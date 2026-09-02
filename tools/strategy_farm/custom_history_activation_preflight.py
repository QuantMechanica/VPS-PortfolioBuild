#!/usr/bin/env python3
"""Read-only authority preflight for a Custom-history v2 activation install."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    import custom_history_gate
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm import custom_history_gate


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--farm-root", type=Path, required=True)
    parser.add_argument("--activation", type=Path, required=True)
    parser.add_argument("--post-ignition-ramp", type=Path, required=True)
    args = parser.parse_args()

    try:
        activation = custom_history_gate._load_bound_json(
            args.activation, label="candidate activation"
        )
        receipt = custom_history_gate.preflight_activation_install(
            args.farm_root,
            activation=activation,
            post_ignition_ramp_path=args.post_ignition_ramp,
        )
    except Exception as exc:
        print(
            json.dumps(
                {
                    "status": "REFUSED",
                    "error": f"{type(exc).__name__}: {exc}",
                    "live_install_performed": False,
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(receipt, indent=2, sort_keys=True, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
