"""Reference invariants for QM5_41243's locked event translation."""

from __future__ import annotations

import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta


BUY = 1
SELL = -1


def fade_direction(open_price: float, close_price: float) -> int:
    if close_price < open_price:
        return BUY
    if close_price > open_price:
        return SELL
    return 0


def event_window(now_ny: datetime) -> bool:
    return (
        now_ny.weekday() == 2
        and now_ny.hour == 10
        and now_ny.minute == 35
        and 0 <= now_ny.second < 30
    )


def completed_bar_matches(decision_bar: datetime, release_bar: datetime) -> bool:
    return (
        decision_bar.date() == release_bar.date()
        and (release_bar.hour, release_bar.minute) == (10, 30)
        and decision_bar - release_bar == timedelta(minutes=5)
    )


def quote_allowed(bid: float, ask: float, point: float, ceiling: int = 1500) -> bool:
    if bid <= 0 or ask <= 0 or point <= 0 or ask < bid:
        return False
    return 0 <= (ask - bid) / point <= ceiling


def encode_direction(day_key: int, direction: int) -> int:
    if direction not in (BUY, SELL):
        raise ValueError("direction must be BUY or SELL")
    return day_key if direction == BUY else -day_key


@dataclass(frozen=True)
class PositionState:
    magic_count: int
    symbol_ok: bool
    position_direction: int
    persisted_day_key: int
    persisted_direction: int
    opened_day_key: int
    has_stop: bool
    now_hhmm: int
    elapsed_minutes: int


def must_repair(state: PositionState) -> bool:
    return (
        state.magic_count != 1
        or not state.symbol_ok
        or state.position_direction != state.persisted_direction
        or state.persisted_direction not in (BUY, SELL)
        or state.persisted_day_key != state.opened_day_key
        or not state.has_stop
        or state.now_hhmm >= 1045
        or state.elapsed_minutes >= 20
    )


class WtiEiaLag2FadeReferenceTests(unittest.TestCase):
    def test_strict_opposite_sign(self) -> None:
        self.assertEqual(fade_direction(70.0, 69.5), BUY)
        self.assertEqual(fade_direction(70.0, 70.5), SELL)
        self.assertEqual(fade_direction(70.0, 70.0), 0)

    def test_only_standard_wednesday_first_thirty_seconds(self) -> None:
        self.assertTrue(event_window(datetime(2026, 9, 2, 10, 35, 29)))
        self.assertFalse(event_window(datetime(2026, 9, 2, 10, 35, 30)))
        self.assertFalse(event_window(datetime(2026, 9, 3, 10, 35, 1)))

    def test_completed_release_bar_is_exactly_five_minutes_older(self) -> None:
        decision = datetime(2026, 9, 2, 10, 35)
        self.assertTrue(completed_bar_matches(decision, datetime(2026, 9, 2, 10, 30)))
        self.assertFalse(completed_bar_matches(decision, datetime(2026, 9, 2, 10, 29)))

    def test_zero_spread_is_valid_but_crossed_quote_is_not(self) -> None:
        self.assertTrue(quote_allowed(70.0, 70.0, 0.01))
        self.assertTrue(quote_allowed(70.0, 70.15, 0.01))
        self.assertFalse(quote_allowed(70.01, 70.0, 0.01))
        self.assertFalse(quote_allowed(70.0, 85.01, 0.01))

    def test_direction_state_encoding_is_signed_day_key(self) -> None:
        self.assertEqual(encode_direction(20260902, BUY), 20260902)
        self.assertEqual(encode_direction(20260902, SELL), -20260902)
        with self.assertRaises(ValueError):
            encode_direction(20260902, 0)

    def test_valid_position_survives_before_flat_clock(self) -> None:
        state = PositionState(1, True, BUY, 20260902, BUY, 20260902, True, 1044, 9)
        self.assertFalse(must_repair(state))

    def test_wrong_direction_stopless_and_timed_positions_are_repaired(self) -> None:
        base = dict(
            magic_count=1,
            symbol_ok=True,
            position_direction=BUY,
            persisted_day_key=20260902,
            persisted_direction=BUY,
            opened_day_key=20260902,
            has_stop=True,
            now_hhmm=1044,
            elapsed_minutes=9,
        )
        self.assertTrue(must_repair(PositionState(**{**base, "position_direction": SELL})))
        self.assertTrue(must_repair(PositionState(**{**base, "has_stop": False})))
        self.assertTrue(must_repair(PositionState(**{**base, "now_hhmm": 1045})))
        self.assertTrue(must_repair(PositionState(**{**base, "elapsed_minutes": 20})))


if __name__ == "__main__":
    unittest.main()
