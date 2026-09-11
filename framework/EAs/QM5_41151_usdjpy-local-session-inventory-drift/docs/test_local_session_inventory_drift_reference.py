from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_41151_usdjpy-local-session-inventory-drift.mq5"
CARD = EA_DIR / "docs" / "strategy_card.md"


def tokyo_local(utc: datetime) -> datetime:
    return (utc + timedelta(hours=9)).replace(tzinfo=None)


def test_identity_card_and_fixed_mechanics_are_wired() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")
    assert "g0_status: APPROVED" in card
    assert "#define STRATEGY_EA_ID             41151" in source
    assert "#define STRATEGY_SESSION_OPEN_HOUR 9" in source
    assert "#define STRATEGY_SESSION_END_HOUR  18" in source
    assert "strategy_atr_period_h1 == 14" in source
    assert "Strategy_DoubleEquals(strategy_hard_stop_atr, 1.5)" in source
    assert 'req.reason = "41151_tokyo_inventory_buy";' in source


def test_jst_is_fixed_utc_plus_nine_without_dst() -> None:
    assert tokyo_local(datetime(2024, 1, 15, 0, 0, tzinfo=timezone.utc)) == datetime(2024, 1, 15, 9, 0)
    assert tokyo_local(datetime(2024, 7, 15, 0, 0, tzinfo=timezone.utc)) == datetime(2024, 7, 15, 9, 0)
    assert tokyo_local(datetime(2024, 12, 31, 15, 0, tzinfo=timezone.utc)) == datetime(2025, 1, 1, 0, 0)


def test_attempt_is_consumed_before_submission_and_exit_precedes_entry() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    consume = source.index("if(!Strategy_ConsumeDateBeforeSubmission())")
    reason = source.index('req.reason = "41151_tokyo_inventory_buy";')
    exit_due = source.index("if(Strategy_ExitSignal())")
    new_bar = source.index("if(!QM_IsNewBar(_Symbol, PERIOD_H1))")
    entry = source.index("if(Strategy_EntrySignal(req))")
    assert consume < reason
    assert exit_due < new_bar < entry


def test_framework_inputs_are_not_pinned_to_operational_defaults() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert "qm_rng_seed ==" not in source and "qm_rng_seed !=" not in source
    assert "qm_news_temporal ==" not in source and "qm_news_temporal !=" not in source
    assert "qm_news_compliance ==" not in source and "qm_news_compliance !=" not in source
    assert "qm_friday_close_enabled ==" not in source and "qm_friday_close_enabled !=" not in source
    assert "qm_stress_reject_probability == 0" not in source
