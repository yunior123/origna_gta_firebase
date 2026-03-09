#!/usr/bin/env python3
"""
R2 Upload Helper — uploads a local image file to Cloudflare R2 dev/products/ folder.
Returns the public CDN URL (https://cdn.origna.ca/dev/products/<filename>).

Usage:
    source functions/venv/bin/activate
    export $(grep -v '^#' functions/.env.local | xargs)
    python scripts/upload_r2_helper.py /tmp/my_image.jpg

Env vars required:
    R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY
"""
from __future__ import annotations

import os
import sys
import uuid
from pathlib import Path

import boto3
from botocore.config import Config

BUCKET = "orignagta"
CDN_BASE = "https://cdn.origna.ca"
FOLDER = "dev/products"  # hardcoded to dev — change for staging/prod


def upload_image(local_path: str, filename: str | None = None) -> str:
    """Upload image to R2, return public CDN URL."""
    account_id = os.environ["R2_ACCOUNT_ID"]
    access_key = os.environ["R2_ACCESS_KEY"]
    secret_key = os.environ["R2_SECRET_KEY"]

    s3 = boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )

    path = Path(local_path)
    if filename is None:
        ext = path.suffix or ".jpg"
        filename = f"psrc_{uuid.uuid4().hex}{ext}"

    key = f"{FOLDER}/{filename}"

    suffix = path.suffix.lower()
    content_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(suffix, "image/jpeg")

    with open(local_path, "rb") as f:
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=f,
            ContentType=content_type,
        )

    return f"{CDN_BASE}/{key}"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python upload_r2_helper.py <local_path>", file=sys.stderr)
        sys.exit(1)
    url = upload_image(sys.argv[1])
    print(url)
