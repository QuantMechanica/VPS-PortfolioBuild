from __future__ import annotations

from datetime import datetime, timezone

from tools.strategy_farm.news_calendar_blast_radius import (
    classify_pair,
    count_entry_windows,
    effective_news_mode,
    parse_input_defaults,
    parse_set_assignments,
    symbol_has_usd_exposure,
)


ACTIVE_EA = """
input QM_NewsTemporalMode qm_news_temporal = QM_NEWS_TEMPORAL_PRE30_POST30;
bool Strategy_NoTradeFilter() {
  return !QM_NewsAllowsTrade2(_Symbol, TimeCurrent(), qm_news_temporal,
                              QM_NEWS_COMPLIANCE_DXZ);
}
"""


def test_symbol_usd_applicability_matches_framework_aliases() -> None:
    assert symbol_has_usd_exposure("EURUSD.DWX")
    assert symbol_has_usd_exposure("USDJPY.DWX")
    assert symbol_has_usd_exposure("XAUUSD.DWX")
    assert symbol_has_usd_exposure("NDX.DWX")
    assert symbol_has_usd_exposure("WS30.DWX")
    assert not symbol_has_usd_exposure("EURGBP.DWX")
    assert not symbol_has_usd_exposure("GDAXI.DWX")


def test_synthetic_ea_snippets_cover_exposed_inert_and_unknown() -> None:
    defaults = parse_input_defaults(ACTIVE_EA)
    state, source, value = effective_news_mode({}, defaults, {})
    assert (state, source, value) == (
        "ACTIVE",
        "mq5_default.qm_news_temporal",
        "QM_NEWS_TEMPORAL_PRE30_POST30",
    )
    assert classify_pair(
        symbol="EURUSD.DWX", timeframe="M5", news_state=state, source_text=ACTIVE_EA
    )[0] == "EXPOSED"
    assert classify_pair(
        symbol="EURUSD.DWX", timeframe="D1", news_state=state, source_text=ACTIVE_EA
    )[0] == "INERT"
    assert classify_pair(
        symbol="EURGBP.DWX", timeframe="M5", news_state=state, source_text=ACTIVE_EA
    )[0] == "INERT"
    assert classify_pair(
        symbol="EURUSD.DWX", timeframe="M5", news_state="UNKNOWN", source_text=ACTIVE_EA
    )[0] == "UNKNOWN"


def test_setfile_off_overrides_active_source_default() -> None:
    values = parse_set_assignments(
        "; comment\nqm_news_temporal=QM_NEWS_TEMPORAL_OFF||0||0||6||N\n"
    )
    state, source, value = effective_news_mode(values, parse_input_defaults(ACTIVE_EA), {})
    assert (state, source, value) == (
        "OFF",
        "setfile.qm_news_temporal",
        "QM_NEWS_TEMPORAL_OFF",
    )
    assert classify_pair(
        symbol="XAUUSD.DWX", timeframe="H1", news_state=state, source_text=ACTIVE_EA
    )[0] == "INERT"


def test_entry_window_counter_converts_broker_wall_time_to_utc() -> None:
    # January broker UTC+2: 15:30 broker is the true 13:30Z release slot.
    true_broker = datetime(2024, 1, 5, 15, 30, tzinfo=timezone.utc)
    # July broker UTC+3: Thursday 23:30 broker is the wrong 20:30Z slot.
    wrong_broker = datetime(2024, 7, 11, 23, 30, tzinfo=timezone.utc)
    outside = datetime(2024, 7, 12, 8, 0, tzinfo=timezone.utc)
    counts = count_entry_windows([true_broker, wrong_broker, outside])
    assert counts["entries"] == 3
    assert counts["true_window_entries"] == 1
    assert counts["wrong_thursday_window_entries"] == 1
