from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import Company, CompanyLocation
from products.models import Product, Order, OrderItem, UserCustomPricing, ZipCodePricing

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

    def _get_valid_future_date_str(self):
        import datetime
        delivery_date = datetime.date.today() + datetime.timedelta(days=3)
        while delivery_date.isoweekday() > 5:
            delivery_date += datetime.timedelta(days=1)
        return delivery_date.isoformat()

    def test_successful_checkout_and_stock_deduction(self):
        """Verifies a valid cart deducts inventory and applies corporate contract pricing."""
        self.client.force_authenticate(user=self.user_a)

        payload = {
            "location_id": self.location_a.id,
            "delivery_date": self._get_valid_future_date_str(),
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
        self.assertIsNotNone(order.delivery_date)

    def test_insufficient_stock_fails_atomically(self):
        """Verifies that an out-of-stock item rejects the order and rolls back all items."""
        self.client.force_authenticate(user=self.user_a)

        payload = {
            "location_id": self.location_a.id,
            "delivery_date": self._get_valid_future_date_str(),
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
            "delivery_date": self._get_valid_future_date_str(),
            "items": [
                {"sku": "SKU-ZEEE-01", "quantity": 1}
            ]
        }

        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIn("Invalid or unauthorized corporate facility", response.data["error"])
        
        self.product_1.refresh_from_db()
        self.assertEqual(self.product_1.stock_quantity, 50)

    def test_checkout_within_credit_limit(self):
        """Verifies checking out within credit limit succeeds and updates outstanding balance."""
        self.client.force_authenticate(user=self.user_a)
        
        # Set specific credit limit and balance
        self.company_a.credit_limit = 500.00
        self.company_a.outstanding_balance = 100.00
        self.company_a.save()
        
        payload = {
            "location_id": self.location_a.id,
            "delivery_date": self._get_valid_future_date_str(),
            "items": [
                {"sku": "SKU-ZEEE-01", "quantity": 2} # 2 * $85.00 contract rate = $170.00
            ]
        }
        
        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        self.company_a.refresh_from_db()
        # Outstanding balance should be: old_balance (100.00) + order_total (170.00) = 270.00
        self.assertEqual(self.company_a.outstanding_balance, 270.00)

    def test_checkout_exceeds_credit_limit(self):
        """Verifies checking out exceeding credit limit fails and rolls back stock deductions."""
        self.client.force_authenticate(user=self.user_a)
        
        # Set specific credit limit and balance
        self.company_a.credit_limit = 200.00
        self.company_a.outstanding_balance = 100.00
        self.company_a.save()
        
        payload = {
            "location_id": self.location_a.id,
            "delivery_date": self._get_valid_future_date_str(),
            "items": [
                {"sku": "SKU-ZEEE-01", "quantity": 2} # 2 * $85.00 contract rate = $170.00. $100 + $170 = $270 > $200.
            ]
        }
        
        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("exceeds your commercial credit limit", response.data["error"])
        
        # Verify db rolled back
        self.company_a.refresh_from_db()
        self.assertEqual(self.company_a.outstanding_balance, 100.00)
        self.product_1.refresh_from_db()
        self.assertEqual(self.product_1.stock_quantity, 50)

    def test_catalog_anonymous_allowed(self):
        """Verifies anonymous access to catalog list is allowed (guest bypass)."""
        url = reverse('api_products_list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Check that it returns base baseline MSRP prices
        prod_1_data = next(item for item in response.data["results"] if item["sku"] == "SKU-ZEEE-01")
        self.assertEqual(prod_1_data["calculated_price"], "100.00") # Base MSRP, not contract $85.00

    def test_catalog_anonymous_with_zip_pricing(self):
        """Verifies anonymous access applies regional ZIP code pricing override."""
        ZipCodePricing.objects.create(
            zip_code="39401",
            product=self.product_2,
            regional_price=42.00
        )
        url = f"{reverse('api_products_list')}?zip_code=39401"
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        prod_2_data = next(item for item in response.data["results"] if item["sku"] == "SKU-ZEEE-02")
        self.assertEqual(prod_2_data["calculated_price"], "42.00")

    def test_catalog_retrieval_with_contract_pricing(self):
        """Verifies buyer retrieves the catalog with their contract price override applied."""
        self.client.force_authenticate(user=self.user_a)
        url = reverse('api_products_list')
        
        # Request catalog without location
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 2)
        
        # Since company_a has a custom contract pricing of $85.00 for product_1, it should apply
        prod_1_data = next(item for item in response.data["results"] if item["sku"] == "SKU-ZEEE-01")
        self.assertEqual(prod_1_data["calculated_price"], "85.00")

    def test_catalog_retrieval_with_regional_pricing_fallback(self):
        """Verifies regional pricing override is applied when no contract pricing exists."""
        # Setup: Create a regional ZIP price for Product 2 (Base $50 -> Regional $42 for ZIP 39401)
        ZipCodePricing.objects.create(
            zip_code="39401",
            product=self.product_2,
            regional_price=42.00
        )
        
        # Authenticate User A (company_a uses location_a which has ZIP 39401)
        self.client.force_authenticate(user=self.user_a)
        url = f"{reverse('api_products_list')}?location_id={self.location_a.id}"
        
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Product 1 should still have contract price $85.00
        prod_1_data = next(item for item in response.data["results"] if item["sku"] == "SKU-ZEEE-01")
        self.assertEqual(prod_1_data["calculated_price"], "85.00")
        
        # Product 2 should have regional override price $42.00 (instead of MSRP $50.00)
        prod_2_data = next(item for item in response.data["results"] if item["sku"] == "SKU-ZEEE-02")
        self.assertEqual(prod_2_data["calculated_price"], "42.00")

    def test_catalog_search(self):
        """Verifies searching catalog by SKU or Name query works."""
        self.client.force_authenticate(user=self.user_a)
        url = f"{reverse('api_products_list')}?search=ZEEE-01"
        
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["sku"], "SKU-ZEEE-01")

    def test_catalog_category_filtering(self):
        """Verifies filtering catalog by category slug works."""
        from products.models import Category
        # Assign self.product_1 to category 'Bakery'
        bakery_cat = Category.objects.create(name="Bakery", slug="bakery")
        self.product_1.category = bakery_cat
        self.product_1.save()

        self.client.force_authenticate(user=self.user_a)
        url = f"{reverse('api_products_list')}?category_slug=bakery"
        
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["sku"], "SKU-ZEEE-01")

    def test_catalog_pagination_slicing(self):
        """Verifies pagination parameters limit page results size."""
        self.client.force_authenticate(user=self.user_a)
        url = f"{reverse('api_products_list')}?page=1&page_size=1"
        
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["page_size"], 1)
        self.assertEqual(len(response.data["results"]), 1)
        self.assertEqual(response.data["count"], 2) # Total matched is still 2
        self.assertEqual(response.data["total_pages"], 2)

    def test_checkout_sends_invoice_email_with_pdf(self):
        """Verifies that checkout successfully dispatches a confirmation email with PDF invoice."""
        from django.core import mail
        
        # Clear outbox
        mail.outbox = []
        
        self.client.force_authenticate(user=self.user_a)

        payload = {
            "location_id": self.location_a.id,
            "delivery_date": self._get_valid_future_date_str(),
            "items": [
                {"sku": "SKU-ZEEE-01", "quantity": 1}
            ]
        }

        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        # Verify email was sent
        self.assertEqual(len(mail.outbox), 1)
        sent_email = mail.outbox[0]
        
        # Verify email headers and body
        self.assertEqual(sent_email.to, [self.user_a.email])
        self.assertIn("B2B Wholesale Order PO", sent_email.subject)
        self.assertIn("Tax Exempt", sent_email.subject)
        self.assertIn("Zevron Solutions", sent_email.body)
        
        # Verify PDF attachment
        self.assertEqual(len(sent_email.attachments), 1)
        attachment_name, attachment_content, mime_type = sent_email.attachments[0]
        self.assertTrue(attachment_name.startswith("invoice_PO_"))
        self.assertTrue(attachment_name.endswith(".pdf"))
        self.assertEqual(mime_type, "application/pdf")
        
        # Check that PDF has content
        self.assertGreater(len(attachment_content), 0)


class AdminCsvImportTests(APITestCase):
    """Verifies bulk CSV matrix imports via custom Admin views."""

    def setUp(self):
        # Create a staff user to access the admin site
        self.staff_user = User.objects.create_superuser(
            username="admin_operator",
            email="operator@zevron.com",
            password="adminpassword123"
        )
        self.buyer_user = User.objects.create_user(
            username="buyer_user",
            email="buyer@zevron.com",
            password="password123"
        )
        self.import_url = reverse('admin:products_import_csv')

    def test_csv_import_restricted_to_staff(self):
        """Verifies that non-staff clients are blocked from the CSV import URL."""
        # Unauthenticated blocked
        response = self.client.get(self.import_url)
        self.assertEqual(response.status_code, status.HTTP_302_FOUND) # Redirects to admin login
        
        # Authenticated non-staff buyer blocked
        self.client.force_login(self.buyer_user)
        response = self.client.get(self.import_url)
        self.assertEqual(response.status_code, status.HTTP_302_FOUND) # Redirects to admin login

    def test_csv_import_catalog_updates(self):
        """Verifies that a valid inventory CSV updates the Product database records."""
        from django.core.files.uploadedfile import SimpleUploadedFile
        self.client.force_login(self.staff_user)

        csv_content = (
            "sku,name,category,unit_of_measure,base_price,stock_quantity,is_available\r\n"
            "SKU-CSV-01,CSV Widget,Kitchen Supplies,Case of 12,120.00,10,True\r\n"
            "SKU-CSV-02,CSV Pallet,Warehouse Supply,Pallet,500.00,5,True\r\n"
        )
        csv_file = SimpleUploadedFile(
            "catalog.csv",
            csv_content.encode("utf-8"),
            content_type="text/csv"
        )

        response = self.client.post(self.import_url, {"csv_file": csv_file})
        self.assertEqual(response.status_code, status.HTTP_302_FOUND) # Redirect back to change list

        # Verify items were created in DB
        prod1 = Product.objects.filter(sku="SKU-CSV-01").first()
        self.assertIsNotNone(prod1)
        self.assertEqual(prod1.name, "CSV Widget")
        self.assertEqual(prod1.base_price, 120.00)
        self.assertEqual(prod1.category.name, "Kitchen Supplies")
        self.assertEqual(prod1.stock_quantity, 10)

        prod2 = Product.objects.filter(sku="SKU-CSV-02").first()
        self.assertIsNotNone(prod2)
        self.assertEqual(prod2.unit_of_measure, "Pallet")

    def test_csv_import_logging_on_failure(self):
        """Verifies that CSV uploads logging errors works, supporting partial success."""
        from django.core.files.uploadedfile import SimpleUploadedFile
        from products.models import CSVImportLog, CSVImportRowError
        self.client.force_login(self.staff_user)

        # SKU-CSV-99 does not exist, and company Delta Corp does not exist.
        csv_content = (
            "sku,company_legal_name,negotiated_price\r\n"
            "SKU-CSV-99,Delta Corp,120.00\r\n"
        )
        csv_file = SimpleUploadedFile(
            "contracts_bad.csv",
            csv_content.encode("utf-8"),
            content_type="text/csv"
        )

        response = self.client.post(self.import_url, {"csv_file": csv_file})
        self.assertEqual(response.status_code, status.HTTP_302_FOUND)

        # Verify audit log was created
        log_record = CSVImportLog.objects.filter(file_name="contracts_bad.csv").first()
        self.assertIsNotNone(log_record)
        self.assertEqual(log_record.status, CSVImportLog.ImportStatus.FAILED)
        self.assertIn("0 created, 0 updated, 1 failed", log_record.summary)

        # Verify row error record
        row_error = CSVImportRowError.objects.filter(import_log=log_record).first()
        self.assertIsNotNone(row_error)
        self.assertEqual(row_error.line_number, 2)
        self.assertIn("Product matching SKU 'SKU-CSV-99' does not exist", row_error.error_message)


from unittest.mock import patch, MagicMock

class WebhookNotificationTests(APITestCase):
    """Verifies that placing orders and changing status dispatches JSON webhooks to targets."""

    def setUp(self):
        from accounts.models import Company, CompanyLocation
        from products.models import Product, LogisticsWebhookTarget
        
        self.company = Company.objects.create(legal_name="Delta Logistics", corporate_email="ops@delta.com")
        self.location = CompanyLocation.objects.create(
            company=self.company,
            location_name="Hattiesburg Terminal",
            zip_code="39401",
            delivery_address="100 Logistics Way",
            sales_tax_id="MS-9988-EX"
        )
        self.user = User.objects.create_user(username="dispatcher_buyer", email="buyer@delta.com", password="password")
        self.user.company = self.company
        self.user.save()
        
        self.product = Product.objects.create(
            sku="SKU-WEB-01",
            name="Heavy Caster Wheel",
            base_price=35.00,
            stock_quantity=100
        )
        
        # Setup webhook target
        self.webhook_target = LogisticsWebhookTarget.objects.create(
            url="https://logistics.zevron.io/api/v1/orders-receive/",
            is_active=True
        )

    @patch('urllib.request.urlopen')
    def test_order_placement_triggers_webhook(self, mock_urlopen):
        """Verifies order placement creates order and dispatches ORDER_PLACED webhook."""
        from products.models import Order
        
        mock_response = MagicMock()
        mock_response.status = 200
        mock_urlopen.return_value = mock_response
        
        # Simulate checkout view call or manual creation
        order = Order.objects.create(
            user=self.user,
            location=self.location,
            delivery_address_snapshot=self.location.delivery_address,
            sales_tax_id_snapshot=self.location.sales_tax_id,
            total_amount=35.00
        )
        
        # Since webhook is in background thread, we wait briefly for thread to start/execute
        import time
        time.sleep(0.5)
        
        # Assert urllib.request.urlopen was called
        self.assertTrue(mock_urlopen.called)
        
        # Assert request parameters
        called_req = mock_urlopen.call_args[0][0]
        self.assertEqual(called_req.full_url, self.webhook_target.url)
        self.assertEqual(called_req.method, "POST")

    @patch('urllib.request.urlopen')
    def test_order_status_change_triggers_webhook(self, mock_urlopen):
        """Verifies changing order status dispatches ORDER_STATUS_CHANGED webhook."""
        from products.models import Order
        
        mock_response = MagicMock()
        mock_response.status = 200
        mock_urlopen.return_value = mock_response
        
        # Create order
        order = Order.objects.create(
            user=self.user,
            location=self.location,
            delivery_address_snapshot=self.location.delivery_address,
            sales_tax_id_snapshot=self.location.sales_tax_id,
            total_amount=35.00
        )
        
        # Clear initial placement webhook call history
        import time
        time.sleep(0.5)
        mock_urlopen.reset_mock()
        
        # Transition status
        order.status = 'APPROVED'
        order.save()
        
        time.sleep(0.5)
        
        self.assertTrue(mock_urlopen.called)
        called_req = mock_urlopen.call_args[0][0]
        self.assertEqual(called_req.full_url, self.webhook_target.url)


class ProductCategoryListViewTests(APITestCase):
    def setUp(self):
        from products.models import Category
        self.cat1 = Category.objects.create(name="Bakery", slug="bakery")
        self.cat2 = Category.objects.create(name="Pantry", slug="pantry")
        self.user = User.objects.create_user(username="test_buyer", password="password")

    def test_list_categories(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get(reverse('api_categories_list'))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)
        self.assertEqual(response.data[0]["name"], "Bakery")
        self.assertEqual(response.data[1]["name"], "Pantry")

    def test_list_categories_unauthenticated_allowed(self):
        response = self.client.get(reverse('api_categories_list'))
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class OrderGuideListViewTests(APITestCase):
    def setUp(self):
        from accounts.models import Company, CompanyLocation
        from products.models import Product, Order, OrderItem
        
        self.company = Company.objects.create(legal_name="Guide Test Company", corporate_email="ops@guidetest.com")
        self.location = CompanyLocation.objects.create(
            company=self.company,
            location_name="Guide Hub",
            zip_code="39401",
            delivery_address="300 Cargo Lane"
        )
        self.user = User.objects.create_user(username="guide_buyer", password="password", company=self.company)
        
        self.prod1 = Product.objects.create(sku="SKU-G-01", name="Product A", base_price=10.00, stock_quantity=100)
        self.prod2 = Product.objects.create(sku="SKU-G-02", name="Product B", base_price=20.00, stock_quantity=100)
        
        # Place orders to establish order history frequency
        # Order 1 has prod1 and prod2
        self.order1 = Order.objects.create(
            user=self.user,
            location=self.location,
            delivery_address_snapshot="Guide Hub",
            total_amount=30.00
        )
        OrderItem.objects.create(order=self.order1, product=self.prod1, quantity=10, price_paid=10.00)
        OrderItem.objects.create(order=self.order1, product=self.prod2, quantity=1, price_paid=20.00)

        # Order 2 has only prod1 (making prod1 frequency = 2, prod2 frequency = 1)
        self.order2 = Order.objects.create(
            user=self.user,
            location=self.location,
            delivery_address_snapshot="Guide Hub",
            total_amount=10.00
        )
        OrderItem.objects.create(order=self.order2, product=self.prod1, quantity=5, price_paid=10.00)

    def test_order_guide_unauthenticated_blocked(self):
        url = reverse('api_order_guide')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_order_guide_sorting_by_frequency(self):
        self.client.force_authenticate(user=self.user)
        url = reverse('api_order_guide')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)
        
        # Product A (SKU-G-01) must be first since it was ordered in 2 separate orders
        self.assertEqual(response.data[0]["sku"], "SKU-G-01")
        self.assertEqual(response.data[0]["frequency_count"], 2)
        
        # Product B (SKU-G-02) must be second
        self.assertEqual(response.data[1]["sku"], "SKU-G-02")
        self.assertEqual(response.data[1]["frequency_count"], 1)


class RouteDeliverySchedulingTests(APITestCase):
    def setUp(self):
        from accounts.models import Company, CompanyLocation
        from products.models import Product, ZipCodeRouteRule
        import datetime
        
        self.company = Company.objects.create(legal_name="Route Test Co", corporate_email="ops@route.com")
        # Route 1: ZIP 39401 gets Mondays (1) and Thursdays (4) only. Cut-off 16:00.
        self.rule_1 = ZipCodeRouteRule.objects.create(
            zip_code="39401",
            delivery_days="1,4",
            cutoff_time=datetime.time(16, 0, 0)
        )
        self.location = CompanyLocation.objects.create(
            company=self.company,
            location_name="Hattiesburg Branch",
            zip_code="39401",
            delivery_address="300 Cargo Lane"
        )
        self.user = User.objects.create_user(username="route_buyer", password="password", company=self.company)
        
        self.product = Product.objects.create(sku="SKU-R-01", name="Product R", base_price=10.00, stock_quantity=100)
        self.checkout_url = reverse('api_cart_checkout')
        self.route_url = reverse('api_delivery_route')

    def test_get_delivery_schedule_api(self):
        response = self.client.get(self.route_url, {"zip_code": "39401"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["delivery_days"], [1, 4])
        self.assertEqual(response.data["cutoff_time"], "16:00:00")
        self.assertIn("next_available_date", response.data)

    def test_checkout_invalid_weekday_fails(self):
        self.client.force_authenticate(user=self.user)
        # Select a Tuesday (day 2) e.g., 2026-07-21 is Tuesday
        payload = {
            "location_id": self.location.id,
            "delivery_date": "2026-07-21",
            "items": [{"sku": "SKU-R-01", "quantity": 1}]
        }
        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("not a valid delivery day", response.data["error"])

    def test_checkout_before_next_available_fails(self):
        self.client.force_authenticate(user=self.user)
        # 2020-01-02 is a Thursday (valid weekday, but before next available date)
        payload = {
            "location_id": self.location.id,
            "delivery_date": "2020-01-02",
            "items": [{"sku": "SKU-R-01", "quantity": 1}]
        }
        response = self.client.post(self.checkout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("The selected delivery date is not available", response.data["error"])