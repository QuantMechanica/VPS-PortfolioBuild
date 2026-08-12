"""Read-only fail-closed guard for public snapshot publication.

The public exporter must not publish tracked state while either automatic Q02
bypass incident is active.  This module never creates or migrates the runtime
database; callers receive a machine-readable refusal on every read/schema error.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
BLOCKING_HOLD_CODES = (
    "FACTORY_OFF_AUTO_Q02_BYPASS",
    "STALE_BUILD_RESULT_AUTO_Q02_BYPASS",
)
SCHEMA_VERSION = "qm-public-snapshot-incident-guard/v1"


def inspect_public_snapshot_incident_holds(database: Path) -> dict[str, Any]:
    """Inspect the hold table in SQLite read-only mode and fail closed."""
    database = Path(database)
    base: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "database": str(database),
        "valid": False,
        "publication_allowed": False,
        "active_incident_hold_count": 0,
        "active_incident_holds": [],
        "error_code": None,
        "error": None,
    }
    conn: sqlite3.Connection | None = None
    try:
        uri = database.resolve().as_uri() + "?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA query_only=ON")
        columns = {
            str(row["name"])
            for row in conn.execute("PRAGMA table_info(work_item_holds)").fetchall()
        }
        required = {"work_item_id", "hold_code", "active"}
        if not required.issubset(columns):
            missing = sorted(required - columns)
            raise RuntimeError(f"work_item_holds schema missing columns: {missing!r}")
        placeholders = ",".join("?" for _ in BLOCKING_HOLD_CODES)
        rows = conn.execute(
            "SELECT work_item_id, hold_code, active FROM work_item_holds "
            f"WHERE hold_code IN ({placeholders}) "
            "ORDER BY hold_code, work_item_id",
            BLOCKING_HOLD_CODES,
        ).fetchall()
        holds: list[dict[str, str]] = []
        for row in rows:
            work_item_id = str(row["work_item_id"] or "").strip()
            hold_code = str(row["hold_code"] or "").strip()
            if (
                not work_item_id
                or hold_code not in BLOCKING_HOLD_CODES
                or type(row["active"]) is not int
                or row["active"] not in (0, 1)
            ):
                raise RuntimeError("incident-hold row failed strict validation")
            if row["active"] == 1:
                holds.append({"work_item_id": work_item_id, "hold_code": hold_code})
        return {
            **base,
            "valid": True,
            "publication_allowed": not holds,
            "active_incident_hold_count": len(holds),
            "active_incident_holds": holds,
        }
    except Exception as exc:
        return {
            **base,
            "error_code": "incident_hold_read_failed",
            "error": repr(exc),
        }
    finally:
        if conn is not None:
            conn.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Refuse public snapshot publication during active Q02 bypass incidents"
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = inspect_public_snapshot_incident_holds(args.db)
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    if not result["valid"]:
        return 2
    return 0 if result["publication_allowed"] else 3


if __name__ == "__main__":
    sys.exit(main())
