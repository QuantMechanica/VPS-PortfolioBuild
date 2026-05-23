"""Phase Orchestrator — advance EAs through G0 -> P1 -> P2 -> ... -> P10.

After each phase completes (PASS), the orchestrator decides whether the EA can
advance to the next phase. It does NOT execute backtests directly — it dispatches
the appropriate runner script for the next phase, and tracks progression in
`D:/QM/reports/pipeline/<EA>/orchestration.log`.

Usage:
    python phase_orchestrator.py                                # decide for all known EAs
    python phase_orchestrator.py --ea QM5_1003                  # one EA
    python phase_orchestrator.py --ea QM5_1003 --execute        # actually launch next phase
    python phase_orchestrator.py --dry-run                      # report only

Spec source: docs/ops/PIPELINE_PHASE_SPEC.md (G0..P10).
Manual gates (P9, P9b, P10) are NEVER auto-launched — they require OWNER decision.

Wire-up:
- Cron-style: register via Windows Task Scheduler hourly
- On-demand: Pipeline-Op heartbeat invokes after each phase completes
"""
from __future__ import annotations

import argparse
import csv
import json
import sqlite3
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
import re

if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts.queue_init import ensure_schema
from framework.scripts.pipeline_dispatcher import dedup_key, load_dispatch_state, DEFAULT_STATE_PATH

REPO_ROOT = Path(__file__).resolve().parents[2]
PIPELINE_ROOT = Path(r"D:\QM\reports\pipeline")
EA_ROOT = REPO_ROOT / "framework" / "EAs"
DEFAULT_QUEUE_SQLITE = Path(r"D:\QM\reports\pipeline\mt5_queue.db")
DEFAULT_DISPATCH_STATE = DEFAULT_STATE_PATH
VERIFY_BUILD_DEPLOYMENT_SCRIPT = REPO_ROOT / "framework" / "scripts" / "verify_build_deployment.py"

# Phase order per PIPELINE_PHASE_SPEC.md
PHASE_ORDER = ["G0", "P1", "P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8", "P9", "P9b", "P10"]

# Manual gates — orchestrator marks ready but does NOT launch
MANUAL_GATES = {"G0", "P9", "P9b", "P10"}

# Phase runners — script name + args invocation
PHASE_RUNNERS = {
    "P1": ("python", "framework/scripts/p1_build_validation.py", ["--ea"]),  # not built yet
    "P2": ("python", "framework/scripts/p2_baseline.py", ["--ea"]),
    "P3": ("python", "framework/scripts/p3_param_sweep.py", ["--ea"]),  # not built yet
    "P3.5": ("pwsh", "framework/scripts/run_phase.ps1", ["-EAId", "-Phase", "P3.5"]),
    "P4": ("python", "framework/scripts/p4_walk_forward.py", ["--ea"]),
    "P5": ("pwsh", "framework/scripts/run_phase.ps1", ["-EAId", "-Phase", "P5"]),
    "P5b": ("pwsh", "framework/scripts/run_phase.ps1", ["-EAId", "-Phase", "P5b"]),
    "P5c": ("pwsh", "framework/scripts/run_phase.ps1", ["-EAId", "-Phase", "P5c"]),
    "P6": ("pwsh", "framework/scripts/run_phase.ps1", ["-EAId", "-Phase", "P6"]),
    "P7": ("pwsh", "framework/scripts/run_phase.ps1", ["-EAId", "-Phase", "P7"]),
    "P8": ("pwsh", "framework/scripts/run_phase.ps1", ["-EAId", "-Phase", "P8"]),
}
QUEUE_PHASES = {"P2"}


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _find_ea_dir(ea_label: str) -> Path | None:
    exact = EA_ROOT / ea_label
    if exact.is_dir():
        return exact
    candidates = [p for p in EA_ROOT.glob(f"{ea_label}_*") if p.is_dir()]
    if not candidates:
        return None
    if len(candidates) > 1:
        return None
    return candidates[0]


def _discover_phase_symbols(ea: str, phase: str, period: str = "H1") -> tuple[list[str], str]:
    ea_dir = _find_ea_dir(ea)
    if ea_dir is None:
        return [], "ea_dir_missing_or_ambiguous"
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        return [], "sets_dir_missing"
    if phase != "P2":
        return [], f"unsupported_queue_phase:{phase}"
    pattern = re.compile(rf"^{re.escape(ea_dir.name)}_(.+?)_{re.escape(period)}_backtest\.set$")
    symbols: list[str] = []
    for item in sorted(sets_dir.iterdir()):
        m = pattern.match(item.name)
        if m:
            symbols.append(m.group(1))
    if not symbols:
        return [], "setfiles_not_found"
    return symbols, ""


def _setfile_path_for_symbol(ea: str, symbol: str, period: str = "H1") -> str | None:
    ea_dir = _find_ea_dir(ea)
    if ea_dir is None:
        return None
    setfile = ea_dir / "sets" / f"{ea_dir.name}_{symbol}_{period}_backtest.set"
    if not setfile.exists():
        return None
    return str(setfile)


def _normalize_ea_numeric_id(ea: str) -> str:
    label = str(ea or "").strip()
    if label.startswith("QM5_"):
        parts = label.split("_", 2)
        if len(parts) >= 2:
            return parts[1]
    return label


def _verify_build_deployment_for_ea(ea: str, dry_run: bool) -> tuple[bool, str, dict]:
    if dry_run:
        return True, "", {"verdict": "PASS", "dry_run": True}
    if not VERIFY_BUILD_DEPLOYMENT_SCRIPT.exists():
        return False, "build_verify:script_missing", {"verdict": "VERIFY_SCRIPT_MISSING"}
    ea_dir_glob = ea if (EA_ROOT / ea).is_dir() else f"{ea}_*"
    cmd = [
        sys.executable,
        str(VERIFY_BUILD_DEPLOYMENT_SCRIPT),
        "--json",
        "--ea-id",
        _normalize_ea_numeric_id(ea),
        "--ea-dir-glob",
        ea_dir_glob,
    ]
    try:
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False, creationflags=creationflags)
    except Exception as exc:
        return False, f"build_verify:exception:{exc}", {"verdict": "VERIFY_EXCEPTION"}
    try:
        payload = json.loads(proc.stdout or "{}")
    except Exception:
        payload = {"stdout": (proc.stdout or "")[:1000], "stderr": (proc.stderr or "")[:1000]}
    verdict = str(payload.get("verdict") or "").strip().upper()
    if int(proc.returncode) == 0 and verdict == "PASS":
        return True, "", payload
    return False, f"build_verify:{verdict or 'FAILED'}:rc={int(proc.returncode)}", payload


def _enqueue_phase_jobs(
    *,
    ea: str,
    phase: str,
    sqlite_path: Path,
    period: str = "H1",
    version: str = "v1",
) -> dict:
    symbols, err = _discover_phase_symbols(ea, phase, period=period)
    if not symbols:
        return {"status": "enqueue_unavailable", "phase": phase, "reason": err}
    sqlite_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(sqlite_path))
    inserted = 0
    skipped_duplicate = 0
    invalid_setfile = 0
    inserted_ids: list[str] = []
    now_iso = _utc_now_iso()
    dedup_seen: set[str] = set()
    try:
        ensure_schema(conn)
        for symbol in symbols:
            setfile_path = _setfile_path_for_symbol(ea, symbol, period=period)
            if not setfile_path:
                invalid_setfile += 1
                continue
            job = {
                "ea_id": ea,
                "version": version,
                "phase": phase,
                "symbol": symbol,
                "sub_gate_config_hash": f"{ea}|{version}|{symbol}|{phase}|{period}",
                "setfile_path": setfile_path.replace("\\", "/"),
                "target_terminal": "any",
            }
            key = dedup_key(job)
            if key in dedup_seen:
                skipped_duplicate += 1
                continue
            dedup_seen.add(key)
            dup = conn.execute(
                """
                SELECT 1
                FROM jobs
                WHERE ea_id = ?
                  AND version = ?
                  AND symbol = ?
                  AND phase = ?
                  AND sub_gate_config_hash = ?
                  AND status IN ('queued', 'claimed', 'running', 'done', 'failed', 'invalid', 'blocked_strategy', 'failed_terminal')
                LIMIT 1
                """,
                (
                    job["ea_id"],
                    job["version"],
                    job["symbol"],
                    job["phase"],
                    job["sub_gate_config_hash"],
                ),
            ).fetchone()
            if dup:
                skipped_duplicate += 1
                continue
            job_id = str(uuid.uuid4())
            cur = conn.execute(
                """
                INSERT OR IGNORE INTO jobs
                (job_id,ea_id,version,symbol,period,year,phase,sub_gate_config_hash,setfile_path,status,retry_count,enqueued_at,enqueued_by)
                VALUES (?,?,?,?,?,?,?,?,?,'queued',0,?,'phase_orchestrator')
                """,
                (
                    job_id,
                    job["ea_id"],
                    job["version"],
                    job["symbol"],
                    period,
                    2024,
                    job["phase"],
                    job["sub_gate_config_hash"],
                    job["setfile_path"],
                    now_iso,
                ),
            )
            if cur.rowcount > 0:
                inserted += 1
                inserted_ids.append(job_id)
            else:
                skipped_duplicate += 1
        conn.commit()
    finally:
        conn.close()
    return {
        "status": "enqueued",
        "phase": phase,
        "sqlite": str(sqlite_path),
        "requested": len(symbols),
        "inserted": inserted,
        "skipped_duplicate": skipped_duplicate,
        "invalid_setfile": invalid_setfile,
        "inserted_ids": inserted_ids,
    }


def discover_eas() -> list[str]:
    """Discover EAs from filesystem (pipeline reports + EA dirs)."""
    eas = set()
    if PIPELINE_ROOT.is_dir():
        for d in PIPELINE_ROOT.iterdir():
            if d.is_dir() and d.name.startswith(("QM5_", "QM5-")):
                eas.add(d.name)
    if EA_ROOT.is_dir():
        for d in EA_ROOT.iterdir():
            if d.is_dir() and d.name.startswith(("QM5_", "QM5-")):
                # Extract canonical EA label (QM5_NNNN or QM5_SRC04_S03)
                parts = d.name.split("_")
                if len(parts) >= 2:
                    if parts[1].startswith("SRC"):
                        eas.add("_".join(parts[:3]))
                    else:
                        eas.add("_".join(parts[:2]))
    return sorted(eas)


def read_phase_verdict(ea: str, phase: str) -> tuple[str, dict]:
    """Read phase result for EA. Returns (verdict, raw_json_or_csv_summary).

    PASS = phase complete, can advance.
    REVIEW_REQUIRED = needs human/CEO judgment.
    BLOCKED = phase ran but failed.
    NOT_RUN = no report.csv / no result file.
    """
    phase_dir_name = phase.replace(".", "_")
    phase_dir = PIPELINE_ROOT / ea / phase_dir_name
    if not phase_dir.is_dir():
        # P2 uses non-underscored convention
        phase_dir = PIPELINE_ROOT / ea / phase
    if not phase_dir.is_dir():
        return "NOT_RUN", {}

    # Try result JSON first
    result_file = phase_dir / f"{phase_dir_name}_{ea}_result.json"
    if not result_file.exists():
        result_file = phase_dir / f"p2_{ea}_result.json" if phase == "P2" else result_file
    if result_file.exists():
        try:
            with result_file.open(encoding="utf-8-sig") as f:
                data = json.load(f)
            verdict = (data.get("verdict") or data.get("final_verdict") or "").upper()
            if not verdict and phase == "P2":
                # P2 result.json has aggregate counts. A single PASS is not a
                # phase PASS if any row failed or went invalid.
                counts = data.get("counts") or {}
                pass_count = int(counts.get("PASS", 0) or 0)
                bad_count = sum(int(counts.get(k, 0) or 0) for k in ("FAIL", "INVALID", "BLOCKED", "ERROR"))
                total_count = sum(int(v or 0) for v in counts.values())
                if bad_count > 0:
                    verdict = "BLOCKED"
                elif pass_count > 0 and pass_count == total_count:
                    verdict = "PASS"
                else:
                    verdict = "NOT_RUN"
            return verdict or "NOT_RUN", data
        except Exception as e:
            return "ERROR", {"error": str(e)}

    # Fallback: count from report.csv
    report_csv = phase_dir / "report.csv"
    if report_csv.exists():
        from collections import Counter
        counts = Counter()
        with report_csv.open(encoding="utf-8", errors="replace") as f:
            r = csv.DictReader(f)
            for row in r:
                counts[(row.get("verdict") or "").upper()] += 1
        bad_count = sum(counts.get(key, 0) for key in ("FAIL", "INVALID", "BLOCKED", "ERROR"))
        total_count = sum(counts.values())
        if bad_count > 0:
            return "BLOCKED", {"counts": dict(counts)}
        if counts.get("PASS", 0) > 0 and counts.get("PASS", 0) == total_count:
            return "PASS", {"counts": dict(counts)}
        return "NOT_RUN", {"counts": dict(counts)}

    return "NOT_RUN", {}


def _phase_from_dispatch_key(ea: str, key: str) -> tuple[str, str] | None:
    prefix = f"{ea}_"
    if not key.startswith(prefix):
        return None
    tail = key[len(prefix):]
    if "_" not in tail:
        return None
    version, phase = tail.split("_", 1)
    if not version or not phase:
        return None
    return version, phase


def _read_dispatch_phase_verdicts(ea: str, dispatch_state_path: Path) -> tuple[dict[str, str], dict]:
    try:
        state = load_dispatch_state(dispatch_state_path)
    except Exception as exc:  # noqa: BLE001
        return {}, {"dispatch_error": str(exc)}
    matrix = state.get("phase_matrix_index", {})
    if not isinstance(matrix, dict):
        return {}, {"dispatch_error": "phase_matrix_index_not_dict"}
    verdicts: dict[str, str] = {}
    for key, bucket in matrix.items():
        if not isinstance(key, str) or not isinstance(bucket, dict):
            continue
        parsed = _phase_from_dispatch_key(ea, key)
        if not parsed:
            continue
        _version, phase = parsed
        verdict = str(bucket.get("phase_verdict") or "").strip().upper()
        if not verdict:
            continue
        if verdict == "PASS":
            verdicts[phase] = "PASS"
        elif verdict.startswith("FAIL") or verdict in {"INVALID", "BLOCKED"}:
            verdicts[phase] = "BLOCKED"
    return verdicts, {"dispatch_state_path": str(dispatch_state_path), "dispatch_phases": sorted(verdicts.keys())}


def find_next_phase(ea: str, dispatch_state_path: Path | None = None) -> tuple[str | None, str, dict]:
    """Walk PHASE_ORDER. Returns (next_phase_to_launch, current_state, evidence).

    Logic:
    - Find the highest phase with PASS verdict (current "level").
    - The next phase is the one immediately after.
    - If next phase is in MANUAL_GATES, return None (OWNER decides).
    - If any phase has BLOCKED, return None (don't advance past failure).
    - If no phase has PASS yet, recommend P1 (or G0 manual).
    """
    last_pass = None
    blocker = None
    dispatch_verdicts: dict[str, str] = {}
    dispatch_evidence: dict = {}
    if dispatch_state_path:
        dispatch_verdicts, dispatch_evidence = _read_dispatch_phase_verdicts(ea, dispatch_state_path)
    if dispatch_verdicts:
        for phase in PHASE_ORDER:
            verdict = dispatch_verdicts.get(phase)
            if verdict == "PASS":
                last_pass = phase
            elif verdict == "BLOCKED":
                blocker = (phase, dispatch_evidence)
                break
    else:
        for phase in PHASE_ORDER:
            verdict, evidence = read_phase_verdict(ea, phase)
            if verdict == "PASS":
                last_pass = phase
            elif verdict == "BLOCKED":
                blocker = (phase, evidence)
                break

    if blocker:
        return None, f"BLOCKED at {blocker[0]}", blocker[1]

    if last_pass is None:
        # Nothing has passed yet — recommend P1 (G0 is manual)
        return "P1", "BOOTSTRAP", dispatch_evidence if dispatch_evidence else {}

    # Find phase after last_pass
    try:
        idx = PHASE_ORDER.index(last_pass)
    except ValueError:
        return None, f"unknown phase {last_pass}", {}

    if idx + 1 >= len(PHASE_ORDER):
        return None, "ALL_PHASES_COMPLETE", {}

    next_phase = PHASE_ORDER[idx + 1]
    if next_phase in MANUAL_GATES:
        return None, f"MANUAL_GATE:{next_phase}", {"last_pass": last_pass}

    evidence = {"last_pass": last_pass}
    if dispatch_evidence:
        evidence["source"] = "dispatch_state"
        evidence["dispatch_state_path"] = dispatch_evidence.get("dispatch_state_path")
    return next_phase, f"ADVANCING:{last_pass}->{next_phase}", evidence


def append_orchestration_log(ea: str, decision: dict) -> None:
    log_dir = PIPELINE_ROOT / ea
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / "orchestration.log"
    line = f"{datetime.now(timezone.utc).isoformat()} | {json.dumps(decision, ensure_ascii=False)}\n"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(line)


def launch_phase(ea: str, phase: str, dry_run: bool, queue_sqlite: Path) -> dict:
    """Dispatch the runner for a phase. Returns dict with status."""
    if phase == "P2":
        verify_ok, verify_reason, verify_payload = _verify_build_deployment_for_ea(ea, dry_run=dry_run)
        if not verify_ok:
            return {
                "status": "blocked_ghost_build",
                "phase": phase,
                "reason": verify_reason,
                "verifier": verify_payload,
            }
    if phase in QUEUE_PHASES:
        if dry_run:
            symbols, err = _discover_phase_symbols(ea, phase)
            if symbols:
                return {
                    "status": "dry_run_enqueue",
                    "phase": phase,
                    "sqlite": str(queue_sqlite),
                    "symbols": symbols,
                }
            return {"status": "dry_run_enqueue_unavailable", "phase": phase, "reason": err}
        return _enqueue_phase_jobs(ea=ea, phase=phase, sqlite_path=queue_sqlite)
    if phase not in PHASE_RUNNERS:
        return {"status": "no_runner", "phase": phase}
    interpreter, script, base_args = PHASE_RUNNERS[phase]
    script_path = REPO_ROOT / script
    if not script_path.exists():
        return {"status": "runner_missing", "script": str(script_path), "phase": phase}

    # Build args
    cmd = []
    if interpreter == "python":
        cmd.append(sys.executable)
    elif interpreter == "pwsh":
        cmd.extend(["pwsh", "-NoProfile", "-File"])
    cmd.append(str(script_path))
    for arg in base_args:
        cmd.append(arg)
    # Append EA value
    if "--ea" in base_args:
        cmd.append(ea)
    elif "-EAId" in base_args:
        # ea_id is numeric for run_phase.ps1
        ea_num = ea.split("_")[1] if "_" in ea else ea
        cmd.append(ea_num if ea_num.isdigit() else ea)

    if dry_run:
        return {"status": "dry_run", "phase": phase, "cmd": cmd}

    DETACHED = 0x00000008 | 0x00000200 | 0x08000000
    proc = subprocess.Popen(cmd, creationflags=DETACHED, close_fds=True,
                            stdin=subprocess.DEVNULL,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL)
    return {"status": "launched", "phase": phase, "pid": proc.pid, "cmd": cmd}


def main() -> int:
    global PIPELINE_ROOT
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ea", help="single EA (default: all discovered)")
    ap.add_argument("--execute", action="store_true", help="actually launch the next phase")
    ap.add_argument("--dry-run", action="store_true", help="print plan only")
    ap.add_argument("--json", action="store_true", help="emit JSON")
    ap.add_argument("--queue-sqlite", default=str(DEFAULT_QUEUE_SQLITE), help="SQLite queue path for producer phases")
    ap.add_argument("--pipeline-root", default=str(PIPELINE_ROOT), help="Pipeline reports root path")
    ap.add_argument("--dispatch-state", default=str(DEFAULT_DISPATCH_STATE), help="dispatch_state.json path")
    args = ap.parse_args()
    PIPELINE_ROOT = Path(args.pipeline_root)
    queue_sqlite = Path(args.queue_sqlite)
    dispatch_state_path = Path(args.dispatch_state)

    eas = [args.ea] if args.ea else discover_eas()
    decisions = []
    for ea in eas:
        next_phase, state, evidence = find_next_phase(ea, dispatch_state_path=dispatch_state_path)
        decision = {
            "ts_utc": datetime.now(timezone.utc).isoformat(),
            "ea": ea,
            "state": state,
            "next_phase": next_phase,
            "evidence": evidence,
        }
        if next_phase and args.execute:
            launch_result = launch_phase(ea, next_phase, args.dry_run, queue_sqlite)
            decision["launch"] = launch_result
        elif next_phase and args.dry_run:
            decision["launch"] = launch_phase(ea, next_phase, dry_run=True, queue_sqlite=queue_sqlite)
        decisions.append(decision)
        append_orchestration_log(ea, decision)

    if args.json:
        print(json.dumps(decisions, indent=2))
    else:
        for d in decisions:
            np = d.get("next_phase") or "—"
            evidence_compact = ""
            if d.get("evidence"):
                ev = d["evidence"]
                if "last_pass" in ev:
                    evidence_compact = f" last_pass={ev['last_pass']}"
            launch = d.get("launch", {})
            launch_str = ""
            if launch:
                launch_str = f" launch={launch.get('status')}"
                if launch.get("pid"):
                    launch_str += f" pid={launch['pid']}"
            print(f"  {d['ea']:<30} state={d['state']:<35} next={np}{evidence_compact}{launch_str}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
