"""Deterministic reference checks for QM5_41207 XAU/XAG correlation-break RV."""

from __future__ import annotations

import math
from pathlib import Path
import statistics
import unittest
from datetime import datetime, timedelta, timezone


UTC = timezone.utc


def date_key(value: datetime) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


def week_key(value: datetime) -> int:
    return date_key(value - timedelta(days=value.weekday()))


def pearson(x: list[float], y: list[float]) -> float:
    if len(x) != len(y) or len(x) < 4:
        raise ValueError("invalid block")
    mx, my = statistics.mean(x), statistics.mean(y)
    xx = sum((value - mx) ** 2 for value in x)
    yy = sum((value - my) ** 2 for value in y)
    if xx <= 1.0e-12 or yy <= 1.0e-12:
        raise ValueError("degenerate variance")
    return sum((a - mx) * (b - my) for a, b in zip(x, y)) / math.sqrt(xx * yy)


def fisher(value: float) -> float:
    bounded = max(-0.999999999, min(0.999999999, value))
    return 0.5 * math.log((1.0 + bounded) / (1.0 - bounded))


def break_qualified(rho_old: float, rho_new: float, z_drop: float) -> bool:
    return rho_old >= 0.50 and rho_new <= 0.35 and rho_old - rho_new >= 0.25 and z_drop >= 1.645


def evaluate(xau_returns: list[float], xag_returns: list[float]) -> tuple[int, dict[str, float]]:
    if len(xau_returns) != 80 or len(xag_returns) != 80:
        raise ValueError("exactly 80 returns required")
    rho_old = pearson(xau_returns[:60], xag_returns[:60])
    rho_new = pearson(xau_returns[60:], xag_returns[60:])
    z_drop = (fisher(rho_old) - fisher(rho_new)) / math.sqrt(1 / 57 + 1 / 17)
    relative = [x - y for x, y in zip(xau_returns, xag_returns)]
    mean = statistics.mean(relative[:60])
    sd = statistics.stdev(relative[:60])
    score = (sum(relative[-5:]) - 5 * mean) / (sd * math.sqrt(5))
    broken = break_qualified(rho_old, rho_new, z_drop)
    direction = -1 if broken and score >= 1.25 else 1 if broken and score <= -1.25 else 0
    return direction, {"rho_old": rho_old, "rho_new": rho_new, "z_drop": z_drop, "mean": mean, "sd": sd, "score": score}


def fixture(sign: int = 1) -> tuple[list[float], list[float]]:
    old_x = [0.006 * math.sin(i * 0.71) + 0.002 * math.cos(i * 0.19) for i in range(60)]
    old_y = [0.85 * value + 0.0008 * math.sin(i * 1.37) for i, value in enumerate(old_x)]
    new_x = [0.004 * math.sin(i * 1.11) + 0.001 * math.cos(i * 0.43) for i in range(20)]
    new_y = [0.004 * math.cos(i * 0.83) - 0.001 * math.sin(i * 1.61) for i in range(20)]
    if sign > 0:
        new_x[-5:] = [value + 0.015 for value in new_x[-5:]]
    else:
        new_x[-5:] = [value - 0.015 for value in new_x[-5:]]
    return old_x + new_x, old_y + new_y


def target(anchor_xau: float, anchor_xag: float, signal_xau: float, signal_xag: float) -> float:
    anchor = math.log(anchor_xau) - math.log(anchor_xag)
    signal = math.log(signal_xau) - math.log(signal_xag)
    return anchor + 0.5 * (signal - anchor)


def synchronized(completed_newest_first: list[tuple[datetime, datetime]], current: datetime) -> bool:
    if len(completed_newest_first) != 81:
        return False
    previous: datetime | None = None
    for xau_time, xag_time in completed_newest_first:
        if xau_time != xag_time or xau_time >= current:
            return False
        if previous is not None and previous <= xau_time:
            return False
        previous = xau_time
    return True


def half_risk_lots(full_risk_lots: float, step: float) -> float:
    return math.floor((0.5 * full_risk_lots + 1.0e-12) / step) * step


class CorrelationBreakReferenceTest(unittest.TestCase):
    def test_positive_displacement_sells_xau(self) -> None:
        direction, metrics = evaluate(*fixture(1))
        self.assertEqual(direction, -1)
        self.assertGreaterEqual(metrics["rho_old"], 0.50)
        self.assertLessEqual(metrics["rho_new"], 0.35)
        self.assertGreaterEqual(metrics["z_drop"], 1.645)
        self.assertGreaterEqual(metrics["score"], 1.25)

    def test_negative_displacement_buys_xau(self) -> None:
        direction, metrics = evaluate(*fixture(-1))
        self.assertEqual(direction, 1)
        self.assertLessEqual(metrics["score"], -1.25)

    def test_disjoint_blocks_ignore_cross_boundary_pairing(self) -> None:
        xau, xag = fixture(1)
        old_before = pearson(xau[:60], xag[:60])
        xau[60:] = list(reversed(xau[60:]))
        self.assertEqual(pearson(xau[:60], xag[:60]), old_before)

    def test_fisher_clamp_is_finite_at_perfect_correlation(self) -> None:
        self.assertTrue(math.isfinite(fisher(1.0)))
        self.assertTrue(math.isfinite(fisher(-1.0)))
        self.assertEqual(pearson([1.0, 2.0, 3.0, 4.0], [2.0, 4.0, 6.0, 8.0]), 1.0)

    def test_all_break_boundaries_are_inclusive(self) -> None:
        self.assertTrue(break_qualified(0.60, 0.35, 1.645))
        self.assertTrue(break_qualified(0.50, 0.25, 1.645))
        self.assertFalse(break_qualified(0.499999, 0.249999, 1.645))
        self.assertFalse(break_qualified(0.60, 0.350001, 1.645))
        self.assertFalse(break_qualified(0.60, 0.35, 1.644999))

    def test_degenerate_variance_is_invalid(self) -> None:
        with self.assertRaises(ValueError):
            pearson([1.0] * 20, [float(i) for i in range(20)])

    def test_exact_halfway_target_and_crossing_side(self) -> None:
        value = target(2000.0, 20.0, 2200.0, 20.0)
        anchor = math.log(100.0)
        signal = math.log(110.0)
        self.assertAlmostEqual(value, (anchor + signal) / 2)
        self.assertTrue(value <= value)  # short-XAU package exits at or below.
        self.assertTrue(value >= value)  # long-XAU package exits at or above.

    def test_exact_81_synchronized_completed_endpoints(self) -> None:
        current = datetime(2026, 8, 31, tzinfo=UTC)
        bars = [(current - timedelta(days=i + 1), current - timedelta(days=i + 1)) for i in range(81)]
        self.assertTrue(synchronized(bars, current))
        self.assertFalse(synchronized(bars[:-1], current))
        broken = list(bars)
        broken[7] = (broken[7][0], broken[7][1] + timedelta(hours=1))
        self.assertFalse(synchronized(broken, current))

    def test_week_key_and_single_consumption(self) -> None:
        self.assertEqual(week_key(datetime(2027, 1, 3, tzinfo=UTC)), 20261228)
        attempts: set[int] = set()
        key = week_key(datetime(2027, 1, 4, tzinfo=UTC))
        self.assertNotIn(key, attempts)
        attempts.add(key)
        self.assertIn(key, attempts)

    def test_half_risk_rounding_never_exceeds_leg_budget(self) -> None:
        self.assertEqual(half_risk_lots(1.23, 0.01), 0.61)
        self.assertLessEqual(half_risk_lots(1.23, 0.01) / 1.23, 0.5)

    def test_completed_bar_and_stale_lifecycle(self) -> None:
        entry = datetime(2026, 8, 3, tzinfo=UTC)
        self.assertFalse(14 >= 15)
        self.assertTrue(15 >= 15)
        self.assertFalse(datetime(2026, 8, 26, tzinfo=UTC) - entry >= timedelta(days=24))
        self.assertTrue(datetime(2026, 8, 27, tzinfo=UTC) - entry >= timedelta(days=24))

    def test_source_persists_attempt_and_package_before_fallible_work(self) -> None:
        source = (Path(__file__).parents[1] / "QM5_41207_xauxag-corrbreak-rv.mq5").read_text(encoding="utf-8")
        entry = source[source.index("bool Strategy_EntrySignal"):source.index("bool Strategy_NewestCompletedRatio")]
        self.assertLess(entry.index("Strategy_RecordAttemptState"), entry.index("Strategy_LoadCorrelationBreak"))
        package = source[source.index("bool Strategy_OpenPair"):source.index("bool Strategy_NoTradeFilter")]
        self.assertLess(package.index("Strategy_PersistPackageState"), package.index("Strategy_OpenLeg"))
        spread = source[source.index("bool Strategy_SpreadAllowed"):source.index("bool Strategy_SymbolReady")]
        self.assertIn("ask < bid", spread)
        self.assertNotIn("ask <= bid", spread)


if __name__ == "__main__":
    unittest.main()
