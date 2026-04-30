#!/usr/bin/env python3
"""P6 multi-seed verdict runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_float,
    parse_int,
    row_passes,
    update_result_with_evidence_path,
    write_phase_artifacts,
)

DEFAULT_SEEDS_TEXT = "42,17,99,7,2026"


def _text_or_none(value: object) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if text == "":
        return None
    return text


def _parse_seeds(seed_text: str) -> list[int]:
    seeds: list[int] = []
    seen: set[int] = set()
    for chunk in seed_text.split(","):
        token = chunk.strip()
        if token == "":
            continue
        seed = int(token)
        if seed in seen:
            continue
        seen.add(seed)
        seeds.append(seed)
    if not seeds:
        raise ValueError("At least one seed is required")
    return seeds


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate P6 multi-seed verdict")
    add_common_args(parser)
    parser.add_argument("--seeds-csv", required=True)
    parser.add_argument("--seeds", default=DEFAULT_SEEDS_TEXT)
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P6")

    required_seeds = _parse_seeds(args.seeds)

    rows = load_csv_rows(Path(args.seeds_csv))
    seed_rows: dict[int, dict[str, str]] = {}
    for row in rows:
        seed = parse_int(row.get("seed"), -1)
        if seed >= 0:
            seed_rows[seed] = row

    missing_seeds = [seed for seed in required_seeds if seed not in seed_rows]

    pass_count = 0
    has_pf_below_one = False
    seed_metrics: list[dict[str, object]] = []
    incomplete_seeds: list[int] = []
    for seed in required_seeds:
        row = seed_rows.get(seed)
        if not row:
            continue
        pf_text = _text_or_none(row.get("pf", row.get("profit_factor")))
        verdict_text = _text_or_none(row.get("verdict", row.get("status", row.get("result", row.get("pass")))))
        evidence_complete = pf_text is not None and verdict_text is not None
        if not evidence_complete:
            incomplete_seeds.append(seed)

        passed = row_passes(row)
        if passed:
            pass_count += 1
        pf_value = parse_float(pf_text, 0.0) if pf_text is not None else None
        pf_below_one = pf_value is not None and pf_value < 1.0
        if pf_below_one:
            has_pf_below_one = True
        seed_metrics.append(
            {
                "seed": seed,
                "evidence_complete": evidence_complete,
                "passed": passed,
                "pf": pf_value,
                "pf_below_one": pf_below_one,
                "verdict_raw": verdict_text,
            }
        )

    if missing_seeds or incomplete_seeds:
        verdict = "MULTI_SEED_WAIVER"
        criterion = "Evidence missing or incomplete for one or more required seeds"
    elif pass_count >= 3 and not has_pf_below_one:
        verdict = "MULTI_SEED_PASS"
        criterion = ">=3 seeds PASS and no seed PF < 1.0"
    elif pass_count >= 3 and has_pf_below_one:
        verdict = "MULTI_SEED_MIXED"
        criterion = ">=3 seeds PASS but at least one seed PF < 1.0"
    else:
        verdict = "MULTI_SEED_FAIL"
        criterion = "Fewer than 3 seeds PASS"

    details = {
        "has_pf_below_one": has_pf_below_one,
        "incomplete_seeds": incomplete_seeds,
        "missing_seeds": missing_seeds,
        "pass_count": pass_count,
        "required_seeds": required_seeds,
        "seed_metrics": seed_metrics,
    }

    result = build_result(
        phase="P6",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details=details,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P6", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
