from http.server import HTTPServer, SimpleHTTPRequestHandler

class NoCacheHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

if __name__ == '__main__':
    port = 5173
    handler = lambda *args, **kwargs: NoCacheHTTPRequestHandler(*args, directory='build/web', **kwargs)
    httpd = HTTPServer(('0.0.0.0', port), handler)
    print(f"Serving HTTP on 0.0.0.0 port {port} with no-cache headers ...")
    httpd.serve_forever()
