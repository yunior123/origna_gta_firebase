## CHAT FINDINGS

### CRITICAL (must fix before launch)
1. Messages use `datetime.now(UTC)` NOT `firestore.SERVER_TIMESTAMP` — ordering guarantee broken on rapid sends (chat.py:320)
2. No max messages per thread limit — malicious premium user can send 86K messages/day = 2.5GB/month per thread

### HIGH
3. `message_reports` collection has NO Firestore rules — not protected (firestore.rules missing)
4. No message deletion for senders — soft delete pattern needed
5. No `delete_message` admin callable for moderation panel

### MEDIUM
6. Content sanitization misses Unicode homoglyphs/obfuscation (Cyrillic lookalikes, zero-width chars) (chat.py:36)
7. Premium check reads Firestore on every message send — 60 reads/min/user → $36/day at scale (chat.py:277)
8. No duplicate identical message spam detection

### LOW
9. Chat ID is `{productId}_{buyerId}` in plain text — exposes buyer UID to seller
10. Seller response time metrics not aggregated to seller_metrics collection
