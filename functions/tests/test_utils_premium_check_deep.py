from unittest.mock import Mock, patch

from schema_constants import Fields, SubscriptionStatusValues


class TestPremiumCheckDeep:
    @patch("firebase_admin.firestore.client")
    def test_get_db_lazy_initialization_and_cache(self, mock_client):
        import utils.premium_check as premium_check

        premium_check._db = None
        sentinel_db = Mock()
        mock_client.return_value = sentinel_db

        db1 = premium_check._get_db()
        db2 = premium_check._get_db()

        assert db1 is sentinel_db
        assert db2 is sentinel_db
        mock_client.assert_called_once()

    @patch("utils.premium_check._get_db")
    def test_is_premium_authoritative_uses_default_db_when_not_provided(self, mock_get_db):
        from utils.premium_check import is_premium_authoritative

        db = Mock()
        mock_get_db.return_value = db
        snap = Mock()
        snap.exists = True
        snap.to_dict.return_value = {Fields.STATUS: next(iter(SubscriptionStatusValues.PREMIUM_ACTIVE))}
        db.collection.return_value.document.return_value.get.return_value = snap

        assert is_premium_authoritative("u1") is True
        mock_get_db.assert_called_once()

    def test_is_premium_authoritative_false_when_doc_missing_or_status_not_premium(self):
        from utils.premium_check import is_premium_authoritative

        db = Mock()
        missing = Mock()
        missing.exists = False
        db.collection.return_value.document.return_value.get.return_value = missing
        assert is_premium_authoritative("u1", db=db) is False

        inactive = Mock()
        inactive.exists = True
        inactive.to_dict.return_value = {Fields.STATUS: "canceled"}
        db.collection.return_value.document.return_value.get.return_value = inactive
        assert is_premium_authoritative("u1", db=db) is False
