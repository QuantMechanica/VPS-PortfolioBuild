"""Independent mechanic fixtures for QM5_41200.

The suite covers native and prior-day energy-label normalization, genuine
month boundaries, entry day/attachment limits, a durable consumed attempt,
the day-16 exit across a weekend, malformed exposure, and the 20-day survivor
guard. It does not invoke MT5 or duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import unittest
from dataclasses import dataclass


DAY = dt.timedelta(days=1)


def normalized_session(
    label: dt.datetime, broker_now: dt.datetime
) -> tuple[dt.datetime, int] | None:
    elapsed = broker_now - label
    if dt.timedelta(0) <= elapsed < DAY:
        normalized = label
        offset = 0
    elif DAY <= elapsed < 2 * DAY:
        normalized = label + DAY
        offset = 1
    else:
        return None
    if normalized.date() != broker_now.date():
        return None
    return normalized, offset


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def next_month(month: int) -> int:
    year, number = divmod(month, 100)
    if number == 12:
        return (year + 1) * 100 + 1
    return year * 100 + number + 1


@dataclass(frozen=True)
class Boundary:
    month: int
    day: int
    offset_days: int
    attach_age: dt.timedelta


def detect_boundary(
    current_label: dt.datetime,
    previous_label: dt.datetime,
    broker_now: dt.datetime,
) -> Boundary | None:
    normalized = normalized_session(current_label, broker_now)
    if normalized is None:
        return None
    current, offset = normalized
    previous = previous_label + offset * DAY
    if current <= previous or next_month(month_key(previous)) != month_key(current):
        return None
    return Boundary(
        month=month_key(current),
        day=current.day,
        offset_days=offset,
        attach_age=broker_now - current,
    )


def entry_eligible(
    boundary: Boundary | None,
    latest_day: int = 5,
    maximum_age: dt.timedelta = dt.timedelta(minutes=180),
) -> bool:
    return bool(
        boundary
        and 1 <= boundary.day <= latest_day
        and dt.timedelta(0) <= boundary.attach_age <= maximum_age
    )


class AttemptBook:
    """Reference state: persistence happens before fallible execution gates."""

    def __init__(self) -> None:
        self.last_month: int | None = None

    def consume(self, month: int) -> bool:
        if self.last_month == month:
            return False
        self.last_month = month
        return True


@dataclass(frozen=True)
class Position:
    side: str
    opened: dt.datetime
    volume: float
    open_price: float
    stop_price: float


def ordinary_exit_due(
    opened: dt.datetime, current_session: dt.datetime, exit_day: int = 16
) -> bool:
    return current_session > opened and current_session.day >= exit_day


def malformed(position: Position, owned_count: int) -> bool:
    return bool(
        owned_count != 1
        or position.side != "SELL"
        or position.volume <= 0
        or position.open_price <= 0
        or position.stop_price <= position.open_price
    )


def stale_exit_due(
    opened: dt.datetime, current: dt.datetime, maximum_days: int = 20
) -> bool:
    return current - opened >= maximum_days * DAY


class WtiFirstHalfMonthReferenceTests(unittest.TestCase):
    def test_native_month_boundary_within_attachment_window(self) -> None:
        boundary = detect_boundary(
            dt.datetime(2026, 6, 1),
            dt.datetime(2026, 5, 29),
            dt.datetime(2026, 6, 1, 2, 59),
        )
        self.assertIsNotNone(boundary)
        self.assertEqual(boundary.offset_days if boundary else -1, 0)
        self.assertTrue(entry_eligible(boundary))

    def test_prior_day_energy_label_normalizes_uniformly(self) -> None:
        boundary = detect_boundary(
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 7, 30),
            dt.datetime(2026, 8, 1, 1),
        )
        self.assertIsNotNone(boundary)
        self.assertEqual(boundary.month if boundary else 0, 202608)
        self.assertEqual(boundary.offset_days if boundary else -1, 1)
        self.assertTrue(entry_eligible(boundary))

    def test_weekend_month_start_uses_first_available_session(self) -> None:
        boundary = detect_boundary(
            dt.datetime(2026, 8, 3),
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 8, 3, 2),
        )
        self.assertIsNotNone(boundary)
        self.assertEqual(boundary.day if boundary else 0, 3)
        self.assertTrue(entry_eligible(boundary))

    def test_mid_month_bar_is_not_a_boundary(self) -> None:
        self.assertIsNone(
            detect_boundary(
                dt.datetime(2026, 8, 11),
                dt.datetime(2026, 8, 10),
                dt.datetime(2026, 8, 11, 1),
            )
        )

    def test_invalid_third_day_label_convention_is_rejected(self) -> None:
        self.assertIsNone(
            detect_boundary(
                dt.datetime(2026, 7, 31),
                dt.datetime(2026, 7, 30),
                dt.datetime(2026, 8, 3, 1),
            )
        )

    def test_attachment_ceiling_is_inclusive_then_fails(self) -> None:
        at_ceiling = Boundary(202608, 1, 0, dt.timedelta(minutes=180))
        after_ceiling = Boundary(202608, 1, 0, dt.timedelta(minutes=181))
        self.assertTrue(entry_eligible(at_ceiling))
        self.assertFalse(entry_eligible(after_ceiling))

    def test_entry_day_ceiling_accepts_five_and_rejects_six(self) -> None:
        self.assertTrue(entry_eligible(Boundary(202608, 5, 0, dt.timedelta())))
        self.assertFalse(entry_eligible(Boundary(202608, 6, 0, dt.timedelta())))

    def test_failed_gate_consumes_month_without_retry(self) -> None:
        attempts = AttemptBook()
        self.assertTrue(attempts.consume(202608))
        # A spread/quote/ATR/order failure occurs after the first call.
        self.assertFalse(attempts.consume(202608))
        self.assertTrue(attempts.consume(202609))

    def test_day_sixteen_weekend_gap_exits_on_first_later_session(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertFalse(ordinary_exit_due(opened, dt.datetime(2026, 8, 14)))
        # The 16th is Sunday; Monday the 17th is the first observed D1 session.
        self.assertTrue(ordinary_exit_due(opened, dt.datetime(2026, 8, 17)))

    def test_only_one_well_formed_short_with_stop_is_valid(self) -> None:
        valid = Position("SELL", dt.datetime(2026, 8, 3), 1.0, 70.0, 75.0)
        wrong_side = Position("BUY", valid.opened, 1.0, 70.0, 65.0)
        no_stop = Position("SELL", valid.opened, 1.0, 70.0, 0.0)
        self.assertFalse(malformed(valid, 1))
        self.assertTrue(malformed(valid, 2))
        self.assertTrue(malformed(wrong_side, 1))
        self.assertTrue(malformed(no_stop, 1))

    def test_twenty_day_guard_repairs_only_survivor(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1)
        self.assertFalse(stale_exit_due(opened, opened + 20 * DAY - dt.timedelta(seconds=1)))
        self.assertTrue(stale_exit_due(opened, opened + 20 * DAY))


if __name__ == "__main__":
    unittest.main()
