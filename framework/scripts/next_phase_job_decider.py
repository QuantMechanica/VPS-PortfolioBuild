#!/usr/bin/env python3
"""Derive transition-ready queue jobs from per-EA phase results."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

DEFAULT_PHASE_RESULTS = Path(r"D:\QM\Reports\pipeline\phase_results_latest.json")
DEFAULT_OUT = Path(r"D:\QM\Reports\pipeline\multi_ea_transition_ready.json")

NEXT_PHASE = {
    "P0": "P1",
    "P1": "P2",
    "P2": "P3.5",
    "P3.5": "P5",
    "P5": "P5b",
    "P5b": "P5c",
    "P5c": "P6",
    "P6": "P7",
    "P7": "P8",
    "P8": "P10",
}
PASS_VERDICTS = {"PASS", "AUTO_PASS"}


def _s(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{name} must be non-empty string")
    return value.strip()


def derive_transition_jobs(results: list[dict[str, Any]]) -> list[dict[str, str]]:
    jobs: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for row in results:
        ea_id = _s(row.get("ea_id"), "ea_id")
        phase = _s(row.get("phase"), "phase")
        symbol = _s(row.get("symbol"), "symbol")
        verdict = _s(row.get("verdict"), "verdict").upper()
        config_hash = _s(row.get("config_hash"), "config_hash")

        if verdict not in PASS_VERDICTS:
            continue
        next_phase = NEXT_PHASE.get(phase)
        if not next_phase:
            continue
        if not symbol.endswith(".DWX"):
            raise ValueError(f"symbol must end with .DWX: {symbol}")

        key = (ea_id, next_phase, symbol)
        if key in seen:
            continue
        seen.add(key)
        jobs.append(
            {
                "ea_id": ea_id,
                "phase": next_phase,
                "symbol": symbol,
                "config_hash": config_hash,
            }
        )
    return jobs


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Derive transition-ready jobs from phase results")
    parser.add_argument("--phase-results", type=Path, default=DEFAULT_PHASE_RESULTS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    with args.phase_results.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, list):
        raise ValueError("phase results payload must be array")
    jobs = derive_transition_jobs(payload)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(jobs, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(json.dumps({"transition_ready": len(jobs), "out": str(args.out)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
