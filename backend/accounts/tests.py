from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import Company, CompanyLocation

User = get_user_model()

class AccountsSystemTests(APITestCase):
    """Verifies authentication, tenant onboarding, and user validation constraints."""

    def setUp(self):
        # Establish base targets
        self.register_url = reverse('api_register')
        self.login_url = reverse('api_login')
        self.check_token_url = reverse('api_check_token')
        self.password_reset_url = reverse('api_password_reset')

        # Create a pre-existing tenant structure to test validation duplicates
        self.existing_company = Company.objects.create(
            legal_name="Zevron Foods",
            corporate_email="wholesale@zevron.com"
        )
        self.existing_location = CompanyLocation.objects.create(
            company=self.existing_company,
            location_name="Hattiesburg Branch",
            delivery_address="100 Innovation Way",
            zip_code="39401",
            sales_tax_id="TAX-Z-999"
        )
        self.existing_user = User.objects.create_user(
            username="zevron_admin",
            email="admin@zevron.com",
            password="securepassword123",
            company=self.existing_company,
            role=User.UserRoles.ADMIN
        )

    def test_successful_corporate_onboarding(self):
        """Verifies that nested JSON payload creates company, location, and owner admin accounts."""
        payload = {
            "username": "new_b2b_admin",
            "password": "brandnewpassword123",
            "email": "owner@newcorp.com",
            "first_name": "John",
            "last_name": "Doe",
            "phone_number": "1-800-555-0199",
            "company_name": "New Corp Foods LLC",
            "corporate_email": "ops@newcorp.com",
            "location_data": {
                "location_name": "Primary Warehouse",
                "delivery_address": "400 Logistics Blvd, Houston, TX",
                "zip_code": "77001",
                "sales_tax_id": "TAX-TX-888"
            }
        }

        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertIn("user", response.data)
        self.assertEqual(response.data["user"]["username"], "new_b2b_admin")
        self.assertEqual(response.data["user"]["company_name"], "New Corp Foods LLC")
        self.assertEqual(response.data["user"]["phone_number"], "1-800-555-0199")

        # Verify DB states
        company_exists = Company.objects.filter(legal_name="New Corp Foods LLC").exists()
        self.assertTrue(company_exists)
        
        user = User.objects.get(username="new_b2b_admin")
        self.assertEqual(user.email, "owner@newcorp.com")
        self.assertEqual(user.phone_number, "1-800-555-0199")
        self.assertEqual(user.role, User.UserRoles.ADMIN)
        self.assertEqual(user.company.legal_name, "New Corp Foods LLC")
        
        location = CompanyLocation.objects.get(company=user.company)
        self.assertEqual(location.location_name, "Primary Warehouse")
        self.assertEqual(location.zip_code, "77001")
        self.assertEqual(location.sales_tax_id, "TAX-TX-888")

    def test_register_duplicate_username_fails(self):
        """Verifies that duplicate username requests are rejected."""
        payload = {
            "username": "zevron_admin", # Duplicate
            "password": "somepassword123",
            "email": "different@email.com",
            "company_name": "Unique Company Ltd",
            "corporate_email": "unique@company.com",
            "location_data": {
                "delivery_address": "123 Lane",
                "zip_code": "12345",
                "sales_tax_id": "TAX-123"
            }
        }
        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("username", response.data)

    def test_register_duplicate_email_fails(self):
        """Verifies that duplicate human user email registration is rejected."""
        payload = {
            "username": "new_admin_user",
            "password": "somepassword123",
            "email": "admin@zevron.com", # Duplicate
            "company_name": "Unique Company Ltd",
            "corporate_email": "unique@company.com",
            "location_data": {
                "delivery_address": "123 Lane",
                "zip_code": "12345",
                "sales_tax_id": "TAX-123"
            }
        }
        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("email", response.data)

    def test_register_duplicate_company_name_fails(self):
        """Verifies that registering with an existing legal company name is rejected."""
        payload = {
            "username": "new_admin_user",
            "password": "somepassword123",
            "email": "new@email.com",
            "company_name": "Zevron Foods", # Duplicate
            "corporate_email": "unique@company.com",
            "location_data": {
                "delivery_address": "123 Lane",
                "zip_code": "12345",
                "sales_tax_id": "TAX-123"
            }
        }
        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("company_name", response.data)
        self.assertIn("legal company name already exists", str(response.data["company_name"]))

    def test_register_duplicate_corporate_email_fails(self):
        """Verifies that registering with an existing corporate email is rejected."""
        payload = {
            "username": "new_admin_user",
            "password": "somepassword123",
            "email": "new@email.com",
            "company_name": "Unique Company Ltd",
            "corporate_email": "wholesale@zevron.com", # Duplicate
            "location_data": {
                "delivery_address": "123 Lane",
                "zip_code": "12345",
                "sales_tax_id": "TAX-123"
            }
        }
        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("corporate_email", response.data)
        self.assertIn("corporate email address already exists", str(response.data["corporate_email"]))

    def test_jwt_login_success(self):
        """Verifies JWT login returns tokens and serialize profile data correctly."""
        payload = {
            "username": "zevron_admin",
            "password": "securepassword123"
        }
        response = self.client.post(self.login_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertIn("user", response.data)
        self.assertEqual(response.data["user"]["role"], "ADMIN")
        self.assertEqual(response.data["user"]["company_name"], "Zevron Foods")

    def test_jwt_login_invalid_credentials_fails(self):
        """Verifies that bad login credentials return unauthorized status."""
        payload = {
            "username": "zevron_admin",
            "password": "wrongpassword"
        }
        response = self.client.post(self.login_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_check_token_endpoint(self):
        """Verifies JWT validation gateway confirms access credentials."""
        self.client.force_authenticate(user=self.existing_user)
        response = self.client.get(self.check_token_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["authenticated"])
        self.assertEqual(response.data["user"]["username"], "zevron_admin")

    def test_check_token_unauthenticated_is_blocked(self):
        """Verifies unauthenticated token pings are blocked."""
        response = self.client.get(self.check_token_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_password_recovery_link_generation(self):
        """Verifies password reset requests generate confirmation signals."""
        payload = {
            "email": "admin@zevron.com"
        }
        response = self.client.post(self.password_reset_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("recovery link has been generated", response.data["message"])

    def test_list_company_locations(self):
        """Verifies authenticated users retrieve locations list matching company tenant."""
        self.client.force_authenticate(user=self.existing_user)
        url = reverse('api_locations_list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["location_name"], "Hattiesburg Branch")

    def test_list_company_locations_unauthenticated_blocked(self):
        """Verifies unauthenticated locations list access is rejected."""
        url = reverse('api_locations_list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_company_location(self):
        """Verifies authenticated users can create a new location for their company."""
        self.client.force_authenticate(user=self.existing_user)
        url = reverse('api_locations_list')
        payload = {
            "location_name": "New Houston Hub",
            "delivery_address": "500 Cargo Rd, Houston, TX",
            "zip_code": "77002",
            "sales_tax_id": "TX-9988-ABC"
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["location_name"], "New Houston Hub")
        self.assertEqual(response.data["zip_code"], "77002")

        # Verify in DB
        location = CompanyLocation.objects.get(id=response.data["id"])
        self.assertEqual(location.company, self.existing_user.company)
        self.assertEqual(location.zip_code, "77002")

    def test_create_company_location_unauthenticated_blocked(self):
        """Verifies unauthenticated users cannot create locations."""
        url = reverse('api_locations_list')
        payload = {
            "location_name": "Unauthorized Hub",
            "delivery_address": "500 Cargo Rd, Houston, TX",
            "zip_code": "77002",
            "sales_tax_id": "TX-9988-ABC"
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_team_members_as_admin_succeeds(self):
        self.client.force_authenticate(user=self.existing_user)
        url = reverse('api_team_list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Should contain the existing admin user
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["username"], self.existing_user.username)

    def test_list_team_members_as_buyer_fails(self):
        # Create a user with BUYER role
        buyer_user = User.objects.create_user(
            username="buyer_test",
            email="buyer@zevron.com",
            password="password123",
            company=self.existing_company,
            role=User.UserRoles.BUYER
        )
        self.client.force_authenticate(user=buyer_user)
        url = reverse('api_team_list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_add_team_member_as_admin_succeeds(self):
        self.client.force_authenticate(user=self.existing_user)
        url = reverse('api_team_list')
        payload = {
            "username": "new_chef",
            "email": "chef@zevron.com",
            "password": "password123",
            "first_name": "Chef",
            "last_name": "Boyardee",
            "phone_number": "555-555-5555",
            "role": "BUYER"
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["username"], "new_chef")
        self.assertEqual(response.data["role"], "BUYER")

        # Verify DB
        new_chef_exists = User.objects.filter(username="new_chef", company=self.existing_company).exists()
        self.assertTrue(new_chef_exists)

    def test_add_team_member_as_buyer_fails(self):
        buyer_user = User.objects.create_user(
            username="buyer_test2",
            email="buyer2@zevron.com",
            password="password123",
            company=self.existing_company,
            role=User.UserRoles.BUYER
        )
        self.client.force_authenticate(user=buyer_user)
        url = reverse('api_team_list')
        payload = {
            "username": "new_chef2",
            "email": "chef2@zevron.com",
            "password": "password123",
            "role": "BUYER"
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_delete_team_member_as_admin_succeeds(self):
        # Create a team member to delete
        sub_user = User.objects.create_user(
            username="to_delete",
            email="delete@zevron.com",
            password="password123",
            company=self.existing_company,
            role=User.UserRoles.VIEWER
        )
        self.client.force_authenticate(user=self.existing_user)
        url = reverse('api_team_detail', kwargs={'pk': sub_user.id})
        response = self.client.delete(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify DB
        self.assertFalse(User.objects.filter(id=sub_user.id).exists())

    def test_delete_self_fails(self):
        self.client.force_authenticate(user=self.existing_user)
        url = reverse('api_team_detail', kwargs={'pk': self.existing_user.id})
        response = self.client.delete(url)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("cannot remove your own", response.data["error"])
