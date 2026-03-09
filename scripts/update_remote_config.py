"""Module update_remote_config.py."""

import os
import argparse
import subprocess
import requests
from dotenv import load_dotenv

# Load .env from functions directory
load_dotenv("functions/.env")

def get_access_token():
    """Get Access Token from gcloud."""
    try:
        token = subprocess.check_output(
            ["gcloud", "auth", "print-access-token"],
            text=True
        ).strip()
        return token
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to get access token: {e}")
        return None

def update_remote_config(project_id):
    """Function update_remote_config."""
    print(f"🔄 Updating Remote Config for {project_id} via REST API...")

    token = get_access_token()
    if not token:
        return

    url = f"https://firebaseremoteconfig.googleapis.com/v1/projects/{project_id}/remoteConfig"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "x-goog-user-project": project_id  # Critical for quota attribution with ADC
    }

    # 1. Get current config
    try:
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            print(f"⚠️ Failed to fetch current config (might be empty): {response.text}")
            current_config = {"parameters": {}}
            etag = "*" # Force update if empty
        else:
            current_config = response.json()
            etag = response.headers.get("ETag", "*")
    except Exception as e:
        print(f"❌ Error fetching config: {e}")
        return

    # Get values from .env
    algolia_app_id = os.environ.get("ALGOLIA_APP_ID", "")
    algolia_search_key = os.environ.get("ALGOLIA_SEARCH_API_KEY", "")
    algolia_admin_key = os.environ.get("ALGOLIA_ADMIN_API_KEY", "")
    geoapify_key = os.environ.get("GEOAPIFY_API_KEY", "")

    # Placeholders for missing values
    image_base_url = "https://pub-MISSING-R2-URL.r2.dev"
    sentry_dns = ""

    if not algolia_app_id or not algolia_search_key:
        print("⚠️ Warning: Algolia keys missing in .env")

    # SRCH-H3: Guard against accidentally pushing admin API key to Remote Config.
    # The admin key grants full write access to the Algolia index — it must never
    # reach client devices. Abort if the search key matches the admin key.
    if algolia_admin_key and algolia_search_key == algolia_admin_key:
        print("❌ ABORT: ALGOLIA_SEARCH_API_KEY equals ALGOLIA_ADMIN_API_KEY — "
              "you are about to push the admin key to Remote Config. "
              "Set ALGOLIA_SEARCH_API_KEY to the public search-only key.")
        return

    # Prepare new parameters
    new_params = {
        "algolia_app_id": {
            "defaultValue": {"value": algolia_app_id},
            "description": "Algolia App ID"
        },
        "algolia_search_api_key": {
            "defaultValue": {"value": algolia_search_key},
            "description": "Algolia Search API Key (Public)"
        },
        "geoapify_api_key": {
            "defaultValue": {"value": geoapify_key},
            "description": "Geoapify API Key (Public)"
        },
        "image_base_url": {
            "defaultValue": {"value": image_base_url},
            "description": "R2 Image Base URL"
        },
        "sentry_dns": {
            "defaultValue": {"value": sentry_dns},
            "description": "Sentry DSN for Flutter Monitoring"
        }
    }

    # Merge with existing parameters
    if "parameters" not in current_config:
        current_config["parameters"] = {}
    
    current_config["parameters"].update(new_params)

    # 2. Publish updated config
    headers["If-Match"] = etag
    try:
        response = requests.put(url, headers=headers, json=current_config)
        if response.status_code == 200:
            print(f"✅ Successfully updated Remote Config for {project_id}")
        else:
            print(f"❌ Failed to update Remote Config: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Error updating config: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update Remote Config for Dev/Staging")
    parser.add_argument("--projects", nargs="+", default=["orignagta-dev", "orignagta-staging"], help="Projects to update")
    args = parser.parse_args()

    for project in args.projects:
        update_remote_config(project)
