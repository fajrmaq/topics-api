# final-demo


This folder contains an automated setup for the Topics API demo sites.

Files added:
- `setup_sites.py`: Creates `sites/<domain>/index.html` for every domain listed in `intersecting_48_topics_sites.json`, generates a single SAN certificate for all domains using `mkcert`, and can manage a marked `/etc/hosts` block for easy removal later.
- `https_server.py`: Serves content from `sites/` and selects the site to serve from the request `Host:` header. If a certificate/key pair (`cert-*.pem`/`*-key.pem`) exists, the server will use TLS.

Quick start

- **Install mkcert**: install `mkcert` and add the local CA to your trust store (only needed once):

```bash
# final-demo

Concise setup instructions for the local Topics API demo.

Requirements
- Python 3
- `mkcert` (optional, required for TLS and to make the pages accessible via real hostnames)

1) Generate sites and (optionally) certificate

From `final-demo/` run one of:

```bash
# Generate sites, create SAN cert with mkcert and print hosts lines (does NOT install hosts):
python3 setup_sites.py

*** Begin Final-demo README ***

# final-demo

This folder contains an automated setup for the Topics API demo sites.

Files of interest
- `setup_sites.py`: Generates `sites/<domain>/index.html` for every domain in `intersecting_48_topics_sites.json`, optionally creates a SAN certificate for all domains using `mkcert`, and manages a small marked block in `/etc/hosts` for easy install/uninstall.
- `https_server.py`: Host-aware server that serves content from `sites/` based on the request `Host:` header. If a certificate/key pair (`*-cert.pem`/`*-key.pem`) exists the server can run in HTTPS mode.
- `adtech.html` (created by `setup_sites.py`): a single, shared advertiser UI served from the repo root at `/adtech.html`.
- `witness.js` (created by `setup_sites.py`): helper imported by the shared `adtech.html`.

Quick start

Requirements
- Python 3
- `mkcert` (optional — required only if you want real HTTPS and trusted local hostnames)

1) Generate sites and (optionally) certificate

From `final-demo/` run one of:

```bash
# Generate sites, create SAN cert with mkcert and print hosts lines (does NOT install hosts):
python3 setup_sites.py

#!/usr/bin/env bash

# final-demo README

This folder contains an automated setup for the Topics API demo sites.

Files of interest
- `setup_sites.py`: Generates `sites/<domain>/index.html` for every domain in `intersecting_48_topics_sites.json`, optionally creates a SAN certificate for all domains using `mkcert`, and manages a small marked block in `/etc/hosts` for easy install/uninstall.
- `https_server.py`: Host-aware server that serves content from `sites/` based on the request `Host:` header. If a certificate/key pair (`*-cert.pem`/`*-key.pem`) exists the server can run in HTTPS mode.
- `adtech.html` (created by `setup_sites.py`): a single, shared advertiser UI served from the repo root at `/adtech.html`.
- `witness.js` (created by `setup_sites.py`): helper imported by the shared `adtech.html`.

Quick start

Requirements
- Python 3
- `mkcert` (optional — required only if you want real HTTPS and trusted local hostnames)

1) Generate sites and (optionally) certificate

From `final-demo/` run one of:

```bash
# Generate sites, create SAN cert with mkcert and print hosts lines (does NOT install hosts):
python3 setup_sites.py

# Skip creating a certificate (useful if mkcert is not installed):
python3 setup_sites.py --no-cert

# Run mkcert -install first and then generate certs (requires mkcert available):
python3 setup_sites.py --mkcert-install
```


Notes:
- Default `PORT` is `8080`. If you change it, set the same `PORT` when generating and when starting the server: `PORT=8443 python3 setup_sites.py` and `PORT=8443 python3 https_server.py`.
- Setup now creates a single shared advertiser page at `final-demo/adtech.html` and a shared `final-demo/witness.js`. All generated publisher pages embed the advertiser as `/adtech.html` so a single ad page is used for every site.

2) Install hostnames (optional — makes browsing in Chrome simpler)

```bash
# Add a managed block to /etc/hosts (may prompt for sudo)
python3 setup_sites.py --hosts install

# Remove the managed block
python3 setup_sites.py --hosts remove

# Show the managed block without changing /etc/hosts
python3 setup_sites.py --hosts show
```

3) Start the host-aware server

```bash
cd final-demo
# default port 8080
PORT=8080 python3 https_server.py
```

4) Verify access

- If you installed hosts and created the mkcert cert, open any generated publisher origin in your browser (the publisher page will embed the shared ad UI at `/adtech.html`):
  `https://<one-of-the-generated-hostnames>:8080/` and `https://<one-of-the-generated-hostnames>:8080/adtech.html`

- If you did not modify `/etc/hosts`, use `curl --resolve` to test a publisher origin without system changes. Example (replace hostname):
```bash
curl -vk --resolve 1xbet-nez.top:8080:127.0.0.1 https://1xbet-nez.top:8080/
```

Important notes
- The Topics API (and `document.browsingTopics()`) requires a secure context. Publishers that call `document.browsingTopics()` must be served over HTTPS (or a secure context). The shared advertiser page (`/adtech.html`) itself does not need to run under HTTPS because it receives topics via `postMessage` from the publisher iframe — however the publisher origin providing topics must be secure.
- `--no-cert` is useful when you want to skip mkcert and test using `curl --resolve` or the scripts' `--host-resolver-rules` chrome flag.

Useful options
- `--no-cert` : generate sites but skip mkcert certificate creation.
- `--mkcert-install` : run `mkcert -install` before generating certs.
- `--adhost NAME` : legacy; not required. Setup generates a shared `/adtech.html` by default.
- `--cert-name NAME` : change certificate base name (creates `NAME-cert.pem` and `NAME-key.pem`).

Cleanup

```bash
# Remove generated sites
rm -rf final-demo/sites

# Remove generated certs (adjust names if you used --cert-name)
rm final-demo/*-cert.pem final-demo/*-key.pem
```

Automated browsing scripts

Two helper scripts are provided to simulate browsing half the generated sites using a dedicated Chrome profile.

- `browse_random_ubuntu.sh` — for Linux (Chrome/Chromium on PATH)
- `browse_random_macos.sh` — for macOS (uses the standard `/Applications/Google Chrome` path)

Usage (from `final-demo/`):

```bash
# pick half the sites at random, open them in a new profile, wait (default 30s), then close
./browse_random_ubuntu.sh

# macOS version
./browse_random_macos.sh
```

Environment variables:
- `PORT` — port the local server is running on (default `8080`). Must match the `PORT` used when generating pages and when starting `https_server.py`.
- `DWELL` — how many seconds to keep Chrome open before closing (default `30`).

Notes:
- The scripts create a local profile directory (`chrome-topics-profile-ubuntu` or `chrome-topics-profile-mac`) inside `final-demo/` if it does not exist.
- The scripts add the Topics/Privacy Sandbox flags and use `--host-resolver-rules` so you do not need to edit `/etc/hosts` (they map the selected sites to `127.0.0.1`).
- The scripts will attempt to find Chrome/Chromium; if Chrome is not found, install it or run with the `--hosts install` option and open sites manually in your browser.

### Useful:
```bash
chrome://flags/
chrome://topics-internals/
https://127.0.0.1:8080/
https://127.0.0.1:8080/adtech.html
https://1xbet-nez.top:8080/
```