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
