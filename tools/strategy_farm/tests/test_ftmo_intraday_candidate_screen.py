from __future__ import annotations

import unittest
from pathlib import Path

import pandas as pd

from tools.strategy_farm.portfolio.ftmo_intraday_candidate_screen import (
    Instrument,
    Trade,
    broker_wall_seconds_to_utc,
    holdout_pass,
    opening_range_breakout,
    previous_session_move,
    simulate_market_trade,
    split_metrics,
)


class FtmoIntradayCandidateScreenTests(unittest.TestCase):
    def test_broker_wall_epoch_converts_with_us_dst_offset(self) -> None:
        broker_wall = pd.Series(
            [
                int(pd.Timestamp("2024-01-08 18:00:00", tz="UTC").timestamp()),
                int(pd.Timestamp("2024-07-08 18:00:00", tz="UTC").timestamp()),
            ]
        )

        utc = broker_wall_seconds_to_utc(broker_wall)

        self.assertEqual(str(utc.iloc[0]), "2024-01-08 16:00:00+00:00")
        self.assertEqual(str(utc.iloc[1]), "2024-07-08 15:00:00+00:00")
        new_york = utc.dt.tz_convert("America/New_York")
        self.assertEqual(new_york.iloc[0].hour, 11)
        self.assertEqual(new_york.iloc[1].hour, 11)

    def test_same_bar_collision_is_stop_first(self) -> None:
        frame = pd.DataFrame(
            [
                {
                    "open": 100.0,
                    "high": 112.0,
                    "low": 89.0,
                    "close": 105.0,
                    "utc": pd.Timestamp("2025-01-02T10:00:00Z"),
                    "local_date": pd.Timestamp("2025-01-02").date(),
                    "year": 2025,
                }
            ]
        )
        trade = simulate_market_trade(
            frame,
            entry_index=0,
            side=1,
            stop_distance=10.0,
            target_r=1.0,
            last_index=0,
            round_trip_cost_points=1.0,
        )
        self.assertIsNotNone(trade)
        assert trade is not None
        self.assertEqual(trade.exit_reason, "stop_pessimistic")
        self.assertAlmostEqual(trade.r_multiple, -1.1)

    def test_dual_pending_touch_is_counted_as_pessimistic_stop(self) -> None:
        local_date = pd.Timestamp("2025-01-02").date()
        frame = pd.DataFrame(
            [
                {
                    "open": 95.0,
                    "high": 100.0,
                    "low": 90.0,
                    "close": 96.0,
                    "utc": pd.Timestamp("2025-01-02T09:00:00Z"),
                    "local_date": local_date,
                    "year": 2025,
                    "hour": 9,
                    "weekday": 3,
                    "atr14": 10.0,
                },
                {
                    "open": 96.0,
                    "high": 102.0,
                    "low": 88.0,
                    "close": 95.0,
                    "utc": pd.Timestamp("2025-01-02T10:00:00Z"),
                    "local_date": local_date,
                    "year": 2025,
                    "hour": 10,
                    "weekday": 3,
                    "atr14": 10.0,
                },
            ]
        )
        instrument = Instrument("TEST", Path("unused"), "UTC", 9, 10, (), 0.0)

        trades = opening_range_breakout(
            frame,
            instrument,
            range_bars=1,
            buffer_atr=0.0,
            target_r=5.0,
            max_range_atr=2.0,
        )

        self.assertEqual(len(trades), 1)
        self.assertEqual(trades[0].side, 1)
        self.assertEqual(trades[0].exit_reason, "stop")
        self.assertAlmostEqual(trades[0].r_multiple, -1.0)

    def test_holdout_requires_both_years_positive(self) -> None:
        trades = [
            Trade("2024-01-02T10:00:00+00:00", "2024-01-02", 2024, 1, 2.0, "target"),
            Trade("2025-01-02T10:00:00+00:00", "2025-01-02", 2025, 1, -1.0, "stop"),
        ] * 20
        metrics = split_metrics(trades)
        self.assertFalse(holdout_pass(metrics))

    def test_previous_session_fade_uses_only_prior_closed_session(self) -> None:
        frame = pd.DataFrame(
            [
                {"open": 90.0, "high": 96.0, "low": 89.0, "close": 95.0, "hour": 9},
                {"open": 95.0, "high": 101.0, "low": 94.0, "close": 100.0, "hour": 15},
                {"open": 100.0, "high": 101.0, "low": 89.0, "close": 90.0, "hour": 9},
                {"open": 90.0, "high": 91.0, "low": 89.0, "close": 90.0, "hour": 15},
            ]
        )
        frame["utc"] = pd.to_datetime(
            [
                "2025-01-06T14:00:00Z",
                "2025-01-06T20:00:00Z",
                "2025-01-07T14:00:00Z",
                "2025-01-07T20:00:00Z",
            ]
        )
        frame["local_date"] = [pd.Timestamp("2025-01-06").date()] * 2 + [
            pd.Timestamp("2025-01-07").date()
        ] * 2
        frame["year"] = 2025
        frame["weekday"] = [0, 0, 1, 1]
        frame["atr14"] = 10.0
        instrument = Instrument("TEST", Path("unused"), "UTC", 9, 15, (), 0.0)

        trades = previous_session_move(
            frame,
            instrument,
            move_atr=0.5,
            stop_atr=1.0,
            target_r=1.0,
            continuation=False,
            weekday=1,
        )

        self.assertEqual(len(trades), 1)
        self.assertEqual(trades[0].side, -1)
        self.assertEqual(trades[0].exit_reason, "target")


if __name__ == "__main__":
    unittest.main()
