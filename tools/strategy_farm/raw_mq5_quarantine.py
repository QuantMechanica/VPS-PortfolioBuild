#!/usr/bin/env python3
"""Fail closed against direct compile/promotion of quarantined raw MQ5 files."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path, PureWindowsPath
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
LEDGER_REL = Path("framework") / "registry" / "raw_mq5_source_ledger.csv"
REQUIRED_COLUMNS = {
    "quarantine_id",
    "farm_source_id",
    "source_basename",
    "source_locator",
    "locator_status",
    "sha256",
    "intake_state",
    "deployment_policy",
    "required_reentry",
    "registered_at",
    "registered_by",
    "router_task_id",
}
RAW_STATE = "RAW_UNTRUSTED"
DEPLOYMENT_POLICY = "DO_NOT_DEPLOY"
REENTRY_CONTRACT = "NEW_CARD_V5_REIMPLEMENT_FULL_GATE_CHAIN"
KNOWN_PURPOSES = {"compile", "promotion"}


class QuarantineConfigurationError(RuntimeError):
    pass


@dataclass(frozen=True)
class QuarantineEntry:
    quarantine_id: str
    farm_source_id: str
    source_basename: str
    source_locator: str
    locator_status: str
    sha256: str
    intake_state: str
    deployment_policy: str
    required_reentry: str
    registered_at: str
    registered_by: str
    router_task_id: str


def _is_sha256_or_unavailable(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-f]{64}", value.lower())) or value.startswith(
        "UNAVAILABLE_"
    )


def load_ledger(
    repo_root: Path = REPO_ROOT,
    ledger_path: Path | None = None,
) -> list[QuarantineEntry]:
    path = (ledger_path or (repo_root / LEDGER_REL)).resolve()
    if not path.is_file():
        raise QuarantineConfigurationError(f"quarantine ledger missing: {path}")
    entries: list[QuarantineEntry] = []
    ids: set[str] = set()
    basenames: set[str] = set()
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            missing = sorted(REQUIRED_COLUMNS - set(reader.fieldnames or []))
            if missing:
                raise QuarantineConfigurationError(
                    f"quarantine ledger missing columns {','.join(missing)}: {path}"
                )
            for row in reader:
                values = {key: str(row.get(key) or "").strip() for key in REQUIRED_COLUMNS}
                empty = sorted(key for key, value in values.items() if not value)
                if empty:
                    raise QuarantineConfigurationError(
                        f"quarantine ledger line {reader.line_num} has empty "
                        f"columns {','.join(empty)}"
                    )
                basename = values["source_basename"]
                if (
                    PureWindowsPath(basename).name != basename
                    or Path(basename).suffix.casefold() != ".mq5"
                ):
                    raise QuarantineConfigurationError(
                        f"quarantine ledger line {reader.line_num} has invalid MQ5 basename"
                    )
                if values["intake_state"] != RAW_STATE:
                    raise QuarantineConfigurationError(
                        f"quarantine ledger line {reader.line_num} must be {RAW_STATE}"
                    )
                if values["deployment_policy"] != DEPLOYMENT_POLICY:
                    raise QuarantineConfigurationError(
                        f"quarantine ledger line {reader.line_num} must be {DEPLOYMENT_POLICY}"
                    )
                if values["required_reentry"] != REENTRY_CONTRACT:
                    raise QuarantineConfigurationError(
                        f"quarantine ledger line {reader.line_num} has invalid re-entry contract"
                    )
                if not _is_sha256_or_unavailable(values["sha256"]):
                    raise QuarantineConfigurationError(
                        f"quarantine ledger line {reader.line_num} has invalid sha256 state"
                    )
                folded_id = values["quarantine_id"].casefold()
                folded_basename = basename.casefold()
                if folded_id in ids or folded_basename in basenames:
                    raise QuarantineConfigurationError(
                        f"quarantine ledger line {reader.line_num} duplicates identity/basename"
                    )
                ids.add(folded_id)
                basenames.add(folded_basename)
                entries.append(QuarantineEntry(**values))
    except (OSError, UnicodeError, csv.Error) as exc:
        raise QuarantineConfigurationError(f"cannot parse quarantine ledger {path}: {exc}") from exc
    if not entries:
        raise QuarantineConfigurationError(f"quarantine ledger is empty: {path}")
    return entries


def _drive_letter(raw_path: str) -> str | None:
    match = re.match(r"(?i)^(?:file:/+)?([a-z]):(?:[\\/]|$)", raw_path.strip())
    return match.group(1).upper() if match else None


def _basename(raw_path: str) -> str:
    return PureWindowsPath(raw_path.strip().replace("/", "\\")).name


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_under(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def check_source_path(
    source_path: str | Path,
    *,
    purpose: str,
    repo_root: Path = REPO_ROOT,
    ledger_path: Path | None = None,
    enforce_canonical: bool = True,
) -> dict[str, Any]:
    """Return a machine-readable allow/refuse decision for one MQ5 source."""
    raw_path = str(source_path or "").strip()
    if purpose not in KNOWN_PURPOSES:
        return {
            "allowed": False,
            "code": "RAW_MQ5_QUARANTINE_PURPOSE_INVALID",
            "reason": f"unknown purpose: {purpose}",
            "source_path": raw_path,
        }
    try:
        entries = load_ledger(repo_root, ledger_path)
    except QuarantineConfigurationError as exc:
        return {
            "allowed": False,
            "code": "RAW_MQ5_QUARANTINE_CONFIG_INVALID",
            "reason": str(exc),
            "source_path": raw_path,
            "purpose": purpose,
        }
    base = _basename(raw_path)
    common = {
        "source_path": raw_path,
        "source_basename": base,
        "purpose": purpose,
        "ledger_entries": len(entries),
        "canonical_path_enforced": enforce_canonical,
    }
    if not raw_path:
        return {
            "allowed": False,
            "code": "RAW_MQ5_SOURCE_PATH_MISSING",
            "reason": "MQ5 source path is required",
            **common,
        }
    if _drive_letter(raw_path) == "G":
        return {
            "allowed": False,
            "code": "RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED",
            "reason": (
                "direct compile/promotion from G: is forbidden; intake may re-enter only "
                "through a new Strategy Card, V5 reimplementation, and the full gate chain"
            ),
            **common,
        }

    by_basename = {entry.source_basename.casefold(): entry for entry in entries}
    matching_name = by_basename.get(base.casefold())
    if matching_name is not None:
        return {
            "allowed": False,
            "code": "RAW_MQ5_QUARANTINED_BASENAME_REFUSED",
            "reason": (
                f"{base} is registered {RAW_STATE}/{DEPLOYMENT_POLICY}; byte/source "
                "promotion is forbidden"
            ),
            "quarantine_entry": asdict(matching_name),
            **common,
        }

    candidate = Path(raw_path).resolve(strict=False)
    root = repo_root.resolve()
    allowed_roots = [root / "framework" / "EAs"]
    if purpose == "compile":
        allowed_roots.extend(
            [root / "framework" / "templates", root / "framework" / "tests"]
        )
    if enforce_canonical and not any(
        _is_under(candidate, allowed.resolve()) for allowed in allowed_roots
    ):
        return {
            "allowed": False,
            "code": "RAW_MQ5_NONCANONICAL_PATH_REFUSED",
            "reason": (
                f"{purpose} source must remain inside the canonical governed "
                f"{'compile roots' if purpose == 'compile' else 'framework/EAs root'}"
            ),
            "resolved_path": str(candidate),
            "allowed_roots": [str(path.resolve()) for path in allowed_roots],
            **common,
        }

    known_hashes = {
        entry.sha256.lower(): entry
        for entry in entries
        if re.fullmatch(r"[0-9a-f]{64}", entry.sha256.lower())
    }
    if candidate.is_file() and known_hashes:
        digest = _sha256_file(candidate)
        matching_hash = known_hashes.get(digest)
        if matching_hash is not None:
            return {
                "allowed": False,
                "code": "RAW_MQ5_QUARANTINED_HASH_REFUSED",
                "reason": "source bytes match a quarantined raw MQ5",
                "source_sha256": digest,
                "quarantine_entry": asdict(matching_hash),
                **common,
            }

    return {
        "allowed": True,
        "code": "RAW_MQ5_SOURCE_ALLOWED",
        "reason": "source path is canonical and does not match the quarantine ledger",
        "resolved_path": str(candidate),
        **common,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check"])
    parser.add_argument("--source-path", required=True)
    parser.add_argument("--purpose", required=True, choices=sorted(KNOWN_PURPOSES))
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--ledger", type=Path)
    args = parser.parse_args(argv)
    result = check_source_path(
        args.source_path,
        purpose=args.purpose,
        repo_root=args.repo_root,
        ledger_path=args.ledger,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["allowed"]:
        return 0
    return 2 if result["code"] == "RAW_MQ5_QUARANTINE_CONFIG_INVALID" else 3


if __name__ == "__main__":
    raise SystemExit(main())
