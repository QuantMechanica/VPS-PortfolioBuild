#!/usr/bin/env python3
"""Strict OWNER authorization contract for a real Factory activation.

The 2026-08-02 preparation decision is deliberately *not* runtime authority.
Factory_ON and restart-hold release call this validator independently.  A
canonical runtime decision and its SHA-256 sidecar must exist, be committed,
be unmodified, be fresh, and bind the exact preparation decision, OFF record,
worker/hold cohort, and final source blobs.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


RUNTIME_ACTIVATION_RECORD_PREFIX = "QM_FACTORY_RUNTIME_ACTIVATION_V1:"


SCHEMA_VERSION = "qm.factory-runtime-activation-owner-decision/v1"
REPO_ROOT = Path(r"C:\QM\repo")
DECISION_RELATIVE_PATH = Path(
    "docs/ops/evidence/FACTORY_RUNTIME_ACTIVATION_OWNER_DECISION.json"
)
DIGEST_RELATIVE_PATH = Path(
    "docs/ops/evidence/FACTORY_RUNTIME_ACTIVATION_OWNER_DECISION.sha256"
)
PREPARATION_DECISION_RELATIVE_PATH = Path(
    "docs/ops/evidence/2026-08-09_factory_preparation_owner_decision_isolation.json"
)
PREPARATION_DECISION_SHA256 = (
    "e01667eb4881b80d8774c7adcebae28bab3a10ad4e857a12d0d8851336d1a450"
)
PREPARATION_DECISION_COMMIT = "191671ab3e2b7a3bff5573bffbb5db4f752872f9"
PREPARATION_DECISION_BLOB = "8336703fee1071f9e2494c1a063be85df34113a7"
FACTORY_ON_RELATIVE_PATH = Path("tools/strategy_farm/Factory_ON.ps1")
MAINTENANCE_CONTROL_RELATIVE_PATH = Path(
    "tools/strategy_farm/maintenance_control.py"
)
SOURCE_BINDING_PATHS = {
    "factory_on": FACTORY_ON_RELATIVE_PATH,
    "factory_off": Path("tools/strategy_farm/Factory_OFF.ps1"),
    "maintenance_control": MAINTENANCE_CONTROL_RELATIVE_PATH,
    "runtime_activation_validator": Path(
        "tools/strategy_farm/factory_runtime_activation.py"
    ),
    "restart_health": Path("tools/strategy_farm/factory_restart_health.ps1"),
    "process_scope": Path("tools/strategy_farm/factory_process_scope.ps1"),
    "mutation_lock_protocol": Path(
        "tools/strategy_farm/factory_mutation_lock.ps1"
    ),
    "task_manifest": Path("tools/strategy_farm/qm_tasks.manifest.ps1"),
    "worker_launcher": Path("tools/strategy_farm/start_terminal_workers.py"),
    "farmctl": Path("tools/strategy_farm/farmctl.py"),
    "public_snapshot_task_wrapper": Path("scripts/run_public_snapshot_task.ps1"),
    "public_snapshot_incident_guard": Path(
        "tools/strategy_farm/public_snapshot_incident_guard.py"
    ),
}
WORKER_TERMINALS = (
    "T1",
    "T2",
    "T3",
    "T4",
    "T5",
    "T6",
    "T7",
    "T8",
    "T9",
    "T10",
)
SHA256_RE = re.compile(r"[0-9a-f]{64}")
GIT_OID_RE = re.compile(r"[0-9a-f]{40}")
WORK_ITEM_ID_RE = re.compile(r"[0-9a-fA-F-]{36}")


class RuntimeActivationError(RuntimeError):
    """A fail-closed runtime-authorization validation error."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise RuntimeActivationError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _load_json(raw: bytes, *, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            raw.decode("utf-8"), object_pairs_hook=_reject_duplicate_keys
        )
    except (UnicodeError, json.JSONDecodeError, RuntimeActivationError) as exc:
        raise RuntimeActivationError(f"{label} is not strict UTF-8 JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise RuntimeActivationError(f"{label} must be a JSON object")
    return value


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _git_blob(raw: bytes) -> str:
    return hashlib.sha1(
        f"blob {len(raw)}\0".encode("ascii") + raw, usedforsecurity=False
    ).hexdigest()


def _git(repo_root: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            ("git", "-C", str(repo_root), *args),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="strict",
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.SubprocessError, UnicodeError) as exc:
        raise RuntimeActivationError(f"Git provenance probe failed: {exc}") from exc
    if result.returncode != 0:
        raise RuntimeActivationError(
            f"Git provenance probe failed ({' '.join(args)}): {result.stderr.strip()}"
        )
    return result.stdout.strip()


def _parse_utc(value: Any, *, label: str) -> dt.datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise RuntimeActivationError(f"{label} must be an exact UTC Z timestamp")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise RuntimeActivationError(f"{label} is not parseable") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != dt.timedelta(0):
        raise RuntimeActivationError(f"{label} must be UTC")
    return parsed


def _require_exact_keys(value: dict[str, Any], expected: set[str], *, label: str) -> None:
    actual = set(value)
    if actual != expected:
        raise RuntimeActivationError(
            f"{label} key-set mismatch: "
            f"missing={sorted(expected - actual)!r} extra={sorted(actual - expected)!r}"
        )


def _validated_restart_hold_plan(
    payload: dict[str, Any], *, label: str
) -> list[str]:
    restart_holds = payload.get("restart_holds")
    if not isinstance(restart_holds, dict):
        raise RuntimeActivationError(f"{label} restart_holds must be an object")
    work_item_ids = restart_holds.get("authorized_work_item_ids")
    authorized_release_count = restart_holds.get("authorized_release_count")
    if not isinstance(work_item_ids, list):
        raise RuntimeActivationError(
            f"{label} authorized_work_item_ids must be a list"
        )
    if type(authorized_release_count) is not int:
        raise RuntimeActivationError(
            f"{label} authorized_release_count must be an integer"
        )
    if any(
        not isinstance(work_item_id, str)
        or not work_item_id
        or WORK_ITEM_ID_RE.fullmatch(work_item_id) is None
        for work_item_id in work_item_ids
    ):
        raise RuntimeActivationError(
            f"{label} authorized_work_item_ids must contain UUID-shaped strings"
        )
    if len(work_item_ids) != len(set(work_item_ids)):
        raise RuntimeActivationError(
            f"{label} authorized_work_item_ids must be unique"
        )
    if authorized_release_count != len(work_item_ids):
        raise RuntimeActivationError(
            f"{label} authorized_release_count does not equal the declared plan length"
        )
    return list(work_item_ids)


def _verify_committed_file(
    repo_root: Path,
    relative_path: Path,
    *,
    expected_sha256: str | None = None,
    expected_commit: str | None = None,
    expected_blob: str | None = None,
) -> dict[str, str]:
    path = repo_root / relative_path
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise RuntimeActivationError(f"required file cannot be read: {path}: {exc}") from exc
    sha256 = _sha256(raw)
    blob = _git_blob(raw)
    if expected_sha256 is not None and sha256 != expected_sha256:
        raise RuntimeActivationError(
            f"{relative_path.as_posix()} SHA-256 mismatch: "
            f"expected={expected_sha256} actual={sha256}"
        )
    commit = expected_commit or _git(
        repo_root, "log", "-1", "--format=%H", "--", relative_path.as_posix()
    )
    if GIT_OID_RE.fullmatch(commit) is None:
        raise RuntimeActivationError(
            f"{relative_path.as_posix()} has no canonical commit provenance"
        )
    resolved_commit = _git(repo_root, "rev-parse", f"{commit}^{{commit}}")
    committed_blob = _git(
        repo_root, "rev-parse", f"{commit}:{relative_path.as_posix()}"
    )
    if resolved_commit != commit:
        raise RuntimeActivationError(
            f"{relative_path.as_posix()} commit identity mismatch"
        )
    if expected_blob is not None and committed_blob != expected_blob:
        raise RuntimeActivationError(
            f"{relative_path.as_posix()} committed blob mismatch: "
            f"expected={expected_blob} actual={committed_blob}"
        )
    if blob != committed_blob:
        raise RuntimeActivationError(
            f"{relative_path.as_posix()} worktree bytes are not the committed blob"
        )
    return {"sha256": sha256, "git_commit": commit, "git_blob": blob}


def _require_runtime_authorizations(payload: dict[str, Any]) -> None:
    if payload.get("schema_version") != SCHEMA_VERSION:
        raise RuntimeActivationError(
            "preparation/read-only decision cannot authorize Factory runtime activation"
        )
    if payload.get("authority") != "OWNER" or payload.get("status") != "APPROVED":
        raise RuntimeActivationError("runtime decision lacks exact OWNER/APPROVED authority")
    authorizations = payload.get("authorizations")
    if not isinstance(authorizations, dict):
        raise RuntimeActivationError("runtime decision lacks authorizations")
    _require_exact_keys(
        authorizations,
        {
            "factory_on",
            "release_declared_restart_holds",
            "runtime_flag_upgrade_authorized",
        },
        label="authorizations",
    )
    if authorizations.get("factory_on") is not True:
        raise RuntimeActivationError("runtime decision does not authorize Factory_ON")
    if authorizations.get("release_declared_restart_holds") is not True:
        raise RuntimeActivationError(
            "runtime decision does not authorize its declared restart-hold plan"
        )
    if authorizations.get("runtime_flag_upgrade_authorized") is not False:
        raise RuntimeActivationError(
            "Factory_ON never upgrades OFF flags; runtime_flag_upgrade_authorized must be false"
        )


def _validate_runtime_activation_artifacts(
    *,
    repo_root: Path = REPO_ROOT,
    decision_relative_path: Path = DECISION_RELATIVE_PATH,
    digest_relative_path: Path = DIGEST_RELATIVE_PATH,
    factory_off_flag: Path | None = None,
    now_utc: dt.datetime | None = None,
    require_artifact_provenance: bool,
) -> dict[str, Any]:
    repo_root = Path(repo_root).resolve()
    decision_path = Path(decision_relative_path)
    digest_path = Path(digest_relative_path)
    if not decision_path.is_absolute():
        decision_path = repo_root / decision_path
    if not digest_path.is_absolute():
        digest_path = repo_root / digest_path
    if not decision_path.is_file() or not digest_path.is_file():
        raise RuntimeActivationError(
            "Factory runtime activation remains hard-blocked: canonical fresh OWNER "
            "runtime decision and SHA-256 sidecar do not exist"
        )
    try:
        decision_raw = decision_path.read_bytes()
        digest_text = digest_path.read_text(encoding="ascii")
    except (OSError, UnicodeError) as exc:
        raise RuntimeActivationError(f"runtime decision binding cannot be read: {exc}") from exc
    decision_sha256 = _sha256(decision_raw)
    expected_sidecar = f"{decision_sha256}  {decision_path.name}\n"
    if digest_text != expected_sidecar:
        raise RuntimeActivationError("runtime decision SHA-256 sidecar mismatch")
    payload = _load_json(decision_raw, label="runtime activation decision")
    _require_runtime_authorizations(payload)
    _require_exact_keys(
        payload,
        {
            "schema_version",
            "decision_id",
            "activation_nonce",
            "authority",
            "status",
            "authorized_at_utc",
            "expires_at_utc",
            "preparation_decision",
            "authorizations",
            "restart_holds",
            "worker_policy",
            "restore_intent",
            "source_bindings",
        },
        label="runtime decision",
    )
    decision_id = payload.get("decision_id")
    if not isinstance(decision_id, str) or not decision_id.strip():
        raise RuntimeActivationError("runtime decision_id must be non-empty")
    activation_nonce = payload.get("activation_nonce")
    if (
        not isinstance(activation_nonce, str)
        or re.fullmatch(r"[0-9a-f]{32}", activation_nonce) is None
    ):
        raise RuntimeActivationError("runtime activation_nonce must be 32 lowercase hex characters")
    authorized_at = _parse_utc(payload.get("authorized_at_utc"), label="authorized_at_utc")
    expires_at = _parse_utc(payload.get("expires_at_utc"), label="expires_at_utc")
    now = now_utc or dt.datetime.now(dt.UTC)
    if now.tzinfo is None:
        raise RuntimeActivationError("validator now_utc must be timezone-aware")
    now = now.astimezone(dt.UTC)
    if authorized_at > now + dt.timedelta(minutes=5):
        raise RuntimeActivationError("runtime decision authorization is future-dated")
    if expires_at <= authorized_at or now >= expires_at:
        raise RuntimeActivationError("runtime decision is expired or has an invalid window")
    if expires_at - authorized_at > dt.timedelta(hours=24):
        raise RuntimeActivationError("runtime decision authorization window exceeds 24 hours")

    preparation = payload.get("preparation_decision")
    if not isinstance(preparation, dict):
        raise RuntimeActivationError("preparation_decision binding is missing")
    expected_preparation = {
        "relative_path": PREPARATION_DECISION_RELATIVE_PATH.as_posix(),
        "sha256": PREPARATION_DECISION_SHA256,
        "git_commit": PREPARATION_DECISION_COMMIT,
        "git_blob": PREPARATION_DECISION_BLOB,
    }
    if preparation != expected_preparation:
        raise RuntimeActivationError("runtime decision preparation binding mismatch")
    prep_provenance = _verify_committed_file(
        repo_root,
        PREPARATION_DECISION_RELATIVE_PATH,
        expected_sha256=PREPARATION_DECISION_SHA256,
        expected_commit=PREPARATION_DECISION_COMMIT,
        expected_blob=PREPARATION_DECISION_BLOB,
    )
    prep_payload = _load_json(
        (repo_root / PREPARATION_DECISION_RELATIVE_PATH).read_bytes(),
        label="preparation decision",
    )
    prep_plan = _validated_restart_hold_plan(
        prep_payload, label="preparation decision"
    )
    if (
        prep_payload.get("restore_intent", {}).get("factory_on_authorized") is not False
        or prep_payload.get("restore_intent", {}).get("runtime_flag_upgrade_authorized")
        is not False
        or prep_payload.get("explicit_exclusions", {}).get("hold_release_now") is not False
    ):
        raise RuntimeActivationError("pinned preparation decision semantics changed")
    prep_restore = prep_payload.get("restore_intent")
    if not isinstance(prep_restore, dict):
        raise RuntimeActivationError("pinned preparation restore intent is missing")
    task_enabled_before = prep_restore.get("task_enabled_before")
    if not isinstance(task_enabled_before, dict) or len(task_enabled_before) != 21:
        raise RuntimeActivationError("pinned preparation exact 21-task map is missing")
    if any(
        not isinstance(task_name, str) or not isinstance(enabled, bool)
        for task_name, enabled in task_enabled_before.items()
    ):
        raise RuntimeActivationError("pinned preparation task map is not exact boolean state")
    task_map_bytes = json.dumps(
        task_enabled_before, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    task_map_sha256 = _sha256(task_map_bytes)

    restart_holds = payload.get("restart_holds")
    runtime_plan = _validated_restart_hold_plan(
        payload, label="runtime decision"
    )
    expected_restart_holds = {
        "authorized_release_count": len(prep_plan),
        "authorized_work_item_ids": prep_plan,
    }
    if (
        not isinstance(restart_holds, dict)
        or restart_holds != expected_restart_holds
        or runtime_plan != prep_plan
    ):
        raise RuntimeActivationError("runtime decision restart-hold set mismatch")
    worker_policy = payload.get("worker_policy")
    if not isinstance(worker_policy, dict) or worker_policy != {
        "disabled_terminals": [],
        "expected_worker_count": 10,
        "expected_terminals": list(WORKER_TERMINALS),
    }:
        raise RuntimeActivationError("runtime decision worker policy mismatch")

    restore_intent = payload.get("restore_intent")
    if not isinstance(restore_intent, dict):
        raise RuntimeActivationError("runtime decision restore_intent is missing")
    _require_exact_keys(
        restore_intent,
        {
            "factory_off_flag_sha256",
            "factory_off_schema_version",
            "factory_off_state",
            "task_enabled_before_sha256",
        },
        label="restore_intent",
    )
    expected_flag_sha = restore_intent.get("factory_off_flag_sha256")
    if not isinstance(expected_flag_sha, str) or SHA256_RE.fullmatch(expected_flag_sha) is None:
        raise RuntimeActivationError("restore_intent factory_off_flag_sha256 is invalid")
    if (
        restore_intent.get("factory_off_schema_version") != 2
        or restore_intent.get("factory_off_state") != "OFF"
        or restore_intent.get("task_enabled_before_sha256") != task_map_sha256
    ):
        raise RuntimeActivationError(
            "runtime decision requires the exact preparation-bound schema-v2 restore intent"
        )
    if factory_off_flag is not None:
        try:
            flag_raw = Path(factory_off_flag).read_bytes()
        except OSError as exc:
            raise RuntimeActivationError(f"bound FACTORY_OFF record cannot be read: {exc}") from exc
        if _sha256(flag_raw) != expected_flag_sha:
            raise RuntimeActivationError("bound FACTORY_OFF record SHA-256 mismatch")
        flag_payload = _load_json(
            flag_raw.removeprefix(b"\xef\xbb\xbf"),
            label="FACTORY_OFF record",
        )
        if (
            flag_payload.get("schema_version") != 2
            or flag_payload.get("state") != "OFF"
            or flag_payload.get("task_enabled_before") != task_enabled_before
        ):
            raise RuntimeActivationError(
                "bound FACTORY_OFF record does not contain the approved exact 21-task map"
            )

    source_bindings = payload.get("source_bindings")
    if not isinstance(source_bindings, dict):
        raise RuntimeActivationError("runtime decision source_bindings are missing")
    _require_exact_keys(
        source_bindings, set(SOURCE_BINDING_PATHS), label="source_bindings"
    )
    verified_sources: dict[str, dict[str, str]] = {}
    for label, relative_path in SOURCE_BINDING_PATHS.items():
        binding = source_bindings.get(label)
        if not isinstance(binding, dict):
            raise RuntimeActivationError(f"source_bindings.{label} is missing")
        expected_keys = {"relative_path", "sha256", "git_commit", "git_blob"}
        _require_exact_keys(binding, expected_keys, label=f"source_bindings.{label}")
        if binding.get("relative_path") != relative_path.as_posix():
            raise RuntimeActivationError(f"source_bindings.{label} path mismatch")
        for field, pattern in (("sha256", SHA256_RE), ("git_commit", GIT_OID_RE), ("git_blob", GIT_OID_RE)):
            if not isinstance(binding.get(field), str) or pattern.fullmatch(binding[field]) is None:
                raise RuntimeActivationError(f"source_bindings.{label}.{field} is invalid")
        verified_sources[label] = _verify_committed_file(
            repo_root,
            relative_path,
            expected_sha256=binding["sha256"],
            expected_commit=binding["git_commit"],
            expected_blob=binding["git_blob"],
        )

    result = {
        "authorized": True,
        "decision_id": decision_id,
        "activation_nonce": activation_nonce,
        "authorized_at_utc": payload["authorized_at_utc"],
        "expires_at_utc": payload["expires_at_utc"],
        "decision_sha256": decision_sha256,
        "factory_off_flag_sha256": expected_flag_sha,
        "task_enabled_before_sha256": task_map_sha256,
        "task_enabled_before": task_enabled_before,
        "preparation": prep_provenance,
        "source_bindings": verified_sources,
        "restart_hold_ids": prep_plan,
        "worker_terminals": list(WORKER_TERMINALS),
        "worker_policy_disabled_terminals": list(
            worker_policy["disabled_terminals"]
        ),
    }
    if require_artifact_provenance:
        decision_provenance = _verify_committed_file(
            repo_root, decision_relative_path, expected_sha256=decision_sha256
        )
        digest_provenance = _verify_committed_file(repo_root, digest_relative_path)
        result.update(
            {
                "decision_git_commit": decision_provenance["git_commit"],
                "decision_git_blob": decision_provenance["git_blob"],
                "digest_sha256": digest_provenance["sha256"],
            }
        )
    else:
        result.update(
            {
                "candidate_validated": True,
                "digest_sha256": _sha256(digest_text.encode("ascii")),
            }
        )
    return result


def validate_runtime_activation_decision(
    *,
    repo_root: Path = REPO_ROOT,
    decision_relative_path: Path = DECISION_RELATIVE_PATH,
    digest_relative_path: Path = DIGEST_RELATIVE_PATH,
    factory_off_flag: Path | None = None,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    """Validate canonical, committed runtime authority for production consumers."""

    return _validate_runtime_activation_artifacts(
        repo_root=repo_root,
        decision_relative_path=decision_relative_path,
        digest_relative_path=digest_relative_path,
        factory_off_flag=factory_off_flag,
        now_utc=now_utc,
        require_artifact_provenance=True,
    )


def validate_runtime_activation_candidate(
    *,
    repo_root: Path = REPO_ROOT,
    decision_path: Path,
    digest_path: Path,
    factory_off_flag: Path | None = None,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    """Validate a builder candidate before publication.

    Candidate artifacts cannot have commit provenance yet.  Every authorization,
    time, preparation, flag, task-map, and source-binding guard is still applied;
    only provenance of the two not-yet-published candidate files is deferred.
    Production callers must use :func:`validate_runtime_activation_decision`.
    """

    return _validate_runtime_activation_artifacts(
        repo_root=repo_root,
        decision_relative_path=decision_path,
        digest_relative_path=digest_path,
        factory_off_flag=factory_off_flag,
        now_utc=now_utc,
        require_artifact_provenance=False,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--decision", type=Path)
    parser.add_argument("--digest", type=Path)
    parser.add_argument("--factory-off-flag", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    repo_root = args.repo_root.resolve()
    decision_relative = (
        args.decision.resolve().relative_to(repo_root)
        if args.decision is not None
        else DECISION_RELATIVE_PATH
    )
    digest_relative = (
        args.digest.resolve().relative_to(repo_root)
        if args.digest is not None
        else DIGEST_RELATIVE_PATH
    )
    result = validate_runtime_activation_decision(
        repo_root=repo_root,
        decision_relative_path=decision_relative,
        digest_relative_path=digest_relative,
        factory_off_flag=args.factory_off_flag,
    )
    payload = json.dumps(result, sort_keys=True, separators=(",", ":"))
    print(f"{RUNTIME_ACTIVATION_RECORD_PREFIX}{payload}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
