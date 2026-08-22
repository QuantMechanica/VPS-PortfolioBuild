"""Independent deterministic fixtures for QM5_41112's monthly basket rule."""

from __future__ import annotations

import json
import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
HISTORY_BARS = 70


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class BreadthResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    parent_sessions: int = 0
    positive: int = 0
    negative: int = 0
    endpoint_net: float = 0.0


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def previous_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year - 1) * 100 + 12 if month == 1 else year * 100 + month - 1


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


def make_month(key: int, ratios: list[float]) -> tuple[list[CloseBar], list[CloseBar]]:
    year, month = divmod(key, 100)
    xau: list[CloseBar] = []
    xag: list[CloseBar] = []
    for day, ratio in enumerate(ratios, start=1):
        opened = datetime(year, month, day, tzinfo=UTC)
        silver = 1.0
        xau.append(CloseBar(opened, silver * math.exp(ratio)))
        xag.append(CloseBar(opened, silver))
    return list(reversed(xau)), list(reversed(xag))


def sample(
    relative_returns: list[float],
    *,
    completed_key: int = 202607,
    parent_key: int | None = None,
    parent_count: int = 20,
    parent_ratios: list[float] | None = None,
) -> tuple[list[CloseBar], list[CloseBar]]:
    """Build an exact 70-bar newest-first pair with a visible older boundary."""

    if parent_key is None:
        parent_key = previous_month_key(completed_key)
    anchor = 4.25
    if parent_ratios is None:
        parent_ratios = [anchor - 0.10] * (parent_count - 1) + [anchor]
    elif len(parent_ratios) != parent_count:
        raise ValueError("parent_ratios must match parent_count")

    completed_ratios: list[float] = []
    level = parent_ratios[-1]
    for value in relative_returns:
        level += value
        completed_ratios.append(level)

    completed_xau, completed_xag = make_month(completed_key, completed_ratios)
    parent_xau, parent_xag = make_month(parent_key, parent_ratios)
    xau = completed_xau + parent_xau
    xag = completed_xag + parent_xag

    padding_key = previous_month_key(parent_key)
    while len(xau) < HISTORY_BARS:
        count = min(23, HISTORY_BARS - len(xau))
        padding_xau, padding_xag = make_month(padding_key, [anchor - 0.5] * count)
        xau.extend(padding_xau)
        xag.extend(padding_xag)
        padding_key = previous_month_key(padding_key)
    if len(xau) != HISTORY_BARS:
        raise ValueError("fixture exceeds the fixed history buffer")
    return xau, xag


def synchronized_pair_valid(
    xau_bars: list[CloseBar], xag_bars: list[CloseBar], index: int
) -> bool:
    if not 0 <= index < len(xau_bars) or index >= len(xag_bars):
        return False
    xau, xag = xau_bars[index], xag_bars[index]
    if (
        xau.opened != xag.opened
        or not all(math.isfinite(value) and value > 0.0 for value in (xau.close, xag.close))
    ):
        return False
    if index > 0 and (
        xau_bars[index - 1].opened <= xau.opened
        or xag_bars[index - 1].opened <= xag.opened
    ):
        return False
    return True


def monthly_ratio_breadth(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
    minimum: int = 17,
    maximum: int = 23,
    history_bars: int = HISTORY_BARS,
) -> BreadthResult:
    """Mirror the EA's bounded two-month aggregation and orientation."""

    if (
        current_month <= 0
        or history_bars != HISTORY_BARS
        or minimum > maximum
        or history_bars < 2 * maximum + 1
        or len(xau_bars) != history_bars
        or len(xag_bars) != history_bars
        or not synchronized_pair_valid(xau_bars, xag_bars, 0)
    ):
        return BreadthResult()

    completed_key = month_key(xau_bars[0].opened)
    if month_key(xag_bars[0].opened) != completed_key or next_month_key(completed_key) != current_month:
        return BreadthResult()

    newest_ratios: list[float] = []
    index = 0
    while index < history_bars and month_key(xau_bars[index].opened) == completed_key:
        if (
            len(newest_ratios) >= maximum
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != completed_key
        ):
            return BreadthResult()
        newest_ratios.append(math.log(xau_bars[index].close) - math.log(xag_bars[index].close))
        index += 1

    if not minimum <= len(newest_ratios) <= maximum or index >= history_bars:
        return BreadthResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return BreadthResult()
    parent_key = month_key(xau_bars[index].opened)
    if month_key(xag_bars[index].opened) != parent_key or next_month_key(parent_key) != completed_key:
        return BreadthResult()

    parent_sessions = 0
    parent_final_ratio = 0.0
    while index < history_bars and month_key(xau_bars[index].opened) == parent_key:
        if (
            parent_sessions >= maximum
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != parent_key
        ):
            return BreadthResult()
        ratio = math.log(xau_bars[index].close) - math.log(xag_bars[index].close)
        if parent_sessions == 0:
            parent_final_ratio = ratio
        parent_sessions += 1
        index += 1

    if not minimum <= parent_sessions <= maximum or index >= history_bars:
        return BreadthResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return BreadthResult()
    older_key = month_key(xau_bars[index].opened)
    if month_key(xag_bars[index].opened) != older_key or next_month_key(older_key) != parent_key:
        return BreadthResult()

    positive = 0
    negative = 0
    previous_ratio = parent_final_ratio
    for ratio in reversed(newest_ratios):
        relative_return = ratio - previous_ratio
        if relative_return > 0.0:
            positive += 1
        elif relative_return < 0.0:
            negative += 1
        previous_ratio = ratio

    endpoint_net = newest_ratios[0] - parent_final_ratio
    direction = 0
    if 2 * positive > len(newest_ratios) and endpoint_net > 0.0:
        direction = -1
    elif 2 * negative > len(newest_ratios) and endpoint_net < 0.0:
        direction = 1
    return BreadthResult(
        True,
        direction,
        len(newest_ratios),
        parent_sessions,
        positive,
        negative,
        endpoint_net,
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


class MonthlyRatioBreadthReferenceTest(unittest.TestCase):
    def signal(self, returns: list[float], **kwargs) -> BreadthResult:
        xau, xag = sample(returns, **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_ratio_breadth(next_month_key(completed_key), xau, xag)

    def test_positive_strict_majority_and_positive_net_are_faded(self) -> None:
        result = self.signal([0.02] * 11 + [-0.01] * 9)
        self.assertTrue(result.valid)
        self.assertEqual(result.direction, -1)
        self.assertEqual((result.positive, result.negative), (11, 9))
        self.assertGreater(result.endpoint_net, 0.0)

    def test_negative_strict_majority_and_negative_net_are_faded(self) -> None:
        result = self.signal([-0.02] * 11 + [0.01] * 9)
        self.assertTrue(result.valid)
        self.assertEqual(result.direction, 1)
        self.assertEqual((result.positive, result.negative), (9, 11))
        self.assertLess(result.endpoint_net, 0.0)

    def test_majority_endpoint_disagreement_is_flat(self) -> None:
        result = self.signal([0.01] * 11 + [-0.02] * 9)
        self.assertTrue(result.valid)
        self.assertEqual(result.positive, 11)
        self.assertLess(result.endpoint_net, 0.0)
        self.assertEqual(result.direction, 0)

    def test_equal_return_stays_in_strict_majority_denominator(self) -> None:
        result = self.signal([0.02] * 9 + [-0.01] * 8 + [0.0])
        self.assertTrue(result.valid)
        self.assertEqual(result.completed_sessions, 18)
        self.assertEqual((result.positive, result.negative), (9, 8))
        self.assertGreater(result.endpoint_net, 0.0)
        self.assertEqual(result.direction, 0)

    def test_both_month_session_bounds_are_exact(self) -> None:
        for completed_count in (17, 20, 23):
            result = self.signal([0.02] * (completed_count // 2 + 1) + [-0.01] * (completed_count // 2 - (0 if completed_count % 2 else 1)))
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, completed_count)
        for parent_count in (17, 20, 23):
            self.assertTrue(self.signal([0.02] * 11 + [-0.01] * 9, parent_count=parent_count).valid)
        for completed_count in (16, 24):
            returns = [0.02] * (completed_count // 2 + 1) + [-0.01] * (completed_count - completed_count // 2 - 1)
            self.assertFalse(self.signal(returns).valid)
        for parent_count in (16, 24):
            self.assertFalse(self.signal([0.02] * 11 + [-0.01] * 9, parent_count=parent_count).valid)

    def test_asynchronous_and_non_descending_pairs_are_rejected(self) -> None:
        xau, xag = sample([0.02] * 11 + [-0.01] * 9)
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_ratio_breadth(202608, xau, xag).valid)

        xau, xag = sample([0.02] * 11 + [-0.01] * 9)
        xau[2] = CloseBar(xau[1].opened, xau[2].close)
        xag[2] = CloseBar(xag[1].opened, xag[2].close)
        self.assertFalse(monthly_ratio_breadth(202608, xau, xag).valid)

    def test_invalid_close_current_month_leak_and_short_buffer_are_rejected(self) -> None:
        xau, xag = sample([0.02] * 11 + [-0.01] * 9)
        xau[3] = CloseBar(xau[3].opened, float("nan"))
        self.assertFalse(monthly_ratio_breadth(202608, xau, xag).valid)

        xau, xag = sample([0.02] * 11 + [-0.01] * 9)
        current = datetime(2026, 8, 1, tzinfo=UTC)
        xau[0] = CloseBar(current, xau[0].close)
        xag[0] = CloseBar(current, xag[0].close)
        self.assertFalse(monthly_ratio_breadth(202608, xau, xag).valid)

        xau, xag = sample([0.02] * 11 + [-0.01] * 9)
        self.assertFalse(monthly_ratio_breadth(202608, xau[:-1], xag[:-1]).valid)

    def test_parent_and_completed_months_must_be_consecutive(self) -> None:
        result = self.signal(
            [0.02] * 11 + [-0.01] * 9,
            completed_key=202607,
            parent_key=202605,
        )
        self.assertFalse(result.valid)

    def test_parent_chronological_final_is_the_anchor(self) -> None:
        parent = [5.50] + [4.00] * 18 + [4.25]
        result = self.signal(
            [0.02] * 11 + [-0.01] * 9,
            parent_count=20,
            parent_ratios=parent,
        )
        self.assertTrue(result.valid)
        self.assertEqual(result.direction, -1)
        self.assertAlmostEqual(result.endpoint_net, 0.13, places=10)

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
        result = self.signal(
            [0.02] * 11 + [-0.01] * 9,
            completed_key=202612,
            parent_key=202611,
        )
        self.assertTrue(result.valid)
        self.assertEqual(next_month_key(202612), 202701)
        opened = datetime(2026, 12, 2, tzinfo=UTC)
        self.assertEqual(month_key(opened), month_key(datetime(2026, 12, 31, tzinfo=UTC)))
        self.assertNotEqual(month_key(opened), month_key(datetime(2027, 1, 1, tzinfo=UTC)))
        xau, xag, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41112_xauxag-mdaybreadth-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41112_xauxag-mdaybreadth-rv_QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41112;",
            "strategy_history_bars_d1         = 70;",
            "CopyRates(g_leg_xau",
            "PERIOD_D1, 1, strategy_history_bars_d1",
            "if(parent_month_sessions == 0)",
            "newest_ratios[series_index] - previous_ratio",
            "endpoint_net = newest_ratios[0] - parent_final_ratio;",
            "if(2 * positive_count > completed_month_sessions && endpoint_net > 0.0)",
            "else if(2 * negative_count > completed_month_sessions && endpoint_net < 0.0)",
            "QM_ATR(g_leg_xau, PERIOD_D1, strategy_atr_period_d1, 1)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
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
            "qm_ea_id=41112",
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
        self.assertEqual(manifest["logical_symbol"], "QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41112_xauxag-mdaybreadth-rv_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())


if __name__ == "__main__":
    unittest.main()
