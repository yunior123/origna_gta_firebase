#!/usr/bin/env python3
"""Module run_flutter_integration_with_timeout.py."""

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser(description="Run Flutter integration tests with timeout.")
    parser.add_argument(
        "--timeout",
        type=int,
        default=900,
        help="Timeout in seconds (default: 900).",
    )
    parser.add_argument(
        "--target",
        default="integration_test/all_tests.dart",
        help="Flutter integration test target (default: integration_test/all_tests.dart).",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    script_path = repo_root / "scripts" / "run_flutter_integration_tests_web.sh"

    if not script_path.exists():
        print(f"Missing script: {script_path}", file=sys.stderr)
        return 2

    cmd = [str(script_path), args.target]

    try:
        subprocess.run(cmd, check=True, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        print(
            f"Integration test timed out after {args.timeout} seconds.",
            file=sys.stderr,
        )
        return 124
    except subprocess.CalledProcessError as exc:
        return exc.returncode

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
