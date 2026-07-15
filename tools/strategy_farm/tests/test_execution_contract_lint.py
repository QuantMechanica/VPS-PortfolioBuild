from __future__ import annotations

import copy
import json
from datetime import date
from pathlib import Path

from tools.strategy_farm import execution_contract_lint as lint


ROOT = Path(__file__).resolve().parents[3]
REGISTRY = ROOT / "framework" / "registry" / "dxz23_execution_contracts.json"


def _contracts() -> list[dict]:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))["contracts"]


def test_dxz23_registry_is_source_bound_and_structurally_clean() -> None:
    payload, contracts, issues = lint.lint_registry(
        REGISTRY,
        repo_root=ROOT,
        as_of=date(2026, 7, 15),
    )
    assert payload["schema_version"] == 2
    assert len(contracts) == 20
    assert len({item["ea_id"] for item in contracts}) == 20
    assert issues == []


def test_uncertain_sleeves_are_machine_blocked_without_strategy_reinvention() -> None:
    by_id = {item["ea_id"]: item for item in _contracts()}
    assert by_id[11165]["promotion"] == {
        "status": "BLOCKED",
        "block_reasons": [
            "deployed_binary_hash_not_bound_to_repo_source",
            "canonical_stream_not_bound_to_deployed_binary",
            "friday_close_override_not_card_qualified",
        ],
    }
    assert by_id[12778]["promotion"]["status"] == "BLOCKED"
    assert "historical_annex_used_wrong_USD_tester_currency" in by_id[12778]["promotion"]["block_reasons"]
    assert by_id[12989]["promotion"]["status"] == "BLOCKED"
    assert by_id[1556]["promotion"]["status"] == "BLOCKED"


def test_promotion_gate_returns_distinct_blocked_exit_code(capsys) -> None:
    result = lint.main(
        [
            "--contracts",
            str(REGISTRY),
            "--repo-root",
            str(ROOT),
            "--as-of",
            "2026-07-15",
            "--ea-id",
            "11165",
            "--require-promotable",
        ]
    )
    output = json.loads(capsys.readouterr().out)
    assert result == 3
    assert output["status"] == "blocked"
    assert output["promotion_blocks"][0]["ea_id"] == 11165


def test_runtime_timeframe_drift_is_rejected(tmp_path: Path) -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 10403))
    original = ROOT / contract["source"]
    target = tmp_path / contract["source"]
    target.parent.mkdir(parents=True)
    source = original.read_text(encoding="utf-8")
    source = source.replace(
        "QM_FrameworkDeclareExecutionContract(PERIOD_D1,",
        "QM_FrameworkDeclareExecutionContract(PERIOD_H1,",
        1,
    )
    target.write_text(source, encoding="utf-8")

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=tmp_path, as_of=date(2026, 7, 15))
    }
    assert "runtime_timeframe_mismatch" in codes


def test_finite_calendar_expires_fail_closed_in_linter() -> None:
    contract = next(item for item in _contracts() if item["ea_id"] == 13128)
    issues = lint.lint_contract(contract, repo_root=ROOT, as_of=date(2027, 1, 1))
    assert "calendar_expired" in {issue.code for issue in issues}


def test_card_v2_template_satisfies_required_execution_sections() -> None:
    template = ROOT / "framework" / "templates" / "strategy_card_v2.md"
    assert lint.lint_card_v2(template) == []


def test_card_v2_missing_override_section_is_rejected(tmp_path: Path) -> None:
    card = tmp_path / "card.md"
    text = (ROOT / "framework" / "templates" / "strategy_card_v2.md").read_text(encoding="utf-8")
    text = text.replace("## Framework execution overrides", "## Framework notes")
    card.write_text(text, encoding="utf-8")
    assert "card_v2_section_missing" in {issue.code for issue in lint.lint_card_v2(card)}


def test_13128_calendar_and_12778_canonical_harness_guards_are_literal() -> None:
    fomc = (
        ROOT
        / "framework/EAs/QM5_13128_pre-fomc-drift-ndx/QM5_13128_pre-fomc-drift-ndx.mq5"
    ).read_text(encoding="utf-8")
    assert "g_event_calendar_valid_through_key = 20261231" in fomc
    assert "20260128, 20260318, 20260429, 20260617" in fomc
    assert "20260729, 20260916, 20261028, 20261209" in fomc
    assert "Strategy_CalendarCoverageAllows(broker_now)" in fomc
    assert "SETUP_DATA_STALE" in fomc

    basket = (
        ROOT
        / "framework/EAs/QM5_12778_edgelab-audusd-eurjpy-cointegration"
        / "QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5"
    ).read_text(encoding="utf-8")
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in basket
    assert 'MQLInfoInteger(MQL_TESTER) != 0 && AccountInfoString(ACCOUNT_CURRENCY) != "EUR"' in basket
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in basket
