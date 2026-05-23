"""Q06 — Stress HARSH runner.

Per Vault Q06 spec:
  Slippage: 5 pips
  Spread:   × 3 broker baseline
  Commission: × 3 baseline (FW2/FW5 multiplier)
  Trade-rejection: 10% (via FW2 hook qm_stress_reject_probability=0.10)
  Window: full available history per symbol
  Verdict: PF > 1.0 AND DD < 15%

Same shape as Q05 but with the HARSH stress level. Trade-rejection is
applied inside the EA via the FW2 hook reading qm_stress_reject_probability
from the setfile (set to 0.10 by gen_stress_setfile.py --level HARSH).
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json
from framework.scripts.q05_stress_medium import (
    _parse_pf_dd_trades,
    PF_FLOOR, DD_PCT_MAX, STARTING_EQUITY,
)

GATE_NAME = "Q06"
LEVEL = "HARSH"


def gen_harsh_setfile_for(baseline: Path) -> Path:
    repo_root = Path(__file__).resolve().parents[2]
    gen_script = repo_root / "framework" / "scripts" / "gen_stress_setfile.py"
    args = [sys.executable, str(gen_script), str(baseline),
            "--level", LEVEL, "--in-place"]
    proc = subprocess.run(args, capture_output=True, text=True, timeout=30)
    if proc.returncode != 0:
        raise RuntimeError(f"gen_stress_setfile HARSH failed: {proc.stderr or proc.stdout}")
    stem = baseline.stem
    if stem.endswith("_backtest"):
        stem = stem[: -len("_backtest")]
    return baseline.with_name(f"{stem}_q06_stress_harsh.set")


def run_harsh_backtest(*, ea_id: int, ea_expert: str, symbol: str,
                        setfile: Path, terminal: str,
                        report_root: Path, timeout_sec: int = 2400) -> dict:
    """Q06 timeout is longer than Q05 — 10% trade rejection may slightly
    increase retry overhead on the EA side, though the rejection itself
    short-circuits before OrderSend so the impact is small."""
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", "0",
        "-Terminal", terminal,
        "-Period", "H1",
        "-DispatchSubGateHash", f"q06_{ea_id}_{symbol.replace('.', '_')}",
        "-DispatchPhase", "Q06",
        "-DispatchVersion", "q06_stress_harsh",
        "-Runs", "1",
        "-MinTrades", "20",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    proc = subprocess.run(args, capture_output=True, text=True,
                          timeout=timeout_sec, creationflags=creationflags)
    sym_clean = symbol.replace(".", "_")
    summary = report_root / f"QM5_{ea_id}" / "Q06" / sym_clean / "summary.json"
    pf, dd_money, trades = _parse_pf_dd_trades(summary)
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None

    if pf is None or dd_money is None:
        verdict, reason = "INVALID", "missing_pf_or_dd_in_summary"
    elif pf <= PF_FLOOR:
        verdict, reason = "FAIL", f"pf_below_floor:pf={pf:.3f}:floor={PF_FLOOR}"
    elif dd_pct > DD_PCT_MAX:
        verdict, reason = "FAIL", f"dd_above_ceiling:dd_pct={dd_pct:.2f}:max={DD_PCT_MAX}"
    else:
        verdict, reason = "PASS", f"pf={pf:.3f}:dd_pct={dd_pct:.2f}:stress=HARSH"

    return {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "symbol": symbol,
        "stress_level": LEVEL,
        "rejection_probability": 0.10,
        "verdict": verdict,
        "reason": reason,
        "pf": pf,
        "dd_money": dd_money,
        "dd_pct": dd_pct,
        "trades": trades,
        "exit_code": proc.returncode,
        "summary_path": str(summary) if summary.exists() else None,
        "generated_at_utc": utc_now_iso(),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Q06 Stress HARSH runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True)
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--timeout-sec", type=int, default=2400)
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))

    harsh_set = gen_harsh_setfile_for(args.baseline_setfile)
    print(f"Q06 HARSH: generated stress setfile {harsh_set.name}  (reject_prob=0.10)")

    res = run_harsh_backtest(
        ea_id=ea_id, ea_expert=args.ea, symbol=args.symbol,
        setfile=harsh_set, terminal=args.terminal,
        report_root=args.report_root, timeout_sec=args.timeout_sec,
    )

    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q06" / args.symbol.replace(".", "_"))
    write_json(out_dir / "aggregate.json", res)
    print(f"Q06 {args.ea} {args.symbol}: {res['verdict']}  pf={res['pf']}  dd_pct={res['dd_pct']}")
    return 0 if res["verdict"] == "PASS" else (1 if res["verdict"] == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
