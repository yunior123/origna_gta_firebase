#!/usr/bin/env bash
set -e

# Start the widget previewer and immediately patch the scaffold HTML
# Record start time so we only match scaffolds created in THIS run (not stale ones)
TIMESTAMP=$(mktemp /tmp/.preview-start-XXXX)

flutter widget-preview start &
FLUTTER_PID=$!

# Wait for scaffold to be generated (poll for the HTML file)
# macOS uses /var/folders, not /tmp — poll up to 120s
# -newer $TIMESTAMP ensures we skip scaffolds from previous runs
SCAFFOLD_HTML=""
TMPBASE=$(dirname $(mktemp -u))
for i in $(seq 1 120); do
  SCAFFOLD_HTML=$(find "$TMPBASE" -name "index.html" \
    -path "*/widget_preview_scaffold*/web/*" 2>/dev/null \
    -newer "$TIMESTAMP" | head -1)
  if [ -n "$SCAFFOLD_HTML" ]; then break; fi
  sleep 1
done
rm -f "$TIMESTAMP"

if [ -n "$SCAFFOLD_HTML" ]; then
  python3 - "$SCAFFOLD_HTML" << 'PYEOF'
import sys
path = sys.argv[1]
stub = '''  <!-- PasskeyAuthenticator full stub — all 7 interop.dart methods.
       Prevents passkeys_web plugin from crashing in preview/test mode. -->
  <script>
    if (typeof window.PasskeyAuthenticator === 'undefined') {
      window.PasskeyAuthenticator = {
        init: function() {},
        register: function() { return Promise.reject('passkeys not loaded'); },
        login: function() { return Promise.reject('passkeys not loaded'); },
        cancelCurrentAuthenticatorOperation: function() {},
        isUserVerifyingPlatformAuthenticatorAvailable: function() { return Promise.resolve(false); },
        isConditionalMediationAvailable: function() { return Promise.resolve(false); },
        hasPasskeySupport: function() { return false; }
      };
    }
  </script>
  '''
with open(path) as f:
    content = f.read()
if 'PasskeyAuthenticator' not in content:
    content = content.replace(
        '  <script src="flutter_bootstrap.js" async></script>',
        stub + '  <script src="flutter_bootstrap.js" async></script>'
    )
    with open(path, 'w') as f:
        f.write(content)
    print(f'✓ Patched {path}')
else:
    print('Already patched')
PYEOF
fi

wait $FLUTTER_PID
