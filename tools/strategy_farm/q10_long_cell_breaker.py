"""Q10 long-cell circuit breaker — detection + documented hold, never a verdict.

Router task cae3df77 (ops_issue, claude), following
``docs/ops/evidence/2026-08-24_throughput_forensics.md`` recommendation 2:

    "Add a long-cell circuit breaker. Flag a Q10 cell for operator review when
    wall time exceeds ``max(3 x parent rolling median, configured cell
    timeout)`` and prevent unbounded retry occupancy. ``13f41983`` demonstrates
    why failure-exhaustion time must be reported separately from successful-cell
    time."

Case ``13f41983-74c6-4058-8a41-c787633a1391`` (Q10_NEWS, QM5_1328 EURJPY) held
terminal T6 for hours with 0 receipts: five cells retry-exhausted (mean 51.0
min/cell, range 30.7-263.5), three still pending, each cell burning its bounded
transient-retry budget (``DEFAULT_CELL_RETRY_BUDGET=2`` -> ``cell_failure_3.json``
with ``TIMEOUT`` / ``INCOMPLETE_RUNS`` / ``METATESTER_HUNG`` /
``MODEL4_MARKER_REQUIRED``). The parent never completed and was never flagged.

What this module does (and, importantly, does NOT):

- DETECTS a Q10 cell whose wall time exceeds the parent threshold.
- WRITES a hold row to ``work_item_holds`` (``hold_code=Q10_LONG_CELL_BREAKER``)
  so the ordinary claim selector (which filters out rows with any active hold,
  ``farmctl.py:1499-1502`` / ``terminal_worker.py:1847-1850``) stops re-claiming
  the parent once it lands back in ``pending`` — i.e. the retry chain ends in a
  documented hold instead of re-retrying forever.
- SEPARATES success-cell wall time from exhaustion-cell wall time in the emitted
  telemetry (they were commingled before; the whole point of the case is that a
  0-receipt parent's exhaustion time must not be read as success latency).
- SURFACES the flag in ``farmctl.py health`` / ``state/health.json`` via
  ``health.chk_q10_long_cell_breaker_holds`` (read-only; no verdict).

It NEVER writes a pipeline verdict / status on the work item, never touches a
gate criterion, and never kills an in-flight tester process. It is detection +
hold + visibility only. The affected parent's next disposition (release, real
failure classification, OWNER decision) stays with the operator/pipeline.

Rollback: set ``QM_DISABLE_Q10_LONG_CELL_BREAKER=1`` in the environment. The
detector then no-ops (``breaker_enabled()`` returns False) and writes no holds;
existing holds stay until an operator releases them. Same env-var kill-switch
convention as ``codex_fleet_pacer.QM_DISABLE_TESTER_DRAIN_CODEX_CAP`` and
``QM_DISABLE_LONGRUN_SCHEDULING_CAP``. No restart-time migration; the flag is
read fresh on every run.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import statistics
import sys
import datetime as dt
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Mapping, Optional, Sequence

# ---------------------------------------------------------------------------
# Constants / configuration
# ---------------------------------------------------------------------------

HOLD_CODE = "Q10_LONG_CELL_BREAKER"
DISABLE_ENV = "QM_DISABLE_Q10_LONG_CELL_BREAKER"
CELL_TIMEOUT_ENV = "QM_Q10_CELL_TIMEOUT_SECONDS"

# "configured cell timeout" floor for the max(3 x median, timeout) rule. 120 min
# matches the documented Q07 parent-timeout precedent cited in the forensics
# report (§2, "configured parent timeout was 120 min"); it is the floor that
# applies when a parent has produced no successful cell yet and therefore has no
# rolling median (exactly the 13f41983 shape). Override via CELL_TIMEOUT_ENV.
DEFAULT_CELL_TIMEOUT_SECONDS = 120 * 60.0

# A cell is "exhausted" once it has burned the full bounded transient-retry
# budget: DEFAULT_CELL_RETRY_BUDGET (2) extra attempts beyond the first ->
# cell_failure_3.json. Mirrors q09_news_runner.DEFAULT_CELL_RETRY_BUDGET; kept a
# module constant so the breaker has no import-time dependency on the runner.
MAX_FAILURE_OCCURRENCE = 3

# Any active breaker hold older than this escalates the health entry from WARN
# (present, operator-review) to FAIL (aged, still not actioned).
BREAKER_HOLD_FAIL_HOURS = 6.0

# Storage phase keys carrying the news-cell (q09_contract_v3/cells) artifact
# layout this breaker measures.
DEFAULT_Q10_PHASES: tuple[str, ...] = ("Q10_NEWS", "Q10")

DEFAULT_DB_PATH = Path(
    os.environ.get(
        "QM_FARM_STATE_DB", r"D:\QM\strategy_farm\state\farm_state.sqlite"
    )
)
DEFAULT_REPORTS_ROOT = Path(
    os.environ.get("QM_REPORTS_WORK_ITEMS_ROOT", r"D:\QM\reports\work_items")
)
STATE_FILE = Path(r"D:/QM/reports/state/q10_long_cell_breaker_state.json")

# YYYYMMDD_HHMMSS tester-run directory token.
_TS_RE = re.compile(r"^\d{8}_\d{6}$")


# ---------------------------------------------------------------------------
# Rollback / configuration helpers
# ---------------------------------------------------------------------------

def breaker_enabled(env: Optional[Mapping[str, str]] = None) -> bool:
    """False when the QM_DISABLE_Q10_LONG_CELL_BREAKER kill-switch is set."""
    env = os.environ if env is None else env
    return str(env.get(DISABLE_ENV, "")).strip().lower() not in {"1", "true", "yes", "on"}


def configured_cell_timeout_seconds(env: Optional[Mapping[str, str]] = None) -> float:
    env = os.environ if env is None else env
    raw = str(env.get(CELL_TIMEOUT_ENV, "")).strip()
    if raw:
        try:
            value = float(raw)
            if value > 0:
                return value
        except ValueError:
            pass
    return DEFAULT_CELL_TIMEOUT_SECONDS


def utc_now_iso() -> str:
    return (
        dt.datetime.now(dt.timezone.utc)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z")
    )


# ---------------------------------------------------------------------------
# Pure decision logic (fully unit-testable, no IO)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class CellTiming:
    """One Q10 cell's measured wall time and terminal status.

    status is one of: "success" (cell_receipt.json present), "exhausted"
    (retry budget burned, cell_failure_<MAX>.json present), or "inflight"
    (still running / retrying, no terminal artifact yet).
    """

    name: str
    status: str
    wall_seconds: Optional[float]


def long_cell_threshold_seconds(
    parent_median_seconds: Optional[float],
    configured_timeout_seconds: float,
) -> float:
    """max(3 x parent rolling median, configured cell timeout).

    When the parent has no successful cell yet (median None/<=0) the rule
    collapses to the configured timeout floor — this is the 13f41983 case, a
    parent with 0 receipts whose only signal is the timeout floor.
    """
    floor = float(configured_timeout_seconds)
    if parent_median_seconds is None or parent_median_seconds <= 0:
        return floor
    return max(3.0 * float(parent_median_seconds), floor)


def cell_breaches_threshold(
    wall_seconds: Optional[float], threshold_seconds: float
) -> bool:
    if wall_seconds is None:
        return False
    return float(wall_seconds) > float(threshold_seconds)


def parent_success_median_seconds(
    cells: Iterable[CellTiming],
) -> Optional[float]:
    successes = [
        c.wall_seconds
        for c in cells
        if c.status == "success" and c.wall_seconds is not None
    ]
    if not successes:
        return None
    return float(statistics.median(successes))


def _series(cells: Iterable[CellTiming], status: str) -> list[float]:
    return [
        round(float(c.wall_seconds), 1)
        for c in cells
        if c.status == status and c.wall_seconds is not None
    ]


def split_cell_telemetry(cells: Sequence[CellTiming]) -> dict:
    """Success-cell time and exhaustion-time as DISTINCT series.

    This is acceptance criterion 3: a 0-receipt parent's exhaustion time must
    never be read as, or averaged into, successful-cell latency. Inflight cells
    are reported as their own third series so a still-running long cell is not
    silently folded into either.
    """
    success = _series(cells, "success")
    exhaustion = _series(cells, "exhausted")
    inflight = _series(cells, "inflight")

    def _median(series: list[float]) -> Optional[float]:
        return round(float(statistics.median(series)), 1) if series else None

    return {
        "success_cell_seconds": success,
        "exhaustion_cell_seconds": exhaustion,
        "inflight_cell_seconds": inflight,
        "success_cell_count": len(success),
        "exhaustion_cell_count": len(exhaustion),
        "inflight_cell_count": len(inflight),
        "success_cell_median_seconds": _median(success),
        "exhaustion_cell_median_seconds": _median(exhaustion),
        "inflight_cell_max_seconds": round(max(inflight), 1) if inflight else None,
    }


def evaluate_parent(
    work_item_id: str,
    cells: Sequence[CellTiming],
    configured_timeout_seconds: float,
) -> dict:
    """Threshold, breaching cells, and split telemetry for one parent.

    Only inflight and exhausted cells can breach — a success cell already
    produced a receipt and is not occupying the terminal.
    """
    median = parent_success_median_seconds(cells)
    threshold = long_cell_threshold_seconds(median, configured_timeout_seconds)
    breaching = [
        c
        for c in cells
        if c.status in {"inflight", "exhausted"}
        and cell_breaches_threshold(c.wall_seconds, threshold)
    ]
    telemetry = split_cell_telemetry(cells)
    return {
        "work_item_id": work_item_id,
        "parent_success_median_seconds": (
            round(median, 1) if median is not None else None
        ),
        "threshold_seconds": round(threshold, 1),
        "cell_count": len(cells),
        "breaching_cells": [c.name for c in breaching],
        "breaching_cell_details": [
            {
                "cell": c.name,
                "status": c.status,
                "wall_seconds": round(float(c.wall_seconds), 1),
            }
            for c in breaching
        ],
        "breached": bool(breaching),
        "telemetry": telemetry,
    }


# ---------------------------------------------------------------------------
# Artifact scanning (filesystem IO)
# ---------------------------------------------------------------------------

def _earliest_run_marker_epoch(cell_dir: Path) -> Optional[float]:
    """Earliest tester-run artifact mtime for the cell = wall-time start.

    The forensics report defines cell wall time as "earliest timestamped
    selection/holdout run directory through cell_receipt.json mtime". We anchor
    the *start* on the earliest run-dir mtime rather than parsing the
    YYYYMMDD_HHMMSS dir-name string, because the dir name is broker/local wall
    clock while the terminal artifact end marker is a UTC os mtime — using
    mtimes on both ends measures the same interval without the local/UTC skew
    the string method carries. Falls back to inputs.set, then the cell dir.
    """
    candidates: list[float] = []
    for run_dir in cell_dir.glob("runs/*/*/*"):
        if run_dir.is_dir() and _TS_RE.match(run_dir.name):
            try:
                candidates.append(run_dir.stat().st_mtime)
            except OSError:
                continue
    if candidates:
        return min(candidates)
    inputs = cell_dir / "inputs.set"
    if inputs.exists():
        try:
            return inputs.stat().st_mtime
        except OSError:
            return None
    try:
        return cell_dir.stat().st_mtime
    except OSError:
        return None


def _max_failure_occurrence(cell_dir: Path) -> tuple[int, Optional[Path]]:
    """Highest cell_failure occurrence present and its path (0 if none)."""
    best = 0
    best_path: Optional[Path] = None
    for path in cell_dir.glob("cell_failure*.json"):
        name = path.name
        if name == "cell_failure.json":
            occurrence = 1
        else:
            m = re.match(r"^cell_failure_([1-9][0-9]*)\.json$", name)
            if not m:
                continue
            occurrence = int(m.group(1))
        if occurrence > best:
            best = occurrence
            best_path = path
    return best, best_path


def scan_cell_timing(cell_dir: Path, now_epoch: float) -> CellTiming:
    """Classify one cell directory into a CellTiming."""
    start = _earliest_run_marker_epoch(cell_dir)
    receipt = cell_dir / "cell_receipt.json"
    max_failure, failure_path = _max_failure_occurrence(cell_dir)

    if receipt.exists():
        status = "success"
        try:
            end = receipt.stat().st_mtime
        except OSError:
            end = now_epoch
    elif max_failure >= MAX_FAILURE_OCCURRENCE and failure_path is not None:
        status = "exhausted"
        try:
            end = failure_path.stat().st_mtime
        except OSError:
            end = now_epoch
    else:
        status = "inflight"
        end = now_epoch

    wall = None if start is None else max(0.0, end - start)
    return CellTiming(name=cell_dir.name, status=status, wall_seconds=wall)


def scan_parent_cells(
    parent_reports_dir: Path, now_epoch: float
) -> list[CellTiming]:
    """All cell timings under ``<work_item>/q09_contract_v3/cells``."""
    cells_dir = parent_reports_dir / "q09_contract_v3" / "cells"
    if not cells_dir.is_dir():
        return []
    timings: list[CellTiming] = []
    for cell_dir in sorted(cells_dir.iterdir()):
        if cell_dir.is_dir():
            timings.append(scan_cell_timing(cell_dir, now_epoch))
    return timings


# ---------------------------------------------------------------------------
# Database IO
# ---------------------------------------------------------------------------

def read_active_q10_parents(
    db_path: Path, phases: Sequence[str] = DEFAULT_Q10_PHASES
) -> list[dict]:
    """Active/pending Q10 parents, read-only.

    Fails open (returns []) if the DB is unreadable — this is a visibility
    mechanism and must never crash the caller.
    """
    if not Path(db_path).exists():
        return []
    marks = ",".join("?" for _ in phases)
    try:
        con = sqlite3.connect(
            f"{Path(db_path).as_uri()}?mode=ro", uri=True, timeout=5.0
        )
    except sqlite3.Error:
        return []
    try:
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA query_only = ON")
        rows = con.execute(
            f"""
            SELECT id, ea_id, symbol, phase, status
            FROM work_items
            WHERE phase IN ({marks})
              AND status IN ('active', 'pending')
            ORDER BY id
            """,
            tuple(phases),
        ).fetchall()
    except sqlite3.Error:
        return []
    finally:
        con.close()
    return [dict(r) for r in rows]


def write_long_cell_hold(
    conn: sqlite3.Connection,
    work_item_id: str,
    *,
    reason: str,
    now: Optional[str] = None,
) -> bool:
    """Write/refresh the breaker hold for a parent. Returns True if applied.

    Never overwrites a *different* active hold (mirrors
    q09_news_schema.hold_until_plan_bound): if another mechanism already holds
    this row, we leave it and report False. Only ``work_item_holds`` is touched
    — no ``work_items`` column, no verdict, no status.
    """
    existing = conn.execute(
        "SELECT hold_code, active FROM work_item_holds WHERE work_item_id=?",
        (str(work_item_id),),
    ).fetchone()
    if (
        existing is not None
        and int(existing[1]) == 1
        and str(existing[0]) != HOLD_CODE
    ):
        return False
    stamp = now or utc_now_iso()
    conn.execute(
        """
        INSERT INTO work_item_holds(
            work_item_id, hold_code, reason, active, release_on_restart,
            created_at, updated_at, released_at, release_note
        ) VALUES(?,?,?,1,0,?,?,NULL,NULL)
        ON CONFLICT(work_item_id) DO UPDATE SET
            hold_code=excluded.hold_code,
            reason=excluded.reason,
            active=1,
            release_on_restart=0,
            updated_at=excluded.updated_at,
            released_at=NULL,
            release_note=NULL
        """,
        (str(work_item_id), HOLD_CODE, reason, stamp, stamp),
    )
    return True


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

@dataclass
class BreakerRun:
    enabled: bool
    checked_at: str
    configured_cell_timeout_seconds: float
    parents_scanned: int = 0
    parents_breached: int = 0
    holds_written: int = 0
    parents: list[dict] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "checked_at": self.checked_at,
            "breaker_enabled": self.enabled,
            "disable_env": DISABLE_ENV,
            "hold_code": HOLD_CODE,
            "configured_cell_timeout_seconds": self.configured_cell_timeout_seconds,
            "parents_scanned": self.parents_scanned,
            "parents_breached": self.parents_breached,
            "holds_written": self.holds_written,
            "parents": self.parents,
        }


def run(
    *,
    db_path: Path = DEFAULT_DB_PATH,
    reports_root: Path = DEFAULT_REPORTS_ROOT,
    apply: bool = False,
    phases: Sequence[str] = DEFAULT_Q10_PHASES,
    env: Optional[Mapping[str, str]] = None,
    now_epoch: Optional[float] = None,
) -> BreakerRun:
    """Scan active Q10 parents; in apply mode write holds for breaching ones.

    Detection-only by default (dry run). Never writes a verdict. Never kills a
    process.
    """
    enabled = breaker_enabled(env)
    timeout = configured_cell_timeout_seconds(env)
    now_epoch = dt.datetime.now(dt.timezone.utc).timestamp() if now_epoch is None else now_epoch
    result = BreakerRun(
        enabled=enabled,
        checked_at=utc_now_iso(),
        configured_cell_timeout_seconds=timeout,
    )
    if not enabled:
        return result

    parents = read_active_q10_parents(db_path, phases)
    result.parents_scanned = len(parents)

    write_conn: Optional[sqlite3.Connection] = None
    try:
        for parent in parents:
            wid = parent["id"]
            cells = scan_parent_cells(Path(reports_root) / wid, now_epoch)
            ev = evaluate_parent(wid, cells, timeout)
            ev["ea_id"] = parent.get("ea_id")
            ev["symbol"] = parent.get("symbol")
            ev["phase"] = parent.get("phase")
            ev["status"] = parent.get("status")
            ev["hold_written"] = False
            if ev["breached"]:
                result.parents_breached += 1
                if apply:
                    if write_conn is None:
                        write_conn = sqlite3.connect(str(db_path), timeout=30.0)
                        write_conn.execute("PRAGMA busy_timeout = 30000")
                    reason = (
                        f"{HOLD_CODE}: cell(s) {ev['breaching_cells']} exceeded "
                        f"{ev['threshold_seconds']:.0f}s "
                        f"(max(3x median, configured timeout)); flagged for "
                        f"operator review — no verdict written."
                    )
                    with write_conn:
                        applied = write_long_cell_hold(
                            write_conn, wid, reason=reason
                        )
                    ev["hold_written"] = applied
                    if applied:
                        result.holds_written += 1
            result.parents.append(ev)
    finally:
        if write_conn is not None:
            write_conn.close()
    return result


def _write_state(result: BreakerRun) -> None:
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(
            json.dumps(result.to_dict(), indent=2, sort_keys=True), encoding="utf-8"
        )
    except OSError:
        pass


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Q10 long-cell circuit breaker (router task cae3df77). "
            "Detection + documented hold only — never writes a verdict, never "
            "kills a running tester."
        )
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB_PATH)
    parser.add_argument("--reports-root", type=Path, default=DEFAULT_REPORTS_ROOT)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write breaker holds. Default is dry-run (detect + report only).",
    )
    parser.add_argument("--json", action="store_true", help="Emit the run JSON.")
    parser.add_argument(
        "--no-state", action="store_true", help="Do not write the state sidecar."
    )
    args = parser.parse_args(argv)

    result = run(db_path=args.db, reports_root=args.reports_root, apply=args.apply)
    if not args.no_state:
        _write_state(result)
    if args.json:
        print(json.dumps(result.to_dict(), indent=2, sort_keys=True))
    else:
        if not result.enabled:
            print(f"Q10 long-cell breaker DISABLED via {DISABLE_ENV}")
        else:
            mode = "apply" if args.apply else "dry-run"
            print(
                f"Q10 long-cell breaker [{mode}]: scanned={result.parents_scanned} "
                f"breached={result.parents_breached} holds_written={result.holds_written}"
            )
            for p in result.parents:
                if p["breached"]:
                    print(
                        f"  BREACH {p['work_item_id'][:8]} {p.get('ea_id')}/{p.get('symbol')}: "
                        f"cells={p['breaching_cells']} threshold={p['threshold_seconds']:.0f}s "
                        f"hold_written={p['hold_written']}"
                    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
