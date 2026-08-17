"""Independent mechanic fixtures for QM5_21503.

These tests cover the locked calendar normalization, 206-close index map,
non-overlapping weekly realized-volatility blocks, inclusive rank boundary,
direction, grace, attempt consumption, lifecycle repair, and source wiring.
They do not invoke MT5 or duplicate framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
from pathlib import Path
import unittest


DAY = dt.timedelta(days=1)
RETURNS_PER_WEEK = 5
BASELINE_BLOCKS = 40
RANK_MAX_COUNT = 13
BARS_NEEDED = 206


def session_time(label: dt.datetime, broker_now: dt.datetime) -> dt.datetime:
    elapsed = broker_now - label
    if DAY <= elapsed <= 2 * DAY:
        return label + DAY
    return label


def within_entry_grace(
    broker_now: dt.datetime, labelled_bar_open: dt.datetime, grace_minutes: int = 180
) -> bool:
    elapsed = int((broker_now - labelled_bar_open).total_seconds())
    if elapsed < 0:
        return False
    return elapsed % 86_400 <= grace_minutes * 60


def valid_signal_week(
    broker_now: dt.datetime,
    current_label: dt.datetime,
    completed_labels: tuple[dt.datetime, ...],
) -> bool:
    if len(completed_labels) != 6:
        return False
    current = session_time(current_label, broker_now)
    offset = current - current_label
    normalized = tuple(value + offset for value in completed_labels)
    expected_weekdays = (4, 3, 2, 1, 0, 4)  # Python Monday=0
    expected_dates = tuple(
        (current - days * DAY).date() for days in (3, 4, 5, 6, 7, 10)
    )
    return (
        broker_now.weekday() == 0
        and current.date() == broker_now.date()
        and tuple(value.weekday() for value in normalized) == expected_weekdays
        and tuple(value.date() for value in normalized) == expected_dates
    )


def closes_from_interval_returns(interval_returns: list[float]) -> list[float]:
    """Build newest-first closes where r[i] = log(close[i]/close[i+1])."""
    if len(interval_returns) != BARS_NEEDED - 1:
        raise ValueError("exactly 205 completed return intervals are required")
    closes = [0.0] * BARS_NEEDED
    closes[-1] = 70.0
    for index in range(BARS_NEEDED - 2, -1, -1):
        closes[index] = closes[index + 1] * math.exp(interval_returns[index])
    return closes


def exact_week_lowvol_signal(
    closes: list[float],
    baseline_blocks: int = BASELINE_BLOCKS,
    rank_max_count: int = RANK_MAX_COUNT,
) -> tuple[int, float, float, int] | None:
    if baseline_blocks != BASELINE_BLOCKS or rank_max_count != RANK_MAX_COUNT:
        return None
    if len(closes) != 6 + baseline_blocks * RETURNS_PER_WEEK:
        return None
    if not all(math.isfinite(value) and value > 0.0 for value in closes):
        return None

    signal_returns = [
        math.log(closes[4 - k] / closes[5 - k])
        for k in range(RETURNS_PER_WEEK)
    ]
    weekly_return = sum(signal_returns)
    endpoint_return = math.log(closes[0] / closes[5])
    current_rv = math.sqrt(sum(value * value for value in signal_returns))
    if (
        not all(math.isfinite(value) for value in signal_returns)
        or not math.isfinite(weekly_return)
        or not math.isfinite(endpoint_return)
        or abs(weekly_return - endpoint_return) > 1.0e-10
        or not math.isfinite(current_rv)
        or current_rv <= 0.0
    ):
        return None

    rank_count = 0
    for block in range(baseline_blocks):
        block_returns = [
            math.log(
                closes[5 + block * RETURNS_PER_WEEK + k]
                / closes[6 + block * RETURNS_PER_WEEK + k]
            )
            for k in range(RETURNS_PER_WEEK)
        ]
        baseline_rv = math.sqrt(sum(value * value for value in block_returns))
        if not math.isfinite(baseline_rv) or baseline_rv < 0.0:
            return None
        if baseline_rv <= current_rv:
            rank_count += 1

    direction = 0
    if rank_count <= rank_max_count:
        if weekly_return > 0.0:
            direction = 1
        elif weekly_return < 0.0:
            direction = -1
    return direction, weekly_return, current_rv, rank_count


def ranked_fixture(
    signal_returns: list[float], equal_or_lower_blocks: int
) -> list[float]:
    if len(signal_returns) != RETURNS_PER_WEEK:
        raise ValueError("signal week must contain five returns")
    baseline_returns: list[float] = []
    for block in range(BASELINE_BLOCKS):
        value = (
            abs(signal_returns[0])
            if block < equal_or_lower_blocks
            else abs(signal_returns[0]) * 2.0
        )
        baseline_returns.extend([value] * RETURNS_PER_WEEK)
    return closes_from_interval_returns(signal_returns + baseline_returns)


def return_interval_sets() -> tuple[set[tuple[int, int]], set[tuple[int, int]]]:
    signal = {(4 - k, 5 - k) for k in range(RETURNS_PER_WEEK)}
    baseline = {
        (
            5 + block * RETURNS_PER_WEEK + k,
            6 + block * RETURNS_PER_WEEK + k,
        )
        for block in range(BASELINE_BLOCKS)
        for k in range(RETURNS_PER_WEEK)
    }
    return signal, baseline


def week_start(value: dt.datetime) -> dt.date:
    return (value - value.weekday() * DAY).date()


class AttemptLedger:
    def __init__(self) -> None:
        self.last_key = 0

    def consume_then_evaluate(self, date_key: int, fallible_gate: bool) -> bool:
        if date_key <= 0 or date_key == self.last_key:
            return False
        self.last_key = date_key
        return fallible_gate


class ExactWeekLowVolReferenceTests(unittest.TestCase):
    def test_native_and_prior_date_energy_labels(self) -> None:
        broker_now = dt.datetime(2026, 8, 17, 1, 0)
        native = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (14, 13, 12, 11, 10, 7)
        )
        prior_date = tuple(
            dt.datetime(2026, 8, day, 0, 0) for day in (13, 12, 11, 10, 9, 6)
        )
        self.assertTrue(
            valid_signal_week(broker_now, dt.datetime(2026, 8, 17), native)
        )
        self.assertTrue(
            valid_signal_week(broker_now, dt.datetime(2026, 8, 16), prior_date)
        )

    def test_holiday_shift_and_non_monday_fail_closed(self) -> None:
        shifted = tuple(
            dt.datetime(2026, 8, day) for day in (14, 12, 11, 10, 7, 6)
        )
        self.assertFalse(
            valid_signal_week(
                dt.datetime(2026, 8, 17, 1), dt.datetime(2026, 8, 17), shifted
            )
        )
        self.assertFalse(
            valid_signal_week(
                dt.datetime(2026, 8, 18, 1), dt.datetime(2026, 8, 18), shifted
            )
        )

    def test_three_hour_grace_uses_raw_label_modulo_day(self) -> None:
        labelled = dt.datetime(2026, 8, 16)
        self.assertTrue(within_entry_grace(dt.datetime(2026, 8, 17, 2, 59), labelled))
        self.assertFalse(
            within_entry_grace(dt.datetime(2026, 8, 17, 3, 0, 1), labelled)
        )

    def test_206_closes_partition_all_205_intervals_without_overlap(self) -> None:
        signal, baseline = return_interval_sets()
        self.assertEqual(len(signal), 5)
        self.assertEqual(len(baseline), 200)
        self.assertTrue(signal.isdisjoint(baseline))
        self.assertEqual(
            {newer for newer, _ in signal | baseline}, set(range(BARS_NEEDED - 1))
        )

    def test_low_rv_positive_and_negative_weeks_follow_the_sign(self) -> None:
        long_state = exact_week_lowvol_signal(ranked_fixture([0.001] * 5, 0))
        short_state = exact_week_lowvol_signal(ranked_fixture([-0.001] * 5, 0))
        self.assertIsNotNone(long_state)
        self.assertIsNotNone(short_state)
        assert long_state is not None and short_state is not None
        self.assertEqual((long_state[0], long_state[3]), (1, 0))
        self.assertEqual((short_state[0], short_state[3]), (-1, 0))

    def test_inclusive_rank_13_passes_and_14_fails(self) -> None:
        boundary = exact_week_lowvol_signal(ranked_fixture([0.002] * 5, 13))
        outside = exact_week_lowvol_signal(ranked_fixture([0.002] * 5, 14))
        self.assertIsNotNone(boundary)
        self.assertIsNotNone(outside)
        assert boundary is not None and outside is not None
        self.assertEqual((boundary[0], boundary[3]), (1, 13))
        self.assertEqual((outside[0], outside[3]), (0, 14))

    def test_all_40_lower_blocks_are_ineligible(self) -> None:
        state = exact_week_lowvol_signal(ranked_fixture([0.002] * 5, 40))
        self.assertIsNotNone(state)
        assert state is not None
        self.assertEqual((state[0], state[3]), (0, 40))

    def test_zero_return_and_zero_rv_are_flat_or_invalid(self) -> None:
        zero_return = closes_from_interval_returns([0.0] * 5 + [1.0] * 200)
        # Powers-of-two reciprocal ratios cancel exactly in binary libm while
        # retaining positive path RV. Older blocks remain strictly higher RV.
        zero_return[:6] = [64.0, 128.0, 64.0, 128.0, 64.0, 64.0]
        state = exact_week_lowvol_signal(zero_return)
        self.assertIsNotNone(state)
        assert state is not None
        self.assertEqual(state[0], 0)
        self.assertIsNone(
            exact_week_lowvol_signal(closes_from_interval_returns([0.0] * 205))
        )

    def test_endpoint_return_reconciles(self) -> None:
        state = exact_week_lowvol_signal(ranked_fixture([0.001, 0.002] * 2 + [0.003], 0))
        self.assertIsNotNone(state)
        assert state is not None
        closes = ranked_fixture([0.001, 0.002] * 2 + [0.003], 0)
        self.assertAlmostEqual(state[1], math.log(closes[0] / closes[5]), places=12)

    def test_invalid_history_fails_closed(self) -> None:
        valid = ranked_fixture([0.001] * 5, 0)
        self.assertIsNone(exact_week_lowvol_signal(valid[:-1]))
        valid[100] = float("nan")
        self.assertIsNone(exact_week_lowvol_signal(valid))

    def test_attempt_is_consumed_before_a_fallible_gate(self) -> None:
        ledger = AttemptLedger()
        self.assertFalse(ledger.consume_then_evaluate(20260817, False))
        self.assertFalse(ledger.consume_then_evaluate(20260817, True))
        self.assertTrue(ledger.consume_then_evaluate(20260824, True))

    def test_later_week_and_eight_day_guards(self) -> None:
        opened = dt.datetime(2026, 8, 17, 1)
        self.assertEqual(week_start(opened), week_start(dt.datetime(2026, 8, 21, 22)))
        self.assertNotEqual(week_start(opened), week_start(dt.datetime(2026, 8, 24, 0, 1)))
        self.assertLess(dt.datetime(2026, 8, 25, 0, 59) - opened, 8 * DAY)
        self.assertGreaterEqual(dt.datetime(2026, 8, 25, 1) - opened, 8 * DAY)

    def test_mq5_contains_locked_mechanic_and_gate_order(self) -> None:
        source = (
            Path(__file__).resolve().parents[1]
            / "QM5_21503_xti-weekly-tsmom-lowvol.mq5"
        ).read_text(encoding="utf-8")
        required = (
            "qm_ea_id                     = 21503",
            "strategy_baseline_blocks      = 40",
            "strategy_rank_max_count       = 13",
            "bars_needed != 206",
            "baseline_rv <= current_rv",
            "MathAbs(weekly_return - endpoint_return) > 1.0e-10",
            "MathAbs(RISK_FIXED - 1000.0)",
            "strategy_atr_sl_mult - 3.0",
            "qm_friday_close_hour_broker != 21",
        )
        for token in required:
            self.assertIn(token, source)
        self.assertLess(
            source.index("Strategy_RecordDateAttempt(date_key)"),
            source.index("Strategy_LoadWeeklyLowVol(g_strategy_d1_bar_time"),
        )
        self.assertLess(
            source.index("Strategy_ManageOpenPosition();"),
            source.index("Strategy_NoTradeFilter())", source.index("void OnTick()")),
        )


if __name__ == "__main__":
    unittest.main()
