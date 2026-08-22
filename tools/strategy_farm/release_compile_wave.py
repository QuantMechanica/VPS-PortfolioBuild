#!/usr/bin/env python3
"""Release a bounded, source-fresh COMPILE_EA rollout wave.

This utility only deactivates the activation hold.  It does not claim or run
work: resident terminal workers continue to use the canonical selector,
terminal lease, ownership CAS, and compile evidence machinery.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import uuid
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
HOLD_CODE = "COMPILE_EA_WORKER_ROLLOUT_PENDING"


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _connect(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def inspect(
    db: Path,
    repo: Path,
    max_items: int,
    work_item_id: str | None = None,
) -> dict[str, Any]:
    if max_items < 1 or max_items > 10:
        raise ValueError("--max-items must be between 1 and 10")
    with _connect(db) as conn:
        rows = conn.execute(
            """
            SELECT w.id,w.ea_id,w.status,w.claimed_by,w.verdict,w.payload_json,
                   h.hold_code,h.active,h.release_on_restart,h.created_at
            FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
            WHERE w.phase='COMPILE_EA' AND w.status='pending'
              AND w.claimed_by IS NULL AND h.active=1 AND h.hold_code=?
              AND (? IS NULL OR w.id=?)
            ORDER BY w.created_at,w.id
            """,
            (HOLD_CODE, work_item_id, work_item_id),
        ).fetchall()

    eligible: list[dict[str, Any]] = []
    deferred: list[dict[str, Any]] = []
    for row in rows:
        payload = json.loads(row["payload_json"] or "{}")
        label = str(payload.get("ea_label") or "").strip()
        source = repo / "framework" / "EAs" / label / f"{label}.mq5"
        expected_sha = str(payload.get("mq5_sha256") or "").lower()
        actual_sha = sha256_file(source).lower() if source.is_file() else None
        item = {
            "work_item_id": row["id"],
            "ea_id": row["ea_id"],
            "ea_label": label,
            "source_path": str(source),
            "expected_mq5_sha256": expected_sha or None,
            "actual_mq5_sha256": actual_sha,
        }
        if not label or not expected_sha or actual_sha != expected_sha:
            item["reason"] = "SOURCE_SHA_STALE_OR_MISSING"
            deferred.append(item)
        elif len(eligible) < max_items:
            eligible.append(item)
        else:
            item["reason"] = "LATER_WAVE"
            deferred.append(item)
    return {
        "schema_version": "qm.compile-ea-rollout-wave/v1",
        "mode": "dry_run",
        "max_items": max_items,
        "work_item_id_selector": work_item_id,
        "held_pending_count": len(rows),
        "release_count": len(eligible),
        "release": eligible,
        "deferred": deferred,
    }


def _backup(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    target = backup_dir / f"farm_state_before_compile_wave_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    source_conn = sqlite3.connect(db, timeout=30)
    target_conn = sqlite3.connect(target)
    try:
        source_conn.backup(target_conn)
    finally:
        target_conn.close()
        source_conn.close()
    return target, sha256_file(target)


def apply_wave(
    db: Path,
    repo: Path,
    backup_dir: Path,
    max_items: int,
    note: str,
    work_item_id: str | None = None,
) -> dict[str, Any]:
    plan = inspect(db, repo, max_items, work_item_id)
    if not plan["release"]:
        return {**plan, "mode": "apply", "applied": 0, "backup": None}
    backup_path, backup_sha = _backup(db, backup_dir)
    now = utc_now()
    applied: list[str] = []
    with _connect(db) as conn:
        conn.execute("BEGIN IMMEDIATE")
        try:
            for item in plan["release"]:
                row = conn.execute(
                    """SELECT w.status,w.claimed_by,w.payload_json,h.hold_code,h.active
                       FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
                       WHERE w.id=?""",
                    (item["work_item_id"],),
                ).fetchone()
                if row is None or row["status"] != "pending" or row["claimed_by"] is not None:
                    raise RuntimeError(f"work item changed before release: {item['work_item_id']}")
                if row["hold_code"] != HOLD_CODE or int(row["active"]) != 1:
                    raise RuntimeError(f"activation hold changed before release: {item['work_item_id']}")
                payload = json.loads(row["payload_json"] or "{}")
                label = str(payload.get("ea_label") or "")
                source = repo / "framework" / "EAs" / label / f"{label}.mq5"
                if not source.is_file() or sha256_file(source).lower() != str(payload.get("mq5_sha256") or "").lower():
                    raise RuntimeError(f"source SHA changed before release: {item['work_item_id']}")
                cursor = conn.execute(
                    """UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
                       WHERE work_item_id=? AND hold_code=? AND active=1""",
                    (now, now, note, item["work_item_id"], HOLD_CODE),
                )
                if cursor.rowcount != 1:
                    raise RuntimeError(f"hold release CAS failed: {item['work_item_id']}")
                key = f"compile-rollout:{item['work_item_id']}:{row['hold_code']}"
                conn.execute(
                    """INSERT INTO work_item_transition_ledger
                       (idempotency_key,ts,work_item_id,action,reason,run_id,detail_json)
                       VALUES(?,?,?,'release_hold',?,'compile_ea_rollout',?)""",
                    (
                        key,
                        now,
                        item["work_item_id"],
                        note,
                        json.dumps(
                            {"max_items": max_items, "work_item_id_selector": work_item_id},
                            sort_keys=True,
                        ),
                    ),
                )
                conn.execute(
                    """INSERT INTO events(ts,entity_type,entity_id,event,detail_json)
                       VALUES(?,'work_item',?,'compile_rollout_hold_released',?)""",
                    (
                        now,
                        item["work_item_id"],
                        json.dumps(
                            {"release_note": note, "work_item_id_selector": work_item_id},
                            sort_keys=True,
                        ),
                    ),
                )
                applied.append(item["work_item_id"])
            conn.commit()
        except Exception:
            conn.rollback()
            raise
    return {
        **plan,
        "mode": "apply",
        "applied": len(applied),
        "applied_work_item_ids": applied,
        "released_at": now,
        "backup": {"path": str(backup_path), "sha256": backup_sha},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--max-items", type=int, default=1)
    parser.add_argument(
        "--work-item-id",
        help="release only this exact held pending work item (still via the normal worker path)",
    )
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--release-note", default="bounded COMPILE_EA worker rollout wave")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = (
        apply_wave(
            args.db,
            args.repo,
            args.backup_dir,
            args.max_items,
            args.release_note,
            args.work_item_id,
        )
        if args.apply
        else inspect(args.db, args.repo, args.max_items, args.work_item_id)
    )
    encoded = json.dumps(result, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temp = args.output.with_name(f".{args.output.name}.{uuid.uuid4().hex}.tmp")
        temp.write_text(encoded + "\n", encoding="utf-8")
        temp.replace(args.output)
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
