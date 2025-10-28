import http.server
import ssl
from http.server import ThreadingHTTPServer

PORT = 8000

handler = http.server.SimpleHTTPRequestHandler
httpd = ThreadingHTTPServer(("0.0.0.0", PORT), handler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(
    certfile="cooking.test+3.pem", keyfile="cooking.test+3-key.pem"
)
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print(
    f"""
Serving HTTPS on:
  https://sports.test:{PORT}/sports-site.html
  https://cooking.test:{PORT}/cooking-site.html
  https://travel.test:{PORT}/travel-site.html
  https://tennis.test:{PORT}/test-site.html
"""
)

httpd.serve_forever()