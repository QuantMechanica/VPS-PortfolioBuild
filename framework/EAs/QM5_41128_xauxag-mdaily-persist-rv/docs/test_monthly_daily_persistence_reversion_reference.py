"""Independent deterministic fixtures for QM5_41128's persistence basket."""

from __future__ import annotations

import json
import math
import random
import unittest
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
HISTORY_BARS = 45
THRESHOLD = 0.0
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class PersistenceResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    return_count: int = 0
    net_displacement: float = 0.0
    endpoint_displacement: float = 0.0
    return_mean: float = 0.0
    squared_deviation_sum: float = 0.0
    adjacent_product_sum: float = 0.0
    lag_one_autocorrelation: float = 0.0
    bias_adjustment: float = 0.0
    persistence_score: float = 0.0


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


def cumulative_ratios(returns: list[float], boundary: float = 0.0) -> list[float]:
    ratios: list[float] = []
    current = boundary
    for value in returns:
        current += value
        ratios.append(current)
    return ratios


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
    returns: list[float],
    *,
    completed_key: int = 202607,
    older_key: int | None = None,
) -> tuple[list[CloseBar], list[CloseBar]]:
    """Build a fixed newest-first pair with an exact older boundary ratio."""

    if older_key is None:
        older_key = previous_month_key(completed_key)
    xau, xag = make_month(completed_key, cumulative_ratios(returns))
    older_count = min(23, HISTORY_BARS - len(xau))
    older_ratios = [-0.1 - 0.001 * index for index in range(older_count - 1)] + [0.0]
    older_xau, older_xag = make_month(older_key, older_ratios)
    xau.extend(older_xau)
    xag.extend(older_xag)
    padding_key = previous_month_key(older_key)
    while len(xau) < HISTORY_BARS:
        count = min(23, HISTORY_BARS - len(xau))
        padding = [-0.2 - 0.001 * index for index in range(count)]
        padding_xau, padding_xag = make_month(padding_key, padding)
        xau.extend(padding_xau)
        xag.extend(padding_xag)
        padding_key = previous_month_key(padding_key)
    if len(xau) != HISTORY_BARS:
        raise ValueError("fixture exceeds fixed history buffer")
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


def classify_ratios(
    chronological: list[float],
    threshold: float = THRESHOLD,
    tolerance: float = TOLERANCE,
) -> PersistenceResult:
    """Mirror the boundary-plus-month centered lag-one score and fade side."""

    if len(chronological) < 18 or any(not math.isfinite(value) for value in chronological):
        return PersistenceResult()
    return_count = len(chronological) - 1
    if not 17 <= return_count <= 23:
        return PersistenceResult()
    returns = [
        chronological[index] - chronological[index - 1]
        for index in range(1, len(chronological))
    ]
    net = sum(returns)
    endpoint = chronological[-1] - chronological[0]
    mean = net / return_count
    result = PersistenceResult(
        completed_sessions=return_count,
        return_count=return_count,
        net_displacement=net,
        endpoint_displacement=endpoint,
        return_mean=mean,
    )
    if (
        not all(math.isfinite(value) for value in (*returns, net, endpoint, mean))
        or abs(net - endpoint) > tolerance * max(1.0, abs(endpoint))
    ):
        return result

    centered = [value - mean for value in returns]
    squared_deviation_sum = sum(value * value for value in centered)
    result = replace(result, squared_deviation_sum=squared_deviation_sum)
    if squared_deviation_sum == 0.0:
        return replace(result, valid=True)
    if squared_deviation_sum < 0.0 or not math.isfinite(squared_deviation_sum):
        return result

    adjacent_product_sum = sum(
        centered[index] * centered[index - 1]
        for index in range(1, return_count)
    )
    rho = adjacent_product_sum / squared_deviation_sum
    result = replace(result, adjacent_product_sum=adjacent_product_sum)
    if (
        not math.isfinite(adjacent_product_sum)
        or not math.isfinite(rho)
        or rho < -1.0 - tolerance
        or rho > 1.0 + tolerance
    ):
        return result
    rho = min(1.0, max(-1.0, rho))
    bias = 1.0 / (return_count - 1)
    score = rho + bias
    if not math.isfinite(score):
        return result
    direction = 0
    if score > threshold:
        direction = 1 if net < 0.0 else -1 if net > 0.0 else 0
    return replace(
        result,
        valid=True,
        direction=direction,
        lag_one_autocorrelation=rho,
        bias_adjustment=bias,
        persistence_score=score,
    )


def monthly_daily_persistence(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
) -> PersistenceResult:
    if (
        current_month <= 0
        or len(xau_bars) != HISTORY_BARS
        or len(xag_bars) != HISTORY_BARS
        or not synchronized_pair_valid(xau_bars, xag_bars, 0)
    ):
        return PersistenceResult()
    completed_key = month_key(xau_bars[0].opened)
    if month_key(xag_bars[0].opened) != completed_key or next_month_key(completed_key) != current_month:
        return PersistenceResult()

    series_ratios: list[float] = []
    index = 0
    while index < HISTORY_BARS and month_key(xau_bars[index].opened) == completed_key:
        if (
            len(series_ratios) >= 23
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != completed_key
        ):
            return PersistenceResult()
        ratio = math.log(xau_bars[index].close) - math.log(xag_bars[index].close)
        if not math.isfinite(ratio):
            return PersistenceResult()
        series_ratios.append(ratio)
        index += 1

    if not 17 <= len(series_ratios) <= 23 or index >= HISTORY_BARS:
        return PersistenceResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return PersistenceResult()
    older_key = month_key(xau_bars[index].opened)
    if month_key(xag_bars[index].opened) != older_key or next_month_key(older_key) != completed_key:
        return PersistenceResult()
    boundary = math.log(xau_bars[index].close) - math.log(xag_bars[index].close)
    return classify_ratios([boundary, *reversed(series_ratios)])


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
    ratio = xau_lots * xau_notional_per_lot / (xag_lots * xag_notional_per_lot)
    return xau_lots, xag_lots, risk, ratio


class AttemptLedger:
    def __init__(self) -> None:
        self.month = 0

    def consume(self, month: int) -> bool:
        if month <= 0 or month == self.month:
            return False
        self.month = month
        return True


class MonthlyDailyPersistenceReversionReferenceTest(unittest.TestCase):
    def signal(self, returns: list[float], **kwargs: int) -> PersistenceResult:
        xau, xag = sample(returns, **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_daily_persistence(next_month_key(completed_key), xau, xag)

    def test_persistent_positive_and_negative_paths_fade_net(self) -> None:
        positive = [0.001 + 0.0001 * index for index in range(20)]
        negative = [-value for value in positive]
        self.assertGreater(self.signal(positive).persistence_score, 0.0)
        self.assertEqual(self.signal(positive).direction, -1)
        self.assertEqual(self.signal(negative).direction, 1)

    def test_alternating_path_is_nonpositive_and_flat(self) -> None:
        returns = [0.01 if index % 2 == 0 else -0.009 for index in range(20)]
        result = self.signal(returns)
        self.assertTrue(result.valid)
        self.assertLessEqual(result.persistence_score, 0.0)
        self.assertEqual(result.direction, 0)

    def test_exact_zero_returns_have_zero_variance_and_are_flat(self) -> None:
        result = self.signal([0.0] * 17)
        self.assertTrue(result.valid)
        self.assertEqual(result.squared_deviation_sum, 0.0)
        self.assertEqual(result.direction, 0)

    def test_every_allowed_count_includes_boundary_return_once(self) -> None:
        for count in range(17, 24):
            returns = [0.001 + 0.0001 * index for index in range(count)]
            result = self.signal(returns)
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, count)
            self.assertEqual(result.return_count, count)
            self.assertAlmostEqual(result.net_displacement, sum(returns), places=12)
            self.assertAlmostEqual(result.bias_adjustment, 1.0 / (count - 1), places=15)

    def test_adjacent_order_is_load_bearing_and_threshold_is_strict(self) -> None:
        returns = [0.001 + 0.0001 * (index % 5) for index in range(20)]
        ordered = classify_ratios([0.0, *cumulative_ratios(returns)])
        shuffled_returns = list(returns)
        random.Random(41128).shuffle(shuffled_returns)
        shuffled = classify_ratios([0.0, *cumulative_ratios(shuffled_returns)])
        self.assertNotAlmostEqual(
            ordered.adjacent_product_sum,
            shuffled.adjacent_product_sum,
            places=12,
        )
        at_equality = classify_ratios(
            [0.0, *cumulative_ratios(returns)],
            threshold=ordered.persistence_score,
        )
        self.assertEqual(at_equality.direction, 0)

    def test_session_synchronization_and_adjacent_boundary_are_exact(self) -> None:
        for count in (17, 20, 23):
            returns = [0.001 + 0.0001 * index for index in range(count)]
            self.assertTrue(self.signal(returns).valid)
        for count in (16, 24):
            self.assertFalse(self.signal([0.001] * count).valid)
        xau, xag = sample([0.001 + 0.0001 * index for index in range(20)])
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_daily_persistence(202608, xau, xag).valid)
        xau, xag = sample([0.001] * 20, older_key=202605)
        self.assertFalse(monthly_daily_persistence(202608, xau, xag).valid)

    def test_clock_attempt_year_boundary_density_and_joint_risk(self) -> None:
        current = datetime(2026, 8, 3, tzinfo=UTC)
        now = current + timedelta(minutes=180)
        completed = datetime(2026, 7, 31, tzinfo=UTC)
        self.assertEqual(decision_clock(now, current, current, completed), (True, False, 202608))
        self.assertTrue(decision_clock(now + timedelta(minutes=1), current, current, completed)[1])
        ledger = AttemptLedger()
        self.assertTrue(ledger.consume(202608))
        self.assertFalse(ledger.consume(202608))
        self.assertEqual(next_month_key(202612), 202701)

        rng = random.Random(20260823)
        for count in (17, 20, 23):
            qualified = 0
            for _ in range(5000):
                values = [rng.gauss(0.0, 1.0) for _ in range(count)]
                qualified += classify_ratios([0.0, *cumulative_ratios(values)]).direction != 0
            self.assertGreater(qualified / 5000, 0.45)
            self.assertLess(qualified / 5000, 0.55)
        xau_lots, xag_lots, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau_lots, 0.0)
        self.assertGreater(xag_lots, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41128_xauxag-mdaily-persist-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41128_xauxag-mdaily-persist-rv_QM5_41128_XAU_XAG_MDAILY_PERSIST_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41128;",
            "input bool   strategy_sample_bias_adjustment    = true;",
            "input double strategy_persistence_threshold     = 0.0;",
            "chronological_ratios[0]",
            "daily_returns[i - 1] = relative_return;",
            "return_mean = net_displacement / (double)return_count;",
            "adjacent_product_sum += product;",
            "adjacent_product_sum / squared_deviation_sum",
            "1.0 / (double)(return_count - 1)",
            "persistence_score > strategy_persistence_threshold",
            "if(net_displacement < 0.0)",
            "else if(net_displacement > 0.0)",
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
            "qm_ea_id=41128",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_sample_bias_adjustment=true",
            "strategy_persistence_threshold=0.0",
            "strategy_numerical_tolerance=1.0e-10",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertEqual(manifest["logical_symbol"], "QM5_41128_XAU_XAG_MDAILY_PERSIST_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

        approved = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41128_xauxag-mdaily-persist-rv_card.md"
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())
        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(encoding="utf-8-sig")
        self.assertIn("41128,xauxag-mdaily-persist-rv,0,XAUUSD.DWX,411280000", magic_rows)
        self.assertIn("41128,xauxag-mdaily-persist-rv,1,XAGUSD.DWX,411280001", magic_rows)
        resolver = (REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh").read_text(encoding="utf-8")
        self.assertIn("411280000", resolver)
        self.assertIn("411280001", resolver)


if __name__ == "__main__":
    unittest.main()
