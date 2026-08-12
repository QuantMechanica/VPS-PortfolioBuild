"""Apply every preholdout-selected sleeve filter to a research manifest."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any, Mapping, Sequence


def sleeve_key(ea_id: Any, symbol: Any) -> str:
    return f"{int(ea_id)}:{str(symbol).upper()}"


def apply_selected_filters(
    manifest: Mapping[str, Any],
    selection: Mapping[str, Any],
) -> dict[str, Any]:
    contract = selection.get("selection_contract")
    if not isinstance(contract, Mapping) or contract.get("selection_uses_holdout") is not False:
        raise ValueError("selection does not prove holdout exclusion")
    rows = selection.get("sleeves")
    if not isinstance(rows, list):
        raise ValueError("selection sleeves are missing")

    filters: dict[str, str] = {}
    for row in rows:
        if not isinstance(row, Mapping):
            raise ValueError("selection sleeve must be an object")
        winner = row.get("selected_winner")
        if winner is None:
            continue
        if not isinstance(winner, Mapping) or not str(winner.get("rule") or "").strip():
            raise ValueError("selected winner rule is missing")
        key = sleeve_key(row["ea_id"], row["symbol"])
        if key in filters:
            raise ValueError(f"duplicate selected sleeve: {key}")
        filters[key] = str(winner["rule"])
    if not filters:
        raise ValueError("selection contains no winners")

    output = copy.deepcopy(dict(manifest))
    base_sleeves = output.get("sleeves")
    if not isinstance(base_sleeves, list):
        raise ValueError("manifest sleeves are missing")
    seen: set[str] = set()
    for sleeve in base_sleeves:
        key = sleeve_key(sleeve["ea_id"], sleeve["symbol"])
        if key in filters:
            sleeve["entry_filter"] = filters[key]
            seen.add(key)
    missing = sorted(set(filters) - seen)
    if missing:
        raise ValueError(f"selected sleeves absent from manifest: {missing}")

    output["status"] = "RESEARCH_ONLY_NO_GO"
    output["deployment_allowed"] = False
    output["basis"] = (
        "incumbent_weights_with_all_preholdout_selected_causal_sleeve_filters"
    )
    output["filter_application"] = filters
    output["generator"] = "tools/strategy_farm/portfolio/ftmo_apply_sleeve_filters.py"
    return output


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--selection", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    selection = json.loads(args.selection.read_text(encoding="utf-8-sig"))
    output = apply_selected_filters(manifest, selection)
    output["selection_artifact"] = str(args.selection)
    output["source_manifest"] = str(args.manifest)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "filters": len(output["filter_application"]),
                "status": output["status"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
