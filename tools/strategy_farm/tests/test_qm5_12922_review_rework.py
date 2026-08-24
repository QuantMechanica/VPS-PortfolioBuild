from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_12922_ariel-first-half-month-idx"
SOURCE_PATH = EA_DIR / "QM5_12922_ariel-first-half-month-idx.mq5"
SETS_DIR = EA_DIR / "sets"


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def _between(text: str, start: str, end: str) -> str:
    return text.split(start, 1)[1].split(end, 1)[0]


def test_calendar_reconstruction_uses_bounded_framework_helpers() -> None:
    source = _source()

    assert "const int STRATEGY_D1_LOOKBACK_LIMIT = 32;" in source
    assert "shift < STRATEGY_D1_LOOKBACK_LIMIT" in source
    assert "QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, shift)" in source
    assert "QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0)" in source
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in source

    forbidden_raw_series = (
        "iTime(",
        "iOpen(",
        "iHigh(",
        "iLow(",
        "iClose(",
        "CopyTime(",
        "CopyRates(",
        "CopyBuffer(",
    )
    for token in forbidden_raw_series:
        assert token not in source


def test_restart_state_is_reconstructed_without_terminal_globals() -> None:
    source = _source()
    on_init = _between(source, "int OnInit()", "void OnDeinit")

    assert "Strategy_ReconstructCalendarState()" in on_init
    assert "HistorySelect(month_start, now)" in source
    assert "HistoryDealGetInteger(ticket, DEAL_MAGIC)" in source
    assert "HistoryDealGetInteger(ticket, DEAL_ENTRY)" in source
    assert "QM_TM_OpenPositionCount(QM_FrameworkMagic())" in source
    assert "GlobalVariable" not in source

    reconstruction = _between(
        source, "bool Strategy_ReconstructCalendarState()", "// -----------------------------------------------------------------------------"
    )
    assert "if(trading_day == 1)" in reconstruction
    assert "Strategy_MacroDayState(day_key)" in reconstruction
    assert "else if(trading_day == 2)" in reconstruction
    assert "QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1)" in reconstruction
    assert "g_strategy_entry_due = g_strategy_entry_deferred;" in reconstruction


def test_named_t1_macro_events_are_scanned_across_the_whole_session() -> None:
    source = _source()

    for event_name in (
        '"NON-FARM EMPLOYMENT CHANGE"',
        '"NONFARM PAYROLLS"',
        '"FEDERAL FUNDS RATE"',
        '"FOMC STATEMENT"',
        '"MAIN REFINANCING RATE"',
        '"ECB PRESS CONFERENCE"',
    ):
        assert event_name in source

    assert "Strategy_LoadTesterMacroCalendar()" in source
    assert "QM_NewsParseDateTimeUTC" in source
    assert 'QM_NewsImpactUpper(fields[impact_index]) != "HIGH"' in source
    assert "CalendarValueHistory(values, day_start, day_start + 86399)" in source
    assert "event.importance != CALENDAR_IMPORTANCE_HIGH" in source
    assert "const int STRATEGY_MACRO_DAY_LIMIT   = 4096;" in source
    assert "count > STRATEGY_MACRO_DAY_LIMIT" in source


def test_entry_due_is_consumed_only_after_successful_open() -> None:
    source = _source()
    entry_signal = _between(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")
    assert "g_strategy_entry_due = false" not in entry_signal

    on_tick = _between(source, "void OnTick()", "void OnTimer()")
    news_denial = _between(on_tick, "if(!news_allows)", "QM_EntryRequest req;")
    assert "g_strategy_entry_due = false" not in news_denial

    successful_open = _between(
        on_tick, "if(QM_TM_OpenPosition(req, out_ticket))", "         }\n      }"
    )
    assert "g_strategy_last_traded_month_key = g_strategy_last_month_key;" in successful_open
    assert "g_strategy_entry_due = false;" in successful_open


def test_friday_close_is_fail_closed_off_in_source_and_sets() -> None:
    source = _source()
    assert "input bool   qm_friday_close_enabled     = false;" in source
    assert "if(qm_friday_close_enabled)" in source
    assert "return INIT_PARAMETERS_INCORRECT;" in source
    assert "QM_FrameworkHandleFridayClose()" in source

    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == 5
    for setfile in setfiles:
        text = setfile.read_text(encoding="utf-8-sig")
        assert "qm_friday_close_enabled=false" in text
        assert "qm_friday_close_hour_broker=21" in text


def test_framework_corset_risk_magic_mae_and_input_wiring() -> None:
    source = _source()

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkInit(qm_ea_id" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_TM_OpenPosition(req, out_ticket)" in source
    assert "RISK_FIXED                  = 1000.0;" in source
    assert "RISK_PERCENT                = 0.0;" in source
    assert not re.search(r"12922\s*\*\s*10000", source)
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", source, re.IGNORECASE)

    declared_inputs = re.findall(r"^input\s+\w+\s+(\w+)\s*=", source, re.MULTILINE)
    assert declared_inputs
    for name in declared_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    expected_symbols = {"GDAXI.DWX", "NDX.DWX", "SP500.DWX", "UK100.DWX", "WS30.DWX"}
    setfiles = sorted(SETS_DIR.glob("*.set"))
    actual_symbols = {path.name.rsplit("_", 3)[-3] for path in setfiles}
    assert actual_symbols == expected_symbols
    for setfile in setfiles:
        text = setfile.read_text(encoding="utf-8-sig")
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert "qm_news_temporal=3" in text
        assert "qm_news_compliance=1" in text
        assert "qm_news_stale_max_hours=336" in text
