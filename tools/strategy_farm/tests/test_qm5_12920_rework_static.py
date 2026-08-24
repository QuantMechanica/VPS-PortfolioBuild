from __future__ import annotations

import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_12920_qp-pre-election-sp500"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SETFILE = EA_DIR / "sets" / f"{EA_LABEL}_SP500.DWX_D1_backtest.set"
CARD = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_12920_qp-pre-election-sp500.md"
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


def test_qm5_12920_passes_source_build_hardening() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, CARD)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_entry_is_exact_d5_and_restart_safe() -> None:
    source = source_text()
    entry = function_body(source, "Strategy_EntrySignal")
    history = function_body(source, "Strategy_HasElectionEntryHistory")

    assert "QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol)" in entry
    assert "QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1)" in entry
    assert "closed_day_key != Strategy_DateKey(d5_date)" in entry
    assert "current_bar_time <= d5_date" not in entry
    assert "g_last_traded_election_year" not in source
    assert "HistorySelect(d5_date, TimeCurrent())" in history
    assert "DEAL_MAGIC" in history
    assert "entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT" in history
    assert "Strategy_HasElectionEntryHistory(election_year, history_ready)" in entry


def test_calendar_and_history_checks_replace_raw_series_calls() -> None:
    source = source_text()
    assert "QM_CalendarPeriodKey(PERIOD_D1, _Symbol, strategy_min_d1_bars)" in source
    assert not re.search(r"^\s*(?:const\s+\w+\s+\w+\s*=\s*)?(?:iTime|Bars)\s*\(", source, re.MULTILINE)
    assert "CopyBuffer(" not in source
    assert "QM_StopATR(" in source


def test_mandatory_exit_precedes_entry_only_filters() -> None:
    source = source_text()
    on_tick = function_body(source, "OnTick")
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae()") < on_tick.index("QM_KillSwitchCheck()")
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index("QM_NewsAllowsTrade2(")
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index("QM_FrameworkHandleFridayClose()")
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index("Strategy_NoTradeFilter()")
    assert "input bool   qm_friday_close_enabled     = false;" in source
    assert "QM_IsNewBar(" not in on_tick


def test_request_and_framework_wiring_are_complete() -> None:
    source = source_text()
    on_tick = function_body(source, "OnTick")
    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkInit(qm_ea_id," in source
    assert "QM_FrameworkMagic()" in source
    assert "ZeroMemory(req);" in on_tick
    assert on_tick.index("ZeroMemory(req);") < on_tick.index("Strategy_EntrySignal(req)")
    assert "QM_TM_OpenPosition(req, out_ticket);" in on_tick
    assert not re.search(r"\b12920\s*\*\s*10000\b", source)


def test_every_declared_input_has_an_executable_use_site() -> None:
    source = source_text()
    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert names
    unused = [name for name in names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2]
    assert unused == []


def test_backtest_set_binds_identity_risk_and_card_filters() -> None:
    set_text = SETFILE.read_text(encoding="utf-8-sig")
    assert "qm_ea_id=12920" in set_text
    assert "qm_magic_slot_offset=2" in set_text
    assert "RISK_FIXED=1000" in set_text
    assert "RISK_PERCENT=0" in set_text
    assert "qm_news_temporal=0" in set_text
    assert "qm_news_compliance=0" in set_text
    assert "qm_friday_close_enabled=false" in set_text
    assert "strategy_atr_period=20" in set_text
    assert "strategy_atr_sl_mult=2.0" in set_text
    assert "strategy_min_d1_bars=60" in set_text
