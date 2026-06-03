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
import re
import sys
import time
from pathlib import Path

# Allow running both as a module and as a script
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.strategy_farm.portfolio import commission
    from framework.scripts.q08_davey import (
        common, sub_8_1_correlation, sub_8_2_dsr_mc_fdr, sub_8_3_tail_dependence,
        sub_8_4_seasonal, sub_8_5_neighborhood, sub_8_6_chopping_block,
        sub_8_7_pbo, sub_8_8_edge_decay, sub_8_9_runs_test, sub_8_10_regime_crisis,
    )
else:
    from tools.strategy_farm.portfolio import commission
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

N_SEASON = 3  # max CONSECUTIVE losing calendar months still 'soft' (OWNER: "am Stück")
CHOP_SOFT = 0.90
PBO_HARD = 55.0
LOW_SAMPLE_DETAIL_TOKENS = (
    "insufficient_trade_count",
    "insufficient_daily_returns",
    "insufficient_month_coverage",
    "insufficient_history",
    "insufficient_candidate_history",
    "months_with_no_trades",
    "no_trades",
    "regime_input_missing",
    "regime_join_incomplete",
    "regimes_with_zero_trades",
)


def _ensure_sub_gate_inputs(ea_id: int, symbol: str, terminal: str | None = None) -> dict:
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
                    "--terminal", terminal or "T2",
                ], capture_output=True, text=True, timeout=1800)
                ran["8_5_neighborhood"] = {
                    "exit_code": proc.returncode,
                    "artifact_now_exists": perturbations.exists(),
                    "stdout_tail": proc.stdout[-1000:],
                    "stderr_tail": proc.stderr[-1000:],
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
                "stdout_tail": proc.stdout[-1000:],
                "stderr_tail": proc.stderr[-1000:],
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


def _common_q08_trade_log(ea_id: int, symbol: str) -> Path:
    """Deterministic Common\\Files path the recompiled EA writes its per-trade stream to
    (the tester writes the EA's own log to the agent sandbox, which Q08 can't find)."""
    return (Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files")
            / "QM" / "q08_trades" / f"{ea_id}_{symbol.replace('.', '_')}.jsonl")


def _latest_structured_qm_log(ea_id: int, symbol: str, terminal: str | None = None) -> Path | None:
    """Find the fullest tester-agent QM log carrying structured framework events.

    `farmctl` passes the terminal MQL5 Logs path, but Strategy Tester agents write
    QM_Logger output under Tester/Agent-*/MQL5/Files/QM. The Common\\Files stream
    only carries TRADE_CLOSED rows, so Q08.1/8.3/8.10 need this recovery path for
    EQUITY_SNAPSHOT input.
    """
    terminals = [terminal] if terminal else []
    terminals.extend(f"T{i}" for i in range(1, 11) if f"T{i}" not in terminals)
    symbol_token = f'"symbol":"{symbol}"'

    candidates: list[Path] = []
    for term in terminals:
        if not term:
            continue
        base = Path("D:/QM/mt5") / term / "Tester"
        if not base.exists():
            continue
        candidates.extend(base.glob(f"Agent-*/MQL5/Files/QM/QM5_{ea_id}_*.log"))

    best: tuple[int, float, Path] | None = None
    for path in candidates:
        count = 0
        try:
            with path.open(encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    if "EQUITY_SNAPSHOT" in line and symbol_token in line:
                        count += 1
        except OSError:
            continue
        if count <= 0:
            continue
        score = (count, path.stat().st_mtime, path)
        if best is None or score[:2] > best[:2]:
            best = score
    return best[2] if best is not None else None


def _run_baseline_for_trades(ea_id: int, symbol: str, terminal: str | None) -> dict:
    """Run ONE clean full-history backtest so the EA emits its TRADE_CLOSED stream to
    Common\\Files. Q08 itself doesn't otherwise run a backtest, so without this the trade
    log never exists for the aggregator to read."""
    import subprocess as _sp
    import re as _re
    repo_root = Path(__file__).resolve().parents[3]
    baseline = _guess_baseline_setfile(repo_root, ea_id, symbol)
    if baseline is None:
        return {"skipped": "no_baseline_setfile"}
    ea_dirs = [d for d in (repo_root / "framework" / "EAs").iterdir()
               if d.is_dir() and d.name.startswith(f"QM5_{ea_id}_")]
    if not ea_dirs:
        return {"skipped": "no_ea_dir"}
    expert = f"QM\\{ea_dirs[0].name}"
    m = _re.search(r"_(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)_backtest", baseline.name)
    period = m.group(1) if m else "H1"
    report_root = Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/_baseline")
    args = [
        "pwsh.exe", "-NoProfile", "-File",
        str(repo_root / "framework" / "scripts" / "run_smoke.ps1"),
        "-EAId", str(ea_id), "-Expert", expert, "-Symbol", symbol,
        "-Year", "2025", "-FromDate", "2017.01.01", "-ToDate", "2025.12.31",
        "-Terminal", terminal or "T1", "-Period", period,
        "-Runs", "1", "-MinTrades", "1", "-Model", "4",
        "-SetFile", str(baseline), "-ReportRoot", str(report_root),
        "-DispatchPhase", "Q08", "-DispatchVersion", "q08_baseline",
        "-DispatchSubGateHash", f"q08base_{ea_id}_{symbol.replace('.', '_')}",
        "-TimeoutSeconds", "2400",
    ]
    flags = 0x08000000 if sys.platform == "win32" else 0
    try:
        p = _sp.run(args, capture_output=True, text=True, timeout=2500, creationflags=flags)
        summary = _latest_baseline_summary(report_root, ea_id, wait_seconds=10)
        out = {"exit_code": p.returncode, "expert": expert, "period": period}
        if summary is not None:
            out.update(_baseline_report_metadata(summary))
        structured_log = _latest_structured_qm_log(ea_id, symbol, terminal)
        if structured_log is not None:
            out["structured_log_path"] = str(structured_log)
        return out
    except Exception as exc:
        return {"error": repr(exc)}


def _latest_baseline_summary(report_root: Path, ea_id: int, wait_seconds: int = 0) -> Path | None:
    base = report_root / f"QM5_{ea_id}"
    deadline = time.time() + max(0, wait_seconds)
    while True:
        if base.exists():
            summaries = sorted(base.glob("*/summary.json"), key=lambda p: p.stat().st_mtime, reverse=True)
            if summaries:
                return summaries[0]
        if time.time() >= deadline:
            return None
        time.sleep(1)


def _baseline_report_metadata(summary_path: Path) -> dict:
    try:
        data = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {"baseline_summary_path": str(summary_path)}
    runs = data.get("runs") or []
    run = runs[0] if runs else {}
    report_path = run.get("report_canonical_path") or run.get("report_source_path")
    return {
        "baseline_summary_path": str(summary_path),
        "baseline_result": data.get("result"),
        "baseline_reason_classes": data.get("reason_classes"),
        "baseline_report_path": report_path,
        "baseline_total_trades": run.get("total_trades"),
        "baseline_profit_factor": run.get("profit_factor"),
    }


def _float_or_none(value) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _gross_before_commission(trade: dict) -> float:
    profit = _float_or_none(trade.get("profit"))
    swap = _float_or_none(trade.get("swap")) or 0.0
    if profit is not None:
        return profit + swap

    net = _float_or_none(trade.get("net")) or 0.0
    broker_commission = _float_or_none(trade.get("commission"))
    if broker_commission is not None:
        return net - broker_commission
    return net


def _apply_worst_case_commission(trades: list[dict], fallback_symbol: str) -> tuple[list[dict], dict]:
    model = commission.load_model()
    adjusted: list[dict] = []
    total_cost = 0.0

    for trade in trades:
        row = dict(trade)
        trade_symbol = str(row.get("symbol") or fallback_symbol)
        volume = _float_or_none(row.get("volume")) or 0.0
        notional = _float_or_none(row.get("notional"))
        cost = model.cost_round_trip(trade_symbol, volume, notional)
        total_cost += cost

        original_net = _float_or_none(row.get("net", row.get("profit", 0))) or 0.0
        row["net_original"] = original_net
        row["commission_model_cost"] = cost
        row["commission_basis"] = "worst_case_dxz_ftmo"
        row["net"] = _gross_before_commission(row) - cost
        adjusted.append(row)

    model_info = commission.describe_model(model)
    return adjusted, {
        "commission_basis": "worst_case_dxz_ftmo",
        "commission_model": model_info,
        "commission_total": round(total_cost, 6),
        "degraded_symbols": model_info["degraded_symbols"],
    }


def _detail_text(sub_gate_result: dict) -> str:
    return str(sub_gate_result.get("detail") or "").strip()


def _result_name(sub_gate_result: dict) -> str:
    return str(sub_gate_result.get("name") or "").strip().lower()


def _float_from_detail(detail: str, pattern: str) -> float | None:
    match = re.search(pattern, detail)
    if not match:
        return None
    try:
        return float(match.group(1))
    except (TypeError, ValueError):
        return None


def _max_consecutive_losing_months(sub_gate_result: dict) -> int | None:
    """Longest run of CONSECUTIVE losing calendar months (OWNER: 'am Stück').
    4 scattered losing months are not a sustained drawdown; 4 in a row are."""
    evidence = sub_gate_result.get("evidence") or {}
    losing_months = evidence.get("losing_months")
    if not isinstance(losing_months, list):
        detail = _detail_text(sub_gate_result)
        if "losing_months:" not in detail:
            return None
        tail = detail.split("losing_months:", 1)[1]
        losing_months = [int(x) for x in re.findall(r"\b\d{1,2}\b", tail)]
    months = sorted({int(m) for m in losing_months if 1 <= int(m) <= 12})
    if not months:
        return 0
    best = run = 1
    for i in range(1, len(months)):
        run = run + 1 if months[i] == months[i - 1] + 1 else 1
        best = max(best, run)
    return best


def _classify_fail(sub_gate_result: dict) -> str:
    """Classify a non-PASS Q08 sub-gate result for the portfolio-rescue track."""
    detail = _detail_text(sub_gate_result)
    detail_lower = detail.lower()
    name = _result_name(sub_gate_result)

    if any(token in detail_lower for token in LOW_SAMPLE_DETAIL_TOKENS):
        return "LOW_SAMPLE"

    if name.startswith("8.4"):
        streak = _max_consecutive_losing_months(sub_gate_result)
        if streak is not None and streak <= N_SEASON:
            return "EDGE_SOFT"
        return "EDGE_HARD"

    if name.startswith("8.6"):
        pf_after = _float_from_detail(detail, r"pf_after_top\d+pct_removal=([-+]?\d+(?:\.\d+)?)")
        if pf_after is not None and CHOP_SOFT <= pf_after < 1.0:
            return "EDGE_SOFT"
        return "EDGE_HARD"

    if name.startswith("8.7"):
        pbo = _float_from_detail(detail, r"PBO=([-+]?\d+(?:\.\d+)?)%")
        if pbo is not None and 40.0 < pbo <= PBO_HARD:
            return "EDGE_SOFT"
        return "EDGE_HARD"

    return "EDGE_HARD"


def _net_profit_factor(trades: list[dict]) -> float | None:
    profits = [_float_or_none(t.get("net")) or 0.0 for t in trades]
    return common.profit_factor(profits)


def _aggregate_verdict(sub_results: list[dict], trades: list[dict] | None = None) -> tuple[str, dict[str, str]]:
    """Combine sub-gate statuses into PASS/FAIL_SOFT/FAIL_HARD/INVALID."""
    classification: dict[str, str] = {}
    hard = False
    soft = False
    invalid = False

    for result in sub_results:
        name = str(result.get("name") or "unknown")
        status = str(result.get("status") or "").upper()
        if status == "PASS":
            classification[name] = "PASS"
            continue
        if status == "INVALID" and not any(
            token in _detail_text(result).lower() for token in LOW_SAMPLE_DETAIL_TOKENS
        ):
            classification[name] = "INVALID"
            invalid = True
            continue
        tier = _classify_fail(result)
        classification[name] = tier
        if tier == "EDGE_HARD":
            hard = True
        else:
            soft = True

    pf = _net_profit_factor(trades or [])
    if pf is not None and pf < 1.0:
        classification["portfolio_net_pf"] = "EDGE_HARD"
        hard = True

    # HARD dominates: a definitive edge failure (e.g. PBO 88%, 4-consecutive losing
    # months) means the EA is not robust regardless of a single non-evaluable gate.
    # INVALID (genuine infra/join gap) only decides when no hard fail is present.
    if hard:
        return "FAIL_HARD", classification
    if invalid:
        return "INVALID", classification
    if soft:
        return "FAIL_SOFT", classification
    return "PASS", classification


def run_all(ea_id: int, symbol: str, log_path: Path,
            portfolio: list[dict] | None = None,
            out_dir: Path | None = None,
            terminal: str | None = None) -> dict:
    log_path = Path(log_path)
    trades = common.load_trades_from_log(log_path)
    equity_stream = common.load_equity_stream(log_path)
    if not equity_stream:
        structured_log = _latest_structured_qm_log(ea_id, symbol, terminal)
        if structured_log is not None:
            equity_stream = common.load_equity_stream(structured_log)
    # Tester writes the EA log to the agent sandbox, so the farmctl --log path is empty.
    # The recompiled EA also dumps a TRADE_CLOSED stream to Common\Files; read that, and
    # run a clean baseline backtest first if it's not there yet.
    baseline_run = None
    if not trades:
        common_log = _common_q08_trade_log(ea_id, symbol)
        # Always run a FRESH full-history baseline so Q08 evaluates a clean run, not a
        # stale per-fold log left by an earlier phase (which would undercount trades and
        # wrongly fail a higher-frequency strategy). Clear the stale log first.
        try:
            if common_log.exists():
                common_log.unlink()
        except OSError:
            pass
        baseline_run = _run_baseline_for_trades(ea_id, symbol, terminal)
        if baseline_run and not baseline_run.get("baseline_report_path"):
            retry_summary = _latest_baseline_summary(
                Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/_baseline"),
                ea_id,
                wait_seconds=5,
            )
            if retry_summary is not None:
                baseline_run.update(_baseline_report_metadata(retry_summary))
        trades = common.load_trades_from_log(common_log)
        equity_stream = common.load_equity_stream(common_log) or equity_stream
        structured_log = _latest_structured_qm_log(ea_id, symbol, terminal)
        if structured_log is not None:
            equity_stream = common.load_equity_stream(structured_log) or equity_stream
            if baseline_run is not None:
                baseline_run["structured_log_path"] = str(structured_log)
        if not trades and baseline_run and baseline_run.get("baseline_report_path"):
            trades = common.load_trades_from_mt5_report(Path(str(baseline_run["baseline_report_path"])))

    trades, commission_info = _apply_worst_case_commission(trades, symbol)

    # PT4 — best-effort pre-run of Q08.5 + Q08.7 supporting runners
    sub_gate_input_runs = _ensure_sub_gate_inputs(ea_id, symbol, terminal)

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

    # PASS only if all 10 PASS; otherwise split failures into hard/soft/infra.
    overall, verdict_classification = _aggregate_verdict(sub_results, trades)

    aggregate = {
        "ea_id": ea_id,
        "symbol": symbol,
        "phase": "Q08",
        "verdict": overall,
        "verdict_classification": verdict_classification,
        "verdict_calibration": {
            "N_SEASON": N_SEASON,
            "CHOP_SOFT": CHOP_SOFT,
            "PBO_HARD": PBO_HARD,
        },
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "n_trades": len(trades),
        "n_equity_snapshots": len(equity_stream),
        "commission_basis": commission_info["commission_basis"],
        "commission_model": commission_info["commission_model"],
        "commission_total": commission_info["commission_total"],
        "sub_gates": sub_results,
        "sub_gate_input_runs": sub_gate_input_runs,
        "baseline_run": baseline_run,
        "summary": {
            "n_pass":    sum(1 for r in sub_results if r["status"] == "PASS"),
            "n_fail":    sum(1 for r in sub_results if r["status"] == "FAIL"),
            "n_invalid": sum(1 for r in sub_results if r["status"] == "INVALID"),
        },
    }
    if commission_info["degraded_symbols"]:
        aggregate["degraded_symbols"] = commission_info["degraded_symbols"]

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
    ap.add_argument("--terminal", help="MT5 terminal (T1-T10) for the baseline trade-log backtest")
    ap.add_argument("--discover", action="store_true",
                    help="walk Q07-PASS pairs in farm DB and run Q08 on each (TODO)")
    args = ap.parse_args()

    if args.discover:
        print("--discover not yet wired (needs farm DB query of Q07 PASS pairs)", file=sys.stderr)
        return 2

    if not (args.ea_id and args.symbol and args.log):
        ap.print_usage(sys.stderr)
        return 2

    agg = run_all(args.ea_id, args.symbol, args.log, out_dir=args.out_dir, terminal=args.terminal)
    _print_summary(agg)
    return 0 if agg["verdict"] == "PASS" else (1 if agg["verdict"] == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
