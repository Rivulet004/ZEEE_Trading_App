# Product Specification Document: B2B Wholesale Ordering Platform (Revised)

## 1. Product Overview & Core Vision

The platform is a high-performance, decoupled Business-to-Business (B2B) commerce ecosystem specifically optimized for the commercial restaurant supply and food distribution industries.

Unlike standard retail platforms, this system bypasses consumer-facing complexities (like multi-tier retail taxes and manual administrative onboarding queues) to offer immediate, frictionless utility to restaurant managers, chefs, and wholesale buyers. The core architectural priority is speed, offline utility, absolute historical financial accuracy, and granular pricing flexibility down to individual contract lines.

### Key Demographics & Persona Focus

* **Primary User:** Restaurant owners, head chefs, and purchasing managers executing frequent, high-volume, recurring bulk catalog purchases.
* **Operational Environment:** Thick-walled commercial walk-in freezers, basement dry-storage facilities, and high-stress kitchen environments lacking reliable network connectivity.

---

## 2. Platform Architecture & Tech Stack

The architecture utilizes a fully decoupled modern framework stack designed to maximize localized performance and ensure bulletproof security.

```
[Flutter Mobile Application] <─── Secure REST API (JSON / HTTPS) ───> [Django Core Web Server]
                                                                              │
                                                                              ▼
                                                                     [PostgreSQL Database]

```

* **Frontend Client:** Flutter (Dart) compiled natively for iOS and Android. Chosen for high-frequency hardware acceleration, centralized cross-platform state synchronization, and native local database caching modules.
* **Backend Application Server:** Django (Python) via Django REST Framework (DRF). Chosen for its mature security paradigms, strict Relational Object Mapping (ORM), robust built-in cryptographic tools, and comprehensive administrative portal.
* **Production Database Layer:** PostgreSQL. Configured with heavy indexing across performance-critical strings (SKUs, ZIP Codes, User Links) to maintain sub-millisecond query performance during high-concurrency request windows.

---

## 3. Epics, Features, & Capabilities

### Module 1: Seamless Onboarding & User Management

* **Frictionless B2B Account Creation:** Self-service registration interface requesting standard credentials alongside critical enterprise metrics: Legal Company Name, Physical Delivery Address (stored inside a single `delivery_address` block field), Target Delivery ZIP Code, and State Sales Tax ID.
* **Instant Access Session Handshake:** The system completely bypasses administrative verification queues. Upon submission, the API processes registration, generates a unique user row linked to a custom `UserProfile` tracking roles (`ADMIN`, `BUYER`, `VIEWER`), establishes a cryptographic JWT token, and logs the user straight into the active catalog profile.
* **Token-Backed Persistent Session State:** Secure local client storage preserves the active session state using hardware-level keychains, mitigating frequent, frustrating login requests for the user.
* **Cryptographic Password Recovery:** Fully automated end-to-end "Forgot Password" framework. The backend translates the mobile request into a timed, single-use, signature-verified link dispatched to the client's inbox, routing them safely to a clean password confirmation gateway.

### Module 2: The Multi-Tier Dynamic Pricing Engine

The platform implements a hyper-targeted, real-time pricing cascade logic. The database evaluates product catalog queries on demand using a strict three-tier structural fallback mechanism:

1. **Contract Override Tier (Highest Priority):** Evaluates if a matching record exists inside the `UserCustomPricing` ledger for the explicitly authenticated corporate entity and target Product ID. If a contract price is defined, the system selects this rate immediately.
2. **Regional Grid Tier (Secondary Fallback):** If no direct user contract exists, the engine scans the `ZipCodePricing` matrix matching the shipping destination facility's `zip_code` against the target Product ID. This absorbs regional logistics, freight variables, and shifting market overheads dynamically.
3. **Base Wholesale Tier (Universal Default):** If neither exception rule matches, the system surfaces the baseline standard rate declared in the core master product inventory row.

```
[User Action: View Catalog]
            │
            ▼
[Check User Custom Pricing Table] ───( Found )───> [Display Contract Price]
            │
         ( None )
            │
            ▼
[Check Zip Code Pricing Table] ────( Found )───> [Display Regional Price]
            │
         ( None )
            │
            ▼
[Read Product Master Table] ──────────────────────> [Display Base Wholesale Price]

```

### Module 3: Advanced Wholesale Catalog & Cart Dynamics

* **High-Density SKU Matrix Display:** Visually clean, dense catalog grid presenting vital tracking metrics at a glance: Product Name, Product Image Asset link, Weight/Volume Unit Metrics (`unit_of_measure`), Unique SKU Identifiers, Warehouse Stock Indicators, and the dynamically calculated Active Contract Price.
* **Wholesale Unit Incrementors:** Quantity modification systems tailored for bulk buying. Bypasses standard sluggish dropdown selectors in favor of high-frequency step controllers capable of handling heavy numeric increments (e.g., ordering items smoothly by the pallet or multi-case crate) with zero input lag.
* **Disconnected Grid Resiliency (Offline Mode):** Local storage engines cache active item structures, product category relations, media links, and user-tier pricing structures directly onto the mobile hardware memory. Users can easily browse records, navigate inventory categories, and systematically assemble their physical shopping carts while entirely offline inside insulated warehouse freezers.
* **Synchronized Cart Ledger Validation:** Cart actions are held locally in app memory during compilation. Upon checkout execution, the complete payload is transmitted to the backend where the DRF pipeline cross-examines the proposed total against current database configurations, catching price adjustments instantly.

### Module 4: The Tax-Exempt Invoicing & Billing Pipeline

Upon mobile validation and order placement, the Django backend triggers a multi-step transactional automation chain wrapped inside an atomic transaction:

* **Immutable Financial Price-Locking:** The checkout engine clones the active dynamic price and stamps it as a static number directly into a permanent `OrderItem` historical log row. Future manual product adjustments or contract mutations within the admin dashboard will never alter historical sales records.
* **Protective Text Snapshots:** The system takes unalterable plain text snapshots of the destination facility's detailed `delivery_address` and current `sales_tax_id` at the exact millisecond of checkout, storing them directly on the `Order` record to preserve historical accuracy against future corporate profile edits.
* **Sales Tax ID Compliance Formatting:** In accordance with business-to-business wholesale regulations, the system checks the shipping location's provided Sales Tax ID. The calculation system sets the tax variable to exactly `0.00` and stamps the invoice ledger line explicitly as Tax Exempt (Sales Tax Certificate ID Provided).
* **Dynamic PDF Generation System:** The backend constructs an accounting-compliant commercial PDF invoice. The document header dynamically embeds the client’s company credentials, full delivery metadata, and their verified Tax ID for seamless tracking and financial audits.
* **Omnichannel Fulfillment Notifications:**
* *External Direct Delivery:* The system hooks into an email engine to transmit the finalized PDF invoice structure directly to the customer’s primary inbox within seconds.
* *Internal Logistics Dispatch:* The platform instantly broadcasts a notification dispatch to internal fulfillment centers, generating detailed picking tickets, warehousing SKU manifests, and sorting logs for the loaders.



### Module 5: Administrative Command & Control Dashboard

* **Granular Contract Pricing Management:** Inline administration tables built directly into the user account views. Management personnel can effortlessly search for any product item and assign a binding contract override rate to a customer account in seconds.
* **Mass Matrix CSV Data Utilities:** High-speed upload gateways allowing operators to drop full warehouse CSV sheets directly into the dashboard, processing mass creations or overwrites of global inventories, stock amounts, product category mappings, and regional pricing grids simultaneously.
* **Logistics Auditing Console:** Real-time visibility into global ordering logs, tracking overall delivery statuses using strict `OrderStatus` progressions (`PENDING` $\rightarrow$ `APPROVED` $\rightarrow$ `SHIPPED` $\rightarrow$ `DELIVERED`), reviewing past PDF records, and assessing historical sales performance.