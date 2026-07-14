"""Screen profit-band conditional deadline acceleration on the locked FTMO book."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from . import ftmo_bar_governor_sim as governor
    from . import ftmo_sleeve_edge_scaling as edge
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    import ftmo_sleeve_edge_scaling as edge  # type: ignore


@dataclass(frozen=True)
class ConditionalPolicy:
    name: str
    steps: tuple[tuple[int, float, float, float], ...]


def parse_policy(raw: Mapping[str, Any]) -> ConditionalPolicy:
    steps = tuple(
        (
            int(row["elapsed_calendar_days"]),
            float(row["minimum_profit"]),
            float(row["maximum_profit"]),
            float(row["risk_multiplier"]),
        )
        for row in raw.get("conditional_steps", [])
    )
    governor.risk_multiplier_for_conditional_deadline(
        0,
        governor.START_BALANCE,
        1.0,
        steps,
    )
    return ConditionalPolicy(name=str(raw["name"]), steps=steps)


def serialize_policy(policy: ConditionalPolicy) -> dict[str, Any]:
    return {
        "name": policy.name,
        "conditional_steps": [
            {
                "elapsed_calendar_days": day,
                "minimum_profit": minimum_profit,
                "maximum_profit": maximum_profit,
                "risk_multiplier": multiplier,
            }
            for day, minimum_profit, maximum_profit, multiplier in policy.steps
        ],
    }


def evaluate_one(
    grid: Any,
    paths: Sequence[governor.GovernedTradePath],
    *,
    weights: Mapping[str, float],
    fixed: Mapping[str, Any],
    excluded_years: set[int],
    threshold_fill: bool,
    policy: ConditionalPolicy,
) -> dict[str, Any]:
    horizon = int(fixed["horizon_calendar_days"])
    eligible = edge.exclude_path_years(paths, grid, excluded_years)
    return governor.evaluate_policy(
        grid,
        governor.index_entries(eligible),
        start_days=governor.valid_start_days(
            grid,
            horizon_days=horizon,
            excluded_years=excluded_years,
        ),
        horizon_days=horizon,
        weights=weights,
        risk_multiplier=float(fixed["risk_multiplier"]),
        daily_stop=float(fixed["daily_stop"]),
        full_risk_room=float(fixed["full_risk_room"]),
        room_retention=float(fixed["room_retention"]),
        open_risk_limit_ratio=float(fixed.get("open_risk_limit_ratio", 0.0)),
        threshold_fill=threshold_fill,
        conditional_deadline_steps=policy.steps,
    )


def policy_row(
    policy: ConditionalPolicy,
    *,
    grid: Any,
    paths: Sequence[governor.GovernedTradePath],
    weights: Mapping[str, float],
    fixed: Mapping[str, Any],
    excluded_years: set[int],
) -> dict[str, Any]:
    return {
        "policy": serialize_policy(policy),
        "normal": evaluate_one(
            grid,
            paths,
            weights=weights,
            fixed=fixed,
            excluded_years=excluded_years,
            threshold_fill=True,
            policy=policy,
        ),
        "adverse": evaluate_one(
            grid,
            paths,
            weights=weights,
            fixed=fixed,
            excluded_years=excluded_years,
            threshold_fill=False,
            policy=policy,
        ),
    }


def rank_survivors(rows: Sequence[Mapping[str, Any]]) -> list[Mapping[str, Any]]:
    return sorted(
        (row for row in rows if row["stage_survivor"]),
        key=lambda row: (
            min(row["pass_delta_pct_points"].values()),
            sum(row["pass_delta_pct_points"].values()),
            -len(row["policy"]["conditional_steps"]),
            row["policy"]["name"],
        ),
        reverse=True,
    )


def dual_improvement_with_breach_budget(
    normal: Mapping[str, Any],
    adverse: Mapping[str, Any],
    control_normal: Mapping[str, Any],
    control_adverse: Mapping[str, Any],
    *,
    maximum_individual_breach_increase_pp: float,
) -> bool:
    if maximum_individual_breach_increase_pp < 0.0:
        raise ValueError("breach increase budget must be non-negative")
    candidate_normal = edge.metrics(normal)
    candidate_adverse = edge.metrics(adverse)
    baseline_normal = edge.metrics(control_normal)
    baseline_adverse = edge.metrics(control_adverse)
    return (
        candidate_normal["pass_pct"] > baseline_normal["pass_pct"]
        and candidate_adverse["pass_pct"] > baseline_adverse["pass_pct"]
        and candidate_normal["daily_breach_pct"]
        <= baseline_normal["daily_breach_pct"] + maximum_individual_breach_increase_pp
        and candidate_normal["max_breach_pct"]
        <= baseline_normal["max_breach_pct"] + maximum_individual_breach_increase_pp
        and candidate_adverse["daily_breach_pct"]
        <= baseline_adverse["daily_breach_pct"] + maximum_individual_breach_increase_pp
        and candidate_adverse["max_breach_pct"]
        <= baseline_adverse["max_breach_pct"] + maximum_individual_breach_increase_pp
    )


def screen(
    predeclaration: Mapping[str, Any],
    manifest: Mapping[str, Any],
    *,
    data_root: Path,
    stage: str,
    locked_artifact: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    if stage not in edge.STAGE_EXCLUDED_YEARS:
        raise ValueError(f"unsupported stage: {stage}")
    scenario = edge.find_scenario(manifest, str(predeclaration["scenario"]))
    weights = {str(key): float(value) for key, value in scenario["weights"].items()}
    fixed = predeclaration["fixed_governor"]
    breach_budget = float(
        predeclaration.get("maximum_individual_breach_increase_pp", 0.0)
    )
    if breach_budget < 0.0:
        raise ValueError("maximum_individual_breach_increase_pp must be non-negative")
    control_policy = parse_policy(predeclaration["control"])
    if stage == "development":
        candidates = [parse_policy(row) for row in predeclaration["candidates"]]
    else:
        if locked_artifact is None:
            raise ValueError(f"{stage} requires a locked prior-stage artifact")
        required = (
            "DEVELOPMENT_SURVIVOR_FOUND"
            if stage == "validation"
            else "VALIDATION_SURVIVOR_FOUND"
        )
        if locked_artifact.get("status") != required:
            raise ValueError(f"{stage} requires {required}")
        candidates = [parse_policy(locked_artifact["winner"]["policy"])]

    grid, paths = edge.load_full_paths(manifest, data_root)
    excluded = edge.STAGE_EXCLUDED_YEARS[stage]
    control = policy_row(
        control_policy,
        grid=grid,
        paths=paths,
        weights=weights,
        fixed=fixed,
        excluded_years=excluded,
    )
    rows: list[dict[str, Any]] = []
    for candidate in candidates:
        row = policy_row(
            candidate,
            grid=grid,
            paths=paths,
            weights=weights,
            fixed=fixed,
            excluded_years=excluded,
        )
        row["pass_delta_pct_points"] = {
            "normal": edge.metrics(row["normal"])["pass_pct"]
            - edge.metrics(control["normal"])["pass_pct"],
            "adverse": edge.metrics(row["adverse"])["pass_pct"]
            - edge.metrics(control["adverse"])["pass_pct"],
        }
        row["stage_survivor"] = dual_improvement_with_breach_budget(
            row["normal"],
            row["adverse"],
            control["normal"],
            control["adverse"],
            maximum_individual_breach_increase_pp=breach_budget,
        )
        rows.append(row)
    survivors = rank_survivors(rows)
    winner = survivors[0] if survivors else None
    positive_status = {
        "development": "DEVELOPMENT_SURVIVOR_FOUND",
        "validation": "VALIDATION_SURVIVOR_FOUND",
        "holdout": "LOCKED_HOLDOUT_IMPROVEMENT_CONFIRMED",
    }[stage]
    negative_status = {
        "development": "NO_DEVELOPMENT_SURVIVOR",
        "validation": "LOCKED_VALIDATION_FAILED",
        "holdout": "LOCKED_HOLDOUT_FAILED",
    }[stage]
    return {
        "schema_version": 1,
        "status": positive_status if winner else negative_status,
        "stage": stage,
        "predeclaration": predeclaration.get(
            "evidence_path",
            "artifacts/ftmo_conditional_deadline_policy_predeclaration_2026-07-12.json",
        ),
        "manifest": predeclaration["manifest"],
        "scenario": predeclaration["scenario"],
        "excluded_years": sorted(excluded),
        "selection_uses_validation": stage != "development",
        "selection_uses_sealed": stage == "holdout",
        "maximum_individual_breach_increase_pp": breach_budget,
        "control": control,
        "evaluated_candidates": len(rows),
        "survivor_count": len(survivors),
        "winner": winner,
        "leaderboard": sorted(
            rows,
            key=lambda row: (
                min(row["pass_delta_pct_points"].values()),
                sum(row["pass_delta_pct_points"].values()),
            ),
            reverse=True,
        ),
        "deployment_allowed": False,
        "label": "RESEARCH_ONLY_NO_GO",
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predeclaration", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--stage", choices=sorted(edge.STAGE_EXCLUDED_YEARS), required=True)
    parser.add_argument("--locked", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    predeclaration = json.loads(args.predeclaration.read_text(encoding="utf-8-sig"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    locked = (
        json.loads(args.locked.read_text(encoding="utf-8-sig")) if args.locked else None
    )
    output = screen(
        predeclaration,
        manifest,
        data_root=args.data_root,
        stage=args.stage,
        locked_artifact=locked,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "stage": output["stage"],
                "evaluated": output["evaluated_candidates"],
                "survivors": output["survivor_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
