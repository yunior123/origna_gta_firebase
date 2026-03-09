"""PDF Invoice Generator for Origna GTA

Generates professional bilingual (EN/FR) PDF invoices attached to order confirmation emails.
Uses reportlab for PDF generation.

Quebec Bill 96 Compliance: All invoices support both English and French based on
the buyer's preferredLanguage field.

Dependencies: reportlab (add to requirements.txt)
"""

import io
import logging
from datetime import datetime

from schema_constants import AppConfig, EmailConfig, Fields

logger = logging.getLogger(__name__)

try:
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_RIGHT
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import inch
    from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

    HAS_REPORTLAB = True
except ImportError:
    HAS_REPORTLAB = False
    logger.warning("reportlab not installed — PDF invoice generation disabled. Run: pip install reportlab")


# ===========================================================================
# BILINGUAL INVOICE STRINGS (EN / FR — Quebec Bill 96 Compliance)
# ===========================================================================

_INVOICE_STRINGS: dict[str, dict[str, str]] = {
    "invoice_title": {"en": "INVOICE", "fr": "FACTURE"},
    "bill_to": {"en": "Bill To / Ship To:", "fr": "Facturer à / Expédier à :"},
    "order_id_label": {"en": "Order ID:", "fr": "N° de commande :"},
    "order_date_label": {"en": "Date:", "fr": "Date :"},
    "gst_hst_label": {"en": "GST/HST:", "fr": "TPS/TVH :"},
    "status_label": {"en": "Status:", "fr": "Statut :"},
    "phone_label": {"en": "Phone:", "fr": "Tél. :"},
    "email_label": {"en": "Email:", "fr": "Courriel :"},
    "items_header": {"en": "Items", "fr": "Articles"},
    "col_product": {"en": "Product", "fr": "Produit"},
    "col_qty": {"en": "Qty", "fr": "Qté"},
    "col_unit_price": {"en": "Unit Price", "fr": "Prix unitaire"},
    "col_total": {"en": "Total", "fr": "Total"},
    "subtotal": {"en": "Subtotal", "fr": "Sous-total"},
    "shipping": {"en": "Shipping", "fr": "Livraison"},
    "shipping_free": {"en": "Free", "fr": "Gratuit"},
    "taxes_total": {"en": "Taxes Total", "fr": "Total des taxes"},
    "total_cad": {"en": "TOTAL (CAD)", "fr": "TOTAL (CAD)"},
    "footer_thanks": {
        "en": "Thank you for shopping with Origna! For questions:",
        "fr": "Merci de magasiner chez Origna ! Pour toute question :",
    },
}


def _t(key: str, lang: str) -> str:
    """Translate a key to the given language (defaults to 'en' if key or lang not found)."""
    return _INVOICE_STRINGS.get(key, {}).get(lang if lang in ("en", "fr") else "en", key)


def generate_invoice_pdf(order_data: dict, order_id: str, preferred_language: str = "en") -> bytes | None:
    """Generate a bilingual PDF invoice for an order.

    Args:
        order_data: Order dict from Firestore
        order_id: Order document ID
        preferred_language: 'en' or 'fr' (Quebec Bill 96 compliance). Defaults to 'en'.

    Returns:
        PDF bytes or None if reportlab is not installed
    """
    if not HAS_REPORTLAB:
        logger.warning("reportlab not available — skipping PDF invoice generation")
        return None

    # Normalize language
    lang = preferred_language.lower()[:2] if preferred_language else "en"
    if lang not in ("en", "fr"):
        lang = "en"

    try:
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=50,
            leftMargin=50,
            topMargin=40,
            bottomMargin=40,
        )

        styles = getSampleStyleSheet()

        # Custom styles
        title_style = ParagraphStyle(
            "InvoiceTitle",
            parent=styles["Heading1"],
            fontSize=24,
            spaceAfter=4,
            textColor=colors.HexColor("#1F235A"),
            fontName="Helvetica-Bold",
        )
        subtitle_style = ParagraphStyle(
            "InvoiceSubtitle",
            parent=styles["Normal"],
            fontSize=10,
            textColor=colors.HexColor("#666666"),
        )
        header_style = ParagraphStyle(
            "SectionHeader",
            parent=styles["Heading2"],
            fontSize=12,
            spaceAfter=8,
            spaceBefore=16,
            textColor=colors.HexColor("#1F235A"),
            fontName="Helvetica-Bold",
        )
        normal_style = ParagraphStyle(
            "InvoiceNormal",
            parent=styles["Normal"],
            fontSize=10,
            leading=14,
            textColor=colors.HexColor("#333333"),
        )
        small_style = ParagraphStyle(
            "InvoiceSmall",
            parent=styles["Normal"],
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#888888"),
        )
        right_style = ParagraphStyle(
            "RightAligned",
            parent=normal_style,
            alignment=TA_RIGHT,
        )
        center_style = ParagraphStyle(
            "CenterAligned",
            parent=small_style,
            alignment=TA_CENTER,
        )

        elements = []

        # ── HEADER ──────────────────────────────────────────────
        short_oid = order_id[:8] if len(order_id) > 8 else order_id

        # Localized date format
        now = datetime.now()
        if lang == "fr":
            months_fr = [
                "janvier", "février", "mars", "avril", "mai", "juin",
                "juillet", "août", "septembre", "octobre", "novembre", "décembre",
            ]
            order_date = f"{now.day} {months_fr[now.month - 1]} {now.year}"
        else:
            order_date = now.strftime("%B %d, %Y")

        header_data = [
            [
                Paragraph("ORIGNA", title_style),
                Paragraph(
                    f'<b>{_t("invoice_title", lang)}</b><br/><font size="9">#{short_oid}</font>',
                    right_style,
                ),
            ],
            [
                Paragraph("Origna Ventures Inc.", subtitle_style),
                Paragraph(
                    f'{_t("order_date_label", lang)} {order_date}',
                    ParagraphStyle("rd", parent=right_style, fontSize=9, textColor=colors.HexColor("#666666")),
                ),
            ],
            [
                Paragraph(EmailConfig.PHYSICAL_ADDRESS, subtitle_style),
                Paragraph(
                    f'{_t("gst_hst_label", lang)} {EmailConfig.GST_HST_NUMBER}',
                    ParagraphStyle("rd2", parent=right_style, fontSize=9, textColor=colors.HexColor("#666666")),
                ),
            ],
        ]
        header_table = Table(header_data, colWidths=[3.5 * inch, 3.5 * inch])
        header_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
                ]
            )
        )
        elements.append(header_table)
        elements.append(Spacer(1, 8))
        elements.append(HRFlowable(width="100%", thickness=2, color=colors.HexColor("#667EEA")))
        elements.append(Spacer(1, 16))

        # ── BILL TO / SHIP TO ───────────────────────────────────
        shipping = order_data.get(Fields.SHIPPING_ADDRESS, {})
        customer_email = order_data.get(Fields.CUSTOMER_EMAIL, "N/A")
        address_lines = [
            shipping.get(Fields.STREET, ""),
            shipping.get(Fields.APARTMENT, ""),
            f"{shipping.get(Fields.CITY, '')}, {shipping.get(Fields.STATE, '')} {shipping.get(Fields.POSTAL_CODE, '')}",
            shipping.get(Fields.COUNTRY, AppConfig.DEFAULT_COUNTRY_NAME),
        ]
        address_text = "<br/>".join(line for line in address_lines if line and line.strip())
        phone = shipping.get(Fields.PHONE_NUMBER, "")
        if phone:
            address_text += f"<br/>{_t('phone_label', lang)} {phone}"

        bill_data = [
            [
                Paragraph(f"<b>{_t('bill_to', lang)}</b>", normal_style),
                Paragraph(f"<b>{_t('order_id_label', lang)}</b> {order_id}", normal_style),
            ],
            [
                Paragraph(f"{address_text}<br/>{_t('email_label', lang)} {customer_email}", normal_style),
                Paragraph(
                    f"<b>{_t('status_label', lang)}</b> {order_data.get(Fields.ORDER_STATUS, 'confirmed').title()}",
                    normal_style,
                ),
            ],
        ]
        bill_table = Table(bill_data, colWidths=[3.5 * inch, 3.5 * inch])
        bill_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ]
            )
        )
        elements.append(bill_table)
        elements.append(Spacer(1, 20))

        # ── ITEMS TABLE ─────────────────────────────────────────
        elements.append(Paragraph(_t("items_header", lang), header_style))

        items = order_data.get(Fields.ITEMS, [])
        table_data = [
            [
                Paragraph(
                    f"<b>{_t('col_product', lang)}</b>",
                    ParagraphStyle("th", parent=normal_style, textColor=colors.white, fontSize=9),
                ),
                Paragraph(
                    f"<b>{_t('col_qty', lang)}</b>",
                    ParagraphStyle("thc", parent=normal_style, textColor=colors.white, fontSize=9, alignment=TA_CENTER),
                ),
                Paragraph(
                    f"<b>{_t('col_unit_price', lang)}</b>",
                    ParagraphStyle("thr", parent=normal_style, textColor=colors.white, fontSize=9, alignment=TA_RIGHT),
                ),
                Paragraph(
                    f"<b>{_t('col_total', lang)}</b>",
                    ParagraphStyle("thr2", parent=normal_style, textColor=colors.white, fontSize=9, alignment=TA_RIGHT),
                ),
            ]
        ]

        for item in items:
            name = item.get(Fields.NAME, "Product")
            qty = item.get(Fields.QUANTITY, 1)
            price = item.get(Fields.PRICE, 0)
            line_total = price * qty
            table_data.append(
                [
                    Paragraph(str(name), normal_style),
                    Paragraph(str(qty), ParagraphStyle("tc", parent=normal_style, alignment=TA_CENTER)),
                    Paragraph(f"${price:.2f}", ParagraphStyle("tr", parent=normal_style, alignment=TA_RIGHT)),
                    Paragraph(
                        f"${line_total:.2f}",
                        ParagraphStyle("tr2", parent=normal_style, alignment=TA_RIGHT, fontName="Helvetica-Bold"),
                    ),
                ]
            )

        items_table = Table(table_data, colWidths=[3 * inch, 0.8 * inch, 1.3 * inch, 1.3 * inch])
        items_table.setStyle(
            TableStyle(
                [
                    # Header row
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#667EEA")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("FONTSIZE", (0, 0), (-1, 0), 9),
                    ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
                    ("TOPPADDING", (0, 0), (-1, 0), 8),
                    # Body rows
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f8f9ff")]),
                    ("BOTTOMPADDING", (0, 1), (-1, -1), 6),
                    ("TOPPADDING", (0, 1), (-1, -1), 6),
                    # Grid
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#e0e3f0")),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                    ("ROUNDEDCORNERS", [4, 4, 4, 4]),
                ]
            )
        )
        elements.append(items_table)
        elements.append(Spacer(1, 20))

        # ── TOTALS ──────────────────────────────────────────────
        subtotal = order_data.get(Fields.SUBTOTAL_CENTS, 0) / 100
        shipping_cost = order_data.get(Fields.SHIPPING_COST_CENTS, 0) / 100
        taxes_dict = order_data.get(Fields.TAXES, {})
        taxes_total = sum(taxes_dict.values())
        total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100

        summary_data = [
            [_t("subtotal", lang), f"${subtotal:.2f}"],
            [
                _t("shipping", lang),
                _t("shipping_free", lang) if shipping_cost == 0 else f"${shipping_cost:.2f}",
            ],
        ]

        # Itemized tax breakdown
        for tax_name, tax_amount in sorted(taxes_dict.items()):
            summary_data.append([f"  {tax_name}", f"${tax_amount:.2f}"])

        summary_data.append([_t("taxes_total", lang), f"${taxes_total:.2f}"])

        # Total row (special styling)
        summary_data.append([_t("total_cad", lang), f"${total:.2f}"])

        summary_table = Table(summary_data, colWidths=[2 * inch, 1.5 * inch])
        summary_table.setStyle(
            TableStyle(
                [
                    ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                    ("FONTSIZE", (0, 0), (-1, -1), 10),
                    ("TEXTCOLOR", (0, 0), (-1, -2), colors.HexColor("#555555")),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                    ("TOPPADDING", (0, 0), (-1, -1), 4),
                    # Total row
                    ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
                    ("FONTSIZE", (0, -1), (-1, -1), 13),
                    ("TEXTCOLOR", (0, -1), (-1, -1), colors.HexColor("#667EEA")),
                    ("LINEABOVE", (0, -1), (-1, -1), 1, colors.HexColor("#667EEA")),
                    ("TOPPADDING", (0, -1), (-1, -1), 8),
                ]
            )
        )

        # Right-align the summary block
        wrapper = Table([[None, summary_table]], colWidths=[3 * inch, 3.5 * inch])
        wrapper.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
        elements.append(wrapper)
        elements.append(Spacer(1, 30))

        # ── FOOTER ──────────────────────────────────────────────
        elements.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#e0e3f0")))
        elements.append(Spacer(1, 8))
        elements.append(
            Paragraph(
                f"{_t('footer_thanks', lang)} {EmailConfig.SUPPORT_EMAIL}",
                center_style,
            )
        )
        elements.append(
            Paragraph(f"{EmailConfig.PHYSICAL_ADDRESS} | GST/HST: {EmailConfig.GST_HST_NUMBER}", center_style)
        )
        elements.append(Paragraph(f"{EmailConfig.COPYRIGHT_TEXT}", center_style))

        doc.build(elements)
        pdf_bytes = buffer.getvalue()
        buffer.close()

        logger.info(f"📄 PDF invoice generated for order {order_id} ({len(pdf_bytes)} bytes, lang={lang})")
        return pdf_bytes

    except Exception as e:
        logger.error(f"❌ Failed to generate PDF invoice for order {order_id}: {str(e)}")
        return None
