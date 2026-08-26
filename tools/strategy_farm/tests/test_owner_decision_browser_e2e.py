"""Browser-level Mission Control OWNER-decision receipt test.

All state lives below pytest's temporary directory.  The synthetic decision ID
and receipt note are explicitly marked TEST so this can never be mistaken for
OWNER authority or a production decision.
"""
from __future__ import annotations

import json
import threading
from pathlib import Path

import pytest

from tools.strategy_farm import owner_decision_service as service
from tools.strategy_farm import owner_decision_store as store
from tools.strategy_farm import render_cockpit_v2 as renderer
from tools.strategy_farm.tests.test_render_cockpit_v2 import make_contract


DECISION_ID = "OWNER-DEC-TEST-BROWSER-E2E"
PLAN_HASH = "c" * 64
TOKEN = "a" * 64
TEST_NOTE = "[TEST] Synthetic browser E2E receipt; not an OWNER decision."


def _chrome_path() -> Path | None:
    candidates = (
        Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
        Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
        Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
    )
    return next((path for path in candidates if path.is_file()), None)


def _seed_feed(path: Path) -> dict:
    item = {
        "id": DECISION_ID,
        "status": "OPEN",
        "category": "TEST",
        "question": "TEST: browser receipt flow?",
        "recommendation": "TEST only.",
        "yes_effect": "Write one temporary TEST receipt.",
        "no_effect": "Write one temporary TEST receipt.",
        "cost_of_wait": "None; synthetic fixture.",
        "detail": "No production state or OWNER authority.",
        "evidence": ["TEST fixture"],
        "depends_on": [],
        "due": None,
        "severity": "info",
        "created_at_utc": "2026-08-26T00:00:00Z",
    }
    path.write_text(
        json.dumps(
            {
                "schema_version": store.FEED_SCHEMA,
                "revision": 1,
                "maintainer": "pytest TEST fixture",
                "updated_at_utc": "2026-08-26T00:00:00Z",
                "items": [item],
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return item


def test_file_page_click_writes_bound_test_receipt_and_updates_card(tmp_path: Path) -> None:
    sync_api = pytest.importorskip("playwright.sync_api")
    browser_path = _chrome_path()
    if browser_path is None:
        pytest.skip("Chrome/Edge executable unavailable for browser E2E")

    feed = tmp_path / "owner_decisions.TEST.json"
    receipts = tmp_path / "owner_decision_receipts.TEST.jsonl"
    vault = tmp_path / "OWNER.TEST.md"
    page_path = tmp_path / "cockpit_v2.TEST.html"
    item = _seed_feed(feed)
    card_hash = store.decision_card_sha256(item)
    vault.write_text(store.render_vault_queue(store.load_feed(feed)), encoding="utf-8")

    handed_off: list[dict] = []

    def _test_handoff(receipt: dict) -> dict:
        handed_off.append(receipt)
        return {
            "state": "TEST_ONLY_NO_ROUTER_TASK",
            "created": False,
            "task_id": receipt["execution_task_id"],
        }

    server = service.build_server(
        port=0,
        token=TOKEN,
        feed_path=feed,
        receipts_path=receipts,
        vault_owner_path=vault,
        handoff_fn=_test_handoff,
        plan_hash_fn=lambda _decision_id: PLAN_HASH,
    )
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    contract = make_contract(n_decisions=1)
    rendered_item = contract["owner_decisions"]["items"][0]
    rendered_item.update(item)
    rendered_item["decision_card_sha256"] = card_hash
    rendered_item["execution_plan"]["plan_sha256"] = PLAN_HASH
    contract["owner_decisions"]["intake"].update(
        {
            "enabled": True,
            "endpoint": f"http://127.0.0.1:{server.server_port}/v1/decisions",
            "token": TOKEN,
            "mode": "ROUTER_HANDOFF",
            "degraded_reason": None,
        }
    )
    page_path.write_text(renderer.render(contract), encoding="utf-8")

    try:
        with sync_api.sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path=str(browser_path),
            )
            page = browser.new_page()
            page.on("dialog", lambda dialog: dialog.accept())
            page.goto(page_path.as_uri(), wait_until="load")
            page.locator("[data-decision-service-state]").wait_for(state="visible")
            page.wait_for_function(
                "document.querySelector('[data-decision-service-state]').textContent === 'INTAKE VERBUNDEN'"
            )
            row = page.locator(f'[data-decision-id="{DECISION_ID}"]')
            row.locator("textarea").fill(TEST_NOTE)
            row.locator('button[data-decision-choice="YES"]').click()
            page.wait_for_function(
                "document.querySelector('.mc-dec-result').textContent.startsWith('BEAUFTRAGT: YES')"
            )
            assert "mc-dec-recorded" in (row.get_attribute("class") or "")
            assert DECISION_ID in page.content()
            browser.close()
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)

    receipt_lines = receipts.read_text(encoding="utf-8").splitlines()
    assert len(receipt_lines) == 1
    receipt = json.loads(receipt_lines[0])
    assert receipt["decision_id"] == DECISION_ID
    assert receipt["notes"] == TEST_NOTE
    assert receipt["decision_card_sha256"] == card_hash
    assert receipt["execution_plan_sha256"] == PLAN_HASH
    assert receipt["decision"] == "YES"
    assert len(handed_off) == 1
    assert store.load_feed(feed)["items"][0]["status"] == "DECIDED"
