#!/usr/bin/env python3
"""Plan or apply exact, durable holds to pending Strategy Farm work items.

This is the operator-facing path for parking known unsafe rows while the
factory remains running.  It never changes ``work_items.status``.  Apply mode
takes a SQLite backup, acquires ``BEGIN IMMEDIATE``, revalidates every exact
``id=symbol`` target, inserts non-restart holds, emits audit events, commits,
and reads back that none of the rows remain claimable.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Sequence


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
HOLD_CODE_RE = re.compile(r"^[A-Z][A-Z0-9_]{2,127}$")


class HoldError(RuntimeError):
    """Fail-closed hold planning or application error."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_targets(values: Sequence[str]) -> list[tuple[str, str]]:
    targets: list[tuple[str, str]] = []
    seen: set[str] = set()
    for value in values:
        work_item_id, separator, symbol = value.partition("=")
        work_item_id, symbol = work_item_id.strip(), symbol.strip()
        if not separator or not work_item_id or not symbol:
            raise HoldError(f"invalid_target:{value!r}:expected WORK_ITEM_ID=SYMBOL")
        if work_item_id in seen:
            raise HoldError(f"duplicate_target:{work_item_id}")
        targets.append((work_item_id, symbol))
        seen.add(work_item_id)
    if not targets:
        raise HoldError("no_targets")
    return targets


def ensure_schema(conn: sqlite3.Connection) -> None:
    required = {
        "work_items": {"id", "ea_id", "symbol", "phase", "status", "verdict", "claimed_by"},
        "work_item_holds": {
            "work_item_id", "hold_code", "reason", "active", "release_on_restart",
            "created_at", "updated_at", "released_at", "release_note",
        },
        "events": {"ts", "entity_type", "entity_id", "event", "detail_json"},
    }
    for table, columns in required.items():
        actual = {str(row[1]) for row in conn.execute(f"PRAGMA table_info({table})")}
        missing = sorted(columns - actual)
        if missing:
            raise HoldError(f"schema_missing:{table}:{','.join(missing)}")


def _claimable(conn: sqlite3.Connection, work_item_id: str) -> bool:
    row = conn.execute(
        """
        SELECT EXISTS(
          SELECT 1 FROM work_items w
          WHERE w.id=? AND w.status='pending' AND w.claimed_by IS NULL
            AND NOT EXISTS(
              SELECT 1 FROM work_item_holds h
              WHERE h.work_item_id=w.id AND h.active=1
            )
        )
        """,
        (work_item_id,),
    ).fetchone()
    return bool(row[0])


def inspect_targets(
    conn: sqlite3.Connection,
    targets: Sequence[tuple[str, str]],
    *,
    ea_id: str,
    phase: str,
    hold_code: str,
    reason: str,
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for work_item_id, symbol in targets:
        row = conn.execute(
            "SELECT id,kind,ea_id,symbol,phase,status,verdict,claimed_by,created_at,updated_at "
            "FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if row is None:
            raise HoldError(f"work_item_missing:{work_item_id}")
        actual = dict(row)
        expected = {
            "ea_id": ea_id,
            "symbol": symbol,
            "phase": phase,
            "status": "pending",
            "verdict": None,
            "claimed_by": None,
        }
        mismatches = [
            f"{key}=expected:{expected_value!r}:actual:{actual.get(key)!r}"
            for key, expected_value in expected.items()
            if actual.get(key) != expected_value
        ]
        if mismatches:
            raise HoldError(f"work_item_precondition:{work_item_id}:" + ";".join(mismatches))
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=?", (work_item_id,)
        ).fetchone()
        hold_doc = dict(hold) if hold is not None else None
        if hold_doc and bool(hold_doc["active"]):
            if (
                hold_doc["hold_code"] != hold_code
                or hold_doc["reason"] != reason
                or bool(hold_doc["release_on_restart"])
            ):
                raise HoldError(f"conflicting_active_hold:{work_item_id}:{hold_doc['hold_code']}")
        result.append(
            {
                "work_item": actual,
                "hold": hold_doc,
                "claimable": _claimable(conn, work_item_id),
            }
        )
    return result


def sqlite_backup(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / f"farm_state_before_governed_hold_{stamp}.sqlite"
    if destination.exists():
        raise HoldError(f"backup_exists:{destination}")
    source = sqlite3.connect(db, timeout=30)
    target = sqlite3.connect(destination)
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def apply_holds(
    db: Path,
    backup_dir: Path,
    targets: Sequence[tuple[str, str]],
    *,
    ea_id: str,
    phase: str,
    hold_code: str,
    reason: str,
    release_condition: str,
) -> dict[str, Any]:
    backup_path, backup_sha = sqlite_backup(db, backup_dir)
    now = utc_now()
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    inserted = 0
    already_held = 0
    try:
        ensure_schema(conn)
        conn.execute("BEGIN IMMEDIATE")
        before = inspect_targets(
            conn, targets, ea_id=ea_id, phase=phase, hold_code=hold_code, reason=reason
        )
        for item in before:
            row = item["work_item"]
            existing = item["hold"]
            if existing and bool(existing["active"]):
                already_held += 1
                continue
            if existing and existing["hold_code"] != hold_code:
                raise HoldError(
                    f"conflicting_inactive_hold:{row['id']}:{existing['hold_code']}"
                )
            if existing:
                conn.execute(
                    """
                    UPDATE work_item_holds
                    SET reason=?,active=1,release_on_restart=0,updated_at=?,
                        released_at=NULL,release_note=NULL
                    WHERE work_item_id=? AND hold_code=? AND active=0
                    """,
                    (reason, now, row["id"], hold_code),
                )
            else:
                conn.execute(
                    """
                    INSERT INTO work_item_holds(
                      work_item_id,hold_code,reason,active,release_on_restart,
                      created_at,updated_at,released_at,release_note
                    ) VALUES(?,?,?,1,0,?,?,NULL,NULL)
                    """,
                    (row["id"], hold_code, reason, now, now),
                )
            detail = {
                "ea_id": ea_id,
                "symbol": row["symbol"],
                "phase": phase,
                "hold_code": hold_code,
                "reason": reason,
                "release_condition": release_condition,
                "release_on_restart": False,
                "backup_path": str(backup_path),
                "backup_sha256": backup_sha,
            }
            conn.execute(
                "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                "VALUES(?,'work_item',?,'governed_hold_activated',?)",
                (now, row["id"], json.dumps(detail, sort_keys=True)),
            )
            inserted += 1
        after = inspect_targets(
            conn, targets, ea_id=ea_id, phase=phase, hold_code=hold_code, reason=reason
        )
        if any(item["claimable"] for item in after):
            raise HoldError("pre_commit_claimable_row")
        if any(not item["hold"] or not bool(item["hold"]["active"]) for item in after):
            raise HoldError("pre_commit_active_hold_missing")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    return {
        "mode": "apply",
        "hold_code": hold_code,
        "reason": reason,
        "release_condition": release_condition,
        "inserted": inserted,
        "already_held": already_held,
        "backup": {"path": str(backup_path), "sha256": backup_sha},
        "rows": after,
        "all_unclaimable": True,
    }


def plan_holds(
    db: Path,
    targets: Sequence[tuple[str, str]],
    *,
    ea_id: str,
    phase: str,
    hold_code: str,
    reason: str,
    release_condition: str,
) -> dict[str, Any]:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        ensure_schema(conn)
        rows = inspect_targets(
            conn, targets, ea_id=ea_id, phase=phase, hold_code=hold_code, reason=reason
        )
    finally:
        conn.close()
    return {
        "mode": "plan",
        "hold_code": hold_code,
        "reason": reason,
        "release_condition": release_condition,
        "targets": rows,
        "would_insert": sum(not item["hold"] or not bool(item["hold"]["active"]) for item in rows),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "apply"))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--target", action="append", required=True, help="WORK_ITEM_ID=SYMBOL; repeat per row")
    parser.add_argument("--ea-id", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--hold-code", required=True)
    parser.add_argument("--reason", required=True)
    parser.add_argument("--release-condition", required=True)
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if not HOLD_CODE_RE.fullmatch(args.hold_code):
            raise HoldError(f"invalid_hold_code:{args.hold_code}")
        targets = parse_targets(args.target)
        common = {
            "ea_id": args.ea_id,
            "phase": args.phase,
            "hold_code": args.hold_code,
            "reason": args.reason,
            "release_condition": args.release_condition,
        }
        if args.command == "plan":
            result = plan_holds(args.db, targets, **common)
        else:
            result = apply_holds(args.db, args.backup_dir, targets, **common)
        result.update(schema="qm.governed-work-item-hold/v1", status="ok")
        exit_code = 0
    except (HoldError, sqlite3.Error, OSError) as exc:
        result = {
            "schema": "qm.governed-work-item-hold/v1",
            "status": "aborted",
            "reason": str(exc),
        }
        exit_code = 2
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    print(rendered, end="")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
