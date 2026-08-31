"""Execute the sealed OWNER backup-retention phase-2 manifest safely.

Authority: OWNER-DEC-BACKUP-RETENTION-20260830.

The phase-1 CSV is intentionally aggregate evidence.  This executor expands
the sealed aggregate rows into exact current paths and applies only paths that
remain classifiable, pre-date the seal, fit inside the sealed row's count/byte
bounds, and pass an immediate identity/lock check.  Drift is retained.

Deletion is always a same-volume atomic move into a run-specific quarantine,
verification in quarantine, and only then an individual unlink.  Compression
uses the NTFS compression control on an exclusive file handle.  Exact-path
batch inventories are written as deterministic gzip JSONL plus JSON receipts.

The default is a read-only plan.  ``--apply`` is required for mutation.
"""
from __future__ import annotations

import argparse
import csv
import ctypes
import datetime as dt
import gzip
import hashlib
import json
import os
import re
import shutil
import sqlite3
import sys
import time
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator

import build_backup_retention_manifest as phase1


DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_REPORTS = Path("D:/QM/reports")
DEFAULT_LOGS = Path("D:/QM/strategy_farm/logs")
DEFAULT_RELOCATED = Path("C:/QM/backups_relocated")
DEFAULT_MANIFEST = Path(
    "C:/QM/repo/docs/ops/evidence/"
    "2026-08-31_b327c0fe_backup_retention_phase1_manifest.csv"
)
DEFAULT_MANIFEST_MD = DEFAULT_MANIFEST.with_suffix(".md")
EXPECTED_MANIFEST_SHA256 = "0c3385c1bc0d9e5bc4a059eefcedeb5fffd666796223b366c6bc4a41b7b5c032"

ACTION_DISPOSITIONS = {
    "DELETE_DB_ROTATION",
    "DELETE_LOG",
    "DELETE_NONRETAINED",
    "COMPRESS_KEEP_COMPLETE_CHAIN",
    "COMPRESS_KEEP_Q02_Q04",
}
DELETE_DISPOSITIONS = {"DELETE_DB_ROTATION", "DELETE_LOG", "DELETE_NONRETAINED"}
COMPRESS_DISPOSITIONS = {
    "COMPRESS_KEEP_COMPLETE_CHAIN",
    "COMPRESS_KEEP_Q02_Q04",
}
FORBIDDEN_NAMES = {"custom_master", "t_live"}
REPORT_FORBIDDEN_NAMES = FORBIDDEN_NAMES | {"state"}
FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400
FILE_ATTRIBUTE_COMPRESSED = 0x00000800


GroupKey = tuple[str, str, str, str, str, str, str]


@dataclass(frozen=True)
class SealedRow:
    key: GroupKey
    file_count: int
    bytes: int


@dataclass(frozen=True)
class FileRecord:
    scope: str
    root: Path
    path: Path
    relative: str
    disposition: str
    group_key: GroupKey
    size: int
    mtime_ns: int
    inode: int

    def inventory_entry(self) -> dict[str, object]:
        return {
            "scope": self.scope,
            "source": str(self.path),
            "relative": self.relative,
            "disposition": self.disposition,
            "size": self.size,
            "mtime_ns": self.mtime_ns,
            "inode": self.inode,
        }


@dataclass
class ScanResult:
    candidates: list[FileRecord]
    holds: Counter[str]
    hold_bytes: Counter[str]
    current_groups: dict[GroupKey, tuple[int, int]]
    preseal_action_groups: dict[GroupKey, tuple[int, int]]
    drift_rows: list[dict[str, object]]
    files_seen: int
    bytes_seen: int


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _parse_utc(value: str) -> dt.datetime:
    parsed = dt.datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def _seal_time(markdown: Path) -> dt.datetime:
    text = markdown.read_text(encoding="utf-8")
    match = re.search(r"Generated UTC:\s*`([^`]+)`", text)
    if not match:
        raise ValueError(f"cannot read seal timestamp from {markdown}")
    return _parse_utc(match.group(1))


def _group_key(scope: str, classification: phase1.Classification) -> GroupKey:
    return (
        scope,
        classification.ea_id or "UNRESOLVED",
        classification.symbol or "UNRESOLVED",
        classification.phase or "UNRESOLVED",
        classification.pair_class,
        classification.disposition,
        classification.reason,
    )


def _csv_key(row: dict[str, str]) -> GroupKey:
    return (
        row["scope"],
        row["ea_id"],
        row["symbol"],
        row["phase"],
        row["pair_class"],
        row["disposition"],
        row["reason"],
    )


def load_sealed_rows(manifest: Path, expected_sha256: str) -> dict[GroupKey, SealedRow]:
    actual = _sha256(manifest)
    if actual.lower() != expected_sha256.lower():
        raise ValueError(
            f"manifest SHA-256 mismatch: expected={expected_sha256.lower()} actual={actual.lower()}"
        )
    rows: dict[GroupKey, SealedRow] = {}
    with manifest.open("r", encoding="utf-8", newline="") as fh:
        for raw in csv.DictReader(fh):
            key = _csv_key(raw)
            if key in rows:
                raise ValueError(f"duplicate sealed aggregate key: {key!r}")
            rows[key] = SealedRow(key, int(raw["file_count"]), int(raw["bytes"]))
    if not rows:
        raise ValueError("sealed manifest is empty")
    return rows


def _stat_identity(path: Path) -> tuple[int, int, int, int]:
    stat = path.stat()
    attributes = int(getattr(stat, "st_file_attributes", 0))
    return int(stat.st_size), int(stat.st_mtime_ns), int(stat.st_ino), attributes


def _safe_relative(path: Path, root: Path, scope: str) -> str:
    try:
        relative = path.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"path escaped source root: {path} not under {root}") from exc
    lowered = {part.lower() for part in relative.parts}
    forbidden = REPORT_FORBIDDEN_NAMES if scope == "D_REPORTS" else FORBIDDEN_NAMES
    if lowered & forbidden:
        raise ValueError(f"forbidden path component in {path}")
    # The exact legacy component ``retention_quarantine`` was deliberately
    # inventoried by phase 1.  Run-specific phase-2 quarantine roots carry a
    # suffix and must never be consumed by a retry/resume scan.
    if any(
        part.lower().startswith("retention_quarantine_")
        for part in relative.parts
    ):
        raise ValueError(f"existing quarantine path is never re-consumed: {path}")
    _size, _mtime, _inode, attributes = _stat_identity(path)
    if attributes & FILE_ATTRIBUTE_REPARSE_POINT:
        raise ValueError(f"reparse-point file is never acted on: {path}")
    return relative.as_posix()


def _iter_current(
    snapshot: phase1.Snapshot,
    reports_root: Path,
    logs_root: Path,
    relocated_root: Path,
    now: dt.datetime,
    notes: Counter[str],
) -> Iterator[tuple[str, Path, Path, phase1.Classification]]:
    for path, skip_reason in phase1._iter_files(reports_root, REPORT_FORBIDDEN_NAMES):
        if skip_reason:
            notes[f"scan_skip:{skip_reason}"] += 1
            continue
        yield "D_REPORTS", reports_root, path, phase1.classify_report(path, "D_REPORTS", snapshot)

    for path, skip_reason in phase1._iter_files(logs_root, FORBIDDEN_NAMES):
        if skip_reason:
            notes[f"scan_skip:{skip_reason}"] += 1
            continue
        classification = phase1.Classification(
            "", "", "", "LOG_ROOT", "DELETE_LOG",
            "OWNER doctrine: dedicated farm logs need not be kept",
        )
        yield "D_FARM_LOGS", logs_root, path, classification

    relocated_entries = list(phase1._iter_files(relocated_root, FORBIDDEN_NAMES))
    backup_files: list[Path] = []
    for path, skip_reason in relocated_entries:
        if skip_reason:
            continue
        lower_parts = {part.lower() for part in path.parts}
        if any(part.startswith("farm_state_backups_") for part in lower_parts) and path.suffix.lower() in {".sqlite", ".db"}:
            try:
                path.stat()
            except OSError:
                continue
            backup_files.append(path)
    backup_files.sort(key=lambda item: item.stat().st_mtime_ns, reverse=True)
    backup_set = set(backup_files)
    newest = set(backup_files[:10])
    cutoff = now - dt.timedelta(days=14)

    for path, skip_reason in relocated_entries:
        if skip_reason:
            notes[f"scan_skip:{skip_reason}"] += 1
            continue
        lower_parts = {part.lower() for part in path.parts}
        try:
            stat = path.stat()
        except OSError:
            notes["scan_skip:stat_failed"] += 1
            continue
        if path in backup_set:
            modified = dt.datetime.fromtimestamp(stat.st_mtime, dt.UTC)
            keep = path in newest or modified >= cutoff
            classification = phase1.Classification(
                "", "", "", "DB_BACKUP",
                "KEEP_DB_ROTATION" if keep else "DELETE_DB_ROTATION",
                "newest 10 or modified within 14 days"
                if keep else "older than 14 days and outside newest 10; phase-2 quick_check required",
            )
        elif any("log" in part for part in lower_parts) and not any("card" in part for part in lower_parts):
            classification = phase1.Classification(
                "", "", "", "LOG_ARCHIVE", "DELETE_LOG",
                "OWNER doctrine: relocated logs need not be kept",
            )
        elif "retention_quarantine" in lower_parts:
            classification = phase1.classify_report(path, "C_RELOCATED_QUARANTINE", snapshot)
        else:
            classification = phase1.Classification(
                "", "", "", "OUT_OF_SCOPE", "KEEP_OUT_OF_SCOPE",
                "not a report, log, or farm-state backup",
            )
        yield "C_RELOCATED", relocated_root, path, classification


def build_plan(
    sealed: dict[GroupKey, SealedRow],
    seal_time: dt.datetime,
    snapshot: phase1.Snapshot,
    reports_root: Path,
    logs_root: Path,
    relocated_root: Path,
    now: dt.datetime,
) -> ScanResult:
    holds: Counter[str] = Counter()
    hold_bytes: Counter[str] = Counter()
    current_counts: dict[GroupKey, list[int]] = defaultdict(lambda: [0, 0])
    preseal_counts: dict[GroupKey, list[int]] = defaultdict(lambda: [0, 0])
    candidates_by_key: dict[GroupKey, list[FileRecord]] = defaultdict(list)
    files_seen = 0
    bytes_seen = 0
    seal_ns = int(seal_time.timestamp() * 1_000_000_000)

    for scope, root, path, classification in _iter_current(
        snapshot, reports_root, logs_root, relocated_root, now, holds
    ):
        files_seen += 1
        try:
            size, mtime_ns, inode, _attributes = _stat_identity(path)
        except OSError:
            holds["stat_failed"] += 1
            continue
        bytes_seen += size
        key = _group_key(scope, classification)
        current_counts[key][0] += 1
        current_counts[key][1] += size
        if classification.disposition not in ACTION_DISPOSITIONS:
            continue
        sealed_row = sealed.get(key)
        if sealed_row is None:
            holds["action_group_not_in_seal"] += 1
            hold_bytes["action_group_not_in_seal"] += size
            continue
        if mtime_ns > seal_ns:
            holds["post_seal_new_or_changed"] += 1
            hold_bytes["post_seal_new_or_changed"] += size
            continue
        try:
            relative = _safe_relative(path, root, scope)
        except (OSError, ValueError):
            holds["unsafe_or_unclassifiable_path"] += 1
            hold_bytes["unsafe_or_unclassifiable_path"] += size
            continue
        preseal_counts[key][0] += 1
        preseal_counts[key][1] += size
        candidates_by_key[key].append(
            FileRecord(scope, root, path, relative, classification.disposition, key, size, mtime_ns, inode)
        )

    candidates: list[FileRecord] = []
    for key, records in candidates_by_key.items():
        sealed_row = sealed[key]
        count, size = preseal_counts[key]
        if count > sealed_row.file_count or size > sealed_row.bytes:
            holds["preseal_aggregate_exceeds_seal"] += count
            hold_bytes["preseal_aggregate_exceeds_seal"] += size
            continue
        candidates.extend(records)

    current_groups = {key: (value[0], value[1]) for key, value in current_counts.items()}
    preseal_action_groups = {key: (value[0], value[1]) for key, value in preseal_counts.items()}
    drift_rows: list[dict[str, object]] = []
    for key, row in sealed.items():
        if key[5] not in ACTION_DISPOSITIONS:
            continue
        current = current_groups.get(key, (0, 0))
        preseal = preseal_action_groups.get(key, (0, 0))
        if current != (row.file_count, row.bytes) or preseal != (row.file_count, row.bytes):
            drift_rows.append({
                "scope": key[0],
                "ea_id": key[1],
                "symbol": key[2],
                "phase": key[3],
                "pair_class": key[4],
                "disposition": key[5],
                "reason": key[6],
                "sealed_file_count": row.file_count,
                "sealed_bytes": row.bytes,
                "current_file_count": current[0],
                "current_bytes": current[1],
                "eligible_preseal_file_count": preseal[0],
                "eligible_preseal_bytes": preseal[1],
            })

    candidates.sort(key=lambda record: (record.disposition, record.scope, record.relative.lower()))
    return ScanResult(
        candidates=candidates,
        holds=holds,
        hold_bytes=hold_bytes,
        current_groups=current_groups,
        preseal_action_groups=preseal_action_groups,
        drift_rows=drift_rows,
        files_seen=files_seen,
        bytes_seen=bytes_seen,
    )


def _summarize_plan(scan: ScanResult) -> dict[str, object]:
    by_disposition: dict[str, dict[str, int]] = defaultdict(lambda: {"files": 0, "bytes": 0})
    for record in scan.candidates:
        by_disposition[record.disposition]["files"] += 1
        by_disposition[record.disposition]["bytes"] += record.size
    return {
        "files_seen": scan.files_seen,
        "bytes_seen": scan.bytes_seen,
        "eligible": dict(sorted(by_disposition.items())),
        "eligible_files": len(scan.candidates),
        "eligible_bytes": sum(record.size for record in scan.candidates),
        "holds": dict(sorted(scan.holds.items())),
        "hold_bytes": dict(sorted(scan.hold_bytes.items())),
        "drifted_aggregate_rows": len(scan.drift_rows),
    }


def _atomic_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def _canonical_lines(entries: Iterable[dict[str, object]]) -> Iterator[bytes]:
    for entry in entries:
        yield (json.dumps(entry, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _write_exact_inventory(path: Path, entries: list[dict[str, object]]) -> tuple[str, str, int]:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    content_hash = hashlib.sha256()
    with temporary.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as zipped:
            for line in _canonical_lines(entries):
                content_hash.update(line)
                zipped.write(line)
    os.replace(temporary, path)
    return content_hash.hexdigest(), _sha256(path), path.stat().st_size


def _batch(records: list[FileRecord], max_files: int, max_bytes: int) -> Iterator[list[FileRecord]]:
    current: list[FileRecord] = []
    current_bytes = 0
    for record in records:
        if current and (len(current) >= max_files or current_bytes + record.size > max_bytes):
            yield current
            current = []
            current_bytes = 0
        current.append(record)
        current_bytes += record.size
    if current:
        yield current


def _exclusive_probe(path: Path) -> tuple[bool, str]:
    if os.name != "nt":
        return True, "non_windows_probe_skipped"
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    create_file = kernel32.CreateFileW
    create_file.argtypes = [
        ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p,
        ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p,
    ]
    create_file.restype = ctypes.c_void_p
    handle = create_file(str(path), 0, 0, None, 3, 0x00200000, None)
    invalid = ctypes.c_void_p(-1).value
    if handle == invalid:
        return False, f"winerror={ctypes.get_last_error()}"
    kernel32.CloseHandle(ctypes.c_void_p(handle))
    return True, "exclusive_probe_ok"


def _identity_matches(record: FileRecord) -> tuple[bool, str]:
    try:
        size, mtime_ns, inode, attributes = _stat_identity(record.path)
    except OSError as exc:
        return False, f"stat_failed:{exc}"
    if attributes & FILE_ATTRIBUTE_REPARSE_POINT:
        return False, "became_reparse_point"
    if (size, mtime_ns, inode) != (record.size, record.mtime_ns, record.inode):
        return False, "identity_changed_since_scan"
    return _exclusive_probe(record.path)


def _disk_free(path: Path) -> int:
    return int(shutil.disk_usage(path.anchor or str(path)).free)


def _content_sha256(path: Path) -> str:
    return _sha256(path)


def _quarantine_root(record: FileRecord, run_id: str) -> Path:
    if record.scope in {"D_REPORTS", "D_FARM_LOGS"}:
        return Path(f"D:/QM/reports/maintenance/retention_quarantine_{run_id}")
    if record.scope == "C_RELOCATED":
        return Path(f"C:/QM/backups_relocated/retention_quarantine_{run_id}")
    raise ValueError(f"unsupported quarantine scope {record.scope}")


def _quarantine_destination(record: FileRecord, run_id: str) -> Path:
    """Return a bounded-length, collision-resistant same-volume destination."""
    identity = f"{record.scope}\0{record.path}".encode("utf-8")
    token = hashlib.sha256(identity).hexdigest()
    suffix = "".join(record.path.suffixes[-2:])[-24:]
    suffix = re.sub(r"[^A-Za-z0-9._-]", "_", suffix)
    return _quarantine_root(record, run_id) / record.scope / token[:2] / f"{token}{suffix}"


def _restore_unverified_move(record: FileRecord, destination: Path) -> tuple[str, str]:
    """Restore a drifted file when possible; never overwrite a recreated source."""
    if record.path.exists():
        return "QUARANTINED_RECOVERABLE", "source_recreated_after_quarantine"
    try:
        record.path.parent.mkdir(parents=True, exist_ok=True)
        os.rename(destination, record.path)
        return "HELD_RESTORED", "post_move_verification_failed; restored_to_source"
    except OSError as exc:
        return "QUARANTINED_RECOVERABLE", f"restore_failed:{exc}"


def _execute_delete_batch(
    records: list[FileRecord],
    run_id: str,
    batch_id: str,
    receipt_dir: Path,
    manifest_sha256: str,
    hash_contents: bool,
) -> dict[str, object]:
    entries: list[dict[str, object]] = []
    verified: list[tuple[FileRecord, Path, dict[str, object]]] = []
    free_before_by_drive: dict[str, int] = {}
    for record in records:
        free_before_by_drive.setdefault(record.path.drive.upper(), _disk_free(record.path))
        entry = record.inventory_entry()
        destination = _quarantine_destination(record, run_id)
        entry["quarantine"] = str(destination)
        ok, reason = _identity_matches(record)
        if not ok:
            entry["status"] = "HELD"
            entry["detail"] = reason
            entries.append(entry)
            continue
        if destination.exists():
            entry["status"] = "HELD"
            entry["detail"] = "quarantine_collision"
            entries.append(entry)
            continue
        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
            os.replace(record.path, destination)
            dsize, dmtime, dinode, dattributes = _stat_identity(destination)
        except OSError as exc:
            entry["status"] = "HELD"
            entry["detail"] = f"quarantine_move_failed:{exc}"
            entries.append(entry)
            continue
        if dattributes & FILE_ATTRIBUTE_REPARSE_POINT or (dsize, dmtime) != (record.size, record.mtime_ns):
            entry["status"], entry["detail"] = _restore_unverified_move(record, destination)
            entries.append(entry)
            continue
        entry["quarantine_inode"] = dinode
        if hash_contents:
            try:
                entry["content_sha256"] = _content_sha256(destination)
            except OSError as exc:
                entry["status"], restore_detail = _restore_unverified_move(record, destination)
                entry["detail"] = f"content_hash_failed:{exc};{restore_detail}"
                entries.append(entry)
                continue
        entry["status"] = "QUARANTINED_VERIFIED"
        entry["detail"] = "same_volume_move_and_identity_verified"
        entries.append(entry)
        verified.append((record, destination, entry))

    for record, destination, entry in verified:
        try:
            destination.unlink()
            if destination.exists():
                raise OSError("path still exists after unlink")
            entry["status"] = "DELETED"
            entry["detail"] = "verified_quarantine_then_unlink"
        except OSError as exc:
            entry["status"] = "QUARANTINED_RECOVERABLE"
            entry["detail"] = f"unlink_failed:{exc}"

    inventory_path = receipt_dir / f"{batch_id}_exact_paths.jsonl.gz"
    entries_sha, gzip_sha, gzip_bytes = _write_exact_inventory(inventory_path, entries)
    free_after_by_drive = {
        drive: _disk_free(Path(f"{drive}\\")) for drive in free_before_by_drive
    }
    deleted = [entry for entry in entries if entry["status"] == "DELETED"]
    quarantined = [entry for entry in entries if str(entry["status"]).startswith("QUARANTINED")]
    held = [entry for entry in entries if str(entry["status"]).startswith("HELD")]
    receipt = {
        "schema": "qm.backup-retention.phase2-batch.v1",
        "authority": "OWNER-DEC-BACKUP-RETENTION-20260830",
        "run_id": run_id,
        "batch_id": batch_id,
        "action": "DELETE_VIA_QUARANTINE",
        "manifest_sha256": manifest_sha256,
        "requested_files": len(records),
        "requested_bytes": sum(record.size for record in records),
        "deleted_files": len(deleted),
        "deleted_logical_bytes": sum(int(entry["size"]) for entry in deleted),
        "held_files": len(held),
        "recoverable_quarantine_files": len(quarantined),
        "exact_paths_file": inventory_path.name,
        "exact_paths_canonical_sha256": entries_sha,
        "exact_paths_gzip_sha256": gzip_sha,
        "exact_paths_gzip_bytes": gzip_bytes,
        "volume_free_before": free_before_by_drive,
        "volume_free_after": free_after_by_drive,
        "volume_free_delta": {
            drive: free_after_by_drive[drive] - before for drive, before in free_before_by_drive.items()
        },
        "completed_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
    }
    _atomic_json(receipt_dir / f"{batch_id}.json", receipt)
    return receipt


def _get_file_attributes(path: Path) -> int:
    if os.name != "nt":
        return 0
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    func = kernel32.GetFileAttributesW
    func.argtypes = [ctypes.c_wchar_p]
    func.restype = ctypes.c_uint32
    result = int(func(str(path)))
    if result == 0xFFFFFFFF:
        raise OSError(ctypes.get_last_error(), f"GetFileAttributesW failed: {path}")
    return result


def _allocated_size(path: Path) -> int:
    if os.name != "nt":
        return path.stat().st_size
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    func = kernel32.GetCompressedFileSizeW
    func.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_uint32)]
    func.restype = ctypes.c_uint32
    high = ctypes.c_uint32(0)
    ctypes.set_last_error(0)
    low = int(func(str(path), ctypes.byref(high)))
    error = ctypes.get_last_error()
    if low == 0xFFFFFFFF and error:
        raise OSError(error, f"GetCompressedFileSizeW failed: {path}")
    return (int(high.value) << 32) | low


def _set_ntfs_compression(record: FileRecord) -> tuple[bool, str, int, int]:
    try:
        size, mtime_ns, inode, attributes = _stat_identity(record.path)
    except OSError as exc:
        return False, f"stat_failed:{exc}", 0, 0
    if (size, mtime_ns, inode) != (record.size, record.mtime_ns, record.inode):
        return False, "identity_changed_since_scan", 0, 0
    try:
        before = _allocated_size(record.path)
    except OSError:
        before = record.size
    if attributes & FILE_ATTRIBUTE_COMPRESSED:
        return True, "already_ntfs_compressed", before, before
    if os.name != "nt":
        return False, "NTFS compression requires Windows", before, before

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    create_file = kernel32.CreateFileW
    create_file.argtypes = [
        ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p,
        ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p,
    ]
    create_file.restype = ctypes.c_void_p
    handle = create_file(
        str(record.path), 0xC0000000, 0, None, 3,
        0x08000000 | 0x00200000, None,
    )
    invalid = ctypes.c_void_p(-1).value
    if handle == invalid:
        return False, f"exclusive_open_failed:winerror={ctypes.get_last_error()}", before, before
    try:
        compression_format = ctypes.c_uint16(1)
        returned = ctypes.c_uint32(0)
        device_io = kernel32.DeviceIoControl
        device_io.argtypes = [
            ctypes.c_void_p, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32,
            ctypes.c_void_p, ctypes.c_uint32, ctypes.POINTER(ctypes.c_uint32), ctypes.c_void_p,
        ]
        device_io.restype = ctypes.c_int
        ok = device_io(
            ctypes.c_void_p(handle), 0x0009C040,
            ctypes.byref(compression_format), ctypes.sizeof(compression_format),
            None, 0, ctypes.byref(returned), None,
        )
        if not ok:
            return False, f"FSCTL_SET_COMPRESSION_failed:winerror={ctypes.get_last_error()}", before, before
    finally:
        kernel32.CloseHandle(ctypes.c_void_p(handle))

    try:
        after = _allocated_size(record.path)
        attributes_after = _get_file_attributes(record.path)
    except OSError as exc:
        return False, f"post_compression_verify_failed:{exc}", before, before
    if not attributes_after & FILE_ATTRIBUTE_COMPRESSED:
        return False, "compressed_attribute_not_set", before, after
    return True, "ntfs_compression_verified", before, after


def _execute_compress_batch(
    records: list[FileRecord],
    run_id: str,
    batch_id: str,
    receipt_dir: Path,
    manifest_sha256: str,
) -> dict[str, object]:
    entries: list[dict[str, object]] = []
    for record in records:
        entry = record.inventory_entry()
        ok, detail, before, after = _set_ntfs_compression(record)
        entry["status"] = "COMPRESSED" if ok else "HELD"
        entry["detail"] = detail
        entry["allocated_before"] = before
        entry["allocated_after"] = after
        entries.append(entry)
    inventory_path = receipt_dir / f"{batch_id}_exact_paths.jsonl.gz"
    entries_sha, gzip_sha, gzip_bytes = _write_exact_inventory(inventory_path, entries)
    compressed = [entry for entry in entries if entry["status"] == "COMPRESSED"]
    held = [entry for entry in entries if entry["status"] == "HELD"]
    receipt = {
        "schema": "qm.backup-retention.phase2-batch.v1",
        "authority": "OWNER-DEC-BACKUP-RETENTION-20260830",
        "run_id": run_id,
        "batch_id": batch_id,
        "action": "NTFS_COMPRESS",
        "manifest_sha256": manifest_sha256,
        "requested_files": len(records),
        "requested_bytes": sum(record.size for record in records),
        "compressed_files": len(compressed),
        "held_files": len(held),
        "allocated_before": sum(int(entry["allocated_before"]) for entry in compressed),
        "allocated_after": sum(int(entry["allocated_after"]) for entry in compressed),
        "allocated_saved": sum(
            max(0, int(entry["allocated_before"]) - int(entry["allocated_after"]))
            for entry in compressed
        ),
        "exact_paths_file": inventory_path.name,
        "exact_paths_canonical_sha256": entries_sha,
        "exact_paths_gzip_sha256": gzip_sha,
        "exact_paths_gzip_bytes": gzip_bytes,
        "completed_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
    }
    _atomic_json(receipt_dir / f"{batch_id}.json", receipt)
    return receipt


def _quick_check(db_path: Path) -> str:
    uri = db_path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=10)
    try:
        row = connection.execute("PRAGMA quick_check").fetchone()
        return str(row[0]) if row else "no_result"
    finally:
        connection.close()


class _BackgroundIo:
    entered = False

    def __enter__(self) -> "_BackgroundIo":
        if os.name == "nt":
            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
            self.entered = bool(kernel32.SetPriorityClass(kernel32.GetCurrentProcess(), 0x00100000))
        return self

    def __exit__(self, _exc_type: object, _exc: object, _tb: object) -> None:
        if self.entered and os.name == "nt":
            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel32.SetPriorityClass(kernel32.GetCurrentProcess(), 0x00200000)


def _factory_active_count(db_path: Path) -> int:
    try:
        uri = db_path.resolve().as_uri() + "?mode=ro"
        connection = sqlite3.connect(uri, uri=True, timeout=2)
        try:
            row = connection.execute(
                "SELECT COUNT(*) FROM work_items WHERE lower(status) IN ('active','claimed','in_progress')"
            ).fetchone()
            return int(row[0]) if row else 0
        finally:
            connection.close()
    except (OSError, sqlite3.Error):
        return -1


def _throttle(db_path: Path, delay_seconds: float) -> int:
    active = _factory_active_count(db_path)
    multiplier = 4 if active >= 8 else (2 if active >= 5 else 1)
    time.sleep(max(0.0, delay_seconds) * multiplier)
    return active


def execute(
    scan: ScanResult,
    db_path: Path,
    run_id: str,
    receipt_dir: Path,
    manifest_sha256: str,
    batch_max_files: int,
    batch_max_bytes: int,
    delay_seconds: float,
) -> dict[str, object]:
    receipt_dir.mkdir(parents=True, exist_ok=True)
    non_db_delete = [
        record for record in scan.candidates
        if record.disposition in DELETE_DISPOSITIONS and record.disposition != "DELETE_DB_ROTATION"
    ]
    compress = [record for record in scan.candidates if record.disposition in COMPRESS_DISPOSITIONS]
    db_delete = [record for record in scan.candidates if record.disposition == "DELETE_DB_ROTATION"]
    receipts: list[dict[str, object]] = []
    batch_number = 0
    active_samples: list[int] = []

    with _BackgroundIo() as background:
        for records in _batch(non_db_delete, batch_max_files, batch_max_bytes):
            batch_number += 1
            batch_id = f"batch_{batch_number:04d}_delete"
            receipt = _execute_delete_batch(
                records, run_id, batch_id, receipt_dir, manifest_sha256, hash_contents=False
            )
            receipts.append(receipt)
            active_samples.append(_throttle(db_path, delay_seconds))
            print(json.dumps({"progress": batch_id, "receipt": receipt}, sort_keys=True), flush=True)

        for records in _batch(compress, batch_max_files, batch_max_bytes):
            batch_number += 1
            batch_id = f"batch_{batch_number:04d}_compress"
            receipt = _execute_compress_batch(records, run_id, batch_id, receipt_dir, manifest_sha256)
            receipts.append(receipt)
            active_samples.append(_throttle(db_path, delay_seconds))
            print(json.dumps({"progress": batch_id, "receipt": receipt}, sort_keys=True), flush=True)

        db_quick_check = "not_required"
        if db_delete:
            db_quick_check = _quick_check(db_path)
            if db_quick_check != "ok":
                raise RuntimeError(f"fresh DB quick_check failed before rotation: {db_quick_check}")
            for records in _batch(db_delete, batch_max_files, batch_max_bytes):
                batch_number += 1
                batch_id = f"batch_{batch_number:04d}_db_rotation"
                receipt = _execute_delete_batch(
                    records, run_id, batch_id, receipt_dir, manifest_sha256, hash_contents=True
                )
                receipt["fresh_db_quick_check"] = db_quick_check
                _atomic_json(receipt_dir / f"{batch_id}.json", receipt)
                receipts.append(receipt)
                active_samples.append(_throttle(db_path, delay_seconds))
                print(json.dumps({"progress": batch_id, "receipt": receipt}, sort_keys=True), flush=True)

    deleted_files = sum(int(receipt.get("deleted_files", 0)) for receipt in receipts)
    deleted_bytes = sum(int(receipt.get("deleted_logical_bytes", 0)) for receipt in receipts)
    compressed_files = sum(int(receipt.get("compressed_files", 0)) for receipt in receipts)
    compressed_bytes = sum(int(receipt.get("requested_bytes", 0)) for receipt in receipts if receipt["action"] == "NTFS_COMPRESS")
    compression_saved = sum(int(receipt.get("allocated_saved", 0)) for receipt in receipts)
    held_files = sum(int(receipt.get("held_files", 0)) for receipt in receipts)
    recoverable = sum(int(receipt.get("recoverable_quarantine_files", 0)) for receipt in receipts)
    return {
        "schema": "qm.backup-retention.phase2-run.v1",
        "authority": "OWNER-DEC-BACKUP-RETENTION-20260830",
        "run_id": run_id,
        "manifest_sha256": manifest_sha256,
        "receipt_dir": str(receipt_dir),
        "batch_count": len(receipts),
        "deleted_files": deleted_files,
        "deleted_logical_bytes": deleted_bytes,
        "compressed_files": compressed_files,
        "compressed_source_bytes": compressed_bytes,
        "compression_allocated_saved": compression_saved,
        "action_held_files": held_files,
        "recoverable_quarantine_files": recoverable,
        "fresh_db_quick_check": db_quick_check,
        "background_io_mode": background.entered,
        "factory_active_samples": active_samples,
        "completed_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="execute mutations; default is read-only")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--reports-root", type=Path, default=DEFAULT_REPORTS)
    parser.add_argument("--logs-root", type=Path, default=DEFAULT_LOGS)
    parser.add_argument("--relocated-root", type=Path, default=DEFAULT_RELOCATED)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--manifest-markdown", type=Path, default=DEFAULT_MANIFEST_MD)
    parser.add_argument("--expected-manifest-sha256", default=EXPECTED_MANIFEST_SHA256)
    parser.add_argument("--run-id")
    parser.add_argument("--receipt-dir", type=Path)
    parser.add_argument("--summary-json", type=Path)
    parser.add_argument("--batch-max-files", type=int, default=5000)
    parser.add_argument("--batch-max-bytes", type=int, default=512 * 1024 * 1024)
    parser.add_argument("--batch-delay-seconds", type=float, default=0.10)
    args = parser.parse_args()

    if args.batch_max_files < 1 or args.batch_max_bytes < 1:
        parser.error("batch limits must be positive")
    manifest_sha = _sha256(args.manifest)
    sealed = load_sealed_rows(args.manifest, args.expected_manifest_sha256)
    seal_time = _seal_time(args.manifest_markdown)
    snapshot = phase1.load_snapshot(args.db)
    if snapshot.db_quick_check != "ok":
        raise RuntimeError(f"initial live DB quick_check failed: {snapshot.db_quick_check}")
    now = dt.datetime.now(dt.UTC)
    scan = build_plan(
        sealed, seal_time, snapshot,
        args.reports_root, args.logs_root, args.relocated_root, now,
    )
    plan_summary = {
        "schema": "qm.backup-retention.phase2-plan.v1",
        "authority": "OWNER-DEC-BACKUP-RETENTION-20260830",
        "mode": "APPLY" if args.apply else "DRY_RUN",
        "manifest": str(args.manifest),
        "manifest_sha256": manifest_sha,
        "seal_time": seal_time.replace(microsecond=0).isoformat(),
        "live_db_quick_check": snapshot.db_quick_check,
        "live_db_max_work_item_updated_at": snapshot.db_max_updated_at,
        "planned_at": now.replace(microsecond=0).isoformat(),
        **_summarize_plan(scan),
        "drift_rows": scan.drift_rows,
    }
    console_plan = dict(plan_summary)
    console_plan.pop("drift_rows", None)
    print(json.dumps(console_plan, indent=2, sort_keys=True), flush=True)

    if not args.apply:
        if args.summary_json:
            _atomic_json(args.summary_json, plan_summary)
        return 0

    if not args.run_id or not args.receipt_dir:
        parser.error("--apply requires both --run-id and --receipt-dir")
    receipt_root = args.receipt_dir.resolve()
    canonical_evidence = Path("C:/QM/repo/docs/ops/evidence").resolve()
    try:
        receipt_root.relative_to(canonical_evidence)
    except ValueError as exc:
        raise ValueError(f"receipt directory must be under {canonical_evidence}") from exc

    execution = execute(
        scan, args.db, args.run_id, receipt_root, manifest_sha,
        args.batch_max_files, args.batch_max_bytes, args.batch_delay_seconds,
    )
    final = {"plan": plan_summary, "execution": execution}
    summary_path = args.summary_json or receipt_root / "run_summary.json"
    _atomic_json(summary_path, final)
    print(json.dumps(execution, indent=2, sort_keys=True), flush=True)
    return 2 if execution["recoverable_quarantine_files"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
