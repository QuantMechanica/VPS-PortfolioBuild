from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


EA_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = EA_ROOT / "QM5_20002_ict-icytea-core.mq5"
SOURCE = SOURCE_PATH.read_text(encoding="utf-8")


def function_body(name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", SOURCE, re.DOTALL)
    assert match is not None, name
    start = match.end() - 1
    depth = 0
    for index in range(start, len(SOURCE)):
        if SOURCE[index] == "{":
            depth += 1
        elif SOURCE[index] == "}":
            depth -= 1
            if depth == 0:
                return SOURCE[start : index + 1]
    raise AssertionError(f"unterminated function: {name}")


@dataclass(frozen=True)
class Bar:
    time: int
    high: float
    low: float
    close: float


def low_reclaim_model(newest_first: list[Bar], level: float, return_bars: int):
    current = newest_first[0]
    if current.low < level < current.close:
        return current.low, current.time
    if current.close <= level:
        return None
    lowest = float("inf")
    oldest_time = None
    for bar in newest_first[1 : return_bars + 1]:
        if bar.close > level:
            break
        if bar.low < level:
            lowest = min(lowest, bar.low)
            oldest_time = bar.time
    return None if oldest_time is None else (lowest, oldest_time)


def test_primary_source_reclaim_convention_is_encoded_without_prior_close_gate() -> None:
    low = function_body("ICT_LowLevelJustSwept")
    high = function_body("ICT_HighLevelJustSwept")
    assert "if(low1 < level && close1 > level)" in low
    assert "if(high1 > level && close1 < level)" in high
    assert "for(int s = 2; s <= sweep_return_bars + 1; ++s)" in low
    assert "for(int s = 2; s <= sweep_return_bars + 1; ++s)" in high
    assert "close2" not in SOURCE

    # A conventional immediate rejection remains valid even if the prior close
    # was already above the level; a later first reclaim records the wick bar.
    assert low_reclaim_model(
        [Bar(3, 102, 99, 101), Bar(2, 103, 100.5, 102)], 100, 3
    ) == (99, 3)
    assert low_reclaim_model(
        [Bar(4, 102, 100.2, 101), Bar(3, 100, 98, 99), Bar(2, 99.5, 97, 98.5)],
        100,
        3,
    ) == (97, 2)
    assert low_reclaim_model(
        [Bar(4, 102, 100.2, 101), Bar(3, 102, 99, 101), Bar(2, 99, 97, 98)],
        100,
        3,
    ) is None


def test_same_bar_order_is_not_inferred_and_fvg_is_strictly_post_sweep() -> None:
    process_long = function_body("ICT_ProcessLong")
    process_short = function_body("ICT_ProcessShort")
    assert "sweep_time < g_ict_pending_long.registered_time" in process_long
    assert "sweep_time < g_ict_pending_short.registered_time" in process_short

    build_long = function_body("ICT_TryBuildLongEntry")
    build_short = function_body("ICT_TryBuildShortEntry")
    for body in (build_long, build_short):
        assert "const int leg = MathMin(sweep_shift - 1, ICT_IMPULSE_MAX);" in body
        assert "for(int i = 1; i + 2 <= leg; ++i)" in body
        assert "if(time_a <= pending.sweep_time || time_c > mss_time)" in body
        assert body.index("if(time_a <= pending.sweep_time") < body.index("any_fvg = true")


def test_new_york_calendar_levels_do_not_use_broker_daily_bars() -> None:
    assert "PERIOD_D1" not in SOURCE
    assert "ICT_BrokerTimeToNY(t, ny);" in function_body("ICT_PrevDayRange")
    week = function_body("ICT_PrevWeekRange")
    assert "ICT_NYWeekKey(ny)" in week
    assert "PERIOD_M15" in week
    day = function_body("ICT_PrevDayRange")
    assert "ny.day_of_week == 0 || ny.day_of_week == 6" in day


def test_management_and_flattening_precede_entry_news_gate() -> None:
    tick = function_body("OnTick")
    assert tick.index("ICT_EnforceEntryWindow") < tick.index(
        "QM_FrameworkHandleFridayClose"
    )
    assert tick.index("QM_FrameworkHandleFridayClose") < tick.index(
        "Strategy_ManageOpenPosition"
    )
    assert tick.index("Strategy_ManageOpenPosition") < tick.index(
        "Strategy_ExitSignal"
    )
    assert tick.index("Strategy_ExitSignal") < tick.index("ICT_FreshNewsAllowsAt")


def test_gtc_and_fill_race_are_checked_with_uncached_calendar_truth() -> None:
    assert "QM_NewsAllowsTrade2Fresh" in function_body("ICT_FreshNewsAllowsAt")
    enforcement = function_body("ICT_EnforceEntryWindow")
    assert "QM_TM_RemovePendingOrder" in enforcement
    assert "POSITION_TIME" in enforcement
    assert "QM_TM_ClosePosition" in enforcement
    transaction = function_body("OnTradeTransaction")
    assert transaction.index("QM_FrameworkOnTradeTransaction") < transaction.index(
        "ICT_EnforceEntryWindow"
    )


def test_restart_rebuilds_or_transactionally_restores_every_safety_state() -> None:
    init = function_body("OnInit")
    for call in (
        "ICT_RebuildSwings",
        "ICT_RestorePending(g_ict_pending_long",
        "ICT_RestorePending(g_ict_pending_short",
        "ICT_RebuildPositionStates",
    ):
        assert call in init
    persist = function_body("ICT_PersistPending")
    assert persist.index('GlobalVariableDel(prefix + "ready")') < persist.index(
        'ICT_WritePendingField(prefix + "sx"'
    )
    assert persist.index('ICT_WritePendingField(prefix + "rt"') < persist.index(
        'ICT_WritePendingField(prefix + "ready"'
    )
    rebuild = function_body("ICT_RebuildPositionStates")
    assert "ICT_PositionClosingHistory" in rebuild
    assert "POSITION_SL" in rebuild
    assert "partial_done = true" in rebuild  # fail-closed if deal history is unavailable
    assert "HistorySelectByPosition" in function_body("ICT_PositionClosingHistory")

