import datetime as dt

from tools.strategy_farm.portfolio.ftmo_calendar_launch_gate_screen import (
    calendar_gate_set,
)


def test_calendar_gate_membership_is_ex_ante_and_complete() -> None:
    gates = calendar_gate_set()
    day = dt.date(2024, 7, 23)

    assert len(gates) == 28
    assert gates["month_07"](day)
    assert gates["quarter_3"](day)
    assert gates["half_2"](day)
    assert gates["weekday_1"](day)
    assert gates["month_day_21_end"](day)
    assert not gates["month_06"](day)
    assert not gates["month_day_01_10"](day)
