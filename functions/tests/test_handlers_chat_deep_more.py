from datetime import datetime, timedelta
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    ValidationLimits,
)


def _chat_req(uid="buyer_1", data=None):
    req = Mock()
    req.auth = Mock()
    req.auth.uid = uid
    req.data = data or {Fields.CHAT_ID: "prod_1_buyer_1", Fields.MESSAGE_TEXT: "hello"}
    return req


class TestChatMorePureBranches:
    def test_is_premium_uses_authoritative_subscription_check(self):
        from handlers.chat import _is_premium

        db = Mock()
        with patch("handlers.chat._get_db", return_value=db), patch(
            "utils.premium_check.is_premium_authoritative", return_value=True
        ) as mock_auth:
            assert _is_premium("u1") is True
        mock_auth.assert_called_once_with("u1", db=db)

    def test_sanitize_text_keeps_non_phone_long_digit_string(self):
        from handlers.chat import _sanitize_text

        raw = "Code 12345678901234567890 should stay"
        out = _sanitize_text(raw)
        assert "12345678901234567890" in out


class TestGetOrCreateChatMoreBranches:
    @patch("handlers.chat._is_premium", return_value=True)
    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="ts")
    def test_get_or_create_chat_unknown_create_error_is_raised(self, _mock_ts, mock_get_db, _mock_premium):
        from handlers.chat import get_or_create_chat

        db = Mock()
        mock_get_db.return_value = db

        product_doc = Mock()
        product_doc.exists = True
        product_doc.to_dict.return_value = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Product",
            Fields.IMAGE_URLS: [],
        }
        order_query = Mock()
        order_query.where.return_value = order_query
        order_query.limit.return_value = order_query
        order_query.get.return_value = [Mock()]
        chat_ref = Mock()
        chat_ref.create.side_effect = Exception("boom")

        def _collection(name):
            c = Mock()
            if name == Collections.PRODUCTS:
                c.document.return_value.get.return_value = product_doc
            elif name == Collections.ORDERS:
                c.where.return_value = order_query
            elif name == Collections.CHATS:
                c.document.return_value = chat_ref
            return c

        db.collection.side_effect = _collection

        req = _chat_req(data={Fields.PRODUCT_ID: "prod_1"})
        with pytest.raises(Exception, match="boom"):
            get_or_create_chat(req)


class TestMarkMessagesReadMoreBranches:
    @patch("handlers.chat._get_db")
    def test_mark_messages_read_chat_not_found(self, mock_get_db):
        from handlers.chat import mark_messages_read

        db = Mock()
        chat_doc = Mock()
        chat_doc.exists = False
        db.collection.return_value.document.return_value.get.return_value = chat_doc
        mock_get_db.return_value = db

        req = _chat_req(data={Fields.CHAT_ID: "chat_1"})
        with pytest.raises(https_fn.HttpsError) as exc:
            mark_messages_read(req)
        assert exc.value.code == "not-found"


class TestSendMessageMoreBranches:
    def test_send_message_rejects_empty_after_sanitization(self):
        from handlers.chat import send_message

        req = _chat_req(data={Fields.CHAT_ID: "chat_1", Fields.MESSAGE_TEXT: "<script>x</script>"})
        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(req)
        assert exc.value.code == "invalid-argument"

    def test_send_message_rejects_too_long_message(self):
        from handlers.chat import send_message

        too_long = "x" * (ValidationLimits.MAX_MESSAGE_LENGTH + 1)
        req = _chat_req(data={Fields.CHAT_ID: "chat_1", Fields.MESSAGE_TEXT: too_long})
        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.chat._get_db")
    def test_send_message_chat_not_found(self, mock_get_db):
        from handlers.chat import send_message

        db = Mock()
        chat_doc = Mock()
        chat_doc.exists = False
        db.collection.return_value.document.return_value.get.return_value = chat_doc
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(_chat_req())
        assert exc.value.code == "not-found"

    @patch("handlers.chat._is_premium", return_value=True)
    @patch("handlers.chat._get_db")
    def test_send_message_duplicate_with_naive_datetime_hits_tz_normalization(self, mock_get_db, _mock_premium):
        from handlers.chat import send_message

        db = Mock()
        naive_now = datetime.utcnow() - timedelta(seconds=2)  # naive UTC; triggers tz-normalization + duplicate guard
        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
            Fields.MESSAGE_COUNT: 1,
            Fields.LAST_MESSAGE_TEXT: "hello",
            Fields.UPDATED_AT: naive_now,
        }
        db.collection.return_value.document.return_value.get.return_value = chat_doc
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(_chat_req(uid="buyer_1"))
        assert exc.value.code == "already-exists"

    @patch("handlers.chat._is_premium", return_value=True)
    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="ts")
    @patch("services.rate_limiter.RateLimiter")
    def test_send_message_rate_limit_exceeded(self, mock_rl, _mock_ts, mock_get_db, _mock_premium):
        from handlers.chat import send_message

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (False, "slow")

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
            Fields.MESSAGE_COUNT: 1,
            Fields.LAST_MESSAGE_TEXT: None,
        }
        sender_doc = Mock()
        sender_doc.to_dict.return_value = {Fields.NAME: "Buyer"}

        def _collection(name):
            c = Mock()
            if name == Collections.CHATS:
                c.document.return_value.get.return_value = chat_doc
            elif name == Collections.USERS:
                c.document.return_value.get.return_value = sender_doc
            return c

        db.collection.side_effect = _collection

        with pytest.raises(https_fn.HttpsError) as exc:
            send_message(_chat_req(uid="buyer_1"))
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.chat._is_premium", return_value=True)
    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="ts")
    @patch("services.rate_limiter.RateLimiter")
    @patch("services.push_service.send_push_notification")
    def test_send_message_success_persists_message_updates_thread_and_pushes(
        self, mock_push, mock_rl, _mock_ts, mock_get_db, _mock_premium
    ):
        from handlers.chat import send_message

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
            Fields.MESSAGE_COUNT: 1,
            Fields.LAST_MESSAGE_TEXT: None,
            Fields.FIRST_BUYER_MESSAGE_AT: None,
        }
        sender_doc = Mock()
        sender_doc.to_dict.return_value = {Fields.NAME: "Buyer"}

        msg_ref = Mock()
        msg_ref.id = "msg_1"
        chat_ref = Mock()
        chat_ref.get.return_value = chat_doc
        chat_ref.collection.return_value.document.return_value = msg_ref

        def _collection(name):
            c = Mock()
            if name == Collections.CHATS:
                c.document.return_value = chat_ref
            elif name == Collections.USERS:
                c.document.return_value.get.return_value = sender_doc
            return c

        db.collection.side_effect = _collection

        result = send_message(_chat_req(uid="buyer_1"))
        assert result["success"] is True
        assert result["messageId"] == "msg_1"
        msg_ref.set.assert_called_once()
        chat_ref.update.assert_called_once()
        mock_push.assert_called_once()

    @patch("handlers.chat._is_premium", return_value=True)
    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="ts")
    @patch("services.rate_limiter.RateLimiter")
    @patch("services.push_service.send_push_notification", side_effect=Exception("push down"))
    def test_send_message_push_failures_are_swallowed(
        self, _mock_push, mock_rl, _mock_ts, mock_get_db, _mock_premium
    ):
        from handlers.chat import send_message

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
            Fields.MESSAGE_COUNT: 1,
            Fields.LAST_MESSAGE_TEXT: None,
        }
        sender_doc = Mock()
        sender_doc.to_dict.return_value = {Fields.NAME: "Buyer"}

        msg_ref = Mock()
        msg_ref.id = "msg_2"
        chat_ref = Mock()
        chat_ref.get.return_value = chat_doc
        chat_ref.collection.return_value.document.return_value = msg_ref

        def _collection(name):
            c = Mock()
            if name == Collections.CHATS:
                c.document.return_value = chat_ref
            elif name == Collections.USERS:
                c.document.return_value.get.return_value = sender_doc
            return c

        db.collection.side_effect = _collection

        result = send_message(_chat_req(uid="buyer_1"))
        assert result["success"] is True
        assert result["messageId"] == "msg_2"

    @patch("handlers.chat._is_premium", return_value=True)
    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="ts")
    @patch("services.rate_limiter.RateLimiter")
    def test_send_message_with_existing_message_id_is_idempotent(
        self, mock_rl, _mock_ts, mock_get_db, _mock_premium
    ):
        from handlers.chat import send_message

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
            Fields.MESSAGE_COUNT: 1,
            Fields.LAST_MESSAGE_TEXT: None,
        }
        sender_doc = Mock()
        sender_doc.to_dict.return_value = {Fields.NAME: "Buyer"}

        msg_ref = Mock()
        msg_ref.id = "msg_existing"
        existing_msg_doc = Mock()
        existing_msg_doc.exists = True
        msg_ref.get.return_value = existing_msg_doc

        chat_ref = Mock()
        chat_ref.get.return_value = chat_doc
        chat_ref.collection.return_value.document.return_value = msg_ref

        def _collection(name):
            c = Mock()
            if name == Collections.CHATS:
                c.document.return_value = chat_ref
            elif name == Collections.USERS:
                c.document.return_value.get.return_value = sender_doc
            return c

        db.collection.side_effect = _collection

        req = _chat_req(
            uid="buyer_1",
            data={Fields.CHAT_ID: "prod_1_buyer_1", Fields.MESSAGE_TEXT: "hello", Fields.MESSAGE_ID: "msg_existing"},
        )
        out = send_message(req)
        assert out == {"success": True, "messageId": "msg_existing"}
        msg_ref.set.assert_not_called()
        chat_ref.update.assert_not_called()

    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="ts")
    @patch("services.rate_limiter.RateLimiter")
    @patch("services.push_service.send_push_notification")
    def test_send_message_seller_first_reply_sets_response_metrics(self, mock_push, mock_rl, _mock_ts, mock_get_db):
        from handlers.chat import send_message

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        first_buyer_msg_at = datetime.utcnow() - timedelta(hours=4)
        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {
            Fields.BUYER_ID: "buyer_1",
            Fields.SELLER_ID: "seller_1",
            Fields.MESSAGE_COUNT: 2,
            Fields.LAST_MESSAGE_TEXT: None,
            Fields.FIRST_BUYER_MESSAGE_AT: first_buyer_msg_at,
            Fields.FIRST_SELLER_REPLY_AT: None,
        }
        seller_doc = Mock()
        seller_doc.to_dict.return_value = {Fields.NAME: "Seller"}

        msg_ref = Mock()
        msg_ref.id = "msg_seller_1"
        chat_ref = Mock()
        chat_ref.get.return_value = chat_doc
        chat_ref.collection.return_value.document.return_value = msg_ref

        def _collection(name):
            c = Mock()
            if name == Collections.CHATS:
                c.document.return_value = chat_ref
            elif name == Collections.USERS:
                c.document.return_value.get.return_value = seller_doc
            return c

        db.collection.side_effect = _collection

        req = _chat_req(uid="seller_1", data={Fields.CHAT_ID: "prod_1_buyer_1", Fields.MESSAGE_TEXT: "Thanks!"})
        out = send_message(req)
        assert out["success"] is True
        update_payload = chat_ref.update.call_args.args[0]
        assert Fields.FIRST_SELLER_REPLY_AT in update_payload
        assert Fields.FIRST_REPLY_HOURS in update_payload
        assert update_payload[Fields.FIRST_REPLY_HOURS] >= 0
        mock_push.assert_called_once()


class TestDeleteMessageMoreBranches:
    @patch("handlers.chat._get_db")
    def test_delete_message_not_found(self, mock_get_db):
        from handlers.chat import delete_message

        db = Mock()
        mock_get_db.return_value = db

        msg_ref = Mock()
        msg_ref.get.return_value = Mock(exists=False)
        db.collection.return_value.document.return_value.collection.return_value.document.return_value = msg_ref

        req = _chat_req(uid="u1", data={Fields.CHAT_ID: "chat_1", Fields.MESSAGE_ID: "msg_1"})
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_message(req)
        assert exc.value.code == "not-found"

    @patch("handlers.chat._get_db")
    @patch("handlers.chat.get_server_timestamp", return_value="ts")
    def test_delete_message_sender_success_path_updates_fields(self, _mock_ts, mock_get_db):
        from handlers.chat import delete_message

        db = Mock()
        mock_get_db.return_value = db

        msg_doc = Mock()
        msg_doc.exists = True
        msg_doc.to_dict.return_value = {Fields.SENDER_ID: "u1", Fields.DELETED: False}
        msg_ref = Mock()
        msg_ref.get.return_value = msg_doc

        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.ROLES: []}

        def _collection(name):
            c = Mock()
            if name == Collections.CHATS:
                c.document.return_value.collection.return_value.document.return_value = msg_ref
            elif name == Collections.USERS:
                c.document.return_value.get.return_value = user_doc
            return c

        db.collection.side_effect = _collection

        req = _chat_req(uid="u1", data={Fields.CHAT_ID: "chat_1", Fields.MESSAGE_ID: "msg_1"})
        out = delete_message(req)
        assert out["success"] is True
        msg_ref.update.assert_called_once()


class TestReportMessageMoreBranches:
    @patch("handlers.chat._get_db")
    def test_report_message_chat_not_found(self, mock_get_db):
        from handlers.chat import report_message

        db = Mock()
        mock_get_db.return_value = db
        chat_doc = Mock()
        chat_doc.exists = False
        db.collection.return_value.document.return_value.get.return_value = chat_doc

        req = _chat_req(uid="u1", data={Fields.CHAT_ID: "chat_1", Fields.MESSAGE_ID: "msg_1"})
        with pytest.raises(https_fn.HttpsError) as exc:
            report_message(req)
        assert exc.value.code == "not-found"

    @patch("handlers.chat._get_db")
    def test_report_message_message_not_found(self, mock_get_db):
        from handlers.chat import report_message

        db = Mock()
        mock_get_db.return_value = db

        chat_doc = Mock()
        chat_doc.exists = True
        chat_doc.to_dict.return_value = {Fields.BUYER_ID: "u1", Fields.SELLER_ID: "u2"}
        msg_doc = Mock()
        msg_doc.exists = False

        chat_ref = Mock()
        chat_ref.get.return_value = chat_doc
        chat_ref.collection.return_value.document.return_value.get.return_value = msg_doc
        db.collection.return_value.document.return_value = chat_ref

        req = _chat_req(uid="u1", data={Fields.CHAT_ID: "chat_1", Fields.MESSAGE_ID: "msg_1"})
        with pytest.raises(https_fn.HttpsError) as exc:
            report_message(req)
        assert exc.value.code == "not-found"
