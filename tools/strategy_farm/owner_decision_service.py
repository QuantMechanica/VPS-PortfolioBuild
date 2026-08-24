#!/usr/bin/env python3
"""Loopback-only OWNER decision intake with governed router handoff."""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import re
import secrets
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable
from urllib.parse import unquote, urlsplit

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import owner_decision_store as store  # noqa: E402
from tools.strategy_farm import owner_decision_execution as execution  # noqa: E402


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
DEFAULT_TOKEN_FILE = Path(r"D:\QM\strategy_farm\state\owner_decision_intake_token.txt")
DEFAULT_STATE_FILE = Path(r"D:\QM\strategy_farm\state\owner_decision_service.json")
DECISION_PATH_RE = re.compile(r"^/v1/decisions/([A-Z0-9][A-Z0-9_.:-]{4,127})$")
MAX_BODY_BYTES = 16 * 1024


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f"{path.name}.tmp.{os.getpid()}")
    try:
        with temp.open("wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def ensure_token(path: Path = DEFAULT_TOKEN_FILE) -> str:
    if path.is_file():
        token = path.read_text(encoding="ascii").strip()
        if not re.fullmatch(r"[0-9a-f]{64}", token):
            raise store.DecisionStoreError(f"invalid decision service token file: {path}")
        return token
    token = secrets.token_hex(32)
    _atomic_write(path, (token + "\n").encode("ascii"))
    return token


def _origin_allowed(origin: str | None) -> bool:
    # Mission Control is opened from file:// and browsers serialize that origin
    # as "null". No web origin receives write access.
    return origin in (None, "null")


def make_handler(
    *,
    token: str,
    feed_path: Path = store.DEFAULT_FEED,
    receipts_path: Path = store.DEFAULT_RECEIPTS,
    vault_owner_path: Path = store.DEFAULT_VAULT_OWNER,
    handoff_fn: Callable[[dict[str, Any]], dict[str, Any]] | None = None,
    plan_hash_fn: Callable[[str], str] = execution.decision_plan_sha256,
) -> type[BaseHTTPRequestHandler]:
    service_mode = "ROUTER_HANDOFF" if handoff_fn is not None else "DOCUMENT_ONLY"

    class Handler(BaseHTTPRequestHandler):
        server_version = "QMOwnerDecisionIntake/2"

        def log_message(self, fmt: str, *args: Any) -> None:
            # Under pythonw stderr is absent. The durable receipt is the audit
            # surface; do not leak notes or the token into an access log.
            if sys.stderr is not None:
                super().log_message(fmt, *args)

        def _headers(self, status: int, *, content_length: int = 0) -> None:
            self.send_response(status)
            origin = self.headers.get("Origin")
            if origin == "null":
                self.send_header("Access-Control-Allow-Origin", "null")
                self.send_header("Vary", "Origin")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header(
                "Access-Control-Allow-Headers", "Content-Type, X-QM-Decision-Token"
            )
            if self.headers.get("Access-Control-Request-Private-Network") == "true":
                self.send_header("Access-Control-Allow-Private-Network", "true")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(content_length))
            self.end_headers()

        def _json(self, status: int, payload: dict[str, Any]) -> None:
            body = json.dumps(payload, sort_keys=True).encode("utf-8") + b"\n"
            self._headers(status, content_length=len(body))
            self.wfile.write(body)

        def _reject_origin(self) -> bool:
            if _origin_allowed(self.headers.get("Origin")):
                return False
            self._json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "origin_not_allowed"})
            return True

        def do_OPTIONS(self) -> None:  # noqa: N802
            if self._reject_origin():
                return
            self._headers(HTTPStatus.NO_CONTENT)

        def do_GET(self) -> None:  # noqa: N802
            if self._reject_origin():
                return
            if urlsplit(self.path).path != "/health":
                self._json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not_found"})
                return
            try:
                feed = store.load_feed(feed_path)
                self._json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "mode": service_mode,
                        "schema": feed["schema_version"],
                        "revision": feed["revision"],
                        "open_count": len(store.open_items(feed)),
                    },
                )
            except store.DecisionStoreError as exc:
                self._json(
                    HTTPStatus.SERVICE_UNAVAILABLE,
                    {"ok": False, "error": "feed_unavailable", "detail": str(exc)},
                )

        def do_POST(self) -> None:  # noqa: N802
            if self._reject_origin():
                return
            match = DECISION_PATH_RE.fullmatch(unquote(urlsplit(self.path).path))
            if match is None:
                self._json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not_found"})
                return
            supplied = self.headers.get("X-QM-Decision-Token") or ""
            if not hmac.compare_digest(supplied, token):
                self._json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "invalid_token"})
                return
            try:
                length = int(self.headers.get("Content-Length") or "0")
            except ValueError:
                length = 0
            if length <= 0 or length > MAX_BODY_BYTES:
                self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "invalid_length"})
                return
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8"))
                if not isinstance(body, dict):
                    raise ValueError("body must be an object")
                decision = str(body.get("decision") or "").strip().upper()
                supplied_card_hash = str(
                    body.get("decision_card_sha256") or ""
                ).strip()
                supplied_plan_hash = str(body.get("execution_plan_sha256") or "").strip()
                if decision in {"YES", "NO"}:
                    current_plan_hash = plan_hash_fn(match.group(1))
                    if not hmac.compare_digest(supplied_plan_hash, current_plan_hash):
                        self._json(
                            HTTPStatus.CONFLICT,
                            {
                                "ok": False,
                                "error": "execution_plan_changed",
                                "detail": "Mission Control neu laden; der sichtbare Ausfuehrungsplan hat sich geaendert.",
                            },
                        )
                        return
                receipt = store.record_decision(
                    decision_id=match.group(1),
                    decision=decision,
                    notes=str(body.get("notes") or ""),
                    request_id=str(body.get("request_id") or ""),
                    feed_path=feed_path,
                    receipts_path=receipts_path,
                    vault_owner_path=vault_owner_path,
                    expected_decision_card_sha256=supplied_card_hash,
                    execution_plan_sha256=(
                        supplied_plan_hash if decision in {"YES", "NO"} else None
                    ),
                )
            except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
                self._json(
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": "invalid_json", "detail": str(exc)},
                )
                return
            except store.DecisionConflict as exc:
                self._json(
                    HTTPStatus.CONFLICT,
                    {"ok": False, "error": "decision_conflict", "detail": str(exc)},
                )
                return
            except execution.ExecutionContractError as exc:
                self._json(
                    HTTPStatus.CONFLICT,
                    {"ok": False, "error": "execution_plan_unavailable", "detail": str(exc)},
                )
                return
            except store.DecisionStoreError as exc:
                self._json(
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": "invalid_decision", "detail": str(exc)},
                )
                return
            except Exception:  # pragma: no cover - fail closed, no internals to browser
                self._json(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    {"ok": False, "error": "decision_store_failure"},
                )
                return
            if receipt.get("execution_handoff_authorized") is True and handoff_fn is not None:
                try:
                    handoff = handoff_fn(receipt)
                except Exception:
                    # The OWNER answer is already durable. The canonical 5-minute
                    # reconciler will retry this exact deterministic task identity.
                    handoff = {
                        "state": "RETRY_PENDING",
                        "created": False,
                        "task_id": receipt.get("execution_task_id"),
                    }
            elif receipt.get("decision") == "DEFERRED":
                handoff = {"state": "DEFERRED_NO_HANDOFF", "created": False, "task_id": None}
            else:
                handoff = {
                    "state": "HANDOFF_DISABLED",
                    "created": False,
                    "task_id": receipt.get("execution_task_id"),
                }
            self._json(
                HTTPStatus.CREATED,
                {
                    "ok": True,
                    "mode": service_mode,
                    "decision_id": receipt["decision_id"],
                    "decision": receipt["decision"],
                    "receipt_id": receipt["receipt_id"],
                    "receipt_sha256": receipt["receipt_sha256"],
                    "execution_authorized": receipt["execution_authorized"],
                    "execution_boundary": receipt["execution_boundary"],
                    "execution_task_id": receipt.get("execution_task_id"),
                    "execution_plan_sha256": receipt.get("execution_plan_sha256"),
                    "handoff_state": handoff["state"],
                    "handoff_created": bool(handoff.get("created")),
                },
            )

    return Handler


def build_server(
    *,
    host: str = DEFAULT_HOST,
    port: int = DEFAULT_PORT,
    token: str,
    feed_path: Path = store.DEFAULT_FEED,
    receipts_path: Path = store.DEFAULT_RECEIPTS,
    vault_owner_path: Path = store.DEFAULT_VAULT_OWNER,
    handoff_fn: Callable[[dict[str, Any]], dict[str, Any]] | None = None,
    plan_hash_fn: Callable[[str], str] = execution.decision_plan_sha256,
) -> ThreadingHTTPServer:
    if host not in {"127.0.0.1", "::1", "localhost"}:
        raise store.DecisionStoreError("decision service may bind only to loopback")
    handler = make_handler(
        token=token,
        feed_path=feed_path,
        receipts_path=receipts_path,
        vault_owner_path=vault_owner_path,
        handoff_fn=handoff_fn,
        plan_hash_fn=plan_hash_fn,
    )
    server = ThreadingHTTPServer((host, port), handler)
    server.daemon_threads = True
    return server


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--token-file", type=Path, default=DEFAULT_TOKEN_FILE)
    parser.add_argument("--state-file", type=Path, default=DEFAULT_STATE_FILE)
    parser.add_argument("--feed", type=Path, default=store.DEFAULT_FEED)
    parser.add_argument("--receipts", type=Path, default=store.DEFAULT_RECEIPTS)
    parser.add_argument("--vault-owner", type=Path, default=store.DEFAULT_VAULT_OWNER)
    args = parser.parse_args(argv)
    token = ensure_token(args.token_file)
    startup_reconcile: dict[str, Any]
    try:
        startup_reconcile = execution.reconcile_receipts(
            root=execution.DEFAULT_ROOT,
            feed_path=args.feed,
            receipts_path=args.receipts,
            apply=True,
        )
    except Exception as exc:
        startup_reconcile = {"ok": False, "error": type(exc).__name__}

    def _handoff(receipt: dict[str, Any]) -> dict[str, Any]:
        return execution.handoff_receipt(
            receipt,
            root=execution.DEFAULT_ROOT,
            feed_path=args.feed,
            apply=True,
        )

    server = build_server(
        host=args.host,
        port=args.port,
        token=token,
        feed_path=args.feed,
        receipts_path=args.receipts,
        vault_owner_path=args.vault_owner,
        handoff_fn=_handoff,
    )
    state = {
        "schema": "qm.owner-decision-service-state/v1",
        "pid": os.getpid(),
        "started_at_utc": store.utc_now(),
        "endpoint": f"http://{args.host}:{server.server_port}",
        "mode": "ROUTER_HANDOFF",
        "token_sha256": hashlib.sha256(token.encode("ascii")).hexdigest(),
        "startup_reconcile": startup_reconcile,
    }
    _atomic_write(args.state_file, json.dumps(state, indent=2, sort_keys=True).encode("utf-8") + b"\n")
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
