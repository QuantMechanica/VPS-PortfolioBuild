#!/usr/bin/env python3
"""Velocity intake pump (Fable session tool, 2026-09-20).

One cycle = (1) commit every receipted .ex5 (COMPILE_OK-bound, tracked-modified or
untracked) with its EA's restamped setfiles, (2) append a Q02 canary for every
COMPILE_OK row of the day that has no Q02 row yet (intake-first-q02 --apply, RAM-
ranked, never SP500), (3) release the next tranche of held COMPILE_EA rows,
(4) print a status table of the day's velocity waves.

Read-only except through the governed farmctl / release_compile_wave paths and the
janitor's receipted-ex5 commit helper. Usage:
    python -X utf8 tools/strategy_farm/session_tools/velocity_intake_pump_0920.py [--tranche N] [--no-release] [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(r"C:\QM\repo")
DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
SINCE = "2026-09-20T16:00"
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
import run_worktree_clean_task as janitor  # noqa: E402


def _run(args: list[str], timeout: int = 600) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True, cwd=str(REPO), timeout=timeout,
                          encoding="utf-8", errors="replace")


def _json(raw: str) -> dict:
    i = raw.find("{")
    try:
        return json.loads(raw[i:]) if i >= 0 else {}
    except json.JSONDecodeError:
        return {}


def _retry_lock(args: list[str], timeout: int = 600, tries: int = 6) -> subprocess.CompletedProcess:
    for _ in range(tries):
        p = _run(args, timeout)
        if "mutation lock is busy" in (p.stdout + p.stderr):
            time.sleep(random.uniform(2, 6))
            continue
        return p
    return p


def compile_rows(con: sqlite3.Connection) -> list[sqlite3.Row]:
    return con.execute(
        "SELECT id, ea_id, status, verdict, updated_at, ex5_sha256 FROM work_items "
        "WHERE kind='compile' AND phase='COMPILE_EA' AND created_at >= ? ORDER BY created_at",
        (SINCE,),
    ).fetchall()


def q02_rows(con: sqlite3.Connection, ea_id: str) -> list[sqlite3.Row]:
    return con.execute(
        "SELECT id, symbol, status, verdict, created_at FROM work_items WHERE ea_id=? AND phase='Q02' "
        "AND created_at >= ? ORDER BY created_at", (ea_id, SINCE)).fetchall()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tranche", type=int, default=10)
    ap.add_argument("--no-release", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    out: dict = {"committed_ex5": [], "canaries": [], "release": None, "status": []}

    # (1) commit receipted binaries
    status = janitor._git_status()
    receipted = janitor._receipted_tracked_ex5(status)
    if receipted and not a.dry_run:
        out["committed_ex5"] = janitor._commit_receipted_tracked_ex5(status)
    else:
        out["committed_ex5"] = receipted

    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    # (2) canaries for COMPILE_OK rows without a Q02 row
    for r in compile_rows(con):
        if r["verdict"] != "COMPILE_OK":
            continue
        if q02_rows(con, r["ea_id"]):
            continue
        args = [sys.executable, "-X", "utf8", "tools/strategy_farm/farmctl.py", "intake-first-q02",
                "--compile-work-item-id", r["id"]]
        if not a.dry_run:
            args.append("--apply")
        p = _retry_lock(args)
        d = _json(p.stdout + p.stderr)
        out["canaries"].append({"ea_id": r["ea_id"], "compile": r["id"][:8], "reason": d.get("reason"),
                                "q02": (d.get("work_item_id") or "")[:8],
                                "canary": {k: (d.get("canary") or {}).get(k) for k in ("symbol", "timeframe")},
                                "detail": {k: str(d.get(k))[:160] for k in ("review_entry_gate", "sha256", "magic") if d.get(k)}})
    con.close()
    # (3) release next tranche
    if not a.no_release and not a.dry_run:
        p = _retry_lock([sys.executable, "-X", "utf8", "tools/strategy_farm/release_compile_wave.py",
                         "--max-items", str(a.tranche), "--apply",
                         "--release-note", "Velocity intake pump (FABLE-DEC-VELOCITY-INTAKE-20260920)"])
        d = _json(p.stdout + p.stderr)
        out["release"] = {"release_count": d.get("release_count"), "held_pending_count": d.get("held_pending_count"),
                          "eas": [e.get("ea_label", "").split("_")[1] for e in (d.get("release") or [])]}
    # (4) status table
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    for r in compile_rows(con):
        q = q02_rows(con, r["ea_id"])
        out["status"].append({"ea": r["ea_id"], "compile": r["verdict"] or r["status"],
                              "q02": [f'{x["symbol"]}:{x["verdict"] or x["status"]}' for x in q]})
    con.close()
    print(json.dumps(out, indent=1, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
