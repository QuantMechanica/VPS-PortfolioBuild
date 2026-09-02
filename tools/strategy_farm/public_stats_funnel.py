#!/usr/bin/env python3
"""public_stats_funnel.py — read-only pipeline-funnel counts for stats.json.

Emits a single compact JSON object on stdout with the redacted pipeline-funnel
counts that the public ``stats.json`` exposes.  The exporter
(``scripts/export_public_snapshot.ps1``) calls this helper and merges the result
into ``$publicStats`` so the funnel SQL lives in one unit-testable place instead
of inline PowerShell.

Read-only over the farm DB (``mode=ro`` URI); it never mutates state.

Emitted keys (all integers, all counts — never names, ids, paths or amounts):

* ``q02_baseline_pass``    — DISTINCT (ea_id, symbol) with a done PASS at Q02
* ``q04_walkforward_pass`` — DISTINCT (ea_id, symbol) with a done PASS at Q04
* ``q08_davey_stats_pass`` — DISTINCT (ea_id, symbol) with a done PASS at Q08
* ``portfolio_candidates`` — DISTINCT (ea_id, symbol) done CONFIG_LOCKED at Q10_NEWS
* ``symbols``              — DISTINCT non-empty symbols across all done rows
* ``research_sources``     — row count of the ``sources`` table (OMITTED when the
                             table does not exist)

The archive KPIs (archive_total / archive_passed_q10 / archive_failed) are NOT
computed here: they are derived by the exporter from the strategy-archive
projection (``website_archive_contract.py``) so the archive page and the funnel
share one producer.

Run:  python tools/strategy_farm/public_stats_funnel.py --db <farm_state.sqlite>
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")

# key -> phase for the "done + verdict=PASS, DISTINCT ea_id|symbol" counts.
PASS_GATE_PHASES = {
    "q02_baseline_pass": "Q02",
    "q04_walkforward_pass": "Q04",
    "q08_davey_stats_pass": "Q08",
}


def open_ro(db_path: str | Path) -> sqlite3.Connection:
    """Open the farm DB strictly read-only (mode=ro URI)."""
    uri = f"file:{Path(db_path).as_posix()}?mode=ro"
    return sqlite3.connect(uri, uri=True)


def _scalar(conn: sqlite3.Connection, sql: str, params: tuple = ()) -> int:
    row = conn.execute(sql, params).fetchone()
    return int((row[0] if row and row[0] is not None else 0))


def _distinct_pair_pass(conn: sqlite3.Connection, phase: str) -> int:
    """DISTINCT ea_id|symbol of done PASS work_items for one phase."""
    return _scalar(
        conn,
        "SELECT COUNT(DISTINCT ea_id || '|' || symbol) FROM work_items "
        "WHERE status = 'done' AND verdict = 'PASS' AND phase = ?",
        (phase,),
    )


def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        (name,),
    ).fetchone()
    return row is not None


def compute_funnel(conn: sqlite3.Connection) -> dict[str, int]:
    """Return the redacted pipeline-funnel counts as a plain dict."""
    funnel: dict[str, int] = {}
    for key, phase in PASS_GATE_PHASES.items():
        funnel[key] = _distinct_pair_pass(conn, phase)

    funnel["portfolio_candidates"] = _scalar(
        conn,
        "SELECT COUNT(DISTINCT ea_id || '|' || symbol) FROM work_items "
        "WHERE phase = 'Q10_NEWS' AND status = 'done' "
        "AND verdict = 'CONFIG_LOCKED'",
    )

    # Distinct real symbols across every done row; the empty-symbol basket host
    # label is not a tradeable symbol and is excluded.
    funnel["symbols"] = _scalar(
        conn,
        "SELECT COUNT(DISTINCT symbol) FROM work_items "
        "WHERE status = 'done' AND symbol IS NOT NULL AND symbol <> ''",
    )

    if _table_exists(conn, "sources"):
        funnel["research_sources"] = _scalar(conn, "SELECT COUNT(*) FROM sources")

    return funnel


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Read-only public stats funnel counts (JSON on stdout)."
    )
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    args = ap.parse_args(argv)

    if not Path(args.db).is_file():
        print(f"farm DB not found: {args.db}", file=sys.stderr)
        return 2

    conn = open_ro(args.db)
    try:
        funnel = compute_funnel(conn)
    finally:
        conn.close()

    print(json.dumps(funnel, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
