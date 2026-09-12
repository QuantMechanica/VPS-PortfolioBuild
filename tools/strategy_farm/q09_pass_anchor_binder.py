"""Bind held Q10_NEWS rows to an authenticated exact Q09 PASS anchor.

Default mode is a read-only census.  ``--apply`` authors an immutable
q09-news-run-plan/v2 and atomically replaces only the ordinary
Q09_AWAITING_SEALED_PLAN hold.  Historical work items and verdicts are never
changed.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3
from typing import Any, Mapping

try:
    from tools.strategy_farm import build_q09_include_closure as closure_builder
    from tools.strategy_farm import farmctl
    from tools.strategy_farm import q09_news_runner as runner
    from tools.strategy_farm import q09_news_schema as news_schema
except ModuleNotFoundError:
    import build_q09_include_closure as closure_builder
    import farmctl
    import q09_news_runner as runner
    import q09_news_schema as news_schema


ROOT = Path(r"D:\QM\strategy_farm")
TASK_ID = "b982a763-925a-46d1-9414-825f18ab26f8"
HOLD = "Q09_AWAITING_SEALED_PLAN"
ANCHOR_SCOPE = "Q09_AUTOSEAL_EXACT_PASS"


class BinderError(RuntimeError):
    pass


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _payload(row: Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (json.JSONDecodeError, TypeError) as exc:
        raise BinderError(f"{row['id']}: payload JSON invalid") from exc
    if not isinstance(value, dict):
        raise BinderError(f"{row['id']}: payload must be an object")
    return value


def _load(path: Path, role: str) -> dict[str, Any]:
    if not path.is_file():
        raise BinderError(f"{role} missing: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise BinderError(f"{role} invalid: {path}") from exc
    if not isinstance(value, dict):
        raise BinderError(f"{role} must be an object")
    return value


def _same_path(left: Any, right: Any) -> bool:
    return str(Path(str(left)).resolve()).casefold() == str(Path(str(right)).resolve()).casefold()


def _source(conn: sqlite3.Connection, row: sqlite3.Row) -> sqlite3.Row | None:
    payload = _payload(row)
    promoted = str(payload.get("promoted_from_work_item") or "")
    if promoted:
        candidate = conn.execute("SELECT * FROM work_items WHERE id=?", (promoted,)).fetchone()
        if candidate is not None and _source_identity_matches(candidate, row):
            return candidate
    candidates = conn.execute(
        """
        SELECT * FROM work_items
        WHERE phase='Q09' AND status='done' AND verdict='PASS'
          AND ea_id=? AND symbol=?
        ORDER BY updated_at DESC,id DESC
        """,
        (row["ea_id"], row["symbol"]),
    ).fetchall()
    return next((candidate for candidate in candidates if _source_identity_matches(candidate, row)), None)


def _source_identity_matches(source: sqlite3.Row, row: sqlite3.Row) -> bool:
    return bool(
        source["phase"] == "Q09"
        and source["status"] == "done"
        and source["verdict"] == "PASS"
        and str(source["ea_id"]) == str(row["ea_id"])
        and str(source["symbol"]) == str(row["symbol"])
        and _same_path(source["setfile_path"], row["setfile_path"])
    )


def _execution_symbol(source: sqlite3.Row, row: sqlite3.Row) -> str:
    """Return the tester symbol authenticated by an exact logical basket pair."""
    logical_symbol = str(row["symbol"])
    row_payload = _payload(row)
    source_payload = _payload(source)
    if row_payload.get("portfolio_scope") != "basket":
        return logical_symbol
    identity_fields = ("portfolio_scope", "logical_symbol", "host_symbol", "basket_manifest")
    if any(str(row_payload.get(field) or "") != str(source_payload.get(field) or "") for field in identity_fields):
        raise BinderError("Q09 basket execution identity mismatch")
    row_symbols = row_payload.get("basket_symbols")
    source_symbols = source_payload.get("basket_symbols")
    host_symbol = str(row_payload.get("host_symbol") or "")
    if (
        not host_symbol
        or row_payload.get("logical_symbol") != logical_symbol
        or not isinstance(row_symbols, list)
        or row_symbols != source_symbols
        or host_symbol not in row_symbols
    ):
        raise BinderError("Q09 basket execution identity is incomplete")
    return host_symbol


def _material(conn: sqlite3.Connection, row: sqlite3.Row) -> tuple[dict[str, Any], dict[str, Any]]:
    if row["phase"] != "Q10_NEWS" or row["status"] != "pending" or row["verdict"] is not None:
        raise BinderError("row is not pending Q10_NEWS")
    if str(row["claimed_by"] or ""):
        raise BinderError("row is already claimed")
    source = _source(conn, row)
    if source is None:
        raise BinderError("no exact completed Q09 PASS source")
    evidence_path = Path(str(source["evidence_path"] or "")).resolve()
    evidence = _load(evidence_path, "Q09 PASS aggregate")
    summary_path = Path(str(evidence.get("summary_path") or "")).resolve()
    summary = _load(summary_path, "Q09 PASS summary")
    payload = _payload(row)
    execution_symbol = _execution_symbol(source, row)
    expected_period = str(payload.get("expected_period") or "").upper()
    if (
        evidence.get("phase") != "Q09"
        or evidence.get("verdict") != "PASS"
        or str(evidence.get("symbol") or "") != execution_symbol
        or summary.get("result") != "PASS"
        or str(summary.get("symbol") or "") != execution_symbol
        or (expected_period and str(summary.get("period") or "").upper() != expected_period)
        or str(summary.get("from_date") or "") != str(evidence.get("history_from") or "")
        or str(summary.get("to_date") or "") != str(evidence.get("history_to") or "")
    ):
        raise BinderError("Q09 PASS aggregate/summary contradiction")
    setfile = Path(str(row["setfile_path"])).resolve()
    ea_dir = farmctl._ea_dir_from_setfile_path(setfile, str(row["ea_id"])) or farmctl._preferred_ea_dir(str(row["ea_id"]))
    if ea_dir is None:
        raise BinderError("canonical EA directory missing or ambiguous")
    ex5 = (ea_dir / f"{ea_dir.name}.ex5").resolve()
    mq5 = (ea_dir / f"{ea_dir.name}.mq5").resolve()
    for path, role in ((setfile, "setfile"), (ex5, "EX5"), (mq5, "MQ5")):
        if not path.is_file():
            raise BinderError(f"current {role} missing: {path}")
    summary_ex5 = (((summary.get("execution_identity") or {}).get("expert_binary") or {}).get("source") or {}).get("sha256")
    if str(summary_ex5 or "").lower() != _sha(ex5):
        raise BinderError("Q09 PASS/current EX5 mismatch")
    period = expected_period or str(summary.get("period") or "").upper()
    material = {
        "schema_version": "qm.scoped-q10-q09-pass-execution-anchor/v1",
        "scope": ANCHOR_SCOPE,
        "router_task_id": TASK_ID,
        "source_work_item_id": str(source["id"]),
        "source_evidence_path": str(evidence_path),
        "source_evidence_sha256": _sha(evidence_path),
        "source_summary_path": str(summary_path),
        "source_summary_sha256": _sha(summary_path),
        "source_verdict": "PASS",
        "ea_id": str(row["ea_id"]),
        "symbol": str(row["symbol"]),
        "execution_symbol": execution_symbol,
        "baseline_run": {
            "period": period,
            "baseline_setfile_path": str(setfile),
            "baseline_setfile_sha256": _sha(setfile),
            "baseline_ex5_path": str(ex5),
            "baseline_ex5_sha256": _sha(ex5),
            "baseline_mq5_path": str(mq5),
            "baseline_mq5_sha256": _sha(mq5),
        },
        "authority": ["router_task:" + TASK_ID],
        "pipeline_verdict_created": False,
    }
    return material, {"source": source, "setfile": setfile, "ea_dir": ea_dir, "ex5": ex5}


def collect(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    rows = conn.execute(
        """SELECT w.* FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
           WHERE w.phase='Q10_NEWS' AND w.status='pending' AND h.hold_code=? AND h.active=1
           ORDER BY w.created_at,w.id""",
        (HOLD,),
    ).fetchall()
    findings = []
    for row in rows:
        payload = _payload(row)
        failure = payload.get("q09_autoseal_failure") or {}
        try:
            material, _ = _material(conn, row)
            findings.append({"work_item_id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
                "prior_reason_code": failure.get("reason_code"), "action": "BIND_Q09_PASS_ANCHOR",
                "source_work_item_id": material["source_work_item_id"]})
        except BinderError as exc:
            findings.append({"work_item_id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
                "prior_reason_code": failure.get("reason_code"), "action": "HOLD", "reason": str(exc)})
    return findings


def _write_anchor(row: sqlite3.Row, material: dict[str, Any]) -> Path:
    unsigned_sha = hashlib.sha256(runner.contract.canonical_json_bytes(material)).hexdigest()
    document = {**material, "anchor_sha256": unsigned_sha}
    path = (farmctl.Q09_AUTOPILOT_REPORT_ROOT / str(row["id"]) / "q09_pass_anchor" / unsigned_sha / "anchor.json").resolve()
    runner._write_immutable(path, runner.contract.canonical_json_bytes(document))
    return path


def apply_one(conn: sqlite3.Connection, row: sqlite3.Row) -> dict[str, Any]:
    material, context = _material(conn, row)
    anchor_path = _write_anchor(row, material)
    closure, _ = farmctl._validated_q09_include_closure(
        closure_builder, ea_id=str(row["ea_id"]), ea_dir=context["ea_dir"], work_item_id=str(row["id"])
    )
    plan = runner.build_run_plan(
        work_item_id=str(row["id"]),
        candidate_lineage_key=farmctl._q09_candidate_lineage_key(str(row["ea_id"]), str(row["symbol"]), material["source_work_item_id"]),
        deployment_target="DXZ", q08_work_item_id=material["source_work_item_id"],
        q08_evidence_path=anchor_path, baseline_setfile_path=context["setfile"], ex5_path=context["ex5"],
        include_closure_path=closure, calendar_manifest_path=farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST,
        calendar_common_relative_path=farmctl.Q09_AUTOPILOT_CALENDAR_COMMON_RELATIVE_PATH,
        tester_model="REAL_TICKS", cost_profile="DXZ_CANONICAL_REAL_TICKS_V1",
        contract_version=runner.contract.SCHEMA_VERSION,
        output_root=anchor_path.parent / "q09_contract_v2", **farmctl.Q09_AUTOPILOT_WINDOWS,
    )
    plan_path = Path(plan["plan_path"]).resolve()
    plan_file_sha = _sha(plan_path)
    loaded, manifest = runner.load_authenticated_plan(plan_path, expected_file_sha256=plan_file_sha)
    payload = _payload(row)
    source = material["source_work_item_id"]
    timeout_min = runner.required_factory_timeout_min(
        int(loaded["cell_count"]), cell_timeout_sec=farmctl.Q09_AUTOPILOT_CELL_TIMEOUT_SEC,
        window_count=int(loaded.get("window_count") or 3),
    )
    payload.update({
        "q09_binding_version": "q09-news-dispatch-binding/v1", "q09_activation_state": "RUNNABLE_BOUND",
        "q09_run_plan_path": str(plan_path), "q09_run_plan_file_sha256": plan_file_sha,
        "q09_run_plan_sha256": loaded["plan_sha256"], "q09_input_manifest_sha256": loaded["input_manifest_sha256"],
        "q09_q08_work_item_id": source, "q09_q08_evidence_sha256": manifest["identities"]["q08_evidence_sha256"],
        "q09_q07_work_item_id": source, "q09_q07_evidence_path": material["source_evidence_path"],
        "q09_q07_evidence_sha256": material["source_evidence_sha256"],
        "q09_q07_lineage_resolution": "q09_pass_execution_anchor", "q09_cell_count": int(loaded["cell_count"]),
        "q09_cell_timeout_sec": farmctl.Q09_AUTOPILOT_CELL_TIMEOUT_SEC,
        "q09_plan_bound_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "scoped_q09_pass_execution_anchor": {"path": str(anchor_path), "sha256": _sha(anchor_path), "source_work_item_id": source},
        "terminal_claimable": True, "timeout_min": max(int(payload.get("timeout_min") or 0), timeout_min),
    })
    payload.pop("q09_autoseal_failure", None); payload.pop("q09_activation_next_action", None)
    payload["q09_dispatch_binding_sha256"] = runner._dispatch_binding_sha256(payload)
    runner.validate_scoped_q09_pass_execution_anchor(payload, manifest, farm_root=ROOT)
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    conn.execute("UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?", (json.dumps(payload, sort_keys=True), now, row["id"]))
    if not news_schema.release_plan_bound_hold(conn, str(row["id"]), now=now):
        raise BinderError("expected activation hold was not released")
    conn.execute("INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,'work_item',?,'q09_pass_anchor_bound',?)",
        (now, row["id"], json.dumps({"task_id": TASK_ID, "plan_path": str(plan_path), "plan_file_sha256": plan_file_sha}, sort_keys=True)))
    return {"work_item_id": row["id"], "source_work_item_id": source, "plan_path": str(plan_path),
        "plan_file_sha256": plan_file_sha, "cell_count": int(loaded["cell_count"]), "hold_released": True}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    if args.limit <= 0:
        parser.error("--limit must be positive")
    with farmctl.connect(ROOT) as conn:
        findings = collect(conn)
        applied = []
        if args.apply:
            for finding in [item for item in findings if item["action"] == "BIND_Q09_PASS_ANCHOR"][: args.limit]:
                conn.execute("BEGIN IMMEDIATE")
                try:
                    row = conn.execute("SELECT * FROM work_items WHERE id=?", (finding["work_item_id"],)).fetchone()
                    applied.append(apply_one(conn, row)); conn.commit()
                except Exception:
                    conn.rollback(); raise
    result = {"schema": "qm.q09-pass-anchor-binder/v1", "mode": "apply" if args.apply else "plan",
        "counts": {"total": len(findings), "ready": sum(x["action"] != "HOLD" for x in findings),
                   "held": sum(x["action"] == "HOLD" for x in findings), "applied": len(applied)},
        "findings": findings, "applied": applied}
    text = json.dumps(result, indent=2) + "\n"
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True); args.receipt.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
