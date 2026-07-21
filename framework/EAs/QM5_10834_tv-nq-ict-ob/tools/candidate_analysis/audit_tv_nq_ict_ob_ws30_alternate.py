#!/usr/bin/env python3
"""Reserved one-shot WS30.DWX infrastructure alternate for QM5_10834.

This adapter may only run from the fixed detached runtime worktree.  It
revalidates the opaque, outcome-blind closure of primary attempt 001 and uses a
separate PRE, authorization, claim, state, job, and POST namespace for the
preregistered alternate attempt 002.  Primary controller stderr and native
reports are never opened by this module.
"""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


# Importing the private primary adapter and its base auditor must not create an
# untracked __pycache__ in the immutable detached runtime worktree.
sys.dont_write_bytecode = True

TOOL_PATH = Path(__file__).resolve()
PRIMARY_ADAPTER_PATH = TOOL_PATH.with_name("audit_tv_nq_ict_ob_ws30.py")
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]

_PRIMARY_SPEC = importlib.util.spec_from_file_location(
    "qm10834_ws30_alternate_private_primary", PRIMARY_ADAPTER_PATH
)
if _PRIMARY_SPEC is None or _PRIMARY_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load primary WS30 adapter: {PRIMARY_ADAPTER_PATH}")
W = importlib.util.module_from_spec(_PRIMARY_SPEC)
sys.modules[_PRIMARY_SPEC.name] = W
_PRIMARY_SPEC.loader.exec_module(W)
B = W.B


ANALYSIS_ID = W.ANALYSIS_ID
RESEARCH_SYMBOL = W.RESEARCH_SYMBOL
MAIN_WORKTREE_ROOT = Path(r"C:\QM\repo")
MAIN_EA_ROOT = (
    MAIN_WORKTREE_ROOT / "framework" / "EAs" / "QM5_10834_tv-nq-ict-ob"
)
RUNTIME_WORKTREE_ROOT = Path(r"C:\QM\runtime_worktrees\QM5_10834_WS30_ALT002")
RUNTIME_RECEIPT_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\runtime"
    r"\WS30_ICT_OB_TRANSPORT_INFRA_ALTERNATE_002_runtime_receipt.json"
)
ALTERNATE_RUN_ROOT = W.ALTERNATE_RUN_ROOT
ALTERNATE_PRE_RECEIPT_PATH = ALTERNATE_RUN_ROOT / "pre_receipt.json"
ALTERNATE_AUTHORIZATION_PATH = W.ALTERNATE_AUTHORIZATION_PATH
ALTERNATE_STATE_PATH = ALTERNATE_RUN_ROOT / "launch_state.json"
ALTERNATE_JOB_PATH = ALTERNATE_RUN_ROOT / "launch_job.json"
ALTERNATE_POST_RECEIPT_PATH = ALTERNATE_RUN_ROOT / "post_receipt.json"
ALTERNATE_CLAIM_PATH = W.ALTERNATE_CLAIM_PATH
ALTERNATE_AUTHORIZATION_SCOPE = W.ALTERNATE_AUTHORIZATION_SCOPE

PRIMARY_CLOSURE_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "ws30_primary_attempt001_invalid_infra_closure_20260721.json"
)
EXPECTED_PRIMARY_CLOSURE_SHA256 = (
    "510c100a5a5fa95a38a00d0b023833922b8f1574eb19a13746e21650ce6f3bbc"
)
ALTERNATE_CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "ws30_transport_infra_alternate002_contract_20260721.json"
)
EXPECTED_ALTERNATE_CONTRACT_SHA256 = (
    "0b4c11f4e9846a495374b8db1fe78435b94c689a7bff028ace0fadd7b7f9c31a"
)
EXPECTED_DATA_RECEIPT_SIZE = 29800
EXPECTED_DATA_RECEIPT_SHA256 = (
    "bd398f53d31e7c91667069e6b2c5b6ec466bb2630fb0934436a3b8f75aedd401"
)
EXPECTED_MERIT_CONTRACT_SHA256 = (
    "b87795527d7d4b6bfdfc111e03513b74e06a4bb391f8fdab0dd0cd0a1437bf2e"
)
EXPECTED_PRIMARY_ADAPTER_SIZE = 51496
EXPECTED_PRIMARY_ADAPTER_SHA256 = (
    "d9433850c15557575f6fccac2afa62c4ef09ecdd1007c806ca4f31fcb36c90fb"
)
EXPECTED_BASE_AUDITOR_SIZE = 239116
EXPECTED_BASE_AUDITOR_SHA256 = (
    "58101fefced46392f26bd24aae0e7520d8ee591d97d1e50a759efd46b693f013"
)

EXPECTED_DATA_RECEIPT_REPO_BINDING_LOCATIONS = frozenset(
    {
        "$.cost_schedule.supplemental_stress.slippage.source",
        "$.factory_evidence.aliases",
        "$.factory_evidence.cost",
        "$.factory_evidence.matrix",
        "$.factory_evidence.slippage_calibration",
        "$.factory_evidence.v5_framework",
    }
)

PRIMARY_ROOT = W.PRIMARY_RUN_ROOT
PRIMARY_STATE_PATH = W.PRIMARY_STATE_PATH
PRIMARY_CLAIM_PATH = W.PRIMARY_CLAIM_PATH
PRIMARY_EXPECTED_DIRECTORIES = ("control", "native", r"native\DEV")
PRIMARY_EXPECTED_FILE_LEDGER = (
    (
        r"control\dev2_machine_credential_probe.json",
        747,
        "4f4b6e815b92a35ef225638b3f589d565d0fe68420544996b6587f926614f61f",
    ),
    (
        r"control\dev2_machine_credential_probe.stderr.log",
        0,
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    ),
    (
        r"control\dev2_machine_credential_probe.stdout.log",
        48,
        "e28ad5859d8acd2dbe9e04c21db9d3fe507afaa2b19b52db6c7bfbc82340e856",
    ),
    (
        "launch_job.json",
        2076,
        "c377b7fc058b04aeebe93b39c5f7f4f7fcbe8eeff12032af60d4efc9b77258ac",
    ),
    (
        "launch_state.json",
        7383,
        "e4aaedf0d4b01d30f2512fb33338ebd0cbbcb59365a764a9209482894106039f",
    ),
    (
        "native_outcome_authorization.json",
        1571,
        "40cf7159e3892fda1db98543ff0c94a36b64f36694e054c6e528acff04f8e153",
    ),
    (
        r"native\DEV\controller.stderr.log",
        312,
        "854a59a927aa016d66e12a287cec83692db22ab08c215a655593ca626e839241",
    ),
    (
        r"native\DEV\controller.stdout.log",
        0,
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    ),
    (
        "pre_receipt.json",
        73661,
        "53ca4f23d16c877f69b062812e3e098d97fca20025f67b0d05b2032e6491ff92",
    ),
)
PRIMARY_CLAIM_BINDING = {
    "path": str(PRIMARY_CLAIM_PATH),
    "size": 4296,
    "sha256": "07f318a2638e680bbbb7f9310436b1e931751c786c04d7ca2d09b13de8fb8efe",
}

ALTERNATE_RUNTIME_BINDING_ROLES = tuple(
    dict.fromkeys(
        (
            *W.RUNTIME_BINDING_ROLES,
            "tool",
            "ws30_primary_adapter",
            "alternate_contract",
            "primary_invalid_infra_closure",
            "alternate_runtime_materialization_receipt",
        )
    )
)

_BASE_EXPECTED_BINDING_PATHS = W._expected_binding_paths
_BASE_PREFLIGHT = W._BASE_PREFLIGHT
_BASE_ASSERT_PRE_RECEIPT = W._BASE_ASSERT_PRE_RECEIPT
_BASE_EXECUTION_CONTRACT = W._BASE_EXECUTION_CONTRACT
_BASE_CLAIM_BASIS = W._BASE_CLAIM_BASIS
_BASE_LAUNCH_DETACHED = B.launch_detached
_BASE_VALIDATE_BACKTEST_DATA_RECEIPT = B.validate_backtest_data_receipt
_ORIGINAL_LOAD_JSON = B.load_json


def _configure_alternate_profile() -> None:
    B.__doc__ = __doc__
    B.TOOL_PATH = TOOL_PATH
    B.CURRENT_CLAIM_SEQUENCE = 2
    B.RESERVED_COUNTED_ALTERNATE_ATTEMPT_NUMBER = 2
    B.PRIOR_CLAIM_SEQUENCES = 1
    B.MAXIMUM_COUNTED_ALTERNATE_ATTEMPTS = 1
    B.PRIOR_COUNTED_ALTERNATE_ATTEMPTS = 0
    B.AUTHORIZATION_SCOPE = ALTERNATE_AUTHORIZATION_SCOPE
    B.NATIVE_ATTEMPT_CLAIM_PATH = ALTERNATE_CLAIM_PATH
    B.NATIVE_LAUNCH_LOCK_PATH = W.NATIVE_LAUNCH_LOCK_PATH
    B.REQUIRED_BINDING_ROLES = frozenset(
        set(B.REQUIRED_BINDING_ROLES)
        | {
            "ws30_primary_adapter",
            "alternate_contract",
            "primary_invalid_infra_closure",
            "alternate_runtime_materialization_receipt",
        }
    )


_configure_alternate_profile()


def _git_at(
    root: Path, *args: str, check: bool = True
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if check and completed.returncode != 0:
        raise B.InvalidEvidence(f"git query failed at {root}: {' '.join(args)}")
    return completed


def _clean_head(root: Path, label: str, *, detached_required: bool) -> str:
    root = W._assert_no_reparse_components(root, label)
    if not root.is_dir():
        raise B.InvalidEvidence(f"{label} does not exist: {root}")
    top = Path(
        _git_at(root, "rev-parse", "--show-toplevel").stdout.strip()
    ).resolve()
    if top != root.resolve():
        raise B.InvalidEvidence(f"{label} top-level drift: {top}")
    status = _git_at(
        root, "status", "--porcelain=v1", "--untracked-files=all"
    ).stdout
    if status:
        raise B.InvalidEvidence(f"{label} is dirty")
    head = _git_at(root, "rev-parse", "HEAD^{commit}").stdout.strip().lower()
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        raise B.InvalidEvidence(f"{label} HEAD is malformed")
    symbolic = _git_at(root, "symbolic-ref", "-q", "HEAD", check=False)
    if detached_required and not (
        symbolic.returncode == 1 and not symbolic.stdout.strip()
    ):
        raise B.InvalidEvidence(f"{label} must be detached")
    return head


def assert_main_worktree_clean(stage: str) -> str:
    return _clean_head(
        MAIN_WORKTREE_ROOT, f"main worktree at {stage}", detached_required=False
    )


def _assert_runtime_location() -> Path:
    observed = W._lexical_path(REPO_ROOT)
    expected = W._lexical_path(RUNTIME_WORKTREE_ROOT)
    if os.path.normcase(str(observed)) != os.path.normcase(str(expected)):
        raise B.InvalidEvidence(
            f"alternate must execute from detached runtime worktree: {observed} != {expected}"
        )
    if observed == W._lexical_path(MAIN_WORKTREE_ROOT):
        raise B.InvalidEvidence("alternate runtime may not be the main worktree")
    W._assert_no_reparse_components(observed, "alternate runtime worktree")
    return observed


def validate_alternate_contract() -> dict[str, Any]:
    binding = B.file_binding(ALTERNATE_CONTRACT_PATH, EXPECTED_ALTERNATE_CONTRACT_SHA256)
    payload = B.load_json(ALTERNATE_CONTRACT_PATH)
    if set(payload) != {
        "schema_version",
        "artifact_type",
        "status",
        "created_utc",
        "analysis_id",
        "attempt",
        "primary_contract",
        "primary_invalid_infra_closure",
        "identical_evidence_contract",
        "separate_control_namespace",
        "immutable_runtime",
        "outcome_fence",
        "launch_gate",
    }:
        raise B.InvalidEvidence("alternate contract field closure drift")
    if (
        payload.get("schema_version") != 1
        or payload.get("artifact_type")
        != "QM5_10834_WS30_TRANSPORT_INFRA_ALTERNATE_CONTRACT"
        or payload.get("status")
        != "IMPLEMENTED_NOT_MATERIALIZED_NOT_AUTHORIZED_NOT_LAUNCHED"
        or payload.get("analysis_id") != ANALYSIS_ID
    ):
        raise B.InvalidEvidence("alternate contract identity/status drift")
    W._strict_created_utc(payload.get("created_utc"), "alternate contract created_utc")
    attempt = payload.get("attempt")
    if not isinstance(attempt, Mapping) or attempt != {
        "type": "PREREGISTERED_SINGLE_INFRASTRUCTURE_ALTERNATE",
        "attempt_number": 2,
        "maximum_total_attempts": 2,
        "further_attempts_forbidden": True,
        "execution_lane": "DEV2",
        "resume_forbidden": True,
        "terminal_hopping_forbidden": True,
    }:
        raise B.InvalidEvidence("alternate attempt budget drift")
    primary_contract = payload.get("primary_contract")
    if not isinstance(primary_contract, Mapping) or (
        primary_contract.get("size") != 8247
        or primary_contract.get("sha256") != W.EXPECTED_CONTRACT_SHA256
    ):
        raise B.InvalidEvidence("alternate primary-contract binding drift")
    closure = payload.get("primary_invalid_infra_closure")
    if not isinstance(closure, Mapping) or (
        closure.get("size") != 6069
        or closure.get("sha256") != EXPECTED_PRIMARY_CLOSURE_SHA256
        or closure.get("required_status")
        != "PRIMARY_INVALID_INFRA_CLOSED_NO_OUTCOME_READ"
        or closure.get("required_cause_class")
        != "DEV2_CONTROLLER_FAILED_BEFORE_NATIVE_REPORT"
        or closure.get("zero_native_reports_required") is not True
        or closure.get("strategy_outcomes_read_must_be_false") is not True
        or closure.get("strategy_merit_adjudicated_must_be_false") is not True
    ):
        raise B.InvalidEvidence("alternate primary-closure contract drift")
    identical = payload.get("identical_evidence_contract")
    if not isinstance(identical, Mapping) or (
        identical.get("research_symbol") != RESEARCH_SYMBOL
        or identical.get("timeframe") != "M5"
        or identical.get("model") != 4
        or identical.get("duplicates_per_cell") != 2
        or identical.get("maximum_attempts_per_cell") != 4
        or any(
            identical.get(key) is not True
            for key in (
                "same_build_receipt_required",
                "same_ea_binary_required",
                "same_set_required",
                "same_tick_data_receipt_required",
                "same_strategy_parameters_required",
                "same_cost_schedule_required",
                "same_merit_contract_required",
                "parameter_tuning_forbidden",
                "gate_relaxation_forbidden",
            )
        )
    ):
        raise B.InvalidEvidence("alternate identical-evidence contract drift")
    tick_receipt = identical.get("tick_data_receipt_binding")
    if not isinstance(tick_receipt, Mapping) or tick_receipt != {
        "path": str(W.FUTURE_DATA_RECEIPT_PATH),
        "size": EXPECTED_DATA_RECEIPT_SIZE,
        "sha256": EXPECTED_DATA_RECEIPT_SHA256,
    }:
        raise B.InvalidEvidence("alternate frozen tick-data receipt binding drift")
    frozen_gate = identical.get("frozen_gate_and_auditor_identity")
    if not isinstance(frozen_gate, Mapping) or frozen_gate != {
        "merit_contract_canonical_sha256": EXPECTED_MERIT_CONTRACT_SHA256,
        "primary_ws30_adapter_size": EXPECTED_PRIMARY_ADAPTER_SIZE,
        "primary_ws30_adapter_sha256": EXPECTED_PRIMARY_ADAPTER_SHA256,
        "base_auditor_size": EXPECTED_BASE_AUDITOR_SIZE,
        "base_auditor_sha256": EXPECTED_BASE_AUDITOR_SHA256,
    }:
        raise B.InvalidEvidence("alternate frozen merit/auditor identity drift")
    expected_windows = [
        {
            "cell_id": row.cell_id,
            "cohort": row.cohort,
            "from_date": row.from_date.isoformat(),
            "to_date": row.to_date.isoformat(),
        }
        for row in B.WINDOWS
    ]
    if identical.get("windows") != expected_windows:
        raise B.InvalidEvidence("alternate DEV/OOS windows drift")
    namespace = payload.get("separate_control_namespace")
    if not isinstance(namespace, Mapping) or (
        Path(str(namespace.get("run_root", ""))).resolve()
        != ALTERNATE_RUN_ROOT.resolve()
        or Path(str(namespace.get("pre_receipt_path", ""))).resolve()
        != ALTERNATE_PRE_RECEIPT_PATH.resolve()
        or Path(str(namespace.get("authorization_path", ""))).resolve()
        != ALTERNATE_AUTHORIZATION_PATH.resolve()
        or Path(str(namespace.get("launch_state_path", ""))).resolve()
        != ALTERNATE_STATE_PATH.resolve()
        or Path(str(namespace.get("launch_job_path", ""))).resolve()
        != ALTERNATE_JOB_PATH.resolve()
        or Path(str(namespace.get("post_receipt_path", ""))).resolve()
        != ALTERNATE_POST_RECEIPT_PATH.resolve()
        or Path(str(namespace.get("claim_path", ""))).resolve()
        != ALTERNATE_CLAIM_PATH.resolve()
        or namespace.get("authorization_scope") != ALTERNATE_AUTHORIZATION_SCOPE
        or namespace.get("all_primary_paths_forbidden") is not True
    ):
        raise B.InvalidEvidence("alternate control namespace drift")
    runtime = payload.get("immutable_runtime")
    if not isinstance(runtime, Mapping) or (
        Path(str(runtime.get("source_main_worktree", ""))).resolve()
        != MAIN_WORKTREE_ROOT.resolve()
        or Path(str(runtime.get("runtime_worktree_root", ""))).resolve()
        != RUNTIME_WORKTREE_ROOT.resolve()
        or runtime.get("runtime_tool_relative_path")
        != str(TOOL_PATH.relative_to(REPO_ROOT)).replace("\\", "/")
        or any(
            runtime.get(key) is not True
            for key in (
                "main_worktree_must_be_clean_at_materialization",
                "main_worktree_must_be_clean_at_pre",
                "main_worktree_must_be_clean_at_launch",
                "runtime_worktree_must_be_new",
                "runtime_worktree_must_be_detached",
                "runtime_worktree_must_be_clean",
                "runtime_worktree_must_not_equal_main_worktree",
                "runtime_root_reparse_components_forbidden",
                "exact_bound_file_byte_overlay_required",
                "post_overlay_git_clean_required",
                "runtime_head_must_contain_contract_and_closure",
                "primary_contract_absolute_repo_paths_are_evidence_origin_only",
                "runtime_relocation_requires_byte_identical_repository_relative_files",
                "all_repository_pre_and_include_bindings_byte_identity_ledger_required",
                "alternate_pre_and_worker_must_not_open_main_worktree_evidence_files",
                "pre_binds_runtime_head_and_all_runtime_roles",
                "worker_reasserts_bound_bytes_before_each_native_cell",
                "pump_mutation_of_main_worktree_cannot_change_bound_runtime_bytes",
            )
        )
    ):
        raise B.InvalidEvidence("alternate immutable-runtime contract drift")
    B.assert_binding(binding, "alternate execution contract")
    return payload


def validate_frozen_gate_and_auditor_identity() -> None:
    primary = B.file_binding(PRIMARY_ADAPTER_PATH, EXPECTED_PRIMARY_ADAPTER_SHA256)
    base = B.file_binding(W.BASE_TOOL_PATH, EXPECTED_BASE_AUDITOR_SHA256)
    if primary["size"] != EXPECTED_PRIMARY_ADAPTER_SIZE:
        raise B.InvalidEvidence("frozen primary WS30 adapter size drift")
    if base["size"] != EXPECTED_BASE_AUDITOR_SIZE:
        raise B.InvalidEvidence("frozen base auditor size drift")
    if B.canonical_sha256(B.MERIT_GATES) != EXPECTED_MERIT_CONTRACT_SHA256:
        raise B.InvalidEvidence("frozen primary merit contract drift")


def validate_relocated_primary_transport_contract() -> dict[str, Any]:
    """Validate the frozen primary contract without opening C:\\QM\\repo inputs.

    The primary contract predates the reserved runtime worktree and records two
    absolute C:\\QM\\repo evidence-origin paths.  The alternate extension
    explicitly permits only a repository-relative, byte-identical relocation.
    Temporarily supplying the recorded origin root to the *contract parser*
    validates those frozen strings; all actual PRE bindings remain under the
    detached runtime root and are rehashed there.
    """

    validate_alternate_contract()
    validate_frozen_gate_and_auditor_identity()
    runtime_build = EA_ROOT / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
    runtime_set = EA_ROOT / "sets" / f"{B.EXPERT_NAME}_{RESEARCH_SYMBOL}_M5_backtest.set"
    B.file_binding(runtime_build, W.EXPECTED_BUILD_RECEIPT_SHA256)
    B.file_binding(
        runtime_set,
        "0f6979d7024aa9f5098deac1f04010876a86cf0363f1fd25ab21eb3ed066e3d6",
    )
    original_ea_root = W.EA_ROOT
    original_build_receipt = W.BUILD_RECEIPT_PATH
    try:
        W.EA_ROOT = MAIN_EA_ROOT
        W.BUILD_RECEIPT_PATH = (
            MAIN_EA_ROOT
            / "docs"
            / "candidate-analysis"
            / "build_receipt_20260720.json"
        )
        return W.validate_transport_contract(W.CONTRACT_PATH)
    finally:
        W.EA_ROOT = original_ea_root
        W.BUILD_RECEIPT_PATH = original_build_receipt


def _main_repo_relative(path: Path | str) -> Path | None:
    candidate = Path(os.fspath(path))
    if not candidate.is_absolute():
        return None
    lexical = W._lexical_path(path)
    try:
        relative = lexical.relative_to(W._lexical_path(MAIN_WORKTREE_ROOT))
    except ValueError:
        return None
    if not relative.parts:
        raise B.InvalidEvidence("bare main-worktree root is not a relocatable binding")
    return relative


def _project_data_receipt_repo_bindings(
    payload: Mapping[str, Any],
) -> dict[str, Any]:
    """Relocate the six frozen repo bindings without opening C:\\QM\\repo.

    Only exact ``{path,size,sha256}`` binding objects at preregistered JSON
    locations may reference the original main worktree.  Each is projected to
    the same repository-relative path in the detached runtime and its size/hash
    is reasserted there.  Any additional main-worktree string fails closed.
    """

    observed_locations: set[str] = set()

    def visit(value: Any, location: str) -> Any:
        if isinstance(value, Mapping):
            if set(value) == {"path", "size", "sha256"}:
                relative = _main_repo_relative(str(value.get("path", "")))
                if relative is not None:
                    if location not in EXPECTED_DATA_RECEIPT_REPO_BINDING_LOCATIONS:
                        raise B.InvalidEvidence(
                            f"unapproved main-worktree binding in data receipt: {location}"
                        )
                    digest = str(value.get("sha256", "")).lower()
                    try:
                        size = int(value.get("size"))
                    except (TypeError, ValueError) as exc:
                        raise B.InvalidEvidence(
                            f"malformed relocated binding size: {location}"
                        ) from exc
                    runtime_path = W._assert_no_reparse_components(
                        REPO_ROOT / relative,
                        f"relocated data-receipt binding {location}",
                    )
                    runtime_binding = B.file_binding(runtime_path, digest)
                    if runtime_binding["size"] != size:
                        raise B.InvalidEvidence(
                            f"relocated data-receipt binding size drift: {location}"
                        )
                    observed_locations.add(location)
                    return runtime_binding
            return {
                str(key): visit(item, f"{location}.{key}")
                for key, item in value.items()
            }
        if isinstance(value, list):
            return [visit(item, f"{location}[{index}]") for index, item in enumerate(value)]
        if isinstance(value, str) and _main_repo_relative(value) is not None:
            raise B.InvalidEvidence(
                f"unbound main-worktree path in data receipt: {location}"
            )
        return value

    projected = visit(copy.deepcopy(dict(payload)), "$")
    if observed_locations != set(EXPECTED_DATA_RECEIPT_REPO_BINDING_LOCATIONS):
        raise B.InvalidEvidence(
            "data-receipt repo relocation location closure drift: "
            f"{sorted(observed_locations)}"
        )
    if not isinstance(projected, dict):  # pragma: no cover - input is a mapping
        raise B.InvalidEvidence("projected data receipt is not an object")
    return projected


def validate_relocated_backtest_data_receipt(
    path: Path,
    symbol: str,
    *,
    terminal_data_root: Path = B.TERMINAL_DATA_ROOT,
    evidence_paths: Mapping[str, Path] | None = None,
) -> dict[str, Any]:
    if evidence_paths is not None:
        raise B.InvalidEvidence("alternate data-receipt evidence overrides are forbidden")
    W._assert_lexical_exact(
        path, W.FUTURE_DATA_RECEIPT_PATH, "alternate frozen data receipt"
    )
    receipt_binding = B.file_binding(path, EXPECTED_DATA_RECEIPT_SHA256)
    if receipt_binding["size"] != EXPECTED_DATA_RECEIPT_SIZE:
        raise B.InvalidEvidence("alternate frozen data receipt size drift")
    saved_loader = B.load_json
    raw = saved_loader(path)
    if not isinstance(raw, Mapping):
        raise B.InvalidEvidence("alternate raw data receipt is not an object")
    projected = _project_data_receipt_repo_bindings(raw)
    receipt_path = W._lexical_path(path)

    def projected_loader(candidate: Path) -> Any:
        if W._lexical_path(candidate) == receipt_path:
            return copy.deepcopy(projected)
        return saved_loader(candidate)

    B.load_json = projected_loader
    try:
        validated = _BASE_VALIDATE_BACKTEST_DATA_RECEIPT(
            path,
            symbol,
            terminal_data_root=terminal_data_root,
            evidence_paths=None,
        )
    finally:
        B.load_json = saved_loader
    if validated.get("receipt") != receipt_binding:
        raise B.InvalidEvidence(
            "alternate frozen data receipt changed during relocated validation"
        )
    final_binding = B.file_binding(path, EXPECTED_DATA_RECEIPT_SHA256)
    if (
        final_binding != receipt_binding
        or final_binding["size"] != EXPECTED_DATA_RECEIPT_SIZE
    ):
        raise B.InvalidEvidence(
            "alternate frozen data receipt changed after relocated validation"
        )
    return validated


def _binding_from_closure(row: Mapping[str, Any]) -> dict[str, Any]:
    if set(row) != {"path", "size", "sha256"}:
        raise B.InvalidEvidence("primary closure binding field drift")
    binding = {
        "path": str(Path(str(row["path"])).resolve()),
        "size": int(row["size"]),
        "sha256": str(row["sha256"]).lower(),
    }
    B.assert_binding(binding, "primary closure external control file")
    return binding


def validate_primary_invalid_infra_closure() -> dict[str, Any]:
    """Validate primary attempt 001 without opening stderr or native outcomes."""

    closure_binding = B.file_binding(
        PRIMARY_CLOSURE_PATH, EXPECTED_PRIMARY_CLOSURE_SHA256
    )
    closure = B.load_json(PRIMARY_CLOSURE_PATH)
    if (
        closure.get("schema_version") != 1
        or closure.get("artifact_type")
        != "QM5_10834_WS30_PRIMARY_INVALID_INFRA_CLOSURE"
        or closure.get("status") != "PRIMARY_INVALID_INFRA_CLOSED_NO_OUTCOME_READ"
        or closure.get("analysis_id") != ANALYSIS_ID
        or closure.get("terminal_disposition")
        != "INVALID_TERMINAL_INFRASTRUCTURE_NO_MERIT_ADJUDICATION"
        or closure.get("allowed_alternate_cause_class")
        != "DEV2_CONTROLLER_FAILED_BEFORE_NATIVE_REPORT"
    ):
        raise B.InvalidEvidence("primary invalid-infra closure identity drift")
    W._strict_created_utc(closure.get("created_utc"), "primary closure created_utc")
    attempt = closure.get("primary_attempt")
    if not isinstance(attempt, Mapping) or (
        attempt.get("attempt_number") != 1
        or Path(str(attempt.get("run_root", ""))).resolve() != PRIMARY_ROOT.resolve()
    ):
        raise B.InvalidEvidence("primary closure attempt identity drift")
    for role in (
        "pre_receipt",
        "authorization",
        "launch_job",
        "launch_state",
        "native_claim",
    ):
        row = attempt.get(role)
        if not isinstance(row, Mapping):
            raise B.InvalidEvidence(f"primary closure missing binding: {role}")
        _binding_from_closure(row)
    if dict(attempt["native_claim"]) != PRIMARY_CLAIM_BINDING:
        raise B.InvalidEvidence("primary claim binding drift")

    metadata = closure.get("directory_metadata_closure")
    if not isinstance(metadata, Mapping) or (
        metadata.get("inspection_mode")
        != "PATH_TYPE_SIZE_SHA256_ONLY_NO_LOG_OR_REPORT_CONTENT_READ"
        or metadata.get("directories_exact") != list(PRIMARY_EXPECTED_DIRECTORIES)
        or metadata.get("exact_file_closure") is not True
        or metadata.get("native_report_file_count") != 0
        or metadata.get("native_outcome_file_count") != 0
        or metadata.get("controller_stdout_size") != 0
        or metadata.get("controller_stderr_size") != 312
        or metadata.get("controller_stderr_semantics_read") is not False
        or metadata.get("controller_logs_are_opaque_hash_bindings_only") is not True
    ):
        raise B.InvalidEvidence("primary directory-metadata closure drift")
    expected_rows = [
        {"relative_path": path, "size": size, "sha256": digest}
        for path, size, digest in PRIMARY_EXPECTED_FILE_LEDGER
    ]
    if metadata.get("files_exact") != expected_rows:
        raise B.InvalidEvidence("primary closure file ledger drift")

    W._assert_no_reparse_components(PRIMARY_ROOT, "primary closed run root")
    observed_directories = sorted(
        str(path.relative_to(PRIMARY_ROOT)).replace("/", "\\")
        for path in PRIMARY_ROOT.rglob("*")
        if path.is_dir()
    )
    if observed_directories != sorted(PRIMARY_EXPECTED_DIRECTORIES):
        raise B.InvalidEvidence("primary closed directory set drift")
    observed_files = sorted(
        str(path.relative_to(PRIMARY_ROOT)).replace("/", "\\")
        for path in PRIMARY_ROOT.rglob("*")
        if path.is_file()
    )
    expected_files = sorted(row[0] for row in PRIMARY_EXPECTED_FILE_LEDGER)
    if observed_files != expected_files:
        raise B.InvalidEvidence("primary closed file set drift")
    for relative, size, digest in PRIMARY_EXPECTED_FILE_LEDGER:
        binding = B.file_binding(PRIMARY_ROOT / Path(relative), digest)
        if binding["size"] != size:
            raise B.InvalidEvidence(f"primary closed file size drift: {relative}")

    # launch_state.json is a control envelope, not a native report.  No other
    # file under native/ is parsed; controller stderr remains hash-only.
    state = B.load_json(PRIMARY_STATE_PATH)
    facts = attempt.get("launch_state_control_facts")
    cells = state.get("cells")
    if not isinstance(facts, Mapping) or not isinstance(cells, list) or len(cells) != 4:
        raise B.InvalidEvidence("primary launch-state control closure malformed")
    first = cells[0]
    attempts = first.get("attempts") if isinstance(first, Mapping) else None
    if not isinstance(attempts, list) or len(attempts) != 1:
        raise B.InvalidEvidence("primary first-cell attempt closure drift")
    native_attempt = attempts[0]
    if not isinstance(native_attempt, Mapping) or (
        state.get("analysis_id") != ANALYSIS_ID
        or state.get("artifact_type") != "QM5_10834_NATIVE_LAUNCH_STATE"
        or state.get("status") != facts.get("status")
        or state.get("worker_pid") is not None
        or state.get("resume_count") != 0
        or state.get("finished_utc") is not None
        or first.get("cell_id") != facts.get("active_cell_id")
        or first.get("status") != facts.get("first_cell_status")
        or native_attempt.get("exit_code") != 1
        or native_attempt.get("native_result") is not None
        or native_attempt.get("native_root") is not None
        or native_attempt.get("summary") is not None
        or native_attempt.get("outcome_artifacts") != []
        or [row.get("status") for row in cells[1:]] != ["PENDING"] * 3
        or [len(row.get("attempts", [])) for row in cells[1:]] != [0, 0, 0]
    ):
        raise B.InvalidEvidence("primary launch-state terminal facts drift")
    active = state.get("active_cell")
    if not isinstance(active, Mapping) or (
        active.get("cell_id") != "WS30_DWX_DEV"
        or active.get("status") != "OUTCOME_POSSIBLE_NO_RESUME"
    ):
        raise B.InvalidEvidence("primary active-cell no-resume fence drift")
    outcome_fence = closure.get("outcome_fence")
    if not isinstance(outcome_fence, Mapping) or outcome_fence != {
        "native_report_content_opened": False,
        "controller_stderr_content_opened": False,
        "strategy_outcomes_read": False,
        "strategy_merit_adjudicated": False,
        "primary_resume_permitted": False,
        "primary_post_permitted": False,
        "primary_artifacts_must_remain_immutable": True,
    }:
        raise B.InvalidEvidence("primary outcome fence drift")
    B.assert_binding(closure_binding, "primary invalid-infra closure receipt")
    return closure


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    paths = _BASE_EXPECTED_BINDING_PATHS(symbol)
    paths.update(
        {
            "ws30_primary_adapter": PRIMARY_ADAPTER_PATH,
            "alternate_contract": ALTERNATE_CONTRACT_PATH,
            "primary_invalid_infra_closure": PRIMARY_CLOSURE_PATH,
            "alternate_runtime_materialization_receipt": RUNTIME_RECEIPT_PATH,
        }
    )
    return {
        role: W._assert_no_reparse_components(path, f"alternate PRE binding {role}")
        for role, path in paths.items()
    }


def _assert_alternate_run_root(path: Path) -> Path:
    return W._assert_lexical_exact(path, ALTERNATE_RUN_ROOT, "alternate run root")


def _assert_alternate_control_namespace() -> None:
    for path, label in (
        (B.ALLOWED_RUN_ROOT, "WS30 analysis root"),
        (B.ALLOWED_RUN_ROOT / "claims", "WS30 claim root"),
        (ALTERNATE_RUN_ROOT, "alternate run root"),
        (ALTERNATE_CLAIM_PATH, "alternate claim path"),
        (W.NATIVE_LAUNCH_LOCK_PATH, "alternate launch lock path"),
        (W.FUTURE_DATA_RECEIPT_PATH, "WS30 data receipt path"),
        (RUNTIME_RECEIPT_PATH, "alternate runtime receipt path"),
    ):
        W._assert_no_reparse_components(path, label)


def _repository_binding_relative_paths(root: Path = REPO_ROOT) -> tuple[str, ...]:
    root_lexical = W._lexical_path(root)
    candidates = list(_expected_binding_paths(RESEARCH_SYMBOL).values())
    candidates.append(
        EA_ROOT / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
    )
    includes = B.include_closure(B.MQ5_PATH)
    for item in includes:
        if not isinstance(item, Mapping):
            raise B.InvalidEvidence("runtime include closure binding is malformed")
        candidates.append(Path(str(item.get("path", ""))))
    relative_paths: set[str] = set()
    for candidate in candidates:
        lexical = W._lexical_path(candidate)
        try:
            relative = lexical.relative_to(root_lexical)
        except ValueError:
            continue
        if not relative.parts or any(part in {"", ".", ".."} for part in relative.parts):
            raise B.InvalidEvidence(f"unsafe runtime repository binding: {candidate}")
        relative_paths.add(relative.as_posix())
    if not relative_paths:
        raise B.InvalidEvidence("runtime repository binding closure is empty")
    return tuple(sorted(relative_paths, key=str.casefold))


def _build_repository_byte_identity_ledger(
    source_root: Path,
    runtime_root: Path,
    relative_paths: Sequence[str],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if list(relative_paths) != sorted(set(relative_paths), key=str.casefold):
        raise B.InvalidEvidence("repository binding relatives are not unique/sorted")
    for relative_text in relative_paths:
        relative = Path(relative_text)
        if relative.is_absolute() or any(part in {"", ".", ".."} for part in relative.parts):
            raise B.InvalidEvidence(f"unsafe repository binding relative path: {relative_text}")
        source = W._assert_no_reparse_components(
            source_root / relative, f"source repository binding {relative_text}"
        )
        runtime = W._assert_no_reparse_components(
            runtime_root / relative, f"runtime repository binding {relative_text}"
        )
        source_binding = B.file_binding(source)
        runtime_binding = B.file_binding(runtime, source_binding["sha256"])
        if source_binding["size"] != runtime_binding["size"]:
            raise B.InvalidEvidence(
                f"source/runtime byte size differs after checkout: {relative_text}"
            )
        rows.append(
            {
                "relative_path": relative.as_posix(),
                "size": source_binding["size"],
                "sha256": source_binding["sha256"],
            }
        )
    return rows


def _overlay_exact_repository_binding_bytes(
    source_root: Path,
    runtime_root: Path,
    relative_paths: Sequence[str],
) -> None:
    """Copy the clean source working bytes for every bound repo dependency.

    The frozen evidence intentionally contains mixed LF/CRLF working bytes, so
    no single Git checkout EOL setting can reproduce all hashes.  The detached
    checkout supplies the tree topology; this exact, closed overlay supplies
    only the preregistered runtime/PRE/include dependency bytes.
    """

    for relative_text in relative_paths:
        relative = Path(relative_text)
        if relative.is_absolute() or any(part in {"", ".", ".."} for part in relative.parts):
            raise B.InvalidEvidence(f"unsafe overlay relative path: {relative_text}")
        source = W._assert_no_reparse_components(
            source_root / relative, f"source overlay file {relative_text}"
        )
        runtime = W._assert_no_reparse_components(
            runtime_root / relative, f"runtime overlay file {relative_text}"
        )
        if not source.is_file() or not runtime.is_file():
            raise B.InvalidEvidence(f"overlay file is missing: {relative_text}")
        shutil.copyfile(source, runtime)


def _validate_runtime_repository_binding_ledger(rows: Any) -> None:
    if not isinstance(rows, list):
        raise B.InvalidEvidence("runtime repository byte ledger is missing")
    expected_relatives = list(_repository_binding_relative_paths(REPO_ROOT))
    observed_relatives: list[str] = []
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping) or set(row) != {
            "relative_path",
            "size",
            "sha256",
        }:
            raise B.InvalidEvidence(f"runtime byte ledger row[{index}] malformed")
        relative_text = str(row.get("relative_path", ""))
        relative = Path(relative_text)
        if relative.is_absolute() or any(part in {"", ".", ".."} for part in relative.parts):
            raise B.InvalidEvidence(f"unsafe runtime byte ledger path[{index}]")
        try:
            size = int(row.get("size"))
        except (TypeError, ValueError) as exc:
            raise B.InvalidEvidence(f"runtime byte ledger size[{index}] malformed") from exc
        digest = str(row.get("sha256", "")).lower()
        binding = B.file_binding(REPO_ROOT / relative, digest)
        if binding["size"] != size:
            raise B.InvalidEvidence(f"runtime byte ledger size drift[{index}]")
        observed_relatives.append(relative.as_posix())
    if observed_relatives != expected_relatives:
        raise B.InvalidEvidence("runtime repository binding-ledger closure drift")


def _runtime_bootstrap_bindings(root: Path) -> dict[str, Any]:
    relative_paths = {
        "tool": TOOL_PATH.relative_to(REPO_ROOT),
        "ws30_primary_adapter": PRIMARY_ADAPTER_PATH.relative_to(REPO_ROOT),
        "alternate_contract": ALTERNATE_CONTRACT_PATH.relative_to(REPO_ROOT),
        "primary_invalid_infra_closure": PRIMARY_CLOSURE_PATH.relative_to(REPO_ROOT),
    }
    return {
        role: B.file_binding(root / relative)
        for role, relative in relative_paths.items()
    }


def validate_runtime_materialization_receipt() -> dict[str, Any]:
    binding = B.file_binding(RUNTIME_RECEIPT_PATH)
    payload = B.load_json(RUNTIME_RECEIPT_PATH)
    expected_keys = {
        "schema_version",
        "artifact_type",
        "status",
        "created_utc",
        "source_main_worktree",
        "source_head",
        "runtime_worktree",
        "runtime_head",
        "runtime_detached",
        "main_clean_at_materialization",
        "runtime_clean_at_materialization",
        "checkout_policy",
        "repository_binding_byte_identity_ledger",
        "bootstrap_bindings",
    }
    if set(payload) != expected_keys or (
        payload.get("schema_version") != 1
        or payload.get("artifact_type")
        != "QM5_10834_WS30_ALTERNATE_RUNTIME_MATERIALIZATION_RECEIPT"
        or payload.get("status") != "PASS"
        or Path(str(payload.get("source_main_worktree", ""))).resolve()
        != MAIN_WORKTREE_ROOT.resolve()
        or Path(str(payload.get("runtime_worktree", ""))).resolve()
        != RUNTIME_WORKTREE_ROOT.resolve()
        or payload.get("runtime_detached") is not True
        or payload.get("main_clean_at_materialization") is not True
        or payload.get("runtime_clean_at_materialization") is not True
    ):
        raise B.InvalidEvidence("alternate runtime receipt identity drift")
    if payload.get("checkout_policy") != {
        "checkout": "GIT_WORKTREE_ADD_DETACHED_THEN_EXACT_BOUND_FILE_BYTE_OVERLAY",
        "checkout_eol_policy_is_not_evidence": True,
        "exact_overlay_from_clean_source_worktree": True,
        "post_overlay_git_clean": True,
        "post_checkout_byte_identity_required": True,
    }:
        raise B.InvalidEvidence("alternate runtime LF checkout policy drift")
    W._strict_created_utc(payload.get("created_utc"), "runtime materialization created_utc")
    runtime_head = _clean_head(
        RUNTIME_WORKTREE_ROOT, "alternate runtime worktree", detached_required=True
    )
    if (
        payload.get("source_head") != runtime_head
        or payload.get("runtime_head") != runtime_head
    ):
        raise B.InvalidEvidence("alternate runtime receipt HEAD drift")
    expected_bootstrap = _runtime_bootstrap_bindings(RUNTIME_WORKTREE_ROOT)
    if payload.get("bootstrap_bindings") != expected_bootstrap:
        raise B.InvalidEvidence("alternate runtime bootstrap binding drift")
    _validate_runtime_repository_binding_ledger(
        payload.get("repository_binding_byte_identity_ledger")
    )
    B.assert_binding(binding, "alternate runtime materialization receipt")
    return payload


def runtime_provenance(bindings: Mapping[str, Any]) -> dict[str, Any]:
    _assert_runtime_location()
    receipt = validate_runtime_materialization_receipt()
    head = _clean_head(REPO_ROOT, "alternate runtime worktree", detached_required=True)
    runtime_bindings: dict[str, Any] = {}
    for role in ALTERNATE_RUNTIME_BINDING_ROLES:
        item = bindings.get(role)
        if not isinstance(item, Mapping):
            raise B.InvalidEvidence(f"alternate runtime binding missing: {role}")
        B.assert_binding(item, f"alternate runtime {role}")
        runtime_bindings[role] = dict(item)
    return {
        "runtime_mode": "DETACHED_PUMP_PROOF_WORKTREE",
        "runtime_root": str(REPO_ROOT.resolve()),
        "runtime_head": head,
        "runtime_clean": True,
        "runtime_detached": True,
        "materialization_receipt": B.file_binding(RUNTIME_RECEIPT_PATH),
        "materialization_payload_sha256": B.canonical_sha256(receipt),
        "runtime_bindings": runtime_bindings,
    }


def validate_runtime_provenance(
    provenance: Mapping[str, Any], bindings: Mapping[str, Any]
) -> None:
    current = runtime_provenance(bindings)
    if provenance != current:
        raise B.InvalidEvidence("alternate immutable runtime provenance drift")


def execution_contract() -> dict[str, Any]:
    contract = _BASE_EXECUTION_CONTRACT()
    contract.update(
        {
            "native_attempt_claim_mode": (
                "ATOMIC_CREATE_ONCE_FOR_WS30_INFRA_ALTERNATE_002_AFTER_"
                "SAME_WORKER_PRECLAIM_PROBE"
            ),
            "current_attempt_type": "PREREGISTERED_INFRA_ALTERNATE_ONE_SHOT",
            "maximum_total_counted_attempts": 2,
            "primary_attempt_number": 1,
            "current_attempt_number": 2,
            "resume_permitted": False,
            "further_attempts_forbidden": True,
            "primary_invalid_infra_closure": B.file_binding(
                PRIMARY_CLOSURE_PATH, EXPECTED_PRIMARY_CLOSURE_SHA256
            ),
            "alternate_execution_contract": B.file_binding(
                ALTERNATE_CONTRACT_PATH, EXPECTED_ALTERNATE_CONTRACT_SHA256
            ),
            "immutable_runtime_required": True,
            "main_worktree_clean_at_launch_required": True,
        }
    )
    return contract


def _assert_native_attempt_unclaimed(stage: str) -> None:
    _assert_alternate_control_namespace()
    if not PRIMARY_CLAIM_PATH.is_file():
        raise B.AuthorizationError(
            f"primary attempt claim is missing before alternate at {stage}"
        )
    B.assert_binding(PRIMARY_CLAIM_BINDING, "primary attempt claim")
    if ALTERNATE_CLAIM_PATH.exists():
        raise B.AuthorizationError(
            f"WS30 alternate native attempt 002 is already claimed at {stage}"
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
    basis.update(
        {
            "classification": (
                "ATOMIC_GLOBAL_OUTCOME_BLIND_WS30_INFRA_ALTERNATE_ATTEMPT_002"
            ),
            "maximum_total_counted_attempts": 2,
            "primary_attempt_claim": dict(PRIMARY_CLAIM_BINDING),
            "primary_invalid_infra_closure": dict(
                pre["bindings"]["primary_invalid_infra_closure"]
            ),
            "alternate_execution_contract": dict(
                pre["bindings"]["alternate_contract"]
            ),
            "immutable_runtime": dict(pre["runtime_provenance"]),
            "resume_permitted": False,
            "further_attempts_forbidden": True,
        }
    )
    return basis


def _transport_distinctness() -> dict[str, Any]:
    return {
        "classification": "PREREGISTERED_WS30_INFRA_ALTERNATE_NOT_NDX_RETRY",
        "research_symbol": RESEARCH_SYMBOL,
        "ndx_data_receipt_reused": False,
        "ndx_native_report_read": False,
        "ndx_strategy_outcome_read": False,
        "primary_ws30_native_report_read": False,
        "primary_ws30_controller_stderr_read": False,
        "primary_ws30_strategy_outcome_read": False,
        "parameters_tuned_for_ws30": False,
        "strategy_parameters_changed_between_attempts": False,
        "merit_gates_changed_between_attempts": False,
    }


def preflight(
    symbol: str,
    data_receipt_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    assert_main_worktree_clean("alternate PRE")
    _assert_runtime_location()
    _assert_alternate_control_namespace()
    validate_alternate_contract()
    validate_relocated_primary_transport_contract()
    validate_primary_invalid_infra_closure()
    runtime_receipt = validate_runtime_materialization_receipt()
    payload = _BASE_PREFLIGHT(
        symbol,
        data_receipt_path,
        build_receipt_path,
        run_root,
    )
    payload["runtime_provenance"] = runtime_provenance(payload["bindings"])
    payload["transport_distinctness"] = _transport_distinctness()
    payload["infrastructure_alternate"] = {
        "attempt_number": 2,
        "primary_attempt_number": 1,
        "primary_closure": dict(
            payload["bindings"]["primary_invalid_infra_closure"]
        ),
        "alternate_contract": dict(payload["bindings"]["alternate_contract"]),
        "runtime_materialization_receipt": dict(
            payload["bindings"]["alternate_runtime_materialization_receipt"]
        ),
        "runtime_materialization_payload_sha256": B.canonical_sha256(
            runtime_receipt
        ),
        "same_strategy_parameters": True,
        "same_merit_gates": True,
        "resume_permitted": False,
        "further_attempts_forbidden": True,
    }
    return payload


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _assert_alternate_control_namespace()
    W._assert_lexical_exact(
        path, ALTERNATE_PRE_RECEIPT_PATH, "alternate PRE receipt"
    )
    pre = _BASE_ASSERT_PRE_RECEIPT(path, expected_sha256)
    W._assert_lexical_exact(
        str(pre.get("run_root", "")), ALTERNATE_RUN_ROOT, "alternate PRE run root"
    )
    W._assert_lexical_exact(
        str(pre.get("build_receipt", {}).get("path", "")),
        W.BUILD_RECEIPT_PATH,
        "alternate PRE build receipt",
    )
    W._assert_lexical_exact(
        str(pre.get("backtest_data_receipt", {}).get("path", "")),
        W.FUTURE_DATA_RECEIPT_PATH,
        "alternate PRE data receipt",
    )
    if pre.get("transport_distinctness") != _transport_distinctness():
        raise B.InvalidEvidence("alternate PRE transport-distinctness drift")
    alt = pre.get("infrastructure_alternate")
    if not isinstance(alt, Mapping) or (
        alt.get("attempt_number") != 2
        or alt.get("primary_attempt_number") != 1
        or alt.get("same_strategy_parameters") is not True
        or alt.get("same_merit_gates") is not True
        or alt.get("resume_permitted") is not False
        or alt.get("further_attempts_forbidden") is not True
    ):
        raise B.InvalidEvidence("alternate PRE attempt closure drift")
    validate_alternate_contract()
    validate_primary_invalid_infra_closure()
    provenance = pre.get("runtime_provenance")
    bindings = pre.get("bindings")
    if not isinstance(provenance, Mapping) or not isinstance(bindings, Mapping):
        raise B.InvalidEvidence("alternate PRE runtime provenance missing")
    validate_runtime_provenance(provenance, bindings)
    if alt.get("primary_closure") != bindings.get("primary_invalid_infra_closure"):
        raise B.InvalidEvidence("alternate PRE primary closure binding drift")
    if alt.get("alternate_contract") != bindings.get("alternate_contract"):
        raise B.InvalidEvidence("alternate PRE contract binding drift")
    if alt.get("runtime_materialization_receipt") != bindings.get(
        "alternate_runtime_materialization_receipt"
    ):
        raise B.InvalidEvidence("alternate PRE runtime receipt binding drift")
    return pre


def launch_detached(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    if resume:
        raise B.AuthorizationError("WS30 infrastructure alternate never permits resume")
    assert_main_worktree_clean("alternate launch")
    _assert_runtime_location()
    validate_primary_invalid_infra_closure()
    return _BASE_LAUNCH_DETACHED(
        pre_path,
        pre_sha256,
        authorization_path,
        state_path,
        resume=False,
    )


def _assert_cli_path_confinement(args: Any) -> None:
    if args.command == "freeze-data":
        raise B.InvalidEvidence(
            "alternate reuses the frozen WS30 data receipt; freeze-data is forbidden"
        )
    if args.command == "pre":
        if args.symbol != RESEARCH_SYMBOL:
            raise B.InvalidEvidence(f"alternate symbol must be exactly {RESEARCH_SYMBOL}")
        W._assert_lexical_exact(
            args.data_receipt, W.FUTURE_DATA_RECEIPT_PATH, "alternate data receipt"
        )
        W._assert_lexical_exact(
            args.build_receipt, W.BUILD_RECEIPT_PATH, "alternate build receipt"
        )
        W._assert_lexical_exact(args.run_root, ALTERNATE_RUN_ROOT, "alternate run root")
        W._assert_lexical_exact(
            args.receipt, ALTERNATE_PRE_RECEIPT_PATH, "alternate PRE receipt"
        )
        return
    if args.command == "launch":
        if args.resume:
            raise B.AuthorizationError("alternate resume is forbidden")
        W._assert_lexical_exact(
            args.pre_receipt, ALTERNATE_PRE_RECEIPT_PATH, "alternate launch PRE"
        )
        W._assert_lexical_exact(
            args.authorization,
            ALTERNATE_AUTHORIZATION_PATH,
            "alternate launch authorization",
        )
        W._assert_lexical_exact(
            args.state, ALTERNATE_STATE_PATH, "alternate launch state"
        )
        return
    if args.command == "post":
        W._assert_lexical_exact(
            args.pre_receipt, ALTERNATE_PRE_RECEIPT_PATH, "alternate POST PRE"
        )
        W._assert_lexical_exact(args.state, ALTERNATE_STATE_PATH, "alternate POST state")
        W._assert_lexical_exact(
            args.receipt, ALTERNATE_POST_RECEIPT_PATH, "alternate POST receipt"
        )
        return
    if args.command == "status":
        W._assert_lexical_exact(args.state, ALTERNATE_STATE_PATH, "alternate status state")
        return
    if args.command == "_run-plan":
        W._assert_lexical_exact(args.job, ALTERNATE_JOB_PATH, "alternate worker job")


def materialize_runtime() -> dict[str, Any]:
    """Create the fixed detached runtime from a clean, committed main worktree."""

    if RUNTIME_RECEIPT_PATH.exists():
        raise B.InvalidEvidence(
            f"runtime materialization receipt already exists: {RUNTIME_RECEIPT_PATH}"
        )
    if RUNTIME_WORKTREE_ROOT.exists():
        raise B.InvalidEvidence(
            f"runtime worktree target already exists: {RUNTIME_WORKTREE_ROOT}"
        )
    source_head = assert_main_worktree_clean("runtime materialization")
    relative_paths = _repository_binding_relative_paths(MAIN_WORKTREE_ROOT)
    for relative_text in relative_paths:
        probe = _git_at(
            MAIN_WORKTREE_ROOT,
            "ls-files",
            "--error-unmatch",
            "--",
            relative_text,
            check=False,
        )
        if probe.returncode != 0:
            raise B.InvalidEvidence(
                f"runtime binding file is not tracked: {relative_text}"
            )
    W._assert_no_reparse_components(
        RUNTIME_WORKTREE_ROOT.parent, "runtime worktree parent"
    ).mkdir(parents=True, exist_ok=True)
    completed = subprocess.run(
        [
            "git",
            "-C",
            str(MAIN_WORKTREE_ROOT),
            "worktree",
            "add",
            "--detach",
            str(RUNTIME_WORKTREE_ROOT),
            source_head,
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if completed.returncode != 0:
        raise B.InvalidEvidence("git worktree add failed for alternate runtime")
    checkout_head = _clean_head(
        RUNTIME_WORKTREE_ROOT, "alternate runtime worktree", detached_required=True
    )
    if checkout_head != source_head:
        raise B.InvalidEvidence("materialized runtime HEAD differs from source HEAD")
    _overlay_exact_repository_binding_bytes(
        MAIN_WORKTREE_ROOT,
        RUNTIME_WORKTREE_ROOT,
        relative_paths,
    )
    runtime_head = _clean_head(
        RUNTIME_WORKTREE_ROOT,
        "alternate runtime worktree after exact byte overlay",
        detached_required=True,
    )
    if runtime_head != source_head:
        raise B.InvalidEvidence("overlayed runtime HEAD differs from source HEAD")
    repository_ledger = _build_repository_byte_identity_ledger(
        MAIN_WORKTREE_ROOT,
        RUNTIME_WORKTREE_ROOT,
        relative_paths,
    )
    bootstrap = _runtime_bootstrap_bindings(RUNTIME_WORKTREE_ROOT)
    payload = {
        "schema_version": 1,
        "artifact_type": "QM5_10834_WS30_ALTERNATE_RUNTIME_MATERIALIZATION_RECEIPT",
        "status": "PASS",
        "created_utc": B.utc_now(),
        "source_main_worktree": str(MAIN_WORKTREE_ROOT.resolve()),
        "source_head": source_head,
        "runtime_worktree": str(RUNTIME_WORKTREE_ROOT.resolve()),
        "runtime_head": runtime_head,
        "runtime_detached": True,
        "main_clean_at_materialization": True,
        "runtime_clean_at_materialization": True,
        "checkout_policy": {
            "checkout": "GIT_WORKTREE_ADD_DETACHED_THEN_EXACT_BOUND_FILE_BYTE_OVERLAY",
            "checkout_eol_policy_is_not_evidence": True,
            "exact_overlay_from_clean_source_worktree": True,
            "post_overlay_git_clean": True,
            "post_checkout_byte_identity_required": True,
        },
        "repository_binding_byte_identity_ledger": repository_ledger,
        "bootstrap_bindings": bootstrap,
    }
    digest = B.atomic_json(RUNTIME_RECEIPT_PATH, payload, replace=False)
    return {
        "status": "PASS",
        "runtime_worktree": str(RUNTIME_WORKTREE_ROOT.resolve()),
        "runtime_head": runtime_head,
        "receipt": str(RUNTIME_RECEIPT_PATH.resolve()),
        "sha256": digest,
        "next_tool": str(
            RUNTIME_WORKTREE_ROOT / TOOL_PATH.relative_to(MAIN_WORKTREE_ROOT)
        ),
    }


# Install the alternate hooks into this module's private base-auditor namespace.
B._expected_binding_paths = _expected_binding_paths
B._assert_run_root = _assert_alternate_run_root
B.validate_infra_retry_contract = validate_relocated_primary_transport_contract
B.validate_backtest_data_receipt = validate_relocated_backtest_data_receipt
B.preflight = preflight
B.assert_pre_receipt = assert_pre_receipt
B.execution_contract = execution_contract
B._assert_native_attempt_unclaimed = _assert_native_attempt_unclaimed
B._native_attempt_claim_basis = _native_attempt_claim_basis
B.launch_detached = launch_detached


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if arguments and arguments[0] == "materialize-runtime":
        parser = argparse.ArgumentParser(
            description="Materialize the fixed detached WS30 alternate runtime"
        )
        parser.parse_args(arguments[1:])
        try:
            output = materialize_runtime()
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
            print(
                json.dumps(
                    B.invalid_receipt("MATERIALIZE_RUNTIME", exc),
                    indent=2,
                    sort_keys=True,
                ),
                file=sys.stderr,
            )
            return 2
    args = B.build_parser().parse_args(arguments)
    try:
        _assert_alternate_control_namespace()
        _assert_cli_path_confinement(args)
        if args.command == "status":
            state = B.load_json(args.state)
            if (
                state.get("analysis_id") != ANALYSIS_ID
                or state.get("artifact_type") != "QM5_10834_NATIVE_LAUNCH_STATE"
            ):
                raise B.InvalidEvidence("alternate status state identity drift")
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
        if args.command == "pre":
            # A readiness failure must not consume the canonical one-shot PRE
            # path with an INVALID placeholder.  Only a successful, fully
            # validated PRE is atomically created here.
            payload = preflight(
                args.symbol,
                args.data_receipt,
                args.build_receipt,
                args.run_root,
            )
            digest = B.atomic_json(args.receipt, payload, replace=False)
            print(
                json.dumps(
                    {
                        "status": "PASS",
                        "receipt": str(args.receipt.resolve()),
                        "sha256": digest,
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        return B.main(arguments)
    except (
        B.AuditError,
        OSError,
        subprocess.SubprocessError,
        ValueError,
        KeyError,
        TypeError,
    ) as exc:
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
