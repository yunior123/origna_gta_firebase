"""OrderEvent model — tracks every status transition. Stored at orders/{orderId}/events/{eventId}."""

from datetime import UTC, datetime

from pydantic import BaseModel, Field


class OrderEvent(BaseModel):
    """Class OrderEvent."""
    eventType: str = Field(..., description="One of OrderEventTypes.*")
    fromStatus: str | None = Field(default=None)
    toStatus: str | None = Field(default=None)
    actor: str = Field(..., description="UID or 'system' or 'stripe_webhook'")
    actorType: str = Field(..., description="'seller'|'buyer'|'admin'|'system'")
    metadata: dict = Field(default_factory=dict)
    createdAt: datetime = Field(default_factory=lambda: datetime.now(UTC))

    @staticmethod
    def write(db_or_batch, order_id: str, event_type: str, actor: str, actor_type: str,
              from_status: str | None = None, to_status: str | None = None, metadata: dict | None = None) -> None:
        """Function write."""
        from firebase_admin import firestore as fs
        from schema_constants import Collections

        db = db_or_batch if hasattr(db_or_batch, 'collection') else fs.client()
        event_ref = db.collection(Collections.ORDERS).document(order_id).collection(Collections.ORDER_EVENTS).document()
        event = OrderEvent(
            eventType=event_type, fromStatus=from_status, toStatus=to_status,
            actor=actor, actorType=actor_type, metadata=metadata or {},
        )
        if hasattr(db_or_batch, 'set'):
            db_or_batch.set(event_ref, event.model_dump())
        else:
            event_ref.set(event.model_dump())
