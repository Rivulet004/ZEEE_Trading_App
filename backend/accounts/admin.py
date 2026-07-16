from django.contrib import admin
from django.utils.translation import gettext_lazy as _
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from unfold.admin import ModelAdmin, TabularInline, StackedInline
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm
from .models import Company, CompanyLocation, UserProfile

class CompanyLocationInline(StackedInline):
    """
    Allows physical delivery locations to be edited directly 
    inside the master Company dashboard screen (Inline layout).
    """
    model = CompanyLocation
    extra = 1  # Provides 1 empty slot automatically to add a new location quickly
    classes = ['collapse']  # Keeps the structural view clean by allowing panels to minimize
    fieldsets = (
        (None, {
            'fields': ('location_name', 'delivery_address', 'zip_code')
        }),
        (_('Tax Exemption Auditing'), {
            'fields': ('sales_tax_id', 'tax_exempt_verified', 'tax_certificate_expiry', 'tax_certificate_file'),
            'description': _('Ensure physical compliance parameters are verified before checking tax exemption.')
        }),
    )


class UserProfileInline(TabularInline):
    """
    Allows management to view, add, or change employee login 
    accounts directly from the master Company screen.
    """
    model = UserProfile
    extra = 0  # Do not force blank user additions without specific operational intent
    fields = ('username', 'email', 'role', 'is_active')
    readonly_fields = ('username', 'email')  # Protect security credentials from accidental edits
    can_delete = False  # Force accounts to be deactivated rather than hard deleted to preserve database logs


@admin.register(Company)
class CompanyAdmin(ModelAdmin):
    """
    The main control hub for a corporate client entity.
    Gathers locations, buyers, and financial states into a single screen.
    """
    list_display = ('legal_name', 'corporate_email', 'total_locations', 'total_employees', 'is_active', 'created_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('legal_name', 'corporate_email')
    
    # Embed the location matrix and employee frameworks straight into this screen view
    inlines = [CompanyLocationInline, UserProfileInline]

    def total_locations(self, obj):
        """ Dynamically tracks active shipping points for dashboard overview """
        return obj.locations.count()
    total_locations.short_description = _("Shipping Locations")

    def total_employees(self, obj):
        """ Dynamically tracks user accounts hooked to this corporate layer """
        return obj.employees.count()
    total_employees.short_description = _("Registered Buyers")


@admin.register(CompanyLocation)
class CompanyLocationAdmin(ModelAdmin):
    """
    A fallback list view dedicated to auditing shipping points 
    and fast tracking tax compliance flags across regions.
    """
    list_display = ('location_name', 'get_company_name', 'zip_code', 'sales_tax_id', 'tax_exempt_verified', 'tax_certificate_expiry')
    list_filter = ('tax_exempt_verified', 'zip_code', 'tax_certificate_expiry')
    search_fields = ('location_name', 'company__legal_name', 'zip_code', 'sales_tax_id')
    actions = ['mark_tax_exempt_verified', 'revoke_tax_exemption']

    def get_company_name(self, obj):
        return obj.company.legal_name
    get_company_name.short_description = _("Parent Company")
    get_company_name.admin_order_field = 'company__legal_name'

    # --- Bulk Actions for Administrative Operators ---

    @admin.action(description=_("Bulk Verify Selected Tax Certificates"))
    def mark_tax_exempt_verified(self, request, queryset):
        """ Custom action to approve multiple tax certificates instantly """
        updated = queryset.update(tax_exempt_verified=True)
        self.message_user(request, f"Successfully verified {updated} location tax profiles.")

    @admin.action(description=_("Bulk Revoke Selected Tax Exemptions"))
    def revoke_tax_exemption(self, request, queryset):
        """ Custom action to lock out expired or invalid tax profiles """
        updated = queryset.update(tax_exempt_verified=False)
        self.message_user(request, f"Successfully revoked exemption status for {updated} profiles.", level='warning')


@admin.register(UserProfile)
class CustomUserProfileAdmin(BaseUserAdmin, ModelAdmin):
    """
    Enterprise modification of Django's default User system interface.
    Integrates our customized role options and target company connections cleanly.
    """
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm

    list_display = ('username', 'email', 'get_company_name', 'role', 'is_staff', 'is_active')
    list_filter = ('role', 'is_staff', 'is_active')
    search_fields = ('username', 'first_name', 'last_name', 'email', 'company__legal_name')

    # Append our custom corporate link blocks directly into the User detail fields view
    fieldsets = BaseUserAdmin.fieldsets + (
        (_('B2B Organizational Context'), {
            'fields': ('company', 'role'),
        }),
    )

    def get_company_name(self, obj):
        return obj.company.legal_name if obj.company else _("Unlinked Freelance Buyer")
    get_company_name.short_description = _("Assigned Corporate Entity")
    get_company_name.admin_order_field = 'company__legal_name'