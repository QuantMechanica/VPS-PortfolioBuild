from __future__ import annotations

from dataclasses import dataclass
import hashlib
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41270_wti-mlepage-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41270_wti-mlepage-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41270_wti-mlepage-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
SOURCE_PACKET = (
    REPO_ROOT
    / "strategy-seeds"
    / "sources"
    / "AI-CODEX-WTI-MLEPAGE-SHIFT-20260901"
    / "source.md"
)
G0_DECISION = (
    REPO_ROOT
    / "decisions"
    / "2026-09-01_qm5_41270_wti_monthly_lepage_shift_trend_g0.md"
)
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
MAGIC_RESOLVER = (
    REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
)

CLOSE_COUNT = 51
RETURN_COUNT = 50
BLOCK_SIZE = 25
W_MEAN = 637.5
W_VARIANCE = 2656.25
A_MEAN = 325.0
A_VARIANCE = 32500.0 / 49.0
STATISTIC_GATE = 1.3862943611198906
DIRECTION_EPSILON = 1e-12

JOINT_RECENT_RANKS = [
    1,
    2,
    4,
    5,
    7,
    8,
    9,
    10,
    12,
    13,
    16,
    23,
    25,
    28,
    29,
    30,
    34,
    37,
    38,
    39,
    40,
    41,
    43,
    45,
    48,
]
FLAT_RECENT_RANKS = [
    1,
    2,
    6,
    7,
    8,
    9,
    10,
    19,
    20,
    22,
    23,
    25,
    26,
    27,
    28,
    29,
    33,
    36,
    37,
    39,
    43,
    45,
    46,
    49,
    50,
]
TAIL_RECENT_RANKS = list(range(1, 13)) + [25] + list(range(39, 51))


@dataclass(frozen=True)
class Signal:
    direction: int
    qualifies: bool
    wilcoxon_rank_sum: float
    ansari_bradley_score: float
    location_component: float
    scale_component: float
    statistic_l: float
    recent_return: float


def returns_for_recent_ranks(recent_ranks: list[int]) -> list[float]:
    if len(recent_ranks) != BLOCK_SIZE or len(set(recent_ranks)) != BLOCK_SIZE:
        raise ValueError("twenty-five distinct recent ranks required")
    if any(rank < 1 or rank > RETURN_COUNT for rank in recent_ranks):
        raise ValueError("rank outside locked pool")
    recent_set = set(recent_ranks)
    old_ranks = [rank for rank in range(1, RETURN_COUNT + 1) if rank not in recent_set]
    values = {rank: (rank - 25.5) / 1000.0 for rank in range(1, 51)}
    return [values[rank] for rank in old_ranks] + [
        values[rank] for rank in recent_ranks
    ]


def closes_from_returns(returns: list[float], start: float = 70.0) -> list[float]:
    closes = [start]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def lepage_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("locked finite fifty-return sample required")
    ordered = sorted(enumerate(returns), key=lambda item: item[1])
    if any(ordered[index - 1][1] >= ordered[index][1] for index in range(1, 50)):
        raise ValueError("pairwise-distinct returns required")

    recent_indices = set(range(BLOCK_SIZE, RETURN_COUNT))
    recent_ranks = [
        rank
        for rank, (source_index, _value) in enumerate(ordered, start=1)
        if source_index in recent_indices
    ]
    wilcoxon_rank_sum = float(sum(recent_ranks))
    ansari_bradley_score = float(
        sum(min(rank, RETURN_COUNT + 1 - rank) for rank in recent_ranks)
    )
    location_component = (
        (wilcoxon_rank_sum - W_MEAN) ** 2 / W_VARIANCE
    )
    scale_component = (
        (ansari_bradley_score - A_MEAN) ** 2 / A_VARIANCE
    )
    statistic_l = location_component + scale_component
    recent_return = sum(returns[BLOCK_SIZE:])
    qualifies = statistic_l >= STATISTIC_GATE
    direction = 0
    if qualifies and recent_return > DIRECTION_EPSILON:
        direction = 1
    elif qualifies and recent_return < -DIRECTION_EPSILON:
        direction = -1
    return Signal(
        direction,
        qualifies,
        wilcoxon_rank_sum,
        ansari_bradley_score,
        location_component,
        scale_component,
        statistic_l,
        recent_return,
    )


def input_literal(source: str, name: str) -> str:
    match = re.search(
        rf"^input\s+(?:int|uint|double|bool|string)\s+{re.escape(name)}\s*=\s*([^;]+);",
        source,
        flags=re.MULTILINE,
    )
    if match is None:
        raise AssertionError(f"missing input {name}")
    return match.group(1).strip()


def set_values(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        values[name.strip()] = value.strip()
    return values


class LepageArithmeticTests(unittest.TestCase):
    def test_locked_null_moments(self) -> None:
        self.assertEqual(W_MEAN, BLOCK_SIZE * (RETURN_COUNT + 1) / 2.0)
        self.assertEqual(
            W_VARIANCE,
            BLOCK_SIZE * BLOCK_SIZE * (RETURN_COUNT + 1) / 12.0,
        )
        scores = [min(rank, 51 - rank) for rank in range(1, 51)]
        self.assertEqual(sum(scores), 650)
        self.assertEqual(A_MEAN, BLOCK_SIZE * sum(scores) / RETURN_COUNT)
        population_ss = sum((score - 13.0) ** 2 for score in scores)
        random_subset_variance = (
            BLOCK_SIZE
            * BLOCK_SIZE
            * population_ss
            / (RETURN_COUNT * (RETURN_COUNT - 1))
        )
        self.assertAlmostEqual(A_VARIANCE, random_subset_variance, places=13)

    def test_joint_fixture_requires_both_components(self) -> None:
        signal = lepage_signal(returns_for_recent_ranks(JOINT_RECENT_RANKS))
        self.assertEqual(signal.wilcoxon_rank_sum, 587.0)
        self.assertEqual(signal.ansari_bradley_score, 295.0)
        self.assertAlmostEqual(
            signal.location_component, 0.9600941176470589, places=14
        )
        self.assertAlmostEqual(
            signal.scale_component, 1.356923076923077, places=14
        )
        self.assertAlmostEqual(signal.statistic_l, 2.317017194570136, places=14)
        self.assertLess(signal.location_component, STATISTIC_GATE)
        self.assertLess(signal.scale_component, STATISTIC_GATE)
        self.assertTrue(signal.qualifies)
        self.assertEqual(signal.direction, -1)

    def test_sign_reversal_preserves_joint_state_and_flips_side(self) -> None:
        original = returns_for_recent_ranks(JOINT_RECENT_RANKS)
        sell = lepage_signal(original)
        buy = lepage_signal([-value for value in original])
        self.assertAlmostEqual(buy.statistic_l, sell.statistic_l, places=14)
        self.assertAlmostEqual(buy.recent_return, -sell.recent_return, places=14)
        self.assertEqual((sell.direction, buy.direction), (-1, 1))

    def test_flat_fixture_stays_below_gate(self) -> None:
        signal = lepage_signal(returns_for_recent_ranks(FLAT_RECENT_RANKS))
        self.assertEqual(signal.wilcoxon_rank_sum, 640.0)
        self.assertEqual(signal.ansari_bradley_score, 327.0)
        self.assertAlmostEqual(signal.statistic_l, 0.008383710407239817, places=15)
        self.assertFalse(signal.qualifies)
        self.assertEqual(signal.direction, 0)

    def test_location_and_scale_extremes_both_qualify(self) -> None:
        location = lepage_signal(returns_for_recent_ranks(list(range(26, 51))))
        scale = lepage_signal(returns_for_recent_ranks(TAIL_RECENT_RANKS))
        self.assertEqual(location.wilcoxon_rank_sum, 950.0)
        self.assertEqual(location.ansari_bradley_score, 325.0)
        self.assertTrue(location.qualifies)
        self.assertEqual(scale.wilcoxon_rank_sum, 637.0)
        self.assertEqual(scale.ansari_bradley_score, 181.0)
        self.assertAlmostEqual(scale.statistic_l, 31.26360180995475, places=13)
        self.assertTrue(scale.qualifies)

    def test_exact_tie_fails_closed(self) -> None:
        returns = returns_for_recent_ranks(JOINT_RECENT_RANKS)
        returns[-1] = returns[0]
        with self.assertRaisesRegex(ValueError, "pairwise-distinct"):
            lepage_signal(returns)

    def test_close_round_trip_preserves_direction(self) -> None:
        expected = lepage_signal(returns_for_recent_ranks(JOINT_RECENT_RANKS))
        closes = closes_from_returns(
            returns_for_recent_ranks(JOINT_RECENT_RANKS)
        )
        recovered = [
            math.log(closes[index + 1] / closes[index])
            for index in range(RETURN_COUNT)
        ]
        actual = lepage_signal(recovered)
        self.assertEqual(len(closes), CLOSE_COUNT)
        self.assertEqual(actual.direction, expected.direction)
        self.assertAlmostEqual(actual.statistic_l, expected.statistic_l, places=12)


class BuildContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = EA_SOURCE.read_text(encoding="utf-8")
        cls.set_text = SETFILE.read_text(encoding="utf-8")
        cls.sets = set_values(cls.set_text)

    def test_identity_and_magic_are_exact(self) -> None:
        self.assertEqual(input_literal(self.source, "qm_ea_id"), "41270")
        self.assertIn('const string g_symbol = "XTIUSD.DWX";', self.source)
        self.assertIn("QM_FrameworkMagic() != 412700000", self.source)
        registry_rows = [
            line
            for line in MAGIC_REGISTRY.read_text(encoding="utf-8").splitlines()
            if line.startswith("41270,")
        ]
        self.assertEqual(
            registry_rows,
            [
                "41270,wti-mlepage-shift-tr,0,XTIUSD.DWX,412700000,"
                "2026-09-01,Codex governed allocator,active"
            ],
        )
        resolver = MAGIC_RESOLVER.read_text(encoding="utf-8")
        registry_hash = hashlib.sha256(MAGIC_REGISTRY.read_bytes()).hexdigest().upper()
        self.assertIn(
            f'#define QM_MAGIC_REGISTRY_SHA256 "{registry_hash}"', resolver
        )
        self.assertIn(", 41270}", resolver)
        self.assertIn(", 412700000}", resolver)

    def test_ea_and_setfile_lock_the_formula(self) -> None:
        expected = {
            "strategy_close_count": "51",
            "strategy_return_count": "50",
            "strategy_block_size": "25",
            "strategy_w_mean": "637.5",
            "strategy_w_variance": "2656.25",
            "strategy_a_mean": "325.0",
            "strategy_a_variance": "663.26530612244898",
            "strategy_statistic_gate": "1.3862943611198906",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "80",
            "strategy_entry_grace_minutes": "180",
            "strategy_max_completed_bar_age_days": "4",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
            "strategy_deviation_points": "20",
        }
        for name, literal in expected.items():
            self.assertEqual(input_literal(self.source, name), literal, name)
            self.assertEqual(self.sets[name], literal, name)
        for token in (
            "metrics.wilcoxon_rank_sum += (double)rank;",
            "metrics.ansari_bradley_score += (double)symmetric_score;",
            "location_delta * location_delta / strategy_w_variance",
            "scale_delta * scale_delta / strategy_a_variance",
            "metrics.statistic_l >= strategy_statistic_gate",
            "sorted_returns[index - 1] >= sorted_returns[index]",
        ):
            self.assertIn(token, self.source)

    def test_fixed_risk_backtest_only(self) -> None:
        self.assertEqual(self.sets["qm_ea_id"], "41270")
        self.assertEqual(self.sets["qm_magic_slot_offset"], "0")
        self.assertEqual(self.sets["RISK_FIXED"], "1000")
        self.assertEqual(self.sets["RISK_PERCENT"], "0")
        self.assertEqual(self.sets["PORTFOLIO_WEIGHT"], "1")
        self.assertIn("; environment:  backtest", self.set_text)
        self.assertIn("; risk_mode:    FIXED", self.set_text)
        setfiles = sorted(path.name for path in (EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE.name])
        self.assertNotRegex(self.set_text.lower(), r"live|autotrading")

    def test_consumption_precedes_fallible_gates(self) -> None:
        prepare = self.source.index("void Strategy_PrepareDecisionSignal()")
        consume = self.source.index("Strategy_RecordMonthAttempt", prepare)
        history = self.source.index("Strategy_LoadPreMonthCloses", consume)
        entry = self.source.index("bool Strategy_EntrySignal", history)
        spread = self.source.index("Strategy_SpreadAllowed", entry)
        atr = self.source.index("QM_ATR", spread)
        self.assertLess(consume, history)
        self.assertLess(history, spread)
        self.assertLess(spread, atr)

    def test_position_management_precedes_entry_only_news(self) -> None:
        tick = self.source.index("void OnTick()")
        manage = self.source.index("Strategy_ManageOpenPosition();", tick)
        news = self.source.index("Strategy_NewsFilterHook", manage)
        entry = self.source.index("Strategy_EntrySignal(req)", news)
        self.assertLess(manage, news)
        self.assertLess(news, entry)

    def test_framework_hooks_and_structural_only_surface(self) -> None:
        for token in (
            "QM_FrameworkInit",
            "QM_FrameworkDeclareExecutionContract",
            "QM_KillSwitchCheck",
            "QM_IsNewBar",
            "QM_TM_OpenPosition",
            "QM_FrameworkOnTimer",
            "QM_FrameworkOnTradeTransaction",
            "QM_DefaultObjective",
        ):
            self.assertIn(token, self.source)
        for forbidden in (
            "iMA(",
            "iRSI(",
            "iMACD(",
            "iBands(",
            "machine learning",
            "neural",
            "Epps-Singleton",
            "Strategy_Invert4x4",
        ):
            self.assertNotIn(forbidden, self.source)

    def test_card_source_and_g0_are_durable(self) -> None:
        self.assertEqual(CANONICAL_CARD.read_bytes(), EA_CARD.read_bytes())
        card = CANONICAL_CARD.read_text(encoding="utf-8")
        source = SOURCE_PACKET.read_text(encoding="utf-8")
        decision = G0_DECISION.read_text(encoding="utf-8")
        self.assertIn("g0_status: APPROVED", card)
        self.assertIn("q02_status: NOT_ENQUEUED_Q01_PENDING", card)
        self.assertIn("Lepage", source)
        self.assertIn("APPROVED", decision)


if __name__ == "__main__":
    unittest.main()
