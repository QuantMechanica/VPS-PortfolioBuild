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
import time
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
CODEX_RESEARCH_TEMPLATE = PROMPTS_DIR / "codex_research_source.md"
CLAUDE_REVIEW_TEMPLATE = PROMPTS_DIR / "claude_review_ea.md"
CODEX_REVIEW_TEMPLATE = PROMPTS_DIR / "codex_review_ea.md"
CODEX_G0_TEMPLATE = PROMPTS_DIR / "codex_g0_review.md"

PIPELINE_REPORT_ROOT = Path(r"D:\QM\reports\pipeline")
SUPPORTED_BACKTEST_PHASES = ("P2", "P3", "P3.5", "P4")  # 2026-05-17: extend chain to P3.5 (cross-symbol robustness) + P4 (walk-forward OOS)
MT5_TERMINALS = ("T1", "T2", "T3", "T4", "T5")  # factory fleet, used by dispatch-tick for per-EA terminal assignment
ZERO_TRADE_DEAD_THRESHOLD = 0.80
ZERO_TRADE_DEAD_MIN_DONE = 5
ZERO_TRADE_REWORK_DEDUP_HOURS = 6

# Known-good fallback paths for codex.cmd / claude.cmd. Required because
# scheduled tasks run as SYSTEM user, which has a minimal PATH that doesn't
# include npm globals (where these CLIs live). shutil.which() returns None
# under SYSTEM → spawned subprocesses fail with "'codex' is not recognized
# as an internal or external command". Try shutil.which first, then fall
# back to these.
_CODEX_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd")
_CLAUDE_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\claude.cmd")


def _resolve_codex() -> str:
    import shutil as _shutil
    p = _shutil.which("codex.cmd") or _shutil.which("codex")
    if p:
        return p
    if _CODEX_FALLBACK.exists():
        return str(_CODEX_FALLBACK)
    return "codex"  # let subprocess fail with a clear error


def _resolve_claude() -> str:
    import shutil as _shutil
    p = _shutil.which("claude.cmd") or _shutil.which("claude")
    if p:
        return p
    if _CLAUDE_FALLBACK.exists():
        return str(_CLAUDE_FALLBACK)
    return "claude"

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

            -- Per-(EA × symbol × phase × setfile) work units. One bundled
            -- `backtest_p<n>` task in `tasks` fans out into N rows here, one
            -- per setfile in the EA's sets/ dir. MT5 dispatcher claims rows
            -- one-by-one per free terminal — fail of one symbol no longer
            -- blocks the other 3, and the DB shows per-symbol state directly.
            -- Per OWNER 2026-05-16 vision: "endlose Liste, pro EA pro
            -- Symbol pro Phase, MT5 zieht raus, fail → ans Ende".
            CREATE TABLE IF NOT EXISTS work_items (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,             -- 'backtest' (more kinds later)
                phase TEXT NOT NULL,            -- 'P2', 'P3', etc.
                ea_id TEXT NOT NULL,            -- 'QM5_1049'
                symbol TEXT NOT NULL,           -- 'EURUSD.DWX'
                setfile_path TEXT NOT NULL,
                status TEXT NOT NULL CHECK (
                    status IN ('pending', 'active', 'done', 'failed')
                ),
                verdict TEXT,                   -- PASS/FAIL/INVALID (NULL until done)
                attempt_count INTEGER NOT NULL DEFAULT 0,
                parent_task_id TEXT,            -- FK to tasks(id) — the bundled backtest task
                evidence_path TEXT,             -- path to smoke summary.json
                claimed_by TEXT,                -- terminal name (T1..T5) when active
                payload_json TEXT NOT NULL,     -- extra context
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(parent_task_id) REFERENCES tasks(id)
            );

            CREATE INDEX IF NOT EXISTS idx_work_items_status_kind
                ON work_items(status, kind);
            CREATE INDEX IF NOT EXISTS idx_work_items_parent
                ON work_items(parent_task_id);
            CREATE INDEX IF NOT EXISTS idx_work_items_ea_phase
                ON work_items(ea_id, phase);
            """
        )
        # --- migrations (idempotent) ---
        # 2026-05-16: per OWNER, Codex also does research in parallel with
        # Claude. assigned_worker disambiguates active sources so both workers
        # never claim the same row. Old rows have NULL = treat as 'claude'.
        try:
            conn.execute("ALTER TABLE sources ADD COLUMN assigned_worker TEXT")
        except sqlite3.OperationalError:
            pass  # already exists


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


def work_items_view(root: Path, status_filter: str | None = None,
                    ea_filter: str | None = None) -> dict[str, Any]:
    """Per-symbol queue view — answers "which (EA × symbol × phase)
    units are pending/active/done/failed right now?"

    Output is the work_items table with optional filters.
    """
    init_db(root)
    query = "SELECT id, kind, phase, ea_id, symbol, status, verdict, attempt_count, parent_task_id, evidence_path, claimed_by, created_at, updated_at FROM work_items"
    where = []
    params: list[Any] = []
    if status_filter:
        where.append("status = ?")
        params.append(status_filter)
    if ea_filter:
        where.append("ea_id = ?")
        params.append(ea_filter)
    if where:
        query += " WHERE " + " AND ".join(where)
    query += " ORDER BY ea_id, phase, symbol"
    with connect(root) as conn:
        rows = rows_as_dicts(conn.execute(query, params).fetchall())
    summary: dict[str, dict[str, int]] = {}
    for r in rows:
        key = f"{r['phase']}_{r['status']}"
        if r.get('verdict'):
            key += f"_{r['verdict']}"
        summary[key] = summary.get(key, 0) + 1
    return {"items": rows, "summary": summary, "count": len(rows)}


def backfill_work_items(root: Path) -> dict[str, Any]:
    """One-shot: for every existing backtest_<phase> task in tasks, create
    matching work_items in the new table. Idempotent — skips parent_task_ids
    that already have work_items.

    For done tasks, also seed verdicts from the per-symbol report.csv rows
    so the work_items table reflects historical state.
    """
    init_db(root)
    created = 0
    skipped = 0
    seeded_verdicts = 0
    with connect(root) as conn:
        rows = conn.execute(
            "SELECT id, kind, status, payload_json FROM tasks WHERE kind LIKE 'backtest_%'"
        ).fetchall()
        for r in rows:
            existing = conn.execute(
                "SELECT COUNT(*) FROM work_items WHERE parent_task_id = ?",
                (r["id"],),
            ).fetchone()[0]
            if existing:
                skipped += 1
                continue
            payload = json.loads(r["payload_json"]) if r["payload_json"] else {}
            ea_id = payload.get("ea_id")
            phase = payload.get("phase") or r["kind"].replace("backtest_", "").upper()
            if not ea_id:
                continue
            surviving = payload.get("surviving_symbols")
            new_items = _create_backtest_work_items(
                conn, parent_task_id=r["id"], ea_id=ea_id, phase=phase,
                surviving_symbols=surviving,
            )
            created += len(new_items)
            # Seed verdicts from report.csv if task done
            if r["status"] == "done":
                report_csv = None
                erp = payload.get("expected_report_path")
                if erp and Path(erp).exists():
                    report_csv = Path(erp)
                else:
                    glob_pat = payload.get("expected_report_glob")
                    if glob_pat:
                        ms = glob.glob(glob_pat)
                        if ms:
                            report_csv = Path(ms[0])
                sym_to_verdict = {}
                sym_to_evidence = {}
                if report_csv and report_csv.exists():
                    try:
                        with report_csv.open(encoding="utf-8") as f:
                            for csv_row in csv.DictReader(f):
                                sym = csv_row.get("symbol")
                                if sym and csv_row.get("verdict"):
                                    sym_to_verdict[sym] = csv_row["verdict"]
                                    sym_to_evidence[sym] = csv_row.get("evidence", "")
                    except Exception:
                        pass
                for item in new_items:
                    v = sym_to_verdict.get(item["symbol"])
                    if v:
                        conn.execute(
                            "UPDATE work_items SET status='done', verdict=?, evidence_path=?, updated_at=? WHERE id=?",
                            (v, sym_to_evidence.get(item["symbol"]) or "", utc_now(), item["id"]),
                        )
                        seeded_verdicts += 1
                    else:
                        # Parent task is done but per-symbol verdict can't be
                        # recovered from report.csv (file moved, format change,
                        # etc.). Mark work_item done with INVALID so the new
                        # per-symbol dispatcher doesn't try to re-run it.
                        conn.execute(
                            "UPDATE work_items SET status='done', verdict='INVALID', payload_json=?, updated_at=? WHERE id=?",
                            (json.dumps({"backfill_note": "parent_done_no_per_symbol_data"}), utc_now(), item["id"]),
                        )
        conn.commit()
    return {"created": created, "skipped_parents": skipped, "seeded_verdicts": seeded_verdicts}


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


def _derive_verdict_from_summary(summary: dict[str, Any], min_trades: int = 5) -> tuple[str, str]:
    """Single-symbol verdict from a run_smoke summary.json. Returns (verdict, reason).

    Mirrors p2_baseline's derive_verdict: PASS if at least one run had
    ≥min_trades, else FAIL with reason. INVALID if model4 marker absent.
    """
    if summary.get("result") != "PASS":
        reasons = summary.get("reason_classes") or ["UNKNOWN"]
        return "FAIL", "run_smoke_fail:" + ";".join(reasons)
    if not summary.get("model4_log_marker_detected"):
        return "INVALID", "G1_NO_REAL_TICKS"
    runs = summary.get("runs") or []
    if not runs:
        return "INVALID", "no_runs_in_summary"
    trades = [int(r.get("total_trades", 0) or 0) for r in runs]
    if any(t >= min_trades for t in trades):
        return "PASS", ""
    return "FAIL", "MIN_TRADES_NOT_MET"


def _spawn_run_smoke_for_work_item(root: Path, item_row: sqlite3.Row,
                                    terminal: str) -> dict[str, Any]:
    """Spawn run_smoke.ps1 for one work_item, pinned to a specific terminal.

    Returns dict with spawn metadata. The PID + log_path + expected_summary
    dir are stored in the work_item payload so the next dispatch cycle can
    find the result.
    """
    ea_id = item_row["ea_id"]  # e.g. QM5_1049
    symbol = item_row["symbol"]
    setfile_path = item_row["setfile_path"]
    phase = item_row["phase"]

    # Resolve full EA dir name (with slug) for the -EALabel arg
    ea_root_dir = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root_dir.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return {"spawned": False, "reason": f"no EA dir for {ea_id}"}
    ea_dir_name = candidates[0].name
    period = _detect_ea_period(ea_id)
    numeric_id = int(re.match(r"^QM5_(\d+)$", ea_id).group(1))

    # Per-work-item report root keeps summaries discoverable
    report_root = Path(r"D:\QM\reports\work_items") / item_row["id"]
    report_root.mkdir(parents=True, exist_ok=True)
    log_path = root / "logs" / f"work_item_{item_row['id']}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)

    # OWNER 2026-05-17 iteration 7 throughput fix: backtests were taking
    # 41-61 min each because of (a) 6-year P2 window + (b) 2-run determinism
    # check. With 5 MT5 terminals, that's 5 work_items/hour. 64 pending →
    # 13h drain. Crippling for ablation/synth exploration.
    #
    # Fast-path for EXPLORATION children (ablation / grid / synth):
    #   - 1 run instead of 2 (skip determinism re-check; EA binary is same
    #     across siblings, original setfile got its check)
    #   - shorter window (2020-2022 = 3y instead of 2017-2022 = 6y)
    # Full-path for FIRST P2 (canonical _backtest.set, no exploration suffix):
    #   - Keep 2 runs + 6 years for rigor
    is_exploration = ("_ablation_" in setfile_path or "_grid_" in setfile_path
                      or "_synth_" in setfile_path)
    n_runs = "1" if is_exploration else "2"
    if phase == "P2":
        from_date = "2020.01.01" if is_exploration else "2017.01.01"
        to_date = "2022.12.31"
    else:
        from_date = None
        to_date = None
    year = 2024

    cmd = [
        "pwsh.exe", "-NoProfile", "-File",
        str(REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"),
        "-EAId", str(numeric_id),
        "-EALabel", ea_dir_name,
        "-Symbol", symbol,
        "-Year", str(year),
        "-Terminal", terminal,
        "-Period", period,
        "-Runs", n_runs,
        "-MinTrades", "5",
        "-Model", "4",
        "-SetFile", setfile_path,
        "-ReportRoot", str(report_root),
        "-AllowMissingRealTicksLogMarker",
        "-TimeoutSeconds", "1800",
    ]
    if from_date:
        cmd.extend(["-FromDate", from_date])
    if to_date:
        cmd.extend(["-ToDate", to_date])

    log_fh = open(log_path, "w", encoding="utf-8")
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    proc = subprocess.Popen(
        cmd,
        cwd=str(REPO_ROOT),
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "pid": proc.pid,
        "log_path": str(log_path),
        "report_root": str(report_root),
        "ea_dir_name": ea_dir_name,
    }


def dispatch_work_items(root: Path, timeout_minutes: float = 60.0) -> dict[str, Any]:
    """Per-(symbol, setfile) dispatcher. Replaces bundled p2_baseline fan-out.

    Phase 1: poll active work_items. If their report_root has a summary.json,
             parse + derive verdict + mark done. If too old, mark failed (auto-
             retry up to MAX_WORK_ITEM_RETRIES).
    Phase 2: claim pending work_items, one per free terminal, spawn run_smoke.
    Phase 3: aggregate — when ALL work_items for a parent_task_id are done,
             classify the bundled parent task and auto-enqueue next phase.
    """
    init_db(root)
    actions: list[dict[str, Any]] = []
    started_iso = utc_now()
    busy_terminals: set[str] = set()
    MAX_WORK_ITEM_RETRIES = 3

    # --- Phase 1: process active work_items ---
    with connect(root) as conn:
        active = conn.execute(
            "SELECT * FROM work_items WHERE status='active' ORDER BY updated_at"
        ).fetchall()
    for item in active:
        payload = json.loads(item["payload_json"]) if item["payload_json"] else {}
        report_root = payload.get("report_root")
        ea_dir_name = payload.get("ea_dir_name")
        terminal = item["claimed_by"]
        if terminal:
            busy_terminals.add(terminal)
        # Find newest summary.json under report_root
        summary_path = None
        if report_root and Path(report_root).is_dir():
            cands = sorted(
                Path(report_root).rglob("summary.json"),
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            if cands:
                summary_path = cands[0]
        if summary_path and summary_path.exists():
            try:
                summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
            except Exception as e:
                summary = None
            if summary:
                verdict, reason = _derive_verdict_from_summary(summary, min_trades=5)
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='done', verdict=?, evidence_path=?, payload_json=?, updated_at=? WHERE id=?",
                        (verdict, str(summary_path),
                         json.dumps({**payload, "verdict_reason": reason}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "classified_item", "item_id": item["id"],
                               "ea_id": item["ea_id"], "symbol": item["symbol"],
                               "verdict": verdict, "reason": reason,
                               "terminal_released": terminal})
                continue
        # Still no summary — first check if the run_smoke.ps1 child PID
        # is still alive. If it died without writing a summary (MT5 crash,
        # OS reboot, manual kill) we should release the terminal IMMEDIATELY
        # instead of waiting `timeout_minutes` for the slow path.
        worker_pid = payload.get("pid")
        worker_alive = False
        if worker_pid:
            try:
                _ps = subprocess.run(
                    ["powershell.exe", "-NoProfile", "-Command",
                     f"if (Get-Process -Id {int(worker_pid)} -ErrorAction SilentlyContinue) {{'alive'}}"],
                    capture_output=True, text=True, timeout=8,
                )
                worker_alive = "alive" in (_ps.stdout or "")
            except Exception:
                worker_alive = True  # can't tell — assume alive, defer to timeout path
        else:
            worker_alive = True  # no PID recorded — defer to timeout path

        started = payload.get("started_at_iso")
        age_min = 0.0
        if started:
            try:
                age_min = (dt.datetime.now(dt.UTC) - dt.datetime.fromisoformat(started.replace("Z", "+00:00"))).total_seconds() / 60.0
            except Exception:
                age_min = 0.0

        # Fast-fail: PID gone + nothing produced + > 1 min (avoid races on spawn)
        if not worker_alive and age_min > 1.0:
            attempt = item["attempt_count"] + 1
            if attempt < MAX_WORK_ITEM_RETRIES:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='pending', attempt_count=?, claimed_by=NULL, payload_json=?, updated_at=? WHERE id=?",
                        (attempt, json.dumps({**payload, "prior_failure": "worker_died"}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "retry_worker_died", "item_id": item["id"],
                                "terminal_released": terminal, "attempt": attempt})
            else:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='failed', verdict='INVALID', payload_json=?, updated_at=? WHERE id=?",
                        (json.dumps({**payload, "final_failure": "worker_died_retries_exhausted"}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "failed_worker_died", "item_id": item["id"]})
            continue

        if age_min > timeout_minutes:
            attempt = item["attempt_count"] + 1
            if attempt < MAX_WORK_ITEM_RETRIES:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='pending', attempt_count=?, claimed_by=NULL, payload_json=?, updated_at=? WHERE id=?",
                        (attempt, json.dumps({"prior_timeout": started}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "retry_timeout", "item_id": item["id"], "attempt": attempt})
            else:
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='failed', verdict='INVALID', payload_json=?, updated_at=? WHERE id=?",
                        (json.dumps({**payload, "final_failure": "retries_exhausted"}, sort_keys=True),
                         started_iso, item["id"]),
                    )
                    conn2.commit()
                busy_terminals.discard(terminal)
                actions.append({"action": "failed_final", "item_id": item["id"]})

    # --- Phase 2: claim pending work_items per free terminal ---
    # OWNER 2026-05-17 priority queue (replaces FIFO):
    #   1. Highest phase first (P4 > P3.5 > P3 > P2) — promotions get priority
    #      because they're already known winners advancing toward Live.
    #   2. EA-of-a-known-winner before greenfield (ea_id with prior PASSes).
    #   3. Then FIFO within tier (updated_at ASC).
    # The CASE WHEN encodes the priority. Lower number = sooner.
    free_terminals = [t for t in MT5_TERMINALS if t not in busy_terminals]
    if free_terminals:
        with connect(root) as conn:
            pending = conn.execute(
                """
                SELECT w.*,
                  CASE w.phase
                    WHEN 'P8'   THEN 0
                    WHEN 'P7'   THEN 1
                    WHEN 'P6'   THEN 2
                    WHEN 'P5c'  THEN 3
                    WHEN 'P5b'  THEN 4
                    WHEN 'P5'   THEN 5
                    WHEN 'P4'   THEN 6
                    WHEN 'P3.5' THEN 7
                    WHEN 'P3'   THEN 8
                    WHEN 'P2'   THEN 9
                    ELSE 9 END AS _phase_rank,
                  CASE WHEN EXISTS (
                    SELECT 1 FROM work_items wp
                    WHERE wp.ea_id=w.ea_id AND wp.status='done' AND wp.verdict='PASS'
                  ) THEN 0 ELSE 1 END AS _winner_rank
                FROM work_items w
                WHERE w.status='pending'
                ORDER BY _phase_rank ASC, _winner_rank ASC, w.updated_at ASC, w.created_at ASC
                """
            ).fetchall()
        for item in pending:
            if not free_terminals:
                break
            terminal = free_terminals.pop(0)
            spawn = _spawn_run_smoke_for_work_item(root, item, terminal)
            if not spawn.get("spawned"):
                # Mark failed if spawn impossible
                with connect(root) as conn2:
                    conn2.execute(
                        "UPDATE work_items SET status='failed', verdict='INVALID', updated_at=? WHERE id=?",
                        (started_iso, item["id"]),
                    )
                    conn2.commit()
                actions.append({"action": "spawn_failed", "item_id": item["id"], "reason": spawn.get("reason")})
                free_terminals.insert(0, terminal)  # give terminal back
                continue
            new_payload = {
                "started_at_iso": started_iso,
                "pid": spawn["pid"],
                "log_path": spawn["log_path"],
                "report_root": spawn["report_root"],
                "ea_dir_name": spawn["ea_dir_name"],
                "terminal": terminal,
            }
            with connect(root) as conn2:
                conn2.execute(
                    "UPDATE work_items SET status='active', claimed_by=?, payload_json=?, updated_at=? WHERE id=?",
                    (terminal, json.dumps(new_payload, sort_keys=True), started_iso, item["id"]),
                )
                conn2.commit()
            actions.append({
                "action": "claimed",
                "item_id": item["id"],
                "ea_id": item["ea_id"],
                "symbol": item["symbol"],
                "terminal": terminal,
                "pid": spawn["pid"],
            })

    # --- Phase 3: aggregate completed parents ---
    with connect(root) as conn:
        # Find parent_task_ids that have all work_items done but parent is still active/pending
        parent_summaries = conn.execute(
            """
            SELECT parent_task_id,
                   COUNT(*) AS total,
                   SUM(CASE WHEN status='done' OR status='failed' THEN 1 ELSE 0 END) AS finished,
                   SUM(CASE WHEN verdict='PASS' THEN 1 ELSE 0 END) AS passes
            FROM work_items
            WHERE parent_task_id IS NOT NULL
            GROUP BY parent_task_id
            HAVING total = finished
            """
        ).fetchall()
        for ps in parent_summaries:
            parent_id = ps["parent_task_id"]
            if not parent_id:
                continue
            parent_row = conn.execute("SELECT * FROM tasks WHERE id=?", (parent_id,)).fetchone()
            if not parent_row or parent_row["status"] == "done":
                continue
            # Build classification from work_items
            wis = conn.execute("SELECT * FROM work_items WHERE parent_task_id=?", (parent_id,)).fetchall()
            surviving = [w["symbol"] for w in wis if w["verdict"] == "PASS"]
            phase = parent_row["kind"].replace("backtest_", "").upper()
            verdict = "PASS" if surviving else "STRATEGY_FAIL"
            classification = {
                "verdict": verdict,
                "surviving_symbols": surviving,
                "counts_by_verdict": {
                    v: sum(1 for w in wis if w["verdict"] == v)
                    for v in ("PASS", "FAIL", "INVALID")
                },
                "source": "work_items_aggregate",
            }
            parent_payload = json.loads(parent_row["payload_json"]) if parent_row["payload_json"] else {}
            parent_payload["classification"] = classification
            parent_payload["completed_at_iso"] = started_iso
            conn.execute(
                "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
                (json.dumps(parent_payload), started_iso, parent_id),
            )
            conn.commit()
            # Auto-enqueue next phase on PASS
            auto_next = None
            if verdict == "PASS":
                next_map = {"P2": "P3", "P3": "P3.5", "P3.5": "P4"}
                npp = next_map.get(phase)
                if npp and npp in SUPPORTED_BACKTEST_PHASES:
                    npp_kind = npp.lower().replace(".", "")  # P3.5 → 'p35' for task kind
                    existing = conn.execute(
                        "SELECT id FROM tasks WHERE kind=? AND payload_json LIKE ?",
                        (f"backtest_{npp_kind}", f"%\"ea_id\": \"{parent_payload.get('ea_id')}\"%"),
                    ).fetchone()
                    if not existing:
                        enq = enqueue_backtest(root, parent_id, npp)
                        if enq.get("enqueued"):
                            auto_next = {"phase": npp, "task_id": enq.get("task_id"),
                                        "work_items_created": len(enq.get("work_items_created", []))}
            actions.append({
                "action": "parent_classified",
                "parent_task_id": parent_id,
                "ea_id": parent_payload.get("ea_id"),
                "phase": phase,
                "verdict": verdict,
                "surviving_symbols": surviving,
                "auto_next": auto_next,
            })

    return {
        "actions": actions,
        "busy_terminals": sorted(busy_terminals),
        "free_terminals": [t for t in MT5_TERMINALS if t not in busy_terminals],
        "scanned_at": started_iso,
    }


def _spawn_claude_for_review(root: Path, build_task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Claude CLI to review one done build_ea task.

    Renders the review prompt via render_claude_review_prompt, then invokes
    claude detached with -p pointing at the rendered prompt. The Claude
    process writes the verdict JSON to verdict_path itself per
    claude_review_ea.md output contract. Next pump cycle picks up the
    verdict and calls record-review.

    Idempotent: if an ea_review task already exists for this build, skip.
    """
    build_task_id = build_task_row["id"]
    # Check if review already exists
    with connect(root) as conn:
        existing = conn.execute(
            "SELECT id FROM tasks WHERE kind='ea_review' AND payload_json LIKE ?",
            (f"%\"build_task_id\": \"{build_task_id}\"%",),
        ).fetchone()
    if existing:
        return {"spawned": False, "reason": "ea_review task already exists", "review_task_id": existing[0]}

    # Render the prompt — also creates the ea_review task row
    rendered = render_claude_review_prompt(root, build_task_id, None)
    if not rendered.get("written"):
        return {"spawned": False, "reason": f"render failed: {rendered.get('reason')}"}
    prompt_path = rendered.get("prompt_path")
    review_task_id = rendered.get("review_task_id")
    verdict_path = rendered.get("verdict_path")

    import shutil as _shutil
    claude_path = _resolve_claude()
    live_log = root / "logs" / f"claude_review_{review_task_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)

    # Read prompt to embed as the -p argument (claude CLI doesn't accept stdin
    # for -p mode; the prompt is a single string arg with non-interactive output).
    prompt_text = Path(prompt_path).read_text(encoding="utf-8") if prompt_path else ""
    bootstrap = (
        "You are a focused QM EA reviewer. Read the prompt I pass + the referenced "
        "files (mq5, card, build_result, smoke_summary). Apply checklist sections "
        f"§0-§7 from claude_review_ea.md. Write the JSON verdict EXACTLY to "
        f"'{verdict_path}'. Then exit cleanly. No prose, no commentary outside "
        f"the JSON file.\n\nReview Prompt:\n\n{prompt_text}"
    )

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [claude_path, "-p", bootstrap,
         "--permission-mode", "bypassPermissions",
         "--add-dir", "C:\\QM\\repo",
         "--add-dir", "D:\\QM\\strategy_farm",
         "--add-dir", "D:\\QM\\reports"],
        cwd=str(REPO_ROOT),
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        shell=True,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "ea_id": rendered.get("ea_id"),
        "verdict_path": verdict_path,
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _g0_claim_path(card_path: Path) -> Path:
    """Lock path for atomic G0 claim. Lives next to the card in cards_draft/."""
    return card_path.with_suffix(card_path.suffix + ".g0_claim")


def _claim_g0_cards(card_paths: list[Path], reviewer: str, max_age_sec: int = 1800) -> list[Path]:
    """Atomically claim cards for a G0 reviewer. Returns the actually-claimed
    subset.

    Uses O_CREAT|O_EXCL — first writer wins. Skips cards whose claim file
    already exists AND is fresh (within max_age_sec, default 30 min).
    Stale claim files (older than that) get overwritten — means a previous
    spawn died mid-batch.
    """
    claimed: list[Path] = []
    now = time.time()
    for c in card_paths:
        lock = _g0_claim_path(c)
        if lock.exists():
            try:
                age = now - lock.stat().st_mtime
                if age < max_age_sec:
                    continue  # held by another reviewer
            except OSError:
                pass
        # Try to claim atomically. O_EXCL fails if file exists (race);
        # for stale locks we explicitly overwrite by rm + retry.
        try:
            if lock.exists():
                lock.unlink()
            fd = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            try:
                os.write(fd, f"reviewer={reviewer}\ntimestamp={utc_now()}\n".encode("utf-8"))
            finally:
                os.close(fd)
            claimed.append(c)
        except FileExistsError:
            continue  # lost the race to another spawner
        except OSError:
            continue
    return claimed


def _spawn_claude_for_g0_batch(root: Path) -> dict[str, Any]:
    """Spawn Claude for G0 review of up to 5 draft cards.

    OWNER 2026-05-17: Claude AND Codex both do G0 in parallel. Claim
    mechanism (filesystem .g0_claim locks) prevents double-review.

    Bounded at 5 cards per spawn to cap token burn.
    """
    import shutil as _shutil
    drafts_dir = root / "artifacts" / "cards_draft"
    if not drafts_dir.is_dir():
        return {"spawned": False, "reason": "no cards_draft dir"}
    # Oldest first, skip already-claimed
    drafts = sorted([f for f in drafts_dir.glob("QM5_*.md") if f.is_file()],
                    key=lambda p: p.stat().st_mtime)
    drafts = [d for d in drafts if not _g0_claim_path(d).exists() or
              (time.time() - _g0_claim_path(d).stat().st_mtime) >= 1800]
    if not drafts:
        return {"spawned": False, "reason": "no unclaimed draft cards"}
    batch = _claim_g0_cards(drafts[:5], reviewer="claude")
    if not batch:
        return {"spawned": False, "reason": "all candidates lost race to Codex"}
    batch_paths = "\n".join(f"- {f}" for f in batch)

    claude_path = _resolve_claude()
    live_log = root / "logs" / f"claude_g0_{dt.datetime.utcnow().strftime('%Y%m%dT%H%M%S')}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    if live_log.exists() and (time.time() - live_log.stat().st_mtime) < 60:
        return {"spawned": False, "reason": "claude g0 live log active < 60s"}

    bootstrap = (
        "You are doing focused QM G0 reviews. Read "
        "C:\\QM\\repo\\processes\\qb_reputable_source_criteria.md to refresh "
        "R1-R4 criteria. Then for each draft card in this batch:\n\n"
        f"{batch_paths}\n\n"
        "Apply R1 (source link/attribution), R2 (mechanical Entry+Exit rules), "
        "R3 (testable on >=1 DWX symbol after porting), R4 (no ML / binding HR14). "
        "For each card:\n"
        "  - All four PASS  -> run `python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py "
        "approve-card --card \"<path>\" --reasoning \"<R1-R4 one-line rationale>\"`\n"
        "  - Any FAIL       -> run `python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py "
        "reject-card --card \"<path>\" --reason \"<which R + why>\"`\n\n"
        "Use farmctl --help if argument names differ. SP500.DWX is now backtest-only "
        "available (2026-05-16T19:15Z) — R3 PASS with T6-caveat is acceptable. "
        "Process all cards in the batch, then exit cleanly."
    )

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [claude_path, "-p", bootstrap,
         "--permission-mode", "bypassPermissions",
         "--add-dir", "C:\\QM\\repo",
         "--add-dir", "D:\\QM\\strategy_farm"],
        cwd=str(REPO_ROOT),
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        shell=True,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "batch_size": len(batch),
        "cards": [f.stem for f in batch],
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _spawn_codex_for_g0_batch(root: Path) -> dict[str, Any]:
    """Spawn Codex for G0 review of up to 3 draft cards (smaller batch
    than Claude — Codex iterates through farmctl subprocesses serially).

    Runs IN PARALLEL with Claude G0 — claim mechanism prevents both
    workers from grabbing the same card.
    """
    import shutil as _shutil
    drafts_dir = root / "artifacts" / "cards_draft"
    if not drafts_dir.is_dir():
        return {"spawned": False, "reason": "no cards_draft dir"}
    drafts = sorted([f for f in drafts_dir.glob("QM5_*.md") if f.is_file()],
                    key=lambda p: p.stat().st_mtime)
    drafts = [d for d in drafts if not _g0_claim_path(d).exists() or
              (time.time() - _g0_claim_path(d).stat().st_mtime) >= 1800]
    if not drafts:
        return {"spawned": False, "reason": "no unclaimed draft cards"}
    # Codex grabs from the OLDER end too but offset 5 ahead of Claude so they
    # naturally pick different cards in low-pressure case; in high-pressure
    # case the claim race breaks ties.
    candidates = drafts[5:8] + drafts[:5]  # prefer older-but-not-Claude's-first-5
    batch = _claim_g0_cards(candidates, reviewer="codex")[:3]
    if not batch:
        return {"spawned": False, "reason": "all candidates already claimed"}
    batch_paths = "\n".join(f"- {f}" for f in batch)

    codex_path = _resolve_codex()
    ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
    live_log = root / "logs" / f"codex_g0_{ts}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    prompt_path = root / "queue" / f"codex_g0_{ts}.md"
    prompt_path.parent.mkdir(parents=True, exist_ok=True)

    template = CODEX_G0_TEMPLATE.read_text(encoding="utf-8")
    template = template.replace("{{batch_paths}}", batch_paths)
    prompt_path.write_text(template, encoding="utf-8", newline="\n")

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        shell=True,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "batch_size": len(batch),
        "cards": [f.stem for f in batch],
        "live_log": str(live_log),
        "prompt_path": str(prompt_path),
        "pid": proc.pid,
    }


def _claim_research_source(root: Path) -> dict[str, Any]:
    """Find next research work and spawn Claude.

    Priority:
      1. Any source with status='active' (continue mining its next batch)
      2. Any source with status='cards_ready' that is eligible to resume
         (its drafted cards have all reached pipeline-end)
      3. Any source with status='notes_ready' (cards can be drafted from notes)
      4. Claim oldest pending source (lowest priority numeric value)
    """
    import shutil as _shutil
    claude_path = _resolve_claude()

    # Skip if a Claude is already running for research.
    # assigned_worker IS NULL = legacy/pre-codex rows → treat as 'claude'.
    with connect(root) as conn:
        active_src = conn.execute(
            "SELECT id, lane, source_type, uri, title, status, notes_path "
            "FROM sources WHERE status='active' "
            "AND (assigned_worker IS NULL OR assigned_worker='claude') LIMIT 1"
        ).fetchone()
    target_source = None
    research_action = None
    if active_src:
        target_source = dict(active_src)
        research_action = "continue_active"
    else:
        # Resume cards_ready first (source flagged "more findable") so sources
        # actually reach 'done' instead of accumulating in cards_ready forever.
        with connect(root) as conn:
            cr = conn.execute(
                "SELECT id, lane, source_type, uri, title, status, notes_path "
                "FROM sources WHERE status='cards_ready' "
                "AND (assigned_worker IS NULL OR assigned_worker='claude') "
                "ORDER BY priority ASC, updated_at ASC LIMIT 1"
            ).fetchone()
        if cr:
            with connect(root) as conn:
                cur = conn.execute(
                    "UPDATE sources SET status='active', assigned_worker='claude', updated_at=? "
                    "WHERE id=? AND status='cards_ready'",
                    (utc_now(), cr["id"]),
                )
                conn.commit()
                claimed = cur.rowcount == 1
            if claimed:
                target_source = dict(cr)
                research_action = "resume_cards_ready"
        if not target_source:
            with connect(root) as conn:
                # try notes_ready next (cards waiting to be drafted)
                nr = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='notes_ready' LIMIT 1"
                ).fetchone()
            if nr:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='claude', updated_at=? "
                        "WHERE id=? AND status='notes_ready'",
                        (utc_now(), nr["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(nr)
                    research_action = "draft_cards_from_notes"
        if not target_source:
            with connect(root) as conn:
                pend = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='pending' "
                    "ORDER BY priority ASC, created_at ASC LIMIT 1"
                ).fetchone()
            if pend:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='claude', updated_at=? "
                        "WHERE id=? AND status='pending'",
                        (utc_now(), pend["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(pend)
                    target_source["status"] = "active"
                    research_action = "claim_pending_first_batch"
    if not target_source:
        return {"spawned": False, "reason": "no research work available"}

    src_id = target_source["id"]
    live_log = root / "logs" / f"claude_research_{src_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    if live_log.exists() and (time.time() - live_log.stat().st_mtime) < 60:
        return {"spawned": False, "reason": "claude research live log active < 60s", "source_id": src_id}

    bootstrap = (
        "You are a focused QM strategy researcher. Read "
        "C:\\QM\\repo\\tools\\strategy_farm\\prompts\\claude_research_source.md "
        "AND C:\\QM\\repo\\processes\\qb_reputable_source_criteria.md . "
        f"Mine source `{src_id}` ({target_source.get('title')}). "
        "Action: " + (research_action or "draft_cards") + ". "
        "Draft UP TO 5 new strategy cards into "
        "D:\\QM\\strategy_farm\\artifacts\\cards_draft\\QM5_<NNNN>_<slug>.md per the "
        "Strategy Wiki _TEMPLATE Strategy.md format with g0_status: PENDING. "
        "Allocate fresh QM5_<NNNN> IDs starting after the highest existing in "
        "framework/registry/ea_id_registry.csv. Append notes to "
        f"D:\\QM\\strategy_farm\\artifacts\\source_notes\\{src_id}.md. "
        "At end: if <5 cards or exhausted, run `farmctl set-source-status "
        f"{src_id} done`. If 5 cards + more findable, run `farmctl "
        f"set-source-status {src_id} cards_ready`. Exit cleanly."
    )
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [claude_path, "-p", bootstrap,
         "--permission-mode", "bypassPermissions",
         "--add-dir", "C:\\QM\\repo",
         "--add-dir", "D:\\QM\\strategy_farm",
         "--add-dir", "G:\\My Drive\\QuantMechanica - Company Reference"],
        cwd=str(REPO_ROOT),
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        shell=True,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "source_id": src_id,
        "title": target_source.get("title"),
        "research_action": research_action,
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _claim_research_source_codex(root: Path) -> dict[str, Any]:
    """Codex twin of `_claim_research_source`.

    Both workers use `status='active'`; the `assigned_worker` column
    ('claude' | 'codex' | NULL→claude) disambiguates so neither claims the
    other's source. The claim UPDATE is conditional on the prior status to
    avoid races when both pump cycles run close together.

    Priority:
      1. status='active' AND assigned_worker='codex' → continue mining
      2. status='notes_ready' (shared with Claude — first claim wins)
      3. status='pending'     (shared with Claude — first claim wins)
    """
    import shutil as _shutil
    codex_path = _resolve_codex()

    target_source = None
    research_action = None
    # Step 1: continue an active source already assigned to codex
    with connect(root) as conn:
        active_src = conn.execute(
            "SELECT id, lane, source_type, uri, title, status, notes_path "
            "FROM sources WHERE status='active' AND assigned_worker='codex' LIMIT 1"
        ).fetchone()
    if active_src:
        target_source = dict(active_src)
        research_action = "continue_active"
    else:
        # Step 2: resume a cards_ready source ("more findable" was flagged
        # by the prior run; we promised to come back and mine more).
        # Without this, every source gets exactly one 5-card session then
        # parked forever, and sources never reach 'done'.
        with connect(root) as conn:
            cr = conn.execute(
                "SELECT id, lane, source_type, uri, title, status, notes_path "
                "FROM sources WHERE status='cards_ready' "
                "ORDER BY priority ASC, updated_at ASC LIMIT 1"
            ).fetchone()
        if cr:
            with connect(root) as conn:
                cur = conn.execute(
                    "UPDATE sources SET status='active', assigned_worker='codex', updated_at=? "
                    "WHERE id=? AND status='cards_ready'",
                    (utc_now(), cr["id"]),
                )
                conn.commit()
                claimed = cur.rowcount == 1
            if claimed:
                target_source = dict(cr)
                research_action = "resume_cards_ready"
        # Step 3: try to claim a notes_ready source
        if not target_source:
            with connect(root) as conn:
                nr = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='notes_ready' LIMIT 1"
                ).fetchone()
            if nr:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='codex', updated_at=? "
                        "WHERE id=? AND status='notes_ready'",
                        (utc_now(), nr["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(nr)
                    research_action = "draft_cards_from_notes"
        if not target_source:
            # Step 4: claim pending oldest
            with connect(root) as conn:
                pend = conn.execute(
                    "SELECT id, lane, source_type, uri, title, status, notes_path "
                    "FROM sources WHERE status='pending' "
                    "ORDER BY priority ASC, created_at ASC LIMIT 1"
                ).fetchone()
            if pend:
                with connect(root) as conn:
                    cur = conn.execute(
                        "UPDATE sources SET status='active', assigned_worker='codex', updated_at=? "
                        "WHERE id=? AND status='pending'",
                        (utc_now(), pend["id"]),
                    )
                    conn.commit()
                    claimed = cur.rowcount == 1
                if claimed:
                    target_source = dict(pend)
                    research_action = "claim_pending_first_batch"
    if not target_source:
        return {"spawned": False, "reason": "no research work available for codex"}

    src_id = target_source["id"]
    live_log = root / "logs" / f"codex_research_{src_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    if live_log.exists() and (time.time() - live_log.stat().st_mtime) < 60:
        return {"spawned": False, "reason": "codex research live log active < 60s", "source_id": src_id}

    # Render bootstrap prompt from template
    prompt_path = root / "queue" / f"codex_research_{src_id}.md"
    prompt_path.parent.mkdir(parents=True, exist_ok=True)
    template = CODEX_RESEARCH_TEMPLATE.read_text(encoding="utf-8")
    for k, v in [
        ("source_id", src_id),
        ("title", target_source.get("title") or ""),
        ("uri", target_source.get("uri") or ""),
        ("action", research_action or ""),
    ]:
        template = template.replace("{{" + k + "}}", str(v))
    prompt_path.write_text(template, encoding="utf-8", newline="\n")

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        shell=True,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "source_id": src_id,
        "title": target_source.get("title"),
        "research_action": research_action,
        "live_log": str(live_log),
        "prompt_path": str(prompt_path),
        "pid": proc.pid,
    }


def _spawn_codex_for_review(root: Path, build_task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Codex CLI to mechanically pre-review one done build_ea task.

    Codex runs BEFORE Claude review (cheaper, deterministic). Codex's verdict
    JSON appears at `verdict_path`; if PASS → pump spawns Claude review; if
    FAIL → pump blocks the build with reason='codex_review_fail' so retry
    logic can re-run build (rework).

    Idempotent: if a codex_review task already exists for this build, skip.
    Creates a separate codex_review task row (distinct kind from ea_review)
    with payload.build_task_id + payload.verdict_path.
    """
    build_task_id = build_task_row["id"]
    with connect(root) as conn:
        existing = conn.execute(
            "SELECT id, status FROM tasks WHERE kind='codex_review' AND payload_json LIKE ?",
            (f"%\"build_task_id\": \"{build_task_id}\"%",),
        ).fetchone()
    if existing:
        return {
            "spawned": False,
            "reason": f"codex_review task exists status={existing['status']}",
            "codex_review_task_id": existing["id"],
        }

    payload_build = json.loads(build_task_row["payload_json"])
    codex_result = payload_build.get("codex_result") or {}
    mq5_path = codex_result.get("mq5_path") or ""
    ex5_path = codex_result.get("ex5_path") or ""
    smoke_report_path = codex_result.get("smoke_report_path") or ""

    with connect(root) as conn:
        review_task_id = create_task(
            conn,
            kind="codex_review",
            source_id=build_task_row["source_id"],
            card_id=build_task_row["card_id"],
            payload={
                "build_task_id": build_task_id,
                "ea_id": payload_build.get("ea_id"),
                "card_path": payload_build.get("card_path"),
                "mq5_path": mq5_path,
                "ex5_path": ex5_path,
                "smoke_report_path": smoke_report_path,
                "build_result_path": str(root / "artifacts" / "builds" / f"{build_task_id}.json"),
            },
        )
    verdict_path = root / "artifacts" / "verdicts" / f"codex_review_{review_task_id}.json"
    verdict_path.parent.mkdir(parents=True, exist_ok=True)
    with connect(root) as conn:
        # Persist verdict_path back to payload so record-review can find it
        row = conn.execute("SELECT payload_json FROM tasks WHERE id=?", (review_task_id,)).fetchone()
        p = json.loads(row["payload_json"])
        p["verdict_path"] = str(verdict_path)
        conn.execute("UPDATE tasks SET payload_json=? WHERE id=?", (json.dumps(p), review_task_id))
        conn.commit()

    template = CODEX_REVIEW_TEMPLATE.read_text(encoding="utf-8")
    for k, v in [
        ("review_task_id", review_task_id),
        ("build_task_id", build_task_id),
        ("ea_id", payload_build.get("ea_id") or ""),
        ("card_path", payload_build.get("card_path") or ""),
        ("mq5_path", mq5_path),
        ("ex5_path", ex5_path),
        ("smoke_report_path", smoke_report_path),
        ("build_result_path", str(root / "artifacts" / "builds" / f"{build_task_id}.json")),
        ("verdict_path", str(verdict_path)),
    ]:
        template = template.replace("{{" + k + "}}", str(v))

    prompt_path = root / "queue" / f"codex_review_{review_task_id}.md"
    prompt_path.parent.mkdir(parents=True, exist_ok=True)
    prompt_path.write_text(template, encoding="utf-8", newline="\n")

    import shutil as _shutil
    codex_path = _resolve_codex()
    live_log = root / "logs" / f"codex_review_{review_task_id}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)

    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        shell=True,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "codex_review_task_id": review_task_id,
        "build_task_id": build_task_id,
        "ea_id": payload_build.get("ea_id"),
        "verdict_path": str(verdict_path),
        "live_log": str(live_log),
        "pid": proc.pid,
    }


def _record_codex_review_result(root: Path, review_task_id: str, verdict_path: str) -> dict[str, Any]:
    """Read a completed codex_review verdict, mark the task done, return the verdict.

    Pump uses the returned verdict to decide whether to spawn claude_review
    (PASS) or block the build (FAIL).
    """
    vp = Path(verdict_path)
    if not vp.exists() or vp.stat().st_size == 0:
        return {"recorded": False, "reason": "verdict not yet written"}
    try:
        v = json.loads(vp.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"recorded": False, "reason": f"verdict json invalid: {exc}"}
    verdict = (v.get("verdict") or "").upper()
    if verdict not in ("PASS", "FAIL"):
        return {"recorded": False, "reason": f"verdict must be PASS|FAIL, got {verdict!r}"}
    with connect(root) as conn:
        row = conn.execute("SELECT payload_json FROM tasks WHERE id=?", (review_task_id,)).fetchone()
        if not row:
            return {"recorded": False, "reason": "review task not found"}
        payload = json.loads(row["payload_json"])
        payload["verdict"] = verdict
        payload["findings"] = v.get("findings") or []
        payload["sections"] = v.get("sections") or {}
        conn.execute(
            "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(payload), utc_now(), review_task_id),
        )
        event(conn, "task", review_task_id, "codex_review_recorded", {
            "verdict": verdict,
            "findings_count": len(payload["findings"]),
            "build_task_id": payload.get("build_task_id"),
        })
        conn.commit()
    return {
        "recorded": True,
        "review_task_id": review_task_id,
        "verdict": verdict,
        "build_task_id": payload.get("build_task_id"),
        "findings_count": len(payload["findings"]),
    }


def _spawn_codex_for_build(root: Path, task_row: sqlite3.Row) -> dict[str, Any]:
    """Spawn Codex CLI as a detached process for a pending build_ea task.

    Idempotent: if a codex_build_<task_id>.live.log is being actively
    written (size growing) → consider already-running and skip. Otherwise
    spawn fresh. The Codex process writes the build_result JSON itself per
    the codex_build_ea.md output contract; subsequent pump cycles will see
    the build_ea row transition to done via record-build (called by the
    hourly wake or a future Claude-worker pump cycle).
    """
    payload = json.loads(task_row["payload_json"])
    ea_id = payload.get("ea_id")
    slug = payload.get("slug")
    card_path = payload.get("card_path")
    prompt_path = payload.get("prompt_path")
    if not prompt_path:
        # Render now via build-ea logic (it'll create a NEW task — but we
        # already have one. So re-derive prompt path manually).
        if not card_path:
            return {"spawned": False, "reason": "no card_path in payload"}
        prompt_path = str(root / "queue" / f"codex_build_{task_row['id']}.md")
        # Render prompt
        build_result_path = str(root / "artifacts" / "builds" / f"{task_row['id']}.json")
        Path(prompt_path).parent.mkdir(parents=True, exist_ok=True)
        Path(build_result_path).parent.mkdir(parents=True, exist_ok=True)
        template = CODEX_BUILD_TEMPLATE.read_text(encoding="utf-8")
        for k, v in [
            ("task_id", task_row["id"]),
            ("ea_id", ea_id),
            ("slug", slug or ""),
            ("card_path", card_path or ""),
            ("source_id", ""),
            ("ea_dir", str(FRAMEWORK_EAS_DIR / f"{ea_id}_{slug}")),
            ("build_result_path", build_result_path),
        ]:
            template = template.replace("{{" + k + "}}", str(v))
        Path(prompt_path).write_text(template, encoding="utf-8", newline="\n")
        # Persist back to task payload
        payload["prompt_path"] = prompt_path
        payload["build_result_path"] = build_result_path
        with connect(root) as conn:
            conn.execute("UPDATE tasks SET payload_json=? WHERE id=?", (json.dumps(payload), task_row["id"]))
            conn.commit()

    live_log = root / "logs" / f"codex_build_{task_row['id']}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    # Check if already running (live log growing in last 60s)
    if live_log.exists():
        age_sec = time.time() - live_log.stat().st_mtime
        if age_sec < 60:
            return {"spawned": False, "reason": "live log activity within 60s — codex likely still running", "task_id": task_row["id"]}

    # Spawn: cat prompt | codex exec -s danger-full-access --cd C:/QM/repo 2>&1 | tee live_log
    # We do this through a shell wrapper to chain cat+tee on Windows.
    # Detached so pump doesn't wait.
    # Direct Popen — codex.cmd is an npm batch shim; subprocess can exec it
    # via shell=True. stdin piped from prompt file, stdout/stderr to live_log.
    import shutil as _shutil
    codex_path = _resolve_codex()
    creationflags = 0
    if sys.platform == "win32":
        # CREATE_NEW_CONSOLE gives the child its own console (separate from
        # farmctl's). Codex needs a console for its TUI even when run with
        # `exec` (non-interactive). DETACHED_PROCESS removed because it makes
        # codex.cmd's batch shim exit immediately without running node.
        creationflags = subprocess.CREATE_NEW_CONSOLE  # type: ignore[attr-defined]
    stdin_f = open(prompt_path, "rb")
    stdout_f = open(live_log, "wb")
    proc = subprocess.Popen(
        [codex_path, "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
        cwd=str(REPO_ROOT),
        stdin=stdin_f,
        stdout=stdout_f,
        stderr=subprocess.STDOUT,
        shell=True,
        creationflags=creationflags,
        close_fds=False,
    )
    return {
        "spawned": True,
        "task_id": task_row["id"],
        "ea_id": ea_id,
        "pid": proc.pid,
        "live_log": str(live_log),
    }


def _is_zero_trade_failure_payload(payload_json: str | None, evidence_path: str | None) -> bool:
    if payload_json and "MIN_TRADES_NOT_MET" in payload_json:
        return True
    if not evidence_path:
        return False
    try:
        p = Path(evidence_path)
        if not p.exists() or p.stat().st_size <= 0:
            return False
        text = p.read_text(encoding="utf-8", errors="ignore")
        if "MIN_TRADES_NOT_MET" in text:
            return True
        data = json.loads(text)
        reason_classes = data.get("reason_classes") or []
        if any(str(r).upper() == "MIN_TRADES_NOT_MET" for r in reason_classes):
            return True
        return "MIN_TRADES_NOT_MET" in str(data.get("reason_class") or data.get("reason") or "")
    except Exception:
        return False


def _recent_zero_trade_rework_exists(con: sqlite3.Connection, ea_id: str) -> bool:
    cutoff = (dt.datetime.now(dt.UTC) - dt.timedelta(hours=ZERO_TRADE_REWORK_DEDUP_HOURS)).replace(microsecond=0).isoformat()
    row = con.execute(
        """
        SELECT id FROM tasks
        WHERE card_id=? AND kind='build_ea'
          AND payload_json LIKE '%ZERO_TRADE_RECURRENT%'
          AND created_at >= ?
        ORDER BY created_at DESC LIMIT 1
        """,
        (ea_id, cutoff),
    ).fetchone()
    return row is not None


def _find_first_path(patterns: list[tuple[Path, str]]) -> Path | None:
    for base, pattern in patterns:
        if not base.exists():
            continue
        matches = sorted(base.glob(pattern))
        if matches:
            return matches[0]
    return None


def _write_zerotrade_rework_codex_task(
    root: Path,
    ea_id: str,
    ratio: float,
    done: int,
    zt: int,
    task_id: str,
    evidence_paths: list[str],
) -> Path:
    inbox = root / "codex_inbox"
    inbox.mkdir(parents=True, exist_ok=True)

    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    md_task_id = f"auto-rework-{ea_id}-{stamp}"
    target = inbox / f"{md_task_id}.md"

    card_path = _find_first_path([
        (root / "artifacts" / "cards_approved", f"{ea_id}_*.md"),
        (root / "artifacts" / "cards_draft", f"{ea_id}_*.md"),
    ])
    source_path = _find_first_path([(FRAMEWORK_EAS_DIR, f"{ea_id}_*/{ea_id}_*.mq5")])

    evidence_lines = evidence_paths[:5] or ["<none recorded>"]
    evidence_md = "\n".join(f"- {p}" for p in evidence_lines)

    body = f"""---
task_id: {md_task_id}
priority: med
created: {dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
auto_generated: true
trigger: ZERO_TRADE_RECURRENT
db_task_id: {task_id}
---

# Auto-detected zero-trade rework: {ea_id}

Pump detected that {ea_id} has {ratio:.0%} zero-trade FAIL ratio ({zt}/{done} P2 done work_items returned MIN_TRADES_NOT_MET). Strategy logic likely has an entry-condition bug.

## Files to investigate

- Card: {card_path if card_path else '<card not found>'}
- Source: {source_path if source_path else '<source not found>'}
- 5 zero-trade summary.jsons:
{evidence_md}

## What to do

Same shape as task #019 diagnosis: identify the specific rejecting test and propose a patch. Do not apply the patch; Claude reviews and commits.

## Output

`D:/QM/strategy_farm/codex_outbox/{md_task_id}_result.md`

## Acceptance criteria

- 3+ `.mq5:line` citations identifying the rejecting test
- Patch proposal OR verdict: `DEAD`, `REWORK`, or `PROP_FIRM_INCOMPATIBLE`
- No commit / no push
"""

    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(body, encoding="utf-8", newline="\n")
    tmp.replace(target)
    return target


def _detect_zerotrade_dead_eas(con: sqlite3.Connection, root: Path = DEFAULT_ROOT) -> list[dict[str, Any]]:
    """
    Find EAs where >=80% of done P2 work_items are FAILs caused by
    MIN_TRADES_NOT_MET, with at least 5 done P2 samples. Create one fresh
    build_ea retry task plus one bridge .md task, de-duped over 6 hours.
    """
    rows = con.execute(
        """
        SELECT ea_id, verdict, payload_json, evidence_path, updated_at
        FROM work_items
        WHERE phase='P2' AND status='done'
        """
    ).fetchall()

    grouped: dict[str, dict[str, Any]] = {}
    for r in rows:
        ea_id = r["ea_id"]
        bucket = grouped.setdefault(ea_id, {"done": 0, "zt": 0, "evidence": []})
        bucket["done"] += 1
        if (r["verdict"] or "").upper() == "FAIL" and _is_zero_trade_failure_payload(r["payload_json"], r["evidence_path"]):
            bucket["zt"] += 1
            if r["evidence_path"]:
                bucket["evidence"].append(r["evidence_path"])

    flagged: list[dict[str, Any]] = []
    for ea_id, stats in sorted(grouped.items()):
        done = int(stats["done"])
        zt = int(stats["zt"])
        if done < ZERO_TRADE_DEAD_MIN_DONE:
            continue
        ratio = zt / done if done else 0.0
        if ratio < ZERO_TRADE_DEAD_THRESHOLD:
            continue
        if _recent_zero_trade_rework_exists(con, ea_id):
            continue

        card_path = _find_first_path([
            (root / "artifacts" / "cards_approved", f"{ea_id}_*.md"),
            (root / "artifacts" / "cards_draft", f"{ea_id}_*.md"),
        ])
        frontmatter: dict[str, Any] = {}
        slug = ""
        if card_path:
            try:
                frontmatter = parse_card_frontmatter(card_path)
                slug = str(frontmatter.get("slug") or "")
            except Exception:
                frontmatter = {}
        ea_dir = _find_first_path([(FRAMEWORK_EAS_DIR, f"{ea_id}_*")])

        payload = {
            "rework_reason": "ZERO_TRADE_RECURRENT",
            "ea_id": ea_id,
            "slug": slug,
            "card_path": str(card_path) if card_path else "",
            "ea_dir": str(ea_dir) if ea_dir else "",
            "frontmatter": frontmatter,
            "zero_trade_ratio": ratio,
            "zero_trade_failures": zt,
            "sample_size": done,
            "trigger_ts": utc_now(),
            "evidence_query": (
                "SELECT evidence_path FROM work_items WHERE ea_id='"
                + ea_id
                + "' AND verdict='FAIL' AND payload_json LIKE '%MIN_TRADES_NOT_MET%' LIMIT 5"
            ),
        }
        task_id = create_task(
            con,
            kind="build_ea",
            source_id=None,
            card_id=ea_id,
            payload=payload,
        )
        md_path = _write_zerotrade_rework_codex_task(
            root,
            ea_id,
            ratio,
            done,
            zt,
            task_id,
            list(stats["evidence"]),
        )
        con.execute(
            "UPDATE tasks SET payload_json=?, updated_at=? WHERE id=?",
            (json.dumps({**payload, "codex_inbox_task_path": str(md_path)}, sort_keys=True), utc_now(), task_id),
        )
        flagged.append({
            "ea_id": ea_id,
            "zero_trade_ratio": ratio,
            "zero_trade_failures": zt,
            "sample_size": done,
            "task_id": task_id,
            "codex_inbox_task_path": str(md_path),
        })

    if flagged:
        con.commit()
    return flagged


def _has_auto_build_task_file(root: Path, ea_id: str) -> bool:
    inbox = root / "codex_inbox"
    for rel in ("", ".processing", ".archive"):
        d = inbox / rel if rel else inbox
        if d.is_dir() and any(d.glob(f"auto-build-{ea_id}-*.md")):
            return True
    return False


def _detect_unbuilt_cards(root: Path) -> list[dict[str, Any]]:
    """
    Find approved cards where the matching EA .ex5 does not exist yet and
    no bridge auto-build task has already been written.
    """
    cards_dir = root / "artifacts" / "cards_approved"
    if not cards_dir.is_dir():
        return []

    unbuilt: list[dict[str, Any]] = []
    for card_md in sorted(cards_dir.glob("QM5_*.md")):
        m = re.match(r"(QM5_\d{4})_(.+)\.md$", card_md.name)
        if not m:
            continue
        ea_id, slug = m.group(1), m.group(2)
        label = f"{ea_id}_{slug}"
        ea_dir = FRAMEWORK_EAS_DIR / label
        ex5 = ea_dir / f"{label}.ex5"
        if ex5.exists():
            continue
        if _has_auto_build_task_file(root, ea_id):
            continue
        unbuilt.append({
            "ea_id": ea_id,
            "slug": slug,
            "label": label,
            "card_path": str(card_md),
            "expected_ex5": str(ex5),
        })
    return unbuilt


def _write_auto_build_task(ea_info: dict[str, Any], root: Path) -> Path:
    """Write an auto-build bridge task for an approved-but-unbuilt card."""
    inbox = root / "codex_inbox"
    inbox.mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    task_id = f"auto-build-{ea_info['ea_id']}-{ts}"
    label = ea_info["label"]
    card_path = ea_info["card_path"]
    content = f"""---
task_id: {task_id}
priority: high
created: {dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
auto_generated: true
trigger: UNBUILT_APPROVED_CARD
ea_id: {ea_info['ea_id']}
label: {label}
---

# Auto-build {ea_info['ea_id']} from approved card

Pump detected that card `{card_path}` is approved but
`framework/EAs/{label}/{label}.ex5` does not exist. Build the EA.

## Files to read

- Card: `{card_path}`
- V5 framework spec: `C:/QM/repo/framework/V5_FRAMEWORK_DESIGN.md`
- Template references: `QM5_1056`, `QM5_1099`, `QM5_1101` `.mq5` files for V5 boilerplate
- Magic registry: `C:/QM/repo/framework/registry/magic_numbers.csv`
- Known findings: `D:/QM/strategy_farm/codex_inbox/_KNOWN_FINDINGS.md`

## What to do

1. Read the card body for entry/exit rules and input specs.
2. Create directory `framework/EAs/{label}/`.
3. Write `{label}.mq5` implementing the card per V5 framework.
4. Append rows to `magic_numbers.csv`, one per card-listed symbol.
5. Regenerate `QM_MagicResolver.mqh` via `update_magic_resolver.py`.
6. Run build_check / compile; both must pass with 0 errors and 0 warnings.
7. Run smoke on the first card-listed symbol to confirm entry logic fires.
8. Generate per-symbol `.set` files via `gen_setfile.ps1`.
9. No commit / no push.

## Output

`D:/QM/strategy_farm/codex_outbox/{task_id}_result.md`

## Acceptance criteria

- [ ] `.mq5` and `.ex5` created
- [ ] build_check PASS and compile 0/0
- [ ] Smoke produces at least 1 trade OR documents the zero-trade reason
- [ ] magic registry and resolver updated
- [ ] `.set` files generated for card-listed symbols
- [ ] No commit / no push
"""
    target = inbox / f"{task_id}.md"
    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8", newline="\n")
    tmp.replace(target)
    return target


def _detect_unenqueued_eas(con: sqlite3.Connection) -> list[dict[str, Any]]:
    """
    Find reviewed, built EAs with no P2 work_items. These are ready for
    automatic P2 enqueue.
    """
    rows = con.execute(
        """
        SELECT card_id, MAX(updated_at) latest_review_ts, id AS review_task_id
        FROM tasks
        WHERE kind='ea_review' AND status='done'
        GROUP BY card_id
        """
    ).fetchall()
    needs: list[dict[str, Any]] = []
    for r in rows:
        ea_id = r["card_id"]
        if not ea_id:
            continue
        wi_count = con.execute(
            "SELECT COUNT(*) FROM work_items WHERE ea_id=? AND phase='P2'",
            (ea_id,),
        ).fetchone()[0]
        if wi_count > 0:
            continue
        candidates = sorted(p for p in FRAMEWORK_EAS_DIR.glob(f"{ea_id}_*") if p.is_dir())
        if not candidates:
            continue
        ea_dir = candidates[0]
        ex5 = ea_dir / f"{ea_dir.name}.ex5"
        if not ex5.exists():
            continue
        needs.append({
            "ea_id": ea_id,
            "review_task_id": r["review_task_id"],
            "ea_dir": str(ea_dir),
            "ex5": str(ex5),
        })
    return needs


def _enqueue_p2_from_review(root: Path, review_task_id: str) -> int:
    result = enqueue_backtest(root, review_task_id, "P2")
    if not result.get("enqueued"):
        raise RuntimeError(str(result.get("reason") or result))
    return len(result.get("work_items_created") or [])


def pump(root: Path) -> dict[str, Any]:
    """Continuous deterministic worker — run every 5 min.

    Does the no-LLM-needed work that previously waited for hourly Claude
    wakes:
      - MT5 backtest dispatch (was: separate `tick` command)
      - Auto-enqueue next phase on PASS verdicts (now inside dispatch_tick)
      - Spawn Codex for ONE pending build_ea task per pump call (bounded —
        Codex builds take 5-15 min, don't pile up multiple)
      - Record build results when Codex's build_result JSON appears
      - (Future) spawn Claude for ONE pending ea_review task

    Bounded per pump cycle to avoid resource overrun. Idempotent — checks
    live_log freshness so re-runs while Codex is still going don't
    double-spawn.
    """
    init_db(root)
    result: dict[str, Any] = {
        "pumped_at": utc_now(),
        "dispatch": None,
        "codex_spawn": None,
        "build_records": [],
        "build_retries": [],
    }

    # CIRCUIT BREAKER: if recent codex logs are full of 401 Unauthorized,
    # Codex OAuth is broken. Each new spawn wastes 5 retries × ~30s before
    # giving up + leaves a junk log + counts against codex quota. Don't
    # spawn ANY codex work until auth is fixed (OWNER must run `codex login`
    # interactively). Build/research/review/g0 all skipped; MT5 dispatch
    # + Claude work continue normally.
    codex_auth_broken = False
    try:
        import re as _re, time as _t
        pat = _re.compile(rb"401 Unauthorized")
        from pathlib import Path as _P
        _auth = _P(r"C:/Users/Administrator/.codex/auth.json")
        auth_mtime = _auth.stat().st_mtime if _auth.exists() else 0.0
        n_401 = 0
        for log in (root / "logs").glob("codex_*.live.log"):
            try:
                log_mtime = log.stat().st_mtime
                if _t.time() - log_mtime > 900:
                    continue
                # Skip 401s from logs older than the most recent `codex login`.
                if log_mtime < auth_mtime:
                    continue
                size = log.stat().st_size
                with open(log, "rb") as fh:
                    fh.seek(max(0, size - 4096))
                    tail = fh.read()
                if pat.search(tail):
                    n_401 += 1
            except OSError:
                continue
        codex_auth_broken = n_401 >= 3
        result["codex_auth_broken"] = {
            "tripped": codex_auth_broken,
            "n_401_recent_logs": n_401,
        }
    except Exception as exc:
        result["codex_auth_broken"] = {"tripped": False, "error": repr(exc)}

    # 1a. Per-symbol work_items dispatch (NEW — pump consumes work_items as
    #     the unit of MT5 work, one per free terminal, replacing the bundled
    #     p2_baseline fan-out). Aggregates parent task verdicts on completion.
    result["dispatch_work_items"] = dispatch_work_items(root)
    # 1b. Legacy bundled-task dispatch — handles any backtest_<phase> tasks
    #     created WITHOUT matching work_items (e.g. older runs). Will become
    #     a no-op once all enqueues create work_items.
    result["dispatch"] = dispatch_tick(root)
    with connect(root) as conn:
        result["zerotrade_rework_flagged"] = _detect_zerotrade_dead_eas(conn, root)

    result["auto_build_queued"] = []
    for ea_info in _detect_unbuilt_cards(root)[:2]:
        p = _write_auto_build_task(ea_info, root)
        result["auto_build_queued"].append({
            "ea_id": ea_info["ea_id"],
            "label": ea_info["label"],
            "task_path": str(p),
        })

    result["auto_p2_enqueued"] = []
    with connect(root) as conn:
        for ea_info in _detect_unenqueued_eas(conn)[:3]:
            try:
                n = _enqueue_p2_from_review(root, ea_info["review_task_id"])
                result["auto_p2_enqueued"].append({
                    "ea_id": ea_info["ea_id"],
                    "work_items": n,
                    "review_task_id": ea_info["review_task_id"],
                })
            except Exception as exc:
                result["auto_p2_enqueued"].append({
                    "ea_id": ea_info["ea_id"],
                    "review_task_id": ea_info["review_task_id"],
                    "error": repr(exc),
                })

    # 2. Retry blocked builds — OWNER 2026-05-16 "Fail → ans Ende der
    #    Liste". A blocked build means the previous attempt hit
    #    framework_error / compile_failed / smoke_failed. Re-queue up to
    #    MAX_BUILD_RETRIES so framework fixes (deploy, perf, etc.) get a
    #    fresh swing.
    MAX_BUILD_RETRIES = 3
    with connect(root) as conn:
        blocked_builds = conn.execute(
            "SELECT * FROM tasks WHERE kind='build_ea' AND status='blocked' "
            "ORDER BY updated_at ASC"
        ).fetchall()
    for row in blocked_builds:
        payload = json.loads(row["payload_json"])
        attempt = int(payload.get("attempt_count", 0)) + 1
        if attempt > MAX_BUILD_RETRIES:
            continue
        # Archive stale build_result so the next pump cycle doesn't re-record
        # the OLD outcome as a "fresh" build. Codex writes a new file on the
        # next run. Also archive live log so a fresh one gets created.
        brp = payload.get("build_result_path")
        if brp:
            brp_path = Path(brp)
            if brp_path.exists() and brp_path.stat().st_size > 0:
                archive = brp_path.with_suffix(f".attempt_{attempt-1}.json")
                try:
                    brp_path.rename(archive)
                except OSError:
                    pass
        live_log = root / "logs" / f"codex_build_{row['id']}.live.log"
        if live_log.exists():
            try:
                live_log.rename(live_log.with_suffix(f".attempt_{attempt-1}.log"))
            except OSError:
                pass

        update_payload = dict(payload)
        update_payload["attempt_count"] = attempt
        update_payload["last_blocked_reason"] = payload.get("blocked_reason") or payload.get("build_result", {}).get("blocked_reason")
        # Clear stale dispatch metadata so the fresh Codex run starts clean
        for k in ("pid", "started_at_iso", "log_path", "build_result", "blocked_reason"):
            update_payload.pop(k, None)
        with connect(root) as conn2:
            conn2.execute(
                "UPDATE tasks SET status='pending', payload_json=?, updated_at=? WHERE id=?",
                (json.dumps(update_payload), utc_now(), row["id"]),
            )
            conn2.commit()
        result["build_retries"].append({
            "task_id": row["id"],
            "ea_id": payload.get("ea_id"),
            "attempt": attempt,
            "last_blocked_reason": (payload.get("blocked_reason") or "")[:120],
        })

    # 3. Codex builds for up to MAX_PARALLEL_CODEX pending build_ea tasks.
    #    Each Codex builds a DIFFERENT EA — races on shared writes (CSV
    #    appends + update_magic_resolver.py rewrite) are resolved at the
    #    file level: CSV append is atomic line-by-line, update_resolver is
    #    idempotent (reads current CSV state, regenerates .mqh deterministically).
    #    OWNER 2026-05-16: explicit ok to parallelize.
    MAX_PARALLEL_CODEX = 10
    MAX_PARALLEL_CODEX_BUILDS = 7
    # Circuit breaker: when codex auth is broken, force both caps to 0 so
    # NO codex work spawns (research/review/build/g0 all gated through
    # these caps). Prevents wasting 5×30s retries per spawn + leaving
    # 401-junk logs that confuse later diagnosis.
    if codex_auth_broken:
        MAX_PARALLEL_CODEX = 0
        MAX_PARALLEL_CODEX_BUILDS = 0
    try:
        import shutil as _shutil
        ps_out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name codex -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        )
        active_codex = int((ps_out.stdout or "0").strip() or "0")
    except Exception:
        active_codex = 0
    # Build budget capped at 7 OR (total cap - already active), whichever is lower.
    # Non-build spawns (research/review/g0) can still use up to MAX_PARALLEL_CODEX-active.
    spawn_budget = max(0, min(MAX_PARALLEL_CODEX_BUILDS, MAX_PARALLEL_CODEX - active_codex))
    with connect(root) as conn:
        # Dedupe by ea_id — never spawn 2 codex builds for the same EA at
        # once (race on EA dir + magic_numbers.csv + resolver regeneration).
        # When multiple build_ea tasks exist for the same ea_id (e.g. retry
        # races), pick the oldest pending and ignore the others until that
        # one settles.
        all_pending = conn.execute(
            "SELECT * FROM tasks WHERE kind='build_ea' AND status='pending' "
            "ORDER BY updated_at ASC"
        ).fetchall()
        seen_eas: set[str] = set()
        pending_builds = []
        for row in all_pending:
            if len(pending_builds) >= spawn_budget:
                break
            payload = json.loads(row["payload_json"])
            ea_id = payload.get("ea_id")
            if ea_id in seen_eas:
                continue
            seen_eas.add(ea_id)
            pending_builds.append(row)
    spawns = []
    for pending_build in pending_builds:
        sp = _spawn_codex_for_build(root, pending_build)
        spawns.append(sp)

    # 3b. Auto-create build_ea tasks for newly-approved cards. Without this,
    #    pump can't reach Codex on cards that haven't yet been touched by
    #    autonomous_wake's Step 2 — the hourly cadence becomes the real
    #    bottleneck for fresh approved cards. Bounded by spawn_budget so we
    #    don't pile up backlog faster than we can build it.
    result["auto_created_builds"] = []
    # Count actually-spawned (not skipped-due-to-fresh-log)
    actually_spawned = sum(1 for s in spawns if s.get("spawned"))
    if actually_spawned < spawn_budget:
        cards_approved_dir = root / "artifacts" / "cards_approved"
        if cards_approved_dir.is_dir():
            with connect(root) as conn:
                have_task = {
                    json.loads(r["payload_json"]).get("ea_id")
                    for r in conn.execute("SELECT payload_json FROM tasks WHERE kind='build_ea'").fetchall()
                }
            cards_without_task = []
            for f in sorted(cards_approved_dir.glob("QM5_*.md")):
                parts = f.stem.split("_")
                if len(parts) < 2:
                    continue
                ea_id = f"{parts[0]}_{parts[1]}"
                if ea_id not in have_task:
                    if _has_auto_build_task_file(root, ea_id):
                        continue
                    cards_without_task.append((ea_id, f))
            slots_left = spawn_budget - actually_spawned
            for ea_id, card_path in cards_without_task[:slots_left]:
                br = render_codex_build_prompt(root, str(card_path), None)
                if br.get("written"):
                    result["auto_created_builds"].append({
                        "ea_id": ea_id,
                        "task_id": br.get("task_id"),
                    })
                    # Now spawn Codex for it immediately
                    with connect(root) as conn:
                        new_row = conn.execute(
                            "SELECT * FROM tasks WHERE id=?", (br["task_id"],)
                        ).fetchone()
                    if new_row:
                        sp = _spawn_codex_for_build(root, new_row)
                        spawns.append(sp)
    result["codex_spawn"] = spawns[0] if spawns else None
    result["codex_spawns_all"] = spawns
    result["codex_active_before"] = active_codex
    result["codex_spawn_budget"] = spawn_budget

    # 4. Record completed Codex builds — any pending build_ea whose
    #    build_result JSON exists and isn't empty.
    with connect(root) as conn:
        rows = conn.execute(
            "SELECT * FROM tasks WHERE kind='build_ea' AND status='pending'"
        ).fetchall()
    for row in rows:
        payload = json.loads(row["payload_json"])
        brp = payload.get("build_result_path")
        if brp and Path(brp).exists() and Path(brp).stat().st_size > 0:
            rec = record_build_result(root, row["id"], brp)
            result["build_records"].append({"task_id": row["id"], "recorded": rec})

    # 4b. ZERO-TRADE SHORT-CIRCUIT — observed 2026-05-17: 9/9 codex_reviews
    #     in last hour FAIL on smoke_sanity (0 trades in smoke window). The
    #     build_result.json already says smoke_result='MIN_TRADES_NOT_MET' —
    #     spawning Codex to "verify" that is pure waste. Mark such builds
    #     blocked with reason='zero_trade_smoke' BEFORE codex_review spawn.
    result["zero_trade_blocks"] = []
    with connect(root) as conn:
        candidates = conn.execute(
            """
            SELECT b.* FROM tasks b
            WHERE b.kind='build_ea' AND b.status='done'
              AND NOT EXISTS (
                SELECT 1 FROM tasks r WHERE r.kind='codex_review'
                  AND r.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              )
              AND NOT EXISTS (
                SELECT 1 FROM tasks rr WHERE rr.kind='ea_review'
                  AND rr.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              )
            """
        ).fetchall()
        for b in candidates:
            bp = json.loads(b["payload_json"])
            br_path = bp.get("build_result_path")
            if not br_path or not Path(br_path).exists():
                continue
            try:
                br = json.loads(Path(br_path).read_text(encoding="utf-8"))
            except Exception:
                continue
            sr = (br.get("smoke_result") or "").upper()
            blocked_r = (br.get("blocked_reason") or "")
            # Trigger conditions: explicit MIN_TRADES_NOT_MET, OR framework_error,
            # OR known dead-end blocked_reason patterns
            zero_trade = (
                "MIN_TRADES_NOT_MET" in sr or
                "MIN_TRADES_NOT_MET" in blocked_r or
                sr == "FRAMEWORK_ERROR" or
                "REPORT_MISSING" in blocked_r
            )
            if not zero_trade:
                continue
            bp["blocked_reason"] = bp.get("blocked_reason") or "zero_trade_smoke"
            bp["attempt"] = int(bp.get("attempt", 0)) + 1
            bp["zero_trade_short_circuit"] = True
            conn.execute(
                "UPDATE tasks SET status='blocked', payload_json=?, updated_at=? WHERE id=?",
                (json.dumps(bp), utc_now(), b["id"]),
            )
            event(conn, "task", b["id"], "build_zero_trade_blocked", {
                "smoke_result": sr,
                "blocked_reason": blocked_r[:200],
            })
            result["zero_trade_blocks"].append({
                "task_id": b["id"],
                "ea_id": bp.get("ea_id"),
                "smoke_result": sr,
                "saved_codex_review_spawn": True,
            })
        conn.commit()

    # 5a. CODEX pre-review for done build_ea without codex_review yet.
    #     Codex catches mechanical bugs (Framework Corset, INTRADAY DISCIPLINE,
    #     magic collisions, 0-trade smoke) BEFORE Claude burns tokens on
    #     policy review. PASS → Claude proceeds. FAIL → build → blocked.
    #     Zero-trade builds were already short-circuited in §4b — they
    #     won't appear here.
    result["codex_review_spawns"] = []
    with connect(root) as conn:
        builds_needing_codex_review = conn.execute(
            """
            SELECT b.* FROM tasks b
            WHERE b.kind='build_ea' AND b.status='done'
              AND NOT EXISTS (
                SELECT 1 FROM tasks r
                WHERE r.kind='codex_review'
                  AND r.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              )
            ORDER BY b.updated_at ASC LIMIT 3
            """
        ).fetchall()
    for b in builds_needing_codex_review:
        # Respect total-codex cap: builds + reviews + research (all share the pool)
        builds_now = len([s for s in (result.get("codex_spawns_all") or []) if isinstance(s, dict) and s.get("spawned")])
        reviews_now = len([s for s in result["codex_review_spawns"] if isinstance(s, dict) and s.get("spawned")])
        if (active_codex + builds_now + reviews_now) >= MAX_PARALLEL_CODEX:
            break
        sp = _spawn_codex_for_review(root, b)
        result["codex_review_spawns"].append(sp)

    # 5b. Record completed codex_review verdicts.
    result["codex_review_records"] = []
    with connect(root) as conn:
        pending_codex_reviews = conn.execute(
            "SELECT * FROM tasks WHERE kind='codex_review' AND status='pending'"
        ).fetchall()
    for cr in pending_codex_reviews:
        p = json.loads(cr["payload_json"])
        vp = p.get("verdict_path")
        if not vp:
            continue
        rec = _record_codex_review_result(root, cr["id"], vp)
        if rec.get("recorded"):
            result["codex_review_records"].append(rec)
            # If Codex says FAIL → block the build for rework, skip Claude
            if rec["verdict"] == "FAIL":
                build_id = rec["build_task_id"]
                with connect(root) as conn:
                    brow = conn.execute("SELECT payload_json FROM tasks WHERE id=?", (build_id,)).fetchone()
                    if brow:
                        bp = json.loads(brow["payload_json"])
                        bp["codex_review_findings"] = p.get("findings") or []
                        bp["blocked_reason"] = "codex_review_fail"
                        bp["attempt"] = int(bp.get("attempt", 0)) + 1
                        conn.execute(
                            "UPDATE tasks SET status='blocked', payload_json=?, updated_at=? WHERE id=?",
                            (json.dumps(bp), utc_now(), build_id),
                        )
                        event(conn, "task", build_id, "build_blocked_by_codex_review", {
                            "findings_count": len(bp["codex_review_findings"]),
                        })
                        conn.commit()

    # 5c. Spawn Claude review ONLY for builds that have a PASSING codex_review
    #     AND no ea_review yet. This is the cost-saver: Claude tokens only
    #     burn on builds Codex already cleared as mechanically sound.
    try:
        active_claude_count = int(subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name claude -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        ).stdout.strip() or "0")
    except Exception:
        active_claude_count = 0
    result["claude_active_before"] = active_claude_count
    MAX_PARALLEL_CLAUDE = 6
    if active_claude_count < MAX_PARALLEL_CLAUDE:
        with connect(root) as conn:
            done_no_review = conn.execute(
                """
                SELECT b.* FROM tasks b
                WHERE b.kind='build_ea' AND b.status='done'
                  AND EXISTS (
                    SELECT 1 FROM tasks cr
                    WHERE cr.kind='codex_review' AND cr.status='done'
                      AND cr.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
                      AND cr.payload_json LIKE '%"verdict": "PASS"%'
                  )
                  AND NOT EXISTS (
                    SELECT 1 FROM tasks r
                    WHERE r.kind='ea_review'
                      AND r.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
                  )
                ORDER BY b.updated_at ASC LIMIT 1
                """
            ).fetchone()
        if done_no_review:
            result["claude_review_spawn"] = _spawn_claude_for_review(root, done_no_review)

    # 6. Record completed Claude reviews — look for verdict JSONs that
    #    correspond to ea_review tasks NOT yet recorded.
    with connect(root) as conn:
        unreviewed = conn.execute(
            "SELECT * FROM tasks WHERE kind='ea_review' AND status='pending'"
        ).fetchall()
    result["review_records"] = []
    for row in unreviewed:
        payload = json.loads(row["payload_json"])
        vp = payload.get("verdict_path") or (str(root / "artifacts" / "verdicts" / f"review_{row['id']}.json"))
        if vp and Path(vp).exists() and Path(vp).stat().st_size > 0:
            try:
                rec = record_review_result(root, row["id"], vp)
                result["review_records"].append({"task_id": row["id"], "recorded": rec})
            except Exception as e:
                result["review_records"].append({"task_id": row["id"], "error": str(e)})

    # 7. Spawn Claude G0 review of draft cards (drain the backlog before
    #    starting more research). Bounded at 5 cards per spawn.
    spawned_other = bool(result.get("claude_review_spawn"))
    if active_claude_count < MAX_PARALLEL_CLAUDE and not spawned_other:
        result["claude_g0_spawn"] = _spawn_claude_for_g0_batch(root)
        if result["claude_g0_spawn"].get("spawned"):
            spawned_other = True

    # 7b. Spawn Codex G0 IN PARALLEL with Claude G0 — both review different
    #     cards via the .g0_claim filesystem lock mechanism. OWNER 2026-05-17:
    #     "Claude und Codex recherchieren beide, können auch beide G0-Review".
    #     Pulls Claude-token pressure off the biggest single consumer (G0
    #     batches with 5 cards × full strategy reasoning).
    result["codex_g0_spawn"] = None
    # Reserve budget vs total codex cap (build + review + research + g0 share pool)
    g0_builds_now = len([s for s in (result.get("codex_spawns_all") or []) if isinstance(s, dict) and s.get("spawned")])
    g0_reviews_now = len([s for s in (result.get("codex_review_spawns") or []) if isinstance(s, dict) and s.get("spawned")])
    if (active_codex + g0_builds_now + g0_reviews_now) < MAX_PARALLEL_CODEX:
        result["codex_g0_spawn"] = _spawn_codex_for_g0_batch(root)

    # 8. Spawn Claude research if no other claude spawn happened and budget allows.
    #    Continuous research per OWNER 2026-05-16 "weiter mit Research".
    if active_claude_count < MAX_PARALLEL_CLAUDE and not spawned_other:
        result["claude_research_spawn"] = _claim_research_source(root)

    # 9. Spawn Codex research IN ADDITION when codex has spare capacity.
    #    OWNER 2026-05-16: "Codex kann auch Research, wir verbrauchen Codex
    #    Token langsamer als Claude Token". Codex research runs in parallel
    #    with Claude research on a DIFFERENT source. Each codex_research
    #    claims one source as assigned_worker='codex' so no double-claim.
    #    OWNER 2026-05-17 (Hebel A): lift research parallelism from 1 to 3 —
    #    Codex quota at 4%/5h, massive headroom; serial-1 mining was wasting
    #    research throughput (only 4 sources mined per 8h overnight).
    MAX_PARALLEL_CODEX_RESEARCH = 3
    try:
        codex_research_fresh = 0
        for log in (root / "logs").glob("codex_research_*.live.log"):
            if time.time() - log.stat().st_mtime < 60:
                codex_research_fresh += 1
    except Exception:
        codex_research_fresh = 0
    result["codex_research_active"] = codex_research_fresh
    # active_codex was measured before this pump's build/review spawns.
    # Refresh by adding what we just spawned, so total cap stays at MAX_PARALLEL_CODEX.
    builds_spawned_this_cycle = len([s for s in (result.get("codex_spawns_all") or []) if isinstance(s, dict) and s.get("spawned")])
    reviews_spawned_this_cycle = len([s for s in (result.get("codex_review_spawns") or []) if isinstance(s, dict) and s.get("spawned")])
    result["codex_research_spawns"] = []
    # Spawn up to (MAX_PARALLEL_CODEX_RESEARCH - codex_research_fresh) new
    # research sessions, respecting the total codex cap.
    research_to_spawn = max(0, MAX_PARALLEL_CODEX_RESEARCH - codex_research_fresh)
    for _ in range(research_to_spawn):
        total_now = (active_codex + builds_spawned_this_cycle + reviews_spawned_this_cycle
                     + len(result["codex_research_spawns"]))
        if total_now >= MAX_PARALLEL_CODEX:
            break
        spawn = _claim_research_source_codex(root)
        result["codex_research_spawns"].append(spawn)
        if not spawn.get("spawned"):
            break  # no more research work available — stop trying
    # Back-compat: keep the singular field pointing to the first spawn
    result["codex_research_spawn"] = (result["codex_research_spawns"][0]
                                       if result["codex_research_spawns"] else None)

    # 10. Parameter ablation — phase-aware:
    #     - P2-PASS (exploration): 5 random ±25% mutations to find a viable
    #       region. OWNER 2026-05-16 "Ablation auf Gewinner statt Greenfield".
    #     - P3-PASS (exploitation): 50 systematic grid points ±30% across the
    #       top numeric strategy_* inputs (cartesian product). OWNER 2026-05-17
    #       "für jeden P3-PASS 50 Ablations spawnen (parameter-grid)".
    #     Ablation children themselves never re-ablate (is_ablation=0 filter).
    try:
        from ablate import spawn_ablation_workitems
    except ImportError:
        import sys as _sys
        _sys.path.insert(0, str(Path(__file__).resolve().parent))
        from ablate import spawn_ablation_workitems
    result["ablation_children"] = []

    # §10a P2-PASS → 5 random
    #
    # NOTE: depth-1 filter uses setfile_path pattern, NOT payload flag.
    # The MT5 worker overwrites payload_json with its own runtime fields
    # (terminal, pid, started_at, etc.) — any is_ablation flag we set at
    # work_item-insertion time is GONE by the time the verdict comes in.
    # The setfile name (`*_ablation_NN.set` / `*_grid_NNN.set`) is the only
    # reliable lineage marker that survives worker overwrites.
    with connect(root) as conn:
        p2_pass = conn.execute(
            """
            SELECT * FROM work_items
            WHERE status='done' AND verdict='PASS' AND phase='P2'
              AND setfile_path NOT LIKE '%_ablation_%'
              AND setfile_path NOT LIKE '%_grid_%'
              AND COALESCE(json_extract(payload_json, '$.ablated_at'), '')=''
            ORDER BY updated_at ASC LIMIT 5
            """
        ).fetchall()
        for wi in p2_pass:
            try:
                report = spawn_ablation_workitems(
                    conn, dict(wi), FRAMEWORK_EAS_DIR,
                    n_variants=5, perturb_pct=0.25, method="random",
                )
                result["ablation_children"].append(report)
            except Exception as exc:
                result["ablation_children"].append({
                    "parent_id": wi["id"], "ea_id": wi["ea_id"],
                    "method": "random",
                    "children_count": 0, "reason": f"error: {exc!r}",
                })

    # §10c Promote ablation/grid P2-PASS work_items into P3.
    #
    # Problem: the original P2→P3 auto-enqueue (in classify_aggregate) gates
    # on "does a backtest_p3 task already exist for this ea_id". When the
    # first 3 P2-PASSes for 1049 created a backtest_p3 task, that task only
    # received work_items for the setfiles that existed at the time (3
    # originals). The 8 ablation children that later passed P2 never got a
    # corresponding P3 work_item because the gate sees "P3 task exists".
    #
    # Fix: directly insert P3 work_items per (ea_id, symbol, setfile) that
    # passed P2 but has no P3 work_item yet. Re-open the parent P3 task back
    # to 'pending' so classify_aggregate re-aggregates when new work_items
    # finish. Skip rows where no parent P3 task exists yet (next cycle will
    # catch them after the first PASS goes through normal auto-enqueue).
    result["p3_promotions"] = []
    with connect(root) as conn:
        promotable = conn.execute(
            """
            SELECT w.* FROM work_items w
            WHERE w.status='done' AND w.verdict='PASS' AND w.phase='P2'
              AND (w.setfile_path LIKE '%_ablation_%' OR w.setfile_path LIKE '%_grid_%')
              AND NOT EXISTS (
                SELECT 1 FROM work_items w2
                WHERE w2.ea_id = w.ea_id
                  AND w2.symbol = w.symbol
                  AND w2.setfile_path = w.setfile_path
                  AND w2.phase = 'P3'
              )
            ORDER BY w.updated_at ASC LIMIT 10
            """
        ).fetchall()
        reopened_parents: set[str] = set()
        for wi in promotable:
            parent = conn.execute(
                "SELECT id, status FROM tasks WHERE kind='backtest_p3' "
                "AND payload_json LIKE ? ORDER BY created_at ASC LIMIT 1",
                (f'%"ea_id": "{wi["ea_id"]}"%',),
            ).fetchone()
            if not parent:
                continue
            new_id = str(uuid.uuid4())
            now = utc_now()
            payload = {"promoted_from_p2_work_item": wi["id"]}
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   attempt_count, parent_task_id, payload_json, created_at, updated_at)
                VALUES (?, 'backtest', 'P3', ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
                """,
                (new_id, wi["ea_id"], wi["symbol"], wi["setfile_path"],
                 parent["id"], json.dumps(payload), now, now),
            )
            # Re-open parent P3 task so classify_aggregate re-runs when this
            # work_item finishes. No-op if already pending.
            if parent["id"] not in reopened_parents and parent["status"] == "done":
                conn.execute(
                    "UPDATE tasks SET status='pending', updated_at=? WHERE id=?",
                    (now, parent["id"]),
                )
                reopened_parents.add(parent["id"])
            result["p3_promotions"].append({
                "p3_work_item_id": new_id,
                "ea_id": wi["ea_id"],
                "symbol": wi["symbol"],
                "setfile": Path(wi["setfile_path"]).name,
                "parent_p2_work_item_id": wi["id"],
                "parent_p3_task_id": parent["id"],
                "reopened_parent": parent["id"] in reopened_parents and parent["status"] == "done",
            })
        if result["p3_promotions"]:
            conn.commit()

    result["cascade_promotions"] = []
    cascade_phase_map = {
        "P3": "P4",
        "P4": "P5",
        "P5": "P5b",
        "P5b": "P5c",
        "P5c": "P6",
        "P6": "P7",
        "P7": "P8",
    }
    cascade_pass_verdicts = {
        "P3": {"PASS"},
        "P4": {"PASS"},
        "P5": {"PASS"},
        "P5b": {"PASS"},
        "P5c": {"PASS", "REPORT_ONLY"},
        "P6": {"PASS", "MULTI_SEED_PASS", "MULTI_SEED_MIXED"},
        "P7": {"PASS"},
    }
    with connect(root) as conn:
        reopened_parents: set[str] = set()
        for prev_phase, next_phase in cascade_phase_map.items():
            verdicts = sorted(cascade_pass_verdicts[prev_phase])
            placeholders = ",".join("?" for _ in verdicts)
            promotable = conn.execute(
                f"""
                SELECT w.* FROM work_items w
                WHERE w.status='done' AND w.phase=? AND w.verdict IN ({placeholders})
                  AND NOT EXISTS (
                    SELECT 1 FROM work_items w2
                    WHERE w2.ea_id = w.ea_id
                      AND w2.symbol = w.symbol
                      AND w2.phase = ?
                  )
                ORDER BY w.updated_at ASC LIMIT 10
                """,
                (prev_phase, *verdicts, next_phase),
            ).fetchall()
            for wi in promotable:
                next_kind = next_phase.lower().replace(".", "")
                parent = conn.execute(
                    "SELECT id, status FROM tasks WHERE kind=? "
                    "AND payload_json LIKE ? ORDER BY created_at ASC LIMIT 1",
                    (f"backtest_{next_kind}", f'%"ea_id": "{wi["ea_id"]}"%'),
                ).fetchone()
                parent_id = parent["id"] if parent else None
                new_id = str(uuid.uuid4())
                now = utc_now()
                payload = {
                    "promoted_from_phase": prev_phase,
                    "promoted_from_work_item": wi["id"],
                    "promotion_source": "pump_cascade",
                }
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       attempt_count, parent_task_id, payload_json, created_at, updated_at)
                    VALUES (?, 'backtest', ?, ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
                    """,
                    (new_id, next_phase, wi["ea_id"], wi["symbol"], wi["setfile_path"],
                     parent_id, json.dumps(payload, sort_keys=True), now, now),
                )
                reopened_parent = False
                if parent and parent["id"] not in reopened_parents and parent["status"] == "done":
                    conn.execute(
                        "UPDATE tasks SET status='pending', updated_at=? WHERE id=?",
                        (now, parent["id"]),
                    )
                    reopened_parents.add(parent["id"])
                    reopened_parent = True
                result["cascade_promotions"].append({
                    "work_item_id": new_id,
                    "ea_id": wi["ea_id"],
                    "symbol": wi["symbol"],
                    "from_phase": prev_phase,
                    "to_phase": next_phase,
                    "from_work_item_id": wi["id"],
                    "parent_task_id": parent_id,
                    "reopened_parent": reopened_parent,
                })
        if result["cascade_promotions"]:
            conn.commit()

    # §10d Synthetic variants for proven winners — EAs with ≥3 P2-PASSes
    # get a one-shot 30-variant burst exploring symbol family + bool flips +
    # ±30% on top-2 numerics. Triggers ONCE per EA (idempotent via
    # synthetic_variants_spawned_at on build_ea task).
    try:
        from synth_variants import auto_spawn_for_winners
    except ImportError:
        import sys as _sys
        _sys.path.insert(0, str(Path(__file__).resolve().parent))
        from synth_variants import auto_spawn_for_winners
    with connect(root) as conn:
        result["synthetic_variants"] = auto_spawn_for_winners(
            conn, FRAMEWORK_EAS_DIR, min_pass_count=3, max_variants_per_ea=30,
        )

    # §10b P3-PASS → 50 grid (one parent per pump cycle — 50 children is a lot)
    # Same setfile_path lineage check as §10a (see comment above).
    with connect(root) as conn:
        p3_pass = conn.execute(
            """
            SELECT * FROM work_items
            WHERE status='done' AND verdict='PASS' AND phase='P3'
              AND setfile_path NOT LIKE '%_ablation_%'
              AND setfile_path NOT LIKE '%_grid_%'
              AND COALESCE(json_extract(payload_json, '$.ablated_at'), '')=''
            ORDER BY updated_at ASC LIMIT 1
            """
        ).fetchall()
        for wi in p3_pass:
            try:
                report = spawn_ablation_workitems(
                    conn, dict(wi), FRAMEWORK_EAS_DIR,
                    n_variants=50, perturb_pct=0.30, method="grid",
                )
                result["ablation_children"].append(report)
            except Exception as exc:
                result["ablation_children"].append({
                    "parent_id": wi["id"], "ea_id": wi["ea_id"],
                    "method": "grid",
                    "children_count": 0, "reason": f"error: {exc!r}",
                })

    return result


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


def _find_ea_setfiles(ea_id: str, phase: str) -> list[tuple[str, str]]:
    """Return [(symbol, setfile_path)] for the EA's sets/ dir.

    Picks setfiles matching the period detected from the dir (single-period
    EAs are the norm). For P3+, restrict to the surviving_symbols supplied
    by the caller (filter applied externally).
    """
    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return []
    ea_dir = candidates[0]
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        return []
    period = _detect_ea_period(ea_id)
    pat = re.compile(rf"^{re.escape(ea_dir.name)}_(?P<sym>.+?)_{re.escape(period)}_backtest\.set$")
    out: list[tuple[str, str]] = []
    for f in sorted(sets_dir.iterdir()):
        m = pat.match(f.name)
        if m:
            out.append((m.group("sym"), str(f.resolve())))
    return out


def _create_backtest_work_items(conn: sqlite3.Connection, parent_task_id: str,
                                 ea_id: str, phase: str,
                                 surviving_symbols: list[str] | None) -> list[dict[str, str]]:
    """Fan out a backtest task into per-(symbol, setfile) work_items.

    For P2: every setfile in EA's sets/ dir.
    For P3+: only setfiles whose symbol is in surviving_symbols (subset).
    Returns list of created {id, symbol, setfile_path} for the response.
    """
    setfiles = _find_ea_setfiles(ea_id, phase)
    if not setfiles:
        return []
    if surviving_symbols:
        symbol_set = set(surviving_symbols)
        setfiles = [(s, p) for s, p in setfiles if s in symbol_set]
    out: list[dict[str, str]] = []
    now = utc_now()
    for sym, setfile_path in setfiles:
        wid = str(uuid.uuid4())
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status,
               attempt_count, parent_task_id, payload_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
            """,
            (wid, "backtest", phase, ea_id, sym, setfile_path, parent_task_id,
             json.dumps({}, sort_keys=True), now, now),
        )
        out.append({"id": wid, "symbol": sym, "setfile_path": setfile_path})
    return out


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
            kind=f"backtest_{phase.lower().replace('.', '')}",  # P3.5 → 'backtest_p35'
            source_id=pred_row["source_id"],
            card_id=pred_row["card_id"],
            payload=payload,
        )

        # NEW 2026-05-16: also fan out work_items per (ea × symbol × setfile)
        # for the per-symbol queue model. The bundled `tasks` row above stays
        # as the high-level lifecycle anchor; work_items are what the MT5
        # dispatcher actually claims one-by-one.
        work_items_created = _create_backtest_work_items(
            conn,
            parent_task_id=task_id,
            ea_id=ea_id,
            phase=phase,
            surviving_symbols=surviving_symbols,
        )

    return {
        "enqueued": True,
        "task_id": task_id,
        "ea_id": ea_id,
        "phase": phase,
        "work_items_created": work_items_created,
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

    BUG fix 2026-05-17: original regex `_([A-Za-z0-9]+)_backtest\\.set$` had
    two issues — (a) didn't match ablation children which end in
    `_ablation_NN.set` not `_backtest.set`, (b) DID match synth children
    `_D1_synth_000_backtest.set` capturing `000` as a fake period. Result:
    QM5_1049 D1-only setfiles polluted by synth's `000`/`001`/... → no
    unique period → fallback H1 → McConnell-D1 backtest tried on H1 →
    METATESTER_HUNG. That blocked 11 P3 runs.

    Fix: match ONLY canonical MT5 timeframe tokens. Order matters
    (longest first) so H4 doesn't get partial-matched by H.
    """
    ea_root = REPO_ROOT / "framework" / "EAs"
    candidates = [p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return "H1"
    sets_dir = candidates[0] / "sets"
    if not sets_dir.is_dir():
        return "H1"
    VALID_TFS = ("MN1", "W1", "D1", "H12", "H8", "H6", "H4", "H3", "H2", "H1",
                 "M30", "M20", "M15", "M12", "M10", "M6", "M5", "M4", "M3", "M2", "M1")
    pat = re.compile(r"_(" + "|".join(VALID_TFS) + r")_")
    periods: set[str] = set()
    for f in sets_dir.iterdir():
        if not f.name.endswith(".set"):
            continue
        m = pat.search(f.name)
        if m:
            periods.add(m.group(1))
    if len(periods) == 1:
        return periods.pop()
    # Multiple TFs (rare — mixed-TF strategies) OR none detected → conservative default
    if periods:
        # Prefer the longest TF (most strategies are D1/H4 not M1)
        order = {tf: i for i, tf in enumerate(VALID_TFS)}
        return sorted(periods, key=lambda p: order.get(p, 999))[0]
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
        # P2 = LONG in-sample window. OWNER 2026-05-17: 2022-2024 was too
        # short (3y) — strategies that only PASS on recent bull-run noise
        # would slip through. 2017-2022 = 6 years covers GFC echo, COVID
        # crash, post-COVID rally, 2022 inflation regime — much harder to
        # curve-fit. Walk-forward 2023+ stays as the OOS gate (P4).
        cmd = [
            sys.executable,
            str(REPO_ROOT / "framework" / "scripts" / "p2_baseline.py"),
            "--ea", ea_id,
            "--period", period,
            "--from-year", "2017",
            "--to-year", "2022",
            "--min-trades", "10",  # raised from 5 — 6y covers more cycles; demand more data points
        ]
        if terminal:
            cmd.extend(["--terminal", terminal])
        return cmd

    if phase == "P3":
        period = _detect_ea_period(ea_id)
        symbols = surviving_symbols or []
        if not symbols:
            return None
        # P3 = parameter sweep on SAME in-sample window as P2 to test
        # parameter-robustness (Sharpe stable across nearby param values).
        # OWNER 2026-05-17: this is NOT an OOS test — that's P3.5/P4.
        # Same year flag still (single-year sweep is fast); but we can
        # expand once we see how runtimes pan out.
        cmd = [
            sys.executable, "-m", "framework.scripts.p3_param_sweep",
            "--ea", ea_id,
            "--symbols", ",".join(symbols),
            "--periods", period,
            "--year", "2022",  # last year of P2 window — same in-sample regime
            "--max-runs", "24",
            "--max-parallel", "5",
        ]
        return cmd

    if phase == "P3.5":
        # P3.5 = cross-symbol robustness on the SAME in-sample window.
        # Does the edge generalize across multiple DWX symbols? Different
        # from P4 walk-forward (which is true OOS in time).
        period = _detect_ea_period(ea_id)
        symbols = surviving_symbols or []
        if not symbols:
            return None
        cmd = [
            sys.executable, "-m", "framework.scripts.p35_csr_runner",
            "--ea", ea_id,
            "--symbols", ",".join(symbols),
            "--period", period,
            "--from-year", "2017",
            "--to-year", "2022",
        ]
        return cmd

    if phase == "P4":
        # P4 = true OOS Walk-Forward on 2023-now data.
        # Train on rolling 5y windows ending pre-2023, test 6 months OOS.
        period = _detect_ea_period(ea_id)
        symbols = surviving_symbols or []
        if not symbols:
            return None
        cmd = [
            sys.executable, "-m", "framework.scripts.p4_walk_forward",
            "--ea", ea_id,
            "--symbols", ",".join(symbols),
            "--period", period,
            "--train-from-year", "2017",
            "--train-to-year", "2022",
            "--oos-from-year", "2023",
            "--oos-to-year", "2025",
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
        # Phase 1 — poll all active backtest tasks. Tasks that have
        # work_items are owned by dispatch_work_items; this legacy path
        # only handles bundled tasks without per-symbol fan-out.
        active_rows = conn.execute(
            "SELECT t.* FROM tasks t "
            "WHERE t.kind LIKE 'backtest_%' AND t.status = 'active' "
            "AND NOT EXISTS (SELECT 1 FROM work_items wi WHERE wi.parent_task_id = t.id) "
            "ORDER BY t.created_at"
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
                    auto_enqueued = None
                    # Auto-advance: PASS → enqueue next phase as a NEW pending
                    # task. Only when next phase is supported AND no successor
                    # already exists for the same EA. Saves the wait for the
                    # next hourly wake + manual enqueue.
                    if verdict == "PASS":
                        next_phase_map = {"P2": "P3", "P3": "P3.5", "P3.5": "P4"}  # extend as adapters come online
                        next_phase = next_phase_map.get(phase)
                        if next_phase and next_phase in SUPPORTED_BACKTEST_PHASES:
                            next_phase_kind = next_phase.lower().replace(".", "")  # P3.5 → 'p35'
                            existing_next = conn.execute(
                                "SELECT id FROM tasks WHERE kind = ? AND payload_json LIKE ?",
                                (f"backtest_{next_phase_kind}", f"%\"ea_id\": \"{ea_id}\"%"),
                            ).fetchone()
                            if not existing_next:
                                # Need to commit current update first so enqueue sees it
                                conn.commit()
                                enq_result = enqueue_backtest(root, row["id"], next_phase)
                                if enq_result.get("enqueued"):
                                    auto_enqueued = {
                                        "next_phase": next_phase,
                                        "next_task_id": enq_result.get("task_id"),
                                    }
                    actions.append({
                        "task_id": row["id"],
                        "action": "classified",
                        "phase": phase,
                        "ea_id": ea_id,
                        "terminal_released": assigned_terminal,
                        "verdict": verdict,
                        "surviving_symbols": classification.get("surviving_symbols", []),
                        "auto_enqueued_next": auto_enqueued,
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

        # Phase 2 — pick dispatch mode based on pending count + fleet state.
        # Same back-compat filter: skip tasks that have work_items (those
        # belong to dispatch_work_items).
        free_terminals = [t for t in MT5_TERMINALS if t not in busy_terminals]
        pending_rows = conn.execute(
            "SELECT t.* FROM tasks t "
            "WHERE t.kind LIKE 'backtest_%' AND t.status = 'pending' "
            "AND NOT EXISTS (SELECT 1 FROM work_items wi WHERE wi.parent_task_id = t.id) "
            "ORDER BY t.created_at"
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
    sub.add_parser("pump", help="Continuous deterministic worker: dispatch MT5 + auto-spawn Codex + record builds. Run every 5 min.")
    sub.add_parser("health", help="Run 10 pipeline invariants; write state/health.json + alarms log. Cockpit reads health.json for top banner.")
    sub.add_parser("repair", help="Auto-fix detected pipeline anomalies (stranded sources, phantom review fails, ablation grandchildren, stale work_items). Idempotent; safe to run any time.")
    work_items_p = sub.add_parser("work-items", help="Per-(EA × symbol × phase) work_items view")
    work_items_p.add_argument("--status", choices=["pending", "active", "done", "failed"], help="Filter by status")
    work_items_p.add_argument("--ea", help="Filter by ea_id (e.g. QM5_1049)")
    sub.add_parser("backfill-work-items", help="One-shot: populate work_items table from existing backtest tasks + report.csv")
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
    elif args.command == "pump":
        print_json(pump(root))
    elif args.command == "health":
        try:
            from health import run_all as _health_run_all
        except ImportError:
            import sys as _sys
            _sys.path.insert(0, str(Path(__file__).resolve().parent))
            from health import run_all as _health_run_all
        print_json(_health_run_all())
    elif args.command == "repair":
        try:
            from repair import run_all as _repair_run_all
        except ImportError:
            import sys as _sys
            _sys.path.insert(0, str(Path(__file__).resolve().parent))
            from repair import run_all as _repair_run_all
        print_json(_repair_run_all())
    elif args.command == "work-items":
        print_json(work_items_view(root, status_filter=args.status, ea_filter=args.ea))
    elif args.command == "backfill-work-items":
        print_json(backfill_work_items(root))
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
