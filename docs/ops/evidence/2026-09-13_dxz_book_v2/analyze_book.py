#!/usr/bin/env python3
"""DXZ book v2 analytic build + fit analysis.

Replicates tools/strategy_farm/portfolio/build_book_dxz.build_dxz_manifest with ONE
deviation, which is documented in the output: the proposal and the incumbent are
aligned on a SHARED date grid (the union of trading days of ALL keys inside the
common window) instead of each on its own subset-union grid.  The shipped builder
refuses any roster whose sleeve set differs from the incumbent with
``proposal and incumbent did not resolve to the identical common-day grid``
(build_book_dxz.py:~134 + book_builder_common.aligned_matrix), which makes a real
book-change proposal uncomputable.  Every metric function used below is the
builder's own.

Writes ONLY under D:/QM/reports/portfolio/dxz_v2_20260913/.  Read-only elsewhere.
NOT a minted book manifest: the live risk freeze is ACTIVE, so build_book_dxz
refuses to write one.  This is analysis evidence.
"""
from __future__ import annotations
import argparse, datetime as dt, json, math, statistics, sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, r"C:\QM\repo")
from tools.strategy_farm.portfolio import concentration_tail
from tools.strategy_farm.portfolio.book_builder_common import (
    book_metrics, capped_inverse_vol, file_binding, portfolio_daily, sleeve_bindings,
    roster_sha256, canonical_json, sha256_bytes,
)
from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl
from tools.strategy_farm.portfolio import build_book_dxz as bbd

REPO = Path(r"C:\QM\repo")
BASE = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913")
INC_MANIFEST = Path(r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json")
BACKTEST_RISK_PCT = 1.0  # tester_defaults.json: fixed_risk 1000 USD on 100_000 deposit
CAPITAL = 100_000.0


def shared_grid(daily, keys, start, end):
    days = sorted({d for k in keys for d in daily[k] if start <= d <= end})
    return days


def matrix_for(daily, keys, days):
    return [[float(daily[k].get(d, 0.0)) for k in keys] for d in days]


def pearson(a, b):
    n = len(a)
    ma, mb = sum(a) / n, sum(b) / n
    va = sum((x - ma) ** 2 for x in a)
    vb = sum((x - mb) ** 2 for x in b)
    if va <= 0 or vb <= 0:
        return None
    cov = sum((a[i] - ma) * (b[i] - mb) for i in range(n))
    return cov / math.sqrt(va * vb)


def sleeve_stats(trades, daily):
    wins = [t.net_of_cost for t in trades if t.net_of_cost > 0]
    losses = [-t.net_of_cost for t in trades if t.net_of_cost < 0]
    pf = (sum(wins) / sum(losses)) if losses and sum(losses) > 0 else None
    days = sorted(daily)
    eq = peak = mdd = 0.0
    for d in days:
        eq += daily[d]
        peak = max(peak, eq)
        mdd = max(mdd, peak - eq)
    span_years = ((days[-1] - days[0]).days / 365.25) if len(days) > 1 else 0.0
    vols = [t.volume for t in trades if t.volume > 0]
    return {
        "n_trades": len(trades),
        "first_day": days[0].isoformat() if days else None,
        "last_day": days[-1].isoformat() if days else None,
        "span_years": round(span_years, 2),
        "trades_per_year": round(len(trades) / span_years, 2) if span_years > 0 else None,
        "net_of_cost": round(sum(t.net_of_cost for t in trades), 2),
        "profit_factor": round(pf, 4) if pf else None,
        "standalone_maxdd_pct_at_1pct_risk": round(mdd / CAPITAL * 100.0, 4),
        "active_days": len([d for d in days if daily[d] != 0.0]),
        "volume_min": min(vols) if vols else None,
        "volume_median": round(statistics.median(vols), 4) if vols else None,
        "volume_max": max(vols) if vols else None,
    }


def run(roster_path: Path, stream_root: Path, out_dir: Path, tag: str):
    roster_doc = json.loads(roster_path.read_text(encoding="utf-8"))
    roster = sorted((int(s["ea_id"]), s["symbol"]) for s in roster_doc["sleeves"])
    inc_doc = json.loads(INC_MANIFEST.read_text(encoding="utf-8"))
    inc_keys = sorted((int(s["ea_id"]), s["symbol"]) for s in inc_doc["sleeves"])
    inc_w = {(int(s["ea_id"]), s["symbol"]): float(s["risk_percent"]) for s in inc_doc["sleeves"]}

    all_keys = sorted(set(roster) | set(inc_keys))
    streams = load_streams(stream_root, candidates=all_keys)
    missing = sorted(set(all_keys) - set(streams))
    if missing:
        raise SystemExit(f"missing streams: {missing}")
    daily = {k: to_daily_pnl(streams[k]) for k in all_keys}
    start = max(min(daily[k]) for k in all_keys)
    end = min(max(daily[k]) for k in all_keys)
    days = shared_grid(daily, all_keys, start, end)

    p_matrix = matrix_for(daily, roster, days)
    i_matrix = matrix_for(daily, inc_keys, days)
    weights = capped_inverse_vol(roster, p_matrix, total=9.75, cap=1.0)
    p_metrics = book_metrics(portfolio_daily(roster, p_matrix, weights), len(roster), CAPITAL)
    i_metrics = book_metrics(portfolio_daily(inc_keys, i_matrix, inc_w), len(inc_keys), CAPITAL)
    gate = bbd._gate(p_metrics, i_metrics)

    conc = concentration_tail.evaluate(
        keys=roster, weights=weights, dates=days, matrix=p_matrix,
        streams={k: streams[k] for k in roster}, starting_capital=CAPITAL,
        policy_path=concentration_tail.DEFAULT_POLICY_PATH,
        symbol_matrix_path=concentration_tail.DEFAULT_SYMBOL_MATRIX, repo_root=REPO,
    )
    status = bbd._final_status(gate, conc)

    bindings = {(r["ea_id"], r["symbol"]): r for r in sleeve_bindings(REPO, roster)}
    by_label = {(int(s["ea_id"]), s["symbol"]): s for s in roster_doc["sleeves"]}
    live_by_key = {(int(s["ea_id"]), s["symbol"]): s for s in inc_doc["sleeves"]}

    sleeves = []
    for key in roster:
        b = dict(bindings[key])
        r = by_label[key]
        st_full = sleeve_stats(streams[key], daily[key])
        cw = {d: v for d, v in daily[key].items() if start <= d <= end}
        tr_cw = [t for t in streams[key]
                 if start <= dt.datetime.fromtimestamp(t.time, tz=dt.UTC).date() <= end]
        st_cw = sleeve_stats(tr_cw, cw) if cw else None
        vmed = st_full["volume_median"]
        vmax = st_full["volume_max"]
        vmin = st_full["volume_min"]
        sleeves.append({
            **b,
            "ea_label": r["ea_label"],
            "weight_risk_percent": round(weights[key], 6),
            "capped_at_sleeve_cap": abs(weights[key] - 1.0) < 1e-9,
            "already_live": r["already_live"],
            "live_magic_number": r["live_magic_number"],
            "live_risk_percent": r["live_risk_percent"],
            "q14_terminal_verdict": r["q14_terminal_verdict"],
            "q14_evidence_path": r["q14_evidence_path"],
            "standalone_full_stream": st_full,
            "standalone_common_window": st_cw,
            "min_lot_risk_percent": {
                "note": "streams are at RISK_FIXED $1000 on 100k = 1.0%/trade; lots scale linearly",
                "median_trade_hits_0.01_lots_at_pct": round(0.01 / vmed * BACKTEST_RISK_PCT, 4) if vmed else None,
                "largest_trade_hits_0.01_lots_at_pct": round(0.01 / vmax * BACKTEST_RISK_PCT, 4) if vmax else None,
                "smallest_trade_hits_0.01_lots_at_pct": round(0.01 / vmin * BACKTEST_RISK_PCT, 4) if vmin else None,
            },
        })

    # marginal contribution: leave-one-out on the proposal (weights re-solved)
    marginal = {}
    for key in roster:
        rest = [k for k in roster if k != key]
        if len(rest) < 2:
            continue
        m2 = matrix_for(daily, rest, days)
        w2 = capped_inverse_vol(rest, m2, total=9.75, cap=1.0)
        mm = book_metrics(portfolio_daily(rest, m2, w2), len(rest), CAPITAL)
        marginal[f"{key[0]}:{key[1]}"] = {
            "sharpe_without": mm["sharpe"],
            "delta_sharpe": (round(p_metrics["sharpe"] - mm["sharpe"], 6)
                             if p_metrics["sharpe"] is not None and mm["sharpe"] is not None else None),
            "maxdd_without_pct": mm["max_drawdown_pct"],
            "delta_maxdd_pct": round(p_metrics["max_drawdown_pct"] - mm["max_drawdown_pct"], 6),
            "annual_return_without_pct": mm["annual_return_pct"],
        }

    # pairwise correlation on the shared grid + co-active overlap
    corr, overlap, flagged = {}, {}, []
    for i, a in enumerate(roster):
        for b_ in roster[i + 1:]:
            sa = [daily[a].get(d, 0.0) for d in days]
            sb = [daily[b_].get(d, 0.0) for d in days]
            co = sum(1 for k in range(len(days)) if sa[k] != 0.0 and sb[k] != 0.0)
            r = pearson(sa, sb)
            lbl = f"{a[0]}:{a[1]}|{b_[0]}:{b_[1]}"
            corr[lbl] = None if r is None else round(r, 6)
            overlap[lbl] = co
            if r is not None and abs(r) >= 0.5:
                flagged.append({"pair": lbl, "r": round(r, 6), "co_active_days": co,
                                "meets_min_overlap_60": co >= 60})

    # ENB on the weighted correlation matrix (Meucci-style: 1/sum(w_i w_j rho_ij))
    w = [weights[k] for k in roster]
    tot = sum(w)
    wn = [x / tot for x in w]
    num = 0.0
    for i, a in enumerate(roster):
        for j, b_ in enumerate(roster):
            if i == j:
                rho = 1.0
            else:
                lbl = f"{a[0]}:{a[1]}|{b_[0]}:{b_[1]}" if i < j else f"{b_[0]}:{b_[1]}|{a[0]}:{a[1]}"
                rho = corr.get(lbl)
                rho = 0.0 if rho is None else rho
            num += wn[i] * wn[j] * rho
    enb = (1.0 / num) if num > 0 else None

    out = {
        "schema": "qm.dxz-book-v2-analytic-preview/v1",
        "NOT_A_MINTED_MANIFEST": (
            "build_book_dxz.py refuses this roster: (1) proposal/incumbent day grids differ, "
            "(2) the live risk freeze is ACTIVE. Analysis only; no live weights, no deployment."
        ),
        "lane": "Q11_DXZ",
        "variant": tag,
        "as_of": "2026-09-12",
        "execution_mode": "DRY_RUN",
        "status": status,
        "application_authority": "OWNER_ONLY",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
        "generated_utc": dt.datetime.now(dt.UTC).isoformat(),
        "order_artifact": "decisions/2026-09-13_owner_book_order_dxz.md",
        "roster": {"input": file_binding(roster_path), "n": len(roster)},
        "roster_sha256": roster_sha256([{"ea_id": k[0], "symbol": k[1]} for k in roster]),
        "stream_root": str(stream_root),
        "weighting": {"method": "CAPPED_INVERSE_VOL_DAILY_PNL", "total_risk_pct": 9.75,
                      "sleeve_cap_pct": 1.0,
                      "sum_risk_percent": round(sum(weights.values()), 6)},
        "comparison": {
            "basis": "SHARED_COMMON_DAY_GRID_UNION_OF_ALL_KEYS",
            "window": {"start": start.isoformat(), "end": end.isoformat(), "days": len(days)},
            "starting_capital": CAPITAL,
            "proposal": p_metrics,
            "incumbent": i_metrics,
            "incumbent_input": file_binding(INC_MANIFEST),
            "not_worse_gate": gate,
        },
        "enb_weighted": None if enb is None else round(enb, 4),
        "correlation": {"max_abs": max((abs(v) for v in corr.values() if v is not None), default=None),
                        "flagged_ge_0.5": sorted(flagged, key=lambda x: -abs(x["r"])),
                        "matrix": corr, "co_active_days": overlap},
        "marginal_contribution": marginal,
        "concentration_tail": conc,
        "sleeves": sleeves,
        "overlap_with_live_book": sorted(f"{k[0]}:{k[1]}" for k in set(roster) & set(inc_keys)),
        "live_sleeves_dropped_by_v2": sorted(f"{k[0]}:{k[1]}" for k in set(inc_keys) - set(roster)),
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    p = out_dir / f"analytic_preview_manifest_{tag}.json"
    p.write_text(json.dumps(out, indent=2, sort_keys=True, default=str) + "\n", encoding="utf-8")
    print(f"[{tag}] status={status} sleeves={len(roster)} window={start}..{end} ({len(days)}d)")
    print(f"[{tag}] proposal  {json.dumps(p_metrics)}")
    print(f"[{tag}] incumbent {json.dumps(i_metrics)}")
    print(f"[{tag}] gate={gate['checks']} passed={gate['passed']}")
    print(f"[{tag}] ENB={out['enb_weighted']} maxAbsCorr={out['correlation']['max_abs']} flagged={len(flagged)}")
    print(f"[{tag}] concentration reject={conc.get('concentration_reject')} eligible={conc.get('builder_eligible')}")
    print(f"[{tag}] -> {p}")
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--roster", type=Path, required=True)
    ap.add_argument("--stream-root", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--tag", required=True)
    a = ap.parse_args()
    run(a.roster, a.stream_root, a.out_dir, a.tag)
