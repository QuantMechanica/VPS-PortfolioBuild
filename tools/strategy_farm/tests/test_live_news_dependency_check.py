from pathlib import Path

from tools.strategy_farm import live_news_dependency_check as guard


ROOT = Path("C:/QM/repo")


def test_corpus_live_news_include_closures_are_native_and_fail_closed() -> None:
    report = guard.scan(ROOT)
    assert report["ea_sources_checked"] > 0
    assert report["news_filter_contracts_checked"] == 1
    assert report["findings"] == []
    assert report["ok"] is True


def test_contract_rejects_archive_allow_when_native_calendar_unavailable() -> None:
    source = (ROOT / "framework/include/QM/QM_NewsFilter.mqh").read_text(encoding="utf-8-sig")
    broken = source.replace("verdict_live = false; // fail-closed", "verdict_live = true; // fail-open", 1)
    assert "live_calendar_unavailable_not_fail_closed" in guard.contract_defects(broken)


def test_contract_rejects_missing_native_compliance_route() -> None:
    source = (ROOT / "framework/include/QM/QM_NewsFilter.mqh").read_text(encoding="utf-8-sig")
    function = guard.extract_function(source, "QM_NewsAllowsTrade2")
    broken_function = function.replace("QM_NewsLiveComplianceAllows", "QM_NewsComplianceAllows", 1)
    broken = source.replace(function, broken_function)
    assert "live_native_decision_call_missing:QM_NewsLiveComplianceAllows" in guard.contract_defects(broken)


def test_build_check_wires_named_live_news_predicate() -> None:
    source = (ROOT / "framework/scripts/build_check.ps1").read_text(encoding="utf-8-sig")
    assert "EA_LIVE_NEWS_ARCHIVE_DEPENDENCY" in source
    assert "live_news_dependency_check.py" in source
