#!/usr/bin/env python3
"""Simple SPA-aware HTTP server for Flutter Web.
Falls back to index.html for routes that don't match a physical file.
"""
import http.server
import os
import sys

WEB_DIR = os.path.join(os.path.dirname(__file__), '..', 'origna_gta', 'build', 'web')
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5005


class SPAHandler(http.server.SimpleHTTPRequestHandler):
    """Class SPAHandler."""
    def __init__(self, *args, **kwargs):
        """Function __init__."""
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        # Check if the requested path maps to a real file
        """Function do_GET."""
        path = self.translate_path(self.path)
        if not os.path.exists(path) or (os.path.isdir(path) and not os.path.exists(os.path.join(path, 'index.html'))):
            # SPA fallback: serve index.html for any unmatched route
            self.path = '/index.html'
        return super().do_GET()

    def log_message(self, format, *args):
        # Suppress noisy logging during tests
        """Function log_message."""
        pass


if __name__ == '__main__':
    with http.server.HTTPServer(('127.0.0.1', PORT), SPAHandler) as httpd:
        print(f'🌐 SPA server on http://127.0.0.1:{PORT} → {WEB_DIR}')
        httpd.serve_forever()
