# Changelog: ZEEE B2B Trading App

All notable changes to this project will be documented in this file.

## [Release 1.3.0] - 2026-07-16

### Added
- **Unified 5-Tab Navigation Container:** Unfolded layout flow into a bottom navigation portal (Dashboard, Order Guide, Catalog, Cart, Profile).
- **Logistics Ticking Countdown:** Real-time countdown timer to warehouse route cut-offs.
- **One-Tap Quick Reorder:** Rapid order duplicates panel for the last 3 purchase orders.
- **Credit Progress Visuals:** Progress bars tracking corporate debt and cart limits warning levels.
- **Branch facility switcher dropdown & Order status steppers:** Embedded directly inside the new Profile settings tab.

---

## [Release 1.2.0] - 2026-07-16

### Added
- **Route Delivery Calendars & Order Cut-off Times:** Added route schedules to the backend ZIP code matrix (`ZipCodeRouteRule`). Implemented a native calendar date picker on checkout, automatically graying out weekends/unscheduled weekdays and dates violating the daily warehouse 4:00 PM cut-off.
- **Chef's Shopping Order Guide:** Added `/api/v1/products/order-guide/` frequency-aggregation endpoint and a dedicated high-density list screen in Flutter with inline steppers.
- **Commercial Credit Limits & Net Terms:** Added `credit_limit` and `outstanding_balance` parameters to the `Company` model and enforced checks in `InventoryCheckoutView` to reject PO checkouts exceeding available corporate credit. Added warning banners and checkout block parameters on the cart screen.
- **Branch Location Creation:** Added POST method to `/api/accounts/locations/` and a "Register New Shipping Hub" floating action button dialog on the frontend branch picker.
- **Guest Catalog Bypass:** Added guest catalog preview access by inputting a delivery ZIP code on the login screen. Bypasses login to show catalog and regional pricing overrides, showing warnings when trying to perform checkout.
- **Dynamic Database Categories:** Mapped categories chip selectors dynamically to active database rows fetched from `/api/v1/categories/`.
- **User Phone Number:** Added `phone_number` parameter to `UserProfile` model, profile/registration serializers, and the signup stepper.
- **B2B Team Member Management:** Added `/api/accounts/team/` and `/api/accounts/team/<id>/` REST endpoints, permitting company administrators to query their employee roster, onboard new logins, assign role flags, and deactivate logins safely from a custom Flutter screen.

---

## [Frontend Release] - 2026-07-14

### Added
- **Flutter App Architecture Setup:** Configured `frontend/pubspec.yaml` incorporating `provider` (state), `dio` (networking), `flutter_secure_storage` (keychain), `shared_preferences` (cache), and `intl` (formatting).
- **Secure JWT API Service Client:** Created [api_client.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/services/api_client.dart) implementing custom request/error interceptors. They append bearer signatures, handle automatic `/api/token/refresh/` pings, and force sign-out redirects on token expiration.
- **B2B Session & Auth Provider:** Created [auth_provider.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/providers/auth_provider.dart) managing login exchanges, multi-step self-onboarding firms registration, and recovery link requests.
- **Product Catalog Provider:** Created [catalog_provider.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/providers/catalog_provider.dart) loading paginated scroll lists, SKU search query strings, category chips, and order purchase logs.
- **Shopping Cart & Facility Provider:** Created [cart_provider.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/providers/cart_provider.dart) caching branch preferences locally, tracking cart increments/decrements, and submitting PO checkouts.
- **Authentication Screens:** Built [login_screen.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/screens/login_screen.dart), [register_screen.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/screens/register_screen.dart) (multi-step registration stepper), and [password_reset_screen.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/screens/password_reset_screen.dart).
- **Locations & Catalog Display Screens:** Built [location_picker_screen.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/screens/location_picker_screen.dart) (branch facility lists) and [catalog_screen.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/screens/catalog_screen.dart) (high-density list grids, search, category choice chips, MSRP strike-through overlays, drawer links, and quantity increments).
- **Checkout & History Screens:** Built [cart_screen.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/screens/cart_screen.dart) (exemption labels and PO checkouts) and [order_history_screen.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/screens/order_history_screen.dart) (status badges and invoice download notifications).
- **Bootstrap Entry Gateway:** Wired all dependencies and multi-providers inside [main.dart](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/frontend/lib/main.dart) routing users dynamically.

---

## [Backend Release] - 2026-07-13

### Added
- **`api_locations_list` (Branch Locations Listing) Endpoint:** Implemented [CompanyLocationListView](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/accounts/views.py#L104) mapped at `/api/accounts/locations/` returning the authenticated user's registered shipping hubs, along with unit tests.
- **`accounts` Unit Tests:** Created a complete unit test suite in [backend/accounts/tests.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/accounts/tests.py) covering B2B registration, JWT auth logins, token validations, and password reset requests.
- **`customer_order_history` Endpoint:** Implemented [CustomerOrderHistoryView](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/views.py#L156) and mapped it to the `/api/v1/orders/history/` endpoint in [backend/core_backend/urls.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/core_backend/urls.py#L44) to fetch historical tenant invoices.
- **`api_products_list` (Product Catalog Listing) Endpoint:** Implemented [ProductCatalogListView](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/views.py#L207) at `/api/v1/products/` evaluating B2B dynamic pricing structures (contracts, regional ZIPs, and MSRPs) in real-time. Added support for text query searches (on SKU or Name), category slug filtering, and paginated response envelopes for optimal client infinite scroll performance.
- **B2B Registration Constraints:** Added `validate_company_name` and `validate_corporate_email` validators to [EnterpriseRegisterSerializer](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/accounts/serializers.py#L15) to return HTTP 400 validation errors rather than database IntegrityErrors on duplicates.
- **Custom `CheckoutError` Exception:** Added a custom exception handler to roll back the atomic checkout transaction on product stock verification failures.
- **Product Catalog Integration Tests:** Added unit tests verifying catalog access permissions, custom corporate contract pricing overrides, and regional ZIP-code fallback pricing.
- **PDF Invoice Billing System (Module 4):** Created a dynamic PDF compiler [pdf.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/pdf.py) using ReportLab. It draws structured document layouts embedding legal company credentials, shipping facilities, verified Tax IDs, and purchase line-item grids.
- **Email Invoicing Notification Engine:** Created dispatch utility [notifications.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/notifications.py) to format B2B receipt summaries, attach PDF receipts, and trigger automated emails immediately upon successful checkout completions.
- **Invoicing Integration Tests:** Added unit tests verifying email outbox states, PO fields, and PDF attachment compliance parameters.
- **Mass Matrix CSV Import Gateway (Module 5):** Added custom change list actions and HTML templates to standard Django Admin portals. Operators can upload warehouse CSV sheets to bulk import or overwrite master inventory list records, regional prices, or custom corporate contract grids.
- **Admin CSV Integration Tests:** Added unit tests verifying staff access permissions and database record updates after parsed CSV imports.
- **CSV Audit & Row Logging System (Module 5):** Added `CSVImportLog` and `CSVImportRowError` audit models with tabular admin inlines. Row-by-row imports run in nested atomic blocks, logging line numbers and exact failure reasons for corrupt rows while committing valid records successfully.
- **Logistics Webhook Trigger Dispatcher (Module 5):** Created `LogisticsWebhookTarget` registry to manage active URLs for logistics webhooks. Hooked status transitions in `Order.save()` to dispatch ORDER_PLACED and ORDER_STATUS_CHANGED events in background threads using `urllib.request`.
- **Auditing & Webhook Integration Tests:** Added unit tests verifying CSV partial failures, error log parsing, order placement webhooks, and status transition webhook notifications.

### Changed
- **Registration & Password Recovery Security Access:** Configured `permission_classes = [AllowAny]` on both `EnterpriseRegisterView` and `PasswordResetRequestView` so anonymous/logged-out users can register or initiate password recoveries.

### Fixed
- **Pricing Fallback Engine Bug:** Resolved attribute typo in `calculate_item_price` (changed `custom_tier.custom_price` to `custom_tier.negotiated_price` in [backend/products/utils.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/utils.py#L18)).
- **Stock Deduction atomic commitment:** Prevented out-of-stock items from committing stock reductions of previous cart items by raising `CheckoutError` to abort the transaction.
