"""Bounded Balke repair admission guard; no backtest or verdict mutation.

Dry-run by default. Preserve pending Q12 rows while the new sibling awaits
compile/review. Exact hold preimages and unchanged work-item digests are recorded.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3

from tools.strategy_farm import farmctl, opt_census
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

ROOT = Path("D:/QM/strategy_farm")
REPO = Path("C:/QM/repo")
EA = "QM5_41398_balke-pattern-repair-opt"
OLD = "QM5_41097_balke-gmt3-range-breakout-opt"
DECISION = "CEO-DEC-BALKE-PATTERN-RECOVERY-20260909"
HOLD = "BALKE_PATTERN_REPAIR_REVIEW_PENDING"
HARNESS = "ccd5acb4-af10-51ce-8b64-8953a6cb2a4b"
Q12_IDS = frozenset({
    "ed127702-3a08-59fa-888a-c3a0a20a0803",
    "0e5eff83-75b8-5c59-99d0-609f5f2fb65c",
    "97908d93-3ff8-5528-9518-8968aea72342",
})
OLD_SOURCE_SHA = "8e5cfdbf6f513bdbfd5fdcd25357907cad124497123b8a1abe133c9f2d1d6329"
OLD_EX5_SHA = "e077660cc9ac5d74a6edc8896b72249f221fb030279bbd022f7e9d7756bb3a2e"
PATTERN_SHA = "101cc2230e32d88970a89aadea167a8cece2a64074f450a3946f7302dcd2039e"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def validate_scope(rows):
    if {r["id"] for r in rows} != Q12_IDS:
        raise ValueError("Balke pending Q12 scope changed; inspect before applying")
    for r in rows:
        if (r["ea_id"] != "QM5_13213" or r["symbol"] != "USDJPY.DWX"
                or r["phase"] != "Q12" or r["status"] != "pending"
                or r["verdict"] is not None or r["claimed_by"] is not None):
            raise ValueError("only exact unclaimed, unverdicted Balke Q12 rows allowed")


def inspect(db):
    old_dir = REPO / "framework/EAs" / OLD
    if sha(old_dir / (OLD + ".mq5")) != OLD_SOURCE_SHA:
        raise ValueError("frozen Balke source drift")
    if sha(old_dir / (OLD + ".ex5")) != OLD_EX5_SHA:
        raise ValueError("frozen Balke binary drift")
    pattern = REPO / "framework/include/QM/QM_PatternPermission.mqh"
    if hashlib.sha256(pattern.read_bytes().replace(b"\r\n", b"\n")).hexdigest() != PATTERN_SHA:
        raise ValueError("repaired pattern source drift")
    harness = opt_census._harness_pass(db, HARNESS)
    rows = [dict(r) for r in db.execute(
        "SELECT * FROM work_items WHERE ea_id='QM5_13213' AND symbol='USDJPY.DWX' "
        "AND phase='Q12' AND status='pending' ORDER BY id")]
    validate_scope(rows)
    holds = []
    for r in rows:
        existing = db.execute("SELECT * FROM work_item_holds WHERE work_item_id=?", (r["id"],)).fetchone()
        h = dict(existing) if existing else None
        if h and h["hold_code"] not in {HOLD, "Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING"}:
            raise ValueError("unrelated hold present; do not replace")
        holds.append({"work_item_id": r["id"], "before": h})
    return rows, {"schema": "qm.balke-pattern-recovery-admission/v1",
        "decision": DECISION, "created_at_utc": farmctl.utc_now(),
        "new_measurement_ea": EA, "fixture_harness": harness,
        "frozen_source_sha256": OLD_SOURCE_SHA, "frozen_ex5_sha256": OLD_EX5_SHA,
        "new_source_sha256": sha(REPO / "framework/EAs" / EA / (EA + ".mq5")),
        "work_items_before_sha256": digest(rows), "holds": holds,
        "economic_reruns_enqueued": 0, "work_item_verdicts_changed": 0}


def install_holds(db, rows, receipt):
    validate_scope(rows)
    now = farmctl.utc_now()
    reason = DECISION + ": native compile and independent review of QM5_41398 required; preserve duplicate declarations"
    for r in rows:
        db.execute("""INSERT INTO work_item_holds
            (work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at)
            VALUES(?,?,?,1,0,?,?) ON CONFLICT(work_item_id) DO UPDATE SET
            hold_code=excluded.hold_code,reason=excluded.reason,active=1,
            release_on_restart=0,updated_at=excluded.updated_at,
            released_at=NULL,release_note=NULL""", (r["id"], HOLD, reason, now, now))
    after = [dict(db.execute("SELECT * FROM work_items WHERE id=?", (r["id"],)).fetchone()) for r in rows]
    if digest(after) != receipt["work_items_before_sha256"]:
        raise ValueError("work item changed during hold installation")
    receipt["work_items_after_sha256"] = digest(after)
    receipt["applied"] = True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        raise ValueError("receipt already exists; inspect it rather than overwrite")
    if args.apply:
        with FactoryMutationLock(owner=DECISION), farmctl.connect(ROOT) as db:
            db.execute("BEGIN IMMEDIATE")
            rows, receipt = inspect(db)
            install_holds(db, rows, receipt)
            args.out.parent.mkdir(parents=True, exist_ok=True)
            with args.out.open("x", encoding="utf-8") as fh:
                json.dump(receipt, fh, indent=2)
            db.commit()
    else:
        with sqlite3.connect((ROOT / "state/farm_state.sqlite").as_uri() + "?mode=ro", uri=True) as db:
            db.row_factory = sqlite3.Row
            _, receipt = inspect(db)
        receipt["applied"] = False
        args.out.parent.mkdir(parents=True, exist_ok=True)
        with args.out.open("x", encoding="utf-8") as fh:
            json.dump(receipt, fh, indent=2)
    print(json.dumps({"out": str(args.out), "applied": receipt["applied"],
                      "q12_count": len(receipt["holds"]), "harness": HARNESS}))


if __name__ == "__main__":
    main()
