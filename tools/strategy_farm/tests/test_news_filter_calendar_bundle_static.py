from __future__ import annotations

from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
NEWS_FILTER = REPO / "framework" / "include" / "QM" / "QM_NewsFilter.mqh"
COMMON = REPO / "framework" / "include" / "QM" / "QM_Common.mqh"


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


def test_bundle_fields_are_plain_report_visible_inputs() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")

    for field in (
        "qm_news_calendar_bundle_id",
        "qm_news_calendar_expected_sha256",
        "qm_news_calendar_common_relative_path",
    ):
        assert f'input string {field} = "";' in source


def test_bundle_loader_hashes_strict_common_file_before_parsing_and_rechecks_it() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")
    strict_read = _function_body(source, "QM_NewsReadCommonFileBytes")
    bundle_init = _function_body(source, "QM_NewsInitTesterBundle")

    assert "FILE_COMMON" in strict_read
    assert "QM_NewsBasename" not in strict_read
    assert bundle_init.index("QM_NewsHashBytes(verified_bytes") < bundle_init.index(
        "QM_NewsLoadCsv(common_relative_path, rows_bundle, true)"
    )
    assert "calendar_bundle_sha256_mismatch" in bundle_init
    assert "calendar_bundle_changed_during_parse" in bundle_init
    assert "ArrayResize(g_qm_news_events, 0);" in bundle_init
    assert '"NEWS_CALENDAR_BUNDLE_LOADED"' in bundle_init
    for field in ("bundle_id", "sha256", "rows"):
        assert f'\\"{field}\\"' in bundle_init


def test_bundle_branch_is_tester_only_partial_inputs_fail_and_controls_authenticate() -> None:
    news_source = NEWS_FILTER.read_text(encoding="utf-8")
    common_source = COMMON.read_text(encoding="utf-8")
    news_init = _function_body(news_source, "QM_NewsInit")
    framework_init = _function_body(
        common_source, "QM_FrameworkInitCoreAfterRuntimeStateArmed"
    )

    assert "MQLInfoInteger(MQL_TESTER) != 0 && QM_NewsTesterBundleInputsRequested()" in news_init
    assert "QM_NewsTesterBundleInputsComplete()" in news_init
    assert "calendar_bundle_inputs_partial" in news_init
    assert news_init.index("QM_NewsInitTesterBundle()") < news_init.index("uchar bytes_primary[]")
    assert "MQLInfoInteger(MQL_TESTER) != 0 && QM_NewsTesterBundleInputsRequested()" in framework_init
    assert "tester_bundle_requested" in framework_init
    assert "(news_compliance != QM_NEWS_COMPLIANCE_NONE) ||\n                                 tester_bundle_requested" in framework_init


def test_live_decision_branches_never_read_bundle_inputs() -> None:
    source = NEWS_FILTER.read_text(encoding="utf-8")

    for function in (
        "QM_NewsLiveTemporalAllows",
        "QM_NewsLiveComplianceAllows",
        "QM_NewsNextBlockStartLive",
    ):
        assert "qm_news_calendar_" not in _function_body(source, function)
