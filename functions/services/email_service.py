"""Module email_service.py."""
import hashlib
import hmac
import html
import logging
import os
from datetime import datetime, timedelta
from urllib.parse import quote

from mailjet_rest import Client

from config import (
    CURRENT_ENV,
    IS_EMULATOR,
    get_mailjet_api_key,
    get_mailjet_secret_key,
    get_unsubscribe_hmac_secret,
)
from schema_constants import (
    AppConfig,
    Collections,
    DeliveryTypeValues,
    DigitalPlatformValues,
    DigitalTypeValues,
    EmailConfig,
    Fields,
    ShippingTiers,
    UserRoleValues,
)
from services import shipping_service

logger = logging.getLogger(__name__)

# Allow real email sending in emulator mode for E2E testing
FORCE_REAL_EMAIL = os.environ.get("FORCE_REAL_EMAIL", "false").lower() == "true"

# Mailjet client singleton — lazy initialized to avoid cold-start failures
_mailjet_client = None


def _get_mailjet() -> "Client":
    """Lazy-initialize the Mailjet client as a singleton."""
    global _mailjet_client
    if _mailjet_client is None:
        _mailjet_client = Client(
            auth=(get_mailjet_api_key(), get_mailjet_secret_key()),
            version=EmailConfig.MAILJET_API_VERSION,
        )
    return _mailjet_client

# Dynamic base URL for email links — Environment-aware
APP_BASE_URL = CURRENT_ENV.get_base_url()

# Dynamic unsubscribe URL — Environment-aware
UNSUBSCRIBE_URL = CURRENT_ENV.get_unsubscribe_url()

# HMAC secret for signed unsubscribe tokens (prevents unauthorized unsubscription)
# Loaded from GCP Secret Manager in production, from .env in emulator.
# Validated lazily (on first use) so Firebase CLI analysis can load the module without
# Secret Manager access during `firebase deploy`.
_UNSUBSCRIBE_SECRET: str | None = None


def _get_unsubscribe_secret() -> str:
    """Return the HMAC secret, validating it on first use."""
    global _UNSUBSCRIBE_SECRET
    if _UNSUBSCRIBE_SECRET is None:
        raw = get_unsubscribe_hmac_secret()
        if not (isinstance(raw, str) and raw):
            if IS_EMULATOR:
                raw = "origna-unsub-default-dev-key"
            else:
                raise RuntimeError("UNSUBSCRIBE_HMAC_SECRET is not configured — cannot send emails in non-emulator env")
        _UNSUBSCRIBE_SECRET = raw
    return _UNSUBSCRIBE_SECRET


# ============================================================
# Bilingual string table — EN / FR (Quebec Bill 96 compliance)
# ============================================================
_EMAIL_STRINGS: dict[str, dict[str, str]] = {
    # Order status tracker
    "status.confirmed": {"en": "Confirmed", "fr": "Confirmée"},
    "status.processing": {"en": "Processing", "fr": "En traitement"},
    "status.shipped": {"en": "Shipped", "fr": "Expédiée"},
    "status.delivered": {"en": "Delivered", "fr": "Livrée"},
    # Table column headers
    "col.product": {"en": "Product", "fr": "Produit"},
    "col.qty": {"en": "Qty", "fr": "Qté"},
    "col.price": {"en": "Price", "fr": "Prix"},
    # Section headings
    "section.items_ordered": {"en": "Items Ordered", "fr": "Articles commandés"},
    "section.items_to_ship": {"en": "Items to Ship", "fr": "Articles à expédier"},
    "section.order_receipt": {"en": "Order Receipt", "fr": "Reçu de commande"},
    "section.ship_to": {"en": "Shipping To", "fr": "Livraison à"},
    "section.ship_to_seller": {"en": "Ship To", "fr": "Expédier à"},
    "section.customer_info": {"en": "Customer Info", "fr": "Info client"},
    "section.tracking": {"en": "Tracking Details", "fr": "Détails de suivi"},
    "section.return_policy": {"en": "Return &amp; Refund Policy", "fr": "Politique de retour et remboursement"},
    # Price summary
    "price.subtotal": {"en": "Subtotal", "fr": "Sous-total"},
    "price.shipping": {"en": "Shipping", "fr": "Livraison"},
    "price.taxes": {"en": "Taxes", "fr": "Taxes"},
    "price.total": {"en": "Total", "fr": "Total"},
    "price.free": {"en": "Free", "fr": "Gratuit"},
    # Common labels
    "label.order": {"en": "Order", "fr": "Commande"},
    "label.order_id": {"en": "Order ID:", "fr": "N° de commande :"},
    "label.carrier": {"en": "Carrier:", "fr": "Transporteur :"},
    "label.tracking_num": {"en": "Tracking #:", "fr": "N° de suivi :"},
    "label.amount": {"en": "Amount:", "fr": "Montant :"},
    "label.reason": {"en": "Reason:", "fr": "Raison :"},
    "label.ordered": {"en": "Ordered:", "fr": "Commandé le :"},
    "label.email": {"en": "Email:", "fr": "Courriel :"},
    "label.refund_amount": {"en": "Refund Amount:", "fr": "Montant remboursé :"},
    "label.orig_total": {"en": "Original Total:", "fr": "Total original :"},
    "label.status": {"en": "Status:", "fr": "Statut :"},
    "label.revenue": {"en": "Revenue", "fr": "Revenu"},
    "label.items_stat": {"en": "Items", "fr": "Articles"},
    "label.issue": {"en": "Issue:", "fr": "Problème :"},
    # CTA buttons
    "cta.track_order": {"en": "Track Your Order →", "fr": "Suivre ma commande →"},
    "cta.view_order": {"en": "View Order →", "fr": "Voir ma commande →"},
    "cta.view_orders": {"en": "View Orders →", "fr": "Voir mes commandes →"},
    "cta.manage_orders": {"en": "Manage Orders →", "fr": "Gérer les commandes →"},
    "cta.confirm_receipt": {"en": "Confirm Receipt →", "fr": "Confirmer la réception →"},
    # Footer
    "footer.unsubscribe": {
        "en": "Unsubscribe from marketing emails",
        "fr": "Se désabonner des courriels promotionnels",
    },
    "footer.privacy": {"en": "Privacy Policy", "fr": "Politique de confidentialité"},
    # Seller notification
    "seller.action_banner": {
        "en": "⚡ ACTION REQUIRED — Confirm and ship this order within 48 hours",
        "fr": "⚡ ACTION REQUISE — Confirmez et expédiez cette commande dans les 48 heures",
    },
    "seller.hero_h": {"en": "New Order Received!", "fr": "Nouvelle commande reçue !"},
    "seller.hero_s": {
        "en": "You have a new order to fulfill. Ship it fast!",
        "fr": "Vous avez une nouvelle commande à traiter. Expédiez-la rapidement !",
    },
    "seller.order_total": {"en": "Order Total", "fr": "Total commande"},
    # Order confirmation
    "confirm.hero_h": {"en": "Order Confirmed!", "fr": "Commande confirmée !"},
    "confirm.hero_s": {
        "en": "Thank you for shopping with us, your order is being prepared.",
        "fr": "Merci pour votre achat. Votre commande est en cours de préparation.",
    },
    "confirm.order_date": {"en": "🕐 Ordered on", "fr": "🕐 Commandé le"},
    "confirm.est_delivery": {"en": "📦 Estimated delivery by", "fr": "📦 Livraison estimée avant le"},
    "confirm.sold_by": {"en": "Sold by: Origna Ventures Inc.", "fr": "Vendu par : Origna Ventures Inc."},
    "confirm.return_title": {"en": "Return &amp; Refund Policy", "fr": "Politique de retour et remboursement"},
    "confirm.return_body": {
        "en": "Returns and refunds are accepted within <strong>7 days of delivery</strong>. After 7 days post-delivery, all sales are final. If the goods are defective or not as described, contact {support} with your order ID within the return window. Under Ontario's Consumer Protection Act, you may cancel before shipment.",
        "fr": "Les retours et remboursements sont acceptés dans les <strong>7 jours suivant la livraison</strong>. Après ce délai, toutes les ventes sont définitives. Si les articles sont défectueux ou non conformes, contactez {support} avec votre numéro de commande. Conformément à la Loi sur la protection du consommateur de l'Ontario, vous pouvez annuler avant l'expédition.",
    },
    # Shipped
    "shipped.hero_h": {"en": "Your Order Has Shipped!", "fr": "Votre commande a été expédiée !"},
    "shipped.hero_s": {"en": "Your items are on the way.", "fr": "Vos articles sont en route."},
    # In transit
    "in_transit.hero_h": {"en": "Your Order Is In Transit!", "fr": "Votre commande est en transit !"},
    "in_transit.hero_s": {"en": "Your package is on its way to you.", "fr": "Votre colis est en chemin."},
    "in_transit.move_text": {
        "en": "on the move. You'll receive another update once it's delivered.",
        "fr": "en transit. Vous recevrez une autre mise à jour à la livraison.",
    },
    # Delivered
    "delivered.hero_h": {"en": "Your Order Has Been Delivered!", "fr": "Votre commande a été livrée !"},
    "delivered.hero_s": {"en": "We hope you love your items.", "fr": "Nous espérons que vos articles vous plaisent."},
    "delivered.confirm_t": {"en": "📋 Please Confirm Receipt", "fr": "📋 Veuillez confirmer la réception"},
    "delivered.confirm_b": {
        "en": "Confirming receipt helps us release payment to the seller and improves the marketplace for everyone.",
        "fr": "Confirmer la réception nous permet de libérer le paiement au vendeur et d'améliorer la marketplace pour tous.",
    },
    "delivered.auto_release": {
        "en": "<strong>Note:</strong> Payment will be auto-released after {days} days if not confirmed.",
        "fr": "<strong>Remarque :</strong> Le paiement sera libéré automatiquement après {days} jours si non confirmé.",
    },
    "delivered.return_body": {
        "en": "Returns and refunds are accepted within <strong>{days} days of delivery</strong>. After that, all sales are final. Contact {support} with your order ID within the return window.",
        "fr": "Les retours et remboursements sont acceptés dans les <strong>{days} jours suivant la livraison</strong>. Après ce délai, toutes les ventes sont définitives. Contactez {support} avec votre numéro de commande.",
    },
    # Cancelled
    "cancelled.hero_h": {"en": "Order Cancelled", "fr": "Commande annulée"},
    "cancelled.hero_s": {"en": "Your order has been cancelled.", "fr": "Votre commande a été annulée."},
    "cancelled.refund_t": {"en": "💰 Refund Information", "fr": "💰 Information de remboursement"},
    "cancelled.refund_b": {
        "en": "If payment was captured, a full refund will be issued to your original payment method within 5-10 business days. If you don't see the refund, contact your bank or {support}.",
        "fr": "Si le paiement a été capturé, un remboursement complet sera effectué sur votre moyen de paiement original dans les 5 à 10 jours ouvrables. Si vous ne voyez pas le remboursement, contactez votre banque ou {support}.",
    },
    # Processing
    "processing.hero_h": {"en": "Your Order Is Being Processed!", "fr": "Votre commande est en cours de traitement !"},
    "processing.hero_s": {
        "en": "Payment confirmed — sellers are preparing your items.",
        "fr": "Paiement confirmé — les vendeurs préparent vos articles.",
    },
    "processing.payment_t": {"en": "✅ Payment Confirmed", "fr": "✅ Paiement confirmé"},
    "processing.shipping_n": {
        "en": "You'll receive a shipping notification with tracking details once your items are on the way.",
        "fr": "Vous recevrez une notification d'expédition avec les détails de suivi dès que vos articles seront en route.",
    },
    # Refunded
    "refunded.hero_h": {"en": "Your Refund Has Been Processed", "fr": "Votre remboursement a été traité"},
    "refunded.hero_s": {
        "en": "A full refund has been issued for your order.",
        "fr": "Un remboursement complet a été émis pour votre commande.",
    },
    "refunded.status": {"en": "Full Refund", "fr": "Remboursement complet"},
    "refunded.timeline_t": {"en": "🏦 When Will I See My Refund?", "fr": "🏦 Quand vais-je voir mon remboursement ?"},
    "refunded.timeline_b": {
        "en": "Refunds typically appear on your statement within <strong>5-10 business days</strong>, depending on your bank. If you don't see the refund after 10 business days, contact your bank or reach out to {support}.",
        "fr": "Les remboursements apparaissent généralement sur votre relevé dans les <strong>5 à 10 jours ouvrables</strong>, selon votre banque. Si vous ne voyez pas le remboursement après 10 jours ouvrables, contactez votre banque ou {support}.",
    },
    # Partial refund
    "partial.hero_h": {"en": "Partial Refund Processed", "fr": "Remboursement partiel traité"},
    "partial.hero_s": {
        "en": "A partial refund has been issued for your order.",
        "fr": "Un remboursement partiel a été émis pour votre commande.",
    },
    "partial.status": {"en": "Partial Refund", "fr": "Remboursement partiel"},
    "partial.timeline_t": {"en": "🏦 When Will I See My Refund?", "fr": "🏦 Quand vais-je voir mon remboursement ?"},
    # Payment capture failed
    "capture.hero_h": {"en": "Payment Issue", "fr": "Problème de paiement"},
    "capture.alert_t": {"en": "⚠️ Action Required", "fr": "⚠️ Action requise"},
    "capture.alert_b": {
        "en": "We couldn't complete the payment for your order.",
        "fr": "Nous n'avons pas pu effectuer le paiement pour votre commande.",
    },
    # Auth expired
    "auth_exp.hero_h": {"en": "⏰ Payment Authorization Expired", "fr": "⏰ Autorisation de paiement expirée"},
    "auth_exp.body_1": {
        "en": "Your order authorization has expired after 7 days without seller confirmation.",
        "fr": "L'autorisation de votre commande a expiré après 7 jours sans confirmation du vendeur.",
    },
    "auth_exp.body_2": {
        "en": "The hold on your payment has been released. No charge was made to your card.",
        "fr": "Le blocage sur votre paiement a été levé. Aucun montant n'a été débité de votre carte.",
    },
    "auth_exp.body_3": {
        "en": "If you still want these items, please place a new order.",
        "fr": "Si vous souhaitez toujours ces articles, veuillez passer une nouvelle commande.",
    },
    "auth_exp.subject": {"en": "Order {oid} - Authorization Expired", "fr": "Commande {oid} - Autorisation expirée"},
    # Email subjects (used in handlers)
    "sub.confirmed": {"en": "Order Confirmation - Origna", "fr": "Confirmation de commande - Origna"},
    "sub.new_order": {"en": "New Order Received - Origna", "fr": "Nouvelle commande reçue - Origna"},
    "sub.new_order_seller": {
        "en": "New Order #{oid} — Action Required",
        "fr": "Nouvelle commande #{oid} — Action requise",
    },
    "sub.processing": {
        "en": "Order #{oid} Is Being Processed - Origna",
        "fr": "Commande #{oid} en cours de traitement - Origna",
    },
    "sub.shipped": {
        "en": "Your Order #{oid} Has Shipped - Origna",
        "fr": "Votre commande #{oid} a été expédiée - Origna",
    },
    "sub.ready_for_pickup": {
        "en": "Ready for Pickup - Order #{oid} - Origna",
        "fr": "Prêt pour ramassage - Commande #{oid} - Origna",
    },
    "sub.shipped_seller": {
        "en": "Order {oid} Shipped Successfully - Origna",
        "fr": "Commande {oid} expédiée avec succès - Origna",
    },
    "sub.in_transit": {"en": "Order #{oid} Is In Transit - Origna", "fr": "Commande #{oid} en transit - Origna"},
    "sub.delivered": {
        "en": "Order #{oid} Delivered - Please Confirm Receipt",
        "fr": "Commande #{oid} livrée - Veuillez confirmer la réception",
    },
    "sub.cancelled": {"en": "Order #{oid} Cancelled - Origna", "fr": "Commande #{oid} annulée - Origna"},
    "sub.refunded": {
        "en": "Refund Processed for Order #{oid} - Origna",
        "fr": "Remboursement traité pour la commande #{oid} - Origna",
    },
    "sub.item_shipped": {
        "en": "Part of your order #{oid} has shipped! - Origna",
        "fr": "Une partie de votre commande #{oid} a été expédiée ! - Origna",
    },
    "sub.partial": {
        "en": "Partial Refund for Order #{oid} - Origna",
        "fr": "Remboursement partiel pour la commande #{oid} - Origna",
    },
    "sub.payment_issue": {"en": "Payment Issue - Order #{oid}", "fr": "Problème de paiement - Commande #{oid}"},
    "sub.perishable_urgent": {
        "en": "URGENT: Perishable Order #{oid} — Ship Today",
        "fr": "URGENT: Commande périssable #{oid} — Expédier aujourd'hui",
    },
    # Payment capture failed — "What happened" / "Next steps" sections (fix #5: i18n for FR buyers)
    "capture.what_happened_h": {"en": "What happened?", "fr": "Que s'est-il passé ?"},
    "capture.what_happened_b": {
        "en": "Your payment was authorized but couldn't be charged. Common causes:",
        "fr": "Votre paiement a été autorisé mais n'a pas pu être débité. Causes fréquentes :",
    },
    "capture.cause_funds": {"en": "Card has insufficient funds", "fr": "Fonds insuffisants sur la carte"},
    "capture.cause_expired": {"en": "Card was canceled or expired", "fr": "Carte annulée ou expirée"},
    "capture.cause_declined": {"en": "Bank declined the transaction", "fr": "Banque a refusé la transaction"},
    "capture.next_steps_h": {"en": "Next steps:", "fr": "Prochaines étapes :"},
    "capture.step_1": {"en": "1. Log in to your account", "fr": "1. Connectez-vous à votre compte"},
    "capture.step_2": {"en": "2. Update your payment method", "fr": "2. Mettez à jour votre moyen de paiement"},
    "capture.step_3": {
        "en": "3. Contact your bank if the issue persists",
        "fr": "3. Contactez votre banque si le problème persiste",
    },
    "capture.cta": {"en": "View Order", "fr": "Voir la commande"},
    "capture.help": {
        "en": "Need help? Contact us with order ID:",
        "fr": "Besoin d'aide ? Contactez-nous avec l'ID de commande :",
    },
    "capture.action_required": {
        "en": "Action required for Order #{oid}",
        "fr": "Action requise pour la commande #{oid}",
    },
    # Return request — buyer notifications
    "return.requested_buyer_h": {"en": "Return Request Submitted", "fr": "Demande de retour soumise"},
    "return.requested_buyer_s": {
        "en": "Your return request has been submitted and is awaiting seller review.",
        "fr": "Votre demande de retour a été soumise et est en attente d'examen par le vendeur.",
    },
    "return.approved_buyer_h": {"en": "Return Request Approved! 🎉", "fr": "Demande de retour approuvée ! 🎉"},
    "return.approved_buyer_s": {
        "en": "Your return has been approved. Please ship the item back to the seller.",
        "fr": "Votre retour a été approuvé. Veuillez renvoyer l'article au vendeur.",
    },
    "return.rejected_buyer_h": {"en": "Return Request Update", "fr": "Mise à jour de la demande de retour"},
    "return.rejected_buyer_s": {
        "en": "Unfortunately, your return request was not approved.",
        "fr": "Malheureusement, votre demande de retour n'a pas été approuvée.",
    },
    # Return request — seller notifications
    "return.requested_seller_h": {"en": "⚠️ New Return Request", "fr": "⚠️ Nouvelle demande de retour"},
    "return.requested_seller_s": {
        "en": "A buyer has submitted a return request for one of your orders.",
        "fr": "Un acheteur a soumis une demande de retour pour l'une de vos commandes.",
    },
    # Return request — shared labels
    "return.label_return_id": {"en": "Return ID:", "fr": "N° de retour :"},
    "return.label_reason": {"en": "Reason:", "fr": "Motif :"},
    "return.label_status": {"en": "Status:", "fr": "Statut :"},
    "return.status_requested": {"en": "Awaiting Review", "fr": "En attente d'examen"},
    "return.status_approved": {"en": "Approved", "fr": "Approuvé"},
    "return.status_rejected": {"en": "Not Approved", "fr": "Non approuvé"},
    "return.next_steps_approved": {
        "en": "Please ship the item back and mark it as shipped in the app once sent.",
        "fr": "Veuillez renvoyer l'article et le marquer comme expédié dans l'application.",
    },
    "return.contact_seller_note": {
        "en": "If you believe this decision is incorrect, please contact our support team.",
        "fr": "Si vous pensez que cette décision est incorrecte, veuillez contacter notre équipe de support.",
    },
    # Return request email subjects
    "sub.return_requested_buyer": {
        "en": "Return Request Submitted - Order #{oid}",
        "fr": "Demande de retour soumise - Commande #{oid}",
    },
    "sub.return_approved": {
        "en": "Return Approved - Order #{oid}",
        "fr": "Retour approuvé - Commande #{oid}",
    },
    "sub.return_rejected": {
        "en": "Return Request Update - Order #{oid}",
        "fr": "Mise à jour de la demande de retour - Commande #{oid}",
    },
    "sub.return_requested_seller": {
        "en": "New Return Request - Order #{oid}",
        "fr": "Nouvelle demande de retour - Commande #{oid}",
    },
}


def _t(key: str, lang: str) -> str:
    """Translate email string to the given language. Falls back to 'en' if not found."""
    strings = _EMAIL_STRINGS.get(key, {})
    return strings.get(lang) or strings.get("en", key)


def _generate_unsubscribe_token(email: str) -> str:
    """Generate an HMAC-SHA256 token for secure unsubscribe links.
    Prevents attackers from unsubscribing arbitrary emails."""
    return hmac.new(_get_unsubscribe_secret().encode(), email.lower().encode(), hashlib.sha256).hexdigest()[:32]


def _get_signed_unsubscribe_url(email: str) -> str:
    """Generate a signed unsubscribe URL (email + HMAC token)."""
    token = _generate_unsubscribe_token(email)
    return f"{UNSUBSCRIBE_URL}?email={quote(email)}&token={token}"


def _casl_compliant_footer(include_gst: bool = False, lang: str = "en", recipient_email: str = "") -> str:
    """Generate CASL-compliant email footer with physical address, unsubscribe, and optional GST/HST.

    Required by:
    - CASL (Canadian Anti-Spam Legislation): Physical address + unsubscribe link
    - Excise Tax Act: GST/HST registration number on receipts
    - Quebec Law 25: Privacy officer contact (bilingual for French users)
    """
    gst_line = (
        f'<p style="margin: 0 0 8px 0; font-size: 11px; color: rgba(255,255,255,0.35);">GST/HST Registration: {EmailConfig.GST_HST_NUMBER}</p>'
        if include_gst
        else ""
    )
    t_unsub = _t("footer.unsubscribe", lang)
    t_privacy = _t("footer.privacy", lang)
    unsub_url = _get_signed_unsubscribe_url(recipient_email) if recipient_email else UNSUBSCRIBE_URL
    return f"""
        <tr><td bgcolor="#1a1a2e" style="background-color: #1a1a2e; padding: 32px 40px; text-align: center;">
            <div style="margin-bottom: 16px;">
                <span style="font-size: 12px; font-weight: 700; letter-spacing: 3px; text-transform: uppercase; color: rgba(255,255,255,0.5);">O R I G N A</span>
            </div>
            <p style="margin: 0 0 8px 0; font-size: 13px; color: rgba(255,255,255,0.5);">{EmailConfig.APP_TAGLINE}</p>
            <p style="margin: 0 0 8px 0; font-size: 12px; color: rgba(255,255,255,0.35);">{EmailConfig.PHYSICAL_ADDRESS}</p>
            {gst_line}
            <p style="margin: 0 0 8px 0; font-size: 12px; color: rgba(255,255,255,0.35);">Questions? <a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA; text-decoration: none;">{EmailConfig.SUPPORT_EMAIL}</a> | Privacy: <a href="mailto:{EmailConfig.PRIVACY_OFFICER_EMAIL}" style="color: #667EEA; text-decoration: none;">{EmailConfig.PRIVACY_OFFICER_EMAIL}</a></p>
            <p style="margin: 0 0 12px 0; font-size: 12px; color: rgba(255,255,255,0.35);"><a href="{unsub_url}" style="color: #667EEA; text-decoration: underline;">{t_unsub}</a> | <a href="{APP_BASE_URL}/privacy-policy" style="color: #667EEA; text-decoration: none;">{t_privacy}</a></p>
            <div style="border-top: 1px solid rgba(255,255,255,0.1); padding-top: 16px;">
                <p style="margin: 0; font-size: 11px; color: rgba(255,255,255,0.25);">{EmailConfig.COPYRIGHT_TEXT}</p>
            </div>
        </td></tr>"""


def _log_email_for_testing(to_email: str, subject: str, html_body: str) -> None:
    """Log an email to Firestore so E2E tests can verify it was "sent" in the emulator/dev."""
    from config import CURRENT_ENV, Environment
    if CURRENT_ENV in (Environment.PRODUCTION, Environment.STAGING):
        return

    from firebase_admin import firestore
    try:
        db = firestore.client()
        db.collection(Collections.MAIL_LOGS).add({
            "to": to_email,
            "subject": subject,
            "html": html_body,
            "sentAt": firestore.SERVER_TIMESTAMP
        })
    except Exception as e:
        logger.error(f"Failed to log email to _mail_logs for E2E testing: {e}")


def get_order_confirmation_email(order_data, order_id=None, lang: str = "en"):
    """Generate HTML email for customer order confirmation

    Args:
        order_data: Dict containing order information
        order_id: Optional order ID (can be in order_data[Fields.ORDER_ID] instead)
        lang: User preferred language ('en' or 'fr')
    """
    oid = order_data.get(Fields.ORDER_ID, order_id or "N/A")
    short_oid = oid[:8] if len(oid) > 8 else oid

    items_list = order_data.get(Fields.ITEMS, [])
    all_digital_order = bool(items_list) and all(item.get(Fields.IS_DIGITAL, False) for item in items_list)

    items_html = ""
    for i, item in enumerate(items_list):
        safe_name = html.escape(str(item.get(Fields.NAME, "Product")))
        qty = item.get(Fields.QUANTITY, 1)
        price = item.get(Fields.PRICE, 0)
        line_total = price * qty
        bg = "#f8f9ff" if i % 2 == 0 else "#ffffff"
        items_html += f"""
        <tr style="background: {bg};">
            <td style="padding: 14px 16px; font-size: 14px; color: #1a1a2e;">
                <span style="font-weight: 600;">{safe_name}</span>
            </td>
            <td style="padding: 14px 16px; text-align: center; font-size: 14px; color: #555;">
                ×{qty}
            </td>
            <td style="padding: 14px 16px; text-align: right; font-size: 14px; font-weight: 600; color: #1a1a2e;">
                ${line_total:.2f}
            </td>
        </tr>
        """

    subtotal = order_data.get(Fields.SUBTOTAL_CENTS, 0) / 100
    shipping = order_data.get(Fields.SHIPPING_COST_CENTS, 0) / 100
    taxes_dict = order_data.get(Fields.TAXES, {})
    taxes = sum(taxes_dict.values())
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100
    num_items = sum(item.get(Fields.QUANTITY, 1) for item in order_data.get(Fields.ITEMS, []))

    # Build itemized tax breakdown (Instacart-style: show GST, HST, PST, QST separately)
    tax_rows_html = ""
    if len(taxes_dict) > 1 or (len(taxes_dict) == 1 and list(taxes_dict.keys())[0] != "HST"):
        for tax_name, tax_amount in sorted(taxes_dict.items()):
            tax_rows_html += f"""
                        <tr>
                            <td style="padding: 4px 0 4px 16px; font-size: 13px; color: #888888;">{html.escape(tax_name)}</td>
                            <td style="padding: 4px 0; font-size: 13px; color: #1a1a2e; text-align: right;">${tax_amount:.2f}</td>
                        </tr>"""

    delivery_info = order_data.get(Fields.SHIPPING_ADDRESS, {})
    address_parts = [
        delivery_info.get(Fields.STREET, ""),
        delivery_info.get(Fields.APARTMENT, ""),
        f"{delivery_info.get(Fields.CITY, '')}, {delivery_info.get(Fields.STATE, '')} {delivery_info.get(Fields.POSTAL_CODE, '')}",
        delivery_info.get(Fields.COUNTRY, AppConfig.DEFAULT_COUNTRY_NAME),
    ]
    formatted_address = "<br>".join(p for p in address_parts if p and p.strip())
    phone_html = f"<br>📱 {delivery_info[Fields.PHONE_NUMBER]}" if delivery_info.get(Fields.PHONE_NUMBER) else ""

    _order_created_at = order_data.get(Fields.CREATED_AT)
    if _order_created_at and hasattr(_order_created_at, "strftime"):
        order_date = _order_created_at.strftime("%B %d, %Y at %I:%M %p")
    else:
        order_date = datetime.now().strftime("%B %d, %Y at %I:%M %p")

    # CPA Ontario: estimated delivery date (7 business days from now as default)

    # Calculate estimated delivery date based on items and shipping speed
    # We take the maximum days from all items to be safe
    max_delivery_days = 0
    delivery_speed = order_data.get(Fields.DELIVERY_SPEED, DeliveryTypeValues.STANDARD)

    for item in order_data.get(Fields.ITEMS, []):
        # Get item details for estimation
        supplier_info = item.get(Fields.SUPPLIER)
        estimated_ship_days = item.get(Fields.ESTIMATED_SHIP_DAYS, ShippingTiers.DEFAULT_SELLER_SHIP_DAYS)

        # Determine if international (naive check based on supplier or extended ship days)
        # Ideally we would check seller address country, but that might not be in item data.
        # Dropshipped items are definitely international if they have supplier info.
        is_international = bool(supplier_info) or estimated_ship_days > 10

        estimate = shipping_service.estimate_delivery_date_range(
            supplier_info=supplier_info,
            seller_estimated_days=estimated_ship_days,
            is_international=is_international,
            speed=delivery_speed,
        )

        if estimate.get("max_days", 0) > max_delivery_days:
            max_delivery_days = estimate.get("max_days", 0)

    # Calculate date
    # If Same Day (max_days=0), it's today. Otherwise add business days.
    # For simplicity in email static text, we just add calendar days + buffer
    # or use the max_days directly.
    estimated_delivery_date = datetime.now() + timedelta(days=max(1, max_delivery_days))
    if delivery_speed == DeliveryTypeValues.SAME_DAY:
        estimated_delivery_date = datetime.now()

    if lang == "fr":
        estimated_delivery = estimated_delivery_date.strftime("%-d %B %Y")
    else:
        estimated_delivery = estimated_delivery_date.strftime("%B %d, %Y")

    # Bilingual string aliases for the inline HTML below
    _t_hero_h = _t("confirm.hero_h", lang)
    _t_hero_s = _t("confirm.hero_s", lang)
    _t_order = _t("label.order", lang)
    _t_confirmed = _t("status.confirmed", lang)
    _t_processing = _t("status.processing", lang)
    _t_shipped = _t("status.shipped", lang)
    _t_delivered = _t("status.delivered", lang)
    _t_product = _t("col.product", lang)
    _t_qty = _t("col.qty", lang)
    _t_price = _t("col.price", lang)
    _t_subtotal = _t("price.subtotal", lang)
    _t_shipping_lbl = _t("price.shipping", lang)
    _t_taxes = _t("price.taxes", lang)
    _t_free = _t("price.free", lang)
    _t_total = _t("price.total", lang)
    _t_ship_to = _t("section.ship_to", lang)
    _t_order_date_lbl = _t("confirm.order_date", lang)
    _t_est_delivery = _t("confirm.est_delivery", lang)
    _t_sold_by = _t("confirm.sold_by", lang)
    _t_ret_title = _t("confirm.return_title", lang)
    _support_link = (
        f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'
    )
    _t_ret_body = _t("confirm.return_body", lang).format(support=_support_link)
    _t_cta = _t("cta.track_order", lang)
    _t_footer_unsub = _t("footer.unsubscribe", lang)
    _t_footer_priv = _t("footer.privacy", lang)
    if lang == "fr":
        _items_label = f"{num_items} article{'s' if num_items != 1 else ''} commandé{'s' if num_items != 1 else ''}"
    else:
        _items_label = f"{num_items} Item{'s' if num_items != 1 else ''} Ordered"
    _shipping_val = _t_free if shipping == 0 else f"${shipping:.2f}"

    # ── Digital-only status tracker (2-step: Confirmed + Delivered Instantly) ──
    if all_digital_order:
        _t_instant_delivery = "Delivered Instantly" if lang == "en" else "Livré instantanément"
        _status_tracker_html = f"""
        <!-- ORDER STATUS TRACKER — DIGITAL -->
        <tr><td style="padding: 32px 40px 24px 40px;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
            <tr>
                <td width="50%" align="center">
                    <div style="width: 36px; height: 36px; background: linear-gradient(135deg, #667EEA, #764BA2); border-radius: 50%; margin: 0 auto 8px; line-height: 36px; font-size: 16px; color: white;">✓</div>
                    <div style="font-size: 11px; font-weight: 700; color: #667EEA; text-transform: uppercase; letter-spacing: 0.5px;">{_t_confirmed}</div>
                </td>
                <td width="50%" align="center">
                    <div style="width: 36px; height: 36px; background: linear-gradient(135deg, #10B981, #059669); border-radius: 50%; margin: 0 auto 8px; line-height: 36px; font-size: 16px; color: white;">⚡</div>
                    <div style="font-size: 11px; font-weight: 700; color: #10B981; text-transform: uppercase; letter-spacing: 0.5px;">{_t_instant_delivery}</div>
                </td>
            </tr>
            <tr><td colspan="2" style="padding-top: 12px;">
                <div style="height: 4px; background: #e8ebf0; border-radius: 4px; overflow: hidden;">
                    <div style="width: 100%; height: 100%; background: linear-gradient(90deg, #10B981, #059669); border-radius: 4px;"></div>
                </div>
            </td></tr>
            </table>
        </td></tr>"""
    else:
        _status_tracker_html = f"""
        <!-- ORDER STATUS TRACKER — PHYSICAL -->
        <tr><td style="padding: 32px 40px 24px 40px;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
            <tr>
                <td width="25%" align="center">
                    <div style="width: 36px; height: 36px; background: linear-gradient(135deg, #667EEA, #764BA2); border-radius: 50%; margin: 0 auto 8px; line-height: 36px; font-size: 16px; color: white;">✓</div>
                    <div style="font-size: 11px; font-weight: 700; color: #667EEA; text-transform: uppercase; letter-spacing: 0.5px;">{_t_confirmed}</div>
                </td>
                <td width="25%" align="center">
                    <div style="width: 36px; height: 36px; background: #e8ebf0; border-radius: 50%; margin: 0 auto 8px; line-height: 36px; font-size: 16px; color: #999;">📦</div>
                    <div style="font-size: 11px; font-weight: 600; color: #999; text-transform: uppercase; letter-spacing: 0.5px;">{_t_processing}</div>
                </td>
                <td width="25%" align="center">
                    <div style="width: 36px; height: 36px; background: #e8ebf0; border-radius: 50%; margin: 0 auto 8px; line-height: 36px; font-size: 16px; color: #999;">🚚</div>
                    <div style="font-size: 11px; font-weight: 600; color: #999; text-transform: uppercase; letter-spacing: 0.5px;">{_t_shipped}</div>
                </td>
                <td width="25%" align="center">
                    <div style="width: 36px; height: 36px; background: #e8ebf0; border-radius: 50%; margin: 0 auto 8px; line-height: 36px; font-size: 16px; color: #999;">🏠</div>
                    <div style="font-size: 11px; font-weight: 600; color: #999; text-transform: uppercase; letter-spacing: 0.5px;">{_t_delivered}</div>
                </td>
            </tr>
            <!-- Progress bar -->
            <tr><td colspan="4" style="padding-top: 12px;">
                <div style="height: 4px; background: #e8ebf0; border-radius: 4px; overflow: hidden;">
                    <div style="width: 12%; height: 100%; background: linear-gradient(90deg, #667EEA, #764BA2); border-radius: 4px;"></div>
                </div>
            </td></tr>
            </table>
        </td></tr>"""

    # ── License key block (software: key + download links; book: access CTA) ──
    _digital_block_html = ""
    digital_items = [item for item in items_list if item.get(Fields.IS_DIGITAL) and item.get(Fields.DIGITAL_UNLOCKED)]
    if digital_items:
        license_rows = ""
        platform_labels = {
            DigitalPlatformValues.MACOS: "macOS",
            DigitalPlatformValues.WINDOWS: "Windows",
            DigitalPlatformValues.LINUX: "Linux",
        }
        for item in digital_items:
            safe_name = html.escape(str(item.get(Fields.NAME, "Digital Product")))
            license_key = item.get(Fields.LICENSE_KEY, "")
            digital_type = item.get(Fields.DIGITAL_TYPE, "")
            builds = item.get(Fields.DIGITAL_BUILDS) or {}

            if digital_type == DigitalTypeValues.SOFTWARE and license_key:
                platform_links = "".join(
                    f'<a href="{url}" style="color: #667EEA; text-decoration: none; margin-right: 16px; font-size: 13px;">'
                    f"{platform_labels.get(platform, platform.capitalize())} ↓</a>"
                    for platform, url in builds.items()
                )
                instructions = (
                    "Open the app → click <strong>Enter License</strong> → paste your key"
                    if lang == "en"
                    else "Ouvrez l'application → cliquez <strong>Entrer la licence</strong> → collez votre clé"
                )
                license_rows += f"""
                <tr style="background-color: #f8f9ff;">
                    <td style="padding: 16px 20px;">
                        <div style="font-size: 13px; font-weight: 700; color: #1a1a2e; margin-bottom: 8px;">{safe_name}</div>
                        <div style="font-family: 'Courier New', monospace; font-size: 18px; font-weight: 700; color: #667EEA; letter-spacing: 2px; background: #eef0ff; padding: 10px 16px; border-radius: 8px; display: inline-block; margin-bottom: 8px;">{html.escape(license_key)}</div>
                        {f'<div style="margin-bottom: 8px;">{platform_links}</div>' if platform_links else ""}
                        <div style="font-size: 12px; color: #555;">{instructions}</div>
                    </td>
                </tr>"""

            elif digital_type == DigitalTypeValues.BOOK and license_key:
                access_label = (
                    "Access your book in the Origna app"
                    if lang == "en"
                    else "Accédez à votre livre dans l'application Origna"
                )
                license_rows += f"""
                <tr style="background-color: #f8f9ff;">
                    <td style="padding: 16px 20px;">
                        <div style="font-size: 13px; font-weight: 700; color: #1a1a2e; margin-bottom: 8px;">{safe_name}</div>
                        <div style="font-size: 13px; color: #555; margin-bottom: 6px;">{access_label}</div>
                        <div style="font-family: 'Courier New', monospace; font-size: 12px; color: #888;">Key: {html.escape(license_key)}</div>
                    </td>
                </tr>"""

        if license_rows:
            heading = "Your Digital Downloads" if lang == "en" else "Vos téléchargements numériques"
            _digital_block_html = f"""
        <tr><td style="padding: 0 40px 28px 40px;">
            <h2 style="margin: 0 0 16px 0; font-size: 16px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 1px;">
                <span style="border-bottom: 3px solid #10B981; padding-bottom: 6px;">🔑 {html.escape(heading)}</span>
            </h2>
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-radius: 12px; overflow: hidden; border: 2px solid #10B981;">
                {license_rows}
            </table>
        </td></tr>"""

    return f"""
    <!DOCTYPE html>
    <html lang="{lang}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Order Confirmed - Origna</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f0f2f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; -webkit-font-smoothing: antialiased;">
        <!-- Preheader: inbox preview text (hidden in body) -->
        <div style="display:none;font-size:1px;color:#f0f2f8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">Your order #{short_oid} has been confirmed and is being prepared for shipment.</div>

        <!-- Outer wrapper -->
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f0f2f8;">
        <tr><td align="center" style="padding: 24px 16px;">

        <!-- Email container -->
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 60px rgba(102, 126, 234, 0.15);">

        <!-- HERO HEADER -->
        <tr><td bgcolor="#1F235A" style="background-color: #1F235A; background-image: linear-gradient(135deg, #1F235A 0%, #2F3B8F 40%, #764BA2 100%); padding: 48px 40px 40px 40px; text-align: center;">
            <!-- Logo text -->
            <div style="margin-bottom: 8px;">
                <span style="font-size: 14px; font-weight: 700; letter-spacing: 4px; text-transform: uppercase; color: rgba(255,255,255,0.6);">O R I G N A</span>
            </div>
            <!-- Confirmation icon -->
            <div style="width: 72px; height: 72px; margin: 16px auto; background: rgba(16, 185, 129, 0.2); border-radius: 50%; line-height: 72px; font-size: 36px;">
                ✅
            </div>
            <h1 style="margin: 16px 0 8px 0; font-size: 28px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">{_t_hero_h}</h1>
            <p style="margin: 0; font-size: 15px; color: rgba(255,255,255,0.75);">{_t_hero_s}</p>
            <!-- Order badge -->
            <div style="display: inline-block; margin-top: 20px; background: rgba(255,255,255,0.12); backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2); border-radius: 50px; padding: 10px 24px;">
                <span style="font-size: 12px; color: rgba(255,255,255,0.6); text-transform: uppercase; letter-spacing: 1px;">{_t_order}</span>
                <span style="font-size: 15px; color: #ffffff; font-weight: 700; margin-left: 6px; font-family: 'Courier New', monospace;">#{short_oid}</span>
            </div>
        </td></tr>

        <!-- ORDER STATUS TRACKER -->
        {_status_tracker_html}

        <!-- DIVIDER -->
        <tr><td style="padding: 0 40px;"><div style="height: 1px; background-color: #e8ebf0;"></div></td></tr>

        <!-- ITEMS TABLE -->
        <tr><td style="padding: 28px 40px 0 40px;">
            <h2 style="margin: 0 0 16px 0; font-size: 16px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 1px;">
                <span style="border-bottom: 3px solid #667EEA; padding-bottom: 6px;">{_items_label}</span>
            </h2>
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-radius: 12px; overflow: hidden; border: 1px solid #e8ebf0;">
                <thead>
                    <tr bgcolor="#667EEA" style="background-color: #667EEA;">
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: left; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{_t_product}</th>
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: center; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{_t_qty}</th>
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: right; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{_t_price}</th>
                    </tr>
                </thead>
                <tbody>
                    {items_html}
                </tbody>
            </table>
        </td></tr>

        {_digital_block_html}

        <!-- ORDER RECEIPT (Gmail-safe: uses bgcolor fallbacks) -->
        <tr><td style="padding: 24px 40px;">
            <h2 style="margin: 0 0 16px 0; font-size: 16px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 1px;">
                <span style="border-bottom: 3px solid #667EEA; padding-bottom: 6px;">{_t("section.order_receipt", lang)}</span>
            </h2>
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#f8f9ff" style="background-color: #f8f9ff; border-radius: 16px; border: 1px solid #e0e3f0; overflow: hidden;">
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 20px 24px 4px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{_t_subtotal}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">${subtotal:.2f}</td>
                        </tr>
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{_t_shipping_lbl}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: {"#10B981" if shipping == 0 else "#1a1a2e"}; text-align: right; font-weight: 500;">{_shipping_val}</td>
                        </tr>
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{_t_taxes}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">${taxes:.2f}</td>
                        </tr>
                        {tax_rows_html}
                    </table>
                </td></tr>
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 0 24px;"><div style="height: 1px; background-color: #d0d4e8;"></div></td></tr>
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 16px 24px 20px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                        <tr>
                            <td style="font-size: 16px; font-weight: 700; color: #1a1a2e;">{_t_total} (CAD)</td>
                            <td style="font-size: 22px; font-weight: 800; color: #667EEA; text-align: right; letter-spacing: -0.5px;">${total:.2f}</td>
                        </tr>
                    </table>
                </td></tr>
            </table>
        </td></tr>

        <!-- SHIPPING ADDRESS -->
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background: #ffffff; border: 1px solid #e8ebf0; border-radius: 16px; padding: 20px 24px;">
                <div style="display: flex; align-items: center; margin-bottom: 12px;">
                    <span style="font-size: 18px; margin-right: 8px;">📍</span>
                    <span style="font-size: 14px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 0.5px;">{_t_ship_to}</span>
                </div>
                <p style="margin: 0; font-size: 14px; line-height: 1.8; color: #555;">
                    {formatted_address}{phone_html}
                </p>
            </div>
        </td></tr>

        <!-- ORDER DATE -->
        <tr><td style="padding: 0 40px 24px 40px; text-align: center;">
            <p style="margin: 0 0 4px 0; font-size: 12px; color: #999;">{_t_order_date_lbl} {order_date}</p>
            <p style="margin: 0 0 4px 0; font-size: 12px; color: #999;">{_t_est_delivery} {estimated_delivery}</p>
            <p style="margin: 0; font-size: 12px; color: #999;">{_t_sold_by} | GST/HST: {EmailConfig.GST_HST_NUMBER}</p>
        </td></tr>

        <!-- CTA BUTTON -->
        <tr><td style="padding: 0 40px 32px 40px; text-align: center;">
            <table role="presentation" cellspacing="0" cellpadding="0" align="center" style="margin: 0 auto;"><tr>
            <td align="center" bgcolor="#667EEA" style="background-color: #667EEA; border-radius: 50px;">
                <a href="{APP_BASE_URL}/orders" target="_blank" style="display: inline-block; padding: 16px 48px; font-size: 15px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px; letter-spacing: 0.5px;">{_t_cta}</a>
            </td>
            </tr></table>
        </td></tr>

        <!-- CPA ONTARIO COMPLIANCE: Cancellation rights notice -->
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e8ebf0; border-radius: 12px; padding: 16px 20px;">
                <p style="margin: 0 0 8px 0; font-size: 13px; font-weight: 700; color: #1a1a2e;">{_t_ret_title}</p>
                <p style="margin: 0; font-size: 12px; color: #555555; line-height: 1.6;">{_t_ret_body}</p>
            </div>
        </td></tr>

        <!-- CASL-COMPLIANT FOOTER with GST/HST (Excise Tax Act) -->
        {_casl_compliant_footer(include_gst=True, lang=lang, recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, ''))}

        </table>
        </td></tr>
        </table>
    </body>
    </html>
    """


def get_seller_notification_email(order_data, order_id=None, seller_id=None, lang: str = "en", seller_email: str = "", is_urgent_perishable: bool = False):
    """Generate HTML email for seller notification

    Args:
        order_data: Dict containing order information
        order_id: Optional order ID (can be in order_data[Fields.ORDER_ID])
        seller_id: Seller ID to filter items — only shows this seller's items (multi-seller privacy)
    """
    oid = order_data.get(Fields.ORDER_ID, order_id or "N/A")
    short_oid = oid[:8] if len(oid) > 8 else oid

    # CRITICAL: Filter items to show only this seller's items (multi-seller privacy)
    all_items = order_data.get(Fields.ITEMS, [])
    seller_items = [item for item in all_items if item.get(Fields.SELLER_ID) == seller_id] if seller_id else all_items

    items_html = ""
    for i, item in enumerate(seller_items):
        safe_name = html.escape(str(item.get(Fields.NAME, "Product")))
        qty = item.get(Fields.QUANTITY, 1)
        price = item.get(Fields.PRICE, 0)
        line_total = price * qty
        bg = "#f8f9ff" if i % 2 == 0 else "#ffffff"
        items_html += f"""
        <tr style="background: {bg};">
            <td style="padding: 14px 16px; font-size: 14px; color: #1a1a2e;">
                <span style="font-weight: 600;">{safe_name}</span>
            </td>
            <td style="padding: 14px 16px; text-align: center; font-size: 14px; color: #555;">
                ×{qty}
            </td>
            <td style="padding: 14px 16px; text-align: right; font-size: 14px; font-weight: 600; color: #1a1a2e;">
                ${line_total:.2f}
            </td>
        </tr>
        """

    # Calculate totals only for this seller's items (not the full order)
    seller_subtotal = sum(item.get(Fields.PRICE, 0) * item.get(Fields.QUANTITY, 1) for item in seller_items)
    num_items = sum(item.get(Fields.QUANTITY, 1) for item in seller_items)

    # Seller sees only their portion — not full order shipping/taxes/total
    subtotal = seller_subtotal  # Seller revenue = subtotal of their items only
    shipping = 0  # Shipping is charged to buyer, not split per seller
    taxes = 0  # Taxes apply to the buyer's total, not per-seller
    total = seller_subtotal  # Seller revenue = subtotal of their items only
    # AUDIT FIX: Removed duplicate num_items that was overwriting seller-only count with full order count

    delivery_info = order_data.get(Fields.SHIPPING_ADDRESS, {})
    addr_parts = [
        delivery_info.get(Fields.STREET, ""),
        delivery_info.get(Fields.APARTMENT, ""),
        f"{delivery_info.get(Fields.CITY, '')}, {delivery_info.get(Fields.STATE, '')} {delivery_info.get(Fields.POSTAL_CODE, '')}",
        delivery_info.get(Fields.COUNTRY, AppConfig.DEFAULT_COUNTRY_NAME),
    ]
    address_html = "<br>".join(p for p in addr_parts if p and p.strip())
    phone_html = f"<br>📱 {delivery_info[Fields.PHONE_NUMBER]}" if delivery_info.get(Fields.PHONE_NUMBER) else ""

    if lang == "fr":
        order_date = datetime.now().strftime("%d %B %Y à %H:%M")
    else:
        order_date = datetime.now().strftime("%B %d, %Y at %I:%M %p")
    customer_email = html.escape(order_data.get(Fields.CUSTOMER_EMAIL, "N/A"))

    if is_urgent_perishable:
        hero_bg = "#B91C1C"
        hero_grad = "linear-gradient(135deg, #B91C1C 0%, #DC2626 40%, #EF4444 100%)"
        hero_icon = "🚨"
        hero_icon_bg = "rgba(254, 226, 226, 0.2)"
        hero_title = _t("seller.hero_h_urgent", lang)
        if hero_title == "seller.hero_h_urgent":
            hero_title = "URGENT: PERISHABLE ORDER" if lang != "fr" else "URGENT : COMMANDE PÉRISSABLE"

        hero_sub = _t("seller.hero_s_urgent", lang)
        if hero_sub == "seller.hero_s_urgent":
            hero_sub = "CFIA Compliance Required: Ship Today" if lang != "fr" else "Conformité ACIA requise : Expédier aujourd'hui"
        urgent_banner_html = f"""
        <!-- CFIA COMPLIANCE BANNER -->
        <tr><td bgcolor="#FEF2F2" style="background-color: #FEF2F2; padding: 16px 40px; border-bottom: 2px solid #FECACA; text-align: center;">
            <div style="font-size: 13px; font-weight: 700; color: #DC2626; letter-spacing: 0.5px; line-height: 1.5;">
                🛑 COMPLIANCE NOTICE: This order contains perishable items. To meet CFIA safety regulations, you MUST fulfill and ship this order TODAY.<br/>Delayed shipping may result in liability and account suspension.
            </div>
        </td></tr>
        """
    else:
        hero_bg = "#1F235A"
        hero_grad = "linear-gradient(135deg, #1F235A 0%, #2F3B8F 40%, #764BA2 100%)"
        hero_icon = "💰"
        hero_icon_bg = "rgba(245, 158, 11, 0.2)"
        hero_title = _t("seller.hero_h", lang)
        hero_sub = _t("seller.hero_s", lang)
        urgent_banner_html = ""

    return f"""
    <!DOCTYPE html>
    <html lang="{lang}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>New Order - Origna Seller</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f0f2f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; -webkit-font-smoothing: antialiased;">
        <!-- Preheader: inbox preview text (hidden in body) -->
        <div style="display:none;font-size:1px;color:#f0f2f8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">New order ${total:.2f} — {num_items} items to ship. Order #{short_oid}</div>

        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f0f2f8;">
        <tr><td align="center" style="padding: 24px 16px;">

        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 60px rgba(102, 126, 234, 0.15);">

        {urgent_banner_html}

        <!-- HERO HEADER -->
        <tr><td bgcolor="{hero_bg}" style="background-color: {hero_bg}; background-image: {hero_grad}; padding: 48px 40px 40px 40px; text-align: center;">
            <div style="margin-bottom: 8px;">
                <span style="font-size: 14px; font-weight: 700; letter-spacing: 4px; text-transform: uppercase; color: rgba(255,255,255,0.6);">O R I G N A</span>
            </div>
            <!-- icon -->
            <div style="width: 72px; height: 72px; margin: 16px auto; background: {hero_icon_bg}; border-radius: 50%; line-height: 72px; font-size: 36px;">
                {hero_icon}
            </div>
            <h1 style="margin: 16px 0 8px 0; font-size: 28px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">{hero_title}</h1>
            <p style="margin: 0; font-size: 15px; color: rgba(255,255,255,0.75);">{hero_sub}</p>

            <!-- Stats row -->
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-top: 28px;">
            <tr>
                <td width="33%" align="center">
                    <div style="background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.15); border-radius: 16px; padding: 14px 8px;">
                        <div style="font-size: 22px; font-weight: 800; color: #ffffff;">${total:.2f}</div>
                        <div style="font-size: 10px; font-weight: 600; color: rgba(255,255,255,0.5); text-transform: uppercase; letter-spacing: 1px; margin-top: 4px;">{_t("label.revenue", lang)}</div>
                    </div>
                </td>
                <td width="33%" align="center">
                    <div style="background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.15); border-radius: 16px; padding: 14px 8px;">
                        <div style="font-size: 22px; font-weight: 800; color: #ffffff;">{num_items}</div>
                        <div style="font-size: 10px; font-weight: 600; color: rgba(255,255,255,0.5); text-transform: uppercase; letter-spacing: 1px; margin-top: 4px;">{_t("label.items_stat", lang)}</div>
                    </div>
                </td>
                <td width="33%" align="center">
                    <div style="background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.15); border-radius: 16px; padding: 14px 8px;">
                        <div style="font-size: 22px; font-weight: 800; color: #ffffff;">#{short_oid}</div>
                        <div style="font-size: 10px; font-weight: 600; color: rgba(255,255,255,0.5); text-transform: uppercase; letter-spacing: 1px; margin-top: 4px;">Order ID</div>
                    </div>
                </td>
            </tr>
            </table>
        </td></tr>

        <!-- URGENT ACTION BANNER -->
        <tr><td bgcolor="#F59E0B" style="background-color: #F59E0B; background-image: linear-gradient(90deg, #F59E0B, #F97316); padding: 14px 40px; text-align: center;">
            <span style="font-size: 13px; font-weight: 700; color: #ffffff; letter-spacing: 0.5px;">{_t("seller.action_banner", lang)}</span>
        </td></tr>

        <!-- CUSTOMER INFO -->
        <tr><td style="padding: 28px 40px 0 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e0e3f0; border-radius: 16px; padding: 20px 24px;">
                <div style="margin-bottom: 12px;">
                    <span style="font-size: 18px; margin-right: 8px;">👤</span>
                    <span style="font-size: 14px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 0.5px;">{_t("section.customer_info", lang)}</span>
                </div>
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888; width: 90px;">{_t("label.email", lang)}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 500;">{customer_email}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">{_t("label.ordered", lang)}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 500;">{order_date}</td>
                    </tr>
                </table>
            </div>
        </td></tr>

        <!-- ITEMS TABLE -->
        <tr><td style="padding: 24px 40px 0 40px;">
            <h2 style="margin: 0 0 16px 0; font-size: 16px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 1px;">
                <span style="border-bottom: 3px solid #764BA2; padding-bottom: 6px;">{_t("section.items_to_ship", lang)}</span>
            </h2>
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-radius: 12px; overflow: hidden; border: 1px solid #e8ebf0;">
                <thead>
                    <tr bgcolor="#667EEA" style="background-color: #667EEA; background-image: linear-gradient(135deg, #667EEA, #764BA2);">
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: left; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{_t("col.product", lang)}</th>
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: center; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{_t("col.qty", lang)}</th>
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: right; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{_t("col.price", lang)}</th>
                    </tr>
                </thead>
                <tbody>
                    {items_html}
                </tbody>
            </table>
        </td></tr>

        <!-- PRICE SUMMARY (Gmail-safe: uses bgcolor fallbacks) -->
        <tr><td style="padding: 24px 40px;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#f8f9ff" style="background-color: #f8f9ff; border-radius: 16px; border: 1px solid #e0e3f0; overflow: hidden;">
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 20px 24px 4px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{_t("price.subtotal", lang)}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">${subtotal:.2f}</td>
                        </tr>
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{_t("price.shipping", lang)}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">{_t("price.free", lang) if shipping == 0 else f"${shipping:.2f}"}</td>
                        </tr>
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{_t("price.taxes", lang)}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">${taxes:.2f}</td>
                        </tr>
                    </table>
                </td></tr>
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 0 24px;"><div style="height: 1px; background-color: #d0d4e8;"></div></td></tr>
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 16px 24px 20px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                        <tr>
                            <td style="font-size: 16px; font-weight: 700; color: #1a1a2e;">{_t("seller.order_total", lang)}</td>
                            <td style="font-size: 22px; font-weight: 800; color: #10B981; text-align: right; letter-spacing: -0.5px;">${total:.2f} <span style="font-size: 13px; font-weight: 600; color: #999999;">CAD</span></td>
                        </tr>
                    </table>
                </td></tr>
            </table>
        </td></tr>

        <!-- SHIPPING ADDRESS -->
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background: #ffffff; border: 1px solid #e8ebf0; border-radius: 16px; padding: 20px 24px;">
                <div style="margin-bottom: 12px;">
                    <span style="font-size: 18px; margin-right: 8px;">📦</span>
                    <span style="font-size: 14px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 0.5px;">{_t("section.ship_to_seller", lang)}</span>
                </div>
                <p style="margin: 0; font-size: 14px; line-height: 1.8; color: #555;">
                    {address_html}{phone_html}
                </p>
            </div>
        </td></tr>

        <!-- CTA BUTTON -->
        <tr><td style="padding: 0 40px 32px 40px; text-align: center;">
            <table role="presentation" cellspacing="0" cellpadding="0" align="center" style="margin: 0 auto;"><tr>
            <td align="center" bgcolor="#667EEA" style="background-color: #667EEA; border-radius: 50px;">
                <a href="{APP_BASE_URL}/seller/orders" target="_blank" style="display: inline-block; padding: 16px 48px; font-size: 15px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px; letter-spacing: 0.5px;">{_t("cta.manage_orders", lang)}</a>
            </td>
            </tr></table>
        </td></tr>

        <!-- CASL-COMPLIANT FOOTER -->
        {_casl_compliant_footer(include_gst=False, lang=lang, recipient_email=seller_email)}

        </table>
        </td></tr>
        </table>
    </body>
    </html>
    """


def _email_wrapper(title: str, content_html: str, include_gst: bool = False, lang: str = "en", recipient_email: str = "") -> str:
    """Wrap email content in full branded HTML email template with CASL-compliant footer.

    Gmail-safe: uses bgcolor fallbacks, no CSS-only gradients for backgrounds.
    """
    return f"""
    <!DOCTYPE html>
    <html lang="{lang}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{html.escape(title)} - Origna</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f0f2f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; -webkit-font-smoothing: antialiased;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f0f2f8;">
        <tr><td align="center" style="padding: 24px 16px;">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background-color: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 60px rgba(102, 126, 234, 0.15);">

        {content_html}

        {_casl_compliant_footer(include_gst=include_gst, lang=lang, recipient_email=recipient_email)}

        </table>
        </td></tr>
        </table>
    </body>
    </html>
    """


def _hero_header(icon: str, heading: str, subtext: str, icon_bg: str = "rgba(102, 126, 234, 0.2)") -> str:
    """Generate a branded hero header section for emails."""
    return f"""
        <tr><td bgcolor="#1F235A" style="background-color: #1F235A; background-image: linear-gradient(135deg, #1F235A 0%, #2F3B8F 40%, #764BA2 100%); padding: 48px 40px 40px 40px; text-align: center;">
            <div style="margin-bottom: 8px;">
                <span style="font-size: 14px; font-weight: 700; letter-spacing: 4px; text-transform: uppercase; color: rgba(255,255,255,0.6);">O R I G N A</span>
            </div>
            <div style="width: 72px; height: 72px; margin: 16px auto; background: {icon_bg}; border-radius: 50%; line-height: 72px; font-size: 36px;">
                {icon}
            </div>
            <h1 style="margin: 16px 0 8px 0; font-size: 28px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">{html.escape(heading)}</h1>
            <p style="margin: 0; font-size: 15px; color: rgba(255,255,255,0.75);">{html.escape(subtext)}</p>
        </td></tr>
    """


def _order_status_tracker(active_step: int, lang: str = "en") -> str:
    """Generate order status progress tracker. active_step: 1=Confirmed, 2=Processing, 3=Shipped, 4=Delivered."""
    steps = [
        (_t("status.confirmed", lang), "✓"),
        (_t("status.processing", lang), "📦"),
        (_t("status.shipped", lang), "🚚"),
        (_t("status.delivered", lang), "🏠"),
    ]
    rows = ""
    for i, (label, icon) in enumerate(steps):
        step_num = i + 1
        if step_num <= active_step:
            bg = "background: linear-gradient(135deg, #667EEA, #764BA2);"
            color = "#667EEA"
            weight = "700"
            text_color = "white"
        else:
            bg = "background-color: #e8ebf0;"
            color = "#999999"
            weight = "600"
            text_color = "#999999"
        rows += f"""
                <td width="25%" align="center">
                    <div style="width: 36px; height: 36px; {bg} border-radius: 50%; margin: 0 auto 8px; line-height: 36px; font-size: 16px; color: {text_color};">{icon}</div>
                    <div style="font-size: 11px; font-weight: {weight}; color: {color}; text-transform: uppercase; letter-spacing: 0.5px;">{label}</div>
                </td>"""

    pct = ["12%", "37%", "62%", "100%"][active_step - 1] if active_step > 0 else "0%"
    return f"""
        <tr><td style="padding: 32px 40px 24px 40px;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
            <tr>{rows}</tr>
            <tr><td colspan="4" style="padding-top: 12px;">
                <div style="height: 4px; background-color: #e8ebf0; border-radius: 4px; overflow: hidden;">
                    <div style="width: {pct}; height: 100%; background: linear-gradient(90deg, #667EEA, #764BA2); border-radius: 4px;"></div>
                </div>
            </td></tr>
            </table>
        </td></tr>
    """


def _cta_button(url: str, label: str, color: str = "#667EEA") -> str:
    """Generate a pill-shaped CTA button."""
    return f"""
        <tr><td style="padding: 0 40px 32px 40px; text-align: center;">
            <table role="presentation" cellspacing="0" cellpadding="0" align="center" style="margin: 0 auto;"><tr>
            <td align="center" bgcolor="{color}" style="background-color: {color}; border-radius: 50px;">
                <a href="{url}" target="_blank" style="display: inline-block; padding: 16px 48px; font-size: 15px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px; letter-spacing: 0.5px;">{html.escape(label)}</a>
            </td>
            </tr></table>
        </td></tr>
    """


def _items_summary_table(items: list, lang: str = "en") -> str:
    """Generate a table of order items for receipt emails."""
    if not items:
        return ""
    rows = ""
    for i, item in enumerate(items):
        safe_name = html.escape(str(item.get(Fields.NAME, "Product")))
        qty = item.get(Fields.QUANTITY, 1)
        price = item.get(Fields.PRICE, 0)
        line_total = price * qty
        bg = "#f8f9ff" if i % 2 == 0 else "#ffffff"
        rows += f"""
        <tr style="background-color: {bg};">
            <td style="padding: 14px 16px; font-size: 14px; color: #1a1a2e;">
                <span style="font-weight: 600;">{safe_name}</span>
            </td>
            <td style="padding: 14px 16px; text-align: center; font-size: 14px; color: #555555;">
                &times;{qty}
            </td>
            <td style="padding: 14px 16px; text-align: right; font-size: 14px; font-weight: 600; color: #1a1a2e;">
                ${line_total:.2f}
            </td>
        </tr>"""

    t_heading = _t("section.items_ordered", lang)
    t_product = _t("col.product", lang)
    t_qty = _t("col.qty", lang)
    t_price = _t("col.price", lang)
    return f"""
        <tr><td style="padding: 28px 40px 0 40px;">
            <h2 style="margin: 0 0 16px 0; font-size: 16px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 1px;">
                <span style="border-bottom: 3px solid #667EEA; padding-bottom: 6px;">{t_heading}</span>
            </h2>
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-radius: 12px; overflow: hidden; border: 1px solid #e8ebf0;">
                <thead>
                    <tr bgcolor="#667EEA" style="background-color: #667EEA;">
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: left; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{t_product}</th>
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: center; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{t_qty}</th>
                        <th bgcolor="#667EEA" style="padding: 12px 16px; text-align: right; font-size: 11px; font-weight: 700; color: white; text-transform: uppercase; letter-spacing: 1px;">{t_price}</th>
                    </tr>
                </thead>
                <tbody>
                    {rows}
                </tbody>
            </table>
        </td></tr>
    """


def _price_summary_block(subtotal: float, shipping: float, taxes: float, total: float, lang: str = "en") -> str:
    """Generate Gmail-safe price summary block with receipt-style layout."""
    t_subtotal = _t("price.subtotal", lang)
    t_shipping = _t("price.shipping", lang)
    t_taxes = _t("price.taxes", lang)
    t_total = _t("price.total", lang)
    t_free = _t("price.free", lang)
    return f"""
        <tr><td style="padding: 24px 40px;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#f8f9ff" style="background-color: #f8f9ff; border-radius: 16px; border: 1px solid #e0e3f0; overflow: hidden;">
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 20px 24px 4px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{t_subtotal}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">${subtotal:.2f}</td>
                        </tr>
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{t_shipping}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">{t_free if shipping == 0 else f"${shipping:.2f}"}</td>
                        </tr>
                        <tr>
                            <td style="padding: 6px 0; font-size: 14px; color: #555555;">{t_taxes}</td>
                            <td style="padding: 6px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 500;">${taxes:.2f}</td>
                        </tr>
                    </table>
                </td></tr>
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 0 24px;"><div style="height: 1px; background-color: #d0d4e8;"></div></td></tr>
                <tr><td bgcolor="#f8f9ff" style="background-color: #f8f9ff; padding: 16px 24px 20px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                        <tr>
                            <td style="font-size: 16px; font-weight: 700; color: #1a1a2e;">{t_total}</td>
                            <td style="font-size: 22px; font-weight: 800; color: #667EEA; text-align: right; letter-spacing: -0.5px;">${total:.2f} <span style="font-size: 13px; font-weight: 600; color: #999999;">CAD</span></td>
                        </tr>
                    </table>
                </td></tr>
            </table>
        </td></tr>
    """


def get_order_shipped_email(
    order_data: dict, order_id: str, tracking_number: str = "N/A", carrier: str = "N/A", lang: str = "en"
) -> str:
    """Generate branded HTML email for order shipped notification."""
    short_oid = order_id[:8] if len(order_id) > 8 else order_id
    safe_tracking = html.escape(str(tracking_number))
    safe_carrier = html.escape(str(carrier))

    items = order_data.get(Fields.ITEMS, [])
    subtotal = order_data.get(Fields.SUBTOTAL_CENTS, 0) / 100
    shipping = order_data.get(Fields.SHIPPING_COST_CENTS, 0) / 100
    taxes = sum(order_data.get(Fields.TAXES, {}).values())
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100

    content = _hero_header("🚚", _t("shipped.hero_h", lang), _t("shipped.hero_s", lang), "rgba(59, 130, 246, 0.2)")
    content += _order_status_tracker(3, lang)

    t_tracking = _t("section.tracking", lang)
    t_order_id = _t("label.order_id", lang)
    t_carrier = _t("label.carrier", lang)
    t_tracking_num = _t("label.tracking_num", lang)
    content += f"""
        <tr><td style="padding: 0 40px;"><div style="height: 1px; background-color: #e8ebf0;"></div></td></tr>

        <!-- Tracking Info -->
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e0e3f0; border-radius: 16px; padding: 20px 24px;">
                <div style="margin-bottom: 12px;">
                    <span style="font-size: 18px; margin-right: 8px;">📦</span>
                    <span style="font-size: 14px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 0.5px;">{t_tracking}</span>
                </div>
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 120px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_carrier}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 500;">{safe_carrier}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_tracking_num}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #667EEA; font-weight: 600;">{safe_tracking}</td>
                    </tr>
                </table>
            </div>
        </td></tr>
    """

    content += _items_summary_table(items, lang)
    content += _price_summary_block(subtotal, shipping, taxes, total, lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.track_order", lang))

    return _email_wrapper("Order Shipped", content, include_gst=True, lang=lang, recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, ''))


def get_order_item_shipped_email(
    order_data: dict, order_id: str, shipped_items: list, tracking_number: str = "N/A", carrier: str = "N/A", lang: str = "en"
) -> str:
    """Generate HTML email for partial shipment notification (item-level)."""
    short_oid = order_id[:8]
    safe_tracking = html.escape(str(tracking_number))
    safe_carrier = html.escape(str(carrier))

    # Detect if any of the items originated internationally
    is_international = False
    for item in shipped_items:
        address = item.get(Fields.SELLER_ADDRESS, {})
        country = str(address.get(Fields.COUNTRY, "Canada")).strip().lower()
        if country and country not in ("canada", "ca"):
            is_international = True
            break

    hero_sub_text = f"Items from order #{short_oid} are on their way!"
    if is_international:
        hero_sub_text += "<br/><br/><strong style='color: #4B5563;'>🌍 Note: This package is arriving from overseas.</strong><br/>International shipments typically require an additional 7+ business days for customs clearance and regional transport."

    content = _hero_header("📦", _t("shipped.hero_h", lang), hero_sub_text, "rgba(59, 130, 246, 0.2)")

    # Tracking block
    t_tracking = _t("section.tracking", lang)
    t_order_id = _t("label.order_id", lang)
    t_carrier = _t("label.carrier", lang)
    t_tracking_num = _t("label.tracking_num", lang)
    content += f"""
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e0e3f0; border-radius: 16px; padding: 20px 24px;">
                <div style="margin-bottom: 12px;">
                    <span style="font-size: 18px; margin-right: 8px;">🚚</span>
                    <span style="font-size: 14px; font-weight: 700; color: #1a1a2e; text-transform: uppercase; letter-spacing: 0.5px;">{t_tracking}</span>
                </div>
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 120px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_carrier}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 500;">{safe_carrier}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_tracking_num}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #667EEA; font-weight: 600;">{safe_tracking}</td>
                    </tr>
                </table>
            </div>
        </td></tr>
    """

    content += _items_summary_table(shipped_items, lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.track_order", lang))

    return _email_wrapper("Shipment Update", content, include_gst=False, lang=lang, recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, ''))


def get_order_in_transit_email(order_data: dict, order_id: str, lang: str = "en") -> str:
    """Generate branded HTML email for order in-transit notification."""
    short_oid = order_id[:8] if len(order_id) > 8 else order_id

    tracking_number = order_data.get(Fields.TRACKING_NUMBER, "N/A")
    carrier = order_data.get(Fields.CARRIER, "N/A")
    safe_tracking = html.escape(str(tracking_number))
    safe_carrier = html.escape(str(carrier))

    items = order_data.get(Fields.ITEMS, [])
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100

    content = _hero_header(
        "🚚", _t("in_transit.hero_h", lang), _t("in_transit.hero_s", lang), "rgba(59, 130, 246, 0.2)"
    )
    content += _order_status_tracker(3, lang)

    t_tracking = _t("section.tracking", lang)
    t_order_id = _t("label.order_id", lang)
    t_carrier = _t("label.carrier", lang)
    t_tracking_num = _t("label.tracking_num", lang)
    t_move_text = _t("in_transit.move_text", lang)
    item_word = (
        "article"
        if lang == "fr" and len(items) == 1
        else ("articles" if lang == "fr" else ("item" if len(items) == 1 else "items"))
    )
    content += f"""
        <tr><td style="padding: 0 40px;"><div style="height: 1px; background-color: #e8ebf0;"></div></td></tr>

        <!-- Tracking Info -->
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #EFF6FF; border: 1px solid #BFDBFE; border-radius: 16px; padding: 20px 24px;">
                <div style="margin-bottom: 12px;">
                    <span style="font-size: 18px; margin-right: 8px;">📍</span>
                    <span style="font-size: 14px; font-weight: 700; color: #1E40AF; text-transform: uppercase; letter-spacing: 0.5px;">{t_tracking}</span>
                </div>
                <table role="presentation" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 16px 4px 0; font-size: 13px; color: #888888;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 16px 4px 0; font-size: 13px; color: #888888;">{t_carrier}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 500;">{safe_carrier}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 16px 4px 0; font-size: 13px; color: #888888;">{t_tracking_num}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #667EEA; font-weight: 600;">{safe_tracking}</td>
                    </tr>
                </table>
            </div>
        </td></tr>

        <tr><td style="padding: 0 40px 16px 40px; text-align: center;">
            <p style="margin: 0; font-size: 13px; color: #6B7280; line-height: 1.6;">Your package with {len(items)} {item_word} worth <strong>${total:.2f} CAD</strong> is {t_move_text}</p>
        </td></tr>
    """

    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.track_order", lang))

    return _email_wrapper("Order In Transit", content, include_gst=False, lang=lang, recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, ''))


def get_order_delivered_email(order_data: dict, order_id: str, lang: str = "en") -> str:
    """Generate branded HTML email for order delivered notification."""
    short_oid = order_id[:8] if len(order_id) > 8 else order_id

    items = order_data.get(Fields.ITEMS, [])
    subtotal = order_data.get(Fields.SUBTOTAL_CENTS, 0) / 100
    shipping = order_data.get(Fields.SHIPPING_COST_CENTS, 0) / 100
    taxes = sum(order_data.get(Fields.TAXES, {}).values())
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100

    from schema_constants import BusinessRules

    content = _hero_header("🏠", _t("delivered.hero_h", lang), _t("delivered.hero_s", lang), "rgba(16, 185, 129, 0.2)")
    content += _order_status_tracker(4, lang)

    t_confirm_t = _t("delivered.confirm_t", lang)
    t_confirm_b = _t("delivered.confirm_b", lang)
    t_auto_release = _t("delivered.auto_release", lang).format(days=BusinessRules.AUTO_CONFIRM_DAYS)
    t_order_label = _t("label.order", lang)
    t_return_title = _t("section.return_policy", lang)
    support_link = (
        f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'
    )
    t_return_body = _t("delivered.return_body", lang).format(
        days=BusinessRules.RETURN_WINDOW_DAYS, support=support_link
    )
    content += f"""
        <tr><td style="padding: 0 40px;"><div style="height: 1px; background-color: #e8ebf0;"></div></td></tr>

        <!-- Confirmation Notice -->
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #ECFDF5; border: 1px solid #A7F3D0; border-radius: 16px; padding: 20px 24px;">
                <p style="margin: 0 0 8px 0; font-size: 14px; font-weight: 700; color: #065F46;">{t_confirm_t}</p>
                <p style="margin: 0 0 8px 0; font-size: 13px; color: #047857; line-height: 1.6;">{t_confirm_b}</p>
                <p style="margin: 0; font-size: 12px; color: #6B7280;">{t_auto_release}</p>
            </div>
        </td></tr>

        <!-- Order ID badge -->
        <tr><td style="padding: 0 40px 16px 40px; text-align: center;">
            <div style="display: inline-block; background-color: #f8f9ff; border: 1px solid #e0e3f0; border-radius: 50px; padding: 10px 24px;">
                <span style="font-size: 12px; color: #888888; text-transform: uppercase; letter-spacing: 1px;">{t_order_label}</span>
                <span style="font-size: 15px; color: #1a1a2e; font-weight: 700; margin-left: 6px; font-family: 'Courier New', monospace;">#{short_oid}</span>
            </div>
        </td></tr>
    """

    content += _items_summary_table(items, lang)
    content += _price_summary_block(subtotal, shipping, taxes, total, lang)

    content += f"""
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e8ebf0; border-radius: 12px; padding: 16px 20px;">
                <p style="margin: 0 0 8px 0; font-size: 13px; font-weight: 700; color: #1a1a2e;">{t_return_title}</p>
                <p style="margin: 0; font-size: 12px; color: #555555; line-height: 1.6;">{t_return_body}</p>
            </div>
        </td></tr>
    """

    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.confirm_receipt", lang), "#10B981")

    return _email_wrapper("Order Delivered", content, include_gst=True, lang=lang, recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, ''))


def get_order_cancelled_email(order_data: dict, order_id: str, reason: str = "Unknown", lang: str = "en") -> str:
    """Generate branded HTML email for order cancelled notification."""
    short_oid = order_id[:8] if len(order_id) > 8 else order_id
    safe_reason = html.escape(str(reason))

    items = order_data.get(Fields.ITEMS, [])
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100

    content = _hero_header("❌", _t("cancelled.hero_h", lang), _t("cancelled.hero_s", lang), "rgba(220, 38, 38, 0.2)")

    t_order_id = _t("label.order_id", lang)
    t_amount = _t("label.amount", lang)
    t_reason = _t("label.reason", lang)
    t_refund_t = _t("cancelled.refund_t", lang)
    support_link = (
        f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'
    )
    t_refund_b = _t("cancelled.refund_b", lang).format(support=support_link)
    content += f"""
        <!-- Cancellation details -->
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #FEF2F2; border: 1px solid #FECACA; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 100px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_amount}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">${total:.2f} CAD</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_reason}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #DC2626; font-weight: 500;">{safe_reason}</td>
                    </tr>
                </table>
            </div>
        </td></tr>

        <!-- Refund notice -->
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e8ebf0; border-radius: 12px; padding: 16px 20px;">
                <p style="margin: 0 0 8px 0; font-size: 13px; font-weight: 700; color: #1a1a2e;">{t_refund_t}</p>
                <p style="margin: 0; font-size: 12px; color: #555555; line-height: 1.6;">{t_refund_b}</p>
            </div>
        </td></tr>
    """

    content += _items_summary_table(items, lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_orders", lang))

    return _email_wrapper("Order Cancelled", content, include_gst=False, lang=lang, recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, ''))


def get_order_processing_email(order_data: dict, order_id: str, lang: str = "en") -> str:
    """Generate branded HTML email for order processing (payment captured successfully)."""
    short_oid = order_id[:8] if len(order_id) > 8 else order_id

    items = order_data.get(Fields.ITEMS, [])
    subtotal = order_data.get(Fields.SUBTOTAL_CENTS, 0) / 100
    shipping = order_data.get(Fields.SHIPPING_COST_CENTS, 0) / 100
    taxes = sum(order_data.get(Fields.TAXES, {}).values())
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100

    content = _hero_header(
        "⚙️",
        _t("processing.hero_h", lang),
        _t("processing.hero_s", lang),
        "rgba(99, 102, 241, 0.2)",
    )
    content += _order_status_tracker(2, lang)

    t_payment_t = _t("processing.payment_t", lang)
    # Build bilingual payment body with interpolated amount
    if lang == "fr":
        t_payment_b = f"Votre paiement de <strong>{total:.2f} $ CAD</strong> a été capturé. Les vendeurs ont été notifiés et préparent vos articles."
    else:
        t_payment_b = f"Your payment of <strong>${total:.2f} CAD</strong> has been captured. Sellers have been notified and are now preparing your items for shipment."
    t_shipping_n = _t("processing.shipping_n", lang)
    t_order_label = _t("label.order", lang)
    content += f"""
        <tr><td style="padding: 0 40px;"><div style="height: 1px; background-color: #e8ebf0;"></div></td></tr>

        <!-- Processing notice -->
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #EEF2FF; border: 1px solid #C7D2FE; border-radius: 16px; padding: 20px 24px;">
                <p style="margin: 0 0 8px 0; font-size: 14px; font-weight: 700; color: #3730A3;">{t_payment_t}</p>
                <p style="margin: 0 0 8px 0; font-size: 13px; color: #4338CA; line-height: 1.6;">{t_payment_b}</p>
                <p style="margin: 0; font-size: 12px; color: #6B7280;">{t_shipping_n}</p>
            </div>
        </td></tr>

        <!-- Order ID badge -->
        <tr><td style="padding: 0 40px 16px 40px; text-align: center;">
            <div style="display: inline-block; background-color: #f8f9ff; border: 1px solid #e0e3f0; border-radius: 50px; padding: 10px 24px;">
                <span style="font-size: 12px; color: #888888; text-transform: uppercase; letter-spacing: 1px;">{t_order_label}</span>
                <span style="font-size: 15px; color: #1a1a2e; font-weight: 700; margin-left: 6px; font-family: 'Courier New', monospace;">#{short_oid}</span>
            </div>
        </td></tr>
    """

    content += _items_summary_table(items, lang)
    content += _price_summary_block(subtotal, shipping, taxes, total, lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_order", lang))

    return _email_wrapper("Order Processing", content, include_gst=True, lang=lang, recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, ''))


def get_order_refunded_email(order_data: dict, order_id: str, refund_amount_cents: int = 0, lang: str = "en") -> str:
    """Generate branded HTML email for full refund notification."""
    short_oid = order_id[:8] if len(order_id) > 8 else order_id

    items = order_data.get(Fields.ITEMS, [])
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100
    refund_amount = refund_amount_cents / 100 if refund_amount_cents else total

    content = _hero_header("💰", _t("refunded.hero_h", lang), _t("refunded.hero_s", lang), "rgba(16, 185, 129, 0.2)")

    t_order_id = _t("label.order_id", lang)
    t_refund_amt = _t("label.refund_amount", lang)
    t_status = _t("label.status", lang)
    t_full_refund = _t("refunded.status", lang)
    t_timeline_t = _t("refunded.timeline_t", lang)
    support_link = (
        f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'
    )
    t_timeline_b = _t("refunded.timeline_b", lang).format(support=support_link)
    content += f"""
        <!-- Refund details -->
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #ECFDF5; border: 1px solid #A7F3D0; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 120px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_refund_amt}</td>
                        <td style="padding: 4px 0; font-size: 16px; color: #059669; font-weight: 700;">${refund_amount:.2f} CAD</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_status}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #059669; font-weight: 600;">{t_full_refund}</td>
                    </tr>
                </table>
            </div>
        </td></tr>

        <!-- Timeline notice -->
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e8ebf0; border-radius: 12px; padding: 16px 20px;">
                <p style="margin: 0 0 8px 0; font-size: 13px; font-weight: 700; color: #1a1a2e;">{t_timeline_t}</p>
                <p style="margin: 0; font-size: 12px; color: #555555; line-height: 1.6;">{t_timeline_b}</p>
            </div>
        </td></tr>
    """

    content += _items_summary_table(items, lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_orders", lang))

    return _email_wrapper("Order Refunded", content, include_gst=False, lang=lang)


def get_order_partially_refunded_email(
    order_data: dict, order_id: str, refund_amount_cents: int = 0, lang: str = "en"
) -> str:
    """Generate branded HTML email for partial refund notification."""
    short_oid = order_id[:8] if len(order_id) > 8 else order_id

    items = order_data.get(Fields.ITEMS, [])
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100
    refund_amount = refund_amount_cents / 100 if refund_amount_cents else 0
    remaining = total - refund_amount

    content = _hero_header("💸", _t("partial.hero_h", lang), _t("partial.hero_s", lang), "rgba(245, 158, 11, 0.2)")

    t_order_id = _t("label.order_id", lang)
    t_orig_total = _t("label.orig_total", lang)
    t_refund_amt = _t("label.refund_amount", lang)
    t_status = _t("label.status", lang)
    t_partial = _t("partial.status", lang)
    t_timeline_t = _t("partial.timeline_t", lang)
    support_link = (
        f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'
    )
    if lang == "fr":
        t_timeline_b = f"Les remboursements partiels apparaissent généralement sur votre relevé dans les <strong>5 à 10 jours ouvrables</strong>. Le solde restant de <strong>{remaining:.2f} $ CAD</strong> n'est pas affecté. Des questions ? Contactez {support_link}."
    else:
        t_timeline_b = f"Partial refunds typically appear on your statement within <strong>5-10 business days</strong>. The remaining balance of <strong>${remaining:.2f} CAD</strong> is not affected. Questions? Contact {support_link}."
    content += f"""
        <!-- Partial refund details -->
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #FFFBEB; border: 1px solid #FDE68A; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 120px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_orig_total}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 500;">${total:.2f} CAD</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_refund_amt}</td>
                        <td style="padding: 4px 0; font-size: 16px; color: #D97706; font-weight: 700;">${refund_amount:.2f} CAD</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_status}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #D97706; font-weight: 600;">{t_partial}</td>
                    </tr>
                </table>
            </div>
        </td></tr>

        <!-- Timeline notice -->
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e8ebf0; border-radius: 12px; padding: 16px 20px;">
                <p style="margin: 0 0 8px 0; font-size: 13px; font-weight: 700; color: #1a1a2e;">{t_timeline_t}</p>
                <p style="margin: 0; font-size: 12px; color: #555555; line-height: 1.6;">{t_timeline_b}</p>
            </div>
        </td></tr>
    """

    content += _items_summary_table(items, lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_orders", lang))

    return _email_wrapper("Partial Refund", content, include_gst=False, lang=lang)


def get_return_request_submitted_email(return_data: dict, return_id: str, order_id: str, recipient: str = "buyer", lang: str = "en") -> str:
    """Email to buyer (request submitted) or seller (new return request)."""
    short_oid = order_id[:8]
    short_rid = return_id[:8]
    reason = html.escape(str(return_data.get(Fields.RETURN_REASON, "")))

    if recipient == UserRoleValues.SELLER:
        content = _hero_header("⚠️", _t("return.requested_seller_h", lang), _t("return.requested_seller_s", lang), "rgba(245, 158, 11, 0.2)")
    else:
        content = _hero_header("📦", _t("return.requested_buyer_h", lang), _t("return.requested_buyer_s", lang), "rgba(102, 126, 234, 0.2)")

    t_order_id = _t("label.order_id", lang)
    t_return_id = _t("return.label_return_id", lang)
    t_status = _t("return.label_status", lang)
    t_status_val = _t("return.status_requested", lang)
    reason_row = f"""
        <tr>
            <td style="padding: 4px 0; font-size: 13px; color: #888888;">{_t("return.label_reason", lang)}</td>
            <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e;">{reason}</td>
        </tr>""" if reason else ""

    bg = "#FFFBEB" if recipient == UserRoleValues.SELLER else "#EFF6FF"
    border = "#FDE68A" if recipient == UserRoleValues.SELLER else "#BFDBFE"

    content += f"""
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: {bg}; border: 1px solid {border}; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 120px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_return_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-family: 'Courier New', monospace;">#{short_rid}</td>
                    </tr>
                    {reason_row}
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_status}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #D97706; font-weight: 600;">{t_status_val}</td>
                    </tr>
                </table>
            </div>
        </td></tr>
    """
    cta_label = _t("cta.manage_orders", lang) if recipient == UserRoleValues.SELLER else _t("cta.view_orders", lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", cta_label)
    title = "New Return Request" if recipient == UserRoleValues.SELLER else "Return Request Submitted"
    # FIX F6-5: Pass recipient_email so CASL footer generates personalised unsubscribe link
    _rec_email = return_data.get(Fields.CUSTOMER_EMAIL, "") if recipient != UserRoleValues.SELLER else ""
    return _email_wrapper(title, content, include_gst=False, lang=lang, recipient_email=_rec_email)


def get_return_request_approved_email(return_data: dict, return_id: str, order_id: str, lang: str = "en") -> str:
    """Email to buyer when their return request is approved."""
    short_oid = order_id[:8]
    short_rid = return_id[:8]
    reason = html.escape(str(return_data.get(Fields.RETURN_REASON, "")))

    content = _hero_header("✅", _t("return.approved_buyer_h", lang), _t("return.approved_buyer_s", lang), "rgba(16, 185, 129, 0.2)")

    t_order_id = _t("label.order_id", lang)
    t_return_id = _t("return.label_return_id", lang)
    t_status = _t("return.label_status", lang)
    t_next = _t("return.next_steps_approved", lang)
    reason_row = f"""
        <tr>
            <td style="padding: 4px 0; font-size: 13px; color: #888888;">{_t("return.label_reason", lang)}</td>
            <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e;">{reason}</td>
        </tr>""" if reason else ""

    content += f"""
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #ECFDF5; border: 1px solid #A7F3D0; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 120px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_return_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_rid}</td>
                    </tr>
                    {reason_row}
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_status}</td>
                        <td style="padding: 14px 16px; font-size: 14px; color: #059669; font-weight: 600;">{_t("return.status_approved", lang)}</td>
                    </tr>
                </table>
            </div>
        </td></tr>
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e8ebf0; border-radius: 12px; padding: 16px 20px;">
                <p style="margin: 0; font-size: 13px; color: #555555;">{t_next}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_orders", lang))
    # FIX F6-5: Pass recipient_email for personalised unsubscribe URL in CASL footer
    return _email_wrapper("Return Approved", content, include_gst=False, lang=lang, recipient_email=return_data.get(Fields.CUSTOMER_EMAIL, ""))


def get_return_request_rejected_email(return_data: dict, return_id: str, order_id: str, lang: str = "en") -> str:
    """Email to buyer when their return request is rejected."""
    short_oid = order_id[:8]
    short_rid = return_id[:8]
    reason = html.escape(str(return_data.get(Fields.RETURN_REASON, "")))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    content = _hero_header("❌", _t("return.rejected_buyer_h", lang), _t("return.rejected_buyer_s", lang), "rgba(220, 38, 38, 0.2)")

    t_order_id = _t("label.order_id", lang)
    t_return_id = _t("return.label_return_id", lang)
    t_status = _t("return.label_status", lang)
    t_contact = _t("return.contact_seller_note", lang).replace("{support}", support_link)
    reason_row = f"""
        <tr>
            <td style="padding: 4px 0; font-size: 13px; color: #888888;">{_t("return.label_reason", lang)}</td>
            <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e;">{reason}</td>
        </tr>""" if reason else ""

    content += f"""
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #FEF2F2; border: 1px solid #FECACA; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888; width: 120px;">{t_order_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-weight: 600; font-family: 'Courier New', monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_return_id}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; font-family: 'Courier New', monospace;">#{short_rid}</td>
                    </tr>
                    {reason_row}
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888888;">{t_status}</td>
                        <td style="padding: 14px 16px; font-size: 14px; color: #DC2626; font-weight: 600;">{_t("return.status_rejected", lang)}</td>
                    </tr>
                </table>
            </div>
        </td></tr>
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color: #f8f9ff; border: 1px solid #e8ebf0; border-radius: 12px; padding: 16px 20px;">
                <p style="margin: 0; font-size: 12px; color: #555555;">{t_contact}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_orders", lang))
    # FIX F6-5: Pass recipient_email for personalised unsubscribe URL in CASL footer
    return _email_wrapper("Return Request Update", content, include_gst=False, lang=lang, recipient_email=return_data.get(Fields.CUSTOMER_EMAIL, ""))


def send_email(
    to_email: str,
    subject: str,
    html_content: str,
    from_email: str = EmailConfig.SUPPORT_EMAIL,
    to_name: str | None = None,
    attachments: list | None = None,
) -> bool:
    """Send email using Mailjet — CASL compliant with List-Unsubscribe header

    Args:
        to_email: Recipient email address
        subject: Email subject line
        html_content: HTML body
        from_email: Sender email (default: support@)
        to_name: Optional recipient display name
        attachments: Optional list of dicts with keys:
            - ContentType (str): MIME type, e.g. 'application/pdf'
            - Filename (str): Attachment filename
            - Base64Content (str): Base64-encoded file content
    """
    try:
        _log_email_for_testing(to_email, subject, html_content)

        if (IS_EMULATOR and not FORCE_REAL_EMAIL) or not get_mailjet_api_key():
            logger.info(f"\U0001f4e7 [EMULATOR] Would send email to {to_email}: {subject}")
            if attachments:
                logger.info(f"   📎 With {len(attachments)} attachment(s): {[a.get('Filename') for a in attachments]}")
            return True

        mailjet = _get_mailjet()

        to_field: dict = {"Email": to_email}
        if to_name:
            to_field["Name"] = to_name
        message = {
            "From": {"Email": from_email, "Name": EmailConfig.SENDER_NAME},
            "To": [to_field],
            "Subject": subject,
            "HTMLPart": html_content,
            "Headers": {
                "List-Unsubscribe": f"<{_get_signed_unsubscribe_url(to_email)}>, <mailto:{EmailConfig.SUPPORT_EMAIL}?subject=Unsubscribe>",
                "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
            },
        }

        # Attach files (e.g. PDF invoice)
        if attachments:
            message["Attachments"] = attachments

        data = {"Messages": [message]}

        result = mailjet.send.create(data=data)
        if result.status_code == 200:
            logger.info(f"✉️ Mailjet email sent to {to_email}")
            return True
        else:
            logger.error(f"❌ Mailjet failed: {result.json()}")
            return False
    except Exception as e:
        logger.error(f"❌ Mailjet error: {str(e)}")
        return False


def send_authorization_expired_email(order_id: str, order_data: dict, lang: str = "en") -> None:
    """Send notification when payment authorization expires after 7 days."""
    customer_email = order_data.get(Fields.CUSTOMER_EMAIL)
    if not customer_email:
        logger.warning(f"Cannot send authorization expired email for order {order_id}: missing customer_email")
        return
    total = order_data.get(Fields.TOTAL_AMOUNT_CENTS, 0) / 100
    content = f"""
        {_hero_header("⏰", _t("auth_exp.hero_h", lang), "Order #" + order_id[:8], "rgba(255, 107, 53, 0.2)")}
        <tr><td style="padding: 28px 40px;">
            <p style="margin: 0 0 20px 0; font-size: 15px; color: #333;">{_t("auth_exp.body_1", lang)}</p>

            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f8f9ff; border-radius: 12px; border: 1px solid #e5e8f5; margin-bottom: 24px;">
            <tr><td style="padding: 16px 20px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">{_t("label.order_id", lang)}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 600;">{order_id[:8]}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">{_t("label.amount", lang)}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 600;">${total:.2f} CAD</td>
                    </tr>
                </table>
            </td></tr>
            </table>

            <p style="margin: 0 0 12px 0; font-size: 15px; color: #333;">{_t("auth_exp.body_2", lang)}</p>
            <p style="margin: 0; font-size: 15px; color: #333;">{_t("auth_exp.body_3", lang)}</p>
        </td></tr>
    """
    subject = _t("auth_exp.subject", lang).replace("{oid}", order_id[:8])
    html_body = _email_wrapper(_t("auth_exp.hero_h", lang), content, include_gst=False, lang=lang, recipient_email=customer_email)
    send_email(customer_email, subject, html_body)


def send_payment_capture_failed_email(
    order_id: str, customer_email: str, customer_name: str, amount: float, error_message: str, lang: str = "en"
):
    """
    Send email notification when payment capture fails.
    Instructs buyer to update payment method or contact support.
    """
    if not customer_email:
        logger.info("Cannot send capture failure email: missing customer_email")
        return

    # Build HTML (single build — used for logging, emulator, and sending)
    safe_name = html.escape(str(customer_name or ""))
    safe_error = html.escape(str(error_message or "Unknown error"))
    html_body = f"""
    <!DOCTYPE html>
    <html lang="{lang}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Issue - Origna</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f0f2f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
        <div style="display:none;font-size:1px;color:#f0f2f8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">Action required: payment issue with order #{order_id[:8]}</div>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f0f2f8;">
        <tr><td align="center" style="padding: 24px 16px;">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background-color: #ffffff; border-radius: 20px; overflow: hidden;">

        <!-- Header -->
        <tr><td bgcolor="#1F235A" style="background-color: #1F235A; padding: 40px 40px 32px 40px; text-align: center;">
            <div style="margin-bottom: 8px;">
                <span style="font-size: 14px; font-weight: 700; letter-spacing: 4px; text-transform: uppercase; color: #9999b3;">O R I G N A</span>
            </div>
            <div style="font-size: 48px; margin: 12px 0;">⚠️</div>
            <h1 style="margin: 12px 0 8px 0; font-size: 24px; font-weight: 800; color: #ffffff;">{_t("capture.hero_h", lang)}</h1>
            <p style="margin: 0; font-size: 14px; color: #b0b0cc;">{_t("capture.action_required", lang).replace("{oid}", order_id[:8])}</p>
        </td></tr>

        <!-- Alert Banner -->
        <tr><td bgcolor="#FEF3C7" style="background-color: #FEF3C7; border-left: 4px solid #F59E0B; padding: 16px 40px;">
            <span style="font-size: 14px; font-weight: 700; color: #92400E;">{_t("capture.alert_t", lang)}</span><br>
            <span style="font-size: 14px; color: #78350F;">{_t("capture.alert_b", lang)}</span>
        </td></tr>

        <!-- Content -->
        <tr><td style="padding: 28px 40px;">
            <p style="margin: 0 0 20px 0; font-size: 15px; color: #333;">Hi {safe_name},</p>

            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f8f9ff; border-radius: 12px; border: 1px solid #e5e8f5; margin-bottom: 24px;">
            <tr><td style="padding: 16px 20px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">{_t("label.order_id", lang)}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 600;">{order_id[:8]}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">{_t("label.amount", lang)}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #1a1a2e; text-align: right; font-weight: 600;">${amount:.2f} CAD</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 0; font-size: 13px; color: #888;">{_t("label.issue", lang)}</td>
                        <td style="padding: 4px 0; font-size: 14px; color: #dc2626; text-align: right; font-weight: 500;">{safe_error}</td>
                    </tr>
                </table>
            </td></tr>
            </table>

            <p style="margin: 0 0 8px 0; font-size: 15px; font-weight: 700; color: #1a1a2e;">{_t("capture.what_happened_h", lang)}</p>
            <p style="margin: 0 0 12px 0; font-size: 14px; color: #555; line-height: 1.6;">{_t("capture.what_happened_b", lang)}</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">&bull; {_t("capture.cause_funds", lang)}</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">&bull; {_t("capture.cause_expired", lang)}</p>
            <p style="margin: 0 0 20px 0; font-size: 14px; color: #555;">&bull; {_t("capture.cause_declined", lang)}</p>

            <p style="margin: 0 0 8px 0; font-size: 15px; font-weight: 700; color: #1a1a2e;">{_t("capture.next_steps_h", lang)}</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">{_t("capture.step_1", lang)}</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">{_t("capture.step_2", lang)}</p>
            <p style="margin: 0 0 4px 0; font-size: 14px; color: #555;">{_t("capture.step_3", lang)}</p>
        </td></tr>

        <!-- CTA Button -->
        <tr><td style="padding: 0 40px 28px 40px; text-align: center;">
            <table role="presentation" cellspacing="0" cellpadding="0" align="center" style="margin: 0 auto;"><tr>
            <td align="center" bgcolor="#667EEA" style="background-color: #667EEA; border-radius: 50px;">
                <a href="{APP_BASE_URL}/orders/{order_id}" target="_blank" style="display: inline-block; padding: 14px 40px; font-size: 15px; font-weight: 700; color: #ffffff; text-decoration: none; border-radius: 50px;">{_t("capture.cta", lang)}</a>
            </td>
            </tr></table>
        </td></tr>

        <tr><td style="padding: 0 40px 24px 40px;">
            <p style="margin: 0; font-size: 13px; color: #888; text-align: center;">{_t("capture.help", lang)} <strong>{order_id[:8]}</strong></p>

        <!-- CASL-COMPLIANT FOOTER -->
        {_casl_compliant_footer(include_gst=False, lang=lang, recipient_email=customer_email)}

        </table>
        </td></tr>
        </table>
    </body>
    </html>
    """
    subject = _t("sub.payment_issue", lang).replace("{oid}", order_id[:8])
    send_email(customer_email, subject, html_body, to_name=customer_name)


def get_order_item_delivered_email(
    order_data: dict, order_id: str, delivered_items: list, lang: str = "en"
) -> str:
    """Generate HTML email for partial delivery notification (item-level)."""
    short_oid = order_id[:8]

    content = _hero_header(
        "🎉",
        "Item Delivered" if lang == "en" else "Article livré",
        f"Good news! Items from order #{short_oid} have arrived.",
        "rgba(16, 185, 129, 0.2)"
    )

    content += _items_summary_table(delivered_items, lang)
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.track_order", lang))

    return _email_wrapper(
        "Delivery Update" if lang == "en" else "Mise à jour de livraison",
        content,
        include_gst=False,
        lang=lang,
        recipient_email=order_data.get(Fields.CUSTOMER_EMAIL, '')
    )


# ============================================================
# FLOW 6 — Return: RECEIVED + REFUNDED email templates
# ============================================================

def get_return_received_email(return_data: dict, return_id: str, order_id: str, lang: str = "en") -> str:
    """Email to buyer: seller has confirmed the returned item was received; refund in progress."""
    short_oid = order_id[:8]
    short_rid = return_id[:8]
    reason = html.escape(str(return_data.get(Fields.RETURN_REASON, "")))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    hero_h = {"en": "Return Received ✅", "fr": "Retour reçu ✅"}.get(lang, "Return Received ✅")
    hero_s = {
        "en": "The seller has confirmed receipt of your returned item. A refund is now being processed.",
        "fr": "Le vendeur a confirmé la réception de votre article retourné. Un remboursement est en cours de traitement.",
    }.get(lang, "The seller has confirmed receipt of your returned item. A refund is now being processed.")
    t_order = _t("label.order_id", lang)
    t_ret = _t("return.label_return_id", lang)
    t_status_label = _t("return.label_status", lang)
    t_status_val = {"en": "Item Received — Refund Processing", "fr": "Article reçu — Remboursement en cours"}.get(lang, "Item Received — Refund Processing")
    t_timeline_t = _t("refunded.timeline_t", lang)
    t_timeline_b = _t("refunded.timeline_b", lang).format(support=support_link)
    reason_row = f"""<tr>
        <td style="padding:4px 0;font-size:13px;color:#888888;">{_t("return.label_reason", lang)}</td>
        <td style="padding:4px 0;font-size:14px;color:#1a1a2e;">{reason}</td>
    </tr>""" if reason else ""

    content = _hero_header("📬", hero_h, hero_s, "rgba(16, 185, 129, 0.2)")
    content += f"""
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #ECFDF5; border: 1px solid #A7F3D0; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding:4px 0;font-size:13px;color:#888888;width:120px;">{t_order}</td>
                        <td style="padding:4px 0;font-size:14px;color:#1a1a2e;font-weight:600;font-family:'Courier New',monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding:4px 0;font-size:13px;color:#888888;">{t_ret}</td>
                        <td style="padding:4px 0;font-size:14px;color:#1a1a2e;font-family:'Courier New',monospace;">#{short_rid}</td>
                    </tr>
                    {reason_row}
                    <tr>
                        <td style="padding:4px 0;font-size:13px;color:#888888;">{t_status_label}</td>
                        <td style="padding:4px 0;font-size:14px;color:#059669;font-weight:600;">{t_status_val}</td>
                    </tr>
                </table>
            </div>
        </td></tr>
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color:#f8f9ff;border:1px solid #e8ebf0;border-radius:12px;padding:16px 20px;">
                <p style="margin:0 0 8px 0;font-size:13px;font-weight:700;color:#1a1a2e;">{t_timeline_t}</p>
                <p style="margin:0;font-size:12px;color:#555555;line-height:1.6;">{t_timeline_b}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_orders", lang))

    buyer_email = return_data.get(Fields.CUSTOMER_EMAIL, "")
    return _email_wrapper("Return Received", content, include_gst=False, lang=lang, recipient_email=buyer_email)


def get_return_refunded_email(return_data: dict, return_id: str, order_id: str, lang: str = "en") -> str:
    """Email to buyer: refund for their return has been issued."""
    short_oid = order_id[:8]
    short_rid = return_id[:8]
    refund_cents = return_data.get(Fields.RETURN_REFUND_AMOUNT_CENTS, 0) or 0
    refund_amount = refund_cents / 100
    reason = html.escape(str(return_data.get(Fields.RETURN_REASON, "")))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color: #667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    hero_h = {"en": "Your Refund Has Been Issued 💰", "fr": "Votre remboursement a été émis 💰"}.get(lang, "Your Refund Has Been Issued 💰")
    hero_s = {
        "en": "Your return refund has been processed and is on its way to your original payment method.",
        "fr": "Votre remboursement de retour a été traité et est en route vers votre moyen de paiement d'origine.",
    }.get(lang, "Your return refund has been processed and is on its way to your original payment method.")
    t_order = _t("label.order_id", lang)
    t_ret = _t("return.label_return_id", lang)
    t_refund_amt = _t("label.refund_amount", lang)
    t_timeline_t = _t("refunded.timeline_t", lang)
    t_timeline_b = _t("refunded.timeline_b", lang).format(support=support_link)
    reason_row = f"""<tr>
        <td style="padding:4px 0;font-size:13px;color:#888888;">{_t("return.label_reason", lang)}</td>
        <td style="padding:4px 0;font-size:14px;color:#1a1a2e;">{reason}</td>
    </tr>""" if reason else ""

    content = _hero_header("💰", hero_h, hero_s, "rgba(16, 185, 129, 0.2)")
    content += f"""
        <tr><td style="padding: 24px 40px;">
            <div style="background-color: #ECFDF5; border: 1px solid #A7F3D0; border-radius: 16px; padding: 20px 24px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                    <tr>
                        <td style="padding:4px 0;font-size:13px;color:#888888;width:120px;">{t_order}</td>
                        <td style="padding:4px 0;font-size:14px;color:#1a1a2e;font-weight:600;font-family:'Courier New',monospace;">#{short_oid}</td>
                    </tr>
                    <tr>
                        <td style="padding:4px 0;font-size:13px;color:#888888;">{t_ret}</td>
                        <td style="padding:4px 0;font-size:14px;color:#1a1a2e;font-family:'Courier New',monospace;">#{short_rid}</td>
                    </tr>
                    {reason_row}
                    <tr>
                        <td style="padding:4px 0;font-size:13px;color:#888888;">{t_refund_amt}</td>
                        <td style="padding:4px 0;font-size:16px;color:#059669;font-weight:700;">${refund_amount:.2f} CAD</td>
                    </tr>
                </table>
            </div>
        </td></tr>
        <tr><td style="padding: 0 40px 24px 40px;">
            <div style="background-color:#f8f9ff;border:1px solid #e8ebf0;border-radius:12px;padding:16px 20px;">
                <p style="margin:0 0 8px 0;font-size:13px;font-weight:700;color:#1a1a2e;">{t_timeline_t}</p>
                <p style="margin:0;font-size:12px;color:#555555;line-height:1.6;">{t_timeline_b}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/orders", _t("cta.view_orders", lang))

    buyer_email = return_data.get(Fields.CUSTOMER_EMAIL, "")
    return _email_wrapper("Return Refunded", content, include_gst=False, lang=lang, recipient_email=buyer_email)


# ============================================================
# FLOW 7 — Premium Subscription email templates
# ============================================================

def get_premium_welcome_email(user_data: dict, period_end=None, lang: str = "en") -> str:
    """Welcome email sent when a user's premium subscription is first activated."""
    user_name = html.escape(user_data.get("name", ""))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color:#667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    period_str = ""
    if period_end:
        try:
            period_str = period_end.strftime("%B %d, %Y") if hasattr(period_end, "strftime") else str(period_end)
        except Exception:
            pass

    hero_h = {"en": "Welcome to Origna Premium! 🌟", "fr": "Bienvenue dans Origna Premium ! 🌟"}.get(lang, "Welcome to Origna Premium! 🌟")
    hero_s = {
        "en": "Your premium subscription is now active. Enjoy exclusive benefits!",
        "fr": "Votre abonnement premium est maintenant actif. Profitez des avantages exclusifs !",
    }.get(lang, "Your premium subscription is now active. Enjoy exclusive benefits!")

    benefits_en = [
        "🚚 Free shipping on all orders",
        "⭐ Priority customer support",
        "🔔 Early access to new products and sales",
        "🏷️ Exclusive member discounts",
    ]
    benefits_fr = [
        "🚚 Livraison gratuite sur toutes les commandes",
        "⭐ Support client prioritaire",
        "🔔 Accès anticipé aux nouveaux produits et ventes",
        "🏷️ Remises exclusives pour les membres",
    ]
    benefits = benefits_fr if lang == "fr" else benefits_en
    benefit_rows = "".join(
        f'<li style="margin:0 0 8px 0;font-size:14px;color:#333333;line-height:1.5;">{b}</li>'
        for b in benefits
    )

    t_next_billing = {
        "en": f"Your subscription renews on <strong>{period_str}</strong> at $7.86 CAD/month.",
        "fr": f"Votre abonnement se renouvelle le <strong>{period_str}</strong> à 7,86 $ CAD/mois.",
    }.get(lang, f"Your subscription renews on <strong>{period_str}</strong> at $7.86 CAD/month.") if period_str else ""

    t_manage = {
        "en": f"To manage or cancel your subscription at any time, visit your account settings or contact {support_link}.",
        "fr": f"Pour gérer ou annuler votre abonnement à tout moment, consultez les paramètres de votre compte ou contactez {support_link}.",
    }.get(lang, "")

    salutation = f"<p style='margin:0 0 16px 0;font-size:15px;color:#333;'>{('Hello' if lang == 'en' else 'Bonjour')} {user_name},</p>" if user_name else ""

    content = _hero_header("🌟", hero_h, hero_s, "rgba(102, 126, 234, 0.2)")
    content += f"""
        <tr><td style="padding:28px 40px;">
            {salutation}
            <p style="margin:0 0 16px 0;font-size:14px;color:#333;line-height:1.6;">
                {"You're now a Premium member of Origna — Canada's Modern Marketplace. Here's what you get:" if lang == "en" else "Vous êtes maintenant membre Premium d'Origna — la marketplace moderne du Canada. Voici vos avantages :"}
            </p>
            <ul style="margin:0 0 20px 0;padding-left:20px;">
                {benefit_rows}
            </ul>
        </td></tr>
        <tr><td style="padding:0 40px 24px 40px;">
            <div style="background-color:#f8f9ff;border:1px solid #e8ebf0;border-radius:12px;padding:16px 20px;">
                <p style="margin:0 0 8px 0;font-size:13px;color:#555;line-height:1.5;">{t_next_billing}</p>
                <p style="margin:0;font-size:12px;color:#888;line-height:1.5;">{t_manage}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/subscription", "Manage Subscription" if lang == "en" else "Gérer l'abonnement")

    recipient_email = user_data.get("email", "")
    return _email_wrapper("Welcome to Premium", content, include_gst=False, lang=lang, recipient_email=recipient_email)


def get_premium_cancellation_email(user_data: dict, period_end=None, lang: str = "en") -> str:
    """Confirmation email when a user schedules their subscription to cancel at period end."""
    user_name = html.escape(user_data.get("name", ""))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color:#667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    period_str = ""
    if period_end:
        try:
            period_str = period_end.strftime("%B %d, %Y") if hasattr(period_end, "strftime") else str(period_end)
        except Exception:
            pass

    hero_h = {"en": "Subscription Cancellation Confirmed", "fr": "Annulation d'abonnement confirmée"}.get(lang, "Subscription Cancellation Confirmed")
    hero_s = {
        "en": "Your premium subscription has been scheduled to cancel.",
        "fr": "Votre abonnement premium a été planifié pour annulation.",
    }.get(lang, "Your premium subscription has been scheduled to cancel.")

    t_access = {
        "en": f"You'll retain full premium access until <strong>{period_str}</strong>. After that, your account will revert to a standard membership." if period_str else "You'll retain full premium access until your current billing period ends.",
        "fr": f"Vous conserverez l'accès complet au premium jusqu'au <strong>{period_str}</strong>. Après cette date, votre compte reviendra à un abonnement standard." if period_str else "Vous conserverez l'accès complet au premium jusqu'à la fin de votre période de facturation en cours.",
    }.get(lang, "")
    t_reactivate = {
        "en": f"Changed your mind? You can reactivate anytime before {period_str} from your account settings or by contacting {support_link}." if period_str else f"Changed your mind? Reactivate from your account settings or contact {support_link}.",
        "fr": f"Vous avez changé d'avis ? Vous pouvez réactiver à tout moment avant le {period_str} depuis les paramètres de votre compte ou en contactant {support_link}." if period_str else f"Vous avez changé d'avis ? Réactivez depuis les paramètres de votre compte ou contactez {support_link}.",
    }.get(lang, "")

    salutation = f"<p style='margin:0 0 16px 0;font-size:15px;color:#333;'>{('Hello' if lang == 'en' else 'Bonjour')} {user_name},</p>" if user_name else ""

    content = _hero_header("❌", hero_h, hero_s, "rgba(220, 38, 38, 0.15)")
    content += f"""
        <tr><td style="padding:28px 40px;">
            {salutation}
            <div style="background-color:#FEF2F2;border:1px solid #FECACA;border-radius:12px;padding:16px 20px;margin-bottom:16px;">
                <p style="margin:0;font-size:14px;color:#333;line-height:1.6;">{t_access}</p>
            </div>
            <div style="background-color:#f8f9ff;border:1px solid #e8ebf0;border-radius:12px;padding:16px 20px;">
                <p style="margin:0;font-size:13px;color:#555;line-height:1.5;">{t_reactivate}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/subscription", "Manage Subscription" if lang == "en" else "Gérer l'abonnement")

    recipient_email = user_data.get("email", "")
    return _email_wrapper("Cancellation Confirmed", content, include_gst=False, lang=lang, recipient_email=recipient_email)


def get_premium_expired_email(user_data: dict, lang: str = "en") -> str:
    """Email sent when a subscription is fully deleted/expired by Stripe."""
    user_name = html.escape(user_data.get("name", ""))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color:#667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    hero_h = {"en": "Your Premium Subscription Has Ended", "fr": "Votre abonnement Premium a pris fin"}.get(lang, "Your Premium Subscription Has Ended")
    hero_s = {
        "en": "Your premium benefits are no longer active.",
        "fr": "Vos avantages premium ne sont plus actifs.",
    }.get(lang, "Your premium benefits are no longer active.")

    t_body = {
        "en": "We're sorry to see you go. Your account has been downgraded to a standard membership. You can still browse and shop on Origna — you'll just lose premium-exclusive benefits like free shipping.",
        "fr": "Nous sommes désolés de vous voir partir. Votre compte a été rétrogradé à un abonnement standard. Vous pouvez toujours naviguer et acheter sur Origna — vous perdez simplement les avantages exclusifs premium comme la livraison gratuite.",
    }.get(lang, "")
    t_resubscribe = {
        "en": f"Want to rejoin? Subscribe again at any time from your account settings. Questions? Contact {support_link}.",
        "fr": f"Envie de nous rejoindre à nouveau ? Réabonnez-vous à tout moment depuis les paramètres de votre compte. Des questions ? Contactez {support_link}.",
    }.get(lang, "")

    salutation = f"<p style='margin:0 0 16px 0;font-size:15px;color:#333;'>{('Hello' if lang == 'en' else 'Bonjour')} {user_name},</p>" if user_name else ""

    content = _hero_header("😔", hero_h, hero_s, "rgba(107, 114, 128, 0.2)")
    content += f"""
        <tr><td style="padding:28px 40px;">
            {salutation}
            <p style="margin:0 0 16px 0;font-size:14px;color:#333;line-height:1.6;">{t_body}</p>
            <div style="background-color:#f8f9ff;border:1px solid #e8ebf0;border-radius:12px;padding:16px 20px;">
                <p style="margin:0;font-size:13px;color:#555;line-height:1.5;">{t_resubscribe}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/subscription", "Subscribe Again" if lang == "en" else "Se réabonner")

    recipient_email = user_data.get("email", "")
    return _email_wrapper("Subscription Ended", content, include_gst=False, lang=lang, recipient_email=recipient_email)


def get_premium_payment_failed_email(user_data: dict, lang: str = "en") -> str:
    """Email sent when a subscription renewal payment fails (invoice.payment_failed)."""
    user_name = html.escape(user_data.get("name", ""))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color:#667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    hero_h = {"en": "⚠️ Premium Payment Failed", "fr": "⚠️ Paiement premium échoué"}.get(lang, "⚠️ Premium Payment Failed")
    hero_s = {
        "en": "We couldn't renew your premium subscription — please update your payment method.",
        "fr": "Nous n'avons pas pu renouveler votre abonnement premium — veuillez mettre à jour votre moyen de paiement.",
    }.get(lang, "We couldn't renew your premium subscription — please update your payment method.")

    t_body = {
        "en": "Your premium subscription renewal payment has failed. Your account has been temporarily downgraded. To restore premium access, please update your payment method in your account settings.",
        "fr": "Le paiement de renouvellement de votre abonnement premium a échoué. Votre compte a été temporairement rétrogradé. Pour restaurer l'accès premium, veuillez mettre à jour votre moyen de paiement dans les paramètres de votre compte.",
    }.get(lang, "")
    t_causes = {
        "en": ["Card has insufficient funds", "Card was cancelled or expired", "Bank declined the transaction"],
        "fr": ["Fonds insuffisants sur la carte", "Carte annulée ou expirée", "Banque a refusé la transaction"],
    }.get(lang, ["Card has insufficient funds", "Card was cancelled or expired", "Bank declined the transaction"])
    cause_rows = "".join(f'<li style="margin:0 0 4px 0;font-size:13px;color:#555;">{c}</li>' for c in t_causes)
    t_help = {
        "en": f"Need help? Contact {support_link} with your account email.",
        "fr": f"Besoin d'aide ? Contactez {support_link} avec l'adresse e-mail de votre compte.",
    }.get(lang, "")

    salutation = f"<p style='margin:0 0 16px 0;font-size:15px;color:#333;'>{('Hello' if lang == 'en' else 'Bonjour')} {user_name},</p>" if user_name else ""

    content = _hero_header("⚠️", hero_h, hero_s, "rgba(245, 158, 11, 0.2)")
    content += f"""
        <tr><td style="padding:28px 40px;">
            {salutation}
            <p style="margin:0 0 16px 0;font-size:14px;color:#333;line-height:1.6;">{t_body}</p>
            <div style="background-color:#FFFBEB;border:1px solid #FDE68A;border-radius:12px;padding:16px 20px;margin-bottom:16px;">
                <p style="margin:0 0 8px 0;font-size:13px;font-weight:700;color:#92400E;">{'Common causes:' if lang == 'en' else 'Causes fréquentes :'}</p>
                <ul style="margin:0;padding-left:18px;">{cause_rows}</ul>
            </div>
            <div style="background-color:#f8f9ff;border:1px solid #e8ebf0;border-radius:12px;padding:16px 20px;">
                <p style="margin:0;font-size:12px;color:#555;">{t_help}</p>
            </div>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/subscription", "Update Payment Method" if lang == "en" else "Mettre à jour le moyen de paiement")

    recipient_email = user_data.get("email", "")
    return _email_wrapper("Payment Failed", content, include_gst=False, lang=lang, recipient_email=recipient_email)


def get_premium_renewal_reminder_email(user_data: dict, period_end=None, days_remaining: int = 7, lang: str = "en") -> str:
    """Renewal reminder email sent N days before subscription renews."""
    user_name = html.escape(user_data.get("name", ""))
    support_link = f'<a href="mailto:{EmailConfig.SUPPORT_EMAIL}" style="color:#667EEA;">{EmailConfig.SUPPORT_EMAIL}</a>'

    period_str = ""
    if period_end:
        try:
            period_str = period_end.strftime("%B %d, %Y") if hasattr(period_end, "strftime") else str(period_end)
        except Exception:
            pass

    hero_h = {
        "en": f"Your Premium Renews in {days_remaining} Days",
        "fr": f"Votre Premium se renouvelle dans {days_remaining} jours",
    }.get(lang, f"Your Premium Renews in {days_remaining} Days")
    hero_s = {
        "en": "Just a friendly heads-up about your upcoming renewal.",
        "fr": "Juste un petit rappel concernant votre prochain renouvellement.",
    }.get(lang, "Just a friendly heads-up about your upcoming renewal.")

    t_body = {
        "en": f"Your Origna Premium subscription will automatically renew on <strong>{period_str}</strong> at <strong>$7.86 CAD/month</strong>.",
        "fr": f"Votre abonnement Origna Premium sera automatiquement renouvelé le <strong>{period_str}</strong> à <strong>7,86 $ CAD/mois</strong>.",
    }.get(lang, "") if period_str else {
        "en": "Your Origna Premium subscription is coming up for renewal at <strong>$7.86 CAD/month</strong>.",
        "fr": "Votre abonnement Origna Premium arrive à renouvellement à <strong>7,86 $ CAD/mois</strong>.",
    }.get(lang, "")

    t_manage = {
        "en": f"To cancel or manage your subscription, visit your account settings or contact {support_link}.",
        "fr": f"Pour annuler ou gérer votre abonnement, consultez les paramètres de votre compte ou contactez {support_link}.",
    }.get(lang, "")

    salutation = f"<p style='margin:0 0 16px 0;font-size:15px;color:#333;'>{('Hello' if lang == 'en' else 'Bonjour')} {user_name},</p>" if user_name else ""

    content = _hero_header("🔔", hero_h, hero_s, "rgba(102, 126, 234, 0.2)")
    content += f"""
        <tr><td style="padding:28px 40px;">
            {salutation}
            <div style="background-color:#f8f9ff;border:1px solid #e8ebf0;border-radius:12px;padding:16px 20px;margin-bottom:16px;">
                <p style="margin:0 0 8px 0;font-size:14px;color:#333;line-height:1.6;">{t_body}</p>
            </div>
            <p style="margin:0;font-size:12px;color:#888;line-height:1.5;">{t_manage}</p>
        </td></tr>
    """
    content += _cta_button(f"{APP_BASE_URL}/subscription", "Manage Subscription" if lang == "en" else "Gérer l'abonnement")

    recipient_email = user_data.get("email", "")
    return _email_wrapper("Renewal Reminder", content, include_gst=False, lang=lang, recipient_email=recipient_email)
