"""Build pipeline_state.json — single source of truth for EA pipeline state.

Per-EA pipeline state (per_ea, by_status, and the automated-gate slice of
by_phase) is derived READ-ONLY from the Strategy Farm work_items DB
(D:/QM/strategy_farm/state/farm_state.sqlite) — the authoritative record of
gate verdicts. Environment/summary fields (MT5 saturation, sub-agent watchdog,
dispatcher stats, registry/card counts) still come from their respective disk
artifacts (last_check_state.json, watchdog latest.json, dispatch_state.json,
ea_id_registry.csv, strategy cards). Produces an atomic
D:/QM/reports/state/pipeline_state.json that downstream consumers
(public snapshot exporter, daily summary) read.

FB-05 fix (audit docs/ops/source_harvest/audit): per_ea previously came from
D:/QM/reports/pipeline/*/*_result.json filesystem artifacts, which no longer
track live gate outcomes — every EA showed NOT_RUN while the DB held ~23k PASS
verdicts. The old filesystem path is retained ONLY as a resilience fallback for
the (rare) case where the DB cannot be opened; the top-level "per_ea_source"
field records which path produced the per-EA block ("work_items" vs
"filesystem_fallback").

Design:
- Primary derivation from work_items (read-only URI, mode=ro — never written).
- Atomic temp-then-rename write.
- Idempotent: identical inputs → identical output bytes (except generated_at).

Usage:
    python build_pipeline_state.py                  # write state file
    python build_pipeline_state.py --dry-run        # print JSON to stdout, no write
    python build_pipeline_state.py --verbose        # log per-EA decisions
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(r"C:/QM/repo")
PIPELINE_ROOT = Path(r"D:/QM/reports/pipeline")
STATE_DIR = Path(r"D:/QM/reports/state")
STATE_FILE = STATE_DIR / "pipeline_state.json"
LAST_CHECK_FILE = STATE_DIR / "last_check_state.json"
WATCHDOG_LATEST = REPO_ROOT / "docs" / "ops" / "pipeline_health" / "latest.json"
DISPATCH_STATE = PIPELINE_ROOT / "dispatch_state.json"
EA_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
STRATEGY_CARDS_DIR = REPO_ROOT / "strategy-seeds" / "cards"
STRATEGY_SPECS_DIR = REPO_ROOT / "strategy-seeds" / "specs"
FARM_ROOT = Path(r"D:/QM/strategy_farm")
FARM_CARDS_DIRS = [
    FARM_ROOT / "artifacts" / "cards_approved",
    FARM_ROOT / "artifacts" / "cards_draft",
]
FARM_DB = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")

# V5 phase order (from PIPELINE_PHASE_SPEC.md). P3.5 is stored as P3_5 in JSON keys
# to satisfy the public-snapshot schema.
PHASES = ["G0", "P1", "P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8", "P9", "P9b", "P10"]
PHASE_TO_KEY = {p: p.replace(".", "_") for p in PHASES}
MANUAL_GATES = {"G0", "P9", "P9b", "P10"}
ADVANCED_PHASE_RESULT_MIN_UTC = datetime(2026, 5, 15, tzinfo=timezone.utc)
ADVANCED_PHASES = {"P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8"}


def read_json_safe(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return None


def count_strategy_cards() -> int:
    slugs: set[str] = set()
    for directory in [STRATEGY_SPECS_DIR, STRATEGY_CARDS_DIR, *FARM_CARDS_DIRS]:
        if directory.is_dir():
            slugs.update(p.stem for p in directory.iterdir() if p.is_file() and p.suffix.lower() == ".md")
    return len(slugs)


def read_ea_registry() -> list[dict]:
    if not EA_REGISTRY.is_file():
        return []
    rows = []
    with EA_REGISTRY.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            rows.append(row)
    return rows


def find_phase_result(ea_dir: Path, phase: str) -> dict | None:
    """Locate the canonical phase result JSON for an EA.

    Naming conventions observed:
      - P2:  <ea_dir>/P2/p2_<EA>_result.json
      - Pn:  <ea_dir>/P<n>/P<n>_<EA>_result.json
      - P3.5: <ea_dir>/P3.5/P3_5_<EA>_result.json
        Legacy <ea_dir>/P3_5 is still accepted while old artifacts age out.
    """
    phase_key = PHASE_TO_KEY[phase]
    phase_dir = ea_dir / phase
    if not phase_dir.is_dir():
        phase_dir = ea_dir / phase_key  # legacy P3_5 fallback / schema-safe names
    if not phase_dir.is_dir():
        return None
    ea_name = ea_dir.name
    candidates = [
        phase_dir / f"{phase_key}_{ea_name}_result.json",
        phase_dir / f"p{phase_key[1:].lower()}_{ea_name}_result.json",
        phase_dir / f"p2_{ea_name}_result.json" if phase == "P2" else None,
    ]
    for c in candidates:
        if c and c.is_file():
            data = read_json_safe(c)
            if data:
                return data
    return None


def extract_verdict(result: dict) -> str:
    """Normalize phase verdict from the result JSON to one of:
    PASS, FAIL, REVIEW_REQUIRED, BLOCKED, INVALID, DRY, UNKNOWN.
    """
    if not result:
        return "UNKNOWN"
    v = (result.get("verdict") or "").upper().strip()
    if v in {"PASS", "FAIL", "REVIEW_REQUIRED", "BLOCKED", "INVALID", "MODE_SELECTED",
             "AUTO_PASS", "NEEDS_RERUN", "MULTI_SEED_PASS", "MULTI_SEED_MIXED", "MULTI_SEED_FAIL"}:
        # Treat MODE_SELECTED + AUTO_PASS + MULTI_SEED_PASS as PASS for progression counting
        if v in {"MODE_SELECTED", "AUTO_PASS", "MULTI_SEED_PASS", "MULTI_SEED_MIXED"}:
            return "PASS"
        return v
    counts = result.get("counts")
    if isinstance(counts, dict):
        if counts.get("PASS", 0) > 0 and counts.get("FAIL", 0) == 0 and counts.get("INVALID", 0) == 0:
            return "PASS"
        if counts.get("FAIL", 0) > 0:
            return "FAIL"
        if counts.get("DRY", 0) > 0 and sum(counts.get(k, 0) for k in ("PASS", "FAIL", "INVALID")) == 0:
            return "DRY"
        if counts.get("INVALID", 0) > 0:
            return "INVALID"
    return "UNKNOWN"


def phase_result_is_current(phase: str, result: dict, evidence_path: str | None) -> bool:
    """Ignore stale advanced-chain artifacts from pre-V5 cascade experiments."""
    if phase not in ADVANCED_PHASES:
        return True

    raw_ts = result.get("generated_at_utc") or result.get("generated_at")
    parsed_ts = None
    if raw_ts:
        text = str(raw_ts).replace("Z", "+00:00")
        try:
            parsed_ts = datetime.fromisoformat(text)
            if parsed_ts.tzinfo is None:
                parsed_ts = parsed_ts.replace(tzinfo=timezone.utc)
        except ValueError:
            parsed_ts = None

    if parsed_ts is None and evidence_path:
        p = Path(evidence_path)
        if p.is_file():
            parsed_ts = datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc)

    return bool(parsed_ts and parsed_ts >= ADVANCED_PHASE_RESULT_MIN_UTC)


def per_ea_state(ea_dir: Path) -> dict:
    """Build per-EA state record."""
    ea = ea_dir.name
    phase_verdicts: dict[str, str] = {}
    phase_evidence: dict[str, str] = {}
    for phase in PHASES:
        if phase in MANUAL_GATES and phase != "G0":
            continue  # P9/P9b/P10 are manual, no auto result file
        res = find_phase_result(ea_dir, phase)
        if res is None:
            continue
        evidence_path = str(res.get("evidence_path") or "")
        if not phase_result_is_current(phase, res, evidence_path):
            continue
        phase_verdicts[phase] = extract_verdict(res)
        if evidence_path:
            phase_evidence[phase] = evidence_path

    # Determine latest reached phase = highest phase with PASS verdict
    latest_pass = None
    for phase in PHASES:
        if phase_verdicts.get(phase) == "PASS":
            latest_pass = phase

    # Determine current status
    index_data = read_json_safe(ea_dir / "index.json")
    final_verdict = (index_data or {}).get("final_verdict", "UNKNOWN")
    phase_blockers = (index_data or {}).get("phase_blockers", [])

    # Status classification (board-level coarse status):
    # READY      - aggregator's index.json final_verdict == READY (P8 reached)
    # BLOCKED    - aggregator says BLOCKED OR any verdict == FAIL/INVALID
    # REVIEW_REQUIRED - aggregator says REVIEW_REQUIRED
    # IN_PROGRESS - some phases PASS, latest not yet reached P8
    # NOT_RUN    - no phase result files
    if not phase_verdicts:
        status = "NOT_RUN"
    elif final_verdict == "READY":
        status = "READY"
    elif final_verdict == "BLOCKED" or any(v in {"FAIL", "INVALID"} for v in phase_verdicts.values()):
        status = "BLOCKED"
    elif final_verdict == "REVIEW_REQUIRED":
        status = "REVIEW_REQUIRED"
    else:
        status = "IN_PROGRESS"

    # Find latest result mtime for last_run_utc
    last_run_utc = None
    for phase, ev in phase_evidence.items():
        p = Path(ev)
        if p.is_file():
            ts = datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc).isoformat()
            if last_run_utc is None or ts > last_run_utc:
                last_run_utc = ts

    return {
        "ea_id": ea,
        "latest_pass_phase": latest_pass,
        "phase_verdicts": phase_verdicts,
        "status": status,
        "final_verdict": final_verdict,
        "phase_blockers": phase_blockers,
        "last_run_utc": last_run_utc,
    }


def aggregate_by_phase(eas: list[dict]) -> dict[str, int]:
    """Count EAs whose latest_pass_phase is exactly P{N}, by phase key."""
    by_phase = {PHASE_TO_KEY[p]: 0 for p in PHASES}
    for ea in eas:
        latest = ea.get("latest_pass_phase")
        if latest and latest in PHASE_TO_KEY:
            by_phase[PHASE_TO_KEY[latest]] += 1
    return by_phase


def aggregate_by_status(eas: list[dict]) -> dict[str, int]:
    counts = {"READY": 0, "BLOCKED": 0, "REVIEW_REQUIRED": 0, "IN_PROGRESS": 0, "NOT_RUN": 0}
    for ea in eas:
        s = ea.get("status", "NOT_RUN")
        counts[s] = counts.get(s, 0) + 1
    return counts


def farm_db_by_phase() -> dict[str, int]:
    """Current Strategy Farm DB view of distinct EAs with PASS evidence per phase."""
    by_phase = {PHASE_TO_KEY[p]: 0 for p in PHASES}
    if not FARM_DB.is_file():
        return by_phase

    pass_verdicts = {"PASS", "AUTO_PASS", "MODE_SELECTED", "MULTI_SEED_PASS", "MULTI_SEED_MIXED"}

    con = None
    try:
        con = sqlite3.connect(str(FARM_DB))
        con.row_factory = sqlite3.Row
        rows = con.execute(
            "SELECT ea_id, phase, verdict FROM work_items "
            "WHERE status='done' AND verdict IS NOT NULL"
        ).fetchall()
    except sqlite3.Error:
        return by_phase
    finally:
        try:
            if con is not None:
                con.close()
        except Exception:
            pass

    phase_eas: dict[str, set[str]] = {p: set() for p in PHASES}
    for row in rows:
        ea_id = str(row["ea_id"] or "").strip()
        phase = str(row["phase"] or "").strip()
        verdict = str(row["verdict"] or "").strip().upper()
        if not ea_id or phase not in phase_eas or verdict not in pass_verdicts:
            continue
        phase_eas[phase].add(ea_id)

    for phase, eas in phase_eas.items():
        by_phase[PHASE_TO_KEY[phase]] = len(eas)
    return by_phase


def mt5_state() -> dict:
    """Extract per-terminal MT5 state from aggregator's last_check_state.json."""
    data = read_json_safe(LAST_CHECK_FILE) or {}
    bl = data.get("bl_progress", {})
    out = {}
    for tn in (f"T{i}" for i in range(1, 11)):
        entry = bl.get(tn, {})
        pid = entry.get("terminal_pid")
        running = bool(pid and pid != "none")
        out[tn] = {
            "running": running,
            "terminal_pid": pid,
            "ea": entry.get("ea", "unknown"),
            "status": entry.get("status", "unknown"),
            "latest_report_mtime_utc": entry.get("latest_report_mtime_utc"),
            "report_age_sec": entry.get("report_age_sec"),
            "tracked_report_dirs": entry.get("tracked_report_dirs", 0),
        }
    return out


def agents_watchdog_state() -> dict:
    """Extract sub-agent online/offline counts from the watchdog's latest.json.

    The watchdog flags sub-agents with runs_last_2h == 0 as alarm=true.
    Map: online = not in alarm, offline = in alarm.
    """
    data = read_json_safe(WATCHDOG_LATEST) or {}
    subs = data.get("sub_agents", []) or []
    online = sum(1 for s in subs if not s.get("alarm"))
    offline = sum(1 for s in subs if s.get("alarm"))
    return {
        "online_count": online,
        "offline_count": offline,
        "total_count": len(subs),
        "watchdog_ts_utc": data.get("ts_utc"),
        "active_alarms": [a.get("kind") for a in data.get("alarms", [])],
    }


def dispatch_state_summary() -> dict:
    data = read_json_safe(DISPATCH_STATE) or {}
    return {
        "dedup_entries": len(data.get("dedup", {})),
        "recent_runs_count": len(data.get("recent_runs", [])),
        "phase_matrix_entries": len(data.get("phase_matrix_index", {})),
        "pending_matrix_jobs": len(data.get("pending_matrix_jobs", []) or []),
        "running_jobs": len(data.get("running", []) or []),
    }


# ---------------------------------------------------------------------------
# work_items (farm_state.sqlite) derivation — the AUTHORITATIVE per-EA source.
#
# The DB stores canonical Qxx phase keys (Q02..Q10, plus residual legacy "P2"
# rows and "Q09_PORTFOLIO"). Legacy P* by_phase keys are kept as a COMPATIBILITY
# VIEW mapped from Qxx (public-snapshot.schema.json / export_public_snapshot.ps1
# require exactly the 15 P-keys). The maps below faithfully mirror
# tools/strategy_farm/phase_ids.py (Q_TO_LEGACY_P, PHASE_ORDER) — kept inlined so
# this SYSTEM-scheduled script has no cross-package import dependency.
# ---------------------------------------------------------------------------

# Qxx -> dominant legacy P-key. Mirror of phase_ids.Q_TO_LEGACY_P for the funnel
# keys the public snapshot expects. Q02..Q08 are the automated evidence gates;
# Q11 (portfolio) maps to legacy P9. Q10/Q12/Q13 have no slot in the legacy
# 15-key funnel and are intentionally not surfaced in the compat by_phase view.
DB_Q_TO_LEGACY_P = {
    "Q00": "G0", "Q01": "P1", "Q02": "P2", "Q03": "P3", "Q04": "P4",
    "Q05": "P5", "Q06": "P6", "Q07": "P7", "Q08": "P8",
    "Q11": "P9", "Q12": "P9b", "Q13": "P10",
}

# Canonical Qxx ordering for latest-pass ranking (mirror phase_ids.PHASE_ORDER).
QXX_ORDER = ["Q00", "Q01", "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08",
             "Q09", "Q10", "Q11", "Q12", "Q13"]
QXX_RANK = {q: i for i, q in enumerate(QXX_ORDER)}
TERMINAL_QXX = {"Q10", "Q11", "Q12", "Q13"}

# DB phase-key normalization: residual legacy P-keys / odd variants -> canonical
# Qxx (mirror phase_ids.LEGACY_P_TO_Q for the keys that appear in this DB).
DB_PHASE_NORMALIZE = {
    "P2": "Q02", "P3": "Q03", "P4": "Q04", "P5": "Q05", "P6": "Q07",
    "P7": "Q08", "P8": "Q08",
    "Q09_PORTFOLIO": "Q11",  # portfolio construction; DB labels it Q09_PORTFOLIO
}

# Verdict families. Pass-family = clean gate advance (specific string preserved,
# e.g. PASS_SOFT / PASS_LOWFREQ, so the per-EA history matches the DB exactly).
DB_PASS_VERDICTS = {
    "PASS", "AUTO_PASS", "MODE_SELECTED", "MULTI_SEED_PASS", "MULTI_SEED_MIXED",
    "PASS_SOFT", "PASS_LOWFREQ", "PASS_PORTFOLIO",
}
DB_FAIL_VERDICTS = {
    "FAIL", "FAIL_SOFT", "FAIL_HARD", "INVALID", "INVALID_BUILD_STATIC_FIDELITY",
    "FAIL_PORTFOLIO", "FAIL_DD_PORTFOLIO_REVIEW", "ZERO_TRADES", "DRAFT_DEFECT",
}
# Everything else (INFRA_FAIL, NULL, NEED_MORE_DATA, SUPERSEDED*/RETIRED*/
# OBSOLETE*/CANCELLED*/PENDING*) is infra/lifecycle noise, NOT gate evidence,
# and is ignored for phase reachability + status classification.


def _canon_ea_id(raw: object) -> str:
    """Normalize a work_items ea_id to the canonical QM5_<digits> form.

    A handful of rows store a bare numeric id (e.g. '20022') that collides with
    its 'QM5_20022' sibling; folding them prevents double-counting / stray rows.
    """
    ea = str(raw or "").strip()
    if re.fullmatch(r"\d+", ea):
        return f"QM5_{ea}"
    return ea


def _norm_db_phase(raw: object) -> str:
    ph = str(raw or "").strip().upper()
    return DB_PHASE_NORMALIZE.get(ph, ph)


def _verdict_rank(verdict: str) -> int:
    """2 = pass-family (dominates), 1 = fail-family, 0 = ignore."""
    if verdict in DB_PASS_VERDICTS:
        return 2
    if verdict in DB_FAIL_VERDICTS:
        return 1
    return 0


def _bump_last(slot: dict, ts: object) -> None:
    text = str(ts).strip() if ts is not None else ""
    if not text:
        return
    if slot["last"] is None or text > slot["last"]:
        slot["last"] = text


def _classify_status(latest_pass: str | None, phases: dict[str, tuple]) -> tuple[str, str]:
    """Coarse board status from the per-phase dominant verdicts.

    Precedence: NOT_RUN (no clean evidence) -> READY (pass at a terminal gate)
    -> BLOCKED (any fail-family dominant) -> IN_PROGRESS (pass, mid-pipeline).
    REVIEW_REQUIRED is retained as a valid bucket but the DB carries no verdict
    that maps to it. final_verdict mirrors status (no consumer reads it per-EA;
    kept for schema/back-compat with the old index.json-sourced field).
    """
    if not phases:
        return "NOT_RUN", "UNKNOWN"
    if latest_pass in TERMINAL_QXX:
        # A fail-family verdict at a phase RANKED AFTER the latest pass must win
        # (codex impl-review 2026-07-24 #10: Q10 PASS + Q11 FAIL_PORTFOLIO was
        # exported as READY). The decisive gate is the furthest one, not the
        # furthest passing one.
        lp_rank = QXX_RANK.get(latest_pass, -1)
        if any(rank == 1 and QXX_RANK.get(ph, -1) > lp_rank
               for ph, (rank, _verdict) in phases.items()):
            return "BLOCKED", "BLOCKED"
        return "READY", "READY"
    if any(rank == 1 for rank, _ in phases.values()):
        return "BLOCKED", "BLOCKED"
    if latest_pass is not None:
        return "IN_PROGRESS", "IN_PROGRESS"
    return "NOT_RUN", "UNKNOWN"


def load_per_ea_from_db() -> tuple[list[dict], bool]:
    """Derive per-EA state from work_items (READ-ONLY). Returns (per_ea, ok).

    ok=False means the DB could not be opened; the caller then falls back to the
    legacy filesystem derivation (resilience only — never the primary source).

    Per (EA, phase) the DB holds many rows (one per symbol/config/attempt); the
    dominant verdict for a phase is its highest-ranked verdict (pass beats fail
    beats infra/lifecycle noise). Only phases with a clean pass/fail dominant are
    recorded; EAs with no clean gate evidence at all are omitted entirely.
    """
    if not FARM_DB.is_file():
        return [], False

    con = None
    try:
        con = sqlite3.connect(f"file:{FARM_DB.as_posix()}?mode=ro", uri=True)
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA busy_timeout=4000")
        rows = con.execute(
            "SELECT ea_id, phase, verdict, updated_at FROM work_items "
            "WHERE status='done' AND verdict IS NOT NULL"
        ).fetchall()
    except sqlite3.Error:
        return [], False
    finally:
        try:
            if con is not None:
                con.close()
        except Exception:
            pass

    # ea_id -> {"phases": {Qxx: (rank, verdict)}, "last": iso_str|None}
    per: dict[str, dict] = {}
    for row in rows:
        ea = _canon_ea_id(row["ea_id"])
        if not ea:
            continue
        phase = _norm_db_phase(row["phase"])
        verdict = str(row["verdict"] or "").strip().upper()
        rank = _verdict_rank(verdict)
        slot = per.setdefault(ea, {"phases": {}, "last": None})
        _bump_last(slot, row["updated_at"])
        if rank == 0 or phase not in QXX_RANK:
            continue  # infra/lifecycle noise, or an out-of-model phase key
        cur = slot["phases"].get(phase)
        if cur is None or rank > cur[0]:
            slot["phases"][phase] = (rank, verdict)

    out: list[dict] = []
    for ea in sorted(per):
        slot = per[ea]
        phases = slot["phases"]
        if not phases:
            continue  # DB activity but no clean gate evidence -> omit
        latest_pass = None
        for phase, (rank, _v) in phases.items():
            if rank == 2 and (latest_pass is None or QXX_RANK[phase] > QXX_RANK[latest_pass]):
                latest_pass = phase
        phase_verdicts = {ph: v for ph, (_r, v) in sorted(phases.items(), key=lambda kv: QXX_RANK[kv[0]])}
        phase_blockers = [
            {"phase": ph, "verdict": v}
            for ph, (rank, v) in sorted(phases.items(), key=lambda kv: QXX_RANK[kv[0]])
            if rank == 1
        ]
        status, final_verdict = _classify_status(latest_pass, phases)
        out.append({
            "ea_id": ea,
            "latest_pass_phase": latest_pass,       # canonical Qxx (None if no pass)
            "phase_verdicts": phase_verdicts,        # {Qxx: raw verdict string}
            "status": status,
            "final_verdict": final_verdict,
            "phase_blockers": phase_blockers,        # DB-derived (fail-family gates)
            "last_run_utc": slot["last"],
        })
    return out, True


def db_by_phase_legacy(per_ea: list[dict]) -> dict[str, int]:
    """Legacy P-keyed funnel (compat view for the public snapshot): distinct EAs
    with a pass-family verdict at each Qxx gate, mapped to legacy P-keys.

    All 15 legacy keys are always present (0 default). Q02..Q08 populate P2..P8;
    Q11 (portfolio) populates P9. Folded/manual keys (P3_5, P5b, P5c, G0, P1,
    P9b, P10) stay 0 — no Qxx gate feeds them.
    """
    qxx_pass: dict[str, set[str]] = {}
    for ea in per_ea:
        for phase, verdict in ea.get("phase_verdicts", {}).items():
            if str(verdict).upper() in DB_PASS_VERDICTS:
                qxx_pass.setdefault(phase, set()).add(ea["ea_id"])
    legacy = {PHASE_TO_KEY[p]: 0 for p in PHASES}
    for phase, eas in qxx_pass.items():
        key = DB_Q_TO_LEGACY_P.get(phase)
        if key and key in legacy:
            legacy[key] = len(eas)
    return legacy


def build() -> dict:
    per_ea, db_ok = load_per_ea_from_db()
    per_ea_source = "work_items"

    if db_ok:
        by_phase = db_by_phase_legacy(per_ea)
    else:
        # Resilience fallback ONLY: the farm DB could not be opened. Reconstruct
        # the coarse/incomplete legacy view from filesystem artifacts (FB-05:
        # this path under-reports gate state and is not the source of truth).
        per_ea_source = "filesystem_fallback"
        per_ea = []
        if PIPELINE_ROOT.is_dir():
            for d in sorted(PIPELINE_ROOT.iterdir()):
                if d.is_dir() and d.name.startswith("QM5_"):
                    per_ea.append(per_ea_state(d))
        by_phase = aggregate_by_phase(per_ea)
        db_by_phase = farm_db_by_phase()
        if sum(db_by_phase.values()) > 0:
            for phase in ("P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8"):
                by_phase[PHASE_TO_KEY[phase]] = db_by_phase[PHASE_TO_KEY[phase]]

    registry = read_ea_registry()
    cards = count_strategy_cards()

    state = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generated_by": "scripts/build_pipeline_state.py",
        "per_ea_source": per_ea_source,
        "strategy_cards_count": cards,
        "eas_registered_count": len(registry),
        "eas_with_reports_count": len(per_ea),
        "by_phase": by_phase,
        "by_status": aggregate_by_status(per_ea),
        "mt5": mt5_state(),
        "agents_watchdog": agents_watchdog_state(),
        "dispatch": dispatch_state_summary(),
        "per_ea": per_ea,
    }
    return state


def atomic_write(path: Path, content: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    os.replace(tmp, path)
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="Print JSON, do not write file.")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    state = build()
    out = json.dumps(state, indent=2, default=str)

    if args.dry_run:
        print(out)
        return 0

    atomic_write(STATE_FILE, out)
    if args.verbose:
        print(f"Wrote {STATE_FILE} ({len(out)} bytes)")
        print(f"  strategy_cards={state['strategy_cards_count']} eas_registered={state['eas_registered_count']} eas_with_reports={state['eas_with_reports_count']}")
        print(f"  by_phase={state['by_phase']}")
        print(f"  by_status={state['by_status']}")
        print(f"  mt5_running={[k for k,v in state['mt5'].items() if v['running']]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
