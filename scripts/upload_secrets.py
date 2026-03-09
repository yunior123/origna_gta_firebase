"""Module upload_secrets.py."""

import os
import subprocess

# Secrets mapping: Env Var Name -> Secret Name (kebab-case)
SECRETS_MAP = {
    "STRIPE_SECRET_KEY": "STRIPE_SECRET_KEY",
    "STRIPE_WEBHOOK_SECRET": "STRIPE_WEBHOOK_SECRET",
    "ALGOLIA_APP_ID": "ALGOLIA_APP_ID",
    "ALGOLIA_WRITE_API_KEY": "ALGOLIA_WRITE_API_KEY",
    "GEOAPIFY_API_KEY": "GEOAPIFY_API_KEY",
    "MAILJET_API_KEY": "MAILJET_API_KEY",
    "MAILJET_SECRET_KEY": "MAILJET_SECRET_KEY",
    "R2_ACCOUNT_ID": "R2_ACCOUNT_ID",
    "R2_ACCESS_KEY": "R2_ACCESS_KEY",
    "R2_SECRET_KEY": "R2_SECRET_KEY",
    "UNSUBSCRIBE_HMAC_SECRET": "UNSUBSCRIBE_HMAC_SECRET",
    "SENTRY_DSN_BACKEND": "SENTRY_DSN_BACKEND",
    "AIRWALLEX_API_KEY": "AIRWALLEX_API_KEY",
    "AIRWALLEX_CLIENT_ID": "AIRWALLEX_CLIENT_ID",
    "AIRWALLEX_WEBHOOK_SECRET": "AIRWALLEX_WEBHOOK_SECRET",
}

PROJECTS = ["orignagta-dev", "orignagta-staging"]

def read_env_file(filepath):
    """Function read_env_file."""
    secrets = {}
    if not os.path.exists(filepath):
        return secrets
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, value = line.split('=', 1)
                secrets[key.strip()] = value.strip().strip('"').strip("'")
    return secrets

def upload_secret(project_id, secret_name, secret_value):
    """Function upload_secret."""
    print(f"Uploading {secret_name} to {project_id}...")
    try:
        # Use gcloud secrets create/versions add because firebase CLI can be interactive/slow
        # First try to create secret
        subprocess.run(
            ["gcloud", "secrets", "create", secret_name, "--project", project_id, "--replication-policy", "automatic"],
            capture_output=True
        )
        
        # Get list of currently enabled versions to disable them later
        old_versions_raw = subprocess.run(
            ["gcloud", "secrets", "versions", "list", secret_name, "--project", project_id, "--filter", "state=enabled", "--format", "value(name)"],
            capture_output=True,
            text=True
        ).stdout.strip().split("\n")
        old_versions = [v.split("/")[-1] for v in old_versions_raw if v]

        # Add secret version
        process = subprocess.Popen(
            ["gcloud", "secrets", "versions", "add", secret_name, "--project", project_id, "--data-file=-"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate(input=secret_value)
        
        if process.returncode == 0:
            print(f"✅ Successfully set {secret_name}")
            # Disable old versions to save costs
            for v_id in old_versions:
                print(f"  Disabling old version {v_id} to save costs...")
                subprocess.run(
                    ["gcloud", "secrets", "versions", "disable", v_id, "--secret", secret_name, "--project", project_id],
                    capture_output=True
                )
        else:
            print(f"❌ Failed to set {secret_name}: {stderr}")
            
    except Exception as e:
        print(f"❌ Exception setting {secret_name}: {e}")

def main():
    # Load secrets
    """Function main."""
    env_secrets = read_env_file("functions/.env")
    local_secrets = read_env_file("functions/.env.local")
    
    # Merge, preferring .env.local
    all_secrets = {**env_secrets, **local_secrets}
    
    for project in PROJECTS:
        print(f"\n--- Processing Project: {project} ---")
        
        # Enable Secret Manager API
        print(f"Enabling Secret Manager API for {project}...")
        subprocess.run(
            ["gcloud", "services", "enable", "secretmanager.googleapis.com", "--project", project],
            capture_output=True
        )
        
        for env_var, secret_name in SECRETS_MAP.items():
            if env_var in all_secrets:
                secret_value = all_secrets[env_var]
            else:
                print(f"⚠️ {secret_name} not found in .env files. Using 'dummy_value' to unblock deployment.")
                secret_value = "dummy_value"

            upload_secret(project, secret_name, secret_value)

if __name__ == "__main__":
    main()
