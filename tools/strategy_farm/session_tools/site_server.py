"""Local preview server with Netlify-style pretty URLs: /x -> x.html, /dir/ -> index.html. Read-only, loopback only."""
import http.server, os, sys, functools
ROOT = sys.argv[1] if len(sys.argv) > 1 else r"C:\QM\deploy\qm-ops-refresh\Website"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8770
class H(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        p = super().translate_path(path)
        if not os.path.exists(p):
            base = path.split('?', 1)[0].split('#', 1)[0]
            cand = super().translate_path(base.rstrip('/') + '.html')
            if os.path.isfile(cand):
                return cand
        return p
    def log_message(self, *a):
        pass
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()
http.server.ThreadingHTTPServer(('127.0.0.1', PORT), functools.partial(H, directory=ROOT)).serve_forever()
