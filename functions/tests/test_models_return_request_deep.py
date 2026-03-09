import pytest

from models.return_request import ReturnRequest
from schema_constants import ReturnStatusValues


def _base_return_request() -> dict:
    return {
        "returnId": "ret_1",
        "orderId": "ord_1",
        "orderItemId": "item_1",
        "buyerId": "buyer_1",
        "sellerId": "seller_1",
        "productId": "prod_1",
        "productName": "Keyboard",
        "returnReason": "Item arrived damaged in transit.",
    }


class TestReturnRequestDeep:
    def test_return_request_valid_defaults(self):
        request = ReturnRequest(**_base_return_request())

        assert request.quantity == 1
        assert request.returnStatus == ReturnStatusValues.REQUESTED
        assert request.requestedAt is not None
        assert request.updatedAt is not None

    def test_return_request_accepts_explicit_valid_status(self):
        valid_status = next(iter(ReturnStatusValues.ALL))
        request = ReturnRequest(**{**_base_return_request(), "returnStatus": valid_status})
        assert request.returnStatus == valid_status

    def test_return_request_rejects_invalid_status(self):
        with pytest.raises(ValueError, match="Invalid return status"):
            ReturnRequest(**{**_base_return_request(), "returnStatus": "not_a_status"})
