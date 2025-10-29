import http.server
import ssl
from http.server import ThreadingHTTPServer

PORT = 8000

handler = http.server.SimpleHTTPRequestHandler
httpd = ThreadingHTTPServer(("0.0.0.0", PORT), handler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(certfile="sports.test+5.pem", keyfile="sports.test+5-key.pem")
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print(
    f"""
Serving HTTPS on:
  https://news.test:{PORT}/news-site.html
  https://games.test:{PORT}/games-site.html
  https://sports.test:{PORT}/sports-site.html
  https://cooking.test:{PORT}/cooking-site.html
  https://travel.test:{PORT}/travel-site.html
  https://tennis.test:{PORT}/tennis-site.html
"""
)

httpd.serve_forever()
