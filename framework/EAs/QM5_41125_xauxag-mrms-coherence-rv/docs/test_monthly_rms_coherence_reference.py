"""Independent deterministic fixtures for QM5_41125's coherence basket."""

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
THRESHOLD = 0.16
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class CoherenceResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    return_count: int = 0
    net_displacement: float = 0.0
    squared_path: float = 0.0
    endpoint_displacement: float = 0.0
    coherence: float = 0.0


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
    """Build a 45-bar newest-first pair with an exact older boundary ratio."""

    if older_key is None:
        older_key = previous_month_key(completed_key)
    month_ratios = cumulative_ratios(returns)
    xau, xag = make_month(completed_key, month_ratios)

    # The newest close in the older month is the left boundary ratio zero.
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
) -> CoherenceResult:
    """Mirror the boundary-plus-month N/Q loop and contrarian side."""

    if len(chronological) < 18 or any(not math.isfinite(value) for value in chronological):
        return CoherenceResult()
    return_count = len(chronological) - 1
    if not 17 <= return_count <= 23:
        return CoherenceResult()
    net = 0.0
    squared_path = 0.0
    for index in range(1, len(chronological)):
        relative_return = chronological[index] - chronological[index - 1]
        if not math.isfinite(relative_return):
            return CoherenceResult()
        net += relative_return
        squared_path += relative_return * relative_return
        if not math.isfinite(net) or not math.isfinite(squared_path):
            return CoherenceResult()

    endpoint = chronological[-1] - chronological[0]
    result = CoherenceResult(
        completed_sessions=return_count,
        return_count=return_count,
        net_displacement=net,
        squared_path=squared_path,
        endpoint_displacement=endpoint,
    )
    if not math.isfinite(endpoint) or abs(net - endpoint) > tolerance * max(1.0, abs(endpoint)):
        return result
    if squared_path == 0.0:
        return replace(result, valid=(net == 0.0 and endpoint == 0.0))
    if squared_path < 0.0:
        return result

    denominator = math.sqrt(return_count * squared_path)
    coherence = abs(net) / denominator
    if not math.isfinite(coherence) or coherence < 0.0 or coherence > 1.0 + tolerance:
        return result
    coherence = min(coherence, 1.0)
    direction = 0
    if coherence >= threshold:
        direction = 1 if net < 0.0 else -1 if net > 0.0 else 0
    return replace(result, valid=True, direction=direction, coherence=coherence)


def monthly_rms_coherence(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
) -> CoherenceResult:
    if (
        current_month <= 0
        or len(xau_bars) != HISTORY_BARS
        or len(xag_bars) != HISTORY_BARS
        or not synchronized_pair_valid(xau_bars, xag_bars, 0)
    ):
        return CoherenceResult()
    completed_key = month_key(xau_bars[0].opened)
    if month_key(xag_bars[0].opened) != completed_key or next_month_key(completed_key) != current_month:
        return CoherenceResult()

    series_ratios: list[float] = []
    index = 0
    while index < HISTORY_BARS and month_key(xau_bars[index].opened) == completed_key:
        if (
            len(series_ratios) >= 23
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != completed_key
        ):
            return CoherenceResult()
        ratio = math.log(xau_bars[index].close) - math.log(xag_bars[index].close)
        if not math.isfinite(ratio):
            return CoherenceResult()
        series_ratios.append(ratio)
        index += 1

    if not 17 <= len(series_ratios) <= 23 or index >= HISTORY_BARS:
        return CoherenceResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return CoherenceResult()
    older_key = month_key(xau_bars[index].opened)
    if month_key(xag_bars[index].opened) != older_key or next_month_key(older_key) != completed_key:
        return CoherenceResult()
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


class MonthlyRmsCoherenceReferenceTest(unittest.TestCase):
    def signal(self, returns: list[float], **kwargs: int) -> CoherenceResult:
        xau, xag = sample(returns, **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_rms_coherence(next_month_key(completed_key), xau, xag)

    def test_every_allowed_session_count_includes_boundary_return_once(self) -> None:
        for count in range(17, 24):
            returns = [0.01] * count
            result = self.signal(returns)
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, count)
            self.assertEqual(result.return_count, count)
            self.assertAlmostEqual(result.net_displacement, sum(returns), places=12)
            self.assertAlmostEqual(result.squared_path, sum(value * value for value in returns), places=12)
            self.assertAlmostEqual(result.coherence, 1.0, places=12)

    def test_positive_and_negative_coherent_paths_fade_net(self) -> None:
        self.assertEqual(self.signal([0.01] * 20).direction, -1)
        self.assertEqual(self.signal([-0.01] * 20).direction, 1)

    def test_zero_constituents_valid_and_zero_path_consumed_flat(self) -> None:
        with_zero = self.signal([0.01] * 9 + [0.0] + [0.01] * 10)
        self.assertTrue(with_zero.valid)
        self.assertEqual(with_zero.direction, -1)
        zero_path = self.signal([0.0] * 17)
        self.assertTrue(zero_path.valid)
        self.assertEqual(zero_path.squared_path, 0.0)
        self.assertEqual(zero_path.direction, 0)

    def test_noisy_zero_net_is_flat_and_order_is_irrelevant(self) -> None:
        returns = [0.01 if index % 2 == 0 else -0.01 for index in range(20)]
        forward = classify_ratios([0.0, *cumulative_ratios(returns)])
        shuffled = list(returns)
        random.Random(20260823).shuffle(shuffled)
        reordered = classify_ratios([0.0, *cumulative_ratios(shuffled)])
        self.assertEqual(forward.direction, 0)
        self.assertAlmostEqual(forward.net_displacement, reordered.net_displacement)
        self.assertAlmostEqual(forward.squared_path, reordered.squared_path)
        self.assertAlmostEqual(forward.coherence, reordered.coherence)

    def test_threshold_comparison_is_inclusive(self) -> None:
        count = 20
        target_sum = THRESHOLD * math.sqrt(count)
        component = target_sum / count
        orthogonal = math.sqrt((1.0 - THRESHOLD * THRESHOLD) / 2.0)
        returns = [component + orthogonal, component - orthogonal] + [component] * (count - 2)
        result = classify_ratios([0.0, *cumulative_ratios(returns)], threshold=THRESHOLD - 1.0e-14)
        self.assertAlmostEqual(result.coherence, THRESHOLD, places=12)
        self.assertEqual(result.direction, -1)

    def test_session_synchronization_and_adjacent_boundary_are_exact(self) -> None:
        for count in (17, 20, 23):
            self.assertTrue(self.signal([0.01] * count).valid)
        for count in (16, 24):
            self.assertFalse(self.signal([0.01] * count).valid)
        xau, xag = sample([0.01] * 20)
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_rms_coherence(202608, xau, xag).valid)
        xau, xag = sample([0.01] * 20, older_key=202605)
        self.assertFalse(monthly_rms_coherence(202608, xau, xag).valid)

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
        self.assertEqual(self.signal([0.01] * 20, completed_key=202612).direction, -1)

        rng = random.Random(20260823)
        for count in (17, 20, 23):
            qualified = 0
            for _ in range(5000):
                values = [rng.gauss(0.0, 1.0) for _ in range(count)]
                qualified += classify_ratios([0.0, *cumulative_ratios(values)]).direction != 0
            self.assertGreater(qualified / 5000, 0.42)
            self.assertLess(qualified / 5000, 0.57)
        xau_lots, xag_lots, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau_lots, 0.0)
        self.assertGreater(xag_lots, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41125_xauxag-mrms-coherence-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41125_xauxag-mrms-coherence-rv_QM5_41125_XAU_XAG_MRMS_COHERENCE_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41125;",
            "input double strategy_coherence_threshold       = 0.16;",
            "input double strategy_numerical_tolerance       = 1.0e-10;",
            "chronological_ratios[0]",
            "chronological_ratios[i + 1] = ratio;",
            "for(int i = 1; i <= completed_month_sessions; ++i)",
            "squared_path += relative_return * relative_return;",
            "MathSqrt((double)return_count * squared_path)",
            "coherence >= strategy_coherence_threshold",
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
            "qm_ea_id=41125",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_coherence_threshold=0.16",
            "strategy_numerical_tolerance=1.0e-10",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertEqual(manifest["logical_symbol"], "QM5_41125_XAU_XAG_MRMS_COHERENCE_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

        approved = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41125_xauxag-mrms-coherence-rv_card.md"
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())
        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(encoding="utf-8-sig")
        self.assertIn("41125,xauxag-mrms-coherence-rv,0,XAUUSD.DWX,411250000", magic_rows)
        self.assertIn("41125,xauxag-mrms-coherence-rv,1,XAGUSD.DWX,411250001", magic_rows)
        resolver = (REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh").read_text(encoding="utf-8")
        self.assertIn("411250000", resolver)
        self.assertIn("411250001", resolver)


if __name__ == "__main__":
    unittest.main()
