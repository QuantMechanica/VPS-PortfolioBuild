from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import owner_decision_store as store


def _seed(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "schema_version": store.FEED_SCHEMA,
                "revision": 0,
                "maintainer": "test",
                "updated_at_utc": "2026-08-24T00:00:00Z",
                "items": [
                    {
                        "id": "OWNER-DEC-TEST-ONE",
                        "status": "OPEN",
                        "category": "Test",
                        "question": "Freigeben?",
                        "recommendation": "JA, weil reversibel.",
                        "yes_effect": "Freigabe dokumentiert.",
                        "no_effect": "Bleibt aus.",
                        "cost_of_wait": "Ein Tag.",
                        "detail": "Kontext",
                        "evidence": ["evidence.md"],
                        "due": None,
                        "severity": "action",
                        "created_at_utc": "2026-08-24T00:00:00Z",
                    },
                    {
                        "id": "OWNER-DEC-TEST-TWO",
                        "status": "DEFERRED",
                        "category": "Test",
                        "question": "Spaeter entscheiden?",
                        "recommendation": "VERTAGT bis Evidenz vorliegt.",
                        "yes_effect": "Ja dokumentiert.",
                        "no_effect": "Nein dokumentiert.",
                        "cost_of_wait": "Keiner.",
                        "detail": "Kontext",
                        "evidence": [],
                        "due": "EVENT:READY",
                        "severity": "info",
                        "created_at_utc": "2026-08-24T00:00:00Z",
                    },
                ],
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def _legacy_feed(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "updated_at_utc": "2026-08-21T00:00:00Z",
                "items": [{"cat": "old", "title": "old"}],
            }
        ),
        encoding="utf-8",
    )


def _legacy_vault(path: Path) -> None:
    path.parent.mkdir(parents=True)
    path.write_text(
        """# @OWNER — ToDos

Intro.

## Entscheidungsschlange (max 5)

- [ ] @OWNER `OLD` **Alt**

## Arbeitsaufträge (keine Entscheidungen)

- [ ] @OWNER `TASK` **Bleibt**

## Erinnerungen (terminiert)

- [ ] @OWNER `REM` **Bleibt auch**

## Bewusst vertagt

- [ ] @OWNER `OWNER-DEC-MQL5CAND` **Altduplikat**
""",
        encoding="utf-8",
    )


def _legacy_index(path: Path) -> None:
    path.write_text(
        """# Index

## Offene OWNER-Entscheidungen (≤5)

1. Alt
2. Alt

## Programme

Bleibt.
""",
        encoding="utf-8",
    )


def test_bootstrap_is_hash_guarded_preserves_backups_and_removes_five_cap(
    tmp_path: Path,
) -> None:
    feed = tmp_path / "state" / "owner_decisions.json"
    seed = tmp_path / "seed.json"
    vault = tmp_path / "vault" / "12 ToDo" / "AI ToDos" / "OWNER.md"
    vault_index = tmp_path / "vault" / "12 ToDo" / "_INDEX.md"
    feed.parent.mkdir(parents=True)
    _legacy_feed(feed)
    _seed(seed)
    _legacy_vault(vault)
    _legacy_index(vault_index)

    plan = store.bootstrap_plan(
        feed_path=feed, seed_path=seed, vault_owner_path=vault,
        vault_index_path=vault_index,
    )
    assert plan["state"] == "READY"
    plan_hash = store.bootstrap_plan_sha256(plan)
    with pytest.raises(store.DecisionStoreError, match="plan hash changed"):
        store.apply_bootstrap(
            plan,
            expected_plan_sha256="0" * 64,
            feed_path=feed,
            seed_path=seed,
            vault_owner_path=vault,
            vault_index_path=vault_index,
        )

    result = store.apply_bootstrap(
        plan,
        expected_plan_sha256=plan_hash,
        feed_path=feed,
        seed_path=seed,
        vault_owner_path=vault,
        vault_index_path=vault_index,
    )
    assert result["applied"] is True
    assert Path(result["feed_backup"]).is_file()
    assert Path(result["vault_backup"]).is_file()
    assert Path(result["vault_index_backup"]).is_file()
    migrated = store.load_feed(feed)
    assert migrated["revision"] == 1
    text = vault.read_text(encoding="utf-8")
    assert store.VAULT_QUEUE_START in text
    assert "max 5" not in text
    assert "OWNER-DEC-TEST-ONE" in text
    assert "`TASK`" in text and "`REM`" in text
    assert text.count("OWNER-DEC-MQL5CAND") == 0
    index_text = vault_index.read_text(encoding="utf-8")
    assert "ohne Cap" in index_text
    assert "(≤5)" not in index_text
    assert "## Programme" in index_text


def test_record_decision_is_receipted_idempotent_and_router_scoped(tmp_path: Path) -> None:
    feed = tmp_path / "state" / "owner_decisions.json"
    receipts = tmp_path / "state" / "receipts.jsonl"
    vault = tmp_path / "vault" / "12 ToDo" / "AI ToDos" / "OWNER.md"
    feed.parent.mkdir(parents=True)
    _seed(feed)
    vault.parent.mkdir(parents=True)
    vault.write_text(
        "# OWNER\n\n" + store.render_vault_queue(store.load_feed(feed)) + "\n",
        encoding="utf-8",
    )

    receipt = store.record_decision(
        decision_id="OWNER-DEC-TEST-ONE",
        decision="YES",
        notes="Bitte separat beauftragen.",
        request_id="request-0001",
        feed_path=feed,
        receipts_path=receipts,
        vault_owner_path=vault,
        decided_at_utc="2026-08-24T08:00:00+00:00",
    )
    assert receipt["execution_authorized"] is True
    assert receipt["execution_handoff_authorized"] is True
    assert receipt["execution_boundary"] == "DECISION_SCOPED_ROUTER_TASK"
    assert receipt["execution_task_id"] == store.execution_task_id(receipt["receipt_id"])
    assert receipt["selected_effect"] == "Freigabe dokumentiert."
    assert receipt["decision_card_sha256"]
    assert receipt["live_execution_authorized"] is False
    decided = next(item for item in store.load_feed(feed)["items"] if item["id"].endswith("ONE"))
    assert decided["status"] == "DECIDED"
    assert "OWNER-DEC-TEST-ONE" not in vault.read_text(encoding="utf-8").split(
        store.VAULT_QUEUE_END
    )[0]
    archive = vault.parent / "Archive" / "Entscheidungen 2026-08-24.md"
    assert receipt["receipt_id"] in archive.read_text(encoding="utf-8")
    assert len(receipts.read_text(encoding="utf-8").splitlines()) == 1

    repeated = store.record_decision(
        decision_id="OWNER-DEC-TEST-ONE",
        decision="YES",
        notes="ignored on idempotent replay",
        request_id="request-0001",
        feed_path=feed,
        receipts_path=receipts,
        vault_owner_path=vault,
    )
    assert repeated["receipt_id"] == receipt["receipt_id"]
    assert len(receipts.read_text(encoding="utf-8").splitlines()) == 1

    deferred = store.record_decision(
        decision_id="OWNER-DEC-TEST-TWO",
        decision="DEFERRED",
        notes="Bis zum Event.",
        request_id="request-0002",
        feed_path=feed,
        receipts_path=receipts,
        vault_owner_path=vault,
        decided_at_utc="2026-08-24T08:01:00+00:00",
    )
    assert deferred["decision"] == "DEFERRED"
    assert deferred["execution_authorized"] is False
    assert deferred["execution_task_id"] is None
    assert deferred["execution_boundary"] == "DEFERRED_NO_HANDOFF"
    still_open = next(item for item in store.load_feed(feed)["items"] if item["id"].endswith("TWO"))
    assert still_open["status"] == "DEFERRED"
    assert "OWNER-DEC-TEST-TWO" in vault.read_text(encoding="utf-8")


def test_terminal_decision_cannot_be_overwritten(tmp_path: Path) -> None:
    feed = tmp_path / "owner_decisions.json"
    receipts = tmp_path / "receipts.jsonl"
    vault = tmp_path / "OWNER.md"
    _seed(feed)
    vault.write_text(store.render_vault_queue(store.load_feed(feed)), encoding="utf-8")
    store.record_decision(
        decision_id="OWNER-DEC-TEST-ONE",
        decision="NO",
        notes="",
        request_id="request-1001",
        feed_path=feed,
        receipts_path=receipts,
        vault_owner_path=vault,
    )
    with pytest.raises(store.DecisionConflict, match="already terminal"):
        store.record_decision(
            decision_id="OWNER-DEC-TEST-ONE",
            decision="YES",
            notes="",
            request_id="request-1002",
            feed_path=feed,
            receipts_path=receipts,
            vault_owner_path=vault,
        )
