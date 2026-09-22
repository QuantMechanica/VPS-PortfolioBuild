"""Governed repair for unclaimed Q08 promotion metadata.

The tool never edits terminal rows, verdicts, or evidence.  It authenticates
pending promoted rows against their exact predecessor and governed compile
receipt, reseals the Q08 phase window, then performs a short compare-and-swap
under the factory mutation lock.  Dry-run is the default; apply requires one
durable journal path and creates a governed SQLite backup first.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    from tools.strategy_farm import farmctl
except ModuleNotFoundError:
    import farmctl


SCHEMA = "qm.q08-promotion-repair/v1"
JOURNAL_SCHEMA = "qm.q08-promotion-repair-journal/v1"
ACTION = "q08_promotion_metadata_repaired"
REFUSAL_SCHEMA = "qm.q08-promotion-binding-refusal/v1"
REFUSAL_HOLD_CODE = "Q08_PROMOTION_BINDING_REFUSED"
REFUSAL_HOLD_ACTION = "q08_promotion_binding_refusal_held"


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _payload(row: Mapping[str, Any]) -> dict[str, Any] | None:
    try:
        value = json.loads(str(row.get("payload_json") or "{}"))
    except (TypeError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def _canonical_payload(payload: Mapping[str, Any]) -> str:
    return json.dumps(dict(payload), sort_keys=True, separators=(",", ":"))


def _valid_sha(value: Any) -> str | None:
    token = str(value or "").strip().lower()
    return token if re.fullmatch(r"[0-9a-f]{64}", token) else None


def _identity_conflicts(
    row: Mapping[str, Any],
    old_payload: Mapping[str, Any],
    derived: Mapping[str, Any],
) -> dict[str, list[str]]:
    old_identity = old_payload.get("artifact_identity")
    if not isinstance(old_identity, Mapping):
        old_identity = {}
    checks = {
        "ex5_sha256": (
            row.get("ex5_sha256"), old_payload.get("expected_ex5_sha256"),
            old_payload.get("expected_current_ex5_sha256"),
            old_identity.get("ex5_sha256"),
        ),
        "setfile_sha256": (
            row.get("setfile_sha256"), old_payload.get("expected_setfile_sha256"),
            old_identity.get("setfile_sha256"),
        ),
        "mq5_sha256": (
            row.get("mq5_sha256"), old_payload.get("expected_mq5_sha256"),
            old_identity.get("mq5_sha256"),
        ),
        "include_closure_sha256": (
            row.get("include_closure_sha256"),
            old_payload.get("include_closure_sha256"),
            old_identity.get("include_closure_sha256"),
        ),
    }
    conflicts: dict[str, list[str]] = {}
    for key, values in checks.items():
        expected = _valid_sha(derived.get(key))
        present = sorted({token for value in values if (token := _valid_sha(value))})
        if expected is not None and present and present != [expected]:
            conflicts[key] = present
    return conflicts


def _summary_row(plan: Mapping[str, Any]) -> dict[str, Any]:
    return {
        key: plan.get(key)
        for key in (
            "work_item_id", "ea_id", "symbol", "predecessor_work_item_id",
            "reason", "before_payload_sha256", "after_payload_sha256",
            "before_window", "after_window", "before_identity", "after_identity",
            "dsr_context_status", "compile_work_item_id",
        )
        if plan.get(key) is not None
    }


def _refusal_plan(
    row: Mapping[str, Any],
    *,
    reason: str,
    predecessor_work_item_id: str | None = None,
    detail: Any = None,
) -> dict[str, Any]:
    before_raw = str(row.get("payload_json") or "{}")
    result = {
        "work_item_id": str(row["id"]),
        "ea_id": row.get("ea_id"),
        "symbol": row.get("symbol"),
        "predecessor_work_item_id": predecessor_work_item_id,
        "reason": reason,
        "detail": detail,
        "hold_code": REFUSAL_HOLD_CODE,
        "before_payload_raw": before_raw,
        "before_payload_sha256": _sha256_text(before_raw),
    }
    return result


def _summary_refusal(plan: Mapping[str, Any]) -> dict[str, Any]:
    return {
        key: plan.get(key)
        for key in (
            "work_item_id", "ea_id", "symbol", "predecessor_work_item_id",
            "reason", "detail", "conflicts", "hold_code",
            "before_payload_sha256",
        )
        if plan.get(key) is not None
    }


def _candidate_rows(
    conn: sqlite3.Connection,
    work_item_ids: Sequence[str] | None,
) -> list[sqlite3.Row]:
    args: list[Any] = []
    exact = ""
    if work_item_ids:
        placeholders = ",".join("?" for _ in work_item_ids)
        exact = f" AND w.id IN ({placeholders})"
        args.extend(str(value) for value in work_item_ids)
    return conn.execute(
        f"""
        SELECT w.* FROM work_items w
        WHERE upper(w.phase)='Q08' AND lower(w.status)='pending'
          AND w.verdict IS NULL AND w.claimed_by IS NULL
          AND json_valid(w.payload_json)
          AND json_extract(w.payload_json,'$.promoted_from_work_item') IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM work_item_supersedes s WHERE s.work_item_id=w.id
          )
          {exact}
        ORDER BY w.created_at,w.id
        """,
        args,
    ).fetchall()


def plan_repairs(
    conn: sqlite3.Connection,
    *,
    task_id: str,
    reason: str,
    journal_path: Path | None,
    work_item_ids: Sequence[str] | None = None,
    seal_dsr: bool = False,
) -> dict[str, Any]:
    eligible: list[dict[str, Any]] = []
    refused: list[dict[str, Any]] = []
    unchanged: list[dict[str, Any]] = []
    for raw in _candidate_rows(conn, work_item_ids):
        row = dict(raw)
        work_item_id = str(row["id"])
        old_payload = _payload(row)
        if old_payload is None:
            refused.append(_refusal_plan(row, reason="payload_invalid"))
            continue
        predecessor_id = str(old_payload.get("promoted_from_work_item") or "")
        predecessor_raw = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (predecessor_id,)
        ).fetchone()
        if predecessor_raw is None:
            refused.append(_refusal_plan(
                row,
                reason="predecessor_missing",
                predecessor_work_item_id=predecessor_id,
            ))
            continue
        predecessor = dict(predecessor_raw)
        new_payload = dict(old_payload)
        window_ok, window_detail = farmctl._carry_q08_candidate_window(
            predecessor, new_payload
        )
        if not window_ok:
            refused.append(_refusal_plan(
                row,
                reason="window_binding_refused",
                predecessor_work_item_id=predecessor_id,
                detail=window_detail,
            ))
            continue
        binding_ok, binding_detail = farmctl._q08_promotion_execution_binding(
            conn, predecessor, new_payload
        )
        if not binding_ok:
            refused.append(_refusal_plan(
                row,
                reason="identity_binding_refused",
                predecessor_work_item_id=predecessor_id,
                detail=binding_detail,
            ))
            continue
        typed = farmctl._q08_typed_identity_from_payload(new_payload)
        conflicts = _identity_conflicts(row, old_payload, typed)
        if conflicts:
            refusal = _refusal_plan(
                row,
                reason="existing_identity_conflicts_with_authenticated_binding",
                predecessor_work_item_id=predecessor_id,
            )
            refusal["conflicts"] = conflicts
            refused.append(refusal)
            continue
        new_payload["q08_promotion_repair"] = {
            "schema": SCHEMA,
            "task_id": task_id,
            "reason": reason,
            "journal_path": str(journal_path.resolve()) if journal_path else None,
            "terminal_row_edited": False,
            "verdict_edited": False,
            "evidence_edited": False,
        }
        if seal_dsr:
            candidate = dict(row)
            candidate.update(typed)
            status = farmctl._attach_q08_dsr_context(
                conn, candidate, new_payload
            )
        else:
            status = {
                "status": "PLANNED_RESEAL",
                "candidate_window_source": (
                    "payload.expected_from_date/expected_to_date"
                ),
            }
            new_payload.pop("dsr_context", None)
            new_payload["dsr_context_status"] = status

        before_raw = str(row["payload_json"] or "{}")
        after_raw = _canonical_payload(new_payload)
        before_typed = {
            key: row.get(key)
            for key in (
                "ex5_sha256", "setfile_sha256", "mq5_sha256",
                "include_closure_sha256", "build_id", "data_window_start",
                "data_window_end",
            )
        }
        after_typed = {key: typed.get(key) for key in before_typed}
        base = {
            "work_item_id": work_item_id,
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "predecessor_work_item_id": predecessor_id,
            "before_payload_raw": before_raw,
            "before_payload_sha256": _sha256_text(before_raw),
            "after_payload": new_payload,
            "after_payload_raw": after_raw,
            "after_payload_sha256": _sha256_text(after_raw),
            "before_window": {
                key: old_payload.get(key)
                for key in (
                    "from_date", "to_date", "from_year", "to_year",
                    "expected_from_date", "expected_to_date",
                )
            },
            "after_window": {
                key: new_payload.get(key)
                for key in (
                    "from_date", "to_date", "from_year", "to_year",
                    "expected_from_date", "expected_to_date",
                )
            },
            "before_identity": before_typed,
            "after_identity": after_typed,
            "typed_identity": typed,
            "dsr_context_status": status,
            "compile_work_item_id": (
                binding_detail.get("compile_record") or {}
            ).get("work_item_id"),
        }
        if before_raw == after_raw and before_typed == after_typed:
            unchanged.append(base)
        else:
            eligible.append(base)
    return {
        "schema": SCHEMA,
        "task_id": task_id,
        "dry_run": not seal_dsr,
        "candidate_count": len(eligible) + len(refused) + len(unchanged),
        "eligible_count": len(eligible),
        "refused_count": len(refused),
        "unchanged_count": len(unchanged),
        "eligible": eligible,
        "refused": refused,
        "unchanged": unchanged,
    }


def _public_plan(plan: Mapping[str, Any]) -> dict[str, Any]:
    return {
        key: value
        for key, value in plan.items()
        if key not in {"eligible", "refused", "unchanged"}
    } | {
        "eligible": [_summary_row(row) for row in plan.get("eligible", [])],
        "refused": [
            _summary_refusal(row) for row in plan.get("refused", [])
        ],
        "unchanged": [_summary_row(row) for row in plan.get("unchanged", [])],
    }


def _install_refusal_hold(
    conn: sqlite3.Connection,
    item: Mapping[str, Any],
    *,
    task_id: str,
    repair_reason: str,
    journal_path: Path,
    now: str,
) -> tuple[bool, dict[str, Any]]:
    """CAS-install one item-scoped hold without changing the queue row."""
    current = conn.execute(
        """
        SELECT id FROM work_items
        WHERE id=? AND lower(status)='pending' AND verdict IS NULL
          AND claimed_by IS NULL AND payload_json=?
          AND NOT EXISTS (
            SELECT 1 FROM work_item_supersedes s
            WHERE s.work_item_id=work_items.id
          )
        """,
        (item["work_item_id"], item["before_payload_raw"]),
    ).fetchone()
    if current is None:
        return False, {"reason": "compare_and_swap_missed"}
    refusal = {
        "schema": REFUSAL_SCHEMA,
        "task_id": task_id,
        "repair_reason": repair_reason,
        "refusal_reason": item["reason"],
        "detail": item.get("detail"),
        "conflicts": item.get("conflicts"),
        "journal_path": str(journal_path),
        "before_payload_sha256": item["before_payload_sha256"],
    }
    cursor = conn.execute(
        """
        INSERT INTO work_item_holds(
          work_item_id,hold_code,reason,active,release_on_restart,
          created_at,updated_at
        ) VALUES(?,?,?,1,0,?,?)
        ON CONFLICT(work_item_id) DO UPDATE SET
          hold_code=excluded.hold_code,reason=excluded.reason,active=1,
          release_on_restart=0,updated_at=excluded.updated_at,
          released_at=NULL,release_note=NULL
        WHERE work_item_holds.active=0
           OR work_item_holds.hold_code=excluded.hold_code
        """,
        (
            item["work_item_id"], REFUSAL_HOLD_CODE,
            json.dumps(refusal, sort_keys=True, separators=(",", ":")),
            now, now,
        ),
    )
    if cursor.rowcount != 1:
        existing = conn.execute(
            """
            SELECT hold_code,reason FROM work_item_holds
            WHERE work_item_id=? AND active=1
            """,
            (item["work_item_id"],),
        ).fetchone()
        return False, {
            "reason": "active_hold_conflict",
            "existing_hold_code": existing["hold_code"] if existing else None,
        }
    return True, refusal


def repair_pending_q08_promotions(
    root: Path,
    *,
    task_id: str,
    reason: str,
    apply: bool = False,
    journal_path: Path | None = None,
    work_item_ids: Sequence[str] | None = None,
) -> dict[str, Any]:
    task_id = str(task_id or "").strip()
    reason = str(reason or "").strip()
    if not task_id:
        return {"ok": False, "reason": "task_id_required"}
    if not reason:
        return {"ok": False, "reason": "reason_required", "task_id": task_id}
    journal = Path(journal_path).resolve() if journal_path else None
    if apply and journal is None:
        return {"ok": False, "reason": "journal_path_required_for_apply"}
    if apply and journal is not None and journal.exists():
        return {
            "ok": False,
            "reason": "journal_path_exists",
            "journal_path": str(journal),
        }

    if not apply:
        conn = sqlite3.connect(
            f"file:{farmctl.db_path(root).resolve().as_posix()}?mode=ro",
            uri=True,
        )
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA query_only=ON")
        try:
            plan = plan_repairs(
                conn,
                task_id=task_id,
                reason=reason,
                journal_path=journal,
                work_item_ids=work_item_ids,
                seal_dsr=False,
            )
        finally:
            conn.close()
        return {"ok": True, "applied": False, **_public_plan(plan)}

    farmctl.init_db(root)
    # Seal content-addressed DSR documents before taking the fleet-wide lock;
    # the transaction below still compare-and-swaps the exact payload bytes.
    with farmctl.connect(root) as conn:
        plan = plan_repairs(
            conn,
            task_id=task_id,
            reason=reason,
            journal_path=journal,
            work_item_ids=work_item_ids,
            seal_dsr=True,
        )
    if not plan["eligible"] and not plan["refused"]:
        return {"ok": True, "applied": False, **_public_plan(plan)}

    backup = farmctl._governed_state_backup_resolution(
        root, "q08_promotion_repair"
    )
    lock = farmctl.FactoryMutationLock(
        farmctl.path_for_factory_flag(farmctl.factory_off_flag_path(root)),
        owner=f"q08_promotion_repair:{task_id}",
    )
    try:
        lock.__enter__()
    except RuntimeError as exc:
        return {
            "ok": False,
            "applied": False,
            "reason": "factory_mutation_lock_busy",
            "detail": str(exc),
            "backup": backup,
            **_public_plan(plan),
        }

    journal_written = False
    applied_rows: list[dict[str, Any]] = []
    held_rows: list[dict[str, Any]] = []
    raced_rows: list[dict[str, Any]] = []
    now = farmctl.utc_now()
    conn: sqlite3.Connection | None = None
    try:
        conn = farmctl.connect_short_under_mutation_lock(root)
        conn.execute("BEGIN IMMEDIATE")
        for item in plan["eligible"]:
            typed = item["typed_identity"]
            cursor = conn.execute(
                """
                UPDATE work_items
                SET payload_json=?,updated_at=?,ex5_sha256=?,setfile_sha256=?,
                    mq5_sha256=?,include_closure_sha256=?,build_id=?,
                    data_window_start=?,data_window_end=?,verdict_taxonomy='open',
                    sh3_enforced=1
                WHERE id=? AND lower(status)='pending' AND verdict IS NULL
                  AND claimed_by IS NULL AND payload_json=?
                  AND NOT EXISTS (
                    SELECT 1 FROM work_item_supersedes s
                    WHERE s.work_item_id=work_items.id
                  )
                """,
                (
                    item["after_payload_raw"], now,
                    typed.get("ex5_sha256"), typed.get("setfile_sha256"),
                    typed.get("mq5_sha256"), typed.get("include_closure_sha256"),
                    typed.get("build_id"), typed.get("data_window_start"),
                    typed.get("data_window_end"), item["work_item_id"],
                    item["before_payload_raw"],
                ),
            )
            if cursor.rowcount != 1:
                raced_rows.append({
                    "work_item_id": item["work_item_id"],
                    "action": ACTION,
                    "reason": "compare_and_swap_missed",
                })
                continue
            applied_rows.append(item)

        assert journal is not None
        for item in plan["refused"]:
            installed, hold_detail = _install_refusal_hold(
                conn,
                item,
                task_id=task_id,
                repair_reason=reason,
                journal_path=journal,
                now=now,
            )
            if not installed:
                raced_rows.append({
                    "work_item_id": item["work_item_id"],
                    "action": REFUSAL_HOLD_ACTION,
                    **hold_detail,
                })
                continue
            held_rows.append({**item, "hold_detail": hold_detail})

        journal_document = {
            "schema": JOURNAL_SCHEMA,
            "recorded_at": now,
            "recorded_by": "q08_promotion_repair.py",
            "task_id": task_id,
            "reason": reason,
            "backup": backup,
            "candidate_count": plan["candidate_count"],
            "applied_count": len(applied_rows),
            "held_count": len(held_rows),
            "raced_count": len(raced_rows),
            "refused_count": plan["refused_count"],
            "unchanged_count": plan["unchanged_count"],
            "rows": [_summary_row(row) for row in applied_rows],
            "held": [_summary_refusal(row) for row in held_rows],
            "raced": raced_rows,
            "refused": [
                _summary_refusal(row) for row in plan["refused"]
            ],
            "terminal_rows_edited": 0,
            "verdicts_edited": 0,
            "evidence_paths_edited": 0,
        }
        farmctl._write_json_atomic(journal, journal_document)
        journal_written = True
        journal_sha256 = farmctl._sha256_file(journal)

        for item in applied_rows:
            ledger_key = (
                f"{ACTION}:{item['work_item_id']}:{item['after_payload_sha256']}"
            )
            detail = {
                "task_id": task_id,
                "journal_path": str(journal),
                "journal_sha256": journal_sha256,
                "backup_path": backup["path"],
                "backup_sha256": backup["sha256"],
                "before_payload_sha256": item["before_payload_sha256"],
                "after_payload_sha256": item["after_payload_sha256"],
                "predecessor_work_item_id": item["predecessor_work_item_id"],
                "compile_work_item_id": item.get("compile_work_item_id"),
            }
            conn.execute(
                """
                INSERT INTO work_item_transition_ledger(
                  idempotency_key,ts,work_item_id,action,from_status,to_status,
                  from_verdict,to_verdict,reason,run_id,detail_json
                ) VALUES(?,? ,?,?,'pending','pending',NULL,NULL,?,?,?)
                """,
                (
                    ledger_key, now, item["work_item_id"], ACTION,
                    reason, task_id, json.dumps(detail, sort_keys=True),
                ),
            )
            farmctl.event(
                conn,
                "work_item",
                item["work_item_id"],
                ACTION,
                detail,
            )
        for item in held_rows:
            ledger_key = (
                f"{REFUSAL_HOLD_ACTION}:{item['work_item_id']}:"
                f"{item['before_payload_sha256']}"
            )
            detail = {
                "task_id": task_id,
                "journal_path": str(journal),
                "journal_sha256": journal_sha256,
                "backup_path": backup["path"],
                "backup_sha256": backup["sha256"],
                "before_payload_sha256": item["before_payload_sha256"],
                "predecessor_work_item_id": item.get(
                    "predecessor_work_item_id"
                ),
                "hold_code": REFUSAL_HOLD_CODE,
                "refusal_reason": item["reason"],
                "refusal_detail": item.get("detail"),
                "conflicts": item.get("conflicts"),
            }
            conn.execute(
                """
                INSERT INTO work_item_transition_ledger(
                  idempotency_key,ts,work_item_id,action,from_status,to_status,
                  from_verdict,to_verdict,reason,run_id,detail_json
                ) VALUES(?,? ,?,?,'pending','pending',NULL,NULL,?,?,?)
                """,
                (
                    ledger_key, now, item["work_item_id"],
                    REFUSAL_HOLD_ACTION, item["reason"], task_id,
                    json.dumps(detail, sort_keys=True),
                ),
            )
            farmctl.event(
                conn,
                "work_item",
                item["work_item_id"],
                REFUSAL_HOLD_ACTION,
                detail,
            )
        conn.commit()
        return {
            "ok": True,
            "applied": bool(applied_rows or held_rows),
            "task_id": task_id,
            "candidate_count": plan["candidate_count"],
            "applied_count": len(applied_rows),
            "held_count": len(held_rows),
            "raced_count": len(raced_rows),
            "refused_count": plan["refused_count"],
            "unchanged_count": plan["unchanged_count"],
            "applied_rows": [_summary_row(row) for row in applied_rows],
            "held_rows": [_summary_refusal(row) for row in held_rows],
            "raced": raced_rows,
            "refused": [
                _summary_refusal(row) for row in plan["refused"]
            ],
            "backup": backup,
            "journal_path": str(journal),
            "journal_sha256": journal_sha256,
        }
    except Exception:
        if conn is not None:
            conn.rollback()
        if journal_written and journal is not None:
            journal.unlink(missing_ok=True)
        raise
    finally:
        if conn is not None:
            conn.close()
        lock.__exit__(None, None, None)


def _main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(r"D:\QM\strategy_farm"))
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--reason", required=True)
    parser.add_argument("--journal-path", type=Path)
    parser.add_argument("--work-item-id", action="append", default=[])
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    result = repair_pending_q08_promotions(
        args.root,
        task_id=args.task_id,
        reason=args.reason,
        apply=args.apply,
        journal_path=args.journal_path,
        work_item_ids=args.work_item_id or None,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(_main())
