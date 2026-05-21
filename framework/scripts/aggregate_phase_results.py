#!/usr/bin/env python3
"""Aggregate phase result JSON files into a per-EA index."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import ensure_dir, load_json, write_json

EXPECTED_PHASES = ["P3.5", "P5", "P5b", "P5c", "P6", "P7", "P8"]
REQUIRED_PHASES = ("P3.5", "P5", "P5b", "P6", "P7", "P8")
PHASE_DISPLAY = {
    "P3.5": "Q04",
    "P5": "Q06",
    "P5b": "Q07",
    "P5c": "Q08",
    "P6": "Q09",
    "P7": "Q10",
    "P8": "Q11",
}

PASS_VERDICTS = {
    "P3.5": {"AUTO_PASS", "PASS"},
    "P5": {"PASS"},
    "P5b": {"PASS"},
    "P6": {"MULTI_SEED_PASS", "PASS"},
    "P7": {"PASS"},
    "P8": {"MODE_SELECTED"},
}

REVIEW_REQUIRED_VERDICTS = {
    "P5b": {"YELLOW"},
    "P6": {"MULTI_SEED_WAIVER"},
}


def normalize_verdict(value: object) -> str:
    return str(value or "MISSING").strip().upper()


def main() -> int:
    parser = argparse.ArgumentParser(description="Aggregate phase runner outputs into index.json")
    parser.add_argument("--ea", required=True)
    parser.add_argument("--input-root", default="D:/QM/reports/pipeline")
    parser.add_argument("--output-root", default="D:/QM/reports/pipeline")
    args = parser.parse_args()

    ea_id = args.ea
    input_root = Path(args.input_root) / ea_id
    output_dir = ensure_dir(Path(args.output_root) / ea_id)

    by_phase = {}
    for phase in EXPECTED_PHASES:
        phase_token = phase.replace(".", "_")
        phase_dir = input_root / phase
        result_file = phase_dir / f"{phase_token}_{ea_id}_result.json"
        if not result_file.exists():
            legacy_phase_dir = input_root / phase_token
            legacy_result_file = legacy_phase_dir / f"{phase_token}_{ea_id}_result.json"
            if legacy_result_file.exists():
                result_file = legacy_result_file
        if result_file.exists():
            by_phase[phase] = load_json(result_file)
        else:
            by_phase[phase] = {
                "phase": phase,
                "verdict": "MISSING",
                "evidence_path": str(result_file),
            }

    blockers = []
    review_required = []
    for phase in REQUIRED_PHASES:
        verdict = normalize_verdict(by_phase[phase].get("verdict", "MISSING"))
        if verdict in PASS_VERDICTS.get(phase, set()):
            continue
        if verdict in REVIEW_REQUIRED_VERDICTS.get(phase, set()):
            review_required.append({"phase": phase, "verdict": verdict})
            continue
        blockers.append({"phase": phase, "verdict": verdict})

    if blockers:
        final_verdict = "BLOCKED"
    elif review_required:
        final_verdict = "REVIEW_REQUIRED"
    else:
        final_verdict = "READY"

    index = {
        "ea_id": ea_id,
        "final_verdict": final_verdict,
        "phase_blockers": blockers,
        "phase_review_required": review_required,
        "phases": by_phase,
        "required_phases": list(REQUIRED_PHASES),
        "phase_display": PHASE_DISPLAY,
    }

    out_path = output_dir / "index.json"
    write_json(out_path, index)
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
