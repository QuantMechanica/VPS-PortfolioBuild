"""Governed B-prime activation for the 2026-09-07 wave-2 allowlist.

The eight review-only rows are converted in place without changing a verdict:
their exact Q09 PASS aggregate and run summary are sealed into an explicit
execution anchor, an ordinary contract-v3 news plan is built, and the plan is
bound while the row remains held.  The Q09 plan hold is then atomically changed
to the physical calendar-taint hold and released through release_scoped_item().

The two historical silent-abort rows are inspected independently.  A row is
released only when its existing plan and every runtime evidence binding remain
intact.  Every operation is exact-ID allowlisted and emits a receipt line.
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
    from tools.strategy_farm import build_q09_include_closure as closure_builder
    from tools.strategy_farm import farmctl
    from tools.strategy_farm import news_calendar_scoped_activation as scoped_b
    from tools.strategy_farm import news_calendar_taint as taint
    from tools.strategy_farm import q09_news_runner as runner
    from tools.strategy_farm import release_compile_wave as backup_policy
except ModuleNotFoundError:
    import build_q09_include_closure as closure_builder
    import farmctl
    import news_calendar_scoped_activation as scoped_b
    import news_calendar_taint as taint
    import q09_news_runner as runner
    import release_compile_wave as backup_policy


ROOT = Path(r"D:\QM\strategy_farm")
EVIDENCE_ROOT = Path(r"C:\QM\repo\docs\ops\evidence")
TASK_ID = "253814f1-f01a-4ea5-899f-b4ea3fc2dbcb"
SCOPED_IDS = (
    "c18cf1fa-60c0-498e-82db-637fc8320f58",
    "ca96d7bf-51e0-4417-a5c6-94546e9d9946",
    "f15ac955-9dbb-4f39-9a9e-8eb142f11138",
    "136b0e0f-7896-4e0c-b34b-47991cc49342",
    "450fb9f6-9797-496d-937e-9bddc5f292a8",
    "abea4df5-c03b-494a-a025-37747d0a1e32",
    "6d528b09-59d8-4c2f-bfb2-a1102e8ae12c",
    "b6e02932-d34d-4fea-8f3c-f977c8efe7eb",
)
ABORT_IDS = (
    "ee4ff9b4-41a3-4e74-b5ec-de548ed47113",
    "745671a4-02e4-4df5-b5e1-e25f0e41ca0e",
)
ALLOWLIST = SCOPED_IDS + ABORT_IDS
DECISIONS = (
    "OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907",
    "OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907",
)
SILENT_ABORT_FIX_COMMIT = "d6b58fb21"


class Wave2Error(RuntimeError):
    pass


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical(value: Any) -> bytes:
    return runner.contract.canonical_json_bytes(value)


def _payload(row: Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (json.JSONDecodeError, TypeError) as exc:
        raise Wave2Error(f"{row['id']}: payload JSON invalid") from exc
    if not isinstance(value, dict):
        raise Wave2Error(f"{row['id']}: payload must be an object")
    return value


def _row(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row:
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
    if row is None:
        raise Wave2Error(f"{work_item_id}: work item missing")
    return row


def _active_hold(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM work_item_holds WHERE work_item_id=? AND active=1",
        (work_item_id,),
    ).fetchone()


def _assert_pending(row: sqlite3.Row) -> None:
    if (
        row["phase"] != "Q10_NEWS"
        or row["status"] != "pending"
        or row["verdict"] is not None
        or str(row["claimed_by"] or "").strip()
    ):
        raise Wave2Error(f"{row['id']}: not an unclaimed pending Q10_NEWS row")


def _source_summary(source_evidence: Mapping[str, Any]) -> tuple[Path, dict[str, Any]]:
    summary_path = Path(str(source_evidence.get("summary_path") or "")).resolve()
    if not summary_path.is_file():
        raise Wave2Error(f"source Q09 summary missing: {summary_path}")
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Wave2Error(f"source Q09 summary invalid: {summary_path}") from exc
    if not isinstance(summary, dict):
        raise Wave2Error("source Q09 summary must be an object")
    return summary_path, summary


def scoped_anchor_material(
    conn: sqlite3.Connection, row: sqlite3.Row
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Authenticate a review-only row and return its unsigned anchor + paths."""

    _assert_pending(row)
    payload = _payload(row)
    seal = payload.get("scoped_q10_window_seal")
    if (
        not isinstance(seal, dict)
        or payload.get("scoped_review_only") is not True
        or payload.get("terminal_claimable") is not False
        or seal.get("schema") != "qm.scoped-q10-window-seal/v1"
        or seal.get("terminal_claimable") is not False
    ):
        raise Wave2Error(f"{row['id']}: review-only scoped window seal missing")
    seal_unsigned = dict(seal)
    seal_sha = str(seal_unsigned.pop("seal_sha256", ""))
    expected_seal_sha = hashlib.sha256(
        (json.dumps(seal_unsigned, sort_keys=True, separators=(",", ":")) + "\n").encode()
    ).hexdigest()
    if seal_sha != expected_seal_sha:
        raise Wave2Error(f"{row['id']}: scoped window seal self-hash mismatch")
    source = _row(conn, str(seal.get("source_work_item_id") or ""))
    if (
        source["phase"] != "Q09"
        or source["status"] != "done"
        or source["verdict"] != "PASS"
        or any(str(source[key] or "") != str(row[key] or "") for key in ("ea_id", "symbol", "setfile_path"))
    ):
        raise Wave2Error(f"{row['id']}: exact Q09 PASS source identity mismatch")
    evidence_path = Path(str(source["evidence_path"] or "")).resolve()
    if not evidence_path.is_file() or _sha(evidence_path) != seal.get("source_evidence_sha256"):
        raise Wave2Error(f"{row['id']}: source Q09 aggregate binding failed")
    evidence = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    summary_path, summary = _source_summary(evidence)
    expected_period = str(payload.get("expected_period") or "").upper()
    if (
        evidence.get("phase") != "Q09"
        or evidence.get("verdict") != "PASS"
        or str(evidence.get("symbol") or "") != str(row["symbol"])
        or summary.get("result") != "PASS"
        or str(summary.get("symbol") or "") != str(row["symbol"])
        or str(summary.get("period") or "").upper() != expected_period
        or str(summary.get("from_date") or "") != str(evidence.get("history_from") or "")
        or str(summary.get("to_date") or "") != str(evidence.get("history_to") or "")
    ):
        raise Wave2Error(f"{row['id']}: source Q09 aggregate/summary contradiction")

    setfile = Path(str(row["setfile_path"])).resolve()
    ea_id = str(row["ea_id"])
    ea_dir = farmctl._ea_dir_from_setfile_path(setfile, ea_id) or farmctl._preferred_ea_dir(ea_id)
    if ea_dir is None:
        raise Wave2Error(f"{row['id']}: canonical EA directory missing/ambiguous")
    ex5 = (ea_dir / f"{ea_dir.name}.ex5").resolve()
    mq5 = (ea_dir / f"{ea_dir.name}.mq5").resolve()
    artifact_identity = payload.get("artifact_identity") or {}
    actual = {
        "setfile_sha256": _sha(setfile),
        "ex5_sha256": _sha(ex5),
        "mq5_sha256": _sha(mq5),
    }
    for key, digest in actual.items():
        if str(artifact_identity.get(key) or "").lower() != digest:
            raise Wave2Error(f"{row['id']}: current {key} differs from scoped identity")
    summary_ex5 = (
        ((summary.get("execution_identity") or {}).get("expert_binary") or {}).get("source") or {}
    ).get("sha256")
    if str(summary_ex5 or "").lower() != actual["ex5_sha256"]:
        raise Wave2Error(f"{row['id']}: source Q09/current EX5 mismatch")

    material = {
        "schema_version": "qm.scoped-q10-q09-pass-execution-anchor/v1",
        "scope": "OWNER_B_PRIME_EXACT_ALLOWLIST",
        "router_task_id": TASK_ID,
        "source_work_item_id": str(source["id"]),
        "source_evidence_path": str(evidence_path),
        "source_evidence_sha256": _sha(evidence_path),
        "source_summary_path": str(summary_path),
        "source_summary_sha256": _sha(summary_path),
        "source_verdict": "PASS",
        "source_window_seal_sha256": seal_sha,
        "ea_id": ea_id,
        "symbol": str(row["symbol"]),
        "baseline_run": {
            "period": expected_period,
            "baseline_setfile_path": str(setfile),
            "baseline_setfile_sha256": actual["setfile_sha256"],
            "baseline_ex5_path": str(ex5),
            "baseline_ex5_sha256": actual["ex5_sha256"],
            "baseline_mq5_path": str(mq5),
            "baseline_mq5_sha256": actual["mq5_sha256"],
        },
        "authority": list(DECISIONS),
        "pipeline_verdict_created": False,
    }
    context = {
        "payload": payload,
        "source": source,
        "setfile": setfile,
        "ea_dir": ea_dir,
        "ex5": ex5,
        "mq5": mq5,
        "seal": seal,
    }
    return material, context


def _write_anchor(row: sqlite3.Row, material: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    unsigned_sha = hashlib.sha256(_canonical(material)).hexdigest()
    document = {**material, "anchor_sha256": unsigned_sha}
    root = farmctl.Q09_AUTOPILOT_REPORT_ROOT / str(row["id"]) / "scoped_q09_pass_anchor" / unsigned_sha
    path = (root / "anchor.json").resolve()
    runner._write_immutable(path, _canonical(document))
    return path, document


def _build_scoped_plan(row: sqlite3.Row, material: dict[str, Any], context: dict[str, Any]) -> tuple[dict[str, Any], Path, dict[str, Any]]:
    anchor_path, anchor = _write_anchor(row, material)
    closure, closure_validation = farmctl._validated_q09_include_closure(
        closure_builder,
        ea_id=str(row["ea_id"]),
        ea_dir=Path(context["ea_dir"]),
        work_item_id=str(row["id"]),
    )
    output_root = anchor_path.parent / "q09_contract_v3"
    plan = runner.build_run_plan(
        work_item_id=str(row["id"]),
        candidate_lineage_key=farmctl._q09_candidate_lineage_key(
            str(row["ea_id"]), str(row["symbol"]), str(material["source_work_item_id"])
        ),
        deployment_target="DXZ",
        q08_work_item_id=str(material["source_work_item_id"]),
        q08_evidence_path=anchor_path,
        baseline_setfile_path=Path(context["setfile"]),
        ex5_path=Path(context["ex5"]),
        include_closure_path=closure,
        calendar_manifest_path=farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST,
        calendar_common_relative_path=farmctl.Q09_AUTOPILOT_CALENDAR_COMMON_RELATIVE_PATH,
        tester_model="REAL_TICKS",
        cost_profile="DXZ_CANONICAL_REAL_TICKS_V1",
        news_or_event_strategy=False,
        force_expanded_matrix=farmctl._force_expanded_news_matrix(row),
        contract_version=runner.contract.SCHEMA_VERSION_V3,
        output_root=output_root,
        **farmctl.Q09_AUTOPILOT_WINDOWS,
    )
    return plan, anchor_path, {
        "anchor": anchor,
        "closure_path": str(closure),
        "generated_source_drift": list(closure_validation.get("generated_source_drift") or []),
    }


def _activation_marker(payload: Mapping[str, Any], seal: Mapping[str, Any]) -> dict[str, Any]:
    material = {
        "schema": "qm.scoped-q10-plan-activation/v1",
        "router_task_id": TASK_ID,
        "source_window_seal_sha256": seal["seal_sha256"],
        "run_plan_path": payload["q09_run_plan_path"],
        "run_plan_file_sha256": payload["q09_run_plan_file_sha256"],
        "input_manifest_sha256": payload["q09_input_manifest_sha256"],
        "authority": list(DECISIONS),
    }
    return {**material, "activation_sha256": hashlib.sha256(scoped_b._canonical(material)).hexdigest()}


def _replace_hold_with_scoped_release(
    conn: sqlite3.Connection,
    *,
    row: sqlite3.Row,
    expected_hold: str,
    event_detail: Mapping[str, Any],
) -> dict[str, Any]:
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    changed = conn.execute(
        """UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
           WHERE work_item_id=? AND hold_code=? AND active=1""",
        (now, now, f"wave-2 governed transition; router_task={TASK_ID}", row["id"], expected_hold),
    ).rowcount
    if changed != 1:
        raise Wave2Error(f"{row['id']}: expected active {expected_hold} hold missing")
    conn.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,'work_item',?,?,?)",
        (now, row["id"], "wave2_prior_hold_released", json.dumps(dict(event_detail), sort_keys=True)),
    )
    synchronized = taint.synchronize(
        conn,
        taint.load_policy(),
        farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST,
        item_id=str(row["id"]),
        apply=True,
    )
    if len(synchronized) != 1 or synchronized[0].get("action") != "HOLD":
        raise Wave2Error(f"{row['id']}: physical taint hold was not created")
    marker = taint.release_scoped_item(
        conn, str(row["id"]), farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST
    )
    return {"taint_synchronize": synchronized[0], "b_marker": marker}


def _apply_scoped(conn: sqlite3.Connection, row: sqlite3.Row, plan: Mapping[str, Any], anchor_path: Path, build: Mapping[str, Any]) -> dict[str, Any]:
    plan_path = Path(str(plan["plan_path"])).resolve()
    plan_sha = _sha(plan_path)
    loaded_plan, manifest = runner.load_authenticated_plan(
        plan_path, expected_file_sha256=plan_sha
    )
    payload = _payload(row)
    source = str(build["anchor"]["source_work_item_id"])
    source_evidence_path = str(build["anchor"]["source_evidence_path"])
    source_evidence_sha = str(build["anchor"]["source_evidence_sha256"])
    timeout_min = runner.required_factory_timeout_min(
        int(loaded_plan["cell_count"]),
        cell_timeout_sec=farmctl.Q09_AUTOPILOT_CELL_TIMEOUT_SEC,
        window_count=int(loaded_plan.get("window_count") or 2),
    )
    payload.update({
        "q09_binding_version": "q09-news-dispatch-binding/v1",
        "q09_activation_state": "RUNNABLE_BOUND",
        "q09_run_plan_path": str(plan_path),
        "q09_run_plan_file_sha256": plan_sha,
        "q09_run_plan_sha256": loaded_plan["plan_sha256"],
        "q09_input_manifest_sha256": loaded_plan["input_manifest_sha256"],
        "q09_q08_work_item_id": source,
        "q09_q08_evidence_sha256": manifest["identities"]["q08_evidence_sha256"],
        # These legacy-named fields remain populated for result provenance;
        # runtime authentication uses the explicit scoped anchor marker.
        "q09_q07_work_item_id": source,
        "q09_q07_evidence_path": source_evidence_path,
        "q09_q07_evidence_sha256": source_evidence_sha,
        "q09_q07_lineage_resolution": "scoped_q09_pass_execution_anchor",
        "q09_cell_count": int(loaded_plan["cell_count"]),
        "q09_cell_timeout_sec": farmctl.Q09_AUTOPILOT_CELL_TIMEOUT_SEC,
        "q09_plan_bound_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "q09_autoseal_plan_generation": {
            "mode": "scoped_q09_pass_anchor",
            "output_root": str(plan_path.parent),
            "supersedes_plan_path": None,
        },
        "scoped_q09_pass_execution_anchor": {
            "path": str(anchor_path),
            "sha256": _sha(anchor_path),
            "source_work_item_id": source,
        },
        "scoped_review_only": False,
        "terminal_claimable": True,
        "timeout_min": max(int(payload.get("timeout_min") or 0), timeout_min),
    })
    payload.pop("q09_autoseal_failure", None)
    payload.pop("q09_activation_next_action", None)
    # Older long-lived workers know only that a top-level scoped seal is
    # review-only.  Archive that exact seal under an explicit provenance key
    # so they naturally select the ordinary bound-plan branch without a fleet
    # restart; the activation marker binds the transition to the original hash.
    origin_seal = payload.pop("scoped_q10_window_seal")
    payload["scoped_q10_window_seal_review_origin"] = origin_seal
    payload["scoped_q10_plan_activation"] = _activation_marker(payload, origin_seal)
    payload["q09_dispatch_binding_sha256"] = runner._dispatch_binding_sha256(payload)
    runner.validate_scoped_q09_pass_execution_anchor(payload, manifest)
    conn.execute(
        "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
        (json.dumps(payload, sort_keys=True), dt.datetime.now(dt.timezone.utc).isoformat(), row["id"]),
    )
    release = _replace_hold_with_scoped_release(
        conn,
        row=row,
        expected_hold="Q09_AWAITING_SEALED_PLAN",
        event_detail={
            "router_task_id": TASK_ID,
            "plan_path": str(plan_path),
            "plan_file_sha256": plan_sha,
            "execution_anchor_path": str(anchor_path),
            "execution_anchor_sha256": _sha(anchor_path),
            "verdict_changed": False,
        },
    )
    return {
        "action": "SCOPED_PLAN_BOUND_AND_B_RELEASED",
        "plan_path": str(plan_path),
        "plan_file_sha256": plan_sha,
        "cell_count": int(loaded_plan["cell_count"]),
        "execution_anchor_path": str(anchor_path),
        "execution_anchor_sha256": _sha(anchor_path),
        **release,
    }


def inspect_abort(conn: sqlite3.Connection, row: sqlite3.Row) -> dict[str, Any]:
    _assert_pending(row)
    hold = _active_hold(conn, str(row["id"]))
    if hold is None or hold["hold_code"] != "NEWS_RUNNER_SPAWN_SILENT_ABORT":
        raise Wave2Error(f"{row['id']}: expected silent-abort hold missing")
    payload = _payload(row)
    plan_path = Path(str(payload.get("q09_run_plan_path") or "")).resolve()
    plan, manifest = runner.load_authenticated_plan(
        plan_path,
        expected_file_sha256=str(payload.get("q09_run_plan_file_sha256") or ""),
    )
    runner.sealed_plan_period(manifest)
    q07_path = Path(str(payload.get("q09_q07_evidence_path") or "")).resolve()
    q07_ok = q07_path.is_file() and _sha(q07_path) == payload.get("q09_q07_evidence_sha256")
    return {
        "work_item_id": str(row["id"]),
        "hold_reason": str(hold["reason"]),
        "plan_path": str(plan_path),
        "plan_file_sha256": _sha(plan_path),
        "cell_count": int(plan["cell_count"]),
        "q07_evidence_path": str(q07_path),
        "q07_evidence_intact": q07_ok,
        "root_cause": (
            "runner/worker process exited before durable completion; creation-key/PID-reuse handling is fixed"
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


def _apply_abort(conn: sqlite3.Connection, row: sqlite3.Row, inspection: Mapping[str, Any]) -> dict[str, Any]:
    if not inspection.get("releasable") or not _fix_commit_present():
        raise Wave2Error(f"{row['id']}: silent-abort recovery preconditions not met")
    release = _replace_hold_with_scoped_release(
        conn,
        row=row,
        expected_hold="NEWS_RUNNER_SPAWN_SILENT_ABORT",
        event_detail={
            "router_task_id": TASK_ID,
            "root_cause": inspection["root_cause"],
            "fix_commit": SILENT_ABORT_FIX_COMMIT,
            "plan_file_sha256": inspection["plan_file_sha256"],
            "q07_evidence_intact": True,
            "verdict_changed": False,
        },
    )
    return {
        "action": "SILENT_ABORT_HOLD_RELEASED_AND_B_RELEASED",
        "fix_commit": SILENT_ABORT_FIX_COMMIT,
        **inspection,
        **release,
    }


def cycle(*, apply: bool, receipt_path: Path) -> dict[str, Any]:
    if tuple(dict.fromkeys(ALLOWLIST)) != ALLOWLIST or len(ALLOWLIST) != 10:
        raise Wave2Error("wave-2 allowlist invariant failed")
    receipt: dict[str, Any] = {
        "schema": "qm.scoped-b-release-wave2-receipt/v1",
        "router_task_id": TASK_ID,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "mode": "APPLY" if apply else "DRY_RUN",
        "authority": list(DECISIONS),
        "allowlist": list(ALLOWLIST),
        "rows": [],
    }
    with farmctl.connect(ROOT) as conn:
        conn.row_factory = sqlite3.Row
        prepared: dict[str, tuple[dict[str, Any], dict[str, Any]]] = {}
        for work_item_id in SCOPED_IDS:
            entry = {"work_item_id": work_item_id, "kind": "SCOPED_WINDOW_SUCCESSOR"}
            try:
                row = _row(conn, work_item_id)
                material, context = scoped_anchor_material(conn, row)
                assessment = scoped_b.assess_work_item(dict(row), scoped_b.load_activation())
                if assessment.get("verdict") != "ADMISSIBLE":
                    raise Wave2Error(f"B-prime assessment is {assessment.get('verdict')}")
                prepared[work_item_id] = (material, context)
                entry.update({
                    "eligible": True,
                    "would": "seal contract-v3 plan, atomically replace Q09 hold with taint hold, stamp B marker",
                    "source_work_item_id": material["source_work_item_id"],
                    "source_evidence_sha256": material["source_evidence_sha256"],
                    "baseline_run": material["baseline_run"],
                    "assessment_sha256": assessment["assessment_sha256"],
                })
            except Exception as exc:
                entry.update({"eligible": False, "error": f"{type(exc).__name__}: {exc}"})
            receipt["rows"].append(entry)
        for work_item_id in ABORT_IDS:
            entry = {"work_item_id": work_item_id, "kind": "SILENT_ABORT"}
            try:
                inspection = inspect_abort(conn, _row(conn, work_item_id))
                entry.update({"eligible": bool(inspection["releasable"]), **inspection})
                if not inspection["releasable"]:
                    entry["error"] = "bound Q07 evidence is missing; release remains fail-closed"
            except Exception as exc:
                entry.update({"eligible": False, "error": f"{type(exc).__name__}: {exc}"})
            receipt["rows"].append(entry)

    if apply:
        # The production DB is currently ~700 MiB; the generic 60-second
        # helper can time out under normal WAL traffic.  Keep the same online
        # backup policy but grant this explicit one-shot mutation seven minutes.
        with sqlite3.connect(str(farmctl.db_path(ROOT))) as backup_conn:
            backup_result = backup_policy._resolve_backup(
                backup_conn,
                farmctl.db_path(ROOT),
                ROOT / "state" / "backups",
                timeout_seconds=420.0,
                reuse_max_age_minutes=0.0,
                backup_label="scoped_b_wave2",
            )
        backup = Path(backup_result["path"])
        backup_sha = str(backup_result["sha256"])
        receipt["state_backup"] = str(backup)
        receipt["state_backup_sha256"] = backup_sha
        built: dict[str, tuple[dict[str, Any], Path, dict[str, Any]]] = {}
        for work_item_id, (material, context) in prepared.items():
            with farmctl.connect(ROOT) as conn:
                conn.row_factory = sqlite3.Row
                built[work_item_id] = _build_scoped_plan(_row(conn, work_item_id), material, context)
        with farmctl.FactoryMutationLock(
            farmctl.path_for_factory_flag(farmctl.factory_off_flag_path(ROOT)),
            owner="scoped_q10_wave2",
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
                        if work_item_id in built:
                            plan, anchor_path, build = built[work_item_id]
                            result = _apply_scoped(conn, row, plan, anchor_path, build)
                        else:
                            result = _apply_abort(conn, row, inspect_abort(conn, row))
                        conn.commit()
                        entry.update({"applied": True, **result})
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
        "schema": "qm.scoped-b-release-wave2-verification/v1",
        "router_task_id": TASK_ID,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "rows": [],
    }
    activation = scoped_b.load_activation()
    with farmctl.connect(ROOT) as conn:
        conn.row_factory = sqlite3.Row
        for work_item_id in ALLOWLIST:
            row = _row(conn, work_item_id)
            payload = _payload(row)
            hold = _active_hold(conn, work_item_id)
            checks: dict[str, bool] = {
                "phase_q10_news": row["phase"] == "Q10_NEWS",
                "verdict_unchanged_null": row["verdict"] is None,
            }
            if work_item_id == ABORT_IDS[1]:
                checks.update({
                    "still_pending_unclaimed": row["status"] == "pending" and not row["claimed_by"],
                    "silent_abort_hold_preserved": bool(
                        hold and hold["hold_code"] == "NEWS_RUNNER_SPAWN_SILENT_ABORT"
                    ),
                    "b_marker_absent": scoped_b.MARKER_KEY not in payload,
                    "missing_q07_still_fail_closed": not Path(
                        str(payload.get("q09_q07_evidence_path") or "")
                    ).is_file(),
                })
            else:
                plan_path = Path(str(payload.get("q09_run_plan_path") or ""))
                runner.load_authenticated_plan(
                    plan_path,
                    expected_file_sha256=str(payload.get("q09_run_plan_file_sha256") or ""),
                )
                checks.update({
                    "pending_or_claimed_normally": row["status"] in {"pending", "active"},
                    "terminal_claimable": payload.get("terminal_claimable", True) is True,
                    "review_only_disabled": payload.get("scoped_review_only", False) is False,
                    "b_marker_valid": scoped_b.marker_valid(dict(row), activation),
                    "no_active_policy_hold": hold is None,
                })
                if work_item_id in SCOPED_IDS:
                    checks.update({
                        "review_origin_preserved": isinstance(
                            payload.get("scoped_q10_window_seal_review_origin"), dict
                        ),
                        "execution_anchor_valid": bool(
                            runner.validate_scoped_q09_pass_execution_anchor(payload)
                        ),
                    })
                else:
                    checks["bound_q07_intact"] = Path(
                        str(payload.get("q09_q07_evidence_path") or "")
                    ).is_file()
            result["rows"].append({
                "work_item_id": work_item_id,
                "status": row["status"],
                "claimed_by": row["claimed_by"],
                "active_hold": hold["hold_code"] if hold else None,
                "checks": checks,
                "passed": all(checks.values()),
            })
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
