from __future__ import annotations

import csv
import importlib.util
import re
from pathlib import Path

import pytest


SCRIPT = Path(__file__).resolve().parents[1] / "update_magic_resolver.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("update_magic_resolver_binary_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _function_body(source: str, function: str) -> str:
    match = re.search(rf"\b{function}\s*\([^)]*\)\s*\{{", source, re.S)
    assert match, function
    start = match.end() - 1
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
    raise AssertionError(function)


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


def _checked_outcome_at_index(
    rows: list[dict], ea_id: int, slot: int, expected_symbol: str, index: int
) -> tuple[str, int]:
    magic = ea_id * 10_000 + slot
    if index < 0 or rows[index]["magic"] != magic:
        return "EA_MAGIC_NOT_REGISTERED", -1
    registered_symbol = rows[index]["symbol"]
    if expected_symbol and registered_symbol and registered_symbol != expected_symbol:
        return "EA_MAGIC_RESOLUTION_FAILED", -1
    return "OK", magic


def _unregistered_sample(rows: list[dict]) -> list[tuple[int, int]]:
    registered = {(row["ea_id"], row["slot"]) for row in rows}
    candidates = [
        (999, 0),
        (1000, 9999),
        (99999, 0),
        (99999, 9999),
    ]
    stride = max(1, len(rows) // 128)
    for row in rows[::stride]:
        candidates.append((row["ea_id"], 9999))
        candidates.append((row["ea_id"], (row["slot"] + 5000) % 10000))
    return list(dict.fromkeys(pair for pair in candidates if pair not in registered))


def test_binary_lookup_is_equivalent_over_every_generated_row_and_misses() -> None:
    module = _load_module()
    rows, dropped = module.load_rows(keep_obsolete=False)

    assert rows
    assert dropped == []
    module.validate_row_order(rows)
    # A single pass records the first index that the old linear scan returned
    # for every pair. Strict uniqueness means this captures its whole-row
    # domain exactly without making the test itself quadratic.
    linear_first_index: dict[tuple[int, int], int] = {}
    for index, row in enumerate(rows):
        linear_first_index.setdefault((row["ea_id"], row["slot"]), index)
    assert len(linear_first_index) == len(rows)

    for expected_index, row in enumerate(rows):
        pair = (row["ea_id"], row["slot"])
        linear_index = linear_first_index[pair]
        assert linear_index == expected_index
        assert _binary_find(rows, *pair) == expected_index
        binary_index = _binary_find(rows, *pair)
        assert _checked_outcome_at_index(
            rows, *pair, row["symbol"], linear_index
        ) == _checked_outcome_at_index(rows, *pair, row["symbol"], binary_index)
        assert _checked_outcome_at_index(
            rows, *pair, "INTENTIONAL.MISMATCH", linear_index
        ) == _checked_outcome_at_index(
            rows, *pair, "INTENTIONAL.MISMATCH", binary_index
        )

    misses = _unregistered_sample(rows)
    assert len(misses) >= 128
    for pair in misses:
        linear_index = linear_first_index.get(pair, -1)
        assert linear_index == -1
        assert _binary_find(rows, *pair) == -1
        assert _checked_outcome_at_index(
            rows, *pair, "UNREGISTERED.DWX", linear_index
        ) == _checked_outcome_at_index(rows, *pair, "UNREGISTERED.DWX", -1)


def test_regeneration_sorts_unsorted_csv_by_strict_composite_key(
    tmp_path: Path, monkeypatch
) -> None:
    module = _load_module()
    registry = tmp_path / "magic_numbers.csv"
    with registry.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(["ea_id", "symbol_slot", "symbol", "magic", "status"])
        writer.writerow([1002, 3, "USDJPY.DWX", 10020003, "active"])
        writer.writerow([1001, 9, "GBPUSD.DWX", 10010009, "active"])
        writer.writerow([1001, 0, "EURUSD.DWX", 10010000, "active"])

    monkeypatch.setattr(module, "REGISTRY_CSV", registry)
    monkeypatch.setattr(module, "active_ea_ids", lambda **_: {1001, 1002})

    rows, dropped = module.load_rows(keep_obsolete=False)
    keys = [module.row_composite_key(row) for row in rows]
    assert dropped == []
    assert keys == [10010000, 10010009, 10020003]
    assert keys == sorted(set(keys))
    assert module.render_mqh(rows) == module.render_mqh(rows)


def test_renderer_rejects_unsorted_or_duplicate_composite_keys() -> None:
    module = _load_module()
    rows = [
        {"ea_id": 1002, "slot": 0, "symbol": "GBPUSD.DWX", "magic": 10020000},
        {"ea_id": 1001, "slot": 0, "symbol": "EURUSD.DWX", "magic": 10010000},
    ]
    with pytest.raises(ValueError, match="strictly increasing"):
        module.render_mqh(rows)

    with pytest.raises(ValueError, match="strictly increasing"):
        module.render_mqh([rows[1], rows[1]])


def test_generated_checked_path_uses_one_index_lookup_for_both_guards() -> None:
    module = _load_module()
    rows = [
        {"ea_id": 1001, "slot": 0, "symbol": "EURUSD.DWX", "magic": 10010000},
        {"ea_id": 1002, "slot": 0, "symbol": "GBPUSD.DWX", "magic": 10020000},
    ]
    rendered = module.render_mqh(rows)
    find_body = _function_body(rendered, "QM_MagicRegistryFindIndex")
    checked_body = _function_body(rendered, "QM_MagicChecked")

    assert "while(low <= high)" in find_body
    assert "middle_key == target_key" in find_body
    assert checked_body.count("QM_MagicRegistryFindIndex(") == 1
    assert "QM_MagicRegistered(" not in checked_body
    assert "QM_MagicRegisteredSymbol(" not in checked_body
    assert "QM_MAGIC_REG_MAGIC[registry_index] != magic" in checked_body
    assert "QM_MAGIC_REG_SYMBOL[registry_index]" in checked_body
    assert "EA_MAGIC_NOT_REGISTERED" in checked_body
    assert "EA_MAGIC_RESOLUTION_FAILED" in checked_body
