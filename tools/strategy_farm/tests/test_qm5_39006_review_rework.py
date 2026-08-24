from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_39006_forexfactory-spudfyre-stochastic-ribbon"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"
AUTHORIZED_SYMBOLS = {
    "EURUSD.DWX": 0,
    "GBPUSD.DWX": 1,
    "AUDUSD.DWX": 2,
}


def source_text() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def between(text: str, start: str, end: str) -> str:
    return text.split(start, 1)[1].split(end, 1)[0]


def test_qm5_39006_build_gate_hardening_is_clean() -> None:
    result = hardening.analyze_file(
        SOURCE_PATH, hardening.find_card(REPO_ROOT, EA_LABEL)
    )
    assert result["failures"] == []
    assert result["warnings"] == []


def test_qm5_39006_card_timeframe_stop_and_break_even_are_exact() -> None:
    source = source_text()
    entry = between(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")
    manage = between(source, "void Strategy_ManageOpenPosition", "bool Strategy_ExitSignal")

    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H1" in source
    assert "QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips))" in entry
    assert "const double sl = swing_low - buf;" in entry
    assert "const double sl = swing_high + buf;" in entry
    assert "1.5 * g_cached_atr_1" not in entry
    assert "3.5 * g_cached_atr_1" not in entry
    assert "initial_risk * strategy_be_trigger_r" in manage
    assert "QM_TM_MoveSL" in manage
    assert "strategy_sl_buffer_pips * 10" not in source
    assert "strategy_be_trigger_r * 10" not in source


def test_qm5_39006_risk_utc_slippage_and_framework_wiring() -> None:
    raw = source_text()
    source = hardening.strip_comments_preserve_lines(raw)
    no_trade = between(raw, "bool Strategy_NoTradeFilter", "bool Strategy_EntrySignal")
    on_tick = between(raw, "void OnTick()", "void OnTimer()")

    assert "#include <QM/QM_Common.mqh>" in raw
    assert "input double RISK_PERCENT               = 0.0;" in raw
    assert "input double RISK_FIXED                 = 1000.0;" in raw
    assert "TimeToStruct(QM_BrokerToUTC(TimeCurrent()), dt);" in no_trade
    assert "QM_KillSwitchInit(qm_ea_id" in raw
    assert "strategy_daily_hard_stop_pct" in raw
    assert "strategy_total_dd_halt_pct" in raw
    assert "QM_EntryConfigure(qm_ea_id" in raw
    assert "strategy_max_slippage_ticks * tick_size / point" in raw
    assert "strategy_max_slippage_ticks > 3.0" in raw
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert re.search(r"\b39006\s*\*\s*10000", source) is None
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", source, re.IGNORECASE)


def test_qm5_39006_all_declared_inputs_have_use_sites() -> None:
    source = hardening.strip_comments_preserve_lines(source_text())
    input_names = re.findall(r"(?m)^\s*input\s+\S+\s+(\w+)\s*=", source)
    source_without_declarations = re.sub(
        r"(?m)^\s*input\s+\S+\s+\w+\s*=.*?;\s*$", "", source
    )
    unused = [
        name
        for name in input_names
        if re.search(rf"\b{re.escape(name)}\b", source_without_declarations) is None
    ]
    assert unused == []


def test_qm5_39006_uses_bounded_framework_indicators_only() -> None:
    source = source_text()

    assert "const int stoch_periods[7]" in source
    assert "for(int i = 0; i < 7; ++i)" in source
    assert "QM_Stoch_K" in source
    assert "QM_ATR" in source
    for forbidden in (
        "CopyBuffer(",
        "CopyRates(",
        "iStochastic(",
        "iATR(",
        "iOpen(",
        "iHigh(",
        "iLow(",
        "iClose(",
        "iTime(",
    ):
        assert forbidden not in source


def test_qm5_39006_sets_and_magic_rows_match_authorized_universe() -> None:
    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == len(AUTHORIZED_SYMBOLS)

    delivered: dict[str, int] = {}
    for setfile in setfiles:
        payload = setfile.read_text(encoding="utf-8-sig")
        symbol = re.search(r"(?m)^; symbol:\s*(\S+)\s*$", payload)
        slot = re.search(r"(?m)^qm_magic_slot_offset=(\d+)\s*$", payload)
        assert symbol is not None
        assert slot is not None
        delivered[symbol.group(1)] = int(slot.group(1))
        assert "RISK_FIXED=1000" in payload
        assert "RISK_PERCENT=0" in payload
        assert "strategy_max_slippage_ticks=3.0" in payload

    assert delivered == AUTHORIZED_SYMBOLS

    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        active_rows = {
            row["symbol"]: int(row["symbol_slot"])
            for row in csv.DictReader(handle)
            if row["ea_id"] == "39006" and row["status"] == "active"
        }
    assert active_rows == AUTHORIZED_SYMBOLS
