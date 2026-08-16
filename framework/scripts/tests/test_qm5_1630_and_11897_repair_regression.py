"""Regression tests for QM5_1630 Demark TD Sequential Overlay and QM5_11897 Vegas Wave repairs."""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
EAS_DIR = REPO_ROOT / "framework" / "EAs"


def test_qm5_1630_cooldown_only_on_successful_open_regression() -> None:
    """Regression test for QM5_1630:

    1. Strategy_EntrySignal must NOT set cooldown timestamps.
    2. Cooldown timestamps (g_last_buy_entry_time, g_last_sell_entry_time) must only be set
       inside the successful QM_TM_OpenPosition branch in OnTick.
    3. req.symbol_slot must be wired to qm_magic_slot_offset.
    4. State machine simulation:
       - Failed open preserves g_last_buy_entry_time == 0 -> next signal is NOT blocked.
       - Successful open sets g_last_buy_entry_time -> signals within cooldown window ARE blocked.
       - Signals beyond cooldown window are permitted.
    """
    mq5_path = (
        EAS_DIR
        / "QM5_1630_demark-td-sequential-combo-overlay-h4"
        / "QM5_1630_demark-td-sequential-combo-overlay-h4.mq5"
    )
    source = mq5_path.read_text(encoding="utf-8")

    # 1. Check Strategy_EntrySignal does not modify timestamps
    entry_signal_body = source.split("bool Strategy_EntrySignal", 1)[1].split(
        "void Strategy_ManageOpenPosition", 1
    )[0]
    assert "g_last_buy_entry_time =" not in entry_signal_body, (
        "Strategy_EntrySignal must not write g_last_buy_entry_time"
    )
    assert "g_last_sell_entry_time =" not in entry_signal_body, (
        "Strategy_EntrySignal must not write g_last_sell_entry_time"
    )
    assert "req.symbol_slot = qm_magic_slot_offset;" in entry_signal_body

    # 2. Check OnTick writes timestamps strictly on open success
    ontick_body = source.split("void OnTick()", 1)[1].split("void OnTimer()", 1)[0]
    open_block = ontick_body.split("if(QM_TM_OpenPosition(req, out_ticket))", 1)[1].split(
        "}", 1
    )[0]
    assert "g_last_buy_entry_time = iTime(_Symbol, _Period, 0)" in open_block
    assert "g_last_sell_entry_time = iTime(_Symbol, _Period, 0)" in open_block

    # 3. Behavioral Simulation of Cooldown Logic
    strategy_cooldown_bars = 18
    g_last_buy_entry_time = 0
    bar_timestamps = [1000 + i * 14400 for i in range(50)]  # H4 bars (14400s)

    def check_entry_signal(bar_idx: int, fire_buy: bool) -> bool:
        if not fire_buy:
            return False
        if g_last_buy_entry_time > 0:
            last_idx = bar_timestamps.index(g_last_buy_entry_time)
            bars_since = bar_idx - last_idx
            if 0 <= bars_since < strategy_cooldown_bars:
                return False
        return True

    # Step A: Bar 0 - Signal fires, open fails
    bar_0 = 0
    sig_0 = check_entry_signal(bar_0, fire_buy=True)
    assert sig_0 is True, "Initial signal should be allowed"
    open_success_0 = False  # Simulating open failure (e.g. rejection)
    if open_success_0:
        g_last_buy_entry_time = bar_timestamps[bar_0]
    assert g_last_buy_entry_time == 0, "Failed open must not set timestamp"

    # Step B: Bar 1 (next bar) - Signal fires, verify NOT cooldown blocked
    bar_1 = 1
    sig_1 = check_entry_signal(bar_1, fire_buy=True)
    assert sig_1 is True, "Signal immediately after failed open MUST NOT be blocked by cooldown"
    open_success_1 = True  # Simulating successful open
    if open_success_1:
        g_last_buy_entry_time = bar_timestamps[bar_1]
    assert g_last_buy_entry_time == bar_timestamps[bar_1]

    # Step C: Bar 2 (1 bar after success) - Signal fires, verify cooldown BLOCKS it
    bar_2 = 2
    sig_2 = check_entry_signal(bar_2, fire_buy=True)
    assert sig_2 is False, "Signal 1 bar after successful open MUST be cooldown-blocked"

    # Step D: Bar 18 (17 bars after success) - Signal fires, verify cooldown BLOCKS it
    bar_18 = 18
    sig_18 = check_entry_signal(bar_18, fire_buy=True)
    assert sig_18 is False, "Signal 17 bars after successful open MUST be cooldown-blocked"

    # Step E: Bar 19 (18 bars after success) - Signal fires, verify cooldown ALLOWS it
    bar_19 = 19
    sig_19 = check_entry_signal(bar_19, fire_buy=True)
    assert sig_19 is True, "Signal 18 bars after successful open MUST be allowed"


def test_qm5_11897_timeframe_wiring_and_duration_regression() -> None:
    """Regression test for QM5_11897:

    1. GetBuyStopSignal and GetShortStopSignal must derive expire_seconds from PeriodSeconds(tf).
    2. Strategy_ManageOpenPosition must derive time-stop from PeriodSeconds(GetStrategyTimeframe()).
    3. No hard-coded '* 3600' durations in expiry or time stops.
    """
    mq5_path = (
        EAS_DIR
        / "QM5_11897_vegas-wave-ema144-169-fractal-h1-alt"
        / "QM5_11897_vegas-wave-ema144-169-fractal-h1-alt.mq5"
    )
    source = mq5_path.read_text(encoding="utf-8")

    # Verify no hard-coded 3600
    assert "3600" not in source, "No hardcoded 3600 seconds should exist in QM5_11897"

    # Verify PeriodSeconds usage in GetBuyStopSignal
    buy_stop_body = source.split("bool GetBuyStopSignal", 1)[1].split(
        "bool GetShortStopSignal", 1
    )[0]
    assert "expire_seconds = (10 - (fractal_bar - 3)) * PeriodSeconds(tf);" in buy_stop_body

    # Verify PeriodSeconds usage in GetShortStopSignal
    short_stop_body = source.split("bool GetShortStopSignal", 1)[1].split(
        "bool Strategy_EntrySignal", 1
    )[0]
    assert "expire_seconds = (10 - (fractal_bar - 3)) * PeriodSeconds(tf);" in short_stop_body

    # Verify PeriodSeconds usage in Strategy_ManageOpenPosition
    manage_body = source.split("void Strategy_ManageOpenPosition", 1)[1].split(
        "bool Strategy_ExitSignal", 1
    )[0]
    assert (
        "if(TimeCurrent() - open_time >= 120 * PeriodSeconds(GetStrategyTimeframe()))"
        in manage_body
    )
