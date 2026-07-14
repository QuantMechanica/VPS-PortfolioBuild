"""Select one pre-holdout FTMO weight candidate under a frozen maximin rule."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence


FILL_KEYS = (
    "development_threshold",
    "development_adverse",
    "validation_threshold",
    "validation_adverse",
)


def _pass_by_scenario(artifact: Mapping[str, Any]) -> dict[str, float]:
    output: dict[str, float] = {}
    for row in artifact.get("results", []):
        name = str(row["scenario"])
        if name in output:
            raise ValueError(f"duplicate scenario result: {name}")
        value = float(row["historical_rolling"]["pass_pct"])
        if not math.isfinite(value):
            raise ValueError(f"non-finite pass rate for {name}")
        output[name] = value
    if not output:
        raise ValueError("artifact contains no scenario results")
    return output


def select_candidate(
    *,
    manifest: Mapping[str, Any],
    artifacts: Mapping[str, Mapping[str, Any]],
    control_name: str,
    development_minimum_delta: float,
    validation_minimum_delta: float,
) -> dict[str, Any]:
    if set(artifacts) != set(FILL_KEYS):
        raise ValueError(f"expected artifacts {FILL_KEYS}")
    passes = {key: _pass_by_scenario(artifacts[key]) for key in FILL_KEYS}
    scenario_sets = [set(values) for values in passes.values()]
    if any(values != scenario_sets[0] for values in scenario_sets[1:]):
        raise ValueError("scenario sets differ across evaluation artifacts")
    if control_name not in scenario_sets[0]:
        raise ValueError(f"control scenario missing: {control_name}")

    manifest_scenarios = {
        str(row["name"]): row for row in manifest.get("scenarios", [])
    }
    if scenario_sets[0] - set(manifest_scenarios):
        raise ValueError("evaluation contains scenarios absent from manifest")
    controls = {key: passes[key][control_name] for key in FILL_KEYS}
    rows: list[dict[str, Any]] = []
    for name in sorted(scenario_sets[0] - {control_name}):
        deltas = {key: passes[key][name] - controls[key] for key in FILL_KEYS}
        development_pass = all(
            deltas[key] >= development_minimum_delta
            for key in ("development_threshold", "development_adverse")
        )
        validation_pass = all(
            deltas[key] >= validation_minimum_delta
            for key in ("validation_threshold", "validation_adverse")
        )
        metadata = manifest_scenarios[name].get("search_metadata", {})
        l1_distance = float(metadata.get("l1_distance_from_control", math.inf))
        row = {
            "scenario": name,
            "pass_pct": {key: passes[key][name] for key in FILL_KEYS},
            "delta_pct_points": deltas,
            "minimum_delta_pct_points": min(deltas.values()),
            "sum_delta_pct_points": sum(deltas.values()),
            "l1_distance_from_control": l1_distance,
            "development_gate_pass": development_pass,
            "validation_gate_pass": validation_pass,
            "eligible": development_pass and validation_pass,
        }
        rows.append(row)

    ranked = sorted(
        rows,
        key=lambda row: (
            -float(row["minimum_delta_pct_points"]),
            -float(row["sum_delta_pct_points"]),
            float(row["l1_distance_from_control"]),
            str(row["scenario"]),
        ),
    )
    eligible = [row for row in ranked if row["eligible"]]
    winner = eligible[0] if eligible else None
    return {
        "schema_version": 1,
        "status": "SURVIVOR" if winner else "NO_SURVIVOR",
        "control_scenario": control_name,
        "control_pass_pct": controls,
        "development_minimum_delta_pct_points_each_fill": development_minimum_delta,
        "validation_minimum_delta_pct_points_each_fill": validation_minimum_delta,
        "candidate_count": len(rows),
        "eligible_count": len(eligible),
        "winner": winner,
        "combined_preholdout_required": winner is not None,
        "sealed_holdout_open_allowed": False,
        "ranking_contract": (
            "minimum_delta_desc,sum_delta_desc,l1_distance_asc,scenario_asc"
        ),
        "leaderboard": ranked,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--development-threshold", type=Path, required=True)
    parser.add_argument("--development-adverse", type=Path, required=True)
    parser.add_argument("--validation-threshold", type=Path, required=True)
    parser.add_argument("--validation-adverse", type=Path, required=True)
    parser.add_argument("--control-name", default="locked_control")
    parser.add_argument("--development-minimum-delta", type=float, default=0.5)
    parser.add_argument("--validation-minimum-delta", type=float, default=0.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    artifact_paths = {
        "development_threshold": args.development_threshold,
        "development_adverse": args.development_adverse,
        "validation_threshold": args.validation_threshold,
        "validation_adverse": args.validation_adverse,
    }
    output = select_candidate(
        manifest=json.loads(args.manifest.read_text(encoding="utf-8-sig")),
        artifacts={
            key: json.loads(path.read_text(encoding="utf-8-sig"))
            for key, path in artifact_paths.items()
        },
        control_name=args.control_name,
        development_minimum_delta=args.development_minimum_delta,
        validation_minimum_delta=args.validation_minimum_delta,
    )
    output["manifest"] = str(args.manifest)
    output["source_artifacts"] = {
        key: str(path) for key, path in artifact_paths.items()
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"wrote {args.out} status={output['status']} "
        f"eligible={output['eligible_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
