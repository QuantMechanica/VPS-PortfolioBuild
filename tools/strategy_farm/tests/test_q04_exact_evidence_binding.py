"""The worker must grade the exact durable Q04 work-item aggregate."""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402

farmctl = terminal_worker.farmctl


def _insert_q02_item(
    root: Path,
    *,
    item_id: str,
    summary: dict,
    attempt_count: int = 0,
) -> Path:
    farmctl.init_db(root)
    report_root = root / "reports" / item_id
    summary_path = report_root / "QM5_1001" / "run" / "summary.json"
    summary_path.parent.mkdir(parents=True)
    summary_path.write_text(json.dumps(summary), encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
               attempt_count, parent_task_id, evidence_path, claimed_by,
               payload_json, created_at, updated_at)
            VALUES
              (?, 'backtest', 'Q02', 'QM5_1001', 'EURUSD.DWX', 'dummy.set',
               'active', NULL, ?, NULL, NULL, 'T2', ?, ?, ?)
            """,
            (
                item_id,
                attempt_count,
                json.dumps({"report_root": str(report_root)}, sort_keys=True),
                now,
                now,
            ),
        )
        conn.commit()
    return summary_path


def test_exact_q04_evidence_path_is_fail_closed(tmp_path: Path) -> None:
    exact = tmp_path / "pipeline" / "QM5_1001" / "Q04" / "EURUSD.DWX__wi-1" / "aggregate.json"
    exact.parent.mkdir(parents=True)
    exact.write_text(
        json.dumps({"phase": "Q04", "verdict": "PASS", "reason": "exact"}),
        encoding="utf-8",
    )
    volatile_wrong = (
        tmp_path
        / "work_items"
        / "wi-1"
        / "QM5_1001"
        / "Q04"
        / "EURUSD.DWX"
        / "aggregate.json"
    )
    volatile_wrong.parent.mkdir(parents=True)
    volatile_wrong.write_text(
        json.dumps({"phase": "Q04", "verdict": "FAIL", "reason": "wrong"}),
        encoding="utf-8",
    )
    item = {"phase": "Q04", "ea_id": "QM5_1001", "symbol": "EURUSD.DWX"}
    payload = {
        "phase_evidence_path": str(exact),
        "report_root": str(tmp_path / "work_items" / "wi-1"),
    }

    found = terminal_worker._find_work_item_summary_data(item, payload)  # type: ignore[arg-type]

    assert found is not None
    assert found[0] == exact
    assert found[1]["reason"] == "exact"

    exact.unlink()
    assert terminal_worker._find_work_item_summary_data(  # type: ignore[arg-type]
        item, payload
    ) is None


def test_q02_cold_summary_requeues_with_signature_and_bound(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    _insert_q02_item(
        root,
        item_id="wi-cold",
        summary={
            "result": "FAIL",
            "reason_classes": ["NO_HISTORY", "INCOMPLETE_RUNS"],
            "runs": [
                {
                    "status": "INVALID",
                    "failure": "NO_HISTORY",
                    "invalid_report_reasons": ["BARS_ZERO"],
                    "total_trades": 0,
                }
            ],
        },
    )

    result = terminal_worker._finish_work_item(root, "wi-cold", exit_code=1)

    assert result["status"] == "pending"
    assert result["matched_signature"] in {"NO_HISTORY", "INCOMPLETE_RUNS", "BARS_ZERO"}
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status, verdict, attempt_count, payload_json "
            "FROM work_items WHERE id='wi-cold'"
        ).fetchone()
    payload = json.loads(row["payload_json"])
    assert row["status"] == "pending"
    assert row["verdict"] is None
    assert row["attempt_count"] == 1
    assert payload["cold_cache_retry_attempt"] == 1
    assert payload["cold_cache_retry_cap"] == terminal_worker.MAX_WORK_ITEM_RETRIES
    assert payload["cold_cache_signature"] == result["matched_signature"]


def test_q02_completed_strategy_fail_is_not_retried(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    _insert_q02_item(
        root,
        item_id="wi-strategy",
        summary={
            "result": "FAIL",
            "reason_classes": ["MIN_TRADES_NOT_MET"],
            "runs": [
                {
                    "status": "INVALID",
                    "failure": "NO_HISTORY",
                    "invalid_report_reasons": ["BARS_ZERO"],
                    "total_trades": 0,
                },
                {"status": "OK", "total_trades": 3, "profit_factor": 0.8},
            ],
        },
    )

    result = terminal_worker._finish_work_item(root, "wi-strategy", exit_code=1)

    assert result["status"] == "done"
    assert result["verdict"] == "FAIL"
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status, verdict, attempt_count FROM work_items "
            "WHERE id='wi-strategy'"
        ).fetchone()
    assert tuple(row) == ("done", "FAIL", 0)


def test_q02_cold_summary_retry_cap_exhausts_to_infra(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    summary_path = _insert_q02_item(
        root,
        item_id="wi-cold-cap",
        attempt_count=terminal_worker.MAX_WORK_ITEM_RETRIES - 1,
        summary={
            "result": "FAIL",
            "reason_classes": ["INCOMPLETE_RUNS"],
            "runs": [{"status": "INVALID", "total_trades": 0}],
        },
    )

    result = terminal_worker._finish_work_item(root, "wi-cold-cap", exit_code=1)

    assert result["status"] == "failed"
    assert result["verdict"] == "INFRA_FAIL"
    assert result["attempt"] == terminal_worker.MAX_WORK_ITEM_RETRIES
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status, verdict, attempt_count, evidence_path, payload_json "
            "FROM work_items WHERE id='wi-cold-cap'"
        ).fetchone()
    payload = json.loads(row["payload_json"])
    assert row["status"] == "failed"
    assert row["verdict"] == "INFRA_FAIL"
    assert row["attempt_count"] == terminal_worker.MAX_WORK_ITEM_RETRIES
    assert Path(row["evidence_path"]) == summary_path
    assert payload["verdict_reason"].startswith("cold_cache_retries_exhausted:")
