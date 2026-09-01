"""Continuous low-space retention under OWNER-DEC-BACKUP-RETENTION-20260830.

The runner is fail-closed and single-pass.  It is normally invoked every 45
minutes by Windows Task Scheduler.  Above the free-space watermark it records
a no-op.  Below the watermark it:

* validates the live farm DB with PRAGMA quick_check before backup deletion;
* retains the union of the newest ten backups and the trailing fourteen days,
  NTFS-compresses retained backups, and removes older backups in byte-receipted
  batches;
* NTFS-compresses work-item evidence older than two hours, excluding every
  open work-item directory/path;
* rotates large exclusively-openable logs and deletes logs older than 48 hours,
  excluding log paths bound to open work items.

No database row, verdict, ledger, terminal, T_Live, or AutoTrading state is
modified.  ``--apply`` is required for filesystem mutation.
"""
from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import json
import msvcrt
import os
import shutil
import sqlite3
import sys
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterable


AUTHORITY = "OWNER-DEC-BACKUP-RETENTION-20260830"
SCHEMA = "qm.continuous-retention/v1"
DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_BACKUPS = Path("D:/QM/strategy_farm/state/backups")
DEFAULT_WORK_ITEMS = Path("D:/QM/reports/work_items")
DEFAULT_LOGS = Path("D:/QM/strategy_farm/logs")
DEFAULT_RECEIPTS = Path("D:/QM/reports/state/continuous_retention")
DEFAULT_TELEMETRY = Path("D:/QM/reports/state/backup_retention_continuous.jsonl")
DEFAULT_LOCK = Path("D:/QM/strategy_farm/state/locks/continuous_retention.lock")
OPEN_STATUSES = {"pending", "active", "claimed", "in_progress"}
COMPRESSED_ATTRIBUTE = 0x00000800
REPARSE_ATTRIBUTE = 0x00000400


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
              if key not in {"backup_compression", "evidence_compression", "log_rotation"}}
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


def backup_plan(root: Path, now: dt.datetime) -> tuple[list[Path], list[Path]]:
    files = sorted((p for p in root.glob("*.sqlite") if p.is_file()),
                   key=lambda p: (p.stat().st_mtime_ns, p.name), reverse=True)
    cutoff = now.timestamp() - 14 * 86400
    keep = [p for index, p in enumerate(files) if index < 10 or p.stat().st_mtime >= cutoff]
    delete = [p for p in files if p not in set(keep)]
    return keep, delete


def iter_old_files(root: Path, cutoff_epoch: float) -> Iterable[Path]:
    if not root.is_dir():
        return []
    return (p for p in root.rglob("*") if p.is_file() and p.stat().st_mtime < cutoff_epoch)


def safe_delete_batch(paths: list[Path], root: Path, receipt_dir: Path,
                      run_id: str, action: str, apply: bool) -> dict[str, Any]:
    entries = []
    for path in paths:
        resolved = path.resolve()
        if resolved.parent != root.resolve() and not is_under(resolved, root):
            raise RuntimeError(f"delete target escaped root: {resolved}")
        stat = resolved.stat()
        if file_attributes(resolved) & REPARSE_ATTRIBUTE:
            continue
        entries.append({"path": str(resolved), "bytes": stat.st_size, "mtime_ns": stat.st_mtime_ns})
    receipt = {"schema": SCHEMA, "authority": AUTHORITY, "run_id": run_id,
               "action": action, "mode": "APPLY" if apply else "DRY_RUN",
               "requested_files": len(entries),
               "requested_bytes": sum(row["bytes"] for row in entries),
               "deleted_files": 0, "deleted_bytes": 0, "entries": entries}
    receipt_path = receipt_dir / f"{run_id}_{action.lower()}.json"
    atomic_json(receipt_path, receipt)
    if apply and entries:
        quarantine = root / f".continuous_retention_quarantine_{run_id}_{action.lower()}"
        quarantine.mkdir(parents=False, exist_ok=False)
        for index, row in enumerate(entries):
            source = Path(row["path"])
            target = quarantine / f"{index:05d}_{source.name}"
            os.replace(source, target)
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
    keep_backups, old_backups = backup_plan(args.backups_root, now)
    receipt_dir = args.receipt_root / run_id
    receipt_dir.mkdir(parents=True, exist_ok=True)
    compressed = []
    for path in keep_backups:
        status, before, after = set_ntfs_compression(path) if args.apply else ("PLANNED", path.stat().st_size, path.stat().st_size)
        compressed.append({"path": str(path), "status": status, "bytes": before, "bytes_after": after})
    evidence = []
    cutoff = now.timestamp() - args.evidence_age_hours * 3600
    for path in iter_old_files(args.work_items_root, cutoff):
        if is_open_bound(path, open_ids, open_paths):
            continue
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
                                   "LOG_DELETE", args.apply)
    summary.update({"status": "PASS", "db_quick_check": qc,
        "open_work_item_count": len(open_ids), "retained_backup_count": len(keep_backups),
        "backup_compression": compressed, "evidence_compression": evidence,
        "log_rotation": rotation, "backup_delete": backup_delete,
        "log_delete": log_delete, "free_after": shutil.disk_usage(args.drive_root).free,
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
