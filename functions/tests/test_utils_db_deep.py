from types import SimpleNamespace
from unittest.mock import Mock, patch

from utils import db as db_utils


class TestUtilsDbDeep:
    def setup_method(self):
        db_utils._db = None
        db_utils._firestore = None

    def teardown_method(self):
        db_utils._db = None
        db_utils._firestore = None

    @patch("firebase_admin.firestore")
    def test_get_db_lazy_initializes_and_caches_client(self, mock_fs):
        fake_client = Mock()
        mock_fs.client.return_value = fake_client

        c1 = db_utils.get_db()
        c2 = db_utils.get_db()

        assert c1 is fake_client
        assert c2 is fake_client
        mock_fs.client.assert_called_once()
        assert db_utils._firestore is mock_fs

    @patch("firebase_admin.firestore")
    def test_get_firestore_lazy_initializes_when_cache_empty(self, mock_fs):
        fs1 = db_utils.get_firestore()
        fs2 = db_utils.get_firestore()

        assert fs1 is mock_fs
        assert fs2 is mock_fs

    def test_server_timestamp_and_delete_field_forwarders(self):
        fake_fs = SimpleNamespace(SERVER_TIMESTAMP="SERVER_TS", DELETE_FIELD="DELETE_FIELD")
        db_utils._firestore = fake_fs

        assert db_utils.get_server_timestamp() == "SERVER_TS"
        assert db_utils.get_delete_field() == "DELETE_FIELD"
