#!/usr/bin/env python3
"""Measure the generated magic resolver's old and indexed lookup shapes.

This is a deterministic Python mirror of the registry-only portion of
QM_MagicChecked. It intentionally excludes open-position collision scanning,
which is unchanged by the indexed resolver.
"""

from __future__ import annotations

import argparse
import json
import statistics
import time

import update_magic_resolver as resolver


def _linear_checked(rows: list[dict], query: tuple[int, int, str]) -> int:
    ea_id, slot, expected_symbol = query
    magic = ea_id * 10_000 + slot

    registered = False
    for row in rows:
        if row["ea_id"] == ea_id and row["slot"] == slot:
            registered = row["magic"] == magic
            break
    if not registered:
        return -1

    registered_symbol = ""
    for row in rows:
        if row["ea_id"] == ea_id and row["slot"] == slot:
            registered_symbol = row["symbol"]
            break
    if expected_symbol and registered_symbol and registered_symbol != expected_symbol:
        return -1
    return magic


def _binary_find(rows: list[dict], ea_id: int, slot: int) -> int:
    target = ea_id * 10_000 + slot
    low = 0
    high = len(rows) - 1
    while low <= high:
        middle = low + (high - low) // 2
        row = rows[middle]
        middle_key = row["ea_id"] * 10_000 + row["slot"]
        if middle_key == target:
            return middle
        if middle_key < target:
            low = middle + 1
        else:
            high = middle - 1
    return -1


def _indexed_checked(rows: list[dict], query: tuple[int, int, str]) -> int:
    ea_id, slot, expected_symbol = query
    magic = ea_id * 10_000 + slot
    index = _binary_find(rows, ea_id, slot)
    if index < 0 or rows[index]["magic"] != magic:
        return -1
    registered_symbol = rows[index]["symbol"]
    if expected_symbol and registered_symbol and registered_symbol != expected_symbol:
        return -1
    return magic


def _queries(rows: list[dict], calls: int) -> list[tuple[int, int, str]]:
    registered_ids = {row["ea_id"] for row in rows}
    missing_ea_id = next(ea_id for ea_id in range(99_999, 999, -1) if ea_id not in registered_ids)
    result: list[tuple[int, int, str]] = []
    for index in range(calls):
        if index % 5:
            row = rows[(index * 7_919) % len(rows)]
            result.append((row["ea_id"], row["slot"], row["symbol"]))
        else:
            result.append((missing_ea_id, index % 10_000, "UNREGISTERED.DWX"))
    return result


def _measure(function, rows: list[dict], queries: list[tuple[int, int, str]]) -> int:
    checksum = 0
    started = time.perf_counter_ns()
    for query in queries:
        checksum ^= function(rows, query)
    elapsed = time.perf_counter_ns() - started
    # Keep the loop result observable and make accidental algorithm drift fail.
    if checksum == -2_147_483_648:
        raise AssertionError("unreachable benchmark checksum")
    return elapsed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--calls", type=int, default=2_000)
    parser.add_argument("--repeats", type=int, default=3)
    args = parser.parse_args()
    if args.calls <= 0 or args.repeats <= 0:
        parser.error("--calls and --repeats must be positive")

    rows, dropped = resolver.load_rows(keep_obsolete=False)
    if dropped:
        raise SystemExit(f"refusing benchmark with dropped EA IDs: {dropped}")
    queries = _queries(rows, args.calls)
    expected = [_linear_checked(rows, query) for query in queries]
    actual = [_indexed_checked(rows, query) for query in queries]
    if actual != expected:
        raise AssertionError("indexed lookup is not equivalent to the linear reference")

    linear_samples = [
        _measure(_linear_checked, rows, queries) for _ in range(args.repeats)
    ]
    indexed_samples = [
        _measure(_indexed_checked, rows, queries) for _ in range(args.repeats)
    ]
    linear_median = statistics.median(linear_samples)
    indexed_median = statistics.median(indexed_samples)
    result = {
        "schema": "qm.magic-resolver-lookup-benchmark/v1",
        "registry_rows": len(rows),
        "registry_sha256": resolver.csv_sha256_upper(),
        "calls_per_repeat": args.calls,
        "repeats": args.repeats,
        "registered_call_fraction": 0.8,
        "linear_double_scan": {
            "median_total_ns": linear_median,
            "median_ns_per_call": linear_median / args.calls,
            "samples_ns": linear_samples,
        },
        "binary_single_lookup": {
            "median_total_ns": indexed_median,
            "median_ns_per_call": indexed_median / args.calls,
            "samples_ns": indexed_samples,
        },
        "speedup_ratio": linear_median / indexed_median,
        "equivalent_outputs": True,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
