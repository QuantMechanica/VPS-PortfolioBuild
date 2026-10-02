#!/usr/bin/env python3
"""Headroom/smooth-de-risking governor lever test (task 16e8127e-dd8d-42ff-aa82-36aa2959a884), 2026-10-02.

SIMULATION ONLY. See 00_PREREGISTRATION.md for the sealed design and the prior-art audit. Reads the unchanged
engine from the canonical checkout (C:/QM/repo, read-only); writes only under this evidence directory.

H1 reuses governor_ladder_w3.measure_job verbatim (the sealed-but-never-run wave-3 cell design), with exactly one
monkeypatch: W3_BASE_CFG.daily_event = "day_reset" (the ratified V3 chain) instead of "latch" (the superseded V2
chain wave 3 was sealed against). H2 is new: a per-stage constant risk-scale multiplier via a local stage_hooks
contextmanager built from the same governor_base.py primitives (phase_walk_gov / funded_walk_gov / NO_GOVERNOR).

    python run_headroom_test.py run
    python run_headroom_test.py analyze
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Mapping

import numpy as np

REPO = Path(r"C:/QM/repo")
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm" / "research"))
import governor_ladder as gl  # noqa: E402
import governor_ladder_w3 as w3  # noqa: E402
from tools.strategy_farm.ftmo import book_sim as bs  # noqa: E402
from tools.strategy_farm.ftmo import first_passage as fp  # noqa: E402
from tools.strategy_farm.ftmo import governor_base as gb  # noqa: E402

HERE = Path(__file__).resolve().parent
RUN = HERE / "run"
N_PATHS = 40000
SEEDS = gl.SEEDS
ENGINE_FILES = {
    "book_sim.py": REPO / "tools/strategy_farm/ftmo/book_sim.py",
    "first_passage.py": REPO / "tools/strategy_farm/ftmo/first_passage.py",
    "governor_base.py": REPO / "tools/strategy_farm/ftmo/governor_base.py",
    "governor_ladder.py": REPO / "tools/strategy_farm/research/governor_ladder.py",
    "governor_ladder_w3.py": REPO / "tools/strategy_farm/research/governor_ladder_w3.py",
}

# ---- the one sanctioned change vs the sealed wave-3 spec: day_reset (V3, ratified) instead of latch (V2, superseded) ----
w3.W3_BASE_CFG = gb.GovConfig(daily_event="day_reset", trigger_basis="low", stages=("phase1",))
H1_WARNS = (5000.0, 6000.0, 7000.0, 8000.0)
H1_FLOORS = (0.15, 0.25, 0.35, 0.50)
w3.WARNS = H1_WARNS
w3.FLOORS = H1_FLOORS


def engine_hashes() -> dict[str, str]:
    import hashlib
    return {k: hashlib.sha256(v.read_bytes().replace(b"\r\n", b"\n")).hexdigest() for k, v in ENGINE_FILES.items()}


def h1_path(job: Mapping[str, Any], seed: int) -> Path:
    return RUN / "h1" / f"{job['name']}__{seed}.json"


def run_h1(sleeves, start, end) -> None:
    jobs = w3.arm_jobs()  # W3_BASE, UNGOVERNED_BASE, 16 cells (uses the patched WARNS/FLOORS)
    for job in jobs:
        for seed in SEEDS:
            path = h1_path(job, seed)
            if path.exists():
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            t0 = time.time()
            res = w3.measure_job(sleeves, start, end, seed, N_PATHS, job)
            res = res | {"job": dict(job), "seed": seed, "n_paths": N_PATHS, "wall_s": round(time.time() - t0, 1)}
            path.write_text(json.dumps(res, indent=1, sort_keys=True, default=str), encoding="utf-8")
            print(f"H1 {job['name']} seed {seed}: LCB {res['normal']['lcb']:.4f}/{res['stress']['lcb']:.4f} "
                  f"({res['wall_s']}s)", flush=True)


def load_h1() -> dict[str, list[dict[str, Any]]]:
    jobs = w3.arm_jobs()
    return {job["name"]: [json.loads(h1_path(job, s).read_text(encoding="utf-8")) for s in SEEDS] for job in jobs}


# --------------------------------------------------------------------------- H2: per-stage constant risk-scale multiplier
def overlay_const(k: float) -> gb.OverlayFactory:
    def factory(_n: int):
        return lambda cum: np.full(cum.shape, float(k), dtype=np.float64)
    return factory


@contextmanager
def stage_hooks(cfg: gb.GovConfig, overlays: Mapping[str, gb.OverlayFactory | None]):
    """Like gb.base_gov_hooks, but a DIFFERENT overlay per stage (base_gov_hooks shares one overlay for all three)."""
    orig_phase, orig_funded = fp._phase_walk, fp._funded_walk
    gb.GOV_DIAGS.clear()
    p1_target = gb.POLICIES[gb.STAGE_POLICY["phase1"]].target_balance - 100000.0

    def phase(net, low, opened, idx, *, target, daily_cap, total_cap, min_days):
        stage = "phase1" if abs(target - p1_target) < 1e-6 else "phase2"
        ov = overlays.get(stage)
        if stage not in cfg.stages:
            if ov is None:
                return orig_phase(net, low, opened, idx, target=target, daily_cap=daily_cap, total_cap=total_cap, min_days=min_days)
            return gb.phase_walk_gov(net, low, opened, idx, target=target, daily_cap=daily_cap, total_cap=total_cap, min_days=min_days,
                                      policy=gb.NO_GOVERNOR, cfg=cfg, overlay_factory=ov)
        return gb.phase_walk_gov(net, low, opened, idx, target=target, daily_cap=daily_cap, total_cap=total_cap, min_days=min_days,
                                  cfg=cfg, overlay_factory=ov)

    def funded(net, low, opened, idx, *, daily_cap, total_cap, eligibility_business_days, processing_business_days):
        ov = overlays.get("funded")
        if "funded" not in cfg.stages:
            if ov is None:
                return orig_funded(net, low, opened, idx, daily_cap=daily_cap, total_cap=total_cap,
                                    eligibility_business_days=eligibility_business_days,
                                    processing_business_days=processing_business_days)
            return gb.funded_walk_gov(net, low, opened, idx, daily_cap=daily_cap, total_cap=total_cap,
                                      eligibility_business_days=eligibility_business_days,
                                      processing_business_days=processing_business_days, policy=gb.NO_GOVERNOR, cfg=cfg,
                                      overlay_factory=ov)
        return gb.funded_walk_gov(net, low, opened, idx, daily_cap=daily_cap, total_cap=total_cap,
                                  eligibility_business_days=eligibility_business_days,
                                  processing_business_days=processing_business_days, cfg=cfg, overlay_factory=ov)

    fp._phase_walk, fp._funded_walk = phase, funded
    try:
        yield gb.GOV_DIAGS
    finally:
        fp._phase_walk, fp._funded_walk = orig_phase, orig_funded


H2_CFG = gb.GovConfig(daily_event="day_reset", trigger_basis="low", stages=("phase1",))
H2_ARMS: dict[str, dict[str, gb.OverlayFactory | None]] = {
    "H2_DERISK_ONLY": {"phase1": None, "phase2": overlay_const(0.6), "funded": overlay_const(0.8)},
    "H2_HOT_CHALLENGE": {"phase1": overlay_const(1.15), "phase2": overlay_const(0.6), "funded": overlay_const(0.8)},
}


def measure_h2(sleeves, start, end, seed: int, n_paths: int, overlays: Mapping[str, gb.OverlayFactory | None]) -> dict[str, Any]:
    rules = fp.load_rules()
    economics = fp.load_economics()
    roster = bs._to_first_passage_roster(sleeves, start=start, end=end, timezone=str(rules["timezone"]))

    def _build():
        return fp.build(roster=roster, rules=rules, economics=economics, seed=seed, n_paths=n_paths,
                         block_len=gl.BLOCK_LEN, horizon=gl.HORIZON, sensitivity=((1.0, 0.0), (1.5, 2.0)),
                         n_batches=min(20, max(2, n_paths // 100)), now=bs._parse_as_of(gl.AS_OF))

    with gl.engine_hooks(None):
        with stage_hooks(H2_CFG, overlays):
            passage = _build()
        caps = list(gl.CAPTURES)
    return gl.extract(passage, caps)


def h2_path(name: str, seed: int) -> Path:
    return RUN / "h2" / f"{name}__{seed}.json"


def run_h2(sleeves, start, end) -> None:
    for name, overlays in H2_ARMS.items():
        for seed in SEEDS:
            path = h2_path(name, seed)
            if path.exists():
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            t0 = time.time()
            res = measure_h2(sleeves, start, end, seed, N_PATHS, overlays)
            res = res | {"arm": name, "seed": seed, "n_paths": N_PATHS, "wall_s": round(time.time() - t0, 1)}
            path.write_text(json.dumps(res, indent=1, sort_keys=True, default=str), encoding="utf-8")
            print(f"H2 {name} seed {seed}: LCB {res['normal']['lcb']:.4f}/{res['stress']['lcb']:.4f} "
                  f"({res['wall_s']}s)", flush=True)


def load_h2() -> dict[str, list[dict[str, Any]]]:
    return {name: [json.loads(h2_path(name, s).read_text(encoding="utf-8")) for s in SEEDS] for name in H2_ARMS}


# --------------------------------------------------------------------------- admission rule (payload, literal)
def payload_admit(base: list[dict[str, Any]], arm: list[dict[str, Any]]) -> dict[str, Any]:
    """Adopt only if DeltaP80 < 0 AND DeltaLCB >= 0, every seed, both cost arms (the payload's literal rule)."""
    out: dict[str, Any] = {}
    fails: list[str] = []
    for cost in ("normal", "stress"):
        d = gl.paired_deltas(base, arm, cost)
        p80 = d["d_p80"]
        lcb = d["d_lcb"]
        p80_ok = all(x is not None and x < 0 for x in p80)
        lcb_ok = all(x is not None and x >= 0 for x in lcb)
        if not p80_ok:
            fails.append(f"{cost}:DELTA_P80_NOT_NEGATIVE_EVERY_SEED({[round(x,1) if isinstance(x,(int,float)) and x not in (float('inf'),float('-inf')) else x for x in p80]})")
        if not lcb_ok:
            fails.append(f"{cost}:DELTA_LCB_NOT_NONNEGATIVE_EVERY_SEED({[round(x,4) if x is not None else None for x in lcb]})")
        out[cost] = {"d_p80_per_seed": p80, "d_lcb_per_seed": lcb, "d_p80_key": d["p80_key"],
                     "mean_d_lcb": gl._mean(lcb), "mean_d_p80": gl._mean([x for x in p80 if isinstance(x, (int, float))])}
    out["adopt"] = not fails
    out["fails"] = fails
    return out


def cmd_run(_a: argparse.Namespace) -> int:
    sleeves, start, end, _ = gl.load_book()
    run_h1(sleeves, start, end)
    run_h2(sleeves, start, end)
    return 0


def cmd_analyze(_a: argparse.Namespace) -> int:
    h1 = load_h1()
    h2 = load_h2()
    base_h1 = h1["W3_BASE"]
    ungoverned = h1["UNGOVERNED_BASE"]
    cell_names = [n for n in h1 if n.startswith("W7-02G-")]
    cells = {n: h1[n] for n in cell_names}
    cell_clauses = {n: w3.cell_clauses(base_h1, rows) for n, rows in cells.items()}
    sign_stable = all(c[cost]["maxloss_down_every_seed"] and (c[cost]["d_lcb"] or 0) >= 0
                       for c in cell_clauses.values() for cost in w3.COSTS)
    payload_cells = {n: payload_admit(base_h1, rows) for n, rows in cells.items()}

    h2_base = h1["W3_BASE"]  # identical config to H2_REF; reused, not re-run
    h2_payload = {n: payload_admit(h2_base, rows) for n, rows in h2.items()}

    def summary_row(rows: list[dict[str, Any]]) -> dict[str, Any]:
        lcb_n = gl._mean([r["normal"]["lcb"] for r in rows])
        lcb_s = gl._mean([r["stress"]["lcb"] for r in rows])
        t80_n = gl._mean([r["normal"]["t80_bd"] for r in rows if r["normal"]["t80_bd"] is not None]) if any(r["normal"]["t80_bd"] is not None for r in rows) else None
        p80_n = gl._mean([r["normal"]["p80_point_bd"] for r in rows])
        maxloss_n = gl._mean([r["normal"]["phase1_max_loss"] for r in rows])
        censored_n = gl._mean([r["normal"]["censored_share"] for r in rows])
        return {"lcb_normal": lcb_n, "lcb_stress": lcb_s, "t80_bd_normal": t80_n, "point_p80_bd_normal": p80_n,
                "phase1_max_loss_normal": maxloss_n, "censored_normal": censored_n}

    out = {
        "generated_at": "2026-10-02",
        "n_paths": N_PATHS, "seeds": SEEDS,
        "engine_hashes": engine_hashes(),
        "decision_base_cfg": {"daily_event": w3.W3_BASE_CFG.daily_event, "trigger_basis": w3.W3_BASE_CFG.trigger_basis,
                               "stages": list(w3.W3_BASE_CFG.stages)},
        "h1": {
            "references": {"W3_BASE_GOVDR_dayreset": summary_row(base_h1), "UNGOVERNED_BASE": summary_row(ungoverned)},
            "cells_summary": {n: summary_row(rows) for n, rows in cells.items()},
            "wave3_sealed_cell_clauses": cell_clauses,
            "wave3_sign_stable_all_16": sign_stable,
            "wave3_cells_passing": sum(1 for c in cell_clauses.values() if c["pass"]),
            "payload_rule_delta_p80_lt0_and_delta_lcb_ge0": payload_cells,
            "payload_rule_cells_passing": sum(1 for c in payload_cells.values() if c["adopt"]),
        },
        "h2": {
            "reference": summary_row(h2_base),
            "arms_summary": {n: summary_row(rows) for n, rows in h2.items()},
            "payload_rule_delta_p80_lt0_and_delta_lcb_ge0": h2_payload,
            "payload_rule_arms_passing": sum(1 for c in h2_payload.values() if c["adopt"]),
        },
    }
    (HERE / "results.json").write_text(json.dumps(out, indent=1, sort_keys=True, default=str), encoding="utf-8")
    print(json.dumps({
        "h1_wave3_cells_passing_of_16": out["h1"]["wave3_cells_passing"],
        "h1_payload_cells_passing_of_16": out["h1"]["payload_rule_cells_passing"],
        "h2_payload_arms_passing_of_2": out["h2"]["payload_rule_arms_passing"],
    }, indent=1))
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("run")
    sub.add_parser("analyze")
    args = ap.parse_args(argv)
    return {"run": cmd_run, "analyze": cmd_analyze}[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
