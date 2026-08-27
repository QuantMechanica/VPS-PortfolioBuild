import copy
import json
import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import q13_declaration_validator as q13  # noqa: E402


SHA = "a" * 64


def _frequency() -> dict:
    return {
        "entry_trading_days_floor": 10,
        "per_scored_year": True,
        "partial_year_pro_rata": True,
        "evaluated_before_performance_selection": True,
    }


def _parameter(index: int, values: list[int] | None = None) -> dict:
    return {
        "input_name": f"strategy_parameter_{index}",
        "input_type": "int",
        "parent_value": 3,
        "candidate_values": values or [1, 2, 3, 4, 5],
        "technical_bounds": {"minimum": 1, "maximum": 10},
        "interaction_constraints": [],
        "hypothesis": f"Mechanical causal hypothesis {index}",
        "expected_effect": "Robust plateau around the parent, not an isolated peak",
        "refutation_criterion": "Reject if the sealed plateau or holdout condition fails",
        "frequency_check": _frequency(),
    }


def _seal(declaration: dict) -> dict:
    declaration["declaration_sha256"] = q13.canonical_declaration_sha256(
        declaration
    )
    return declaration


def _declaration(parameter_count: int = 3) -> dict:
    parameters = [_parameter(index) for index in range(parameter_count)]
    trial_increment = sum(len(item["candidate_values"]) - 1 for item in parameters)
    physical_cells = 0 if not parameters else 7 * (1 + 5 * parameter_count) + 2
    terminal_hours = round(physical_cells * 7.2 / 60, 2)
    declaration = {
        "schema": q13.DECLARATION_SCHEMA,
        "contract_id": "OWNER-DEC-Q13-BUDGET-CONTRACT-20260827-OPTION-M",
        "gate_contract_version": "v4",
        "budget_option": "M",
        "owner_decision_id": "OWNER-DEC-Q13-BUDGET-OPTION-M-20260827",
        "ea_id": "QM5_41097",
        "symbol": "GBPUSD.DWX",
        "timeframe": "H1",
        "bindings": {
            "q11_work_item_id": "q11-parent",
            "q11_evidence_sha256": SHA,
            "q12_work_item_id": "q12-parent",
            "q12_evidence_sha256": SHA,
        },
        "hashes": {
            "parent_build_sha256": SHA,
            "setfile_sha256": SHA,
            "include_closure_sha256": SHA,
        },
        "q12_filter_freeze_sha256": SHA,
        "one_parameter_per_cell": True,
        "selection_years": list(range(2019, 2026)),
        "objective": "return_to_maxdd",
        "activity_floor": _frequency(),
        "consistency_rule": {
            "min_year_fraction": "2/3",
            "min_relative_improvement_pct": 5.0,
            "no_frequency_break": True,
            "plateau_median_selection": True,
        },
        "parameter_count": parameter_count,
        "parameters": parameters,
        "declared_trial_count_before": 154,
        "declared_trial_increment": trial_increment,
        "declared_trial_count_effective_after": 154 + trial_increment,
        "q13_lineage_trial_increment_before": 0,
        "q13_lineage_trial_increment_effective_after": trial_increment,
        "physical_q13_cells": physical_cells,
        "terminal_hours": terminal_hours,
    }
    return _seal(declaration)


def test_sealed_contract_and_authority_hashes_authenticate():
    contract = q13.load_contract()
    assert contract["budget_option"] == "M"
    assert contract["limits"]["max_lineage_trial_increment"] == 12
    assert contract["limits"]["max_physical_q13_cells"] == 114


def test_option_m_maximum_declaration_is_valid_and_reports_ledger_growth():
    result = q13.validate_declaration(_declaration(), env={})
    assert result.valid is True
    assert result.code == "VALID_OPTION_M_DECLARATION"
    assert result.declared_trial_increment == 12
    assert result.physical_q13_cells == 114
    assert result.terminal_hours == 13.68
    assert result.activation_enabled is False


def test_zero_parameter_no_change_contract_remains_valid_default():
    result = q13.validate_declaration(_declaration(parameter_count=0), env={})
    assert result.valid is True
    assert result.declared_trial_increment == 0
    assert result.physical_q13_cells == 0
    assert result.terminal_hours == 0.0


def test_admission_is_default_off_even_for_valid_declaration():
    result = q13.admission_decision(_declaration(), env={})
    assert result.valid is False
    assert result.code == "Q13_DECLARATIONS_DISABLED"


def test_admission_can_only_pass_with_explicit_flag_and_valid_declaration():
    result = q13.admission_decision(
        _declaration(), env={q13.ACTIVATION_ENV: "1"}
    )
    assert result.valid is True
    assert result.activation_enabled is True


def test_missing_parameter_count_fails_closed():
    declaration = _declaration()
    declaration.pop("parameter_count")
    _seal(declaration)
    result = q13.validate_declaration(declaration)
    assert result.valid is False
    assert any("parameter_count" in error for error in result.errors)


def test_missing_or_blank_gelb_fields_fail_closed():
    declaration = _declaration()
    declaration["parameters"][0]["hypothesis"] = ""
    declaration["parameters"][1].pop("refutation_criterion")
    declaration["parameters"][2].pop("frequency_check")
    _seal(declaration)
    result = q13.validate_declaration(declaration)
    assert result.valid is False
    joined = "\n".join(result.errors)
    assert "hypothesis" in joined
    assert "refutation_criterion" in joined
    assert "frequency_check" in joined


def test_four_parameters_exceed_option_m_budget():
    result = q13.validate_declaration(_declaration(parameter_count=4))
    assert result.valid is False
    assert any("BUDGET_CONTRACT_EXCEEDED" in error for error in result.errors)


def test_six_values_exceed_per_parameter_budget():
    declaration = _declaration(parameter_count=1)
    declaration["parameters"][0] = _parameter(0, [1, 2, 3, 4, 5, 6])
    declaration["declared_trial_increment"] = 5
    declaration["declared_trial_count_effective_after"] = 159
    declaration["q13_lineage_trial_increment_effective_after"] = 5
    declaration["physical_q13_cells"] = 51
    declaration["terminal_hours"] = 6.12
    _seal(declaration)
    result = q13.validate_declaration(declaration)
    assert result.valid is False
    assert any("candidate_values" in error for error in result.errors)


def test_lineage_ledger_cannot_evade_twelve_trial_cap():
    declaration = _declaration()
    declaration["q13_lineage_trial_increment_before"] = 4
    declaration["q13_lineage_trial_increment_effective_after"] = 16
    _seal(declaration)
    result = q13.validate_declaration(declaration)
    assert result.valid is False
    assert any("Q13 lineage trial ledger" in error for error in result.errors)


def test_trial_ledger_arithmetic_mismatch_fails_closed():
    declaration = _declaration()
    declaration["declared_trial_count_effective_after"] += 1
    _seal(declaration)
    result = q13.validate_declaration(declaration)
    assert result.valid is False
    assert any("ledger arithmetic mismatch" in error for error in result.errors)


def test_declaration_hash_drift_fails_closed():
    declaration = _declaration()
    declaration["symbol"] = "EURUSD.DWX"
    result = q13.validate_declaration(declaration)
    assert result.valid is False
    assert "declaration_sha256 mismatch" in result.errors


def test_contract_copy_is_rejected_when_byte_changed(tmp_path):
    contract = json.loads(q13.CONTRACT_PATH.read_text(encoding="utf-8"))
    contract["limits"]["max_parameter_count"] = 4
    drifted = tmp_path / "contract.json"
    drifted.write_text(json.dumps(contract), encoding="utf-8")
    try:
        q13.load_contract(drifted)
    except q13.ContractError as exc:
        assert "sha256 mismatch" in str(exc)
    else:
        raise AssertionError("drifted contract was accepted")


def test_invalid_declaration_never_passes_when_activation_flag_is_on():
    declaration = copy.deepcopy(_declaration())
    declaration["parameters"][0]["hypothesis"] = ""
    _seal(declaration)
    result = q13.admission_decision(
        declaration, env={q13.ACTIVATION_ENV: "1"}
    )
    assert result.valid is False
    assert result.code == "DECLARATION_INVALID"
