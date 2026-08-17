#!/usr/bin/env python3
"""Canonical, machine-readable supersession for work_items (v6 point 1.13).

Inventory first (`docs/ops/evidence/2026-08-18_point_1_13_supersedes_is_fragmented_not_missing.md`):
supersession is not missing, it is fragmented across five incompatible payload encodings, one of
which (``superseded_by``) means a work_item id in one family and an *agent name* in another. The
newest supersessions -- today's hedge repairs -- use none of them and live only in evidence files.

This module gives the relation one home, back-fills the existing encodings onto it, and provides
the write path without which a back-fill decays the moment the next supersession is recorded.

Three design points that fall out of the data rather than from taste:

**A supersession may have no successor.** The hedge rows were superseded because their *binary* was
rebuilt, not because a replacement row exists. ``superseded_by_work_item_id`` is therefore nullable,
and ``reason`` carries the weight.

**The ambiguous field is disambiguated by value shape, not by guessing.** A UUID-shaped
``superseded_by`` is a successor row; anything else is the actor that performed the supersession and
is stored as ``recorded_by``.

**Back-fill records its source encoding.** A row whose provenance is ``payload:superseded_by_label``
is weaker evidence than one carrying a real work_item id, and a consumer deserves to see which it
got.

Dry-run is the default. Apply takes a SQLite backup, runs under ``BEGIN IMMEDIATE``, re-reads every
insert before committing, and rolls back on any failure.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
SCHEMA = "qm.work-item-supersedes/v1"
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)

DDL = """
CREATE TABLE IF NOT EXISTS work_item_supersedes (
    work_item_id                TEXT NOT NULL,
    superseded_by_work_item_id  TEXT,
    reason                      TEXT NOT NULL,
    source_encoding             TEXT NOT NULL,
    evidence_path               TEXT,
    recorded_by                 TEXT NOT NULL,
    recorded_at                 TEXT NOT NULL,
    PRIMARY KEY (work_item_id, source_encoding)
);
CREATE INDEX IF NOT EXISTS idx_work_item_supersedes_target
    ON work_item_supersedes(superseded_by_work_item_id);
"""


class SupersedeError(RuntimeError):
    """Fail-closed supersession error."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _walk(obj: Any, path: str = ""):
    if isinstance(obj, dict):
        for key, value in obj.items():
            yield path + key, value
            yield from _walk(value, path + key + ".")
    elif isinstance(obj, list):
        for item in obj[:16]:
            yield from _walk(item, path + "[].")


def extract(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    """Map every existing payload encoding onto the canonical shape."""
    found: list[dict[str, Any]] = []
    for row in conn.execute(
        "SELECT id, payload_json FROM work_items WHERE payload_json LIKE '%supersed%'"
    ):
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except (ValueError, TypeError):
            continue
        fields = {k: v for k, v in _walk(payload) if "supersed" in k.lower()}
        if not fields:
            continue
        successor = None
        actor = None
        encoding = None
        reason_parts: list[str] = []

        for key, value in fields.items():
            leaf = key.rsplit(".", 1)[-1]
            text = value if isinstance(value, str) else None
            if leaf == "superseded_by_work_item_id" and text:
                successor, encoding = text, "payload:superseded_by_work_item_id"
            elif leaf == "superseded_by" and text:
                # The ambiguous one: UUID -> successor row, otherwise -> actor.
                if UUID_RE.match(text.strip()):
                    successor = successor or text.strip()
                    encoding = encoding or "payload:superseded_by(uuid)"
                else:
                    actor = text.strip()
                    encoding = encoding or "payload:superseded_by(agent)"
            elif leaf == "superseded_by_label" and text:
                encoding = encoding or "payload:superseded_by_label"
                reason_parts.append(f"successor_label={text}")
            elif leaf == "superseded_by_logical_symbol" and text:
                encoding = encoding or "payload:basket_consolidation"
                reason_parts.append(f"logical_symbol={text}")
            elif leaf in ("superseded_reason", "superseded_scope") and text:
                reason_parts.append(f"{leaf}={text}")
        if encoding is None:
            encoding = "payload:supersede_metadata_only"
        found.append({
            "work_item_id": row["id"],
            "superseded_by_work_item_id": successor,
            "reason": "; ".join(reason_parts)[:600] or "recorded in payload without a stated reason",
            "source_encoding": encoding,
            "evidence_path": None,
            "recorded_by": actor or "backfill",
        })
    return found


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(DDL)


def backup(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    dest = backup_dir / f"farm_state_before_supersedes_{stamp}.sqlite"
    if dest.exists():
        raise SupersedeError(f"backup_exists:{dest}")
    src = sqlite3.connect(db, timeout=30)
    dst = sqlite3.connect(dest)
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()
    return dest, sha256_file(dest)


def cmd_backfill(db: Path, backup_dir: Path, apply: bool) -> dict[str, Any]:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    try:
        rows = extract(conn)
    finally:
        conn.close()

    by_encoding: dict[str, int] = {}
    with_successor = 0
    for r in rows:
        by_encoding[r["source_encoding"]] = by_encoding.get(r["source_encoding"], 0) + 1
        with_successor += bool(r["superseded_by_work_item_id"])

    result = {
        "schema": SCHEMA,
        "mode": "apply" if apply else "plan",
        "at_utc": utc_now(),
        "extracted": len(rows),
        "with_successor_id": with_successor,
        "without_successor_id": len(rows) - with_successor,
        "by_source_encoding": by_encoding,
    }
    if not apply:
        return result

    backup_path, backup_sha = backup(db, backup_dir)
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    now = utc_now()
    try:
        ensure_schema(conn)
        conn.execute("BEGIN IMMEDIATE")
        inserted = 0
        for r in rows:
            cur = conn.execute(
                """INSERT OR IGNORE INTO work_item_supersedes
                   (work_item_id, superseded_by_work_item_id, reason, source_encoding,
                    evidence_path, recorded_by, recorded_at)
                   VALUES (?,?,?,?,?,?,?)""",
                (r["work_item_id"], r["superseded_by_work_item_id"], r["reason"],
                 r["source_encoding"], r["evidence_path"], r["recorded_by"], now),
            )
            inserted += cur.rowcount if cur.rowcount > 0 else 0
        readback = conn.execute("SELECT COUNT(*) n FROM work_item_supersedes").fetchone()["n"]
        if readback < inserted:
            raise SupersedeError(f"pre_commit_readback_short:{readback}<{inserted}")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    result.update(inserted=inserted, table_rows=readback,
                  backup={"path": str(backup_path), "sha256": backup_sha})
    return result


def cmd_record(db: Path, backup_dir: Path, apply: bool, *, work_item_id: str,
               successor: str | None, reason: str, evidence: str | None,
               recorded_by: str) -> dict[str, Any]:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    try:
        row = conn.execute("SELECT id, ea_id, symbol, phase, status, verdict FROM work_items WHERE id=?",
                           (work_item_id,)).fetchone()
        if row is None:
            raise SupersedeError(f"work_item_missing:{work_item_id}")
        if successor:
            if conn.execute("SELECT 1 FROM work_items WHERE id=?", (successor,)).fetchone() is None:
                raise SupersedeError(f"successor_missing:{successor}")
        preview = {
            "schema": SCHEMA, "mode": "apply" if apply else "plan", "at_utc": utc_now(),
            "work_item": dict(row), "superseded_by_work_item_id": successor,
            "reason": reason, "evidence_path": evidence, "recorded_by": recorded_by,
        }
        if not apply:
            return preview
    finally:
        conn.close()

    backup_path, backup_sha = backup(db, backup_dir)
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    now = utc_now()
    try:
        ensure_schema(conn)
        conn.execute("BEGIN IMMEDIATE")
        conn.execute(
            """INSERT OR REPLACE INTO work_item_supersedes
               (work_item_id, superseded_by_work_item_id, reason, source_encoding,
                evidence_path, recorded_by, recorded_at)
               VALUES (?,?,?,'operator:record',?,?,?)""",
            (work_item_id, successor, reason, evidence, recorded_by, now),
        )
        conn.execute(
            "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
            "VALUES(?,'work_item',?,'work_item_superseded',?)",
            (now, work_item_id, json.dumps(
                {"superseded_by_work_item_id": successor, "reason": reason,
                 "evidence_path": evidence, "recorded_by": recorded_by}, sort_keys=True)),
        )
        check = conn.execute(
            "SELECT 1 FROM work_item_supersedes WHERE work_item_id=? AND source_encoding='operator:record'",
            (work_item_id,)).fetchone()
        if check is None:
            raise SupersedeError("pre_commit_row_missing")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    preview.update(recorded=True, backup={"path": str(backup_path), "sha256": backup_sha})
    return preview


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="command", required=True)
    for name in ("backfill", "record"):
        p = sub.add_parser(name)
        p.add_argument("--apply", action="store_true")
        p.add_argument("--db", type=Path, default=DEFAULT_DB)
        p.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
        p.add_argument("--output", type=Path)
        if name == "record":
            p.add_argument("--work-item-id", required=True)
            p.add_argument("--superseded-by", default=None,
                           help="successor work_item id; omit when the verdict was superseded "
                                "without a replacement row (e.g. the binary was rebuilt)")
            p.add_argument("--reason", required=True)
            p.add_argument("--evidence", default=None)
            p.add_argument("--recorded-by", required=True)
    args = ap.parse_args()
    try:
        if args.command == "backfill":
            result = cmd_backfill(args.db, args.backup_dir, args.apply)
        else:
            result = cmd_record(args.db, args.backup_dir, args.apply,
                                work_item_id=args.work_item_id, successor=args.superseded_by,
                                reason=args.reason, evidence=args.evidence,
                                recorded_by=args.recorded_by)
        result["status"] = "ok"
        code = 0
    except (SupersedeError, sqlite3.Error, OSError) as exc:
        result = {"schema": SCHEMA, "status": "aborted", "reason": f"{type(exc).__name__}: {exc}"}
        code = 2
    text = json.dumps(result, indent=1, sort_keys=False, default=str)
    print(text)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
