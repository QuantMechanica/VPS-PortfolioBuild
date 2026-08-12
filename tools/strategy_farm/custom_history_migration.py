#!/usr/bin/env python3
"""OWNER-gated Variant-A staging, cutover, activation, and rollback tooling.

Mutation commands are dry-run by default.  ``--execute`` is accepted only with
an OWNER-approved full archive manifest and the exact detached OWNER approval
receipt that binds its hash, window, T1-T10 set, and rollback authorization.
No command starts MT5, changes AutoTrading, or removes a retained tree.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

try:
    import custom_history_gate
    import custom_history_lease
    import mt5_history_isolation
    from custom_history_contract import (
        DEFAULT_ARCHIVE_YEARS,
        DEFAULT_CURRENT_YEAR,
        DEFAULT_RUNNER_TERMINALS,
        CustomHistoryContractError,
        archive_acl_write_denied,
        attach_owner_approval,
        build_archive_manifest,
        canonical_bytes,
        classify_relative_path,
        file_identity,
        load_json_strict,
        load_manifest,
        normalize_relative_path,
        require_owner_window_open,
        sha256_file,
        utc_now,
        validate_manifest,
        validate_owner_approval,
        write_json_atomic,
    )
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm import (
        custom_history_gate,
        custom_history_lease,
        mt5_history_isolation,
    )
    from tools.strategy_farm.custom_history_contract import (
        DEFAULT_ARCHIVE_YEARS,
        DEFAULT_CURRENT_YEAR,
        DEFAULT_RUNNER_TERMINALS,
        CustomHistoryContractError,
        archive_acl_write_denied,
        attach_owner_approval,
        build_archive_manifest,
        canonical_bytes,
        classify_relative_path,
        file_identity,
        load_json_strict,
        load_manifest,
        normalize_relative_path,
        require_owner_window_open,
        sha256_file,
        utc_now,
        validate_manifest,
        validate_owner_approval,
        write_json_atomic,
    )


MIGRATION_SCHEMA = "qm.custom-history-variant-a-migration/v1"
STAGE_RECEIPT_SCHEMA = "qm.custom-history-stage-receipt/v1"
CUTOVER_RECEIPT_SCHEMA = "qm.custom-history-cutover-receipt/v1"
ROLLBACK_RECEIPT_SCHEMA = "qm.custom-history-rollback-receipt/v1"
DEFAULT_MT5_ROOT = Path(r"D:\QM\mt5")
DEFAULT_FARM_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_PROTECTED_ROOTS = mt5_history_isolation.DEFAULT_PROTECTED_ROOTS
ACL_SCRIPT = Path(__file__).with_name("custom_history_acl.ps1")
_WINDOW_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$")


class CustomHistoryMigrationError(RuntimeError):
    pass


def _payload_hash(payload: Mapping[str, Any], field: str) -> str:
    return hashlib.sha256(
        canonical_bytes({key: value for key, value in payload.items() if key != field})
    ).hexdigest()


def _safe_window_id(value: str) -> str:
    candidate = str(value).strip()
    if _WINDOW_RE.fullmatch(candidate) is None:
        raise CustomHistoryMigrationError("window_id contains unsafe characters")
    return candidate


def load_owner_window_receipt(
    path: Path,
    *,
    manifest: Mapping[str, Any],
) -> dict[str, Any]:
    approval = load_json_strict(Path(path))
    validated = validate_owner_approval(
        approval,
        expected_manifest_sha256=str(manifest["manifest_sha256"]),
        expected_terminals=manifest["runner_terminals"],
    )
    embedded = manifest.get("owner_approval")
    if not isinstance(embedded, dict) or canonical_bytes(embedded) != canonical_bytes(validated):
        raise CustomHistoryMigrationError(
            "detached OWNER window receipt does not exactly match manifest approval"
        )
    return validated


def custom_path(mt5_root: Path, terminal: str) -> Path:
    return Path(mt5_root) / str(terminal).upper() / "Bases" / "Custom"


def staging_path(mt5_root: Path, terminal: str, window_id: str) -> Path:
    live = custom_path(mt5_root, terminal)
    return live.with_name(f"Custom.__variant_a_stage__.{_safe_window_id(window_id)}")


def rollback_path(mt5_root: Path, terminal: str, window_id: str) -> Path:
    live = custom_path(mt5_root, terminal)
    return live.with_name(f"Custom.__variant_a_rollback__.{_safe_window_id(window_id)}")


def failed_path(mt5_root: Path, terminal: str, window_id: str) -> Path:
    live = custom_path(mt5_root, terminal)
    return live.with_name(f"Custom.__variant_a_failed__.{_safe_window_id(window_id)}")


def _source_files(source: Path) -> list[tuple[str, Path]]:
    return sorted(
        [
            (normalize_relative_path(path.relative_to(source).as_posix()), path)
            for path in source.rglob("*")
            if path.is_file()
        ],
        key=lambda item: item[0].casefold(),
    )


def build_stage_plan(
    *,
    manifest: Mapping[str, Any],
    mt5_root: Path,
    window_id: str,
) -> dict[str, Any]:
    validated = validate_manifest(
        manifest,
        require_owner_approval=False,
        allow_metadata_only=True,
    )
    source = Path(validated["source_custom"])
    files = _source_files(source)
    archive = {str(row["relative_path"]).casefold() for row in validated["files"]}
    archive_count = sum(relative.casefold() in archive for relative, _ in files)
    private_count = len(files) - archive_count
    targets = []
    for terminal in validated["runner_terminals"]:
        live = custom_path(mt5_root, terminal)
        targets.append(
            {
                "terminal": terminal,
                "live": str(live),
                "staging": str(staging_path(mt5_root, terminal, window_id)),
                "rollback": str(rollback_path(mt5_root, terminal, window_id)),
                "live_resolved": str(live.resolve(strict=False)),
                "live_is_reparse": mt5_history_isolation._is_reparse_point(live),
            }
        )
    payload: dict[str, Any] = {
        "schema_version": MIGRATION_SCHEMA,
        "mode": "DRY_RUN_PLAN",
        "runtime_action": "NONE",
        "manifest_sha256": validated["manifest_sha256"],
        "window_id": _safe_window_id(window_id),
        "source_custom": str(source),
        "source_file_count": len(files),
        "archive_hardlink_files_per_terminal": archive_count,
        "private_copy_files_per_terminal": private_count,
        "runner_terminals": list(validated["runner_terminals"]),
        "targets": targets,
    }
    payload["plan_sha256"] = _payload_hash(payload, "plan_sha256")
    return payload


def _require_authorized_execution(
    *,
    manifest_path: Path,
    owner_receipt_path: Path,
    require_window_open: bool = False,
) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest = load_manifest(manifest_path, require_owner_approval=True)
    owner = load_owner_window_receipt(owner_receipt_path, manifest=manifest)
    if require_window_open:
        require_owner_window_open(owner)
    return manifest, owner


def _ensure_target_file(
    *,
    source: Path,
    target: Path,
    archive: bool,
    expected_archive_identity: str | None,
) -> str:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        identity = file_identity(target)
        if archive and identity["file_id"] != expected_archive_identity:
            raise CustomHistoryMigrationError(f"existing archive target has wrong file ID: {target}")
        if not archive and (identity["size"] != source.stat().st_size or sha256_file(target) != sha256_file(source)):
            raise CustomHistoryMigrationError(f"existing private target differs from source: {target}")
        return "VERIFIED_EXISTING"
    if archive:
        os.link(source, target)
        if file_identity(target)["file_id"] != expected_archive_identity:
            raise CustomHistoryMigrationError(f"hardlink identity verification failed: {target}")
        return "HARDLINK_CREATED"
    shutil.copy2(source, target)
    if target.stat().st_size != source.stat().st_size:
        raise CustomHistoryMigrationError(f"private copy size verification failed: {target}")
    return "PRIVATE_COPY_CREATED"


def _run_acl_script(
    *,
    mode: str,
    manifest_path: Path,
    owner_receipt_path: Path,
    source_custom: Path,
    evidence_path: Path,
    execute: bool,
    farm_root: Path,
) -> dict[str, Any]:
    command = [
        "powershell.exe",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ACL_SCRIPT),
        "-Mode",
        mode,
        "-ManifestPath",
        str(manifest_path),
        "-OwnerReceiptPath",
        str(owner_receipt_path),
        "-SourceCustom",
        str(source_custom),
        "-EvidencePath",
        str(evidence_path),
        "-FarmRoot",
        str(farm_root),
    ]
    if execute:
        command.append("-Execute")
    process = subprocess.run(
        command,
        capture_output=True,
        text=True,
        timeout=7200,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if process.returncode != 0:
        raise CustomHistoryMigrationError(
            f"ACL {mode} failed ({process.returncode}): {(process.stderr or process.stdout)[-4000:]}"
        )
    try:
        return json.loads(process.stdout)
    except json.JSONDecodeError as exc:
        raise CustomHistoryMigrationError("ACL script returned invalid JSON") from exc


def stage_variant_a(
    *,
    manifest_path: Path,
    owner_receipt_path: Path,
    mt5_root: Path,
    farm_root: Path,
    receipt_path: Path,
    acl_evidence_path: Path,
    execute: bool,
    acl_runner: Callable[..., Mapping[str, Any]] | None = None,
    quiescence_probe: Callable[..., Mapping[str, Any]] | None = None,
) -> dict[str, Any]:
    manifest, owner = _require_authorized_execution(
        manifest_path=manifest_path,
        owner_receipt_path=owner_receipt_path,
        require_window_open=execute,
    )
    plan = build_stage_plan(
        manifest=manifest,
        mt5_root=mt5_root,
        window_id=owner["window_id"],
    )
    if not execute:
        return plan
    factory_off = _require_factory_off(farm_root)
    mode = _require_containment_engaged(farm_root)
    probe = quiescence_probe or quiescence_snapshot
    quiescence = dict(
        probe(
            farm_root=farm_root,
            mt5_root=mt5_root,
            terminals=manifest["runner_terminals"],
        )
    )
    if not quiescence.get("quiescent"):
        raise CustomHistoryMigrationError(
            f"staging requires factory quiescence: {quiescence}"
        )
    source = Path(manifest["source_custom"])
    archive_rows = {
        str(row["relative_path"]).casefold(): row for row in manifest["files"]
    }
    actions: dict[str, int] = {}
    for terminal in manifest["runner_terminals"]:
        _require_factory_off(farm_root)
        staging = staging_path(mt5_root, terminal, owner["window_id"])
        staging.mkdir(parents=True, exist_ok=True)
        if mt5_history_isolation._is_reparse_point(staging):
            raise CustomHistoryMigrationError(f"staging root is a reparse point: {staging}")
        for relative, source_path in _source_files(source):
            archive_row = archive_rows.get(relative.casefold())
            action = _ensure_target_file(
                source=source_path,
                target=staging.joinpath(*relative.split("/")),
                archive=archive_row is not None,
                expected_archive_identity=(
                    str(archive_row["file_id"]) if archive_row is not None else None
                ),
            )
            actions[action] = actions.get(action, 0) + 1
    acl_call = acl_runner or _run_acl_script
    acl = dict(
        acl_call(
            mode="Apply",
            manifest_path=manifest_path,
            owner_receipt_path=owner_receipt_path,
            source_custom=source,
            evidence_path=acl_evidence_path,
            execute=True,
            farm_root=farm_root,
        )
    )
    if acl.get("status") != "PASS":
        raise CustomHistoryMigrationError("archive ACL application did not PASS")
    receipt: dict[str, Any] = {
        "schema_version": STAGE_RECEIPT_SCHEMA,
        "created_at_utc": utc_now(),
        "manifest_sha256": manifest["manifest_sha256"],
        "window_id": owner["window_id"],
        "mt5_root": str(Path(mt5_root).absolute()),
        "runner_terminals": list(manifest["runner_terminals"]),
        "actions": actions,
        "acl_evidence_path": str(Path(acl_evidence_path).absolute()),
        "acl_evidence_sha256": sha256_file(acl_evidence_path),
        "plan_sha256": plan["plan_sha256"],
        "containment_mode_sha256": mode["mode_sha256"],
        "factory_off": factory_off,
        "quiescence": quiescence,
    }
    receipt["receipt_sha256"] = _payload_hash(receipt, "receipt_sha256")
    write_json_atomic(receipt_path, receipt)
    return receipt


def verify_staging(
    *,
    manifest: Mapping[str, Any],
    mt5_root: Path,
    window_id: str,
    verify_acl: bool = True,
    acl_probe: Callable[[Path, str], Mapping[str, Any]] = archive_acl_write_denied,
    accept_cutover_live: bool = False,
) -> dict[str, Any]:
    validated = validate_manifest(manifest, require_owner_approval=True)
    source = Path(validated["source_custom"])
    if accept_cutover_live:
        source_rollback = rollback_path(
            mt5_root,
            validated["runner_terminals"][0],
            window_id,
        )
        if source_rollback.exists():
            source = source_rollback
    source_files = dict(_source_files(source))
    archive_rows = {
        str(row["relative_path"]).casefold(): row for row in validated["files"]
    }
    findings: list[dict[str, Any]] = []
    mutable_ids: dict[str, list[str]] = {}
    archive_hash_cache: dict[str, str] = {}
    acl_cache: dict[str, Mapping[str, Any]] = {}
    summaries = []
    for terminal in validated["runner_terminals"]:
        staging = staging_path(mt5_root, terminal, window_id)
        candidate = staging
        location = "STAGING"
        live = custom_path(mt5_root, terminal)
        rollback = rollback_path(mt5_root, terminal, window_id)
        if (
            accept_cutover_live
            and not staging.exists()
            and rollback.exists()
            and live.exists()
        ):
            candidate = live
            location = "CUTOVER_LIVE"
        if not candidate.is_dir() or mt5_history_isolation._is_reparse_point(candidate):
            findings.append({"code": "STAGING_ROOT_NOT_PHYSICAL", "terminal": terminal, "path": str(candidate), "location": location})
            continue
        target_files = dict(_source_files(candidate))
        missing = sorted(set(source_files) - set(target_files))
        extra = sorted(set(target_files) - set(source_files))
        for relative in missing:
            findings.append({"code": "STAGING_FILE_MISSING", "terminal": terminal, "relative_path": relative})
        for relative in extra:
            findings.append({"code": "STAGING_FILE_EXTRA", "terminal": terminal, "relative_path": relative})
        for relative in sorted(set(source_files) & set(target_files)):
            source_path = source_files[relative]
            target = target_files[relative]
            target_identity = file_identity(target)
            archive_row = archive_rows.get(relative.casefold())
            if archive_row is not None:
                if target_identity["file_id"] != archive_row["file_id"]:
                    findings.append({"code": "STAGING_ARCHIVE_FILE_ID_MISMATCH", "terminal": terminal, "relative_path": relative})
                cache_key = target_identity["file_id"]
                if cache_key not in archive_hash_cache:
                    archive_hash_cache[cache_key] = sha256_file(target)
                if archive_hash_cache[cache_key] != archive_row["sha256"]:
                    findings.append({"code": "STAGING_ARCHIVE_HASH_MISMATCH", "terminal": terminal, "relative_path": relative})
                if verify_acl:
                    if cache_key not in acl_cache:
                        acl_cache[cache_key] = acl_probe(target, validated["runner_identity"])
                    if not acl_cache[cache_key].get("write_denied"):
                        findings.append({"code": "STAGING_ARCHIVE_ACL_WRITABLE", "terminal": terminal, "relative_path": relative})
            else:
                mutable_ids.setdefault(target_identity["file_id"], []).append(terminal)
                if target_identity["file_id"] == file_identity(source_path)["file_id"]:
                    findings.append({"code": "STAGING_MUTABLE_FILE_HARDLINKED", "terminal": terminal, "relative_path": relative})
                elif target_identity["size"] != source_path.stat().st_size or sha256_file(target) != sha256_file(source_path):
                    findings.append({"code": "STAGING_MUTABLE_COPY_MISMATCH", "terminal": terminal, "relative_path": relative})
        summaries.append({"terminal": terminal, "files": len(target_files), "path": str(candidate), "location": location})
    for file_id, terminals in mutable_ids.items():
        unique = sorted(set(terminals))
        if len(unique) > 1:
            findings.append({"code": "STAGING_MUTABLE_FILE_ID_SHARED", "file_id": file_id, "terminals": unique})
    findings.sort(key=lambda row: (row["code"], str(row.get("terminal", "")), str(row.get("relative_path", ""))))
    payload: dict[str, Any] = {
        "schema_version": "qm.custom-history-stage-verification/v1",
        "status": "PASS_ISOLATED" if not findings else "FAIL_CLOSED",
        "manifest_sha256": validated["manifest_sha256"],
        "window_id": _safe_window_id(window_id),
        "summaries": summaries,
        "findings": findings,
    }
    payload["verification_sha256"] = _payload_hash(payload, "verification_sha256")
    return payload


def quiescence_snapshot(
    *,
    farm_root: Path,
    mt5_root: Path,
    terminals: Sequence[str] = DEFAULT_RUNNER_TERMINALS,
) -> dict[str, Any]:
    active_rows: list[dict[str, Any]] = []
    db_path = Path(farm_root) / "state" / "farm_state.sqlite"
    if not db_path.is_file():
        return {"quiescent": False, "reason": "farm_db_missing", "db_path": str(db_path)}
    try:
        with sqlite3.connect(f"file:{db_path.as_posix()}?mode=ro", uri=True, timeout=30) as conn:
            conn.row_factory = sqlite3.Row
            active_rows = [dict(row) for row in conn.execute(
                "SELECT id,phase,ea_id,symbol,claimed_by FROM work_items WHERE status='active' ORDER BY id"
            )]
    except sqlite3.Error as exc:
        return {"quiescent": False, "reason": "farm_db_unreadable", "error": repr(exc)}
    process_rows: list[dict[str, Any]] = []
    if sys.platform == "win32":
        roots = [str(Path(mt5_root) / terminal).casefold() for terminal in terminals]
        script = "Get-CimInstance Win32_Process | Where-Object {$_.Name -in @('terminal64.exe','metatester64.exe')} | Select-Object ProcessId,Name,ExecutablePath | ConvertTo-Json -Compress"
        try:
            process = subprocess.run(
                ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
                capture_output=True,
                text=True,
                timeout=30,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            if process.returncode != 0:
                return {
                    "quiescent": False,
                    "reason": "process_probe_failed",
                    "returncode": process.returncode,
                    "stderr": (process.stderr or "")[-2000:],
                    "active_rows": active_rows,
                }
            raw = json.loads(process.stdout or "[]")
            candidates = raw if isinstance(raw, list) else ([raw] if raw else [])
            for row in candidates:
                executable = str(row.get("ExecutablePath") or "").casefold()
                if any(executable == root or executable.startswith(root + "\\") for root in roots) or str(row.get("Name", "")).casefold() == "metatester64.exe":
                    process_rows.append(row)
        except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
            return {"quiescent": False, "reason": "process_probe_failed", "error": repr(exc), "active_rows": active_rows}
    return {
        "quiescent": not active_rows and not process_rows,
        "active_work_items": active_rows,
        "runner_processes": process_rows,
        "db_path": str(db_path),
    }


def backup_farm_db(farm_root: Path, target: Path) -> dict[str, Any]:
    source = Path(farm_root) / "state" / "farm_state.sqlite"
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        try:
            with sqlite3.connect(
                f"file:{target.as_posix()}?mode=ro", uri=True, timeout=30
            ) as existing:
                integrity = existing.execute("PRAGMA integrity_check").fetchone()
        except sqlite3.Error as exc:
            raise CustomHistoryMigrationError(
                f"existing database backup is unreadable: {target}: {exc}"
            ) from exc
        if not integrity or str(integrity[0]).casefold() != "ok":
            raise CustomHistoryMigrationError(
                f"existing database backup failed integrity_check: {target}"
            )
        reused = True
    else:
        with sqlite3.connect(source) as src, sqlite3.connect(target) as dst:
            src.backup(dst)
        reused = False
    return {
        "path": str(target),
        "sha256": sha256_file(target),
        "size": target.stat().st_size,
        "reused_existing": reused,
    }


def _require_containment_engaged(farm_root: Path) -> dict[str, Any]:
    mode = custom_history_lease.load_mode(farm_root)
    if not mode.get("enabled"):
        raise CustomHistoryMigrationError("global Custom-history containment lease is not engaged")
    return mode


def _require_factory_off(farm_root: Path) -> dict[str, Any]:
    flag = Path(farm_root) / "state" / "FACTORY_OFF.flag"
    if not flag.is_file():
        raise CustomHistoryMigrationError("FACTORY_OFF.flag is required for topology mutation")
    return {"path": str(flag), "sha256": sha256_file(flag)}


def cutover_variant_a(
    *,
    manifest_path: Path,
    owner_receipt_path: Path,
    mt5_root: Path,
    farm_root: Path,
    db_backup_path: Path,
    receipt_path: Path,
    execute: bool,
    quiescence_probe: Callable[..., Mapping[str, Any]] = quiescence_snapshot,
) -> dict[str, Any]:
    manifest, owner = _require_authorized_execution(
        manifest_path=manifest_path,
        owner_receipt_path=owner_receipt_path,
        require_window_open=execute,
    )
    plan = build_stage_plan(manifest=manifest, mt5_root=mt5_root, window_id=owner["window_id"])
    if not execute:
        return {**plan, "next_action": "execute_requires_quiescence_containment_stage_pass_and_db_backup"}
    factory_off = _require_factory_off(farm_root)
    quiescence = dict(quiescence_probe(farm_root=farm_root, mt5_root=mt5_root, terminals=manifest["runner_terminals"]))
    if not quiescence.get("quiescent"):
        raise CustomHistoryMigrationError(f"cutover requires quiescence: {quiescence}")
    mode = _require_containment_engaged(farm_root)
    stage_verification = verify_staging(
        manifest=manifest,
        mt5_root=mt5_root,
        window_id=owner["window_id"],
        accept_cutover_live=True,
    )
    if stage_verification["status"] != "PASS_ISOLATED":
        raise CustomHistoryMigrationError("staging verification failed")
    receipt_target = Path(receipt_path)
    if receipt_target.exists():
        receipt = load_json_strict(receipt_target)
        if (
            receipt.get("schema_version") != CUTOVER_RECEIPT_SCHEMA
            or receipt.get("manifest_sha256") != manifest["manifest_sha256"]
            or receipt.get("window_id") != owner["window_id"]
            or receipt.get("receipt_sha256")
            != _payload_hash(receipt, "receipt_sha256")
        ):
            raise CustomHistoryMigrationError("existing cutover journal binding/hash mismatch")
        db_backup = dict(receipt.get("db_backup") or {})
        if (
            Path(str(db_backup.get("path") or "")).resolve(strict=False)
            != Path(db_backup_path).resolve(strict=False)
            or not Path(db_backup_path).is_file()
            or sha256_file(db_backup_path) != db_backup.get("sha256")
        ):
            raise CustomHistoryMigrationError("existing cutover journal backup mismatch")
        operations = list(receipt.get("operations") or [])
        if receipt.get("status") == "COMPLETE":
            return receipt
        if receipt.get("status") != "IN_PROGRESS":
            raise CustomHistoryMigrationError("existing cutover journal status is invalid")
    else:
        db_backup = backup_farm_db(farm_root, db_backup_path)
        receipt = {
            "schema_version": CUTOVER_RECEIPT_SCHEMA,
            "status": "IN_PROGRESS",
            "started_at_utc": utc_now(),
            "completed_at_utc": None,
            "manifest_sha256": manifest["manifest_sha256"],
            "window_id": owner["window_id"],
            "containment_mode_sha256": mode["mode_sha256"],
            "factory_off": factory_off,
            "quiescence": quiescence,
            "stage_verification_sha256": stage_verification["verification_sha256"],
            "db_backup": db_backup,
            "operations": [],
            "rollback_retained": True,
        }
        receipt["receipt_sha256"] = _payload_hash(receipt, "receipt_sha256")
        write_json_atomic(receipt_target, receipt)
        operations = []

    def persist_cutover(status: str) -> None:
        receipt["status"] = status
        receipt["operations"] = list(operations)
        receipt["completed_at_utc"] = utc_now() if status == "COMPLETE" else None
        receipt["receipt_sha256"] = _payload_hash(receipt, "receipt_sha256")
        write_json_atomic(receipt_target, receipt)

    for terminal in manifest["runner_terminals"]:
        _require_factory_off(farm_root)
        live = custom_path(mt5_root, terminal)
        stage = staging_path(mt5_root, terminal, owner["window_id"])
        rollback = rollback_path(mt5_root, terminal, owner["window_id"])
        if rollback.exists() and live.exists() and not stage.exists():
            operations.append({"terminal": terminal, "status": "ALREADY_CUT_OVER"})
            if mt5_history_isolation._is_reparse_point(live):
                raise CustomHistoryMigrationError(
                    f"already-cut-over live root is a reparse point: {live}"
                )
            persist_cutover("IN_PROGRESS")
            continue
        if not rollback.exists():
            if not live.exists() or not stage.exists():
                raise CustomHistoryMigrationError(f"cutover precondition missing for {terminal}")
            live.rename(rollback)
            operations.append({"terminal": terminal, "operation": "LIVE_TO_ROLLBACK", "path": str(rollback)})
            persist_cutover("IN_PROGRESS")
        if not live.exists():
            if not stage.exists():
                raise CustomHistoryMigrationError(f"staging path disappeared for {terminal}")
            stage.rename(live)
            operations.append({"terminal": terminal, "operation": "STAGE_TO_LIVE", "path": str(live)})
            persist_cutover("IN_PROGRESS")
        if mt5_history_isolation._is_reparse_point(live):
            raise CustomHistoryMigrationError(f"cutover live root is still a reparse point: {live}")
    persist_cutover("COMPLETE")
    return receipt


def rollback_variant_a(
    *,
    manifest_path: Path,
    owner_receipt_path: Path,
    mt5_root: Path,
    farm_root: Path,
    receipt_path: Path,
    execute: bool,
    quiescence_probe: Callable[..., Mapping[str, Any]] = quiescence_snapshot,
) -> dict[str, Any]:
    manifest, owner = _require_authorized_execution(
        manifest_path=manifest_path,
        owner_receipt_path=owner_receipt_path,
        require_window_open=execute,
    )
    plan = {"mode": "DRY_RUN_ROLLBACK", "runtime_action": "NONE", "window_id": owner["window_id"], "terminals": list(manifest["runner_terminals"])}
    if not execute:
        return plan
    factory_off = _require_factory_off(farm_root)
    _require_containment_engaged(farm_root)
    quiescence = dict(quiescence_probe(farm_root=farm_root, mt5_root=mt5_root, terminals=manifest["runner_terminals"]))
    if not quiescence.get("quiescent"):
        raise CustomHistoryMigrationError(f"rollback requires quiescence: {quiescence}")
    receipt_target = Path(receipt_path)
    if receipt_target.exists():
        receipt = load_json_strict(receipt_target)
        if (
            receipt.get("schema_version") != ROLLBACK_RECEIPT_SCHEMA
            or receipt.get("manifest_sha256") != manifest["manifest_sha256"]
            or receipt.get("window_id") != owner["window_id"]
            or receipt.get("receipt_sha256")
            != _payload_hash(receipt, "receipt_sha256")
        ):
            raise CustomHistoryMigrationError("existing rollback journal binding/hash mismatch")
        operations = list(receipt.get("operations") or [])
        if receipt.get("status") not in {"IN_PROGRESS", "COMPLETE"}:
            raise CustomHistoryMigrationError("existing rollback journal status is invalid")
    else:
        receipt = {
            "schema_version": ROLLBACK_RECEIPT_SCHEMA,
            "status": "IN_PROGRESS",
            "started_at_utc": utc_now(),
            "completed_at_utc": None,
            "manifest_sha256": manifest["manifest_sha256"],
            "window_id": owner["window_id"],
            "quiescence": quiescence,
            "factory_off": factory_off,
            "operations": [],
            "failure_analysis_retained": True,
            "containment_remains_engaged": True,
        }
        receipt["receipt_sha256"] = _payload_hash(receipt, "receipt_sha256")
        write_json_atomic(receipt_target, receipt)
        operations = []

    def persist_rollback(status: str) -> None:
        receipt["status"] = status
        receipt["operations"] = list(operations)
        receipt["completed_at_utc"] = utc_now() if status == "COMPLETE" else None
        receipt["receipt_sha256"] = _payload_hash(receipt, "receipt_sha256")
        write_json_atomic(receipt_target, receipt)

    for terminal in manifest["runner_terminals"]:
        _require_factory_off(farm_root)
        live = custom_path(mt5_root, terminal)
        rollback = rollback_path(mt5_root, terminal, owner["window_id"])
        failed = failed_path(mt5_root, terminal, owner["window_id"])
        if not rollback.exists():
            if not live.exists():
                raise CustomHistoryMigrationError(
                    f"rollback source and live root are both absent for {terminal}"
                )
            operations.append({"terminal": terminal, "status": "ROLLBACK_SOURCE_ABSENT_NO_ACTION"})
            persist_rollback("IN_PROGRESS")
            continue
        if failed.exists() and live.exists():
            raise CustomHistoryMigrationError(
                f"rollback has simultaneous live and failure-analysis roots: {terminal}"
            )
        if live.exists():
            live.rename(failed)
            operations.append({"terminal": terminal, "operation": "LIVE_TO_FAILURE_ANALYSIS", "path": str(failed)})
            persist_rollback("IN_PROGRESS")
        rollback.rename(live)
        operations.append({"terminal": terminal, "operation": "ROLLBACK_TO_LIVE", "path": str(live)})
        persist_rollback("IN_PROGRESS")
    persist_rollback("COMPLETE")
    activation = custom_history_gate.load_activation(farm_root)
    rollback_gate_mode = None
    if activation is not None:
        rollback_gate_mode = custom_history_gate.build_rollback_mode(
            activation=activation,
            rollback_receipt_path=receipt_path,
            owner_receipt_path=owner_receipt_path,
        )
        custom_history_gate.write_rollback_mode(
            farm_root,
            rollback_gate_mode,
            activation=activation,
        )
    return {**receipt, "rollback_gate_mode": rollback_gate_mode}


def _print(payload: Mapping[str, Any]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    build = sub.add_parser("build-manifest")
    build.add_argument("--source-custom", type=Path, required=True)
    build.add_argument("--runner-identity", required=True)
    build.add_argument("--current-year", type=int, default=DEFAULT_CURRENT_YEAR)
    build.add_argument("--archive-year", type=int, action="append")
    build.add_argument("--metadata-only", action="store_true")
    build.add_argument("--output", type=Path)
    build.add_argument("--dry-run", action="store_true")

    attach = sub.add_parser("attach-owner-approval")
    attach.add_argument("--manifest", type=Path, required=True)
    attach.add_argument("--owner-receipt", type=Path, required=True)
    attach.add_argument("--output", type=Path, required=True)

    validate_authorization = sub.add_parser("validate-authorization")
    validate_authorization.add_argument("--manifest", type=Path, required=True)
    validate_authorization.add_argument("--owner-receipt", type=Path, required=True)
    validate_authorization.add_argument("--farm-root", type=Path)
    validate_authorization.add_argument("--require-mutation-guard", action="store_true")

    plan = sub.add_parser("plan")
    plan.add_argument("--manifest", type=Path, required=True)
    plan.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    plan.add_argument("--window-id", required=True)

    stage = sub.add_parser("stage")
    stage.add_argument("--manifest", type=Path, required=True)
    stage.add_argument("--owner-receipt", type=Path, required=True)
    stage.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    stage.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    stage.add_argument("--receipt", type=Path, required=True)
    stage.add_argument("--acl-evidence", type=Path, required=True)
    stage.add_argument("--execute", action="store_true")

    verify = sub.add_parser("verify-stage")
    verify.add_argument("--manifest", type=Path, required=True)
    verify.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    verify.add_argument("--window-id", required=True)

    engage = sub.add_parser("engage-containment")
    engage.add_argument("--manifest", type=Path, required=True)
    engage.add_argument("--owner-receipt", type=Path, required=True)
    engage.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    engage.add_argument("--reason", required=True)
    engage.add_argument("--execute", action="store_true")

    release = sub.add_parser("release-containment")
    release.add_argument("--manifest", type=Path, required=True)
    release.add_argument("--owner-receipt", type=Path, required=True)
    release.add_argument("--audit", type=Path, action="append", required=True)
    release.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    release.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    release.add_argument("--reason", required=True)
    release.add_argument("--execute", action="store_true")

    cutover = sub.add_parser("cutover")
    cutover.add_argument("--manifest", type=Path, required=True)
    cutover.add_argument("--owner-receipt", type=Path, required=True)
    cutover.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    cutover.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    cutover.add_argument("--db-backup", type=Path, required=True)
    cutover.add_argument("--receipt", type=Path, required=True)
    cutover.add_argument("--execute", action="store_true")

    rollback = sub.add_parser("rollback")
    rollback.add_argument("--manifest", type=Path, required=True)
    rollback.add_argument("--owner-receipt", type=Path, required=True)
    rollback.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    rollback.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    rollback.add_argument("--receipt", type=Path, required=True)
    rollback.add_argument("--execute", action="store_true")

    activate = sub.add_parser("activate-gate")
    activate.add_argument("--manifest", type=Path, required=True)
    activate.add_argument("--owner-receipt", type=Path, required=True)
    activate.add_argument("--audit", type=Path, action="append", required=True)
    activate.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    activate.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    activate.add_argument("--execute", action="store_true")

    ramp = sub.add_parser("set-ramp")
    ramp.add_argument("--manifest", type=Path, required=True)
    ramp.add_argument("--owner-receipt", type=Path, required=True)
    ramp.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    ramp.add_argument("--limit", type=int, choices=(1, 2, 5, 10), required=True)
    ramp.add_argument("--reason", required=True)
    ramp.add_argument("--execute", action="store_true")

    args = parser.parse_args(argv)
    try:
        if args.command == "build-manifest":
            manifest = build_archive_manifest(
                args.source_custom,
                archive_years=tuple(args.archive_year or DEFAULT_ARCHIVE_YEARS),
                current_year=args.current_year,
                runner_identity=args.runner_identity,
                hash_content=not args.metadata_only,
            )
            if args.dry_run and args.output:
                raise CustomHistoryMigrationError("dry-run cannot write --output")
            if args.output:
                write_json_atomic(args.output, manifest)
            _print({
                "status": "DRAFT_ONLY_UNSIGNED",
                "runtime_action": "NONE",
                "manifest_sha256": manifest["manifest_sha256"],
                "hash_mode": manifest["hash_mode"],
                "file_count": manifest["file_count"],
                "total_bytes": manifest["total_bytes"],
                "output": str(args.output) if args.output else None,
            })
            return 0
        if args.command == "attach-owner-approval":
            manifest = load_json_strict(args.manifest)
            approved = attach_owner_approval(manifest, load_json_strict(args.owner_receipt))
            write_json_atomic(args.output, approved)
            _print({"status": "OWNER_APPROVAL_ATTACHED", "manifest_sha256": approved["manifest_sha256"], "output": str(args.output)})
            return 0
        if args.command == "validate-authorization":
            manifest, owner = _require_authorized_execution(
                manifest_path=args.manifest,
                owner_receipt_path=args.owner_receipt,
                require_window_open=args.require_mutation_guard,
            )
            mutation_guard = None
            if args.require_mutation_guard:
                if args.farm_root is None:
                    raise CustomHistoryMigrationError(
                        "--require-mutation-guard requires --farm-root"
                    )
                mutation_guard = {
                    "factory_off": _require_factory_off(args.farm_root),
                    "containment": _require_containment_engaged(args.farm_root),
                }
            _print(
                {
                    "status": "PASS_AUTHORIZED",
                    "runtime_action": "NONE",
                    "manifest_sha256": manifest["manifest_sha256"],
                    "window_id": owner["window_id"],
                    "mutation_guard": mutation_guard,
                }
            )
            return 0
        if args.command == "plan":
            _print(build_stage_plan(manifest=load_json_strict(args.manifest), mt5_root=args.mt5_root, window_id=args.window_id))
            return 0
        if args.command == "stage":
            _print(stage_variant_a(manifest_path=args.manifest, owner_receipt_path=args.owner_receipt, mt5_root=args.mt5_root, farm_root=args.farm_root, receipt_path=args.receipt, acl_evidence_path=args.acl_evidence, execute=args.execute))
            return 0
        if args.command == "verify-stage":
            payload = verify_staging(manifest=load_manifest(args.manifest, require_owner_approval=True), mt5_root=args.mt5_root, window_id=args.window_id)
            _print(payload)
            return 0 if payload["status"] == "PASS_ISOLATED" else 2
        if args.command in {"engage-containment", "release-containment"}:
            manifest, owner = _require_authorized_execution(
                manifest_path=args.manifest,
                owner_receipt_path=args.owner_receipt,
                require_window_open=args.execute,
            )
            current = custom_history_lease.load_mode(args.farm_root)
            authorization_sha256 = sha256_file(args.owner_receipt)
            source = "owner_window_runbook"
            if args.command == "release-containment":
                if len(args.audit) != 2:
                    raise CustomHistoryMigrationError(
                        "release-containment requires exactly two --audit paths"
                    )
                active = custom_history_gate.load_activation(args.farm_root)
                requested_audits = {
                    str(Path(path).absolute()).casefold() for path in args.audit
                }
                active_audits = {
                    str(Path(row["path"]).absolute()).casefold()
                    for row in (active or {}).get("dual_audits", [])
                }
                if (
                    active is None
                    or active["manifest_sha256"] != manifest["manifest_sha256"]
                    or requested_audits != active_audits
                ):
                    raise CustomHistoryMigrationError(
                        "matching dual-audit isolation activation must be written before containment release"
                    )
                quiescence = quiescence_snapshot(
                    farm_root=args.farm_root,
                    mt5_root=args.mt5_root,
                    terminals=manifest["runner_terminals"],
                )
                if not quiescence.get("quiescent"):
                    raise CustomHistoryMigrationError(
                        f"containment release requires zero active work/processes: {quiescence}"
                    )
                if custom_history_lease.lease_path(args.farm_root).exists():
                    raise CustomHistoryMigrationError(
                        "global Custom-history lease record still exists at release boundary"
                    )
                authorization_sha256 = active["activation_sha256"]
                source = "dual_cutover_audits_passed_before_ramp"
            receipt = custom_history_lease.build_mode_receipt(
                enabled=args.command == "engage-containment",
                reason=args.reason,
                source=source,
                authorization_sha256=authorization_sha256,
                previous_mode_sha256=current.get("mode_sha256"),
            )
            if args.execute:
                custom_history_lease.write_mode(args.farm_root, receipt)
            _print({**receipt, "runtime_action": "MODE_WRITTEN" if args.execute else "NONE", "manifest_sha256": manifest["manifest_sha256"], "window_id": owner["window_id"]})
            return 0
        if args.command == "cutover":
            _print(cutover_variant_a(manifest_path=args.manifest, owner_receipt_path=args.owner_receipt, mt5_root=args.mt5_root, farm_root=args.farm_root, db_backup_path=args.db_backup, receipt_path=args.receipt, execute=args.execute))
            return 0
        if args.command == "rollback":
            _print(rollback_variant_a(manifest_path=args.manifest, owner_receipt_path=args.owner_receipt, mt5_root=args.mt5_root, farm_root=args.farm_root, receipt_path=args.receipt, execute=args.execute))
            return 0
        if args.command == "activate-gate":
            if len(args.audit) != 2:
                raise CustomHistoryMigrationError("activate-gate requires exactly two --audit paths")
            _require_authorized_execution(
                manifest_path=args.manifest,
                owner_receipt_path=args.owner_receipt,
                require_window_open=args.execute,
            )
            mode = custom_history_lease.load_mode(args.farm_root)
            if not mode.get("enabled"):
                raise CustomHistoryMigrationError(
                    "isolation activation requires engaged global containment"
                )
            quiescence = quiescence_snapshot(
                farm_root=args.farm_root,
                mt5_root=args.mt5_root,
                terminals=DEFAULT_RUNNER_TERMINALS,
            )
            if not quiescence.get("quiescent"):
                raise CustomHistoryMigrationError(
                    f"isolation activation requires quiescence: {quiescence}"
                )
            activation = custom_history_gate.build_activation(
                manifest_path=args.manifest,
                owner_window_receipt_path=args.owner_receipt,
                protected_roots=DEFAULT_PROTECTED_ROOTS,
                dual_audit_paths=args.audit,
            )
            if args.execute:
                custom_history_gate.write_activation(args.farm_root, activation)
            _print({**activation, "runtime_action": "ACTIVATION_WRITTEN" if args.execute else "NONE"})
            return 0
        if args.command == "set-ramp":
            manifest, owner = _require_authorized_execution(
                manifest_path=args.manifest,
                owner_receipt_path=args.owner_receipt,
                require_window_open=args.execute,
            )
            activation = custom_history_gate.load_activation(args.farm_root)
            if activation is None or activation["manifest_sha256"] != manifest["manifest_sha256"]:
                raise CustomHistoryMigrationError(
                    "matching isolation activation is required before setting ramp"
                )
            mode = custom_history_lease.load_mode(args.farm_root)
            if mode.get("enabled"):
                raise CustomHistoryMigrationError(
                    "release global containment after dual audits and before ramping"
                )
            current_ramp = custom_history_gate.load_ramp(
                args.farm_root,
                activation=activation,
            )
            current_limit = int(current_ramp["limit"]) if current_ramp else None
            next_limit = {None: 1, 1: 2, 2: 5, 5: 10, 10: None}[current_limit]
            if args.limit != next_limit:
                raise CustomHistoryMigrationError(
                    f"ramp must advance 1->2->5->10; current={current_limit}, next={next_limit}"
                )
            ramp_receipt = custom_history_gate.build_ramp(
                activation=activation,
                limit=args.limit,
                reason=args.reason,
            )
            if args.execute:
                custom_history_gate.write_ramp(
                    args.farm_root,
                    ramp_receipt,
                    activation=activation,
                )
            _print({
                **ramp_receipt,
                "runtime_action": "RAMP_WRITTEN" if args.execute else "NONE",
                "window_id": owner["window_id"],
            })
            return 0
    except (CustomHistoryContractError, CustomHistoryMigrationError, custom_history_gate.CustomHistoryGateError, custom_history_lease.CustomHistoryLeaseError, OSError, sqlite3.Error) as exc:
        _print({"status": "FAIL_CLOSED", "error": str(exc), "command": args.command})
        return 2
    raise AssertionError(args.command)


if __name__ == "__main__":
    raise SystemExit(main())
