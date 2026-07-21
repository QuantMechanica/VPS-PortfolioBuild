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
CREDENTIAL_HELPER_RELATIVE_PATH = Path(
    "framework/scripts/dev2_machine_credential.ps1"
)
IDENTITY_PROBE_CHILD_RELATIVE_PATH = Path(
    "framework/scripts/invoke_dev2_identity_probe.ps1"
)
INVALID_RUNTIME_WORKTREE_ROOT = Path(
    r"C:\QM\runtime_worktrees\QM5_10834_WS30_ALT002"
)
INVALID_RUNTIME_RECEIPT_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\runtime"
    r"\WS30_ICT_OB_TRANSPORT_INFRA_ALTERNATE_002_runtime_receipt.json"
)
RUNTIME_WORKTREE_ROOT = Path(
    r"C:\QM\runtime_worktrees\QM5_10834_WS30_ALT002_FIX001"
)
RUNTIME_RECEIPT_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\runtime"
    r"\WS30_ICT_OB_TRANSPORT_INFRA_ALTERNATE_002_runtime_fix001_receipt.json"
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
    "8414d4d52bf8e3c31d08fc27189ce259cc156695be108052af0ffa55ab22a284"
)
INVALID_RUNTIME_CLOSURE_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "ws30_alt002_runtime_materialization_invalid_closure_20260721.json"
)
RUNTIME_FIX_CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "ws30_transport_infra_alternate002_runtime_fix001_contract_20260721.json"
)
EXPECTED_INVALID_RUNTIME_CLOSURE_SHA256 = (
    "ba32fcfcdd8c5b30efdf8ca5db0816a50d4339950cd334cef2b608e70bbf5674"
)
EXPECTED_RUNTIME_FIX_CONTRACT_SHA256 = (
    "878cae427b5f24f8b82ae72d1b4959527b5425d8501d8631e442157bf2bb45b2"
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
HISTORICAL_MAIN_SCOPED_PATH_COUNT = 53
HISTORICAL_MAIN_SCOPED_PATH_LIST_SHA256 = (
    "1bc5d9e2fe51aa27926bae55e6fb888b3cde1a43a1df08c22e0f78f2b6b8758a"
)
TECHNICAL_DIAGNOSIS_PATH_COUNT = 54
TECHNICAL_DIAGNOSIS_PATH_LIST_SHA256 = (
    "69a9ddbb82904c625a84ae1559d3f6182f1ff14e6820a21d1e019f76556117ed"
)
MAIN_SCOPED_PATH_COUNT = 56
MAIN_SCOPED_PATH_LIST_SHA256 = (
    "b6f88751e1eb4345a48dc041d795c49fa2023da472abe59a115bcb7290ec31fd"
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
            "runtime_fix_contract",
            "invalid_runtime_materialization_closure",
            "primary_invalid_infra_closure",
            "alternate_runtime_materialization_receipt",
            "dev2_identity_probe_child",
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
_BASE_VALIDATE_MACHINE_CREDENTIAL_ROTATION_RECEIPT = (
    B.validate_machine_credential_rotation_receipt
)


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
            "runtime_fix_contract",
            "invalid_runtime_materialization_closure",
            "primary_invalid_infra_closure",
            "alternate_runtime_materialization_receipt",
            "dev2_identity_probe_child",
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


def _normalized_clean_head(root: Path, label: str, *, detached_required: bool) -> str:
    """Require semantic Git cleanliness without trusting stat-only porcelain dirt.

    Exact raw bytes for the bound repository closure are checked separately by the
    source/runtime byte-identity ledger.  This Git gate deliberately uses diff
    exit codes because core.autocrlf can leave the index stat cache describing a
    CRLF checkout after the exact LF overlay, causing porcelain to report `.M`
    even though Git's normalized blob comparison is clean.
    """

    root = W._assert_no_reparse_components(root, label)
    if not root.is_dir():
        raise B.InvalidEvidence(f"{label} does not exist: {root}")
    top = Path(
        _git_at(root, "rev-parse", "--show-toplevel").stdout.strip()
    ).resolve()
    if top != root.resolve():
        raise B.InvalidEvidence(f"{label} top-level drift: {top}")
    head = _git_at(root, "rev-parse", "HEAD^{commit}").stdout.strip().lower()
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        raise B.InvalidEvidence(f"{label} HEAD is malformed")
    staged = _git_at(
        root,
        "diff",
        "--cached",
        "--quiet",
        "--no-ext-diff",
        "--no-textconv",
        "--exit-code",
        "HEAD",
        "--",
        check=False,
    )
    if staged.returncode == 1:
        raise B.InvalidEvidence(f"{label} has a staged diff")
    if staged.returncode != 0:
        raise B.InvalidEvidence(f"{label} staged-diff query failed")
    normalized = _git_at(
        root,
        "diff",
        "--quiet",
        "--no-ext-diff",
        "--no-textconv",
        "--exit-code",
        "--",
        check=False,
    )
    if normalized.returncode == 1:
        raise B.InvalidEvidence(f"{label} has a normalized worktree diff")
    if normalized.returncode != 0:
        raise B.InvalidEvidence(f"{label} normalized-diff query failed")
    # Deliberately do not pass any exclude option: ignored caches/logs are
    # untracked runtime mutations too and must fail the immutable-runtime gate.
    untracked = _git_at(root, "ls-files", "--others", "-z").stdout
    if untracked:
        raise B.InvalidEvidence(f"{label} has untracked files")
    symbolic = _git_at(root, "symbolic-ref", "-q", "HEAD", check=False)
    if detached_required and not (
        symbolic.returncode == 1 and not symbolic.stdout.strip()
    ):
        raise B.InvalidEvidence(f"{label} must be detached")
    return head


def _scoped_clean_head(
    root: Path,
    label: str,
    relative_paths: Sequence[str],
    *,
    detached_required: bool,
) -> str:
    root = W._assert_no_reparse_components(root, label)
    if not root.is_dir():
        raise B.InvalidEvidence(f"{label} does not exist: {root}")
    top = Path(
        _git_at(root, "rev-parse", "--show-toplevel").stdout.strip()
    ).resolve()
    if top != root.resolve():
        raise B.InvalidEvidence(f"{label} top-level drift: {top}")
    normalized: list[str] = []
    for index, relative_text in enumerate(relative_paths):
        relative = Path(str(relative_text))
        if relative.is_absolute() or any(
            part in {"", ".", ".."} for part in relative.parts
        ):
            raise B.InvalidEvidence(f"unsafe scoped path[{index}]: {relative_text}")
        normalized.append(relative.as_posix())
    if normalized != sorted(set(normalized), key=str.casefold) or not normalized:
        raise B.InvalidEvidence("scoped path set must be non-empty, unique, and sorted")
    literal_pathspecs = tuple(f":(literal){relative}" for relative in normalized)
    status = _git_at(
        root,
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
        "--",
        *literal_pathspecs,
    ).stdout
    if status:
        raise B.InvalidEvidence(f"{label} has dirt in the exact scoped path set")
    head = _git_at(root, "rev-parse", "HEAD^{commit}").stdout.strip().lower()
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        raise B.InvalidEvidence(f"{label} HEAD is malformed")
    symbolic = _git_at(root, "symbolic-ref", "-q", "HEAD", check=False)
    if detached_required and not (
        symbolic.returncode == 1 and not symbolic.stdout.strip()
    ):
        raise B.InvalidEvidence(f"{label} must be detached")
    return head


def assert_main_scoped_paths_clean(stage: str) -> str:
    return _scoped_clean_head(
        MAIN_WORKTREE_ROOT,
        f"main worktree scoped dependencies at {stage}",
        _main_scoped_relative_paths(),
        detached_required=False,
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
        != INVALID_RUNTIME_WORKTREE_ROOT.resolve()
        or runtime.get("runtime_tool_relative_path")
        != str(TOOL_PATH.relative_to(REPO_ROOT)).replace("\\", "/")
        or any(
            runtime.get(key) is not True
            for key in (
                "main_worktree_scoped_paths_must_be_clean_at_materialization",
                "main_worktree_scoped_paths_must_be_clean_at_pre",
                "main_worktree_scoped_paths_must_be_clean_at_launch",
                "unrelated_main_worktree_paths_may_be_dirty",
                "runtime_worktree_must_be_new",
                "runtime_worktree_must_be_detached",
                "runtime_worktree_must_be_normalized_clean",
                "runtime_worktree_staged_diff_forbidden",
                "runtime_worktree_untracked_files_forbidden",
                "runtime_worktree_porcelain_status_is_not_cleanliness_authority",
                "runtime_worktree_must_not_equal_main_worktree",
                "runtime_root_reparse_components_forbidden",
                "exact_bound_file_byte_overlay_required",
                "post_overlay_normalized_git_clean_required",
                "post_overlay_exact_raw_byte_ledger_required",
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
    scoped_policy = runtime.get("main_worktree_scoped_path_policy")
    if not isinstance(scoped_policy, Mapping) or scoped_policy != {
        "basis": "EXACT_RUNTIME_PRE_INCLUDE_AND_CONTRACT_ARTIFACT_DEPENDENCY_CLOSURE",
        "path_count": HISTORICAL_MAIN_SCOPED_PATH_COUNT,
        "relative_path_list_canonical_sha256": (
            HISTORICAL_MAIN_SCOPED_PATH_LIST_SHA256
        ),
        "git_status_uses_literal_pathspecs_only": True,
        "source_to_runtime_exact_byte_identity_required": True,
    }:
        raise B.InvalidEvidence("alternate main-worktree scoped-path policy drift")
    runtime_cleanliness = runtime.get("runtime_worktree_cleanliness_policy")
    if not isinstance(runtime_cleanliness, Mapping) or runtime_cleanliness != {
        "staged_diff": "GIT_DIFF_CACHED_QUIET_EXIT_ZERO_REQUIRED",
        "normalized_worktree_diff": "GIT_DIFF_QUIET_EXIT_ZERO_REQUIRED",
        "untracked_files": (
            "GIT_LS_FILES_OTHERS_INCLUDING_IGNORED_EMPTY_REQUIRED"
        ),
        "porcelain_status": (
            "NON_AUTHORITATIVE_DUE_TO_AUTOCRLF_INDEX_STAT_FALSE_POSITIVES"
        ),
        "raw_bound_file_bytes": (
            "EXACT_SOURCE_RUNTIME_SHA256_SIZE_LEDGER_REQUIRED"
        ),
    }:
        raise B.InvalidEvidence("alternate runtime-cleanliness policy drift")
    launch_gate = payload.get("launch_gate")
    if not isinstance(launch_gate, Mapping) or (
        launch_gate.get(
            "scoped_main_paths_and_normalized_clean_runtime_required"
        )
        is not True
        or launch_gate.get("unrelated_main_worktree_dirt_does_not_block") is not True
        or launch_gate.get("launch_not_authorized_by_this_contract") is not True
    ):
        raise B.InvalidEvidence("alternate scoped launch gate drift")
    B.assert_binding(binding, "alternate execution contract")
    return payload


def validate_invalid_runtime_materialization_closure() -> dict[str, Any]:
    binding = B.file_binding(
        INVALID_RUNTIME_CLOSURE_PATH, EXPECTED_INVALID_RUNTIME_CLOSURE_SHA256
    )
    if binding["size"] != 4477:
        raise B.InvalidEvidence("invalid-runtime closure size drift")
    payload = B.load_json(INVALID_RUNTIME_CLOSURE_PATH)
    if set(payload) != {
        "schema_version",
        "artifact_type",
        "status",
        "created_utc",
        "analysis_id",
        "native_attempt",
        "historical_contract",
        "invalid_materialization",
        "credential_rotation_evidence",
        "outcome_fence",
        "disposition",
    } or (
        payload.get("schema_version") != 1
        or payload.get("artifact_type")
        != "QM5_10834_WS30_ALT002_RUNTIME_MATERIALIZATION_INVALID_CLOSURE"
        or payload.get("status")
        != "INVALID_RUNTIME_MATERIALIZATION_CLOSED_BEFORE_PRE_ATTEMPT_UNCONSUMED"
        or payload.get("analysis_id") != ANALYSIS_ID
    ):
        raise B.InvalidEvidence("invalid-runtime closure identity drift")
    W._strict_created_utc(payload.get("created_utc"), "invalid-runtime closure created_utc")

    if payload.get("native_attempt") != {
        "attempt_number": 2,
        "claim_sequence": 2,
        "run_root": str(ALTERNATE_RUN_ROOT),
        "claim_path": str(ALTERNATE_CLAIM_PATH),
        "pre_receipt_created": False,
        "authorization_created": False,
        "claim_created": False,
        "launch_job_created": False,
        "launch_state_created": False,
        "native_process_started": False,
        "attempt_consumed": False,
    }:
        raise B.InvalidEvidence("invalid-runtime closure attempt-consumption drift")
    expected_historical_contract = {
        "path": (
            "framework/EAs/QM5_10834_tv-nq-ict-ob/docs/candidate-analysis/"
            "ws30_transport_infra_alternate002_contract_20260721.json"
        ),
        "size": 7777,
        "sha256": EXPECTED_ALTERNATE_CONTRACT_SHA256,
    }
    if payload.get("historical_contract") != expected_historical_contract:
        raise B.InvalidEvidence("invalid-runtime historical contract drift")

    invalid_runtime_receipt = {
        "path": str(INVALID_RUNTIME_RECEIPT_PATH),
        "size": 13053,
        "sha256": (
            "5877c55922fae1a57e975709fef606662137e480ed251ec30ba4f6d5d1a5149c"
        ),
    }
    invalid_materialization = payload.get("invalid_materialization")
    if not isinstance(invalid_materialization, Mapping) or invalid_materialization != {
        "runtime_worktree": str(INVALID_RUNTIME_WORKTREE_ROOT),
        "runtime_receipt": invalid_runtime_receipt,
        "runtime_head": "e39e54093e88fabdf5ee41d4f394715fe222269e",
        "materialization_receipt_status": "PASS",
        "materialization_created_utc": "2026-07-21T09:51:01.870458+00:00",
        "repository_binding_path_count": HISTORICAL_MAIN_SCOPED_PATH_COUNT,
        "repository_binding_path_list_canonical_sha256": (
            HISTORICAL_MAIN_SCOPED_PATH_LIST_SHA256
        ),
        "classification": (
            "MECHANICALLY_SEALED_BUT_PRE_UNEXECUTABLE_CREDENTIAL_RUNTIME_BINDING"
        ),
        "failure_stage": "PRE_MACHINE_CREDENTIAL_ROTATION_RECEIPT_VALIDATION",
        "must_remain_immutable": True,
        "must_never_be_resumed": True,
    }:
        raise B.InvalidEvidence("invalid-runtime materialization facts drift")

    old_receipt_binding = B.file_binding(
        INVALID_RUNTIME_RECEIPT_PATH, invalid_runtime_receipt["sha256"]
    )
    if old_receipt_binding != invalid_runtime_receipt:
        raise B.InvalidEvidence("invalid runtime receipt binding drift")
    old_receipt = B.load_json(INVALID_RUNTIME_RECEIPT_PATH)
    if (
        old_receipt.get("artifact_type")
        != "QM5_10834_WS30_ALTERNATE_RUNTIME_MATERIALIZATION_RECEIPT"
        or old_receipt.get("status") != "PASS"
        or old_receipt.get("runtime_worktree") != str(INVALID_RUNTIME_WORKTREE_ROOT)
        or old_receipt.get("runtime_head")
        != "e39e54093e88fabdf5ee41d4f394715fe222269e"
        or old_receipt.get("main_scoped_path_count")
        != HISTORICAL_MAIN_SCOPED_PATH_COUNT
        or old_receipt.get("main_scoped_path_list_canonical_sha256")
        != HISTORICAL_MAIN_SCOPED_PATH_LIST_SHA256
    ):
        raise B.InvalidEvidence("invalid runtime receipt frozen facts drift")
    historical_runtime_bindings = (
        (
            INVALID_RUNTIME_WORKTREE_ROOT
            / "framework"
            / "EAs"
            / "QM5_10834_tv-nq-ict-ob"
            / "docs"
            / "candidate-analysis"
            / "ws30_transport_infra_alternate002_contract_20260721.json",
            7777,
            EXPECTED_ALTERNATE_CONTRACT_SHA256,
            "historical alternate contract",
        ),
        (
            INVALID_RUNTIME_WORKTREE_ROOT / CREDENTIAL_HELPER_RELATIVE_PATH,
            23740,
            "bd3077f5ff671d80a377a820e35cd233cdf8ad1b25d376d579da4714c323ad2c",
            "historical runtime credential helper",
        ),
        (
            INVALID_RUNTIME_WORKTREE_ROOT / IDENTITY_PROBE_CHILD_RELATIVE_PATH,
            10102,
            "140c361e7f0f40d28ef8a6a8edf103133b3cb0fe30496fc9dad6a64dc59d69ad",
            "historical runtime identity child",
        ),
    )
    for historical_path, historical_size, historical_sha, label in (
        historical_runtime_bindings
    ):
        historical_binding = B.file_binding(historical_path, historical_sha)
        if historical_binding["size"] != historical_size:
            raise B.InvalidEvidence(f"{label} size drift")
    old_ledger = old_receipt.get("repository_binding_byte_identity_ledger")
    if not isinstance(old_ledger, list) or len(old_ledger) != 53:
        raise B.InvalidEvidence("invalid runtime 53-path ledger drift")
    for index, row in enumerate(old_ledger):
        if not isinstance(row, Mapping) or set(row) != {
            "relative_path",
            "size",
            "sha256",
        }:
            raise B.InvalidEvidence(f"invalid runtime ledger row[{index}] drift")
        relative = Path(str(row.get("relative_path", "")))
        if relative.is_absolute() or any(
            part in {"", ".", ".."} for part in relative.parts
        ):
            raise B.InvalidEvidence(f"invalid runtime ledger path[{index}] unsafe")
        old_runtime_binding = B.file_binding(
            INVALID_RUNTIME_WORKTREE_ROOT / relative,
            str(row.get("sha256", "")),
        )
        if old_runtime_binding["size"] != int(row.get("size")):
            raise B.InvalidEvidence(f"invalid runtime ledger size[{index}] drift")
    old_rows = {
        str(row.get("relative_path", "")): row
        for row in old_ledger
        if isinstance(row, Mapping)
    }
    if IDENTITY_PROBE_CHILD_RELATIVE_PATH.as_posix() in old_rows or old_rows.get(
        CREDENTIAL_HELPER_RELATIVE_PATH.as_posix()
    ) != {
        "relative_path": CREDENTIAL_HELPER_RELATIVE_PATH.as_posix(),
        "size": 23740,
        "sha256": (
            "bd3077f5ff671d80a377a820e35cd233cdf8ad1b25d376d579da4714c323ad2c"
        ),
    }:
        raise B.InvalidEvidence("invalid runtime credential ledger diagnosis drift")

    credential_evidence = payload.get("credential_rotation_evidence")
    if not isinstance(credential_evidence, Mapping) or set(credential_evidence) != {
        "signed_receipt",
        "machine_credential_helper",
        "identity_probe_child",
    }:
        raise B.InvalidEvidence("invalid-runtime credential evidence closure drift")
    signed_receipt = {
        "path": str(B.MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH),
        "size": 1624,
        "sha256": (
            "019b7f01fdce4d83db9fc51b7583fb0b729a6c662a6fead61dde01ede3022244"
        ),
    }
    if credential_evidence.get("signed_receipt") != signed_receipt:
        raise B.InvalidEvidence("invalid-runtime signed receipt binding drift")
    if B.file_binding(
        B.MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH, signed_receipt["sha256"]
    ) != signed_receipt:
        raise B.InvalidEvidence("invalid-runtime current signed receipt drift")
    signed_payload = B.load_json(B.MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH)
    helper_sha = "bd3077f5ff671d80a377a820e35cd233cdf8ad1b25d376d579da4714c323ad2c"
    child_sha = "fa14caeacfef311a30717e31e553d8c93b1eaa66a8495b63debfee5957f96f48"
    if (
        signed_payload.get("machine_credential_helper_path")
        != str(MAIN_WORKTREE_ROOT / CREDENTIAL_HELPER_RELATIVE_PATH)
        or signed_payload.get("machine_credential_helper_sha256") != helper_sha
        or signed_payload.get("identity_probe_child_path")
        != str(MAIN_WORKTREE_ROOT / IDENTITY_PROBE_CHILD_RELATIVE_PATH)
        or signed_payload.get("identity_probe_child_sha256") != child_sha
    ):
        raise B.InvalidEvidence("invalid-runtime signed credential provenance drift")
    if credential_evidence.get("machine_credential_helper") != {
        "signed_origin_path": str(MAIN_WORKTREE_ROOT / CREDENTIAL_HELPER_RELATIVE_PATH),
        "signed_sha256": helper_sha,
        "main_origin_size": 23740,
        "invalid_runtime_path": str(
            INVALID_RUNTIME_WORKTREE_ROOT / CREDENTIAL_HELPER_RELATIVE_PATH
        ),
        "invalid_runtime_size": 23740,
        "invalid_runtime_sha256": helper_sha,
        "bytes_match_but_signed_path_is_origin_only": True,
    }:
        raise B.InvalidEvidence("invalid-runtime helper diagnosis drift")
    if credential_evidence.get("identity_probe_child") != {
        "signed_origin_path": str(MAIN_WORKTREE_ROOT / IDENTITY_PROBE_CHILD_RELATIVE_PATH),
        "signed_sha256": child_sha,
        "main_origin_size": 9886,
        "invalid_runtime_path": str(
            INVALID_RUNTIME_WORKTREE_ROOT / IDENTITY_PROBE_CHILD_RELATIVE_PATH
        ),
        "invalid_runtime_size": 10102,
        "invalid_runtime_sha256": (
            "140c361e7f0f40d28ef8a6a8edf103133b3cb0fe30496fc9dad6a64dc59d69ad"
        ),
        "missing_from_53_path_overlay_and_byte_ledger": True,
        "runtime_bytes_do_not_match_signed_hash": True,
    }:
        raise B.InvalidEvidence("invalid-runtime identity-child diagnosis drift")

    if payload.get("outcome_fence") != {
        "pre_receipt_opened": False,
        "native_reports_opened": False,
        "controller_logs_opened": False,
        "deal_rows_parsed": False,
        "market_values_parsed": False,
        "strategy_outcomes_read": False,
        "strategy_merit_adjudicated": False,
    }:
        raise B.InvalidEvidence("invalid-runtime outcome fence drift")
    disposition = payload.get("disposition")
    if not isinstance(disposition, Mapping) or (
        any(value is not True for key, value in disposition.items() if key != "superseding_contract_path")
        or disposition.get("superseding_contract_path")
        != (
            "framework/EAs/QM5_10834_tv-nq-ict-ob/docs/candidate-analysis/"
            "ws30_transport_infra_alternate002_runtime_fix001_contract_20260721.json"
        )
    ):
        raise B.InvalidEvidence("invalid-runtime disposition drift")
    B.assert_binding(signed_receipt, "signed machine-credential rotation receipt")
    B.assert_binding(old_receipt_binding, "historical invalid runtime receipt")
    B.assert_binding(binding, "invalid-runtime materialization closure")
    return payload


def _assert_fix001_native_attempt_still_unconsumed(stage: str) -> None:
    """Reassert closure-time absence only before FIX001 materialization/PRE.

    The same ALT002 namespace is intentionally retained.  Therefore PRE and
    authorization files may legitimately exist later and must not invalidate
    the historical closure during launch/worker validation.
    """

    for candidate, label in (
        (ALTERNATE_PRE_RECEIPT_PATH, "PRE receipt"),
        (ALTERNATE_AUTHORIZATION_PATH, "authorization"),
        (ALTERNATE_CLAIM_PATH, "claim"),
        (ALTERNATE_JOB_PATH, "launch job"),
        (ALTERNATE_STATE_PATH, "launch state"),
        (ALTERNATE_POST_RECEIPT_PATH, "POST receipt"),
    ):
        if candidate.exists():
            raise B.InvalidEvidence(
                f"FIX001 {stage} requires unconsumed ALT002; {label} exists"
            )


def validate_runtime_fix_contract() -> dict[str, Any]:
    binding = B.file_binding(
        RUNTIME_FIX_CONTRACT_PATH, EXPECTED_RUNTIME_FIX_CONTRACT_SHA256
    )
    if binding["size"] != 5920:
        raise B.InvalidEvidence("runtime FIX001 contract size drift")
    payload = B.load_json(RUNTIME_FIX_CONTRACT_PATH)
    if set(payload) != {
        "schema_version",
        "artifact_type",
        "status",
        "created_utc",
        "analysis_id",
        "fix_id",
        "historical_attempt_contract",
        "invalid_materialization_closure",
        "native_attempt_identity",
        "superseding_runtime_materialization",
        "dependency_closure",
        "credential_receipt_origin_projection",
        "frozen_native_evidence",
        "outcome_fence",
        "launch_gate",
    } or (
        payload.get("schema_version") != 1
        or payload.get("artifact_type")
        != "QM5_10834_WS30_ALT002_SUPERSEDING_RUNTIME_MATERIALIZATION_CONTRACT"
        or payload.get("status")
        != "IMPLEMENTED_NOT_MATERIALIZED_NOT_AUTHORIZED_NOT_LAUNCHED"
        or payload.get("analysis_id") != ANALYSIS_ID
        or payload.get("fix_id") != "WS30_ALT002_RUNTIME_FIX001"
    ):
        raise B.InvalidEvidence("runtime FIX001 contract identity drift")
    W._strict_created_utc(payload.get("created_utc"), "runtime FIX001 created_utc")
    if payload.get("historical_attempt_contract") != {
        "path": (
            "framework/EAs/QM5_10834_tv-nq-ict-ob/docs/candidate-analysis/"
            "ws30_transport_infra_alternate002_contract_20260721.json"
        ),
        "size": 7777,
        "sha256": EXPECTED_ALTERNATE_CONTRACT_SHA256,
    } or payload.get("invalid_materialization_closure") != {
        "path": (
            "framework/EAs/QM5_10834_tv-nq-ict-ob/docs/candidate-analysis/"
            "ws30_alt002_runtime_materialization_invalid_closure_20260721.json"
        ),
        "size": 4477,
        "sha256": EXPECTED_INVALID_RUNTIME_CLOSURE_SHA256,
        "required_status": (
            "INVALID_RUNTIME_MATERIALIZATION_CLOSED_BEFORE_PRE_ATTEMPT_UNCONSUMED"
        ),
    }:
        raise B.InvalidEvidence("runtime FIX001 predecessor binding drift")
    if payload.get("native_attempt_identity") != {
        "attempt_number": 2,
        "claim_sequence": 2,
        "maximum_total_attempts": 2,
        "run_root": str(ALTERNATE_RUN_ROOT),
        "claim_path": str(ALTERNATE_CLAIM_PATH),
        "authorization_scope": ALTERNATE_AUTHORIZATION_SCOPE,
        "pre_receipt_created_before_fix": False,
        "authorization_created_before_fix": False,
        "claim_created_before_fix": False,
        "launch_created_before_fix": False,
        "attempt_consumed_before_fix": False,
        "same_native_attempt_not_a_retry": True,
        "resume_forbidden": True,
        "further_attempts_forbidden": True,
    }:
        raise B.InvalidEvidence("runtime FIX001 native-attempt identity drift")
    if payload.get("superseding_runtime_materialization") != {
        "scope": "RUNTIME_MATERIALIZATION_ONLY",
        "invalid_runtime_worktree": str(INVALID_RUNTIME_WORKTREE_ROOT),
        "invalid_runtime_receipt": str(INVALID_RUNTIME_RECEIPT_PATH),
        "invalid_runtime_and_receipt_must_remain_immutable": True,
        "runtime_worktree_root": str(RUNTIME_WORKTREE_ROOT),
        "runtime_receipt_path": str(RUNTIME_RECEIPT_PATH),
        "runtime_worktree_must_be_new": True,
        "runtime_receipt_atomic_create_once": True,
        "runtime_worktree_must_be_detached": True,
        "runtime_worktree_must_be_normalized_clean": True,
        "runtime_worktree_staged_diff_forbidden": True,
        "runtime_worktree_untracked_files_forbidden": True,
        "runtime_worktree_porcelain_status_is_not_cleanliness_authority": True,
        "runtime_root_reparse_components_forbidden": True,
        "all_bound_files_exact_byte_overlay_required": True,
        "all_bound_files_source_runtime_byte_identity_required": True,
        "worker_reasserts_runtime_provenance_before_each_native_cell": True,
    }:
        raise B.InvalidEvidence("runtime FIX001 materialization namespace drift")
    if payload.get("dependency_closure") != {
        "historical_materialization_path_count": HISTORICAL_MAIN_SCOPED_PATH_COUNT,
        "historical_materialization_path_list_canonical_sha256": (
            HISTORICAL_MAIN_SCOPED_PATH_LIST_SHA256
        ),
        "technical_diagnosis_path_count": TECHNICAL_DIAGNOSIS_PATH_COUNT,
        "technical_diagnosis_path_list_canonical_sha256": (
            TECHNICAL_DIAGNOSIS_PATH_LIST_SHA256
        ),
        "technical_diagnosis_adds_identity_probe_child": True,
        "executable_fix001_path_count": MAIN_SCOPED_PATH_COUNT,
        "executable_fix001_path_list_canonical_sha256": MAIN_SCOPED_PATH_LIST_SHA256,
        "executable_fix001_also_adds_invalid_closure_and_fix_contract": True,
        "all_56_paths_raw_byte_identical_and_clean_required": True,
        "git_status_uses_literal_pathspecs_only": True,
    }:
        raise B.InvalidEvidence("runtime FIX001 dependency closure drift")
    if payload.get("credential_receipt_origin_projection") != {
        "signed_machine_credential_helper_path_must_equal": str(
            MAIN_WORKTREE_ROOT / CREDENTIAL_HELPER_RELATIVE_PATH
        ),
        "signed_identity_probe_child_path_must_equal": str(
            MAIN_WORKTREE_ROOT / IDENTITY_PROBE_CHILD_RELATIVE_PATH
        ),
        "signed_helper_hash_must_equal_bound_runtime_helper_hash": True,
        "signed_identity_child_hash_must_equal_bound_runtime_child_hash": True,
        "bound_helper_path_must_be_exact_fix001_runtime_relative_path": True,
        "bound_identity_child_path_must_be_exact_fix001_runtime_relative_path": True,
        "main_origin_files_must_not_be_opened_by_pre_or_worker": True,
        "temporary_in_memory_projection_only": True,
        "load_hook_must_be_restored_in_finally": True,
        "reported_receipt_payload_hash_must_describe_raw_signed_payload": True,
    }:
        raise B.InvalidEvidence("runtime FIX001 credential projection policy drift")
    if payload.get("frozen_native_evidence") != {
        "research_symbol": RESEARCH_SYMBOL,
        "timeframe": "M5",
        "model": 4,
        "duplicates_per_cell": 2,
        "maximum_attempts_per_cell": 4,
        "same_build_and_ea_binary": True,
        "same_tick_data_receipt": True,
        "same_set_and_strategy_parameters": True,
        "same_dev_and_oos_windows": True,
        "same_cost_schedule": True,
        "same_merit_gates_and_auditor": True,
        "parameter_tuning_forbidden": True,
        "gate_relaxation_forbidden": True,
    }:
        raise B.InvalidEvidence("runtime FIX001 frozen native evidence drift")
    if payload.get("outcome_fence") != {
        "invalid_materialization_native_reports_opened": False,
        "invalid_materialization_controller_logs_opened": False,
        "strategy_outcomes_read": False,
        "strategy_merit_adjudicated": False,
        "fix001_pre_reads_no_native_reports_or_outcomes": True,
        "post_requires_complete_state": True,
    } or payload.get("launch_gate") != {
        "this_contract_does_not_authorize_native_launch": True,
        "fix001_materialization_receipt_required": True,
        "fresh_owner_authorization_at_existing_alt002_path_required": True,
        "successful_pre_at_existing_alt002_path_required": True,
        "existing_alt002_claim_must_still_be_absent_before_launch": True,
        "old_runtime_must_never_be_used_or_resumed": True,
    }:
        raise B.InvalidEvidence("runtime FIX001 outcome/launch fence drift")
    B.assert_binding(binding, "runtime FIX001 materialization contract")
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


def _lexically_equal(left: Path | str, right: Path | str) -> bool:
    return os.path.normcase(str(W._lexical_path(left))) == os.path.normcase(
        str(W._lexical_path(right))
    )


def _path_text_is_exact(left: Path | str, right: Path | str) -> bool:
    """Compare absolute Windows path text without normalizing aliases."""

    left_text = os.fspath(left)
    right_text = os.fspath(right)
    return (
        Path(left_text).is_absolute()
        and Path(right_text).is_absolute()
        and os.path.normcase(left_text) == os.path.normcase(right_text)
    )


def _exact_runtime_binding(
    bindings: Mapping[str, Any],
    role: str,
    relative_path: Path,
    module_path: Path,
    label: str,
) -> dict[str, Any]:
    item = bindings.get(role)
    if not isinstance(item, Mapping) or set(item) != {"path", "size", "sha256"}:
        raise B.InvalidEvidence(f"{label} runtime binding field closure drift")
    expected_path = REPO_ROOT / relative_path
    if not _path_text_is_exact(module_path, expected_path):
        raise B.InvalidEvidence(f"{label} module runtime path drift")
    if not _path_text_is_exact(str(item.get("path", "")), expected_path):
        raise B.InvalidEvidence(f"{label} bound path is not the exact runtime path")
    W._assert_no_reparse_components(expected_path, f"{label} runtime binding")
    B.assert_binding(item, f"{label} runtime binding")
    return dict(item)


def validate_relocated_machine_credential_rotation_receipt(
    bindings: Mapping[str, Any], *, now: datetime | None = None
) -> dict[str, Any]:
    """Validate signed main-origin provenance against runtime-only helper bytes.

    The externally signed rotation receipt predates the detached worktree and
    therefore records the canonical main-worktree paths for both PowerShell
    helpers.  Those strings are provenance only: PRE and the worker must never
    open either main-worktree file.  Their signed hashes must instead match the
    two exact, ledger-covered runtime copies before the frozen base validator is
    given a temporary in-memory path projection.
    """

    receipt_binding = bindings.get("dev2_machine_credential_rotation_receipt")
    if not isinstance(receipt_binding, Mapping) or set(receipt_binding) != {
        "path",
        "size",
        "sha256",
    }:
        raise B.InvalidEvidence(
            "machine-credential rotation receipt binding field closure drift"
        )
    receipt_path = Path(str(receipt_binding.get("path", "")))
    if not _path_text_is_exact(
        receipt_path, B.MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH
    ):
        raise B.InvalidEvidence("machine-credential rotation receipt path drift")
    B.assert_binding(receipt_binding, "machine-credential rotation receipt")

    helper_binding = _exact_runtime_binding(
        bindings,
        "dev2_machine_credential_helper",
        CREDENTIAL_HELPER_RELATIVE_PATH,
        B.CREDENTIAL_HELPER_PATH,
        "machine-credential helper",
    )
    child_binding = _exact_runtime_binding(
        bindings,
        "dev2_identity_probe_child",
        IDENTITY_PROBE_CHILD_RELATIVE_PATH,
        B.IDENTITY_PROBE_CHILD_PATH,
        "identity-probe child",
    )

    saved_loader = B.load_json
    raw_payload = saved_loader(receipt_path)
    if not isinstance(raw_payload, Mapping):
        raise B.InvalidEvidence("machine-credential rotation receipt is not an object")
    raw_receipt = copy.deepcopy(dict(raw_payload))

    origin_helper = MAIN_WORKTREE_ROOT / CREDENTIAL_HELPER_RELATIVE_PATH
    origin_child = MAIN_WORKTREE_ROOT / IDENTITY_PROBE_CHILD_RELATIVE_PATH
    if not _path_text_is_exact(
        str(raw_receipt.get("machine_credential_helper_path", "")), origin_helper
    ):
        raise B.InvalidEvidence(
            "machine-credential receipt helper origin path is not canonical"
        )
    if (
        str(raw_receipt.get("machine_credential_helper_sha256", "")).lower()
        != helper_binding["sha256"]
    ):
        raise B.InvalidEvidence(
            "machine-credential receipt helper hash differs from runtime binding"
        )
    if not _path_text_is_exact(
        str(raw_receipt.get("identity_probe_child_path", "")), origin_child
    ):
        raise B.InvalidEvidence(
            "machine-credential receipt identity-child origin path is not canonical"
        )
    if (
        str(raw_receipt.get("identity_probe_child_sha256", "")).lower()
        != child_binding["sha256"]
    ):
        raise B.InvalidEvidence(
            "machine-credential receipt identity-child hash differs from runtime binding"
        )

    projected_receipt = copy.deepcopy(raw_receipt)
    projected_receipt["machine_credential_helper_path"] = helper_binding["path"]
    projected_receipt["identity_probe_child_path"] = child_binding["path"]
    receipt_lexical = W._lexical_path(receipt_path)

    def projected_loader(candidate: Path) -> Any:
        candidate_lexical = W._lexical_path(candidate)
        if _lexically_equal(candidate_lexical, receipt_lexical):
            return copy.deepcopy(projected_receipt)
        if _main_repo_relative(candidate_lexical) is not None:
            raise B.InvalidEvidence(
                "machine-credential validation attempted to open main-worktree evidence"
            )
        return saved_loader(candidate)

    B.load_json = projected_loader
    try:
        validated_raw = _BASE_VALIDATE_MACHINE_CREDENTIAL_ROTATION_RECEIPT(
            bindings, now=now
        )
    finally:
        B.load_json = saved_loader

    if not isinstance(validated_raw, Mapping):
        raise B.InvalidEvidence("machine-credential rotation validator result drift")
    validated = dict(validated_raw)
    if (
        validated.get("receipt_payload_sha256")
        != B.canonical_sha256(projected_receipt)
        or validated.get("machine_credential_helper") != helper_binding
        or validated.get("identity_probe_child") != child_binding
    ):
        raise B.InvalidEvidence(
            "machine-credential projected runtime validation result drift"
        )

    # The receipt binding and payload digest always describe the signed raw
    # bytes, not the temporary in-memory projection used by the base validator.
    B.assert_binding(receipt_binding, "machine-credential rotation receipt")
    B.assert_binding(helper_binding, "machine-credential helper runtime binding")
    B.assert_binding(child_binding, "identity-probe child runtime binding")
    validated["receipt_payload_sha256"] = B.canonical_sha256(raw_receipt)
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
            "runtime_fix_contract": RUNTIME_FIX_CONTRACT_PATH,
            "invalid_runtime_materialization_closure": (
                INVALID_RUNTIME_CLOSURE_PATH
            ),
            "primary_invalid_infra_closure": PRIMARY_CLOSURE_PATH,
            "alternate_runtime_materialization_receipt": RUNTIME_RECEIPT_PATH,
            "dev2_identity_probe_child": (
                REPO_ROOT / IDENTITY_PROBE_CHILD_RELATIVE_PATH
            ),
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
        (INVALID_RUNTIME_WORKTREE_ROOT, "invalid historical runtime root"),
        (INVALID_RUNTIME_RECEIPT_PATH, "invalid historical runtime receipt"),
        (RUNTIME_WORKTREE_ROOT, "FIX001 runtime root"),
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


def _main_scoped_relative_paths() -> tuple[str, ...]:
    relative_paths = _repository_binding_relative_paths(REPO_ROOT)
    if (
        len(relative_paths) != MAIN_SCOPED_PATH_COUNT
        or B.canonical_sha256(list(relative_paths)) != MAIN_SCOPED_PATH_LIST_SHA256
    ):
        raise B.InvalidEvidence("main scoped dependency path-set identity drift")
    return relative_paths


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
        "runtime_fix_contract": RUNTIME_FIX_CONTRACT_PATH.relative_to(REPO_ROOT),
        "invalid_runtime_materialization_closure": (
            INVALID_RUNTIME_CLOSURE_PATH.relative_to(REPO_ROOT)
        ),
        "primary_invalid_infra_closure": PRIMARY_CLOSURE_PATH.relative_to(REPO_ROOT),
    }
    return {
        role: B.file_binding(root / relative)
        for role, relative in relative_paths.items()
    }


def _runtime_cleanliness_claim() -> dict[str, bool]:
    return {
        "staged_diff_absent": True,
        "normalized_worktree_diff_absent": True,
        "untracked_files_absent": True,
        "porcelain_status_is_not_cleanliness_authority": True,
        "raw_bound_file_byte_identity_ledger_verified": True,
    }


def validate_runtime_materialization_receipt() -> dict[str, Any]:
    binding = B.file_binding(RUNTIME_RECEIPT_PATH)
    payload = B.load_json(RUNTIME_RECEIPT_PATH)
    expected_keys = {
        "schema_version",
        "artifact_type",
        "runtime_fix_id",
        "status",
        "created_utc",
        "source_main_worktree",
        "source_head",
        "runtime_worktree",
        "runtime_head",
        "runtime_detached",
        "main_scoped_paths_clean_at_materialization",
        "main_scoped_path_count",
        "main_scoped_path_list_canonical_sha256",
        "unrelated_main_worktree_dirt_ignored",
        "runtime_cleanliness_at_materialization",
        "checkout_policy",
        "repository_binding_byte_identity_ledger",
        "bootstrap_bindings",
    }
    if set(payload) != expected_keys or (
        payload.get("schema_version") != 1
        or payload.get("artifact_type")
        != "QM5_10834_WS30_ALT002_FIX001_RUNTIME_MATERIALIZATION_RECEIPT"
        or payload.get("runtime_fix_id") != "WS30_ALT002_RUNTIME_FIX001"
        or payload.get("status") != "PASS"
        or Path(str(payload.get("source_main_worktree", ""))).resolve()
        != MAIN_WORKTREE_ROOT.resolve()
        or Path(str(payload.get("runtime_worktree", ""))).resolve()
        != RUNTIME_WORKTREE_ROOT.resolve()
        or payload.get("runtime_detached") is not True
        or payload.get("main_scoped_paths_clean_at_materialization") is not True
        or payload.get("main_scoped_path_count") != MAIN_SCOPED_PATH_COUNT
        or payload.get("main_scoped_path_list_canonical_sha256")
        != MAIN_SCOPED_PATH_LIST_SHA256
        or payload.get("unrelated_main_worktree_dirt_ignored") is not True
        or payload.get("runtime_cleanliness_at_materialization")
        != _runtime_cleanliness_claim()
    ):
        raise B.InvalidEvidence("alternate runtime receipt identity drift")
    if payload.get("checkout_policy") != {
        "checkout": "GIT_WORKTREE_ADD_DETACHED_THEN_EXACT_BOUND_FILE_BYTE_OVERLAY",
        "checkout_eol_policy_is_not_evidence": True,
        "exact_overlay_from_clean_source_worktree": True,
        "post_overlay_normalized_git_clean": True,
        "post_overlay_porcelain_status_is_not_evidence": True,
        "post_checkout_byte_identity_required": True,
    }:
        raise B.InvalidEvidence("alternate runtime LF checkout policy drift")
    W._strict_created_utc(payload.get("created_utc"), "runtime materialization created_utc")
    runtime_head = _normalized_clean_head(
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
    head = _normalized_clean_head(
        REPO_ROOT, "alternate runtime worktree", detached_required=True
    )
    runtime_bindings: dict[str, Any] = {}
    for role in ALTERNATE_RUNTIME_BINDING_ROLES:
        item = bindings.get(role)
        if not isinstance(item, Mapping):
            raise B.InvalidEvidence(f"alternate runtime binding missing: {role}")
        B.assert_binding(item, f"alternate runtime {role}")
        runtime_bindings[role] = dict(item)
    return {
        "runtime_mode": "DETACHED_PUMP_PROOF_WORKTREE_FIX001",
        "runtime_fix_id": "WS30_ALT002_RUNTIME_FIX001",
        "runtime_root": str(REPO_ROOT.resolve()),
        "runtime_head": head,
        "runtime_cleanliness": _runtime_cleanliness_claim(),
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
            "runtime_fix001_contract": B.file_binding(
                RUNTIME_FIX_CONTRACT_PATH, EXPECTED_RUNTIME_FIX_CONTRACT_SHA256
            ),
            "invalid_runtime_materialization_closure": B.file_binding(
                INVALID_RUNTIME_CLOSURE_PATH,
                EXPECTED_INVALID_RUNTIME_CLOSURE_SHA256,
            ),
            "runtime_fix001_supersedes_materialization_only": True,
            "native_attempt_002_unconsumed_before_fix001": True,
            "immutable_runtime_required": True,
            "main_worktree_scoped_paths_clean_at_launch_required": True,
            "main_worktree_scoped_path_count": MAIN_SCOPED_PATH_COUNT,
            "main_worktree_scoped_path_list_canonical_sha256": (
                MAIN_SCOPED_PATH_LIST_SHA256
            ),
            "unrelated_main_worktree_dirt_ignored": True,
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
            "runtime_fix001_contract": dict(
                pre["bindings"]["runtime_fix_contract"]
            ),
            "invalid_runtime_materialization_closure": dict(
                pre["bindings"]["invalid_runtime_materialization_closure"]
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
    assert_main_scoped_paths_clean("alternate PRE")
    _assert_runtime_location()
    _assert_alternate_control_namespace()
    _assert_fix001_native_attempt_still_unconsumed("PRE")
    validate_alternate_contract()
    validate_invalid_runtime_materialization_closure()
    validate_runtime_fix_contract()
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
        "runtime_fix001_contract": dict(
            payload["bindings"]["runtime_fix_contract"]
        ),
        "invalid_runtime_materialization_closure": dict(
            payload["bindings"]["invalid_runtime_materialization_closure"]
        ),
        "supersedes_runtime_materialization_only": True,
        "native_attempt_unconsumed_before_fix001": True,
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
        or alt.get("supersedes_runtime_materialization_only") is not True
        or alt.get("native_attempt_unconsumed_before_fix001") is not True
        or alt.get("resume_permitted") is not False
        or alt.get("further_attempts_forbidden") is not True
    ):
        raise B.InvalidEvidence("alternate PRE attempt closure drift")
    validate_alternate_contract()
    validate_invalid_runtime_materialization_closure()
    validate_runtime_fix_contract()
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
    if alt.get("runtime_fix001_contract") != bindings.get("runtime_fix_contract"):
        raise B.InvalidEvidence("alternate PRE runtime FIX001 contract binding drift")
    if alt.get("invalid_runtime_materialization_closure") != bindings.get(
        "invalid_runtime_materialization_closure"
    ):
        raise B.InvalidEvidence("alternate PRE invalid-runtime closure binding drift")
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
    assert_main_scoped_paths_clean("alternate launch")
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
    """Create the runtime from a clean exact dependency scope in the main tree."""

    if RUNTIME_RECEIPT_PATH.exists():
        raise B.InvalidEvidence(
            f"runtime materialization receipt already exists: {RUNTIME_RECEIPT_PATH}"
        )
    if RUNTIME_WORKTREE_ROOT.exists():
        raise B.InvalidEvidence(
            f"runtime worktree target already exists: {RUNTIME_WORKTREE_ROOT}"
        )
    source_head = assert_main_scoped_paths_clean("runtime materialization")
    relative_paths = _main_scoped_relative_paths()
    _assert_fix001_native_attempt_still_unconsumed("materialization")
    validate_alternate_contract()
    validate_invalid_runtime_materialization_closure()
    validate_runtime_fix_contract()
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
    checkout_head = _normalized_clean_head(
        RUNTIME_WORKTREE_ROOT, "alternate runtime worktree", detached_required=True
    )
    if checkout_head != source_head:
        raise B.InvalidEvidence("materialized runtime HEAD differs from source HEAD")
    _overlay_exact_repository_binding_bytes(
        MAIN_WORKTREE_ROOT,
        RUNTIME_WORKTREE_ROOT,
        relative_paths,
    )
    runtime_head = _normalized_clean_head(
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
        "artifact_type": (
            "QM5_10834_WS30_ALT002_FIX001_RUNTIME_MATERIALIZATION_RECEIPT"
        ),
        "runtime_fix_id": "WS30_ALT002_RUNTIME_FIX001",
        "status": "PASS",
        "created_utc": B.utc_now(),
        "source_main_worktree": str(MAIN_WORKTREE_ROOT.resolve()),
        "source_head": source_head,
        "runtime_worktree": str(RUNTIME_WORKTREE_ROOT.resolve()),
        "runtime_head": runtime_head,
        "runtime_detached": True,
        "main_scoped_paths_clean_at_materialization": True,
        "main_scoped_path_count": MAIN_SCOPED_PATH_COUNT,
        "main_scoped_path_list_canonical_sha256": MAIN_SCOPED_PATH_LIST_SHA256,
        "unrelated_main_worktree_dirt_ignored": True,
        "runtime_cleanliness_at_materialization": _runtime_cleanliness_claim(),
        "checkout_policy": {
            "checkout": "GIT_WORKTREE_ADD_DETACHED_THEN_EXACT_BOUND_FILE_BYTE_OVERLAY",
            "checkout_eol_policy_is_not_evidence": True,
            "exact_overlay_from_clean_source_worktree": True,
            "post_overlay_normalized_git_clean": True,
            "post_overlay_porcelain_status_is_not_evidence": True,
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
B.validate_machine_credential_rotation_receipt = (
    validate_relocated_machine_credential_rotation_receipt
)
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
