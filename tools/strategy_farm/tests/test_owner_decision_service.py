from __future__ import annotations

import http.client
import json
import threading
from pathlib import Path

from tools.strategy_farm import owner_decision_service as service
from tools.strategy_farm import owner_decision_store as store


def _feed(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "schema_version": store.FEED_SCHEMA,
                "revision": 1,
                "updated_at_utc": "2026-08-24T00:00:00Z",
                "items": [
                    {
                        "id": "OWNER-DEC-SERVICE-TEST",
                        "status": "OPEN",
                        "category": "Test",
                        "question": "Dokumentieren?",
                        "recommendation": "JA.",
                        "yes_effect": "Receipt.",
                        "no_effect": "Kein Receipt.",
                        "cost_of_wait": "Keiner.",
                        "detail": "Test",
                        "evidence": [],
                        "due": None,
                        "severity": "action",
                        "created_at_utc": "2026-08-24T00:00:00Z",
                    }
                ],
            }
        ),
        encoding="utf-8",
    )


def _request(
    port: int,
    method: str,
    path: str,
    *,
    body: dict | None = None,
    token: str | None = None,
    origin: str = "null",
) -> tuple[int, dict]:
    payload = None if body is None else json.dumps(body)
    headers = {"Origin": origin}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    if token is not None:
        headers["X-QM-Decision-Token"] = token
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    conn.request(method, path, body=payload, headers=headers)
    response = conn.getresponse()
    data = json.loads(response.read().decode("utf-8") or "{}")
    conn.close()
    return response.status, data


def test_loopback_service_records_only_a_document_receipt(tmp_path: Path) -> None:
    feed = tmp_path / "owner_decisions.json"
    receipts = tmp_path / "receipts.jsonl"
    vault = tmp_path / "OWNER.md"
    _feed(feed)
    vault.write_text(store.render_vault_queue(store.load_feed(feed)), encoding="utf-8")
    token = "a" * 64
    server = service.build_server(
        port=0,
        token=token,
        feed_path=feed,
        receipts_path=receipts,
        vault_owner_path=vault,
    )
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        port = int(server.server_port)
        status, health = _request(port, "GET", "/health")
        assert status == 200
        assert health == {
            "mode": "DOCUMENT_ONLY",
            "ok": True,
            "open_count": 1,
            "revision": 1,
            "schema": store.FEED_SCHEMA,
        }

        status, denied = _request(
            port,
            "POST",
            "/v1/decisions/OWNER-DEC-SERVICE-TEST",
            token="b" * 64,
            body={"decision": "YES", "notes": "ok", "request_id": "request-2001"},
        )
        assert status == 403 and denied["error"] == "invalid_token"
        assert not receipts.exists()

        status, accepted = _request(
            port,
            "POST",
            "/v1/decisions/OWNER-DEC-SERVICE-TEST",
            token=token,
            body={
                "decision": "YES",
                "notes": "Nur dokumentieren.",
                "request_id": "request-2001",
            },
        )
        assert status == 201
        assert accepted["ok"] is True
        assert accepted["execution_authorized"] is False
        assert accepted["mode"] == "DOCUMENT_ONLY"
        receipt = json.loads(receipts.read_text(encoding="utf-8").strip())
        assert receipt["execution_authorized"] is False
        assert store.load_feed(feed)["items"][0]["status"] == "DECIDED"

        status, rejected_origin = _request(
            port, "GET", "/health", origin="https://example.invalid"
        )
        assert status == 403 and rejected_origin["error"] == "origin_not_allowed"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def test_token_is_created_once_and_reused(tmp_path: Path) -> None:
    token_file = tmp_path / "token.txt"
    first = service.ensure_token(token_file)
    second = service.ensure_token(token_file)
    assert first == second
    assert len(first) == 64
