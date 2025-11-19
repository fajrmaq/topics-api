#!/usr/bin/env bash
set -euo pipefail

# Browse a random half of generated sites using a dedicated Chrome profile (Ubuntu)
# - Creates `chrome-topics-profile-ubuntu` under the demo folder if missing
# - Picks half of the folders in `sites/` (excludes `adtech.test` if present)
# - Launches Chrome with Topics/Privacy Sandbox flags and host resolver rules
# - Waits N seconds (default 30) then closes the browser

ROOT="$(cd "$(dirname "$0")" && pwd)"
SITES_DIR="$ROOT/sites"
PROFILE_DIR="$ROOT/chrome-topics-profile-ubuntu"
PORT=${PORT:-8080}
DWELL=${DWELL:-30}
RD_PORT=${RD_PORT:-9222}

if [ ! -d "$SITES_DIR" ]; then
  echo "No sites directory found at: $SITES_DIR" >&2
  exit 1
fi

# Find chrome binary
CHROME_CMD=""
for c in google-chrome-stable google-chrome chromium-browser chromium; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME_CMD=$(command -v "$c")
    break
  fi
done

if [ -z "$CHROME_CMD" ]; then
  echo "Chrome/Chromium not found on PATH (looked for google-chrome, chromium)." >&2
  exit 2
fi

# Build domain list (exclude adtech host copy)
mapfile -t DOMAINS < <(ls -1 "$SITES_DIR" | grep -v '^adtech.test$' || true)
if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "No domains found in $SITES_DIR" >&2
  exit 1
fi

# Pick half randomly
COUNT=${#DOMAINS[@]}
HALF=$(( (COUNT + 1) / 2 ))
SHUFFLED=( $(printf "%s\n" "${DOMAINS[@]}" | shuf) )
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

# Require profile dir to exist (create with create_chrome_profile_ubuntu.sh)
# Ensure profile dir exists (Chrome will initialize it on first run)
mkdir -p "$PROFILE_DIR"

FLAGS=(
  "--enable-features=BrowsingTopics,BrowsingTopicsParameters:time_period_per_epoch/60s,max_epoch_introduction_delay/3s,PrivacySandboxAdsAPIsOverride,PrivacySandboxSettings3,OverridePrivacySandboxSettingsLocalTesting,BrowsingTopicsBypassIPIsPubliclyRoutableCheck,BrowsingTopicsBypassIPIsPubliclyRoutableCheck"
  "--privacy-sandbox-enrollment-overrides=$ENROLL"
  "--host-resolver-rules=$HRULES"
  "--user-data-dir=$PROFILE_DIR"
)

# Build URL list to open in tabs
URLS=()
for d in "${SELECTED[@]}"; do
  URLS+=("https://$d:$PORT/")
done

# Always open topics internals in its own tab/window and keep it open
URLS=("chrome://topics-internals/" "${URLS[@]}")

echo "Launching Chrome ($CHROME_CMD) with profile: $PROFILE_DIR"
"$CHROME_CMD" "${FLAGS[@]}" "${URLS[@]}" &
CHROME_PID=$!

echo "Chrome PID: $CHROME_PID — waiting $DWELL seconds..."
sleep "$DWELL"

echo "Closing only the opened site tabs (leaving topics-internals open)..."

# Export selected domains as JSON for the Python helper
SEL_JSON=$(printf '%s\n' "${SELECTED[@]}" | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')

SEL_JSON="$SEL_JSON" PORT="$PORT" RD_PORT="$RD_PORT" python3 - <<'PY'
import os, sys, json, urllib.request
try:
    selected = set(json.loads(os.environ['SEL_JSON']))
except Exception as e:
    print('Bad SEL_JSON', e, file=sys.stderr); sys.exit(0)
PORT = int(os.environ.get('PORT','8080'))
RD = int(os.environ.get('RD_PORT','9222'))
host = f'http://127.0.0.1:{RD}'
try:
    data = urllib.request.urlopen(host + '/json').read()
    tabs = json.loads(data)
except Exception as e:
    print('Failed to query DevTools endpoint:', e, file=sys.stderr)
    sys.exit(0)

to_close = []
for t in tabs:
  url = t.get('url','')
  for d in selected:
    prefix = f'https://{d}:{PORT}/'
    if url.startswith(prefix):
      to_close.append(t.get('id'))
      break

for tid in to_close:
    try:
        urllib.request.urlopen(host + '/json/close/' + tid)
        print('Closed tab', tid)
    except Exception as e:
        print('Failed to close', tid, e, file=sys.stderr)
PY

echo "Done."
