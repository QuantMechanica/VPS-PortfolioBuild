#!/usr/bin/env python3
"""Run one exact work item while the autonomous Factory remains OFF.

Dry-run is the default.  Apply is bound to the current FACTORY_OFF file, the
logical SQLite image, the exact pre-claim payload, and the worker script.  A
single global mutation lock remains held for snapshot, claim, tester run and
receipt publication, so Factory_ON and maintenance one-shots cannot overlap.

This controller never chooses queue work.  The requested row must carry an
active non-releasing maintenance hold and an explicit terminal identity.
T5 and T_Live are structurally forbidden.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import shutil
import signal
import sqlite3
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any

from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag


DEFAULT_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_DB_REL = Path("state") / "farm_state.sqlite"
DEFAULT_REPO_ROOT = Path(r"C:\QM\repo")
DEFAULT_WORKER = Path(r"C:\QM\repo\tools\strategy_farm\terminal_worker.py")
DEFAULT_REPORTS_WORK_ITEMS = Path(r"D:\QM\reports\work_items")
DEFAULT_FILE_COMMON_Q08 = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades"
)
DEFAULT_FILE_COMMON_Q08_EQUITY = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_equity"
)
ALLOWED_TERMINALS = frozenset({"T1", "T2", "T3", "T4", "T6", "T7", "T8", "T9", "T10"})
FTMO_BOOK3_MEASUREMENT_CONTRACT = (
    "FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET"
)
FTMO_BOOK3_EVIDENCE_VINTAGE = "FTMO_BOOK3_20260729_V2"
FTMO_BOOK3_MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
FTMO_BOOK3_FIDELITY_ALGORITHM = (
    "maximum_bipartite_exact_time_side_price_full_lifecycle_money_volume/v3"
)
FTMO_BOOK3_MONEY_TOLERANCE = 0.005
FTMO_BOOK3_VOLUME_TOLERANCE = 0.005
FTMO_BOOK3_PRICE_TOLERANCE = 0.0
FTMO_BOOK3_EXPECTED_EXECUTION_INPUT_COUNT = 307
FTMO_BOOK3_FIDELITY_STAGE_MEMBERS = {
    0: {
        "standalone": {"rung": "R0", "sequence": 0, "magic": 99360000, "symbol": "USDJPY.DWX"},
        "joint": {"rung": "J0", "sequence": 1, "magic": 201810000, "symbol": "USDJPY.DWX"},
    },
    1: {
        "standalone": {"rung": "R1", "sequence": 2, "magic": 101450034, "symbol": "XAUUSD.DWX"},
        "joint": {"rung": "J1", "sequence": 3, "magic": 201810001, "symbol": "XAUUSD.DWX"},
    },
    2: {
        "standalone": {"rung": "R2", "sequence": 4, "magic": 131080000, "symbol": "XTIUSD.DWX"},
        "joint": {"rung": "J2", "sequence": 5, "magic": 201810002, "symbol": "XTIUSD.DWX"},
    },
}
FTMO_BOOK3_SYMBOLS = ("USDJPY.DWX", "XAUUSD.DWX", "XTIUSD.DWX")
FTMO_BOOK3_RUNGS: dict[str, tuple[int, str | None]] = {
    "R0": (0, None),
    "J0": (1, "FTMO_BOOK3_20260729_V2_J0"),
    "R1": (2, None),
    "J1": (3, "FTMO_BOOK3_20260729_V2_J1"),
    "R2": (4, None),
    "J2": (5, "FTMO_BOOK3_20260729_V2_J2"),
}
FTMO_BOOK3_CALENDAR_FILES = (
    "news_calendar_2015_2025.csv",
    "forex_factory_calendar_clean.csv",
)
FTMO_BOOK3_HOLD_CODE = "FTMO_BOOK3_Q02_ISOLATED_ONLY"
FTMO_BOOK3_HOLD_REASON = (
    "OWNER-preregistered FTMO Book-3 Q02 fidelity ladder; isolated T10 execution only"
)
FTMO_BOOK3_WORK_CORE: dict[str, dict[str, Any]] = {
    "R0": {
        "sequence": 0,
        "ea_id": "QM5_9936",
        "symbol": "USDJPY.DWX",
        "period": "H1",
        "ea_dir_name": "QM5_9936_ff-range-breakout-gmt3-h1",
        "set_name": "QM5_9936_ff-range-breakout-gmt3-h1_USDJPY.DWX_H1_backtest.set",
    },
    "J0": {
        "sequence": 1,
        "ea_id": "QM5_20181",
        "symbol": "USDJPY.DWX",
        "period": "H1",
        "ea_dir_name": "QM5_20181_ftmo-joint-multisym-timer",
        "set_name": "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_replay_runner.set",
    },
    "R1": {
        "sequence": 2,
        "ea_id": "QM5_10145",
        "symbol": "XAUUSD.DWX",
        "period": "D1",
        "ea_dir_name": "QM5_10145_tsm-meanret",
        "set_name": "QM5_10145_tsm-meanret_XAUUSD.DWX_D1_backtest.set",
    },
    "J1": {
        "sequence": 3,
        "ea_id": "QM5_20181",
        "symbol": "USDJPY.DWX",
        "period": "H1",
        "ea_dir_name": "QM5_20181_ftmo-joint-multisym-timer",
        "set_name": "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book2_9936_10145.set",
    },
    "R2": {
        "sequence": 4,
        "ea_id": "QM5_13108",
        "symbol": "XTIUSD.DWX",
        "period": "D1",
        "ea_dir_name": "QM5_13108_xti-mtsm-s2",
        "set_name": "QM5_13108_xti-mtsm-s2_XTIUSD.DWX_D1_backtest.set",
    },
    "J2": {
        "sequence": 5,
        "ea_id": "QM5_20181",
        "symbol": "USDJPY.DWX",
        "period": "H1",
        "ea_dir_name": "QM5_20181_ftmo-joint-multisym-timer",
        "set_name": "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book3_9936_10145_13108.set",
    },
}
FTMO_RUNTIME_SOURCE_ROLES = (
    "preparation_controller",
    "isolated_runner",
    "terminal_worker",
    "farmctl",
    "factory_mutation_lock",
    "phase_utils",
    "run_smoke",
    "fidelity_comparator",
    "preregistration",
    "qm_tasks_manifest",
    "factory_process_scope",
    "fidelity_gate",
)
MAX_PAYLOAD_BYTES = 1_048_576
MIN_TIMEOUT_MINUTES = 0.01
MAX_TIMEOUT_MINUTES = 360.0
FTMO_ALLOWED_RUNTIME_PAYLOAD_KEYS = frozenset(
    {
        "adopted_active_child_at_iso",
        "avoid_terminals",
        "avoid_terminals_cleared_reason",
        "claimed_at_iso",
        "claimed_by_worker_pid",
        "cleared_stale_preflight_at",
        "cleared_stale_preflight_reason",
        "cold_cache_retry_attempt",
        "cold_cache_retry_cap",
        "cold_cache_signature",
        "cold_cache_summary_path",
        "commit_reservation_gb",
        "commit_reservation_until_utc",
        "ea_dir_name",
        "effective_min_trades",
        "evidence_binding_required",
        "evidence_provenance",
        "expected_ex5_sha256",
        "expected_expert",
        "expected_from_date",
        "expected_mq5_sha256",
        "expected_period",
        "expected_setfile_sha256",
        "expected_symbol",
        "expected_to_date",
        "expected_trades_per_year_per_symbol",
        "failure_class",
        "failure_class_evidence",
        "failure_subclass",
        "final_failure",
        "from_date",
        "from_year",
        "history_adjusted",
        "history_adjustment_source",
        "history_first_year",
        "history_last_year",
        "job_object_assigned",
        "job_object_mode",
        "job_object_registry_key",
        "killed_at",
        "last_launch_fault_at",
        "last_launch_fault_child_tail",
        "last_launch_fault_pid",
        "last_launch_fault_seconds",
        "last_launch_fault_terminal",
        "launch_fault_count",
        "launch_fault_defer_seconds",
        "launch_not_before_utc",
        "log_bomb_evidence_path",
        "log_bomb_journal_cap_bytes",
        "log_bomb_journal_gb",
        "log_bomb_journal_path",
        "log_path",
        "missing_inputs",
        "orphan_child_adopted_at_iso",
        "orphan_worker_pid",
        "p2_prescreen_done",
        "p2_prescreen_evidence_path",
        "p2_prescreen_from_date",
        "p2_prescreen_reason",
        "p2_prescreen_to_date",
        "p2_prescreen_verdict",
        "p2_run_stage",
        "phase_evidence_path",
        "phase_runner",
        "pid",
        "preflight_failed_at",
        "preflight_failure",
        "primary_thread_resumed",
        "prior_failure",
        "process_creation_key",
        "process_image_path",
        "process_started_at_epoch",
        "process_started_suspended",
        "reason_classes",
        "report_root",
        "requested_from_year",
        "requested_to_year",
        "run_smoke_exit_code",
        "smoke_year_count",
        "staged_ex5",
        "started_at_iso",
        "targeted_factory_off_run",
        "terminal",
        "terminal_stopped_on_release",
        "to_date",
        "to_year",
        "transient_infra_attempts",
        "transient_infra_evidence_path",
        "transient_infra_signature",
        "verdict_reason",
        "verdict_taxonomy",
    }
)
DEFAULT_T10_ROOT = Path(r"D:\QM\mt5\T10")
DEFAULT_NEWS_CALENDAR_ROOT = Path(r"D:\QM\data\news_calendar")
DEFAULT_COMMON_FILES_ROOT = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
)
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _bound_file_observation(path: Path) -> dict[str, Any]:
    """Hash one open file while proving its lexical path target stayed stable."""

    resolved_before = path.resolve(strict=True)
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        byte_count = os.fstat(handle.fileno()).st_size
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    resolved_after = path.resolve(strict=True)
    if _lexical_path_identity(resolved_before) != _lexical_path_identity(resolved_after):
        raise RuntimeError(
            f"path or junction target changed while file was read: "
            f"before={resolved_before} after={resolved_after}"
        )
    return {
        "sha256": digest.hexdigest(),
        "bytes": int(byte_count),
        "resolved_path": str(resolved_after),
    }


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def canonical_sha256(value: Any) -> str:
    rendered = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(rendered).hexdigest()


def connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def sqlite_state_sha256(db: Path) -> str:
    with connect_ro(db) as conn:
        return hashlib.sha256(conn.serialize()).hexdigest()


def sqlite_snapshot(source: Path, target: Path, *, reserved: bool = False) -> str:
    if reserved:
        if not target.is_file() or target.stat().st_size != 0:
            raise RuntimeError(f"snapshot reservation is missing or changed: {target}")
    elif target.exists():
        raise FileExistsError(f"snapshot target already exists: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    src = sqlite3.connect(source, timeout=30)
    dst = sqlite3.connect(target)
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()
    return sha256_file(target)


def checkpoint_wal(db: Path) -> dict[str, int]:
    with sqlite3.connect(db, timeout=30, isolation_level=None) as conn:
        conn.execute("PRAGMA busy_timeout=30000")
        row = conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
    busy, log_frames, checkpointed = (int(value or 0) for value in row)
    if busy:
        raise RuntimeError("SQLite WAL checkpoint remained busy after isolated run")
    return {"busy": busy, "log_frames": log_frames, "checkpointed_frames": checkpointed}


def _artifact(path_value: Any, expected_sha: Any, role: str) -> dict[str, Any]:
    path = Path(str(path_value or ""))
    expected = str(expected_sha or "").strip().lower()
    result: dict[str, Any] = {"role": role, "path": str(path), "expected_sha256": expected}
    if not path.is_file():
        result.update({"valid": False, "reason": "missing"})
        return result
    actual = sha256_file(path)
    result.update({"actual_sha256": actual, "valid": bool(expected) and actual == expected})
    if not expected:
        result["reason"] = "expected_hash_missing"
    elif actual != expected:
        result["reason"] = "hash_mismatch"
    return result


def _lexical_path_identity(path: Path) -> str:
    """Normalize an absolute path without dereferencing its final junction.

    T10's Custom data directory is deliberately junctioned to the validated
    shared history store.  Resolving it would turn an exact T10 contract into a
    different lexical terminal path, so execution-input identity is bound to
    the absolute path written into the preregistered payload and the bytes at
    that path.
    """

    return os.path.normcase(os.path.abspath(str(path)))


def _ftmo_book3_expected_execution_input_paths(repo_root: Path) -> dict[str, Path]:
    bases = DEFAULT_T10_ROOT / "bases"
    custom = bases / "Custom"
    expected: dict[str, Path] = {
        "t10_terminal_binary": DEFAULT_T10_ROOT / "terminal64.exe",
        "t10_metatester_binary": DEFAULT_T10_ROOT / "metatester64.exe",
        "t10_symbol_spec": bases / "symbols.custom.dat",
        "tester_cost_basis": (
            repo_root
            / "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt"
        ),
        "live_commission": repo_root / "framework/registry/live_commission.json",
        "venue_cost_model": repo_root / "framework/registry/venue_cost_model.json",
        "dwx_symbol_matrix": repo_root / "framework/registry/dwx_symbol_matrix.csv",
        "ftmo_rulepack": (
            repo_root
            / "tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json"
        ),
        "ftmo_official_rules_snapshot": (
            repo_root
            / "docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json"
        ),
    }
    for symbol in FTMO_BOOK3_SYMBOLS:
        for year in range(2018, 2026):
            expected[f"history:{symbol}:{year}"] = (
                custom / "history" / symbol / f"{year}.hcc"
            )
        for year in range(2018, 2026):
            first_month = 7 if year == 2018 else 1
            for month in range(first_month, 13):
                expected[f"ticks:{symbol}:{year}{month:02d}"] = (
                    custom / "ticks" / symbol / f"{year}{month:02d}.tkc"
                )
    for name in FTMO_BOOK3_CALENDAR_FILES:
        expected[f"calendar_source:{name}"] = DEFAULT_NEWS_CALENDAR_ROOT / name
        expected[f"calendar_common:{name}"] = DEFAULT_COMMON_FILES_ROOT / name
    return expected


def _execution_input_plan(
    payload: dict[str, Any], *, repo_root: Path
) -> dict[str, Any]:
    """Re-hash every preregistered external Book-3 execution operand.

    The preparation controller binds the same canonical 307-row list.  This
    second validation happens under the Factory mutation lock immediately
    before each tester process is started, closing the plan-to-run gap for
    terminal binaries, symbol specs, HCC/TKC data, calendars, costs and the
    FTMO rulepack.
    """

    raw = payload.get("execution_input_artifacts")
    requested = raw is not None
    if payload.get("measurement_contract") != FTMO_BOOK3_MEASUREMENT_CONTRACT:
        if requested:
            return {
                "requested": True,
                "valid": False,
                "errors": [
                    "execution_input_artifacts are only supported for the exact "
                    f"{FTMO_BOOK3_MEASUREMENT_CONTRACT} contract"
                ],
                "artifacts": [],
            }
        return {"requested": False, "valid": True, "errors": [], "artifacts": []}

    errors: list[str] = []
    if str(payload.get("terminal") or "").upper() != "T10":
        errors.append("FTMO Book-3 execution inputs require terminal T10")
    if not isinstance(raw, list):
        return {
            "requested": True,
            "valid": False,
            "errors": ["execution_input_artifacts must be an array"],
            "artifacts": [],
        }
    expected = _ftmo_book3_expected_execution_input_paths(repo_root)
    if len(raw) != len(expected):
        errors.append(
            "execution_input_artifacts cardinality mismatch: "
            f"expected={len(expected)} actual={len(raw)}"
        )

    normalized: list[dict[str, Any]] = []
    seen_roles: set[str] = set()
    seen_paths: set[str] = set()
    for index, item in enumerate(raw):
        result: dict[str, Any] = {"index": index, "valid": False}
        if not isinstance(item, dict):
            result["reason"] = "row_not_object"
            normalized.append(result)
            errors.append(f"execution input {index} is not an object")
            continue
        if set(item) != {"role", "path", "sha256", "bytes"}:
            errors.append(f"execution input {index} fields are not exact")
        role = item.get("role")
        path_text = item.get("path")
        expected_hash = item.get("sha256")
        expected_bytes = item.get("bytes")
        result.update(
            {
                "role": role,
                "path": path_text,
                "expected_sha256": expected_hash,
                "expected_bytes": expected_bytes,
            }
        )
        if not isinstance(role, str) or not role:
            errors.append(f"execution input {index} role is invalid")
            normalized.append(result)
            continue
        if role in seen_roles:
            errors.append(f"execution input role is duplicated: {role}")
        seen_roles.add(role)
        expected_path = expected.get(role)
        if expected_path is None:
            errors.append(f"execution input role is unexpected: {role}")
        if not isinstance(path_text, str) or not path_text or not Path(path_text).is_absolute():
            errors.append(f"execution input {role} path is not absolute")
            normalized.append(result)
            continue
        path = Path(path_text)
        path_identity = _lexical_path_identity(path)
        if path_identity in seen_paths:
            errors.append(f"execution input path is duplicated: {path_text}")
        seen_paths.add(path_identity)
        if expected_path is not None and path_identity != _lexical_path_identity(expected_path):
            errors.append(
                f"execution input {role} path mismatch: "
                f"expected={expected_path} actual={path_text}"
            )
            normalized.append(result)
            continue
        if not isinstance(expected_hash, str) or not _SHA256_RE.fullmatch(expected_hash):
            errors.append(f"execution input {role} SHA-256 is not canonical lower-hex")
            normalized.append(result)
            continue
        if (
            isinstance(expected_bytes, bool)
            or not isinstance(expected_bytes, int)
            or expected_bytes < 0
        ):
            errors.append(f"execution input {role} byte count is invalid")
            normalized.append(result)
            continue
        if not path.is_file():
            errors.append(f"execution input {role} is missing: {path}")
            result["reason"] = "missing"
            normalized.append(result)
            continue
        try:
            observation = _bound_file_observation(path)
            actual_bytes = observation["bytes"]
            actual_hash = observation["sha256"]
            actual_resolved_path = observation["resolved_path"]
        except OSError as exc:
            errors.append(f"execution input {role} cannot be read: {exc}")
            result["reason"] = "unreadable"
            normalized.append(result)
            continue
        result.update(
            {
                "actual_sha256": actual_hash,
                "actual_bytes": actual_bytes,
                "actual_resolved_path": actual_resolved_path,
            }
        )
        if actual_bytes != expected_bytes:
            errors.append(
                f"execution input {role} byte mismatch: "
                f"expected={expected_bytes} actual={actual_bytes}"
            )
        if actual_hash != expected_hash:
            errors.append(
                f"execution input {role} SHA-256 mismatch: "
                f"expected={expected_hash} actual={actual_hash}"
            )
        result["valid"] = actual_bytes == expected_bytes and actual_hash == expected_hash
        normalized.append(result)

    missing_roles = sorted(set(expected) - seen_roles)
    if missing_roles:
        errors.append(f"execution input roles are missing: {missing_roles}")
    canonical_order = sorted(
        raw,
        key=lambda item: (
            str(item.get("role") or "") if isinstance(item, dict) else "",
            str(item.get("path") or "") if isinstance(item, dict) else "",
        ),
    )
    if raw != canonical_order:
        errors.append("execution_input_artifacts are not in canonical role/path order")
    actual_list_sha = canonical_sha256(raw)
    expected_list_sha = payload.get("execution_input_artifacts_sha256")
    if (
        not isinstance(expected_list_sha, str)
        or not _SHA256_RE.fullmatch(expected_list_sha)
        or expected_list_sha != actual_list_sha
    ):
        errors.append(
            "execution_input_artifacts_sha256 mismatch: "
            f"expected={expected_list_sha} actual={actual_list_sha}"
        )
    observations = [
        {
            "role": item.get("role"),
            "path": item.get("path"),
            "resolved_path": item.get("actual_resolved_path"),
            "sha256": item.get("actual_sha256"),
            "bytes": item.get("actual_bytes"),
        }
        for item in normalized
        if item.get("valid") is True
    ]
    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "expected_count": len(expected),
        "artifacts": normalized,
        "canonical_sha256": actual_list_sha,
        "observed_bundle_sha256": canonical_sha256(observations),
    }


def _git_head(repo_root: Path) -> str:
    process = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if process.returncode:
        raise RuntimeError(
            f"git rev-parse HEAD failed: {(process.stderr or process.stdout).strip()}"
        )
    return process.stdout.strip().lower()


def _git_clean_plan(
    repo_root: Path, *, scoped_paths: Any = (),
) -> dict[str, Any]:
    try:
        resolved_repo = repo_root.resolve(strict=True)
    except OSError as exc:
        return {
            "valid": False,
            "error": f"authoritative source repository is unavailable: {exc}",
            "porcelain": None,
        }
    relative_paths: list[str] = []
    for raw_path in scoped_paths:
        try:
            resolved = Path(raw_path).resolve(strict=True)
            relative = resolved.relative_to(resolved_repo)
        except (OSError, ValueError) as exc:
            return {
                "valid": False,
                "error": f"Git-bound runtime source is outside the repository: {raw_path}: {exc}",
                "porcelain": None,
            }
        rendered = relative.as_posix()
        if rendered not in relative_paths:
            relative_paths.append(rendered)
    if not relative_paths:
        return {
            "valid": False,
            "error": "Git-bound runtime source scope is empty",
            "porcelain": None,
        }
    process = subprocess.run(
        [
            "git",
            "status",
            "--porcelain=v1",
            "--untracked-files=all",
            "--",
            *sorted(relative_paths),
        ],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if process.returncode:
        return {
            "valid": False,
            "error": "git status failed: "
            + (process.stderr or process.stdout).strip(),
            "porcelain": None,
        }
    porcelain = process.stdout
    return {
        "valid": porcelain == "",
        "error": (
            None
            if porcelain == ""
            else "authoritative runtime-source scope is not clean"
        ),
        "porcelain": porcelain,
    }


def _content_uuid(content_sha256: str) -> str | None:
    if not isinstance(content_sha256, str) or not _SHA256_RE.fullmatch(content_sha256):
        return None
    value = bytearray(bytes.fromhex(content_sha256[:32]))
    value[6] = (value[6] & 0x0F) | 0x50
    value[8] = (value[8] & 0x3F) | 0x80
    return str(uuid.UUID(bytes=bytes(value)))


def _payload_contract_plan(
    payload: dict[str, Any], *, payload_text: str
) -> dict[str, Any]:
    requested = payload.get("measurement_contract") == FTMO_BOOK3_MEASUREMENT_CONTRACT
    if not requested:
        return {"requested": False, "valid": True, "errors": []}
    key_hashes = {
        key: canonical_sha256(payload[key])
        for key in sorted(payload)
    }
    return {
        "requested": True,
        "valid": True,
        "errors": [],
        "pre_payload_sha256": sha256_text(payload_text),
        "pre_keys": sorted(payload),
        "pre_key_value_sha256": key_hashes,
        "allowed_runtime_additions": sorted(FTMO_ALLOWED_RUNTIME_PAYLOAD_KEYS),
    }


def _revalidate_payload_contract(
    preflight: dict[str, Any], *, post_payload_text: str
) -> dict[str, Any]:
    prior = preflight.get("payload_contract") or {}
    post_sha = sha256_text(post_payload_text)
    if not prior.get("requested"):
        return {
            "requested": False,
            "valid": True,
            "errors": [],
            "pre_payload_sha256": preflight.get("work_item", {}).get("payload_sha256"),
            "post_payload_sha256": post_sha,
        }
    errors: list[str] = []
    try:
        post_payload = _strict_json_object(
            post_payload_text.encode("utf-8"), label="post payload_json"
        )
    except (TypeError, ValueError, RuntimeError) as exc:
        post_payload = {}
        errors.append(f"post payload_json is invalid: {exc}")
    if not isinstance(post_payload, dict):
        post_payload = {}
        errors.append("post payload_json must decode to an object")
    pre_keys = set(prior.get("pre_keys") or [])
    expected_hashes = prior.get("pre_key_value_sha256") or {}
    allowed = set(prior.get("allowed_runtime_additions") or [])
    post_keys = set(post_payload)
    removed = sorted(pre_keys - post_keys)
    added = sorted(post_keys - pre_keys)
    unexpected_added = sorted(set(added) - allowed)
    changed = sorted(
        key
        for key in pre_keys & post_keys
        if canonical_sha256(post_payload[key]) != expected_hashes.get(key)
    )
    if removed:
        errors.append(f"immutable FTMO payload keys were removed: {removed}")
    if changed:
        errors.append(f"immutable FTMO payload keys changed: {changed}")
    if unexpected_added:
        errors.append(f"unexpected FTMO runtime payload keys were added: {unexpected_added}")
    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "pre_payload_sha256": prior.get("pre_payload_sha256"),
        "post_payload_sha256": post_sha,
        "immutable_key_count": len(pre_keys),
        "immutable_keys": sorted(pre_keys),
        "added_runtime_keys": added,
        "unexpected_added_runtime_keys": unexpected_added,
        "removed_immutable_keys": removed,
        "changed_immutable_keys": changed,
    }


def _ftmo_runtime_source_paths(
    repo_root: Path, *, worker_script: Path
) -> dict[str, Path]:
    return {
        "preparation_controller": (
            repo_root / "tools/strategy_farm/prepare_ftmo_book3_q02.py"
        ).resolve(),
        "isolated_runner": Path(__file__).resolve(),
        "terminal_worker": worker_script.resolve(),
        "farmctl": (repo_root / "tools/strategy_farm/farmctl.py").resolve(),
        "factory_mutation_lock": (
            repo_root / "tools/strategy_farm/factory_mutation_lock.py"
        ).resolve(),
        "phase_utils": (repo_root / "framework/scripts/_phase_utils.py").resolve(),
        "run_smoke": (repo_root / "framework/scripts/run_smoke.ps1").resolve(),
        "fidelity_comparator": (
            repo_root / "tools/strategy_farm/compare_joint_replay.py"
        ).resolve(),
        "preregistration": (
            repo_root
            / "docs/ops/evidence/2026-07-29_ftmo_book3_execution_preregistration_v2.md"
        ).resolve(),
        "qm_tasks_manifest": (
            repo_root / "tools/strategy_farm/qm_tasks.manifest.ps1"
        ).resolve(),
        "factory_process_scope": (
            repo_root / "tools/strategy_farm/factory_process_scope.ps1"
        ).resolve(),
        "fidelity_gate": (
            repo_root / "tools/strategy_farm/ftmo_book3_fidelity_gate.py"
        ).resolve(),
    }


def _ftmo_runtime_source_plan(
    payload: dict[str, Any], *, repo_root: Path, worker_script: Path
) -> dict[str, Any]:
    """Validate the exact transitive source manifest used by the FTMO run."""

    raw = payload.get("runtime_source_artifacts")
    errors: list[str] = []
    if not isinstance(raw, list):
        return {
            "requested": True,
            "valid": False,
            "errors": ["runtime_source_artifacts must be an array"],
            "artifacts": [],
        }
    expected = _ftmo_runtime_source_paths(repo_root, worker_script=worker_script)
    if set(expected) != set(FTMO_RUNTIME_SOURCE_ROLES):
        errors.append("internal runtime source role contract is inconsistent")
    if len(raw) != len(expected):
        errors.append(
            "runtime_source_artifacts cardinality mismatch: "
            f"expected={len(expected)} actual={len(raw)}"
        )
    normalized: list[dict[str, Any]] = []
    seen_roles: set[str] = set()
    seen_paths: set[str] = set()
    for index, item in enumerate(raw):
        result: dict[str, Any] = {"index": index, "valid": False}
        if not isinstance(item, dict):
            errors.append(f"runtime source {index} is not an object")
            normalized.append(result)
            continue
        if set(item) != {"role", "path", "sha256", "bytes"}:
            errors.append(f"runtime source {index} fields are not exact")
        role = item.get("role")
        path_text = item.get("path")
        expected_hash = item.get("sha256")
        expected_bytes = item.get("bytes")
        result.update(
            {
                "role": role,
                "path": path_text,
                "expected_sha256": expected_hash,
                "expected_bytes": expected_bytes,
            }
        )
        if not isinstance(role, str) or role not in expected:
            errors.append(f"runtime source {index} role is unexpected: {role!r}")
            normalized.append(result)
            continue
        if role in seen_roles:
            errors.append(f"runtime source role is duplicated: {role}")
        seen_roles.add(role)
        if not isinstance(path_text, str) or not Path(path_text).is_absolute():
            errors.append(f"runtime source {role} path is not absolute")
            normalized.append(result)
            continue
        path = Path(path_text)
        identity = _lexical_path_identity(path)
        if identity in seen_paths:
            errors.append(f"runtime source path is duplicated: {path_text}")
        seen_paths.add(identity)
        if identity != _lexical_path_identity(expected[role]):
            errors.append(
                f"runtime source {role} path mismatch: "
                f"expected={expected[role]} actual={path_text}"
            )
            normalized.append(result)
            continue
        if not isinstance(expected_hash, str) or not _SHA256_RE.fullmatch(expected_hash):
            errors.append(f"runtime source {role} SHA-256 is not canonical lower-hex")
            normalized.append(result)
            continue
        if (
            isinstance(expected_bytes, bool)
            or not isinstance(expected_bytes, int)
            or expected_bytes < 0
        ):
            errors.append(f"runtime source {role} byte count is invalid")
            normalized.append(result)
            continue
        if not path.is_file():
            errors.append(f"runtime source {role} is missing: {path}")
            normalized.append(result)
            continue
        try:
            observation = _bound_file_observation(path)
            actual_hash = observation["sha256"]
            actual_bytes = observation["bytes"]
            actual_resolved = observation["resolved_path"]
        except OSError as exc:
            errors.append(f"runtime source {role} cannot be read: {exc}")
            normalized.append(result)
            continue
        result.update(
            {
                "actual_sha256": actual_hash,
                "actual_bytes": actual_bytes,
                "actual_resolved_path": actual_resolved,
            }
        )
        if actual_hash != expected_hash:
            errors.append(f"runtime source {role} SHA-256 mismatch")
        if actual_bytes != expected_bytes:
            errors.append(f"runtime source {role} byte count mismatch")
        result["valid"] = actual_hash == expected_hash and actual_bytes == expected_bytes
        normalized.append(result)
    missing = sorted(set(expected) - seen_roles)
    if missing:
        errors.append(f"runtime source roles are missing: {missing}")
    canonical = sorted(
        raw,
        key=lambda item: (
            str(item.get("role") or "") if isinstance(item, dict) else "",
            str(item.get("path") or "") if isinstance(item, dict) else "",
        ),
    )
    if raw != canonical:
        errors.append("runtime_source_artifacts are not in canonical role/path order")
    actual_list_sha = canonical_sha256(raw)
    expected_list_sha = payload.get("runtime_source_artifacts_sha256")
    if (
        not isinstance(expected_list_sha, str)
        or not _SHA256_RE.fullmatch(expected_list_sha)
        or expected_list_sha != actual_list_sha
    ):
        errors.append(
            "runtime_source_artifacts_sha256 mismatch: "
            f"expected={expected_list_sha} actual={actual_list_sha}"
        )
    # The repository can legitimately contain unrelated OWNER work in progress.
    # Git cleanliness therefore applies to the exact, hash-bound runtime-source
    # manifest, not to unrelated dashboard/public-data paths.  Every execution
    # input and EA artifact is independently hash-checked above/below.
    git = _git_clean_plan(repo_root, scoped_paths=expected.values())
    if not git.get("valid"):
        errors.append(
            str(git.get("error") or "authoritative runtime-source scope is not clean")
        )
    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "artifacts": normalized,
        "canonical_sha256": actual_list_sha,
        "git_clean": git,
    }


def _tree_content_sha256(root: Path) -> tuple[str, int]:
    if not root.is_dir():
        raise FileNotFoundError(root)
    rows = [
        {
            "path": child.relative_to(root).as_posix(),
            "sha256": sha256_file(child),
            "bytes": child.stat().st_size,
        }
        for child in sorted(
            (path for path in root.rglob("*") if path.is_file()),
            key=lambda path: path.relative_to(root).as_posix().lower(),
        )
    ]
    if not rows:
        raise RuntimeError(f"source tree is empty: {root}")
    return canonical_sha256(rows), len(rows)


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key in values:
            raise ValueError(f"duplicate set key: {key}")
        values[key] = value.strip()
    return values


def _ftmo_source_binding_plan(
    payload: dict[str, Any], *, repo_root: Path, worker_script: Path,
    setfile_path: Path,
) -> dict[str, Any]:
    if payload.get("measurement_contract") != FTMO_BOOK3_MEASUREMENT_CONTRACT:
        return {"requested": False, "valid": True, "errors": []}

    errors: list[str] = []
    rung = payload.get("measurement_rung")
    sequence = payload.get("measurement_sequence")
    evidence_run_id = payload.get("evidence_run_id")
    expected_rung = FTMO_BOOK3_RUNGS.get(str(rung))
    if expected_rung is None:
        errors.append(f"FTMO Book-3 measurement rung is invalid: {rung!r}")
    else:
        expected_sequence, expected_evidence_run_id = expected_rung
        if sequence != expected_sequence:
            errors.append(
                "FTMO Book-3 measurement sequence mismatch: "
                f"expected={expected_sequence} actual={sequence}"
            )
        if evidence_run_id != expected_evidence_run_id:
            errors.append(
                "FTMO Book-3 evidence_run_id mismatch: "
                f"expected={expected_evidence_run_id!r} actual={evidence_run_id!r}"
            )
        if expected_evidence_run_id is not None:
            try:
                set_evidence_run_id = _set_values(setfile_path).get(
                    "qm_evidence_run_id"
                )
            except Exception as exc:
                set_evidence_run_id = None
                errors.append(f"FTMO Book-3 setfile cannot be parsed: {exc}")
            if set_evidence_run_id != expected_evidence_run_id:
                errors.append(
                    "FTMO Book-3 setfile evidence_run_id mismatch: "
                    f"expected={expected_evidence_run_id!r} "
                    f"actual={set_evidence_run_id!r}"
                )
    expected_source_commit = payload.get("authoritative_source_commit")
    expected_controller_commit = payload.get("controller_head_commit")
    for label, value in (
        ("authoritative_source_commit", expected_source_commit),
        ("controller_head_commit", expected_controller_commit),
    ):
        if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{40}", value):
            errors.append(f"{label} must be a full canonical lower-hex Git commit")
    try:
        actual_head = _git_head(repo_root)
    except Exception as exc:
        actual_head = None
        errors.append(f"source Git identity cannot be read: {exc}")
    if actual_head is not None:
        if actual_head != expected_source_commit:
            errors.append(
                "authoritative source commit mismatch: "
                f"expected={expected_source_commit} actual={actual_head}"
            )
        if actual_head != expected_controller_commit:
            errors.append(
                "controller head commit mismatch: "
                f"expected={expected_controller_commit} actual={actual_head}"
            )

    include_tree = repo_root / "framework/include/QM"
    try:
        actual_tree_sha, tree_file_count = _tree_content_sha256(include_tree)
    except Exception as exc:
        actual_tree_sha = None
        tree_file_count = 0
        errors.append(f"framework include tree cannot be fingerprinted: {exc}")
    expected_tree_sha = payload.get("framework_include_tree_sha256")
    if (
        not isinstance(expected_tree_sha, str)
        or not _SHA256_RE.fullmatch(expected_tree_sha)
        or actual_tree_sha != expected_tree_sha
    ):
        errors.append(
            "framework include tree SHA-256 mismatch: "
            f"expected={expected_tree_sha} actual={actual_tree_sha}"
        )

    preregistration = (
        repo_root
        / "docs/ops/evidence/2026-07-29_ftmo_book3_execution_preregistration_v2.md"
    )
    expected_prereg_sha = payload.get("preregistration_sha256")
    actual_prereg_sha = sha256_file(preregistration) if preregistration.is_file() else None
    if (
        not isinstance(expected_prereg_sha, str)
        or not _SHA256_RE.fullmatch(expected_prereg_sha)
        or actual_prereg_sha != expected_prereg_sha
    ):
        errors.append(
            "preregistration SHA-256 mismatch: "
            f"expected={expected_prereg_sha} actual={actual_prereg_sha}"
        )

    controller_path = Path(__file__).resolve()
    declared_controller_path = Path(str(payload.get("isolated_runner_path") or ""))
    if _lexical_path_identity(declared_controller_path) != _lexical_path_identity(
        controller_path
    ):
        errors.append(
            "isolated runner path mismatch: "
            f"expected={controller_path} actual={declared_controller_path}"
        )
    actual_controller_sha = sha256_file(controller_path)
    expected_controller_sha = payload.get("isolated_runner_sha256")
    if (
        not isinstance(expected_controller_sha, str)
        or not _SHA256_RE.fullmatch(expected_controller_sha)
        or actual_controller_sha != expected_controller_sha
    ):
        errors.append(
            "isolated runner SHA-256 mismatch: "
            f"expected={expected_controller_sha} actual={actual_controller_sha}"
        )
    declared_worker_path = Path(str(payload.get("terminal_worker_path") or ""))
    if _lexical_path_identity(declared_worker_path) != _lexical_path_identity(
        worker_script
    ):
        errors.append(
            "terminal worker path mismatch: "
            f"expected={worker_script} actual={declared_worker_path}"
        )
    actual_worker_sha = sha256_file(worker_script) if worker_script.is_file() else None
    expected_worker_sha = payload.get("terminal_worker_sha256")
    if (
        not isinstance(expected_worker_sha, str)
        or not _SHA256_RE.fullmatch(expected_worker_sha)
        or actual_worker_sha != expected_worker_sha
    ):
        errors.append(
            "terminal worker SHA-256 mismatch: "
            f"expected={expected_worker_sha} actual={actual_worker_sha}"
        )

    preparation_controller = (
        repo_root / "tools/strategy_farm/prepare_ftmo_book3_q02.py"
    ).resolve()
    declared_preparation_path = Path(
        str(payload.get("preparation_controller_path") or "")
    )
    if _lexical_path_identity(declared_preparation_path) != _lexical_path_identity(
        preparation_controller
    ):
        errors.append(
            "preparation controller path mismatch: "
            f"expected={preparation_controller} actual={declared_preparation_path}"
        )
    actual_preparation_sha = (
        sha256_file(preparation_controller)
        if preparation_controller.is_file()
        else None
    )
    expected_preparation_sha = payload.get("preparation_controller_sha256")
    if (
        not isinstance(expected_preparation_sha, str)
        or not _SHA256_RE.fullmatch(expected_preparation_sha)
        or actual_preparation_sha != expected_preparation_sha
    ):
        errors.append(
            "preparation controller SHA-256 mismatch: "
            f"expected={expected_preparation_sha} actual={actual_preparation_sha}"
        )

    runtime_sources = _ftmo_runtime_source_plan(
        payload, repo_root=repo_root, worker_script=worker_script
    )
    errors.extend(runtime_sources.get("errors") or [])

    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "authoritative_source_commit": expected_source_commit,
        "controller_head_commit": expected_controller_commit,
        "actual_head_commit": actual_head,
        "measurement_rung": rung,
        "measurement_sequence": sequence,
        "evidence_run_id": evidence_run_id,
        "framework_include_tree": {
            "path": str(include_tree),
            "expected_sha256": expected_tree_sha,
            "actual_sha256": actual_tree_sha,
            "file_count": tree_file_count,
        },
        "preregistration": {
            "path": str(preregistration),
            "expected_sha256": expected_prereg_sha,
            "actual_sha256": actual_prereg_sha,
        },
        "isolated_runner": {
            "path": str(controller_path),
            "expected_sha256": expected_controller_sha,
            "actual_sha256": actual_controller_sha,
        },
        "terminal_worker": {
            "path": str(worker_script),
            "expected_sha256": expected_worker_sha,
            "actual_sha256": actual_worker_sha,
        },
        "preparation_controller": {
            "path": str(preparation_controller),
            "expected_sha256": expected_preparation_sha,
            "actual_sha256": actual_preparation_sha,
        },
        "runtime_sources": runtime_sources,
    }


def _line_count(path: Path) -> int:
    with path.open("rb") as handle:
        return sum(1 for _ in handle)


def _stream_fingerprint(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"exists": False}
    stat = path.stat()
    return {
        "exists": True,
        "sha256": sha256_file(path),
        "bytes": stat.st_size,
        "lines": _line_count(path),
        "mtime_ns": stat.st_mtime_ns,
    }


def _path_identity(path: Path) -> str:
    """Return a platform-normalized identity for collision checks."""
    return os.path.normcase(str(path.resolve()))


def _allowed_file_common_stream_roots() -> dict[str, Path]:
    return {
        "q08_trades": DEFAULT_FILE_COMMON_Q08,
        "q08_equity": DEFAULT_FILE_COMMON_Q08_EQUITY,
    }


def _multi_stream_binding_errors(streams: list[dict[str, Any]]) -> list[str]:
    """Reject mixed-run or duplicate-role evidence batches."""
    errors: list[str] = []
    target_identities: dict[str, int] = {}
    source_identities: dict[str, int] = {}
    type_indices: dict[str, int] = {}
    stems: dict[str, list[int]] = {}
    allowed_types = _allowed_file_common_stream_roots()
    for index, contract in enumerate(streams):
        stream_type = str(contract.get("stream_type") or "").strip()
        if stream_type in allowed_types:
            if stream_type in type_indices:
                errors.append(
                    f"post-run stream_type {stream_type!r} appears more than once at streams "
                    f"{type_indices[stream_type]} and {index}"
                )
            else:
                type_indices[stream_type] = index
            source_text = str(contract.get("source") or "").strip()
            if source_text:
                stems.setdefault(Path(source_text).stem, []).append(index)
        try:
            target_identity = _path_identity(Path(str(contract["target"])))
            if target_identity in target_identities:
                errors.append(
                    "duplicate post-run evidence target for streams "
                    f"{target_identities[target_identity]} and {index}: {contract['target']}"
                )
            else:
                target_identities[target_identity] = index
            source_identity = _path_identity(Path(str(contract["source"])))
            if source_identity in source_identities:
                errors.append(
                    "duplicate post-run source for streams "
                    f"{source_identities[source_identity]} and {index}: {contract['source']}"
                )
            else:
                source_identities[source_identity] = index
        except (KeyError, OSError) as exc:
            errors.append(f"stream {index} identity cannot be resolved: {exc}")
    if len(stems) > 1:
        rendered = ", ".join(
            f"{stem!r}@{indices}" for stem, indices in sorted(stems.items())
        )
        errors.append(f"post-run stream source stems must be identical: {rendered}")
    return errors


def _single_post_run_stream_plan(
    *,
    source_value: Any,
    stream_type: str,
    report_root: Path,
    expected_report_root: Path,
    pre_capture: dict[str, Any],
) -> dict[str, Any]:
    source_text = str(source_value or "").strip()
    source = Path(source_text)
    governed_root = _allowed_file_common_stream_roots().get(stream_type)
    target = report_root / f"{stream_type}_{source.stem}.timer_v2.jsonl"
    errors: list[str] = []
    if governed_root is None:
        errors.append(f"unsupported post-run stream_type: {stream_type!r}")
    if not source_text:
        errors.append("post-run source is required")
    elif not source.is_absolute():
        errors.append("post-run source must be an absolute path")
    if source.suffix.lower() != ".jsonl":
        errors.append("post-run source must be a JSONL file")
    if source.name.lower() == ".jsonl":
        errors.append("post-run source must have a non-empty stem")
    if governed_root is not None and source_text:
        try:
            if source.resolve().parent != governed_root.resolve():
                errors.append(
                    f"post-run source is outside the governed FILE_COMMON {stream_type} directory"
                )
        except OSError as exc:
            errors.append(f"post-run source cannot be resolved: {exc}")
    try:
        if report_root.resolve() != expected_report_root.resolve():
            errors.append(
                "report_root must be the exact governed work-item evidence directory: "
                f"{expected_report_root}"
            )
    except OSError as exc:
        errors.append(f"report_root cannot be resolved: {exc}")
    try:
        if target.resolve().parent != expected_report_root.resolve():
            errors.append("post-run evidence target escapes the governed report_root")
    except OSError as exc:
        errors.append(f"post-run evidence target cannot be resolved: {exc}")
    if target.exists():
        errors.append(f"post-run evidence target already exists: {target}")

    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "stream_type": stream_type,
        "source": str(source),
        "target": str(target),
        # Invalid outside-allowlist paths are never read during preflight.
        "pre_run_source": _stream_fingerprint(source) if not errors else {"exists": False},
        "pre_v2_capture": pre_capture,
    }


def _post_run_stream_plan(payload: dict[str, Any], work_item_id: str) -> dict[str, Any]:
    """Build a legacy single-stream or governed coordinated multi-stream contract.

    ``post_run_file_common_source`` remains the legacy q08-trades contract.
    ``post_run_file_common_streams`` adds zero or more objects with exactly a
    ``stream_type`` (q08_trades/q08_equity) and absolute ``source``.  Targets
    are derived, never caller-selected, beneath the exact work-item report root.
    """
    source_value = str(payload.get("post_run_file_common_source") or "").strip()
    report_root = Path(str(payload.get("report_root") or ""))
    expected_report_root = DEFAULT_REPORTS_WORK_ITEMS / work_item_id
    legacy: dict[str, Any] | None = None
    if source_value:
        legacy = _single_post_run_stream_plan(
            source_value=source_value,
            stream_type="q08_trades",
            report_root=report_root,
            expected_report_root=expected_report_root,
            pre_capture={
                "path": payload.get("pre_v2_file_common_capture_path"),
                "sha256": str(payload.get("pre_v2_file_common_capture_sha256") or "").lower(),
                "bytes": payload.get("pre_v2_file_common_capture_bytes"),
                "lines": payload.get("pre_v2_file_common_capture_lines"),
            },
        )

    multi_present = "post_run_file_common_streams" in payload
    raw_streams = payload.get("post_run_file_common_streams")
    if not multi_present:
        return legacy or {"requested": False, "valid": True}
    if not isinstance(raw_streams, list):
        streams = [legacy] if legacy is not None else []
        return {
            "requested": True,
            "valid": False,
            "mode": "atomic_multi",
            "errors": ["post_run_file_common_streams must be an array"],
            "streams": streams,
        }
    if not raw_streams:
        return legacy or {"requested": False, "valid": True, "mode": "atomic_multi", "streams": []}

    streams: list[dict[str, Any]] = []
    if legacy is not None:
        streams.append(legacy)
    aggregate_errors: list[str] = []
    for index, item in enumerate(raw_streams):
        if not isinstance(item, dict):
            aggregate_errors.append(f"post_run_file_common_streams[{index}] must be an object")
            continue
        if "target" in item or "target_name" in item:
            aggregate_errors.append(
                f"post_run_file_common_streams[{index}]: caller-selected targets are forbidden"
            )
        stream_type = str(item.get("stream_type") or "").strip()
        contract = _single_post_run_stream_plan(
            source_value=item.get("source"),
            stream_type=stream_type,
            report_root=report_root,
            expected_report_root=expected_report_root,
            pre_capture={
                "path": item.get("pre_capture_path"),
                "sha256": str(item.get("pre_capture_sha256") or "").lower(),
                "bytes": item.get("pre_capture_bytes"),
                "lines": item.get("pre_capture_lines"),
            },
        )
        streams.append(contract)
        aggregate_errors.extend(
            f"post_run_file_common_streams[{index}]: {error}"
            for error in contract.get("errors") or []
        )

    aggregate_errors.extend(_multi_stream_binding_errors(streams))

    if legacy is not None:
        aggregate_errors.extend(legacy.get("errors") or [])
    return {
        "requested": True,
        "valid": not aggregate_errors,
        "mode": "atomic_multi",
        "errors": aggregate_errors,
        "streams": streams,
    }


def _governed_recovery_report_root(work_item_id: Any) -> Path:
    value = str(work_item_id or "").strip()
    if (
        not value
        or value in {".", ".."}
        or any(character in value for character in ("/", "\\", ":", "\x00"))
    ):
        raise ValueError(f"invalid work_item_id for governed report root: {value!r}")
    root = DEFAULT_REPORTS_WORK_ITEMS / value
    if root.resolve().parent != DEFAULT_REPORTS_WORK_ITEMS.resolve():
        raise ValueError("work_item_id escapes the governed reports/work_items root")
    return root


def _revalidate_serialized_stream_item(
    serialized: Any,
    *,
    work_item_id: str,
    legacy_q08_trades: bool,
    index: int,
) -> dict[str, Any]:
    if not isinstance(serialized, dict):
        return {
            "requested": True,
            "valid": False,
            "errors": [f"serialized stream {index} must be an object"],
        }
    item = dict(serialized)
    errors: list[str] = []
    stream_type = str(item.get("stream_type") or "").strip()
    if legacy_q08_trades and not stream_type:
        stream_type = "q08_trades"
    governed_root = _allowed_file_common_stream_roots().get(stream_type)
    if governed_root is None:
        errors.append(f"unsupported serialized stream_type: {stream_type!r}")

    source_text = str(item.get("source") or "").strip()
    target_text = str(item.get("target") or "").strip()
    source = Path(source_text)
    target = Path(target_text)
    if not source_text or not source.is_absolute():
        errors.append("serialized post-run source must be an absolute path")
    if ".." in source.parts:
        errors.append("serialized post-run source contains parent traversal")
    if source.suffix.lower() != ".jsonl" or source.name.lower() == ".jsonl":
        errors.append("serialized post-run source must be a named JSONL file")
    if governed_root is not None and source_text:
        try:
            if source.resolve().parent != governed_root.resolve():
                errors.append(
                    f"serialized source is outside the governed FILE_COMMON {stream_type} directory"
                )
        except OSError as exc:
            errors.append(f"serialized source cannot be resolved: {exc}")

    expected_report_root = _governed_recovery_report_root(work_item_id)
    expected_target = expected_report_root / f"{stream_type}_{source.stem}.timer_v2.jsonl"
    if not target_text or not target.is_absolute():
        errors.append("serialized post-run target must be an absolute path")
    if ".." in target.parts:
        errors.append("serialized post-run target contains parent traversal")
    if target_text:
        try:
            if _path_identity(target) != _path_identity(expected_target):
                errors.append(
                    "serialized post-run target is not the exact derived governed target: "
                    f"{expected_target}"
                )
        except OSError as exc:
            errors.append(f"serialized target cannot be resolved: {exc}")
    if target.exists():
        errors.append(
            "serialized post-run target already exists; possible crash residue requires operator review"
        )

    item.update({
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "stream_type": stream_type,
        "source": source_text,
        "target": target_text,
    })
    return item


def _revalidate_serialized_post_run_stream_contract(
    serialized: Any, *, work_item_id: str
) -> dict[str, Any]:
    """Rebuild recovery trust from governed paths, never serialized validity."""
    if not isinstance(serialized, dict):
        return {
            "requested": True,
            "valid": False,
            "mode": "atomic_multi",
            "errors": ["serialized harvest contract must be an object"],
            "streams": [],
        }
    if "streams" not in serialized:
        return _revalidate_serialized_stream_item(
            serialized,
            work_item_id=work_item_id,
            legacy_q08_trades=True,
            index=0,
        )
    raw_streams = serialized.get("streams")
    if not isinstance(raw_streams, list) or not raw_streams:
        return {
            "requested": True,
            "valid": False,
            "mode": "atomic_multi",
            "errors": ["serialized multi-stream harvest contract must contain streams"],
            "streams": [],
        }
    streams = [
        _revalidate_serialized_stream_item(
            item,
            work_item_id=work_item_id,
            legacy_q08_trades=False,
            index=index,
        )
        for index, item in enumerate(raw_streams)
    ]
    errors = [
        f"serialized stream {index}: {error}"
        for index, item in enumerate(streams)
        for error in item.get("errors") or []
    ]
    errors.extend(_multi_stream_binding_errors(streams))
    return {
        "requested": True,
        "valid": not errors,
        "mode": "atomic_multi",
        "errors": errors,
        "streams": streams,
    }


def _publication_receipt(
    *,
    published: list[Path] | None = None,
    published_before_rollback: list[Path] | None = None,
    rollback_attempted: bool = False,
    rollback_complete: bool | None = None,
) -> dict[str, Any]:
    published = published or []
    published_before_rollback = published_before_rollback or []
    return {
        "per_target_publish": "atomic_os_replace",
        "physically_atomic_across_targets": False,
        "rollback_on_caught_baseexception": True,
        "process_crash_policy": (
            "FAIL_CLOSED: a process/power crash can leave a published subset; any existing "
            "governed target blocks retry and recovery pending operator review"
        ),
        "published_targets": [str(path) for path in published],
        "published_before_rollback": [str(path) for path in published_before_rollback],
        "rollback_attempted": rollback_attempted,
        "rollback_complete": rollback_complete,
    }


def _harvest_post_run_stream(
    contract: dict[str, Any], *, worker_started_wall_ns: int
) -> dict[str, Any]:
    """Publish a coordinated, all-valid set of fresh FILE_COMMON streams.

    Legacy single-stream contracts keep their historical result shape.  A
    multi-stream contract uses a two-phase stage/verify/publish sequence and
    rolls back every published target on a caught ``BaseException``.  Each
    ``os.replace`` is atomic, but multiple targets are not physically atomic
    across a process/power crash.  Crash residue therefore blocks all retries
    fail-closed until an operator adjudicates it; the receipt states this bound.
    """
    if not contract.get("requested"):
        return {"requested": False, "valid": True}
    is_multi = isinstance(contract.get("streams"), list)
    stream_contracts = list(contract.get("streams") or []) if is_multi else [contract]
    batch = _harvest_post_run_stream_batch(
        stream_contracts,
        worker_started_wall_ns=worker_started_wall_ns,
        contract_valid=bool(contract.get("valid")),
        contract_errors=list(contract.get("errors") or []),
    )
    if not is_multi:
        single = batch["streams"][0]
        single["publication"] = batch["publication"]
        return single
    return batch


def _inspect_post_run_stream(
    contract: dict[str, Any], *, worker_started_wall_ns: int
) -> tuple[dict[str, Any], Path | None, Path | None]:
    result: dict[str, Any] = {
        "requested": True,
        "valid": False,
        "stream_type": contract.get("stream_type"),
        "source": contract.get("source"),
        "target": contract.get("target"),
        "pre_run_source": contract.get("pre_run_source"),
        "pre_v2_capture": contract.get("pre_v2_capture"),
    }
    try:
        if not contract.get("valid"):
            raise RuntimeError(f"invalid harvest contract: {contract.get('errors')}")
        source = Path(str(contract["source"]))
        target = Path(str(contract["target"]))
        post_source = _stream_fingerprint(source)
        result["post_run_source"] = post_source
        if not post_source.get("exists"):
            raise RuntimeError("post-run FILE_COMMON stream is missing")
        pre_source = contract.get("pre_run_source") or {}
        if int(post_source.get("mtime_ns") or 0) < worker_started_wall_ns - 2_000_000_000:
            raise RuntimeError("post-run FILE_COMMON stream predates the isolated worker")
        same_preflight_content = (
            pre_source.get("exists")
            and post_source.get("sha256") == pre_source.get("sha256")
        )
        same_preflight_mtime = (
            pre_source.get("exists")
            and int(post_source.get("mtime_ns") or 0) <= int(pre_source.get("mtime_ns") or 0)
        )
        if same_preflight_content and same_preflight_mtime:
            raise RuntimeError("post-run FILE_COMMON stream is unchanged from controller preflight")
        capture_sha = str((contract.get("pre_v2_capture") or {}).get("sha256") or "").lower()
        if capture_sha and post_source.get("sha256") == capture_sha:
            raise RuntimeError("post-run FILE_COMMON stream equals the pre-v2 capture")
        if target.exists():
            raise FileExistsError(f"post-run evidence target already exists: {target}")
        result["content_identical_but_rewritten"] = bool(same_preflight_content)
        return result, source, target
    except Exception as exc:
        result["error"] = str(exc)
        return result, None, None


def _harvest_post_run_stream_batch(
    contracts: list[dict[str, Any]],
    *,
    worker_started_wall_ns: int,
    contract_valid: bool,
    contract_errors: list[str],
) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    batch_errors = list(contract_errors)
    if not contracts:
        return {
            "requested": True,
            "valid": False,
            "mode": "atomic_multi",
            "errors": batch_errors or ["requested multi-stream contract contains no streams"],
            "streams": [],
            "publication": _publication_receipt(),
        }

    # Recheck role, run stem and path identities at harvest time so a malformed
    # serialized contract cannot mix evidence even if its ``valid`` bit is true.
    batch_errors.extend(_multi_stream_binding_errors(contracts))

    if not contract_valid or batch_errors:
        error = f"invalid governed harvest contract: {batch_errors}"
        for item in contracts:
            results.append({
                "requested": True,
                "valid": False,
                "stream_type": item.get("stream_type"),
                "source": item.get("source"),
                "target": item.get("target"),
                "pre_run_source": item.get("pre_run_source"),
                "pre_v2_capture": item.get("pre_v2_capture"),
                "error": error,
            })
        return {
            "requested": True,
            "valid": False,
            "mode": "atomic_multi",
            "errors": batch_errors or [error],
            "streams": results,
            "publication": _publication_receipt(),
        }

    resolved: list[tuple[Path, Path]] = []
    for item in contracts:
        result, source, target = _inspect_post_run_stream(
            item, worker_started_wall_ns=worker_started_wall_ns
        )
        results.append(result)
        if source is not None and target is not None:
            resolved.append((source, target))

    if len(resolved) != len(contracts):
        failed = [str(item.get("error")) for item in results if item.get("error")]
        abort_error = "coordinated harvest aborted before staging: " + "; ".join(failed)
        for item in results:
            item.setdefault("error", "atomic batch aborted because another requested stream was invalid")
        return {
            "requested": True,
            "valid": False,
            "mode": "atomic_multi",
            "errors": [abort_error],
            "streams": results,
            "publication": _publication_receipt(),
        }

    staged: list[tuple[Path, Path]] = []
    publish_attempted: list[tuple[Path, str]] = []
    published_before_rollback: list[Path] = []
    rollback_attempted = False
    rollback_complete: bool | None = None
    active_index = -1
    try:
        for active_index, ((source, target), result) in enumerate(zip(resolved, results)):
            target.parent.mkdir(parents=True, exist_ok=True)
            tmp = target.with_name(
                f"{target.name}.{os.getpid()}.{active_index}.{time.time_ns()}.tmp"
            )
            staged.append((tmp, target))
            with source.open("rb") as source_handle, tmp.open("xb") as target_handle:
                shutil.copyfileobj(source_handle, target_handle, length=1024 * 1024)
                target_handle.flush()
                os.fsync(target_handle.fileno())
            staged_fingerprint = _stream_fingerprint(tmp)
            result["staged"] = staged_fingerprint
            if staged_fingerprint.get("sha256") != result["post_run_source"].get("sha256"):
                raise RuntimeError("FILE_COMMON source changed during evidence staging")

        # All sources must remain byte- and metadata-stable until the full set
        # has been staged.  This closes cross-stream torn-snapshot evidence.
        for active_index, ((source, _target), result) in enumerate(zip(resolved, results)):
            post_stage = _stream_fingerprint(source)
            result["post_stage_source"] = post_stage
            if post_stage != result["post_run_source"]:
                raise RuntimeError("FILE_COMMON source changed during coordinated batch staging")

        for active_index, (tmp, target) in enumerate(staged):
            if target.exists():
                raise FileExistsError(f"post-run evidence target appeared during staging: {target}")
            expected_sha = str(results[active_index]["post_run_source"].get("sha256") or "")
            # Record the intent before replace: a BaseException can be raised
            # after the OS completed the rename but before Python returns.
            publish_attempted.append((target, expected_sha))
            os.replace(tmp, target)

        for active_index, ((_source, target), result) in enumerate(zip(resolved, results)):
            harvested = _stream_fingerprint(target)
            if harvested.get("sha256") != result["post_run_source"].get("sha256"):
                raise RuntimeError("published evidence hash differs from FILE_COMMON source")
            result.update({"valid": True, "harvested": harvested})
    except BaseException as exc:
        failure = f"{type(exc).__name__}: {exc}"
        batch_errors.append(failure)
        if 0 <= active_index < len(results):
            results[active_index]["error"] = failure
        rollback_attempted = True
        rollback_errors: list[str] = []
        for target, _expected_sha in publish_attempted:
            try:
                if target.exists():
                    published_before_rollback.append(target)
            except BaseException as inspect_exc:
                rollback_errors.append(
                    f"cannot inspect {target}: {type(inspect_exc).__name__}: {inspect_exc}"
                )
        for target, expected_sha in reversed(publish_attempted):
            try:
                if not target.exists():
                    continue
                actual_sha = sha256_file(target)
                if actual_sha != expected_sha:
                    rollback_errors.append(
                        f"refusing to delete unexpected target content {target}: "
                        f"expected={expected_sha} actual={actual_sha}"
                    )
                    continue
                target.unlink()
            except BaseException as rollback_exc:
                rollback_errors.append(
                    f"{target}: {type(rollback_exc).__name__}: {rollback_exc}"
                )
        remaining_published: list[Path] = []
        for target, _expected_sha in publish_attempted:
            try:
                if target.exists():
                    remaining_published.append(target)
            except BaseException as inspect_exc:
                rollback_errors.append(
                    f"cannot inspect {target}: {type(inspect_exc).__name__}: {inspect_exc}"
                )
        rollback_complete = not rollback_errors and not remaining_published
        if rollback_errors:
            batch_errors.extend(f"rollback failed: {error}" for error in rollback_errors)
        for result in results:
            result["valid"] = False
            result.pop("harvested", None)
            result.setdefault("error", "coordinated batch publication rolled back")
    finally:
        cleanup_errors: list[str] = []
        for tmp, _target in staged:
            try:
                tmp.unlink(missing_ok=True)
            except BaseException as cleanup_exc:
                cleanup_errors.append(
                    f"{tmp}: {type(cleanup_exc).__name__}: {cleanup_exc}"
                )
        batch_errors.extend(f"temporary cleanup failed: {error}" for error in cleanup_errors)

    remaining_published = []
    for target, _expected_sha in publish_attempted:
        try:
            if target.exists():
                remaining_published.append(target)
        except BaseException as inspect_exc:
            batch_errors.append(
                f"cannot inspect published target {target}: "
                f"{type(inspect_exc).__name__}: {inspect_exc}"
            )

    return {
        "requested": True,
        "valid": not batch_errors and all(item.get("valid") for item in results),
        "mode": "atomic_multi",
        "errors": batch_errors,
        "streams": results,
        "publication": _publication_receipt(
            published=remaining_published,
            published_before_rollback=published_before_rollback,
            rollback_attempted=rollback_attempted,
            rollback_complete=rollback_complete,
        ),
    }


def recover_harvest_from_receipt(
    root: Path,
    *,
    source_receipt_path: Path,
    expected_source_receipt_sha256: str,
    recovery_receipt_path: Path,
) -> dict[str, Any]:
    """Recover only the evidence copy from a completed isolated-run receipt.

    This path cannot rerun or mutate a work item.  It exists for a controller
    harvest false-negative and authenticates the exact original receipt, its
    post-run DB state, the unchanged Factory-OFF flag and a quiet tester fleet.
    Serialized validity and paths are untrusted: every source, derived target,
    stream role and shared run stem is independently revalidated before lock
    acquisition, and target existence is checked again before publication.
    """
    if not source_receipt_path.is_file():
        raise FileNotFoundError(f"source receipt missing: {source_receipt_path}")
    source_receipt_sha = sha256_file(source_receipt_path)
    _require_equal(
        "source receipt SHA-256", expected_source_receipt_sha256, source_receipt_sha
    )
    receipt = json.loads(source_receipt_path.read_text(encoding="utf-8"))
    post_item = receipt.get("post_work_item") or {}
    failed_harvest = receipt.get("post_run_stream") or {}
    if receipt.get("mode") != "apply" or int(receipt.get("worker_exit_code", -1)) != 0:
        raise RuntimeError("source receipt is not a completed worker execution")
    if post_item.get("status") != "done" or post_item.get("verdict") != "PASS":
        raise RuntimeError("source receipt does not bind a done/PASS work item")
    if not failed_harvest.get("requested") or failed_harvest.get("valid") is not False:
        raise RuntimeError("source receipt is not an eligible failed harvest")
    serialized_contract = (receipt.get("preflight") or {}).get("post_run_stream") or {}
    try:
        contract = _revalidate_serialized_post_run_stream_contract(
            serialized_contract, work_item_id=str(post_item.get("id") or "")
        )
    except (OSError, ValueError) as exc:
        raise RuntimeError(f"serialized recovery harvest contract is invalid: {exc}") from exc
    if not contract.get("valid"):
        raise RuntimeError(
            f"serialized recovery harvest contract is invalid: {contract.get('errors')}"
        )

    flag = root / "state" / "FACTORY_OFF.flag"
    db = root / DEFAULT_DB_REL
    lock_path = path_for_factory_flag(flag)
    with FactoryMutationLock(
        lock_path, owner=f"isolated_harvest_recovery:{post_item.get('id')}"
    ):
        _require_equal("FACTORY_OFF SHA-256", receipt["factory_off_sha256"], sha256_file(flag))
        _require_equal(
            "post-run logical DB state SHA-256",
            receipt["post_db_state_sha256"],
            sqlite_state_sha256(db),
        )
        processes = _factory_processes()
        if processes:
            raise RuntimeError(f"factory terminal/tester processes are present: {len(processes)}")
        started = dt.datetime.fromisoformat(str(receipt["started_at_utc"]))
        if started.tzinfo is None:
            raise RuntimeError("source receipt started_at_utc is not timezone-aware")
        started_ns = int(started.timestamp() * 1_000_000_000)
        contract_streams = (
            list(contract.get("streams") or [])
            if isinstance(contract.get("streams"), list)
            else [contract]
        )
        failed_streams = (
            list(failed_harvest.get("streams") or [])
            if isinstance(failed_harvest.get("streams"), list)
            else [failed_harvest]
        )
        if not contract_streams or len(contract_streams) != len(failed_streams):
            raise RuntimeError(
                "source receipt does not bind one failed result per requested stream"
            )
        for index, (stream_contract, failed_stream) in enumerate(
            zip(contract_streams, failed_streams)
        ):
            if str(stream_contract.get("source") or "") != str(
                failed_stream.get("source") or ""
            ):
                raise RuntimeError(
                    f"source receipt stream {index} contract/result source mismatch"
                )
            if str(stream_contract.get("target") or "") != str(
                failed_stream.get("target") or ""
            ):
                raise RuntimeError(
                    f"source receipt stream {index} contract/result target mismatch"
                )
            recorded = failed_stream.get("post_run_source")
            if not isinstance(recorded, dict) or recorded.get("exists") is not True:
                raise RuntimeError(
                    f"source receipt stream {index} has no completed post-run fingerprint"
                )
            current = _stream_fingerprint(Path(str(stream_contract["source"])))
            if current != recorded:
                raise RuntimeError(
                    f"source receipt stream {index} changed after the original harvest"
                )
        harvest = _harvest_post_run_stream(
            contract, worker_started_wall_ns=started_ns
        )
        result = {
            "schema_version": 1,
            "mode": "harvest_recovery",
            "recovered_at_utc": utc_now(),
            "source_receipt_path": str(source_receipt_path),
            "source_receipt_sha256": source_receipt_sha,
            "controller_path": str(Path(__file__).resolve()),
            "controller_sha256": sha256_file(Path(__file__).resolve()),
            "work_item_id": post_item.get("id"),
            "factory_off_sha256": sha256_file(flag),
            "db_state_sha256": sqlite_state_sha256(db),
            "factory_processes": processes,
            "serialized_harvest_contract_revalidated": True,
            "revalidated_harvest_contract": contract,
            "harvest": harvest,
            "live_scope_touched": False,
            "autotrading_touched": False,
        }
        _write_receipt(recovery_receipt_path, result)
        return result


def _factory_processes() -> list[dict[str, Any]]:
    if os.name != "nt":
        return []
    command = (
        "$rows=Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe' OR Name='metatester64.exe'\" "
        "| Select-Object Name,ProcessId,ExecutablePath,CommandLine; "
        "$rows | ConvertTo-Json -Compress"
    )
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"factory process probe failed: {proc.stderr.strip()}")
    raw = proc.stdout.strip()
    if not raw:
        return []
    parsed = json.loads(raw)
    rows = parsed if isinstance(parsed, list) else [parsed]
    found: list[dict[str, Any]] = []
    for row in rows:
        if str(row.get("Name") or "").lower() == "metatester64.exe":
            found.append(row)
            continue
        haystack = str(row.get("ExecutablePath") or row.get("CommandLine") or "")
        normalized = haystack.replace("/", "\\").upper()
        if any(f"\\MT5\\T{i}\\" in normalized or f"\\MT5\\T{i}_" in normalized for i in range(1, 11)):
            found.append(row)
    return found


def _ftmo_work_core_plan(
    *,
    row: sqlite3.Row,
    hold: sqlite3.Row | None,
    payload: dict[str, Any],
    work_item_id: str,
    terminal: str,
    requested_timeout_minutes: float | None,
) -> dict[str, Any]:
    if payload.get("measurement_contract") != FTMO_BOOK3_MEASUREMENT_CONTRACT:
        return {"requested": False, "valid": True, "errors": []}
    errors: list[str] = []
    rung = str(payload.get("measurement_rung") or "")
    core = FTMO_BOOK3_WORK_CORE.get(rung)
    if core is None:
        return {
            "requested": True,
            "valid": False,
            "errors": [f"FTMO Book-3 rung has no exact work core: {rung!r}"],
        }
    exact = {
        "payload schema": (
            payload.get("schema"),
            "qm.ftmo-book3-q02-work-item-payload/v1",
        ),
        "evidence vintage": (
            payload.get("evidence_vintage"),
            FTMO_BOOK3_EVIDENCE_VINTAGE,
        ),
        "money basis": (
            payload.get("money_basis"),
            FTMO_BOOK3_MONEY_BASIS,
        ),
        "measurement sequence": (payload.get("measurement_sequence"), core["sequence"]),
        "terminal": (terminal, "T10"),
        "payload terminal": (str(payload.get("terminal") or "").upper(), "T10"),
        "phase": (row["phase"], "Q02"),
        "EA": (row["ea_id"], core["ea_id"]),
        "symbol": (row["symbol"], core["symbol"]),
        "host timeframe": (payload.get("host_timeframe"), core["period"]),
        "EA directory": (payload.get("ea_dir_name"), core["ea_dir_name"]),
        "setfile basename": (
            Path(str(row["setfile_path"] or "")).name,
            core["set_name"],
        ),
        "from date": (payload.get("from_date"), "2018.07.02"),
        "to date": (payload.get("to_date"), "2025.12.31"),
        "tester model": (payload.get("model"), 4),
        "tester currency": (payload.get("tester_currency"), "USD"),
        "tester deposit": (payload.get("tester_deposit"), 100000),
        "risk mode": (payload.get("risk_mode"), "RISK_FIXED"),
        "fixed risk": (payload.get("risk_fixed"), 1000),
        "percent risk": (payload.get("risk_percent"), 0),
        "isolated_only": (payload.get("isolated_only"), True),
        "auto_enqueue": (payload.get("auto_enqueue"), False),
        "auto_promote": (payload.get("auto_promote"), False),
        "next_phase": (payload.get("next_phase"), None),
        "factory_on_authorized": (payload.get("factory_on_authorized"), False),
        "required fidelity stage": (
            payload.get("required_fidelity_stage"),
            None if core["sequence"] < 2 else (core["sequence"] // 2) - 1,
        ),
    }
    for label, (actual, expected) in exact.items():
        if actual != expected:
            errors.append(
                f"FTMO Book-3 {label} mismatch: expected={expected!r} actual={actual!r}"
            )
    avoid = [str(value).upper() for value in (payload.get("avoid_terminals") or [])]
    expected_avoid = [
        "T1",
        "T2",
        "T3",
        "T4",
        "T5",
        "T6",
        "T7",
        "T8",
        "T9",
        "T_LIVE",
    ]
    if avoid != expected_avoid:
        errors.append("FTMO Book-3 avoid_terminals is not the exact ordered deny-list")
    execution_sha = payload.get("execution_bundle_sha256")
    expected_work_id = _content_uuid(execution_sha)
    if expected_work_id is None or work_item_id != expected_work_id:
        errors.append(
            "FTMO Book-3 work-item ID is not content-addressed to execution_bundle_sha256"
        )
    if hold is None:
        errors.append("FTMO Book-3 exact maintenance hold is missing")
    else:
        if hold["hold_code"] != FTMO_BOOK3_HOLD_CODE:
            errors.append("FTMO Book-3 hold_code mismatch")
        if hold["reason"] != FTMO_BOOK3_HOLD_REASON:
            errors.append("FTMO Book-3 hold reason mismatch")
        if int(hold["active"] or 0) != 1:
            errors.append("FTMO Book-3 hold is not active")
        if int(hold["release_on_restart"] or 0) != 0:
            errors.append("FTMO Book-3 hold is releasing on restart")
    payload_timeout = payload.get("timeout_min")
    if payload_timeout != 240:
        errors.append(
            f"FTMO Book-3 payload timeout mismatch: expected=240 actual={payload_timeout!r}"
        )
    if requested_timeout_minutes is not None and float(requested_timeout_minutes) != 240.0:
        errors.append(
            "FTMO Book-3 requested timeout is not exactly the payload-bound 240 minutes"
        )
    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "rung": rung,
        "core": core,
        "payload_timeout_minutes": payload_timeout,
        "requested_timeout_minutes": requested_timeout_minutes,
    }


def _ftmo_ladder_order_plan(
    conn: sqlite3.Connection, *, current_work_item_id: str, payload: dict[str, Any]
) -> dict[str, Any]:
    if payload.get("measurement_contract") != FTMO_BOOK3_MEASUREMENT_CONTRACT:
        return {"requested": False, "valid": True, "errors": [], "rungs": []}
    errors: list[str] = []
    by_sequence: dict[int, list[dict[str, Any]]] = {index: [] for index in range(6)}
    rows = conn.execute(
        "SELECT id,phase,ea_id,symbol,status,verdict,claimed_by,evidence_path,payload_json "
        "FROM work_items"
    ).fetchall()
    for candidate in rows:
        raw = str(candidate["payload_json"] or "{}")
        if len(raw.encode("utf-8")) > MAX_PAYLOAD_BYTES:
            continue
        try:
            candidate_payload = _strict_json_object(
                raw.encode("utf-8"), label=f"ladder payload {candidate['id']}"
            )
        except (TypeError, ValueError, RuntimeError):
            continue
        if candidate_payload.get("measurement_contract") != FTMO_BOOK3_MEASUREMENT_CONTRACT:
            continue
        sequence = candidate_payload.get("measurement_sequence")
        if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence not in by_sequence:
            errors.append(f"FTMO ladder row has invalid sequence: {candidate['id']}")
            continue
        by_sequence[sequence].append(
            {
                "id": candidate["id"],
                "phase": candidate["phase"],
                "ea_id": candidate["ea_id"],
                "symbol": candidate["symbol"],
                "status": candidate["status"],
                "verdict": candidate["verdict"],
                "claimed_by": candidate["claimed_by"],
                "evidence_path": candidate["evidence_path"],
                "rung": candidate_payload.get("measurement_rung"),
                "terminal": candidate_payload.get("terminal"),
            }
        )
    for sequence in range(6):
        entries = by_sequence[sequence]
        if len(entries) != 1:
            errors.append(
                f"FTMO ladder sequence {sequence} cardinality mismatch: {len(entries)}"
            )
            continue
        entry = entries[0]
        expected_rung = next(
            code
            for code, core in FTMO_BOOK3_WORK_CORE.items()
            if core["sequence"] == sequence
        )
        core = FTMO_BOOK3_WORK_CORE[expected_rung]
        if entry["rung"] != expected_rung:
            errors.append(f"FTMO ladder sequence {sequence} rung mismatch")
        if entry["phase"] != "Q02" or entry["ea_id"] != core["ea_id"]:
            errors.append(f"FTMO ladder sequence {sequence} work core mismatch")
        if entry["symbol"] != core["symbol"] or str(entry["terminal"]).upper() != "T10":
            errors.append(f"FTMO ladder sequence {sequence} symbol/terminal mismatch")
    current_sequence = payload.get("measurement_sequence")
    if isinstance(current_sequence, int) and current_sequence in by_sequence:
        entries = by_sequence[current_sequence]
        if len(entries) == 1 and entries[0]["id"] != current_work_item_id:
            errors.append("FTMO ladder current work item is not the unique sequence row")
        for sequence in range(current_sequence):
            entries = by_sequence[sequence]
            if len(entries) != 1:
                continue
            predecessor = entries[0]
            if not (
                predecessor["status"] == "done"
                and predecessor["verdict"] == "PASS"
                and predecessor["claimed_by"] is None
                and isinstance(predecessor["evidence_path"], str)
                and bool(predecessor["evidence_path"].strip())
            ):
                errors.append(
                    "FTMO ladder predecessor is not terminal done/PASS/unclaimed with evidence: "
                    f"sequence={sequence} id={predecessor['id']}"
                )
    else:
        errors.append("FTMO ladder current sequence is invalid")
    flattened = [entry for sequence in range(6) for entry in by_sequence[sequence]]
    return {
        "requested": True,
        "valid": not errors,
        "errors": errors,
        "current_sequence": current_sequence,
        "rungs": flattened,
    }


def _strict_json_object(raw: bytes, *, label: str) -> dict[str, Any]:
    def no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    def reject_constant(value: str) -> None:
        raise ValueError(f"non-finite JSON number is forbidden: {value}")

    try:
        parsed = json.loads(
            raw.decode("utf-8-sig", errors="strict"),
            object_pairs_hook=no_duplicates,
            parse_constant=reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise RuntimeError(f"{label} is not strict duplicate-free UTF-8 JSON: {exc}") from exc
    if not isinstance(parsed, dict):
        raise RuntimeError(f"{label} must be a JSON object")
    return parsed


def _runtime_source_expected_hash(payload: dict[str, Any], role: str) -> str | None:
    rows = payload.get("runtime_source_artifacts")
    if not isinstance(rows, list):
        return None
    selected = [
        item
        for item in rows
        if isinstance(item, dict) and item.get("role") == role
    ]
    if len(selected) != 1:
        return None
    value = selected[0].get("sha256")
    return value if isinstance(value, str) and _SHA256_RE.fullmatch(value) else None


def _runtime_source_expected_artifact(
    payload: dict[str, Any], role: str
) -> dict[str, Any] | None:
    rows = payload.get("runtime_source_artifacts")
    if not isinstance(rows, list):
        return None
    selected = [
        item
        for item in rows
        if isinstance(item, dict) and item.get("role") == role
    ]
    if len(selected) != 1:
        return None
    item = selected[0]
    if (
        set(item) != {"role", "path", "sha256", "bytes"}
        or not isinstance(item.get("path"), str)
        or not Path(item["path"]).is_absolute()
        or not isinstance(item.get("sha256"), str)
        or not _SHA256_RE.fullmatch(item["sha256"])
        or isinstance(item.get("bytes"), bool)
        or not isinstance(item.get("bytes"), int)
        or item["bytes"] <= 0
    ):
        return None
    return {
        "path": item["path"],
        "sha256": item["sha256"],
        "bytes": item["bytes"],
    }


def _exact_finite_number(value: Any, expected: float) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(float(value))
        and float(value) == expected
    )


def _fidelity_utc(value: Any) -> dt.datetime | None:
    if type(value) is not str:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None or parsed.utcoffset() != dt.timedelta(0):
        return None
    return parsed


_FIDELITY_FIELD_NOT_SUPPLIED = object()


def _fidelity_bound_file_errors(
    *,
    label: str,
    path_value: Any,
    sha_value: Any,
    byte_value: Any = _FIDELITY_FIELD_NOT_SUPPLIED,
    line_value: Any = _FIDELITY_FIELD_NOT_SUPPLIED,
) -> list[str]:
    errors: list[str] = []
    if type(path_value) is not str or not Path(path_value).is_absolute():
        return [f"{label} path is not an absolute string"]
    if type(sha_value) is not str or not _SHA256_RE.fullmatch(sha_value):
        return [f"{label} SHA-256 is not canonical lower-hex"]
    byte_required = byte_value is not _FIDELITY_FIELD_NOT_SUPPLIED
    line_required = line_value is not _FIDELITY_FIELD_NOT_SUPPLIED
    if byte_required and (type(byte_value) is not int or byte_value <= 0):
        errors.append(f"{label} bytes must be a positive integer")
    if line_required and (type(line_value) is not int or line_value <= 0):
        errors.append(f"{label} lines must be a positive integer")
    path = Path(path_value)
    if not path.is_file():
        errors.append(f"{label} file is missing: {path}")
        return errors
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != sha_value:
        errors.append(f"{label} file SHA-256 mismatch")
    if byte_required and len(raw) != byte_value:
        errors.append(f"{label} file byte count mismatch")
    if line_required and len(raw.splitlines()) != line_value:
        errors.append(f"{label} file line count mismatch")
    return errors


def _validate_ftmo_gate_operand(
    operand: Any,
    *,
    role: str,
    stage: int,
    expected_work_item_id: Any,
    expected_source_commit: Any,
    expected_execution_identity: Any,
    expected_framework_include_sha256: Any,
    expected_evidence_path: Any,
    expected_runtime_sources: dict[str, dict[str, Any]],
    errors: list[str],
) -> dict[str, Any]:
    label = f"fidelity receipt {role} operand"
    if not isinstance(operand, dict):
        errors.append(f"{label} must be an object")
        return {}
    expected_keys = {
        "role",
        "rung",
        "sequence",
        "receipt_path",
        "receipt_sha256",
        "work_item_id",
        "started_at_utc",
        "completed_at_utc",
        "source_commit",
        "factory_off_sha256",
        "source_binding",
        "runner_artifacts",
        "execution_input_artifacts_sha256",
        "execution_input_observed_bundle_sha256",
        "execution_input_artifact_count",
        "post_payload_sha256",
        "post_evidence",
        "q08_trades",
        "magic",
        "symbol",
    }
    if set(operand) != expected_keys:
        errors.append(f"{label} fields are not exact")
    member = FTMO_BOOK3_FIDELITY_STAGE_MEMBERS.get(stage, {}).get(role, {})
    exact_values = {
        "role": role,
        "rung": member.get("rung"),
        "work_item_id": expected_work_item_id,
        "source_commit": expected_source_commit,
        "execution_input_artifacts_sha256": expected_execution_identity,
        "magic": member.get("magic"),
        "symbol": member.get("symbol"),
    }
    for key, expected in exact_values.items():
        if operand.get(key) != expected:
            errors.append(f"{label} {key} mismatch")
    if type(operand.get("sequence")) is not int or operand.get("sequence") != member.get(
        "sequence"
    ):
        errors.append(f"{label} sequence mismatch or type substitution")
    if type(operand.get("magic")) is not int:
        errors.append(f"{label} magic must be an integer")
    for key in (
        "receipt_sha256",
        "factory_off_sha256",
        "execution_input_artifacts_sha256",
        "execution_input_observed_bundle_sha256",
        "post_payload_sha256",
    ):
        value = operand.get(key)
        if type(value) is not str or not _SHA256_RE.fullmatch(value):
            errors.append(f"{label} {key} is not canonical lower-hex")
    if (
        type(operand.get("execution_input_artifact_count")) is not int
        or operand.get("execution_input_artifact_count")
        != FTMO_BOOK3_EXPECTED_EXECUTION_INPUT_COUNT
    ):
        errors.append(f"{label} execution-input count mismatch or type substitution")
    started = _fidelity_utc(operand.get("started_at_utc"))
    completed = _fidelity_utc(operand.get("completed_at_utc"))
    if started is None or completed is None or started > completed:
        errors.append(f"{label} timestamps are invalid or out of order")
    errors.extend(
        _fidelity_bound_file_errors(
            label=f"{label} runner receipt",
            path_value=operand.get("receipt_path"),
            sha_value=operand.get("receipt_sha256"),
        )
    )

    source_binding = operand.get("source_binding")
    expected_source_binding_keys = {
        "framework_include_tree",
        "preregistration",
        "isolated_runner",
        "terminal_worker",
        "preparation_controller",
        "runtime_sources",
    }
    if not isinstance(source_binding, dict) or set(source_binding) != expected_source_binding_keys:
        errors.append(f"{label} source_binding fields are not exact")
        source_binding = {}
    direct_to_runtime = {
        "preregistration": "preregistration",
        "isolated_runner": "isolated_runner",
        "terminal_worker": "terminal_worker",
        "preparation_controller": "preparation_controller",
    }
    for direct, runtime_role in direct_to_runtime.items():
        row = source_binding.get(direct)
        expected = expected_runtime_sources.get(runtime_role)
        if not isinstance(row, dict) or set(row) != {"path", "sha256"}:
            errors.append(f"{label} {direct} binding fields are not exact")
            continue
        if (
            type(row.get("path")) is not str
            or not Path(row["path"]).is_absolute()
            or type(row.get("sha256")) is not str
            or not _SHA256_RE.fullmatch(row["sha256"])
        ):
            errors.append(f"{label} {direct} binding types are invalid")
            continue
        if expected is None or (
            os.path.normcase(os.path.abspath(row["path"]))
            != os.path.normcase(os.path.abspath(expected["path"]))
            or row["sha256"] != expected["sha256"]
        ):
            errors.append(f"{label} {direct} binding mismatches expected runtime source")
    tree = source_binding.get("framework_include_tree")
    if not isinstance(tree, dict) or set(tree) != {"path", "sha256", "file_count"}:
        errors.append(f"{label} framework include binding fields are not exact")
    elif (
        type(tree.get("path")) is not str
        or not Path(tree["path"]).is_absolute()
        or type(tree.get("sha256")) is not str
        or not _SHA256_RE.fullmatch(tree["sha256"])
        or type(tree.get("file_count")) is not int
        or tree["file_count"] <= 0
    ):
        errors.append(f"{label} framework include binding types are invalid")
    elif tree["sha256"] != expected_framework_include_sha256:
        errors.append(f"{label} framework include binding hash mismatch")

    runtime_block = source_binding.get("runtime_sources")
    if not isinstance(runtime_block, dict) or set(runtime_block) != {
        "canonical_sha256",
        "roles",
    }:
        errors.append(f"{label} runtime_sources fields are not exact")
        runtime_block = {}
    runtime_roles = runtime_block.get("roles")
    if not isinstance(runtime_roles, dict) or set(runtime_roles) != set(
        FTMO_RUNTIME_SOURCE_ROLES
    ):
        errors.append(f"{label} runtime source roles are not exact")
        runtime_roles = {}
    canonical_rows: list[dict[str, Any]] = []
    for runtime_role in FTMO_RUNTIME_SOURCE_ROLES:
        row = runtime_roles.get(runtime_role)
        expected = expected_runtime_sources.get(runtime_role)
        if not isinstance(row, dict) or set(row) != {"role", "path", "sha256", "bytes"}:
            errors.append(f"{label} runtime source {runtime_role} fields are not exact")
            continue
        if (
            row.get("role") != runtime_role
            or type(row.get("path")) is not str
            or not Path(row["path"]).is_absolute()
            or type(row.get("sha256")) is not str
            or not _SHA256_RE.fullmatch(row["sha256"])
            or type(row.get("bytes")) is not int
            or row["bytes"] <= 0
        ):
            errors.append(f"{label} runtime source {runtime_role} types are invalid")
            continue
        canonical_rows.append(dict(row))
        if expected is None or row != {"role": runtime_role, **expected}:
            errors.append(f"{label} runtime source {runtime_role} binding mismatch")
    expected_runtime_identity = canonical_sha256(
        sorted(canonical_rows, key=lambda row: (row["role"], row["path"]))
    )
    if (
        type(runtime_block.get("canonical_sha256")) is not str
        or runtime_block.get("canonical_sha256") != expected_runtime_identity
    ):
        errors.append(f"{label} runtime source canonical identity mismatch")

    artifacts = operand.get("runner_artifacts")
    if not isinstance(artifacts, dict) or set(artifacts) != {"setfile", "staged_ex5", "mq5"}:
        errors.append(f"{label} runner_artifacts fields are not exact")
    else:
        for artifact_role, row in artifacts.items():
            if (
                not isinstance(row, dict)
                or set(row) != {"path", "sha256"}
                or type(row.get("path")) is not str
                or not Path(row["path"]).is_absolute()
                or type(row.get("sha256")) is not str
                or not _SHA256_RE.fullmatch(row["sha256"])
            ):
                errors.append(f"{label} runner artifact {artifact_role} is invalid")
                continue
            errors.extend(
                _fidelity_bound_file_errors(
                    label=f"{label} runner artifact {artifact_role}",
                    path_value=row.get("path"),
                    sha_value=row.get("sha256"),
                )
            )

    evidence = operand.get("post_evidence")
    if not isinstance(evidence, dict) or set(evidence) != {
        "path",
        "resolved_path",
        "sha256",
        "bytes",
    }:
        errors.append(f"{label} post_evidence fields are not exact")
    else:
        if (
            type(expected_evidence_path) is not str
            or not expected_evidence_path.strip()
            or os.path.normcase(os.path.abspath(evidence.get("path", "")))
            != os.path.normcase(os.path.abspath(expected_evidence_path))
        ):
            errors.append(f"{label} post_evidence path does not match ladder evidence")
        if (
            type(evidence.get("resolved_path")) is not str
            or not Path(evidence["resolved_path"]).is_absolute()
            or os.path.normcase(os.path.abspath(evidence.get("path", "")))
            != os.path.normcase(os.path.abspath(evidence["resolved_path"]))
        ):
            errors.append(f"{label} post_evidence resolved path mismatch")
        errors.extend(
            _fidelity_bound_file_errors(
                label=f"{label} post evidence",
                path_value=evidence.get("path"),
                sha_value=evidence.get("sha256"),
                byte_value=evidence.get("bytes"),
            )
        )

    stream = operand.get("q08_trades")
    if not isinstance(stream, dict) or set(stream) != {
        "source",
        "target",
        "path",
        "sha256",
        "bytes",
        "lines",
        "selected_trade_count",
    }:
        errors.append(f"{label} q08_trades fields are not exact")
    else:
        if (
            type(stream.get("source")) is not str
            or not Path(stream["source"]).is_absolute()
            or type(stream.get("target")) is not str
            or not Path(stream["target"]).is_absolute()
            or type(stream.get("path")) is not str
            or not Path(stream["path"]).is_absolute()
            or os.path.normcase(os.path.abspath(stream["target"]))
            != os.path.normcase(os.path.abspath(stream["path"]))
        ):
            errors.append(f"{label} q08_trades path binding mismatch")
        selected = stream.get("selected_trade_count")
        if type(selected) is not int or selected <= 0:
            errors.append(f"{label} selected trade count must be a positive integer")
        if type(stream.get("lines")) is int and type(selected) is int and selected > stream["lines"]:
            errors.append(f"{label} selected trade count exceeds physical lines")
        errors.extend(
            _fidelity_bound_file_errors(
                label=f"{label} q08 harvest",
                path_value=stream.get("path"),
                sha_value=stream.get("sha256"),
                byte_value=stream.get("bytes"),
                line_value=stream.get("lines"),
            )
        )
    return {
        "started": started,
        "completed": completed,
        "factory_off_sha256": operand.get("factory_off_sha256"),
        "source_binding": source_binding,
        "execution_input_observed_bundle_sha256": operand.get(
            "execution_input_observed_bundle_sha256"
        ),
        "selected_trade_count": (
            stream.get("selected_trade_count") if isinstance(stream, dict) else None
        ),
    }


def _ftmo_fidelity_receipt_plan(
    payload: dict[str, Any],
    *,
    ladder_order: dict[str, Any],
    receipt_path: Path | None,
    expected_receipt_sha256: str | None,
    expected_factory_off_sha256: str | None,
) -> dict[str, Any]:
    if payload.get("measurement_contract") != FTMO_BOOK3_MEASUREMENT_CONTRACT:
        if receipt_path is not None or expected_receipt_sha256 is not None:
            return {
                "requested": True,
                "required": False,
                "valid": False,
                "errors": ["fidelity receipts are restricted to the FTMO Book-3 contract"],
            }
        return {"requested": False, "required": False, "valid": True, "errors": []}
    sequence = payload.get("measurement_sequence")
    required_stage = None if isinstance(sequence, int) and sequence < 2 else payload.get(
        "required_fidelity_stage"
    )
    expected_stage = (
        None
        if isinstance(sequence, int) and sequence < 2
        else ((sequence // 2) - 1 if isinstance(sequence, int) else None)
    )
    errors: list[str] = []
    if (
        type(expected_factory_off_sha256) is not str
        or not _SHA256_RE.fullmatch(expected_factory_off_sha256)
    ):
        errors.append("expected FACTORY_OFF SHA-256 is not canonical lower-hex")
    if payload.get("required_fidelity_stage") != expected_stage:
        errors.append(
            "payload required_fidelity_stage does not match the rung sequence"
        )
    if expected_stage is None:
        if receipt_path is not None or expected_receipt_sha256 is not None:
            errors.append("R0/J0 must not consume a prior fidelity receipt")
        return {
            "requested": receipt_path is not None or expected_receipt_sha256 is not None,
            "required": False,
            "required_stage": None,
            "valid": not errors,
            "errors": errors,
        }
    if receipt_path is None or expected_receipt_sha256 is None:
        errors.append(
            f"FTMO rung requires a hash-bound Stage-{expected_stage} PASS fidelity receipt"
        )
        return {
            "requested": False,
            "required": True,
            "required_stage": expected_stage,
            "valid": False,
            "errors": errors,
        }
    if not receipt_path.is_absolute():
        errors.append("fidelity receipt path must be absolute")
    if not isinstance(expected_receipt_sha256, str) or not _SHA256_RE.fullmatch(
        expected_receipt_sha256
    ):
        errors.append("expected fidelity receipt SHA-256 is not canonical lower-hex")
    raw: bytes | None = None
    actual_sha: str | None = None
    receipt: dict[str, Any] | None = None
    if not receipt_path.is_file():
        errors.append(f"fidelity receipt is missing: {receipt_path}")
    elif not errors:
        try:
            raw = receipt_path.read_bytes()
            if len(raw) > 16 * 1024 * 1024:
                raise RuntimeError("fidelity receipt exceeds 16 MiB")
            actual_sha = hashlib.sha256(raw).hexdigest()
            if actual_sha != expected_receipt_sha256:
                errors.append(
                    "fidelity receipt SHA-256 mismatch: "
                    f"expected={expected_receipt_sha256} actual={actual_sha}"
                )
            receipt = _strict_json_object(raw, label="fidelity receipt")
        except Exception as exc:
            errors.append(str(exc))
    rungs = {
        int(item["rung"][1:]) * 2 + (1 if str(item["rung"]).startswith("J") else 0): item
        for item in (ladder_order.get("rungs") or [])
        if isinstance(item, dict)
        and isinstance(item.get("rung"), str)
        and re.fullmatch(r"[RJ][0-2]", item["rung"])
    }
    expected_ids = {
        "standalone": (rungs.get(expected_stage * 2) or {}).get("id"),
        "joint": (rungs.get(expected_stage * 2 + 1) or {}).get("id"),
    }
    expected_evidence_paths = {
        "standalone": (rungs.get(expected_stage * 2) or {}).get("evidence_path"),
        "joint": (rungs.get(expected_stage * 2 + 1) or {}).get("evidence_path"),
    }
    expected_source_commit = payload.get("authoritative_source_commit")
    expected_execution_inputs = payload.get("execution_input_artifacts_sha256")
    expected_gate = _runtime_source_expected_artifact(payload, "fidelity_gate")
    expected_runner = _runtime_source_expected_artifact(payload, "isolated_runner")
    expected_preparation = _runtime_source_expected_artifact(
        payload, "preparation_controller"
    )
    expected_comparator = _runtime_source_expected_artifact(
        payload, "fidelity_comparator"
    )
    expected_runtime_sources = {
        role: _runtime_source_expected_artifact(payload, role)
        for role in FTMO_RUNTIME_SOURCE_ROLES
    }
    for role, artifact in expected_runtime_sources.items():
        if artifact is None:
            errors.append(f"runtime source binding is invalid or missing: {role}")
    if receipt is not None:
        expected_top_keys = {
            "schema",
            "generated_at_utc",
            "stage",
            "verdict",
            "work_item_ids",
            "source_commit",
            "execution_input_artifacts_sha256",
            "controller_path",
            "controller_sha256",
            "controller_bytes",
            "isolated_runner_sha256",
            "preparation_controller_sha256",
            "comparator_sha256",
            "comparator",
            "errors",
            "contract",
            "safety",
            "operands",
            "comparison",
            "adjudication_id",
        }
        if set(receipt) != expected_top_keys:
            errors.append("fidelity receipt top-level fields are not exact")
        if _fidelity_utc(receipt.get("generated_at_utc")) is None:
            errors.append("fidelity receipt generated_at_utc is not a UTC timestamp")
        if type(receipt.get("stage")) is not int or receipt.get("stage") != expected_stage:
            errors.append("fidelity receipt stage mismatch or type substitution")
        if not isinstance(receipt.get("work_item_ids"), dict) or set(
            receipt.get("work_item_ids") or {}
        ) != {"standalone", "joint"}:
            errors.append("fidelity receipt work_item_ids fields are not exact")
        elif any(type(value) is not str or not value for value in receipt["work_item_ids"].values()):
            errors.append("fidelity receipt work_item_ids types are invalid")
        if type(receipt.get("controller_bytes")) is not int or receipt.get(
            "controller_bytes"
        ) <= 0:
            errors.append("fidelity receipt controller_bytes must be a positive integer")
        exact = {
            "schema": "qm.ftmo-book3-fidelity-adjudication-receipt/v2",
            "verdict": "PASS",
            "errors": [],
            "work_item_ids": expected_ids,
            "source_commit": expected_source_commit,
            "execution_input_artifacts_sha256": expected_execution_inputs,
            "controller_path": expected_gate.get("path") if expected_gate else None,
            "controller_sha256": (
                expected_gate.get("sha256") if expected_gate else None
            ),
            "controller_bytes": expected_gate.get("bytes") if expected_gate else None,
            "isolated_runner_sha256": (
                expected_runner.get("sha256") if expected_runner else None
            ),
            "preparation_controller_sha256": (
                expected_preparation.get("sha256")
                if expected_preparation
                else None
            ),
            "comparator_sha256": (
                expected_comparator.get("sha256") if expected_comparator else None
            ),
        }
        for key, expected in exact.items():
            if receipt.get(key) != expected:
                errors.append(
                    f"fidelity receipt {key} mismatch: "
                    f"expected={expected!r} actual={receipt.get(key)!r}"
                )
        expected_comparator_binding = expected_comparator or {
            "path": None,
            "sha256": None,
            "bytes": None,
        }
        comparator_binding = receipt.get("comparator")
        if (
            not isinstance(comparator_binding, dict)
            or set(comparator_binding) != {"path", "sha256", "bytes"}
            or type(comparator_binding.get("path")) is not str
            or type(comparator_binding.get("sha256")) is not str
            or type(comparator_binding.get("bytes")) is not int
            or comparator_binding != expected_comparator_binding
        ):
            errors.append("fidelity receipt comparator binding mismatch")
        contract = receipt.get("contract")
        expected_contract_keys = {
            "measurement_contract",
            "expected_execution_input_count",
            "match_rate_required",
            "unmatched_required",
            "both_operands_nonempty",
            "money_tolerance",
            "volume_tolerance",
            "price_tolerance",
            "money_basis",
        }
        if not isinstance(contract, dict) or set(contract) != expected_contract_keys:
            errors.append("fidelity receipt contract fields are not exact")
        else:
            contract_exact = {
                "measurement_contract": FTMO_BOOK3_MEASUREMENT_CONTRACT,
                "expected_execution_input_count": (
                    FTMO_BOOK3_EXPECTED_EXECUTION_INPUT_COUNT
                ),
                "both_operands_nonempty": True,
                "money_basis": FTMO_BOOK3_MONEY_BASIS,
            }
            for key, expected in contract_exact.items():
                type_valid = (
                    type(contract.get(key)) is bool
                    if key == "both_operands_nonempty"
                    else type(contract.get(key)) is int
                    if key == "expected_execution_input_count"
                    else type(contract.get(key)) is str
                )
                if not type_valid or contract.get(key) != expected:
                    errors.append(
                        f"fidelity receipt contract {key} mismatch: "
                        f"expected={expected!r} actual={contract.get(key)!r}"
                    )
            numeric_contract = {
                "match_rate_required": (1.0, float),
                "unmatched_required": (0.0, int),
                "money_tolerance": (FTMO_BOOK3_MONEY_TOLERANCE, float),
                "volume_tolerance": (FTMO_BOOK3_VOLUME_TOLERANCE, float),
                "price_tolerance": (FTMO_BOOK3_PRICE_TOLERANCE, float),
            }
            for key, (expected, expected_type) in numeric_contract.items():
                if type(contract.get(key)) is not expected_type or not _exact_finite_number(
                    contract.get(key), expected
                ):
                    errors.append(
                        f"fidelity receipt contract {key} mismatch: "
                        f"expected={expected!r} actual={contract.get(key)!r}"
                    )
        safety = receipt.get("safety")
        expected_safety = {
            "read_only_inputs": True,
            "create_only_output": True,
            "opens_factory_db": False,
            "runs_mt5": False,
            "mutates_factory_state": False,
            "touches_live_scope": False,
            "touches_autotrading": False,
        }
        if (
            not isinstance(safety, dict)
            or set(safety) != set(expected_safety)
            or any(type(value) is not bool for value in safety.values())
            or safety != expected_safety
        ):
            errors.append("fidelity receipt safety block mismatch")
        comparison = receipt.get("comparison")
        expected_comparison_keys = {
            "algorithm",
            "money_basis",
            "money_tolerance",
            "volume_tolerance",
            "price_tolerance",
            "standalone_trades",
            "joint_trades",
            "matched",
            "unmatched_standalone",
            "unmatched_joint",
            "match_rate",
            "unmatched_standalone_sample",
            "unmatched_joint_sample",
        }
        if (
            not isinstance(comparison, dict)
            or set(comparison) != expected_comparison_keys
        ):
            errors.append("fidelity receipt comparison fields are not exact")
        else:
            counts = {
                key: comparison.get(key)
                for key in ("standalone_trades", "joint_trades", "matched")
            }
            counts_valid = all(
                type(value) is int
                and value > 0
                for value in counts.values()
            )
            comparison_valid = (
                comparison.get("algorithm") == FTMO_BOOK3_FIDELITY_ALGORITHM
                and comparison.get("money_basis") == FTMO_BOOK3_MONEY_BASIS
                and type(comparison.get("algorithm")) is str
                and type(comparison.get("money_basis")) is str
                and type(comparison.get("money_tolerance")) is float
                and _exact_finite_number(
                    comparison.get("money_tolerance"),
                    FTMO_BOOK3_MONEY_TOLERANCE,
                )
                and type(comparison.get("volume_tolerance")) is float
                and _exact_finite_number(
                    comparison.get("volume_tolerance"),
                    FTMO_BOOK3_VOLUME_TOLERANCE,
                )
                and type(comparison.get("price_tolerance")) is float
                and _exact_finite_number(
                    comparison.get("price_tolerance"),
                    FTMO_BOOK3_PRICE_TOLERANCE,
                )
                and type(comparison.get("match_rate")) is float
                and _exact_finite_number(comparison.get("match_rate"), 1.0)
                and type(comparison.get("unmatched_standalone")) is int
                and comparison.get("unmatched_standalone") == 0
                and type(comparison.get("unmatched_joint")) is int
                and comparison.get("unmatched_joint") == 0
                and counts_valid
                and counts["standalone_trades"] == counts["joint_trades"]
                and counts["matched"] == counts["standalone_trades"]
                and comparison.get("unmatched_standalone_sample") == []
                and comparison.get("unmatched_joint_sample") == []
            )
            if not comparison_valid:
                errors.append(
                    "fidelity receipt comparison is not an exact non-empty "
                    "maximum-cardinality match"
                )
        operands = receipt.get("operands")
        if not isinstance(operands, dict) or set(operands) != {"standalone", "joint"}:
            errors.append("fidelity receipt operands fields are not exact")
        else:
            operand_results = {
                role: _validate_ftmo_gate_operand(
                    operands.get(role),
                    role=role,
                    stage=expected_stage,
                    expected_work_item_id=expected_ids[role],
                    expected_source_commit=expected_source_commit,
                    expected_execution_identity=expected_execution_inputs,
                    expected_framework_include_sha256=payload.get(
                        "framework_include_tree_sha256"
                    ),
                    expected_evidence_path=expected_evidence_paths[role],
                    expected_runtime_sources={
                        key: value
                        for key, value in expected_runtime_sources.items()
                        if value is not None
                    },
                    errors=errors,
                )
                for role in ("standalone", "joint")
            }
            standalone_operand = operand_results["standalone"]
            joint_operand = operand_results["joint"]
            if standalone_operand.get("factory_off_sha256") != joint_operand.get(
                "factory_off_sha256"
            ):
                errors.append("fidelity receipt operand FACTORY_OFF identities are spliced")
            if standalone_operand.get("factory_off_sha256") != expected_factory_off_sha256:
                errors.append("fidelity receipt operand FACTORY_OFF identity is not current")
            if standalone_operand.get("source_binding") != joint_operand.get(
                "source_binding"
            ):
                errors.append("fidelity receipt operand source bindings are spliced")
            standalone_completed = standalone_operand.get("completed")
            joint_started = joint_operand.get("started")
            if (
                standalone_completed is None
                or joint_started is None
                or standalone_completed > joint_started
            ):
                errors.append("fidelity receipt operand execution order is invalid")
            if standalone_operand.get(
                "execution_input_observed_bundle_sha256"
            ) != joint_operand.get("execution_input_observed_bundle_sha256"):
                errors.append(
                    "fidelity receipt operand observed execution-input identities are spliced"
                )
            if isinstance(comparison, dict):
                if comparison.get("standalone_trades") != standalone_operand.get(
                    "selected_trade_count"
                ):
                    errors.append(
                        "fidelity receipt standalone comparison count does not match operand"
                    )
                if comparison.get("joint_trades") != joint_operand.get(
                    "selected_trade_count"
                ):
                    errors.append(
                        "fidelity receipt joint comparison count does not match operand"
                    )
        identity = {
            key: value
            for key, value in receipt.items()
            if key not in {"generated_at_utc", "adjudication_id"}
        }
        adjudication_id = hashlib.sha256(
            (
                json.dumps(
                    identity,
                    ensure_ascii=False,
                    sort_keys=True,
                    separators=(",", ":"),
                    allow_nan=False,
                )
                + "\n"
            ).encode("utf-8")
        ).hexdigest()
        if receipt.get("adjudication_id") != adjudication_id:
            errors.append("fidelity receipt adjudication_id is invalid")
    return {
        "requested": True,
        "required": True,
        "required_stage": required_stage,
        "valid": not errors,
        "errors": errors,
        "path": str(receipt_path),
        "expected_sha256": expected_receipt_sha256,
        "actual_sha256": actual_sha,
        "bytes": len(raw) if raw is not None else None,
        "work_item_ids": expected_ids,
        "source_commit": expected_source_commit,
        "execution_input_artifacts_sha256": expected_execution_inputs,
    }


def _revalidate_fidelity_receipt(preflight: dict[str, Any]) -> dict[str, Any]:
    prior = preflight.get("fidelity_receipt") or {}
    if not prior.get("required"):
        return {
            "requested": prior.get("requested", False),
            "required": False,
            "valid": prior.get("valid") is True,
            "errors": list(prior.get("errors") or []),
        }
    errors: list[str] = []
    path = Path(str(prior.get("path") or ""))
    if not path.is_file():
        errors.append(f"fidelity receipt disappeared during run: {path}")
        actual_sha = None
        byte_count = None
    else:
        raw = path.read_bytes()
        actual_sha = hashlib.sha256(raw).hexdigest()
        byte_count = len(raw)
        if actual_sha != prior.get("actual_sha256"):
            errors.append("fidelity receipt changed during isolated run")
    return {
        **prior,
        "valid": not errors,
        "errors": errors,
        "post_sha256": actual_sha,
        "post_bytes": byte_count,
    }


def build_plan(
    root: Path,
    *,
    terminal: str,
    work_item_id: str,
    worker_script: Path,
    repo_root: Path = DEFAULT_REPO_ROOT,
    requested_timeout_minutes: float | None = None,
    fidelity_receipt_path: Path | None = None,
    expected_fidelity_receipt_sha256: str | None = None,
) -> dict[str, Any]:
    terminal = terminal.upper()
    db = root / DEFAULT_DB_REL
    flag = root / "state" / "FACTORY_OFF.flag"
    errors: list[str] = []
    if terminal not in ALLOWED_TERMINALS:
        errors.append(f"terminal {terminal!r} is forbidden for isolated runs")
    if not flag.is_file():
        errors.append(f"FACTORY_OFF flag missing: {flag}")
    if not db.is_file():
        errors.append(f"farm DB missing: {db}")
    if not worker_script.is_file():
        errors.append(f"worker script missing: {worker_script}")
    if errors:
        return {"mode": "dry_run", "valid": False, "errors": errors}

    with connect_ro(db) as conn:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=? AND active=1",
            (work_item_id,),
        ).fetchone()
    if row is None:
        errors.append(f"work item missing: {work_item_id}")
        return {"mode": "dry_run", "valid": False, "errors": errors}

    payload_text = str(row["payload_json"] or "{}")
    payload_bytes = len(payload_text.encode("utf-8"))
    if payload_bytes > MAX_PAYLOAD_BYTES:
        payload = {}
        errors.append(
            f"payload_json exceeds maximum size: {payload_bytes}>{MAX_PAYLOAD_BYTES}"
        )
    else:
        try:
            payload = _strict_json_object(
                payload_text.encode("utf-8"), label="payload_json"
            )
        except (ValueError, RuntimeError):
            payload = {}
            errors.append("payload_json is invalid")
    if not isinstance(payload, dict):
        payload = {}
        errors.append("payload_json must decode to an object")
    payload_contract = _payload_contract_plan(payload, payload_text=payload_text)
    if row["status"] != "pending" or row["claimed_by"] is not None:
        errors.append(f"work item is not pending/unclaimed: {row['status']}/{row['claimed_by']}")
    if hold is None:
        errors.append("active maintenance hold is required")
    elif int(hold["release_on_restart"] or 0) != 0:
        errors.append("isolated run requires a non-releasing hold")
    payload_terminal = str(payload.get("terminal") or "").upper()
    if payload_terminal != terminal:
        errors.append(f"payload terminal mismatch: expected {terminal}, actual {payload_terminal!r}")
    avoid = {str(value).upper() for value in (payload.get("avoid_terminals") or [])}
    if terminal in avoid:
        errors.append(f"terminal {terminal} is explicitly avoided")
    if requested_timeout_minutes is not None and not (
        MIN_TIMEOUT_MINUTES <= float(requested_timeout_minutes) <= MAX_TIMEOUT_MINUTES
    ):
        errors.append(
            "requested timeout is outside the controller safety range "
            f"[{MIN_TIMEOUT_MINUTES}, {MAX_TIMEOUT_MINUTES}] minutes"
        )
    payload_timeout = payload.get("timeout_min")
    if payload_timeout is not None:
        if (
            isinstance(payload_timeout, bool)
            or not isinstance(payload_timeout, (int, float))
            or not (MIN_TIMEOUT_MINUTES <= float(payload_timeout) <= MAX_TIMEOUT_MINUTES)
        ):
            errors.append("payload timeout_min is invalid")
        elif (
            requested_timeout_minutes is not None
            and float(requested_timeout_minutes) != float(payload_timeout)
        ):
            errors.append(
                "requested timeout does not match payload-bound timeout_min: "
                f"expected={payload_timeout} actual={requested_timeout_minutes}"
            )

    work_core = _ftmo_work_core_plan(
        row=row,
        hold=hold,
        payload=payload,
        work_item_id=work_item_id,
        terminal=terminal,
        requested_timeout_minutes=requested_timeout_minutes,
    )
    errors.extend(work_core.get("errors") or [])
    with connect_ro(db) as conn:
        ladder_order = _ftmo_ladder_order_plan(
            conn, current_work_item_id=work_item_id, payload=payload
        )
    errors.extend(ladder_order.get("errors") or [])
    fidelity_receipt = _ftmo_fidelity_receipt_plan(
        payload,
        ladder_order=ladder_order,
        receipt_path=fidelity_receipt_path,
        expected_receipt_sha256=expected_fidelity_receipt_sha256,
        expected_factory_off_sha256=sha256_file(flag),
    )
    errors.extend(fidelity_receipt.get("errors") or [])

    ea_dir_name = str(payload.get("ea_dir_name") or "")
    mq5_path = repo_root / "framework" / "EAs" / ea_dir_name / f"{ea_dir_name}.mq5"
    artifacts = [
        _artifact(row["setfile_path"], payload.get("expected_setfile_sha256"), "setfile"),
        _artifact(payload.get("staged_ex5_path"), payload.get("staged_ex5_sha256"), "staged_ex5"),
        _artifact(mq5_path, payload.get("expected_mq5_sha256"), "mq5"),
    ]
    errors.extend(
        f"{item['role']} artifact invalid: {item.get('reason', 'hash_mismatch')}"
        for item in artifacts
        if not item["valid"]
    )
    execution_inputs = _execution_input_plan(payload, repo_root=repo_root)
    errors.extend(execution_inputs.get("errors") or [])
    source_binding = _ftmo_source_binding_plan(
        payload,
        repo_root=repo_root,
        worker_script=worker_script,
        setfile_path=Path(str(row["setfile_path"])),
    )
    errors.extend(source_binding.get("errors") or [])
    post_run_stream = _post_run_stream_plan(payload, work_item_id)
    errors.extend(post_run_stream.get("errors") or [])
    processes = _factory_processes()
    if processes:
        errors.append(f"factory terminal/tester processes are present: {len(processes)}")

    return {
        "mode": "dry_run",
        "valid": not errors,
        "errors": errors,
        "root": str(root),
        "db": str(db),
        "db_sha256": sha256_file(db),
        "db_state_sha256": sqlite_state_sha256(db),
        "factory_off_flag": str(flag),
        "factory_off_sha256": sha256_file(flag),
        "terminal": terminal,
        "work_item_id": work_item_id,
        "work_item": {
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "phase": row["phase"],
            "status": row["status"],
            "claimed_by": row["claimed_by"],
            "measurement_rung": payload.get("measurement_rung"),
            "measurement_sequence": payload.get("measurement_sequence"),
            "evidence_run_id": payload.get("evidence_run_id"),
            "payload_sha256": sha256_text(payload_text),
            "payload_bytes": payload_bytes,
            "timeout_min": payload_timeout,
        },
        "hold": dict(hold) if hold is not None else None,
        "payload_contract": payload_contract,
        "work_core": work_core,
        "ladder_order": ladder_order,
        "fidelity_receipt": fidelity_receipt,
        "artifacts": artifacts,
        "execution_inputs": execution_inputs,
        "source_binding": source_binding,
        "post_run_stream": post_run_stream,
        "worker_script": str(worker_script),
        "worker_sha256": sha256_file(worker_script),
        "factory_processes": processes,
    }


def _require_equal(label: str, expected: str, actual: str) -> None:
    if expected.strip().lower() != actual.strip().lower():
        raise RuntimeError(f"{label} mismatch: expected={expected} actual={actual}")


def _write_receipt(path: Path, payload: dict[str, Any]) -> None:
    if path.exists():
        raise FileExistsError(f"receipt target already exists: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def _fsync_file(handle: Any) -> None:
    handle.flush()
    os.fsync(handle.fileno())


def _reserve_execution_outputs(
    *,
    snapshot_path: Path,
    receipt_path: Path,
    worker_log_path: Path,
    intent: dict[str, Any],
) -> str:
    paths = [snapshot_path, receipt_path, worker_log_path]
    identities = [_lexical_path_identity(path) for path in paths]
    if len(set(identities)) != len(identities):
        raise RuntimeError("snapshot, receipt and worker log paths must be distinct")
    existing = [str(path) for path in paths if path.exists()]
    if existing:
        raise FileExistsError(f"isolated-run output target already exists: {existing}")
    reservation_id = str(uuid.uuid4())
    created: list[Path] = []
    try:
        for path in (snapshot_path, worker_log_path):
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as handle:
                _fsync_file(handle)
            created.append(path)
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        reservation = {
            "schema_version": 2,
            "mode": "apply",
            "state": "intent_reserved",
            "reservation_id": reservation_id,
            "reserved_at_utc": utc_now(),
            "snapshot_path": str(snapshot_path),
            "worker_log_path": str(worker_log_path),
            **intent,
        }
        with receipt_path.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(reservation, indent=2, sort_keys=True) + "\n")
            _fsync_file(handle)
        created.append(receipt_path)
    except BaseException:
        for path in reversed(created):
            path.unlink(missing_ok=True)
        raise
    return reservation_id


def _publish_reserved_receipt(
    path: Path, *, reservation_id: str, payload: dict[str, Any]
) -> None:
    try:
        current = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise RuntimeError(f"reserved receipt cannot be authenticated: {exc}") from exc
    if current.get("reservation_id") != reservation_id:
        raise RuntimeError("reserved receipt reservation_id changed")
    tmp = path.with_name(f"{path.name}.{reservation_id}.tmp")
    rendered = {
        **payload,
        "reservation_id": reservation_id,
    }
    try:
        with tmp.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(rendered, indent=2, sort_keys=True) + "\n")
            _fsync_file(handle)
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def _terminate_pid_tree(pid: int) -> dict[str, Any]:
    result: dict[str, Any] = {"pid": int(pid), "attempted": True, "errors": []}
    if os.name == "nt":
        process = subprocess.run(
            ["taskkill.exe", "/PID", str(pid), "/T", "/F"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        result.update(
            {
                "returncode": process.returncode,
                "stdout": process.stdout.strip(),
                "stderr": process.stderr.strip(),
            }
        )
        return result
    try:
        os.killpg(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except Exception as exc:  # pragma: no cover - platform-specific containment
        result["errors"].append(f"{type(exc).__name__}: {exc}")
    return result


def _contain_worker_process_tree(process: subprocess.Popen[Any] | None) -> dict[str, Any]:
    if process is None:
        return {"attempted": False, "valid": True, "actions": []}
    actions: list[dict[str, Any]] = []
    if process.poll() is None:
        actions.append(_terminate_pid_tree(process.pid))
        try:
            process.wait(timeout=30)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=30)
    else:
        # Never target an already-exited PID: immediate PID reuse could make a
        # late taskkill/killpg hit an unrelated process.  Factory descendants
        # are handled by the authoritative post-run factory census below.
        actions.append({"pid": process.pid, "attempted": False, "parent_exited": True})
    return {
        "attempted": True,
        "valid": process.poll() is not None,
        "worker_pid": process.pid,
        "actions": actions,
    }


def _post_run_quiescence() -> dict[str, Any]:
    before = _factory_processes()
    actions: list[dict[str, Any]] = []
    for row in before:
        pid = row.get("ProcessId")
        if isinstance(pid, int) or (isinstance(pid, str) and pid.isdigit()):
            actions.append(_terminate_pid_tree(int(pid)))
    deadline = time.monotonic() + 30.0
    after = _factory_processes()
    while after and time.monotonic() < deadline:
        time.sleep(0.25)
        after = _factory_processes()
    return {
        "valid": not after,
        "before": before,
        "termination_actions": actions,
        "after": after,
    }


def _revalidate_execution_inputs(
    preflight: dict[str, Any], *, repo_root: Path
) -> dict[str, Any]:
    prior = preflight.get("execution_inputs") or {}
    if not prior.get("requested"):
        return {"requested": False, "valid": True, "errors": []}
    rows = [
        {
            "role": item.get("role"),
            "path": item.get("path"),
            "sha256": item.get("expected_sha256"),
            "bytes": item.get("expected_bytes"),
        }
        for item in prior.get("artifacts") or []
    ]
    payload = {
        "measurement_contract": FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "terminal": "T10",
        "execution_input_artifacts": rows,
        "execution_input_artifacts_sha256": canonical_sha256(rows),
    }
    current = _execution_input_plan(payload, repo_root=repo_root)
    errors = list(current.get("errors") or [])
    if current.get("observed_bundle_sha256") != prior.get("observed_bundle_sha256"):
        errors.append("execution input observation bundle changed during isolated run")
    current["errors"] = errors
    current["valid"] = not errors
    current["pre_observed_bundle_sha256"] = prior.get("observed_bundle_sha256")
    return current


def _revalidate_runtime_sources(
    preflight: dict[str, Any], *, repo_root: Path, worker_script: Path
) -> dict[str, Any]:
    prior = ((preflight.get("source_binding") or {}).get("runtime_sources") or {})
    if not prior.get("requested"):
        return {"requested": False, "valid": True, "errors": []}
    rows = [
        {
            "role": item.get("role"),
            "path": item.get("path"),
            "sha256": item.get("expected_sha256"),
            "bytes": item.get("expected_bytes"),
        }
        for item in prior.get("artifacts") or []
    ]
    payload = {
        "runtime_source_artifacts": rows,
        "runtime_source_artifacts_sha256": canonical_sha256(rows),
    }
    current = _ftmo_runtime_source_plan(
        payload, repo_root=repo_root, worker_script=worker_script
    )
    errors = list(current.get("errors") or [])
    if current.get("canonical_sha256") != prior.get("canonical_sha256"):
        errors.append("runtime source manifest changed during isolated run")
    current["errors"] = errors
    current["valid"] = not errors
    return current


def _post_evidence_plan(post: sqlite3.Row, preflight: dict[str, Any]) -> dict[str, Any]:
    path_text = post["evidence_path"]
    errors: list[str] = []
    if not isinstance(path_text, str) or not path_text.strip():
        return {"valid": False, "errors": ["work item has no evidence_path"]}
    path = Path(path_text)
    if not path.is_absolute():
        errors.append("work-item evidence_path is not absolute")
    if not path.is_file():
        errors.append(f"work-item evidence file is missing: {path}")
    if not errors and (preflight.get("work_core") or {}).get("requested"):
        report_root_text = None
        stream = preflight.get("post_run_stream") or {}
        streams = stream.get("streams") or []
        if streams:
            report_root_text = str(Path(str(streams[0]["target"])).parent)
        elif stream.get("target"):
            report_root_text = str(Path(str(stream["target"])).parent)
        if report_root_text is not None:
            report_root = Path(report_root_text).resolve()
            try:
                path.resolve(strict=True).relative_to(report_root)
            except (OSError, ValueError):
                errors.append("FTMO work-item evidence is outside its governed report root")
    result: dict[str, Any] = {"path": str(path), "valid": not errors, "errors": errors}
    if not errors:
        observation = _bound_file_observation(path)
        result.update(
            {
                "sha256": observation["sha256"],
                "bytes": observation["bytes"],
                "resolved_path": observation["resolved_path"],
            }
        )
    return result


def execute(
    root: Path,
    *,
    terminal: str,
    work_item_id: str,
    worker_script: Path,
    repo_root: Path,
    timeout_minutes: float,
    expected_factory_off_sha256: str,
    expected_db_state_sha256: str,
    expected_payload_sha256: str,
    expected_worker_sha256: str,
    snapshot_path: Path,
    receipt_path: Path,
    worker_log_path: Path,
    fidelity_receipt_path: Path | None = None,
    expected_fidelity_receipt_sha256: str | None = None,
) -> dict[str, Any]:
    flag = root / "state" / "FACTORY_OFF.flag"
    lock_path = path_for_factory_flag(flag)
    with FactoryMutationLock(lock_path, owner=f"isolated_work_item:{work_item_id}:{terminal.upper()}"):
        plan = build_plan(
            root,
            terminal=terminal,
            work_item_id=work_item_id,
            worker_script=worker_script,
            repo_root=repo_root,
            requested_timeout_minutes=timeout_minutes,
            fidelity_receipt_path=fidelity_receipt_path,
            expected_fidelity_receipt_sha256=expected_fidelity_receipt_sha256,
        )
        if not plan.get("valid"):
            raise RuntimeError(f"isolated run preflight failed: {plan.get('errors')}")
        _require_equal("FACTORY_OFF SHA-256", expected_factory_off_sha256, plan["factory_off_sha256"])
        _require_equal("logical DB state SHA-256", expected_db_state_sha256, plan["db_state_sha256"])
        _require_equal("work-item payload SHA-256", expected_payload_sha256, plan["work_item"]["payload_sha256"])
        _require_equal("worker SHA-256", expected_worker_sha256, plan["worker_sha256"])
        reservation_id = _reserve_execution_outputs(
            snapshot_path=snapshot_path,
            receipt_path=receipt_path,
            worker_log_path=worker_log_path,
            intent={
                "terminal": terminal.upper(),
                "work_item_id": work_item_id,
                "factory_off_sha256": plan["factory_off_sha256"],
                "db_state_sha256": plan["db_state_sha256"],
                "payload_sha256": plan["work_item"]["payload_sha256"],
            },
        )
        started_at = utc_now()
        process: subprocess.Popen[Any] | None = None
        containment: dict[str, Any] = {"attempted": False, "valid": True, "actions": []}
        quiescence: dict[str, Any] = {"valid": False, "before": [], "after": []}
        try:
            snapshot_sha = sqlite_snapshot(
                Path(plan["db"]), snapshot_path, reserved=True
            )
            command = [
                sys.executable,
                str(worker_script),
                "--terminal",
                terminal.upper(),
                "--root",
                str(root),
                "--timeout-minutes",
                str(timeout_minutes),
                "--work-item-id",
                work_item_id,
            ]
            worker_started_wall_ns = time.time_ns()
            worker_env = os.environ.copy()
            # Bind imports to the exact clean source checkout and prevent test
            # subprocess bytecode from dirtying that source vintage.
            worker_env["PYTHONPATH"] = str(repo_root)
            worker_env["PYTHONDONTWRITEBYTECODE"] = "1"
            if worker_log_path.stat().st_size != 0:
                raise RuntimeError("worker log reservation changed before launch")
            popen_kwargs: dict[str, Any] = {}
            if os.name == "nt":
                popen_kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
            else:
                popen_kwargs["start_new_session"] = True
            try:
                with worker_log_path.open("r+", encoding="utf-8") as log_handle:
                    process = subprocess.Popen(
                        command,
                        cwd=str(repo_root),
                        env=worker_env,
                        stdout=log_handle,
                        stderr=subprocess.STDOUT,
                        text=True,
                        **popen_kwargs,
                    )
                    hard_deadline = time.monotonic() + timeout_minutes * 60.0 + 60.0
                    next_heartbeat = time.monotonic()
                    while process.poll() is None:
                        now = time.monotonic()
                        if now >= hard_deadline:
                            raise RuntimeError(
                                "isolated worker exceeded payload-bound controller deadline"
                            )
                        if now >= next_heartbeat:
                            print(
                                json.dumps(
                                    {
                                        "event": "isolated_run_heartbeat",
                                        "work_item_id": work_item_id,
                                        "terminal": terminal.upper(),
                                        "worker_pid": process.pid,
                                        "elapsed_seconds": int(
                                            timeout_minutes * 60.0
                                            + 60.0
                                            - (hard_deadline - now)
                                        ),
                                    }
                                ),
                                flush=True,
                            )
                            next_heartbeat = now + 30.0
                        time.sleep(2.0)
                    worker_exit_code = int(process.returncode)
            finally:
                containment = _contain_worker_process_tree(process)
                quiescence = _post_run_quiescence()
            if not containment.get("valid") or not quiescence.get("valid"):
                raise RuntimeError("isolated worker process tree did not become quiescent")
            if sha256_file(flag) != plan["factory_off_sha256"]:
                raise RuntimeError("FACTORY_OFF flag changed during isolated run")

            post_execution_inputs = _revalidate_execution_inputs(
                plan, repo_root=repo_root
            )
            post_runtime_sources = _revalidate_runtime_sources(
                plan, repo_root=repo_root, worker_script=worker_script
            )
            post_fidelity_receipt = _revalidate_fidelity_receipt(plan)
            post_run_stream = _harvest_post_run_stream(
                plan["post_run_stream"], worker_started_wall_ns=worker_started_wall_ns
            )
            db = Path(plan["db"])
            wal_checkpoint = checkpoint_wal(db)
            with connect_ro(db) as conn:
                post = conn.execute(
                    "SELECT id,status,verdict,claimed_by,evidence_path,updated_at,payload_json "
                    "FROM work_items WHERE id=?",
                    (work_item_id,),
                ).fetchone()
            if post is None:
                raise RuntimeError("work item disappeared during isolated run")
            post_payload_text = str(post["payload_json"] or "{}")
            payload_contract_revalidation = _revalidate_payload_contract(
                plan, post_payload_text=post_payload_text
            )
            evidence = _post_evidence_plan(post, plan)
            success_checks = {
                "worker_exit_code_zero": worker_exit_code == 0,
                "work_item_done": post["status"] == "done",
                "work_item_pass": post["verdict"] == "PASS",
                "work_item_unclaimed": post["claimed_by"] is None,
                "work_item_evidence_valid": evidence.get("valid") is True,
                "post_run_stream_valid": post_run_stream.get("valid") is True,
                "execution_inputs_unchanged": post_execution_inputs.get("valid") is True,
                "runtime_sources_unchanged": post_runtime_sources.get("valid") is True,
                "payload_contract_revalidated": (
                    payload_contract_revalidation.get("valid") is True
                ),
                "fidelity_receipt_unchanged": (
                    post_fidelity_receipt.get("valid") is True
                ),
                "process_tree_quiescent": quiescence.get("valid") is True,
            }
            result = {
                "schema_version": 1,
                "mode": "apply",
                "state": "completed",
                "success": all(success_checks.values()),
                "success_checks": success_checks,
                "started_at_utc": started_at,
                "completed_at_utc": utc_now(),
                "terminal": terminal.upper(),
                "work_item_id": work_item_id,
                "preflight": plan,
                "snapshot_path": str(snapshot_path),
                "snapshot_sha256": snapshot_sha,
                "worker_log_path": str(worker_log_path),
                "worker_log_sha256": sha256_file(worker_log_path),
                "worker_exit_code": worker_exit_code,
                "process_tree_containment": containment,
                "post_run_quiescence": quiescence,
                "post_execution_inputs": post_execution_inputs,
                "post_runtime_sources": post_runtime_sources,
                "post_fidelity_receipt": post_fidelity_receipt,
                "payload_contract_revalidation": payload_contract_revalidation,
                "post_run_stream": post_run_stream,
                "post_evidence": evidence,
                "post_work_item": {
                    key: post[key]
                    for key in (
                        "id",
                        "status",
                        "verdict",
                        "claimed_by",
                        "evidence_path",
                        "updated_at",
                    )
                },
                "pre_payload_sha256": plan["work_item"]["payload_sha256"],
                "post_payload_sha256": sha256_text(post_payload_text),
                "post_db_sha256": sha256_file(db),
                "post_db_state_sha256": sqlite_state_sha256(db),
                "factory_off_sha256": sha256_file(flag),
                "wal_checkpoint": wal_checkpoint,
                "live_scope_touched": False,
                "autotrading_touched": False,
            }
            _publish_reserved_receipt(
                receipt_path, reservation_id=reservation_id, payload=result
            )
            return result
        except BaseException as exc:
            try:
                containment = _contain_worker_process_tree(process)
                quiescence = _post_run_quiescence()
            except BaseException as cleanup_exc:
                quiescence = {
                    "valid": False,
                    "error": f"{type(cleanup_exc).__name__}: {cleanup_exc}",
                }
            failure = {
                "schema_version": 2,
                "mode": "apply",
                "state": "failed",
                "success": False,
                "started_at_utc": started_at,
                "completed_at_utc": utc_now(),
                "terminal": terminal.upper(),
                "work_item_id": work_item_id,
                "error_type": type(exc).__name__,
                "error": str(exc),
                "process_tree_containment": containment,
                "post_run_quiescence": quiescence,
                "factory_off_sha256": sha256_file(flag) if flag.is_file() else None,
                "live_scope_touched": False,
                "autotrading_touched": False,
            }
            try:
                _publish_reserved_receipt(
                    receipt_path, reservation_id=reservation_id, payload=failure
                )
            except BaseException as receipt_exc:
                exc.add_note(f"failure receipt publication also failed: {receipt_exc}")
            raise


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--terminal")
    parser.add_argument("--work-item-id")
    parser.add_argument("--worker-script", type=Path, default=DEFAULT_WORKER)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    parser.add_argument("--timeout-minutes", type=float, default=90.0)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--expected-db-state-sha256")
    parser.add_argument("--expected-payload-sha256")
    parser.add_argument("--expected-worker-sha256")
    parser.add_argument("--snapshot-path", type=Path)
    parser.add_argument("--receipt-path", type=Path)
    parser.add_argument("--worker-log-path", type=Path)
    parser.add_argument("--fidelity-receipt-path", type=Path)
    parser.add_argument("--expected-fidelity-receipt-sha256")
    parser.add_argument("--recover-harvest-from-receipt", type=Path)
    parser.add_argument("--expected-source-receipt-sha256")
    parser.add_argument("--recovery-receipt-path", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.recover_harvest_from_receipt:
        if not args.expected_source_receipt_sha256 or not args.recovery_receipt_path:
            parser.error(
                "harvest recovery requires --expected-source-receipt-sha256 "
                "and --recovery-receipt-path"
            )
        result = recover_harvest_from_receipt(
            args.root,
            source_receipt_path=args.recover_harvest_from_receipt,
            expected_source_receipt_sha256=args.expected_source_receipt_sha256,
            recovery_receipt_path=args.recovery_receipt_path,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["harvest"].get("valid") else 2
    if not args.terminal or not args.work_item_id:
        parser.error("--terminal and --work-item-id are required for an isolated run")
    if not args.apply:
        plan = build_plan(
            args.root,
            terminal=args.terminal,
            work_item_id=args.work_item_id,
            worker_script=args.worker_script,
            repo_root=args.repo_root,
            requested_timeout_minutes=args.timeout_minutes,
            fidelity_receipt_path=args.fidelity_receipt_path,
            expected_fidelity_receipt_sha256=args.expected_fidelity_receipt_sha256,
        )
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0 if plan.get("valid") else 2
    required = {
        "--expected-factory-off-sha256": args.expected_factory_off_sha256,
        "--expected-db-state-sha256": args.expected_db_state_sha256,
        "--expected-payload-sha256": args.expected_payload_sha256,
        "--expected-worker-sha256": args.expected_worker_sha256,
        "--snapshot-path": args.snapshot_path,
        "--receipt-path": args.receipt_path,
        "--worker-log-path": args.worker_log_path,
    }
    missing = [name for name, value in required.items() if value in (None, "")]
    if missing:
        parser.error("apply requires " + ", ".join(missing))
    result = execute(
        args.root,
        terminal=args.terminal,
        work_item_id=args.work_item_id,
        worker_script=args.worker_script,
        repo_root=args.repo_root,
        timeout_minutes=args.timeout_minutes,
        expected_factory_off_sha256=args.expected_factory_off_sha256,
        expected_db_state_sha256=args.expected_db_state_sha256,
        expected_payload_sha256=args.expected_payload_sha256,
        expected_worker_sha256=args.expected_worker_sha256,
        snapshot_path=args.snapshot_path,
        receipt_path=args.receipt_path,
        worker_log_path=args.worker_log_path,
        fidelity_receipt_path=args.fidelity_receipt_path,
        expected_fidelity_receipt_sha256=args.expected_fidelity_receipt_sha256,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("success") is True else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2), file=sys.stderr)
        raise SystemExit(1)
