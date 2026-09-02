from __future__ import annotations

from collections import Counter
import dataclasses
import json
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41309_wti-mlz76-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41309_wti-mlz76-tr_XTIUSD.DWX_D1_backtest.set"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41309_wti-mlz76-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
DENSITY_RECEIPT = (
    REPO_ROOT / "artifacts" / "qm5_wti_mlz76_tr_threshold_density_20260902.json"
)

WORD_LENGTH = 20
COMPLEXITY_CEILING = 6
SIGN_EPSILON = 1e-12
DIRECTION_EPSILON = 1e-12
EXPECTED_DISTRIBUTION = {
    2: 4,
    3: 396,
    4: 11_552,
    5: 125_696,
    6: 452_428,
    7: 410_944,
    8: 47_508,
    9: 48,
}


@dataclasses.dataclass(frozen=True)
class LZ76Parse:
    complexity: int
    phrases: tuple[str, ...]
    exhaustive_components: int
    final_component_non_exhaustive: bool


@dataclasses.dataclass(frozen=True)
class LZ76Signal:
    direction: int
    sign_word: str
    parse: LZ76Parse
    complexity_qualified: bool
    momentum_12: float


def lz76_parse(word: str) -> LZ76Parse:
    if not word or len(word) > WORD_LENGTH or set(word) - {"0", "1"}:
        raise ValueError("bounded nonempty binary word required")

    phrases: list[str] = []
    exhaustive_components = 0
    final_non_exhaustive = False
    phrase_start = 0
    while phrase_start < len(word):
        remaining = len(word) - phrase_start
        selected = ""
        selected_is_new = False
        for phrase_length in range(1, remaining + 1):
            phrase = word[phrase_start : phrase_start + phrase_length]
            # Candidate starts strictly before p are precisely the length-L
            # substrings contained in S[0..q-1], including permitted overlap.
            occurs_before_terminal = any(
                word[candidate_start : candidate_start + phrase_length] == phrase
                for candidate_start in range(phrase_start)
            )
            if not occurs_before_terminal:
                selected = phrase
                selected_is_new = True
                break
        if not selected:
            selected = word[phrase_start:]
            final_non_exhaustive = True
        if not selected or (not selected_is_new and len(selected) != remaining):
            raise AssertionError("only the terminal component may be non-exhaustive")
        phrases.append(selected)
        if selected_is_new:
            exhaustive_components += 1
        phrase_start += len(selected)

    if "".join(phrases) != word:
        raise AssertionError("phrase reconstruction failed")
    if final_non_exhaustive:
        if exhaustive_components != len(phrases) - 1:
            raise AssertionError("invalid non-exhaustive component count")
    elif exhaustive_components != len(phrases):
        raise AssertionError("invalid exhaustive component count")
    return LZ76Parse(
        complexity=len(phrases),
        phrases=tuple(phrases),
        exhaustive_components=exhaustive_components,
        final_component_non_exhaustive=final_non_exhaustive,
    )


def signal_from_returns(
    returns: list[float],
    month_returns: int = WORD_LENGTH,
    complexity_ceiling: int = COMPLEXITY_CEILING,
    sign_epsilon: float = SIGN_EPSILON,
    momentum_months: int = 12,
    direction_epsilon: float = DIRECTION_EPSILON,
) -> LZ76Signal:
    if (
        month_returns != WORD_LENGTH
        or complexity_ceiling != COMPLEXITY_CEILING
        or sign_epsilon != SIGN_EPSILON
        or momentum_months != 12
        or direction_epsilon != DIRECTION_EPSILON
        or len(returns) != WORD_LENGTH
        or any(not math.isfinite(value) for value in returns)
    ):
        raise ValueError("locked finite twenty-return baseline required")
    if any(abs(value) <= sign_epsilon for value in returns):
        raise ValueError("inclusive return-sign tie")

    word = "".join("1" if value > sign_epsilon else "0" for value in returns)
    parsed = lz76_parse(word)
    if not 2 <= parsed.complexity <= 9:
        raise ValueError("twenty-bit LZ76 complexity out of bounds")
    qualified = parsed.complexity <= complexity_ceiling
    momentum = sum(returns[8:20])
    direction = 0
    if qualified and momentum > direction_epsilon:
        direction = 1
    elif qualified and momentum < -direction_epsilon:
        direction = -1
    return LZ76Signal(
        direction=direction,
        sign_word=word,
        parse=parsed,
        complexity_qualified=qualified,
        momentum_12=momentum,
    )


def closes_from_returns(returns: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def signal_from_closes(closes: list[float]) -> LZ76Signal:
    if len(closes) != 21 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("twenty-one positive finite closes required")
    returns = [math.log(right / left) for left, right in zip(closes, closes[1:])]
    return signal_from_returns(returns)


def run_count(word: str) -> int:
    if not word:
        return 0
    return 1 + sum(left != right for left, right in zip(word, word[1:]))


def complexity_distribution() -> Counter[int]:
    return Counter(
        lz76_parse(f"{value:0{WORD_LENGTH}b}").complexity
        for value in range(1 << WORD_LENGTH)
    )


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 21 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right for left, right in zip(endpoints, endpoints[1:])
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


class WtiMonthlyLZ76ReferenceTests(unittest.TestCase):
    def test_published_method_reference_word(self) -> None:
        parsed = lz76_parse("0011011101110110")
        self.assertEqual(parsed.complexity, 5)
        self.assertEqual(parsed.phrases, ("0", "01", "10", "111", "01110110"))
        self.assertEqual("".join(parsed.phrases), "0011011101110110")

    def test_equal_sign_and_run_counts_straddle_locked_boundary(self) -> None:
        admitted_word = "00000001101110100100"
        excluded_word = "00000001101110101000"
        admitted = lz76_parse(admitted_word)
        excluded = lz76_parse(excluded_word)
        self.assertEqual((admitted_word.count("1"), run_count(admitted_word)), (7, 9))
        self.assertEqual((excluded_word.count("1"), run_count(excluded_word)), (7, 9))
        self.assertEqual(admitted.phrases, ("0", "0000001", "10", "111", "010", "0100"))
        self.assertEqual(excluded.phrases, ("0", "0000001", "10", "111", "010", "100", "0"))
        self.assertLessEqual(admitted.complexity, COMPLEXITY_CEILING)
        self.assertGreater(excluded.complexity, COMPLEXITY_CEILING)

    def test_terminal_non_exhaustive_suffix_is_unique_and_reconstructed(self) -> None:
        zeros = lz76_parse("0" * 20)
        alternating = lz76_parse("01" * 10)
        self.assertEqual((zeros.complexity, zeros.phrases), (2, ("0", "0" * 19)))
        self.assertEqual((alternating.complexity, alternating.phrases), (3, ("0", "1", "01" * 9)))
        self.assertTrue(zeros.final_component_non_exhaustive)
        self.assertTrue(alternating.final_component_non_exhaustive)
        self.assertEqual(zeros.exhaustive_components, zeros.complexity - 1)
        self.assertEqual(alternating.exhaustive_components, alternating.complexity - 1)

    def test_full_twenty_bit_distribution_matches_predata_receipt(self) -> None:
        distribution = dict(sorted(complexity_distribution().items()))
        self.assertEqual(distribution, EXPECTED_DISTRIBUTION)
        qualified = sum(count for complexity, count in distribution.items() if complexity <= 6)
        self.assertEqual(qualified, 590_076)
        self.assertEqual(sum(distribution.values()), 1 << WORD_LENGTH)

        receipt = json.loads(DENSITY_RECEIPT.read_text(encoding="utf-8"))
        receipt_distribution = {
            int(key): int(value)
            for key, value in receipt["enumeration"][
                "component_count_distribution"
            ].items()
        }
        self.assertEqual(receipt_distribution, EXPECTED_DISTRIBUTION)
        self.assertEqual(receipt["enumeration"]["qualified_words"], qualified)

    def test_gate_and_newest_twelve_month_side(self) -> None:
        buy = signal_from_returns([0.01] * 20)
        sell = signal_from_returns([-0.01] * 20)
        neutral = signal_from_returns([-0.01, 0.01] * 10)
        excluded_word = "00000001101110101000"
        excluded = signal_from_returns(
            [0.01 if bit == "1" else -0.01 for bit in excluded_word]
        )
        self.assertEqual((buy.direction, sell.direction, neutral.direction), (1, -1, 0))
        self.assertTrue(buy.complexity_qualified)
        self.assertTrue(sell.complexity_qualified)
        self.assertAlmostEqual(neutral.momentum_12, 0.0, places=15)
        self.assertEqual(excluded.parse.complexity, 7)
        self.assertFalse(excluded.complexity_qualified)
        self.assertEqual(excluded.direction, 0)

    def test_log_return_orientation_is_oldest_to_newest(self) -> None:
        returns = [-0.01] * 8 + [0.01] * 12
        signal = signal_from_closes(closes_from_returns(returns))
        self.assertEqual(signal.sign_word, "0" * 8 + "1" * 12)
        self.assertEqual(signal.direction, 1)

    def test_ties_dimensions_and_invalid_words_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "tie"):
            signal_from_returns([0.01] * 19 + [SIGN_EPSILON])
        with self.assertRaises(ValueError):
            signal_from_returns([0.01] * 19)
        with self.assertRaises(ValueError):
            signal_from_returns([0.01] * 20, complexity_ceiling=7)
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 20)
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 20 + [0.0])
        with self.assertRaises(ValueError):
            lz76_parse("00120")

    def test_twenty_one_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 202411
        for _ in range(21):
            endpoints.append(key)
            key = next_month_key(key)
        self.assertTrue(validate_month_keys(key, endpoints))
        self.assertFalse(validate_month_keys(key, endpoints[:-1]))
        broken = endpoints.copy()
        broken[8] = broken[7]
        self.assertFalse(validate_month_keys(key, broken))

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41309")
        self.assertEqual(headers["ea_slug"], "wti-mlz76-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41309",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "20",
            "strategy_complexity_ceiling": "6",
            "strategy_sign_epsilon": "0.000000000001",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1000",
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

    def test_source_contract_attempt_order_and_parser_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_LZ76ParseWord", source)
        self.assertIn("bool Strategy_LZ76ReferenceSelfTest", source)
        self.assertIn("bool Strategy_LZ76Signal", source)
        self.assertIn("candidate_start < phrase_start", source)
        self.assertIn("reconstruction != word", source)
        self.assertIn("metrics.complexity <= strategy_complexity_ceiling", source)
        self.assertIn("strategy_month_returns - strategy_momentum_months", source)
        self.assertIn("QM_FrameworkMagic() != 413090000", source)
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
        self.assertIn("41309,wti-mlz76-tr,0,XTIUSD.DWX,413090000", registry)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
