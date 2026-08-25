#!/usr/bin/env python3
"""Supersede stale COMPILE_EA rollout holds against current-source successors.

Dry-run is the default. Apply takes a SQLite backup and changes only the
canonical supersession sidecar, the exact stale activation holds, the append-
only transition ledger, and events. Work-item status, verdict, payload, and
evidence are never changed.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import sqlite3
import uuid
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

try:
    from work_item_supersedes import ensure_schema
except ModuleNotFoundError:
    from tools.strategy_farm.work_item_supersedes import ensure_schema


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
HOLD_CODE = "COMPILE_EA_WORKER_ROLLOUT_PENDING"
TASK_ID = "e9944090-1e0f-4dea-af90-e74f8079d1c8"
SOURCE_ENCODING = "operator:compile-rollout-stale-source/v1"
SCHEMA_VERSION = "qm.compile-rollout-stale-reconciliation/v1"


class ReconciliationError(RuntimeError):
    """Fail-closed reconciliation refusal."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _payload(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _connect(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _successor_rank(row: dict[str, Any]) -> tuple[int, str, str]:
    if row["status"] == "done" and row["verdict"] == "COMPILE_OK":
        rank = 0
    elif row["status"] in {"pending", "active"}:
        rank = 1
    elif row["status"] in {"done", "failed"}:
        rank = 2
    else:
        rank = 3
    return rank, str(row["created_at"] or ""), str(row["id"])


def inspect(db: Path, repo: Path) -> dict[str, Any]:
    with _connect(db) as conn:
        table = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='work_item_supersedes'"
        ).fetchone()
        if table is None:
            raise ReconciliationError("work_item_supersedes_schema_missing")
        held = conn.execute(
            """SELECT w.id,w.ea_id,w.status,w.verdict,w.payload_json,w.created_at,
                      w.updated_at,h.active,h.created_at AS hold_created_at
               FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
               WHERE w.phase='COMPILE_EA' AND h.hold_code=? AND h.active=1
               ORDER BY w.created_at,w.id""",
            (HOLD_CODE,),
        ).fetchall()
        compile_by_ea: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for row in conn.execute(
            """SELECT id,ea_id,status,verdict,payload_json,created_at,updated_at
               FROM work_items WHERE phase='COMPILE_EA'"""
        ):
            item = dict(row)
            item["payload"] = _payload(row["payload_json"])
            compile_by_ea[str(row["ea_id"])].append(item)
        superseded_ids = {
            str(row[0])
            for row in conn.execute("SELECT DISTINCT work_item_id FROM work_item_supersedes")
        }

    source_cache: dict[str, tuple[str, str | None]] = {}
    rows: list[dict[str, Any]] = []
    for held_row in held:
        old = dict(held_row)
        old_payload = _payload(old["payload_json"])
        label = str(old_payload.get("ea_label") or "").strip()
        if label not in source_cache:
            source_path = repo / "framework" / "EAs" / label / f"{label}.mq5"
            current_sha = sha256_file(source_path) if label and source_path.is_file() else None
            source_cache[label] = (str(source_path), current_sha)
        source_path, current_sha = source_cache[label]
        bound_sha = str(old_payload.get("mq5_sha256") or "").lower() or None
        base = {
            "work_item_id": str(old["id"]),
            "ea_id": str(old["ea_id"]),
            "ea_label": label,
            "work_item_status": str(old["status"]),
            "work_item_verdict": old["verdict"],
            "work_item_created_at": old["created_at"],
            "hold_code": HOLD_CODE,
            "bound_mq5_sha256": bound_sha,
            "current_mq5_sha256": current_sha,
            "source_path": source_path,
            "successor_work_item_id": None,
            "successor_status": None,
            "successor_verdict": None,
            "successor_created_at": None,
        }
        if not label or not bound_sha or current_sha is None:
            rows.append({
                **base,
                "classification": "SOURCE_OR_BINDING_UNAVAILABLE",
                "action": "MANUAL_REVIEW",
            })
            continue
        if bound_sha == current_sha.lower():
            rows.append({
                **base,
                "classification": "SOURCE_FRESH_HELD_SUCCESSOR",
                "action": "RELEASE_VIA_BOUNDED_WAVE",
            })
            continue
        candidates = []
        for candidate in compile_by_ea.get(str(old["ea_id"]), []):
            if str(candidate["id"]) == str(old["id"]):
                continue
            if str(candidate["id"]) in superseded_ids:
                continue
            if str(candidate["created_at"] or "") <= str(old["created_at"] or ""):
                continue
            candidate_sha = str(candidate["payload"].get("mq5_sha256") or "").lower()
            if candidate_sha == current_sha.lower():
                candidates.append(candidate)
        if not candidates:
            rows.append({
                **base,
                "classification": "STALE_SOURCE_NO_CURRENT_SUCCESSOR",
                "action": "ENQUEUE_CURRENT_SOURCE_SUCCESSOR",
            })
            continue
        successor = sorted(candidates, key=_successor_rank)[0]
        rows.append({
            **base,
            "successor_work_item_id": str(successor["id"]),
            "successor_status": str(successor["status"]),
            "successor_verdict": successor["verdict"],
            "successor_created_at": successor["created_at"],
            "classification": "STALE_SOURCE_CURRENT_SUCCESSOR_EXISTS",
            "action": "SUPERSEDE_AND_CLOSE_STALE_HOLD",
        })

    counts = Counter(row["classification"] for row in rows)
    stale_rows = [row for row in rows if row["bound_mq5_sha256"] != row["current_mq5_sha256"]]
    return {
        "schema_version": SCHEMA_VERSION,
        "mode": "dry_run",
        "task_id": TASK_ID,
        "at_utc": utc_now(),
        "active_hold_count": len(rows),
        "stale_hold_count": len(stale_rows),
        "source_fresh_hold_count": counts["SOURCE_FRESH_HELD_SUCCESSOR"],
        "ready_to_supersede_count": counts["STALE_SOURCE_CURRENT_SUCCESSOR_EXISTS"],
        "needs_successor_count": counts["STALE_SOURCE_NO_CURRENT_SUCCESSOR"],
        "manual_review_count": counts["SOURCE_OR_BINDING_UNAVAILABLE"],
        "classification_counts": dict(sorted(counts.items())),
        "rows": rows,
    }


def _backup(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    target = backup_dir / (
        f"farm_state_before_compile_rollout_reconcile_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    source_conn = sqlite3.connect(db, timeout=30)
    target_conn = sqlite3.connect(target)
    try:
        source_conn.backup(target_conn)
    finally:
        target_conn.close()
        source_conn.close()
    return target, sha256_file(target)


def apply_reconciliation(
    db: Path,
    repo: Path,
    backup_dir: Path,
    *,
    expected_stale_count: int,
    evidence_path: str,
) -> dict[str, Any]:
    plan = inspect(db, repo)
    if plan["stale_hold_count"] != expected_stale_count:
        raise ReconciliationError(
            f"stale_hold_count_changed:{plan['stale_hold_count']}!={expected_stale_count}"
        )
    if plan["needs_successor_count"] or plan["manual_review_count"]:
        raise ReconciliationError(
            "stale_rows_not_ready:"
            f"needs_successor={plan['needs_successor_count']},"
            f"manual_review={plan['manual_review_count']}"
        )
    targets = [
        row for row in plan["rows"]
        if row["classification"] == "STALE_SOURCE_CURRENT_SUCCESSOR_EXISTS"
    ]
    if len(targets) != expected_stale_count:
        raise ReconciliationError(
            f"ready_target_count_changed:{len(targets)}!={expected_stale_count}"
        )

    backup_path, backup_sha = _backup(db, backup_dir)
    now = utc_now()
    applied: list[str] = []
    inserted_supersessions = 0
    with _connect(db) as conn:
        ensure_schema(conn)
        conn.execute("BEGIN IMMEDIATE")
        try:
            for target in targets:
                row = conn.execute(
                    """SELECT w.ea_id,w.status,w.verdict,w.payload_json,w.created_at,
                              h.hold_code,h.active
                       FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
                       WHERE w.id=?""",
                    (target["work_item_id"],),
                ).fetchone()
                if row is None or row["hold_code"] != HOLD_CODE or int(row["active"]) != 1:
                    raise ReconciliationError(
                        f"stale_hold_changed:{target['work_item_id']}"
                    )
                payload = _payload(row["payload_json"])
                label = str(payload.get("ea_label") or "")
                source = repo / "framework" / "EAs" / label / f"{label}.mq5"
                current_sha = sha256_file(source) if source.is_file() else None
                bound_sha = str(payload.get("mq5_sha256") or "").lower()
                if not current_sha or bound_sha == current_sha.lower():
                    raise ReconciliationError(
                        f"source_fresh_or_missing_at_apply:{target['work_item_id']}"
                    )
                successor = conn.execute(
                    "SELECT ea_id,payload_json,created_at FROM work_items WHERE id=?",
                    (target["successor_work_item_id"],),
                ).fetchone()
                successor_payload = _payload(successor["payload_json"] if successor else None)
                if not (
                    successor
                    and successor["ea_id"] == row["ea_id"]
                    and str(successor["created_at"] or "") > str(row["created_at"] or "")
                    and str(successor_payload.get("mq5_sha256") or "").lower()
                    == current_sha.lower()
                ):
                    raise ReconciliationError(
                        f"successor_binding_changed:{target['work_item_id']}"
                    )

                existing = conn.execute(
                    """SELECT superseded_by_work_item_id FROM work_item_supersedes
                       WHERE work_item_id=? AND source_encoding=?""",
                    (target["work_item_id"], SOURCE_ENCODING),
                ).fetchone()
                if existing and existing[0] != target["successor_work_item_id"]:
                    raise ReconciliationError(
                        f"conflicting_supersession:{target['work_item_id']}"
                    )
                if existing is None:
                    conn.execute(
                        """INSERT INTO work_item_supersedes
                           (work_item_id,superseded_by_work_item_id,reason,source_encoding,
                            evidence_path,recorded_by,recorded_at)
                           VALUES (?,?,?,?,?,'codex',?)""",
                        (
                            target["work_item_id"],
                            target["successor_work_item_id"],
                            f"stale COMPILE_EA source superseded under router task {TASK_ID}",
                            SOURCE_ENCODING,
                            evidence_path,
                            now,
                        ),
                    )
                    inserted_supersessions += 1
                note = (
                    "stale source superseded by current-source COMPILE_EA "
                    f"{target['successor_work_item_id']} under router task {TASK_ID}"
                )
                cursor = conn.execute(
                    """UPDATE work_item_holds
                       SET active=0,updated_at=?,released_at=?,release_note=?
                       WHERE work_item_id=? AND hold_code=? AND active=1""",
                    (now, now, note, target["work_item_id"], HOLD_CODE),
                )
                if cursor.rowcount != 1:
                    raise ReconciliationError(
                        f"hold_close_cas_failed:{target['work_item_id']}"
                    )
                conn.execute(
                    """INSERT INTO work_item_transition_ledger
                       (idempotency_key,ts,work_item_id,action,reason,run_id,detail_json)
                       VALUES(?,?,?,'supersede_stale_compile_hold',?,? ,?)""",
                    (
                        f"compile-rollout-stale:{TASK_ID}:{target['work_item_id']}",
                        now,
                        target["work_item_id"],
                        note,
                        TASK_ID,
                        json.dumps(
                            {"successor_work_item_id": target["successor_work_item_id"]},
                            sort_keys=True,
                        ),
                    ),
                )
                conn.execute(
                    """INSERT INTO events(ts,entity_type,entity_id,event,detail_json)
                       VALUES(?,'work_item',?,'stale_compile_rollout_hold_superseded',?)""",
                    (
                        now,
                        target["work_item_id"],
                        json.dumps(
                            {
                                "successor_work_item_id": target["successor_work_item_id"],
                                "task_id": TASK_ID,
                            },
                            sort_keys=True,
                        ),
                    ),
                )
                applied.append(target["work_item_id"])
            conn.commit()
        except Exception:
            conn.rollback()
            raise
    post = inspect(db, repo)
    return {
        **plan,
        "mode": "apply",
        "applied_at_utc": now,
        "applied": len(applied),
        "applied_work_item_ids": applied,
        "inserted_supersessions": inserted_supersessions,
        "post_active_hold_count": post["active_hold_count"],
        "post_stale_hold_count": post["stale_hold_count"],
        "post_source_fresh_hold_count": post["source_fresh_hold_count"],
        "backup": {"path": str(backup_path), "sha256": backup_sha},
    }


def _write_json(path: Path, result: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temp.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temp.replace(path)


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0]) if rows else ["work_item_id"]
    temp = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    with temp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temp.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-stale-count", type=int)
    parser.add_argument("--evidence-path", default="")
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--output-csv", type=Path)
    parser.add_argument(
        "--output-needs-successor",
        type=Path,
        help="write a unique ea_label CSV for ENQUEUE_CURRENT_SOURCE_SUCCESSOR rows",
    )
    args = parser.parse_args()
    try:
        if args.apply:
            if args.expected_stale_count is None or not args.evidence_path:
                raise ReconciliationError(
                    "--apply requires --expected-stale-count and --evidence-path"
                )
            result = apply_reconciliation(
                args.db,
                args.repo,
                args.backup_dir,
                expected_stale_count=args.expected_stale_count,
                evidence_path=args.evidence_path,
            )
        else:
            result = inspect(args.db, args.repo)
        result["status"] = "ok"
        code = 0
    except (ReconciliationError, OSError, sqlite3.Error, ValueError) as exc:
        result = {
            "schema_version": SCHEMA_VERSION,
            "status": "aborted",
            "reason": f"{type(exc).__name__}: {exc}",
        }
        code = 2
    if args.output_json:
        _write_json(args.output_json, result)
    if args.output_csv and result.get("rows"):
        _write_csv(args.output_csv, result["rows"])
    if args.output_needs_successor and result.get("rows"):
        needed = sorted({
            str(row["ea_label"])
            for row in result["rows"]
            if row.get("action") == "ENQUEUE_CURRENT_SOURCE_SUCCESSOR"
        })
        _write_csv(
            args.output_needs_successor,
            [{"ea_label": label} for label in needed],
        )
    print(json.dumps(result, indent=2, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
