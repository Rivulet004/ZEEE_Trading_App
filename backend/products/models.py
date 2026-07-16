from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _

class Category(models.Model):
    """
    Structural groupings for inventory classification.
    Allows easy frontend catalog tab generation and search filtering.
    """
    name = models.CharField(max_length=100, unique=True, db_index=True)
    slug = models.SlugField(max_length=120, unique=True, help_text="URL-friendly identifier.")
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Product Category"
        verbose_name_plural = "Product Categories"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Product(models.Model):
    """
    Master inventory catalog. Tracks stock keeping units (SKUs),
    structural classification, visual assets, and baseline wholesale pricing parameters.
    """
    sku = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=255, db_index=True)
    
    # Newly Integrated Relationships & Media Attributes
    category = models.ForeignKey(
        Category, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name="products",
        help_text="Primary classification group."
    )
    image = models.ImageField(
        upload_to="products/catalog/", 
        blank=True, 
        null=True, 
        help_text="Visual catalog thumbnail asset."
    )
    
    description = models.TextField(blank=True)
    unit_of_measure = models.CharField(max_length=50, help_text="e.g., 50lb Bag, Case of 6, Gallon")
    base_price = models.DecimalField(max_digits=12, decimal_places=2, help_text="Standard wholesale price rule fallback.")
    stock_quantity = models.IntegerField(default=0)
    is_available = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Master Product"
        verbose_name_plural = "Master Products"
        ordering = ["sku"]

    def __str__(self):
        return f"{self.name} ({self.sku})"


# ==============================================================================
# ENTERPRISE B2B PRICING MATRIX TIERS
# ==============================================================================

class ZipCodePricing(models.Model):
    """
    Regional Tier Grid pricing layer. Overrides base price rules 
    automatically depending on the shipping location target ZIP.
    """
    zip_code = models.CharField(max_length=10, db_index=True)
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="zip_prices")
    regional_price = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        unique_together = ('zip_code', 'product')
        verbose_name = "Regional Zip Price Rule"
        verbose_name_plural = "Regional Zip Price Rules"

    def __str__(self):
        return f"ZIP {self.zip_code} -> {self.product.sku}: ${self.regional_price}"

    def save(self, *args, **kwargs):
        if self.zip_code:
            self.zip_code = self.zip_code.strip().upper()
        super().save(*args, **kwargs)


class UserCustomPricing(models.Model):
    """
    Contract Tier Pricing layer. Overrides all other rules for a 
    specific corporate client based on pre-negotiated legal terms.
    """
    company = models.ForeignKey('accounts.Company', on_delete=models.CASCADE, related_name="contract_prices")
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="company_custom_prices")
    negotiated_price = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        unique_together = ('company', 'product')
        verbose_name = "Corporate Contract Price"
        verbose_name_plural = "Corporate Contract Prices"

    def __str__(self):
        return f"{self.company.legal_name} -> {self.product.sku}: ${self.negotiated_price}"


# ==============================================================================
# AUDITABLE TRANSACTION LAYER (HISTORICAL CUSTOMER PURCHASE LEDGER)
# ==============================================================================

class Order(models.Model):
    """
    Master transaction ledger tracking commercial checkouts.
    Binds the order history record permanently to the customer profile.
    """
    class OrderStatus(models.TextChoices):
        PENDING = 'PENDING', 'Pending Processing'
        APPROVED = 'APPROVED', 'Approved by Logistics'
        SHIPPED = 'SHIPPED', 'Out for Delivery'
        DELIVERED = 'DELIVERED', 'Fulfillment Complete'
        CANCELLED = 'CANCELLED', 'Void / Cancelled'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.PROTECT, 
        related_name="placed_orders"
    )
    location = models.ForeignKey(
        'accounts.CompanyLocation', 
        on_delete=models.PROTECT, 
        related_name="location_orders"
    )
    status = models.CharField(
        max_length=15, 
        choices=OrderStatus.choices, 
        default=OrderStatus.PENDING, 
        db_index=True
    )
    
    delivery_address_snapshot = models.TextField()
    sales_tax_id_snapshot = models.CharField(max_length=50)
    delivery_date = models.DateField(null=True, blank=True, help_text="Scheduled route shipment date.")
    
    total_amount = models.DecimalField(max_digits=12, decimal_places=2)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Commercial Purchase Order"
        verbose_name_plural = "Commercial Purchase Orders"
        ordering = ["-created_at"]

    def __str__(self):
        return f"PO #{self.id} - {self.location.company.legal_name} ({self.created_at.strftime('%Y-%m-%d')})"

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        old_status = None
        if not is_new:
            try:
                old_status = Order.objects.get(pk=self.pk).status
            except Order.DoesNotExist:
                pass
                
        super().save(*args, **kwargs)
        
        # Trigger webhook notifications
        try:
            from products.notifications import trigger_order_webhook
            if is_new:
                trigger_order_webhook(self, 'ORDER_PLACED')
            elif old_status and old_status != self.status:
                trigger_order_webhook(self, 'ORDER_STATUS_CHANGED')
        except Exception as webhook_err:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to dispatch logistics webhook for PO #{self.id}: {webhook_err}")


class OrderItem(models.Model):
    """
    Immutable individual line items inside a purchase order.
    Freezes final computed price paid at checkout permanently.
    """
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(Product, on_delete=models.PROTECT, related_name="historical_sales")
    quantity = models.PositiveIntegerField()
    price_paid = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        verbose_name = "Transaction Line Item"
        verbose_name_plural = "Transaction Line Items"

    def __str__(self):
        return f"PO #{self.order.id} | {self.product.sku} x {self.quantity}"


class CSVImportLog(models.Model):
    class ImportStatus(models.TextChoices):
        SUCCESS = 'SUCCESS', 'Completed Successfully'
        PARTIAL = 'PARTIAL', 'Completed with Errors'
        FAILED = 'FAILED', 'Failed Entirely'

    class ImportType(models.TextChoices):
        CATALOG = 'CATALOG', 'Product Inventory Catalog'
        REGIONAL = 'REGIONAL', 'Regional ZIP Pricing Grid'
        CONTRACT = 'CONTRACT', 'Corporate Contract Pricing'

    file_name = models.CharField(max_length=255)
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=15, choices=ImportStatus.choices, default=ImportStatus.SUCCESS)
    import_type = models.CharField(max_length=15, choices=ImportType.choices)
    summary = models.TextField(blank=True)

    class Meta:
        verbose_name = "CSV Import Audit Log"
        verbose_name_plural = "CSV Import Audit Logs"
        ordering = ["-uploaded_at"]

    def __str__(self):
        return f"{self.get_import_type_display()} - {self.file_name} ({self.uploaded_at.strftime('%Y-%m-%d %H:%M')})"


class CSVImportRowError(models.Model):
    import_log = models.ForeignKey(CSVImportLog, on_delete=models.CASCADE, related_name="row_errors")
    line_number = models.IntegerField()
    row_data = models.TextField(help_text="Original CSV row content.")
    error_message = models.TextField()

    class Meta:
        verbose_name = "CSV Row Import Error"
        verbose_name_plural = "CSV Row Import Errors"
        ordering = ["line_number"]

    def __str__(self):
        return f"Line {self.line_number}: {self.error_message[:50]}"


class LogisticsWebhookTarget(models.Model):
    url = models.URLField(max_length=500, unique=True, help_text="Target URL for B2B dispatch notifications.")
    is_active = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Logistics Webhook Target"
        verbose_name_plural = "Logistics Webhook Targets"
        ordering = ["-created_at"]

    def __str__(self):
        return self.url


class ZipCodeRouteRule(models.Model):
    """
    Defines delivery days and daily cut-off rules for a specific ZIP code area.
    """
    zip_code = models.CharField(max_length=10, unique=True, db_index=True)
    # Comma-separated weekdays (1=Monday, 7=Sunday)
    delivery_days = models.CharField(max_length=50, default="1,2,3,4,5,6,7", help_text="Comma-separated ISO weekdays (1=Monday, 7=Sunday).")
    cutoff_time = models.TimeField(default="16:00:00", help_text="Daily order cut-off time (24h format). Past this, shipment shifts to the next route day.")

    class Meta:
        verbose_name = "ZIP Code Delivery Route Rule"
        verbose_name_plural = "ZIP Code Delivery Route Rules"

    def __str__(self):
        return f"ZIP {self.zip_code} Delivery Days: {self.delivery_days} Cut-off: {self.cutoff_time}"


class SystemAlert(models.Model):
    SEVERITY_CHOICES = [
        ('INFO', 'Information'),
        ('WARNING', 'Warning'),
        ('CRITICAL', 'Critical Delay'),
    ]
    message = models.TextField()
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default='WARNING')
    is_active = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = "System Alert"
        verbose_name_plural = "System Alerts"
        ordering = ["-created_at"]

    def __str__(self):
        return f"[{self.severity}] {self.message[:30]}"