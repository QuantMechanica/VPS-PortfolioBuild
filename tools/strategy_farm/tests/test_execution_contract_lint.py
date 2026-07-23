from __future__ import annotations

import copy
import hashlib
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


def _write_enriched_contract_fixture(tmp_path: Path) -> tuple[dict, Path]:
    ea_id = 29999
    slug = "synthetic"
    source = (
        tmp_path
        / "framework"
        / "EAs"
        / f"QM5_{ea_id}_{slug}"
        / f"QM5_{ea_id}_{slug}.mq5"
    )
    source.parent.mkdir(parents=True)
    source.write_text(
        "\n".join(
            (
                "input int qm_ea_id = 29999;",
                "input int qm_magic_slot_offset = 0;",
                "input bool qm_friday_close_enabled = false;",
                'const string strategy_variant_id = "BASELINE";',
                "void BindContract() {",
                '  QM_FrameworkDeclareExecutionContract(PERIOD_H1, QM_FRIDAY_CLOSE_DISABLED, "none");',
                "}",
                "void OnTick() {",
                "  if(!QM_IsNewBar(_Symbol, PERIOD_H1)) return;",
                "}",
                "",
            )
        ),
        encoding="utf-8",
    )

    card = tmp_path / "cards" / f"QM5_{ea_id}_{slug}.md"
    card.parent.mkdir(parents=True)
    card.write_text(
        """---
card_schema_version: 2
ea_id: QM5_29999
slug: synthetic
status: DRAFT
g0_status: APPROVED
symbol: EURUSD.DWX
timeframe: H1
variant_id: BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=29999
execution_contract_status: DRAFT
---

# Synthetic fixture

## Source-defined rules

Fixture.

## QM interpretations

Fixture.

## Framework execution overrides

None.

## Exit precedence

Fixture.

## Runtime data dependencies

Fixture.

## Falsification and requalification

Fixture.
""",
        encoding="utf-8",
    )

    setfile = source.parent / "sets" / f"QM5_{ea_id}_{slug}_EURUSD.DWX_H1_backtest.set"
    setfile.parent.mkdir()
    setfile.write_text(
        "; deterministic fixture\nqm_ea_id=29999\nqm_magic_slot_offset=0\n",
        encoding="utf-8",
    )
    setfile_hash = hashlib.sha256(setfile.read_bytes()).hexdigest()

    artifact = tmp_path / "data" / "side_guard.csv"
    artifact.parent.mkdir()
    artifact.write_text("day,allow\n2026-07-22,1\n", encoding="utf-8")
    artifact_hash = hashlib.sha256(artifact.read_bytes()).hexdigest()

    magic_registry = tmp_path / "framework" / "registry" / "magic_numbers.csv"
    magic_registry.parent.mkdir(parents=True)
    magic_registry.write_text(
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
        "29999,synthetic,0,EURUSD.DWX,299990000,2026-07-22,Development,active\n",
        encoding="utf-8",
    )

    contract = {
        "ea_id": ea_id,
        "symbol": "EURUSD.DWX",
        "timeframe": "H1",
        "variant_id": "BASELINE",
        "slug": slug,
        "card_ref": str(card.relative_to(tmp_path)).replace("\\", "/"),
        "source": str(source.relative_to(tmp_path)).replace("\\", "/"),
        "strategy_timeframe": "H1",
        "bar_gate_timeframe": "H1",
        "card_binding": {
            "ea_id": ea_id,
            "slug": slug,
            "timeframe": "H1",
            "variant_id": "BASELINE",
            "status": "DRAFT",
            "execution_contract_status": "DRAFT",
        },
        "runtime_binding": {
            "qm_ea_id": ea_id,
            "magic_slot_offset": 0,
            "setfile": str(setfile.relative_to(tmp_path)).replace("\\", "/"),
            "setfile_sha256": setfile_hash,
            "magic_registry": str(magic_registry.relative_to(tmp_path)).replace("\\", "/"),
        },
        "data_dependencies": [
            {
                "dependency_id": "native_event_calendar",
                "type": "calendar",
                "qualification_status": "PASS",
                "required_for": ["ENTRY"],
                "block_reason": None,
                "source_ref": "NATIVE_MT5_CALENDAR",
                "calendar_policy": "EVENT_TIMESTAMPS",
                "stale_behavior": "ENTRY_FAIL_CLOSED",
                "coverage_start": "2026-01-01",
                "coverage_end": "2026-12-31",
            },
            {
                "dependency_id": "side_guard",
                "type": "artifact",
                "qualification_status": "PASS",
                "required_for": ["ENTRY"],
                "block_reason": None,
                "path": str(artifact.relative_to(tmp_path)).replace("\\", "/"),
                "sha256": artifact_hash,
            },
            {
                "dependency_id": "xti_signal_anchor",
                "type": "signal_anchor",
                "qualification_status": "PASS",
                "required_for": ["SIGNAL_ONLY"],
                "block_reason": None,
                "symbol": "XTIUSD.DWX",
                "timeframe": "H1",
                "order_allowed": False,
            },
            {
                "dependency_id": "broker_session_exceptions",
                "type": "session_metadata",
                "qualification_status": "BLOCKED",
                "required_for": ["ENTRY", "EXIT"],
                "block_reason": "dependency_broker_session_exception_calendar_missing",
                "metadata_kind": "SESSION_EXCEPTION_CALENDAR",
                "source_ref": "BROKER_SESSION_LEDGER_PENDING",
            },
        ],
        "friday_close": {
            "enabled": False,
            "hour_broker": None,
            "mode": "DISABLED",
            "declaration": "none",
            "qualification_status": "PASS",
        },
        "calendar": {"policy": "NONE"},
        "promotion": {
            "status": "BLOCKED",
            "block_reasons": [
                "card_status_draft_not_approved",
                "card_execution_contract_status_draft_not_approved",
                "dependency_broker_session_exception_calendar_missing",
            ],
        },
    }
    return contract, source


def test_enriched_contract_binds_card_runtime_and_all_dependency_types(
    tmp_path: Path,
) -> None:
    contract, _source = _write_enriched_contract_fixture(tmp_path)
    registry = tmp_path / "contracts.json"
    registry.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "book_id": "ENRICHED_CONTRACT_FIXTURE",
                "contracts": [contract],
            }
        ),
        encoding="utf-8",
    )

    assert _schema_valid(registry)
    assert lint.lint_contract(
        contract,
        repo_root=tmp_path,
        as_of=date(2026, 7, 22),
    ) == []


def test_general_symbol_routing_is_not_hardcoded_to_sp500(tmp_path: Path) -> None:
    contract, _source = _write_enriched_contract_fixture(tmp_path)
    evidence = tmp_path / "evidence" / "eurusd-route.md"
    evidence.parent.mkdir()
    evidence.write_text("EURUSD.DWX tester alias routes explicitly to EURUSD.\n", encoding="utf-8")
    matrix = tmp_path / "framework" / "registry" / "symbol_matrix.csv"
    matrix.write_text(
        "symbol,evidence_line,live_order_symbol,live_order_status,routing_evidence_ref\n"
        f"EURUSD.DWX,explicit route,EURUSD,ORDER_ROUTABLE_CONFIRMED,{evidence.as_posix()}\n",
        encoding="utf-8",
    )
    contract["symbol_routing"] = {
        "test_symbol": "EURUSD.DWX",
        "live_order_symbol": "EURUSD",
        "status": "BACKTEST_ALIAS_TO_ORDER_ROUTABLE_BROKER_SYMBOL",
        "source_registry": matrix.as_posix(),
        "evidence_ref": evidence.as_posix(),
        "automatic_symbol_inference": False,
        "qualification_status": "PASS",
        "full_requalification_required": True,
    }
    registry = tmp_path / "contracts.json"
    registry.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "book_id": "GENERAL_ROUTING_FIXTURE",
                "contracts": [contract],
            }
        ),
        encoding="utf-8",
    )

    assert _schema_valid(registry)
    codes = {
        issue.code
        for issue in lint.lint_contract(
            contract,
            repo_root=tmp_path,
            as_of=date(2026, 7, 22),
        )
    }
    assert not {code for code in codes if code.startswith("dxz_")}

    contract["darwinex_zero_routing"] = copy.deepcopy(contract["symbol_routing"])
    registry.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "book_id": "DUPLICATE_ROUTING_FIXTURE",
                "contracts": [contract],
            }
        ),
        encoding="utf-8",
    )
    assert not _schema_valid(registry)
    duplicate_codes = {
        issue.code
        for issue in lint.lint_contract(
            contract,
            repo_root=tmp_path,
            as_of=date(2026, 7, 22),
        )
    }
    assert "symbol_routing_duplicate" in duplicate_codes


def test_dependency_block_reason_and_blocked_promotion_are_mandatory(
    tmp_path: Path,
) -> None:
    contract, _source = _write_enriched_contract_fixture(tmp_path)
    contract["promotion"]["block_reasons"].remove(
        "dependency_broker_session_exception_calendar_missing"
    )
    codes = {
        issue.code
        for issue in lint.lint_contract(
            contract,
            repo_root=tmp_path,
            as_of=date(2026, 7, 22),
        )
    }
    assert "data_dependency_promotion_reason_missing" in codes

    contract["promotion"]["status"] = "REQUAL_REQUIRED"
    codes = {
        issue.code
        for issue in lint.lint_contract(
            contract,
            repo_root=tmp_path,
            as_of=date(2026, 7, 22),
        )
    }
    assert "blocked_dependency_not_blocked" in codes


def test_card_binding_matches_contract_and_card_frontmatter(tmp_path: Path) -> None:
    contract, _source = _write_enriched_contract_fixture(tmp_path)
    contract["card_binding"]["slug"] = "wrong-slug"
    codes = {
        issue.code
        for issue in lint.lint_contract(
            contract,
            repo_root=tmp_path,
            as_of=date(2026, 7, 22),
        )
    }
    assert "card_binding_contract_mismatch" in codes
    assert "card_binding_frontmatter_mismatch" in codes


def test_runtime_binding_rejects_source_setfile_hash_slot_and_magic_drift(
    tmp_path: Path,
) -> None:
    contract, source = _write_enriched_contract_fixture(tmp_path)
    contract["runtime_binding"]["qm_ea_id"] = 30000
    source.write_text(
        source.read_text(encoding="utf-8").replace(
            "input int qm_ea_id = 29999;",
            "input int qm_ea_id = 999;",
        ),
        encoding="utf-8",
    )
    setfile = tmp_path / contract["runtime_binding"]["setfile"]
    setfile.write_text(
        "; drifted fixture\nqm_ea_id=999\nqm_magic_slot_offset=4\n",
        encoding="utf-8",
    )
    magic_registry = tmp_path / contract["runtime_binding"]["magic_registry"]
    magic_registry.write_text(
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n",
        encoding="utf-8",
    )

    codes = {
        issue.code
        for issue in lint.lint_contract(
            contract,
            repo_root=tmp_path,
            as_of=date(2026, 7, 22),
        )
    }
    assert {
        "runtime_qm_ea_id_contract_mismatch",
        "runtime_qm_ea_id_mismatch",
        "runtime_setfile_hash_mismatch",
        "runtime_setfile_ea_id_mismatch",
        "runtime_setfile_slot_mismatch",
        "runtime_magic_registry_binding_missing",
    }.issubset(codes)


def test_enriched_contract_still_requires_explicit_bar_gate(tmp_path: Path) -> None:
    contract, source = _write_enriched_contract_fixture(tmp_path)
    source.write_text(
        source.read_text(encoding="utf-8").replace(
            "QM_IsNewBar(_Symbol, PERIOD_H1)",
            "QM_IsNewBar()",
        ),
        encoding="utf-8",
    )
    codes = {
        issue.code
        for issue in lint.lint_contract(
            contract,
            repo_root=tmp_path,
            as_of=date(2026, 7, 22),
        )
    }
    assert "runtime_bar_gate_missing" in codes


def test_schema_rejects_pass_dependency_with_block_reason(tmp_path: Path) -> None:
    contract, _source = _write_enriched_contract_fixture(tmp_path)
    contract["data_dependencies"][0]["block_reason"] = "stale_reason"
    registry = tmp_path / "contracts.json"
    registry.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "book_id": "INVALID_DEPENDENCY_FIXTURE",
                "contracts": [contract],
            }
        ),
        encoding="utf-8",
    )
    assert not _schema_valid(registry)


def test_dxz23_registry_is_source_bound_and_structurally_clean() -> None:
    payload, contracts, issues = lint.lint_registry(
        REGISTRY,
        repo_root=ROOT,
        as_of=date(2026, 7, 15),
    )
    assert payload["schema_version"] == 2
    assert len(contracts) == 55
    assert len({item["ea_id"] for item in contracts}) == 34
    assert len(
        {
            (item["ea_id"], item.get("symbol"), item.get("timeframe"))
            for item in contracts
        }
    ) == 55
    assert issues == []


def test_density_fleet_has_28_honest_blocked_order_sleeves() -> None:
    density_ids = {
        20030,
        20031,
        20032,
        20033,
        20034,
        20037,
        20038,
        20039,
        20040,
        20041,
        20043,
        20044,
        20045,
    }
    contracts = [item for item in _contracts() if item["ea_id"] in density_ids]

    assert len(contracts) == 28
    assert {item["ea_id"] for item in contracts} == density_ids
    assert all(item["promotion"]["status"] == "BLOCKED" for item in contracts)
    assert all(item["card_binding"]["status"] == "DRAFT" for item in contracts)
    assert all(
        item["card_binding"]["execution_contract_status"] == "DRAFT"
        for item in contracts
    )
    assert not any(item["symbol"] == "XTIUSD.DWX" for item in contracts)

    eia = next(item for item in contracts if item["ea_id"] == 20030)
    signal_anchors = [
        dependency
        for dependency in eia["data_dependencies"]
        if dependency["type"] == "signal_anchor"
    ]
    assert signal_anchors == [
        {
            "dependency_id": "xti_release_bar_signal_anchor",
            "type": "signal_anchor",
            "qualification_status": "PASS",
            "required_for": ["SIGNAL_ONLY"],
            "block_reason": None,
            "symbol": "XTIUSD.DWX",
            "timeframe": "M5",
            "order_allowed": False,
            "source_ref": "SYNCHRONIZED_RELEASE_BAR_ONLY",
        }
    ]


def test_density_sp500_sleeves_require_explicit_full_requalification() -> None:
    density_ids = {
        20030,
        20031,
        20032,
        20033,
        20034,
        20037,
        20038,
        20039,
        20040,
        20041,
        20043,
        20044,
        20045,
    }
    contracts = [
        item
        for item in _contracts()
        if item["ea_id"] in density_ids and item["symbol"] == "SP500.DWX"
    ]

    assert len(contracts) == 7
    for contract in contracts:
        assert contract["symbol_routing"]["full_requalification_required"] is True
        assert contract["symbol_routing"]["qualification_status"] == "REQUAL_REQUIRED"
        assert (
            "sp500_dwx_to_sp500_alias_full_requalification_required"
            in contract["promotion"]["block_reasons"]
        )


def test_density_execution_contracts_are_source_and_runtime_binding_clean() -> None:
    density_ids = {
        20030,
        20031,
        20032,
        20033,
        20034,
        20037,
        20038,
        20039,
        20040,
        20041,
        20043,
        20044,
        20045,
    }
    _payload, contracts, issues = lint.lint_registry(
        REGISTRY,
        repo_root=ROOT,
        as_of=date(2026, 7, 23),
        ea_ids=density_ids,
    )

    assert len(contracts) == 28
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


def test_20009_ftmo_news_calendar_is_exact_and_evidence_bound() -> None:
    contracts = [item for item in _contracts() if item["ea_id"] == 20009]
    expected_hashes = {
        "SHARED_PRIMARY": "8e898ca1c4aed5fbc4cbe43fc176e8d8595c2e6f5f05c2984c2468527d4f5b0d",
        "SHARED_SECONDARY": "3cf4b7d881b62105b70e34cb8400caa6c393b85743cce8046085c680ae05f3d1",
        "QMDEV1_COMMON_PRIMARY": "8e898ca1c4aed5fbc4cbe43fc176e8d8595c2e6f5f05c2984c2468527d4f5b0d",
        "QMDEV1_COMMON_SECONDARY": "3cf4b7d881b62105b70e34cb8400caa6c393b85743cce8046085c680ae05f3d1",
    }
    expected_paths = {
        "SHARED_PRIMARY": "D:/QM/data/news_calendar/news_calendar_2015_2025.csv",
        "SHARED_SECONDARY": "D:/QM/data/news_calendar/forex_factory_calendar_clean.csv",
        "QMDEV1_COMMON_PRIMARY": "C:/Users/QMDev1/AppData/Roaming/MetaQuotes/Terminal/Common/Files/news_calendar_2015_2025.csv",
        "QMDEV1_COMMON_SECONDARY": "C:/Users/QMDev1/AppData/Roaming/MetaQuotes/Terminal/Common/Files/forex_factory_calendar_clean.csv",
    }
    calendar_codes = {
        "calendar_news_contract_invalid",
        "calendar_news_source_missing",
        "calendar_news_source_hash_mismatch",
        "calendar_news_coverage_mismatch",
        "calendar_news_expired",
        "calendar_news_copy_drift",
        "runtime_news_policy_mismatch",
    }

    assert len(contracts) == 4
    for contract in contracts:
        calendar = contract["calendar"]
        assert calendar["policy"] == "FTMO_PRE30_POST30_NEWS_FILES_FAIL_CLOSED"
        assert calendar["temporal_mode"] == "PRE30_POST30"
        assert calendar["compliance_profile"] == "FTMO"
        assert calendar["minimum_impact"] == "high"
        assert calendar["stale_max_hours"] == 336
        assert calendar["stale_behavior"] == "INIT_AND_ENTRY_FAIL_CLOSED"
        assert calendar["live_source"] == "NATIVE_MT5_CALENDAR"
        assert {item["role"]: item["sha256"] for item in calendar["sources"]} == expected_hashes
        assert {item["role"]: item["path"] for item in calendar["sources"]} == expected_paths
        assert {
            (item["coverage_start"], item["coverage_end"])
            for item in calendar["sources"]
        } == {("2015-01-01", "2026-07-24")}

        codes = {
            issue.code
            for issue in lint.lint_contract(
                contract, repo_root=ROOT, as_of=date(2026, 7, 19)
            )
        }
        assert codes.isdisjoint(calendar_codes)


def test_20009_ftmo_news_calendar_rejects_hash_drift() -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 20009))
    contract["calendar"]["sources"][0]["sha256"] = "0" * 64

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 19))
    }
    assert "calendar_news_source_hash_mismatch" in codes
    assert "calendar_news_copy_drift" in codes


def test_20009_ftmo_news_calendar_rejects_declared_coverage_drift() -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 20009))
    contract["calendar"]["sources"][0]["coverage_end"] = "2026-07-23"

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 19))
    }
    assert "calendar_news_coverage_mismatch" in codes


def test_20009_ftmo_news_calendar_expires_fail_closed() -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 20009))

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 25))
    }
    assert "calendar_news_expired" in codes


def test_20009_ftmo_news_calendar_rejects_missing_source(tmp_path: Path) -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 20009))
    contract["calendar"]["sources"][0]["path"] = str(tmp_path / "missing-news.csv")

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 19))
    }
    assert "calendar_news_source_missing" in codes


def test_20009_ftmo_news_calendar_rejects_non_fail_closed_stale_policy() -> None:
    contract = copy.deepcopy(next(item for item in _contracts() if item["ea_id"] == 20009))
    contract["calendar"]["stale_behavior"] = "NOT_APPLICABLE"

    codes = {
        issue.code
        for issue in lint.lint_contract(contract, repo_root=ROOT, as_of=date(2026, 7, 19))
    }
    assert "calendar_news_contract_invalid" in codes


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("temporal_mode", "PRE15_POST15"),
        ("compliance_profile", "DXZ"),
        ("minimum_impact", "medium"),
        ("stale_max_hours", 337),
        ("stale_behavior", "NOT_APPLICABLE"),
        ("live_source", "NEWS_FILES"),
    ],
)
def test_20009_ftmo_news_calendar_schema_rejects_weakened_policy(
    tmp_path: Path, field: str, value: object
) -> None:
    payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
    contract = next(item for item in payload["contracts"] if item["ea_id"] == 20009)
    contract["calendar"][field] = value
    invalid = tmp_path / "invalid_calendar_policy.json"
    invalid.write_text(json.dumps(payload), encoding="utf-8")

    assert not _schema_valid(invalid)


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
