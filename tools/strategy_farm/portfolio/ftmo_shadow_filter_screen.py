"""Screen same-year per-sleeve shadow-PnL filters on a locked FTMO book.

Every rejected trade continues to exist in the shadow history, so deployment
requires an independent paper feed. Candidate selection uses development and
2023 validation only; sealed years are not simulated by this tool.
"""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from . import ftmo_bar_governor_sim as governor
    from .ftmo_launch_gate_screen import summarize_subset
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    from ftmo_launch_gate_screen import summarize_subset  # type: ignore


FILTERS = (
    "shadow_pnl_last_3_pos_same_year",
    "shadow_pnl_last_5_pos_same_year",
    "shadow_pnl_last_10_pos_same_year",
    "shadow_pnl_last_20_pos_same_year",
)


def robust_improvement(
    development: Mapping[str, Any],
    validation: Mapping[str, Any],
    control_development: Mapping[str, Any],
    control_validation: Mapping[str, Any],
    *,
    minimum_improvement_pct: float,
) -> bool:
    comparisons = (
        (development, control_development, "threshold_fill"),
        (development, control_development, "adverse_bar_fill"),
        (validation, control_validation, "threshold_fill"),
        (validation, control_validation, "adverse_bar_fill"),
    )
    return all(
        float(candidate[fill]["pass_pct"])
        >= float(control[fill]["pass_pct"]) + minimum_improvement_pct
        for candidate, control, fill in comparisons
    )


def _simulate(
    grid,
    entries,
    start_days,
    *,
    weights,
    horizon,
    risk_multiplier,
    daily_stop,
    full_risk_room,
    room_retention,
    threshold_fill,
):
    return [
        governor.simulate_window(
            grid,
            entries,
            start_day=day,
            horizon_days=horizon,
            weights=weights,
            risk_multiplier=risk_multiplier,
            daily_stop=daily_stop,
            full_risk_room=full_risk_room,
            room_retention=room_retention,
            threshold_fill=threshold_fill,
        )
        for day in start_days
    ]


def _parse_years(raw: str) -> set[int]:
    values = {int(value.strip()) for value in raw.split(",") if value.strip()}
    if not values:
        raise ValueError("year list is empty")
    return values


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"))
    parser.add_argument("--development-years", default="2018,2019,2021,2022")
    parser.add_argument("--validation-years", default="2023")
    parser.add_argument("--sealed-years", default="2017,2020,2024,2025")
    parser.add_argument("--horizon", type=int, default=30)
    parser.add_argument("--risk-multiplier", type=float, default=25.0)
    parser.add_argument("--daily-stop", type=float, default=4500.0)
    parser.add_argument("--full-risk-room", type=float, default=4000.0)
    parser.add_argument("--room-retention", type=float, default=0.2)
    parser.add_argument("--minimum-improvement-pct", type=float, default=1.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    matching = [row for row in manifest.get("scenarios", []) if row.get("name") == args.scenario]
    if len(matching) != 1:
        parser.error(f"expected one scenario {args.scenario!r}, found {len(matching)}")
    weights = {str(key): float(value) for key, value in matching[0]["weights"].items()}
    development_years = _parse_years(args.development_years)
    validation_years = _parse_years(args.validation_years)
    sealed_years = _parse_years(args.sealed_years)
    if development_years & validation_years or (development_years | validation_years) & sealed_years:
        parser.error("development, validation, and sealed years must be disjoint")

    base_cases, bars = governor.load_cases(
        manifest,
        bar_paths=governor.default_bar_paths(args.data_root),
    )
    grid = governor.common_grid(base_cases)
    all_starts = governor.valid_start_days(
        grid,
        horizon_days=args.horizon,
        excluded_years=sealed_years,
    )
    selected_years = development_years | validation_years
    start_days = [day for day in all_starts if day.year in selected_years]
    dev_indices = [index for index, day in enumerate(start_days) if day.year in development_years]
    val_indices = [index for index, day in enumerate(start_days) if day.year in validation_years]

    def build_paths(filter_name: str | None):
        paths = []
        for original_case in base_cases:
            case = copy.copy(original_case)
            if filter_name is None:
                case.pop("entry_filter", None)
            else:
                case["entry_filter"] = filter_name
            symbol = str(case["symbol"]).upper()
            aligned, observed = governor.align_bars_to_grid(bars[symbol], grid)
            paths.extend(
                governor.build_trade_paths(
                    case,
                    grid=grid,
                    aligned_bars=aligned,
                    observed_bar_timestamps=observed,
                    feature_bars=bars[symbol],
                    excluded_years=sealed_years,
                )
            )
        return paths

    def evaluate(paths):
        entries = governor.index_entries(paths)
        threshold = _simulate(
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
        adverse = _simulate(
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

        def split(indices):
            return summarize_subset(
                [start_days[index] for index in indices],
                [threshold[index] for index in indices],
                [adverse[index] for index in indices],
                [True] * len(indices),
            )

        return split(dev_indices), split(val_indices)

    control_paths = build_paths(None)
    control_development, control_validation = evaluate(control_paths)
    candidates: list[dict[str, Any]] = []
    for filter_name in FILTERS:
        paths = build_paths(filter_name)
        development, validation = evaluate(paths)
        improvements = [
            development["threshold_fill"]["pass_pct"]
            - control_development["threshold_fill"]["pass_pct"],
            development["adverse_bar_fill"]["pass_pct"]
            - control_development["adverse_bar_fill"]["pass_pct"],
            validation["threshold_fill"]["pass_pct"]
            - control_validation["threshold_fill"]["pass_pct"],
            validation["adverse_bar_fill"]["pass_pct"]
            - control_validation["adverse_bar_fill"]["pass_pct"],
        ]
        retained = len(paths) / len(control_paths) if control_paths else 0.0
        passed = retained >= 0.35 and robust_improvement(
            development,
            validation,
            control_development,
            control_validation,
            minimum_improvement_pct=args.minimum_improvement_pct,
        )
        candidates.append(
            {
                "entry_filter": filter_name,
                "trade_paths": len(paths),
                "path_retention_pct": 100.0 * retained,
                "development": development,
                "validation": validation,
                "improvements_pct": {
                    "development_threshold": improvements[0],
                    "development_adverse": improvements[1],
                    "validation_threshold": improvements[2],
                    "validation_adverse": improvements[3],
                },
                "preholdout_score": min(improvements),
                "preholdout_pass": passed,
            }
        )

    survivors = [row for row in candidates if row["preholdout_pass"]]
    winner = max(survivors, key=lambda row: row["preholdout_score"], default=None)
    candidates.sort(key=lambda row: row["preholdout_score"], reverse=True)
    artifact = {
        "schema_version": 1,
        "status": "PREHOLDOUT_SURVIVOR" if winner else "NO_PREHOLDOUT_SURVIVOR",
        "basis": "causal_same_year_per_sleeve_shadow_pnl_filter",
        "manifest": str(args.manifest),
        "scenario": args.scenario,
        "selection_contract": {
            "development_years": sorted(development_years),
            "validation_years": sorted(validation_years),
            "sealed_years_unopened": sorted(sealed_years),
            "candidate_filters": list(FILTERS),
            "minimum_path_retention_pct": 35.0,
            "minimum_improvement_pct_each_fill_and_split": args.minimum_improvement_pct,
            "shadow_trade_source": "all prior completed native strategy trades including rejected live trades",
            "year_boundary": "reset",
            "selection_uses_sealed_years": False,
        },
        "policy": {
            "horizon_calendar_days": args.horizon,
            "risk_multiplier": args.risk_multiplier,
            "daily_stop": args.daily_stop,
            "full_risk_room": args.full_risk_room,
            "room_retention": args.room_retention,
        },
        "control": {
            "trade_paths": len(control_paths),
            "development": control_development,
            "validation": control_validation,
        },
        "preholdout_survivor_count": len(survivors),
        "selected_winner": winner,
        "leaderboard": candidates,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "status": artifact["status"],
                "winner": winner["entry_filter"] if winner else None,
                "out": str(args.out),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
