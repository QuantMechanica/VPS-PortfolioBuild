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
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PIPELINE_ROOT = Path(r"D:\QM\reports\pipeline")
EA_ROOT = REPO_ROOT / "framework" / "EAs"

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
                # P2 result.json has counts, derive verdict
                counts = data.get("counts") or {}
                if counts.get("PASS", 0) > 0:
                    verdict = "PASS"
                elif counts.get("FAIL", 0) > 0:
                    verdict = "BLOCKED"
                elif counts.get("INVALID", 0) > 0:
                    verdict = "BLOCKED"
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
        if counts.get("PASS", 0) > 0:
            return "PASS", {"counts": dict(counts)}
        if counts.get("FAIL", 0) > 0 or counts.get("INVALID", 0) > 0:
            return "BLOCKED", {"counts": dict(counts)}
        return "NOT_RUN", {"counts": dict(counts)}

    return "NOT_RUN", {}


def find_next_phase(ea: str) -> tuple[str | None, str, dict]:
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
        return "P1", "BOOTSTRAP", {}

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

    return next_phase, f"ADVANCING:{last_pass}->{next_phase}", {"last_pass": last_pass}


def append_orchestration_log(ea: str, decision: dict) -> None:
    log_dir = PIPELINE_ROOT / ea
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / "orchestration.log"
    line = f"{datetime.now(timezone.utc).isoformat()} | {json.dumps(decision, ensure_ascii=False)}\n"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(line)


def launch_phase(ea: str, phase: str, dry_run: bool) -> dict:
    """Dispatch the runner for a phase. Returns dict with status."""
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
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ea", help="single EA (default: all discovered)")
    ap.add_argument("--execute", action="store_true", help="actually launch the next phase")
    ap.add_argument("--dry-run", action="store_true", help="print plan only")
    ap.add_argument("--json", action="store_true", help="emit JSON")
    args = ap.parse_args()

    eas = [args.ea] if args.ea else discover_eas()
    decisions = []
    for ea in eas:
        next_phase, state, evidence = find_next_phase(ea)
        decision = {
            "ts_utc": datetime.now(timezone.utc).isoformat(),
            "ea": ea,
            "state": state,
            "next_phase": next_phase,
            "evidence": evidence,
        }
        if next_phase and args.execute:
            launch_result = launch_phase(ea, next_phase, args.dry_run)
            decision["launch"] = launch_result
        elif next_phase and args.dry_run:
            decision["launch"] = launch_phase(ea, next_phase, dry_run=True)
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
