"""Module test_diff.py."""
import json
import subprocess
import urllib.request
import ssl

def main():
    """Function main."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    token = subprocess.run(['gcloud', 'auth', 'print-access-token'], capture_output=True, text=True, check=True).stdout.strip()
    
    headers = {"Authorization": f"Bearer {token}", "x-goog-user-project": "orignagta-dev"}
    req = urllib.request.Request("https://firebaserules.googleapis.com/v1/projects/orignagta-dev/releases", headers=headers)
    releases = json.loads(urllib.request.urlopen(req, context=ctx).read().decode())
    
    rname = [r for r in releases['releases'] if r.get('name').endswith('cloud.firestore')][0]['rulesetName']
    
    req = urllib.request.Request(f"https://firebaserules.googleapis.com/v1/{rname}", headers=headers)
    ruleset = json.loads(urllib.request.urlopen(req, context=ctx).read().decode())
    
    deployed = ruleset['source']['files'][0]['content']
    with open('firestore.rules') as f:
        local = f.read()
        
    def norm(t):
        """Function norm."""
        return '\n'.join([l.rstrip() for l in t.strip().splitlines()])
    
    import difflib
    for line in difflib.unified_diff(norm(local).splitlines(), norm(deployed).splitlines()):
        print(line)

main()
