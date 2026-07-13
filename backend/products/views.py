from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from accounts.models import CompanyLocation
from .models import Product
from .utils import calculate_item_price

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