from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from accounts.models import CompanyLocation

from django.db import transaction
from accounts.models import CompanyLocation
from .models import Product, Order, OrderItem
from .utils import calculate_item_price
from .pdf import generate_invoice_pdf
from .notifications import send_invoice_email

class ProductPriceEvaluationView(APIView):
    """Secure endpoint providing dynamic real-time contract/regional cost checking."""
    permission_classes = [IsAuthenticated]

    def get(self, request, sku):
        try:
            # 1. Look up the catalog product asset
            product = Product.objects.get(sku=sku)
            
            # 2. Grab the location parameter passed by the app session context
            location_id = request.query_params.get('location_id')
            location = None
            if location_id:
                location = CompanyLocation.objects.filter(
                    id=location_id, 
                    company=request.user.company
                ).first()

            # 3. Compute the true corporate price structure
            final_price = calculate_item_price(request.user, location, product)

            return Response({
                "sku": product.sku,
                "name": product.name,
                "base_price": str(product.base_price),
                "calculated_price": str(final_price),
                "has_discount": final_price < product.base_price
            }, status=status.HTTP_200_OK)

        except Product.DoesNotExist:
            return Response({"error": "Product catalog asset not found."}, status=status.HTTP_404_NOT_FOUND)


class CheckoutError(Exception):
    """Custom exception to roll back transactions and convey custom HTTP status codes."""
    def __init__(self, message, status_code):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class InventoryCheckoutView(APIView):
    """
    Processes incoming mobile shopping carts, executes real-time stock deductions,
    and commits unalterable financial purchase orders to the ledger.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        location_id = request.data.get('location_id')
        cart_items = request.data.get('items', [])  # Expects list: [{"sku": "...", "quantity": 2}]

        if not location_id or not cart_items:
            return Response(
                {"error": "Missing location identity or shopping cart contents."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Look up the target delivery branch location matching this user's company tenant
        location = CompanyLocation.objects.filter(id=location_id, company=user.company).first()
        if not location:
            return Response(
                {"error": "Invalid or unauthorized corporate facility selection."}, 
                status=status.HTTP_404_NOT_FOUND
            )

        # Wrap everything in an atomic database block. If anything fails, all changes roll back instantly.
        try:
            with transaction.atomic():
                total_order_amount = 0
                order_items_to_create = []

                # Build out the text address snapshot permanently
                address_snapshot = f"{location.location_name}\n{location.delivery_address} (ZIP: {location.zip_code})"
                tax_snapshot = location.sales_tax_id or 'NOT_PROVIDED'

                # Loop through and process each item in the cart array
                for item in cart_items:
                    sku = item.get('sku')
                    quantity = int(item.get('quantity', 0))

                    if quantity <= 0:
                        raise CheckoutError(
                            f"Invalid item quantity specified for SKU: {sku}.", 
                            status.HTTP_400_BAD_REQUEST
                        )

                    # Select for update locks the row in PostgreSQL to prevent simultaneous stock tampering
                    product = Product.objects.select_for_update().filter(sku=sku).first()
                    if not product:
                        raise CheckoutError(
                            f"Catalog item matching SKU '{sku}' does not exist.", 
                            status.HTTP_404_NOT_FOUND
                        )

                    # Verify inventory thresholds
                    if product.stock_quantity < quantity:
                        raise CheckoutError(
                            f"Insufficient stock allocation for {product.name}. Available: {product.stock_quantity}.", 
                            status.HTTP_409_CONFLICT
                        )

                    # Deduct stock counts immediately
                    product.stock_quantity -= quantity
                    product.save()

                    # Calculate the true real-time contract/regional tier price
                    price_paid = calculate_item_price(user, location, product)
                    line_total = price_paid * quantity
                    total_order_amount += line_total

                    # Queue up the line item payload array
                    order_items_to_create.append({
                        "product": product,
                        "quantity": quantity,
                        "price_paid": price_paid
                    })

                # Create the master transaction envelope record
                master_order = Order.objects.create(
                    user=user,
                    location=location,
                    delivery_address_snapshot=address_snapshot,
                    sales_tax_id_snapshot=tax_snapshot,
                    total_amount=total_order_amount
                )

                # Commit all queued items pointing back to the master envelope ID
                for line in order_items_to_create:
                    OrderItem.objects.create(
                        order=master_order,
                        product=line["product"],
                        quantity=line["quantity"],
                        price_paid=line["price_paid"]
                    )

            # Generate dynamic PDF and send email notification
            try:
                pdf_content = generate_invoice_pdf(master_order)
                send_invoice_email(master_order, pdf_content)
            except Exception as notification_error:
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"Fulfillment notification failed for PO #{master_order.id}: {str(notification_error)}")

            return Response({
                "message": "Commercial purchase order authorized successfully.",
                "order_id": master_order.id,
                "total_amount": str(master_order.total_amount),
                "status": master_order.status
            }, status=status.HTTP_201_CREATED)

        except CheckoutError as ce:
            return Response(
                {"error": ce.message}, 
                status=ce.status_code
            )
        except Exception as e:
            return Response(
                {"error": f"An unhandled execution event faulted the checkout loop: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class CustomerOrderHistoryView(APIView):
    """
    Secure endpoint allowing authenticated users to fetch historical transaction logs
    matching their corporate tenant profile.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if not user.company:
            return Response([], status=status.HTTP_200_OK)

        # Retrieve orders for the user's company, ordering by creation time descending
        orders = Order.objects.filter(user__company=user.company).prefetch_related('items__product').order_by('-created_at')
        
        data = []
        for order in orders:
            data.append({
                "id": order.id,
                "order_id": order.id,
                "status": order.status,
                "total_amount": str(order.total_amount),
                "tax_amount": str(order.tax_amount),
                "delivery_address_snapshot": order.delivery_address_snapshot,
                "sales_tax_id_snapshot": order.sales_tax_id_snapshot,
                "created_at": order.created_at.isoformat(),
                "items": [
                    {
                        "product_sku": item.product.sku,
                        "product_name": item.product.name,
                        "quantity": item.quantity,
                        "price_paid": str(item.price_paid),
                    }
                    for item in order.items.all()
                ]
            })
        return Response(data, status=status.HTTP_200_OK)


class ProductCatalogListView(APIView):
    """
    Secure endpoint returning the master catalog list with dynamic pricing cascades
    calculated specifically for the authenticated user and location.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        location_id = request.query_params.get('location_id')
        
        # Resolve user's branch location for regional pricing tier checking
        location = None
        if location_id:
            location = CompanyLocation.objects.filter(
                id=location_id,
                company=user.company
            ).first()

        # 1. Start with available catalog items
        queryset = Product.objects.filter(is_available=True).select_related('category')

        # 2. Query Search Filter (SKU or Name)
        search_query = request.query_params.get('search')
        if search_query:
            from django.db.models import Q
            queryset = queryset.filter(
                Q(sku__icontains=search_query) | Q(name__icontains=search_query)
            )

        # 3. Category Filter
        category_slug = request.query_params.get('category_slug')
        if category_slug:
            queryset = queryset.filter(category__slug=category_slug)

        # 4. Count total items before slicing
        total_count = queryset.count()

        # 5. Parse Pagination Query params
        page = 1
        try:
            page = int(request.query_params.get('page', 1))
            if page < 1:
                page = 1
        except ValueError:
            pass

        page_size = 20
        try:
            page_size = int(request.query_params.get('page_size', 20))
            if page_size < 1:
                page_size = 20
        except ValueError:
            pass

        start = (page - 1) * page_size
        end = start + page_size
        products = queryset[start:end]
        
        data = []
        for product in products:
            calculated_price = calculate_item_price(user, location, product)
            
            # Resolve absolute media URL if image is present
            image_url = None
            if product.image:
                image_url = request.build_absolute_uri(product.image.url)

            data.append({
                "sku": product.sku,
                "name": product.name,
                "description": product.description,
                "unit_of_measure": product.unit_of_measure,
                "base_price": str(product.base_price),
                "calculated_price": str(calculated_price),
                "stock_quantity": product.stock_quantity,
                "image_url": image_url,
                "category": {
                    "id": product.category.id,
                    "name": product.category.name,
                    "slug": product.category.slug,
                } if product.category else None,
                "is_available": product.is_available,
            })
            
        # Build paginated response envelope
        import math
        total_pages = math.ceil(total_count / page_size) if total_count > 0 else 1
        next_page = page + 1 if page < total_pages else None
        prev_page = page - 1 if page > 1 else None

        return Response({
            "count": total_count,
            "total_pages": total_pages,
            "current_page": page,
            "page_size": page_size,
            "next_page": next_page,
            "prev_page": prev_page,
            "results": data
        }, status=status.HTTP_200_OK)