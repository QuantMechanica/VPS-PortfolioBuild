"""FINAL Sunday DXZ book (2026-07-26 / "24b"): the 2026-07-19 24-sleeve TOTALRISK12
composition MINUS 10440/NDX.DWX PLUS 11422/USDCAD.DWX, at TOTAL_RISK 12.0, capped
inverse-vol cap 1.0.

Two operator decisions taken under OWNER delegation (2026-07-24/25):
  * REMOVE 10440/NDX.DWX  — fresh warm Q10 on the NEW binary is a hard FAIL
    (pf 1.07, dd 31.0%, 490 trades — far over the 25% DD ceiling).
  * ADD    11422/USDCAD.DWX — the one candidate with a clean CURRENT evidence chain
    (same-day-recompiled full-chain PASS incl real Q08 PASS + Q10 PASS n=197);
    both admission lenses ADMIT; DeltaSharpe +0.030, regime corr 0.025.

Stream basis:
  * 23 incumbent sleeves  -> sealed SHA-pinned bundle dxz_final_20260719/QM/q08_trades
  * 11422/USDCAD.DWX      -> sleeve_streams/QM/q08_trades/11422_USDCAD_DWX.jsonl
    (197 trades, WP-6 count-only v1 lineage: Q08 agg content_sha256=None,
     agg n_trades=197==stream 197; trustworthy only to the extent the count-matched
     stream equals the graded backtest).

Arithmetic is REUSED VERBATIM from the production admission cross-check
(candidate_admission_12 / marginal_contribution_eval): portfolio_common
load_streams/to_daily_pnl/align + mce.capped_inverse_vol_weights (capped inverse-vol,
daily-vol basis) + portfolio_kpi.metrics_from_daily_pnl. The same base-24 solve
reproduces the sealed manifest weights (err 0.0) and Sharpe 2.3737468913.

Read-only: no terminal, no DB, no queue mutation. NO import-time side effects — all
work is behind main() so importing / --help never rewrites an artifact. Emits a DRAFT
manifest only; OWNER written approval + chart session + T_Live verify remain.
"""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, r"C:/QM/repo")

from tools.strategy_farm.portfolio.portfolio_common import align, load_streams, to_daily_pnl
from tools.strategy_farm.portfolio.portfolio_kpi import metrics_from_daily_pnl
from tools.strategy_farm.portfolio.marginal_contribution_eval import capped_inverse_vol_weights

# ---------------------------------------------------------------- constants (no side effects)
BASE_MANIFEST = Path(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_24sleeve_TOTALRISK12_20260726.json")
SEALED = Path(r"D:/QM/reports/portfolio/dxz_final_20260719")            # incumbent stream basis (SHA-pinned)
SLEEVE_ROOT = Path(r"D:/QM/reports/portfolio/sleeve_streams")           # 11422 candidate stream basis
DEFAULT_OUT = Path(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json")

REMOVE = (10440, "NDX.DWX")
ADD = (11422, "USDCAD.DWX")

# 11422/USDCAD.DWX evidence (verified before generation; see report):
ADD_EA_LABEL = "QM5_11422_williams-18ma-outside-bar-entry-d1"
ADD_EA_DIR = Path(rf"C:/QM/repo/framework/EAs/{ADD_EA_LABEL}")
ADD_EX5 = ADD_EA_DIR / f"{ADD_EA_LABEL}.ex5"
# backtest_set == the setfile the 07-24 Q10 ran, resolved from the Q10 work_item tester.ini
# (ExpertParameters=...USDCAD.DWX_D1_q10_confirmation.set). Strategy params are identical to
# the _backtest.set; the q10_confirmation variant additionally carries the DXZ news-compliance
# params -> the correct evidence-anchored base for the live preset.
ADD_BACKTEST_SET = ADD_EA_DIR / "sets" / f"{ADD_EA_LABEL}_USDCAD.DWX_D1_q10_confirmation.set"
ADD_MAGIC = 114220004          # ea_id*10000 + slot(4); registry USDCAD.DWX slot == 4
ADD_MAGIC_SLOT = 4
ADD_TRADES = 197
ADD_STREAM_FILE = SLEEVE_ROOT / "QM" / "q08_trades" / "11422_USDCAD_DWX.jsonl"
ADD_STREAM_LINEAGE = (
    "WP-6 count-only v1 fallback (Q08 agg content_sha256=None; agg n_trades=197==stream 197). "
    "Trustworthy only to the extent the count-matched stream equals the graded backtest."
)

SC = 100_000.0
MANIFEST_SHARPE = 2.3737       # sealed base-24 manifest KPI
MANIFEST_MAXDD_FAITHFUL = 3.3851
MANIFEST_PROFIT = 91754.02


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def faithful_maxdd_pct(daily: list[float]) -> float:
    """constant-SC faithful method (the base manifest / gen_dxz_final_manifest.met convention):
    peak of cumulative PnL from 0, drawdown / SC * 100."""
    eq, cum = [], 0.0
    for v in daily:
        cum += v
        eq.append(cum)
    peak = mdd = 0.0
    for e in eq:
        peak = max(peak, e)
        mdd = max(mdd, peak - e)
    return mdd / SC * 100.0


def solve(keys, daily_by_key, total, cap):
    """capped inverse-vol weights + composite metrics over `keys` on their union daily grid."""
    ak, dates, mat = align({k: daily_by_key[k] for k in keys})
    matrix = [[float(mat[r][c]) for c in range(len(ak))] for r in range(len(dates))]
    w = capped_inverse_vol_weights(ak, matrix, total, cap)
    comp = [sum(matrix[r][c] * w[ak[c]] for c in range(len(ak))) for r in range(len(dates))]
    m = metrics_from_daily_pnl(comp, n_sleeves=len(ak), starting_capital=SC)
    return ak, dates, w, comp, m


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--total-risk", type=float, default=12.0, help="book TOTAL_RISK %% (default 12.0)")
    ap.add_argument("--cap", type=float, default=1.0, help="per-sleeve cap %% (OWNER hard constraint)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output manifest path")
    args = ap.parse_args()
    TOTAL, CAP = args.total_risk, args.cap

    base = json.loads(BASE_MANIFEST.read_text(encoding="utf-8-sig"))
    base_sleeves = base["sleeves"]
    book24 = [(int(s["ea_id"]), str(s["symbol"])) for s in base_sleeves]
    man_w = {(int(s["ea_id"]), str(s["symbol"])): float(s["risk_percent"]) for s in base_sleeves}
    assert REMOVE in book24, f"{REMOVE} not in base manifest"
    assert ADD not in book24, f"{ADD} already in base manifest"

    # ---- load streams: 24 incumbents (sealed) + 11422 (sleeve_streams) ----
    inc_streams = load_streams(SEALED, candidates=book24)
    missing = sorted(set(book24) - set(inc_streams))
    if missing:
        print(f"[STOP] incumbent streams missing from sealed bundle: {missing}", file=sys.stderr)
        return 2
    add_streams = load_streams(SLEEVE_ROOT, candidates=[ADD])
    if ADD not in add_streams or not add_streams[ADD]:
        print(f"[STOP] candidate stream {ADD} not found under {SLEEVE_ROOT}", file=sys.stderr)
        return 2
    if len(add_streams[ADD]) != ADD_TRADES:
        print(f"[STOP] {ADD} stream has {len(add_streams[ADD])} trades, expected {ADD_TRADES}", file=sys.stderr)
        return 2

    daily = {k: to_daily_pnl(v) for k, v in inc_streams.items()}
    daily[ADD] = to_daily_pnl(add_streams[ADD])

    # ---- STEP 1: BASE VERIFY — reproduce sealed base-24 solve BEFORE any swap ----
    ak24, dates24, w24, comp24, m24 = solve(book24, daily, TOTAL, CAP)
    weight_err = max(abs(w24[k] - man_w[k]) for k in book24)
    sharpe_match = abs(m24["sharpe"] - MANIFEST_SHARPE) < 5e-3
    base_maxdd_faithful = faithful_maxdd_pct(comp24)
    base_verify = {
        "n_sleeves": len(ak24),
        "n_days": len(dates24),
        "window": [dates24[0].isoformat(), dates24[-1].isoformat()],
        "sharpe_reproduced": m24["sharpe"],
        "sharpe_manifest": MANIFEST_SHARPE,
        "sharpe_match": sharpe_match,
        "capped_invvol_max_weight_err_vs_manifest": round(weight_err, 8),
        "maxdd_running_peak_pct": m24["max_drawdown_pct"],
        "maxdd_faithful_constSC_pct": round(base_maxdd_faithful, 4),
        "maxdd_faithful_manifest": MANIFEST_MAXDD_FAITHFUL,
        "total_net_of_cost_profit_reproduced": m24["total_net_of_cost_profit"],
        "total_net_of_cost_profit_manifest": MANIFEST_PROFIT,
    }
    print("=== BASE VERIFY (sealed 24, before swap) ===")
    print(json.dumps(base_verify, indent=2))
    if not (sharpe_match and weight_err < 1e-4):
        print("[STOP] base 24-sleeve solve does not reproduce Sharpe 2.3737 / manifest weights "
              "within rounding; every delta would be on sand. Nothing emitted.", file=sys.stderr)
        return 3

    # ---- STEP 2: FINAL book = drop 10440, add 11422 ----
    bookF = [k for k in book24 if k != REMOVE] + [ADD]
    akF, datesF, wF, compF, mF = solve(bookF, daily, TOTAL, CAP)
    final_maxdd_faithful = faithful_maxdd_pct(compF)
    at_cap = sorted([f"{k[0]}:{k[1]}" for k in akF if wF[k] >= CAP - 1e-9])
    wsum = sum(wF.values())

    ex5_sha = _sha256_file(ADD_EX5)

    # ---- build sleeve list: reuse base metadata for incumbents (only reweight); fresh 11422 ----
    sleeves = []
    for s in base_sleeves:
        k = (int(s["ea_id"]), str(s["symbol"]))
        if k == REMOVE:
            continue
        e = copy.deepcopy(s)
        w = round(wF[k], 6)
        e["weight"] = w
        e["risk_percent"] = w
        e["set_file_expectation"]["RISK_PERCENT"] = w
        sleeves.append(e)
    add_w = round(wF[ADD], 6)
    sleeves.append({
        "ea_id": ADD[0], "symbol": ADD[1], "ea_label": ADD_EA_LABEL,
        "magic_number": ADD_MAGIC, "magic_slot": ADD_MAGIC_SLOT,
        "weight": add_w, "risk_percent": add_w,
        "ex5_path": str(ADD_EX5).replace("/", "\\"),
        "ex5_sha256": ex5_sha,
        "backtest_set": str(ADD_BACKTEST_SET).replace("/", "\\"),
        "backtest_set_note": ("resolved from the 07-24 Q10 work_item tester.ini "
                              "(ExpertParameters=...USDCAD.DWX_D1_q10_confirmation.set); "
                              "strategy params identical to the _backtest.set, plus DXZ news-compliance params"),
        "new_candidate": True,
        "trades": ADD_TRADES,
        "stream_file": str(ADD_STREAM_FILE).replace("/", "\\"),
        "stream_lineage": ADD_STREAM_LINEAGE,
        "set_file_expectation": {"ENV": "live", "RISK_FIXED": 0.0, "RISK_PERCENT": add_w, "PORTFOLIO_WEIGHT": 1.0},
    })

    kpis = {
        "sharpe": mF["sharpe"],
        "max_drawdown_pct": round(final_maxdd_faithful, 4),
        "max_drawdown_pct_method": "faithful_constSC (peak of cumulative PnL from 0, dd/SC*100; matches base manifest convention)",
        "max_drawdown_pct_running_peak": mF["max_drawdown_pct"],
        "total_net_of_cost_profit": mF["total_net_of_cost_profit"],
        "n_days": len(datesF),
        "n_sleeves": len(akF),
    }

    manifest = {
        "book": "DXZ", "status": "DRAFT", "n_sleeves": len(sleeves), "starting_capital": SC,
        "total_risk_pct": TOTAL,
        "weight_method": f"capped_inverse_vol_cap{CAP:g}_total{TOTAL:g}",
        "risk_application_contract": {
            "RISK_PERCENT": "absolute_allocated_sleeve_risk", "PORTFOLIO_WEIGHT": 1.0,
            "effective_risk_formula": "RISK_PERCENT * PORTFOLIO_WEIGHT",
            "relative_weights_are_analytics_only": True},
        "generated_by": "gen_dxz24b_20260726 (claude/board-advisor)",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "derived_from": str(BASE_MANIFEST),
        "stream_basis": {
            "incumbents_bundle": str(SEALED),
            "candidate_11422_common_dir": str(SLEEVE_ROOT),
            "note": "23 incumbents on the sealed SHA-pinned bundle; 11422/USDCAD on sleeve_streams (its only home)."},
        "arithmetic_basis": ("portfolio_common load_streams/to_daily_pnl/align + "
                             "marginal_contribution_eval.capped_inverse_vol_weights (capped inverse-vol, daily-vol) + "
                             "portfolio_kpi.metrics_from_daily_pnl; reused verbatim from candidate_admission_12."),
        "base_verify": base_verify,
        "kpis": kpis,
        "composition_change": {
            "removed": [{
                "ea_id": REMOVE[0], "symbol": REMOVE[1],
                "base_weight": man_w[REMOVE],
                "reason": ("fresh warm Q10 on the NEW binary is a hard FAIL: pf 1.07, dd 31.0%, 490 trades — "
                           "far over the 25% DD ceiling. Operator decision under OWNER delegation 2026-07-24."),
            }],
            "added": [{
                "ea_id": ADD[0], "symbol": ADD[1], "final_weight": add_w,
                "reason": ("the one candidate with a clean CURRENT evidence chain: same-day-recompiled full-chain "
                           "PASS incl real Q08 PASS + Q10 PASS n=197 (pf 1.24, dd 13.25%). Both admission lenses "
                           "ADMIT (current ratified gate + DL-083 recommendation engine); DeltaSharpe +0.030, "
                           "regime corr 0.025. Operator decision under OWNER delegation 2026-07-24/25."),
                "evidence": {
                    "q10_aggregate": str(SEALED.parent / "pipeline" / "QM5_11422" / "Q10" / "aggregate.json").replace("/", "\\"),
                    "q10_aggregate_path_actual": r"D:\QM\reports\pipeline\QM5_11422\Q10\aggregate.json",
                    "admission_solve": r"candidate_admission_12.json (scratchpad); current_gate ADMIT + DL-083 ADMIT-CANDIDATE",
                    "ex5_sha256": ex5_sha,
                    "stream_lineage": ADD_STREAM_LINEAGE,
                },
            }],
        },
        "note": ("FINAL Sunday book 24b: sealed base-24 (TOTALRISK12) MINUS 10440/NDX.DWX PLUS 11422/USDCAD.DWX, "
                 "capped inverse-vol cap 1.0 total 12.0. DRAFT ONLY — OWNER written approval + chart session + "
                 "T_Live SHA/magic/setfile/news verification remain."),
        "manual_approval_required": True, "autotrading_action": "NONE", "deployment_action": "STAGE_ONLY",
        "new_candidates": [{"ea_id": ADD[0], "symbol": ADD[1]}],
        "weights_at_cap": at_cap,
        "sleeves": sleeves,
    }

    args.out.write_text(json.dumps(manifest, indent=1), encoding="utf-8")

    # ---- report ----
    print("\n=== FINAL 24b book ===")
    print(f"wrote {args.out}")
    print(f"Sharpe               {mF['sharpe']}")
    print(f"MaxDD faithful/SC    {round(final_maxdd_faithful,4)}%   (manifest kpi convention)")
    print(f"MaxDD running-peak   {mF['max_drawdown_pct']}%")
    print(f"total net-of-cost    {mF['total_net_of_cost_profit']}")
    print(f"n_days               {len(datesF)}   n_sleeves {len(akF)}")
    print(f"weight sum           {round(wsum,6)}  (target {TOTAL})")
    print(f"sleeves at cap       {at_cap}")
    print(f"11422/USDCAD weight  {add_w}   ex5_sha {ex5_sha[:16]}...   trades {ADD_TRADES}")
    print("\nper-sleeve weights (final vs base):")
    for k in sorted(akF):
        base_w = man_w.get(k)
        tag = "  <-- ADDED" if k == ADD else ""
        bstr = f"{base_w:.6f}" if base_w is not None else "   —    "
        print(f"  {k[0]:>5}:{k[1]:<11} {wF[k]:.6f}  (base {bstr}){tag}")
    print(f"  {REMOVE[0]:>5}:{REMOVE[1]:<11} DROPPED (base {man_w[REMOVE]:.6f})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
