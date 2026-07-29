#!/usr/bin/env python3
"""Fail-closed FTMO Book-3 singleton-replay fidelity adjudicator.

The gate consumes exactly one standalone and one joint isolated-runner apply
receipt for a selected Book-3 stage.  Receipt hashes, source vintage, the full
307-row execution-input identity, and the runner-harvested q08 trade streams
are authenticated before any trade is compared.  Input files are read once;
the SHA-256 and parsed content therefore refer to the same bytes.

This program is deliberately outside the factory controller.  It does not
open the farm database, acquire a factory lock, launch MT5, or mutate Factory
state.  Its only write is the caller-selected, create-only adjudication receipt.

Exit codes:

* 0: PASS
* 2: FAIL (valid, non-empty operands differ)
* 3: SETUP_BLOCKED (contract/evidence/input problem)
* 4: the create-only output could not be published
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import sys
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any


SCHEMA = "qm.ftmo-book3-fidelity-adjudication-receipt/v2"
MEASUREMENT_CONTRACT = "FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET"
FULL_LIFECYCLE_MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
JOINT_PRODUCER_VERSION = "QM5_20181_FTMO_TRACE_V2"
EXPECTED_EXECUTION_INPUT_COUNT = 307
RUNTIME_SOURCE_ROLES = (
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
SUCCESS_CHECK_KEYS = (
    "worker_exit_code_zero",
    "work_item_done",
    "work_item_pass",
    "work_item_unclaimed",
    "work_item_evidence_valid",
    "post_run_stream_valid",
    "execution_inputs_unchanged",
    "runtime_sources_unchanged",
    "payload_contract_revalidated",
    "fidelity_receipt_unchanged",
    "process_tree_quiescent",
)
MONEY_TOLERANCE = Decimal("0.005")
VOLUME_TOLERANCE = Decimal("0.005")
PRICE_TOLERANCE = Decimal("0")
CANONICAL_SIDES = frozenset({"BUY", "SELL"})
DEFAULT_COMPARATOR = Path(__file__).resolve().with_name("compare_joint_replay.py")
_SHA256_RE = re.compile(r"[0-9a-f]{64}")
_COMMIT_RE = re.compile(r"[0-9a-f]{40}")


class SetupBlocked(RuntimeError):
    """Evidence cannot support a fidelity decision."""


class DuplicateKeyError(ValueError):
    """A JSON object contains a duplicate key."""


@dataclass(frozen=True)
class OperandSpec:
    role: str
    rung: str
    sequence: int
    ea_id: str
    work_symbol: str
    trade_magic: int
    trade_symbol: str
    evidence_run_id: str | None
    source_stem: str


@dataclass(frozen=True)
class StageSpec:
    stage: int
    standalone: OperandSpec
    joint: OperandSpec


STAGES: dict[int, StageSpec] = {
    0: StageSpec(
        stage=0,
        standalone=OperandSpec(
            "standalone", "R0", 0, "QM5_9936", "USDJPY.DWX",
            99360000, "USDJPY.DWX", None, "9936_USDJPY_DWX",
        ),
        joint=OperandSpec(
            "joint", "J0", 1, "QM5_20181", "USDJPY.DWX",
            201810000, "USDJPY.DWX", "FTMO_BOOK3_20260729_V2_J0",
            "20181_USDJPY_DWX",
        ),
    ),
    1: StageSpec(
        stage=1,
        standalone=OperandSpec(
            "standalone", "R1", 2, "QM5_10145", "XAUUSD.DWX",
            101450034, "XAUUSD.DWX", None, "10145_XAUUSD_DWX",
        ),
        joint=OperandSpec(
            "joint", "J1", 3, "QM5_20181", "USDJPY.DWX",
            201810001, "XAUUSD.DWX", "FTMO_BOOK3_20260729_V2_J1",
            "20181_USDJPY_DWX",
        ),
    ),
    2: StageSpec(
        stage=2,
        standalone=OperandSpec(
            "standalone", "R2", 4, "QM5_13108", "XTIUSD.DWX",
            131080000, "XTIUSD.DWX", None, "13108_XTIUSD_DWX",
        ),
        joint=OperandSpec(
            "joint", "J2", 5, "QM5_20181", "USDJPY.DWX",
            201810002, "XTIUSD.DWX", "FTMO_BOOK3_20260729_V2_J2",
            "20181_USDJPY_DWX",
        ),
    ),
}


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def _canonical_sha(value: Any) -> str:
    # Runner list identities do not contain the receipt's trailing newline.
    rendered = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(rendered).hexdigest()


def _sha256_argument(value: str, label: str) -> str:
    if not isinstance(value, str) or _SHA256_RE.fullmatch(value) is None:
        raise SetupBlocked(f"{label} must be exactly 64 lowercase hexadecimal characters")
    return value


def _commit_argument(value: str, label: str) -> str:
    if not isinstance(value, str) or _COMMIT_RE.fullmatch(value) is None:
        raise SetupBlocked(f"{label} must be exactly 40 lowercase hexadecimal characters")
    return value


def _no_duplicate_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_json_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON number is forbidden: {value}")


def _strict_json(raw: bytes, label: str) -> Any:
    try:
        text = raw.decode("utf-8-sig", errors="strict")
        return json.loads(
            text,
            object_pairs_hook=_no_duplicate_object,
            parse_constant=_reject_json_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, DuplicateKeyError, ValueError) as exc:
        raise SetupBlocked(f"{label} is not strict duplicate-free UTF-8 JSON: {exc}") from exc


def _resolved_file(path: Path, label: str) -> Path:
    if not path.is_absolute():
        raise SetupBlocked(f"{label} path must be absolute: {path}")
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise SetupBlocked(f"{label} file is missing or unreadable: {path}: {exc}") from exc
    if not resolved.is_file():
        raise SetupBlocked(f"{label} is not a regular file: {resolved}")
    return resolved


def _read_bound_bytes(path: Path, expected_sha256: str, label: str) -> tuple[Path, bytes, str]:
    expected = _sha256_argument(expected_sha256, f"expected {label} SHA-256")
    resolved = _resolved_file(path, label)
    try:
        # Exactly one file read.  Both parsing and hashing consume this object.
        raw = resolved.read_bytes()
    except OSError as exc:
        raise SetupBlocked(f"{label} cannot be read: {resolved}: {exc}") from exc
    actual = hashlib.sha256(raw).hexdigest()
    if actual != expected:
        raise SetupBlocked(
            f"{label} SHA-256 mismatch: expected={expected} actual={actual}"
        )
    return resolved, raw, actual


def _as_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SetupBlocked(f"{label} must be an object")
    return value


def _as_list(value: Any, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise SetupBlocked(f"{label} must be an array")
    return value


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise SetupBlocked(message)


def _canonical_lower_hash(value: Any, label: str) -> str:
    if not isinstance(value, str) or _SHA256_RE.fullmatch(value) is None:
        raise SetupBlocked(f"{label} is not a canonical lowercase SHA-256")
    return value


def _exact_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise SetupBlocked(f"{label} must be an integer")
    return value


def _utc_timestamp(value: Any, label: str) -> dt.datetime:
    if not isinstance(value, str):
        raise SetupBlocked(f"{label} must be an ISO-8601 timestamp")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise SetupBlocked(f"{label} is not a valid ISO-8601 timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise SetupBlocked(f"{label} must be timezone-aware")
    if parsed.utcoffset() != dt.timedelta(0):
        raise SetupBlocked(f"{label} must be UTC")
    return parsed


def _validate_runtime_source_block(
    value: Any, spec: OperandSpec
) -> dict[str, Any]:
    label = f"{spec.role} runtime sources"
    block = _as_dict(value, label)
    _require(block.get("requested") is True, f"{label} were not requested")
    _require(block.get("valid") is True, f"{label} are invalid")
    _require(block.get("errors") == [], f"{label} contain errors")
    git_clean = _as_dict(block.get("git_clean"), f"{label} Git cleanliness")
    _require(
        git_clean
        == {"valid": True, "error": None, "porcelain": ""},
        f"{label} were measured from a dirty or unknown source tree",
    )
    rows = _as_list(block.get("artifacts"), f"{label} artifacts")
    _require(
        len(rows) == len(RUNTIME_SOURCE_ROLES),
        f"{label} must contain exactly {len(RUNTIME_SOURCE_ROLES)} artifacts",
    )
    canonical_rows: list[dict[str, Any]] = []
    roles: dict[str, dict[str, Any]] = {}
    paths: set[str] = set()
    for index, row_value in enumerate(rows):
        row = _as_dict(row_value, f"{label} artifact {index}")
        _require(row.get("index") == index, f"{label} index mismatch at {index}")
        _require(row.get("valid") is True, f"{label} artifact {index} is invalid")
        role = row.get("role")
        path_text = row.get("path")
        _require(
            role in RUNTIME_SOURCE_ROLES and role not in roles,
            f"{label} role is unexpected or duplicated: {role!r}",
        )
        _require(
            isinstance(path_text, str) and Path(path_text).is_absolute(),
            f"{label} {role} path is invalid",
        )
        path_identity = os.path.normcase(os.path.abspath(path_text))
        _require(path_identity not in paths, f"{label} path is duplicated: {path_text}")
        paths.add(path_identity)
        expected_sha = _canonical_lower_hash(
            row.get("expected_sha256"), f"{label} {role} expected SHA-256"
        )
        actual_sha = _canonical_lower_hash(
            row.get("actual_sha256"), f"{label} {role} actual SHA-256"
        )
        _require(expected_sha == actual_sha, f"{label} {role} hash mismatch")
        expected_bytes = _exact_int(
            row.get("expected_bytes"), f"{label} {role} expected bytes"
        )
        actual_bytes = _exact_int(
            row.get("actual_bytes"), f"{label} {role} actual bytes"
        )
        _require(
            expected_bytes >= 0 and expected_bytes == actual_bytes,
            f"{label} {role} byte count mismatch",
        )
        canonical = {
            "role": role,
            "path": path_text,
            "sha256": actual_sha,
            "bytes": actual_bytes,
        }
        canonical_rows.append(canonical)
        roles[str(role)] = canonical
    _require(
        set(roles) == set(RUNTIME_SOURCE_ROLES),
        f"{label} role set is incomplete",
    )
    _require(
        canonical_rows
        == sorted(canonical_rows, key=lambda row: (row["role"], row["path"])),
        f"{label} are not in canonical role/path order",
    )
    identity = _canonical_sha(canonical_rows)
    recorded = _canonical_lower_hash(
        block.get("canonical_sha256"), f"{label} canonical SHA-256"
    )
    _require(identity == recorded, f"{label} manifest hash is inconsistent")
    return {"canonical_sha256": identity, "roles": roles}


def _validate_source_binding(
    receipt: dict[str, Any], spec: OperandSpec, expected_source_commit: str
) -> dict[str, Any]:
    preflight = _as_dict(receipt.get("preflight"), f"{spec.role} preflight")
    binding = _as_dict(
        preflight.get("source_binding"), f"{spec.role} source binding"
    )
    _require(binding.get("requested") is True, f"{spec.role} source binding was not requested")
    _require(binding.get("valid") is True, f"{spec.role} source binding is not valid")
    _require(binding.get("errors") == [], f"{spec.role} source binding contains errors")
    for key in (
        "authoritative_source_commit",
        "controller_head_commit",
        "actual_head_commit",
    ):
        _require(
            binding.get(key) == expected_source_commit,
            f"{spec.role} source binding {key} mismatch",
        )
    _require(binding.get("measurement_rung") == spec.rung, f"{spec.role} source rung mismatch")
    _require(
        binding.get("measurement_sequence") == spec.sequence,
        f"{spec.role} source sequence mismatch",
    )
    _require(
        binding.get("evidence_run_id") == spec.evidence_run_id,
        f"{spec.role} source evidence_run_id mismatch",
    )

    common: dict[str, Any] = {}
    artifact_keys = (
        "framework_include_tree",
        "preregistration",
        "isolated_runner",
        "terminal_worker",
        "preparation_controller",
    )
    for key in artifact_keys:
        row = _as_dict(binding.get(key), f"{spec.role} source binding {key}")
        expected = _canonical_lower_hash(
            row.get("expected_sha256"), f"{spec.role} {key} expected SHA-256"
        )
        actual = _canonical_lower_hash(
            row.get("actual_sha256"), f"{spec.role} {key} actual SHA-256"
        )
        _require(expected == actual, f"{spec.role} {key} expected/actual hash mismatch")
        path_text = row.get("path")
        _require(
            isinstance(path_text, str) and Path(path_text).is_absolute(),
            f"{spec.role} {key} path must be absolute",
        )
        common[key] = {"path": os.path.normcase(os.path.abspath(path_text)), "sha256": actual}
        if key == "framework_include_tree":
            count = _exact_int(row.get("file_count"), f"{spec.role} framework file_count")
            _require(count > 0, f"{spec.role} framework include tree is empty")
            common[key]["file_count"] = count
    runtime_sources = _validate_runtime_source_block(
        binding.get("runtime_sources"), spec
    )
    for direct_key, runtime_role in (
        ("preregistration", "preregistration"),
        ("isolated_runner", "isolated_runner"),
        ("terminal_worker", "terminal_worker"),
        ("preparation_controller", "preparation_controller"),
    ):
        _require(
            common[direct_key]["sha256"]
            == runtime_sources["roles"][runtime_role]["sha256"],
            f"{spec.role} {direct_key} direct/runtime-source binding mismatch",
        )
    common["runtime_sources"] = runtime_sources
    return common


def _validate_artifacts(receipt: dict[str, Any], spec: OperandSpec) -> dict[str, Any]:
    preflight = _as_dict(receipt.get("preflight"), f"{spec.role} preflight")
    rows = _as_list(preflight.get("artifacts"), f"{spec.role} artifacts")
    _require(len(rows) == 3, f"{spec.role} must bind exactly three runner artifacts")
    result: dict[str, Any] = {}
    for row_value in rows:
        row = _as_dict(row_value, f"{spec.role} artifact row")
        role = row.get("role")
        _require(
            role in {"setfile", "staged_ex5", "mq5"} and role not in result,
            f"{spec.role} artifact role is unexpected or duplicated: {role!r}",
        )
        _require(row.get("valid") is True, f"{spec.role} {role} artifact is invalid")
        expected = _canonical_lower_hash(
            row.get("expected_sha256"), f"{spec.role} {role} expected SHA-256"
        )
        actual = _canonical_lower_hash(
            row.get("actual_sha256"), f"{spec.role} {role} actual SHA-256"
        )
        _require(expected == actual, f"{spec.role} {role} artifact hash mismatch")
        path_text = row.get("path")
        _require(
            isinstance(path_text, str) and Path(path_text).is_absolute(),
            f"{spec.role} {role} artifact path must be absolute",
        )
        result[role] = {
            "path": os.path.normcase(os.path.abspath(path_text)),
            "sha256": actual,
        }
    _require(
        set(result) == {"setfile", "staged_ex5", "mq5"},
        f"{spec.role} runner artifact set is incomplete",
    )
    return result


def _validate_execution_inputs(
    receipt: dict[str, Any], spec: OperandSpec, expected_identity: str
) -> tuple[list[dict[str, Any]], str, str]:
    preflight = _as_dict(receipt.get("preflight"), f"{spec.role} preflight")
    block = _as_dict(
        preflight.get("execution_inputs"), f"{spec.role} execution inputs"
    )
    _require(block.get("requested") is True, f"{spec.role} execution inputs were not requested")
    _require(block.get("valid") is True, f"{spec.role} execution inputs are invalid")
    _require(block.get("errors") == [], f"{spec.role} execution inputs contain errors")
    _require(
        block.get("expected_count") == EXPECTED_EXECUTION_INPUT_COUNT,
        f"{spec.role} execution input expected_count is not {EXPECTED_EXECUTION_INPUT_COUNT}",
    )
    rows = _as_list(block.get("artifacts"), f"{spec.role} execution input artifacts")
    _require(
        len(rows) == EXPECTED_EXECUTION_INPUT_COUNT,
        f"{spec.role} execution input count is not {EXPECTED_EXECUTION_INPUT_COUNT}",
    )
    canonical_rows: list[dict[str, Any]] = []
    observation_rows: list[dict[str, Any]] = []
    roles: set[str] = set()
    paths: set[str] = set()
    for index, row_value in enumerate(rows):
        row = _as_dict(row_value, f"{spec.role} execution input {index}")
        _require(row.get("index") == index, f"{spec.role} execution input index mismatch at {index}")
        _require(row.get("valid") is True, f"{spec.role} execution input {index} is invalid")
        role = row.get("role")
        path_text = row.get("path")
        _require(isinstance(role, str) and bool(role), f"{spec.role} execution input {index} role invalid")
        _require(role not in roles, f"{spec.role} execution input role duplicated: {role}")
        roles.add(role)
        _require(
            isinstance(path_text, str) and Path(path_text).is_absolute(),
            f"{spec.role} execution input {role} path invalid",
        )
        path_identity = os.path.normcase(os.path.abspath(path_text))
        _require(path_identity not in paths, f"{spec.role} execution input path duplicated: {path_text}")
        paths.add(path_identity)
        expected_sha = _canonical_lower_hash(
            row.get("expected_sha256"), f"{spec.role} execution input {role} expected SHA-256"
        )
        actual_sha = _canonical_lower_hash(
            row.get("actual_sha256"), f"{spec.role} execution input {role} actual SHA-256"
        )
        _require(expected_sha == actual_sha, f"{spec.role} execution input {role} hash mismatch")
        expected_bytes = _exact_int(
            row.get("expected_bytes"), f"{spec.role} execution input {role} expected bytes"
        )
        actual_bytes = _exact_int(
            row.get("actual_bytes"), f"{spec.role} execution input {role} actual bytes"
        )
        _require(
            expected_bytes >= 0 and expected_bytes == actual_bytes,
            f"{spec.role} execution input {role} byte count mismatch",
        )
        actual_resolved_path = row.get("actual_resolved_path")
        _require(
            isinstance(actual_resolved_path, str)
            and Path(actual_resolved_path).is_absolute(),
            f"{spec.role} execution input {role} resolved path invalid",
        )
        canonical_rows.append(
            {"role": role, "path": path_text, "sha256": actual_sha, "bytes": actual_bytes}
        )
        observation_rows.append(
            {
                "role": role,
                "path": path_text,
                "resolved_path": actual_resolved_path,
                "sha256": actual_sha,
                "bytes": actual_bytes,
            }
        )
    _require(
        canonical_rows == sorted(canonical_rows, key=lambda row: (row["role"], row["path"])),
        f"{spec.role} execution inputs are not in canonical role/path order",
    )
    actual_identity = _canonical_sha(canonical_rows)
    recorded_identity = _canonical_lower_hash(
        block.get("canonical_sha256"), f"{spec.role} recorded execution-input identity"
    )
    _require(actual_identity == recorded_identity, f"{spec.role} execution-input list hash is inconsistent")
    _require(actual_identity == expected_identity, f"{spec.role} execution-input identity mismatch")
    observed_identity = _canonical_lower_hash(
        block.get("observed_bundle_sha256"),
        f"{spec.role} observed execution-input bundle SHA-256",
    )
    _require(
        observed_identity == _canonical_sha(observation_rows),
        f"{spec.role} observed execution-input bundle hash is inconsistent",
    )
    return canonical_rows, actual_identity, observed_identity


def _select_stream(block: dict[str, Any], stream_type: str, label: str) -> dict[str, Any]:
    if isinstance(block.get("streams"), list):
        rows = [
            _as_dict(row, f"{label} stream")
            for row in _as_list(block.get("streams"), f"{label} streams")
        ]
        selected = [row for row in rows if row.get("stream_type") == stream_type]
        _require(len(selected) == 1, f"{label} must contain exactly one {stream_type} stream")
        return selected[0]
    _require(block.get("stream_type") == stream_type, f"{label} is not a {stream_type} stream")
    return block


def _validate_fingerprint(value: Any, label: str) -> dict[str, Any]:
    row = _as_dict(value, label)
    _require(row.get("exists") is True, f"{label} does not exist")
    sha = _canonical_lower_hash(row.get("sha256"), f"{label} SHA-256")
    byte_count = _exact_int(row.get("bytes"), f"{label} bytes")
    lines = _exact_int(row.get("lines"), f"{label} lines")
    _require(byte_count >= 0 and lines >= 0, f"{label} size/line count is negative")
    return {"sha256": sha, "bytes": byte_count, "lines": lines}


def _validate_harvest(receipt: dict[str, Any], spec: OperandSpec) -> dict[str, Any]:
    post = _as_dict(receipt.get("post_run_stream"), f"{spec.role} post-run stream")
    preflight = _as_dict(receipt.get("preflight"), f"{spec.role} preflight")
    pre = _as_dict(preflight.get("post_run_stream"), f"{spec.role} preflight stream")
    _require(post.get("requested") is True, f"{spec.role} post-run stream was not requested")
    _require(post.get("valid") is True, f"{spec.role} post-run stream is invalid")
    _require(pre.get("requested") is True, f"{spec.role} preflight stream was not requested")
    _require(pre.get("valid") is True, f"{spec.role} preflight stream is invalid")

    if spec.role == "joint":
        _require(post.get("mode") == "atomic_multi", "joint harvest is not atomic_multi")
        _require(pre.get("mode") == "atomic_multi", "joint preflight harvest is not atomic_multi")
        _require(post.get("errors") == [], "joint harvest contains errors")
        _require(pre.get("errors") == [], "joint preflight harvest contains errors")
        post_rows = _as_list(post.get("streams"), "joint harvested streams")
        pre_rows = _as_list(pre.get("streams"), "joint preflight streams")
        _require(len(post_rows) == 2 and len(pre_rows) == 2, "joint receipt must bind exactly q08_trades and q08_equity")
        _require(
            {row.get("stream_type") for row in post_rows if isinstance(row, dict)}
            == {"q08_trades", "q08_equity"},
            "joint harvested stream roles mismatch",
        )
        _require(
            {row.get("stream_type") for row in pre_rows if isinstance(row, dict)}
            == {"q08_trades", "q08_equity"},
            "joint preflight stream roles mismatch",
        )
        for row in post_rows:
            _require(isinstance(row, dict) and row.get("valid") is True, "joint atomic stream member invalid")
    else:
        _require("streams" not in post and "streams" not in pre, "standalone receipt must use one q08_trades stream")

    selected = _select_stream(post, "q08_trades", f"{spec.role} harvest")
    pre_selected = _select_stream(pre, "q08_trades", f"{spec.role} preflight harvest")
    _require(selected.get("valid") is True, f"{spec.role} q08_trades harvest invalid")
    source_text = selected.get("source")
    target_text = selected.get("target")
    _require(
        isinstance(source_text, str) and Path(source_text).is_absolute(),
        f"{spec.role} q08_trades source path invalid",
    )
    _require(
        isinstance(target_text, str) and Path(target_text).is_absolute(),
        f"{spec.role} q08_trades target path invalid",
    )
    _require(
        pre_selected.get("source") == source_text and pre_selected.get("target") == target_text,
        f"{spec.role} q08_trades preflight/post path binding mismatch",
    )
    source = Path(source_text)
    target = Path(target_text)
    _require(source.stem == spec.source_stem, f"{spec.role} q08_trades source stem mismatch")
    _require(
        target.name == f"q08_trades_{spec.source_stem}.timer_v2.jsonl",
        f"{spec.role} harvested q08_trades filename mismatch",
    )
    _require(
        target.parent.name == receipt.get("work_item_id"),
        f"{spec.role} harvested q08_trades is outside its work-item directory",
    )

    fingerprints = {
        name: _validate_fingerprint(selected.get(name), f"{spec.role} q08_trades {name}")
        for name in ("post_run_source", "staged", "post_stage_source", "harvested")
    }
    content_identity = {
        (row["sha256"], row["bytes"], row["lines"])
        for row in fingerprints.values()
    }
    _require(len(content_identity) == 1, f"{spec.role} q08_trades harvest fingerprints diverge")

    publication = _as_dict(post.get("publication"), f"{spec.role} harvest publication")
    published = _as_list(publication.get("published_targets"), f"{spec.role} published targets")
    _require(published.count(target_text) == 1, f"{spec.role} q08_trades target was not published exactly once")
    _require(publication.get("rollback_attempted") is False, f"{spec.role} harvest rollback was attempted")
    _require(publication.get("published_before_rollback") == [], f"{spec.role} harvest has rollback residue")
    return {
        "source": source_text,
        "target": target_text,
        **fingerprints["harvested"],
    }


def _validate_completed_runner_contract(
    receipt: dict[str, Any], spec: OperandSpec
) -> None:
    _require(receipt.get("state") == "completed", f"{spec.role} runner receipt is not completed")
    _require(receipt.get("success") is True, f"{spec.role} runner receipt success is not true")
    checks = _as_dict(receipt.get("success_checks"), f"{spec.role} success checks")
    _require(
        checks == {key: True for key in SUCCESS_CHECK_KEYS},
        f"{spec.role} success_checks keyset/value contract mismatch",
    )
    containment = _as_dict(
        receipt.get("process_tree_containment"),
        f"{spec.role} process-tree containment",
    )
    _require(
        containment.get("valid") is True,
        f"{spec.role} process-tree containment is invalid",
    )
    quiescence = _as_dict(
        receipt.get("post_run_quiescence"), f"{spec.role} post-run quiescence"
    )
    _require(quiescence.get("valid") is True, f"{spec.role} post-run quiescence is invalid")
    _require(quiescence.get("after") == [], f"{spec.role} post-run process census is not empty")


def _validate_post_execution_inputs(
    receipt: dict[str, Any],
    spec: OperandSpec,
    *,
    expected_rows: list[dict[str, Any]],
    expected_identity: str,
    expected_observed_identity: str,
) -> None:
    block = _as_dict(
        receipt.get("post_execution_inputs"),
        f"{spec.role} post-run execution inputs",
    )
    rows, identity, observed = _validate_execution_inputs(
        {"preflight": {"execution_inputs": block}},
        spec,
        expected_identity,
    )
    _require(rows == expected_rows, f"{spec.role} execution input rows changed during run")
    _require(identity == expected_identity, f"{spec.role} post-run execution input identity mismatch")
    _require(
        observed == expected_observed_identity,
        f"{spec.role} observed execution input bundle changed during run",
    )
    _require(
        block.get("pre_observed_bundle_sha256") == expected_observed_identity,
        f"{spec.role} post-run execution input pre-observation mismatch",
    )


def _validate_payload_revalidation(
    receipt: dict[str, Any], spec: OperandSpec, pre_payload_sha256: str
) -> str:
    top_pre = _canonical_lower_hash(
        receipt.get("pre_payload_sha256"), f"{spec.role} top-level pre-payload SHA-256"
    )
    top_post = _canonical_lower_hash(
        receipt.get("post_payload_sha256"), f"{spec.role} top-level post-payload SHA-256"
    )
    _require(top_pre == pre_payload_sha256, f"{spec.role} pre-payload binding mismatch")
    block = _as_dict(
        receipt.get("payload_contract_revalidation"),
        f"{spec.role} payload contract revalidation",
    )
    _require(block.get("requested") is True, f"{spec.role} payload revalidation was not requested")
    _require(block.get("valid") is True, f"{spec.role} payload revalidation is invalid")
    _require(block.get("errors") == [], f"{spec.role} payload revalidation contains errors")
    _require(
        block.get("pre_payload_sha256") == top_pre,
        f"{spec.role} payload revalidation pre-hash mismatch",
    )
    _require(
        block.get("post_payload_sha256") == top_post,
        f"{spec.role} payload revalidation post-hash mismatch",
    )
    for key in (
        "changed_immutable_keys",
        "removed_immutable_keys",
        "unexpected_added_runtime_keys",
    ):
        _require(block.get(key) == [], f"{spec.role} payload revalidation {key} is not empty")
    return top_post


def _validate_post_fidelity_receipt(receipt: dict[str, Any], spec: OperandSpec) -> None:
    stage = int(spec.rung[1])
    required = stage > 0
    preflight = _as_dict(receipt.get("preflight"), f"{spec.role} preflight")
    prior = _as_dict(
        preflight.get("fidelity_receipt"), f"{spec.role} prior fidelity receipt"
    )
    post = _as_dict(
        receipt.get("post_fidelity_receipt"),
        f"{spec.role} post-run fidelity receipt",
    )
    for label, block in (("prior", prior), ("post-run", post)):
        _require(block.get("required") is required, f"{spec.role} {label} fidelity required flag mismatch")
        _require(block.get("valid") is True, f"{spec.role} {label} fidelity receipt is invalid")
        _require(block.get("errors") == [], f"{spec.role} {label} fidelity receipt contains errors")
    if required:
        _require(prior.get("requested") is True, f"{spec.role} prior fidelity receipt was not requested")
        _require(prior.get("required_stage") == stage - 1, f"{spec.role} prior fidelity stage mismatch")
        _require(
            post.get("post_sha256") == prior.get("actual_sha256")
            and post.get("post_bytes") == prior.get("bytes"),
            f"{spec.role} prior fidelity receipt changed during run",
        )
    else:
        _require(prior.get("requested") is False, f"{spec.role} rung must not consume a prior fidelity receipt")


def _validate_post_evidence(receipt: dict[str, Any], spec: OperandSpec) -> dict[str, Any]:
    post_work = _as_dict(receipt.get("post_work_item"), f"{spec.role} post work item")
    evidence = _as_dict(receipt.get("post_evidence"), f"{spec.role} post evidence")
    _require(evidence.get("valid") is True, f"{spec.role} post evidence is invalid")
    _require(evidence.get("errors") == [], f"{spec.role} post evidence contains errors")
    path_text = evidence.get("path")
    _require(
        isinstance(path_text, str)
        and Path(path_text).is_absolute()
        and path_text == post_work.get("evidence_path"),
        f"{spec.role} post evidence path binding mismatch",
    )
    expected_sha = _canonical_lower_hash(
        evidence.get("sha256"), f"{spec.role} post evidence SHA-256"
    )
    resolved, raw, actual_sha = _read_bound_bytes(
        Path(path_text), expected_sha, f"{spec.role} post evidence"
    )
    _require(
        evidence.get("resolved_path") == str(resolved),
        f"{spec.role} post evidence resolved-path mismatch",
    )
    _require(
        evidence.get("bytes") == len(raw),
        f"{spec.role} post evidence byte count mismatch",
    )
    return {"path": path_text, "resolved_path": str(resolved), "sha256": actual_sha, "bytes": len(raw)}


def _validate_receipt(
    receipt: dict[str, Any],
    spec: OperandSpec,
    *,
    receipt_path: Path,
    receipt_sha256: str,
    expected_source_commit: str,
    expected_execution_identity: str,
) -> dict[str, Any]:
    _require(receipt.get("schema_version") == 1, f"{spec.role} runner receipt schema_version mismatch")
    _require(receipt.get("mode") == "apply", f"{spec.role} receipt is not an apply receipt")
    _validate_completed_runner_contract(receipt, spec)
    _require(receipt.get("terminal") == "T10", f"{spec.role} receipt terminal is not T10")
    _require(
        type(receipt.get("worker_exit_code")) is int and receipt.get("worker_exit_code") == 0,
        f"{spec.role} worker did not exit successfully",
    )
    _require(receipt.get("live_scope_touched") is False, f"{spec.role} receipt touched live scope")
    _require(receipt.get("autotrading_touched") is False, f"{spec.role} receipt touched AutoTrading")
    factory_off_sha = _canonical_lower_hash(
        receipt.get("factory_off_sha256"), f"{spec.role} receipt FACTORY_OFF SHA-256"
    )
    started = _utc_timestamp(receipt.get("started_at_utc"), f"{spec.role} started_at_utc")
    completed = _utc_timestamp(receipt.get("completed_at_utc"), f"{spec.role} completed_at_utc")
    _require(started <= completed, f"{spec.role} completion predates start")

    work_id = receipt.get("work_item_id")
    _require(isinstance(work_id, str) and bool(work_id), f"{spec.role} work_item_id invalid")
    preflight = _as_dict(receipt.get("preflight"), f"{spec.role} preflight")
    _require(preflight.get("valid") is True, f"{spec.role} preflight is invalid")
    _require(preflight.get("errors") == [], f"{spec.role} preflight contains errors")
    _require(preflight.get("terminal") == "T10", f"{spec.role} preflight terminal mismatch")
    _require(preflight.get("work_item_id") == work_id, f"{spec.role} preflight work_item_id mismatch")
    _require(
        preflight.get("factory_off_sha256") == factory_off_sha,
        f"{spec.role} preflight/post FACTORY_OFF binding mismatch",
    )
    work = _as_dict(preflight.get("work_item"), f"{spec.role} preflight work item")
    expected_work = {
        "ea_id": spec.ea_id,
        "symbol": spec.work_symbol,
        "phase": "Q02",
        "status": "pending",
        "claimed_by": None,
        "measurement_rung": spec.rung,
        "measurement_sequence": spec.sequence,
        "evidence_run_id": spec.evidence_run_id,
    }
    for key, expected in expected_work.items():
        _require(work.get(key) == expected, f"{spec.role} preflight work item {key} mismatch")
    payload_sha = _canonical_lower_hash(
        work.get("payload_sha256"), f"{spec.role} preflight payload SHA-256"
    )
    post = _as_dict(receipt.get("post_work_item"), f"{spec.role} post work item")
    _require(post.get("id") == work_id, f"{spec.role} post work_item_id mismatch")
    _require(post.get("status") == "done", f"{spec.role} post work item is not done")
    _require(post.get("verdict") == "PASS", f"{spec.role} post work item verdict is not PASS")
    _require(post.get("claimed_by") is None, f"{spec.role} post work item remains claimed")

    source_binding = _validate_source_binding(receipt, spec, expected_source_commit)
    artifacts = _validate_artifacts(receipt, spec)
    execution_rows, execution_identity, observed_execution_identity = _validate_execution_inputs(
        receipt, spec, expected_execution_identity
    )
    _validate_post_execution_inputs(
        receipt,
        spec,
        expected_rows=execution_rows,
        expected_identity=execution_identity,
        expected_observed_identity=observed_execution_identity,
    )
    post_runtime_sources = _validate_runtime_source_block(
        receipt.get("post_runtime_sources"), spec
    )
    _require(
        post_runtime_sources == source_binding["runtime_sources"],
        f"{spec.role} runtime sources changed during run",
    )
    post_payload_sha = _validate_payload_revalidation(receipt, spec, payload_sha)
    _validate_post_fidelity_receipt(receipt, spec)
    post_evidence = _validate_post_evidence(receipt, spec)
    worker_sha = _canonical_lower_hash(
        preflight.get("worker_sha256"), f"{spec.role} preflight worker SHA-256"
    )
    _require(
        worker_sha == source_binding["terminal_worker"]["sha256"],
        f"{spec.role} terminal worker binding mismatch",
    )
    worker_path = preflight.get("worker_script")
    _require(
        isinstance(worker_path, str)
        and os.path.normcase(os.path.abspath(worker_path))
        == source_binding["terminal_worker"]["path"],
        f"{spec.role} terminal worker path mismatch",
    )
    harvest = _validate_harvest(receipt, spec)
    return {
        "role": spec.role,
        "rung": spec.rung,
        "sequence": spec.sequence,
        "receipt_path": str(receipt_path),
        "receipt_sha256": receipt_sha256,
        "work_item_id": work_id,
        "started_at_utc": started.isoformat(),
        "completed_at_utc": completed.isoformat(),
        "source_commit": expected_source_commit,
        "factory_off_sha256": factory_off_sha,
        "source_binding": source_binding,
        "runner_artifacts": artifacts,
        "execution_input_artifacts_sha256": execution_identity,
        "execution_input_observed_bundle_sha256": observed_execution_identity,
        "execution_input_artifacts": execution_rows,
        "post_payload_sha256": post_payload_sha,
        "post_evidence": post_evidence,
        "q08_trades": harvest,
        "magic": spec.trade_magic,
        "symbol": spec.trade_symbol,
    }


def _decimal(value: Any, label: str) -> Decimal:
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        raise SetupBlocked(f"{label} must be numeric")
    if isinstance(value, float) and not math.isfinite(value):
        raise SetupBlocked(f"{label} must be finite")
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise SetupBlocked(f"{label} is not a valid decimal") from exc
    if not parsed.is_finite():
        raise SetupBlocked(f"{label} must be finite")
    return parsed


def _positive_deal_ids(value: Any, label: str) -> list[int]:
    _require(isinstance(value, list) and bool(value), f"{label} must be a non-empty array")
    result = [_exact_int(item, f"{label}[{index}]") for index, item in enumerate(value)]
    _require(all(item > 0 for item in result), f"{label} must contain only positive integers")
    _require(len(result) == len(set(result)), f"{label} contains duplicate deal IDs")
    return result


def _validate_joint_lineage(
    row: dict[str, Any],
    money: dict[str, Decimal],
    *,
    label: str,
    entry_time: int,
    close_time: int,
) -> None:
    """Validate lifecycle-v2 deal lineage and its declared balance ledger.

    The lineage grammar can represent ordered partial exits without pretending
    they happened at the final close timestamp.  The current Book-3 joint
    producer separately setup-blocks ``exit_count != 1`` because its one-row-
    per-position output would not have the standalone producer's per-exit
    cardinality.  This validator therefore does not imply generic partial-close
    fidelity support.
    """

    position_id = _exact_int(row.get("position_id"), f"{label} position_id")
    _require(position_id > 0, f"{label} position_id must be positive")
    entry_ids = _positive_deal_ids(row.get("entry_deal_ids"), f"{label} entry_deal_ids")
    exit_ids = _positive_deal_ids(row.get("exit_deal_ids"), f"{label} exit_deal_ids")
    _require(
        not (set(entry_ids) & set(exit_ids)),
        f"{label} entry/exit deal IDs overlap",
    )

    events = row.get("balance_events")
    _require(
        isinstance(events, list) and bool(events),
        f"{label} balance_events must be a non-empty array",
    )
    exact_fields = {"deal_id", "time", "component", "amount"}
    allowed_components = {"PROFIT", "SWAP", "COMMISSION", "FEE"}
    entry_id_set = set(entry_ids)
    exit_id_set = set(exit_ids)
    seen: set[tuple[int, str]] = set()
    event_time_by_deal: dict[int, int] = {}
    amounts: dict[tuple[str, str], Decimal] = {}

    for index, event in enumerate(events):
        event_label = f"{label} balance_events[{index}]"
        _require(isinstance(event, dict), f"{event_label} must be an object")
        _require(set(event) == exact_fields, f"{event_label} fields mismatch")
        deal_id = _exact_int(event["deal_id"], f"{event_label} deal_id")
        _require(deal_id > 0, f"{event_label} deal_id must be positive")
        event_time = _exact_int(event["time"], f"{event_label} time")
        _require(event_time > 0, f"{event_label} time must be positive")
        component = event["component"]
        _require(
            isinstance(component, str) and component in allowed_components,
            f"{event_label} component invalid",
        )
        _require(
            not isinstance(event["amount"], bool)
            and isinstance(event["amount"], (int, float)),
            f"{event_label} amount must be a JSON number",
        )
        amount = _decimal(event["amount"], f"{event_label} amount")
        identity = (deal_id, component)
        _require(identity not in seen, f"{event_label} duplicates deal/component")
        seen.add(identity)
        previous_time = event_time_by_deal.setdefault(deal_id, event_time)
        _require(
            previous_time == event_time,
            f"{event_label} deal components have inconsistent times",
        )

        if deal_id in entry_id_set:
            _require(component == "COMMISSION", f"{event_label} entry component invalid")
            _require(
                entry_time <= event_time <= close_time,
                f"{event_label} entry event time outside lifecycle",
            )
            bucket = ("entry", component)
        else:
            _require(deal_id in exit_id_set, f"{event_label} deal_id outside declared lineage")
            _require(
                entry_time <= event_time <= close_time,
                f"{event_label} exit event time outside lifecycle",
            )
            bucket = ("exit", component)
        amounts[bucket] = amounts.get(bucket, Decimal("0")) + amount

    for deal_id in entry_ids:
        _require(
            (deal_id, "COMMISSION") in seen,
            f"{label} entry deal {deal_id} lacks COMMISSION event",
        )
    for deal_id in exit_ids:
        for component in allowed_components:
            _require(
                (deal_id, component) in seen,
                f"{label} exit deal {deal_id} lacks {component} event",
            )
    entry_event_times = [event_time_by_deal[deal_id] for deal_id in entry_ids]
    exit_event_times = [event_time_by_deal[deal_id] for deal_id in exit_ids]
    _require(
        entry_event_times == sorted(entry_event_times),
        f"{label} entry deal/event ordering is not monotonic",
    )
    _require(
        exit_event_times == sorted(exit_event_times),
        f"{label} exit deal/event ordering is not monotonic",
    )
    _require(
        entry_event_times[0] == entry_time,
        f"{label} first entry deal does not establish entry_time",
    )
    _require(
        exit_event_times[-1] == close_time,
        f"{label} final exit deal does not establish close time",
    )

    expected = {
        ("entry", "COMMISSION"): money["entry_commission"],
        ("exit", "PROFIT"): money["profit"],
        ("exit", "SWAP"): money["swap"],
        ("exit", "COMMISSION"): money["exit_commission"],
        ("exit", "FEE"): money["fee"],
    }
    _require(set(amounts) == set(expected), f"{label} balance-event components mismatch")
    for bucket, declared in expected.items():
        _require(
            amounts[bucket] == declared,
            f"{label} balance-event {bucket[0]} {bucket[1]} does not reconcile",
        )


def _full_lifecycle_money(
    row: dict[str, Any], *, spec: OperandSpec, label: str
) -> dict[str, Decimal]:
    """Validate one producer's actual full-position money decomposition.

    V2 deliberately compares producer truth without reconstructing a missing
    entry-side cost in Python.  Standalone rows must therefore carry the
    framework's explicit full-lifecycle marker; joint rows must carry the
    already-versioned lifecycle-v2 identity.  Any legacy or ambiguous row is
    setup-blocked rather than normalized heuristically.
    """

    if spec.role == "standalone":
        _require(
            "schema_version" not in row,
            f"{label} standalone schema_version is ambiguous",
        )
        _require(
            row.get("money_basis") == FULL_LIFECYCLE_MONEY_BASIS,
            f"{label} standalone money_basis mismatch",
        )
    else:
        _require(row.get("schema_version") == 2, f"{label} joint schema_version mismatch")
        _require(
            row.get("producer_version") == JOINT_PRODUCER_VERSION,
            f"{label} joint producer_version mismatch",
        )
        _require(row.get("run_id") == spec.evidence_run_id, f"{label} joint run_id mismatch")
        _require(
            row.get("position_fully_closed") is True,
            f"{label} joint position is not fully closed",
        )
    values = {
        key: _decimal(row.get(key), f"{label} {key}")
        for key in (
            "profit",
            "swap",
            "commission",
            "entry_commission",
            "exit_commission",
            "net",
        )
    }
    _require("fee" in row, f"{label} fee is missing")
    fee = _decimal(row["fee"], f"{label} fee")
    _require(abs(fee) <= MONEY_TOLERANCE, f"{label} non-zero fee is unsupported")
    _require(
        abs(
            values["commission"]
            - values["entry_commission"]
            - values["exit_commission"]
        )
        <= MONEY_TOLERANCE,
        f"{label} commission components do not reconcile",
    )
    _require(
        abs(
            values["net"]
            - values["profit"]
            - values["swap"]
            - values["commission"]
            - fee
        )
        <= MONEY_TOLERANCE,
        f"{label} full-lifecycle net does not reconcile",
    )
    values["fee"] = fee
    return values


def _load_trades_once(path: Path, expected: dict[str, Any], spec: OperandSpec, stage: int) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    resolved, raw, actual_sha = _read_bound_bytes(
        path, str(expected["sha256"]), f"{spec.role} harvested q08_trades"
    )
    _require(
        os.path.normcase(os.path.abspath(str(path))) == os.path.normcase(str(resolved)),
        f"{spec.role} harvested q08_trades path resolves through an alias or link",
    )
    _require(len(raw) == expected["bytes"], f"{spec.role} q08_trades byte count mismatch")
    physical_lines = len(raw.splitlines())
    _require(physical_lines == expected["lines"], f"{spec.role} q08_trades line count mismatch")

    selected: list[dict[str, Any]] = []
    # The explicit ladder order matters; future sleeves are invalid in an
    # earlier joint rung even if the requested comparison sleeve is present.
    joint_ladder = (
        (201810000, "USDJPY.DWX"),
        (201810001, "XAUUSD.DWX"),
        (201810002, "XTIUSD.DWX"),
    )
    allowed_joint_pairs = set(joint_ladder[: stage + 1])
    for line_number, line in enumerate(raw.splitlines(), start=1):
        if not line.strip():
            continue
        row = _strict_json(line, f"{spec.role} q08_trades line {line_number}")
        if not isinstance(row, dict):
            raise SetupBlocked(f"{spec.role} q08_trades line {line_number} is not an object")
        if row.get("event") != "TRADE_CLOSED":
            continue
        magic = _exact_int(row.get("magic"), f"{spec.role} trade line {line_number} magic")
        symbol = row.get("symbol")
        _require(isinstance(symbol, str) and bool(symbol), f"{spec.role} trade line {line_number} symbol invalid")
        pair = (magic, symbol)
        if spec.role == "standalone":
            _require(pair == (spec.trade_magic, spec.trade_symbol), f"{spec.role} contains an unexpected TRADE_CLOSED sleeve {pair}")
        else:
            _require(pair in allowed_joint_pairs, f"joint contains an unexpected or not-yet-enabled TRADE_CLOSED sleeve {pair}")
        if pair != (spec.trade_magic, spec.trade_symbol):
            continue
        entry_time = _exact_int(row.get("entry_time"), f"{spec.role} trade line {line_number} entry_time")
        close_time = _exact_int(row.get("time"), f"{spec.role} trade line {line_number} time")
        _require(entry_time > 0 and close_time > entry_time, f"{spec.role} trade line {line_number} time order invalid")
        label = f"{spec.role} trade line {line_number}"
        money = _full_lifecycle_money(row, spec=spec, label=label)
        if spec.role == "joint":
            _validate_joint_lineage(
                row,
                money,
                label=label,
                entry_time=entry_time,
                close_time=close_time,
            )
        side = row.get("side")
        _require(
            isinstance(side, str) and side in CANONICAL_SIDES,
            f"{label} side must be canonical BUY or SELL",
        )
        entry_price = _decimal(row.get("entry_price"), f"{label} entry_price")
        exit_price = _decimal(row.get("exit_price"), f"{label} exit_price")
        _require(entry_price > 0, f"{label} entry_price must be positive")
        _require(exit_price > 0, f"{label} exit_price must be positive")
        volume = _decimal(row.get("volume"), f"{spec.role} trade line {line_number} volume")
        _require(volume > 0, f"{spec.role} trade line {line_number} volume must be positive")
        selected.append(
            {
                "entry_time": entry_time,
                "time": close_time,
                "side": side,
                "entry_price": entry_price,
                "exit_price": exit_price,
                **money,
                "volume": volume,
                "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
            }
        )
    return selected, {
        "path": str(resolved),
        "sha256": actual_sha,
        "bytes": len(raw),
        "lines": physical_lines,
        "selected_trade_count": len(selected),
    }


def _maximum_matching(
    joint: list[dict[str, Any]], standalone: list[dict[str, Any]]
) -> tuple[int, set[int], set[int]]:
    reference_by_time: dict[tuple[int, int], list[int]] = {}
    for index, row in enumerate(standalone):
        reference_by_time.setdefault((row["entry_time"], row["time"]), []).append(index)
    edges: list[list[int]] = []
    for joint_row in joint:
        candidates = []
        time_key = (joint_row["entry_time"], joint_row["time"])
        for index in reference_by_time.get(time_key, []):
            reference_row = standalone[index]
            if (
                joint_row["side"] == reference_row["side"]
                and abs(joint_row["entry_price"] - reference_row["entry_price"])
                <= PRICE_TOLERANCE
                and abs(joint_row["exit_price"] - reference_row["exit_price"])
                <= PRICE_TOLERANCE
                and all(
                    abs(joint_row[key] - reference_row[key]) <= MONEY_TOLERANCE
                    for key in (
                        "net",
                        "profit",
                        "swap",
                        "commission",
                        "entry_commission",
                        "exit_commission",
                        "fee",
                    )
                )
                and abs(joint_row["volume"] - reference_row["volume"]) <= VOLUME_TOLERANCE
            ):
                candidates.append(index)
        edges.append(candidates)

    matched_reference: dict[int, int] = {}

    def augment(joint_index: int, seen: set[int]) -> bool:
        for reference_index in edges[joint_index]:
            if reference_index in seen:
                continue
            seen.add(reference_index)
            previous = matched_reference.get(reference_index)
            if previous is None or augment(previous, seen):
                matched_reference[reference_index] = joint_index
                return True
        return False

    # Fewest candidates first makes the deterministic result easier to audit;
    # augmenting paths still produce a maximum-cardinality matching.
    order = sorted(range(len(joint)), key=lambda index: (len(edges[index]), index))
    for joint_index in order:
        augment(joint_index, set())
    matched_joint = set(matched_reference.values())
    matched_standalone = set(matched_reference)
    return len(matched_reference), matched_joint, matched_standalone


def _public_trade(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "entry_time": row["entry_time"],
        "time": row["time"],
        "side": row["side"],
        "entry_price": str(row["entry_price"]),
        "exit_price": str(row["exit_price"]),
        "net": str(row["net"]),
        "profit": str(row["profit"]),
        "swap": str(row["swap"]),
        "commission": str(row["commission"]),
        "entry_commission": str(row["entry_commission"]),
        "exit_commission": str(row["exit_commission"]),
        "fee": str(row["fee"]),
        "volume": str(row["volume"]),
    }


def _comparison(joint: list[dict[str, Any]], standalone: list[dict[str, Any]]) -> dict[str, Any]:
    matched, matched_joint, matched_standalone = _maximum_matching(joint, standalone)
    unmatched_joint = [
        _public_trade(row) for index, row in enumerate(joint) if index not in matched_joint
    ]
    unmatched_standalone = [
        _public_trade(row)
        for index, row in enumerate(standalone)
        if index not in matched_standalone
    ]
    denominator = max(len(joint), len(standalone))
    match_rate = matched / denominator if denominator else None
    return {
        "algorithm": "maximum_bipartite_exact_time_side_price_full_lifecycle_money_volume/v3",
        "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
        "money_tolerance": float(MONEY_TOLERANCE),
        "volume_tolerance": float(VOLUME_TOLERANCE),
        "price_tolerance": float(PRICE_TOLERANCE),
        "standalone_trades": len(standalone),
        "joint_trades": len(joint),
        "matched": matched,
        "unmatched_standalone": len(unmatched_standalone),
        "unmatched_joint": len(unmatched_joint),
        "match_rate": round(match_rate, 12) if match_rate is not None else None,
        "unmatched_standalone_sample": unmatched_standalone[:20],
        "unmatched_joint_sample": unmatched_joint[:20],
    }


def _adjudication_id(receipt: dict[str, Any]) -> str:
    identity = {key: value for key, value in receipt.items() if key not in {"generated_at_utc", "adjudication_id"}}
    return hashlib.sha256(_canonical_bytes(identity)).hexdigest()


def adjudicate(
    *,
    stage: int,
    standalone_receipt_path: Path,
    expected_standalone_receipt_sha256: str,
    joint_receipt_path: Path,
    expected_joint_receipt_sha256: str,
    expected_source_commit: str,
    expected_execution_input_artifacts_sha256: str,
    expected_controller_sha256: str,
    comparator_path: Path,
    expected_comparator_sha256: str,
) -> dict[str, Any]:
    generated = dt.datetime.now(dt.timezone.utc).isoformat()
    result: dict[str, Any] = {
        "schema": SCHEMA,
        "generated_at_utc": generated,
        "stage": stage,
        "verdict": "SETUP_BLOCKED",
        "work_item_ids": {"standalone": None, "joint": None},
        "source_commit": None,
        "execution_input_artifacts_sha256": None,
        "controller_path": str(Path(__file__).resolve()),
        "controller_sha256": None,
        "isolated_runner_sha256": None,
        "preparation_controller_sha256": None,
        "comparator_sha256": None,
        "errors": [],
        "contract": {
            "measurement_contract": MEASUREMENT_CONTRACT,
            "expected_execution_input_count": EXPECTED_EXECUTION_INPUT_COUNT,
            "match_rate_required": 1.0,
            "unmatched_required": 0,
            "both_operands_nonempty": True,
            "money_tolerance": float(MONEY_TOLERANCE),
            "volume_tolerance": float(VOLUME_TOLERANCE),
            "price_tolerance": float(PRICE_TOLERANCE),
            "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
        },
        "safety": {
            "read_only_inputs": True,
            "create_only_output": True,
            "opens_factory_db": False,
            "runs_mt5": False,
            "mutates_factory_state": False,
            "touches_live_scope": False,
            "touches_autotrading": False,
        },
    }
    try:
        spec = STAGES.get(stage)
        if spec is None:
            raise SetupBlocked(f"unsupported FTMO Book-3 stage: {stage!r}")
        source_commit = _commit_argument(expected_source_commit, "expected source commit")
        execution_identity = _sha256_argument(
            expected_execution_input_artifacts_sha256,
            "expected execution-input identity",
        )
        controller_resolved, controller_bytes, controller_sha = _read_bound_bytes(
            Path(__file__).resolve(), expected_controller_sha256, "fidelity gate controller"
        )
        result["source_commit"] = source_commit
        result["execution_input_artifacts_sha256"] = execution_identity
        result["controller_path"] = str(controller_resolved)
        result["controller_sha256"] = controller_sha
        result["controller_bytes"] = len(controller_bytes)
        comparator_resolved, comparator_bytes, comparator_sha = _read_bound_bytes(
            comparator_path, expected_comparator_sha256, "fidelity comparator"
        )
        canonical_comparator = DEFAULT_COMPARATOR.resolve(strict=True)
        _require(
            comparator_resolved == canonical_comparator,
            f"fidelity comparator path mismatch: expected={canonical_comparator} actual={comparator_resolved}",
        )
        result["comparator"] = {
            "path": str(comparator_resolved),
            "sha256": comparator_sha,
            "bytes": len(comparator_bytes),
        }
        result["comparator_sha256"] = comparator_sha

        standalone_path, standalone_bytes, standalone_sha = _read_bound_bytes(
            standalone_receipt_path,
            expected_standalone_receipt_sha256,
            "standalone isolated-runner receipt",
        )
        joint_path, joint_bytes, joint_sha = _read_bound_bytes(
            joint_receipt_path,
            expected_joint_receipt_sha256,
            "joint isolated-runner receipt",
        )
        _require(standalone_path != joint_path, "standalone and joint receipt paths are identical")
        standalone_receipt = _strict_json(standalone_bytes, "standalone isolated-runner receipt")
        joint_receipt = _strict_json(joint_bytes, "joint isolated-runner receipt")
        standalone_receipt = _as_dict(standalone_receipt, "standalone isolated-runner receipt")
        joint_receipt = _as_dict(joint_receipt, "joint isolated-runner receipt")

        standalone = _validate_receipt(
            standalone_receipt,
            spec.standalone,
            receipt_path=standalone_path,
            receipt_sha256=standalone_sha,
            expected_source_commit=source_commit,
            expected_execution_identity=execution_identity,
        )
        joint = _validate_receipt(
            joint_receipt,
            spec.joint,
            receipt_path=joint_path,
            receipt_sha256=joint_sha,
            expected_source_commit=source_commit,
            expected_execution_identity=execution_identity,
        )
        _require(standalone["work_item_id"] != joint["work_item_id"], "standalone and joint work_item_id are identical")
        _require(
            standalone["source_binding"] == joint["source_binding"],
            "standalone/joint source vintage is spliced",
        )
        runtime_roles = standalone["source_binding"]["runtime_sources"]["roles"]
        _require(
            runtime_roles["fidelity_gate"]["sha256"] == controller_sha
            and runtime_roles["fidelity_gate"]["bytes"] == len(controller_bytes)
            and Path(runtime_roles["fidelity_gate"]["path"]).resolve(strict=True)
            == controller_resolved,
            "runner runtime-source manifest does not bind this fidelity gate controller",
        )
        _require(
            runtime_roles["fidelity_comparator"]["sha256"] == comparator_sha
            and runtime_roles["fidelity_comparator"]["bytes"] == len(comparator_bytes)
            and Path(runtime_roles["fidelity_comparator"]["path"]).resolve(strict=True)
            == comparator_resolved,
            "runner runtime-source manifest does not bind the authenticated comparator",
        )
        _require(
            standalone["execution_input_artifacts"] == joint["execution_input_artifacts"],
            "standalone/joint execution-input list is spliced",
        )
        _require(
            standalone["factory_off_sha256"] == joint["factory_off_sha256"],
            "standalone/joint FACTORY_OFF identity is spliced",
        )
        result["work_item_ids"] = {
            "standalone": standalone["work_item_id"],
            "joint": joint["work_item_id"],
        }
        result["isolated_runner_sha256"] = standalone["source_binding"]["isolated_runner"]["sha256"]
        result["preparation_controller_sha256"] = standalone["source_binding"]["preparation_controller"]["sha256"]
        standalone_completed = _utc_timestamp(
            standalone["completed_at_utc"], "standalone normalized completion"
        )
        joint_started = _utc_timestamp(joint["started_at_utc"], "joint normalized start")
        _require(
            standalone_completed <= joint_started,
            "serial ladder violated: joint run started before standalone run completed",
        )
        # The authenticated runner receipts already retain all 307 rows.  The
        # adjudication receipt needs their shared content identity and count,
        # not a second 614-row copy.
        standalone.pop("execution_input_artifacts")
        joint.pop("execution_input_artifacts")
        standalone["execution_input_artifact_count"] = EXPECTED_EXECUTION_INPUT_COUNT
        joint["execution_input_artifact_count"] = EXPECTED_EXECUTION_INPUT_COUNT

        standalone_trades, standalone_stream = _load_trades_once(
            Path(standalone["q08_trades"]["target"]),
            standalone["q08_trades"],
            spec.standalone,
            stage,
        )
        joint_trades, joint_stream = _load_trades_once(
            Path(joint["q08_trades"]["target"]),
            joint["q08_trades"],
            spec.joint,
            stage,
        )
        standalone["q08_trades"] = {**standalone["q08_trades"], **standalone_stream}
        joint["q08_trades"] = {**joint["q08_trades"], **joint_stream}
        result["operands"] = {"standalone": standalone, "joint": joint}
        if not standalone_trades or not joint_trades:
            raise SetupBlocked("empty filtered operand: standalone and joint trade sets must both be non-empty")
        comparison = _comparison(joint_trades, standalone_trades)
        result["comparison"] = comparison
        passed = (
            comparison["match_rate"] == 1.0
            and comparison["unmatched_standalone"] == 0
            and comparison["unmatched_joint"] == 0
        )
        result["verdict"] = "PASS" if passed else "FAIL"
        if not passed:
            result["errors"] = ["valid non-empty fidelity operands do not match exactly"]
    except SetupBlocked as exc:
        result["verdict"] = "SETUP_BLOCKED"
        result["errors"] = [str(exc)]
    except Exception as exc:  # unexpected input faults must never turn into PASS
        result["verdict"] = "SETUP_BLOCKED"
        result["errors"] = [f"unexpected fail-closed adjudication error: {type(exc).__name__}: {exc}"]
    result["adjudication_id"] = _adjudication_id(result)
    return result


def _write_create_only(path: Path, receipt: dict[str, Any]) -> None:
    if not path.is_absolute():
        raise ValueError(f"receipt output path must be absolute: {path}")
    if not path.parent.is_dir():
        raise FileNotFoundError(f"receipt output parent does not exist: {path.parent}")
    payload = _canonical_bytes(receipt)
    # Direct exclusive creation is intentionally used instead of os.replace:
    # no concurrent writer can ever be overwritten.
    with path.open("xb") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", required=True, type=int, choices=sorted(STAGES))
    parser.add_argument("--standalone-receipt", required=True, type=Path)
    parser.add_argument("--expected-standalone-receipt-sha256", required=True)
    parser.add_argument("--joint-receipt", required=True, type=Path)
    parser.add_argument("--expected-joint-receipt-sha256", required=True)
    parser.add_argument("--expected-source-commit", required=True)
    parser.add_argument("--expected-execution-input-artifacts-sha256", required=True)
    parser.add_argument("--expected-controller-sha256", required=True)
    parser.add_argument("--comparator-path", type=Path, default=DEFAULT_COMPARATOR)
    parser.add_argument("--expected-comparator-sha256", required=True)
    parser.add_argument("--receipt-out", required=True, type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    receipt = adjudicate(
        stage=args.stage,
        standalone_receipt_path=args.standalone_receipt,
        expected_standalone_receipt_sha256=args.expected_standalone_receipt_sha256,
        joint_receipt_path=args.joint_receipt,
        expected_joint_receipt_sha256=args.expected_joint_receipt_sha256,
        expected_source_commit=args.expected_source_commit,
        expected_execution_input_artifacts_sha256=args.expected_execution_input_artifacts_sha256,
        expected_controller_sha256=args.expected_controller_sha256,
        comparator_path=args.comparator_path,
        expected_comparator_sha256=args.expected_comparator_sha256,
    )
    try:
        _write_create_only(args.receipt_out, receipt)
    except Exception as exc:
        print(
            json.dumps(
                {"verdict": "SETUP_BLOCKED", "error": f"create-only publication failed: {exc}"},
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 4
    print(json.dumps(receipt, indent=2, ensure_ascii=False, sort_keys=True))
    return {"PASS": 0, "FAIL": 2, "SETUP_BLOCKED": 3}[receipt["verdict"]]


if __name__ == "__main__":
    raise SystemExit(main())
