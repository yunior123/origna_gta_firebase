#!/usr/bin/env python3
"""Module validate_rules.py."""

import json
import subprocess
import sys
import os

ENVIRONMENTS = ['orignagta-dev', 'orignagta-staging', 'orignagta']
LOCAL_RULES_FILE = 'firestore.rules'

def get_access_token():
    """Function get_access_token."""
    try:
        result = subprocess.run(
            ['gcloud', 'auth', 'print-access-token'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print("❌ Failed to get gcloud access token. Ensure gcloud is authenticated.")
        print(e.stderr)
        sys.exit(1)

def get_deployed_rules(project_id, access_token):
    """Function get_deployed_rules."""
    print(f"Fetching rules for {project_id}...")
    
    # 1. Get the latest release for Cloud Firestore
    releases_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/releases"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "x-goog-user-project": project_id
    }
    
    try:
        import urllib.request
        import ssl
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        req = urllib.request.Request(releases_url, headers=headers)
        with urllib.request.urlopen(req, context=ctx) as response:
            releases_data = json.loads(response.read().decode())
    except Exception as e:
        print(f"❌ Failed to fetch rules releases for {project_id}: {e}")
        return None

    # Find the firestore release
    firestore_release = next((r for r in releases_data.get('releases', []) if r.get('name', '').endswith('releases/cloud.firestore')), None)
    
    if not firestore_release:
        print(f"❌ No firestore rules release found for {project_id}.")
        return None

    ruleset_name = firestore_release.get('rulesetName')
    
    # 2. Get the ruleset content
    ruleset_url = f"https://firebaserules.googleapis.com/v1/{ruleset_name}"
    try:
        req = urllib.request.Request(ruleset_url, headers=headers)
        with urllib.request.urlopen(req, context=ctx) as response:
            ruleset_data = json.loads(response.read().decode())
    except Exception as e:
        print(f"❌ Failed to fetch ruleset for {project_id}: {e}")
        return None

    # Extract the file content
    files = ruleset_data.get('source', {}).get('files', [])
    if not files:
        print(f"❌ No files found in ruleset for {project_id}.")
        return None
        
    return files[0].get('content', '')

def normalize_rules(rules_text):
    """Normalize rules by stripping whitespace to ignore line-ending differences."""
    return '\\n'.join([line.rstrip() for line in rules_text.strip().splitlines()])

def main():
    """Function main."""
    if not os.path.exists(LOCAL_RULES_FILE):
        print(f"❌ Error: {LOCAL_RULES_FILE} not found.")
        sys.exit(1)

    with open(LOCAL_RULES_FILE, 'r', encoding='utf-8') as f:
        local_rules_raw = f.read()
        
    local_rules = normalize_rules(local_rules_raw)
    
    access_token = get_access_token()
    all_passed = True

    for env in ENVIRONMENTS:
        deployed_rules_raw = get_deployed_rules(env, access_token)
        if deployed_rules_raw is None:
            all_passed = False
            continue
            
        deployed_rules = normalize_rules(deployed_rules_raw)
        
        if local_rules != deployed_rules:
            print(f"❌ ERROR: Environment {env} has different Firestore rules deployed than the local {LOCAL_RULES_FILE} file.")
            all_passed = False
        else:
            print(f"✅ Environment {env} rules match local file.")

    if not all_passed:
        print("\\n❌ Rule validation failed. Please deploy rules to all environments using:")
        print("   firebase deploy --only firestore:rules --project <env>")
        sys.exit(1)

    print("🎉 All environments have the correct Firestore rules deployed.")

if __name__ == "__main__":
    main()
