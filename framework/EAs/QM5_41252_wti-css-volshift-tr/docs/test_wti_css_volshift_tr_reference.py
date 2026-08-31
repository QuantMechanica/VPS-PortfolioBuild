from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41252_wti-css-volshift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41252_wti-css-volshift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41252_wti-css-volshift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
RETURN_COUNT = 252
SPLIT_MIN = 21
SPLIT_MAX = 231
SCORE_THRESHOLD = 0.63
TOTAL_SQUARE_EPSILON = 1e-16
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class CssSignal:
    direction: int
    returns: tuple[float, ...]
    mean_return: float
    total_square: float
    selected_split: int
    selected_d: float
    score: float
    post_return: float


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def retain_latest_exact_max(scores: tuple[float, ...]) -> int:
    if not scores or any(not math.isfinite(value) for value in scores):
        raise ValueError("finite nonempty score vector required")
    selected = -1
    best = -1.0
    for index, score in enumerate(scores):
        if score > best or score == best:
            best = score
            selected = index
    return selected


def qualified_direction(
    score: float,
    post_return: float,
    score_threshold: float = SCORE_THRESHOLD,
    direction_epsilon: float = DIRECTION_EPSILON,
) -> int:
    if not math.isfinite(score) or not math.isfinite(post_return):
        raise ValueError("finite score and post return required")
    if score < score_threshold:
        return 0
    if post_return > direction_epsilon:
        return 1
    if post_return < -direction_epsilon:
        return -1
    return 0


def css_signal(
    closes: list[float],
    return_count: int = RETURN_COUNT,
    split_min: int = SPLIT_MIN,
    split_max: int = SPLIT_MAX,
    score_threshold: float = SCORE_THRESHOLD,
    total_square_epsilon: float = TOTAL_SQUARE_EPSILON,
    direction_epsilon: float = DIRECTION_EPSILON,
) -> CssSignal:
    if (
        return_count != RETURN_COUNT
        or split_min != SPLIT_MIN
        or split_max != SPLIT_MAX
        or score_threshold != SCORE_THRESHOLD
        or total_square_epsilon != TOTAL_SQUARE_EPSILON
        or direction_epsilon != DIRECTION_EPSILON
        or len(closes) != return_count + 1
        or any(not math.isfinite(value) or value <= 0.0 for value in closes)
    ):
        raise ValueError("locked positive 253-close baseline required")

    returns = tuple(
        math.log(right / left) for left, right in zip(closes, closes[1:])
    )
    if len(returns) != return_count or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("252 finite chronological log returns required")
    mean_return = sum(returns) / return_count
    squares = tuple((value - mean_return) ** 2 for value in returns)
    total_square = sum(squares)
    if not math.isfinite(mean_return) or not math.isfinite(total_square):
        raise ValueError("CSS centering must be finite")
    if total_square <= total_square_epsilon:
        return CssSignal(0, returns, mean_return, total_square, 0, 0.0, 0.0, 0.0)

    running = 0.0
    candidates: list[tuple[int, float, float]] = []
    scale = math.sqrt(return_count / 2.0)
    for split, value in enumerate(squares, start=1):
        running += value
        if split_min <= split <= split_max:
            d_value = running / total_square - split / return_count
            score = scale * abs(d_value)
            if not math.isfinite(d_value) or not math.isfinite(score):
                raise ValueError("CSS path must be finite")
            candidates.append((split, d_value, score))
    selected_index = retain_latest_exact_max(
        tuple(candidate[2] for candidate in candidates)
    )
    selected_split, selected_d, score = candidates[selected_index]
    post_return = sum(returns[selected_split:]) if score >= score_threshold else 0.0
    if not math.isfinite(post_return):
        raise ValueError("post-shift return must be finite")
    direction = qualified_direction(
        score, post_return, score_threshold, direction_epsilon
    )
    return CssSignal(
        direction,
        returns,
        mean_return,
        total_square,
        selected_split,
        selected_d,
        score,
        post_return,
    )


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_completed_history(
    current_month: int, newest_month: int, endpoint_times: list[int]
) -> bool:
    return (
        len(endpoint_times) == 253
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


class WtiCssVarianceShiftReferenceTests(unittest.TestCase):
    def test_high_variance_post_shift_direction_is_symmetric(self) -> None:
        quiet = [0.001 if index % 2 == 0 else -0.001 for index in range(126)]
        positive = [0.03 if index % 2 == 0 else -0.02 for index in range(126)]
        negative = [-0.03 if index % 2 == 0 else 0.02 for index in range(126)]
        buy = css_signal(closes_from_returns(quiet + positive))
        sell = css_signal(closes_from_returns(quiet + negative))
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertEqual((buy.selected_split, sell.selected_split), (126, 126))
        self.assertAlmostEqual(buy.score, 5.485029465967751, places=12)
        self.assertAlmostEqual(sell.score, buy.score, places=12)
        self.assertGreater(buy.post_return, 0.0)
        self.assertLess(sell.post_return, 0.0)

    def test_constant_path_is_degenerate_and_flat(self) -> None:
        signal = css_signal([100.0] * 253)
        self.assertEqual(signal.direction, 0)
        self.assertEqual(signal.selected_split, 0)
        self.assertEqual(signal.total_square, 0.0)
        self.assertEqual(signal.score, 0.0)

    def test_latest_exact_tie_and_inclusive_boundary(self) -> None:
        self.assertEqual(retain_latest_exact_max((0.1, 0.63, 0.2, 0.63)), 3)
        self.assertEqual(qualified_direction(0.63, 0.01), 1)
        self.assertEqual(qualified_direction(0.63, -0.01), -1)
        self.assertEqual(qualified_direction(math.nextafter(0.63, 0.0), 0.01), 0)
        self.assertEqual(qualified_direction(0.63, 1e-12), 0)

    def test_log_return_orientation_is_chronological(self) -> None:
        returns = [0.0001 * (index - 126) for index in range(252)]
        signal = css_signal(closes_from_returns(returns))
        for actual, expected in zip(signal.returns, returns):
            self.assertAlmostEqual(actual, expected, places=13)

    def test_invalid_counts_values_and_unlocked_parameters_fail(self) -> None:
        with self.assertRaises(ValueError):
            css_signal([100.0] * 252)
        with self.assertRaises(ValueError):
            css_signal([100.0] * 252 + [0.0])
        with self.assertRaises(ValueError):
            css_signal([100.0] * 252 + [math.inf])
        with self.assertRaises(ValueError):
            css_signal([100.0] * 253, return_count=251)
        with self.assertRaises(ValueError):
            css_signal([100.0] * 253, split_min=20)
        with self.assertRaises(ValueError):
            css_signal([100.0] * 253, score_threshold=0.64)

    def test_completed_history_contract(self) -> None:
        times = list(range(1, 254))
        self.assertTrue(validate_completed_history(202608, 202607, times))
        self.assertTrue(validate_completed_history(202601, 202512, times))
        self.assertFalse(validate_completed_history(202608, 202606, times))
        self.assertFalse(validate_completed_history(202608, 202607, times[:-1]))
        broken = times.copy()
        broken[100] = broken[99]
        self.assertFalse(validate_completed_history(202608, 202607, broken))

    def test_css_formula_and_latest_tie_are_literal_in_source(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("cumulative_square / metrics.total_square", source)
        self.assertIn("MathSqrt((double)strategy_return_count / 2.0)", source)
        self.assertIn("score > best_score || score == best_score", source)
        self.assertIn("metrics.score < strategy_score_threshold", source)
        self.assertIn("metrics.post_return += returns[index]", source)
        self.assertNotIn("Strategy_CusumSignal", source)

    def test_loader_excludes_current_bar_and_requires_prior_month(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_LoadCompletedCloses", source)
        self.assertIn("strategy_return_count != 252 || endpoint_target != 253", source)
        self.assertIn("Strategy_NextMonthKey(month_key) != current_month_key", source)
        self.assertIn("if(month_key == current_month_key)", source)
        self.assertIn("PERIOD_D1,\n                1,", source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41252")
        self.assertEqual(headers["ea_slug"], "wti-css-volshift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41252",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_return_count": "252",
            "strategy_split_min": "21",
            "strategy_split_max": "231",
            "strategy_score_threshold": "0.63",
            "strategy_total_square_epsilon": "0.0000000000000001",
            "strategy_direction_epsilon": "0.000000000001",
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

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_CssVarianceShiftSignal", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41252", source)
        self.assertIn('StringFormat("QM5_41252_MONTH_ATTEMPT_%d"', source)
        self.assertNotIn("iRSI", source)
        self.assertNotIn("iBands", source)
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
