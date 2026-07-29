#!/usr/bin/env python3
"""Plan/apply the six isolated FTMO Book-3 Q02 fidelity measurements.

Dry-run is the default.  The prepare apply path only creates the preregistered
R0/J0/R1/J1/R2/J2 pending rows and their non-releasing holds.  A separate
release plan/apply path can deactivate only those six holds, and only after all
six rows are done/PASS/unclaimed and three independently revalidated, create-
only fidelity PASS receipts cover stages 0, 1, and 2.  Neither path runs MT5,
promotes work, enqueues another phase, changes scheduled tasks, or removes
FACTORY_OFF.
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
import stat
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

try:
    from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
except ModuleNotFoundError:
    from tools.strategy_farm.factory_mutation_lock import (
        FactoryMutationLock,
        path_for_factory_flag,
    )


SCHEMA_PREPARE = "qm.ftmo-book3-q02-prepare-plan/v1"
SCHEMA_RELEASE = "qm.ftmo-book3-q02-release-holds-plan/v1"
SCHEMA_RECEIPT = "qm.ftmo-book3-q02-maintenance-receipt/v1"
SCHEMA_FIDELITY = "qm.ftmo-book3-fidelity-adjudication-receipt/v2"
FIDELITY_STAGES = (0, 1, 2)
FIDELITY_MEASUREMENT_CONTRACT = (
    "FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET"
)
EVIDENCE_VINTAGE = "FTMO_BOOK3_20260729_V2"
PREREGISTRATION_REL = Path(
    "docs/ops/evidence/2026-07-29_ftmo_book3_execution_preregistration_v2.md"
)
FULL_LIFECYCLE_MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
FIDELITY_COMPARISON_ALGORITHM = (
    "maximum_bipartite_exact_time_side_price_full_lifecycle_money_volume/v3"
)
DEFAULT_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_ARTIFACT_ROOT = Path(
    r"D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02"
)
DEFAULT_REPORT_ROOT = Path(r"D:\QM\reports\work_items")
DEFAULT_COMMON_QM = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM"
)
DEFAULT_T10_BASES = Path(r"D:\QM\mt5\T10\bases")
DEFAULT_CALENDAR_SOURCE = Path(r"D:\QM\data\news_calendar")
DEFAULT_CALENDAR_COMMON = DEFAULT_COMMON_QM.parent
CALENDAR_FILES = ("news_calendar_2015_2025.csv", "forex_factory_calendar_clean.csv")
DATA_SYMBOLS = ("USDJPY.DWX", "XAUUSD.DWX", "XTIUSD.DWX")
COST_ARTIFACT_ROLES = (
    "tester_cost_basis",
    "live_commission",
    "venue_cost_model",
    "dwx_symbol_matrix",
)
RUNTIME_SOURCE_ROLES = (
    "preparation_controller",
    "isolated_runner",
    "terminal_worker",
    "farmctl",
    "factory_mutation_lock",
    "phase_utils",
    "run_smoke",
    "qm_tasks_manifest",
    "factory_process_scope",
    "fidelity_gate",
    "fidelity_comparator",
    "preregistration",
)
COMPILE_MANIFEST_NAME = "compile_manifest.json"
COMPILE_CONTRACT = "FTMO_BOOK3_PORTABLE_COMPILE_V2"
COMPILE_CONTROLLER_REL = Path("tools/strategy_farm/compile_ftmo_book3_v2.ps1")
COMPILE_EAS: tuple[tuple[int, str], ...] = (
    (9936, "QM5_9936_ff-range-breakout-gmt3-h1"),
    (10145, "QM5_10145_tsm-meanret"),
    (13108, "QM5_13108_xti-mtsm-s2"),
    (20181, "QM5_20181_ftmo-joint-multisym-timer"),
)
TERMINAL = "T10"
FORBIDDEN_TERMINALS = ("T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T_LIVE")
HOLD_CODE = "FTMO_BOOK3_Q02_ISOLATED_ONLY"
HOLD_REASON = "OWNER-preregistered FTMO Book-3 Q02 fidelity ladder; isolated T10 execution only"
FROM_DATE = "2018.07.02"
TO_DATE = "2025.12.31"


class ContractError(RuntimeError):
    pass


RUN_SPECS: tuple[dict[str, Any], ...] = (
    {
        "code": "R0", "ea_id": "QM5_9936", "symbol": "USDJPY.DWX", "period": "H1",
        "ea_dir": "QM5_9936_ff-range-breakout-gmt3-h1",
        "set_name": "QM5_9936_ff-range-breakout-gmt3-h1_USDJPY.DWX_H1_backtest.set",
        "ex5_sha256": None,
        "evidence_run_id": None,
        "basket_symbols": (),
    },
    {
        "code": "J0", "ea_id": "QM5_20181", "symbol": "USDJPY.DWX", "period": "H1",
        "ea_dir": "QM5_20181_ftmo-joint-multisym-timer",
        "set_name": "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_replay_runner.set",
        "ex5_sha256": None,
        "evidence_run_id": "FTMO_BOOK3_20260729_V2_J0",
        "basket_symbols": ("USDJPY.DWX",),
    },
    {
        "code": "R1", "ea_id": "QM5_10145", "symbol": "XAUUSD.DWX", "period": "D1",
        "ea_dir": "QM5_10145_tsm-meanret",
        "set_name": "QM5_10145_tsm-meanret_XAUUSD.DWX_D1_backtest.set",
        "ex5_sha256": None,
        "evidence_run_id": None,
        "basket_symbols": (),
    },
    {
        "code": "J1", "ea_id": "QM5_20181", "symbol": "USDJPY.DWX", "period": "H1",
        "ea_dir": "QM5_20181_ftmo-joint-multisym-timer",
        "set_name": "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book2_9936_10145.set",
        "ex5_sha256": None,
        "evidence_run_id": "FTMO_BOOK3_20260729_V2_J1",
        "basket_symbols": ("USDJPY.DWX", "XAUUSD.DWX"),
    },
    {
        "code": "R2", "ea_id": "QM5_13108", "symbol": "XTIUSD.DWX", "period": "D1",
        "ea_dir": "QM5_13108_xti-mtsm-s2",
        "set_name": "QM5_13108_xti-mtsm-s2_XTIUSD.DWX_D1_backtest.set",
        "ex5_sha256": None,
        "evidence_run_id": None,
        "basket_symbols": (),
    },
    {
        "code": "J2", "ea_id": "QM5_20181", "symbol": "USDJPY.DWX", "period": "H1",
        "ea_dir": "QM5_20181_ftmo-joint-multisym-timer",
        "set_name": "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book3_9936_10145_13108.set",
        "ex5_sha256": None,
        "evidence_run_id": "FTMO_BOOK3_20260729_V2_J2",
        "basket_symbols": ("USDJPY.DWX", "XAUUSD.DWX", "XTIUSD.DWX"),
    },
)


def _bound_run_specs(ex5_by_ea: dict[str, str]) -> tuple[dict[str, Any], ...]:
    expected = {f"QM5_{ea_id}" for ea_id, _ in COMPILE_EAS}
    if set(ex5_by_ea) != expected or any(
        not re.fullmatch(r"[0-9a-f]{64}", value)
        for value in ex5_by_ea.values()
    ):
        raise ContractError("compile manifest does not bind the exact four EX5 hashes")
    return tuple({**spec, "ex5_sha256": ex5_by_ea[str(spec["ea_id"])]} for spec in RUN_SPECS)


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def canonical_sha(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _reject_duplicate_object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _strict_json_object(data: bytes, label: str) -> dict[str, Any]:
    """Decode one duplicate-free finite JSON object from already-read bytes."""

    def reject_constant(value: str) -> None:
        raise ContractError(f"{label} contains non-finite JSON constant: {value}")

    try:
        value = json.loads(
            data.decode("utf-8-sig"),
            object_pairs_hook=_reject_duplicate_object_pairs,
            parse_constant=reject_constant,
        )
    except ContractError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ContractError(f"{label} is not strict UTF-8 JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractError(f"{label} must be a JSON object")
    return value


def _is_reparse_point(path_stat: os.stat_result) -> bool:
    attributes = getattr(path_stat, "st_file_attributes", 0)
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return bool(reparse_flag and attributes & reparse_flag)


def _read_unaliased_regular_file_once(path: Path, label: str) -> tuple[Path, bytes, str, tuple[int, int]]:
    """Read an absolute, canonical, single-link regular file exactly once.

    Fidelity receipts are create-only authorization artifacts.  Symlinks,
    reparse points, hard links and lexical aliases would let a caller present
    one mutable inode under several identities, so all are rejected.
    """

    path = Path(path)
    if not path.is_absolute():
        raise ContractError(f"{label} path must be absolute: {path}")
    lexical = Path(os.path.abspath(str(path)))
    try:
        resolved = path.resolve(strict=True)
        path_lstat = path.lstat()
    except OSError as exc:
        raise ContractError(f"{label} is unavailable: {path}: {exc}") from exc
    if _path_identity(lexical) != _path_identity(resolved):
        raise ContractError(f"{label} path is an alias: supplied={path} resolved={resolved}")
    if path.is_symlink() or _is_reparse_point(path_lstat):
        raise ContractError(f"{label} must not be a symlink or reparse point: {path}")
    if not stat.S_ISREG(path_lstat.st_mode):
        raise ContractError(f"{label} is not a regular file: {path}")
    if int(path_lstat.st_nlink) != 1:
        raise ContractError(f"{label} must have exactly one filesystem link: {path}")
    try:
        with path.open("rb") as handle:
            before = os.fstat(handle.fileno())
            data = handle.read()
            after = os.fstat(handle.fileno())
    except OSError as exc:
        raise ContractError(f"{label} could not be read: {path}: {exc}") from exc
    stable_before = (
        before.st_dev,
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
        before.st_ctime_ns,
    )
    stable_after = (
        after.st_dev,
        after.st_ino,
        after.st_size,
        after.st_mtime_ns,
        after.st_ctime_ns,
    )
    if stable_before != stable_after or len(data) != before.st_size:
        raise ContractError(f"{label} changed while it was read: {path}")
    try:
        post = path.stat()
    except OSError as exc:
        raise ContractError(f"{label} disappeared after it was read: {path}") from exc
    if (post.st_dev, post.st_ino) != (before.st_dev, before.st_ino):
        raise ContractError(f"{label} path changed identity while it was read: {path}")
    return resolved, data, hashlib.sha256(data).hexdigest(), (before.st_dev, before.st_ino)


def connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def sqlite_state_sha256(db: Path) -> str:
    with connect_ro(db) as conn:
        return hashlib.sha256(conn.serialize()).hexdigest()


def sqlite_snapshot(source: Path, target: Path) -> str:
    if target.exists():
        raise ContractError(f"snapshot target already exists: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f".{target.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    # Create the backing inode exclusively, populate it, then publish with a
    # no-replace hard link.  Unlike os.replace, this can never overwrite a path
    # that appears after the initial preflight.
    with temporary.open("xb"):
        pass
    source_conn = sqlite3.connect(source, timeout=30)
    target_conn = sqlite3.connect(temporary)
    try:
        source_conn.backup(target_conn)
    finally:
        target_conn.close()
        source_conn.close()
    try:
        os.link(temporary, target)
        return sha256_file(target)
    except FileExistsError as exc:
        raise ContractError(f"snapshot target appeared during publication: {target}") from exc
    finally:
        temporary.unlink(missing_ok=True)


def _git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", *args], cwd=repo, capture_output=True, text=True, timeout=30,
        creationflags=(subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0),
    )
    if proc.returncode:
        raise ContractError(f"git {' '.join(args)} failed: {(proc.stderr or proc.stdout).strip()}")
    return (proc.stdout or "").strip()


def _artifact(path: Path, role: str, *, expected_sha256: str | None = None) -> dict[str, Any]:
    item: dict[str, Any] = {"role": role, "path": str(path)}
    if not path.is_file():
        return {**item, "valid": False, "reason": "missing"}
    actual = sha256_file(path)
    item.update({"sha256": actual, "bytes": path.stat().st_size, "valid": True})
    if expected_sha256 and actual != expected_sha256.lower():
        item.update({"valid": False, "reason": "authoritative_sha256_mismatch", "expected_sha256": expected_sha256.lower()})
    return item


def _tree_artifact(path: Path, role: str) -> dict[str, Any]:
    if not path.is_dir():
        return {"role": role, "path": str(path), "valid": False, "reason": "missing"}
    rows = []
    for child in sorted((p for p in path.rglob("*") if p.is_file()), key=lambda p: p.relative_to(path).as_posix().lower()):
        rows.append({"path": child.relative_to(path).as_posix(), "sha256": sha256_file(child), "bytes": child.stat().st_size})
    return {"role": role, "path": str(path), "sha256": canonical_sha(rows), "file_count": len(rows), "valid": bool(rows)}


def _compile_tree_digest(path: Path) -> dict[str, Any]:
    """Reproduce compile_ftmo_book3_v2.ps1 Get-TreeDigest byte-for-byte."""
    root = Path(path).resolve(strict=True)
    # Windows PowerShell's ``Sort-Object FullName`` orders an ASCII sibling
    # such as ``QM_Branding.mqh`` before a child such as ``QM\modules\...``.
    # Python's ordinal path sort does the opposite because ``\\`` sorts before
    # ``_``.  Treat separators as a high sentinel to match the producer.
    def powershell_fullname_key(child: Path) -> str:
        return str(child.resolve()).casefold().replace("\\", "\uffff").replace("/", "\uffff")

    files = sorted(
        (child for child in root.rglob("*") if child.is_file()),
        key=powershell_fullname_key,
    )
    if not files:
        raise ContractError(f"compile tree is empty: {root}")
    rows: list[bytes] = []
    total = 0
    for child in files:
        resolved = child.resolve(strict=True)
        try:
            relative = resolved.relative_to(root).as_posix()
        except ValueError as exc:
            raise ContractError(f"compile tree member escaped root: {child}") from exc
        size = resolved.stat().st_size
        rows.append(f"{relative}\0{sha256_file(resolved)}\0{size}\n".encode("utf-8"))
        total += size
    return {
        "root": str(root),
        "sha256": hashlib.sha256(b"".join(rows)).hexdigest(),
        "file_count": len(files),
        "total_bytes": total,
    }


def _require_exact_path(value: Any, expected: Path, label: str) -> Path:
    supplied = Path(str(value or ""))
    if not supplied.is_absolute() or _path_identity(supplied) != _path_identity(expected):
        raise ContractError(f"{label} path mismatch: expected={expected} actual={value}")
    return supplied


def _require_current_file(binding: Any, expected: Path, label: str) -> dict[str, Any]:
    if not isinstance(binding, dict):
        raise ContractError(f"{label} binding must be an object")
    path = _require_exact_path(binding.get("path"), expected, label)
    if not path.is_file():
        raise ContractError(f"{label} is missing: {path}")
    actual = sha256_file(path)
    if binding.get("sha256") != actual:
        raise ContractError(f"{label} SHA-256 mismatch")
    return {"path": str(path), "sha256": actual, "bytes": path.stat().st_size}


def _git_ancestor_with_clean_compile_scope(
    repo: Path, compile_commit: str, authoritative_commit: str,
) -> None:
    if compile_commit == authoritative_commit:
        return
    proc = subprocess.run(
        ["git", "merge-base", "--is-ancestor", compile_commit, authoritative_commit],
        cwd=repo, capture_output=True, text=True, timeout=30,
        creationflags=(subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0),
    )
    if proc.returncode != 0:
        raise ContractError("compile source_commit is not an ancestor of authoritative prepare commit")
    scope = [
        *(f"framework/EAs/{name}" for _, name in COMPILE_EAS),
        "framework/include",
        COMPILE_CONTROLLER_REL.as_posix(),
    ]
    changed = _git(repo, "diff", "--name-only", f"{compile_commit}..{authoritative_commit}", "--", *scope)
    if changed:
        raise ContractError(f"compile-relevant source changed after compile source_commit: {changed}")


def _load_compile_manifest(
    *, repo: Path, artifact_root: Path, flag: Path,
    authoritative_source_commit: str, supplied_joint_ex5_sha256: str | None = None,
) -> tuple[dict[str, Any], dict[str, str]]:
    manifest_path = artifact_root / COMPILE_MANIFEST_NAME
    resolved, raw, manifest_sha, _ = _read_unaliased_regular_file_once(
        manifest_path, "FTMO Book-3 compile manifest"
    )
    document = _strict_json_object(raw, "FTMO Book-3 compile manifest")
    fixed = {
        "schema_version": 2,
        "contract": COMPILE_CONTRACT,
        "result": "PASS",
        "create_only": True,
        "serial_compile": True,
        "canonical_publication_after_four_pass": True,
        "terminals_started": [],
        "terminals_modified": [],
    }
    for key, expected in fixed.items():
        if type(document.get(key)) is not type(expected) or document.get(key) != expected:
            raise ContractError(f"compile manifest has invalid {key}")
    _require_exact_path(document.get("artifact_root"), artifact_root, "compile artifact_root")
    compile_commit = document.get("source_commit")
    if not isinstance(compile_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", compile_commit):
        raise ContractError("compile manifest source_commit must be 40 lowercase hexadecimal characters")
    _git_ancestor_with_clean_compile_scope(repo, compile_commit, authoritative_source_commit)

    factory = document.get("factory_off")
    if not isinstance(factory, dict):
        raise ContractError("compile manifest factory_off binding is missing")
    _require_exact_path(factory.get("path"), flag, "compile factory_off")
    if not flag.is_file() or factory.get("sha256") != sha256_file(flag):
        raise ContractError("compile manifest FACTORY_OFF binding drifted")
    mutation = document.get("mutation_lock")
    if not isinstance(mutation, dict) or mutation.get("required_absent") is not True:
        raise ContractError("compile manifest mutation-lock absence contract is invalid")
    expected_lock = path_for_factory_flag(flag)
    _require_exact_path(mutation.get("path"), expected_lock, "compile mutation_lock")

    controller_path = repo / COMPILE_CONTROLLER_REL
    controller = _require_current_file(document.get("tool"), controller_path, "compile controller")
    compiler = document.get("compiler")
    if not isinstance(compiler, dict) or compiler.get("portable") is not True or compiler.get("invocation_switch") != "/portable":
        raise ContractError("compile manifest portable compiler identity is invalid")
    template_root = Path(str(compiler.get("source_template_root") or ""))
    if not template_root.is_absolute() or not template_root.is_dir():
        raise ContractError("compile manifest compiler source_template_root is invalid")
    expected_compiler_paths = {
        "source_path": template_root / "MetaEditor64.exe",
        "workspace_path": artifact_root / "workspace/portable_metaeditor/MetaEditor64.exe",
    }
    for key, expected_path in expected_compiler_paths.items():
        path = Path(str(compiler.get(key) or ""))
        _require_exact_path(path, expected_path, f"compile compiler {key}")
        if not path.is_file():
            raise ContractError(f"compile manifest compiler {key} is missing")
        if compiler.get(key.replace("path", "sha256")) != sha256_file(path):
            raise ContractError(f"compile manifest compiler {key} hash drifted")
    if compiler.get("source_sha256") != compiler.get("workspace_sha256"):
        raise ContractError("portable compiler source/workspace identity mismatch")
    if not isinstance(compiler.get("file_version"), str) or not compiler["file_version"]:
        raise ContractError("compile manifest compiler file_version is missing")
    if not isinstance(compiler.get("product_version"), str) or not compiler["product_version"]:
        raise ContractError("compile manifest compiler product_version is missing")
    for key, expected_path in (
        ("isolated_appdata", artifact_root / "workspace/profile/Roaming"),
        ("isolated_localappdata", artifact_root / "workspace/profile/Local"),
    ):
        _require_exact_path(compiler.get(key), expected_path, f"compile compiler {key}")

    current_overlay = _compile_tree_digest(repo / "framework/include")
    include_trees = document.get("include_trees")
    if not isinstance(include_trees, dict):
        raise ContractError("compile manifest include_trees binding is missing")
    for key in ("repo_overlay", "repo_overlay_after"):
        if include_trees.get(key) != current_overlay:
            raise ContractError(f"compile manifest {key} does not match current repo include tree")

    expected_order = [name for _, name in COMPILE_EAS]
    if document.get("compile_order") != expected_order:
        raise ContractError("compile manifest compile_order is not the exact four-EA order")
    results = document.get("results")
    if not isinstance(results, list) or len(results) != len(COMPILE_EAS):
        raise ContractError("compile manifest must contain exactly four results")
    ex5_by_ea: dict[str, str] = {}
    for result, (ea_id, name) in zip(results, COMPILE_EAS):
        if not isinstance(result, dict):
            raise ContractError("compile result must be an object")
        if result.get("ea_id") != ea_id or type(result.get("ea_id")) is not int or result.get("name") != name:
            raise ContractError("compile result ID/name/order mismatch")
        if result.get("result") != "PASS" or result.get("errors") != 0 or result.get("warnings") != 0:
            raise ContractError(f"compile result is not strict PASS: {name}")
        if type(result.get("errors")) is not int or type(result.get("warnings")) is not int:
            raise ContractError(f"compile result counters must be integers: {name}")
        # MetaEditor64 uses both 0 and 1 as successful process exit codes in
        # observed portable builds.  PASS remains anchored to fresh EX5/log
        # hashes plus the parsed 0-error/0-warning result.
        if type(result.get("metaeditor_exit_code")) is not int or result.get("metaeditor_exit_code") not in {0, 1}:
            raise ContractError(f"compile result MetaEditor exit code is outside the accepted producer contract: {name}")
        mq5 = repo / "framework/EAs" / name / f"{name}.mq5"
        _require_exact_path(result.get("source_mq5_path"), mq5, f"compile source MQ5 {name}")
        if not mq5.is_file() or result.get("source_mq5_sha256") != sha256_file(mq5):
            raise ContractError(f"compile source MQ5 hash drifted: {name}")
        ex5 = artifact_root / "canonical_staged_ex5" / f"{name}.ex5"
        log = artifact_root / "canonical_compile_logs" / f"{name}.compile.log"
        _require_exact_path(result.get("ex5_path"), ex5, f"compiled EX5 {name}")
        _require_exact_path(result.get("compile_log_path"), log, f"compile log {name}")
        if not ex5.is_file() or result.get("ex5_sha256") != sha256_file(ex5):
            raise ContractError(f"compiled EX5 hash drifted: {name}")
        if not log.is_file() or result.get("compile_log_sha256") != sha256_file(log):
            raise ContractError(f"compile log hash drifted: {name}")
        raw_log = log.read_bytes()
        encoding = "utf-16" if raw_log.startswith((b"\xff\xfe", b"\xfe\xff")) or b"\x00" in raw_log[:256] else "utf-8-sig"
        if "Result: 0 errors, 0 warnings" not in raw_log.decode(encoding, errors="replace"):
            raise ContractError(f"compile log is not a strict pass: {name}")
        ex5_by_ea[f"QM5_{ea_id}"] = str(result["ex5_sha256"])

    publication = document.get("publication")
    if not isinstance(publication, dict):
        raise ContractError("compile manifest publication binding is missing")
    for key, directory in (
        ("staged_ex5_tree", artifact_root / "canonical_staged_ex5"),
        ("compile_logs_tree", artifact_root / "canonical_compile_logs"),
    ):
        if publication.get(key) != _compile_tree_digest(directory):
            raise ContractError(f"compile manifest publication {key} drifted")
    joint = ex5_by_ea["QM5_20181"]
    if supplied_joint_ex5_sha256 is not None and supplied_joint_ex5_sha256 != joint:
        raise ContractError("supplied joint EX5 SHA-256 differs from compile manifest")
    binding = {
        "path": str(resolved),
        "sha256": manifest_sha,
        "bytes": len(raw),
        "source_commit": compile_commit,
        "compile_controller": controller,
    }
    return binding, ex5_by_ea


def _factory_processes() -> list[dict[str, Any]]:
    try:
        try:
            import isolated_work_item_runner as runner
        except ModuleNotFoundError:
            from tools.strategy_farm import isolated_work_item_runner as runner
        return list(runner._factory_processes())
    except Exception as exc:
        return [{"classification": "SCAN_FAILED", "error": str(exc)}]


def _calendar_preflight(source_dir: Path, common_dir: Path) -> dict[str, Any]:
    try:
        try:
            import news_calendar_gate
        except ModuleNotFoundError:
            from tools.strategy_farm import news_calendar_gate
        return news_calendar_gate.preflight_news_calendar(
            use_cache=False, source_dir=source_dir, common_dir=common_dir
        ).as_dict()
    except Exception as exc:
        return {"ok": False, "status": "PREFLIGHT_EXCEPTION", "detail": str(exc)}


def _table_columns(conn: sqlite3.Connection, table: str) -> set[str]:
    return {str(row[1]) for row in conn.execute(f"PRAGMA table_info({table})")}


def _schema_errors(conn: sqlite3.Connection) -> list[str]:
    required_work = {
        "id", "kind", "phase", "ea_id", "symbol", "setfile_path", "status", "verdict",
        "attempt_count", "parent_task_id", "evidence_path", "claimed_by", "payload_json",
        "created_at", "updated_at",
    }
    required_hold = {
        "work_item_id", "hold_code", "reason", "active", "release_on_restart", "created_at",
        "updated_at", "released_at", "release_note",
    }
    errors = []
    for table, required in (("work_items", required_work), ("work_item_holds", required_hold)):
        missing = sorted(required - _table_columns(conn, table))
        if missing:
            errors.append(f"{table} missing columns: {','.join(missing)}")
    return errors


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key.strip() in values:
            raise ContractError(f"duplicate set key {key.strip()}: {path}")
        values[key.strip()] = value.strip()
    return values


def _validate_set(spec: dict[str, Any], path: Path) -> list[str]:
    try:
        values = _set_values(path)
    except Exception as exc:
        return [f"{spec['code']} set parse failed: {exc}"]
    errors = []
    for key, expected in (("RISK_FIXED", "1000"), ("RISK_PERCENT", "0"), ("PORTFOLIO_WEIGHT", "1")):
        if values.get(key) != expected:
            errors.append(f"{spec['code']} {key} must equal {expected}")
    enabled = len(spec["basket_symbols"])
    if spec["code"].startswith("J"):
        if values.get("qm_evidence_run_id") != spec.get("evidence_run_id"):
            errors.append(f"{spec['code']} qm_evidence_run_id mismatch")
        if values.get("qm_stress_reject_probability") not in {"0", "0.0"}:
            errors.append(f"{spec['code']} stress rejection must be zero")
        for slot in range(3):
            if values.get(f"s{slot}_enabled") != ("1" if slot < enabled else "0"):
                errors.append(f"{spec['code']} s{slot}_enabled mismatch")
            if values.get(f"s{slot}_risk_fixed") != "1000":
                errors.append(f"{spec['code']} s{slot}_risk_fixed must equal 1000")
    return errors


def _registry_errors(registry: Path, resolver: Path) -> list[str]:
    errors: list[str] = []
    if not registry.is_file() or not resolver.is_file():
        return ["magic registry or resolver missing"]
    with registry.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row.get("ea_id") == "20181" and row.get("status") == "active"]
    expected = {
        ("0", "USDJPY.DWX", "201810000"),
        ("1", "XAUUSD.DWX", "201810001"),
        ("2", "XTIUSD.DWX", "201810002"),
    }
    actual = {(str(r.get("symbol_slot")), str(r.get("symbol")), str(r.get("magic"))) for r in rows}
    if actual != expected:
        errors.append(f"20181 registry tuple mismatch: {sorted(actual)}")
    text = resolver.read_text(encoding="utf-8-sig")
    match = re.search(r'QM_MAGIC_REGISTRY_SHA256\s+"([0-9A-Fa-f]{64})"', text)
    if not match or match.group(1).lower() != sha256_file(registry):
        errors.append("magic resolver registry SHA-256 mismatch")
    return errors


def _repo_paths(repo: Path, controller_path: Path) -> tuple[list[Path], list[Path]]:
    source_paths = [
        repo / PREREGISTRATION_REL,
        repo / "framework/registry/magic_numbers.csv",
        repo / "framework/include/QM/QM_MagicResolver.mqh",
        repo / "framework/include/QM",
        repo / "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt",
        repo / "framework/registry/live_commission.json",
        repo / "framework/registry/venue_cost_model.json",
        repo / "framework/registry/dwx_symbol_matrix.csv",
        repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json",
        repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json",
        repo / "framework/scripts/run_smoke.ps1",
    ]
    for spec in RUN_SPECS:
        ea_dir = repo / "framework/EAs" / spec["ea_dir"]
        source_paths.extend([ea_dir / f"{spec['ea_dir']}.mq5", ea_dir / "sets" / spec["set_name"]])
    controller_paths = [
        controller_path,
        repo / "tools/strategy_farm/terminal_worker.py",
        repo / "tools/strategy_farm/isolated_work_item_runner.py",
        repo / "tools/strategy_farm/farmctl.py",
        repo / "tools/strategy_farm/factory_mutation_lock.py",
        repo / "framework/scripts/_phase_utils.py",
        repo / "framework/scripts/run_smoke.ps1",
        repo / "tools/strategy_farm/qm_tasks.manifest.ps1",
        repo / "tools/strategy_farm/factory_process_scope.ps1",
        repo / "tools/strategy_farm/ftmo_book3_fidelity_gate.py",
        repo / "tools/strategy_farm/compare_joint_replay.py",
    ]
    return source_paths, controller_paths


def _git_identity(repo: Path, controller_path: Path, source_commit: str) -> tuple[dict[str, Any], list[str]]:
    errors: list[str] = []
    try:
        head = _git(repo, "rev-parse", "HEAD")
        resolved_source = _git(repo, "rev-parse", f"{source_commit}^{{commit}}")
        if resolved_source.lower() != source_commit.lower():
            errors.append("authoritative source commit did not resolve exactly")
        if head.lower() != source_commit.lower():
            errors.append("authoritative source commit must equal controller HEAD")
        source_paths, controller_paths = _repo_paths(repo, controller_path)
        scoped = []
        for path in [*source_paths, *controller_paths]:
            try:
                rel = path.resolve().relative_to(repo.resolve()).as_posix()
            except (OSError, ValueError):
                errors.append(f"git-bound path outside repo: {path}")
                continue
            if rel not in scoped:
                scoped.append(rel)
        status = _git(repo, "status", "--porcelain=v1", "--untracked-files=all", "--", *scoped)
        if status:
            errors.append("git-bound execution/controller scope is dirty")
        source_rel = []
        for path in source_paths:
            rel = path.resolve().relative_to(repo.resolve()).as_posix()
            if rel not in source_rel:
                source_rel.append(rel)
        source_diff = _git(repo, "diff", "--name-only", source_commit, "--", *source_rel)
        if source_diff:
            errors.append("execution source differs from authoritative source commit")
        return {
            "controller_head_commit": head.lower(),
            "authoritative_source_commit": source_commit.lower(),
            "scoped_status": status.splitlines() if status else [],
            "source_diff": source_diff.splitlines() if source_diff else [],
        }, errors
    except Exception as exc:
        return {"authoritative_source_commit": source_commit.lower()}, [f"git identity failed: {exc}"]


def _plan_core(plan: dict[str, Any]) -> dict[str, Any]:
    core = copy.deepcopy(plan)
    # Validity and the exact diagnostic set are authorization-bearing.  An
    # invalid dry-run must not become applicable by flipping ``valid`` while
    # retaining the original plan id.
    for key in ("generated_at_utc", "plan_id"):
        core.pop(key, None)
    return core


def _assign_plan_id(plan: dict[str, Any]) -> None:
    plan["plan_id"] = canonical_sha(_plan_core(plan))


def _validate_plan_id(plan: dict[str, Any]) -> None:
    actual = canonical_sha(_plan_core(plan))
    if str(plan.get("plan_id") or "") != actual:
        raise ContractError(f"plan_id mismatch: expected={plan.get('plan_id')} actual={actual}")


def _content_uuid(content_sha256: str) -> str:
    uuid_bytes = bytearray(bytes.fromhex(content_sha256[:32]))
    uuid_bytes[6] = (uuid_bytes[6] & 0x0F) | 0x50
    uuid_bytes[8] = (uuid_bytes[8] & 0x3F) | 0x80
    return str(uuid.UUID(bytes=bytes(uuid_bytes)))


def _validate_prepare_operations(
    manifest: dict[str, Any], *, validate_live_source: bool = True
) -> None:
    _validate_manifest_topology(manifest)
    repo = Path(str(manifest["repo"]))
    artifact_root = Path(str(manifest["artifact_root"]))
    report_root = Path(str(manifest["report_root"]))
    common_qm = Path(str(manifest["common_qm"]))
    t10_bases = Path(str(manifest["t10_bases"]))
    calendar_source = Path(str(manifest["calendar_source"]))
    calendar_common = Path(str(manifest["calendar_common"]))
    compile_binding, ex5_by_ea = _load_compile_manifest(
        repo=repo,
        artifact_root=artifact_root,
        flag=Path(str(manifest["factory_off"]["path"])),
        authoritative_source_commit=str(manifest["git"]["authoritative_source_commit"]),
        supplied_joint_ex5_sha256=str(manifest.get("joint_ex5_sha256") or ""),
    )
    if manifest.get("compile_manifest") != compile_binding:
        raise ContractError("prepare compile-manifest binding drifted")
    if manifest.get("compiled_ex5_sha256_by_ea") != ex5_by_ea:
        raise ContractError("prepare compiled EX5 map drifted")
    specs = _bound_run_specs(ex5_by_ea)
    operations = manifest.get("operations") or []
    if manifest.get("terminal") != TERMINAL or len(operations) != len(specs):
        raise ContractError("prepare manifest is not the exact six-item T10 contract")
    artifacts = manifest.get("artifacts") or []
    roles = [str(item.get("role") or "") for item in artifacts]
    paths = [str(item.get("path") or "").casefold() for item in artifacts]
    if len(roles) != len(set(roles)) or len(paths) != len(set(paths)):
        raise ContractError("prepare manifest artifacts must occur exactly once by role and path")
    if any(item.get("valid") is not True for item in artifacts):
        raise ContractError("prepare manifest contains an invalid artifact")
    amap = _artifact_map(artifacts)
    if "compile_manifest" not in amap or "compile_controller" not in amap:
        raise ContractError("prepare manifest is missing compile provenance artifacts")
    if {
        key: amap["compile_manifest"].get(key)
        for key in ("path", "sha256", "bytes")
    } != {
        key: compile_binding[key] for key in ("path", "sha256", "bytes")
    }:
        raise ContractError("prepare compile-manifest artifact binding is invalid")
    if {
        key: amap["compile_controller"].get(key)
        for key in ("path", "sha256", "bytes")
    } != compile_binding["compile_controller"]:
        raise ContractError("prepare compile-controller artifact binding is invalid")
    expected_controller_artifacts = {
        role: {
            "path": amap[role]["path"],
            "sha256": amap[role]["sha256"],
            "bytes": amap[role]["bytes"],
        }
        for role in (
            "preparation_controller", "isolated_runner", "terminal_worker",
            "compile_manifest",
        )
    }
    if manifest.get("controller_artifacts") != expected_controller_artifacts:
        raise ContractError("prepare manifest controller artifact bindings are invalid")
    expected_input_paths = _required_execution_input_paths(
        repo=repo, t10_bases=t10_bases,
        calendar_source=calendar_source, calendar_common=calendar_common,
    )
    if set(expected_input_paths) - set(amap):
        raise ContractError("prepare manifest is missing required execution input artifacts")
    for role, expected_path in expected_input_paths.items():
        if amap[role].get("path") != expected_path:
            raise ContractError(f"prepare manifest execution input has invalid path: {role}")
    if validate_live_source:
        rulepack_errors = _rulepack_snapshot_errors(
            Path(amap["ftmo_rulepack"]["path"]),
            Path(amap["ftmo_official_rules_snapshot"]["path"]),
        )
        if rulepack_errors:
            raise ContractError("; ".join(rulepack_errors))
    execution_inputs = _execution_input_artifacts(artifacts)
    if [item["role"] for item in execution_inputs] != sorted(expected_input_paths):
        raise ContractError("prepare manifest execution input artifact list is not exact")
    execution_inputs_sha = canonical_sha(execution_inputs)
    runtime_sources = _runtime_source_artifacts(artifacts)
    if [item["role"] for item in runtime_sources] != sorted(RUNTIME_SOURCE_ROLES):
        raise ContractError("prepare manifest runtime source artifact list is not exact")
    runtime_sources_sha = canonical_sha(runtime_sources)
    if manifest.get("execution_input_artifacts_sha256") != execution_inputs_sha:
        raise ContractError("prepare manifest has invalid canonical execution input list hash")
    data_bundle_sha = _artifact_bundle_sha(
        artifacts,
        ("t10_terminal_binary", "t10_metatester_binary", "t10_symbol_spec", "history:", "ticks:"),
    )
    calendar_bundle_sha = _artifact_bundle_sha(artifacts, ("calendar_source:", "calendar_common:"))
    cost_bundle_sha = canonical_sha([
        {"role": role, "path": amap[role]["path"], "sha256": amap[role]["sha256"], "bytes": amap[role]["bytes"]}
        for role in COST_ARTIFACT_ROLES
    ])
    for sequence, (spec, operation) in enumerate(zip(specs, operations)):
        required_fidelity_stage = None if sequence < 2 else (sequence // 2) - 1
        expected_set = repo / "framework/EAs" / spec["ea_dir"] / "sets" / spec["set_name"]
        fixed = {
            "code": spec["code"], "sequence": sequence, "kind": "backtest", "phase": "Q02",
            "ea_id": spec["ea_id"], "symbol": spec["symbol"], "setfile_path": str(expected_set),
        }
        for key, expected in fixed.items():
            if operation.get(key) != expected:
                raise ContractError(f"prepare operation {spec['code']} has invalid {key}")
        execution_sha = str(operation.get("execution_bundle_sha256") or "")
        if not re.fullmatch(r"[0-9a-f]{64}", execution_sha) or operation.get("work_item_id") != _content_uuid(execution_sha):
            raise ContractError(f"prepare operation {spec['code']} has invalid content-addressed UUID")
        expected_report = report_root / operation["work_item_id"]
        if operation.get("report_root") != str(expected_report):
            raise ContractError(f"prepare operation {spec['code']} has invalid report root")
        if operation.get("hold") != {
            "hold_code": HOLD_CODE, "reason": HOLD_REASON, "active": 1, "release_on_restart": 0,
        }:
            raise ContractError(f"prepare operation {spec['code']} has invalid hold")
        try:
            payload = json.loads(operation["payload_json"])
        except (KeyError, TypeError, json.JSONDecodeError) as exc:
            raise ContractError(f"prepare operation {spec['code']} payload invalid") from exc
        expected_trade = common_qm / "q08_trades" / f"{str(spec['ea_id']).replace('QM5_', '')}_{str(spec['symbol']).replace('.', '_')}.jsonl"
        expected_streams = ([{
            "stream_type": "q08_equity",
            "source": str(common_qm / "q08_equity" / "20181_USDJPY_DWX.jsonl"),
        }] if spec["basket_symbols"] else [])
        checks = {
            "measurement_contract": FIDELITY_MEASUREMENT_CONTRACT,
            "evidence_vintage": EVIDENCE_VINTAGE,
            "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
            "measurement_rung": spec["code"], "measurement_sequence": sequence,
            "evidence_run_id": spec.get("evidence_run_id"),
            "required_fidelity_stage": required_fidelity_stage,
            "execution_bundle_sha256": execution_sha, "terminal": TERMINAL,
            "authoritative_source_commit": manifest["git"]["authoritative_source_commit"],
            "controller_head_commit": manifest["git"]["controller_head_commit"],
            "avoid_terminals": list(FORBIDDEN_TERMINALS), "ea_dir_name": spec["ea_dir"],
            "host_timeframe": spec["period"], "staged_ex5_path": str(artifact_root / "canonical_staged_ex5" / f"{spec['ea_dir']}.ex5"),
            "staged_ex5_sha256": spec["ex5_sha256"], "from_date": FROM_DATE, "to_date": TO_DATE,
            "tester_currency": "USD", "tester_deposit": 100000, "risk_mode": "RISK_FIXED",
            "risk_fixed": 1000, "risk_percent": 0, "model": 4, "report_root": str(expected_report),
            "post_run_file_common_source": str(expected_trade), "post_run_file_common_streams": expected_streams,
            "expected_setfile_sha256": amap[f"set:{spec['code']}"]["sha256"],
            "expected_mq5_sha256": amap[f"mq5:{spec['ea_dir']}"]["sha256"],
            "framework_include_tree_sha256": amap["framework_include_tree"]["sha256"],
            "preregistration_sha256": amap["preregistration"]["sha256"],
            "isolated_runner_path": amap["isolated_runner"]["path"],
            "isolated_runner_sha256": amap["isolated_runner"]["sha256"],
            "terminal_worker_path": amap["terminal_worker"]["path"],
            "terminal_worker_sha256": amap["terminal_worker"]["sha256"],
            "preparation_controller_path": amap["preparation_controller"]["path"],
            "preparation_controller_sha256": amap["preparation_controller"]["sha256"],
            "compile_manifest_path": compile_binding["path"],
            "compile_manifest_sha256": compile_binding["sha256"],
            "compile_manifest_bytes": compile_binding["bytes"],
            "compile_source_commit": compile_binding["source_commit"],
            "compile_controller_path": compile_binding["compile_controller"]["path"],
            "compile_controller_sha256": compile_binding["compile_controller"]["sha256"],
            "runtime_source_artifacts": runtime_sources,
            "runtime_source_artifacts_sha256": runtime_sources_sha,
            "execution_input_artifacts": execution_inputs,
            "execution_input_artifacts_sha256": execution_inputs_sha,
            "execution_data_bundle_sha256": data_bundle_sha,
            "t10_terminal_binary_path": amap["t10_terminal_binary"]["path"],
            "t10_terminal_binary_sha256": amap["t10_terminal_binary"]["sha256"],
            "t10_metatester_binary_path": amap["t10_metatester_binary"]["path"],
            "t10_metatester_binary_sha256": amap["t10_metatester_binary"]["sha256"],
            "t10_symbol_spec_path": str(t10_bases / "symbols.custom.dat"),
            "t10_symbol_spec_sha256": amap["t10_symbol_spec"]["sha256"],
            "history_tick_window": {"from": FROM_DATE, "to": TO_DATE, "symbols": list(DATA_SYMBOLS)},
            "calendar_source_dir": str(calendar_source), "calendar_common_dir": str(calendar_common),
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
            "commission_per_lot": 0, "commission_per_side_native": 0,
            "ftmo_official_rules_snapshot_path": amap["ftmo_official_rules_snapshot"]["path"],
            "ftmo_official_rules_snapshot_sha256": amap["ftmo_official_rules_snapshot"]["sha256"],
            "ftmo_rulepack_path": amap["ftmo_rulepack"]["path"],
            "ftmo_rulepack_sha256": amap["ftmo_rulepack"]["sha256"],
            "isolated_only": True, "auto_enqueue": False, "auto_promote": False,
            "next_phase": None, "factory_on_authorized": False,
        }
        for key, expected in checks.items():
            if payload.get(key) != expected:
                raise ContractError(f"prepare operation {spec['code']} payload has invalid {key}")
        expected_identity = {
            "schema": "qm.ftmo-book3-q02-work-item/v1",
            "measurement_contract": FIDELITY_MEASUREMENT_CONTRACT,
            "evidence_vintage": EVIDENCE_VINTAGE,
            "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
            "code": spec["code"], "sequence": sequence, "ea_id": spec["ea_id"],
            "evidence_run_id": spec.get("evidence_run_id"),
            "required_fidelity_stage": required_fidelity_stage,
            "symbol": spec["symbol"], "period": spec["period"], "terminal": TERMINAL,
            "from_date": FROM_DATE, "to_date": TO_DATE,
            "source_commit": manifest["git"]["authoritative_source_commit"],
            "mq5_sha256": amap[f"mq5:{spec['ea_dir']}"]["sha256"],
            "setfile_sha256": amap[f"set:{spec['code']}"]["sha256"],
            "staged_ex5_sha256": spec["ex5_sha256"],
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
            "execution_input_artifacts_sha256": execution_inputs_sha,
            "execution_data_bundle_sha256": data_bundle_sha,
            "calendar_bundle_sha256": calendar_bundle_sha,
            "cost_bundle_sha256": cost_bundle_sha,
            "ftmo_official_rules_snapshot_sha256": amap["ftmo_official_rules_snapshot"]["sha256"],
            "ftmo_rulepack_sha256": amap["ftmo_rulepack"]["sha256"],
        }
        if execution_sha != canonical_sha(expected_identity):
            raise ContractError(f"prepare operation {spec['code']} has invalid execution bundle")
        if spec["basket_symbols"]:
            basket_checks = {
                "portfolio_scope": "basket", "host_symbol": "USDJPY.DWX",
                "basket_symbol_count": len(spec["basket_symbols"]), "basket_symbols": list(spec["basket_symbols"]),
            }
            for key, expected in basket_checks.items():
                if payload.get(key) != expected:
                    raise ContractError(f"prepare operation {spec['code']} payload has invalid {key}")
    if validate_live_source:
        semantic_errors = _semantic_source_errors(manifest)
        if semantic_errors:
            raise ContractError("; ".join(semantic_errors))


def _external_artifacts(
    artifact_root: Path, specs: tuple[dict[str, Any], ...],
) -> list[dict[str, Any]]:
    artifacts: list[dict[str, Any]] = []
    seen: set[str] = set()
    for spec in specs:
        ea_dir = str(spec["ea_dir"])
        if ea_dir in seen:
            continue
        seen.add(ea_dir)
        artifacts.append(_artifact(
            artifact_root / "canonical_staged_ex5" / f"{ea_dir}.ex5",
            f"canonical_staged_ex5:{ea_dir}", expected_sha256=str(spec["ex5_sha256"]),
        ))
        log = artifact_root / "canonical_compile_logs" / f"{ea_dir}.compile.log"
        item = _artifact(log, f"canonical_compile_log:{ea_dir}")
        raw = log.read_bytes() if log.is_file() else b""
        encoding = "utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) or b"\x00" in raw[:256] else "utf-8-sig"
        text = raw.decode(encoding, errors="replace")
        if item.get("valid") and "Result: 0 errors, 0 warnings" not in text:
            item.update({"valid": False, "reason": "compile_log_not_strict_pass"})
        artifacts.append(item)
    return artifacts


def _execution_data_artifacts(t10_bases: Path) -> list[dict[str, Any]]:
    t10_root = t10_bases.parent
    artifacts = [
        _artifact(t10_root / "terminal64.exe", "t10_terminal_binary"),
        _artifact(t10_root / "metatester64.exe", "t10_metatester_binary"),
        _artifact(t10_bases / "symbols.custom.dat", "t10_symbol_spec"),
    ]
    custom = t10_bases / "Custom"
    for symbol in DATA_SYMBOLS:
        for year in range(2018, 2026):
            artifacts.append(_artifact(
                custom / "history" / symbol / f"{year}.hcc",
                f"history:{symbol}:{year}",
            ))
        for year in range(2018, 2026):
            first_month = 7 if year == 2018 else 1
            for month in range(first_month, 13):
                artifacts.append(_artifact(
                    custom / "ticks" / symbol / f"{year}{month:02d}.tkc",
                    f"ticks:{symbol}:{year}{month:02d}",
                ))
    return artifacts


def _calendar_artifacts(source_dir: Path, common_dir: Path) -> list[dict[str, Any]]:
    artifacts = []
    for name in CALENDAR_FILES:
        artifacts.append(_artifact(source_dir / name, f"calendar_source:{name}"))
        artifacts.append(_artifact(common_dir / name, f"calendar_common:{name}"))
    return artifacts


def _rulepack_snapshot_errors(rulepack: Path, snapshot: Path) -> list[str]:
    try:
        document = json.loads(rulepack.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        return [f"FTMO rulepack parse failed: {exc}"]
    if not snapshot.is_file():
        return [f"FTMO official rules snapshot missing: {snapshot}"]
    expected_path = "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json"
    expected_sha = sha256_file(snapshot)
    sources = document.get("official_sources")
    if not isinstance(sources, list) or not sources:
        return ["FTMO rulepack official_sources must be a non-empty array"]
    errors = []
    for index, source in enumerate(sources):
        if not isinstance(source, dict):
            errors.append(f"FTMO rulepack official source {index} is not an object")
            continue
        if source.get("snapshot_path") != expected_path:
            errors.append(f"FTMO rulepack official source {index} snapshot_path mismatch")
        if source.get("snapshot_sha256") != expected_sha:
            errors.append(f"FTMO rulepack official source {index} snapshot_sha256 mismatch")
    return errors


def _artifact_bundle_sha(artifacts: list[dict[str, Any]], prefixes: tuple[str, ...]) -> str:
    rows = sorted([
        {"role": item["role"], "path": item["path"], "sha256": item.get("sha256"), "bytes": item.get("bytes")}
        for item in artifacts if str(item.get("role") or "").startswith(prefixes)
    ], key=lambda item: (str(item["role"]), str(item["path"])))
    return canonical_sha(rows)


def _required_execution_input_paths(
    *, repo: Path, t10_bases: Path, calendar_source: Path, calendar_common: Path,
) -> dict[str, str]:
    paths = {
        "t10_terminal_binary": str(t10_bases.parent / "terminal64.exe"),
        "t10_metatester_binary": str(t10_bases.parent / "metatester64.exe"),
        "t10_symbol_spec": str(t10_bases / "symbols.custom.dat"),
        "tester_cost_basis": str(repo / "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt"),
        "live_commission": str(repo / "framework/registry/live_commission.json"),
        "venue_cost_model": str(repo / "framework/registry/venue_cost_model.json"),
        "dwx_symbol_matrix": str(repo / "framework/registry/dwx_symbol_matrix.csv"),
        "ftmo_official_rules_snapshot": str(
            repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json"
        ),
        "ftmo_rulepack": str(repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json"),
    }
    custom = t10_bases / "Custom"
    for symbol in DATA_SYMBOLS:
        for year in range(2018, 2026):
            paths[f"history:{symbol}:{year}"] = str(custom / "history" / symbol / f"{year}.hcc")
        for year in range(2018, 2026):
            first_month = 7 if year == 2018 else 1
            for month in range(first_month, 13):
                paths[f"ticks:{symbol}:{year}{month:02d}"] = str(
                    custom / "ticks" / symbol / f"{year}{month:02d}.tkc"
                )
    for name in CALENDAR_FILES:
        paths[f"calendar_source:{name}"] = str(calendar_source / name)
        paths[f"calendar_common:{name}"] = str(calendar_common / name)
    return paths


def _required_execution_input_roles() -> set[str]:
    roles = {
        "t10_terminal_binary", "t10_metatester_binary", "t10_symbol_spec",
        *COST_ARTIFACT_ROLES, "ftmo_official_rules_snapshot", "ftmo_rulepack",
    }
    for symbol in DATA_SYMBOLS:
        roles.update(f"history:{symbol}:{year}" for year in range(2018, 2026))
        for year in range(2018, 2026):
            first_month = 7 if year == 2018 else 1
            roles.update(f"ticks:{symbol}:{year}{month:02d}" for month in range(first_month, 13))
    for name in CALENDAR_FILES:
        roles.update((f"calendar_source:{name}", f"calendar_common:{name}"))
    return roles


def _execution_input_artifacts(artifacts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Return the complete file-level runner input list in canonical order."""
    required_roles = _required_execution_input_roles()
    rows = [
        {
            "role": str(item["role"]),
            "path": str(item["path"]),
            "sha256": str(item["sha256"]),
            "bytes": int(item["bytes"]),
        }
        for item in artifacts
        if str(item.get("role") or "") in required_roles
        and item.get("valid") is True
        and item.get("sha256") is not None
        and item.get("bytes") is not None
    ]
    return sorted(rows, key=lambda item: (item["role"], item["path"]))


def _runtime_source_artifacts(artifacts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Return the exact transitive controller/worker source vintage."""
    by_role = _artifact_map(artifacts)
    rows: list[dict[str, Any]] = []
    for role in RUNTIME_SOURCE_ROLES:
        item = by_role.get(role)
        if (
            not isinstance(item, dict)
            or item.get("valid") is not True
            or item.get("sha256") is None
            or item.get("bytes") is None
        ):
            continue
        rows.append({
            "role": role,
            "path": str(item["path"]),
            "sha256": str(item["sha256"]),
            "bytes": int(item["bytes"]),
        })
    return sorted(rows, key=lambda item: (item["role"], item["path"]))


def _repo_artifacts(repo: Path, controller_path: Path) -> list[dict[str, Any]]:
    items = [
        _artifact(repo / PREREGISTRATION_REL, "preregistration"),
        _artifact(repo / "framework/registry/magic_numbers.csv", "magic_registry"),
        _artifact(repo / "framework/include/QM/QM_MagicResolver.mqh", "magic_resolver"),
        _tree_artifact(repo / "framework/include/QM", "framework_include_tree"),
        _artifact(controller_path, "preparation_controller"),
        _artifact(repo / COMPILE_CONTROLLER_REL, "compile_controller"),
        _artifact(repo / "tools/strategy_farm/terminal_worker.py", "terminal_worker"),
        _artifact(repo / "tools/strategy_farm/isolated_work_item_runner.py", "isolated_runner"),
        _artifact(repo / "tools/strategy_farm/farmctl.py", "farmctl"),
        _artifact(repo / "tools/strategy_farm/factory_mutation_lock.py", "factory_mutation_lock"),
        _artifact(repo / "framework/scripts/_phase_utils.py", "phase_utils"),
        _artifact(repo / "tools/strategy_farm/compare_joint_replay.py", "fidelity_comparator"),
        _artifact(repo / "framework/scripts/run_smoke.ps1", "run_smoke"),
        _artifact(repo / "tools/strategy_farm/qm_tasks.manifest.ps1", "qm_tasks_manifest"),
        _artifact(repo / "tools/strategy_farm/factory_process_scope.ps1", "factory_process_scope"),
        _artifact(repo / "tools/strategy_farm/ftmo_book3_fidelity_gate.py", "fidelity_gate"),
        _artifact(repo / "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt", "tester_cost_basis"),
        _artifact(repo / "framework/registry/live_commission.json", "live_commission"),
        _artifact(repo / "framework/registry/venue_cost_model.json", "venue_cost_model"),
        _artifact(repo / "framework/registry/dwx_symbol_matrix.csv", "dwx_symbol_matrix"),
        _artifact(
            repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json",
            "ftmo_official_rules_snapshot",
        ),
        _artifact(repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json", "ftmo_rulepack"),
    ]
    seen = set()
    for spec in RUN_SPECS:
        ea_dir = repo / "framework/EAs" / spec["ea_dir"]
        mq5 = ea_dir / f"{spec['ea_dir']}.mq5"
        setfile = ea_dir / "sets" / spec["set_name"]
        for path, role in ((mq5, f"mq5:{spec['ea_dir']}"), (setfile, f"set:{spec['code']}")):
            key = str(path).lower()
            if key not in seen:
                seen.add(key)
                items.append(_artifact(path, role))
    return items


def _artifact_map(artifacts: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(item["role"]): item for item in artifacts}


def _item_contract(
    spec: dict[str, Any], *, repo: Path, artifact_root: Path, report_root: Path,
    common_qm: Path, t10_bases: Path, calendar_source: Path, calendar_common: Path,
    git_identity: dict[str, Any], compile_binding: dict[str, Any],
    artifacts: list[dict[str, Any]], sequence: int,
) -> dict[str, Any]:
    amap = _artifact_map(artifacts)
    ea_dir = repo / "framework/EAs" / spec["ea_dir"]
    setfile = ea_dir / "sets" / spec["set_name"]
    staged = artifact_root / "canonical_staged_ex5" / f"{spec['ea_dir']}.ex5"
    execution_inputs = _execution_input_artifacts(artifacts)
    execution_inputs_sha = canonical_sha(execution_inputs)
    runtime_sources = _runtime_source_artifacts(artifacts)
    runtime_sources_sha = canonical_sha(runtime_sources)
    required_fidelity_stage = None if sequence < 2 else (sequence // 2) - 1
    data_bundle_sha = _artifact_bundle_sha(artifacts, ("t10_terminal_binary", "t10_metatester_binary", "t10_symbol_spec", "history:", "ticks:"))
    calendar_bundle_sha = _artifact_bundle_sha(artifacts, ("calendar_source:", "calendar_common:"))
    cost_bundle_sha = canonical_sha([
        {"role": role, "path": amap[role]["path"], "sha256": amap[role]["sha256"], "bytes": amap[role]["bytes"]}
        for role in COST_ARTIFACT_ROLES
    ])
    identity = {
        "schema": "qm.ftmo-book3-q02-work-item/v1",
        "measurement_contract": FIDELITY_MEASUREMENT_CONTRACT,
        "evidence_vintage": EVIDENCE_VINTAGE,
        "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
        "code": spec["code"], "sequence": sequence, "ea_id": spec["ea_id"],
        "evidence_run_id": spec.get("evidence_run_id"),
        "required_fidelity_stage": required_fidelity_stage,
        "symbol": spec["symbol"], "period": spec["period"], "terminal": TERMINAL,
        "from_date": FROM_DATE, "to_date": TO_DATE,
        "source_commit": git_identity["authoritative_source_commit"],
        "mq5_sha256": amap[f"mq5:{spec['ea_dir']}"]["sha256"],
        "setfile_sha256": amap[f"set:{spec['code']}"]["sha256"],
        "staged_ex5_sha256": spec["ex5_sha256"],
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
        "execution_input_artifacts_sha256": execution_inputs_sha,
        "execution_data_bundle_sha256": data_bundle_sha,
        "calendar_bundle_sha256": calendar_bundle_sha,
        "cost_bundle_sha256": cost_bundle_sha,
        "ftmo_official_rules_snapshot_sha256": amap["ftmo_official_rules_snapshot"]["sha256"],
        "ftmo_rulepack_sha256": amap["ftmo_rulepack"]["sha256"],
    }
    execution_sha = canonical_sha(identity)
    # MNT-046 process lineage accepts only a direct UUID leaf below
    # reports/work_items.  Make that UUID content-addressed while setting the
    # RFC-4122 version/variant bits deterministically.
    work_item_id = _content_uuid(execution_sha)
    evidence_root = report_root / work_item_id
    trade_source = common_qm / "q08_trades" / f"{str(spec['ea_id']).replace('QM5_', '')}_{str(spec['symbol']).replace('.', '_')}.jsonl"
    payload: dict[str, Any] = {
        "schema": "qm.ftmo-book3-q02-work-item-payload/v1",
        "measurement_contract": FIDELITY_MEASUREMENT_CONTRACT,
        "evidence_vintage": EVIDENCE_VINTAGE,
        "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
        "measurement_rung": spec["code"], "measurement_sequence": sequence,
        "evidence_run_id": spec.get("evidence_run_id"),
        "required_fidelity_stage": required_fidelity_stage,
        "execution_bundle_sha256": execution_sha,
        "authoritative_source_commit": git_identity["authoritative_source_commit"],
        "controller_head_commit": git_identity["controller_head_commit"],
        "terminal": TERMINAL, "avoid_terminals": list(FORBIDDEN_TERMINALS),
        "ea_dir_name": spec["ea_dir"], "host_timeframe": spec["period"],
        "expected_setfile_sha256": identity["setfile_sha256"],
        "expected_mq5_sha256": identity["mq5_sha256"],
        "staged_ex5_path": str(staged), "staged_ex5_sha256": spec["ex5_sha256"],
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
        "execution_input_artifacts_sha256": execution_inputs_sha,
        "execution_data_bundle_sha256": data_bundle_sha,
        "t10_terminal_binary_path": amap["t10_terminal_binary"]["path"],
        "t10_terminal_binary_sha256": amap["t10_terminal_binary"]["sha256"],
        "t10_metatester_binary_path": amap["t10_metatester_binary"]["path"],
        "t10_metatester_binary_sha256": amap["t10_metatester_binary"]["sha256"],
        "t10_symbol_spec_path": str(t10_bases / "symbols.custom.dat"),
        "t10_symbol_spec_sha256": amap["t10_symbol_spec"]["sha256"],
        "history_tick_window": {"from": FROM_DATE, "to": TO_DATE, "symbols": list(DATA_SYMBOLS)},
        "calendar_source_dir": str(calendar_source), "calendar_common_dir": str(calendar_common),
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
        "commission_per_lot": 0, "commission_per_side_native": 0,
        "ftmo_official_rules_snapshot_path": amap["ftmo_official_rules_snapshot"]["path"],
        "ftmo_official_rules_snapshot_sha256": identity["ftmo_official_rules_snapshot_sha256"],
        "ftmo_rulepack_path": amap["ftmo_rulepack"]["path"],
        "ftmo_rulepack_sha256": amap["ftmo_rulepack"]["sha256"],
        "from_year": 2018, "to_year": 2025, "from_date": FROM_DATE, "to_date": TO_DATE,
        "tester_currency": "USD", "tester_deposit": 100000, "timeout_min": 240,
        "risk_mode": "RISK_FIXED", "risk_fixed": 1000, "risk_percent": 0,
        "model": 4, "report_root": str(evidence_root),
        "post_run_file_common_source": str(trade_source),
        "post_run_file_common_streams": [],
        "isolated_only": True, "auto_enqueue": False, "auto_promote": False,
        "next_phase": None, "factory_on_authorized": False,
    }
    if spec["basket_symbols"]:
        payload.update({
            "portfolio_scope": "basket", "host_symbol": "USDJPY.DWX",
            "basket_symbol_count": len(spec["basket_symbols"]),
            "basket_symbols": list(spec["basket_symbols"]),
            "post_run_file_common_streams": [{
                "stream_type": "q08_equity",
                "source": str(common_qm / "q08_equity" / "20181_USDJPY_DWX.jsonl"),
            }],
        })
    return {
        "code": spec["code"], "sequence": sequence, "work_item_id": work_item_id,
        "kind": "backtest", "phase": "Q02", "ea_id": spec["ea_id"],
        "symbol": spec["symbol"], "setfile_path": str(setfile),
        "report_root": str(evidence_root), "execution_bundle_sha256": execution_sha,
        "payload_json": json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")),
        "hold": {"hold_code": HOLD_CODE, "reason": HOLD_REASON, "active": 1, "release_on_restart": 0},
    }


def build_prepare_plan(
    *, source_commit: str, joint_ex5_sha256: str | None = None,
    root: Path = DEFAULT_ROOT, repo: Path = DEFAULT_REPO,
    artifact_root: Path = DEFAULT_ARTIFACT_ROOT, report_root: Path = DEFAULT_REPORT_ROOT,
    common_qm: Path = DEFAULT_COMMON_QM, controller_path: Path | None = None,
    t10_bases: Path = DEFAULT_T10_BASES,
    calendar_source: Path = DEFAULT_CALENDAR_SOURCE,
    calendar_common: Path = DEFAULT_CALENDAR_COMMON,
) -> dict[str, Any]:
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise ContractError("source commit must be exactly 40 lowercase hexadecimal characters")
    controller_path = Path(controller_path or __file__).resolve()
    db = root / "state/farm_state.sqlite"
    flag = root / "state/FACTORY_OFF.flag"
    errors: list[str] = []
    errors.extend(_topology_errors(
        root=root, repo=repo, artifact_root=artifact_root,
        report_root=report_root, common_qm=common_qm,
        t10_bases=t10_bases, calendar_source=calendar_source,
        calendar_common=calendar_common, db=db, flag=flag,
    ))
    git_identity, git_errors = _git_identity(repo, controller_path, source_commit)
    errors.extend(git_errors)
    compile_binding: dict[str, Any] = {}
    ex5_by_ea: dict[str, str] = {}
    specs: tuple[dict[str, Any], ...] = ()
    try:
        compile_binding, ex5_by_ea = _load_compile_manifest(
            repo=repo,
            artifact_root=artifact_root,
            flag=flag,
            authoritative_source_commit=source_commit,
            supplied_joint_ex5_sha256=joint_ex5_sha256,
        )
        specs = _bound_run_specs(ex5_by_ea)
    except ContractError as exc:
        errors.append(f"COMPILE_MANIFEST_INVALID:{exc}")
    artifacts = (
        _repo_artifacts(repo, controller_path)
        + [_artifact(artifact_root / COMPILE_MANIFEST_NAME, "compile_manifest")]
        + _external_artifacts(artifact_root, specs)
        + _execution_data_artifacts(t10_bases)
        + _calendar_artifacts(calendar_source, calendar_common)
    )
    errors.extend(f"artifact invalid: {a['role']}:{a.get('reason', 'invalid')}" for a in artifacts if not a.get("valid"))
    errors.extend(_rulepack_snapshot_errors(
        repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json",
        repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json",
    ))
    artifact_roles = [str(item.get("role") or "") for item in artifacts]
    artifact_paths = [str(item.get("path") or "").casefold() for item in artifacts]
    if len(artifact_roles) != len(set(artifact_roles)):
        errors.append("ARTIFACT_DUPLICATE_ROLE: every plan artifact must occur exactly once")
    if len(artifact_paths) != len(set(artifact_paths)):
        errors.append("ARTIFACT_DUPLICATE_PATH: every plan artifact must occur exactly once")
    expected_input_paths = _required_execution_input_paths(
        repo=repo, t10_bases=t10_bases,
        calendar_source=calendar_source, calendar_common=calendar_common,
    )
    input_artifacts = _execution_input_artifacts(artifacts)
    if {item["role"] for item in input_artifacts} != set(expected_input_paths):
        errors.append("EXECUTION_INPUT_ARTIFACTS_INCOMPLETE: exact canonical input list unavailable")
    else:
        for item in input_artifacts:
            if item["path"] != expected_input_paths[item["role"]]:
                errors.append(f"EXECUTION_INPUT_PATH_MISMATCH:{item['role']}")
    calendar_preflight = _calendar_preflight(calendar_source, calendar_common)
    if calendar_preflight.get("ok") is not True:
        errors.append(
            "CALENDAR_BASIS_INVALID:"
            f"{calendar_preflight.get('status')}:{calendar_preflight.get('detail') or ''}"
        )
    for name in CALENDAR_FILES:
        source = next((a for a in artifacts if a["role"] == f"calendar_source:{name}"), {})
        common = next((a for a in artifacts if a["role"] == f"calendar_common:{name}"), {})
        if source.get("sha256") != common.get("sha256"):
            errors.append(f"CALENDAR_COPY_MISMATCH:{name}")
    for role in COST_ARTIFACT_ROLES:
        if not any(a.get("valid") for a in artifacts if a.get("role") == role):
            errors.append(f"COST_BASIS_UNRESOLVED:{role}")
    errors.extend(_registry_errors(repo / "framework/registry/magic_numbers.csv", repo / "framework/include/QM/QM_MagicResolver.mqh"))
    for spec in specs:
        errors.extend(_validate_set(spec, repo / "framework/EAs" / spec["ea_dir"] / "sets" / spec["set_name"]))
    if not flag.is_file():
        errors.append(f"FACTORY_OFF missing: {flag}")
    if not db.is_file():
        errors.append(f"farm database missing: {db}")
    processes = _factory_processes()
    if processes:
        errors.append(f"factory process census is not empty: {len(processes)}")
    operations: list[dict[str, Any]] = []
    if not any(not a.get("valid") for a in artifacts) and not git_errors:
        operations = [
            _item_contract(spec, repo=repo, artifact_root=artifact_root, report_root=report_root,
                           common_qm=common_qm, t10_bases=t10_bases,
                           calendar_source=calendar_source, calendar_common=calendar_common,
                           git_identity=git_identity, compile_binding=compile_binding,
                           artifacts=artifacts, sequence=index)
            for index, spec in enumerate(specs)
        ]
    db_state = None
    if db.is_file():
        try:
            with connect_ro(db) as conn:
                errors.extend(_schema_errors(conn))
                if operations:
                    ids = [op["work_item_id"] for op in operations]
                    marks = ",".join("?" for _ in ids)
                    existing = conn.execute(f"SELECT id FROM work_items WHERE id IN ({marks})", ids).fetchall()
                    existing_holds = conn.execute(f"SELECT work_item_id FROM work_item_holds WHERE work_item_id IN ({marks})", ids).fetchall()
                    if existing:
                        errors.append(f"planned work items already exist: {[r[0] for r in existing]}")
                    if existing_holds:
                        errors.append(f"planned holds already exist: {[r[0] for r in existing_holds]}")
            db_state = sqlite_state_sha256(db)
        except Exception as exc:
            errors.append(f"database preflight failed: {exc}")
    for operation in operations:
        if Path(operation["report_root"]).exists():
            errors.append(f"report root already exists: {operation['report_root']}")
    if errors:
        operations = []
    plan = {
        "schema": SCHEMA_PREPARE, "mode": "dry_run", "generated_at_utc": utc_now(),
        "root": str(root), "repo": str(repo), "artifact_root": str(artifact_root),
        "report_root": str(report_root), "common_qm": str(common_qm), "terminal": TERMINAL,
        "joint_ex5_sha256": ex5_by_ea.get("QM5_20181"),
        "compiled_ex5_sha256_by_ea": ex5_by_ea,
        "compile_manifest": compile_binding,
        "t10_bases": str(t10_bases), "calendar_source": str(calendar_source),
        "calendar_common": str(calendar_common), "calendar_preflight": calendar_preflight,
        "factory_off": {"path": str(flag), "sha256": sha256_file(flag) if flag.is_file() else None},
        "db": {"path": str(db), "logical_state_sha256": db_state},
        "git": git_identity, "artifacts": artifacts, "factory_processes": processes,
        "controller_artifacts": {
            role: {
                "path": _artifact_map(artifacts)[role]["path"],
                "sha256": _artifact_map(artifacts)[role]["sha256"],
                "bytes": _artifact_map(artifacts)[role]["bytes"],
            }
            for role in (
                "preparation_controller", "isolated_runner", "terminal_worker",
                "compile_manifest",
            )
        },
        "execution_input_artifacts_sha256": canonical_sha(input_artifacts),
        "runtime_source_artifacts_sha256": canonical_sha(
            _runtime_source_artifacts(artifacts)
        ),
        "operation_count": len(operations), "operations": operations,
        "safety": {"factory_remains_off": True, "runs_mt5": False, "auto_enqueue": False, "auto_promote": False},
        "valid": not errors and len(operations) == 6, "errors": errors,
    }
    _assign_plan_id(plan)
    return plan


def _verify_artifacts(manifest: dict[str, Any]) -> None:
    for artifact in manifest.get("artifacts") or []:
        path = Path(str(artifact["path"]))
        if artifact.get("file_count") is not None:
            current = _tree_artifact(path, str(artifact["role"]))
        else:
            current = _artifact(path, str(artifact["role"]))
        if not current.get("valid") or current.get("sha256") != artifact.get("sha256"):
            raise ContractError(f"artifact drift: {artifact['role']}")


def _semantic_source_errors(manifest: dict[str, Any]) -> list[str]:
    """Recompute authorization semantics from the currently bound bytes."""
    repo = Path(str(manifest["repo"]))
    errors: list[str] = []
    try:
        compile_binding, ex5_by_ea = _load_compile_manifest(
            repo=repo,
            artifact_root=Path(str(manifest["artifact_root"])),
            flag=Path(str(manifest["factory_off"]["path"])),
            authoritative_source_commit=str(manifest["git"]["authoritative_source_commit"]),
            supplied_joint_ex5_sha256=str(manifest.get("joint_ex5_sha256") or ""),
        )
        if manifest.get("compile_manifest") != compile_binding:
            errors.append("compile-manifest binding drifted")
        if manifest.get("compiled_ex5_sha256_by_ea") != ex5_by_ea:
            errors.append("compiled EX5 map drifted")
        specs = _bound_run_specs(ex5_by_ea)
    except ContractError as exc:
        return [f"compile manifest invalid: {exc}"]
    errors.extend(_registry_errors(
        repo / "framework/registry/magic_numbers.csv",
        repo / "framework/include/QM/QM_MagicResolver.mqh",
    ))
    for spec in specs:
        errors.extend(_validate_set(
            spec,
            repo / "framework/EAs" / spec["ea_dir"] / "sets" / spec["set_name"],
        ))
    errors.extend(_rulepack_snapshot_errors(
        repo / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json",
        repo / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json",
    ))
    current_external = _external_artifacts(Path(manifest["artifact_root"]), specs)
    errors.extend(
        f"runtime compile artifact invalid: {item['role']}:{item.get('reason', 'invalid')}"
        for item in current_external
        if item.get("valid") is not True
    )
    controller_path = repo / "tools/strategy_farm/prepare_ftmo_book3_q02.py"
    current_git, git_errors = _git_identity(
        repo,
        controller_path,
        str(manifest["git"]["authoritative_source_commit"]),
    )
    errors.extend(git_errors)
    if current_git.get("controller_head_commit") != manifest["git"].get(
        "controller_head_commit"
    ):
        errors.append("controller Git HEAD differs from manifest")
    return errors


def _assert_equal(label: str, expected: Any, actual: Any) -> None:
    if str(expected).lower() != str(actual).lower():
        raise ContractError(f"{label} mismatch: expected={expected} actual={actual}")


def _path_identity(path: Path) -> str:
    return os.path.normcase(os.path.abspath(str(path)))


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


def _validate_manifest_topology(manifest: dict[str, Any]) -> None:
    root = Path(str(manifest.get("root") or ""))
    values = {
        "repo": Path(str(manifest.get("repo") or "")),
        "artifact_root": Path(str(manifest.get("artifact_root") or "")),
        "report_root": Path(str(manifest.get("report_root") or "")),
        "common_qm": Path(str(manifest.get("common_qm") or "")),
        "t10_bases": Path(str(manifest.get("t10_bases") or "")),
        "calendar_source": Path(str(manifest.get("calendar_source") or "")),
        "calendar_common": Path(str(manifest.get("calendar_common") or "")),
        "db": Path(str((manifest.get("db") or {}).get("path") or "")),
        "flag": Path(str((manifest.get("factory_off") or {}).get("path") or "")),
    }
    errors = _topology_errors(root=root, **values)
    if errors:
        raise ContractError("; ".join(errors))


def _write_new_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2, ensure_ascii=False, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        try:
            os.link(temporary, path)
        except FileExistsError as exc:
            raise ContractError(f"JSON target already exists: {path}") from exc
    finally:
        temporary.unlink(missing_ok=True)


def _intent_path(receipt_path: Path) -> Path:
    return receipt_path.with_name(receipt_path.name + ".intent.json")


def _reserve_mutation_outputs(
    *, action: str, plan_id: str, manifest_path: Path, manifest_sha256: str,
    snapshot_path: Path, receipt_path: Path, db_path: Path, flag_path: Path,
) -> tuple[Path, str]:
    intent_path = _intent_path(receipt_path)
    paths = [snapshot_path, receipt_path, intent_path]
    identities = [_path_identity(path) for path in paths]
    if len(identities) != len(set(identities)):
        raise ContractError("snapshot, receipt, and intent paths must be distinct")
    existing = [str(path) for path in paths if path.exists()]
    if existing:
        raise ContractError(f"reserved output target already exists: {existing}")
    intent = {
        "schema": "qm.ftmo-book3-q02-mutation-intent/v1",
        "status": "INTENT_CREATED",
        "action": action,
        "created_at_utc": utc_now(),
        "plan_id": plan_id,
        "manifest_path": str(manifest_path),
        "manifest_sha256": manifest_sha256,
        "snapshot_path": str(snapshot_path),
        "receipt_path": str(receipt_path),
        "db_path": str(db_path),
        "factory_off_path": str(flag_path),
        "recovery_required_if_final_receipt_missing": True,
    }
    _write_new_json(intent_path, intent)
    return intent_path, sha256_file(intent_path)


def _load_manifest(path: Path, expected_sha256: str, schema: str) -> tuple[dict[str, Any], str]:
    actual_sha = sha256_file(path)
    _assert_equal("manifest SHA-256", expected_sha256, actual_sha)
    manifest = json.loads(path.read_text(encoding="utf-8-sig"))
    if manifest.get("schema") != schema or manifest.get("valid") is not True:
        raise ContractError("manifest schema/validity mismatch")
    _validate_plan_id(manifest)
    return manifest, actual_sha


def apply_prepare(
    *, manifest_path: Path, expected_manifest_sha256: str, confirm_plan_id: str,
    expected_factory_off_sha256: str, expected_db_state_sha256: str,
    expected_source_commit: str, snapshot_path: Path, receipt_path: Path,
) -> dict[str, Any]:
    manifest, manifest_sha = _load_manifest(manifest_path, expected_manifest_sha256, SCHEMA_PREPARE)
    _assert_equal("confirmed plan id", confirm_plan_id, manifest["plan_id"])
    _assert_equal("FACTORY_OFF argument", expected_factory_off_sha256, manifest["factory_off"]["sha256"])
    _assert_equal("DB state argument", expected_db_state_sha256, manifest["db"]["logical_state_sha256"])
    _assert_equal("source commit argument", expected_source_commit, manifest["git"]["authoritative_source_commit"])
    _validate_prepare_operations(manifest)
    db = Path(manifest["db"]["path"])
    flag = Path(manifest["factory_off"]["path"])
    lock_path = path_for_factory_flag(flag)
    intent_path, intent_sha = _reserve_mutation_outputs(
        action="prepare",
        plan_id=manifest["plan_id"],
        manifest_path=manifest_path,
        manifest_sha256=manifest_sha,
        snapshot_path=snapshot_path,
        receipt_path=receipt_path,
        db_path=db,
        flag_path=flag,
    )
    with FactoryMutationLock(lock_path, owner=f"ftmo_book3_q02_prepare:{manifest['plan_id']}"):
        _assert_equal("FACTORY_OFF SHA-256", expected_factory_off_sha256, sha256_file(flag))
        _assert_equal("DB logical state", expected_db_state_sha256, sqlite_state_sha256(db))
        _assert_equal("controller Git HEAD", manifest["git"]["controller_head_commit"], _git(Path(manifest["repo"]), "rev-parse", "HEAD"))
        _assert_equal("source commit", expected_source_commit, _git(Path(manifest["repo"]), "rev-parse", f"{expected_source_commit}^{{commit}}"))
        _verify_artifacts(manifest)
        semantic_errors = _semantic_source_errors(manifest)
        if semantic_errors:
            raise ContractError("; ".join(semantic_errors))
        calendar_preflight = _calendar_preflight(
            Path(manifest["calendar_source"]), Path(manifest["calendar_common"])
        )
        if calendar_preflight.get("ok") is not True:
            raise ContractError(
                "calendar preflight failed immediately before prepare apply: "
                f"{calendar_preflight.get('status')}:{calendar_preflight.get('detail') or ''}"
            )
        if _factory_processes():
            raise ContractError("factory process census is not empty")
        snapshot_sha = sqlite_snapshot(db, snapshot_path)
        _assert_equal("DB state after snapshot", expected_db_state_sha256, sqlite_state_sha256(db))
        applied_at = utc_now()
        conn = sqlite3.connect(db, timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("PRAGMA busy_timeout=30000")
            conn.execute("BEGIN IMMEDIATE")
            _assert_equal("transaction DB preimage", expected_db_state_sha256, hashlib.sha256(conn.serialize()).hexdigest())
            schema_errors = _schema_errors(conn)
            if schema_errors:
                raise ContractError("; ".join(schema_errors))
            for operation in manifest["operations"]:
                if Path(operation["report_root"]).exists():
                    raise ContractError(f"report root already exists: {operation['report_root']}")
                work_id = operation["work_item_id"]
                if conn.execute("SELECT 1 FROM work_items WHERE id=?", (work_id,)).fetchone():
                    raise ContractError(f"work item absence CAS failed: {work_id}")
                if conn.execute("SELECT 1 FROM work_item_holds WHERE work_item_id=?", (work_id,)).fetchone():
                    raise ContractError(f"hold absence CAS failed: {work_id}")
                cur = conn.execute(
                    """INSERT INTO work_items
                    (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,parent_task_id,
                     evidence_path,claimed_by,payload_json,created_at,updated_at)
                    SELECT ?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?
                    WHERE NOT EXISTS (SELECT 1 FROM work_items WHERE id=?)""",
                    (work_id, operation["kind"], operation["phase"], operation["ea_id"], operation["symbol"],
                     operation["setfile_path"], operation["payload_json"], applied_at, applied_at, work_id),
                )
                if cur.rowcount != 1:
                    raise ContractError(f"work item insert CAS failed: {work_id}")
                hold = operation["hold"]
                cur = conn.execute(
                    """INSERT INTO work_item_holds
                    (work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note)
                    SELECT ?,?,?,1,0,?,?,NULL,NULL
                    WHERE NOT EXISTS (SELECT 1 FROM work_item_holds WHERE work_item_id=?)""",
                    (work_id, hold["hold_code"], hold["reason"], applied_at, applied_at, work_id),
                )
                if cur.rowcount != 1:
                    raise ContractError(f"hold insert CAS failed: {work_id}")
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()
        _assert_equal("FACTORY_OFF post SHA-256", expected_factory_off_sha256, sha256_file(flag))
        _verify_artifacts(manifest)
        post_state = sqlite_state_sha256(db)
        with connect_ro(db) as verify:
            post_rows = [dict(verify.execute(
                "SELECT id,status,verdict,claimed_by,created_at,updated_at FROM work_items WHERE id=?", (op["work_item_id"],)
            ).fetchone()) for op in manifest["operations"]]
            post_holds = [dict(verify.execute(
                "SELECT work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note "
                "FROM work_item_holds WHERE work_item_id=?", (op["work_item_id"],)
            ).fetchone()) for op in manifest["operations"]]
        receipt = {
            "schema": SCHEMA_RECEIPT, "action": "prepare", "mode": "apply",
            "receipt_id": f"ftmo-book3-q02-prepare-{manifest['plan_id']}",
            "applied_at_utc": applied_at, "plan_id": manifest["plan_id"],
            "manifest_path": str(manifest_path), "manifest_sha256": manifest_sha,
            "mutation_intent": {"path": str(intent_path), "sha256": intent_sha},
            "factory_off_sha256": expected_factory_off_sha256.lower(),
            "pre_db_state_sha256": expected_db_state_sha256.lower(), "post_db_state_sha256": post_state,
            "snapshot": {"path": str(snapshot_path), "sha256": snapshot_sha},
            "controller_artifacts": manifest["controller_artifacts"],
            "execution_input_artifacts_sha256": manifest["execution_input_artifacts_sha256"],
            "created_work_items": post_rows, "created_holds": post_holds,
            "factory_remains_off": flag.is_file(), "runs_mt5": False,
        }
        _write_new_json(receipt_path, receipt)
        return receipt


def _fidelity_adjudication_identity(receipt: dict[str, Any]) -> dict[str, Any]:
    identity = copy.deepcopy(receipt)
    identity.pop("generated_at_utc", None)
    identity.pop("adjudication_id", None)
    return identity


def _fidelity_adjudication_id(receipt: dict[str, Any]) -> str:
    return canonical_sha(_fidelity_adjudication_identity(receipt))


def _bound_runtime_artifact(manifest: dict[str, Any], role: str) -> dict[str, Any]:
    matches = [
        item for item in manifest.get("artifacts") or []
        if item.get("role") == role
    ]
    if len(matches) != 1:
        raise ContractError(f"fidelity runtime artifact must occur exactly once: {role}")
    item = matches[0]
    if item.get("valid") is not True:
        raise ContractError(f"fidelity runtime artifact is invalid: {role}")
    path = Path(str(item.get("path") or ""))
    if not path.is_absolute() or not path.is_file():
        raise ContractError(f"fidelity runtime artifact is not an absolute regular file: {role}")
    try:
        resolved = path.resolve(strict=True)
        path_stat = path.lstat()
        data = path.read_bytes()
    except OSError as exc:
        raise ContractError(f"fidelity runtime artifact is unavailable: {role}: {exc}") from exc
    if path.is_symlink() or _is_reparse_point(path_stat) or not stat.S_ISREG(path_stat.st_mode):
        raise ContractError(f"fidelity runtime artifact is aliased or non-regular: {role}")
    actual_sha = hashlib.sha256(data).hexdigest()
    expected_sha = str(item.get("sha256") or "")
    expected_bytes = item.get("bytes")
    if actual_sha != expected_sha or len(data) != expected_bytes:
        raise ContractError(f"fidelity runtime artifact drift: {role}")
    return {
        "role": role,
        "path": str(resolved),
        "sha256": actual_sha,
        "bytes": len(data),
    }


def _require_fidelity_equal(label: str, expected: Any, actual: Any) -> None:
    def typed_equal(left: Any, right: Any) -> bool:
        if type(left) is not type(right):
            return False
        if isinstance(left, dict):
            return set(left) == set(right) and all(
                typed_equal(left[key], right[key]) for key in left
            )
        if isinstance(left, list):
            return len(left) == len(right) and all(
                typed_equal(a, b) for a, b in zip(left, right)
            )
        return left == right

    if not typed_equal(expected, actual):
        raise ContractError(
            f"fidelity adjudication {label} mismatch: expected={expected!r} actual={actual!r}"
        )


def _require_exact_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ContractError(f"{label} must be an object")
    if set(value) != expected:
        raise ContractError(
            f"{label} keyset mismatch: missing={sorted(expected - set(value))} "
            f"extra={sorted(set(value) - expected)}"
        )
    return value


def _fidelity_operand_spec(stage: int, role: str) -> dict[str, Any]:
    rows = {
        0: {
            "standalone": ("R0", 0, 99360000, "USDJPY.DWX", "9936_USDJPY_DWX"),
            "joint": ("J0", 1, 201810000, "USDJPY.DWX", "20181_USDJPY_DWX"),
        },
        1: {
            "standalone": ("R1", 2, 101450034, "XAUUSD.DWX", "10145_XAUUSD_DWX"),
            "joint": ("J1", 3, 201810001, "XAUUSD.DWX", "20181_USDJPY_DWX"),
        },
        2: {
            "standalone": ("R2", 4, 131080000, "XTIUSD.DWX", "13108_XTIUSD_DWX"),
            "joint": ("J2", 5, 201810002, "XTIUSD.DWX", "20181_USDJPY_DWX"),
        },
    }
    rung, sequence, magic, symbol, source_stem = rows[stage][role]
    return {
        "role": role, "rung": rung, "sequence": sequence,
        "magic": magic, "symbol": symbol, "source_stem": source_stem,
    }


def _validate_fidelity_operand(
    *, operand: Any, stage: int, role: str, operation: dict[str, Any],
    manifest: dict[str, Any], artifacts: dict[str, dict[str, Any]],
    expected_work_payload_sha256: str,
) -> dict[str, Any]:
    label = f"stage {stage} {role} operand"
    expected_keys = {
        "role", "rung", "sequence", "receipt_path", "receipt_sha256",
        "work_item_id", "started_at_utc", "completed_at_utc", "source_commit",
        "factory_off_sha256", "source_binding", "runner_artifacts",
        "execution_input_artifacts_sha256", "execution_input_observed_bundle_sha256",
        "post_payload_sha256", "post_evidence", "q08_trades", "magic", "symbol",
        "execution_input_artifact_count",
    }
    row = _require_exact_keys(operand, expected_keys, label)
    spec = _fidelity_operand_spec(stage, role)
    for key in ("role", "rung", "sequence", "magic", "symbol"):
        _require_fidelity_equal(f"{label}.{key}", spec[key], row.get(key))
    _require_fidelity_equal(f"{label}.work_item_id", operation["work_item_id"], row.get("work_item_id"))
    _require_fidelity_equal(
        f"{label}.source_commit",
        manifest["git"]["authoritative_source_commit"], row.get("source_commit"),
    )
    _require_fidelity_equal(
        f"{label}.factory_off_sha256", manifest["factory_off"]["sha256"],
        row.get("factory_off_sha256"),
    )
    _require_fidelity_equal(
        f"{label}.execution_input_artifacts_sha256",
        manifest["execution_input_artifacts_sha256"],
        row.get("execution_input_artifacts_sha256"),
    )
    _require_fidelity_equal(f"{label}.execution_input_artifact_count", 307, row.get("execution_input_artifact_count"))
    observed = row.get("execution_input_observed_bundle_sha256")
    if not isinstance(observed, str) or not re.fullmatch(r"[0-9a-f]{64}", observed):
        raise ContractError(f"{label} observed execution-input identity is invalid")
    try:
        started = dt.datetime.fromisoformat(str(row.get("started_at_utc")))
        completed = dt.datetime.fromisoformat(str(row.get("completed_at_utc")))
    except ValueError as exc:
        raise ContractError(f"{label} timestamps are invalid") from exc
    if started.tzinfo is None or completed.tzinfo is None or started >= completed:
        raise ContractError(f"{label} timestamps are not an ordered timezone-aware interval")

    receipt_path = Path(str(row.get("receipt_path") or ""))
    resolved_receipt, receipt_raw, receipt_sha, _ = _read_unaliased_regular_file_once(
        receipt_path, f"{label} isolated-runner receipt"
    )
    _require_fidelity_equal(f"{label}.receipt_path", str(resolved_receipt), row.get("receipt_path"))
    _require_fidelity_equal(f"{label}.receipt_sha256", receipt_sha, row.get("receipt_sha256"))
    if len(receipt_raw) <= 0:
        raise ContractError(f"{label} isolated-runner receipt is empty")
    runner_receipt = _strict_json_object(
        receipt_raw, f"{label} isolated-runner receipt"
    )
    runner_post_payload_sha = runner_receipt.get("post_payload_sha256")
    if not isinstance(runner_post_payload_sha, str) or not re.fullmatch(
        r"[0-9a-f]{64}", runner_post_payload_sha
    ):
        raise ContractError(f"{label} runner post_payload_sha256 is invalid")
    _require_fidelity_equal(
        f"{label}.runner post_payload_sha256",
        expected_work_payload_sha256, runner_post_payload_sha,
    )
    _require_fidelity_equal(
        f"{label}.post_payload_sha256",
        runner_post_payload_sha, row.get("post_payload_sha256"),
    )

    runtime_rows = _runtime_source_artifacts(manifest.get("artifacts") or [])
    expected_runtime_roles = {
        item["role"]: {
            "role": item["role"], "path": item["path"],
            "sha256": item["sha256"], "bytes": item["bytes"],
        }
        for item in runtime_rows
    }
    expected_runtime = {
        "canonical_sha256": canonical_sha(runtime_rows),
        "roles": expected_runtime_roles,
    }
    binding = _require_exact_keys(
        row.get("source_binding"),
        {
            "framework_include_tree", "preregistration", "isolated_runner",
            "terminal_worker", "preparation_controller", "runtime_sources",
        },
        f"{label}.source_binding",
    )
    expected_direct: dict[str, Any] = {
        "framework_include_tree": {
            "path": os.path.normcase(os.path.abspath(artifacts["framework_include_tree"]["path"])),
            "sha256": artifacts["framework_include_tree"]["sha256"],
            "file_count": artifacts["framework_include_tree"]["file_count"],
        }
    }
    for key in ("preregistration", "isolated_runner", "terminal_worker", "preparation_controller"):
        expected_direct[key] = {
            "path": os.path.normcase(os.path.abspath(artifacts[key]["path"])),
            "sha256": artifacts[key]["sha256"],
        }
    for key, expected in expected_direct.items():
        _require_fidelity_equal(f"{label}.source_binding.{key}", expected, binding.get(key))
    _require_fidelity_equal(f"{label}.source_binding.runtime_sources", expected_runtime, binding.get("runtime_sources"))

    run_artifacts = _require_exact_keys(
        row.get("runner_artifacts"), {"setfile", "staged_ex5", "mq5"},
        f"{label}.runner_artifacts",
    )
    payload = json.loads(operation["payload_json"])
    expected_runner_artifacts = {
        "setfile": {"path": os.path.normcase(os.path.abspath(operation["setfile_path"])), "sha256": payload["expected_setfile_sha256"]},
        "staged_ex5": {"path": os.path.normcase(os.path.abspath(payload["staged_ex5_path"])), "sha256": payload["staged_ex5_sha256"]},
        "mq5": {
            "path": os.path.normcase(os.path.abspath(str(Path(manifest["repo"]) / "framework/EAs" / payload["ea_dir_name"] / f"{payload['ea_dir_name']}.mq5"))),
            "sha256": payload["expected_mq5_sha256"],
        },
    }
    _require_fidelity_equal(f"{label}.runner_artifacts", expected_runner_artifacts, run_artifacts)

    evidence = _require_exact_keys(
        row.get("post_evidence"), {"path", "resolved_path", "sha256", "bytes"},
        f"{label}.post_evidence",
    )
    evidence_path = Path(str(evidence.get("path") or ""))
    resolved_evidence, evidence_raw, evidence_sha, _ = _read_unaliased_regular_file_once(
        evidence_path, f"{label} post evidence"
    )
    for key, expected in {
        "resolved_path": str(resolved_evidence), "sha256": evidence_sha, "bytes": len(evidence_raw),
    }.items():
        _require_fidelity_equal(f"{label}.post_evidence.{key}", expected, evidence.get(key))

    q08 = _require_exact_keys(
        row.get("q08_trades"),
        {"source", "target", "path", "sha256", "bytes", "lines", "selected_trade_count"},
        f"{label}.q08_trades",
    )
    _require_fidelity_equal(f"{label}.q08_trades.source", payload["post_run_file_common_source"], q08.get("source"))
    expected_target = Path(operation["report_root"]) / f"q08_trades_{spec['source_stem']}.timer_v2.jsonl"
    _require_exact_path(q08.get("target"), expected_target, f"{label} q08 target")
    q08_path = Path(str(q08.get("path") or ""))
    resolved_q08, q08_raw, q08_sha, _ = _read_unaliased_regular_file_once(q08_path, f"{label} q08 trades")
    _require_fidelity_equal(f"{label}.q08 target/path", _path_identity(expected_target), _path_identity(resolved_q08))
    expected_q08 = {
        "sha256": q08_sha, "bytes": len(q08_raw), "lines": len(q08_raw.splitlines()),
    }
    for key, expected in expected_q08.items():
        _require_fidelity_equal(f"{label}.q08_trades.{key}", expected, q08.get(key))
    selected = q08.get("selected_trade_count")
    if isinstance(selected, bool) or not isinstance(selected, int) or selected <= 0:
        raise ContractError(f"{label} selected trade count must be a positive integer")
    return {
        "started": started, "completed": completed, "selected_trade_count": selected,
        "observed_execution_identity": observed,
    }


def _validate_fidelity_receipt(
    *, stage: int, path: Path, manifest: dict[str, Any],
    expected_work_item_ids: list[str],
    current_work_payload_sha256_by_id: dict[str, str],
) -> tuple[dict[str, Any], tuple[int, int]]:
    label = f"stage {stage} fidelity receipt"
    resolved, raw, receipt_sha, file_identity = _read_unaliased_regular_file_once(path, label)
    receipt = _strict_json_object(raw, label)
    _require_exact_keys(
        receipt,
        {
            "schema", "generated_at_utc", "stage", "verdict", "work_item_ids",
            "source_commit", "execution_input_artifacts_sha256", "controller_path",
            "controller_sha256", "controller_bytes", "isolated_runner_sha256",
            "preparation_controller_sha256", "comparator_sha256", "errors",
            "contract", "safety", "comparator", "operands", "comparison",
            "adjudication_id",
        },
        label,
    )
    _require_fidelity_equal("schema", SCHEMA_FIDELITY, receipt.get("schema"))
    generated = receipt.get("generated_at_utc")
    if not isinstance(generated, str):
        raise ContractError(f"{label} generated_at_utc must be a string")
    try:
        generated_time = dt.datetime.fromisoformat(generated)
    except ValueError as exc:
        raise ContractError(f"{label} generated_at_utc is invalid") from exc
    if generated_time.tzinfo is None:
        raise ContractError(f"{label} generated_at_utc must be timezone-aware")
    if isinstance(receipt.get("stage"), bool) or not isinstance(receipt.get("stage"), int):
        raise ContractError(f"{label} stage must be an integer")
    _require_fidelity_equal("stage", stage, receipt.get("stage"))
    _require_fidelity_equal("verdict", "PASS", receipt.get("verdict"))
    _require_fidelity_equal("errors", [], receipt.get("errors"))
    pair_offset = stage * 2
    expected_pair = {
        "standalone": expected_work_item_ids[pair_offset],
        "joint": expected_work_item_ids[pair_offset + 1],
    }
    _require_fidelity_equal("work_item_ids", expected_pair, receipt.get("work_item_ids"))
    _require_fidelity_equal(
        "source_commit",
        manifest["git"]["authoritative_source_commit"],
        receipt.get("source_commit"),
    )
    _require_fidelity_equal(
        "execution_input_artifacts_sha256",
        manifest["execution_input_artifacts_sha256"],
        receipt.get("execution_input_artifacts_sha256"),
    )

    gate = _bound_runtime_artifact(manifest, "fidelity_gate")
    runner = _bound_runtime_artifact(manifest, "isolated_runner")
    preparation = _bound_runtime_artifact(manifest, "preparation_controller")
    comparator = _bound_runtime_artifact(manifest, "fidelity_comparator")
    _require_fidelity_equal("controller_path", gate["path"], receipt.get("controller_path"))
    _require_fidelity_equal("controller_sha256", gate["sha256"], receipt.get("controller_sha256"))
    _require_fidelity_equal("controller_bytes", gate["bytes"], receipt.get("controller_bytes"))
    _require_fidelity_equal(
        "isolated_runner_sha256", runner["sha256"], receipt.get("isolated_runner_sha256")
    )
    _require_fidelity_equal(
        "preparation_controller_sha256",
        preparation["sha256"],
        receipt.get("preparation_controller_sha256"),
    )
    _require_fidelity_equal(
        "comparator_sha256", comparator["sha256"], receipt.get("comparator_sha256")
    )
    comparator_receipt = _require_exact_keys(
        receipt.get("comparator"), {"path", "sha256", "bytes"},
        f"{label} comparator",
    )
    for key in ("path", "sha256", "bytes"):
        _require_fidelity_equal(
            f"comparator.{key}", comparator[key], comparator_receipt.get(key)
        )

    expected_contract = {
        "measurement_contract": FIDELITY_MEASUREMENT_CONTRACT,
        "expected_execution_input_count": len(_required_execution_input_roles()),
        "match_rate_required": 1.0,
        "unmatched_required": 0,
        "both_operands_nonempty": True,
        "money_tolerance": 0.005,
        "volume_tolerance": 0.005,
        "price_tolerance": 0.0,
        "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
    }
    contract = _require_exact_keys(receipt.get("contract"), set(expected_contract), f"{label} contract")
    _require_fidelity_equal("contract", expected_contract, contract)
    expected_safety = {
        "read_only_inputs": True,
        "create_only_output": True,
        "opens_factory_db": False,
        "runs_mt5": False,
        "mutates_factory_state": False,
        "touches_live_scope": False,
        "touches_autotrading": False,
    }
    safety = _require_exact_keys(receipt.get("safety"), set(expected_safety), f"{label} safety")
    _require_fidelity_equal("safety", expected_safety, safety)

    comparison = _require_exact_keys(
        receipt.get("comparison"),
        {
            "algorithm", "money_basis", "money_tolerance", "volume_tolerance",
            "price_tolerance", "standalone_trades", "joint_trades", "matched",
            "unmatched_standalone", "unmatched_joint", "match_rate",
            "unmatched_standalone_sample", "unmatched_joint_sample",
        },
        f"{label} comparison",
    )
    _require_fidelity_equal(
        "comparison.algorithm",
        FIDELITY_COMPARISON_ALGORITHM,
        comparison.get("algorithm"),
    )
    _require_fidelity_equal(
        "comparison.money_basis",
        FULL_LIFECYCLE_MONEY_BASIS,
        comparison.get("money_basis"),
    )
    for key, expected in {
        "money_tolerance": 0.005,
        "volume_tolerance": 0.005,
        "price_tolerance": 0.0,
        "unmatched_standalone": 0,
        "unmatched_joint": 0,
        "match_rate": 1.0,
    }.items():
        _require_fidelity_equal(f"comparison.{key}", expected, comparison.get(key))
    counts = {
        key: comparison.get(key)
        for key in ("standalone_trades", "joint_trades", "matched")
    }
    if any(isinstance(value, bool) or not isinstance(value, int) for value in counts.values()):
        raise ContractError(f"{label} comparison trade counts must be integers")
    if counts["standalone_trades"] <= 0 or counts["joint_trades"] <= 0:
        raise ContractError(f"{label} comparison operands must both be non-empty")
    if counts["matched"] != counts["standalone_trades"] or counts["matched"] != counts["joint_trades"]:
        raise ContractError(f"{label} comparison does not prove exact cardinality match")
    _require_fidelity_equal("comparison.unmatched_standalone_sample", [], comparison.get("unmatched_standalone_sample"))
    _require_fidelity_equal("comparison.unmatched_joint_sample", [], comparison.get("unmatched_joint_sample"))

    operands = _require_exact_keys(
        receipt.get("operands"), {"standalone", "joint"}, f"{label} operands"
    )
    amap = _artifact_map(manifest.get("artifacts") or [])
    prepare_operations = manifest.get("prepare_operations") or manifest["operations"]
    if len(prepare_operations) != 6 or any("payload_json" not in item for item in prepare_operations):
        raise ContractError(f"{label} is missing the authenticated prepare operations")
    standalone_auth = _validate_fidelity_operand(
        operand=operands["standalone"], stage=stage, role="standalone",
        operation=prepare_operations[pair_offset], manifest=manifest, artifacts=amap,
        expected_work_payload_sha256=current_work_payload_sha256_by_id[
            expected_pair["standalone"]
        ],
    )
    joint_auth = _validate_fidelity_operand(
        operand=operands["joint"], stage=stage, role="joint",
        operation=prepare_operations[pair_offset + 1], manifest=manifest, artifacts=amap,
        expected_work_payload_sha256=current_work_payload_sha256_by_id[
            expected_pair["joint"]
        ],
    )
    if standalone_auth["completed"] > joint_auth["started"]:
        raise ContractError(f"{label} serial operand order is invalid")
    if standalone_auth["observed_execution_identity"] != joint_auth["observed_execution_identity"]:
        raise ContractError(f"{label} operand execution-input observations are spliced")
    _require_fidelity_equal(
        "comparison.standalone_trades",
        standalone_auth["selected_trade_count"], counts["standalone_trades"],
    )
    _require_fidelity_equal(
        "comparison.joint_trades", joint_auth["selected_trade_count"], counts["joint_trades"],
    )

    adjudication_id = receipt.get("adjudication_id")
    if not isinstance(adjudication_id, str) or not re.fullmatch(r"[0-9a-f]{64}", adjudication_id):
        raise ContractError(f"{label} adjudication_id is not a canonical SHA-256")
    recomputed_id = _fidelity_adjudication_id(receipt)
    _require_fidelity_equal("adjudication_id", recomputed_id, adjudication_id)
    normalized_identity = _fidelity_adjudication_identity(receipt)
    return {
        "stage": stage,
        "path": str(resolved),
        "sha256": receipt_sha,
        "bytes": len(raw),
        "adjudication_id": adjudication_id,
        "normalized_identity": normalized_identity,
    }, file_identity


def _validate_fidelity_receipt_set(
    manifest: dict[str, Any],
    supplied: list[tuple[int, Path]],
    expected_work_item_ids: list[str],
    current_work_payload_sha256_by_id: dict[str, str],
) -> list[dict[str, Any]]:
    if len(expected_work_item_ids) != 6:
        raise ContractError("fidelity adjudications require the exact six-item ladder")
    if set(current_work_payload_sha256_by_id) != set(expected_work_item_ids) or any(
        not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value)
        for value in current_work_payload_sha256_by_id.values()
    ):
        raise ContractError("fidelity adjudications require exact current work-payload hashes")
    if len(supplied) != len(FIDELITY_STAGES):
        raise ContractError("exactly three fidelity receipts are required (stages 0,1,2)")
    stages = [stage for stage, _path in supplied]
    if stages != list(FIDELITY_STAGES):
        raise ContractError(
            f"fidelity receipts must be supplied exactly once in stage order 0,1,2: {stages}"
        )
    bindings: list[dict[str, Any]] = []
    path_identities: set[str] = set()
    file_identities: set[tuple[int, int]] = set()
    for stage, path in supplied:
        if isinstance(stage, bool) or not isinstance(stage, int):
            raise ContractError(f"fidelity receipt stage must be an integer: {stage!r}")
        binding, file_identity = _validate_fidelity_receipt(
            stage=stage,
            path=Path(path),
            manifest=manifest,
            expected_work_item_ids=expected_work_item_ids,
            current_work_payload_sha256_by_id=current_work_payload_sha256_by_id,
        )
        path_identity = _path_identity(Path(binding["path"]))
        if path_identity in path_identities or file_identity in file_identities:
            raise ContractError("fidelity receipt paths/files must be three distinct identities")
        path_identities.add(path_identity)
        file_identities.add(file_identity)
        bindings.append(binding)
    return bindings


def build_release_plan(
    prepare_manifest: dict[str, Any],
    fidelity_receipts: list[tuple[int, Path]] | None = None,
) -> dict[str, Any]:
    _validate_plan_id(prepare_manifest)
    if prepare_manifest.get("schema") != SCHEMA_PREPARE or prepare_manifest.get("valid") is not True:
        raise ContractError("release requires the exact prepare manifest")
    _validate_prepare_operations(prepare_manifest)
    db = Path(prepare_manifest["db"]["path"])
    flag = Path(prepare_manifest["factory_off"]["path"])
    errors: list[str] = []
    operations = []
    if not flag.is_file():
        errors.append("FACTORY_OFF missing")
    processes = _factory_processes()
    if processes:
        errors.append(f"factory process census is not empty: {len(processes)}")
    with connect_ro(db) as conn:
        for source in prepare_manifest["operations"]:
            work_id = source["work_item_id"]
            row = conn.execute("SELECT status,verdict,claimed_by,updated_at,payload_json FROM work_items WHERE id=?", (work_id,)).fetchone()
            hold = conn.execute("SELECT * FROM work_item_holds WHERE work_item_id=?", (work_id,)).fetchone()
            if row is None or hold is None:
                errors.append(f"release operand missing: {work_id}")
                continue
            if row["status"] != "done" or row["verdict"] != "PASS" or row["claimed_by"] is not None:
                errors.append(f"work item is not done/PASS/unclaimed: {work_id}")
            if hold["hold_code"] != HOLD_CODE or hold["reason"] != HOLD_REASON or int(hold["active"]) != 1 or int(hold["release_on_restart"]) != 0:
                errors.append(f"hold preimage mismatch: {work_id}")
            operations.append({
                "work_item_id": work_id, "work_status": row["status"], "work_verdict": row["verdict"],
                "work_claimed_by": row["claimed_by"], "work_updated_at": row["updated_at"],
                "work_payload_sha256": hashlib.sha256(str(row["payload_json"]).encode()).hexdigest(),
                "hold_code": hold["hold_code"], "reason": hold["reason"], "hold_updated_at": hold["updated_at"],
            })
    authorized_work_item_ids = [
        operation["work_item_id"] for operation in prepare_manifest["operations"]
    ]
    fidelity_adjudications: list[dict[str, Any]] = []
    try:
        fidelity_adjudications = _validate_fidelity_receipt_set(
            prepare_manifest,
            list(fidelity_receipts or []),
            authorized_work_item_ids,
            {
                operation["work_item_id"]: operation["work_payload_sha256"]
                for operation in operations
            },
        )
    except ContractError as exc:
        errors.append(str(exc))
        fidelity_adjudications = []
    plan = {
        "schema": SCHEMA_RELEASE, "mode": "dry_run", "generated_at_utc": utc_now(),
        "root": prepare_manifest["root"], "repo": prepare_manifest["repo"],
        "artifact_root": prepare_manifest["artifact_root"],
        "report_root": prepare_manifest["report_root"],
        "common_qm": prepare_manifest["common_qm"],
        "t10_bases": prepare_manifest["t10_bases"],
        "calendar_source": prepare_manifest["calendar_source"],
        "calendar_common": prepare_manifest["calendar_common"],
        "joint_ex5_sha256": prepare_manifest["joint_ex5_sha256"],
        "compiled_ex5_sha256_by_ea": prepare_manifest["compiled_ex5_sha256_by_ea"],
        "compile_manifest": prepare_manifest["compile_manifest"],
        "prepare_plan_id": prepare_manifest["plan_id"], "terminal": TERMINAL,
        "prepare_operations": prepare_manifest["operations"],
        "authorized_work_item_ids": authorized_work_item_ids,
        "execution_input_artifacts_sha256": prepare_manifest["execution_input_artifacts_sha256"],
        "runtime_source_artifacts_sha256": prepare_manifest["runtime_source_artifacts_sha256"],
        "fidelity_adjudication_count": len(fidelity_adjudications),
        "fidelity_adjudications": fidelity_adjudications,
        "factory_off": {"path": str(flag), "sha256": sha256_file(flag) if flag.is_file() else None},
        "db": {"path": str(db), "logical_state_sha256": sqlite_state_sha256(db)},
        "git": prepare_manifest["git"], "artifacts": prepare_manifest["artifacts"],
        "factory_processes": processes, "operation_count": len(operations), "operations": operations,
        "safety": {"only_own_six_holds": True, "auto_release": False, "factory_remains_off": True},
        "valid": not errors and len(operations) == 6 and len(fidelity_adjudications) == 3,
        "errors": errors,
    }
    _assign_plan_id(plan)
    return plan


def _validate_release_operations(manifest: dict[str, Any]) -> None:
    _validate_manifest_topology(manifest)
    compile_binding, ex5_by_ea = _load_compile_manifest(
        repo=Path(str(manifest["repo"])),
        artifact_root=Path(str(manifest["artifact_root"])),
        flag=Path(str(manifest["factory_off"]["path"])),
        authoritative_source_commit=str(manifest["git"]["authoritative_source_commit"]),
        supplied_joint_ex5_sha256=str(manifest.get("joint_ex5_sha256") or ""),
    )
    if manifest.get("compile_manifest") != compile_binding:
        raise ContractError("release compile-manifest binding drifted")
    if manifest.get("compiled_ex5_sha256_by_ea") != ex5_by_ea:
        raise ContractError("release compiled EX5 map drifted")
    specs = _bound_run_specs(ex5_by_ea)
    operations = manifest.get("operations") or []
    if manifest.get("terminal") != TERMINAL or len(operations) != len(specs):
        raise ContractError("release manifest is not exactly six T10 holds")
    artifacts = manifest.get("artifacts") or []
    execution_inputs = _execution_input_artifacts(artifacts)
    if manifest.get("execution_input_artifacts_sha256") != canonical_sha(execution_inputs):
        raise ContractError("release manifest execution input list hash mismatch")
    if manifest.get("runtime_source_artifacts_sha256") != canonical_sha(
        _runtime_source_artifacts(artifacts)
    ):
        raise ContractError("release manifest runtime source list hash mismatch")
    expected = [
        _item_contract(
            spec,
            repo=Path(manifest["repo"]),
            artifact_root=Path(manifest["artifact_root"]),
            report_root=Path(manifest["report_root"]),
            common_qm=Path(manifest["common_qm"]),
            t10_bases=Path(manifest["t10_bases"]),
            calendar_source=Path(manifest["calendar_source"]),
            calendar_common=Path(manifest["calendar_common"]),
            git_identity=manifest["git"], compile_binding=compile_binding,
            artifacts=artifacts, sequence=sequence,
        )
        for sequence, spec in enumerate(specs)
    ]
    expected_ids = [item["work_item_id"] for item in expected]
    if manifest.get("prepare_operations") != expected:
        raise ContractError("release manifest prepare-operation bindings are not exact")
    if manifest.get("authorized_work_item_ids") != expected_ids:
        raise ContractError("release manifest authorized work-item IDs are not the exact six-item ladder")
    if [item.get("work_item_id") for item in operations] != expected_ids:
        raise ContractError("release operations are not the exact six-item ladder")
    fidelity_bindings = manifest.get("fidelity_adjudications")
    if (
        type(manifest.get("fidelity_adjudication_count")) is not int
        or
        manifest.get("fidelity_adjudication_count") != len(FIDELITY_STAGES)
        or not isinstance(fidelity_bindings, list)
        or len(fidelity_bindings) != len(FIDELITY_STAGES)
    ):
        raise ContractError("release manifest requires exactly three bound fidelity adjudications")
    supplied: list[tuple[int, Path]] = []
    for binding in fidelity_bindings:
        if not isinstance(binding, dict):
            raise ContractError("release manifest fidelity binding must be an object")
        supplied.append((binding.get("stage"), Path(str(binding.get("path") or ""))))
    current_bindings = _validate_fidelity_receipt_set(
        manifest,
        supplied,
        expected_ids,
        {
            operation["work_item_id"]: operation["work_payload_sha256"]
            for operation in operations
        },
    )
    if current_bindings != fidelity_bindings:
        raise ContractError("release manifest fidelity adjudication bindings drifted")
    for item in operations:
        if item.get("hold_code") != HOLD_CODE or item.get("reason") != HOLD_REASON:
            raise ContractError(f"release hold contract mismatch: {item.get('work_item_id')}")
        if item.get("work_status") != "done" or item.get("work_verdict") != "PASS":
            raise ContractError(f"release work item is not done/PASS: {item.get('work_item_id')}")
        if item.get("work_claimed_by") is not None:
            raise ContractError(f"release work item remains claimed: {item.get('work_item_id')}")


def apply_release(
    *, manifest_path: Path, expected_manifest_sha256: str, confirm_plan_id: str,
    expected_factory_off_sha256: str, expected_db_state_sha256: str,
    snapshot_path: Path, receipt_path: Path,
) -> dict[str, Any]:
    manifest, manifest_sha = _load_manifest(manifest_path, expected_manifest_sha256, SCHEMA_RELEASE)
    _assert_equal("confirmed plan id", confirm_plan_id, manifest["plan_id"])
    _assert_equal("FACTORY_OFF argument", expected_factory_off_sha256, manifest["factory_off"]["sha256"])
    _assert_equal("DB state argument", expected_db_state_sha256, manifest["db"]["logical_state_sha256"])
    _validate_release_operations(manifest)
    db = Path(manifest["db"]["path"])
    flag = Path(manifest["factory_off"]["path"])
    intent_path, intent_sha = _reserve_mutation_outputs(
        action="release_completed_holds",
        plan_id=manifest["plan_id"],
        manifest_path=manifest_path,
        manifest_sha256=manifest_sha,
        snapshot_path=snapshot_path,
        receipt_path=receipt_path,
        db_path=db,
        flag_path=flag,
    )
    with FactoryMutationLock(path_for_factory_flag(flag), owner=f"ftmo_book3_q02_release:{manifest['plan_id']}"):
        _assert_equal("FACTORY_OFF SHA-256", expected_factory_off_sha256, sha256_file(flag))
        _assert_equal("DB logical state", expected_db_state_sha256, sqlite_state_sha256(db))
        _assert_equal("controller Git HEAD", manifest["git"]["controller_head_commit"], _git(Path(manifest["repo"]), "rev-parse", "HEAD"))
        _verify_artifacts(manifest)
        semantic_errors = _semantic_source_errors(manifest)
        if semantic_errors:
            raise ContractError("; ".join(semantic_errors))
        if _factory_processes():
            raise ContractError("factory process census is not empty")
        # Re-read and re-adjudicate the three create-only PASS receipts under
        # the same Factory mutation lock immediately before the DB snapshot.
        _validate_release_operations(manifest)
        snapshot_sha = sqlite_snapshot(db, snapshot_path)
        _assert_equal("DB state after snapshot", expected_db_state_sha256, sqlite_state_sha256(db))
        released_at = utc_now()
        conn = sqlite3.connect(db, timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            _assert_equal("transaction DB preimage", expected_db_state_sha256, hashlib.sha256(conn.serialize()).hexdigest())
            for operation in manifest["operations"]:
                row = conn.execute("SELECT status,verdict,claimed_by,updated_at,payload_json FROM work_items WHERE id=?", (operation["work_item_id"],)).fetchone()
                if row is None or row["status"] != operation["work_status"] or row["verdict"] != operation["work_verdict"] or row["claimed_by"] is not None or row["updated_at"] != operation["work_updated_at"] or hashlib.sha256(str(row["payload_json"]).encode()).hexdigest() != operation["work_payload_sha256"]:
                    raise ContractError(f"terminal work-item CAS failed: {operation['work_item_id']}")
                cur = conn.execute(
                    """UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
                    WHERE work_item_id=? AND hold_code=? AND reason=? AND active=1 AND release_on_restart=0
                      AND updated_at=? AND released_at IS NULL AND release_note IS NULL""",
                    (released_at, released_at, f"terminal FTMO Book-3 ladder; release plan {manifest['plan_id']}",
                     operation["work_item_id"], operation["hold_code"], operation["reason"], operation["hold_updated_at"]),
                )
                if cur.rowcount != 1:
                    raise ContractError(f"hold release CAS failed: {operation['work_item_id']}")
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()
        _assert_equal("FACTORY_OFF post SHA-256", expected_factory_off_sha256, sha256_file(flag))
        with connect_ro(db) as verify:
            released = [dict(verify.execute(
                "SELECT work_item_id,active,release_on_restart,released_at,release_note FROM work_item_holds WHERE work_item_id=?",
                (op["work_item_id"],),
            ).fetchone()) for op in manifest["operations"]]
        receipt = {
            "schema": SCHEMA_RECEIPT, "action": "release_completed_holds", "mode": "apply",
            "receipt_id": f"ftmo-book3-q02-release-{manifest['plan_id']}", "applied_at_utc": released_at,
            "plan_id": manifest["plan_id"], "prepare_plan_id": manifest["prepare_plan_id"],
            "manifest_path": str(manifest_path), "manifest_sha256": manifest_sha,
            "mutation_intent": {"path": str(intent_path), "sha256": intent_sha},
            "factory_off_sha256": expected_factory_off_sha256.lower(),
            "pre_db_state_sha256": expected_db_state_sha256.lower(), "post_db_state_sha256": sqlite_state_sha256(db),
            "snapshot": {"path": str(snapshot_path), "sha256": snapshot_sha}, "released_holds": released,
            "fidelity_adjudication_count": manifest["fidelity_adjudication_count"],
            "fidelity_adjudications": manifest["fidelity_adjudications"],
            "factory_remains_off": flag.is_file(), "runs_mt5": False,
        }
        _write_new_json(receipt_path, receipt)
        return receipt


def _parse_fidelity_receipt_args(values: list[str]) -> list[tuple[int, Path]]:
    supplied: list[tuple[int, Path]] = []
    for value in values:
        stage_text, separator, path_text = value.partition(":")
        if not separator or stage_text not in {"0", "1", "2"} or not path_text:
            raise ContractError(
                f"--fidelity-receipt must use STAGE:ABSOLUTE_PATH for stage 0, 1, or 2: {value!r}"
            )
        supplied.append((int(stage_text), Path(path_text)))
    return supplied


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--report-root", type=Path, default=DEFAULT_REPORT_ROOT)
    parser.add_argument("--common-qm", type=Path, default=DEFAULT_COMMON_QM)
    parser.add_argument("--t10-bases", type=Path, default=DEFAULT_T10_BASES)
    parser.add_argument("--calendar-source", type=Path, default=DEFAULT_CALENDAR_SOURCE)
    parser.add_argument("--calendar-common", type=Path, default=DEFAULT_CALENDAR_COMMON)
    parser.add_argument("--source-commit")
    parser.add_argument("--joint-ex5-sha256")
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--release-from-prepare-manifest", type=Path)
    parser.add_argument(
        "--fidelity-receipt",
        action="append",
        default=[],
        metavar="STAGE:ABSOLUTE_PATH",
        help="repeat exactly for stages 0, 1, and 2 when building a release plan",
    )
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--expected-manifest-sha256")
    parser.add_argument("--confirm-plan-id")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--expected-db-state-sha256")
    parser.add_argument("--expected-source-commit")
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--receipt", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if not args.apply:
        if args.release_from_prepare_manifest:
            prepare = json.loads(args.release_from_prepare_manifest.read_text(encoding="utf-8-sig"))
            plan = build_release_plan(
                prepare,
                fidelity_receipts=_parse_fidelity_receipt_args(args.fidelity_receipt),
            )
        else:
            if args.fidelity_receipt:
                raise ContractError(
                    "--fidelity-receipt is valid only with --release-from-prepare-manifest"
                )
            if not args.source_commit:
                raise ContractError("prepare dry-run requires --source-commit")
            plan = build_prepare_plan(source_commit=args.source_commit,
                                      joint_ex5_sha256=args.joint_ex5_sha256,
                                      root=args.root, repo=args.repo, artifact_root=args.artifact_root,
                                      report_root=args.report_root, common_qm=args.common_qm,
                                      t10_bases=args.t10_bases,
                                      calendar_source=args.calendar_source,
                                      calendar_common=args.calendar_common)
        if args.plan_out:
            _write_new_json(args.plan_out, plan)
        print(json.dumps(plan, indent=2, ensure_ascii=False, sort_keys=True))
        return 0 if plan["valid"] else 2
    if args.fidelity_receipt:
        raise ContractError(
            "release apply consumes fidelity receipts only through the hash-bound release manifest"
        )
    required = {
        "--manifest": args.manifest, "--expected-manifest-sha256": args.expected_manifest_sha256,
        "--confirm-plan-id": args.confirm_plan_id, "--expected-factory-off-sha256": args.expected_factory_off_sha256,
        "--expected-db-state-sha256": args.expected_db_state_sha256,
        "--snapshot": args.snapshot, "--receipt": args.receipt,
    }
    missing = [name for name, value in required.items() if value in (None, "")]
    if missing:
        raise ContractError(f"apply missing required arguments: {', '.join(missing)}")
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    if manifest.get("schema") == SCHEMA_PREPARE:
        if not args.expected_source_commit:
            raise ContractError("prepare apply requires --expected-source-commit")
        receipt = apply_prepare(
            manifest_path=args.manifest, expected_manifest_sha256=args.expected_manifest_sha256,
            confirm_plan_id=args.confirm_plan_id, expected_factory_off_sha256=args.expected_factory_off_sha256,
            expected_db_state_sha256=args.expected_db_state_sha256, expected_source_commit=args.expected_source_commit,
            snapshot_path=args.snapshot, receipt_path=args.receipt,
        )
    elif manifest.get("schema") == SCHEMA_RELEASE:
        receipt = apply_release(
            manifest_path=args.manifest, expected_manifest_sha256=args.expected_manifest_sha256,
            confirm_plan_id=args.confirm_plan_id, expected_factory_off_sha256=args.expected_factory_off_sha256,
            expected_db_state_sha256=args.expected_db_state_sha256, snapshot_path=args.snapshot, receipt_path=args.receipt,
        )
    else:
        raise ContractError("unsupported manifest schema")
    print(json.dumps(receipt, indent=2, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ContractError as exc:
        print(json.dumps({"error": str(exc), "fail_closed": True}, sort_keys=True), file=sys.stderr)
        raise SystemExit(2)
