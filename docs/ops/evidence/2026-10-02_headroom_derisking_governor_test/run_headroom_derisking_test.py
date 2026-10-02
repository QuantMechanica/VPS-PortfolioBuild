#!/usr/bin/env python3
"""Headroom/smooth-de-risking governor lever + phase-specific risk — task 16e8127e-dd8d-42ff-aa82-36aa2959a884.

SIMULATION ONLY. Imports the UNCHANGED engine (tools/strategy_farm/ftmo/{book_sim,first_passage,
governor_base}.py + tools/strategy_farm/research/governor_ladder.py) read-only from the canonical
checkout (C:/QM/repo); edits nothing there. See PREREGISTRATION.md (written before this script
ran) for the exact arm parameterization and admission rule.

Why a new driver instead of extending docs/ftmo/p80_lever_synthesis_2026-09-26/scripts/p80_levers.py
in place: that script's BASES dict only ever swaps the GovConfig passed to book_sim's single-grid
chain; it has no path to (a) run phase 1 under NO_GOVERNOR+overlay while phase 2/funded stay
ungoverned, or (b) feed stage 1 and stages 2-3 from two differently-risk-weighted grids. Both are
built here directly from first_passage._phase_walk/_funded_walk/_payout_frontier and
governor_base.phase_walk_gov, the same primitives p80_levers.py and governor_ladder.py already call.
"""
from __future__ import annotations

import datetime as dt
import json
import sys
import time
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

import numpy as np

REPO = Path(r"C:\QM\repo")
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm" / "research"))
import governor_ladder as gl  # noqa: E402
from tools.strategy_farm.ftmo import book_sim as bs  # noqa: E402
from tools.strategy_farm.ftmo import first_passage as fp  # noqa: E402
from tools.strategy_farm.ftmo import governor_base as gb  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE / "runs.jsonl"

N_PATHS = 40000
SEEDS = gl.SEEDS[:5]
BLOCK_LEN = gl.BLOCK_LEN
HORIZON = gl.HORIZON
FUNDED_HORIZON = fp.DEFAULT_FUNDED_HORIZON
N_BATCHES = 20
COST_SCENARIOS = (("normal", 1.0, 0.0), ("stress", 1.5, 2.0))


def rescale(sleeves: Sequence[Mapping[str, Any]], factor: float) -> list[dict[str, Any]]:
    if factor == 1.0:
        return list(sleeves)
    out = []
    for s in sleeves:
        o = dict(s)
        o["risk_percent"] = float(s["risk_percent"]) * factor
        out.append(o)
    return out


def stage1_v3(net, low, opened, idx, *, target, daily_cap, total_cap, min_days):
    """The deployed decision-base governor: V3 day-lock, phase 1 only (identical to p80_levers.BASES['GOVDR'])."""
    cfg = gb.GovConfig(daily_event="day_reset", trigger_basis="low", stages=("phase1",))
    return gb.phase_walk_gov(net, low, opened, idx, target=target, daily_cap=daily_cap, total_cap=total_cap,
                             min_days=min_days, cfg=cfg)


def make_stage1_overlay(warn: float, floor: float, line: float) -> Callable:
    """Phase 1 governed ONLY by a continuous headroom-responsive size scale: no internal hard floor,
    no halt/latch/day-lock event of any kind. The only thing that can end a path is the real
    official daily/total loss test, applied every day to the overlay-scaled P&L."""
    overlay = gb.overlay_cppi(warn=warn, floor=floor, max_loss_line=line)

    def fn(net, low, opened, idx, *, target, daily_cap, total_cap, min_days):
        return gb.phase_walk_gov(net, low, opened, idx, target=target, daily_cap=daily_cap, total_cap=total_cap,
                                 min_days=min_days, policy=gb.NO_GOVERNOR, cfg=gb.GovConfig(),
                                 overlay_factory=overlay)
    return fn


ARMS: dict[str, dict[str, Any]] = {
    "REF": {"stage1": stage1_v3, "challenge_factor": 1.0, "post_factor": 1.0},
    "E1_TIGHT": {"stage1": make_stage1_overlay(2000.0, 0.10, 9000.0), "challenge_factor": 1.0, "post_factor": 1.0},
    "E2_WIDE": {"stage1": make_stage1_overlay(4000.0, 0.25, 9500.0), "challenge_factor": 1.0, "post_factor": 1.0},
    "E3_ZEROFLOOR": {"stage1": make_stage1_overlay(3000.0, 0.00, 9500.0), "challenge_factor": 1.0, "post_factor": 1.0},
    "PR_050": {"stage1": stage1_v3, "challenge_factor": 1.0, "post_factor": 0.5},
    "PR_075": {"stage1": stage1_v3, "challenge_factor": 1.0, "post_factor": 0.75},
    "PR_075_CH125": {"stage1": stage1_v3, "challenge_factor": 1.25, "post_factor": 0.75},
}


def run_chain(challenge_sleeves, post_sleeves, start, end, *, seed: int, n_paths: int,
              cost_mult: float, slippage_usd_per_lot: float, rules, economics, stage1_fn) -> dict[str, Any]:
    roster_ch = bs._to_first_passage_roster(challenge_sleeves, start=start, end=end, timezone=str(rules["timezone"]))
    grid_ch = fp.build_grid(roster_ch["sleeves"])
    if post_sleeves is challenge_sleeves:
        grid_po = grid_ch
    else:
        roster_po = bs._to_first_passage_roster(post_sleeves, start=start, end=end, timezone=str(rules["timezone"]))
        grid_po = fp.build_grid(roster_po["sleeves"])
    if grid_ch["business_days"] != grid_po["business_days"]:
        raise RuntimeError("challenge/post grids diverged in window length: risk rescale must not move the active window")
    n_grid = int(grid_ch["business_days"])

    net_ch, low_ch, opened_ch = fp._cost_adjusted(grid_ch, cost_mult, slippage_usd_per_lot)
    if grid_po is grid_ch:
        net_po, low_po, opened_po = net_ch, low_ch, opened_ch
    else:
        net_po, low_po, opened_po = fp._cost_adjusted(grid_po, cost_mult, slippage_usd_per_lot)

    initial = rules["initial_equity"]
    daily_cap = rules["daily_loss_fraction"] * initial
    total_cap = rules["total_loss_fraction"] * initial
    min_days = int(rules["min_trading_days"])
    p1_target = rules["target_fraction"] * initial
    p2_target = rules["phase2_target_fraction"] * initial
    elig_bd = fp.calendar_to_business_days(fp.FUNDED_ELIGIBILITY_CALENDAR_DAYS)

    idx1 = fp._stage_index_matrix(seed, 1, n_grid, n_paths, HORIZON, BLOCK_LEN)
    w1 = stage1_fn(net_ch, low_ch, opened_ch, idx1, target=p1_target, daily_cap=daily_cap, total_cap=total_cap,
                   min_days=min_days)
    o1 = fp._resolve_phase(w1)
    del idx1

    idx2 = fp._stage_index_matrix(seed, 2, n_grid, n_paths, HORIZON, BLOCK_LEN)
    w2 = fp._phase_walk(net_po, low_po, opened_po, idx2, target=p2_target, daily_cap=daily_cap, total_cap=total_cap,
                        min_days=min_days)
    o2 = fp._resolve_phase(w2)
    del idx2

    idx3 = fp._stage_index_matrix(seed, 3, n_grid, n_paths, FUNDED_HORIZON, BLOCK_LEN)
    w3 = fp._funded_walk(net_po, low_po, opened_po, idx3, daily_cap=daily_cap, total_cap=total_cap,
                         eligibility_business_days=elig_bd, processing_business_days=fp.PAYOUT_PROCESSING_BUSINESS_DAYS)
    del idx3

    reached_funded = o1["passed"] & o2["passed"]
    end_to_end = reached_funded & w3["survived"]
    net_cash = fp.net_cash_from_profit(w3["profit_at_reward"], economics)
    net_positive = end_to_end & (net_cash > 0.0)
    all_days_total = (w1["pass_day"] + w2["pass_day"] + w3["payout_day"] + 3).astype(float)
    total_days_for_frontier = np.where(net_positive, all_days_total, 0).astype(np.int64)

    outcome_masks = {
        "positive_net_payout": net_positive,
        "phase1_daily_loss_breach": o1["is_daily"], "phase1_max_loss_breach": o1["is_total"], "phase1_censored": o1["censored"],
        "verification_daily_loss_breach": o1["passed"] & o2["is_daily"],
        "verification_max_loss_breach": o1["passed"] & o2["is_total"],
        "verification_censored": o1["passed"] & o2["censored"],
        "funded_daily_loss_breach": reached_funded & w3["is_daily"],
        "funded_max_loss_breach": reached_funded & w3["is_total"],
        "funded_censored": reached_funded & w3["censored"],
        "reward_not_net_positive": end_to_end & ~net_positive,
    }
    pf = fp._payout_frontier(net_positive, total_days_for_frontier, n_batches=N_BATCHES,
                             outcome_masks=outcome_masks, initial_equity=float(initial), economics=economics)
    lcb_interval = fp._batch_ci(net_positive, None, N_BATCHES)
    cond = (pf.get("conditional_on_positive_net_payout") or {}).get("business_days") or {}
    part = {k: v["probability"] for k, v in (pf.get("outcome_partition_unconditional") or {}).items()}
    return {
        "t80_bd": pf["unconditional_t80"].get("business_day"),
        "p80_point_bd": gl.quantile_day(net_positive, total_days_for_frontier, 0.8),
        "p50_point_bd": gl.quantile_day(net_positive, total_days_for_frontier, 0.5),
        "cond_p50_bd": cond.get("p50"),
        "lcb": lcb_interval["p05"],
        "p": fp._share(net_positive),
        "phase1_max_loss": part.get("phase1_max_loss_breach"),
        "phase1_daily_loss": part.get("phase1_daily_loss_breach"),
        "daily_loss_all_stages": round(sum(part.get(k, 0) or 0 for k in
                                           ("phase1_daily_loss_breach", "verification_daily_loss_breach", "funded_daily_loss_breach")), 6),
        "max_loss_all_stages": round(sum(part.get(k, 0) or 0 for k in
                                         ("phase1_max_loss_breach", "verification_max_loss_breach", "funded_max_loss_breach")), 6),
        "censored_share": round(sum(part.get(k, 0) or 0 for k in
                                    ("phase1_censored", "verification_censored", "funded_censored")), 6),
        "n_paths": int(n_paths),
    }


def main() -> int:
    sleeves, start, end, prov = gl.load_book()
    rules = fp.load_rules()
    economics = fp.load_economics()
    print(f"book loaded: {len(sleeves)} sleeves, window {start}..{end}, book risk "
          f"{sum(float(s['risk_percent']) for s in sleeves):.5f}%", flush=True)

    results: dict[str, list[dict[str, Any]]] = {name: [] for name in ARMS}
    fh = OUT.open("a", encoding="utf-8")
    try:
        for name, spec in ARMS.items():
            challenge = rescale(sleeves, spec["challenge_factor"])
            post = rescale(sleeves, spec["post_factor"]) if spec["post_factor"] != spec["challenge_factor"] else challenge
            for seed in SEEDS:
                row: dict[str, Any] = {}
                for cost_name, cost_mult, slip in COST_SCENARIOS:
                    t0 = time.time()
                    row[cost_name] = run_chain(challenge, post, start, end, seed=seed, n_paths=N_PATHS,
                                               cost_mult=cost_mult, slippage_usd_per_lot=slip, rules=rules,
                                               economics=economics, stage1_fn=spec["stage1"])
                    wall = round(time.time() - t0, 1)
                    print(f"{name} seed={seed} {cost_name}: t80={row[cost_name]['t80_bd']} "
                          f"p80pt={row[cost_name]['p80_point_bd']} lcb={row[cost_name]['lcb']} "
                          f"maxloss={row[cost_name]['max_loss_all_stages']} ({wall}s)", flush=True)
                rec = {"arm": name, "seed": seed, **row}
                fh.write(json.dumps(rec, sort_keys=True) + "\n")
                fh.flush()
                results[name].append(row)
    finally:
        fh.close()

    ref_rows = results["REF"]
    verdicts: dict[str, Any] = {}
    for name, rows in results.items():
        if name == "REF":
            continue
        dn = gl.paired_deltas(ref_rows, rows, "normal")
        ds = gl.paired_deltas(ref_rows, rows, "stress")
        decision = gl.decide(dn, ds)
        verdicts[name] = {"deltas_normal": dn, "deltas_stress": ds, "decision": decision}
        print(f"=== {name}: adopt={decision['adopt']} fails={decision['fails']}", flush=True)

    (HERE / "results.json").write_text(json.dumps({"ref": ref_rows, "verdicts": verdicts}, indent=1, default=str),
                                       encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
