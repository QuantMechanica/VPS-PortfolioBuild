from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41308_wti-mordinal-entropy-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41308_wti-mordinal-entropy-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41308_wti-mordinal-entropy-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"

PATTERN_TRIPLES = (
    (0.0, 1.0, 2.0),  # 012: a < b < c
    (0.0, 2.0, 1.0),  # 021: a < c < b
    (1.0, 0.0, 2.0),  # 102: b < a < c
    (1.0, 2.0, 0.0),  # 120: c < a < b
    (2.0, 0.0, 1.0),  # 201: b < c < a
    (2.0, 1.0, 0.0),  # 210: c < b < a
)
ENTROPY_CEILING = 0.80
TIE_EPSILON = 1e-12
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class OrdinalEntropySignal:
    direction: int
    patterns: tuple[int, ...]
    counts: tuple[int, ...]
    entropy_raw: float
    entropy_normalized: float
    entropy_qualified: bool
    momentum_12: float


def returns_are_tied(
    left: float,
    right: float,
    epsilon: float = TIE_EPSILON,
) -> bool:
    if not math.isfinite(left) or not math.isfinite(right):
        raise ValueError("finite returns required")
    return abs(left - right) <= epsilon * max(1.0, abs(left), abs(right))


def order3_pattern(
    triple: tuple[float, float, float],
    epsilon: float = TIE_EPSILON,
) -> int:
    if len(triple) != 3 or epsilon != TIE_EPSILON:
        raise ValueError("locked order-three triple required")
    a, b, c = triple
    if any(
        returns_are_tied(left, right, epsilon)
        for left, right in ((a, b), (a, c), (b, c))
    ):
        raise ValueError("within-triple relative tie")
    if a < b < c:
        return 0
    if a < c < b:
        return 1
    if b < a < c:
        return 2
    if c < a < b:
        return 3
    if b < c < a:
        return 4
    if c < b < a:
        return 5
    raise ValueError("unclassified strict order")


def entropy_from_counts(counts: tuple[int, ...]) -> tuple[float, float]:
    if len(counts) != 6 or sum(counts) != 8 or any(count < 0 for count in counts):
        raise ValueError("six nonnegative counts summing to eight required")
    raw = -sum(
        (count / 8.0) * math.log(count / 8.0)
        for count in counts
        if count > 0
    )
    normalized = raw / math.log(6.0)
    if not math.isfinite(normalized) or not 0.0 <= normalized <= 1.0:
        raise ValueError("normalized entropy out of range")
    return raw, normalized


def signal_from_returns(
    returns: list[float],
    month_returns: int = 24,
    pattern_order: int = 3,
    pattern_blocks: int = 8,
    pattern_states: int = 6,
    entropy_ceiling: float = ENTROPY_CEILING,
    momentum_months: int = 12,
    direction_epsilon: float = DIRECTION_EPSILON,
) -> OrdinalEntropySignal:
    if (
        month_returns != 24
        or pattern_order != 3
        or pattern_blocks != 8
        or pattern_states != 6
        or entropy_ceiling != ENTROPY_CEILING
        or momentum_months != 12
        or direction_epsilon != DIRECTION_EPSILON
        or len(returns) != 24
        or any(not math.isfinite(value) for value in returns)
    ):
        raise ValueError("locked finite twenty-four-return baseline required")

    patterns = tuple(
        order3_pattern(tuple(returns[3 * index : 3 * index + 3]))
        for index in range(8)
    )
    counts = tuple(patterns.count(pattern) for pattern in range(6))
    raw, normalized = entropy_from_counts(counts)
    momentum = sum(returns[12:24])
    qualified = normalized <= entropy_ceiling
    direction = 0
    if qualified and momentum > direction_epsilon:
        direction = 1
    elif qualified and momentum < -direction_epsilon:
        direction = -1
    return OrdinalEntropySignal(
        direction=direction,
        patterns=patterns,
        counts=counts,
        entropy_raw=raw,
        entropy_normalized=normalized,
        entropy_qualified=qualified,
        momentum_12=momentum,
    )


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def signal_from_closes(closes: list[float]) -> OrdinalEntropySignal:
    if len(closes) != 25 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("twenty-five positive finite closes required")
    returns = [math.log(right / left) for left, right in zip(closes, closes[1:])]
    return signal_from_returns(returns)


def weak_compositions(total: int, parts: int, prefix: tuple[int, ...] = ()):
    if parts == 1:
        yield prefix + (total,)
        return
    for value in range(total + 1):
        yield from weak_compositions(total - value, parts - 1, prefix + (value,))


def pattern_string_density() -> tuple[int, int]:
    total = 0
    qualifying = 0
    factorial_8 = math.factorial(8)
    for counts in weak_compositions(8, 6):
        multiplicity = factorial_8 // math.prod(math.factorial(value) for value in counts)
        _, normalized = entropy_from_counts(counts)
        total += multiplicity
        if normalized <= ENTROPY_CEILING:
            qualifying += multiplicity
    return qualifying, total


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 25 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right
        for left, right in zip(endpoints, endpoints[1:])
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


class WtiMonthlyOrdinalEntropyReferenceTests(unittest.TestCase):
    def test_all_six_order_three_patterns_match_the_card_map(self) -> None:
        self.assertEqual(
            tuple(order3_pattern(triple) for triple in PATTERN_TRIPLES),
            tuple(range(6)),
        )

    def test_relative_ties_fail_closed_at_the_inclusive_epsilon(self) -> None:
        with self.assertRaisesRegex(ValueError, "tie"):
            order3_pattern((0.0, 1e-12, 3e-12))
        self.assertEqual(order3_pattern((0.0, 2e-12, 4e-12)), 0)
        with self.assertRaises(ValueError):
            order3_pattern((0.0, math.inf, 1.0))

    def test_twenty_four_returns_form_eight_disjoint_triples(self) -> None:
        labels = (0, 1, 2, 3, 4, 5, 0, 5)
        returns = [value for label in labels for value in PATTERN_TRIPLES[label]]
        signal = signal_from_returns(returns)
        self.assertEqual(signal.patterns, labels)
        self.assertEqual(signal.counts, (2, 1, 1, 1, 1, 2))
        self.assertEqual(sum(signal.counts), 8)

    def test_low_entropy_gate_and_newest_twelve_month_side(self) -> None:
        buy_returns = [-0.01, 0.01, 0.02] * 8
        sell_returns = [-0.03, -0.02, -0.01] * 8
        neutral_returns = [-0.01, 0.0, 0.01] * 8
        buy = signal_from_returns(buy_returns)
        sell = signal_from_returns(sell_returns)
        neutral = signal_from_returns(neutral_returns)
        self.assertEqual((buy.direction, sell.direction, neutral.direction), (1, -1, 0))
        self.assertEqual((buy.counts, sell.counts, neutral.counts), ((8, 0, 0, 0, 0, 0),) * 3)
        self.assertEqual((buy.entropy_normalized, sell.entropy_normalized), (0.0, 0.0))
        self.assertGreater(buy.momentum_12, DIRECTION_EPSILON)
        self.assertLess(sell.momentum_12, -DIRECTION_EPSILON)
        self.assertAlmostEqual(neutral.momentum_12, 0.0, places=15)

    def test_log_return_orientation_is_oldest_to_newest(self) -> None:
        returns = [-0.01, 0.01, 0.02] * 8
        signal = signal_from_closes(closes_from_returns(returns))
        self.assertEqual(signal.direction, 1)
        self.assertEqual(signal.patterns, (0,) * 8)

    def test_discrete_entropy_boundary_neighbors(self) -> None:
        admitted_counts = (0, 0, 2, 2, 2, 2)
        excluded_counts = (0, 1, 1, 1, 2, 3)
        _, admitted = entropy_from_counts(admitted_counts)
        _, excluded = entropy_from_counts(excluded_counts)
        self.assertAlmostEqual(admitted, 0.7737056144690831, places=15)
        self.assertAlmostEqual(excluded, 0.8339150226079424, places=15)
        self.assertLessEqual(admitted, ENTROPY_CEILING)
        self.assertGreater(excluded, ENTROPY_CEILING)

    def test_exact_pattern_string_density_matches_receipt(self) -> None:
        qualifying, total = pattern_string_density()
        self.assertEqual((qualifying, total), (782_496, 1_679_616))
        self.assertAlmostEqual(qualifying / total, 0.46587791495198905, places=15)

    def test_invalid_dimensions_and_parameters_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            signal_from_returns([0.1] * 23)
        with self.assertRaises(ValueError):
            signal_from_returns([0.1] * 24, pattern_blocks=7)
        with self.assertRaises(ValueError):
            signal_from_returns([0.1] * 24, entropy_ceiling=0.81)
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 24)
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 24 + [0.0])

    def test_twenty_five_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 202307
        for _ in range(25):
            endpoints.append(key)
            key = next_month_key(key)
        self.assertTrue(validate_month_keys(key, endpoints))
        self.assertFalse(validate_month_keys(key, endpoints[:-1]))
        broken = endpoints.copy()
        broken[8] = broken[7]
        self.assertFalse(validate_month_keys(key, broken))

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41308")
        self.assertEqual(headers["ea_slug"], "wti-mordinal-entropy-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41308",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "24",
            "strategy_pattern_order": "3",
            "strategy_pattern_blocks": "8",
            "strategy_pattern_states": "6",
            "strategy_entropy_ceiling": "0.80",
            "strategy_relative_tie_epsilon": "0.000000000001",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1200",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        input_names = set(
            re.findall(r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=", source)
        )
        self.assertTrue(set(values) <= input_names)
        self.assertTrue(
            {name for name in input_names if name.startswith("strategy_")} <= set(values)
        )
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(
            any(
                token in path.name.lower()
                for path in setfiles
                for token in ("live", "demo", "shadow", "stress")
            )
        )

    def test_source_contract_attempt_order_and_entry_state(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_OrdinalEntropySignal", source)
        self.assertIn("metrics.entropy_normalized <= strategy_entropy_ceiling", source)
        self.assertIn("triple_index * strategy_pattern_order", source)
        self.assertIn("strategy_month_returns - strategy_momentum_months", source)
        self.assertIn("QM_FrameworkMagic() != 413080000", source)
        self.assertIn("Strategy_HasForeignSymbolPosition()", source)

        prepare = source.index("void Strategy_PrepareDecisionSignal")
        consume = source.index("Strategy_RecordMonthAttempt(g_decision_month_key)", prepare)
        history = source.index("Strategy_LoadMonthlyEndpoints", consume)
        self.assertLess(consume, history)

        open_call = source.index("QM_TM_OpenPosition(req, out_ticket)")
        persist_entry = source.index("Strategy_RecordEntryMonth(g_decision_month_key)", open_call)
        self.assertLess(open_call, persist_entry)
        self.assertIn("Strategy_RecoverEntryMonthFromDeals", source)
        self.assertIn("HistorySelectByPosition(position_id)", source)

        for prohibited in (
            "iRSI(",
            "iMACD(",
            "iBands(",
            "iADX(",
            "iMA(",
            "MathRand(",
            "WebRequest(",
            "FileOpen(",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_card_copy_are_exact(self) -> None:
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn(
            "41308,wti-mordinal-entropy-tr,0,XTIUSD.DWX,413080000",
            registry,
        )
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
