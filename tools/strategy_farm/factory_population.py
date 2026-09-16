"""Factory population reconciliation read-model (``qm.factory-population/v1``).

Durable successor of ``factory_three_numbers.py`` (which it extends but does not
modify). Every Mission Control "open" row is classified exactly once, every MC
"parking-lot" row exactly once, and the OWNER-mandated multi-count view +
recovery backlog + runnable-hours forecast are persisted to
``D:/QM/reports/state/factory_population.json``. The legacy
``factory_three_numbers.json`` contract (``qm.factory-three-numbers/v1``) is
re-emitted from the same computation pass so existing consumers keep working.

The four counts:

  * OPEN_PIPELINE_ROWS — MC "Queue" main number: pending rows in MT5-tester
    phases (what ``mission_control_v2_data.build_queue`` calls
    ``pending_executable``; rendered by ``render_cockpit_v2`` Queue cell).
  * TRUE_CLAIMABLE_WORK — rows of ``farmctl.pending_claim_order_sql()``
    (Level 1) minus rows failing ``dsr_cohort.claimability_precheck``
    (Level 2, Q08 only; a raising precheck counts the row, fail-open, exactly
    as the watchdog v2 here-string). RAM is NOT part of this number.
  * RESOURCE_FEASIBLE_RUNNABLE_WORK — TRUE_CLAIMABLE rows whose measured
    reservation (``terminal_worker._ram_reservation_detail_for_candidate``:
    max(flat class, measured expectation, phase floor)) plus the class floor
    (``_ram_floor_for_class``) fits the host's currently free RAM. The Q06
    37.9 GB measured class and the parked flat-44 GB cohort live here.
  * ACTIVE_ECONOMIC_BACKTESTS — ``COUNT(work_items WHERE status='active')``.

Classifiers (OPEN buckets): ACTIVE_NOW, RUNNABLE_NOW, RESOURCE_BLOCKED,
GOVERNANCE_BLOCKED, DSR_CONTEXT_BLOCKED, BUILD_IDENTITY_BLOCKED,
ARTIFACT_BINDING_BLOCKED, COMPILE_OR_BUILD_BLOCKED, REQUEUE_EXCLUDED,
DATA_OR_HISTORY_BLOCKED, ANALYTIC_DECLARATION_ONLY, SUPERSEDED_REPAIR,
STALE_OR_ORPHAN, OTHER. Classification is precedence-ordered; every row lands
in exactly one bucket and bucket sums equal the MC populations exactly.

Parked buckets: RECOVERABLE_WITHOUT_OWNER, RECOVERABLE_WITH_EXISTING_AUTHORITY,
REQUIRES_NEW_OWNER_DECISION, RESOURCE_BLOCKED, INTENTIONALLY_INERT,
ECONOMICALLY_TERMINAL (plus OTHER as a loud, normally-empty catch-all).

Health (persisted across runs via the previous output document):
  FACTORY_BUFFER_LOW = AMBER when FORECAST_RUNNABLE_HOURS < 2 h and
  recoverable high-value work > 0; FACTORY_IDLE_WITH_RUNNABLE_WORK = RED when
  active = 0 AND resource-feasible > 0 in two consecutive runs; classification
  RUNNING / BUFFER_LOW / IDLE_WITH_RUNNABLE_WORK / IDLE_RED / NO_RUNNABLE_WORK
  (NO_RUNNABLE_WORK only when resource-feasible = 0 AND recoverable
  high-value = 0 — otherwise the classification names what blocks, e.g.
  IDLE_RESOURCE_GATED with the blocking cohorts listed).

The module never opens the DB writable, never starts a process, and never
forges unavailable inputs (degraded paths are explicit).

CLI::

    python tools/strategy_farm/factory_population.py
    python tools/strategy_farm/factory_population.py --stdout
"""

from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import json
import math
import os
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Mapping

SCHEMA_VERSION = "qm.factory-population/v1"

ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_STATE = Path(r"D:\QM\reports\state")
DB = ROOT / "state" / "farm_state.sqlite"
OUTPUT_PATH = REPORTS_STATE / "factory_population.json"
LEGACY_OUTPUT_PATH = REPORTS_STATE / "factory_three_numbers.json"
TESTER_MEMORY_LEDGER = REPORTS_STATE / "tester_memory_ledger.jsonl"
Q12_DRYRUN_RECEIPT = Path(r"D:\QM\reports\dl089_matrix_service_dryrun_20260916_all106.json")
SECOND_CHANCE_REGISTER = REPORTS_STATE / "second_chance_register.json"
BOOK_FTMO = REPORTS_STATE / "book_evolution_ftmo.json"
BOOK_DXZ = REPORTS_STATE / "book_evolution_dxz.json"

# The MC "executable" phase set, kept in lockstep with
# mission_control_v2_data.MT5_TESTER_PHASES (the render data contract). A
# startup self-check asserts equality when that module is importable.
MT5_TESTER_PHASES = frozenset(
    {
        "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q10",
        "P2", "P3", "P4", "P5", "P5B", "P5C", "P6", "P7", "P8",
    }
)

# ---------------------------------------------------------------------------
# Settled-decision cohorts (frozen records, same idiom as
# work_item_clean_view.DEFECT_BLOCK_COHORT — historical facts, not live state).
# ---------------------------------------------------------------------------
# OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916 batch-2: the 8 staged Q08 rows whose
# cards were amended under V3 but which carried no recorded build identity.
# Dispositions applied 2026-09-16T11:57:58Z (receipt d59b2277 batch2); kept for
# subcategory attribution of any stragglers still carrying the defect.
BATCH2_BUILD_IDENTITY_IDS = frozenset(
    {
        "456f590f-0ef0-4cbf-8d46-9508f84455ea",  # QM5_10287
        "ff0b551b-b00c-47d0-9040-110fd75e30a9",  # QM5_9576
        "a591ff4c-a104-4d26-b996-0881e3758703",  # QM5_1230
        "885b82ab-b7bb-4c00-85e3-03f1e8170c3d",  # QM5_9973
        "bb5eccf7-1635-4383-9d72-5843408b9567",  # QM5_13012
        "1494bfb4-c698-4ad3-99d2-7c3e4e2723a2",  # QM5_11882
        "b11e5b43-f9f5-4238-b00e-3ff73f9c7277",  # QM5_10269
        "aec37e79-d8e0-41a6-ab34-16ed3f893715",  # QM5_10280
    }
)

# Queued OWNER decisions (KIMI_INTERIM_HANDOFF_2026-09-18.md): D4 = force-
# rebuild/source-repair authority for QM5_11731; D5 = re-compile authority for
# QM5_41478. Both unlock factory chains once decided.
D4_DECISION_EA = "QM5_11731"
D5_DECISION_EA = "QM5_41478"

# Second-chance programme (OWNER-DEC-D3-20260915 §12): wave-1 commissioned EA.
SECOND_CHANCE_WAVE1_EA = "QM5_11563"

OPEN_BUCKETS = (
    "ACTIVE_NOW", "RUNNABLE_NOW", "RESOURCE_BLOCKED", "GOVERNANCE_BLOCKED",
    "DSR_CONTEXT_BLOCKED", "BUILD_IDENTITY_BLOCKED", "ARTIFACT_BINDING_BLOCKED",
    "COMPILE_OR_BUILD_BLOCKED", "REQUEUE_EXCLUDED", "DATA_OR_HISTORY_BLOCKED",
    "ANALYTIC_DECLARATION_ONLY", "SUPERSEDED_REPAIR", "STALE_OR_ORPHAN",
    "OTHER",
)
PARKED_BUCKETS = (
    "RECOVERABLE_WITHOUT_OWNER", "RECOVERABLE_WITH_EXISTING_AUTHORITY",
    "REQUIRES_NEW_OWNER_DECISION", "RESOURCE_BLOCKED", "INTENTIONALLY_INERT",
    "ECONOMICALLY_TERMINAL", "OTHER",
)

# Hold-code classes (shared by the open and parked classifiers). Order inside
# each map is irrelevant; precedence between classes is HOLD_CLASS_PRECEDENCE.
HOLD_CLASS_BY_CODE: dict[str, str] = {
    "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914": "RESOURCE_BLOCKED",
    "RAM_WINDOW_44GB": "RESOURCE_BLOCKED",
    "RAM_OUTLIER_4X_RESERVATION": "RESOURCE_BLOCKED",
    "Q08_DSR_CONTEXT_UNAVAILABLE": "DSR_CONTEXT_BLOCKED",
    "Q08_DSR_CONTEXT_UNAVAILABLE_20260915": "DSR_CONTEXT_BLOCKED",
    "Q08_DSR_CANDIDATE_WINDOW_UNAVAILABLE": "DSR_CONTEXT_BLOCKED",
    "SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD": "DSR_CONTEXT_BLOCKED",
    "Q02_DL089_SUPERSEDED_SETFILE_BINDING": "DSR_CONTEXT_BLOCKED",
    "COMPILE_GATE_BROKEN_SOURCE": "COMPILE_OR_BUILD_BLOCKED",
    "COMPILED_MAGIC_REGISTRY_STALE": "COMPILE_OR_BUILD_BLOCKED",
    "SOURCE_REPAIR_AUTHORITY_REQUIRED": "COMPILE_OR_BUILD_BLOCKED",
    "AWAITING_OWNER_RECOMPILE_DECISION": "COMPILE_OR_BUILD_BLOCKED",
    "REVIEW_FAIL_PIPELINE_ENTRY_BLOCKED": "GOVERNANCE_BLOCKED",
    "REVIEW_NOT_COMPLETED_PIPELINE_ENTRY_BLOCKED": "GOVERNANCE_BLOCKED",
    "MONITOR_BUDGET_REVIEW_REQUIRED": "GOVERNANCE_BLOCKED",
    "BALKE_PATTERN_REPAIR_REVIEW_PENDING": "GOVERNANCE_BLOCKED",
    "OWNER_D5_BASKET_LEASE_HOLD": "GOVERNANCE_BLOCKED",
    "EXCLUSIVE_LANE_DEFERRED_BOOK_SPRINT_20260914": "GOVERNANCE_BLOCKED",
    "FTMO_BOOK3_Q02_ISOLATED_ONLY": "GOVERNANCE_BLOCKED",
    "Q02_SPLIT_FIX_STAGED_BATCH": "GOVERNANCE_BLOCKED",
    "WITHHELD_FOREIGN_SYMBOL_SCOPE": "GOVERNANCE_BLOCKED",
    "CUSTOM_HISTORY_SYMBOL_NOT_IN_MANIFEST": "DATA_OR_HISTORY_BLOCKED",
    "NEWS_CALENDAR_TAINTED": "REQUIRES_NEW_OWNER_DECISION",  # parked mapping
    "PRESCREEN_SKIPPED": "INTENTIONALLY_INERT",              # parked mapping
    "COMPILE_EA_WORKER_ROLLOUT_PENDING": "RECOVERABLE_WITHOUT_OWNER",
    "NEWS_RUNNER_SPAWN_SILENT_ABORT": "RECOVERABLE_WITHOUT_OWNER",
    "Q09_AWAITING_SEALED_PLAN": "RECOVERABLE_WITHOUT_OWNER",
}
HOLD_CLASS_PRECEDENCE = (
    "RESOURCE_BLOCKED", "DSR_CONTEXT_BLOCKED", "ARTIFACT_BINDING_BLOCKED",
    "COMPILE_OR_BUILD_BLOCKED", "GOVERNANCE_BLOCKED", "DATA_OR_HISTORY_BLOCKED",
    "REQUIRES_NEW_OWNER_DECISION", "RECOVERABLE_WITHOUT_OWNER",
    "RECOVERABLE_WITH_EXISTING_AUTHORITY", "INTENTIONALLY_INERT",
    "ECONOMICALLY_TERMINAL", "OTHER",
)
ARTIFACT_BINDING_PREFIX = "ARTIFACT_BINDING"

# Q08 precheck reason token -> open bucket.
def _bucket_from_precheck_reason(reason: str) -> str:
    r = str(reason or "")
    if "BUILD_IDENTITY_MISMATCH" in r:
        return "BUILD_IDENTITY_BLOCKED"
    if "EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED" in r:
        return "GOVERNANCE_BLOCKED"
    return "DSR_CONTEXT_BLOCKED"


# ---------------------------------------------------------------------------
# time / db helpers
# ---------------------------------------------------------------------------
def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(t: dt.datetime) -> str:
    return t.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def _connect_ro(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA busy_timeout=5000")
    con.execute("PRAGMA query_only=ON")
    return con


def _json_loads(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(raw or "{}")
    except Exception:  # noqa: BLE001 — malformed payload -> {}, watchdog idiom
        return {}
    return value if isinstance(value, dict) else {}


# ---------------------------------------------------------------------------
# host RAM probe (monkeypatchable in tests)
# ---------------------------------------------------------------------------
class _MEMSTAT(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]


def host_memory_gb() -> tuple[float | None, float | None]:
    """(total_gb, free_gb) via GlobalMemoryStatusEx; (None, None) off-Windows."""
    try:
        stat = _MEMSTAT()
        stat.dwLength = ctypes.sizeof(stat)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            return None, None
        return stat.ullTotalPhys / 2**30, stat.ullAvailPhys / 2**30
    except Exception:  # noqa: BLE001 — probe, never crash the read-model
        return None, None


# ---------------------------------------------------------------------------
# measured runtime medians (tester memory ledger)
# ---------------------------------------------------------------------------
def load_runtime_medians_minutes(
    ledger_path: Path | None = None,
) -> dict[str, Any]:
    """Median finished-run minutes by phase and by (phase, symbol_class).

    Returns {"by_phase": {ph: minutes}, "by_phase_class": {"ph|cls": minutes},
    "samples": n, "degraded_reason": None|str}. Missing/unreadable ledger is
    explicit, never forged.
    """
    empty: dict[str, Any] = {"by_phase": {}, "by_phase_class": {},
                             "samples": 0, "degraded_reason": None}
    ledger_path = Path(ledger_path or TESTER_MEMORY_LEDGER)
    try:
        by_phase: dict[str, list[float]] = defaultdict(list)
        by_pc: dict[str, list[float]] = defaultdict(list)
        with Path(ledger_path).open(encoding="utf-8", errors="replace") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except Exception:  # noqa: BLE001
                    continue
                if str(rec.get("outcome")) != "finished":
                    continue
                try:
                    secs = float(rec.get("run_seconds"))
                except (TypeError, ValueError):
                    continue
                if not math.isfinite(secs) or secs <= 0 or secs > 7 * 24 * 3600:
                    continue
                ph = str(rec.get("phase") or "").strip().upper()
                cls = str(rec.get("symbol_class") or "").strip().lower()
                if not ph:
                    continue
                by_phase[ph].append(secs)
                if cls:
                    by_pc[f"{ph}|{cls}"].append(secs)
        if not by_phase:
            empty["degraded_reason"] = "ledger has no finished runs"
            return empty
        import statistics

        med = {
            "by_phase": {k: statistics.median(v) / 60.0
                         for k, v in by_phase.items() if v},
            "by_phase_class": {k: statistics.median(v) / 60.0
                               for k, v in by_pc.items() if v},
            "samples": sum(len(v) for v in by_phase.values()),
            "degraded_reason": None,
        }
        return med
    except OSError as exc:
        empty["degraded_reason"] = f"ledger unreadable: {exc}"
        return empty


COMPILE_ESTIMATE_MINUTES = 10.0  # compile takes seconds; conservative bound.


def runtime_minutes_for(phase: str, symbol_class: str | None,
                        medians: Mapping[str, Any]) -> float | None:
    ph = str(phase or "").upper()
    bp = medians.get("by_phase") or {}
    bpc = medians.get("by_phase_class") or {}
    if symbol_class:
        hit = bpc.get(f"{ph}|{str(symbol_class).lower()}")
        if hit:
            return float(hit)
    if ph == "COMPILE_EA":
        return COMPILE_ESTIMATE_MINUTES
    hit = bp.get(ph)
    return float(hit) if hit else None


# ---------------------------------------------------------------------------
# side inputs: Q12 receipt, venue books, second-chance register
# ---------------------------------------------------------------------------
def load_q12_receipt(path: Path | None = None) -> dict[str, str]:
    """work_item_id -> machine_reason from the 2026-09-16 all-106 dry pass."""
    path = Path(path or Q12_DRYRUN_RECEIPT)
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
        rows = data.get("deferred") or []
        out = {}
        for row in rows:
            wid = str(row.get("work_item_id") or "")
            reason = str(row.get("machine_reason") or "")
            if wid:
                out[wid] = reason
        return out
    except (OSError, ValueError, TypeError):
        return {}


def load_venue_eas(book_ftmo: Path | None = None,
                   book_dxz: Path | None = None) -> dict[str, set[str]]:
    """EA ids (QM5_<n>) with venue relevance from the live evolution books."""
    book_ftmo = Path(book_ftmo or BOOK_FTMO)
    book_dxz = Path(book_dxz or BOOK_DXZ)
    def _collect(path: Path) -> set[str]:
        found: set[str] = set()
        try:
            data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
        except (OSError, ValueError, TypeError):
            return found
        for section in ("incumbent", "challengers"):
            node = data.get(section)
            items = node.get("sleeves") if isinstance(node, dict) else node
            if not isinstance(items, list):
                continue
            for it in items:
                if not isinstance(it, dict):
                    continue
                try:
                    found.add(f"QM5_{int(it.get('ea_id'))}")
                except (TypeError, ValueError):
                    continue
        return found

    return {"FTMO": _collect(book_ftmo), "DXZ": _collect(book_dxz)}


def venue_for(ea_id: str, venues: Mapping[str, set[str]]) -> str:
    ea = str(ea_id or "")
    in_ftmo = ea in (venues.get("FTMO") or set())
    in_dxz = ea in (venues.get("DXZ") or set())
    if in_ftmo and in_dxz:
        return "FTMO+DXZ"
    if in_ftmo:
        return "FTMO"
    if in_dxz:
        return "DXZ"
    return "NONE"


def second_chance_eligible_count(path: Path = SECOND_CHANCE_REGISTER) -> int:
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, ValueError, TypeError):
        return 0
    records = data.get("records") or []
    return sum(
        1 for r in records
        if str(r.get("second_chance_status") or "") == "ELIGIBLE_FOR_RECONSIDERATION"
    )


# ---------------------------------------------------------------------------
# core population queries
# ---------------------------------------------------------------------------
MC_OPEN_SQL = (
    "SELECT id, ea_id, symbol, phase, status, kind, payload_json, verdict, "
    "created_at, updated_at FROM work_items WHERE status IN ('pending','active')"
)
# Mission Control's own population (mission_control_v2_data.build_queue) is the
# clean-view pending census; for pending rows the clean view passes status
# through unchanged, so the raw-table census above reproduces it exactly. The
# live run asserts equality against the clean view when available.


def fetch_population_rows(con: sqlite3.Connection) -> list[dict[str, Any]]:
    rows = []
    for r in con.execute(MC_OPEN_SQL):
        d = dict(r)
        d["phase_upper"] = str(d.get("phase") or "").strip().upper()
        d["payload"] = _json_loads(d.get("payload_json"))
        rows.append(d)
    return rows


def split_mc_populations(
    rows: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    # MC "Queue"/OPEN is the *pending* executable census; active rows are the
    # fleet's in-flight work (counted in ACTIVE_ECONOMIC_BACKTESTS, not in
    # OPEN_PIPELINE_ROWS).
    open_rows = [r for r in rows
                 if r["phase_upper"] in MT5_TESTER_PHASES
                 and str(r.get("status") or "").lower() == "pending"]
    parked_rows = [r for r in rows
                   if r["phase_upper"] not in MT5_TESTER_PHASES
                   and str(r.get("status") or "").lower() == "pending"]
    return open_rows, parked_rows


# ---------------------------------------------------------------------------
# claimability + RAM feasibility
# ---------------------------------------------------------------------------
def compute_selector_claimable(
    con: sqlite3.Connection,
) -> dict[str, Any]:
    """farmctl selector + Q08 DSR precheck (watchdog v2 semantics)."""
    try:
        import farmctl
    except Exception as exc:  # noqa: BLE001
        return {"selector_ids": set(), "selector_rows": None,
                "true_claimable_ids": set(), "precheck_excluded": None,
                "precheck_errors": None, "precheck_reasons": {},
                "degraded_reason": f"farmctl import failed: {exc}"}
    try:
        import dsr_cohort
    except Exception as exc:  # noqa: BLE001
        dsr_cohort = None  # type: ignore[assignment]
        dsr_err = f"dsr_cohort import failed: {exc}"

    rows = con.execute(farmctl.pending_claim_order_sql()).fetchall()
    selector_ids = {r["id"] for r in rows}
    precheck_reasons: dict[str, str] = {}
    excluded = 0
    errors = 0
    true_ids: set[str] = set()
    degraded = None
    for row in rows:
        payload = _json_loads(row["payload_json"])
        if str(row["phase"] or "").upper() == "Q08" and dsr_cohort is not None:
            try:
                pre = dsr_cohort.claimability_precheck(con, dict(row), payload)
                if pre.get("claimable") is False:
                    excluded += 1
                    precheck_reasons[row["id"]] = str(pre.get("reason") or "")
                    continue
            except Exception:  # noqa: BLE001 — watchdog fail-open: count it
                errors += 1
        true_ids.add(row["id"])
    if dsr_cohort is None:
        degraded = dsr_err
        true_ids = set(selector_ids)
    return {
        "selector_ids": selector_ids,
        "selector_rows": len(rows),
        "true_claimable_ids": true_ids,
        "precheck_excluded": excluded,
        "precheck_errors": errors,
        "precheck_reasons": precheck_reasons,
        "degraded_reason": degraded,
    }


def compute_ram_feasibility(
    rows: list[dict[str, Any]],
    *,
    free_ram_gb: float | None,
    tw_module: Any = None,
) -> dict[str, dict[str, Any]]:
    """Per-row {reservation_gb, floor_gb, feasible, ram_class, source}.

    Rows whose reservation cannot be resolved are marked feasible=None
    (unknown), never True/False-forged.
    """
    if tw_module is None:
        try:
            import terminal_worker as tw_module  # type: ignore[no-redef]
        except Exception:  # noqa: BLE001
            tw_module = None
    out: dict[str, dict[str, Any]] = {}
    if tw_module is None:
        for r in rows:
            out[r["id"]] = {"reservation_gb": None, "floor_gb": None,
                            "feasible": None, "ram_class": None,
                            "source": None,
                            "degraded_reason": "terminal_worker import failed"}
        return out
    if free_ram_gb is None:
        for r in rows:
            out[r["id"]] = {"reservation_gb": None, "floor_gb": None,
                            "feasible": None, "ram_class": None,
                            "source": None,
                            "degraded_reason": "host free RAM unavailable"}
        return out
    try:
        multisym_ids = tw_module._multisymbol_ea_ids()
    except Exception:  # noqa: BLE001 — registry down: reservations unknown
        multisym_ids = frozenset()
    for r in rows:
        try:
            multisymbol = tw_module._work_item_is_multisymbol(
                r, r["payload"], multisym_ids)
            ram_class, reservation_gb, source = \
                tw_module._ram_reservation_detail_for_candidate(
                    r, r["payload"], multisymbol)
            floor_gb = float(tw_module._ram_floor_for_class(ram_class))
            feasible = bool(free_ram_gb - float(reservation_gb) >= floor_gb)
            out[r["id"]] = {
                "reservation_gb": round(float(reservation_gb), 2),
                "floor_gb": floor_gb, "feasible": feasible,
                "ram_class": ram_class, "source": source,
                "degraded_reason": None,
            }
        except Exception as exc:  # noqa: BLE001
            out[r["id"]] = {"reservation_gb": None, "floor_gb": None,
                            "feasible": None, "ram_class": None,
                            "source": None,
                            "degraded_reason": f"reservation failed: {exc}"}
    return out


# ---------------------------------------------------------------------------
# hold / supersede / quarantine context
# ---------------------------------------------------------------------------
def load_row_context(con: sqlite3.Connection,
                     rows: list[dict[str, Any]]) -> dict[str, Any]:
    ids = [r["id"] for r in rows]
    ctx: dict[str, Any] = {"holds": defaultdict(list), "superseded": set(),
                           "quarantined": set()}
    if not ids:
        return ctx
    ph = ",".join("?" for _ in ids)
    for r in con.execute(
            f"SELECT work_item_id, hold_code FROM work_item_holds "
            f"WHERE active=1 AND work_item_id IN ({ph})", ids):
        ctx["holds"][r["work_item_id"]].append(str(r["hold_code"]))
    for r in con.execute(
            f"SELECT work_item_id FROM work_item_supersedes "
            f"WHERE work_item_id IN ({ph})", ids):
        ctx["superseded"].add(r["work_item_id"])
    for r in rows:
        if con.execute(
            "SELECT 1 FROM poison_pill_quarantine WHERE ea_id=? AND symbol=? "
            "AND (phase=? OR phase='*') AND active=1 LIMIT 1",
            (r.get("ea_id"), r.get("symbol"), r.get("phase")),
        ).fetchone():
            ctx["quarantined"].add(r["id"])
    return ctx


# ---------------------------------------------------------------------------
# classifiers
# ---------------------------------------------------------------------------
def classify_open_row(
    row: dict[str, Any],
    *,
    claimability: Mapping[str, Any],
    ram: Mapping[str, Any],
    ctx: Mapping[str, Any],
) -> tuple[str, str]:
    """Deterministic open-row classification -> (bucket, subcategory)."""
    rid = row["id"]
    if str(row.get("status") or "").lower() == "active":
        return "ACTIVE_NOW", "in_flight"
    selector_ids = claimability.get("selector_ids") or set()
    true_ids = claimability.get("true_claimable_ids") or set()
    if rid in selector_ids and rid in true_ids:
        # Claimable and precheck-clean. RAM decides runnable vs resource-held.
        ram_info = ram.get(rid) or {}
        if ram_info.get("feasible") is True:
            return "RUNNABLE_NOW", str(ram_info.get("ram_class") or "")
        if ram_info.get("feasible") is False:
            return "RESOURCE_BLOCKED", "ram_infeasible_now"
        return "RUNNABLE_NOW", "ram_not_evaluated"
    if rid in selector_ids and rid not in true_ids:
        reason = (claimability.get("precheck_reasons") or {}).get(rid, "")
        bucket = _bucket_from_precheck_reason(reason)
        if rid in BATCH2_BUILD_IDENTITY_IDS:
            return bucket, "d1_batch2_build_identity"
        return bucket, "precheck_" + (
            "build_identity" if bucket == "BUILD_IDENTITY_BLOCKED" else
            "governance" if bucket == "GOVERNANCE_BLOCKED" else "dsr_context")
    if rid in ctx["superseded"]:
        holds = ctx["holds"].get(rid) or []
        return "SUPERSEDED_REPAIR", "+".join(holds) if holds else "plain"
    if rid in ctx["quarantined"]:
        return "REQUEUE_EXCLUDED", "poison_pill_quarantine"
    holds = ctx["holds"].get(rid) or []
    if holds:
        classes = []
        for code in holds:
            if code.startswith(ARTIFACT_BINDING_PREFIX):
                classes.append("ARTIFACT_BINDING_BLOCKED")
            else:
                classes.append(HOLD_CLASS_BY_CODE.get(code, "OTHER"))
        for wanted in HOLD_CLASS_PRECEDENCE:
            if wanted in classes:
                subs = [c for c, cl in zip(holds, classes) if cl == wanted]
                return wanted, "+".join(sorted(subs))
        return "OTHER", "+".join(sorted(holds))
    return "OTHER", "selector_excluded_no_hold"


def _classify_q12_analytic(row: dict[str, Any],
                           receipt: Mapping[str, str],
                           ctx: Mapping[str, Any]) -> tuple[str, str]:
    rid = row["id"]
    if rid in ctx["superseded"]:
        return "INTENTIONALLY_INERT", "retired_superseded"
    reason = receipt.get(rid)
    if reason:
        if reason.startswith("PROGRAM_Q12_REBIND_REFUSED"):
            return "INTENTIONALLY_INERT", "duplicate_declaration_rebind_refused"
        if "expected one approved _opt sibling" in reason:
            prog = str(row["payload"].get("program_id") or "")
            if "10911" in prog:
                return "REQUIRES_NEW_OWNER_DECISION", "sibling_build_commission"
            if "11294" in prog:
                return "REQUIRES_NEW_OWNER_DECISION", "card_amend_add_gdaxi"
            if "20086" in prog:
                return "REQUIRES_NEW_OWNER_DECISION", "card_amend_add_ndx"
            return "REQUIRES_NEW_OWNER_DECISION", "sibling_scope_amendment"
        if "blocking hold:" in reason:
            code = reason.split("blocking hold:", 1)[1].strip()
            if code.startswith(ARTIFACT_BINDING_PREFIX):
                return "RECOVERABLE_WITH_EXISTING_AUTHORITY", \
                    "binding_repair_lane:" + code
            if code == "RAM_WINDOW_44GB":
                return "REQUIRES_NEW_OWNER_DECISION", "owner_verified_44gb_window"
            if code == "BALKE_PATTERN_REPAIR_REVIEW_PENDING":
                return "RECOVERABLE_WITH_EXISTING_AUTHORITY", \
                    "review_lane:" + code
            return "REQUIRES_NEW_OWNER_DECISION", "held:" + code
        return "REQUIRES_NEW_OWNER_DECISION", "matrix_service_unresolved"
    holds = ctx["holds"].get(rid) or []
    if holds:
        code = holds[0]
        if code.startswith(ARTIFACT_BINDING_PREFIX):
            return "RECOVERABLE_WITH_EXISTING_AUTHORITY", "binding_repair_lane"
        return "REQUIRES_NEW_OWNER_DECISION", "held:" + code
    return "REQUIRES_NEW_OWNER_DECISION", "analytic_declaration_unserviced"


def classify_parked_row(
    row: dict[str, Any],
    *,
    receipt: Mapping[str, str],
    ctx: Mapping[str, Any],
    claimability: Mapping[str, Any] | None = None,
) -> tuple[str, str]:
    payload = row["payload"]
    kind = str(row.get("kind") or "").lower()
    lane = str(payload.get("execution_lane") or "")
    governed_analytic = (
        kind == "analytic" and lane == "GOVERNED_ANALYTIC_DISPATCH"
    )
    if governed_analytic:
        return _classify_q12_analytic(row, receipt, ctx)
    if str(payload.get("diagnostic_non_admission") or "") in ("1", "true", "True") \
            or payload.get("diagnostic_non_admission") is True:
        return "INTENTIONALLY_INERT", "diagnostic_non_admission"
    if row["id"] in ctx["superseded"]:
        return "INTENTIONALLY_INERT", "retired_superseded"
    holds = ctx["holds"].get(row["id"]) or []
    if holds:
        classes = []
        for code in holds:
            if code.startswith(ARTIFACT_BINDING_PREFIX):
                classes.append("RECOVERABLE_WITH_EXISTING_AUTHORITY")
            elif code == "EXCLUSIVE_LANE_DEFERRED_BOOK_SPRINT_20260914":
                classes.append("RECOVERABLE_WITH_EXISTING_AUTHORITY")
            else:
                classes.append(HOLD_CLASS_BY_CODE.get(
                    code, "REQUIRES_NEW_OWNER_DECISION"))
        for wanted in HOLD_CLASS_PRECEDENCE:
            if wanted in classes:
                subs = [c for c, cl in zip(holds, classes) if cl == wanted]
                return wanted, "+".join(sorted(subs))
        return "REQUIRES_NEW_OWNER_DECISION", "+".join(sorted(holds))
    # Unheld and not superseded/quarantined/governed: if the canonical selector
    # already admits the row (e.g. freshly materialized OPT_CENSUS cells), no
    # repair or decision is missing at all — the row drains through the normal
    # claim path. It is "recoverable without OWNER" in the weakest sense: zero
    # action. The subcategory says so explicitly.
    if claimability is not None:
        selector_ids = claimability.get("selector_ids") or set()
        true_ids = claimability.get("true_claimable_ids") or set()
        if row["id"] in selector_ids and row["id"] in true_ids:
            return "RECOVERABLE_WITHOUT_OWNER", "claimable_now_no_repair_needed"
    return "REQUIRES_NEW_OWNER_DECISION", "unmapped_parked_row"


# ---------------------------------------------------------------------------
# classification passes
# ---------------------------------------------------------------------------
def classify_population(
    open_rows: list[dict[str, Any]],
    parked_rows: list[dict[str, Any]],
    *,
    claimability: Mapping[str, Any],
    ram: Mapping[str, Any],
    ctx: Mapping[str, Any],
    receipt: Mapping[str, str],
) -> dict[str, Any]:
    open_counts: Counter[str] = Counter()
    open_table: list[dict[str, Any]] = []
    for row in open_rows:
        bucket, sub = classify_open_row(
            row, claimability=claimability, ram=ram, ctx=ctx)
        open_counts[bucket] += 1
        open_table.append({
            "id": row["id"], "ea_id": row.get("ea_id"),
            "symbol": row.get("symbol"), "phase": row.get("phase"),
            "bucket": bucket, "subcategory": sub,
            "holds": ctx["holds"].get(row["id"]) or [],
            "reservation_gb": (ram.get(row["id"]) or {}).get("reservation_gb"),
            "created_at": row.get("created_at"),
        })
    parked_counts: Counter[str] = Counter()
    parked_table: list[dict[str, Any]] = []
    for row in parked_rows:
        bucket, sub = classify_parked_row(
            row, receipt=receipt, ctx=ctx, claimability=claimability)
        parked_counts[bucket] += 1
        parked_table.append({
            "id": row["id"], "ea_id": row.get("ea_id"),
            "symbol": row.get("symbol"), "phase": row.get("phase"),
            "bucket": bucket, "subcategory": sub,
            "holds": ctx["holds"].get(row["id"]) or [],
            "created_at": row.get("created_at"),
        })
    return {
        "open_counts": dict(open_counts),
        "open_rows": open_table,
        "parked_counts": dict(parked_counts),
        "parked_rows": parked_table,
    }


# ---------------------------------------------------------------------------
# report mapping (OWNER reconciliation tables)
# ---------------------------------------------------------------------------
def build_report_mapping(open_counts: Mapping[str, int],
                         parked_counts: Mapping[str, int],
                         active: int,
                         resource_feasible: int) -> dict[str, Any]:
    technical = sum(int(open_counts.get(b) or 0) for b in (
        "RESOURCE_BLOCKED", "DSR_CONTEXT_BLOCKED", "BUILD_IDENTITY_BLOCKED",
        "ARTIFACT_BINDING_BLOCKED", "COMPILE_OR_BUILD_BLOCKED",
        "DATA_OR_HISTORY_BLOCKED"))
    superseded_stale = sum(int(open_counts.get(b) or 0) for b in (
        "SUPERSEDED_REPAIR", "STALE_OR_ORPHAN", "REQUEUE_EXCLUDED"))
    runnable = int(open_counts.get("RUNNABLE_NOW") or 0)
    open_table = {
        "mission_control_open": sum(open_counts.values()),
        "active_mt5": active,
        "runnable_now": runnable,
        "resource_feasible": resource_feasible,
        "governance_blocked": int(open_counts.get("GOVERNANCE_BLOCKED") or 0),
        "technical_evidence_blocked": technical,
        "analytic_declaration_only": int(
            open_counts.get("ANALYTIC_DECLARATION_ONLY") or 0),
        "superseded_stale": superseded_stale,
        "other": int(open_counts.get("OTHER") or 0),
        "partition_total": (runnable + int(open_counts.get("GOVERNANCE_BLOCKED") or 0)
                            + technical + int(open_counts.get("ANALYTIC_DECLARATION_ONLY") or 0)
                            + superseded_stale + int(open_counts.get("OTHER") or 0)),
    }
    parked_table = {
        "recoverable_without_owner": int(
            parked_counts.get("RECOVERABLE_WITHOUT_OWNER") or 0),
        "recoverable_with_existing_authority": int(
            parked_counts.get("RECOVERABLE_WITH_EXISTING_AUTHORITY") or 0),
        "requires_new_owner_decision": int(
            parked_counts.get("REQUIRES_NEW_OWNER_DECISION") or 0),
        "resource_blocked": int(parked_counts.get("RESOURCE_BLOCKED") or 0),
        "intentionally_inert": int(parked_counts.get("INTENTIONALLY_INERT") or 0),
        "economically_terminal": int(
            parked_counts.get("ECONOMICALLY_TERMINAL") or 0),
        "other": int(parked_counts.get("OTHER") or 0),
        "partition_total": sum(parked_counts.values()),
    }
    return {"open_table": open_table, "parked_table": parked_table}


# ---------------------------------------------------------------------------
# recovery backlog + forecast
# ---------------------------------------------------------------------------
def _rows_for(classified: Mapping[str, Any], bucket: str | None = None,
              subcategory_prefix: str | None = None,
              phases: tuple[str, ...] | None = None,
              hold_codes: tuple[str, ...] | None = None) -> list[dict[str, Any]]:
    out = []
    for table_key in ("open_rows", "parked_rows"):
        for row in classified.get(table_key) or []:
            if bucket is not None and row["bucket"] != bucket:
                continue
            if subcategory_prefix is not None and not str(
                    row["subcategory"] or "").startswith(subcategory_prefix):
                continue
            if phases is not None and str(row["phase"]).upper() not in phases:
                continue
            if hold_codes is not None and not any(
                    h in (row["holds"] or []) for h in hold_codes):
                continue
            out.append(row)
    return out


def _gate_rank(phase: str) -> int:
    try:
        import farmctl
        return int(farmctl.phase_rank(str(phase or "").upper()))
    except Exception:  # noqa: BLE001
        return -1


def build_recoverable_backlog(
    classified: Mapping[str, Any],
    venues: Mapping[str, set[str]],
    medians: Mapping[str, Any],
) -> list[dict[str, Any]]:
    """Aggregate blocked cohorts into ranked recovery actions."""
    entries: list[dict[str, Any]] = []

    def _add(entry: dict[str, Any], rows: list[dict[str, Any]],
             hours: float | None) -> None:
        eas = sorted({str(r.get("ea_id") or "?") for r in rows})
        phases = sorted({str(r.get("phase") or "?") for r in rows})
        gates = [_gate_rank(p) for p in phases]
        gates = [g for g in gates if g >= 0]
        entry.setdefault("affected_rows", len(rows))
        entry.setdefault("affected_eas", len(eas))
        entry["highest_gate"] = max(phases, key=lambda p: _gate_rank(p)) \
            if phases else None
        entry["gate_rank_max"] = max(gates) if gates else -1
        venue_set: set[str] = set()
        for ea in eas:
            for token in venue_for(ea, venues).split("+"):
                if token and token != "NONE":
                    venue_set.add(token)
        entry["venue_relevance"] = "+".join(sorted(venue_set)) or "NONE"
        entry["expected_unlock_hours"] = round(hours, 2) \
            if isinstance(hours, (int, float)) else None
        entry["eas_sample"] = eas[:8]
        entries.append(entry)

    def _hours(rows: list[dict[str, Any]]) -> float | None:
        total = 0.0
        ok = True
        for r in rows:
            mins = runtime_minutes_for(
                str(r.get("phase") or ""), None, medians)
            if mins is None:
                ok = False
                continue
            total += mins
        return total / 60.0 if ok or total else (total / 60.0 if total else None)

    ram44 = _rows_for(
        classified, bucket="RESOURCE_BLOCKED",
        hold_codes=("RAM_RESERVATION_44GB_NOT_WINNABLE_20260914",
                    "RAM_WINDOW_44GB", "RAM_OUTLIER_4X_RESERVATION"))
    _add({
        "blocker_class": "ram_44gb_reservation_class",
        "repair_authority": "ticket 6cdc6811 (class calibration from measured "
                            "peaks) or host RAM upgrade; governed release-hold",
        "estimated_effort_class": "L",
        "status": "AUTHORIZED_PENDING_EXECUTION",
        "expected_runnable_rows_unlocked": len(ram44),
    }, ram44, _hours(ram44))

    precheck_rows = _rows_for(
        classified,
        subcategory_prefix="precheck_",
    ) + _rows_for(classified, subcategory_prefix="d1_batch2")
    bi = [r for r in precheck_rows if r["bucket"] == "BUILD_IDENTITY_BLOCKED"]
    gov = [r for r in precheck_rows if r["bucket"] == "GOVERNANCE_BLOCKED"]
    dsr = [r for r in precheck_rows if r["bucket"] == "DSR_CONTEXT_BLOCKED"]
    _add({
        "blocker_class": "q08_staged_build_identity",
        "repair_authority": "OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916 repair "
                            "pattern (supersede + fresh enqueue with current "
                            "build binding)",
        "estimated_effort_class": "S",
        "status": "AUTHORIZED_PENDING_EXECUTION",
        "expected_runnable_rows_unlocked": len(bi),
    }, bi, _hours(bi))
    _add({
        "blocker_class": "q08_card_declaration_amendment",
        "repair_authority": "card amendment under the V3 single-configuration "
                            "pattern; per-card OWNER approval",
        "estimated_effort_class": "M",
        "status": "REQUIRES_NEW_OWNER_DECISION",
        "expected_runnable_rows_unlocked": len(gov),
    }, gov, _hours(gov))
    _add({
        "blocker_class": "q08_dsr_candidate_mismatch",
        "repair_authority": "DSR context investigation (staged candidate vs "
                            "declared configuration)",
        "estimated_effort_class": "M",
        "status": "REQUIRES_NEW_OWNER_DECISION",
        "expected_runnable_rows_unlocked": len(dsr),
    }, dsr, _hours(dsr))

    dsr_ctx = _rows_for(classified, bucket="DSR_CONTEXT_BLOCKED")
    dsr_ctx = [r for r in dsr_ctx if not str(r["subcategory"]).startswith("precheck")]
    _add({
        "blocker_class": "q08_dsr_context_cohort",
        "repair_authority": "OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916 "
                            "(16-card cohort; staged rows with amended cards)",
        "estimated_effort_class": "M",
        "status": "AUTHORIZED_PENDING_EXECUTION",
        "expected_runnable_rows_unlocked": len(dsr_ctx),
    }, dsr_ctx, _hours(dsr_ctx))

    binding = _rows_for(classified, bucket="ARTIFACT_BINDING_BLOCKED")
    _add({
        "blocker_class": "artifact_binding_drift",
        "repair_authority": "governed artifact-binding repair lane "
                            "(rebind/drift receipts 2026-09-12/13)",
        "estimated_effort_class": "M",
        "status": "AUTHORIZED_PENDING_EXECUTION",
        "expected_runnable_rows_unlocked": len(binding),
    }, binding, _hours(binding))

    news_tainted = _rows_for(
        classified, bucket="REQUIRES_NEW_OWNER_DECISION",
        subcategory_prefix="NEWS_CALENDAR_TAINTED") + _rows_for(
        classified, hold_codes=("NEWS_CALENDAR_TAINTED",))
    seen_nt = set()
    news_tainted = [
        r for r in news_tainted
        if "NEWS" in str(r["phase"]) and not (r["id"] in seen_nt
                                              or seen_nt.add(r["id"]))
    ]
    _add({
        "blocker_class": "news_calendar_taint",
        "repair_authority": "OWNER E1-C decision (Q09 manifest repin vs "
                            "remeasurement) + news-calendar registry patch",
        "estimated_effort_class": "M",
        "status": "REQUIRES_NEW_OWNER_DECISION",
        "expected_runnable_rows_unlocked": len(news_tainted),
    }, news_tainted, _hours(news_tainted))

    siblings = _rows_for(
        classified, bucket="REQUIRES_NEW_OWNER_DECISION",
        subcategory_prefix="sibling_") + _rows_for(
        classified, bucket="REQUIRES_NEW_OWNER_DECISION",
        subcategory_prefix="card_amend")
    _add({
        "blocker_class": "q12_frontier_sibling_programs",
        "repair_authority": "sibling build commission (QM5_10911) / sealed "
                            "card target-symbol amendments (QM5_11294 +GDAXI, "
                            "QM5_20086 +NDX); then service-dl089-matrix --apply",
        "estimated_effort_class": "L",
        "status": "REQUIRES_NEW_OWNER_DECISION",
        "expected_runnable_rows_unlocked": len(siblings),
    }, siblings, None)

    dupes = _rows_for(classified, subcategory_prefix="duplicate_declaration")
    _add({
        "blocker_class": "q12_duplicate_declarations",
        "repair_authority": "bulk supersede disposition (governance question, "
                            "2026-09-16 Q12 disposition recommendation 3)",
        "estimated_effort_class": "S",
        "status": "REQUIRES_NEW_OWNER_DECISION",
        "expected_runnable_rows_unlocked": 0,
    }, dupes, 0.0)

    compile_rollout = _rows_for(
        classified, bucket="RECOVERABLE_WITHOUT_OWNER",
        subcategory_prefix="COMPILE_EA_WORKER_ROLLOUT_PENDING")
    _add({
        "blocker_class": "compile_worker_rollout",
        "repair_authority": "setup-only: reviewed COMPILE_EA worker rollout "
                            "(release rollout holds)",
        "estimated_effort_class": "S",
        "status": "SETUP_ONLY",
        "expected_runnable_rows_unlocked": len(compile_rollout),
    }, compile_rollout, _hours(compile_rollout))

    spawn = _rows_for(
        classified, bucket="RECOVERABLE_WITHOUT_OWNER",
        subcategory_prefix="NEWS_RUNNER_SPAWN_SILENT_ABORT")
    _add({
        "blocker_class": "news_runner_spawn_silent_abort",
        "repair_authority": "deterministic infra repair of the news runner "
                            "spawn path",
        "estimated_effort_class": "M",
        "status": "RECOVERABLE_WITHOUT_OWNER",
        "expected_runnable_rows_unlocked": len(spawn),
    }, spawn, _hours(spawn))

    sealed = _rows_for(
        classified, bucket="RECOVERABLE_WITHOUT_OWNER",
        subcategory_prefix="Q09_AWAITING_SEALED_PLAN")
    _add({
        "blocker_class": "q09_sealed_plan_derivation",
        "repair_authority": "deterministic q09 autoseal/lineage derivation fix "
                            "(fail-closed)",
        "estimated_effort_class": "M",
        "status": "RECOVERABLE_WITHOUT_OWNER",
        "expected_runnable_rows_unlocked": len(sealed),
    }, sealed, _hours(sealed))

    decision_rows = []
    blocked_buckets = {
        "RESOURCE_BLOCKED", "GOVERNANCE_BLOCKED", "DSR_CONTEXT_BLOCKED",
        "BUILD_IDENTITY_BLOCKED", "ARTIFACT_BINDING_BLOCKED",
        "COMPILE_OR_BUILD_BLOCKED", "DATA_OR_HISTORY_BLOCKED",
        "REQUEUE_EXCLUDED", "SUPERSEDED_REPAIR",
        "REQUIRES_NEW_OWNER_DECISION", "RECOVERABLE_WITH_EXISTING_AUTHORITY",
    }
    for ea, tag in ((D4_DECISION_EA, "d4_force_rebuild_qm5_11731"),
                    (D5_DECISION_EA, "d5_recompile_qm5_41478")):
        # Only rows still in a blocked bucket count: once the decision has
        # executed (compiled/Q02 passed/census materialized), the unlocked
        # rows leave the blocked set and the entry reports DECISION_EXECUTED.
        hits = [r for r in classified.get("open_rows", [])
                + classified.get("parked_rows", [])
                if str(r.get("ea_id")) == ea
                and str(r.get("bucket")) in blocked_buckets]
        status = ("REQUIRES_NEW_OWNER_DECISION" if hits
                  else "DECISION_EXECUTED")
        _add({
            "blocker_class": tag,
            "repair_authority": "queued OWNER decision (KIMI_INTERIM_HANDOFF_"
                                "2026-09-18)",
            "estimated_effort_class": "S",
            "status": status,
            "expected_runnable_rows_unlocked": len(hits),
        }, hits, _hours(hits) if hits else 0.0)

    sc_row = [{
        "id": "second_chance_wave1", "ea_id": SECOND_CHANCE_WAVE1_EA,
        "phase": "Q02", "holds": [],
    }]
    _add({
        "blocker_class": "second_chance_wave1",
        "repair_authority": "OWNER-DEC-D3-20260915 §12 second-chance "
                            "programme; reviews land 09-19",
        "estimated_effort_class": "M",
        "status": "AUTHORIZED_PENDING_EXECUTION",
        "expected_runnable_rows_unlocked": 1,
    }, sc_row, _hours(sc_row))

    # Economic priority rank: score = unlock_hours * venue weight *
    # authorization factor; desc. Decision-gated items keep their (0.25)
    # factor so genuinely large unlocks still surface high.
    def _weight(entry: dict[str, Any]) -> float:
        venue = str(entry.get("venue_relevance") or "NONE")
        vw = 1.0 if "FTMO" in venue else (0.8 if "DXZ" in venue else 0.5)
        af = {"AUTHORIZED_PENDING_EXECUTION": 1.0,
              "SETUP_ONLY": 1.0,
              "RECOVERABLE_WITHOUT_OWNER": 0.9}.get(
            str(entry.get("status")), 0.25)
        return vw * af

    scored = []
    for entry in entries:
        hours = entry.get("expected_unlock_hours")
        hours = float(hours) if isinstance(hours, (int, float)) else 0.0
        score = hours * _weight(entry)
        scored.append((score, entry))
    scored.sort(key=lambda se: (-se[0], -int(se[1].get("affected_rows") or 0),
                                str(se[1].get("blocker_class"))))
    for rank, (_, entry) in enumerate(scored, start=1):
        entry["economic_priority_rank"] = rank
        entry.pop("gate_rank_max", None)
    return [entry for _, entry in scored]


def build_forecast(
    classified: Mapping[str, Any],
    backlog: list[dict[str, Any]],
    medians: Mapping[str, Any],
    runnable_feasible_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    runnable_hours = 0.0
    runnable_missing = 0
    for row in runnable_feasible_rows:
        mins = runtime_minutes_for(str(row.get("phase") or ""), None, medians)
        if mins is None:
            runnable_missing += 1
            continue
        runnable_hours += mins / 60.0

    unlock_total = 0.0
    components: dict[str, Any] = {}
    for entry in backlog:
        hours = entry.get("expected_unlock_hours")
        if not isinstance(hours, (int, float)):
            continue
        if str(entry.get("status")) not in (
                "AUTHORIZED_PENDING_EXECUTION", "SETUP_ONLY",
                "RECOVERABLE_WITHOUT_OWNER"):
            continue
        components[entry["blocker_class"]] = round(float(hours), 2)
        unlock_total += float(hours)

    forecast = round(runnable_hours + unlock_total, 2)
    return {
        "runtime_basis": {
            "source": "tester_memory_ledger run_seconds medians (finished "
                      "runs), phase-level; COMPILE_EA fixed estimate "
                      f"{COMPILE_ESTIMATE_MINUTES:.0f} min",
            "samples": medians.get("samples"),
            "medians_minutes_by_phase": {
                k: round(v, 2) for k, v in sorted(
                    (medians.get("by_phase") or {}).items())
            },
            "degraded_reason": medians.get("degraded_reason"),
        },
        "runnable_now_missing_runtime_rows": runnable_missing,
        "RUNNABLE_NOW_HOURS": round(runnable_hours, 2),
        "EXPECTED_UNLOCK_HOURS": {"total": round(unlock_total, 2),
                                  "components": components},
        "FORECAST_RUNNABLE_HOURS": forecast,
        "buffer_threshold_hours": 2.0,
    }


# ---------------------------------------------------------------------------
# health
# ---------------------------------------------------------------------------
HEALTH_RUNNING = "RUNNING"
HEALTH_BUFFER_LOW = "BUFFER_LOW"
HEALTH_IDLE_WITH_WORK = "IDLE_WITH_RUNNABLE_WORK"
HEALTH_IDLE_RED = "IDLE_RED"
HEALTH_NO_RUNNABLE_WORK = "NO_RUNNABLE_WORK"
HEALTH_IDLE_RESOURCE_GATED = "IDLE_RESOURCE_GATED"
HEALTH_UNKNOWN = "UNKNOWN"


def classify_health(
    *,
    active: Any,
    resource_feasible: Any,
    forecast_hours: Any,
    recoverable_high_value_rows: Any,
    blocked_by: list[dict[str, Any]],
    previous: dict[str, Any] | None,
) -> dict[str, Any]:
    prev_health = (previous or {}).get("health") or {}
    prev_classification = prev_health.get("classification")
    prev_streak = int(
        prev_health.get("consecutive_idle_resource_feasible_runs") or 0)

    out: dict[str, Any] = {
        "previous_classification": prev_classification,
        "previous_generated_at_utc": (previous or {}).get("generated_at_utc"),
    }
    if not isinstance(active, int) or not isinstance(resource_feasible, int):
        out.update({
            "classification": HEALTH_UNKNOWN,
            "consecutive_idle_resource_feasible_runs": 0,
            "FACTORY_BUFFER_LOW": "UNKNOWN",
            "FACTORY_IDLE_WITH_RUNNABLE_WORK": "UNKNOWN",
            "blocked_by": blocked_by,
            "degraded_reason": "numbers not evaluable",
        })
        return out

    buffer_low = (
        isinstance(forecast_hours, (int, float))
        and forecast_hours < 2.0
        and isinstance(recoverable_high_value_rows, int)
        and recoverable_high_value_rows > 0
    )
    idle_red_now = active == 0 and resource_feasible > 0
    streak = prev_streak + 1 if idle_red_now and prev_classification in (
        HEALTH_IDLE_WITH_WORK, HEALTH_IDLE_RED) else (1 if idle_red_now else 0)
    idle_flag = "RED" if (idle_red_now and streak >= 2) else "GREEN"

    if active > 0:
        classification = HEALTH_RUNNING
    elif resource_feasible > 0:
        classification = HEALTH_IDLE_RED if streak >= 2 else HEALTH_IDLE_WITH_WORK
    elif isinstance(recoverable_high_value_rows, int) \
            and recoverable_high_value_rows > 0:
        classification = (HEALTH_BUFFER_LOW if buffer_low
                          else HEALTH_IDLE_RESOURCE_GATED)
    else:
        classification = HEALTH_NO_RUNNABLE_WORK

    out.update({
        "classification": classification,
        "consecutive_idle_resource_feasible_runs": streak,
        "FACTORY_BUFFER_LOW": "AMBER" if buffer_low else "GREEN",
        "FACTORY_IDLE_WITH_RUNNABLE_WORK": idle_flag,
        "blocked_by": blocked_by if classification in (
            HEALTH_IDLE_RESOURCE_GATED, HEALTH_BUFFER_LOW,
            HEALTH_NO_RUNNABLE_WORK) else [],
        "degraded_reason": None,
    })
    return out


# ---------------------------------------------------------------------------
# assembly
# ---------------------------------------------------------------------------
def load_previous(path: Path | None = None) -> dict[str, Any] | None:
    path = Path(path or OUTPUT_PATH)
    try:
        doc = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    return doc if isinstance(doc, dict) else None


def build_document(
    con: sqlite3.Connection,
    *,
    now: dt.datetime,
    previous: dict[str, Any] | None = None,
    free_ram_gb: float | None = None,
    host_total_gb: float | None = None,
    tw_module: Any = None,
) -> dict[str, Any]:
    degraded: list[str] = []
    if free_ram_gb is None:
        host_total_gb, free_ram_gb = host_memory_gb()
    if free_ram_gb is None:
        degraded.append("host free RAM unavailable -> RAM feasibility "
                        "NOT_EVALUATED")

    rows = fetch_population_rows(con)
    open_rows, parked_rows = split_mc_populations(rows)
    claimability = compute_selector_claimable(con)
    if claimability.get("degraded_reason"):
        degraded.append(str(claimability["degraded_reason"]))
    ctx = load_row_context(con, rows)

    # RAM feasibility is evaluated for every pending row (both populations),
    # so RESOURCE_BLOCKED rows carry their measured reservation.
    ram = compute_ram_feasibility(
        rows, free_ram_gb=free_ram_gb, tw_module=tw_module)
    ram_degraded = sorted({
        str(info.get("degraded_reason"))
        for info in ram.values() if info.get("degraded_reason")
    })
    degraded.extend(ram_degraded)

    receipt = load_q12_receipt()
    if not receipt:
        degraded.append("q12 dry-run receipt unavailable -> Q12 rows "
                        "classified from holds only")
    medians = load_runtime_medians_minutes()
    if medians.get("degraded_reason"):
        degraded.append(str(medians["degraded_reason"]))
    venues = load_venue_eas()

    classified = classify_population(
        open_rows, parked_rows,
        claimability=claimability, ram=ram, ctx=ctx, receipt=receipt)

    active = sum(1 for r in rows if str(r.get("status")).lower() == "active")
    true_claimable = len(claimability.get("true_claimable_ids") or set())
    runnable_rows = [r for r in classified["open_rows"]
                     if r["bucket"] == "RUNNABLE_NOW"]
    resource_feasible = len(runnable_rows)

    four_counts = {
        "OPEN_PIPELINE_ROWS": len(open_rows),
        "SELECTOR_CLAIMABLE_ROWS": claimability.get("selector_rows"),
        "TRUE_CLAIMABLE_WORK": true_claimable,
        "RESOURCE_FEASIBLE_RUNNABLE_WORK": resource_feasible,
        "ACTIVE_ECONOMIC_BACKTESTS": active,
    }

    # What gates the idle factory (named blockers, not a vague "blocked").
    blocked_by: list[dict[str, Any]] = []
    ram_infeasible_runnable = [
        r for r in classified["open_rows"]
        if r["bucket"] == "RESOURCE_BLOCKED"
        and r["subcategory"] == "ram_infeasible_now"
    ]
    for r in ram_infeasible_runnable:
        info = ram.get(r["id"]) or {}
        blocked_by.append({
            "blocker": "ram_infeasible_now",
            "rows": 1, "phase": r["phase"], "ea_id": r["ea_id"],
            "reservation_gb": info.get("reservation_gb"),
            "free_ram_gb": round(float(free_ram_gb), 1)
            if free_ram_gb is not None else None,
        })
    ram44 = [r for r in classified["open_rows"] + classified["parked_rows"]
             if r["bucket"] == "RESOURCE_BLOCKED"
             and any("RAM_" in h for h in (r["holds"] or []))]
    if ram44:
        blocked_by.append({
            "blocker": "ram_44gb_class_parked",
            "rows": len(ram44),
            "authority": "ticket 6cdc6811 or RAM upgrade",
        })

    backlog = build_recoverable_backlog(classified, venues, medians)
    forecast = build_forecast(classified, backlog, medians, runnable_rows)
    recoverable_high_value = sum(
        int(classified["parked_counts"].get(b) or 0)
        for b in ("RECOVERABLE_WITHOUT_OWNER",
                  "RECOVERABLE_WITH_EXISTING_AUTHORITY")) + len(ram44)
    health = classify_health(
        active=active,
        resource_feasible=resource_feasible,
        forecast_hours=forecast["FORECAST_RUNNABLE_HOURS"],
        recoverable_high_value_rows=recoverable_high_value,
        blocked_by=blocked_by,
        previous=previous,
    )

    mapping = build_report_mapping(
        classified["open_counts"], classified["parked_counts"],
        active, resource_feasible)

    # MC cross-check against the render data contract when available.
    mc_computation = {
        "open_query": "work_items_clean c LEFT JOIN work_items w ON w.id=c.id "
                      "WHERE c.status='pending', phase in MT5_TESTER_PHASES "
                      "(mission_control_v2_data.build_queue, lines ~784-816)",
        "parked_query": "same census, phases outside MT5_TESTER_PHASES",
        "render_paths": [
            "tools/strategy_farm/mission_control_v2_data.py:build_queue",
            "tools/strategy_farm/render_cockpit_v2.py:queue_breakdown",
            "tools/strategy_farm/render_cockpit_v2.py:_render_control_strip "
            "(Queue cell: main=pending_executable, sub='+<pending_parked> "
            "parked · <active> active')",
        ],
        "owner_observed_display": {"open": 981, "parked": 2011,
                                   "as_of": "OWNER observation ~2026-09-16"},
        "freshness_note": None,
    }

    doc = {
        "schema": SCHEMA_VERSION,
        "generated_at_utc": _iso(now),
        "sources": {
            "db": str(DB),
            "tester_memory_ledger": str(TESTER_MEMORY_LEDGER),
            "q12_dryrun_receipt": str(Q12_DRYRUN_RECEIPT),
            "second_chance_register": str(SECOND_CHANCE_REGISTER),
            "claimable_semantics": "farmctl.pending_claim_order_sql() + "
                                   "dsr_cohort.claimability_precheck (Q08), "
                                   "mirroring factory_watchdog.ps1 v2",
            "ram_semantics": "terminal_worker._ram_reservation_detail_"
                             "for_candidate (max(flat, measured, phase "
                             "floor)) + _ram_floor_for_class vs free RAM",
        },
        "mission_control": {
            "open_pipeline_rows": len(open_rows),
            "parked_rows": len(parked_rows),
            "pending_total": len(rows),
            "active": active,
            "computation": mc_computation,
        },
        "four_counts": four_counts,
        "resource_snapshot": {
            "host_total_ram_gb": round(host_total_gb, 1)
            if host_total_gb is not None else None,
            "host_free_ram_gb": round(free_ram_gb, 1)
            if free_ram_gb is not None else None,
            "gate": "free_ram - reservation >= class_floor",
            "reservations_measured": not ram_degraded,
        },
        "classification": {
            "open": {
                "total_rows": len(open_rows),
                "buckets": {b: int(classified["open_counts"].get(b) or 0)
                            for b in OPEN_BUCKETS},
                "rows": classified["open_rows"],
            },
            "parked": {
                "total_rows": len(parked_rows),
                "buckets": {b: int(classified["parked_counts"].get(b) or 0)
                            for b in PARKED_BUCKETS},
                "rows": classified["parked_rows"],
            },
        },
        "parked_split": {b: int(classified["parked_counts"].get(b) or 0)
                         for b in PARKED_BUCKETS},
        "recoverable_backlog": backlog,
        "forecast": forecast,
        "recoverable_high_value_rows": recoverable_high_value,
        "second_chance_register_eligible": second_chance_eligible_count(),
        "health": health,
        "report_mapping": mapping,
        "degraded_reasons": degraded,
    }
    # Freshness explanation vs the OWNER-observed parked figure.
    obs_open = mc_computation["owner_observed_display"]["open"]
    obs_parked = mc_computation["owner_observed_display"]["parked"]
    deltas = []
    if obs_open != len(open_rows):
        deltas.append(f"open {obs_open} -> {len(open_rows)}")
    if obs_parked != len(parked_rows):
        deltas.append(f"parked {obs_parked} -> {len(parked_rows)}")
    mc_computation["freshness_note"] = (
        "Live computation at generated_at_utc; the parked census is dominated "
        "by the OPT_CENSUS PRESCREEN_SKIPPED cohort (created 2026-08-22.."
        "09-03) and churns with claims/dispositions. Delta vs the "
        "OWNER-observed display: " + (", ".join(deltas) if deltas else "none")
        + "."
    )
    return doc


# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
def write_text_atomic(path: Path, rendered: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(rendered, encoding="utf-8", newline="\n")
    os.replace(temp, path)


def _legacy_three_numbers_document(
    con: sqlite3.Connection, now: dt.datetime
) -> dict[str, Any]:
    """Byte-shape compatible qm.factory-three-numbers/v1 from the same pass."""
    from tools.strategy_farm import factory_three_numbers as tn

    try:
        previous_legacy = tn.load_previous(LEGACY_OUTPUT_PATH)
    except Exception:  # noqa: BLE001
        previous_legacy = None
    return tn.build_document(con, now=now, previous=previous_legacy)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DB,
                        help="override farm_state.sqlite path")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH,
                        help="factory_population.json output path")
    parser.add_argument("--legacy-output", type=Path,
                        default=LEGACY_OUTPUT_PATH,
                        help="factory_three_numbers.json output path (kept "
                             "for existing consumers)")
    parser.add_argument("--stdout", action="store_true",
                        help="also print the read-model to stdout")
    args = parser.parse_args(argv)

    now = _now_utc()
    previous = load_previous(args.output)
    con = _connect_ro(args.db)
    try:
        doc = build_document(con, now=now, previous=previous)
        legacy = _legacy_three_numbers_document(con, now)
    finally:
        con.close()

    rendered = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    write_text_atomic(args.output, rendered)
    write_text_atomic(
        args.legacy_output,
        json.dumps(legacy, indent=2, ensure_ascii=False) + "\n")
    if args.stdout:
        sys.stdout.write(rendered)

    n = doc["four_counts"]
    _err = sys.stderr if sys.stderr is not None else open(
        os.devnull, "w", encoding="utf-8")
    _err.write(
        f"[factory_population] open={n['OPEN_PIPELINE_ROWS']} "
        f"claimable={n['TRUE_CLAIMABLE_WORK']} "
        f"resource_feasible={n['RESOURCE_FEASIBLE_RUNNABLE_WORK']} "
        f"active={n['ACTIVE_ECONOMIC_BACKTESTS']} "
        f"parked={doc['mission_control']['parked_rows']} "
        f"forecast_h={doc['forecast']['FORECAST_RUNNABLE_HOURS']} "
        f"health={doc['health'].get('classification')} -> {args.output}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
