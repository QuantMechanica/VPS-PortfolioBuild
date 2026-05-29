"""Q09 — News Impact Mode runner.

Per Vault Q09 spec (2-axis: temporal × compliance):
  Default: temporal=Mode 3 (pause 30min pre+post), compliance=DXZ.
  Optionally sweep all 7 temporal modes for diagnostics.

Per OWNER policy (Vault Q09 §"Default Policy"): pipeline does NOT stall
waiting for OWNER per-EA decision. The default is auto-applied, the full
sweep matrix surfaces in the EA detail page, OWNER can override from there.

Output:
  D:/QM/reports/pipeline/QM5_<id>/Q09/<symbol>/chosen_config.json
  D:/QM/reports/pipeline/QM5_<id>/Q09/<symbol>/matrix.csv  (per-mode metrics — when --sweep)

Usage:
    # Fast path — apply default Mode 3, no sweep
    python q09_news_mode.py --ea QM5_1056 --symbol NDX.DWX --baseline-setfile <path>

    # Diagnostic — sweep all 7 modes
    python q09_news_mode.py --ea QM5_1056 --symbol NDX.DWX --baseline-setfile <path> --sweep
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json

GATE_NAME = "Q09"

# Mode 3 (pause 30min pre + 30min post) is the default per Vault §"Default Policy".
DEFAULT_TEMPORAL = "QM_NEWS_TEMPORAL_PRE30_POST30"
DEFAULT_COMPLIANCE = "QM_NEWS_COMPLIANCE_DXZ"

# All 7 temporal modes — for diagnostic sweep mode.
ALL_TEMPORAL_MODES = [
    ("QM_NEWS_TEMPORAL_OFF", "0_off"),
    ("QM_NEWS_TEMPORAL_PRE30", "1_pre30"),
    ("QM_NEWS_TEMPORAL_PRE60", "2_pre60"),
    ("QM_NEWS_TEMPORAL_PRE30_POST30", "3_pre30_post30"),
    ("QM_NEWS_TEMPORAL_PRE60_POST60", "4_pre60_post60"),
    ("QM_NEWS_TEMPORAL_SKIP_DAY", "5_skip_day"),
    ("QM_NEWS_TEMPORAL_CLOSE_ALL_PRE", "6_close_all_pre"),
]


def write_news_mode_setfile(baseline: Path, temporal: str, compliance: str,
                             out_dir: Path) -> Path:
    """Patch qm_news_temporal + qm_news_compliance into a setfile copy."""
    text = baseline.read_text(encoding="utf-8", errors="replace")

    def patch(key: str, value: str) -> None:
        nonlocal text
        if re.search(rf"^{key}=", text, re.MULTILINE):
            text = re.sub(rf"^{key}=.*$", f"{key}={value}", text, flags=re.MULTILINE)
        else:
            text = text.rstrip() + f"\n{key}={value}\n"

    patch("qm_news_temporal", temporal)
    patch("qm_news_compliance", compliance)
    # Also ensure stress reject is reset to baseline (Q09 isn't a stress phase)
    patch("qm_stress_reject_probability", "0.0000")

    suffix_short = temporal.replace("QM_NEWS_TEMPORAL_", "").lower()
    out_path = out_dir / f"{baseline.stem}_q09_{suffix_short}.set"
    out_path.write_text(text, encoding="utf-8")
    return out_path


def main() -> int:
    ap = argparse.ArgumentParser(description="Q09 News Impact Mode runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile to be patched per news mode")
    ap.add_argument("--temporal", default=DEFAULT_TEMPORAL,
                    help="Chosen temporal mode (default = Mode 3 PRE30_POST30)")
    ap.add_argument("--compliance", default=DEFAULT_COMPLIANCE,
                    help="Chosen compliance profile (default = DXZ)")
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--sweep", action="store_true",
                    help="Sweep all 7 temporal modes for diagnostic matrix")
    ap.add_argument("--timeout-sec", type=int, default=2400)
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))
    sym_clean = args.symbol.replace(".", "_")

    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q09" / sym_clean)
    setfile_dir = ensure_dir(out_dir / "setfiles")

    # ---- Default-apply path (no sweep) ----
    if not args.sweep:
        chosen_set = write_news_mode_setfile(args.baseline_setfile,
                                              args.temporal, args.compliance,
                                              setfile_dir)
        chosen = {
            "phase": GATE_NAME,
            "ea_id": ea_id,
            "symbol": args.symbol,
            "verdict": "PASS",   # Q09 doesn't fail; it always picks a mode
            "reason": "default_applied_no_sweep",
            "chosen_temporal": args.temporal,
            "chosen_compliance": args.compliance,
            "chosen_setfile": str(chosen_set),
            "default_policy_applied": (args.temporal == DEFAULT_TEMPORAL and
                                        args.compliance == DEFAULT_COMPLIANCE),
            "owner_override": (args.temporal != DEFAULT_TEMPORAL or
                                args.compliance != DEFAULT_COMPLIANCE),
            "generated_at_utc": utc_now_iso(),
        }
        write_json(out_dir / "chosen_config.json", chosen)
        write_json(out_dir / "aggregate.json", chosen)
        print(f"Q09 {args.ea} {args.symbol}: PASS (default mode applied)")
        print(f"  temporal:   {args.temporal}")
        print(f"  compliance: {args.compliance}")
        print(f"  setfile:    {chosen_set.name}")
        return 0

    # ---- Diagnostic sweep path ----
    print(f"Q09 {args.ea} {args.symbol}: sweeping all {len(ALL_TEMPORAL_MODES)} temporal modes...")
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"

    matrix_rows: list[dict] = []
    for temporal, tag in ALL_TEMPORAL_MODES:
        mode_set = write_news_mode_setfile(args.baseline_setfile, temporal,
                                            args.compliance, setfile_dir)
        run_tag = f"q09_{tag}_{ea_id}_{sym_clean}"
        args_list = [
            "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
            "-EAId", str(ea_id),
            "-Expert", args.ea,
            "-Symbol", args.symbol,
            "-Year", "0",
            "-Terminal", args.terminal,
            "-Period", "H1",
            "-DispatchSubGateHash", run_tag,
            "-DispatchPhase", "Q09",
            "-DispatchVersion", f"q09_{tag}",
            "-Runs", "1",
            "-MinTrades", "20",
            "-Model", "4",
            "-SetFile", str(mode_set),
            "-ReportRoot", str(args.report_root),
            "-TimeoutSeconds", str(args.timeout_sec),
        ]
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        try:
            subprocess.run(args_list, capture_output=True, text=True,
                           timeout=args.timeout_sec, creationflags=creationflags)
        except subprocess.TimeoutExpired:
            matrix_rows.append({"temporal": temporal, "tag": tag,
                                 "pf": None, "trades": 0, "status": "TIMEOUT"})
            continue
        summary = (args.report_root / f"QM5_{ea_id}" / "Q09" /
                   sym_clean / run_tag / "summary.json")
        pf, trades = None, 0
        if summary.exists():
            try:
                sj = json.loads(summary.read_text(encoding="utf-8-sig"))
                runs = sj.get("runs") or []
                if runs:
                    r0 = runs[-1]
                    pf = float(r0.get("profit_factor") or 0) or None
                    trades = int(r0.get("total_trades") or 0)
            except Exception:
                pass
        matrix_rows.append({"temporal": temporal, "tag": tag,
                             "pf": pf, "trades": trades,
                             "status": "OK" if pf else "NO_DATA"})
        print(f"  {tag:18s} -> PF={pf} trades={trades}")

    # Write matrix CSV
    import csv as _csv
    matrix_path = out_dir / "matrix.csv"
    with matrix_path.open("w", encoding="utf-8", newline="") as fh:
        w = _csv.writer(fh)
        w.writerow(["temporal", "tag", "pf", "trades", "status"])
        for r in matrix_rows:
            w.writerow([r["temporal"], r["tag"], r["pf"] if r["pf"] is not None else "",
                        r["trades"], r["status"]])

    # Default-apply Mode 3 regardless of sweep results (OWNER policy)
    chosen_set = write_news_mode_setfile(args.baseline_setfile,
                                          args.temporal, args.compliance, setfile_dir)
    chosen = {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "symbol": args.symbol,
        "verdict": "PASS",
        "reason": "default_applied_after_diagnostic_sweep",
        "chosen_temporal": args.temporal,
        "chosen_compliance": args.compliance,
        "chosen_setfile": str(chosen_set),
        "diagnostic_sweep_matrix_csv": str(matrix_path),
        "n_modes_swept": len(matrix_rows),
        "generated_at_utc": utc_now_iso(),
    }
    write_json(out_dir / "chosen_config.json", chosen)
    write_json(out_dir / "aggregate.json", chosen)
    print(f"Q09 {args.ea} {args.symbol}: PASS (default mode applied after sweep)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
