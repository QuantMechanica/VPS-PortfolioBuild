"""OWNER E1-C Option B: governed per-row hold release for UNCHANGED_EQUIVALENT rows.

Uses news_calendar_taint.release_e1c_item() exactly as designed: one row per
call inside a caller-owned write transaction under the factory mutation lock.
The marker is stamped into the row payload and only this module's
NEWS_CALENDAR_TAINTED hold is released. Status, verdict and evidence are never
touched. The tainted sha config entry is KEPT (the old bundle is still
tainted); the marker is the per-row counter-path, so the sweep/claim guard
re-verifies the delta record bytes on every pass and re-arms the hold on any
tampering (fail closed).

Usage:
  python release_e1c_optionb_rows.py --dry-run                 # verify only
  python release_e1c_optionb_rows.py --apply                   # release all eligible
  python release_e1c_optionb_rows.py --apply <work_item_id>... # release subset

Writes a receipt under docs/ops/evidence/2026-09-16_e1c_optionb/.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import sqlite3
import sys

REPO = pathlib.Path(r"C:\QM\repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO))
import farmctl  # noqa: E402
import news_calendar_taint as taint  # noqa: E402

DB = pathlib.Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
ROOT = pathlib.Path(r"D:\QM\strategy_farm")
EVIDENCE = REPO / "docs" / "ops" / "evidence" / "2026-09-16_e1c_optionb"
RELEASED_BY = "kimi-interim-e1c-optionb"


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work_item_ids", nargs="*")
    parser.add_argument("--apply", action="store_true", help="execute releases (default: dry-run)")
    parser.add_argument("--released-by", default=RELEASED_BY)
    args = parser.parse_args()

    summary_raw = (EVIDENCE / "summary.json").read_bytes()
    summary = json.loads(summary_raw.decode("utf-8-sig"))
    summary_sha = hashlib.sha256(canonical({k: v for k, v in summary.items() if k != "summary_sha256"})).hexdigest()
    if summary_sha != summary.get("summary_sha256"):
        print(json.dumps({"fatal": "summary sha256 mismatch", "expected": summary.get("summary_sha256"),
                          "actual": summary_sha}))
        return 2

    eligible = {r["work_item_id"]: r for r in summary["rows"] if r.get("release_eligible")}
    if args.work_item_ids:
        unknown = [w for w in args.work_item_ids if w not in eligible]
        if unknown:
            print(json.dumps({"fatal": "work item(s) not release-eligible per summary",
                              "unknown": unknown}))
            return 2
        targets = args.work_item_ids
    else:
        targets = sorted(eligible)

    receipt = {
        "schema": "qm.e1c-optionb-release-receipt/v1",
        "at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "actor": args.released_by,
        "decision_id": taint.E1C_DECISION_ID,
        "mode": "apply" if args.apply else "dry-run",
        "pin_manifest": str(farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST),
        "summary_sha256": summary.get("summary_sha256"),
        "rows": [],
    }

    def release_one(conn, wid):
        record_path = EVIDENCE / "rows" / f"{wid}.json"
        record_raw = record_path.read_bytes()
        record = json.loads(record_raw.decode("utf-8-sig"))
        if record.get("record_sha256") != taint._record_digest(record):
            raise ValueError("record self-hash mismatch on disk")
        return taint.release_e1c_item(
            conn, wid, farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST,
            record_path=record_path,
            record_sha256=record.get("record_sha256"),
            released_by=args.released_by,
        )

    if args.apply:
        with farmctl.FactoryMutationLock(
            farmctl.path_for_factory_flag(farmctl.factory_off_flag_path(ROOT)),
            owner="release_e1c_optionb_rows",
        ):
            conn = sqlite3.connect(str(DB), timeout=60)
            conn.row_factory = sqlite3.Row
            try:
                for wid in targets:
                    entry = {"work_item_id": wid}
                    try:
                        conn.execute("BEGIN IMMEDIATE")
                        detail = release_one(conn, wid)
                        conn.commit()
                        entry.update({"released": True, "record_sha256": detail["record_sha256"]})
                    except Exception as exc:  # noqa: BLE001
                        conn.rollback()
                        entry.update({"released": False, "error": f"{type(exc).__name__}: {exc}"})
                    print(json.dumps(entry, default=str)[:300], flush=True)
                    receipt["rows"].append(entry)
            finally:
                conn.close()
    else:
        conn = sqlite3.connect(DB.resolve().as_uri() + "?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        try:
            for wid in targets:
                entry = {"work_item_id": wid, "released": False, "dry_run": True}
                hold = conn.execute(
                    "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=? AND active=1",
                    (wid,),
                ).fetchone()
                item = conn.execute(
                    "SELECT phase,status,payload_json FROM work_items WHERE id=?", (wid,),
                ).fetchone()
                record_path = EVIDENCE / "rows" / f"{wid}.json"
                record_raw = record_path.read_bytes()
                record = json.loads(record_raw.decode("utf-8-sig"))
                entry["checks"] = {
                    "record_sha256_match": record.get("record_sha256") == taint._record_digest(record),
                    "record_status": record.get("delta_validation_status"),
                    "hold_active_taint": bool(hold) and hold["hold_code"] == taint.HOLD,
                    "row_pending_news": bool(item) and item["phase"] in taint.PHASES and item["status"] == "pending",
                    "marker_absent": taint.E1C_MARKER_KEY not in (json.loads(item["payload_json"] or "{}") if item else {}),
                }
                entry["would_release"] = all(entry["checks"].values())
                print(json.dumps(entry, default=str)[:300], flush=True)
                receipt["rows"].append(entry)
        finally:
            conn.close()

    receipt["released_count"] = sum(1 for r in receipt["rows"] if r.get("released"))
    out = EVIDENCE / f"release_receipt_{dt.datetime.now(dt.timezone.utc):%Y%m%dT%H%M%SZ}.json"
    out.write_text(json.dumps(receipt, indent=1, default=str) + "\n", encoding="utf-8")
    print("receipt", out.name)
    print("released", receipt["released_count"], "/", len(targets))
    return 0 if receipt["released_count"] == len(targets) or not args.apply else 1


if __name__ == "__main__":
    raise SystemExit(main())
