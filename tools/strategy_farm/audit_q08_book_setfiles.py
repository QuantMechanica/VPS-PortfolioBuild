"""Read-only audit of Q08 work-item setfiles against a book manifest.

The generic research cascade is allowed to advance grid/ablation variants.
Book requalification is different: its exact baseline is declared by each
manifest sleeve's ``backtest_set``.  This tool compares those two namespaces
without mutating the farm database.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
VARIANT_TOKENS = ("_ablation_", "_grid_", "_synth_", "_freq_")
OPEN_STATES = {"pending", "active"}


def _sha256(path: Path) -> str | None:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def _path_key(value: str | os.PathLike[str]) -> str:
    return os.path.normcase(os.path.normpath(str(value)))


def _ea_id(value: Any) -> str:
    token = str(value or "").strip()
    if token.startswith("QM5_"):
        return token
    return f"QM5_{int(token)}"


def load_manifest(path: Path) -> tuple[dict[tuple[str, str], dict[str, Any]], str]:
    raw = path.read_bytes()
    data = json.loads(raw.decode("utf-8-sig"))
    sleeves = data.get("sleeves")
    if not isinstance(sleeves, list) or not sleeves:
        raise ValueError("manifest must contain a non-empty sleeves list")

    expected: dict[tuple[str, str], dict[str, Any]] = {}
    for sleeve in sleeves:
        if not isinstance(sleeve, dict):
            raise ValueError("manifest sleeve must be an object")
        ea_id = _ea_id(sleeve.get("ea_id"))
        symbol = str(sleeve.get("symbol") or "").strip()
        setfile = str(sleeve.get("backtest_set") or "").strip()
        if not symbol or not setfile:
            raise ValueError(f"manifest sleeve missing symbol/backtest_set: {ea_id}")
        key = (ea_id.casefold(), symbol.casefold())
        if key in expected:
            raise ValueError(f"duplicate manifest sleeve: {ea_id}/{symbol}")
        expected[key] = {
            "ea_id": ea_id,
            "symbol": symbol,
            "expected_setfile": setfile,
            "expected_setfile_sha256": _sha256(Path(setfile)),
        }
    return expected, hashlib.sha256(raw).hexdigest()


def _connect_read_only(db_path: Path) -> sqlite3.Connection:
    uri = f"file:{db_path.resolve().as_posix()}?mode=ro"
    con = sqlite3.connect(uri, uri=True)
    con.row_factory = sqlite3.Row
    return con


def audit(db_path: Path, manifest_path: Path) -> dict[str, Any]:
    expected, manifest_sha = load_manifest(manifest_path)
    with _connect_read_only(db_path) as con:
        db_rows = con.execute(
            """
            SELECT id, ea_id, symbol, setfile_path, status, verdict,
                   created_at, updated_at
            FROM work_items
            WHERE phase='Q08'
            """
        ).fetchall()

    rows: list[dict[str, Any]] = []
    covered: set[tuple[str, str]] = set()
    for db_row in db_rows:
        key = (
            str(db_row["ea_id"] or "").casefold(),
            str(db_row["symbol"] or "").casefold(),
        )
        sleeve = expected.get(key)
        if sleeve is None:
            continue
        covered.add(key)
        actual = str(db_row["setfile_path"] or "")
        expected_path = str(sleeve["expected_setfile"])
        actual_sha = _sha256(Path(actual))
        if _path_key(actual) == _path_key(expected_path):
            classification = "EXACT"
        elif (
            actual_sha is not None
            and actual_sha == sleeve["expected_setfile_sha256"]
            and Path(actual).name.casefold() == Path(expected_path).name.casefold()
        ):
            classification = "CONTENT_ALIAS"
        elif any(token in actual.casefold() for token in VARIANT_TOKENS):
            classification = "VARIANT_MISMATCH"
        else:
            classification = "PATH_MISMATCH"
        status = str(db_row["status"] or "").lower()
        rows.append({
            "id": db_row["id"],
            "ea_id": sleeve["ea_id"],
            "symbol": sleeve["symbol"],
            "status": status,
            "verdict": db_row["verdict"],
            "created_at": db_row["created_at"],
            "updated_at": db_row["updated_at"],
            "actual_setfile": actual,
            "actual_setfile_sha256": actual_sha,
            "expected_setfile": expected_path,
            "expected_setfile_sha256": sleeve["expected_setfile_sha256"],
            "classification": classification,
            "open_mismatch": status in OPEN_STATES and classification not in {
                "EXACT", "CONTENT_ALIAS"
            },
        })

    rows.sort(key=lambda row: (
        row["ea_id"], row["symbol"], str(row["updated_at"] or ""), row["id"]
    ))
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["classification"]] = counts.get(row["classification"], 0) + 1
    open_mismatches = [row for row in rows if row["open_mismatch"]]
    return {
        "schema": "qm.q08_book_setfile_audit.v1",
        "generated_at_utc": datetime.now(UTC).isoformat(),
        "database": str(db_path.resolve()),
        "manifest": str(manifest_path.resolve()),
        "manifest_sha256": manifest_sha,
        "manifest_sleeves": len(expected),
        "covered_sleeves": len(covered),
        "q08_rows": len(rows),
        "classification_counts": counts,
        "open_mismatch_count": len(open_mismatches),
        "open_mismatches": open_mismatches,
        "rows": rows,
    }


def render_csv(result: dict[str, Any]) -> str:
    fields = [
        "id", "ea_id", "symbol", "status", "verdict", "created_at", "updated_at",
        "classification", "open_mismatch", "actual_setfile", "actual_setfile_sha256",
        "expected_setfile", "expected_setfile_sha256",
    ]
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=fields, extrasaction="ignore")
    writer.writeheader()
    writer.writerows(result["rows"])
    return buffer.getvalue()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--csv", action="store_true", help="emit row-level CSV instead of JSON")
    parser.add_argument(
        "--summary-only", action="store_true", help="omit the full rows array from JSON output"
    )
    parser.add_argument(
        "--fail-on-open-mismatch", action="store_true",
        help="return 2 when a pending/active row disagrees with the manifest",
    )
    args = parser.parse_args(argv)
    result = audit(args.db, args.manifest)
    if args.csv:
        print(render_csv(result), end="")
    else:
        if args.summary_only:
            result = {key: value for key, value in result.items() if key != "rows"}
        print(json.dumps(result, indent=2, sort_keys=True))
    return 2 if args.fail_on_open_mismatch and result["open_mismatch_count"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
