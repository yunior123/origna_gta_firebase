#!/usr/bin/env python3
"""
Documentation crawler for audit enrichment.
Crawls external provider docs (Stripe, Firebase, Algolia, Cloudflare, Mailjet)
and returns cleaned text to include alongside project code in audit prompts.

Multi-strategy crawling:
  1. Stripe  → .md endpoint (raw markdown, no JS required)
  2. Firebase/Algolia → standard HTML parse (SSR, good text content)
  3. Cloudflare → <main> tag extraction (Astro SSG)
  4. Mailjet  → GitHub raw README (Gatsby CSR = no server content)
"""
import re
import time
import hashlib
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse

import requests
from html.parser import HTMLParser

SCRIPT_DIR = Path(__file__).resolve().parent
CACHE_DIR = SCRIPT_DIR / ".doc_cache"
CACHE_TTL_HOURS = 24  # Re-crawl after 24 hours

# Standard request headers
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,text/markdown,text/plain,*/*",
    "Accept-Language": "en-US,en;q=0.9",
}


# ─── Documentation URL Registry ─────────────────────────────────────────────
# Each entry: (label, url, strategy)
#   strategy: "stripe_md" | "html" | "html_main" | "raw"
#
# • stripe_md  — append .md to URL for raw markdown (Stripe-specific)
# • html       — standard HTML parse, skip nav/footer/script (Firebase, Algolia)
# • html_main  — extract only <main> tag content (Cloudflare Astro SSG)
# • html_article — extract <article id="content"> (Stripe fallback)
# • raw        — URL returns raw text/markdown directly (GitHub raw, etc.)

DOC_URLS = {
    "payment": [
        ("Stripe: Direct Charges (Connect)", "https://docs.stripe.com/connect/direct-charges", "stripe_md"),
        ("Stripe: PaymentIntents API", "https://docs.stripe.com/api/payment_intents", "stripe_md"),
        ("Stripe: Express Accounts", "https://docs.stripe.com/connect/express-accounts", "stripe_md"),
        ("Stripe: Webhooks", "https://docs.stripe.com/webhooks", "stripe_md"),
        ("Stripe: Disputes", "https://docs.stripe.com/disputes", "stripe_md"),
        ("Stripe: Refunds", "https://docs.stripe.com/refunds", "stripe_md"),
        ("Stripe: Manual Capture", "https://docs.stripe.com/payments/place-a-hold-on-a-payment-method", "stripe_md"),
        ("Stripe: Account Capabilities", "https://docs.stripe.com/connect/account-capabilities", "stripe_md"),
    ],
    "auth": [
        ("Firebase Auth: Getting Started", "https://firebase.google.com/docs/auth/web/start", "html"),
        ("Firebase Auth: Manage Users", "https://firebase.google.com/docs/auth/web/manage-users", "html"),
        ("Firestore: Security Rules Structure", "https://firebase.google.com/docs/firestore/security/rules-structure", "html"),
        ("Firestore: Security Rules Conditions", "https://firebase.google.com/docs/firestore/security/rules-conditions", "html"),
    ],
    "orders": [
        ("Stripe: PaymentIntents API", "https://docs.stripe.com/api/payment_intents", "stripe_md"),
        ("Stripe: Webhooks", "https://docs.stripe.com/webhooks", "stripe_md"),
        ("Stripe: Manual Capture", "https://docs.stripe.com/payments/place-a-hold-on-a-payment-method", "stripe_md"),
        ("Stripe: Refunds", "https://docs.stripe.com/refunds", "stripe_md"),
    ],
    "product": [
        ("Algolia: API Keys Security", "https://www.algolia.com/doc/guides/security/api-keys/", "html"),
        ("Cloudflare R2: Presigned URLs", "https://developers.cloudflare.com/r2/api/s3/presigned-urls/", "html_main"),
        ("Firestore: Security Rules Structure", "https://firebase.google.com/docs/firestore/security/rules-structure", "html"),
    ],
    "seller": [
        ("Stripe: Express Accounts", "https://docs.stripe.com/connect/express-accounts", "stripe_md"),
        ("Stripe: Account Capabilities", "https://docs.stripe.com/connect/account-capabilities", "stripe_md"),
        ("Stripe: Direct Charges (Connect)", "https://docs.stripe.com/connect/direct-charges", "stripe_md"),
    ],
    "data_flow": [
        ("Firestore: Data Model", "https://firebase.google.com/docs/firestore/data-model", "html"),
        ("Firestore: Security Rules Structure", "https://firebase.google.com/docs/firestore/security/rules-structure", "html"),
        ("Algolia: API Keys Security", "https://www.algolia.com/doc/guides/security/api-keys/", "html"),
    ],
    "error_handling": [
        ("Stripe: Error Handling", "https://docs.stripe.com/error-handling", "stripe_md"),
        ("Stripe: Webhooks", "https://docs.stripe.com/webhooks", "stripe_md"),
        ("Firebase Auth: Error Handling", "https://firebase.google.com/docs/auth/admin/errors", "html"),
    ],
    "performance": [
        ("Firestore: Best Practices", "https://firebase.google.com/docs/firestore/best-practices", "html"),
        ("Algolia: API Keys Security", "https://www.algolia.com/doc/guides/security/api-keys/", "html"),
    ],
    "state_management": [
        ("Stripe: Payment Intents Lifecycle", "https://docs.stripe.com/payments/payment-intents", "stripe_md"),
        ("Stripe: Manual Capture", "https://docs.stripe.com/payments/place-a-hold-on-a-payment-method", "stripe_md"),
        ("Stripe: Refunds", "https://docs.stripe.com/refunds", "stripe_md"),
    ],
    "api_security": [
        ("Stripe: Webhooks", "https://docs.stripe.com/webhooks", "stripe_md"),
        ("Firebase Auth: Getting Started", "https://firebase.google.com/docs/auth/web/start", "html"),
        ("Firestore: Security Rules Structure", "https://firebase.google.com/docs/firestore/security/rules-structure", "html"),
        ("Algolia: API Keys Security", "https://www.algolia.com/doc/guides/security/api-keys/", "html"),
        ("Cloudflare R2: Presigned URLs", "https://developers.cloudflare.com/r2/api/s3/presigned-urls/", "html_main"),
    ],
    "email_notifications": [
        ("Mailjet Python SDK", "https://raw.githubusercontent.com/mailjet/mailjet-apiv3-python/master/README.md", "raw"),
    ],
}


# ─── HTML Text Extractors ────────────────────────────────────────────────────

class _HTMLTextExtractor(HTMLParser):
    """General-purpose HTML to text converter — strips tags and scripts."""

    _SKIP_TAGS = frozenset(("script", "style", "svg", "noscript"))
    _NAV_TAGS = frozenset(("nav", "footer", "header"))
    _BLOCK_TAGS = frozenset(("p", "div", "br", "h1", "h2", "h3", "h4", "h5",
                             "h6", "li", "tr", "td", "pre", "blockquote",
                             "section", "article", "dt", "dd"))

    def __init__(self, *, skip_nav: bool = True):
        """Function __init__."""
        super().__init__()
        self._pieces: list[str] = []
        self._skip_depth: int = 0
        self._skip_nav = skip_nav

    def handle_starttag(self, tag, attrs):
        """Function handle_starttag."""
        if tag in self._SKIP_TAGS:
            self._skip_depth += 1
        elif self._skip_nav and tag in self._NAV_TAGS:
            self._skip_depth += 1

    def handle_endtag(self, tag):
        """Function handle_endtag."""
        if tag in self._SKIP_TAGS:
            self._skip_depth = max(0, self._skip_depth - 1)
        elif self._skip_nav and tag in self._NAV_TAGS:
            self._skip_depth = max(0, self._skip_depth - 1)
        if tag in self._BLOCK_TAGS:
            self._pieces.append("\n")

    def handle_data(self, data):
        """Function handle_data."""
        if self._skip_depth == 0:
            txt = data.strip()
            if txt:
                self._pieces.append(txt + " ")

    def get_text(self) -> str:
        """Function get_text."""
        raw = "".join(self._pieces)
        raw = re.sub(r'\n{3,}', '\n\n', raw)
        raw = re.sub(r'[ \t]+', ' ', raw)
        return raw.strip()


class _ScopedHTMLExtractor(HTMLParser):
    """Extract text only from inside a specific container tag.

    Works for:
      • <main> content (Cloudflare)
      • <article id="content"> (Stripe fallback)
    """

    _SKIP_TAGS = frozenset(("script", "style", "svg", "nav", "footer", "noscript"))
    _BLOCK_TAGS = frozenset(("p", "div", "br", "h1", "h2", "h3", "h4", "h5",
                             "h6", "li", "tr", "td", "pre", "blockquote",
                             "section", "dt", "dd"))

    def __init__(self, scope_tag: str = "main",
                 scope_attrs: Optional[dict] = None):
        """Function __init__."""
        super().__init__()
        self._scope_tag = scope_tag
        self._scope_attrs = scope_attrs or {}
        self._in_scope = False
        self._scope_depth = 0
        self._skip_depth = 0
        self._pieces: list[str] = []

    def handle_starttag(self, tag, attrs):
        """Function handle_starttag."""
        attrs_dict = dict(attrs)
        # Enter scope
        if (tag == self._scope_tag and not self._in_scope and
                all(attrs_dict.get(k) == v for k, v in self._scope_attrs.items())):
            self._in_scope = True
            self._scope_depth = 1
            return
        if self._in_scope:
            if tag == self._scope_tag:
                self._scope_depth += 1
            if tag in self._SKIP_TAGS:
                self._skip_depth += 1

    def handle_endtag(self, tag):
        """Function handle_endtag."""
        if not self._in_scope:
            return
        if tag == self._scope_tag:
            self._scope_depth -= 1
            if self._scope_depth <= 0:
                self._in_scope = False
                return
        if tag in self._SKIP_TAGS:
            self._skip_depth = max(0, self._skip_depth - 1)
        if tag in self._BLOCK_TAGS:
            self._pieces.append("\n")

    def handle_data(self, data):
        """Function handle_data."""
        if self._in_scope and self._skip_depth == 0:
            txt = data.strip()
            if txt:
                self._pieces.append(txt + " ")

    def get_text(self) -> str:
        """Function get_text."""
        raw = "".join(self._pieces)
        raw = re.sub(r'\n{3,}', '\n\n', raw)
        raw = re.sub(r'[ \t]+', ' ', raw)
        return raw.strip()


def _html_to_text(html: str) -> str:
    """Convert full HTML to plain text (general strategy)."""
    parser = _HTMLTextExtractor()
    parser.feed(html)
    return parser.get_text()


def _html_main_to_text(html: str) -> str:
    """Extract text only from <main> tag (for Cloudflare/Astro sites)."""
    parser = _ScopedHTMLExtractor(scope_tag="main")
    parser.feed(html)
    return parser.get_text()


def _html_article_to_text(html: str) -> str:
    """Extract text from <article id='content'> (Stripe SSR fallback)."""
    parser = _ScopedHTMLExtractor(scope_tag="article",
                                  scope_attrs={"id": "content"})
    parser.feed(html)
    return parser.get_text()


# ─── Cache Management ────────────────────────────────────────────────────────

def _cache_key(url: str) -> str:
    """Generate a cache filename from URL."""
    h = hashlib.md5(url.encode()).hexdigest()[:12]
    domain = urlparse(url).netloc.replace(".", "_")
    return f"{domain}_{h}.txt"


def _get_cached(url: str) -> Optional[str]:
    """Return cached content if fresh enough, else None."""
    CACHE_DIR.mkdir(exist_ok=True)
    cache_path = CACHE_DIR / _cache_key(url)
    if cache_path.exists():
        age_hours = (time.time() - cache_path.stat().st_mtime) / 3600
        if age_hours < CACHE_TTL_HOURS:
            return cache_path.read_text()
    return None


def _set_cached(url: str, text: str):
    """Write content to cache."""
    CACHE_DIR.mkdir(exist_ok=True)
    cache_path = CACHE_DIR / _cache_key(url)
    cache_path.write_text(text)


# ─── Crawl Functions ─────────────────────────────────────────────────────────

def _fetch(url: str, timeout: int = 30) -> requests.Response:
    """Fetch a URL with standard headers."""
    return requests.get(url, headers=_HEADERS, timeout=timeout, allow_redirects=True)


def _crawl_stripe_md(url: str, max_chars: int, timeout: int) -> str:
    """Stripe-specific: fetch raw markdown via .md suffix.
    Falls back to <article> HTML extraction if .md returns 404."""
    md_url = url.rstrip("/") + ".md"
    try:
        resp = _fetch(md_url, timeout=timeout)
        if resp.status_code == 200:
            text = resp.text.strip()
            # Verify it's actual markdown (starts with # or ---)
            if text.startswith("#") or text.startswith("---"):
                if len(text) > max_chars:
                    text = text[:max_chars] + "\n\n[... truncated ...]"
                return text
    except requests.RequestException:
        pass  # Fall through to HTML fallback

    # Fallback: fetch HTML and extract <article id="content">
    try:
        resp = _fetch(url, timeout=timeout)
        resp.raise_for_status()
        text = _html_article_to_text(resp.text)
        if text and len(text) > 200:
            if len(text) > max_chars:
                text = text[:max_chars] + "\n\n[... truncated ...]"
            return text
        # Last resort: full HTML parse
        text = _html_to_text(resp.text)
        if len(text) > max_chars:
            text = text[:max_chars] + "\n\n[... truncated ...]"
        return text
    except requests.RequestException as e:
        return f"[ERROR crawling {url}: {e}]"


def _crawl_html(url: str, max_chars: int, timeout: int) -> str:
    """Standard HTML crawl — good for Firebase, Algolia (SSR sites)."""
    try:
        resp = _fetch(url, timeout=timeout)
        resp.raise_for_status()
        text = _html_to_text(resp.text)
        if len(text) > max_chars:
            text = text[:max_chars] + "\n\n[... truncated ...]"
        return text
    except requests.RequestException as e:
        return f"[ERROR crawling {url}: {e}]"


def _crawl_html_main(url: str, max_chars: int, timeout: int) -> str:
    """Extract only <main> tag content — for Cloudflare/Astro sites."""
    try:
        resp = _fetch(url, timeout=timeout)
        resp.raise_for_status()
        text = _html_main_to_text(resp.text)
        if not text or len(text) < 200:
            # Fallback to full HTML
            text = _html_to_text(resp.text)
        if len(text) > max_chars:
            text = text[:max_chars] + "\n\n[... truncated ...]"
        return text
    except requests.RequestException as e:
        return f"[ERROR crawling {url}: {e}]"


def _crawl_raw(url: str, max_chars: int, timeout: int) -> str:
    """Fetch raw text/markdown directly (GitHub raw URLs, etc.)."""
    try:
        resp = _fetch(url, timeout=timeout)
        resp.raise_for_status()
        text = resp.text.strip()
        if len(text) > max_chars:
            text = text[:max_chars] + "\n\n[... truncated ...]"
        return text
    except requests.RequestException as e:
        return f"[ERROR crawling {url}: {e}]"


_STRATEGY_MAP = {
    "stripe_md": _crawl_stripe_md,
    "html": _crawl_html,
    "html_main": _crawl_html_main,
    "html_article": _crawl_stripe_md,  # same fallback chain
    "raw": _crawl_raw,
}


def crawl_url(url: str, max_chars: int = 15_000, timeout: int = 30,
              strategy: str = "html") -> str:
    """Crawl a single documentation URL and return cleaned text.

    Args:
        url: The documentation URL to crawl
        max_chars: Maximum characters to return per page
        timeout: Request timeout in seconds
        strategy: One of 'stripe_md', 'html', 'html_main', 'raw'

    Returns:
        Cleaned text content, truncated to max_chars
    """
    # Check cache first
    cached = _get_cached(url)
    if cached:
        return cached[:max_chars]

    crawl_fn = _STRATEGY_MAP.get(strategy, _crawl_html)
    text = crawl_fn(url, max_chars, timeout)

    if not text.startswith("[ERROR"):
        _set_cached(url, text)

    return text


def crawl_docs_for_audit(
    audit_type: str,
    max_chars_per_page: int = 12_000,
    max_total_chars: int = 60_000,
) -> str:
    """Crawl all documentation URLs for a given audit type.
    
    Args:
        audit_type: Key into DOC_URLS (e.g. 'payment', 'auth')
        max_chars_per_page: Max chars to extract per URL
        max_total_chars: Max total chars for all docs combined
    
    Returns:
        Formatted string with all crawled documentation
    """
    urls = DOC_URLS.get(audit_type, [])
    if not urls:
        return ""

    sections = []
    total = 0
    crawled = 0
    failed = 0

    print(f"  📚 Crawling {len(urls)} documentation pages for '{audit_type}' audit...")

    for entry in urls:
        label, url, strategy = entry[0], entry[1], entry[2] if len(entry) > 2 else "html"

        if total >= max_total_chars:
            remaining = len(urls) - crawled - failed
            sections.append(f"\n\n[TRUNCATED — {remaining} docs skipped due to size limit]")
            break

        remaining_budget = max_total_chars - total
        chars_for_page = min(max_chars_per_page, remaining_budget)

        text = crawl_url(url, max_chars=chars_for_page, strategy=strategy)
        if text.startswith("[ERROR"):
            print(f"    ⚠️  {label}: {text}")
            failed += 1
            continue

        block = f"\n\n### EXTERNAL DOC: {label}\n**Source:** {url}\n```\n{text}\n```"
        sections.append(block)
        total += len(block)
        crawled += 1
        print(f"    ✅ {label} ({len(text):,} chars via {strategy})")

    print(f"  📚 Crawled {crawled}/{len(urls)} docs ({total:,} chars total, {failed} failed)")
    return "".join(sections)


def clear_cache():
    """Remove all cached documentation files."""
    if CACHE_DIR.exists():
        for f in CACHE_DIR.iterdir():
            f.unlink()
        print(f"Cache cleared: {CACHE_DIR}")


# ─── CLI ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        audit_type = sys.argv[1]
        if audit_type == "--clear-cache":
            clear_cache()
        elif audit_type == "--list":
            for key, urls in DOC_URLS.items():
                print(f"\n{key}:")
                for label, url in urls:
                    print(f"  - {label}: {url}")
        else:
            result = crawl_docs_for_audit(audit_type)
            print(f"\n{'='*60}")
            print(f"Result ({len(result):,} chars):")
            print(result[:2000])
    else:
        print("Usage: python doc_crawler.py <audit_type|--clear-cache|--list>")
        print(f"Available audit types: {', '.join(DOC_URLS.keys())}")
