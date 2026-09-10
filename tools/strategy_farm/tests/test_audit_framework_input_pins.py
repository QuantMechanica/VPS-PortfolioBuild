from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


MODULE_PATH = Path(__file__).resolve().parents[2] / "audit_framework_input_pins.py"
SPEC = importlib.util.spec_from_file_location("audit_framework_input_pins", MODULE_PATH)
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = AUDIT
SPEC.loader.exec_module(AUDIT)


def _source(condition: str) -> str:
    return f"""
input int qm_ea_id = 1;
input int qm_magic_slot_offset = 0;
input int qm_rng_seed = 42;
input int qm_news_temporal = 3;
input bool qm_friday_close_enabled = true;
input double qm_stress_reject_probability = 0.0;
input int strategy_period = 14;
input double RISK_FIXED = 1000.0;
input double RISK_PERCENT = 0.0;
int OnInit()
{{
   if({condition}) return INIT_PARAMETERS_INCORRECT;
   if(!FrameworkInit(qm_rng_seed, qm_news_temporal,
                     qm_friday_close_enabled,
                     qm_stress_reject_probability)) return INIT_FAILED;
   return INIT_SUCCEEDED;
}}
void OnTick() {{ if(qm_news_temporal != 0) return; }}
"""


def test_allows_contract_pins_and_stress_validation() -> None:
    findings = AUDIT.audit_source(
        _source(
            "qm_ea_id != 1 || qm_magic_slot_offset != 0 || "
            "strategy_period != 14 || RISK_FIXED <= 0 || RISK_PERCENT != 0 || "
            "!MathIsValidNumber(qm_stress_reject_probability) || "
            "qm_stress_reject_probability < 0.0 || "
            "qm_stress_reject_probability > 1.0"
        )
    )
    assert findings == []


def test_rejects_rng_news_and_friday_pins() -> None:
    for condition, expected in (
        ("qm_rng_seed != 42", "qm_rng_seed"),
        ("qm_news_temporal == 3", "qm_news_*"),
        ("qm_friday_close_enabled != true", "qm_friday_close_*"),
        ("!qm_friday_close_enabled", "qm_friday_close_*"),
    ):
        messages = [finding.message for finding in AUDIT.audit_source(_source(condition))]
        assert any(expected in message for message in messages)


def test_rejects_stress_default_equality_and_non_range_threshold() -> None:
    for condition in (
        "qm_stress_reject_probability != 0.0",
        "qm_stress_reject_probability == 0.25",
        "qm_stress_reject_probability > 0.5",
    ):
        messages = [finding.message for finding in AUDIT.audit_source(_source(condition))]
        assert any("stress rejection probability" in message for message in messages)


def test_ignores_comments_strings_and_runtime_news_branch() -> None:
    text = _source("strategy_period != 14") + r'''
// if(qm_rng_seed != 42) return;
string example = "qm_news_temporal == 3";
'''
    assert AUDIT.audit_source(text) == []


def test_requires_balanced_on_init() -> None:
    findings = AUDIT.audit_source("void OnTick() {}")
    assert findings and "OnInit" in findings[0].message
