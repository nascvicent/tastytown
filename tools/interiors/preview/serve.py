"""Servidor do preview de interiores.

Serve a pasta do preview e aceita POST /snapshot?name=<nome> com um PNG,
salvo em tools/interiors/preview/snapshots/ (ignorado pelo git).

    python tools/interiors/preview/serve.py 8765
"""
import http.server
import os
import re
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.abspath(__file__))
SNAPSHOTS = os.path.join(ROOT, "snapshots")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # Sem cache: o scene.js muda a cada build
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        if url.path != "/snapshot":
            self.send_error(404)
            return
        name = urllib.parse.parse_qs(url.query).get("name", ["snapshot"])[0]
        name = re.sub(r"[^A-Za-z0-9_-]", "_", name)[:60] or "snapshot"
        length = int(self.headers.get("Content-Length", 0))
        data = self.rfile.read(length)
        os.makedirs(SNAPSHOTS, exist_ok=True)
        path = os.path.join(SNAPSHOTS, name + ".png")
        with open(path, "wb") as f:
            f.write(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(path.encode())


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
