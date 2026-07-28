from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _task(
    con,
    *,
    task_id: str,
    kind: str,
    status: str,
    payload: dict,
    created_at: str,
) -> None:
    con.execute(
        "INSERT INTO tasks "
        "(id, kind, status, source_id, card_id, payload_json, created_at, updated_at) "
        "VALUES (?, ?, ?, NULL, NULL, ?, ?, ?)",
        (task_id, kind, status, json.dumps(payload), created_at, created_at),
    )


def _work_item(
    con,
    *,
    item_id: str,
    ea_id: str,
    phase: str,
    symbol: str,
    status: str,
    verdict: str | None,
    updated_at: str,
) -> None:
    con.execute(
        "INSERT INTO work_items "
        "(id, kind, phase, ea_id, symbol, setfile_path, status, verdict, "
        "attempt_count, parent_task_id, evidence_path, claimed_by, payload_json, "
        "created_at, updated_at) "
        "VALUES (?, 'backtest', ?, ?, ?, ?, ?, ?, 1, NULL, NULL, NULL, '{}', ?, ?)",
        (
            item_id,
            phase,
            ea_id,
            symbol,
            f"sets/{ea_id}_{symbol}_{phase}.set",
            status,
            verdict,
            updated_at,
            updated_at,
        ),
    )


def test_pipeline_view_uses_work_items_over_later_failed_build_and_handles_string_review(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as con:
        _task(
            con,
            task_id="build-late-failure",
            kind="build_ea",
            status="failed",
            payload={"ea_id": "QM5_10035", "slug": "example"},
            created_at="2026-07-28T20:00:00Z",
        )
        _task(
            con,
            task_id="review-string",
            kind="ea_review",
            status="done",
            payload={"ea_id": "QM5_10035", "verdict": "APPROVE_FOR_BACKTEST"},
            created_at="2026-07-20T20:00:00Z",
        )
        _work_item(
            con,
            item_id="q03-pass",
            ea_id="QM5_10035",
            phase="Q03",
            symbol="EURUSD.DWX",
            status="done",
            verdict="PASS",
            updated_at="2026-06-28T12:00:00Z",
        )
        _work_item(
            con,
            item_id="q04-pass-soft",
            ea_id="QM5_10035",
            phase="Q04",
            symbol="EURUSD.DWX",
            status="done",
            verdict="PASS_SOFT",
            updated_at="2026-06-29T12:00:00Z",
        )
        _work_item(
            con,
            item_id="q05-fail",
            ea_id="QM5_10035",
            phase="Q05",
            symbol="EURUSD.DWX",
            status="done",
            verdict="FAIL",
            updated_at="2026-06-30T12:00:00Z",
        )
        con.commit()

    view = farmctl.pipeline_view(root)
    ea = next(row for row in view["eas"] if row["ea_id"] == "QM5_10035")

    assert view["per_ea_source"] == "work_items_with_task_metadata"
    assert ea["per_ea_source"] == "work_items"
    assert ea["review"]["verdict"] == "APPROVE_FOR_BACKTEST"
    assert ea["build"]["status"] == "failed"
    assert ea["phases"]["Q03"]["verdict"] == "PASS"
    assert ea["phases"]["Q04"]["verdict"] == "PASS_SOFT"
    assert ea["current_stage"] == "Q05_fail"
    assert ea["current_stage"] != "build_failed"


def test_pipeline_view_pass_family_dominates_fail_within_phase(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as con:
        _work_item(
            con,
            item_id="q03-fail-newer",
            ea_id="10002",
            phase="P3",
            symbol="EURUSD.DWX",
            status="done",
            verdict="FAIL",
            updated_at="2026-07-28T12:00:00Z",
        )
        _work_item(
            con,
            item_id="q03-pass-older",
            ea_id="QM5_10002",
            phase="Q03",
            symbol="GBPUSD.DWX",
            status="done",
            verdict="PASS",
            updated_at="2026-07-27T12:00:00Z",
        )
        con.commit()

    view = farmctl.pipeline_view(root)
    ea = next(row for row in view["eas"] if row["ea_id"] == "QM5_10002")

    assert list(ea["phases"]) == ["Q03"]
    assert ea["phases"]["Q03"]["verdict"] == "PASS"
    assert ea["phases"]["Q03"]["work_item_count"] == 2
    assert ea["current_stage"] == "Q03_pass"


def test_pipeline_view_ignores_non_pipeline_tasks_and_normalizes_lowercase_phase(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as con:
        _task(
            con,
            task_id="maintenance-uuid",
            kind="ops_issue",
            status="pending",
            payload={"title": "not an EA"},
            created_at="2026-07-28T12:00:00Z",
        )
        _work_item(
            con,
            item_id="q03-lowercase",
            ea_id="10003",
            phase="q03",
            symbol="EURUSD.DWX",
            status="done",
            verdict="PASS",
            updated_at="2026-07-28T12:00:00Z",
        )
        con.commit()

    view = farmctl.pipeline_view(root)

    assert [row["ea_id"] for row in view["eas"]] == ["QM5_10003"]
    assert list(view["eas"][0]["phases"]) == ["Q03"]
