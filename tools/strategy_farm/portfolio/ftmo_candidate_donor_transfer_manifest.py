"""Build FTMO scenarios that transfer risk from one incumbent donor to a candidate.

Each scenario subtracts an absolute candidate weight from exactly one declared
incumbent sleeve. Total book weight and every other incumbent weight stay
unchanged, which makes substitution tests directly attributable.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import re
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from tools.strategy_farm.portfolio.ftmo_candidate_weight_manifest import (
        _parse_weights,
        _validate_weights,
        _weight_tag,
        sleeve_key,
    )
except ModuleNotFoundError:
    from ftmo_candidate_weight_manifest import (
        _parse_weights,
        _validate_weights,
        _weight_tag,
        sleeve_key,
    )


def _donor_tag(key: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", key).strip("_")


def build_manifest(
    base: Mapping[str, Any],
    candidate_spec: Mapping[str, Any],
    *,
    base_scenario: str,
    donor_keys: Sequence[str],
    candidate_weights_pct: Sequence[float],
    control_name: str,
    scenario_prefix: str,
    snapshot_date: str | None = None,
    basis: str | None = None,
) -> dict[str, Any]:
    scenarios = [row for row in base.get("scenarios", []) if row.get("name") == base_scenario]
    if len(scenarios) != 1:
        raise ValueError(f"expected one base scenario {base_scenario!r}, found {len(scenarios)}")

    sleeve = copy.deepcopy(candidate_spec.get("sleeve"))
    if not isinstance(sleeve, dict):
        raise ValueError("candidate specification requires a sleeve object")
    candidate_key = sleeve_key(sleeve)

    base_weights = {
        str(key): float(value) for key, value in scenarios[0].get("weights", {}).items()
    }
    base_sleeves = [
        copy.deepcopy(row)
        for row in base.get("sleeves", [])
        if sleeve_key(row) in base_weights
    ]
    incumbent_keys = {sleeve_key(row) for row in base_sleeves}
    _validate_weights(base_weights, incumbent_keys)
    if candidate_key in incumbent_keys:
        raise ValueError(f"candidate sleeve already exists: {candidate_key}")

    donors = [str(key) for key in donor_keys]
    if not donors or len(set(donors)) != len(donors):
        raise ValueError("donor keys must be non-empty and unique")
    unknown = sorted(set(donors) - incumbent_keys)
    if unknown:
        raise ValueError(f"unknown donor keys: {unknown}")

    weights_pct = [float(value) for value in candidate_weights_pct]
    if not weights_pct or len(set(weights_pct)) != len(weights_pct):
        raise ValueError("candidate weights must be non-empty and unique")
    if any(not math.isfinite(value) or value <= 0.0 or value >= 100.0 for value in weights_pct):
        raise ValueError("candidate weights must be finite percentages between zero and 100")

    output_scenarios: list[dict[str, Any]] = [
        {"name": control_name, "weights": copy.deepcopy(base_weights)}
    ]
    for donor_key in donors:
        for weight_pct in weights_pct:
            candidate_weight = weight_pct / 100.0
            if candidate_weight > base_weights[donor_key] + 1e-12:
                raise ValueError(
                    f"candidate weight {candidate_weight:.6f} exceeds donor "
                    f"{donor_key} weight {base_weights[donor_key]:.6f}"
                )
            weights = copy.deepcopy(base_weights)
            weights[donor_key] -= candidate_weight
            weights[candidate_key] = candidate_weight
            _validate_weights(weights, incumbent_keys | {candidate_key})
            output_scenarios.append(
                {
                    "name": (
                        f"{scenario_prefix}_{_donor_tag(donor_key)}_"
                        f"{_weight_tag(weight_pct)}"
                    ),
                    "weights": weights,
                }
            )

    output = copy.deepcopy(dict(base))
    output["status"] = "RESEARCH_ONLY_NO_GO"
    output["deployment_allowed"] = False
    output["snapshot_date"] = snapshot_date or output.get("snapshot_date")
    output["basis"] = basis or output.get("basis")
    output["sleeves"] = [*base_sleeves, sleeve]
    output["scenarios"] = output_scenarios
    output["candidate_evidence"] = list(
        dict.fromkeys(
            [
                *output.get("candidate_evidence", []),
                *candidate_spec.get("candidate_evidence", []),
            ]
        )
    )
    output["generator"] = {
        "tool": "tools/strategy_farm/portfolio/ftmo_candidate_donor_transfer_manifest.py",
        "base_scenario": base_scenario,
        "candidate_key": candidate_key,
        "donor_keys": donors,
        "candidate_weights_pct": weights_pct,
        "contract": "risk_neutral_single_donor_absolute_transfer",
    }
    return output


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-manifest", type=Path, required=True)
    parser.add_argument("--candidate-spec", type=Path, required=True)
    parser.add_argument("--base-scenario", required=True)
    parser.add_argument("--donor-keys", required=True)
    parser.add_argument("--candidate-weights-pct", required=True)
    parser.add_argument("--control-name", default="locked_control")
    parser.add_argument("--scenario-prefix", required=True)
    parser.add_argument("--snapshot-date")
    parser.add_argument("--basis")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    base = json.loads(args.base_manifest.read_text(encoding="utf-8-sig"))
    candidate = json.loads(args.candidate_spec.read_text(encoding="utf-8-sig"))
    output = build_manifest(
        base,
        candidate,
        base_scenario=args.base_scenario,
        donor_keys=[value.strip() for value in args.donor_keys.split(",") if value.strip()],
        candidate_weights_pct=_parse_weights(args.candidate_weights_pct),
        control_name=args.control_name,
        scenario_prefix=args.scenario_prefix,
        snapshot_date=args.snapshot_date,
        basis=args.basis,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
