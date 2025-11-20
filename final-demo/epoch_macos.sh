#!/usr/bin/env bash
set -euo pipefail

# Browse a random half of generated sites using a dedicated Chrome profile (macOS)
# - Creates `chrome-topics-profile-mac` under the demo folder if missing
# - Picks half of the folders in `sites/` (excludes `adtech.test` if present)
# - Launches Google Chrome with Topics/Privacy Sandbox flags and host resolver rules
# - Waits N seconds (default 30) then closes the browser

ROOT="$(cd "$(dirname "$0")" && pwd)"
SITES_DIR="$ROOT/sites"
PROFILE_DIR="$ROOT/chrome-topics-profile-mac"
PORT=${PORT:-8080}
DWELL=${DWELL:-4}
RD_PORT=${RD_PORT:-9222}
WITNESS_FILE="$ROOT/.adtech_witness.jsonl"
if [ -f "$WITNESS_FILE" ]; then
  WITNESS_OFFSET=$(stat -f%z "$WITNESS_FILE")
else
  WITNESS_OFFSET=0
fi

if [ ! -d "$SITES_DIR" ]; then
  echo "No sites directory found at: $SITES_DIR" >&2
  exit 1
fi

CHROME_CMD="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ ! -x "$CHROME_CMD" ]; then
  echo "Google Chrome binary not found at $CHROME_CMD" >&2
  exit 2
fi

# Build domain list (exclude adtech host copy)
# `mapfile` / `readarray` are Bash 4+; macOS ships an older Bash where
# `mapfile` isn't available. Use a portable read-loop to populate the array.
DOMAINS=()
while IFS= read -r domain; do
  if [ -n "$domain" ]; then
    DOMAINS[${#DOMAINS[@]}]="$domain"
  fi
done < <(ls -1 "$SITES_DIR" | grep -v '^adtech.test$' || true)
if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "No domains found in $SITES_DIR" >&2
  exit 1
fi

# Pick half randomly
COUNT=${#DOMAINS[@]}
HALF=$(( (COUNT + 1) / 2 ))
# `shuf` (GNU coreutils) may not be available on macOS by default.
# Use Python to shuffle the list in a portable way.
SHUFFLED=( $(printf "%s\n" "${DOMAINS[@]}" | python3 -c 'import sys,random; a=[l.strip() for l in sys.stdin if l.strip()]; random.shuffle(a); print("\n".join(a))') )
SELECTED=("${SHUFFLED[@]:0:HALF}")

echo "Selected $HALF / $COUNT sites to browse:"
printf '  %s\n' "${SELECTED[@]}"

# Build enrollment overrides and host-resolver rules
ENROLL=""
HRULES=""
for d in "${SELECTED[@]}"; do
  url="https://$d:$PORT"
  if [ -z "$ENROLL" ]; then
    ENROLL="$url"
  else
    ENROLL="$ENROLL,$url"
  fi
  if [ -z "$HRULES" ]; then
    HRULES="MAP $d 127.0.0.1"
  else
    HRULES="$HRULES,MAP $d 127.0.0.1"
  fi
done

# Require profile dir to exist (create with create_chrome_profile_macos.sh)
# Ensure profile dir exists (Chrome will initialize it on first run)
mkdir -p "$PROFILE_DIR"

FLAGS=(
  "--enable-features=BrowsingTopics,BrowsingTopicsParameters:time_period_per_epoch/180s,max_epoch_introduction_delay/3s,PrivacySandboxAdsAPIsOverride,PrivacySandboxSettings3,OverridePrivacySandboxSettingsLocalTesting,BrowsingTopicsBypassIPIsPubliclyRoutableCheck,BrowsingTopicsBypassIPIsPubliclyRoutableCheck"
  "--privacy-sandbox-enrollment-overrides=$ENROLL"
  "--host-resolver-rules=$HRULES"
  "--user-data-dir=$PROFILE_DIR"
  # Expose the DevTools remote debugging endpoint so the helper can close tabs.
  "--remote-debugging-port=$RD_PORT"
  # Avoid first-run UI and default-browser prompts when opening a fresh profile.
  "--no-first-run"
  "--no-default-browser-check"
)

# Build URL list to open in tabs
URLS=()
for d in "${SELECTED[@]}"; do
  URLS+=("https://$d:$PORT/")
done

# Always open topics internals in its own tab/window and keep it open
TOPICS_INTERNALS_URL="chrome://topics-internals/"
URLS=("$TOPICS_INTERNALS_URL" "${URLS[@]}")

echo "Launching Chrome ($CHROME_CMD) with profile: $PROFILE_DIR"
"$CHROME_CMD" "${FLAGS[@]}" "${URLS[@]}" &
CHROME_PID=$!

echo "Ensuring chrome://topics-internals/ tab is open..."
TOPICS_INTERNALS_URL="$TOPICS_INTERNALS_URL" RD_PORT="$RD_PORT" python3 - <<'PY'
import os, sys, json, time, urllib.request, urllib.parse
target = os.environ.get('TOPICS_INTERNALS_URL', '').strip()
if not target:
    sys.exit(0)
target_norm = target.lower()
host = f"http://127.0.0.1:{int(os.environ.get('RD_PORT','9222'))}"
encoded = urllib.parse.quote(target, safe=':/?=&')
for _ in range(60):
    try:
        data = urllib.request.urlopen(host + '/json', timeout=1).read()
        tabs = json.loads(data)
    except Exception:
        time.sleep(0.25)
        continue
    if any(tab.get('url','').strip().lower() == target_norm for tab in tabs):
        print('Topics internals tab already open.')
        break
    try:
        urllib.request.urlopen(f"{host}/json/new?{encoded}")
        print('Opened topics internals tab.')
        break
    except Exception:
        time.sleep(0.25)
else:
    print('Warning: could not ensure topics internals tab is open', file=sys.stderr)
PY

echo "Chrome PID: $CHROME_PID — waiting $DWELL seconds..."
sleep "$DWELL"

echo "Closing tabs that did not produce Topics observations..."

# Export selected domains as JSON for the Python helper
SEL_JSON=$(printf '%s\n' "${SELECTED[@]}" | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')

SEL_JSON="$SEL_JSON" PORT="$PORT" RD_PORT="$RD_PORT" \
WITNESS_FILE="$WITNESS_FILE" WITNESS_OFFSET="$WITNESS_OFFSET" \
TOPICS_INTERNALS_URL="$TOPICS_INTERNALS_URL" python3 - <<'PY'
import os, sys, json, urllib.request, urllib.parse
try:
    selected = {d.lower() for d in json.loads(os.environ['SEL_JSON'])}
except Exception as e:
    print('Bad SEL_JSON', e, file=sys.stderr); sys.exit(0)
PORT = int(os.environ.get('PORT','8080'))
RD = int(os.environ.get('RD_PORT','9222'))
host = f'http://127.0.0.1:{RD}'
topics_tab_url = os.environ.get('TOPICS_INTERNALS_URL','').strip().lower()
try:
    data = urllib.request.urlopen(host + '/json').read()
    tabs = json.loads(data)
except Exception as e:
    print('Failed to query DevTools endpoint:', e, file=sys.stderr)
    sys.exit(0)

witness_file = os.environ.get('WITNESS_FILE')
offset = int(os.environ.get('WITNESS_OFFSET','0'))
keep_domains = set()
if witness_file and os.path.exists(witness_file):
    try:
        with open(witness_file, 'r', encoding='utf-8') as f:
            if offset:
                f.seek(offset)
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                origin = rec.get('origin') or rec.get('hostname')
                topics = rec.get('topics') or []
                if origin and isinstance(topics, list) and topics:
                    origin_norm = origin.strip().lower()
                    if origin_norm in selected:
                        keep_domains.add(origin_norm)
    except Exception as e:
        print('Failed to read witness file:', e, file=sys.stderr)

print('Domains with new Topics observations:', ", ".join(sorted(keep_domains)) or "none")

for tab in tabs:
    tab_id = tab.get('id')
    url = tab.get('url','')
    url_norm = url.strip().lower()
    if topics_tab_url and url_norm == topics_tab_url:
        print('Keeping topics internals tab open:', url)
        continue
    parsed = urllib.parse.urlparse(url)
    hostname = (parsed.hostname or '').lower()
    if hostname in keep_domains:
        print('Keeping tab (topics observed):', url)
        continue
    if not tab_id:
        continue
    try:
        urllib.request.urlopen(host + '/json/close/' + tab_id)
        print('Closed tab', url)
    except Exception as e:
        print('Failed to close', tab_id, e, file=sys.stderr)
PY

echo "Done."
