"""Deterministic reference checks for QM5_21504 signal arithmetic."""

from __future__ import annotations

import unittest


WEEK_BARS = 5


def flowrev_signal(
    closes: list[float],
    tick_volumes: list[int],
    lookback: int = 40,
    percentile_floor: float = 75.0,
) -> tuple[int, float, list[int]]:
    required = lookback * WEEK_BARS + WEEK_BARS
    if len(closes) != required or len(tick_volumes) != required:
        raise ValueError("exact completed-bar support required")
    if any(close <= 0.0 for close in closes):
        raise ValueError("closes must be positive")
    if any(volume <= 0 for volume in tick_volumes):
        raise ValueError("tick volume must be positive")

    week_return = closes[0] / closes[WEEK_BARS] - 1.0
    current_volume = sum(tick_volumes[:WEEK_BARS])
    baseline = [
        sum(
            tick_volumes[
                WEEK_BARS + window * WEEK_BARS :
                WEEK_BARS + (window + 1) * WEEK_BARS
            ]
        )
        for window in range(lookback)
    ]
    volume_rank = 100.0 * sum(
        value <= current_volume for value in baseline
    ) / lookback

    if volume_rank < percentile_floor or week_return == 0.0:
        return 0, volume_rank, baseline
    return (-1 if week_return > 0.0 else 1), volume_rank, baseline


def fixture(current_per_bar: int) -> tuple[list[float], list[int]]:
    closes = [100.0] * 205
    closes[0] = 105.0
    tick_volumes = [current_per_bar] * WEEK_BARS
    for window in range(40):
        tick_volumes.extend([window + 1] * WEEK_BARS)
    return closes, tick_volumes


class FlowReversalReferenceTests(unittest.TestCase):
    def test_exact_seventy_fifth_percentile_fades_positive_return(self) -> None:
        closes, volumes = fixture(30)
        direction, rank, baseline = flowrev_signal(closes, volumes)
        self.assertEqual(-1, direction)
        self.assertEqual(75.0, rank)
        self.assertEqual(40, len(baseline))

    def test_below_percentile_stays_flat(self) -> None:
        closes, volumes = fixture(29)
        direction, rank, _ = flowrev_signal(closes, volumes)
        self.assertEqual(0, direction)
        self.assertEqual(72.5, rank)

    def test_ties_are_included(self) -> None:
        closes = [100.0] * 205
        closes[0] = 95.0
        volumes = [20] * 205
        direction, rank, _ = flowrev_signal(closes, volumes)
        self.assertEqual(1, direction)
        self.assertEqual(100.0, rank)

    def test_current_window_does_not_overlap_baseline(self) -> None:
        closes, volumes = fixture(30)
        _, _, before = flowrev_signal(closes, volumes)
        volumes[0] = 10_000
        _, _, after = flowrev_signal(closes, volumes)
        self.assertEqual(before, after)

    def test_exact_history_length_is_required(self) -> None:
        closes, volumes = fixture(30)
        with self.assertRaises(ValueError):
            flowrev_signal(closes[:-1], volumes[:-1])


if __name__ == "__main__":
    unittest.main()
