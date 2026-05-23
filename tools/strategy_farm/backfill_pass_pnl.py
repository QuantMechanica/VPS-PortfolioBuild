"""Hydrate PASS work_items with PnL stats from their summary.json evidence.

This is a one-time, idempotent backfill for historical PASS rows that predate
farmctl persisting `payload_json.recovered_stats`.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

try:
    from farmctl import _summary_recovered_stats
except ModuleNotFoundError:
    from tools.strategy_farm.farmctl import _summary_recovered_stats


DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _connect() -> sqlite3.Connection:
    con = sqlite3.connect(str(DB))
    con.row_factory = sqlite3.Row
    return con


def _load_payload(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def _load_summary(path_text: str | None) -> tuple[dict | None, str | None]:
    if not path_text:
        return None, "missing evidence_path"
    path = Path(path_text)
    if path.name.lower() != "summary.json":
        return None, "evidence_path is not summary.json"
    if not path.exists():
        return None, "summary.json missing"
    try:
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, f"summary.json unreadable: {exc}"
    if not isinstance(summary, dict):
        return None, "summary.json root is not an object"
    return summary, None


def backfill(dry_run: bool = False, limit: int | None = None) -> dict:
    con = _connect()
    sql = """
        SELECT id, ea_id, symbol, phase, payload_json, evidence_path
        FROM work_items
        WHERE verdict='PASS'
          AND (
            payload_json NOT LIKE '%recovered_stats%'
            OR payload_json LIKE '%"recovered_stats": null%'
          )
        ORDER BY updated_at ASC
    """
    params: tuple = ()
    if limit is not None:
        sql += " LIMIT ?"
        params = (limit,)

    out = {
        "checked": 0,
        "updated": 0,
        "skipped_existing": 0,
        "skipped_no_stats": 0,
        "skipped_unreadable": 0,
        "dry_run": dry_run,
        "examples": [],
    }
    rows = list(con.execute(sql, params))
    for row in rows:
        out["checked"] += 1
        payload = _load_payload(row["payload_json"])
        if payload.get("recovered_stats"):
            out["skipped_existing"] += 1
            continue

        summary, error = _load_summary(row["evidence_path"])
        if summary is None:
            out["skipped_unreadable"] += 1
            if len(out["examples"]) < 10:
                out["examples"].append({
                    "work_item": row["id"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "status": error,
                })
            continue

        stats = _summary_recovered_stats(summary)
        if "net_profit" not in stats:
            out["skipped_no_stats"] += 1
            if len(out["examples"]) < 10:
                out["examples"].append({
                    "work_item": row["id"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "status": "no net_profit in summary",
                })
            continue

        payload["recovered_stats"] = stats
        if len(out["examples"]) < 10:
            out["examples"].append({
                "work_item": row["id"],
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "phase": row["phase"],
                "stats": stats,
            })
        if not dry_run:
            con.execute(
                "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=?",
                (json.dumps(payload, sort_keys=True), _utc_now(), row["id"]),
            )
        out["updated"] += 1

    if not dry_run:
        con.commit()
    con.close()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()
    result = backfill(dry_run=args.dry_run, limit=args.limit)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
