#!/usr/bin/env python3
"""Run periodic ghost-build reconciliation across dispatch_state EAs.

Reads dispatch_state.json phase_matrix_index, verifies each EA build/deployment via
verify_build_deployment.py, and writes CSV evidence for operator review.
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts.pipeline_dispatcher import load_dispatch_state

REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFY_SCRIPT = REPO_ROOT / "framework" / "scripts" / "verify_build_deployment.py"
DEFAULT_DISPATCH_STATE = Path(r"D:\QM\Reports\pipeline\dispatch_state.json")
DEFAULT_OUT_DIR = Path(r"D:\QM\reports\pipeline\ghost_build_reconciler")


def utc_now_compact() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _ea_from_phase_matrix_key(key: str) -> str | None:
    # Expected shape: <ea>_<version>_<phase>, where <ea> can contain underscores.
    parts = str(key).rsplit("_", 2)
    if len(parts) != 3:
        return None
    ea = parts[0].strip()
    return ea if ea.startswith("QM5_") else None


def _normalize_ea_numeric_id(ea: str) -> str:
    label = str(ea or "").strip()
    if label.startswith("QM5_"):
        parts = label.split("_", 2)
        if len(parts) >= 2:
            return parts[1]
    return label


def discover_eas(dispatch_state_path: Path) -> list[str]:
    state = load_dispatch_state(dispatch_state_path)
    matrix = state.get("phase_matrix_index", {})
    if not isinstance(matrix, dict):
        return []
    eas = {_ea_from_phase_matrix_key(k) for k in matrix.keys() if isinstance(k, str)}
    return sorted([ea for ea in eas if ea])


def verify_ea(ea: str) -> dict:
    if not VERIFY_SCRIPT.exists():
        return {
            "ea": ea,
            "ea_id": _normalize_ea_numeric_id(ea),
            "verdict": "VERIFY_SCRIPT_MISSING",
            "exit_code": -1,
            "reason": "verify_build_deployment.py missing",
            "raw": {},
        }
    cmd = [
        sys.executable,
        str(VERIFY_SCRIPT),
        "--json",
        "--ea-id",
        _normalize_ea_numeric_id(ea),
        "--ea-dir-glob",
        f"{ea}_*",
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except Exception as exc:  # noqa: BLE001
        return {
            "ea": ea,
            "ea_id": _normalize_ea_numeric_id(ea),
            "verdict": "VERIFY_EXCEPTION",
            "exit_code": -1,
            "reason": f"exception:{exc}",
            "raw": {},
        }

    try:
        payload = json.loads(proc.stdout or "{}")
    except Exception:  # noqa: BLE001
        payload = {"stdout": (proc.stdout or "")[:1000], "stderr": (proc.stderr or "")[:1000]}

    verdict = str(payload.get("verdict") or "FAILED").upper()
    reason = ""
    evidence = payload.get("evidence")
    if isinstance(evidence, dict):
        deploy_missing = evidence.get("deploy_missing")
        sha_mismatch = evidence.get("sha_mismatch")
        if deploy_missing:
            reason = f"deploy_missing:{','.join(str(x) for x in deploy_missing)}"
        elif sha_mismatch:
            reason = f"sha_mismatch:{','.join(str(x) for x in sha_mismatch)}"
    if not reason and verdict != "PASS":
        reason = f"verifier_exit:{proc.returncode}"

    return {
        "ea": ea,
        "ea_id": _normalize_ea_numeric_id(ea),
        "verdict": verdict,
        "exit_code": int(proc.returncode),
        "reason": reason,
        "raw": payload,
    }


def write_csv(rows: list[dict], out_csv: Path) -> None:
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["ts_utc", "ea", "ea_id", "verdict", "exit_code", "reason"])
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in w.fieldnames})


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dispatch-state", default=str(DEFAULT_DISPATCH_STATE))
    ap.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR))
    ap.add_argument("--json", action="store_true", help="Emit JSON summary")
    ap.add_argument("--dry-run", action="store_true", help="Do not execute verifier")
    args = ap.parse_args()

    dispatch_state_path = Path(args.dispatch_state)
    out_dir = Path(args.out_dir)
    ts = utc_now_compact()

    eas = discover_eas(dispatch_state_path)
    rows: list[dict] = []
    for ea in eas:
        base = {
            "ts_utc": datetime.now(timezone.utc).isoformat(),
            "ea": ea,
            "ea_id": _normalize_ea_numeric_id(ea),
        }
        if args.dry_run:
            rows.append({**base, "verdict": "DRY_RUN", "exit_code": 0, "reason": "not_executed"})
            continue
        result = verify_ea(ea)
        rows.append({**base, "verdict": result["verdict"], "exit_code": result["exit_code"], "reason": result["reason"]})

    out_csv = out_dir / f"ghost_build_reconciler_{ts}.csv"
    write_csv(rows, out_csv)

    summary = {
        "status": "ok",
        "dispatch_state": str(dispatch_state_path),
        "out_csv": str(out_csv),
        "ea_count": len(eas),
        "fail_count": sum(1 for r in rows if str(r.get("verdict")) != "PASS"),
    }
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
