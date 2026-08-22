"""Independent deterministic fixtures for QM5_41121's sequence basket."""

from __future__ import annotations

import json
import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
HISTORY_BARS = 45


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class SequenceResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    return_count: int = 0
    transition_count: int = 0
    sequences: int = 0
    reversals: int = 0
    net_displacement: float = 0.0


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def previous_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year - 1) * 100 + 12 if month == 1 else year * 100 + month - 1


def within_entry_grace(now: datetime, current_bar: datetime, minutes: int = 180) -> bool:
    elapsed = now - current_bar
    return timedelta(0) <= elapsed <= timedelta(minutes=minutes)


def decision_clock(
    now: datetime,
    xau_current: datetime,
    xag_current: datetime,
    newest_completed: datetime,
) -> tuple[bool, bool, int]:
    key = month_key(now)
    exact_current = (
        xau_current == xag_current
        and xau_current.date() == now.date()
        and month_key(xau_current) == key
    )
    if not exact_current:
        return False, False, key
    late = not within_entry_grace(now, xau_current) or month_key(newest_completed) == key
    return True, late, key


def ratios_from_returns(returns: list[float], start: float = 0.0) -> list[float]:
    ratios = [start]
    for value in returns:
        ratios.append(ratios[-1] + value)
    return ratios


def signs_from_transitions(transitions: list[bool]) -> list[int]:
    """True keeps the prior sign (sequence); False flips it (reversal)."""

    signs = [1]
    for same in transitions:
        signs.append(signs[-1] if same else -signs[-1])
    return signs


def make_month(key: int, ratios: list[float]) -> tuple[list[CloseBar], list[CloseBar]]:
    year, month = divmod(key, 100)
    xau: list[CloseBar] = []
    xag: list[CloseBar] = []
    for day, ratio in enumerate(ratios, start=1):
        opened = datetime(year, month, day, tzinfo=UTC)
        xau.append(CloseBar(opened, math.exp(ratio)))
        xag.append(CloseBar(opened, 1.0))
    return list(reversed(xau)), list(reversed(xag))


def sample(
    completed_ratios: list[float],
    *,
    completed_key: int = 202607,
    older_key: int | None = None,
) -> tuple[list[CloseBar], list[CloseBar]]:
    """Build an exact 45-bar newest-first pair plus adjacent older boundary."""

    if older_key is None:
        older_key = previous_month_key(completed_key)
    xau, xag = make_month(completed_key, completed_ratios)
    padding_key = older_key
    while len(xau) < HISTORY_BARS:
        count = min(23, HISTORY_BARS - len(xau))
        padding_ratios = [-1.0 - index * 0.001 for index in range(count)]
        padding_xau, padding_xag = make_month(padding_key, padding_ratios)
        xau.extend(padding_xau)
        xag.extend(padding_xag)
        padding_key = previous_month_key(padding_key)
    if len(xau) != HISTORY_BARS:
        raise ValueError("fixture exceeds the fixed history buffer")
    return xau, xag


def synchronized_pair_valid(
    xau_bars: list[CloseBar], xag_bars: list[CloseBar], index: int
) -> bool:
    if not 0 <= index < len(xau_bars) or index >= len(xag_bars):
        return False
    xau, xag = xau_bars[index], xag_bars[index]
    if (
        xau.opened != xag.opened
        or not all(math.isfinite(value) and value > 0.0 for value in (xau.close, xag.close))
    ):
        return False
    if index > 0 and (
        xau_bars[index - 1].opened <= xau.opened
        or xag_bars[index - 1].opened <= xag.opened
    ):
        return False
    return True


def monthly_sequence_dominance(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
    minimum: int = 17,
    maximum: int = 23,
    history_bars: int = HISTORY_BARS,
) -> SequenceResult:
    """Mirror month reconstruction, chronological transitions, and inverse side."""

    if (
        current_month <= 0
        or history_bars != HISTORY_BARS
        or minimum != 17
        or maximum != 23
        or minimum > maximum
        or history_bars < maximum + 1
        or len(xau_bars) != history_bars
        or len(xag_bars) != history_bars
        or not synchronized_pair_valid(xau_bars, xag_bars, 0)
    ):
        return SequenceResult()

    completed_key = month_key(xau_bars[0].opened)
    if (
        month_key(xag_bars[0].opened) != completed_key
        or next_month_key(completed_key) != current_month
    ):
        return SequenceResult()

    series_ratios: list[float] = []
    index = 0
    while index < history_bars and month_key(xau_bars[index].opened) == completed_key:
        if (
            len(series_ratios) >= maximum
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != completed_key
        ):
            return SequenceResult()
        ratio = math.log(xau_bars[index].close) - math.log(xag_bars[index].close)
        if not math.isfinite(ratio):
            return SequenceResult()
        series_ratios.append(ratio)
        index += 1

    if not minimum <= len(series_ratios) <= maximum or index >= history_bars:
        return SequenceResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return SequenceResult()
    older_key = month_key(xau_bars[index].opened)
    if (
        month_key(xag_bars[index].opened) != older_key
        or next_month_key(older_key) != completed_key
    ):
        return SequenceResult()

    chronological = list(reversed(series_ratios))
    returns = [chronological[i] - chronological[i - 1] for i in range(1, len(chronological))]
    if any(not math.isfinite(value) or value == 0.0 for value in returns):
        return SequenceResult()

    signs = [1 if value > 0.0 else -1 for value in returns]
    sequences = sum(signs[i] == signs[i - 1] for i in range(1, len(signs)))
    reversals = sum(signs[i] != signs[i - 1] for i in range(1, len(signs)))
    transitions = len(signs) - 1
    if transitions != len(chronological) - 2 or sequences + reversals != transitions:
        return SequenceResult()

    net = chronological[-1] - chronological[0]
    if not math.isfinite(net):
        return SequenceResult()
    direction = 0
    if sequences >= reversals:
        direction = 1 if net < 0.0 else -1 if net > 0.0 else 0
    return SequenceResult(
        True,
        direction,
        len(chronological),
        len(returns),
        transitions,
        sequences,
        reversals,
        net,
    )


def round_down(value: float, step: float, minimum: float) -> float:
    rounded = math.floor((value + 1e-12) / step) * step
    return rounded if rounded + 1e-12 >= minimum else 0.0


def equal_notional_package(
    full_xau_lots: float,
    full_xag_lots: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
) -> tuple[float, float, float, float]:
    lot_ratio = xag_notional_per_lot / xau_notional_per_lot
    normalized_per_xag_lot = lot_ratio / full_xau_lots + 1.0 / full_xag_lots
    xag_lots = round_down(1.0 / normalized_per_xag_lot, 0.01, 0.01)
    xau_lots = round_down(lot_ratio / normalized_per_xag_lot, 0.01, 0.01)
    risk = xau_lots / full_xau_lots + xag_lots / full_xag_lots
    notional_ratio = xau_lots * xau_notional_per_lot / (xag_lots * xag_notional_per_lot)
    return xau_lots, xag_lots, risk, notional_ratio


class AttemptLedger:
    def __init__(self) -> None:
        self.month = 0

    def consume(self, month: int) -> bool:
        if month <= 0 or month == self.month:
            return False
        self.month = month
        return True


class MonthlySequenceDominanceReferenceTest(unittest.TestCase):
    def signal(self, returns: list[float], **kwargs: int) -> SequenceResult:
        xau, xag = sample(ratios_from_returns(returns), **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_sequence_dominance(next_month_key(completed_key), xau, xag)

    def test_every_allowed_session_count_has_exhaustive_arithmetic(self) -> None:
        for count in range(17, 24):
            result = self.signal([1.0] * (count - 1))
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, count)
            self.assertEqual(result.return_count, count - 1)
            self.assertEqual(result.transition_count, count - 2)
            self.assertEqual(result.sequences + result.reversals, count - 2)

    def test_all_positive_and_negative_paths_fade_net_direction(self) -> None:
        positive = self.signal([1.0] * 19)
        self.assertEqual((positive.sequences, positive.reversals), (18, 0))
        self.assertEqual(positive.direction, -1)
        negative = self.signal([-1.0] * 19)
        self.assertEqual((negative.sequences, negative.reversals), (18, 0))
        self.assertEqual(negative.direction, 1)

    def test_inclusive_tie_qualifies_and_reversal_majority_stays_flat(self) -> None:
        tie_signs = signs_from_transitions([True, False] * 8)
        tie_returns = [2.0 if sign > 0 else -1.0 for sign in tie_signs]
        tied = self.signal(tie_returns)
        self.assertTrue(tied.valid)
        self.assertEqual((tied.sequences, tied.reversals), (8, 8))
        self.assertGreater(tied.net_displacement, 0.0)
        self.assertEqual(tied.direction, -1)

        alternating = self.signal([1.0, -0.5] * 8)
        self.assertTrue(alternating.valid)
        self.assertLess(alternating.sequences, alternating.reversals)
        self.assertEqual(alternating.direction, 0)

    def test_exact_zero_return_rejects_and_sequence_dominant_net_zero_is_flat(self) -> None:
        with_zero = [1.0] * 8 + [0.0] + [1.0] * 7
        self.assertFalse(self.signal(with_zero).valid)

        net_zero = self.signal([1.0] * 8 + [-1.0] * 8)
        self.assertTrue(net_zero.valid)
        self.assertGreater(net_zero.sequences, net_zero.reversals)
        self.assertEqual(net_zero.net_displacement, 0.0)
        self.assertEqual(net_zero.direction, 0)

    def test_same_sign_multiset_is_chronology_sensitive(self) -> None:
        clustered = self.signal([1.0] * 10 + [-1.0] * 6)
        permuted = self.signal([1.0, -1.0] * 6 + [1.0] * 4)
        self.assertEqual(clustered.net_displacement, permuted.net_displacement)
        self.assertEqual(clustered.direction, -1)
        self.assertEqual(permuted.direction, 0)
        self.assertGreater(clustered.sequences, clustered.reversals)
        self.assertLess(permuted.sequences, permuted.reversals)

    def test_session_bounds_synchronization_and_month_boundaries_are_exact(self) -> None:
        for count in (17, 20, 23):
            self.assertTrue(self.signal([1.0] * (count - 1)).valid)
        for count in (16, 24):
            self.assertFalse(self.signal([1.0] * (count - 1)).valid)

        xau, xag = sample(ratios_from_returns([1.0] * 19))
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_sequence_dominance(202608, xau, xag).valid)

        xau, xag = sample(ratios_from_returns([1.0] * 19))
        xau[2] = CloseBar(xau[1].opened, xau[2].close)
        xag[2] = CloseBar(xag[1].opened, xag[2].close)
        self.assertFalse(monthly_sequence_dominance(202608, xau, xag).valid)

        xau, xag = sample(ratios_from_returns([1.0] * 19), older_key=202605)
        self.assertFalse(monthly_sequence_dominance(202608, xau, xag).valid)
        self.assertFalse(monthly_sequence_dominance(202609, xau, xag).valid)

    def test_clock_attempt_year_boundary_and_joint_risk_are_bounded(self) -> None:
        current = datetime(2026, 8, 3, tzinfo=UTC)
        now = current + timedelta(minutes=180)
        completed = datetime(2026, 7, 31, tzinfo=UTC)
        self.assertEqual(decision_clock(now, current, current, completed), (True, False, 202608))
        self.assertTrue(decision_clock(now + timedelta(minutes=1), current, current, completed)[1])
        self.assertFalse(decision_clock(now, current, current + timedelta(hours=1), completed)[0])
        ledger = AttemptLedger()
        self.assertTrue(ledger.consume(202608))
        self.assertFalse(ledger.consume(202608))
        self.assertEqual(next_month_key(202612), 202701)
        year_boundary = self.signal([1.0] * 19, completed_key=202612)
        self.assertTrue(year_boundary.valid)
        self.assertEqual(year_boundary.direction, -1)

        xau, xag, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41121_xauxag-mseqdom-rv.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41121_xauxag-mseqdom-rv_QM5_41121_XAU_XAG_MSEQDOM_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41121;",
            "input bool   strategy_sequence_inclusive       = true;",
            "CopyRates(g_leg_xau",
            "PERIOD_D1, 1, strategy_history_bars_d1",
            "chronological_ratios[i] = ratio;",
            "relative_return == 0.0",
            "if(current_sign == prior_sign)",
            "sequences + reversals != transition_count",
            "if(sequences >= reversals)",
            "if(net_displacement < 0.0)",
            "else if(net_displacement > 0.0)",
            "QM_ATR(g_leg_xau, PERIOD_D1, strategy_atr_period_d1, 1)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
            "request.tp = 0.0;",
            "strategy_notional_ratio",
        ):
            self.assertIn(marker, source)
        for banned in ("iRSI(", "iMACD(", "iBands(", "WebRequest("):
            self.assertNotIn(banned, source)
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntrySignal(request)"),
        )
        for marker in (
            "qm_ea_id=41121",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_sequence_inclusive=true",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertEqual(manifest["logical_symbol"], "QM5_41121_XAU_XAG_MSEQDOM_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41121_xauxag-mseqdom-rv_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())

        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(
            encoding="utf-8-sig"
        )
        self.assertIn("41121,xauxag-mseqdom-rv,0,XAUUSD.DWX,411210000", magic_rows)
        self.assertIn("41121,xauxag-mseqdom-rv,1,XAGUSD.DWX,411210001", magic_rows)


if __name__ == "__main__":
    unittest.main()
