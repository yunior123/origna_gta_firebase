"""
🏗️ Infrastructure Verification Audit Hook

Verifies that all project configuration matches what's deployed in production:
- Cloud Functions (deployed vs code)
- Firestore Rules & Indexes (deployed vs local)
- Stripe Webhooks & API config (events registered, keys valid)
- GCP Secret Manager (all required secrets exist)
- Storage Rules, Hosting, CORS, Cron Jobs

Uses CLI tools (gcloud, firebase, stripe) when available.
"""
from __future__ import annotations

import json
import subprocess
import shutil

from .base import BaseHook, Finding, HookResult, register_hook
from .config import PROJECT_ROOT, CRITICAL, HIGH, MEDIUM, LOW
from .prompts import STRUCTURED_OUTPUT_INSTRUCTION, PROJECT_CONTEXT


def _run_cmd(cmd: list[str], timeout: int = 30) -> tuple[int, str, str]:
    """Run a CLI command safely. Returns (returncode, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            cwd=str(PROJECT_ROOT),
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return -1, "", f"Command not found: {cmd[0]}"
    except subprocess.TimeoutExpired:
        return -2, "", f"Timeout after {timeout}s"
    except Exception as e:
        return -3, "", str(e)


def _has_cmd(name: str) -> bool:
    """Check if a CLI tool is available."""
    return shutil.which(name) is not None


# ──────────────────────────────────────────────────────────────────────────────
# Cloud Functions Verifier
# ──────────────────────────────────────────────────────────────────────────────

def _get_decorated_functions() -> set[str]:
    """
    Scan all Python files in functions/ to find ONLY functions with Cloud Function
    decorators (@https_fn.on_call, @https_fn.on_request, @scheduler_fn, @firestore_fn, etc.).
    Returns set of function names that are ACTUAL Cloud Function entry points.
    """
    import re
    decorator_pattern = re.compile(
        r"@(?:https_fn\.on_call|https_fn\.on_request|scheduler_fn\.\w+|firestore_fn\.\w+|"
        r"tasks_fn\.\w+|storage_fn\.\w+|eventarc_fn\.\w+)\b"
    )
    func_after_decorator = re.compile(r"^def\s+(\w+)\s*\(")

    decorated = set()
    handlers_dir = PROJECT_ROOT / "functions" / "handlers"
    search_dirs = [PROJECT_ROOT / "functions", handlers_dir]

    for search_dir in search_dirs:
        if not search_dir.exists():
            continue
        for py_file in search_dir.glob("*.py"):
            try:
                lines = py_file.read_text().splitlines()
                in_decorator = False
                for line in lines:
                    stripped = line.strip()
                    if decorator_pattern.search(stripped):
                        in_decorator = True
                    elif in_decorator and func_after_decorator.match(stripped):
                        m = func_after_decorator.match(stripped)
                        if m:
                            decorated.add(m.group(1))
                        in_decorator = False
                    elif in_decorator and stripped and not stripped.startswith("@") and not stripped.startswith("#"):
                        in_decorator = False
            except Exception:
                continue

    return decorated


def verify_functions() -> list[Finding]:
    """Compare DECORATED Cloud Functions vs deployed functions.
    
    Only flags functions that have a Cloud Function decorator (@https_fn, @scheduler_fn, etc.)
    and are NOT deployed. Internal helpers in __all__ (like process_charge_refunded,
    calculate_shipping_cost) are NOT flagged — they're not meant to be deployed separately.
    """
    findings = []

    # 1. Parse __all__ from main.py
    main_py = PROJECT_ROOT / "functions" / "main.py"
    if not main_py.exists():
        findings.append(Finding(
            severity=CRITICAL, title="functions/main.py not found",
            description="Cannot verify Cloud Functions without main.py",
            file="functions/main.py", category="infra",
        ))
        return findings

    text = main_py.read_text()
    # Extract __all__ list
    import ast
    try:
        tree = ast.parse(text)
        local_functions = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        if isinstance(node.value, ast.List):
                            local_functions = [
                                elt.value for elt in node.value.elts
                                if isinstance(elt, ast.Constant) and isinstance(elt.value, str)
                            ]
    except Exception:
        local_functions = []

    if not local_functions:
        findings.append(Finding(
            severity=HIGH, title="Could not parse __all__ from main.py",
            description="Unable to extract function list from main.py",
            file="functions/main.py", category="infra",
        ))
        return findings

    # 2. Identify which functions are ACTUAL Cloud Function entry points (have decorators)
    decorated_functions = _get_decorated_functions()
    # Deployable = in __all__ AND has a Cloud Function decorator
    deployable_functions = [fn for fn in local_functions if fn in decorated_functions]
    # Non-deployable = in __all__ but plain Python helpers (no decorator)
    helper_functions = [fn for fn in local_functions if fn not in decorated_functions]

    findings.append(Finding(
        severity=LOW, title=f"{len(deployable_functions)} deployable Cloud Functions",
        description=f"In __all__ with decorator. Plus {len(helper_functions)} internal helpers: {', '.join(sorted(helper_functions)[:10])}",
        file="functions/main.py", category="infra",
    ))

    # 3. Check runtime.txt
    runtime_file = PROJECT_ROOT / "functions" / "runtime.txt"
    if runtime_file.exists():
        runtime = runtime_file.read_text().strip()
        if "python311" not in runtime and "python312" not in runtime:
            findings.append(Finding(
                severity=MEDIUM, title=f"Runtime '{runtime}' — verify compatibility",
                description="Ensure Python runtime matches Cloud Functions Gen2 support",
                file="functions/runtime.txt", category="infra",
            ))

    # 4. Try gcloud CLI to list deployed functions — only compare DEPLOYABLE functions
    if _has_cmd("gcloud"):
        rc, stdout, stderr = _run_cmd([
            "gcloud", "functions", "list",
            "--project=orignagta", "--format=json",
        ], timeout=60)

        if rc == 0 and stdout.strip():
            try:
                deployed = json.loads(stdout)
                deployed_names = {
                    f.get("name", "").split("/")[-1]
                    for f in deployed
                }

                # Only check DEPLOYABLE functions (with decorators), not helpers
                missing = [fn for fn in deployable_functions if fn not in deployed_names]
                if missing:
                    for fn in sorted(missing):
                        findings.append(Finding(
                            severity=HIGH,
                            title=f"Function '{fn}' not deployed",
                            description=f"Cloud Function '{fn}' has a Firebase decorator but is not deployed to production",
                            file="functions/main.py",
                            category="infra",
                            fix_suggestion=f"firebase deploy --only functions:{fn} --project=orignagta",
                        ))

                # Check for orphaned deployed functions not in our codebase
                all_known = set(local_functions) | decorated_functions
                for fn in deployed_names:
                    if fn not in all_known and fn not in {"", "None"}:
                        findings.append(Finding(
                            severity=MEDIUM,
                            title=f"Orphaned function '{fn}' deployed",
                            description=f"Function '{fn}' is deployed but not in __all__ or codebase",
                            file="functions/main.py",
                            category="infra",
                        ))

            except json.JSONDecodeError:
                findings.append(Finding(
                    severity=LOW, title="Could not parse gcloud functions output",
                    description=f"Raw output: {stdout[:200]}", file="functions/main.py",
                    category="infra",
                ))
        elif rc == -1:
            findings.append(Finding(
                severity=MEDIUM,
                title="gcloud CLI available but functions list failed",
                description=f"stderr: {stderr[:200]}",
                file="functions/main.py", category="infra",
            ))
    else:
        findings.append(Finding(
            severity=LOW, title="gcloud CLI not available — skipping deployed functions check",
            description="Install gcloud CLI for full verification: https://cloud.google.com/sdk/docs/install",
            file="functions/main.py", category="infra",
        ))

    return findings


# ──────────────────────────────────────────────────────────────────────────────
# Firestore Rules & Indexes Verifier
# ──────────────────────────────────────────────────────────────────────────────

def verify_firestore() -> list[Finding]:
    """Verify Firestore rules and indexes."""
    findings = []

    # 1. Parse firestore.rules — static checks
    rules_file = PROJECT_ROOT / "firestore.rules"
    if rules_file.exists():
        rules = rules_file.read_text()
        lines = rules.splitlines()

        # Check for dangerous patterns
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if "allow read, write: if true" in stripped:
                findings.append(Finding(
                    severity=CRITICAL,
                    title="Open Firestore rule found",
                    description=f"Line {i}: `{stripped}` — allows unrestricted access",
                    file="firestore.rules", line=i, category="security",
                ))
            if "allow read, write;" in stripped and "if" not in stripped:
                findings.append(Finding(
                    severity=CRITICAL,
                    title="Unconditional Firestore rule",
                    description=f"Line {i}: `{stripped}` — no condition",
                    file="firestore.rules", line=i, category="security",
                ))

        # Check required collections have rules
        # Note: "cart" is a subcollection under users/{userId}/cart/{itemId}
        # "categories" are hardcoded constants (#1-21), not a Firestore collection
        # Missing collections are denied by catch-all rule: match /{document=**} { allow read, write: if false; }
        required_collections = [
            "users", "products", "orders", "security_alerts",
            "admin_logs", "config", "product_ratings", "refunds",
            "webhook_logs", "webhook_events", "rate_limits", "payouts",
        ]
        # Also check subcollections that should have rules
        required_subcollections = {
            "cart": "users/{userId}/cart",    # nested under users
        }

        for coll in required_collections:
            # Check both top-level and nested match patterns
            if f"match /{coll}" not in rules and f"/{coll}/" not in rules:
                findings.append(Finding(
                    severity=HIGH,
                    title=f"No Firestore rules for '{coll}' collection",
                    description=f"Collection '{coll}' may be unprotected (catch-all denies by default)",
                    file="firestore.rules", category="security",
                ))

        for subcoll, path_hint in required_subcollections.items():
            if f"match /{subcoll}" not in rules:
                findings.append(Finding(
                    severity=HIGH,
                    title=f"No Firestore rules for subcollection '{subcoll}'",
                    description=f"Expected at {path_hint}",
                    file="firestore.rules", category="security",
                ))
    else:
        findings.append(Finding(
            severity=CRITICAL, title="firestore.rules not found",
            description="Firestore security rules file missing",
            file="firestore.rules", category="infra",
        ))

    # 2. Parse firestore.indexes.json
    indexes_file = PROJECT_ROOT / "firestore.indexes.json"
    if indexes_file.exists():
        try:
            indexes = json.loads(indexes_file.read_text())
            idx_count = len(indexes.get("indexes", []))
            findings.append(Finding(
                severity=LOW,
                title=f"{idx_count} composite indexes defined",
                description="Verify all are deployed with `gcloud firestore indexes composite list`",
                file="firestore.indexes.json", category="infra",
            ))
        except json.JSONDecodeError:
            findings.append(Finding(
                severity=HIGH, title="Invalid firestore.indexes.json",
                description="JSON parse error in indexes file",
                file="firestore.indexes.json", category="infra",
            ))

    # 3. firebase CLI does not support a safe "dry-run" deploy for Firestore rules.
    # Keep checks local-only here (static scan above). Actual deploy should happen via
    # an explicit deploy script/command.
    if _has_cmd("firebase"):
        findings.append(Finding(
            severity=LOW,
            title="Firestore rules deploy validation skipped",
            description=(
                "Firebase CLI has no supported dry-run for firestore:rules; "
                "rely on static checks + explicit deploy."
            ),
            file="firestore.rules",
            category="infra",
        ))

    # 4. Check indexes deployment  
    if _has_cmd("gcloud"):
        rc, stdout, stderr = _run_cmd([
            "gcloud", "firestore", "indexes", "composite", "list",
            "--project=orignagta", "--format=json",
        ], timeout=60)

        if rc == 0 and stdout.strip():
            try:
                deployed_indexes = json.loads(stdout)
                creating = [
                    idx for idx in deployed_indexes
                    if idx.get("state") in ("CREATING", "NEEDS_REPAIR")
                ]
                if creating:
                    findings.append(Finding(
                        severity=HIGH,
                        title=f"{len(creating)} indexes still CREATING/NEEDS_REPAIR",
                        description="Indexes not ready — queries will fail",
                        file="firestore.indexes.json", category="infra",
                    ))
            except json.JSONDecodeError:
                pass

    return findings


# ──────────────────────────────────────────────────────────────────────────────
# Stripe Configuration Verifier
# ──────────────────────────────────────────────────────────────────────────────

def verify_stripe() -> list[Finding]:
    """Verify Stripe webhook endpoints, events, and configuration."""
    findings = []

    # Required webhook events (from payment_stripe.py)
    required_events = [
        "checkout.session.completed",
        "checkout.session.expired",
        "payment_intent.succeeded",
        "payment_intent.payment_failed",
        "charge.refunded",
        "charge.dispute.created",
        "charge.dispute.updated",
        "charge.dispute.closed",
        "charge.dispute.funds_reinstated",
        "account.updated",
    ]

    # 1. Check Stripe CLI
    if not _has_cmd("stripe"):
        findings.append(Finding(
            severity=MEDIUM,
            title="Stripe CLI not available — limited verification",
            description="Install Stripe CLI: https://stripe.com/docs/stripe-cli",
            file="functions/handlers/payment_stripe.py", category="infra",
        ))
        return findings

    # 2. Determine CLI mode early (test vs live) so we can interpret findings.
    is_test_mode: bool | None = None
    rc, stdout, stderr = _run_cmd(["stripe", "config", "--list"], timeout=15)
    if rc == 0:
        is_test_mode = "test" in stdout.lower()
        if is_test_mode:
            findings.append(Finding(
                severity=MEDIUM,
                title="Stripe CLI configured with test keys",
                description="Ensure production keys are set in GCP Secret Manager",
                file="functions/config.py",
                category="infra",
            ))
    else:
        findings.append(Finding(
            severity=MEDIUM,
            title="Stripe CLI not configured",
            description="Run `stripe login` to authenticate",
            file="functions/config.py",
            category="infra",
        ))

    # 3. List webhook endpoints
    rc, stdout, stderr = _run_cmd([
        "stripe", "webhook_endpoints", "list", "--limit=20",
    ], timeout=30)

    if rc == 0 and stdout.strip():
        # Parse webhook endpoints
        if "No webhook endpoints" in stdout:
            findings.append(Finding(
                severity=CRITICAL,
                title="No Stripe webhook endpoints configured",
                description="Webhooks are required for checkout completion, disputes, refunds",
                file="functions/handlers/payment_stripe.py", category="infra",
                fix_suggestion="Create webhook endpoint: stripe webhook_endpoints create --url=https://us-central1-orignagta.cloudfunctions.net/stripe_webhook --enabled-events=checkout.session.completed,...",
            ))
        else:
            # Check for production URL
            expected_url = "us-central1-orignagta.cloudfunctions.net/stripe_webhook"
            if expected_url not in stdout:
                findings.append(Finding(
                    severity=MEDIUM if is_test_mode else HIGH,
                    title="Production webhook URL not found",
                    description=f"Expected URL containing: {expected_url}",
                    file="functions/handlers/payment_stripe.py", category="infra",
                ))

            # Check registered events
            for event in required_events:
                if event not in stdout:
                    findings.append(Finding(
                        severity=HIGH,
                        title=f"Webhook event '{event}' may not be registered",
                        description=f"Event '{event}' not found in webhook endpoints list",
                        file="functions/handlers/payment_stripe.py", category="infra",
                    ))
    elif rc != 0:
        findings.append(Finding(
            severity=MEDIUM,
            title="Stripe webhook list failed",
            description=f"Error: {stderr[:200]}. May need `stripe login` first.",
            file="functions/handlers/payment_stripe.py", category="infra",
        ))

    return findings


# ──────────────────────────────────────────────────────────────────────────────
# GCP Secrets Verifier
# ──────────────────────────────────────────────────────────────────────────────

def verify_secrets() -> list[Finding]:
    """Verify all required secrets exist in GCP Secret Manager.
    
    Uses UPPERCASE_UNDERSCORE naming to match what config.py uses via
    _load_secret() / params.SecretParam. These names match GCP Secret Manager.
    """
    findings = []

    # Secrets as named in GCP Secret Manager (UPPERCASE_UNDERSCORE)
    # Matches config.py _load_secret("NAME") calls
    required_secrets = [
        "STRIPE_SECRET_KEY",
        "STRIPE_WEBHOOK_SECRET",
        "ALGOLIA_APP_ID",
        "ALGOLIA_WRITE_API_KEY",
        "MAILJET_API_KEY",
        "MAILJET_SECRET_KEY",
        "GEOAPIFY_API_KEY",
        "UNSUBSCRIBE_HMAC_SECRET",
    ]

    # Optional secrets — warn if missing but not critical
    optional_secrets = [
        "SENTRY_DSN",
        "R2_ACCESS_KEY",
        "R2_SECRET_KEY",
        "R2_ACCOUNT_ID",
        "ALGOLIA_SEARCH_API_KEY",
    ]

    if not _has_cmd("gcloud"):
        findings.append(Finding(
            severity=MEDIUM,
            title="gcloud CLI not available — cannot verify secrets",
            description="Install gcloud CLI for secrets verification",
            file="functions/config.py", category="infra",
        ))
        return findings

    rc, stdout, stderr = _run_cmd([
        "gcloud", "secrets", "list", "--project=orignagta", "--format=json",
    ], timeout=30)

    if rc == 0 and stdout.strip():
        try:
            secrets = json.loads(stdout)
            secret_names = {
                s.get("name", "").split("/")[-1] for s in secrets
            }

            for req in required_secrets:
                if req not in secret_names:
                    findings.append(Finding(
                        severity=CRITICAL,
                        title=f"Missing secret: '{req}'",
                        description=f"Secret '{req}' not found in GCP Secret Manager",
                        file="functions/config.py", category="infra",
                        fix_suggestion=f"echo 'YOUR_VALUE' | gcloud secrets create {req} --data-file=- --project=orignagta",
                    ))
                else:
                    findings.append(Finding(
                        severity=LOW,
                        title=f"Secret '{req}' exists ✓",
                        description="Present in GCP Secret Manager",
                        file="functions/config.py", category="infra",
                    ))

            for opt in optional_secrets:
                if opt not in secret_names:
                    findings.append(Finding(
                        severity=MEDIUM,
                        title=f"Optional secret missing: '{opt}'",
                        description=f"Secret '{opt}' not in GCP Secret Manager — may be needed for full functionality",
                        file="functions/config.py", category="infra",
                    ))

        except json.JSONDecodeError:
            findings.append(Finding(
                severity=MEDIUM,
                title="Could not parse gcloud secrets output",
                description=stderr[:200], file="functions/config.py", category="infra",
            ))
    elif rc != 0:
        findings.append(Finding(
            severity=MEDIUM,
            title="gcloud secrets list failed",
            description=f"Error: {stderr[:200]}",
            file="functions/config.py", category="infra",
        ))

    return findings


# ──────────────────────────────────────────────────────────────────────────────
# Storage Rules Verifier
# ──────────────────────────────────────────────────────────────────────────────

def verify_storage() -> list[Finding]:
    """Verify storage.rules configuration."""
    findings = []
    rules_file = PROJECT_ROOT / "storage.rules"

    if not rules_file.exists():
        findings.append(Finding(
            severity=CRITICAL, title="storage.rules not found",
            description="Storage security rules file missing",
            file="storage.rules", category="infra",
        ))
        return findings

    rules = rules_file.read_text()

    # Check for size limit
    if "10 * 1024 * 1024" not in rules and "10485760" not in rules:
        findings.append(Finding(
            severity=HIGH, title="No 10MB upload limit in storage rules",
            description="Missing file size validation in storage.rules",
            file="storage.rules", category="security",
        ))

    # Check for content type validation
    if "contentType" not in rules:
        findings.append(Finding(
            severity=HIGH, title="No content type validation in storage rules",
            description="Anyone could upload executable files",
            file="storage.rules", category="security",
        ))

    # Check for auth
    if "request.auth" not in rules:
        findings.append(Finding(
            severity=CRITICAL, title="No auth check in storage rules",
            description="Unauthenticated uploads may be possible",
            file="storage.rules", category="security",
        ))

    return findings


# ──────────────────────────────────────────────────────────────────────────────
# Firebase Hosting Verifier
# ──────────────────────────────────────────────────────────────────────────────

def verify_hosting() -> list[Finding]:
    """Verify firebase.json hosting configuration."""
    findings = []
    firebase_json = PROJECT_ROOT / "firebase.json"

    if not firebase_json.exists():
        findings.append(Finding(
            severity=CRITICAL, title="firebase.json not found",
            description="Firebase configuration missing",
            file="firebase.json", category="infra",
        ))
        return findings

    try:
        config = json.loads(firebase_json.read_text())
    except json.JSONDecodeError:
        findings.append(Finding(
            severity=CRITICAL, title="Invalid firebase.json",
            description="JSON parse error", file="firebase.json", category="infra",
        ))
        return findings

    hosting = config.get("hosting", {})

    # Security headers
    headers = hosting.get("headers", [])
    header_text = json.dumps(headers)
    required_headers = [
        "X-Content-Type-Options",
        "X-Frame-Options",
        "Strict-Transport-Security",
        "X-XSS-Protection",
    ]
    for h in required_headers:
        if h not in header_text:
            findings.append(Finding(
                severity=HIGH,
                title=f"Missing security header: {h}",
                description=f"Header '{h}' not configured in firebase.json hosting",
                file="firebase.json", category="security",
            ))

    # SPA rewrite
    rewrites = hosting.get("rewrites", [])
    has_spa_rewrite = any(
        r.get("source") == "**" and r.get("destination") == "/index.html"
        for r in rewrites
    )
    if not has_spa_rewrite:
        findings.append(Finding(
            severity=HIGH,
            title="Missing SPA rewrite for Flutter web",
            description="Flutter web needs `** → /index.html` rewrite",
            file="firebase.json", category="infra",
        ))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTERED HOOK
# ═══════════════════════════════════════════════════════════════════════════════

@register_hook
class InfraHook(BaseHook):
    """
    Infrastructure verification hook.

    Runs CLI-based checks FIRST (fast, no LLM cost), then uses LLM
    for deeper analysis of config files.
    """
    hook_name = "infra"
    description = "Infrastructure verification: Functions, Rules, Indexes, Stripe, Secrets, Hosting"
    emoji = "🏗️"

    watch_patterns = [
        "firebase.json",
        "firestore.rules",
        "firestore.indexes.json",
        "storage.rules",
        "functions/main.py",
        "functions/config.py",
        "functions/runtime.txt",
        "functions/requirements.txt",
        "functions/handlers/payment_stripe.py",
    ]

    target_files = [
        "firebase.json",
        "firestore.rules",
        "firestore.indexes.json",
        "storage.rules",
        "functions/main.py",
        "functions/config.py",
        "functions/runtime.txt",
        "functions/requirements.txt",
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a senior DevOps/SRE engineer verifying PRODUCTION READINESS for a March 2026 launch.

{PROJECT_CONTEXT}

## Your Task

Analyze all infrastructure configuration files and verify:

1. **Cloud Functions** — Are all functions in __all__ properly exported? Any typos? Correct trigger types?
2. **Firestore Rules** — Comprehensive security? Every collection protected? No gaps?
3. **Firestore Indexes** — All needed indexes defined? Cover all query patterns?
4. **Storage Rules** — Upload restrictions correct? Auth required? Size limits?
5. **Firebase Hosting** — Security headers? SPA rewrite? CORS?
6. **Dependencies** — requirements.txt frozen? Compatible versions?
7. **Environment** — Runtime version? Region configuration?

## Cross-Reference
- Compare functions in main.py __all__ with actual handler imports
- Compare firestore.indexes.json indexes with query patterns in handlers
- Verify firebase.json hosting config matches Flutter web needs
- Check requirements.txt versions for security vulnerabilities

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""

    def run(self, changed_only: list[str] | None = None) -> HookResult:
        """
        Override run() to add CLI-based verification BEFORE LLM analysis.
        """
        import time
        start = time.time()
        result = HookResult(hook_name=self.hook_name, status="success")

        print(f"\n{self.emoji} {self.hook_name}: Running infrastructure verification...")

        # ── Phase 1: CLI-based checks (FREE, no LLM cost) ──
        print("  📋 Phase 1: CLI-based verification...")

        cli_findings = []
        cli_findings.extend(verify_functions())
        cli_findings.extend(verify_firestore())
        cli_findings.extend(verify_stripe())
        cli_findings.extend(verify_secrets())
        cli_findings.extend(verify_storage())
        cli_findings.extend(verify_hosting())

        critical_cli = sum(1 for f in cli_findings if f.severity == CRITICAL)
        high_cli = sum(1 for f in cli_findings if f.severity == HIGH)
        print(f"  ✅ Phase 1 complete: {len(cli_findings)} findings "
              f"({critical_cli} critical, {high_cli} high)")

        result.findings.extend(cli_findings)

        # ── Phase 2: LLM analysis of config files ──
        # Only run LLM if we have target files (saves $$$)
        files = self.resolve_files(changed_only)
        if files:
            result.files_audited = len(files)
            print(f"  🤖 Phase 2: LLM analysis of {len(files)} config files...")

            try:
                context = self.bundle_files(files)
                prompt = self.get_prompt()

                # Add CLI findings as context for LLM
                cli_summary = "\n## CLI Verification Results (already checked):\n"
                for f in cli_findings:
                    cli_summary += f"- [{f.severity}] {f.title}\n"
                context = cli_summary + context

                raw_response = self.call_llm(prompt, context)
                llm_findings = self.parse_findings(raw_response)
                result.findings.extend(llm_findings)
                result.markdown_report = raw_response
            except Exception as e:
                print(f"  ⚠️  LLM analysis skipped: {e}")
                result.markdown_report = "LLM analysis skipped — CLI findings only"

        # Sort all findings by severity
        result.findings.sort(key=lambda f: f.severity_rank)
        result.duration_seconds = round(time.time() - start, 2)

        return result
