from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_pre_fomc_ndx_requalification.py"
)
SPEC = importlib.util.spec_from_file_location("qm13128_requalification_audit", TOOL)
assert SPEC and SPEC.loader
audit = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = audit
SPEC.loader.exec_module(audit)


def test_contract_is_hash_pinned_and_blocked() -> None:
    contract = audit.load_contract()
    assert audit.sha256_path(audit.CONTRACT_PATH) == audit.EXPECTED_CONTRACT_SHA256
    assert contract["decision"]["state"] == "BLOCKED_NOT_RELEASED"
    assert contract["decision"]["execution_authority"] == "NONE"
    assert contract["decision"]["tester_authority"] == "NONE"
    assert contract["decision"]["promotion_authority"] == "NONE"


def test_contract_hash_drift_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(audit, "EXPECTED_CONTRACT_SHA256", "0" * 64)
    with pytest.raises(audit.AuditError, match="contract hash drift"):
        audit.load_contract()


def test_official_calendar_is_exact_unique_and_ordered() -> None:
    contract = audit.load_contract()
    audit.verify_calendar(contract)
    assert len(audit.OFFICIAL_DATE_KEYS) == 65
    assert len(set(audit.OFFICIAL_DATE_KEYS)) == 65
    assert audit.OFFICIAL_DATE_KEYS[-8:] == (
        20260128,
        20260318,
        20260429,
        20260617,
        20260729,
        20260916,
        20261028,
        20261209,
    )


def test_calendar_parser_reads_only_the_named_array() -> None:
    source = """
    // unrelated 20991231
    const int g_event_dates[] = {20260128, 20260318};
    const int other = 20991231;
    """
    assert audit.extract_source_date_keys(source) == (20260128, 20260318)


def test_backtest_and_live_risk_identities_remain_separate() -> None:
    audit.verify_set_and_risk_identity()


def test_card_source_and_binary_conflict_is_reproduced() -> None:
    contract = audit.load_contract()
    audit.verify_card_source_binary_conflict(contract)


def test_registry_and_data_blockers_are_content_bound() -> None:
    contract = audit.load_contract()
    audit.verify_registry_blockers(contract)
    audit.verify_fail_closed_state(contract)


def test_all_frozen_source_bindings_match() -> None:
    if not Path("D:/QM").is_dir():
        pytest.skip("VPS evidence volume D:/QM is not mounted")
    contract = audit.load_contract()
    assert audit.verify_source_bindings(contract) == len(contract["source_bindings"])


def test_full_audit_reproduces_blocked_state_without_tester() -> None:
    if not Path("D:/QM").is_dir():
        pytest.skip("VPS evidence volume D:/QM is not mounted")
    result = audit.run_audit()
    assert result == {
        "analysis_id": "QM5_13128_PRE_FOMC_NDX_REQUAL_READINESS_20260720_001",
        "status": "PASS_BLOCKED_STATE_REPRODUCED",
        "qualification_state": "BLOCKED_NOT_RELEASED",
        "tester_started": False,
        "source_bindings_verified": 22,
        "official_calendar_dates_verified": 65,
        "future_events_fenced": 4,
    }


def test_tool_has_no_execution_surface() -> None:
    source = TOOL.read_text(encoding="utf-8")
    for forbidden in ("import subprocess", "os.system", "terminal64.exe", "metatester"):
        assert forbidden not in source.lower()
    assert "only --check is supported; this tool has no tester mode" in source
