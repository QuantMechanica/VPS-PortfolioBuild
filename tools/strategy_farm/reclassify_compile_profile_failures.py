#!/usr/bin/env python3
"""Read-only dry run for append-only compile-profile failure reruns."""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
REASON = "COMPILE_PROFILE_STDLIB_MISSING"
_SIGNATURE = re.compile(
    r"error\s+106:\s+file\s+'(?:Include[\\/])?(?:Object\.mqh|Trade[\\/]Trade\.mqh)'\s+not\s+found",
    re.IGNORECASE,
)


def _read_text(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8-sig", errors="replace")


def _payload(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


def _compile_log(evidence_path: Any) -> Path | None:
    if not evidence_path:
        return None
    evidence = Path(str(evidence_path))
    try:
        document = json.loads(evidence.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    raw = document.get("compile_log") if isinstance(document, dict) else None
    return Path(str(raw)) if raw else None


def _matches_signature(log_path: Path | None) -> bool:
    if log_path is None or not log_path.is_file():
        return False
    try:
        return _SIGNATURE.search(_read_text(log_path)) is not None
    except OSError:
        return False


def _connect_ro(db_path: Path) -> sqlite3.Connection:
    uri = db_path.resolve().as_uri() + "?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def build_dry_run(db_path: Path = DEFAULT_DB) -> dict[str, Any]:
    """List only deduplicated rows with no later success/open successor."""
    db = Path(db_path)
    with _connect_ro(db) as conn:
        rows = conn.execute(
            "SELECT id,ea_id,status,verdict,evidence_path,payload_json,created_at,updated_at "
            "FROM work_items WHERE phase='COMPILE_EA' ORDER BY updated_at,id"
        ).fetchall()

    indexed: list[dict[str, Any]] = []
    for row in rows:
        payload = _payload(row["payload_json"])
        indexed.append({
            "row": row,
            "payload": payload,
            "source_hash": str(payload.get("mq5_sha256") or ""),
            "key": (str(row["ea_id"]), str(payload.get("mq5_sha256") or "")),
        })

    matched = []
    for item in indexed:
        row = item["row"]
        if row["status"] != "failed" or row["verdict"] != "COMPILE_FAIL":
            continue
        log_path = _compile_log(row["evidence_path"])
        if _matches_signature(log_path):
            item = dict(item)
            item["compile_log"] = log_path
            matched.append(item)

    latest_by_key: dict[tuple[str, str], dict[str, Any]] = {}
    for item in matched:
        latest_by_key[item["key"]] = item

    eligible_rows: list[dict[str, Any]] = []
    for item in latest_by_key.values():
        row = item["row"]
        blockers = []
        for other in indexed:
            other_row = other["row"]
            if other["key"] != item["key"] or other_row["updated_at"] <= row["updated_at"]:
                continue
            if other_row["status"] in {"pending", "active"}:
                blockers.append(str(other_row["id"]))
            elif other_row["status"] == "done" and other_row["verdict"] == "COMPILE_OK":
                blockers.append(str(other_row["id"]))
        if blockers:
            continue
        payload = item["payload"]
        eligible_rows.append({
            "work_item_id": str(row["id"]),
            "ea_id": str(row["ea_id"]),
            "ea_label": payload.get("ea_label"),
            "mq5_sha256": item["source_hash"] or None,
            "updated_at": str(row["updated_at"]),
            "evidence_path": str(row["evidence_path"]),
            "compile_log": str(item["compile_log"]),
            "reason": REASON,
            "eligible_action": "APPEND_ONLY_COMPILE_EA_RERUN",
        })

    eligible_rows.sort(key=lambda value: (value["updated_at"], value["work_item_id"]))
    return {
        "schema_version": "qm.compile-profile-failure-reclassify-dry-run/v1",
        "mode": "dry_run",
        "database": str(db.resolve()),
        "database_mode": "ro",
        "matched_signature_count": len(matched),
        "deduplicated_signature_count": len(latest_by_key),
        "eligible_count": len(eligible_rows),
        "eligible_rows": eligible_rows,
        "mutation_count": 0,
        "apply_supported": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="required; no apply mode exists")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    args = parser.parse_args(argv)
    if not args.dry_run:
        parser.error("--dry-run is required; this tool has no mutation mode")
    print(json.dumps(build_dry_run(args.db), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
