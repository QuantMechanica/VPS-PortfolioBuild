"""Continuous low-space retention under OWNER-DEC-BACKUP-RETENTION-20260830.

The runner is fail-closed and single-pass.  It is normally invoked every 45
minutes by Windows Task Scheduler.  Above the free-space watermark it records
a no-op.  Below the watermark it:

* validates the live farm DB with PRAGMA quick_check before backup deletion;
* retains the newest eight hourly farm-state backups, mutation backups for 48
  hours, and every snapshot referenced by an open work-item receipt; a 10 GiB
  cap removes only otherwise-unprotected snapshots,
  NTFS-compresses retained backups, and removes older backups in byte-receipted
  batches;
* NTFS-compresses work-item evidence older than two hours, excluding every
  open work-item directory/path;
* rotates large exclusively-openable logs and deletes logs older than 48 hours,
  excluding log paths bound to open work items.

Database-journal archival is a second, Default-OFF gate.  When explicitly
enabled with ``--archive-state-journals --apply``, old ``events`` rows are
written to a hash-bound append-only JSONL archive and only then deleted and
VACUUMed under the factory mutation lock in a verified quiet window.
``--apply`` is required for every mutation.
"""
from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import hashlib
import json
import msvcrt
import os
import re
import shutil
import sqlite3
import sys
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterable

try:
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:  # direct ``python tools/.../script.py`` invocation
    from factory_mutation_lock import FactoryMutationLock


AUTHORITY = "OWNER-DEC-BACKUP-RETENTION-20260830"
SCHEMA = "qm.continuous-retention/v1"
DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_BACKUPS = Path("D:/QM/strategy_farm/state/backups")
DEFAULT_WORK_ITEMS = Path("D:/QM/reports/work_items")
DEFAULT_LOGS = Path("D:/QM/strategy_farm/logs")
DEFAULT_RECEIPTS = Path("D:/QM/reports/state/continuous_retention")
DEFAULT_TELEMETRY = Path("D:/QM/reports/state/backup_retention_continuous.jsonl")
DEFAULT_LOCK = Path("D:/QM/strategy_farm/state/locks/continuous_retention.lock")
DEFAULT_ARCHIVE_ROOT = Path("D:/QM/reports/state/archive")
DEFAULT_FACTORY_LOCK = Path("D:/QM/strategy_farm/state/FACTORY_MUTATION.lock")
OPEN_STATUSES = {"pending", "active", "claimed", "in_progress"}
BUSY_STATUSES = {"active", "claimed", "in_progress"}
COMPRESSED_ATTRIBUTE = 0x00000800
REPARSE_ATTRIBUTE = 0x00000400
HOURLY_BACKUP_RE = re.compile(r"farm_state_\d{8}_\d{4}\.sqlite$")
MUTATION_BACKUP_RE = re.compile(r"farm_state_before_.+\.sqlite$")
BACKUP_CAP_BYTES = 10 * 1024**3


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")


def telemetry_record(summary: dict[str, Any]) -> dict[str, Any]:
    record = {key: value for key, value in summary.items()
              if key not in {"backup_compression", "evidence_compression", "log_rotation", "backup_retention"}}
    for source, label in (("backup_compression", "backup_compression"),
                          ("evidence_compression", "evidence_compression"),
                          ("log_rotation", "log_rotation")):
        rows = summary.get(source, [])
        statuses: dict[str, int] = {}
        for row in rows:
            status = str(row.get("status", "UNKNOWN"))
            statuses[status] = statuses.get(status, 0) + 1
        record[label] = {
            "files": len(rows),
            "logical_bytes": sum(int(row.get("bytes", 0)) for row in rows),
            "status_counts": statuses,
        }
    if "free_before" in summary and "free_after" in summary:
        record["free_delta"] = int(summary["free_after"]) - int(summary["free_before"])
    record["purge_log_pattern"] = {
        "retention": "current_plus_48h",
        "rotation": record["log_rotation"],
        "deletion": summary.get("log_delete", {}),
    }
    if "backup_retention" in summary:
        plan = summary["backup_retention"]
        reason_counts: dict[str, int] = {}
        for row in plan.get("decisions", []):
            key = f"{row.get('decision', 'UNKNOWN')}:{row.get('reason', 'UNKNOWN')}"
            reason_counts[key] = reason_counts.get(key, 0) + 1
        record["backup_retention"] = {
            "cap_bytes": plan.get("cap_bytes"),
            "retained_bytes": plan.get("retained_bytes"),
            "cap_satisfied": plan.get("cap_satisfied"),
            "reason_counts": reason_counts,
        }
    return record


@contextmanager
def exclusive_runner_lock(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("a+b")
    try:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            handle.write(b"0")
            handle.flush()
        handle.seek(0)
        try:
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            yield False
            return
        try:
            yield True
        finally:
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
    finally:
        handle.close()


def quick_check(db_path: Path) -> str:
    uri = db_path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=15)
    try:
        row = connection.execute("PRAGMA quick_check").fetchone()
        return str(row[0]) if row else "no_result"
    finally:
        connection.close()


def _strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            yield str(key)
            yield from _strings(item)
    elif isinstance(value, (list, tuple)):
        for item in value:
            yield from _strings(item)


def open_bindings(db_path: Path) -> tuple[set[str], set[Path]]:
    uri = db_path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=15)
    ids: set[str] = set()
    paths: set[Path] = set()
    try:
        rows = connection.execute(
            "SELECT id, evidence_path, payload_json FROM work_items "
            "WHERE lower(status) IN ('pending','active','claimed','in_progress')"
        )
        for work_id, evidence_path, payload_json in rows:
            ids.add(str(work_id).lower())
            for raw in (evidence_path,):
                if raw:
                    paths.add(Path(str(raw)).resolve())
            try:
                payload = json.loads(payload_json or "{}")
            except json.JSONDecodeError:
                payload = {}
            if isinstance(payload, dict):
                for key in ("report_root", "evidence_path", "phase_evidence_path", "log_path"):
                    raw = payload.get(key)
                    if raw:
                        paths.add(Path(str(raw)).resolve())
    finally:
        connection.close()
    return ids, paths


def open_backup_references(db_path: Path, backups_root: Path) -> set[Path]:
    """Return exact backup files named by an open row or its JSON receipt.

    Receipt reads are bounded and read-only.  A missing or malformed receipt
    cannot create a false deletion candidate because the raw DB bindings are
    still searched and only exact filenames under ``backups_root`` match.
    """
    candidates = [p.resolve() for p in backups_root.glob("*.sqlite") if p.is_file()]
    if not candidates:
        return set()
    uri = db_path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=15)
    haystacks: list[str] = []
    try:
        rows = connection.execute(
            "SELECT evidence_path, payload_json FROM work_items "
            "WHERE lower(status) IN ('pending','active','claimed','in_progress')"
        )
        for evidence_path, payload_json in rows:
            raw_values: list[str] = [str(evidence_path or ""), str(payload_json or "")]
            try:
                payload = json.loads(payload_json or "{}")
                raw_values.extend(_strings(payload))
            except json.JSONDecodeError:
                pass
            if evidence_path:
                receipt = Path(str(evidence_path))
                try:
                    if receipt.is_file() and receipt.suffix.lower() == ".json" and receipt.stat().st_size <= 16 * 1024**2:
                        raw_values.append(receipt.read_text(encoding="utf-8-sig"))
                except OSError:
                    pass
            haystacks.append("\n".join(raw_values).replace("\\", "/").lower())
    finally:
        connection.close()
    protected: set[Path] = set()
    for candidate in candidates:
        full = str(candidate).replace("\\", "/").lower()
        name = candidate.name.lower()
        if any(full in text or name in text for text in haystacks):
            protected.add(candidate)
    return protected


def is_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def is_open_bound(path: Path, open_ids: set[str], open_paths: set[Path]) -> bool:
    lowered_parts = {part.lower() for part in path.parts}
    if lowered_parts & open_ids:
        return True
    resolved = path.resolve()
    # Candidates are files.  A file is protected when it is the exact bound
    # path or is below a bound directory; hashed ancestor membership avoids an
    # O(files * open_work_items) scan on the production queue.
    return resolved in open_paths or any(parent in open_paths for parent in resolved.parents)


def file_attributes(path: Path) -> int:
    return int(getattr(path.stat(), "st_file_attributes", 0))


def open_exclusive_windows_handle(path: Path) -> tuple[Any, int]:
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    create_file = kernel32.CreateFileW
    create_file.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                            ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32,
                            ctypes.c_void_p]
    create_file.restype = ctypes.c_void_p
    kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    kernel32.CloseHandle.restype = ctypes.c_int
    handle = create_file(str(path), 0xC0000000, 0, None, 3,
                         0x08000000 | 0x00200000, None)
    return kernel32, handle


def set_ntfs_compression(path: Path) -> tuple[str, int, int]:
    size = path.stat().st_size
    attributes = file_attributes(path)
    if attributes & REPARSE_ATTRIBUTE:
        return "HELD_REPARSE", size, size
    if attributes & COMPRESSED_ATTRIBUTE:
        return "ALREADY_COMPRESSED", size, size
    if os.name != "nt":
        return "HELD_NON_WINDOWS", size, size
    kernel32, handle = open_exclusive_windows_handle(path)
    if handle == ctypes.c_void_p(-1).value:
        return f"HELD_OPEN_{ctypes.get_last_error()}", size, size
    try:
        fmt = ctypes.c_uint16(1)
        returned = ctypes.c_uint32(0)
        ok = kernel32.DeviceIoControl(ctypes.c_void_p(handle), 0x0009C040,
                                      ctypes.byref(fmt), ctypes.sizeof(fmt),
                                      None, 0, ctypes.byref(returned), None)
        if not ok:
            return f"HELD_COMPRESS_{ctypes.get_last_error()}", size, size
    finally:
        kernel32.CloseHandle(ctypes.c_void_p(handle))
    return ("COMPRESSED" if file_attributes(path) & COMPRESSED_ATTRIBUTE else "HELD_VERIFY", size, path.stat().st_size)


def backup_retention_plan(
    root: Path,
    now: dt.datetime,
    referenced: set[Path] | None = None,
    *,
    cap_bytes: int = BACKUP_CAP_BYTES,
) -> dict[str, Any]:
    """Build the exact reasoned plan; unrelated SQLite files are invisible."""
    referenced = {p.resolve() for p in (referenced or set())}
    files = sorted(
        (
            p for p in root.glob("*.sqlite")
            if p.is_file() and (HOURLY_BACKUP_RE.fullmatch(p.name) or MUTATION_BACKUP_RE.fullmatch(p.name))
        ),
        key=lambda p: (p.stat().st_mtime_ns, p.name),
        reverse=True,
    )
    hourly = [p for p in files if HOURLY_BACKUP_RE.fullmatch(p.name)]
    hourly_floor = {p.resolve() for p in hourly[:8]}
    mutation_cutoff = now.timestamp() - 48 * 3600
    rows: list[dict[str, Any]] = []
    keep: set[Path] = set()
    protected: set[Path] = set()
    for path in files:
        resolved = path.resolve()
        if resolved in referenced:
            reason = "OPEN_RECEIPT_REFERENCE"
            keep.add(resolved)
            protected.add(resolved)
        elif resolved in hourly_floor:
            reason = "HOURLY_NEWEST_8"
            keep.add(resolved)
            protected.add(resolved)
        elif MUTATION_BACKUP_RE.fullmatch(path.name) and path.stat().st_mtime >= mutation_cutoff:
            reason = "MUTATION_WITHIN_48H"
            keep.add(resolved)
        else:
            reason = "EXPIRED_POLICY"
        rows.append({"path": str(resolved), "bytes": path.stat().st_size, "decision": "KEEP" if resolved in keep else "DELETE", "reason": reason})

    total = sum(row["bytes"] for row in rows if row["decision"] == "KEEP")
    if total > cap_bytes:
        # Oldest unprotected candidates leave first.  The newest-eight hourly
        # floor and open-receipt references are fail-closed even if they alone
        # make the configured cap unattainable.
        removable = sorted(
            (row for row in rows if Path(row["path"]) in keep - protected),
            key=lambda row: (Path(row["path"]).stat().st_mtime_ns, row["path"]),
        )
        for row in removable:
            if total <= cap_bytes:
                break
            row["decision"] = "DELETE"
            row["reason"] = "HARD_CAP_10_GIB"
            keep.remove(Path(row["path"]))
            total -= int(row["bytes"])
    delete = [Path(row["path"]) for row in rows if row["decision"] == "DELETE"]
    return {
        "cap_bytes": cap_bytes,
        "retained_bytes": total,
        "cap_satisfied": total <= cap_bytes,
        "keep": sorted(keep, key=str),
        "delete": delete,
        "decisions": rows,
    }


def backup_plan(root: Path, now: dt.datetime) -> tuple[list[Path], list[Path]]:
    """Compatibility surface for callers/tests that only need path sets."""
    plan = backup_retention_plan(root, now)
    return list(plan["keep"]), list(plan["delete"])


def legacy_backup_retention_plan(root: Path, now: dt.datetime) -> dict[str, Any]:
    """Preserve the ratified pre-ticket policy while the new gate is OFF."""
    files = sorted(
        (p for p in root.glob("farm_state_before_*.sqlite") if p.is_file()),
        key=lambda p: (p.stat().st_mtime_ns, p.name), reverse=True,
    )
    cutoff = now.timestamp() - 24 * 3600
    keep = [p.resolve() for index, p in enumerate(files) if index < 5 or p.stat().st_mtime >= cutoff]
    keep_set = set(keep)
    delete = [p.resolve() for p in files if p.resolve() not in keep_set]
    return {
        "cap_bytes": None,
        "retained_bytes": sum(path.stat().st_size for path in keep),
        "cap_satisfied": None,
        "keep": keep,
        "delete": delete,
        "decisions": [
            {"path": str(p.resolve()), "bytes": p.stat().st_size,
             "decision": "KEEP" if p.resolve() in keep_set else "DELETE",
             "reason": "LEGACY_NEWEST_5_OR_24H" if p.resolve() in keep_set else "LEGACY_EXPIRED"}
            for p in files
        ],
    }


def serializable_backup_plan(plan: dict[str, Any]) -> dict[str, Any]:
    return {
        **plan,
        "keep": [str(path) for path in plan["keep"]],
        "delete": [str(path) for path in plan["delete"]],
    }


LONG_PATH_PREFIX = "\\\\?\\"


def long_path(path: "str | Path") -> str:
    """Return ``path`` with the Win32 extended-length prefix (no-op elsewhere)."""
    text = os.fspath(path)
    if os.name != "nt" or text.startswith(LONG_PATH_PREFIX):
        return text
    return LONG_PATH_PREFIX + os.path.abspath(text)


# 2026-09-20 (Fable): a directory that lists fine by its plain name can still
# contain FILES whose full path exceeds MAX_PATH (Q09 contract-v2 pass-anchor
# cells: ...\runs\selection\QM5_1567\20260917_005027\raw\run_01\logger_sample.jsonl).
# stat()/GetFileAttributes on such a plain path raise WinError 3 and every
# scheduled run since 2026-09-17 failed closed again (backups grew to 53.6 GB,
# D: fell to 81 GB, the cold-restart worker cap dropped to 5).  Long file
# paths are therefore yielded with the extended-length prefix as well, and the
# per-file consumer skips a file it still cannot open instead of aborting.
LONG_PATH_YIELD_THRESHOLD = 240


def yieldable_path(entry_path: str) -> str:
    """Plain path when short enough for Win32 calls, else the prefixed form."""
    if os.name == "nt" and len(entry_path) >= LONG_PATH_YIELD_THRESHOLD:
        return long_path(entry_path)
    return entry_path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def iter_old_files(root: Path, cutoff_epoch: float) -> Iterable[Path]:
    """Yield files under ``root`` older than ``cutoff_epoch``.

    2026-09-02: ``Path.rglob`` aborted the whole run with ``FileNotFoundError``
    (WinError 3) as soon as the evidence tree contained a directory deeper
    than MAX_PATH (Q09 contract-v3 successor cells: ``reports/work_items/<id>/
    q09_contract_v3/successors/<sha256>/cells/.../raw/run_01/...``).  Every
    scheduled run since 2026-08-26 failed closed, so no backup was compressed
    and no evidence aged out while D: filled up.  The walk now descends with
    ``os.scandir``; a directory that cannot be listed by its plain name is
    retried with the extended-length prefix, and a directory that still cannot
    be listed is skipped (recorded by the caller as untouched) instead of
    aborting the run.  Files found below a prefixed directory are yielded with
    the prefix so that the Win32 attribute/compression calls can open them;
    the work-item id guard in ``is_open_bound`` matches on path parts and is
    prefix-agnostic, and the exclusive-handle check still protects every file
    that is in use.
    """
    if not root.is_dir():
        return []

    def _walk() -> Iterable[Path]:
        stack = [os.fspath(root)]
        while stack:
            directory = stack.pop()
            try:
                listing = os.scandir(directory)
            except OSError:
                try:
                    listing = os.scandir(long_path(directory))
                except OSError:
                    continue
            with listing:
                for entry in listing:
                    try:
                        if entry.is_dir(follow_symlinks=False):
                            stack.append(entry.path)
                        elif entry.is_file(follow_symlinks=False) and entry.stat().st_mtime < cutoff_epoch:
                            yield Path(yieldable_path(entry.path))
                    except OSError:
                        continue

    return _walk()


def iter_evidence_candidates(root: Path, cutoff_epoch: float,
                             open_ids: set[str], open_paths: set[Path]) -> Iterable[Path]:
    for path in iter_old_files(root, cutoff_epoch):
        try:
            if is_open_bound(path, open_ids, open_paths):
                continue
            attributes = file_attributes(path)
        except OSError:
            # Unreadable by name (MAX_PATH / transient lock): leave untouched,
            # exactly like an unlistable directory; never abort the run.
            continue
        if attributes & (COMPRESSED_ATTRIBUTE | REPARSE_ATTRIBUTE):
            continue
        yield path


def safe_delete_batch(paths: list[Path], root: Path, receipt_dir: Path,
                      run_id: str, action: str, apply: bool,
                      skip_locked: bool = False) -> dict[str, Any]:
    entries = []
    for path in paths:
        resolved = path.resolve()
        if resolved.parent != root.resolve() and not is_under(resolved, root):
            raise RuntimeError(f"delete target escaped root: {resolved}")
        stat = resolved.stat()
        if file_attributes(resolved) & REPARSE_ATTRIBUTE:
            continue
        entry = {"path": str(resolved), "name": resolved.name,
                 "bytes": stat.st_size, "mtime_ns": stat.st_mtime_ns}
        if action == "BACKUP_DELETE":
            # The receipt is written before any move/unlink, so this is the
            # authoritative pre-delete content identity.
            entry["sha256"] = sha256_file(resolved)
        entries.append(entry)
    receipt_path = receipt_dir / f"{run_id}_{action.lower()}.json"
    receipt = {"schema": SCHEMA, "authority": AUTHORITY, "run_id": run_id,
               "action": action, "mode": "APPLY" if apply else "DRY_RUN",
               "requested_files": len(entries),
               "requested_bytes": sum(row["bytes"] for row in entries),
               "deleted_files": 0, "deleted_bytes": 0,
               "skipped_files": 0, "skipped_bytes": 0,
               "archive_list": str(receipt_path) if action == "BACKUP_DELETE" else None,
               "skip_reasons": {}, "skipped": [], "entries": entries}
    atomic_json(receipt_path, receipt)
    if apply and entries:
        quarantine = root / f".continuous_retention_quarantine_{run_id}_{action.lower()}"
        quarantine.mkdir(parents=False, exist_ok=False)
        for index, row in enumerate(entries):
            source = Path(row["path"])
            target = quarantine / f"{index:05d}_{source.name}"
            if skip_locked and os.name == "nt":
                kernel32, handle = open_exclusive_windows_handle(source)
                if handle == ctypes.c_void_p(-1).value:
                    error = ctypes.get_last_error()
                    if error == 32:
                        skipped = {"path": str(source), "bytes": row["bytes"],
                                   "status": "SKIPPED_LOCKED", "winerror": error}
                        receipt["skipped"].append(skipped)
                        receipt["skipped_files"] += 1
                        receipt["skipped_bytes"] += row["bytes"]
                        receipt["skip_reasons"]["SKIPPED_LOCKED"] = (
                            receipt["skip_reasons"].get("SKIPPED_LOCKED", 0) + 1
                        )
                        continue
                    raise OSError(error, f"exclusive-open failed for delete candidate: {source}")
                kernel32.CloseHandle(ctypes.c_void_p(handle))
            try:
                os.replace(source, target)
            except PermissionError as exc:
                if not skip_locked or getattr(exc, "winerror", None) != 32:
                    raise
                skipped = {"path": str(source), "bytes": row["bytes"],
                           "status": "SKIPPED_LOCKED", "winerror": 32}
                receipt["skipped"].append(skipped)
                receipt["skipped_files"] += 1
                receipt["skipped_bytes"] += row["bytes"]
                receipt["skip_reasons"]["SKIPPED_LOCKED"] = (
                    receipt["skip_reasons"].get("SKIPPED_LOCKED", 0) + 1
                )
                continue
            if target.stat().st_size != row["bytes"]:
                raise RuntimeError(f"quarantine size mismatch: {source}")
            target.unlink()
            receipt["deleted_files"] += 1
            receipt["deleted_bytes"] += row["bytes"]
        quarantine.rmdir()
        receipt["completed_at"] = utc_now().replace(microsecond=0).isoformat()
        atomic_json(receipt_path, receipt)
    return {key: value for key, value in receipt.items() if key != "entries"}


def rotate_large_logs(root: Path, open_ids: set[str], open_paths: set[Path],
                      now: dt.datetime, apply: bool, threshold: int) -> list[dict[str, Any]]:
    results = []
    for path in root.glob("*.log"):
        if not path.is_file() or path.stat().st_size < threshold or is_open_bound(path, open_ids, open_paths):
            continue
        size = path.stat().st_size
        rotated = path.with_name(f"{path.name}.{now.strftime('%Y%m%dT%H%M%SZ')}")
        status = "PLANNED"
        if apply:
            if os.name != "nt":
                status = "HELD_NON_WINDOWS"
            else:
                kernel32, handle = open_exclusive_windows_handle(path)
                if handle == ctypes.c_void_p(-1).value:
                    status = "HELD_ACTIVE"
                else:
                    kernel32.CloseHandle(ctypes.c_void_p(handle))
                    os.replace(path, rotated)
                    path.touch()
                    status = "ROTATED"
        results.append({"path": str(path), "rotated_path": str(rotated),
                        "bytes": size,
                        "status": status})
    return results


def journal_archive_plan(db_path: Path, cutoff: dt.datetime) -> dict[str, Any]:
    """Measure the bounded old-events cohort without mutating the database."""
    uri = db_path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=15)
    try:
        row = connection.execute(
            "SELECT count(*), min(id), max(id), "
            "coalesce(sum(length(coalesce(detail_json,''))),0) "
            "FROM events WHERE ts < ?",
            (cutoff.isoformat(),),
        ).fetchone()
        return {
            "table": "events",
            "cutoff_utc": cutoff.isoformat(),
            "rows": int(row[0]),
            "min_id": row[1],
            "max_id": row[2],
            "logical_detail_bytes": int(row[3]),
        }
    finally:
        connection.close()


def _busy_work_items(connection: sqlite3.Connection) -> int:
    placeholders = ",".join("?" for _ in BUSY_STATUSES)
    return int(connection.execute(
        f"SELECT count(*) FROM work_items WHERE lower(status) IN ({placeholders})",
        tuple(sorted(BUSY_STATUSES)),
    ).fetchone()[0])


def archive_state_journals(
    db_path: Path,
    archive_root: Path,
    factory_lock: Path,
    cutoff: dt.datetime,
) -> dict[str, Any]:
    """Archive/delete old events and VACUUM only under a verified quiet lock."""
    plan = journal_archive_plan(db_path, cutoff)
    if not plan["rows"]:
        return {**plan, "status": "NOOP_EMPTY"}
    archive_root.mkdir(parents=True, exist_ok=True)
    target = archive_root / f"events_through_{cutoff.strftime('%Y%m%dT%H%M%SZ')}_id{plan['max_id']}.jsonl"
    manifest = target.with_suffix(".manifest.json")
    if target.exists() or manifest.exists():
        raise RuntimeError(f"append-only archive target already exists: {target}")

    with FactoryMutationLock(factory_lock, owner="continuous_retention:events_archive_vacuum"):
        connection = sqlite3.connect(str(db_path), timeout=30)
        temporary = target.with_name(f".{target.name}.{uuid.uuid4().hex}.tmp")
        try:
            if _busy_work_items(connection):
                raise RuntimeError("journal archive refused: work-item fleet is not quiet")
            rows = connection.execute(
                "SELECT id,ts,entity_type,entity_id,event,detail_json FROM events "
                "WHERE id <= ? AND ts < ? ORDER BY id",
                (plan["max_id"], cutoff.isoformat()),
            )
            digest = hashlib.sha256()
            exported = 0
            with temporary.open("xb") as handle:
                for row in rows:
                    encoded = (json.dumps({
                        "id": row[0], "ts": row[1], "entity_type": row[2],
                        "entity_id": row[3], "event": row[4], "detail_json": row[5],
                    }, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
                    handle.write(encoded)
                    digest.update(encoded)
                    exported += 1
                handle.flush()
                os.fsync(handle.fileno())
            if exported != plan["rows"]:
                raise RuntimeError(f"archive row-count mismatch: {exported} != {plan['rows']}")
            os.replace(temporary, target)
            archive_sha = digest.hexdigest()
            prepared = {**plan, "schema": "qm.state-journal-archive/v1", "status": "PREPARED",
                        "archive_path": str(target), "archive_sha256": archive_sha,
                        "exported_rows": exported}
            atomic_json(manifest, prepared)

            connection.execute("BEGIN IMMEDIATE")
            if _busy_work_items(connection):
                connection.rollback()
                raise RuntimeError("journal archive refused: quiet window closed before delete")
            before = connection.total_changes
            connection.execute(
                "DELETE FROM events WHERE id <= ? AND ts < ?",
                (plan["max_id"], cutoff.isoformat()),
            )
            deleted = connection.total_changes - before
            if deleted != exported:
                connection.rollback()
                raise RuntimeError(f"delete row-count mismatch: {deleted} != {exported}")
            connection.commit()
            connection.execute("VACUUM")
            qc = connection.execute("PRAGMA quick_check").fetchone()[0]
            if qc != "ok":
                raise RuntimeError(f"post-vacuum quick_check failed: {qc}")
            completed = {**prepared, "status": "PASS", "deleted_rows": deleted,
                         "post_vacuum_quick_check": qc}
            atomic_json(manifest, completed)
            return completed
        finally:
            connection.close()
            if temporary.exists():
                temporary.unlink()


def run(args: argparse.Namespace) -> dict[str, Any]:
    now = utc_now()
    run_id = now.strftime("%Y%m%dT%H%M%SZ")
    free_before = shutil.disk_usage(args.drive_root).free
    summary: dict[str, Any] = {"schema": SCHEMA, "authority": AUTHORITY,
        "run_id": run_id, "mode": "APPLY" if args.apply else "DRY_RUN",
        "free_before": free_before, "noop_free_threshold_bytes": args.noop_free_bytes}
    if free_before >= args.noop_free_bytes:
        summary.update({"status": "NOOP_FREE_SPACE", "free_after": free_before})
        return summary
    qc = quick_check(args.db)
    if qc != "ok":
        raise RuntimeError(f"live DB quick_check failed: {qc}")
    open_ids, open_paths = open_bindings(args.db)
    governed_retention = getattr(args, "governed_state_retention", False)
    referenced_backups = (
        open_backup_references(args.db, args.backups_root) if governed_retention else set()
    )
    retention = (
        backup_retention_plan(
            args.backups_root, now, referenced_backups,
            cap_bytes=getattr(args, "backup_cap_bytes", BACKUP_CAP_BYTES),
        )
        if governed_retention else legacy_backup_retention_plan(args.backups_root, now)
    )
    keep_backups = list(retention["keep"])
    old_backups = list(retention["delete"])
    retention_report = serializable_backup_plan(retention)
    receipt_dir = args.receipt_root / run_id
    receipt_dir.mkdir(parents=True, exist_ok=True)
    if getattr(args, "retention_plan_only", False):
        journal_archive = None
        if getattr(args, "archive_state_journals", False):
            cutoff = now - dt.timedelta(days=getattr(args, "journal_keep_days", 30.0))
            journal_archive = {**journal_archive_plan(args.db, cutoff), "status": "DRY_RUN"}
        summary.update({
            "status": "PASS_PLAN_ONLY", "db_quick_check": qc,
            "open_work_item_count": len(open_ids),
            "referenced_backup_count": len(referenced_backups),
            "retained_backup_count": len(keep_backups),
            "backup_retention": retention_report,
            "journal_archive": journal_archive,
            "free_after": shutil.disk_usage(args.drive_root).free,
            "completed_at": utc_now().replace(microsecond=0).isoformat(),
        })
        atomic_json(receipt_dir / "run_summary.json", summary)
        return summary
    compressed = []
    for path in keep_backups:
        status, before, after = set_ntfs_compression(path) if args.apply else ("PLANNED", path.stat().st_size, path.stat().st_size)
        compressed.append({"path": str(path), "status": status, "bytes": before, "bytes_after": after})
    evidence = []
    cutoff = now.timestamp() - args.evidence_age_hours * 3600
    for path in iter_evidence_candidates(args.work_items_root, cutoff, open_ids, open_paths):
        status, before, after = set_ntfs_compression(path) if args.apply else ("PLANNED", path.stat().st_size, path.stat().st_size)
        evidence.append({"path": str(path), "status": status, "bytes": before, "bytes_after": after})
        if len(evidence) >= args.max_evidence_files:
            break
    rotation = rotate_large_logs(args.logs_root, open_ids, open_paths, now, args.apply, args.rotate_bytes)
    log_cutoff = now.timestamp() - args.log_keep_hours * 3600
    old_logs = [p for p in iter_old_files(args.logs_root, log_cutoff)
                if not is_open_bound(p, open_ids, open_paths)
                and ".continuous_retention_quarantine_" not in str(p)]
    backup_delete = safe_delete_batch(old_backups, args.backups_root, receipt_dir, run_id,
                                      "BACKUP_DELETE", args.apply)
    log_delete = safe_delete_batch(old_logs, args.logs_root, receipt_dir, run_id,
                                   "LOG_DELETE", args.apply, skip_locked=True)
    journal_archive = None
    if getattr(args, "archive_state_journals", False):
        cutoff = now - dt.timedelta(days=getattr(args, "journal_keep_days", 30.0))
        journal_archive = (
            archive_state_journals(
                args.db,
                getattr(args, "archive_root", DEFAULT_ARCHIVE_ROOT),
                getattr(args, "factory_lock", DEFAULT_FACTORY_LOCK),
                cutoff,
            )
            if args.apply else {**journal_archive_plan(args.db, cutoff), "status": "DRY_RUN"}
        )
    summary.update({"status": "PASS", "db_quick_check": qc,
        "open_work_item_count": len(open_ids), "retained_backup_count": len(keep_backups),
        "referenced_backup_count": len(referenced_backups),
        "backup_retention": retention_report,
        "backup_compression": compressed, "evidence_compression": evidence,
        "log_rotation": rotation, "backup_delete": backup_delete,
        "log_delete": log_delete, "journal_archive": journal_archive,
        "free_after": shutil.disk_usage(args.drive_root).free,
        "completed_at": utc_now().replace(microsecond=0).isoformat()})
    atomic_json(receipt_dir / "run_summary.json", summary)
    return summary


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--apply", action="store_true")
    result.add_argument("--db", type=Path, default=DEFAULT_DB)
    result.add_argument("--backups-root", type=Path, default=DEFAULT_BACKUPS)
    result.add_argument("--work-items-root", type=Path, default=DEFAULT_WORK_ITEMS)
    result.add_argument("--logs-root", type=Path, default=DEFAULT_LOGS)
    result.add_argument("--receipt-root", type=Path, default=DEFAULT_RECEIPTS)
    result.add_argument("--telemetry", type=Path, default=DEFAULT_TELEMETRY)
    result.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    result.add_argument("--drive-root", type=Path, default=Path("D:/"))
    result.add_argument("--noop-free-bytes", type=int, default=150 * 1024**3)
    result.add_argument("--evidence-age-hours", type=float, default=2.0)
    result.add_argument("--log-keep-hours", type=float, default=48.0)
    result.add_argument("--rotate-bytes", type=int, default=64 * 1024**2)
    result.add_argument("--max-evidence-files", type=int, default=5000)
    result.add_argument("--backup-cap-bytes", type=int, default=BACKUP_CAP_BYTES)
    result.add_argument("--governed-state-retention", action="store_true",
                        help="Default-OFF: newest-8/48h/open-receipt/10-GiB backup policy")
    result.add_argument("--archive-state-journals", action="store_true",
                        help="Default-OFF: archive/delete old events and VACUUM in a quiet window")
    result.add_argument("--journal-keep-days", type=float, default=30.0)
    result.add_argument("--archive-root", type=Path, default=DEFAULT_ARCHIVE_ROOT)
    result.add_argument("--factory-lock", type=Path, default=DEFAULT_FACTORY_LOCK)
    result.add_argument("--retention-plan-only", action="store_true",
                        help="Write the reasoned dry-run plan without hashing or touching candidates")
    return result


def main() -> int:
    args = parser().parse_args()
    with exclusive_runner_lock(args.lock) as acquired:
        if not acquired:
            print(json.dumps({"schema": SCHEMA, "status": "NOOP_LOCKED"}))
            return 0
        try:
            summary = run(args)
        except Exception as exc:
            failure = {"schema": SCHEMA, "authority": AUTHORITY, "status": "FAIL_CLOSED",
                       "error": f"{type(exc).__name__}: {exc}",
                       "timestamp": utc_now().replace(microsecond=0).isoformat()}
            append_jsonl(args.telemetry, failure)
            print(json.dumps(failure, indent=2, sort_keys=True))
            return 1
        compact = telemetry_record(summary)
        append_jsonl(args.telemetry, compact)
        print(json.dumps(compact, indent=2, sort_keys=True))
        return 0


if __name__ == "__main__":
    sys.exit(main())
