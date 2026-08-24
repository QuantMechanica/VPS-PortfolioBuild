"""Independent deterministic fixtures for QM5_41139's daily pseudomedian."""

from __future__ import annotations

import math
import random
import unittest
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
MIN_SESSIONS = 17
MAX_SESSIONS = 23
MAX_PAIR_COUNT = 276
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class Signal:
    count: int
    returns: tuple[float, ...]
    pair_count: int
    sorted_pairwise: tuple[float, ...]
    center_low: float
    center_high: float
    pseudomedian: float
    raw_sum: float
    endpoint_return: float
    direction: int


def previous_month(month: tuple[int, int]) -> tuple[int, int]:
    year, number = month
    return (year - 1, 12) if number == 1 else (year, number - 1)


def choose_label_offset(raw_label: date, broker_date: date) -> timedelta:
    if raw_label == broker_date:
        return timedelta(0)
    if raw_label + timedelta(days=1) == broker_date:
        return timedelta(days=1)
    raise ValueError("unsupported label offset")


def normalize_package(
    raw_current: date,
    broker_date: date,
    raw_history_newest_first: list[date],
) -> tuple[date, list[date]]:
    offset = choose_label_offset(raw_current, broker_date)
    normalized_current = raw_current + offset
    normalized = [label + offset for label in raw_history_newest_first]
    if any(
        normalized[index - 1] <= normalized[index]
        for index in range(1, len(normalized))
    ):
        raise ValueError("mixed convention, collision, or non-decreasing history")
    return normalized_current, normalized


def extract_completed_month(
    normalized_history_newest_first: list[date],
    current_month: tuple[int, int],
) -> tuple[list[date], date]:
    if not normalized_history_newest_first:
        raise ValueError("history")
    expected = previous_month(current_month)
    selected: list[date] = []
    boundary: date | None = None
    for label in normalized_history_newest_first:
        if label.weekday() >= 5:
            raise ValueError("weekend ending label")
        label_month = (label.year, label.month)
        if label_month == current_month:
            raise ValueError("current-month leakage")
        if not selected:
            if label_month != expected:
                raise ValueError("not immediately completed month")
            selected.append(label)
        elif label_month == expected:
            selected.append(label)
        else:
            if label_month != previous_month(expected):
                raise ValueError("non-adjacent boundary")
            boundary = label
            break
    if not MIN_SESSIONS <= len(selected) <= MAX_SESSIONS or boundary is None:
        raise ValueError("session count or boundary")
    return list(reversed(selected)), boundary


def business_days(start: date, count: int) -> list[date]:
    labels: list[date] = []
    cursor = start
    while len(labels) < count:
        if cursor.weekday() < 5:
            labels.append(cursor)
        cursor += timedelta(days=1)
    return labels


def self_pair_index(count: int, observation: int) -> int:
    return sum(count - prior for prior in range(observation))


def classify_daily_returns(
    returns: list[float], endpoint_return: float | None = None
) -> Signal:
    if not MIN_SESSIONS <= len(returns) <= MAX_SESSIONS:
        raise ValueError("session count")
    if not all(math.isfinite(value) for value in returns):
        raise ValueError("return validity")

    pairwise = tuple(
        (returns[left] + returns[right]) / 2.0
        for left in range(len(returns))
        for right in range(left, len(returns))
    )
    pair_count = len(returns) * (len(returns) + 1) // 2
    if len(pairwise) != pair_count or not 153 <= pair_count <= MAX_PAIR_COUNT:
        raise ValueError("pair count")
    for index, value in enumerate(returns):
        if not math.isclose(
            pairwise[self_pair_index(len(returns), index)],
            value,
            rel_tol=0.0,
            abs_tol=TOLERANCE,
        ):
            raise ValueError("self-pair identity")

    ordered = tuple(sorted(pairwise))
    if not all(math.isfinite(value) for value in ordered):
        raise ValueError("pair validity")
    left_index = (pair_count - 1) // 2
    right_index = pair_count // 2
    center_low = ordered[left_index]
    center_high = ordered[right_index]
    pseudomedian = (
        center_low
        if left_index == right_index
        else (center_low + center_high) / 2.0
    )
    if not all(
        math.isfinite(value) for value in (center_low, center_high, pseudomedian)
    ):
        raise ValueError("pseudomedian validity")

    raw_sum = sum(returns)
    endpoint = raw_sum if endpoint_return is None else endpoint_return
    if not math.isfinite(raw_sum) or not math.isfinite(endpoint):
        raise ValueError("sum validity")
    if abs(raw_sum - endpoint) > TOLERANCE:
        raise ValueError("endpoint identity")
    direction = 1 if pseudomedian > 0.0 else -1 if pseudomedian < 0.0 else 0
    return Signal(
        count=len(returns),
        returns=tuple(returns),
        pair_count=pair_count,
        sorted_pairwise=ordered,
        center_low=center_low,
        center_high=center_high,
        pseudomedian=pseudomedian,
        raw_sum=raw_sum,
        endpoint_return=endpoint,
        direction=direction,
    )


def signal_from_closes(boundary_close: float, month_closes: list[float]) -> Signal:
    prices = [boundary_close, *month_closes]
    if not all(value > 0.0 and math.isfinite(value) for value in prices):
        raise ValueError("prices")
    returns = [
        math.log(prices[index + 1]) - math.log(prices[index])
        for index in range(len(prices) - 1)
    ]
    endpoint = math.log(prices[-1]) - math.log(prices[0])
    return classify_daily_returns(returns, endpoint)


def within_raw_bar_grace(raw_bar_open: datetime, broker_now: datetime) -> bool:
    elapsed = broker_now - raw_bar_open
    return timedelta(0) <= elapsed <= timedelta(minutes=180)


def lifecycle_close(
    entry_time: datetime,
    broker_now: datetime,
    normalized_current_month: tuple[int, int],
    position_valid: bool = True,
) -> bool:
    if not position_valid or entry_time > broker_now:
        return True
    if (entry_time.year, entry_time.month) != normalized_current_month:
        return True
    return broker_now - entry_time >= timedelta(days=40)


def aggregate_risk_lots(
    risk_fixed: float, stop_risk_per_lot: float, lot_step: float
) -> float:
    if risk_fixed <= 0.0 or stop_risk_per_lot <= 0.0 or lot_step <= 0.0:
        raise ValueError("risk inputs")
    raw = risk_fixed / stop_risk_per_lot
    return math.floor((raw + 1.0e-12) / lot_step) * lot_step


class AttemptLedger:
    def __init__(self) -> None:
        self.month: int | None = None

    def consume_before(self, month: int, downstream_gate: bool) -> bool:
        if self.month == month:
            return False
        self.month = month
        return downstream_gate


class MonthlyDailyHodgesLehmannReferenceTests(unittest.TestCase):
    def test_positive_negative_and_zero_pseudomedians_follow_sign(self) -> None:
        positive = classify_daily_returns([0.01] * 17)
        negative = classify_daily_returns([-0.01] * 17)
        zero = classify_daily_returns([0.0] * 17)
        self.assertEqual(
            (positive.direction, negative.direction, zero.direction), (1, -1, 0)
        )

    def test_exact_dynamic_pair_counts_and_odd_even_centers(self) -> None:
        for count in range(MIN_SESSIONS, MAX_SESSIONS + 1):
            returns = [0.001 * (index - count / 3.0) for index in range(count)]
            signal = classify_daily_returns(returns)
            expected = tuple(
                sorted(
                    (returns[left] + returns[right]) / 2.0
                    for left in range(count)
                    for right in range(left, count)
                )
            )
            expected_count = count * (count + 1) // 2
            left_index = (expected_count - 1) // 2
            right_index = expected_count // 2
            self.assertEqual(signal.pair_count, expected_count)
            self.assertEqual(signal.sorted_pairwise, expected)
            self.assertEqual(signal.center_low, expected[left_index])
            self.assertEqual(signal.center_high, expected[right_index])

    def test_every_return_has_exactly_one_inclusive_self_pair(self) -> None:
        returns = [0.001 * value for value in range(-8, 9)]
        signal = classify_daily_returns(returns)
        unsorted = tuple(
            (returns[left] + returns[right]) / 2.0
            for left in range(len(returns))
            for right in range(left, len(returns))
        )
        for index, value in enumerate(returns):
            self.assertEqual(unsorted[self_pair_index(len(returns), index)], value)
        self.assertEqual(signal.pair_count, 153)

    def test_pairwise_functional_differs_from_raw_sample_median(self) -> None:
        returns = [-1.0] * 8 + [0.01] * 9
        signal = classify_daily_returns(returns)
        ordinary_median = sorted(returns)[len(returns) // 2]
        self.assertGreater(ordinary_median, 0.0)
        self.assertLess(signal.pseudomedian, 0.0)
        self.assertEqual(signal.direction, -1)

    def test_raw_endpoint_cannot_override_pseudomedian(self) -> None:
        long_signal = classify_daily_returns([-1.0] * 4 + [0.01] * 16)
        short_signal = classify_daily_returns([1.0] * 4 + [-0.01] * 16)
        self.assertLess(long_signal.raw_sum, 0.0)
        self.assertGreater(long_signal.pseudomedian, 0.0)
        self.assertEqual(long_signal.direction, 1)
        self.assertGreater(short_signal.raw_sum, 0.0)
        self.assertLess(short_signal.pseudomedian, 0.0)
        self.assertEqual(short_signal.direction, -1)

    def test_pairwise_location_is_order_invariant(self) -> None:
        returns = [-0.5, 0.8, *[0.001 * index for index in range(-9, 9)]]
        shuffled = list(returns)
        random.Random(41139).shuffle(shuffled)
        original = classify_daily_returns(returns)
        permuted = classify_daily_returns(shuffled)
        self.assertEqual(original.sorted_pairwise, permuted.sorted_pairwise)
        self.assertEqual(original.pseudomedian, permuted.pseudomedian)
        self.assertEqual(original.direction, permuted.direction)

    def test_session_bounds_nonfinite_and_endpoint_mismatch_fail(self) -> None:
        for count in (17, 20, 23):
            self.assertEqual(classify_daily_returns([0.001] * count).count, count)
        for count in (16, 24):
            with self.assertRaisesRegex(ValueError, "session count"):
                classify_daily_returns([0.001] * count)
        with self.assertRaisesRegex(ValueError, "return validity"):
            classify_daily_returns([0.001] * 16 + [math.nan])
        with self.assertRaisesRegex(ValueError, "endpoint identity"):
            classify_daily_returns([0.001] * 20, endpoint_return=0.02 + 2.0e-10)

    def test_close_path_preserves_endpoint(self) -> None:
        increments = [-1.0] * 4 + [0.01] * 16
        closes: list[float] = []
        price = 80.0
        for increment in increments:
            price *= math.exp(increment)
            closes.append(price)
        signal = signal_from_closes(80.0, closes)
        self.assertAlmostEqual(signal.raw_sum, math.log(closes[-1] / 80.0), places=12)
        self.assertEqual(signal.direction, 1)

    def test_immediately_completed_month_and_boundary_across_year(self) -> None:
        december = business_days(date(2025, 12, 1), 23)
        history = list(reversed(december)) + [date(2025, 11, 28)]
        selected, boundary = extract_completed_month(history, (2026, 1))
        self.assertEqual(len(selected), 23)
        self.assertEqual((selected[0].year, selected[0].month), (2025, 12))
        self.assertEqual((boundary.year, boundary.month), (2025, 11))

    def test_leakage_missing_boundary_and_weekend_fail(self) -> None:
        valid = business_days(date(2026, 7, 1), 20)
        with self.assertRaisesRegex(ValueError, "current-month leakage"):
            extract_completed_month([date(2026, 8, 3), *reversed(valid)], (2026, 8))
        with self.assertRaisesRegex(ValueError, "boundary"):
            extract_completed_month(list(reversed(valid)), (2026, 8))
        weekend = list(reversed(valid)) + [date(2026, 6, 27)]
        with self.assertRaisesRegex(ValueError, "weekend"):
            extract_completed_month(weekend, (2026, 8))

    def test_zero_and_plus_one_label_conventions_match(self) -> None:
        labels = [date(2026, 6, 30), *business_days(date(2026, 7, 1), 20)]
        zero_current, zero_history = normalize_package(
            date(2026, 8, 3), date(2026, 8, 3), list(reversed(labels))
        )
        lag_current, lag_history = normalize_package(
            date(2026, 8, 2),
            date(2026, 8, 3),
            [label - timedelta(days=1) for label in reversed(labels)],
        )
        self.assertEqual(zero_current, lag_current)
        self.assertEqual(zero_history, lag_history)

    def test_clock_attempt_lifecycle_and_fixed_risk(self) -> None:
        opened = datetime(2026, 8, 3, 0, 0)
        self.assertTrue(within_raw_bar_grace(opened, opened + timedelta(minutes=180)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(minutes=181)))
        ledger = AttemptLedger()
        self.assertFalse(ledger.consume_before(202608, downstream_gate=False))
        self.assertFalse(ledger.consume_before(202608, downstream_gate=True))
        self.assertTrue(ledger.consume_before(202609, downstream_gate=True))
        entry = datetime(2026, 8, 3, 1, 0)
        self.assertFalse(lifecycle_close(entry, datetime(2026, 8, 20), (2026, 8)))
        self.assertTrue(lifecycle_close(entry, datetime(2026, 9, 1), (2026, 9)))
        self.assertTrue(lifecycle_close(entry, entry + timedelta(days=40), (2026, 8)))
        lots = aggregate_risk_lots(1000.0, 240.0, 0.01)
        self.assertLessEqual(lots * 240.0, 1000.0 + 1.0e-9)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41139_wti-mdaily-hl-mom.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41139_wti-mdaily-hl-mom_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                      = 41139;",
            "input int    strategy_max_pair_count       = 276;",
            "const int expected_pair_count =",
            "for(int right = left; right < return_count; ++right)",
            "pairwise_values[pair_index] = pair_average;",
            "MathAbs(pair_average - daily_returns[left])",
            "ArraySort(pairwise_values);",
            "const int center = pair_count / 2;",
            "if(daily_pseudomedian > 0.0)",
            "MathAbs(raw_sum - endpoint_return)",
            "req.tp = 0.0;",
            "strategy_atr_sl_mult);",
        ):
            self.assertIn(marker, source)
        for banned in ("irsi(", "imacd(", "ibands(", "webrequest("):
            self.assertNotIn(banned, source.lower())
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_PrepareDecisionSignal();"),
            on_tick.index("Strategy_NewsFilterHook(broker_now)"),
        )
        for marker in (
            "qm_ea_id=41139",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_max_pair_count=276",
            "strategy_numerical_tolerance=0.0000000001",
            "strategy_atr_sl_mult=3.5",
        ):
            self.assertIn(marker, setfile)

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41139_wti-mdaily-hl-mom_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(
            local.read_text(encoding="utf-8").rstrip(),
            approved.read_text(encoding="utf-8").rstrip(),
        )
        magic_rows = (
            REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
        ).read_text(encoding="utf-8-sig")
        self.assertIn(
            "41139,wti-mdaily-hl-mom,0,XTIUSD.DWX,411390000", magic_rows
        )
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("411390000", resolver)


if __name__ == "__main__":
    unittest.main()
