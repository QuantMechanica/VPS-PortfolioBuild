"""Generate one-factor weight probes around a locked FTMO book.

Each probe moves exactly one incumbent sleeve by a fixed percentage-point
delta and scales every other sleeve proportionally. The output is a research
manifest for training-only diagnostics; it never changes the locked source
manifest.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import random
from pathlib import Path
from typing import Any, Mapping, Sequence


def _tag(key: str) -> str:
    ea_id, symbol = key.split(":", 1)
    return f"{ea_id}_{symbol.split('.', 1)[0].lower()}"


def _delta_tag(delta_pct: float) -> str:
    sign = "up" if delta_pct > 0 else "down"
    magnitude = f"{abs(delta_pct):g}".replace(".", "p")
    return f"{sign}{magnitude}"


def perturb_weights(
    weights: Mapping[str, float], selected_key: str, delta_pct: float
) -> dict[str, float]:
    if selected_key not in weights:
        raise ValueError(f"unknown sleeve key: {selected_key}")
    values = {str(key): float(value) for key, value in weights.items()}
    if not math.isclose(sum(values.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        raise ValueError("base weights must sum to one")
    if any(not math.isfinite(value) or value < 0.0 for value in values.values()):
        raise ValueError("base weights must be finite and non-negative")

    old_weight = values[selected_key]
    new_weight = old_weight + float(delta_pct) / 100.0
    if not 0.0 <= new_weight < 1.0:
        raise ValueError("perturbed weight must remain in [0, 1)")
    old_other = 1.0 - old_weight
    new_other = 1.0 - new_weight
    if old_other <= 0.0:
        raise ValueError("selected sleeve leaves no incumbent weight to scale")

    scale = new_other / old_other
    output = {
        key: (new_weight if key == selected_key else value * scale)
        for key, value in values.items()
    }
    if not math.isclose(sum(output.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        raise AssertionError("generated weights do not sum to one")
    return output


def build_probe_manifest(
    base: Mapping[str, Any],
    *,
    base_scenario: str,
    deltas_pct: Sequence[float],
    control_name: str = "locked_control",
) -> dict[str, Any]:
    matches = [row for row in base.get("scenarios", []) if row.get("name") == base_scenario]
    if len(matches) != 1:
        raise ValueError(f"expected one base scenario {base_scenario!r}, found {len(matches)}")
    weights = {str(key): float(value) for key, value in matches[0]["weights"].items()}
    if not deltas_pct or any(float(value) == 0.0 for value in deltas_pct):
        raise ValueError("deltas must be non-empty and non-zero")

    scenarios: list[dict[str, Any]] = [
        {"name": control_name, "weights": copy.deepcopy(weights)}
    ]
    skipped: list[dict[str, Any]] = []
    for key in weights:
        for delta in deltas_pct:
            try:
                probed = perturb_weights(weights, key, float(delta))
            except ValueError as exc:
                skipped.append({"key": key, "delta_pct": float(delta), "reason": str(exc)})
                continue
            scenarios.append(
                {
                    "name": f"probe_{_tag(key)}_{_delta_tag(float(delta))}",
                    "weights": probed,
                }
            )

    output = copy.deepcopy(dict(base))
    output["status"] = "RESEARCH_ONLY_NO_GO"
    output["deployment_allowed"] = False
    output["basis"] = "locked_incumbent_one_factor_weight_probe"
    output["scenarios"] = scenarios
    output["generator"] = {
        "tool": "tools/strategy_farm/portfolio/ftmo_incumbent_weight_probe.py",
        "base_scenario": base_scenario,
        "deltas_pct": [float(value) for value in deltas_pct],
        "contract": "one_sleeve_absolute_delta_other_incumbents_proportional",
        "skipped": skipped,
    }
    return output


def build_cumulative_manifest(
    base: Mapping[str, Any],
    *,
    base_scenario: str,
    operations: Sequence[tuple[str, float]],
    control_name: str = "locked_control",
) -> dict[str, Any]:
    matches = [row for row in base.get("scenarios", []) if row.get("name") == base_scenario]
    if len(matches) != 1:
        raise ValueError(f"expected one base scenario {base_scenario!r}, found {len(matches)}")
    if not operations:
        raise ValueError("operations must not be empty")
    weights = {str(key): float(value) for key, value in matches[0]["weights"].items()}
    scenarios: list[dict[str, Any]] = [
        {"name": control_name, "weights": copy.deepcopy(weights)}
    ]
    applied: list[dict[str, Any]] = []
    for step, (key, delta_pct) in enumerate(operations, start=1):
        weights = perturb_weights(weights, key, delta_pct)
        applied.append({"key": key, "delta_pct": float(delta_pct)})
        scenarios.append(
            {
                "name": f"path_{step:02d}_{_tag(key)}_{_delta_tag(float(delta_pct))}",
                "weights": copy.deepcopy(weights),
            }
        )

    output = copy.deepcopy(dict(base))
    output["status"] = "RESEARCH_ONLY_NO_GO"
    output["deployment_allowed"] = False
    output["basis"] = "locked_incumbent_cumulative_weight_path"
    output["scenarios"] = scenarios
    output["generator"] = {
        "tool": "tools/strategy_farm/portfolio/ftmo_incumbent_weight_probe.py",
        "base_scenario": base_scenario,
        "operations": applied,
        "contract": "ordered_cumulative_one_sleeve_delta_other_incumbents_proportional",
    }
    return output


def build_leave_one_out_manifest(
    base: Mapping[str, Any],
    *,
    base_scenario: str,
    control_name: str = "locked_control",
) -> dict[str, Any]:
    matches = [row for row in base.get("scenarios", []) if row.get("name") == base_scenario]
    if len(matches) != 1:
        raise ValueError(f"expected one base scenario {base_scenario!r}, found {len(matches)}")
    weights = {str(key): float(value) for key, value in matches[0]["weights"].items()}
    scenarios: list[dict[str, Any]] = [
        {"name": control_name, "weights": copy.deepcopy(weights)}
    ]
    for key, weight in weights.items():
        scenarios.append(
            {
                "name": f"drop_{_tag(key)}",
                "weights": perturb_weights(weights, key, -100.0 * weight),
            }
        )

    output = copy.deepcopy(dict(base))
    output["status"] = "RESEARCH_ONLY_NO_GO"
    output["deployment_allowed"] = False
    output["basis"] = "locked_incumbent_leave_one_out_probe"
    output["scenarios"] = scenarios
    output["generator"] = {
        "tool": "tools/strategy_farm/portfolio/ftmo_incumbent_weight_probe.py",
        "base_scenario": base_scenario,
        "contract": "one_sleeve_zero_weight_other_incumbents_proportional",
    }
    return output


def build_logistic_normal_manifest(
    base: Mapping[str, Any],
    *,
    base_scenario: str,
    seed: int,
    sigmas: Sequence[float],
    candidates_per_sigma: int,
    max_weight: float,
    max_l1_distance: float,
    control_name: str = "locked_control",
) -> dict[str, Any]:
    """Generate a deterministic, regularized multivariate weight search."""

    matches = [row for row in base.get("scenarios", []) if row.get("name") == base_scenario]
    if len(matches) != 1:
        raise ValueError(f"expected one base scenario {base_scenario!r}, found {len(matches)}")
    weights = {str(key): float(value) for key, value in matches[0]["weights"].items()}
    if not math.isclose(sum(weights.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        raise ValueError("base weights must sum to one")
    if any(not math.isfinite(value) or value <= 0.0 for value in weights.values()):
        raise ValueError("logistic-normal search requires finite positive base weights")
    if not sigmas or any(not math.isfinite(float(value)) or float(value) <= 0.0 for value in sigmas):
        raise ValueError("sigmas must be finite and positive")
    if candidates_per_sigma <= 0:
        raise ValueError("candidates_per_sigma must be positive")
    if not 0.0 < max_weight < 1.0:
        raise ValueError("max_weight must be in (0, 1)")
    if not 0.0 < max_l1_distance <= 2.0:
        raise ValueError("max_l1_distance must be in (0, 2]")

    rng = random.Random(int(seed))
    keys = list(weights)
    scenarios: list[dict[str, Any]] = [
        {"name": control_name, "weights": copy.deepcopy(weights)}
    ]
    accepted_by_sigma: dict[str, int] = {}
    attempts_by_sigma: dict[str, int] = {}
    seen: set[tuple[float, ...]] = set()
    max_attempts_per_sigma = max(1000, candidates_per_sigma * 200)
    for sigma_value in sigmas:
        sigma = float(sigma_value)
        sigma_tag = f"{sigma:g}".replace(".", "p")
        accepted = 0
        attempts = 0
        while accepted < candidates_per_sigma and attempts < max_attempts_per_sigma:
            attempts += 1
            raw = {
                key: weights[key] * math.exp(rng.normalvariate(0.0, sigma))
                for key in keys
            }
            total = sum(raw.values())
            candidate = {key: raw[key] / total for key in keys}
            l1_distance = sum(abs(candidate[key] - weights[key]) for key in keys)
            if max(candidate.values()) > max_weight or l1_distance > max_l1_distance:
                continue
            signature = tuple(round(candidate[key], 12) for key in keys)
            if signature in seen:
                continue
            seen.add(signature)
            accepted += 1
            scenarios.append(
                {
                    "name": f"global_sigma_{sigma_tag}_{accepted:03d}",
                    "weights": candidate,
                    "search_metadata": {
                        "sigma": sigma,
                        "l1_distance_from_control": l1_distance,
                    },
                }
            )
        if accepted != candidates_per_sigma:
            raise ValueError(
                f"could not generate {candidates_per_sigma} candidates for sigma {sigma:g} "
                f"within {max_attempts_per_sigma} attempts"
            )
        accepted_by_sigma[f"{sigma:g}"] = accepted
        attempts_by_sigma[f"{sigma:g}"] = attempts

    output = copy.deepcopy(dict(base))
    output["status"] = "RESEARCH_ONLY_NO_GO"
    output["deployment_allowed"] = False
    output["basis"] = "locked_incumbent_regularized_logistic_normal_weight_search"
    output["scenarios"] = scenarios
    output["generator"] = {
        "tool": "tools/strategy_farm/portfolio/ftmo_incumbent_weight_probe.py",
        "base_scenario": base_scenario,
        "seed": int(seed),
        "sigmas": [float(value) for value in sigmas],
        "candidates_per_sigma": int(candidates_per_sigma),
        "max_weight": float(max_weight),
        "max_l1_distance": float(max_l1_distance),
        "accepted_by_sigma": accepted_by_sigma,
        "attempts_by_sigma": attempts_by_sigma,
        "contract": "log_base_weight_plus_seeded_gaussian_then_simplex_normalize",
    }
    return output


def _parse_operations(raw: str) -> list[tuple[str, float]]:
    operations: list[tuple[str, float]] = []
    for item in raw.split(";"):
        item = item.strip()
        if not item:
            continue
        key, separator, value = item.rpartition("=")
        if not separator or not key:
            raise ValueError(f"invalid operation: {item!r}")
        operations.append((key, float(value)))
    return operations


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-manifest", type=Path, required=True)
    parser.add_argument("--base-scenario", required=True)
    parser.add_argument("--deltas-pct", default="-2,2,5")
    parser.add_argument(
        "--cumulative-operations",
        help="semicolon-separated KEY=DELTA_PCT operations; replaces one-factor probes",
    )
    parser.add_argument(
        "--leave-one-out",
        action="store_true",
        help="generate one scenario that removes each incumbent sleeve",
    )
    parser.add_argument(
        "--global-lognormal",
        action="store_true",
        help="generate a deterministic regularized multivariate weight search",
    )
    parser.add_argument("--seed", type=int, default=20260712)
    parser.add_argument("--sigmas", default="0.15,0.30,0.50")
    parser.add_argument("--candidates-per-sigma", type=int, default=24)
    parser.add_argument("--max-weight", type=float, default=0.25)
    parser.add_argument("--max-l1-distance", type=float, default=0.35)
    parser.add_argument("--control-name", default="locked_control")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    base = json.loads(args.base_manifest.read_text(encoding="utf-8-sig"))
    selected_modes = sum(
        bool(value)
        for value in (args.cumulative_operations, args.leave_one_out, args.global_lognormal)
    )
    if selected_modes > 1:
        parser.error(
            "--cumulative-operations, --leave-one-out, and --global-lognormal "
            "are mutually exclusive"
        )
    if args.global_lognormal:
        output = build_logistic_normal_manifest(
            base,
            base_scenario=args.base_scenario,
            seed=args.seed,
            sigmas=[float(value.strip()) for value in args.sigmas.split(",") if value.strip()],
            candidates_per_sigma=args.candidates_per_sigma,
            max_weight=args.max_weight,
            max_l1_distance=args.max_l1_distance,
            control_name=args.control_name,
        )
    elif args.leave_one_out:
        output = build_leave_one_out_manifest(
            base,
            base_scenario=args.base_scenario,
            control_name=args.control_name,
        )
    elif args.cumulative_operations:
        output = build_cumulative_manifest(
            base,
            base_scenario=args.base_scenario,
            operations=_parse_operations(args.cumulative_operations),
            control_name=args.control_name,
        )
    else:
        deltas = [float(value.strip()) for value in args.deltas_pct.split(",") if value.strip()]
        output = build_probe_manifest(
            base,
            base_scenario=args.base_scenario,
            deltas_pct=deltas,
            control_name=args.control_name,
        )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
