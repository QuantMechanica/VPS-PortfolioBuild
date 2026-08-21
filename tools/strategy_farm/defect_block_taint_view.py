"""Read-only historical defect-block taint view for ``work_items``.

15 EAs were formally BLOCKED on 2026-08-16 in ``agent_tasks`` for documented
correctness defects (host-slot magic conflation, unwired strategy inputs,
framework violations, stale wiring, and related build/review failures). The
block held: independently reverified here, zero work_items rows exist for
any of these (EA, symbol) pairs with ``created_at`` after the block event.
But the 103 gate rows they produced *before* the block (44 of them PASS, at
Q02/Q03) sit in ``work_items`` indistinguishable from clean evidence in
every raw count.

Mirrors the MNT-016 pattern (``work_item_clean_view.py``, commit 9d9259dec):
never rewrite ``work_items``. A TEMP view projects a taint marker derived
from a frozen, source-cited registry, installed on a read-only connection
with ``query_only`` asserted. The registry is data, not a live status check
-- it answers "did this row predate a documented defect-block event for its
EA", which stays true even if the EA is later repaired and rebuilt.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
from collections import Counter
from pathlib import Path
from typing import Any


TAINT_VIEW_NAME = "work_items_defect_block_taint"
TAINT_VIEW_SCHEMA = "qm.work_items.defect_block_taint_view.v1"

# Frozen registry: ea_id (bare numeric, as carried in the BLOCKED task
# payloads) -> defect record. blocked_at is the earliest BLOCKED verdict
# timestamp found in agent_tasks for that EA (the moment it stopped
# producing new gate rows). source_task_id is that task's id, auditable via
# `agent_router.py list-tasks` / direct agent_tasks lookup. Populated and
# independently re-verified 2026-08-21 (see evidence doc
# docs/ops/evidence/2026-08-21_defect_block_taint_marker.md).
DEFECT_BLOCKED_EAS: dict[str, dict[str, str]] = {
    "10648": {
        "defect_class": "host_slot_magic_conflation",
        "source_task_id": "5f1f643e-e343-41bd-a17c-6bc21ddeba47",
        "blocked_at": "2026-08-16T21:23:09+00:00",
        "summary": "req.symbol_slot not wired to qm_magic_slot_offset",
    },
    "10649": {
        "defect_class": "host_slot_magic_conflation",
        "source_task_id": "3371d2a0-7569-46f6-8f08-a9c951ee1d3d",
        "blocked_at": "2026-08-16T21:23:09+00:00",
        "summary": "req.symbol_slot not wired to qm_magic_slot_offset",
    },
    "10973": {
        "defect_class": "host_slot_magic_conflation",
        "source_task_id": "93481b8d-1a1d-4506-9064-12b0dc740c4e",
        "blocked_at": "2026-08-16T21:23:10+00:00",
        "summary": "req.symbol_slot not wired to qm_magic_slot_offset",
    },
    "11301": {
        "defect_class": "spec_gate_and_smoke_schema",
        "source_task_id": "efe9876c-ca5d-4405-ae94-65d804e3c715",
        "blocked_at": "2026-08-16T21:30:08+00:00",
        "summary": "FAIL: SPEC gate and build-result smoke schema",
    },
    "11302": {
        "defect_class": "spec_gate_and_smoke_schema",
        "source_task_id": "dfc248dc-ce63-4b55-bbfb-1ff701db0d91",
        "blocked_at": "2026-08-16T21:30:08+00:00",
        "summary": "FAIL: SPEC gate and build-result smoke schema",
    },
    "11689": {
        "defect_class": "raw_series_noncanonical_symbol",
        "source_task_id": "b36ca851-5323-405b-9a22-f9c5a7c596ae",
        "blocked_at": "2026-08-16T21:30:10+00:00",
        "summary": "FAIL: raw series calls and noncanonical GER40.DWX registration",
    },
    "11897": {
        "defect_class": "unwired_strategy_inputs",
        "source_task_id": "9cc2e6ea-bd05-4a95-9ea6-3e26a724769a",
        "blocked_at": "2026-08-16T21:23:13+00:00",
        "summary": "unwired inputs: strategy_timeframe, strategy_fractal_lookback_bars, "
        "strategy_fractal_filter_pips, strategy_time_filter_majors_start_gmt "
        "(also re-failed 2026-08-16T21:30:09Z review: 20 framework violations, "
        "invalid fractal shifts, stale position context)",
    },
    "11898": {
        "defect_class": "timeout_wallclock_and_missing_build_result",
        "source_task_id": "7ac78733-f755-445e-a36c-1e21f7d6b600",
        "blocked_at": "2026-08-16T21:30:10+00:00",
        "summary": "FAIL: 96-bar timeout implemented as wall-clock seconds; canonical build_result missing",
    },
    "12352": {
        "defect_class": "zero_trade_smoke_and_symbol_mismatch",
        "source_task_id": "23a6f9a0-0044-428d-af46-4774e028f60d",
        "blocked_at": "2026-08-16T21:30:10+00:00",
        "summary": "FAIL: 0-trade smoke and blocked build result; card/registry symbol mismatch",
    },
    "20070": {
        "defect_class": "stale_framework_wiring",
        "source_task_id": "fe1f8186-798a-41f7-8909-ecdaa522581a",
        "blocked_at": "2026-08-16T21:30:11+00:00",
        "summary": "FAIL: canonical RETIRE; stale framework wiring; session filter suppresses exits",
    },
    "20071": {
        "defect_class": "stale_framework_wiring",
        "source_task_id": "47666b69-24c3-48f1-a660-e74c7396c467",
        "blocked_at": "2026-08-16T21:30:12+00:00",
        "summary": "FAIL: canonical RETIRE; stale framework wiring; spread filter suppresses exits",
    },
    "20179": {
        "defect_class": "invalid_stop_out_of_charter",
        "source_task_id": "9df810a8-9783-4f10-9378-83989f69ac36",
        "blocked_at": "2026-08-16T21:30:13+00:00",
        "summary": "FAIL: fresh strict build contradicts artifact; invalid-stop cases; incomplete/out-of-charter card",
    },
    "2076": {
        "defect_class": "unwired_strategy_inputs",
        "source_task_id": "1e9d9d3e-2060-408a-8cc3-9025a49d021b",
        "blocked_at": "2026-08-16T21:23:23+00:00",
        "summary": "unwired inputs: strategy_stddev_period, strategy_volume_mean_bars "
        "(also re-failed 2026-08-16T21:30:13Z review: fresh strict build "
        "contradicts artifact; stale exit wiring; Edge Lab DD breach)",
    },
    "9354": {
        "defect_class": "build_check_failures_and_state_mutation",
        "source_task_id": "982fe1f3-c9e2-430b-a080-093f59a5b012",
        "blocked_at": "2026-08-16T21:30:13+00:00",
        "summary": "FAIL: canonical build_check 31 failures; pre-open state mutation",
    },
    "9501": {
        "defect_class": "time_sensitive_strategy_params_missing",
        "source_task_id": "037da632-6b8f-435f-b142-3829e442a2a9",
        "blocked_at": "2026-08-16T21:26:18+00:00",
        "summary": "validate_build_guardrails: time_sensitive_strategy_params_missing (W1 entry-clock defect)",
    },
}


def _bare_ea_id(ea_id: Any) -> str:
    """Strip the QM5_ prefix work_items.ea_id carries, per Hard Rule (strip QM5_)."""

    text = str(ea_id or "")
    return text[4:] if text.startswith("QM5_") else text


def taint_record(ea_id: Any) -> dict[str, str] | None:
    return DEFECT_BLOCKED_EAS.get(_bare_ea_id(ea_id))


def install_taint_view(connection: sqlite3.Connection) -> None:
    """Install the defect-block taint TEMP view on an existing connection."""

    connection.create_function(
        "qm_defect_taint_field",
        2,
        lambda ea_id, field: (taint_record(ea_id) or {}).get(field),
        deterministic=True,
    )
    connection.create_function(
        "qm_defect_taint_flag",
        1,
        lambda ea_id: int(taint_record(ea_id) is not None),
        deterministic=True,
    )
    connection.execute(f"DROP VIEW IF EXISTS temp.{TAINT_VIEW_NAME}")
    available = {
        str(row[1]) for row in connection.execute("PRAGMA main.table_info(work_items)")
    }
    if not available:
        raise sqlite3.OperationalError("required main.work_items table is missing")

    def source(column: str) -> str:
        return column if column in available else "NULL"

    ea_col = source("ea_id")
    connection.execute(
        f"""
        CREATE TEMP VIEW {TAINT_VIEW_NAME} AS
        SELECT
            {source('id')} AS id,
            {source('kind')} AS kind,
            {source('phase')} AS phase,
            {ea_col} AS ea_id,
            {source('symbol')} AS symbol,
            {source('status')} AS status,
            {source('verdict')} AS verdict,
            {source('created_at')} AS created_at,
            {source('updated_at')} AS updated_at,
            qm_defect_taint_flag({ea_col}) AS defect_block_taint,
            qm_defect_taint_field({ea_col}, 'defect_class') AS defect_block_class,
            qm_defect_taint_field({ea_col}, 'source_task_id') AS defect_block_source_task_id,
            qm_defect_taint_field({ea_col}, 'blocked_at') AS defect_block_at,
            qm_defect_taint_field({ea_col}, 'summary') AS defect_block_summary,
            '{TAINT_VIEW_SCHEMA}' AS taint_view_schema
        FROM main.work_items
        """
    )


def open_taint_view_connection(database: Path | str) -> sqlite3.Connection:
    """Open the source read-only, install the TEMP view, then fail closed."""

    resolved = Path(database).resolve()
    connection = sqlite3.connect(resolved.as_uri() + "?mode=ro", uri=True)
    try:
        install_taint_view(connection)
        connection.execute("PRAGMA query_only=ON")
        enabled = connection.execute("PRAGMA query_only").fetchone()
        if enabled is None or int(enabled[0]) != 1:
            raise sqlite3.OperationalError("SQLite query_only could not be asserted")
    except BaseException:
        connection.close()
        raise
    return connection


def audit_taint_view(connection: sqlite3.Connection) -> dict[str, Any]:
    """Summarize tainted rows and prove the after-block invariant."""

    connection.row_factory = sqlite3.Row
    rows = connection.execute(
        f"SELECT id, ea_id, phase, status, verdict, created_at, "
        f"defect_block_taint, defect_block_class, defect_block_at "
        f"FROM {TAINT_VIEW_NAME} WHERE defect_block_taint = 1"
    ).fetchall()

    by_ea: Counter[str] = Counter()
    by_phase: Counter[str] = Counter()
    by_verdict: Counter[str] = Counter()
    pass_by_phase: Counter[str] = Counter()
    after_block_violations: list[str] = []

    for row in rows:
        by_ea[row["ea_id"]] += 1
        by_phase[row["phase"] or "<null>"] += 1
        by_verdict[row["verdict"] or "<null>"] += 1
        verdict = str(row["verdict"] or "").upper()
        if verdict.startswith("PASS"):
            pass_by_phase[row["phase"] or "<null>"] += 1
        blocked_at = row["defect_block_at"]
        created_at = row["created_at"]
        if blocked_at and created_at and str(created_at) > str(blocked_at):
            after_block_violations.append(str(row["id"]))

    registry_eas = set(DEFECT_BLOCKED_EAS)
    seen_eas = {_bare_ea_id(ea) for ea in by_ea}
    return {
        "schema": TAINT_VIEW_SCHEMA,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "registry_size": len(DEFECT_BLOCKED_EAS),
        "registry_eas_with_no_work_items": sorted(registry_eas - seen_eas),
        "tainted_row_count": len(rows),
        "pass_row_count": sum(pass_by_phase.values()),
        "by_ea": dict(sorted(by_ea.items())),
        "by_phase": dict(sorted(by_phase.items())),
        "by_verdict": dict(sorted(by_verdict.items())),
        "pass_rows_by_phase": dict(sorted(pass_by_phase.items())),
        "after_block_invariant": {
            "valid": not after_block_violations,
            "violation_count": len(after_block_violations),
            "sample_ids": after_block_violations[:20],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db",
        type=Path,
        default=Path(r"D:\QM\strategy_farm\state\farm_state.sqlite"),
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    with open_taint_view_connection(args.db) as connection:
        report = audit_taint_view(connection)
    report["source_db"] = str(args.db.resolve())
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    else:
        print(rendered, end="")
    return 0 if report["after_block_invariant"]["valid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
