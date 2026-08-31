from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41254_wti-chow-break-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41254_wti-chow-break-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41254_wti-chow-break-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

OBSERVATION_COUNT = 252
SPLIT_MIN = 63
SPLIT_MAX = 189
SCORE_THRESHOLD = 3.0
RSS_EPSILON = 1e-16
IMPROVEMENT_TOLERANCE = 1e-12
SLOPE_EPSILON = 1e-12
RESIDUAL_DOF = 248


@dataclasses.dataclass(frozen=True)
class OlsFit:
    intercept: float
    slope: float
    rss: float


@dataclasses.dataclass(frozen=True)
class BreakSignal:
    direction: int
    log_prices: tuple[float, ...]
    selected_split: int
    pooled: OlsFit
    left: OlsFit
    recent: OlsFit
    split_rss: float
    improvement: float
    score: float


def ols_fit(values: tuple[float, ...], start: int, count: int) -> OlsFit:
    end = start + count
    if start < 0 or count < 2 or end <= start or end > len(values):
        raise ValueError("nondegenerate in-range regression required")
    xs = tuple(float(index) for index in range(start, end))
    ys = values[start:end]
    if any(not math.isfinite(value) for value in xs + ys):
        raise ValueError("finite regression inputs required")
    sample_count = float(count)
    sum_x = sum(xs)
    sum_y = sum(ys)
    sum_xx = sum(value * value for value in xs)
    sum_xy = sum(x_value * y_value for x_value, y_value in zip(xs, ys))
    denominator = sample_count * sum_xx - sum_x * sum_x
    if not math.isfinite(denominator) or denominator <= RSS_EPSILON:
        raise ValueError("degenerate regression denominator")
    slope = (sample_count * sum_xy - sum_x * sum_y) / denominator
    intercept = (sum_y - slope * sum_x) / sample_count
    residuals = tuple(
        y_value - (intercept + slope * x_value)
        for x_value, y_value in zip(xs, ys)
    )
    rss = sum(value * value for value in residuals)
    if not all(math.isfinite(value) for value in (intercept, slope, rss)):
        raise ValueError("finite OLS result required")
    return OlsFit(intercept, slope, rss)


def guarded_improvement(
    pooled_rss: float,
    split_rss: float,
    tolerance: float = IMPROVEMENT_TOLERANCE,
) -> float:
    if not all(math.isfinite(value) for value in (pooled_rss, split_rss, tolerance)):
        raise ValueError("finite improvement inputs required")
    improvement = pooled_rss - split_rss
    negative_limit = -tolerance * max(1.0, pooled_rss)
    if improvement < negative_limit:
        raise ValueError("negative improvement outside tolerance")
    return max(0.0, improvement)


def retain_latest_exact_max(scores: tuple[float, ...]) -> int:
    if not scores or any(not math.isfinite(value) for value in scores):
        raise ValueError("finite nonempty score vector required")
    selected = -1
    best = -1.0
    for index, score in enumerate(scores):
        if score > best or score == best:
            selected = index
            best = score
    return selected


def qualified_direction(
    score: float,
    recent_slope: float,
    score_threshold: float = SCORE_THRESHOLD,
    slope_epsilon: float = SLOPE_EPSILON,
) -> int:
    if not math.isfinite(score) or not math.isfinite(recent_slope):
        raise ValueError("finite score and slope required")
    if score < score_threshold:
        return 0
    if recent_slope > slope_epsilon:
        return 1
    if recent_slope < -slope_epsilon:
        return -1
    return 0


def scanned_break_signal(
    closes: list[float],
    observation_count: int = OBSERVATION_COUNT,
    split_min: int = SPLIT_MIN,
    split_max: int = SPLIT_MAX,
    score_threshold: float = SCORE_THRESHOLD,
    rss_epsilon: float = RSS_EPSILON,
    improvement_tolerance: float = IMPROVEMENT_TOLERANCE,
    slope_epsilon: float = SLOPE_EPSILON,
) -> BreakSignal:
    if (
        observation_count != OBSERVATION_COUNT
        or split_min != SPLIT_MIN
        or split_max != SPLIT_MAX
        or score_threshold != SCORE_THRESHOLD
        or rss_epsilon != RSS_EPSILON
        or improvement_tolerance != IMPROVEMENT_TOLERANCE
        or slope_epsilon != SLOPE_EPSILON
        or len(closes) != observation_count
        or any(not math.isfinite(value) or value <= 0.0 for value in closes)
    ):
        raise ValueError("locked positive 252-close baseline required")

    log_prices = tuple(math.log(value) for value in closes)
    if any(not math.isfinite(value) for value in log_prices):
        raise ValueError("finite chronological log prices required")
    pooled = ols_fit(log_prices, 0, observation_count)
    if pooled.rss <= rss_epsilon:
        raise ValueError("pooled RSS is degenerate")

    candidates: list[tuple[int, OlsFit, OlsFit, float, float, float]] = []
    for split in range(split_min, split_max + 1):
        left = ols_fit(log_prices, 0, split)
        recent = ols_fit(log_prices, split, observation_count - split)
        split_rss = left.rss + recent.rss
        if not math.isfinite(split_rss) or split_rss <= rss_epsilon:
            raise ValueError("split RSS is degenerate")
        improvement = guarded_improvement(
            pooled.rss, split_rss, improvement_tolerance
        )
        score = (improvement / 2.0) / (split_rss / RESIDUAL_DOF)
        if not math.isfinite(score) or score < 0.0:
            raise ValueError("finite nonnegative score required")
        candidates.append((split, left, recent, split_rss, improvement, score))

    selected_index = retain_latest_exact_max(
        tuple(candidate[5] for candidate in candidates)
    )
    selected_split, left, recent, split_rss, improvement, score = candidates[
        selected_index
    ]
    direction = qualified_direction(
        score, recent.slope, score_threshold, slope_epsilon
    )
    return BreakSignal(
        direction,
        log_prices,
        selected_split,
        pooled,
        left,
        recent,
        split_rss,
        improvement,
        score,
    )


def piecewise_closes(recent_slope: float, split: int = 126) -> list[float]:
    values: list[float] = []
    for index in range(OBSERVATION_COUNT):
        noise = 0.0015 * math.sin(index * 0.37) + 0.0007 * math.cos(index * 0.11)
        if index < split:
            level = 4.4 + 0.0004 * index
        else:
            join = 4.4 + 0.0004 * (split - 1)
            level = join + recent_slope * (index - split + 1)
        values.append(math.exp(level + noise))
    return values


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_completed_history(
    current_month: int, newest_month: int, endpoint_times: list[int]
) -> bool:
    return (
        len(endpoint_times) == OBSERVATION_COUNT
        and next_month_key(newest_month) == current_month
        and all(left < right for left, right in zip(endpoint_times, endpoint_times[1:]))
    )


def parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    headers: dict[str, str] = {}
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith(";"):
            body = line[1:].strip()
            if ":" in body:
                key, value = body.split(":", 1)
                headers[key.strip()] = value.strip()
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class WtiChowBreakReferenceTests(unittest.TestCase):
    def test_piecewise_recent_slope_direction_is_symmetric(self) -> None:
        buy = scanned_break_signal(piecewise_closes(0.0030))
        sell = scanned_break_signal(piecewise_closes(-0.0030))
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertEqual((buy.selected_split, sell.selected_split), (126, 126))
        self.assertGreater(buy.score, SCORE_THRESHOLD)
        self.assertGreater(sell.score, SCORE_THRESHOLD)
        self.assertGreater(buy.recent.slope, SLOPE_EPSILON)
        self.assertLess(sell.recent.slope, -SLOPE_EPSILON)

    def test_constant_path_is_degenerate(self) -> None:
        with self.assertRaisesRegex(ValueError, "pooled RSS"):
            scanned_break_signal([100.0] * OBSERVATION_COUNT)

    def test_latest_exact_tie_and_inclusive_boundary(self) -> None:
        self.assertEqual(retain_latest_exact_max((0.1, 3.0, 0.2, 3.0)), 3)
        self.assertEqual(qualified_direction(3.0, 0.01), 1)
        self.assertEqual(qualified_direction(3.0, -0.01), -1)
        self.assertEqual(qualified_direction(math.nextafter(3.0, 0.0), 0.01), 0)
        self.assertEqual(qualified_direction(3.0, 1e-12), 0)

    def test_negative_improvement_tolerance(self) -> None:
        self.assertEqual(guarded_improvement(0.5, 0.5 + 0.5e-12), 0.0)
        with self.assertRaisesRegex(ValueError, "outside tolerance"):
            guarded_improvement(0.5, 0.5 + 1.1e-12)

    def test_log_price_orientation_is_chronological(self) -> None:
        closes = piecewise_closes(0.0030)
        signal = scanned_break_signal(closes)
        for actual, close in zip(signal.log_prices, closes):
            self.assertAlmostEqual(actual, math.log(close), places=14)

    def test_invalid_counts_values_and_unlocked_parameters_fail(self) -> None:
        closes = piecewise_closes(0.0030)
        with self.assertRaises(ValueError):
            scanned_break_signal(closes[:-1])
        with self.assertRaises(ValueError):
            scanned_break_signal(closes[:-1] + [0.0])
        with self.assertRaises(ValueError):
            scanned_break_signal(closes[:-1] + [math.inf])
        with self.assertRaises(ValueError):
            scanned_break_signal(closes, observation_count=251)
        with self.assertRaises(ValueError):
            scanned_break_signal(closes, split_min=62)
        with self.assertRaises(ValueError):
            scanned_break_signal(closes, score_threshold=3.1)

    def test_completed_history_contract(self) -> None:
        times = list(range(1, OBSERVATION_COUNT + 1))
        self.assertTrue(validate_completed_history(202608, 202607, times))
        self.assertTrue(validate_completed_history(202601, 202512, times))
        self.assertFalse(validate_completed_history(202608, 202606, times))
        self.assertFalse(validate_completed_history(202608, 202607, times[:-1]))
        broken = times.copy()
        broken[100] = broken[99]
        self.assertFalse(validate_completed_history(202608, 202607, broken))

    def test_formula_tolerance_and_latest_tie_are_literal_in_source(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_OlsFit", source)
        self.assertIn("metrics.pooled_rss - split_rss", source)
        self.assertIn("-strategy_improvement_tolerance * tolerance_scale", source)
        self.assertIn("if(improvement < 0.0)", source)
        self.assertIn("(improvement / 2.0) /", source)
        self.assertIn("(split_rss / residual_dof)", source)
        self.assertIn("residual_dof != 248.0", source)
        self.assertIn("score > best_score || score == best_score", source)
        self.assertIn("metrics.score < strategy_score_threshold", source)
        self.assertIn("metrics.recent_slope > strategy_slope_epsilon", source)

    def test_loader_excludes_current_bar_and_requires_prior_month(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_LoadCompletedCloses", source)
        self.assertIn("strategy_observation_count != 252 || endpoint_target != 252", source)
        self.assertIn("Strategy_NextMonthKey(month_key) != current_month_key", source)
        self.assertIn("if(month_key == current_month_key)", source)
        self.assertIn("PERIOD_D1,\n                1,", source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41254")
        self.assertEqual(headers["ea_slug"], "wti-chow-break-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41254",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_observation_count": "252",
            "strategy_split_min": "63",
            "strategy_split_max": "189",
            "strategy_score_threshold": "3.0",
            "strategy_rss_epsilon": "0.0000000000000001",
            "strategy_improvement_tolerance": "0.000000000001",
            "strategy_slope_epsilon": "0.000000000001",
            "strategy_history_bars": "500",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_attempt_order_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_ScannedRegressionBreakSignal", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41254", source)
        self.assertIn("QM_FrameworkMagic() != 412540000", source)
        self.assertIn('StringFormat("QM5_41254_MONTH_ATTEMPT_%d"', source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadCompletedCloses"),
        )
        self.assertNotIn("iRSI", source)
        self.assertNotIn("iBands", source)
        self.assertNotIn("iMA(", source)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_backtest_setfile_exists(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
