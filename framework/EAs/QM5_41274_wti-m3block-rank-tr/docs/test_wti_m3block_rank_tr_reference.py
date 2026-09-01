from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41274_wti-m3block-rank-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41274_wti-m3block-rank-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41274_wti-m3block-rank-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"

MONTH_SESSIONS_MIN = 17
MONTH_SESSIONS_MAX = 23
CLOSE_COUNT = 15
BLOCK_SIZE = 5
COMPARISON_COUNT = 75
CENTER_DOUBLED = 75
TIE_POINTS = 0.5


@dataclass(frozen=True)
class Signal:
    direction: int
    comparisons: int
    wins: int
    close_tie: bool = False


def final_fifteen(month_closes: list[float]) -> list[float]:
    if not MONTH_SESSIONS_MIN <= len(month_closes) <= MONTH_SESSIONS_MAX:
        raise ValueError("completed month must contain 17..23 sessions")
    if any(not math.isfinite(value) or value <= 0.0 for value in month_closes):
        raise ValueError("positive finite closes required")
    return month_closes[-CLOSE_COUNT:]


def ordinal_signal(closes: list[float], point: float = 1.0) -> Signal:
    if len(closes) != CLOSE_COUNT:
        raise ValueError("exact final-fifteen sample required")
    if not math.isfinite(point) or point <= 0.0:
        raise ValueError("positive finite symbol point required")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("positive finite closes required")
    tie_distance = TIE_POINTS * point
    if any(
        abs(closes[left] - closes[right]) <= tie_distance
        for left in range(CLOSE_COUNT - 1)
        for right in range(left + 1, CLOSE_COUNT)
    ):
        return Signal(0, 0, 0, close_tie=True)

    comparisons = 0
    wins = 0
    for earlier_block, later_block in ((0, 1), (0, 2), (1, 2)):
        for earlier_index in range(BLOCK_SIZE):
            x = closes[earlier_block * BLOCK_SIZE + earlier_index]
            for later_index in range(BLOCK_SIZE):
                y = closes[later_block * BLOCK_SIZE + later_index]
                comparisons += 1
                wins += y > x
    if comparisons != COMPARISON_COUNT:
        raise ValueError("cross-block comparison invariant failed")
    doubled = 2 * wins
    if doubled > CENTER_DOUBLED:
        direction = 1
    elif doubled < CENTER_DOUBLED:
        direction = -1
    else:
        raise ValueError("even doubled score cannot equal odd midpoint")
    return Signal(direction, comparisons, wins)


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


class WtiThreeBlockOrdinalTrendReferenceTests(unittest.TestCase):
    def test_monotone_extremes_use_all_75_comparisons(self) -> None:
        long_signal = ordinal_signal(list(range(1, 16)))
        short_signal = ordinal_signal(list(range(15, 0, -1)))
        self.assertEqual(
            (long_signal.direction, long_signal.comparisons, long_signal.wins),
            (1, 75, 75),
        )
        self.assertEqual(
            (short_signal.direction, short_signal.comparisons, short_signal.wins),
            (-1, 75, 0),
        )

    def test_strict_midpoint_boundary_is_38_long_37_short(self) -> None:
        wins_38 = [3, 7, 4, 15, 11, 13, 8, 12, 2, 5, 10, 9, 6, 14, 1]
        wins_37 = [11, 7, 6, 14, 4, 15, 10, 1, 2, 9, 8, 3, 12, 5, 13]
        long_signal = ordinal_signal(wins_38)
        short_signal = ordinal_signal(wins_37)
        self.assertEqual((long_signal.wins, long_signal.direction), (38, 1))
        self.assertEqual((short_signal.wins, short_signal.direction), (37, -1))
        self.assertNotEqual(2 * long_signal.wins, CENTER_DOUBLED)
        self.assertNotEqual(2 * short_signal.wins, CENTER_DOUBLED)

    def test_half_point_or_closer_pair_consumes_flat(self) -> None:
        closes = [float(value) for value in range(10, 25)]
        closes[1] = closes[0] + 0.5
        at_boundary = ordinal_signal(closes, point=1.0)
        self.assertTrue(at_boundary.close_tie)
        self.assertEqual(at_boundary.direction, 0)

        closes[1] = closes[0] + 0.49
        inside = ordinal_signal(closes, point=1.0)
        self.assertTrue(inside.close_tie)
        closes[1] = closes[0] + 0.51
        outside = ordinal_signal(closes, point=1.0)
        self.assertFalse(outside.close_tie)

    def test_within_block_permutation_does_not_change_score(self) -> None:
        closes = [3, 7, 4, 15, 11, 13, 8, 12, 2, 5, 10, 9, 6, 14, 1]
        permuted = (
            list(reversed(closes[0:5]))
            + [closes[7], closes[5], closes[9], closes[6], closes[8]]
            + [closes[12], closes[14], closes[10], closes[13], closes[11]]
        )
        original_signal = ordinal_signal(closes)
        permuted_signal = ordinal_signal(permuted)
        self.assertEqual(
            (original_signal.wins, original_signal.direction),
            (permuted_signal.wins, permuted_signal.direction),
        )

    def test_fixed_three_block_vote_disagreement_fixture(self) -> None:
        closes = [1, 2, 3, 4, 10, 11, 12, 13, 14, 9, 15, 16, 17, 18, 8]
        signal = ordinal_signal(closes)
        self.assertEqual((signal.wins, signal.direction), (68, 1))
        parent_close = 5
        block_returns = (
            math.log(closes[4] / parent_close),
            math.log(closes[9] / closes[4]),
            math.log(closes[14] / closes[9]),
        )
        self.assertEqual(tuple(value > 0 for value in block_returns), (True, False, False))

    def test_endpoint_return_disagreement_fixture(self) -> None:
        closes = [*range(100, 114), 99]
        signal = ordinal_signal(closes)
        self.assertEqual((signal.wins, signal.direction), (65, 1))
        self.assertLess(closes[-1] / closes[0] - 1.0, 0.0)

    def test_final_fifteen_selection_and_session_bounds(self) -> None:
        month = [50.0 + index for index in range(20)]
        self.assertEqual(final_fifteen(month), month[5:])
        self.assertEqual(len(final_fifteen(month[:17])), CLOSE_COUNT)
        self.assertEqual(len(final_fifteen(month + [70.0, 71.0, 72.0])), CLOSE_COUNT)
        with self.assertRaises(ValueError):
            final_fifteen(month[:16])
        with self.assertRaises(ValueError):
            final_fifteen(month + [70.0, 71.0, 72.0, 73.0])

    def test_source_contains_literal_formula_and_attempt_order(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        required = (
            "bool Strategy_LoadCompletedMonthCloses",
            "strategy_close_count - 1 - index",
            "bool Strategy_OrdinalSupportValid",
            "loop_comparisons == 75",
            "long_states == 38 && short_states == 38 && flat_states == 0",
            "bool Strategy_OrdinalSignal",
            "MathAbs(closes[left] - closes[right]) <= tie_distance",
            "++metrics.comparison_count",
            "if(closes[y] > closes[x])",
            "2 * metrics.win_count > strategy_center_doubled",
            "2 * metrics.win_count < strategy_center_doubled",
            "QM_FrameworkMagic() != 412740000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41274",
        )
        for literal in required:
            self.assertIn(literal, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadCompletedMonthCloses"),
        )
        for banned in (
            "iRSI",
            "iBands",
            "iMA(",
            "iMACD",
            "MathRand",
            "WebRequest",
            "FileOpen",
        ):
            self.assertNotIn(banned, source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41274")
        self.assertEqual(headers["ea_slug"], "wti-m3block-rank-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41274",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_sessions_min": "17",
            "strategy_month_sessions_max": "23",
            "strategy_close_count": "15",
            "strategy_block_size": "5",
            "strategy_comparison_count": "75",
            "strategy_center_doubled": "75",
            "strategy_tie_points": "0.5",
            "strategy_history_bars_d1": "120",
            "strategy_entry_window_minutes": "180",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
            "strategy_deviation_points": "20",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_card_copy_and_only_backtest_set_exist(self) -> None:
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
