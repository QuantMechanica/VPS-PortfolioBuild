#!/usr/bin/env python3
"""Enumerate every pending work item whose bound artifact no longer matches disk.

This command is deliberately read-only.  It mirrors the dispatch preflight hashes,
reports every active hold, and assigns a conservative per-row disposition.  It does
not rebind or supersede work items; those actions remain on their governed paths.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Sequence


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_EAS = Path(r"C:\QM\repo\framework\EAs")


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _newline_hashes(data: bytes) -> set[str]:
    lf = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    crlf = lf.replace(b"\n", b"\r\n")
    return {_sha256(value) for value in (data, lf, crlf)}


def _artifact_paths(row: sqlite3.Row, payload: dict[str, Any], eas: Path) -> dict[str, Path]:
    setfile = Path(str(row["setfile_path"])).resolve()
    ea_dir_name = str(payload.get("ea_dir_name") or setfile.parent.parent.name).strip()
    ea_dir = eas / ea_dir_name
    return {
        "ex5": ea_dir / f"{ea_dir_name}.ex5",
        "mq5": ea_dir / f"{ea_dir_name}.mq5",
        "setfile": setfile,
    }


def _classification(role: str, expected: str, path: Path) -> tuple[str | None, str | None]:
    try:
        data = path.read_bytes()
    except OSError:
        return "MISSING", None
    actual = _sha256(data)
    if actual == expected:
        return None, actual
    if role in {"mq5", "setfile"} and expected in _newline_hashes(data):
        return "LINE_ENDINGS_ONLY", actual
    return "CONTENT_CHANGED", actual


def _disposition(findings: list[dict[str, Any]]) -> str:
    roles = {str(item["role"]) for item in findings}
    classes = {str(item["classification"]) for item in findings}
    if "MISSING" in classes:
        return "WAIT_GOVERNED_ARTIFACT_RESTORE_OR_RECOMPILE"
    if roles & {"ex5", "mq5"}:
        return "GOVERNED_BUILD_SUCCESSOR_REQUIRED"
    if roles == {"setfile"} and classes <= {"LINE_ENDINGS_ONLY"}:
        return "NORMALIZED_BYTE_REBIND_ELIGIBLE"
    if roles == {"setfile"}:
        return "GOVERNED_APPEND_ONLY_SETFILE_SUCCESSOR_REQUIRED"
    return "PER_EA_REVIEW_REQUIRED"


def build_census(db: Path = DEFAULT_DB, eas: Path = DEFAULT_EAS) -> dict[str, Any]:
    conn = sqlite3.connect(f"{db.as_uri()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    try:
        rows = conn.execute(
            """
            SELECT w.id,w.ea_id,w.symbol,w.phase,w.status,w.setfile_path,
                   w.payload_json,w.created_at,w.updated_at,w.claimed_by,
                   h.hold_code,h.reason AS hold_reason,h.release_on_restart
            FROM work_items w
            LEFT JOIN work_item_holds h
              ON h.work_item_id=w.id AND h.active=1
            WHERE w.status='pending' AND json_valid(w.payload_json)=1
              AND (
                json_extract(w.payload_json,'$.expected_ex5_sha256') IS NOT NULL OR
                json_extract(w.payload_json,'$.expected_mq5_sha256') IS NOT NULL OR
                json_extract(w.payload_json,'$.expected_setfile_sha256') IS NOT NULL
              )
            ORDER BY w.created_at,w.id
            """
        ).fetchall()
    finally:
        conn.close()

    drifted: list[dict[str, Any]] = []
    for row in rows:
        payload = json.loads(row["payload_json"] or "{}")
        paths = _artifact_paths(row, payload, eas)
        findings: list[dict[str, Any]] = []
        for role, path in paths.items():
            key = f"expected_{role}_sha256"
            expected = str(payload.get(key) or "").strip().lower()
            if not re.fullmatch(r"[0-9a-f]{64}", expected):
                continue
            classification, actual = _classification(role, expected, path)
            if classification is None:
                continue
            findings.append(
                {
                    "role": role,
                    "classification": classification,
                    "path": str(path),
                    "expected_sha256": expected,
                    "actual_sha256": actual,
                }
            )
        if not findings:
            continue
        drifted.append(
            {
                "id": str(row["id"]),
                "ea_id": str(row["ea_id"]),
                "symbol": str(row["symbol"]),
                "phase": str(row["phase"]),
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
                "claimed_by": row["claimed_by"],
                "hold": (
                    {
                        "hold_code": row["hold_code"],
                        "reason": row["hold_reason"],
                        "release_on_restart": bool(row["release_on_restart"]),
                    }
                    if row["hold_code"]
                    else None
                ),
                "findings": findings,
                "disposition": _disposition(findings),
            }
        )

    class_counts: dict[str, int] = {}
    disposition_counts: dict[str, int] = {}
    for row in drifted:
        disposition_counts[row["disposition"]] = disposition_counts.get(row["disposition"], 0) + 1
        for finding in row["findings"]:
            key = str(finding["classification"])
            class_counts[key] = class_counts.get(key, 0) + 1
    return {
        "schema": "qm.pending-artifact-binding-census.v1",
        "database": str(db),
        "bound_pending_rows_checked": len(rows),
        "drifted_rows": len(drifted),
        "mismatched_bindings": sum(len(row["findings"]) for row in drifted),
        "class_counts": dict(sorted(class_counts.items())),
        "disposition_counts": dict(sorted(disposition_counts.items())),
        "rows": drifted,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--eas", type=Path, default=DEFAULT_EAS)
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = build_census(args.db, args.eas)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 1 if result["drifted_rows"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
