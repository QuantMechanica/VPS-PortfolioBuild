#!/usr/bin/env python3
"""Read-only reconciliation: Strategy Archive holes vs rebaseline backfill actions.

Answers Task A(2): are the archive's "reachable gap" cells the same set as the
backfill planner's per-pair FILL_MISSING actions? Where they differ, why, with
counts. Nothing is written to the farm DB; the backfill CSV is read from disk.

    python docs/ops/rebaseline/reconcile_archive_backfill.py
"""
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


def archive_holes() -> dict[tuple[str, str], str]:
    """(ea, symbol) -> gate of its single reachable gap, as the matrix draws it."""
    data = am.collect()
    holes: dict[tuple[str, str], str] = {}
    for card in data["cards"]:
        ea = card["ea"]
        syms = card["symbols"]
        for tok, _l, _g, _s in am.COLUMNS:
            for packed in card["cells"].get(tok, []):
                if (packed & 7) == am.ST_HOLE:
                    si = packed >> 3
                    holes[(ea, syms[si])] = tok
    return holes, data


def backfill_rows() -> list[dict]:
    with BACKFILL_CSV.open(encoding="utf-8") as fh:
        return [r for r in csv.DictReader(fh) if r.get("record_type") == "PAIR"]


def main() -> int:
    holes, data = archive_holes()
    rows = backfill_rows()
    by_action = Counter(r["action"] for r in rows)

    # backfill FILL_MISSING keyed by pair -> target gate
    fill_missing = {(r["ea_id"], r["symbol"]): r["target_gate"]
                    for r in rows if r["action"] == "FILL_MISSING"}
    all_actions = {(r["ea_id"], r["symbol"]): (r["action"], r["target_gate"])
                   for r in rows}

    hk = set(holes)
    fk = set(fill_missing)

    both = hk & fk
    gate_match = sum(1 for k in both if holes[k] == fill_missing[k])
    gate_mismatch = {k: (holes[k], fill_missing[k]) for k in both
                     if holes[k] != fill_missing[k]}

    only_archive = hk - fk
    only_backfill = fk - hk

    # classify archive-only holes by what the backfill said instead
    oa_by_backfill_action = Counter()
    oa_gate = Counter()
    for k in only_archive:
        oa_gate[holes[k]] += 1
        act = all_actions.get(k, ("<no pair row>", ""))[0]
        oa_by_backfill_action[act] += 1

    ob_gate = Counter(fill_missing[k] for k in only_backfill)

    print("=== TOTALS ===")
    print(f"archive reachable-gap pairs (one gap each): {len(hk)}")
    print(f"  (matrix reports total hole cells: {sum(data['hole_by_gate'].values())})")
    print(f"  archive hole_by_gate: {dict(data['hole_by_gate'].most_common())}")
    print(f"  archive untested_targets (frontmatter, synthetic Q02 gaps): {data['untested_targets']}")
    print(f"backfill pair rows: {len(rows)}  actions={dict(by_action)}")
    print(f"backfill FILL_MISSING pairs: {len(fk)}")
    print(f"  FILL_MISSING by target gate: {dict(Counter(fill_missing.values()).most_common())}")
    print()
    print("=== INTERSECTION (pairs in both hole-set and FILL_MISSING) ===")
    print(f"in both: {len(both)}  gate agrees: {gate_match}  gate differs: {len(gate_mismatch)}")
    if gate_mismatch:
        c = Counter((a, b) for a, b in gate_mismatch.values())
        print(f"  gate-mismatch (archive_gate -> backfill_gate): {dict(c.most_common(12))}")
    print()
    print("=== ARCHIVE-ONLY (matrix shows a gap, backfill has no FILL_MISSING) ===")
    print(f"count: {len(only_archive)}")
    print(f"  by archive gate: {dict(oa_gate.most_common())}")
    print(f"  what backfill said instead: {dict(oa_by_backfill_action.most_common())}")
    print()
    print("=== BACKFILL-ONLY (FILL_MISSING, matrix shows no gap) ===")
    print(f"count: {len(only_backfill)}")
    print(f"  by backfill target gate: {dict(ob_gate.most_common())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
