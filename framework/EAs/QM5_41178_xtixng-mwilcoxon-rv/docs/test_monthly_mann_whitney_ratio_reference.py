from __future__ import annotations

import dataclasses
import itertools
import json
import math
import re
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41178_xtixng-mwilcoxon-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41178_xtixng-mwilcoxon-rv_QM5_41178_XTI_XNG_MWILCOXON_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41178_xtixng-mwilcoxon-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclasses.dataclass(frozen=True)
class MannWhitneyRatioSignal:
    direction: int
    u_new: int
    u_old: int
    newer_rank_sum: int


def mann_whitney_ratio_signal(
    ratios: list[float],
    block_size: int = 6,
    lower: int = 12,
    upper: int = 24,
) -> MannWhitneyRatioSignal:
    if len(ratios) != 12 or block_size != 6 or lower != 12 or upper != 24:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) for value in ratios):
        raise ValueError("finite log ratios required")
    if len(set(ratios)) != len(ratios):
        raise ValueError("ties fail closed")

    older = ratios[:block_size]
    newer = ratios[block_size:]
    u_new = sum(new > old for new in newer for old in older)
    u_old = sum(old > new for new in newer for old in older)
    newer_rank_sum = sum(
        1 + sum(other < value for other in ratios) for value in newer
    )
    if (
        not 0 <= u_new <= 36
        or not 0 <= u_old <= 36
        or u_new + u_old != 36
        or newer_rank_sum - 21 != u_new
    ):
        raise AssertionError("Mann-Whitney identity broken")

    # Fade the ratio displacement: high newer location means short ratio.
    direction = -1 if u_new >= upper else 1 if u_new <= lower else 0
    return MannWhitneyRatioSignal(direction, u_new, u_old, newer_rank_sum)


def ratios_for_newer_ranks(newer_ranks: tuple[int, ...]) -> list[float]:
    newer = set(newer_ranks)
    older_ranks = [rank for rank in range(1, 13) if rank not in newer]
    return [float(rank) for rank in older_ranks + list(newer_ranks)]


def log_ratios(xti: list[float], xng: list[float]) -> list[float]:
    if len(xti) != 12 or len(xng) != 12:
        raise ValueError("exactly twelve synchronized closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in xti + xng):
        raise ValueError("positive finite closes required")
    return [
        math.log(oil) - math.log(gas)
        for oil, gas in zip(xti, xng, strict=True)
    ]


def spearman_integer_score(ranks: list[int]) -> int:
    if len(ranks) != 13 or sorted(ranks) != list(range(1, 14)):
        raise ValueError("thirteen strict ranks required")
    return 364 - sum(
        (rank - time_rank) ** 2
        for time_rank, rank in enumerate(ranks, 1)
    )


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    return (
        len(endpoints) == 12
        and next_month_key(endpoints[-1]) == current_month
        and all(
            next_month_key(left) == right
            for left, right in zip(endpoints[:-1], endpoints[1:], strict=True)
        )
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
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return headers, values


class MonthlyMannWhitneyRatioReferenceTests(unittest.TestCase):
    def test_extremes_and_identity_are_symmetric_and_contrarian(self) -> None:
        upward = mann_whitney_ratio_signal(
            [float(value) for value in range(1, 13)]
        )
        downward = mann_whitney_ratio_signal(
            [float(value) for value in range(12, 0, -1)]
        )
        self.assertEqual(upward, MannWhitneyRatioSignal(-1, 36, 0, 57))
        self.assertEqual(downward, MannWhitneyRatioSignal(1, 0, 36, 21))

    def test_inclusive_boundaries_and_central_region(self) -> None:
        by_u: dict[int, tuple[int, ...]] = {}
        for newer in itertools.combinations(range(1, 13), 6):
            by_u.setdefault(sum(newer) - 21, newer)
        self.assertEqual(
            mann_whitney_ratio_signal(ratios_for_newer_ranks(by_u[12])).direction,
            1,
        )
        self.assertEqual(
            mann_whitney_ratio_signal(ratios_for_newer_ranks(by_u[13])).direction,
            0,
        )
        self.assertEqual(
            mann_whitney_ratio_signal(ratios_for_newer_ranks(by_u[23])).direction,
            0,
        )
        self.assertEqual(
            mann_whitney_ratio_signal(ratios_for_newer_ranks(by_u[24])).direction,
            -1,
        )

    def test_exact_density_lock_covers_all_rank_assignments(self) -> None:
        distribution = [
            sum(newer) - 21
            for newer in itertools.combinations(range(1, 13), 6)
        ]
        low = sum(value <= 12 for value in distribution)
        high = sum(value >= 24 for value in distribution)
        self.assertEqual((len(distribution), low, high), (924, 182, 182))
        self.assertEqual(low + high, 364)
        self.assertAlmostEqual((low + high) / 924, 0.3939393939393939)

    def test_ties_invalid_values_and_unlocked_inputs_fail(self) -> None:
        with self.assertRaises(ValueError):
            mann_whitney_ratio_signal([1.0] * 12)
        with self.assertRaises(ValueError):
            mann_whitney_ratio_signal(
                [float(value) for value in range(1, 12)] + [math.inf]
            )
        with self.assertRaises(ValueError):
            mann_whitney_ratio_signal(
                [float(value) for value in range(1, 13)], upper=25
            )
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 11 + [0.0], [1.0] * 12)

    def test_locked_nonduplicate_fixtures(self) -> None:
        first = [11, 13, 2, 4, 6, 1, 3, 10, 5, 7, 8, 9, 12]
        second = [1, 8, 3, 5, 7, 11, 9, 4, 2, 12, 13, 6, 10]
        third = [11, 10, 9, 8, 3, 2, 1, 13, 4, 5, 6, 12, 7]
        self.assertEqual(
            (
                mann_whitney_ratio_signal(list(map(float, first[1:]))).direction,
                mann_whitney_ratio_signal(list(map(float, first[1:]))).u_new,
                spearman_integer_score(first),
            ),
            (-1, 29, 52),
        )
        self.assertEqual(
            (
                mann_whitney_ratio_signal(list(map(float, second[1:]))).direction,
                mann_whitney_ratio_signal(list(map(float, second[1:]))).u_new,
                spearman_integer_score(second),
            ),
            (0, 20, 176),
        )
        self.assertEqual(
            (
                mann_whitney_ratio_signal(list(map(float, third[1:]))).direction,
                mann_whitney_ratio_signal(list(map(float, third[1:]))).u_new,
                spearman_integer_score(third),
            ),
            (-1, 24, -44),
        )

    def test_log_ratio_orientation_and_month_sequence(self) -> None:
        xti = [100.0 * math.exp(0.01 * index) for index in range(12)]
        xng = [10.0] * 12
        self.assertEqual(
            mann_whitney_ratio_signal(log_ratios(xti, xng)).direction,
            -1,
        )
        endpoints = [
            202508,
            202509,
            202510,
            202511,
            202512,
            202601,
            202602,
            202603,
            202604,
            202605,
            202606,
            202607,
        ]
        self.assertTrue(validate_month_keys(202608, endpoints))
        broken = endpoints.copy()
        broken[6] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_source_manifest_sets_and_card_copy_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        headers, values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41178",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "12",
            "strategy_block_size": "6",
            "strategy_u_lower": "12",
            "strategy_u_upper": "24",
            "strategy_history_bars_d1": "900",
            "strategy_xti_max_spread_points": "1500",
            "strategy_xng_max_spread_points": "3000",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(headers["symbol"], manifest["logical_symbol"])
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        self.assertEqual(
            manifest["logical_symbol"],
            "QM5_41178_XTI_XNG_MWILCOXON_RV_D1",
        )
        self.assertIn("Strategy_LoadMonthlyMannWhitney", source)
        self.assertIn("++u_new", source)
        self.assertIn("++u_old", source)
        self.assertIn("u_new + u_old != pair_count", source)
        self.assertIn("newer_rank_sum - minimum_rank_sum != u_new", source)
        self.assertIn("if(u_new >= strategy_u_upper)", source)
        self.assertIn("else if(u_new <= strategy_u_lower)", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xng)", source)
        self.assertNotIn("Strategy_LoadMonthlySpearman", source)
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
            headers, values = parse_setfile(path)
            self.assertEqual(headers["environment"], "backtest")
            self.assertEqual(headers["risk_mode"], "FIXED")
            self.assertEqual((values["RISK_FIXED"], values["RISK_PERCENT"]), ("1000", "0"))
            self.assertEqual(values["strategy_endpoint_count"], "12")
            self.assertEqual(values["strategy_block_size"], "6")


if __name__ == "__main__":
    unittest.main()
