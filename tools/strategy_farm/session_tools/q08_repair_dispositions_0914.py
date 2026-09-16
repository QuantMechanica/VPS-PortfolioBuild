"""Append-only dispositions for OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916 (batch-1 build-identity repair).

Mirrors apply_q09_retire2_dispositions.py: online SQLite backup, FactoryMutationLock, one
``kind='disposition'`` row per target (status failed, verdict SUPERSEDED_<why>), one
``work_item_supersedes`` edge (target -> disposition row, or -> the named successor), and the
release of the target's active hold when one is named.  Original rows are never edited.

Targets (plan below, frozen in this file) — the 8 batch-1 rows of OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916
whose cards were amended (valid single-configuration declaration) but whose staged Q08 rows carry
NULL build identity (mq5/ex5/setfile_sha256 columns + no payload artifact_identity), an enqueue-time
defect of the 2026-09-15/16 parked cohort (claimability_precheck: BUILD_IDENTITY_MISMATCH:<role>):
  A  7bc8b34e QM5_1159, d4aebc12 QM5_10804, 383c45b0 QM5_10661, 20c533da QM5_10211,
     a937b9bc QM5_12958, 15fed5d8 QM5_9123, aa0fa828 QM5_10291, 94d46fe7 QM5_10267
     -> superseded by the disposition row; a fresh Q08 from the Q07 predecessor with the
        current-build binding follows (farmctl enqueue-backtest --phase Q08 --from-work-item-id
        <Q07> --expected-current-ex5-sha256 <current ex5 sha>); no holds exist on these rows.
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
EVID = REPO / "docs" / "ops" / "evidence" / "2026-09-16_q08_amend_v3" / "repair_fresh_enqueue"
RECEIPT = EVID / "dispositions_receipt.json"
DECISION_ID = "OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916"
OWNER_RECEIPT = "d59b2277"
TASK_ID = "c4f2a8e1"
HOLD = "Q08_DSR_CONTEXT_UNAVAILABLE"

_REASON_V3 = (
    "staged Q08 row carries NULL build identity (mq5/ex5/setfile_sha256 columns + no payload "
    "artifact_identity), an enqueue-time defect of the 2026-09-15/16 parked cohort; the card's "
    "single-configuration declaration was amended under OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916; "
    "a fresh Q08 from the Q07 predecessor with the current-build binding follows"
)
PLAN = [
    {"prefix": p, "cls": "A", "verdict": "SUPERSEDED_REPAIR", "successor_prefix": None, "release_hold": False,
     "reason": _REASON_V3}
    for p in ("7bc8b34e", "d4aebc12", "383c45b0", "20c533da", "a937b9bc", "15fed5d8", "aa0fa828", "94d46fe7")
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
