"""Independent deterministic fixtures for QM5_41158's repeated median."""

from __future__ import annotations

import math
import statistics
import unittest
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
POINT_COUNT = 13
SLOPES_PER_PIVOT = 12
GROUPED_SLOPE_COUNT = 156


@dataclass(frozen=True)
class Signal:
    log_prices: tuple[float, ...]
    pivot_slopes: tuple[tuple[float, ...], ...]
    pivot_medians: tuple[float, ...]
    repeated_median: float
    direction: int


def next_month(month: tuple[int, int]) -> tuple[int, int]:
    year, number = month
    return (year + 1, 1) if number == 12 else (year, number + 1)


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
    raw_history_newest_first: list[tuple[date, float]],
) -> tuple[date, list[tuple[date, float]]]:
    offset = choose_label_offset(raw_current, broker_date)
    normalized_current = raw_current + offset
    normalized = [(label + offset, close) for label, close in raw_history_newest_first]
    if any(
        normalized[index - 1][0] <= normalized[index][0]
        for index in range(1, len(normalized))
    ):
        raise ValueError("mixed convention, collision, or non-decreasing history")
    return normalized_current, normalized


def extract_month_endpoints(
    normalized_history_newest_first: list[tuple[date, float]],
    current_month: tuple[int, int],
    broker_date: date,
) -> tuple[list[float], list[date]]:
    reverse: list[tuple[tuple[int, int], date, float]] = []
    history_started = False
    last_month: tuple[int, int] | None = None
    for label, close in normalized_history_newest_first:
        if not math.isfinite(close) or close <= 0.0:
            raise ValueError("close validity")
        month = (label.year, label.month)
        if month == current_month:
            if history_started:
                raise ValueError("current-month interleave")
            continue
        history_started = True
        if month != last_month:
            if not reverse:
                if next_month(month) != current_month:
                    raise ValueError("not immediately prior month")
            elif next_month(month) != last_month:
                raise ValueError("nonconsecutive month")
            reverse.append((month, label, close))
            last_month = month
            if len(reverse) == POINT_COUNT:
                break
    if len(reverse) != POINT_COUNT:
        raise ValueError("endpoint count")
    if broker_date - reverse[0][1] > timedelta(days=10):
        raise ValueError("stale newest endpoint")
    chronological = list(reversed(reverse))
    dates = [item[1] for item in chronological]
    closes = [item[2] for item in chronological]
    if any(dates[index] <= dates[index - 1] for index in range(1, len(dates))):
        raise ValueError("endpoint order")
    return closes, dates


def repeated_median_from_logs(log_prices: list[float]) -> Signal:
    if len(log_prices) != POINT_COUNT:
        raise ValueError("point count")
    if not all(math.isfinite(value) for value in log_prices):
        raise ValueError("log validity")

    groups: list[tuple[float, ...]] = []
    medians: list[float] = []
    for pivot in range(POINT_COUNT):
        slopes = []
        for other in range(POINT_COUNT):
            if other == pivot:
                continue
            lower, upper = sorted((pivot, other))
            distance = upper - lower
            slopes.append((log_prices[upper] - log_prices[lower]) / distance)
        if len(slopes) != SLOPES_PER_PIVOT:
            raise ValueError("pivot count")
        ordered = tuple(sorted(slopes))
        groups.append(ordered)
        medians.append((ordered[5] + ordered[6]) / 2.0)

    if sum(map(len, groups)) != GROUPED_SLOPE_COUNT or len(medians) != POINT_COUNT:
        raise ValueError("grouped count")
    ordered_medians = tuple(sorted(medians))
    center = ordered_medians[6]
    direction = 1 if center > 0.0 else -1 if center < 0.0 else 0
    return Signal(
        log_prices=tuple(log_prices),
        pivot_slopes=tuple(groups),
        pivot_medians=tuple(medians),
        repeated_median=center,
        direction=direction,
    )


def signal_from_closes(closes: list[float]) -> Signal:
    if len(closes) != POINT_COUNT or not all(
        value > 0.0 and math.isfinite(value) for value in closes
    ):
        raise ValueError("close package")
    return repeated_median_from_logs([math.log(value) for value in closes])


def theil_sen_from_logs(log_prices: list[float]) -> float:
    if len(log_prices) != POINT_COUNT:
        raise ValueError("point count")
    slopes = [
        (log_prices[right] - log_prices[left]) / (right - left)
        for left in range(POINT_COUNT)
        for right in range(left + 1, POINT_COUNT)
    ]
    if len(slopes) != 78:
        raise ValueError("Theil-Sen count")
    return statistics.median(slopes)


def month_sequence(end: tuple[int, int], count: int) -> list[tuple[int, int]]:
    months = [end]
    while len(months) < count:
        months.append(previous_month(months[-1]))
    return list(reversed(months))


def month_end_history(
    current_month: tuple[int, int],
    current_bars: int = 0,
) -> list[tuple[date, float]]:
    prior = previous_month(current_month)
    months = month_sequence(prior, POINT_COUNT)
    endpoints = [
        (date(year, number, 28), 60.0 + index)
        for index, (year, number) in enumerate(months)
    ]
    history = list(reversed(endpoints))
    year, number = current_month
    current_history = [
        (date(year, number, day), 80.0 + day)
        for day in range(current_bars, 0, -1)
    ]
    return current_history + history


def within_raw_bar_grace(raw_open: datetime, broker_now: datetime) -> bool:
    elapsed = broker_now - raw_open
    return timedelta(0) <= elapsed <= timedelta(minutes=180)


def lifecycle_close(
    entry_time: datetime,
    broker_now: datetime,
    normalized_current_month: tuple[int, int],
    valid_position: bool = True,
    expected_side: bool = True,
) -> bool:
    if not valid_position or not expected_side or entry_time > broker_now:
        return True
    if (entry_time.year, entry_time.month) != normalized_current_month:
        return True
    return broker_now - entry_time >= timedelta(days=40)


class AttemptLedger:
    def __init__(self) -> None:
        self.month: int | None = None

    def consume_before(self, month: int, downstream_gate: bool) -> bool:
        if self.month == month:
            return False
        self.month = month
        return downstream_gate


class MonthlyRepeatedMedianReferenceTests(unittest.TestCase):
    def test_increasing_decreasing_and_constant_paths_follow_strict_sign(self) -> None:
        up = repeated_median_from_logs([0.01 * index for index in range(13)])
        down = repeated_median_from_logs([-0.01 * index for index in range(13)])
        flat = repeated_median_from_logs([0.0] * 13)
        self.assertEqual((up.direction, down.direction, flat.direction), (1, -1, 0))
        self.assertAlmostEqual(up.repeated_median, 0.01)
        self.assertAlmostEqual(down.repeated_median, -0.01)
        self.assertEqual(flat.repeated_median, 0.0)

    def test_exact_nested_counts_indexes_and_pair_duplication(self) -> None:
        logs = [0.003 * index * index - 0.02 * index for index in range(13)]
        signal = repeated_median_from_logs(logs)
        self.assertEqual(len(signal.pivot_slopes), 13)
        self.assertTrue(all(len(group) == 12 for group in signal.pivot_slopes))
        self.assertEqual(sum(map(len, signal.pivot_slopes)), 156)
        for left in range(13):
            for right in range(left + 1, 13):
                slope = (logs[right] - logs[left]) / (right - left)
                self.assertIn(slope, signal.pivot_slopes[left])
                self.assertIn(slope, signal.pivot_slopes[right])
        expected_inner = tuple(
            (group[5] + group[6]) / 2.0 for group in signal.pivot_slopes
        )
        self.assertEqual(signal.pivot_medians, expected_inner)
        self.assertEqual(signal.repeated_median, sorted(expected_inner)[6])

    def test_fixed_path_takes_opposite_side_to_global_theil_sen(self) -> None:
        logs = [0.0, 0.01, 0.06, 0.11, 0.14, 0.13, 0.11, 0.12, 0.09, 0.04, 0.02, 0.05, 0.10]
        global_slope = theil_sen_from_logs(logs)
        nested = repeated_median_from_logs(logs)
        self.assertAlmostEqual(global_slope, 0.0015555555555555557, places=15)
        self.assertAlmostEqual(nested.repeated_median, -0.0045, places=15)
        self.assertGreater(global_slope, 0.0)
        self.assertEqual(nested.direction, -1)

    def test_close_transform_and_invalid_packages(self) -> None:
        closes = [70.0 * math.exp(0.012 * index) for index in range(13)]
        self.assertEqual(signal_from_closes(closes).direction, 1)
        for invalid in (closes[:-1], [*closes[:-1], 0.0], [*closes[:-1], math.nan]):
            with self.assertRaisesRegex(ValueError, "close package"):
                signal_from_closes(invalid)
        with self.assertRaisesRegex(ValueError, "log validity"):
            repeated_median_from_logs([0.0] * 12 + [math.inf])

    def test_thirteen_consecutive_endpoints_and_year_rollover(self) -> None:
        current = (2026, 1)
        history = month_end_history(current, current_bars=0)
        closes, dates = extract_month_endpoints(history, current, date(2026, 1, 2))
        self.assertEqual(len(closes), 13)
        self.assertEqual((dates[0].year, dates[0].month), (2024, 12))
        self.assertEqual((dates[-1].year, dates[-1].month), (2025, 12))
        self.assertTrue(all(dates[index] < dates[index + 1] for index in range(12)))

    def test_current_month_is_excluded_and_latest_close_wins(self) -> None:
        current = (2026, 8)
        history = month_end_history(current, current_bars=2)
        history.insert(3, (date(2026, 7, 15), 999.0))
        closes, dates = extract_month_endpoints(history, current, date(2026, 8, 3))
        self.assertEqual((dates[-1].year, dates[-1].month, dates[-1].day), (2026, 7, 28))
        self.assertNotIn(999.0, closes)
        self.assertTrue(all((item.year, item.month) != current for item in dates))

    def test_missing_month_staleness_and_bad_history_fail_closed(self) -> None:
        current = (2026, 8)
        valid = month_end_history(current)
        missing = [item for item in valid if (item[0].year, item[0].month) != (2026, 4)]
        with self.assertRaisesRegex(ValueError, "nonconsecutive month"):
            extract_month_endpoints(missing, current, date(2026, 8, 3))
        with self.assertRaisesRegex(ValueError, "stale newest endpoint"):
            extract_month_endpoints(valid, current, date(2026, 8, 20))
        malformed = list(valid)
        malformed[0] = (malformed[0][0], math.nan)
        with self.assertRaisesRegex(ValueError, "close validity"):
            extract_month_endpoints(malformed, current, date(2026, 8, 3))

    def test_zero_and_plus_one_label_conventions_match(self) -> None:
        current = (2026, 8)
        canonical = month_end_history(current)
        zero_current, zero_history = normalize_package(
            date(2026, 8, 3), date(2026, 8, 3), canonical
        )
        lag_current, lag_history = normalize_package(
            date(2026, 8, 2),
            date(2026, 8, 3),
            [(label - timedelta(days=1), close) for label, close in canonical],
        )
        self.assertEqual(zero_current, lag_current)
        self.assertEqual(zero_history, lag_history)

    def test_attempt_clock_lifecycle_and_fixed_risk_contract(self) -> None:
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
        self.assertTrue(lifecycle_close(entry, datetime(2026, 8, 4), (2026, 8), expected_side=False))

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41158_wti-repmedian-tr.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR / "sets" / "QM5_41158_wti-repmedian-tr_XTIUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                      = 41158;",
            "input int    strategy_price_points        = 13;",
            "for(int pivot = 0; pivot < point_count; ++pivot)",
            "for(int other = 0; other < point_count; ++other)",
            "const int lower = (pivot < other) ? pivot : other;",
            "const int upper = (pivot < other) ? other : pivot;",
            "grouped_slope_count != 156",
            "center_low_index != 5 || center_high_index != 6",
            "outer_median_index != 6",
            "if(repeated_median > 0.0)",
            "req.tp = 0.0;",
            "strategy_atr_sl_mult);",
        ):
            self.assertIn(marker, source)
        for banned in ("irsi(", "imacd(", "ibands(", "webrequest(", "theil_sen"):
            self.assertNotIn(banned, source.lower())
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_PrepareDecisionSignal();"),
            on_tick.index("Strategy_NewsFilterHook(broker_now)"),
        )
        for marker in (
            "environment:  backtest",
            "qm_ea_id=41158",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_price_points=13",
            "strategy_history_bars_d1=800",
            "strategy_endpoint_stale_days=10",
            "strategy_atr_sl_mult=3.5",
        ):
            self.assertIn(marker, setfile)

        approved = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41158_wti-repmedian-tr_card.md"
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())
        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(encoding="utf-8-sig")
        self.assertIn("41158,wti-repmedian-tr,0,XTIUSD.DWX,411580000", magic_rows)
        resolver = (REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh").read_text(encoding="utf-8")
        self.assertIn("411580000", resolver)


if __name__ == "__main__":
    unittest.main()
