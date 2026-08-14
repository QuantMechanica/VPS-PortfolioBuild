"""Deterministic reference checks for QM5_21521 signal arithmetic."""

from __future__ import annotations

import unittest


WEEK_BARS = 5


def flow_switch_signal(
    closes: list[float],
    tick_volumes: list[int],
    lookback: int = 40,
    low_rank_cap: float = 25.0,
    high_rank_floor: float = 75.0,
) -> tuple[int, float, list[int]]:
    required = lookback * WEEK_BARS + WEEK_BARS
    if len(closes) != required or len(tick_volumes) != required:
        raise ValueError("exact completed-bar support required")
    if any(close <= 0.0 for close in closes):
        raise ValueError("closes must be positive")
    if any(volume <= 0 for volume in tick_volumes):
        raise ValueError("tick volume must be positive")
    if not 0.0 < low_rank_cap < 50.0:
        raise ValueError("low rank boundary must be below 50")
    if not 50.0 < high_rank_floor < 100.0:
        raise ValueError("high rank boundary must be above 50")
    if low_rank_cap >= high_rank_floor:
        raise ValueError("rank boundaries must not overlap")

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

    if week_return == 0.0:
        return 0, volume_rank, baseline
    return_sign = 1 if week_return > 0.0 else -1
    if volume_rank <= low_rank_cap:
        return return_sign, volume_rank, baseline
    if volume_rank >= high_rank_floor:
        return -return_sign, volume_rank, baseline
    return 0, volume_rank, baseline


def fixture(current_per_bar: int) -> tuple[list[float], list[int]]:
    closes = [100.0] * 205
    closes[0] = 105.0
    tick_volumes = [current_per_bar] * WEEK_BARS
    for window in range(40):
        tick_volumes.extend([window + 1] * WEEK_BARS)
    return closes, tick_volumes


class FlowSwitchReferenceTests(unittest.TestCase):
    def test_exact_low_boundary_follows_positive_return(self) -> None:
        closes, volumes = fixture(10)
        direction, rank, baseline = flow_switch_signal(closes, volumes)
        self.assertEqual(1, direction)
        self.assertEqual(25.0, rank)
        self.assertEqual(40, len(baseline))

    def test_low_tail_follows_negative_return(self) -> None:
        closes, volumes = fixture(10)
        closes[0] = 95.0
        direction, rank, _ = flow_switch_signal(closes, volumes)
        self.assertEqual(-1, direction)
        self.assertEqual(25.0, rank)

    def test_middle_half_stays_flat(self) -> None:
        closes, volumes = fixture(20)
        direction, rank, _ = flow_switch_signal(closes, volumes)
        self.assertEqual(0, direction)
        self.assertEqual(50.0, rank)

    def test_exact_high_boundary_fades_positive_return(self) -> None:
        closes, volumes = fixture(30)
        direction, rank, _ = flow_switch_signal(closes, volumes)
        self.assertEqual(-1, direction)
        self.assertEqual(75.0, rank)

    def test_high_tail_fades_negative_return(self) -> None:
        closes, volumes = fixture(30)
        closes[0] = 95.0
        direction, rank, _ = flow_switch_signal(closes, volumes)
        self.assertEqual(1, direction)
        self.assertEqual(75.0, rank)

    def test_equal_volume_ties_rank_high_and_fade(self) -> None:
        closes = [100.0] * 205
        closes[0] = 105.0
        volumes = [20] * 205
        direction, rank, _ = flow_switch_signal(closes, volumes)
        self.assertEqual(-1, direction)
        self.assertEqual(100.0, rank)

    def test_current_window_does_not_overlap_baseline(self) -> None:
        closes, volumes = fixture(10)
        _, _, before = flow_switch_signal(closes, volumes)
        volumes[0] = 10_000
        _, _, after = flow_switch_signal(closes, volumes)
        self.assertEqual(before, after)

    def test_zero_return_stays_flat_in_either_tail(self) -> None:
        closes, volumes = fixture(40)
        closes[0] = closes[WEEK_BARS]
        direction, rank, _ = flow_switch_signal(closes, volumes)
        self.assertEqual(0, direction)
        self.assertEqual(100.0, rank)

    def test_exact_history_length_is_required(self) -> None:
        closes, volumes = fixture(10)
        with self.assertRaises(ValueError):
            flow_switch_signal(closes[:-1], volumes[:-1])


if __name__ == "__main__":
    unittest.main()
