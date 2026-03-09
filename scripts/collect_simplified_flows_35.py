#!/usr/bin/env python3
"""
collect_simplified_flows_35.py

Generate a simplified 35-flow bundle for Claude chat usage (Sonnet 4.6 style workflow):
- Uses only non-test flows (35 total).
- Limits each flow folder to 20 files max:
    18 primary files + INSTRUCTIONS.md + optional _overflow.md.
- Enforces a total byte cap per flow (inherited from base script by default).

Output:
    ~/Desktop/origna_flows_simplified_35

Environment overrides:
    ORIGNA_SIMPLIFIED_MAX_PRIMARY_FILES   (default: 18)
    ORIGNA_SIMPLIFIED_MAX_BYTES           (default: 1500000)
    ORIGNA_SIMPLIFIED_OUTPUT_DIR          (default: ~/Desktop/origna_flows_simplified_35)
"""

from __future__ import annotations

import os
from pathlib import Path

import collect_flow_files as base


def _select_non_test_flows() -> dict[str, list[str]]:
    flows = {name: files for name, files in base.FLOWS.items() if not name.startswith("test_")}
    if len(flows) != 35:
        raise SystemExit(f"Expected 35 non-test flows, found {len(flows)}")
    return flows


def main() -> None:
    """Function main."""
    output_dir = Path(
        os.getenv(
            "ORIGNA_SIMPLIFIED_OUTPUT_DIR",
            str(Path.home() / "Desktop" / "origna_flows_simplified_35"),
        )
    )
    max_primary = int(os.getenv("ORIGNA_SIMPLIFIED_MAX_PRIMARY_FILES", "18"))
    max_bytes = int(os.getenv("ORIGNA_SIMPLIFIED_MAX_BYTES", "1500000"))

    if max_primary <= 0:
        raise SystemExit("ORIGNA_SIMPLIFIED_MAX_PRIMARY_FILES must be > 0")
    if max_bytes <= 0:
        raise SystemExit("ORIGNA_SIMPLIFIED_MAX_BYTES must be > 0")

    # Patch base collector settings for this specialized run.
    base.DESKTOP = output_dir
    base.MAX_FILES_PER_FLOW = max_primary
    base.MAX_TOTAL_FILES_PER_FLOW = max_primary + 2
    base.MAX_TOTAL_BYTES = max_bytes
    base.FLOWS = _select_non_test_flows()

    base.create_complete_flows()


if __name__ == "__main__":
    main()

