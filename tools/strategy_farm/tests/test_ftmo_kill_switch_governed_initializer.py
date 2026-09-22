"""Static/behavioural contract for the governed FTMO kill-switch initializer."""
from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[3]
KILL_SWITCH = ROOT / "framework" / "include" / "QM" / "QM_KillSwitch.mqh"
COMMON = ROOT / "framework" / "include" / "QM" / "QM_Common.mqh"
KS_SOURCE = KILL_SWITCH.read_text(encoding="utf-8", errors="replace")
COMMON_SOURCE = COMMON.read_text(encoding="utf-8", errors="replace")


def _function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\n\s*\{{", source)
    assert match, f"{name} not found"
    start = source.index("{", match.start())
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise AssertionError(f"unbalanced function {name}")


def _mql_day_key(utc_value: datetime) -> int:
    prague = utc_value.astimezone(ZoneInfo("Europe/Prague"))
    return prague.year * 1000 + prague.timetuple().tm_yday - 1


def test_named_anchor_policy_and_conservative_default_are_explicit() -> None:
    assert "FTMO_BALANCE_AT_MIDNIGHT = 1" in KS_SOURCE
    assert "MAX_BALANCE_EQUITY       = 2" in KS_SOURCE
    assert re.search(
        r"qm_ftmo_anchor_mode\s*=\s*MAX_BALANCE_EQUITY\s*;", KS_SOURCE
    )
    anchor = _function_body(KS_SOURCE, "double QM_KillSwitchAnchorEquity")
    assert "g_qm_ks_anchor_mode == FTMO_BALANCE_AT_MIDNIGHT" in anchor
    assert "g_qm_ks_anchor_mode == MAX_BALANCE_EQUITY" in anchor
    assert anchor.index("return balance") < anchor.index("MathMax(equity, balance)")


def test_one_framework_initializer_is_fail_closed_before_init_event() -> None:
    core = _function_body(COMMON_SOURCE, "bool QM_FrameworkInitCoreAfterRuntimeStateArmed")
    kill_init = core.index("QM_KillSwitchInit")
    ftmo_init = core.index("QM_KillSwitchApplyFtmoContract")
    init_event = core.index('QM_LogEvent(QM_INFO, "INIT"')
    assert kill_init < ftmo_init < init_event
    assert "ftmo_kill_switch_contract_failed" in core

    governed = _function_body(KS_SOURCE, "bool QM_KillSwitchApplyFtmoContract")
    assert governed.index("QM_KillSwitchSetBookTag") < governed.index(
        "QM_KillSwitchSetPragueDayAnchor"
    )
    assert "if(!QM_KillSwitchSetBookTag(tag))" in governed
    assert "if(!QM_KillSwitchSetPragueDayAnchor(qm_ftmo_anchor_mode))" in governed


def test_prague_helper_encodes_both_dst_calendars_and_wall_clock_timer() -> None:
    assert "QM_KillSwitchNthSunday(t.year, 3, 2)" in KS_SOURCE
    assert "QM_KillSwitchNthSunday(t.year, 11, 1)" in KS_SOURCE
    assert "QM_KillSwitchLastSunday(t.year, 3)" in KS_SOURCE
    assert "QM_KillSwitchLastSunday(t.year, 10)" in KS_SOURCE
    clock = _function_body(KS_SOURCE, "bool QM_KillSwitchPragueClock")
    assert "TimeGMT()" in clock
    assert "MQLInfoInteger(MQL_TESTER)" in clock
    timer = _function_body(COMMON_SOURCE, "void QM_FrameworkOnTimer")
    assert "QM_KillSwitchRefreshBrokerDay();" in timer


def test_rollover_event_and_state_readback_fields_are_durable() -> None:
    refresh = _function_body(KS_SOURCE, "void QM_KillSwitchRefreshBrokerDay")
    for field in (
        "KS_DAY_ROLLOVER", "old_day_key", "new_day_key", "server_time",
        "effective_prague_time", "offset_hours", "anchor_mode",
        "selected_anchor",
    ):
        assert field in refresh
    save = _function_body(KS_SOURCE, "void QM_KillSwitchSaveState")
    for field in (
        "anchor_offset", "anchor_mode", "book_tag", "prague_calendar",
        "prague_date",
    ):
        assert f'"{field}=' in save


def test_friday_close_to_sunday_restart_requires_a_new_prague_key() -> None:
    friday_close = datetime(2026, 9, 18, 21, 54, 59, tzinfo=timezone.utc)
    sunday_restart = datetime(2026, 9, 20, 8, 0, 0, tzinfo=timezone.utc)
    assert _mql_day_key(friday_close) != _mql_day_key(sunday_restart)
    setter = _function_body(KS_SOURCE, "bool QM_KillSwitchSetPragueDayAnchor")
    assert setter.index("QM_KillSwitchDayKey(prague_time)") < setter.index(
        "QM_KillSwitchRestoreState()"
    )
    assert setter.index("QM_KillSwitchRestoreState()") < setter.index(
        "QM_KillSwitchSaveState()"
    )


def test_all_six_sleeves_delegate_timer_and_init_to_shared_framework() -> None:
    labels = (
        "QM5_13213_balke-gmt3-range-breakout",
        "QM5_10706_tv-mon-ls",
        "QM5_10700_tv-liq-break",
        "QM5_11422_williams-18ma-outside-bar-entry-d1",
        "QM5_10403_et-turtle20x",
        "QM5_41219_cum-rsi2-commodity-requal8",
    )
    for label in labels:
        source = (ROOT / "framework" / "EAs" / label / f"{label}.mq5").read_text(
            encoding="utf-8", errors="replace"
        )
        assert source.count("QM_FrameworkInit(") == 1
        assert source.count("QM_FrameworkOnTimer();") == 1
        assert "QM_KillSwitchSetBookTag" not in source
        assert "QM_KillSwitchSetPragueDayAnchor" not in source
