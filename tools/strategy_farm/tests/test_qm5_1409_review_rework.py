from __future__ import annotations

import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_1409_wyckoff-sign-of-strength-phase-d-h4"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
SETS = EA_DIR / "sets"

APPROVED_SLOTS = {
    "EURUSD.DWX": 0,
    "GBPUSD.DWX": 1,
    "USDJPY.DWX": 2,
    "NDX.DWX": 7,
    "WS30.DWX": 8,
    "GDAXI.DWX": 9,  # canonical DWX house symbol for card token GER40.DWX
    "XAUUSD.DWX": 12,
    "XTIUSD.DWX": 13,
}


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_all_declared_inputs_are_wired_and_series_access_is_governed() -> None:
    source = _source()
    inputs = re.findall(r"^input\s+\S+\s+(\w+)\s*=", source, re.MULTILINE)

    assert inputs
    assert all(len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2 for name in inputs)
    assert not re.search(r"\bi(?:ATR|MA|RSI|MACD|ADX|Bands|Open|High|Low|Close)\s*\(", source)
    for line in source.splitlines():
        if "iBarShift(" in line or "CopyRates(" in line:
            assert "perf-allowed:" in line


def test_trimmed_range_uses_retained_sample_and_fractal_spring() -> None:
    compact = _compact(_source())

    assert "retained_count=tr_len-2*trim_cnt" in compact
    assert "trim_cnt+(int)MathFloor(0.20*(retained_count-1))" in compact
    assert "trim_cnt+(int)MathFloor(0.80*(retained_count-1))" in compact
    assert "high_top20_idx>=ArraySize(highs)" in compact
    assert "low_bot20_idx>=ArraySize(lows)" in compact
    assert "Strategy_IsSwingLow(rates,idx,strategy_fractal_wing_bars)" in compact


def test_news_is_literal_entry_only_and_management_is_framework_governed() -> None:
    source = _source()
    compact = _compact(source)
    on_tick = compact[compact.index("voidOnTick()") : compact.index("voidOnTimer()")]

    assert "qm_news_temporal=QM_NEWS_TEMPORAL_OFF" in compact
    assert "QM_NewsInWindow(news_time_utc,_Symbol,480,480,qm_news_min_impact)" in compact
    assert on_tick.index("Strategy_ManageOpenPosition()") < on_tick.index("QM_NewsAllowsTrade2")
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index("QM_NewsAllowsTrade2")
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index("QM_KillSwitchCheck()")
    assert "QM_TM_PartialClose(" in source
    assert "QM_TM_MoveSL(" in source
    assert "CTrade" not in source
    assert "PositionClosePartial(" not in source
    assert "PositionModify(" not in source


def test_restart_and_invalidation_state_are_durable_and_fail_closed() -> None:
    source = _source()
    compact = _compact(source)

    for field in ("tp1", "high", "move", "signal", "partial", "ready"):
        assert f'"{field}"' in source
    assert "GlobalVariableSet(" in source
    assert "GlobalVariablesFlush();" in source
    assert "Strategy_LPSInvalidated(" in source
    assert "Strategy_BlockPatternReuse(invalidation_time);" in source
    assert 'QM_LogEvent(QM_ERROR,"WYCKOFF_STATE_MISSING"' in compact
    assert "if(!Strategy_EnsurePositionState(ticket))returntrue;" in compact


def test_setfiles_are_exactly_the_approved_canonical_universe() -> None:
    paths = sorted(SETS.glob("*.set"))
    observed: dict[str, int] = {}
    for path in paths:
        match = re.search(rf"{re.escape(LABEL)}_(.+)_H4_backtest\.set$", path.name)
        assert match, path
        symbol = match.group(1)
        values = _set_values(path)
        observed[symbol] = int(values["qm_magic_slot_offset"])
        text = path.read_text(encoding="utf-8")
        assert "; volume_reliability: RELIABLE" in text
        assert "; volume_gate_bias:   ENFORCE_GATE_8" in text
        assert values["strategy_volume_filter_enabled"] == "true"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"

    assert observed == APPROVED_SLOTS


def test_strict_source_hardening_findings_are_closed() -> None:
    result = hardening.analyze(REPO, LABEL)
    checks = result["rows"][0]["checks"]

    assert checks["D7_mae_hook"]["failures"] == 0
    assert checks["D9_trade_request_initialization"]["failures"] == 0
    assert checks["D10_indicator_buffer_bounds"]["failures"] == 0
    assert checks["D15_news_entry_contract"]["failures"] == 0
