#!/usr/bin/env python3
"""Shared rolling-window SQLite backup reuse for governed state writers.

Reuse is deliberately limited to one database path/schema generation and a
bounded age window.  When identity cannot be established, no sidecar matches,
or reuse is disabled, callers receive a fresh online SQLite backup.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sqlite3
import time
import uuid
from pathlib import Path
from typing import Any, Callable


DEFAULT_REUSE_MAX_AGE_MINUTES = 60.0
DEFAULT_TOOL_BACKUP_KEEP = 3


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def backup(
    db: Path,
    backup_dir: Path,
    *,
    timeout_seconds: float = 60.0,
    backup_label: str = "governed_tool",
) -> tuple[Path, str]:
    if timeout_seconds <= 0:
        raise ValueError("backup timeout must be positive")
    if not re.fullmatch(r"[a-z0-9_]+", backup_label):
        raise ValueError(f"unsupported tool backup label: {backup_label}")
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    target = backup_dir / (
        f"farm_state_before_{backup_label}_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    partial = target.with_suffix(target.suffix + ".partial")
    source_conn = sqlite3.connect(db, timeout=30)
    target_conn = sqlite3.connect(partial)
    started = time.monotonic()

    def progress(_status: int, remaining: int, total: int) -> None:
        elapsed = time.monotonic() - started
        if elapsed > timeout_seconds:
            raise TimeoutError(
                "GOVERNED_STATE_BACKUP_TIMEOUT:"
                f"elapsed_seconds={elapsed:.3f}:remaining_pages={remaining}:"
                f"total_pages={total}"
            )

    try:
        source_conn.backup(target_conn, pages=256, progress=progress, sleep=0.05)
        target_conn.close()
        source_conn.close()
        partial.replace(target)
    except BaseException:
        target_conn.close()
        source_conn.close()
        try:
            partial.unlink(missing_ok=True)
        except OSError:
            pass
        raise
    finally:
        try:
            target_conn.close()
        finally:
            source_conn.close()
    return target, sha256_file(target)


def identity_sidecar_path(backup_path: Path) -> Path:
    return backup_path.with_name(backup_path.name + ".identity.json")


def db_identity(conn: sqlite3.Connection, db: Path) -> dict[str, Any] | None:
    """Return the exact cheap identity required for backup reuse."""
    try:
        stat = db.stat()
        wal_path = Path(str(db) + "-wal")
        wal_size = wal_path.stat().st_size if wal_path.is_file() else 0
        schema_version = int(conn.execute("PRAGMA schema_version").fetchone()[0])
    except (OSError, sqlite3.Error, TypeError, IndexError):
        return None
    return {
        "source_path": str(db.resolve()),
        "schema_version": schema_version,
        "source_mtime_ns": stat.st_mtime_ns,
        "source_size": stat.st_size,
        "source_wal_size": wal_size,
    }


def identities_match(a: dict[str, Any], b: dict[str, Any]) -> bool:
    return (
        a.get("source_path") == b.get("source_path")
        and a.get("schema_version") == b.get("schema_version")
        and a.get("source_mtime_ns") == b.get("source_mtime_ns")
        and a.get("source_size") == b.get("source_size")
        and a.get("source_wal_size") == b.get("source_wal_size")
    )


def cap_tool_backup_class(
    backup_dir: Path,
    backup_label: str,
    *,
    keep: int = DEFAULT_TOOL_BACKUP_KEEP,
) -> str | None:
    """Keep the newest N backups for one label and receipt exact deletions."""
    if keep < 1:
        raise ValueError("tool backup keep count must be positive")
    root = backup_dir.resolve()
    candidates = sorted(
        backup_dir.glob(f"farm_state_before_{backup_label}_*.sqlite"),
        key=lambda path: (path.stat().st_mtime_ns, path.name),
        reverse=True,
    )
    deleted: list[dict[str, Any]] = []
    for path in candidates[keep:]:
        resolved = path.resolve()
        if resolved.parent != root:
            raise RuntimeError(f"tool backup cap target escaped backup dir: {resolved}")
        size = path.stat().st_size
        sidecar = identity_sidecar_path(path)
        path.unlink()
        sidecar_deleted = False
        if sidecar.is_file() and sidecar.resolve().parent == root:
            sidecar.unlink()
            sidecar_deleted = True
        deleted.append(
            {"path": str(path), "bytes": size, "sidecar_deleted": sidecar_deleted}
        )
    if not deleted:
        return None
    receipt_dir = backup_dir / "receipts"
    receipt_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%S_%fZ")
    receipt = receipt_dir / f"tool_backup_cap_{backup_label}_{stamp}.json"
    payload = {
        "schema": "qm.tool-backup-cap/v1",
        "backup_label": backup_label,
        "keep": keep,
        "deleted": deleted,
        "deleted_bytes": sum(item["bytes"] for item in deleted),
        "created_at": utc_now(),
    }
    receipt.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return str(receipt)


def write_identity_sidecar(
    backup_path: Path,
    identity: dict[str, Any],
    backup_sha: str,
) -> None:
    sidecar = identity_sidecar_path(backup_path)
    payload = {
        **identity,
        "backup_path": str(backup_path),
        "backup_sha256": backup_sha,
        "created_at": utc_now(),
    }
    temp = sidecar.with_name(f".{sidecar.name}.{uuid.uuid4().hex}.tmp")
    temp.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    temp.replace(sidecar)


def find_reusable_backup(
    backup_dir: Path,
    live_identity: dict[str, Any],
    max_age_minutes: float,
) -> tuple[Path, str, Path] | None:
    if max_age_minutes <= 0 or not backup_dir.is_dir():
        return None
    cutoff = time.time() - (max_age_minutes * 60.0)
    candidates: list[tuple[float, Path]] = []
    for sidecar in backup_dir.glob("*.identity.json"):
        try:
            mtime = sidecar.stat().st_mtime
        except OSError:
            continue
        if mtime >= cutoff:
            candidates.append((mtime, sidecar))
    candidates.sort(key=lambda pair: pair[0], reverse=True)
    for _, sidecar in candidates:
        try:
            data = json.loads(sidecar.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict) or not identities_match(data, live_identity):
            continue
        backup_path_raw = data.get("backup_path")
        backup_sha = data.get("backup_sha256")
        if not backup_path_raw or not backup_sha:
            continue
        backup_path = Path(backup_path_raw)
        if backup_path.is_file():
            return backup_path, str(backup_sha), sidecar
    return None


def resolve_backup(
    conn: sqlite3.Connection,
    db: Path,
    backup_dir: Path,
    *,
    timeout_seconds: float = 60.0,
    reuse_max_age_minutes: float = DEFAULT_REUSE_MAX_AGE_MINUTES,
    backup_label: str = "governed_tool",
    backup_func: Callable[..., tuple[Path, str]] = backup,
    cap_func: Callable[..., str | None] = cap_tool_backup_class,
) -> dict[str, Any]:
    """Reuse a fresh identity sidecar or fail closed to a fresh backup."""
    live_identity = db_identity(conn, db)
    if live_identity is not None and reuse_max_age_minutes > 0:
        reusable = find_reusable_backup(
            backup_dir, live_identity, reuse_max_age_minutes
        )
        if reusable is not None:
            backup_path, backup_sha, sidecar_path = reusable
            return {
                "path": backup_path,
                "sha256": backup_sha,
                "reused": True,
                "reused_from_sidecar": str(sidecar_path),
                "identity": live_identity,
                "identity_established": True,
                "cap_receipt": cap_func(backup_dir, backup_label),
            }

    backup_path, backup_sha = backup_func(
        db,
        backup_dir,
        timeout_seconds=timeout_seconds,
        backup_label=backup_label,
    )
    identity_for_sidecar = live_identity if live_identity is not None else db_identity(conn, db)
    if identity_for_sidecar is not None:
        try:
            write_identity_sidecar(backup_path, identity_for_sidecar, backup_sha)
        except OSError:
            pass
    return {
        "path": backup_path,
        "sha256": backup_sha,
        "reused": False,
        "reused_from_sidecar": None,
        "identity": identity_for_sidecar,
        "identity_established": identity_for_sidecar is not None,
        "cap_receipt": cap_func(backup_dir, backup_label),
    }
