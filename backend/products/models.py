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