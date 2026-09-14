"""record_decision resolves a card whose id carries a lowercase sha suffix (2026-09-14).

dd719400a8 widened the card-id regex so the live-identity cards (``OWNER-DEC-LIVE-IDENTITY-
CURRENT-<lowercase sha>``) load; ``record_decision`` still upper-cased the requested id and
then required an exact match, so no receipt could ever be written for those cards.  The
lookup is now case-insensitive and the receipt keeps the feed's exact id.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import owner_decision_store as store  # noqa: E402

SHA = "8b06c6c8fd0a97273bc39d14cc0150a57d2e75e3c248353b475b13a3e432a400"


def _feed(tmp_path: Path) -> tuple[Path, Path, Path]:
    item = {
        "id": f"OWNER-DEC-LIVE-IDENTITY-CURRENT-{SHA}",
        "status": "OPEN",
        "question": "Attest the unchanged live identity?",
        "recommendation": "JA",
        "yes_effect": f"ATTEST_CURRENT_PROPOSAL_SHA256={SHA};FREEZE=ACTIVE;NO_ACTIVATION",
        "no_effect": "Condition 1 stays open.",
        "category": "Book", "severity": "action", "created_at_utc": "2026-09-13T17:00:00+00:00",
        "cost_of_wait": "none", "detail": "Kontext", "due": None, "evidence": [],
    }
    feed = {"schema_version": store.FEED_SCHEMA, "maintainer": "test", "revision": 1,
            "updated_at_utc": "2026-09-13T17:00:00+00:00", "items": [item]}
    feed_path = tmp_path / "owner_decisions.json"
    feed_path.write_text(json.dumps(feed), encoding="utf-8")
    receipts = tmp_path / "receipts.jsonl"
    vault = tmp_path / "vault" / "OWNER.md"
    vault.parent.mkdir(parents=True)
    vault.write_text("# OWNER\n", encoding="utf-8")
    return feed_path, receipts, vault


def test_lowercase_sha_card_id_accepts_a_receipt_and_keeps_the_feed_id(tmp_path):
    feed_path, receipts, vault = _feed(tmp_path)
    feed = store.load_feed(feed_path)
    item = feed["items"][0]
    receipt = store.record_decision(
        decision_id=item["id"],
        decision="YES",
        notes="OWNER chat 2026-09-14 transcribed",
        request_id="CHAT-20260914-TEST-00000001",
        feed_path=feed_path,
        receipts_path=receipts,
        vault_owner_path=vault,
        expected_decision_card_sha256=store.decision_card_sha256(item),
        execution_plan_sha256="0" * 64,
    )
    assert receipt["decision_id"] == item["id"]  # exact feed id, lowercase sha kept
    assert receipt["selected_effect"].startswith("ATTEST_CURRENT_PROPOSAL_SHA256=")
    after = store.load_feed(feed_path)
    assert after["items"][0]["status"] == "DECIDED"
    assert after["items"][0]["last_receipt_id"] == receipt["receipt_id"]
