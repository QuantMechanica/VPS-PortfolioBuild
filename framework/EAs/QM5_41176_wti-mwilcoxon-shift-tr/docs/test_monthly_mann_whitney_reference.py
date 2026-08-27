from __future__ import annotations

import dataclasses
import itertools
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41176_wti-mwilcoxon-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41176_wti-mwilcoxon-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41176_wti-mwilcoxon-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclasses.dataclass(frozen=True)
class MannWhitneySignal:
    direction: int
    u_new: int
    u_old: int
    newer_rank_sum: int


def mann_whitney_signal(
    closes: list[float],
    block_size: int = 6,
    lower: int = 12,
    upper: int = 24,
) -> MannWhitneySignal:
    if len(closes) != 12 or block_size != 6 or lower != 12 or upper != 24:
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    older = closes[:block_size]
    newer = closes[block_size:]
    u_new = sum(new > old for new in newer for old in older)
    u_old = sum(old > new for new in newer for old in older)
    newer_rank_sum = sum(
        1 + sum(other < value for other in closes) for value in newer
    )
    if (
        not 0 <= u_new <= 36
        or not 0 <= u_old <= 36
        or u_new + u_old != 36
        or newer_rank_sum - 21 != u_new
    ):
        raise AssertionError("Mann-Whitney identity broken")

    direction = 1 if u_new >= upper else -1 if u_new <= lower else 0
    return MannWhitneySignal(direction, u_new, u_old, newer_rank_sum)


def closes_for_newer_ranks(newer_ranks: tuple[int, ...]) -> list[float]:
    newer = set(newer_ranks)
    older_ranks = [rank for rank in range(1, 13) if rank not in newer]
    return [float(rank) for rank in older_ranks + list(newer_ranks)]


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


class MonthlyMannWhitneyReferenceTests(unittest.TestCase):
    def test_extremes_and_identity_are_symmetric(self) -> None:
        upward = mann_whitney_signal([float(value) for value in range(1, 13)])
        downward = mann_whitney_signal(
            [float(value) for value in range(12, 0, -1)]
        )
        self.assertEqual(upward, MannWhitneySignal(1, 36, 0, 57))
        self.assertEqual(downward, MannWhitneySignal(-1, 0, 36, 21))

    def test_inclusive_boundaries_and_central_region(self) -> None:
        by_u: dict[int, tuple[int, ...]] = {}
        for newer in itertools.combinations(range(1, 13), 6):
            by_u.setdefault(sum(newer) - 21, newer)
        self.assertEqual(
            mann_whitney_signal(closes_for_newer_ranks(by_u[12])).direction,
            -1,
        )
        self.assertEqual(
            mann_whitney_signal(closes_for_newer_ranks(by_u[13])).direction,
            0,
        )
        self.assertEqual(
            mann_whitney_signal(closes_for_newer_ranks(by_u[23])).direction,
            0,
        )
        self.assertEqual(
            mann_whitney_signal(closes_for_newer_ranks(by_u[24])).direction,
            1,
        )

    def test_exact_density_lock_covers_all_rank_assignments(self) -> None:
        distribution = [
            sum(newer) - 21
            for newer in itertools.combinations(range(1, 13), 6)
        ]
        short = sum(value <= 12 for value in distribution)
        long = sum(value >= 24 for value in distribution)
        self.assertEqual((len(distribution), short, long), (924, 182, 182))
        self.assertEqual(short + long, 364)
        self.assertAlmostEqual((short + long) / 924, 0.3939393939393939)

    def test_ties_invalid_values_and_unlocked_inputs_fail(self) -> None:
        with self.assertRaises(ValueError):
            mann_whitney_signal([1.0] * 12)
        with self.assertRaises(ValueError):
            mann_whitney_signal([float(value) for value in range(1, 12)] + [0.0])
        with self.assertRaises(ValueError):
            mann_whitney_signal(
                [float(value) for value in range(1, 12)] + [math.inf]
            )
        with self.assertRaises(ValueError):
            mann_whitney_signal([float(value) for value in range(1, 13)], upper=25)

    def test_locked_nonduplicate_fixtures(self) -> None:
        first = [13, 2, 4, 6, 1, 3, 10, 5, 7, 8, 9, 12]
        second = [8, 3, 5, 7, 11, 9, 4, 2, 12, 13, 6, 10]
        third = [10, 9, 8, 3, 2, 1, 13, 4, 5, 6, 12, 7]
        self.assertEqual(
            (mann_whitney_signal(first).direction, mann_whitney_signal(first).u_new),
            (1, 29),
        )
        self.assertEqual(
            (mann_whitney_signal(second).direction, mann_whitney_signal(second).u_new),
            (0, 20),
        )
        self.assertEqual(
            (mann_whitney_signal(third).direction, mann_whitney_signal(third).u_new),
            (1, 24),
        )

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
        broken[6] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41176")
        self.assertEqual(headers["ea_slug"], "wti-mwilcoxon-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        expected = {
            "qm_ea_id": "41176",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "12",
            "strategy_block_size": "6",
            "strategy_u_lower": "12",
            "strategy_u_upper": "24",
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

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_MannWhitneySignal", source)
        self.assertIn("++metrics.u_new", source)
        self.assertIn("++metrics.u_old", source)
        self.assertIn("metrics.u_new + metrics.u_old != pair_count", source)
        self.assertIn(
            "metrics.newer_rank_sum - minimum_rank_sum != metrics.u_new",
            source,
        )
        self.assertIn("metrics.u_new >= strategy_u_upper", source)
        self.assertIn("metrics.u_new <= strategy_u_lower", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41176", source)
        self.assertNotIn("Strategy_SpearmanSignal", source)
        self.assertNotIn("Strategy_PettittSignal", source)
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
