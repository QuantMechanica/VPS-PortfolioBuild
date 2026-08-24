from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_1612_aa-dsp-hplwma10"
SOURCE = EA_DIR / "QM5_1612_aa-dsp-hplwma10.mq5"
SPEC = EA_DIR / "SPEC.md"
BUILD_IDENTITY = EA_DIR / "build_identity.json"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("GDAXI.DWX", 16120000),
    1: ("NDX.DWX", 16120001),
    2: ("SP500.DWX", 16120002),
    3: ("UK100.DWX", 16120003),
    4: ("WS30.DWX", 16120004),
    5: ("XAUUSD.DWX", 16120005),
    6: ("EURUSD.DWX", 16120006),
    7: ("GBPUSD.DWX", 16120007),
    8: ("USDJPY.DWX", 16120008),
    9: ("USDCHF.DWX", 16120009),
    10: ("AUDUSD.DWX", 16120010),
    11: ("USDCAD.DWX", 16120011),
    12: ("NZDUSD.DWX", 16120012),
    13: ("XTIUSD.DWX", 16120013),
}


def _function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_card_faithful_spread_guard_is_dynamic_bounded_and_fail_closed() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    spread = _function_body(source, "bool Strategy_SpreadAllowsEntry()")
    entry = _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")

    assert "strategy_spread_median_days = 20" in source
    assert "strategy_spread_median_mult = 2.5" in source
    assert "strategy_max_spread_points" not in source
    assert "CopySpread(_Symbol" in spread
    assert "// perf-allowed:" in spread
    assert "ArraySize(spreads) < strategy_spread_median_days" in spread
    assert "ArraySort(spreads);" in spread
    assert "strategy_spread_median_mult * median_spread" in spread
    assert "if(!Strategy_SpreadAllowsEntry())" in entry


def test_all_declared_strategy_inputs_have_executable_use_sites() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    strategy_block = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------", 1
    )[0]
    names = re.findall(r"(?m)^input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", strategy_block)

    assert names == [
        "strategy_min_daily_bars",
        "strategy_atr_period",
        "strategy_atr_sl_mult",
        "strategy_spread_median_days",
        "strategy_spread_median_mult",
    ]
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name


def test_exit_is_d1_new_bar_gated_while_management_stays_tick_responsive() -> None:
    on_tick = _function_body(SOURCE.read_text(encoding="utf-8"), "void OnTick()")

    manage = on_tick.index("Strategy_ManageOpenPosition();")
    new_bar = on_tick.index("QM_IsNewBar(_Symbol, PERIOD_D1)")
    exit_signal = on_tick.index("Strategy_ExitSignal()")
    news = on_tick.index("QM_NewsAllowsTrade2(")
    entry = on_tick.index("Strategy_EntrySignal(req)")

    assert manage < new_bar < exit_signal < news < entry
    assert on_tick.count("QM_IsNewBar(_Symbol, PERIOD_D1)") == 1
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert "ZeroMemory(req);" in on_tick


def test_registry_and_setfiles_cover_the_repaired_oil_alias() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "1612" and row["status"].lower() == "active"
        ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"])) for row in rows
    }
    assert actual == EXPECTED_SLOTS

    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    assert len(list(SETS.glob("*.set"))) == len(EXPECTED_SLOTS)
    for slot, (symbol, _) in EXPECTED_SLOTS.items():
        path = SETS / f"QM5_1612_aa-dsp-hplwma10_{symbol}_D1_backtest.set"
        values = _set_values(path)
        text = path.read_text(encoding="utf-8-sig")
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["strategy_spread_median_days"] == "20"
        assert values["strategy_spread_median_mult"] == "2.5"


def test_spec_is_clean_and_bound_to_the_approved_card() -> None:
    spec = SPEC.read_text(encoding="utf-8")

    assert not any(ord(char) < 32 and char not in "\n\r\t" for char in spec)
    assert "**Slug:** aa-dsp-hplwma10" in spec
    assert "**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7" in spec
    assert "$1,000 per trade" in spec
    assert "USOIL.DWX" in spec
    assert "XTIUSD.DWX" in spec


def test_build_identity_uses_the_canonical_build_result_schema() -> None:
    result = json.loads(BUILD_IDENTITY.read_text(encoding="utf-8"))

    required = {
        "task_id",
        "ea_id",
        "ea_dir",
        "mq5_path",
        "ex5_path",
        "magic_base",
        "symbols_registered",
        "setfiles_generated",
        "spec_md_path",
        "build_check_passed",
        "compile_succeeded",
        "smoke_result",
        "smoke_report_path",
    }
    assert required <= result.keys()
    assert result["task_id"] == "690cd9ab-da44-4dd5-8cb2-0212384dc3db"
    assert result["ea_id"] == "QM5_1612"
    assert result["magic_base"] == 16120000
    assert result["symbols_registered"] == [
        symbol for _, (symbol, _) in sorted(EXPECTED_SLOTS.items())
    ]
    assert result["mq5_sha256"] == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    assert len(result["setfiles_generated"]) == len(EXPECTED_SLOTS)
