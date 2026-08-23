"""Independent deterministic fixtures for QM5_41123's path-efficiency basket."""

from __future__ import annotations

import json
import math
import unittest
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
HISTORY_BARS = 45
THRESHOLD = 0.20
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class EfficiencyResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    return_count: int = 0
    net_displacement: float = 0.0
    absolute_path: float = 0.0
    efficiency: float = 0.0


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


def ratios_from_returns(returns: list[float], start: float = 0.0) -> list[float]:
    ratios = [start]
    for value in returns:
        ratios.append(ratios[-1] + value)
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
        padding_ratios = [-0.1 - index * 0.001 for index in range(count)]
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


def classify_ratios(
    chronological: list[float],
    threshold: float = THRESHOLD,
    tolerance: float = TOLERANCE,
) -> EfficiencyResult:
    """Mirror the bounded N/P loop, numerical gate, and contrarian side."""

    if len(chronological) < 2 or any(not math.isfinite(value) for value in chronological):
        return EfficiencyResult()
    net = 0.0
    absolute_path = 0.0
    for index in range(1, len(chronological)):
        relative_return = chronological[index] - chronological[index - 1]
        if not math.isfinite(relative_return):
            return EfficiencyResult()
        net += relative_return
        absolute_path += abs(relative_return)
        if not math.isfinite(net) or not math.isfinite(absolute_path):
            return EfficiencyResult()

    result = EfficiencyResult(
        completed_sessions=len(chronological),
        return_count=len(chronological) - 1,
        net_displacement=net,
        absolute_path=absolute_path,
    )
    endpoint_net = chronological[-1] - chronological[0]
    scale = max(1.0, absolute_path)
    if not math.isfinite(endpoint_net) or abs(net - endpoint_net) > tolerance * scale:
        return result
    if absolute_path <= 0.0:
        return result

    efficiency = abs(net) / absolute_path
    if not math.isfinite(efficiency) or efficiency < 0.0 or efficiency > 1.0 + tolerance:
        return result
    efficiency = min(efficiency, 1.0)
    direction = 0
    if efficiency >= threshold:
        direction = 1 if net < 0.0 else -1 if net > 0.0 else 0
    return replace(result, valid=True, direction=direction, efficiency=efficiency)


def monthly_path_efficiency(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
    minimum: int = 17,
    maximum: int = 23,
    history_bars: int = HISTORY_BARS,
) -> EfficiencyResult:
    """Mirror exact completed-month reconstruction before classification."""

    if (
        current_month <= 0
        or history_bars != HISTORY_BARS
        or minimum != 17
        or maximum != 23
        or minimum > maximum
        or history_bars < maximum + 1
        or len(xau_bars) != history_bars
        or len(xag_bars) != history_bars
        or not synchronized_pair_valid(xau_bars, xag_bars, 0)
    ):
        return EfficiencyResult()

    completed_key = month_key(xau_bars[0].opened)
    if (
        month_key(xag_bars[0].opened) != completed_key
        or next_month_key(completed_key) != current_month
    ):
        return EfficiencyResult()

    series_ratios: list[float] = []
    index = 0
    while index < history_bars and month_key(xau_bars[index].opened) == completed_key:
        if (
            len(series_ratios) >= maximum
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != completed_key
        ):
            return EfficiencyResult()
        ratio = math.log(xau_bars[index].close) - math.log(xag_bars[index].close)
        if not math.isfinite(ratio):
            return EfficiencyResult()
        series_ratios.append(ratio)
        index += 1

    if not minimum <= len(series_ratios) <= maximum or index >= history_bars:
        return EfficiencyResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return EfficiencyResult()
    older_key = month_key(xau_bars[index].opened)
    if (
        month_key(xag_bars[index].opened) != older_key
        or next_month_key(older_key) != completed_key
    ):
        return EfficiencyResult()

    return classify_ratios(list(reversed(series_ratios)))


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


class MonthlyPathEfficiencyReferenceTest(unittest.TestCase):
    def signal(self, returns: list[float], **kwargs: int) -> EfficiencyResult:
        xau, xag = sample(ratios_from_returns(returns), **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_path_efficiency(next_month_key(completed_key), xau, xag)

    def test_every_allowed_session_count_sums_every_return_once(self) -> None:
        for count in range(17, 24):
            returns = [0.01] * (count - 1)
            result = self.signal(returns)
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, count)
            self.assertEqual(result.return_count, count - 1)
            self.assertAlmostEqual(result.net_displacement, sum(returns), places=12)
            self.assertAlmostEqual(result.absolute_path, sum(map(abs, returns)), places=12)
            self.assertAlmostEqual(result.efficiency, 1.0, places=12)

    def test_positive_and_negative_efficient_paths_fade_net(self) -> None:
        positive = self.signal([0.01] * 19)
        self.assertEqual(positive.direction, -1)
        negative = self.signal([-0.01] * 19)
        self.assertEqual(negative.direction, 1)

    def test_zero_constituent_returns_are_valid_and_zero_total_path_is_flat(self) -> None:
        with_zero = self.signal([0.01] * 8 + [0.0] + [0.01] * 7)
        self.assertTrue(with_zero.valid)
        self.assertEqual(with_zero.direction, -1)
        self.assertEqual(with_zero.return_count, 16)

        zero_path = self.signal([0.0] * 16)
        self.assertFalse(zero_path.valid)
        self.assertEqual(zero_path.direction, 0)
        self.assertEqual(zero_path.absolute_path, 0.0)

    def test_zero_net_is_flat_and_threshold_is_inclusive(self) -> None:
        net_zero = classify_ratios(ratios_from_returns([1.0, -1.0] + [0.0] * 14))
        self.assertTrue(net_zero.valid)
        self.assertEqual(net_zero.efficiency, 0.0)
        self.assertEqual(net_zero.direction, 0)

        equality = classify_ratios(ratios_from_returns([3.0, -2.0] + [0.0] * 14))
        self.assertTrue(equality.valid)
        self.assertEqual(equality.efficiency, 0.20)
        self.assertEqual(equality.direction, -1)

        below = classify_ratios(ratios_from_returns([3.0, -2.01] + [0.0] * 14))
        self.assertTrue(below.valid)
        self.assertLess(below.efficiency, THRESHOLD)
        self.assertEqual(below.direction, 0)

    def test_path_order_changes_efficiency_without_changing_endpoints(self) -> None:
        direct = classify_ratios([0.0, 0.2] + [0.2] * 15)
        excursion = classify_ratios([0.0, 1.0, 0.2] + [0.2] * 14)
        self.assertAlmostEqual(direct.net_displacement, excursion.net_displacement)
        self.assertAlmostEqual(direct.efficiency, 1.0)
        self.assertLess(excursion.efficiency, THRESHOLD)
        self.assertEqual(direct.direction, -1)
        self.assertEqual(excursion.direction, 0)

    def test_session_bounds_synchronization_and_month_boundaries_are_exact(self) -> None:
        for count in (17, 20, 23):
            self.assertTrue(self.signal([0.01] * (count - 1)).valid)
        for count in (16, 24):
            self.assertFalse(self.signal([0.01] * (count - 1)).valid)

        xau, xag = sample(ratios_from_returns([0.01] * 19))
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_path_efficiency(202608, xau, xag).valid)

        xau, xag = sample(ratios_from_returns([0.01] * 19))
        xau[2] = CloseBar(xau[1].opened, xau[2].close)
        xag[2] = CloseBar(xag[1].opened, xag[2].close)
        self.assertFalse(monthly_path_efficiency(202608, xau, xag).valid)

        xau, xag = sample(ratios_from_returns([0.01] * 19), older_key=202605)
        self.assertFalse(monthly_path_efficiency(202608, xau, xag).valid)
        self.assertFalse(monthly_path_efficiency(202609, xau, xag).valid)

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
        year_boundary = self.signal([0.01] * 19, completed_key=202612)
        self.assertTrue(year_boundary.valid)
        self.assertEqual(year_boundary.direction, -1)

        xau, xag, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41123_xauxag-mpath-eff-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41123_xauxag-mpath-eff-rv_QM5_41123_XAU_XAG_MPATH_EFF_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41123;",
            "input double strategy_efficiency_threshold      = 0.20;",
            "input double strategy_efficiency_tolerance      = 1.0e-10;",
            "CopyRates(g_leg_xau",
            "PERIOD_D1, 1, strategy_history_bars_d1",
            "chronological_ratios[i] = ratio;",
            "net_displacement += relative_return;",
            "absolute_path += MathAbs(relative_return);",
            "if(absolute_path <= 0.0)",
            "efficiency >= strategy_efficiency_threshold",
            "if(net_displacement < 0.0)",
            "else if(net_displacement > 0.0)",
            "QM_ATR(g_leg_xau, PERIOD_D1, strategy_atr_period_d1, 1)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
            "request.tp = 0.0;",
            "strategy_notional_ratio",
        ):
            self.assertIn(marker, source)
        self.assertNotIn("relative_return == 0.0", source)
        for banned in ("irsi(", "imacd(", "ibands(", "webrequest(", "sequence"):
            self.assertNotIn(banned, source.lower())
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntrySignal(request)"),
        )
        for marker in (
            "qm_ea_id=41123",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_efficiency_threshold=0.20",
            "strategy_efficiency_tolerance=1.0e-10",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertEqual(manifest["logical_symbol"], "QM5_41123_XAU_XAG_MPATH_EFF_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41123_xauxag-mpath-eff-rv_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())

        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(
            encoding="utf-8-sig"
        )
        self.assertIn("41123,xauxag-mpath-eff-rv,0,XAUUSD.DWX,411230000", magic_rows)
        self.assertIn("41123,xauxag-mpath-eff-rv,1,XAGUSD.DWX,411230001", magic_rows)
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("411230000", resolver)
        self.assertIn("411230001", resolver)


if __name__ == "__main__":
    unittest.main()
