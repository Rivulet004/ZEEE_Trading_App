from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from accounts.models import Company, CompanyLocation
from products.models import Product, Order, OrderItem

User = get_user_model()

class EnterpriseSystemIntegrationsTests(APITestCase):
    """Verifies complete data layer integration across accounts and products."""

    def setUp(self):
        # 1. Initialize Company A (Tenant A)
        self.company_a = Company.objects.create(legal_name="Zevron Wholesale", corporate_email="hq@zevron.com")
        self.loc_a = CompanyLocation.objects.create(company=self.company_a, location_name="Main Hub", zip_code="39401")
        self.user_a = User.objects.create_user(username="zevron_buyer", password="password123", company=self.company_a)
        
        # 2. Initialize Company B (Tenant B - Isolation Check)
        self.company_b = Company.objects.create(legal_name="Delta Core", corporate_email="hq@delta.com")
        self.loc_b = CompanyLocation.objects.create(company=self.company_b, location_name="North Branch", zip_code="77001")
        self.user_b = User.objects.create_user(username="delta_buyer", password="password123", company=self.company_b)

        # 3. Build Base Inventory
        self.product = Product.objects.create(sku="SKU-ZEEE-01", name="Premium Trading Widget", base_price=100.00, stock_quantity=50)

        # 4. Create an Order History entry for Company A
        self.order_a = Order.objects.create(
            user=self.user_a, 
            location=self.loc_a, 
            total_amount=100.00, 
            delivery_address_snapshot="123 Zevron St",
            sales_tax_id_snapshot="TAX-999"
        )
        OrderItem.objects.create(order=self.order_a, product=self.product, quantity=1, price_paid=100.00)

        # 5. Routing targets
        self.history_url = reverse('customer_order_history')

    def test_database_relations_exist(self):
        """Verifies that companies, profiles, and inventory are linking correctly in PostgreSQL."""
        self.assertEqual(self.user_a.company.legal_name, "Zevron Wholesale")
        self.assertEqual(self.loc_a.company.legal_name, "Zevron Wholesale")
        self.assertEqual(self.product.sku, "SKU-ZEEE-01")

    def test_unauthenticated_order_history_blocked(self):
        """Secures data: anonymous incoming traffic must be rejected."""
        response = self.client.get(self.history_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_isolated_tenant_order_history(self):
        """Verifies multi-tenancy: Company B cannot see Company A's history logs."""
        self.client.force_authenticate(user=self.user_b)
        response = self.client.get(self.history_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Should return 0 items because Company B has placed no orders
        self.assertEqual(len(response.data), 0)

    def test_authorized_order_history_retrieval(self):
        """Verifies a buyer successfully fetches their own corporate transaction logs."""
        self.client.force_authenticate(user=self.user_a)
        response = self.client.get(self.history_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['items'][0]['product_sku'], "SKU-ZEEE-01")