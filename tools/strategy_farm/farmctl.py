"""Deterministic local controller for the QuantMechanica strategy farm.

The controller deliberately avoids background work and model calls. It owns
state and queues; humans/agents execute the current action and report artifacts
back into the filesystem.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import glob
import json
import os
import re
import sqlite3
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
DB_REL = Path("state") / "farm_state.sqlite"
REPO_ROOT = Path(__file__).resolve().parents[2]
FRAMEWORK_EAS_DIR = REPO_ROOT / "framework" / "EAs"
PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"
CLAUDE_RESEARCH_TEMPLATE = PROMPTS_DIR / "claude_research_source.md"
CODEX_BUILD_TEMPLATE = PROMPTS_DIR / "codex_build_ea.md"
CLAUDE_REVIEW_TEMPLATE = PROMPTS_DIR / "claude_review_ea.md"

PIPELINE_REPORT_ROOT = Path(r"D:\QM\reports\pipeline")
SUPPORTED_BACKTEST_PHASES = ("P2", "P3")  # P3 added 2026-05-16 for end-to-end pipeline flow
MT5_TERMINALS = ("T1", "T2", "T3", "T4", "T5")  # factory fleet, used by dispatch-tick for per-EA terminal assignment

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


def parse_card_frontmatter(card_path: Path) -> dict[str, Any]:
    """Minimal YAML frontmatter parser for flat key:value Strategy Card fields.

    Returns a dict of the simple top-level keys (ea_id, slug, g0_status, r1..r4,
    pipeline_phase, last_updated). Skips list/dict values silently.
    """
    text = card_path.read_text(encoding="utf-8")
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    block = m.group(1)
    result: dict[str, Any] = {}
    for line in block.splitlines():
        m2 = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+?)\s*$", line)
        if m2:
            key, val = m2.group(1), m2.group(2).strip()
            if val and not val.startswith("-") and val not in {"|", ">"}:
                result[key] = val.strip('"').strip("'")
    return result


def create_task(
    conn: sqlite3.Connection,
    kind: str,
    source_id: str | None,
    card_id: str | None,
    payload: dict[str, Any],
) -> str:
    task_id = str(uuid.uuid4())
    now = utc_now()
    conn.execute(
        """
        INSERT INTO tasks(id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
        VALUES (?, ?, 'pending', ?, ?, ?, ?, ?)
        """,
        (task_id, kind, source_id, card_id, json.dumps(payload, sort_keys=True), now, now),
    )
    event(conn, "task", task_id, "created", {"kind": kind, "card_id": card_id, "source_id": source_id})
    return task_id


def update_task(
    conn: sqlite3.Connection,
    task_id: str,
    status: str | None = None,
    payload_merge: dict[str, Any] | None = None,
) -> dict[str, Any] | None:
    row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    if row is None:
        return None
    payload = json.loads(row["payload_json"])
    if payload_merge:
        payload.update(payload_merge)
    new_status = status if status is not None else row["status"]
    conn.execute(
        "UPDATE tasks SET status = ?, payload_json = ?, updated_at = ? WHERE id = ?",
        (new_status, json.dumps(payload, sort_keys=True), utc_now(), task_id),
    )
    event(conn, "task", task_id, "updated", {"from": row["status"], "to": new_status})
    return {"id": task_id, "status": new_status, "payload": payload}


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


def pipeline_view(root: Path) -> dict[str, Any]:
    """Per-EA lifecycle table — answers "where does each EA stand RIGHT NOW?"

    Aggregates state across the tasks table for every EA seen in build_ea +
    backtest_<phase> + ea_review rows. Output is one row per EA with columns:
      ea_id, slug (from build payload), card_status (approved/etc.),
      build_status, build_smoke, review_verdict, p2_verdict, p3_verdict, ...
      attempts (sum across tasks), terminal_state (which phase is active).

    Designed to be the single command OWNER runs to see the whole farm.
    """
    init_db(root)
    eas: dict[str, dict[str, Any]] = {}
    with connect(root) as conn:
        rows = conn.execute(
            "SELECT id, kind, status, payload_json, created_at, updated_at "
            "FROM tasks ORDER BY created_at"
        ).fetchall()
    for r in rows:
        payload = json.loads(r["payload_json"]) if r["payload_json"] else {}
        ea_id = payload.get("ea_id") or r["id"]
        if not ea_id:
            continue
        entry = eas.setdefault(ea_id, {
            "ea_id": ea_id,
            "slug": payload.get("slug") or "",
            "build": None,
            "review": None,
            "phases": {},          # phase_label → {status, verdict, attempts, surviving_symbols}
            "current_stage": "card",
            "total_attempts": 0,
            "last_activity": r["updated_at"],
        })
        if not entry["slug"] and payload.get("slug"):
            entry["slug"] = payload["slug"]
        if r["updated_at"] > entry["last_activity"]:
            entry["last_activity"] = r["updated_at"]
        entry["total_attempts"] += int(payload.get("attempt_count", 0))

        kind = r["kind"]
        if kind == "build_ea":
            entry["build"] = {
                "task_id": r["id"],
                "status": r["status"],
                "smoke": (payload.get("build_result") or {}).get("smoke_result") or payload.get("smoke_result"),
                "blocked_reason": payload.get("blocked_reason"),
            }
            if r["status"] == "pending":
                entry["current_stage"] = "build_pending"
            elif r["status"] == "active":
                entry["current_stage"] = "building"
            elif r["status"] in ("done",):
                entry["current_stage"] = "built"
            elif r["status"] in ("failed", "blocked"):
                entry["current_stage"] = f"build_{r['status']}"
        elif kind == "ea_review":
            verdict_doc = payload.get("verdict") or {}
            entry["review"] = {
                "task_id": r["id"],
                "status": r["status"],
                "verdict": verdict_doc.get("verdict"),
            }
            if r["status"] == "done":
                if verdict_doc.get("verdict") == "APPROVE_FOR_BACKTEST":
                    entry["current_stage"] = "review_approved"
                else:
                    entry["current_stage"] = f"review_{verdict_doc.get('verdict','?').lower()}"
        elif kind.startswith("backtest_"):
            phase = payload.get("phase") or kind.replace("backtest_", "").upper()
            classification = payload.get("classification") or {}
            entry["phases"][phase] = {
                "task_id": r["id"],
                "status": r["status"],
                "verdict": classification.get("verdict"),
                "attempts": int(payload.get("attempt_count", 0)),
                "surviving_symbols": classification.get("surviving_symbols", []),
            }
            if r["status"] == "pending":
                entry["current_stage"] = f"{phase}_pending"
            elif r["status"] == "active":
                entry["current_stage"] = f"{phase}_running"
            elif r["status"] == "done":
                entry["current_stage"] = f"{phase}_{(classification.get('verdict') or '?').lower()}"

    # Order: by ea_id ascending
    out = sorted(eas.values(), key=lambda e: e["ea_id"])
    summary = {
        "by_stage": {},
    }
    for e in out:
        s = e["current_stage"]
        summary["by_stage"][s] = summary["by_stage"].get(s, 0) + 1
    return {"eas": out, "summary": summary, "count": len(out)}


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


def get_mt5_status() -> dict[str, Any]:
    """Return MT5 fleet status via tasklist scan of terminal64.exe.

    v1 is intentionally coarse — counts running terminals and lists their PIDs +
    window titles. Per-slot (T1..T5) attribution requires cwd inspection that
    tasklist alone cannot do; future revisions can swap in psutil for that.
    """
    scan_at = utc_now()
    try:
        result = subprocess.run(
            ["tasklist", "/V", "/FO", "CSV", "/FI", "IMAGENAME eq terminal64.exe"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except Exception as exc:
        return {"scanned_at": scan_at, "error": f"tasklist failed: {exc}"}

    lines = [l for l in result.stdout.splitlines() if "terminal64.exe" in l]
    processes: list[dict[str, str]] = []
    for line in lines:
        # CSV cols: ImageName, PID, SessionName, Session#, MemUsage, Status, UserName, CpuTime, WindowTitle
        try:
            reader = csv.reader([line])
            cols = next(reader)
            if len(cols) >= 9:
                processes.append({
                    "pid": cols[1].strip('"'),
                    "status": cols[5].strip('"'),
                    "window_title": cols[8].strip('"'),
                })
        except Exception:
            continue

    return {
        "scanned_at": scan_at,
        "terminal64_running_count": len(processes),
        "processes": processes,
        "note": "v1 scan — per-slot T1..T5 attribution requires cwd inspection (see future psutil swap)",
    }


def classify_p2(report_csv_path: Path) -> dict[str, Any]:
    """Apply the P2 phase gate to a p2_baseline report.csv.

    Verdict logic per Pipeline Overview + HR7:
    - >=1 PASS symbol  -> PASS, advance EA (Portfolio-Kandidat = mindestens 1 Symbol durch).
    - All FAIL with trade_count_below_min reason  -> ZERO_TRADES (HR7: setup, not strategy fail).
    - >=50% INVALID  -> INFRA_FAIL (G1 / real-ticks / model4 setup problem).
    - Otherwise  -> STRATEGY_FAIL.
    """
    if not report_csv_path.exists():
        return {
            "verdict": "INFRA_FAIL",
            "reason": "report.csv missing",
            "evidence_path": str(report_csv_path),
        }

    rows: list[dict[str, str]] = []
    try:
        with report_csv_path.open(encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
    except Exception as exc:
        return {
            "verdict": "INFRA_FAIL",
            "reason": f"report.csv unreadable: {exc}",
            "evidence_path": str(report_csv_path),
        }

    if not rows:
        return {
            "verdict": "INFRA_FAIL",
            "reason": "report.csv has no data rows",
            "evidence_path": str(report_csv_path),
        }

    surviving = [r["symbol"] for r in rows if r.get("verdict") == "PASS"]
    fails = [r for r in rows if r.get("verdict") == "FAIL"]
    invalids = [r for r in rows if r.get("verdict") == "INVALID"]
    zero_trade_syms = [
        r["symbol"] for r in fails
        if "trade_count_below_min" in (r.get("invalidation_reason") or "")
    ]
    strategy_fail_syms = [r["symbol"] for r in fails if r["symbol"] not in zero_trade_syms]

    counts: dict[str, int] = {}
    for r in rows:
        v = r.get("verdict", "MISSING")
        counts[v] = counts.get(v, 0) + 1

    base = {
        "evidence_path": str(report_csv_path),
        "counts_by_verdict": counts,
        "surviving_symbols": surviving,
        "zero_trade_symbols": zero_trade_syms,
        "invalid_symbols": [r["symbol"] for r in invalids],
        "strategy_fail_symbols": strategy_fail_syms,
    }

    if surviving:
        return {**base, "verdict": "PASS"}
    if zero_trade_syms and not strategy_fail_syms:
        return {
            **base,
            "verdict": "ZERO_TRADES",
            "advice": "Per HR7 NO_REPORT != EA-Schwaeche. Investigate filters/window before declaring strategy fail.",
        }
    if invalids and len(invalids) >= 0.5 * len(rows):
        return {
            **base,
            "verdict": "INFRA_FAIL",
            "advice": "Majority INVALID — check G1 real-ticks marker, Model 4 setup, tester defaults.",
        }
    return {**base, "verdict": "STRATEGY_FAIL"}


def classify_p3(report_csv_path: Path) -> dict[str, Any]:
    """Classify a P3 parameter sweep.

    Verdict logic:
    - >=1 PASS row  -> PASS (at least one param combo survived; advance to P3.5).
    - All rows present but 0 PASS  -> STRATEGY_FAIL.
    - report missing / unreadable / empty  -> INFRA_FAIL.

    p3_param_sweep.py rows are keyed by run_id (=symbol_period_NNN) with a
    verdict column. surviving_params is the list of param dicts that passed.
    """
    if not report_csv_path.exists():
        return {"verdict": "INFRA_FAIL", "reason": "report.csv missing", "evidence_path": str(report_csv_path)}
    try:
        with report_csv_path.open(encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
    except Exception as exc:
        return {"verdict": "INFRA_FAIL", "reason": f"report.csv unreadable: {exc}", "evidence_path": str(report_csv_path)}
    if not rows:
        return {"verdict": "INFRA_FAIL", "reason": "report.csv has no data rows", "evidence_path": str(report_csv_path)}

    passes = [r for r in rows if r.get("verdict") == "PASS"]
    fails = [r for r in rows if r.get("verdict") == "FAIL"]
    counts = {"PASS": len(passes), "FAIL": len(fails), "TOTAL": len(rows)}
    base = {
        "evidence_path": str(report_csv_path),
        "counts_by_verdict": counts,
        "surviving_params": [r.get("params", "") for r in passes][:10],
        "surviving_run_ids": [r.get("run_id", "") for r in passes][:10],
    }
    if passes:
        return {**base, "verdict": "PASS"}
    return {**base, "verdict": "STRATEGY_FAIL"}


PHASE_CLASSIFIERS = {
    "P3": classify_p3,
    "P2": classify_p2,
}


def classify_backtest(phase: str, report_csv_path: Path) -> dict[str, Any]:
    fn = PHASE_CLASSIFIERS.get(phase)
    if fn is None:
        return {
            "verdict": "UNSUPPORTED",
            "reason": f"no classifier registered for phase {phase}",
            "evidence_path": str(report_csv_path),
        }
    return fn(report_csv_path)


def enqueue_backtest(root: Path, review_task_id: str, phase: str) -> dict[str, Any]:
    """Create a backtest_<phase> task.

    For phase P2: predecessor is an APPROVE_FOR_BACKTEST ea_review task.
    For phase P3+: predecessor is a done backtest_<prev_phase> task with
    classification.verdict == 'PASS'. The review_task_id argument is then
    actually the previous backtest task id (kept name for back-compat).
    """
    if phase not in SUPPORTED_BACKTEST_PHASES:
        return {
            "enqueued": False,
            "reason": f"Phase {phase} not yet supported. Supported: {SUPPORTED_BACKTEST_PHASES}",
        }
    init_db(root)
    with connect(root) as conn:
        pred_row = conn.execute("SELECT * FROM tasks WHERE id = ?", (review_task_id,)).fetchone()
        if pred_row is None:
            return {"enqueued": False, "reason": f"Predecessor task not found: {review_task_id}"}

        # P2 predecessor must be ea_review APPROVE_FOR_BACKTEST.
        # P3+ predecessor must be backtest_<prev>:done with verdict=PASS.
        if phase == "P2":
            if pred_row["kind"] != "ea_review":
                return {"enqueued": False, "reason": f"Task {review_task_id} kind={pred_row['kind']!r}, expected ea_review for P2"}
            review_payload = json.loads(pred_row["payload_json"])
            verdict_doc = review_payload.get("verdict") or {}
            if verdict_doc.get("verdict") != "APPROVE_FOR_BACKTEST":
                return {"enqueued": False, "reason": f"Review verdict was {verdict_doc.get('verdict')!r}, not APPROVE_FOR_BACKTEST"}
            ea_id = review_payload.get("ea_id")
            surviving_symbols = None
            surviving_params = None
        else:
            # P3+: predecessor is a done backtest task with PASS verdict.
            if not pred_row["kind"].startswith("backtest_"):
                return {"enqueued": False, "reason": f"Task {review_task_id} kind={pred_row['kind']!r}, expected backtest_<prev> for {phase}"}
            if pred_row["status"] != "done":
                return {"enqueued": False, "reason": f"Predecessor backtest task status={pred_row['status']!r}, expected 'done'"}
            pred_payload = json.loads(pred_row["payload_json"])
            classification = pred_payload.get("classification") or {}
            if classification.get("verdict") != "PASS":
                return {"enqueued": False, "reason": f"Predecessor verdict was {classification.get('verdict')!r}, not PASS"}
            ea_id = pred_payload.get("ea_id")
            surviving_symbols = classification.get("surviving_symbols", [])
            surviving_params = classification.get("surviving_params", [])

        if not ea_id:
            return {"enqueued": False, "reason": "Predecessor payload missing ea_id"}

        # Each runner writes to D:/QM/reports/pipeline/<args.ea>/<PHASE>/report.csv
        # Glob matches both short (QM5_NNNN) and long (QM5_NNNN_<slug>) forms.
        expected_glob = str(PIPELINE_REPORT_ROOT / f"{ea_id}*" / phase / "report.csv")

        payload = {
            "phase": phase,
            "ea_id": ea_id,
            "predecessor_task_id": review_task_id,
            "expected_report_glob": expected_glob,
        }
        if surviving_symbols is not None:
            payload["surviving_symbols"] = surviving_symbols
        if surviving_params is not None:
            payload["surviving_params"] = surviving_params
        # Back-compat alias
        if phase == "P2":
            payload["review_task_id"] = review_task_id

        task_id = create_task(
            conn,
            kind=f"backtest_{phase.lower()}",
            source_id=pred_row["source_id"],
            card_id=pred_row["card_id"],
            payload=payload,
        )

    return {
        "enqueued": True,
        "task_id": task_id,
        "ea_id": ea_id,
        "phase": phase,
        "expected_report_glob": expected_glob,
        "next_action_hint": "python tools/strategy_farm/farmctl.py dispatch-tick",
    }


def _resolve_report(payload: dict[str, Any]) -> Path | None:
    """Resolve the report.csv path for a backtest task — direct path or glob."""
    direct = payload.get("expected_report_path")
    if direct and Path(direct).exists():
        return Path(direct)
    glob_pat = payload.get("expected_report_glob")
    if glob_pat:
        matches = glob.glob(glob_pat)
        if matches:
            return Path(matches[0])
    return None


def _detect_ea_period(ea_id: str) -> str:
    """Infer setfile period (D1/H1/M30/...) from existing setfile names.

    p2_baseline.py needs --period to match the setfile pattern. Default H1
    fails for any EA built on a different timeframe (e.g. QM5_1047 Halloween
    on D1). Inspect framework/EAs/<ea_id>_*/sets/ and pick the unique period.
    """
    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return "H1"
    sets_dir = candidates[0] / "sets"
    if not sets_dir.is_dir():
        return "H1"
    periods: set[str] = set()
    pat = re.compile(r"_([A-Za-z0-9]+)_backtest\.set$")
    for f in sets_dir.iterdir():
        m = pat.search(f.name)
        if m:
            periods.add(m.group(1))
    if len(periods) == 1:
        return periods.pop()
    return "H1"


def _phase_runner_cmd(phase: str, ea_id: str, terminal: str | None = None,
                       surviving_symbols: list[str] | None = None) -> list[str] | None:
    """Return the subprocess argv for the runner of a given phase, or None.

    P2 takes all setfiles in the EA dir; P3+ runs only on `surviving_symbols`
    from the predecessor phase (P2 PASS symbols). When `terminal` is given
    (P2-only path), pins p2_baseline to one terminal for fleet saturation.
    """
    if phase == "P2":
        period = _detect_ea_period(ea_id)
        # Multi-year window: annual-cycle EAs (Halloween, Estrada 6m-rotation,
        # McConnell turn-of-month) cannot hit min-trades on a single calendar
        # year. 2022-2024 = 3 years is enough for monthly strategies and
        # covers ≥3 cycles for annual ones (HR7 still applies as fallback).
        cmd = [
            sys.executable,
            str(REPO_ROOT / "framework" / "scripts" / "p2_baseline.py"),
            "--ea", ea_id,
            "--period", period,
            "--from-year", "2022",
            "--to-year", "2024",
            "--min-trades", "5",  # lowered from 20 for low-frequency strategies; sub-gates apply higher bars
        ]
        if terminal:
            cmd.extend(["--terminal", terminal])
        return cmd

    if phase == "P3":
        period = _detect_ea_period(ea_id)
        symbols = surviving_symbols or []
        if not symbols:
            return None  # P3 without surviving symbols is meaningless
        # p3_param_sweep imports `framework.scripts.pipeline_dispatcher`, so we
        # invoke via `python -m framework.scripts.p3_param_sweep` with the repo
        # root on sys.path. The PYTHONPATH env var is set by the dispatcher
        # when it spawns the subprocess (see dispatch_tick).
        cmd = [
            sys.executable, "-m", "framework.scripts.p3_param_sweep",
            "--ea", ea_id,
            "--symbols", ",".join(symbols),
            "--periods", period,
            "--year", "2024",
            "--max-runs", "24",
            "--max-parallel", "5",
        ]
        return cmd

    return None


def dispatch_tick(root: Path, timeout_hours: float = 6.0) -> dict[str, Any]:
    """Hybrid saturated dispatch (Achse B v2, OWNER 2026-05-16).

    Single-EA case (1 pending task, idle fleet) → run that EA on ALL T1-T5
    via p2_baseline.py without --terminal arg (legacy mode, p2_baseline
    distributes symbols across T1-T5 in its own ThreadPoolExecutor). This
    saturates the fleet WITHIN one EA.

    Multi-EA case (≥2 pending tasks, or some terminals already busy) → assign
    one EA per free terminal up to 5 concurrent. Each EA runs its symbols
    sequentially on its assigned terminal (p2_baseline --terminal Tn). This
    saturates the fleet ACROSS EAs.

    Two complementary modes cover the throughput spectrum:
    - Pipeline starting up / single-EA-in-flight → ALL mode (5x faster per EA)
    - Pipeline saturated / many EAs queued → per-terminal mode (5x EAs in parallel)

    Order of operations:
    1. Poll every active backtest task. If its report.csv exists, classify
       and mark done. If older than timeout_hours with no report, mark failed.
       For ALL-mode tasks, mark all 5 terminals busy while running.
    2. Decide mode:
       - If exactly 1 pending task AND 0 busy terminals → spawn in ALL mode
       - Else → assign one task per free terminal
       Spawn the phase runner accordingly, record assignment in task payload.

    HR16-saturate: at the EA level, multiple EAs can be in P2 concurrently
    via per-terminal mode. HR16-strict still holds at the source-research
    level (one active source for mining).
    """
    init_db(root)
    actions: list[dict[str, Any]] = []
    started_iso = utc_now()
    busy_terminals: set[str] = set()

    with connect(root) as conn:
        # Phase 1 — poll all active backtest tasks
        active_rows = conn.execute(
            "SELECT * FROM tasks WHERE kind LIKE 'backtest_%' AND status = 'active' "
            "ORDER BY created_at"
        ).fetchall()

        for row in active_rows:
            payload = json.loads(row["payload_json"])
            phase = payload.get("phase", "?")
            ea_id = payload.get("ea_id")
            assigned_terminal = payload.get("assigned_terminal")

            report = _resolve_report(payload)
            if report is not None and report.exists():
                # report.csv exists, but the runners (p2_baseline / p3_param_sweep
                # / etc.) append rows live during the run — classifying as soon
                # as the file appears means we see only the first row.
                # QM5_1049 16:20: STRATEGY_FAIL locked in after only NDX FAIL
                # had been written; WS30/UK100/GDAXI (all PASS) arrived later.
                # Gate classification on the sentinel JSON
                # `<phase_lower>_<ea>_result.json` that each runner writes
                # ONLY after all rows finish.
                phase_lower = phase.lower().replace(".", "")  # P3.5 → p35
                sentinel = report.parent / f"{phase_lower}_{ea_id}_result.json"
                if not sentinel.exists():
                    # Still running — fall through to age/timeout check below.
                    pass
                else:
                    classification = classify_backtest(phase, report)
                    verdict = classification.get("verdict")
                    attempt = int(payload.get("attempt_count", 0)) + 1
                    MAX_BACKTEST_RETRIES = 3
                    # INFRA_FAIL = setup/data problem (not strategy fail);
                    # safe + valuable to retry. STRATEGY_FAIL/PASS are
                    # terminal verdicts — keep done.
                    if verdict == "INFRA_FAIL" and attempt < MAX_BACKTEST_RETRIES:
                        update_task(
                            conn,
                            row["id"],
                            status="pending",
                            payload_merge={
                                "attempt_count": attempt,
                                "last_infra_fail_at": started_iso,
                                "last_infra_fail_classification": classification,
                                "pid": None,
                                "started_at_iso": None,
                                "assigned_terminal": None,
                                "dispatch_mode": None,
                                "log_path": None,
                            },
                        )
                        actions.append({
                            "task_id": row["id"],
                            "action": "retry_infra_fail",
                            "phase": phase,
                            "ea_id": ea_id,
                            "attempt_count": attempt,
                        })
                        continue
                    update_task(
                        conn,
                        row["id"],
                        status="done",
                        payload_merge={
                            "classification": classification,
                            "completed_at_iso": started_iso,
                            "expected_report_path": str(report),
                            "p2_sentinel_path": str(sentinel),
                            "attempt_count": attempt,
                        },
                    )
                    actions.append({
                        "task_id": row["id"],
                        "action": "classified",
                        "phase": phase,
                        "ea_id": ea_id,
                        "terminal_released": assigned_terminal,
                        "verdict": verdict,
                        "surviving_symbols": classification.get("surviving_symbols", []),
                    })
                    continue

            start_iso = payload.get("started_at_iso")
            age_hours = 0.0
            if start_iso:
                try:
                    start_dt = dt.datetime.fromisoformat(start_iso.replace("Z", "+00:00"))
                    age_hours = (dt.datetime.now(dt.UTC) - start_dt).total_seconds() / 3600.0
                except Exception:
                    age_hours = 0.0
            if age_hours > timeout_hours:
                # OWNER 2026-05-16 "Wenn etwas scheitert, solls hinten
                # angereiht werden an die Liste." Auto-retry: increment
                # attempt_count, re-queue to pending (= back of FIFO by
                # updated_at). Cap retries at MAX_BACKTEST_RETRIES so we
                # don't loop forever on a genuinely broken job.
                attempt = int(payload.get("attempt_count", 0)) + 1
                MAX_BACKTEST_RETRIES = 3
                if attempt < MAX_BACKTEST_RETRIES:
                    update_task(
                        conn,
                        row["id"],
                        status="pending",
                        payload_merge={
                            "attempt_count": attempt,
                            "last_timeout_at": started_iso,
                            "last_timeout_reason": f"no report after {age_hours:.2f}h",
                            # Clear dispatch metadata so re-dispatch is clean
                            "pid": None,
                            "started_at_iso": None,
                            "assigned_terminal": None,
                            "dispatch_mode": None,
                            "log_path": None,
                        },
                    )
                    actions.append({
                        "task_id": row["id"],
                        "action": "retry",
                        "phase": phase,
                        "ea_id": ea_id,
                        "attempt_count": attempt,
                        "age_hours": round(age_hours, 2),
                    })
                else:
                    update_task(
                        conn,
                        row["id"],
                        status="failed",
                        payload_merge={
                            "timeout_reason": f"no report after {age_hours:.2f}h (limit {timeout_hours}h)",
                            "completed_at_iso": started_iso,
                            "attempt_count": attempt,
                            "final_failure": "retries_exhausted",
                        },
                    )
                    actions.append({
                        "task_id": row["id"],
                        "action": "failed_final",
                        "phase": phase,
                        "ea_id": ea_id,
                        "attempts": attempt,
                    })
                continue

            # Still running — terminal stays busy
            # ALL mode: this task occupies the whole fleet
            if assigned_terminal == "ALL":
                busy_terminals.update(MT5_TERMINALS)
            elif assigned_terminal:
                busy_terminals.add(assigned_terminal)
            actions.append({
                "task_id": row["id"],
                "action": "still_running",
                "phase": phase,
                "ea_id": ea_id,
                "terminal": assigned_terminal,
                "pid": payload.get("pid"),
                "age_hours": round(age_hours, 2),
            })

        # Phase 2 — pick dispatch mode based on pending count + fleet state
        free_terminals = [t for t in MT5_TERMINALS if t not in busy_terminals]
        pending_rows = conn.execute(
            "SELECT * FROM tasks WHERE kind LIKE 'backtest_%' AND status = 'pending' "
            "ORDER BY created_at"
        ).fetchall()

        # Hybrid: single-EA-in-flight + idle fleet → ALL mode (full saturation
        # within one EA, p2_baseline distributes its symbols across T1-T5).
        # Else: per-terminal mode (multi-EA saturates across EAs).
        use_all_mode = (
            len(pending_rows) == 1
            and len(busy_terminals) == 0
            and len(free_terminals) == len(MT5_TERMINALS)
        )
        dispatch_mode = "single_ea_all_terminals" if use_all_mode else "per_terminal"

        if use_all_mode:
            pending_row = pending_rows[0]
            payload = json.loads(pending_row["payload_json"])
            phase = payload.get("phase")
            ea_id = payload.get("ea_id")
            surviving_symbols = payload.get("surviving_symbols")
            cmd = _phase_runner_cmd(phase, ea_id, terminal=None, surviving_symbols=surviving_symbols)  # no --terminal = all-T1-T5
            if cmd is None:
                update_task(
                    conn,
                    pending_row["id"],
                    status="failed",
                    payload_merge={"failure_reason": f"no runner for phase {phase}"},
                )
                actions.append({
                    "task_id": pending_row["id"],
                    "action": "no_runner",
                    "phase": phase,
                    "ea_id": ea_id,
                })
            else:
                log_path = root / "logs" / f"dispatch_{pending_row['id']}.log"
                log_path.parent.mkdir(parents=True, exist_ok=True)
                creationflags = 0
                if sys.platform == "win32":
                    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS  # type: ignore[attr-defined]
                log_fh = open(log_path, "w", encoding="utf-8")
                env = {**os.environ, "PYTHONPATH": str(REPO_ROOT)}
                proc = subprocess.Popen(
                    cmd,
                    cwd=str(REPO_ROOT),
                    stdout=log_fh,
                    stderr=subprocess.STDOUT,
                    creationflags=creationflags,
                    close_fds=True,
                    env=env,
                )
                update_task(
                    conn,
                    pending_row["id"],
                    status="active",
                    payload_merge={
                        "started_at_iso": started_iso,
                        "pid": proc.pid,
                        "log_path": str(log_path),
                        "cmd": cmd,
                        "assigned_terminal": "ALL",
                        "dispatch_mode": "single_ea_all_terminals",
                    },
                )
                busy_terminals.update(MT5_TERMINALS)
                actions.append({
                    "task_id": pending_row["id"],
                    "action": "started",
                    "phase": phase,
                    "ea_id": ea_id,
                    "terminal": "ALL",
                    "mode": "single_ea_all_terminals",
                    "pid": proc.pid,
                    "log_path": str(log_path),
                })
        else:
            # Per-terminal mode: 1 EA per free terminal
            for terminal in free_terminals:
                if not pending_rows:
                    break
                pending_row = pending_rows.pop(0)
                payload = json.loads(pending_row["payload_json"])
                phase = payload.get("phase")
                ea_id = payload.get("ea_id")
                surviving_symbols = payload.get("surviving_symbols")
                cmd = _phase_runner_cmd(phase, ea_id, terminal=terminal, surviving_symbols=surviving_symbols)
                if cmd is None:
                    update_task(
                        conn,
                        pending_row["id"],
                        status="failed",
                        payload_merge={"failure_reason": f"no runner for phase {phase}"},
                    )
                    actions.append({
                        "task_id": pending_row["id"],
                        "action": "no_runner",
                        "phase": phase,
                        "ea_id": ea_id,
                    })
                    continue

                log_path = root / "logs" / f"dispatch_{pending_row['id']}.log"
                log_path.parent.mkdir(parents=True, exist_ok=True)
                creationflags = 0
                if sys.platform == "win32":
                    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS  # type: ignore[attr-defined]
                log_fh = open(log_path, "w", encoding="utf-8")
                env = {**os.environ, "PYTHONPATH": str(REPO_ROOT)}
                proc = subprocess.Popen(
                    cmd,
                    cwd=str(REPO_ROOT),
                    stdout=log_fh,
                    stderr=subprocess.STDOUT,
                    creationflags=creationflags,
                    close_fds=True,
                    env=env,
                )
                update_task(
                    conn,
                    pending_row["id"],
                    status="active",
                    payload_merge={
                        "started_at_iso": started_iso,
                        "pid": proc.pid,
                        "log_path": str(log_path),
                        "cmd": cmd,
                        "assigned_terminal": terminal,
                        "dispatch_mode": "per_terminal",
                    },
                )
                busy_terminals.add(terminal)
                actions.append({
                    "task_id": pending_row["id"],
                    "action": "started",
                    "phase": phase,
                    "ea_id": ea_id,
                    "terminal": terminal,
                    "mode": "per_terminal",
                    "pid": proc.pid,
                    "log_path": str(log_path),
                })

    return {
        "scanned_at": started_iso,
        "actions": actions,
        "busy_terminals": sorted(busy_terminals),
        "free_terminals": sorted([t for t in MT5_TERMINALS if t not in busy_terminals]),
        "mode": dispatch_mode if pending_rows or actions else "idle",
    }


def render_codex_build_prompt(root: Path, card_path_str: str, out_path: str | None) -> dict[str, Any]:
    """Validate an APPROVED card, create a build_ea task, render the Codex prompt."""
    init_db(root)
    card_path = Path(card_path_str).resolve()
    if not card_path.exists():
        return {"written": False, "reason": f"Card path does not exist: {card_path}"}
    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    slug = fm.get("slug")
    g0_status = fm.get("g0_status")
    if not ea_id or not slug:
        return {"written": False, "reason": "Card missing ea_id or slug in frontmatter", "frontmatter": fm}
    if g0_status != "APPROVED":
        return {"written": False, "reason": f"Card g0_status must be APPROVED, got: {g0_status!r}"}

    ea_dir = FRAMEWORK_EAS_DIR / f"{ea_id}_{slug}"

    with connect(root) as conn:
        task_id = create_task(
            conn,
            kind="build_ea",
            source_id=None,
            card_id=ea_id,
            payload={
                "card_path": str(card_path),
                "ea_id": ea_id,
                "slug": slug,
                "ea_dir": str(ea_dir),
                "frontmatter": fm,
            },
        )

    build_result_path = root / "artifacts" / "builds" / f"{task_id}.json"
    build_result_path.parent.mkdir(parents=True, exist_ok=True)

    template = CODEX_BUILD_TEMPLATE.read_text(encoding="utf-8")
    values = {
        "task_id": task_id,
        "ea_id": ea_id,
        "slug": slug,
        "card_path": str(card_path),
        "source_id": "",
        "ea_dir": str(ea_dir),
        "build_result_path": str(build_result_path),
    }
    prompt = template
    for k, v in values.items():
        prompt = prompt.replace("{{" + k + "}}", str(v))

    target = Path(out_path) if out_path else root / "queue" / f"codex_build_{task_id}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(prompt, encoding="utf-8", newline="\n")

    return {
        "written": True,
        "task_id": task_id,
        "ea_id": ea_id,
        "ea_dir": str(ea_dir),
        "prompt_path": str(target),
        "build_result_path": str(build_result_path),
        "suggested_command": (
            # ChatGPT-account Codex (v0.130+): default gpt-5.5 works.
            # gpt-5-codex / gpt-5-codex-mini / gpt-5 are 400 on ChatGPT auth.
            # -s danger-full-access required: workspace-write blocks pwsh subprocess
            # commands by codex policy, even though it permits file writes. Codex
            # needs to invoke pwsh for build_check / compile_one / gen_setfile /
            # run_smoke. Constrained externally by the build prompt + build_check.ps1.
            # [windows] sandbox = "elevated" was removed from ~/.codex/config.toml
            # 2026-05-16 (lockout incident) — Codex now uses cross-platform sandbox.
            # Prompt MUST be piped via stdin, NOT passed as a CLI arg: passing as
            # arg makes codex print "Reading additional input from stdin..." and
            # hang waiting for stdin EOF that the inherited claude pipe never
            # delivers (observed 2026-05-16: 18 min hang, codex CPU=0s).
            # Output is tee'd to a per-build live log so OWNER can Get-Content -Wait
            # without depending on the buffered wake session log.
            f"cat '{target}' | codex exec -s danger-full-access --cd \"{REPO_ROOT}\" 2>&1 "
            f"| tee 'D:/QM/strategy_farm/logs/codex_build_{task_id}.live.log'"
        ),
    }


def update_card_frontmatter(card_path: Path, updates: dict[str, str]) -> None:
    """Patch flat key:value pairs in a card's YAML frontmatter, in-place.

    Replaces existing keys; appends new ones at the end of the frontmatter block.
    Preserves the rest of the file verbatim.
    """
    text = card_path.read_text(encoding="utf-8")
    m = re.match(r"^(---\s*\n)(.*?)(\n---)", text, re.DOTALL)
    if not m:
        raise ValueError(f"No YAML frontmatter found in {card_path}")
    fm_block = m.group(2)
    lines = fm_block.split("\n")
    handled: set[str] = set()
    for i, line in enumerate(lines):
        for key, value in updates.items():
            if key in handled:
                continue
            if re.match(rf"^{re.escape(key)}\s*:", line):
                lines[i] = f"{key}: {value}"
                handled.add(key)
    for key, value in updates.items():
        if key not in handled:
            lines.append(f"{key}: {value}")
    new_fm = "\n".join(lines)
    new_text = m.group(1) + new_fm + m.group(3) + text[m.end():]
    card_path.write_text(new_text, encoding="utf-8", newline="\n")


VALID_SOURCE_TYPES = (
    "book", "paper", "web_forum", "web_blog",
    "mql5_codebase", "mql5_articles", "video", "local_archive",
)
VALID_LANES = ("research", "recovery", "legacy", "discovery")


def add_source(
    root: Path,
    uri: str,
    title: str,
    source_type: str,
    lane: str = "research",
    priority: int = 70,
) -> dict[str, Any]:
    """Add a new source to the queue (e.g. discovered by autonomous source-scan)."""
    init_db(root)
    if source_type not in VALID_SOURCE_TYPES:
        return {
            "added": False,
            "reason": f"source_type must be one of {VALID_SOURCE_TYPES}",
        }
    if lane not in VALID_LANES:
        return {"added": False, "reason": f"lane must be one of {VALID_LANES}"}
    if not uri or not title:
        return {"added": False, "reason": "uri and title are required"}

    sid = source_id({"source_type": source_type, "uri": uri})
    now = utc_now()
    with connect(root) as conn:
        existing = conn.execute("SELECT id, status FROM sources WHERE id = ?", (sid,)).fetchone()
        if existing is not None:
            return {
                "added": False,
                "reason": "Source with same (source_type, uri) already exists",
                "existing_id": existing["id"],
                "existing_status": existing["status"],
            }
        try:
            conn.execute(
                """
                INSERT INTO sources(
                    id, priority, lane, source_type, uri, title, status,
                    notes_path, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, 'pending', NULL, ?, ?)
                """,
                (sid, priority, lane, source_type, uri, title, now, now),
            )
            event(conn, "source", sid, "added", {
                "priority": priority,
                "lane": lane,
                "source_type": source_type,
                "uri": uri,
                "title": title,
            })
        except sqlite3.IntegrityError as exc:
            return {"added": False, "reason": f"IntegrityError: {exc}"}

    write_sources_jsonl(root)
    return {
        "added": True,
        "source_id": sid,
        "priority": priority,
        "lane": lane,
        "source_type": source_type,
        "uri": uri,
        "title": title,
        "next_action_hint": "python tools/strategy_farm/farmctl.py status",
    }


def approve_card(root: Path, card_path_str: str, reasoning: str) -> dict[str, Any]:
    """Set g0_status: APPROVED in the card frontmatter, move draft → approved."""
    init_db(root)
    card_path = Path(card_path_str).resolve()
    if not card_path.exists():
        return {"approved": False, "reason": f"Card not found: {card_path}"}
    if not reasoning:
        return {"approved": False, "reason": "reasoning is required"}

    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    if not ea_id:
        return {"approved": False, "reason": "Card frontmatter missing ea_id"}

    today = dt.datetime.now(dt.UTC).strftime("%Y-%m-%d")
    quoted = '"' + reasoning.replace('"', "'").replace("\n", " ").strip()[:300] + '"'
    update_card_frontmatter(card_path, {
        "g0_status": "APPROVED",
        "g0_approval_reasoning": quoted,
        "last_updated": today,
    })

    target_dir = root / "artifacts" / "cards_approved"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / card_path.name
    if target.exists():
        return {
            "approved": False,
            "reason": f"Approved card already at {target} — manual reconciliation needed",
        }

    # Move only if the source is in cards_draft/. Otherwise leave in place (already-approved card).
    src_in_draft = "cards_draft" in card_path.parts
    if src_in_draft:
        import shutil
        shutil.move(str(card_path), str(target))
        final_path = target
    else:
        final_path = card_path

    with connect(root) as conn:
        event(conn, "card", ea_id, "approved", {
            "card_path": str(final_path),
            "reasoning": reasoning[:300],
        })

    return {
        "approved": True,
        "ea_id": ea_id,
        "card_path": str(final_path),
        "reasoning": reasoning,
        "next_action_hint": f"python tools/strategy_farm/farmctl.py build-ea --card \"{final_path}\"",
    }


def _find_cards_by_source_id(root: Path, target_source_id: str) -> dict[str, list[Path]]:
    """Find all cards across draft/approved/rejected dirs whose frontmatter source_id matches."""
    result: dict[str, list[Path]] = {"draft": [], "approved": [], "rejected": []}
    for state, subdir in [
        ("draft", "cards_draft"),
        ("approved", "cards_approved"),
        ("rejected", "cards_rejected"),
    ]:
        d = root / "artifacts" / subdir
        if not d.exists():
            continue
        for card_path in d.glob("*.md"):
            try:
                fm = parse_card_frontmatter(card_path)
            except Exception:
                continue
            if fm.get("source_id") == target_source_id:
                result[state].append(card_path)
    return result


def _card_pipeline_state(conn: sqlite3.Connection, card_path: Path, state: str) -> str:
    """Return 'done' (reached pipeline-end) or 'in_flight'.

    Rules (v1 — until P3+ classifiers wired):
    - card in cards_rejected/ → 'done' (REJECTED at G0)
    - card in cards_draft/ → 'in_flight' (awaiting G0 verdict)
    - card in cards_approved/:
        - no build_ea task → 'in_flight' (awaiting Codex)
        - build_ea status='failed' or 'blocked' → 'done' (DEAD before backtest)
        - build_ea status='done' but no ea_review → 'in_flight'
        - ea_review status='done' with REJECT_REWORK → 'in_flight' (rework pending)
        - ea_review status='done' with APPROVE_FOR_BACKTEST + no backtest_p2 task → 'in_flight'
        - backtest_p2 status='pending' or 'active' → 'in_flight'
        - backtest_p2 status='done' or 'failed' → 'done' (terminal at P2 in v1)
    """
    if state == "rejected":
        return "done"
    if state == "draft":
        return "in_flight"
    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    if not ea_id:
        return "in_flight"

    rows = conn.execute(
        "SELECT kind, status, payload_json FROM tasks WHERE card_id = ? ORDER BY created_at ASC",
        (ea_id,),
    ).fetchall()
    if not rows:
        return "in_flight"  # approved but no build task yet

    build_task = next((r for r in rows if r["kind"] == "build_ea"), None)
    review_task = next((r for r in rows if r["kind"] == "ea_review"), None)
    backtest_task = next((r for r in rows if r["kind"].startswith("backtest_")), None)

    if build_task is None:
        return "in_flight"
    if build_task["status"] in ("failed", "blocked"):
        return "done"
    if build_task["status"] != "done":
        return "in_flight"
    # build_ea done — need review
    if review_task is None:
        return "in_flight"
    if review_task["status"] != "done":
        return "in_flight"
    # review done — read verdict
    review_payload = json.loads(review_task["payload_json"] or "{}")
    verdict_doc = review_payload.get("verdict") or {}
    if verdict_doc.get("verdict") != "APPROVE_FOR_BACKTEST":
        # REJECT_REWORK or unknown — Codex rework pending
        return "in_flight"
    # APPROVE — need backtest
    if backtest_task is None:
        return "in_flight"
    if backtest_task["status"] in ("done", "failed", "blocked"):
        return "done"
    return "in_flight"


def resume_mining(root: Path) -> dict[str, Any]:
    """Walk all sources with status='cards_ready'; flip back to 'active' for any whose
    drafted card batch has fully reached pipeline-end. Returns summary of actions taken."""
    init_db(root)
    scan_at = utc_now()
    results: list[dict[str, Any]] = []
    with connect(root) as conn:
        paused = conn.execute(
            "SELECT id, title, priority FROM sources "
            "WHERE status = 'cards_ready' ORDER BY priority"
        ).fetchall()
        for src in paused:
            cards = _find_cards_by_source_id(root, src["id"])
            states: list[str] = []
            for state, paths in cards.items():
                for p in paths:
                    states.append(_card_pipeline_state(conn, p, state))
            total = len(states)
            done = sum(1 for s in states if s == "done")
            in_flight = total - done

            if total == 0:
                results.append({
                    "source_id": src["id"],
                    "title": src["title"],
                    "action": "skipped_no_cards",
                    "reason": "no cards with this source_id — possible missing frontmatter field",
                })
                continue

            if in_flight == 0:
                conn.execute(
                    "UPDATE sources SET status = 'active', updated_at = ? WHERE id = ?",
                    (scan_at, src["id"]),
                )
                event(conn, "source", src["id"], "resumed", {
                    "previous_status": "cards_ready",
                    "cards_in_batch": total,
                    "reason": "all batch cards reached pipeline-end",
                })
                results.append({
                    "source_id": src["id"],
                    "title": src["title"],
                    "action": "resumed",
                    "cards_in_batch": total,
                })
            else:
                results.append({
                    "source_id": src["id"],
                    "title": src["title"],
                    "action": "still_waiting",
                    "cards_in_batch": total,
                    "done": done,
                    "in_flight": in_flight,
                })

    return {
        "scanned_at": scan_at,
        "checked_sources": len(results),
        "resumed_count": sum(1 for r in results if r["action"] == "resumed"),
        "results": results,
    }


def reject_card(root: Path, card_path_str: str, reason: str) -> dict[str, Any]:
    """Set g0_status: REJECTED in the card frontmatter, move draft → rejected."""
    init_db(root)
    card_path = Path(card_path_str).resolve()
    if not card_path.exists():
        return {"rejected": False, "reason": f"Card not found: {card_path}"}
    if not reason:
        return {"rejected": False, "reason": "reason is required"}

    fm = parse_card_frontmatter(card_path)
    ea_id = fm.get("ea_id", "UNKNOWN")

    today = dt.datetime.now(dt.UTC).strftime("%Y-%m-%d")
    quoted = '"' + reason.replace('"', "'").replace("\n", " ").strip()[:300] + '"'
    update_card_frontmatter(card_path, {
        "g0_status": "REJECTED",
        "g0_rejection_reason": quoted,
        "last_updated": today,
    })

    target_dir = root / "artifacts" / "cards_rejected"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / card_path.name
    if target.exists():
        return {
            "rejected": False,
            "reason": f"Rejected card already at {target} — manual reconciliation needed",
        }

    if "cards_draft" in card_path.parts:
        import shutil
        shutil.move(str(card_path), str(target))
        final_path = target
    else:
        final_path = card_path

    with connect(root) as conn:
        event(conn, "card", ea_id, "rejected", {
            "card_path": str(final_path),
            "reason": reason[:300],
        })

    return {
        "rejected": True,
        "ea_id": ea_id,
        "card_path": str(final_path),
        "reason": reason,
    }


def record_build_result(root: Path, task_id: str, result_file: str) -> dict[str, Any]:
    """Read Codex's build result JSON, transition the build_ea task."""
    init_db(root)
    rp = Path(result_file).resolve()
    if not rp.exists():
        return {"recorded": False, "reason": f"Result file not found: {rp}"}
    try:
        result = json.loads(rp.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"recorded": False, "reason": f"Invalid JSON in {rp}: {exc}"}

    blocked = result.get("blocked_reason")
    smoke = result.get("smoke_result")
    if blocked:
        new_status = "blocked"
    elif smoke in ("passed", "zero_trades"):
        # zero_trades per HR7 is a setup question, not a strategy fail — still proceed to review
        new_status = "done"
    else:
        new_status = "failed"

    with connect(root) as conn:
        updated = update_task(conn, task_id, status=new_status, payload_merge={"codex_result": result})
    if updated is None:
        return {"recorded": False, "reason": f"Task not found: {task_id}"}
    return {
        "recorded": True,
        "task_id": task_id,
        "new_status": new_status,
        "smoke_result": smoke,
        "blocked_reason": blocked,
        "next_action_hint": (
            f"python tools/strategy_farm/farmctl.py claude-review-prompt --build-task-id {task_id}"
            if new_status == "done" else f"Build failed/blocked. Inspect {rp} and rework or escalate."
        ),
    }


def render_claude_review_prompt(root: Path, build_task_id: str, out_path: str | None) -> dict[str, Any]:
    """Create an ea_review task and render the Claude review prompt."""
    init_db(root)
    with connect(root) as conn:
        row = conn.execute("SELECT * FROM tasks WHERE id = ?", (build_task_id,)).fetchone()
    if row is None:
        return {"written": False, "reason": f"Build task not found: {build_task_id}"}
    if row["kind"] != "build_ea":
        return {"written": False, "reason": f"Task {build_task_id} kind={row['kind']!r}, expected build_ea"}
    payload = json.loads(row["payload_json"])
    codex_result = payload.get("codex_result")
    if not codex_result:
        return {
            "written": False,
            "reason": "Build task has no codex_result. Call record-build first.",
        }

    with connect(root) as conn:
        review_task_id = create_task(
            conn,
            kind="ea_review",
            source_id=row["source_id"],
            card_id=row["card_id"],
            payload={
                "build_task_id": build_task_id,
                "ea_id": payload.get("ea_id"),
                "card_path": payload.get("card_path"),
                "mq5_path": codex_result.get("mq5_path"),
                "ex5_path": codex_result.get("ex5_path"),
                "smoke_report_path": codex_result.get("smoke_report_path"),
                "build_result_path": str(root / "artifacts" / "builds" / f"{build_task_id}.json"),
            },
        )

    verdict_path = root / "artifacts" / "verdicts" / f"review_{review_task_id}.json"
    verdict_path.parent.mkdir(parents=True, exist_ok=True)

    template = CLAUDE_REVIEW_TEMPLATE.read_text(encoding="utf-8")
    values = {
        "review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "ea_id": payload.get("ea_id") or "",
        "card_path": payload.get("card_path") or "",
        "mq5_path": codex_result.get("mq5_path") or "",
        "ex5_path": codex_result.get("ex5_path") or "",
        "smoke_report_path": codex_result.get("smoke_report_path") or "",
        "build_result_path": str(root / "artifacts" / "builds" / f"{build_task_id}.json"),
        "verdict_path": str(verdict_path),
    }
    prompt = template
    for k, v in values.items():
        prompt = prompt.replace("{{" + k + "}}", str(v))

    target = Path(out_path) if out_path else root / "queue" / f"claude_review_{review_task_id}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(prompt, encoding="utf-8", newline="\n")

    return {
        "written": True,
        "review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "prompt_path": str(target),
        "verdict_path": str(verdict_path),
        "suggested_command": (
            "claude -p --permission-mode acceptEdits "
            f"--add-dir \"{REPO_ROOT}\" "
            f"--add-dir \"{root}\" "
            "--add-dir \"G:\\My Drive\\QuantMechanica - Company Reference\" "
            f"\"$(Get-Content -Raw '{target}')\""
        ),
    }


def record_review_result(root: Path, review_task_id: str, result_file: str) -> dict[str, Any]:
    """Read Claude's review verdict JSON, mark the ea_review task done."""
    init_db(root)
    rp = Path(result_file).resolve()
    if not rp.exists():
        return {"recorded": False, "reason": f"Verdict file not found: {rp}"}
    try:
        verdict = json.loads(rp.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"recorded": False, "reason": f"Invalid JSON in {rp}: {exc}"}

    decision = verdict.get("verdict")
    if decision not in ("APPROVE_FOR_BACKTEST", "REJECT_REWORK"):
        return {"recorded": False, "reason": f"Unknown verdict value: {decision!r}"}

    with connect(root) as conn:
        updated = update_task(
            conn,
            review_task_id,
            status="done",
            payload_merge={"verdict": verdict},
        )
    if updated is None:
        return {"recorded": False, "reason": f"Review task not found: {review_task_id}"}

    return {
        "recorded": True,
        "review_task_id": review_task_id,
        "verdict": decision,
        "rework_directives": verdict.get("rework_directives"),
        "findings_count": len(verdict.get("findings", []) or []),
        "next_action_hint": (
            "Ready for backtest dispatch (Phase C: enqueue-backtest)"
            if decision == "APPROVE_FOR_BACKTEST"
            else "Reopen build with rework_directives — re-render Codex prompt"
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
    sub.add_parser("pipeline", help="Per-EA lifecycle view (where does each EA stand?)")
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

    build_ea = sub.add_parser(
        "build-ea", help="Create a build_ea task and render the Codex EA-build prompt for an APPROVED card"
    )
    build_ea.add_argument("--card", required=True, help="Path to the APPROVED Strategy Card .md")
    build_ea.add_argument("--out", help="Override prompt output path")

    record_build = sub.add_parser("record-build", help="Record Codex build result JSON into the build_ea task")
    record_build.add_argument("--task-id", required=True)
    record_build.add_argument("--result-file", required=True, help="Path to Codex's build result JSON")

    review_prompt = sub.add_parser(
        "claude-review-prompt", help="Create an ea_review task and render the Claude EA-review prompt"
    )
    review_prompt.add_argument("--build-task-id", required=True)
    review_prompt.add_argument("--out", help="Override prompt output path")

    record_review = sub.add_parser("record-review", help="Record Claude review verdict JSON into the ea_review task")
    record_review.add_argument("--task-id", required=True, help="ea_review task id")
    record_review.add_argument("--result-file", required=True, help="Path to Claude's verdict JSON")

    sub.add_parser("mt5-slots", help="Show MT5 terminal process scan (running terminal64.exe count + window titles)")

    enqueue_bt = sub.add_parser(
        "enqueue-backtest",
        help="Create a backtest_<phase> task from an APPROVE_FOR_BACKTEST ea_review task",
    )
    enqueue_bt.add_argument("--review-task-id", required=True)
    enqueue_bt.add_argument("--phase", default="P2", choices=list(SUPPORTED_BACKTEST_PHASES))

    dispatch = sub.add_parser(
        "dispatch-tick",
        help="Advance backtest tasks one step: start one pending, poll active, classify completed",
    )
    dispatch.add_argument("--timeout-hours", type=float, default=6.0)

    tick = sub.add_parser(
        "tick",
        help="Single farm tick - runs dispatch-tick (and in future: post-classify chaining)",
    )
    tick.add_argument("--timeout-hours", type=float, default=6.0)

    approve = sub.add_parser(
        "approve-card",
        help="Set g0_status: APPROVED + move draft to approved + emit event",
    )
    approve.add_argument("--card", required=True, help="Path to the draft card .md")
    approve.add_argument("--reasoning", required=True, help="One-line R1-R4 rationale")

    reject = sub.add_parser(
        "reject-card",
        help="Set g0_status: REJECTED + move draft to rejected + emit event",
    )
    reject.add_argument("--card", required=True, help="Path to the draft card .md")
    reject.add_argument("--reason", required=True, help="One-line rejection reason")

    sub.add_parser(
        "resume-mining",
        help="Check cards_ready sources; flip back to active if their card batch is pipeline-done",
    )

    add_src = sub.add_parser(
        "add-source",
        help="Add a new source to the queue (used by autonomous source-discovery)",
    )
    add_src.add_argument("--uri", required=True, help="Canonical URI or path of the source")
    add_src.add_argument("--title", required=True, help="Human-readable title")
    add_src.add_argument(
        "--source-type", required=True,
        choices=list(VALID_SOURCE_TYPES),
        help="Source category",
    )
    add_src.add_argument(
        "--lane", default="research", choices=list(VALID_LANES),
        help="Routing lane",
    )
    add_src.add_argument("--priority", type=int, default=70, help="Lower = earlier")
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
    elif args.command == "pipeline":
        print_json(pipeline_view(root))
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
    elif args.command == "build-ea":
        print_json(render_codex_build_prompt(root, args.card, args.out))
    elif args.command == "record-build":
        print_json(record_build_result(root, args.task_id, args.result_file))
    elif args.command == "claude-review-prompt":
        print_json(render_claude_review_prompt(root, args.build_task_id, args.out))
    elif args.command == "record-review":
        print_json(record_review_result(root, args.task_id, args.result_file))
    elif args.command == "mt5-slots":
        print_json(get_mt5_status())
    elif args.command == "enqueue-backtest":
        print_json(enqueue_backtest(root, args.review_task_id, args.phase))
    elif args.command == "dispatch-tick":
        print_json(dispatch_tick(root, timeout_hours=args.timeout_hours))
    elif args.command == "tick":
        # v1 tick: just dispatch-tick. Future ticks will chain post-classify
        # advance (PASS → enqueue next phase / FAIL → mark EA DEAD) and
        # post-review auto-enqueue (APPROVE_FOR_BACKTEST → enqueue P2).
        print_json({
            "tick_at": utc_now(),
            "dispatch": dispatch_tick(root, timeout_hours=args.timeout_hours),
        })
    elif args.command == "approve-card":
        print_json(approve_card(root, args.card, args.reasoning))
    elif args.command == "reject-card":
        print_json(reject_card(root, args.card, args.reason))
    elif args.command == "resume-mining":
        print_json(resume_mining(root))
    elif args.command == "add-source":
        print_json(add_source(
            root,
            uri=args.uri,
            title=args.title,
            source_type=args.source_type,
            lane=args.lane,
            priority=args.priority,
        ))
    else:
        raise AssertionError(args.command)
    return 0


if __name__ == "__main__":
    sys.exit(main())
