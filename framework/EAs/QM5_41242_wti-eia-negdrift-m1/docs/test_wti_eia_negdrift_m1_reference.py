from __future__ import annotations

import math
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EA = ROOT / "QM5_41242_wti-eia-negdrift-m1.mq5"
SETFILE = ROOT / "sets" / "QM5_41242_wti-eia-negdrift-m1_XTIUSD.DWX_M1_backtest.set"


def signal(open_value: float, close_value: float) -> int:
    if not all(math.isfinite(v) and v > 0 for v in (open_value, close_value)):
        return 0
    return -1 if close_value < open_value else 0


def valid_event(
    *,
    weekday: int,
    decision_hhmm: int,
    decision_second: int,
    release_hhmm: int,
    same_day: bool,
    separation_seconds: int,
) -> bool:
    return (
        weekday == 3
        and decision_hhmm == 1031
        and 0 <= decision_second < 30
        and release_hhmm == 1030
        and same_day
        and separation_seconds == 60
    )


def should_close(
    *,
    same_day: bool,
    now_hhmm: int,
    elapsed_seconds: int,
    malformed: bool = False,
) -> bool:
    return malformed or not same_day or now_hhmm >= 1035 or elapsed_seconds >= 600


class SignalReferenceTests(unittest.TestCase):
    def test_negative_bar_sells(self) -> None:
        self.assertEqual(signal(80.25, 79.90), -1)

    def test_positive_bar_is_flat(self) -> None:
        self.assertEqual(signal(79.90, 80.25), 0)

    def test_equal_bar_is_flat(self) -> None:
        self.assertEqual(signal(80.00, 80.00), 0)

    def test_invalid_price_is_flat(self) -> None:
        self.assertEqual(signal(float("nan"), 80.00), 0)
        self.assertEqual(signal(80.00, 0.00), 0)

    def test_exact_event_is_valid(self) -> None:
        self.assertTrue(
            valid_event(
                weekday=3,
                decision_hhmm=1031,
                decision_second=0,
                release_hhmm=1030,
                same_day=True,
                separation_seconds=60,
            )
        )

    def test_grace_boundary_is_strict(self) -> None:
        self.assertTrue(
            valid_event(
                weekday=3,
                decision_hhmm=1031,
                decision_second=29,
                release_hhmm=1030,
                same_day=True,
                separation_seconds=60,
            )
        )
        self.assertFalse(
            valid_event(
                weekday=3,
                decision_hhmm=1031,
                decision_second=30,
                release_hhmm=1030,
                same_day=True,
                separation_seconds=60,
            )
        )

    def test_wrong_weekday_is_invalid(self) -> None:
        self.assertFalse(
            valid_event(
                weekday=4,
                decision_hhmm=1031,
                decision_second=0,
                release_hhmm=1030,
                same_day=True,
                separation_seconds=60,
            )
        )

    def test_missing_minute_is_invalid(self) -> None:
        self.assertFalse(
            valid_event(
                weekday=3,
                decision_hhmm=1031,
                decision_second=0,
                release_hhmm=1029,
                same_day=True,
                separation_seconds=120,
            )
        )

    def test_close_clock_and_repairs(self) -> None:
        self.assertFalse(should_close(same_day=True, now_hhmm=1034, elapsed_seconds=239))
        self.assertTrue(should_close(same_day=True, now_hhmm=1035, elapsed_seconds=240))
        self.assertTrue(should_close(same_day=False, now_hhmm=900, elapsed_seconds=60))
        self.assertTrue(should_close(same_day=True, now_hhmm=1032, elapsed_seconds=600))
        self.assertTrue(should_close(same_day=True, now_hhmm=1032, elapsed_seconds=60, malformed=True))


class BuildContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ea_text = EA.read_text(encoding="utf-8")
        cls.set_text = SETFILE.read_text(encoding="utf-8")

    def test_identity_and_host_are_frozen(self) -> None:
        self.assertIn("qm_ea_id                     = 41242", self.ea_text)
        self.assertIn('_Symbol == "XTIUSD.DWX" && _Period == PERIOD_M1', self.ea_text)
        self.assertIn("QM_FRIDAY_CLOSE_CARD_RULE", self.ea_text)

    def test_signal_is_short_only_and_strict(self) -> None:
        self.assertIn("!(release_close < release_open)", self.ea_text)
        self.assertIn("request.type = QM_SELL", self.ea_text)
        self.assertNotIn("request.type = QM_BUY", self.ea_text)

    def test_attempt_precedes_fallible_event_reads(self) -> None:
        record_at = self.ea_text.index("Strategy_RecordAttemptState(day_key)")
        release_at = self.ea_text.index("iTime(_Symbol, PERIOD_M1, 1)", record_at)
        atr_at = self.ea_text.index("QM_ATR(_Symbol, PERIOD_M1", record_at)
        self.assertLess(record_at, release_at)
        self.assertLess(record_at, atr_at)

    def test_exact_clock_and_lifecycle_are_locked(self) -> None:
        for fragment in (
            "strategy_release_hhmm_ny == 1030",
            "strategy_decision_hhmm_ny == 1031",
            "strategy_flat_hhmm_ny == 1035",
            "strategy_entry_grace_seconds == 30",
            "strategy_max_hold_minutes == 10",
        ):
            self.assertIn(fragment, self.ea_text)

    def test_frozen_atr_stop_and_no_target(self) -> None:
        self.assertIn("strategy_atr_period_m1 == 20", self.ea_text)
        self.assertIn("strategy_atr_stop_multiple - 3.0", self.ea_text)
        self.assertIn("QM_StopATRFromValue", self.ea_text)
        self.assertIn("request.tp = 0.0", self.ea_text)

    def test_news_axes_are_off(self) -> None:
        self.assertIn("qm_news_temporal == QM_NEWS_TEMPORAL_OFF", self.ea_text)
        self.assertIn("qm_news_compliance == QM_NEWS_COMPLIANCE_NONE", self.ea_text)
        self.assertIn("qm_news_mode_legacy == QM_NEWS_OFF", self.ea_text)

    def test_setfile_is_fixed_risk_only(self) -> None:
        for line in (
            "qm_ea_id=41242",
            "qm_magic_slot_offset=0",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_news_temporal=0",
            "qm_news_compliance=0",
            "qm_news_mode_legacy=0",
            "strategy_release_hhmm_ny=1030",
            "strategy_decision_hhmm_ny=1031",
            "strategy_flat_hhmm_ny=1035",
            "strategy_atr_stop_multiple=3.0",
        ):
            self.assertIn(line, self.set_text)


if __name__ == "__main__":
    unittest.main()
