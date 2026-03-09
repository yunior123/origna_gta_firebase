from datetime import UTC, datetime
from unittest.mock import Mock, patch

import pytest

from models.product import Product
from schema_constants import Fields, ProductLifecycleStatusValues


def _client_cm(client: Mock) -> Mock:
    cm = Mock()
    cm.__enter__ = Mock(return_value=client)
    cm.__exit__ = Mock(return_value=None)
    return cm


class TestAlgoliaFormatting:
    @patch("services.algolia_service._log_sync_failure")
    def test_format_product_for_algolia_invalid_data_returns_empty(self, mock_log_failure):
        from services.algolia_service import format_product_for_algolia

        out = format_product_for_algolia("prod_bad", {})
        assert out == {}
        assert mock_log_failure.called

    def test_format_product_for_algolia_valid_data_maps_expected_fields(self):
        from services.algolia_service import format_product_for_algolia

        product = {
            Fields.NAME: "Premium Keyboard",
            Fields.DESCRIPTION: "Mechanical keyboard for coding and gaming",
            Fields.PRICE: 99.99,
            Fields.CATEGORY_ID: 2,
            Fields.SELLER_ID: "seller_1",
            Fields.IMAGE_URLS: ["https://cdn.example.com/kb.jpg"],
            Fields.STOCK_QUANTITY: 8,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.KEYWORDS: ["keyboard", "mechanical"],
            Fields.IS_LOCAL_DELIVERY_ONLY: True,
            Fields.SELLER_ADDRESS: {
                Fields.STREET: "1 Queen St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5H 2N2",
                Fields.COUNTRY: "Canada",
            },
            Fields.CREATED_AT: datetime.now(UTC),
        }

        out = format_product_for_algolia("prod_1", product)

        assert out["objectID"] == "prod_1"
        assert out[Fields.PRICE_CENTS] == 9999
        assert out["availableInCanada"] is True
        assert out[Fields.NAME] == "Premium Keyboard"


class TestAlgoliaSyncOps:
    @patch("services.algolia_service.delete_product")
    def test_index_product_skips_delete_when_never_active(self, mock_delete):
        from services.algolia_service import index_product

        ok = index_product("prod_1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.DRAFT})
        assert ok is True
        mock_delete.assert_not_called()

    @patch("services.algolia_service.delete_product")
    def test_index_product_deletes_when_previously_active(self, mock_delete):
        from services.algolia_service import index_product

        ok = index_product(
            "prod_1",
            {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                "_previousLifecycleStatus": ProductLifecycleStatusValues.ACTIVE,
            },
        )
        assert ok is True
        mock_delete.assert_called_once_with("prod_1")

    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service.format_product_for_algolia", return_value={"objectID": "prod_1"})
    @patch("services.algolia_service._get_algolia_client")
    def test_index_product_success(self, mock_get_client, _mock_format, _mock_index_name):
        from services.algolia_service import index_product

        client = Mock()
        mock_get_client.return_value = _client_cm(client)

        ok = index_product("prod_1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE})
        assert ok is True
        client.save_object.assert_called_once()

    @patch("services.algolia_service.format_product_for_algolia", return_value={"objectID": "prod_1"})
    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_index_product_runtime_error_returns_false(self, _mock_client, _mock_format):
        from services.algolia_service import index_product

        ok = index_product("prod_1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE})
        assert ok is False

    @patch("services.algolia_service._log_sync_failure")
    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service.format_product_for_algolia", return_value={"objectID": "prod_1"})
    @patch("services.algolia_service._get_algolia_client")
    def test_index_product_logs_failure_after_retries(self, mock_get_client, _mock_format, _mock_index_name, mock_log_failure):
        from services.algolia_service import index_product

        client = Mock()
        client.save_object.side_effect = Exception("algolia down")
        mock_get_client.return_value = _client_cm(client)

        ok = index_product("prod_1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, max_retries=2)
        assert ok is False
        mock_log_failure.assert_called_once()

    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service._get_algolia_client")
    def test_partial_update_product_success(self, mock_get_client, _mock_index_name):
        from services.algolia_service import partial_update_product

        client = Mock()
        mock_get_client.return_value = _client_cm(client)

        ok = partial_update_product("prod_1", {Fields.STOCK_QUANTITY: 4})
        assert ok is True
        client.partial_update_object.assert_called_once()

    def test_batch_partial_update_products_empty_is_noop(self):
        from services.algolia_service import batch_partial_update_products

        assert batch_partial_update_products([], {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}) is True

    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_batch_partial_update_products_runtime_error_returns_false(self, _mock_client):
        from services.algolia_service import batch_partial_update_products

        ok = batch_partial_update_products(["p1"], {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED})
        assert ok is False

    @patch("services.algolia_service._log_sync_failure")
    @patch("services.algolia_service._get_algolia_client")
    def test_delete_product_logs_failure_after_retries(self, mock_get_client, mock_log_failure):
        from services.algolia_service import delete_product

        client = Mock()
        client.delete_object.side_effect = Exception("delete failed")
        mock_get_client.return_value = _client_cm(client)

        ok = delete_product("prod_1", max_retries=2)
        assert ok is False
        mock_log_failure.assert_called_once()

    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service._get_algolia_client")
    def test_get_index_stats_returns_hits(self, mock_get_client, _mock_index_name):
        from services.algolia_service import get_index_stats

        client = Mock()
        client.search_single_index.return_value = Mock(nb_hits=42)
        mock_get_client.return_value = _client_cm(client)

        assert get_index_stats() == 42

    @patch("services.algolia_service.format_product_for_algolia", side_effect=lambda pid, data: {"objectID": pid})
    @patch("services.algolia_service._get_algolia_client")
    def test_batch_index_products_indexes_only_active_products(self, mock_get_client, _mock_format):
        from services.algolia_service import batch_index_products

        client = Mock()
        mock_get_client.return_value = _client_cm(client)
        products = [
            ("p1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}),
            ("p2", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.DRAFT}),
        ]

        success, failure = batch_index_products(products)
        assert success == 1
        assert failure == 0
        client.save_objects.assert_called_once()

    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_configure_algolia_index_runtime_error_returns_false(self, _mock_client):
        from services.algolia_service import configure_algolia_index

        assert configure_algolia_index() is False

    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service._get_algolia_client")
    def test_configure_algolia_index_success(self, mock_get_client, _mock_index_name):
        from services.algolia_service import configure_algolia_index

        client = Mock()
        mock_get_client.return_value = _client_cm(client)
        assert configure_algolia_index() is True
        client.set_settings.assert_called_once()

    @patch("services.algolia_service._log_sync_failure")
    @patch("services.algolia_service._get_algolia_client")
    def test_delete_products_from_algolia_logs_each_failure(self, mock_get_client, mock_log_failure):
        from services.algolia_service import delete_products_from_algolia

        client = Mock()
        client.delete_objects.side_effect = Exception("boom")
        mock_get_client.return_value = _client_cm(client)

        deleted = delete_products_from_algolia(["p1", "p2"])
        assert deleted == 0
        assert mock_log_failure.call_count == 2


class TestAlgoliaDeepBranches:
    def test_get_algolia_client_raises_when_credentials_missing(self):
        from services.algolia_service import _get_algolia_client

        with patch("services.algolia_service.get_algolia_app_id", return_value=""), patch(
            "services.algolia_service.get_algolia_write_api_key", return_value="key"
        ):
            with pytest.raises(RuntimeError, match="credentials not configured"):
                _get_algolia_client()

    def test_get_algolia_client_builds_search_client_when_credentials_present(self):
        from services.algolia_service import _get_algolia_client

        sentinel_client = Mock()
        with patch("services.algolia_service.get_algolia_app_id", return_value="app"), patch(
            "services.algolia_service.get_algolia_write_api_key", return_value="key"
        ), patch("services.algolia_service.SearchClientSync", return_value=sentinel_client) as mock_ctor:
            out = _get_algolia_client()

        assert out is sentinel_client
        mock_ctor.assert_called_once_with("app", "key")

    def test_format_product_for_algolia_product_model_path_and_optional_shipping_fields(self):
        from services.algolia_service import format_product_for_algolia

        product = Product(
            name="Valid Product Name",
            price=10.0,
            description="A valid description for this product.",
            imageUrls=["https://example.com/a.jpg"],
            sellerId="seller_1",
            sellerAddress={
                Fields.STREET: "123 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2H1",
                Fields.COUNTRY: "Canada",
            },
            categoryId=1,
            stockQuantity=5,
        )

        seller_addr_obj = Mock()
        seller_addr_obj.model_dump.return_value = {Fields.COUNTRY: "CA", Fields.CITY: "Toronto"}
        created_at_obj = Mock()
        created_at_obj.timestamp.return_value = 1234567890
        model_data = {
            Fields.NAME: "Mapped Name",
            Fields.DESCRIPTION: "Mapped Desc",
            Fields.PRICE: 12.34,
            Fields.CATEGORY_ID: 1,
            Fields.SELLER_ID: "seller_1",
            Fields.IMAGE_URLS: [],
            Fields.STOCK_QUANTITY: 3,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_LOCAL_DELIVERY_ONLY: True,
            Fields.SELLER_ADDRESS: seller_addr_obj,
            Fields.SHIP_FROM_CITY: "Toronto",
            Fields.SHIP_FROM_PROVINCE: "ON",
            Fields.SHIP_FROM_COUNTRY: "CA",
            Fields.SHIP_FROM_COUNTRIES: ["CA", "US"],
            Fields.CREATED_AT: created_at_obj,
        }

        with patch.object(Product, "model_dump", return_value=model_data):
            out = format_product_for_algolia("prod_model", product)

        assert out["objectID"] == "prod_model"
        assert out[Fields.PRICE_CENTS] == 1234
        assert out["availableInCanada"] is True
        assert out[Fields.SELLER_ADDRESS][Fields.COUNTRY] == "CA"
        assert out[Fields.SHIP_FROM_CITY] == "Toronto"
        assert out[Fields.SHIP_FROM_COUNTRIES] == ["CA", "US"]
        assert out[Fields.CREATED_AT] == 1234567890

    @patch("services.algolia_service.logger")
    def test_log_sync_failure_writes_dead_letter_queue(self, mock_logger):
        from services.algolia_service import _log_sync_failure

        db = Mock()
        collection_ref = Mock()
        db.collection.return_value = collection_ref

        with patch("firebase_admin.firestore.client", return_value=db), patch(
            "firebase_admin.firestore.SERVER_TIMESTAMP", "server-ts"
        ):
            _log_sync_failure("prod_1", "index", "boom", 2)

        db.collection.assert_called_once()
        collection_ref.add.assert_called_once()
        mock_logger.info.assert_called_once()

    @patch("services.algolia_service.logger")
    def test_log_sync_failure_handles_dlq_write_errors(self, mock_logger):
        from services.algolia_service import _log_sync_failure

        with patch("firebase_admin.firestore.client", side_effect=Exception("firestore down")):
            _log_sync_failure("prod_1", "index", "boom", 1)

        assert mock_logger.error.called

    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_partial_update_product_runtime_error_returns_false(self, _mock_client):
        from services.algolia_service import partial_update_product

        ok = partial_update_product("prod_1", {Fields.STOCK_QUANTITY: 3})
        assert ok is False

    @patch("services.algolia_service._log_sync_failure")
    @patch("services.algolia_service._get_algolia_client")
    def test_partial_update_product_logs_after_retry_exhaustion(self, mock_get_client, mock_log_failure):
        from services.algolia_service import partial_update_product

        client = Mock()
        client.partial_update_object.side_effect = Exception("update failed")
        mock_get_client.return_value = _client_cm(client)

        ok = partial_update_product("prod_1", {Fields.STOCK_QUANTITY: 3}, max_retries=2)
        assert ok is False
        mock_log_failure.assert_called_once()

    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service._get_algolia_client")
    def test_batch_partial_update_products_success(self, mock_get_client, _mock_index_name):
        from services.algolia_service import batch_partial_update_products

        client = Mock()
        mock_get_client.return_value = _client_cm(client)

        with patch("algoliasearch.search.models.action.Action") as mock_action, patch(
            "algoliasearch.search.models.batch_request.BatchRequest",
            side_effect=lambda action, body: {"action": action, "body": body},
        ), patch(
            "algoliasearch.search.models.batch_write_params.BatchWriteParams",
            side_effect=lambda requests: {"requests": requests},
        ):
            mock_action.PARTIAL_UPDATE_OBJECT = "partialUpdateObject"
            ok = batch_partial_update_products(
                ["p1", "p2"], {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}
            )
        assert ok is True
        client.batch.assert_called_once()

    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_batch_partial_update_products_runtime_error_branch(self, _mock_client):
        from services.algolia_service import batch_partial_update_products

        with patch("algoliasearch.search.models.action.Action") as mock_action, patch(
            "algoliasearch.search.models.batch_request.BatchRequest",
            side_effect=lambda action, body: {"action": action, "body": body},
        ), patch(
            "algoliasearch.search.models.batch_write_params.BatchWriteParams",
            side_effect=lambda requests: {"requests": requests},
        ):
            mock_action.PARTIAL_UPDATE_OBJECT = "partialUpdateObject"
            ok = batch_partial_update_products(
                ["p1"], {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}
            )
        assert ok is False

    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service._get_algolia_client")
    def test_delete_product_success(self, mock_get_client, _mock_index_name):
        from services.algolia_service import delete_product

        client = Mock()
        mock_get_client.return_value = _client_cm(client)
        assert delete_product("p1") is True
        client.delete_object.assert_called_once()

    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_delete_product_runtime_error_returns_false(self, _mock_client):
        from services.algolia_service import delete_product

        assert delete_product("p1") is False

    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_get_index_stats_runtime_error_returns_zero(self, _mock_client):
        from services.algolia_service import get_index_stats

        assert get_index_stats() == 0

    @patch("services.algolia_service._get_algolia_client")
    def test_get_index_stats_non_runtime_exception_returns_zero(self, mock_get_client):
        from services.algolia_service import get_index_stats

        client = Mock()
        client.search_single_index.side_effect = Exception("network")
        mock_get_client.return_value = _client_cm(client)
        assert get_index_stats() == 0

    def test_batch_index_products_returns_zero_when_no_active_products(self):
        from services.algolia_service import batch_index_products

        out = batch_index_products([("p1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.DRAFT})])
        assert out == (0, 0)

    @patch("services.algolia_service.format_product_for_algolia", return_value={"objectID": "p1"})
    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_batch_index_products_runtime_error_counts_all_inputs_as_failed(self, _mock_client, _mock_format):
        from services.algolia_service import batch_index_products

        products = [("p1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE})]
        assert batch_index_products(products) == (0, 1)

    @patch("services.algolia_service._log_sync_failure")
    @patch("services.algolia_service.format_product_for_algolia", side_effect=lambda pid, _data: {"objectID": pid})
    @patch("services.algolia_service._get_algolia_client")
    def test_batch_index_products_exception_logs_each_active_id(self, mock_get_client, _mock_format, mock_log_failure):
        from services.algolia_service import batch_index_products

        client = Mock()
        client.save_objects.side_effect = Exception("algolia down")
        mock_get_client.return_value = _client_cm(client)
        products = [
            ("p1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}),
            ("p2", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}),
        ]

        success, failure = batch_index_products(products)
        assert success == 0
        assert failure == 2
        assert mock_log_failure.call_count == 2

    @patch("services.algolia_service._get_algolia_client", side_effect=Exception("unexpected"))
    def test_configure_algolia_index_unexpected_error_returns_false(self, _mock_client):
        from services.algolia_service import configure_algolia_index

        assert configure_algolia_index() is False

    def test_delete_products_from_algolia_empty_input_returns_zero(self):
        from services.algolia_service import delete_products_from_algolia

        assert delete_products_from_algolia([]) == 0

    @patch("services.algolia_service._get_index_name", return_value="products_test")
    @patch("services.algolia_service._get_algolia_client")
    def test_delete_products_from_algolia_success_returns_count(self, mock_get_client, _mock_index_name):
        from services.algolia_service import delete_products_from_algolia

        client = Mock()
        mock_get_client.return_value = _client_cm(client)
        assert delete_products_from_algolia(["p1", "p2"]) == 2
        client.delete_objects.assert_called_once()

    @patch("services.algolia_service._get_algolia_client", side_effect=RuntimeError("no creds"))
    def test_delete_products_from_algolia_runtime_error_returns_zero(self, _mock_client):
        from services.algolia_service import delete_products_from_algolia

        assert delete_products_from_algolia(["p1"]) == 0
