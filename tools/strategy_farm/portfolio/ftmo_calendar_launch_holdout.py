"""Evaluate one frozen calendar launch gate on sealed FTMO holdout years."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any, Sequence

try:
    from . import ftmo_bar_governor_sim as governor
    from .ftmo_calendar_launch_gate_screen import calendar_gate_set
    from .ftmo_launch_gate_screen import _parse_ints, _simulate, summarize_subset
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    from ftmo_calendar_launch_gate_screen import calendar_gate_set  # type: ignore
    from ftmo_launch_gate_screen import _parse_ints, _simulate, summarize_subset  # type: ignore


def frozen_gate(selection: dict[str, Any], requested_gate: str):
    if selection.get("status") != "PREHOLDOUT_SURVIVOR":
        raise ValueError("selection artifact has no pre-holdout survivor")
    winner = selection.get("selected_winner")
    if not isinstance(winner, dict) or winner.get("gate") != requested_gate:
        raise ValueError("requested gate does not match the frozen selected winner")
    contract = selection.get("selection_contract")
    if not isinstance(contract, dict) or contract.get("selection_uses_sealed_years") is not False:
        raise ValueError("selection artifact does not prove sealed-year exclusion")
    gates = calendar_gate_set()
    if requested_gate not in gates:
        raise ValueError(f"unknown calendar gate: {requested_gate}")
    return gates[requested_gate]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--selection", type=Path, required=True)
    parser.add_argument("--gate", required=True)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--holdout-years", default="2024,2025")
    parser.add_argument("--excluded-years", default="2017,2018,2019,2020,2021,2022,2023")
    parser.add_argument("--horizon", type=int, default=30)
    parser.add_argument("--risk-multiplier", type=float, default=25.0)
    parser.add_argument("--daily-stop", type=float, default=4500.0)
    parser.add_argument("--full-risk-room", type=float, default=4000.0)
    parser.add_argument("--room-retention", type=float, default=0.2)
    parser.add_argument("--target-pass-pct", type=float, default=80.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    selection = json.loads(args.selection.read_text(encoding="utf-8-sig"))
    gate = frozen_gate(selection, args.gate)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    matching = [
        row for row in manifest.get("scenarios", []) if row.get("name") == args.scenario
    ]
    if len(matching) != 1:
        parser.error(f"expected one scenario {args.scenario!r}, found {len(matching)}")
    weights = {str(key): float(value) for key, value in matching[0]["weights"].items()}
    if not math.isclose(sum(weights.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        parser.error("scenario weights must sum to one")

    holdout_years = _parse_ints(args.holdout_years)
    excluded_years = _parse_ints(args.excluded_years)
    if holdout_years & excluded_years:
        parser.error("holdout and excluded years must be disjoint")

    cases, bars = governor.load_cases(
        manifest,
        bar_paths=governor.default_bar_paths(args.data_root),
    )
    grid = governor.common_grid(cases)
    paths: list[governor.GovernedTradePath] = []
    for case in cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = governor.align_bars_to_grid(bars[symbol], grid)
        paths.extend(
            governor.build_trade_paths(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
                feature_bars=bars[symbol],
                excluded_years=excluded_years,
            )
        )
    entries = governor.index_entries(paths)
    start_days = [
        day
        for day in governor.valid_start_days(
            grid,
            horizon_days=args.horizon,
            excluded_years=excluded_years,
        )
        if day.year in holdout_years
    ]
    threshold_results = _simulate(
        grid,
        entries,
        start_days,
        weights=weights,
        horizon=args.horizon,
        risk_multiplier=args.risk_multiplier,
        daily_stop=args.daily_stop,
        full_risk_room=args.full_risk_room,
        room_retention=args.room_retention,
        threshold_fill=True,
    )
    adverse_results = _simulate(
        grid,
        entries,
        start_days,
        weights=weights,
        horizon=args.horizon,
        risk_multiplier=args.risk_multiplier,
        daily_stop=args.daily_stop,
        full_risk_room=args.full_risk_room,
        room_retention=args.room_retention,
        threshold_fill=False,
    )
    selected_mask = [bool(gate(day)) for day in start_days]
    control = summarize_subset(
        start_days,
        threshold_results,
        adverse_results,
        [True] * len(start_days),
    )
    selected = summarize_subset(
        start_days,
        threshold_results,
        adverse_results,
        selected_mask,
    )
    normal_target_met = (
        float(selected["threshold_fill"]["pass_pct"]) >= args.target_pass_pct
    )
    adverse_target_met = (
        float(selected["adverse_bar_fill"]["pass_pct"]) >= args.target_pass_pct
    )
    artifact = {
        "schema_version": 1,
        "status": "NORMAL_TARGET_MET" if normal_target_met else "TARGET_NOT_MET",
        "basis": "one_time_sealed_holdout_of_frozen_calendar_launch_gate",
        "manifest": str(args.manifest),
        "scenario": args.scenario,
        "selection_artifact": str(args.selection),
        "gate": args.gate,
        "holdout_years": sorted(holdout_years),
        "excluded_years": sorted(excluded_years),
        "selection_uses_holdout": False,
        "policy": {
            "horizon_calendar_days": args.horizon,
            "risk_multiplier": args.risk_multiplier,
            "daily_stop": args.daily_stop,
            "full_risk_room": args.full_risk_room,
            "room_retention": args.room_retention,
        },
        "target_pass_pct": args.target_pass_pct,
        "normal_target_met": normal_target_met,
        "adverse_target_met": adverse_target_met,
        "trade_paths": len(paths),
        "control": control,
        "selected": selected,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "gate": args.gate,
                "eligible_starts": selected["eligible_starts"],
                "threshold_pass_pct": selected["threshold_fill"]["pass_pct"],
                "adverse_pass_pct": selected["adverse_bar_fill"]["pass_pct"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
