"""Append-only duplicate disposition of QM5_41221/EURUSD.DWX (OWNER-DEC-DUPLICATE-41221-11421-20260913).

OWNER chat 2026-09-13 ~17:0xZ (verbatim): "Den Klon kannst Du fuer mir streichen."
Evidence: docs/ops/evidence/2026-09-13_dxz_book_v2/FIT_REPORT.md - 41221/EURUSD is the requal8 clone of the
live sleeve 11421/EURUSD (r = 1.0000 over 67 co-active days, identical 91 trades, PF 1.1415, MaxDD 5.9696 %).

Pattern = tools/strategy_farm/apply_q09_retire2_dispositions.py (one-shot, dry-run plan with content hash,
online backup, FactoryMutationLock, append-only ``disposition`` work item, supersession edge; the original
Q14 row is never edited). The census (rebaseline_census STALE_CLS contains SUPERSEDED_DUPLICATE) then stops
counting the pair as qualified; 11421/EURUSD keeps its qualification and its live history.

Usage: python apply_book_v2_duplicate_41221_0913.py plan   -> writes the plan JSON + sha
       python apply_book_v2_duplicate_41221_0913.py apply --plan-sha256 <sha>
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
import uuid
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
from factory_mutation_lock import FactoryMutationLock  # noqa: E402

DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
LOCK = Path("D:/QM/strategy_farm/state/FACTORY_MUTATION.lock")
BACKUP_DIR = Path("D:/QM/strategy_farm/state/backups")
EVIDENCE_DIR = REPO / "docs" / "ops" / "evidence" / "2026-09-13_dxz_book_v2"
PLAN_PATH = EVIDENCE_DIR / "duplicate_41221_disposition_plan.json"
RECEIPT_PATH = EVIDENCE_DIR / "duplicate_41221_disposition_receipt.json"
OWNER_DECISION_ID = "OWNER-DEC-DUPLICATE-41221-11421-20260913"
SOURCE_ID = "dd6facac-ede0-5afe-9883-934cda38ff01"  # QM5_41221 EURUSD.DWX Q14 KEEP_INCUMBENT 2026-09-09
EA_ID, SYMBOL, PHASE = "QM5_41221", "EURUSD.DWX", "Q14"
KEEP_EA = "QM5_11421"
VERBATIM = "Den Klon kannst Du fuer mir streichen."


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def sha256_file(p: Path) -> str:
    return sha256_bytes(p.read_bytes())


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def identity_of(row: sqlite3.Row) -> dict:
    return {"id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"], "phase": row["phase"],
            "status": row["status"], "verdict": row["verdict"], "created_at": row["created_at"],
            "setfile_path": row["setfile_path"]}


def connect(read_only: bool) -> sqlite3.Connection:
    uri = f"file:{DB.as_posix()}?mode={'ro' if read_only else 'rw'}"
    c = sqlite3.connect(uri, uri=True, timeout=30)
    c.row_factory = sqlite3.Row
    return c


def build_plan() -> dict:
    c = connect(True)
    try:
        src = c.execute("SELECT * FROM work_items WHERE id=?", (SOURCE_ID,)).fetchone()
        if src is None or src["ea_id"] != EA_ID or src["symbol"] != SYMBOL or src["phase"] != PHASE:
            raise SystemExit(f"source row mismatch: {dict(src) if src else None}")
        if c.execute("SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (SOURCE_ID,)).fetchone():
            raise SystemExit("source already superseded")
        keep = c.execute("SELECT id, verdict FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q14' AND status='done' ORDER BY updated_at DESC LIMIT 1", (KEEP_EA, SYMBOL)).fetchone()
    finally:
        c.close()
    disposition_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"qm:book-v2-duplicate-disposition:{SOURCE_ID}"))
    plan = {
        "schema": "qm.book-v2-duplicate-disposition-plan/v1",
        "owner_decision_id": OWNER_DECISION_ID,
        "owner_verbatim": VERBATIM,
        "generated_at": utc_now(),
        "source_work_item_id": SOURCE_ID,
        "source_identity_sha256": sha256_bytes(canonical(identity_of(src))),
        "source_identity": identity_of(src),
        "keep_pair": {"ea_id": KEEP_EA, "symbol": SYMBOL, "q14_row": (keep["id"] if keep else None), "q14_verdict": (keep["verdict"] if keep else None)},
        "disposition_work_item_id": disposition_id,
        "disposition_verdict": "SUPERSEDED_DUPLICATE",
        "evidence": "docs/ops/evidence/2026-09-13_dxz_book_v2/FIT_REPORT.md (r = 1.0000, identical 91 trades, PF 1.1415, MaxDD 5.9696 %)",
    }
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    PLAN_PATH.write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"plan": str(PLAN_PATH), "plan_sha256": sha256_file(PLAN_PATH), "disposition_id": disposition_id}, indent=1))
    return plan


def apply(expected_sha: str) -> None:
    if sha256_file(PLAN_PATH) != expected_sha.lower():
        raise SystemExit("plan sha mismatch")
    plan = json.loads(PLAN_PATH.read_text(encoding="utf-8-sig"))
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = BACKUP_DIR / f"farm_state_before_book_v2_duplicate_41221_{stamp}.sqlite"
    src_conn = sqlite3.connect(str(DB), timeout=30); tgt = sqlite3.connect(str(backup))
    try:
        src_conn.backup(tgt)
    finally:
        tgt.close(); src_conn.close()
    applied_at = utc_now()
    payload = {
        "append_only_disposition": True, "disposition": "SUPERSEDED_DUPLICATE",
        "duplicate_of": {"ea_id": KEEP_EA, "symbol": SYMBOL},
        "historical_evidence_preserved": True, "historical_verdicts_preserved": True,
        "owner_decision_id": OWNER_DECISION_ID, "owner_verbatim": VERBATIM,
        "plan_sha256": expected_sha.lower(), "source_work_item_id": SOURCE_ID,
        "verdict_reason": "OWNER_APPROVED_DUPLICATE_PAIR_DISPOSITION_R_1_0000",
        "recorded_by": "claude-orchestrator", "evidence": plan["evidence"],
    }
    with FactoryMutationLock(LOCK, owner="book-v2-duplicate-41221:claude-orchestrator"):
        c = connect(False)
        try:
            c.execute("BEGIN IMMEDIATE")
            src = c.execute("SELECT * FROM work_items WHERE id=?", (SOURCE_ID,)).fetchone()
            if src is None or sha256_bytes(canonical(identity_of(src))) != plan["source_identity_sha256"]:
                raise SystemExit("source identity drift")
            if c.execute("SELECT 1 FROM work_items WHERE id=?", (plan["disposition_work_item_id"],)).fetchone():
                raise SystemExit("disposition already exists")
            if c.execute("SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (SOURCE_ID,)).fetchone():
                raise SystemExit("supersession raced")
            c.execute(
                """INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,parent_task_id,
                     evidence_path,claimed_by,payload_json,created_at,updated_at,verdict_taxonomy_stored,clean_status_stored,
                     gate_contract_version,verdict_taxonomy,sh3_enforced)
                   VALUES(?,'disposition',?,?,?,?,'failed','SUPERSEDED_DUPLICATE',0,NULL,?,NULL,?,?,?,'strategy','failed',?,'strategy',0)""",
                (plan["disposition_work_item_id"], PHASE, EA_ID, SYMBOL, src["setfile_path"], str(RECEIPT_PATH.resolve()),
                 json.dumps(payload, sort_keys=True), applied_at, applied_at, src["gate_contract_version"]))
            c.execute(
                """INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id,reason,source_encoding,evidence_path,recorded_by,recorded_at)
                   VALUES(?,?,?,?,?,?,?)""",
                (SOURCE_ID, plan["disposition_work_item_id"], f"OWNER-approved duplicate disposition (clone of {KEEP_EA}/{SYMBOL}); {OWNER_DECISION_ID}",
                 "owner:book-v2-duplicate/v1", str(RECEIPT_PATH.resolve()), "claude-orchestrator", applied_at))
            c.commit()
        finally:
            c.close()
    receipt = {"schema": "qm.book-v2-duplicate-disposition-receipt/v1", "applied_at": applied_at, "plan_sha256": expected_sha.lower(),
               "backup": str(backup), "backup_sha256": sha256_file(backup), "disposition_work_item_id": plan["disposition_work_item_id"],
               "source_work_item_id": SOURCE_ID, "owner_decision_id": OWNER_DECISION_ID, "owner_verbatim": VERBATIM}
    RECEIPT_PATH.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(receipt, indent=1))


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("plan")
    a = sub.add_parser("apply"); a.add_argument("--plan-sha256", required=True)
    args = ap.parse_args()
    if args.cmd == "plan":
        build_plan()
    else:
        apply(args.plan_sha256)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
