#!/usr/bin/env python3
"""Preregistered WS30.DWX transport analysis for QM5_10834.

This adapter loads the NDX auditor into a private module namespace and applies a
fail-closed WS30 profile.  It deliberately does not import or validate any NDX
attempt receipt, launch state, native report or outcome.  ``freeze-data`` and
``pre`` remain read-only with respect to MT5/data stores and fail until the
preregistered DEV2 provision evidence and live-alias registry rows exist.
"""

from __future__ import annotations

import importlib.util
import json
import os
import re
import stat
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
BASE_TOOL_PATH = TOOL_PATH.with_name("audit_tv_nq_ict_ob.py")
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]

_BASE_SPEC = importlib.util.spec_from_file_location(
    "qm10834_ws30_private_base_audit", BASE_TOOL_PATH
)
if _BASE_SPEC is None or _BASE_SPEC.loader is None:  # pragma: no cover - import invariant
    raise RuntimeError(f"cannot load base auditor: {BASE_TOOL_PATH}")
B = importlib.util.module_from_spec(_BASE_SPEC)
sys.modules[_BASE_SPEC.name] = B
_BASE_SPEC.loader.exec_module(B)


ANALYSIS_ID = "QM5_10834_TV_NQ_ICT_OB_WS30_TRANSPORT_001"
RESEARCH_SYMBOL = "WS30.DWX"
PRIMARY_RUN_ROOT = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_NATIVE_ATTEMPT_001"
)
ALTERNATE_RUN_ROOT = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_INFRA_ALTERNATE_002"
)
CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "ws30_transport_analysis_contract_20260721.json"
)
EXPECTED_CONTRACT_SHA256 = (
    "694d91e193f2dc151129683b42f7fdbf81f0d0965b1b6c78ebf2d9d18bafe253"
)
BUILD_RECEIPT_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
)
EXPECTED_BUILD_RECEIPT_SHA256 = (
    "046845096bed048faa18fbf1852c0d0b748a6a3aca7f348eee1023ef25568ccd"
)
FUTURE_DATA_RECEIPT_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\data\WS30_DWX_201807_202512_DEV2_backtest_data_receipt.json"
)
PROVISION_ROOT = Path(
    r"D:\QM\reports\setup\tick-data-timezone\WS30.DWX_DEV2_TRANSPORT_001"
)
PROVISION_MANIFEST_PATH = PROVISION_ROOT / "provision_manifest.json"
PROVISION_RECEIPT_PATH = PROVISION_ROOT / "provision_receipt.json"
PROVISION_SOURCE_DATA_ROOT = Path(r"D:\QM\mt5\T1\Bases\Custom")
PROVISION_TARGET_DATA_ROOT = B.TERMINAL_DATA_ROOT
SLIPPAGE_CALIBRATION_PATH = (
    REPO_ROOT / "framework" / "calibrations" / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"
)
REQUIRED_WMI_FIX_COMMIT = "13e82258f5e7d514b50ed4c04787d8aa2e30eb5a"
REQUIRED_WMI_FIX_SUBJECT = "fix: tolerate metatester owner lookup exit races"
PRIMARY_AUTHORIZATION_SCOPE = (
    "QM5_10834_WS30_TRANSPORT_PRIMARY_001_4_CELLS_X_2_DUPLICATES_"
    "MODEL4_MAX_4_NATIVE_STARTS_PER_CELL"
)
ALTERNATE_AUTHORIZATION_SCOPE = (
    "QM5_10834_WS30_TRANSPORT_INFRA_ALTERNATE_002_4_CELLS_X_2_DUPLICATES_"
    "MODEL4_MAX_4_NATIVE_STARTS_PER_CELL"
)
PRIMARY_PRE_RECEIPT_PATH = PRIMARY_RUN_ROOT / "pre_receipt.json"
PRIMARY_AUTHORIZATION_PATH = PRIMARY_RUN_ROOT / "native_outcome_authorization.json"
PRIMARY_STATE_PATH = PRIMARY_RUN_ROOT / "launch_state.json"
PRIMARY_JOB_PATH = PRIMARY_RUN_ROOT / "launch_job.json"
PRIMARY_POST_RECEIPT_PATH = PRIMARY_RUN_ROOT / "post_receipt.json"
ALTERNATE_AUTHORIZATION_PATH = (
    ALTERNATE_RUN_ROOT / "native_outcome_authorization.json"
)
PRIMARY_CLAIM_PATH = (
    B.ALLOWED_RUN_ROOT
    / "claims"
    / f"{ANALYSIS_ID}_DEV2_NATIVE_ATTEMPT_001.json"
)
ALTERNATE_CLAIM_PATH = (
    B.ALLOWED_RUN_ROOT
    / "claims"
    / f"{ANALYSIS_ID}_DEV2_NATIVE_ATTEMPT_002.json"
)
NATIVE_LAUNCH_LOCK_PATH = (
    B.ALLOWED_RUN_ROOT / "claims" / f"{ANALYSIS_ID}_NATIVE_LAUNCH.lock"
)
EXPECTED_LIVE_ALIASES = {"DXZ_LIVE": "WS30", "FTMO_TRIAL": "US30.cash"}
RUNTIME_BINDING_ROLES = (
    "base_tool",
    "runner",
    "runner_child",
    "dev2_cleanup_helper",
    "dev2_machine_credential_probe",
    "dev2_machine_credential_helper",
    "runner_smoke",
    "dev2_lane_contract",
    "scheduled_task_helper",
)


# Save generic implementations before installing the private profile hooks.
_BASE_EXPECTED_BINDING_PATHS = B._expected_binding_paths
_BASE_PREFLIGHT = B.preflight
_BASE_ASSERT_PRE_RECEIPT = B.assert_pre_receipt
_BASE_EXECUTION_CONTRACT = B.execution_contract
_BASE_CLAIM_BASIS = B._native_attempt_claim_basis
_BASE_RESOLVE_COST_SCHEDULE = B.resolve_cost_schedule
_BASE_POSTFLIGHT = B.postflight


def _configure_private_profile() -> None:
    B.__doc__ = __doc__
    B.TOOL_PATH = TOOL_PATH
    B.ANALYSIS_ID = ANALYSIS_ID
    B.RESEARCH_SYMBOL = RESEARCH_SYMBOL
    B.SYMBOL_POLICY = {RESEARCH_SYMBOL: "FACTORY_DWX_RESEARCH_BACKTEST_SYMBOL"}
    B.EXPECTED_LIVE_ALIASES = dict(EXPECTED_LIVE_ALIASES)
    B.EXPECTED_MATRIX_IMPORT_PATH = "Custom/Indices/Index 1/WS30.DWX"
    B.EXPECTED_MAGIC_SLOT_OFFSET = "1"
    B.EXPECTED_COST_ALIAS_CHAIN = ("WS30",)
    B.EXPECTED_COST_LOOKUP_KEY = "WS30"
    B.EXPECTED_DXZ_RT_PER_LOT_USD = Decimal("0.70")
    B.EXPECTED_FTMO_RT_PER_LOT_USD = Decimal("0.00")
    B.EXPECTED_WORST_RT_PER_LOT_USD = Decimal("0.70")
    B.REBUILD_EVIDENCE_LABEL = "WS30 DEV2 provision"
    B.NDX_REBUILD_ROOT = PROVISION_ROOT
    B.NDX_REBUILD_DONE_PATH = PROVISION_RECEIPT_PATH
    B.NDX_REBUILD_SOURCE_PATH = PROVISION_MANIFEST_PATH
    B.DATA_RECEIPT_ARTIFACT_TYPE = "QM5_10834_WS30_BACKTEST_DATA_RECEIPT"
    B.INFRA_RETRY_CONTRACT_PATH = CONTRACT_PATH
    B.EXPECTED_INFRA_RETRY_CONTRACT_SHA256 = EXPECTED_CONTRACT_SHA256
    B.CURRENT_CLAIM_SEQUENCE = 1
    B.RESERVED_COUNTED_ALTERNATE_ATTEMPT_NUMBER = 2
    B.PRIOR_CLAIM_SEQUENCES = 0
    B.MAXIMUM_COUNTED_ALTERNATE_ATTEMPTS = 1
    B.PRIOR_COUNTED_ALTERNATE_ATTEMPTS = 0
    B.AUTHORIZATION_SCOPE = PRIMARY_AUTHORIZATION_SCOPE
    B.NATIVE_ATTEMPT_CLAIM_PATH = PRIMARY_CLAIM_PATH
    B.NATIVE_LAUNCH_LOCK_PATH = NATIVE_LAUNCH_LOCK_PATH
    B.DATA_FACTORY_EVIDENCE_ROLES = frozenset(
        set(B.DATA_FACTORY_EVIDENCE_ROLES) | {"slippage_calibration"}
    )
    B.REQUIRED_BINDING_ROLES = frozenset(
        set(B.REQUIRED_BINDING_ROLES) | {"base_tool", "slippage_calibration"}
    )


_configure_private_profile()


def _lexical_path(path: Path | str) -> Path:
    return Path(os.path.abspath(os.path.normpath(os.fspath(path))))


def _path_is_reparse(path: Path) -> bool:
    try:
        observed = os.lstat(path)
    except OSError:
        return False
    attributes = int(getattr(observed, "st_file_attributes", 0))
    reparse_flag = int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))
    return stat.S_ISLNK(observed.st_mode) or bool(attributes & reparse_flag)


def _assert_no_reparse_components(path: Path | str, label: str) -> Path:
    lexical = _lexical_path(path)
    components = list(reversed((lexical, *lexical.parents)))
    for component in components:
        if os.path.lexists(component) and _path_is_reparse(component):
            raise B.InvalidEvidence(f"{label} contains a reparse component: {component}")
    return lexical


def _assert_lexical_exact(candidate: Path | str, expected: Path | str, label: str) -> Path:
    candidate_lexical = _lexical_path(candidate)
    expected_lexical = _lexical_path(expected)
    if os.path.normcase(str(candidate_lexical)) != os.path.normcase(
        str(expected_lexical)
    ):
        raise B.InvalidEvidence(
            f"{label} must be lexically exact: {candidate_lexical} != {expected_lexical}"
        )
    _assert_no_reparse_components(candidate_lexical, label)
    return candidate_lexical


def _expected_data_files(
    symbol: str,
    terminal_data_root: Path,
) -> list[tuple[str, str, Path]]:
    B.enforce_symbol_policy(symbol)
    root = _assert_no_reparse_components(terminal_data_root, "WS30 terminal data root")
    history_root = _assert_no_reparse_components(
        root / "history" / symbol, "WS30 history root"
    )
    ticks_root = _assert_no_reparse_components(
        root / "ticks" / symbol, "WS30 ticks root"
    )
    result = [
        ("history", year, history_root / f"{year}.hcc")
        for year in B._required_history_years()
    ]
    result.extend(
        ("ticks", month, ticks_root / f"{month}.tkc")
        for month in B._required_tick_months()
    )
    for kind, period, path in result:
        _assert_no_reparse_components(path, f"WS30 {kind} file {period}")
    return result


def _factory_evidence_paths(
    overrides: Mapping[str, Path] | None = None,
) -> dict[str, Path]:
    paths = {
        "v5_framework": B.V5_FRAMEWORK_PATH,
        "backtest_rules": B.BACKTEST_RULES_PATH,
        "aliases": B.ALIASES_PATH,
        "matrix": B.MATRIX_PATH,
        "cost": B.COST_PATH,
        "rebuild_done": PROVISION_RECEIPT_PATH,
        "rebuild_source": PROVISION_MANIFEST_PATH,
        "slippage_calibration": SLIPPAGE_CALIBRATION_PATH,
    }
    if overrides is not None:
        if set(overrides) != B.DATA_FACTORY_EVIDENCE_ROLES:
            raise B.InvalidEvidence("WS30 Factory evidence-role closure drift")
        paths = {role: Path(path) for role, path in overrides.items()}
    return {
        role: _assert_no_reparse_components(path, f"WS30 Factory evidence {role}")
        for role, path in paths.items()
    }


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    paths = _BASE_EXPECTED_BINDING_PATHS(symbol)
    paths["base_tool"] = BASE_TOOL_PATH
    paths["slippage_calibration"] = SLIPPAGE_CALIBRATION_PATH
    return {
        role: _assert_no_reparse_components(path, f"WS30 PRE binding {role}")
        for role, path in paths.items()
    }


def _assert_primary_run_root(path: Path) -> Path:
    return _assert_lexical_exact(path, PRIMARY_RUN_ROOT, "WS30 primary run root")


def _assert_primary_control_namespace() -> None:
    for path, label in (
        (B.ALLOWED_RUN_ROOT, "WS30 analysis root"),
        (B.ALLOWED_RUN_ROOT / "claims", "WS30 claim root"),
        (PRIMARY_RUN_ROOT, "WS30 primary run root"),
        (PRIMARY_CLAIM_PATH, "WS30 primary claim path"),
        (NATIVE_LAUNCH_LOCK_PATH, "WS30 launch lock path"),
        (FUTURE_DATA_RECEIPT_PATH, "WS30 data receipt path"),
    ):
        _assert_no_reparse_components(path, label)


def _strict_created_utc(value: Any, label: str) -> datetime:
    parsed = B.parse_utc(str(value), label)
    if parsed > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence(f"{label} is implausibly in the future")
    return parsed


def validate_transport_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    binding = B.file_binding(path, EXPECTED_CONTRACT_SHA256)
    payload = B.load_json(path)
    expected_top = {
        "schema_version",
        "artifact_type",
        "status",
        "created_utc",
        "candidate",
        "windows",
        "frozen_inputs",
        "merit_contract",
        "cost_contract",
        "research_and_live_symbols",
        "data_contract",
        "runtime_contract",
        "attempt_budget",
        "outcome_fence",
        "classification",
    }
    if set(payload) != expected_top:
        raise B.InvalidEvidence("WS30 transport contract field closure drift")
    if (
        payload.get("schema_version") != 1
        or payload.get("artifact_type")
        != "QM5_10834_WS30_TRANSPORT_ANALYSIS_CONTRACT"
        or payload.get("status") != "PREREGISTERED_UNTOUCHED_EVIDENCE"
        or payload.get("classification")
        != "NEW_SYMBOL_TRANSPORT_ON_UNTOUCHED_WS30_DWX_EVIDENCE_NOT_NDX_RETRY"
    ):
        raise B.InvalidEvidence("WS30 transport contract identity/status drift")
    _strict_created_utc(payload.get("created_utc"), "WS30 contract created_utc")

    candidate = payload.get("candidate")
    if not isinstance(candidate, Mapping) or candidate != {
        "ea_id": "QM5_10834",
        "analysis_id": ANALYSIS_ID,
        "strategy": "tv-nq-ict-ob",
        "transport_from_symbol": "NDX.DWX",
        "research_symbol": RESEARCH_SYMBOL,
        "timeframe": "M5",
        "model": 4,
        "duplicates_per_cell": 2,
        "parameter_tuning_forbidden": True,
        "same_strategy_parameters_as_ndx_required": True,
        "same_merit_gates_as_ndx_required": True,
        "ndx_analysis_may_not_be_retried_or_reset": True,
        "ws30_evidence_must_not_reference_ndx_data_or_outcomes": True,
    }:
        raise B.InvalidEvidence("WS30 transport candidate/distinctness drift")
    expected_windows = [
        {
            "cell_id": row.cell_id,
            "cohort": row.cohort,
            "from_date": row.from_date.isoformat(),
            "to_date": row.to_date.isoformat(),
        }
        for row in B.WINDOWS
    ]
    if payload.get("windows") != expected_windows:
        raise B.InvalidEvidence("WS30 DEV/OOS window drift")

    frozen = payload.get("frozen_inputs")
    if not isinstance(frozen, Mapping) or (
        Path(str(frozen.get("build_receipt_path", ""))).resolve()
        != BUILD_RECEIPT_PATH.resolve()
        or frozen.get("build_receipt_sha256") != EXPECTED_BUILD_RECEIPT_SHA256
        or Path(str(frozen.get("set_path", ""))).resolve()
        != (EA_ROOT / "sets" / f"{B.EXPERT_NAME}_{RESEARCH_SYMBOL}_M5_backtest.set").resolve()
        or frozen.get("set_sha256")
        != "0f6979d7024aa9f5098deac1f04010876a86cf0363f1fd25ab21eb3ed066e3d6"
        or frozen.get("qm_ea_id") != "10834"
        or frozen.get("qm_magic_slot_offset") != "1"
        or frozen.get("RISK_FIXED") != "1000"
        or frozen.get("RISK_PERCENT") != "0"
        or frozen.get("strategy_entry_start_hhmm") != "945"
        or frozen.get("strategy_entry_end_hhmm") != "1015"
        or frozen.get("strategy_target_r") != "2.0"
        or frozen.get("InpQMSimCommissionPerLot") != "0"
    ):
        raise B.InvalidEvidence("WS30 frozen build/set/strategy input drift")

    merit = payload.get("merit_contract")
    if not isinstance(merit, Mapping) or merit != {
        "version": B.MERIT_CONTRACT_VERSION,
        "source": "audit_tv_nq_ict_ob.py:MERIT_GATES",
        "byte_for_byte_semantic_equality_required": True,
        "cli_overrides_forbidden": True,
    }:
        raise B.InvalidEvidence("WS30 merit-contract transport drift")

    cost = payload.get("cost_contract")
    center = cost.get("merit_center") if isinstance(cost, Mapping) else None
    overcost = cost.get("registry_overcost_stress") if isinstance(cost, Mapping) else None
    if (
        not isinstance(center, Mapping)
        or center.get("spread") != "EMBEDDED_IN_BOUND_WS30_DWX_REAL_TICKS"
        or center.get("dxz_commission_rt_per_lot_usd") != "0.70"
        or center.get("ftmo_index_commission_rt_per_lot_usd") != "0.00"
        or center.get("commission_used_for_merit_rt_per_lot_usd") != "0.70"
        or center.get("additional_slippage_points") != "0"
        or cost.get("slippage_stress_axis_points") != ["0", "1", "3"]
        or cost.get("slippage_source_is_auto_stub") is not True
        or cost.get("slippage_axis_is_supplemental_not_merit") is not True
        or not isinstance(overcost, Mapping)
        or overcost.get("commission_rt_per_lot_usd") != "5.50"
        or overcost.get("mode") != "ABSOLUTE_COMMISSION_RATE_NOT_ADDITIVE_TO_0_70"
        or overcost.get("supplemental_not_merit") is not True
        or cost.get("silent_merit_center_substitution_forbidden") is not True
    ):
        raise B.InvalidEvidence("WS30 cost/stress preregistration drift")

    symbols = payload.get("research_and_live_symbols")
    if not isinstance(symbols, Mapping) or (
        symbols.get("backtest_exact") != RESEARCH_SYMBOL
        or symbols.get("dwx_required_for_research_and_backtest") is not True
        or symbols.get("suffix_stripped_only_for_live_deploy") is not True
        or symbols.get("required_future_registry_rows") != EXPECTED_LIVE_ALIASES
        or symbols.get("pre_fails_until_both_registry_rows_are_committed") is not True
    ):
        raise B.InvalidEvidence("WS30 research/live alias contract drift")

    data = payload.get("data_contract")
    if not isinstance(data, Mapping) or (
        data.get("execution_terminal") != "DEV2"
        or data.get("history_file_count") != 8
        or data.get("tick_file_count") != 90
        or data.get("total_file_count") != 98
        or Path(str(data.get("future_data_receipt_path", ""))).resolve()
        != FUTURE_DATA_RECEIPT_PATH.resolve()
        or Path(str(data.get("future_provision_manifest_path", ""))).resolve()
        != PROVISION_MANIFEST_PATH.resolve()
        or Path(str(data.get("future_provision_receipt_path", ""))).resolve()
        != PROVISION_RECEIPT_PATH.resolve()
        or data.get("source_terminal_preregistered") != "T1"
        or data.get("provision_receipt_requires_exact_ordered_98_file_ledger")
        is not True
        or data.get("each_provision_file_row_binds_source_and_target_path_size_sha256")
        is not True
        or data.get("source_and_target_bytes_reasserted_before_freeze") is not True
        or data.get("freeze_data_only_after_dev2_provision_pass") is not True
        or data.get("freeze_data_starts_no_mt5_process") is not True
        or data.get("pre_provisions_or_copies_no_data") is not True
        or data.get("pre_fails_if_future_receipt_or_any_bound_file_is_missing") is not True
    ):
        raise B.InvalidEvidence("WS30 DEV2 data/provision contract drift")

    runtime = payload.get("runtime_contract")
    if not isinstance(runtime, Mapping) or (
        runtime.get("required_wmi_fix_commit") != REQUIRED_WMI_FIX_COMMIT
        or runtime.get("required_wmi_fix_subject") != REQUIRED_WMI_FIX_SUBJECT
        or runtime.get("required_commit_must_be_ancestor_of_pre_head") is not True
        or runtime.get("current_runtime_file_hashes_bound_dynamically_at_pre") is not True
        or runtime.get("bound_runtime_roles") != list(RUNTIME_BINDING_ROLES)
    ):
        raise B.InvalidEvidence("WS30 WMI/runtime preregistration drift")

    budget = payload.get("attempt_budget")
    if not isinstance(budget, Mapping) or (
        budget.get("execution_lane") != "DEV2"
        or budget.get("primary_attempt_number") != 1
        or budget.get("maximum_total_counted_attempts") != 2
        or budget.get("reserved_single_infrastructure_alternate_attempt_number") != 2
        or Path(str(budget.get("primary_run_root", ""))).resolve()
        != PRIMARY_RUN_ROOT.resolve()
        or Path(str(budget.get("alternate_run_root", ""))).resolve()
        != ALTERNATE_RUN_ROOT.resolve()
        or Path(str(budget.get("primary_claim_path", ""))).resolve()
        != PRIMARY_CLAIM_PATH.resolve()
        or Path(str(budget.get("alternate_claim_path", ""))).resolve()
        != ALTERNATE_CLAIM_PATH.resolve()
        or Path(str(budget.get("primary_authorization_path", ""))).resolve()
        != PRIMARY_AUTHORIZATION_PATH.resolve()
        or Path(str(budget.get("alternate_authorization_path", ""))).resolve()
        != ALTERNATE_AUTHORIZATION_PATH.resolve()
        or budget.get("primary_authorization_scope") != PRIMARY_AUTHORIZATION_SCOPE
        or budget.get("alternate_authorization_scope") != ALTERNATE_AUTHORIZATION_SCOPE
        or budget.get("claim_creation_alone_does_not_count") is not True
        or budget.get("counting_boundary") != B.ALTERNATE_ATTEMPT_COUNTING_BOUNDARY
        or budget.get("primary_claim_atomic_create_once") is not True
        or budget.get("alternate_claim_atomic_create_once") is not True
        or budget.get("terminal_hopping_forbidden") is not True
        or budget.get("parameter_or_gate_changes_between_attempts_forbidden") is not True
        or budget.get("alternate_requires_immutable_primary_invalid_infra_receipt") is not True
        or budget.get("alternate_requires_zero_native_report_files") is not True
        or budget.get("alternate_requires_strategy_outcomes_read_false") is not True
        or budget.get("alternate_requires_strategy_merit_adjudicated_false") is not True
        or budget.get("alternate_allowed_cause_classes")
        != [
            "DEV2_CONTROLLER_FAILED_BEFORE_NATIVE_REPORT",
            "DEV2_SCHEDULED_WORKER_FAILED_BEFORE_NATIVE_REPORT",
            "DEV2_DATA_STORE_FAILED_BEFORE_NATIVE_REPORT",
        ]
        or budget.get("retrospective_cause_exemptions_forbidden") is not True
        or budget.get("further_attempts_forbidden") is not True
    ):
        raise B.InvalidEvidence("WS30 primary/alternate attempt budget drift")

    fence = payload.get("outcome_fence")
    if not isinstance(fence, Mapping) or (
        fence.get("pre_reads_native_reports") is not False
        or fence.get("pre_reads_strategy_outcomes") is not False
        or fence.get("freeze_data_reads_native_reports") is not False
        or fence.get("worker_parses_native_reports") is not False
        or fence.get("worker_seals_opaque_artifacts_only") is not True
        or fence.get("post_requires_complete_launch_state") is not True
        or fence.get("model4_required_twice_per_cell") is not True
        or fence.get("duplicate_deal_sequence_must_match_exactly") is not True
        or fence.get("active_run_reports_may_not_be_read_before_fenced_post") is not True
    ):
        raise B.InvalidEvidence("WS30 outcome-fence drift")
    B.assert_binding(binding, "stable WS30 transport contract")
    return payload


def validate_infra_retry_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    """Base-auditor compatibility hook for the new transport/attempt contract."""
    return validate_transport_contract(path)


def validate_data_provision_contract(
    symbol: str,
    receipt_path: Path,
    manifest_path: Path,
) -> dict[str, Any]:
    if symbol != RESEARCH_SYMBOL:
        raise B.InvalidEvidence("WS30 provision symbol drift")
    _assert_lexical_exact(
        receipt_path, PROVISION_RECEIPT_PATH, "WS30 provision receipt path"
    )
    _assert_lexical_exact(
        manifest_path, PROVISION_MANIFEST_PATH, "WS30 provision manifest path"
    )
    _assert_no_reparse_components(
        PROVISION_SOURCE_DATA_ROOT, "WS30 provision source data root"
    )
    _assert_no_reparse_components(
        PROVISION_TARGET_DATA_ROOT, "WS30 provision target data root"
    )
    manifest_binding = B.stable_file_binding(manifest_path)
    manifest = B.load_json(manifest_path)
    expected_manifest_keys = {
        "schema_version",
        "artifact_type",
        "created_utc",
        "symbol",
        "source_terminal",
        "source_data_root",
        "target_terminal",
        "target_data_root",
        "coverage",
        "expected_history_files",
        "expected_tick_files",
        "expected_total_files",
        "operation",
        "outcome_fence",
    }
    if set(manifest) != expected_manifest_keys:
        raise B.InvalidEvidence("WS30 provision manifest field closure drift")
    manifest_created = _strict_created_utc(
        manifest.get("created_utc"), "WS30 provision manifest created_utc"
    )
    expected_coverage = B._data_coverage_contract()
    if (
        manifest.get("schema_version") != 1
        or manifest.get("artifact_type") != "QM5_10834_WS30_DEV2_PROVISION_MANIFEST"
        or manifest.get("symbol") != RESEARCH_SYMBOL
        or manifest.get("source_terminal") != "T1"
        or os.path.normcase(
            str(_lexical_path(str(manifest.get("source_data_root", ""))))
        )
        != os.path.normcase(str(_lexical_path(PROVISION_SOURCE_DATA_ROOT)))
        or manifest.get("target_terminal") != "DEV2"
        or os.path.normcase(
            str(_lexical_path(str(manifest.get("target_data_root", ""))))
        )
        != os.path.normcase(str(_lexical_path(PROVISION_TARGET_DATA_ROOT)))
        or manifest.get("coverage") != expected_coverage
        or manifest.get("expected_history_files") != 8
        or manifest.get("expected_tick_files") != 90
        or manifest.get("expected_total_files") != 98
        or manifest.get("operation") != "BYTE_EXACT_OFFLINE_FILE_TRANSPORT"
        or manifest.get("outcome_fence")
        != {
            "mt5_terminal_started": False,
            "metatester_started": False,
            "native_reports_opened": False,
            "strategy_outcomes_read": False,
        }
    ):
        raise B.InvalidEvidence("WS30 provision manifest semantic drift")

    receipt_binding = B.stable_file_binding(receipt_path)
    receipt = B.load_json(receipt_path)
    expected_receipt_keys = {
        "schema_version",
        "artifact_type",
        "status",
        "completed_utc",
        "manifest",
        "symbol",
        "source_terminal",
        "target_terminal",
        "target_data_root",
        "history_files",
        "tick_files",
        "file_count",
        "files",
        "source_file_set_sha256",
        "target_file_set_sha256",
        "source_target_sha256_equal",
        "outcome_fence",
    }
    if set(receipt) != expected_receipt_keys:
        raise B.InvalidEvidence("WS30 provision receipt field closure drift")
    completed = _strict_created_utc(
        receipt.get("completed_utc"), "WS30 provision receipt completed_utc"
    )
    if (
        receipt.get("schema_version") != 1
        or receipt.get("artifact_type") != "QM5_10834_WS30_DEV2_PROVISION_RECEIPT"
        or receipt.get("status") != "PASS"
        or receipt.get("manifest") != manifest_binding
        or receipt.get("symbol") != RESEARCH_SYMBOL
        or receipt.get("source_terminal") != "T1"
        or receipt.get("target_terminal") != "DEV2"
        or os.path.normcase(
            str(_lexical_path(str(receipt.get("target_data_root", ""))))
        )
        != os.path.normcase(str(_lexical_path(PROVISION_TARGET_DATA_ROOT)))
        or receipt.get("history_files") != 8
        or receipt.get("tick_files") != 90
        or receipt.get("file_count") != 98
        or receipt.get("source_target_sha256_equal") is not True
        or receipt.get("outcome_fence")
        != {
            "mt5_terminal_started": False,
            "metatester_started": False,
            "native_reports_opened": False,
            "strategy_outcomes_read": False,
        }
        or completed < manifest_created
    ):
        raise B.InvalidEvidence("WS30 provision receipt semantic drift")

    rows = receipt.get("files")
    source_files = B._expected_data_files(
        RESEARCH_SYMBOL, PROVISION_SOURCE_DATA_ROOT
    )
    target_files = B._expected_data_files(
        RESEARCH_SYMBOL, PROVISION_TARGET_DATA_ROOT
    )
    if not isinstance(rows, list) or len(rows) != 98:
        raise B.InvalidEvidence("WS30 provision receipt must bind exactly 98 files")
    all_bindings: list[tuple[Mapping[str, Any], str]] = []
    file_set_basis: list[dict[str, Any]] = []
    path_identities_before: dict[Path, tuple[int, int, int, int]] = {}
    for index, (row, source_expected, target_expected) in enumerate(
        zip(rows, source_files, target_files)
    ):
        source_kind, source_period, source_path = source_expected
        target_kind, target_period, target_path = target_expected
        if source_kind != target_kind or source_period != target_period:
            raise B.InvalidEvidence("WS30 source/target expected-file order drift")
        if not isinstance(row, Mapping) or set(row) != {
            "kind",
            "period",
            "source",
            "target",
        }:
            raise B.InvalidEvidence(f"WS30 provision file[{index}] field closure drift")
        source_binding = row.get("source")
        target_binding = row.get("target")
        if (
            row.get("kind") != source_kind
            or row.get("period") != source_period
            or not isinstance(source_binding, Mapping)
            or set(source_binding) != {"path", "size", "sha256"}
            or not isinstance(target_binding, Mapping)
            or set(target_binding) != {"path", "size", "sha256"}
            or os.path.normcase(
                str(_lexical_path(str(source_binding.get("path", ""))))
            )
            != os.path.normcase(str(_lexical_path(source_path)))
            or os.path.normcase(
                str(_lexical_path(str(target_binding.get("path", ""))))
            )
            != os.path.normcase(str(_lexical_path(target_path)))
            or source_binding.get("size") != target_binding.get("size")
            or source_binding.get("sha256") != target_binding.get("sha256")
        ):
            raise B.InvalidEvidence(
                f"WS30 provision source/target byte binding drift at index {index}"
            )
        source_lexical = _assert_no_reparse_components(
            str(source_binding["path"]), f"WS30 provision source[{index}]"
        )
        target_lexical = _assert_no_reparse_components(
            str(target_binding["path"]), f"WS30 provision target[{index}]"
        )
        try:
            same_file = os.path.samefile(source_lexical, target_lexical)
        except OSError as exc:
            raise B.InvalidEvidence(
                f"cannot compare WS30 provision source/target identity[{index}]"
            ) from exc
        if same_file:
            raise B.InvalidEvidence(
                f"WS30 provision source/target are the same file[{index}]"
            )
        for binding, label in (
            (source_binding, f"WS30 provision source[{index}]"),
            (target_binding, f"WS30 provision target[{index}]"),
        ):
            path = Path(str(binding["path"])).resolve()
            try:
                stat = path.stat()
            except OSError as exc:
                raise B.InvalidEvidence(f"missing WS30 provision file: {path}") from exc
            path_identities_before[path] = (
                stat.st_dev,
                stat.st_ino,
                stat.st_size,
                stat.st_mtime_ns,
            )
            all_bindings.append((binding, label))
        source_identity = path_identities_before[source_lexical]
        target_identity = path_identities_before[target_lexical]
        if source_identity[:2] == target_identity[:2]:
            raise B.InvalidEvidence(
                f"WS30 provision source/target share filesystem identity[{index}]"
            )
        file_set_basis.append(
            {
                "kind": source_kind,
                "period": source_period,
                "size": source_binding["size"],
                "sha256": source_binding["sha256"],
            }
        )
    expected_file_set_sha256 = B.canonical_sha256(file_set_basis)
    if (
        receipt.get("source_file_set_sha256") != expected_file_set_sha256
        or receipt.get("target_file_set_sha256") != expected_file_set_sha256
    ):
        raise B.InvalidEvidence("WS30 provision aggregate file-set hash drift")
    for binding, label in all_bindings:
        B.assert_stable_binding(binding, label)
    for path, identity_before in path_identities_before.items():
        try:
            stat = path.stat()
        except OSError as exc:
            raise B.InvalidEvidence(f"WS30 provision file disappeared: {path}") from exc
        identity_after = (
            stat.st_dev,
            stat.st_ino,
            stat.st_size,
            stat.st_mtime_ns,
        )
        if identity_after != identity_before:
            raise B.InvalidEvidence(
                f"WS30 provision corpus changed during validation: {path}"
            )
    B.assert_stable_binding(manifest_binding, "stable WS30 provision manifest")
    B.assert_stable_binding(receipt_binding, "stable WS30 provision receipt")
    return {
        "status": "PASS",
        "mode": "BYTE_EXACT_OFFLINE_FILE_TRANSPORT",
        "target": RESEARCH_SYMBOL,
        "source_terminal": "T1",
        "target_terminal": "DEV2",
        "history_files": 8,
        "tick_files": 90,
        "files": 98,
        "source_file_set_sha256": expected_file_set_sha256,
        "target_file_set_sha256": expected_file_set_sha256,
        "source_target_sha256_equal": True,
        "manifest": manifest_binding,
        "receipt": receipt_binding,
        "mt5_terminal_started": False,
        "metatester_started": False,
    }


def _load_slippage_stress_contract(path: Path | None = None) -> dict[str, Any]:
    path = (path or SLIPPAGE_CALIBRATION_PATH).resolve()
    payload = B.load_json(path)
    symbols = payload.get("symbols")
    row = symbols.get(RESEARCH_SYMBOL) if isinstance(symbols, Mapping) else None
    slippage = row.get("slippage_points") if isinstance(row, Mapping) else None
    if (
        not isinstance(row, Mapping)
        or row.get("auto_stub") is not True
        or not isinstance(slippage, Mapping)
        or B._strict_decimal(slippage.get("avg"), "WS30 slippage avg") != Decimal("1")
        or B._strict_decimal(slippage.get("p95"), "WS30 slippage p95") != Decimal("3")
    ):
        raise B.InvalidEvidence("WS30 supplemental slippage calibration drift")
    return {
        "source": B.file_binding(path),
        "source_quality": "AUTO_STUB_STRESS_ONLY_NOT_MERIT",
        "points_axis": ["0", "1", "3"],
        "merit_center_points": "0",
    }


def resolve_cost_schedule(path: Path, symbol: str) -> dict[str, Any]:
    schedule = _BASE_RESOLVE_COST_SCHEDULE(path, symbol)
    schedule["merit_center"] = {
        "commission_rt_per_lot_usd": "0.7",
        "additional_slippage_points": "0",
        "spread": "EMBEDDED_IN_BOUND_REAL_TICKS",
    }
    schedule["supplemental_stress"] = {
        "slippage": _load_slippage_stress_contract(),
        "registry_overcost": {
            "absolute_commission_rt_per_lot_usd": "5.5",
            "not_additive_to_merit_center": True,
            "merit_gate_effect": "NONE",
        },
    }
    return schedule


def _git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *args],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if check and completed.returncode != 0:
        raise B.InvalidEvidence(f"git provenance query failed: {' '.join(args)}")
    return completed


def runtime_provenance(bindings: Mapping[str, Any]) -> dict[str, Any]:
    subject = _git("show", "-s", "--format=%s", REQUIRED_WMI_FIX_COMMIT).stdout.strip()
    if subject != REQUIRED_WMI_FIX_SUBJECT:
        raise B.InvalidEvidence("required WMI-fix commit subject drift")
    pre_head = _git("rev-parse", "HEAD^{commit}").stdout.strip().lower()
    if not re.fullmatch(r"[0-9a-f]{40}", pre_head):
        raise B.InvalidEvidence("PRE HEAD commit identity is malformed")
    ancestor = _git(
        "merge-base", "--is-ancestor", REQUIRED_WMI_FIX_COMMIT, pre_head, check=False
    )
    if ancestor.returncode != 0:
        raise B.InvalidEvidence("required WMI-fix commit is not an ancestor of PRE HEAD")
    runtime_bindings: dict[str, Any] = {}
    for role in RUNTIME_BINDING_ROLES:
        item = bindings.get(role)
        if not isinstance(item, Mapping):
            raise B.InvalidEvidence(f"PRE runtime binding missing: {role}")
        _assert_no_reparse_components(
            str(item.get("path", "")), f"PRE runtime {role}"
        )
        B.assert_binding(item, f"PRE runtime {role}")
        runtime_bindings[role] = dict(item)
    return {
        "required_wmi_fix_commit": REQUIRED_WMI_FIX_COMMIT,
        "required_wmi_fix_subject": REQUIRED_WMI_FIX_SUBJECT,
        "required_fix_is_ancestor_of_pre_head": True,
        "pre_head_commit": pre_head,
        "runtime_bindings": runtime_bindings,
    }


def validate_runtime_provenance(
    provenance: Mapping[str, Any], bindings: Mapping[str, Any]
) -> None:
    if set(provenance) != {
        "required_wmi_fix_commit",
        "required_wmi_fix_subject",
        "required_fix_is_ancestor_of_pre_head",
        "pre_head_commit",
        "runtime_bindings",
    }:
        raise B.InvalidEvidence("PRE runtime provenance field closure drift")
    pre_head = str(provenance.get("pre_head_commit", "")).lower()
    if (
        provenance.get("required_wmi_fix_commit") != REQUIRED_WMI_FIX_COMMIT
        or provenance.get("required_wmi_fix_subject") != REQUIRED_WMI_FIX_SUBJECT
        or provenance.get("required_fix_is_ancestor_of_pre_head") is not True
        or not re.fullmatch(r"[0-9a-f]{40}", pre_head)
    ):
        raise B.InvalidEvidence("PRE WMI-fix provenance drift")
    subject = _git("show", "-s", "--format=%s", REQUIRED_WMI_FIX_COMMIT).stdout.strip()
    if subject != REQUIRED_WMI_FIX_SUBJECT:
        raise B.InvalidEvidence("required WMI-fix commit no longer resolves exactly")
    if _git("cat-file", "-e", f"{pre_head}^{{commit}}", check=False).returncode != 0:
        raise B.InvalidEvidence("PRE-bound HEAD commit no longer resolves")
    if (
        _git(
            "merge-base", "--is-ancestor", REQUIRED_WMI_FIX_COMMIT, pre_head, check=False
        ).returncode
        != 0
    ):
        raise B.InvalidEvidence("PRE-bound HEAD lacks the required WMI fix")
    current_head = _git("rev-parse", "HEAD^{commit}").stdout.strip().lower()
    if (
        _git(
            "merge-base",
            "--is-ancestor",
            REQUIRED_WMI_FIX_COMMIT,
            current_head,
            check=False,
        ).returncode
        != 0
    ):
        raise B.InvalidEvidence("current HEAD lacks the required WMI fix")
    observed_bindings = provenance.get("runtime_bindings")
    expected_bindings = {
        role: dict(bindings[role]) for role in RUNTIME_BINDING_ROLES
    }
    if observed_bindings != expected_bindings:
        raise B.InvalidEvidence("PRE current-runtime hash binding drift")
    for role, binding in expected_bindings.items():
        B.assert_binding(binding, f"PRE current-runtime {role}")


def preflight(
    symbol: str,
    data_receipt_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    _assert_primary_control_namespace()
    validate_transport_contract()
    _assert_lexical_exact(
        data_receipt_path, FUTURE_DATA_RECEIPT_PATH, "WS30 PRE data receipt"
    )
    _assert_lexical_exact(
        build_receipt_path, BUILD_RECEIPT_PATH, "WS30 PRE build receipt"
    )
    B.file_binding(build_receipt_path, EXPECTED_BUILD_RECEIPT_SHA256)
    _assert_primary_run_root(run_root)
    payload = _BASE_PREFLIGHT(
        symbol,
        data_receipt_path,
        build_receipt_path,
        run_root,
    )
    payload["runtime_provenance"] = runtime_provenance(payload["bindings"])
    payload["transport_distinctness"] = {
        "classification": "NEW_SYMBOL_TRANSPORT_NOT_NDX_RETRY",
        "research_symbol": RESEARCH_SYMBOL,
        "ndx_data_receipt_reused": False,
        "ndx_native_report_read": False,
        "ndx_strategy_outcome_read": False,
        "parameters_tuned_for_ws30": False,
    }
    return payload


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _assert_primary_control_namespace()
    _assert_lexical_exact(path, PRIMARY_PRE_RECEIPT_PATH, "WS30 PRE receipt")
    pre = _BASE_ASSERT_PRE_RECEIPT(path, expected_sha256)
    _assert_lexical_exact(
        str(pre.get("run_root", "")), PRIMARY_RUN_ROOT, "WS30 PRE run root identity"
    )
    _assert_lexical_exact(
        str(pre.get("build_receipt", {}).get("path", "")),
        BUILD_RECEIPT_PATH,
        "WS30 PRE build receipt identity",
    )
    _assert_lexical_exact(
        str(pre.get("backtest_data_receipt", {}).get("path", "")),
        FUTURE_DATA_RECEIPT_PATH,
        "WS30 PRE data receipt identity",
    )
    expected_distinctness = {
        "classification": "NEW_SYMBOL_TRANSPORT_NOT_NDX_RETRY",
        "research_symbol": RESEARCH_SYMBOL,
        "ndx_data_receipt_reused": False,
        "ndx_native_report_read": False,
        "ndx_strategy_outcome_read": False,
        "parameters_tuned_for_ws30": False,
    }
    if pre.get("transport_distinctness") != expected_distinctness:
        raise B.InvalidEvidence("WS30 PRE transport-distinctness drift")
    provenance = pre.get("runtime_provenance")
    bindings = pre.get("bindings")
    if not isinstance(provenance, Mapping) or not isinstance(bindings, Mapping):
        raise B.InvalidEvidence("WS30 PRE runtime provenance missing")
    validate_runtime_provenance(provenance, bindings)
    return pre


def execution_contract() -> dict[str, Any]:
    contract = _BASE_EXECUTION_CONTRACT()
    contract["native_attempt_claim_mode"] = (
        "ATOMIC_CREATE_ONCE_FOR_WS30_PRIMARY_ATTEMPT_001_AFTER_SAME_WORKER_PRECLAIM_PROBE"
    )
    contract["current_attempt_type"] = "PRIMARY_ONE_SHOT"
    contract["maximum_total_counted_attempts"] = 2
    contract["reserved_single_infrastructure_alternate_attempt_number"] = 2
    contract["reserved_infrastructure_alternate_run_root"] = str(
        ALTERNATE_RUN_ROOT.resolve()
    )
    contract["reserved_infrastructure_alternate_claim_path"] = str(
        ALTERNATE_CLAIM_PATH.resolve()
    )
    contract["reserved_infrastructure_alternate_authorization_scope"] = (
        ALTERNATE_AUTHORIZATION_SCOPE
    )
    contract["retrospective_infrastructure_exemptions_forbidden"] = True
    contract["attempt_budget_contract"] = B.file_binding(
        CONTRACT_PATH, EXPECTED_CONTRACT_SHA256
    )
    return contract


def _assert_native_attempt_unclaimed(stage: str) -> None:
    _assert_primary_control_namespace()
    if PRIMARY_CLAIM_PATH.exists():
        raise B.AuthorizationError(
            f"WS30 primary native attempt 001 is already claimed at {stage}"
        )


def _native_attempt_claim_basis(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    state_path: Path,
    authorization: Mapping[str, Any],
    preclaim_probe: Mapping[str, Any],
) -> dict[str, Any]:
    basis = _BASE_CLAIM_BASIS(
        pre_path,
        pre_sha256,
        pre,
        state_path,
        authorization,
        preclaim_probe,
    )
    basis["classification"] = (
        "ATOMIC_GLOBAL_OUTCOME_BLIND_WS30_PRIMARY_NATIVE_ATTEMPT_001"
    )
    basis["maximum_total_counted_attempts"] = 2
    basis["reserved_infrastructure_alternate_attempt_number"] = 2
    basis["reserved_infrastructure_alternate_claim_path"] = str(
        ALTERNATE_CLAIM_PATH.resolve()
    )
    return basis


def _stress_metrics(values: Sequence[Decimal]) -> dict[str, Any]:
    gross_profit = sum((max(value, Decimal("0")) for value in values), Decimal("0"))
    gross_loss = sum((min(value, Decimal("0")) for value in values), Decimal("0"))
    net = sum(values, Decimal("0"))
    if gross_loss < 0:
        pf = B._decimal_text(gross_profit / -gross_loss)
        state = "FINITE"
    elif gross_profit > 0:
        pf = None
        state = "INFINITE_NO_LOSSES"
    else:
        pf = None
        state = "UNDEFINED"
    return {
        "trades": len(values),
        "net_usd": B._money_text(net),
        "gross_profit_usd": B._money_text(gross_profit),
        "gross_loss_usd": B._money_text(gross_loss),
        "profit_factor": pf,
        "profit_factor_state": state,
    }


def _supplemental_stress(post: Mapping[str, Any]) -> dict[str, Any]:
    by_cell: dict[str, Any] = {}
    pooled: list[Decimal] = []
    cells = post.get("cells")
    if not isinstance(cells, list):
        raise B.InvalidEvidence("WS30 POST cells missing for supplemental stress")
    for cell in cells:
        if not isinstance(cell, Mapping) or not isinstance(cell.get("runs"), list):
            raise B.InvalidEvidence("WS30 POST run ledger missing for supplemental stress")
        runs = cell["runs"]
        if len(runs) != B.DUPLICATES:
            raise B.InvalidEvidence("WS30 supplemental stress requires exactly two duplicates")
        ledgers: list[list[Mapping[str, Any]]] = []
        for run in runs:
            cost_ledger = run.get("cost_ledger") if isinstance(run, Mapping) else None
            trades = cost_ledger.get("trades") if isinstance(cost_ledger, Mapping) else None
            if not isinstance(trades, list) or any(not isinstance(row, Mapping) for row in trades):
                raise B.InvalidEvidence("WS30 supplemental stress trade ledger malformed")
            ledgers.append(trades)
        signatures = [
            [
                (
                    row.get("entry_deal"),
                    row.get("exit_deals"),
                    row.get("volume"),
                    row.get("native_net_usd"),
                )
                for row in ledger
            ]
            for ledger in ledgers
        ]
        if signatures[0] != signatures[1]:
            raise B.InvalidEvidence("WS30 duplicate ledger drift in supplemental stress")
        stressed = [
            B._money(
                B._strict_decimal(row["native_net_usd"], "stress native net")
                - Decimal("5.50")
                * B._strict_decimal(row["volume"], "stress volume")
            )
            for row in ledgers[0]
        ]
        pooled.extend(stressed)
        by_cell[str(cell.get("cell_id", ""))] = _stress_metrics(stressed)
    return {
        "merit_center_unchanged": True,
        "merit_center_commission_rt_per_lot_usd": "0.70",
        "registry_overcost_absolute_commission_rt_per_lot_usd": "5.50",
        "registry_overcost_is_not_additive_to_merit_center": True,
        "registry_overcost_metrics_by_cell": by_cell,
        "registry_overcost_metrics_pooled": _stress_metrics(pooled),
        "slippage_points_axis": {
            "levels": ["0", "1", "3"],
            "source_quality": "AUTO_STUB_STRESS_ONLY_NOT_MERIT",
            "merit_gate_effect": "NONE",
            "usd_repricing_status": "NOT_COMPUTED_WITHOUT_BOUND_EXACT_USD_PER_POINT",
        },
    }


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    payload = _BASE_POSTFLIGHT(pre_path, pre_sha256, state_path)
    payload["supplemental_stress"] = _supplemental_stress(payload)
    return payload


# Install hooks only in the private base namespace used by this adapter.
B._factory_evidence_paths = _factory_evidence_paths
B._expected_data_files = _expected_data_files
B._expected_binding_paths = _expected_binding_paths
B._assert_run_root = _assert_primary_run_root
B.validate_infra_retry_contract = validate_infra_retry_contract
B.validate_data_provision_contract = validate_data_provision_contract
B.resolve_cost_schedule = resolve_cost_schedule
B.preflight = preflight
B.assert_pre_receipt = assert_pre_receipt
B.execution_contract = execution_contract
B._assert_native_attempt_unclaimed = _assert_native_attempt_unclaimed
B._native_attempt_claim_basis = _native_attempt_claim_basis
B.postflight = postflight


def _assert_cli_path_confinement(args: Any) -> None:
    if args.command == "freeze-data":
        if args.symbol != RESEARCH_SYMBOL:
            raise B.InvalidEvidence(
                f"WS30 freeze symbol must be exactly {RESEARCH_SYMBOL}"
            )
        _assert_lexical_exact(
            args.receipt, FUTURE_DATA_RECEIPT_PATH, "WS30 freeze receipt"
        )
        return
    if args.command == "pre":
        _assert_lexical_exact(
            args.receipt, PRIMARY_PRE_RECEIPT_PATH, "WS30 PRE receipt"
        )
        return
    if args.command == "launch":
        _assert_lexical_exact(
            args.pre_receipt, PRIMARY_PRE_RECEIPT_PATH, "WS30 launch PRE path"
        )
        _assert_lexical_exact(
            args.authorization,
            PRIMARY_AUTHORIZATION_PATH,
            "WS30 launch authorization path",
        )
        _assert_lexical_exact(args.state, PRIMARY_STATE_PATH, "WS30 launch state path")
        return
    if args.command == "post":
        _assert_lexical_exact(
            args.pre_receipt, PRIMARY_PRE_RECEIPT_PATH, "WS30 POST PRE path"
        )
        _assert_lexical_exact(args.state, PRIMARY_STATE_PATH, "WS30 POST state path")
        _assert_lexical_exact(
            args.receipt, PRIMARY_POST_RECEIPT_PATH, "WS30 POST receipt path"
        )
        return
    if args.command == "status":
        _assert_lexical_exact(args.state, PRIMARY_STATE_PATH, "WS30 status state path")
        return
    if args.command == "_run-plan":
        _assert_lexical_exact(args.job, PRIMARY_JOB_PATH, "WS30 worker job path")


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    args = B.build_parser().parse_args(arguments)
    try:
        # Constrain every caller-controlled path before the inherited auditor can
        # open it.  This prevents a WS30 invocation from even inspecting an NDX
        # PRE/state/job/report namespace.
        _assert_primary_control_namespace()
        _assert_cli_path_confinement(args)
        if args.command == "status":
            state = B.load_json(args.state)
            if (
                state.get("analysis_id") != ANALYSIS_ID
                or state.get("artifact_type") != "QM5_10834_NATIVE_LAUNCH_STATE"
            ):
                raise B.InvalidEvidence("WS30 status state identity drift")
            print(
                json.dumps(
                    {
                        "status": state.get("status"),
                        "worker_pid": state.get("worker_pid"),
                        "cells": [
                            {
                                "cell_id": row.get("cell_id"),
                                "status": row.get("status"),
                            }
                            for row in state.get("cells", [])
                            if isinstance(row, Mapping)
                        ],
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        if args.command not in {"freeze-data", "pre"}:
            return B.main(arguments)
        if args.command == "freeze-data":
            payload = B.freeze_backtest_data(args.symbol)
            digest = B.atomic_json(args.receipt, payload, replace=False)
            output = {
                "status": "PASS",
                "receipt": str(args.receipt.resolve()),
                "sha256": digest,
                "symbol": payload["symbol"],
                "files": payload["totals"]["files"],
                "bytes": payload["totals"]["bytes"],
            }
        else:
            payload = preflight(
                args.symbol,
                args.data_receipt,
                args.build_receipt,
                args.run_root,
            )
            digest = B.atomic_json(args.receipt, payload, replace=False)
            output = {
                "status": "PASS",
                "receipt": str(args.receipt.resolve()),
                "sha256": digest,
            }
        print(json.dumps(output, indent=2, sort_keys=True))
        return 0
    except (
        B.AuditError,
        OSError,
        subprocess.SubprocessError,
        ValueError,
        KeyError,
        TypeError,
    ) as exc:
        # Readiness failures are stderr-only.  In particular, never consume the
        # canonical one-shot receipt path with an INVALID placeholder before the
        # provision/alias prerequisites exist.
        print(
            json.dumps(
                B.invalid_receipt(args.command.upper(), exc),
                indent=2,
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
