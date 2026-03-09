"""Module verify_functions_sync.py."""
import os
import subprocess
import sys
import ast
import json

def get_local_functions():
    """Extract the list of exported functions from functions/main.py __all__."""
    main_path = os.path.join("functions", "main.py")
    if not os.path.exists(main_path):
        print(f"❌ Error: {main_path} not found.")
        return set()

    try:
        with open(main_path, "r") as f:
            tree = ast.parse(f.read())
        
        for node in tree.body:
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        if isinstance(node.value, ast.List):
                            # In AST, a List node has an 'elts' attribute containing the elements
                            return set(elt.value for elt in node.value.elts if isinstance(elt, ast.Constant))
    except Exception as e:
        print(f"❌ Error parsing {main_path}: {e}")
    
    return set()

def get_deployed_functions(project_id):
    """Get the list of deployed functions for a given Firebase project using JSON output."""
    print(f"🔍 Fetching deployed functions for project: {project_id}...")
    try:
        # Use --json for reliable parsing
        result = subprocess.run(
            ["firebase", "functions:list", "--project", project_id, "--json"],
            capture_output=True,
            text=True,
            check=True
        )
        
        data = json.loads(result.stdout)
        if data.get("status") == "success":
            functions = set()
            for func in data.get("result", []):
                # The 'id' field contains the function name
                func_id = func.get("id")
                if func_id:
                    functions.add(func_id)
            return functions
        else:
            print(f"⚠️ Warning: Firebase CLI reported failure for {project_id}: {data.get('error')}")
            return None
            
    except subprocess.CalledProcessError as e:
        # Try to parse error if it's JSON
        try:
            err_data = json.loads(e.stdout)
            print(f"⚠️ Warning: Failed to fetch functions for {project_id}: {err_data.get('error')}")
        except:
            print(f"⚠️ Warning: Failed to fetch functions for {project_id}: {e.stderr or e.stdout}")
        return None
    except Exception as e:
        print(f"⚠️ Warning: An error occurred for {project_id}: {e}")
        return None

def verify_sync():
    """Function verify_sync."""
    local_funcs = get_local_functions()
    if not local_funcs:
        print("❌ Could not find any local functions in functions/main.py")
        return False

    print(f"✅ Found {len(local_funcs)} functions defined locally in functions/main.py")

    projects = {
        "dev": "orignagta-dev",
        "staging": "orignagta-staging",
        "prod": "orignagta"
    }

    overall_success = True

    for env, project_id in projects.items():
        deployed_funcs = get_deployed_functions(project_id)
        if deployed_funcs is None:
            # Skip if we couldn't fetch (maybe not logged in or network issue)
            # We don't want to block the push if we just can't reach the server
            print(f"⏭️ Skipping {env} environment check due to fetch failure.")
            continue

        missing_in_deploy = local_funcs - deployed_funcs
        extra_in_deploy = deployed_funcs - local_funcs

        if not missing_in_deploy and not extra_in_deploy:
            print(f"✅ {env.upper()} ({project_id}) is perfectly in sync.")
        else:
            # We only fail if there are functions in repo that are NOT deployed
            # Having extra functions in deployment might be okay (old ones not yet cleaned up)
            # but usually we want exact match.
            if missing_in_deploy:
                overall_success = False
                print(f"❌ {env.upper()} ({project_id}) IS MISSING FUNCTIONS!")
                print("   The following functions are in the repo but NOT deployed:")
                for f in sorted(missing_in_deploy):
                    print(f"     - {f}")
            
            if extra_in_deploy:
                # Warning only for extra functions
                print(f"⚠️ {env.upper()} ({project_id}) has extra deployed functions not in repo:")
                for f in sorted(extra_in_deploy):
                    print(f"     - {f}")
        print("-" * 40)

    return overall_success

if __name__ == "__main__":
    success = verify_sync()
    if not success:
        print("❌ Verification failed. Please deploy missing functions before pushing.")
        sys.exit(1)
    else:
        print("✅ Cloud Functions sync verification passed.")
        sys.exit(0)
