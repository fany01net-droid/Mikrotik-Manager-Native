import os
import sys
import ssl
import json
import urllib.request
import urllib.parse
import urllib.error
from http.server import HTTPServer, SimpleHTTPRequestHandler

class RelayHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

    def do_OPTIONS(self):
        # Handle browser CORS preflight
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Max-Age', '86400')
        self.end_headers()

    def do_GET(self):
        if self.path.startswith('/proxy'):
            self._handle_proxy('GET')
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/proxy'):
            self._handle_proxy('POST')
        else:
            self.send_error(404, "Not Found")

    def do_PUT(self):
        if self.path.startswith('/proxy'):
            self._handle_proxy('PUT')
        else:
            self.send_error(404, "Not Found")

    def do_PATCH(self):
        if self.path.startswith('/proxy'):
            self._handle_proxy('PATCH')
        else:
            self.send_error(404, "Not Found")

    def do_DELETE(self):
        if self.path.startswith('/proxy'):
            self._handle_proxy('DELETE')
        else:
            self.send_error(404, "Not Found")

    def _handle_proxy(self, method):
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)
        target_url = qs.get('url', [None])[0]
        if not target_url:
            self.send_response(400)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"error": "Missing target url query parameter"}')
            return

        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        auth_val = self.headers.get('Authorization')
        if auth_val:
            print(f"[AUTH USED] {auth_val}", flush=True)

        req = urllib.request.Request(target_url, data=body, method=method)
        for h in ['Authorization', 'Content-Type', 'Accept']:
            val = self.headers.get(h)
            if val:
                req.add_header(h, val)

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        try:
            with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
                resp_data = resp.read()
                if 'system/resource' in target_url:
                    print(f"[DEBUG RESOURCE] {resp_data.decode('utf-8', errors='ignore')}", flush=True)
                self.send_response(resp.status)
                self.send_response(resp.status)
                content_type = resp.headers.get('Content-Type', 'application/json')
                self.send_header('Content-Type', content_type)
                self.end_headers()
                self.wfile.write(resp_data)
        except urllib.error.HTTPError as e:
            err_data = e.read()
            self.send_response(e.code)
            content_type = e.headers.get('Content-Type', 'application/json')
            self.send_header('Content-Type', content_type)
            self.end_headers()
            self.wfile.write(err_data)
        except Exception as e:
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            err_msg = json.dumps({"error": f"Relay error: {str(e)}"}).encode('utf-8')
            self.wfile.write(err_msg)

if __name__ == '__main__':
    port = 5173
    handler = lambda *args, **kwargs: RelayHTTPRequestHandler(*args, directory='build/web', **kwargs)
    httpd = HTTPServer(('0.0.0.0', port), handler)
    print(f"Serving HTTP on 0.0.0.0 port {port} with CORS relay proxy at /proxy ...")
    httpd.serve_forever()
