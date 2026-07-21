#!/usr/bin/env python3
"""One-shot outcome-fenced NDX.DWX Model-4 prescreen for QM5_13209.

The module profiles the proven isolated-DEV2 controller from QM5_10834.  PRE
opens configuration, registry and tick-data evidence only.  The persistent
worker seals native artifacts as opaque path/size/hash bindings.  POST is the
first phase allowed to parse reports or economic outcomes.
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import re
import sqlite3
import subprocess
import sys
from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
BASE_TOOL_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_10834_tv-nq-ict-ob"
    / "tools"
    / "candidate_analysis"
    / "audit_tv_nq_ict_ob.py"
)
_BASE_SPEC = importlib.util.spec_from_file_location(
    "qm13209_ndx_private_dev2_base", BASE_TOOL_PATH
)
if _BASE_SPEC is None or _BASE_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load DEV2 base auditor: {BASE_TOOL_PATH}")
B = importlib.util.module_from_spec(_BASE_SPEC)
sys.modules[_BASE_SPEC.name] = B
_BASE_SPEC.loader.exec_module(B)


EA_ID = 13209
EA_LABEL = "QM5_13209"
EXPERT_NAME = "QM5_13209_mulham-pm-range-sweep"
EXPERT_PATH = rf"QM\{EXPERT_NAME}"
ANALYSIS_ID = "QM5_13209_MULHAM_PM_RANGE_SWEEP_NDX_PRESCREEN_NATIVE_001"
RESEARCH_SYMBOL = "NDX.DWX"
TIMEFRAME = "M5"
INITIAL_BALANCE = Decimal("100000")
DUPLICATES = 2
MAX_INFRA_WARMUPS = 2
MAX_ATTEMPTS = 4
COMMISSION_RT_PER_LOT = Decimal("5.50")
MAGIC_SLOT = 1
MAGIC = 132090001
WINDOWS = (
    B.Window("PRESCREEN_2022H2", "PRESCREEN", date(2022, 7, 1), date(2022, 12, 31)),
)
MERIT_GATES: dict[str, Any] = {
    "version": "QM5_13209_NDX_PRESCREEN_V1_20260721",
    "minimum_trades": 5,
    "minimum_native_profit_factor": "1.20",
    "minimum_cost_adjusted_profit_factor": "1.20",
    "cost_adjusted_net_must_be_strictly_positive": True,
    "lifecycle_and_session_invariants_required": True,
}

RUN_FAMILY_ROOT = Path(r"D:\QM\reports\candidate_analysis\QM5_13209")
RUN_NAMESPACE_ROOT = RUN_FAMILY_ROOT / "NDX_PM_RANGE_SWEEP_NATIVE_001"
RUN_ROOT = RUN_NAMESPACE_ROOT / "ATTEMPT_001"
PRE_RECEIPT_PATH = RUN_ROOT / "pre_receipt.json"
AUTHORIZATION_PATH = RUN_ROOT / "native_outcome_authorization.json"
STATE_PATH = RUN_ROOT / "launch_state.json"
JOB_PATH = RUN_ROOT / "launch_job.json"
POST_RECEIPT_PATH = RUN_ROOT / "post_receipt.json"
CLAIM_PATH = RUN_ROOT / "native_attempt_claim.json"
LOCK_PATH = RUN_ROOT / "native_launch.lock"
AUTHORIZATION_SCOPE = (
    "QM5_13209_NDX_PRESCREEN_NATIVE_001_ATTEMPT_001_"
    "ONE_CELL_2022H2_TWO_DUPLICATES_MAX_FOUR_STARTS_MODEL4_DEV2"
)
SCHEDULED_TASK_PREFIX = "QM_QM13209_NDX_AUDIT_"

DOC_ROOT = EA_ROOT / "docs" / "candidate-analysis"
CONTRACT_PATH = DOC_ROOT / "ndx_prescreen_outcome_fenced_analysis_contract_20260721.json"
OLD_CLOSURE_PATH = DOC_ROOT / "ndx_factory_summary_missing_invalid_infrastructure_closure_20260721.json"
BUILD_RECEIPT_PATH = DOC_ROOT / "build_receipt_20260721.json"
BUILD_RESULT_PATH = DOC_ROOT / "build_result_superseding_20260721.json"
CANONICAL_BUILD_RESULT_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\builds\d54ae7b2-bed6-4c7d-85a2-5030944f3127.json"
)
REVIEW_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\verdicts\review_6154711f-fb6e-4900-a208-17fe7df355b2.json"
)
DATA_RECEIPT_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\data\NDX_DWX_201807_202512_DEV2_backtest_data_receipt.json"
)
FACTORY_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
FACTORY_OFF_FLAG_PATH = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
OLD_WORKITEM_ID = "aff5d23f-fe44-43ef-a48f-f29737baf6ca"
DUPLICATE_WORKITEM_ID = "c9db50a1-8c0c-414f-ae16-36bd7e09985e"
SP500_RESULT_WORKITEM_ID = "f5b0237a-3be3-4064-9871-14b2da803118"
OLD_WORKITEM_ROOT = Path(r"D:\QM\reports\work_items") / OLD_WORKITEM_ID
SP500_EVIDENCE_PATH = (
    Path(r"D:\QM\reports\work_items")
    / SP500_RESULT_WORKITEM_ID
    / "QM5_13209"
    / "20260721_074932"
    / "summary.json"
)

CARD_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_13209_mulham-pm-range-sweep.md"
)
SPEC_PATH = EA_ROOT / "SPEC.md"
MQ5_PATH = EA_ROOT / f"{EXPERT_NAME}.mq5"
EX5_PATH = EA_ROOT / f"{EXPERT_NAME}.ex5"
SET_PATH = EA_ROOT / "sets" / f"{EXPERT_NAME}_NDX.DWX_M5_backtest.set"
ALIASES_PATH = REPO_ROOT / "framework" / "registry" / "execution_symbol_aliases_v1.json"
MATRIX_PATH = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
COST_PATH = REPO_ROOT / "framework" / "registry" / "venue_cost_model.json"
MAGIC_REGISTRY_PATH = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
EA_REGISTRY_PATH = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
TESTER_DEFAULTS_PATH = REPO_ROOT / "framework" / "registry" / "tester_defaults.json"
SCHEDULED_TASK_HELPER_PATH = TOOL_PATH.with_name("run_outcome_fenced_task.ps1")

EXPECTED_DATA_RECEIPT = {
    "path": str(DATA_RECEIPT_PATH),
    "size": 27870,
    "sha256": "b16fbc866b7e03a73b04fb5e67938eb7e290a0b31addcc6cc34736d1f554a66e",
}
EXPECTED_REVIEW = {
    "path": str(REVIEW_PATH),
    "size": 3390,
    "sha256": "7f59367de9c6dd826b059eeec843154610e2d3a4b3017b865d7886599940f45f",
}
EXPECTED_CANONICAL_BUILD = {
    "path": str(CANONICAL_BUILD_RESULT_PATH),
    "size": 2278,
    "sha256": "a6f60f690b5ec26293ea5e14f6e693d5a7d90ea5f4880d54f93997d881b27293",
}
EXPECTED_SP500_EVIDENCE = {
    "path": str(SP500_EVIDENCE_PATH),
    "size": 3305,
    "sha256": "5f5c9cc543648e9504326044f3c00a384e2cc561e3de315e86c327d91b0eedbe",
}
EXPECTED_INFRA_HASHES = {
    "runner": "d3d2bcbcd2d2d52bea4d0a50f501d86e35d48211b67066fad236d5c5d4efc485",
    "runner_child": "6602217a4c27636a9d4faa26086b6be5dfd3a4817b5fa8174640e5160922d6b1",
    "dev2_cleanup_helper": "617bbd95dfd1324bf70654a831ca6caec087df3cbaa8c1d064ddda3455e9f250",
    "dev2_machine_credential_probe": "103c9886c85e36650e3c0ac4c05fc3891ad019faab66c9d31ea961d0d93812d5",
    "dev2_machine_credential_helper": "bd3077f5ff671d80a377a820e35cd233cdf8ad1b25d376d579da4714c323ad2c",
    "dev2_lane_contract": "866e4e346187e47c33e32beb30bb96dc4085e98cc316819fb33f7925306dda06",
    "report_parser": "c9dc5106383073b50150f0edb091338181dc53470615839fb252f5bc96a46c03",
}


AuditError = B.AuditError
InvalidEvidence = B.InvalidEvidence
AuthorizationError = B.AuthorizationError
TradeRecord = B.TradeRecord

_BASE_RUNNER_COMMAND = B.runner_command
_BASE_WORKER_RUN = B._worker_run
_BASE_POSTFLIGHT = B.postflight
_BASE_LAUNCH_DETACHED = B.launch_detached


def _exact_binding(path: Path, expected: Mapping[str, Any], label: str) -> dict[str, Any]:
    if path.resolve() != Path(str(expected["path"])).resolve():
        raise InvalidEvidence(f"{label} path drift")
    binding = B.file_binding(path, str(expected["sha256"]))
    if binding["size"] != int(expected["size"]):
        raise InvalidEvidence(f"{label} size drift")
    return binding


def _assert_exact_control(path: Path, expected: Path, label: str) -> Path:
    if path.resolve() != expected.resolve():
        raise InvalidEvidence(f"{label} must be exactly {expected.resolve()}")
    return path.resolve()


def enforce_symbol_policy(symbol: str) -> None:
    if symbol != RESEARCH_SYMBOL or not symbol.endswith(".DWX"):
        raise InvalidEvidence("prescreen symbol must be exactly NDX.DWX")


def _assert_run_root(path: Path) -> Path:
    return _assert_exact_control(path, RUN_ROOT, "run root")


def validate_old_workitem_closure() -> dict[str, Any]:
    closure = B.load_json(OLD_CLOSURE_PATH)
    if (
        closure.get("status") != "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND_NO_MERIT_VERDICT"
        or closure.get("old_workitem", {}).get("workitem_id") != OLD_WORKITEM_ID
        or closure.get("old_workitem", {}).get("prior_failure") != "summary_missing"
        or closure.get("old_workitem", {}).get("evidence") is not None
        or closure.get("classification", {}).get("strategy_merit_adjudicated") is not False
        or closure.get("outcome_fence", {}).get("tester_ini_opened") is not False
    ):
        raise InvalidEvidence("old summary_missing closure drift")
    expected_file = {
        "relative_path": "QM5_13209/20260721_074735/raw/run_01/tester.ini",
        "size": 459,
        "sha256": "c330cb04599995fd999a58ff1ce9b440e3fc284478d1d678889ec6bc5cf7e416",
        "content_opened": False,
    }
    if closure.get("filesystem_inventory", {}).get("files") != [expected_file]:
        raise InvalidEvidence("old workitem outcome-blind inventory drift")
    path = OLD_WORKITEM_ROOT / Path(expected_file["relative_path"])
    _exact_binding(path, {**expected_file, "path": str(path)}, "old tester.ini opaque binding")
    actual_files = [item for item in OLD_WORKITEM_ROOT.rglob("*") if item.is_file()]
    if [item.resolve() for item in actual_files] != [path.resolve()]:
        raise InvalidEvidence("old workitem acquired an unregistered file")
    return {"binding": B.file_binding(OLD_CLOSURE_PATH), "status": closure["status"]}


def validate_factory_database_gate() -> dict[str, Any]:
    uri = f"file:{FACTORY_DB_PATH.as_posix()}?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=5)
    try:
        connection.row_factory = sqlite3.Row
        rows = {
            str(row["id"]): row
            for row in connection.execute(
                "SELECT id,status,verdict,attempt_count,evidence_path,payload_json "
                "FROM work_items WHERE ea_id='QM5_13209'"
            )
        }
    finally:
        connection.close()
    for item_id in (OLD_WORKITEM_ID, DUPLICATE_WORKITEM_ID, SP500_RESULT_WORKITEM_ID):
        if item_id not in rows:
            raise InvalidEvidence(f"required Factory workitem missing: {item_id}")
    old = rows[OLD_WORKITEM_ID]
    old_payload = json.loads(str(old["payload_json"] or "{}"))
    closure_binding = B.file_binding(OLD_CLOSURE_PATH)
    if (
        (old["status"], old["verdict"], old["attempt_count"], old["evidence_path"])
        != ("failed", "INFRA_FAIL", 1, None)
        or old_payload.get("final_failure") != "summary_missing"
        or old_payload.get("closure_artifact_path") != str(OLD_CLOSURE_PATH.resolve())
        or old_payload.get("closure_artifact_sha256") != closure_binding["sha256"]
        or old_payload.get("strategy_merit_adjudicated") is not False
    ):
        raise InvalidEvidence("aff5 Factory DB closure end-state drift")
    duplicate = rows[DUPLICATE_WORKITEM_ID]
    duplicate_payload = json.loads(str(duplicate["payload_json"] or "{}"))
    if (
        (duplicate["status"], duplicate["verdict"], duplicate["attempt_count"], duplicate["evidence_path"])
        != ("failed", "INVALID", 0, None)
        or duplicate_payload.get("duplicate_of") != SP500_RESULT_WORKITEM_ID
        or duplicate_payload.get("superseded_by") != SP500_RESULT_WORKITEM_ID
    ):
        raise InvalidEvidence("auto-enqueued SP500 duplicate end-state drift")
    result = rows[SP500_RESULT_WORKITEM_ID]
    if (
        (result["status"], result["verdict"], result["evidence_path"])
        != ("done", "FAIL", str(SP500_EVIDENCE_PATH))
    ):
        raise InvalidEvidence("existing SP500 strategy-result row drift")
    _exact_binding(SP500_EVIDENCE_PATH, EXPECTED_SP500_EVIDENCE, "SP500 evidence opaque binding")
    active = [
        item_id
        for item_id, row in rows.items()
        if str(row["status"]) in {"pending", "active", "claimed", "running"}
    ]
    if active:
        raise InvalidEvidence(f"QM5_13209 Factory rows remain active: {active}")
    return {
        "status": "PASS",
        "database_path": str(FACTORY_DB_PATH.resolve()),
        "old_ndx": "failed/INFRA_FAIL/evidence_path_NULL",
        "sp500_duplicate": "failed/INVALID/evidence_path_NULL",
        "existing_sp500_result": "done/FAIL/unchanged_opaque_binding",
    }


def validate_build_receipt() -> dict[str, Any]:
    receipt = B.load_json(BUILD_RECEIPT_PATH)
    if (
        receipt.get("status") != "APPROVED_FOR_BACKTEST"
        or receipt.get("ea_id") != EA_LABEL
        or receipt.get("research_symbol") != RESEARCH_SYMBOL
        or receipt.get("timeframe") != TIMEFRAME
        or receipt.get("source_commit") != "8d762f66321ef9a2aa3503ae8b464ea378e5a34f"
    ):
        raise InvalidEvidence("build receipt is not exactly review-approved")
    artifacts = receipt.get("artifact_bindings")
    expected_paths = {
        "mq5": MQ5_PATH,
        "ex5": EX5_PATH,
        "spec": SPEC_PATH,
        "ndx_m5_set": SET_PATH,
    }
    if not isinstance(artifacts, Mapping) or set(artifacts) != set(expected_paths):
        raise InvalidEvidence("build artifact binding closure drift")
    for role, path in expected_paths.items():
        _exact_binding(path, artifacts[role], f"build {role}")
    _exact_binding(CANONICAL_BUILD_RESULT_PATH, EXPECTED_CANONICAL_BUILD, "canonical build result")
    review_binding = _exact_binding(REVIEW_PATH, EXPECTED_REVIEW, "review verdict")
    review = B.load_json(REVIEW_PATH)
    if (
        review.get("review_task_id") != "6154711f-fb6e-4900-a208-17fe7df355b2"
        or review.get("build_task_id") != "d54ae7b2-bed6-4c7d-85a2-5030944f3127"
        or review.get("ea_id") != EA_LABEL
        or review.get("verdict") != "APPROVE_FOR_BACKTEST"
        or review.get("rework_directives") is not None
    ):
        raise InvalidEvidence("review verdict semantic drift")
    return {
        "binding": B.file_binding(BUILD_RECEIPT_PATH),
        "source_commit": receipt["source_commit"],
        "review": review_binding,
        "canonical_build_result": B.file_binding(CANONICAL_BUILD_RESULT_PATH),
    }


def validate_analysis_contract() -> dict[str, Any]:
    contract = B.load_json(CONTRACT_PATH)
    if (
        contract.get("status") != "IMPLEMENTED_REVIEW_APPROVED_NOT_AUTHORIZED_NOT_LAUNCHED"
        or contract.get("analysis_id") != ANALYSIS_ID
        or contract.get("candidate", {}).get("research_symbol") != RESEARCH_SYMBOL
        or contract.get("candidate", {}).get("magic_slot") != MAGIC_SLOT
        or contract.get("candidate", {}).get("magic") != MAGIC
        or contract.get("scope", {}).get("run_root") != str(RUN_ROOT)
        or contract.get("scope", {}).get("attempts") != 1
        or any(contract.get("scope", {}).get(key) is not False for key in (
            "resume_permitted", "relaunch_permitted", "retry_permitted"
        ))
        or contract.get("cell", {}).get("cell_id") != "PRESCREEN_2022H2"
        or contract.get("cell", {}).get("accepted_deterministic_duplicates") != 2
        or contract.get("cell", {}).get("maximum_native_starts") != 4
        or contract.get("merit_gates") != {
            "minimum_trades": 5,
            "minimum_native_profit_factor": "1.20",
            "minimum_cost_adjusted_profit_factor": "1.20",
            "cost_adjusted_net_must_be_strictly_positive": True,
            "all_lifecycle_and_session_invariants_must_pass": True,
        }
    ):
        raise InvalidEvidence("NDX prescreen analysis contract drift")
    return {"binding": B.file_binding(CONTRACT_PATH), "status": contract["status"]}


def validate_backtest_data_receipt(
    path: Path = DATA_RECEIPT_PATH,
    symbol: str = RESEARCH_SYMBOL,
    *,
    verify_files: bool = True,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    receipt_binding = _exact_binding(path, EXPECTED_DATA_RECEIPT, "NDX data receipt")
    payload = B.load_json(path)
    coverage = payload.get("coverage", {})
    files = payload.get("files")
    if (
        payload.get("artifact_type") != "QM5_10834_BACKTEST_DATA_RECEIPT"
        or payload.get("symbol") != RESEARCH_SYMBOL
        or payload.get("terminal") != "DEV2"
        or coverage.get("from_date") != "2018-07-02"
        or coverage.get("to_date") != "2025-12-31"
        or coverage.get("history_file_count") != 8
        or coverage.get("tick_file_count") != 90
        or not isinstance(files, list)
        or len(files) != 98
        or payload.get("outcome_fence", {}).get("strategy_outcomes_read") is not False
    ):
        raise InvalidEvidence("frozen NDX data receipt semantic drift")
    periods = {(str(row.get("kind")), str(row.get("period"))) for row in files if isinstance(row, Mapping)}
    required = {("history", "2022"), *{("ticks", f"2022{month:02d}") for month in range(7, 13)}}
    if not required.issubset(periods):
        raise InvalidEvidence("NDX 2022H2 exact-tick coverage is incomplete")
    seen: set[Path] = set()
    if verify_files:
        for index, row in enumerate(files):
            if not isinstance(row, Mapping) or set(row) != {"kind", "path", "period", "sha256", "size"}:
                raise InvalidEvidence(f"data file ledger[{index}] malformed")
            file_path = Path(str(row["path"])).resolve()
            if file_path in seen:
                raise InvalidEvidence("duplicate data file path")
            seen.add(file_path)
            _exact_binding(file_path, {**row, "path": str(file_path)}, f"data file[{index}]")
    return {
        "receipt": receipt_binding,
        "file_count": 98,
        "history_files": 8,
        "tick_files": 90,
        "file_ledger_sha256": B.canonical_sha256(files),
        "historical_factory_bindings_replayed": False,
    }


def validate_current_ndx_semantics() -> dict[str, Any]:
    aliases = B.load_json(ALIASES_PATH)
    observed: dict[str, str] = {}
    for venue in aliases.get("venues", []):
        if not isinstance(venue, Mapping):
            continue
        matches = [
            row for row in venue.get("symbols", [])
            if isinstance(row, Mapping) and row.get("logical_symbol") == RESEARCH_SYMBOL
        ]
        if matches:
            if len(matches) != 1:
                raise InvalidEvidence("NDX alias is ambiguous within a venue")
            observed[str(venue.get("venue_id"))] = str(matches[0].get("raw_symbol"))
    if observed != {"DXZ_LIVE": "NDX", "FTMO_TRIAL": "US100.cash"}:
        raise InvalidEvidence(f"current exact NDX alias semantics drift: {observed}")

    with MATRIX_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        matrix = [row for row in csv.DictReader(handle) if row.get("symbol") == RESEARCH_SYMBOL]
    if len(matrix) != 1 or (
        matrix[0].get("asset_class") != "indices"
        or matrix[0].get("import_log_path") != "Custom/Indices/Index 3/NDX.DWX"
        or matrix[0].get("canonical_name_verified") != "true"
    ):
        raise InvalidEvidence("current NDX research-symbol matrix semantics drift")

    with MAGIC_REGISTRY_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        magic_rows = [row for row in csv.DictReader(handle) if row.get("ea_id") == str(EA_ID)]
    expected_magic = [
        row for row in magic_rows
        if row.get("symbol") == RESEARCH_SYMBOL and row.get("symbol_slot") == str(MAGIC_SLOT)
    ]
    if len(expected_magic) != 1 or expected_magic[0].get("magic") != str(MAGIC) or expected_magic[0].get("status") != "active":
        raise InvalidEvidence("NDX slot-1 magic semantics drift")

    costs = B.load_json(COST_PATH).get("symbols", {})
    if (
        not isinstance(costs, Mapping)
        or costs.get("NDX", {}).get("alias_of") != "US100"
        or Decimal(str(costs.get("US100", {}).get("worst_case_rt_per_lot_usd"))) != COMMISSION_RT_PER_LOT
    ):
        raise InvalidEvidence("current NDX venue-cost semantics drift")
    defaults = B.load_json(TESTER_DEFAULTS_PATH)
    if defaults.get("initial_deposit") != 100000 or defaults.get("deposit_currency") != "USD" or defaults.get("leverage") != 100:
        raise InvalidEvidence("tester 100k/USD/1:100 defaults drift")
    return {
        "aliases": observed,
        "matrix_row": matrix[0],
        "magic": MAGIC,
        "cost_rt_per_lot_usd": "5.50",
        "tester": {"deposit": 100000, "currency": "USD", "leverage": 100},
    }


def assert_dev2_quiescence() -> dict[str, Any]:
    if not FACTORY_OFF_FLAG_PATH.is_file():
        raise InvalidEvidence("Factory OFF flag is required")
    script = r"""
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$names=@('terminal64.exe','metatester64.exe','metaeditor64.exe')
$processes=@(Get-CimInstance Win32_Process | ForEach-Object {
  $p=[string]$_.ExecutablePath
  if($p -and $names -contains ([IO.Path]::GetFileName($p).ToLowerInvariant()) -and
     [IO.Path]::GetFullPath($p).StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) {
    [ordered]@{pid=[int]$_.ProcessId;name=[string]$_.Name;path=[IO.Path]::GetFullPath($p)}
  }
})
$tasks=@(Get-ScheduledTask -ErrorAction Stop | Where-Object {
  ($_.TaskName -like 'QM_DEV2_SMOKE_*' -or $_.TaskName -like 'QM_DEV2_CLEANUP_*' -or
   $_.TaskName -like 'QM_DEV2_PROFILE_INIT_*') -and $_.State.ToString() -in @('Running','Queued')
} | ForEach-Object {[ordered]@{task_name=$_.TaskName;state=$_.State.ToString()}})
$mutex=$null;$held=$false;$available=$false
try {
  try {$mutex=[Threading.Mutex]::OpenExisting('Global\QM_DEV2_SMOKE_CONTROLLER')}
  catch [Threading.WaitHandleCannotBeOpenedException] {$created=$false;$mutex=New-Object Threading.Mutex($false,'Global\QM_DEV2_SMOKE_CONTROLLER',[ref]$created)}
  try {$held=$mutex.WaitOne(0);$available=$held}
  catch [Threading.AbandonedMutexException] {$held=$true;$available=$true}
} finally {if($held){$mutex.ReleaseMutex()};if($null-ne$mutex){$mutex.Dispose()}}
[ordered]@{processes=$processes;active_tasks=$tasks;mutex_available=$available;command_lines_read=$false}|ConvertTo-Json -Depth 5 -Compress
"""
    completed = subprocess.run(
        [str(B.POWERSHELL_PATH), "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    if completed.returncode != 0:
        raise InvalidEvidence("DEV2 quiescence probe failed closed")
    try:
        proof = json.loads(completed.stdout.strip())
    except json.JSONDecodeError as exc:
        raise InvalidEvidence("DEV2 quiescence probe returned invalid JSON") from exc
    if proof != {"processes": [], "active_tasks": [], "mutex_available": True, "command_lines_read": False}:
        raise InvalidEvidence(f"DEV2 is not quiescent: {proof}")
    return {
        "status": "PASS",
        "factory_off_flag": B.file_binding(FACTORY_OFF_FLAG_PATH),
        **proof,
    }


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    enforce_symbol_policy(symbol)
    return {
        "card": CARD_PATH,
        "spec": SPEC_PATH,
        "mq5": MQ5_PATH,
        "ex5": EX5_PATH,
        "set": SET_PATH,
        "analysis_contract": CONTRACT_PATH,
        "old_workitem_closure": OLD_CLOSURE_PATH,
        "build_receipt": BUILD_RECEIPT_PATH,
        "build_result": BUILD_RESULT_PATH,
        "canonical_build_result": CANONICAL_BUILD_RESULT_PATH,
        "review_verdict": REVIEW_PATH,
        "aliases": ALIASES_PATH,
        "matrix": MATRIX_PATH,
        "cost": COST_PATH,
        "magic_registry": MAGIC_REGISTRY_PATH,
        "ea_registry": EA_REGISTRY_PATH,
        "tester_defaults": TESTER_DEFAULTS_PATH,
        "runner": B.RUNNER_PATH,
        "runner_child": B.RUNNER_CHILD_PATH,
        "dev2_cleanup_helper": B.DEV2_CLEANUP_HELPER_PATH,
        "dev2_machine_credential_probe": B.CREDENTIAL_PROBE_PATH,
        "dev2_machine_credential_helper": B.CREDENTIAL_HELPER_PATH,
        "dev2_machine_credential": B.MACHINE_CREDENTIAL_PATH,
        "dev2_machine_credential_rotation_receipt": B.MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH,
        "runner_smoke": B.RUN_SMOKE_PATH,
        "dev2_lane_contract": B.DEV2_LANE_CONTRACT_PATH,
        "tester_groups_canonical": B.TESTER_GROUPS_CANONICAL_PATH,
        "tester_groups_dev2": B.TESTER_GROUPS_DEV2_PATH,
        "dev2_symbol_database": B.TERMINAL_SYMBOL_DATABASE_PATH,
        "report_parser": B.REPORT_CORE_PATH,
        "powershell": B.POWERSHELL_PATH,
        "python": B.PYTHON_PATH,
        "scheduled_task_helper": SCHEDULED_TASK_HELPER_PATH,
        "tool": TOOL_PATH,
    }


def _binding_map(symbol: str) -> dict[str, dict[str, Any]]:
    bindings: dict[str, dict[str, Any]] = {}
    for role, path in _expected_binding_paths(symbol).items():
        bindings[role] = B.file_binding(path, EXPECTED_INFRA_HASHES.get(role))
    if bindings["tester_groups_dev2"]["sha256"] != bindings["tester_groups_canonical"]["sha256"]:
        raise InvalidEvidence("DEV2 tester groups differ from canonical")
    return bindings


def _validate_set_contract(symbol: str, metadata: Mapping[str, str], inputs: Mapping[str, str]) -> None:
    enforce_symbol_policy(symbol)
    if metadata.get("ea_id") != "13209" or metadata.get("symbol") != symbol or metadata.get("timeframe") != TIMEFRAME or metadata.get("magic_slot") != "1":
        raise InvalidEvidence("NDX M5 set metadata drift")
    expected = {
        "qm_ea_id": "13209", "qm_magic_slot_offset": "1", "RISK_FIXED": "1000",
        "RISK_PERCENT": "0", "PORTFOLIO_WEIGHT": "1", "pm_start_hour": "20",
        "pm_start_min": "30", "pm_end_hour": "23", "pm_end_min": "0",
        "sweep_start_hour": "16", "sweep_start_min": "30", "sweep_end_hour": "18",
        "sweep_end_min": "0", "entry_cancel_hour": "19", "flatten_hour": "20",
        "strategy_tp_mode": "STRATEGY_TP_OPPOSITE_EXTREME",
    }
    drift = {key: (value, inputs.get(key)) for key, value in expected.items() if inputs.get(key) != value}
    if drift:
        raise InvalidEvidence(f"NDX set input drift: {drift}")


def execution_contract() -> dict[str, Any]:
    return {
        "terminal": "DEV2",
        "controller": "ISOLATED_DEV2_SCHEDULED_TASK_LANE",
        "controller_mutex": "Global\\QM_DEV2_SMOKE_CONTROLLER",
        "factory_off_required": True,
        "one_shot": True,
        "resume_relaunch_retry_forbidden": True,
        "accepted_duplicates": 2,
        "maximum_infrastructure_warmups": 2,
        "maximum_native_starts": 4,
        "model": 4,
        "deposit": 100000,
        "currency": "USD",
        "leverage": 100,
        "claim_path": str(CLAIM_PATH.resolve()),
        "authorization_scope": AUTHORIZATION_SCOPE,
    }


def build_plan(symbol: str, set_binding: Mapping[str, Any], run_root: Path) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    _assert_run_root(run_root)
    cell = {
        "cell_id": "NDX_DWX_PRESCREEN_2022H2",
        "symbol": symbol,
        "cohort": "PRESCREEN",
        "from_date": "2022-07-01",
        "to_date": "2022-12-31",
        "timeframe": TIMEFRAME,
        "model": 4,
        "duplicates": 2,
        "maximum_postflight_acceptable_infrastructure_warmups": 2,
        "maximum_attempts": 4,
        "native_start_budget_is_outcome_independent": True,
        "set": dict(set_binding),
        "output_root": str((run_root / "native" / "PRESCREEN_2022H2").resolve()),
    }
    basis = {
        "single_authorized_symbol": symbol,
        "cells": [cell],
        "accepted_duplicate_run_count": 2,
        "maximum_native_starts": 4,
        "technical_prescreen": {"authorized": True, "merit_eligible": True, "window": "2022H2"},
    }
    return {**basis, "plan_sha256": B.canonical_sha256(basis)}


def preflight(symbol: str, data_receipt_path: Path, build_receipt_path: Path, run_root: Path) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    _assert_run_root(run_root)
    _assert_exact_control(data_receipt_path, DATA_RECEIPT_PATH, "data receipt")
    _assert_exact_control(build_receipt_path, BUILD_RECEIPT_PATH, "build receipt")
    if RUN_ROOT.exists() and any(RUN_ROOT.iterdir()):
        raise InvalidEvidence("fresh one-shot run root is not empty")
    if CLAIM_PATH.exists() or STATE_PATH.exists() or JOB_PATH.exists():
        raise InvalidEvidence("one-shot analysis is already consumed")
    contract = validate_analysis_contract()
    closure = validate_old_workitem_closure()
    factory_db = validate_factory_database_gate()
    build = validate_build_receipt()
    data = validate_backtest_data_receipt(data_receipt_path, symbol)
    semantics = validate_current_ndx_semantics()
    quiescence = assert_dev2_quiescence()
    bindings = _binding_map(symbol)
    rotation = B.validate_machine_credential_rotation_receipt(bindings)
    card = CARD_PATH.read_text(encoding="utf-8-sig")
    if "ea_id: QM5_13209" not in card or "status: APPROVED" not in card or "g0_status: APPROVED" not in card:
        raise InvalidEvidence("Strategy Card approval drift")
    includes = B.include_closure(MQ5_PATH)
    metadata, set_inputs = B.parse_set(SET_PATH)
    _validate_set_contract(symbol, metadata, set_inputs)
    effective_inputs = B.effective_input_contract(MQ5_PATH, includes, set_inputs)
    if effective_inputs.get("InpQMSimCommissionPerLot", {}).get("canonical") != "0":
        raise InvalidEvidence("EA-side simulated commission must be zero")
    plan = build_plan(symbol, bindings["set"], run_root)
    return {
        "schema_version": 1,
        "artifact_type": "QM5_13209_NDX_PRESCREEN_OUTCOME_FENCED_PRE_RECEIPT",
        "status": "PASS",
        "created_utc": B.utc_now(),
        "analysis_id": ANALYSIS_ID,
        "run_root": str(RUN_ROOT.resolve()),
        "symbol_policy": {
            "authorized_symbol": RESEARCH_SYMBOL,
            "dwx_research_backtest_required": True,
            "suffix_removed_only_at_deploy_packaging": True,
            "live_aliases": semantics["aliases"],
            "magic_slot": MAGIC_SLOT,
            "magic": MAGIC,
        },
        "outcome_fence": {
            "native_reports_opened": False,
            "deal_rows_parsed": False,
            "market_values_parsed": False,
            "mt5_terminal_started": False,
            "metatester_started": False,
        },
        "bindings": bindings,
        "analysis_contract": contract,
        "old_workitem_closure": closure,
        "factory_database_gate": factory_db,
        "build_review": build,
        "backtest_data_receipt": data,
        "current_ndx_semantics": semantics,
        "dev2_quiescence": quiescence,
        "machine_credential_rotation": rotation,
        "include_closure": includes,
        "effective_inputs": effective_inputs,
        "execution_contract": execution_contract(),
        "cost_schedule": {
            "symbol": RESEARCH_SYMBOL,
            "spread": "EMBEDDED_IN_BOUND_REAL_TICKS",
            "swap": "REQUIRED_ZERO_BY_INTRADAY_FLAT_INVARIANT",
            "worst_rt_per_lot_usd": "5.50",
        },
        "merit_contract": MERIT_GATES,
        "plan": plan,
    }


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _assert_exact_control(path, PRE_RECEIPT_PATH, "PRE receipt")
    binding = B.file_binding(path, expected_sha256)
    pre = B.load_json(path)
    if (
        pre.get("artifact_type") != "QM5_13209_NDX_PRESCREEN_OUTCOME_FENCED_PRE_RECEIPT"
        or pre.get("status") != "PASS"
        or pre.get("analysis_id") != ANALYSIS_ID
        or pre.get("run_root") != str(RUN_ROOT.resolve())
        or pre.get("merit_contract") != MERIT_GATES
        or pre.get("execution_contract") != execution_contract()
        or pre.get("plan") != build_plan(RESEARCH_SYMBOL, pre.get("bindings", {}).get("set", {}), RUN_ROOT)
    ):
        raise InvalidEvidence("PRE identity/plan drift")
    bindings = pre.get("bindings")
    if not isinstance(bindings, Mapping) or set(bindings) != set(_expected_binding_paths(RESEARCH_SYMBOL)):
        raise InvalidEvidence("PRE binding-role closure drift")
    for role, item in bindings.items():
        B.assert_binding(item, f"PRE {role}")
    validate_analysis_contract()
    validate_old_workitem_closure()
    validate_build_receipt()
    if pre.get("backtest_data_receipt") != validate_backtest_data_receipt(DATA_RECEIPT_PATH, RESEARCH_SYMBOL):
        raise InvalidEvidence("PRE/data receipt drift")
    current = validate_current_ndx_semantics()
    if pre.get("current_ndx_semantics") != current:
        raise InvalidEvidence("PRE/current NDX semantics drift")
    B.assert_binding(binding, "stable PRE receipt")
    return pre


def validate_current_research_data_gate(pre: Mapping[str, Any]) -> None:
    validate_factory_database_gate()
    validate_current_ndx_semantics()
    validate_backtest_data_receipt(DATA_RECEIPT_PATH, RESEARCH_SYMBOL)
    assert_dev2_quiescence()
    if pre.get("execution_contract") != execution_contract():
        raise InvalidEvidence("current DEV2 execution contract drift")


def validate_authorization(
    path: Path, pre_sha256: str, *, require_current: bool = True, now: datetime | None = None
) -> dict[str, Any]:
    _assert_exact_control(path, AUTHORIZATION_PATH, "authorization")
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected = {
        "schema_version": 1,
        "artifact_type": "QM5_13209_NDX_PRESCREEN_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_sha256": pre_sha256.lower(),
        "scope": AUTHORIZATION_SCOPE,
        "authorized_by": "OWNER",
        "authorized_symbol": RESEARCH_SYMBOL,
        "authorized_cells": ["PRESCREEN_2022H2"],
        "duplicates_per_cell": 2,
        "maximum_infrastructure_warmups_per_cell": 2,
        "maximum_native_starts": 4,
        "model": 4,
        "authorize_native_outcomes": True,
        "resume_relaunch_retry_forbidden": True,
    }
    if set(payload) != {*expected, "created_utc", "expires_utc"} or any(payload.get(key) != value for key, value in expected.items()):
        raise AuthorizationError("one-shot native authorization drift")
    created = B.parse_utc(str(payload["created_utc"]), "authorization created_utc")
    expires = B.parse_utc(str(payload["expires_utc"]), "authorization expires_utc")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if expires <= created or expires - created > timedelta(hours=24) or (require_current and not created - timedelta(minutes=5) <= current <= expires):
        raise AuthorizationError("authorization chronology/validity drift")
    return {"binding": binding, "payload_sha256": B.canonical_sha256(payload), "payload": payload}


def _native_attempt_claim_basis(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    state_path: Path,
    authorization: Mapping[str, Any],
    preclaim_probe: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "QM5_13209_NDX_PRESCREEN_NATIVE_ATTEMPT_CLAIM",
        "analysis_id": ANALYSIS_ID,
        "classification": "ATOMIC_ONE_SHOT_OUTCOME_BLIND_DEV2_CLAIM",
        "authorization_scope": AUTHORIZATION_SCOPE,
        "accepted_duplicates_per_cell": 2,
        "maximum_infrastructure_warmups_per_cell": 2,
        "maximum_native_starts": 4,
        "resume_relaunch_retry_forbidden": True,
        "same_worker_machine_credential_preclaim_probe": dict(preclaim_probe),
        "pre_receipt": B.file_binding(pre_path, pre_sha256),
        "run_root": str(RUN_ROOT.resolve()),
        "launch_state_path": str(state_path.resolve()),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "analysis_contract": dict(pre["bindings"]["analysis_contract"]),
        "ea_binary": dict(pre["bindings"]["ex5"]),
        "set": dict(pre["bindings"]["set"]),
        "authorization": {
            "binding": dict(authorization["binding"]),
            "payload_sha256": authorization["payload_sha256"],
        },
    }


def launch_detached(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    if resume:
        raise AuthorizationError("one-shot NDX prescreen never permits resume")
    for observed, expected, label in (
        (pre_path, PRE_RECEIPT_PATH, "PRE receipt"),
        (authorization_path, AUTHORIZATION_PATH, "authorization"),
        (state_path, STATE_PATH, "launch state"),
    ):
        _assert_exact_control(observed, expected, label)
    if CLAIM_PATH.exists() or STATE_PATH.exists() or JOB_PATH.exists():
        raise AuthorizationError("one-shot NDX prescreen is already consumed")
    assert_dev2_quiescence()
    return _BASE_LAUNCH_DETACHED(pre_path, pre_sha256, authorization_path, state_path, resume=False)


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    if pre.get("execution_contract") != execution_contract():
        raise InvalidEvidence("runner requires exact NDX DEV2 prescreen contract")
    return _BASE_RUNNER_COMMAND(pre, cell)


def validate_trade_semantics(trades: Sequence[TradeRecord]) -> dict[str, Any]:
    per_day: dict[str, int] = defaultdict(int)
    for trade in trades:
        if not time(16, 30) <= trade.entry_time_broker.time() < time(19, 0):
            raise InvalidEvidence("entry outside [16:30,19:00) broker window")
        if trade.entry_time_broker.date() != trade.exit_time_broker.date():
            raise InvalidEvidence("position was not flat on its broker entry day")
        if trade.exit_time_broker.time() >= time(20, 5):
            raise InvalidEvidence("position was not flat before 20:05 broker time")
        if trade.exit_time_broker < trade.entry_time_broker:
            raise InvalidEvidence("negative holding time")
        day = trade.entry_time_broker.date().isoformat()
        per_day[day] += 1
    if any(count > 1 for count in per_day.values()):
        raise InvalidEvidence("more than one completed trade per broker day")
    return {
        "status": "PASS",
        "entries_inside_1630_1900_half_open": True,
        "flat_same_broker_day": True,
        "flat_before_2005_execution_grace": True,
        "maximum_one_trade_per_broker_day": True,
        "trading_days": len(per_day),
    }


def _axis_metrics(trades: Sequence[TradeRecord], field: str) -> dict[str, Any]:
    values = [Decimal(getattr(row, field)) for row in trades]
    gross_profit = sum((max(value, Decimal("0")) for value in values), Decimal("0"))
    gross_loss = sum((min(value, Decimal("0")) for value in values), Decimal("0"))
    net = sum(values, Decimal("0"))
    if gross_loss < 0:
        pf: str | None = B._decimal_text(gross_profit / -gross_loss)
        state = "FINITE"
    elif gross_profit > 0:
        pf = None
        state = "INFINITE_NO_LOSSES"
    else:
        pf = None
        state = "UNDEFINED"
    return {"trades": len(values), "net_usd": B._money_text(net), "profit_factor": pf, "profit_factor_state": state}


def _pf_at_least(metrics: Mapping[str, Any], floor: Decimal) -> bool:
    return metrics["profit_factor_state"] == "INFINITE_NO_LOSSES" or (
        metrics["profit_factor_state"] == "FINITE"
        and metrics["profit_factor"] is not None
        and Decimal(str(metrics["profit_factor"])) >= floor
    )


def evaluate_merit(cells: Mapping[str, Sequence[TradeRecord]]) -> dict[str, Any]:
    if set(cells) != {"PRESCREEN_2022H2"}:
        raise InvalidEvidence("prescreen merit cell closure drift")
    trades = list(cells["PRESCREEN_2022H2"])
    lifecycle = validate_trade_semantics(trades)
    native = _axis_metrics(trades, "native_net_usd")
    adjusted = _axis_metrics(trades, "adjusted_net_usd")
    gates = [
        B._gate("MIN_TRADES", len(trades) >= 5, len(trades), ">=5"),
        B._gate("NATIVE_PF", _pf_at_least(native, Decimal("1.20")), native["profit_factor"], ">=1.20"),
        B._gate("ADJUSTED_PF", _pf_at_least(adjusted, Decimal("1.20")), adjusted["profit_factor"], ">=1.20"),
        B._gate("ADJUSTED_NET", Decimal(adjusted["net_usd"]) > 0, adjusted["net_usd"], ">0"),
        B._gate("LIFECYCLE", lifecycle["status"] == "PASS", lifecycle, "all invariants PASS"),
    ]
    return {
        "contract": MERIT_GATES,
        "native": native,
        "cost_adjusted": adjusted,
        "lifecycle": lifecycle,
        "gates": gates,
        "status": "PASS" if all(row["status"] == "PASS" for row in gates) else "FAIL",
    }


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    _assert_exact_control(pre_path, PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control(state_path, STATE_PATH, "launch state")
    payload = _BASE_POSTFLIGHT(pre_path, pre_sha256, state_path)
    payload["artifact_type"] = "QM5_13209_NDX_PRESCREEN_OUTCOME_FENCED_POST_RECEIPT"
    payload["decision"] = "ADVANCE_FAMILY_TO_FULL_VALIDATION" if payload["status"] == "PASS" else "STOP_FAMILY_ON_PRESCREEN_MERIT"
    return payload


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    pre = sub.add_parser("pre")
    pre.add_argument("--symbol", required=True)
    pre.add_argument("--data-receipt", type=Path, required=True)
    pre.add_argument("--build-receipt", type=Path, required=True)
    pre.add_argument("--run-root", type=Path, required=True)
    pre.add_argument("--receipt", type=Path, required=True)
    launch = sub.add_parser("launch")
    launch.add_argument("--pre-receipt", type=Path, required=True)
    launch.add_argument("--pre-sha256", required=True)
    launch.add_argument("--authorization", type=Path, required=True)
    launch.add_argument("--state", type=Path, required=True)
    launch.set_defaults(resume=False)
    post = sub.add_parser("post")
    post.add_argument("--pre-receipt", type=Path, required=True)
    post.add_argument("--pre-sha256", required=True)
    post.add_argument("--state", type=Path, required=True)
    post.add_argument("--receipt", type=Path, required=True)
    status = sub.add_parser("status")
    status.add_argument("--state", type=Path, required=True)
    worker = sub.add_parser("_run-plan", help=argparse.SUPPRESS)
    worker.add_argument("--job", type=Path, required=True)
    return parser


def _configure_private_profile() -> None:
    assignments = {
        "TOOL_PATH": TOOL_PATH, "EA_ROOT": EA_ROOT, "REPO_ROOT": REPO_ROOT,
        "EA_ID": EA_ID, "EA_LABEL": EA_LABEL, "EXPERT_NAME": EXPERT_NAME,
        "EXPERT_PATH": EXPERT_PATH, "ANALYSIS_ID": ANALYSIS_ID,
        "SCHEMA_VERSION": 1, "MERIT_CONTRACT_VERSION": MERIT_GATES["version"],
        "CARD_PATH": CARD_PATH, "SPEC_PATH": SPEC_PATH, "MQ5_PATH": MQ5_PATH,
        "EX5_PATH": EX5_PATH, "ALLOWED_RUN_ROOT": RUN_ROOT,
        "NATIVE_ATTEMPT_CLAIM_PATH": CLAIM_PATH, "NATIVE_LAUNCH_LOCK_PATH": LOCK_PATH,
        "CURRENT_CLAIM_SEQUENCE": 1, "RESERVED_COUNTED_ALTERNATE_ATTEMPT_NUMBER": 1,
        "PRIOR_CLAIM_SEQUENCES": 0, "MAXIMUM_COUNTED_ALTERNATE_ATTEMPTS": 1,
        "PRIOR_COUNTED_ALTERNATE_ATTEMPTS": 0,
        "ALTERNATE_ATTEMPT_COUNTING_BOUNDARY": "EXACT_DEV2_METATESTER_PROCESS_STARTED",
        "AUTHORIZATION_SCOPE": AUTHORIZATION_SCOPE, "TIMEFRAME": TIMEFRAME,
        "DUPLICATES": DUPLICATES, "MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL": 2,
        "MAX_ATTEMPTS_PER_CELL": 4, "INITIAL_BALANCE": INITIAL_BALANCE,
        "WINDOWS": WINDOWS, "MERIT_GATES": MERIT_GATES, "RESEARCH_SYMBOL": RESEARCH_SYMBOL,
        "SCHEDULED_TASK_PREFIX": SCHEDULED_TASK_PREFIX, "LAUNCHER_REVISION": 1320901,
        "SCHEDULED_TASK_HELPER_PATH": SCHEDULED_TASK_HELPER_PATH,
        "REQUIRED_BINDING_ROLES": frozenset(_expected_binding_paths(RESEARCH_SYMBOL)),
    }
    for name, value in assignments.items():
        setattr(B, name, value)
    B._assert_run_root = _assert_run_root
    B.enforce_symbol_policy = enforce_symbol_policy
    B._expected_binding_paths = _expected_binding_paths
    B._binding_map = _binding_map
    B._validate_set_contract = _validate_set_contract
    B.execution_contract = execution_contract
    B.build_plan = build_plan
    B.preflight = preflight
    B.assert_pre_receipt = assert_pre_receipt
    B.validate_current_research_data_gate = validate_current_research_data_gate
    B.validate_authorization = validate_authorization
    B._native_attempt_claim_basis = _native_attempt_claim_basis
    B.launch_detached = launch_detached
    B.runner_command = runner_command
    B.validate_trade_semantics = validate_trade_semantics
    B.evaluate_merit = evaluate_merit
    B.postflight = postflight
    B.build_parser = build_parser


_configure_private_profile()


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    args = build_parser().parse_args(arguments)
    try:
        if args.command == "status":
            _assert_exact_control(args.state, STATE_PATH, "launch state")
            state = B.load_json(args.state)
            print(json.dumps({
                "status": state.get("status"),
                "worker_pid": state.get("worker_pid"),
                "cells": [
                    {"cell_id": row.get("cell_id"), "status": row.get("status")}
                    for row in state.get("cells", []) if isinstance(row, Mapping)
                ],
            }, indent=2, sort_keys=True))
            return 0
        if args.command == "_run-plan":
            _assert_exact_control(args.job, JOB_PATH, "launch job")
            return _BASE_WORKER_RUN(args.job)
        if args.command == "pre":
            _assert_exact_control(args.receipt, PRE_RECEIPT_PATH, "PRE receipt")
            payload = preflight(args.symbol, args.data_receipt, args.build_receipt, args.run_root)
            digest = B.atomic_json(args.receipt, payload, replace=False)
            output = {"status": "PASS", "receipt": str(args.receipt.resolve()), "sha256": digest}
            code = 0
        elif args.command == "launch":
            output = launch_detached(args.pre_receipt, args.pre_sha256, args.authorization, args.state, resume=False)
            code = 0
        else:
            _assert_exact_control(args.receipt, POST_RECEIPT_PATH, "POST receipt")
            payload = postflight(args.pre_receipt, args.pre_sha256, args.state)
            digest = B.atomic_json(args.receipt, payload, replace=False)
            output = {"status": payload["status"], "receipt": str(args.receipt.resolve()), "sha256": digest, "decision": payload["decision"]}
            code = 0 if payload["status"] == "PASS" else 1
        print(json.dumps(output, indent=2, sort_keys=True))
        return code
    except (B.AuditError, OSError, sqlite3.Error, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps(B.invalid_receipt(args.command.upper(), exc), indent=2, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
