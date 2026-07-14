"""Replace one FTMO sleeve's evidence while preserving locked portfolio weights."""

from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence


def sleeve_key(sleeve: Mapping[str, Any]) -> str:
    return f"{int(sleeve['ea_id'])}:{str(sleeve['symbol']).upper()}"


def build_replacement_manifest(
    base: Mapping[str, Any],
    replacement_spec: Mapping[str, Any],
    *,
    base_scenario: str,
    scenario_name: str,
    snapshot_date: str | None = None,
    basis: str | None = None,
) -> dict[str, Any]:
    scenarios = [row for row in base.get("scenarios", []) if row.get("name") == base_scenario]
    if len(scenarios) != 1:
        raise ValueError(f"expected one base scenario {base_scenario!r}, found {len(scenarios)}")

    replacement = copy.deepcopy(replacement_spec.get("sleeve"))
    if not isinstance(replacement, dict):
        raise ValueError("replacement specification requires a sleeve object")
    replacement_key = sleeve_key(replacement)

    weights = {
        str(key): float(value) for key, value in scenarios[0].get("weights", {}).items()
    }
    if replacement_key not in weights:
        raise ValueError(f"replacement key is not in the locked scenario: {replacement_key}")
    if any(not math.isfinite(value) or value < 0.0 for value in weights.values()):
        raise ValueError("scenario weights must be finite and non-negative")
    if not math.isclose(sum(weights.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        raise ValueError(f"scenario weights must sum to one, got {sum(weights.values()):.12f}")

    active_sleeves = [
        copy.deepcopy(row)
        for row in base.get("sleeves", [])
        if sleeve_key(row) in weights
    ]
    matches = [index for index, row in enumerate(active_sleeves) if sleeve_key(row) == replacement_key]
    if len(matches) != 1:
        raise ValueError(f"expected one incumbent sleeve {replacement_key}, found {len(matches)}")
    incumbent = active_sleeves[matches[0]]
    if float(replacement.get("base_risk_fixed", incumbent.get("base_risk_fixed", 0.0))) != float(
        incumbent.get("base_risk_fixed", 0.0)
    ):
        raise ValueError("replacement must preserve base_risk_fixed")
    replacement.setdefault("base_risk_fixed", incumbent.get("base_risk_fixed"))
    active_sleeves[matches[0]] = replacement

    active_keys = {sleeve_key(row) for row in active_sleeves}
    if active_keys != set(weights):
        raise ValueError("active sleeve keys do not exactly match locked scenario weights")

    output = copy.deepcopy(dict(base))
    output["status"] = "RESEARCH_ONLY_NO_GO"
    output["deployment_allowed"] = False
    output["snapshot_date"] = snapshot_date or output.get("snapshot_date")
    output["basis"] = basis or output.get("basis")
    output["sleeves"] = active_sleeves
    output["scenarios"] = [{"name": scenario_name, "weights": weights}]
    output["candidate_evidence"] = list(
        dict.fromkeys(
            [
                *output.get("candidate_evidence", []),
                *replacement_spec.get("candidate_evidence", []),
            ]
        )
    )
    output["generator"] = {
        "tool": "tools/strategy_farm/portfolio/ftmo_replace_sleeve_manifest.py",
        "base_scenario": base_scenario,
        "replacement_key": replacement_key,
        "contract": "same_key_same_weight_evidence_replacement",
    }
    return output


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-manifest", type=Path, required=True)
    parser.add_argument("--replacement-spec", type=Path, required=True)
    parser.add_argument("--base-scenario", required=True)
    parser.add_argument("--scenario-name", required=True)
    parser.add_argument("--snapshot-date")
    parser.add_argument("--basis")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    base = json.loads(args.base_manifest.read_text(encoding="utf-8-sig"))
    replacement = json.loads(args.replacement_spec.read_text(encoding="utf-8-sig"))
    output = build_replacement_manifest(
        base,
        replacement,
        base_scenario=args.base_scenario,
        scenario_name=args.scenario_name,
        snapshot_date=args.snapshot_date,
        basis=args.basis,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
