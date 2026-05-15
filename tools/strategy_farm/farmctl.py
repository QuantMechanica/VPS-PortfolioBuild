"""Deterministic local controller for the QuantMechanica strategy farm.

The controller deliberately avoids background work and model calls. It owns
state and queues; humans/agents execute the current action and report artifacts
back into the filesystem.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sqlite3
import sys
import uuid
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
DB_REL = Path("state") / "farm_state.sqlite"
REPO_ROOT = Path(__file__).resolve().parents[2]
CLAUDE_RESEARCH_TEMPLATE = Path(__file__).resolve().parent / "prompts" / "claude_research_source.md"

RUNTIME_DIRS = [
    "queue",
    "state/locks",
    "artifacts/source_notes",
    "artifacts/cards_draft",
    "artifacts/cards_approved",
    "artifacts/builds",
    "artifacts/backtests",
    "artifacts/verdicts",
    "logs",
]

SEED_SOURCES = [
    {
        "priority": 10,
        "lane": "recovery",
        "source_type": "existing_ea",
        "uri": r"C:\QM\repo\framework\EAs\QM5_1006_davey-eu-day",
        "title": "QM5_1006 Davey EU day zero-trade recovery",
    },
    {
        "priority": 20,
        "lane": "research",
        "source_type": "web_forum",
        "uri": "https://www.forexfactory.com/",
        "title": "ForexFactory strategies and systems",
    },
    {
        "priority": 30,
        "lane": "research",
        "source_type": "web_forum",
        "uri": "https://forums.babypips.com/",
        "title": "BabyPips forum strategy research",
    },
    {
        "priority": 40,
        "lane": "research",
        "source_type": "mql5_codebase",
        "uri": "https://www.mql5.com/en/code/mt5",
        "title": "MQL5 CodeBase MT5 strategies",
    },
    {
        "priority": 50,
        "lane": "research",
        "source_type": "mql5_articles",
        "uri": "https://www.mql5.com/en/articles",
        "title": "MQL5 Articles strategy research",
    },
    {
        "priority": 60,
        "lane": "legacy",
        "source_type": "local_archive",
        "uri": r"G:\My Drive\QuantMechanica",
        "title": "Legacy QuantMechanica books and EAs",
    },
]


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def source_id(source: dict[str, Any]) -> str:
    raw = f"{source['source_type']}|{source['uri']}"
    return str(uuid.uuid5(uuid.NAMESPACE_URL, raw))


def root_from_args(args: argparse.Namespace) -> Path:
    return Path(args.root).resolve()


def db_path(root: Path) -> Path:
    return root / DB_REL


def connect(root: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path(root))
    conn.row_factory = sqlite3.Row
    return conn


def init_dirs(root: Path) -> None:
    for rel in RUNTIME_DIRS:
        (root / rel).mkdir(parents=True, exist_ok=True)


def init_db(root: Path) -> None:
    init_dirs(root)
    with connect(root) as conn:
        conn.executescript(
            """
            PRAGMA journal_mode=WAL;

            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY,
                priority INTEGER NOT NULL,
                lane TEXT NOT NULL,
                source_type TEXT NOT NULL,
                uri TEXT NOT NULL,
                title TEXT NOT NULL,
                status TEXT NOT NULL CHECK (
                    status IN (
                        'pending',
                        'active',
                        'notes_ready',
                        'cards_ready',
                        'approved',
                        'rejected',
                        'done',
                        'blocked'
                    )
                ),
                notes_path TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(source_type, uri)
            );

            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                status TEXT NOT NULL CHECK (
                    status IN ('pending', 'active', 'done', 'blocked', 'failed')
                ),
                source_id TEXT,
                card_id TEXT,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(source_id) REFERENCES sources(id)
            );

            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                event TEXT NOT NULL,
                detail_json TEXT NOT NULL
            );
            """
        )


def event(conn: sqlite3.Connection, entity_type: str, entity_id: str, name: str, detail: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO events(ts, entity_type, entity_id, event, detail_json)
        VALUES (?, ?, ?, ?, ?)
        """,
        (utc_now(), entity_type, entity_id, name, json.dumps(detail, sort_keys=True)),
    )


def seed_sources(root: Path, force: bool = False) -> dict[str, Any]:
    init_db(root)
    inserted = 0
    skipped = 0
    now = utc_now()
    with connect(root) as conn:
        if force:
            conn.execute("DELETE FROM sources")
            conn.execute("DELETE FROM tasks")
            event(conn, "farm", "sources", "seed_force_reset", {})
        for src in SEED_SOURCES:
            sid = source_id(src)
            try:
                conn.execute(
                    """
                    INSERT INTO sources(
                        id, priority, lane, source_type, uri, title, status,
                        notes_path, created_at, updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, 'pending', NULL, ?, ?)
                    """,
                    (
                        sid,
                        src["priority"],
                        src["lane"],
                        src["source_type"],
                        src["uri"],
                        src["title"],
                        now,
                        now,
                    ),
                )
                event(conn, "source", sid, "seeded", src)
                inserted += 1
            except sqlite3.IntegrityError:
                skipped += 1

    write_sources_jsonl(root)
    return {"inserted": inserted, "skipped": skipped, "root": str(root), "db": str(db_path(root))}


def rows_as_dicts(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(row) for row in rows]


def write_sources_jsonl(root: Path) -> Path:
    init_db(root)
    out = root / "queue" / "sources.jsonl"
    with connect(root) as conn:
        rows = conn.execute(
            """
            SELECT priority, lane, source_type, uri, title, status, id
            FROM sources
            ORDER BY priority, created_at, id
            """
        ).fetchall()
    with out.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(dict(row), sort_keys=True) + "\n")
    return out


def status(root: Path) -> dict[str, Any]:
    init_db(root)
    with connect(root) as conn:
        counts = rows_as_dicts(
            conn.execute(
                "SELECT status, COUNT(*) AS count FROM sources GROUP BY status ORDER BY status"
            ).fetchall()
        )
        active = rows_as_dicts(
            conn.execute(
                """
                SELECT id, priority, lane, source_type, uri, title, status
                FROM sources
                WHERE status = 'active'
                ORDER BY priority, created_at, id
                """
            ).fetchall()
        )
        next_pending = conn.execute(
            """
            SELECT id, priority, lane, source_type, uri, title, status
            FROM sources
            WHERE status = 'pending'
            ORDER BY priority, created_at, id
            LIMIT 1
            """
        ).fetchone()
        task_counts = rows_as_dicts(
            conn.execute(
                "SELECT kind, status, COUNT(*) AS count FROM tasks GROUP BY kind, status ORDER BY kind, status"
            ).fetchall()
        )
    return {
        "root": str(root),
        "db": str(db_path(root)),
        "source_counts": counts,
        "active_sources": active,
        "next_pending_source": dict(next_pending) if next_pending else None,
        "task_counts": task_counts,
    }


def next_action(root: Path) -> dict[str, Any]:
    current = status(root)
    active = current["active_sources"]
    if len(active) > 1:
        return {
            "action": "repair_required",
            "reason": "More than one active source exists. Resolve before continuing.",
            "active_sources": active,
        }
    if active:
        return {
            "action": "research_active_source",
            "role": "Claude",
            "source": active[0],
            "expected_output": "source notes and draft strategy cards under artifacts/source_notes and artifacts/cards_draft",
        }
    pending = current["next_pending_source"]
    if pending:
        return {
            "action": "claim_source",
            "command": "python tools/strategy_farm/farmctl.py claim-source",
            "source": pending,
        }
    return {"action": "idle", "reason": "No pending sources or active work."}


def claim_source(root: Path) -> dict[str, Any]:
    init_db(root)
    now = utc_now()
    with connect(root) as conn:
        active = conn.execute("SELECT COUNT(*) AS count FROM sources WHERE status = 'active'").fetchone()["count"]
        if active:
            return {"claimed": None, "reason": "An active source already exists.", "next_action": next_action(root)}
        row = conn.execute(
            """
            SELECT id, priority, lane, source_type, uri, title, status
            FROM sources
            WHERE status = 'pending'
            ORDER BY priority, created_at, id
            LIMIT 1
            """
        ).fetchone()
        if row is None:
            return {"claimed": None, "reason": "No pending source exists."}
        conn.execute("UPDATE sources SET status = 'active', updated_at = ? WHERE id = ?", (now, row["id"]))
        event(conn, "source", row["id"], "claimed", {"previous_status": "pending"})
    write_sources_jsonl(root)
    claimed = dict(row)
    claimed["status"] = "active"
    return {"claimed": claimed, "next_action": next_action(root)}


def set_source_status(root: Path, sid: str, new_status: str, notes_path: str | None = None) -> dict[str, Any]:
    init_db(root)
    now = utc_now()
    allowed = {
        "pending",
        "active",
        "notes_ready",
        "cards_ready",
        "approved",
        "rejected",
        "done",
        "blocked",
    }
    if new_status not in allowed:
        return {"updated": False, "reason": f"Unsupported status: {new_status}", "allowed": sorted(allowed)}
    with connect(root) as conn:
        row = conn.execute("SELECT id, status, notes_path FROM sources WHERE id = ?", (sid,)).fetchone()
        if row is None:
            return {"updated": False, "reason": f"Unknown source id: {sid}"}
        if new_status == "active":
            active = conn.execute(
                "SELECT id FROM sources WHERE status = 'active' AND id != ? LIMIT 1", (sid,)
            ).fetchone()
            if active is not None:
                return {
                    "updated": False,
                    "reason": "Another active source exists. Only one active source is allowed.",
                    "active_source_id": active["id"],
                }
        final_notes = notes_path if notes_path is not None else row["notes_path"]
        conn.execute(
            "UPDATE sources SET status = ?, notes_path = ?, updated_at = ? WHERE id = ?",
            (new_status, final_notes, now, sid),
        )
        event(
            conn,
            "source",
            sid,
            "status_changed",
            {"from": row["status"], "to": new_status, "notes_path": final_notes},
        )
    write_sources_jsonl(root)
    return {"updated": True, "source_id": sid, "from": row["status"], "to": new_status, "next_action": next_action(root)}


def events_tail(root: Path, limit: int) -> dict[str, Any]:
    init_db(root)
    with connect(root) as conn:
        rows = rows_as_dicts(
            conn.execute(
                """
                SELECT ts, entity_type, entity_id, event, detail_json
                FROM events
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        )
    rows.reverse()
    for row in rows:
        row["detail"] = json.loads(row.pop("detail_json"))
    return {"events": rows}


def render_claude_prompt(root: Path, source_id_arg: str | None, out_path: str | None) -> dict[str, Any]:
    init_db(root)
    with connect(root) as conn:
        if source_id_arg:
            row = conn.execute(
                """
                SELECT id, priority, lane, source_type, uri, title, status
                FROM sources
                WHERE id = ?
                """,
                (source_id_arg,),
            ).fetchone()
        else:
            row = conn.execute(
                """
                SELECT id, priority, lane, source_type, uri, title, status
                FROM sources
                WHERE status = 'active'
                ORDER BY priority, created_at, id
                LIMIT 1
                """
            ).fetchone()
    if row is None:
        return {"written": False, "reason": "No matching source. Claim a source first or pass --source-id."}

    template = CLAUDE_RESEARCH_TEMPLATE.read_text(encoding="utf-8")
    values = {
        "source_id": row["id"],
        "title": row["title"],
        "source_type": row["source_type"],
        "lane": row["lane"],
        "uri": row["uri"],
    }
    prompt = template
    for key, value in values.items():
        prompt = prompt.replace("{{" + key + "}}", str(value))

    target = Path(out_path) if out_path else root / "queue" / f"claude_research_{row['id']}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(prompt, encoding="utf-8", newline="\n")

    return {
        "written": True,
        "prompt_path": str(target),
        "source": dict(row),
        "suggested_command": (
            "claude -p --permission-mode acceptEdits "
            f"--add-dir \"{REPO_ROOT}\" "
            f"--add-dir \"{root}\" "
            "--add-dir \"G:\\My Drive\\QuantMechanica - Company Reference\" "
            f"\"$(Get-Content -Raw '{target}')\""
        ),
    }


def print_json(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="QuantMechanica Option A strategy farm controller")
    parser.add_argument("--root", default=str(DEFAULT_ROOT), help="Runtime root. Default: %(default)s")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("init", help="Create runtime directories and SQLite schema")

    seed = sub.add_parser("seed-sources", help="Seed the ordered initial source queue")
    seed.add_argument("--force", action="store_true", help="Replace current sources/tasks before seeding")

    sub.add_parser("status", help="Show source/task state")
    sub.add_parser("next", help="Show the deterministic next action")
    sub.add_parser("claim-source", help="Activate the next pending source if no source is active")

    set_status = sub.add_parser("set-source-status", help="Move one source to a new explicit status")
    set_status.add_argument("source_id")
    set_status.add_argument("status")
    set_status.add_argument("--notes-path", help="Artifact path for research notes")

    events_cmd = sub.add_parser("events", help="Show recent state transition events")
    events_cmd.add_argument("--limit", type=int, default=20)

    claude_prompt = sub.add_parser("claude-prompt", help="Write a Claude research handoff prompt")
    claude_prompt.add_argument("--source-id")
    claude_prompt.add_argument("--out")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = root_from_args(args)

    if args.command == "init":
        init_db(root)
        print_json({"initialized": True, "root": str(root), "db": str(db_path(root))})
    elif args.command == "seed-sources":
        print_json(seed_sources(root, force=args.force))
    elif args.command == "status":
        print_json(status(root))
    elif args.command == "next":
        print_json(next_action(root))
    elif args.command == "claim-source":
        print_json(claim_source(root))
    elif args.command == "set-source-status":
        print_json(set_source_status(root, args.source_id, args.status, args.notes_path))
    elif args.command == "events":
        print_json(events_tail(root, args.limit))
    elif args.command == "claude-prompt":
        print_json(render_claude_prompt(root, args.source_id, args.out))
    else:
        raise AssertionError(args.command)
    return 0


if __name__ == "__main__":
    sys.exit(main())
