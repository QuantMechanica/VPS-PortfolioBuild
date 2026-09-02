#!/usr/bin/env python3
"""Serve or smoke-check the local QuantMechanica website without deployment."""

from __future__ import annotations

import argparse
import contextlib
import functools
import http.server
import json
import threading
import urllib.request
from pathlib import Path


DEFAULT_ROOT = Path(r"C:\QM\deploy\quantmechanica-ops\Website")


def make_server(root: Path, port: int) -> http.server.ThreadingHTTPServer:
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
    return http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)


def smoke_check(root: Path) -> dict[str, object]:
    server = make_server(root, 0)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_address[1]}"
    checks: dict[str, int] = {}
    try:
        routes = ["/", "/scripts/stats-loader.js"]
        for name in ("stats.json", "public-snapshot.json"):
            if (root / "public-data" / name).is_file():
                routes.append(f"/public-data/{name}")
        for route in routes:
            with contextlib.closing(urllib.request.urlopen(base + route, timeout=5)) as response:
                checks[route] = int(response.status)
                response.read()
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
    return {"schema": "qm.local-website-preview/v1", "root": str(root), "checks": checks}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--check", action="store_true", help="start, fetch key routes, and exit")
    args = parser.parse_args()
    root = args.root.resolve()
    if not (root / "index.html").is_file():
        parser.error(f"website index missing: {root / 'index.html'}")
    if args.check:
        print(json.dumps(smoke_check(root), indent=2))
        return 0
    server = make_server(root, args.port)
    print(f"Serving {root} at http://127.0.0.1:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
