#!/usr/bin/env python3
"""Selective-union book search for DXZ book v2 (2026-09-13).

Finds the best book that PASSES the ratified not-worse gate BY CONSTRUCTION.
Every metric is computed with the shipped builder helpers
(book_builder_common.matrix_on_grid / capped_inverse_vol / portfolio_daily /
book_metrics) on ONE shared day grid: the union of the trading days of all 41
union keys inside their common window.  The gate reference is ALWAYS the
deployed 24-sleeve live manifest with its deployed risk_percent weights.

Read-only except for the two sanctioned output directories.
NOT a minted manifest: no deployment, no AutoTrading, no live weights applied.
"""
from __future__ import annotations

import datetime as dt
import json
import math
import statistics
import sys
from pathlib import Path

sys.path.insert(0, r"C:\QM\repo")

from tools.strategy_farm.portfolio import build_book_dxz as bbd
from tools.strategy_farm.portfolio import concentration_tail
from tools.strategy_farm.portfolio.book_builder_common import (
    book_metrics,
    canonical_json,
    capped_inverse_vol,
    file_binding,
    matrix_on_grid,
    portfolio_daily,
    roster_sha256,
    sha256_bytes,
    shared_day_grid,
)
from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl

REPO = Path(r"C:\QM\repo")
BASE = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913")
OUT = BASE / "selective"
INC_MANIFEST = Path(r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json")
INC_STREAMS = Path(r"D:\QM\reports\portfolio\dxz_final_20260719")
V2_ROSTER = BASE / "roster_v2b.json"
V2_STREAMS = BASE / "streams_v2b"
CAPITAL = 100_000.0
TOTAL = 9.75
CAP = 1.0
BACKTEST_RISK_PCT = 1.0
EXCLUDE = {(41221, "EURUSD.DWX")}
DEAD = [(12778, "AUDUSD.DWX"), (13117, "EURGBP.DWX"), (12969, "USDJPY.DWX")]


def lbl(key):
    return f"{key[0]}:{key[1]}"


def ea_label(ea_id: int) -> str:
    hits = sorted((REPO / "framework" / "EAs").glob(f"QM5_{ea_id}_*"))
    return hits[0].name if hits else f"QM5_{ea_id}"


def main() -> int:
    inc_doc = json.loads(INC_MANIFEST.read_text(encoding="utf-8"))
    inc_keys = sorted((int(s["ea_id"]), s["symbol"]) for s in inc_doc["sleeves"])
    inc_w = {(int(s["ea_id"]), s["symbol"]): float(s["risk_percent"]) for s in inc_doc["sleeves"]}

    v2_doc = json.loads(V2_ROSTER.read_text(encoding="utf-8"))
    v2_rows = {(int(s["ea_id"]), s["symbol"]): s for s in v2_doc["sleeves"]}
    proposal_keys = sorted(k for k in v2_rows if k not in EXCLUDE)

    all_keys = sorted(set(inc_keys) | set(proposal_keys))
    overlaps = sorted(set(inc_keys) & set(proposal_keys))
    new_keys = sorted(set(proposal_keys) - set(inc_keys))

    # Ordered sealed roots, exactly as build_book_dxz._load_daily_sources:
    # proposal-declared keys come from the v2b bundle, the rest from dxz_final.
    streams = {}
    s1 = load_streams(V2_STREAMS, candidates=proposal_keys)
    streams.update({k: s1[k] for k in proposal_keys if k in s1})
    rest = [k for k in all_keys if k not in streams]
    s2 = load_streams(V2_STREAMS, candidates=rest)
    streams.update({k: s2[k] for k in rest if k in s2})
    rest = [k for k in all_keys if k not in streams]
    s3 = load_streams(INC_STREAMS, candidates=rest)
    streams.update({k: s3[k] for k in rest if k in s3})
    missing = sorted(set(all_keys) - set(streams))
    if missing:
        raise SystemExit(f"sealed stream basis is missing roster sleeves: {missing}")

    daily = {k: to_daily_pnl(streams[k]) for k in all_keys}
    start = max(min(daily[k]) for k in all_keys)
    end = min(max(daily[k]) for k in all_keys)
    grid = shared_day_grid(daily, all_keys, start, end)

    cache = {}

    def evaluate(keys, weights=None):
        ordered = sorted(keys)
        tag = (tuple(ordered), weights is not None)
        if tag in cache:
            return cache[tag]
        _, matrix = matrix_on_grid(daily, ordered, grid)
        w = weights if weights is not None else capped_inverse_vol(
            ordered, matrix, total=TOTAL, cap=CAP
        )
        m = book_metrics(portfolio_daily(ordered, matrix, w), len(ordered), CAPITAL)
        res = (ordered, matrix, w, m)
        cache[tag] = res
        return res

    # ---------- gate reference: the deployed 24 ----------
    ref_keys, ref_matrix, ref_w, ref_metrics = evaluate(inc_keys, inc_w)

    def gate(m):
        return bbd._gate(m, ref_metrics)

    def brief(m):
        return {
            "annual_return_pct": m["annual_return_pct"],
            "max_drawdown_pct": m["max_drawdown_pct"],
            "return_to_maxdd": m["return_to_maxdd"],
            "worst_day_pct": m["worst_day_pct"],
            "sharpe": m["sharpe"],
            "n_sleeves": m["n_sleeves"],
        }

    results = {}

    # ---------- baselines ----------
    var_i_keys = list(inc_keys)
    var_ii_keys = sorted(set(inc_keys) - set(DEAD))
    _, _, w_i_civ, m_i_civ = evaluate(var_i_keys)
    _, _, w_ii, m_ii = evaluate(var_ii_keys)

    results["baselines"] = {
        "gate_reference_deployed_24": {
            "weights": "AS_DEPLOYED_RISK_PERCENT",
            "sum_risk_percent": round(sum(inc_w.values()), 6),
            "metrics": brief(ref_metrics),
        },
        "variant_i_24_as_deployed": {
            "weights": "AS_DEPLOYED_RISK_PERCENT",
            "metrics": brief(ref_metrics),
            "gate_vs_deployed_24": gate(ref_metrics),
        },
        "variant_i_24_capped_inverse_vol": {
            "weights": "CAPPED_INVERSE_VOL_9.75_CAP_1.0",
            "metrics": brief(m_i_civ),
            "gate_vs_deployed_24": gate(m_i_civ),
        },
        "variant_ii_21_minus_dead_capped_inverse_vol": {
            "weights": "CAPPED_INVERSE_VOL_9.75_CAP_1.0",
            "dropped": [lbl(k) for k in sorted(DEAD)],
            "metrics": brief(m_ii),
            "gate_vs_deployed_24": gate(m_ii),
        },
    }

    # ---------- greedy forward selection ----------
    def greedy_forward(seed_keys, name):
        current = sorted(seed_keys)
        _, _, _, cur_m = evaluate(current)
        path = [{
            "step": 0,
            "action": "SEED",
            "added": None,
            "n_sleeves": len(current),
            "metrics": brief(cur_m),
            "gate": gate(cur_m),
        }]
        already = [lbl(k) for k in proposal_keys if k in set(current)]
        step = 0
        while True:
            step += 1
            best = None
            rejected = []
            for cand in proposal_keys:
                if cand in set(current):
                    continue
                trial = sorted(set(current) | {cand})
                try:
                    _, _, _, m = evaluate(trial)
                except Exception as exc:  # fail-closed, recorded
                    rejected.append({"candidate": lbl(cand), "broke": f"EVAL_ERROR:{exc}"})
                    continue
                g = gate(m)
                if not g["passed"]:
                    broke = sorted(n for n, ok in g["checks"].items() if not ok)
                    rejected.append({
                        "candidate": lbl(cand), "broke": broke,
                        "return_to_maxdd": m["return_to_maxdd"],
                        "max_drawdown_pct": m["max_drawdown_pct"],
                        "worst_day_pct": m["worst_day_pct"],
                    })
                    continue
                if m["return_to_maxdd"] <= cur_m["return_to_maxdd"]:
                    rejected.append({
                        "candidate": lbl(cand), "broke": ["NO_RET_DD_IMPROVEMENT"],
                        "return_to_maxdd": m["return_to_maxdd"],
                        "max_drawdown_pct": m["max_drawdown_pct"],
                        "worst_day_pct": m["worst_day_pct"],
                    })
                    continue
                score = (m["return_to_maxdd"], -m["max_drawdown_pct"], m["sharpe"] or 0.0)
                if best is None or score > best[0]:
                    best = (score, cand, m)
            if best is None:
                path.append({
                    "step": step, "action": "STOP",
                    "reason": "no candidate both passes the gate and improves return/maxDD",
                    "rejected": sorted(rejected, key=lambda r: r["candidate"]),
                })
                break
            _, cand, m = best
            current = sorted(set(current) | {cand})
            cur_m = m
            path.append({
                "step": step, "action": "ADD", "added": lbl(cand),
                "n_sleeves": len(current), "metrics": brief(m), "gate": gate(m),
                "rejected": sorted(rejected, key=lambda r: r["candidate"]),
            })
        return {
            "seed": name,
            "seed_sleeves": len(seed_keys),
            "candidates_considered": len(proposal_keys),
            "candidates_already_in_seed": already,
            "path": path,
            "final_keys": [lbl(k) for k in current],
            "final_metrics": brief(cur_m),
            "final_gate": gate(cur_m),
        }, current, cur_m

    fwd_ii, keys_ii, m_fwd_ii = greedy_forward(var_ii_keys, "variant_ii_21_minus_dead")
    fwd_i, keys_i, m_fwd_i = greedy_forward(var_i_keys, "variant_i_24_as_deployed_set")
    results["greedy_forward_from_variant_ii"] = fwd_ii
    results["greedy_forward_from_variant_i"] = fwd_i

    # ---------- relaxed forward (gate only at termination) ----------
    # The strict rule above requires the gate to hold at EVERY step.  Variant (ii)
    # starts 0.84 pp of maxDD BELOW the bar, so no single addition can repair it and
    # the strict search stops at step 1.  This relaxed pass keeps the identical
    # improvement rule (return/maxDD, tie-break maxDD then Sharpe) but scores the
    # gate only as a property of each intermediate state, so the best gate-PASS
    # book reachable from (ii) is not hidden behind a myopic first step.
    def greedy_relaxed(seed_keys, name):
        current = sorted(seed_keys)
        _, _, _, cur_m = evaluate(current)
        states = [{"step": 0, "added": None, "n_sleeves": len(current),
                   "metrics": brief(cur_m), "gate_passed": gate(cur_m)["passed"],
                   "keys": [lbl(k) for k in current]}]
        step = 0
        while True:
            step += 1
            best = None
            for cand in proposal_keys:
                if cand in set(current):
                    continue
                trial = sorted(set(current) | {cand})
                try:
                    _, _, _, m = evaluate(trial)
                except Exception:
                    continue
                if m["return_to_maxdd"] <= cur_m["return_to_maxdd"]:
                    continue
                score = (m["return_to_maxdd"], -m["max_drawdown_pct"], m["sharpe"] or 0.0)
                if best is None or score > best[0]:
                    best = (score, cand, m)
            if best is None:
                break
            _, cand, m = best
            current = sorted(set(current) | {cand})
            cur_m = m
            states.append({"step": step, "added": lbl(cand), "n_sleeves": len(current),
                           "metrics": brief(m), "gate_passed": gate(m)["passed"],
                           "keys": [lbl(k) for k in current]})
        passing = [s for s in states if s["gate_passed"]]
        best_pass = max(passing, key=lambda s: (s["metrics"]["return_to_maxdd"],
                                                -s["metrics"]["max_drawdown_pct"])) if passing else None
        return {"seed": name, "path": states,
                "first_gate_pass_step": passing[0]["step"] if passing else None,
                "best_gate_pass": best_pass,
                "terminal_metrics": brief(cur_m),
                "terminal_gate": gate(cur_m)}

    results["greedy_relaxed_from_variant_ii"] = greedy_relaxed(
        var_ii_keys, "variant_ii_21_minus_dead_gate_at_termination_only")

    # ---------- greedy backward pruning from the full union ----------
    cur = sorted(all_keys)
    _, _, _, m = evaluate(cur)
    back_path = [{"step": 0, "action": "SEED_FULL_UNION", "n_sleeves": len(cur),
                  "metrics": brief(m), "gate": gate(m)}]
    removed = []
    step = 0
    while not gate(m)["passed"] and len(cur) > 3:
        step += 1
        best = None
        for k in cur:
            trial = [x for x in cur if x != k]
            try:
                _, _, _, mm = evaluate(trial)
            except Exception:
                continue
            score = (mm["return_to_maxdd"], -mm["max_drawdown_pct"], mm["sharpe"] or 0.0)
            if best is None or score > best[0]:
                best = (score, k, mm)
        if best is None:
            break
        _, k, mm = best
        cur = [x for x in cur if x != k]
        m = mm
        removed.append(lbl(k))
        back_path.append({"step": step, "action": "REMOVE", "removed": lbl(k),
                          "n_sleeves": len(cur), "metrics": brief(mm), "gate": gate(mm)})
    results["greedy_backward_from_full_union"] = {
        "seed_sleeves": len(all_keys),
        "removed_order": removed,
        "removed_set": sorted(removed),
        "path": back_path,
        "final_keys": [lbl(x) for x in cur],
        "final_metrics": brief(m),
        "final_gate": gate(m),
    }
    back_keys, back_m = list(cur), m

    # ---------- pick the final book ----------
    def unlbl(text):
        ea, _, sym = text.partition(":")
        return (int(ea), sym)

    cands = [
        ("greedy_forward_from_variant_ii", keys_ii, m_fwd_ii),
        ("greedy_forward_from_variant_i", keys_i, m_fwd_i),
        ("greedy_backward_from_full_union", back_keys, back_m),
    ]
    relaxed = results["greedy_relaxed_from_variant_ii"]["best_gate_pass"]
    if relaxed:
        rk = sorted(unlbl(x) for x in relaxed["keys"])
        _, _, _, rm = evaluate(rk)
        cands.append(("greedy_relaxed_from_variant_ii", rk, rm))
    passing = [c for c in cands if gate(c[2])["passed"]]
    ranked = sorted(
        passing,
        key=lambda c: (c[2]["return_to_maxdd"], -c[2]["max_drawdown_pct"], c[2]["sharpe"] or 0.0),
        reverse=True,
    )
    if not ranked:
        raise SystemExit("no searched variant passes the gate")
    sel_name, sel_keys, sel_m = ranked[0]
    results["selection"] = {
        "chosen_route": sel_name,
        "rule": "highest return/maxDD among gate-PASS routes; tie-break lower maxDD, then Sharpe",
        "route_comparison": [
            {"route": n, "n_sleeves": len(k), "gate_passed": gate(mm)["passed"], **brief(mm)}
            for n, k, mm in cands
        ],
    }

    sel_keys = sorted(sel_keys)
    _, sel_matrix, sel_w, sel_m = evaluate(sel_keys)

    # ---------- robustness ----------
    def pearson(a, b):
        n = len(a)
        ma, mb = sum(a) / n, sum(b) / n
        va = sum((x - ma) ** 2 for x in a)
        vb = sum((x - mb) ** 2 for x in b)
        if va <= 0 or vb <= 0:
            return None
        cov = sum((a[i] - ma) * (b[i] - mb) for i in range(n))
        return cov / math.sqrt(va * vb)

    series = {k: [daily[k].get(d, 0.0) for d in grid] for k in sel_keys}
    corr, coact, flagged = {}, {}, []
    for i, a in enumerate(sel_keys):
        for b in sel_keys[i + 1:]:
            r = pearson(series[a], series[b])
            co = sum(1 for t in range(len(grid)) if series[a][t] != 0.0 and series[b][t] != 0.0)
            key = f"{lbl(a)}|{lbl(b)}"
            corr[key] = None if r is None else round(r, 6)
            coact[key] = co
            if r is not None and abs(r) >= 0.5:
                flagged.append({"pair": key, "r": round(r, 6), "co_active_days": co})
    wsum = sum(sel_w.values())
    wn = [sel_w[k] / wsum for k in sel_keys]
    num = 0.0
    for i, a in enumerate(sel_keys):
        for j, b in enumerate(sel_keys):
            if i == j:
                rho = 1.0
            else:
                key = f"{lbl(a)}|{lbl(b)}" if i < j else f"{lbl(b)}|{lbl(a)}"
                rho = corr.get(key)
                rho = 0.0 if rho is None else rho
            num += wn[i] * wn[j] * rho
    enb = (1.0 / num) if num > 0 else None

    conc = concentration_tail.evaluate(
        keys=sel_keys, weights=sel_w, dates=grid, matrix=sel_matrix,
        streams={k: streams[k] for k in sel_keys}, starting_capital=CAPITAL,
        policy_path=concentration_tail.DEFAULT_POLICY_PATH,
        symbol_matrix_path=concentration_tail.DEFAULT_SYMBOL_MATRIX, repo_root=REPO,
    )

    def vol_stats(key):
        vols = [t.volume for t in streams[key] if t.volume > 0]
        return {
            "volume_min": min(vols) if vols else None,
            "volume_median": round(statistics.median(vols), 4) if vols else None,
            "volume_max": max(vols) if vols else None,
            "n_trades": len(streams[key]),
        }

    sleeves = []
    for k in sel_keys:
        vs = vol_stats(k)
        vmed, vmax, vmin = vs["volume_median"], vs["volume_max"], vs["volume_min"]
        sleeves.append({
            "ea_id": k[0],
            "symbol": k[1],
            "ea_label": v2_rows[k]["ea_label"] if k in v2_rows else ea_label(k[0]),
            "magic": (v2_rows[k].get("magic_number") if k in v2_rows else None),
            "weight_risk_percent": round(sel_w[k], 6),
            "capped_at_sleeve_cap": abs(sel_w[k] - CAP) < 1e-9,
            "already_live": k in set(inc_keys),
            "live_risk_percent": inc_w.get(k),
            "in_v2b_candidate_roster": k in set(proposal_keys),
            "stream_source": str(V2_STREAMS) if k in set(proposal_keys) else str(INC_STREAMS),
            "standalone": vs,
            "min_lot_risk_percent": {
                "note": "streams are RISK_FIXED $1000 on 100k = 1.0 %/trade; lots scale linearly",
                "median_trade_hits_0.01_lots_at_pct": round(0.01 / vmed * BACKTEST_RISK_PCT, 4) if vmed else None,
                "largest_trade_hits_0.01_lots_at_pct": round(0.01 / vmax * BACKTEST_RISK_PCT, 4) if vmax else None,
                "smallest_trade_hits_0.01_lots_at_pct": round(0.01 / vmin * BACKTEST_RISK_PCT, 4) if vmin else None,
            },
        })

    results["final_book"] = {
        "route": sel_name,
        "n_sleeves": len(sel_keys),
        "keys": [lbl(k) for k in sel_keys],
        "metrics": brief(sel_m),
        "gate_vs_deployed_24": gate(sel_m),
        "sum_risk_percent": round(sum(sel_w.values()), 6),
        "enb_weighted": None if enb is None else round(enb, 4),
        "max_abs_pairwise_correlation": max((abs(v) for v in corr.values() if v is not None), default=None),
        "flagged_correlations_ge_0.5": sorted(flagged, key=lambda x: -abs(x["r"])),
        "overlaps_live_and_v2b": [lbl(k) for k in overlaps],
        "overlaps_in_final_book": [lbl(k) for k in overlaps if k in set(sel_keys)],
        "new_sleeves_added": [lbl(k) for k in sel_keys if k not in set(inc_keys)],
        "live_sleeves_dropped": [lbl(k) for k in inc_keys if k not in set(sel_keys)],
        "concentration_tail": {
            "builder_eligible": conc.get("builder_eligible"),
            "concentration_reject": conc.get("concentration_reject"),
            "policy_status": conc.get("policy_status"),
        },
        "sleeves": sleeves,
    }

    # ---------- sensitivity: backward polish of the selected book ----------
    # Informational only; it does NOT change the selected roster.  It answers
    # "is the forward greedy leaving an obviously better gate-PASS book behind?"
    pol = list(sel_keys)
    _, _, _, pol_m = evaluate(pol)
    pol_removed = []
    while True:
        best = None
        for k in pol:
            trial = [x for x in pol if x != k]
            if len(trial) < 5:
                continue
            try:
                _, _, _, mm = evaluate(trial)
            except Exception:
                continue
            if not gate(mm)["passed"] or mm["return_to_maxdd"] <= pol_m["return_to_maxdd"]:
                continue
            score = (mm["return_to_maxdd"], -mm["max_drawdown_pct"], mm["sharpe"] or 0.0)
            if best is None or score > best[0]:
                best = (score, k, mm)
        if best is None:
            break
        _, k, mm = best
        pol = [x for x in pol if x != k]
        pol_m = mm
        pol_removed.append(lbl(k))
    results["sensitivity_backward_polish_of_selected"] = {
        "note": "informational cross-check; the selected roster is NOT changed by this pass",
        "removed_order": pol_removed,
        "n_sleeves": len(pol),
        "metrics": brief(pol_m),
        "gate_vs_deployed_24": gate(pol_m),
        "keys": [lbl(x) for x in sorted(pol)],
    }

    # ---------- deployability check: the final book without the 3 dead live sleeves ----------
    live_minus_dead = sorted(set(sel_keys) - set(DEAD))
    dead_in_final = [lbl(k) for k in sorted(DEAD) if k in set(sel_keys)]
    if live_minus_dead != sel_keys:
        _, md_matrix, md_w, md_m = evaluate(live_minus_dead)
        md_conc = concentration_tail.evaluate(
            keys=live_minus_dead, weights=md_w, dates=grid, matrix=md_matrix,
            streams={k: streams[k] for k in live_minus_dead}, starting_capital=CAPITAL,
            policy_path=concentration_tail.DEFAULT_POLICY_PATH,
            symbol_matrix_path=concentration_tail.DEFAULT_SYMBOL_MATRIX, repo_root=REPO,
        )
        results["deployability_final_book_minus_dead_sleeves"] = {
            "why": ("12778:AUDUSD, 13117:EURGBP and 12969:USDJPY never trade in production "
                    "(docs/ops/evidence/2026-09-02_dark_live_sleeves_disposition.md). Their "
                    "sealed backtest streams still carry PnL, so any book that keeps them "
                    "books diversification it will not receive live."),
            "dead_sleeves_in_final_book": dead_in_final,
            "n_sleeves": len(live_minus_dead),
            "metrics": brief(md_m),
            "gate_vs_deployed_24": gate(md_m),
            "sum_risk_percent": round(sum(md_w.values()), 6),
            "concentration_tail": {
                "builder_eligible": md_conc.get("builder_eligible"),
                "concentration_reject": md_conc.get("concentration_reject"),
            },
        }

    results["basis"] = {
        "schema": "qm.dxz-selective-union-search/v1",
        "NOT_A_MINTED_MANIFEST": (
            "Analysis evidence only. No deployment, no AutoTrading, no live weight application. "
            "OWNER authority is untouched."
        ),
        "grid": "SHARED_COMMON_DAY_GRID_UNION_OF_ALL_41_UNION_KEYS",
        "window": {"start": start.isoformat(), "end": end.isoformat(), "days": len(grid)},
        "starting_capital": CAPITAL,
        "total_risk_pct": TOTAL,
        "sleeve_cap_pct": CAP,
        "weighting": "CAPPED_INVERSE_VOL_DAILY_PNL (incumbent reference keeps its deployed risk_percent)",
        "gate_rule": "ALL: return/maxDD >= incumbent; worst-day >= incumbent; maxDD <= incumbent",
        "gate_reference": "deployed 24-sleeve live manifest, deployed weights, same grid",
        "excluded_pairs": [lbl(k) for k in sorted(EXCLUDE)],
        "dead_live_sleeves": [lbl(k) for k in sorted(DEAD)],
        "union_keys": len(all_keys),
        "incumbent_input": file_binding(INC_MANIFEST),
        "proposal_roster_input": file_binding(V2_ROSTER),
        "proposal_stream_root": str(V2_STREAMS),
        "incumbent_stream_root": str(INC_STREAMS),
        "generated_utc": dt.datetime.now(dt.UTC).isoformat(),
    }
    results["correlation_matrix"] = corr
    results["co_active_days"] = coact
    results["concentration_tail_full"] = conc

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "selection_analysis.json").write_text(
        json.dumps(results, indent=2, sort_keys=True, default=str) + "\n", encoding="utf-8")

    # burnin.py input shape
    preview = {
        "schema": "qm.dxz-book-v2-analytic-preview/v1",
        "variant": "SELECTED",
        "status": "GATE_PASS_ANALYTIC" if gate(sel_m)["passed"] else "NOT_WORSE_BAR_NOT_MET",
        "sleeves": sleeves,
        "comparison": {"proposal": sel_m, "incumbent": ref_metrics,
                       "not_worse_gate": gate(sel_m),
                       "window": {"start": start.isoformat(), "end": end.isoformat(),
                                  "days": len(grid)}},
        "roster_sha256": roster_sha256([{"ea_id": k[0], "symbol": k[1]} for k in sel_keys]),
    }
    (OUT / "analytic_preview_manifest_SELECTED.json").write_text(
        json.dumps(preview, indent=2, sort_keys=True, default=str) + "\n", encoding="utf-8")

    # Builder roster schema (manifest-compatible; resolve_roster accepts a sleeves list).
    # ``sleeves`` is the PROPOSAL side only -- the sleeves this book adds on top of the
    # live 24.  ``--union`` re-adds the incumbent 24 and de-duplicates, so the evaluated
    # roster is exactly the selected book.  Declaring the incumbent-only sleeves here
    # instead would make build_book_dxz source every sleeve from the v2b bundle (which
    # does not seal them) and the run would fail closed.
    proposal_side_keys = [k for k in sel_keys if k not in set(inc_keys)]
    roster_rows = []
    for k in proposal_side_keys:
        src = v2_rows.get(k)
        roster_rows.append({
            "ea_id": k[0],
            "symbol": k[1],
            "ea_label": (src or {}).get("ea_label", ea_label(k[0])),
            "already_live": k in set(inc_keys),
            "live_risk_percent": inc_w.get(k),
            "magic_number": (src or {}).get("magic_number"),
            "q14_terminal_verdict": (src or {}).get("q14_terminal_verdict"),
            "q14_evidence_path": (src or {}).get("q14_evidence_path"),
            "backtest_risk_fixed": 1000.0,
            "backtest_risk_percent": 0.0,
            "analysis_weight_risk_percent": round(sel_w[k], 6),
            "source": "V2B_CANDIDATE" if k in set(proposal_keys) else "INCUMBENT_LIVE_BOOK",
        })
    roster_doc = {
        "schema": "qm.dual-book-roster-input/v1-manifest-compatible",
        "book": "DXZ_4000090541",
        "lane": "Q11_DXZ",
        "as_of": "2026-09-13",
        "status": "PROPOSAL_DRY_RUN",
        "n_sleeves_proposal_side": len(roster_rows),
        "n_sleeves_evaluated_book_under_union": len(sel_keys),
        "selection_route": sel_name,
        "selected_book": [
            {"ea_id": k[0], "symbol": k[1],
             "ea_label": (v2_rows[k]["ea_label"] if k in v2_rows else ea_label(k[0])),
             "source": "V2B_CANDIDATE" if k in set(proposal_keys) else "INCUMBENT_LIVE_BOOK",
             "already_live": k in set(inc_keys),
             "analysis_weight_risk_percent": round(sel_w[k], 6)}
            for k in sel_keys
        ],
        "selected_book_roster_sha256": roster_sha256(
            [{"ea_id": k[0], "symbol": k[1]} for k in sel_keys]),
        "stream_root": str(V2_STREAMS),
        "incumbent_stream_root": str(INC_STREAMS),
        "reproduce_with": (
            "python -X utf8 tools/strategy_farm/portfolio/build_book_dxz.py "
            "--roster D:/QM/reports/portfolio/dxz_v2_20260913/selective/roster_selected.json "
            "--stream-root D:/QM/reports/portfolio/dxz_v2_20260913/streams_v2b "
            "--incumbent-stream-root D:/QM/reports/portfolio/dxz_final_20260719 --union "
            + " ".join(f"--exclude-pair {lbl(k)}" for k in inc_keys if k not in set(sel_keys))
            + " --analysis-only --as-of 2026-09-13"
        ),
        "builder_exclude_pairs": [lbl(k) for k in inc_keys if k not in set(sel_keys)],
        "generated_utc": dt.datetime.now(dt.UTC).isoformat(),
        "note": ("Analysis roster only. Deployment and AutoTrading remain OWNER-only; "
                 "this file mints nothing."),
        "sleeves": roster_rows,
    }
    (OUT / "roster_selected.json").write_text(
        json.dumps(roster_doc, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(json.dumps({
        "baselines": results["baselines"],
        "forward_ii": {"added": [p.get("added") for p in fwd_ii["path"] if p.get("action") == "ADD"],
                       "final": fwd_ii["final_metrics"], "gate": fwd_ii["final_gate"]["passed"]},
        "forward_i": {"added": [p.get("added") for p in fwd_i["path"] if p.get("action") == "ADD"],
                      "final": fwd_i["final_metrics"], "gate": fwd_i["final_gate"]["passed"]},
        "backward": {"removed": removed, "final": results["greedy_backward_from_full_union"]["final_metrics"],
                     "gate": results["greedy_backward_from_full_union"]["final_gate"]["passed"]},
        "final_book": {k: results["final_book"][k] for k in
                       ("route", "n_sleeves", "metrics", "sum_risk_percent", "enb_weighted",
                        "max_abs_pairwise_correlation", "concentration_tail",
                        "new_sleeves_added", "live_sleeves_dropped", "overlaps_in_final_book")},
    }, indent=2, sort_keys=True, default=str))
    print("-> " + str(OUT / "selection_analysis.json"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
