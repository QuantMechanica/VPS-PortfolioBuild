"""MNT-016: Q08 INVALID rows are unsatisfiable against work_items_clean.

Both collect_q08_portfolio_rescue_for_ea (render_dashboards.py) and
q08_portfolio_rescue_snapshot (render_cockpit.py) filtered on
``status='done' AND verdict IN (...,'INVALID')``. But work_items_clean maps
any INVALID%% verdict to clean status='failed' (see work_item_clean_view.py's
status_sql CASE), never 'done' -- so the INVALID arm of that filter could
never match a single row. Both call sites' own tier-classifier functions
(_q08_rescue_tier / _q08_tier) already special-case verdict=='INVALID' as a
distinct display tier, which only makes sense if the surface was meant to
show these rows -- evidence-quality defects the portfolio gate can't
meaningfully rescue-judge, not silently-dropped candidates.

The fix: query status='failed' for the INVALID arm (matching what the clean
view actually derives) alongside status='done' for the real FAIL_SOFT/
FAIL_HARD/FAIL strategy-taxonomy rows.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

from tools.strategy_farm import render_cockpit
from tools.strategy_farm.dashboards import render_dashboards as dashboard


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    phase TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    status TEXT,
    verdict TEXT,
    payload_json TEXT,
    evidence_path TEXT,
    updated_at TEXT
);
"""


def _fixture_database(path: Path) -> None:
    with sqlite3.connect(path) as connection:
        connection.executescript(WORK_ITEMS_DDL)
        # raw status is 'done' (the run completed and produced a verdict);
        # verdict itself is INVALID -- the clean view derives status='failed'
        # from that, which is what makes the naive 'done'-only filter miss it.
        connection.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?)",
            ("q08-invalid", "Q08", "QM5_10848", "GDAXI.DWX", "done", "INVALID",
             '{"verdict_reason": "neighborhood_evidence_lineage_invalid"}',
             None, "2026-08-21T04:05:16+00:00"),
        )
        connection.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?)",
            ("q08-failsoft", "Q08", "QM5_20001", "EURUSD.DWX", "done", "FAIL_SOFT",
             '{}', None, "2026-08-20T00:00:00Z"),
        )


def test_dashboard_rescue_collector_surfaces_invalid_row(tmp_path: Path):
    root = tmp_path
    (root / "state").mkdir()
    db = root / "state" / "farm_state.sqlite"
    _fixture_database(db)

    rows = dashboard.collect_q08_portfolio_rescue_for_ea("QM5_10848", root)
    assert [r["symbol"] for r in rows] == ["GDAXI.DWX"]
    assert rows[0]["q08_tier"] == "INVALID"

    rows_soft = dashboard.collect_q08_portfolio_rescue_for_ea("QM5_20001", root)
    assert [r["symbol"] for r in rows_soft] == ["EURUSD.DWX"]
    assert rows_soft[0]["q08_tier"] == "FAIL_SOFT"


def test_cockpit_rescue_snapshot_surfaces_and_counts_invalid_row(tmp_path: Path, monkeypatch):
    db = tmp_path / "farm_state.sqlite"
    _fixture_database(db)
    monkeypatch.setattr(render_cockpit, "DB", db)

    snapshot = render_cockpit.q08_portfolio_rescue_snapshot()
    tiers_by_symbol = {r["symbol"]: r["tier"] for r in snapshot["rows"]}
    assert tiers_by_symbol["GDAXI.DWX"] == "INVALID"
    assert tiers_by_symbol["EURUSD.DWX"] == "FAIL_SOFT"
    assert snapshot["invalid"] == 1
    assert snapshot["soft"] == 1
    assert snapshot["hard"] == 0
