from django.contrib import admin
from .models import Product, ZipCodePricing, UserCustomPricing, Order, OrderItem

class ZipCodePricingInline(admin.TabularInline):
    model = ZipCodePricing
    extra = 1

class UserCustomPricingInline(admin.TabularInline):
    model = UserCustomPricing
    extra = 1

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('sku', 'name', 'base_price', 'unit_of_measure', 'stock_quantity', 'is_available')
    search_fields = ('sku', 'name')
    list_filter = ('is_available',)
    inlines = [ZipCodePricingInline, UserCustomPricingInline]

class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ('product', 'quantity', 'price_paid')
    can_delete = False

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'get_company_name', 'status', 'total_amount', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('id', 'user__username', 'sales_tax_id_snapshot')
    readonly_fields = ('user', 'location', 'delivery_address_snapshot', 'sales_tax_id_snapshot', 'total_amount', 'tax_amount', 'created_at')
    inlines = [OrderItemInline]

    def get_company_name(self, obj):
        return obj.location.company.legal_name