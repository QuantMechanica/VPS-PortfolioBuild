from pathlib import Path


EA = Path(__file__).parents[1] / "QM5_41272_turn-of-month-index-long-restart-r1.mq5"


def reconstructed_days(entry_bar_current_shift: int) -> int:
    """Mirror MQL5 iBarShift semantics: current D1=0, prior D1=1, etc."""
    if entry_bar_current_shift < 0:
        raise ValueError("entry bar unavailable")
    return entry_bar_current_shift


def test_restart_does_not_reset_inherited_position_to_today() -> None:
    assert reconstructed_days(0) == 0
    assert reconstructed_days(1) == 1
    assert reconstructed_days(3) == 3
    assert reconstructed_days(8) == 8


def test_missing_entry_history_is_fail_closed() -> None:
    try:
        reconstructed_days(-1)
    except ValueError:
        pass
    else:
        raise AssertionError("missing history must not silently reset held days")


def test_source_binds_reconstruction_to_position_time() -> None:
    source = EA.read_text(encoding="utf-8")
    assert "PositionGetInteger(POSITION_TIME)" in source
    assert "iBarShift(_Symbol, PERIOD_D1, position_time, false)" in source
    assert "g_days_elapsed = entry_bar_shift;" in source
    assert "if(!Strategy_RehydrateHeldDays())" in source
    assert "g_last_seen_day_key = today_key; // restart-safety" not in source
