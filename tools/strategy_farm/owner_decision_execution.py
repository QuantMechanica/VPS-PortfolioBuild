#!/usr/bin/env python3
"""Turn terminal OWNER decision receipts into deterministic Claude tasks.

The receipt is the human authority.  This module never interprets a free-form
note as additional authority: it binds one YES/NO receipt to the corresponding
pre-reviewed execution plan and inserts exactly one ``agent_tasks`` row.  The
normal capability router and Claude scheduled lane own assignment/execution.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import agent_router, farmctl  # noqa: E402
from tools.strategy_farm import owner_decision_store as store  # noqa: E402


CONTRACT_SCHEMA = "qm.owner-decision-execution-contract/v1"
TASK_OPERATION = "owner_decision_execution"
DEFAULT_CONTRACT = Path(__file__).resolve().parent / "config" / "owner_decision_execution.v1.json"
DEFAULT_ROOT = farmctl.DEFAULT_ROOT
CANONICAL_REPO = Path(r"C:\QM\repo")
TERMINAL_CHOICES = frozenset({"YES", "NO"})


class ExecutionContractError(RuntimeError):
    """A receipt or execution plan is missing, ambiguous, or tampered."""


def _canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def load_contract(path: Path = DEFAULT_CONTRACT) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ExecutionContractError(f"execution contract unreadable: {path}: {exc}") from exc
    if not isinstance(payload, dict) or payload.get("schema") != CONTRACT_SCHEMA:
        raise ExecutionContractError("unsupported execution contract schema")
    if payload.get("agent") != "claude" or payload.get("task_type") != "ops_issue":
        raise ExecutionContractError("execution contract must target the governed Claude ops lane")
    capabilities = payload.get("required_capabilities")
    if not isinstance(capabilities, list) or set(capabilities) != {"code", "ops", "summary"}:
        raise ExecutionContractError(
            "execution contract must bind the exact Claude-only code+ops+summary capability set"
        )
    forbidden = payload.get("global_forbidden_actions")
    if not isinstance(forbidden, list) or not forbidden:
        raise ExecutionContractError("execution contract has no global forbidden actions")
    decisions = payload.get("decisions")
    if not isinstance(decisions, list):
        raise ExecutionContractError("execution decisions must be a list")
    seen: set[str] = set()
    for decision in decisions:
        if not isinstance(decision, dict):
            raise ExecutionContractError("execution decision must be an object")
        decision_id = str(decision.get("id") or "")
        if not decision_id or decision_id in seen:
            raise ExecutionContractError(f"blank or duplicate execution decision: {decision_id!r}")
        seen.add(decision_id)
        if not str(decision.get("todo_id") or "").startswith("QM-TODO-"):
            raise ExecutionContractError(f"execution decision {decision_id} has no QM-TODO id")
        choices = decision.get("choices")
        if not isinstance(choices, dict) or set(choices) != TERMINAL_CHOICES:
            raise ExecutionContractError(f"execution decision {decision_id} must map YES and NO")
        for choice, plan in choices.items():
            if not isinstance(plan, dict):
                raise ExecutionContractError(f"{decision_id}/{choice} plan must be an object")
            for key in ("mode", "objective", "allowed_actions", "acceptance"):
                if not plan.get(key):
                    raise ExecutionContractError(f"{decision_id}/{choice} missing {key}")
    return payload


def contract_sha256(contract: Mapping[str, Any]) -> str:
    return store.sha256_bytes(store.canonical_bytes(contract))


def _decision_plan(contract: Mapping[str, Any], decision_id: str, choice: str) -> tuple[dict, dict]:
    row = next(
        (item for item in contract.get("decisions") or [] if item.get("id") == decision_id),
        None,
    )
    if row is None:
        raise ExecutionContractError(f"no execution plan for {decision_id}")
    plan = (row.get("choices") or {}).get(choice)
    if not isinstance(plan, dict):
        raise ExecutionContractError(f"no execution plan for {decision_id}/{choice}")
    return dict(row), dict(plan)


def plan_summary(decision_id: str, contract_path: Path = DEFAULT_CONTRACT) -> dict[str, Any]:
    try:
        contract = load_contract(contract_path)
        row = next(
            (item for item in contract["decisions"] if item["id"] == decision_id),
            None,
        )
        if row is None:
            return {"ready": False, "agent": "claude", "reason": "execution_plan_missing"}
        return {
            "ready": True,
            "agent": "claude",
            "task_type": contract["task_type"],
            "todo_id": row["todo_id"],
            "yes_mode": row["choices"]["YES"]["mode"],
            "no_mode": row["choices"]["NO"]["mode"],
            "boundary": "DECISION_SCOPED_ROUTER_TASK",
        }
    except ExecutionContractError as exc:
        return {"ready": False, "agent": "claude", "reason": str(exc)}


def _validate_receipt(receipt: Mapping[str, Any]) -> None:
    if receipt.get("schema") not in store.SUPPORTED_RECEIPT_SCHEMAS:
        raise ExecutionContractError("unsupported OWNER receipt schema")
    supplied_hash = str(receipt.get("receipt_sha256") or "")
    unhashed = {key: value for key, value in receipt.items() if key != "receipt_sha256"}
    observed_hash = store.sha256_bytes(store.canonical_bytes(unhashed))
    if supplied_hash != observed_hash:
        raise ExecutionContractError("OWNER receipt hash mismatch")
    if receipt.get("decided_by") != "OWNER":
        raise ExecutionContractError("execution receipt was not decided by OWNER")
    choice = str(receipt.get("decision") or "")
    if choice not in TERMINAL_CHOICES:
        raise ExecutionContractError("only terminal YES/NO receipts may create work")
    if receipt.get("execution_authorized") is not True:
        raise ExecutionContractError("receipt does not authorize decision-scoped execution")
    if receipt.get("execution_handoff_authorized") is not True:
        raise ExecutionContractError("receipt does not authorize an agent handoff")
    if receipt.get("execution_boundary") != "DECISION_SCOPED_ROUTER_TASK":
        raise ExecutionContractError("receipt execution boundary is not router-scoped")
    if receipt.get("live_execution_authorized") is not False:
        raise ExecutionContractError("receipt must explicitly deny live execution")
    expected_task = store.execution_task_id(str(receipt.get("receipt_id") or ""))
    if receipt.get("execution_task_id") != expected_task:
        raise ExecutionContractError("receipt execution task identity mismatch")


def _feed_item(feed: Mapping[str, Any], decision_id: str) -> dict[str, Any]:
    item = next((row for row in feed.get("items") or [] if row.get("id") == decision_id), None)
    if not isinstance(item, dict):
        raise ExecutionContractError(f"decision feed item missing: {decision_id}")
    return dict(item)


def _validate_card_binding(receipt: Mapping[str, Any], item: Mapping[str, Any]) -> str:
    """Refuse recovery if the OWNER-visible card changed after the receipt."""

    observed_card_hash = store.decision_card_sha256(item)
    if receipt.get("decision_card_sha256") != observed_card_hash:
        raise ExecutionContractError("OWNER decision card changed after receipt")
    choice = str(receipt["decision"])
    observed_effect = str(item["yes_effect"] if choice == "YES" else item["no_effect"])
    if receipt.get("selected_effect") != observed_effect:
        raise ExecutionContractError("OWNER-selected effect changed after receipt")
    if receipt.get("question") != item.get("question"):
        raise ExecutionContractError("OWNER decision question changed after receipt")
    if receipt.get("recommendation") != item.get("recommendation"):
        raise ExecutionContractError("OWNER decision recommendation changed after receipt")
    return observed_effect


def _artifact_path(receipt: Mapping[str, Any]) -> str:
    day = str(receipt["decided_at_utc"])[:10]
    slug = str(receipt["decision_id"]).lower().replace("owner-dec-", "").replace("_", "-")
    short = str(receipt["receipt_id"]).split("-", 1)[0]
    return str(CANONICAL_REPO / "docs" / "ops" / "evidence" / f"{day}_{slug}_{short}_execution.md")


def build_task(
    receipt: Mapping[str, Any],
    *,
    feed: Mapping[str, Any],
    contract: Mapping[str, Any],
) -> dict[str, Any]:
    _validate_receipt(receipt)
    decision_id = str(receipt["decision_id"])
    choice = str(receipt["decision"])
    item = _feed_item(feed, decision_id)
    contract_row, plan = _decision_plan(contract, decision_id, choice)
    selected_effect = _validate_card_binding(receipt, item)
    expected_artifact = _artifact_path(receipt)
    payload = {
        "title": f"Execute OWNER decision {decision_id} = {choice}",
        "operation": TASK_OPERATION,
        "qm_todo_id": contract_row["todo_id"],
        "target_agent_profile": "claude",
        "owner_decision": {
            "decision_id": decision_id,
            "choice": choice,
            "question": receipt["question"],
            "recommendation_at_decision": receipt["recommendation"],
            "selected_effect": selected_effect,
            "owner_notes": receipt.get("notes") or "",
            "receipt_id": receipt["receipt_id"],
            "receipt_sha256": receipt["receipt_sha256"],
            "decided_at_utc": receipt["decided_at_utc"],
        },
        "implementation_mode": plan["mode"],
        "objective": plan["objective"],
        "allowed_actions": list(plan["allowed_actions"]),
        "forbidden_actions": list(contract["global_forbidden_actions"]),
        "acceptance": list(plan["acceptance"]),
        "evidence_inputs": list(item.get("evidence") or []),
        "expected_artifact": expected_artifact,
        "execution_contract_schema": contract["schema"],
        "execution_contract_sha256": contract_sha256(contract),
        "authority": {
            "scope": "selected_effect_only",
            "execution_authorized": True,
            "live_execution_authorized": False,
            "factory_pause_authorized": False,
            "autotrading_authorized": False,
            "deployment_authorized": False,
            "notes_may_expand_scope": False,
        },
        "review_required": "INDEPENDENT_ORCHESTRATOR_CLOSEOUT",
        "source": "Mission Control OWNER receipt",
    }
    return {
        "task_id": receipt["execution_task_id"],
        "task_type": contract["task_type"],
        "state": "TODO",
        "priority": int(contract_row.get("priority") or contract["default_priority"]),
        "required_capabilities": list(contract["required_capabilities"]),
        "required_skills": list(contract.get("required_skills") or []),
        "budget_class": contract["budget_class"],
        "payload": payload,
        "expected_artifact": expected_artifact,
    }


def _require_canonical_live_writer(root: Path) -> None:
    if Path(root).resolve() != Path(DEFAULT_ROOT).resolve():
        return
    checkout = Path(__file__).resolve().parents[2]
    if checkout != CANONICAL_REPO:
        raise ExecutionContractError(
            f"live handoff requires canonical checkout {CANONICAL_REPO}, got {checkout}"
        )


def handoff_receipt(
    receipt: Mapping[str, Any],
    *,
    root: Path = DEFAULT_ROOT,
    feed_path: Path = store.DEFAULT_FEED,
    contract_path: Path = DEFAULT_CONTRACT,
    apply: bool = True,
) -> dict[str, Any]:
    choice = str(receipt.get("decision") or "")
    if choice == "DEFERRED":
        return {"state": "DEFERRED_NO_HANDOFF", "created": False, "task_id": None}
    feed = store.load_feed(feed_path)
    contract = load_contract(contract_path)
    task = build_task(receipt, feed=feed, contract=contract)
    if not apply:
        return {"state": "READY", "created": False, **task}
    _require_canonical_live_writer(root)
    now = farmctl.utc_now()
    conn = agent_router.connect(root)
    try:
        conn.execute("BEGIN IMMEDIATE")
        existing = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task["task_id"],)).fetchone()
        if existing is not None:
            existing_payload = json.loads(existing["payload_json"] or "{}")
            if (
                existing_payload.get("operation") != TASK_OPERATION
                or (existing_payload.get("owner_decision") or {}).get("receipt_sha256")
                != receipt["receipt_sha256"]
            ):
                raise ExecutionContractError("deterministic execution task id collision")
            conn.commit()
            return {
                "state": "EXISTING",
                "created": False,
                "task_id": task["task_id"],
                "task_state": existing["state"],
                "assigned_agent": existing["assigned_agent"],
            }
        conn.execute(
            """
            INSERT INTO agent_tasks(
                id, task_type, state, priority, required_capabilities_json,
                required_skills_json, assigned_agent, budget_class, parent_id,
                artifact_path, verdict, payload_json, created_at, updated_at
            ) VALUES (?, ?, 'TODO', ?, ?, ?, NULL, ?, NULL, NULL, NULL, ?, ?, ?)
            """,
            (
                task["task_id"], task["task_type"], task["priority"],
                _canonical_json(task["required_capabilities"]),
                _canonical_json(task["required_skills"]), task["budget_class"],
                _canonical_json(task["payload"]), now, now,
            ),
        )
        try:
            farmctl.event(
                conn,
                "owner_decision_execution",
                str(receipt["decision_id"]),
                "execution_task_created",
                {
                    "task_id": task["task_id"],
                    "receipt_id": receipt["receipt_id"],
                    "receipt_sha256": receipt["receipt_sha256"],
                    "choice": choice,
                    "agent": "claude",
                },
            )
        except Exception:
            pass
        conn.commit()
    finally:
        conn.close()
    return {
        "state": "QUEUED",
        "created": True,
        "task_id": task["task_id"],
        "task_state": "TODO",
        "assigned_agent": None,
        "expected_artifact": task["expected_artifact"],
    }


def reconcile_receipts(
    *,
    root: Path = DEFAULT_ROOT,
    feed_path: Path = store.DEFAULT_FEED,
    receipts_path: Path = store.DEFAULT_RECEIPTS,
    contract_path: Path = DEFAULT_CONTRACT,
    apply: bool = False,
) -> dict[str, Any]:
    receipts = store.load_receipts(receipts_path)
    results: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    for receipt in receipts:
        if receipt.get("decision") == "DEFERRED":
            continue
        if receipt.get("execution_handoff_authorized") is not True:
            continue
        try:
            result = handoff_receipt(
                receipt,
                root=root,
                feed_path=feed_path,
                contract_path=contract_path,
                apply=apply,
            )
            results.append({"decision_id": receipt["decision_id"], **result})
        except (ExecutionContractError, store.DecisionStoreError) as exc:
            errors.append({"receipt_id": str(receipt.get("receipt_id") or ""), "error": str(exc)})
    return {
        "schema": "qm.owner-decision-execution-reconcile/v1",
        "apply": apply,
        "receipt_count": len(receipts),
        "eligible_count": len(results) + len(errors),
        "results": results,
        "errors": errors,
        "ok": not errors,
    }


def _task_projection(row: Mapping[str, Any] | None, task_id: str) -> dict[str, Any]:
    if row is None:
        return {
            "task_id": task_id,
            "status": "HANDOFF_PENDING",
            "task_state": None,
            "assigned_agent": None,
            "artifact_path": None,
            "verdict": None,
            "updated_at": None,
            "complete": False,
        }
    state = str(row.get("state") or "UNKNOWN")
    status = {
        "BACKLOG": "QUEUED", "TODO": "QUEUED", "IN_PROGRESS": "RUNNING",
        "REVIEW": "AWAITING_REVIEW", "APPROVED": "ACCEPTED",
        "PIPELINE": "ACCEPTED", "PASSED": "COMPLETE", "FAILED": "FAILED",
        "RECYCLE": "RECYCLE", "OPS_FIX_REQUIRED": "OPS_FIX_REQUIRED",
        "BLOCKED": "BLOCKED", "SELF_LEARNING": "RUNNING",
    }.get(state, "UNKNOWN")
    return {
        "task_id": task_id,
        "status": status,
        "task_state": state,
        "assigned_agent": row.get("assigned_agent"),
        "artifact_path": row.get("artifact_path"),
        "verdict": row.get("verdict"),
        "updated_at": row.get("updated_at"),
        "complete": state == "PASSED",
    }


def project_feed_executions(con: sqlite3.Connection, feed: Mapping[str, Any]) -> list[dict[str, Any]]:
    decided = [
        item for item in feed.get("items") or []
        if item.get("status") == "DECIDED" and item.get("last_receipt_id")
    ]
    if not decided:
        return []
    columns = {
        str(row[1] if not isinstance(row, sqlite3.Row) else row["name"])
        for row in con.execute("PRAGMA table_info(agent_tasks)").fetchall()
    }
    desired = [
        name for name in (
            "id", "state", "assigned_agent", "artifact_path", "verdict", "updated_at"
        ) if name in columns
    ]
    rows_by_id: dict[str, dict[str, Any]] = {}
    if "id" in desired and "state" in desired:
        ids = [store.execution_task_id(str(item["last_receipt_id"])) for item in decided]
        placeholders = ",".join("?" for _ in ids)
        try:
            for row in con.execute(
                f"SELECT {','.join(desired)} FROM agent_tasks WHERE id IN ({placeholders})",
                ids,
            ).fetchall():
                rows_by_id[str(row["id"])] = {name: row[name] for name in desired}
        except sqlite3.Error:
            rows_by_id = {}
    output: list[dict[str, Any]] = []
    for item in decided:
        task_id = store.execution_task_id(str(item["last_receipt_id"]))
        projection = _task_projection(rows_by_id.get(task_id), task_id)
        output.append(
            {
                "decision_id": item["id"],
                "decision": item.get("last_decision"),
                "decided_at_utc": item.get("last_decision_at_utc"),
                "receipt_id": item.get("last_receipt_id"),
                "question": item.get("question"),
                **projection,
            }
        )
    return sorted(output, key=lambda row: str(row.get("decided_at_utc") or ""), reverse=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--feed", type=Path, default=store.DEFAULT_FEED)
    parser.add_argument("--receipts", type=Path, default=store.DEFAULT_RECEIPTS)
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--apply", action="store_true", help="Insert missing tasks; default is dry-run")
    args = parser.parse_args(argv)
    result = reconcile_receipts(
        root=args.root,
        feed_path=args.feed,
        receipts_path=args.receipts,
        contract_path=args.contract,
        apply=args.apply,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
