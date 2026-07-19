from __future__ import annotations

import copy
import json
import shutil
import subprocess
from datetime import date
from pathlib import Path

import pytest

from tools.strategy_farm import execution_contract_lint as lint


ROOT = Path(__file__).resolve().parents[3]
REGISTRY = ROOT / "framework" / "registry" / "dxz23_execution_contracts.json"
SCHEMA = ROOT / "framework" / "schemas" / "strategy_card_v2_execution_contract.schema.json"


def _contracts() -> list[dict]:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))["contracts"]


def _by_sleeve() -> dict[tuple[int, str, str], dict]:
    return {
        (int(item["ea_id"]), str(item["symbol"]), str(item["timeframe"])): item
        for item in _contracts()
    }


def _schema_valid(payload: Path) -> bool:
    pwsh = shutil.which("pwsh")
    if pwsh is None:
        pytest.skip("PowerShell Test-Json is required for JSON-schema integration tests")
    command = (
        "& { param($payloadPath, $schemaPath) "
        "$payload = Get-Content -Raw -LiteralPath $payloadPath; "
        "$valid = $payload | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue; "
        "if ($valid) { exit 0 } else { exit 1 } }"
    )
    completed = subprocess.run(
        [pwsh, "-NoProfile", "-NonInteractive", "-Command", command, str(payload), str(SCHEMA)],
        check=False,
        capture_output=True,
        text=True,
    )
    return completed.returncode == 0


def test_dxz23_registry_is_source_bound_and_structurally_clean() -> None:
    payload, contracts, issues = lint.lint_registry(
        REGISTRY,
        repo_root=ROOT,
        as_of=date(2026, 7, 15),
    )
    assert payload["schema_version"] == 2
    assert len(contracts) == 27
    assert len({item["ea_id"] for item in contracts}) == 21
    assert len(
        {
            (item["ea_id"], item.get("symbol"), item.get("timeframe"))
            for item in contracts
        }
    ) == 27
    assert issues == []


def test_dxz23_registry_is_valid_against_execution_contract_schema() -> None:
    assert _schema_valid(REGISTRY)


def test_exact_contract_identity_includes_optional_variant() -> None:
    contract = copy.deepcopy(_contracts()[0])
    contract["variant_id"] = "C_POLICY_REPAIR"

    assert lint.execution_contract_identity(contract) == (
        contract["ea_id"],
        contract["symbol"],
        contract["timeframe"],
        "C_POLICY_REPAIR",
    )
    assert lint.execution_contract_identity_label(contract).endswith(
        ":C_POLICY_REPAIR"
    )


def test_schema_accepts_exact_variant_and_rejects_legacy_variant(tmp_path: Path) -> None:
    payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
    payload["contracts"][0]["variant_id"] = "C_POLICY_REPAIR"
    exact = tmp_path / "exact_variant.json"
    exact.write_text(json.dumps(payload), encoding="utf-8")
    assert _schema_valid(exact)

    payload["contracts"][0].pop("symbol")
    payload["contracts"][0].pop("timeframe")
    legacy = tmp_path / "legacy_variant.json"
    legacy.write_text(json.dumps(payload), encoding="utf-8")
    assert not _schema_valid(legacy)


def test_same_ea_symbol_different_timeframes_and_variants_do_not_collide(
    tmp_path: Path,
) -> None:
    first = copy.deepcopy(_contracts()[0])
    first["variant_id"] = "VARIANT_A"
    second = copy.deepcopy(first)
    second["timeframe"] = "H1"
    second["strategy_timeframe"] = "H1"
    second["bar_gate_timeframe"] = "H1"
    third = copy.deepcopy(first)
    third["variant_id"] = "VARIANT_B"
    registry = tmp_path / "contracts.json"
    registry.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "book_id": "IDENTITY_TEST",
                "contracts": [first, second, third],
            }
        ),
        encoding="utf-8",
    )

    _payload, _selected, issues = lint.lint_registry(
        registry, repo_root=ROOT, as_of=date(2026, 7, 16)
    )
    assert "duplicate_sleeve_identity" not in {issue.code for issue in issues}

    duplicate = copy.deepcopy(third)
    payload = json.loads(registry.read_text(encoding="utf-8"))
    payload["contracts"].append(duplicate)
    registry.write_text(json.dumps(payload), encoding="utf-8")
    _payload, _selected, issues = lint.lint_registry(
        registry, repo_root=ROOT, as_of=date(2026, 7, 16)
    )
    assert "duplicate_sleeve_identity" in {issue.code for issue in issues}


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("unexpected_override", True),
        ("test_symbol", "SP500"),
        ("live_order_symbol", "SP500.DWX"),
        ("status", "BACKTEST_ONLY_NON_ORDER_ROUTABLE"),
        ("automatic_symbol_inference", True),
    ],
)
def test_dxz_routing_schema_rejects_extra_fields_and_weaker_values(
    tmp_path: Path,
    field: str,
    value: object,
) -> None:
    payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
    contract = next(item for item in payload["contracts"] if item["ea_id"] == 11132)
    contract["darwinex_zero_routing"][field] = value
    invalid = tmp_path / "invalid_execution_contracts.json"
    invalid.write_text(json.dumps(payload), encoding="utf-8")

    assert not _schema_valid(invalid)


def test_uncertain_sleeves_are_machine_blocked_without_strategy_reinvention() -> None:
    by_id = {item["ea_id"]: item for item in _contracts()}
    by_sleeve = _by_sleeve()
    assert by_id[11132]["promotion"]["status"] == "BLOCKED"
    assert by_id[11132]["darwinex_zero_routing"] == {
        "test_symbol": "SP500.DWX",
        "live_order_symbol": "SP500",
        "status": "BACKTEST_ALIAS_TO_ORDER_ROUTABLE_BROKER_SYMBOL",
        "source_registry": "framework/registry/dwx_symbol_matrix.csv",
        "evidence_ref": "docs/ops/evidence/DXZ_11132_SP500_DIRECT_ROUTABILITY_2026-07-16.md",
        "automatic_symbol_inference": False,
        "qualification_status": "REQUAL_REQUIRED",
        "full_requalification_required": True,
    }
    assert "sp500_dwx_to_sp500_alias_full_requalification_required" in by_id[11132][
        "promotion"
    ]["block_reasons"]
    assert "darwinex_zero_sp500_dwx_backtest_only_non_order_routable" not in by_id[11132][
        "promotion"
    ]["block_reasons"]
    assert "substitute_to_ndx_or_ws30_full_requalification_required" not in by_id[11132][
        "promotion"
    ]["block_reasons"]
    assert by_sleeve[(11165, "AUDCAD.DWX", "H1")]["promotion"] == {
        "status": "BLOCKED",
        "block_reasons": [
            "deployed_binary_hash_not_bound_to_repo_source",
            "canonical_stream_not_bound_to_deployed_binary",
            "audcad_live_preset_strategy_parameters_not_card_qualified",
            "legacy_q08_identity_incomplete",
            "friday_close_override_not_card_qualified",
        ],
    }
    assert "audcad_live_preset_strategy_parameters_not_card_qualified" not in by_sleeve[
        (11165, "EURUSD.DWX", "H1")
    ]["promotion"]["block_reasons"]
    assert by_id[12778]["promotion"]["status"] == "BLOCKED"
    assert "historical_annex_used_wrong_USD_tester_currency" in by_id[12778]["promotion"]["block_reasons"]
    assert by_id[12989]["promotion"]["status"] == "BLOCKED"
    assert by_id[1556]["promotion"]["status"] == "BLOCKED"


def test_10706_owner_risk_decision_and_double_scaling_are_machine_blocked() -> None:
    by_id = {item["ea_id"]: item for item in _contracts()}
    promotion = by_id[10706]["promotion"]

    assert promotion["status"] == "BLOCKED"
    assert {
        "owner_canonical_percent_risk_contract_decision_required",
        "historical_double_scaled_source_manifest_rejected",
        "reference_risk_contract_rebase_required",
        "mandatory_friday_close_after_news_filter_remediation_required",
        "session_aware_weekend_flattening_remediation_required",
        "legacy_q08_full_execution_identity_incomplete",
        "structured_five_axis_cost_evidence_required",
    }.issubset(set(promotion["block_reasons"]))


def test_10939_owner_semantics_binary_risk_and_identity_conflicts_are_blocked() -> None:
    by_id = {item["ea_id"]: item for item in _contracts()}
    promotion = by_id[10939]["promotion"]

    assert promotion["status"] == "BLOCKED"
    assert {
        "approved_card_g0_status_contradiction",
        "card_v2_qm_interpretation_owner_approval_required",
        "owner_news_risk_source_closure_decisions_required",
        "friday_close_21_owner_directive_unsealed",
        "mandatory_friday_close_after_news_filter_remediation_required",
        "session_aware_weekend_flattening_remediation_required",
        "deployed_binary_hash_differs_from_repository_binary",
        "repository_live_risk_differs_from_as_live_risk",
        "legacy_q08_full_identity_invalid_missing_entry_time",
        "six_commission_rows_bounded_ambiguous",
        "structured_five_axis_cost_evidence_required",
        "continuous_segment_requalification_required",
    }.issubset(set(promotion["block_reasons"]))


def test_12567_xau_and_xng_variant_conflicts_are_machine_blocked() -> None:
    by_sleeve = _by_sleeve()
    xau = by_sleeve[(12567, "XAUUSD.DWX", "D1")]["promotion"]
    xng = by_sleeve[(12567, "XNGUSD.DWX", "D1")]["promotion"]

    assert xau["status"] == "BLOCKED"
    assert {
        "xau_owner_qm_variant_news_risk_source_decisions_required",
        "friday_close_21_owner_directive_unsealed",
        "mandatory_friday_close_after_news_filter_remediation_required",
        "session_aware_weekend_flattening_remediation_required",
        "xau_deployed_binary_hash_differs_from_repository_binary",
        "xau_repository_live_risk_differs_from_as_live_risk",
        "xau_historical_double_scaled_source_manifest_rejected",
        "xau_legacy_q08_identity_invalid_28_of_73_missing_entry_time",
        "xau_full_execution_lot_pnl_identity_required",
        "xau_structured_five_axis_cost_evidence_required",
        "xau_continuous_segment_requalification_required",
    }.issubset(set(xau["block_reasons"]))
    assert "xng_live_threshold_not_card_qualified" not in xau["block_reasons"]

    assert xng["status"] == "BLOCKED"
    assert {
        "xng_live_threshold_not_card_qualified",
        "friday_close_21_owner_directive_unsealed",
        "mandatory_friday_close_after_news_filter_remediation_required",
        "session_aware_weekend_flattening_remediation_required",
        "structured_five_axis_cost_evidence_required",
        "continuous_segment_requalification_required",
    }.issubset(set(xng["block_reasons"]))
    assert not any(reason.startswith("xau_") for reason in xng["block_reasons"])


def test_unqualified_explicit_alias_can_never_be_promotion_eligible() -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 11132))
    contract["promotion"] = {"status": "ELIGIBLE", "block_reasons": []}

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 15))
    }

    assert "dxz_unqualified_alias_promotable" in codes
    assert "dxz_alias_requalification_reason_missing" in codes


def test_structured_order_routable_alias_overrides_legacy_backtest_only_prose(
    tmp_path: Path,
) -> None:
    matrix = tmp_path / "dwx_symbol_matrix.csv"
    matrix.write_text(
        "symbol,evidence_line,live_order_symbol,live_order_status,routing_evidence_ref\n"
        'SP500.DWX,"custom alias is backtest-only",SP500,ORDER_ROUTABLE_CONFIRMED,evidence.md\n',
        encoding="utf-8",
    )

    blocked, error = lint.load_non_order_routable_symbols(matrix)
    routes, route_error = lint.load_symbol_routing_rows(matrix)

    assert error is None
    assert route_error is None
    assert blocked == {}
    assert routes["SP500.DWX"]["live_order_symbol"] == "SP500"


def test_explicit_alias_fails_closed_when_matrix_maps_a_different_live_symbol(
    tmp_path: Path,
) -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 11132))
    matrix = tmp_path / "dwx_symbol_matrix.csv"
    matrix.write_text(
        "symbol,evidence_line,live_order_symbol,live_order_status,routing_evidence_ref\n"
        "SP500.DWX,route,NDX,ORDER_ROUTABLE_CONFIRMED,"
        "docs/ops/evidence/DXZ_11132_SP500_DIRECT_ROUTABILITY_2026-07-16.md\n",
        encoding="utf-8",
    )
    contract["darwinex_zero_routing"]["source_registry"] = str(matrix)

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 15))
    }

    assert "dxz_alias_live_symbol_mismatch" in codes


def test_explicit_alias_fails_closed_without_structured_matrix_columns(tmp_path: Path) -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 11132))
    matrix = tmp_path / "dwx_symbol_matrix.csv"
    matrix.write_text("symbol,evidence_line\nSP500.DWX,legacy-only\n", encoding="utf-8")
    contract["darwinex_zero_routing"]["source_registry"] = str(matrix)

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 15))
    }

    assert "dxz_routing_matrix_invalid" in codes


def test_six_pass_semantic_conflicts_are_machine_blocked() -> None:
    by_id = {item["ea_id"]: item for item in _contracts()}
    expected_reasons = {
        10403: "unresolved_semantic_conflict_friday_close_replaces_card_continuous_channel_exit_187_of_209",
        12969: "unresolved_semantic_conflict_card_no_fixed_stop_vs_active_120_pip_stop_triggered_2_of_331",
        13128: "unresolved_semantic_conflict_card_calendar_ends_2025_vs_source_calendar_extends_2026",
    }

    assert by_id[10403]["friday_close"]["qualification_status"] == "BLOCKED"
    for ea_id, reason in expected_reasons.items():
        assert by_id[ea_id]["promotion"]["status"] == "BLOCKED"
        assert reason in by_id[ea_id]["promotion"]["block_reasons"]


def test_unresolved_semantic_conflict_cannot_be_downgraded_to_requal() -> None:
    for ea_id in (10403, 12969, 13128):
        contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == ea_id))
        contract["promotion"]["status"] = "REQUAL_REQUIRED"

        codes = {
            issue.code
            for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 15))
        }

        assert "unresolved_semantic_conflict_not_blocked" in codes
        if ea_id == 10403:
            assert "blocked_friday_contract_not_blocked" in codes


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


def test_20009_multimode_runtime_declarations_are_exactly_registered() -> None:
    contracts = [item for item in _contracts() if item["ea_id"] == 20009]
    assert {
        (item["symbol"], item["timeframe"], item["variant_id"])
        for item in contracts
    } == {
        ("NDX.DWX", "M1", "INDEX_PRIMARY"),
        ("GDAXI.DWX", "M1", "INDEX_TRANSPORT"),
        ("EURUSD.DWX", "M5", "FX_PRIMARY_EURUSD"),
        ("GBPUSD.DWX", "M5", "FX_PRIMARY_GBPUSD"),
    }
    for contract in contracts:
        codes = {
            issue.code
            for issue in lint.lint_contract(
                contract, repo_root=ROOT, as_of=date(2026, 7, 19)
            )
        }
        assert "execution_contract_call_count" not in codes
        assert "runtime_bar_gate_missing" not in codes


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
