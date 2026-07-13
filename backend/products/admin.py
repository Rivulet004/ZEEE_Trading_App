from django.contrib import admin
from .models import (
    Product, 
    ZipCodePricing, 
    UserCustomPricing, 
    Order, 
    OrderItem, 
    CSVImportLog, 
    CSVImportRowError, 
    LogisticsWebhookTarget
)

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
    change_list_template = "admin/products/product/change_list.html"

    def get_urls(self):
        from django.urls import path
        urls = super().get_urls()
        custom_urls = [
            path('import-csv/', self.admin_site.admin_view(self.import_csv), name='products_import_csv'),
        ]
        return custom_urls + urls

    def import_csv(self, request):
        import csv
        import io
        from django.contrib import messages
        from django.shortcuts import redirect, render
        from django.db import transaction
        from products.models import Product, ZipCodePricing, UserCustomPricing, Category, CSVImportLog, CSVImportRowError
        from accounts.models import Company

        if request.method == "POST":
            csv_file = request.FILES.get('csv_file')
            if not csv_file or not csv_file.name.endswith('.csv'):
                self.message_user(request, "Error: Please upload a valid CSV file.", level=messages.ERROR)
                return redirect("..")

            try:
                # Read the file content as text
                file_data = csv_file.read().decode("utf-8-sig")
                csv_data = csv.DictReader(io.StringIO(file_data))
                
                # Check headers to identify sheet type
                headers = [h.strip().lower() for h in csv_data.fieldnames] if csv_data.fieldnames else []
                
                # Determine import type based on headers
                import_type = None
                if 'sku' in headers and ('base_price' in headers or 'name' in headers):
                    import_type = CSVImportLog.ImportType.CATALOG
                elif 'sku' in headers and 'zip_code' in headers and 'regional_price' in headers:
                    import_type = CSVImportLog.ImportType.REGIONAL
                elif 'sku' in headers and 'company_legal_name' in headers and 'negotiated_price' in headers:
                    import_type = CSVImportLog.ImportType.CONTRACT

                if not import_type:
                    # Log failed import due to bad headers
                    CSVImportLog.objects.create(
                        file_name=csv_file.name,
                        uploaded_by=request.user,
                        status=CSVImportLog.ImportStatus.FAILED,
                        import_type=CSVImportLog.ImportType.CATALOG, # fallback
                        summary="Failed: Invalid CSV header format. Supported headers not matched."
                    )
                    self.message_user(request, "Error: Invalid CSV header format.", level=messages.ERROR)
                    return redirect("..")

                # Create the audit log record
                import_log = CSVImportLog.objects.create(
                    file_name=csv_file.name,
                    uploaded_by=request.user,
                    import_type=import_type,
                    status=CSVImportLog.ImportStatus.SUCCESS # initially success
                )

                created_count = 0
                updated_count = 0
                failure_count = 0

                # Process row by row with partial success recovery
                for index, row in enumerate(csv_data, start=2):
                    cleaned_row = {k.strip().lower(): v.strip() for k, v in row.items() if k}
                    
                    try:
                        with transaction.atomic():
                            sku = cleaned_row.get('sku')
                            if not sku:
                                raise ValueError("Missing required field 'sku'")

                            if import_type == CSVImportLog.ImportType.CATALOG:
                                category_obj = None
                                if 'category' in cleaned_row and cleaned_row['category']:
                                    cat_name = cleaned_row['category']
                                    cat_slug = cat_name.lower().replace(" ", "-").replace("/", "-")
                                    category_obj, _ = Category.objects.get_or_create(
                                        name=cat_name,
                                        defaults={"slug": cat_slug}
                                    )

                                defaults = {}
                                if 'name' in cleaned_row:
                                    defaults['name'] = cleaned_row['name']
                                if 'base_price' in cleaned_row:
                                    defaults['base_price'] = cleaned_row['base_price']
                                if 'unit_of_measure' in cleaned_row:
                                    defaults['unit_of_measure'] = cleaned_row['unit_of_measure']
                                if 'stock_quantity' in cleaned_row:
                                    defaults['stock_quantity'] = int(cleaned_row['stock_quantity'])
                                if 'is_available' in cleaned_row:
                                    defaults['is_available'] = cleaned_row['is_available'].lower() in ('true', '1', 'yes')
                                if category_obj:
                                    defaults['category'] = category_obj

                                obj, created = Product.objects.update_or_create(
                                    sku=sku,
                                    defaults=defaults
                                )

                            elif import_type == CSVImportLog.ImportType.REGIONAL:
                                zip_code = cleaned_row.get('zip_code')
                                regional_price = cleaned_row.get('regional_price')
                                if not zip_code or not regional_price:
                                    raise ValueError("Missing 'zip_code' or 'regional_price'")

                                product = Product.objects.filter(sku=sku).first()
                                if not product:
                                    raise ValueError(f"Product matching SKU '{sku}' does not exist")

                                obj, created = ZipCodePricing.objects.update_or_create(
                                    zip_code=zip_code.upper(),
                                    product=product,
                                    defaults={"regional_price": regional_price}
                                )

                            elif import_type == CSVImportLog.ImportType.CONTRACT:
                                company_name = cleaned_row.get('company_legal_name')
                                negotiated_price = cleaned_row.get('negotiated_price')
                                if not company_name or not negotiated_price:
                                    raise ValueError("Missing 'company_legal_name' or 'negotiated_price'")

                                product = Product.objects.filter(sku=sku).first()
                                if not product:
                                    raise ValueError(f"Product matching SKU '{sku}' does not exist")

                                company = Company.objects.filter(legal_name__iexact=company_name).first()
                                if not company:
                                    raise ValueError(f"Company matching legal name '{company_name}' does not exist")

                                obj, created = UserCustomPricing.objects.update_or_create(
                                    company=company,
                                    product=product,
                                    defaults={"negotiated_price": negotiated_price}
                                )

                            if created:
                                created_count += 1
                            else:
                                updated_count += 1

                    except Exception as row_error:
                        # Log error details and mark row failure
                        CSVImportRowError.objects.create(
                            import_log=import_log,
                            line_number=index,
                            row_data=str(row),
                            error_message=str(row_error)
                        )
                        failure_count += 1

                # Update audit log summary
                total_processed = created_count + updated_count + failure_count
                summary_text = (
                    f"Processed {total_processed} lines: "
                    f"{created_count} created, {updated_count} updated, {failure_count} failed."
                )
                import_log.summary = summary_text

                if failure_count > 0:
                    import_log.status = (
                        CSVImportLog.ImportStatus.PARTIAL 
                        if (created_count + updated_count) > 0 
                        else CSVImportLog.ImportStatus.FAILED
                    )
                    import_log.save()
                    
                    self.message_user(
                        request,
                        f"CSV Import completed with errors: {summary_text} Check the CSV Audit Logs for row-level details.",
                        level=messages.WARNING
                    )
                else:
                    import_log.status = CSVImportLog.ImportStatus.SUCCESS
                    import_log.save()
                    self.message_user(request, f"CSV Import complete! {summary_text}", level=messages.SUCCESS)

                return redirect("..")

            except Exception as e:
                self.message_user(request, f"Critical CSV processor fault: {str(e)}", level=messages.ERROR)
                return redirect("..")

        # GET request renders upload page
        context = dict(
            self.admin_site.each_context(request),
            title="Import B2B CSV Matrix",
        )
        return render(request, "admin/products/import_csv.html", context)

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

class CSVImportRowErrorInline(admin.TabularInline):
    model = CSVImportRowError
    extra = 0
    readonly_fields = ('line_number', 'row_data', 'error_message')
    can_delete = False

@admin.register(CSVImportLog)
class CSVImportLogAdmin(admin.ModelAdmin):
    list_display = ('file_name', 'import_type', 'uploaded_by', 'uploaded_at', 'status', 'summary')
    list_filter = ('status', 'import_type', 'uploaded_at')
    search_fields = ('file_name', 'summary')
    readonly_fields = ('file_name', 'uploaded_by', 'uploaded_at', 'status', 'import_type', 'summary')
    inlines = [CSVImportRowErrorInline]

@admin.register(LogisticsWebhookTarget)
class LogisticsWebhookTargetAdmin(admin.ModelAdmin):
    list_display = ('url', 'is_active', 'created_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('url',)