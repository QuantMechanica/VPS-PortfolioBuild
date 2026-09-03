#!/usr/bin/env python3
"""Plan, apply or list the governed DL-089 program queue order.

``dl089_matrix_service._queue_order`` ranks pending Q12 pattern rows by
``(payload.queue_order_at or created_at, id)`` ascending and the service takes
the first ``dl089_scheduling.program_slots()`` candidates as program-slot
owners; everything behind that cut is deferred with ``PROGRAM_SLOT_WAIT:K=<k>``.
This tool is the operator-facing path for OWNER-bound reordering of that queue
(OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903, §2 — see
``docs/ops/evidence/2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md``).

It is deliberately narrow:

* only ``payload_json.queue_order_at`` is written; every other payload key is
  carried through unchanged (``json.dumps(..., sort_keys=True)``);
* ``work_items.status``/``verdict``/``claimed_by``/``updated_at`` and
  ``work_item_holds`` are never touched — the measured cells of a demoted
  program stay and resume when a slot frees;
* every target is an exact ``WORK_ITEM_ID=SYMBOL`` pair, revalidated inside the
  write transaction against ``status='pending'``, ``verdict IS NULL``,
  ``claimed_by IS NULL``, ``phase='Q12'`` and the DL-089 pattern predicate;
* apply mode takes a SQLite backup (path + sha256 recorded in every event),
  acquires ``BEGIN IMMEDIATE``, updates each row with a compare-and-set on its
  exact previous ``payload_json`` bytes, writes one ``dl089_queue_order_set``
  event carrying the previous value, revalidates, and only then commits.

Ordering caveat (the ``--front`` trap): ``_queue_order`` sorts *ascending*, so a
timestamp of "now" ranks a row **behind** every row that keeps its (past)
``created_at``. ``--front`` therefore defaults to now only because the operator
contract names that default; the directional guard below refuses the write when
the projected rank does not actually improve. Use an explicit
``--queue-order-at`` earlier than the current head to really front a row.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
from collections import Counter
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    from tools.strategy_farm import dl089_matrix_service as matrix_service
    from tools.strategy_farm.sqlite_busy import retry_sqlite_busy
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import dl089_matrix_service as matrix_service  # type: ignore
    from sqlite_busy import retry_sqlite_busy  # type: ignore


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
OUTPUT_SCHEMA = "qm.dl089-queue-order/v1"
EVENT_NAME = "dl089_queue_order_set"
GOVERNED_PHASE = "Q12"
# Far future: lexicographic string compare in _queue_order puts "2099-..."
# behind every real created_at, without inventing a fake past timestamp.
DEFER_QUEUE_ORDER_AT = "2099-01-01T00:00:00+00:00"
OWNER_DECISION_RE = re.compile(r"^[A-Z][A-Z0-9_-]{5,127}$")


class QueueOrderError(RuntimeError):
    """Fail-closed queue-order planning or application error."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_targets(values: Sequence[str]) -> list[tuple[str, str]]:
    targets: list[tuple[str, str]] = []
    seen: set[str] = set()
    for value in values:
        work_item_id, separator, symbol = value.partition("=")
        work_item_id, symbol = work_item_id.strip(), symbol.strip()
        if not separator or not work_item_id or not symbol:
            raise QueueOrderError(f"invalid_target:{value!r}:expected WORK_ITEM_ID=SYMBOL")
        if work_item_id in seen:
            raise QueueOrderError(f"duplicate_target:{work_item_id}")
        targets.append((work_item_id, symbol))
        seen.add(work_item_id)
    if not targets:
        raise QueueOrderError("no_targets")
    return targets


def normalize_queue_order_at(value: str) -> str:
    """Accept only an explicit, timezone-aware ISO 8601 instant, verbatim."""

    text = str(value).strip()
    if not text:
        raise QueueOrderError("invalid_queue_order_at:empty")
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError as exc:
        raise QueueOrderError(f"invalid_queue_order_at:{text!r}:{exc}") from exc
    if parsed.tzinfo is None:
        raise QueueOrderError(f"invalid_queue_order_at:{text!r}:missing_timezone")
    return text


def ensure_schema(conn: sqlite3.Connection) -> None:
    required = {
        "work_items": {
            "id", "ea_id", "symbol", "phase", "status", "verdict", "claimed_by",
            "created_at", "payload_json",
        },
        "events": {"ts", "entity_type", "entity_id", "event", "detail_json"},
    }
    for table, columns in required.items():
        actual = {str(row[1]) for row in conn.execute(f"PRAGMA table_info({table})")}
        missing = sorted(columns - actual)
        if missing:
            raise QueueOrderError(f"schema_missing:{table}:{','.join(missing)}")


def _payload(row: Mapping[str, Any]) -> dict[str, Any]:
    raw = str(row["payload_json"] or "{}")
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise QueueOrderError(f"payload_invalid:{row['id']}") from exc
    if not isinstance(value, dict):
        raise QueueOrderError(f"payload_not_object:{row['id']}")
    return value


def _program_id(payload: Mapping[str, Any]) -> str | None:
    sweep = payload.get("pattern_filter_sweep")
    if isinstance(sweep, Mapping):
        program = sweep.get("program_id")
        if program is not None:
            return str(program)
    return None


def _cell_counts(conn: sqlite3.Connection) -> dict[str, Counter[str]]:
    """Count OPT_CENSUS cells per owning Q12 row (read-only, best effort)."""

    counts: dict[str, Counter[str]] = {}
    try:
        rows = conn.execute(
            "SELECT id,status,payload_json FROM work_items WHERE upper(phase)=?",
            (matrix_service.census.PHASE,),
        ).fetchall()
    except sqlite3.Error:  # pragma: no cover - defensive on partial schemas
        return counts
    for row in rows:
        try:
            payload = json.loads(str(row["payload_json"] or "{}"))
        except json.JSONDecodeError:
            continue
        if not isinstance(payload, dict):
            continue
        if payload.get("schema") != matrix_service.census.SCHEMA:
            continue
        q12_id = str(payload.get("q12_work_item_id") or "")
        if not q12_id:
            continue
        counts.setdefault(q12_id, Counter())[str(row["status"]).lower()] += 1
    return counts


def governed_queue(
    conn: sqlite3.Connection,
    *,
    exclude_ids: Iterable[str] = (),
    overrides: Mapping[str, str] | None = None,
) -> list[dict[str, Any]]:
    """Return the governed pattern rows in ``_queue_order`` order.

    ``overrides`` maps work-item id to a projected ``queue_order_at`` and is how
    plan mode shows the order the service *would* take after the write.
    """

    excluded = {str(value) for value in exclude_ids}
    projected = dict(overrides or {})
    rows = conn.execute(
        """
        SELECT id,ea_id,symbol,phase,status,verdict,claimed_by,created_at,payload_json
        FROM work_items
        WHERE upper(phase)=? AND lower(status)='pending'
          AND verdict IS NULL AND claimed_by IS NULL
        ORDER BY created_at,id
        """,
        (GOVERNED_PHASE,),
    ).fetchall()
    entries: list[dict[str, Any]] = []
    for row in rows:
        record = dict(row)
        work_item_id = str(record["id"])
        if work_item_id in excluded:
            continue
        try:
            payload = _payload(record)
        except QueueOrderError:
            continue
        if not matrix_service._is_dl089_pattern(record, payload):
            continue
        if work_item_id in projected:
            payload = {**payload, "queue_order_at": projected[work_item_id]}
        sort_key = matrix_service._queue_order(record, payload)
        entries.append(
            {
                "work_item_id": work_item_id,
                "ea_id": str(record["ea_id"]),
                "symbol": str(record["symbol"]),
                "program_id": _program_id(payload),
                "created_at": str(record["created_at"]),
                "queue_order_at": payload.get("queue_order_at"),
                "sort_key": sort_key[0],
                "sort_key_source": (
                    "queue_order_at" if payload.get("queue_order_at") else "created_at"
                ),
                "_sort": sort_key,
            }
        )
    entries.sort(key=lambda item: item["_sort"])
    slots = matrix_service.program_slots()
    for rank, entry in enumerate(entries, start=1):
        entry.pop("_sort")
        entry["rank"] = rank
        entry["slot"] = rank if rank <= slots else None
        entry["machine_reason"] = None if rank <= slots else f"PROGRAM_SLOT_WAIT:K={slots}"
    return entries


def _rank_index(order: Sequence[Mapping[str, Any]]) -> dict[str, int]:
    return {str(entry["work_item_id"]): int(entry["rank"]) for entry in order}


def inspect_targets(
    conn: sqlite3.Connection,
    targets: Sequence[tuple[str, str]],
    *,
    ea_ids: Sequence[str],
    queue_order_at: str,
) -> list[dict[str, Any]]:
    """Revalidate every exact target; raise on the first mismatch."""

    expected_ea_ids = {str(value) for value in ea_ids}
    observed_ea_ids: set[str] = set()
    result: list[dict[str, Any]] = []
    for work_item_id, symbol in targets:
        row = conn.execute(
            "SELECT id,ea_id,symbol,phase,status,verdict,claimed_by,created_at,payload_json "
            "FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if row is None:
            raise QueueOrderError(f"work_item_missing:{work_item_id}")
        actual = dict(row)
        expected = {
            "symbol": symbol,
            "status": "pending",
            "verdict": None,
            "claimed_by": None,
        }
        mismatches = [
            f"{key}=expected:{expected_value!r}:actual:{actual.get(key)!r}"
            for key, expected_value in expected.items()
            if actual.get(key) != expected_value
        ]
        if str(actual.get("phase") or "").upper() != GOVERNED_PHASE:
            mismatches.append(f"phase=expected:{GOVERNED_PHASE!r}:actual:{actual.get('phase')!r}")
        if mismatches:
            raise QueueOrderError(
                f"work_item_precondition:{work_item_id}:" + ";".join(mismatches)
            )
        payload = _payload(actual)
        if not matrix_service._is_dl089_pattern(actual, payload):
            raise QueueOrderError(
                f"not_a_governed_dl089_pattern_row:{work_item_id}:"
                f"role={payload.get('role')!r};"
                f"routing_revision={payload.get('routing_revision')!r}"
            )
        observed_ea_ids.add(str(actual["ea_id"]))
        previous = payload.get("queue_order_at")
        result.append(
            {
                "work_item_id": work_item_id,
                "ea_id": str(actual["ea_id"]),
                "symbol": str(actual["symbol"]),
                "program_id": _program_id(payload),
                "created_at": str(actual["created_at"]),
                "previous_queue_order_at": previous,
                "previous_sort_key": str(previous or actual["created_at"]),
                "queue_order_at": queue_order_at,
                "already_set": previous == queue_order_at,
                "payload_json": str(actual["payload_json"] or "{}"),
                "payload": payload,
            }
        )
    if observed_ea_ids != expected_ea_ids:
        raise QueueOrderError(
            "ea_id_precondition:expected:"
            f"{sorted(expected_ea_ids)}:actual:{sorted(observed_ea_ids)}"
        )
    return result


def _direction_guard(
    direction: str,
    rows: Sequence[Mapping[str, Any]],
    before: Mapping[str, int],
    after: Mapping[str, int],
    *,
    allow_no_reorder: bool,
) -> None:
    if direction == "explicit" or allow_no_reorder:
        return
    for row in rows:
        work_item_id = str(row["work_item_id"])
        rank_before = before.get(work_item_id)
        rank_after = after.get(work_item_id)
        if rank_before is None or rank_after is None:
            raise QueueOrderError(f"rank_unavailable:{work_item_id}")
        if direction == "defer" and rank_after < rank_before:
            raise QueueOrderError(
                f"defer_does_not_demote:{work_item_id}:"
                f"rank_before={rank_before}:rank_after={rank_after}"
            )
        advanced = rank_after < rank_before or (rank_before == 1 and rank_after == 1)
        if direction == "front" and not advanced:
            raise QueueOrderError(
                f"front_does_not_advance:{work_item_id}:"
                f"rank_before={rank_before}:rank_after={rank_after}:"
                "queue_order_at sorts ascending; pass an explicit "
                "--queue-order-at earlier than the queue head or "
                "--allow-no-reorder"
            )


def _projection(
    conn: sqlite3.Connection,
    rows: Sequence[Mapping[str, Any]],
    queue_order_at: str,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    order_before = governed_queue(conn)
    overrides = {str(row["work_item_id"]): queue_order_at for row in rows}
    order_after = governed_queue(conn, overrides=overrides)
    return order_before, order_after


def _target_report(
    rows: Sequence[Mapping[str, Any]],
    before: Mapping[str, int],
    after: Mapping[str, int],
) -> list[dict[str, Any]]:
    report: list[dict[str, Any]] = []
    for row in rows:
        work_item_id = str(row["work_item_id"])
        report.append(
            {
                key: row[key]
                for key in (
                    "work_item_id", "ea_id", "symbol", "program_id", "created_at",
                    "previous_queue_order_at", "previous_sort_key", "queue_order_at",
                    "already_set",
                )
            }
            | {
                "rank_before": before.get(work_item_id),
                "rank_after": after.get(work_item_id),
            }
        )
    return report


def plan_queue_order(
    db: Path,
    targets: Sequence[tuple[str, str]],
    *,
    ea_ids: Sequence[str],
    queue_order_at: str,
    direction: str,
    reason: str,
    owner_decision: str,
    allow_no_reorder: bool = False,
) -> dict[str, Any]:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        ensure_schema(conn)
        rows = inspect_targets(
            conn, targets, ea_ids=ea_ids, queue_order_at=queue_order_at
        )
        order_before, order_after = _projection(conn, rows, queue_order_at)
    finally:
        conn.close()
    before, after = _rank_index(order_before), _rank_index(order_after)
    _direction_guard(direction, rows, before, after, allow_no_reorder=allow_no_reorder)
    return {
        "mode": "plan",
        "owner_decision": owner_decision,
        "reason": reason,
        "direction": direction,
        "queue_order_at": queue_order_at,
        "program_slots": matrix_service.program_slots(),
        "targets": _target_report(rows, before, after),
        "would_update": sum(1 for row in rows if not row["already_set"]),
        "already_set": sum(1 for row in rows if row["already_set"]),
        "order_before": order_before,
        "order_after": order_after,
    }


def sqlite_backup(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / f"farm_state_before_dl089_queue_order_{stamp}.sqlite"
    if destination.exists():
        raise QueueOrderError(f"backup_exists:{destination}")
    source = sqlite3.connect(db, timeout=30)
    target = sqlite3.connect(destination)
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def apply_queue_order(
    db: Path,
    backup_dir: Path,
    targets: Sequence[tuple[str, str]],
    *,
    ea_ids: Sequence[str],
    queue_order_at: str,
    direction: str,
    reason: str,
    owner_decision: str,
    allow_no_reorder: bool = False,
) -> dict[str, Any]:
    backup_path, backup_sha = sqlite_backup(db, backup_dir)

    def _apply_once() -> dict[str, Any]:
        now = utc_now()
        conn = sqlite3.connect(db, timeout=0.75)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA busy_timeout=750")
        updated = 0
        already_set = 0
        try:
            ensure_schema(conn)
            conn.execute("BEGIN IMMEDIATE")
            rows = inspect_targets(
                conn, targets, ea_ids=ea_ids, queue_order_at=queue_order_at
            )
            order_before, order_after = _projection(conn, rows, queue_order_at)
            before, after = _rank_index(order_before), _rank_index(order_after)
            _direction_guard(
                direction, rows, before, after, allow_no_reorder=allow_no_reorder
            )
            for row in rows:
                if row["already_set"]:
                    already_set += 1
                    continue
                payload = dict(row["payload"])
                payload["queue_order_at"] = queue_order_at
                rendered = json.dumps(payload, sort_keys=True)
                changed = conn.execute(
                    """
                    UPDATE work_items SET payload_json=?
                    WHERE id=? AND payload_json=? AND upper(phase)=?
                      AND lower(status)='pending' AND verdict IS NULL
                      AND claimed_by IS NULL
                    """,
                    (rendered, row["work_item_id"], row["payload_json"], GOVERNED_PHASE),
                ).rowcount
                if changed != 1:
                    raise QueueOrderError(
                        f"compare_and_set_lost:{row['work_item_id']}:rowcount={changed}"
                    )
                detail = {
                    "owner_decision": owner_decision,
                    "reason": reason,
                    "direction": direction,
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "phase": GOVERNED_PHASE,
                    "program_id": row["program_id"],
                    "created_at": row["created_at"],
                    "previous_queue_order_at": row["previous_queue_order_at"],
                    "previous_sort_key": row["previous_sort_key"],
                    "queue_order_at": queue_order_at,
                    "rank_before": before.get(row["work_item_id"]),
                    "rank_after": after.get(row["work_item_id"]),
                    "program_slots": matrix_service.program_slots(),
                    "backup_path": str(backup_path),
                    "backup_sha256": backup_sha,
                }
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES(?,'work_item',?,?,?)",
                    (
                        now,
                        row["work_item_id"],
                        EVENT_NAME,
                        json.dumps(detail, sort_keys=True),
                    ),
                )
                updated += 1
            verify = inspect_targets(
                conn, targets, ea_ids=ea_ids, queue_order_at=queue_order_at
            )
            if any(not item["already_set"] for item in verify):
                raise QueueOrderError("pre_commit_queue_order_not_set")
            for original, current in zip(rows, verify):
                lhs = {k: v for k, v in original["payload"].items() if k != "queue_order_at"}
                rhs = {k: v for k, v in current["payload"].items() if k != "queue_order_at"}
                if json.dumps(lhs, sort_keys=True) != json.dumps(rhs, sort_keys=True):
                    raise QueueOrderError(
                        f"pre_commit_payload_key_drift:{original['work_item_id']}"
                    )
            final_order = governed_queue(conn)
            conn.commit()
            return {
                "mode": "apply",
                "owner_decision": owner_decision,
                "reason": reason,
                "direction": direction,
                "queue_order_at": queue_order_at,
                "program_slots": matrix_service.program_slots(),
                "updated": updated,
                "already_set": already_set,
                "backup": {"path": str(backup_path), "sha256": backup_sha},
                "targets": _target_report(rows, before, after),
                "order_before": order_before,
                "order_after": final_order,
                "work_item_columns_touched": ["payload_json"],
            }
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    # One durable pre-mutation backup, then reopen the whole transaction after
    # each SQLITE_BUSY burst (short-timeout doctrine, XCU 2026-08-16).
    return retry_sqlite_busy(_apply_once, attempts=40)


def list_queue_order(db: Path, *, exclude_ids: Sequence[str] = ()) -> dict[str, Any]:
    """Read-only view of the current governed order (no writes, no locks)."""

    uri = f"{Path(db).resolve().as_uri()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        ensure_schema(conn)
        order = governed_queue(conn, exclude_ids=exclude_ids)
        counts = _cell_counts(conn)
    finally:
        conn.close()
    for entry in order:
        cells = counts.get(entry["work_item_id"], Counter())
        entry["cells_exist"] = bool(cells)
        entry["cells_by_status"] = dict(sorted(cells.items()))
        entry["cells_pending"] = int(cells.get("pending", 0))
        entry["cells_active"] = int(cells.get("active", 0))
        entry["cells_done"] = int(cells.get("done", 0))
    slots = matrix_service.program_slots()
    return {
        "mode": "list",
        "db": str(db),
        "program_slots": slots,
        "governed_rows": len(order),
        "slot_owners": [entry for entry in order if entry["slot"] is not None],
        "waiting": [entry for entry in order if entry["slot"] is None],
        "excluded_ids": sorted({str(value) for value in exclude_ids}),
        "rank_basis": (
            "queue_order_over_pending_governed_Q12_pattern_rows; the service "
            "additionally drops rows whose measurement Q02 sibling is not "
            "done/PASS, so a listed rank is an upper bound on the served slot"
        ),
    }


def resolve_queue_order_at(args: argparse.Namespace) -> tuple[str, str]:
    chosen = [name for name in ("front", "defer") if getattr(args, name)]
    if args.queue_order_at is not None:
        if len(chosen) > 1:
            raise QueueOrderError("conflicting_direction:--front and --defer")
        return normalize_queue_order_at(args.queue_order_at), (chosen[0] if chosen else "explicit")
    if len(chosen) != 1:
        raise QueueOrderError(
            "missing_direction:pass exactly one of --front, --defer or --queue-order-at"
        )
    if chosen[0] == "defer":
        return DEFER_QUEUE_ORDER_AT, "defer"
    return utc_now(), "front"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "apply", "list"))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument(
        "--target", action="append", default=[],
        help="WORK_ITEM_ID=SYMBOL; repeat per row (plan/apply)",
    )
    parser.add_argument(
        "--ea-id", action="append", default=[],
        help="expected EA id; repeat. The set must match the targets exactly.",
    )
    parser.add_argument("--queue-order-at", help="explicit tz-aware ISO 8601 instant")
    parser.add_argument("--front", action="store_true", help="default now (see docstring)")
    parser.add_argument(
        "--defer", action="store_true", help=f"use {DEFER_QUEUE_ORDER_AT}"
    )
    parser.add_argument("--reason", help="operator reason recorded in the event")
    parser.add_argument("--owner-decision", help="OWNER decision id recorded in the event")
    parser.add_argument(
        "--allow-no-reorder", action="store_true",
        help="bypass the directional rank guard (records the direction anyway)",
    )
    parser.add_argument(
        "--exclude-id", action="append", default=[],
        help="list mode: drop a known non-candidate id from the projection",
    )
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "list":
            result = list_queue_order(args.db, exclude_ids=args.exclude_id)
        else:
            if not args.reason:
                raise QueueOrderError("missing_reason")
            if not args.owner_decision or not OWNER_DECISION_RE.fullmatch(args.owner_decision):
                raise QueueOrderError(f"invalid_owner_decision:{args.owner_decision!r}")
            if not args.ea_id:
                raise QueueOrderError("missing_ea_id")
            targets = parse_targets(args.target)
            queue_order_at, direction = resolve_queue_order_at(args)
            common = {
                "ea_ids": args.ea_id,
                "queue_order_at": queue_order_at,
                "direction": direction,
                "reason": args.reason,
                "owner_decision": args.owner_decision,
                "allow_no_reorder": args.allow_no_reorder,
            }
            if args.command == "plan":
                result = plan_queue_order(args.db, targets, **common)
            else:
                result = apply_queue_order(args.db, args.backup_dir, targets, **common)
        result.update(schema=OUTPUT_SCHEMA, status="ok")
        exit_code = 0
    except (QueueOrderError, sqlite3.Error, OSError) as exc:
        result = {"schema": OUTPUT_SCHEMA, "status": "aborted", "reason": str(exc)}
        exit_code = 2
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    print(rendered, end="")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
