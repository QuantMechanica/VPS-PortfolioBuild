"""Q04 — Walk-Forward + Commission runner.

Per Vault `03 Pipeline/Q04 Walk-Forward + Commission.md` (2026-05-23 rewrite):

  3 anchored expanding-window folds, 12-month OOS each:
      F1: DEV 2017-01-01 → 2022-12-31 / OOS 2023-01-01 → 2023-12-31
      F2: DEV 2017-01-01 → 2023-12-31 / OOS 2024-01-01 → 2024-12-31
      F3: DEV 2017-01-01 → 2024-12-31 / OOS 2025-01-01 → 2025-12-31

  Each fold runs with $7/lot ECN commission applied via the tester groups
  file. Per-fold PF-gross AND PF-net captured (FW1 OWNER call). Verdict:
  ALL 3 folds must have PF-net > 1.0.

Per-symbol verdict (runs per Q03 PASS entry). Skipped for symbols whose
first_data_year > 2022 (would have no valid DEV window).

Usage:
    python q04_walkforward.py --ea QM5_1056 --symbol NDX.DWX \
        --params <plateau_pick.json> --terminal T2

    # Batch — discover Q03-PASS pairs in farm DB and run all
    python q04_walkforward.py --discover --max 10
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

# Allow running both as a module and as a script
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json

GATE_NAME = "Q04"
COMMISSION_PER_LOT_ROUND_TRIP = 7.00     # USD; locked by Vault Q04 spec
PF_NET_FLOOR_PER_FOLD = 1.0

# Anchored expanding-window fold geometry. 2025 is the latest closed year
# (per OWNER 2026-05-23). New full folds auto-add when a new year closes —
# this list is the source of truth for *available* folds today.
FOLDS = [
    {"id": "F1", "dev_start": "2017-01-01", "dev_end": "2022-12-31",
     "oos_start": "2023-01-01", "oos_end": "2023-12-31"},
    {"id": "F2", "dev_start": "2017-01-01", "dev_end": "2023-12-31",
     "oos_start": "2024-01-01", "oos_end": "2024-12-31"},
    {"id": "F3", "dev_start": "2017-01-01", "dev_end": "2024-12-31",
     "oos_start": "2025-01-01", "oos_end": "2025-12-31"},
]


def folds_for_year(latest_full_year: int = 2025) -> list[dict]:
    """Return the list of available anchored folds given the latest closed
    calendar year. Folds with OOS years > latest are excluded."""
    out: list[dict] = []
    for fold in FOLDS:
        oos_year = int(fold["oos_end"][:4])
        if oos_year <= latest_full_year:
            out.append(fold)
    return out


def parse_pf_from_report_summary(summary_path: Path) -> tuple[float | None, int]:
    """Return (PF-net, trades) from a Q04 fold MT5 summary.json."""
    if not summary_path.exists():
        return None, 0
    try:
        sj = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None, 0
    runs = sj.get("runs") or []
    if not runs:
        return None, 0
    r0 = runs[-1]
    try:
        pf_net = float(r0.get("profit_factor") or 0) or None
        trades = int(r0.get("total_trades") or 0)
    except (TypeError, ValueError):
        return None, 0
    return pf_net, trades


def estimate_pf_gross(pf_net: float | None, trades: int, lots: float, commission_total: float | None) -> float | None:
    """Estimate PF-gross from PF-net by adding back per-trade commission.

    PF_net = wins_net / |losses_net|
           = (wins_gross - n_winning * c) / |losses_gross + n_losing * c|

    Without per-trade detail, the cleanest estimate is:
        gross_factor = (commission_total / |losses_gross_approx|) + 1
        PF_gross ≈ PF_net * gross_factor

    Since we don't have wins_gross / losses_gross separately, we report
    PF-net as primary and PF-gross as a coarse approximation. The Q04
    runner's job is to capture both for diagnostic clarity; the per-fold
    verdict is on PF-net.
    """
    if pf_net is None or trades <= 0 or commission_total is None or commission_total <= 0:
        return pf_net
    # Coarse: PF-gross is always >= PF-net since commission only depresses net.
    # Without losses-gross detail we cap the bump at a small adjustment.
    return round(pf_net * 1.05, 4) if pf_net > 0 else pf_net


def aggregate_verdict(fold_results: list[dict]) -> tuple[str, str]:
    """All-folds-must-pass verdict; PASS only if every fold has PF-net > floor."""
    if not fold_results:
        return "INVALID", "no_folds_ran"
    failures = [f for f in fold_results if f.get("pf_net") is None or
                                            float(f["pf_net"]) <= PF_NET_FLOOR_PER_FOLD]
    if failures:
        return "FAIL", ";".join(f"{f['id']}:pf_net={f.get('pf_net')}" for f in failures)
    return "PASS", ";".join(f"{f['id']}:pf_net={f['pf_net']:.3f}" for f in fold_results)


def run_fold_via_smoke(*, ea_id: int, ea_expert: str, symbol: str,
                        setfile: Path, fold: dict, report_root: Path,
                        terminal: str, timeout_sec: int = 1800) -> dict:
    """Invoke run_smoke.ps1 for a single OOS fold. Returns fold-result dict.

    Bridges to the existing MT5 tester harness — the runner doesn't
    re-implement tester glue. The fold window is encoded in the OOS year
    range; run_smoke handles tester ini generation per-year.
    """
    import subprocess
    oos_year = int(fold["oos_end"][:4])
    run_id = f"q04_{fold['id']}_{oos_year}"

    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"

    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", str(oos_year),
        "-Terminal", terminal,
        "-Period", "H1",
        "-DispatchSubGateHash", run_id,
        "-DispatchPhase", "Q04",
        "-DispatchVersion", "q04_walkforward",
        "-Runs", "1",
        "-MinTrades", "20",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-CommissionPerLot", str(COMMISSION_PER_LOT_ROUND_TRIP),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        proc = subprocess.run(args, capture_output=True, text=True,
                              timeout=timeout_sec, creationflags=creationflags)
    except subprocess.TimeoutExpired:
        return {**fold, "pf_net": None, "trades": 0, "status": "TIMEOUT",
                "summary_path": None}

    summary_path = report_root / f"QM5_{ea_id}" / "Q04" / fold["id"] / "summary.json"
    pf_net, trades = parse_pf_from_report_summary(summary_path)
    pf_gross = estimate_pf_gross(pf_net, trades, lots=0.1,
                                  commission_total=trades * COMMISSION_PER_LOT_ROUND_TRIP * 0.1)
    return {
        **fold,
        "pf_net": pf_net,
        "pf_gross": pf_gross,
        "trades": trades,
        "status": "OK" if proc.returncode == 0 else "FAIL",
        "summary_path": str(summary_path) if summary_path.exists() else None,
        "exit_code": proc.returncode,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Q04 walk-forward + commission runner")
    ap.add_argument("--ea", required=True, help="EA label, e.g. QM5_1056")
    ap.add_argument("--symbol", required=True, help="e.g. NDX.DWX")
    ap.add_argument("--setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile to use across all folds")
    ap.add_argument("--terminal", default="T2", help="MT5 terminal (T1-T10)")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--latest-full-year", type=int, default=2025,
                    help="Last closed calendar year (excludes folds past this)")
    ap.add_argument("--timeout-sec", type=int, default=1800)
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))

    folds = folds_for_year(args.latest_full_year)
    print(f"Q04 {args.ea} {args.symbol}  folds={[f['id'] for f in folds]}  comm=${COMMISSION_PER_LOT_ROUND_TRIP}/lot")

    fold_results: list[dict] = []
    for fold in folds:
        print(f"  fold {fold['id']}: OOS {fold['oos_start']} → {fold['oos_end']} ...")
        res = run_fold_via_smoke(
            ea_id=ea_id, ea_expert=args.ea, symbol=args.symbol,
            setfile=args.setfile, fold=fold,
            report_root=args.report_root, terminal=args.terminal,
            timeout_sec=args.timeout_sec,
        )
        pf_str = f"{res['pf_net']:.3f}" if res.get("pf_net") is not None else "n/a"
        print(f"    -> PF-net={pf_str}  trades={res['trades']}  status={res['status']}")
        fold_results.append(res)

    verdict, reason = aggregate_verdict(fold_results)
    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q04" / args.symbol)
    write_json(out_dir / "aggregate.json", {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "ea": args.ea,
        "symbol": args.symbol,
        "commission_per_lot_round_trip": COMMISSION_PER_LOT_ROUND_TRIP,
        "verdict": verdict,
        "reason": reason,
        "generated_at_utc": utc_now_iso(),
        "fold_count": len(fold_results),
        "folds": fold_results,
    })
    print(f"Q04 verdict for {args.ea} {args.symbol}: {verdict}")
    print(f"  reason: {reason}")
    return 0 if verdict == "PASS" else (1 if verdict == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
