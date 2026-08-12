"""Select predeclared FTMO profit-feedback policies on development only."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Mapping, Sequence


def policy_key(base_risk: float, steps: Sequence[Sequence[float]]) -> tuple[Any, ...]:
    return (
        float(base_risk),
        tuple((float(step[0]), float(step[1])) for step in steps),
    )


def row_key(row: Mapping[str, Any]) -> tuple[Any, ...]:
    steps = [
        (float(step["profit_threshold"]), float(step["risk_multiplier"]))
        for step in row.get("profit_risk_steps", [])
    ]
    return policy_key(float(row["risk_multiplier"]), steps)


def metrics(row: Mapping[str, Any]) -> dict[str, float]:
    rolling = row["historical_rolling"]
    return {
        "pass_pct": float(rolling["pass_pct"]),
        "daily_breach_pct": float(rolling["daily_breach_pct"]),
        "max_breach_pct": float(rolling["max_breach_pct"]),
        "not_reached_pct": float(rolling["not_reached_pct"]),
    }


def index_rows(artifact: Mapping[str, Any], scenario: str) -> dict[tuple[Any, ...], Mapping[str, Any]]:
    rows = [row for row in artifact.get("results", []) if row.get("scenario") == scenario]
    indexed: dict[tuple[Any, ...], Mapping[str, Any]] = {}
    for row in rows:
        key = row_key(row)
        if key in indexed:
            raise ValueError(f"duplicate policy row: {key}")
        indexed[key] = row
    return indexed


def select_policies(
    predeclaration: Mapping[str, Any],
    threshold_artifact: Mapping[str, Any],
    adverse_artifact: Mapping[str, Any],
) -> dict[str, Any]:
    scenario = str(predeclaration["scenario"])
    if threshold_artifact.get("fill_contract") != "ideal_threshold_inside_m15_bar":
        raise ValueError("threshold artifact has wrong fill contract")
    if adverse_artifact.get("fill_contract") != "adverse_bar":
        raise ValueError("adverse artifact has wrong fill contract")
    for field in ("manifest", "excluded_years", "start_windows", "trade_paths"):
        if threshold_artifact.get(field) != adverse_artifact.get(field):
            raise ValueError(f"artifact metadata drift: {field}")
    if Path(str(threshold_artifact.get("manifest"))) != Path(
        str(predeclaration.get("manifest"))
    ):
        raise ValueError("manifest differs from predeclaration")
    expected_excluded = predeclaration["selection_split"].get(
        "development_excluded_years"
    )
    if expected_excluded is not None and threshold_artifact.get("excluded_years") != expected_excluded:
        raise ValueError("development excluded years differ from predeclaration")

    threshold_rows = index_rows(threshold_artifact, scenario)
    adverse_rows = index_rows(adverse_artifact, scenario)
    control_spec = predeclaration["control"]
    control_key = policy_key(
        control_spec["base_risk_multiplier"], control_spec["profit_risk_steps"]
    )
    if control_key not in threshold_rows or control_key not in adverse_rows:
        raise ValueError("control policy is missing")
    control_threshold = metrics(threshold_rows[control_key])
    control_adverse = metrics(adverse_rows[control_key])

    leaderboard: list[dict[str, Any]] = []
    survivors: list[dict[str, Any]] = []
    for spec in predeclaration.get("candidates", []):
        key = policy_key(spec["base_risk_multiplier"], spec["profit_risk_steps"])
        if key not in threshold_rows or key not in adverse_rows:
            raise ValueError(f"candidate policy is missing: {spec['name']}")
        threshold = metrics(threshold_rows[key])
        adverse = metrics(adverse_rows[key])
        deltas = {
            "threshold_pass_pct_points": threshold["pass_pct"] - control_threshold["pass_pct"],
            "adverse_pass_pct_points": adverse["pass_pct"] - control_adverse["pass_pct"],
        }
        eligible = (
            deltas["threshold_pass_pct_points"] > 0.0
            and deltas["adverse_pass_pct_points"] > 0.0
            and threshold["daily_breach_pct"] <= control_threshold["daily_breach_pct"]
            and threshold["max_breach_pct"] <= control_threshold["max_breach_pct"]
            and adverse["daily_breach_pct"] <= control_adverse["daily_breach_pct"]
            and adverse["max_breach_pct"] <= control_adverse["max_breach_pct"]
        )
        row = {
            "name": spec["name"],
            "base_risk_multiplier": float(spec["base_risk_multiplier"]),
            "profit_risk_steps": spec["profit_risk_steps"],
            "threshold": threshold,
            "adverse": adverse,
            "pass_deltas": deltas,
            "development_survivor": eligible,
        }
        leaderboard.append(row)
        if eligible:
            survivors.append(row)

    leaderboard.sort(
        key=lambda row: (
            min(row["pass_deltas"].values()),
            row["pass_deltas"]["threshold_pass_pct_points"]
            + row["pass_deltas"]["adverse_pass_pct_points"],
        ),
        reverse=True,
    )
    survivors.sort(
        key=lambda row: min(row["pass_deltas"].values()), reverse=True
    )
    return {
        "schema_version": 1,
        "status": (
            "DEVELOPMENT_SURVIVOR_FOUND" if survivors else "NO_DEVELOPMENT_SURVIVOR"
        ),
        "predeclaration": "artifacts/ftmo_incumbent_profit_feedback_predeclaration_2026-07-12.json",
        "manifest": predeclaration["manifest"],
        "scenario": scenario,
        "development_years": predeclaration["selection_split"]["development_years"],
        "selection_uses_validation": False,
        "selection_uses_sealed": False,
        "control": {
            "name": control_spec["name"],
            "threshold": control_threshold,
            "adverse": control_adverse,
        },
        "evaluated_candidates": len(leaderboard),
        "survivor_count": len(survivors),
        "survivors": survivors,
        "leaderboard": leaderboard,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predeclaration", type=Path, required=True)
    parser.add_argument("--threshold", type=Path, required=True)
    parser.add_argument("--adverse", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = select_policies(
        json.loads(args.predeclaration.read_text(encoding="utf-8-sig")),
        json.loads(args.threshold.read_text(encoding="utf-8-sig")),
        json.loads(args.adverse.read_text(encoding="utf-8-sig")),
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "evaluated": output["evaluated_candidates"],
                "survivors": output["survivor_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
