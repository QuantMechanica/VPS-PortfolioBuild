#!/usr/bin/env python3
"""Shared read-only progress model for the terminal-qualification goal.

The public :func:`path_to_25_metrics` function is the only data model consumed
by Mission Control v2, the 15-minute heartbeat, and the 06:00 OWNER report.  It
opens SQLite with ``mode=ro`` and ``query_only=ON`` and never mutates work
items, verdicts, holds, queues, or planner artifacts.
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import book_build_guard, gate_manifest, rebaseline_census


TARGET_QUALIFIED_PAIRS = 25
TERMINAL_CAPACITY = 10
_TERMINAL_STATUSES = frozenset({"done", "failed"})
_OPEN_STATUSES = frozenset({"pending", "active"})
_NEWS_CONCLUSIVE_VERDICTS = frozenset({
    "CONFIG_LOCKED",
    "REVIEW_REQUIRED",
    *rebaseline_census.PASS_ECON,
    *rebaseline_census.ECON_FAIL,
})
_NEWS_PASS_VERDICTS = frozenset({
    "CONFIG_LOCKED",
    *rebaseline_census.PASS_ECON,
})
_PLANNER_REASON_PREFIX = "rb-backfill-planner:"
_PLANNER_RERUN_INFRA = "rb-backfill-planner:rerun_infra"


def _open_ro(db: str | Path) -> sqlite3.Connection:
    path = Path(db).resolve().as_posix()
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA busy_timeout=3000")
    con.execute("PRAGMA query_only=ON")
    return con


def _table_exists(con: sqlite3.Connection, table: str) -> bool:
    return con.execute(
        "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name=?",
        (table,),
    ).fetchone() is not None


def _columns(con: sqlite3.Connection, table: str) -> set[str]:
    if not _table_exists(con, table):
        return set()
    return {str(row[1]).lower() for row in con.execute(f"PRAGMA table_info({table})")}


def _parse_time(value: Any) -> dt.datetime | None:
    if value in (None, ""):
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _payload(value: Any) -> dict[str, Any]:
    try:
        parsed = json.loads(value or "{}")
    except (TypeError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _is_portfolio_lane(phase: Any, contract_version: Any) -> bool:
    resolved = rebaseline_census.phase_qid(phase, contract_version).strip().upper()
    return resolved.endswith("_PORTFOLIO")


def _work_rows(con: sqlite3.Connection) -> list[dict[str, Any]]:
    columns = _columns(con, "work_items")
    required = {"phase", "status", "verdict", "created_at", "updated_at"}
    missing = required - columns
    if missing:
        raise RuntimeError(f"work_items schema missing required columns: {sorted(missing)}")
    contract = (
        "gate_contract_version" if "gate_contract_version" in columns
        else "NULL AS gate_contract_version"
    )
    payload = "payload_json" if "payload_json" in columns else "NULL AS payload_json"
    row_id = "id" if "id" in columns else "NULL AS id"
    parent = (
        "parent_task_id" if "parent_task_id" in columns
        else "NULL AS parent_task_id"
    )
    evidence = "evidence_path" if "evidence_path" in columns else "NULL AS evidence_path"
    return [
        dict(row)
        for row in con.execute(
            "SELECT phase,status,verdict,created_at,updated_at,"
            f"{contract},{payload},{row_id},{parent},{evidence} FROM work_items"
        )
    ]


def _nonnegative_int(value: Any) -> int:
    try:
        return max(0, int(value))
    except (TypeError, ValueError):
        return 0


def _q10_receipt_count(payload: dict[str, Any]) -> int:
    """Return only receipts evidenced by a Q10 parent payload.

    Runner payloads have used both a direct count and an explicit receipt
    collection.  Failure/missing buckets are deliberately not receipts.
    """
    for key in ("authenticated_cell_count", "receipt_count"):
        if key in payload:
            return _nonnegative_int(payload.get(key))
    receipts = payload.get("receipts")
    if isinstance(receipts, (list, dict)):
        return len(receipts)
    details = payload.get("details")
    if isinstance(details, dict):
        return _q10_receipt_count(details)
    return 0


def _committed_work(rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Count declared cell budgets for open Q12 and Q10_NEWS parents.

    Q12 declarations name deterministic child work-item IDs, so materialized
    and receipted counts are joined to those IDs.  Q10 news cells live inside
    the sealed parent plan rather than as child work_items; their authenticated
    receipt count is therefore the materialized count for this telemetry.
    """
    by_id = {str(row.get("id") or ""): row for row in rows if row.get("id")}
    classes = {
        "Q12_PATTERN": {"parents": 0, "declared": 0, "materialized": 0, "receipts": 0},
        "Q10_NEWS": {"parents": 0, "declared": 0, "materialized": 0, "receipts": 0},
    }
    for row in rows:
        if str(row.get("status") or "").lower() not in _OPEN_STATUSES:
            continue
        payload = _payload(row.get("payload_json"))
        phase = str(row.get("phase") or "").upper()
        if phase == "Q12" and str(payload.get("routing_revision") or "") == "dl089-annual-wf-cells-v1":
            declaration = payload.get("pattern_filter_sweep")
            if not isinstance(declaration, dict):
                continue
            annual = _nonnegative_int(declaration.get("annual_cell_count"))
            wf = _nonnegative_int(declaration.get("wf_cell_count"))
            declared = annual + wf
            declared_ids = {
                str(cell.get("work_item_id"))
                for key in ("annual_cells", "wf_cells")
                for cell in (declaration.get(key) or [])
                if isinstance(cell, dict) and cell.get("work_item_id")
            }
            children = [by_id[item_id] for item_id in declared_ids if item_id in by_id]
            receipts = sum(
                1 for child in children
                if str(child.get("status") or "").lower() in _TERMINAL_STATUSES
                and bool(child.get("evidence_path"))
            )
            bucket = classes["Q12_PATTERN"]
            bucket["parents"] += 1
            bucket["declared"] += declared
            bucket["materialized"] += len(children)
            bucket["receipts"] += receipts
        elif phase == "Q10_NEWS":
            details = payload.get("details") if isinstance(payload.get("details"), dict) else {}
            declared = _nonnegative_int(
                payload.get("planned_cell_count")
                or payload.get("q09_cell_count")
                or details.get("planned_cell_count")
            )
            if declared <= 0:
                continue
            receipts = min(declared, _q10_receipt_count(payload))
            bucket = classes["Q10_NEWS"]
            bucket["parents"] += 1
            bucket["declared"] += declared
            bucket["materialized"] += receipts
            bucket["receipts"] += receipts

    totals = {
        key: sum(int(bucket[key]) for bucket in classes.values())
        for key in ("parents", "declared", "materialized", "receipts")
    }
    totals["unmaterialized"] = max(0, totals["declared"] - totals["materialized"])
    for bucket in classes.values():
        bucket["unmaterialized"] = max(0, bucket["declared"] - bucket["materialized"])
    return {**totals, "classes": classes}


def _qualified_pool(pair_rows: list[dict[str, Any]], terminal_gate: str) -> list[dict]:
    return [
        {"ea_id": row["ea_id"], "symbol": row["symbol"]}
        for row in pair_rows
        if row.get("highest_contiguous_valid_gate") == terminal_gate
    ]


def _pair_summaries_fast(
    con: sqlite3.Connection, candidate_gates: tuple[str, ...]
) -> list[dict[str, Any]]:
    """Compute the census frontier without its display-label/hash passes.

    This preserves ``rebaseline_census.canonical_gate`` and ``vclass`` as the
    classification authorities, but groups duplicate history rows in SQLite
    and omits labels/finer hashes that this OWNER metric never renders.
    """
    columns = _columns(con, "work_items")
    contract_select = (
        "gate_contract_version" if "gate_contract_version" in columns
        else "NULL AS gate_contract_version"
    )
    grouped = con.execute(
        "SELECT ea_id,symbol,phase,status,verdict," + contract_select + " "
        "FROM work_items WHERE ea_id IS NOT NULL AND ea_id<>'' "
        "AND symbol IS NOT NULL AND symbol<>''"
    )
    gate_set = set(candidate_gates)
    pair_gates: dict[tuple[str, str], dict[str, dict[str, Any]]] = defaultdict(dict)
    resolution_cache: dict[tuple[str, str], tuple[str | None, bool]] = {}
    for ea_id, symbol, phase, status, verdict, contract_version in grouped:
        resolution_key = (str(phase or ""), str(contract_version or ""))
        resolved = resolution_cache.get(resolution_key)
        if resolved is None:
            gate = rebaseline_census.canonical_gate(phase, contract_version)
            portfolio = _is_portfolio_lane(phase, contract_version)
            resolved = resolution_cache[resolution_key] = (gate, portfolio)
        gate, portfolio_lane = resolved
        if gate not in gate_set or portfolio_lane:
            continue
        gate_rec = pair_gates[(str(ea_id), str(symbol))].setdefault(
            gate, {"valid": False, "classes": set()}
        )
        cls = rebaseline_census.vclass(verdict)
        if str(status or "").lower() == "done" and cls == "PASS":
            gate_rec["valid"] = True
        else:
            gate_rec["classes"].add(cls)

    rows: list[dict[str, Any]] = []
    for (ea_id, symbol), gates in pair_gates.items():
        frontier = ""
        highest = ""
        for gate in candidate_gates:
            if (gates.get(gate) or {}).get("valid"):
                highest = gate
            else:
                frontier = gate
                break
        if not frontier:
            frontier_class = "COMPLETE"
            disposition = "REUSABLE"
        else:
            classes = (gates.get(frontier) or {}).get("classes") or set()
            frontier_class = "MISSING"
            for value in rebaseline_census._FRONTIER_PRIORITY:
                if value in classes:
                    frontier_class = value
                    break
            if frontier_class == "NA":
                disposition = "NOT_APPLICABLE"
            elif frontier_class == "ECON_FAIL":
                disposition = "ECONOMIC_FAIL"
            elif highest:
                disposition = "REUSABLE"
            elif frontier_class == "STALE":
                disposition = "STALE"
            elif frontier_class in {"INFRA", "INVALID"}:
                disposition = "INVALID"
            else:
                disposition = "MISSING"
        rows.append({
            "ea_id": ea_id,
            "symbol": symbol,
            "highest_contiguous_valid_gate": highest,
            "earliest_missing_prerequisite": frontier,
            "frontier_class": frontier_class,
            "disposition": disposition,
        })
    return rows


def _phase_medians(
    rows: list[dict[str, Any]], candidate_gates: tuple[str, ...]
) -> dict[str, float]:
    durations: dict[str, list[float]] = defaultdict(list)
    allowed = set(candidate_gates)
    for row in rows:
        if str(row.get("status") or "").lower() not in _TERMINAL_STATUSES:
            continue
        if bool(row.get("_portfolio_lane")):
            continue
        gate = row.get("_canonical_gate")
        if gate not in allowed:
            continue
        created = _parse_time(row.get("created_at"))
        updated = _parse_time(row.get("updated_at"))
        if created is None or updated is None or updated < created:
            continue
        durations[gate].append((updated - created).total_seconds() / 3600.0)
    return {gate: statistics.median(values) for gate, values in durations.items()}


def _eta_days(
    pair_rows: list[dict[str, Any]], qualified_pairs: int,
    candidate_gates: tuple[str, ...], medians: dict[str, float],
) -> float | None:
    needed = max(0, TARGET_QUALIFIED_PAIRS - qualified_pairs)
    if needed == 0:
        return 0.0
    gate_index = {gate: index for index, gate in enumerate(candidate_gates)}
    estimates: list[float] = []
    for row in pair_rows:
        if row.get("disposition") in {"ECONOMIC_FAIL", "NOT_APPLICABLE"}:
            continue
        frontier = str(row.get("highest_contiguous_valid_gate") or "")
        if frontier == candidate_gates[-1]:
            continue
        remaining = candidate_gates[gate_index.get(frontier, -1) + 1:]
        if not remaining or any(gate not in medians for gate in remaining):
            continue
        estimates.append(sum(medians[gate] for gate in remaining))
    if len(estimates) < needed:
        return None
    terminal_hours = sum(sorted(estimates)[:needed])
    return round(terminal_hours / (TERMINAL_CAPACITY * 24.0), 2)


def path_to_25_metrics(
    db: str | Path, *, _pair_rows: list[dict[str, Any]] | None = None
) -> dict[str, Any]:
    """Return OWNER-facing progress to 25 terminally qualified pairs.

    ``qualified_pairs`` is the canonical ``(EA, symbol)`` count at the v4 Q14
    terminal optimization gate.  ETA is a lower-bound capacity estimate from
    observed phase medians and ten terminals; it is ``None`` when the database
    has no duration evidence for any gate required by the nearest 25 paths.
    """
    db_path = Path(db)
    v4 = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    terminal_gate = v4.terminal_requalification_gate
    terminal_ordinal = next(g.ordinal for g in v4.gates if g.id == terminal_gate)
    candidate_gates = tuple(
        g.id for g in v4.gates if 2 <= g.ordinal <= terminal_ordinal
    )
    news_gate = v4.gate_for_role("NEWS")
    opt_gates = tuple(v4.gate_for_role(role) for role in ("PATTERN", "PARAM_OPT", "HEAD_TO_HEAD"))

    con = _open_ro(db_path)
    try:
        if _pair_rows is None:
            pair_rows = _pair_summaries_fast(con, candidate_gates)
        else:
            # Internal reuse hook: operator_surfaces already paid for the exact
            # same census in this render cycle.  The public one-argument model
            # remains canonical; this avoids a second 100k-row history walk.
            pair_rows = _pair_rows
        rows = _work_rows(con)
        committed_work = _committed_work(rows)

        frontier_counts = Counter(
            str(row.get("highest_contiguous_valid_gate") or "") for row in pair_rows
        )
        frontier_histogram = {
            gate: int(frontier_counts.get(gate, 0)) for gate in candidate_gates
        }
        qualified = _qualified_pool(pair_rows, terminal_gate)
        guard = book_build_guard.check_book_build_allowed(
            "dxz", db_path, book_build_guard.DEFAULT_ORDER_DIR,
            qualified_rows=qualified,
        )

        now = dt.datetime.now(dt.timezone.utc)
        seven_days_ago = now - dt.timedelta(days=7)
        news = {
            "conclusive_verdicts_7d": 0,
            "pass_7d": 0,
            "pending": 0,
            "holds": 0,
        }
        opt_fork: dict[str, Any] = {
            gate: {"pending": 0, "done": 0} for gate in opt_gates
        }
        terminal_verdicts: Counter[str] = Counter()
        backfill = {"enqueued_today": 0, "rerun_infra_open": 0}

        resolution_cache: dict[tuple[str, str], tuple[str | None, bool]] = {}
        for row in rows:
            resolution_key = (
                str(row.get("phase") or ""),
                str(row.get("gate_contract_version") or ""),
            )
            resolved = resolution_cache.get(resolution_key)
            if resolved is None:
                resolved = (
                    rebaseline_census.canonical_gate(
                        row.get("phase"), row.get("gate_contract_version")
                    ),
                    _is_portfolio_lane(
                        row.get("phase"), row.get("gate_contract_version")
                    ),
                )
                resolution_cache[resolution_key] = resolved
            gate, portfolio_lane = resolved
            row["_canonical_gate"] = gate
            row["_portfolio_lane"] = portfolio_lane
            status = str(row.get("status") or "").lower()
            verdict = str(row.get("verdict") or "").upper()
            if gate == news_gate and not portfolio_lane:
                if status in _OPEN_STATUSES:
                    news["pending"] += 1
                updated = _parse_time(row.get("updated_at"))
                if (
                    status in _TERMINAL_STATUSES
                    and updated is not None and updated >= seven_days_ago
                    and verdict in _NEWS_CONCLUSIVE_VERDICTS
                ):
                    news["conclusive_verdicts_7d"] += 1
                    if verdict in _NEWS_PASS_VERDICTS:
                        news["pass_7d"] += 1

            if gate in opt_fork:
                if status == "pending":
                    opt_fork[gate]["pending"] += 1
                elif status == "done":
                    opt_fork[gate]["done"] += 1
                if gate == terminal_gate and status in _TERMINAL_STATUSES and verdict:
                    terminal_verdicts[verdict] += 1

            raw_payload = str(row.get("payload_json") or "")
            payload = _payload(raw_payload) if _PLANNER_REASON_PREFIX in raw_payload.lower() else {}
            rerun_reason = str(payload.get("rerun_reason") or "").lower()
            if rerun_reason.startswith(_PLANNER_REASON_PREFIX):
                created = _parse_time(row.get("created_at"))
                if created is not None and created.date() == now.date():
                    backfill["enqueued_today"] += 1
                if rerun_reason == _PLANNER_RERUN_INFRA and status in _OPEN_STATUSES:
                    backfill["rerun_infra_open"] += 1

        if _table_exists(con, "work_item_holds"):
            hold_columns = _columns(con, "work_item_holds")
            if {"work_item_id", "active"}.issubset(hold_columns):
                contract_expr = (
                    "w.gate_contract_version" if "gate_contract_version" in _columns(con, "work_items")
                    else "NULL"
                )
                for phase, contract_version in con.execute(
                    "SELECT w.phase," + contract_expr + " "
                    "FROM work_item_holds h JOIN work_items w ON w.id=h.work_item_id "
                    "WHERE h.active=1"
                ):
                    if (
                        rebaseline_census.canonical_gate(phase, contract_version) == news_gate
                        and not _is_portfolio_lane(phase, contract_version)
                    ):
                        news["holds"] += 1

        opt_fork["terminal_verdicts"] = dict(sorted(terminal_verdicts.items()))
        medians = _phase_medians(rows, candidate_gates)
        eta = _eta_days(pair_rows, len(qualified), candidate_gates, medians)
    finally:
        con.close()

    return {
        "qualified_pairs": len(qualified),
        "distinct_eas": guard.distinct_eas,
        "families": guard.strategy_families,
        "frontier_histogram": frontier_histogram,
        "news_gate": news,
        "opt_fork": opt_fork,
        "backfill": backfill,
        "committed_work": committed_work,
        "eta_days": eta,
    }


__all__ = ["path_to_25_metrics"]
