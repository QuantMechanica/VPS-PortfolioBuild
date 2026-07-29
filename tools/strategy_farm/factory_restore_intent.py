#!/usr/bin/env python3
"""Read-only validator for OWNER-authorized Factory-OFF restore intent.

The validator never reads Scheduled Task state and never writes any file.  It
binds a proposed legacy-v1 upgrade to the exact current FACTORY_OFF.flag bytes
and to the exact task-name contract supplied by Factory_OFF.ps1.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "qm.factory-restore-intent/v1"
DECISION = "RESTORE_EXACT_PRE_OFF_TASK_INTENT"
SCOPE = "QM_QUIESCENCE_TASKS_RESTORE_INTENT"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class RestoreIntentError(ValueError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise RestoreIntentError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_exact(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8-sig"),
            object_pairs_hook=_reject_duplicate_pairs,
        )
    except (OSError, UnicodeError, json.JSONDecodeError, RestoreIntentError) as exc:
        raise RestoreIntentError(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RestoreIntentError(f"JSON root must be an object: {path}")
    return value


def _require_exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    actual = set(value)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        raise RestoreIntentError(f"{label} key-set mismatch: missing={missing} extra={extra}")


def _require_nonplaceholder_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise RestoreIntentError(f"{label} must be a non-empty string")
    normalized = value.strip()
    if normalized.upper().startswith(("REPLACE_", "TODO", "TBD")):
        raise RestoreIntentError(f"{label} is still a template placeholder")
    return normalized


def _require_timestamp(value: Any, label: str) -> str:
    raw = _require_nonplaceholder_string(value, label)
    try:
        parsed = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError as exc:
        raise RestoreIntentError(f"{label} must be an ISO-8601 timestamp") from exc
    if parsed.tzinfo is None:
        raise RestoreIntentError(f"{label} must include a UTC offset")
    if parsed.utcoffset() != dt.timedelta(0):
        raise RestoreIntentError(f"{label} must be UTC (offset 00:00 or Z)")
    return raw


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left.resolve())) == os.path.normcase(str(right.resolve()))


def validate_restore_intent(
    manifest_path: Path,
    legacy_flag_path: Path,
    expected_tasks: list[str],
) -> dict[str, Any]:
    manifest_path = Path(manifest_path)
    legacy_flag_path = Path(legacy_flag_path)
    if not manifest_path.is_file():
        raise RestoreIntentError(f"restore-intent manifest missing: {manifest_path}")
    if not legacy_flag_path.is_file():
        raise RestoreIntentError(f"legacy FACTORY_OFF flag missing: {legacy_flag_path}")
    if not expected_tasks:
        raise RestoreIntentError("expected QM_QUIESCENCE_TASKS set is empty")
    if len(expected_tasks) != len(set(expected_tasks)):
        raise RestoreIntentError("expected QM_QUIESCENCE_TASKS contains duplicates")

    legacy = load_json_exact(legacy_flag_path)
    legacy_schema = legacy.get("schema_version")
    if legacy_schema not in (None, 1, "1"):
        raise RestoreIntentError(
            f"FACTORY_OFF flag is not legacy-v1: schema_version={legacy_schema!r}"
        )
    if "task_enabled_before" in legacy:
        raise RestoreIntentError("FACTORY_OFF flag already contains restore intent")

    manifest = load_json_exact(manifest_path)
    _require_exact_keys(
        manifest,
        {
            "schema_version",
            "manifest_id",
            "legacy_off_flag",
            "owner_authorization",
            "task_enabled_before",
        },
        "manifest",
    )
    if manifest["schema_version"] != SCHEMA_VERSION:
        raise RestoreIntentError(
            f"unsupported schema_version: {manifest['schema_version']!r}"
        )
    manifest_id = _require_nonplaceholder_string(manifest["manifest_id"], "manifest_id")

    flag_binding = manifest["legacy_off_flag"]
    if not isinstance(flag_binding, dict):
        raise RestoreIntentError("legacy_off_flag must be an object")
    _require_exact_keys(flag_binding, {"path", "sha256"}, "legacy_off_flag")
    bound_path = Path(_require_nonplaceholder_string(flag_binding["path"], "legacy_off_flag.path"))
    if not _same_path(bound_path, legacy_flag_path):
        raise RestoreIntentError(
            f"legacy_off_flag.path mismatch: expected={legacy_flag_path.resolve()} "
            f"actual={bound_path.resolve()}"
        )
    expected_flag_sha = _require_nonplaceholder_string(
        flag_binding["sha256"], "legacy_off_flag.sha256"
    ).lower()
    if not SHA256_RE.fullmatch(expected_flag_sha):
        raise RestoreIntentError("legacy_off_flag.sha256 must be 64 lowercase hex characters")
    actual_flag_sha = sha256_file(legacy_flag_path)
    if actual_flag_sha != expected_flag_sha:
        raise RestoreIntentError(
            f"legacy FACTORY_OFF SHA-256 mismatch: expected={expected_flag_sha} "
            f"actual={actual_flag_sha}"
        )

    authorization = manifest["owner_authorization"]
    if not isinstance(authorization, dict):
        raise RestoreIntentError("owner_authorization must be an object")
    _require_exact_keys(
        authorization,
        {"authority", "authorized_by", "authorized_at_utc", "decision", "decision_ref", "scope"},
        "owner_authorization",
    )
    if authorization["authority"] != "OWNER":
        raise RestoreIntentError("owner_authorization.authority must equal OWNER")
    if authorization["decision"] != DECISION:
        raise RestoreIntentError(f"owner_authorization.decision must equal {DECISION}")
    if authorization["scope"] != SCOPE:
        raise RestoreIntentError(f"owner_authorization.scope must equal {SCOPE}")
    authorized_by = _require_nonplaceholder_string(
        authorization["authorized_by"], "owner_authorization.authorized_by"
    )
    authorized_at = _require_timestamp(
        authorization["authorized_at_utc"], "owner_authorization.authorized_at_utc"
    )
    decision_ref = _require_nonplaceholder_string(
        authorization["decision_ref"], "owner_authorization.decision_ref"
    )

    task_state = manifest["task_enabled_before"]
    if not isinstance(task_state, dict):
        raise RestoreIntentError("task_enabled_before must be an object")
    expected_set = set(expected_tasks)
    _require_exact_keys(task_state, expected_set, "task_enabled_before")
    normalized_state: dict[str, bool] = {}
    for task in expected_tasks:
        value = task_state[task]
        if type(value) is not bool:
            raise RestoreIntentError(f"task_enabled_before.{task} must be boolean")
        normalized_state[task] = value

    return {
        "validated": True,
        "schema_version": SCHEMA_VERSION,
        "manifest_id": manifest_id,
        "manifest_path": str(manifest_path.resolve()),
        "manifest_sha256": sha256_file(manifest_path),
        "legacy_flag_path": str(legacy_flag_path.resolve()),
        "legacy_flag_sha256": actual_flag_sha,
        "owner_authorization": {
            "authority": "OWNER",
            "authorized_by": authorized_by,
            "authorized_at_utc": authorized_at,
            "decision": DECISION,
            "decision_ref": decision_ref,
            "scope": SCOPE,
        },
        "task_enabled_before": normalized_state,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    validate = sub.add_parser("validate")
    validate.add_argument("--manifest", type=Path, required=True)
    validate.add_argument("--legacy-flag", type=Path, required=True)
    validate.add_argument("--expected-task", action="append", default=[], required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = validate_restore_intent(
            args.manifest,
            args.legacy_flag,
            list(args.expected_task),
        )
    except RestoreIntentError as exc:
        print(json.dumps({"validated": False, "error": str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
