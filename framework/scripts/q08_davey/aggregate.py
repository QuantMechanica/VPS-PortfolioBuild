"""Q08 Davey aggregator — run all 10 sub-gates, AND-combine verdicts, write report.

Output:
    D:/QM/reports/pipeline/QM5_<id>/Q08/<symbol>/aggregate.json
    D:/QM/reports/pipeline/QM5_<id>/Q08/<symbol>/8_<N>_<name>.json (per sub-gate)

The combined verdict is AND across all 10 sub-gates. Any INVALID gate
returns INVALID at the aggregate level (separates infrastructure issues
from genuine FAILs).

Usage:
    python -m framework.scripts.q08_davey.aggregate \
        --ea-id 1056 --symbol NDX.DWX \
        --log D:/QM/strategy_farm/.../QM5_1056_NDX_DWX.log

    # Or batch — discover all Q07-PASS pairs and run Q08 on each
    python -m framework.scripts.q08_davey.aggregate --discover
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

# Allow running both as a module and as a script
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from framework.scripts.q08_davey import (
        common, sub_8_1_correlation, sub_8_2_dsr_mc_fdr, sub_8_3_tail_dependence,
        sub_8_4_seasonal, sub_8_5_neighborhood, sub_8_6_chopping_block,
        sub_8_7_pbo, sub_8_8_edge_decay, sub_8_9_runs_test, sub_8_10_regime_crisis,
    )
else:
    from . import (
        common, sub_8_1_correlation, sub_8_2_dsr_mc_fdr, sub_8_3_tail_dependence,
        sub_8_4_seasonal, sub_8_5_neighborhood, sub_8_6_chopping_block,
        sub_8_7_pbo, sub_8_8_edge_decay, sub_8_9_runs_test, sub_8_10_regime_crisis,
    )

# Execution order matches the Vault Q08 spec numbering.
SUB_GATES = [
    ("8.1",  sub_8_1_correlation),
    ("8.2",  sub_8_2_dsr_mc_fdr),
    ("8.3",  sub_8_3_tail_dependence),
    ("8.4",  sub_8_4_seasonal),
    ("8.5",  sub_8_5_neighborhood),
    ("8.6",  sub_8_6_chopping_block),
    ("8.7",  sub_8_7_pbo),
    ("8.8",  sub_8_8_edge_decay),
    ("8.9",  sub_8_9_runs_test),
    ("8.10", sub_8_10_regime_crisis),
]


def _ensure_sub_gate_inputs(ea_id: int, symbol: str) -> dict:
    """PT4 2026-05-23 — pre-invoke Q08.5 + Q08.7 supporting runners if their
    output artifacts don't yet exist. Sub-gates 8.5 (neighborhood) and 8.7
    (PBO) read perturbations.json / scores.csv produced by separate runners.
    Without those files the sub-gates return INVALID; this pre-pass tries
    to populate them so the gate can give a real verdict.

    Both runners are best-effort: failure here is logged but doesn't abort
    the aggregator. The sub-gates handle missing files gracefully.
    """
    import subprocess as _sp
    sym_clean = symbol.replace(".", "_")
    repo_root = Path(__file__).resolve().parents[3]
    py = sys.executable

    ran: dict[str, dict] = {}

    perturbations = (Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/"
                          f"neighborhood/{sym_clean}/perturbations.json"))
    if not perturbations.exists():
        # Best-effort dispatch — requires a baseline setfile to be discoverable.
        # We let the runner self-resolve from --ea + --symbol via Q03 plateau
        # pick lookup; it'll log SKIP and exit non-zero if pre-reqs missing.
        baseline = _guess_baseline_setfile(repo_root, ea_id, symbol)
        if baseline is not None:
            try:
                proc = _sp.run([
                    py, str(repo_root / "framework" / "scripts" /
                            "q08_5_neighborhood_runner.py"),
                    "--ea", f"QM5_{ea_id}",
                    "--symbol", symbol,
                    "--baseline-setfile", str(baseline),
                ], capture_output=True, text=True, timeout=1800)
                ran["8_5_neighborhood"] = {
                    "exit_code": proc.returncode,
                    "artifact_now_exists": perturbations.exists(),
                }
            except _sp.TimeoutExpired:
                ran["8_5_neighborhood"] = {"exit_code": -1, "error": "timeout"}
            except Exception as exc:
                ran["8_5_neighborhood"] = {"exit_code": -1, "error": repr(exc)}
        else:
            ran["8_5_neighborhood"] = {"skipped": "no_baseline_setfile_resolvable"}

    pbo_scores = Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/pbo/"
                      f"{sym_clean}/scores.csv")
    if not pbo_scores.exists():
        try:
            proc = _sp.run([
                py, str(repo_root / "framework" / "scripts" /
                        "q08_7_pbo_runner.py"),
                "--ea", f"QM5_{ea_id}",
                "--symbol", symbol,
            ], capture_output=True, text=True, timeout=600)
            ran["8_7_pbo"] = {
                "exit_code": proc.returncode,
                "artifact_now_exists": pbo_scores.exists(),
            }
        except _sp.TimeoutExpired:
            ran["8_7_pbo"] = {"exit_code": -1, "error": "timeout"}
        except Exception as exc:
            ran["8_7_pbo"] = {"exit_code": -1, "error": repr(exc)}

    return ran


def _guess_baseline_setfile(repo_root: Path, ea_id: int, symbol: str) -> Path | None:
    """Find a baseline backtest setfile for an EA — used to feed the
    neighborhood runner when we can't otherwise resolve the Q03 pick."""
    ea_dirs = [d for d in (repo_root / "framework" / "EAs").iterdir()
               if d.is_dir() and d.name.startswith(f"QM5_{ea_id}_")]
    if not ea_dirs:
        return None
    sets_dir = ea_dirs[0] / "sets"
    if not sets_dir.exists():
        return None
    # Match the symbol; prefer baseline setfiles (not stress / not seed / not perturb)
    sym_token = symbol
    for f in sets_dir.glob("*_backtest.set"):
        if sym_token in f.name and not any(s in f.name for s in
                                            ("stress", "_seed", "_perturb")):
            return f
    return None


def run_all(ea_id: int, symbol: str, log_path: Path,
            portfolio: list[dict] | None = None,
            out_dir: Path | None = None) -> dict:
    log_path = Path(log_path)
    trades = common.load_trades_from_log(log_path)
    equity_stream = common.load_equity_stream(log_path)

    # PT4 — best-effort pre-run of Q08.5 + Q08.7 supporting runners
    sub_gate_input_runs = _ensure_sub_gate_inputs(ea_id, symbol)

    sub_results: list[dict] = []
    for label, mod in SUB_GATES:
        try:
            res = mod.run(
                trades=trades,
                equity_stream=equity_stream,
                portfolio=portfolio,
                ea_id=ea_id,
                symbol=symbol,
            )
        except Exception as exc:
            res = common.make_result(
                f"{label}_{mod.GATE_NAME if hasattr(mod, 'GATE_NAME') else 'unknown'}",
                "INVALID",
                value=None, threshold=None,
                detail=f"sub_gate_exception:{type(exc).__name__}:{exc}",
            )
        sub_results.append(res)

    # AND-combine: PASS only if all 10 PASS.
    statuses = [r["status"] for r in sub_results]
    if "FAIL" in statuses:
        overall = "FAIL"
    elif "INVALID" in statuses:
        overall = "INVALID"  # any infrastructure-missing → can't decide
    else:
        overall = "PASS"

    aggregate = {
        "ea_id": ea_id,
        "symbol": symbol,
        "phase": "Q08",
        "verdict": overall,
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "n_trades": len(trades),
        "n_equity_snapshots": len(equity_stream),
        "sub_gates": sub_results,
        "sub_gate_input_runs": sub_gate_input_runs,
        "summary": {
            "n_pass":    sum(1 for r in sub_results if r["status"] == "PASS"),
            "n_fail":    sum(1 for r in sub_results if r["status"] == "FAIL"),
            "n_invalid": sum(1 for r in sub_results if r["status"] == "INVALID"),
        },
    }

    if out_dir is None:
        sym_clean = symbol.replace(".", "_")
        out_dir = Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/{sym_clean}")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "aggregate.json").write_text(
        json.dumps(aggregate, indent=2, default=str), encoding="utf-8"
    )
    for r in sub_results:
        slug = r["name"].replace(".", "_")
        (out_dir / f"{slug}.json").write_text(
            json.dumps(r, indent=2, default=str), encoding="utf-8"
        )

    return aggregate


def _print_summary(agg: dict) -> None:
    print(f"\nQ08 · QM5_{agg['ea_id']} {agg['symbol']}  ->  {agg['verdict']}")
    print(f"    trades={agg['n_trades']}  equity_snaps={agg['n_equity_snapshots']}")
    for r in agg["sub_gates"]:
        flag = {"PASS": "OK", "FAIL": "X ", "INVALID": "? "}.get(r["status"], "  ")
        val = r.get("value")
        thr = r.get("threshold")
        print(f"    {flag} {r['name']:30s}  value={val}  threshold={thr}")
        print(f"        {r['detail']}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Q08 Davey aggregator (10 sub-gates)")
    ap.add_argument("--ea-id", type=int, help="EA id (with --symbol + --log)")
    ap.add_argument("--symbol", help="symbol e.g. NDX.DWX")
    ap.add_argument("--log", type=Path, help="path to EA JSON-lines log")
    ap.add_argument("--out-dir", type=Path, help="override output dir")
    ap.add_argument("--discover", action="store_true",
                    help="walk Q07-PASS pairs in farm DB and run Q08 on each (TODO)")
    args = ap.parse_args()

    if args.discover:
        print("--discover not yet wired (needs farm DB query of Q07 PASS pairs)", file=sys.stderr)
        return 2

    if not (args.ea_id and args.symbol and args.log):
        ap.print_usage(sys.stderr)
        return 2

    agg = run_all(args.ea_id, args.symbol, args.log, out_dir=args.out_dir)
    _print_summary(agg)
    return 0 if agg["verdict"] == "PASS" else (1 if agg["verdict"] == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
