from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import Company, CompanyLocation
from products.models import Product, Order, OrderItem, UserCustomPricing

User = get_user_model()

class EnterpriseSystemIntegrationsTests(APITestCase):
    """Verifies complete data layer integration across accounts and products."""

    def setUp(self):
        # 1. Initialize Company A (Tenant A)
        self.company_a = Company.objects.create(legal_name="Zevron Wholesale", corporate_email="hq@zevron.com")
        self.loc_a = CompanyLocation.objects.create(company=self.company_a, location_name="Main Hub", zip_code="39401")
        self.user_a = User.objects.create_user(
            username="zevron_buyer", 
            email="buyer_a@zevron.com",  # Explicit unique email
            password="password123", 
            company=self.company_a
        )
        
        # 2. Initialize Company B (Tenant B - Isolation Check)
        self.company_b = Company.objects.create(legal_name="Delta Core", corporate_email="hq@delta.com")
        self.loc_b = CompanyLocation.objects.create(company=self.company_b, location_name="North Branch", zip_code="77001")
        self.user_b = User.objects.create_user(
            username="delta_buyer", 
            email="buyer_b@delta.com",  # Explicit unique email
            password="password123", 
            company=self.company_b
        )

        # 3. Build Base Inventory
        self.product = Product.objects.create(sku="SKU-ZEEE-01", name="Premium Trading Widget", base_price=100.00, stock_quantity=50)

        # 4. Create an Order History entry for Company A
        self.order_a = Order.objects.create(
            user=self.user_a, 
            location=self.loc_a, 
            total_amount=100.00, 
            delivery_address_snapshot="Main Hub, ZIP: 39401",
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
        self.assertEqual(len(response.data), 0)

    def test_authorized_order_history_retrieval(self):
        """Verifies a buyer successfully fetches their own corporate transaction logs."""
        self.client.force_authenticate(user=self.user_a)
        response = self.client.get(self.history_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['items'][0]['product_sku'], "SKU-ZEEE-01")


class CheckoutEngineTests(APITestCase):
    """Verifies atomic checkout operations, stock allocation, and pricing enforcement."""

    def setUp(self):
        # 1. Establish Corporate Tenant A
        self.company_a = Company.objects.create(
            legal_name="Zevron Solutions", 
            corporate_email="hq@zevron.com"
        )
        self.location_a = CompanyLocation.objects.create(
            company=self.company_a,
            location_name="Primary Mississippi Hub",
            delivery_address="100 Innovation Way, Hattiesburg, MS",  # Match your real model field!
            zip_code="39401",
            sales_tax_id="TAX-999"
        )
        self.user_a = User.objects.create_user(
            username="checkout_buyer_a", 
            email="checkout_a@zevron.com",
            password="securepassword123", 
            company=self.company_a
        )

        # 2. Establish Corporate Tenant B (For Isolation Testing)
        self.company_b = Company.objects.create(
            legal_name="Delta Corp", 
            corporate_email="ops@delta.com"
        )
        self.location_b = CompanyLocation.objects.create(
            company=self.company_b,
            location_name="Delta Texas Branch",
            delivery_address="500 Enterprise Row, Houston, TX",  # Match your real model field!
            zip_code="77001",
            sales_tax_id="TAX-888"
        )

        # 3. Populate Inventory Items
        self.product_1 = Product.objects.create(
            sku="SKU-ZEEE-01",
            name="Premium Trading Widget",
            base_price=100.00,
            stock_quantity=50
        )
        self.product_2 = Product.objects.create(
            sku="SKU-ZEEE-02",
            name="Standard Bulk Box",
            base_price=50.00,
            stock_quantity=10
        )

        # 4. Bind a Pre-Negotiated Contract Price to Company A for Product 1 ($100 -> $85)
        UserCustomPricing.objects.create(
            company=self.company_a,
            product=self.product_1,
            negotiated_price=85.00
        )

        # 5. Define Checkout Routing Gateway Target
        self.checkout_url = reverse('api_cart_checkout')

    def test_successful_checkout_and_stock_deduction(self):
        """Verifies a valid cart deducts inventory and applies corporate contract pricing."""
        self.client.force_authenticate(user=self.user_a)

        payload = {
            "location_id": self.location_a.id,
            "items": [
                {"sku": "SKU-ZEEE-01", "quantity": 2},
                {"sku": "SKU-ZEEE-02", "quantity": 1}
            ]
        }

        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["total_amount"], "220.00")

        self.product_1.refresh_from_db()
        self.product_2.refresh_from_db()
        self.assertEqual(self.product_1.stock_quantity, 48)
        self.assertEqual(self.product_2.stock_quantity, 9)

        order = Order.objects.get(id=response.data["order_id"])
        self.assertIn("Primary Mississippi Hub", order.delivery_address_snapshot)
        self.assertEqual(order.items.count(), 2)

    def test_insufficient_stock_fails_atomically(self):
        """Verifies that an out-of-stock item rejects the order and rolls back all items."""
        self.client.force_authenticate(user=self.user_a)

        payload = {
            "location_id": self.location_a.id,
            "items": [
                {"sku": "SKU-ZEEE-01", "quantity": 1},
                {"sku": "SKU-ZEEE-02", "quantity": 99}
            ]
        }

        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertIn("Insufficient stock allocation", response.data["error"])

        self.product_1.refresh_from_db()
        self.assertEqual(self.product_1.stock_quantity, 50) 
        self.assertEqual(Order.objects.count(), 0)

    def test_cross_tenant_location_checkout_is_blocked(self):
        """Secures system borders: Company A cannot check out using Company B's facilities."""
        self.client.force_authenticate(user=self.user_a)

        payload = {
            "location_id": self.location_b.id,
            "items": [
                {"sku": "SKU-ZEEE-01", "quantity": 1}
            ]
        }

        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIn("Invalid or unauthorized corporate facility", response.data["error"])
        
        self.product_1.refresh_from_db()
        self.assertEqual(self.product_1.stock_quantity, 50)