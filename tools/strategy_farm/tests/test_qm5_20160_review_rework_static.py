from __future__ import annotations

import hashlib
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_20160_xng-fri-trend"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
SETFILE = EA_DIR / "sets" / f"{LABEL}_XNGUSD.DWX_D1_backtest.set"
APPROVED_CARD = REPO / "strategy-seeds" / "cards" / "approved" / f"{LABEL}_card.md"
LOCAL_CARD = EA_DIR / "docs" / "strategy_card.md"


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def test_owner_session_tick_amendment_is_wired_without_strategy_drift() -> None:
    source = _source()
    compact = _compact(source)

    assert "Strategy_SessionAnchor(current_bar)" in source
    assert "strategy_session_offset_min*60.0" in compact
    assert "strategy_entry_grace_minutes*60" in compact
    assert "g_observed_bar_ticks<strategy_min_stub_ticks" in compact
    assert "g_active_attach_ticks<strategy_min_attach_ticks" in compact
    assert "now+5*60" in compact
    assert "Strategy_RecordWeekAttempt(week_key)" in source
    assert compact.index("Strategy_RecordWeekAttempt(week_key)") < compact.index(
        "Strategy_LoadMomentum(momentum,direction)"
    )
    assert 'req.type=QM_SELL;' in compact
    assert "direction!=-1" in compact
    assert "strategy_atr_sl_mult" in source
    assert 'req.tp=0.0;' in compact


def test_every_declared_strategy_input_has_a_mechanism_use_site() -> None:
    source = _source()
    strategy_inputs = re.findall(
        r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert strategy_inputs == [
        "strategy_momentum_lookback_d1",
        "strategy_min_abs_return_pct",
        "strategy_session_offset_min",
        "strategy_entry_grace_minutes",
        "strategy_min_stub_ticks",
        "strategy_min_attach_ticks",
        "strategy_atr_period",
        "strategy_atr_sl_mult",
        "strategy_max_hold_days",
        "strategy_max_spread_points",
    ]
    for input_name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(input_name)}\b", source)) >= 3, input_name


def test_framework_news_risk_magic_and_mae_contracts_are_fail_closed() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkInit(qm_ea_id,qm_magic_slot_offset,RISK_PERCENT,RISK_FIXED," in compact
    assert "qm_news_temporal=QM_NEWS_TEMPORAL_PRE30_POST30;" in compact
    assert "qm_news_compliance=QM_NEWS_COMPLIANCE_DXZ;" in compact
    assert "qm_news_mode_legacy=QM_NEWS_PAUSE;" in compact
    assert "qm_news_stale_max_hours=336;" in compact
    assert "QM_NewsAllowsTrade2(" in source
    assert "NEWS_BLACKOUT_OR_STALE_DATA" in source
    assert "QM_TM_OpenPosition(req,out_ticket)" in compact
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)


def test_series_access_is_bounded_guarded_and_perf_annotated() -> None:
    source = _source()
    compact = _compact(source)

    assert "CopyClose(_Symbol,//perf-allowed:boundedFridayD1momentumsample." in compact
    assert "ArraySize(closes)<required" in compact
    for line in source.splitlines():
        if re.search(r"\b(?:iTime|CopyClose)\s*\(", line):
            assert "perf-allowed" in line, line


def test_backtest_set_binds_fixed_risk_news_and_all_strategy_inputs() -> None:
    content = SETFILE.read_text(encoding="utf-8-sig")

    assert "; symbol:       XNGUSD.DWX" in content
    assert "; timeframe:    D1" in content
    assert "; environment:  backtest" in content
    assert "qm_magic_slot_offset=0" in content
    assert "RISK_FIXED=1000" in content
    assert "RISK_PERCENT=0" in content
    assert "qm_news_temporal=3" in content
    assert "qm_news_compliance=1" in content
    assert "qm_news_mode_legacy=1" in content
    source_sha256 = hashlib.sha256(EA.read_bytes()).hexdigest()
    assert f"; build_hash:   {source_sha256}" in content
    for name in re.findall(
        r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
        _source(),
        flags=re.MULTILINE,
    ):
        assert re.search(rf"^{re.escape(name)}=", content, re.MULTILINE), name


def test_local_build_card_is_exactly_the_current_owner_approved_copy() -> None:
    assert LOCAL_CARD.read_text(encoding="utf-8") == APPROVED_CARD.read_text(
        encoding="utf-8"
    )
