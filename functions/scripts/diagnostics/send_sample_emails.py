#!/usr/bin/env python3
"""Send sample of every email type to test inboxes via Mailjet API.

Usage:
    cd functions && source venv/bin/activate && python send_sample_emails.py
"""

import os
import sys
import time

# Load .env
from dotenv import load_dotenv

load_dotenv()

# Force real email sending even if in emulator mode
os.environ["FORCE_REAL_EMAIL"] = "true"
os.environ["FUNCTIONS_EMULATOR"] = "true"

sys.path.insert(0, os.path.dirname(__file__))

from mailjet_rest import Client

from config import MAILJET_API_KEY, MAILJET_SECRET_KEY
from schema_constants import EmailConfig

# ── Recipients ──────────────────────────────────────────────────────
RECIPIENTS = [
    "yr628132@gmail.com",
    "yuniorrodriguezo4601@yahoo.com",
]

# ── Mock order data (realistic) ────────────────────────────────────
MOCK_ORDER_DATA = {
    "orderId": "ORD7f3a9c2e4b1d6e8f",
    "customerEmail": "yr628132@gmail.com",
    "items": [
        {"name": "Sony WH-1000XM5 Wireless Headphones", "quantity": 1, "price": 449.99},
        {"name": "Apple AirTag (4 Pack)", "quantity": 2, "price": 129.00},
        {"name": "Anker USB-C Fast Charger 65W", "quantity": 1, "price": 45.99},
    ],
    "subtotalCents": 75398,  # $753.98
    "shippingCostCents": 1299,  # $12.99
    "taxes": {
        "GST (5%)": 37.70,
        "PST (8%)": 60.32,
    },
    "totalAmountCents": 86429,  # $864.29
    "shippingAddress": {
        "street": "456 King Street West",
        "apartment": "Unit 1204",
        "city": "Toronto",
        "state": "ON",
        "postalCode": "M5V 1K4",
        "country": "Canada",
        "phoneNumber": "+1 (416) 555-0192",
    },
    "sellerIds": ["seller_abc123"],
}

MOCK_ORDER_ID = "ORD7f3a9c2e4b1d6e8f"


def send_to_all(subject: str, html_content: str, tag: str):
    """Send an email to all recipients via Mailjet."""
    mailjet = Client(
        auth=(MAILJET_API_KEY, MAILJET_SECRET_KEY),
        version=EmailConfig.MAILJET_API_VERSION,
    )

    # SPF + DKIM now configured for orignaventures.ca
    for recipient in RECIPIENTS:
        data = {
            "Messages": [
                {
                    "From": {
                        "Email": EmailConfig.SUPPORT_EMAIL,
                        "Name": EmailConfig.SENDER_NAME,
                    },
                    "To": [{"Email": recipient}],
                    "Subject": f"[SAMPLE] {subject}",
                    "HTMLPart": html_content,
                    "CustomCampaign": f"sample-{tag}",
                }
            ]
        }

        result = mailjet.send.create(data=data)
        if result.status_code == 200:
            print(f"  ✅ Sent to {recipient}")
        else:
            print(f"  ❌ Failed for {recipient}: {result.json()}")

    # Small delay to avoid rate limiting
    time.sleep(1)


def main():
    """Function main."""
    print("=" * 60)
    print("📧 Sending ALL email samples via Mailjet")
    print(f"   Recipients: {', '.join(RECIPIENTS)}")
    print("=" * 60)

    # Import email generators
    from services.email_service import (
        get_order_cancelled_email,
        get_order_confirmation_email,
        get_order_delivered_email,
        get_order_shipped_email,
        get_seller_notification_email,
    )

    # ── 1. Order Confirmation (Buyer) ───────────────────────────────
    print("\n1/7  📦 Order Confirmation (Buyer)...")
    html = get_order_confirmation_email(MOCK_ORDER_DATA, MOCK_ORDER_ID)
    send_to_all(
        f"Order Confirmed — #{MOCK_ORDER_ID[:8]}",
        html,
        "order-confirmation",
    )

    # ── 2. Seller Notification ──────────────────────────────────────
    print("\n2/7  💰 New Order (Seller Notification)...")
    html = get_seller_notification_email(MOCK_ORDER_DATA, MOCK_ORDER_ID)
    send_to_all(
        f"New Order Received — #{MOCK_ORDER_ID[:8]}",
        html,
        "seller-notification",
    )

    # ── 3. Order Shipped ────────────────────────────────────────────
    print("\n3/7  🚚 Order Shipped...")
    html = get_order_shipped_email(
        MOCK_ORDER_DATA,
        MOCK_ORDER_ID,
        tracking_number="CP1234567890CA",
        carrier="Canada Post",
    )
    send_to_all(
        f"Your Order Has Shipped — #{MOCK_ORDER_ID[:8]}",
        html,
        "order-shipped",
    )

    # ── 4. Order Delivered ──────────────────────────────────────────
    print("\n4/7  🏠 Order Delivered...")
    html = get_order_delivered_email(MOCK_ORDER_DATA, MOCK_ORDER_ID)
    send_to_all(
        f"Your Order Has Been Delivered — #{MOCK_ORDER_ID[:8]}",
        html,
        "order-delivered",
    )

    # ── 5. Order Cancelled ──────────────────────────────────────────
    print("\n5/7  ❌ Order Cancelled...")
    html = get_order_cancelled_email(
        MOCK_ORDER_DATA,
        MOCK_ORDER_ID,
        reason="Seller unable to fulfill — item out of stock",
    )
    send_to_all(
        f"Order Cancelled — #{MOCK_ORDER_ID[:8]}",
        html,
        "order-cancelled",
    )

    # ── 6. Payment Capture Failed ───────────────────────────────────
    print("\n6/7  ⚠️ Payment Capture Failed...")
    # This one builds its own full HTML internally, so we call the generator part manually
    from services.email_service import APP_BASE_URL, _casl_compliant_footer

    customer_name = "Yunior Rodriguez"
    amount = 864.29
    error_message = "Card declined — insufficient funds"

    capture_failed_html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Issue - Origna</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f0f2f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
        <div style="display:none;font-size:1px;color:#f0f2f8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">Action required: payment issue with order #{MOCK_ORDER_ID[:8]}</div>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f0f2f8;">
        <tr><td align="center" style="padding: 24px 16px;">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background-color: #ffffff; border-radius: 20px; overflow: hidden;">

        <tr><td bgcolor="#1F235A" style="background-color: #1F235A; padding: 40px 40px 32px 40px; text-align: center;">
            <div style="margin-bottom: 8px;">
                <span style="font-size: 14px; font-weight: 700; letter-spacing: 4px; text-transform: uppercase; color: #9999b3;">O R I G N A</span>
            </div>
            <div style="font-size: 48px; margin: 12px 0;">⚠️</div>
            <h1 style="margin: 12px 0 8px 0; font-size: 24px; font-weight: 800; color: #ffffff;">Payment Issue</h1>
            <p style="margin: 0; font-size: 14px; color: #b0b0cc;">Action required for Order #{MOCK_ORDER_ID[:8]}</p>
        </td></tr>

        <tr><td bgcolor="#FEF3C7" style="background-color: #FEF3C7; border-left: 4px solid #F59E0B; padding: 16px 40px;">
            <span style="font-size: 14px; font-weight: 700; color: #92400E;">⚠️ Action Required</span><br>
            <span style="font-size: 14px; color: #78350F;">We couldn't complete the payment for your order.</span>
        </td></tr>

        <tr><td style="padding: 28px 40px;">
            <p style="margin: 0 0 20px 0; font-size: 15px; color: #333;">Hi {customer_name},</p>

            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f8f9ff; border-radius: 12px; border: 1px solid #e5e8f5; margin-bottom: 24px;">
            <tr><td style="padding: 16px 20px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">Order ID:</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 600;">{MOCK_ORDER_ID[:8]}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">Amount:</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 600;">${amount:.2f} CAD</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">Issue:</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #dc2626; text-align: right; font-weight: 500;">{error_message}</td>
                    </tr>
                </table>
            </td></tr>
            </table>

            <p style="margin: 0 0 8px 0; font-size: 15px; font-weight: 700; color: #1a1a2e;">What happened?</p>
            <p style="margin: 0 0 12px 0; font-size: 14px; color: #555; line-height: 1.6;">Your payment was authorized but couldn't be charged. Common causes:</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">&bull; Card has insufficient funds</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">&bull; Card was canceled or expired</p>
            <p style="margin: 0 0 20px 0; font-size: 14px; color: #555;">&bull; Bank declined the transaction</p>

            <p style="margin: 0 0 8px 0; font-size: 15px; font-weight: 700; color: #1a1a2e;">Next steps:</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">1. Log in to your account</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">2. Update your payment method</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">3. Contact your bank if the issue persists</p>
        </td></tr>

        <tr><td style="padding: 0 40px 28px 40px; text-align: center;">
            <table role="presentation" cellspacing="0" cellpadding="0" align="center" style="margin: 0 auto;"><tr>
            <td align="center" bgcolor="#667EEA" style="background-color: #667EEA; border-radius: 50px;">
                <a href="{APP_BASE_URL}/orders/{MOCK_ORDER_ID}" target="_blank" style="display: inline-block; padding: 14px 40px; font-size: 15px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px;">View Order</a>
            </td>
            </tr></table>
        </td></tr>

        <tr><td style="padding: 0 40px 24px 40px;">
            <p style="margin: 0; font-size: 13px; color: #888; text-align: center;">Need help? Contact us with order ID: <strong>{MOCK_ORDER_ID[:8]}</strong></p>
        </td></tr>

        {_casl_compliant_footer(include_gst=False)}

        </table>
        </td></tr>
        </table>
    </body>
    </html>
    """

    send_to_all(
        f"Payment Issue — Order #{MOCK_ORDER_ID[:8]}",
        capture_failed_html,
        "capture-failed",
    )

    # ── 7. Authorization Expired ────────────────────────────────────
    print("\n7/7  ⏰ Authorization Expired...")

    auth_expired_html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Authorization Expired - Origna</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f0f2f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f0f2f8;">
        <tr><td align="center" style="padding: 24px 16px;">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background-color: #ffffff; border-radius: 20px; overflow: hidden;">

        <tr><td bgcolor="#1F235A" style="background-color: #1F235A; padding: 40px 40px 32px 40px; text-align: center;">
            <div style="margin-bottom: 8px;">
                <span style="font-size: 14px; font-weight: 700; letter-spacing: 4px; text-transform: uppercase; color: #9999b3;">O R I G N A</span>
            </div>
            <div style="font-size: 48px; margin: 12px 0;">⏰</div>
            <h1 style="margin: 12px 0 8px 0; font-size: 24px; font-weight: 800; color: #ffffff;">Payment Authorization Expired</h1>
            <p style="margin: 0; font-size: 14px; color: #b0b0cc;">No charge was made to your card</p>
        </td></tr>

        <tr><td style="padding: 28px 40px;">
            <p style="margin: 0 0 20px 0; font-size: 15px; color: #333;">Your order authorization has expired after 7 days without seller confirmation.</p>

            <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0;">
                <p style="margin: 4px 0;"><strong>Order ID:</strong> {MOCK_ORDER_ID[:8]}</p>
                <p style="margin: 4px 0;"><strong>Items:</strong> Sony WH-1000XM5 Wireless Headphones x1, Apple AirTag (4 Pack) x2, Anker USB-C Fast Charger 65W x1</p>
                <p style="margin: 4px 0;"><strong>Amount:</strong> $864.29 CAD</p>
            </div>

            <p>The hold on your payment has been released. No charge was made to your card.</p>
            <p>If you still want these items, please place a new order.</p>
        </td></tr>

        <tr><td style="padding: 0 40px 28px 40px; text-align: center;">
            <table role="presentation" cellspacing="0" cellpadding="0" align="center" style="margin: 0 auto;"><tr>
            <td align="center" bgcolor="#667EEA" style="background-color: #667EEA; border-radius: 50px;">
                <a href="{APP_BASE_URL}" target="_blank" style="display: inline-block; padding: 14px 40px; font-size: 15px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px;">Shop Again →</a>
            </td>
            </tr></table>
        </td></tr>

        {_casl_compliant_footer(include_gst=False)}

        </table>
        </td></tr>
        </table>
    </body>
    </html>
    """

    send_to_all(
        f"Authorization Expired — Order #{MOCK_ORDER_ID[:8]}",
        auth_expired_html,
        "auth-expired",
    )

    print("\n" + "=" * 60)
    print("✅ All 7 email samples sent!")
    print("   Check both inboxes (Gmail + Yahoo) in a few minutes.")
    print("=" * 60)


if __name__ == "__main__":
    main()
