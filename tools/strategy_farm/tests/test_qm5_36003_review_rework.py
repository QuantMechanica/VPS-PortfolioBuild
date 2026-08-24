from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_36003_nnfx-hull-ma-zerolag-macd-stc"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"


def source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def code_without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


def function_body(code: str, start: str, end: str) -> str:
    return code.split(start, 1)[1].split(end, 1)[0]


def declared_inputs(code: str) -> dict[str, str]:
    return dict(
        re.findall(
            r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_]*\s+"
            r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);",
            code,
        )
    )


def test_card_mechanism_and_original_review_findings_are_locked_closed() -> None:
    text = source()
    code = code_without_comments(text)
    entry = function_body(code, "bool Strategy_EntrySignal(", "void Strategy_ManageOpenPosition")
    manage = function_body(code, "void Strategy_ManageOpenPosition", "bool Strategy_ExitSignal")
    exit_signal = function_body(code, "bool Strategy_ExitSignal", "bool Strategy_NewsFilterHook")
    no_trade = function_body(code, "bool Strategy_NoTradeFilter", "bool Strategy_EntrySignal")
    on_tick = function_body(code, "void OnTick", "void OnTimer")

    # ZeroLag MACD is a true EMA-of-adjusted-price construction, including an
    # EMA signal line; the rejected single-bar update and simple mean stay gone.
    assert "close_i + (close_i - zl_fast_first)" in entry
    assert "close_i + (close_i - zl_slow_first)" in entry
    assert "zl_signal_alpha * zl_macd[i]" in entry
    assert "close_i + (close_i - fast_first)" in exit_signal
    assert "close_i + (close_i - slow_first)" in exit_signal

    # BetterVol HIGH means current closed-bar volume exceeds the following
    # prior-bar mean, without the rejected invented 1.02 multiplier.
    assert "for(int k = 1; k <= strategy_better_volume_lookback; ++k)" in entry
    assert "rates[latest - k].tick_volume" in entry
    assert "rates[latest].tick_volume > prior_volume_average" in entry
    assert "1.02" not in entry

    # No broker TP can consume the runner. TP1 is a partial close, protection
    # moves to BE, and only the opposing ZeroLag crossover exits the remainder.
    assert re.search(r"req\.tp\s*=\s*0\.0", entry)
    assert "volume * strategy_tp1_fraction" in manage
    assert "QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL)" in manage
    assert "QM_TM_MoveSL" in manage
    assert "crossed_down" in exit_signal
    assert "crossed_up" in exit_signal

    # GMT and all three card loss contracts are executable. Existing-position
    # bypass occurs before entry-only rollover/spread/loss filters.
    assert no_trade.index("QM_TM_OpenPositionCount(magic) > 0") < no_trade.index(
        "QM_BrokerToUTC(TimeCurrent())"
    )
    assert "strategy_daily_loss_halt_pct" in no_trade
    assert re.search(
        r"QM_KillSwitchInit\s*\(\s*qm_ea_id\s*,\s*QM_FrameworkMagic\(\)\s*,\s*"
        r"strategy_daily_hard_stop_pct\s*,\s*strategy_total_dd_stop_pct",
        no_trade,
    )

    # MAE and exits remain reachable; the central news policy gates new entries
    # only, after management and the runner exit.
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_ExitSignal()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )


def test_framework_risk_buffer_and_raw_series_contracts() -> None:
    text = source()
    code = code_without_comments(text)

    assert "#include <QM/QM_Common.mqh>" in text
    assert re.search(r"input\s+double\s+RISK_PERCENT\s*=\s*0\.0\s*;", code)
    assert re.search(r"input\s+double\s+RISK_FIXED\s*=\s*1000\.0\s*;", code)
    assert "QM_FrameworkMagic()" in code
    assert "QM_FrameworkTrackOpenPositionMae();" in code
    assert "ArraySize(min_queue)" in code
    assert "latest >= ArraySize(zl_macd)" in code
    assert "previous >= ArraySize(zl_signal)" in code
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", code, re.I)
    assert not re.search(r"\bi(?:Close|Open|High|Low|Time|TickVolume)\s*\(", code)

    copy_rates_lines = [line for line in text.splitlines() if "CopyRates(" in line]
    assert len(copy_rates_lines) == 2
    assert all("perf-allowed" in line for line in copy_rates_lines)

    report = build_gate_hardening.analyze(REPO_ROOT, EA_LABEL)
    assert report["files_scanned"] == 1
    assert report["failures"] == []
    assert report["warnings"] == []


def test_every_declared_input_is_used_and_every_strategy_input_is_in_each_set() -> None:
    code = code_without_comments(source())
    inputs = declared_inputs(code)
    assert inputs
    unused = [
        name
        for name in inputs
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ]
    assert unused == []

    strategy_inputs = {name for name in inputs if name.startswith("strategy_")}
    setfiles = sorted((EA_DIR / "sets").glob(f"{EA_LABEL}_*_D1_backtest.set"))
    assert len(setfiles) == 3
    expected_slots = {
        "EURUSD.DWX": "0",
        "GBPUSD.DWX": "1",
        "XAUUSD.DWX": "2",
    }
    for setfile in setfiles:
        values = {
            key.strip(): value.strip()
            for line in setfile.read_text(encoding="utf-8-sig").splitlines()
            if line and not line.startswith(";") and "=" in line
            for key, value in [line.split("=", 1)]
        }
        symbol = next(name for name in expected_slots if name in setfile.name)
        assert values["qm_ea_id"] == "36003"
        assert values["qm_magic_slot_offset"] == expected_slots[symbol]
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert {name for name in values if name.startswith("strategy_")} == strategy_inputs


def test_magic_registry_rows_are_existing_active_allocations() -> None:
    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "36003" and row["status"] == "active"
        ]

    assert [
        (row["symbol_slot"], row["symbol"], row["magic"])
        for row in rows
    ] == [
        ("0", "EURUSD.DWX", "360030000"),
        ("1", "GBPUSD.DWX", "360030001"),
        ("2", "XAUUSD.DWX", "360030002"),
    ]
