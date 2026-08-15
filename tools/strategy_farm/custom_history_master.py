#!/usr/bin/env python3
"""Standalone verified master archive tree and repair-first gate support (DL-085).

The master tree holds one private copy of every manifest-bound archive file,
OUTSIDE every MT5 terminal directory. No MT5 process ever opens a master
inode, so reads from the master cannot collide with running testers (the
proven error-32 discard vector, see
docs/ops/evidence/2026-08-14_claude_archive_eater_forensics.md).

Two consumers:

- copy-on-claim privatization copies FROM the master instead of from the
  cross-terminal shared family inode;
- the dispatch gate repairs manifest archive gaps by copying the verified
  master file into place (repair-first, DL-085) instead of fail-closing the
  fleet; containment remains for master loss or mismatch.

Every repair is sha256-verified against the owner-approved manifest before
the atomic move and appended as a receipt to
``<farm_root>/state/custom_history_repairs.jsonl``.
"""

from __future__ import annotations

import datetime as dt
import errno
import json
import os
from pathlib import Path
import shutil
from typing import Any, Mapping, Sequence
import uuid

try:
    from custom_history_contract import sha256_file
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm.custom_history_contract import sha256_file


MASTER_STATE_SCHEMA = "qm.custom-history-master-root/v1"
MASTER_STATE_RELATIVE = Path("state") / "custom_history_master_root.json"
REPAIRS_LOG_RELATIVE = Path("state") / "custom_history_repairs.jsonl"
REPAIRABLE_FINDING_CODES = frozenset(
    {"MANIFEST_ARCHIVE_FILE_MISSING", "TERMINAL_MANIFEST_INCOMPLETE"}
)


class CustomHistoryMasterError(RuntimeError):
    """The master tree cannot vouch for the requested archive content."""


# Windows resource-exhaustion I/O failures (mirrors the terminal_worker gate
# whitelist): ERROR_NOT_ENOUGH_MEMORY (8), ERROR_OUTOFMEMORY (14),
# ERROR_NO_SYSTEM_RESOURCES (1450), ERROR_COMMITMENT_LIMIT (1455).
_RESOURCE_EXHAUSTION_WINERRORS = frozenset({8, 14, 1450, 1455})


def is_transient_repair_io_error(exc: BaseException) -> bool:
    """Copy-environment artifacts of a repair, not master-vouching failures.

    A repair destination can be write-open in a running tester (sharing
    violation -> PermissionError on the atomic replace), race a concurrent
    repair (FileNotFoundError), or fail under RAM/handle pressure
    (MemoryError, resource-exhaustion OSErrors). None of these question the
    master's content; the next gate cycle retries. CustomHistoryMasterError
    anywhere in the chain (master missing / size / sha mismatch) is the
    genuine vouching-failure class and always wins: 2026-08-14 21:49Z a
    single such transient failure (1 of 4, concurrent with a successful
    sibling repair of the same file) reported master_repair PARTIAL and
    stopped the fleet although the master vouched throughout.
    """

    seen: set[int] = set()
    current: BaseException | None = exc
    while current is not None and id(current) not in seen:
        seen.add(id(current))
        if isinstance(current, CustomHistoryMasterError):
            return False
        current = current.__cause__ or current.__context__
    seen.clear()
    current = exc
    while current is not None and id(current) not in seen:
        seen.add(id(current))
        if isinstance(current, (PermissionError, FileNotFoundError, MemoryError)):
            return True
        if isinstance(current, OSError) and (
            getattr(current, "winerror", None) in _RESOURCE_EXHAUSTION_WINERRORS
            or current.errno == errno.ENOMEM
        ):
            return True
        current = current.__cause__ or current.__context__
    return False


def _utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def master_state_path(farm_root: Path | str) -> Path:
    return Path(farm_root) / MASTER_STATE_RELATIVE


def repairs_log_path(farm_root: Path | str) -> Path:
    return Path(farm_root) / REPAIRS_LOG_RELATIVE


def load_master_state(
    farm_root: Path | str, *, manifest: Mapping[str, Any]
) -> dict[str, Any]:
    """Load and bind the master-root record; fail closed on any mismatch."""

    path = master_state_path(farm_root)
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise CustomHistoryMasterError(f"master root record missing: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise CustomHistoryMasterError(f"master root record unreadable: {path}: {exc}") from exc
    if not isinstance(payload, dict) or payload.get("schema") != MASTER_STATE_SCHEMA:
        raise CustomHistoryMasterError(f"master root record has invalid schema: {path}")
    recorded = str(payload.get("manifest_sha256") or "")
    expected = str(manifest.get("manifest_sha256") or "")
    if not recorded or recorded != expected:
        raise CustomHistoryMasterError(
            "master root record is bound to a different manifest "
            f"(recorded {recorded[:12]}…, expected {expected[:12]}…)"
        )
    master_root = Path(str(payload.get("master_root") or ""))
    if not master_root.is_dir():
        raise CustomHistoryMasterError(f"master root directory missing: {master_root}")
    return {"master_root": master_root, "record": payload}


def master_file_path(master_root: Path | str, relative_path: str) -> Path:
    parts = [part for part in str(relative_path).split("/") if part not in ("", ".", "..")]
    if not parts:
        raise CustomHistoryMasterError(f"invalid relative path: {relative_path!r}")
    return Path(master_root).joinpath(*parts)


def copy_verified_master_file(
    *,
    master_root: Path | str,
    manifest_row: Mapping[str, Any],
    destination: Path,
) -> dict[str, Any]:
    """Copy one master file to ``destination`` (atomic), sha-verified twice.

    The temp copy is hashed against the manifest BEFORE the atomic replace, so
    a torn or corrupted master can never reach a terminal tree. Returns the
    verification facts for the caller's receipt.
    """

    relative = str(manifest_row["relative_path"])
    expected_sha = str(manifest_row["sha256"]).casefold()
    expected_size = int(manifest_row["size"])
    source = master_file_path(master_root, relative)
    if not source.is_file():
        raise CustomHistoryMasterError(f"master file missing: {source}")
    if int(source.stat().st_size) != expected_size:
        raise CustomHistoryMasterError(f"master file size mismatch: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.parent / (
        f".{destination.name}.master-repair.{os.getpid()}.{uuid.uuid4().hex}.tmp"
    )
    try:
        shutil.copyfile(source, temporary)
        digest = sha256_file(temporary)
        if digest != expected_sha:
            raise CustomHistoryMasterError(
                f"master content SHA-256 mismatch for {relative}: {digest}"
            )
        os.replace(temporary, destination)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
    return {
        "relative_path": relative,
        "sha256": expected_sha,
        "size": expected_size,
        "source": str(source),
        "destination": str(destination),
    }


def repair_missing_archives(
    *,
    farm_root: Path | str,
    mt5_root: Path | str,
    manifest: Mapping[str, Any],
    findings: Sequence[Mapping[str, Any]],
    repaired_by: str,
) -> dict[str, Any]:
    """Repair manifest archive gaps from the verified master (DL-085).

    Only findings whose code is in ``REPAIRABLE_FINDING_CODES`` are eligible;
    any other finding makes the whole call refuse (the caller must stay
    fail-closed). Each successful repair appends a JSONL receipt. Failures
    (master missing / mismatched) are returned so the caller fail-closes.
    """

    for finding in findings:
        if str(finding.get("code")) not in REPAIRABLE_FINDING_CODES:
            raise CustomHistoryMasterError(
                f"finding is not repairable: {finding.get('code')!r}"
            )
    master = load_master_state(farm_root, manifest=manifest)
    rows_by_path = {
        str(row["relative_path"]): row for row in manifest["files"]
    }
    repaired: list[dict[str, Any]] = []
    already_present: list[dict[str, Any]] = []
    failed: list[dict[str, Any]] = []
    log_path = repairs_log_path(farm_root)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    seen: set[tuple[str, str]] = set()
    for finding in findings:
        terminal = str(finding.get("terminal") or "").strip().upper()
        relative = str(finding.get("relative_path") or "")
        key = (terminal, relative)
        if key in seen:
            continue
        seen.add(key)
        row = rows_by_path.get(relative)
        record: dict[str, Any] = {
            "schema": "qm.custom-history-repair/v1",
            "repaired_at_utc": _utc_now(),
            "terminal": terminal,
            "relative_path": relative,
            "finding_code": str(finding.get("code")),
            "repaired_by": repaired_by,
        }
        if row is None or not terminal:
            record["result"] = "FAILED_NOT_IN_MANIFEST"
            record["transient_io"] = False
            failed.append(record)
            continue
        destination = (
            Path(mt5_root) / terminal / "Bases" / "Custom"
        ).joinpath(*relative.split("/"))
        try:
            if destination.is_file() and (
                int(destination.stat().st_size) == int(row["size"])
                and sha256_file(destination) == str(row["sha256"]).casefold()
            ):
                # Concurrent repair by another worker; nothing to do.
                record["result"] = "ALREADY_PRESENT_VERIFIED"
                already_present.append(record)
                continue
            facts = copy_verified_master_file(
                master_root=master["master_root"],
                manifest_row=row,
                destination=destination,
            )
        except (CustomHistoryMasterError, OSError) as exc:
            record["result"] = "FAILED"
            record["error"] = repr(exc)
            record["exception_type"] = type(exc).__name__
            record["transient_io"] = is_transient_repair_io_error(exc)
            failed.append(record)
            continue
        record["result"] = "REPAIRED_VERIFIED"
        record.update({"sha256": facts["sha256"], "size": facts["size"]})
        repaired.append(record)
        with open(log_path, "a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")
    return {
        "repaired": repaired,
        "already_present": already_present,
        "failed": failed,
        "receipts_path": str(log_path),
    }


def count_recent_repairs(farm_root: Path | str, *, hours: float = 24.0) -> int:
    """Count organic worker-gate repair receipts younger than ``hours``.

    Health telemetry for the archive-loss rate. Only ``worker_gate:*``
    receipts count: administrative bulk restores (e.g.
    ``claude_dl085_mass_restore_20260814``, 49 receipts) sit in the same
    ledger and inflated the 24h window to 114 while the organic loss rate was
    ~3-13/day (2026-08-15 forensics).
    """

    path = repairs_log_path(farm_root)
    if not path.is_file():
        return 0
    threshold = dt.datetime.now(dt.UTC) - dt.timedelta(hours=hours)
    count = 0
    try:
        with open(path, "r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                    if not str(record.get("repaired_by") or "").startswith("worker_gate:"):
                        continue
                    stamp = str(record.get("repaired_at_utc") or "")
                    when = dt.datetime.fromisoformat(stamp)
                except (json.JSONDecodeError, ValueError):
                    continue
                if when.tzinfo is None:
                    when = when.replace(tzinfo=dt.UTC)
                if when >= threshold:
                    count += 1
    except OSError:
        return 0
    return count
