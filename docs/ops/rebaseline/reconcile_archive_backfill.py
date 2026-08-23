#!/usr/bin/env python3
"""Read-only reconciliation of archive work gaps and the governed backfill plan."""
from __future__ import annotations

import csv
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm" / "dashboards"))

import archive_matrix as am  # noqa: E402

BACKFILL_CSV = Path("D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv")
ACTIONABLE = {"FILL_MISSING", "RERUN_INFRA", "REBIND_STALE"}


def archive_actions() -> tuple[dict[tuple[str, str], tuple[str, str]], dict]:
    """Return work-item-backed archive gaps; Card-Ziel gaps stay separate."""
    data = am.collect()
    actions: dict[tuple[str, str], tuple[str, str]] = {}
    for card in data["cards"]:
        for gate, cells in card["cells"].items():
            for cell in cells:
                if cell["state"] != am.ST_HOLE:
                    continue
                symbol = card["symbols"][cell["symbol_index"]]
                actions[(card["ea"], symbol)] = (gate, str(cell["action"]))
    return actions, data


def backfill_rows() -> list[dict]:
    with BACKFILL_CSV.open(encoding="utf-8", newline="") as handle:
        return [row for row in csv.DictReader(handle) if row.get("record_type") == "PAIR"]


def main() -> int:
    archive, data = archive_actions()
    rows = backfill_rows()
    planned = {
        (row["ea_id"], row["symbol"]): (row["target_gate"], row["action"])
        for row in rows if row["action"] in ACTIONABLE
    }

    archive_keys = set(archive)
    planned_keys = set(planned)
    both = archive_keys & planned_keys
    mismatches = {key: (archive[key], planned[key]) for key in both
                  if archive[key] != planned[key]}
    archive_only = archive_keys - planned_keys
    backfill_only = planned_keys - archive_keys

    print("=== TOTALS ===")
    print(f"archive work-item gap pairs: {len(archive_keys)}")
    print(f"  by action: {dict(Counter(action for _, action in archive.values()).most_common())}")
    print(f"  by gate: {dict(Counter(gate for gate, _ in archive.values()).most_common())}")
    print(f"archive second-source Card-Ziel gaps: {data['untested_targets']}")
    print(f"backfill actionable pairs: {len(planned_keys)}")
    print(f"  by action: {dict(Counter(action for _, action in planned.values()).most_common())}")
    print()
    print("=== INTERSECTION ===")
    print(f"in both: {len(both)}  exact gate+action: {len(both) - len(mismatches)}  "
          f"mismatch: {len(mismatches)}")
    if mismatches:
        print(f"  mismatch classes: {dict(Counter(mismatches.values()).most_common(12))}")
    print()
    print("=== ARCHIVE-ONLY ===")
    print(f"count: {len(archive_only)}")
    print(f"  by gate/action: {dict(Counter(archive[key] for key in archive_only).most_common())}")
    print()
    print("=== BACKFILL-ONLY ===")
    print(f"count: {len(backfill_only)}")
    print(f"  by gate/action: {dict(Counter(planned[key] for key in backfill_only).most_common())}")
    archive_eas = {card["ea"] for card in data["cards"]}
    causes = Counter()
    for ea_id, symbol in backfill_only:
        if am.symbol_class(symbol) == "relic":
            causes["relic symbol excluded by archive F7"] += 1
        elif ea_id not in archive_eas:
            causes["no manifest-gate row/card row on archive surface"] += 1
        else:
            causes["unclassified"] += 1
    print(f"  causes: {dict(causes.most_common())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
