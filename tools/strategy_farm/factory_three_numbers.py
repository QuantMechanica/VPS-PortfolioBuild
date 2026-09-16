"""Factory three-numbers health read-model (``qm.factory-three-numbers/v1``).

Computes the three headline factory health numbers from **read-only** inputs and
persists them to ``D:/QM/reports/state/factory_three_numbers.json``:

  * ACTIVE_ECONOMIC_BACKTESTS — ``COUNT(work_items WHERE status='active')``.
  * TRUE_CLAIMABLE_WORK — rows of ``farmctl.pending_claim_order_sql()``
    (Level 1: excludes superseded / quarantined / governed-analytic / actively
    held rows) minus the rows failing ``dsr_cohort.claimability_precheck``
    (Level 2, Q08 phase only). This mirrors the watchdog v2 here-string in
    ``tools/strategy_farm/factory_watchdog.ps1`` (~line 717) byte-for-byte in
    semantics: a Q08 row whose precheck returns ``claimable: False`` does not
    count; a precheck that RAISES counts the row (fail open, same as the
    watchdog); if ``dsr_cohort`` cannot be imported at all, the count falls
    back to the raw selector row count (``precheck_degraded_to_selector``).
  * BLOCKED_RECOVERABLE_WORK — unreleased ``work_item_holds`` rows whose code
    matches the repairable infra classes ``Q08_DSR%`` / ``RAM_RESERVATION%`` /
    ``ARTIFACT_BINDING%`` (the repairable half of
    ``factory_bottleneck_readmodel.INFRA_HOLD_PREFIXES`` — NEWS/COMPILE classes
    excluded as not recoverable-through-repair debt here). "Unreleased"
    = ``released_at IS NULL`` (equivalent to ``active=1`` in the live DB).

Health classification (persisted across runs via the previous output file, so
IDLE_RED requires the idle-with-work state in TWO consecutive runs):

  * RUNNING              — active > 0
  * IDLE_WITH_WORK       — active = 0, true > 0 (first consecutive run)
  * NO_RUNNABLE_WORK     — active = 0, true = 0 (resets the idle streak)
  * IDLE_RED             — active = 0, true > 0, second-or-later consecutive run

The module never opens the DB writable, never starts a process, and writes only
the JSON output. Missing/degraded inputs are explicit (``NOT_EVALUATED`` /
``degraded_reasons``), never zero-forged.

CLI::

    python tools/strategy_farm/factory_three_numbers.py
    python tools/strategy_farm/factory_three_numbers.py --stdout
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "qm.factory-three-numbers/v1"

# --- canonical paths (module-level so tests can monkeypatch) ---
ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_STATE = Path(r"D:\QM\reports\state")
DB = ROOT / "state" / "farm_state.sqlite"
OUTPUT_PATH = REPORTS_STATE / "factory_three_numbers.json"

# Repairable infra hold classes: unreleased holds under these prefixes are
# backlog debt that a repair lane can recover (NOT merit rejections).
RECOVERABLE_HOLD_PREFIXES = ("Q08_DSR%", "RAM_RESERVATION%", "ARTIFACT_BINDING%")

HEALTH_RUNNING = "RUNNING"
HEALTH_IDLE_WITH_WORK = "IDLE_WITH_WORK"
HEALTH_NO_RUNNABLE_WORK = "NO_RUNNABLE_WORK"
HEALTH_IDLE_RED = "IDLE_RED"
HEALTH_UNKNOWN = "UNKNOWN"


# ---------------------------------------------------------------------------
# time helpers
# ---------------------------------------------------------------------------
def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(t: dt.datetime) -> str:
    return t.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


# ---------------------------------------------------------------------------
# database access (read-only)
# ---------------------------------------------------------------------------
def _connect_ro(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA busy_timeout=5000")
    con.execute("PRAGMA query_only=ON")
    return con


def count_active_economic_backtests(con: sqlite3.Connection) -> int:
    """ACTIVE_ECONOMIC_BACKTESTS: rows actually holding a terminal right now."""
    return int(
        con.execute(
            "SELECT COUNT(*) FROM work_items WHERE status='active'"
        ).fetchone()[0]
    )


def compute_true_claimable(con: sqlite3.Connection) -> dict[str, Any]:
    """TRUE_CLAIMABLE_WORK — watchdog v2 semantics (selector + Q08 precheck).

    Returns selector row count, true count, and diagnostic counters. Degraded
    paths never raise: they record what happened so the health consumer can
    distrust a fallback-derived number.
    """
    try:
        import farmctl
    except Exception as exc:  # noqa: BLE001 — mirror watchdog: probe, don't crash
        return {
            "selector_claimable_rows": None,
            "true_claimable_work": None,
            "q08_precheck_excluded": None,
            "q08_precheck_error_rows": None,
            "precheck_degraded_to_selector": False,
            "degraded_reason": f"farmctl import failed: {exc}",
        }

    rows = con.execute(farmctl.pending_claim_order_sql()).fetchall()
    selector = len(rows)
    excluded = 0
    error_rows = 0

    try:
        import dsr_cohort
    except Exception as exc:  # noqa: BLE001 — watchdog falls back to selector count
        return {
            "selector_claimable_rows": selector,
            "true_claimable_work": selector,
            "q08_precheck_excluded": 0,
            "q08_precheck_error_rows": 0,
            "precheck_degraded_to_selector": True,
            "degraded_reason": f"dsr_cohort import failed: {exc}",
        }

    true_claimable = 0
    for row in rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except Exception:  # noqa: BLE001 — watchdog: malformed payload -> {}
            payload = {}
        if str(row["phase"] or "").upper() == "Q08":
            try:
                pre = dsr_cohort.claimability_precheck(con, dict(row), payload)
                if pre.get("claimable") is False:
                    excluded += 1
                    continue
            except Exception:  # noqa: BLE001 — watchdog fail-open: count the row
                error_rows += 1
        true_claimable += 1

    return {
        "selector_claimable_rows": selector,
        "true_claimable_work": true_claimable,
        "q08_precheck_excluded": excluded,
        "q08_precheck_error_rows": error_rows,
        "precheck_degraded_to_selector": False,
        "degraded_reason": None,
    }


def compute_blocked_recoverable(con: sqlite3.Connection) -> dict[str, Any]:
    """BLOCKED_RECOVERABLE_WORK — unreleased holds in the repairable classes."""
    by_code: dict[str, dict[str, int]] = {}
    total_rows = 0
    where = " OR ".join("hold_code LIKE ?" for _ in RECOVERABLE_HOLD_PREFIXES)
    for row in con.execute(
        f"SELECT hold_code, COUNT(*) AS n, COUNT(DISTINCT work_item_id) AS nd "
        f"FROM work_item_holds WHERE released_at IS NULL AND ({where}) "
        f"GROUP BY hold_code",
        RECOVERABLE_HOLD_PREFIXES,
    ):
        code = str(row["hold_code"] or "UNKNOWN")
        by_code[code] = {"holds": int(row["n"]), "work_items": int(row["nd"])}
        total_rows += int(row["n"])
    # Global distinct must be its own query: one work item can carry several
    # matching codes, so summing the per-code distincts double-counts it.
    total_distinct = int(con.execute(
        f"SELECT COUNT(DISTINCT work_item_id) FROM work_item_holds "
        f"WHERE released_at IS NULL AND ({where})",
        RECOVERABLE_HOLD_PREFIXES,
    ).fetchone()[0])
    return {
        "blocked_recoverable_work": total_rows,
        "blocked_recoverable_work_items_distinct": total_distinct,
        "by_hold_code": dict(
            sorted(by_code.items(), key=lambda kv: (-kv[1]["holds"], kv[0]))
        ),
    }


# ---------------------------------------------------------------------------
# health classification (persisted across runs)
# ---------------------------------------------------------------------------
def classify_health(active: Any, true_claimable: Any,
                    previous: dict[str, Any] | None) -> dict[str, Any]:
    """Classify factory health; IDLE_RED needs the idle state in 2 consecutive
    runs, so the previous output document is an input."""
    prev_health = (previous or {}).get("health") or {}
    prev_classification = prev_health.get("classification")
    prev_streak = int(prev_health.get("consecutive_idle_with_work_runs") or 0)

    if not isinstance(active, int) or not isinstance(true_claimable, int):
        return {
            "classification": HEALTH_UNKNOWN,
            "consecutive_idle_with_work_runs": 0,
            "previous_classification": prev_classification,
            "previous_generated_at_utc": (previous or {}).get("generated_at_utc"),
            "degraded_reason": "numbers not evaluable",
        }

    if active > 0:
        return {
            "classification": HEALTH_RUNNING,
            "consecutive_idle_with_work_runs": 0,
            "previous_classification": prev_classification,
            "previous_generated_at_utc": (previous or {}).get("generated_at_utc"),
            "degraded_reason": None,
        }

    if true_claimable > 0:
        streak = prev_streak + 1 if prev_classification in (
            HEALTH_IDLE_WITH_WORK, HEALTH_IDLE_RED) else 1
        return {
            "classification": HEALTH_IDLE_RED if streak >= 2 else HEALTH_IDLE_WITH_WORK,
            "consecutive_idle_with_work_runs": streak,
            "previous_classification": prev_classification,
            "previous_generated_at_utc": (previous or {}).get("generated_at_utc"),
            "degraded_reason": None,
        }

    return {
        "classification": HEALTH_NO_RUNNABLE_WORK,
        "consecutive_idle_with_work_runs": 0,
        "previous_classification": prev_classification,
        "previous_generated_at_utc": (previous or {}).get("generated_at_utc"),
        "degraded_reason": None,
    }


# ---------------------------------------------------------------------------
# assembly
# ---------------------------------------------------------------------------
def load_previous(path: Path | None = None) -> dict[str, Any] | None:
    """Best-effort read of the previous output document (for streak state)."""
    path = Path(path or OUTPUT_PATH)
    try:
        doc = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    return doc if isinstance(doc, dict) else None


def build_document(con: sqlite3.Connection, *, now: dt.datetime,
                   previous: dict[str, Any] | None = None) -> dict[str, Any]:
    degraded: list[str] = []

    active = count_active_economic_backtests(con)
    claimable = compute_true_claimable(con)
    if claimable.get("degraded_reason"):
        degraded.append(str(claimable["degraded_reason"]))

    blocked = compute_blocked_recoverable(con)
    health = classify_health(active, claimable.get("true_claimable_work"),
                             previous)

    return {
        "schema": SCHEMA_VERSION,
        "generated_at_utc": _iso(now),
        "numbers": {
            "active_economic_backtests": active,
            "true_claimable_work": claimable.get("true_claimable_work"),
            "blocked_recoverable_work": blocked["blocked_recoverable_work"],
        },
        "detail": {
            "selector_claimable_rows": claimable.get("selector_claimable_rows"),
            "q08_precheck_excluded": claimable.get("q08_precheck_excluded"),
            "q08_precheck_error_rows": claimable.get(
                "q08_precheck_error_rows"),
            "precheck_degraded_to_selector": claimable.get(
                "precheck_degraded_to_selector"),
            "blocked_recoverable_work_items_distinct":
                blocked["blocked_recoverable_work_items_distinct"],
            "blocked_by_hold_code": blocked["by_hold_code"],
        },
        "health": health,
        "sources": {
            "db": str(DB),
            "claimable_semantics":
                "farmctl.pending_claim_order_sql() + dsr_cohort."
                "claimability_precheck (Q08), mirroring factory_watchdog.ps1 v2",
        },
        "degraded_reasons": degraded,
    }


def write_text_atomic(path: Path, rendered: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(rendered, encoding="utf-8", newline="\n")
    os.replace(temp, path)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DB,
                        help="override farm_state.sqlite path")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH,
                        help="factory_three_numbers.json output path")
    parser.add_argument("--stdout", action="store_true",
                        help="also print the read-model to stdout")
    args = parser.parse_args(argv)

    now = _now_utc()
    previous = load_previous(args.output)
    con = _connect_ro(args.db)
    try:
        doc = build_document(con, now=now, previous=previous)
    finally:
        con.close()

    rendered = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    write_text_atomic(args.output, rendered)
    if args.stdout:
        sys.stdout.write(rendered)

    n = doc["numbers"]
    _err = sys.stderr if sys.stderr is not None else open(
        os.devnull, "w", encoding="utf-8")
    _err.write(
        f"[factory_three_numbers] active={n.get('active_economic_backtests')} "
        f"true_claimable={n.get('true_claimable_work')} "
        f"blocked_recoverable={n.get('blocked_recoverable_work')} "
        f"health={doc['health'].get('classification')} -> {args.output}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
