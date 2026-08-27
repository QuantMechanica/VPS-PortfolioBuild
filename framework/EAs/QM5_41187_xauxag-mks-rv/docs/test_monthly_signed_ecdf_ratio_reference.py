from __future__ import annotations

import dataclasses
from itertools import combinations
import json
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41187_xauxag-mks-rv.mq5"
LOGICAL_SET = (
    EA_DIR
    / "sets"
    / "QM5_41187_xauxag-mks-rv_QM5_41187_XAU_XAG_MKS_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41187_xauxag-mks-rv_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


@dataclasses.dataclass(frozen=True)
class SignedEcdfRatioSignal:
    direction: int
    d_plus_count: int
    d_minus_count: int
    membership_path: tuple[str, ...]
    delta_path: tuple[int, ...]


def signed_ecdf_ratio_signal(
    ratios: list[float], min_gap_count: int = 3
) -> SignedEcdfRatioSignal:
    if len(ratios) != 12 or min_gap_count != 3:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) for value in ratios):
        raise ValueError("ratios must be finite")
    if len(set(ratios)) != len(ratios):
        raise ValueError("ties fail closed")

    ordered = sorted(enumerate(ratios), key=lambda item: item[1])
    old_seen = new_seen = d_plus = d_minus = 0
    membership: list[str] = []
    deltas: list[int] = []
    for index, _value in ordered:
        if index < 6:
            old_seen += 1
            membership.append("O")
        else:
            new_seen += 1
            membership.append("N")
        delta = old_seen - new_seen
        deltas.append(delta)
        d_plus = max(d_plus, delta)
        d_minus = max(d_minus, -delta)

    if old_seen != 6 or new_seen != 6 or len(deltas) != 12:
        raise AssertionError("combined scan broken")
    if not 0 <= d_plus <= 6 or not 0 <= d_minus <= 6:
        raise AssertionError("signed-gap bounds broken")

    # Positive means BUY XAU / SELL XAG. The ratio basket fades rather than
    # follows the newer distribution displacement.
    direction = 0
    if d_plus >= min_gap_count and d_plus > d_minus:
        direction = -1
    elif d_minus >= min_gap_count and d_minus > d_plus:
        direction = 1
    return SignedEcdfRatioSignal(
        direction=direction,
        d_plus_count=d_plus,
        d_minus_count=d_minus,
        membership_path=tuple(membership),
        delta_path=tuple(deltas),
    )


def ratios_for_old_ranks(old_ranks: tuple[int, ...]) -> list[float]:
    old_set = set(old_ranks)
    if len(old_ranks) != 6 or len(old_set) != 6:
        raise ValueError("requires six distinct old ranks")
    new_ranks = tuple(rank for rank in range(1, 13) if rank not in old_set)
    if len(new_ranks) != 6:
        raise ValueError("requires six complementary new ranks")
    return [float(rank) for rank in old_ranks + new_ranks]


def exact_assignment_density() -> tuple[int, int, int, int, int, int]:
    total = long_ratio = short_ratio = weak_flat = tied_flat = 0
    for old_ranks in combinations(range(1, 13), 6):
        signal = signed_ecdf_ratio_signal(ratios_for_old_ranks(old_ranks))
        total += 1
        if signal.direction > 0:
            long_ratio += 1
        elif signal.direction < 0:
            short_ratio += 1
        elif (
            signal.d_plus_count >= 3
            and signal.d_plus_count == signal.d_minus_count
        ):
            tied_flat += 1
        else:
            weak_flat += 1
    return total, long_ratio, short_ratio, weak_flat, tied_flat, weak_flat + tied_flat


def mann_whitney_u_new(ratios: list[float]) -> int:
    if len(ratios) != 12 or len(set(ratios)) != 12:
        raise ValueError("requires twelve strict values")
    return sum(new > old for old in ratios[:6] for new in ratios[6:])


def log_ratios(xau: list[float], xag: list[float]) -> list[float]:
    if len(xau) != 12 or len(xag) != 12:
        raise ValueError("exactly twelve synchronized closes required")
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
    if len(endpoints) != 12 or next_month_key(endpoints[-1]) != current_month:
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
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return headers, values


class MonthlySignedEcdfRatioReferenceTests(unittest.TestCase):
    def test_combined_scan_preserves_fixed_membership_and_fades(self) -> None:
        ratios = [1, 2, 3, 5, 11, 12, 4, 6, 7, 8, 9, 10]
        signal = signed_ecdf_ratio_signal([float(value) for value in ratios])
        self.assertEqual(
            signal.membership_path,
            ("O", "O", "O", "N", "O", "N", "N", "N", "N", "N", "O", "O"),
        )
        self.assertEqual(
            signal.delta_path,
            (1, 2, 3, 2, 3, 2, 1, 0, -1, -2, -1, 0),
        )
        self.assertEqual((signal.d_plus_count, signal.d_minus_count), (3, 2))
        self.assertEqual(signal.direction, -1)

    def test_inclusive_boundary_reflection_and_tied_max_flat(self) -> None:
        high_fade = signed_ecdf_ratio_signal(
            ratios_for_old_ranks((1, 2, 3, 5, 7, 9))
        )
        low_fade = signed_ecdf_ratio_signal(
            ratios_for_old_ranks((2, 4, 6, 10, 11, 12))
        )
        tied = signed_ecdf_ratio_signal(
            ratios_for_old_ranks((1, 2, 3, 10, 11, 12))
        )
        self.assertEqual(
            (high_fade.d_plus_count, high_fade.d_minus_count, high_fade.direction),
            (3, 0, -1),
        )
        self.assertEqual(
            (low_fade.d_plus_count, low_fade.d_minus_count, low_fade.direction),
            (0, 3, 1),
        )
        self.assertEqual(
            (tied.d_plus_count, tied.d_minus_count, tied.direction),
            (3, 3, 0),
        )

    def test_exact_density_side_symmetry_and_tied_count(self) -> None:
        total, long_ratio, short_ratio, weak, tied, flat = exact_assignment_density()
        self.assertEqual(
            (total, long_ratio, short_ratio, weak, tied, flat),
            (924, 218, 218, 486, 2, 488),
        )
        self.assertEqual(long_ratio + short_ratio, 436)
        self.assertAlmostEqual((long_ratio + short_ratio) / total, 109 / 231, places=15)
        within_block_orders = math.factorial(6) ** 2
        self.assertEqual(total * within_block_orders, math.factorial(12))

    def test_ties_invalid_values_and_unlocked_threshold_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            signed_ecdf_ratio_signal([1.0] * 12)
        with self.assertRaises(ValueError):
            signed_ecdf_ratio_signal([float(value) for value in range(1, 12)] + [math.inf])
        with self.assertRaises(ValueError):
            signed_ecdf_ratio_signal([float(value) for value in range(1, 13)], 2)
        with self.assertRaises(ValueError):
            log_ratios([1.0] * 12, [1.0] * 11 + [0.0])

    def test_mann_whitney_separating_fixtures(self) -> None:
        ks_short = [1, 2, 3, 5, 11, 12, 4, 6, 7, 8, 9, 10]
        ks_flat = [1, 2, 4, 6, 8, 10, 3, 5, 7, 9, 11, 12]
        short_signal = signed_ecdf_ratio_signal([float(value) for value in ks_short])
        flat_signal = signed_ecdf_ratio_signal([float(value) for value in ks_flat])
        self.assertEqual((short_signal.direction, mann_whitney_u_new(ks_short)), (-1, 23))
        self.assertEqual((flat_signal.direction, mann_whitney_u_new(ks_flat)), (0, 26))

    def test_within_block_order_is_irrelevant(self) -> None:
        left = [1, 2, 3, 5, 11, 12, 4, 6, 7, 8, 9, 10]
        right = [12, 3, 11, 1, 5, 2, 9, 4, 10, 7, 6, 8]
        self.assertEqual(signed_ecdf_ratio_signal(left), signed_ecdf_ratio_signal(right))

    def test_log_ratio_orientation_and_month_sequence(self) -> None:
        xau = [100.0 * math.exp(0.01 * index) for index in range(12)]
        xag = [10.0] * 12
        self.assertEqual(signed_ecdf_ratio_signal(log_ratios(xau, xag)).direction, -1)
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
        self.assertFalse(validate_month_keys(202608, endpoints[:-1]))
        broken = endpoints.copy()
        broken[7] = 202604
        self.assertFalse(validate_month_keys(202608, broken))

    def test_source_manifest_sets_card_and_magics_are_locked(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        headers, values = parse_setfile(LOGICAL_SET)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        expected = {
            "qm_ea_id": "41187",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_xag_symbol": "XAGUSD.DWX",
            "strategy_endpoint_count": "12",
            "strategy_block_size": "6",
            "strategy_min_gap_count": "3",
            "strategy_history_bars_d1": "900",
            "strategy_entry_window_minutes": "180",
            "strategy_max_endpoint_gap_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_notional_ratio": "1.0",
            "strategy_max_notional_mismatch_fraction": "0.20",
            "strategy_max_hold_days": "40",
            "strategy_xau_max_spread_points": "1500",
            "strategy_xag_max_spread_points": "500",
        }
        self.assertEqual({key: values[key] for key in expected}, expected)
        self.assertEqual(headers["symbol"], manifest["logical_symbol"])
        self.assertEqual(manifest["logical_symbol"], "QM5_41187_XAU_XAG_MKS_RV_D1")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        self.assertIn("Strategy_LoadMonthlySignedEcdf", source)
        self.assertIn("metrics.dplus_count = MathMax", source)
        self.assertIn("metrics.dminus_count = MathMax", source)
        self.assertIn("metrics.dplus_count > metrics.dminus_count", source)
        self.assertIn("metrics.dminus_count > metrics.dplus_count", source)
        self.assertIn("metrics.direction = -1", source)
        self.assertIn("metrics.direction = 1", source)
        self.assertIn("Strategy_RecordAttemptState(g_signal_month_key)", source)
        self.assertIn("QM_MagicChecked(qm_ea_id, 1, g_leg_xag)", source)
        self.assertNotRegex(source, re.compile(r"iRSI|iMACD|iBands|WebRequest"))
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        rows = MAGIC_REGISTRY.read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(
            [row for row in rows if row.startswith("41187,")],
            [
                "41187,xauxag-mks-rv,0,XAUUSD.DWX,411870000,"
                "2026-08-27,Codex governed allocator,active",
                "41187,xauxag-mks-rv,1,XAGUSD.DWX,411870001,"
                "2026-08-27,Codex governed allocator,active",
            ],
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
            self.assertEqual(values["strategy_min_gap_count"], "3")


if __name__ == "__main__":
    unittest.main()
