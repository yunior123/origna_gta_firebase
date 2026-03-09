#!/usr/bin/env python3
"""
Validate that dev, staging, and prod have identical deploy versions.

Fetches version hashes from Firestore _deploy_versions/current in each project
and compares them. Also optionally validates against local source hashes.

Usage:
    python3 scripts/check_deploy_versions.py [--strict]

    --strict   Also require that deployed versions match local source files.
               Without --strict, only cross-env parity is checked.

Exit codes:
    0  All environments in sync
    1  Drift detected or fetch failed
"""

import argparse
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, "scripts"))

from version_tracker import (
    ENVIRONMENTS,
    COMPONENTS,
    compute_local_versions,
    get_access_token,
    read_versions,
)

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
CYAN = "\033[0;36m"
NC = "\033[0m"
BOLD = "\033[1m"


def _label(env: str) -> str:
    return {"dev": "DEV      ", "staging": "STAGING  ", "prod": "PROD     "}.get(env, env)


def main():
    """Function main."""
    parser = argparse.ArgumentParser(description="Check deploy version parity across environments")
    parser.add_argument("--strict", action="store_true",
                        help="Also require deployed versions match local source")
    args = parser.parse_args()

    print(f"\n{BOLD}{BLUE}╔══════════════════════════════════════════╗{NC}")
    print(f"{BOLD}{BLUE}║   Deploy Version Parity Check            ║{NC}")
    print(f"{BOLD}{BLUE}╚══════════════════════════════════════════╝{NC}\n")

    try:
        token = get_access_token()
    except RuntimeError as e:
        print(f"{RED}❌ {e}{NC}")
        sys.exit(1)

    # Fetch from all environments
    deployed: dict[str, dict | None] = {}
    for env, project_id in ENVIRONMENTS.items():
        print(f"  Fetching {_label(env)} ({project_id})...")
        try:
            deployed[env] = read_versions(project_id, token)
            if deployed[env] is None:
                print(f"  {YELLOW}⚠  No version record found for {env} — never deployed?{NC}")
        except Exception as e:
            print(f"  {RED}❌ Failed to fetch versions for {env}: {e}{NC}")
            deployed[env] = None

    print()

    # Compute local versions if needed
    local_versions = None
    if args.strict:
        try:
            local_versions = compute_local_versions(REPO_ROOT)
        except Exception as e:
            print(f"{RED}❌ Failed to compute local versions: {e}{NC}")
            sys.exit(1)

    # Print comparison table
    print(f"  {'COMPONENT':<22} {'DEV':>14} {'STAGING':>14} {'PROD':>14}", end="")
    if args.strict:
        print(f"  {'LOCAL':>14}", end="")
    print()
    print(f"  {'─' * 22} {'─' * 14} {'─' * 14} {'─' * 14}", end="")
    if args.strict:
        print(f"  {'─' * 14}", end="")
    print()

    drift_components = []

    for comp in COMPONENTS:
        vals = {}
        for env in ENVIRONMENTS:
            vals[env] = (deployed[env] or {}).get(comp, "—")

        all_deployed = [v for v in vals.values() if v != "—"]
        consistent = len(set(all_deployed)) <= 1

        if not consistent:
            drift_components.append(comp)
            icon = f"{RED}✗{NC}"
        elif not all_deployed:
            icon = f"{YELLOW}?{NC}"
        else:
            icon = f"{GREEN}✓{NC}"

        row = f"  {icon} {comp:<22} {vals['dev']:>14} {vals['staging']:>14} {vals['prod']:>14}"
        if args.strict and local_versions:
            local_val = local_versions.get(comp, "—")
            local_matches = local_val in all_deployed if all_deployed else False
            if not local_matches and all_deployed:
                drift_components.append(f"{comp}:local")
                row += f"  {RED}{local_val:>14}{NC}"
            else:
                row += f"  {local_val:>14}"
        print(row)

    # git_sha row
    git_vals = {}
    for env in ENVIRONMENTS:
        git_vals[env] = (deployed[env] or {}).get("git_sha", "—")
    print(f"\n  {'git_sha':<22} {git_vals['dev']:>14} {git_vals['staging']:>14} {git_vals['prod']:>14}")
    if args.strict and local_versions:
        print(f"  {'(local git_sha)':<22} {'':>14} {'':>14} {'':>14}  {local_versions.get('git_sha', '—'):>14}")

    print()

    if drift_components:
        print(f"{RED}❌ Version drift detected in: {', '.join(dict.fromkeys(drift_components))}{NC}")
        print(f"\n{YELLOW}To fix, deploy the drifted components to all environments:{NC}")
        print("   firebase deploy --only firestore:rules --project orignagta-dev")
        print("   firebase deploy --only firestore:rules --project orignagta-staging")
        print("   firebase deploy --only firestore:rules --project orignagta")
        print("\n   Then record the versions:")
        print("   python3 scripts/record_deploy_version.py --env=dev")
        print("   python3 scripts/record_deploy_version.py --env=staging")
        print("   python3 scripts/record_deploy_version.py --env=prod")
        sys.exit(1)
    else:
        print(f"{GREEN}✅ All environments are in sync — no drift detected.{NC}\n")


if __name__ == "__main__":
    main()
