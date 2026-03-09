"""
Unit tests for handlers/users.py
Focusing on buyer address book operations.
"""

from unittest.mock import MagicMock, Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import Collections, Fields


class TestBuyerAddressHandlers:
    @patch("utils.helpers.geocode_address")
    @patch("handlers.users.get_db")
    def test_add_buyer_address_first_is_default(self, mock_get_db, mock_geocode_address):
        from handlers.users import add_buyer_address

        # Mock DB
        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_geocode_address.return_value = (
            True,
            "",
            {
                "street": "123 Main St",
                "city": "Toronto",
                "state": "ON",
                "postalCode": "M5V 2H1",
                "country": "Canada",
                Fields.LATITUDE: 43.6532,
                Fields.LONGITUDE: -79.3832,
            },
        )

        mock_new_ref = Mock()
        mock_new_ref.id = "address_123"

        mock_user_doc_snap = Mock()
        mock_user_doc_snap.to_dict.return_value = {"addressCount": 0}  # no existing addresses

        mock_user_doc_ref = Mock()
        mock_addresses_ref = Mock()
        mock_addresses_ref.where.return_value.get.return_value = []
        mock_addresses_ref.document.return_value = mock_new_ref

        mock_user_doc_ref.get.return_value = mock_user_doc_snap
        mock_user_doc_ref.collection.return_value = mock_addresses_ref

        mock_users_collection = Mock()
        mock_users_collection.document.return_value = mock_user_doc_ref

        mock_db.collection.return_value = mock_users_collection

        # Mock the transaction so _fs.transactional works without a real Firestore connection
        mock_transaction = Mock()
        mock_user_doc_ref.get = lambda transaction=None: mock_user_doc_snap
        mock_db.transaction.return_value = mock_transaction

        captured_set_args = []

        def fake_set(ref, data, **kwargs):
            captured_set_args.append((ref, data))

        mock_transaction.set.side_effect = fake_set
        mock_transaction.update = Mock()

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            mock_request = Mock()
            mock_request.auth = Mock(uid="buyer_123")
            mock_request.data = {
                "street": "123 Main St",
                "city": "Toronto",
                "state": "ON",
                "postalCode": "M5V 2H1",
                "country": "Canada",
            }

            result = add_buyer_address(mock_request)

        assert result["success"] is True
        assert result[Fields.ADDRESS_ID] == "address_123"
        # Verify it was added with isDefault=True
        assert mock_transaction.set.called
        added_data = mock_transaction.set.call_args[0][1]
        assert added_data[Fields.IS_DEFAULT] is True

    @patch("utils.helpers.geocode_address")
    @patch("handlers.users.get_db")
    def test_add_buyer_address_limit_exceeded(self, mock_get_db, mock_geocode_address):
        from handlers.users import add_buyer_address

        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_geocode_address.return_value = (
            True,
            "",
            {
                "street": "123 Main St",
                "city": "Toronto",
                "state": "ON",
                "postalCode": "M5V 2H1",
                "country": "Canada",
                Fields.LATITUDE: 43.6532,
                Fields.LONGITUDE: -79.3832,
            },
        )

        mock_user_doc_snap = Mock()
        mock_user_doc_snap.to_dict.return_value = {"addressCount": 10}  # at limit

        mock_user_doc_ref = Mock()
        mock_user_doc_ref.get = lambda transaction=None: mock_user_doc_snap

        mock_users_collection = Mock()
        mock_users_collection.document.return_value = mock_user_doc_ref
        mock_db.collection.return_value = mock_users_collection

        mock_transaction = Mock()
        mock_db.transaction.return_value = mock_transaction

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            mock_request = Mock()
            mock_request.auth = Mock(uid="buyer_123")
            mock_request.data = {
                "street": "123 Main St",
                "city": "Toronto",
                "state": "ON",
                "postalCode": "M5V 2H1",
                "country": "Canada",
            }

            with pytest.raises(https_fn.HttpsError) as exc:
                add_buyer_address(mock_request)

        assert exc.value.code == "resource-exhausted"
        assert "10 addresses" in str(exc.value.message)

    @patch("utils.helpers.geocode_address")
    @patch("handlers.users.get_db")
    def test_add_buyer_address_geocode_failure_surfaces_error(self, mock_get_db, mock_geocode_address):
        from handlers.users import add_buyer_address

        mock_get_db.return_value = Mock()
        mock_geocode_address.return_value = (False, "Address verification timed out — please try again", {})

        mock_request = Mock()
        mock_request.auth = Mock(uid="buyer_123")
        mock_request.data = {
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V 2H1",
            "country": "Canada",
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            add_buyer_address(mock_request)

        assert exc.value.code == "invalid-argument"
        assert "timed out" in str(exc.value.message)

    @patch("handlers.users.get_db")
    def test_update_buyer_address_invalid_id(self, mock_get_db):
        from handlers.users import update_buyer_address

        mock_request = Mock()
        mock_request.auth = Mock(uid="buyer_123")
        mock_request.data = {
            # Missing addressId
            "street": "123 Main St",
            "city": "Toronto",
            "state": "ON",
            "postalCode": "M5V 2H1",
            "country": "CA",
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            update_buyer_address(mock_request)

        assert exc.value.code == "invalid-argument"
        assert "addressId" in str(exc.value.message)

    @patch("handlers.users.get_db")
    def test_delete_buyer_address_promotes_default(self, mock_get_db):
        from handlers.users import delete_buyer_address

        mock_db = Mock()
        mock_get_db.return_value = mock_db

        # Transaction mock — the transactional decorator calls db.transaction()
        mock_txn = MagicMock()
        mock_db.transaction.return_value = mock_txn

        mock_addresses_ref = Mock()
        mock_address_ref = Mock()

        mock_doc = Mock()
        mock_doc.id = "address_123"
        mock_doc.exists = True
        mock_doc.to_dict.return_value = {Fields.IS_DEFAULT: True}
        # get(transaction=...) returns the doc snap
        mock_address_ref.get.return_value = mock_doc
        # Ownership check: address_ref.parent.parent.id must equal user_id
        mock_address_ref.parent = Mock()
        mock_address_ref.parent.parent = Mock()
        mock_address_ref.parent.parent.id = "buyer_123"

        # Second address to promote
        mock_other_doc = Mock()
        mock_other_doc.id = "address_456"
        mock_other_doc.reference = Mock()
        mock_addresses_ref.get.return_value = [mock_doc, mock_other_doc]
        mock_addresses_ref.document.return_value = mock_address_ref

        mock_user_doc_ref = Mock()
        mock_user_doc_ref.collection.return_value = mock_addresses_ref

        # Mock orders collection for active order check (ADDR-H1)
        mock_orders_collection = Mock()
        mock_orders_collection.where.return_value = mock_orders_collection
        mock_orders_collection.limit.return_value = mock_orders_collection
        mock_orders_collection.stream.return_value = []  # No active orders

        mock_users_collection = Mock()
        mock_users_collection.document.return_value = mock_user_doc_ref

        mock_db.collection.side_effect = lambda c: {
            "users": mock_users_collection,
            "orders": mock_orders_collection,
        }.get(c, Mock())

        mock_request = Mock()
        mock_request.auth = Mock(uid="buyer_123")
        mock_request.data = {Fields.ADDRESS_ID: "address_123"}

        result = delete_buyer_address(mock_request)

        assert result["success"] is True

    @patch("handlers.users.get_db")
    def test_set_default_buyer_address(self, mock_get_db):
        from handlers.users import set_default_buyer_address

        mock_db = Mock()
        mock_get_db.return_value = mock_db

        mock_addresses_ref = Mock()
        mock_address_ref = Mock()

        mock_doc_target = Mock()
        mock_doc_target.exists = True

        mock_doc_1 = Mock()
        mock_doc_1.id = "address_123"
        mock_doc_1.reference = Mock()
        mock_doc_1.to_dict.return_value = {Fields.IS_DEFAULT: False}

        mock_doc_2 = Mock()
        mock_doc_2.id = "address_456"
        mock_doc_2.reference = Mock()
        mock_doc_2.to_dict.return_value = {Fields.IS_DEFAULT: True}

        # Support both regular and transaction-based gets
        mock_addresses_ref.get = lambda transaction=None: [mock_doc_1, mock_doc_2]
        mock_address_ref.get = lambda transaction=None: mock_doc_target
        mock_addresses_ref.document.return_value = mock_address_ref

        mock_user_doc_ref = Mock()
        mock_user_doc_ref.collection.return_value = mock_addresses_ref
        mock_users_collection = Mock()
        mock_users_collection.document.return_value = mock_user_doc_ref
        mock_db.collection.return_value = mock_users_collection

        mock_transaction = Mock()
        mock_db.transaction.return_value = mock_transaction

        mock_request = Mock()
        mock_request.auth = Mock(uid="buyer_123")
        mock_request.data = {Fields.ADDRESS_ID: "address_123"}

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            result = set_default_buyer_address(mock_request)

        assert result["success"] is True
        # Verify transaction.update called: address_123 → True, address_456 → False
        assert mock_transaction.update.call_count == 2
        calls = mock_transaction.update.call_args_list
        refs_and_vals = {call[0][0]: call[0][1] for call in calls}
        assert refs_and_vals.get(mock_doc_1.reference) == {Fields.IS_DEFAULT: True}
        assert refs_and_vals.get(mock_doc_2.reference) == {Fields.IS_DEFAULT: False}
