import pytest

from models.order import Order, OrderItem, Ratings
from schema_constants import Fields


def _base_order_item(**overrides):
    data = {
        Fields.PRODUCT_ID: "prod_1",
        Fields.NAME: "Valid Item Name",
        Fields.PRICE: 10.0,
        Fields.QUANTITY: 1,
        Fields.IMAGE_URLS: ["https://example.com/a.jpg"],
        Fields.SELLER_ID: "seller_1",
    }
    data.update(overrides)
    return data


def _base_order(**overrides):
    data = {
        Fields.ORDER_ID: "order_1",
        Fields.USER_ID: "user_1",
        Fields.ITEMS: [_base_order_item()],
        Fields.SUBTOTAL_CENTS: 1000,
        Fields.TOTAL_AMOUNT_CENTS: 1000,
    }
    data.update(overrides)
    return data


class TestOrderModelDeepMore:
    def test_order_item_validators_reject_invalid_status_carrier_name_and_image_urls(self):
        with pytest.raises(ValueError, match="Invalid status"):
            OrderItem(**_base_order_item(status="unknown"))

        with pytest.raises(ValueError, match="carrier must be one of"):
            OrderItem(**_base_order_item(carrier="carrier_x"))

        with pytest.raises(ValueError, match="disallowed characters"):
            OrderItem(**_base_order_item(name="Bad<name>"))

        with pytest.raises(ValueError, match="Invalid image URL"):
            OrderItem(**_base_order_item(imageUrls=["ftp://bad"]))

    def test_ratings_review_rejects_html(self):
        with pytest.raises(ValueError, match="disallowed characters"):
            Ratings(productId="prod_1", rating=4.0, review="<script>alert(1)</script>")

    def test_order_validators_reject_invalid_currency_and_payout_status(self):
        with pytest.raises(ValueError, match="Only"):
            Order(**_base_order(currency="zzz"))

        with pytest.raises(ValueError, match="Invalid payout status"):
            Order(**_base_order(payoutStatus="bad_status"))

    def test_order_and_item_validators_accept_valid_explicit_values(self):
        item = OrderItem(
            **_base_order_item(
                status="pending",  # cover valid status return branch
                carrier="other",   # cover valid carrier return branch
            )
        )
        assert item.status == "pending"
        assert item.carrier == "other"

        rating = Ratings(productId="prod_1", rating=5.0, review="Great product")
        assert rating.review == "Great product"

        order = Order(**_base_order(currency="cad", payoutStatus="pending"))
        assert order.currency == "cad"
        assert order.payoutStatus == "pending"
