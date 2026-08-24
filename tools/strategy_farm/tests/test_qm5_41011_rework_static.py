from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_41011_tokyo-london-bank-flow-handover"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"
AUTHORIZED_SYMBOLS = {
    "EURJPY.DWX": 0,
    "GBPJPY.DWX": 1,
    "USDJPY.DWX": 2,
}


def source_text() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def between(text: str, start: str, end: str) -> str:
    return text.split(start, 1)[1].split(end, 1)[0]


def test_qm5_41011_build_gate_hardening_is_clean() -> None:
    result = hardening.analyze_file(
        SOURCE_PATH, hardening.find_card(REPO_ROOT, EA_LABEL)
    )
    assert result["failures"] == []
    assert result["warnings"] == []


def test_qm5_41011_range_is_exact_bounded_and_perf_allowed() -> None:
    source = source_text()
    range_builder = between(source, "bool StrategyBuildRange", "void AdvanceState_OnNewBar")

    assert "range_end_utc - 1" in range_builder
    assert "expected_bars > STRATEGY_MAX_RANGE_BARS" in range_builder
    assert "ArrayResize(range_rates, expected_bars) != expected_bars" in range_builder
    assert "copied != expected_bars || ArraySize(range_rates) < expected_bars" in range_builder
    assert "bar_minute < range_start_minute || bar_minute >= range_end_minute" in range_builder
    assert "closed_rates[0].time" in source
    assert "ArraySize(closed_rates) < 1" in source

    for line in source.splitlines():
        if "iBarShift(" in line or "CopyRates(" in line:
            assert "// perf-allowed" in line
    for forbidden in ("iOpen(", "iHigh(", "iLow(", "iClose(", "iTime(", "CopyBuffer("):
        assert forbidden not in source


def test_qm5_41011_card_pips_midpoint_and_range_target_are_exact() -> None:
    source = source_text()
    entry = between(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")

    assert "input double InpBufferPips              = 2.0;" in source
    assert "input double InpMinAtrPips              = 15.0;" in source
    assert "_Symbol, (int)MathRound(InpMinAtrPips));" in entry
    assert "_Symbol, (int)MathRound(InpBufferPips));" in entry
    assert "g_cached_bar_minute_utc < entry_start" in entry
    assert "g_cached_bar_minute_utc >= entry_end" in entry
    assert "InpMinAtrPips * 10" not in source
    assert "InpBufferPips * 10" not in source
    assert "(g_cached_range_high + g_cached_range_low) * 0.5" in entry
    assert "const double range_width = g_cached_range_high - g_cached_range_low;" in entry
    assert "ask + InpRrMultiplier * range_width" in entry
    assert "bid - InpRrMultiplier * range_width" in entry
    assert "0.5 * g_cached_atr_1" not in source
    assert "4.0 * g_cached_atr_1" not in source


def test_qm5_41011_exits_precede_entry_only_news_and_no_trade() -> None:
    source = source_text()
    on_tick = between(source, "void OnTick()", "void OnTimer()")

    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("QM_FrameworkHandleFridayClose()") < on_tick.index(
        "Strategy_ManageOpenPosition();"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )


def test_qm5_41011_consumes_daily_opportunity_only_after_open_success() -> None:
    source = source_text()
    entry = between(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")
    on_tick = between(source, "void OnTick()", "void OnTimer()")

    assert "g_cached_traded = true" not in entry
    assert "if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)" in on_tick
    success_tail = on_tick.split(
        "if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)", 1
    )[1]
    assert "g_cached_traded = true;" in success_tail
    assert "StrategyRestoreDailyTradeState(TimeCurrent());" in source
    assert "HistoryDealGetInteger(deal, DEAL_MAGIC)" in source


def test_qm5_41011_framework_risk_execution_and_input_wiring() -> None:
    raw = source_text()
    source = hardening.strip_comments_preserve_lines(raw)

    assert "#include <QM/QM_Common.mqh>" in raw
    assert "input double RISK_PERCENT               = 0.0;" in raw
    assert "input double RISK_FIXED                 = 1000.0;" in raw
    assert "QM_FrameworkDeclareExecutionContract(" in raw
    assert "PERIOD_M15" in raw
    assert "QM_KillSwitchInit(qm_ea_id" in raw
    assert "InpDailyDrawdownHardStopPct" in raw
    assert "InpTotalDrawdownStopPct" in raw
    assert "QM_EntryConfigure(qm_ea_id" in raw
    assert "InpMaxSlippageTicks * tick_size / point" in raw
    assert re.search(r"\b41011\s*\*\s*10000", source) is None
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", source, re.IGNORECASE)

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


def test_qm5_41011_sets_and_magic_rows_match_authorized_universe() -> None:
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
        assert "qm_news_temporal=3" in payload
        assert "qm_news_compliance=1" in payload
        assert "qm_news_stale_max_hours=336" in payload
        assert "InpMinAtrPips=15.0" in payload
        assert "InpDailyLossLimitPct=2.0" in payload
        assert "InpDailyDrawdownHardStopPct=2.5" in payload
        assert "InpTotalDrawdownStopPct=5.0" in payload
        assert "InpMaxSlippageTicks=3.0" in payload

    assert delivered == AUTHORIZED_SYMBOLS

    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        active_rows = {
            row["symbol"]: int(row["symbol_slot"])
            for row in csv.DictReader(handle)
            if row["ea_id"] == "41011" and row["status"] == "active"
        }
    assert active_rows == AUTHORIZED_SYMBOLS
