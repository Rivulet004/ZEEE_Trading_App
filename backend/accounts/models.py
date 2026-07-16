from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.core.validators import FileExtensionValidator

class Company(models.Model):
    """
    Represents the overarching legal corporate entity. 
    Manages high-level credit details and global corporate identification.
    """
    legal_name = models.CharField(max_length=255, unique=True, db_index=True)
    corporate_email = models.EmailField(unique=True)
    credit_limit = models.DecimalField(max_digits=12, decimal_places=2, default=10000.00, help_text="Maximum outstanding balance allowed for Net terms B2B billing.")
    outstanding_balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00, help_text="Current total amount of unpaid monthly invoices.")
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = _("Company Account")
        verbose_name_plural = _("Company Accounts")
        ordering = ["legal_name"]

    def __str__(self):
        return self.legal_name


class CompanyLocation(models.Model):
    """
    Represents individual physical restaurant branches or delivery sites.
    Allows one corporate entity to easily manage multiple shipping targets.
    """
    company = models.ForeignKey(Company, on_delete=models.PROTECT, related_name="locations")
    location_name = models.CharField(max_length=100, help_text="e.g., Downtown Branch, Warehouse B")
    delivery_address = models.TextField()
    zip_code = models.CharField(max_length=10, db_index=True)
    
    # Tax-Exempt Audit Fields
    sales_tax_id = models.CharField(max_length=50, db_index=True)
    tax_exempt_verified = models.BooleanField(default=False)
    tax_certificate_expiry = models.DateField(null=True, blank=True)
    tax_certificate_file = models.FileField(
        upload_to="tax_certificates/",
        validators=[FileExtensionValidator(allowed_extensions=['pdf', 'jpg', 'jpeg'])],
        null=True,
        blank=True
    )

    class Meta:
        verbose_name = _("Location Matrix")
        verbose_name_plural = _("Location Matrices")

    def __str__(self):
        return f"{self.company.legal_name} - {self.location_name}"

    def save(self, *args, **kwargs):
        """ Enforce standardized uppercase strings to protect pricing fallbacks """
        if self.zip_code:
            self.zip_code = self.zip_code.strip().upper()
        if self.sales_tax_id:
            self.sales_tax_id = self.sales_tax_id.strip().upper()
        super().save(*args, **kwargs)


class UserProfile(AbstractUser):
    """
    Extends the fundamental Django authentication engine.
    Maps human identities directly into corporate accounts with strict role tracking.
    """
    class UserRoles(models.TextChoices):
        ADMIN = 'ADMIN', _('Corporate Administrator')
        BUYER = 'BUYER', _('Standard Purchasing Agent')
        VIEWER = 'VIEWER', _('Read-Only Operational Observer')

    email = models.EmailField(unique=True, error_messages={
        'unique': _("An authenticated profile with this email address already exists."),
    })
    
    # Connections to corporate layers
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="employees", null=True, blank=True)
    role = models.CharField(max_length=10, choices=UserRoles.choices, default=UserRoles.BUYER)

    REQUIRED_FIELDS = ['email']

    class Meta:
        verbose_name = _("User Identity Profile")
        verbose_name_plural = _("User Identity Profiles")

    def __str__(self):
        return f"{self.get_full_name() or self.username} ({self.company.legal_name if self.company else 'Unlinked'})"