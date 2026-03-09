"""Module optimize_secrets.py."""
import subprocess
import json

PROJECTS = ["orignagta-dev", "orignagta-staging", "orignagta"]

def run_command(cmd, capture_output=True):
    """Function run_command."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=capture_output, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error: {e.stderr}")
        return None

def get_secrets(project):
    """Function get_secrets."""
    print(f"Listing secrets for {project}...")
    output = run_command(f"gcloud secrets list --project {project} --format=json")
    if not output:
        return []
    return json.loads(output)

def get_versions(project, secret_name):
    """Function get_versions."""
    output = run_command(f"gcloud secrets versions list {secret_name} --project {project} --format=json")
    if not output:
        return []
    return json.loads(output)

def disable_version(project, secret_name, version):
    """Function disable_version."""
    print(f"Disabling version {version} of {secret_name} in {project}...")
    run_command(f"gcloud secrets versions disable {version} --secret={secret_name} --project={project}")

def delete_secret(project, secret_name):
    """Function delete_secret."""
    print(f"DELETING secret {secret_name} in {project}...")
    # Using --quiet to avoid interactive confirmation
    run_command(f"gcloud secrets delete {secret_name} --project={project} --quiet")

def optimize_project(project):
    """Function optimize_project."""
    print(f"\n=== Optimizing Project: {project} ===")
    secrets = get_secrets(project)
    
    canonical_secrets = []
    redundant_secrets = []
    
    for s in secrets:
        name = s['name'].split('/')[-1]
        if name.isupper():
            canonical_secrets.append(name)
        else:
            redundant_secrets.append(name)
            
    print(f"Found {len(canonical_secrets)} canonical (UPPERCASE) secrets.")
    print(f"Found {len(redundant_secrets)} non-canonical (kebab-case/other) secrets.")
    
    # 1. Optimize Canonical Secrets (keep only latest version)
    for name in canonical_secrets:
        versions = get_versions(project, name)
        # Sort by creation time or version ID descending
        # Version names are like .../versions/1, .../versions/2
        versions.sort(key=lambda x: int(x['name'].split('/')[-1]), reverse=True)
        
        enabled_versions = [v for v in versions if v['state'].lower() == 'enabled']
        
        if len(enabled_versions) > 1:
            print(f"Secret {name} has {len(enabled_versions)} enabled versions. Optimizing...")
            # Keep the first one (latest), disable others
            latest = enabled_versions[0]['name'].split('/')[-1]
            for v in enabled_versions[1:]:
                v_id = v['name'].split('/')[-1]
                disable_version(project, name, v_id)
        elif len(enabled_versions) == 1:
            print(f"Secret {name} is already optimized (1 enabled version).")
        else:
            print(f"⚠️ Secret {name} has NO enabled versions!")

    # 2. Cleanup Redundant Secrets
    for name in redundant_secrets:
        # Check if there's a corresponding UPPERCASE secret
        uppercase_name = name.upper().replace("-", "_")
        if uppercase_name in canonical_secrets:
            print(f"Secret {name} is redundant (canonical version {uppercase_name} exists).")
            delete_secret(project, name)
        else:
            print(f"Secret {name} is non-canonical but no UPPERCASE version found. Keeping for safety but disabling versions.")
            versions = get_versions(project, name)
            for v in versions:
                if v['state'].lower() == 'enabled':
                    v_id = v['name'].split('/')[-1]
                    disable_version(project, name, v_id)

if __name__ == "__main__":
    for project in PROJECTS:
        optimize_project(project)
    print("\n✅ Optimization complete.")
