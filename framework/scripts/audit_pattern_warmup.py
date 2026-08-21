#!/usr/bin/env python3
"""Measure the fail-closed pattern-permission warm-up contract.

This is a source-bound controlled reproduction, not an economic backtest. It
parses the canonical predicate enum and QM_PP_RequiredBars switch, then walks
the exact CopyRates availability boundary (0..required closed bars) for every
predicate depth. The real tester marker is verified separately by the fixture
harness; this tool makes the denied-bar arithmetic reproducible and reviewable.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts import build_pattern_fixture_bundle as bundle

TIMEFRAME_MINUTES = {
    "M5": 5,
    "M15": 15,
    "H1": 60,
    "H4": 240,
    "D1": 1440,
}


def reproduce_depth(required_bars: int) -> dict:
    """Walk the start-of-history states until the first permitted evaluation."""
    states = []
    for available_closed_bars in range(required_bars + 1):
        if available_closed_bars == 0:
            reason = "reference_bar_unavailable"
            valid = False
        elif available_closed_bars < required_bars:
            reason = "insufficient_or_invalid_history"
            valid = False
        else:
            reason = "history_ready"
            valid = True
        states.append(
            {
                "current_bar_index": available_closed_bars,
                "available_closed_bars": available_closed_bars,
                "valid": valid,
                "reason": reason,
            }
        )
    assert states[-1]["valid"] is True
    assert all(not row["valid"] for row in states[:-1])
    return {
        "required_closed_bars": required_bars,
        "reference_unavailable_denied_bars": 1,
        "insufficient_history_denied_bars": max(0, required_bars - 1),
        "total_start_bars_denied": required_bars,
        "first_tradable_current_bar_index": required_bars,
        "states": states,
    }


def measure() -> dict:
    source = bundle._strip_comments(bundle.HEADER.read_text(encoding="utf-8"))
    ids = bundle.parse_predicate_ids(source)
    required_map, required_default = bundle.parse_required_bars(source)
    requirements = {name: required_map.get(name, required_default) for name in ids}
    if len(requirements) != 77:
        raise RuntimeError(f"expected 77 predicates, found {len(requirements)}")

    by_depth = Counter(requirements.values())
    depth_rows = []
    for depth, predicate_count in sorted(by_depth.items()):
        reproduction = reproduce_depth(depth)
        depth_rows.append(
            {
                **{key: value for key, value in reproduction.items() if key != "states"},
                "predicate_count": predicate_count,
                "predicates": sorted(name for name, value in requirements.items() if value == depth),
            }
        )

    worst_depth = max(by_depth)
    worst = reproduce_depth(worst_depth)
    timeframe_rows = []
    for timeframe, minutes in TIMEFRAME_MINUTES.items():
        timeframe_rows.append(
            {
                "timeframe": timeframe,
                "worst_required_closed_bars": worst_depth,
                "worst_total_start_bars_denied": worst["total_start_bars_denied"],
                "first_tradable_current_bar_index": worst["first_tradable_current_bar_index"],
                "nominal_elapsed_minutes_to_first_tradable_bar": worst_depth * minutes,
                "nominal_elapsed_hours_to_first_tradable_bar": round(worst_depth * minutes / 60, 4),
            }
        )

    key_match = re.search(r"const string key = (.*?);", source, re.S)
    if not key_match:
        raise RuntimeError("cache key not found")
    key_expression = " ".join(key_match.group(1).split())
    key_components = ["symbol", "reference_tf", "ref_bar", "QM_PP_ProfileKey(profile)"]
    if not all(component in key_expression for component in key_components):
        raise RuntimeError(f"cache key contract incomplete: {key_expression}")

    return {
        "schema": "qm.pattern-warmup-measurement/v1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source_path": str(bundle.HEADER.resolve()),
        "predicate_count": len(requirements),
        "depth_distribution": {str(depth): count for depth, count in sorted(by_depth.items())},
        "depth_measurements": depth_rows,
        "timeframe_worst_case": timeframe_rows,
        "worst_case": {
            **{key: value for key, value in worst.items() if key != "states"},
            "predicates": sorted(name for name, value in requirements.items() if value == worst_depth),
        },
        "cache_scope": {
            "expression": key_expression,
            "components": key_components,
            "verdict": "NO_DEFECT_REFERENCE_BAR_SCOPED",
            "reason": "ref_bar is part of the key, so a cached denial cannot be reused for the next reference bar",
        },
        "calculation_basis": {
            "bar_zero": "no closed reference bar; reference_bar_unavailable",
            "bars_one_through_required_minus_one": "CopyRates returns fewer than need; insufficient_or_invalid_history",
            "bar_required": "need closed bars exist; first history-valid evaluation",
            "timeframe_duration": "nominal bar duration only; weekends and exchange closures are not converted into wall-clock estimates",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="optional JSON artifact path")
    args = parser.parse_args()
    payload = measure()
    rendered = json.dumps(payload, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
        print(args.output.resolve())
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
