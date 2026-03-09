#!/bin/bash
# Fast Stripe Webhook Audit (~3s) — curl parallel + single python parse
# Compares: Code handlers vs Test dashboard vs Production dashboard
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDLER="$DIR/functions/handlers/payment_stripe.py"
ENV_FILE="$DIR/functions/.env"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# 1) Code events (instant)
CODE=$(grep "event_type ==" "$HANDLER" | sed "s/.*event_type == '//;s/'.*//" | sort)

# 2) Fetch test + live in parallel via curl
TEST_KEY=$(grep "^STRIPE_SECRET_KEY=" "$ENV_FILE" | cut -d'=' -f2)
curl -sf "https://api.stripe.com/v1/webhook_endpoints" -u REDACTED_SECRET -o "$TMP/test.json" &

LIVE_SK=""
if command -v gcloud &>/dev/null; then
    LIVE_SK=$(gcloud secrets versions access latest --secret="STRIPE_SECRET_KEY" --project="orignagta" 2>/dev/null || true)
fi
if [ -n "$LIVE_SK" ]; then
    curl -sf "https://api.stripe.com/v1/webhook_endpoints" -u REDACTED_SECRET -o "$TMP/live.json" &
else
    echo '{"data":[]}' > "$TMP/live.json"
fi
wait

# 3) One python call does all comparison + output
python3 << 'PY' - "$TMP/test.json" "$TMP/live.json" "$CODE"
import sys, json, os

_, test_path, live_path, code_raw = sys.argv[0], sys.argv[1], sys.argv[2], sys.argv[3]
code_events = sorted(set(code_raw.strip().split('\n')))

G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[1m'; C='\033[36m'; N='\033[0m'
EXPECTED="https://us-central1-orignagta.cloudfunctions.net/stripe_webhook"

def load(p):
    try:
        with open(p) as f: d = json.load(f)
        if d.get('data'):
            e=d['data'][0]; return sorted(e.get('enabled_events',[])),e.get('url','?'),e.get('api_version','?'),e.get('status','?'),e.get('id','?')
    except: pass
    return [],'?','?','?','?'

te,tu,ta,ts,ti = load(test_path)
le,lu,la,ls,li = load(live_path)

print(f"\n{B}{C}══ Stripe Webhook Audit ══════════════════════════════{N}")
print(f"  Code: {len(code_events)} handlers | Test: {len(te)} events ({ti}) | Live: {len(le)} events ({li})")
print(f"\n  {B}{'Event':<44} Code  Test  Live{N}")
print(f"  {'─'*44} ───── ───── ─────")

diff=False
for ev in sorted(set(code_events+te+le)):
    c,t,l = ev in code_events, ev in te, ev in le
    if not(c==t==l): diff=True
    m=lambda v: f"{G}✓{N}" if v else f"{R}✗{N}"
    w="" if c==t==l else f"  {R}⚠{N}"
    print(f"  {ev:<44}  {m(c)}     {m(t)}     {m(l)}{w}")

print(f"\n  {B}URLs:{N}")
for n,u in [("Test",tu),("Live",lu)]:
    if u==EXPECTED: print(f"    {n}: {G}✓{N}")
    elif u=='?': print(f"    {n}: {Y}n/a{N}")
    else: print(f"    {n}: {R}✗ {u}{N}"); diff=True

if ta==la and ta!='?': print(f"  {B}API:{N} {G}✓{N} {ta}")
elif la=='?': print(f"  {B}API:{N} test={ta}")
else: print(f"  {B}API:{N} {R}✗{N} test={ta} live={la}"); diff=True

for n,s in [("Test",ts),("Live",ls)]:
    if s=='enabled': print(f"  {B}{n}:{N} {G}✓ enabled{N}")
    elif s=='?': pass
    else: print(f"  {B}{n}:{N} {R}✗ {s}{N}")

print(f"\n{B}{'═'*55}{N}")
if diff: print(f"  {R}{B}✗ AUDIT FAILED — discrepancies found{N}")
else: print(f"  {G}{B}✓ AUDIT PASSED — Code, Test & Live in sync{N}")
print(f"{B}{'═'*55}{N}\n")
PY
