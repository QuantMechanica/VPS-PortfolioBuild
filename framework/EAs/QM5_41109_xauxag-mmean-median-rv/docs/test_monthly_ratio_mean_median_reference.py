"""Independent deterministic fixtures for QM5_41109's monthly basket rule."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def within_entry_grace(now: datetime, current_bar: datetime, minutes: int = 180) -> bool:
    elapsed = now - current_bar
    return timedelta(0) <= elapsed <= timedelta(minutes=minutes)


def decision_clock(
    now: datetime,
    xau_current: datetime,
    xag_current: datetime,
    newest_completed: datetime,
) -> tuple[bool, bool, int]:
    key = month_key(now)
    exact_current = (
        xau_current == xag_current
        and xau_current.date() == now.date()
        and month_key(xau_current) == key
    )
    if not exact_current:
        return False, False, key
    late = not within_entry_grace(now, xau_current) or month_key(newest_completed) == key
    return True, late, key


def make_month(year: int, month: int, ratios: list[float]) -> tuple[list[CloseBar], list[CloseBar]]:
    xau: list[CloseBar] = []
    xag: list[CloseBar] = []
    for day, ratio in enumerate(ratios, start=1):
        opened = datetime(year, month, day, tzinfo=UTC)
        silver = 25.0
        xau.append(CloseBar(opened, silver * math.exp(ratio)))
        xag.append(CloseBar(opened, silver))
    return list(reversed(xau)), list(reversed(xag))


def sample(
    ratios: list[float],
    completed_month: int = 7,
    older_month: int = 6,
) -> tuple[list[CloseBar], list[CloseBar]]:
    completed_xau, completed_xag = make_month(2026, completed_month, ratios)
    older_xau, older_xag = make_month(2026, older_month, [4.25])
    return completed_xau + older_xau, completed_xag + older_xag


def ordinary_median(values: list[float]) -> float:
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    return 0.5 * (ordered[middle - 1] + ordered[middle])


def monthly_ratio_mean_median(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
    minimum: int = 17,
    maximum: int = 23,
    history_bars: int = 40,
) -> tuple[bool, int, int, float, float]:
    """Mirror the bounded newest-first synchronized-close aggregation."""

    empty = (False, 0, 0, 0.0, 0.0)
    if current_month <= 0 or minimum > maximum or history_bars < maximum + 1:
        return empty
    available = min(len(xau_bars), len(xag_bars), history_bars)
    if available < minimum + 1 or xau_bars[0].opened != xag_bars[0].opened:
        return empty

    completed_key = month_key(xau_bars[0].opened)
    if month_key(xag_bars[0].opened) != completed_key or next_month_key(completed_key) != current_month:
        return empty

    ratios: list[float] = []
    index = 0
    while index < available and month_key(xau_bars[index].opened) == completed_key:
        xau, xag = xau_bars[index], xag_bars[index]
        if (
            len(ratios) >= maximum
            or xau.opened != xag.opened
            or month_key(xag.opened) != completed_key
            or not all(math.isfinite(value) and value > 0.0 for value in (xau.close, xag.close))
            or index > 0
            and (
                xau_bars[index - 1].opened <= xau.opened
                or xag_bars[index - 1].opened <= xag.opened
            )
        ):
            return empty
        ratios.append(math.log(xau.close) - math.log(xag.close))
        index += 1

    if not minimum <= len(ratios) <= maximum or index >= available:
        return empty
    older_key = month_key(xau_bars[index].opened)
    if (
        xau_bars[index].opened != xag_bars[index].opened
        or month_key(xag_bars[index].opened) != older_key
        or next_month_key(older_key) != completed_key
        or xau_bars[index - 1].opened <= xau_bars[index].opened
        or xag_bars[index - 1].opened <= xag_bars[index].opened
    ):
        return empty

    arithmetic_mean = sum(ratios) / len(ratios)
    median = ordinary_median(ratios)
    if not all(math.isfinite(value) for value in (arithmetic_mean, median)):
        return empty
    direction = -1 if arithmetic_mean > median else 1 if arithmetic_mean < median else 0
    return True, direction, len(ratios), arithmetic_mean, median


def round_down(value: float, step: float, minimum: float) -> float:
    rounded = math.floor((value + 1e-12) / step) * step
    return rounded if rounded + 1e-12 >= minimum else 0.0


def equal_notional_package(
    full_xau_lots: float,
    full_xag_lots: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
) -> tuple[float, float, float, float]:
    lot_ratio = xag_notional_per_lot / xau_notional_per_lot
    normalized_per_xag_lot = lot_ratio / full_xau_lots + 1.0 / full_xag_lots
    xag_lots = round_down(1.0 / normalized_per_xag_lot, 0.01, 0.01)
    xau_lots = round_down(lot_ratio / normalized_per_xag_lot, 0.01, 0.01)
    risk = xau_lots / full_xau_lots + xag_lots / full_xag_lots
    notional_ratio = xau_lots * xau_notional_per_lot / (xag_lots * xag_notional_per_lot)
    return xau_lots, xag_lots, risk, notional_ratio


class AttemptLedger:
    def __init__(self) -> None:
        self.month = 0

    def consume(self, month: int) -> bool:
        if month <= 0 or month == self.month:
            return False
        self.month = month
        return True


class MonthlyRatioMeanMedianReferenceTest(unittest.TestCase):
    def signal(self, ratios: list[float], **kwargs):
        xau, xag = sample(ratios, **kwargs)
        return monthly_ratio_mean_median(202608, xau, xag)

    def test_positive_tail_bias_is_faded_short_xau(self) -> None:
        valid, direction, count, mean, median = self.signal([4.5] * 16 + [5.5])
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertEqual(count, 17)
        self.assertGreater(mean, median)

    def test_negative_tail_bias_is_faded_long_xau(self) -> None:
        valid, direction, _, mean, median = self.signal([3.5] + [4.5] * 16)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(mean, median)

    def test_exact_equality_is_flat(self) -> None:
        valid, direction, _, mean, median = self.signal([4.5] * 17)
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertEqual(mean, median)

    def test_odd_and_even_medians_use_the_ordinary_definition(self) -> None:
        odd = [4.0] * 8 + [4.5] + [5.0] * 8
        even = [4.0] * 10 + [5.0] * 10
        self.assertAlmostEqual(self.signal(odd)[4], 4.5)
        self.assertAlmostEqual(self.signal(even)[4], 4.5)

    def test_session_bounds_are_exact(self) -> None:
        for count in (17, 20, 23):
            valid, _, observed, _, _ = self.signal([4.5] * (count - 1) + [5.0])
            self.assertTrue(valid)
            self.assertEqual(observed, count)
        for count in (16, 24):
            self.assertFalse(self.signal([4.5] * (count - 1) + [5.0])[0])

    def test_asynchronous_and_non_descending_timestamps_are_rejected(self) -> None:
        xau, xag = sample([4.5] * 16 + [5.0])
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_ratio_mean_median(202608, xau, xag)[0])

        xau, xag = sample([4.5] * 16 + [5.0])
        xau[2] = CloseBar(xau[1].opened, xau[2].close)
        xag[2] = CloseBar(xag[1].opened, xag[2].close)
        self.assertFalse(monthly_ratio_mean_median(202608, xau, xag)[0])

    def test_invalid_close_and_current_month_leak_are_rejected(self) -> None:
        xau, xag = sample([4.5] * 16 + [5.0])
        xau[3] = CloseBar(xau[3].opened, float("nan"))
        self.assertFalse(monthly_ratio_mean_median(202608, xau, xag)[0])

        xau, xag = sample([4.5] * 16 + [5.0])
        xau.insert(0, CloseBar(datetime(2026, 8, 1, tzinfo=UTC), 2500.0))
        xag.insert(0, CloseBar(datetime(2026, 8, 1, tzinfo=UTC), 25.0))
        self.assertFalse(monthly_ratio_mean_median(202608, xau, xag)[0])

    def test_older_boundary_is_visible_and_consecutive(self) -> None:
        xau, xag = sample([4.5] * 16 + [5.0])
        self.assertFalse(monthly_ratio_mean_median(202608, xau[:-1], xag[:-1])[0])
        self.assertFalse(self.signal([4.5] * 16 + [5.0], older_month=5)[0])

    def test_exact_month_clock_grace_and_attempt_are_one_shot(self) -> None:
        current = datetime(2026, 8, 3, tzinfo=UTC)
        now = current + timedelta(minutes=180)
        completed = datetime(2026, 7, 31, tzinfo=UTC)
        self.assertEqual(decision_clock(now, current, current, completed), (True, False, 202608))
        self.assertTrue(decision_clock(now + timedelta(minutes=1), current, current, completed)[1])
        self.assertFalse(decision_clock(now, current, current + timedelta(hours=1), completed)[0])
        ledger = AttemptLedger()
        self.assertTrue(ledger.consume(202608))
        self.assertFalse(ledger.consume(202608))

    def test_year_boundary_month_lifecycle_and_joint_sizing(self) -> None:
        self.assertEqual(next_month_key(202612), 202701)
        opened = datetime(2026, 8, 3, tzinfo=UTC)
        self.assertEqual(month_key(opened), month_key(datetime(2026, 8, 31, tzinfo=UTC)))
        self.assertNotEqual(month_key(opened), month_key(datetime(2026, 9, 1, tzinfo=UTC)))
        xau, xag, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41109_xauxag-mmean-median-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41109_xauxag-mmean-median-rv_QM5_41109_XAU_XAG_MMEAN_MEDIAN_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = (EA_DIR / "basket_manifest.json").read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                    = 41109;",
            "CopyRates(g_leg_xau",
            "PERIOD_D1, 1, strategy_history_bars_d1",
            "MathLog(xau_bar.close) - MathLog(xag_bar.close)",
            "ratio_sum += ratio;",
            "arithmetic_mean = ratio_sum / (double)completed_month_sessions;",
            "ArraySort(values);",
            "median = 0.5 * (values[middle - 1] + values[middle]);",
            "if(arithmetic_mean > ordinary_median)",
            "direction = -1;",
            "else if(arithmetic_mean < ordinary_median)",
            "direction = 1;",
            "QM_ATR(g_leg_xau, PERIOD_D1, strategy_atr_period_d1, 1)",
            "request.tp = 0.0;",
            "strategy_notional_ratio",
        ):
            self.assertIn(marker, source)
        for banned in ("iRSI(", "iMACD(", "iBands(", "WebRequest("):
            self.assertNotIn(banned, source)
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntrySignal(request)"),
        )
        for marker in (
            "qm_ea_id=41109",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=40",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertIn('"logical_symbol": "QM5_41109_XAU_XAG_MMEAN_MEDIAN_RV_D1"', manifest)

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41109_xauxag-mmean-median-rv_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())


if __name__ == "__main__":
    unittest.main()
