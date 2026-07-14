"""Screen causal soft per-sleeve risk scaling on the locked FTMO book."""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np

try:
    from . import ftmo_bar_governor_sim as governor
    from . import ftmo_bar_joint_book_sim as joint
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    import ftmo_bar_joint_book_sim as joint  # type: ignore


EPSILON = 1e-12
STAGE_EXCLUDED_YEARS = {
    "development": {2017, 2020, 2023, 2024, 2025, 2026},
    "validation": {2017, 2018, 2019, 2020, 2021, 2022, 2024, 2025, 2026},
    "holdout": {2017, 2018, 2019, 2020, 2021, 2022, 2023, 2026},
}


@dataclass(frozen=True)
class EdgePolicy:
    name: str
    lookback_trades: int
    negative_factor: float
    positive_factor: float


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def parse_policy(raw: Mapping[str, Any]) -> EdgePolicy:
    policy = EdgePolicy(
        name=str(raw["name"]),
        lookback_trades=int(raw["lookback_trades"]),
        negative_factor=float(raw["negative_factor"]),
        positive_factor=float(raw["positive_factor"]),
    )
    if policy.lookback_trades < 0:
        raise ValueError("lookback_trades must be non-negative")
    if policy.negative_factor <= 0.0 or policy.positive_factor <= 0.0:
        raise ValueError("edge factors must be positive")
    if policy.lookback_trades == 0 and (
        policy.negative_factor != 1.0 or policy.positive_factor != 1.0
    ):
        raise ValueError("the zero-lookback control must use unit factors")
    return policy


def path_net_at_unit_scale(path: governor.GovernedTradePath) -> float:
    return float(path.exit_balance_delta - path.entry_commission)


def causal_edge_scores(
    paths: Sequence[governor.GovernedTradePath],
    lookback_trades: int,
) -> dict[str, float | None]:
    """Return a per-entry score using only strictly earlier path exits."""

    if lookback_trades <= 0:
        return {path.trade_id: None for path in paths}
    completions = sorted(paths, key=lambda path: (path.end_idx, path.trade_id))
    entries = sorted(paths, key=lambda path: (path.start_idx, path.trade_id))
    realized: collections.defaultdict[str, list[float]] = collections.defaultdict(list)
    scores: dict[str, float | None] = {}
    completion_index = 0
    for path in entries:
        while (
            completion_index < len(completions)
            and completions[completion_index].end_idx < path.start_idx
        ):
            completed = completions[completion_index]
            if completed.nominal_risk <= 0.0:
                raise ValueError(f"{completed.trade_id}: nominal risk must be positive")
            realized[completed.key].append(
                path_net_at_unit_scale(completed) / completed.nominal_risk
            )
            completion_index += 1
        history = realized[path.key]
        scores[path.trade_id] = (
            float(sum(history[-lookback_trades:]))
            if len(history) >= lookback_trades
            else None
        )
    return scores


def edge_factor(score: float | None, policy: EdgePolicy) -> float:
    if policy.lookback_trades == 0 or score is None:
        return 1.0
    return policy.positive_factor if score > 0.0 else policy.negative_factor


def scale_paths(
    paths: Sequence[governor.GovernedTradePath],
    policy: EdgePolicy,
) -> tuple[list[governor.GovernedTradePath], dict[str, int]]:
    scores = causal_edge_scores(paths, policy.lookback_trades)
    factor_counts: collections.Counter[str] = collections.Counter()
    output: list[governor.GovernedTradePath] = []
    for path in paths:
        score = scores[path.trade_id]
        factor = edge_factor(score, policy)
        factor_counts[
            "warmup"
            if score is None
            else "positive"
            if score > 0.0
            else "nonpositive"
        ] += 1
        output.append(
            replace(
                path,
                entry_commission=path.entry_commission * factor,
                exit_commission=path.exit_commission * factor,
                exit_balance_delta=path.exit_balance_delta * factor,
                adverse_pnl=path.adverse_pnl * factor,
                close_pnl=path.close_pnl * factor,
                nominal_risk=path.nominal_risk * factor,
            )
        )
    return output, dict(sorted(factor_counts.items()))


def exclude_path_years(
    paths: Sequence[governor.GovernedTradePath],
    grid: Any,
    excluded_years: set[int],
) -> list[governor.GovernedTradePath]:
    output: list[governor.GovernedTradePath] = []
    for path in paths:
        start_year = int(grid[path.start_idx].year)
        end_year = int(grid[path.end_idx].year)
        if set(range(start_year, end_year + 1)) & excluded_years:
            continue
        output.append(path)
    return output


def metrics(evaluation: Mapping[str, Any]) -> Mapping[str, float]:
    return evaluation["historical_rolling"]


def strict_dual_improvement(
    normal: Mapping[str, Any],
    adverse: Mapping[str, Any],
    control_normal: Mapping[str, Any],
    control_adverse: Mapping[str, Any],
) -> bool:
    candidate_normal = metrics(normal)
    candidate_adverse = metrics(adverse)
    baseline_normal = metrics(control_normal)
    baseline_adverse = metrics(control_adverse)
    return (
        candidate_normal["pass_pct"] > baseline_normal["pass_pct"] + EPSILON
        and candidate_adverse["pass_pct"] > baseline_adverse["pass_pct"] + EPSILON
        and candidate_normal["daily_breach_pct"]
        <= baseline_normal["daily_breach_pct"] + EPSILON
        and candidate_normal["max_breach_pct"]
        <= baseline_normal["max_breach_pct"] + EPSILON
        and candidate_adverse["daily_breach_pct"]
        <= baseline_adverse["daily_breach_pct"] + EPSILON
        and candidate_adverse["max_breach_pct"]
        <= baseline_adverse["max_breach_pct"] + EPSILON
    )


def load_full_paths(
    manifest: Mapping[str, Any],
    data_root: Path,
) -> tuple[Any, list[governor.GovernedTradePath]]:
    cases, bars = joint.load_cases(manifest, bar_paths=joint.default_bar_paths(data_root))
    grid = joint.common_grid(cases)
    paths: list[governor.GovernedTradePath] = []
    for case in cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = joint.align_bars_to_grid(bars[symbol], grid)
        paths.extend(
            governor.build_trade_paths(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
                excluded_years={2020},
            )
        )
    return grid, paths


def find_scenario(manifest: Mapping[str, Any], name: str) -> Mapping[str, Any]:
    for scenario in manifest.get("scenarios", []):
        if scenario.get("name") == name:
            return scenario
    raise ValueError(f"scenario not found: {name}")


def evaluate_one(
    grid: Any,
    paths: Sequence[governor.GovernedTradePath],
    *,
    weights: Mapping[str, float],
    fixed: Mapping[str, Any],
    excluded_years: set[int],
    threshold_fill: bool,
) -> dict[str, Any]:
    horizon = int(fixed["horizon_calendar_days"])
    eligible = exclude_path_years(paths, grid, excluded_years)
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
        open_risk_limit_ratio=0.0,
        threshold_fill=threshold_fill,
    )


def policy_row(
    policy: EdgePolicy,
    *,
    grid: Any,
    full_paths: Sequence[governor.GovernedTradePath],
    weights: Mapping[str, float],
    fixed: Mapping[str, Any],
    excluded_years: set[int],
) -> dict[str, Any]:
    scaled, factor_counts = scale_paths(full_paths, policy)
    normal = evaluate_one(
        grid,
        scaled,
        weights=weights,
        fixed=fixed,
        excluded_years=excluded_years,
        threshold_fill=True,
    )
    adverse = evaluate_one(
        grid,
        scaled,
        weights=weights,
        fixed=fixed,
        excluded_years=excluded_years,
        threshold_fill=False,
    )
    return {
        "policy": {
            "name": policy.name,
            "lookback_trades": policy.lookback_trades,
            "negative_factor": policy.negative_factor,
            "positive_factor": policy.positive_factor,
        },
        "factor_counts_all_years": factor_counts,
        "normal": normal,
        "adverse": adverse,
    }


def screen(
    predeclaration: Mapping[str, Any],
    manifest: Mapping[str, Any],
    *,
    data_root: Path,
    stage: str,
    locked_artifact: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    if stage not in STAGE_EXCLUDED_YEARS:
        raise ValueError(f"unsupported stage: {stage}")
    scenario = find_scenario(manifest, str(predeclaration["scenario"]))
    weights = {str(key): float(value) for key, value in scenario["weights"].items()}
    fixed = predeclaration["fixed_governor"]
    control = parse_policy(predeclaration["control"])
    if stage == "development":
        candidates = [parse_policy(row) for row in predeclaration["candidates"]]
    else:
        if locked_artifact is None:
            raise ValueError(f"{stage} requires a locked prior-stage artifact")
        expected_status = (
            "DEVELOPMENT_SURVIVOR_FOUND"
            if stage == "validation"
            else "VALIDATION_SURVIVOR_FOUND"
        )
        if locked_artifact.get("status") != expected_status:
            raise ValueError(
                f"{stage} requires {expected_status}, got {locked_artifact.get('status')}"
            )
        candidates = [parse_policy(locked_artifact["winner"]["policy"])]

    grid, full_paths = load_full_paths(manifest, data_root)
    excluded = STAGE_EXCLUDED_YEARS[stage]
    control_row = policy_row(
        control,
        grid=grid,
        full_paths=full_paths,
        weights=weights,
        fixed=fixed,
        excluded_years=excluded,
    )
    rows: list[dict[str, Any]] = []
    for policy in candidates:
        row = policy_row(
            policy,
            grid=grid,
            full_paths=full_paths,
            weights=weights,
            fixed=fixed,
            excluded_years=excluded,
        )
        row["pass_delta_pct_points"] = {
            "normal": metrics(row["normal"])["pass_pct"]
            - metrics(control_row["normal"])["pass_pct"],
            "adverse": metrics(row["adverse"])["pass_pct"]
            - metrics(control_row["adverse"])["pass_pct"],
        }
        row["stage_survivor"] = strict_dual_improvement(
            row["normal"],
            row["adverse"],
            control_row["normal"],
            control_row["adverse"],
        )
        rows.append(row)

    survivors = [row for row in rows if row["stage_survivor"]]
    survivors.sort(
        key=lambda row: (
            min(row["pass_delta_pct_points"].values()),
            sum(row["pass_delta_pct_points"].values()),
            -max(
                row["policy"]["negative_factor"],
                row["policy"]["positive_factor"],
            ),
        ),
        reverse=True,
    )
    winner = survivors[0] if survivors else None
    status = {
        "development": "DEVELOPMENT_SURVIVOR_FOUND",
        "validation": "VALIDATION_SURVIVOR_FOUND",
        "holdout": "HOLDOUT_DUAL_IMPROVEMENT_FOUND",
    }[stage]
    if winner is None:
        status = {
            "development": "NO_DEVELOPMENT_SURVIVOR",
            "validation": "VALIDATION_GATE_FAILED",
            "holdout": "HOLDOUT_GATE_FAILED",
        }[stage]
    return {
        "schema_version": 1,
        "status": status,
        "stage": stage,
        "selection_uses_later_stage": False,
        "manifest": predeclaration["manifest"],
        "scenario": predeclaration["scenario"],
        "excluded_years": sorted(excluded),
        "fixed_governor": fixed,
        "full_trade_paths": len(full_paths),
        "control": control_row,
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
    parser.add_argument("--stage", choices=sorted(STAGE_EXCLUDED_YEARS), required=True)
    parser.add_argument("--locked-artifact", type=Path)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    predeclaration = json.loads(args.predeclaration.read_text(encoding="utf-8-sig"))
    manifest_path = Path(str(predeclaration["manifest"]))
    expected_hash = str(predeclaration["manifest_sha256"]).upper()
    if file_sha256(manifest_path) != expected_hash:
        raise ValueError("locked manifest hash differs from predeclaration")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    locked = (
        json.loads(args.locked_artifact.read_text(encoding="utf-8-sig"))
        if args.locked_artifact
        else None
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
