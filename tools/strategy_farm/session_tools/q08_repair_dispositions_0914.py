"""Append-only dispositions for OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914 (classes A and D).

Mirrors apply_q09_retire2_dispositions.py: online SQLite backup, FactoryMutationLock, one
``kind='disposition'`` row per target (status failed, verdict SUPERSEDED_<why>), one
``work_item_supersedes`` edge (target -> disposition row, or -> the named successor), and the
release of the target's active hold when one is named.  Original rows are never edited.

Targets (plan below, frozen in this file):
  D  19c9df13 QM5_11167 old identity, INVALID -> superseded by 89ea5894 (same identity, FAIL_SOFT)
  D  737a2134 QM5_11167 old identity, pending held -> superseded (identity rebuilt per
     OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT); hold Q08_DSR_CONTEXT_UNAVAILABLE released
  A  ten pending Q08 rows whose recorded build identity is stale or whose payload carries no
     timeframe (single.validate: BUILD_IDENTITY_MISMATCH / SINGLE_CONFIG_CANDIDATE_MISMATCH):
     superseded by the disposition row; a fresh Q08 from the Q07 predecessor follows
     (q08_repair_fresh_enqueue_0914 step); holds Q08_DSR_CONTEXT_UNAVAILABLE released.
Default = dry-run (prints the plan); --apply executes; receipt JSON under the evidence dir.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import sqlite3
import sys
import uuid
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
os.chdir(REPO)
from factory_mutation_lock import FactoryMutationLock  # noqa: E402

DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
BACKUP_DIR = Path("D:/QM/strategy_farm/state/backups")
LOCK = Path("D:/QM/strategy_farm/state/FACTORY_MUTATION.lock")
EVID = REPO / "docs" / "ops" / "evidence" / "2026-09-14_q08_context_repair"
RECEIPT = EVID / "dispositions_receipt.json"
DECISION_ID = "OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914"
OWNER_RECEIPT = "3415f6c0"
TASK_ID = "3ec11996"
HOLD = "Q08_DSR_CONTEXT_UNAVAILABLE"

PLAN = [
    {"prefix": "19c9df13", "cls": "D", "verdict": "SUPERSEDED_IDENTITY", "successor_prefix": "89ea5894", "release_hold": False,
     "reason": "QM5_11167 old identity; same-identity Q08 89ea5894 (FAIL_SOFT) already stands; identity rebuilt per OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT"},
    {"prefix": "737a2134", "cls": "D", "verdict": "SUPERSEDED_IDENTITY", "successor_prefix": None, "release_hold": True,
     "reason": "QM5_11167 old identity pending Q08; identity rebuilt per OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT; no rerun of the old identity"},
] + [
    {"prefix": p, "cls": "A", "verdict": "SUPERSEDED_REPAIR", "successor_prefix": None, "release_hold": True,
     "reason": "stale build identity or missing timeframe on the pending Q08 row; a fresh Q08 from the Q07 predecessor with the declared single configuration follows"}
    for p in ("b68d05cd", "ffbc4cab", "15f2ecb0", "2b5e5be0", "334ca1c5", "e8e0372e", "2e2be584", "080a08f6", "6caa65b7", "010fd451")
]


def backup() -> tuple[Path, str]:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    dest = BACKUP_DIR / f"farm_state_before_q08_repair_dispositions_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    src = sqlite3.connect(str(DB))
    try:
        target = sqlite3.connect(str(dest))
        try:
            src.backup(target)
        finally:
            target.close()
    finally:
        src.close()
    return dest, hashlib.sha256(dest.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--extra", default="", help="comma-separated extra class-A row prefixes (stale rows found after the frozen plan)")
    ap.add_argument("--only-extra", action="store_true")
    args = ap.parse_args()
    global PLAN
    extra = [{"prefix": x.strip(), "cls": "A", "verdict": "SUPERSEDED_REPAIR", "successor_prefix": None, "release_hold": True,
              "reason": "stale build identity (predecessor artifact hashes copied before the 2026-09-13 source repairs) on a Q08 row; a fresh Q08 pinned to the current build follows"}
             for x in args.extra.split(",") if x.strip()]
    PLAN = extra if args.only_extra else PLAN + extra
    ro = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True, timeout=60)
    ro.row_factory = sqlite3.Row
    resolved = []
    for t in PLAN:
        row = ro.execute("SELECT * FROM work_items WHERE id LIKE ?", (t["prefix"] + "%",)).fetchone()
        if row is None:
            print("MISSING", t["prefix"]); return 2
        succ = None
        if t["successor_prefix"]:
            s = ro.execute("SELECT id FROM work_items WHERE id LIKE ?", (t["successor_prefix"] + "%",)).fetchone()
            if s is None:
                print("SUCCESSOR MISSING", t["successor_prefix"]); return 2
            succ = s["id"]
        already = ro.execute("SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (row["id"],)).fetchone()
        hold = ro.execute("SELECT 1 FROM work_item_holds WHERE work_item_id=? AND hold_code=? AND active=1", (row["id"], HOLD)).fetchone()
        print(("PLAN " if not args.apply else "APPLY"), t["cls"], t["prefix"], row["ea_id"], row["symbol"][:12], row["status"], str(row["verdict"]), "| superseded already:", bool(already), "| hold:", bool(hold), "| release:", t["release_hold"])
        if already:
            continue
        resolved.append((t, dict(row), succ, bool(hold)))
    ro.close()
    if not args.apply:
        print(f"dry-run: {len(resolved)} dispositions would be written")
        return 0
    backup_path, backup_sha = backup()
    applied_at = dt.datetime.now(dt.timezone.utc).isoformat()
    global RECEIPT
    if RECEIPT.exists():  # append-only receipts: never overwrite an earlier run
        RECEIPT = EVID / f"dispositions_receipt_{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.json"
    receipt = {"schema": "qm.q08-context-repair-dispositions/v1", "decision_id": DECISION_ID, "owner_receipt_prefix": OWNER_RECEIPT,
               "router_task_prefix": TASK_ID, "applied_at_utc": applied_at, "backup": {"path": str(backup_path), "sha256": backup_sha}, "rows": []}
    with FactoryMutationLock(LOCK, owner=f"q08-repair-dispositions:{TASK_ID}"):
        conn = sqlite3.connect(str(DB), timeout=60)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            for t, row, succ, hold in resolved:
                current = conn.execute("SELECT status, verdict, claimed_by FROM work_items WHERE id=?", (row["id"],)).fetchone()
                if current["status"] != row["status"] or current["verdict"] != row["verdict"] or (current["claimed_by"] or None) != (row["claimed_by"] or None):
                    raise RuntimeError(f"row changed under lock: {row['id']}")
                if current["claimed_by"] and row["status"] == "active":
                    raise RuntimeError(f"row is active on {current['claimed_by']}: {row['id']}")
                disp_id = str(uuid.uuid4())
                payload = {"schema": "qm.q08-context-repair-disposition/v1", "class": t["cls"], "decision_id": DECISION_ID,
                           "owner_receipt_prefix": OWNER_RECEIPT, "router_task_prefix": TASK_ID, "source_work_item_id": row["id"],
                           "successor_work_item_id": succ, "verdict_reason": t["reason"], "append_only_disposition": True,
                           "source_stale_claimed_by": row.get("claimed_by")}
                conn.execute(
                    """INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,parent_task_id,
                       evidence_path,claimed_by,payload_json,created_at,updated_at,verdict_taxonomy_stored,clean_status_stored,
                       gate_contract_version,verdict_taxonomy,sh3_enforced)
                       VALUES(?,'disposition','Q08',?,?,?,'failed',?,0,NULL,?,NULL,?,?,?,'strategy','failed',?,'strategy',0)""",
                    (disp_id, row["ea_id"], row["symbol"], row["setfile_path"], t["verdict"], str(RECEIPT.resolve()),
                     json.dumps(payload, sort_keys=True), applied_at, applied_at, row["gate_contract_version"]),
                )
                conn.execute(
                    """INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id,reason,source_encoding,evidence_path,recorded_by,recorded_at)
                       VALUES(?,?,?,?,?,?,?)""",
                    (row["id"], succ or disp_id, f"{DECISION_ID} class {t['cls']}: {t['reason']}", "owner:q08-context-repair-v2/v1",
                     str(RECEIPT.resolve()), "claude", applied_at),
                )
                released = 0
                if t["release_hold"] and hold:
                    cur = conn.execute(
                        """UPDATE work_item_holds SET active=0, updated_at=?, released_at=?, release_note=?
                           WHERE work_item_id=? AND hold_code=? AND active=1""",
                        (applied_at, applied_at, f"{DECISION_ID}: row superseded by disposition {disp_id}", row["id"], HOLD),
                    )
                    released = cur.rowcount
                receipt["rows"].append({"class": t["cls"], "source": row["id"], "disposition": disp_id, "superseded_by": succ or disp_id,
                                        "verdict": t["verdict"], "hold_released": released})
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    EVID.mkdir(parents=True, exist_ok=True)
    RECEIPT.write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(f"applied {len(receipt['rows'])} dispositions; receipt {RECEIPT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
