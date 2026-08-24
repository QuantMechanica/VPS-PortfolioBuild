from __future__ import annotations

import math
import re
from pathlib import Path

import pytest

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_1671_ehlers-ebsw-cycle-extract-composite-h4"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
CARD = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_1671_ehlers-ebsw-cycle-extract-composite-h4.md"
)


def source_text() -> str:
    return EA_SOURCE.read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source)
    assert match, f"missing function {name}"
    start = match.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise AssertionError(f"unterminated function {name}")


def ehlers_hilbert_4tap(values: list[float], shift: int = 0) -> float:
    return (
        0.0962 * values[shift]
        + 0.5769 * values[shift + 2]
        - 0.5769 * values[shift + 4]
        - 0.0962 * values[shift + 6]
    )


def test_fixed_four_tap_hilbert_matches_deterministic_reference_vectors() -> None:
    source = source_text()
    hilbert = function_body(source, "EhlersHilbert4Tap")

    assert "ArraySize(signal)" in hilbert
    assert "shift + 6 >= size" in hilbert
    for tap in (
        "0.0962 * signal[shift]",
        "+ 0.5769 * signal[shift + 2]",
        "- 0.5769 * signal[shift + 4]",
        "- 0.0962 * signal[shift + 6]",
    ):
        assert tap in hilbert
    assert "(filt[0] - filt[4]) / 4.0" not in source
    assert "EhlersHilbert4Tap(filt, 0, quad0)" in source
    assert "EhlersHilbert4Tap(ebsw_filt, 0, quad_ebsw0)" in source

    assert ehlers_hilbert_4tap([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) == pytest.approx(0.0962)
    assert ehlers_hilbert_4tap([1.0] * 7) == pytest.approx(0.0, abs=1e-15)

    vector = [1.0, 0.75, 0.25, -0.5, -1.0, -0.75, -0.25, 0.5]
    quadrature_now = ehlers_hilbert_4tap(vector, 0)
    quadrature_prev = ehlers_hilbert_4tap(vector, 1)
    amplitude = math.hypot(vector[3], quadrature_now)
    phase_now = math.atan2(quadrature_now, vector[3])
    phase_prev = math.atan2(quadrature_prev, vector[4])
    delta_phase = phase_prev - phase_now
    if delta_phase <= 0.0:
        delta_phase += 2.0 * math.pi
    period = 2.0 * math.pi / delta_phase

    assert quadrature_now == pytest.approx(0.841375)
    assert quadrature_prev == pytest.approx(0.168275)
    assert amplitude == pytest.approx(0.9787297331873596)
    assert phase_now == pytest.approx(2.1069884948928763)
    assert period == pytest.approx(7.239601656163714)


def test_raw_period_is_the_admission_value_and_invalid_observations_stay_invalid() -> None:
    source = source_text()
    advance = function_body(source, "AdvanceCycleState")
    entry = function_body(source, "Strategy_EntrySignal")

    assert "g_cycle_period_raw = 0.0;" in advance
    assert "g_cycle_period_valid = false;" in advance
    assert "g_cycle_period_valid = (raw_period >= (double)strategy_period_min" in advance
    assert "g_cycle_period_display = strategy_period_min;" in advance
    assert "g_cycle_period_display = strategy_period_max;" in advance
    assert "g_cycle_period_valid &&" in entry
    assert "g_cycle_period_raw >= (double)strategy_period_min" in entry
    assert "g_cycle_period_raw <= (double)strategy_period_max" in entry
    assert "double raw_period = 20.0" not in source
    assert "g_cycle_period >= strategy_period_min" not in source


def test_entry_period_and_cooldown_are_accepted_trade_provenance() -> None:
    source = source_text()
    entry = function_body(source, "Strategy_EntrySignal")
    exit_signal = function_body(source, "Strategy_ExitSignal")
    position_period = function_body(source, "Strategy_PositionEntryPeriod")
    cooldown = function_body(source, "Strategy_InDirectionCooldown")
    on_tick = function_body(source, "OnTick")

    assert 'StringFormat("EBSW:P=%d|D=%s"' in source
    assert "POSITION_COMMENT" in position_period
    assert "POSITION_IDENTIFIER" in position_period
    assert "HistorySelectByPosition" in position_period
    assert "DEAL_COMMENT" in position_period
    assert "const int entry_period = Strategy_PositionEntryPeriod(ticket);" in exit_signal
    assert "strategy_time_stop_mult * entry_period" in exit_signal
    assert "g_cycle_period_raw" not in exit_signal
    assert "g_cycle_period_display" not in exit_signal

    assert "HistorySelect(since, now)" in cooldown
    assert "DEAL_ENTRY_IN" in cooldown
    assert "DEAL_MAGIC" in cooldown
    assert "Strategy_ParseEntryPeriod" in cooldown
    assert "g_last_trade_time" not in source
    assert "g_last_trade_dir" not in source
    assert "QM_TM_OpenPosition(req, out_ticket)" in on_tick
    assert "if(QM_TM_OpenPosition(req, out_ticket))" in on_tick
    assert "Strategy_InDirectionCooldown(1)" in entry
    assert "Strategy_InDirectionCooldown(-1)" in entry


def test_news_is_entry_only_and_h4_clock_is_explicit() -> None:
    source = source_text()
    on_init = function_body(source, "OnInit")
    on_tick = function_body(source, "OnTick")

    news_index = on_tick.index("QM_NewsAllowsTrade2")
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae()") < news_index
    assert on_tick.index("QM_FrameworkHandleFridayClose()") < news_index
    assert on_tick.index("AdvanceCycleState()") < news_index
    assert on_tick.index("Strategy_ManageOpenPosition()") < news_index
    assert on_tick.index("Strategy_ExitSignal()") < news_index
    assert on_tick.index("QM_IsNewBar(_Symbol, PERIOD_H4)") < news_index
    assert on_tick.index("Strategy_NoTradeFilter()") > news_index
    assert "if(_Period != PERIOD_H4)" in on_init
    assert "return INIT_PARAMETERS_INCORRECT;" in on_init


def test_series_reads_are_bounded_and_explicitly_perf_allowed() -> None:
    source = source_text()
    assert "if(ArraySize(close) < count)" in source
    raw_calls = re.findall(
        r"^.*\b(?:iOpen|iHigh|iLow|iClose|iTime|iBarShift|CopyClose|Bars)\s*\(.*$",
        source,
        flags=re.MULTILINE,
    )
    assert raw_calls
    assert all("perf-allowed:" in line for line in raw_calls)


def test_framework_inputs_setfiles_and_hardening_remain_conformant() -> None:
    source = source_text()
    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkInit(qm_ea_id," in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkTrackOpenPositionMae()" in source
    assert "RISK_PERCENT               = 0.0;" in source
    assert "RISK_FIXED                 = 1000.0;" in source
    assert "1671 * 10000" not in source

    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert names
    assert [name for name in names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2] == []

    setfiles = sorted((EA_DIR / "sets").glob("*_H4_backtest.set"))
    assert len(setfiles) == 13
    for setfile in setfiles:
        text = setfile.read_text(encoding="utf-8-sig")
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text

    result = build_gate_hardening.analyze_file(EA_SOURCE, CARD)
    assert result["failures"] == []
    assert result["warnings"] == []
