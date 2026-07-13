from django.core.mail import EmailMessage
from django.conf import settings

def send_invoice_email(order, pdf_content):
    """
    Constructs and dispatches the commercial invoice confirmation email
    with the generated PDF invoice attached.
    """
    subject = f"B2B Wholesale Order PO #{order.id} Confirmation - Tax Exempt"
    
    body = f"""Hi {order.user.first_name or order.user.username},

Thank you for your order! Your purchase order PO #{order.id} has been received and is being processed by our logistics team.

Summary details:
- Company: {order.user.company.legal_name if order.user.company else 'N/A'}
- Purchase Order: PO #{order.id}
- Total Amount: ${order.total_amount} (Tax Exempt)
- Delivery Target: {order.location.location_name}
- Delivery Address:
{order.delivery_address_snapshot}

Please find your official accounting-compliant PDF invoice attached to this email.

Best regards,
B2B Wholesale Portal Operations
Fulfillment and Logistics Center
"""

    email = EmailMessage(
        subject=subject,
        body=body,
        from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@zevron.com'),
        to=[order.user.email],
    )
    
    # Attach the invoice PDF
    email.attach(
        filename=f"invoice_PO_{order.id}.pdf",
        content=pdf_content,
        mimetype="application/pdf"
    )
    
    email.send(fail_silently=False)


import urllib.request
import json
import threading

def send_webhook_request(url, payload):
    """Executes the HTTP POST request to the webhook receiver target URL."""
    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        # 3 seconds timeout to prevent blocking thread execution
        with urllib.request.urlopen(req, timeout=3) as response:
            pass
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Webhook dispatch failed to target URL '{url}': {str(e)}")

def trigger_order_webhook(order, event_type):
    """
    Spawns background daemon thread to dispatch JSON order notifications 
    to all active registered LogisticsWebhookTarget instances.
    """
    from products.models import LogisticsWebhookTarget
    
    active_targets = LogisticsWebhookTarget.objects.filter(is_active=True)
    if not active_targets.exists():
        return

    payload = {
        "event_type": event_type,
        "order_id": order.id,
        "status": order.status,
        "company_name": order.location.company.legal_name if order.location and order.location.company else "Individual Client",
        "delivery_target": order.location.location_name if order.location else "N/A",
        "delivery_address_snapshot": order.delivery_address_snapshot,
        "total_amount": str(order.total_amount),
        "tax_amount": str(order.tax_amount),
        "created_at": order.created_at.isoformat() if order.created_at else None
    }

    for target in active_targets:
        threading.Thread(
            target=send_webhook_request, 
            args=(target.url, payload), 
            daemon=True
        ).start()
