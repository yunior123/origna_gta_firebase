"""Module setup_secrets.py."""

import os
import subprocess
from dotenv import load_dotenv

# Load keys from functions/.env
load_dotenv("functions/.env")

PROJECTS = ["orignagta-dev", "orignagta-staging"]

# Define secrets to upload
SECRETS = {
    "STRIPE_SECRET_KEY": os.getenv("STRIPE_SECRET_KEY"),
    "STRIPE_PUBLISHABLE_KEY": "REDACTED_SECRET", # Placeholder or fetch from somewhere if available
    "STRIPE_WEBHOOK_SECRET": os.getenv("STRIPE_WEBHOOK_SECRET"),
    "ALGOLIA_API_KEY": os.getenv("ALGOLIA_WRITE_API_KEY"),
    "ALGOLIA_SEARCH_KEY": os.getenv("ALGOLIA_SEARCH_API_KEY"), 
    "ALGOLIA_APP_ID": os.getenv("ALGOLIA_APP_ID"),
    "GEOAPIFY_KEY": os.getenv("GEOAPIFY_API_KEY"),
    "CLOUDFLARE_R2_ACCESS_KEY_ID": os.getenv("R2_ACCESS_KEY_OVERRIDE"),
    "CLOUDFLARE_R2_SECRET_ACCESS_KEY": os.getenv("R2_SECRET_KEY_OVERRIDE"),
    "MAILJET_API_KEY": os.getenv("MAILJET_API_KEY"),
    "MAILJET_SECRET_KEY": os.getenv("MAILJET_SECRET_KEY"),
    "NVIDIA_NIM_API_KEY": os.getenv("NVIDIA_NIM_API_KEY"),
    "ANTHROPIC_API_KEY": os.getenv("ANTHROPIC_API_KEY"),
    "GITHUB_TOKEN": os.getenv("GITHUB_TOKEN"),
    "GOOGLE_GEMINI_API_KEY": os.getenv("GOOGLE_GEMINI_API_KEY"),
}

def run_command(cmd, check=True):
    """Function run_command."""
    print(f"Running: {cmd}")
    try:
        subprocess.run(cmd, shell=True, check=check)
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {e}")

def get_secret_from_env(key):
    """Function get_secret_from_env."""
    val = SECRETS.get(key)
    if not val:
        print(f"⚠️ Warning: Missing value for {key}")
    return val

def setup_project_secrets(project_id):
    """Function setup_project_secrets."""
    print(f"\n--- Setting up secrets for {project_id} ---")
    
    # 1. Enable Secret Manager API
    run_command(f"gcloud services enable secretmanager.googleapis.com --project {project_id}", check=False)
    
    # 2. Create and populate secrets
    for key, value in SECRETS.items():
        if not value:
            continue
            
        # Use canonical UPPERCASE name
        secret_name = key
        
        print(f"Configuring {secret_name}...")
        
        # Check if secret exists
        cmd = f"gcloud secrets describe {secret_name} --project {project_id} --format='value(name)'"
        result = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        if result.returncode != 0:
            # Create secret
            run_command(f"gcloud secrets create {secret_name} --replication-policy=automatic --project {project_id}")
        
        # Add new version
        process = subprocess.Popen(
            f"gcloud secrets versions add {secret_name} --data-file=- --project {project_id}",
            shell=True,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate(input=value)
        
        if process.returncode == 0:
            print(f"✅ Added version to {secret_name}")
        else:
            print(f"❌ Failed to add version to {secret_name}: {stderr}")

if __name__ == "__main__":
    for project in PROJECTS:
        setup_project_secrets(project)
