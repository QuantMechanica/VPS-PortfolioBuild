#!/usr/bin/env python3
"""Plan, execute, and collect a reproducible Q09_NEWS v2 tester experiment.

The planner creates immutable, per-cell setfiles and a queue-ready manifest.
Execution uses an already-claimed ordinary factory terminal. The collector
authenticates every cell receipt and artifact before delegating economic
selection to :mod:`q09_news_contract`.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Callable, Mapping, Sequence

try:
    import q09_news_contract as contract
    import q09_news_calendar as calendar_bundle
    import q09_news_schema as news_schema
except ModuleNotFoundError:
    from tools.strategy_farm import q09_news_calendar as calendar_bundle
    from tools.strategy_farm import q09_news_contract as contract
    from tools.strategy_farm import q09_news_schema as news_schema


PLAN_SCHEMA = "q09-news-run-plan/v2"
CELL_RECEIPT_SCHEMA = "q09-news-cell-receipt/v2"
CELL_EVIDENCE_SCHEMA = "q09-news-cell-evidence/v2"
COMPLIANCE_MODE_IDS = {"NONE": 0, "DXZ": 1, "FTMO": 2, "5ERS": 3}
DEFAULT_CELL_TIMEOUT_SEC = 3600
CELL_TIMEOUT_HEADROOM_SEC = 600
WINDOW_NAMES = ("selection", "holdout", "full")
FACTORY_DB_RELATIVE_PATH = Path("state") / "farm_state.sqlite"


class RunnerError(RuntimeError):
    """Raised when a Q09 plan or tester receipt cannot be authenticated."""


class CapacityError(RunnerError):
    """Raised when execution is outside the active factory terminal claim."""


def _safe_common_path(value: str) -> str:
    normalized = value.replace("\\", "/").strip("/")
    path = PurePosixPath(normalized)
    if not normalized or path.is_absolute() or ".." in path.parts or ":" in normalized:
        raise RunnerError("calendar_common_relative_path must be safe and relative")
    return str(path)


def _decode_setfile(data: bytes) -> tuple[str, str, bytes]:
    if data.startswith(b"\xff\xfe"):
        return data[2:].decode("utf-16-le"), "utf-16-le", b"\xff\xfe"
    if data.startswith(b"\xfe\xff"):
        return data[2:].decode("utf-16-be"), "utf-16-be", b"\xfe\xff"
    if data.startswith(b"\xef\xbb\xbf"):
        return data[3:].decode("utf-8"), "utf-8", b"\xef\xbb\xbf"
    try:
        return data.decode("utf-8"), "utf-8", b""
    except UnicodeDecodeError:
        return data.decode("cp1252"), "cp1252", b""


def _replace_set_values(text: str, updates: Mapping[str, str]) -> str:
    newline = "\r\n" if "\r\n" in text else "\n"
    remaining = {key.lower(): (key, value) for key, value in updates.items()}
    output: list[str] = []
    for line in text.splitlines():
        if not line or line.lstrip().startswith(";") or "=" not in line:
            output.append(line)
            continue
        key, current = line.split("=", 1)
        update = remaining.pop(key.strip().lower(), None)
        if update is None:
            output.append(line)
            continue
        _, value = update
        suffix = "||" + current.split("||", 1)[1] if "||" in current else ""
        output.append(f"{key}={value}{suffix}")
    if remaining:
        if output and output[-1]:
            output.append("")
        output.append("; Q09_NEWS v2 sealed tester inputs")
        for _, (key, value) in sorted(remaining.items()):
            output.append(f"{key}={value}")
    return newline.join(output) + newline


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def _write_immutable(path: Path, data: bytes) -> None:
    if path.exists():
        if not path.is_file() or path.read_bytes() != data:
            raise RunnerError(f"existing planned artifact contradicts immutable content: {path}")
        return
    _atomic_write(path, data)


def _load_json(path: Path, role: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RunnerError(f"cannot read {role}: {exc}") from exc
    if not isinstance(value, dict):
        raise RunnerError(f"{role} must be a JSON object")
    return value


def _plan_hash(plan: Mapping[str, Any]) -> str:
    unsigned = dict(plan)
    unsigned.pop("plan_sha256", None)
    return hashlib.sha256(contract.canonical_json_bytes(unsigned)).hexdigest()


def _verify_hash(path: Path, expected: str, role: str) -> None:
    if not path.is_file():
        raise RunnerError(f"{role} missing: {path}")
    actual = contract.sha256_file(path)
    if actual != expected:
        raise RunnerError(f"{role} SHA-256 mismatch: expected {expected}, got {actual}")


def _is_prop_target(deployment_target: str) -> bool:
    normalized = deployment_target.strip().upper().replace("-", "_").replace(" ", "_")
    return normalized in {"FTMO", "5ERS", "THE5ERS", "THE_5ERS"}


def _cell_specs(target_compliance: str, expanded: bool) -> list[tuple[str, str, str, int]]:
    specs = [("CONTROL_OFF", "OFF", "NONE", seed) for seed in contract.SEEDS]
    compliances = contract.COMPLIANCE_MODES if expanded else (target_compliance,)
    for compliance in compliances:
        for temporal in contract.TEMPORAL_MODES:
            for seed in contract.SEEDS:
                specs.append(("POLICY_ON", temporal, compliance, seed))
    return specs


def build_run_plan(
    *,
    work_item_id: str,
    candidate_lineage_key: str,
    deployment_target: str,
    q08_work_item_id: str,
    q08_evidence_path: Path,
    baseline_setfile_path: Path,
    ex5_path: Path,
    include_closure_path: Path,
    calendar_manifest_path: Path,
    calendar_common_relative_path: str,
    full_from_utc: str,
    full_to_utc: str,
    selection_from_utc: str,
    selection_to_utc: str,
    holdout_from_utc: str,
    holdout_to_utc: str,
    complete_months: int,
    holdout_complete_months: int,
    tester_model: str,
    cost_profile: str,
    output_root: Path,
    news_or_event_strategy: bool = False,
    force_expanded_matrix: bool = False,
) -> dict[str, Any]:
    """Seal an immutable queue plan and per-cell setfiles."""

    output_root = output_root.resolve()
    source_paths = {
        "q08_evidence": q08_evidence_path.resolve(),
        "baseline_setfile": baseline_setfile_path.resolve(),
        "ex5": ex5_path.resolve(),
        "include_closure": include_closure_path.resolve(),
        "calendar_manifest": calendar_manifest_path.resolve(),
    }
    for role, path in source_paths.items():
        if not path.is_file():
            raise RunnerError(f"{role} missing: {path}")
    try:
        calendar = calendar_bundle.verify_bundle(source_paths["calendar_manifest"].parent)
    except calendar_bundle.CalendarBundleError as exc:
        raise RunnerError(f"calendar bundle verification failed: {exc}") from exc
    if Path(calendar["manifest_path"]).resolve() != source_paths["calendar_manifest"]:
        raise RunnerError("calendar manifest path is not the canonical bundle manifest")
    for field in (
        "bundle_id",
        "content_sha256",
        "coverage_from_utc",
        "coverage_to_utc",
    ):
        if not calendar.get(field):
            raise RunnerError(f"calendar manifest missing {field}")
    target_compliance = contract.compliance_for_target(deployment_target)
    relative_calendar = _safe_common_path(calendar_common_relative_path)
    identities = {
        "q08_work_item_id": q08_work_item_id,
        "q08_evidence_sha256": contract.sha256_file(source_paths["q08_evidence"]),
        "baseline_setfile_sha256": contract.sha256_file(source_paths["baseline_setfile"]),
        "ex5_sha256": contract.sha256_file(source_paths["ex5"]),
        "include_closure_sha256": contract.sha256_file(source_paths["include_closure"]),
    }
    windows = {
        "full_from_utc": full_from_utc,
        "full_to_utc": full_to_utc,
        "selection_from_utc": selection_from_utc,
        "selection_to_utc": selection_to_utc,
        "holdout_from_utc": holdout_from_utc,
        "holdout_to_utc": holdout_to_utc,
        "complete_months": int(complete_months),
        "holdout_complete_months": int(holdout_complete_months),
        "holdout_sealed": True,
    }
    base_material = {
        "candidate_lineage_key": candidate_lineage_key,
        "deployment_target": deployment_target,
        "identities": identities,
        "calendar_bundle": {
            "bundle_id": calendar["bundle_id"],
            "manifest_sha256": contract.sha256_file(source_paths["calendar_manifest"]),
            "content_sha256": calendar["content_sha256"],
            "coverage_from_utc": calendar["coverage_from_utc"],
            "coverage_to_utc": calendar["coverage_to_utc"],
        },
        "windows": windows,
        "tester_model": tester_model,
        "cost_profile": cost_profile,
    }
    paired_base_identity = hashlib.sha256(contract.canonical_json_bytes(base_material)).hexdigest()
    identities["paired_base_identity_sha256"] = paired_base_identity
    # Reuse contract header validation so planner and adjudicator cannot drift.
    header_probe = {
        "schema_version": contract.SCHEMA_VERSION,
        "work_item_id": work_item_id,
        "deployment_target": deployment_target,
        "identities": identities,
        "calendar_bundle": base_material["calendar_bundle"],
        "windows": windows,
    }
    try:
        contract.validate_experiment_header(header_probe)
    except contract.ContractError as exc:
        raise RunnerError(str(exc)) from exc

    expanded = bool(force_expanded_matrix or news_or_event_strategy or _is_prop_target(deployment_target))
    source_bytes = source_paths["baseline_setfile"].read_bytes()
    source_text, encoding, bom = _decode_setfile(source_bytes)
    cells: list[dict[str, Any]] = []
    for arm, temporal, compliance, seed in _cell_specs(target_compliance, expanded):
        run_material = {
            "paired_base_identity_sha256": paired_base_identity,
            "arm": arm,
            "temporal_mode": temporal,
            "compliance_mode": compliance,
            "seed": seed,
        }
        run_identity = hashlib.sha256(contract.canonical_json_bytes(run_material)).hexdigest()
        cell_dir = output_root / "cells" / f"{arm.lower()}__m{contract.TEMPORAL_MODE_IDS[temporal]}__c{COMPLIANCE_MODE_IDS[compliance]}__s{seed}"
        setfile_path = cell_dir / "inputs.set"
        updated = _replace_set_values(
            source_text,
            {
                "qm_rng_seed": str(seed),
                "qm_news_temporal": str(contract.TEMPORAL_MODE_IDS[temporal]),
                "qm_news_compliance": str(COMPLIANCE_MODE_IDS[compliance]),
                "qm_news_calendar_bundle_id": str(calendar["bundle_id"]),
                "qm_news_calendar_expected_sha256": str(calendar["content_sha256"]),
                "qm_news_calendar_common_relative_path": relative_calendar,
            },
        )
        setfile_bytes = bom + updated.encode(encoding)
        _write_immutable(setfile_path, setfile_bytes)
        cells.append(
            {
                **run_material,
                "run_identity_sha256": run_identity,
                "setfile_path": str(setfile_path.resolve()),
                "setfile_sha256": contract.sha256_file(setfile_path),
                "receipt_path": str((cell_dir / "cell_receipt.json").resolve()),
            }
        )
    if source_paths["baseline_setfile"].read_bytes() != source_bytes:
        raise RunnerError("baseline source setfile changed during planning")

    input_manifest = {
        "schema_version": "q09-news-input-manifest/v2",
        "work_item_id": work_item_id,
        "candidate_lineage_key": candidate_lineage_key,
        "deployment_target": deployment_target,
        "target_compliance": target_compliance,
        "source_paths": {key: str(value) for key, value in source_paths.items()},
        "identities": identities,
        "calendar_bundle": base_material["calendar_bundle"] | {"common_relative_path": relative_calendar},
        "windows": windows,
        "tester_model": tester_model,
        "cost_profile": cost_profile,
        "news_or_event_strategy": bool(news_or_event_strategy),
        "matrix_scope": "7x4" if expanded else "7x1_target_compliance",
    }
    input_manifest_path = output_root / "input_manifest.json"
    input_manifest_bytes = contract.canonical_json_bytes(input_manifest)
    _write_immutable(input_manifest_path, input_manifest_bytes)
    plan: dict[str, Any] = {
        "schema_version": PLAN_SCHEMA,
        "work_item_id": work_item_id,
        "candidate_lineage_key": candidate_lineage_key,
        "input_manifest_path": str(input_manifest_path.resolve()),
        "input_manifest_sha256": contract.sha256_file(input_manifest_path),
        "matrix_scope": input_manifest["matrix_scope"],
        "target_compliance": target_compliance,
        "cell_count": len(cells),
        "cells": cells,
    }
    plan["plan_sha256"] = _plan_hash(plan)
    plan_path = output_root / "run_plan.json"
    _write_immutable(plan_path, contract.canonical_json_bytes(plan))
    return {**plan, "plan_path": str(plan_path.resolve())}


def load_run_plan(path: Path) -> dict[str, Any]:
    plan = _load_json(path, "Q09 run plan")
    if plan.get("schema_version") != PLAN_SCHEMA:
        raise RunnerError("unsupported Q09 run-plan schema")
    if plan.get("plan_sha256") != _plan_hash(plan):
        raise RunnerError("Q09 run-plan SHA-256 mismatch")
    if int(plan.get("cell_count", -1)) != len(plan.get("cells", [])):
        raise RunnerError("Q09 run-plan cell_count mismatch")
    return plan


def _validate_source_vintage(input_manifest: Mapping[str, Any]) -> None:
    identities = input_manifest["identities"]
    source_paths = input_manifest["source_paths"]
    checks = {
        "q08_evidence": identities["q08_evidence_sha256"],
        "baseline_setfile": identities["baseline_setfile_sha256"],
        "ex5": identities["ex5_sha256"],
        "include_closure": identities["include_closure_sha256"],
        "calendar_manifest": input_manifest["calendar_bundle"]["manifest_sha256"],
    }
    for role, expected in checks.items():
        _verify_hash(Path(source_paths[role]), expected, role)


def load_authenticated_plan(
    plan_path: Path,
    *,
    expected_file_sha256: str | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Load a plan, its manifest, and every immutable source binding.

    ``plan_sha256`` authenticates the plan's logical JSON fields.  The optional
    file hash authenticates the exact artifact passed through the work-item
    payload, including serialization bytes.
    """

    plan_path = plan_path.resolve()
    if expected_file_sha256 is not None:
        expected = str(expected_file_sha256).strip().lower()
        if not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise RunnerError("expected Q09 run-plan file SHA-256 is invalid")
        _verify_hash(plan_path, expected, "Q09 run-plan artifact")
    plan = load_run_plan(plan_path)
    try:
        input_path = Path(str(plan["input_manifest_path"]))
        _verify_hash(input_path, str(plan["input_manifest_sha256"]), "Q09 input manifest")
        input_manifest = _load_json(input_path, "Q09 input manifest")
        if input_manifest.get("schema_version") != "q09-news-input-manifest/v2":
            raise RunnerError("unsupported Q09 input-manifest schema")
        if input_manifest.get("work_item_id") != plan.get("work_item_id"):
            raise RunnerError("Q09 plan/input-manifest work_item_id mismatch")
        if input_manifest.get("candidate_lineage_key") != plan.get("candidate_lineage_key"):
            raise RunnerError("Q09 plan/input-manifest candidate lineage mismatch")
        _validate_source_vintage(input_manifest)
    except (KeyError, TypeError, ValueError) as exc:
        raise RunnerError(f"Q09 plan/input manifest is malformed: {exc}") from exc

    seen_identities: set[str] = set()
    for index, spec in enumerate(plan.get("cells", [])):
        if not isinstance(spec, Mapping):
            raise RunnerError(f"Q09 cell spec {index} must be an object")
        required = (
            "run_identity_sha256", "paired_base_identity_sha256", "arm",
            "temporal_mode", "compliance_mode", "seed", "setfile_path",
            "setfile_sha256", "receipt_path",
        )
        if any(field not in spec for field in required):
            raise RunnerError(f"Q09 cell spec {index} is incomplete")
        identity = str(spec["run_identity_sha256"])
        if identity in seen_identities:
            raise RunnerError("Q09 run identity is reused by multiple cells")
        seen_identities.add(identity)
        _verify_hash(
            Path(str(spec["setfile_path"])),
            str(spec["setfile_sha256"]),
            f"planned cell setfile {index}",
        )
    return plan, input_manifest


def required_factory_timeout_min(
    cell_count: int,
    *,
    cell_timeout_sec: int = DEFAULT_CELL_TIMEOUT_SEC,
) -> int:
    """Conservative serial-run outer budget for three tester windows per cell."""

    if cell_count <= 0:
        raise RunnerError("Q09 plan must contain at least one cell")
    if not 60 <= int(cell_timeout_sec) <= 28800:
        raise RunnerError("Q09 cell timeout must be between 60 and 28800 seconds")
    total_seconds = int(cell_count) * len(WINDOW_NAMES) * (
        int(cell_timeout_sec) + CELL_TIMEOUT_HEADROOM_SEC
    )
    return math.ceil(total_seconds / 60) + 60


def _dispatch_binding_material(payload: Mapping[str, Any]) -> dict[str, Any]:
    fields = (
        "q09_run_plan_path",
        "q09_run_plan_file_sha256",
        "q09_run_plan_sha256",
        "q09_input_manifest_sha256",
        "q09_q08_work_item_id",
        "q09_q08_evidence_sha256",
        "q09_q07_work_item_id",
        "q09_q07_evidence_sha256",
        "q09_cell_count",
        "q09_cell_timeout_sec",
    )
    return {field: payload.get(field) for field in fields}


def _dispatch_binding_sha256(payload: Mapping[str, Any]) -> str:
    return contract.sha256_bytes(contract.canonical_json_bytes(_dispatch_binding_material(payload)))


def _farm_db_path(farm_root: Path) -> Path:
    return farm_root.resolve() / FACTORY_DB_RELATIVE_PATH


def bind_plan_to_work_item(
    farm_root: Path,
    *,
    work_item_id: str,
    plan_path: Path,
    expected_plan_file_sha256: str,
    cell_timeout_sec: int = DEFAULT_CELL_TIMEOUT_SEC,
) -> dict[str, Any]:
    """Atomically bind one sealed plan to one pending canonical Q09 row.

    The function authenticates Q08 and Q07 lineage, registers the immutable
    calendar bundle, and writes a self-hashed dispatch binding.  It never
    creates or requeues a work item.
    """

    plan_path = plan_path.resolve()
    plan, manifest = load_authenticated_plan(
        plan_path,
        expected_file_sha256=expected_plan_file_sha256,
    )
    if str(plan.get("work_item_id")) != str(work_item_id):
        raise RunnerError("Q09 run plan is bound to a different work_item_id")
    if str(manifest.get("tester_model") or "").strip().upper() not in {
        "REAL_TICKS", "MODEL4_REAL_TICKS",
    }:
        raise RunnerError("Q09 execution requires a sealed REAL_TICKS tester model")
    timeout_sec = int(cell_timeout_sec)
    timeout_min = required_factory_timeout_min(
        int(plan["cell_count"]), cell_timeout_sec=timeout_sec
    )
    database = _farm_db_path(farm_root)
    if not database.is_file():
        raise RunnerError(f"strategy-farm database missing: {database}")

    connection = sqlite3.connect(str(database), timeout=30)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("BEGIN IMMEDIATE")
        item = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (str(work_item_id),)
        ).fetchone()
        if item is None:
            raise RunnerError("Q09 work item does not exist")
        if item["phase"] != "Q09_NEWS":
            raise RunnerError("plan binding requires canonical phase Q09_NEWS")
        if item["status"] != "pending" or str(item["claimed_by"] or "").strip():
            raise RunnerError("Q09 plan can only bind to an unclaimed pending work item")
        if connection.execute(
            "SELECT 1 FROM q09_news_tests WHERE work_item_id=?", (str(work_item_id),)
        ).fetchone() is not None:
            raise RunnerError("Q09 work item already has immutable adjudication evidence")

        dependency = connection.execute(
            """
            SELECT d.parent_work_item_id,d.parent_evidence_sha256,
                   p.phase,p.status,p.verdict,p.evidence_path,p.payload_json
            FROM work_item_dependencies d
            JOIN work_items p ON p.id=d.parent_work_item_id
            WHERE d.child_work_item_id=? AND d.dependency_role='Q08_INPUT'
            """,
            (str(work_item_id),),
        ).fetchone()
        if dependency is None:
            raise RunnerError("Q09 work item has no bound Q08_INPUT dependency")
        q08_id = str(dependency["parent_work_item_id"])
        q08_hash = str(dependency["parent_evidence_sha256"])
        if (
            dependency["phase"] != "Q08"
            or dependency["status"] != "done"
            or dependency["verdict"] != "PASS"
        ):
            raise RunnerError("Q09 Q08_INPUT dependency is not a done PASS")
        q08_path = Path(str(dependency["evidence_path"] or ""))
        _verify_hash(q08_path, q08_hash, "Q08 dependency evidence")
        identities = manifest.get("identities") or {}
        if identities.get("q08_work_item_id") != q08_id:
            raise RunnerError("Q09 input manifest names a different Q08 work item")
        if identities.get("q08_evidence_sha256") != q08_hash:
            raise RunnerError("Q09 input manifest Q08 evidence hash mismatch")

        setfile_path = Path(str(item["setfile_path"] or ""))
        _verify_hash(
            setfile_path,
            str(identities.get("baseline_setfile_sha256") or ""),
            "Q09 work-item baseline setfile",
        )
        source_baseline = Path(str((manifest.get("source_paths") or {}).get("baseline_setfile", "")))
        if source_baseline.resolve() != setfile_path.resolve():
            raise RunnerError("Q09 plan baseline path differs from the work-item setfile")

        try:
            q08_payload = json.loads(str(dependency["payload_json"] or "{}"))
        except json.JSONDecodeError as exc:
            raise RunnerError("Q08 dependency payload is invalid JSON") from exc
        q07_id = str(q08_payload.get("promoted_from_work_item") or "").strip()
        if not q07_id:
            raise RunnerError("Q08 dependency does not bind its Q07 predecessor")
        q07 = connection.execute(
            "SELECT phase,status,verdict,evidence_path FROM work_items WHERE id=?",
            (q07_id,),
        ).fetchone()
        if (
            q07 is None
            or q07["phase"] != "Q07"
            or q07["status"] != "done"
            or q07["verdict"] not in {"PASS", "MULTI_SEED_PASS"}
        ):
            raise RunnerError("bound Q07 predecessor is not a completed seed-stability PASS")
        q07_path = Path(str(q07["evidence_path"] or ""))
        if not q07_path.is_file():
            raise RunnerError("bound Q07 seed-stability evidence is missing")
        q07_hash = contract.sha256_file(q07_path)

        calendar_manifest = Path(
            str((manifest.get("source_paths") or {}).get("calendar_manifest", ""))
        )
        try:
            verified_calendar = calendar_bundle.verify_bundle(calendar_manifest.parent)
        except calendar_bundle.CalendarBundleError as exc:
            raise RunnerError(f"calendar bundle verification failed during binding: {exc}") from exc
        calendar_id = str(verified_calendar["bundle_id"])
        registered = connection.execute(
            """
            SELECT manifest_sha256,content_sha256 FROM news_calendar_bundles
            WHERE bundle_id=?
            """,
            (calendar_id,),
        ).fetchone()
        if registered is None:
            news_schema.record_calendar_bundle(
                connection, verified_calendar, str(calendar_manifest.resolve())
            )
        elif (
            registered["manifest_sha256"] != verified_calendar["manifest_sha256"]
            or registered["content_sha256"] != verified_calendar["content_sha256"]
        ):
            raise RunnerError("registered calendar bundle contradicts sealed plan")

        try:
            payload = json.loads(str(item["payload_json"] or "{}"))
        except json.JSONDecodeError as exc:
            raise RunnerError("Q09 work-item payload is invalid JSON") from exc
        binding_updates = {
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_run_plan_path": str(plan_path),
            "q09_run_plan_file_sha256": contract.sha256_file(plan_path),
            "q09_run_plan_sha256": plan["plan_sha256"],
            "q09_input_manifest_sha256": plan["input_manifest_sha256"],
            "q09_q08_work_item_id": q08_id,
            "q09_q08_evidence_sha256": q08_hash,
            "q09_q07_work_item_id": q07_id,
            "q09_q07_evidence_path": str(q07_path.resolve()),
            "q09_q07_evidence_sha256": q07_hash,
            "q09_cell_count": int(plan["cell_count"]),
            "q09_cell_timeout_sec": timeout_sec,
        }
        payload.update(binding_updates)
        payload["q09_dispatch_binding_sha256"] = _dispatch_binding_sha256(payload)
        payload["timeout_min"] = max(int(payload.get("timeout_min") or 0), timeout_min)
        payload["q09_plan_bound_at"] = datetime.now(timezone.utc).isoformat()
        connection.execute(
            "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
            (
                json.dumps(payload, sort_keys=True),
                datetime.now(timezone.utc).isoformat(),
                str(work_item_id),
            ),
        )
        connection.commit()
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()
    return {
        "bound": True,
        "work_item_id": str(work_item_id),
        "plan_path": str(plan_path),
        "plan_file_sha256": contract.sha256_file(plan_path),
        "plan_sha256": plan["plan_sha256"],
        "cell_count": int(plan["cell_count"]),
        "cell_timeout_sec": timeout_sec,
        "timeout_min": timeout_min,
        "dispatch_binding_sha256": payload["q09_dispatch_binding_sha256"],
        "next_action": "ordinary factory pump/terminal worker may now claim this pending Q09_NEWS row",
    }


def _receipt_to_cell(spec: Mapping[str, Any]) -> dict[str, Any]:
    receipt_path = Path(spec["receipt_path"])
    receipt = _load_json(receipt_path, f"cell receipt {receipt_path}")
    if receipt.get("schema_version") != CELL_RECEIPT_SCHEMA:
        raise RunnerError(f"unsupported cell receipt schema: {receipt_path}")
    for field in ("run_identity_sha256", "paired_base_identity_sha256", "arm", "temporal_mode", "compliance_mode", "seed"):
        if receipt.get(field) != spec.get(field):
            raise RunnerError(f"cell receipt {field} mismatch: {receipt_path}")
    if receipt.get("requested_seed") != spec["seed"] or receipt.get("effective_seed") != spec["seed"]:
        raise RunnerError(f"cell receipt seed authentication failed: {receipt_path}")
    _verify_hash(Path(spec["setfile_path"]), str(spec["setfile_sha256"]), "planned cell setfile")
    if receipt.get("setfile_sha256") != spec["setfile_sha256"]:
        raise RunnerError(f"cell receipt setfile hash mismatch: {receipt_path}")
    artifact_hashes: dict[str, str] = {}
    artifact_paths: dict[str, Path] = {}
    for role in ("report", "evidence"):
        path_field = f"{role}_path"
        hash_field = f"{role}_sha256"
        path = Path(str(receipt.get(path_field, "")))
        expected = str(receipt.get(hash_field, ""))
        _verify_hash(path, expected, f"cell {role}")
        artifact_hashes[hash_field] = expected
        artifact_paths[role] = path
    flat_receipt_hash: str | None = None
    if receipt.get("flat_at_event_receipt_path") or receipt.get("flat_at_event_receipt_sha256"):
        flat_path = Path(str(receipt.get("flat_at_event_receipt_path", "")))
        flat_receipt_hash = str(receipt.get("flat_at_event_receipt_sha256", ""))
        _verify_hash(flat_path, flat_receipt_hash, "flat-at-event receipt")
    metrics = receipt.get("metrics")
    if not isinstance(metrics, Mapping) or not all(key in metrics for key in ("selection", "holdout", "full")):
        raise RunnerError(f"cell receipt metrics incomplete: {receipt_path}")
    evidence_document = _load_json(artifact_paths["evidence"], f"cell evidence {artifact_paths['evidence']}")
    if evidence_document.get("schema_version") != CELL_EVIDENCE_SCHEMA:
        raise RunnerError(f"unsupported cell evidence schema: {artifact_paths['evidence']}")
    evidence_bindings = {
        "run_identity_sha256": spec["run_identity_sha256"],
        "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
        "requested_seed": spec["seed"],
        "effective_seed": spec["seed"],
        "setfile_sha256": spec["setfile_sha256"],
        "report_sha256": artifact_hashes["report_sha256"],
    }
    for field, expected in evidence_bindings.items():
        if evidence_document.get(field) != expected:
            raise RunnerError(f"cell evidence {field} mismatch: {artifact_paths['evidence']}")
    if evidence_document.get("metrics") != metrics:
        raise RunnerError(f"cell receipt metrics contradict hashed cell evidence: {receipt_path}")
    if evidence_document.get("q07_seed_stability_pass") != receipt.get("q07_seed_stability_pass"):
        raise RunnerError(f"cell Q07 stability receipt contradicts hashed evidence: {receipt_path}")
    if evidence_document.get("flat_at_event_receipt_sha256") != flat_receipt_hash:
        raise RunnerError(f"cell flat-at-event receipt contradicts hashed evidence: {receipt_path}")
    return {
        "arm": spec["arm"],
        "temporal_mode": spec["temporal_mode"],
        "compliance_mode": spec["compliance_mode"],
        "seed": spec["seed"],
        "requested_seed": receipt["requested_seed"],
        "effective_seed": receipt["effective_seed"],
        "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
        "run_identity_sha256": spec["run_identity_sha256"],
        "setfile_sha256": spec["setfile_sha256"],
        "evidence_sha256": artifact_hashes["evidence_sha256"],
        "report_sha256": artifact_hashes["report_sha256"],
        "selection": metrics["selection"],
        "holdout": metrics["holdout"],
        "full": metrics["full"],
        "q07_seed_stability_pass": receipt.get("q07_seed_stability_pass"),
        "flat_at_event_receipt_sha256": flat_receipt_hash,
    }


def _evidence_payload(
    input_manifest: Mapping[str, Any],
    cells: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    return {
        "schema_version": contract.SCHEMA_VERSION,
        "work_item_id": input_manifest["work_item_id"],
        "deployment_target": input_manifest["deployment_target"],
        "identities": input_manifest["identities"],
        "calendar_bundle": {
            key: input_manifest["calendar_bundle"][key]
            for key in (
                "bundle_id", "manifest_sha256", "content_sha256",
                "coverage_from_utc", "coverage_to_utc",
            )
        },
        "windows": input_manifest["windows"],
        "news_or_event_strategy": input_manifest["news_or_event_strategy"],
        "cells": list(cells),
    }


def _nonlocking_adjudication(
    *,
    verdict: str,
    reason_code: str,
    input_manifest: Mapping[str, Any],
    details: Mapping[str, Any],
) -> dict[str, Any]:
    if verdict not in {"REVIEW_REQUIRED", "INVALID_EVIDENCE"}:
        raise RunnerError("non-locking Q09 adjudication verdict is invalid")
    result: dict[str, Any] = {
        "schema_version": contract.ADJUDICATION_SCHEMA_VERSION,
        "verdict": verdict,
        "reason_codes": [reason_code],
        "target_compliance": contract.compliance_for_target(
            str(input_manifest["deployment_target"])
        ),
        "matrix_scope": input_manifest["matrix_scope"],
        "chosen_config": None,
        "locked_arms": [],
        "details": dict(details),
    }
    result["adjudication_sha256"] = contract.sha256_bytes(
        contract.canonical_json_bytes(result)
    )
    return result


def _publish_collection(
    *,
    payload: Mapping[str, Any],
    adjudication: Mapping[str, Any],
    output_root: Path,
) -> dict[str, Any]:
    destination = output_root.resolve()
    evidence_path = destination / "q09_news_evidence.json"
    aggregate_path = destination / "aggregate.json"
    _atomic_write(evidence_path, contract.canonical_json_bytes(payload))
    _atomic_write(aggregate_path, contract.canonical_json_bytes(adjudication))
    return {
        "verdict": adjudication["verdict"],
        "adjudication": dict(adjudication),
        "evidence_path": str(evidence_path),
        "evidence_sha256": contract.sha256_file(evidence_path),
        "aggregate_path": str(aggregate_path),
        "aggregate_sha256": contract.sha256_file(aggregate_path),
    }


def collect_run_plan(plan_path: Path, *, output_root: Path | None = None) -> dict[str, Any]:
    plan, input_manifest = load_authenticated_plan(plan_path)
    cells = [_receipt_to_cell(spec) for spec in plan["cells"]]
    payload = _evidence_payload(input_manifest, cells)
    result = contract.adjudicate(payload)
    return _publish_collection(
        payload=payload,
        adjudication=result,
        output_root=output_root or plan_path.parent,
    )


def collect_run_plan_status(
    plan_path: Path,
    *,
    output_root: Path | None = None,
    expected_plan_file_sha256: str | None = None,
) -> dict[str, Any]:
    """Publish a truthful terminal result for complete, partial, or bad cells.

    Plan/hash/source drift still raises and produces no adjudication. Missing
    receipts are a recoverable execution result; contradictory receipts are
    immutable evidence failures. Neither path can call the selector.
    """

    plan, input_manifest = load_authenticated_plan(
        plan_path,
        expected_file_sha256=expected_plan_file_sha256,
    )
    cells: list[dict[str, Any]] = []
    missing: list[str] = []
    invalid: list[dict[str, str]] = []
    for spec in plan["cells"]:
        receipt_path = Path(str(spec["receipt_path"]))
        cell_id = str(spec["run_identity_sha256"])
        if not receipt_path.is_file():
            missing.append(cell_id)
            continue
        try:
            cells.append(_receipt_to_cell(spec))
        except RunnerError as exc:
            invalid.append({"run_identity_sha256": cell_id, "error": str(exc)})
    payload = _evidence_payload(input_manifest, cells)
    if invalid:
        adjudication = _nonlocking_adjudication(
            verdict="INVALID_EVIDENCE",
            reason_code="cell_receipt_invalid",
            input_manifest=input_manifest,
            details={
                "planned_cell_count": int(plan["cell_count"]),
                "authenticated_cell_count": len(cells),
                "missing_cell_count": len(missing),
                "invalid_cells": invalid,
            },
        )
    elif missing:
        adjudication = _nonlocking_adjudication(
            verdict="REVIEW_REQUIRED",
            reason_code="partial_cell_execution",
            input_manifest=input_manifest,
            details={
                "planned_cell_count": int(plan["cell_count"]),
                "authenticated_cell_count": len(cells),
                "missing_cell_count": len(missing),
                "missing_run_identity_sha256": missing,
            },
        )
    else:
        adjudication = contract.adjudicate(payload)
    result = _publish_collection(
        payload=payload,
        adjudication=adjudication,
        output_root=output_root or plan_path.parent,
    )
    result.update({
        "planned_cell_count": int(plan["cell_count"]),
        "authenticated_cell_count": len(cells),
        "missing_cell_count": len(missing),
        "invalid_cell_count": len(invalid),
    })
    return result


def assert_factory_capacity(
    farm_root: Path,
    *,
    work_item_id: str,
    terminal: str,
    plan_path: Path,
    expected_plan_file_sha256: str,
) -> dict[str, Any]:
    """Prove that this process owns the active ordinary factory slot."""

    database = _farm_db_path(farm_root)
    if not database.is_file():
        raise CapacityError(f"strategy-farm database missing: {database}")
    connection = sqlite3.connect(str(database), timeout=10)
    connection.row_factory = sqlite3.Row
    try:
        row = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (str(work_item_id),)
        ).fetchone()
    finally:
        connection.close()
    if row is None:
        raise CapacityError("Q09 factory capacity refused: work item missing")
    if row["phase"] != "Q09_NEWS":
        raise CapacityError("Q09 factory capacity refused: non-canonical phase")
    if row["status"] != "active" or str(row["claimed_by"] or "") != str(terminal):
        raise CapacityError(
            "Q09 factory capacity refused: exact active terminal claim is not owned"
        )
    try:
        payload = json.loads(str(row["payload_json"] or "{}"))
    except json.JSONDecodeError as exc:
        raise CapacityError("Q09 factory capacity refused: payload is invalid JSON") from exc
    if payload.get("q09_binding_version") != "q09-news-dispatch-binding/v1":
        raise CapacityError("Q09 factory capacity refused: sealed dispatch binding missing")
    bound_path = Path(str(payload.get("q09_run_plan_path") or ""))
    if bound_path.resolve() != plan_path.resolve():
        raise CapacityError("Q09 factory capacity refused: run-plan path differs from binding")
    expected = str(expected_plan_file_sha256).strip().lower()
    if payload.get("q09_run_plan_file_sha256") != expected:
        raise CapacityError("Q09 factory capacity refused: run-plan hash differs from binding")
    _verify_hash(plan_path.resolve(), expected, "bound Q09 run-plan")
    actual_binding = _dispatch_binding_sha256(payload)
    if payload.get("q09_dispatch_binding_sha256") != actual_binding:
        raise CapacityError("Q09 factory capacity refused: dispatch binding hash mismatch")
    q07_path = Path(str(payload.get("q09_q07_evidence_path") or ""))
    _verify_hash(
        q07_path,
        str(payload.get("q09_q07_evidence_sha256") or ""),
        "bound Q07 seed-stability evidence",
    )
    return {"row": dict(row), "payload": payload}


def _setfile_values(path: Path) -> dict[str, str]:
    text, _, _ = _decode_setfile(path.read_bytes())
    values: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, raw_value = line.split("=", 1)
        values[key.strip().casefold()] = raw_value.split("||", 1)[0].strip()
    return values


def _required_float(values: Mapping[str, str], key: str) -> float:
    raw = values.get(key.casefold())
    if raw is None:
        raise RunnerError(f"Q09 setfile is missing required {key}")
    try:
        value = float(raw)
    except ValueError as exc:
        raise RunnerError(f"Q09 setfile {key} is not numeric") from exc
    if not math.isfinite(value):
        raise RunnerError(f"Q09 setfile {key} is not finite")
    return value


def _validate_cell_setfile(
    spec: Mapping[str, Any],
    input_manifest: Mapping[str, Any],
) -> float:
    path = Path(str(spec["setfile_path"]))
    _verify_hash(path, str(spec["setfile_sha256"]), "planned Q09 cell setfile")
    values = _setfile_values(path)
    risk_fixed = _required_float(values, "RISK_FIXED")
    risk_percent = _required_float(values, "RISK_PERCENT")
    if risk_fixed <= 0 or risk_percent != 0:
        raise RunnerError("Q09 backtest setfile requires RISK_FIXED > 0 and RISK_PERCENT = 0")
    stale_raw = values.get("qm_news_stale_max_hours")
    if stale_raw is not None:
        try:
            stale_hours = float(stale_raw)
        except ValueError as exc:
            raise RunnerError("qm_news_stale_max_hours is not numeric") from exc
        if not math.isfinite(stale_hours) or stale_hours > 336:
            raise RunnerError("qm_news_stale_max_hours exceeds the hard 336-hour maximum")
    expected = {
        "qm_rng_seed": str(spec["seed"]),
        "qm_news_temporal": str(contract.TEMPORAL_MODE_IDS[str(spec["temporal_mode"])]),
        "qm_news_compliance": str(COMPLIANCE_MODE_IDS[str(spec["compliance_mode"])]),
        "qm_news_calendar_bundle_id": str(input_manifest["calendar_bundle"]["bundle_id"]),
        "qm_news_calendar_expected_sha256": str(
            input_manifest["calendar_bundle"]["content_sha256"]
        ),
        "qm_news_calendar_common_relative_path": str(
            input_manifest["calendar_bundle"]["common_relative_path"]
        ),
    }
    for key, value in expected.items():
        if values.get(key.casefold()) != value:
            raise RunnerError(f"planned Q09 cell setfile has wrong {key}")
    return risk_fixed


def _parse_utc(value: str, field: str) -> datetime:
    text = str(value).strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError as exc:
        raise RunnerError(f"{field} is not ISO-8601") from exc
    if parsed.tzinfo is None:
        raise RunnerError(f"{field} must include a UTC offset")
    return parsed.astimezone(timezone.utc)


def _mt5_date(value: str, field: str) -> str:
    return _parse_utc(value, field).strftime("%Y.%m.%d")


def _read_report_html(path: Path) -> str:
    raw = path.read_bytes()
    encodings = (
        ("utf-16",) if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else ()
    ) + ("utf-8-sig", "cp1252")
    for encoding in encodings:
        try:
            text = raw.decode(encoding)
        except (UnicodeError, LookupError):
            continue
        if "<html" in text[:1000].casefold():
            return text
    raise RunnerError(f"cannot decode MT5 report: {path}")


def _settings_row_label(row_html: str) -> str | None:
    match = re.search(
        r'<td\b[^>]*\bcolspan\s*=\s*["\']?3(?!\d)[^>]*>(.*?)</td>',
        row_html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if match is None:
        return None
    return html.unescape(re.sub(r"<[^>]+>", "", match.group(1))).strip().rstrip(":").strip()


def _report_inputs_region(report_html: str) -> str:
    rows = list(re.finditer(r"<tr\b.*?</tr>", report_html, flags=re.IGNORECASE | re.DOTALL))
    start: int | None = None
    for index, row in enumerate(rows):
        label = _settings_row_label(row.group(0))
        if label is not None and label.casefold() == "inputs":
            start = index
            break
    if start is None:
        raise RunnerError("MT5 report has no scoped Inputs region")
    parts = [rows[start].group(0)]
    for row in rows[start + 1:]:
        label = _settings_row_label(row.group(0))
        if label is None or label != "":
            break
        parts.append(row.group(0))
    return "".join(parts)


def _report_inputs(path: Path) -> dict[str, str]:
    region = _report_inputs_region(_read_report_html(path))
    values: dict[str, str] = {}
    for raw in re.findall(r"<b>\s*([^<>]+?=[^<>]*?)\s*</b>", region, re.IGNORECASE):
        key, value = html.unescape(raw).split("=", 1)
        values[key.strip().casefold()] = value.strip()
    if not values:
        raise RunnerError("MT5 report Inputs region contains no effective inputs")
    return values


def _validate_report_effective_inputs(
    path: Path,
    *,
    spec: Mapping[str, Any],
    input_manifest: Mapping[str, Any],
    risk_fixed: float,
) -> dict[str, str]:
    """Authenticate the EA inputs MT5 says were effective for one Q09 cell."""

    effective = _report_inputs(path)
    expected_inputs = {
        "qm_rng_seed": str(spec["seed"]),
        "qm_news_temporal": str(contract.TEMPORAL_MODE_IDS[str(spec["temporal_mode"])]),
        "qm_news_compliance": str(COMPLIANCE_MODE_IDS[str(spec["compliance_mode"])]),
        "qm_news_calendar_bundle_id": str(input_manifest["calendar_bundle"]["bundle_id"]),
        "qm_news_calendar_expected_sha256": str(
            input_manifest["calendar_bundle"]["content_sha256"]
        ),
        "qm_news_calendar_common_relative_path": str(
            input_manifest["calendar_bundle"]["common_relative_path"]
        ),
    }
    for key, expected in expected_inputs.items():
        if effective.get(key.casefold()) != expected:
            raise RunnerError(f"MT5 report effective input {key} mismatch")
    if _required_float(effective, "RISK_FIXED") != risk_fixed:
        raise RunnerError("MT5 report effective RISK_FIXED mismatch")
    if _required_float(effective, "RISK_PERCENT") != 0:
        raise RunnerError("MT5 report effective RISK_PERCENT is not zero")
    stale = effective.get("qm_news_stale_max_hours")
    if stale is not None and _required_float(effective, "qm_news_stale_max_hours") > 336:
        raise RunnerError("MT5 report weakens the 336-hour stale-news guard")
    return effective


def _report_cell_after(path: Path, label: str) -> str:
    report_html = _read_report_html(path)
    for row_match in re.finditer(r"<tr\b.*?</tr>", report_html, re.IGNORECASE | re.DOTALL):
        cells = [
            html.unescape(re.sub(r"<[^>]+>", "", raw)).strip()
            for raw in re.findall(
                r"<td\b[^>]*>(.*?)</td>", row_match.group(0), re.IGNORECASE | re.DOTALL
            )
        ]
        for index, cell in enumerate(cells[:-1]):
            if cell.strip().rstrip(":").casefold() == label.casefold():
                return cells[index + 1]
    raise RunnerError(f"MT5 report metric missing: {label}")


def _finite_report_number(raw: Any, field: str) -> float:
    text = str(raw or "").replace("\xa0", " ").strip()
    match = re.search(r"-?[\d\s.,]+", text)
    if not match:
        raise RunnerError(f"MT5 report {field} is missing")
    token = match.group(0).replace(" ", "")
    if "," in token and "." in token:
        token = token.replace(",", "")
    elif "," in token:
        token = token.replace(",", ".")
    try:
        value = float(token)
    except ValueError as exc:
        raise RunnerError(f"MT5 report {field} is not numeric") from exc
    if not math.isfinite(value):
        raise RunnerError(f"MT5 report {field} is not finite")
    return value


def _drawdown_percent(path: Path) -> float:
    raw = _report_cell_after(path, "Equity Drawdown Maximal")
    match = re.search(r"\((-?[\d\s.,]+)%\)", raw)
    if not match:
        raise RunnerError("MT5 report equity drawdown percentage is missing")
    return _finite_report_number(match.group(1), "equity drawdown percentage")


def _logger_entry_counts(path: Path, *, control: bool) -> tuple[int, int, int]:
    if not path.is_file():
        raise RunnerError("run_smoke logger sample is missing")
    accepted = 0
    news_blocked = 0
    with path.open("r", encoding="utf-8-sig", errors="strict") as handle:
        for line_number, line in enumerate(handle, start=1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise RunnerError(f"logger sample line {line_number} is invalid JSON") from exc
            event = str(row.get("event") or "").upper()
            payload = row.get("payload")
            if isinstance(payload, str):
                try:
                    payload = json.loads(payload)
                except json.JSONDecodeError:
                    payload = {}
            if not isinstance(payload, Mapping):
                payload = {}
            if event == "ENTRY_ACCEPTED":
                accepted += 1
            elif event == "ENTRY_REJECTED" and (
                str(payload.get("result") or "").upper() == "QM_ENTRY_REJECTED_NEWS"
                or str(payload.get("detail") or "").casefold() == "news_filter_block"
            ):
                news_blocked += 1
    if control and news_blocked:
        raise RunnerError("CONTROL_OFF logger contains news-filter rejections")
    return accepted + news_blocked, news_blocked, news_blocked


def _latest_summary(report_root: Path, started_at: float) -> Path:
    candidates = [
        path for path in report_root.rglob("summary.json")
        if path.stat().st_mtime >= started_at - 2
    ]
    if not candidates:
        raise RunnerError("run_smoke produced no fresh summary")
    return max(candidates, key=lambda path: path.stat().st_mtime)


def _validate_window_summary(
    summary_path: Path,
    *,
    spec: Mapping[str, Any],
    input_manifest: Mapping[str, Any],
    terminal: str,
    ea_id: int,
    expert: str,
    symbol: str,
    period: str,
    from_date: str,
    to_date: str,
    risk_fixed: float,
) -> tuple[dict[str, Any], dict[str, Any]]:
    summary = _load_json(summary_path, "run_smoke summary")
    exact = {
        "evidence_schema": "run_smoke/v2",
        "result": "PASS",
        "terminal": terminal,
        "ea_id": ea_id,
        "expert": expert,
        "symbol": symbol,
        "period": period,
        "from_date": from_date,
        "to_date": to_date,
        "model": 4,
        "requested_runs": 1,
    }
    for field, expected in exact.items():
        if summary.get(field) != expected:
            raise RunnerError(f"run_smoke summary {field} mismatch")
    if (
        summary.get("model4_log_marker_detected") is not True
        or summary.get("deterministic") is not True
        or summary.get("oninit_failure_detected") is not False
    ):
        raise RunnerError("run_smoke real-tick/determinism/OnInit evidence failed")
    identity = summary.get("execution_identity")
    if not isinstance(identity, Mapping) or identity.get("stable_during_run") is not True:
        raise RunnerError("run_smoke execution identity is missing or unstable")
    expert_identity = identity.get("expert_binary") or {}
    set_identity = identity.get("setfile") or {}
    deployed_ex5 = expert_identity.get("deployed") or {}
    source_set = set_identity.get("source") or {}
    if (
        expert_identity.get("stable_during_run") is not True
        or set_identity.get("stable_during_run") is not True
        or deployed_ex5.get("sha256") != input_manifest["identities"]["ex5_sha256"]
        or source_set.get("sha256") != spec["setfile_sha256"]
    ):
        raise RunnerError("run_smoke EX5/setfile identity authentication failed")
    runs = summary.get("runs")
    if not isinstance(runs, list) or len(runs) != 1 or runs[0].get("status") != "OK":
        raise RunnerError("run_smoke did not publish exactly one authenticated OK run")
    run = runs[0]
    report_path = Path(str(run.get("report_canonical_path") or ""))
    if not report_path.is_file():
        raise RunnerError("run_smoke canonical MT5 report is missing")
    report_sha = contract.sha256_file(report_path)
    if run.get("report_sha256") != report_sha:
        raise RunnerError("run_smoke report SHA-256 mismatch")
    _validate_report_effective_inputs(
        report_path,
        spec=spec,
        input_manifest=input_manifest,
        risk_fixed=risk_fixed,
    )
    logger_path = Path(str(summary.get("logger_sample_path") or ""))
    logger_meta = summary.get("logger_sample") or {}
    if (
        not logger_path.is_file()
        or logger_meta.get("exact_byte_copy") is not True
        or logger_meta.get("sha256") != contract.sha256_file(logger_path)
    ):
        raise RunnerError("run_smoke logger sample authentication failed")
    original, blocked, affected = _logger_entry_counts(
        logger_path, control=str(spec["arm"]) == "CONTROL_OFF"
    )
    trades = int(run.get("total_trades"))
    if trades > 0 and original == 0:
        raise RunnerError("MT5 trades exist but the framework entry stream is empty")
    profit_factor = _finite_report_number(run.get("profit_factor"), "profit factor")
    net_profit = _finite_report_number(run.get("net_profit"), "net profit")
    sharpe = _finite_report_number(_report_cell_after(report_path, "Sharpe Ratio"), "Sharpe ratio")
    report_trades = int(_finite_report_number(_report_cell_after(report_path, "Total Trades"), "total trades"))
    if report_trades != trades:
        raise RunnerError("run_smoke and MT5 report trade totals disagree")
    commission_group = summary.get("commission_group")
    if not isinstance(commission_group, Mapping):
        raise RunnerError("run_smoke commission-group evidence is missing")
    if (
        commission_group.get("commission_per_lot") != 0
        or commission_group.get("commission_per_side_native") != 0
        or commission_group.get("restored_to_canonical") is not True
        or not re.fullmatch(
            r"[0-9a-f]{64}", str(commission_group.get("injected_sha256") or "")
        )
        or commission_group.get("injected_sha256")
        != commission_group.get("canonical_sha256")
        or commission_group.get("restored_sha256")
        != commission_group.get("canonical_sha256")
    ):
        raise RunnerError("run_smoke canonical commission-group identity failed")
    cost_execution_identity = {
        key: commission_group.get(key)
        for key in (
            "commission_per_lot", "commission_per_side_native",
            "commission_matcher", "commission_mode", "injected_sha256",
            "canonical_sha256", "restored_sha256",
        )
    }
    metrics = {
        "trades": trades,
        "profit_factor": profit_factor,
        "drawdown_pct": _drawdown_percent(report_path),
        "sharpe": sharpe,
        "net_r": net_profit / risk_fixed,
        "original_entries": original,
        "blocked_entries": blocked,
        "affected_entries": affected,
    }
    artifacts = {
        "summary_path": str(summary_path.resolve()),
        "summary_sha256": contract.sha256_file(summary_path),
        "report_path": str(report_path.resolve()),
        "report_sha256": report_sha,
        "logger_sample_path": str(logger_path.resolve()),
        "logger_sample_sha256": contract.sha256_file(logger_path),
        "commission_group": dict(commission_group),
        "cost_execution_identity_sha256": contract.sha256_bytes(
            contract.canonical_json_bytes(cost_execution_identity)
        ),
        "news_calendar": summary.get("news_calendar"),
    }
    return metrics, artifacts


def _production_dispatch_cell(
    spec: Mapping[str, Any],
    context: Mapping[str, Any],
) -> None:
    manifest = context["input_manifest"]
    risk_fixed = _validate_cell_setfile(spec, manifest)
    windows = manifest["windows"]
    bounds = {
        "selection": (windows["selection_from_utc"], windows["selection_to_utc"]),
        "holdout": (windows["holdout_from_utc"], windows["holdout_to_utc"]),
        "full": (windows["full_from_utc"], windows["full_to_utc"]),
    }
    metrics: dict[str, Any] = {}
    artifacts: dict[str, Any] = {}
    ea_id = int(context["ea_id"])
    for window_name in WINDOW_NAMES:
        assert_factory_capacity(
            Path(context["farm_root"]),
            work_item_id=str(context["work_item_id"]),
            terminal=str(context["terminal"]),
            plan_path=Path(context["plan_path"]),
            expected_plan_file_sha256=str(context["expected_plan_file_sha256"]),
        )
        raw_from, raw_to = bounds[window_name]
        from_date = _mt5_date(str(raw_from), f"{window_name}_from_utc")
        to_date = _mt5_date(str(raw_to), f"{window_name}_to_utc")
        run_root = Path(str(spec["receipt_path"])).parent / "runs" / window_name
        run_root.mkdir(parents=True, exist_ok=True)
        run_log = run_root / "run_smoke.log"
        command = [
            "pwsh.exe", "-NoProfile", "-File", str(context["run_smoke_path"]),
            "-EAId", str(ea_id), "-Expert", str(context["expert"]),
            "-Symbol", str(context["symbol"]), "-Year", to_date[:4],
            "-FromDate", from_date, "-ToDate", to_date,
            "-Terminal", str(context["terminal"]), "-Period", str(context["period"]),
            "-Runs", "1", "-MinTrades", "0", "-Model", "4",
            "-TimeoutSeconds", str(context["cell_timeout_sec"]),
            "-SetFile", str(spec["setfile_path"]), "-ReportRoot", str(run_root),
            "-DispatchPhase", "Q09_NEWS", "-DispatchVersion", "q09_news_executor_v1",
            "-DispatchSubGateHash", f"{str(spec['run_identity_sha256'])[:16]}_{window_name}",
        ]
        started_at = datetime.now(timezone.utc).timestamp()
        creationflags = 0x08000000 if sys.platform == "win32" else 0
        try:
            completed = subprocess.run(
                command,
                cwd=str(context["repo_root"]),
                capture_output=True,
                text=True,
                timeout=int(context["cell_timeout_sec"]) + CELL_TIMEOUT_HEADROOM_SEC,
                creationflags=creationflags,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:
            raise RunnerError(f"Q09 {window_name} run_smoke process timed out") from exc
        _atomic_write(
            run_log,
            ((completed.stdout or "") + (completed.stderr or "")).encode("utf-8", errors="replace"),
        )
        if completed.returncode != 0:
            raise RunnerError(
                f"Q09 {window_name} run_smoke exited with code {completed.returncode}"
            )
        summary_path = _latest_summary(run_root, started_at)
        metrics[window_name], artifacts[window_name] = _validate_window_summary(
            summary_path,
            spec=spec,
            input_manifest=manifest,
            terminal=str(context["terminal"]),
            ea_id=ea_id,
            expert=str(context["expert"]),
            symbol=str(context["symbol"]),
            period=str(context["period"]),
            from_date=from_date,
            to_date=to_date,
            risk_fixed=risk_fixed,
        )
        observed_cost_identity = artifacts[window_name]["cost_execution_identity_sha256"]
        expected_cost_identity = context.get("cost_execution_identity_sha256")
        if expected_cost_identity is None:
            if isinstance(context, dict):
                context["cost_execution_identity_sha256"] = observed_cost_identity
        elif observed_cost_identity != expected_cost_identity:
            raise RunnerError("Q09 cells do not share one canonical cost execution identity")
        artifacts[window_name]["run_smoke_log_path"] = str(run_log.resolve())
        artifacts[window_name]["run_smoke_log_sha256"] = contract.sha256_file(run_log)

    cell_dir = Path(str(spec["receipt_path"])).parent
    report_manifest_path = cell_dir / "report_manifest.json"
    report_manifest = {
        "schema_version": "q09-news-cell-report-manifest/v1",
        "run_identity_sha256": spec["run_identity_sha256"],
        "tester_model": manifest["tester_model"],
        "cost_profile": manifest["cost_profile"],
        "windows": artifacts,
    }
    _write_immutable(report_manifest_path, contract.canonical_json_bytes(report_manifest))
    report_sha = contract.sha256_file(report_manifest_path)
    evidence_path = cell_dir / "cell_evidence.json"
    evidence = {
        "schema_version": CELL_EVIDENCE_SCHEMA,
        "run_identity_sha256": spec["run_identity_sha256"],
        "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
        "requested_seed": spec["seed"],
        "effective_seed": spec["seed"],
        "setfile_sha256": spec["setfile_sha256"],
        "report_sha256": report_sha,
        "metrics": metrics,
        "q07_seed_stability_pass": True,
        "q07_work_item_id": context["q07_work_item_id"],
        "q07_evidence_sha256": context["q07_evidence_sha256"],
        "flat_at_event_receipt_sha256": None,
        "execution_contract": "FACTORY_RESERVED_RUN_SMOKE_MODEL4_THREE_WINDOWS_V1",
        "cost_profile": manifest["cost_profile"],
        "cost_execution_identity_sha256": context.get("cost_execution_identity_sha256"),
    }
    _write_immutable(evidence_path, contract.canonical_json_bytes(evidence))
    receipt = {
        "schema_version": CELL_RECEIPT_SCHEMA,
        "run_identity_sha256": spec["run_identity_sha256"],
        "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
        "arm": spec["arm"],
        "temporal_mode": spec["temporal_mode"],
        "compliance_mode": spec["compliance_mode"],
        "seed": spec["seed"],
        "requested_seed": spec["seed"],
        "effective_seed": spec["seed"],
        "setfile_sha256": spec["setfile_sha256"],
        "report_path": str(report_manifest_path.resolve()),
        "report_sha256": report_sha,
        "evidence_path": str(evidence_path.resolve()),
        "evidence_sha256": contract.sha256_file(evidence_path),
        "metrics": metrics,
        "q07_seed_stability_pass": True,
    }
    _write_immutable(
        Path(str(spec["receipt_path"])), contract.canonical_json_bytes(receipt)
    )


def _persist_q09_result(
    farm_root: Path,
    *,
    work_item_id: str,
    terminal: str,
    plan_path: Path,
    expected_plan_file_sha256: str,
    result: Mapping[str, Any],
) -> dict[str, Any]:
    assert_factory_capacity(
        farm_root,
        work_item_id=work_item_id,
        terminal=terminal,
        plan_path=plan_path,
        expected_plan_file_sha256=expected_plan_file_sha256,
    )
    evidence_payload = _load_json(Path(str(result["evidence_path"])), "Q09 evidence")
    adjudication = _load_json(Path(str(result["aggregate_path"])), "Q09 adjudication")
    database = _farm_db_path(farm_root)
    connection = sqlite3.connect(str(database), timeout=30)
    connection.row_factory = sqlite3.Row
    try:
        existing = connection.execute(
            "SELECT verdict,aggregate_path,aggregate_sha256 FROM q09_news_tests WHERE work_item_id=?",
            (str(work_item_id),),
        ).fetchone()
        if existing is not None:
            if (
                existing["verdict"] != result["verdict"]
                or Path(str(existing["aggregate_path"])).resolve()
                != Path(str(result["aggregate_path"])).resolve()
                or existing["aggregate_sha256"] != result["aggregate_sha256"]
            ):
                raise RunnerError("existing immutable Q09 adjudication contradicts executor result")
            return {"status": "ALREADY_RECORDED", "verdict": existing["verdict"]}
        news_schema.record_q09_adjudication(
            connection,
            evidence_payload=evidence_payload,
            adjudication=adjudication,
            aggregate_path=str(result["aggregate_path"]),
            aggregate_sha256=str(result["aggregate_sha256"]),
        )
        recorded = connection.execute(
            "SELECT verdict,aggregate_sha256 FROM q09_news_tests WHERE work_item_id=?",
            (str(work_item_id),),
        ).fetchone()
        if recorded is None or recorded["aggregate_sha256"] != result["aggregate_sha256"]:
            raise RunnerError("Q09 adjudication sidecar verification failed")
        return {"status": "RECORDED", "verdict": recorded["verdict"]}
    finally:
        connection.close()


def execute_run_plan(
    plan_path: Path,
    *,
    output_root: Path,
    farm_root: Path,
    work_item_id: str,
    terminal: str,
    expected_plan_file_sha256: str,
    ea_id: int,
    expert: str,
    symbol: str,
    work_item_symbol: str | None,
    period: str,
    repo_root: Path,
    common_root: Path,
    dispatch_cell: Callable[[Mapping[str, Any], Mapping[str, Any]], None] | None = None,
) -> dict[str, Any]:
    """Execute missing plan cells serially inside one claimed factory slot."""

    plan_path = plan_path.resolve()
    plan, input_manifest = load_authenticated_plan(
        plan_path,
        expected_file_sha256=expected_plan_file_sha256,
    )
    if str(plan["work_item_id"]) != str(work_item_id):
        raise RunnerError("executor work_item_id differs from sealed run plan")
    capacity = assert_factory_capacity(
        farm_root,
        work_item_id=work_item_id,
        terminal=terminal,
        plan_path=plan_path,
        expected_plan_file_sha256=expected_plan_file_sha256,
    )
    payload = capacity["payload"]
    row = capacity["row"]
    if (
        payload.get("q09_run_plan_sha256") != plan.get("plan_sha256")
        or payload.get("q09_input_manifest_sha256") != plan.get("input_manifest_sha256")
        or payload.get("q09_q08_work_item_id")
        != input_manifest["identities"]["q08_work_item_id"]
        or payload.get("q09_q08_evidence_sha256")
        != input_manifest["identities"]["q08_evidence_sha256"]
        or int(payload.get("q09_cell_count") or -1) != int(plan["cell_count"])
    ):
        raise CapacityError("Q09 factory payload contradicts the authenticated run plan")
    if (
        str(row["ea_id"]) != f"QM5_{int(ea_id)}"
        or str(row["symbol"]) != str(work_item_symbol or symbol)
        or Path(str(row["setfile_path"])).resolve()
        != Path(str(input_manifest["source_paths"]["baseline_setfile"])).resolve()
    ):
        raise CapacityError("Q09 factory work-item identity differs from executor arguments")
    calendar_manifest = Path(str(input_manifest["source_paths"]["calendar_manifest"]))
    try:
        provision = calendar_bundle.provision_to_common(
            calendar_manifest.parent,
            common_root,
            str(input_manifest["calendar_bundle"]["common_relative_path"]),
        )
    except calendar_bundle.CalendarBundleError as exc:
        raise RunnerError(f"Q09 calendar Common provisioning failed: {exc}") from exc
    context: dict[str, Any] = {
        "plan_path": str(plan_path),
        "expected_plan_file_sha256": expected_plan_file_sha256,
        "input_manifest": input_manifest,
        "farm_root": str(farm_root.resolve()),
        "work_item_id": str(work_item_id),
        "terminal": str(terminal),
        "ea_id": int(ea_id),
        "expert": str(expert),
        "symbol": str(symbol),
        "period": str(period),
        "repo_root": str(repo_root.resolve()),
        "run_smoke_path": str((repo_root / "framework" / "scripts" / "run_smoke.ps1").resolve()),
        "cell_timeout_sec": int(payload["q09_cell_timeout_sec"]),
        "q07_work_item_id": payload["q09_q07_work_item_id"],
        "q07_evidence_sha256": payload["q09_q07_evidence_sha256"],
        "calendar_provision": provision,
    }
    dispatcher = dispatch_cell or _production_dispatch_cell
    for spec in plan["cells"]:
        receipt_path = Path(str(spec["receipt_path"]))
        if receipt_path.is_file():
            try:
                _receipt_to_cell(spec)
            except RunnerError:
                result = collect_run_plan_status(
                    plan_path,
                    output_root=output_root,
                    expected_plan_file_sha256=expected_plan_file_sha256,
                )
                result["sidecar"] = _persist_q09_result(
                    farm_root,
                    work_item_id=work_item_id,
                    terminal=terminal,
                    plan_path=plan_path,
                    expected_plan_file_sha256=expected_plan_file_sha256,
                    result=result,
                )
                return result
            continue
        assert_factory_capacity(
            farm_root,
            work_item_id=work_item_id,
            terminal=terminal,
            plan_path=plan_path,
            expected_plan_file_sha256=expected_plan_file_sha256,
        )
        try:
            dispatcher(spec, context)
            _receipt_to_cell(spec)
        except CapacityError:
            raise
        except Exception as exc:
            failure_path = output_root.resolve() / "execution_failure.json"
            _atomic_write(
                failure_path,
                contract.canonical_json_bytes({
                    "schema_version": "q09-news-execution-failure/v1",
                    "work_item_id": str(work_item_id),
                    "run_identity_sha256": spec["run_identity_sha256"],
                    "error_type": type(exc).__name__,
                    "error": str(exc),
                }),
            )
            result = collect_run_plan_status(
                plan_path,
                output_root=output_root,
                expected_plan_file_sha256=expected_plan_file_sha256,
            )
            result["execution_failure_path"] = str(failure_path)
            result["execution_failure_sha256"] = contract.sha256_file(failure_path)
            result["sidecar"] = _persist_q09_result(
                farm_root,
                work_item_id=work_item_id,
                terminal=terminal,
                plan_path=plan_path,
                expected_plan_file_sha256=expected_plan_file_sha256,
                result=result,
            )
            return result
    result = collect_run_plan_status(
        plan_path,
        output_root=output_root,
        expected_plan_file_sha256=expected_plan_file_sha256,
    )
    result["sidecar"] = _persist_q09_result(
        farm_root,
        work_item_id=work_item_id,
        terminal=terminal,
        plan_path=plan_path,
        expected_plan_file_sha256=expected_plan_file_sha256,
        result=result,
    )
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    plan = sub.add_parser("plan")
    plan.add_argument("--work-item-id", required=True)
    plan.add_argument("--candidate-lineage-key", required=True)
    plan.add_argument("--deployment-target", required=True)
    plan.add_argument("--q08-work-item-id", required=True)
    plan.add_argument("--q08-evidence", required=True, type=Path)
    plan.add_argument("--baseline-setfile", required=True, type=Path)
    plan.add_argument("--ex5", required=True, type=Path)
    plan.add_argument("--include-closure", required=True, type=Path)
    plan.add_argument("--calendar-manifest", required=True, type=Path)
    plan.add_argument("--calendar-common-relative-path", required=True)
    for name in (
        "full-from-utc", "full-to-utc", "selection-from-utc", "selection-to-utc",
        "holdout-from-utc", "holdout-to-utc",
    ):
        plan.add_argument("--" + name, required=True)
    plan.add_argument("--complete-months", required=True, type=int)
    plan.add_argument("--holdout-complete-months", required=True, type=int)
    plan.add_argument("--tester-model", required=True)
    plan.add_argument("--cost-profile", required=True)
    plan.add_argument("--output-root", required=True, type=Path)
    plan.add_argument("--out-prefix", type=Path, help=argparse.SUPPRESS)
    plan.add_argument("--news-or-event-strategy", action="store_true")
    plan.add_argument("--force-expanded-matrix", action="store_true")
    collect = sub.add_parser("collect")
    collect.add_argument("--plan", required=True, type=Path)
    collect.add_argument("--output-root", type=Path)
    collect.add_argument("--expected-plan-file-sha256")
    collect.add_argument("--out-prefix", type=Path, help=argparse.SUPPRESS)
    execute = sub.add_parser("execute")
    execute.add_argument("--plan", required=True, type=Path)
    execute.add_argument("--expected-plan-file-sha256", required=True)
    execute.add_argument("--output-root", required=True, type=Path)
    execute.add_argument("--farm-root", required=True, type=Path)
    execute.add_argument("--work-item-id", required=True)
    execute.add_argument("--terminal", required=True)
    execute.add_argument("--ea-id", required=True, type=int)
    execute.add_argument("--expert", required=True)
    execute.add_argument("--symbol", required=True)
    execute.add_argument("--work-item-symbol")
    execute.add_argument("--period", required=True)
    execute.add_argument("--repo-root", required=True, type=Path)
    execute.add_argument("--common-root", required=True, type=Path)
    execute.add_argument("--out-prefix", type=Path, help=argparse.SUPPRESS)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "plan":
        result = build_run_plan(
            work_item_id=args.work_item_id,
            candidate_lineage_key=args.candidate_lineage_key,
            deployment_target=args.deployment_target,
            q08_work_item_id=args.q08_work_item_id,
            q08_evidence_path=args.q08_evidence,
            baseline_setfile_path=args.baseline_setfile,
            ex5_path=args.ex5,
            include_closure_path=args.include_closure,
            calendar_manifest_path=args.calendar_manifest,
            calendar_common_relative_path=args.calendar_common_relative_path,
            full_from_utc=args.full_from_utc,
            full_to_utc=args.full_to_utc,
            selection_from_utc=args.selection_from_utc,
            selection_to_utc=args.selection_to_utc,
            holdout_from_utc=args.holdout_from_utc,
            holdout_to_utc=args.holdout_to_utc,
            complete_months=args.complete_months,
            holdout_complete_months=args.holdout_complete_months,
            tester_model=args.tester_model,
            cost_profile=args.cost_profile,
            output_root=args.output_root,
            news_or_event_strategy=args.news_or_event_strategy,
            force_expanded_matrix=args.force_expanded_matrix,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if args.command == "execute":
        result = execute_run_plan(
            args.plan,
            output_root=args.output_root,
            farm_root=args.farm_root,
            work_item_id=args.work_item_id,
            terminal=args.terminal,
            expected_plan_file_sha256=args.expected_plan_file_sha256,
            ea_id=args.ea_id,
            expert=args.expert,
            symbol=args.symbol,
            work_item_symbol=args.work_item_symbol,
            period=args.period,
            repo_root=args.repo_root,
            common_root=args.common_root,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["verdict"] == "CONFIG_LOCKED" else 2
    result = collect_run_plan_status(
        args.plan,
        output_root=args.output_root,
        expected_plan_file_sha256=args.expected_plan_file_sha256,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["verdict"] == "CONFIG_LOCKED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
