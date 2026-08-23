"""Independent deterministic fixtures for QM5_41120's residence basket."""

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
HISTORY_BARS = 45


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class ResidenceResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    later_observations: int = 0
    above_anchor: int = 0
    below_anchor: int = 0
    required_residence: int = 0
    anchor: float = 0.0
    final_ratio: float = 0.0


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
        xau.append(CloseBar(opened, math.exp(ratio)))
        xag.append(CloseBar(opened, 1.0))
    return list(reversed(xau)), list(reversed(xag))


def sample(
    completed_ratios: list[float],
    *,
    completed_key: int = 202607,
    older_key: int | None = None,
) -> tuple[list[CloseBar], list[CloseBar]]:
    """Build an exact 45-bar newest-first pair plus adjacent older boundary."""

    if older_key is None:
        older_key = previous_month_key(completed_key)
    xau, xag = make_month(completed_key, completed_ratios)
    padding_key = older_key
    while len(xau) < HISTORY_BARS:
        count = min(23, HISTORY_BARS - len(xau))
        padding_ratios = [-0.01 - index * 0.0001 for index in range(count)]
        padding_xau, padding_xag = make_month(padding_key, padding_ratios)
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


def monthly_open_residence(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
    minimum: int = 17,
    maximum: int = 23,
    numerator: int = 3,
    denominator: int = 4,
    history_bars: int = HISTORY_BARS,
) -> ResidenceResult:
    """Mirror exact month reconstruction, strict residence, and inverse side."""

    if (
        current_month <= 0
        or history_bars != HISTORY_BARS
        or minimum != 17
        or maximum != 23
        or numerator != 3
        or denominator != 4
        or minimum > maximum
        or history_bars < maximum + 1
        or len(xau_bars) != history_bars
        or len(xag_bars) != history_bars
        or not synchronized_pair_valid(xau_bars, xag_bars, 0)
    ):
        return ResidenceResult()

    completed_key = month_key(xau_bars[0].opened)
    if (
        month_key(xag_bars[0].opened) != completed_key
        or next_month_key(completed_key) != current_month
    ):
        return ResidenceResult()

    series_ratios: list[float] = []
    index = 0
    while index < history_bars and month_key(xau_bars[index].opened) == completed_key:
        if (
            len(series_ratios) >= maximum
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != completed_key
        ):
            return ResidenceResult()
        ratio = math.log(xau_bars[index].close) - math.log(xag_bars[index].close)
        if not math.isfinite(ratio):
            return ResidenceResult()
        series_ratios.append(ratio)
        index += 1

    if not minimum <= len(series_ratios) <= maximum or index >= history_bars:
        return ResidenceResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return ResidenceResult()
    older_key = month_key(xau_bars[index].opened)
    if (
        month_key(xag_bars[index].opened) != older_key
        or next_month_key(older_key) != completed_key
    ):
        return ResidenceResult()

    chronological = list(reversed(series_ratios))
    anchor = chronological[0]
    final_ratio = chronological[-1]
    if not math.isfinite(anchor) or not math.isfinite(final_ratio):
        return ResidenceResult()

    later = chronological[1:]
    above = sum(value > anchor for value in later)
    below = sum(value < anchor for value in later)
    required = (numerator * len(later) + denominator - 1) // denominator
    if not 1 <= required <= len(later) or above + below > len(later):
        return ResidenceResult()

    direction = 0
    if above >= required and final_ratio > anchor:
        direction = -1
    elif below >= required and final_ratio < anchor:
        direction = 1
    return ResidenceResult(
        True,
        direction,
        len(chronological),
        len(later),
        above,
        below,
        required,
        anchor,
        final_ratio,
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


class MonthlyOpenResidenceReferenceTest(unittest.TestCase):
    def signal(self, ratios: list[float], **kwargs: int) -> ResidenceResult:
        xau, xag = sample(ratios, **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_open_residence(next_month_key(completed_key), xau, xag)

    @staticmethod
    def exact_upper(count: int) -> list[float]:
        later = count - 1
        required = (3 * later + 3) // 4
        ties = later - required
        return [0.0] + [0.01] * (required - 1) + [0.0] * ties + [0.01]

    @staticmethod
    def exact_lower(count: int) -> list[float]:
        return [-value for value in MonthlyOpenResidenceReferenceTest.exact_upper(count)]

    def test_every_allowed_session_count_has_exact_ceiling_arithmetic(self) -> None:
        for count in range(17, 24):
            result = self.signal(self.exact_upper(count))
            later = count - 1
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, count)
            self.assertEqual(result.later_observations, later)
            self.assertEqual(result.required_residence, (3 * later + 3) // 4)
            self.assertEqual(result.above_anchor, result.required_residence)
            self.assertEqual(result.direction, -1)

    def test_exact_upper_and_lower_thresholds_fade_residence_side(self) -> None:
        upper = self.signal(self.exact_upper(20))
        self.assertEqual((upper.above_anchor, upper.below_anchor), (15, 0))
        self.assertEqual(upper.required_residence, 15)
        self.assertEqual(upper.direction, -1)

        lower = self.signal(self.exact_lower(20))
        self.assertEqual((lower.above_anchor, lower.below_anchor), (0, 15))
        self.assertEqual(lower.required_residence, 15)
        self.assertEqual(lower.direction, 1)

    def test_strict_ties_are_neutral_and_final_side_confirmation_is_required(self) -> None:
        tie_heavy = [0.0] + [0.01] * 14 + [0.0] * 5
        result = self.signal(tie_heavy)
        self.assertTrue(result.valid)
        self.assertEqual((result.above_anchor, result.below_anchor), (14, 0))
        self.assertEqual(result.required_residence, 15)
        self.assertEqual(result.direction, 0)

        final_tie = [0.0] + [0.01] * 15 + [0.0] * 4
        result = self.signal(final_tie)
        self.assertTrue(result.valid)
        self.assertEqual(result.above_anchor, result.required_residence)
        self.assertEqual(result.final_ratio, result.anchor)
        self.assertEqual(result.direction, 0)

    def test_first_close_is_immutable_anchor_and_chronology_matters(self) -> None:
        ordered = self.exact_upper(17)
        rotated = [ordered[-1], *ordered[:-1]]
        first = self.signal(ordered)
        second = self.signal(rotated)
        self.assertEqual(sorted(ordered), sorted(rotated))
        self.assertEqual(first.direction, -1)
        self.assertEqual(second.direction, 0)
        self.assertNotEqual(first.anchor, second.anchor)

    def test_session_bounds_synchronization_and_month_boundaries_are_exact(self) -> None:
        for count in (17, 20, 23):
            self.assertTrue(self.signal(self.exact_upper(count)).valid)
        for count in (16, 24):
            self.assertFalse(self.signal(self.exact_upper(count)).valid)

        xau, xag = sample(self.exact_upper(20))
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_open_residence(202608, xau, xag).valid)

        xau, xag = sample(self.exact_upper(20))
        xau[2] = CloseBar(xau[1].opened, xau[2].close)
        xag[2] = CloseBar(xag[1].opened, xag[2].close)
        self.assertFalse(monthly_open_residence(202608, xau, xag).valid)

        xau, xag = sample(self.exact_upper(20), older_key=202605)
        self.assertFalse(monthly_open_residence(202608, xau, xag).valid)
        self.assertFalse(monthly_open_residence(202609, xau, xag).valid)

    def test_clock_attempt_year_boundary_and_joint_risk_are_bounded(self) -> None:
        current = datetime(2026, 8, 3, tzinfo=UTC)
        now = current + timedelta(minutes=180)
        completed = datetime(2026, 7, 31, tzinfo=UTC)
        self.assertEqual(decision_clock(now, current, current, completed), (True, False, 202608))
        self.assertTrue(decision_clock(now + timedelta(minutes=1), current, current, completed)[1])
        self.assertFalse(decision_clock(now, current, current + timedelta(hours=1), completed)[0])
        ledger = AttemptLedger()
        self.assertTrue(ledger.consume(202608))
        self.assertFalse(ledger.consume(202608))
        self.assertEqual(next_month_key(202612), 202701)
        year_boundary = self.signal(self.exact_lower(20), completed_key=202612)
        self.assertTrue(year_boundary.valid)
        self.assertEqual(year_boundary.direction, 1)

        xau, xag, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41120_xauxag-mopen-residence-rv.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41120_xauxag-mopen-residence-rv_QM5_41120_XAU_XAG_MOPEN_RESIDENCE_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41120;",
            "input int    strategy_residence_numerator       = 3;",
            "input int    strategy_residence_denominator     = 4;",
            "CopyRates(g_leg_xau",
            "PERIOD_D1, 1, strategy_history_bars_d1",
            "chronological_ratios[i] = ratio;",
            "anchor = chronological_ratios[0];",
            "if(ratio > anchor)",
            "else if(ratio < anchor)",
            "strategy_residence_numerator * later_observations",
            "above_anchor >= required_residence && final_ratio > anchor",
            "below_anchor >= required_residence && final_ratio < anchor",
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
            "qm_ea_id=41120",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_residence_numerator=3",
            "strategy_residence_denominator=4",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertEqual(
            manifest["logical_symbol"], "QM5_41120_XAU_XAG_MOPEN_RESIDENCE_RV_D1"
        )
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41120_xauxag-mopen-residence-rv_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())

        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(
            encoding="utf-8-sig"
        )
        self.assertIn("41120,xauxag-mopen-residence-rv,0,XAUUSD.DWX,411200000", magic_rows)
        self.assertIn("41120,xauxag-mopen-residence-rv,1,XAGUSD.DWX,411200001", magic_rows)


if __name__ == "__main__":
    unittest.main()
