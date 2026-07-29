#!/usr/bin/env python3
"""Fidelity diff for the QM5_20180 joint FTMO backtest EA (singleton replay).

Requirement #3 of the joint-EA build: prove that a sleeve of the joint EA trades
what the gated single-symbol EA traded. Run the joint EA with ONE sleeve enabled
(sets ``..._replay_s0.set`` / ``..._replay_s1.set``) over the gated window, then
compare its Q08 ``TRADE_CLOSED`` stream against the gated sleeve's stream with
this script.  The current V2 contract accepts only actual full-position money:
standalone rows carry ``FULL_POSITION_LIFECYCLE_ACTUAL_V1`` and joint rows carry
the lifecycle-v2 producer schema.  Legacy closing-deal-only money is rejected;
it is never repaired by assuming a second commission side.

The per-sleeve magic DIFFERS by construction (re-magicked under ea_id 20180), so
the comparison keys on the trade identity that must be invariant under
re-magicking: entry/close time, canonical side, exact entry/exit prices, all
full-lifecycle money components, and volume. A trade matches iff all fields
agree within the fixed money/volume tolerances and the governed zero price
tolerance.
The reported match rate is the fidelity metric. A low match rate is a FINDING to
report, not to tune away.

The lifecycle-v2 lineage grammar is validated for ordered multi-exit histories,
but the current Book-3 joint producer deliberately setup-blocks more than one
exit deal: its row is per position while the standalone stream is per exit.

    python compare_joint_replay.py --joint <joint_book.jsonl> \
                                   --expected-joint-run-id FTMO_BOOK3_20260729_V2_J0 \
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
import math
import sys
from pathlib import Path


FULL_LIFECYCLE_MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
JOINT_PRODUCER_VERSION = "QM5_20181_FTMO_TRACE_V2"
GOVERNED_MONEY_TOLERANCE = 0.005
GOVERNED_VOLUME_TOLERANCE = 0.005
GOVERNED_PRICE_TOLERANCE = 0.0
CANONICAL_SIDES = frozenset({"BUY", "SELL"})
GOVERNED_RUN_IDS = frozenset(
    f"FTMO_BOOK3_20260729_V2_J{stage}" for stage in range(3)
)
MONEY_COMPONENT_KEYS = (
    "profit",
    "swap",
    "fee",
    "entry_commission",
    "exit_commission",
    "commission",
    "net",
)


def _number(value, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        raise ValueError(f"{label} must be numeric")
    try:
        parsed = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{label} must be numeric") from exc
    if not math.isfinite(parsed):
        raise ValueError(f"{label} must be finite")
    return parsed


def _governed_tolerance(value: object, *, label: str, maximum: float) -> float:
    parsed = _number(value, label)
    if parsed < 0.0:
        raise ValueError(f"{label} must be non-negative")
    if parsed > maximum:
        raise ValueError(f"{label} exceeds governed maximum {maximum}")
    return parsed


def governed_tolerance_arg(*, label: str, maximum: float):
    def parse(value: str) -> float:
        try:
            return _governed_tolerance(value, label=label, maximum=maximum)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(str(exc)) from exc

    return parse


def governed_run_id(value: str) -> str:
    if value not in GOVERNED_RUN_IDS:
        raise argparse.ArgumentTypeError(
            "expected joint run ID must be one of " + ", ".join(sorted(GOVERNED_RUN_IDS))
        )
    return value


def _positive_exact_int(value: object, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValueError(f"{label} must be a positive integer")
    return value


def _positive_deal_ids(value: object, label: str) -> list[int]:
    if not isinstance(value, list) or not value:
        raise ValueError(f"{label} must be a non-empty array")
    ids = [_positive_exact_int(item, f"{label}[{index}]") for index, item in enumerate(value)]
    if len(ids) != len(set(ids)):
        raise ValueError(f"{label} contains duplicate deal IDs")
    return ids


def validate_full_lifecycle_rows(
    rows: list[dict], *, role: str, money_tol: float,
    expected_run_id: str | None = None,
) -> list[dict]:
    """Return rows only after their actual lifecycle money reconciles."""

    money_tol = _governed_tolerance(
        money_tol, label="money tolerance", maximum=GOVERNED_MONEY_TOLERANCE
    )
    if role == "joint" and expected_run_id not in GOVERNED_RUN_IDS:
        raise ValueError("joint comparison requires an exact governed expected run ID")
    validated: list[dict] = []
    for index, source in enumerate(rows, start=1):
        row = dict(source)
        label = f"{role} trade {index}"
        entry_time = _positive_exact_int(row.get("entry_time"), f"{label} entry_time")
        close_time = _positive_exact_int(row.get("time"), f"{label} time")
        if close_time <= entry_time:
            raise ValueError(f"{label} time order invalid")
        side = row.get("side")
        if not isinstance(side, str) or side not in CANONICAL_SIDES:
            raise ValueError(f"{label} side must be canonical BUY or SELL")
        entry_price = _number(row.get("entry_price"), f"{label} entry_price")
        exit_price = _number(row.get("exit_price"), f"{label} exit_price")
        if entry_price <= 0.0 or exit_price <= 0.0:
            raise ValueError(f"{label} entry/exit prices must be positive")
        entry_ids: list[int] = []
        exit_ids: list[int] = []
        events: list[dict] = []
        if role == "standalone":
            if "schema_version" in row:
                raise ValueError(f"{label} schema_version is ambiguous")
            if row.get("money_basis") != FULL_LIFECYCLE_MONEY_BASIS:
                raise ValueError(f"{label} money_basis mismatch")
        elif role == "joint":
            if row.get("schema_version") != 2:
                raise ValueError(f"{label} schema_version mismatch")
            if row.get("producer_version") != JOINT_PRODUCER_VERSION:
                raise ValueError(f"{label} producer_version mismatch")
            if row.get("run_id") != expected_run_id:
                raise ValueError(f"{label} run_id mismatch")
            if row.get("position_fully_closed") is not True:
                raise ValueError(f"{label} is not fully closed")
            _positive_exact_int(row.get("position_id"), f"{label} position_id")
            entry_ids = _positive_deal_ids(row.get("entry_deal_ids"), f"{label} entry_deal_ids")
            exit_ids = _positive_deal_ids(row.get("exit_deal_ids"), f"{label} exit_deal_ids")
            if set(entry_ids) & set(exit_ids):
                raise ValueError(f"{label} entry/exit deal IDs overlap")
            events = row.get("balance_events")
            if not isinstance(events, list) or not events:
                raise ValueError(f"{label} balance_events must be a non-empty array")
        else:
            raise ValueError(f"unknown comparison role: {role}")
        values = {
            key: _number(row.get(key), f"{label} {key}")
            for key in (
                "profit",
                "swap",
                "commission",
                "entry_commission",
                "exit_commission",
                "net",
            )
        }
        if "fee" not in row:
            raise ValueError(f"{label} fee is missing")
        fee = _number(row["fee"], f"{label} fee")
        if abs(fee) > money_tol:
            raise ValueError(f"{label} non-zero fee is unsupported")
        if abs(values["commission"] - values["entry_commission"] - values["exit_commission"]) > money_tol:
            raise ValueError(f"{label} commission components do not reconcile")
        if abs(values["net"] - values["profit"] - values["swap"] - values["commission"] - fee) > money_tol:
            raise ValueError(f"{label} full-lifecycle net does not reconcile")
        row.update(values)
        row["fee"] = fee
        row["side"] = side
        row["entry_price"] = entry_price
        row["exit_price"] = exit_price
        if role == "joint":
            exact_fields = {"deal_id", "time", "component", "amount"}
            allowed_components = {"PROFIT", "SWAP", "COMMISSION", "FEE"}
            entry_id_set = set(entry_ids)
            exit_id_set = set(exit_ids)
            seen: set[tuple[int, str]] = set()
            event_time_by_deal: dict[int, int] = {}
            amounts: dict[tuple[str, str], float] = {}
            for event_index, event in enumerate(events):
                event_label = f"{label} balance_events[{event_index}]"
                if not isinstance(event, dict):
                    raise ValueError(f"{event_label} must be an object")
                if set(event) != exact_fields:
                    raise ValueError(f"{event_label} fields mismatch")
                deal_id = _positive_exact_int(event["deal_id"], f"{event_label} deal_id")
                event_time = _positive_exact_int(event["time"], f"{event_label} time")
                component = event["component"]
                if not isinstance(component, str) or component not in allowed_components:
                    raise ValueError(f"{event_label} component invalid")
                if isinstance(event["amount"], bool) or not isinstance(
                    event["amount"], (int, float)
                ):
                    raise ValueError(f"{event_label} amount must be a JSON number")
                amount = _number(event["amount"], f"{event_label} amount")
                identity = (deal_id, component)
                if identity in seen:
                    raise ValueError(f"{event_label} duplicates deal/component")
                seen.add(identity)
                previous_time = event_time_by_deal.setdefault(deal_id, event_time)
                if previous_time != event_time:
                    raise ValueError(
                        f"{event_label} deal components have inconsistent times"
                    )
                if deal_id in entry_id_set:
                    if component != "COMMISSION":
                        raise ValueError(f"{event_label} entry component invalid")
                    if not entry_time <= event_time <= close_time:
                        raise ValueError(f"{event_label} entry event time outside lifecycle")
                    bucket = ("entry", component)
                else:
                    if deal_id not in exit_id_set:
                        raise ValueError(f"{event_label} deal_id is outside declared lineage")
                    if not entry_time <= event_time <= close_time:
                        raise ValueError(f"{event_label} exit event time outside lifecycle")
                    bucket = ("exit", component)
                amounts[bucket] = amounts.get(bucket, 0.0) + amount

            for deal_id in entry_ids:
                if (deal_id, "COMMISSION") not in seen:
                    raise ValueError(f"{label} entry deal {deal_id} lacks COMMISSION event")
            for deal_id in exit_ids:
                for component in allowed_components:
                    if (deal_id, component) not in seen:
                        raise ValueError(f"{label} exit deal {deal_id} lacks {component} event")
            entry_event_times = [event_time_by_deal[deal_id] for deal_id in entry_ids]
            exit_event_times = [event_time_by_deal[deal_id] for deal_id in exit_ids]
            if entry_event_times != sorted(entry_event_times):
                raise ValueError(f"{label} entry deal/event ordering is not monotonic")
            if exit_event_times != sorted(exit_event_times):
                raise ValueError(f"{label} exit deal/event ordering is not monotonic")
            if entry_event_times[0] != entry_time:
                raise ValueError(f"{label} first entry deal does not establish entry_time")
            if exit_event_times[-1] != close_time:
                raise ValueError(f"{label} final exit deal does not establish close time")
            expected = {
                ("entry", "COMMISSION"): values["entry_commission"],
                ("exit", "PROFIT"): values["profit"],
                ("exit", "SWAP"): values["swap"],
                ("exit", "COMMISSION"): values["exit_commission"],
                ("exit", "FEE"): fee,
            }
            if set(amounts) != set(expected):
                raise ValueError(f"{label} balance-event components mismatch")
            for bucket, declared in expected.items():
                if not math.isclose(amounts[bucket], declared, rel_tol=0.0, abs_tol=1e-9):
                    raise ValueError(
                        f"{label} balance-event {bucket[0]} {bucket[1]} does not reconcile"
                    )
        validated.append(row)
    return validated


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


def trade_components_match(left: dict, right: dict, money_tol: float) -> bool:
    return (
        left["side"] == right["side"]
        and abs(float(left["entry_price"]) - float(right["entry_price"]))
        <= GOVERNED_PRICE_TOLERANCE
        and abs(float(left["exit_price"]) - float(right["exit_price"]))
        <= GOVERNED_PRICE_TOLERANCE
        and all(
        abs(float(left[field]) - float(right[field])) <= money_tol
        for field in MONEY_COMPONENT_KEYS
        )
    )


def classify(joint: list[dict], gated: list[dict], money_tol: float, vol_tol: float) -> dict:
    """Pair deterministically and classify every non-exact trade."""
    money_tol = _governed_tolerance(
        money_tol, label="money tolerance", maximum=GOVERNED_MONEY_TOLERANCE
    )
    vol_tol = _governed_tolerance(
        vol_tol, label="volume tolerance", maximum=GOVERNED_VOLUME_TOLERANCE
    )
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
                      and trade_components_match(row, g, money_tol)
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
    ap.add_argument(
        "--expected-joint-run-id",
        required=True,
        type=governed_run_id,
        help="exact governed V2 rung identity expected in every joint row",
    )
    ap.add_argument("--joint-magic", type=positive_magic,
                    help="select this exact magic from the joint stream")
    ap.add_argument("--gated-magic", type=positive_magic,
                    help="select this exact magic from the gated stream")
    ap.add_argument("--joint-symbol",
                    help="optionally select this exact symbol from the joint stream")
    ap.add_argument("--gated-symbol",
                    help="optionally select this exact symbol from the gated stream")
    ap.add_argument(
        "--money-tol",
        type=governed_tolerance_arg(
            label="money tolerance", maximum=GOVERNED_MONEY_TOLERANCE
        ),
        default=GOVERNED_MONEY_TOLERANCE,
        help="absolute tolerance for every money component; governed maximum 0.005 USD",
    )
    ap.add_argument(
        "--vol-tol",
        type=governed_tolerance_arg(
            label="volume tolerance", maximum=GOVERNED_VOLUME_TOLERANCE
        ),
        default=GOVERNED_VOLUME_TOLERANCE,
        help="absolute volume tolerance; governed maximum 0.005 lots",
    )
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
    try:
        joint = validate_full_lifecycle_rows(
            joint,
            role="joint",
            money_tol=args.money_tol,
            expected_run_id=args.expected_joint_run_id,
        )
        gated = validate_full_lifecycle_rows(
            gated, role="standalone", money_tol=args.money_tol
        )
    except ValueError as exc:
        print(json.dumps({
            "valid": False,
            "reason": "full_lifecycle_money_contract_invalid",
            "detail": str(exc),
            "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
        }, indent=2))
        return 2

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
                if (trade_components_match(o, g, args.money_tol) and
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
        "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
        "mismatch_categories": categories,
        "filters": {
            "expected_joint_run_id": args.expected_joint_run_id,
            "joint_magic": args.joint_magic,
            "gated_magic": args.gated_magic,
            "joint_symbol": args.joint_symbol,
            "gated_symbol": args.gated_symbol,
            "money_tolerance": args.money_tol,
            "volume_tolerance": args.vol_tol,
            "price_tolerance": GOVERNED_PRICE_TOLERANCE,
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
