from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import work_item_lifecycle_v2 as lifecycle
from tools.strategy_farm import farmctl


def _row(item_id: str, status: str, verdict=None, payload=None):
    return {
        "id": item_id,
        "status": status,
        "verdict": verdict,
        "payload_json": json.dumps(payload or {}, sort_keys=True),
        "updated_at": "2026-07-29T12:00:00Z",
    }


def test_projection_keeps_waiting_blocked_and_quarantined_nonterminal() -> None:
    rows = [
        _row("a", "done", "WAITING_INPUT", {"verdict_reason": "missing panel"}),
        _row("b", "done", "PENDING_RUNNER"),
        _row("c", "failed", "INFRA_FAIL", {"quarantined": True}),
        _row("d", "done", "PASS_SOFT"),
        _row("e", "done", "NEED_MORE_DATA"),
        _row("f", "done", "REVIEW_REQUIRED"),
        _row("g", "failed", "BLOCKED_FACTORY_OFF"),
    ]
    plan = lifecycle.build_plan(rows, database_sha256="a" * 64)
    by_id = {row["work_item_id"]: row for row in plan["rows"]}

    assert (by_id["a"]["typed_state"], by_id["a"]["terminal"]) == (
        "WAITING_INPUT",
        False,
    )
    assert (by_id["b"]["typed_state"], by_id["b"]["terminal"]) == ("BLOCKED", False)
    assert (by_id["c"]["typed_state"], by_id["c"]["terminal"]) == (
        "QUARANTINED",
        False,
    )
    assert (by_id["d"]["typed_state"], by_id["d"]["terminal"]) == (
        "SUCCEEDED",
        True,
    )
    assert by_id["d"]["reason"] == "PASS_SOFT"
    assert (by_id["e"]["typed_state"], by_id["e"]["terminal"]) == (
        "WAITING_INPUT",
        False,
    )
    assert by_id["f"]["typed_state"] == "WAITING_INPUT"
    assert by_id["g"]["typed_state"] == "BLOCKED"


@pytest.mark.parametrize(
    "verdict",
    ["PASS", "PASS_SOFT", "PASS_LOWFREQ", "PASS_PORTFOLIO", "CONFIG_LOCKED"],
)
def test_real_success_verdict_family_projects_to_succeeded(verdict: str) -> None:
    projected = lifecycle.project_row(_row("success", "done", verdict))

    assert projected["typed_state"] == "SUCCEEDED"
    assert projected["terminal"] is True


def test_lifecycle_taxonomy_covers_canonical_farmctl_verdicts() -> None:
    placeholders = {"BLOCKED", "PENDING_IMPLEMENTATION", "PENDING_RUNNER", "WAITING_INPUT"}

    assert lifecycle.KNOWN_VERDICTS == (
        set(farmctl.CANONICAL_PARENT_CHILD_VERDICTS) | placeholders
    )


def test_maintenance_quarantine_payload_precedes_blocked_legacy_verdict() -> None:
    projected = lifecycle.project_row(
        _row(
            "held",
            "failed",
            "BLOCKED_STALE_BUILD_RESULT",
            {
                "maintenance_hold_code": "STALE_BUILD_RESULT_AUTO_Q02_BYPASS",
                "maintenance_transitions": [{"action": "quarantine"}],
            },
        )
    )

    assert projected["typed_state"] == "QUARANTINED"
    assert projected["terminal"] is False
    assert projected["reason"] == "STALE_BUILD_RESULT_AUTO_Q02_BYPASS"


def test_plan_is_order_independent_and_hash_bound() -> None:
    rows = [_row("b", "active"), _row("a", "pending")]
    first = lifecycle.build_plan(rows, database_sha256="b" * 64)
    second = lifecycle.build_plan(reversed(rows), database_sha256="b" * 64)
    assert first == second
    body = {key: value for key, value in first.items() if key != "plan_sha256"}
    assert first["plan_sha256"] == hashlib.sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    assert first["runtime_action"] == "NONE"
    assert first["apply_implemented"] is False


def test_unsupported_or_duplicate_rows_fail_closed() -> None:
    with pytest.raises(lifecycle.LifecycleProjectionError, match="requires a verdict"):
        lifecycle.project_row(_row("x", "done", None))
    with pytest.raises(lifecycle.LifecycleProjectionError, match="unsupported verdict"):
        lifecycle.project_row(_row("x", "done", "FUTURE_UNKNOWN"))
    with pytest.raises(lifecycle.LifecycleProjectionError, match="unsupported verdict"):
        lifecycle.project_row(
            _row("x", "failed", "FUTURE_UNKNOWN", {"quarantined": True})
        )
    with pytest.raises(lifecycle.LifecycleProjectionError, match="must not carry verdict"):
        lifecycle.project_row(_row("x", "pending", "PASS"))
    with pytest.raises(lifecycle.LifecycleProjectionError, match="requires legacy status"):
        lifecycle.project_row(_row("x", "failed", "PASS_PORTFOLIO"))
    with pytest.raises(lifecycle.LifecycleProjectionError, match="duplicate"):
        lifecycle.build_plan(
            [_row("x", "pending"), _row("x", "active")],
            database_sha256="c" * 64,
        )


def test_database_inventory_uses_read_only_projection(tmp_path: Path) -> None:
    database = tmp_path / "factory.db"
    connection = sqlite3.connect(database)
    connection.execute(
        "CREATE TABLE work_items (id TEXT, status TEXT, verdict TEXT, payload_json TEXT, updated_at TEXT)"
    )
    connection.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?)",
        ("one", "done", "NEED_MORE_DATA", "{}", "2026-07-29T12:00:00Z"),
    )
    connection.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?)",
        ("two", "done", "PASS_LOWFREQ", "{}", "2026-07-29T12:00:00Z"),
    )
    connection.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?)",
        ("three", "done", "PASS_PORTFOLIO", "{}", "2026-07-29T12:00:00Z"),
    )
    connection.commit()
    connection.close()
    before = database.read_bytes()

    plan = lifecycle.inventory_database(database)

    assert database.read_bytes() == before
    assert plan["typed_state_counts"]["WAITING_INPUT"] == 1
    assert plan["typed_state_counts"]["SUCCEEDED"] == 2
    assert plan["database_sha256"] == hashlib.sha256(before).hexdigest()
