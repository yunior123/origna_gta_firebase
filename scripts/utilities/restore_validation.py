"""Restore the checkout server-side validation block in payment_stripe.py."""

from pathlib import Path

FILE_PATH = Path("functions/handlers/payment_stripe.py")

VALIDATION_BLOCK = [
    "    # --- SERVER-SIDE PRODUCT VALIDATION ---\n",
    "    # F-01:Authoritative price check. Never trust client-supplied prices.\n",
    "    # F-02:Atomic stock check (implemented in transaction below).\n",
    "    validated_items = []\n",
    "    actual_subtotal_cents = 0\n",
    "    sellers = set()\n",
    "\n",
    "    # Batch fetch all products for efficiency (Max 30 items per cart)\n",
    "    product_ids = [item.get(Fields.PRODUCT_ID) for item in items if item.get(Fields.PRODUCT_ID)]\n",
    "    if not product_ids:\n",
    "        raise https_fn.HttpsError(\"invalid-argument\", \"No valid product IDs in cart\")\n",
    "\n",
]


def main() -> None:
    if not FILE_PATH.exists():
        raise SystemExit(f"Missing file: {FILE_PATH}")

    lines = FILE_PATH.read_text().splitlines(keepends=True)
    marker = "Recompute all_digital from server-verified validated_items"

    for idx, line in enumerate(lines):
        if marker in line:
            updated = lines[:idx] + VALIDATION_BLOCK + lines[idx:]
            FILE_PATH.write_text("".join(updated))
            print(f"Inserted validation block before line {idx + 1}")
            return

    raise SystemExit("Insertion marker not found; validation block was not restored")


if __name__ == "__main__":
    main()
