from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_12944_sperandeo-trend-fault-line-h4"
    / "QM5_12944_sperandeo-trend-fault-line-h4.mq5"
)


def _source() -> str:
    return EA_PATH.read_text(encoding="utf-8")


def _function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source)
    assert match is not None, f"missing function {name}"
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


def _input_defaults(source: str) -> dict[str, str]:
    return {
        name: value.strip()
        for name, value in re.findall(
            r"(?m)^input\s+\S+\s+(\w+)\s*=\s*([^;]+);", source
        )
    }


def test_framework_chain_risk_and_magic_are_canonical() -> None:
    source = _source()
    defaults = _input_defaults(source)

    assert "#include <QM/QM_Common.mqh>" in source
    assert defaults["RISK_PERCENT"] == "0.0"
    assert defaults["RISK_FIXED"] == "1000.0"
    assert "QM_FrameworkInit(qm_ea_id" in source
    assert "QM_FrameworkMagic()" in source
    assert not re.search(r"\bqm_ea_id\s*\*\s*10000\b", source)

    on_tick = _function_body(source, "OnTick")
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae()") < on_tick.index(
        "QM_KillSwitchCheck()"
    )


def test_card_entry_mechanics_are_literal_and_crossing_based() -> None:
    source = _source()
    entry = _function_body(source, "Strategy_EntrySignal")

    assert "QM_ATR(_Symbol, PERIOD_H4, 1, 1)" in source
    assert "strategy_vol_expansion_mult * atr20" in source
    assert "rates[0].close > line_bar1 + strategy_break_buffer_mult * atr20" in source
    assert "rates[1].close <= line_bar2 + strategy_break_buffer_mult * atr20" in source
    assert "rates[0].close < line_bar1 - strategy_break_buffer_mult * atr20" in source
    assert "rates[1].close >= line_bar2 - strategy_break_buffer_mult * atr20" in source
    assert "MeanSpreadPointsCached(_Symbol, 100, mean_spread)" in entry
    assert "current_spread > strategy_spread_filter_mult * mean_spread" in entry
    assert "QM_NewsInWindow(utc_now, _Symbol, 15, 15, \"high\")" in entry
    assert "QM_TM_ClosePosition" not in entry


def test_pivot_count_and_full_deviation_drive_n_point_regression() -> None:
    source = _source()
    fit = _function_body(source, "FitLinearRegression")
    down = _function_body(source, "FindDownFaultLine")
    up = _function_body(source, "FindUpFaultLine")

    assert "point_count" in fit
    assert "ArraySize(points)" in fit
    assert "required_pivots = strategy_min_pivots" in down
    assert "required_pivots = strategy_min_pivots" in up
    assert "FitLinearRegression(highs, i, required_pivots" in down
    assert "FitLinearRegression(lows, i, required_pivots" in up
    assert "deviation_pct < strategy_zigzag_dev_pct" in down
    assert "deviation_pct < strategy_zigzag_dev_pct" in up
    assert "strategy_zigzag_dev_pct * 0.5" not in source


def test_reverse_breakouts_are_exit_signals_before_opposite_entry() -> None:
    source = _source()
    exit_signal = _function_body(source, "Strategy_ExitSignal")
    on_tick = _function_body(source, "OnTick")

    assert "POSITION_TYPE_BUY" in exit_signal
    assert "long_failed_break || g_signal_state.short_breakout" in exit_signal
    assert "POSITION_TYPE_SELL" in exit_signal
    assert "short_failed_break || g_signal_state.long_breakout" in exit_signal
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index("Strategy_EntrySignal(req)")


def test_all_strategy_inputs_have_mechanical_use_sites() -> None:
    source = _source()
    strategy_inputs = re.findall(
        r"(?m)^input\s+\S+\s+(strategy_\w+)\s*=", source
    )
    assert strategy_inputs
    for name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name


def test_raw_series_scan_is_bounded_cached_and_guarded() -> None:
    source = _source()

    assert source.count("CopyRates(") == 1
    assert "perf-allowed: bounded bespoke pivot/fault-line scan" in source
    assert "STRATEGY_RATE_WINDOW 160" in source
    assert "ArraySize(rates)" in source
    assert "g_signal_state.bar_time == latest_closed.time" in source
    for forbidden in ("iClose(", "iHigh(", "iLow(", "iATR(", "iMA(", "CopyBuffer("):
        assert forbidden not in source
    for forbidden_ml in ("tensorflow", "torch", "sklearn", "keras", "onnx"):
        assert forbidden_ml not in source.lower()
