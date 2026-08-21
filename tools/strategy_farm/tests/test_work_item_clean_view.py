from __future__ import annotations

import ast
import datetime as dt
import json
import re
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import work_item_clean_view as clean
from tools.strategy_farm.dashboards import render_dashboards


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    kind TEXT,
    phase TEXT,
    ea_id TEXT,
    symbol TEXT,
    setfile_path TEXT,
    status TEXT,
    verdict TEXT,
    attempt_count INTEGER,
    parent_task_id TEXT,
    evidence_path TEXT,
    claimed_by TEXT,
    payload_json TEXT,
    created_at TEXT,
    updated_at TEXT
)
"""


def _row(status: str, verdict: str | None, payload: dict | str) -> dict:
    return {
        "id": "wi-1",
        "status": status,
        "verdict": verdict,
        "payload_json": payload if isinstance(payload, str) else json.dumps(payload),
    }


@pytest.mark.parametrize(
    ("raw_status", "verdict", "taxonomy", "expected_status"),
    [
        ("pending", None, "open", "pending"),
        ("active", None, "open", "active"),
        ("done", "PASS", "strategy", "done"),
        ("failed", "FAIL", "strategy", "done"),
        ("done", "ZERO_TRADES", "strategy", "done"),
        ("done", "INFRA_FAIL", "infra", "failed"),
        ("failed", "INVALID", "invalid", "failed"),
        ("failed", "RETIRE", "strategy", "done"),
        ("done", "DRAFT_DEFECT", "draft_defect", "done"),
        ("done", "REVIEW_REQUIRED", "review", "done"),
        ("done", "SUPERSEDED", "governance", "failed"),
    ],
)
def test_allowed_status_verdict_taxonomy_invariant(
    raw_status: str,
    verdict: str | None,
    taxonomy: str,
    expected_status: str,
) -> None:
    derived = clean.derive_work_item(_row(raw_status, verdict, {}))
    assert derived["status"] == expected_status
    assert derived["verdict_taxonomy"] == taxonomy
    assert derived["clean_view_valid"] is True
    assert clean.allowed_combination(
        derived["status"], derived["verdict"], derived["verdict_taxonomy"]
    )


def test_strategy_row_suppresses_stale_infra_reason_but_keeps_raw_fields() -> None:
    derived = clean.derive_work_item(
        _row(
            "failed",
            "PASS",
            {
                "verdict_taxonomy": "infra",
                "verdict_reason": "run_smoke_fail:REPORT_MISSING;TIMEOUT",
            },
        )
    )
    assert derived["status"] == "done"
    assert derived["verdict_taxonomy"] == "strategy"
    assert derived["verdict_reason"] is None
    assert derived["raw_status"] == "failed"
    assert derived["raw_verdict_taxonomy"] == "infra"
    assert derived["raw_verdict_reason"].startswith("run_smoke_fail")
    assert set(derived["clean_view_flags"]) >= {
        "status_restamped",
        "taxonomy_restamped",
        "reason_suppressed",
    }


def test_strategy_metric_reason_survives_and_infra_status_is_restamped() -> None:
    strategy = clean.derive_work_item(
        _row(
            "done",
            "PASS_SOFT",
            {"verdict_taxonomy": "strategy", "verdict_reason": "soft:2/3>floor,mean=1.11"},
        )
    )
    assert strategy["verdict_reason"] == "soft:2/3>floor,mean=1.11"

    infra = clean.derive_work_item(
        _row(
            "done",
            "INFRA_FAIL",
            {"verdict_taxonomy": "strategy", "verdict_reason": "ACTIVE_TIMEOUT"},
        )
    )
    assert infra["status"] == "failed"
    assert infra["verdict_taxonomy"] == "infra"
    assert infra["verdict_reason"] == "ACTIVE_TIMEOUT"
    assert infra["clean_view_valid"] is True


def test_unknown_or_terminal_null_combination_fails_closed() -> None:
    unknown = clean.derive_work_item(_row("done", "MYSTERY", {}))
    terminal_null = clean.derive_work_item(_row("done", None, {}))
    assert unknown["verdict_taxonomy"] == "unknown"
    assert unknown["clean_view_valid"] is False
    assert terminal_null["verdict_taxonomy"] == "unknown"
    assert terminal_null["clean_view_valid"] is False


def test_temp_view_is_query_only_and_does_not_rewrite_source() -> None:
    connection = sqlite3.connect(":memory:")
    connection.execute(WORK_ITEMS_DDL)
    payload = json.dumps(
        {"verdict_taxonomy": "strategy", "verdict_reason": "ACTIVE_TIMEOUT"}
    )
    connection.execute(
        "INSERT INTO work_items VALUES "
        "('wi', 'backtest', 'Q02', 'QM5_1', 'EURUSD', 'x.set', "
        "'done', 'INFRA_FAIL', 1, NULL, NULL, NULL, ?, '2026-08-21', '2026-08-21')",
        (payload,),
    )
    clean.install_clean_view(connection)
    connection.execute("PRAGMA query_only=ON")
    connection.row_factory = sqlite3.Row

    projected = dict(connection.execute("SELECT * FROM work_items_clean").fetchone())
    assert projected["status"] == "failed"
    assert projected["verdict_taxonomy"] == "infra"
    assert projected["raw_status"] == "done"
    assert json.loads(projected["clean_view_flags"]) == [
        "taxonomy_restamped",
        "status_restamped",
    ]
    with pytest.raises(sqlite3.OperationalError):
        connection.execute("UPDATE work_items SET status='failed'")
    assert connection.execute("SELECT status FROM main.work_items").fetchone()[0] == "done"


def test_archive_dashboard_consumes_clean_status(tmp_path: Path) -> None:
    state_dir = tmp_path / "state"
    state_dir.mkdir()
    database = state_dir / "farm_state.sqlite"
    now = (dt.datetime.now(dt.UTC) - dt.timedelta(minutes=1)).replace(microsecond=0).isoformat()
    with sqlite3.connect(database) as connection:
        connection.execute(WORK_ITEMS_DDL)
        connection.execute(
            "INSERT INTO work_items VALUES "
            "('wi', 'backtest', 'Q02', 'QM5_1', 'EURUSD', 'x.set', "
            "'done', 'INFRA_FAIL', 1, NULL, NULL, NULL, ?, ?, ?)",
            (
                json.dumps(
                    {"verdict_taxonomy": "strategy", "verdict_reason": "ACTIVE_TIMEOUT"}
                ),
                now,
                now,
            ),
        )
        connection.execute(
            "INSERT INTO work_items VALUES "
            "('wi-soft', 'backtest', 'Q06', 'QM5_2', 'GBPUSD', 'y.set', "
            "'done', 'PASS_SOFT', 1, NULL, NULL, NULL, ?, ?, ?)",
            (
                json.dumps(
                    {"verdict_taxonomy": "strategy", "verdict_reason": "soft:2/3>floor"}
                ),
                now,
                now,
            ),
        )

    archive = render_dashboards.collect_archive_v2(tmp_path, {})
    assert archive["cell_latest"][("QM5_1", "EURUSD")]["status"] == "failed"
    assert archive["recent"]["Q02"]["infra"] == 1
    assert archive["recent"]["Q06"]["passsoft"] == 1
    with sqlite3.connect(database) as connection:
        assert connection.execute(
            "SELECT status FROM work_items WHERE id='wi'"
        ).fetchone()[0] == "done"


def test_operator_renderers_do_not_query_raw_work_items_table() -> None:
    repo = Path(__file__).resolve().parents[3]
    raw_table = re.compile(r"\b(?:FROM|JOIN)\s+work_items\b", re.IGNORECASE)
    for relative in (
        Path("tools/strategy_farm/render_cockpit.py"),
        Path("tools/strategy_farm/dashboards/render_dashboards.py"),
    ):
        source = (repo / relative).read_text(encoding="utf-8")
        sql_literals = [
            node.value
            for node in ast.walk(ast.parse(source))
            if isinstance(node, ast.Constant)
            and isinstance(node.value, str)
            and "SELECT" in node.value.upper()
        ]
        assert sql_literals
        assert not [literal for literal in sql_literals if raw_table.search(literal)]
        assert any("work_items_clean" in literal for literal in sql_literals)
