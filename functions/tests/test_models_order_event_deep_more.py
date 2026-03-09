from unittest.mock import Mock

from models.order_event import OrderEvent
from schema_constants import Collections


class _DbNoBatch:
    """Minimal db-like object with collection(), but no set() method."""

    def __init__(self, event_ref):
        self._event_ref = event_ref

    def collection(self, _name):
        orders_coll = Mock()
        order_doc_ref = Mock()
        events_coll = Mock()
        orders_coll.document.return_value = order_doc_ref
        order_doc_ref.collection.return_value = events_coll
        events_coll.document.return_value = self._event_ref
        return orders_coll


class TestOrderEventDeepMore:
    def test_order_event_write_uses_batch_set_when_batch_like_object_passed(self):
        event_ref = Mock()
        batch_like = Mock()
        orders_coll = Mock()
        order_doc_ref = Mock()
        events_coll = Mock()
        orders_coll.document.return_value = order_doc_ref
        order_doc_ref.collection.return_value = events_coll
        events_coll.document.return_value = event_ref
        batch_like.collection.return_value = orders_coll

        OrderEvent.write(
            batch_like,
            order_id="order_1",
            event_type="status_changed",
            actor="system",
            actor_type="system",
        )

        batch_like.set.assert_called_once()

    def test_order_event_write_uses_event_ref_set_for_db_clients(self):
        event_ref = Mock()
        db_like = _DbNoBatch(event_ref)

        OrderEvent.write(
            db_like,
            order_id="order_1",
            event_type="status_changed",
            actor="system",
            actor_type="system",
            from_status="pending",
            to_status="confirmed",
            metadata={"source": "test"},
        )

        event_ref.set.assert_called_once()
