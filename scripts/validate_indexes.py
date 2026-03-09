#!/usr/bin/env python3
"""Module validate_indexes.py."""

import json
import subprocess
import sys
import os

ENVIRONMENTS = ['orignagta-dev', 'orignagta-staging', 'orignagta']
LOCAL_INDEXES_FILE = 'firestore.indexes.json'

def get_deployed_indexes(project_id):
    """Function get_deployed_indexes."""
    print(f"Fetching indexes for {project_id}...")
    try:
        # firebase firestore:indexes outputs JSON to stdout
        result = subprocess.run(
            ['firebase', 'firestore:indexes', '--project', project_id],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to fetch indexes for {project_id}")
        print(e.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"❌ Failed to parse JSON from firebase output for {project_id}")
        sys.exit(1)

def normalize_index(index):
    """Normalize index representation to compare them reliably."""
    fields = []
    for f in index.get('fields', []):
        # Ignore implicit __name__ field added by Firebase if it wasn't in our local config
        if f.get('fieldPath') == '__name__':
            continue
        fields.append((f.get('fieldPath'), f.get('order'), f.get('arrayConfig')))
    
    return {
        'collectionGroup': index.get('collectionGroup'),
        'queryScope': index.get('queryScope'),
        'fields': tuple(fields)
    }

def normalize_local_index(index):
    """Normalize local index, stripping comments and implicit __name__."""
    return normalize_index(index)

def main():
    """Function main."""
    if not os.path.exists(LOCAL_INDEXES_FILE):
        print(f"❌ Error: {LOCAL_INDEXES_FILE} not found.")
        sys.exit(1)

    with open(LOCAL_INDEXES_FILE, 'r') as f:
        local_data = json.load(f)

    local_indexes = [normalize_index(i) for i in local_data.get('indexes', [])]
    
    # Optional: we can just check if our target required index is in all environments
    # as checking every single index might fail if some env has extra indexes.
    # The requirement specifically mentions making sure the indexes are validated.
    # So we check if ALL local indexes are present in the deployed environment.

    all_passed = True

    for env in ENVIRONMENTS:
        deployed_data = get_deployed_indexes(env)
        deployed_indexes = [normalize_index(i) for i in deployed_data.get('indexes', [])]

        missing_indexes = []
        for local_idx in local_indexes:
            if local_idx not in deployed_indexes:
                missing_indexes.append(local_idx)
        
        if missing_indexes:
            print(f"❌ ERROR: Environment {env} is missing {len(missing_indexes)} indexes defined in local config:")
            for idx in missing_indexes:
                print(f"   - Collection: {idx['collectionGroup']}, Fields: {idx['fields']}")
            all_passed = False
        else:
            print(f"✅ Environment {env} has all required indexes.")

    if not all_passed:
        print("\n❌ Index validation failed. Please deploy indexes to all environments using:")
        print("   firebase deploy --only firestore:indexes --project <env>")
        sys.exit(1)

    print("🎉 All environments have the correct Firestore indexes deployed.")

if __name__ == "__main__":
    main()
