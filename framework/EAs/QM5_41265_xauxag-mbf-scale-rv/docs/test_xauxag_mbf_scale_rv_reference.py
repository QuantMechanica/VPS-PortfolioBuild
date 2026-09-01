from __future__ import annotations

import itertools
import json
import math
import re
import unittest
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41265_xauxag-mbf-scale-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41265_xauxag-mbf-scale-rv_QM5_41265_XAU_XAG_MBF_SCALE_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41265_xauxag-mbf-scale-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


@dataclass(frozen=True)
class BrownForsytheSignal:
    direction: int
    old_median: float
    recent_median: float
    old_z_mean: float
    recent_z_mean: float
    grand_z_mean: float
    ss_between: float
    ss_within: float
    w_statistic: float


def median_six(values: list[float]) -> float:
    if len(values) != 6 or any(not math.isfinite(value) for value in values):
        raise ValueError("six finite values required")
    ordered = sorted(values)
    return 0.5 * (ordered[2] + ordered[3])


def brown_forsythe_signal(changes: list[float]) -> BrownForsytheSignal:
    if len(changes) != 12 or any(not math.isfinite(value) for value in changes):
        raise ValueError("twelve finite changes required")
    old = changes[:6]
    recent = changes[6:]
    old_median = median_six(old)
    recent_median = median_six(recent)
    old_z = [abs(value - old_median) for value in old]
    recent_z = [abs(value - recent_median) for value in recent]
    old_z_mean = sum(old_z) / 6.0
    recent_z_mean = sum(recent_z) / 6.0
    grand_z_mean = 0.5 * (old_z_mean + recent_z_mean)
    ss_between = 6.0 * (old_z_mean - grand_z_mean) ** 2 + 6.0 * (
        recent_z_mean - grand_z_mean
    ) ** 2
    ss_within = sum((value - old_z_mean) ** 2 for value in old_z) + sum(
        (value - recent_z_mean) ** 2 for value in recent_z
    )
    values = (
        old_median,
        recent_median,
        old_z_mean,
        recent_z_mean,
        grand_z_mean,
        ss_between,
        ss_within,
    )
    if any(not math.isfinite(value) for value in values):
        raise ValueError("nonfinite Brown-Forsythe arithmetic")
    if ss_within <= 1.0e-18:
        return BrownForsytheSignal(0, *values, 0.0)
    w_statistic = 10.0 * ss_between / ss_within
    if not math.isfinite(w_statistic):
        raise ValueError("nonfinite Brown-Forsythe W")
    scale_tolerance = 1.0e-12 * max(1.0, abs(old_z_mean), abs(recent_z_mean))
    direction = 0
    if recent_z_mean > old_z_mean + scale_tolerance:
        median_delta = recent_median - old_median
        location_tolerance = 1.0e-12 * max(
            1.0, abs(old_median), abs(recent_median)
        )
        if median_delta > location_tolerance:
            direction = -1
        elif median_delta < -location_tolerance:
            direction = 1
    return BrownForsytheSignal(direction, *values, w_statistic)


def ad2_from_labels(labels: tuple[int, ...]) -> float:
    old_seen = 0
    recent_seen = 0
    total = 0.0
    for rank, label in enumerate(labels[:-1], start=1):
        old_seen += label == 0
        recent_seen += label == 1
        old_delta = 12 * old_seen - 6 * rank
        recent_delta = 12 * recent_seen - 6 * rank
        total += (
            old_delta * old_delta / 6.0 + recent_delta * recent_delta / 6.0
        ) / (rank * (12 - rank))
    return total / 12.0


def kuiper_from_labels(labels: tuple[int, ...]) -> float:
    old_seen = 0
    recent_seen = 0
    d_plus = 0.0
    d_minus = 0.0
    for label in labels:
        old_seen += label == 0
        recent_seen += label == 1
        delta = recent_seen / 6.0 - old_seen / 6.0
        d_plus = max(d_plus, delta)
        d_minus = max(d_minus, -delta)
    return d_plus + d_minus


@lru_cache(maxsize=1)
def label_paths() -> tuple[tuple[int, ...], ...]:
    paths: list[tuple[int, ...]] = []
    for recent_ranks in itertools.combinations(range(12), 6):
        recent = set(recent_ranks)
        paths.append(tuple(1 if rank in recent else 0 for rank in range(12)))
    return tuple(paths)


def rank_neighbor_directions(changes: list[float]) -> tuple[int, int, int]:
    if len(changes) != 12 or len(set(changes)) != 12:
        return 0, 0, 0
    labelled = sorted(
        (value, 0 if index < 6 else 1) for index, value in enumerate(changes)
    )
    labels = tuple(label for _, label in labelled)
    rank_sum = sum(rank for rank, label in enumerate(labels, start=1) if label)
    ad_observed = ad2_from_labels(labels)
    kuiper_observed = kuiper_from_labels(labels)
    ad_tail = sum(
        ad2_from_labels(path) + 1.0e-12 * max(1.0, abs(ad_observed))
        >= ad_observed
        for path in label_paths()
    )
    kuiper_tail = sum(
        kuiper_from_labels(path) + 1.0e-12 * max(1.0, abs(kuiper_observed))
        >= kuiper_observed
        for path in label_paths()
    )
    side = -1 if rank_sum > 39 else 1 if rank_sum < 39 else 0
    ad_direction = side if ad_tail <= 452 and 2 * ad_tail <= 924 else 0
    kuiper_direction = (
        side if kuiper_observed + 1.0e-12 >= 0.5 and kuiper_tail <= 798 else 0
    )
    return ad_direction, kuiper_direction, rank_sum


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


class MonthlyBrownForsytheReferenceTests(unittest.TestCase):
    BF_ONLY = [
        3.75, 1.0, -3.5, 3.5, 2.0, 4.5,
        2.5, 4.75, -2.0, 0.5, 5.0, 0.0,
    ]
    RANK_ONLY = [
        4.75, -3.5, 3.75, -3.75, -2.5, -1.0,
        2.0, -2.0, 0.75, -0.75, -0.5, 6.0,
    ]
    SIDE_DISAGREEMENT = [
        -2.0, 0.75, -3.25, 0.5, -4.75, 0.25,
        3.0, 1.5, -4.5, -3.0, 1.0, -3.5,
    ]

    def test_formula_and_bf_only_fixture_are_locked(self) -> None:
        signal = brown_forsythe_signal(self.BF_ONLY)
        self.assertEqual(signal.direction, 1)
        self.assertAlmostEqual(signal.old_median, 2.75, places=15)
        self.assertAlmostEqual(signal.recent_median, 1.5, places=15)
        self.assertAlmostEqual(signal.old_z_mean, 2.0416666666666665, places=15)
        self.assertAlmostEqual(signal.recent_z_mean, 2.2916666666666665, places=15)
        self.assertAlmostEqual(signal.ss_between, 0.1875, places=15)
        self.assertAlmostEqual(signal.ss_within, 30.10416666666667, places=13)
        self.assertAlmostEqual(signal.w_statistic, 0.06228373702422144, places=15)
        self.assertEqual(rank_neighbor_directions(self.BF_ONLY), (0, 0, 39))

    def test_locked_fixtures_prove_rank_and_side_disagreement(self) -> None:
        rank_only = brown_forsythe_signal(self.RANK_ONLY)
        opposite = brown_forsythe_signal(self.SIDE_DISAGREEMENT)
        self.assertEqual(rank_only.direction, 0)
        self.assertLess(rank_only.recent_z_mean, rank_only.old_z_mean)
        self.assertEqual(rank_neighbor_directions(self.RANK_ONLY), (-1, -1, 46))
        self.assertEqual(opposite.direction, 1)
        self.assertEqual(
            rank_neighbor_directions(self.SIDE_DISAGREEMENT), (-1, -1, 43)
        )

    def test_degenerate_neutral_and_invalid_states_fail_closed(self) -> None:
        degenerate = brown_forsythe_signal([1.0] * 6 + [2.0] * 6)
        self.assertEqual((degenerate.ss_within, degenerate.direction), (0.0, 0))
        neutral = brown_forsythe_signal(
            [-3.0, -2.0, -1.0, 1.0, 2.0, 3.0]
            + [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0]
        )
        self.assertGreater(neutral.recent_z_mean, neutral.old_z_mean)
        self.assertEqual(neutral.direction, 0)
        with self.assertRaises(ValueError):
            brown_forsythe_signal([0.0] * 11 + [math.inf])
        with self.assertRaises(ValueError):
            median_six([1.0] * 5)

    def test_ratio_orientation_and_month_sequence_are_exact(self) -> None:
        ratio_path = [math.log(80.0)]
        for change in self.BF_ONLY:
            ratio_path.append(ratio_path[-1] + change / 10.0)
        xag = [20.0] * 13
        xau = [
            silver * math.exp(ratio)
            for silver, ratio in zip(xag, ratio_path, strict=True)
        ]
        derived = log_ratios(xau, xag)
        changes = [
            right - left
            for left, right in zip(derived[:-1], derived[1:], strict=True)
        ]
        self.assertEqual(brown_forsythe_signal(changes).direction, 1)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12 + [0.0], [1.0] * 13)
        endpoints = [
            202507, 202508, 202509, 202510, 202511, 202512, 202601,
            202602, 202603, 202604, 202605, 202606, 202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        endpoints[7] = 202603
        self.assertFalse(validate_month_keys(202608, endpoints))

    def test_source_manifest_set_card_and_magics_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41265",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_return_count": "12",
            "strategy_block_size": "6",
            "strategy_bf_multiplier": "10.0",
            "strategy_min_within_ss": "0.000000000000000001",
            "strategy_relative_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "900",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertEqual(
            manifest["logical_symbol"], "QM5_41265_XAU_XAG_MBF_SCALE_RV_D1"
        )
        self.assertIn("Strategy_MedianSix", source)
        self.assertIn("Strategy_BrownForsytheSignal", source)
        self.assertIn("median = 0.5 * (sorted[2] + sorted[3])", source)
        self.assertIn("ss_within <= strategy_min_within_ss", source)
        self.assertIn("strategy_bf_multiplier * ss_between / ss_within", source)
        self.assertIn("recent_z_mean <= old_z_mean + scale_tolerance", source)
        self.assertIn("median_delta > location_tolerance", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertIn("Strategy_RefreshExpectedDirection()", source)
        self.assertIn("Strategy_PairCompositionValid(g_pair_expected_direction)", source)
        self.assertNotRegex(
            source, re.compile(r"iRSI|iMACD|iBands|WebRequest|Kuiper|permutation")
        )
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn(
            "41265,xauxag-mbf-scale-rv,0,XAUUSD.DWX,412650000", registry
        )
        self.assertIn(
            "41265,xauxag-mbf-scale-rv,1,XAGUSD.DWX,412650001", registry
        )

    def test_only_factory_and_logical_fixed_risk_backtest_sets_exist(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        self.assertIn(LOGICAL_SET, setfiles)
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))
        for path in setfiles:
            values = parse_setfile(path)
            self.assertEqual(
                (values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0")
            )


if __name__ == "__main__":
    unittest.main()
