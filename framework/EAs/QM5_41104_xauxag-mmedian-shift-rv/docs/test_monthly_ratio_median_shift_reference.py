"""Independent deterministic fixtures for QM5_41104's monthly basket rule."""

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


def centered_levels(center: float, count: int, step: float = 0.01) -> list[float]:
    midpoint = (count - 1) / 2.0
    return [center + (index - midpoint) * step for index in range(count)]


def sample(
    new_center: float = 4.70,
    parent_center: float = 4.50,
    new_count: int = 20,
    parent_count: int = 20,
    new_step: float = 0.01,
    parent_step: float = 0.01,
    new_ratios: list[float] | None = None,
    parent_ratios: list[float] | None = None,
    parent_month: int = 6,
) -> tuple[list[CloseBar], list[CloseBar]]:
    newest = new_ratios or centered_levels(new_center, new_count, new_step)
    parent = parent_ratios or centered_levels(parent_center, parent_count, parent_step)
    new_xau, new_xag = make_month(2026, 7, newest)
    parent_xau, parent_xag = make_month(2026, parent_month, parent)
    older_xau, older_xag = make_month(2026, parent_month - 1, [4.40])
    return new_xau + parent_xau + older_xau, new_xag + parent_xag + older_xag


def ordinary_median(values: list[float]) -> float:
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    return 0.5 * (ordered[middle - 1] + ordered[middle])


def monthly_ratio_medians(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
    minimum: int = 17,
    maximum: int = 23,
    history_bars: int = 70,
) -> tuple[bool, int, tuple[int, int], tuple[float, float]]:
    """Mirror the bounded newest-first synchronized-close aggregation."""

    empty = (False, 0, (0, 0), (0.0, 0.0))
    if current_month <= 0 or minimum > maximum or history_bars < 2 * maximum:
        return empty
    available = min(len(xau_bars), len(xag_bars), history_bars)
    if available < 2 * minimum:
        return empty
    if xau_bars[0].opened != xag_bars[0].opened:
        return empty
    newest_key = month_key(xau_bars[0].opened)
    if month_key(xag_bars[0].opened) != newest_key or next_month_key(newest_key) != current_month:
        return empty

    buckets: list[list[float]] = [[], []]
    index = 0
    while index < available and month_key(xau_bars[index].opened) == newest_key:
        xau, xag = xau_bars[index], xag_bars[index]
        if (
            len(buckets[0]) >= maximum
            or xau.opened != xag.opened
            or month_key(xag.opened) != newest_key
            or not all(math.isfinite(value) and value > 0.0 for value in (xau.close, xag.close))
            or index > 0
            and (
                xau_bars[index - 1].opened <= xau.opened
                or xag_bars[index - 1].opened <= xag.opened
            )
        ):
            return empty
        buckets[0].append(math.log(xau.close) - math.log(xag.close))
        index += 1

    if not minimum <= len(buckets[0]) <= maximum or index >= available:
        return empty
    parent_key = month_key(xau_bars[index].opened)
    if (
        xau_bars[index].opened != xag_bars[index].opened
        or month_key(xag_bars[index].opened) != parent_key
        or next_month_key(parent_key) != newest_key
    ):
        return empty

    while index < available and month_key(xau_bars[index].opened) == parent_key:
        xau, xag = xau_bars[index], xag_bars[index]
        if (
            len(buckets[1]) >= maximum
            or xau.opened != xag.opened
            or month_key(xag.opened) != parent_key
            or not all(math.isfinite(value) and value > 0.0 for value in (xau.close, xag.close))
            or xau_bars[index - 1].opened <= xau.opened
            or xag_bars[index - 1].opened <= xag.opened
        ):
            return empty
        buckets[1].append(math.log(xau.close) - math.log(xag.close))
        index += 1

    if not minimum <= len(buckets[1]) <= maximum or index >= available:
        return empty
    older_key = month_key(xau_bars[index].opened)
    if (
        xau_bars[index].opened != xag_bars[index].opened
        or month_key(xag_bars[index].opened) != older_key
        or next_month_key(older_key) != parent_key
        or xau_bars[index - 1].opened <= xau_bars[index].opened
        or xag_bars[index - 1].opened <= xag_bars[index].opened
    ):
        return empty

    newest_median = ordinary_median(buckets[0])
    parent_median = ordinary_median(buckets[1])
    if not all(math.isfinite(value) for value in (newest_median, parent_median)):
        return empty
    direction = -1 if newest_median > parent_median else 1 if newest_median < parent_median else 0
    return True, direction, (len(buckets[0]), len(buckets[1])), (
        newest_median,
        parent_median,
    )


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


class MonthlyRatioMedianShiftReferenceTest(unittest.TestCase):
    def signal(self, **kwargs):
        xau, xag = sample(**kwargs)
        return monthly_ratio_medians(202608, xau, xag)

    def test_upward_median_shift_is_faded_short_xau(self) -> None:
        valid, direction, counts, medians = self.signal()
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertEqual(counts, (20, 20))
        self.assertAlmostEqual(medians[0], 4.70)
        self.assertAlmostEqual(medians[1], 4.50)

    def test_downward_median_shift_is_faded_long_xau(self) -> None:
        valid, direction, _, medians = self.signal(new_center=4.30, parent_center=4.50)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(medians[0], medians[1])

    def test_odd_and_even_sample_medians_are_exact(self) -> None:
        for new_count, parent_count in ((17, 19), (20, 22), (19, 20), (22, 17)):
            valid, _, counts, medians = self.signal(
                new_count=new_count,
                parent_count=parent_count,
            )
            self.assertTrue(valid)
            self.assertEqual(counts, (new_count, parent_count))
            self.assertAlmostEqual(medians[0], 4.70)
            self.assertAlmostEqual(medians[1], 4.50)

    def test_equal_medians_are_flat_even_with_different_ranges(self) -> None:
        valid, direction, _, medians = self.signal(
            new_ratios=[4.0] + [4.5] * 15 + [5.0],
            parent_ratios=[3.0] + [4.5] * 15 + [6.0],
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 0)
        self.assertAlmostEqual(medians[0], medians[1])

    def test_median_shift_signals_when_range_endpoints_are_mixed(self) -> None:
        valid, direction, _, medians = self.signal(
            new_ratios=[4.0] + [4.8] * 15 + [5.0],
            parent_ratios=[4.2] + [4.6] * 15 + [5.4],
        )
        self.assertTrue(valid)
        self.assertGreater(medians[0], medians[1])
        self.assertEqual(direction, -1)

    def test_session_bounds_are_exact(self) -> None:
        for new_count, parent_count in ((17, 17), (23, 23), (17, 23), (23, 17)):
            valid, _, counts, _ = self.signal(new_count=new_count, parent_count=parent_count)
            self.assertTrue(valid)
            self.assertEqual(counts, (new_count, parent_count))
        for new_count, parent_count in ((16, 20), (20, 16), (24, 20), (20, 24)):
            self.assertFalse(self.signal(new_count=new_count, parent_count=parent_count)[0])

    def test_asynchronous_and_non_descending_timestamps_are_rejected(self) -> None:
        xau, xag = sample()
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_ratio_medians(202608, xau, xag)[0])

        xau, xag = sample()
        xau[2] = CloseBar(xau[1].opened, xau[2].close)
        xag[2] = CloseBar(xag[1].opened, xag[2].close)
        self.assertFalse(monthly_ratio_medians(202608, xau, xag)[0])

    def test_invalid_close_is_rejected_but_zero_dispersion_is_valid(self) -> None:
        xau, xag = sample()
        xau[3] = CloseBar(xau[3].opened, float("nan"))
        self.assertFalse(monthly_ratio_medians(202608, xau, xag)[0])

        valid, direction, _, medians = self.signal(new_step=0.0, parent_step=0.0)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(medians[0], medians[1])

    def test_current_month_leak_and_nonconsecutive_parent_are_rejected(self) -> None:
        xau, xag = sample()
        xau.insert(0, CloseBar(datetime(2026, 8, 1, tzinfo=UTC), 2500.0))
        xag.insert(0, CloseBar(datetime(2026, 8, 1, tzinfo=UTC), 25.0))
        self.assertFalse(monthly_ratio_medians(202608, xau, xag)[0])
        self.assertFalse(self.signal(parent_month=5)[0])

    def test_parent_must_have_a_visible_older_boundary(self) -> None:
        xau, xag = sample()
        self.assertFalse(monthly_ratio_medians(202608, xau[:-1], xag[:-1])[0])

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

    def test_year_boundary_and_month_lifecycle(self) -> None:
        self.assertEqual(next_month_key(202612), 202701)
        opened = datetime(2026, 8, 3, tzinfo=UTC)
        same_month = datetime(2026, 8, 31, tzinfo=UTC)
        next_month = datetime(2026, 9, 1, tzinfo=UTC)
        self.assertEqual(month_key(opened), month_key(same_month))
        self.assertNotEqual(month_key(opened), month_key(next_month))
        self.assertLess(same_month - opened, timedelta(days=40))
        self.assertGreaterEqual(opened + timedelta(days=40) - opened, timedelta(days=40))

    def test_joint_sizing_caps_risk_and_targets_equal_notional(self) -> None:
        xau, xag, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41104_xauxag-mmedian-shift-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41104_xauxag-mmedian-shift-rv_QM5_41104_XAU_XAG_MMEDIAN_SHIFT_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = (EA_DIR / "basket_manifest.json").read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                    = 41104;",
            "CopyRates(g_leg_xau",
            "PERIOD_D1, 1, strategy_history_bars_d1",
            "MathLog(xau_bar.close) - MathLog(xag_bar.close)",
            "double new_ratios[];",
            "ArraySort(values);",
            "median = 0.5 * (values[middle - 1] + values[middle]);",
            "if(new_median > parent_median)",
            "direction = -1;",
            "else if(new_median < parent_median)",
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
            "qm_ea_id=41104",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=70",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertIn('"logical_symbol": "QM5_41104_XAU_XAG_MMEDIAN_SHIFT_RV_D1"', manifest)

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41104_xauxag-mmedian-shift-rv_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())


if __name__ == "__main__":
    unittest.main()
