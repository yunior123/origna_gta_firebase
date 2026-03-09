#!/usr/bin/env python3
"""
Record deployed version hashes to Firestore after a successful deploy.

Usage:
    python3 scripts/record_deploy_version.py --env=dev [--component=functions]

    --env         dev | staging | prod (required)
    --component   functions | firestore_rules | firestore_indexes |
                  storage_rules | hosting | schema | all (default: all)

Called automatically by deploy scripts after each deploy.
"""

import argparse
import os
import sys

# Resolve repo root and add scripts/ to path
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, "scripts"))

from version_tracker import (
    ENVIRONMENTS,
    COMPONENTS,
    compute_local_versions,
    get_access_token,
    write_versions,
)

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"


def main():
    """Function main."""
    parser = argparse.ArgumentParser(description="Record deploy versions to Firestore")
    parser.add_argument("--env", required=True, choices=list(ENVIRONMENTS.keys()),
                        help="Target environment: dev, staging, or prod")
    parser.add_argument("--component", default="all",
                        choices=COMPONENTS + ["all"],
                        help="Which component to record (default: all)")
    args = parser.parse_args()

    project_id = ENVIRONMENTS[args.env]
    print(f"\n{YELLOW}Recording deploy versions → {project_id}{NC}")

    try:
        all_versions = compute_local_versions(REPO_ROOT)
    except Exception as e:
        print(f"{RED}❌ Failed to compute local versions: {e}{NC}")
        sys.exit(1)

    if args.component == "all":
        to_record = {k: v for k, v in all_versions.items()}
    else:
        if args.component not in all_versions:
            print(f"{RED}❌ Unknown component: {args.component}{NC}")
            sys.exit(1)
        to_record = {args.component: all_versions[args.component], "git_sha": all_versions["git_sha"]}

    try:
        token = get_access_token()
        write_versions(project_id, to_record, token)
    except Exception as e:
        print(f"{RED}❌ Failed to write versions to Firestore ({project_id}): {e}{NC}")
        sys.exit(1)

    print(f"{GREEN}✅ Recorded versions for {args.env} ({project_id}):{NC}")
    for k, v in to_record.items():
        print(f"   {k:<22} {v}")


if __name__ == "__main__":
    main()
