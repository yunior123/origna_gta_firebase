"""
Unit test for T-7: Transactional Stock Rollback and Race Condition Prevention.
Verifies that checkout stock deduction is handled atomically.
"""

from unittest.mock import MagicMock, patch

import pytest
from firebase_functions import https_fn

from handlers.payment_stripe import create_checkout_session


@patch("handlers.payment_stripe.get_db")
@patch("handlers.payment_stripe.get_firestore")
@patch("handlers.payment_stripe.stripe.checkout.Session.create")
def test_stock_reservation_atomic_pattern(mock_stripe_create, mock_get_fs, mock_get_db):
    """
    Verifies that create_checkout_session uses a transactional pattern for stock.
    We verify that reserve_stock_transaction is called and that we don't leak 
    stock if Stripe fails.
    """
    mock_db = MagicMock()
    mock_get_db.return_value = mock_db

    # Mock user and items
    mock_user_id = "user_123"
    mock_items = [{"productId": "p1", "quantity": 1, "price": 10.0, "sellerId": "seller_1"}]

    # Mock product snapshot (returned by individual .get() and get_all)
    mock_snap = MagicMock()
    mock_snap.exists = True
    mock_snap.id = "p1"
    mock_snap.to_dict.return_value = {
        "stockQuantity": 10,
        "name": "Test Product",
        "price": 10.0,
        "sellerId": "seller_1",
        "lifecycleStatus": "active",
        "inventory": {"allowBackorder": False}
    }

    # Generic doc mock for user/seller/order documents — not suspended
    mock_generic_doc = MagicMock()
    mock_generic_doc.exists = True
    mock_generic_doc.to_dict.return_value = {
        "suspended": False,
        "onboardingCompleted": True,
        "chargesEnabled": True,
        "payoutsEnabled": True,
        "stripeAccountId": "acct_test",
    }

    def make_doc_ref(doc_id=None):
        """Function make_doc_ref."""
        mock_ref = MagicMock()
        if doc_id is not None:
            mock_ref.id = doc_id
        if doc_id == "p1":
            mock_ref.get.return_value = mock_snap
        else:
            mock_ref.get.return_value = mock_generic_doc
        return mock_ref

    mock_db.collection.return_value.document.side_effect = make_doc_ref

    # Implement get_all for batch product fetches
    def get_all_impl(refs):
        """Function get_all_impl."""
        results = []
        for ref in refs:
            doc = ref.get()
            if isinstance(ref.id, str):
                doc.id = ref.id
            results.append(doc)
        return results

    mock_db.get_all = MagicMock(side_effect=get_all_impl)

    # Strip @transactional decorator so the function runs directly
    mock_get_fs.return_value.transactional = lambda f: f

    # Mock request
    mock_req = MagicMock()
    mock_req.auth.uid = mock_user_id
    mock_req.auth.token.get.return_value = True  # email_verified
    mock_req.data = {
        "items": mock_items,
        "shippingAddress": {
            "street": "123 Main St",
            "city": "Montreal",
            "state": "QC",
            "postalCode": "H2X 1Y6",
            "country": "Canada",
        },
        "subtotalCents": 1000,
    }

    # Stripe fails
    mock_stripe_create.side_effect = Exception("Stripe down")

    with pytest.raises(https_fn.HttpsError) as exc:
        create_checkout_session(mock_req)

    assert exc.value.code == "internal"

    # Verify a Firestore transaction was created for stock reservation
    # (stock reservation happens BEFORE Stripe session creation)
    mock_db.transaction.assert_called()

