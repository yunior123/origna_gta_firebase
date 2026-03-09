#!/usr/bin/env python3
"""
Shared utilities for computing and comparing deploy version hashes.

Each "version" is a SHA-256 short hash of the relevant source artifacts.
Versions are stored per-environment in Firestore under _deploy_versions/current.
"""

import hashlib
import json
import os
import subprocess
import ssl
import urllib.request
from typing import Optional

ENVIRONMENTS = {
    "dev": "orignagta-dev",
    "staging": "orignagta-staging",
    "prod": "orignagta",
}
FIRESTORE_DOC = "_deploy_versions/current"

COMPONENTS = ["functions", "firestore_rules", "firestore_indexes", "storage_rules", "hosting", "schema"]


# ---------------------------------------------------------------------------
# Hash computation
# ---------------------------------------------------------------------------

def _sha256_file(path: str) -> str:
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:12]


def _sha256_dir(dirpath: str, extensions: tuple = (".py",), exclude_dirs: tuple = ()) -> str:
    sha = hashlib.sha256()
    for root, dirs, files in os.walk(dirpath):
        dirs[:] = sorted(d for d in dirs if d not in exclude_dirs)
        for fname in sorted(files):
            if any(fname.endswith(ext) for ext in extensions):
                fpath = os.path.join(root, fname)
                sha.update(fname.encode())
                with open(fpath, "rb") as fp:
                    sha.update(fp.read())
    return sha.hexdigest()[:12]


def get_git_sha() -> str:
    """Function get_git_sha."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except Exception:
        return "unknown"


def compute_local_versions(repo_root: str) -> dict:
    """Compute SHA hashes of all tracked source artifacts."""
    return {
        "functions": _sha256_dir(
            os.path.join(repo_root, "functions"),
            extensions=(".py",),
            exclude_dirs=("venv", "__pycache__", "tests", ".git"),
        ),
        "firestore_rules": _sha256_file(os.path.join(repo_root, "firestore.rules")),
        "firestore_indexes": _sha256_file(os.path.join(repo_root, "firestore.indexes.json")),
        "storage_rules": _sha256_file(os.path.join(repo_root, "storage.rules")),
        "hosting": _sha256_dir(
            os.path.join(repo_root, "origna_gta", "lib"),
            extensions=(".dart",),
            exclude_dirs=("generated", ".dart_tool"),
        ),
        "schema": _sha256_file(os.path.join(repo_root, "docs", "database_schema.json")),
        "git_sha": get_git_sha(),
    }


# ---------------------------------------------------------------------------
# Firestore REST helpers (gcloud auth token)
# ---------------------------------------------------------------------------

def _ssl_ctx():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def get_access_token() -> str:
    """Function get_access_token."""
    try:
        result = subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True, text=True, check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"gcloud auth failed: {e.stderr}") from e


def _firestore_url(project_id: str, doc_path: str) -> str:
    return (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        f"/databases/(default)/documents/{doc_path}"
    )


def _to_firestore_doc(data: dict) -> dict:
    fields = {}
    for k, v in data.items():
        if isinstance(v, str):
            fields[k] = {"stringValue": v}
        elif isinstance(v, int):
            fields[k] = {"integerValue": str(v)}
        elif isinstance(v, bool):
            fields[k] = {"booleanValue": v}
        elif v is None:
            fields[k] = {"nullValue": None}
    return {"fields": fields}


def _from_firestore_doc(doc: dict) -> dict:
    result = {}
    for k, v in doc.get("fields", {}).items():
        if "stringValue" in v:
            result[k] = v["stringValue"]
        elif "integerValue" in v:
            result[k] = int(v["integerValue"])
        elif "booleanValue" in v:
            result[k] = v["booleanValue"]
        else:
            result[k] = None
    return result


def write_versions(project_id: str, versions: dict, access_token: str) -> None:
    """Write version hashes to Firestore."""
    url = _firestore_url(project_id, FIRESTORE_DOC) + "?updateMask.fieldPaths=" + "&updateMask.fieldPaths=".join(versions.keys())
    body = json.dumps(_to_firestore_doc(versions)).encode()
    req = urllib.request.Request(
        url, data=body, method="PATCH",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "x-goog-user-project": project_id,
        },
    )
    with urllib.request.urlopen(req, context=_ssl_ctx()) as resp:
        resp.read()


def read_versions(project_id: str, access_token: str) -> Optional[dict]:
    """Read version hashes from Firestore. Returns None if not found."""
    url = _firestore_url(project_id, FIRESTORE_DOC)
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "x-goog-user-project": project_id,
        },
    )
    try:
        with urllib.request.urlopen(req, context=_ssl_ctx()) as resp:
            doc = json.loads(resp.read().decode())
            return _from_firestore_doc(doc)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
