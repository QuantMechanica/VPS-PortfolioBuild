"""Evaluate one frozen causal FTMO launch model on sealed holdout years."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from . import ftmo_bar_governor_sim as governor
    from .ftmo_causal_launch_model_screen import (
        FrozenRidge,
        feature_row,
        model_score,
    )
    from .ftmo_launch_gate_screen import (
        _parse_ints,
        _simulate,
        summarize_subset,
        weighted_daily_pnl,
    )
    from .ftmo_market_launch_gate_screen import CORE_SYMBOLS
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    from ftmo_causal_launch_model_screen import (  # type: ignore
        FrozenRidge,
        feature_row,
        model_score,
    )
    from ftmo_launch_gate_screen import (  # type: ignore
        _parse_ints,
        _simulate,
        summarize_subset,
        weighted_daily_pnl,
    )
    from ftmo_market_launch_gate_screen import CORE_SYMBOLS  # type: ignore


def frozen_selection(
    selection: Mapping[str, Any],
    requested_model_id: str,
) -> tuple[str, float, dict[str, FrozenRidge]]:
    if selection.get("status") != "PREHOLDOUT_SURVIVOR":
        raise ValueError("selection artifact has no pre-holdout survivor")
    contract = selection.get("selection_contract")
    if not isinstance(contract, Mapping) or contract.get("selection_uses_sealed_years") is not False:
        raise ValueError("selection artifact does not prove sealed-year exclusion")
    winner = selection.get("selected_winner")
    if not isinstance(winner, Mapping) or winner.get("model_id") != requested_model_id:
        raise ValueError("requested model does not match the frozen selected winner")
    mode = str(winner.get("score_mode"))
    if mode not in {"joint", "minimum", "mean"}:
        raise ValueError("frozen score mode is invalid")
    score_cutoff = float(winner.get("score_threshold"))
    if not math.isfinite(score_cutoff):
        raise ValueError("frozen score threshold is invalid")
    payloads = winner.get("frozen_models")
    if not isinstance(payloads, Mapping):
        raise ValueError("frozen models are missing")
    required = ("joint",) if mode == "joint" else ("threshold", "adverse")
    if set(payloads) != set(required):
        raise ValueError("frozen model set does not match score mode")
    models = {
        name: FrozenRidge.from_json(payloads[name])
        for name in required
    }
    return mode, score_cutoff, models


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--selection", type=Path, required=True)
    parser.add_argument("--model-id", required=True)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--holdout-years", default="2024,2025")
    parser.add_argument("--outcome-excluded-years", default="2017,2018,2019,2020,2021,2022,2023")
    parser.add_argument("--path-excluded-years", default="2017,2018,2019,2020,2021,2022")
    parser.add_argument("--horizon", type=int, default=30)
    parser.add_argument("--risk-multiplier", type=float, default=25.0)
    parser.add_argument("--daily-stop", type=float, default=4500.0)
    parser.add_argument("--full-risk-room", type=float, default=4000.0)
    parser.add_argument("--room-retention", type=float, default=0.2)
    parser.add_argument("--target-pass-pct", type=float, default=80.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    selection = json.loads(args.selection.read_text(encoding="utf-8-sig"))
    mode, score_cutoff, models = frozen_selection(selection, args.model_id)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    if selection.get("scenario") != args.scenario:
        parser.error("selection scenario does not match requested scenario")
    matching = [
        row for row in manifest.get("scenarios", []) if row.get("name") == args.scenario
    ]
    if len(matching) != 1:
        parser.error(f"expected one scenario {args.scenario!r}, found {len(matching)}")
    weights = {str(key): float(value) for key, value in matching[0]["weights"].items()}
    if not math.isclose(sum(weights.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        parser.error("scenario weights must sum to one")

    holdout_years = _parse_ints(args.holdout_years)
    outcome_excluded_years = _parse_ints(args.outcome_excluded_years)
    path_excluded_years = _parse_ints(args.path_excluded_years)
    if holdout_years & outcome_excluded_years or holdout_years & path_excluded_years:
        parser.error("holdout years must not be excluded")
    if not outcome_excluded_years.issuperset(path_excluded_years):
        parser.error("outcome exclusions must include path exclusions")

    cases, bars = governor.load_cases(
        manifest,
        bar_paths=governor.default_bar_paths(args.data_root),
    )
    missing_symbols = sorted(set(CORE_SYMBOLS) - set(bars))
    if missing_symbols:
        parser.error(f"missing core market bars: {missing_symbols}")
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
                excluded_years=path_excluded_years,
            )
        )
    entries = governor.index_entries(paths)
    start_days = [
        day
        for day in governor.valid_start_days(
            grid,
            horizon_days=args.horizon,
            excluded_years=outcome_excluded_years,
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
    daily_pnl = weighted_daily_pnl(grid, paths, weights)
    rows = {day: feature_row(day, daily_pnl, bars) for day in start_days}
    feature_names = tuple(next(iter(models.values())).feature_names)
    selected_mask: list[bool] = []
    for day in start_days:
        row = rows[day]
        if row is None or tuple(sorted(row)) != feature_names:
            selected_mask.append(False)
            continue
        selected_mask.append(model_score(row, models, mode) >= score_cutoff)

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
    normal_target_met = float(selected["threshold_fill"]["pass_pct"]) >= args.target_pass_pct
    adverse_target_met = float(selected["adverse_bar_fill"]["pass_pct"]) >= args.target_pass_pct
    target_met = normal_target_met and adverse_target_met
    artifact = {
        "schema_version": 1,
        "status": "TARGET_MET" if target_met else "TARGET_NOT_MET",
        "basis": "one_time_sealed_holdout_of_frozen_causal_launch_model",
        "manifest": str(args.manifest),
        "scenario": args.scenario,
        "selection_artifact": str(args.selection),
        "model_id": args.model_id,
        "score_mode": mode,
        "score_threshold": score_cutoff,
        "holdout_years": sorted(holdout_years),
        "outcome_excluded_years": sorted(outcome_excluded_years),
        "path_excluded_years": sorted(path_excluded_years),
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
        "target_met": target_met,
        "trade_paths": len(paths),
        "feature_complete_starts": sum(row is not None for row in rows.values()),
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
                "model_id": args.model_id,
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
