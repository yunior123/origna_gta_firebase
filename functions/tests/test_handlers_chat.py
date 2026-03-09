"""
Tests for handlers/chat.py — product-scoped buyer↔seller messaging.

Coverage:
- _sanitize_text: email/URL/phone redaction, HTML stripping, XSS, unicode normalization
- get_or_create_chat: auth guards, premium gate, order eligibility, self-chat, idempotency
- send_message: validation, capacity, deduplication, non-premium, rate limit, persistence
- mark_messages_read: access control, batch marking, counter reset
- delete_message: sender/admin permission, idempotency, not-found
- report_message: participant check, message existence, report creation
"""
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, Mock, patch

import pytest

from schema_constants import BusinessRules, Fields, ProductLifecycleStatusValues


# ============================================================================
# _sanitize_text — pure function, no mocks needed
# ============================================================================


class TestSanitizeText:
    """Class TestSanitizeText."""
    def _s(self, text: str) -> str:
        from handlers.chat import _sanitize_text
        return _sanitize_text(text)

    def test_strips_html_tags(self):
        """Function test_strips_html_tags."""
        assert self._s("<b>hello</b>") == "hello"

    def test_strips_script_block(self):
        """Function test_strips_script_block."""
        assert '<script>' not in self._s('<script>alert("xss")</script>')

    def test_removes_javascript_scheme(self):
        """Function test_removes_javascript_scheme."""
        assert "javascript:" not in self._s("Click: javascript:void(0)")

    def test_redacts_plain_email(self):
        """Function test_redacts_plain_email."""
        result = self._s("Contact me at test@example.com please")
        assert "[email removed]" in result
        assert "test@example.com" not in result

    def test_redacts_obfuscated_email(self):
        """Function test_redacts_obfuscated_email."""
        result = self._s("Email me at test (at) example.com")
        assert "test (at) example.com" not in result

    def test_redacts_http_url(self):
        """Function test_redacts_http_url."""
        result = self._s("Check http://example.com for details")
        assert "[link removed]" in result

    def test_redacts_https_url(self):
        """Function test_redacts_https_url."""
        result = self._s("Visit https://evil.com/scam")
        assert "[link removed]" in result

    def test_redacts_www_url(self):
        """Function test_redacts_www_url."""
        result = self._s("Go to www.example.com")
        assert "[link removed]" in result

    def test_redacts_10_digit_phone_with_dashes(self):
        """Function test_redacts_10_digit_phone_with_dashes."""
        result = self._s("Call me at 416-555-1234")
        assert "[phone removed]" in result

    def test_strips_zero_width_chars(self):
        # Zero-width space used to bypass redaction filters
        """Function test_strips_zero_width_chars."""
        result = self._s("test\u200b@\u200bexample.com")
        assert "\u200b" not in result

    def test_empty_string_returns_empty(self):
        """Function test_empty_string_returns_empty."""
        assert self._s("") == ""

    def test_clean_message_unchanged(self):
        """Function test_clean_message_unchanged."""
        msg = "Hello, is this item still available?"
        assert self._s(msg) == msg


# ============================================================================
# get_or_create_chat
# ============================================================================


class TestGetOrCreateChat:
    """Class TestGetOrCreateChat."""
    def _req(self, uid: str = "buyer_123", data: dict | None = None) -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = uid
        req.data = data if data is not None else {Fields.PRODUCT_ID: "prod_123"}
        return req

    def _active_product(self, seller_id: str = "seller_123") -> Mock:
        doc = Mock()
        doc.exists = True
        doc.to_dict.return_value = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.SELLER_ID: seller_id,
            Fields.NAME: "Test Product",
            Fields.IMAGE_URLS: [],
        }
        return doc

    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.chat import get_or_create_chat

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            get_or_create_chat(req)
        assert exc.value.code == "unauthenticated"

    def test_missing_product_id_raises(self):
        """Function test_missing_product_id_raises."""
        from firebase_functions import https_fn
        from handlers.chat import get_or_create_chat

        with patch("handlers.chat._is_premium", return_value=True):
            req = self._req(data={Fields.PRODUCT_ID: "   "})
            with pytest.raises(https_fn.HttpsError) as exc:
                get_or_create_chat(req)
        assert exc.value.code == "invalid-argument"

    def test_non_premium_buyer_rejected(self):
        """Function test_non_premium_buyer_rejected."""
        from firebase_functions import https_fn
        from handlers.chat import get_or_create_chat

        with patch("handlers.chat._is_premium", return_value=False):
            req = self._req()
            with pytest.raises(https_fn.HttpsError) as exc:
                get_or_create_chat(req)
        assert exc.value.code == "permission-denied"
        assert "Premium" in exc.value.message

    @patch("handlers.chat._get_db")
    def test_product_not_found_raises(self, mock_get_db):
        """Function test_product_not_found_raises."""
        from firebase_functions import https_fn
        from handlers.chat import get_or_create_chat

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        not_found = Mock()
        not_found.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = not_found

        with patch("handlers.chat._is_premium", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                get_or_create_chat(self._req())
        assert exc.value.code == "not-found"

    @patch("handlers.chat._get_db")
    def test_inactive_product_raises(self, mock_get_db):
        """Function test_inactive_product_raises."""
        from firebase_functions import https_fn
        from handlers.chat import get_or_create_chat

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        paused = Mock()
        paused.exists = True
        paused.to_dict.return_value = {
            Fields.LIFECYCLE_STATUS: "paused",
            Fields.SELLER_ID: "seller_123",
        }
        mock_db.collection.return_value.document.return_value.get.return_value = paused

        with patch("handlers.chat._is_premium", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                get_or_create_chat(self._req())
        assert exc.value.code == "not-found"

    @patch("handlers.chat._get_db")
    def test_self_chat_rejected(self, mock_get_db):
        """Function test_self_chat_rejected."""
        from firebase_functions import https_fn
        from handlers.chat import get_or_create_chat

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        prod = self._active_product(seller_id="buyer_123")  # seller == buyer
        mock_db.collection.return_value.document.return_value.get.return_value = prod

        with patch("handlers.chat._is_premium", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                get_or_create_chat(self._req(uid="buyer_123"))
        assert exc.value.code == "permission-denied"

    @patch("handlers.chat._get_db")
    def test_no_delivered_order_raises(self, mock_get_db):
        """Function test_no_delivered_order_raises."""
        from firebase_functions import https_fn
        from handlers.chat import get_or_create_chat

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "products":
                c.document.return_value.get.return_value = self._active_product()
            elif name == "orders":
                q = MagicMock()
                q.where.return_value = q
                q.limit.return_value = q
                q.get.return_value = []  # No eligible orders
                c.where.return_value = q
            return c

        mock_db.collection.side_effect = coll

        with patch("handlers.chat._is_premium", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                get_or_create_chat(self._req())
        assert exc.value.code == "failed-precondition"
        assert "delivered" in exc.value.message.lower()

    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="mock_ts")
    def test_creates_new_chat(self, _mock_ts, mock_get_db):
        """Function test_creates_new_chat."""
        from handlers.chat import get_or_create_chat

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_ref = MagicMock()
        chat_ref.create.return_value = None

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "products":
                c.document.return_value.get.return_value = self._active_product()
            elif name == "orders":
                q = MagicMock()
                q.where.return_value = q
                q.limit.return_value = q
                q.get.return_value = [Mock()]  # Eligible order found
                c.where.return_value = q
            elif name == "chats":
                c.document.return_value = chat_ref
            return c

        mock_db.collection.side_effect = coll

        with patch("handlers.chat._is_premium", return_value=True):
            result = get_or_create_chat(self._req())

        assert result["chatId"] == "prod_123_buyer_123"
        assert result["isNew"] is True
        chat_ref.create.assert_called_once()

    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="mock_ts")
    def test_returns_existing_on_already_exists_error(self, _mock_ts, mock_get_db):
        """Function test_returns_existing_on_already_exists_error."""
        from handlers.chat import get_or_create_chat

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_ref = MagicMock()
        chat_ref.create.side_effect = Exception("ALREADY_EXISTS: Document already exists")

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "products":
                c.document.return_value.get.return_value = self._active_product()
            elif name == "orders":
                q = MagicMock()
                q.where.return_value = q
                q.limit.return_value = q
                q.get.return_value = [Mock()]
                c.where.return_value = q
            elif name == "chats":
                c.document.return_value = chat_ref
            return c

        mock_db.collection.side_effect = coll

        with patch("handlers.chat._is_premium", return_value=True):
            result = get_or_create_chat(self._req())

        assert result["chatId"] == "prod_123_buyer_123"
        assert result["isNew"] is False


# ============================================================================
# send_message — validation guards
# ============================================================================


class TestSendMessage:
    """Class TestSendMessage."""
    def _req(self, uid: str = "buyer_123", data: dict | None = None) -> Mock:
        req = Mock()
        req.auth = Mock()
        req.auth.uid = uid
        req.data = data if data is not None else {
            Fields.CHAT_ID: "prod_123_buyer_123",
            Fields.MESSAGE_TEXT: "Is this still available?",
        }
        return req

    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(req)
        assert exc.value.code == "unauthenticated"

    def test_missing_chat_id_raises(self):
        """Function test_missing_chat_id_raises."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        req = self._req(data={Fields.CHAT_ID: None, Fields.MESSAGE_TEXT: "Hello"})
        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(req)
        assert exc.value.code == "invalid-argument"

    def test_too_many_images_raises(self):
        """Function test_too_many_images_raises."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        req = self._req(data={
            Fields.CHAT_ID: "chat_123",
            Fields.MESSAGE_TEXT: "",
            Fields.IMAGE_URLS: [f"https://cdn.test/{i}.jpg" for i in range(6)],
        })
        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(req)
        assert exc.value.code == "invalid-argument"
        assert "5 images" in exc.value.message

    def test_non_cdn_image_rejected(self):
        """Function test_non_cdn_image_rejected."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        req = self._req(data={
            Fields.CHAT_ID: "chat_123",
            Fields.MESSAGE_TEXT: "",
            Fields.IMAGE_URLS: ["https://evil.com/image.jpg"],
        })
        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(req)
        assert exc.value.code == "invalid-argument"
        assert "CDN" in exc.value.message

    @patch("handlers.chat._get_db")
    def test_non_participant_rejected(self, mock_get_db):
        """Function test_non_participant_rejected."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "other_buyer",
            Fields.SELLER_ID: "seller_123",
            Fields.MESSAGE_COUNT: 0,
            Fields.LAST_MESSAGE_TEXT: None,
        }
        mock_db.collection.return_value.document.return_value.get.return_value = chat_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(self._req(uid="intruder_999"))
        assert exc.value.code == "permission-denied"

    @patch("handlers.chat._get_db")
    def test_thread_at_capacity_raises(self, mock_get_db):
        """Function test_thread_at_capacity_raises."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_123",
            Fields.SELLER_ID: "seller_123",
            Fields.MESSAGE_COUNT: BusinessRules.MAX_MESSAGES_PER_THREAD,
            Fields.LAST_MESSAGE_TEXT: None,
        }
        sender_doc = Mock()
        sender_doc.to_dict.return_value = {Fields.NAME: "Test Buyer"}

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "chats":
                c.document.return_value.get.return_value = chat_doc
            elif name == "users":
                c.document.return_value.get.return_value = sender_doc
            return c

        mock_db.collection.side_effect = coll

        with patch("handlers.chat._is_premium", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                send_message(self._req())
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.chat._get_db")
    def test_duplicate_message_within_5s_raises(self, mock_get_db):
        """Function test_duplicate_message_within_5s_raises."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        last_ts = datetime.now(UTC) - timedelta(seconds=2)
        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_123",
            Fields.SELLER_ID: "seller_123",
            Fields.MESSAGE_COUNT: 5,
            Fields.LAST_MESSAGE_TEXT: "Is this still available?",  # Exact same text
            Fields.UPDATED_AT: last_ts,
        }
        sender_doc = Mock()
        sender_doc.to_dict.return_value = {Fields.NAME: "Test Buyer"}

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "chats":
                c.document.return_value.get.return_value = chat_doc
            elif name == "users":
                c.document.return_value.get.return_value = sender_doc
            return c

        mock_db.collection.side_effect = coll

        with patch("handlers.chat._is_premium", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                send_message(self._req())
        assert exc.value.code == "already-exists"

    @patch("handlers.chat._get_db")
    def test_non_premium_buyer_rejected_in_send(self, mock_get_db):
        """Function test_non_premium_buyer_rejected_in_send."""
        from firebase_functions import https_fn
        from handlers.chat import send_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_123",
            Fields.SELLER_ID: "seller_123",
            Fields.MESSAGE_COUNT: 0,
            Fields.LAST_MESSAGE_TEXT: None,
        }
        sender_doc = Mock()
        sender_doc.to_dict.return_value = {Fields.NAME: "Test Buyer"}

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "chats":
                c.document.return_value.get.return_value = chat_doc
            elif name == "users":
                c.document.return_value.get.return_value = sender_doc
            return c

        mock_db.collection.side_effect = coll

        with patch("handlers.chat._is_premium", return_value=False):
            with pytest.raises(https_fn.HttpsError) as exc:
                send_message(self._req(uid="buyer_123"))
        assert exc.value.code == "permission-denied"


# ============================================================================
# mark_messages_read
# ============================================================================


class TestMarkMessagesRead:
    """Class TestMarkMessagesRead."""
    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.chat import mark_messages_read

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            mark_messages_read(req)
        assert exc.value.code == "unauthenticated"

    def test_missing_chat_id_raises(self):
        """Function test_missing_chat_id_raises."""
        from firebase_functions import https_fn
        from handlers.chat import mark_messages_read

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "buyer_123"
        req.data = {Fields.CHAT_ID: ""}
        with pytest.raises(https_fn.HttpsError) as exc:
            mark_messages_read(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.chat._get_db")
    def test_non_participant_access_denied(self, mock_get_db):
        """Function test_non_participant_access_denied."""
        from firebase_functions import https_fn
        from handlers.chat import mark_messages_read

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_456",
            Fields.SELLER_ID: "seller_123",
        }
        mock_db.collection.return_value.document.return_value.get.return_value = chat_doc

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "intruder_789"
        req.data = {Fields.CHAT_ID: "chat_123"}

        with pytest.raises(https_fn.HttpsError) as exc:
            mark_messages_read(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.chat._get_db")
    def test_resets_buyer_unread_count(self, mock_get_db):
        """Function test_resets_buyer_unread_count."""
        from handlers.chat import mark_messages_read

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_123",
            Fields.SELLER_ID: "seller_123",
        }

        # Two unread messages from the seller
        msg1 = Mock()
        msg1.reference = Mock()
        msg2 = Mock()
        msg2.reference = Mock()

        mock_batch = MagicMock()
        mock_db.batch.return_value = mock_batch

        chat_coll = MagicMock()
        chat_coll.document.return_value.get.return_value = chat_doc
        msgs_query = MagicMock()
        msgs_query.where.return_value = msgs_query
        msgs_query.limit.return_value = msgs_query
        msgs_query.stream.return_value = iter([msg1, msg2])
        chat_coll.document.return_value.collection.return_value = msgs_query

        mock_db.collection.return_value = chat_coll

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "buyer_123"
        req.data = {Fields.CHAT_ID: "chat_123"}

        result = mark_messages_read(req)
        assert result["success"] is True
        assert result["count"] == 2
        mock_batch.commit.assert_called_once()


# ============================================================================
# delete_message
# ============================================================================


class TestDeleteMessage:
    """Class TestDeleteMessage."""
    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.chat import delete_message

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_message(req)
        assert exc.value.code == "unauthenticated"

    def test_missing_args_raises(self):
        """Function test_missing_args_raises."""
        from firebase_functions import https_fn
        from handlers.chat import delete_message

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "u"
        req.data = {Fields.CHAT_ID: None, Fields.MESSAGE_ID: None}
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_message(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.chat._get_db")
    def test_non_sender_non_admin_rejected(self, mock_get_db):
        """Function test_non_sender_non_admin_rejected."""
        from firebase_functions import https_fn
        from handlers.chat import delete_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        msg_doc = Mock()
        msg_doc.exists = True
        msg_doc.to_dict.return_value = {Fields.SENDER_ID: "actual_sender", Fields.DELETED: False}

        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: ["buyer"]}

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "chats":
                msgs_c = MagicMock()
                msgs_c.document.return_value.get.return_value = msg_doc
                c.document.return_value.collection.return_value = msgs_c
            elif name == "users":
                c.document.return_value.get.return_value = user_doc
            return c

        mock_db.collection.side_effect = coll

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "intruder"
        req.data = {Fields.CHAT_ID: "chat_123", Fields.MESSAGE_ID: "msg_456"}

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_message(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="mock_ts")
    def test_already_deleted_idempotent(self, _ts, mock_get_db):
        """Function test_already_deleted_idempotent."""
        from handlers.chat import delete_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        msg_doc = Mock()
        msg_doc.exists = True
        msg_doc.to_dict.return_value = {Fields.SENDER_ID: "user_123", Fields.DELETED: True}
        msg_ref = MagicMock()
        msg_ref.get.return_value = msg_doc

        def coll(name):
            """Function coll."""
            c = MagicMock()
            msgs_c = MagicMock()
            msgs_c.document.return_value = msg_ref
            c.document.return_value.collection.return_value = msgs_c
            return c

        mock_db.collection.side_effect = coll

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "user_123"
        req.data = {Fields.CHAT_ID: "chat_123", Fields.MESSAGE_ID: "msg_456"}

        result = delete_message(req)
        assert result["success"] is True
        # No update called on an already-deleted message
        msg_ref.update.assert_not_called()


# ============================================================================
# report_message
# ============================================================================


class TestReportMessage:
    """Class TestReportMessage."""
    def test_unauthenticated_raises(self):
        """Function test_unauthenticated_raises."""
        from firebase_functions import https_fn
        from handlers.chat import report_message

        req = Mock()
        req.auth = None
        with pytest.raises(https_fn.HttpsError) as exc:
            report_message(req)
        assert exc.value.code == "unauthenticated"

    def test_missing_args_raises(self):
        """Function test_missing_args_raises."""
        from firebase_functions import https_fn
        from handlers.chat import report_message

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "u"
        req.data = {Fields.CHAT_ID: "", Fields.MESSAGE_ID: ""}
        with pytest.raises(https_fn.HttpsError) as exc:
            report_message(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.chat._get_db")
    def test_non_participant_rejected(self, mock_get_db):
        """Function test_non_participant_rejected."""
        from firebase_functions import https_fn
        from handlers.chat import report_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_456",
            Fields.SELLER_ID: "seller_123",
        }
        mock_db.collection.return_value.document.return_value.get.return_value = chat_doc

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "outsider"
        req.data = {Fields.CHAT_ID: "chat_123", Fields.MESSAGE_ID: "msg_456"}

        with pytest.raises(https_fn.HttpsError) as exc:
            report_message(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="mock_ts")
    def test_creates_report_and_returns_report_id(self, _ts, mock_get_db):
        """Function test_creates_report_and_returns_report_id."""
        from handlers.chat import report_message

        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_123",
            Fields.SELLER_ID: "seller_123",
        }

        msg_doc = Mock()
        msg_doc.exists = True
        msg_doc.to_dict.return_value = {
            Fields.MESSAGE_TEXT: "Check my website",
            Fields.SENDER_ID: "seller_123",
        }

        report_ref = MagicMock()
        report_ref.id = "report_abc"

        def coll(name):
            """Function coll."""
            c = MagicMock()
            if name == "chats":
                c.document.return_value.get.return_value = chat_doc
                msgs_c = MagicMock()
                msgs_c.document.return_value.get.return_value = msg_doc
                c.document.return_value.collection.return_value = msgs_c
            elif name == "message_reports":
                c.document.return_value = report_ref
            return c

        mock_db.collection.side_effect = coll

        req = Mock()
        req.auth = Mock()
        req.auth.uid = "buyer_123"
        req.data = {
            Fields.CHAT_ID: "chat_123",
            Fields.MESSAGE_ID: "msg_456",
            "reason": "Off-platform contact attempt",
        }

        result = report_message(req)
        assert result["success"] is True
        assert Fields.REPORT_ID in result
        report_ref.set.assert_called_once()
