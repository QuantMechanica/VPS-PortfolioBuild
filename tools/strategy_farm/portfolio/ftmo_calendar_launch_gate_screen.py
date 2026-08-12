"""Screen ex-ante calendar gates for launching a locked FTMO challenge book.

Calendar membership is known before a challenge starts and never changes trade
handling after launch. Candidates are selected on development plus validation
years; this tool does not load or evaluate the sealed holdout years.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

try:
    from . import ftmo_bar_governor_sim as governor
    from .ftmo_launch_gate_screen import _parse_ints, _simulate, summarize_subset
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    from ftmo_launch_gate_screen import _parse_ints, _simulate, summarize_subset  # type: ignore


CalendarGate = Callable[[Any], bool]


def calendar_gate_set() -> dict[str, CalendarGate]:
    gates: dict[str, CalendarGate] = {
        f"month_{month:02d}": lambda day, month=month: day.month == month
        for month in range(1, 13)
    }
    gates.update(
        {
            f"quarter_{quarter}": (
                lambda day, quarter=quarter: (day.month - 1) // 3 + 1 == quarter
            )
            for quarter in range(1, 5)
        }
    )
    gates.update(
        {
            "half_1": lambda day: day.month <= 6,
            "half_2": lambda day: day.month >= 7,
            **{
                f"weekday_{weekday}": (
                    lambda day, weekday=weekday: day.weekday() == weekday
                )
                for weekday in range(7)
            },
            "month_day_01_10": lambda day: day.day <= 10,
            "month_day_11_20": lambda day: 11 <= day.day <= 20,
            "month_day_21_end": lambda day: day.day >= 21,
        }
    )
    return gates


def preholdout_pass(
    development: Mapping[str, Any],
    validation: Mapping[str, Any],
    control_development: Mapping[str, Any],
    control_validation: Mapping[str, Any],
    *,
    minimum_floor_pct: float,
    minimum_improvement_pct: float,
    minimum_development_starts: int,
    minimum_validation_starts: int,
    minimum_eligible_pct: float,
) -> bool:
    if development["eligible_starts"] < minimum_development_starts:
        return False
    if validation["eligible_starts"] < minimum_validation_starts:
        return False
    if development["eligible_pct"] < minimum_eligible_pct:
        return False
    if validation["eligible_pct"] < minimum_eligible_pct:
        return False
    comparisons = (
        (development, control_development, "threshold_fill"),
        (development, control_development, "adverse_bar_fill"),
        (validation, control_validation, "threshold_fill"),
        (validation, control_validation, "adverse_bar_fill"),
    )
    return all(
        float(candidate[fill]["pass_pct"]) >= minimum_floor_pct
        and float(candidate[fill]["pass_pct"])
        >= float(control[fill]["pass_pct"]) + minimum_improvement_pct
        for candidate, control, fill in comparisons
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--development-years", default="2018,2019,2021,2022")
    parser.add_argument("--validation-years", default="2023")
    parser.add_argument("--sealed-years", default="2017,2020,2024,2025")
    parser.add_argument("--horizon", type=int, default=30)
    parser.add_argument("--risk-multiplier", type=float, default=25.0)
    parser.add_argument("--daily-stop", type=float, default=4500.0)
    parser.add_argument("--full-risk-room", type=float, default=4000.0)
    parser.add_argument("--room-retention", type=float, default=0.2)
    parser.add_argument("--minimum-floor-pct", type=float, default=60.0)
    parser.add_argument("--minimum-improvement-pct", type=float, default=5.0)
    parser.add_argument("--minimum-development-starts", type=int, default=80)
    parser.add_argument("--minimum-validation-starts", type=int, default=15)
    parser.add_argument("--minimum-eligible-pct", type=float, default=5.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    matching = [
        row for row in manifest.get("scenarios", []) if row.get("name") == args.scenario
    ]
    if len(matching) != 1:
        parser.error(f"expected one scenario {args.scenario!r}, found {len(matching)}")
    weights = {str(key): float(value) for key, value in matching[0]["weights"].items()}
    if not math.isclose(sum(weights.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        parser.error("scenario weights must sum to one")

    development_years = _parse_ints(args.development_years)
    validation_years = _parse_ints(args.validation_years)
    sealed_years = _parse_ints(args.sealed_years)
    if development_years & validation_years or (development_years | validation_years) & sealed_years:
        parser.error("development, validation, and sealed years must be disjoint")

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
                excluded_years=sealed_years,
            )
        )
    entries = governor.index_entries(paths)
    selected_years = development_years | validation_years
    start_days = [
        day
        for day in governor.valid_start_days(
            grid,
            horizon_days=args.horizon,
            excluded_years=sealed_years,
        )
        if day.year in selected_years
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
    dev_indices = [index for index, day in enumerate(start_days) if day.year in development_years]
    val_indices = [index for index, day in enumerate(start_days) if day.year in validation_years]

    def subset(indices: Sequence[int], mask: Sequence[bool]) -> dict[str, Any]:
        return summarize_subset(
            [start_days[index] for index in indices],
            [threshold_results[index] for index in indices],
            [adverse_results[index] for index in indices],
            [mask[index] for index in indices],
        )

    control_mask = [True] * len(start_days)
    control_development = subset(dev_indices, control_mask)
    control_validation = subset(val_indices, control_mask)
    candidates: list[dict[str, Any]] = []
    for name, gate in calendar_gate_set().items():
        mask = [bool(gate(day)) for day in start_days]
        development = subset(dev_indices, mask)
        validation = subset(val_indices, mask)
        rates = [
            development["threshold_fill"]["pass_pct"],
            development["adverse_bar_fill"]["pass_pct"],
            validation["threshold_fill"]["pass_pct"],
            validation["adverse_bar_fill"]["pass_pct"],
        ]
        candidates.append(
            {
                "gate": name,
                "development": development,
                "validation": validation,
                "preholdout_score": min(float(value) for value in rates),
                "preholdout_pass": preholdout_pass(
                    development,
                    validation,
                    control_development,
                    control_validation,
                    minimum_floor_pct=args.minimum_floor_pct,
                    minimum_improvement_pct=args.minimum_improvement_pct,
                    minimum_development_starts=args.minimum_development_starts,
                    minimum_validation_starts=args.minimum_validation_starts,
                    minimum_eligible_pct=args.minimum_eligible_pct,
                ),
            }
        )

    survivors = [row for row in candidates if row["preholdout_pass"]]
    winner = max(
        survivors,
        key=lambda row: (row["preholdout_score"], row["validation"]["eligible_starts"]),
        default=None,
    )
    candidates.sort(key=lambda row: row["preholdout_score"], reverse=True)
    artifact = {
        "schema_version": 1,
        "status": "PREHOLDOUT_SURVIVOR" if winner else "NO_PREHOLDOUT_SURVIVOR",
        "basis": "calendar_membership_known_before_challenge_launch",
        "manifest": str(args.manifest),
        "scenario": args.scenario,
        "timestamp_basis": manifest.get("timestamp_basis", governor.TIMESTAMP_BASIS_UNIX_UTC),
        "selection_contract": {
            "candidate_gates": list(calendar_gate_set()),
            "development_years": sorted(development_years),
            "validation_years": sorted(validation_years),
            "sealed_years_unopened": sorted(sealed_years),
            "minimum_floor_pct_each_fill_and_split": args.minimum_floor_pct,
            "minimum_improvement_pct_each_fill_and_split": args.minimum_improvement_pct,
            "minimum_development_starts": args.minimum_development_starts,
            "minimum_validation_starts": args.minimum_validation_starts,
            "minimum_eligible_pct_each_split": args.minimum_eligible_pct,
            "selection_uses_sealed_years": False,
        },
        "policy": {
            "horizon_calendar_days": args.horizon,
            "risk_multiplier": args.risk_multiplier,
            "daily_stop": args.daily_stop,
            "full_risk_room": args.full_risk_room,
            "room_retention": args.room_retention,
        },
        "trade_paths": len(paths),
        "control": {
            "development": control_development,
            "validation": control_validation,
        },
        "candidate_count": len(candidates),
        "preholdout_survivor_count": len(survivors),
        "selected_winner": winner,
        "leaderboard": candidates,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "candidate_count": len(candidates),
                "survivor_count": len(survivors),
                "winner": winner["gate"] if winner else None,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
