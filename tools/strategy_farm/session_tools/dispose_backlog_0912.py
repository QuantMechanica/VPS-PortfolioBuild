"""OWNER-DEC-BACKLOG-20260912 (chat 2026-09-12 ~08:0xZ): "dann diese Nacharbeiten, fuer die hundertzehn anstossen.
Sechsundsechzig archivieren. Die fuenfundneunzig AGY ... muessten auch angegangen und erledigt werden. Alles
freigegeben, alles restliche bereinigen oder archivieren."

Classified disposition of the RECYCLE (181) and BLOCKED (422) agent_tasks backlog. Dry-run by default; --apply
writes through the router module (canonical writer generation), append-only journal in the payload.

Classes:
  SKIP         video holds (release_video_analysis_holds.py owns them) and rows already handled
  ARCHIVE      -> FAILED, verdict "ARCHIVED (OWNER-DEC-BACKLOG-20260912) <reason>": card gone, superseded,
                  terminal closes, retired/colliding identity, recycle_count >= 2
  PRECONDITION -> stays BLOCKED, tagged for the registry/magic precondition sweeper (Codex ticket 349a8394)
  REQUEUE      -> TODO, payload decision_bound_agent=codex (Sol; agy is backup only), priority note, assigned
                  agent cleared (router re-routes), verdict "REWORK requeued (OWNER-DEC-BACKLOG-20260912)"
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import glob
import json
import os
import re
import sqlite3
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
import agent_router  # noqa: E402

ROOT = Path("D:/QM/strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"
DEC = "OWNER-DEC-BACKLOG-20260912"
CARDS = {"_".join(os.path.basename(x).split("_")[:2]) for x in glob.glob("D:/QM/strategy_farm/artifacts/cards_approved/QM5_*.md")}
EADIRS = {"_".join(x.split("_")[:2]) for x in os.listdir(REPO / "framework" / "EAs") if x.startswith("QM5_")}

ARCHIVE_PAT = re.compile(r"SUPERSEDED|Superseded|superseded|TERMINAL_CLOSE|SELECTION_RELEASED|conditional-obsolete|"
                         r"is retired|collides|UNSTUCK_TO_COMPILE_QUEUE|permanently unclaimable|obsolete", re.I)
PRECOND_PAT = re.compile(r"PRECONDITION_HOLD|D6_BUILD_IDENTITY|no magic rows|no active ea_id|MAGIC_ROWS_REQUIRED", re.I)
VIDEO_PAT = re.compile(r"video_analysis|router_human_lane_hold|OWNER-VID", re.I)


def ea_of(payload: dict) -> str | None:
    ea = payload.get("ea_id") or payload.get("ea_label")
    if ea is not None and str(ea).strip():
        s = str(ea).strip()
        m = re.search(r"\d{4,5}", s)
        if m:
            return "QM5_" + m.group(0)
    m = re.findall(r"QM5_\d{4,5}", json.dumps(payload))
    return collections.Counter(m).most_common(1)[0][0] if m else None


def classify(row: sqlite3.Row) -> tuple[str, str]:
    payload = json.loads(row["payload_json"] or "{}")
    verdict = str(row["verdict"] or "")
    blob = json.dumps(payload) + " " + verdict
    if VIDEO_PAT.search(blob):
        return "SKIP", "video hold (release helper)"
    try:
        rc = int(payload.get("recycle_count") or 0)
    except (TypeError, ValueError):
        rc = 0
    if rc >= 2:
        return "ARCHIVE", f"recycle_count={rc} (failed verification twice)"
    ea = ea_of(payload)
    card_ok = ea is not None and ea in CARDS
    if ARCHIVE_PAT.search(verdict):
        return "ARCHIVE", "terminal/superseded close text"
    if ea is not None and not card_ok:
        return "ARCHIVE", f"card gone ({ea})"
    if PRECOND_PAT.search(verdict):
        return "PRECONDITION", "registry/magic precondition (sweeper 349a8394)"
    if ea is None:
        if re.search(r"duplicate of", verdict, re.I):
            return "ARCHIVE", "duplicate (close text)"
        if row["state"] == "BLOCKED":
            # ops items held on dependencies / OWNER decisions / honest NOT_READY: per-row assessment (sweeper 349a8394)
            return "HOLD", "non-EA dependency/decision hold (sweeper 349a8394 per-row)"
        return "REQUEUE", "non-EA task re-queued"
    return "REQUEUE", "rework " + ea


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--states", default="RECYCLE,BLOCKED")
    args = ap.parse_args()
    states = tuple(s.strip() for s in args.states.split(",") if s.strip())
    conn = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        f"SELECT * FROM agent_tasks WHERE state IN ({','.join('?' * len(states))}) ORDER BY state, updated_at",
        states).fetchall()
    conn.close()
    plan = []
    newest_by_ea: dict[str, str] = {}
    for r in rows:  # rows ordered by updated_at ascending -> the last seen per EA is the newest
        cls, why = classify(r)
        if cls == "REQUEUE" and why.startswith("rework "):
            newest_by_ea[why.split(" ", 1)[1]] = r["id"]
    for r in rows:
        cls, why = classify(r)
        if cls == "REQUEUE" and why.startswith("rework "):
            ea = why.split(" ", 1)[1]
            if newest_by_ea.get(ea) != r["id"]:
                cls, why = "ARCHIVE", f"duplicate rework of {ea} (kept {newest_by_ea[ea][:8]})"
        plan.append((r["id"], r["state"], r["assigned_agent"], cls, why))
    non_ea = [(p[0][:8], p[1]) for p in plan if p[3] == "REQUEUE" and p[4].startswith("non-EA")]
    if non_ea:
        conn2 = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        print("NON-EA REQUEUE titles:")
        for tid, st in non_ea[:40]:
            pj = conn2.execute("SELECT payload_json, verdict FROM agent_tasks WHERE id LIKE ?", (tid + "%",)).fetchone()
            pl = json.loads(pj[0] or "{}")
            print("  ", tid, st, str(pl.get("title") or pl.get("slug") or pl.get("kind") or "")[:80], "|", str(pj[1] or "")[:60])
        conn2.close()
    counts = collections.Counter((p[1], p[3]) for p in plan)
    print("PLAN", dict(sorted(counts.items())))
    samples = collections.defaultdict(list)
    for p in plan:
        if len(samples[(p[1], p[3])]) < 3:
            samples[(p[1], p[3])].append((p[0][:8], p[2], p[4][:70]))
    for k, v in sorted(samples.items()):
        print(" ", k, v)
    if not args.apply:
        return 0
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    done = collections.Counter()
    journal_path = REPO / "docs" / "ops" / "evidence" / "2026-09-12_backlog_disposition_journal.jsonl"
    journal_path.parent.mkdir(parents=True, exist_ok=True)
    with journal_path.open("a", encoding="utf-8") as journal:
        for task_id, state, agent, cls, why in plan:
            if cls in ("SKIP", "PRECONDITION", "HOLD"):
                continue
            if args.limit and sum(done.values()) >= args.limit:
                break
            if cls == "ARCHIVE":
                res = agent_router.update_task(ROOT, task_id, state="FAILED",
                                               verdict=f"ARCHIVED ({DEC}) from {state}: {why}")
            else:
                wconn = agent_router.connect(ROOT)
                try:
                    row = wconn.execute("SELECT payload_json, assigned_agent FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
                    payload = json.loads(row[0] or "{}")
                    payload.setdefault("backlog_disposition_journal", []).append(
                        {"at_utc": now, "decision": DEC, "from_state": state, "previous_assigned_agent": row[1], "why": why})
                    payload[agent_router.DECISION_BOUND_PAYLOAD_FIELD] = "codex"
                    payload["codex_model_tier"] = payload.get("codex_model_tier") or "sol"
                    payload["codex_reasoning_effort"] = payload.get("codex_reasoning_effort") or "high"
                    payload["rework_note"] = ("Re-queued rework (OWNER 2026-09-12): the previous close text explains the defect; "
                                              "fix source to match the approved card, compile via COMPILE_EA only, tests, RESULT line.")
                    wconn.execute("BEGIN IMMEDIATE")
                    wconn.execute("UPDATE agent_tasks SET payload_json=?, updated_at=?, priority=30 WHERE id=?",
                                  (json.dumps(payload, sort_keys=True), now, task_id))
                    try:
                        wconn.execute("UPDATE agent_tasks SET assigned_agent=NULL WHERE id=? AND assigned_agent IS NOT NULL", (task_id,))
                        cleared = True
                    except sqlite3.DatabaseError as exc:
                        cleared = f"assigned_agent kept: {exc}"
                    wconn.commit()
                finally:
                    wconn.close()
                res = agent_router.update_task(ROOT, task_id, state="TODO",
                                               verdict=f"REWORK requeued ({DEC}) from {state}: {why}")
                res = {**(res or {}), "assigned_agent_cleared": cleared}
            ok = bool((res or {}).get("updated", True))
            done[(cls, ok)] += 1
            journal.write(json.dumps({"task_id": task_id, "from": state, "class": cls, "why": why, "result": res,
                                      "at_utc": now}, default=str) + "\n")
    print("APPLIED", dict(done), "journal", journal_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
