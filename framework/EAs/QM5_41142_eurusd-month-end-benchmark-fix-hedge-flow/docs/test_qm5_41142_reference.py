from __future__ import annotations

import calendar
import datetime as dt
import unittest
from zoneinfo import ZoneInfo


LONDON = ZoneInfo("Europe/London")
UK_HOLIDAYS = {
    dt.date(2021, 12, 27),
    dt.date(2021, 12, 28),
    dt.date(2021, 12, 31),
    dt.date(2024, 12, 25),
    dt.date(2024, 12, 26),
}


def is_last_business_day(day: dt.date, holidays: set[dt.date]) -> bool:
    if day.weekday() >= 5 or day in holidays:
        return False
    final = calendar.monthrange(day.year, day.month)[1]
    for number in range(day.day + 1, final + 1):
        candidate = day.replace(day=number)
        if candidate.weekday() < 5 and candidate not in holidays:
            return False
    return True


def direction(gdaxi_mtd_return: float) -> str | None:
    if gdaxi_mtd_return > 0:
        return "SELL"
    if gdaxi_mtd_return < 0:
        return "BUY"
    return None


class Qm541142ReferenceTests(unittest.TestCase):
    def test_weekend_month_end_uses_prior_friday(self) -> None:
        self.assertTrue(is_last_business_day(dt.date(2024, 8, 30), UK_HOLIDAYS))
        self.assertFalse(is_last_business_day(dt.date(2024, 8, 29), UK_HOLIDAYS))

    def test_observed_new_year_holiday_moves_2021_month_end(self) -> None:
        self.assertTrue(is_last_business_day(dt.date(2021, 12, 30), UK_HOLIDAYS))
        self.assertFalse(is_last_business_day(dt.date(2021, 12, 31), UK_HOLIDAYS))

    def test_direction_is_card_literal(self) -> None:
        self.assertEqual(direction(0.012), "SELL")
        self.assertEqual(direction(-0.004), "BUY")
        self.assertIsNone(direction(0.0))

    def test_london_entry_and_fix_convert_across_dst(self) -> None:
        winter_entry = dt.datetime(2024, 1, 31, 14, tzinfo=LONDON)
        summer_entry = dt.datetime(2024, 7, 31, 14, tzinfo=LONDON)
        self.assertEqual(winter_entry.astimezone(dt.UTC).hour, 14)
        self.assertEqual(summer_entry.astimezone(dt.UTC).hour, 13)
        self.assertEqual(
            (winter_entry.replace(hour=16) - winter_entry).total_seconds(), 7200
        )
        self.assertEqual(
            (summer_entry.replace(hour=16) - summer_entry).total_seconds(), 7200
        )

    def test_signal_anchor_is_bar_ending_at_1400_london(self) -> None:
        signal_bar_open = dt.datetime(2024, 7, 31, 13, 45, tzinfo=LONDON)
        self.assertEqual(signal_bar_open + dt.timedelta(minutes=15),
                         dt.datetime(2024, 7, 31, 14, 0, tzinfo=LONDON))


if __name__ == "__main__":
    unittest.main()
