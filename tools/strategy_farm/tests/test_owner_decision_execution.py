from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import owner_decision_execution as execution
from tools.strategy_farm import owner_decision_store as store


def _feed(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "schema_version": store.FEED_SCHEMA,
                "revision": 0,
                "updated_at_utc": "2026-08-24T00:00:00Z",
                "items": [
                    {
                        "id": "OWNER-DEC-EXEC-TEST",
                        "status": "OPEN",
                        "category": "Test",
                        "question": "Ausfuehren?",
                        "recommendation": "JA.",
                        "yes_effect": "Bounded apply.",
                        "no_effect": "No-op verify.",
                        "cost_of_wait": "One day.",
                        "detail": "Fixture",
                        "evidence": ["evidence.md"],
                        "due": None,
                        "severity": "action",
                        "created_at_utc": "2026-08-24T00:00:00Z",
                    }
                ],
            }
        ),
        encoding="utf-8",
    )


def test_execution_contract_covers_every_bootstrap_decision_and_both_choices() -> None:
    feed = store.load_feed(store.DEFAULT_SEED)
    contract = execution.load_contract()
    contract_ids = {row["id"] for row in contract["decisions"]}
    assert contract_ids == {row["id"] for row in feed["items"]}
    for item in feed["items"]:
        summary = execution.plan_summary(item["id"])
        assert summary["ready"] is True
        assert summary["agent"] == "claude"
        assert summary["yes_mode"] in {
            "APPLY_AND_VERIFY", "DOCUMENT_AND_VERIFY", "PREPARE_FOLLOWUP_ONLY"
        }
        assert summary["no_mode"] in {
            "APPLY_AND_VERIFY", "DOCUMENT_AND_VERIFY", "PREPARE_FOLLOWUP_ONLY"
        }


def _contract(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "schema": execution.CONTRACT_SCHEMA,
                "agent": "claude",
                "task_type": "ops_issue",
                "required_capabilities": ["code", "ops", "summary"],
                "required_skills": ["owner_decision_execution"],
                "budget_class": "premium",
                "default_priority": 90,
                "global_forbidden_actions": ["T_Live and AutoTrading mutation"],
                "decisions": [
                    {
                        "id": "OWNER-DEC-EXEC-TEST",
                        "todo_id": "QM-TODO-20260824-999",
                        "priority": 93,
                        "choices": {
                            "YES": {
                                "mode": "APPLY_AND_VERIFY",
                                "objective": "Apply the bounded fixture.",
                                "allowed_actions": ["fixture apply"],
                                "acceptance": ["verified"],
                            },
                            "NO": {
                                "mode": "DOCUMENT_AND_VERIFY",
                                "objective": "Verify the no-op fixture.",
                                "allowed_actions": ["fixture read"],
                                "acceptance": ["unchanged"],
                            },
                        },
                    }
                ],
            }
        ),
        encoding="utf-8",
    )


def _receipt(tmp_path: Path, decision: str = "YES") -> tuple[dict, Path, Path, Path]:
    feed = tmp_path / "feed.json"
    receipts = tmp_path / "receipts.jsonl"
    vault = tmp_path / "OWNER.md"
    contract = tmp_path / "execution.json"
    _feed(feed)
    _contract(contract)
    plan_hash = execution.decision_plan_sha256("OWNER-DEC-EXEC-TEST", contract)
    card_hash = store.decision_card_sha256(store.load_feed(feed)["items"][0])
    vault.write_text(store.render_vault_queue(store.load_feed(feed)), encoding="utf-8")
    receipt = store.record_decision(
        decision_id="OWNER-DEC-EXEC-TEST",
        decision=decision,
        notes="Do not expand this scope.",
        request_id=f"request-exec-{decision.lower()}",
        feed_path=feed,
        receipts_path=receipts,
        vault_owner_path=vault,
        decided_at_utc="2026-08-24T09:00:00+00:00",
        expected_decision_card_sha256=card_hash,
        execution_plan_sha256=plan_hash,
    )
    return receipt, feed, receipts, contract


def test_terminal_receipt_creates_exactly_one_claude_task(tmp_path: Path) -> None:
    receipt, feed, _receipts, contract = _receipt(tmp_path)
    root = tmp_path / "farm"
    first = execution.handoff_receipt(
        receipt, root=root, feed_path=feed, contract_path=contract, apply=True
    )
    second = execution.handoff_receipt(
        receipt, root=root, feed_path=feed, contract_path=contract, apply=True
    )
    assert first["state"] == "QUEUED" and first["created"] is True
    assert second["state"] == "EXISTING" and second["created"] is False
    assert first["task_id"] == receipt["execution_task_id"]

    con = sqlite3.connect(root / "state" / "farm_state.sqlite")
    con.row_factory = sqlite3.Row
    row = con.execute("SELECT * FROM agent_tasks WHERE id=?", (first["task_id"],)).fetchone()
    assert con.execute("SELECT COUNT(*) FROM agent_tasks").fetchone()[0] == 1
    con.close()
    assert row["state"] == "TODO"
    assert json.loads(row["required_capabilities_json"]) == ["code", "ops", "summary"]
    payload = json.loads(row["payload_json"])
    assert payload["operation"] == execution.TASK_OPERATION
    assert payload["target_agent_profile"] == "claude"
    assert payload["containment"] == execution.MODE_CONTAINMENT["APPLY_AND_VERIFY"]
    assert payload["owner_decision"]["selected_effect"] == receipt["selected_effect"]
    assert payload["authority"] == {
        "scope": "selected_effect_only",
        "execution_authorized": True,
        "live_execution_authorized": False,
        "factory_pause_authorized": False,
        "autotrading_authorized": False,
        "deployment_authorized": False,
        "notes_may_expand_scope": False,
    }
    routed = execution.agent_router.route_once(
        root,
        claude_disabled_flag=root / "claude-not-disabled.flag",
        quota_gate_enabled=False,
    )
    assert routed.task_id == receipt["execution_task_id"]
    assert routed.assigned_agent == "claude"
    assert routed.reason == "assigned"


def test_tampered_receipt_is_refused_and_deferred_creates_no_task(tmp_path: Path) -> None:
    receipt, feed, _receipts, contract = _receipt(tmp_path)
    receipt["notes"] = "tampered"
    with pytest.raises(execution.ExecutionContractError, match="hash mismatch"):
        execution.handoff_receipt(
            receipt, root=tmp_path / "farm", feed_path=feed,
            contract_path=contract, apply=True,
        )

    deferred = {
        "decision": "DEFERRED",
        "execution_handoff_authorized": False,
    }
    result = execution.handoff_receipt(deferred, root=tmp_path / "never-created")
    assert result == {"state": "DEFERRED_NO_HANDOFF", "created": False, "task_id": None}
    assert not (tmp_path / "never-created").exists()


def test_feed_card_drift_after_receipt_is_refused(tmp_path: Path) -> None:
    receipt, feed_path, _receipts, contract = _receipt(tmp_path)
    feed = store.load_feed(feed_path)
    feed["items"][0]["yes_effect"] = "A different and unauthorized effect."
    feed_path.write_text(json.dumps(feed), encoding="utf-8")

    with pytest.raises(execution.ExecutionContractError, match="card changed"):
        execution.handoff_receipt(
            receipt,
            root=tmp_path / "farm",
            feed_path=feed_path,
            contract_path=contract,
            apply=True,
        )
    assert not (tmp_path / "farm").exists()


def test_execution_plan_drift_after_receipt_is_refused(tmp_path: Path) -> None:
    receipt, feed_path, _receipts, contract_path = _receipt(tmp_path)
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    contract["decisions"][0]["choices"]["YES"]["allowed_actions"] = [
        "fixture apply",
        "new authority not shown to OWNER",
    ]
    contract_path.write_text(json.dumps(contract), encoding="utf-8")

    with pytest.raises(execution.ExecutionContractError, match="execution plan changed"):
        execution.handoff_receipt(
            receipt,
            root=tmp_path / "farm",
            feed_path=feed_path,
            contract_path=contract_path,
            apply=True,
        )
    assert not (tmp_path / "farm").exists()


def test_five_minute_reconcile_recovers_once_and_is_idempotent(tmp_path: Path) -> None:
    receipt, feed, receipts, contract = _receipt(tmp_path)
    root = tmp_path / "farm"
    first = execution.reconcile_receipts(
        root=root,
        feed_path=feed,
        receipts_path=receipts,
        contract_path=contract,
        apply=True,
    )
    second = execution.reconcile_receipts(
        root=root,
        feed_path=feed,
        receipts_path=receipts,
        contract_path=contract,
        apply=True,
    )
    assert first["ok"] is True and first["receipt_count"] == 1
    assert first["results"] == [{
        "decision_id": receipt["decision_id"],
        "state": "QUEUED",
        "created": True,
        "task_id": receipt["execution_task_id"],
        "task_state": "TODO",
        "assigned_agent": None,
        "expected_artifact": first["results"][0]["expected_artifact"],
    }]
    assert second["ok"] is True
    assert second["results"][0]["state"] == "EXISTING"
    assert second["results"][0]["created"] is False

    con = sqlite3.connect(root / "state" / "farm_state.sqlite")
    assert con.execute("SELECT COUNT(*) FROM agent_tasks").fetchone()[0] == 1
    con.close()


def test_handoff_retries_factory_sqlite_contention_with_fresh_connection(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    receipt, feed, _receipts, contract = _receipt(tmp_path)
    root = tmp_path / "farm"
    real_connect = execution.agent_router.connect
    real_retry = execution.sqlite_busy.retry_sqlite_busy
    attempts = 0

    def flaky_connect(connect_root: Path) -> sqlite3.Connection:
        nonlocal attempts
        attempts += 1
        if attempts < 3:
            raise sqlite3.OperationalError("database is locked")
        return real_connect(connect_root)

    def immediate_retry(operation):
        return real_retry(
            operation,
            sleep=lambda _delay: None,
            random_uniform=lambda _lower, _upper: 0.0,
        )

    monkeypatch.setattr(execution.agent_router, "connect", flaky_connect)
    monkeypatch.setattr(execution.sqlite_busy, "retry_sqlite_busy", immediate_retry)

    result = execution.handoff_receipt(
        receipt, root=root, feed_path=feed, contract_path=contract, apply=True
    )

    assert attempts == 3
    assert result["state"] == "QUEUED"
    con = sqlite3.connect(root / "state" / "farm_state.sqlite")
    assert con.execute(
        "SELECT COUNT(*) FROM agent_tasks WHERE id=?", (receipt["execution_task_id"],)
    ).fetchone()[0] == 1
    con.close()


def test_projection_surfaces_missing_queued_running_review_and_complete(tmp_path: Path) -> None:
    receipt, feed_path, _receipts, contract = _receipt(tmp_path)
    root = tmp_path / "farm"
    feed = store.load_feed(feed_path)
    execution.handoff_receipt(
        receipt, root=root, feed_path=feed_path, contract_path=contract, apply=True
    )
    con = sqlite3.connect(root / "state" / "farm_state.sqlite")
    con.row_factory = sqlite3.Row
    assert execution.project_feed_executions(con, feed)[0]["status"] == "QUEUED"
    for state, expected in (
        ("IN_PROGRESS", "RUNNING"), ("REVIEW", "AWAITING_REVIEW"),
        ("PASSED", "COMPLETE"),
    ):
        con.execute(
            "UPDATE agent_tasks SET state=?, updated_at=? WHERE id=?",
            (state, "2026-08-24T09:01:00+00:00", receipt["execution_task_id"]),
        )
        con.commit()
        projected = execution.project_feed_executions(con, feed)[0]
        assert projected["status"] == expected
        assert projected["complete"] is (state == "PASSED")
    con.close()
