#!/usr/bin/env python3
"""
Mock Stripe Server for E2E Testing

This server simulates Stripe Connect and Checkout APIs for testing purposes.
Run this server locally to mock Stripe responses during E2E tests.
"""

import json
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import time


class MockStripeHandler(BaseHTTPRequestHandler):
    """Class MockStripeHandler."""
    def do_POST(self):
        """Handle POST requests to mock Stripe endpoints"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path

        # Set CORS headers
        self.send_cors_headers()

        if path == "/v1/accounts":
            self.handle_create_account()
        elif path == "/v1/account_links":
            self.handle_create_account_link()
        elif path == "/v1/checkout/sessions":
            self.handle_create_checkout_session()
        elif path.startswith("/v1/checkout/sessions/") and path.endswith("/line_items"):
            session_id = path.split("/")[3]
            self.handle_get_line_items(session_id)
        else:
            self.send_error_response(404, "Endpoint not found")

    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path

        self.send_cors_headers()

        if path.startswith("/v1/checkout/sessions/"):
            session_id = path.split("/")[3]
            if "/line_items" in path:
                self.handle_get_line_items(session_id)
            else:
                self.handle_get_checkout_session(session_id)
        else:
            self.send_error_response(404, "Endpoint not found")

    def send_cors_headers(self):
        """Send CORS headers for all responses"""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Content-Type", "application/json")

    def send_error_response(self, code, message):
        """Send error response"""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        response = {"error": {"type": "invalid_request_error", "message": message}}
        self.wfile.write(json.dumps(response).encode())

    def handle_create_account(self):
        """Mock creating a Stripe Connect account"""
        account_id = f"acct_{uuid.uuid4().hex[:16]}"
        response = {
            "id": account_id,
            "object": "account",
            "business_type": "individual",
            "capabilities": {"card_payments": {"requested": True}, "transfers": {"requested": True}},
            "charges_enabled": False,
            "country": "CA",
            "created": int(time.time()),
            "default_currency": "cad",
            "details_submitted": False,
            "email": "test@example.com",
            "payouts_enabled": False,
            "requirements": {"currently_due": [], "eventually_due": [], "past_due": [], "pending_verification": []},
            "type": "express",
        }
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def handle_create_account_link(self):
        """Mock creating account link for onboarding"""
        link_id = f"link_{uuid.uuid4().hex[:16]}"
        response = {
            "object": "account_link",
            "created": int(time.time()),
            "expires_at": int(time.time()) + 3600,
            "url": "http://localhost:5005/seller/onboarding-success?mock=true",
        }
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def handle_create_checkout_session(self):
        """Mock creating checkout session"""
        session_id = f"cs_test_{uuid.uuid4().hex[:16]}"
        response = {
            "id": session_id,
            "object": "checkout.session",
            "amount_total": 5000,  # $50.00
            "currency": "cad",
            "customer": None,
            "customer_email": "buyer@test.com",
            "line_items": [
                {
                    "amount_total": 5000,
                    "currency": "cad",
                    "description": "Test Product",
                    "price": {"id": "price_test_123", "object": "price"},
                    "quantity": 1,
                }
            ],
            "livemode": False,
            "mode": "payment",
            "payment_intent": f"pi_{uuid.uuid4().hex[:16]}",
            "payment_status": "paid",
            "status": "complete",
            "success_url": "http://localhost:5005/payment-success?session_id={CHECKOUT_SESSION_ID}",
            "url": "http://localhost:5005/payment-success?mock=true&session_id=" + session_id,
        }
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def handle_get_checkout_session(self, session_id):
        """Mock getting checkout session"""
        response = {
            "id": session_id,
            "object": "checkout.session",
            "amount_total": 5000,
            "currency": "cad",
            "customer_email": "buyer@test.com",
            "line_items": [{"amount_total": 5000, "currency": "cad", "description": "Test Product", "quantity": 1}],
            "livemode": False,
            "mode": "payment",
            "payment_status": "paid",
            "status": "complete",
        }
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def handle_get_line_items(self, session_id):
        """Mock getting line items"""
        response = {
            "object": "list",
            "data": [
                {
                    "id": "li_test_123",
                    "object": "item",
                    "amount_total": 5000,
                    "currency": "cad",
                    "description": "Test Product",
                    "price": {"id": "price_test_123", "object": "price"},
                    "quantity": 1,
                }
            ],
            "has_more": False,
            "url": "/v1/checkout/sessions/cs_test_123/line_items",
        }
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def log_message(self, format, *args):
        """Override to reduce log noise"""
        pass


def run_mock_server(port=4242):
    """Run the mock Stripe server"""
    server_address = ("", port)
    httpd = HTTPServer(server_address, MockStripeHandler)
    print(f"Mock Stripe server running on port {port}")
    print("Endpoints:")
    print("  POST /v1/accounts - Create Connect account")
    print("  POST /v1/account_links - Create account link")
    print("  POST /v1/checkout/sessions - Create checkout session")
    print("  GET /v1/checkout/sessions/{id} - Get session")
    print("Press Ctrl+C to stop")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nMock Stripe server stopped")
        httpd.shutdown()


if __name__ == "__main__":
    run_mock_server()
