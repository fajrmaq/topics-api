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
DWELL=${DWELL:-60}
RD_PORT=${RD_PORT:-9222}

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
  "--enable-features=BrowsingTopics,BrowsingTopicsParameters:time_period_per_epoch/60s,max_epoch_introduction_delay/3s,PrivacySandboxAdsAPIsOverride,PrivacySandboxSettings3,OverridePrivacySandboxSettingsLocalTesting,BrowsingTopicsBypassIPIsPubliclyRoutableCheck,BrowsingTopicsBypassIPIsPubliclyRoutableCheck"
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
URLS=("chrome://topics-internals/" "${URLS[@]}")

echo "Launching Chrome ($CHROME_CMD) with profile: $PROFILE_DIR"
"$CHROME_CMD" "${FLAGS[@]}" "${URLS[@]}" &
CHROME_PID=$!

echo "Chrome PID: $CHROME_PID — waiting $DWELL seconds..."
sleep "$DWELL"

echo "Closing only the opened site tabs (leaving topics-internals open)..."

# Export selected domains as JSON for the Python helper
SEL_JSON=$(printf '%s\n' "${SELECTED[@]}" | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')

WITNESS_FILE="$ROOT/.adtech_witness.jsonl"
SEL_JSON="$SEL_JSON" PORT="$PORT" RD_PORT="$RD_PORT" WITNESS_FILE="$WITNESS_FILE" python3 - <<'PY'
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
      # Before closing, check whether the adtech reported any topics for this origin.
      witness_file = os.environ.get('WITNESS_FILE')
      keep_open = False
      if witness_file and os.path.exists(witness_file):
        try:
          with open(witness_file, 'r', encoding='utf-8') as f:
            lines = [l.strip() for l in f if l.strip()]
          for ln in reversed(lines):
            try:
              rec = json.loads(ln)
              origin = rec.get('origin') or rec.get('hostname')
              topics = rec.get('topics') or []
              # If this witness entry matches one of the selected domains
              # and had a non-empty topics array, keep the tab open.
              for d in selected:
                if origin == d and isinstance(topics, list) and len(topics) > 0:
                  keep_open = True
                  break
              if keep_open:
                break
            except Exception:
              continue
        except Exception:
          pass
      if keep_open:
        print('Keeping tab open (adtech observed topics):', tid)
      else:
        urllib.request.urlopen(host + '/json/close/' + tid)
        print('Closed tab', tid)
    except Exception as e:
      print('Failed to close', tid, e, file=sys.stderr)
PY

echo "Done."
