"""Second-chance funnel tracker (``qm.second-chance-funnel/v1``).

READ-MODEL for the Strategy Second-Chance Programme
(``docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`` §5.1). Reads every
``agent_tasks`` row whose payload carries ``kind='second_chance_retest'`` and
classifies each candidate into the linear funnel::

    commissioned -> review -> new-lineage-card -> intake-q00
                 -> factory-work-item -> mt5-evidence -> portfolio-evaluated

Stage derivation is purely read-only and evidence-based; a stage is "reached"
only when its artifact EXISTS on disk / in the DB:

  * commissioned        — the agent task row exists (payload.kind =
                          'second_chance_retest'). Always true for a listed row.
  * review              — task state has reached the review lane or beyond
                          (REVIEW, APPROVED, PIPELINE, PASSED, FAILED, RECYCLE,
                          OPS_FIX_REQUIRED). BACKLOG/TODO/IN_PROGRESS mean an
                          agent still owns the drafting work.
  * new-lineage-card    — the drafted card file exists:
                          ``cards_review/PENDING_<TASKID8>_*.md`` (the exact
                          name pattern the commissioning verdict announces).
  * intake-q00          — a NEW-LINEAGE work item linked to this retest exists
                          with phase 'Q00'. Linkage keys: the work item payload
                          contains the commission task id (full UUID or its
                          8-char prefix). The ORIGIN ea_id is deliberately NOT
                          a linkage key — the origin's historical work items are
                          evidence, never retest progress.
  * factory-work-item   — a linked work item has reached a factory band phase
                          (Q01..Q11, any status).
  * mt5-evidence        — an evidence directory exists for a retest-linked
                          (minted) ea_id under ``D:/QM/reports/pipeline/<ea>``.
  * portfolio-evaluated — a ``portfolio_candidates`` row exists for a
                          retest-linked ea_id (state recorded).

Retest-linked ea ids are resolved from the linked work items' ea_id plus any
explicit mint field the lanes later write into the task payload
(``minted_ea_id`` / ``new_ea_id`` / ``retest_ea_id``).

The module NEVER writes agent_tasks, NEVER advances a stage, and never touches
work_items / portfolio_candidates — advancement stays with the review lanes.
It writes only ``D:/QM/reports/state/second_chance_funnel.json`` and prints a
compact table. Missing inputs are explicit (``EVIDENCE_MISSING`` / absent
artifact lists), never invented.

CLI::

    python tools/strategy_farm/second_chance_funnel.py
    python tools/strategy_farm/second_chance_funnel.py --stdout
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "qm.second-chance-funnel/v1"

# --- canonical paths (module-level so tests can monkeypatch) ---
ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_STATE = Path(r"D:\QM\reports\state")
DB = ROOT / "state" / "farm_state.sqlite"
CARDS_REVIEW = ROOT / "artifacts" / "cards_review"
PIPELINE_DIR = Path(r"D:\QM\reports\pipeline")
OUTPUT_PATH = REPORTS_STATE / "second_chance_funnel.json"

STAGES = (
    "commissioned",
    "review",
    "new-lineage-card",
    "intake-q00",
    "factory-work-item",
    "mt5-evidence",
    "portfolio-evaluated",
)

# States that mean the task reached (or passed) the review lane.
REVIEW_OR_BEYOND = frozenset({
    "REVIEW", "APPROVED", "PIPELINE", "PASSED", "FAILED", "RECYCLE",
    "OPS_FIX_REQUIRED",
})

# Factory-band phases: past intake (Q00) and before the portfolio gate (Q12+).
FACTORY_BAND_PHASES = frozenset(f"Q{i:02d}" for i in range(1, 12))

# Payload keys a lane may later write to record the minted retest ea_id.
MINTED_EA_PAYLOAD_KEYS = ("minted_ea_id", "new_ea_id", "retest_ea_id")


# ---------------------------------------------------------------------------
# time helpers
# ---------------------------------------------------------------------------
def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(t: dt.datetime) -> str:
    return t.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


# ---------------------------------------------------------------------------
# database access (read-only)
# ---------------------------------------------------------------------------
def _connect_ro(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA busy_timeout=5000")
    con.execute("PRAGMA query_only=ON")
    return con


def load_candidates(con: sqlite3.Connection) -> list[dict[str, Any]]:
    """Every second-chance commission ticket, newest first."""
    rows = con.execute(
        "SELECT id, task_type, state, verdict, payload_json, created_at, "
        "updated_at FROM agent_tasks "
        "WHERE payload_json LIKE '%\"kind\": \"second_chance_retest\"%' "
        "OR payload_json LIKE '%\"kind\":\"second_chance_retest\"%' "
        "ORDER BY created_at"
    ).fetchall()
    candidates: list[dict[str, Any]] = []
    for row in rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except json.JSONDecodeError:
            payload = {}
        if payload.get("kind") != "second_chance_retest":
            continue  # LIKE match on a different kind mentioning the string
        candidates.append({
            "task_id": str(row["id"]),
            "task_state": str(row["state"]),
            "task_verdict": row["verdict"],
            "task_type": row["task_type"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
            "payload": payload,
        })
    return candidates


def load_linked_work_items(con: sqlite3.Connection, task_id: str,
                           ) -> list[dict[str, Any]]:
    """Work items carrying this commission ticket in their payload (the
    NEW-lineage retest rows). The origin ea_id is not a key here."""
    task8 = task_id[:8]
    rows = con.execute(
        "SELECT id, ea_id, phase, status FROM work_items "
        "WHERE payload_json LIKE ? OR payload_json LIKE ? ORDER BY created_at",
        (f"%{task_id}%", f"%{task8}%"),
    ).fetchall()
    return [dict(r) for r in rows]


def load_portfolio_states(con: sqlite3.Connection,
                          ea_ids: list[str]) -> list[dict[str, Any]]:
    """portfolio_candidates rows for retest-linked ea ids, if any."""
    if not ea_ids:
        return []
    marks = ",".join("?" for _ in ea_ids)
    rows = con.execute(
        f"SELECT ea_id, symbol, state, q11_work_item_id "
        f"FROM portfolio_candidates WHERE ea_id IN ({marks})",
        ea_ids,
    ).fetchall()
    return [dict(r) for r in rows]


# ---------------------------------------------------------------------------
# per-candidate classification
# ---------------------------------------------------------------------------
def _task8(task_id: str) -> str:
    return task_id[:8].upper()


def find_pending_card(cards_review_dir: Path, task_id: str) -> list[str]:
    """The drafted NEW-lineage card the commissioning verdict announces
    (``card drafted under PENDING_<TASKID8> in cards_review``)."""
    hits = sorted(
        str(p) for p in Path(cards_review_dir).glob(
            f"PENDING_{_task8(task_id)}_*.md")
    )
    return hits


def resolve_minted_ea_ids(payload: dict[str, Any],
                          linked_items: list[dict[str, Any]],
                          origin_ea_id: str) -> list[str]:
    """Retest-linked ea ids: from linked work items plus explicit mint fields
    in the task payload. The origin ea_id is excluded by construction."""
    ids: list[str] = []
    for key in MINTED_EA_PAYLOAD_KEYS:
        value = payload.get(key)
        if isinstance(value, str) and value and value != origin_ea_id:
            ids.append(value)
    for item in linked_items:
        ea = str(item.get("ea_id") or "")
        if ea and ea != origin_ea_id and ea not in ids:
            ids.append(ea)
    return ids


def classify_candidate(candidate: dict[str, Any], con: sqlite3.Connection, *,
                       cards_review_dir: Path = CARDS_REVIEW,
                       pipeline_dir: Path = PIPELINE_DIR) -> dict[str, Any]:
    payload = candidate["payload"]
    task_id = candidate["task_id"]
    origin_ea_id = str(payload.get("origin_ea_id") or "")
    provenance = payload.get("provenance") or {}
    commissioned_at = provenance.get("commissioned_at_utc") or \
        candidate.get("created_at")

    linked_items = load_linked_work_items(con, task_id)
    minted = resolve_minted_ea_ids(payload, linked_items, origin_ea_id)
    cards = find_pending_card(cards_review_dir, task_id)

    stages: dict[str, dict[str, Any]] = {}

    stages["commissioned"] = {
        "reached": True,
        "evidence": [f"agent_tasks:{task_id}"],
    }
    in_review = candidate["task_state"] in REVIEW_OR_BEYOND
    stages["review"] = {
        "reached": in_review,
        "evidence": [f"agent_tasks.state={candidate['task_state']}"],
    }
    stages["new-lineage-card"] = {
        "reached": bool(cards),
        "evidence": cards or [],
    }

    q00_ids = [i["id"] for i in linked_items if i.get("phase") == "Q00"]
    stages["intake-q00"] = {
        "reached": bool(q00_ids),
        "evidence": [f"work_items:{i}" for i in q00_ids],
    }
    factory_items = [i for i in linked_items
                     if i.get("phase") in FACTORY_BAND_PHASES]
    stages["factory-work-item"] = {
        "reached": bool(factory_items),
        "evidence": [
            f"work_items:{i['id']}:{i['phase']}" for i in factory_items
        ],
    }

    evidence_dirs = []
    for ea in minted:
        d = Path(pipeline_dir) / ea
        try:
            entries = sorted(p.name for p in d.iterdir())
        except OSError:
            continue
        if entries:
            evidence_dirs.append({"ea_id": ea, "dir": str(d),
                                  "entries": len(entries)})
    stages["mt5-evidence"] = {
        "reached": bool(evidence_dirs),
        "evidence": evidence_dirs,
    }

    portfolio = load_portfolio_states(con, minted)
    stages["portfolio-evaluated"] = {
        "reached": bool(portfolio),
        "evidence": [
            f"portfolio_candidates:{p['ea_id']}:{p['symbol']}:{p['state']}"
            for p in portfolio
        ],
    }

    furthest = "commissioned"
    for stage in STAGES:
        if stages[stage]["reached"]:
            furthest = stage

    return {
        "task_id": task_id,
        "task_state": candidate["task_state"],
        "origin_ea_id": origin_ea_id,
        "origin_slug": payload.get("origin_slug"),
        "second_chance_reason": payload.get("second_chance_reason"),
        "wave": provenance.get("source"),
        "commissioned_at_utc": commissioned_at,
        "linked_ea_ids": minted,
        "linked_work_item_ids": [i["id"] for i in linked_items],
        "furthest_stage": furthest,
        "stages": stages,
    }


# ---------------------------------------------------------------------------
# assembly + output
# ---------------------------------------------------------------------------
def build_funnel(con: sqlite3.Connection, *, now: dt.datetime,
                 cards_review_dir: Path = CARDS_REVIEW,
                 pipeline_dir: Path = PIPELINE_DIR) -> dict[str, Any]:
    candidates = [
        classify_candidate(c, con, cards_review_dir=cards_review_dir,
                           pipeline_dir=pipeline_dir)
        for c in load_candidates(con)
    ]
    by_stage: dict[str, int] = {s: 0 for s in STAGES}
    for c in candidates:
        by_stage[c["furthest_stage"]] += 1
    return {
        "schema": SCHEMA_VERSION,
        "generated_at_utc": _iso(now),
        "stages": list(STAGES),
        "candidates": candidates,
        "summary": {
            "total": len(candidates),
            "by_furthest_stage": by_stage,
        },
        "sources": {
            "db": str(DB),
            "cards_review_dir": str(cards_review_dir),
            "pipeline_dir": str(pipeline_dir),
        },
    }


def render_table(doc: dict[str, Any]) -> str:
    """Compact funnel table for stdout / logs."""
    headers = ("task", "wave", "origin", "reason", "state", "furthest stage")
    rows = []
    for c in doc["candidates"]:
        rows.append((
            c["task_id"][:8],
            str(c["wave"] or "-"),
            c["origin_ea_id"] or "-",
            str(c["second_chance_reason"] or "-"),
            c["task_state"],
            c["furthest_stage"],
        ))
    widths = [len(h) for h in headers]
    for row in rows:
        widths = [max(w, len(cell)) for w, cell in zip(widths, row)]
    line = "  ".join(h.ljust(w) for h, w in zip(headers, widths))
    sep = "  ".join("-" * w for w in widths)
    body = ["  ".join(cell.ljust(w) for cell, w in zip(row, widths))
            for row in rows]
    if not body:
        body = ["(no second_chance_retest agent tasks)"]
    return "\n".join([line, sep, *body])


def write_text_atomic(path: Path, rendered: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(rendered, encoding="utf-8", newline="\n")
    os.replace(temp, path)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DB,
                        help="override farm_state.sqlite path")
    parser.add_argument("--cards-review-dir", type=Path, default=CARDS_REVIEW)
    parser.add_argument("--pipeline-dir", type=Path, default=PIPELINE_DIR)
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH,
                        help="second_chance_funnel.json output path")
    parser.add_argument("--stdout", action="store_true",
                        help="also print the JSON read-model to stdout")
    args = parser.parse_args(argv)

    now = _now_utc()
    con = _connect_ro(args.db)
    try:
        doc = build_funnel(con, now=now, cards_review_dir=args.cards_review_dir,
                           pipeline_dir=args.pipeline_dir)
    finally:
        con.close()

    rendered = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    write_text_atomic(args.output, rendered)

    table = render_table(doc)
    sys.stdout.write(table + "\n")
    if args.stdout:
        sys.stdout.write(rendered)

    _err = sys.stderr if sys.stderr is not None else open(
        os.devnull, "w", encoding="utf-8")
    _err.write(
        f"[second_chance_funnel] total={doc['summary']['total']} "
        f"by_stage={doc['summary']['by_furthest_stage']} -> {args.output}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
