#!/usr/bin/env python3
"""Exact worker-bound Q01 recovery for router task 0666e8f0.

The active Custom-history contract deliberately refuses direct ``run_smoke``
invocations on T1-T10.  This utility appends three bounded Q01 work items so
the resident worker owns claim, archive privatization, terminal reservation,
and evidence publication.  Once a row has terminal evidence, ``--finalize``
authenticates that evidence and appends a build-smoke receipt.  Historical
build tasks and work items are never updated by this utility.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    import farmctl
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm import farmctl


ROUTER_TASK_ID = "0666e8f0-fe8d-4c25-ac8b-21c9a7d9bac9"
CONTRACT = "qm.q01.worker_bound_basket_smoke.v1"
FROM_DATE = "2024.01.01"
TO_DATE = "2024.12.31"
Q01_MIN_TRADES = 1


class RecoveryError(RuntimeError):
    """The exact recovery contract cannot be proved."""


@dataclass(frozen=True)
class Target:
    ea_id: str
    ea_label: str
    logical_symbol: str
    review_task_id: str
    setfile_name: str


TARGETS = (
    Target(
        "QM5_12512",
        "QM5_12512_bt-pairs-thresh",
        "QM5_12512_FX_PAIRS_THRESHOLD_H1",
        "714c3601-0372-4323-aadc-d42bdde28cd3",
        "QM5_12512_bt-pairs-thresh_QM5_12512_FX_PAIRS_THRESHOLD_H1_H1_backtest.set",
    ),
    Target(
        "QM5_10050",
        "QM5_10050_ff-corr-triad-h1",
        "QM5_10050_CORR_TRIAD_H1",
        "9212d4bd-57e6-4676-b68e-0a625a94f0d0",
        "QM5_10050_ff-corr-triad-h1_QM5_10050_CORR_TRIAD_H1_H1_backtest.set",
    ),
    Target(
        "QM5_12507",
        "QM5_12507_pair-coint-z",
        "QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1",
        "c85bc9b3-d5c5-46fb-ba5a-0ba8ccd01630",
        "QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set",
    ),
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _work_item_id(target: Target) -> str:
    return str(
        uuid.uuid5(
            uuid.NAMESPACE_URL,
            f"qm:q01-basket-smoke:{ROUTER_TASK_ID}:{target.ea_id}:{target.logical_symbol}",
        )
    )


def _receipt_task_id(work_item_id: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"qm:q01-build-smoke-receipt:{work_item_id}"))


def _json_object(raw: Any, *, role: str) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except json.JSONDecodeError as exc:
        raise RecoveryError(f"{role} is not valid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise RecoveryError(f"{role} must be a JSON object")
    return value


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith((";", "#")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip().upper()] = value.split("||", 1)[0].strip()
    return values


def _review_is_approved(conn: sqlite3.Connection, target: Target) -> None:
    row = conn.execute(
        "SELECT kind,status,payload_json FROM tasks WHERE id=?",
        (target.review_task_id,),
    ).fetchone()
    if row is None:
        raise RecoveryError(f"review task missing for {target.ea_id}: {target.review_task_id}")
    payload = _json_object(row["payload_json"], role=f"review {target.review_task_id}")
    verdict = payload.get("verdict") if isinstance(payload.get("verdict"), dict) else {}
    if row["kind"] != "ea_review" or verdict.get("verdict") != "APPROVE_FOR_BACKTEST":
        raise RecoveryError(
            f"review task is not APPROVE_FOR_BACKTEST for {target.ea_id}: "
            f"kind={row['kind']} verdict={verdict.get('verdict')}"
        )
    if str(payload.get("ea_id") or "") != target.ea_id:
        raise RecoveryError(f"review task EA mismatch for {target.ea_id}")


def _target_payload(
    conn: sqlite3.Connection,
    repo_root: Path,
    target: Target,
) -> tuple[dict[str, Any], Path]:
    _review_is_approved(conn, target)
    ea_dir = repo_root / "framework" / "EAs" / target.ea_label
    manifest_path = ea_dir / "basket_manifest.json"
    setfile_path = ea_dir / "sets" / target.setfile_name
    mq5_path = ea_dir / f"{target.ea_label}.mq5"
    ex5_path = ea_dir / f"{target.ea_label}.ex5"
    for role, path in (
        ("basket manifest", manifest_path),
        ("logical setfile", setfile_path),
        ("MQ5", mq5_path),
        ("EX5", ex5_path),
    ):
        if not path.is_file():
            raise RecoveryError(f"{target.ea_id} {role} missing: {path}")

    manifest = _json_object(
        manifest_path.read_text(encoding="utf-8-sig"),
        role=f"{target.ea_id} basket manifest",
    )
    if str(manifest.get("logical_symbol") or "") != target.logical_symbol:
        raise RecoveryError(f"{target.ea_id} logical symbol drift")
    host_symbol = str(manifest.get("host_symbol") or "").strip().upper()
    host_timeframe = str(manifest.get("host_timeframe") or "").strip().upper()
    members = [str(value).strip().upper() for value in manifest.get("basket_symbols") or []]
    if not host_symbol.endswith(".DWX") or not host_timeframe or host_symbol not in members:
        raise RecoveryError(f"{target.ea_id} invalid basket host declaration")
    if len(members) < 2 or len(members) != len(set(members)):
        raise RecoveryError(f"{target.ea_id} invalid basket member declaration")

    set_values = _set_values(setfile_path)
    try:
        risk_fixed = float(set_values.get("RISK_FIXED", ""))
        risk_percent = float(set_values.get("RISK_PERCENT", ""))
    except ValueError as exc:
        raise RecoveryError(f"{target.ea_id} risk values are not numeric") from exc
    if risk_fixed <= 0 or risk_percent != 0:
        raise RecoveryError(
            f"{target.ea_id} setfile violates fixed-risk contract: "
            f"RISK_FIXED={risk_fixed} RISK_PERCENT={risk_percent}"
        )

    payload: dict[str, Any] = {
        "basket_symbol_count": len(members),
        "basket_symbols": members,
        "expected_current_ex5_sha256": _sha256(ex5_path),
        "expected_ex5_sha256": _sha256(ex5_path),
        "expected_mq5_sha256": _sha256(mq5_path),
        "expected_setfile_sha256": _sha256(setfile_path),
        "from_date": FROM_DATE,
        "host_symbol": host_symbol,
        "host_timeframe": host_timeframe,
        "logical_symbol": target.logical_symbol,
        "portfolio_scope": "basket",
        "priority_reason": "router_authorized_q01_smoke_recovery",
        "priority_track": True,
        "q01_min_trades": Q01_MIN_TRADES,
        "q01_smoke_contract": CONTRACT,
        "review_task_id": target.review_task_id,
        "router_task_id": ROUTER_TASK_ID,
        "smoke_mode": True,
        "to_date": TO_DATE,
    }
    if manifest.get("tester_currency"):
        payload["tester_currency"] = str(manifest["tester_currency"]).strip().upper()
    if manifest.get("tester_deposit"):
        payload["tester_deposit"] = int(manifest["tester_deposit"])
    return payload, setfile_path.resolve()


def inspect(
    root: Path,
    repo_root: Path,
    targets: Iterable[Target] = TARGETS,
) -> dict[str, Any]:
    farmctl.init_db(root)
    rows: list[dict[str, Any]] = []
    with farmctl.connect(root) as conn:
        for target in targets:
            payload, setfile = _target_payload(conn, repo_root, target)
            work_item_id = _work_item_id(target)
            existing = conn.execute(
                "SELECT status,verdict,claimed_by,evidence_path,payload_json FROM work_items WHERE id=?",
                (work_item_id,),
            ).fetchone()
            row: dict[str, Any] = {
                "ea_id": target.ea_id,
                "logical_symbol": target.logical_symbol,
                "setfile_path": str(setfile),
                "work_item_id": work_item_id,
                "expected_ex5_sha256": payload["expected_ex5_sha256"],
                "expected_setfile_sha256": payload["expected_setfile_sha256"],
                "status": "NOT_ENQUEUED",
            }
            if existing is not None:
                row.update(
                    status=existing["status"],
                    verdict=existing["verdict"],
                    claimed_by=existing["claimed_by"],
                    evidence_path=existing["evidence_path"],
                )
            receipt = conn.execute(
                "SELECT status,payload_json FROM tasks WHERE id=?",
                (_receipt_task_id(work_item_id),),
            ).fetchone()
            if receipt is not None:
                receipt_payload = _json_object(
                    receipt["payload_json"], role=f"receipt {_receipt_task_id(work_item_id)}"
                )
                codex_result = receipt_payload.get("codex_result") or {}
                row["receipt_task_id"] = _receipt_task_id(work_item_id)
                row["receipt_status"] = receipt["status"]
                row["receipt_smoke_result"] = codex_result.get("smoke_result")
            rows.append(row)
    return {"contract": CONTRACT, "router_task_id": ROUTER_TASK_ID, "targets": rows}


def apply(
    root: Path,
    repo_root: Path,
    targets: Iterable[Target] = TARGETS,
) -> dict[str, Any]:
    farmctl.init_db(root)
    now = farmctl.utc_now()
    inserted: list[str] = []
    existing_ids: list[str] = []
    with farmctl.connect(root) as conn:
        conn.execute("BEGIN IMMEDIATE")
        for target in targets:
            payload, setfile = _target_payload(conn, repo_root, target)
            work_item_id = _work_item_id(target)
            existing = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
            if existing is not None:
                existing_payload = _json_object(
                    existing["payload_json"], role=f"work item {work_item_id}"
                )
                immutable = {
                    "kind": existing["kind"],
                    "phase": existing["phase"],
                    "ea_id": existing["ea_id"],
                    "symbol": existing["symbol"],
                    "setfile_path": str(existing["setfile_path"]),
                    "contract": existing_payload.get("q01_smoke_contract"),
                    "router_task_id": existing_payload.get("router_task_id"),
                    "expected_ex5_sha256": existing_payload.get("expected_ex5_sha256"),
                    "expected_setfile_sha256": existing_payload.get("expected_setfile_sha256"),
                }
                expected = {
                    "kind": "q01_smoke",
                    "phase": "Q01",
                    "ea_id": target.ea_id,
                    "symbol": target.logical_symbol,
                    "setfile_path": str(setfile),
                    "contract": CONTRACT,
                    "router_task_id": ROUTER_TASK_ID,
                    "expected_ex5_sha256": payload["expected_ex5_sha256"],
                    "expected_setfile_sha256": payload["expected_setfile_sha256"],
                }
                if immutable != expected:
                    raise RecoveryError(
                        f"deterministic work-item collision for {work_item_id}: "
                        f"observed={immutable} expected={expected}"
                    )
                existing_ids.append(work_item_id)
                continue
            conn.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
                    payload_json,created_at,updated_at,gate_contract_version
                ) VALUES(?, 'q01_smoke', 'Q01', ?, ?, ?, 'pending', 0, ?, ?, ?, ?)
                """,
                (
                    work_item_id,
                    target.ea_id,
                    target.logical_symbol,
                    str(setfile),
                    json.dumps(payload, sort_keys=True),
                    now,
                    now,
                    farmctl.ACTIVE_GATE_CONTRACT_VERSION,
                ),
            )
            farmctl.event(
                conn,
                "work_item",
                work_item_id,
                "q01_smoke_recovery_enqueued",
                {
                    "contract": CONTRACT,
                    "ea_id": target.ea_id,
                    "logical_symbol": target.logical_symbol,
                    "router_task_id": ROUTER_TASK_ID,
                },
            )
            inserted.append(work_item_id)
        conn.commit()
    return {
        "applied": True,
        "contract": CONTRACT,
        "inserted_work_item_ids": inserted,
        "existing_work_item_ids": existing_ids,
        "router_task_id": ROUTER_TASK_ID,
    }


def _load_authenticated_summary(row: sqlite3.Row, payload: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    evidence = Path(str(row["evidence_path"] or ""))
    if not evidence.is_file():
        raise RecoveryError(f"Q01 evidence missing for {row['id']}: {evidence}")
    summary = _json_object(
        evidence.read_text(encoding="utf-8-sig"), role=f"Q01 summary {row['id']}"
    )
    if not farmctl._summary_matches_expected_evidence(summary, payload):
        raise RecoveryError(f"Q01 evidence identity mismatch for {row['id']}")
    return evidence, summary


def _q01_outcome(row: sqlite3.Row, payload: dict[str, Any]) -> tuple[str, str, Path, dict[str, Any]]:
    evidence, summary = _load_authenticated_summary(row, payload)
    exact_total_raw = farmctl._summary_exact_total_trades(summary)
    if exact_total_raw is None:
        raise RecoveryError(f"Q01 evidence has no exact trade total for {row['id']}")
    exact_total = int(exact_total_raw)
    reasons = [str(value).upper() for value in summary.get("reason_classes") or []]
    if (
        row["status"] == "done"
        and row["verdict"] == "PASS"
        and summary.get("result") == "PASS"
        and exact_total >= Q01_MIN_TRADES
    ):
        return "passed", "Q01_PASS", evidence, summary
    if exact_total == 0 and (
        row["verdict"] == "ZERO_TRADES" or "MIN_TRADES_NOT_MET" in reasons
    ):
        return "zero_trades", "Q01_ZERO_TRADES", evidence, summary
    if row["verdict"] == "INFRA_FAIL":
        return "framework_error", "Q01_INFRA_FAIL", evidence, summary
    return "failed", f"Q01_{row['verdict'] or 'FAIL'}", evidence, summary


def _write_receipt_file(root: Path, work_item_id: str, receipt: dict[str, Any]) -> Path:
    destination = root / "artifacts" / "q01_smoke" / work_item_id / "q01_receipt.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_name(f".{destination.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, destination)
    return destination


def finalize(
    root: Path,
    repo_root: Path,
    targets: Iterable[Target] = TARGETS,
) -> dict[str, Any]:
    farmctl.init_db(root)
    finalized: list[dict[str, Any]] = []
    waiting: list[dict[str, Any]] = []
    for target in targets:
        work_item_id = _work_item_id(target)
        with farmctl.connect(root) as conn:
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
            if row is None:
                waiting.append({"ea_id": target.ea_id, "reason": "NOT_ENQUEUED"})
                continue
            if row["status"] not in {"done", "failed"}:
                waiting.append(
                    {
                        "ea_id": target.ea_id,
                        "status": row["status"],
                        "claimed_by": row["claimed_by"],
                        "work_item_id": work_item_id,
                    }
                )
                continue
            payload = _json_object(row["payload_json"], role=f"work item {work_item_id}")
            current_payload, current_setfile = _target_payload(conn, repo_root, target)
            for field in (
                "expected_ex5_sha256",
                "expected_mq5_sha256",
                "expected_setfile_sha256",
            ):
                if str(payload.get(field) or "") != str(current_payload.get(field) or ""):
                    raise RecoveryError(f"{target.ea_id} artifact drift after Q01: {field}")
            if str(row["setfile_path"]) != str(current_setfile):
                raise RecoveryError(f"{target.ea_id} setfile path drift after Q01")
            smoke_result, outcome_reason, evidence, summary = _q01_outcome(row, payload)

        receipt_task_id = _receipt_task_id(work_item_id)
        now = farmctl.utc_now()
        receipt = {
            "contract": CONTRACT,
            "created_at_utc": str(row["updated_at"]),
            "ea_id": target.ea_id,
            "expert_sha256": payload["expected_ex5_sha256"],
            "logical_symbol": target.logical_symbol,
            "outcome_reason": outcome_reason,
            "q01_min_trades": Q01_MIN_TRADES,
            "q01_summary_path": str(evidence),
            "q01_summary_sha256": _sha256(evidence),
            "q01_work_item_id": work_item_id,
            "router_task_id": ROUTER_TASK_ID,
            "setfile_sha256": payload["expected_setfile_sha256"],
            "smoke_result": smoke_result,
            "summary_result": summary.get("result"),
            "summary_total_trades": farmctl._summary_exact_total_trades(summary),
        }
        receipt_path = _write_receipt_file(root, work_item_id, receipt)
        task_payload = {
            "build_result_path": str(receipt_path),
            "codex_result": {
                "blocked_reason": "" if smoke_result == "passed" else outcome_reason,
                "ea_id": target.ea_id,
                "q01_smoke_contract": CONTRACT,
                "q01_summary_path": str(evidence),
                "q01_work_item_id": work_item_id,
                "smoke_result": smoke_result,
            },
            "ea_id": target.ea_id,
            "q01_recovery_receipt": receipt,
            "review_task_id": target.review_task_id,
            "router_task_id": ROUTER_TASK_ID,
        }
        task_status = "done" if smoke_result == "passed" else "failed"
        with farmctl.connect(root) as conn:
            conn.execute("BEGIN IMMEDIATE")
            existing = conn.execute("SELECT * FROM tasks WHERE id=?", (receipt_task_id,)).fetchone()
            if existing is not None:
                existing_payload = _json_object(
                    existing["payload_json"], role=f"receipt task {receipt_task_id}"
                )
                prior_receipt = existing_payload.get("q01_recovery_receipt") or {}
                stable_fields = (
                    "contract",
                    "ea_id",
                    "expert_sha256",
                    "logical_symbol",
                    "outcome_reason",
                    "q01_summary_sha256",
                    "q01_work_item_id",
                    "router_task_id",
                    "setfile_sha256",
                    "smoke_result",
                )
                if any(prior_receipt.get(key) != receipt.get(key) for key in stable_fields):
                    raise RecoveryError(f"receipt collision for {receipt_task_id}")
            else:
                conn.execute(
                    """
                    INSERT INTO tasks(
                        id,kind,status,source_id,card_id,payload_json,created_at,updated_at
                    ) VALUES(?, 'build_ea', ?, NULL, ?, ?, ?, ?)
                    """,
                    (
                        receipt_task_id,
                        task_status,
                        target.ea_id,
                        json.dumps(task_payload, sort_keys=True),
                        now,
                        now,
                    ),
                )
                farmctl.event(
                    conn,
                    "task",
                    receipt_task_id,
                    "q01_smoke_receipt_appended",
                    {
                        "contract": CONTRACT,
                        "q01_work_item_id": work_item_id,
                        "smoke_result": smoke_result,
                    },
                )
            conn.commit()
        finalized.append(
            {
                "ea_id": target.ea_id,
                "receipt_path": str(receipt_path),
                "receipt_task_id": receipt_task_id,
                "smoke_result": smoke_result,
                "work_item_id": work_item_id,
            }
        )
    return {
        "contract": CONTRACT,
        "finalized": finalized,
        "router_task_id": ROUTER_TASK_ID,
        "waiting": waiting,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--farm-root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument("--repo-root", type=Path, default=farmctl.REPO_ROOT)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--finalize", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.apply:
            result = apply(args.farm_root, args.repo_root)
        elif args.finalize:
            result = finalize(args.farm_root, args.repo_root)
        else:
            result = inspect(args.farm_root, args.repo_root)
    except (OSError, RecoveryError, sqlite3.Error, ValueError) as exc:
        print(json.dumps({"error": str(exc), "status": "REFUSED"}, sort_keys=True))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
