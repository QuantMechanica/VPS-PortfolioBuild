"""Split throughput telemetry — read-only measurement, never dispatch/verdict.

Router task 6e9a724b ("Durchsatz-Telemetrie splitten: execution verdicts vs
disposition_only"), implementing recommendation 6 of
``docs/ops/evidence/2026-08-24_throughput_forensics.md``:

    "Split throughput telemetry. Publish execution verdicts/hour excluding
    ``disposition_only``, active terminal-minutes by phase, Q10 cell
    receipts/hour, retry-exhausted cells/hour, and claimed-to-completed latency
    percentiles. The 182-row disposition batch shows why raw verdict rows/hour is
    not a valid tester-throughput metric."

Why this exists: on 2026-08-23T17:53:43Z a single OWNER batch decision
(``OWNER-DEC-STRANDED-182``) appended 182 administrative Q02 ``INVALID``
dispositions in one second. Those rows carry ``payload_json.disposition_only =
true`` and closed deterministically-dead work with **no tester run**. Counting
raw ``work_items`` verdict rows made that hour look like a 183-verdict throughput
spike when the real tester work was a single Q07 completion.

An **execution verdict** is a terminal (``done``/``failed``) row with a non-null
verdict that is NOT a ``disposition_only`` administrative row. That is the only
count that reflects real tester throughput.

This module is measurement-only. It never writes a ``work_items`` verdict/status,
never touches queue ordering, and never dispatches work. Every DB read is a plain
SELECT; callers pass their own (read-only) connection.
"""
from __future__ import annotations

import datetime as dt
import json
import math
import sqlite3
from pathlib import Path
from typing import Any, Iterable, Mapping, Optional, Sequence

try:  # direct ``python tools/strategy_farm/<script>.py`` imports
    import q10_long_cell_breaker
    from phase_ids import phase_qid
except ModuleNotFoundError:  # package imports (tests, module consumers)
    from tools.strategy_farm import q10_long_cell_breaker
    from tools.strategy_farm.phase_ids import phase_qid


# Canonical SQL predicate for "this terminal row is a real execution verdict, not
# an administrative disposition". Reused verbatim by news_gate_service and
# optimization_fork_driver so every verdicts/hour|day rate shares one definition.
# json_extract on a JSON boolean ``true`` yields integer 1; a legacy ``"true"``
# string yields the text 'true'; an absent key yields NULL -> coalesced to 0
# (kept). Invalid/NULL payloads are kept (they are real rows, not dispositions).
EXECUTION_VERDICT_EXCLUSION_SQL = (
    "(json_valid(payload_json)=0 "
    "OR coalesce(json_extract(payload_json,'$.disposition_only'),0) NOT IN (1,'true'))"
)

DEFAULT_WINDOW_HOURS = 24
DEFAULT_LATENCY_PERCENTILES: tuple[int, ...] = (50, 90, 99)


# ---------------------------------------------------------------------------
# Pure helpers (no IO)
# ---------------------------------------------------------------------------

def is_disposition_only(payload_json: str | None) -> bool:
    """True when a row is an administrative disposition, not a tester run.

    Mirrors ``EXECUTION_VERDICT_EXCLUSION_SQL`` for Python-side callers/tests.
    """
    try:
        payload = json.loads(str(payload_json or "{}"))
    except (json.JSONDecodeError, TypeError):
        return False
    if not isinstance(payload, dict):
        return False
    value = payload.get("disposition_only")
    if isinstance(value, str):
        return value.strip().lower() == "true"
    return bool(value)


def percentiles(values: Sequence[float], points: Iterable[int]) -> dict[str, Optional[float]]:
    """Nearest-rank percentiles keyed ``pNN``. Empty input -> all None."""
    ordered = sorted(float(v) for v in values)
    result: dict[str, Optional[float]] = {}
    n = len(ordered)
    for p in points:
        key = f"p{int(p)}"
        if n == 0:
            result[key] = None
            continue
        rank = max(1, math.ceil((float(p) / 100.0) * n))
        result[key] = round(ordered[min(rank, n) - 1], 1)
    return result


def _cutoff_iso(now: dt.datetime, window_hours: float) -> str:
    if now.tzinfo is None:
        now = now.replace(tzinfo=dt.timezone.utc)
    return (now.astimezone(dt.timezone.utc) - dt.timedelta(hours=window_hours)).isoformat()


def _parse_iso(value: str | None) -> Optional[dt.datetime]:
    if not value:
        return None
    text = str(value).strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        try:
            parsed = dt.datetime.strptime(text, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _payload(payload_json: str | None) -> dict:
    try:
        payload = json.loads(str(payload_json or "{}"))
    except (json.JSONDecodeError, TypeError):
        return {}
    return payload if isinstance(payload, dict) else {}


# ---------------------------------------------------------------------------
# Metric 1: execution verdicts vs raw verdict rows, by Qxx phase
# ---------------------------------------------------------------------------

def execution_vs_raw_by_phase(
    con: sqlite3.Connection,
    *,
    now: dt.datetime,
    window_hours: float = DEFAULT_WINDOW_HOURS,
) -> dict[str, Any]:
    """Trailing-window terminal rows split into execution vs disposition.

    ``by_phase`` is keyed by canonical Qxx (never a storage P-key). ``raw`` is
    every terminal verdict row; ``execution`` excludes ``disposition_only``
    administrative rows. ``per_hour`` fields divide by the window length.
    """
    cutoff = _cutoff_iso(now, window_hours)
    rows = con.execute(
        """
        SELECT phase, gate_contract_version AS gcv, payload_json
        FROM work_items
        WHERE status IN ('done','failed') AND verdict IS NOT NULL
          AND updated_at >= ?
        """,
        (cutoff,),
    ).fetchall()
    by_phase: dict[str, dict[str, int]] = {}
    raw_total = 0
    execution_total = 0
    for row in rows:
        try:
            phase = row["phase"]
            gcv = row["gcv"]
            payload_json = row["payload_json"]
        except (TypeError, IndexError):
            phase, gcv, payload_json = row[0], row[1], row[2]
        qid = phase_qid(str(phase or ""), gcv) or "UNKNOWN"
        bucket = by_phase.setdefault(qid, {"raw": 0, "execution": 0})
        bucket["raw"] += 1
        raw_total += 1
        if not is_disposition_only(payload_json):
            bucket["execution"] += 1
            execution_total += 1
    disposition_total = raw_total - execution_total
    hours = float(window_hours) or 1.0
    return {
        "window_hours": window_hours,
        "raw_total": raw_total,
        "execution_total": execution_total,
        "disposition_total": disposition_total,
        "execution_per_hour": round(execution_total / hours, 3),
        "raw_per_hour": round(raw_total / hours, 3),
        "by_phase": {qid: by_phase[qid] for qid in sorted(by_phase)},
    }


# ---------------------------------------------------------------------------
# Metric 2: active terminal-minutes by Qxx phase
# ---------------------------------------------------------------------------

def active_terminal_minutes_by_phase(
    con: sqlite3.Connection,
    *,
    now: dt.datetime,
) -> dict[str, Any]:
    """Currently-occupied terminal-minutes per Qxx phase.

    Start time is the persisted ``claimed_at_iso`` (the same claim anchor the
    forensics report used), falling back to ``updated_at`` when a claim stamp is
    absent. Rows are the ``status='active'`` work items — the same occupancy
    source ``chk_active_row_age`` reads.
    """
    if now.tzinfo is None:
        now = now.replace(tzinfo=dt.timezone.utc)
    now = now.astimezone(dt.timezone.utc)
    rows = con.execute(
        """
        SELECT phase, gate_contract_version AS gcv, claimed_by, payload_json, updated_at
        FROM work_items
        WHERE status='active'
        """
    ).fetchall()
    by_phase: dict[str, float] = {}
    active_rows = 0
    total_minutes = 0.0
    for row in rows:
        try:
            phase, gcv, payload_json, updated_at = (
                row["phase"], row["gcv"], row["payload_json"], row["updated_at"]
            )
        except (TypeError, IndexError):
            phase, gcv, payload_json, updated_at = row[0], row[1], row[3], row[4]
        payload = _payload(payload_json)
        start = _parse_iso(payload.get("claimed_at_iso")) or _parse_iso(updated_at)
        if start is None:
            continue
        minutes = max(0.0, (now - start).total_seconds() / 60.0)
        qid = phase_qid(str(phase or ""), gcv) or "UNKNOWN"
        by_phase[qid] = by_phase.get(qid, 0.0) + minutes
        total_minutes += minutes
        active_rows += 1
    return {
        "active_rows": active_rows,
        "total_active_minutes": round(total_minutes, 1),
        "by_phase": {qid: round(by_phase[qid], 1) for qid in sorted(by_phase)},
    }


# ---------------------------------------------------------------------------
# Metric 3: claimed-to-completed latency percentiles
# ---------------------------------------------------------------------------

def claim_to_complete_latency(
    con: sqlite3.Connection,
    *,
    now: dt.datetime,
    window_hours: float = DEFAULT_WINDOW_HOURS,
    points: Iterable[int] = DEFAULT_LATENCY_PERCENTILES,
    include_dispositions: bool = False,
) -> dict[str, Any]:
    """Percentiles of (updated_at - claimed_at_iso) for terminal rows, minutes.

    Administrative ``disposition_only`` rows are excluded by default — they never
    ran and their (append time - claim time) is not a tester latency. Rows with
    no claim stamp are skipped (latency undefined).
    """
    cutoff = _cutoff_iso(now, window_hours)
    rows = con.execute(
        """
        SELECT payload_json, updated_at
        FROM work_items
        WHERE status IN ('done','failed') AND verdict IS NOT NULL
          AND updated_at >= ?
        """,
        (cutoff,),
    ).fetchall()
    latencies: list[float] = []
    skipped_no_claim = 0
    for row in rows:
        try:
            payload_json, updated_at = row["payload_json"], row["updated_at"]
        except (TypeError, IndexError):
            payload_json, updated_at = row[0], row[1]
        if not include_dispositions and is_disposition_only(payload_json):
            continue
        payload = _payload(payload_json)
        claimed = _parse_iso(payload.get("claimed_at_iso"))
        finished = _parse_iso(updated_at)
        if claimed is None or finished is None:
            skipped_no_claim += 1
            continue
        latencies.append(max(0.0, (finished - claimed).total_seconds() / 60.0))
    result: dict[str, Any] = {
        "window_hours": window_hours,
        "sample_count": len(latencies),
        "skipped_no_claim": skipped_no_claim,
    }
    result.update(percentiles(latencies, points))
    return result


# ---------------------------------------------------------------------------
# Metric 4: Q10 cell receipts/hour and retry-exhausted cells/hour
# ---------------------------------------------------------------------------

def _cell_terminal_event(cell_dir: Path) -> Optional[tuple[str, float]]:
    """(status, end_epoch) for a terminal cell, else None (still inflight).

    Reuses ``q10_long_cell_breaker`` artifact rules verbatim: a ``cell_receipt``
    is a success; ``cell_failure_<MAX>.json`` (retry budget burned) is exhausted.
    """
    receipt = cell_dir / "cell_receipt.json"
    if receipt.exists():
        try:
            return "success", receipt.stat().st_mtime
        except OSError:
            return None
    max_failure, failure_path = q10_long_cell_breaker._max_failure_occurrence(cell_dir)
    if max_failure >= q10_long_cell_breaker.MAX_FAILURE_OCCURRENCE and failure_path is not None:
        try:
            return "exhausted", failure_path.stat().st_mtime
        except OSError:
            return None
    return None


def q10_cell_throughput(
    con: sqlite3.Connection,
    *,
    now: dt.datetime,
    reports_root: Path,
    window_hours: float = DEFAULT_WINDOW_HOURS,
    phases: Sequence[str] = q10_long_cell_breaker.DEFAULT_Q10_PHASES,
) -> dict[str, Any]:
    """Q10 cell receipts and retry-exhausted cells completed in the window.

    Scans the bounded set of active/pending Q10 parents (the only ones occupying
    terminals) and counts cells whose terminal artifact mtime lands inside the
    trailing window. Fails open (zeros) when the reports tree is unreadable.
    """
    if now.tzinfo is None:
        now = now.replace(tzinfo=dt.timezone.utc)
    now = now.astimezone(dt.timezone.utc)
    cutoff_epoch = (now - dt.timedelta(hours=window_hours)).timestamp()
    marks = ",".join("?" for _ in phases)
    try:
        parents = con.execute(
            f"""
            SELECT id FROM work_items
            WHERE phase IN ({marks}) AND status IN ('active','pending')
            ORDER BY id
            """,
            tuple(phases),
        ).fetchall()
    except sqlite3.Error:
        parents = []
    receipts = 0
    exhausted = 0
    parents_scanned = 0
    root = Path(reports_root)
    for parent in parents:
        try:
            wid = parent["id"]
        except (TypeError, IndexError):
            wid = parent[0]
        cells_dir = root / str(wid) / "q09_contract_v3" / "cells"
        if not cells_dir.is_dir():
            continue
        parents_scanned += 1
        for cell_dir in cells_dir.iterdir():
            if not cell_dir.is_dir():
                continue
            event = _cell_terminal_event(cell_dir)
            if event is None:
                continue
            status, end_epoch = event
            if end_epoch < cutoff_epoch:
                continue
            if status == "success":
                receipts += 1
            elif status == "exhausted":
                exhausted += 1
    hours = float(window_hours) or 1.0
    return {
        "window_hours": window_hours,
        "parents_scanned": parents_scanned,
        "receipts": receipts,
        "retry_exhausted": exhausted,
        "receipts_per_hour": round(receipts / hours, 3),
        "retry_exhausted_per_hour": round(exhausted / hours, 3),
    }
