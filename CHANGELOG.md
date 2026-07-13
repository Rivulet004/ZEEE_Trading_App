# Changelog: ZEEE B2B Trading App Backend

All notable changes to this project will be documented in this file.

---

## [Unreleased] - 2026-07-13

### Added
- **`accounts` Unit Tests:** Created a complete unit test suite in [backend/accounts/tests.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/accounts/tests.py) covering B2B registration, JWT auth logins, token validations, and password reset requests.
- **`customer_order_history` Endpoint:** Implemented [CustomerOrderHistoryView](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/views.py#L156) and mapped it to the `/api/v1/orders/history/` endpoint in [backend/core_backend/urls.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/core_backend/urls.py#L44) to fetch historical tenant invoices.
- **`api_products_list` (Product Catalog Listing) Endpoint:** Implemented [ProductCatalogListView](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/views.py#L207) at `/api/v1/products/` evaluating B2B dynamic pricing structures (contracts, regional ZIPs, and MSRPs) in real-time.
- **B2B Registration Constraints:** Added `validate_company_name` and `validate_corporate_email` validators to [EnterpriseRegisterSerializer](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/accounts/serializers.py#L15) to return HTTP 400 validation errors rather than database IntegrityErrors on duplicates.
- **Custom `CheckoutError` Exception:** Added a custom exception handler to roll back the atomic checkout transaction on product stock verification failures.
- **Product Catalog Integration Tests:** Added unit tests verifying catalog access permissions, custom corporate contract pricing overrides, and regional ZIP-code fallback pricing.
- **PDF Invoice Billing System (Module 4):** Created a dynamic PDF compiler [pdf.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/pdf.py) using ReportLab. It draws structured document layouts embedding legal company credentials, shipping facilities, verified Tax IDs, and purchase line-item grids.
- **Email Invoicing Notification Engine:** Created dispatch utility [notifications.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/notifications.py) to format B2B receipt summaries, attach PDF receipts, and trigger automated emails immediately upon successful checkout completions.
- **Invoicing Integration Tests:** Added unit tests verifying email outbox states, PO fields, and PDF attachment compliance parameters.

### Changed
- **Registration & Password Recovery Security Access:** Configured `permission_classes = [AllowAny]` on both `EnterpriseRegisterView` and `PasswordResetRequestView` so anonymous/logged-out users can register or initiate password recoveries.

### Fixed
- **Pricing Fallback Engine Bug:** Resolved attribute typo in `calculate_item_price` (changed `custom_tier.custom_price` to `custom_tier.negotiated_price` in [backend/products/utils.py](file:///c:/Users/MBS/OneDrive/Desktop/Programming/ZEEE_Trading_app/backend/products/utils.py#L18)).
- **Stock Deduction atomic commitment:** Prevented out-of-stock items from committing stock reductions of previous cart items by raising `CheckoutError` to abort the transaction.
