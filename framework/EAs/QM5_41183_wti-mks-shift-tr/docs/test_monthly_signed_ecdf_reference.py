from __future__ import annotations

import dataclasses
from itertools import combinations
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41183_wti-mks-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41183_wti-mks-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41183_wti-mks-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


@dataclasses.dataclass(frozen=True)
class SignedEcdfSignal:
    direction: int
    d_plus_count: int
    d_minus_count: int
    membership_path: tuple[str, ...]
    delta_path: tuple[int, ...]


def signed_ecdf_signal(
    closes: list[float], min_gap_count: int = 3
) -> SignedEcdfSignal:
    if len(closes) != 12 or min_gap_count != 3:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    ordered = sorted(enumerate(closes), key=lambda item: item[1])
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

    direction = 0
    if d_plus >= min_gap_count and d_plus > d_minus:
        direction = 1
    elif d_minus >= min_gap_count and d_minus > d_plus:
        direction = -1
    return SignedEcdfSignal(
        direction=direction,
        d_plus_count=d_plus,
        d_minus_count=d_minus,
        membership_path=tuple(membership),
        delta_path=tuple(deltas),
    )


def closes_for_old_ranks(old_ranks: tuple[int, ...]) -> list[float]:
    old_set = set(old_ranks)
    if len(old_ranks) != 6 or len(old_set) != 6:
        raise ValueError("requires six distinct old ranks")
    new_ranks = tuple(rank for rank in range(1, 13) if rank not in old_set)
    if len(new_ranks) != 6:
        raise ValueError("requires six complementary new ranks")
    return [float(rank) for rank in old_ranks + new_ranks]


def exact_assignment_density() -> tuple[int, int, int, int]:
    total = buy = sell = flat = 0
    for old_ranks in combinations(range(1, 13), 6):
        signal = signed_ecdf_signal(closes_for_old_ranks(old_ranks))
        total += 1
        if signal.direction > 0:
            buy += 1
        elif signal.direction < 0:
            sell += 1
        else:
            flat += 1
    return total, buy, sell, flat


def mann_whitney_u_new(closes: list[float]) -> int:
    if len(closes) != 12 or len(set(closes)) != 12:
        raise ValueError("requires twelve strict values")
    return sum(new > old for old in closes[:6] for new in closes[6:])


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
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class MonthlySignedEcdfReferenceTests(unittest.TestCase):
    def test_combined_scan_preserves_fixed_membership(self) -> None:
        closes = [1, 2, 3, 5, 11, 12, 4, 6, 7, 8, 9, 10]
        signal = signed_ecdf_signal([float(value) for value in closes])
        self.assertEqual(
            signal.membership_path,
            ("O", "O", "O", "N", "O", "N", "N", "N", "N", "N", "O", "O"),
        )
        self.assertEqual(signal.delta_path, (1, 2, 3, 2, 3, 2, 1, 0, -1, -2, -1, 0))
        self.assertEqual((signal.d_plus_count, signal.d_minus_count), (3, 2))
        self.assertEqual(signal.direction, 1)

    def test_inclusive_boundary_reflection_and_tied_max_flat(self) -> None:
        buy = signed_ecdf_signal(
            closes_for_old_ranks((1, 2, 3, 5, 7, 9))
        )
        sell = signed_ecdf_signal(
            closes_for_old_ranks((2, 4, 6, 10, 11, 12))
        )
        tied = signed_ecdf_signal(
            closes_for_old_ranks((1, 2, 3, 10, 11, 12))
        )
        self.assertEqual((buy.d_plus_count, buy.d_minus_count, buy.direction), (3, 0, 1))
        self.assertEqual((sell.d_plus_count, sell.d_minus_count, sell.direction), (0, 3, -1))
        self.assertEqual((tied.d_plus_count, tied.d_minus_count, tied.direction), (3, 3, 0))

    def test_exact_density_and_side_symmetry(self) -> None:
        total, buy, sell, flat = exact_assignment_density()
        self.assertEqual((total, buy, sell, flat), (924, 218, 218, 488))
        self.assertEqual(buy + sell, 436)
        self.assertAlmostEqual((buy + sell) / total, 109 / 231, places=15)
        within_block_orders = math.factorial(6) ** 2
        self.assertEqual(total * within_block_orders, math.factorial(12))

    def test_ties_invalid_values_and_unlocked_threshold_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            signed_ecdf_signal([1.0] * 12)
        with self.assertRaises(ValueError):
            signed_ecdf_signal([float(value) for value in range(1, 12)] + [0.0])
        with self.assertRaises(ValueError):
            signed_ecdf_signal([float(value) for value in range(1, 12)] + [math.inf])
        with self.assertRaises(ValueError):
            signed_ecdf_signal([float(value) for value in range(1, 13)], 2)

    def test_mann_whitney_separating_fixtures(self) -> None:
        ks_buy = [1, 2, 3, 5, 11, 12, 4, 6, 7, 8, 9, 10]
        ks_flat = [1, 2, 4, 6, 8, 10, 3, 5, 7, 9, 11, 12]
        buy_signal = signed_ecdf_signal([float(value) for value in ks_buy])
        flat_signal = signed_ecdf_signal([float(value) for value in ks_flat])
        self.assertEqual((buy_signal.direction, mann_whitney_u_new(ks_buy)), (1, 23))
        self.assertEqual((flat_signal.direction, mann_whitney_u_new(ks_flat)), (0, 26))

    def test_within_block_order_is_irrelevant(self) -> None:
        left = [1, 2, 3, 5, 11, 12, 4, 6, 7, 8, 9, 10]
        right = [12, 3, 11, 1, 5, 2, 9, 4, 10, 7, 6, 8]
        self.assertEqual(signed_ecdf_signal(left), signed_ecdf_signal(right))

    def test_twelve_consecutive_completed_months(self) -> None:
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

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41183")
        self.assertEqual(headers["ea_slug"], "wti-mks-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        expected = {
            "qm_ea_id": "41183",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "qm_news_temporal": "0",
            "qm_news_compliance": "0",
            "qm_news_mode_legacy": "0",
            "qm_friday_close_enabled": "false",
            "strategy_endpoint_count": "12",
            "strategy_block_size": "6",
            "strategy_min_gap_count": "3",
            "strategy_history_bars_d1": "900",
            "strategy_entry_window_minutes": "180",
            "strategy_max_endpoint_gap_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
            "strategy_deviation_points": "20",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_card_copy_and_magic(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_SignedEcdfSignal", source)
        self.assertIn("metrics.old_seen - metrics.new_seen", source)
        self.assertIn("metrics.d_plus_count = MathMax", source)
        self.assertIn("metrics.d_minus_count = MathMax", source)
        self.assertIn("metrics.d_plus_count > metrics.d_minus_count", source)
        self.assertIn("metrics.d_minus_count > metrics.d_plus_count", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41183", source)
        self.assertNotIn("Strategy_MannWhitneySignal", source)
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        rows = MAGIC_REGISTRY.read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(
            [row for row in rows if row.startswith("41183,")],
            [
                "41183,wti-mks-shift-tr,0,XTIUSD.DWX,411830000,"
                "2026-08-27,Codex governed allocator,active"
            ],
        )

    def test_only_backtest_setfile_exists(self) -> None:
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
