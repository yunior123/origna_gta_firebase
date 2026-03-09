"""Module append_learned.py."""
with open('.claude/LEARNED.md', 'a', encoding='utf-8') as f:
    f.write("""
---

## Add Product — Code Audit Learnings (Feb 2026)
- **MVVM Violations:** Ensure screens contain 0 business logic state (`setState` variables). Form flow, inventory config, category selections must be handled in `AddProductState` and managed by the ViewModel.
- **Controller Leaks:** Always ensure every `TextEditingController` created in a screen (especially in dynamic forms or dialogs) is disposed in the `dispose()` method or after dialog `pop`.
- **Validation Consistency:** Inline UI validators (like `compareAtPrice - price < 0.50`) must perfectly match the ViewModel validation logic, otherwise the user passes UI validation but gets blocked by a snackbar.
- **Magic Strings:** Never use hardcoded English strings in widgets (e.g. `labelText: 'Category'`). Use translation keys (`'product.category'.tr()`) to ensure compliance with Bill 96.
- **Pagination False Positives:** When paginating Firestore, fetching exactly `pageSize` docs and checking `snapshot.docs.length >= pageSize` causes an empty next page if the total docs is an exact multiple. Fix by fetching `pageSize + 1`, checking length, and slicing.
- **Parallelization:** When uploading or compressing multiple images, use `Future.wait` for parallel processing instead of sequential `for` loops.

## Seller Warehouses & Profiles Audit (Feb 2026)
- **Firestore Deletion Guards:** `delete_warehouse` backend handler must query `products` (using `warehouseIds array_contains`) to prevent deleting a warehouse that is actively used by products. Firestore Rules cannot enforce cross-collection `array-contains` constraints.
- **isDefault Uniqueness:** Batch writes do not retry on conflict. Enforcing a single default warehouse per seller requires a `@firestore.transactional` block in Python, not a batch write. Firestore rules cannot query sibling documents to enforce "at most one true" constraints.
- **Cross-Stack Sync:** When a denormalized field like `shipFromCountries` exists on the product level, it must be added consistently across Pydantic models, Dart Freezed models, Firestore schema JSON, and synchronized on warehouse mutations.
- **Sequential Read Race Conditions:** Two sequential `get()` calls in Python (e.g. reading `users` then `seller_profiles`) can introduce race conditions. Use `@firestore.transactional` to read them consistently when validating critical business state (like checking if a seller is suspended before allowing checkout).
- **Province Code Validation:** Province inputs must be validated against `CanadianProvinceValues` rather than free-text to prevent breaking GST/HST lookups during checkout.

## Subscription & Premium Features Audit (Feb 2026)
- **Stripe Webhook Dictionary vs Object:** In webhook handlers (like `invoice.paid`), be careful with wrapper dicts. `event["data"]["object"]` is a dict, not a Stripe object. Call Stripe's `.retrieve(sub_id)` to get the object, or handle the dict appropriately.
- **Stripe Idempotency Expiry:** Stripe idempotency keys expire after 24 hours. A static idempotency key (like `f"premium_sub_{uid}"`) will fail if the user retries a day later. Scope keys to the date `f"premium_sub_{uid}_{datetime.now(UTC).date().isoformat()}"`.
- **AppLifecycleState for Timers:** If a screen uses a `Timer` (e.g. 30 seconds to wait for Stripe activation), pause the timer when the app is backgrounded (Stripe checkout) using `WidgetsBindingObserver`, otherwise it will fire while the user is away.
- **Role Scoping:** Always verify roles before executing paid actions. Ensure `create_subscription` blocks `seller` accounts from subscribing if the feature is only meant for buyers.
- **StreamProvider AutoDispose:** When a StreamProvider relies on the user ID, it should `ref.watch(authStateChangesProvider)` to correctly reset its state when the user logs out and logs in as someone else.

## Security & MFA Audit (Feb 2026)
- **TOTP Replay Attacks:** OTP codes must be invalidated after use. The backend must persist the hash of the last used OTP code and reject it if re-submitted within the valid time window.
- **Backup Code Consumption Race Conditions:** Deducting a backup code involves reading the array, finding the match, and writing the array back. This must be done inside a `@firestore.transactional` block to prevent concurrent requests from using the same code twice.
- **Firestore Lockout Increments:** Use `firestore.Increment(1)` for atomic failed attempt counting. Read-then-write `attempts + 1` allows concurrent brute forcing to bypass lockouts.
- **Fail-Closed Rate Limiting:** High-security endpoints (MFA enroll, Suspend/Unsuspend) must use `fail_closed=True` for their rate limiters so they block access if Firestore is down.
- **Rule Whitelisting on Creation:** `allow create` rules in Firestore (like `return_requests`) must explicitly whitelist keys and enforce initial default states (e.g. `request.resource.data.returnStatus == 'requested'`) to prevent client injection.
""")
