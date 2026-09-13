#!/usr/bin/env python3
"""Enumerate every pending work item whose bound artifact no longer matches disk.

This command is deliberately read-only.  It mirrors the dispatch preflight hashes,
reports every active hold, and assigns a conservative per-row disposition.  It does
not rebind or supersede work items; those actions remain on their governed paths.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
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


# --- EA-directory resolution (mirrors the dispatch runner) --------------------
# terminal_worker._dispatch_ex5_requirement resolves the immutable EX5 by ea_id,
# NOT by the set file's location: farmctl._ea_dir_from_setfile_path (set file
# anchored under <ea_dir>/sets) then farmctl._preferred_ea_dir (ea_id glob +
# registry disambiguation). OPT_CENSUS PRESCREEN/WINSWEEP cells keep their set
# files under D:\...\opt_census\<program>\setfiles\, so the old
# setfile.parent.parent derivation invented a nonexistent framework/EAs/<program>
# executable and reported byte-exact bindings as MISSING. These helpers mirror
# the runner so the census resolves the same file the runner runs, rooted at
# ``eas`` for testability.


def _ea_dir_version(dir_name: str) -> int:
    match = re.search(r"_v(\d+)(?:$|_)", dir_name)
    return int(match.group(1)) if match else 1


def _ea_dir_slug(ea_id: str, dir_name: str) -> str:
    prefix = f"{ea_id}_"
    return dir_name[len(prefix):] if dir_name.startswith(prefix) else dir_name


def _active_registered_slugs(ea_id: str, eas: Path) -> set[str]:
    """Registered, non-retired ea_slugs for ea_id (mirrors farmctl)."""
    m = re.search(r"QM5_(\d+)", str(ea_id))
    if not m:
        return set()
    num = m.group(1)
    out: set[str] = set()
    try:
        text = (eas.parent / "registry" / "magic_numbers.csv").read_text(encoding="utf-8-sig")
    except OSError:
        return out
    for record in csv.DictReader(io.StringIO(text)):
        if str(record.get("ea_id") or "").strip() != num:
            continue
        if str(record.get("status") or "active").strip().lower() == "retired":
            continue
        slug = str(record.get("ea_slug") or "").strip()
        if slug:
            out.add(slug)
    return out


def _preferred_ea_dir(ea_id: str, eas: Path) -> Path | None:
    """Mirror farmctl._preferred_ea_dir, rooted at ``eas``."""
    if not ea_id:
        return None
    candidates = sorted(p for p in eas.glob(f"{ea_id}_*") if p.is_dir())
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    active = _active_registered_slugs(ea_id, eas)
    registered = [p for p in candidates if _ea_dir_slug(ea_id, p.name) in active]
    pool = registered or candidates
    best = max(_ea_dir_version(p.name) for p in pool)
    top = [p for p in pool if _ea_dir_version(p.name) == best]
    return top[0] if len(top) == 1 else None


def _ea_dir_from_setfile_path(setfile: Path, ea_id: str) -> Path | None:
    """Mirror farmctl._ea_dir_from_setfile_path (set file under <ea_dir>/sets)."""
    if not ea_id or setfile.parent.name.lower() != "sets":
        return None
    ea_dir = setfile.parent.parent
    if not ea_dir.is_dir() or not ea_dir.name.startswith(f"{ea_id}_"):
        return None
    return ea_dir


def _is_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (ValueError, OSError):
        return False


def _resolve_ea_dir(
    setfile: Path, ea_id: str, payload: dict[str, Any], eas: Path
) -> tuple[Path, str]:
    """Resolve the EA directory for ex5/mq5 the way the dispatch runner does.

    Order: explicit payload ``ea_dir_name`` -> set-file-anchored (runner) ->
    ea_id registry glob (runner) -> set-file-relative grandparent, and the last
    only when the set file lives under framework/EAs. Returns the directory and
    the derivation label recorded on each mismatch for auditability.
    """
    name = str(payload.get("ea_dir_name") or "").strip()
    if name:
        return eas / name, "ea_id_resolution"
    anchored = _ea_dir_from_setfile_path(setfile, ea_id)
    if anchored is not None:
        return anchored, "ea_id_resolution"
    preferred = _preferred_ea_dir(ea_id, eas)
    if preferred is not None:
        return preferred, "ea_id_resolution"
    if _is_under(setfile, eas):
        return eas / setfile.parent.parent.name, "setfile_relative"
    # Unresolvable by ea_id and the set file is outside framework/EAs: anchor a
    # non-existent ea_id path so the row reports MISSING (the runner would raise
    # staged_ex5_ea_dir_unresolved) without inventing a set-file-relative EA dir.
    return eas / (ea_id or "UNRESOLVED_EA"), "ea_id_resolution"


def resolve_artifact_paths(
    row: sqlite3.Row, payload: dict[str, Any], eas: Path
) -> dict[str, tuple[Path, str]]:
    """Resolve (path, derivation) for ex5/mq5/setfile as the dispatch runner would.

    ex5/mq5 honour an explicit ``expected_<role>_path`` first, then resolve by
    ea_id (payload hint or registry/glob), then a set-file-relative fallback that
    applies only inside framework/EAs. The set file itself is the work-item path.
    """
    setfile = Path(str(row["setfile_path"])).resolve()
    ea_id = str(row["ea_id"] or "").strip()
    ea_dir, ea_dir_derivation = _resolve_ea_dir(setfile, ea_id, payload, eas)

    def _binary(role: str) -> tuple[Path, str]:
        explicit = str(payload.get(f"expected_{role}_path") or "").strip()
        if explicit:
            return Path(explicit).resolve(), "expected_path"
        return ea_dir / f"{ea_dir.name}.{role}", ea_dir_derivation

    return {
        "ex5": _binary("ex5"),
        "mq5": _binary("mq5"),
        "setfile": (setfile, "work_item_setfile"),
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
        paths = resolve_artifact_paths(row, payload, eas)
        findings: list[dict[str, Any]] = []
        for role, (path, derivation) in paths.items():
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
                    "derivation": derivation,
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
