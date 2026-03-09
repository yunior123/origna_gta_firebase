from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import MagicMock, Mock, patch

from schema_constants import Collections, Fields


class TestPushServiceDeep:
    def test_send_push_notifications_batch_empty_users_returns_zero(self):
        from services.push_service import send_push_notifications_batch

        assert send_push_notifications_batch([], "Title", "Body") == 0

    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notifications_batch_sends_and_cleans_stale_tokens(self, mock_send, mock_get_db):
        from services.push_service import send_push_notifications_batch

        db = Mock()
        mock_get_db.return_value = db

        # collection_group token query
        token_query = Mock()
        token_query.where.return_value = token_query
        stale_ref = Mock()
        valid_ref = Mock()
        token_docs = [
            Mock(to_dict=Mock(return_value={Fields.USER_ID: "u1", "token": "tok_valid"}), reference=valid_ref),
            Mock(to_dict=Mock(return_value={Fields.USER_ID: "u1", "token": "tok_stale"}), reference=stale_ref),
        ]
        token_query.stream.return_value = token_docs
        db.collection_group.return_value = token_query

        users_ref = Mock()
        users_ref.document.side_effect = lambda uid: Mock(id=uid)
        db.collection.return_value = users_ref

        user_doc = Mock()
        user_doc.exists = True
        user_doc.id = "u1"
        user_doc.to_dict.return_value = {Fields.PUSH_ENABLED: True, "dailyPushStats": {"lastDate": "2000-01-01", "count": 1}}
        user_doc.reference = Mock()
        db.get_all.return_value = [user_doc]

        resp_ok = SimpleNamespace(success=True, exception=None)
        resp_stale = SimpleNamespace(success=False, exception=Exception("invalid-registration-token"))
        batch_response = SimpleNamespace(success_count=1, responses=[resp_ok, resp_stale])
        mock_send.return_value = batch_response

        sent = send_push_notifications_batch(["u1", "u1"], "Hello", "World", data={"type": "alert"})

        assert sent == 1
        mock_send.assert_called_once()
        stale_ref.delete.assert_called_once()
        user_doc.reference.update.assert_called_once()

    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notifications_batch_skips_users_over_daily_limit(self, mock_send, mock_get_db):
        from services.push_service import send_push_notifications_batch

        db = Mock()
        mock_get_db.return_value = db

        token_query = Mock()
        token_query.where.return_value = token_query
        token_query.stream.return_value = [Mock(to_dict=Mock(return_value={Fields.USER_ID: "u1", "token": "tok_1"}), reference=Mock())]
        db.collection_group.return_value = token_query

        users_ref = Mock()
        users_ref.document.side_effect = lambda uid: Mock(id=uid)
        db.collection.return_value = users_ref

        today = datetime.now(UTC).strftime("%Y-%m-%d")
        user_doc = Mock()
        user_doc.exists = True
        user_doc.id = "u1"
        user_doc.to_dict.return_value = {Fields.PUSH_ENABLED: True, "dailyPushStats": {"lastDate": today, "count": 20}}
        user_doc.reference = Mock()
        db.get_all.return_value = [user_doc]

        sent = send_push_notifications_batch(["u1"], "Hello", "World")

        assert sent == 0
        mock_send.assert_not_called()
        user_doc.reference.update.assert_not_called()

    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notification_deduplicates_duplicate_tokens(self, mock_send, mock_get_db):
        from services.push_service import send_push_notification

        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.PUSH_ENABLED: True}
        user_ref.get.return_value = user_doc

        tok_ref1 = Mock()
        tok_ref2 = Mock()
        token_doc_1 = Mock(to_dict=Mock(return_value={"token": "dup_tok"}), reference=tok_ref1)
        token_doc_2 = Mock(to_dict=Mock(return_value={"token": "dup_tok"}), reference=tok_ref2)
        user_ref.collection.return_value.stream.return_value = [token_doc_1, token_doc_2]

        db.collection.return_value.document.return_value = user_ref

        mock_send.return_value = SimpleNamespace(
            success_count=1,
            responses=[SimpleNamespace(success=True, exception=None)],
        )

        ok = send_push_notification("u1", "Title", "Body")
        assert ok is True
        sent_message = mock_send.call_args.args[0]
        assert sent_message.tokens == ["dup_tok"]

    @patch("services.push_service._get_db")
    def test_send_push_notification_returns_false_for_missing_user_or_tokens(self, mock_get_db):
        from services.push_service import send_push_notification

        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        missing_user = Mock()
        missing_user.exists = False
        user_ref.get.return_value = missing_user
        db.collection.return_value.document.return_value = user_ref

        assert send_push_notification("u_missing", "Title", "Body") is False

        present_user = Mock()
        present_user.exists = True
        present_user.to_dict.return_value = {Fields.PUSH_ENABLED: True}
        user_ref.get.return_value = present_user
        user_ref.collection.return_value.stream.return_value = []
        assert send_push_notification("u_missing", "Title", "Body") is False

    @patch("firebase_admin.firestore.client")
    def test_get_db_lazy_initializes_and_caches_client(self, mock_client):
        import services.push_service as push_service

        push_service._db = None
        mock_client.return_value = Mock()

        d1 = push_service._get_db()
        d2 = push_service._get_db()

        assert d1 is d2
        mock_client.assert_called_once()


class TestPushServiceExtraBranches:
    def test_send_push_notification_import_error_returns_false(self):
        from services.push_service import send_push_notification

        real_import = __import__

        def _fake_import(name, globals=None, locals=None, fromlist=(), level=0):
            if name == "firebase_admin" and "messaging" in (fromlist or ()):
                raise ImportError("messaging unavailable")
            return real_import(name, globals, locals, fromlist, level)

        with patch("builtins.__import__", side_effect=_fake_import):
            assert send_push_notification("u1", "Title", "Body") is False

    @patch("services.push_service.logger")
    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notification_stale_token_delete_error_is_logged(self, mock_send, mock_get_db, mock_logger):
        from services.push_service import send_push_notification

        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.PUSH_ENABLED: True}
        user_ref.get.return_value = user_doc

        stale_ref = Mock()
        stale_ref.delete.side_effect = Exception("cannot delete")
        token_doc = Mock(to_dict=Mock(return_value={"token": "tok_bad"}), reference=stale_ref)
        user_ref.collection.return_value.stream.return_value = [token_doc]
        db.collection.return_value.document.return_value = user_ref

        bad_resp = SimpleNamespace(success=False, exception=Exception("invalid-registration-token"))
        mock_send.return_value = SimpleNamespace(success_count=0, responses=[bad_resp])

        ok = send_push_notification("u1", "Title", "Body")
        assert ok is False
        assert mock_logger.warning.called

    @patch("services.push_service._get_db")
    def test_send_push_notification_respects_push_opt_out(self, mock_get_db):
        from services.push_service import send_push_notification

        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.PUSH_ENABLED: False}
        user_ref.get.return_value = user_doc
        db.collection.return_value.document.return_value = user_ref

        assert send_push_notification("u1", "Title", "Body") is False

    @patch("services.push_service.logger")
    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notification_removes_stale_token_and_logs_info(self, mock_send, mock_get_db, mock_logger):
        from services.push_service import send_push_notification

        db = Mock()
        mock_get_db.return_value = db

        user_ref = Mock()
        user_doc = Mock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {Fields.PUSH_ENABLED: True}
        user_ref.get.return_value = user_doc

        stale_ref = Mock()
        token_doc = Mock(to_dict=Mock(return_value={"token": "tok_bad"}), reference=stale_ref)
        user_ref.collection.return_value.stream.return_value = [token_doc]
        db.collection.return_value.document.return_value = user_ref

        bad_resp = SimpleNamespace(success=False, exception=Exception("registration-token-not-registered"))
        mock_send.return_value = SimpleNamespace(success_count=0, responses=[bad_resp])

        assert send_push_notification("u1", "Title", "Body") is False
        stale_ref.delete.assert_called_once()
        assert mock_logger.info.called

    @patch("services.push_service._get_db", side_effect=Exception("firestore down"))
    def test_send_push_notification_handles_unexpected_exceptions(self, _mock_get_db):
        from services.push_service import send_push_notification

        assert send_push_notification("u1", "Title", "Body") is False

    def test_send_push_notifications_batch_import_error_returns_zero(self):
        from services.push_service import send_push_notifications_batch

        real_import = __import__

        def _fake_import(name, globals=None, locals=None, fromlist=(), level=0):
            if name == "firebase_admin" and "messaging" in (fromlist or ()):
                raise ImportError("messaging unavailable")
            return real_import(name, globals, locals, fromlist, level)

        with patch("builtins.__import__", side_effect=_fake_import):
            assert send_push_notifications_batch(["u1"], "Title", "Body") == 0

    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notifications_batch_skips_when_token_docs_missing_user_or_token(self, mock_send, mock_get_db):
        from services.push_service import send_push_notifications_batch

        db = Mock()
        mock_get_db.return_value = db

        token_query = Mock()
        token_query.where.return_value = token_query
        token_query.stream.return_value = [Mock(to_dict=Mock(return_value={}), reference=Mock())]
        db.collection_group.return_value = token_query

        sent = send_push_notifications_batch(["u1"], "Title", "Body")
        assert sent == 0
        mock_send.assert_not_called()

    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notifications_batch_skips_missing_and_push_disabled_users(self, mock_send, mock_get_db):
        from services.push_service import send_push_notifications_batch

        db = Mock()
        mock_get_db.return_value = db

        token_query = Mock()
        token_query.where.return_value = token_query
        token_query.stream.return_value = [
            Mock(to_dict=Mock(return_value={Fields.USER_ID: "u_missing", "token": "tok_1"}), reference=Mock()),
            Mock(to_dict=Mock(return_value={Fields.USER_ID: "u_disabled", "token": "tok_2"}), reference=Mock()),
        ]
        db.collection_group.return_value = token_query

        users_ref = Mock()
        users_ref.document.side_effect = lambda uid: Mock(id=uid)
        db.collection.return_value = users_ref

        missing_doc = Mock()
        missing_doc.exists = False
        disabled_doc = Mock()
        disabled_doc.exists = True
        disabled_doc.id = "u_disabled"
        disabled_doc.to_dict.return_value = {Fields.PUSH_ENABLED: False}
        db.get_all.return_value = [missing_doc, disabled_doc]

        sent = send_push_notifications_batch(["u_missing", "u_disabled"], "Hello", "World")
        assert sent == 0
        mock_send.assert_not_called()

    @patch("services.push_service._get_db")
    @patch("firebase_admin.messaging.send_each_for_multicast")
    def test_send_push_notifications_batch_ignores_stale_token_delete_errors(self, mock_send, mock_get_db):
        from services.push_service import send_push_notifications_batch

        db = Mock()
        mock_get_db.return_value = db

        bad_ref = Mock()
        bad_ref.delete.side_effect = Exception("no delete")
        token_query = Mock()
        token_query.where.return_value = token_query
        token_query.stream.return_value = [
            Mock(to_dict=Mock(return_value={Fields.USER_ID: "u1", "token": "tok_stale"}), reference=bad_ref),
        ]
        db.collection_group.return_value = token_query

        users_ref = Mock()
        users_ref.document.side_effect = lambda uid: Mock(id=uid)
        db.collection.return_value = users_ref

        user_doc = Mock()
        user_doc.exists = True
        user_doc.id = "u1"
        user_doc.to_dict.return_value = {Fields.PUSH_ENABLED: True, "dailyPushStats": {"lastDate": "2000-01-01", "count": 0}}
        user_doc.reference = Mock()
        db.get_all.return_value = [user_doc]

        resp_stale = SimpleNamespace(success=False, exception=Exception("registration-token-not-registered"))
        mock_send.return_value = SimpleNamespace(success_count=0, responses=[resp_stale])

        sent = send_push_notifications_batch(["u1"], "Hello", "World")
        assert sent == 0
        user_doc.reference.update.assert_called_once()
