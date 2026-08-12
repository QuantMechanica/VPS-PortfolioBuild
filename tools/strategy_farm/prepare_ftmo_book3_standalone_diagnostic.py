#!/usr/bin/env python3
"""Plan/apply one governed standalone QM5_13108 diagnostic while Factory is OFF.

This controller creates a new content-addressed Q02 work item and a dedicated
non-releasing hold.  It never runs MT5, never consumes or changes the pending
V2 R2 rung, never progresses the V2 ladder, and never grants release or Factory
ON authority.  Dry-run is the default; apply is hash-bound and create-only.
"""

from __future__ import annotations

import argparse
import copy
import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    import prepare_ftmo_book3_q02 as base
except ModuleNotFoundError:  # pragma: no cover - package import
    from tools.strategy_farm import prepare_ftmo_book3_q02 as base


SCHEMA_PREPARE = "qm.ftmo-book3-standalone-diagnostic-prepare-plan/v1"
SCHEMA_RECEIPT = "qm.ftmo-book3-standalone-diagnostic-maintenance-receipt/v1"
SCHEMA_INTENT = "qm.ftmo-book3-standalone-diagnostic-mutation-intent/v1"
SCHEMA_RECONCILE_RECEIPT = (
    "qm.ftmo-book3-standalone-diagnostic-intent-reconcile-receipt/v1"
)
SCHEMA_SNAPSHOT_ATTESTATION = (
    "qm.ftmo-book3-standalone-diagnostic-snapshot-attestation/v1"
)
PAYLOAD_SCHEMA = "qm.ftmo-book3-standalone-diagnostic-work-item-payload/v1"
IDENTITY_SCHEMA = "qm.ftmo-book3-standalone-diagnostic-work-item/v1"
MEASUREMENT_CONTRACT = "FTMO_BOOK3_STANDALONE_DIAGNOSTIC_V1"
EVIDENCE_VINTAGE = "FTMO_BOOK3_20260730_R2_STANDALONE_DIAGNOSTIC_V1"
MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
DIAGNOSTIC_CODE = "D13108"
DIAGNOSTIC_PURPOSE = "portfolio_component_evaluation"
COMPILE_POLICY = "MANIFEST_PINNED_STAGED_EX5_NO_RECOMPILE_V1"
V2_R2_WORK_ITEM_ID = "034a2bcd-1a69-5437-9654-6e4b3e9b0ff9"
PREREGISTRATION_REL = Path(
    "docs/ops/evidence/2026-07-30_ftmo_book3_r2_standalone_diagnostic_preregistration_v1.md"
)
HOLD_CODE = "FTMO_BOOK3_STANDALONE_DIAGNOSTIC_ISOLATED_ONLY"
HOLD_REASON = (
    "OWNER-authorized FTMO Book-3 QM5_13108 standalone diagnostic; "
    "isolated T10 execution only; no ladder progression or release authority"
)
TERMINAL = "T10"
FORBIDDEN_TERMINALS = (
    "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T_LIVE"
)
FROM_DATE = "2018.07.02"
TO_DATE = "2025.12.31"
EXPECTED_EXECUTION_INPUT_COUNT = 307
SPEC = {
    "code": DIAGNOSTIC_CODE,
    "ea_id": "QM5_13108",
    "symbol": "XTIUSD.DWX",
    "period": "D1",
    "ea_dir": "QM5_13108_xti-mtsm-s2",
    "set_name": "QM5_13108_xti-mtsm-s2_XTIUSD.DWX_D1_backtest.set",
    "basket_symbols": (),
    "evidence_run_id": None,
}
V2_R2_WORK_ITEM_PREIMAGE_COLUMNS = (
    "id",
    "kind",
    "phase",
    "ea_id",
    "symbol",
    "setfile_path",
    "status",
    "verdict",
    "attempt_count",
    "parent_task_id",
    "evidence_path",
    "claimed_by",
    "payload_json",
    "created_at",
    "updated_at",
)

DEFAULT_ROOT = base.DEFAULT_ROOT
DEFAULT_REPO = base.DEFAULT_REPO
DEFAULT_ARTIFACT_ROOT = base.DEFAULT_ARTIFACT_ROOT
DEFAULT_REPORT_ROOT = base.DEFAULT_REPORT_ROOT
DEFAULT_COMMON_QM = base.DEFAULT_COMMON_QM
DEFAULT_T10_BASES = base.DEFAULT_T10_BASES
DEFAULT_CALENDAR_SOURCE = base.DEFAULT_CALENDAR_SOURCE
DEFAULT_CALENDAR_COMMON = base.DEFAULT_CALENDAR_COMMON

RUNTIME_SOURCE_ROLES = (
    "preparation_controller",
    "base_preparation_controller",
    "isolated_runner",
    "terminal_worker",
    "farmctl",
    "factory_mutation_lock",
    "phase_utils",
    "run_smoke",
    "preregistration",
    "qm_tasks_manifest",
    "factory_process_scope",
    "cache_audit",
    "phase_ids",
    "managed_codex",
    "process_identity",
    "phase_runner_allowlist",
    "q09_news_contract",
    "q09_news_schema",
    "tester_defaults",
    "news_calendar_gate",
    "windows_job_object",
)
RECOVERY_POLICY = {
    "classification": "FAIL_CLOSED",
    "automatic_reapply_forbidden": True,
    "database_replay_forbidden": True,
    "authenticated_reconcile_available": True,
    "reconcile_mutates_database": False,
    "requirements": [
        "exact manifest and intent SHA-256",
        "exact plan ID, source commit and Factory-OFF SHA-256",
        "exact operator-supplied post-commit logical DB SHA-256",
        "snapshot logical state equals manifest preimage",
        "exact committed diagnostic work item and hold",
        "excluded pending V2 R2 remains byte-content bound and unchanged",
        "empty factory terminal/tester process census",
        "create-only final reconciliation receipt",
    ],
}


class ContractError(RuntimeError):
    pass


def _canonical_sha(value: Any) -> str:
    return base.canonical_sha(value)


def _sha(path: Path) -> str:
    return base.sha256_file(path)


def _path_identity(path: Path) -> str:
    return os.path.normcase(os.path.abspath(str(path)))


def _is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _validate_governed_output_paths(
    *,
    paths: dict[str, Path],
    artifact_root: Path,
    report_root: Path,
    protected_paths: tuple[Path, ...] = (),
) -> None:
    roots = (artifact_root, report_root)
    if any(not root.is_absolute() for root in roots):
        raise ContractError("governed artifact/report roots must be absolute")
    resolved_roots = tuple(root.resolve(strict=False) for root in roots)
    identities: dict[str, str] = {}
    for role, path in paths.items():
        if not path.is_absolute():
            raise ContractError(f"{role} path must be absolute: {path}")
        resolved = path.resolve(strict=False)
        if _path_identity(path) != _path_identity(resolved):
            raise ContractError(
                f"{role} path uses an alias, symlink, or traversal: {path}"
            )
        if not any(
            resolved != root and _is_relative_to(resolved, root)
            for root in resolved_roots
        ):
            raise ContractError(
                f"{role} path is outside governed artifact/report roots: {path}"
            )
        identity = _path_identity(resolved)
        if identity in identities.values():
            raise ContractError("governed output paths must be distinct")
        identities[role] = identity
    protected = {
        _path_identity(path.resolve(strict=False))
        for path in protected_paths
        if path.is_absolute()
    }
    collisions = sorted(
        role for role, identity in identities.items() if identity in protected
    )
    if collisions:
        raise ContractError(
            f"governed output aliases a source/input path: {collisions}"
        )


def _strict_payload(raw: str, label: str) -> dict[str, Any]:
    try:
        return base._strict_json_object(raw.encode("utf-8"), label)
    except base.ContractError as exc:
        raise ContractError(str(exc)) from exc


def _plan_core(plan: dict[str, Any]) -> dict[str, Any]:
    core = copy.deepcopy(plan)
    core.pop("generated_at_utc", None)
    core.pop("plan_id", None)
    return core


def _assign_plan_id(plan: dict[str, Any]) -> None:
    plan["plan_id"] = _canonical_sha(_plan_core(plan))


def _validate_plan_id(plan: dict[str, Any]) -> None:
    actual = _canonical_sha(_plan_core(plan))
    if plan.get("plan_id") != actual:
        raise ContractError(
            f"plan_id mismatch: expected={plan.get('plan_id')} actual={actual}"
        )


def _content_uuid(content_sha256: str) -> str:
    try:
        return base._content_uuid(content_sha256)
    except Exception as exc:
        raise ContractError("execution bundle SHA-256 is invalid") from exc


def _topology_errors(
    *, root: Path, repo: Path, artifact_root: Path, report_root: Path,
    common_qm: Path, t10_bases: Path, calendar_source: Path,
    calendar_common: Path, db: Path, flag: Path,
) -> list[str]:
    expected = {
        "root": DEFAULT_ROOT,
        "repo": DEFAULT_REPO,
        "artifact_root": DEFAULT_ARTIFACT_ROOT,
        "report_root": DEFAULT_REPORT_ROOT,
        "common_qm": DEFAULT_COMMON_QM,
        "t10_bases": DEFAULT_T10_BASES,
        "calendar_source": DEFAULT_CALENDAR_SOURCE,
        "calendar_common": DEFAULT_CALENDAR_COMMON,
        "db": root / "state/farm_state.sqlite",
        "flag": root / "state/FACTORY_OFF.flag",
    }
    actual = {
        "root": root,
        "repo": repo,
        "artifact_root": artifact_root,
        "report_root": report_root,
        "common_qm": common_qm,
        "t10_bases": t10_bases,
        "calendar_source": calendar_source,
        "calendar_common": calendar_common,
        "db": db,
        "flag": flag,
    }
    return [
        f"canonical topology mismatch for {label}: expected={expected[label]} actual={path}"
        for label, path in actual.items()
        if _path_identity(path) != _path_identity(expected[label])
    ]


def _source_scope(repo: Path, controller_path: Path) -> list[Path]:
    ea_dir = repo / "framework/EAs" / SPEC["ea_dir"]
    return [
        controller_path,
        repo / "tools/strategy_farm/prepare_ftmo_book3_q02.py",
        repo / "tools/strategy_farm/isolated_work_item_runner.py",
        repo / "tools/strategy_farm/terminal_worker.py",
        repo / "tools/strategy_farm/farmctl.py",
        repo / "tools/strategy_farm/factory_mutation_lock.py",
        repo / "framework/scripts/_phase_utils.py",
        repo / "framework/scripts/run_smoke.ps1",
        repo / "tools/strategy_farm/qm_tasks.manifest.ps1",
        repo / "tools/strategy_farm/factory_process_scope.ps1",
        repo / "tools/strategy_farm/cache_audit.py",
        repo / "tools/strategy_farm/phase_ids.py",
        repo / "tools/strategy_farm/managed_codex.py",
        repo / "tools/strategy_farm/process_identity.py",
        repo / "tools/strategy_farm/phase_runner_allowlist.v1.json",
        repo / "tools/strategy_farm/q09_news_contract.py",
        repo / "tools/strategy_farm/q09_news_schema.py",
        repo / "framework/registry/tester_defaults.json",
        repo / "tools/strategy_farm/news_calendar_gate.py",
        repo / "tools/strategy_farm/windows_job_object.py",
        repo / base.COMPILE_CONTROLLER_REL,
        repo / PREREGISTRATION_REL,
        ea_dir / f"{SPEC['ea_dir']}.mq5",
        ea_dir / "sets" / SPEC["set_name"],
        repo / "framework/include/QM",
        repo / "framework/registry/magic_numbers.csv",
        repo / "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt",
        repo / "framework/registry/live_commission.json",
        repo / "framework/registry/venue_cost_model.json",
        repo / "framework/registry/dwx_symbol_matrix.csv",
        repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json",
        repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json",
    ]


def _git_identity(
    repo: Path, controller_path: Path, source_commit: str
) -> tuple[dict[str, Any], list[str]]:
    errors: list[str] = []
    result: dict[str, Any] = {"authoritative_source_commit": source_commit}
    try:
        head = base._git(repo, "rev-parse", "HEAD").lower()
        resolved = base._git(repo, "rev-parse", f"{source_commit}^{{commit}}").lower()
        if resolved != source_commit:
            errors.append("authoritative source commit did not resolve exactly")
        if head != source_commit:
            errors.append("authoritative source commit must equal controller HEAD")
        paths = _source_scope(repo, controller_path)
        relative: list[str] = []
        for path in paths:
            try:
                relative.append(path.resolve().relative_to(repo.resolve()).as_posix())
            except (OSError, ValueError) as exc:
                errors.append(f"source scope path is invalid: {path}: {exc}")
        porcelain = ""
        if relative:
            porcelain = base._git(
                repo,
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
                "--",
                *sorted(set(relative)),
            )
            if porcelain:
                errors.append("diagnostic source scope is not clean")
        tracked = base._git(repo, "ls-files", "--", *sorted(set(relative)))
        tracked_rows = [row for row in tracked.splitlines() if row.strip()]
        if not tracked_rows:
            errors.append("diagnostic source scope has no tracked files")
        result.update(
            {
                "controller_head_commit": head,
                "source_scope": sorted(set(relative)),
                "tracked_source_file_count": len(tracked_rows),
                "source_scope_porcelain": porcelain,
            }
        )
    except Exception as exc:
        errors.append(f"git identity failed: {exc}")
    return result, errors


def _repo_artifacts(repo: Path, controller_path: Path) -> list[dict[str, Any]]:
    ea_dir = repo / "framework/EAs" / SPEC["ea_dir"]
    return [
        base._artifact(controller_path, "preparation_controller"),
        base._artifact(repo / "tools/strategy_farm/prepare_ftmo_book3_q02.py", "base_preparation_controller"),
        base._artifact(repo / "tools/strategy_farm/isolated_work_item_runner.py", "isolated_runner"),
        base._artifact(repo / "tools/strategy_farm/terminal_worker.py", "terminal_worker"),
        base._artifact(repo / "tools/strategy_farm/farmctl.py", "farmctl"),
        base._artifact(repo / "tools/strategy_farm/factory_mutation_lock.py", "factory_mutation_lock"),
        base._artifact(repo / "framework/scripts/_phase_utils.py", "phase_utils"),
        base._artifact(repo / "framework/scripts/run_smoke.ps1", "run_smoke"),
        base._artifact(repo / "tools/strategy_farm/qm_tasks.manifest.ps1", "qm_tasks_manifest"),
        base._artifact(repo / "tools/strategy_farm/factory_process_scope.ps1", "factory_process_scope"),
        base._artifact(repo / "tools/strategy_farm/cache_audit.py", "cache_audit"),
        base._artifact(repo / "tools/strategy_farm/phase_ids.py", "phase_ids"),
        base._artifact(repo / "tools/strategy_farm/managed_codex.py", "managed_codex"),
        base._artifact(repo / "tools/strategy_farm/process_identity.py", "process_identity"),
        base._artifact(
            repo / "tools/strategy_farm/phase_runner_allowlist.v1.json",
            "phase_runner_allowlist",
        ),
        base._artifact(
            repo / "tools/strategy_farm/q09_news_contract.py", "q09_news_contract"
        ),
        base._artifact(repo / "tools/strategy_farm/q09_news_schema.py", "q09_news_schema"),
        base._artifact(
            repo / "framework/registry/tester_defaults.json", "tester_defaults"
        ),
        base._artifact(repo / "tools/strategy_farm/news_calendar_gate.py", "news_calendar_gate"),
        base._artifact(repo / "tools/strategy_farm/windows_job_object.py", "windows_job_object"),
        base._artifact(repo / base.COMPILE_CONTROLLER_REL, "compile_controller"),
        base._artifact(repo / PREREGISTRATION_REL, "preregistration"),
        base._artifact(ea_dir / f"{SPEC['ea_dir']}.mq5", f"mq5:{SPEC['ea_dir']}"),
        base._artifact(ea_dir / "sets" / SPEC["set_name"], f"set:{DIAGNOSTIC_CODE}"),
        base._tree_artifact(repo / "framework/include/QM", "framework_include_tree"),
        base._artifact(repo / "framework/registry/magic_numbers.csv", "magic_registry"),
        base._artifact(repo / "framework/include/QM/QM_MagicResolver.mqh", "magic_resolver"),
        base._artifact(repo / "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt", "tester_cost_basis"),
        base._artifact(repo / "framework/registry/live_commission.json", "live_commission"),
        base._artifact(repo / "framework/registry/venue_cost_model.json", "venue_cost_model"),
        base._artifact(repo / "framework/registry/dwx_symbol_matrix.csv", "dwx_symbol_matrix"),
        base._artifact(repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json", "ftmo_official_rules_snapshot"),
        base._artifact(repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json", "ftmo_rulepack"),
    ]


def _runtime_source_artifacts(
    artifacts: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    by_role = base._artifact_map(artifacts)
    rows: list[dict[str, Any]] = []
    for role in RUNTIME_SOURCE_ROLES:
        item = by_role.get(role)
        if not isinstance(item, dict) or item.get("valid") is not True:
            continue
        rows.append(
            {
                "role": role,
                "path": str(item["path"]),
                "sha256": str(item["sha256"]),
                "bytes": int(item["bytes"]),
            }
        )
    return sorted(rows, key=lambda item: (item["role"], item["path"]))


def _magic_errors(registry: Path, resolver: Path) -> list[str]:
    errors: list[str] = []
    if not registry.is_file() or not resolver.is_file():
        return ["magic registry or resolver missing"]
    with registry.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row.get("ea_id") == "13108" and row.get("status") == "active"
        ]
    observed = {
        (str(row.get("symbol_slot")), str(row.get("symbol")), str(row.get("magic")))
        for row in rows
    }
    if observed != {("0", "XTIUSD.DWX", "131080000")}:
        errors.append(f"13108 registry tuple mismatch: {sorted(observed)}")
    text = resolver.read_text(encoding="utf-8-sig")
    match = re.search(r'QM_MAGIC_REGISTRY_SHA256\s+"([0-9A-Fa-f]{64})"', text)
    if not match or match.group(1).lower() != _sha(registry):
        errors.append("magic resolver registry SHA-256 mismatch")
    return errors


def _excluded_v2_r2(
    conn: sqlite3.Connection,
) -> tuple[dict[str, Any] | None, list[str]]:
    errors: list[str] = []
    row = conn.execute(
        "SELECT * FROM work_items WHERE id=?",
        (V2_R2_WORK_ITEM_ID,),
    ).fetchone()
    if row is None:
        return None, [f"pending V2 R2 row is missing: {V2_R2_WORK_ITEM_ID}"]
    hold_row = conn.execute(
        "SELECT work_item_id,hold_code,reason,active,release_on_restart,created_at,"
        "updated_at,released_at,release_note FROM work_item_holds WHERE work_item_id=?",
        (V2_R2_WORK_ITEM_ID,),
    ).fetchone()
    hold = dict(hold_row) if hold_row is not None else None
    if hold is None:
        errors.append("pending V2 R2 non-releasing hold is missing")
    else:
        hold_exact = {
            "hold_code": (hold.get("hold_code"), base.HOLD_CODE),
            "reason": (hold.get("reason"), base.HOLD_REASON),
            "active": (hold.get("active"), 1),
            "release_on_restart": (hold.get("release_on_restart"), 0),
            "released_at": (hold.get("released_at"), None),
            "release_note": (hold.get("release_note"), None),
        }
        for label, (actual, expected) in hold_exact.items():
            if actual != expected:
                errors.append(
                    "pending V2 R2 hold "
                    f"{label} mismatch: expected={expected!r} actual={actual!r}"
                )
    row_map = dict(row)
    missing_columns = sorted(
        set(V2_R2_WORK_ITEM_PREIMAGE_COLUMNS) - set(row_map)
    )
    if missing_columns:
        errors.append(
            f"pending V2 R2 full row preimage is unavailable: {missing_columns}"
        )
        row_summary = None
        row_sha = None
    else:
        row_summary = {
            key: row_map[key] for key in V2_R2_WORK_ITEM_PREIMAGE_COLUMNS
        }
        row_sha = _canonical_sha(row_summary)
    raw = str(row_map.get("payload_json") or "{}")
    try:
        payload = _strict_payload(raw, "pending V2 R2 payload")
    except ContractError as exc:
        payload = {}
        errors.append(str(exc))
    exact = {
        "kind": (row_map.get("kind"), "backtest"),
        "phase": (row_map.get("phase"), "Q02"),
        "ea_id": (row_map.get("ea_id"), "QM5_13108"),
        "symbol": (row_map.get("symbol"), "XTIUSD.DWX"),
        "status": (row_map.get("status"), "pending"),
        "verdict": (row_map.get("verdict"), None),
        "attempt_count": (row_map.get("attempt_count"), 0),
        "parent_task_id": (row_map.get("parent_task_id"), None),
        "claimed_by": (row_map.get("claimed_by"), None),
        "evidence_path": (row_map.get("evidence_path"), None),
        "measurement_contract": (
            payload.get("measurement_contract"),
            base.FIDELITY_MEASUREMENT_CONTRACT,
        ),
        "measurement_rung": (payload.get("measurement_rung"), "R2"),
        "measurement_sequence": (payload.get("measurement_sequence"), 4),
        "terminal": (str(payload.get("terminal") or "").upper(), "T10"),
    }
    for label, (actual, expected) in exact.items():
        if actual != expected:
            errors.append(
                f"pending V2 R2 {label} mismatch: expected={expected!r} actual={actual!r}"
            )
    return (
        {
            "id": row_map.get("id"),
            "payload_sha256": hashlib.sha256(raw.encode("utf-8")).hexdigest(),
            "row": row_summary,
            "row_sha256": row_sha,
            "status": row_map.get("status"),
            "verdict": row_map.get("verdict"),
            "claimed_by": row_map.get("claimed_by"),
            "evidence_path": row_map.get("evidence_path"),
            "hold": hold,
        },
        errors,
    )


def _item_contract(
    *, repo: Path, artifact_root: Path, report_root: Path, common_qm: Path,
    t10_bases: Path, calendar_source: Path, calendar_common: Path,
    git_identity: dict[str, Any], compile_binding: dict[str, Any],
    ex5_sha256: str, artifacts: list[dict[str, Any]],
    excluded_v2: dict[str, Any],
) -> dict[str, Any]:
    amap = base._artifact_map(artifacts)
    ea_dir = repo / "framework/EAs" / SPEC["ea_dir"]
    setfile = ea_dir / "sets" / SPEC["set_name"]
    staged = artifact_root / "canonical_staged_ex5" / f"{SPEC['ea_dir']}.ex5"
    execution_inputs = base._execution_input_artifacts(artifacts)
    runtime_sources = _runtime_source_artifacts(artifacts)
    execution_inputs_sha = _canonical_sha(execution_inputs)
    runtime_sources_sha = _canonical_sha(runtime_sources)
    data_bundle_sha = base._artifact_bundle_sha(
        artifacts,
        ("t10_terminal_binary", "t10_metatester_binary", "t10_symbol_spec", "history:", "ticks:"),
    )
    calendar_bundle_sha = base._artifact_bundle_sha(
        artifacts, ("calendar_source:", "calendar_common:")
    )
    cost_bundle_sha = _canonical_sha(
        [
            {
                "role": role,
                "path": amap[role]["path"],
                "sha256": amap[role]["sha256"],
                "bytes": amap[role]["bytes"],
            }
            for role in base.COST_ARTIFACT_ROLES
        ]
    )
    identity = {
        "schema": IDENTITY_SCHEMA,
        "measurement_contract": MEASUREMENT_CONTRACT,
        "evidence_vintage": EVIDENCE_VINTAGE,
        "money_basis": MONEY_BASIS,
        "diagnostic_code": DIAGNOSTIC_CODE,
        "diagnostic_purpose": DIAGNOSTIC_PURPOSE,
        "compile_policy": COMPILE_POLICY,
        "no_ladder_progression": True,
        "no_joint_admission": True,
        "no_release_authority": True,
        "supersedes_work_item_id": None,
        "excluded_v2_r2_work_item_id": excluded_v2["id"],
        "excluded_v2_r2_payload_sha256": excluded_v2["payload_sha256"],
        "excluded_v2_r2_row_sha256": excluded_v2["row_sha256"],
        "excluded_v2_r2_hold_sha256": _canonical_sha(excluded_v2["hold"]),
        "ea_id": SPEC["ea_id"],
        "symbol": SPEC["symbol"],
        "period": SPEC["period"],
        "terminal": TERMINAL,
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "source_commit": git_identity["authoritative_source_commit"],
        "mq5_sha256": amap[f"mq5:{SPEC['ea_dir']}"]["sha256"],
        "setfile_sha256": amap[f"set:{DIAGNOSTIC_CODE}"]["sha256"],
        "staged_ex5_sha256": ex5_sha256,
        "include_tree_sha256": amap["framework_include_tree"]["sha256"],
        "preregistration_sha256": amap["preregistration"]["sha256"],
        "isolated_runner_sha256": amap["isolated_runner"]["sha256"],
        "terminal_worker_sha256": amap["terminal_worker"]["sha256"],
        "preparation_controller_sha256": amap["preparation_controller"]["sha256"],
        "compile_manifest_path": compile_binding["path"],
        "compile_manifest_sha256": compile_binding["sha256"],
        "compile_manifest_bytes": compile_binding["bytes"],
        "compile_source_commit": compile_binding["source_commit"],
        "compile_controller_sha256": compile_binding["compile_controller"]["sha256"],
        "runtime_source_artifacts_sha256": runtime_sources_sha,
        "execution_input_artifact_count": len(execution_inputs),
        "execution_input_artifacts_sha256": execution_inputs_sha,
        "execution_data_bundle_sha256": data_bundle_sha,
        "calendar_bundle_sha256": calendar_bundle_sha,
        "cost_bundle_sha256": cost_bundle_sha,
        "ftmo_official_rules_snapshot_sha256": amap["ftmo_official_rules_snapshot"]["sha256"],
        "ftmo_rulepack_sha256": amap["ftmo_rulepack"]["sha256"],
    }
    execution_sha = _canonical_sha(identity)
    work_item_id = _content_uuid(execution_sha)
    evidence_root = report_root / work_item_id
    trade_source = common_qm / "q08_trades/13108_XTIUSD_DWX.jsonl"
    payload = {
        "schema": PAYLOAD_SCHEMA,
        "measurement_contract": MEASUREMENT_CONTRACT,
        "evidence_vintage": EVIDENCE_VINTAGE,
        "money_basis": MONEY_BASIS,
        "diagnostic_code": DIAGNOSTIC_CODE,
        "diagnostic_purpose": DIAGNOSTIC_PURPOSE,
        "compile_policy": COMPILE_POLICY,
        "no_ladder_progression": True,
        "no_joint_admission": True,
        "no_release_authority": True,
        "supersedes_work_item_id": None,
        "excluded_v2_r2_work_item_id": excluded_v2["id"],
        "excluded_v2_r2_payload_sha256": excluded_v2["payload_sha256"],
        "excluded_v2_r2_row_sha256": identity["excluded_v2_r2_row_sha256"],
        "excluded_v2_r2_hold_sha256": identity["excluded_v2_r2_hold_sha256"],
        "execution_bundle_sha256": execution_sha,
        "authoritative_source_commit": git_identity["authoritative_source_commit"],
        "controller_head_commit": git_identity["controller_head_commit"],
        "terminal": TERMINAL,
        "avoid_terminals": list(FORBIDDEN_TERMINALS),
        "ea_dir_name": SPEC["ea_dir"],
        "host_timeframe": SPEC["period"],
        "expected_setfile_sha256": identity["setfile_sha256"],
        "expected_mq5_sha256": identity["mq5_sha256"],
        "staged_ex5_path": str(staged),
        "staged_ex5_sha256": ex5_sha256,
        "framework_include_tree_sha256": identity["include_tree_sha256"],
        "preregistration_sha256": identity["preregistration_sha256"],
        "isolated_runner_path": amap["isolated_runner"]["path"],
        "isolated_runner_sha256": identity["isolated_runner_sha256"],
        "terminal_worker_path": amap["terminal_worker"]["path"],
        "terminal_worker_sha256": identity["terminal_worker_sha256"],
        "preparation_controller_path": amap["preparation_controller"]["path"],
        "preparation_controller_sha256": identity["preparation_controller_sha256"],
        "compile_manifest_path": compile_binding["path"],
        "compile_manifest_sha256": compile_binding["sha256"],
        "compile_manifest_bytes": compile_binding["bytes"],
        "compile_source_commit": compile_binding["source_commit"],
        "compile_controller_path": compile_binding["compile_controller"]["path"],
        "compile_controller_sha256": compile_binding["compile_controller"]["sha256"],
        "runtime_source_artifacts": runtime_sources,
        "runtime_source_artifacts_sha256": runtime_sources_sha,
        "execution_input_artifacts": execution_inputs,
        "execution_input_artifact_count": len(execution_inputs),
        "execution_input_artifacts_sha256": execution_inputs_sha,
        "execution_data_bundle_sha256": data_bundle_sha,
        "t10_terminal_binary_path": amap["t10_terminal_binary"]["path"],
        "t10_terminal_binary_sha256": amap["t10_terminal_binary"]["sha256"],
        "t10_metatester_binary_path": amap["t10_metatester_binary"]["path"],
        "t10_metatester_binary_sha256": amap["t10_metatester_binary"]["sha256"],
        "t10_symbol_spec_path": str(t10_bases / "symbols.custom.dat"),
        "t10_symbol_spec_sha256": amap["t10_symbol_spec"]["sha256"],
        "history_tick_window": {
            "from": FROM_DATE,
            "to": TO_DATE,
            "symbols": list(base.DATA_SYMBOLS),
        },
        "calendar_source_dir": str(calendar_source),
        "calendar_common_dir": str(calendar_common),
        "calendar_bundle_sha256": calendar_bundle_sha,
        "tester_cost_basis_path": amap["tester_cost_basis"]["path"],
        "tester_cost_basis_sha256": amap["tester_cost_basis"]["sha256"],
        "live_commission_path": amap["live_commission"]["path"],
        "live_commission_sha256": amap["live_commission"]["sha256"],
        "venue_cost_model_path": amap["venue_cost_model"]["path"],
        "venue_cost_model_sha256": amap["venue_cost_model"]["sha256"],
        "dwx_symbol_matrix_path": amap["dwx_symbol_matrix"]["path"],
        "dwx_symbol_matrix_sha256": amap["dwx_symbol_matrix"]["sha256"],
        "cost_bundle_sha256": cost_bundle_sha,
        "commission_per_lot": 0,
        "commission_per_side_native": 0,
        "ftmo_official_rules_snapshot_path": amap["ftmo_official_rules_snapshot"]["path"],
        "ftmo_official_rules_snapshot_sha256": identity["ftmo_official_rules_snapshot_sha256"],
        "ftmo_rulepack_path": amap["ftmo_rulepack"]["path"],
        "ftmo_rulepack_sha256": amap["ftmo_rulepack"]["sha256"],
        "from_year": 2018,
        "to_year": 2025,
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "tester_currency": "USD",
        "tester_deposit": 100000,
        "timeout_min": 240,
        "risk_mode": "RISK_FIXED",
        "risk_fixed": 1000,
        "risk_percent": 0,
        "model": 4,
        "q08_expected_magic": 131080000,
        "q08_expected_symbol": "XTIUSD.DWX",
        "q08_expected_money_basis": MONEY_BASIS,
        "post_run_file_common_source": str(trade_source),
        "post_run_file_common_streams": [],
        "isolated_only": True,
        "auto_enqueue": False,
        "auto_promote": False,
        "next_phase": None,
        "factory_on_authorized": False,
    }
    return {
        "code": DIAGNOSTIC_CODE,
        "work_item_id": work_item_id,
        "kind": "backtest",
        "phase": "Q02",
        "ea_id": SPEC["ea_id"],
        "symbol": SPEC["symbol"],
        "setfile_path": str(setfile),
        "report_root": str(evidence_root),
        "execution_bundle_sha256": execution_sha,
        "payload_json": json.dumps(
            payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        ),
        "hold": {
            "hold_code": HOLD_CODE,
            "reason": HOLD_REASON,
            "active": 1,
            "release_on_restart": 0,
        },
    }


def _build_artifacts(
    *, repo: Path, controller_path: Path, artifact_root: Path,
    t10_bases: Path, calendar_source: Path, calendar_common: Path,
    ex5_sha256: str,
) -> list[dict[str, Any]]:
    staged = artifact_root / "canonical_staged_ex5" / f"{SPEC['ea_dir']}.ex5"
    log = artifact_root / "canonical_compile_logs" / f"{SPEC['ea_dir']}.compile.log"
    return (
        _repo_artifacts(repo, controller_path)
        + [base._artifact(artifact_root / base.COMPILE_MANIFEST_NAME, "compile_manifest")]
        + [
            base._artifact(staged, f"canonical_staged_ex5:{SPEC['ea_dir']}", expected_sha256=ex5_sha256),
            base._artifact(log, f"canonical_compile_log:{SPEC['ea_dir']}"),
        ]
        + base._execution_data_artifacts(t10_bases)
        + base._calendar_artifacts(calendar_source, calendar_common)
    )


def _validate_artifact_contract(
    artifacts: list[dict[str, Any]], *, repo: Path, t10_bases: Path,
    calendar_source: Path, calendar_common: Path,
) -> list[str]:
    errors = [
        f"artifact invalid: {item.get('role')}:{item.get('reason', 'invalid')}"
        for item in artifacts
        if item.get("valid") is not True
    ]
    roles = [str(item.get("role") or "") for item in artifacts]
    paths = [str(item.get("path") or "").casefold() for item in artifacts]
    if len(roles) != len(set(roles)):
        errors.append("artifact roles are not unique")
    if len(paths) != len(set(paths)):
        errors.append("artifact paths are not unique")
    expected_paths = base._required_execution_input_paths(
        repo=repo,
        t10_bases=t10_bases,
        calendar_source=calendar_source,
        calendar_common=calendar_common,
    )
    inputs = base._execution_input_artifacts(artifacts)
    if len(inputs) != EXPECTED_EXECUTION_INPUT_COUNT:
        errors.append(
            "execution input artifact cardinality mismatch: "
            f"expected={EXPECTED_EXECUTION_INPUT_COUNT} actual={len(inputs)}"
        )
    if {item["role"] for item in inputs} != set(expected_paths):
        errors.append("execution input artifact roles are not exact")
    else:
        for item in inputs:
            if item["path"] != expected_paths[item["role"]]:
                errors.append(f"execution input path mismatch: {item['role']}")
    runtime = _runtime_source_artifacts(artifacts)
    if [row["role"] for row in runtime] != sorted(RUNTIME_SOURCE_ROLES):
        errors.append("runtime source artifact roles are not exact")
    return errors


def build_prepare_plan(
    *, source_commit: str, root: Path | None = None, repo: Path | None = None,
    artifact_root: Path | None = None, report_root: Path | None = None,
    common_qm: Path | None = None, controller_path: Path | None = None,
    t10_bases: Path | None = None, calendar_source: Path | None = None,
    calendar_common: Path | None = None,
) -> dict[str, Any]:
    root = Path(root or DEFAULT_ROOT)
    repo = Path(repo or DEFAULT_REPO)
    artifact_root = Path(artifact_root or DEFAULT_ARTIFACT_ROOT)
    report_root = Path(report_root or DEFAULT_REPORT_ROOT)
    common_qm = Path(common_qm or DEFAULT_COMMON_QM)
    controller_path = Path(controller_path or __file__).resolve()
    t10_bases = Path(t10_bases or DEFAULT_T10_BASES)
    calendar_source = Path(calendar_source or DEFAULT_CALENDAR_SOURCE)
    calendar_common = Path(calendar_common or DEFAULT_CALENDAR_COMMON)
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise ContractError(
            "source commit must be exactly 40 lowercase hexadecimal characters"
        )
    db = root / "state/farm_state.sqlite"
    flag = root / "state/FACTORY_OFF.flag"
    errors = _topology_errors(
        root=root,
        repo=repo,
        artifact_root=artifact_root,
        report_root=report_root,
        common_qm=common_qm,
        t10_bases=t10_bases,
        calendar_source=calendar_source,
        calendar_common=calendar_common,
        db=db,
        flag=flag,
    )
    git_identity, git_errors = _git_identity(repo, controller_path, source_commit)
    errors.extend(git_errors)
    compile_binding: dict[str, Any] = {}
    ex5_by_ea: dict[str, str] = {}
    try:
        compile_binding, ex5_by_ea = base._load_compile_manifest(
            repo=repo,
            artifact_root=artifact_root,
            flag=flag,
            authoritative_source_commit=source_commit,
        )
    except Exception as exc:
        errors.append(f"COMPILE_MANIFEST_INVALID:{exc}")
    ex5_sha = ex5_by_ea.get("QM5_13108", "")
    artifacts = _build_artifacts(
        repo=repo,
        controller_path=controller_path,
        artifact_root=artifact_root,
        t10_bases=t10_bases,
        calendar_source=calendar_source,
        calendar_common=calendar_common,
        ex5_sha256=ex5_sha,
    )
    errors.extend(
        _validate_artifact_contract(
            artifacts,
            repo=repo,
            t10_bases=t10_bases,
            calendar_source=calendar_source,
            calendar_common=calendar_common,
        )
    )
    errors.extend(
        base._validate_set(
            SPEC,
            repo / "framework/EAs" / SPEC["ea_dir"] / "sets" / SPEC["set_name"],
        )
    )
    errors.extend(
        _magic_errors(
            repo / "framework/registry/magic_numbers.csv",
            repo / "framework/include/QM/QM_MagicResolver.mqh",
        )
    )
    errors.extend(
        base._rulepack_snapshot_errors(
            repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json",
            repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json",
        )
    )
    calendar_preflight = base._calendar_preflight(calendar_source, calendar_common)
    if calendar_preflight.get("ok") is not True:
        errors.append(
            "calendar basis invalid: "
            f"{calendar_preflight.get('status')}:{calendar_preflight.get('detail') or ''}"
        )
    if not flag.is_file():
        errors.append(f"FACTORY_OFF missing: {flag}")
    if not db.is_file():
        errors.append(f"farm database missing: {db}")
    processes = base._factory_processes()
    if processes:
        errors.append(f"factory process census is not empty: {len(processes)}")
    excluded_v2: dict[str, Any] | None = None
    db_state: str | None = None
    if db.is_file():
        try:
            with base.connect_ro(db) as conn:
                errors.extend(base._schema_errors(conn))
                excluded_v2, excluded_errors = _excluded_v2_r2(conn)
                errors.extend(excluded_errors)
            db_state = base.sqlite_state_sha256(db)
        except Exception as exc:
            errors.append(f"database preflight failed: {exc}")
    operations: list[dict[str, Any]] = []
    if (
        not errors
        and excluded_v2 is not None
        and re.fullmatch(r"[0-9a-f]{64}", ex5_sha)
    ):
        operation = _item_contract(
            repo=repo,
            artifact_root=artifact_root,
            report_root=report_root,
            common_qm=common_qm,
            t10_bases=t10_bases,
            calendar_source=calendar_source,
            calendar_common=calendar_common,
            git_identity=git_identity,
            compile_binding=compile_binding,
            ex5_sha256=ex5_sha,
            artifacts=artifacts,
            excluded_v2=excluded_v2,
        )
        with base.connect_ro(db) as conn:
            if conn.execute(
                "SELECT 1 FROM work_items WHERE id=?", (operation["work_item_id"],)
            ).fetchone():
                errors.append(
                    f"planned diagnostic work item already exists: {operation['work_item_id']}"
                )
            if conn.execute(
                "SELECT 1 FROM work_item_holds WHERE work_item_id=?",
                (operation["work_item_id"],),
            ).fetchone():
                errors.append(
                    f"planned diagnostic hold already exists: {operation['work_item_id']}"
                )
        if Path(operation["report_root"]).exists():
            errors.append(f"report root already exists: {operation['report_root']}")
        if not errors:
            operations = [operation]
    inputs = base._execution_input_artifacts(artifacts)
    runtime_sources = _runtime_source_artifacts(artifacts)
    plan = {
        "schema": SCHEMA_PREPARE,
        "mode": "dry_run",
        "generated_at_utc": base.utc_now(),
        "root": str(root),
        "repo": str(repo),
        "artifact_root": str(artifact_root),
        "report_root": str(report_root),
        "common_qm": str(common_qm),
        "terminal": TERMINAL,
        "measurement_contract": MEASUREMENT_CONTRACT,
        "evidence_vintage": EVIDENCE_VINTAGE,
        "t10_bases": str(t10_bases),
        "calendar_source": str(calendar_source),
        "calendar_common": str(calendar_common),
        "calendar_preflight": calendar_preflight,
        "factory_off": {
            "path": str(flag),
            "sha256": _sha(flag) if flag.is_file() else None,
        },
        "db": {"path": str(db), "logical_state_sha256": db_state},
        "git": git_identity,
        "compile_manifest": compile_binding,
        "compiled_ex5_sha256": ex5_sha or None,
        "excluded_v2_r2": excluded_v2,
        "artifacts": artifacts,
        "factory_processes": processes,
        "controller_artifacts": {
            role: {
                "path": base._artifact_map(artifacts)[role]["path"],
                "sha256": base._artifact_map(artifacts)[role]["sha256"],
                "bytes": base._artifact_map(artifacts)[role]["bytes"],
            }
            for role in ("preparation_controller", "isolated_runner", "terminal_worker", "compile_manifest")
            if base._artifact_map(artifacts).get(role, {}).get("valid") is True
        },
        "execution_input_artifact_count": len(inputs),
        "execution_input_artifacts_sha256": _canonical_sha(inputs),
        "runtime_source_artifacts_sha256": _canonical_sha(runtime_sources),
        "operation_count": len(operations),
        "operations": operations,
        "safety": {
            "factory_remains_off": True,
            "runs_mt5": False,
            "auto_enqueue": False,
            "auto_promote": False,
            "no_ladder_progression": True,
            "no_joint_admission": True,
            "no_release_authority": True,
            "pending_v2_r2_mutated": False,
        },
        "valid": not errors and len(operations) == 1,
        "errors": errors,
    }
    _assign_plan_id(plan)
    return plan


def _validate_manifest(manifest: dict[str, Any]) -> None:
    if manifest.get("schema") != SCHEMA_PREPARE or manifest.get("valid") is not True:
        raise ContractError("manifest schema/validity mismatch")
    _validate_plan_id(manifest)
    if manifest.get("measurement_contract") != MEASUREMENT_CONTRACT:
        raise ContractError("manifest diagnostic contract mismatch")
    if manifest.get("operation_count") != 1 or len(manifest.get("operations") or []) != 1:
        raise ContractError("manifest must contain exactly one diagnostic operation")
    safety = manifest.get("safety")
    expected_safety = {
        "factory_remains_off": True,
        "runs_mt5": False,
        "auto_enqueue": False,
        "auto_promote": False,
        "no_ladder_progression": True,
        "no_joint_admission": True,
        "no_release_authority": True,
        "pending_v2_r2_mutated": False,
    }
    if safety != expected_safety:
        raise ContractError("manifest safety block mismatch")
    root = Path(str(manifest["root"]))
    topology_errors = _topology_errors(
        root=root,
        repo=Path(str(manifest["repo"])),
        artifact_root=Path(str(manifest["artifact_root"])),
        report_root=Path(str(manifest["report_root"])),
        common_qm=Path(str(manifest["common_qm"])),
        t10_bases=Path(str(manifest["t10_bases"])),
        calendar_source=Path(str(manifest["calendar_source"])),
        calendar_common=Path(str(manifest["calendar_common"])),
        db=Path(str(manifest["db"]["path"])),
        flag=Path(str(manifest["factory_off"]["path"])),
    )
    if topology_errors:
        raise ContractError("; ".join(topology_errors))


def _recompute_operation(manifest: dict[str, Any]) -> dict[str, Any]:
    repo = Path(manifest["repo"])
    artifact_root = Path(manifest["artifact_root"])
    flag = Path(manifest["factory_off"]["path"])
    git_identity, git_errors = _git_identity(
        repo,
        repo / "tools/strategy_farm/prepare_ftmo_book3_standalone_diagnostic.py",
        str(manifest["git"]["authoritative_source_commit"]),
    )
    if git_errors or git_identity != manifest["git"]:
        raise ContractError(f"diagnostic Git source binding drifted: {git_errors}")
    compile_binding, ex5_by_ea = base._load_compile_manifest(
        repo=repo,
        artifact_root=artifact_root,
        flag=flag,
        authoritative_source_commit=git_identity["authoritative_source_commit"],
    )
    if compile_binding != manifest.get("compile_manifest"):
        raise ContractError("compile manifest binding drifted")
    artifacts = manifest.get("artifacts") or []
    base._verify_artifacts(manifest)
    artifact_errors = _validate_artifact_contract(
        artifacts,
        repo=repo,
        t10_bases=Path(manifest["t10_bases"]),
        calendar_source=Path(manifest["calendar_source"]),
        calendar_common=Path(manifest["calendar_common"]),
    )
    if artifact_errors:
        raise ContractError("; ".join(artifact_errors))
    with base.connect_ro(Path(manifest["db"]["path"])) as conn:
        excluded_v2, excluded_errors = _excluded_v2_r2(conn)
    if excluded_errors or excluded_v2 != manifest.get("excluded_v2_r2"):
        raise ContractError(f"excluded V2 R2 binding drifted: {excluded_errors}")
    assert excluded_v2 is not None
    return _item_contract(
        repo=repo,
        artifact_root=artifact_root,
        report_root=Path(manifest["report_root"]),
        common_qm=Path(manifest["common_qm"]),
        t10_bases=Path(manifest["t10_bases"]),
        calendar_source=Path(manifest["calendar_source"]),
        calendar_common=Path(manifest["calendar_common"]),
        git_identity=git_identity,
        compile_binding=compile_binding,
        ex5_sha256=ex5_by_ea["QM5_13108"],
        artifacts=artifacts,
        excluded_v2=excluded_v2,
    )


def _write_new_json(path: Path, value: dict[str, Any]) -> None:
    try:
        base._write_new_json(path, value)
    except base.ContractError as exc:
        raise ContractError(str(exc)) from exc


def _open_snapshot_guard(
    path: Path, *, expected_sha256: str
) -> tuple[Any, tuple[int, int]]:
    handle = path.open("rb")
    try:
        identity = base._open_file_identity(handle)
        observed_sha, _bytes = base._hash_open_binary_file(handle)
        if (
            observed_sha != expected_sha256
            or not base._path_matches_open_file(path, identity)
        ):
            raise ContractError("recovery snapshot binding is invalid before mutation")
        return handle, identity
    except BaseException:
        handle.close()
        raise


def _revalidate_snapshot_guard(
    handle: Any,
    *,
    path: Path,
    identity: tuple[int, int],
    expected_sha256: str,
    checkpoint: str,
) -> None:
    if base._open_file_identity(handle) != identity:
        raise ContractError(f"recovery snapshot handle changed {checkpoint}")
    observed_sha, _bytes = base._hash_open_binary_file(handle)
    if (
        observed_sha != expected_sha256
        or not base._path_matches_open_file(path, identity)
    ):
        raise ContractError(f"recovery snapshot binding changed {checkpoint}")


def _read_strict_object(path: Path, label: str) -> dict[str, Any]:
    if not path.is_file():
        raise ContractError(f"{label} is missing: {path}")
    try:
        return base._strict_json_object(path.read_bytes(), label)
    except base.ContractError as exc:
        raise ContractError(str(exc)) from exc


def _committed_prepare_state(
    conn: sqlite3.Connection,
    *,
    operation: dict[str, Any],
    excluded_expected: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    work_id = str(operation["work_item_id"])
    row = conn.execute(
        "SELECT id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
        "parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at "
        "FROM work_items WHERE id=?",
        (work_id,),
    ).fetchone()
    hold_row = conn.execute(
        "SELECT work_item_id,hold_code,reason,active,release_on_restart,created_at,"
        "updated_at,released_at,release_note FROM work_item_holds WHERE work_item_id=?",
        (work_id,),
    ).fetchone()
    if row is None or hold_row is None:
        raise ContractError(
            "intent reconciliation found no complete committed diagnostic work item/hold"
        )
    created = dict(row)
    hold = dict(hold_row)
    expected_work = {
        "id": work_id,
        "kind": operation["kind"],
        "phase": operation["phase"],
        "ea_id": operation["ea_id"],
        "symbol": operation["symbol"],
        "setfile_path": operation["setfile_path"],
        "status": "pending",
        "verdict": None,
        "attempt_count": 0,
        "parent_task_id": None,
        "evidence_path": None,
        "claimed_by": None,
        "payload_json": operation["payload_json"],
    }
    for key, value in expected_work.items():
        if created.get(key) != value:
            raise ContractError(f"committed diagnostic work item {key} mismatch")
    expected_hold = {
        "work_item_id": work_id,
        "hold_code": operation["hold"]["hold_code"],
        "reason": operation["hold"]["reason"],
        "active": 1,
        "release_on_restart": 0,
        "released_at": None,
        "release_note": None,
    }
    for key, value in expected_hold.items():
        if hold.get(key) != value:
            raise ContractError(f"committed diagnostic hold {key} mismatch")
    timestamps = {
        str(created.get("created_at") or ""),
        str(created.get("updated_at") or ""),
        str(hold.get("created_at") or ""),
        str(hold.get("updated_at") or ""),
    }
    if len(timestamps) != 1 or "" in timestamps:
        raise ContractError("committed diagnostic prepare timestamps do not match")
    try:
        parsed_timestamp = dt.datetime.fromisoformat(next(iter(timestamps)))
    except ValueError as exc:
        raise ContractError("committed diagnostic prepare timestamp is invalid") from exc
    if parsed_timestamp.tzinfo is None:
        raise ContractError("committed diagnostic prepare timestamp is not timezone-aware")
    excluded, excluded_errors = _excluded_v2_r2(conn)
    if excluded_errors or excluded != excluded_expected:
        raise ContractError(
            f"pending V2 R2 changed before intent reconciliation: {excluded_errors}"
        )
    assert excluded is not None
    return created, hold, excluded


def apply_prepare(
    *, manifest_path: Path, expected_manifest_sha256: str, confirm_plan_id: str,
    expected_factory_off_sha256: str, expected_db_state_sha256: str,
    expected_source_commit: str, snapshot_path: Path, receipt_path: Path,
) -> dict[str, Any]:
    if not manifest_path.is_file():
        raise ContractError(f"manifest is missing: {manifest_path}")
    actual_manifest_sha = _sha(manifest_path)
    if actual_manifest_sha != expected_manifest_sha256:
        raise ContractError("manifest SHA-256 mismatch")
    try:
        manifest = base._strict_json_object(
            manifest_path.read_bytes(), "standalone diagnostic prepare manifest"
        )
    except base.ContractError as exc:
        raise ContractError(str(exc)) from exc
    _validate_manifest(manifest)
    if manifest["plan_id"] != confirm_plan_id:
        raise ContractError("confirmed plan ID mismatch")
    if manifest["factory_off"]["sha256"] != expected_factory_off_sha256:
        raise ContractError("FACTORY_OFF argument mismatch")
    if manifest["db"]["logical_state_sha256"] != expected_db_state_sha256:
        raise ContractError("DB logical-state argument mismatch")
    if manifest["git"]["authoritative_source_commit"] != expected_source_commit:
        raise ContractError("source-commit argument mismatch")
    expected_operation = _recompute_operation(manifest)
    if manifest["operations"] != [expected_operation]:
        raise ContractError("diagnostic operation contract drifted")
    db = Path(manifest["db"]["path"])
    flag = Path(manifest["factory_off"]["path"])
    lock_path = base.path_for_factory_flag(flag)
    intent_path = receipt_path.with_name(receipt_path.name + ".intent.json")
    snapshot_attestation_path = intent_path.with_name(
        intent_path.name + ".snapshot.json"
    )
    _validate_governed_output_paths(
        paths={
            "snapshot": snapshot_path,
            "receipt": receipt_path,
            "intent": intent_path,
            "snapshot_attestation": snapshot_attestation_path,
        },
        artifact_root=Path(str(manifest["artifact_root"])),
        report_root=Path(str(manifest["report_root"])),
        protected_paths=(manifest_path, db, flag),
    )
    targets = [snapshot_path, receipt_path, intent_path, snapshot_attestation_path]
    if len({_path_identity(path) for path in targets}) != len(targets):
        raise ContractError(
            "snapshot, receipt, intent and snapshot-attestation paths must be distinct"
        )
    existing = [str(path) for path in targets if path.exists()]
    if existing:
        raise ContractError(f"create-only mutation output already exists: {existing}")
    intent = {
        "schema": SCHEMA_INTENT,
        "status": "INTENT_CREATED",
        "action": "prepare",
        "created_at_utc": base.utc_now(),
        "plan_id": manifest["plan_id"],
        "manifest_path": str(manifest_path),
        "manifest_sha256": actual_manifest_sha,
        "snapshot_path": str(snapshot_path),
        "snapshot_attestation_path": str(snapshot_attestation_path),
        "receipt_path": str(receipt_path),
        "db_path": str(db),
        "factory_off_path": str(flag),
        "no_ladder_progression": True,
        "recovery_required_if_final_receipt_missing": True,
        "recovery_policy": RECOVERY_POLICY,
    }
    _write_new_json(intent_path, intent)
    intent_sha = _sha(intent_path)
    with base.FactoryMutationLock(
        lock_path, owner=f"ftmo_book3_standalone_diagnostic_prepare:{manifest['plan_id']}"
    ):
        if _sha(flag) != expected_factory_off_sha256:
            raise ContractError("FACTORY_OFF SHA-256 drifted")
        if base.sqlite_state_sha256(db) != expected_db_state_sha256:
            raise ContractError("DB logical state drifted")
        if base._git(Path(manifest["repo"]), "rev-parse", "HEAD").lower() != expected_source_commit:
            raise ContractError("controller Git HEAD drifted")
        current_operation = _recompute_operation(manifest)
        if current_operation != expected_operation:
            raise ContractError("diagnostic operation changed before apply")
        if base._factory_processes():
            raise ContractError("factory process census is not empty")
        snapshot_sha = base.sqlite_snapshot(db, snapshot_path)
        if base.sqlite_state_sha256(db) != expected_db_state_sha256:
            raise ContractError("DB logical state changed during snapshot")
        snapshot_guard, snapshot_identity = _open_snapshot_guard(
            snapshot_path, expected_sha256=snapshot_sha
        )
        snapshot_attestation = {
            "schema": SCHEMA_SNAPSHOT_ATTESTATION,
            "created_at_utc": base.utc_now(),
            "plan_id": manifest["plan_id"],
            "manifest_path": str(manifest_path),
            "manifest_sha256": actual_manifest_sha,
            "intent_path": str(intent_path),
            "intent_sha256": intent_sha,
            "snapshot_path": str(snapshot_path),
            "snapshot_sha256": snapshot_sha,
            "snapshot_logical_state_sha256": base.sqlite_state_sha256(snapshot_path),
            "source_pre_db_state_sha256": expected_db_state_sha256,
            "factory_off_sha256": expected_factory_off_sha256,
        }
        _write_new_json(snapshot_attestation_path, snapshot_attestation)
        snapshot_attestation_sha = _sha(snapshot_attestation_path)
        _revalidate_snapshot_guard(
            snapshot_guard,
            path=snapshot_path,
            identity=snapshot_identity,
            expected_sha256=snapshot_sha,
            checkpoint="immediately before DB mutation",
        )
        applied_at = base.utc_now()
        conn = sqlite3.connect(db, timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("PRAGMA busy_timeout=30000")
            conn.execute("BEGIN IMMEDIATE")
            preimage = hashlib.sha256(conn.serialize()).hexdigest()
            if preimage != expected_db_state_sha256:
                raise ContractError("transaction DB preimage drifted")
            schema_errors = base._schema_errors(conn)
            if schema_errors:
                raise ContractError("; ".join(schema_errors))
            excluded, excluded_errors = _excluded_v2_r2(conn)
            if excluded_errors or excluded != manifest["excluded_v2_r2"]:
                raise ContractError(f"pending V2 R2 changed inside transaction: {excluded_errors}")
            operation = expected_operation
            work_id = operation["work_item_id"]
            if conn.execute("SELECT 1 FROM work_items WHERE id=?", (work_id,)).fetchone():
                raise ContractError(f"diagnostic work item absence CAS failed: {work_id}")
            if conn.execute(
                "SELECT 1 FROM work_item_holds WHERE work_item_id=?", (work_id,)
            ).fetchone():
                raise ContractError(f"diagnostic hold absence CAS failed: {work_id}")
            if Path(operation["report_root"]).exists():
                raise ContractError(f"report root already exists: {operation['report_root']}")
            cur = conn.execute(
                """INSERT INTO work_items
                (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,parent_task_id,
                 evidence_path,claimed_by,payload_json,created_at,updated_at)
                SELECT ?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?
                WHERE NOT EXISTS (SELECT 1 FROM work_items WHERE id=?)""",
                (
                    work_id,
                    operation["kind"],
                    operation["phase"],
                    operation["ea_id"],
                    operation["symbol"],
                    operation["setfile_path"],
                    operation["payload_json"],
                    applied_at,
                    applied_at,
                    work_id,
                ),
            )
            if cur.rowcount != 1:
                raise ContractError(f"diagnostic work item insert CAS failed: {work_id}")
            hold = operation["hold"]
            cur = conn.execute(
                """INSERT INTO work_item_holds
                (work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note)
                SELECT ?,?,?,1,0,?,?,NULL,NULL
                WHERE NOT EXISTS (SELECT 1 FROM work_item_holds WHERE work_item_id=?)""",
                (
                    work_id,
                    hold["hold_code"],
                    hold["reason"],
                    applied_at,
                    applied_at,
                    work_id,
                ),
            )
            if cur.rowcount != 1:
                raise ContractError(f"diagnostic hold insert CAS failed: {work_id}")
            _revalidate_snapshot_guard(
                snapshot_guard,
                path=snapshot_path,
                identity=snapshot_identity,
                expected_sha256=snapshot_sha,
                checkpoint="inside transaction immediately before commit",
            )
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()
        _revalidate_snapshot_guard(
            snapshot_guard,
            path=snapshot_path,
            identity=snapshot_identity,
            expected_sha256=snapshot_sha,
            checkpoint="immediately after DB commit",
        )
        if _sha(flag) != expected_factory_off_sha256:
            raise ContractError("FACTORY_OFF changed during diagnostic preparation")
        post_state = base.sqlite_state_sha256(db)
        with base.connect_ro(db) as verify:
            created = dict(
                verify.execute(
                    "SELECT id,status,verdict,claimed_by,evidence_path,created_at,updated_at "
                    "FROM work_items WHERE id=?",
                    (expected_operation["work_item_id"],),
                ).fetchone()
            )
            created_hold = dict(
                verify.execute(
                    "SELECT work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note "
                    "FROM work_item_holds WHERE work_item_id=?",
                    (expected_operation["work_item_id"],),
                ).fetchone()
            )
            excluded_after, excluded_errors = _excluded_v2_r2(verify)
        if excluded_errors or excluded_after != manifest["excluded_v2_r2"]:
            raise ContractError("pending V2 R2 changed during diagnostic preparation")
        receipt = {
            "schema": SCHEMA_RECEIPT,
            "action": "prepare",
            "mode": "apply",
            "receipt_id": f"ftmo-book3-standalone-diagnostic-prepare-{manifest['plan_id']}",
            "applied_at_utc": applied_at,
            "plan_id": manifest["plan_id"],
            "manifest_path": str(manifest_path),
            "manifest_sha256": actual_manifest_sha,
            "mutation_intent": {"path": str(intent_path), "sha256": intent_sha},
            "snapshot_attestation": {
                "path": str(snapshot_attestation_path),
                "sha256": snapshot_attestation_sha,
            },
            "factory_off_sha256": expected_factory_off_sha256,
            "pre_db_state_sha256": expected_db_state_sha256,
            "post_db_state_sha256": post_state,
            "snapshot": {"path": str(snapshot_path), "sha256": snapshot_sha},
            "created_work_item": created,
            "created_hold": created_hold,
            "excluded_v2_r2_before_after": {
                "before": manifest["excluded_v2_r2"],
                "after": excluded_after,
                "unchanged": True,
            },
            "execution_input_artifact_count": manifest["execution_input_artifact_count"],
            "execution_input_artifacts_sha256": manifest["execution_input_artifacts_sha256"],
            "factory_remains_off": flag.is_file(),
            "runs_mt5": False,
            "no_ladder_progression": True,
            "no_joint_admission": True,
            "no_release_authority": True,
        }
        _revalidate_snapshot_guard(
            snapshot_guard,
            path=snapshot_path,
            identity=snapshot_identity,
            expected_sha256=snapshot_sha,
            checkpoint="immediately before final receipt publication",
        )
        _write_new_json(receipt_path, receipt)
        snapshot_guard.close()
        return receipt


def reconcile_prepare_intent(
    *,
    manifest_path: Path,
    expected_manifest_sha256: str,
    intent_path: Path,
    expected_intent_sha256: str,
    expected_snapshot_attestation_sha256: str,
    confirm_plan_id: str,
    expected_factory_off_sha256: str,
    expected_post_db_state_sha256: str,
    expected_source_commit: str,
    receipt_path: Path,
) -> dict[str, Any]:
    """Publish a receipt for an already-committed prepare after a crash gap.

    This path is deliberately read-only with respect to the Factory database.
    It authenticates the manifest, pre-mutation intent, snapshot, exact
    committed row/hold, unchanged excluded V2 R2, Factory-OFF state and clean
    source vintage before creating a new reconciliation receipt.
    """

    actual_manifest_sha = _sha(manifest_path) if manifest_path.is_file() else ""
    if actual_manifest_sha != expected_manifest_sha256:
        raise ContractError("manifest SHA-256 mismatch")
    manifest = _read_strict_object(
        manifest_path, "standalone diagnostic prepare manifest"
    )
    _validate_manifest(manifest)
    if manifest["plan_id"] != confirm_plan_id:
        raise ContractError("confirmed plan ID mismatch")
    if manifest["factory_off"]["sha256"] != expected_factory_off_sha256:
        raise ContractError("FACTORY_OFF argument mismatch")
    if manifest["git"]["authoritative_source_commit"] != expected_source_commit:
        raise ContractError("source-commit argument mismatch")
    actual_intent_sha = _sha(intent_path) if intent_path.is_file() else ""
    if actual_intent_sha != expected_intent_sha256:
        raise ContractError("mutation intent SHA-256 mismatch")
    intent = _read_strict_object(intent_path, "standalone diagnostic mutation intent")
    expected_intent_path = receipt_path.with_name(receipt_path.name + ".intent.json")
    if _path_identity(intent_path) != _path_identity(expected_intent_path):
        raise ContractError("intent path is not derived from the final receipt path")
    if receipt_path.exists():
        raise ContractError(f"final receipt already exists: {receipt_path}")
    expected_intent_values = {
        "schema": SCHEMA_INTENT,
        "status": "INTENT_CREATED",
        "action": "prepare",
        "plan_id": manifest["plan_id"],
        "manifest_path": str(manifest_path),
        "manifest_sha256": actual_manifest_sha,
        "snapshot_attestation_path": str(
            intent_path.with_name(intent_path.name + ".snapshot.json")
        ),
        "receipt_path": str(receipt_path),
        "db_path": str(manifest["db"]["path"]),
        "factory_off_path": str(manifest["factory_off"]["path"]),
        "no_ladder_progression": True,
        "recovery_required_if_final_receipt_missing": True,
        "recovery_policy": RECOVERY_POLICY,
    }
    for key, value in expected_intent_values.items():
        if intent.get(key) != value:
            raise ContractError(f"mutation intent {key} mismatch")
    snapshot_path = Path(str(intent.get("snapshot_path") or ""))
    snapshot_attestation_path = Path(
        str(intent.get("snapshot_attestation_path") or "")
    )
    expected_attestation_path = intent_path.with_name(
        intent_path.name + ".snapshot.json"
    )
    if _path_identity(snapshot_attestation_path) != _path_identity(
        expected_attestation_path
    ):
        raise ContractError("snapshot attestation path is not derived from the intent")
    actual_attestation_sha = (
        _sha(snapshot_attestation_path) if snapshot_attestation_path.is_file() else ""
    )
    if actual_attestation_sha != expected_snapshot_attestation_sha256:
        raise ContractError("snapshot attestation SHA-256 mismatch")
    _validate_governed_output_paths(
        paths={
            "snapshot": snapshot_path,
            "receipt": receipt_path,
            "intent": intent_path,
            "snapshot_attestation": snapshot_attestation_path,
        },
        artifact_root=Path(str(manifest["artifact_root"])),
        report_root=Path(str(manifest["report_root"])),
        protected_paths=(
            manifest_path,
            Path(str(manifest["db"]["path"])),
            Path(str(manifest["factory_off"]["path"])),
        ),
    )
    snapshot_attestation = _read_strict_object(
        snapshot_attestation_path, "standalone diagnostic snapshot attestation"
    )
    paths = [
        manifest_path,
        intent_path,
        snapshot_path,
        snapshot_attestation_path,
        receipt_path,
    ]
    if len({_path_identity(path) for path in paths}) != len(paths):
        raise ContractError(
            "manifest, intent, snapshot, snapshot attestation and receipt paths "
            "must be distinct"
        )
    if not snapshot_path.is_file():
        raise ContractError(f"pre-mutation snapshot is missing: {snapshot_path}")
    snapshot_state_sha = base.sqlite_state_sha256(snapshot_path)
    expected_attestation = {
        "schema": SCHEMA_SNAPSHOT_ATTESTATION,
        "plan_id": manifest["plan_id"],
        "manifest_path": str(manifest_path),
        "manifest_sha256": actual_manifest_sha,
        "intent_path": str(intent_path),
        "intent_sha256": actual_intent_sha,
        "snapshot_path": str(snapshot_path),
        "snapshot_sha256": _sha(snapshot_path),
        "snapshot_logical_state_sha256": snapshot_state_sha,
        "source_pre_db_state_sha256": manifest["db"]["logical_state_sha256"],
        "factory_off_sha256": expected_factory_off_sha256,
    }
    for key, value in expected_attestation.items():
        if snapshot_attestation.get(key) != value:
            raise ContractError(f"snapshot attestation {key} mismatch")
    expected_operation = _recompute_operation(manifest)
    if manifest["operations"] != [expected_operation]:
        raise ContractError("diagnostic operation contract drifted")
    db = Path(manifest["db"]["path"])
    flag = Path(manifest["factory_off"]["path"])
    with base.FactoryMutationLock(
        base.path_for_factory_flag(flag),
        owner=f"ftmo_book3_standalone_diagnostic_reconcile:{manifest['plan_id']}",
    ):
        if _sha(manifest_path) != actual_manifest_sha:
            raise ContractError("manifest changed before intent reconciliation")
        if _sha(intent_path) != actual_intent_sha:
            raise ContractError("mutation intent changed before reconciliation")
        if _sha(snapshot_attestation_path) != actual_attestation_sha:
            raise ContractError("snapshot attestation changed before reconciliation")
        if _sha(snapshot_path) != expected_attestation["snapshot_sha256"]:
            raise ContractError("pre-mutation snapshot changed before reconciliation")
        if _sha(flag) != expected_factory_off_sha256:
            raise ContractError("FACTORY_OFF SHA-256 drifted")
        if base._git(Path(manifest["repo"]), "rev-parse", "HEAD").lower() != expected_source_commit:
            raise ContractError("controller Git HEAD drifted")
        if base._factory_processes():
            raise ContractError("factory process census is not empty")
        if _recompute_operation(manifest) != expected_operation:
            raise ContractError("diagnostic operation changed before reconciliation")
        post_state = base.sqlite_state_sha256(db)
        if post_state != expected_post_db_state_sha256:
            raise ContractError("post-prepare DB logical state argument mismatch")
        with base.connect_ro(db) as conn:
            created, created_hold, excluded_after = _committed_prepare_state(
                conn,
                operation=expected_operation,
                excluded_expected=manifest["excluded_v2_r2"],
            )
        if Path(expected_operation["report_root"]).exists():
            raise ContractError("diagnostic report root exists before isolated execution")
        if _sha(flag) != expected_factory_off_sha256:
            raise ContractError("FACTORY_OFF changed during intent reconciliation")
        receipt = {
            "schema": SCHEMA_RECONCILE_RECEIPT,
            "action": "prepare_intent_reconcile",
            "mode": "reconcile_only",
            "reconciled_at_utc": base.utc_now(),
            "plan_id": manifest["plan_id"],
            "manifest_path": str(manifest_path),
            "manifest_sha256": actual_manifest_sha,
            "mutation_intent": {
                "path": str(intent_path),
                "sha256": actual_intent_sha,
            },
            "snapshot_attestation": {
                "path": str(snapshot_attestation_path),
                "sha256": actual_attestation_sha,
            },
            "factory_off_sha256": expected_factory_off_sha256,
            "pre_db_state_sha256": manifest["db"]["logical_state_sha256"],
            "post_db_state_sha256": post_state,
            "snapshot": {
                "path": str(snapshot_path),
                "sha256": _sha(snapshot_path),
                "logical_state_sha256": snapshot_state_sha,
            },
            "created_work_item": created,
            "created_hold": created_hold,
            "excluded_v2_r2": excluded_after,
            "database_mutated_by_reconcile": False,
            "runs_mt5": False,
            "no_ladder_progression": True,
            "no_joint_admission": True,
            "no_release_authority": True,
            "factory_remains_off": flag.is_file(),
        }
        _write_new_json(receipt_path, receipt)
        return receipt


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--report-root", type=Path, default=DEFAULT_REPORT_ROOT)
    parser.add_argument("--common-qm", type=Path, default=DEFAULT_COMMON_QM)
    parser.add_argument("--t10-bases", type=Path, default=DEFAULT_T10_BASES)
    parser.add_argument("--calendar-source", type=Path, default=DEFAULT_CALENDAR_SOURCE)
    parser.add_argument("--calendar-common", type=Path, default=DEFAULT_CALENDAR_COMMON)
    parser.add_argument(
        "--out",
        type=Path,
        help="create-only dry-run plan target (absolute path; never overwritten)",
    )
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--reconcile-intent", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--expected-manifest-sha256")
    parser.add_argument("--confirm-plan-id")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--expected-db-state-sha256")
    parser.add_argument("--expected-post-db-state-sha256")
    parser.add_argument("--expected-intent-sha256")
    parser.add_argument("--expected-snapshot-attestation-sha256")
    parser.add_argument("--snapshot-path", type=Path)
    parser.add_argument("--receipt-path", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.apply and args.reconcile_intent is not None:
            raise ContractError("--apply and --reconcile-intent are mutually exclusive")
        if args.reconcile_intent is not None:
            if args.out is not None:
                raise ContractError("--out is valid only for dry-run plan creation")
            required = {
                "manifest": args.manifest,
                "expected_manifest_sha256": args.expected_manifest_sha256,
                "confirm_plan_id": args.confirm_plan_id,
                "expected_factory_off_sha256": args.expected_factory_off_sha256,
                "expected_post_db_state_sha256": args.expected_post_db_state_sha256,
                "expected_intent_sha256": args.expected_intent_sha256,
                "expected_snapshot_attestation_sha256": (
                    args.expected_snapshot_attestation_sha256
                ),
                "receipt_path": args.receipt_path,
            }
            missing = [key for key, value in required.items() if value in (None, "")]
            if missing:
                raise ContractError(f"reconcile arguments are missing: {missing}")
            receipt = reconcile_prepare_intent(
                manifest_path=args.manifest,
                expected_manifest_sha256=args.expected_manifest_sha256,
                intent_path=args.reconcile_intent,
                expected_intent_sha256=args.expected_intent_sha256,
                expected_snapshot_attestation_sha256=(
                    args.expected_snapshot_attestation_sha256
                ),
                confirm_plan_id=args.confirm_plan_id,
                expected_factory_off_sha256=args.expected_factory_off_sha256,
                expected_post_db_state_sha256=args.expected_post_db_state_sha256,
                expected_source_commit=args.source_commit,
                receipt_path=args.receipt_path,
            )
            print(json.dumps(receipt, indent=2, sort_keys=True))
            return 0
        if args.apply:
            if args.out is not None:
                raise ContractError("--out is valid only for dry-run plan creation")
            required = {
                "manifest": args.manifest,
                "expected_manifest_sha256": args.expected_manifest_sha256,
                "confirm_plan_id": args.confirm_plan_id,
                "expected_factory_off_sha256": args.expected_factory_off_sha256,
                "expected_db_state_sha256": args.expected_db_state_sha256,
                "snapshot_path": args.snapshot_path,
                "receipt_path": args.receipt_path,
            }
            missing = [key for key, value in required.items() if value in (None, "")]
            if missing:
                raise ContractError(f"apply arguments are missing: {missing}")
            receipt = apply_prepare(
                manifest_path=args.manifest,
                expected_manifest_sha256=args.expected_manifest_sha256,
                confirm_plan_id=args.confirm_plan_id,
                expected_factory_off_sha256=args.expected_factory_off_sha256,
                expected_db_state_sha256=args.expected_db_state_sha256,
                expected_source_commit=args.source_commit,
                snapshot_path=args.snapshot_path,
                receipt_path=args.receipt_path,
            )
            print(json.dumps(receipt, indent=2, sort_keys=True))
            return 0
        plan = build_prepare_plan(
            source_commit=args.source_commit,
            root=args.root,
            repo=args.repo,
            artifact_root=args.artifact_root,
            report_root=args.report_root,
            common_qm=args.common_qm,
            t10_bases=args.t10_bases,
            calendar_source=args.calendar_source,
            calendar_common=args.calendar_common,
        )
        if args.out is not None:
            if not args.out.is_absolute():
                raise ContractError("--out must be an absolute path")
            _write_new_json(args.out, plan)
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0 if plan["valid"] else 2
    except Exception as exc:
        print(json.dumps({"valid": False, "error": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
