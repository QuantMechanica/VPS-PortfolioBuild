"""Screen predeclared realized-volatility FTMO governor policies on development data."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from . import ftmo_bar_governor_sim as governor
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore


EXCLUDED_DEVELOPMENT_YEARS = {2017, 2020, 2023, 2024, 2025, 2026}
SPECS = (
    {
        "name": "control",
        "lookback_days": 0,
        "target_rms": 0.0,
        "minimum_scale": 0.5,
        "maximum_scale": 1.25,
    },
    {
        "name": "vol3_target1000",
        "lookback_days": 3,
        "target_rms": 1000.0,
        "minimum_scale": 0.5,
        "maximum_scale": 1.25,
    },
    {
        "name": "vol3_target1500",
        "lookback_days": 3,
        "target_rms": 1500.0,
        "minimum_scale": 0.5,
        "maximum_scale": 1.25,
    },
    {
        "name": "vol5_target1000",
        "lookback_days": 5,
        "target_rms": 1000.0,
        "minimum_scale": 0.5,
        "maximum_scale": 1.25,
    },
    {
        "name": "vol5_target1500",
        "lookback_days": 5,
        "target_rms": 1500.0,
        "minimum_scale": 0.5,
        "maximum_scale": 1.25,
    },
)


def select_development_winner(rows: Sequence[Mapping[str, Any]]) -> Mapping[str, Any] | None:
    eligible = [
        row
        for row in rows
        if row["name"] != "control"
        and float(row["normal_delta_pct_points"]) > 0.0
        and float(row["adverse_delta_pct_points"]) > 0.0
    ]
    if not eligible:
        return None
    return sorted(
        eligible,
        key=lambda row: (
            -min(
                float(row["normal_delta_pct_points"]),
                float(row["adverse_delta_pct_points"]),
            ),
            float(row["maximum_effective_risk_multiplier"]),
            str(row["name"]),
        ),
    )[0]


def run_screen(manifest_path: Path, data_root: Path, scenario_name: str) -> dict[str, Any]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    scenarios = [row for row in manifest["scenarios"] if row["name"] == scenario_name]
    if len(scenarios) != 1:
        raise ValueError(f"expected one scenario {scenario_name!r}, found {len(scenarios)}")
    scenario = scenarios[0]

    cases, bars = governor.load_cases(
        manifest,
        bar_paths=governor.default_bar_paths(data_root),
    )
    grid = governor.common_grid(cases)
    trade_paths: list[governor.GovernedTradePath] = []
    for case in cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = governor.align_bars_to_grid(bars[symbol], grid)
        trade_paths.extend(
            governor.build_trade_paths(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
                feature_bars=bars[symbol],
                excluded_years=EXCLUDED_DEVELOPMENT_YEARS,
            )
        )
    entries = governor.index_entries(trade_paths)
    starts = governor.valid_start_days(
        grid,
        horizon_days=30,
        excluded_years=EXCLUDED_DEVELOPMENT_YEARS,
    )

    raw_rows: list[dict[str, Any]] = []
    for spec in SPECS:
        common = {
            "start_days": starts,
            "horizon_days": 30,
            "weights": scenario["weights"],
            "risk_multiplier": 25.0,
            "daily_stop": 4500.0,
            "full_risk_room": 4000.0,
            "room_retention": 0.2,
            "open_risk_limit_ratio": 0.0,
            "realized_vol_lookback_days": int(spec["lookback_days"]),
            "realized_vol_target_rms": float(spec["target_rms"]),
            "realized_vol_minimum_scale": float(spec["minimum_scale"]),
            "realized_vol_maximum_scale": float(spec["maximum_scale"]),
        }
        normal = governor.evaluate_policy(grid, entries, threshold_fill=True, **common)
        adverse = governor.evaluate_policy(grid, entries, threshold_fill=False, **common)
        raw_rows.append(
            {
                **spec,
                "maximum_effective_risk_multiplier": (
                    25.0
                    if int(spec["lookback_days"]) == 0
                    else 25.0 * float(spec["maximum_scale"])
                ),
                "normal": normal,
                "adverse": adverse,
            }
        )

    control = raw_rows[0]
    control_normal = float(control["normal"]["historical_rolling"]["pass_pct"])
    control_adverse = float(control["adverse"]["historical_rolling"]["pass_pct"])
    rows: list[dict[str, Any]] = []
    for row in raw_rows:
        normal_pass = float(row["normal"]["historical_rolling"]["pass_pct"])
        adverse_pass = float(row["adverse"]["historical_rolling"]["pass_pct"])
        rows.append(
            {
                **row,
                "normal_delta_pct_points": normal_pass - control_normal,
                "adverse_delta_pct_points": adverse_pass - control_adverse,
            }
        )
    winner = select_development_winner(rows)
    return {
        "schema_version": 1,
        "status": "DEVELOPMENT_SURVIVOR_FOUND" if winner is not None else "NO_DEVELOPMENT_SURVIVOR",
        "deployment_allowed": False,
        "manifest": str(manifest_path),
        "scenario": scenario_name,
        "excluded_years": sorted(EXCLUDED_DEVELOPMENT_YEARS),
        "trade_paths": len(trade_paths),
        "start_windows": len(starts),
        "control_normal_pass_pct": control_normal,
        "control_adverse_pass_pct": control_adverse,
        "rows": rows,
        "selected_policy": None if winner is None else str(winner["name"]),
        "validation_2023_open_allowed": winner is not None,
        "sealed_holdout_open_allowed": False,
        "label": "RESEARCH_ONLY_NO_GO",
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    artifact = run_screen(args.manifest, args.data_root, args.scenario)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "selected_policy": artifact["selected_policy"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
