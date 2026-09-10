from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[2]
EA = ROOT / "framework/EAs/QM5_41149_audusd-local-session-inventory-drift/QM5_41149_audusd-local-session-inventory-drift.mq5"
CARD = Path(r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_41149_audusd-local-session-inventory-drift.md")
SYDNEY = ZoneInfo("Australia/Sydney")


def _first_sunday(year: int, month: int) -> int:
    value = datetime(year, month, 1)
    return 1 + ((6 - value.weekday()) % 7)


def _ea_is_sydney_dst(utc_value: datetime) -> bool:
    year = utc_value.year
    start_local_naive = datetime(year, 10, _first_sunday(year, 10), 2)
    end_local_naive = datetime(year, 4, _first_sunday(year, 4), 3)
    start_utc = (start_local_naive - timedelta(hours=10)).replace(tzinfo=timezone.utc)
    end_utc = (end_local_naive - timedelta(hours=11)).replace(tzinfo=timezone.utc)
    return utc_value < end_utc or utc_value >= start_utc


def test_sydney_dst_rule_matches_zoneinfo_around_boundaries() -> None:
    for year in range(2015, 2027):
        for month in (4, 10):
            center = datetime(year, month, _first_sunday(year, month), tzinfo=timezone.utc)
            for hours in range(-18, 31):
                utc_value = center + timedelta(hours=hours)
                expected = utc_value.astimezone(SYDNEY).utcoffset() == timedelta(hours=11)
                assert _ea_is_sydney_dst(utc_value) is expected


def test_session_boundaries_round_trip_uniquely() -> None:
    for year in range(2015, 2027):
        for month in range(1, 13):
            local_open = datetime(year, month, 15, 10, tzinfo=SYDNEY)
            local_end = datetime(year, month, 15, 16, tzinfo=SYDNEY)
            assert local_open.astimezone(timezone.utc).astimezone(SYDNEY) == local_open
            assert local_end.astimezone(timezone.utc).astimezone(SYDNEY) == local_end
            assert local_end - local_open == timedelta(hours=6)


def test_source_contains_binding_guard_and_card_invariants() -> None:
    source = EA.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")
    assert "g0_status: APPROVED" in card
    assert "target_symbols: [AUDUSD.DWX]" in card
    assert "declared_parameter_count: 2" in card
    assert "strategy_atr_period_h1       = 14" in source
    assert "strategy_hard_stop_atr       = 1.5" in source
    assert "STRATEGY_SESSION_OPEN_HOUR 10" in source
    assert "STRATEGY_SESSION_END_HOUR  16" in source
    assert "QM_NEWS_TEMPORAL_PRE60" in source
    assert "Strategy_ConsumeDateBeforeSubmission()" in source
    assert "QM_StopATRFromValue(_Symbol, QM_SELL" in source
    assert "RISK_FIXED > 0.0" in source
    assert "MathIsValidNumber(qm_stress_reject_probability)" in source


def test_framework_inputs_are_not_default_pinned_by_source_guard() -> None:
    source = EA.read_text(encoding="utf-8")
    forbidden = (
        "qm_rng_seed ==",
        "qm_rng_seed !=",
        "qm_news_temporal ==",
        "qm_news_temporal !=",
        "qm_news_compliance ==",
        "qm_news_compliance !=",
        "qm_news_stale_max_hours ==",
        "qm_news_stale_max_hours !=",
        "qm_news_min_impact ==",
        "qm_news_min_impact !=",
        "qm_news_mode_legacy ==",
        "qm_news_mode_legacy !=",
        "qm_friday_close_enabled ==",
        "qm_friday_close_enabled !=",
        "qm_friday_close_hour_broker ==",
        "qm_friday_close_hour_broker !=",
    )
    assert all(token not in source for token in forbidden)
    assert "qm_stress_reject_probability ==" not in source
    assert "qm_stress_reject_probability !=" not in source
