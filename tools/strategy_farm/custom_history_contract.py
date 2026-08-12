#!/usr/bin/env python3
"""Fail-closed contracts for the Variant-A MT5 Custom-history migration.

This module contains no cutover operation.  It builds and validates the
content-addressed archive manifest, classifies mutable versus immutable files,
and exposes the small filesystem/ACL probes shared by the migration and worker
gate.  Callers decide whether a read-only audit or an OWNER-authorized mutation
is appropriate.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Sequence


MANIFEST_SCHEMA = "qm.custom-history-archive-manifest/v1"
OWNER_APPROVAL_SCHEMA = "qm.custom-history-owner-approval/v1"
OWNER_WINDOW_SCHEMA = "qm.custom-history-owner-window/v1"
ACTIVATION_SCHEMA = "qm.custom-history-isolation-activation/v1"
ARCHIVE_EXTENSIONS = frozenset({".hcc", ".tkc"})
DEFAULT_ARCHIVE_YEARS = tuple(range(2017, 2026))
DEFAULT_CURRENT_YEAR = 2026
DEFAULT_RUNNER_TERMINALS = tuple(f"T{number}" for number in range(1, 11))
_YEAR_STEM_RE = re.compile(r"^(?P<year>\d{4})(?:\d{2})?$")
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_GIT_OID_RE = re.compile(r"^[0-9a-f]{40}$")


class CustomHistoryContractError(ValueError):
    """A manifest, approval, path, or filesystem fact violates the contract."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_utc_timestamp(value: Any, *, field: str) -> datetime:
    candidate = str(value or "").strip()
    if candidate.endswith("Z"):
        candidate = candidate[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError as exc:
        raise CustomHistoryContractError(f"{field} must be an ISO-8601 timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise CustomHistoryContractError(f"{field} must include a UTC offset")
    return parsed.astimezone(timezone.utc)


def require_owner_window_open(
    approval: Mapping[str, Any], *, now: datetime | None = None
) -> None:
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    start = parse_utc_timestamp(approval.get("window_start_utc"), field="window_start_utc")
    end = parse_utc_timestamp(approval.get("window_end_utc"), field="window_end_utc")
    signed = parse_utc_timestamp(approval.get("signed_at_utc"), field="signed_at_utc")
    reviewed = parse_utc_timestamp(
        approval.get("claude_reviewed_at_utc"), field="claude_reviewed_at_utc"
    )
    if current < signed or current < reviewed:
        raise CustomHistoryContractError("OWNER/Claude authorization timestamp is in the future")
    if current < start or current > end:
        raise CustomHistoryContractError(
            f"OWNER window is not open: now={current.isoformat()} start={start.isoformat()} end={end.isoformat()}"
        )


def canonical_bytes(payload: Mapping[str, Any]) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path, *, chunk_size: int = 8 * 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        while True:
            chunk = stream.read(chunk_size)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def _manifest_body(manifest: Mapping[str, Any]) -> dict[str, Any]:
    return {
        key: value
        for key, value in manifest.items()
        if key not in {"manifest_sha256", "owner_approval"}
    }


def manifest_sha256(manifest: Mapping[str, Any]) -> str:
    """Hash immutable manifest content; the later OWNER approval binds this hash."""

    return sha256_bytes(canonical_bytes(_manifest_body(manifest)))


def self_hash(payload: Mapping[str, Any], field: str) -> str:
    return sha256_bytes(
        canonical_bytes({key: value for key, value in payload.items() if key != field})
    )


def normalize_relative_path(value: str | PurePosixPath) -> str:
    raw = str(value).replace("\\", "/")
    candidate = PurePosixPath(raw)
    if candidate.is_absolute() or not candidate.parts:
        raise CustomHistoryContractError(f"relative path required: {value!r}")
    if any(part in {"", ".", ".."} for part in candidate.parts):
        raise CustomHistoryContractError(f"unsafe relative path: {value!r}")
    normalized = candidate.as_posix()
    if normalized.startswith("/") or ":" in candidate.parts[0]:
        raise CustomHistoryContractError(f"unsafe relative path: {value!r}")
    return normalized


def history_year(relative_path: str | PurePosixPath) -> int | None:
    relative = PurePosixPath(normalize_relative_path(relative_path))
    if relative.suffix.casefold() not in ARCHIVE_EXTENSIONS:
        return None
    match = _YEAR_STEM_RE.fullmatch(relative.stem)
    return int(match.group("year")) if match else None


def classify_relative_path(
    relative_path: str | PurePosixPath,
    *,
    archive_years: Iterable[int] = DEFAULT_ARCHIVE_YEARS,
    current_year: int = DEFAULT_CURRENT_YEAR,
) -> dict[str, Any]:
    """Classify every non-archive file as private mutable, never by optimism."""

    relative = normalize_relative_path(relative_path)
    suffix = PurePosixPath(relative).suffix.casefold()
    year = history_year(relative)
    archive_set = {int(value) for value in archive_years}
    if suffix in ARCHIVE_EXTENSIONS and year in archive_set and year < current_year:
        file_class = "ARCHIVE_IMMUTABLE"
    elif suffix in ARCHIVE_EXTENSIONS and year == current_year:
        file_class = "CURRENT_YEAR_MUTABLE"
    else:
        file_class = "UNCLASSIFIED_MUTABLE"
    return {
        "relative_path": relative,
        "suffix": suffix,
        "year": year,
        "file_class": file_class,
    }


def file_identity(path: Path, *, follow_symlinks: bool = True) -> dict[str, Any]:
    stat = Path(path).stat(follow_symlinks=follow_symlinks)
    if int(stat.st_ino) <= 0:
        raise CustomHistoryContractError(f"filesystem did not expose a file ID: {path}")
    return {
        "file_id": f"{int(stat.st_dev):x}:{int(stat.st_ino):x}",
        "volume_id": f"{int(stat.st_dev):x}",
        "link_count": int(stat.st_nlink),
        "size": int(stat.st_size),
        "mtime_ns": int(stat.st_mtime_ns),
    }


def is_reparse_point(path: Path) -> bool:
    try:
        stat = Path(path).lstat()
    except OSError:
        return False
    attributes = int(getattr(stat, "st_file_attributes", 0))
    return bool(attributes & int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)))


def _archive_candidates(
    source_custom: Path,
    *,
    archive_years: Sequence[int],
    current_year: int,
) -> list[tuple[str, Path, int]]:
    source = Path(source_custom)
    candidates: list[tuple[str, Path, int]] = []
    for path in source.rglob("*"):
        if not path.is_file():
            continue
        relative = normalize_relative_path(path.relative_to(source).as_posix())
        classification = classify_relative_path(
            relative,
            archive_years=archive_years,
            current_year=current_year,
        )
        if classification["file_class"] == "ARCHIVE_IMMUTABLE":
            candidates.append((relative, path, int(classification["year"])))
    return sorted(candidates, key=lambda item: item[0].casefold())


def build_archive_manifest(
    source_custom: Path,
    *,
    archive_years: Sequence[int] = DEFAULT_ARCHIVE_YEARS,
    current_year: int = DEFAULT_CURRENT_YEAR,
    runner_identity: str,
    runner_terminals: Sequence[str] = DEFAULT_RUNNER_TERMINALS,
    created_at_utc: str | None = None,
    hash_content: bool = True,
) -> dict[str, Any]:
    source = Path(source_custom)
    if not source.is_dir():
        raise CustomHistoryContractError(f"source Custom directory missing: {source}")
    years = tuple(sorted({int(value) for value in archive_years}))
    if not years or years[-1] >= int(current_year):
        raise CustomHistoryContractError("archive years must be non-empty and precede current_year")
    identity = str(runner_identity).strip()
    if not identity:
        raise CustomHistoryContractError("runner_identity is required")
    terminals = tuple(sorted({str(value).upper() for value in runner_terminals}))
    if terminals != tuple(sorted(DEFAULT_RUNNER_TERMINALS)):
        raise CustomHistoryContractError("Variant A manifest must bind exactly T1-T10")

    files: list[dict[str, Any]] = []
    total_bytes = 0
    seen_casefold: set[str] = set()
    for relative, path, year in _archive_candidates(
        source,
        archive_years=years,
        current_year=current_year,
    ):
        folded = relative.casefold()
        if folded in seen_casefold:
            raise CustomHistoryContractError(f"case-insensitive archive path collision: {relative}")
        seen_casefold.add(folded)
        identity_row = file_identity(path)
        content_hash = sha256_file(path) if hash_content else None
        row = {
            "relative_path": relative,
            "year": year,
            "size": identity_row["size"],
            "sha256": content_hash,
            "file_id": identity_row["file_id"],
            "volume_id": identity_row["volume_id"],
            "link_count_at_build": identity_row["link_count"],
            "mtime_ns_at_build": identity_row["mtime_ns"],
        }
        files.append(row)
        total_bytes += int(row["size"])

    manifest: dict[str, Any] = {
        "schema_version": MANIFEST_SCHEMA,
        "created_at_utc": created_at_utc or utc_now(),
        "source_custom": str(source.absolute()),
        "source_resolved_identity": os.path.normcase(str(source.resolve(strict=True))),
        "archive_years": list(years),
        "current_year": int(current_year),
        "runner_identity": identity,
        "runner_terminals": list(terminals),
        "hash_mode": "SHA256_FULL" if hash_content else "METADATA_ONLY_DRY_RUN",
        "file_count": len(files),
        "total_bytes": total_bytes,
        "files": files,
        "owner_approval": None,
    }
    manifest["manifest_sha256"] = manifest_sha256(manifest)
    return manifest


def _validate_sha256(value: Any, *, field: str) -> str:
    candidate = str(value or "").strip().casefold()
    if _SHA256_RE.fullmatch(candidate) is None:
        raise CustomHistoryContractError(f"{field} must be a lowercase SHA-256")
    return candidate


def validate_owner_approval(
    approval: Mapping[str, Any],
    *,
    expected_manifest_sha256: str,
    expected_terminals: Sequence[str] = DEFAULT_RUNNER_TERMINALS,
) -> dict[str, Any]:
    required = {
        "schema_version",
        "authority",
        "signed_by",
        "signed_at_utc",
        "signature",
        "manifest_sha256",
        "decision_sha256",
        "window_id",
        "window_start_utc",
        "window_end_utc",
        "variant",
        "terminals",
        "rollback_authorized",
        "implementation_git_commit",
        "claude_review_task_id",
        "claude_review_verdict",
        "claude_reviewed_at_utc",
    }
    if set(approval) != required:
        raise CustomHistoryContractError("OWNER approval key set mismatch")
    if approval["schema_version"] != OWNER_APPROVAL_SCHEMA:
        raise CustomHistoryContractError("unsupported OWNER approval schema")
    if approval["authority"] != "OWNER" or not str(approval["signed_by"]).strip():
        raise CustomHistoryContractError("OWNER authority/signatory missing")
    if not str(approval["signature"]).strip():
        raise CustomHistoryContractError("OWNER signature is empty")
    if str(approval["variant"]).upper() != "A":
        raise CustomHistoryContractError("OWNER approval does not authorize Variant A")
    if approval["rollback_authorized"] is not True:
        raise CustomHistoryContractError("rollback authorization is required")
    if _GIT_OID_RE.fullmatch(str(approval["implementation_git_commit"]).casefold()) is None:
        raise CustomHistoryContractError("implementation_git_commit must be a 40-character Git OID")
    if str(approval["claude_review_verdict"]).upper() != "APPROVED":
        raise CustomHistoryContractError("Claude review APPROVED is required")
    if not str(approval["claude_review_task_id"]).strip() or not str(approval["claude_reviewed_at_utc"]).strip():
        raise CustomHistoryContractError("Claude review identity/timestamp is required")
    if _validate_sha256(approval["manifest_sha256"], field="manifest_sha256") != expected_manifest_sha256:
        raise CustomHistoryContractError("OWNER approval manifest hash mismatch")
    _validate_sha256(approval["decision_sha256"], field="decision_sha256")
    terminals = tuple(sorted({str(value).upper() for value in approval["terminals"]}))
    if terminals != tuple(sorted({str(value).upper() for value in expected_terminals})):
        raise CustomHistoryContractError("OWNER approval terminal set mismatch")
    if not str(approval["window_id"]).strip():
        raise CustomHistoryContractError("OWNER approval window_id is empty")
    signed_at = parse_utc_timestamp(approval["signed_at_utc"], field="signed_at_utc")
    reviewed_at = parse_utc_timestamp(
        approval["claude_reviewed_at_utc"], field="claude_reviewed_at_utc"
    )
    window_start = parse_utc_timestamp(
        approval["window_start_utc"], field="window_start_utc"
    )
    window_end = parse_utc_timestamp(
        approval["window_end_utc"], field="window_end_utc"
    )
    if window_start >= window_end:
        raise CustomHistoryContractError("OWNER window start must precede its end")
    if reviewed_at > signed_at:
        raise CustomHistoryContractError("Claude review must precede OWNER signature")
    if signed_at > window_end:
        raise CustomHistoryContractError("OWNER signature is later than the window end")
    return dict(approval)


def validate_manifest(
    manifest: Mapping[str, Any],
    *,
    require_owner_approval: bool = False,
    allow_metadata_only: bool = False,
) -> dict[str, Any]:
    required = {
        "schema_version",
        "created_at_utc",
        "source_custom",
        "source_resolved_identity",
        "archive_years",
        "current_year",
        "runner_identity",
        "runner_terminals",
        "hash_mode",
        "file_count",
        "total_bytes",
        "files",
        "manifest_sha256",
        "owner_approval",
    }
    if set(manifest) != required:
        raise CustomHistoryContractError("archive manifest key set mismatch")
    if manifest["schema_version"] != MANIFEST_SCHEMA:
        raise CustomHistoryContractError("unsupported archive manifest schema")
    expected_digest = manifest_sha256(manifest)
    actual_digest = _validate_sha256(manifest["manifest_sha256"], field="manifest_sha256")
    if actual_digest != expected_digest:
        raise CustomHistoryContractError("archive manifest content hash mismatch")
    if manifest["hash_mode"] not in {"SHA256_FULL", "METADATA_ONLY_DRY_RUN"}:
        raise CustomHistoryContractError("unsupported manifest hash_mode")
    if manifest["hash_mode"] != "SHA256_FULL" and not allow_metadata_only:
        raise CustomHistoryContractError("metadata-only manifest cannot authorize migration")
    if require_owner_approval and manifest["hash_mode"] != "SHA256_FULL":
        raise CustomHistoryContractError("metadata-only manifest cannot carry OWNER approval")
    years = tuple(int(value) for value in manifest["archive_years"])
    if tuple(sorted(set(years))) != years or not years:
        raise CustomHistoryContractError("archive_years must be sorted and unique")
    current_year = int(manifest["current_year"])
    if years[-1] >= current_year:
        raise CustomHistoryContractError("archive years must precede current_year")
    terminals = tuple(sorted({str(value).upper() for value in manifest["runner_terminals"]}))
    if terminals != tuple(sorted(DEFAULT_RUNNER_TERMINALS)):
        raise CustomHistoryContractError("manifest runner set must be exactly T1-T10")
    if not str(manifest["runner_identity"]).strip():
        raise CustomHistoryContractError("manifest runner_identity is empty")
    rows = manifest["files"]
    if not isinstance(rows, list) or int(manifest["file_count"]) != len(rows):
        raise CustomHistoryContractError("manifest file_count mismatch")
    seen: set[str] = set()
    total_bytes = 0
    normalized_rows: list[dict[str, Any]] = []
    row_keys = {
        "relative_path",
        "year",
        "size",
        "sha256",
        "file_id",
        "volume_id",
        "link_count_at_build",
        "mtime_ns_at_build",
    }
    for row in rows:
        if not isinstance(row, dict) or set(row) != row_keys:
            raise CustomHistoryContractError("manifest file row key set mismatch")
        relative = normalize_relative_path(row["relative_path"])
        folded = relative.casefold()
        if folded in seen:
            raise CustomHistoryContractError(f"duplicate manifest path: {relative}")
        seen.add(folded)
        classification = classify_relative_path(
            relative,
            archive_years=years,
            current_year=current_year,
        )
        if classification["file_class"] != "ARCHIVE_IMMUTABLE":
            raise CustomHistoryContractError(f"non-archive path in manifest: {relative}")
        if int(row["year"]) != classification["year"]:
            raise CustomHistoryContractError(f"manifest year mismatch: {relative}")
        size = int(row["size"])
        if size < 0 or int(row["link_count_at_build"]) < 1:
            raise CustomHistoryContractError(f"invalid file metadata: {relative}")
        if manifest["hash_mode"] == "SHA256_FULL":
            _validate_sha256(row["sha256"], field=f"files[{relative}].sha256")
        elif row["sha256"] is not None:
            raise CustomHistoryContractError(
                f"metadata-only manifest row unexpectedly carries SHA-256: {relative}"
            )
        if not str(row["file_id"]).strip() or not str(row["volume_id"]).strip():
            raise CustomHistoryContractError(f"file identity missing: {relative}")
        total_bytes += size
        normalized_rows.append(dict(row, relative_path=relative, size=size))
    if int(manifest["total_bytes"]) != total_bytes:
        raise CustomHistoryContractError("manifest total_bytes mismatch")
    if normalized_rows != sorted(normalized_rows, key=lambda row: row["relative_path"].casefold()):
        raise CustomHistoryContractError("manifest files are not canonically sorted")
    approval = manifest["owner_approval"]
    if require_owner_approval:
        if not isinstance(approval, dict):
            raise CustomHistoryContractError("OWNER approval is required")
        validate_owner_approval(
            approval,
            expected_manifest_sha256=actual_digest,
            expected_terminals=terminals,
        )
    elif approval is not None:
        if not isinstance(approval, dict):
            raise CustomHistoryContractError("owner_approval must be an object or null")
        validate_owner_approval(
            approval,
            expected_manifest_sha256=actual_digest,
            expected_terminals=terminals,
        )
    return dict(manifest)


def load_json_strict(path: Path) -> dict[str, Any]:
    def duplicate_guard(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise CustomHistoryContractError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    try:
        value = json.loads(
            Path(path).read_text(encoding="utf-8-sig"),
            object_pairs_hook=duplicate_guard,
            parse_constant=lambda value: (_ for _ in ()).throw(
                CustomHistoryContractError(f"non-finite JSON value: {value}")
            ),
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CustomHistoryContractError(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise CustomHistoryContractError(f"JSON root must be an object: {path}")
    return value


def load_manifest(path: Path, *, require_owner_approval: bool = False) -> dict[str, Any]:
    return validate_manifest(
        load_json_strict(Path(path)),
        require_owner_approval=require_owner_approval,
    )


def attach_owner_approval(
    manifest: Mapping[str, Any], approval: Mapping[str, Any]
) -> dict[str, Any]:
    validated = validate_manifest(manifest, require_owner_approval=False)
    if validated["owner_approval"] is not None:
        raise CustomHistoryContractError("manifest already carries an OWNER approval")
    validate_owner_approval(
        approval,
        expected_manifest_sha256=validated["manifest_sha256"],
        expected_terminals=validated["runner_terminals"],
    )
    result = dict(validated)
    result["owner_approval"] = dict(approval)
    validate_manifest(result, require_owner_approval=True)
    return result


def write_json_atomic(path: Path, payload: Mapping[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f".{target.name}.{os.getpid()}.tmp")
    data = json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    try:
        with temporary.open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def archive_acl_write_denied(path: Path, runner_identity: str) -> dict[str, Any]:
    """Read an ACL and require an explicit write/delete deny for the runner SID."""

    if sys.platform != "win32":
        return {
            "supported": False,
            "write_denied": False,
            "reason": "windows_acl_probe_required",
            "path": str(path),
        }
    escaped_path = str(Path(path)).replace("'", "''")
    escaped_identity = str(runner_identity).replace("'", "''")
    script = f"""
$ErrorActionPreference = 'Stop'
$identity = New-Object System.Security.Principal.NTAccount('{escaped_identity}')
$sid = $identity.Translate([System.Security.Principal.SecurityIdentifier])
$acl = Get-Acl -LiteralPath '{escaped_path}'
$rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
$required = [int][System.Security.AccessControl.FileSystemRights]::Write -bor [int][System.Security.AccessControl.FileSystemRights]::Delete -bor [int][System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor [int][System.Security.AccessControl.FileSystemRights]::TakeOwnership
$denied = $false
foreach ($rule in $rules) {{
  if ($rule.IdentityReference.Value -eq $sid.Value -and $rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {{
    if (([int]$rule.FileSystemRights -band $required) -eq $required) {{ $denied = $true }}
  }}
}}
[pscustomobject]@{{sid=$sid.Value;write_denied=$denied;sddl=$acl.Sddl}} | ConvertTo-Json -Compress
"""
    try:
        process = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return {
            "supported": True,
            "write_denied": False,
            "reason": "acl_probe_error",
            "error": repr(exc),
            "path": str(path),
        }
    if process.returncode != 0:
        return {
            "supported": True,
            "write_denied": False,
            "reason": "acl_probe_failed",
            "stderr": (process.stderr or "")[-2000:],
            "path": str(path),
        }
    try:
        payload = json.loads(process.stdout)
    except json.JSONDecodeError:
        return {
            "supported": True,
            "write_denied": False,
            "reason": "acl_probe_invalid_json",
            "stdout": (process.stdout or "")[-2000:],
            "path": str(path),
        }
    return {
        "supported": True,
        "write_denied": bool(payload.get("write_denied")),
        "runner_sid": payload.get("sid"),
        "sddl_sha256": sha256_bytes(str(payload.get("sddl") or "").encode("utf-8")),
        "path": str(path),
    }
