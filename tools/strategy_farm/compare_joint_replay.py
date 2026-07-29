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

    python compare_joint_replay.py --joint <joint_book.jsonl> \
                                   --joint-magic 201810001 \
                                   --gated <gated_sleeve.jsonl> \
                                   --gated-magic 101450000 [--money-tol 0.005]

The magic filters are optional for backwards-compatible singleton operands and
required in practice when the joint stream contains more than one sleeve.  An
empty filtered operand is invalid and can never pass.  Exit code 0 iff both
operands are non-empty and match_rate == 1.0 (bit-for-bit), else 2.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_closed(
    path: Path,
    *,
    magic: int | None = None,
    symbol: str | None = None,
) -> list[dict]:
    """Load closed trades, optionally selecting one exact sleeve identity."""

    rows: list[dict] = []
    expected_symbol = symbol.strip().upper() if symbol is not None else None
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
            if magic is not None:
                try:
                    observed_magic = int(o.get("magic"))
                except (TypeError, ValueError):
                    continue
                if observed_magic != magic:
                    continue
            if expected_symbol is not None:
                observed_symbol = str(o.get("symbol") or "").strip().upper()
                if observed_symbol != expected_symbol:
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


def positive_magic(value: str) -> int:
    """Argparse type for registry magics, which are strictly positive ints."""

    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("magic must be an integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("magic must be greater than zero")
    return parsed


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--joint", required=True, type=Path,
                    help="joint-EA singleton Q08 stream (20180_USDJPY_DWX.jsonl)")
    ap.add_argument("--gated", required=True, type=Path,
                    help="gated sleeve Q08 stream (9936_/13213_USDJPY_DWX.jsonl)")
    ap.add_argument("--joint-magic", type=positive_magic,
                    help="select this exact magic from the joint stream")
    ap.add_argument("--gated-magic", type=positive_magic,
                    help="select this exact magic from the gated stream")
    ap.add_argument("--joint-symbol",
                    help="optionally select this exact symbol from the joint stream")
    ap.add_argument("--gated-symbol",
                    help="optionally select this exact symbol from the gated stream")
    ap.add_argument("--money-tol", type=float, default=0.005,
                    help="absolute tolerance for net (USD); default 0.005 = half a cent")
    ap.add_argument("--vol-tol", type=float, default=0.005,
                    help="absolute tolerance for volume (lots); default 0.005 = half a step")
    ap.add_argument("--max-report", type=int, default=20,
                    help="max mismatches to print")
    args = ap.parse_args(argv)

    joint = load_closed(
        args.joint,
        magic=args.joint_magic,
        symbol=args.joint_symbol,
    )
    gated = load_closed(
        args.gated,
        magic=args.gated_magic,
        symbol=args.gated_symbol,
    )
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
    operands_nonempty = bool(joint) and bool(gated)
    match_rate = (matched / denom) if operands_nonempty else None
    result = {
        "valid": operands_nonempty,
        "reason": None if operands_nonempty else "empty_filtered_operand",
        "joint_trades": len(joint),
        "gated_trades": len(gated),
        "matched": matched,
        "unmatched_joint": unmatched_joint,
        "unmatched_gated": leftover_gated,
        "match_rate": round(match_rate, 6) if match_rate is not None else None,
        "mismatch_categories": categories,
        "filters": {
            "joint_magic": args.joint_magic,
            "gated_magic": args.gated_magic,
            "joint_symbol": args.joint_symbol,
            "gated_symbol": args.gated_symbol,
        },
    }
    print(json.dumps(result, indent=2))
    if mismatches:
        print("first mismatches:")
        print("\n".join(mismatches))

    return 0 if (
        operands_nonempty
        and match_rate == 1.0
        and unmatched_joint == 0
        and leftover_gated == 0
    ) else 2


if __name__ == "__main__":
    raise SystemExit(main())
