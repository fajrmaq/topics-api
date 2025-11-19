#!/usr/bin/env python3
import os
import ssl
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

PORT = int(os.environ.get("PORT", "8080"))
ROOT = os.path.dirname(__file__)
CERT = os.path.join(ROOT, "cert-cert.pem")
KEY = os.path.join(ROOT, "cert-key.pem")


class HostBasedHTTPRequestHandler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        # Map Host header to a subdirectory under ./sites
        host = self.headers.get("Host", "").split(":")[0]
        if not host:
            host = "localhost"
        site_root = os.path.join(ROOT, "sites", host)
        if not os.path.isdir(site_root):
            # Fallback to sites/default or serve a basic index
            site_root = os.path.join(ROOT, "sites")

        # Remove query params and fragment
        path = path.split("?", 1)[0].split("#", 1)[0]
        # Prevent directory traversal
        path = path.lstrip("/")
        # If a site requests its per-site adtech frame file, allow mapping
        # to a single global `adtech.html` in the repo root to avoid
        # regenerating all index files. This keeps the adtech shared.
        if os.path.basename(path) == "adtech-frame.html":
            global_ad = os.path.join(ROOT, "adtech.html")
            if os.path.exists(global_ad):
                return global_ad
        full_path = os.path.join(site_root, *path.split("/"))
        # If the resource exists under the site folder, serve it (including index files)
        if os.path.isdir(full_path):
            for index in ("index.html", "index.htm"):
                index_path = os.path.join(full_path, index)
                if os.path.exists(index_path):
                    return index_path
        if os.path.exists(full_path):
            return full_path

        # If not found under the site folder, allow serving a file from the repo root
        # (useful for a single global `adtech.html` at the repo root).
        root_candidate = os.path.join(ROOT, *path.split("/"))
        if os.path.isdir(root_candidate):
            for index in ("index.html", "index.htm"):
                index_path = os.path.join(root_candidate, index)
                if os.path.exists(index_path):
                    return index_path
        if os.path.exists(root_candidate):
            return root_candidate

        return full_path

    def do_POST(self):
        # Accept adtech witness events at /__adtech_witness
        if self.path.split('?', 1)[0] == '/__adtech_witness':
            length = int(self.headers.get('Content-Length', '0'))
            try:
                body = self.rfile.read(length) if length else b''
                text = body.decode('utf-8') if body else ''
                # Append as a JSON line to a file in the repo root
                out = os.path.join(os.path.dirname(__file__), '.adtech_witness.jsonl')
                with open(out, 'a', encoding='utf-8') as f:
                    f.write(text + "\n")
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"ok":true}')
            except Exception:
                self.send_response(500)
                self.end_headers()
            return


def main():
    handler = HostBasedHTTPRequestHandler
    httpd = ThreadingHTTPServer(("0.0.0.0", PORT), handler)

    if os.path.exists(CERT) and os.path.exists(KEY):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=CERT, keyfile=KEY)
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
        proto = "HTTPS"
    else:
        proto = "HTTP"

    print(f"Serving {proto} on 0.0.0.0:{PORT}")
    sites_dir = os.path.join(ROOT, "sites")
    scheme = "https" if proto == "HTTPS" else "http"

    if proto == "HTTPS":
        print(f"Using TLS cert: {CERT}")
        print(f"Using TLS key : {KEY}")
    else:
        print("No TLS certificate found; serving over HTTP")

    if os.path.isdir(sites_dir):
        print("\nSites available (add to /etc/hosts pointing to 127.0.0.1):")
        for name in sorted(os.listdir(sites_dir)):
            path = os.path.join(sites_dir, name)
            if os.path.isdir(path):
                print(f"  {scheme}://{name}:{PORT}/ -> {path}")

        print("\nExample curl (without editing /etc/hosts):")
        print(f"  curl -vk --resolve <hostname>:{PORT}:127.0.0.1 {scheme}://<hostname>:{PORT}/")
        print("\nTo make the hostnames resolvable system-wide, add the printed lines to /etc/hosts or use the provided setup script.")
    else:
        print("No sites directory found at:", sites_dir)

    httpd.serve_forever()


if __name__ == "__main__":
    main()
