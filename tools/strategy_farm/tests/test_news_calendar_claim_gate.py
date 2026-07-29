import json
import sqlite3
import sys
from pathlib import Path
from unittest import mock

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


BLOCKED = {
    "ok": False,
    "status": "MISSING_COMMON",
    "principal": "TEST\\calendar-worker",
    "source_dir": r"D:\QM\data\news_calendar",
    "common_dir": r"C:\Users\calendar-worker\AppData\Roaming\MetaQuotes\Terminal\Common\Files",
    "missing_common_paths": ["missing.csv"],
}


def _insert_item(
    root: Path,
    *,
    item_id: str = "wi-calendar",
    status: str = "pending",
    claimed_by: str | None = None,
    payload: dict | None = None,
    attempt_count: int = 2,
) -> dict:
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                attempt_count, parent_task_id, evidence_path, claimed_by,
                payload_json, created_at, updated_at
            ) VALUES (?, 'backtest', 'P2', 'QM5_9999', 'EURUSD.DWX',
                      'dummy.set', ?, NULL, ?, NULL, NULL, ?, ?, ?, ?)
            """,
            (
                item_id,
                status,
                attempt_count,
                claimed_by,
                json.dumps(payload or {}, sort_keys=True),
                now,
                now,
            ),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
    return dict(row)


def _row_state(root: Path, item_id: str = "wi-calendar") -> tuple:
    with farmctl.connect(root) as conn:
        return tuple(
            conn.execute(
                "SELECT status, claimed_by, attempt_count, payload_json FROM work_items WHERE id=?",
                (item_id,),
            ).fetchone()
        )


def _ledger_count(root: Path, item_id: str = "wi-calendar") -> int:
    with farmctl.connect(root) as conn:
        return int(
            conn.execute(
                "SELECT count(*) FROM claim_class_ledger WHERE work_item_id=?", (item_id,)
            ).fetchone()[0]
        )


def test_terminal_worker_preclaim_failure_leaves_item_and_attempt_unchanged(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    _insert_item(root)
    before = _row_state(root)

    with mock.patch.object(farmctl, "_news_calendar_preflight", return_value=BLOCKED):
        result = terminal_worker.claim_atomic(root, "T1")

    assert result["claimed"] is False
    assert result["reason"] == "news_calendar_preflight_failed"
    assert result["calendar_status"] == "MISSING_COMMON"
    assert result["principal"] == BLOCKED["principal"]
    assert result["common_dir"] == BLOCKED["common_dir"]
    assert _row_state(root) == before
    assert _ledger_count(root) == 0


def test_targeted_preclaim_failure_does_not_claim_under_factory_off(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    _insert_item(root)
    (root / "state" / "FACTORY_OFF.flag").write_text("intentional\n", encoding="utf-8")
    before = _row_state(root)

    with mock.patch.object(farmctl, "_news_calendar_preflight", return_value=BLOCKED):
        result = terminal_worker.claim_specific_atomic(root, "T1", "wi-calendar")

    assert result["claimed"] is False
    assert result["reason"] == "news_calendar_preflight_failed"
    assert _row_state(root) == before


def test_shared_spawn_boundary_never_calls_runner_when_calendar_is_bad(
    tmp_path: Path,
) -> None:
    row = {
        "phase": "P2",
        "id": "wi-calendar",
    }
    with (
        mock.patch.object(farmctl, "_news_calendar_preflight", return_value=BLOCKED),
        mock.patch.object(
            farmctl,
            "_spawn_run_smoke_for_work_item",
            side_effect=AssertionError("runner must not start"),
        ),
        mock.patch.object(
            farmctl,
            "_spawn_phase_runner_for_work_item",
            side_effect=AssertionError("phase runner must not start"),
        ),
    ):
        result = farmctl._spawn_work_item_runner(tmp_path, row, "T1")

    assert result["spawned"] is False
    assert result["calendar_preflight_blocked"] is True
    assert result["reason"] == "NEWS_CALENDAR_MISSING_COMMON"


def test_terminal_prespawn_toctou_releases_claim_and_ledger_without_attempt(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    claimed_at = "2026-07-29T10:00:00Z"
    item = _insert_item(
        root,
        status="active",
        claimed_by="T1",
        payload={
            "claimed_at_iso": claimed_at,
            "claimed_by_worker_pid": 12345,
            "terminal": "T1",
            "keep": "original",
        },
    )
    with farmctl.connect(root) as conn:
        farmctl.record_claim_ledger(conn, "T1", item["id"], "priority", claimed_at)
        conn.commit()
    assert _ledger_count(root) == 1

    with (
        mock.patch.object(farmctl, "_news_calendar_preflight", return_value=BLOCKED),
        mock.patch.object(terminal_worker, "_work_item_preflight_failure", return_value=None),
        mock.patch.object(
            terminal_worker,
            "_prepare_staged_ex5",
            side_effect=AssertionError("staging must not run after calendar failure"),
        ),
        mock.patch.object(farmctl, "_pid_tree_exists", return_value=False),
    ):
        result = terminal_worker._run_claimed_item(root, item, "T1", 30)

    status, terminal, attempt, payload_json = _row_state(root)
    assert result["action"] == "calendar_preflight_deferred"
    assert result["claim_released"] is True
    assert result["attempt_count_unchanged"] is True
    assert status == "pending"
    assert terminal is None
    assert attempt == 2
    assert json.loads(payload_json) == {"keep": "original"}
    assert _ledger_count(root) == 0


def test_dispatcher_preclaim_gate_never_claims_or_spawns(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    _insert_item(root)
    before = _row_state(root)

    with (
        mock.patch.object(farmctl, "active_mt5_terminals", return_value=["T1"]),
        mock.patch.object(farmctl, "_running_mt5_terminals", return_value=set()),
        mock.patch.object(farmctl, "_news_calendar_preflight", return_value=BLOCKED),
        mock.patch.object(
            farmctl,
            "_spawn_work_item_runner",
            side_effect=AssertionError("spawn must not run"),
        ),
    ):
        result = farmctl.dispatch_work_items(root)

    assert _row_state(root) == before
    assert _ledger_count(root) == 0
    deferred = [
        action for action in result["actions"] if action["action"] == "calendar_preflight_deferred"
    ]
    assert len(deferred) == 1
    assert deferred[0]["status"] == "MISSING_COMMON"
    assert deferred[0]["principal"] == BLOCKED["principal"]
    assert deferred[0]["common_dir"] == BLOCKED["common_dir"]
