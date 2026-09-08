"""Display-only news provenance and exact-production-helper native fixtures."""

from pathlib import Path
import re


REPO = Path(__file__).resolve().parents[3]
EA = REPO / "framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5"
FIXTURES = REPO / "framework/tests/mql5/QM11421_ConsoleNews_selftests.mqh"


def function_source(name: str) -> str:
    text = EA.read_text(encoding="utf-8")
    match = re.search(r"\b(?:QM_ConsoleGateState|void|bool)\s+" + name + r"\s*\([^)]*\)\s*\{", text)
    assert match, name
    depth = 0
    for index in range(match.end() - 1, len(text)):
        depth += (text[index] == "{") - (text[index] == "}")
        if not depth:
            return text[match.start():index + 1]
    raise AssertionError("unbalanced helper " + name)


def native_probe_source() -> str:
    """Build artifact source from the exact helpers, excluding trading callbacks."""
    helpers = "\n\n".join(function_source(name) for name in (
        "QM11421_ConsoleNewsKeyMatches", "QM11421_ConsoleNewsObservation", "QM11421_ConsoleGateAlerts"))
    return (
        '#property strict\n#property version "1.00"\n'
        '#include <QM/QM_ConsoleModel.mqh>\n\n' + helpers + '\n\n'
        '#include "QM11421_ConsoleNews_selftests.mqh"\n'
        'void OnStart()\n{\n string failure="";\n'
        ' bool passed=QM11421_ConsoleNewsSelfTest(failure);\n'
        ' Print(passed?"QM11421_NEWS_OBSERVATION_SELF_TESTS PASS":'
        '"QM11421_NEWS_OBSERVATION_SELF_TESTS FAIL: "+failure);\n}\n'
    )


def test_projection_does_not_execute_news_or_read_native_health_from_csv():
    producer = function_source("QM11421_RefreshChartPanel")
    assert "g_qm_news_loaded" not in producer and "g_qm_news_available" not in producer
    assert not re.search(r"\b(?:QM_NewsAllowsTrade\w*|Calendar\w*)\s*\(", producer)
    helper = function_source("QM11421_ConsoleNewsObservation")
    assert not re.search(r"\b(?:Time\w*|QM_News\w*|Calendar\w*|Order\w*|Account\w*)\s*\(", helper)
    assert '"Native MT5 blackout"' not in producer + helper


def test_complete_cache_key_and_effective_axis_routing_are_checked():
    producer = function_source("QM11421_RefreshChartPanel")
    key = function_source("QM11421_ConsoleNewsKeyMatches")
    for comparison in ("cached_symbol==symbol", "cached_bar==bar",
                       "cached_temporal==temporal", "cached_compliance==compliance"):
        assert comparison in key
    assert "bar>0" in key and "g_qm_news_cache_valid,news_key_matches" in producer
    assert "QM11421_ConsoleNewsKeyMatches(_Symbol,cache_bar,temporal,compliance," in producer
    assert "g_qm_news_cache_symbol,g_qm_news_cache_bar_time,g_qm_news_cache_temporal,g_qm_news_cache_compliance" in producer
    assert "QM_NewsLegacyTemporal(qm_news_mode_legacy)" in producer
    assert "QM_NewsLegacyCompliance(qm_news_mode_legacy)" in producer
    assert "qm_news_mode_legacy==QM_NEWS_NEWS_ONLY" in producer


def test_ttl_clock_and_absent_observation_do_not_manufacture_block():
    helper = function_source("QM11421_ConsoleNewsObservation")
    assert re.search(r"if\(age>=60\)[^{]*\{[^}]*return QM_GATE_STALE;", helper)
    assert re.search(r"if\(age<0\)[^{]*\{[^}]*return QM_GATE_STALE;", helper)
    assert re.search(r"if\(!cache_valid \|\| observed_at<=0\)[^{]*\{[^}]*return QM_GATE_WAIT;", helper)
    assert re.search(r"if\(!key_matches\)[^{]*\{[^}]*return QM_GATE_WAIT;", helper)
    assert 'reason=verdict?"Last check clear":"Last check blocked"' in helper


def test_real_blocks_outrank_warning_and_preserve_exposure_headline():
    helper = function_source("QM11421_ConsoleGateAlerts")
    assert "for(int priority=0;priority<2;++priority)" in helper
    assert "const bool blocked=gate.state==QM_GATE_BLOCK || gate.state==QM_GATE_ERROR" in helper
    assert "if(blocked) snapshot.state=" in helper
    assert "snapshot.positions==0 && snapshot.pending_orders==0" in helper
    assert '"Entry warning: ":"Entry check: "' in helper
    assert 'if(gate.key=="capacity") continue' in helper


def test_native_fixture_harness_contains_exact_helpers_not_ea_callbacks():
    generated = native_probe_source()
    for name in ("QM11421_ConsoleNewsKeyMatches", "QM11421_ConsoleNewsObservation", "QM11421_ConsoleGateAlerts"):
        assert function_source(name) in generated
    assert "void OnStart()" in generated
    assert not re.search(r"\b(?:OnTick|OnInit|OrderSend\w*|QM_NewsAllowsTrade\w*)\s*\(", generated)
    fixtures = FIXTURES.read_text(encoding="utf-8")
    for name in ("ttl_60_is_stale_not_block", "old_false_is_not_current_block",
                 "fresh_false_does_not_invent_blackout_cause", "real_kill_block_outranks_earlier_news_wait",
                 "position_headline_preserved_with_block_warning", "missing_quote_remains_separate_warning",
                 "fresh_pass_clears_old_warning", "foreign_symbol_key_rejected", "old_bar_key_rejected",
                 "foreign_temporal_key_rejected", "foreign_compliance_key_rejected"):
        assert name in fixtures
