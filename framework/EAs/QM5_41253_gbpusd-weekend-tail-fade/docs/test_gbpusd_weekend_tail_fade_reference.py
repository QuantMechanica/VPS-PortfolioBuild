from __future__ import annotations

import datetime as dt
import math
from pathlib import Path
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41253_gbpusd-weekend-tail-fade.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41253_gbpusd-weekend-tail-fade_GBPUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41253_gbpusd-weekend-tail-fade_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
PRIOR_GAP_COUNT = 52
LOWER_INDEX = 5
UPPER_INDEX = 46


def weekend_gap(monday_open: float, friday_close: float) -> float:
    if (
        not math.isfinite(monday_open)
        or not math.isfinite(friday_close)
        or monday_open <= 0.0
        or friday_close <= 0.0
    ):
        raise ValueError("positive finite prices required")
    value = math.log(monday_open / friday_close)
    if not math.isfinite(value):
        raise ValueError("finite log gap required")
    return value


def tail_direction(
    current_gap: float,
    chronological_prior_gaps: list[float],
    lower_index: int = LOWER_INDEX,
    upper_index: int = UPPER_INDEX,
) -> tuple[int, float, float]:
    if (
        len(chronological_prior_gaps) != PRIOR_GAP_COUNT
        or lower_index != LOWER_INDEX
        or upper_index != UPPER_INDEX
        or not math.isfinite(current_gap)
        or any(not math.isfinite(value) for value in chronological_prior_gaps)
    ):
        raise ValueError("locked finite 52-gap sample required")
    sorted_gaps = sorted(chronological_prior_gaps)
    lower = sorted_gaps[lower_index]
    upper = sorted_gaps[upper_index]
    direction = 1 if current_gap < lower else -1 if current_gap > upper else 0
    return direction, lower, upper


def valid_weekend_pairs(
    pairs: list[tuple[dt.datetime, float, dt.datetime, float]],
) -> bool:
    if len(pairs) != PRIOR_GAP_COUNT:
        return False
    last_monday: dt.datetime | None = None
    for monday, monday_open, friday, friday_close in pairs:
        if (
            monday.weekday() != 0
            or friday.weekday() != 4
            or friday >= monday
            or (monday.date() - friday.date()).days != 3
        ):
            return False
        try:
            weekend_gap(monday_open, friday_close)
        except ValueError:
            return False
        if last_monday is not None and monday <= last_monday:
            return False
        last_monday = monday
    return True


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


class GbpusdWeekendTailFadeReferenceTests(unittest.TestCase):
    def test_exact_order_statistics_and_contrarian_side(self) -> None:
        gaps = [float(value) / 10_000.0 for value in range(-26, 26)]
        buy, lower, upper = tail_direction(-0.0100, gaps)
        sell, lower_2, upper_2 = tail_direction(0.0100, gaps)
        self.assertEqual((buy, sell), (1, -1))
        self.assertEqual((lower, upper), (-0.0021, 0.0020))
        self.assertEqual((lower_2, upper_2), (lower, upper))

    def test_tail_boundaries_are_strict(self) -> None:
        gaps = [float(value) / 10_000.0 for value in range(-26, 26)]
        _, lower, upper = tail_direction(0.0, gaps)
        self.assertEqual(tail_direction(lower, gaps)[0], 0)
        self.assertEqual(tail_direction(upper, gaps)[0], 0)
        self.assertEqual(tail_direction(math.nextafter(lower, -math.inf), gaps)[0], 1)
        self.assertEqual(tail_direction(math.nextafter(upper, math.inf), gaps)[0], -1)

    def test_chronological_order_does_not_change_order_statistics(self) -> None:
        gaps = [math.sin(index) / 100.0 for index in range(PRIOR_GAP_COUNT)]
        forward = tail_direction(0.02, gaps)
        backward = tail_direction(0.02, list(reversed(gaps)))
        self.assertEqual(forward, backward)

    def test_weekend_membership_requires_oldest_to_newest_friday_monday_pairs(
        self,
    ) -> None:
        start = dt.datetime(2024, 1, 1)
        pairs = [
            (
                start + dt.timedelta(weeks=index),
                1.25 + index / 10_000.0,
                start + dt.timedelta(weeks=index, days=-3),
                1.25,
            )
            for index in range(PRIOR_GAP_COUNT)
        ]
        self.assertTrue(valid_weekend_pairs(pairs))
        wrong_day = pairs.copy()
        monday, monday_open, friday, friday_close = wrong_day[10]
        wrong_day[10] = (monday, monday_open, friday - dt.timedelta(days=1), friday_close)
        self.assertFalse(valid_weekend_pairs(wrong_day))
        reversed_pairs = list(reversed(pairs))
        self.assertFalse(valid_weekend_pairs(reversed_pairs))

    def test_invalid_count_and_prices_fail_closed(self) -> None:
        gaps = [0.0] * PRIOR_GAP_COUNT
        with self.assertRaises(ValueError):
            tail_direction(0.0, gaps[:-1])
        with self.assertRaises(ValueError):
            tail_direction(math.inf, gaps)
        with self.assertRaises(ValueError):
            tail_direction(0.0, gaps[:-1] + [math.nan])
        with self.assertRaises(ValueError):
            weekend_gap(0.0, 1.0)
        with self.assertRaises(ValueError):
            weekend_gap(1.0, math.inf)

    def test_source_literal_contract(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("strategy_prior_gap_count      = 52", source)
        self.assertIn("strategy_lower_index          = 5", source)
        self.assertIn("strategy_upper_index          = 46", source)
        self.assertIn("current_gap < g_lower_gap", source)
        self.assertIn("current_gap > g_upper_gap", source)
        self.assertIn("Strategy_RecordWeekAttempt(week_key)", source)
        self.assertIn("QM_FRIDAY_CLOSE_CARD_RULE", source)
        self.assertNotIn("iRSI", source)
        self.assertNotIn("iBands", source)
        self.assertNotIn("MathNN_", source)

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41253")
        self.assertEqual(headers["ea_slug"], "gbpusd-weekend-tail-fade")
        self.assertEqual(headers["symbol"], "GBPUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41253",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_prior_gap_count": "52",
            "strategy_lower_index": "5",
            "strategy_upper_index": "46",
            "strategy_history_bars": "900",
            "strategy_entry_grace_minutes": "180",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "7",
            "strategy_max_spread_points": "50",
            "strategy_deviation_points": "20",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        self.assertIn("qm_news_temporal   = QM_NEWS_TEMPORAL_OFF", source)
        self.assertIn("qm_news_compliance = QM_NEWS_COMPLIANCE_NONE", source)
        self.assertIn("qm_friday_close_enabled       = true", source)
        self.assertIn("qm_friday_close_hour_broker   = 21", source)

    def test_card_copy_and_backtest_only_preset(self) -> None:
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
