from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41247_xauxag-mcusum-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41247_xauxag-mcusum-rv_QM5_41247_XAU_XAG_MCUSUM_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41247_xauxag-mcusum-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclass(frozen=True)
class CusumSignal:
    direction: int
    selected_split: int
    maxima_count: int
    mean_return: float
    max_abs_cusum: float
    selected_cusum: float
    post_mean: float


def cusum_signal(
    ratios: list[float],
    minimum_split: int = 4,
    maximum_split: int = 8,
    epsilon: float = 1.0e-12,
) -> CusumSignal:
    if (
        len(ratios) != 13
        or minimum_split != 4
        or maximum_split != 8
        or epsilon != 1.0e-12
    ):
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) for value in ratios):
        raise ValueError("finite log ratios required")

    returns = [right - left for left, right in zip(ratios[:-1], ratios[1:], strict=True)]
    mean_return = sum(returns) / len(returns)
    running = 0.0
    cusums: list[float] = []
    for split, value in enumerate(returns[:-1], start=1):
        running += value
        cusums.append(running - split * mean_return)
    if any(not math.isfinite(value) for value in returns + cusums + [mean_return]):
        raise ValueError("finite arithmetic required")

    max_abs = max(abs(value) for value in cusums)
    maxima = [
        index + 1
        for index, value in enumerate(cusums)
        if abs(abs(value) - max_abs) <= epsilon
    ]
    selected_split = maxima[0]
    selected_cusum = cusums[selected_split - 1]
    post_mean = 0.0
    direction = 0
    if (
        max_abs > epsilon
        and len(maxima) == 1
        and minimum_split <= selected_split <= maximum_split
    ):
        post = returns[selected_split:]
        post_mean = sum(post) / len(post)
        direction = -1 if post_mean > epsilon else 1 if post_mean < -epsilon else 0
    return CusumSignal(
        direction,
        selected_split,
        len(maxima),
        mean_return,
        max_abs,
        selected_cusum,
        post_mean,
    )


def ratios_from_returns(returns: list[float], start: float = 5.0) -> list[float]:
    if len(returns) != 12:
        raise ValueError("twelve relative returns required")
    values = [start]
    for value in returns:
        values.append(values[-1] + value)
    return values


def piecewise_zero_mean(split: int, old_value: float = -1.0) -> list[float]:
    if not 1 <= split <= 11:
        raise ValueError("nonterminal split required")
    new_value = -(split * old_value) / (12 - split)
    return [old_value] * split + [new_value] * (12 - split)


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


class MonthlyCusumRatioReferenceTests(unittest.TestCase):
    def test_unique_central_shift_opens_exact_contrarian_sides(self) -> None:
        positive_post = cusum_signal(ratios_from_returns(piecewise_zero_mean(4)))
        negative_post = cusum_signal(
            ratios_from_returns(piecewise_zero_mean(4, old_value=1.0))
        )
        self.assertEqual(
            (positive_post.selected_split, positive_post.maxima_count, positive_post.direction),
            (4, 1, -1),
        )
        self.assertEqual(
            (negative_post.selected_split, negative_post.maxima_count, negative_post.direction),
            (4, 1, 1),
        )

    def test_split_band_boundaries_are_exact(self) -> None:
        expected = {3: 0, 4: -1, 8: -1, 9: 0}
        for split, direction in expected.items():
            with self.subTest(split=split):
                result = cusum_signal(ratios_from_returns(piecewise_zero_mean(split)))
                self.assertEqual(result.selected_split, split)
                self.assertEqual(result.maxima_count, 1)
                self.assertEqual(result.direction, direction)

    def test_tied_and_zero_maxima_consume_flat(self) -> None:
        tied = cusum_signal(ratios_from_returns([1.0, -1.0] * 6))
        zero = cusum_signal([7.0] * 13)
        self.assertGreater(tied.maxima_count, 1)
        self.assertEqual(tied.direction, 0)
        self.assertEqual((zero.max_abs_cusum, zero.direction), (0.0, 0))

    def test_full_sample_centering_and_terminal_zero(self) -> None:
        returns = piecewise_zero_mean(6, old_value=-0.25)
        result = cusum_signal(ratios_from_returns(returns))
        self.assertAlmostEqual(result.mean_return, 0.0, places=15)
        self.assertEqual(result.selected_split, 6)
        self.assertAlmostEqual(result.selected_cusum, -1.5, places=15)
        self.assertAlmostEqual(sum(returns) - 12 * result.mean_return, 0.0, places=15)

    def test_ratio_orientation_invalid_values_and_month_sequence(self) -> None:
        relative_returns = piecewise_zero_mean(4)
        ratio_path = ratios_from_returns(relative_returns, start=math.log(10.0))
        xag = [10.0] * 13
        xau = [silver * math.exp(ratio) for silver, ratio in zip(xag, ratio_path, strict=True)]
        self.assertEqual(cusum_signal(log_ratios(xau, xag)).direction, -1)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        with self.assertRaises(ValueError):
            cusum_signal([float(value) for value in range(12)] + [math.inf])
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_set_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41247",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_min_split": "4",
            "strategy_max_split": "8",
            "strategy_tie_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41247_XAU_XAG_MCUSUM_RV_D1")
        self.assertIn("running - (double)split * mean_return", source)
        self.assertIn("distance <= strategy_tie_epsilon", source)
        self.assertIn("selected_split >= strategy_min_split", source)
        self.assertIn("post_mean > strategy_tie_epsilon", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn("Strategy_PairCompositionValid(g_pair_expected_direction)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )

    def test_only_factory_and_logical_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))


if __name__ == "__main__":
    unittest.main()
