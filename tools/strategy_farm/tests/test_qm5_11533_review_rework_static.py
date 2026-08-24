from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21"
EA_DIR = REPO / "framework" / "EAs" / EA_LABEL
SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SETFILE = EA_DIR / "sets" / f"{EA_LABEL}_EURUSD.DWX_H1_backtest.set"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"


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
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_spread_guard_is_entry_only_and_exit_remains_reachable() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    entry = _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")
    on_tick = _function_body(source, "void OnTick()")

    assert "if(!Strategy_SpreadAllowsEntry())" in entry
    assert "Strategy_SpreadAllowsEntry" not in on_tick
    assert "Strategy_NoTradeFilter" not in source
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_ExitSignal()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "QM_NewsAllowsTrade"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_EntrySignal(req)"
    )


def test_h1_and_friday_execution_contract_is_fail_closed() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    on_init = _function_body(source, "int OnInit()")
    on_tick = _function_body(source, "void OnTick()")

    assert "input bool   qm_friday_close_enabled    = false;" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H1," in on_init
    assert "QM_FRIDAY_CLOSE_DISABLED" in on_init
    assert '"CARD_NO_FRIDAY_ENTRY_ONLY"' in on_init
    assert "if(!QM_IsNewBar(_Symbol, PERIOD_H1)) return;" in on_tick
    assert "TimeToStruct(TimeCurrent(), dt);" in source
    assert "dt.day_of_week == 5" in source


def test_medium_cross_uses_closed_bars_one_and_two_for_both_fast_emas() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    long_signal = _function_body(source, "bool RibbonLongSignal()")
    short_signal = _function_body(source, "bool RibbonShortSignal()")

    for fast in ("ema3", "ema5"):
        for medium in ("ema13", "ema21"):
            assert (
                f"({fast}_2 <= {medium}_2) && ({fast}_1 > {medium}_1)"
                in long_signal
            )
            assert (
                f"({fast}_2 >= {medium}_2) && ({fast}_1 < {medium}_1)"
                in short_signal
            )
    assert "cross_up && medium_cross_up && structural" in long_signal
    assert "cross_dn && medium_cross_dn && structural" in short_signal


def test_all_strategy_inputs_are_wired_and_indicators_use_framework_wrappers() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    strategy_block = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------", 1
    )[0]
    names = re.findall(r"(?m)^input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", strategy_block)

    assert names == [
        "strategy_ema_fast",
        "strategy_ema_signal",
        "strategy_ema_medium1",
        "strategy_ema_medium2",
        "strategy_ema_baseline",
        "strategy_rsi_period",
        "strategy_rsi_threshold",
        "strategy_sl_pips",
        "strategy_max_spread_pips",
    ]
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_EMA(" in source and "QM_RSI(" in source
    assert not re.search(r"(?<!QM_)\bi(?:MA|RSI)\s*\(", source)
    assert not re.search(r"\b(?:CopyBuffer|CopyRates|CopyClose|CopyOpen)\s*\(", source)
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)


def test_magic_and_backtest_set_are_bound_to_the_repaired_source() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "11533" and row["status"].lower() == "active"
        ]
    assert len(rows) == 1
    assert rows[0]["symbol_slot"] == "0"
    assert rows[0]["symbol"] == "EURUSD.DWX"
    assert rows[0]["magic"] == "115330000"

    source = SOURCE.read_text(encoding="utf-8")
    assert "QM_FrameworkMagic()" in source
    assert "req.symbol_slot = qm_magic_slot_offset;" in source
    values = _set_values(SETFILE)
    set_text = SETFILE.read_text(encoding="utf-8-sig")
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    assert f"; build_hash:   {source_hash}" in set_text
    assert values["qm_ea_id"] == "11533"
    assert values["qm_magic_slot_offset"] == "0"
    assert values["RISK_FIXED"] == "1000"
    assert values["RISK_PERCENT"] == "0"
    assert values["qm_friday_close_enabled"] == "false"
    assert values["qm_friday_close_hour_broker"] == "21"
