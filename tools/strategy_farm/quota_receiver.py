"""Local HTTP receiver for Tampermonkey usage snapshots.

Listens on localhost:9090 (loopback only — never internet-exposed).

POST /quota
  Body: {"source": "codex" | "claude", "data": <object>, "scraped_at": "<iso>"}
  Writes to: D:/QM/strategy_farm/state/quota_snapshot.json
  (merges with existing — keys "codex" and "claude" carry latest snapshot each)

GET /quota
  Returns current snapshot JSON.

CORS:
  Access-Control-Allow-Origin: * (so userscripts on chatgpt.com / claude.ai
  can POST without preflight failure). Local loopback only — no internet
  exposure. Both Chrome's secure-context CORS preflight (OPTIONS) and the
  Tampermonkey GM_xmlhttpRequest path work.

Run:
  python tools/strategy_farm/quota_receiver.py
  (also installed as scheduled task QM_StrategyFarm_QuotaReceiver, AT STARTUP)
"""

from __future__ import annotations

import datetime as dt
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from socketserver import ThreadingMixIn

HOST = "127.0.0.1"
PORT = 9090
STATE = Path(r"D:/QM/strategy_farm/state/quota_snapshot.json")


def load_snapshot() -> dict:
    if not STATE.exists():
        return {}
    try:
        return json.loads(STATE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_snapshot(d: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(d, indent=2, sort_keys=True), encoding="utf-8")


class QuotaHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        # Quiet — log to stderr only on errors
        sys.stderr.write(f"[{self.log_date_time_string()}] {fmt%args}\n")

    def _send(self, code: int, body: dict | None = None) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        if body is not None:
            self.wfile.write(json.dumps(body).encode("utf-8"))

    def do_OPTIONS(self) -> None:  # CORS preflight
        self._send(204)

    def do_GET(self) -> None:
        if self.path.startswith("/quota"):
            self._send(200, load_snapshot())
            return
        self._send(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if not self.path.startswith("/quota"):
            self._send(404, {"error": "not_found"})
            return
        length = int(self.headers.get("Content-Length") or "0")
        try:
            raw = self.rfile.read(length).decode("utf-8")
            payload = json.loads(raw)
        except Exception as exc:
            self._send(400, {"error": "invalid_json", "detail": str(exc)})
            return
        source = payload.get("source")
        if source not in ("codex", "claude"):
            self._send(400, {"error": "source_must_be_codex_or_claude"})
            return
        snap = load_snapshot()
        snap[source] = {
            "data": payload.get("data"),
            "scraped_at": payload.get("scraped_at") or dt.datetime.utcnow().isoformat() + "Z",
            "received_at": dt.datetime.utcnow().isoformat() + "Z",
            "user_agent": self.headers.get("User-Agent", ""),
        }
        save_snapshot(snap)
        self._send(200, {"ok": True, "source": source})


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main() -> int:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    if not STATE.exists():
        save_snapshot({})
    print(f"quota_receiver listening on http://{HOST}:{PORT}/quota -> {STATE}")
    server = ThreadedHTTPServer((HOST, PORT), QuotaHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
