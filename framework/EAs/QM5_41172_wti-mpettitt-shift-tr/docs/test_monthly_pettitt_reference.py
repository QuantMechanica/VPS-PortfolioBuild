from __future__ import annotations

import dataclasses
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41172_wti-mpettitt-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41172_wti-mpettitt-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41172_wti-mpettitt-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"


@dataclasses.dataclass(frozen=True)
class PettittSignal:
    direction: int
    ranks: tuple[int, ...]
    rank_sum: int
    u_path: tuple[int, ...]
    u_star: int
    change_index: int
    signed_u: int
    maxima_count: int


def pettitt_signal(
    closes: list[float], min_change_index: int = 4, max_change_index: int = 9
) -> PettittSignal:
    if (
        len(closes) != 13
        or min_change_index != 4
        or max_change_index != 9
    ):
        raise ValueError("locked baseline mismatch")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    if len(set(closes)) != len(closes):
        raise ValueError("ties fail closed")

    ordered = sorted(closes)
    ranks = tuple(ordered.index(value) + 1 for value in closes)
    if sorted(ranks) != list(range(1, 14)) or sum(ranks) != 91:
        raise AssertionError("rank permutation broken")

    cumulative = 0
    path: list[int] = []
    for change_index, rank in enumerate(ranks[:-1], start=1):
        cumulative += rank
        signed_u = 2 * cumulative - 14 * change_index
        if signed_u % 2 != 0 or abs(signed_u) > 42:
            raise AssertionError("Pettitt path invariant broken")
        path.append(signed_u)

    u_path = tuple(path)
    u_star = max(abs(value) for value in u_path)
    maxima = tuple(
        index
        for index, value in enumerate(u_path, start=1)
        if abs(value) == u_star
    )
    if not 1 <= u_star <= 42:
        raise AssertionError("Pettitt maximum invariant broken")

    change_index = maxima[0]
    signed_u = u_path[change_index - 1]
    direction = 0
    if (
        len(maxima) == 1
        and min_change_index <= change_index <= max_change_index
    ):
        direction = 1 if signed_u < 0 else -1

    return PettittSignal(
        direction=direction,
        ranks=ranks,
        rank_sum=sum(ranks),
        u_path=u_path,
        u_star=u_star,
        change_index=change_index,
        signed_u=signed_u,
        maxima_count=len(maxima),
    )


def bartels_numerator(ranks: tuple[int, ...]) -> int:
    return sum((right - left) ** 2 for left, right in zip(ranks, ranks[1:]))


def turning_point_count(ranks: tuple[int, ...]) -> int:
    return sum(
        (left < middle > right) or (left > middle < right)
        for left, middle, right in zip(ranks, ranks[1:], ranks[2:])
    )


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 13 or next_month_key(endpoints[-1]) != current_month:
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


class MonthlyPettittReferenceTests(unittest.TestCase):
    def test_unique_central_shift_qualifies_symmetrically(self) -> None:
        upward_ranks = (1, 8, 5, 7, 2, 10, 11, 6, 12, 3, 9, 4, 13)
        upward = pettitt_signal([float(value) for value in upward_ranks])
        downward = pettitt_signal([float(14 - value) for value in upward_ranks])
        self.assertEqual(
            upward.u_path,
            (-12, -10, -14, -14, -24, -18, -10, -12, -2, -10, -6, -12),
        )
        self.assertEqual(
            (upward.direction, upward.u_star, upward.change_index, upward.signed_u),
            (1, 24, 5, -24),
        )
        self.assertEqual(
            (downward.direction, downward.u_star, downward.change_index, downward.signed_u),
            (-1, 24, 5, 24),
        )

    def test_edge_and_tied_maxima_consume_flat(self) -> None:
        edge_ranks = (1, 2, 13, 6, 5, 7, 8, 12, 10, 3, 4, 11, 9)
        edge = pettitt_signal([float(value) for value in edge_ranks])
        self.assertEqual(
            (edge.direction, edge.u_star, edge.change_index, edge.signed_u),
            (0, 22, 2, -22),
        )

        tied_ranks = (1, 2, 3, 4, 7, 8, 6, 9, 5, 10, 11, 12, 13)
        tied = pettitt_signal([float(value) for value in tied_ranks])
        self.assertEqual((tied.direction, tied.u_star, tied.maxima_count), (0, 36, 4))

    def test_ties_and_invalid_values_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            pettitt_signal([1.0] * 13)
        with self.assertRaises(ValueError):
            pettitt_signal([float(value) for value in range(1, 13)] + [0.0])
        with self.assertRaises(ValueError):
            pettitt_signal([float(value) for value in range(1, 13)] + [math.inf])
        with self.assertRaises(ValueError):
            pettitt_signal([float(value) for value in range(1, 14)], 3, 9)

    def test_locked_nonduplicate_fixtures(self) -> None:
        pettitt_buy_ranks = (1, 8, 5, 7, 2, 10, 11, 6, 12, 3, 9, 4, 13)
        pettitt_buy = pettitt_signal([float(value) for value in pettitt_buy_ranks])
        self.assertEqual(pettitt_buy.direction, 1)
        self.assertEqual(bartels_numerator(pettitt_buy.ranks), 436)
        self.assertEqual(turning_point_count(pettitt_buy.ranks), 10)

        pettitt_flat_ranks = (1, 2, 13, 6, 5, 7, 8, 12, 10, 3, 4, 11, 9)
        pettitt_flat = pettitt_signal([float(value) for value in pettitt_flat_ranks])
        self.assertEqual(pettitt_flat.direction, 0)
        self.assertEqual(bartels_numerator(pettitt_flat.ranks), 300)
        self.assertEqual(turning_point_count(pettitt_flat.ranks), 5)

    def test_thirteen_consecutive_completed_months(self) -> None:
        endpoints = [
            202507,
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
        broken[7] = 202603
        self.assertFalse(validate_month_keys(202608, broken))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41172")
        self.assertEqual(headers["ea_slug"], "wti-mpettitt-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41172",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_endpoint_count": "13",
            "strategy_min_change_index": "4",
            "strategy_max_change_index": "9",
            "strategy_history_bars_d1": "900",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_contract_and_card_copy(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("bool Strategy_PettittSignal", source)
        self.assertIn("2 * cumulative_rank_sum", source)
        self.assertIn("metrics.maxima_count == 1", source)
        self.assertIn("metrics.change_index >= strategy_min_change_index", source)
        self.assertIn("Strategy_RecordMonthAttempt(g_decision_month_key)", source)
        self.assertIn("RISK_FIXED != 1000.0", source)
        self.assertIn("qm_ea_id != 41172", source)
        self.assertNotIn("strategy_nm_boundary", source)
        self.assertNotIn("Strategy_BartelsRankSignal", source)
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

