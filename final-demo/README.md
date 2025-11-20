# final-demo

Automated setup for running the Topics API demo sites locally.

## Key files
- `setup_sites.py` – Generates `sites/<domain>/index.html` from `intersecting_48_topics_sites.json`, optionally creates an mkcert SAN certificate, and manages a marked `/etc/hosts` block.
- `https_server.py` – Host-aware server that serves from `sites/` and uses TLS automatically when matching `*-cert.pem`/`*-key.pem` files exist.
- `adtech.html` & `witness.js` – Shared advertiser UI and helper script created by `setup_sites.py` and served from the repo root.
- `browse_random_*.sh` – Convenience scripts that open a random subset of publisher sites in a dedicated Chrome profile.

## Requirements
- Python 3
- `mkcert` (optional, only needed for HTTPS + trusted hostnames)

## Setup
From `final-demo/`:

```bash
# Generate sites, create a SAN cert, and print hosts entries (does not modify /etc/hosts)
python3 setup_sites.py

# Skip certificate generation (useful when mkcert is unavailable)
python3 setup_sites.py --no-cert

# Run mkcert -install before creating the SAN cert
python3 setup_sites.py --mkcert-install
```

Port configuration: default `PORT` is `8080`. Use the same value when generating sites and when starting the server (`PORT=8443 python3 setup_sites.py`, then `PORT=8443 python3 https_server.py`).

### Hostnames (optional)
```bash
# Add/remove/show the managed block in /etc/hosts (may prompt for sudo)
python3 setup_sites.py --hosts install|remove|show
```

### Start the server
```bash
PORT=8080 python3 https_server.py
```

### Verify access
- With `/etc/hosts` + mkcert: open `https://<generated-hostname>:8080/` and `https://<generated-hostname>:8080/adtech.html`.
- Without modifying `/etc/hosts`: `curl -vk --resolve 1xbet-nez.top:8080:127.0.0.1 https://1xbet-nez.top:8080/` (replace hostname as needed).

## Important notes
- The Topics API requires a secure context; publisher pages must be served via HTTPS (mkcert or another trusted cert). The shared advertiser UI receives topics via `postMessage` and may be served over HTTP, but the publisher iframe providing topics must be secure.
- `--no-cert` works when using `curl --resolve` or the automated browsing scripts (they map hostnames to `127.0.0.1` via `--host-resolver-rules`).

## Automated browsing scripts
```bash
# Linux
./browse_random_ubuntu.sh
# macOS
./browse_random_macos.sh
```

Environment variables: `PORT` (matches server/generation port, default `8080`) and `DWELL` (seconds to keep Chrome open, default `4`). The scripts create `chrome-topics-profile-*` directories, enable the Privacy Sandbox flags, and do not require `/etc/hosts`.

## Cleanup
```bash
rm -rf final-demo/sites
rm final-demo/*-cert.pem final-demo/*-key.pem   # adjust names if using --cert-name
```

## Demo
```
https://0003.co.jp:8080/
chrome://topics-internals/
```
