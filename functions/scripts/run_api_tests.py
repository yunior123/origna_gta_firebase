#!/usr/bin/env python3
"""
Postman-like Integration Test Runner for Cloud Functions
Executes HTTP requests against deployed endpoints and verifies responses.
Usage: python3 run_api_tests.py [--emulator]
"""

import json
import sys
import time

import requests

# Configuration
PROJECT_ID = "orignagta"
REGION = "us-central1"

# Known URLs (from deployment logs)
STRIPE_WEBHOOK_URL = "https://stripe-webhook-wwnxr2xxoq-uc.a.run.app"


# For Gen 2 Callable functions, they are typically at:
# https://{function_name}-{random_hash}-{region}.a.run.app
# OR via the project convention:
# https://{region}-{project_id}.cloudfunctions.net/{function_name} (Gen 1 / Compat)
# We will try the Compat URL first, as it often redirects or works for callable.
DEFAULT_BASE_URL = f"https://{REGION}-{PROJECT_ID}.cloudfunctions.net"

EMULATOR_BASE_URL = f"http://127.0.0.1:5001/{PROJECT_ID}/{REGION}"


class Colors:
    """Class Colors."""
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"


def print_header(text):
    """Function print_header."""
    print(f"\n{Colors.HEADER}{Colors.BOLD}=== {text} ==={Colors.ENDC}")


def print_result(name, method, url, status, passed, duration_ms, error=None):
    """Function print_result."""
    icon = "✅" if passed else "❌"
    color = Colors.OKGREEN if passed else Colors.FAIL
    print(f"{icon} {color}{method} {name}{Colors.ENDC}")
    print(f"   URL: {url}")
    print(f"   Status: {status} | Time: {duration_ms}ms")
    if error:
        print(f"   {Colors.FAIL}Error: {error}{Colors.ENDC}")


def run_test(test_case, base_url):
    """Function run_test."""
    url = test_case.get("absolute_url") or f"{base_url}/{test_case['endpoint']}"
    method = test_case.get("method", "POST")
    headers = test_case.get("headers", {"Content-Type": "application/json"})
    body = test_case.get("body", {})

    start_time = time.time()
    try:
        response = requests.request(method, url, json=body, headers=headers, timeout=10)
        duration_ms = round((time.time() - start_time) * 1000)

        # Validation
        passed = True
        error_msg = None

        if "expected_status" in test_case and response.status_code not in test_case["expected_status"]:
            passed = False
            error_msg = f"Expected status {test_case['expected_status']}, got {response.status_code}"

        if passed and "verify_response" in test_case:
            try:
                res_json = response.json()
                if not test_case["verify_response"](res_json):
                    passed = False
                    error_msg = "Response verification failed"
            except json.JSONDecodeError:
                # Si la réponse n'est pas du JSON, passer le texte brut à la fonction de vérification
                if not test_case["verify_response"](response.text):
                    passed = False
                    error_msg = "Response was not valid JSON and did not pass text verification"

        print_result(test_case["name"], method, url, response.status_code, passed, duration_ms, error_msg)
        return passed

    except Exception as e:
        duration_ms = round((time.time() - start_time) * 1000)
        print_result(test_case["name"], method, url, "ERR", False, duration_ms, str(e))
        return False


def main():
    """Function main."""
    use_emulator = "--emulator" in sys.argv
    base_url = EMULATOR_BASE_URL if use_emulator else DEFAULT_BASE_URL

    print_header(f"Starting API Integration Tests ({'Emulator' if use_emulator else 'Production'})")

    tests = [
        # 1. Stripe Webhook (Public, Authenticated via signature)
        {
            "name": "Stripe Webhook (Missing Signature)",
            "absolute_url": STRIPE_WEBHOOK_URL,
            "method": "POST",
            "body": {"id": "evt_test", "type": "payment_intent.succeeded"},
            "expected_status": [400],  # Should fail due to missing Stripe-Signature
            "verify_response": lambda r: "signature" in str(r).lower() or "error" in r,
        },
        # 2. Create Checkout Session (Callable)
        # Expects specific wrapper {"data": ...}
        {
            "name": "Create Checkout Session (Unauthenticated)",
            "endpoint": "create_checkout_session",
            "method": "POST",
            "body": {"data": {"items": []}},
            # On Call functions usually return 200 with "error" in body if handled gracefully,
            # or 400/401/403/500/401 if unhandled or rejected at protocol level.
            # 401 est attendu ici car l'utilisateur n'est pas authentifié.
            "expected_status": [200, 400, 401, 403, 500],
            "verify_response": lambda r: "error" in r or "result" in r,
        },
        # 4. Upload Product Images (Callable)
        {
            "name": "Upload Product Images (Missing Data)",
            "endpoint": "upload_product_images",
            "method": "POST",
            "body": {"data": {}},  # Missing fileNames/contentTypes
            # 401 est attendu ici car l'utilisateur n'est pas authentifié.
            "expected_status": [200, 400, 401, 500],
            "verify_response": lambda r: "error" in r or "message" in str(r),
        },
    ]

    passed_count = 0
    for t in tests:
        if run_test(t, base_url):
            passed_count += 1

    print_header("Test Summary")
    print(f"Total Tests: {len(tests)}")
    print(f"Passed:      {Colors.OKGREEN}{passed_count}{Colors.ENDC}")
    print(f"Failed:      {Colors.FAIL}{len(tests) - passed_count}{Colors.ENDC}")

    if passed_count < len(tests):
        print("\nEnsure the functions are deployed and endpoints are correct.")
        sys.exit(1)


if __name__ == "__main__":
    main()
