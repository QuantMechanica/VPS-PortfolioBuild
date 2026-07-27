#!/usr/bin/env python3
"""Fidelity diff for the QM5_20180 joint FTMO backtest EA (singleton replay).

Requirement #3 of the joint-EA build: prove that a sleeve of the joint EA trades
what the gated single-symbol EA traded. Run the joint EA with ONE sleeve enabled
(sets ``..._replay_s0.set`` / ``..._replay_s1.set``) over the gated window, then
compare its Q08 ``TRADE_CLOSED`` stream against the gated sleeve's stream with
this script.

The per-sleeve magic DIFFERS by construction (re-magicked under ea_id 20180), so
the comparison keys on the trade identity that must be invariant under
re-magicking: (entry_time, close_time, net, volume). A trade matches iff all four
agree (net/volume to the cent / to the volume step). The reported match rate is
the fidelity metric. A low match rate is a FINDING to report, not to tune away.

    python compare_joint_replay.py --joint <joint_singleton.jsonl> \
                                   --gated <gated_sleeve.jsonl> [--money-tol 0.005]

Exit code 0 iff match_rate == 1.0 (bit-for-bit), else 2.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_closed(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open(encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("event") != "TRADE_CLOSED":
                continue
            rows.append(o)
    return rows


def key(o: dict) -> tuple[int, int]:
    # Order-independent identity used for pairing: (entry_time, close_time).
    return (int(o.get("entry_time", 0)), int(o.get("time", 0)))


def classify(joint: list[dict], gated: list[dict], money_tol: float, vol_tol: float) -> dict:
    """Pair deterministically and classify every non-exact trade."""
    remaining = list(gated)
    counts = {
        "exact": 0,
        "same_entry_same_volume_shifted_exit": 0,
        "different_entry": 0,
        "extra": 0,
        "missing": 0,
    }
    for row in joint:
        exact = next((g for g in remaining
                      if key(row) == key(g)
                      and abs(float(row.get("net", 0)) - float(g.get("net", 0))) <= money_tol
                      and abs(float(row.get("volume", 0)) - float(g.get("volume", 0))) <= vol_tol), None)
        if exact is not None:
            counts["exact"] += 1
            remaining.remove(exact)
            continue
        shifted = next((g for g in remaining
                        if int(row.get("entry_time", 0)) == int(g.get("entry_time", 0))
                        and abs(float(row.get("volume", 0)) - float(g.get("volume", 0))) <= vol_tol), None)
        if shifted is not None:
            counts["same_entry_same_volume_shifted_exit"] += 1
            remaining.remove(shifted)
            continue
        same_ordinal = remaining.pop(0) if remaining else None
        if same_ordinal is not None:
            counts["different_entry"] += 1
        else:
            counts["extra"] += 1
    counts["missing"] = len(remaining)
    return counts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--joint", required=True, type=Path,
                    help="joint-EA singleton Q08 stream (20180_USDJPY_DWX.jsonl)")
    ap.add_argument("--gated", required=True, type=Path,
                    help="gated sleeve Q08 stream (9936_/13213_USDJPY_DWX.jsonl)")
    ap.add_argument("--money-tol", type=float, default=0.005,
                    help="absolute tolerance for net (USD); default 0.005 = half a cent")
    ap.add_argument("--vol-tol", type=float, default=0.005,
                    help="absolute tolerance for volume (lots); default 0.005 = half a step")
    ap.add_argument("--max-report", type=int, default=20,
                    help="max mismatches to print")
    args = ap.parse_args()

    joint = load_closed(args.joint)
    gated = load_closed(args.gated)
    categories = classify(joint, gated, args.money_tol, args.vol_tol)

    gated_by_key: dict[tuple[int, int], list[dict]] = {}
    for o in gated:
        gated_by_key.setdefault(key(o), []).append(o)

    matched = 0
    mismatches: list[str] = []
    unmatched_joint = 0
    for o in joint:
        cand = gated_by_key.get(key(o))
        hit = None
        if cand:
            for g in cand:
                if (abs(float(o.get("net", 0)) - float(g.get("net", 0))) <= args.money_tol and
                        abs(float(o.get("volume", 0)) - float(g.get("volume", 0))) <= args.vol_tol):
                    hit = g
                    break
        if hit is not None:
            matched += 1
            cand.remove(hit)
        else:
            unmatched_joint += 1
            if len(mismatches) < args.max_report:
                mismatches.append(
                    f"  joint entry={o.get('entry_time')} close={o.get('time')} "
                    f"net={o.get('net')} vol={o.get('volume')} -> no gated match")

    leftover_gated = sum(len(v) for v in gated_by_key.values())
    denom = max(len(joint), len(gated))
    match_rate = (matched / denom) if denom else 1.0

    print(json.dumps({
        "joint_trades": len(joint),
        "gated_trades": len(gated),
        "matched": matched,
        "unmatched_joint": unmatched_joint,
        "unmatched_gated": leftover_gated,
        "match_rate": round(match_rate, 6),
        "mismatch_categories": categories,
    }, indent=2))
    if mismatches:
        print("first mismatches:")
        print("\n".join(mismatches))

    return 0 if (match_rate == 1.0 and unmatched_joint == 0 and leftover_gated == 0) else 2


if __name__ == "__main__":
    raise SystemExit(main())
