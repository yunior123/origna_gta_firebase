#!/usr/bin/env python3
"""
🏗️ Standalone Infrastructure Verification Script

Runs CLI-based checks WITHOUT LLM (free, fast).
Use this for quick pre-deploy verification.

Usage:
  python audit/scripts/verify_infra.py                    # All domains
  python audit/scripts/verify_infra.py --domain stripe    # Stripe only
  python audit/scripts/verify_infra.py --domain firestore # Firestore only
  python audit/scripts/verify_infra.py --domain functions # Cloud Functions only
  python audit/scripts/verify_infra.py --domain secrets   # GCP Secrets only
  python audit/scripts/verify_infra.py --domain hosting   # Firebase Hosting only
  python audit/scripts/verify_infra.py --domain storage   # Storage rules only
  python audit/scripts/verify_infra.py --domain all       # Everything
  python audit/scripts/verify_infra.py --json             # JSON output
"""
import argparse
import json
import sys
from pathlib import Path

# Add audit directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from hooks.hook_infra import (
    verify_functions,
    verify_firestore,
    verify_stripe,
    verify_secrets,
    verify_storage,
    verify_hosting,
)
from hooks.config import CRITICAL, HIGH, MEDIUM, LOW


DOMAIN_MAP = {
    "functions": ("☁️  Cloud Functions", verify_functions),
    "firestore": ("🔥 Firestore Rules & Indexes", verify_firestore),
    "stripe": ("💳 Stripe Configuration", verify_stripe),
    "secrets": ("🔑 GCP Secret Manager", verify_secrets),
    "storage": ("📦 Storage Rules", verify_storage),
    "hosting": ("🌐 Firebase Hosting", verify_hosting),
}

SEVERITY_EMOJI = {
    CRITICAL: "🔴",
    HIGH: "🟠",
    MEDIUM: "🟡",
    LOW: "🟢",
}


def main():
    """Function main."""
    parser = argparse.ArgumentParser(
        description="🏗️ Infrastructure Verification — CLI-based (no LLM cost)"
    )
    parser.add_argument(
        "--domain", "-d",
        choices=list(DOMAIN_MAP.keys()) + ["all"],
        default="all",
        help="Which domain to verify (default: all)",
    )
    parser.add_argument(
        "--json", "-j",
        action="store_true",
        help="Output as JSON instead of text",
    )
    parser.add_argument(
        "--fail-on-high",
        action="store_true",
        help="Exit with code 1 if HIGH+ findings found",
    )

    args = parser.parse_args()

    # Resolve domains
    if args.domain == "all":
        domains = list(DOMAIN_MAP.keys())
    else:
        domains = [args.domain]

    all_findings = []
    results = {}

    print(f"\n{'='*60}")
    print("🏗️  INFRASTRUCTURE VERIFICATION")
    print(f"{'='*60}\n")

    for domain in domains:
        label, verifier = DOMAIN_MAP[domain]
        print(f"{label}...")

        findings = verifier()
        all_findings.extend(findings)
        results[domain] = findings

        critical = sum(1 for f in findings if f.severity == CRITICAL)
        high = sum(1 for f in findings if f.severity == HIGH)
        medium = sum(1 for f in findings if f.severity == MEDIUM)

        if critical > 0:
            print(f"  🔴 {critical} CRITICAL, 🟠 {high} HIGH, 🟡 {medium} MEDIUM")
        elif high > 0:
            print(f"  🟠 {high} HIGH, 🟡 {medium} MEDIUM")
        else:
            print(f"  ✅ {len(findings)} findings ({medium} medium)")

        # Print detailed findings
        for f in sorted(findings, key=lambda x: {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}.get(x.severity, 99)):
            emoji = SEVERITY_EMOJI.get(f.severity, "⚪")
            print(f"    {emoji} [{f.severity}] {f.title}")
            if f.fix_suggestion:
                print(f"       💡 Fix: {f.fix_suggestion[:100]}")
        print()

    # Summary
    total = len(all_findings)
    total_c = sum(1 for f in all_findings if f.severity == CRITICAL)
    total_h = sum(1 for f in all_findings if f.severity == HIGH)
    total_m = sum(1 for f in all_findings if f.severity == MEDIUM)
    total_l = sum(1 for f in all_findings if f.severity == LOW)

    print(f"{'='*60}")
    print(f"📊 SUMMARY: {total} findings")
    print(f"   🔴 {total_c} Critical | 🟠 {total_h} High | 🟡 {total_m} Medium | 🟢 {total_l} Low")
    print(f"{'='*60}")

    if total_c > 0:
        print(f"\n🚨 {total_c} CRITICAL issues — MUST FIX before production!")

    # JSON output
    if args.json:
        output = {
            "timestamp": __import__("datetime").datetime.now().isoformat(),
            "summary": {
                "critical": total_c, "high": total_h,
                "medium": total_m, "low": total_l, "total": total,
            },
            "domains": {
                domain: [f.to_dict() for f in findings]
                for domain, (_, _) in DOMAIN_MAP.items()
                if domain in results
            },
        }
        # Fix: findings from results dict
        output["domains"] = {
            domain: [f.to_dict() for f in results[domain]]
            for domain in results
        }
        print(json.dumps(output, indent=2))

    # Exit code
    if args.fail_on_high and (total_c > 0 or total_h > 0):
        sys.exit(1)
    elif total_c > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
