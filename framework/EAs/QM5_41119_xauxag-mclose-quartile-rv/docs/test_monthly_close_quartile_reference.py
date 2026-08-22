"""Independent deterministic fixtures for QM5_41119's close-quartile basket."""

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
class CloseQuartileResult:
    valid: bool = False
    direction: int = 0
    completed_sessions: int = 0
    tail_count: int = 0
    newest_rank: int = -1
    newest_ratio: float = 0.0
    newest_tied: bool = False


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
    """Build an exact 45-bar newest-first pair with an adjacent older boundary."""

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


def ratios_for_rank(count: int, newest_rank: int) -> list[float]:
    """Return chronological unique ratios whose final value has the given rank."""

    if not 0 <= newest_rank < count:
        raise ValueError("rank outside sample")
    lower = [float(value) for value in range(-newest_rank, 0)]
    upper_count = count - 1 - newest_rank
    upper = [float(value) for value in range(1, upper_count + 1)]
    return lower + upper + [0.0]


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


def monthly_close_quartile(
    current_month: int,
    xau_bars: list[CloseBar],
    xag_bars: list[CloseBar],
    minimum: int = 17,
    maximum: int = 23,
    history_bars: int = HISTORY_BARS,
) -> CloseQuartileResult:
    """Mirror the bounded reconstruction, strict rank, quartile, and inverse side."""

    if (
        current_month <= 0
        or history_bars != HISTORY_BARS
        or minimum > maximum
        or history_bars < maximum + 1
        or len(xau_bars) != history_bars
        or len(xag_bars) != history_bars
        or not synchronized_pair_valid(xau_bars, xag_bars, 0)
    ):
        return CloseQuartileResult()

    completed_key = month_key(xau_bars[0].opened)
    if (
        month_key(xag_bars[0].opened) != completed_key
        or next_month_key(completed_key) != current_month
    ):
        return CloseQuartileResult()

    ratios: list[float] = []
    index = 0
    while index < history_bars and month_key(xau_bars[index].opened) == completed_key:
        if (
            len(ratios) >= maximum
            or not synchronized_pair_valid(xau_bars, xag_bars, index)
            or month_key(xag_bars[index].opened) != completed_key
        ):
            return CloseQuartileResult()
        ratios.append(math.log(xau_bars[index].close) - math.log(xag_bars[index].close))
        index += 1

    if not minimum <= len(ratios) <= maximum or index >= history_bars:
        return CloseQuartileResult()
    if not synchronized_pair_valid(xau_bars, xag_bars, index):
        return CloseQuartileResult()
    older_key = month_key(xau_bars[index].opened)
    if (
        month_key(xag_bars[index].opened) != older_key
        or next_month_key(older_key) != completed_key
    ):
        return CloseQuartileResult()

    newest = ratios[0]
    rank = sum(value < newest for value in ratios[1:])
    tied = any(value == newest for value in ratios[1:])
    tail = (len(ratios) + 3) // 4
    if not math.isfinite(newest) or not 0 <= rank < len(ratios) or 2 * tail >= len(ratios):
        return CloseQuartileResult()

    direction = 0
    if not tied:
        if rank < tail:
            direction = 1
        elif rank >= len(ratios) - tail:
            direction = -1
    return CloseQuartileResult(True, direction, len(ratios), tail, rank, newest, tied)


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


class MonthlyCloseQuartileReferenceTest(unittest.TestCase):
    def signal(self, ratios: list[float], **kwargs: int) -> CloseQuartileResult:
        xau, xag = sample(ratios, **kwargs)
        completed_key = kwargs.get("completed_key", 202607)
        return monthly_close_quartile(next_month_key(completed_key), xau, xag)

    def test_every_allowed_session_count_uses_exact_ceiling_quarter(self) -> None:
        for count in range(17, 24):
            result = self.signal(ratios_for_rank(count, count // 2))
            self.assertTrue(result.valid)
            self.assertEqual(result.completed_sessions, count)
            self.assertEqual(result.tail_count, math.ceil(count / 4))

    def test_each_unique_rank_maps_to_locked_lower_interior_or_upper_state(self) -> None:
        for count in range(17, 24):
            tail = math.ceil(count / 4)
            for rank in range(count):
                result = self.signal(ratios_for_rank(count, rank))
                self.assertTrue(result.valid)
                self.assertEqual(result.newest_rank, rank)
                expected = 1 if rank < tail else -1 if rank >= count - tail else 0
                self.assertEqual(result.direction, expected)

    def test_newest_tie_is_consumed_flat_even_inside_outer_set(self) -> None:
        ratios = ratios_for_rank(20, 0)
        ratios[0] = ratios[-1]
        result = self.signal(ratios)
        self.assertTrue(result.valid)
        self.assertTrue(result.newest_tied)
        self.assertEqual(result.direction, 0)

    def test_session_bounds_are_exact(self) -> None:
        for count in (17, 20, 23):
            self.assertTrue(self.signal(ratios_for_rank(count, 0)).valid)
        for count in (16, 24):
            self.assertFalse(self.signal(ratios_for_rank(count, 0)).valid)

    def test_asynchronous_non_descending_and_invalid_pairs_are_rejected(self) -> None:
        xau, xag = sample(ratios_for_rank(20, 0))
        xag[4] = CloseBar(xag[4].opened + timedelta(hours=1), xag[4].close)
        self.assertFalse(monthly_close_quartile(202608, xau, xag).valid)

        xau, xag = sample(ratios_for_rank(20, 0))
        xau[2] = CloseBar(xau[1].opened, xau[2].close)
        xag[2] = CloseBar(xag[1].opened, xag[2].close)
        self.assertFalse(monthly_close_quartile(202608, xau, xag).valid)

        xau, xag = sample(ratios_for_rank(20, 0))
        xau[3] = CloseBar(xau[3].opened, float("nan"))
        self.assertFalse(monthly_close_quartile(202608, xau, xag).valid)

    def test_month_must_be_immediate_complete_and_have_adjacent_older_boundary(self) -> None:
        xau, xag = sample(ratios_for_rank(20, 0))
        self.assertFalse(monthly_close_quartile(202609, xau, xag).valid)

        xau, xag = sample(ratios_for_rank(20, 0), older_key=202605)
        self.assertFalse(monthly_close_quartile(202608, xau, xag).valid)

        xau, xag = sample(ratios_for_rank(20, 0))
        current = datetime(2026, 8, 1, tzinfo=UTC)
        xau[0] = CloseBar(current, xau[0].close)
        xag[0] = CloseBar(current, xag[0].close)
        self.assertFalse(monthly_close_quartile(202608, xau, xag).valid)

    def test_month_clock_grace_attempt_and_year_boundary_are_exact(self) -> None:
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
        result = self.signal(ratios_for_rank(20, 19), completed_key=202612)
        self.assertTrue(result.valid)
        self.assertEqual(result.direction, -1)

    def test_equal_notional_joint_risk_stays_bounded(self) -> None:
        xau, xag, risk, ratio = equal_notional_package(0.50, 8.00, 250_000.0, 5_000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41119_xauxag-mclose-quartile-rv.mq5").read_text(
            encoding="utf-8"
        )
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41119_xauxag-mclose-quartile-rv_QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1_D1_backtest.set"
        ).read_text(encoding="utf-8")
        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        for marker in (
            "input int    qm_ea_id                    = 41119;",
            "strategy_history_bars_d1         = 45;",
            "CopyRates(g_leg_xau",
            "PERIOD_D1, 1, strategy_history_bars_d1",
            "newest_ratio = ratios[0];",
            "if(ratios[i] == newest_ratio)",
            "tail_count = (completed_month_sessions + 3) / 4;",
            "if(newest_rank < tail_count)",
            "else if(newest_rank >= completed_month_sessions - tail_count)",
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
            "qm_ea_id=41119",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_friday_close_enabled=false",
            "strategy_history_bars_d1=45",
            "strategy_min_month_sessions=17",
            "strategy_max_month_sessions=23",
            "strategy_atr_sl_mult=3.5",
            "strategy_xag_max_spread_points=500",
        ):
            self.assertIn(marker, setfile)
        self.assertEqual(
            manifest["logical_symbol"], "QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1"
        )
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

        approved = (
            REPO_ROOT
            / "strategy-seeds"
            / "cards"
            / "approved"
            / "QM5_41119_xauxag-mclose-quartile-rv_card.md"
        )
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(local.read_bytes(), approved.read_bytes())


if __name__ == "__main__":
    unittest.main()
