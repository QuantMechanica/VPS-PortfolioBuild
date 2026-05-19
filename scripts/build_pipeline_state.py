"""Build pipeline_state.json — single source of truth for EA pipeline state.

Reads filesystem state under D:/QM/reports/pipeline, the V5 EA registry,
strategy cards, the aggregator's last_check_state.json, the watchdog's latest.json,
and the dispatcher's dispatch_state.json. Produces an atomic
D:/QM/reports/state/pipeline_state.json that downstream consumers
(dashboards, public snapshot exporter, daily summary) read.

Design:
- Pure derivation from existing artifacts on disk. No agent calls, no DB.
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
    if not STRATEGY_CARDS_DIR.is_dir():
        return 0
    return sum(1 for p in STRATEGY_CARDS_DIR.iterdir() if p.is_file() and p.suffix == ".md")


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
    """Current Strategy Farm DB view of each EA's highest PASS phase."""
    by_phase = {PHASE_TO_KEY[p]: 0 for p in PHASES}
    if not FARM_DB.is_file():
        return by_phase

    phase_rank = {phase: idx for idx, phase in enumerate(PHASES)}
    latest_by_ea: dict[str, str] = {}
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

    for row in rows:
        ea_id = str(row["ea_id"] or "").strip()
        phase = str(row["phase"] or "").strip()
        verdict = str(row["verdict"] or "").strip().upper()
        if not ea_id or phase not in phase_rank or verdict not in pass_verdicts:
            continue
        current = latest_by_ea.get(ea_id)
        if current is None or phase_rank[phase] > phase_rank[current]:
            latest_by_ea[ea_id] = phase

    for phase in latest_by_ea.values():
        by_phase[PHASE_TO_KEY[phase]] += 1
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


def build() -> dict:
    eas = []
    if PIPELINE_ROOT.is_dir():
        for d in sorted(PIPELINE_ROOT.iterdir()):
            if d.is_dir() and d.name.startswith("QM5_"):
                eas.append(per_ea_state(d))

    registry = read_ea_registry()
    cards = count_strategy_cards()

    by_phase = aggregate_by_phase(eas)
    db_by_phase = farm_db_by_phase()
    if sum(db_by_phase.values()) > 0:
        for phase in ("P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8"):
            by_phase[PHASE_TO_KEY[phase]] = db_by_phase[PHASE_TO_KEY[phase]]

    state = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "strategy_cards_count": cards,
        "eas_registered_count": len(registry),
        "eas_with_reports_count": len(eas),
        "by_phase": by_phase,
        "by_status": aggregate_by_status(eas),
        "mt5": mt5_state(),
        "agents_watchdog": agents_watchdog_state(),
        "dispatch": dispatch_state_summary(),
        "per_ea": eas,
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
