"""Independent deterministic fixtures for QM5_41241.

The suite covers normalized D1 labels, six consecutive completed WTI month
ends, strict CH3 and DMAC states, their AND intersection, durable attempts,
monthly lifecycle, quote boundaries, and static build conformance. It does
not invoke MT5.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest
from dataclasses import dataclass
from pathlib import Path


DAY = dt.timedelta(days=1)
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class Bar:
    label: dt.datetime
    close: float


@dataclass(frozen=True)
class ConfirmedState:
    latest: float
    channel_high: float
    channel_low: float
    mean6: float
    upper: float
    lower: float
    channel: int
    dmac: int
    direction: int


def date_key(value: dt.datetime) -> int:
    return value.year * 10000 + value.month * 100 + value.day


def normalized_sessions(
    current_label: dt.datetime,
    previous_label: dt.datetime,
    broker_now: dt.datetime,
) -> tuple[dt.datetime, dt.datetime, int] | None:
    if date_key(current_label) == date_key(broker_now):
        offset = 0
    elif date_key(current_label + DAY) == date_key(broker_now):
        offset = 1
    else:
        return None
    current = current_label + offset * DAY
    previous = previous_label + offset * DAY
    if current <= previous or date_key(current) != date_key(broker_now):
        return None
    return current, previous, offset


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def previous_month(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or month not in range(1, 13):
        return 0
    month -= 1
    if month == 0:
        year -= 1
        month = 12
    return year * 100 + month


def completed_month_closes(
    bars: tuple[Bar, ...], decision_month: int, label_offset_days: int
) -> list[float] | None:
    if label_offset_days not in (0, 1) or len(bars) < 6:
        return None
    if any(
        bars[index].label <= bars[index - 1].label
        for index in range(1, len(bars))
    ):
        return None

    expected = previous_month(decision_month)
    closes: list[float] = []
    for bar in reversed(bars):
        normalized = bar.label + label_offset_days * DAY
        observed_month = month_key(normalized)
        if observed_month == decision_month:
            return None
        if observed_month > expected:
            continue
        if observed_month < expected:
            return None
        if not math.isfinite(bar.close) or bar.close <= 0.0:
            return None
        closes.append(bar.close)
        if len(closes) == 6:
            return closes
        expected = previous_month(expected)
    return None


def confirmed_state(closes: list[float]) -> ConfirmedState | None:
    if len(closes) != 6 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        return None
    latest = closes[0]
    channel_high = max(closes[1:4])
    channel_low = min(closes[1:4])
    mean6 = sum(closes) / 6.0
    upper = mean6 * 1.025
    lower = mean6 * 0.975
    channel = 1 if latest > channel_high else -1 if latest < channel_low else 0
    dmac = 1 if latest > upper else -1 if latest < lower else 0
    direction = channel if channel != 0 and channel == dmac else 0
    return ConfirmedState(
        latest,
        channel_high,
        channel_low,
        mean6,
        upper,
        lower,
        channel,
        dmac,
        direction,
    )


def quote_allows(
    bid: float, ask: float, point: float, maximum_spread_points: int = 1500
) -> bool:
    if not all(
        math.isfinite(value) and value > 0.0 for value in (bid, ask, point)
    ):
        return False
    if ask < bid:
        return False
    spread = (ask - bid) / point
    return math.isfinite(spread) and 0.0 <= spread <= maximum_spread_points


class AttemptLedger:
    def __init__(self, storage: dict[str, int], key: str = "attempt") -> None:
        self.storage = storage
        self.key = key

    def consume_before(self, month: int, downstream_gate: bool) -> bool:
        if self.storage.get(self.key, 0) >= month:
            return False
        self.storage[self.key] = month
        return downstream_gate


def exit_due(opened: dt.datetime, current: dt.datetime) -> bool:
    crossed_month = (opened.year, opened.month) != (current.year, current.month)
    return crossed_month or current >= opened + 40 * DAY


class WtiCh3DmacConfirmReferenceTests(unittest.TestCase):
    def test_native_and_prior_day_labels_detect_month_roll(self) -> None:
        native = normalized_sessions(
            dt.datetime(2026, 8, 3),
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 8, 3, 1),
        )
        prior_day = normalized_sessions(
            dt.datetime(2026, 7, 31),
            dt.datetime(2026, 7, 30),
            dt.datetime(2026, 8, 1, 1),
        )
        self.assertIsNotNone(native)
        self.assertIsNotNone(prior_day)
        assert native is not None and prior_day is not None
        self.assertEqual(native[2], 0)
        self.assertEqual(prior_day[2], 1)
        self.assertNotEqual(native[0].month, native[1].month)
        self.assertNotEqual(prior_day[0].month, prior_day[1].month)

    def test_latest_six_consecutive_completed_month_ends(self) -> None:
        bars = tuple(
            Bar(dt.datetime(2026, month, day), 60.0 + month + day / 100.0)
            for month in range(1, 8)
            for day in (2, 25)
        )
        observed = completed_month_closes(bars, 202608, 0)
        self.assertEqual(
            observed,
            [67.25, 66.25, 65.25, 64.25, 63.25, 62.25],
        )
        self.assertIsNone(completed_month_closes(bars[:-2], 202608, 0))
        self.assertIsNone(
            completed_month_closes(
                bars + (Bar(dt.datetime(2026, 8, 1), 70.0),), 202608, 0
            )
        )

    def test_prior_day_labels_preserve_endpoint_months(self) -> None:
        bars = tuple(
            Bar(dt.datetime(2025, month, 27), 80.0 + month)
            for month in range(7, 13)
        ) + tuple(
            Bar(dt.datetime(2026, month, 27), 92.0 + month)
            for month in range(1, 8)
        )
        observed = completed_month_closes(bars, 202608, 1)
        self.assertEqual(observed, [99.0, 98.0, 97.0, 96.0, 95.0, 94.0])

    def test_disagreement_and_confirmation_fixtures(self) -> None:
        fixtures = (
            ([103, 100, 99, 98, 120, 120], (1, -1, 0)),
            ([110, 111, 109, 108, 80, 80], (0, 1, 0)),
            ([120, 110, 105, 100, 95, 90], (1, 1, 1)),
            ([80, 90, 95, 100, 105, 110], (-1, -1, -1)),
        )
        for closes, expected in fixtures:
            with self.subTest(closes=closes):
                state = confirmed_state(closes)
                self.assertIsNotNone(state)
                assert state is not None
                self.assertEqual(
                    (state.channel, state.dmac, state.direction), expected
                )

    def test_strict_channel_equality_and_invalid_data_stay_flat_or_fail(self) -> None:
        state = confirmed_state([100, 100, 99, 98, 60, 60])
        self.assertIsNotNone(state)
        assert state is not None
        self.assertEqual(state.channel, 0)
        self.assertEqual(state.direction, 0)
        self.assertIsNone(confirmed_state([100] * 5))
        self.assertIsNone(confirmed_state([100, 99, 98, 97, 0, 95]))
        self.assertIsNone(
            confirmed_state([100, 99, math.nan, 97, 96, 95])
        )

    def test_attempt_consumes_before_failure_and_survives_restart(self) -> None:
        storage: dict[str, int] = {}
        first = AttemptLedger(storage)
        self.assertFalse(first.consume_before(202608, downstream_gate=False))
        self.assertFalse(first.consume_before(202608, downstream_gate=True))
        restarted = AttemptLedger(storage)
        self.assertFalse(restarted.consume_before(202608, downstream_gate=True))
        self.assertTrue(restarted.consume_before(202609, downstream_gate=True))

    def test_quote_boundaries_and_monthly_stale_lifecycle(self) -> None:
        self.assertTrue(quote_allows(70.0, 70.0, 0.01))
        self.assertTrue(quote_allows(70.0, 85.0, 0.01))
        self.assertFalse(quote_allows(70.0, 85.01, 0.01))
        self.assertFalse(quote_allows(70.01, 70.0, 0.01))
        opened = dt.datetime(2026, 1, 3)
        self.assertFalse(exit_due(opened, opened + 20 * DAY))
        self.assertTrue(exit_due(opened, opened + 40 * DAY))
        self.assertTrue(
            exit_due(dt.datetime(2026, 1, 30), dt.datetime(2026, 2, 2))
        )

    def test_static_build_contract_matches_approved_card(self) -> None:
        source_path = EA_DIR / "QM5_41241_wti-ch3-dmac-confirm.mq5"
        source = source_path.read_text(encoding="utf-8")
        set_path = (
            EA_DIR
            / "sets"
            / "QM5_41241_wti-ch3-dmac-confirm_XTIUSD.DWX_D1_backtest.set"
        )
        setfile = set_path.read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id                     = 41241;",
            'const string g_symbol = "XTIUSD.DWX";',
            "strategy_channel_months       = 3;",
            "strategy_mean_months          = 6;",
            "strategy_band_pct             = 2.5;",
            "strategy_history_bars_d1      = 300;",
            "strategy_atr_period_d1        = 20;",
            "strategy_atr_stop_multiple    = 4.0;",
            "closes[sample_count] = close_value;",
            "channel_high = MathMax(channel_high, closes[index]);",
            "channel_low = MathMin(channel_low, closes[index]);",
            "mean6 = sum / (double)strategy_mean_months;",
            "upper_band = mean6 * (1.0 + strategy_band_pct / 100.0);",
            "lower_band = mean6 * (1.0 - strategy_band_pct / 100.0);",
            "channel_state != 0 && channel_state == dmac_state",
            "Strategy_RecordMonthAttempt(g_decision_month_key)",
            "spread_points < 0.0",
            "req.tp = 0.0;",
            "strategy_atr_period_d1, 1);",
            "strategy_atr_stop_multiple);",
            "QM_FrameworkTrackOpenPositionMae();",
        ):
            self.assertIn(marker, source)
        for banned in (
            "irsi(",
            "imacd(",
            "ibands(",
            "webrequest(",
            "fileopen(",
            "machine learning",
            "neural",
            "martingale",
            "grid entry",
        ):
            self.assertNotIn(banned, source.lower())
        self.assertNotIn("SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)", source)

        prepare = source[
            source.index("void Strategy_PrepareDecisionSignal") :
            source.index("bool Strategy_NoTradeFilter")
        ]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadCompletedMonthCloses"),
        )
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_ManageOpenPosition();"),
            on_tick.index("Strategy_NoTradeFilter()"),
        )

        for marker in (
            "qm_ea_id=41241",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "strategy_channel_months=3",
            "strategy_mean_months=6",
            "strategy_band_pct=2.5",
            "strategy_history_bars_d1=300",
            "strategy_atr_period_d1=20",
            "strategy_atr_stop_multiple=4.0",
            "strategy_max_hold_days=40",
            "strategy_max_spread_points=1500",
        ):
            self.assertIn(marker, setfile)
        self.assertRegex(
            setfile, r"(?m)^; build_hash:\s+(?:pending|[0-9a-f]{64})$"
        )
        self.assertEqual(
            {path.name for path in (EA_DIR / "sets").glob("*.set")},
            {set_path.name},
        )

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41241_wti-ch3-dmac-confirm_card.md"
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
            "41241,wti-ch3-dmac-confirm,0,XTIUSD.DWX,412410000", magic_rows
        )
        resolver = (
            REPO_ROOT
            / "framework"
            / "include"
            / "QM"
            / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("412410000", resolver)


if __name__ == "__main__":
    unittest.main()
