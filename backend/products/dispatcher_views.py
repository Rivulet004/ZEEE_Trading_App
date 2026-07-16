from django.shortcuts import render, redirect
from django.views import View
from django.contrib.auth import authenticate, login
from django.contrib.auth.mixins import LoginRequiredMixin, UserPassesTestMixin
from django.http import JsonResponse, Http404, HttpResponse
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
import json

from products.models import Order
from products.pdf import generate_invoice_pdf
from products.notifications import send_status_update_email

class DispatcherStaffRequiredMixin(LoginRequiredMixin, UserPassesTestMixin):
    login_url = '/dispatcher/login/'
    redirect_field_name = 'next'

    def test_func(self):
        return self.request.user.is_authenticated and (self.request.user.is_staff or self.request.user.groups.filter(name='dispatchers').exists())

class DispatcherLoginView(View):
    def get(self, request):
        if request.user.is_authenticated and (request.user.is_staff or request.user.groups.filter(name='dispatchers').exists()):
            return redirect('dispatcher_dashboard')
        return render(request, 'dispatcher/login.html')

    def post(self, request):
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        user = authenticate(request, username=username, password=password)
        if user is not None and (user.is_staff or user.groups.filter(name='dispatchers').exists()):
            login(request, user)
            next_url = request.GET.get('next', 'dispatcher_dashboard')
            return redirect(next_url)
        else:
            return render(request, 'dispatcher/login.html', {'error': 'Invalid dispatcher credentials or insufficient permissions.'})

class DispatcherDashboardView(DispatcherStaffRequiredMixin, View):
    def get(self, request):
        return render(request, 'dispatcher/dashboard.html')

class DispatcherOrderApiView(DispatcherStaffRequiredMixin, View):
    def get(self, request):
        orders = Order.objects.select_related('location__company', 'user').prefetch_related('items__product').order_by('-created_at')
        data = []
        for o in orders:
            items_list = []
            for item in o.items.all():
                items_list.append({
                    'product_sku': item.product.sku,
                    'product_name': item.product.name,
                    'quantity': item.quantity,
                    'price_paid': str(item.price_paid),
                })
            
            data.append({
                'id': o.id,
                'company_name': o.location.company.legal_name if (o.location and o.location.company) else 'Unknown Company',
                'location_name': o.location.location_name if o.location else 'Unknown Hub',
                'delivery_address': o.location.delivery_address if o.location else '',
                'delivery_date': o.delivery_date.strftime('%Y-%m-%d') if o.delivery_date else 'Not Selected',
                'total_amount': str(o.total_amount),
                'status': o.status,
                'created_at': o.created_at.isoformat(),
                'items': items_list
            })
        return JsonResponse(data, safe=False)

@method_decorator(csrf_exempt, name='dispatch')
class DispatcherOrderStatusView(DispatcherStaffRequiredMixin, View):
    def post(self, request, order_id):
        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return JsonResponse({'error': 'Order not found'}, status=404)
        
        if request.content_type == 'application/json':
            try:
                payload = json.loads(request.body)
                new_status = payload.get('status')
            except Exception:
                new_status = None
        else:
            new_status = request.POST.get('status')

        if new_status:
            new_status = new_status.upper()

        if new_status not in ['PENDING', 'APPROVED', 'SHIPPED', 'DELIVERED', 'CANCELLED']:
            return JsonResponse({'error': f'Invalid status: {new_status}'}, status=400)

        order.status = new_status
        order.save()

        send_status_update_email(order)
        
        return JsonResponse({'success': True, 'new_status': order.status})

class DispatcherInvoicePdfView(DispatcherStaffRequiredMixin, View):
    def get(self, request, order_id):
        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            raise Http404("Order not found")
        
        pdf_data = generate_invoice_pdf(order)
        response = HttpResponse(pdf_data, content_type='application/pdf')
        response['Content-Disposition'] = f'inline; filename="invoice_PO_{order_id}.pdf"'
        return response
