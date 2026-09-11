from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_41150_gbpusd-local-session-inventory-drift.mq5"
CARD = EA_DIR / "docs" / "strategy_card.md"


def last_sunday(year: int, month: int) -> datetime:
    if month == 12:
        cursor = datetime(year + 1, 1, 1, tzinfo=timezone.utc) - timedelta(days=1)
    else:
        cursor = datetime(year, month + 1, 1, tzinfo=timezone.utc) - timedelta(days=1)
    return cursor - timedelta(days=(cursor.weekday() + 1) % 7)


def uk_offset_hours(utc: datetime) -> int:
    start = last_sunday(utc.year, 3).replace(hour=1)
    end = last_sunday(utc.year, 10).replace(hour=1)
    return int(start <= utc < end)


def london_local(utc: datetime) -> datetime:
    return (utc + timedelta(hours=uk_offset_hours(utc))).replace(tzinfo=None)


def test_identity_card_and_fixed_mechanics_are_wired() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")
    assert "g0_status: APPROVED" in card
    assert "#define STRATEGY_EA_ID             41150" in source
    assert "#define STRATEGY_SESSION_OPEN_HOUR 7" in source
    assert "#define STRATEGY_SESSION_END_HOUR  16" in source
    assert "strategy_atr_period_h1 == 14" in source
    assert "Strategy_DoubleEquals(strategy_hard_stop_atr, 1.5)" in source
    assert 'req.reason = "41150_london_inventory_sell";' in source


def test_uk_dst_boundaries_and_london_session_labels() -> None:
    assert london_local(datetime(2024, 3, 31, 0, 59, tzinfo=timezone.utc)) == datetime(2024, 3, 31, 0, 59)
    assert london_local(datetime(2024, 3, 31, 1, 0, tzinfo=timezone.utc)) == datetime(2024, 3, 31, 2, 0)
    assert london_local(datetime(2024, 10, 27, 0, 59, tzinfo=timezone.utc)) == datetime(2024, 10, 27, 1, 59)
    assert london_local(datetime(2024, 10, 27, 1, 0, tzinfo=timezone.utc)) == datetime(2024, 10, 27, 1, 0)
    assert london_local(datetime(2024, 1, 15, 7, 0, tzinfo=timezone.utc)).hour == 7
    assert london_local(datetime(2024, 7, 15, 6, 0, tzinfo=timezone.utc)).hour == 7


def test_attempt_is_consumed_before_submission_and_exit_precedes_entry() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    consume = source.index("if(!Strategy_ConsumeDateBeforeSubmission())")
    reason = source.index('req.reason = "41150_london_inventory_sell";')
    exit_due = source.index("if(Strategy_ExitDue(local_now))")
    new_bar = source.index("if(!QM_IsNewBar(_Symbol, PERIOD_H1))")
    entry = source.index("if(Strategy_BuildEntry(local_bar_open, req))")
    assert consume < reason
    assert exit_due < new_bar < entry


def test_framework_inputs_are_not_pinned_to_operational_defaults() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert "qm_rng_seed ==" not in source and "qm_rng_seed !=" not in source
    assert "qm_news_temporal ==" not in source and "qm_news_temporal !=" not in source
    assert "qm_news_compliance ==" not in source and "qm_news_compliance !=" not in source
    assert "qm_friday_close_enabled ==" not in source and "qm_friday_close_enabled !=" not in source
    assert "qm_stress_reject_probability == 0" not in source
