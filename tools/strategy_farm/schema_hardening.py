"""Farm-DB schema hardening SH-1, SH-2, and the SH-3 successor.

Authority: ``docs/ops/FARM_DB_SCHEMA_HARDENING_2026-08-23.md`` (OWNER-commissioned
2026-08-23).

**SH-1 — materialize the taxonomy.** ``work_items_clean`` (MNT-016) derives the public
status and taxonomy at *read* time. Measured 2026-08-23: 9,381 rows whose STORED status
contradicts their verdict and 50,883 rows with no stored taxonomy at all. A consumer that
does not install the TEMP view reads different numbers — two surfaces can query the same
database, disagree, and both be "right". This adds two stored columns, backfills them, and
keeps the view as an independent **validator**.

**SH-3 — reference integrity.** Not what the commission assumed. Measured, the declared
foreign keys do not describe how the columns are used:

* ``work_items.parent_task_id`` declares ``REFERENCES tasks(id)`` but is **polymorphic** —
  of 71 dangling values, 39 point at ``work_items`` (parent/child lineage), 14 at
  ``agent_tasks``, 18 at nothing;
* ``tasks.source_id`` declares ``REFERENCES sources(id)`` but holds **EA ids** such as
  ``QM5_12108``.

Switching ``PRAGMA foreign_keys=ON`` would therefore fail-closed the factory on the next
write of either shape — orphans are still being created (latest 2026-08-14). So SH-3 ships
as a **monitor** here, and the schema correction (typed columns, or dropping the misleading
declarations) needs its own OFF window.

Usage::

    python tools/strategy_farm/schema_hardening.py check          # read-only, both parts
    python tools/strategy_farm/schema_hardening.py migrate --db X # SH-1 on a copy first
    python tools/strategy_farm/schema_hardening.py migrate --apply
    python tools/strategy_farm/schema_hardening.py migrate-sh2 --dry-run --db COPY
    python tools/strategy_farm/schema_hardening.py migrate-sh3 --dry-run --db COPY
    python tools/strategy_farm/schema_hardening.py --validate-sh3 --db COPY
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
import time
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from work_item_clean_view import clean_status, verdict_taxonomy  # noqa: E402
from artifact_identity import IDENTITY_COLUMNS, SHA256_COLUMNS  # noqa: E402

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
STORED_TAXONOMY = "verdict_taxonomy_stored"
STORED_STATUS = "clean_status_stored"
CHUNK = 5000
SH3_TAXONOMIES = (
    "draft_defect", "governance", "infra", "invalid", "measurement",
    "open", "review", "strategy", "unknown", "artifact", "build",
    "implementation",
)
SH3_MATERIALIZE_INSERT_TRIGGER = "trg_work_items_sh3_materialize_insert"
SH3_MATERIALIZE_UPDATE_TRIGGER = "trg_work_items_sh3_materialize_update"


def _columns(con: sqlite3.Connection, table: str) -> set[str]:
    return {r[1] for r in con.execute(f"PRAGMA table_info({table})")}


def open_ro(path: str | Path) -> sqlite3.Connection:
    norm = str(Path(path)).replace("\\", "/")
    con = sqlite3.connect(f"file:{norm}?mode=ro", uri=True, timeout=10)
    con.execute("PRAGMA busy_timeout=3000")
    return con


def add_columns(con: sqlite3.Connection) -> list[str]:
    """Idempotent, additive, metadata-only. No existing column is touched."""
    have = _columns(con, "work_items")
    added = []
    for col in (STORED_TAXONOMY, STORED_STATUS):
        if col not in have:
            con.execute(f"ALTER TABLE work_items ADD COLUMN {col} TEXT")
            added.append(col)
    return added


def backfill(con: sqlite3.Connection, limit: int | None = None) -> dict:
    """Fill the stored columns from the same functions the view uses.

    Chunked so a live factory never waits on one long write lock. A row whose stored value
    already differs from the derived one is **reported, not silently rewritten** — that is
    a finding, not a formatting problem.
    """
    con.execute("PRAGMA busy_timeout=8000")
    rows = con.execute(
        f"SELECT id, status, verdict, {STORED_TAXONOMY}, {STORED_STATUS} FROM work_items"
    ).fetchall()
    todo, drift = [], []
    for wid, status, verdict, tax_stored, status_stored in rows:
        tax = verdict_taxonomy(status, verdict)
        st = clean_status(status, verdict)
        if tax_stored is None or status_stored is None:
            todo.append((tax, st, wid))
        elif tax_stored != tax or status_stored != st:
            drift.append({"id": wid, "stored": [tax_stored, status_stored],
                          "derived": [tax, st]})
    if limit:
        todo = todo[:limit]
    written = 0
    for i in range(0, len(todo), CHUNK):
        batch = todo[i:i + CHUNK]
        con.execute("BEGIN IMMEDIATE")
        con.executemany(
            f"UPDATE work_items SET {STORED_TAXONOMY}=?, {STORED_STATUS}=? WHERE id=?", batch)
        con.commit()
        written += len(batch)
        time.sleep(0.02)          # leave the write lock to the factory between chunks
    return {"rows": len(rows), "written": written, "drift": len(drift),
            "drift_sample": drift[:5]}


def validate(con: sqlite3.Connection) -> dict:
    """Stored vs derived. Any mismatch is a defect, not a rounding difference."""
    have = _columns(con, "work_items")
    if STORED_TAXONOMY not in have:
        return {"migrated": False}
    mism = Counter()
    missing = 0
    total = 0
    for status, verdict, tax_stored, status_stored in con.execute(
        f"SELECT status, verdict, {STORED_TAXONOMY}, {STORED_STATUS} FROM work_items"
    ):
        total += 1
        if tax_stored is None or status_stored is None:
            missing += 1
            continue
        if tax_stored != verdict_taxonomy(status, verdict):
            mism["taxonomy"] += 1
        if status_stored != clean_status(status, verdict):
            mism["status"] += 1
    return {"migrated": True, "rows": total, "unfilled": missing,
            "mismatch": dict(mism), "valid": not mism and missing == 0}


# ── SH-3 · reference integrity monitor ────────────────────────────────────────

def reference_integrity(con: sqlite3.Connection) -> dict:
    """Classify dangling references instead of enforcing a wrong contract."""
    con.row_factory = None
    viol = con.execute("PRAGMA foreign_key_check").fetchall()
    by_table = Counter((r[0], r[2]) for r in viol)

    wi_rowids = [r[1] for r in viol if r[0] == "work_items"]
    kinds = Counter()
    if wi_rowids:
        q = ",".join("?" * len(wi_rowids))
        for (pid,) in con.execute(
                f"SELECT parent_task_id FROM work_items WHERE rowid IN ({q})", wi_rowids):
            if con.execute("SELECT 1 FROM work_items WHERE id=?", (pid,)).fetchone():
                kinds["points_at_work_items"] += 1
            elif con.execute("SELECT 1 FROM agent_tasks WHERE id=?", (pid,)).fetchone():
                kinds["points_at_agent_tasks"] += 1
            else:
                kinds["points_at_nothing"] += 1

    task_rowids = [r[1] for r in viol if r[0] == "tasks"]
    ea_shaped = 0
    if task_rowids:
        q = ",".join("?" * len(task_rowids))
        for (sid,) in con.execute(
                f"SELECT source_id FROM tasks WHERE rowid IN ({q})", task_rowids):
            if isinstance(sid, str) and sid.startswith("QM5_"):
                ea_shaped += 1

    return {
        "violations": len(viol),
        "by_table": {f"{a}->{b}": n for (a, b), n in by_table.items()},
        "work_items_parent_task_id_is_polymorphic": dict(kinds),
        "tasks_source_id_holding_ea_ids": ea_shaped,
        "enforcement_on": bool(con.execute("PRAGMA foreign_keys").fetchone()[0]),
        "safe_to_enforce": False,
        "why": ("parent_task_id is used polymorphically (work_items | agent_tasks | none) "
                "and tasks.source_id holds EA ids, not source ids. Enforcing the declared "
                "keys would fail-closed the next write of either shape; orphans are still "
                "being created (latest 2026-08-14). Fix the declarations first."),
    }


# ── SH-2 · typed artifact identity ───────────────────────────────────────────

def identity_coverage(con: sqlite3.Connection) -> dict:
    have = _columns(con, "work_items")
    total = int(con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0])
    if "ex5_sha256" not in have:
        payload = int(con.execute(
            "SELECT COUNT(*) FROM work_items WHERE json_valid(payload_json) "
            "AND COALESCE(json_extract(payload_json,'$.expected_ex5_sha256'),"
            "json_extract(payload_json,'$.ex5_sha256'),"
            "json_extract(payload_json,'$.build_hash')) IS NOT NULL"
        ).fetchone()[0])
        return {
            "migrated": False, "rows": total, "rows_with_ex5_identity": payload,
            "coverage_pct": round(100.0 * payload / total, 3) if total else 0.0,
            "source": "payload_fallback",
        }
    with_ex5 = int(con.execute(
        "SELECT COUNT(*) FROM work_items WHERE ex5_sha256 IS NOT NULL AND trim(ex5_sha256)<>''"
    ).fetchone()[0])
    complete = int(con.execute(
        "SELECT COUNT(*) FROM work_items WHERE ex5_sha256 IS NOT NULL "
        "AND setfile_sha256 IS NOT NULL AND data_window_start IS NOT NULL "
        "AND data_window_end IS NOT NULL"
    ).fetchone()[0])
    return {
        "migrated": True, "rows": total, "rows_with_ex5_identity": with_ex5,
        "rows_with_core_identity": complete,
        "coverage_pct": round(100.0 * with_ex5 / total, 3) if total else 0.0,
        "core_coverage_pct": round(100.0 * complete / total, 3) if total else 0.0,
        "source": "typed_columns",
    }


def migrate_sh2(con: sqlite3.Connection) -> dict:
    # Import lazily: read-only validators do not need to load the controller.
    try:
        import farmctl
    except ModuleNotFoundError:
        from tools.strategy_farm import farmctl
    result = farmctl.ensure_work_item_artifact_identity_schema(con)
    result["coverage"] = identity_coverage(con)
    return result


# ── SH-3 successor · enforced new writes, untouched historical contradictions ─

def _row_digest(con: sqlite3.Connection, columns: list[str]) -> str:
    digest = hashlib.sha256()
    select = ",".join('"' + col.replace('"', '""') + '"' for col in columns)
    for row in con.execute(f"SELECT {select} FROM work_items ORDER BY rowid"):
        encoded = json.dumps(
            [[type(value).__name__, value] for value in row],
            ensure_ascii=False, separators=(",", ":"), default=str,
        ).encode("utf-8")
        digest.update(len(encoded).to_bytes(8, "big"))
        digest.update(encoded)
    return digest.hexdigest()


def validate_sh3(con: sqlite3.Connection) -> dict:
    """List historical status contradictions without changing a single row."""
    contradictions = []
    for wid, phase, status, verdict in con.execute(
        "SELECT id,phase,status,verdict FROM work_items ORDER BY id"
    ):
        derived = clean_status(status, verdict)
        if derived != status:
            contradictions.append({
                "id": wid, "phase": phase, "status": status,
                "verdict": verdict, "derived_status": derived,
            })
    have = _columns(con, "work_items")
    return {
        "migrated": "sh3_enforced" in have and "verdict_taxonomy" in have,
        "historical_status_contradiction_count": len(contradictions),
        "historical_status_contradictions": contradictions,
        "historical_rows_mutated": 0,
    }


def _quoted(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def _work_items_column_definitions(con: sqlite3.Connection) -> tuple[list[str], list[str]]:
    info = con.execute("PRAGMA table_info(work_items)").fetchall()
    old_columns = [str(row[1]) for row in info]
    definitions = []
    for _cid, name, declared_type, notnull, default, pk in info:
        parts = [_quoted(str(name)), str(declared_type or "TEXT")]
        if int(notnull):
            parts.append("NOT NULL")
        if default is not None:
            parts.extend(("DEFAULT", str(default)))
        if int(pk):
            parts.append("PRIMARY KEY")
        definitions.append(" ".join(parts))
    if "verdict_taxonomy" not in old_columns:
        definitions.append("verdict_taxonomy TEXT")
    if "sh3_enforced" not in old_columns:
        definitions.append("sh3_enforced INTEGER NOT NULL DEFAULT 1")
    return old_columns, definitions


def _sh3_checks() -> list[str]:
    tax = "COALESCE(NULLIF(verdict_taxonomy,''),NULLIF(json_extract(payload_json,'$.verdict_taxonomy'),''))"
    allowed = ",".join(repr(value) for value in SH3_TAXONOMIES)
    checks = [
        "CHECK (status IN ('pending','active','done','failed'))",
        "CHECK (sh3_enforced IN (0,1))",
        "CHECK (sh3_enforced=0 OR (typeof(phase)='text' AND trim(phase)<>''))",
        "CHECK (sh3_enforced=0 OR verdict IS NULL OR (typeof(verdict)='text' AND trim(verdict)<>''))",
        "CHECK (sh3_enforced=0 OR status<>'done' OR verdict IS NOT NULL)",
        f"CHECK (sh3_enforced=0 OR status<>'failed' OR ({tax}) IS NOT NULL)",
        f"CHECK (sh3_enforced=0 OR ({tax}) IS NULL OR ({tax}) IN ({allowed}))",
        "CHECK (sh3_enforced=0 OR status NOT IN ('pending','active') OR verdict IS NULL)",
    ]
    for column in SHA256_COLUMNS:
        checks.append(
            f"CHECK (sh3_enforced=0 OR {column} IS NULL OR "
            f"(typeof({column})='text' AND length({column})=64 AND {column}=lower({column}) "
            f"AND {column} NOT GLOB '*[^0-9a-f]*'))"
        )
    for column in ("build_id", "data_window_start", "data_window_end"):
        checks.append(
            f"CHECK (sh3_enforced=0 OR {column} IS NULL OR "
            f"(typeof({column})='text' AND trim({column})<>''))"
        )
    return checks


def _sh3_trigger_sql(name: str, event: str) -> str:
    identity_sets = []
    for column in IDENTITY_COLUMNS:
        payload_key = {
            "ex5_sha256": "expected_ex5_sha256",
            "setfile_sha256": "expected_setfile_sha256",
            "mq5_sha256": "expected_mq5_sha256",
            "data_window_start": "expected_from_date",
            "data_window_end": "expected_to_date",
            "news_calendar_sha256": "qm_news_calendar_expected_sha256",
        }.get(column, column)
        identity_sets.append(
            f"{column}=COALESCE({column},json_extract(payload_json,'$.{payload_key}'))"
        )
    assignments = ",".join(identity_sets)
    required_missing = (
        "ex5_sha256 IS NULL OR setfile_sha256 IS NULL OR "
        "data_window_start IS NULL OR data_window_end IS NULL"
    )
    return f"""
    CREATE TRIGGER {name}
    AFTER {event} ON work_items
    WHEN NEW.sh3_enforced=1
    BEGIN
      UPDATE work_items SET
        verdict_taxonomy=COALESCE(verdict_taxonomy,json_extract(payload_json,'$.verdict_taxonomy')),
        {assignments}
      WHERE id=NEW.id;
      UPDATE work_items SET
        status='failed',verdict='INFRA_FAIL',verdict_taxonomy='infra',
        payload_json=json_set(payload_json,'$.verdict_taxonomy','infra',
          '$.verdict_reason','ARTIFACT_IDENTITY_MISSING')
      WHERE id=NEW.id AND status IN ('done','failed')
        AND verdict_taxonomy='strategy' AND ({required_missing});
    END
    """


def _backup_database(con: sqlite3.Connection, backup_path: Path) -> None:
    backup_path = backup_path.resolve()
    if backup_path.exists():
        raise FileExistsError(f"refusing to overwrite backup: {backup_path}")
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    target = sqlite3.connect(str(backup_path))
    try:
        con.backup(target)
        target.commit()
    finally:
        target.close()


def migrate_sh3(con: sqlite3.Connection, backup_path: Path) -> dict:
    """Rebuild ``work_items`` and exempt only copied historical rows from checks."""
    migrate_sh2(con)
    con.commit()
    old_columns, definitions = _work_items_column_definitions(con)
    before_count = int(con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0])
    before_digest = _row_digest(con, old_columns)
    _backup_database(con, backup_path)
    schema_objects: list[tuple[str, str, str]] = []
    seen_objects: set[tuple[str, str]] = set()
    for obj_type, name, sql in con.execute(
        "SELECT type,name,sql FROM sqlite_master WHERE sql IS NOT NULL AND ("
        "(type='index' AND tbl_name='work_items') OR "
        "(type IN ('trigger','view') AND lower(sql) LIKE '%work_items%')) "
        "ORDER BY CASE type WHEN 'index' THEN 0 WHEN 'view' THEN 1 ELSE 2 END,name"
    ):
        key = (str(obj_type), str(name))
        if key not in seen_objects:
            schema_objects.append((str(obj_type), str(name), str(sql)))
            seen_objects.add(key)
    foreign_keys = []
    for _id, _seq, table, from_col, to_col, on_update, on_delete, match in con.execute(
        "PRAGMA foreign_key_list(work_items)"
    ):
        foreign_keys.append(
            f"FOREIGN KEY({_quoted(from_col)}) REFERENCES {_quoted(table)}({_quoted(to_col)}) "
            f"ON UPDATE {on_update} ON DELETE {on_delete} MATCH {match}"
        )
    ddl = ",\n".join(definitions + foreign_keys + _sh3_checks())
    old_select = ",".join(_quoted(column) for column in old_columns)
    target_columns = list(old_columns)
    values = list(old_columns)
    if "verdict_taxonomy" not in old_columns:
        target_columns.append("verdict_taxonomy")
        values.append("verdict_taxonomy_stored" if "verdict_taxonomy_stored" in old_columns else "NULL")
    if "sh3_enforced" not in old_columns:
        target_columns.append("sh3_enforced")
        values.append("0")
    target_sql = ",".join(_quoted(column) for column in target_columns)
    values_sql = ",".join(_quoted(value) if value in old_columns else value for value in values)
    con.execute("PRAGMA foreign_keys=OFF")
    con.execute("BEGIN IMMEDIATE")
    try:
        # SQLite validates all dependent schema text during ALTER TABLE. Remove
        # dependent views/triggers only inside this transaction and reinstall their
        # exact SQL after the swap; rollback restores them automatically on failure.
        for obj_type, name, _sql in reversed(schema_objects):
            if obj_type in {"trigger", "view"}:
                con.execute(f"DROP {obj_type.upper()} {_quoted(name)}")
        con.execute(f"CREATE TABLE work_items_sh3_new ({ddl})")
        con.execute(
            f"INSERT INTO work_items_sh3_new ({target_sql}) SELECT {values_sql} FROM work_items"
        )
        con.execute("DROP TABLE work_items")
        con.execute("ALTER TABLE work_items_sh3_new RENAME TO work_items")
        for obj_type, _name, sql in schema_objects:
            if SH3_MATERIALIZE_INSERT_TRIGGER in sql or SH3_MATERIALIZE_UPDATE_TRIGGER in sql:
                continue
            con.execute(sql)
        for column in IDENTITY_COLUMNS:
            con.execute(
                f"CREATE INDEX IF NOT EXISTS idx_work_items_{column} ON work_items({column})"
            )
        con.execute(_sh3_trigger_sql(SH3_MATERIALIZE_INSERT_TRIGGER, "INSERT"))
        con.execute(_sh3_trigger_sql(
            SH3_MATERIALIZE_UPDATE_TRIGGER, "UPDATE OF status,verdict,payload_json"
        ))
        after_count = int(con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0])
        after_digest = _row_digest(con, old_columns)
        if after_count != before_count or after_digest != before_digest:
            raise RuntimeError("SH-3 rebuild did not preserve historical work_items")
        con.commit()
    except Exception:
        con.rollback()
        raise
    return {
        "backup": str(backup_path.resolve()),
        "before_count": before_count, "after_count": after_count,
        "before_digest": before_digest, "after_digest": after_digest,
        "historical_rows_enforced": 0, "new_row_default_enforced": 1,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Farm-DB schema hardening SH-1 / SH-3")
    ap.add_argument("command", nargs="?", choices=("check", "migrate", "migrate-sh2", "migrate-sh3"))
    ap.add_argument("--db", default=str(DB))
    ap.add_argument("--apply", action="store_true",
                    help="migrate: actually write (default is a plan-only run)")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the migration plan and coverage without writing")
    ap.add_argument("--backup", type=Path,
                    help="required backup destination for migrate-sh3 --apply")
    ap.add_argument("--validate-sh3", action="store_true",
                    help="read-only: enumerate historical status contradictions")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()
    out: dict = {"db": args.db, "at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
    if args.apply and args.dry_run:
        ap.error("--apply and --dry-run are mutually exclusive")
    if args.validate_sh3:
        con = open_ro(args.db)
        out["sh3"] = validate_sh3(con)
        con.close()
        print(json.dumps(out, indent=1))
        return 0
    if args.command is None:
        ap.error("a command or --validate-sh3 is required")

    write = bool(args.apply)
    con = sqlite3.connect(args.db) if write else open_ro(args.db)
    if args.command == "check":
        out["sh1"] = validate(con)
        out["sh2"] = identity_coverage(con)
        out["sh3"] = reference_integrity(con)
        out["sh3_successor"] = validate_sh3(con)
    elif args.command == "migrate":
        have = _columns(con, "work_items")
        out["already_migrated"] = STORED_TAXONOMY in have
        if not write:
            out["plan"] = "would add columns and backfill; re-run with --apply"
            out["sh1_before"] = validate(con)
        else:
            t0 = time.perf_counter()
            out["added_columns"] = add_columns(con)
            out["backfill"] = backfill(con, args.limit)
            out["seconds"] = round(time.perf_counter() - t0, 1)
            out["sh1_after"] = validate(con)
    elif args.command == "migrate-sh2":
        out["sh2_before"] = identity_coverage(con)
        if not write:
            missing = sorted(set(IDENTITY_COLUMNS) - _columns(con, "work_items"))
            out["dry_run"] = True
            out["plan"] = {"add_columns": missing, "create_indexes": list(IDENTITY_COLUMNS),
                           "backfill": "payload keys only; NULL targets only"}
        else:
            out["sh2_migration"] = migrate_sh2(con)
            con.commit()
            out["sh2_after"] = identity_coverage(con)
    else:
        out["sh3_before"] = validate_sh3(con)
        if not write:
            out["dry_run"] = True
            out["plan"] = {
                "backup": "sqlite backup API (required before rebuild)",
                "rebuild": "work_items with typed verdict_taxonomy and CHECK constraints",
                "historical_rows": "copied with sh3_enforced=0; no verdict/status rewrite",
                "new_rows": "sh3_enforced defaults to 1",
            }
        else:
            if args.backup is None:
                ap.error("migrate-sh3 --apply requires --backup")
            out["sh3_migration"] = migrate_sh3(con, args.backup)
            out["sh3_after"] = validate_sh3(con)
    con.close()
    print(json.dumps(out, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
