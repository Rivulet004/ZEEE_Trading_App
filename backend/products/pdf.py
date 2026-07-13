from io import BytesIO
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors

def generate_invoice_pdf(order):
    """
    Constructs an accounting-compliant B2B commercial PDF invoice using ReportLab.
    Dynamically embeds company details, shipping context, snapshots, and item ledgers.
    """
    buffer = BytesIO()
    
    # Establish document setup (printable area: 540pt width)
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )
    
    story = []
    
    # Styles
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'InvoiceTitleStyle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=colors.HexColor("#1A365D"),
        spaceAfter=15
    )
    
    section_title_style = ParagraphStyle(
        'SectionTitleStyle',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=colors.HexColor("#2C5282"),
        spaceBefore=10,
        spaceAfter=5
    )
    
    body_style = ParagraphStyle(
        'InvoiceBodyStyle',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#2D3748")
    )
    
    bold_body_style = ParagraphStyle(
        'InvoiceBoldBodyStyle',
        parent=body_style,
        fontName='Helvetica-Bold'
    )

    # 1. Header Information Table
    header_data = [
        [
            Paragraph("B2B WHOLESALE SUPPLY", title_style),
            Paragraph(f"<b>INVOICE PO #{order.id}</b>", ParagraphStyle('InvoicePO', parent=title_style, alignment=2))
        ],
        [
            Paragraph(f"<b>Date:</b> {order.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}", body_style),
            Paragraph(f"<b>Status:</b> {order.get_status_display()}", ParagraphStyle('InvoiceStatus', parent=body_style, alignment=2))
        ]
    ]
    header_table = Table(header_data, colWidths=[270, 270])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 20))
    
    # 2. Company & Delivery Context Table
    company = order.user.company
    location = order.location
    
    buyer_info = f"""
    <b>Corporate Client:</b><br/>
    {company.legal_name if company else 'Individual Account'}<br/>
    Corporate Email: {company.corporate_email if company else order.user.email}<br/>
    Buyer: {order.user.get_full_name() or order.user.username} ({order.user.email})
    """
    
    delivery_info = f"""
    <b>Shipping Location & Compliance:</b><br/>
    {order.delivery_address_snapshot.replace('\n', '<br/>')}<br/>
    Verified Tax ID: {order.sales_tax_id_snapshot}
    """
    
    context_data = [
        [Paragraph(buyer_info, body_style), Paragraph(delivery_info, body_style)]
    ]
    context_table = Table(context_data, colWidths=[270, 270])
    context_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F7FAFC")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#E2E8F0")),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(context_table)
    story.append(Spacer(1, 25))
    
    # 3. Product Catalog Table
    story.append(Paragraph("ORDER DETAILS", section_title_style))
    
    # Table headers
    items_data = [[
        Paragraph("<b>SKU</b>", bold_body_style),
        Paragraph("<b>Product Description</b>", bold_body_style),
        Paragraph("<b>UOM</b>", bold_body_style),
        Paragraph("<b>Price</b>", bold_body_style),
        Paragraph("<b>Qty</b>", bold_body_style),
        Paragraph("<b>Line Total</b>", bold_body_style)
    ]]
    
    # Table rows
    for item in order.items.all().select_related('product'):
        line_total = item.price_paid * item.quantity
        items_data.append([
            Paragraph(item.product.sku, body_style),
            Paragraph(item.product.name, body_style),
            Paragraph(item.product.unit_of_measure, body_style),
            Paragraph(f"${item.price_paid}", body_style),
            Paragraph(str(item.quantity), body_style),
            Paragraph(f"${line_total}", body_style)
        ])
        
    # Totals rows
    items_data.append([
        "", "", "", "",
        Paragraph("<b>Subtotal:</b>", body_style),
        Paragraph(f"${order.total_amount}", body_style)
    ])
    items_data.append([
        "", "", "", "",
        Paragraph("<b>Sales Tax:</b>", body_style),
        Paragraph(f"${order.tax_amount} (Tax Exempt)", body_style)
    ])
    items_data.append([
        "", "", "", "",
        Paragraph("<b>Total Amount:</b>", bold_body_style),
        Paragraph(f"<b>${order.total_amount}</b>", bold_body_style)
    ])
    
    # Col widths summing up to 540 (printable page width)
    items_table = Table(items_data, colWidths=[90, 180, 80, 60, 50, 80])
    
    table_styles = [
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EDF2F7")),
        ('BOTTOMPADDING', (0,0), (-1,0), 8),
        ('TOPPADDING', (0,0), (-1,0), 8),
        ('GRID', (0,0), (-1,-4), 0.5, colors.HexColor("#E2E8F0")),
        # Style for total rows
        ('SPAN', (0,-3), (3,-3)),
        ('SPAN', (0,-2), (3,-2)),
        ('SPAN', (0,-1), (3,-1)),
        ('TOPPADDING', (4,-3), (-1,-1), 6),
        ('BOTTOMPADDING', (4,-3), (-1,-1), 6),
        ('LINEABOVE', (4,-3), (5,-3), 1, colors.HexColor("#1A365D")),
        ('LINEABOVE', (4,-1), (5,-1), 1.5, colors.HexColor("#1A365D")),
    ]
    items_table.setStyle(TableStyle(table_styles))
    story.append(items_table)
    story.append(Spacer(1, 30))
    
    # Footer Notice
    footer_text = f"""
    This purchase is registered as Tax Exempt under Sales Tax ID: {order.sales_tax_id_snapshot}.<br/>
    If you have any questions regarding wholesale orders, credit lines, or logistics processing,
    please reach out to support at billing@zevron.com or call the regional fulfillment desk.
    """
    story.append(Paragraph(footer_text, ParagraphStyle('InvoiceFooter', parent=body_style, fontSize=8, leading=11, textColor=colors.HexColor("#718096"), alignment=1)))
    
    doc.build(story)
    pdf_content = buffer.getvalue()
    buffer.close()
    return pdf_content
