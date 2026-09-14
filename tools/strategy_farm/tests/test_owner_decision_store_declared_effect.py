"""Declared machine effects on decision cards and the governed receipt re-issue (2026-09-14).

A card may declare the exact consumer-bound effect under ``selected_effect_on_yes`` while
``yes_effect`` stays OWNER-facing prose; ``record_decision`` now carries the declared string.
A terminal receipt written before that rule can be re-issued once with the declared effect
(same decision, same card, superseding receipt, own execution task id).
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import owner_decision_store as store  # noqa: E402

SHA = "8b06c6c8fd0a97273bc39d14cc0150a57d2e75e3c248353b475b13a3e432a400"
EFFECT = f"ATTEST_CURRENT_PROPOSAL_SHA256={SHA};FREEZE=ACTIVE;NO_ACTIVATION"


def _seed(tmp_path: Path, *, declared: bool) -> tuple[Path, Path, Path]:
    item = {
        "id": f"OWNER-DEC-LIVE-IDENTITY-CURRENT-{SHA}",
        "status": "OPEN",
        "category": "Book",
        "question": "Attest the unchanged live identity?",
        "recommendation": "JA",
        "yes_effect": "Receipt mit selected_effect " + EFFECT,
        "no_effect": "Condition 1 stays open.",
        "cost_of_wait": "none",
        "detail": "Kontext",
        "evidence": [],
        "due": None,
        "severity": "action",
        "created_at_utc": "2026-09-13T17:00:00+00:00",
    }
    if declared:
        item["selected_effect_on_yes"] = EFFECT
    feed = {"schema_version": store.FEED_SCHEMA, "maintainer": "test", "revision": 1,
            "updated_at_utc": "2026-09-13T17:00:00+00:00", "items": [item]}
    feed_path = tmp_path / "owner_decisions.json"
    feed_path.write_text(json.dumps(feed), encoding="utf-8")
    receipts = tmp_path / "receipts.jsonl"
    vault = tmp_path / "vault" / "OWNER.md"
    vault.parent.mkdir(parents=True)
    vault.write_text("# OWNER\n\n" + store.VAULT_QUEUE_START + "\n" + store.VAULT_QUEUE_END + "\n", encoding="utf-8")
    return feed_path, receipts, vault


def _decide(feed_path, receipts, vault, request_id="CHAT-20260914-TEST-00000001"):
    item = store.load_feed(feed_path)["items"][0]
    return store.record_decision(
        decision_id=item["id"], decision="YES", notes="OWNER chat transcribed", request_id=request_id,
        feed_path=feed_path, receipts_path=receipts, vault_owner_path=vault,
        expected_decision_card_sha256=store.decision_card_sha256(item), execution_plan_sha256="0" * 64,
    )


def test_declared_effect_wins_over_prose(tmp_path):
    feed_path, receipts, vault = _seed(tmp_path, declared=True)
    receipt = _decide(feed_path, receipts, vault)
    assert receipt["selected_effect"] == EFFECT


def test_prose_effect_is_kept_when_nothing_is_declared(tmp_path):
    feed_path, receipts, vault = _seed(tmp_path, declared=False)
    receipt = _decide(feed_path, receipts, vault)
    assert receipt["selected_effect"].startswith("Receipt mit selected_effect ")
    with pytest.raises(store.DecisionStoreError, match="declares no machine effect"):
        store.reissue_terminal_receipt(receipt_id=receipt["receipt_id"], request_id="CHAT-20260914-TEST-REISSUE-01",
                                       feed_path=feed_path, receipts_path=receipts, vault_owner_path=vault)


def test_reissue_supersedes_with_the_declared_effect_and_own_task_id(tmp_path):
    feed_path, receipts, vault = _seed(tmp_path, declared=False)
    prior = _decide(feed_path, receipts, vault)
    # the card is amended afterwards to declare the machine effect (the 2026-09-14 situation)
    feed = store.load_feed(feed_path)
    feed["items"][0]["selected_effect_on_yes"] = EFFECT
    feed_path.write_text(json.dumps(feed), encoding="utf-8")
    new = store.reissue_terminal_receipt(receipt_id=prior["receipt_id"], request_id="CHAT-20260914-TEST-REISSUE-02",
                                         feed_path=feed_path, receipts_path=receipts, vault_owner_path=vault)
    assert new["selected_effect"] == EFFECT
    assert new["supersedes_receipt_id"] == prior["receipt_id"]
    assert new["decision"] == "YES" and new["decided_by"] == "OWNER" and new["decision_id"] == prior["decision_id"]
    assert new["execution_task_id"] == store.execution_task_id(new["receipt_id"]) != prior["execution_task_id"]
    unsigned = {k: v for k, v in new.items() if k != "receipt_sha256"}
    assert new["receipt_sha256"] == store.sha256_bytes(store.canonical_bytes(unsigned))
    after = store.load_feed(feed_path)["items"][0]
    assert after["status"] == "DECIDED" and after["last_receipt_id"] == new["receipt_id"]
    assert len(store.load_receipts(receipts)) == 2  # append-only: the prior receipt stays
    # idempotent on the same request id; refused a second time otherwise
    again = store.reissue_terminal_receipt(receipt_id=prior["receipt_id"], request_id="CHAT-20260914-TEST-REISSUE-02",
                                           feed_path=feed_path, receipts_path=receipts, vault_owner_path=vault)
    assert again["receipt_id"] == new["receipt_id"]
    with pytest.raises(store.DecisionConflict):
        store.reissue_terminal_receipt(receipt_id=prior["receipt_id"], request_id="CHAT-20260914-TEST-REISSUE-03",
                                       feed_path=feed_path, receipts_path=receipts, vault_owner_path=vault)
