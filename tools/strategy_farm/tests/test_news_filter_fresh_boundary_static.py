from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
NEWS_FILTER = REPO / "framework" / "include" / "QM" / "QM_NewsFilter.mqh"


def _source() -> str:
    return NEWS_FILTER.read_text(encoding="utf-8")


def _function_body(source: str, name: str) -> str:
    signature = source.index(f"{name}(")
    opening = source.index("{", signature)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def test_fresh_verdict_bypasses_bar_and_wall_clock_verdict_caches() -> None:
    source = _source()
    body = _function_body(source, "QM_NewsAllowsTrade2Fresh")

    assert "g_qm_news_cache_" not in body
    assert "iTime(" not in body
    assert "QM_NewsAllowsTrade2(" not in body
    assert "MQLInfoInteger(MQL_TESTER)" in body
    assert "QM_NewsLiveTemporalAllows" in body
    assert "QM_NewsLiveComplianceAllows" in body
    assert "QM_NewsTemporalAllows" in body
    assert "QM_NewsComplianceAllows" in body


def test_fresh_verdict_is_fail_closed_for_active_axes_on_both_data_paths() -> None:
    source = _source()
    body = _function_body(source, "QM_NewsAllowsTrade2Fresh")

    assert "!QM_NewsAxesAreValid" in body
    assert "!temporal_ok || !compliance_ok" in body
    assert 'QM_NewsLogSetupMissing("live_calendar_unavailable")' in body
    assert "!g_qm_news_loaded && !QM_NewsInit()" in body
    assert "!g_qm_news_available" in body
    assert 'QM_NewsLogSetupMissing("calendar_unavailable")' in body
    assert "broker_time <= 0" in body
    assert "utc_time <= 0" in body
    assert "g_qm_news_active" not in body
    assert "TimeGMT()" not in body
    assert "TimeCurrent()" not in body
    assert "TimeTradeServer()" not in body
    assert "QM_NewsRequiredTesterCoverage" in body
    assert "QM_NewsBuildUtcIndex()" in body
    assert "g_qm_news_events[0].event_utc > coverage_from_utc" in body
    assert "g_qm_news_events[event_count - 1].event_utc < coverage_to_utc" in body
    assert "tester_calendar_content_coverage_gap" in body


def test_live_calendar_metadata_failures_are_not_silently_skipped() -> None:
    source = _source()
    temporal = _function_body(source, "QM_NewsLiveInWindow")
    compliance = _function_body(source, "QM_NewsLiveComplianceAllows")

    for body in (temporal, compliance):
        assert "if(n < 0)" in body
        assert "if(n == 0)" in body
        assert body.count("out_ok = false;") >= 3
        assert re.search(
            r"if\(!CalendarEventById\([^;]+\)\)\s*"
            r"\{\s*out_ok = false;\s*return false;",
            body,
            re.S,
        )
        assert re.search(
            r"if\(!CalendarCountryById\([^;]+\)\)\s*"
            r"\{\s*out_ok = false;\s*return false;",
            body,
            re.S,
        )
        assert not re.search(
            r"if\(!Calendar(?:Event|Country)ById\([^;]+\)\)\s*continue;",
            body,
            re.S,
        )


def test_boundary_api_exposes_data_error_none_and_found_separately() -> None:
    source = _source()

    assert "QM_NEWS_BLOCKSTART_DATA_ERROR = -1" in source
    assert "QM_NEWS_BLOCKSTART_NONE       = 0" in source
    assert "QM_NEWS_BLOCKSTART_FOUND      = 1" in source

    body = _function_body(source, "QM_NewsNextBlockStart")
    assert "out_block_start_broker = 0;" in body
    assert "QM_NEWS_BLOCKSTART_DATA_ERROR" in body
    assert "QM_NEWS_BLOCKSTART_NONE" in body
    assert "MQLInfoInteger(MQL_TESTER)" in body
    assert "QM_NewsNextBlockStartTester" in body
    assert "QM_NewsNextBlockStartLive" in body
    assert "temporal == QM_NEWS_TEMPORAL_SKIP_DAY" in body


def test_pre30_post30_ftmo_boundary_uses_the_earliest_axis_start() -> None:
    source = _source()
    body = _function_body(source, "QM_NewsBlockStartForEvent")
    lead = _function_body(source, "QM_NewsBlockStartMaxLeadSeconds")

    assert "case QM_NEWS_TEMPORAL_PRE30_POST30:" in body
    assert "temporal_before_minutes = 30;" in body
    assert "QM_NewsFTMOBeforeMinutes(impact_upper)" in body
    assert "temporal_start = event_time - (temporal_before_minutes * 60);" in body
    assert "compliance_start = event_time - (compliance_before_minutes * 60);" in body
    assert "compliance_start < out_start" in body
    assert "case QM_NEWS_TEMPORAL_PRE30_POST30:" in lead
    assert "out_seconds = 30 * 60;" in lead
    assert 'QM_NewsFTMOBeforeMinutes("HIGH")' in lead


def test_live_boundary_uses_native_calendar_and_fails_closed_on_api_errors() -> None:
    source = _source()
    body = _function_body(source, "QM_NewsNextBlockStartLive")

    assert "CalendarValueHistory(values, broker_from, query_to)" in body
    assert "if(n < 0)" in body
    assert "if(n == 0)" in body
    assert "QM_NewsLiveCalendarHealthy" in body
    assert "if(!CalendarEventById" in body
    assert "if(!CalendarCountryById" in body
    assert "QM_NewsImpactMeetsMinimum" in body
    assert "QM_NewsEventAffectsSymbol(country.currency, symbol)" in body
    assert "g_qm_news_events" not in body
    assert "broker_deadline + max_lead_seconds" in body
    assert "earliest == 0 || candidate < earliest" in body
    assert "candidate < broker_from || candidate > broker_deadline" in body
    assert re.search(
        r"if\(!CalendarEventById\([^;]+\)\)\s*"
        r"return QM_NEWS_BLOCKSTART_DATA_ERROR;",
        body,
        re.S,
    )
    assert re.search(
        r"if\(!CalendarCountryById\([^;]+\)\)\s*"
        r"return QM_NEWS_BLOCKSTART_DATA_ERROR;",
        body,
        re.S,
    )
    zero_result = body[body.index("if(n == 0)") : body.index("datetime earliest")]
    assert "QM_NEWS_BLOCKSTART_DATA_ERROR" in zero_result
    assert "QM_NEWS_BLOCKSTART_NONE" in zero_result


def test_tester_boundary_uses_sorted_csv_with_coverage_and_dst_conversion() -> None:
    source = _source()
    body = _function_body(source, "QM_NewsNextBlockStartTester")

    assert "!g_qm_news_loaded && !QM_NewsInit()" in body
    assert "!g_qm_news_available" in body
    assert "QM_NewsBuildUtcIndex()" in body
    assert "QM_NewsLowerBoundUtc(utc_from)" in body
    assert "QM_BrokerToUTC(broker_from)" in body
    assert "QM_BrokerToUTC(broker_deadline)" in body
    assert "g_qm_news_events[0].event_utc > utc_from" in body
    assert "g_qm_news_events[event_count - 1].event_utc < query_to_utc" in body
    assert "QM_NewsImpactMeetsMinimum" in body
    assert "QM_NewsEventAffectsSymbol(event.currency, symbol)" in body
    assert "QM_UTCToBroker(earliest_utc)" in body
    assert "CalendarValueHistory" not in body
    assert "TimeGMT()" not in body
    assert "TimeCurrent()" not in body
    assert "TimeTradeServer()" not in body
    assert "broker_deadline" in body
    assert "query_to_utc = utc_deadline + max_lead_seconds" in body
    assert "earliest_utc == 0 || candidate_utc < earliest_utc" in body
    assert "candidate_utc < utc_from || candidate_utc > utc_deadline" in body
    coverage_check = body[
        body.index("g_qm_news_events[0].event_utc > utc_from") :
        body.index("datetime earliest_utc")
    ]
    assert "QM_NEWS_BLOCKSTART_DATA_ERROR" in coverage_check
