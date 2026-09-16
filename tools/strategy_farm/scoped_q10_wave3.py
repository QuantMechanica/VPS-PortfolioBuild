"""Governed release of the re-held NEWS_RUNNER_SPAWN_SILENT_ABORT cohort.

The 2026-09-07 wave-2 release (``scoped_q10_wave2``) converted eight scoped
review-only rows and re-released the silent-abort rows after the worker fix
``d6b58fb213`` (dead bound news runners are parked, not retried forever).
Seven of those rows were re-held as ``NEWS_RUNNER_SPAWN_SILENT_ABORT`` between
2026-09-07 and 2026-09-10: every re-run died without durable completion at the
same point in the first cell.

Root cause (deterministic, reproduced 2026-09-16): the wave-2 scoped plans bind
cell evidence under ``scoped_q09_pass_anchor/<64-hex>/q09_contract_v3``, which
pushes tester artifacts past the 260-character Win32 MAX_PATH boundary.  When a
cell needed a failure sidecar, ``q09_news_runner._snapshot_failure_artifacts``
crashed inside ``rglob`` with WinError 3; the exception escaped
``execute_run_plan``; the runner exited with a traceback instead of durable
evidence; the worker (correctly, per d6b58fb213) parked the row again.  The
repair is the long-path-aware snapshot plus the v1 fail-safe sidecar in
``q09_news_runner`` (see the calibration/fix evidence under
``docs/ops/evidence/2026-09-16_deterministic_repairs/``).

This wave releases exactly the seven rows whose re-held aborts traced to that
crash: each row is released only when its bound plan and every runtime evidence
binding authenticate exactly like ``scoped_q10_wave2.inspect_abort``, and only
when the fix commit is present in the repository.  The two remaining held rows
are deliberately excluded and stay fail-closed:

* ``745671a4-02e4-4df5-b5e1-e25f0e41ca0e`` (QM5_11129): bound Q07
  seed-stability evidence is missing (already fail-closed in wave 2).
* ``d712832c-b41b-471c-a986-79f7f17f8dfb`` (QM5_11422): the bound plan fails
  source-vintage authentication at load; it needs a sealed-plan re-derivation,
  which is the separate governed lane.

Every operation is exact-ID allowlisted and emits a receipt line.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
from typing import Any, Mapping

try:
    from tools.strategy_farm import farmctl
    from tools.strategy_farm import news_calendar_scoped_activation as scoped_b
    from tools.strategy_farm import q09_news_runner as runner
    from tools.strategy_farm import release_compile_wave as backup_policy
except ModuleNotFoundError:
    import farmctl
    import news_calendar_scoped_activation as scoped_b
    import q09_news_runner as runner
    import release_compile_wave as backup_policy


ROOT = Path(r"D:\QM\strategy_farm")
EVIDENCE_ROOT = Path(r"C:\QM\repo\docs\ops\evidence")
TASK_ID = "8f14e55c-59f7-4a4b-9f3d-0e51aa6d4c21"
RELEASE_IDS = (
    "c18cf1fa-60c0-498e-82db-637fc8320f58",
    "ca96d7bf-51e0-4417-a5c6-94546e9d9946",
    "136b0e0f-7896-4e0c-b34b-47991cc49342",
    "450fb9f6-9797-496d-937e-9bddc5f292a8",
    "abea4df5-c03b-494a-a025-37747d0a1e32",
    "6d528b09-59d8-4c2f-bfb2-a1102e8ae12c",
    "b6e02932-d34d-4fea-8f3c-f977c8efe7eb",
)
EXCLUDED_IDS = {
    "745671a4-02e4-4df5-b5e1-e25f0e41ca0e": "bound Q07 evidence missing (wave-2 fail-closed)",
    "d712832c-b41b-471c-a986-79f7f17f8dfb": "plan source-vintage mismatch; sealed-plan re-derivation lane",
}
AUTHORITY = (
    "FACTORY_RECOVERABLE_BACKLOG/news_runner_spawn_silent_abort "
    "(RECOVERABLE_WITHOUT_OWNER) + det-repairs 2026-09-16 root-cause evidence"
)
# Filled in at commit time: the q09_news_runner long-path/fail-safe repair.
SILENT_ABORT_FIX_COMMIT = "1f88c6ac8a"


class Wave3Error(RuntimeError):
    pass


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _payload(row: sqlite3.Row) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (json.JSONDecodeError, TypeError) as exc:
        raise Wave3Error(f"{row['id']}: payload JSON invalid") from exc
    if not isinstance(value, dict):
        raise Wave3Error(f"{row['id']}: payload must be an object")
    return value


def _row(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row:
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
    if row is None:
        raise Wave3Error(f"{work_item_id}: work item missing")
    return row


def _active_hold(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM work_item_holds WHERE work_item_id=? AND active=1",
        (work_item_id,),
    ).fetchone()


def _assert_releasable_shape(row: sqlite3.Row) -> None:
    if (
        row["phase"] != "Q10_NEWS"
        or row["status"] != "pending"
        or row["verdict"] is not None
        or str(row["claimed_by"] or "").strip()
    ):
        raise Wave3Error(f"{row['id']}: not an unclaimed pending Q10_NEWS row")


def inspect_row(conn: sqlite3.Connection, row: sqlite3.Row) -> dict[str, Any]:
    """Authenticate one re-held row exactly like wave-2's abort inspection."""

    _assert_releasable_shape(row)
    hold = _active_hold(conn, str(row["id"]))
    if hold is None or hold["hold_code"] != "NEWS_RUNNER_SPAWN_SILENT_ABORT":
        raise Wave3Error(f"{row['id']}: expected silent-abort hold missing")
    payload = _payload(row)
    plan_path = Path(str(payload.get("q09_run_plan_path") or "")).resolve()
    plan, manifest = runner.load_authenticated_plan(
        plan_path,
        expected_file_sha256=str(payload.get("q09_run_plan_file_sha256") or ""),
    )
    runner.sealed_plan_period(manifest)
    if payload.get("scoped_q09_pass_execution_anchor") is not None:
        runner.validate_scoped_q09_pass_execution_anchor(payload)
    q07_path = Path(str(payload.get("q09_q07_evidence_path") or "")).resolve()
    q07_ok = q07_path.is_file() and _sha(q07_path) == payload.get("q09_q07_evidence_sha256")
    return {
        "work_item_id": str(row["id"]),
        "ea_id": str(row["ea_id"]),
        "hold_reason": str(hold["reason"]),
        "plan_path": str(plan_path),
        "plan_file_sha256": _sha(plan_path),
        "cell_count": int(plan["cell_count"]),
        "q07_evidence_path": str(q07_path),
        "q07_evidence_intact": q07_ok,
        "root_cause": (
            "failure-artifact snapshot crashed on >260-char scoped evidence paths "
            "(Win32 MAX_PATH); runner exited without durable completion"
            if q07_ok
            else "launch precondition fails closed because bound Q07 seed-stability evidence is missing"
        ),
        "releasable": bool(q07_ok),
    }


def _fix_commit_present() -> bool:
    result = subprocess.run(
        ["git", "cat-file", "-e", f"{SILENT_ABORT_FIX_COMMIT}^{{commit}}"],
        cwd=Path(r"C:\QM\repo"), capture_output=True, check=False,
    )
    return result.returncode == 0


def _release_hold(
    conn: sqlite3.Connection,
    row: sqlite3.Row,
    inspection: Mapping[str, Any],
) -> dict[str, Any]:
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    changed = conn.execute(
        """UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
           WHERE work_item_id=? AND hold_code=? AND active=1""",
        (
            now,
            now,
            f"wave-3 governed release after MAX_PATH snapshot fix; fix_commit={SILENT_ABORT_FIX_COMMIT}; router_task={TASK_ID}",
            row["id"],
            "NEWS_RUNNER_SPAWN_SILENT_ABORT",
        ),
    ).rowcount
    if changed != 1:
        raise Wave3Error(f"{row['id']}: expected active silent-abort hold missing")
    conn.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,'work_item',?,?,?)",
        (
            now,
            row["id"],
            "wave3_silent_abort_released",
            json.dumps(
                {
                    "router_task_id": TASK_ID,
                    "authority": AUTHORITY,
                    "root_cause": inspection["root_cause"],
                    "fix_commit": SILENT_ABORT_FIX_COMMIT,
                    "plan_file_sha256": inspection["plan_file_sha256"],
                    "q07_evidence_intact": True,
                    "verdict_changed": False,
                },
                sort_keys=True,
            ),
        ),
    )
    return {"released_at": now}


def cycle(*, apply: bool, receipt_path: Path) -> dict[str, Any]:
    if tuple(dict.fromkeys(RELEASE_IDS)) != RELEASE_IDS or len(RELEASE_IDS) != 7:
        raise Wave3Error("wave-3 allowlist invariant failed")
    receipt: dict[str, Any] = {
        "schema": "qm.scoped-b-release-wave3-receipt/v1",
        "router_task_id": TASK_ID,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "mode": "APPLY" if apply else "DRY_RUN",
        "authority": [AUTHORITY],
        "fix_commit": SILENT_ABORT_FIX_COMMIT,
        "allowlist": list(RELEASE_IDS),
        "excluded": dict(EXCLUDED_IDS),
        "rows": [],
    }
    with farmctl.connect(ROOT) as conn:
        conn.row_factory = sqlite3.Row
        prepared: dict[str, dict[str, Any]] = {}
        for work_item_id in RELEASE_IDS:
            entry: dict[str, Any] = {"work_item_id": work_item_id}
            try:
                inspection = inspect_row(conn, _row(conn, work_item_id))
                entry.update({"eligible": bool(inspection["releasable"]), **inspection})
                if not inspection["releasable"]:
                    entry["error"] = "bound Q07 evidence is missing; release remains fail-closed"
                elif not _fix_commit_present():
                    entry["eligible"] = False
                    entry["error"] = "silent-abort fix commit is not present in the repository"
                else:
                    prepared[work_item_id] = inspection
            except Exception as exc:
                entry.update({"eligible": False, "error": f"{type(exc).__name__}: {exc}"})
            receipt["rows"].append(entry)

    if apply:
        if not _fix_commit_present():
            raise Wave3Error("refusing to apply without the silent-abort fix commit present")
        with sqlite3.connect(str(farmctl.db_path(ROOT))) as backup_conn:
            backup_result = backup_policy._resolve_backup(
                backup_conn,
                farmctl.db_path(ROOT),
                ROOT / "state" / "backups",
                timeout_seconds=420.0,
                reuse_max_age_minutes=0.0,
                backup_label="scoped_b_wave3",
            )
        receipt["state_backup"] = str(backup_result["path"])
        receipt["state_backup_sha256"] = str(backup_result["sha256"])
        with farmctl.FactoryMutationLock(
            farmctl.path_for_factory_flag(farmctl.factory_off_flag_path(ROOT)),
            owner="scoped_q10_wave3",
        ):
            with farmctl.connect_short_under_mutation_lock(ROOT) as conn:
                conn.row_factory = sqlite3.Row
                for entry in receipt["rows"]:
                    work_item_id = entry["work_item_id"]
                    if not entry.get("eligible"):
                        entry["applied"] = False
                        continue
                    try:
                        conn.execute("BEGIN IMMEDIATE")
                        row = _row(conn, work_item_id)
                        entry.update(
                            {"applied": True, **_release_hold(conn, row, prepared[work_item_id])}
                        )
                        conn.commit()
                    except Exception as exc:
                        if conn.in_transaction:
                            conn.rollback()
                        entry.update({"applied": False, "apply_error": f"{type(exc).__name__}: {exc}"})

    receipt["eligible_count"] = sum(1 for row in receipt["rows"] if row.get("eligible"))
    receipt["applied_count"] = sum(1 for row in receipt["rows"] if row.get("applied"))
    receipt["deferred_count"] = len(receipt["rows"]) - (
        receipt["applied_count"] if apply else receipt["eligible_count"]
    )
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return receipt


def verify_state(*, receipt_path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "schema": "qm.scoped-b-release-wave3-verification/v1",
        "router_task_id": TASK_ID,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "rows": [],
    }
    activation = scoped_b.load_activation()
    with farmctl.connect(ROOT) as conn:
        conn.row_factory = sqlite3.Row
        for work_item_id in RELEASE_IDS:
            row = _row(conn, work_item_id)
            payload = _payload(row)
            hold = _active_hold(conn, work_item_id)
            checks: dict[str, bool] = {
                "phase_q10_news": row["phase"] == "Q10_NEWS",
                "verdict_unchanged_null": row["verdict"] is None,
                "pending_or_claimed_normally": row["status"] in {"pending", "active"},
                "no_active_policy_hold": hold is None,
                "terminal_claimable": payload.get("terminal_claimable", True) is True,
                "review_only_disabled": payload.get("scoped_review_only", False) is False,
                "b_marker_valid": scoped_b.marker_valid(dict(row), activation),
            }
            plan_path = Path(str(payload.get("q09_run_plan_path") or ""))
            runner.load_authenticated_plan(
                plan_path,
                expected_file_sha256=str(payload.get("q09_run_plan_file_sha256") or ""),
            )
            checks["execution_anchor_valid"] = bool(
                runner.validate_scoped_q09_pass_execution_anchor(payload)
            )
            result["rows"].append(
                {
                    "work_item_id": work_item_id,
                    "status": row["status"],
                    "claimed_by": row["claimed_by"],
                    "active_hold": hold["hold_code"] if hold else None,
                    "checks": checks,
                    "passed": all(checks.values()),
                }
            )
    result["passed_count"] = sum(1 for row in result["rows"] if row["passed"])
    result["failed_count"] = len(result["rows"]) - result["passed_count"]
    result["passed"] = result["failed_count"] == 0
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    if args.apply and args.verify:
        parser.error("--apply and --verify are mutually exclusive")
    if SILENT_ABORT_FIX_COMMIT == "TBD":
        parser.error("SILENT_ABORT_FIX_COMMIT must be set to the committed repair hash")
    if args.verify:
        result = verify_state(receipt_path=args.receipt.resolve())
        print(json.dumps({
            "mode": "VERIFY",
            "passed": result["passed"],
            "passed_count": result["passed_count"],
            "failed_count": result["failed_count"],
            "receipt": str(args.receipt.resolve()),
        }, indent=2))
        return 0 if result["passed"] else 1
    result = cycle(apply=args.apply, receipt_path=args.receipt.resolve())
    print(json.dumps({
        "mode": result["mode"],
        "eligible_count": result["eligible_count"],
        "applied_count": result["applied_count"],
        "deferred_count": result["deferred_count"],
        "receipt": str(args.receipt.resolve()),
    }, indent=2))
    return 0 if (not args.apply or result["applied_count"] == result["eligible_count"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
