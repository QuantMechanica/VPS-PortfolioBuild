"""Mission Control v2 data-contract emitter (``qm.mission_control.v2``).

Builds the complete, versioned Mission Control payload from the canonical
strategy-farm sources — **read-only** — and writes it to
``D:\\QM\\reports\\state\\mission_control_v2_preview.json``.

Scope (task QM-TODO-20260820-002): this module produces DATA only. It performs
no HTML/visual rendering; a renderer consuming this contract needs zero further
data decisions. Every section is self-describing: it carries its own
``source_as_of``, ``staleness`` classification, and (on failure)
``degraded_reason`` so a renderer can badge STALE / DEGRADED without re-deriving
anything.

Canonical sources (see docs/ops/MISSION_CONTROL_V2_DATA_CONTRACT.md for the full
field-by-field contract):

  * queue / progress / terminals  -> farm_state.sqlite (via the read-only
    ``work_items_clean`` TEMP view; MNT-016 taxonomy)
  * EA slug                       -> framework/registry/ea_id_registry.csv
  * gate display names            -> phase_ids.phase_label (Qxx only, ever)
  * terminal reservations         -> state/terminal_reservations.json
    (via farmctl.terminal_reservations, dead-holder pruning included)
  * OWNER decisions               -> D:/QM/reports/state/owner_decisions.json
    (curated feed) + BLOCKED agent_tasks naming OWNER + Q12 review-ready count
  * factory state / freshness     -> state/health.json, state/FACTORY_OFF.flag,
    state/FACTORY_ON_CEREMONY_INCOMPLETE.json

The emitter never opens the DB writable: it uses the ``mode=ro`` URI plus
``PRAGMA query_only=ON`` exactly like render_cockpit's ``db_rows``.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any

try:  # package import (tests, module consumers)
    from tools.strategy_farm.work_item_clean_view import install_clean_view
    from tools.strategy_farm.phase_ids import (
        phase_label,
        normalize_phase_id,
        PHASE_NAME,
    )
    from tools.strategy_farm import live_observability_contract as live_obs
except ModuleNotFoundError:  # direct ``python tools/strategy_farm/mission_control_v2_data.py``
    from work_item_clean_view import install_clean_view
    from phase_ids import phase_label, normalize_phase_id, PHASE_NAME
    import live_observability_contract as live_obs


SCHEMA_VERSION = "qm.mission_control.v2"

# --- canonical paths (module-level so tests can monkeypatch) ---
ROOT = Path(r"D:\QM\strategy_farm")
REPO = Path(r"C:\QM\repo")
DB = ROOT / "state" / "farm_state.sqlite"
REPORTS_STATE = Path(r"D:\QM\reports\state")
OUTPUT_PATH = REPORTS_STATE / "mission_control_v2_preview.json"
LIVE_BOOK_PULSE_STATE = REPORTS_STATE / "live_book_pulse.json"

HEALTH_FILE = ROOT / "state" / "health.json"
FACTORY_OFF_FLAG = ROOT / "state" / "FACTORY_OFF.flag"
FACTORY_ON_CEREMONY_INCOMPLETE = ROOT / "state" / "FACTORY_ON_CEREMONY_INCOMPLETE.json"
OWNER_DECISIONS_FILE = REPORTS_STATE / "owner_decisions.json"
EA_REGISTRY = REPO / "framework" / "registry" / "ea_id_registry.csv"

# Terminal fleet is fixed at T1..T10 (T_Live is C:\ and never a factory slot).
FLEET = tuple(f"T{i}" for i in range(1, 11))

# MT5-tester evidence phases a T1..T10 worker actually drains. Canonical Qxx
# plus their legacy P-aliases (storage may still carry P-keys for old rows).
# Q07 multi-seed runs on the tester too and is included. Q09_NEWS is an
# operator/decision gate (RNG-inert; service rate 0 — the "news dam") and is
# deliberately EXCLUDED from the drainable backlog so its parked rows never
# inflate the ETA. HARNESS_PP_FIXTURE is a test artifact and is excluded.
MT5_TESTER_PHASES = frozenset(
    {
        "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q10",
        # legacy P-key aliases for pre-2026-05-23 rows
        "P2", "P3", "P4", "P5", "P5B", "P5C", "P6", "P7", "P8",
    }
)

# Staleness SLAs (seconds). A section older than its SLA is badged STALE; a
# section that could not be produced at all is DEGRADED with a reason.
SLA_HEALTH_SEC = 20 * 60          # health.json: farmctl health runs /15 min
SLA_OWNER_DECISIONS_SEC = 48 * 3600  # curated feed, hand-maintained; lenient
SLA_RESERVATIONS_SEC = 30 * 60    # reservation file rewritten on each claim cycle

# Throughput sampling window for the ETA-to-empty forecast.
ETA_THROUGHPUT_WINDOW_HOURS = 24


# ---------------------------------------------------------------------------
# time helpers
# ---------------------------------------------------------------------------
def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(t: dt.datetime) -> str:
    return t.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def _parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        t = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=dt.timezone.utc)
        return t.astimezone(dt.timezone.utc)
    except (TypeError, ValueError):
        return None


def _age_seconds(value: str | None, *, now: dt.datetime | None = None) -> int | None:
    t = _parse_iso(value)
    if t is None:
        return None
    now = now or _now_utc()
    return max(0, int((now - t).total_seconds()))


def _file_mtime_iso(path: Path) -> str | None:
    try:
        if path.exists():
            return _iso(dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc))
    except OSError:
        return None
    return None


def _staleness(age_sec: int | None, sla_sec: int) -> str:
    """FRESH / STALE / UNKNOWN — a renderer maps these straight to a badge."""
    if age_sec is None:
        return "UNKNOWN"
    return "FRESH" if age_sec <= sla_sec else "STALE"


def _section_meta(
    *,
    source: str,
    source_as_of: str | None,
    sla_sec: int | None = None,
    degraded_reason: str | None = None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    age = _age_seconds(source_as_of, now=now) if source_as_of else None
    meta: dict[str, Any] = {
        "source": source,
        "source_as_of": source_as_of,
        "age_seconds": age,
        "staleness": _staleness(age, sla_sec) if sla_sec is not None else "N/A",
        "degraded_reason": degraded_reason,
    }
    return meta


# ---------------------------------------------------------------------------
# database access (read-only, clean view)
# ---------------------------------------------------------------------------
def _connect_ro(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA busy_timeout=5000")
    install_clean_view(con)
    con.execute("PRAGMA query_only=ON")
    return con


def _rows(con: sqlite3.Connection, query: str, params: tuple = ()) -> list[dict]:
    return [dict(r) for r in con.execute(query, params).fetchall()]


# ---------------------------------------------------------------------------
# EA slug registry
# ---------------------------------------------------------------------------
def load_ea_slugs(path: Path | None = None) -> dict[str, str]:
    """Map ``ea_id`` (as ``QM5_<n>`` and bare ``<n>``) -> slug. Missing -> {}."""
    path = path or EA_REGISTRY
    out: dict[str, str] = {}
    try:
        with Path(path).open(encoding="utf-8-sig", newline="") as fh:
            for row in csv.DictReader(fh):
                raw = str(row.get("ea_id") or "").strip()
                slug = str(row.get("slug") or "").strip()
                if not raw:
                    continue
                out[raw] = slug
                out[f"QM5_{raw}"] = slug  # work_items store the QM5_ form
    except (OSError, csv.Error):
        return {}
    return out


# ---------------------------------------------------------------------------
# section builders
# ---------------------------------------------------------------------------
def _phase_display(phase: str | None) -> dict[str, str]:
    """Return the Qxx label and name for a stored phase key (never a P-key)."""
    qid = phase_label(phase)  # always Qxx (or pass-through for odd keys)
    name = PHASE_NAME.get(qid, "")
    return {"phase_qid": qid, "phase_name": name}


def build_terminals(con: sqlite3.Connection, ea_slugs: dict[str, str],
                    *, now: dt.datetime | None = None,
                    reservations_override: dict[str, dict] | None = None) -> dict[str, Any]:
    """T1..T10 joined with their live farm assignment.

    JOIN: ``work_items_clean`` rows with ``status='active'`` on
    ``claimed_by`` == terminal name. This is the exact source render_cockpit's
    ``mt5_active_work()`` already reads (SELECT ... WHERE status='active'),
    only here the ``ea_id / symbol / phase / start / work-item id`` fields are
    surfaced instead of being reduced to an active/idle dot.

    RESERVED overlay: state/terminal_reservations.json via
    farmctl.terminal_reservations (dead-holder pruning). RUNNING beats RESERVED.
    """
    now = now or _now_utc()

    active = _rows(
        con,
        "SELECT id, ea_id, phase, symbol, claimed_by, updated_at "
        "FROM work_items_clean WHERE status='active'",
    )
    by_terminal: dict[str, dict] = {}
    for r in active:
        term = str(r.get("claimed_by") or "").strip().upper()
        if term in FLEET:
            # If two active rows ever claim one terminal, keep the newest.
            prev = by_terminal.get(term)
            if prev is None or str(r.get("updated_at") or "") >= str(prev.get("updated_at") or ""):
                by_terminal[term] = r

    # reservations (read-only file; fail open to {})
    reservations: dict[str, dict] = {}
    reservations_degraded = None
    if reservations_override is not None:
        reservations = reservations_override
    else:
        try:
            try:
                from tools.strategy_farm import farmctl
            except ModuleNotFoundError:
                import farmctl  # type: ignore
            reservations = farmctl.terminal_reservations(ROOT, now)
        except Exception as exc:  # noqa: BLE001 — reservations are advisory
            reservations_degraded = f"reservations unavailable: {exc}"

    terminals = []
    running = reserved = idle = 0
    for term in FLEET:
        row = by_terminal.get(term)
        resv = reservations.get(term)
        if row is not None:
            state = "RUNNING"
            running += 1
            start_iso = _iso(_parse_iso(row.get("updated_at")) or now)
            disp = _phase_display(row.get("phase"))
            ea_id = str(row.get("ea_id") or "")
            terminals.append({
                "terminal": term,
                "state": state,
                "work_item_id": row.get("id"),
                "ea_id": ea_id or None,
                "ea_slug": ea_slugs.get(ea_id) or None,
                "symbol": row.get("symbol") or None,
                "phase_qid": disp["phase_qid"],
                "phase_name": disp["phase_name"],
                "start_utc": start_iso,
                "elapsed_seconds": _age_seconds(row.get("updated_at"), now=now),
                "reservation": None,
                "idle_reason": None,
            })
        elif resv is not None:
            reserved += 1
            terminals.append({
                "terminal": term,
                "state": "RESERVED",
                "work_item_id": None,
                "ea_id": None,
                "ea_slug": None,
                "symbol": None,
                "phase_qid": None,
                "phase_name": None,
                "start_utc": None,
                "elapsed_seconds": None,
                "reservation": {
                    "reserved_by": resv.get("reserved_by"),
                    "reason": resv.get("reason"),
                    "until_utc": resv.get("until_utc"),
                },
                "idle_reason": "reserved (smoke/maintenance hold — blocks new claims)",
            })
        else:
            idle += 1
            terminals.append({
                "terminal": term,
                "state": "IDLE",
                "work_item_id": None,
                "ea_id": None,
                "ea_slug": None,
                "symbol": None,
                "phase_qid": None,
                "phase_name": None,
                "start_utc": None,
                "elapsed_seconds": None,
                "reservation": None,
                "idle_reason": "no active farm claim",
            })

    meta = _section_meta(
        source="farm_state.sqlite:work_items_clean(status='active') + "
               "state/terminal_reservations.json",
        source_as_of=_iso(now),
        sla_sec=SLA_RESERVATIONS_SEC,
        degraded_reason=reservations_degraded,
        now=now,
    )
    return {
        "meta": meta,
        "counts": {
            "running": running,
            "reserved": reserved,
            "idle": idle,
            "fleet_size": len(FLEET),
        },
        "terminals": terminals,
        "notes": (
            "state=RUNNING is authoritative from the farm claim (active work "
            "item). Live terminal64/worker process-scan confirmation is a "
            "renderer overlay and is intentionally not spawned here (read-only, "
            "process-free emitter). 'start_utc' is the active-claim transition "
            "time (updated_at); there is no separate claim-timestamp column."
        ),
    }


def _classify_progress(rows: list[dict]) -> dict[str, Any]:
    """Bucket already-terminal clean rows into the progress KPI counters.

    Definitions (single source of truth for today/yesterday/7d/total):
      completed      : row reached a terminal clean status (done|failed)
      gate_pass      : taxonomy=strategy AND verdict is a PASS-family token
      economic_fail  : taxonomy=strategy AND verdict is a FAIL/RETIRE/ZERO token
                       (incl. MULTI_SEED_MIXED — a mixed multi-seed is not a pass)
      infra_transient: taxonomy in (infra, invalid) — execution residue, NOT merit
      other          : governance/review/draft_defect/unknown terminal rows
    """
    pass_tokens = {"AUTO_PASS", "CONFIG_LOCKED", "MODE_SELECTED", "MULTI_SEED_PASS",
                   "PASS_PORTFOLIO"}
    completed = gate_pass = economic_fail = infra_transient = other = 0
    ea_symbol: set[tuple[str, str]] = set()
    for r in rows:
        completed += 1
        ea_symbol.add((str(r.get("ea_id") or ""), str(r.get("symbol") or "")))
        tax = str(r.get("verdict_taxonomy") or "")
        verdict = str(r.get("verdict") or "").upper()
        if tax == "strategy":
            if verdict.startswith("PASS") or verdict in pass_tokens:
                gate_pass += 1
            elif (verdict.startswith("FAIL") or verdict.startswith("RETIR")
                  or verdict.startswith("ZERO") or verdict == "MULTI_SEED_MIXED"):
                economic_fail += 1
            else:
                other += 1
        elif tax in ("infra", "invalid"):
            infra_transient += 1
        else:
            other += 1
    infra_rate = round(infra_transient / completed, 4) if completed else None
    return {
        "completed": completed,
        "distinct_ea_symbol": len(ea_symbol),
        "gate_pass": gate_pass,
        "economic_fail": economic_fail,
        "infra_transient": infra_transient,
        "other": other,
        "infra_rate": infra_rate,
    }


def build_progress(con: sqlite3.Connection, *, now: dt.datetime | None = None) -> dict[str, Any]:
    """today / yesterday / 7-day-average-per-day / total progress KPIs.

    Counting basis (documented, identical across all windows): a progress event
    is a ``work_items_clean`` row that has reached a terminal clean status
    (``done`` or ``failed``) in an MT5-tester phase, counted by its ``updated_at``
    transition timestamp. There is no ``completed_at`` column in the schema;
    ``updated_at`` is the transition marker. Append-only reruns create NEW rows,
    so a requeue is a separate event and never rewrites a prior row's timestamp.
    """
    now = now or _now_utc()
    today = now.date()

    placeholders = ",".join("?" for _ in MT5_TESTER_PHASES)
    phase_params = tuple(sorted(MT5_TESTER_PHASES))

    # Windowed rows: pull the last 8 calendar days once, bucket in Python.
    windowed = _rows(
        con,
        f"""
        SELECT ea_id, symbol, phase, verdict, verdict_taxonomy, updated_at
        FROM work_items_clean
        WHERE status IN ('done','failed')
          AND UPPER(phase) IN ({placeholders})
          AND updated_at >= datetime('now','-8 days')
        """,
        phase_params,
    )

    def in_day(row: dict, delta_days: int) -> bool:
        d = _parse_iso(row.get("updated_at"))
        return d is not None and (today - d.date()).days == delta_days

    def in_last(row: dict, days: int) -> bool:
        d = _parse_iso(row.get("updated_at"))
        return d is not None and 0 <= (today - d.date()).days < days

    today_rows = [r for r in windowed if in_day(r, 0)]
    yday_rows = [r for r in windowed if in_day(r, 1)]

    today_kpi = _classify_progress(today_rows)
    yday_kpi = _classify_progress(yday_rows)

    # 7-day average = the mean of the per-day KPIs over the trailing 7 calendar
    # days (day 0..6). A true daily mean: distinct_ea_symbol is the mean of each
    # day's own distinct-pair count (NOT a 7-day-window distinct / 7, which
    # double-counts pairs touched on several days), and infra_rate is recomputed
    # from the averaged counts.
    daily_kpis = [_classify_progress([r for r in windowed if in_day(r, d)])
                  for d in range(7)]
    count_fields = ("completed", "distinct_ea_symbol", "gate_pass",
                    "economic_fail", "infra_transient", "other")
    seven_day_avg = {
        f: round(sum(k[f] for k in daily_kpis) / 7, 2) for f in count_fields
    }
    seven_day_avg["infra_rate"] = (
        round(seven_day_avg["infra_transient"] / seven_day_avg["completed"], 4)
        if seven_day_avg["completed"] else None
    )
    seven_day_avg["_basis"] = "mean of the 7 per-day KPIs (day 0..6)"

    # Total (all-time). Aggregate counts + distinct pairs + since.
    total_agg = _rows(
        con,
        f"""
        SELECT
          COUNT(*) AS completed,
          COUNT(DISTINCT ea_id || '|' || symbol) AS distinct_ea_symbol,
          SUM(CASE WHEN verdict_taxonomy='strategy'
                    AND (verdict LIKE 'PASS%' OR verdict IN
                        ('AUTO_PASS','CONFIG_LOCKED','MODE_SELECTED',
                         'MULTI_SEED_PASS','PASS_PORTFOLIO'))
                   THEN 1 ELSE 0 END) AS gate_pass,
          SUM(CASE WHEN verdict_taxonomy='strategy'
                    AND (verdict LIKE 'FAIL%' OR verdict LIKE 'RETIR%'
                         OR verdict LIKE 'ZERO%' OR verdict='MULTI_SEED_MIXED')
                   THEN 1 ELSE 0 END) AS economic_fail,
          SUM(CASE WHEN verdict_taxonomy IN ('infra','invalid')
                   THEN 1 ELSE 0 END) AS infra_transient,
          MIN(updated_at) AS since
        FROM work_items_clean
        WHERE status IN ('done','failed')
          AND UPPER(phase) IN ({placeholders})
        """,
        phase_params,
    )[0]
    completed_total = int(total_agg.get("completed") or 0)
    total_kpi = {
        "completed": completed_total,
        "distinct_ea_symbol": int(total_agg.get("distinct_ea_symbol") or 0),
        "gate_pass": int(total_agg.get("gate_pass") or 0),
        "economic_fail": int(total_agg.get("economic_fail") or 0),
        "infra_transient": int(total_agg.get("infra_transient") or 0),
        "infra_rate": (
            round(int(total_agg.get("infra_transient") or 0) / completed_total, 4)
            if completed_total else None
        ),
        "since": str(total_agg.get("since") or "")[:19] or None,
    }

    meta = _section_meta(
        source="farm_state.sqlite:work_items_clean(status IN done,failed; MT5 phases; by updated_at)",
        source_as_of=_iso(now),
        sla_sec=None,
        now=now,
    )
    return {
        "meta": meta,
        "phase_set": sorted(MT5_TESTER_PHASES),
        "today": today_kpi,
        "yesterday": yday_kpi,
        "seven_day_average": seven_day_avg,
        "total": total_kpi,
        "counting_basis": (
            "Terminal work_items_clean rows (done|failed) in MT5-tester phases, "
            "counted by updated_at. No completed_at column exists; updated_at is "
            "the transition marker. Requeues are new rows (separate events)."
        ),
        "caveats": [
            "TOTAL mixes contract eras: gate thresholds and sub-gate calibrations "
            "changed over time (2026-05-23 work_items wipe; later Q04/Q08 "
            "recalibrations). Cross-era PASS/FAIL counts are not strictly "
            "comparable — always show TOTAL with its 'since'.",
            "infra_transient is execution residue re-labelled by the MNT-016 "
            "clean view, not a merit outcome; it is excluded from gate_pass and "
            "economic_fail and surfaced as its own rate.",
            "distinct_ea_symbol counts pairs TOUCHED (a terminal transition) in "
            "the window, not pairs advanced a gate.",
        ],
    }


def build_queue(con: sqlite3.Connection, *, now: dt.datetime | None = None) -> dict[str, Any]:
    """Full pending queue + ETA-to-empty with an explicit basis.

    ETA basis: drainable backlog (pending rows in MT5-tester phases) divided by
    measured recent throughput (terminal transitions in those phases over the
    trailing 24h). Q09_NEWS-style operator/parked pending is reported separately
    and EXCLUDED from the drain estimate. ETA is drain-only: it assumes no new
    arrivals from upstream passes, which is a lower bound on real clear time.
    """
    now = now or _now_utc()
    placeholders = ",".join("?" for _ in MT5_TESTER_PHASES)
    phase_params = tuple(sorted(MT5_TESTER_PHASES))

    # Pending backlog by phase (all pending, then split executable vs parked).
    pending_by_phase = _rows(
        con,
        """
        SELECT phase, COUNT(*) AS pending,
               MIN(created_at) AS oldest_created_at
        FROM work_items_clean
        WHERE status='pending'
        GROUP BY phase
        ORDER BY pending DESC
        """,
    )
    active_count = _rows(
        con, "SELECT COUNT(*) AS c FROM work_items_clean WHERE status='active'"
    )[0]["c"]

    executable_rows = []
    parked_rows = []
    pending_executable = 0
    pending_parked = 0
    for r in pending_by_phase:
        disp = _phase_display(r.get("phase"))
        entry = {
            "phase_qid": disp["phase_qid"],
            "phase_name": disp["phase_name"],
            "pending": int(r.get("pending") or 0),
            "oldest_created_at": str(r.get("oldest_created_at") or "")[:19] or None,
        }
        if normalize_phase_id(r.get("phase")) in MT5_TESTER_PHASES:
            executable_rows.append(entry)
            pending_executable += entry["pending"]
        else:
            parked_rows.append(entry)
            pending_parked += entry["pending"]

    # Throughput over trailing 24h (executable-phase terminal transitions).
    tput = _rows(
        con,
        f"""
        SELECT COUNT(*) AS n
        FROM work_items_clean
        WHERE status IN ('done','failed')
          AND UPPER(phase) IN ({placeholders})
          AND updated_at >= datetime('now','-{ETA_THROUGHPUT_WINDOW_HOURS} hours')
        """,
        phase_params,
    )[0]["n"]
    tput = int(tput or 0)
    per_hour = tput / ETA_THROUGHPUT_WINDOW_HOURS if tput else 0.0

    eta_degraded = None
    if per_hour > 0:
        eta_hours_p50 = round(pending_executable / per_hour, 2)
        # P90 band: assume throughput can sag to ~60% of the 24h mean (slow
        # cold-cache / partial-fleet stretches). Honest band, not false spread.
        eta_hours_p90 = round(pending_executable / (per_hour * 0.6), 2)
    else:
        eta_hours_p50 = None
        eta_hours_p90 = None
        eta_degraded = "no executable-phase throughput in the last 24h (rate=0)"

    meta = _section_meta(
        source="farm_state.sqlite:work_items_clean(status='pending'/'active') + 24h throughput",
        source_as_of=_iso(now),
        sla_sec=None,
        degraded_reason=eta_degraded,
        now=now,
    )
    return {
        "meta": meta,
        "pending_total": pending_executable + pending_parked,
        "pending_executable": pending_executable,
        "pending_parked": pending_parked,
        "active": int(active_count or 0),
        "by_phase_executable": executable_rows,
        "by_phase_parked": parked_rows,
        "eta_to_empty": {
            "basis": (
                "drainable executable backlog / measured 24h throughput; "
                "drain-only (no upstream arrivals modelled) -> lower bound"
            ),
            "pending_executable": pending_executable,
            "throughput_per_hour_24h": round(per_hour, 3),
            "throughput_count_24h": tput,
            "eta_hours_p50": eta_hours_p50,
            "eta_hours_p90": eta_hours_p90,
            "eta_empty_utc_p50": (
                _iso(now + dt.timedelta(hours=eta_hours_p50))
                if eta_hours_p50 is not None else None
            ),
        },
        "notes": (
            "pending_parked (e.g. Q09_NEWS) is excluded from ETA: those rows are "
            "operator/decision-gated, not terminal-drainable, and would inflate "
            "the forecast. 'active' is the count of in-flight claims (<= fleet)."
        ),
    }


def build_owner_decisions(con: sqlite3.Connection, *, now: dt.datetime | None = None) -> dict[str, Any]:
    """Genuine OWNER decisions only — curated feed + BLOCKED-naming-OWNER + Q12.

    Mirrors render_cockpit.owner_decision_rows' source order and exclusions
    (agent work queues are NOT owner decisions), emitted as structured rows.
    """
    now = now or _now_utc()
    items: list[dict] = []

    # Q12 review-ready count (portfolio admission is an OWNER gate).
    try:
        q12_count = int(_rows(
            con,
            "SELECT COUNT(*) AS c FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'",
        )[0]["c"])
    except Exception:  # noqa: BLE001
        q12_count = 0

    # 1. curated feed
    feed_as_of = None
    feed_degraded = None
    try:
        data = json.loads(OWNER_DECISIONS_FILE.read_text(encoding="utf-8-sig"))
        feed_as_of = data.get("updated_at_utc") or _file_mtime_iso(OWNER_DECISIONS_FILE)
        for item in data.get("items") or []:
            detail = str(item.get("detail") or "").replace("{q12_count}", str(q12_count))
            sev = str(item.get("severity") or "").lower()
            items.append({
                "source": "curated_feed",
                "category": str(item.get("cat") or "DECISION"),
                "title": str(item.get("title") or "?"),
                "detail": detail,
                "due": str(item.get("due") or "") or None,
                "severity": sev or "info",
                "alert": sev in ("alert", "action"),
            })
    except FileNotFoundError:
        feed_degraded = "curated owner_decisions.json missing"
    except (OSError, json.JSONDecodeError) as exc:
        feed_degraded = f"curated feed unreadable: {exc}"

    # Q12 admission fallback row (only if the feed did not already carry one).
    if q12_count and not any(i["category"].upper() == "ADMISSION" for i in items):
        items.append({
            "source": "q12_review_ready",
            "category": "ADMISSION",
            "title": f"{q12_count} candidates Q12_REVIEW_READY",
            "detail": "portfolio admission is an OWNER gate",
            "due": None,
            "severity": "info",
            "alert": False,
        })

    # 2. BLOCKED agent_tasks whose unblock condition names OWNER (excluding
    #    superseded/obsolete epitaphs).
    try:
        blocked = _rows(
            con,
            "SELECT id, task_type, verdict, updated_at FROM agent_tasks "
            "WHERE state='BLOCKED' AND verdict LIKE '%OWNER%' "
            "ORDER BY updated_at DESC LIMIT 6",
        )
    except Exception:  # noqa: BLE001
        blocked = []
    import re
    for b in blocked:
        v = str(b.get("verdict") or "")
        if re.search(r"supersed|obsolete", v, re.IGNORECASE):
            continue
        items.append({
            "source": "blocked_agent_task",
            "category": "BLOCKED",
            "title": str(b.get("task_type") or b.get("id") or "OWNER-blocked task"),
            "detail": v[:200],
            "due": None,
            "severity": "action",
            "alert": True,
        })
        if sum(1 for i in items if i["source"] == "blocked_agent_task") >= 3:
            break

    alert_count = sum(1 for i in items if i.get("alert"))
    meta = _section_meta(
        source="D:/QM/reports/state/owner_decisions.json + agent_tasks(BLOCKED,OWNER) + Q12",
        source_as_of=feed_as_of or _iso(now),
        sla_sec=SLA_OWNER_DECISIONS_SEC,
        degraded_reason=feed_degraded,
        now=now,
    )
    return {
        "meta": meta,
        "count": len(items),
        "alert_count": alert_count,
        "q12_review_ready": q12_count,
        "items": items,
        "notes": (
            "Agent work queues (Claude reviews, ops-blocked builds, router SLAs) "
            "are agent status, never OWNER decisions, and are excluded by "
            "construction."
        ),
    }


def build_control_strip(con: sqlite3.Connection, queue: dict, terminals: dict,
                        owner: dict, *, now: dt.datetime | None = None) -> dict[str, Any]:
    """Global control strip: factory state, freshness, queue total, ETA, owner."""
    now = now or _now_utc()

    # Factory state precedence mirrors render_cockpit's topbar logic (data-only).
    ceremony_incomplete = _safe_exists(FACTORY_ON_CEREMONY_INCOMPLETE)
    factory_off = _safe_exists(FACTORY_OFF_FLAG)

    health = {}
    health_as_of = None
    health_degraded = None
    try:
        health = json.loads(HEALTH_FILE.read_text(encoding="utf-8"))
        health_as_of = health.get("checked_at") or _file_mtime_iso(HEALTH_FILE)
    except FileNotFoundError:
        health_degraded = "health.json missing"
    except (OSError, json.JSONDecodeError) as exc:
        health_degraded = f"health.json unreadable: {exc}"

    checks = health.get("checks") or []
    fail_checks = [c for c in checks if str(c.get("status") or "").upper() == "FAIL"]
    factory_down_checks = {
        "mt5_worker_saturation", "codex_auth_broken", "disk_free_gb",
        "pump_task_lastresult", "factory_on_ceremony_incomplete",
        "ablation_grandchildren", "active_row_age",
    }
    factory_fail = [c for c in fail_checks if c.get("name") in factory_down_checks]

    if ceremony_incomplete:
        factory_state = "CRITICAL"
        state_reason = "Factory_ON ceremony incomplete — mutation window not certified"
    elif factory_off:
        factory_state = "MAINTENANCE"
        state_reason = "FACTORY_OFF.flag present (intentional stop)"
    elif factory_fail:
        factory_state = "CRITICAL"
        state_reason = " // ".join(
            f"{c.get('name')}: {str(c.get('detail'))[:90]}" for c in factory_fail[:2]
        )
    elif fail_checks or str(health.get("overall") or "").upper() in ("WARN", "FAIL"):
        factory_state = "DEGRADED"
        first = fail_checks[0] if fail_checks else {}
        state_reason = (
            f"{first.get('name')}: {str(first.get('detail'))[:90]}"
            if first else f"health overall={health.get('overall')}"
        )
    else:
        factory_state = "NOMINAL"
        state_reason = "all factory-down checks pass"

    health_age = _age_seconds(health_as_of, now=now)

    # Freshness roll-up across the critical readmodels this contract depends on.
    critical_readmodels = [
        {"name": "health.json", "as_of": health_as_of,
         "age_seconds": health_age, "sla_sec": SLA_HEALTH_SEC,
         "staleness": _staleness(health_age, SLA_HEALTH_SEC)},
        {"name": "owner_decisions.json", "as_of": owner["meta"]["source_as_of"],
         "age_seconds": owner["meta"]["age_seconds"], "sla_sec": SLA_OWNER_DECISIONS_SEC,
         "staleness": owner["meta"]["staleness"]},
        {"name": "terminal_reservations.json", "as_of": terminals["meta"]["source_as_of"],
         "age_seconds": terminals["meta"]["age_seconds"], "sla_sec": SLA_RESERVATIONS_SEC,
         "staleness": terminals["meta"]["staleness"]},
    ]
    ages = [r["age_seconds"] for r in critical_readmodels if r["age_seconds"] is not None]
    any_stale = any(r["staleness"] == "STALE" for r in critical_readmodels)

    meta = _section_meta(
        source="state/health.json + FACTORY_OFF.flag + FACTORY_ON_CEREMONY_INCOMPLETE.json",
        source_as_of=health_as_of or _iso(now),
        sla_sec=SLA_HEALTH_SEC,
        degraded_reason=health_degraded,
        now=now,
    )
    return {
        "meta": meta,
        "factory_state": factory_state,
        "factory_state_reason": state_reason,
        "health_overall": health.get("overall"),
        "health_fail_count": len(fail_checks),
        "data_freshness": {
            "youngest_age_seconds": min(ages) if ages else None,
            "oldest_age_seconds": max(ages) if ages else None,
            "any_stale": any_stale,
            "critical_readmodels": critical_readmodels,
        },
        "queue_total": queue["pending_total"] + queue["active"],
        "queue_pending_executable": queue["pending_executable"],
        "queue_active": queue["active"],
        "clear_eta_hours_p50": queue["eta_to_empty"]["eta_hours_p50"],
        "clear_eta_hours_p90": queue["eta_to_empty"]["eta_hours_p90"],
        "terminals": terminals["counts"],
        "owner_decisions_open": owner["count"],
        "owner_decisions_alert": owner["alert_count"],
    }


def _safe_exists(path: Path) -> bool:
    try:
        return path.exists()
    except OSError:
        return False


# ---------------------------------------------------------------------------
# top-level assembly
# ---------------------------------------------------------------------------
def _load_live_observability(
    *,
    now: dt.datetime,
    pulse_path: Path | None = None,
) -> dict[str, Any]:
    """Consume Pulse's producer contract; never use this emitter's timestamp
    to replace any source timestamp."""
    return live_obs.load_from_pulse(
        Path(pulse_path or LIVE_BOOK_PULSE_STATE),
        observed_at=now,
    )


def build_contract(
    db: Path | None = None,
    *,
    now: dt.datetime | None = None,
    live_pulse_path: Path | None = None,
) -> dict[str, Any]:
    """Assemble the full ``qm.mission_control.v2`` contract from live sources."""
    db = Path(db) if db is not None else DB
    now = now or _now_utc()
    ea_slugs = load_ea_slugs()

    con = _connect_ro(db)
    try:
        terminals = build_terminals(con, ea_slugs, now=now)
        progress = build_progress(con, now=now)
        queue = build_queue(con, now=now)
        owner = build_owner_decisions(con, now=now)
        control_strip = build_control_strip(con, queue, terminals, owner, now=now)
    finally:
        con.close()

    live_observability = _load_live_observability(
        now=now,
        pulse_path=live_pulse_path,
    )

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": _iso(now),
        "source_db": str(db),
        "live_observability": live_observability,
        "control_strip": control_strip,
        "queue": queue,
        "progress": progress,
        "terminals": terminals,
        "owner_decisions": owner,
    }


# ---------------------------------------------------------------------------
# JSON Schema + dependency-free validator
# ---------------------------------------------------------------------------
def _section_meta_schema() -> dict:
    return {
        "type": "object",
        "required": ["source", "source_as_of", "staleness"],
        "properties": {
            "source": {"type": "string"},
            "source_as_of": {"type": ["string", "null"]},
            "age_seconds": {"type": ["integer", "null"]},
            "staleness": {"enum": ["FRESH", "STALE", "UNKNOWN", "N/A"]},
            "degraded_reason": {"type": ["string", "null"]},
        },
    }


CONTRACT_SCHEMA: dict[str, Any] = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "qm.mission_control.v2",
    "type": "object",
    "required": [
        "schema_version", "generated_at", "control_strip", "queue",
        "progress", "terminals", "owner_decisions",
    ],
    "properties": {
        "schema_version": {"const": SCHEMA_VERSION},
        "generated_at": {"type": "string"},
        "source_db": {"type": "string"},
        "live_observability": {
            "type": "object",
            "required": [
                "schema_version", "observed_at_utc", "status", "sources",
                "fingerprints", "latency",
            ],
            "properties": {
                "schema_version": {"const": live_obs.SCHEMA_VERSION},
                "observed_at_utc": {"type": "string"},
                "status": {"enum": ["GREEN", "STALE", "UNKNOWN"]},
                "sources": {"type": "object"},
                "fingerprints": {"type": "object"},
                "latency": {"type": "object"},
            },
        },
        "control_strip": {
            "type": "object",
            "required": ["meta", "factory_state", "queue_total", "data_freshness"],
            "properties": {
                "meta": _section_meta_schema(),
                "factory_state": {
                    "enum": ["NOMINAL", "DEGRADED", "MAINTENANCE", "CRITICAL"]
                },
                "factory_state_reason": {"type": "string"},
                "queue_total": {"type": "integer"},
                "clear_eta_hours_p50": {"type": ["number", "null"]},
                "clear_eta_hours_p90": {"type": ["number", "null"]},
                "owner_decisions_open": {"type": "integer"},
                "data_freshness": {
                    "type": "object",
                    "required": ["any_stale", "critical_readmodels"],
                    "properties": {
                        "any_stale": {"type": "boolean"},
                        "critical_readmodels": {"type": "array"},
                    },
                },
            },
        },
        "queue": {
            "type": "object",
            "required": ["meta", "pending_total", "pending_executable",
                         "active", "eta_to_empty"],
            "properties": {
                "meta": _section_meta_schema(),
                "pending_total": {"type": "integer"},
                "pending_executable": {"type": "integer"},
                "pending_parked": {"type": "integer"},
                "active": {"type": "integer"},
                "by_phase_executable": {"type": "array"},
                "by_phase_parked": {"type": "array"},
                "eta_to_empty": {
                    "type": "object",
                    "required": ["basis", "throughput_per_hour_24h",
                                 "eta_hours_p50"],
                    "properties": {
                        "basis": {"type": "string"},
                        "throughput_per_hour_24h": {"type": "number"},
                        "eta_hours_p50": {"type": ["number", "null"]},
                        "eta_hours_p90": {"type": ["number", "null"]},
                    },
                },
            },
        },
        "progress": {
            "type": "object",
            "required": ["meta", "today", "yesterday", "seven_day_average",
                         "total", "counting_basis"],
            "properties": {
                "meta": _section_meta_schema(),
                "today": {"$ref": "#/$defs/kpi"},
                "yesterday": {"$ref": "#/$defs/kpi"},
                "total": {"type": "object"},
                "seven_day_average": {"type": "object"},
                "counting_basis": {"type": "string"},
                "caveats": {"type": "array", "items": {"type": "string"}},
            },
        },
        "terminals": {
            "type": "object",
            "required": ["meta", "counts", "terminals"],
            "properties": {
                "meta": _section_meta_schema(),
                "counts": {
                    "type": "object",
                    "required": ["running", "reserved", "idle", "fleet_size"],
                    "properties": {
                        "running": {"type": "integer"},
                        "reserved": {"type": "integer"},
                        "idle": {"type": "integer"},
                        "fleet_size": {"type": "integer"},
                    },
                },
                "terminals": {
                    "type": "array",
                    "minItems": 10,
                    "maxItems": 10,
                    "items": {
                        "type": "object",
                        "required": ["terminal", "state"],
                        "properties": {
                            "terminal": {"type": "string"},
                            "state": {"enum": ["RUNNING", "RESERVED", "IDLE", "ERROR"]},
                            "ea_id": {"type": ["string", "null"]},
                            "ea_slug": {"type": ["string", "null"]},
                            "symbol": {"type": ["string", "null"]},
                            "phase_qid": {"type": ["string", "null"]},
                            "work_item_id": {"type": ["string", "null"]},
                            "start_utc": {"type": ["string", "null"]},
                            "elapsed_seconds": {"type": ["integer", "null"]},
                        },
                    },
                },
            },
        },
        "owner_decisions": {
            "type": "object",
            "required": ["meta", "count", "items"],
            "properties": {
                "meta": _section_meta_schema(),
                "count": {"type": "integer"},
                "alert_count": {"type": "integer"},
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": ["category", "title", "severity"],
                        "properties": {
                            "category": {"type": "string"},
                            "title": {"type": "string"},
                            "detail": {"type": ["string", "null"]},
                            "due": {"type": ["string", "null"]},
                            "severity": {"type": "string"},
                            "alert": {"type": "boolean"},
                        },
                    },
                },
            },
        },
    },
    "$defs": {
        "kpi": {
            "type": "object",
            "required": ["completed", "distinct_ea_symbol", "gate_pass",
                         "economic_fail", "infra_transient"],
            "properties": {
                "completed": {"type": "integer"},
                "distinct_ea_symbol": {"type": "integer"},
                "gate_pass": {"type": "integer"},
                "economic_fail": {"type": "integer"},
                "infra_transient": {"type": "integer"},
                "infra_rate": {"type": ["number", "null"]},
            },
        },
    },
}


class ContractValidationError(AssertionError):
    """Raised when the contract does not satisfy CONTRACT_SCHEMA."""


def _resolve_ref(ref: str, root: dict) -> dict:
    node: Any = root
    for part in ref.lstrip("#/").split("/"):
        if not part:
            continue
        node = node[part]
    return node


_TYPE_MAP = {
    "object": dict,
    "array": list,
    "string": str,
    "boolean": bool,
    "null": type(None),
}


def _check_type(value: Any, type_spec: Any) -> bool:
    types = type_spec if isinstance(type_spec, list) else [type_spec]
    for t in types:
        if t == "number":
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                return True
        elif t == "integer":
            if isinstance(value, int) and not isinstance(value, bool):
                return True
        elif t in _TYPE_MAP and isinstance(value, _TYPE_MAP[t]):
            # bool is a subclass of int — exclude it from "object"/etc naturally;
            # only "boolean" matches bools.
            if t != "boolean" and isinstance(value, bool):
                continue
            return True
    return False


def _validate_node(value: Any, schema: dict, root: dict, path: str,
                   errors: list[str]) -> None:
    if "$ref" in schema:
        schema = _resolve_ref(schema["$ref"], root)
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: expected const {schema['const']!r}, got {value!r}")
        return
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: {value!r} not in enum {schema['enum']}")
        return
    if "type" in schema and not _check_type(value, schema["type"]):
        errors.append(f"{path}: expected type {schema['type']}, got {type(value).__name__}")
        return
    if isinstance(value, dict):
        for req in schema.get("required", []):
            if req not in value:
                errors.append(f"{path}: missing required key '{req}'")
        props = schema.get("properties", {})
        for key, subschema in props.items():
            if key in value:
                _validate_node(value[key], subschema, root, f"{path}.{key}", errors)
    elif isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            errors.append(f"{path}: {len(value)} items < minItems {schema['minItems']}")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path}: {len(value)} items > maxItems {schema['maxItems']}")
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for i, item in enumerate(value):
                _validate_node(item, item_schema, root, f"{path}[{i}]", errors)


def validate_contract(instance: dict, schema: dict | None = None) -> None:
    """Validate ``instance`` against CONTRACT_SCHEMA.

    Uses the ``jsonschema`` package when available; otherwise falls back to the
    embedded dependency-free validator (a JSON-Schema subset sufficient for this
    contract). Raises ContractValidationError on any violation.
    """
    schema = schema or CONTRACT_SCHEMA
    try:
        import jsonschema  # type: ignore

        jsonschema.validate(instance=instance, schema=schema)
        return
    except ModuleNotFoundError:
        pass
    except Exception as exc:  # jsonschema.ValidationError et al.
        raise ContractValidationError(str(exc)) from exc

    errors: list[str] = []
    _validate_node(instance, schema, schema, "$", errors)
    if errors:
        raise ContractValidationError("; ".join(errors))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=None,
                        help="override farm_state.sqlite path")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH,
                        help="output JSON path (default: preview file)")
    parser.add_argument("--stdout", action="store_true",
                        help="also print the contract to stdout")
    parser.add_argument("--no-validate", action="store_true",
                        help="skip schema validation (diagnostics only)")
    args = parser.parse_args(argv)

    contract = build_contract(args.db)
    if not args.no_validate:
        validate_contract(contract)

    rendered = json.dumps(contract, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        write_text_atomic(args.output, rendered)
    if args.stdout or not args.output:
        sys.stdout.write(rendered)

    cs = contract["control_strip"]
    sys.stderr.write(
        f"[mission_control_v2] factory={cs['factory_state']} "
        f"queue_total={cs['queue_total']} "
        f"terminals running={cs['terminals']['running']} "
        f"owner_open={cs['owner_decisions_open']} "
        f"-> {args.output}\n"
    )
    return 0


def write_text_atomic(path: Path, rendered: str) -> None:
    """Same-directory replace keeps readers off partial fresh envelopes."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(rendered, encoding="utf-8", newline="\n")
    os.replace(temp, path)


if __name__ == "__main__":
    raise SystemExit(main())
