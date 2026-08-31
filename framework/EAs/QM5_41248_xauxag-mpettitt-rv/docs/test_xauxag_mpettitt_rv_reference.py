from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41248_xauxag-mpettitt-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41248_xauxag-mpettitt-rv_QM5_41248_XAU_XAG_MPETTITT_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41248_xauxag-mpettitt-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclass(frozen=True)
class PettittRatioSignal:
    direction: int
    ranks: tuple[int, ...]
    rank_sums: tuple[int, ...]
    maximum: int
    maximum_count: int
    change_index: int
    signed_rank_sum: int


def pettitt_ratio_signal(values: list[float]) -> PettittRatioSignal:
    if len(values) != 13:
        raise ValueError("locked endpoint count mismatch")
    if any(not math.isfinite(value) for value in values):
        raise ValueError("finite log ratios required")
    if len(set(values)) != len(values):
        raise ValueError("ties consume flat")

    ordered = sorted(values)
    ranks = tuple(ordered.index(value) + 1 for value in values)
    if sorted(ranks) != list(range(1, 14)):
        raise AssertionError("rank permutation broken")

    rank_sums = tuple(
        2 * sum(ranks[:change_index]) - 14 * change_index
        for change_index in range(1, 13)
    )
    if any(value % 2 or abs(value) > 42 for value in rank_sums):
        raise AssertionError("Pettitt rank-sum invariant broken")
    maximum = max(abs(value) for value in rank_sums)
    maxima = tuple(
        index
        for index, value in enumerate(rank_sums, 1)
        if abs(value) == maximum
    )
    change_index = maxima[0] if len(maxima) == 1 else 0
    signed_rank_sum = rank_sums[change_index - 1] if change_index else 0
    direction = 0
    if len(maxima) == 1 and 4 <= change_index <= 9:
        direction = -1 if signed_rank_sum < 0 else 1
    return PettittRatioSignal(
        direction,
        ranks,
        rank_sums,
        maximum,
        len(maxima),
        change_index,
        signed_rank_sum,
    )


def log_ratios(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != 13 or len(xag) != 13:
        raise ValueError("exactly thirteen synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xau + xag):
        raise ValueError("positive finite closes required")
    return [
        math.log(gold) - math.log(silver)
        for gold, silver in zip(xau, xag, strict=True)
    ]


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    return (
        len(endpoints) == 13
        and next_month_key(endpoints[-1]) == current_month
        and all(
            next_month_key(left) == right
            for left, right in zip(endpoints[:-1], endpoints[1:], strict=True)
        )
    )


def parse_setfile(path: Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        key, value = line.split("=", 1)
        parsed[key] = value
    return parsed


class MonthlyPettittRatioReferenceTests(unittest.TestCase):
    def test_unique_central_shift_opens_exact_contrarian_side(self) -> None:
        rising_fixture = [1, 8, 5, 7, 2, 10, 11, 6, 12, 3, 9, 4, 13]
        signal = pettitt_ratio_signal(list(map(float, rising_fixture)))
        self.assertEqual(
            (
                signal.direction,
                signal.maximum,
                signal.maximum_count,
                signal.change_index,
                signal.signed_rank_sum,
            ),
            (-1, 24, 1, 5, -24),
        )
        inverse = pettitt_ratio_signal([float(14 - value) for value in rising_fixture])
        self.assertEqual(
            (inverse.direction, inverse.maximum, inverse.change_index, inverse.signed_rank_sum),
            (1, 24, 5, 24),
        )

    def test_tied_and_edge_maxima_consume_flat(self) -> None:
        monotone = pettitt_ratio_signal([float(value) for value in range(1, 14)])
        self.assertEqual((monotone.direction, monotone.maximum, monotone.maximum_count), (0, 42, 2))
        edge_fixture = [1, 2, 13, 6, 5, 7, 8, 12, 10, 3, 4, 11, 9]
        edge = pettitt_ratio_signal(list(map(float, edge_fixture)))
        self.assertEqual((edge.direction, edge.maximum, edge.maximum_count, edge.change_index), (0, 22, 1, 2))

    def test_pettitt_state_is_not_the_fixed_six_by_six_neighbor(self) -> None:
        rank_path = [11, 7, 6, 2, 5, 4, 12, 3, 9, 8, 13, 1, 10]
        signal = pettitt_ratio_signal(list(map(float, rank_path)))
        self.assertEqual(
            (signal.direction, signal.maximum, signal.change_index, signal.signed_rank_sum),
            (-1, 14, 6, -14),
        )

        # The XAU/XAG Mann-Whitney neighbor uses only the latest twelve
        # endpoints and one fixed six/six split.  Its U_new=22 is inside its
        # no-trade band, while this card's unique Pettitt K=6 qualifies.
        latest_twelve = rank_path[1:]
        older, newer = latest_twelve[:6], latest_twelve[6:]
        u_new = sum(new > old for old in older for new in newer)
        self.assertEqual(u_new, 22)
        self.assertGreater(u_new, 12)
        self.assertLess(u_new, 24)

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            pettitt_ratio_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        with self.assertRaises(ValueError):
            pettitt_ratio_signal([float(value) for value in range(1, 13)] + [math.inf])

    def test_log_ratio_orientation_and_month_sequence(self) -> None:
        rank_fixture = [1, 8, 5, 7, 2, 10, 11, 6, 12, 3, 9, 4, 13]
        xau = [100.0 * math.exp(0.001 * value) for value in rank_fixture]
        xag = [10.0] * 13
        self.assertEqual(pettitt_ratio_signal(log_ratios(xau, xag)).direction, -1)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_sets_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41248",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_min_change_index": "4",
            "strategy_max_change_index": "9",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41248_XAU_XAG_MPETTITT_RV_D1")
        self.assertIn("const int rank_sum =", source)
        self.assertIn("maximum_count == 1", source)
        self.assertIn("change_index >= strategy_min_change_index", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("XAUXAG_MPETTITT_RV_PAIR_DIRECTION", source)
        self.assertIn("xau_type == expected_xau_type", source)
        self.assertIn("xag_type == expected_xag_type", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))
            self.assertEqual(values["strategy_xag_max_spread_points"], "500")


if __name__ == "__main__":
    unittest.main()
