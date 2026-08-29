"""Independent deterministic fixtures for QM5_41192's daily pseudomedian basket."""

from __future__ import annotations

import json
import math
import random
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
HISTORY_BARS = 45
MAX_PAIR_COUNT = 276
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class PseudomedianResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    return_count: int = 0
    raw_displacement: float = 0.0
    endpoint_displacement: float = 0.0
    pair_count: int = 0
    median_left_index: int = -1
    median_right_index: int = -1
    pseudomedian: float = 0.0
    returns: tuple[float, ...] = ()
    sorted_pairwise: tuple[float, ...] = ()


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
    xti_current: datetime,
    xng_current: datetime,
    newest_completed: datetime,
) -> tuple[bool, bool, int]:
    key = month_key(now)
    exact_current = (
        xti_current == xng_current
        and xti_current.date() == now.date()
        and month_key(xti_current) == key
    )
    if not exact_current:
        return False, False, key
    late = not within_entry_grace(now, xti_current) or month_key(newest_completed) == key
    return True, late, key


def cumulative_ratios(returns: list[float], boundary: float = 0.0) -> list[float]:
    ratios: list[float] = []
    current = boundary
    for value in returns:
        current += value
        ratios.append(current)
    return ratios


def make_month(key: int, ratios: list[float]) -> tuple[list[CloseBar], list[CloseBar]]:
    year, month = divmod(key, 100)
    xti: list[CloseBar] = []
    xng: list[CloseBar] = []
    for day, ratio in enumerate(ratios, start=1):
        opened = datetime(year, month, day, tzinfo=UTC)
        xti.append(CloseBar(opened, math.exp(ratio)))
        xng.append(CloseBar(opened, 1.0))
    return list(reversed(xti)), list(reversed(xng))


def sample(
    returns: list[float],
    *,
    completed_key: int = 202607,
    older_key: int | None = None,
) -> tuple[list[CloseBar], list[CloseBar]]:
    """Build a fixed newest-first pair with an exact older boundary ratio."""

    if older_key is None:
        older_key = previous_month_key(completed_key)
    xti, xng = make_month(completed_key, cumulative_ratios(returns))
    older_count = min(23, HISTORY_BARS - len(xti))
    older_ratios = [-0.1 - 0.001 * index for index in range(older_count - 1)] + [0.0]
    older_xti, older_xng = make_month(older_key, older_ratios)
    xti.extend(older_xti)
    xng.extend(older_xng)
    padding_key = previous_month_key(older_key)
    while len(xti) < HISTORY_BARS:
        count = min(23, HISTORY_BARS - len(xti))
        padding = [-0.2 - 0.001 * index for index in range(count)]
        padding_xti, padding_xng = make_month(padding_key, padding)
        xti.extend(padding_xti)
        xng.extend(padding_xng)
        padding_key = previous_month_key(padding_key)
    if len(xti) != HISTORY_BARS:
        raise ValueError("fixture exceeds fixed history buffer")
    return xti, xng


def synchronized_pair_valid(
    xti_bars: list[CloseBar], xng_bars: list[CloseBar], index: int
) -> bool:
    if not 0 <= index < len(xti_bars) or index >= len(xng_bars):
        return False
    xti, xng = xti_bars[index], xng_bars[index]
    if (
        xti.opened != xng.opened
        or not all(math.isfinite(value) and value > 0.0 for value in (xti.close, xng.close))
    ):
        return False
    if index > 0 and (
        xti_bars[index - 1].opened <= xti.opened
        or xng_bars[index - 1].opened <= xng.opened
    ):
        return False
    return True


def classify_ratios(
    chronological: list[float],
    tolerance: float = TOLERANCE,
) -> PseudomedianResult:
    """Mirror the inclusive pairwise-average pseudomedian fade."""

    if len(chronological) < 18 or any(not math.isfinite(value) for value in chronological):
        return PseudomedianResult()
    return_count = len(chronological) - 1
    if not 17 <= return_count <= 23:
        return PseudomedianResult()
    returns = [
        chronological[index] - chronological[index - 1]
        for index in range(1, len(chronological))
    ]
    raw = sum(returns)
    endpoint = chronological[-1] - chronological[0]
    if (
        not all(math.isfinite(value) for value in (*returns, raw, endpoint))
        or abs(raw - endpoint) > tolerance * max(1.0, abs(endpoint))
    ):
        return PseudomedianResult(
            completed_sessions=return_count,
            return_count=return_count,
            raw_displacement=raw,
            endpoint_displacement=endpoint,
        )

    pairwise = tuple(
        (returns[left] + returns[right]) / 2.0
        for left in range(return_count)
        for right in range(left, return_count)
    )
    pair_count = return_count * (return_count + 1) // 2
    if len(pairwise) != pair_count or pair_count > MAX_PAIR_COUNT:
        return PseudomedianResult()
    for index, value in enumerate(returns):
        self_pair_index = sum(return_count - prior for prior in range(index))
        if not math.isclose(
            pairwise[self_pair_index], value, rel_tol=0.0, abs_tol=tolerance
        ):
            return PseudomedianResult()
    sorted_pairwise = tuple(sorted(pairwise))
    if not all(math.isfinite(value) for value in sorted_pairwise):
        return PseudomedianResult()
    median_left_index = (pair_count - 1) // 2
    median_right_index = pair_count // 2
    pseudomedian = (
        sorted_pairwise[median_left_index]
        if median_left_index == median_right_index
        else (
            sorted_pairwise[median_left_index]
            + sorted_pairwise[median_right_index]
        )
        / 2.0
    )
    if not math.isfinite(pseudomedian):
        return PseudomedianResult()
    direction = 1 if pseudomedian < 0.0 else -1 if pseudomedian > 0.0 else 0
    return PseudomedianResult(
        valid=True,
        direction=direction,
        completed_sessions=return_count,
        return_count=return_count,
        raw_displacement=raw,
        endpoint_displacement=endpoint,
        pair_count=pair_count,
        median_left_index=median_left_index,
        median_right_index=median_right_index,
        pseudomedian=pseudomedian,
        returns=tuple(returns),
        sorted_pairwise=sorted_pairwise,
    )


def monthly_daily_pseudomedian(
    current_month: int,
    xti_bars: list[CloseBar],
    xng_bars: list[CloseBar],
) -> PseudomedianResult:
    if (
        current_month <= 0
        or len(xti_bars) != HISTORY_BARS
        or len(xng_bars) != HISTORY_BARS
        or not synchronized_pair_valid(xti_bars, xng_bars, 0)
    ):
        return PseudomedianResult()
    completed_key = month_key(xti_bars[0].opened)
    if month_key(xng_bars[0].opened) != completed_key or next_month_key(completed_key) != current_month:
        return PseudomedianResult()

    series_ratios: list[float] = []
    index = 0
    while index < HISTORY_BARS and month_key(xti_bars[index].opened) == completed_key:
        if (
            len(series_ratios) >= 23
            or not synchronized_pair_valid(xti_bars, xng_bars, index)
            or month_key(xng_bars[index].opened) != completed_key
        ):
            return PseudomedianResult()
        ratio = math.log(xti_bars[index].close) - math.log(xng_bars[index].close)
        if not math.isfinite(ratio):
            return PseudomedianResult()
        series_ratios.append(ratio)
        index += 1

    if not 17 <= len(series_ratios) <= 23 or index >= HISTORY_BARS:
        return PseudomedianResult()
    if not synchronized_pair_valid(xti_bars, xng_bars, index):
        return PseudomedianResult()
    older_key = month_key(xti_bars[index].opened)
    if month_key(xng_bars[index].opened) != older_key or next_month_key(older_key) != completed_key:
        return PseudomedianResult()
    boundary = math.log(xti_bars[index].close) - math.log(xng_bars[index].close)
    return classify_ratios([boundary, *reversed(series_ratios)])


def round_down(value: float, step: float, minimum: float) -> float:
    rounded = math.floor((value + 1e-12) / step) * step
    return rounded if rounded + 1e-12 >= minimum else 0.0


def equal_notional_package(
    full_xti_lots: float,
    full_xng_lots: float,
    xti_notional_per_lot: float,
    xng_notional_per_lot: float,
) -> tuple[float, float, float, float]:
    lot_ratio = xng_notional_per_lot / xti_notional_per_lot
    normalized_per_xng_lot = lot_ratio / full_xti_lots + 1.0 / full_xng_lots
    xng_lots = round_down(1.0 / normalized_per_xng_lot, 0.01, 0.01)
    xti_lots = round_down(lot_ratio / normalized_per_xng_lot, 0.01, 0.01)
    risk = xti_lots / full_xti_lots + xng_lots / full_xng_lots
    ratio = xti_lots * xti_notional_per_lot / (xng_lots * xng_notional_per_lot)
    return xti_lots, xng_lots, risk, ratio


class AttemptLedger:
    def __init__(self) -> None:
        self.month = 0

    def consume(self, month: int) -> bool:
        if month <= 0 or month == self.month:
            return False
        self.month = month
        return True


class MonthlyDailyHodgesLehmannReversionReferenceTest(unittest.TestCase):
    def signal(self, returns: list[float], **kwargs: int) -> PseudomedianResult:
        xti, xng = sample(returns, **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_daily_pseudomedian(next_month_key(completed_key), xti, xng)

    def test_positive_and_negative_pseudomedians_are_faded(self) -> None:
        positive = [0.001 + 0.00001 * index for index in range(20)]
        negative = [-value for value in positive]
        self.assertGreater(self.signal(positive).pseudomedian, 0.0)
        self.assertEqual(self.signal(positive).direction, -1)
        self.assertLess(self.signal(negative).pseudomedian, 0.0)
        self.assertEqual(self.signal(negative).direction, 1)

    def test_raw_endpoint_cannot_override_opposite_pseudomedian(self) -> None:
        pseudomedian_positive_raw_negative = [-1.0, *([0.01] * 18), 0.02]
        pseudomedian_negative_raw_positive = [1.0, *([-0.01] * 18), -0.02]
        positive = classify_ratios(
            [0.0, *cumulative_ratios(pseudomedian_positive_raw_negative)]
        )
        negative = classify_ratios(
            [0.0, *cumulative_ratios(pseudomedian_negative_raw_positive)]
        )
        self.assertLess(positive.raw_displacement, 0.0)
        self.assertGreater(positive.pseudomedian, 0.0)
        self.assertEqual(positive.direction, -1)
        self.assertGreater(negative.raw_displacement, 0.0)
        self.assertLess(negative.pseudomedian, 0.0)
        self.assertEqual(negative.direction, 1)

    def test_exact_inclusive_pairs_dynamic_count_and_median(self) -> None:
        for count in range(17, 24):
            returns = [0.001 * (index - count / 3.0) for index in range(count)]
            result = classify_ratios([0.0, *cumulative_ratios(returns)])
            expected_pairwise = tuple(
                sorted(
                    (returns[left] + returns[right]) / 2.0
                    for left in range(count)
                    for right in range(left, count)
                )
            )
            expected_pair_count = count * (count + 1) // 2
            left_index = (expected_pair_count - 1) // 2
            right_index = expected_pair_count // 2
            expected_pseudomedian = (
                expected_pairwise[left_index]
                if left_index == right_index
                else (expected_pairwise[left_index] + expected_pairwise[right_index]) / 2.0
            )
            self.assertTrue(result.valid)
            self.assertEqual(result.pair_count, expected_pair_count)
            self.assertEqual(result.median_left_index, left_index)
            self.assertEqual(result.median_right_index, right_index)
            self.assertEqual(len(result.returns), count)
            self.assertEqual(len(result.sorted_pairwise), expected_pair_count)
            for actual, expected in zip(result.returns, returns):
                self.assertAlmostEqual(actual, expected, places=14)
            for actual, expected in zip(result.sorted_pairwise, expected_pairwise):
                self.assertAlmostEqual(actual, expected, places=14)
            self.assertAlmostEqual(result.pseudomedian, expected_pseudomedian, places=14)

    def test_exact_zero_returns_are_valid_and_flat(self) -> None:
        result = self.signal([0.0] * 17)
        self.assertTrue(result.valid)
        self.assertEqual(result.pair_count, 153)
        self.assertEqual(result.pseudomedian, 0.0)
        self.assertEqual(result.direction, 0)

    def test_pairwise_location_is_order_invariant(self) -> None:
        returns = [-0.5, 0.8, *[0.001 * index for index in range(-9, 9)]]
        shuffled = list(returns)
        random.Random(41192).shuffle(shuffled)
        ordered_result = classify_ratios([0.0, *cumulative_ratios(returns)])
        shuffled_result = classify_ratios([0.0, *cumulative_ratios(shuffled)])
        self.assertEqual(
            len(ordered_result.sorted_pairwise), len(shuffled_result.sorted_pairwise)
        )
        for ordered, permuted in zip(
            ordered_result.sorted_pairwise, shuffled_result.sorted_pairwise
        ):
            self.assertAlmostEqual(ordered, permuted, places=14)
        self.assertAlmostEqual(
            ordered_result.pseudomedian, shuffled_result.pseudomedian, places=14
        )
        self.assertEqual(ordered_result.direction, shuffled_result.direction)

    def test_every_allowed_count_includes_boundary_return_once(self) -> None:
        for count in range(17, 24):
            returns = [0.001 + 0.0001 * index for index in range(count)]
            result = self.signal(returns)
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, count)
            self.assertEqual(result.return_count, count)
            self.assertEqual(result.pair_count, count * (count + 1) // 2)
            self.assertAlmostEqual(result.raw_displacement, sum(returns), places=12)
            self.assertAlmostEqual(result.endpoint_displacement, sum(returns), places=12)

    def test_session_synchronization_and_adjacent_boundary_are_exact(self) -> None:
        for count in (17, 20, 23):
            returns = [0.001 + 0.0001 * index for index in range(count)]
            self.assertTrue(self.signal(returns).valid)
        for count in (16, 24):
            self.assertFalse(self.signal([0.001] * count).valid)
        xti, xng = sample([0.001 + 0.0001 * index for index in range(20)])
        xng[4] = CloseBar(xng[4].opened + timedelta(hours=1), xng[4].close)
        self.assertFalse(monthly_daily_pseudomedian(202608, xti, xng).valid)
        xti, xng = sample([0.001] * 20, older_key=202605)
        self.assertFalse(monthly_daily_pseudomedian(202608, xti, xng).valid)

    def test_clock_attempt_year_boundary_and_joint_risk(self) -> None:
        current = datetime(2026, 8, 3, tzinfo=UTC)
        now = current + timedelta(minutes=180)
        completed = datetime(2026, 7, 31, tzinfo=UTC)
        self.assertEqual(decision_clock(now, current, current, completed), (True, False, 202608))
        self.assertTrue(decision_clock(now + timedelta(minutes=1), current, current, completed)[1])
        ledger = AttemptLedger()
        self.assertTrue(ledger.consume(202608))
        self.assertFalse(ledger.consume(202608))
        self.assertEqual(next_month_key(202612), 202701)

        xti_lots, xng_lots, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xti_lots, 0.0)
        self.assertGreater(xng_lots, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41192_xtixng-mdaily-hl-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41192_xtixng-mdaily-hl-rv_QM5_41192_XTI_XNG_MDAILY_HL_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41192;",
            "input int    strategy_max_pair_count          = 276;",
            "chronological_ratios[0]",
            "daily_returns[i - 1] = relative_return;",
            "pair_count = return_count * (return_count + 1) / 2;",
            "for(int j = i; j < return_count; ++j)",
            "pairwise_averages[pair_index] = pair_average;",
            "MathAbs(pair_average - daily_returns[i])",
            "MathAbs(raw_displacement - endpoint_displacement)",
            "!ArraySort(pairwise_averages)",
            "median_left_index = (pair_count - 1) / 2;",
            "median_right_index = pair_count / 2;",
            "if(pseudomedian < 0.0)",
            "else if(pseudomedian > 0.0)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
            "request.tp = 0.0;",
            "strategy_notional_ratio",
        ):
            self.assertIn(marker, source)
        for banned in ("irsi(", "imacd(", "ibands(", "webrequest("):
            self.assertNotIn(banned, source.lower())
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntrySignal(request)"),
        )
        for marker in (
            "qm_ea_id=41192",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_max_pair_count=276",
            "strategy_numerical_tolerance=1.0e-10",
            "strategy_atr_sl_mult=3.5",
            "strategy_xng_max_spread_points=3000",
        ):
            self.assertIn(marker, setfile)
        self.assertEqual(manifest["logical_symbol"], "QM5_41192_XTI_XNG_MDAILY_HL_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XTIUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])

        approved = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41192_xtixng-mdaily-hl-rv_card.md"
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(
            local.read_text(encoding="utf-8").rstrip(),
            approved.read_text(encoding="utf-8").rstrip(),
        )
        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(encoding="utf-8-sig")
        self.assertIn("41192,xtixng-mdaily-hl-rv,0,XTIUSD.DWX,411920000", magic_rows)
        self.assertIn("41192,xtixng-mdaily-hl-rv,1,XNGUSD.DWX,411920001", magic_rows)
        resolver = (REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh").read_text(encoding="utf-8")
        self.assertIn("411920000", resolver)
        self.assertIn("411920001", resolver)


if __name__ == "__main__":
    unittest.main()
