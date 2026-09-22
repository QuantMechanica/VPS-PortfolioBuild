#!/usr/bin/env python3
"""Append-only requalification for a versioned Q09 calendar successor.

The tool consumes the approved DST impact census and changes only the calendar
bundle in authenticated Q09 plans. Historical rows, verdicts, and evidence are
never updated. Exact replays become runnable; rows with missing or drifted
inputs are inserted under a non-auto-sealable hold.
"""

from __future__ import annotations

import argparse
import copy
import csv
import hashlib
import json
import os
import re
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    import farmctl
    import q09_calendar_pin as calendar_pin
    import q09_news_calendar as calendar_bundle
    import q09_news_contract as contract
    import q09_news_runner as q09
except ModuleNotFoundError:
    from tools.strategy_farm import farmctl
    from tools.strategy_farm import q09_calendar_pin as calendar_pin
    from tools.strategy_farm import q09_news_calendar as calendar_bundle
    from tools.strategy_farm import q09_news_contract as contract
    from tools.strategy_farm import q09_news_runner as q09


TASK_ID = "f50a0bba-a85d-4203-a18b-ad3b198f5ee9"
SOURCE_AUDIT_TASK_ID = "a36a5983-8cfc-4528-8277-8b5d21787f82"
SOURCE_IMPACT_SHA256 = "a6fa51c1d756b663c931e13be60a3b25880f7f0e8bae806308da5a2c57c34719"
SOURCE_CONTENT_SHA256 = calendar_pin.PARENT_CONTENT_SHA256
REQUIRED_ACTION = "APPEND_ONLY_REMEASUREMENT_AND_READJUDICATION"
PLAN_SCHEMA = "qm.q09-calendar-requalification-plan/v1"
RECEIPT_SCHEMA = "qm.q09-calendar-requalification-apply/v1"
STATUS_SCHEMA = "qm.q09-calendar-requalification-status/v1"
REQUAL_CONTRACT = "qm.q09-calendar-requalification/v1"
BLOCK_HOLD_CODE = "NEWS_ARCHIVE_REQUALIFICATION_BLOCKED"
BLOCK_HOLD_REASON = (
    "append-only calendar requalification cannot run until the exact historical "
    "input chain is restored or independently requalified"
)
CAMPAIGN_ID = "news-archive-correction-requalification-v1"
SUCCESSOR_NAMESPACE = uuid.uuid5(
    uuid.NAMESPACE_URL, "https://quantmechanica.local/q09-calendar-requalification"
)

DEFAULT_IMPACT_CSV = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-09-21_news_archive_dst_audit"
    r"\task_a36a5983-8cfc-4528-8277-8b5d21787f82\sealed_verdict_impact.csv"
)
DEFAULT_FARM_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_ARTIFACT_ROOT = Path(
    r"D:\QM\strategy_farm\artifacts\news_calendar_requalification"
)
ROSTER_PRIORITY = (
    "QM5_13213", "QM5_10706", "QM5_10700", "QM5_11422", "QM5_10403", "QM5_41219",
)
FOLLOWUP_PRIORITY = ("QM5_11708", "QM5_12710", "QM5_20266")
TARGET_REPLACEMENTS = {"QM5_12710": "QM5_41488", "QM5_20266": "QM5_41489"}


class RequalificationError(RuntimeError):
    """The governed requalification contract cannot be satisfied."""


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _json_bytes(value: Mapping[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(data)
    os.replace(temporary, path)


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    _atomic_write(path, _json_bytes(value))


def _read_json(path: Path, role: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RequalificationError(f"{role} is unreadable: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RequalificationError(f"{role} must be a JSON object: {path}")
    return value


def _read_only_connection(farm_root: Path) -> sqlite3.Connection:
    database = farmctl.db_path(farm_root).resolve()
    if not database.is_file():
        raise RequalificationError(f"farm database missing: {database}")
    connection = sqlite3.connect(
        f"file:{database.as_posix()}?mode=ro", uri=True, timeout=30.0
    )
    connection.row_factory = sqlite3.Row
    return connection


def _require_task_scoped_dir(path: Path, task_id: str) -> Path:
    resolved = path.resolve()
    marker = f"task_{task_id}".casefold()
    if marker not in {part.casefold() for part in resolved.parts}:
        raise RequalificationError(
            f"output directory must contain an exact task_{task_id} component: {resolved}"
        )
    return resolved


def _ea_number(ea_id: str) -> int:
    match = re.fullmatch(r"QM5_(\d+)", str(ea_id or "").strip().upper())
    return int(match.group(1)) if match else 10**9


def _priority_key(row: Mapping[str, str]) -> tuple[Any, ...]:
    ea_id = str(row["ea_id"])
    if ea_id in ROSTER_PRIORITY:
        group, ea_rank = 0, ROSTER_PRIORITY.index(ea_id)
    elif ea_id == FOLLOWUP_PRIORITY[0]:
        group, ea_rank = 1, 0
    elif ea_id in FOLLOWUP_PRIORITY[1:]:
        group, ea_rank = 2, FOLLOWUP_PRIORITY.index(ea_id) - 1
    else:
        group = 3 if str(row.get("verdict")) == "CONFIG_LOCKED" else 4
        ea_rank = _ea_number(ea_id)
    phase_rank = 0 if str(row.get("phase")) == "Q09_NEWS" else 1
    return group, ea_rank, phase_rank, str(row.get("symbol")), str(row["work_item_id"])


def successor_work_item_id(
    *, task_id: str, source_work_item_id: str, target_ea_id: str
) -> str:
    material = (
        f"{task_id}|{source_work_item_id}|{target_ea_id}|"
        f"{calendar_pin.BUNDLE_ID}|{calendar_pin.CONTENT_SHA256}"
    )
    return str(uuid.uuid5(SUCCESSOR_NAMESPACE, material))


def _stable_plan_hash(entries: Sequence[Mapping[str, Any]], impact_sha256: str) -> str:
    material = {
        "schema_version": PLAN_SCHEMA,
        "task_id": TASK_ID,
        "source_audit_task_id": SOURCE_AUDIT_TASK_ID,
        "impact_sha256": impact_sha256,
        "calendar_pin": calendar_pin.payload_binding(),
        "entries": list(entries),
    }
    return hashlib.sha256(contract.canonical_json_bytes(material)).hexdigest()


def _source_contract(
    source: sqlite3.Row, payload: Mapping[str, Any]
) -> tuple[dict[str, Any], dict[str, Any], Path, str]:
    raw_path = str(payload.get("q09_run_plan_path") or "").strip()
    raw_hash = str(payload.get("q09_run_plan_file_sha256") or "").strip().lower()
    if not raw_path:
        raise RequalificationError("SOURCE_RUN_PLAN_PATH_MISSING")
    path = Path(raw_path).resolve()
    if not path.is_file():
        raise RequalificationError(f"SOURCE_RUN_PLAN_MISSING:{path}")
    if not re.fullmatch(r"[0-9a-f]{64}", raw_hash):
        raise RequalificationError("SOURCE_RUN_PLAN_FILE_HASH_MISSING")
    try:
        plan, manifest = q09.load_authenticated_plan(
            path, expected_file_sha256=raw_hash
        )
    except (OSError, q09.RunnerError, ValueError) as exc:
        raise RequalificationError(f"SOURCE_PLAN_AUTHENTICATION_FAILED:{exc}") from exc
    if str(plan.get("work_item_id")) != str(source["id"]):
        raise RequalificationError("SOURCE_PLAN_WORK_ITEM_ID_MISMATCH")
    calendar = manifest.get("calendar_bundle") or {}
    if str(calendar.get("content_sha256") or "").lower() != SOURCE_CONTENT_SHA256:
        raise RequalificationError("SOURCE_PLAN_NOT_BOUND_TO_APPROVED_PARENT")
    return plan, manifest, path, raw_hash


def _q08_dependency(
    connection: sqlite3.Connection, source_work_item_id: str
) -> sqlite3.Row | None:
    return connection.execute(
        """
        SELECT d.parent_work_item_id,d.parent_evidence_sha256,p.*
        FROM work_item_dependencies d
        JOIN work_items p ON p.id=d.parent_work_item_id
        WHERE d.child_work_item_id=? AND d.dependency_role='Q08_INPUT'
        """,
        (source_work_item_id,),
    ).fetchone()


def _replacement_chain_fact(
    connection: sqlite3.Connection, target_ea_id: str, symbol: str
) -> dict[str, Any]:
    row = connection.execute(
        """
        SELECT id,status,verdict,evidence_path,updated_at FROM work_items
        WHERE ea_id=? AND symbol=? AND phase='Q08'
        ORDER BY updated_at DESC,id DESC LIMIT 1
        """,
        (target_ea_id, symbol),
    ).fetchone()
    return dict(row) if row is not None else {
        "id": None, "status": None, "verdict": None,
        "evidence_path": None, "updated_at": None,
    }


def _replacement_execution_source(
    connection: sqlite3.Connection, target_ea_id: str, symbol: str
) -> tuple[sqlite3.Row, dict[str, Any], dict[str, Any], dict[str, Any], sqlite3.Row] | None:
    candidates = connection.execute(
        """
        SELECT * FROM work_items
        WHERE ea_id=? AND symbol=? AND phase=?
        ORDER BY CASE status WHEN 'pending' THEN 0 WHEN 'done' THEN 1 ELSE 2 END,
                 updated_at DESC,id DESC
        """,
        (target_ea_id, symbol, q09.NEWS_PHASE),
    ).fetchall()
    for candidate in candidates:
        try:
            payload = json.loads(str(candidate["payload_json"] or "{}"))
            if not isinstance(payload, dict) or payload.get("diagnostic_non_admission") is True:
                continue
            plan, manifest, _, _ = _source_contract(candidate, payload)
            dependency = _q08_dependency(connection, str(candidate["id"]))
            if (
                dependency is None
                or dependency["phase"] != "Q08"
                or dependency["status"] != "done"
                or dependency["verdict"] not in {"PASS", "FAIL_SOFT"}
            ):
                continue
            return candidate, payload, plan, manifest, dependency
        except (RequalificationError, json.JSONDecodeError):
            continue
    return None


def build_plan(
    *, farm_root: Path, impact_csv: Path, task_id: str = TASK_ID
) -> dict[str, Any]:
    if task_id != TASK_ID:
        raise RequalificationError(f"this tool is pinned to task {TASK_ID}")
    impact_csv = impact_csv.resolve()
    if not impact_csv.is_file():
        raise RequalificationError(f"impact census missing: {impact_csv}")
    impact_sha256 = _sha256_file(impact_csv)
    if impact_sha256 != SOURCE_IMPACT_SHA256:
        raise RequalificationError(
            f"impact census hash mismatch: {impact_sha256} != {SOURCE_IMPACT_SHA256}"
        )
    verified = calendar_bundle.verify_bundle(calendar_pin.MANIFEST_PATH.parent)
    if (
        verified["bundle_id"] != calendar_pin.BUNDLE_ID
        or verified["content_sha256"] != calendar_pin.CONTENT_SHA256
        or verified["manifest_sha256"] != calendar_pin.MANIFEST_SHA256
        or verified.get("parent_bundle_id") != calendar_pin.PARENT_BUNDLE_ID
    ):
        raise RequalificationError("successor calendar contradicts the compiled pin")
    with impact_csv.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = [
            row for row in csv.DictReader(handle)
            if row.get("required_action") == REQUIRED_ACTION
        ]
    if len(rows) != 128:
        raise RequalificationError(f"expected 128 directly exposed rows, found {len(rows)}")
    rows.sort(key=_priority_key)

    entries: list[dict[str, Any]] = []
    with _read_only_connection(farm_root) as connection:
        for priority_rank, audit in enumerate(rows, start=1):
            source_id = str(audit["work_item_id"])
            source = connection.execute(
                "SELECT * FROM work_items WHERE id=?", (source_id,)
            ).fetchone()
            if source is None:
                raise RequalificationError(f"audited source row disappeared: {source_id}")
            if (
                source["status"] != "done"
                or str(source["phase"]) != str(audit["phase"])
                or str(source["ea_id"]) != str(audit["ea_id"])
                or str(source["symbol"]) != str(audit["symbol"])
                or str(source["verdict"]) != str(audit["verdict"])
            ):
                raise RequalificationError(f"audited source row changed: {source_id}")
            try:
                payload = json.loads(str(source["payload_json"] or "{}"))
            except json.JSONDecodeError as exc:
                raise RequalificationError(f"source payload invalid: {source_id}") from exc
            if not isinstance(payload, dict):
                raise RequalificationError(f"source payload not an object: {source_id}")
            target_ea_id = TARGET_REPLACEMENTS.get(
                str(source["ea_id"]), str(source["ea_id"])
            )
            successor_id = successor_work_item_id(
                task_id=task_id,
                source_work_item_id=source_id,
                target_ea_id=target_ea_id,
            )
            entry: dict[str, Any] = {
                "priority_rank": priority_rank,
                "source_work_item_id": source_id,
                "source_phase": str(source["phase"]),
                "source_ea_id": str(source["ea_id"]),
                "target_ea_id": target_ea_id,
                "symbol": str(source["symbol"]),
                "source_status": str(source["status"]),
                "source_verdict": str(source["verdict"]),
                "source_evidence_path": str(source["evidence_path"] or ""),
                "successor_work_item_id": successor_id,
                "successor_phase": q09.NEWS_PHASE,
                "diagnostic_non_admission": payload.get("diagnostic_non_admission") is True,
                "enqueue_disposition": "PENDING_CLASSIFICATION",
                "blocker_code": None,
                "blocker_detail": None,
                "source_plan_path": str(payload.get("q09_run_plan_path") or ""),
                "source_plan_file_sha256": str(
                    payload.get("q09_run_plan_file_sha256") or ""
                ),
                "q08_work_item_id": None,
                "q08_evidence_sha256": None,
            }
            if target_ea_id != str(source["ea_id"]):
                replacement = _replacement_execution_source(
                    connection, target_ea_id, str(source["symbol"])
                )
                fact = _replacement_chain_fact(
                    connection, target_ea_id, str(source["symbol"])
                )
                if replacement is None:
                    entry.update({
                        "enqueue_disposition": (
                            "NOT_ENQUEUED_REPLACEMENT_CHAIN_INELIGIBLE"
                        ),
                        "blocker_code": "TARGET_IDENTITY_HAS_NO_ELIGIBLE_Q08_CHAIN",
                        "blocker_detail": (
                            f"{target_ea_id} latest Q08={fact.get('id')} "
                            f"status={fact.get('status')} verdict={fact.get('verdict')}"
                        ),
                        "replacement_q08_fact": fact,
                    })
                else:
                    (
                        execution,
                        execution_payload,
                        execution_plan,
                        execution_manifest,
                        dependency,
                    ) = replacement
                    entry.update({
                        "enqueue_disposition": "ENQUEUE_RUNNABLE_REPLACEMENT",
                        "identity_replacement": True,
                        "execution_source_work_item_id": str(execution["id"]),
                        "execution_source_status": str(execution["status"]),
                        "source_plan_path": str(
                            execution_payload["q09_run_plan_path"]
                        ),
                        "source_plan_file_sha256": str(
                            execution_payload["q09_run_plan_file_sha256"]
                        ),
                        "source_input_manifest_path": str(
                            execution_plan["input_manifest_path"]
                        ),
                        "source_input_manifest_sha256": str(
                            execution_plan["input_manifest_sha256"]
                        ),
                        "source_contract_version": str(
                            execution_manifest.get("contract_version") or ""
                        ),
                        "source_matrix_scope": str(
                            execution_plan.get("matrix_scope") or ""
                        ),
                        "source_cell_count": int(
                            execution_plan.get("cell_count") or 0
                        ),
                        "q08_work_item_id": str(dependency["parent_work_item_id"]),
                        "q08_evidence_sha256": str(
                            dependency["parent_evidence_sha256"]
                        ),
                        "replacement_q08_fact": fact,
                        "comparison_note": (
                            "calendar remeasurement runs on the OWNER-directed "
                            "replacement EA identity; verdict comparison is not a "
                            "single-build causal estimate"
                        ),
                    })
                entries.append(entry)
                continue
            try:
                source_plan, manifest, plan_path, plan_hash = _source_contract(
                    source, payload
                )
                entry.update({
                    "source_plan_path": str(plan_path),
                    "source_plan_file_sha256": plan_hash,
                    "source_input_manifest_path": str(source_plan["input_manifest_path"]),
                    "source_input_manifest_sha256": str(
                        source_plan["input_manifest_sha256"]
                    ),
                    "source_contract_version": str(
                        manifest.get("contract_version") or ""
                    ),
                    "source_matrix_scope": str(source_plan.get("matrix_scope") or ""),
                    "source_cell_count": int(source_plan.get("cell_count") or 0),
                })
            except RequalificationError as exc:
                entry.update({
                    "enqueue_disposition": "ENQUEUE_HELD_SOURCE_INPUT_BLOCKER",
                    "blocker_code": str(exc).split(":", 1)[0],
                    "blocker_detail": str(exc),
                })
                entries.append(entry)
                continue
            if entry["diagnostic_non_admission"]:
                if (
                    entry["source_phase"] != "Q09_NEWS"
                    or int(entry["source_cell_count"]) != 1
                    or str(entry["source_matrix_scope"])
                    != "oos_2026_single_config_single_seed"
                ):
                    entry.update({
                        "enqueue_disposition": "ENQUEUE_HELD_SOURCE_INPUT_BLOCKER",
                        "blocker_code": "UNSUPPORTED_DIAGNOSTIC_SOURCE_CONTRACT",
                        "blocker_detail": (
                            "only the authenticated OOS-2026 one-cell lane is supported"
                        ),
                    })
                else:
                    entry["enqueue_disposition"] = "ENQUEUE_RUNNABLE_DIAGNOSTIC"
                entries.append(entry)
                continue
            dependency = _q08_dependency(connection, source_id)
            if dependency is None:
                entry.update({
                    "enqueue_disposition": "ENQUEUE_HELD_SOURCE_INPUT_BLOCKER",
                    "blocker_code": "Q08_INPUT_DEPENDENCY_MISSING",
                    "blocker_detail": "source row has no exact Q08_INPUT dependency",
                })
            else:
                entry["q08_work_item_id"] = str(dependency["parent_work_item_id"])
                entry["q08_evidence_sha256"] = str(
                    dependency["parent_evidence_sha256"]
                )
                if (
                    dependency["phase"] != "Q08"
                    or dependency["status"] != "done"
                    or dependency["verdict"] not in {"PASS", "FAIL_SOFT"}
                ):
                    entry.update({
                        "enqueue_disposition": "ENQUEUE_HELD_SOURCE_INPUT_BLOCKER",
                        "blocker_code": "Q08_INPUT_DEPENDENCY_INELIGIBLE",
                        "blocker_detail": (
                            f"phase={dependency['phase']} status={dependency['status']} "
                            f"verdict={dependency['verdict']}"
                        ),
                    })
                else:
                    entry["enqueue_disposition"] = "ENQUEUE_RUNNABLE_CANONICAL"
            entries.append(entry)

    counts: dict[str, int] = {}
    for entry in entries:
        key = str(entry["enqueue_disposition"])
        counts[key] = counts.get(key, 0) + 1
    stable_hash = _stable_plan_hash(entries, impact_sha256)
    return {
        "schema_version": PLAN_SCHEMA,
        "mode": "WhatIf",
        "task_id": task_id,
        "source_audit_task_id": SOURCE_AUDIT_TASK_ID,
        "generated_at_utc": _utc_now(),
        "stable_plan_sha256": stable_hash,
        "impact_csv": str(impact_csv),
        "impact_csv_sha256": impact_sha256,
        "successor_calendar": {
            "bundle_id": verified["bundle_id"],
            "content_sha256": verified["content_sha256"],
            "manifest_path": verified["manifest_path"],
            "manifest_sha256": verified["manifest_sha256"],
            "parent_bundle_id": verified.get("parent_bundle_id"),
            "parent_content_sha256": SOURCE_CONTENT_SHA256,
            "calendar_pin_contract": calendar_pin.payload_binding(),
        },
        "contract_change": {
            "hypothesis": calendar_pin.HYPOTHESIS,
            "single_variable": "news calendar bundle/content hash",
            "identity_replacement_exception": (
                "OWNER-directed 12710->41488 and 20266->41489 comparisons use "
                "the replacement identity's own eligible chain when present; "
                "those deltas are labelled non-causal across builds"
            ),
            "historical_contract_preserved": True,
            "historical_verdicts_preserved": True,
            "false_positive_measure": (
                "new CONFIG_LOCKED where source was REVIEW_REQUIRED"
            ),
            "false_negative_measure": (
                "loss of source CONFIG_LOCKED under successor calendar"
            ),
        },
        "counts": {"directly_exposed": len(entries), **counts},
        "entries": entries,
    }


def _load_source_for_entry(
    connection: sqlite3.Connection, entry: Mapping[str, Any]
) -> tuple[
    sqlite3.Row, sqlite3.Row, dict[str, Any], dict[str, Any], dict[str, Any]
]:
    audit_source = connection.execute(
        "SELECT * FROM work_items WHERE id=?", (entry["source_work_item_id"],)
    ).fetchone()
    if (
        audit_source is None
        or audit_source["status"] != "done"
        or audit_source["verdict"] != entry["source_verdict"]
    ):
        raise RequalificationError("SOURCE_ROW_CHANGED_AFTER_WHATIF")
    execution_id = str(
        entry.get("execution_source_work_item_id")
        or entry["source_work_item_id"]
    )
    execution_source = connection.execute(
        "SELECT * FROM work_items WHERE id=?", (execution_id,)
    ).fetchone()
    if execution_source is None:
        raise RequalificationError("EXECUTION_SOURCE_ROW_MISSING")
    payload = json.loads(str(execution_source["payload_json"] or "{}"))
    plan, manifest, _, _ = _source_contract(execution_source, payload)
    return audit_source, execution_source, payload, plan, manifest


def _successor_artifact_root(
    artifact_root: Path, entry: Mapping[str, Any]
) -> Path:
    return (
        artifact_root
        / f"task_{TASK_ID}"
        / (
            f"slot{int(entry['priority_rank']):03d}_"
            f"{str(entry['source_work_item_id'])[:8]}"
        )
    ).resolve()


def _build_canonical_plan(
    *,
    artifact_root: Path,
    entry: Mapping[str, Any],
    plan: Mapping[str, Any],
    manifest: Mapping[str, Any],
) -> dict[str, Any]:
    paths = manifest.get("source_paths") or {}
    windows = manifest.get("windows") or {}
    required_windows = (
        "full_from_utc", "full_to_utc", "selection_from_utc", "selection_to_utc",
        "holdout_from_utc", "holdout_to_utc", "complete_months",
        "holdout_complete_months",
    )
    if any(key not in windows for key in required_windows):
        raise RequalificationError("SOURCE_WINDOWS_INCOMPLETE")
    output_root = _successor_artifact_root(artifact_root, entry) / "q09_plan"
    return q09.build_run_plan(
        work_item_id=str(entry["successor_work_item_id"]),
        candidate_lineage_key=str(manifest["candidate_lineage_key"]),
        deployment_target=str(manifest["deployment_target"]),
        q08_work_item_id=str(entry["q08_work_item_id"]),
        q08_evidence_path=Path(str(paths["q08_evidence"])),
        baseline_setfile_path=Path(str(paths["baseline_setfile"])),
        ex5_path=Path(str(paths["ex5"])),
        include_closure_path=Path(str(paths["include_closure"])),
        calendar_manifest_path=calendar_pin.MANIFEST_PATH,
        calendar_common_relative_path=calendar_pin.COMMON_RELATIVE_PATH,
        full_from_utc=str(windows["full_from_utc"]),
        full_to_utc=str(windows["full_to_utc"]),
        selection_from_utc=str(windows["selection_from_utc"]),
        selection_to_utc=str(windows["selection_to_utc"]),
        holdout_from_utc=str(windows["holdout_from_utc"]),
        holdout_to_utc=str(windows["holdout_to_utc"]),
        complete_months=int(windows["complete_months"]),
        holdout_complete_months=int(windows["holdout_complete_months"]),
        tester_model=str(manifest["tester_model"]),
        cost_profile=str(manifest["cost_profile"]),
        output_root=output_root,
        news_or_event_strategy=bool(manifest.get("news_or_event_strategy")),
        force_expanded_matrix=str(plan.get("matrix_scope") or "") == "7x4",
        contract_version=str(
            manifest.get("contract_version") or contract.SCHEMA_VERSION
        ),
    )


def _build_diagnostic_plan(
    *,
    artifact_root: Path,
    entry: Mapping[str, Any],
    source_plan: Mapping[str, Any],
    source_manifest: Mapping[str, Any],
) -> dict[str, Any]:
    output_root = _successor_artifact_root(artifact_root, entry) / "q09_plan"
    source_paths = {
        key: Path(str(value)).resolve()
        for key, value in (source_manifest.get("source_paths") or {}).items()
    }
    successor = calendar_bundle.verify_bundle(calendar_pin.MANIFEST_PATH.parent)
    identities = dict(source_manifest["identities"])
    identities.pop("paired_base_identity_sha256", None)
    calendar = {
        "bundle_id": successor["bundle_id"],
        "manifest_sha256": successor["manifest_sha256"],
        "content_sha256": successor["content_sha256"],
        "coverage_from_utc": successor["coverage_from_utc"],
        "coverage_to_utc": successor["coverage_to_utc"],
    }
    base_material = {
        "candidate_lineage_key": source_manifest["candidate_lineage_key"],
        "deployment_target": source_manifest["deployment_target"],
        "identities": identities,
        "calendar_bundle": calendar,
        "windows": source_manifest["windows"],
        "tester_model": source_manifest["tester_model"],
        "cost_profile": source_manifest["cost_profile"],
        "contract_version": source_manifest["contract_version"],
    }
    paired = hashlib.sha256(contract.canonical_json_bytes(base_material)).hexdigest()
    identities["paired_base_identity_sha256"] = paired

    source_cell = dict(source_plan["cells"][0])
    run_material = {
        "paired_base_identity_sha256": paired,
        "arm": source_cell["arm"],
        "temporal_mode": source_cell["temporal_mode"],
        "compliance_mode": source_cell["compliance_mode"],
        "seed": source_cell["seed"],
    }
    run_identity = hashlib.sha256(
        contract.canonical_json_bytes(run_material)
    ).hexdigest()
    cell_dir = output_root / "cell"
    setfile_path = cell_dir / "inputs.set"
    source_bytes = source_paths["baseline_setfile"].read_bytes()
    source_text, encoding, bom = q09._decode_setfile(source_bytes)
    updated = q09._replace_set_values(
        source_text,
        {
            "qm_rng_seed": str(source_cell["seed"]),
            "qm_news_temporal": str(
                contract.TEMPORAL_MODE_IDS[source_cell["temporal_mode"]]
            ),
            "qm_news_compliance": str(
                q09.COMPLIANCE_MODE_IDS[source_cell["compliance_mode"]]
            ),
            "qm_news_calendar_bundle_id": calendar_pin.BUNDLE_ID,
            "qm_news_calendar_expected_sha256": calendar_pin.CONTENT_SHA256,
            "qm_news_calendar_common_relative_path": calendar_pin.COMMON_RELATIVE_PATH,
        },
    )
    q09._write_immutable(setfile_path, bom + updated.encode(encoding))
    cell = {
        **source_cell,
        **run_material,
        "run_identity_sha256": run_identity,
        "setfile_path": str(setfile_path.resolve()),
        "setfile_sha256": contract.sha256_file(setfile_path),
        "receipt_path": str((cell_dir / "cell_receipt.json").resolve()),
    }

    manifest = copy.deepcopy(dict(source_manifest))
    manifest["work_item_id"] = str(entry["successor_work_item_id"])
    manifest["identities"] = identities
    manifest["source_paths"]["calendar_manifest"] = str(
        calendar_pin.MANIFEST_PATH.resolve()
    )
    manifest["calendar_bundle"] = {
        **calendar,
        "common_relative_path": calendar_pin.COMMON_RELATIVE_PATH,
    }
    input_path = output_root / "input_manifest.json"
    q09._write_immutable(input_path, contract.canonical_json_bytes(manifest))

    plan = copy.deepcopy(dict(source_plan))
    plan["work_item_id"] = str(entry["successor_work_item_id"])
    plan["input_manifest_path"] = str(input_path.resolve())
    plan["input_manifest_sha256"] = contract.sha256_file(input_path)
    plan["cells"] = [cell]
    plan.pop("plan_sha256", None)
    plan["plan_sha256"] = q09._plan_hash(plan)
    plan_path = output_root / "run_plan.json"
    q09._write_immutable(plan_path, contract.canonical_json_bytes(plan))
    q09.load_authenticated_plan(
        plan_path, expected_file_sha256=contract.sha256_file(plan_path)
    )
    return {**plan, "plan_path": str(plan_path.resolve())}


def _stable_payload_from_source(
    source: sqlite3.Row,
    source_payload: Mapping[str, Any],
    extra: Mapping[str, Any],
) -> dict[str, Any]:
    payload = farmctl._promotion_payload_with_basket_context(source, dict(extra))
    for key in (
        "ea_dir_name", "expected_ex5_path", "expected_ex5_sha256",
        "expected_mq5_sha256", "expected_period", "expected_symbol",
        "expected_from_date", "expected_to_date", "expected_setfile_sha256",
        "smoke_year_count",
    ):
        if key in source_payload:
            payload[key] = source_payload[key]
    return payload


def _normal_payload(
    *,
    audit_source: sqlite3.Row,
    execution_source: sqlite3.Row,
    execution_payload: Mapping[str, Any],
    entry: Mapping[str, Any],
    now: str,
) -> dict[str, Any]:
    extra: dict[str, Any] = {
        "promoted_from_phase": execution_payload.get("promoted_from_phase"),
        "promoted_from_work_item": execution_payload.get("promoted_from_work_item"),
        "promotion_source": "q09_calendar_requalification",
        "requeued_at": now,
        "priority_track": True,
        "append_only_rerun": True,
        "append_only_rerun_of_work_item": str(execution_source["id"]),
        "rerun_reason": (
            "approved 82-row USD DST correction; single-variable "
            "successor-calendar remeasurement"
        ),
        "historical_work_item_preserved": True,
        "router_task_id": TASK_ID,
        "q09_calendar_pin_contract": calendar_pin.payload_binding(),
        "news_archive_requalification": {
            "schema_version": REQUAL_CONTRACT,
            "source_work_item_id": str(audit_source["id"]),
            "source_phase": str(audit_source["phase"]),
            "source_verdict": str(audit_source["verdict"]),
            "execution_source_work_item_id": str(execution_source["id"]),
            "identity_replacement": bool(entry.get("identity_replacement")),
            "source_calendar_content_sha256": SOURCE_CONTENT_SHA256,
            "successor_calendar_content_sha256": calendar_pin.CONTENT_SHA256,
            "priority_rank": int(entry["priority_rank"]),
            "single_variable": "news_calendar_bundle",
        },
    }
    if (
        execution_payload.get("force_expanded_news_matrix") is True
        or str(entry.get("source_matrix_scope") or "") == "7x4"
    ):
        extra["force_expanded_news_matrix"] = True
    return _stable_payload_from_source(execution_source, execution_payload, extra)


def _diagnostic_payload(
    *,
    source: sqlite3.Row,
    source_payload: Mapping[str, Any],
    entry: Mapping[str, Any],
    plan: Mapping[str, Any],
    manifest: Mapping[str, Any],
    now: str,
) -> dict[str, Any]:
    paths = manifest["source_paths"]
    identities = manifest["identities"]
    anchor_path = str(paths["q08_evidence"])
    ex5_path = str(paths["ex5"])
    payload = _stable_payload_from_source(
        source,
        source_payload,
        {
            "diagnostic_non_admission": True,
            "diagnostic_contract": q09.DIAGNOSTIC_CONTRACT,
            "diagnostic_campaign_id": CAMPAIGN_ID,
            "diagnostic_single_window": True,
            "diagnostic_queue_rank": int(entry["priority_rank"]),
            "diagnostic_live_weight": source_payload.get("diagnostic_live_weight"),
            "diagnostic_anchor_path": anchor_path,
            "diagnostic_anchor_sha256": identities["q08_evidence_sha256"],
            "diagnostic_control": (
                "successor_calendar_only; historical execution inputs preserved"
            ),
            "priority_track": True,
            "host_symbol": source_payload.get("host_symbol") or source["symbol"],
            "host_timeframe": source_payload.get("host_timeframe"),
            "risk_fixed": 1000.0,
            "risk_percent": 0.0,
            "staged_ex5_path": ex5_path,
            "staged_ex5_sha256": identities["ex5_sha256"],
            "avoid_terminals": ["T6", "T7", "T8", "T9", "T10"],
            "diagnostic_allowed_terminals": ["T1", "T2", "T3", "T4", "T5"],
            "diagnostic_concurrency_cap": 5,
            "protected_chain_exclusion": ["OPT_CENSUS", "Q09_PORTFOLIO", "Q10"],
            "router_task_id": TASK_ID,
            "append_only_rerun": True,
            "append_only_rerun_of_work_item": str(source["id"]),
            "rerun_of": str(source["id"]),
            "historical_work_item_preserved": True,
            "window_source": manifest.get("window_source"),
            "q09_calendar_pin_contract": calendar_pin.payload_binding(),
            "news_archive_requalification": {
                "schema_version": REQUAL_CONTRACT,
                "source_work_item_id": str(source["id"]),
                "source_phase": str(source["phase"]),
                "source_verdict": str(source["verdict"]),
                "source_calendar_content_sha256": SOURCE_CONTENT_SHA256,
                "successor_calendar_content_sha256": calendar_pin.CONTENT_SHA256,
                "priority_rank": int(entry["priority_rank"]),
                "single_variable": "news_calendar_bundle",
            },
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_activation_state": "RUNNABLE_BOUND",
            "q09_run_plan_path": str(plan["plan_path"]),
            "q09_run_plan_file_sha256": contract.sha256_file(
                Path(str(plan["plan_path"]))
            ),
            "q09_run_plan_sha256": plan["plan_sha256"],
            "q09_input_manifest_sha256": plan["input_manifest_sha256"],
            "q09_q08_work_item_id": identities["q08_work_item_id"],
            "q09_q08_evidence_sha256": identities["q08_evidence_sha256"],
            "q09_q07_work_item_id": (
                source_payload.get("q09_q07_work_item_id")
                or identities["q08_work_item_id"]
            ),
            "q09_q07_evidence_path": (
                source_payload.get("q09_q07_evidence_path") or anchor_path
            ),
            "q09_q07_evidence_sha256": (
                source_payload.get("q09_q07_evidence_sha256")
                or identities["q08_evidence_sha256"]
            ),
            "q09_cell_count": int(plan["cell_count"]),
            "q09_cell_timeout_sec": q09.DEFAULT_CELL_TIMEOUT_SEC,
            "timeout_min": q09.required_factory_timeout_min(
                int(plan["cell_count"]), window_count=1
            ),
            "q09_plan_bound_at": now,
        },
    )
    artifact_identity = dict(source_payload.get("artifact_identity") or {})
    artifact_identity.update({
        "news_calendar_sha256": calendar_pin.CONTENT_SHA256,
        "ex5_sha256": identities["ex5_sha256"],
        "setfile_sha256": identities["baseline_setfile_sha256"],
        "include_closure_sha256": identities["include_closure_sha256"],
    })
    payload["artifact_identity"] = artifact_identity
    payload["q09_dispatch_binding_sha256"] = q09._dispatch_binding_sha256(payload)
    return payload


def _insert_hold(
    connection: sqlite3.Connection,
    *,
    work_item_id: str,
    code: str,
    reason: str,
    now: str,
) -> None:
    connection.execute(
        """
        INSERT INTO work_item_holds(
          work_item_id,hold_code,reason,active,release_on_restart,
          created_at,updated_at,released_at,release_note
        ) VALUES(?,?,?,1,0,?,?,NULL,NULL)
        ON CONFLICT(work_item_id) DO UPDATE SET
          hold_code=excluded.hold_code,reason=excluded.reason,active=1,
          release_on_restart=0,updated_at=excluded.updated_at,
          released_at=NULL,release_note=NULL
        """,
        (work_item_id, code, reason, now, now),
    )


def _insert_work_item(
    connection: sqlite3.Connection,
    *,
    audit_source: sqlite3.Row,
    execution_source: sqlite3.Row,
    entry: Mapping[str, Any],
    payload: dict[str, Any],
    now: str,
    ready_for_binding: bool,
    diagnostic_bound: bool,
) -> str:
    work_item_id = str(entry["successor_work_item_id"])
    existing = connection.execute(
        "SELECT * FROM work_items WHERE id=?", (work_item_id,)
    ).fetchone()
    if existing is not None:
        existing_payload = json.loads(str(existing["payload_json"] or "{}"))
        marker = existing_payload.get("news_archive_requalification") or {}
        if (
            existing["phase"] != q09.NEWS_PHASE
            or marker.get("source_work_item_id") != str(audit_source["id"])
            or marker.get("successor_calendar_content_sha256")
            != calendar_pin.CONTENT_SHA256
        ):
            raise RequalificationError(f"successor UUID collision: {work_item_id}")
        return "EXISTING"

    connection.execute(
        """
        INSERT INTO work_items(
          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
          parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
          gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256,
          include_closure_sha256,build_id,data_window_start,data_window_end,
          verdict_taxonomy,sh3_enforced
        ) VALUES(?,'backtest',?,?,?,?, 'pending',NULL,0,?,NULL,NULL,?,?,?, ?,
                 NULL,NULL,NULL,NULL,NULL,?,?,NULL,0)
        """,
        (
            work_item_id,
            q09.NEWS_PHASE,
            str(entry["target_ea_id"]),
            str(execution_source["symbol"]),
            str(execution_source["setfile_path"]),
            TASK_ID,
            json.dumps(payload, sort_keys=True),
            now,
            now,
            farmctl.ACTIVE_GATE_CONTRACT_VERSION,
            execution_source["data_window_start"],
            execution_source["data_window_end"],
        ),
    )
    dependency = _q08_dependency(connection, str(execution_source["id"]))
    if dependency is not None and not diagnostic_bound:
        farmctl._add_q08_input_dependency(
            connection,
            child_work_item_id=work_item_id,
            q08_work_item=dependency,
            evidence_sha256=str(dependency["parent_evidence_sha256"]),
        )
    if ready_for_binding:
        farmctl._mark_q09_awaiting_sealed_plan(
            connection, work_item_id=work_item_id, payload=payload, now=now
        )
    elif not diagnostic_bound:
        payload["q09_activation_state"] = "BLOCKED_REQUALIFICATION_INPUT"
        payload["q09_requalification_blocker"] = {
            "code": entry.get("apply_blocker_code") or entry.get("blocker_code"),
            "detail": entry.get("apply_blocker_detail") or entry.get("blocker_detail"),
        }
        connection.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?",
            (json.dumps(payload, sort_keys=True), work_item_id),
        )
        _insert_hold(
            connection,
            work_item_id=work_item_id,
            code=BLOCK_HOLD_CODE,
            reason=BLOCK_HOLD_REASON,
            now=now,
        )
    farmctl.event(
        connection,
        "work_item",
        work_item_id,
        "news_calendar_requalification_enqueued",
        {
            "router_task_id": TASK_ID,
            "source_work_item_id": str(audit_source["id"]),
            "source_verdict": str(audit_source["verdict"]),
            "execution_source_work_item_id": str(execution_source["id"]),
            "successor_calendar_content_sha256": calendar_pin.CONTENT_SHA256,
            "priority_rank": int(entry["priority_rank"]),
            "ready_for_binding": ready_for_binding,
            "diagnostic_bound": diagnostic_bound,
        },
    )
    connection.execute(
        """
        INSERT INTO work_item_transition_ledger(
          idempotency_key,ts,work_item_id,action,from_status,to_status,
          from_verdict,to_verdict,reason,run_id,detail_json
        ) VALUES(?,?,?,'news_calendar_requalification_enqueue',NULL,'pending',
                 NULL,NULL,?,?,?)
        """,
        (
            f"news-calendar-requalification:{TASK_ID}:{audit_source['id']}",
            now,
            work_item_id,
            "approved successor-calendar append-only remeasurement; old row preserved",
            TASK_ID,
            json.dumps({
                "source_work_item_id": str(audit_source["id"]),
                "source_phase": str(audit_source["phase"]),
                "source_verdict": str(audit_source["verdict"]),
                "execution_source_work_item_id": str(execution_source["id"]),
                "calendar_pin": calendar_pin.payload_binding(),
            }, sort_keys=True),
        ),
    )
    return "INSERTED"


def _convert_binding_failure_to_hold(
    farm_root: Path, entry: Mapping[str, Any], error: BaseException
) -> None:
    now = _utc_now()
    detail = f"{type(error).__name__}: {error}"[:1500]
    with farmctl.connect(farm_root) as connection:
        connection.execute("BEGIN IMMEDIATE")
        row = connection.execute(
            "SELECT payload_json FROM work_items WHERE id=?",
            (entry["successor_work_item_id"],),
        ).fetchone()
        payload = json.loads(str(row["payload_json"] or "{}"))
        payload["q09_activation_state"] = "BLOCKED_REQUALIFICATION_INPUT"
        payload["q09_requalification_blocker"] = {
            "code": "SUCCESSOR_PLAN_BINDING_FAILED",
            "detail": detail,
        }
        connection.execute(
            "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
            (
                json.dumps(payload, sort_keys=True),
                now,
                entry["successor_work_item_id"],
            ),
        )
        _insert_hold(
            connection,
            work_item_id=str(entry["successor_work_item_id"]),
            code=BLOCK_HOLD_CODE,
            reason=f"{BLOCK_HOLD_REASON}; {detail}",
            now=now,
        )
        connection.commit()


def _source_snapshot(
    farm_root: Path, entries: Sequence[Mapping[str, Any]]
) -> dict[str, tuple[Any, ...]]:
    snapshot: dict[str, tuple[Any, ...]] = {}
    with _read_only_connection(farm_root) as connection:
        for entry in entries:
            row = connection.execute(
                """
                SELECT status,verdict,evidence_path,payload_json,updated_at
                FROM work_items WHERE id=?
                """,
                (entry["source_work_item_id"],),
            ).fetchone()
            snapshot[str(entry["source_work_item_id"])] = tuple(row) if row else ()
    return snapshot


def apply_plan(
    *, farm_root: Path, plan: dict[str, Any], artifact_root: Path
) -> dict[str, Any]:
    if plan.get("stable_plan_sha256") != _stable_plan_hash(
        plan["entries"], str(plan["impact_csv_sha256"])
    ):
        raise RequalificationError("WhatIf plan stable hash mismatch")
    artifact_root = artifact_root.resolve()
    artifact_root.mkdir(parents=True, exist_ok=True)
    before = _source_snapshot(farm_root, plan["entries"])

    prepared: dict[str, dict[str, Any]] = {}
    build_failures: dict[str, str] = {}
    with _read_only_connection(farm_root) as connection:
        for entry in plan["entries"]:
            disposition = str(entry["enqueue_disposition"])
            if disposition not in {
                "ENQUEUE_RUNNABLE_CANONICAL",
                "ENQUEUE_RUNNABLE_DIAGNOSTIC",
                "ENQUEUE_RUNNABLE_REPLACEMENT",
            }:
                continue
            try:
                (
                    audit_source,
                    execution_source,
                    payload,
                    source_plan,
                    source_manifest,
                ) = (
                    _load_source_for_entry(connection, entry)
                )
                if disposition == "ENQUEUE_RUNNABLE_DIAGNOSTIC":
                    successor_plan = _build_diagnostic_plan(
                        artifact_root=artifact_root,
                        entry=entry,
                        source_plan=source_plan,
                        source_manifest=source_manifest,
                    )
                else:
                    successor_plan = _build_canonical_plan(
                        artifact_root=artifact_root,
                        entry=entry,
                        plan=source_plan,
                        manifest=source_manifest,
                    )
                prepared[str(entry["source_work_item_id"])] = {
                    "audit_source": dict(audit_source),
                    "execution_source": dict(execution_source),
                    "source_payload": payload,
                    "source_manifest": source_manifest,
                    "successor_plan": successor_plan,
                }
            except BaseException as exc:
                build_failures[str(entry["source_work_item_id"])] = (
                    f"{type(exc).__name__}: {exc}"[:1500]
                )

    backup = farmctl._governed_state_backup_resolution(
        farm_root, "q09_calendar_requalification"
    )
    lock = farmctl.FactoryMutationLock(
        farmctl.path_for_factory_flag(farmctl.factory_off_flag_path(farm_root)),
        owner=f"q09-calendar-requalification:{TASK_ID}",
    )
    inserted: list[str] = []
    existing: list[str] = []
    binding_candidates: list[tuple[dict[str, Any], dict[str, Any]]] = []
    diagnostic_runnable: list[str] = []
    held: list[str] = []
    skipped_replacement: list[str] = []
    bound: list[str] = []
    binding_failures: list[dict[str, str]] = []
    lock.__enter__()
    try:
        with farmctl.connect(farm_root) as connection:
            connection.execute("BEGIN IMMEDIATE")
            base_now = datetime.now(timezone.utc)
            for offset, original_entry in enumerate(plan["entries"]):
                entry = dict(original_entry)
                if str(entry["enqueue_disposition"]).startswith("NOT_ENQUEUED_"):
                    skipped_replacement.append(str(entry["source_work_item_id"]))
                    continue
                audit_source = connection.execute(
                    "SELECT * FROM work_items WHERE id=?",
                    (entry["source_work_item_id"],),
                ).fetchone()
                if (
                    audit_source is None
                    or audit_source["status"] != "done"
                    or audit_source["verdict"] != entry["source_verdict"]
                ):
                    raise RequalificationError(
                        f"source changed during apply: {entry['source_work_item_id']}"
                    )
                execution_id = str(
                    entry.get("execution_source_work_item_id")
                    or entry["source_work_item_id"]
                )
                execution_source = connection.execute(
                    "SELECT * FROM work_items WHERE id=?", (execution_id,)
                ).fetchone()
                if execution_source is None:
                    raise RequalificationError(
                        f"execution source disappeared during apply: {execution_id}"
                    )
                execution_payload = json.loads(
                    str(execution_source["payload_json"] or "{}")
                )
                built = prepared.get(str(audit_source["id"]))
                if str(audit_source["id"]) in build_failures:
                    entry["apply_blocker_code"] = "SUCCESSOR_PLAN_BUILD_FAILED"
                    entry["apply_blocker_detail"] = build_failures[
                        str(audit_source["id"])
                    ]
                ready_canonical = bool(
                    built
                    and entry["enqueue_disposition"] in {
                        "ENQUEUE_RUNNABLE_CANONICAL",
                        "ENQUEUE_RUNNABLE_REPLACEMENT",
                    }
                )
                ready_diagnostic = bool(
                    built
                    and entry["enqueue_disposition"] == "ENQUEUE_RUNNABLE_DIAGNOSTIC"
                )
                stamp = (base_now + timedelta(microseconds=offset)).isoformat()
                if ready_diagnostic:
                    successor_plan = built["successor_plan"]
                    successor_manifest = _read_json(
                        Path(str(successor_plan["input_manifest_path"])),
                        "successor diagnostic input manifest",
                    )
                    payload = _diagnostic_payload(
                        source=audit_source,
                        source_payload=execution_payload,
                        entry=entry,
                        plan=successor_plan,
                        manifest=successor_manifest,
                        now=stamp,
                    )
                else:
                    payload = _normal_payload(
                        audit_source=audit_source,
                        execution_source=execution_source,
                        execution_payload=execution_payload,
                        entry=entry,
                        now=stamp,
                    )
                result = _insert_work_item(
                    connection,
                    audit_source=audit_source,
                    execution_source=execution_source,
                    entry=entry,
                    payload=payload,
                    now=stamp,
                    ready_for_binding=ready_canonical,
                    diagnostic_bound=ready_diagnostic,
                )
                target = str(entry["successor_work_item_id"])
                (inserted if result == "INSERTED" else existing).append(target)
                if ready_canonical:
                    binding_candidates.append((entry, built["successor_plan"]))
                elif ready_diagnostic:
                    diagnostic_runnable.append(target)
                else:
                    held.append(target)
            connection.commit()

        for entry, successor_plan in binding_candidates:
            plan_path = Path(str(successor_plan["plan_path"])).resolve()
            try:
                q09.bind_plan_to_work_item(
                    farm_root,
                    work_item_id=str(entry["successor_work_item_id"]),
                    plan_path=plan_path,
                    expected_plan_file_sha256=contract.sha256_file(plan_path),
                    cell_timeout_sec=q09.DEFAULT_CELL_TIMEOUT_SEC,
                )
                bound.append(str(entry["successor_work_item_id"]))
            except BaseException as exc:
                _convert_binding_failure_to_hold(farm_root, entry, exc)
                held.append(str(entry["successor_work_item_id"]))
                binding_failures.append({
                    "source_work_item_id": str(entry["source_work_item_id"]),
                    "successor_work_item_id": str(entry["successor_work_item_id"]),
                    "error": f"{type(exc).__name__}: {exc}"[:1500],
                })
    finally:
        lock.__exit__(None, None, None)

    after = _source_snapshot(farm_root, plan["entries"])
    source_preservation_verified = before == after
    if not source_preservation_verified:
        raise RequalificationError(
            "historical source rows changed during append-only apply"
        )
    return {
        "schema_version": RECEIPT_SCHEMA,
        "task_id": TASK_ID,
        "applied_at_utc": _utc_now(),
        "stable_plan_sha256": plan["stable_plan_sha256"],
        "database": str(farmctl.db_path(farm_root).resolve()),
        "backup": backup,
        "calendar_pin": calendar_pin.payload_binding(),
        "inserted_count": len(inserted),
        "existing_count": len(existing),
        "bound_canonical_count": len(bound),
        "runnable_diagnostic_count": len(diagnostic_runnable),
        "held_count": len(set(held)),
        "replacement_identity_blocked_count": len(skipped_replacement),
        "build_failure_count": len(build_failures),
        "binding_failure_count": len(binding_failures),
        "source_preservation_verified": source_preservation_verified,
        "inserted_work_item_ids": inserted,
        "existing_work_item_ids": existing,
        "bound_canonical_work_item_ids": bound,
        "runnable_diagnostic_work_item_ids": diagnostic_runnable,
        "held_work_item_ids": sorted(set(held)),
        "replacement_identity_blocked_source_ids": skipped_replacement,
        "build_failures": build_failures,
        "binding_failures": binding_failures,
    }


def status_document(
    *, farm_root: Path, plan: Mapping[str, Any]
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    rows: list[dict[str, Any]] = []
    d2g6_losses: list[dict[str, Any]] = []
    counts: dict[str, int] = {}
    with _read_only_connection(farm_root) as connection:
        for entry in plan["entries"]:
            successor = connection.execute(
                """
                SELECT status,verdict,evidence_path,claimed_by,payload_json
                FROM work_items WHERE id=?
                """,
                (entry["successor_work_item_id"],),
            ).fetchone()
            hold = connection.execute(
                """
                SELECT hold_code,reason FROM work_item_holds
                WHERE work_item_id=? AND active=1
                """,
                (entry["successor_work_item_id"],),
            ).fetchone()
            if successor is None:
                new_status = "NOT_ENQUEUED"
                new_verdict = ""
                delta = str(entry.get("blocker_code") or "NOT_ENQUEUED")
                evidence = ""
            else:
                new_status = str(successor["status"])
                new_verdict = str(successor["verdict"] or "")
                evidence = str(successor["evidence_path"] or "")
                if hold is not None:
                    delta = f"HELD:{hold['hold_code']}"
                elif new_status != "done":
                    delta = "PENDING_REMEASUREMENT"
                elif new_verdict == str(entry["source_verdict"]):
                    delta = "VERDICT_UNCHANGED"
                elif (
                    entry["source_verdict"] == "CONFIG_LOCKED"
                    and new_verdict != "CONFIG_LOCKED"
                ):
                    delta = "CONFIG_LOCKED_LOSS"
                else:
                    delta = "VERDICT_CHANGED"
            row = {
                "priority_rank": entry["priority_rank"],
                "source_work_item_id": entry["source_work_item_id"],
                "source_phase": entry["source_phase"],
                "source_ea_id": entry["source_ea_id"],
                "target_ea_id": entry["target_ea_id"],
                "symbol": entry["symbol"],
                "old_verdict": entry["source_verdict"],
                "successor_work_item_id": entry["successor_work_item_id"],
                "new_status": new_status,
                "new_verdict": new_verdict,
                "delta": delta,
                "active_hold_code": str(hold["hold_code"] if hold else ""),
                "new_evidence_path": evidence,
                "blocker_code": str(entry.get("blocker_code") or ""),
            }
            rows.append(row)
            counts[delta] = counts.get(delta, 0) + 1
            if (
                entry["source_ea_id"] in ROSTER_PRIORITY
                and delta == "CONFIG_LOCKED_LOSS"
            ):
                d2g6_losses.append(row)
    status = {
        "schema_version": STATUS_SCHEMA,
        "task_id": TASK_ID,
        "observed_at_utc": _utc_now(),
        "stable_plan_sha256": plan["stable_plan_sha256"],
        "successor_calendar_content_sha256": calendar_pin.CONTENT_SHA256,
        "counts": counts,
        "d2g6_config_locked_losses": d2g6_losses,
        "sunday_status_update_required": bool(d2g6_losses),
        "interpretation": (
            "Only completed successor evidence can produce a verdict delta; "
            "pending and held rows do not alter historical verdicts."
        ),
    }
    return status, rows


def _write_delta_csv(path: Path, rows: Sequence[Mapping[str, Any]]) -> None:
    fields = (
        "priority_rank", "source_work_item_id", "source_phase", "source_ea_id",
        "target_ea_id", "symbol", "old_verdict", "successor_work_item_id",
        "new_status", "new_verdict", "delta", "active_hold_code",
        "new_evidence_path", "blocker_code",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})
    os.replace(temporary, path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    parser.add_argument("--impact-csv", type=Path, default=DEFAULT_IMPACT_CSV)
    parser.add_argument("--task-id", default=TASK_ID)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--evidence-dir", required=True, type=Path)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("plan")
    apply_command = sub.add_parser("apply")
    apply_command.add_argument("--apply", action="store_true")
    sub.add_parser("status")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    evidence_dir = _require_task_scoped_dir(args.evidence_dir, args.task_id)
    plan_path = evidence_dir / "requalification_plan.json"
    if args.command == "status":
        plan = _read_json(plan_path, "requalification WhatIf plan")
        status, delta_rows = status_document(
            farm_root=args.farm_root, plan=plan
        )
        _write_json(evidence_dir / "requalification_status.json", status)
        _write_delta_csv(evidence_dir / "verdict_delta.csv", delta_rows)
        print(json.dumps(status, indent=2, sort_keys=True))
        return 0

    plan = build_plan(
        farm_root=args.farm_root,
        impact_csv=args.impact_csv,
        task_id=args.task_id,
    )
    _write_json(plan_path, plan)
    if args.command == "plan" or not args.apply:
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0

    receipt = apply_plan(
        farm_root=args.farm_root,
        plan=plan,
        artifact_root=args.artifact_root,
    )
    _write_json(evidence_dir / "requalification_apply_receipt.json", receipt)
    status, delta_rows = status_document(farm_root=args.farm_root, plan=plan)
    _write_json(evidence_dir / "requalification_status.json", status)
    _write_delta_csv(evidence_dir / "verdict_delta.csv", delta_rows)
    print(json.dumps({"receipt": receipt, "status": status}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
