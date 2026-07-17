from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny
from accounts.models import CompanyLocation

from django.db import transaction
from accounts.models import CompanyLocation
from .models import Product, Order, OrderItem
from .utils import calculate_item_price, get_delivery_schedule
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
        payment_method = request.data.get('payment_method', 'NET_30').upper()

        if payment_method not in ['NET_30', 'CREDIT_CARD', 'ACH']:
            return Response(
                {"error": f"Invalid payment method specified: {payment_method}."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        if payment_method == 'NET_30' and not user.company:
            return Response(
                {"error": "Net 30 Terms are only available for authorized corporate client accounts."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

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

        # Validate delivery route date selection
        import datetime
        delivery_date_str = request.data.get('delivery_date')
        if not delivery_date_str:
            return Response(
                {"error": "Please select a scheduled delivery date from the route calendar."}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            delivery_date = datetime.datetime.strptime(delivery_date_str, "%Y-%m-%d").date()
        except (ValueError, TypeError):
            return Response(
                {"error": "Invalid delivery date format. Use YYYY-MM-DD."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        schedule = get_delivery_schedule(location.zip_code)
        delivery_weekday = delivery_date.isoweekday()
        if delivery_weekday not in schedule['delivery_days']:
            return Response(
                {"error": f"The selected date is not a valid delivery day for ZIP {location.zip_code}. Deliveries are only available on scheduled weekdays: {schedule['delivery_days']}."}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        next_avail = datetime.date.fromisoformat(schedule['next_available_date'])
        if delivery_date < next_avail:
            return Response(
                {"error": f"The selected delivery date is not available. The next route dispatch for ZIP {location.zip_code} is on or after {schedule['next_available_date']} (respecting daily cut-off rules)."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Wrap everything in an atomic database block. If anything fails, all changes roll back instantly.
        try:
            with transaction.atomic():
                from decimal import Decimal
                total_order_amount = Decimal('0.00')
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
                    line_total = Decimal(str(price_paid)) * quantity
                    total_order_amount += line_total

                    # Queue up the line item payload array
                    order_items_to_create.append({
                        "product": product,
                        "quantity": quantity,
                        "price_paid": price_paid
                    })

                # Verify corporate credit limits (Only if charging to corporate credit line)
                if payment_method == 'NET_30':
                    company = user.company
                    if company:
                        from accounts.models import Company
                        locked_company = Company.objects.select_for_update().get(id=company.id)
                        new_balance = locked_company.outstanding_balance + total_order_amount
                        if new_balance > locked_company.credit_limit:
                            raise CheckoutError(
                                f"Purchase Order exceeds your commercial credit limit. Required: ${total_order_amount:.2f}. Available credit: ${(locked_company.credit_limit - locked_company.outstanding_balance):.2f}.",
                                status.HTTP_400_BAD_REQUEST
                            )
                        locked_company.outstanding_balance = new_balance
                        locked_company.save()

                # Create the master transaction envelope record
                master_order = Order.objects.create(
                    user=user,
                    location=location,
                    delivery_address_snapshot=address_snapshot,
                    sales_tax_id_snapshot=tax_snapshot,
                    delivery_date=delivery_date,
                    total_amount=total_order_amount,
                    payment_method=payment_method
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
    permission_classes = [AllowAny]

    def get(self, request):
        user = request.user
        location_id = request.query_params.get('location_id')
        zip_code = request.query_params.get('zip_code')
        
        # Resolve user's branch location for regional pricing tier checking
        location = None
        if location_id and user and user.is_authenticated:
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
            calculated_price = calculate_item_price(user, location, product, zip_code=zip_code)
            
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


class ProductCatalogDetailView(APIView):
    """
    Secure endpoint returning the details of a single product SKU
    with dynamic pricing cascades calculated specifically for the authenticated user and location.
    """
    permission_classes = [AllowAny]

    def get(self, request, sku):
        from django.shortcuts import get_object_or_404
        user = request.user
        location_id = request.query_params.get('location_id')
        zip_code = request.query_params.get('zip_code')

        product = get_object_or_404(Product, sku=sku, is_available=True)

        # Resolve user's branch location for regional pricing tier checking
        location = None
        if location_id and user and user.is_authenticated:
            location = CompanyLocation.objects.filter(
                id=location_id,
                company=user.company
            ).first()

        calculated_price = calculate_item_price(user, location, product, zip_code=zip_code)

        # Resolve absolute media URL if image is present
        image_url = None
        if product.image:
            image_url = request.build_absolute_uri(product.image.url)

        data = {
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
        }
        return Response(data, status=status.HTTP_200_OK)


class ProductCategoryListView(APIView):
    """
    Exposes a dynamic list of active product categories from the database.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        from .models import Category
        categories = Category.objects.all().order_by('name')
        data = [
            {"id": cat.id, "name": cat.name, "slug": cat.slug}
            for cat in categories
        ]
        return Response(data, status=status.HTTP_200_OK)


class OrderGuideListView(APIView):
    """
    Returns frequently ordered products for the authenticated user's company
    to populate their custom Order Guide.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models import Count, Sum
        from products.models import OrderItem, Product
        from accounts.models import CompanyLocation

        user = request.user
        location_id = request.query_params.get('location_id')
        
        # Resolve user's branch location for regional pricing tier checking
        location = None
        if location_id:
            location = CompanyLocation.objects.filter(
                id=location_id,
                company=user.company
            ).first()

        # Aggregate order history to find top products ordered by this company
        frequent_items = OrderItem.objects.filter(
            order__user__company=user.company
        ).values('product').annotate(
            order_count=Count('order', distinct=True),
            total_qty=Sum('quantity')
        ).order_by('-order_count', '-total_qty')
        
        product_ids = [item['product'] for item in frequent_items]
        
        # Resolve products dictionary in one query
        products = {
            p.id: p 
            for p in Product.objects.filter(id__in=product_ids, is_available=True).select_related('category')
        }
        
        data = []
        for item in frequent_items:
            prod_id = item['product']
            if prod_id not in products:
                continue
            product = products[prod_id]
            calculated_price = calculate_item_price(user, location, product)
            
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
                "frequency_count": item['order_count']
            })
            
        return Response(data, status=status.HTTP_200_OK)


class ZipCodeDeliveryRouteView(APIView):
    """
    Exposes the scheduled delivery weekdays, cut-off hours, and next available shipment dates
    matching a target ZIP code parameter.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        zip_code = request.query_params.get('zip_code')
        if not zip_code:
            return Response(
                {"error": "Missing zip_code query parameter."}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            schedule = get_delivery_schedule(zip_code)
            return Response(schedule, status=status.HTTP_200_OK)
        except Exception as e:
            return Response(
                {"error": f"Failed resolving route parameters: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class SystemAlertListView(APIView):
    """
    Returns active alerts posted within the last 15 days.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        from datetime import timedelta
        from django.utils import timezone
        from .models import SystemAlert

        cutoff_date = timezone.now() - timedelta(days=15)
        alerts = SystemAlert.objects.filter(
            is_active=True,
            created_at__gte=cutoff_date
        ).order_by('-created_at')

        data = []
        for alert in alerts:
            data.append({
                "id": alert.id,
                "message": alert.message,
                "severity": alert.severity,
                "created_at": alert.created_at.isoformat(),
            })
        return Response(data, status=status.HTTP_200_OK)