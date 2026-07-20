"""Static contracts for the 2026-07-20 framework P1 evidence bundle."""

from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]


def _text(relative: str) -> str:
    return (REPO_ROOT / relative).read_text(encoding="utf-8")


def test_canonical_ontick_samples_mae_before_any_guard() -> None:
    source = _text("framework/templates/EA_Skeleton.mq5")
    on_tick = source.split("void OnTick()", 1)[1]
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )

    prompt = _text("tools/strategy_farm/prompts/codex_build_ea.md")
    prompt_example = prompt.split("void OnTick()", 1)[1]
    assert prompt_example.index("QM_FrameworkTrackOpenPositionMae();") < prompt_example.index(
        "if(!QM_FrameworkInit_OK) return;"
    )
    assert "MAE sampling (before any early return)" in prompt


def test_build_check_accepts_direct_or_killswitch_mae_wiring() -> None:
    source = _text("framework/scripts/build_check.ps1")
    body = source.split("function Invoke-MaeHookStaticCheck", 1)[1].split(
        "function Invoke-PerfStaticCheck", 1
    )[0]
    assert "EA_Q08_MAE_HOOK_MISSING" in body
    assert "QM_FrameworkTrackOpenPositionMae" in body
    assert "QM_KillSwitchCheck" in body
    assert "Add-Warning" in body
    assert "Add-Failure" not in body


def test_tester_news_selftest_is_strict_and_precedes_loaded_event() -> None:
    source = _text("framework/include/QM/QM_NewsFilter.mqh")
    helper = source.split("bool QM_NewsTesterCalendarSelfTest", 1)[1].split(
        "bool QM_NewsPushEvent", 1
    )[0]
    assert "NEWS_TESTER_CALENDAR_SELFTEST" in helper
    assert "QM_NewsEventAffectsSymbol" not in helper
    assert 'event_currency == currency_a' in helper
    assert "applicable && matches == 0" in helper
    assert "QM_ERROR" in helper
    assert "return false;" in helper

    init_body = source.split("bool QM_NewsInit", 1)[1]
    zero_rows = init_body.index("if(g_qm_news_rows_loaded <= 0)")
    selftest = init_body.index("QM_NewsTesterCalendarSelfTest(_Symbol)")
    loaded_event = init_body.index('"NEWS_CALENDAR_LOADED"')
    available = init_body.index("g_qm_news_available = true")
    assert zero_rows < selftest < loaded_event < available
    assert re.search(r"MQLInfoInteger\(MQL_TESTER\)\s*!=\s*0", init_body)

    strict_map = source.split("string QM_NewsIndexCurrencies", 1)[1].split(
        "bool QM_NewsEventAffectsSymbol", 1
    )[0]
    assert 'normalized_symbol == "JPN225"' in strict_map
    assert 'normalized_symbol == "AUS200"' in strict_map

    fixture = _text("framework/tests/QM_framework_p1_evidence_compile_test.mq5")
    assert 'QM_NewsStrictSymbolCurrencies("JPN225.DWX"' in fixture
    assert 'QM_NewsStrictSymbolCurrencies("AUS200.DWX"' in fixture


def test_mae_lineage_doc_does_not_label_all_pre_wave_rows_degenerate() -> None:
    source = _text("framework/scripts/q08_davey/__init__.py")
    assert "715b0c077" in source
    assert "unknown\n    compile lineage" in source
    assert "can already\n    contain true MAE" in source
