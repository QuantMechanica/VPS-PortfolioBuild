"""Merge disjoint FTMO governor scenario artifacts with strict metadata checks."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Mapping, Sequence


IDENTITY_FIELDS = (
    "schema_version",
    "status",
    "basis",
    "timestamp_basis",
    "fill_contract",
    "manifest",
    "horizon_calendar_days",
    "excluded_years",
    "trade_paths",
    "start_windows",
)


def _result_identity(row: Mapping[str, Any]) -> tuple[Any, ...]:
    return (
        row.get("scenario"),
        row.get("risk_multiplier"),
        row.get("daily_stop"),
        row.get("full_risk_room"),
        row.get("room_retention"),
        row.get("open_risk_limit_ratio"),
        json.dumps(row.get("profit_risk_steps", []), sort_keys=True),
        json.dumps(row.get("elapsed_risk_steps", []), sort_keys=True),
    )


def merge_artifacts(artifacts: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    if len(artifacts) < 2:
        raise ValueError("at least two artifacts are required")
    reference = artifacts[0]
    for index, artifact in enumerate(artifacts[1:], start=2):
        drift = [
            field
            for field in IDENTITY_FIELDS
            if artifact.get(field) != reference.get(field)
        ]
        if drift:
            raise ValueError(f"artifact {index} metadata drift: {drift}")

    results: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()
    for artifact in artifacts:
        for source_row in artifact.get("results", []):
            row = dict(source_row)
            identity = _result_identity(row)
            if identity in seen:
                raise ValueError(f"duplicate result identity: {identity}")
            seen.add(identity)
            results.append(row)
    if not results:
        raise ValueError("artifacts contain no results")
    results.sort(key=_result_identity)

    output = {field: reference.get(field) for field in IDENTITY_FIELDS}
    output["results"] = results
    output["merged_chunk_count"] = len(artifacts)
    output["merged_result_count"] = len(results)
    return output


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, action="append", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = merge_artifacts(
        [json.loads(path.read_text(encoding="utf-8-sig")) for path in args.input]
    )
    output["source_artifacts"] = [str(path) for path in args.input]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"wrote {args.out} chunks={output['merged_chunk_count']} "
        f"results={output['merged_result_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
