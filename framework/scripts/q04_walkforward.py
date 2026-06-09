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
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json

GATE_NAME = "Q04"
COMMISSION_PER_LOT_ROUND_TRIP = 7.00     # USD; locked by Vault Q04 spec
PF_NET_FLOOR_PER_FOLD = 1.0
# DL-071 (OWNER-ratified 2026-06-09): PASS_SOFT tier for net-positive-with-variance
# edges (ORB / structural setups lose in some periods by design). Clean PASS still
# requires every fold > floor; PASS_SOFT requires a profitable MAJORITY of folds, a
# clear mean edge, and NO catastrophic fold — guardrails so it recalibrates without
# passing single-year wonders. Tunable.
Q04_SOFT_MEAN_FLOOR = 1.10        # mean PF-net across folds must exceed this
Q04_SOFT_MIN_FOLD_FLOOR = 0.80    # no fold may be below this (no catastrophic year)
Q04_SOFT_MIN_POS_FRACTION = 2.0 / 3.0  # >= this fraction of folds must have PF-net > floor

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


def _common_files_dir() -> Path:
    return Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files")


def _q04_sim_result_path(ea_id: int, symbol: str) -> Path:
    return _common_files_dir() / "QM" / "q04_sim" / f"{ea_id}_{symbol.replace('.', '_')}.json"


def read_pf_net_from_ea(ea_id: int, symbol: str) -> tuple[float | None, int, float | None]:
    """PF-net the EA self-reported (net of InpQMSimCommissionPerLot), from the
    deterministic Common\\Files result file. The MT5 tester applies NO commission to
    custom .DWX symbols, so the report PF is gross; the EA emits the true PF-net here."""
    p = _q04_sim_result_path(ea_id, symbol)
    if not p.exists():
        return None, 0, None
    try:
        d = json.loads(p.read_text(encoding="utf-8-sig"))
        pf = d.get("pf_net")
        comm = d.get("sim_commission_total")
        pf = float(pf) if pf is not None else None
        trades = int(d.get("closed_deals") or 0)
        comm = float(comm) if comm is not None else None
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return None, 0, None
    return pf, trades, comm


# ---------------------------------------------------------------------------
# DL-073 (OWNER-ratified 2026-06-09): realistic %-of-notional commission.
# Q04 historically charged a flat $7/lot round-trip EA-side — per-instrument WRONG
# (too harsh for FX majors ~$5, materially too lenient for high-notional index/gold).
# We now grade Q04 with the SAME instrument-correct model Q08 uses
# (tools/strategy_farm/portfolio/commission.py + framework/registry/live_commission.json:
#  cost_rt = max(pct_rate_rt × notional_acct, flat_per_lot_rt × volume)), applied POST-HOC
# to the per-trade stream the fold backtest already emits. No EA change, no MT5 re-run:
# every backtest writes TRADE_CLOSED rows (with notional + volume) to the q08_trades
# stream, so the realistic net P&L is recomputed in python. The flat-$7 EA self-report
# is kept only as a fallback when the stream is unavailable. Mirrors
# q08_davey.aggregate._apply_worst_case_commission so both gates share one cost model.
# ---------------------------------------------------------------------------
_COMMISSION_MODEL = None


def _commission_model():
    """Lazy-load the shared CommissionModel (single source of truth = live_commission.json)."""
    global _COMMISSION_MODEL
    if _COMMISSION_MODEL is None:
        from tools.strategy_farm.portfolio import commission
        _COMMISSION_MODEL = commission.load_model()
    return _COMMISSION_MODEL


def _q08_trade_stream_path(ea_id: int, symbol: str) -> Path:
    return _common_files_dir() / "QM" / "q08_trades" / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"


def _gross_before_commission(trade: dict) -> float:
    """gross P&L of a trade before any commission (mirrors
    q08_davey.aggregate._gross_before_commission). The MT5 tester applies $0 commission to
    .DWX custom symbols, so `profit` is already gross of cost; add swap."""
    try:
        profit = trade.get("profit")
        swap = float(trade.get("swap") or 0.0)
        if profit is not None:
            return float(profit) + swap
        net = float(trade.get("net") or 0.0)
        bc = trade.get("commission")
        return net - float(bc) if bc is not None else net
    except (TypeError, ValueError):
        return 0.0


def pf_net_from_stream(ea_id: int, symbol: str, fold: dict,
                       model=None) -> tuple[float | None, int, float | None, float | None]:
    """DL-073 grading source: PF-net under the realistic %-notional commission model,
    computed post-hoc from the per-trade stream the fold backtest just emitted.

    Returns (pf_net, n_trades, commission_total, gross_total), or (None, 0, None, None)
    when no usable stream exists (caller falls back to the EA's flat-$7 self-report).
    """
    from framework.scripts.q08_davey import common as q08common
    model = model or _commission_model()
    trades = q08common.load_trades_from_log(_q08_trade_stream_path(ea_id, symbol))
    if not trades:
        return None, 0, None, None
    # Defensive OOS windowing: a fold backtest only runs its OOS year, but a stale stream
    # could carry other dates. Keep trades whose close ts is inside [oos_start, oos_end].
    oos_start = dt.datetime.fromisoformat(fold["oos_start"]).replace(tzinfo=dt.timezone.utc)
    oos_end = (dt.datetime.fromisoformat(fold["oos_end"]).replace(tzinfo=dt.timezone.utc)
               + dt.timedelta(days=1))
    nets: list[float] = []
    cost_total = 0.0
    gross_total = 0.0
    for t in trades:
        ts = q08common.trade_timestamp(t)
        if ts is not None and not (oos_start <= ts < oos_end):
            continue
        vol = float(t.get("volume") or 0.0)
        notional = t.get("notional")
        notional = float(notional) if notional not in (None, "") else None
        cost = model.cost_round_trip(str(t.get("symbol") or symbol), vol, notional)
        gross = _gross_before_commission(t)
        nets.append(gross - cost)
        cost_total += cost
        gross_total += gross
    if not nets:
        return None, 0, None, None
    pf = q08common.profit_factor(nets)
    if pf == float("inf"):      # no losing trades after cost → cap for a finite verdict
        pf = 999.0
    return pf, len(nets), round(cost_total, 4), round(gross_total, 4)


def resolve_ea_expert_path(repo_root: Path, ea_label: str) -> str | None:
    """Canonical MT5 expert path 'QM\\<ea_dir>' for run_smoke / the tester (run_smoke
    deploys framework/EAs/<dir>/<dir>.ex5 to Experts/QM/<dir>.ex5). Bare labels do NOT
    resolve — that was the Q04 expert-path bug."""
    eas = repo_root / "framework" / "EAs"
    matches = sorted(p for p in eas.glob(f"{ea_label}_*") if p.is_dir())
    if not matches and (eas / ea_label).is_dir():
        matches = [eas / ea_label]
    return f"QM\\{matches[0].name}" if matches else None


def period_from_setfile(setfile: Path, default: str = "H1") -> str:
    m = re.search(r"_(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)_backtest", Path(setfile).name)
    return m.group(1) if m else default


def aggregate_verdict(fold_results: list[dict]) -> tuple[str, str]:
    """Verdict over the OOS folds (DL-071, OWNER-ratified 2026-06-09):
      - PASS       : EVERY fold has PF-net > floor (clean, the gold standard).
      - PASS_SOFT  : a profitable MAJORITY of folds (>= Q04_SOFT_MIN_POS_FRACTION),
                     mean PF-net > Q04_SOFT_MEAN_FLOOR, and NO catastrophic fold
                     (every fold's PF-net >= Q04_SOFT_MIN_FOLD_FLOOR; a no-trade
                     fold counts as 0.0 → fails this guard). Net-positive-with-
                     controlled-variance — advances like a Q08 soft-pass.
      - FAIL       : otherwise.
    A no-trade / missing fold is treated as PF-net 0.0 for the soft test, so it can
    never soft-pass on a fold that did not trade.
    """
    if not fold_results:
        return "INVALID", "no_folds_ran"
    incomplete = [
        f for f in fold_results
        if not f.get("summary_path")
    ]
    if incomplete:
        return "INVALID", ";".join(f"{f['id']}:incomplete_fold" for f in incomplete)
    failures = [f for f in fold_results if f.get("pf_net") is None or
                                            float(f["pf_net"]) <= PF_NET_FLOOR_PER_FOLD]
    detail = ";".join(
        f"{f['id']}:pf_net={f['pf_net']:.3f}" if f.get("pf_net") is not None
        else f"{f['id']}:trades={f.get('trades', 0)}"
        for f in fold_results
    )
    if not failures:
        return "PASS", detail
    # PASS_SOFT check: net-positive with controlled variance.
    n = len(fold_results)
    pfs = [float(f["pf_net"]) if f.get("pf_net") is not None else 0.0 for f in fold_results]
    n_pos = sum(1 for p in pfs if p > PF_NET_FLOOR_PER_FOLD)
    mean_pf = sum(pfs) / n
    min_pf = min(pfs)
    import math
    need_pos = math.ceil(Q04_SOFT_MIN_POS_FRACTION * n)
    if (n_pos >= need_pos and mean_pf > Q04_SOFT_MEAN_FLOOR
            and min_pf >= Q04_SOFT_MIN_FOLD_FLOOR):
        return "PASS_SOFT", (f"soft:{n_pos}/{n}>floor,mean={mean_pf:.3f},"
                             f"min={min_pf:.3f};{detail}")
    return "FAIL", detail


def _mt5_date(iso_date: str) -> str:
    return iso_date.replace("-", ".")


def _summary_from_log(log_path: Path) -> Path | None:
    try:
        for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("run_smoke.summary="):
                candidate = Path(line.partition("=")[2].strip())
                if candidate.exists():
                    return candidate
    except OSError:
        return None
    return None


def run_fold_via_smoke(*, ea_id: int, ea_expert: str, symbol: str,
                        setfile: Path, fold: dict, report_root: Path,
                        terminal: str, period: str, timeout_sec: int = 1800) -> dict:
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

    # Inject the EA-side simulated commission into a fold-local setfile copy. The tester
    # cannot commission custom .DWX symbols; the EA self-accounts InpQMSimCommissionPerLot
    # and writes PF-net to Common\Files (read back below).
    fold_dir = report_root / f"QM5_{ea_id}" / "Q04" / fold["id"]
    fold_dir.mkdir(parents=True, exist_ok=True)
    fold_set = fold_dir / f"{Path(setfile).stem}_q04comm.set"
    base_text = Path(setfile).read_text(encoding="utf-8", errors="ignore") if Path(setfile).exists() else ""
    if "InpQMSimCommissionPerLot" not in base_text:
        base_text = base_text.rstrip("\r\n") + f"\r\nInpQMSimCommissionPerLot={COMMISSION_PER_LOT_ROUND_TRIP}\r\n"
    fold_set.write_text(base_text, encoding="utf-8")

    # Clear any stale EA result + per-trade stream before this fold (folds run
    # sequentially per ea/symbol) so the post-hoc stream read picks up ONLY this
    # fold's trades. Q08 regenerates the stream from its own full-history baseline.
    for stale in (_q04_sim_result_path(ea_id, symbol), _q08_trade_stream_path(ea_id, symbol)):
        try:
            if stale.exists():
                stale.unlink()
        except OSError:
            pass

    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", str(oos_year),
        "-Terminal", terminal,
        "-Period", period,
        "-DispatchSubGateHash", run_id,
        "-DispatchPhase", "Q04",
        "-DispatchVersion", "q04_walkforward",
        "-Runs", "1",
        "-MinTrades", "5",
        "-Model", "4",
        "-SetFile", str(fold_set),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
        "-FromDate", _mt5_date(fold["oos_start"]),
        "-ToDate", _mt5_date(fold["oos_end"]),
        "-AllowRunningTerminal",
        "-AllowMissingRealTicksLogMarker",
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    log_path = fold_dir / "run_smoke.log"
    try:
        with log_path.open("w", encoding="utf-8") as log:
            proc = subprocess.run(
                args,
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=timeout_sec,
                creationflags=creationflags,
            )
    except subprocess.TimeoutExpired:
        return {**fold, "pf_net": None, "trades": 0, "status": "TIMEOUT",
                "summary_path": None, "log_path": str(log_path)}

    # DL-073: grade from the realistic %-notional model applied post-hoc to the per-trade
    # stream this fold just emitted (preferred). Fall back to the EA's flat-$7 self-report
    # only when the stream is unavailable (older EA / stream skipped).
    pf_net, trades, comm_total, gross_total = pf_net_from_stream(ea_id, symbol, fold)
    commission_basis = "worst_case_dxz_ftmo_notional"
    if pf_net is None:
        pf_net, trades, comm_total = read_pf_net_from_ea(ea_id, symbol)
        gross_total = None
        commission_basis = "flat_7_ea_side_fallback"
    summary_path = _summary_from_log(log_path) or report_root / f"QM5_{ea_id}" / "Q04" / fold["id"] / "summary.json"
    status = "OK" if (pf_net is not None and proc.returncode == 0) else "FAIL"
    return {
        **fold,
        "pf_net": pf_net,
        "trades": trades,
        "sim_commission_total": comm_total,
        "gross_total": gross_total,
        "commission_basis": commission_basis,
        "status": status,
        "summary_path": str(summary_path) if summary_path.exists() else None,
        "exit_code": proc.returncode,
        "log_path": str(log_path),
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

    repo_root = Path(__file__).resolve().parents[2]
    ea_expert = resolve_ea_expert_path(repo_root, args.ea)
    if ea_expert is None:
        print(f"cannot resolve EA dir for {args.ea} under framework/EAs", file=sys.stderr)
        return 2
    period = period_from_setfile(args.setfile)

    folds = folds_for_year(args.latest_full_year)
    print(f"Q04 {args.ea} {args.symbol} {period}  expert={ea_expert}  folds={[f['id'] for f in folds]}  "
          f"comm=realistic %-notional worst-case{{DXZ,FTMO}} (DL-073; flat ${COMMISSION_PER_LOT_ROUND_TRIP}/lot fallback)")

    fold_results: list[dict] = []
    for fold in folds:
        print(f"  fold {fold['id']}: OOS {fold['oos_start']} -> {fold['oos_end']} ...")
        res = run_fold_via_smoke(
            ea_id=ea_id, ea_expert=ea_expert, symbol=args.symbol,
            setfile=args.setfile, fold=fold,
            report_root=args.report_root, terminal=args.terminal,
            period=period, timeout_sec=args.timeout_sec,
        )
        pf_str = f"{res['pf_net']:.3f}" if res.get("pf_net") is not None else "n/a"
        print(f"    -> PF-net={pf_str}  trades={res['trades']}  status={res['status']}")
        fold_results.append(res)

    verdict, reason = aggregate_verdict(fold_results)
    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q04" / args.symbol)
    # DL-073: report the basis actually used across folds (notional model unless a fold
    # had to fall back to the flat-$7 self-report).
    bases = sorted({f.get("commission_basis") for f in fold_results if f.get("commission_basis")})
    write_json(out_dir / "aggregate.json", {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "ea": args.ea,
        "symbol": args.symbol,
        "commission_model": "worst_case_dxz_ftmo_notional (DL-073)",
        "commission_basis": bases,
        "commission_per_lot_round_trip_fallback": COMMISSION_PER_LOT_ROUND_TRIP,
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
