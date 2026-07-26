"""FINAL23 ALTERNATIVE Sunday DXZ book (2026-07-26): the approved FINAL24b composition
MINUS 12567/XNGUSD.DWX, at TOTAL_RISK 12.0, capped inverse-vol cap 1.0.

Prepared as OPTION B for the Sunday-evening OWNER decision. Trigger: the sleeve's fresh
sealed Q08 came back FAIL_HARD twice (2026-07-18 and 2026-07-25, identical sub-gate
pattern): 8.8_edge_decay 41.5% (PF first half 1.764 -> last half 1.032), 8.4_seasonal
9/12, 8.10_regime low-vol negative. Its Q10 full-history PASS (the closing verdict)
stands, and 8.5_neighborhood / 8.6_chopping_block / 8.11_mc_shuffle all PASS — hence a
decision, not an automatic removal. The sleeve sits at cap 1.0 (largest allocation).
Evidence: D:/QM/reports/work_items/084a05e0-99cf-435e-bce3-d464d97081e0/QM5_12567/Q08/
XNGUSD_DWX/aggregate.json (and 2fcecbbf-... for the 07-18 run).

Arithmetic and stream basis are REUSED VERBATIM from gen_dxz24b_20260726: sealed
SHA-pinned bundle dxz_final_20260719 for the incumbents, sleeve_streams for 11422,
portfolio_common + capped_inverse_vol_weights + portfolio_kpi. STEP 1 reproduces the
FINAL24b solve against its emitted manifest before any delta is computed.

Read-only: no terminal, no DB, no queue mutation. NO import-time side effects. Emits a
DRAFT manifest only; OWNER written approval + chart session + T_Live verify remain.
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
BASE_MANIFEST = Path(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json")
SEALED = Path(r"D:/QM/reports/portfolio/dxz_final_20260719")            # incumbent stream basis (SHA-pinned)
SLEEVE_ROOT = Path(r"D:/QM/reports/portfolio/sleeve_streams")           # 11422 stream basis
DEFAULT_OUT = Path(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_FINAL23_TOTALRISK12_20260726.json")

REMOVE = (12567, "XNGUSD.DWX")
CANDIDATE = (11422, "USDCAD.DWX")   # streams live outside the sealed bundle
CANDIDATE_TRADES = 197

SC = 100_000.0

REMOVE_REASON = (
    "fresh sealed Q08 FAIL_HARD twice (2026-07-18 + 2026-07-25, identical pattern): "
    "8.8_edge_decay 41.5% (PF first half 1.764 -> last half 1.032, threshold 40%), "
    "8.4_seasonal 9/12 profitable months, 8.10_regime low-vol P&L negative. Q10 "
    "full-history PASS stands (closing verdict) and neighborhood/chopping/MC pass — "
    "removal is an OWNER composition decision, prepared as OPTION B; sleeve was at "
    "cap 1.0 (largest allocation)."
)
REMOVE_EVIDENCE = [
    r"D:\QM\reports\work_items\084a05e0-99cf-435e-bce3-d464d97081e0\QM5_12567\Q08\XNGUSD_DWX\aggregate.json",
    r"D:\QM\reports\work_items\2fcecbbf-7987-4b86-8802-0035ef69d163\QM5_12567\Q08\XNGUSD_DWX\aggregate.json",
]


def faithful_maxdd_pct(daily: list[float]) -> float:
    """constant-SC faithful method (the manifest KPI convention):
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
    book24b = [(int(s["ea_id"]), str(s["symbol"])) for s in base_sleeves]
    man_w = {(int(s["ea_id"]), str(s["symbol"])): float(s["risk_percent"]) for s in base_sleeves}
    man_sharpe = float(base["kpis"]["sharpe"])
    man_maxdd_faithful = float(base["kpis"]["max_drawdown_pct"])
    assert REMOVE in book24b, f"{REMOVE} not in FINAL24b manifest"
    assert CANDIDATE in book24b, f"{CANDIDATE} missing from FINAL24b manifest"

    # ---- load streams: incumbents from sealed bundle, 11422 from sleeve_streams ----
    incumbents = [k for k in book24b if k != CANDIDATE]
    inc_streams = load_streams(SEALED, candidates=incumbents)
    missing = sorted(set(incumbents) - set(inc_streams))
    if missing:
        print(f"[STOP] incumbent streams missing from sealed bundle: {missing}", file=sys.stderr)
        return 2
    add_streams = load_streams(SLEEVE_ROOT, candidates=[CANDIDATE])
    if CANDIDATE not in add_streams or len(add_streams[CANDIDATE]) != CANDIDATE_TRADES:
        got = len(add_streams.get(CANDIDATE, []))
        print(f"[STOP] {CANDIDATE} stream has {got} trades, expected {CANDIDATE_TRADES}", file=sys.stderr)
        return 2

    daily = {k: to_daily_pnl(v) for k, v in inc_streams.items()}
    daily[CANDIDATE] = to_daily_pnl(add_streams[CANDIDATE])

    # ---- STEP 1: BASE VERIFY — reproduce the FINAL24b solve BEFORE any delta ----
    ak24, dates24, w24, comp24, m24 = solve(book24b, daily, TOTAL, CAP)
    weight_err = max(abs(w24[k] - man_w[k]) for k in book24b)
    sharpe_match = abs(m24["sharpe"] - man_sharpe) < 5e-3
    base_maxdd_faithful = faithful_maxdd_pct(comp24)
    base_verify = {
        "n_sleeves": len(ak24),
        "n_days": len(dates24),
        "window": [dates24[0].isoformat(), dates24[-1].isoformat()],
        "sharpe_reproduced": m24["sharpe"],
        "sharpe_manifest": man_sharpe,
        "sharpe_match": sharpe_match,
        "capped_invvol_max_weight_err_vs_manifest": round(weight_err, 8),
        "maxdd_faithful_constSC_pct": round(base_maxdd_faithful, 4),
        "maxdd_faithful_manifest": man_maxdd_faithful,
    }
    print("=== BASE VERIFY (FINAL24b, before removal) ===")
    print(json.dumps(base_verify, indent=2))
    if not (sharpe_match and weight_err < 1e-4):
        print("[STOP] FINAL24b solve does not reproduce its manifest Sharpe/weights within "
              "rounding; every delta would be on sand. Nothing emitted.", file=sys.stderr)
        return 3

    # ---- STEP 2: FINAL23 = drop 12567/XNGUSD ----
    bookF = [k for k in book24b if k != REMOVE]
    akF, datesF, wF, compF, mF = solve(bookF, daily, TOTAL, CAP)
    final_maxdd_faithful = faithful_maxdd_pct(compF)
    at_cap = sorted([f"{k[0]}:{k[1]}" for k in akF if wF[k] >= CAP - 1e-9])
    wsum = sum(wF.values())

    # ---- sleeve list: reuse FINAL24b metadata, only reweight ----
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
        "generated_by": "gen_dxz23_20260726 (claude/board-advisor)",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "derived_from": str(BASE_MANIFEST),
        "stream_basis": {
            "incumbents_bundle": str(SEALED),
            "candidate_11422_common_dir": str(SLEEVE_ROOT),
            "note": "22 incumbents on the sealed SHA-pinned bundle; 11422/USDCAD on sleeve_streams (its only home)."},
        "arithmetic_basis": ("portfolio_common load_streams/to_daily_pnl/align + "
                             "marginal_contribution_eval.capped_inverse_vol_weights (capped inverse-vol, daily-vol) + "
                             "portfolio_kpi.metrics_from_daily_pnl; reused verbatim from gen_dxz24b_20260726."),
        "base_verify": base_verify,
        "kpis": kpis,
        "composition_change": {
            "removed": [{
                "ea_id": REMOVE[0], "symbol": REMOVE[1],
                "base_weight": man_w[REMOVE],
                "reason": REMOVE_REASON,
                "evidence": REMOVE_EVIDENCE,
            }],
            "added": [],
        },
        "note": ("FINAL23 ALTERNATIVE (OPTION B) for the 2026-07-26 Sunday-evening decision: the approved "
                 "FINAL24b MINUS 12567/XNGUSD.DWX, capped inverse-vol cap 1.0 total 12.0. DRAFT ONLY — "
                 "deploy ONLY if OWNER chooses DROP; otherwise the approved FINAL24b stands unchanged."),
        "manual_approval_required": True, "autotrading_action": "NONE", "deployment_action": "STAGE_ONLY",
        "weights_at_cap": at_cap,
        "sleeves": sleeves,
    }

    args.out.write_text(json.dumps(manifest, indent=1), encoding="utf-8")

    # ---- report ----
    print("\n=== FINAL23 alternative book ===")
    print(f"wrote {args.out}")
    print(f"Sharpe               {mF['sharpe']}   (FINAL24b {man_sharpe})")
    print(f"MaxDD faithful/SC    {round(final_maxdd_faithful,4)}%   (FINAL24b {man_maxdd_faithful}%)")
    print(f"MaxDD running-peak   {mF['max_drawdown_pct']}%")
    print(f"total net-of-cost    {mF['total_net_of_cost_profit']}")
    print(f"n_days               {len(datesF)}   n_sleeves {len(akF)}")
    print(f"weight sum           {round(wsum,6)}  (target {TOTAL})")
    print(f"sleeves at cap       {at_cap}")
    print("\nper-sleeve weights (FINAL23 vs FINAL24b):")
    for k in sorted(akF):
        base_w = man_w.get(k)
        print(f"  {k[0]:>5}:{k[1]:<11} {wF[k]:.6f}  (24b {base_w:.6f})")
    print(f"  {REMOVE[0]:>5}:{REMOVE[1]:<11} DROPPED (24b {man_w[REMOVE]:.6f})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
