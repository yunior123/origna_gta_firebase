"""Module test_notifications_flow.py."""
import os
from unittest.mock import MagicMock, patch

import pytest
from firebase_admin import firestore
from firebase_functions import https_fn

from schema_constants import Collections, Fields, UserRoleValues
from services.push_service import send_push_notification

# Force emulator mode
os.environ["FUNCTIONS_EMULATOR"] = "true"


@pytest.fixture
def mock_db():
    """Function mock_db."""
    with patch("services.push_service._get_db") as mock_get_db:
        db = MagicMock()
        mock_get_db.return_value = db
        yield db


class TestPushNotifications:
    """Tests for FCM push notifications."""

    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_push_skipped_if_push_disabled(self, mock_send, mock_db):
        """User explicitly opted out of push communications."""
        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {
            Fields.UID: "test_user_1",
            Fields.PUSH_ENABLED: False,  # Opted out
        }
        mock_db.collection.return_value.document.return_value.get.return_value = user_doc

        result = send_push_notification("test_user_1", "Test Title", "Test Body")

        assert result is False
        mock_send.assert_not_called()

    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_push_sent_to_multiple_devices(self, mock_send, mock_db):
        """Push should be sent to all device tokens of the user."""
        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {
            Fields.UID: "test_user_2",
            Fields.PUSH_ENABLED: True,
        }

        # Mock subcollection tokens
        token_doc1 = MagicMock()
        token_doc1.to_dict.return_value = {"token": "token_A"}
        token_doc2 = MagicMock()
        token_doc2.to_dict.return_value = {"token": "token_B"}

        user_ref = mock_db.collection.return_value.document.return_value
        user_ref.get.return_value = user_doc
        user_ref.collection.return_value.stream.return_value = [token_doc1, token_doc2]

        mock_response = MagicMock()
        mock_response.success_count = 2
        mock_response.responses = [MagicMock(success=True), MagicMock(success=True)]
        mock_send.return_value = mock_response

        # Include deep link payload data
        data_payload = {"type": "return_approved", "orderId": "order_abc"}
        result = send_push_notification("test_user_2", "Return Approved", "Your return is accepted.", data=data_payload)

        assert result is True
        mock_send.assert_called_once()
        msg_arg = mock_send.call_args[0][0]
        assert msg_arg.tokens == ["token_A", "token_B"]
        assert msg_arg.data == {"type": "return_approved", "orderId": "order_abc"}

    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_stale_tokens_removed_automatically(self, mock_send, mock_db):
        """Unregistered tokens should be automatically pruned."""
        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.UID: "test_user_3", Fields.PUSH_ENABLED: True}

        token_doc_valid = MagicMock()
        token_doc_valid.to_dict.return_value = {"token": "valid_token"}
        token_doc_valid.reference = MagicMock()

        token_doc_stale = MagicMock()
        token_doc_stale.to_dict.return_value = {"token": "stale_token"}
        token_doc_stale.reference = MagicMock()

        user_ref = mock_db.collection.return_value.document.return_value
        user_ref.get.return_value = user_doc
        user_ref.collection.return_value.stream.return_value = [token_doc_valid, token_doc_stale]

        # Simulate one success, one failure
        mock_response = MagicMock()
        mock_response.success_count = 1

        resp_success = MagicMock(success=True)
        resp_fail = MagicMock(success=False, exception=Exception("registration-token-not-registered"))
        mock_response.responses = [resp_success, resp_fail]
        mock_send.return_value = mock_response

        result = send_push_notification("test_user_3", "Update", "Check it out")

        assert result is True
        mock_send.assert_called_once()
        token_doc_valid.reference.delete.assert_not_called()
        token_doc_stale.reference.delete.assert_called_once()

class TestUserPushPreferences:
    """Test user settings for push notifications at creation."""

    @patch("handlers.users.get_db")
    def test_user_creation_saves_push_enabled_false(self, mock_get_db):
        """If user denies push perm during signup, pushEnabled: False should be saved."""
        from handlers.users import create_user_profile

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        user_ref = mock_db.collection.return_value.document.return_value
        user_doc = MagicMock()
        user_doc.exists = False
        user_ref.get.return_value = user_doc

        req = MagicMock()
        req.auth.uid = "user_456"
        req.auth.token = {"email": "test@orignagta.ca"}
        req.data = {
            "name": "Test User",
            Fields.PUSH_ENABLED: False  # Explicitly denied
        }

        # Bypass rate limiter and timestamps for simple check
        with patch("handlers.users.get_server_timestamp", return_value="2026-01-01T00:00:00Z"):
            resp = create_user_profile(req)

        assert resp["success"] is True
        user_ref.set.assert_called_once()
        set_data = user_ref.set.call_args[0][0]
        assert set_data[Fields.PUSH_ENABLED] is False

    @patch("handlers.users.get_db")
    def test_user_creation_default_push_enabled(self, mock_get_db):
        """If pushEnabled isn't specified, defaults to True."""
        from handlers.users import create_user_profile

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        user_ref = mock_db.collection.return_value.document.return_value
        user_doc = MagicMock()
        user_doc.exists = False
        user_ref.get.return_value = user_doc

        req = MagicMock()
        req.auth.uid = "user_789"
        req.auth.token = {"email": "test2@orignagta.ca"}
        req.data = {"name": "Test Two"} # No pushEnabled passed

        with patch("handlers.users.get_server_timestamp", return_value="2026-01-01T00:00:00Z"):
            create_user_profile(req)

        set_data = user_ref.set.call_args[0][0]
        assert set_data[Fields.PUSH_ENABLED] is True
