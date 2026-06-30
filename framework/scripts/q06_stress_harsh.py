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
import json
import re
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import (ensure_dir, utc_now_iso, write_json,
                                            resolve_ea_expert_path, period_from_setfile,
                                            find_latest_summary, full_history_window)
from framework.scripts.q05_stress_medium import (
    _latest_report_metrics, _parse_pf_dd_trades, summary_invalid_reason, MIN_TRADES,
    PF_FLOOR, DD_PCT_MAX, STARTING_EQUITY, DEFAULT_TIMEOUT_SEC,
    RUNNER_HEADROOM_SEC, _basket_tester_overrides,
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


def _basket_logical_symbol(setfile: Path, symbol: str) -> str | None:
    manifest_path = Path(setfile).parent.parent / "basket_manifest.json"
    if not manifest_path.exists():
        return None
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    logical = str(manifest.get("logical_symbol") or "").strip()
    host = str(manifest.get("host_symbol") or "").strip()
    basket_symbols = {str(s).strip() for s in manifest.get("basket_symbols") or []}
    if logical and (symbol == logical or symbol == host or symbol in basket_symbols):
        return logical
    return None


def run_harsh_backtest(*, ea_id: int, ea_expert: str, symbol: str,
                        setfile: Path, terminal: str, period: str = "H1",
                        report_root: Path, timeout_sec: int = DEFAULT_TIMEOUT_SEC,
                        latest_full_year: int | None = None,
                        logical_symbol: str | None = None) -> dict:
    """Q06 timeout is longer than Q05 — 10% trade rejection may slightly
    increase retry overhead on the EA side, though the rejection itself
    short-circuits before OrderSend so the impact is small."""
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    history_year, history_from, history_to = full_history_window(latest_full_year)
    evidence_symbol = logical_symbol or _basket_logical_symbol(setfile, symbol) or symbol
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", history_year, "-FromDate", history_from, "-ToDate", history_to,
        "-Terminal", terminal,
        "-Period", period,
        "-DispatchSubGateHash", f"q06_{ea_id}_{symbol.replace('.', '_')}",
        "-DispatchPhase", "Q06",
        "-DispatchVersion", "q06_stress_harsh",
        "-Runs", "1",
        "-MinTrades", str(MIN_TRADES),
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    tester_currency, tester_deposit = _basket_tester_overrides(setfile)
    if tester_currency:
        args.extend(["-TesterCurrencyOverride", tester_currency])
    if tester_deposit:
        args.extend(["-TesterDepositOverride", str(tester_deposit)])
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    runner_timeout_sec = timeout_sec + RUNNER_HEADROOM_SEC
    timed_out = False
    timeout_detail = None
    try:
        proc = subprocess.run(args, capture_output=True, text=True,
                              timeout=runner_timeout_sec, creationflags=creationflags)
        exit_code = proc.returncode
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        timeout_detail = f"subprocess_timeout_after={exc.timeout}s"
        exit_code = 124
    sym_clean = symbol.replace(".", "_")
    summary = find_latest_summary(report_root)
    invalid_reason = summary_invalid_reason(summary) if summary else None
    report_metrics = None if summary else _latest_report_metrics(report_root)
    if summary:
        pf, dd_money, trades = _parse_pf_dd_trades(summary)
    elif report_metrics:
        pf = report_metrics["pf"]
        dd_money = report_metrics["dd_money"]
        trades = report_metrics["trades"]
    else:
        pf, dd_money, trades = None, None, 0
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None

    if summary is None and report_metrics is None:
        if timed_out:
            verdict = "INVALID"
            reason = f"timeout_expired:timeout_sec={timeout_sec}:runner_timeout_sec={runner_timeout_sec}"
        else:
            verdict, reason = "INVALID", "summary_missing"
    elif invalid_reason:
        verdict, reason = "INVALID", invalid_reason
    elif trades < MIN_TRADES:
        verdict, reason = "FAIL", f"trades_below_floor:trades={trades}:floor={MIN_TRADES}"
    elif pf is None:
        verdict, reason = "FAIL", f"missing_pf_in_summary:trades={trades}"
    elif dd_money is None:
        verdict, reason = "FAIL", f"missing_dd_in_summary:trades={trades}"
    elif pf <= PF_FLOOR:
        verdict, reason = "FAIL", f"pf_below_floor:pf={pf:.3f}:floor={PF_FLOOR}"
    elif dd_pct > DD_PCT_MAX:
        verdict, reason = "FAIL", f"dd_above_ceiling:dd_pct={dd_pct:.2f}:max={DD_PCT_MAX}"
    else:
        verdict, reason = "PASS", f"pf={pf:.3f}:dd_pct={dd_pct:.2f}:stress=HARSH"

    return {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "symbol": evidence_symbol,
        "runner_symbol": symbol,
        "stress_level": LEVEL,
        "rejection_probability": 0.10,
        "verdict": verdict,
        "reason": reason,
        "pf": pf,
        "dd_money": dd_money,
        "dd_pct": dd_pct,
        "trades": trades,
        "exit_code": exit_code,
        "timed_out": timed_out,
        "timeout_detail": timeout_detail,
        "timeout_sec": timeout_sec,
        "runner_timeout_sec": runner_timeout_sec,
        "summary_path": str(summary) if summary else None,
        "report_path": report_metrics.get("report_path") if report_metrics else None,
        "metric_source": "summary_json" if summary else ("report_htm" if report_metrics else None),
        "history_year": history_year,
        "history_from": history_from,
        "history_to": history_to,
        "latest_full_year": latest_full_year,
        "generated_at_utc": utc_now_iso(),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Q06 Stress HARSH runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True)
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--timeout-sec", type=int, default=DEFAULT_TIMEOUT_SEC)
    ap.add_argument("--latest-full-year", type=int,
                    help="Cap full-history window when validated custom-symbol history ends before default")
    ap.add_argument("--logical-symbol",
                    help="Basket evidence symbol to record when --symbol is the MT5 host")
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))

    repo_root = Path(__file__).resolve().parents[2]
    ea_expert = resolve_ea_expert_path(repo_root, args.ea)
    if ea_expert is None:
        print(f"cannot resolve EA dir for {args.ea}", file=sys.stderr)
        return 2
    period = period_from_setfile(args.baseline_setfile)

    harsh_set = gen_harsh_setfile_for(args.baseline_setfile)
    print(f"Q06 HARSH: generated stress setfile {harsh_set.name}  (reject_prob=0.10)")

    res = run_harsh_backtest(
        ea_id=ea_id, ea_expert=ea_expert, symbol=args.symbol,
        setfile=harsh_set, terminal=args.terminal, period=period,
        report_root=args.report_root, timeout_sec=args.timeout_sec,
        latest_full_year=args.latest_full_year,
        logical_symbol=args.logical_symbol,
    )

    evidence_symbol = str(res["symbol"])
    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q06" / evidence_symbol.replace(".", "_"))
    write_json(out_dir / "aggregate.json", res)
    print(f"Q06 {args.ea} {evidence_symbol}: {res['verdict']}  pf={res['pf']}  dd_pct={res['dd_pct']}")
    return 0 if res["verdict"] == "PASS" else (1 if res["verdict"] == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
