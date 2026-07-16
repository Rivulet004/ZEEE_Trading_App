"""
URL configuration for core_backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path
from django.contrib.auth import views as auth_views
from django.conf import settings
from django.conf.urls.static import static
from accounts.views import (
    EnterpriseRegisterView, 
    CustomTokenObtainPairView, 
    CheckTokenView, 
    PasswordResetRequestView,
    CompanyLocationListView,
    CompanyTeamListView,
    CompanyTeamDetailView
)
from products.views import (
    ProductPriceEvaluationView, 
    InventoryCheckoutView, 
    CustomerOrderHistoryView, 
    ProductCatalogListView,
    ProductCategoryListView,
    OrderGuideListView,
    ZipCodeDeliveryRouteView,
    SystemAlertListView
)
from products.dispatcher_views import (
    DispatcherLoginView,
    DispatcherDashboardView,
    DispatcherOrderApiView,
    DispatcherOrderStatusView,
    DispatcherInvoicePdfView
)

urlpatterns = [
    # Master Django Administrative Portal Route Gateway
    path('admin/', admin.site.urls),
    
    # Core Account API Endpoint Interfaces targeted by the Flutter frontend client
    path('api/accounts/register/', EnterpriseRegisterView.as_view(), name='api_register'),
    path('api/accounts/login/', CustomTokenObtainPairView.as_view(), name='api_login'),
    path('api/accounts/check-token/', CheckTokenView.as_view(), name='api_check_token'),
    path('api/accounts/password-reset/', PasswordResetRequestView.as_view(), name='api_password_reset'),
    path('api/accounts/locations/', CompanyLocationListView.as_view(), name='api_locations_list'),
    path('api/accounts/team/', CompanyTeamListView.as_view(), name='api_team_list'),
    path('api/accounts/team/<int:pk>/', CompanyTeamDetailView.as_view(), name='api_team_detail'),
    
    # Native web interface handlers providing the execution screens for inputting new passwords
    path('reset/<uidb64>/<token>/', 
         auth_views.PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('reset/done/', 
         auth_views.PasswordResetCompleteView.as_view(), name='password_reset_complete'),
    path('api/products/<str:sku>/price/', ProductPriceEvaluationView.as_view(), name='product_price_check'),
    path('api/v1/checkout/', InventoryCheckoutView.as_view(), name='api_cart_checkout'),
    path('api/v1/orders/history/', CustomerOrderHistoryView.as_view(), name='customer_order_history'),
    path('api/v1/products/', ProductCatalogListView.as_view(), name='api_products_list'),
    path('api/v1/categories/', ProductCategoryListView.as_view(), name='api_categories_list'),
    path('api/v1/products/order-guide/', OrderGuideListView.as_view(), name='api_order_guide'),
    path('api/v1/delivery-route/', ZipCodeDeliveryRouteView.as_view(), name='api_delivery_route'),
    path('api/v1/alerts/', SystemAlertListView.as_view(), name='api_alerts_list'),
    
    # Dispatcher Portal routing rules
    path('dispatcher/login/', DispatcherLoginView.as_view(), name='dispatcher_login'),
    path('dispatcher/', DispatcherDashboardView.as_view(), name='dispatcher_dashboard'),
    path('dispatcher/api/orders/', DispatcherOrderApiView.as_view(), name='dispatcher_api_orders'),
    path('dispatcher/order/<int:order_id>/status/', DispatcherOrderStatusView.as_view(), name='dispatcher_status_update'),
    path('dispatcher/order/<int:order_id>/invoice/', DispatcherInvoicePdfView.as_view(), name='dispatcher_invoice_pdf'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)