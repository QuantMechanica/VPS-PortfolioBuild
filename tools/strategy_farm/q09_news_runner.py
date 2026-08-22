#!/usr/bin/env python3
"""Plan, execute, and collect a reproducible Q09_NEWS v2 tester experiment.

The planner creates immutable, per-cell setfiles and a queue-ready manifest.
Execution uses an already-claimed ordinary factory terminal. The collector
authenticates every cell receipt and artifact before delegating economic
selection to :mod:`q09_news_contract`.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import html
import json
import math
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
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
NEWS_SELFREPORT_SCHEMA = "qm.news-calendar-run-selfreport/v1"
# SP-B2/ROT-2 is deliberately blocked pending the OWNER's authoritative-source
# and impact-taxonomy decision. New receipts must still state that fact rather
# than leaving the mapping identity implicit as V1 did.
PRE_V2_MAPPING_VERSION = "PRE_V2_UNVERSIONED_OWNER_MAPPING_PENDING"
CELL_FAILURE_SCHEMA_V1 = "q09-news-cell-failure/v1"
CELL_FAILURE_SCHEMA = "q09-news-cell-failure/v2"
SUPPORTED_CELL_FAILURE_SCHEMAS = frozenset(
    {CELL_FAILURE_SCHEMA_V1, CELL_FAILURE_SCHEMA}
)
EXECUTION_FAILURE_SCHEMA_V1 = "q09-news-execution-failure/v1"
EXECUTION_FAILURE_SCHEMA = "q09-news-execution-failure/v2"
SUPPORTED_EXECUTION_FAILURE_SCHEMAS = frozenset(
    {EXECUTION_FAILURE_SCHEMA_V1, EXECUTION_FAILURE_SCHEMA}
)
DIAGNOSTIC_ANCHOR_SCHEMA = "q09-live-news-diagnostic-anchor/v1"
DIAGNOSTIC_SUMMARY_SCHEMA = "q09-live-news-diagnostic-summary/v1"
DIAGNOSTIC_CONTRACT = "q09-live-news-backfill/v1"
DIAGNOSTIC_ALLOWED_TERMINALS = frozenset({"T1", "T2", "T3", "T4", "T5"})
CELL_FAILURE_STABLE_FIELDS = (
    "work_item_id",
    "run_identity_sha256",
    "paired_base_identity_sha256",
    "arm",
    "temporal_mode",
    "compliance_mode",
    "seed",
)
CELL_FAILURE_SIDECAR_RE = re.compile(
    r"^cell_failure(?:_([1-9][0-9]*))?\.json$"
)
CELL_FAILURE_ATTEMPT_DIR = "failure_attempts"
CELL_FAILURE_ATTEMPT_RE = re.compile(
    r"^attempt_([0-9]+)(?:\.tmp)?$"
)
# Immutable failure-snapshot naming layouts.
#   V1 (legacy): snapshot copies keep the source file's own suffix verbatim.
#     This let an ops retention sweep (reports_log_purge.ps1 deletes
#     D:\QM\reports\work_items\**\*.log) silently gut the snapshot — the pilot
#     cba63d44 cell_failure.json listed three .log evidence files (a 2.0MB
#     tester journal, a 1.16MB EA logger .log, run_smoke.log) that had been
#     copied and then deleted from failure_attempts/attempt_0001.
#   V2 (current): copies of purge-swept extensions are renamed to a neutral,
#     never-swept suffix (.log -> .evidence) so the immutable snapshot survives
#     the sweep byte-for-byte.  The true origin is still authenticated via each
#     artifact's source_relative_path.  Both layouts are accepted on read.
CELL_FAILURE_SNAPSHOT_LAYOUT_V1 = "FLAT_INDEXED_SHA256_V1"
CELL_FAILURE_SNAPSHOT_LAYOUT_V2 = "FLAT_INDEXED_SHA256_V2"
CELL_FAILURE_SNAPSHOT_LAYOUT = CELL_FAILURE_SNAPSHOT_LAYOUT_V2
CELL_FAILURE_SNAPSHOT_LAYOUTS = frozenset(
    {CELL_FAILURE_SNAPSHOT_LAYOUT_V1, CELL_FAILURE_SNAPSHOT_LAYOUT_V2}
)
# Suffixes an ops retention sweep deletes recursively under the reports tree
# (reports_log_purge.ps1: -Recurse -Filter *.log).  A snapshot copy of such a
# file must not carry this extension, or the immutable evidence is destroyed.
PURGE_SWEPT_SNAPSHOT_SUFFIXES = frozenset({".log"})
# Neutral terminal suffix given to a snapshot copy whose source extension is
# purge-swept.  Chosen so no `*.log`-style filter matches it (it does not end
# in, or begin its extension with, "log").
CELL_FAILURE_SNAPSHOT_PRESERVED_SUFFIX = ".evidence"
COMPLIANCE_MODE_IDS = {"NONE": 0, "DXZ": 1, "FTMO": 2, "5ERS": 3}
DEFAULT_CELL_TIMEOUT_SEC = 3600
CELL_TIMEOUT_HEADROOM_SEC = 600
TERMINAL_EXIT_WAIT_SEC = 180
TERMINAL_EXIT_POLL_SEC = 2.0
# This is the same terminal-worker attempt ceiling.  A transient cell may
# force the work item back through that existing retry lane, but must not
# create a second, unbounded retry budget inside the Q09 runner.  Retained for
# identity with terminal_worker.MAX_WORK_ITEM_RETRIES; the executor no longer
# requeues the whole work item for a single failing cell (see execute_run_plan).
WORK_ITEM_ATTEMPT_CEILING = 3
# Bounded per-cell transient retry budget (attempts *beyond* the first).  A
# single failing cell is retried at most this many extra times on a transient
# class, then recorded as failed so the remaining planned cells still run.
DEFAULT_CELL_RETRY_BUDGET = 2
# run_smoke reason classes that describe a transient / cold-cache / infra flake
# rather than a genuine tester result.  When a child exits 1 WITH a fresh FAIL
# summary whose reason classes are ALL within this set, the cell is routed into
# the bounded per-cell retry lane (see _production_dispatch_cell); any other or
# unknown reason class (genuine zero-signal, PF-missing validation, non-
# determinism, ...) is a real result and is recorded-and-continued without
# retry.  This is a retry-ROUTING decision only: it changes no gate threshold
# and no adjudication rule.
Q09_TRANSIENT_REASON_CLASSES = frozenset(
    {
        "TIMEOUT",
        "BARS_ZERO",
        "INCOMPLETE_RUNS",
        "NO_HISTORY",
        "MODEL4_MARKER_REQUIRED",
    }
)
WINDOW_NAMES = ("selection", "holdout", "full")
FACTORY_DB_RELATIVE_PATH = Path("state") / "farm_state.sqlite"
FACTORY_MT5_ROOT = Path(r"D:\QM\mt5")


class RunnerError(RuntimeError):
    """Raised when a Q09 plan or tester receipt cannot be authenticated."""


class CapacityError(RunnerError):
    """Raised when execution is outside the active factory terminal claim."""


class TransientCellError(RunnerError):
    """Raised for a child exit-1 that produced no fresh tester receipt."""


class HelperAbortError(RunnerError):
    """Raised when a helper-terminal cell must be caught up by the main slot."""


CELL_SHARD_RE = re.compile(r"^([1-9][0-9]*)/([1-9][0-9]*)$")
FACTORY_TERMINAL_RE = re.compile(r"^T(?:[1-9]|10)$", re.IGNORECASE)


def parse_cell_shard(value: str) -> tuple[int, int]:
    """Parse a one-based ``i/n`` shard selector and fail closed on ambiguity."""

    match = CELL_SHARD_RE.fullmatch(str(value or "").strip())
    if match is None:
        raise RunnerError("Q09 cell shard must use one-based i/n syntax")
    index, count = (int(match.group(1)), int(match.group(2)))
    if index > count:
        raise RunnerError("Q09 cell shard index exceeds shard count")
    return index, count


def cell_key(spec: Mapping[str, Any]) -> str:
    key = str(spec.get("run_identity_sha256") or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", key):
        raise RunnerError("Q09 cell lacks a canonical run identity")
    return key


def build_cell_shard_assignments(
    plan: Mapping[str, Any], shard_count: int
) -> list[list[str]]:
    """Return deterministic, exhaustive, pairwise-disjoint cell-key shards."""

    count = int(shard_count)
    if count <= 0:
        raise RunnerError("Q09 shard count must be positive")
    cells = list(plan.get("cells") or [])
    if not cells:
        raise RunnerError("Q09 run plan has no cells")
    assignments: list[list[str]] = [[] for _ in range(count)]
    for offset, spec in enumerate(cells):
        assignments[offset % count].append(cell_key(spec))
    flattened = [key for shard in assignments for key in shard]
    if len(flattened) != len(cells) or len(set(flattened)) != len(cells):
        raise RunnerError("Q09 shard construction is not exhaustive and disjoint")
    return assignments


def select_plan_cells(
    plan: Mapping[str, Any],
    *,
    cell_shard: str | None = None,
    cell_keys: Sequence[str] | None = None,
) -> list[Mapping[str, Any]]:
    """Select an authenticated subset without changing plan order or identity."""

    if cell_shard and cell_keys:
        raise RunnerError("Q09 cell_shard and cell_keys are mutually exclusive")
    cells = list(plan.get("cells") or [])
    if cell_shard:
        index, count = parse_cell_shard(cell_shard)
        allowed = set(build_cell_shard_assignments(plan, count)[index - 1])
        return [spec for spec in cells if cell_key(spec) in allowed]
    if cell_keys:
        requested = [str(value).strip().lower() for value in cell_keys]
        if len(requested) != len(set(requested)):
            raise RunnerError("Q09 cell_keys contains duplicates")
        by_key = {cell_key(spec): spec for spec in cells}
        unknown = sorted(set(requested) - set(by_key))
        if unknown:
            raise RunnerError(f"Q09 cell_keys contains unknown identities: {unknown}")
        requested_set = set(requested)
        return [spec for spec in cells if cell_key(spec) in requested_set]
    return cells


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


def build_news_selfreport(
    calendar_manifest_path: Path,
    *,
    mapping_version: str = PRE_V2_MAPPING_VERSION,
) -> dict[str, Any]:
    """Return one authenticated, consolidated calendar provenance object.

    This is intentionally additive to the existing Q09 v2 receipt. Until
    ROT-2 resolves the impact mapping, the explicit PRE_V2 marker prevents the
    receipt from being mistaken for post-V2 comparable evidence.
    """

    mapping = str(mapping_version or "").strip()
    if not mapping:
        raise RunnerError("news self-report mapping_version must be non-empty")
    try:
        verified = calendar_bundle.verify_bundle(calendar_manifest_path.parent)
    except calendar_bundle.CalendarBundleError as exc:
        raise RunnerError(f"news self-report calendar verification failed: {exc}") from exc
    files = verified.get("files")
    if not isinstance(files, list):
        raise RunnerError("news self-report calendar files manifest is invalid")
    events = next(
        (
            item
            for item in files
            if isinstance(item, Mapping) and item.get("role") == "EVENTS"
        ),
        None,
    )
    if not isinstance(events, Mapping):
        raise RunnerError("news self-report calendar has no EVENTS artifact")
    source_path = (
        calendar_manifest_path.parent / str(events.get("relative_path") or "")
    ).resolve()
    report = {
        "selfreport_schema_version": NEWS_SELFREPORT_SCHEMA,
        "source_path": str(source_path),
        "content_sha256": str(verified.get("content_sha256") or ""),
        "row_count": verified.get("row_count"),
        "max_event_date_utc": str(verified.get("event_to_utc") or ""),
        "schema_version": str(verified.get("schema_version") or ""),
        "mapping_version": mapping,
        "evidence_authority": (
            "NON_AUTHORITATIVE_PRE_V2"
            if mapping == PRE_V2_MAPPING_VERSION
            else "MAPPING_VERSION_DECLARED"
        ),
    }
    required = (
        "source_path",
        "content_sha256",
        "row_count",
        "max_event_date_utc",
        "schema_version",
        "mapping_version",
    )
    if any(report.get(field) in (None, "", 0) for field in required):
        raise RunnerError("news self-report has an empty required provenance field")
    if str(events.get("sha256") or "") != report["content_sha256"]:
        raise RunnerError("news self-report EVENTS/content SHA-256 mismatch")
    return report


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


def _validate_source_vintage(
    input_manifest: Mapping[str, Any],
    *,
    source_path_overrides: Mapping[str, Path] | None = None,
) -> None:
    identities = input_manifest["identities"]
    source_paths = input_manifest["source_paths"]
    overrides = dict(source_path_overrides or {})
    checks = {
        "q08_evidence": identities["q08_evidence_sha256"],
        "baseline_setfile": identities["baseline_setfile_sha256"],
        "ex5": identities["ex5_sha256"],
        "include_closure": identities["include_closure_sha256"],
        "calendar_manifest": input_manifest["calendar_bundle"]["manifest_sha256"],
    }
    unknown_overrides = set(overrides) - set(checks)
    if unknown_overrides:
        raise RunnerError(
            "unsupported source-vintage override roles: "
            + ", ".join(sorted(unknown_overrides))
        )
    for role, expected in checks.items():
        source_path = Path(overrides.get(role, source_paths[role]))
        _verify_hash(source_path, expected, role)


def load_authenticated_plan(
    plan_path: Path,
    *,
    expected_file_sha256: str | None = None,
    source_path_overrides: Mapping[str, Path] | None = None,
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
        _validate_source_vintage(
            input_manifest,
            source_path_overrides=source_path_overrides,
        )
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


VALID_TESTER_PERIODS = frozenset(
    {"M1", "M5", "M15", "M30", "H1", "H4", "H6", "H8", "D1", "W1", "MN1"}
)


def sealed_plan_period(input_manifest: Mapping[str, Any]) -> str:
    """Resolve the tester period from the hash-bound Q08 evidence.

    The Q08 evidence path and SHA-256 are part of the authenticated Q09 input
    manifest, so its baseline period is a sealed input.  Re-authenticate the
    baseline identities here to prevent a caller from supplying a period that
    merely happens to be syntactically valid.
    """

    try:
        source_paths = input_manifest["source_paths"]
        identities = input_manifest["identities"]
        q08_evidence = _load_json(Path(str(source_paths["q08_evidence"])), "Q08 evidence")
        baseline = q08_evidence["baseline_run"]
        period = str(baseline["period"]).strip().upper()
        baseline_setfile = Path(str(baseline["baseline_setfile_path"])).resolve()
        sealed_setfile = Path(str(source_paths["baseline_setfile"])).resolve()
    except (KeyError, TypeError, ValueError) as exc:
        raise RunnerError(f"Q09 sealed tester period is missing or malformed: {exc}") from exc
    if period not in VALID_TESTER_PERIODS:
        raise RunnerError(f"Q09 sealed tester period is unsupported: {period or '<empty>'}")
    if baseline_setfile != sealed_setfile:
        raise RunnerError("Q09 sealed tester period comes from a different baseline setfile")
    if baseline.get("baseline_setfile_sha256") != identities.get("baseline_setfile_sha256"):
        raise RunnerError("Q09 Q08 baseline setfile identity contradicts the sealed plan")
    if baseline.get("baseline_ex5_sha256") != identities.get("ex5_sha256"):
        raise RunnerError("Q09 Q08 baseline EX5 identity contradicts the sealed plan")
    return period


def resolve_execution_period(
    input_manifest: Mapping[str, Any], supplied_period: str | None
) -> str:
    """Use the sealed period and fail closed on an optional CLI contradiction."""

    sealed_period = sealed_plan_period(input_manifest)
    supplied = str(supplied_period or "").strip().upper()
    if supplied and supplied != sealed_period:
        raise RunnerError(
            f"executor --period {supplied} contradicts sealed Q09 period {sealed_period}"
        )
    return sealed_period


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
    material = {field: payload.get(field) for field in fields}
    # Standard Q09 bindings predate the live-book diagnostic lane.  Keep their
    # hash material byte-for-byte stable (including an already-active round-7
    # row), while binding every non-admission control that makes the diagnostic
    # lane safe when that explicit marker is present.
    if payload.get("diagnostic_non_admission") is True:
        material.update({
            "diagnostic_non_admission": True,
            "diagnostic_contract": payload.get("diagnostic_contract"),
            "diagnostic_anchor_path": payload.get("diagnostic_anchor_path"),
            "diagnostic_anchor_sha256": payload.get("diagnostic_anchor_sha256"),
            "diagnostic_campaign_id": payload.get("diagnostic_campaign_id"),
            "diagnostic_queue_rank": payload.get("diagnostic_queue_rank"),
            "avoid_terminals": payload.get("avoid_terminals"),
            "staged_ex5_path": payload.get("staged_ex5_path"),
            "staged_ex5_sha256": payload.get("staged_ex5_sha256"),
        })
    return material


def _dispatch_binding_sha256(payload: Mapping[str, Any]) -> str:
    return contract.sha256_bytes(contract.canonical_json_bytes(_dispatch_binding_material(payload)))


def _farm_db_path(farm_root: Path) -> Path:
    return farm_root.resolve() / FACTORY_DB_RELATIVE_PATH




_Q07_LINEAGE_AUTH_FAILURE = (
    "Q08 dependency has no Q07 lineage and no identity-bound "
    "Q07 predecessor could be authenticated"
)


def _hex64(value: Any) -> str:
    """Return a lowercased 64-hex sha string, or an empty string otherwise."""
    text = str(value or "").strip().lower()
    if len(text) == 64 and all(c in "0123456789abcdef" for c in text):
        return text
    return ""


def _load_json_document(path: Path) -> dict[str, Any]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return document if isinstance(document, dict) else {}


def _mapping(value: Any) -> Mapping[str, Any]:
    return value if isinstance(value, Mapping) else {}


def _q08_ex5_identity(payload: Mapping[str, Any], evidence: Mapping[str, Any]) -> str:
    """Best authenticated EX5 sha for a Q08 dependency.

    A ``book_q08_regeneration`` row leaves ``expected_ex5_sha256`` empty, so the
    authenticated Q08 evidence (its hash was verified upstream) and the dispatch
    staging record are consulted as fallbacks.
    """
    staged = _mapping(payload.get("staged_ex5"))
    baseline = _mapping(evidence.get("baseline_run"))
    for candidate in (
        payload.get("expected_ex5_sha256"),
        staged.get("source_sha256"),
        staged.get("required_sha256"),
        baseline.get("baseline_ex5_sha256"),
    ):
        found = _hex64(candidate)
        if found:
            return found
    return ""


def _q08_mq5_identity(payload: Mapping[str, Any], evidence: Mapping[str, Any]) -> str:
    baseline = _mapping(evidence.get("baseline_run"))
    for candidate in (
        payload.get("expected_mq5_sha256"),
        baseline.get("baseline_mq5_sha256"),
    ):
        found = _hex64(candidate)
        if found:
            return found
    return ""


def _q07_ex5_identity(payload: Mapping[str, Any], evidence: Mapping[str, Any]) -> str:
    staged = _mapping(payload.get("staged_ex5"))
    baseline = _mapping(evidence.get("baseline_run"))
    for candidate in (
        payload.get("expected_ex5_sha256"),
        staged.get("source_sha256"),
        baseline.get("baseline_ex5_sha256"),
    ):
        found = _hex64(candidate)
        if found:
            return found
    return ""


def _normcase_path(value: Any) -> str:
    return os.path.normcase(os.path.normpath(str(value or "")))


def _resolve_identity_bound_q07(
    connection: sqlite3.Connection,
    *,
    q08_id: str,
    q08_evidence_path: Path,
    q08_payload: Mapping[str, Any],
) -> tuple[str, str]:
    """Fail-closed fallback when a Q08 row carries no ``promoted_from_work_item``.

    Resolves the newest completed Q07 seed-stability PASS for the same
    ea_id/symbol/setfile created no later than the Q08 row, and authenticates the
    EX5 build identity before accepting it.  Never relaxes any gate: any gap in
    the identity chain raises ``_Q07_LINEAGE_AUTH_FAILURE``.
    """
    q08 = connection.execute(
        "SELECT ea_id,symbol,setfile_path,created_at FROM work_items WHERE id=?",
        (q08_id,),
    ).fetchone()
    if q08 is None:
        raise RunnerError(_Q07_LINEAGE_AUTH_FAILURE)
    q08_evidence = _load_json_document(q08_evidence_path)
    q08_ex5 = _q08_ex5_identity(q08_payload, q08_evidence)
    q08_mq5 = _q08_mq5_identity(q08_payload, q08_evidence)
    if not q08_ex5:
        raise RunnerError(_Q07_LINEAGE_AUTH_FAILURE)
    want_setfile = _normcase_path(q08["setfile_path"])
    rows = connection.execute(
        """
        SELECT id,setfile_path,evidence_path,payload_json,created_at
        FROM work_items
        WHERE phase='Q07' AND status='done'
          AND verdict IN ('PASS','MULTI_SEED_PASS')
          AND ea_id=? AND symbol=?
          AND created_at<=?
        ORDER BY created_at DESC, id DESC
        """,
        (q08["ea_id"], q08["symbol"], q08["created_at"]),
    ).fetchall()
    candidate = None
    for row in rows:
        if _normcase_path(row["setfile_path"]) == want_setfile:
            candidate = row
            break
    if candidate is None:
        raise RunnerError(_Q07_LINEAGE_AUTH_FAILURE)
    try:
        q07_payload = json.loads(str(candidate["payload_json"] or "{}"))
    except json.JSONDecodeError:
        q07_payload = {}
    if not isinstance(q07_payload, dict):
        q07_payload = {}
    q07_evidence = _load_json_document(Path(str(candidate["evidence_path"] or "")))
    q07_ex5 = _q07_ex5_identity(q07_payload, q07_evidence)
    if q07_ex5:
        # Both sides carry an EX5 identity: accept only on an exact match.
        if q07_ex5 != q08_ex5:
            raise RunnerError(_Q07_LINEAGE_AUTH_FAILURE)
        return str(candidate["id"]), "identity_bound_fallback"
    # The Q07 evidence records no EX5 identity anywhere (payload, aggregate, or
    # per-seed summary).  Anchor the build to the current repo instead: the Q08
    # must have run the EX5/MQ5 that is still checked in, so a re-run of that
    # same build could not have diverged since the Q07 seed-stability PASS.
    ex5_repo = Path(str(q08_payload.get("expected_ex5_path") or ""))
    baseline = _mapping(q08_evidence.get("baseline_run"))
    mq5_repo = Path(str(baseline.get("baseline_mq5_path") or ""))
    if str(mq5_repo) in ("", ".") and ex5_repo.suffix:
        mq5_repo = ex5_repo.with_suffix(".mq5")
    if not ex5_repo.is_file() or _hex64(contract.sha256_file(ex5_repo)) != q08_ex5:
        raise RunnerError(_Q07_LINEAGE_AUTH_FAILURE)
    if (
        not q08_mq5
        or not mq5_repo.is_file()
        or _hex64(contract.sha256_file(mq5_repo)) != q08_mq5
    ):
        raise RunnerError(_Q07_LINEAGE_AUTH_FAILURE)
    return str(candidate["id"]), "identity_bound_fallback"


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
            or dependency["verdict"] not in {"PASS", "FAIL_SOFT"}
        ):
            raise RunnerError("Q09 Q08_INPUT dependency is not a done PASS/FAIL_SOFT")
        q08_path = Path(str(dependency["evidence_path"] or ""))
        _verify_hash(q08_path, q08_hash, "Q08 dependency evidence")
        identities = manifest.get("identities") or {}
        if identities.get("q08_work_item_id") != q08_id:
            raise RunnerError("Q09 input manifest names a different Q08 work item")
        if identities.get("q08_evidence_sha256") != q08_hash:
            raise RunnerError("Q09 input manifest Q08 evidence hash mismatch")

        # A Q08 FAIL_SOFT is admissible only through the independent portfolio
        # rescue arm.  Authenticate that exact sibling and its Q08 dependency
        # before binding the news plan; this does not relax either gate.
        if dependency["verdict"] == "FAIL_SOFT":
            try:
                item_payload = json.loads(str(item["payload_json"] or "{}"))
            except json.JSONDecodeError as exc:
                raise RunnerError("Q09 work-item payload is invalid JSON") from exc
            portfolio_id = str(
                item_payload.get("q09_portfolio_work_item_id") or ""
            ).strip()
            portfolio_hash = str(
                item_payload.get("q09_portfolio_evidence_sha256") or ""
            ).strip().lower()
            if not portfolio_id or len(portfolio_hash) != 64:
                raise RunnerError(
                    "Q08 FAIL_SOFT news binding lacks an authenticated portfolio sibling"
                )
            portfolio = connection.execute(
                """
                SELECT p.phase,p.status,p.verdict,p.ea_id,p.symbol,p.setfile_path,
                       p.evidence_path,d.parent_work_item_id,
                       d.parent_evidence_sha256
                FROM work_items p
                LEFT JOIN work_item_dependencies d
                  ON d.child_work_item_id=p.id
                 AND d.dependency_role='Q08_INPUT'
                WHERE p.id=?
                """,
                (portfolio_id,),
            ).fetchone()
            if (
                portfolio is None
                or portfolio["phase"] != "Q09_PORTFOLIO"
                or portfolio["status"] != "done"
                or portfolio["verdict"] != "PASS_PORTFOLIO"
                or portfolio["ea_id"] != item["ea_id"]
                or portfolio["symbol"] != item["symbol"]
                or portfolio["setfile_path"] != item["setfile_path"]
                or str(portfolio["parent_work_item_id"] or "") != q08_id
                or str(portfolio["parent_evidence_sha256"] or "").lower()
                != q08_hash.lower()
            ):
                raise RunnerError(
                    "Q08 FAIL_SOFT portfolio sibling does not match exact Q09 lineage"
                )
            _verify_hash(
                Path(str(portfolio["evidence_path"] or "")),
                portfolio_hash,
                "Q09 portfolio sibling evidence",
            )

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
        if q07_id:
            q07_lineage_resolution = "promoted_from_work_item"
        else:
            q07_id, q07_lineage_resolution = _resolve_identity_bound_q07(
                connection,
                q08_id=q08_id,
                q08_evidence_path=q08_path,
                q08_payload=q08_payload,
            )
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
            "q09_activation_state": news_schema.ACTIVATION_STATE_RUNNABLE,
            "q09_run_plan_path": str(plan_path),
            "q09_run_plan_file_sha256": contract.sha256_file(plan_path),
            "q09_run_plan_sha256": plan["plan_sha256"],
            "q09_input_manifest_sha256": plan["input_manifest_sha256"],
            "q09_q08_work_item_id": q08_id,
            "q09_q08_evidence_sha256": q08_hash,
            "q09_q07_work_item_id": q07_id,
            "q09_q07_evidence_path": str(q07_path.resolve()),
            "q09_q07_evidence_sha256": q07_hash,
            "q09_q07_lineage_resolution": q07_lineage_resolution,
            "q09_cell_count": int(plan["cell_count"]),
            "q09_cell_timeout_sec": timeout_sec,
        }
        payload.update(binding_updates)
        payload["q09_dispatch_binding_sha256"] = _dispatch_binding_sha256(payload)
        payload["timeout_min"] = max(int(payload.get("timeout_min") or 0), timeout_min)
        bound_at = datetime.now(timezone.utc).isoformat()
        payload["q09_plan_bound_at"] = bound_at
        connection.execute(
            "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
            (
                json.dumps(payload, sort_keys=True),
                bound_at,
                str(work_item_id),
            ),
        )
        activation_hold_released = news_schema.release_plan_bound_hold(
            connection,
            str(work_item_id),
            now=bound_at,
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
        "activation_state": payload["q09_activation_state"],
        "activation_hold_released": activation_hold_released,
        "next_action": "ordinary factory pump/terminal worker may now claim this pending Q09_NEWS row",
    }


def bind_diagnostic_plan_to_work_item(
    farm_root: Path,
    *,
    work_item_id: str,
    plan_path: Path,
    expected_plan_file_sha256: str,
    cell_timeout_sec: int = DEFAULT_CELL_TIMEOUT_SEC,
) -> dict[str, Any]:
    """Bind a live-book Q09 diagnostic without manufacturing pipeline lineage.

    The anchor is carried in the plan's historical ``q08_evidence`` identity
    slot only so the sealed v2 plan/collector format remains reusable.  This
    binder proves that it is an explicit non-admission anchor, authenticates a
    real completed Q07 seed-stability row, and never creates a Q08 dependency.
    Diagnostic persistence is consequently kept out of ``q09_news_tests``.
    """

    plan_path = plan_path.resolve()
    plan, manifest = load_authenticated_plan(
        plan_path, expected_file_sha256=expected_plan_file_sha256
    )
    if str(plan.get("work_item_id")) != str(work_item_id):
        raise RunnerError("Q09 diagnostic plan is bound to a different work_item_id")
    if str(manifest.get("tester_model") or "").strip().upper() not in {
        "REAL_TICKS", "MODEL4_REAL_TICKS",
    }:
        raise RunnerError("Q09 diagnostic execution requires sealed REAL_TICKS")
    if int(plan.get("cell_count") or 0) != 40 or manifest.get("matrix_scope") != "7x1_target_compliance":
        raise RunnerError("Q09 live-book diagnostic requires the canonical 7x1 / 40-cell matrix")

    anchor_path = Path(str((manifest.get("source_paths") or {}).get("q08_evidence", ""))).resolve()
    anchor = _load_json(anchor_path, "Q09 live-book diagnostic anchor")
    if (
        anchor.get("schema_version") != DIAGNOSTIC_ANCHOR_SCHEMA
        or anchor.get("diagnostic_non_admission") is not True
        or anchor.get("diagnostic_contract") != DIAGNOSTIC_CONTRACT
    ):
        raise RunnerError("Q09 diagnostic anchor contract is missing or contradictory")

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
            raise RunnerError("Q09 diagnostic work item does not exist")
        if item["phase"] != "Q09_NEWS" or item["status"] != "pending" or str(item["claimed_by"] or "").strip():
            raise RunnerError("Q09 diagnostic plan requires an unclaimed pending Q09_NEWS row")
        try:
            payload = json.loads(str(item["payload_json"] or "{}"))
        except json.JSONDecodeError as exc:
            raise RunnerError("Q09 diagnostic payload is invalid JSON") from exc
        anchor_work_item_id = str(anchor.get("work_item_id") or "")
        direct_anchor = anchor_work_item_id == str(work_item_id)
        rerun_parent_id = str(payload.get("rerun_of") or "")
        sealed_identity_rerun = (
            payload.get("sealed_identity_rerun") is True
            and int(payload.get("diagnostic_generation") or 0) >= 3
            and bool(rerun_parent_id)
            and rerun_parent_id == str(item["parent_task_id"] or "")
            and str(payload.get("sealed_identity_anchor_work_item_id") or "")
            == anchor_work_item_id
            and str(payload.get("sealed_identity_anchor_sha256") or "").lower()
            == contract.sha256_file(anchor_path)
        )
        if not direct_anchor and not sealed_identity_rerun:
            raise RunnerError("Q09 diagnostic anchor work-item lineage is contradictory")
        if str(item["ea_id"]) != str(anchor.get("ea_id")) or str(item["symbol"]) != str(anchor.get("symbol")):
            raise RunnerError("Q09 diagnostic anchor differs from work-item EA/symbol")
        if connection.execute(
            "SELECT 1 FROM q09_news_tests WHERE work_item_id=?", (str(work_item_id),)
        ).fetchone() is not None:
            raise RunnerError("diagnostic work item must not have canonical Q09 admission evidence")

        identities = manifest.get("identities") or {}
        if identities.get("q08_evidence_sha256") != contract.sha256_file(anchor_path):
            raise RunnerError("Q09 diagnostic anchor hash differs from sealed plan")
        if identities.get("q08_work_item_id") != str(anchor.get("anchor_id")):
            raise RunnerError("Q09 diagnostic anchor identity differs from sealed plan")
        setfile_path = Path(str(item["setfile_path"] or "")).resolve()
        source_baseline = Path(str((manifest.get("source_paths") or {}).get("baseline_setfile", ""))).resolve()
        if setfile_path != source_baseline:
            raise RunnerError("Q09 diagnostic baseline differs from work-item setfile")
        _verify_hash(
            setfile_path,
            str(identities.get("baseline_setfile_sha256") or ""),
            "Q09 diagnostic baseline setfile",
        )

        fresh_build = anchor.get("fresh_build_ex5") or {}
        deployed = anchor.get("deployed_ex5") or {}
        staged_identity = fresh_build or deployed
        if fresh_build and int(anchor.get("diagnostic_generation") or 0) != 2:
            raise RunnerError("Q09 fresh-build diagnostic lacks generation-2 identity")
        staged_path = Path(str(staged_identity.get("path") or "")).resolve()
        staged_hash = str(staged_identity.get("sha256") or "").lower()
        staged_role = (
            "Q09 exact fresh current-build EX5"
            if fresh_build
            else "Q09 exact deployed live EX5"
        )
        if sealed_identity_rerun:
            # A later canonical rebuild may move the anchor's mutable EX5 path
            # to a new vintage. The successor plan may instead bind an
            # immutable recovered copy, but never a different hash.
            staged_path = Path(str(
                (manifest.get("source_paths") or {}).get("ex5", "")
            )).resolve()
            payload_staged_path = Path(str(payload.get("staged_ex5_path") or "")).resolve()
            payload_staged_hash = str(payload.get("staged_ex5_sha256") or "").lower()
            if payload_staged_path != staged_path or payload_staged_hash != staged_hash:
                raise RunnerError(
                    "Q09 sealed-identity rerun EX5 payload differs from plan/anchor"
                )
            staged_role = "Q09 exact immutable generation EX5"
        _verify_hash(staged_path, staged_hash, staged_role)
        if staged_hash != identities.get("ex5_sha256"):
            raise RunnerError("Q09 diagnostic staged EX5 differs from sealed plan")

        q07 = anchor.get("q07_seed_stability") or {}
        q07_id = str(q07.get("work_item_id") or "")
        q07_path = Path(str(q07.get("evidence_path") or "")).resolve()
        q07_hash = str(q07.get("evidence_sha256") or "").lower()
        q07_row = connection.execute(
            "SELECT phase,status,verdict,evidence_path FROM work_items WHERE id=?",
            (q07_id,),
        ).fetchone()
        exact_work_item_evidence = (
            q07_row is not None
            and Path(str(q07_row["evidence_path"] or "")).resolve() == q07_path
        )
        durable_fallback = str(q07.get("evidence_source") or "") == "DURABLE_PIPELINE_FALLBACK"
        if (
            q07_row is None
            or q07_row["phase"] != "Q07"
            or q07_row["status"] != "done"
            or q07_row["verdict"] not in {"PASS", "MULTI_SEED_PASS"}
            or (not exact_work_item_evidence and not durable_fallback)
        ):
            raise RunnerError("Q09 diagnostic Q07 seed-stability reference is not a completed PASS")
        _verify_hash(q07_path, q07_hash, "Q09 diagnostic Q07 seed-stability evidence")
        if durable_fallback:
            fallback_document = _load_json(q07_path, "durable Q07 fallback evidence")
            if (
                str(fallback_document.get("phase") or "").upper() != "Q07"
                or str(fallback_document.get("verdict") or "").upper()
                not in {"PASS", "MULTI_SEED_PASS"}
                or str(fallback_document.get("symbol") or fallback_document.get("runner_symbol") or "")
                != str(item["symbol"])
            ):
                raise RunnerError("durable Q07 fallback does not match the diagnostic sleeve")

        calendar_manifest = Path(str((manifest.get("source_paths") or {}).get("calendar_manifest", "")))
        try:
            verified_calendar = calendar_bundle.verify_bundle(calendar_manifest.parent)
        except calendar_bundle.CalendarBundleError as exc:
            raise RunnerError(f"calendar bundle verification failed during diagnostic binding: {exc}") from exc
        registered = connection.execute(
            "SELECT manifest_sha256,content_sha256 FROM news_calendar_bundles WHERE bundle_id=?",
            (str(verified_calendar["bundle_id"]),),
        ).fetchone()
        if registered is None:
            news_schema.record_calendar_bundle(
                connection, verified_calendar, str(calendar_manifest.resolve())
            )
        elif (
            registered["manifest_sha256"] != verified_calendar["manifest_sha256"]
            or registered["content_sha256"] != verified_calendar["content_sha256"]
        ):
            raise RunnerError("registered calendar bundle contradicts diagnostic plan")

        avoided = {str(value).upper() for value in payload.get("avoid_terminals", [])}
        if (
            payload.get("diagnostic_non_admission") is not True
            or payload.get("diagnostic_contract") != DIAGNOSTIC_CONTRACT
            or avoided != {"T6", "T7", "T8", "T9", "T10"}
            or Path(str(payload.get("staged_ex5_path") or "")).resolve() != staged_path
            or str(payload.get("staged_ex5_sha256") or "").lower() != staged_hash
        ):
            raise RunnerError("Q09 diagnostic payload lacks the non-admission/cap/exact-EX5 controls")

        payload.update({
            "q09_binding_version": "q09-news-dispatch-binding/v1",
            "q09_activation_state": news_schema.ACTIVATION_STATE_RUNNABLE,
            "q09_run_plan_path": str(plan_path),
            "q09_run_plan_file_sha256": contract.sha256_file(plan_path),
            "q09_run_plan_sha256": plan["plan_sha256"],
            "q09_input_manifest_sha256": plan["input_manifest_sha256"],
            "q09_q08_work_item_id": str(anchor["anchor_id"]),
            "q09_q08_evidence_sha256": contract.sha256_file(anchor_path),
            "q09_q07_work_item_id": q07_id,
            "q09_q07_evidence_path": str(q07_path),
            "q09_q07_evidence_sha256": q07_hash,
            "q09_cell_count": 40,
            "q09_cell_timeout_sec": timeout_sec,
            "diagnostic_anchor_path": str(anchor_path),
            "diagnostic_anchor_sha256": contract.sha256_file(anchor_path),
        })
        payload["q09_dispatch_binding_sha256"] = _dispatch_binding_sha256(payload)
        payload["timeout_min"] = max(int(payload.get("timeout_min") or 0), timeout_min)
        bound_at = datetime.now(timezone.utc).isoformat()
        payload["q09_plan_bound_at"] = bound_at
        connection.execute(
            "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
            (json.dumps(payload, sort_keys=True), bound_at, str(work_item_id)),
        )
        connection.commit()
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()
    return {
        "bound": True,
        "diagnostic_non_admission": True,
        "work_item_id": str(work_item_id),
        "plan_path": str(plan_path),
        "plan_file_sha256": contract.sha256_file(plan_path),
        "cell_count": 40,
        "cell_timeout_sec": timeout_sec,
        "timeout_min": timeout_min,
        "dispatch_binding_sha256": payload["q09_dispatch_binding_sha256"],
        "allowed_terminals": sorted(DIAGNOSTIC_ALLOWED_TERMINALS),
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
    news_selfreport = receipt.get("news_selfreport")
    evidence_news_selfreport = evidence_document.get("news_selfreport")
    if news_selfreport is not None or evidence_news_selfreport is not None:
        if (
            not isinstance(news_selfreport, Mapping)
            or news_selfreport != evidence_news_selfreport
        ):
            raise RunnerError(
                f"cell news self-report contradicts hashed evidence: {receipt_path}"
            )
        for field in (
            "source_path",
            "content_sha256",
            "row_count",
            "max_event_date_utc",
            "schema_version",
            "mapping_version",
        ):
            if news_selfreport.get(field) in (None, "", 0):
                raise RunnerError(
                    f"cell news self-report {field} is empty: {receipt_path}"
                )
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
        "evidence_path": str(artifact_paths["evidence"].resolve()),
        "report_path": str(artifact_paths["report"].resolve()),
        "selection": metrics["selection"],
        "holdout": metrics["holdout"],
        "full": metrics["full"],
        "q07_seed_stability_pass": receipt.get("q07_seed_stability_pass"),
        "flat_at_event_receipt_sha256": flat_receipt_hash,
        "news_selfreport": news_selfreport,
    }


def _cell_failure_path(spec: Mapping[str, Any]) -> Path:
    return Path(str(spec["receipt_path"])).with_name("cell_failure.json")


def _cell_failure_identity(
    spec: Mapping[str, Any], *, work_item_id: str
) -> dict[str, Any]:
    return {
        "schema_version": CELL_FAILURE_SCHEMA,
        "work_item_id": str(work_item_id),
        "run_identity_sha256": spec["run_identity_sha256"],
        "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
        "arm": spec["arm"],
        "temporal_mode": spec["temporal_mode"],
        "compliance_mode": spec["compliance_mode"],
        "seed": spec["seed"],
    }


def _assert_cell_failure_identity(
    failure: Mapping[str, Any],
    expected: Mapping[str, Any],
    path: Path,
) -> None:
    schema_version = str(failure.get("schema_version") or "")
    if schema_version not in SUPPORTED_CELL_FAILURE_SCHEMAS:
        raise RunnerError(
            f"unsupported cell failure schema {schema_version!r}: {path}"
        )
    for field in CELL_FAILURE_STABLE_FIELDS:
        if failure.get(field) != expected[field]:
            raise RunnerError(f"cell failure {field} mismatch: {path}")


def _cell_failure_occurrence_path(base_path: Path, occurrence: int) -> Path:
    if occurrence < 1:
        raise RunnerError("cell failure occurrence must be positive")
    if occurrence == 1:
        return base_path
    return base_path.with_name(
        f"{base_path.stem}_{occurrence}{base_path.suffix}"
    )


def _cell_failure_occurrence(path: Path) -> int:
    match = CELL_FAILURE_SIDECAR_RE.fullmatch(path.name)
    if match is None:
        raise RunnerError(f"invalid cell failure sidecar name: {path}")
    occurrence = int(match.group(1) or 1)
    if occurrence == 1 and path.name != "cell_failure.json":
        raise RunnerError(f"cell failure occurrence 1 must use the base name: {path}")
    return occurrence


def _failure_attempt_root(cell_dir: Path, occurrence: int) -> Path:
    return cell_dir / CELL_FAILURE_ATTEMPT_DIR / f"attempt_{occurrence:04d}"


def _failure_snapshot_artifact_name(
    source_relative_path: Path | PurePosixPath,
    index: int,
    *,
    layout: str = CELL_FAILURE_SNAPSHOT_LAYOUT,
) -> str:
    """Return a short deterministic name for one snapshotted artifact.

    Mirroring the full run-smoke tree below ``failure_attempts`` can push an
    otherwise valid cell past the legacy Windows MAX_PATH boundary.  The
    sidecar already preserves the authenticated source-relative path, so the
    immutable copy only needs a unique, deterministic flat name.

    Under the V2 layout a copy whose source extension is purge-swept (``.log``)
    is renamed to a neutral suffix so an ops ``*.log`` retention sweep cannot
    delete the immutable evidence.  V1 keeps the source suffix verbatim so
    already-written sidecars authenticate unchanged.
    """

    if index < 1:
        raise RunnerError("cell failure artifact index must be positive")
    if layout not in CELL_FAILURE_SNAPSHOT_LAYOUTS:
        raise RunnerError(
            f"cell failure artifact snapshot layout is unsupported: {layout}"
        )
    source = PurePosixPath(source_relative_path.as_posix())
    digest = hashlib.sha256(source.as_posix().encode("utf-8")).hexdigest()[:16]
    suffix = source.suffix.lower()
    if re.fullmatch(r"\.[a-z0-9]{1,10}", suffix) is None:
        suffix = ""
    if (
        layout == CELL_FAILURE_SNAPSHOT_LAYOUT_V2
        and suffix in PURGE_SWEPT_SNAPSHOT_SUFFIXES
    ):
        suffix = CELL_FAILURE_SNAPSHOT_PRESERVED_SUFFIX
    return f"artifact_{index:04d}_{digest}{suffix}"


def _next_cell_failure_occurrence(
    base_path: Path,
    *,
    expected_identity: Mapping[str, Any],
) -> int:
    highest = 0
    for candidate in sorted(base_path.parent.glob("cell_failure*.json")):
        if CELL_FAILURE_SIDECAR_RE.fullmatch(candidate.name) is None:
            continue
        occurrence = _cell_failure_occurrence(candidate)
        prior = _load_json(candidate, f"cell failure {candidate}")
        _assert_cell_failure_identity(prior, expected_identity, candidate)
        highest = max(highest, occurrence)
    attempt_parent = base_path.parent / CELL_FAILURE_ATTEMPT_DIR
    if attempt_parent.is_dir():
        for candidate in attempt_parent.iterdir():
            match = CELL_FAILURE_ATTEMPT_RE.fullmatch(candidate.name)
            if match is not None and int(match.group(1)) > 0:
                highest = max(highest, int(match.group(1)))
    return highest + 1


def _failure_artifact_sources(cell_dir: Path) -> list[tuple[Path, Path]]:
    sources: list[tuple[Path, Path]] = []
    resolved_cell_dir = cell_dir.resolve()
    for path in sorted(cell_dir.rglob("*")):
        if not path.is_file():
            continue
        relative_path = path.relative_to(cell_dir)
        if (
            relative_path.parts[0] == CELL_FAILURE_ATTEMPT_DIR
            or path.name == "cell_receipt.json"
            or CELL_FAILURE_SIDECAR_RE.fullmatch(path.name)
        ):
            continue
        try:
            path.resolve().relative_to(resolved_cell_dir)
        except ValueError as exc:
            raise RunnerError(
                f"cell failure source artifact escapes its cell directory: {path}"
            ) from exc
        sources.append((path, relative_path))
    return sources


def _snapshot_failure_artifacts(
    cell_dir: Path, *, occurrence: int
) -> tuple[Path, list[dict[str, Any]]]:
    """Copy every failure artifact into one immutable attempt namespace.

    The failure sidecar is written only after the child process has stopped, so
    these identities turn a terse exception into durable row-bound evidence.
    Planned inputs are intentionally included. Prior snapshots, receipts, and
    failure sidecars are excluded to avoid recursive or cross-attempt identity.
    """

    snapshot_root = _failure_attempt_root(cell_dir, occurrence)
    temporary_root = snapshot_root.with_name(snapshot_root.name + ".tmp")
    if snapshot_root.exists() or temporary_root.exists():
        raise RunnerError(
            f"cell failure attempt snapshot already exists: {snapshot_root}"
        )
    temporary_root.mkdir(parents=True)
    sources = _failure_artifact_sources(cell_dir)
    copied: list[tuple[Path, Path, str]] = []
    for index, (source_path, source_relative_path) in enumerate(sources, 1):
        snapshot_name = _failure_snapshot_artifact_name(
            source_relative_path, index
        )
        destination = temporary_root / snapshot_name
        before = source_path.stat()
        shutil.copyfile(source_path, destination)
        after = source_path.stat()
        if (
            before.st_size != after.st_size
            or before.st_mtime_ns != after.st_mtime_ns
            or destination.stat().st_size != after.st_size
        ):
            raise RunnerError(
                f"cell failure source artifact changed during snapshot: {source_path}"
            )
        copied.append((source_path, source_relative_path, snapshot_name))
    temporary_root.replace(snapshot_root)

    artifacts: list[dict[str, Any]] = []
    for source_path, source_relative_path, snapshot_name in copied:
        path = snapshot_root / snapshot_name
        artifacts.append(
            {
                "path": str(path.resolve()),
                "relative_path": path.relative_to(cell_dir).as_posix(),
                "source_relative_path": source_relative_path.as_posix(),
                "size_bytes": path.stat().st_size,
                "sha256": contract.sha256_file(path),
            }
        )
    return snapshot_root, artifacts


def _write_cell_failure(
    spec: Mapping[str, Any],
    *,
    work_item_id: str,
    exc: Exception,
) -> Path:
    base_path = _cell_failure_path(spec)
    identity = _cell_failure_identity(spec, work_item_id=work_item_id)
    occurrence = _next_cell_failure_occurrence(
        base_path, expected_identity=identity
    )
    path = _cell_failure_occurrence_path(base_path, occurrence)
    snapshot_root, artifacts = _snapshot_failure_artifacts(
        base_path.parent, occurrence=occurrence
    )
    payload = {
        **identity,
        "failure_occurrence": occurrence,
        "error_type": type(exc).__name__,
        "error": str(exc),
        "artifact_snapshot_relative_path": snapshot_root.relative_to(
            base_path.parent
        ).as_posix(),
        "artifact_snapshot_layout": CELL_FAILURE_SNAPSHOT_LAYOUT,
        "artifacts": artifacts,
    }
    data = contract.canonical_json_bytes(payload)
    _write_immutable(path, data)
    return path


def _authenticated_cell_failure(
    spec: Mapping[str, Any],
    *,
    work_item_id: str,
    failure_path: Path | None = None,
    expected_failure_sha256: str | None = None,
) -> dict[str, Any] | None:
    path = failure_path or _cell_failure_path(spec)
    if not path.is_file():
        return None
    cell_dir = _cell_failure_path(spec).parent.resolve()
    resolved_path = path.resolve()
    if (
        resolved_path.parent != cell_dir
        or CELL_FAILURE_SIDECAR_RE.fullmatch(resolved_path.name) is None
    ):
        raise RunnerError(f"cell failure sidecar path is contradictory: {path}")
    if expected_failure_sha256 is not None:
        _verify_hash(path, expected_failure_sha256, "cell failure sidecar")
    failure = _load_json(path, f"cell failure {path}")
    expected = _cell_failure_identity(spec, work_item_id=work_item_id)
    _assert_cell_failure_identity(failure, expected, path)
    if not str(failure.get("error_type") or "").strip() or not str(
        failure.get("error") or ""
    ).strip():
        raise RunnerError(f"cell failure lacks an explicit error: {path}")
    artifacts = failure.get("artifacts")
    if not isinstance(artifacts, list):
        raise RunnerError(f"cell failure artifact manifest is missing: {path}")
    schema_version = str(failure["schema_version"])
    snapshot_root: Path | None = None
    snapshot_layout: str | None = None
    if schema_version == CELL_FAILURE_SCHEMA:
        occurrence = _cell_failure_occurrence(path)
        if failure.get("failure_occurrence") != occurrence:
            raise RunnerError(f"cell failure occurrence is contradictory: {path}")
        expected_snapshot_relative = _failure_attempt_root(
            path.parent, occurrence
        ).relative_to(path.parent).as_posix()
        if (
            failure.get("artifact_snapshot_relative_path")
            != expected_snapshot_relative
        ):
            raise RunnerError(
                f"cell failure artifact snapshot path is contradictory: {path}"
            )
        snapshot_root = (path.parent / expected_snapshot_relative).resolve()
        if not snapshot_root.is_dir():
            raise RunnerError(
                f"cell failure artifact snapshot is missing: {snapshot_root}"
            )
        raw_layout = failure.get("artifact_snapshot_layout")
        if raw_layout is not None:
            snapshot_layout = str(raw_layout)
            if snapshot_layout not in CELL_FAILURE_SNAPSHOT_LAYOUTS:
                raise RunnerError(
                    f"cell failure artifact snapshot layout is unsupported: {path}"
                )
    seen: set[str] = set()
    seen_sources: set[str] = set()
    for artifact_index, artifact in enumerate(artifacts, 1):
        if not isinstance(artifact, Mapping):
            raise RunnerError(f"cell failure artifact row is malformed: {path}")
        artifact_path = Path(str(artifact.get("path") or "")).resolve()
        try:
            artifact_path.relative_to(cell_dir)
        except ValueError as exc:
            raise RunnerError(f"cell failure artifact escapes its cell directory: {path}") from exc
        relative_path = artifact_path.relative_to(cell_dir).as_posix()
        if artifact.get("relative_path") != relative_path or relative_path in seen:
            raise RunnerError(f"cell failure artifact path is contradictory: {path}")
        seen.add(relative_path)
        if snapshot_root is not None:
            try:
                artifact_path.relative_to(snapshot_root)
            except ValueError as exc:
                raise RunnerError(
                    f"cell failure artifact is outside its attempt snapshot: {path}"
                ) from exc
            source_relative_path = str(
                artifact.get("source_relative_path") or ""
            )
            source_parts = PurePosixPath(source_relative_path).parts
            if (
                not source_relative_path
                or PurePosixPath(source_relative_path).is_absolute()
                or ".." in source_parts
                or ":" in source_relative_path
                or "\\" in source_relative_path
                or source_relative_path in seen_sources
            ):
                raise RunnerError(
                    f"cell failure source artifact path is contradictory: {path}"
                )
            seen_sources.add(source_relative_path)
            if snapshot_layout in CELL_FAILURE_SNAPSHOT_LAYOUTS:
                expected_artifact_path = (
                    snapshot_root
                    / _failure_snapshot_artifact_name(
                        PurePosixPath(source_relative_path),
                        artifact_index,
                        layout=snapshot_layout,
                    )
                ).resolve()
            else:
                # Backward-compatible authentication for v2 sidecars emitted
                # before the flat Windows-safe layout was introduced.
                expected_artifact_path = snapshot_root.joinpath(
                    *source_parts
                ).resolve()
            if artifact_path != expected_artifact_path:
                raise RunnerError(
                    f"cell failure artifact/source paths disagree: {path}"
                )
        _verify_hash(artifact_path, str(artifact.get("sha256") or ""), "cell failure artifact")
        if artifact.get("size_bytes") != artifact_path.stat().st_size:
            raise RunnerError(f"cell failure artifact size mismatch: {artifact_path}")
    return {
        "run_identity_sha256": spec["run_identity_sha256"],
        "error_type": str(failure["error_type"]),
        "error": str(failure["error"]),
        "failure_path": str(resolved_path),
        "failure_sha256": contract.sha256_file(path),
        "failure_occurrence": _cell_failure_occurrence(path),
        "failure_schema_version": schema_version,
        "artifact_count": len(artifacts),
    }


def _execution_failure_reference(
    output_root: Path,
    *,
    plan: Mapping[str, Any],
) -> dict[str, Any] | None:
    path = output_root.resolve() / "execution_failure.json"
    if not path.is_file():
        return None
    failure = _load_json(path, f"execution failure {path}")
    schema_version = str(failure.get("schema_version") or "")
    if schema_version not in SUPPORTED_EXECUTION_FAILURE_SCHEMAS:
        raise RunnerError(
            f"unsupported execution failure schema {schema_version!r}: {path}"
        )
    if str(failure.get("work_item_id") or "") != str(plan["work_item_id"]):
        raise RunnerError(f"execution failure work_item_id mismatch: {path}")
    run_identity = str(failure.get("run_identity_sha256") or "")
    spec = next(
        (
            row
            for row in plan["cells"]
            if str(row["run_identity_sha256"]) == run_identity
        ),
        None,
    )
    if spec is None:
        raise RunnerError(f"execution failure names an unknown cell: {path}")
    sidecar_path = Path(str(failure.get("cell_failure_path") or "")).resolve()
    cell_dir = _cell_failure_path(spec).parent.resolve()
    if (
        sidecar_path.parent != cell_dir
        or CELL_FAILURE_SIDECAR_RE.fullmatch(sidecar_path.name) is None
    ):
        raise RunnerError(f"execution failure sidecar path is contradictory: {path}")
    occurrence = _cell_failure_occurrence(sidecar_path)
    if (
        schema_version == EXECUTION_FAILURE_SCHEMA
        and failure.get("cell_failure_occurrence") != occurrence
    ):
        raise RunnerError(
            f"execution failure sidecar occurrence is contradictory: {path}"
        )
    sidecar_sha256 = str(failure.get("cell_failure_sha256") or "")
    _verify_hash(sidecar_path, sidecar_sha256, "execution failure sidecar")
    return {
        "path": path,
        "sha256": contract.sha256_file(path),
        "schema_version": schema_version,
        "run_identity_sha256": run_identity,
        "cell_failure_path": sidecar_path,
        "cell_failure_sha256": sidecar_sha256,
        "cell_failure_occurrence": occurrence,
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
    failed: list[dict[str, Any]] = []
    invalid_failures: list[dict[str, str]] = []
    invalid_receipts: list[dict[str, str]] = []
    collection_root = (output_root or plan_path.parent).resolve()
    execution_failure_path = collection_root / "execution_failure.json"
    execution_failure: dict[str, Any] | None = None
    has_missing_receipt = any(
        not Path(str(spec["receipt_path"])).is_file()
        for spec in plan["cells"]
    )
    if has_missing_receipt and execution_failure_path.is_file():
        try:
            execution_failure = _execution_failure_reference(
                collection_root, plan=plan
            )
        except RunnerError as exc:
            invalid_failures.append(
                {
                    "run_identity_sha256": "",
                    "error": str(exc),
                }
            )
    for spec in plan["cells"]:
        receipt_path = Path(str(spec["receipt_path"]))
        cell_id = str(spec["run_identity_sha256"])
        if not receipt_path.is_file():
            try:
                if execution_failure is not None:
                    if execution_failure["run_identity_sha256"] != cell_id:
                        missing.append(cell_id)
                        continue
                    failure = _authenticated_cell_failure(
                        spec,
                        work_item_id=str(plan["work_item_id"]),
                        failure_path=execution_failure["cell_failure_path"],
                        expected_failure_sha256=execution_failure[
                            "cell_failure_sha256"
                        ],
                    )
                    if failure is None:
                        raise RunnerError(
                            "execution failure sidecar disappeared during collection"
                        )
                elif execution_failure_path.is_file():
                    # An invalid authoritative pointer may not be bypassed by
                    # authenticating an older numbered sidecar.
                    missing.append(cell_id)
                    continue
                else:
                    # Primary continue-on-failure path: the executor records
                    # each failed cell as its own immutable cell_failure sidecar
                    # (no single execution_failure pointer), so authenticate this
                    # cell's sidecar directly.  Also the backward-compatible read
                    # path for pre-v2 artifacts that never published a pointer.
                    failure = _authenticated_cell_failure(
                        spec, work_item_id=str(plan["work_item_id"])
                    )
            except RunnerError as exc:
                invalid_failures.append(
                    {"run_identity_sha256": cell_id, "error": str(exc)}
                )
                continue
            if failure is None:
                missing.append(cell_id)
            else:
                failed.append(failure)
            continue
        try:
            cells.append(_receipt_to_cell(spec))
        except RunnerError as exc:
            invalid_receipts.append(
                {"run_identity_sha256": cell_id, "error": str(exc)}
            )
    invalid = invalid_failures + invalid_receipts
    payload = _evidence_payload(input_manifest, cells)
    if invalid:
        adjudication = _nonlocking_adjudication(
            verdict="INVALID_EVIDENCE",
            reason_code=(
                "cell_failure_manifest_invalid"
                if invalid_failures
                else "cell_receipt_invalid"
            ),
            input_manifest=input_manifest,
            details={
                "planned_cell_count": int(plan["cell_count"]),
                "authenticated_cell_count": len(cells),
                "failed_cell_count": len(failed),
                "missing_cell_count": len(missing),
                "invalid_cells": invalid,
                "invalid_failure_cells": invalid_failures,
                "invalid_receipt_cells": invalid_receipts,
            },
        )
    elif failed:
        adjudication = _nonlocking_adjudication(
            verdict="REVIEW_REQUIRED",
            reason_code="cell_execution_failed",
            input_manifest=input_manifest,
            details={
                "planned_cell_count": int(plan["cell_count"]),
                "authenticated_cell_count": len(cells),
                "failed_cell_count": len(failed),
                "missing_cell_count": len(missing),
                "failed_cells": failed,
                "missing_run_identity_sha256": missing,
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
    planned = int(plan["cell_count"])
    accounted = len(cells) + len(failed) + len(missing) + len(invalid)
    result.update({
        "planned_cell_count": planned,
        "authenticated_cell_count": len(cells),
        "failed_cell_count": len(failed),
        "missing_cell_count": len(missing),
        "invalid_cell_count": len(invalid),
        # Every planned cell lands in exactly one bucket
        # (authenticated | failed | missing | invalid); this guards the
        # matrix-scope accounting so a partial run can never silently drop a
        # cell from the aggregate.
        "accounted_cell_count": accounted,
        "accounting_reconciled": accounted == planned,
    })
    return result


def assert_factory_capacity(
    farm_root: Path,
    *,
    work_item_id: str,
    terminal: str,
    plan_path: Path,
    expected_plan_file_sha256: str,
    primary_terminal: str | None = None,
    helper_reserved_by: str | None = None,
) -> dict[str, Any]:
    """Prove the main claim or an exact helper reservation is still owned."""

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
    execution_terminal = str(terminal).strip().upper()
    claim_terminal = str(primary_terminal or terminal).strip().upper()
    if row["status"] != "active" or str(row["claimed_by"] or "").upper() != claim_terminal:
        raise CapacityError(
            "Q09 factory capacity refused: exact active terminal claim is not owned"
        )
    if execution_terminal != claim_terminal:
        if not FACTORY_TERMINAL_RE.fullmatch(execution_terminal):
            raise CapacityError("Q09 helper capacity refused: invalid factory terminal")
        reserved_by = str(helper_reserved_by or "").strip()
        if not reserved_by:
            raise CapacityError("Q09 helper capacity refused: reservation identity missing")
        reservation_path = farm_root / "state" / "terminal_reservations.json"
        try:
            reservation_document = json.loads(
                reservation_path.read_text(encoding="utf-8-sig")
            )
            reservations = reservation_document.get(
                "reservations", reservation_document
            )
            reservation = reservations[execution_terminal]
            until = datetime.fromisoformat(
                str(reservation["until_utc"]).replace("Z", "+00:00")
            )
            if until.tzinfo is None:
                until = until.replace(tzinfo=timezone.utc)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
            raise CapacityError(
                "Q09 helper capacity refused: reservation state is missing or unreadable"
            ) from exc
        if (
            str(reservation.get("reserved_by") or "") != reserved_by
            or str(reservation.get("reason") or "")
            != f"Q09_NEWS helper for {work_item_id}"
            or until.astimezone(timezone.utc) <= datetime.now(timezone.utc)
        ):
            raise CapacityError(
                "Q09 helper capacity refused: exact live helper reservation is not owned"
            )
    try:
        payload = json.loads(str(row["payload_json"] or "{}"))
    except json.JSONDecodeError as exc:
        raise CapacityError("Q09 factory capacity refused: payload is invalid JSON") from exc
    if payload.get("q09_binding_version") != "q09-news-dispatch-binding/v1":
        raise CapacityError("Q09 factory capacity refused: sealed dispatch binding missing")
    if payload.get("diagnostic_non_admission") is True:
        if payload.get("diagnostic_contract") != DIAGNOSTIC_CONTRACT:
            raise CapacityError("Q09 diagnostic capacity refused: contract marker missing")
        if str(terminal).upper() not in DIAGNOSTIC_ALLOWED_TERMINALS:
            raise CapacityError("Q09 diagnostic capacity refused: five-terminal cap violated")
        anchor_path = Path(str(payload.get("diagnostic_anchor_path") or ""))
        _verify_hash(
            anchor_path,
            str(payload.get("diagnostic_anchor_sha256") or ""),
            "bound Q09 diagnostic anchor",
        )
        staging = payload.get("staged_ex5") or {}
        required_ex5 = str(payload.get("staged_ex5_sha256") or "").lower()
        if (
            not isinstance(staging, Mapping)
            or staging.get("required_sha256") != required_ex5
            or staging.get("pre_run_sha256") != required_ex5
        ):
            raise CapacityError("Q09 diagnostic capacity refused: exact live EX5 was not staged")
        _verify_hash(
            Path(str(staging.get("destination_path") or "")),
            required_ex5,
            "staged Q09 diagnostic live EX5",
        )
    bound_path = Path(str(payload.get("q09_run_plan_path") or ""))
    if bound_path.resolve() != plan_path.resolve():
        raise CapacityError("Q09 factory capacity refused: run-plan path differs from binding")
    expected = str(expected_plan_file_sha256).strip().lower()
    if payload.get("q09_run_plan_file_sha256") != expected:
        raise CapacityError("Q09 factory capacity refused: run-plan hash differs from binding")
    _verify_hash(plan_path.resolve(), expected, "bound Q09 run-plan")
    actual_binding = _dispatch_binding_sha256(payload)
    if (
        payload.get("diagnostic_non_admission") is True
        and payload.get("q09_dispatch_binding_sha256") != actual_binding
    ):
        # Retry steering may add a failed T1-T5 slot to avoid_terminals.  The
        # sealed diagnostic binding authenticates the permanent T6-T10
        # exclusion, not that mutable in-fleet retry hint.
        stable_payload = dict(payload)
        stable_payload["avoid_terminals"] = ["T6", "T7", "T8", "T9", "T10"]
        actual_binding = _dispatch_binding_sha256(stable_payload)
    if payload.get("q09_dispatch_binding_sha256") != actual_binding:
        raise CapacityError("Q09 factory capacity refused: dispatch binding hash mismatch")
    q07_path = Path(str(payload.get("q09_q07_evidence_path") or ""))
    _verify_hash(
        q07_path,
        str(payload.get("q09_q07_evidence_sha256") or ""),
        "bound Q07 seed-stability evidence",
    )
    return {"row": dict(row), "payload": payload}


def _stage_diagnostic_expert_binary(
    payload: Mapping[str, Any], *, terminal: str, expert: str
) -> dict[str, str]:
    """Stage the exact bound live EX5 under the executor's effective label.

    Long-lived workers loaded before this diagnostic lane may still construct
    the ordinary numeric-only expert label.  The runner owns the reserved slot
    before MT5 starts, so it can safely materialize that alias from the same
    hash-bound deployed binary and then authenticate it before every cell.
    """

    normalized = str(expert or "").strip().replace("/", "\\")
    parts = [part for part in normalized.split("\\") if part]
    if (
        len(parts) != 2
        or parts[0].upper() != "QM"
        or parts[1] in {".", ".."}
        or ":" in parts[1]
        or Path(parts[1]).name != parts[1]
    ):
        raise CapacityError("Q09 diagnostic capacity refused: unsafe expert label")
    required = str(payload.get("staged_ex5_sha256") or "").lower()
    source = Path(str(payload.get("staged_ex5_path") or "")).resolve()
    _verify_hash(source, required, "bound Q09 diagnostic deployed EX5")
    terminal_root = _claimed_factory_terminal_root(terminal).resolve()
    expert_root = (terminal_root / "MQL5" / "Experts").resolve()
    destination = (expert_root / parts[0] / f"{parts[1]}.ex5").resolve()
    try:
        destination.relative_to(expert_root)
    except ValueError as exc:
        raise CapacityError(
            "Q09 diagnostic capacity refused: expert destination escaped terminal root"
        ) from exc
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.is_file() or contract.sha256_file(destination) != required:
        temporary = destination.with_name(f"{destination.name}.{os.getpid()}.tmp")
        try:
            temporary.write_bytes(source.read_bytes())
            if contract.sha256_file(temporary) != required:
                raise CapacityError(
                    "Q09 diagnostic capacity refused: staged expert alias hash mismatch"
                )
            os.replace(temporary, destination)
        finally:
            if temporary.exists():
                temporary.unlink()
    _verify_hash(destination, required, "effective Q09 diagnostic expert EX5")
    return {
        "source_path": str(source),
        "destination_path": str(destination),
        "sha256": required,
        "expert": normalized,
    }


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
    # A numeric zero is a legitimate report value (zero trades, zero profit);
    # `raw or ""` would silently reclassify it as missing.
    if isinstance(raw, bool):
        raise RunnerError(f"MT5 report {field} is not numeric")
    if isinstance(raw, (int, float)):
        value = float(raw)
        if not math.isfinite(value):
            raise RunnerError(f"MT5 report {field} is not finite")
        return value
    text = str(raw if raw is not None else "").replace("\xa0", " ").strip()
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


def _summary_reason_classes(summary_path: Path) -> list[str]:
    """Return the run_smoke FAIL summary's reason classes as plain strings.

    A malformed or absent ``reason_classes`` list yields ``[]`` (which the
    caller treats as a non-transient, non-retryable result).
    """

    summary = _load_json(summary_path, "run_smoke summary")
    raw = summary.get("reason_classes")
    if not isinstance(raw, list):
        return []
    return [str(item) for item in raw]


def _fail_summary_is_transient(summary_path: Path) -> bool:
    """True iff every reason class in the fresh FAIL summary is transient/infra.

    An empty (or unclassified) reason-class list is NOT transient: a FAIL with
    no explained class is a genuine result and must not be silently retried.
    """

    reason_classes = _summary_reason_classes(summary_path)
    return bool(reason_classes) and all(
        reason_class in Q09_TRANSIENT_REASON_CLASSES
        for reason_class in reason_classes
    )


def _single_ok_run(summary: Mapping[str, Any]) -> Mapping[str, Any]:
    """Return the sole successful attempt from a run_smoke summary."""

    runs = summary.get("runs")
    if not isinstance(runs, list):
        raise RunnerError("run_smoke did not publish exactly one authenticated OK run")
    ok_runs = [
        run for run in runs
        if isinstance(run, Mapping) and run.get("status") == "OK"
    ]
    if len(ok_runs) != 1:
        raise RunnerError("run_smoke did not publish exactly one authenticated OK run")
    return ok_runs[0]


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
    run = _single_ok_run(summary)
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
    if trades == 0 and (original - blocked) > 0:
        # Mirror of the check above: the framework accepted entries but the
        # report shows none.  An externally terminated tester pass writes a
        # settings-complete report with zeroed statistics and exit code 0;
        # that is an infrastructure event, never a measurement.  A legitimate
        # full news block keeps accepted == 0 (original == blocked) and is
        # not affected.
        raise TransientCellError(
            f"MT5 report shows zero trades but the framework logged "
            f"{original - blocked} accepted entries; treating this as a "
            "terminated tester pass"
        )
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


def _claimed_factory_terminal_root(terminal: str) -> Path:
    terminal_name = str(terminal).upper()
    if re.fullmatch(r"T(?:[1-9]|10)", terminal_name) is None:
        raise CapacityError(
            f"Q09 terminal exit gate refused non-factory terminal {terminal!r}"
        )
    return (FACTORY_MT5_ROOT / terminal_name).resolve()


def _path_is_under_root(path: str, root: Path) -> bool:
    if not str(path).strip():
        return False
    try:
        candidate = os.path.normcase(os.path.realpath(os.path.abspath(str(path))))
        anchor = os.path.normcase(os.path.realpath(os.path.abspath(str(root))))
        return os.path.commonpath((candidate, anchor)) == anchor
    except (OSError, ValueError):
        return False


def _scan_terminal64_processes() -> list[dict[str, Any]]:
    command = [
        "pwsh.exe",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        (
            "$ErrorActionPreference='Stop'; "
            "@(Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" "
            "| Select-Object ProcessId,ExecutablePath) "
            "| ConvertTo-Json -Compress -Depth 3"
        ),
    ]
    creationflags = 0x08000000 if sys.platform == "win32" else 0
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=creationflags,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RunnerError(f"Q09 terminal process scan failed: {exc}") from exc
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "").strip()
        raise RunnerError(
            f"Q09 terminal process scan exited with code {completed.returncode}: {detail}"
        )
    raw = (completed.stdout or "").strip()
    if not raw:
        return []
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RunnerError("Q09 terminal process scan returned invalid JSON") from exc
    rows = payload if isinstance(payload, list) else [payload]
    if not all(isinstance(row, dict) for row in rows):
        raise RunnerError("Q09 terminal process scan returned an invalid row set")
    return rows


def _claimed_terminal_processes(
    processes: Sequence[Mapping[str, Any]],
    terminal_root: Path,
) -> list[dict[str, Any]]:
    matches: list[dict[str, Any]] = []
    for process in processes:
        executable_path = str(process.get("ExecutablePath") or "")
        if Path(executable_path).name.lower() != "terminal64.exe":
            continue
        if not _path_is_under_root(executable_path, terminal_root):
            continue
        matches.append(dict(process))
    return matches


def _wait_for_claimed_terminal_exit(
    terminal_root: Path,
    *,
    timeout_sec: float = TERMINAL_EXIT_WAIT_SEC,
    poll_sec: float = TERMINAL_EXIT_POLL_SEC,
    process_scan: Callable[[], Sequence[Mapping[str, Any]]] | None = None,
    monotonic: Callable[[], float] | None = None,
    sleeper: Callable[[float], None] | None = None,
) -> None:
    """Wait for terminal64 processes under one claimed factory root to exit."""

    if timeout_sec <= 0 or poll_sec <= 0:
        raise RunnerError("Q09 terminal exit wait requires positive timeout and poll values")
    scan = process_scan or _scan_terminal64_processes
    clock = monotonic or time.monotonic
    sleep = sleeper or time.sleep
    started = clock()
    deadline = started + float(timeout_sec)
    while True:
        matching = _claimed_terminal_processes(scan(), terminal_root)
        if not matching:
            return
        remaining = deadline - clock()
        if remaining <= 0:
            pids = sorted(
                str(process.get("ProcessId") or "unknown") for process in matching
            )
            raise RunnerError(
                "Q09 claimed-terminal exit wait timed out after "
                f"{float(timeout_sec):g}s for {terminal_root}; "
                f"terminal64.exe pids still active: {','.join(pids)}"
            )
        sleep(min(float(poll_sec), remaining))


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
            # Q09 measures the policy-induced entry delta in each independent
            # window.  It is diagnostic non-admission work, so the Q02
            # five-trades-per-year floor must not replace this explicit zero.
            # SmokeMode is run_smoke's opt-in for honoring the caller's floor;
            # admission callers retain the default fail-closed Q02 behavior.
            "-Runs", "1", "-MinTrades", "0", "-SmokeMode", "-Model", "4",
            "-TimeoutSeconds", str(context["cell_timeout_sec"]),
            "-SetFile", str(spec["setfile_path"]), "-ReportRoot", str(run_root),
            "-DispatchPhase", "Q09_NEWS", "-DispatchVersion", "q09_news_executor_v1",
            "-DispatchSubGateHash", f"{str(spec['run_identity_sha256'])[:16]}_{window_name}",
            "-ExpectedExpertSha256", str(context["expected_expert_sha256"]),
            "-RequireFreshLoggerSample",
        ]
        if context.get("skip_expert_deploy") is True:
            command.append("-SkipExpertDeploy")
        _wait_for_claimed_terminal_exit(Path(str(context["terminal_root"])))
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
            if completed.returncode == 1:
                try:
                    summary_path = _latest_summary(run_root, started_at)
                except RunnerError as summary_error:
                    # Child exit 1 with NO fresh tester summary at all: a cold-
                    # cache/wedge flake -> transient retry lane.
                    raise TransientCellError(
                        f"Q09 {window_name} run_smoke exited with code 1 "
                        "without a fresh run_smoke summary or cell receipt"
                    ) from summary_error
                # A fresh FAIL summary exists.  If every reason class is within
                # the transient/infra set (cold-cache BARS_ZERO/NO_HISTORY,
                # TIMEOUT, INCOMPLETE_RUNS, MODEL4_MARKER_REQUIRED), route it
                # into the same bounded per-cell retry lane.  Any other/unknown
                # reason class (genuine zero-signal, PF-missing validation, ...)
                # stays a non-transient result: recorded-and-continue, no retry.
                if _fail_summary_is_transient(summary_path):
                    raise TransientCellError(
                        f"Q09 {window_name} run_smoke FAIL is transient "
                        f"(reason_classes="
                        f"{sorted(_summary_reason_classes(summary_path))})"
                    )
                raise RunnerError(
                    f"Q09 {window_name} run_smoke exited with code 1 "
                    f"(reason_classes="
                    f"{sorted(_summary_reason_classes(summary_path))})"
                )
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
        "news_selfreport": context["news_selfreport"],
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
        "news_selfreport": context["news_selfreport"],
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
    capacity = assert_factory_capacity(
        farm_root,
        work_item_id=work_item_id,
        terminal=terminal,
        plan_path=plan_path,
        expected_plan_file_sha256=expected_plan_file_sha256,
    )
    evidence_payload = _load_json(Path(str(result["evidence_path"])), "Q09 evidence")
    adjudication = _load_json(Path(str(result["aggregate_path"])), "Q09 adjudication")
    database = _farm_db_path(farm_root)
    if capacity["payload"].get("diagnostic_non_admission") is True:
        connection = sqlite3.connect(str(database), timeout=30)
        try:
            recorded = connection.execute(
                "SELECT 1 FROM q09_news_tests WHERE work_item_id=?", (str(work_item_id),)
            ).fetchone()
        finally:
            connection.close()
        if recorded is not None:
            raise RunnerError("diagnostic Q09 result collided with canonical admission storage")
        summary_path = Path(str(result["aggregate_path"])).resolve().parent / "summary.json"
        diagnostic_summary = {
            "schema_version": DIAGNOSTIC_SUMMARY_SCHEMA,
            "phase": "Q09_NEWS",
            "verdict": "REVIEW_REQUIRED",
            "reason": "diagnostic_non_admission",
            "reason_codes": ["diagnostic_non_admission", "owner_review_required"],
            "diagnostic_non_admission": True,
            "diagnostic_contract": DIAGNOSTIC_CONTRACT,
            "work_item_id": str(work_item_id),
            "underlying_q09_verdict": adjudication.get("verdict"),
            "aggregate_path": str(Path(str(result["aggregate_path"])).resolve()),
            "aggregate_sha256": str(result["aggregate_sha256"]),
            "evidence_path": str(Path(str(result["evidence_path"])).resolve()),
            "evidence_sha256": contract.sha256_file(Path(str(result["evidence_path"]))),
            "diagnostic_anchor_path": capacity["payload"].get("diagnostic_anchor_path"),
            "diagnostic_anchor_sha256": capacity["payload"].get("diagnostic_anchor_sha256"),
        }
        _atomic_write(summary_path, contract.canonical_json_bytes(diagnostic_summary))
        return {
            "status": "DIAGNOSTIC_RECORDED",
            "verdict": "REVIEW_REQUIRED",
            "summary_path": str(summary_path),
            "summary_sha256": contract.sha256_file(summary_path),
        }
    connection = sqlite3.connect(str(database), timeout=30)
    connection.row_factory = sqlite3.Row
    try:
        summary_inserted = news_schema.record_q09_adjudication(
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
        return {
            "status": "RECORDED" if summary_inserted else "ALREADY_RECORDED",
            "verdict": recorded["verdict"],
        }
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
    period: str | None,
    repo_root: Path,
    common_root: Path,
    dispatch_cell: Callable[[Mapping[str, Any], Mapping[str, Any]], None] | None = None,
    cell_retry_budget: int = DEFAULT_CELL_RETRY_BUDGET,
    cell_shard: str | None = None,
    cell_keys: Sequence[str] | None = None,
    helper_terminals: Sequence[str] | None = None,
    helper_reserved_by: str | None = None,
) -> dict[str, Any]:
    """Execute selected cells, optionally sharded across leased factory slots.

    A single failing cell never aborts the experiment: each cell is retried up
    to ``cell_retry_budget`` extra times on a transient class, then recorded as
    a failed cell so the remaining planned cells still run.  The run ends with a
    maximal authenticated set plus precise failed/missing accounting, and the
    fail-closed contract adjudication decides the verdict.
    """

    plan_path = plan_path.resolve()
    plan, input_manifest = load_authenticated_plan(
        plan_path,
        expected_file_sha256=expected_plan_file_sha256,
    )
    execution_period = resolve_execution_period(input_manifest, period)
    if str(plan["work_item_id"]) != str(work_item_id):
        raise RunnerError("executor work_item_id differs from sealed run plan")
    primary_terminal = str(terminal).strip().upper()
    capacity = assert_factory_capacity(
        farm_root,
        work_item_id=work_item_id,
        terminal=primary_terminal,
        plan_path=plan_path,
        expected_plan_file_sha256=expected_plan_file_sha256,
    )
    payload = capacity["payload"]
    row = capacity["row"]
    diagnostic_expert_stage = None
    if payload.get("diagnostic_non_admission") is True:
        diagnostic_expert_stage = _stage_diagnostic_expert_binary(
            payload, terminal=terminal, expert=expert
        )
    helpers = [str(value).strip().upper() for value in (helper_terminals or [])]
    if len(helpers) != len(set(helpers)):
        raise CapacityError("Q09 helper terminal list contains duplicates")
    if primary_terminal in helpers:
        raise CapacityError("Q09 helper terminal list contains the main terminal")
    if any(not FACTORY_TERMINAL_RE.fullmatch(value) for value in helpers):
        raise CapacityError("Q09 helper terminal list contains a non-factory terminal")
    if helpers and (cell_shard or cell_keys):
        raise RunnerError("Q09 helper terminals cannot be combined with a subset selector")
    if helpers and payload.get("diagnostic_non_admission") is True:
        raise CapacityError("Q09 diagnostic runs cannot use helper terminals")
    if helpers and not str(helper_reserved_by or "").strip():
        raise CapacityError("Q09 helper reservation identity is missing")
    for helper_terminal in helpers:
        assert_factory_capacity(
            farm_root,
            work_item_id=work_item_id,
            terminal=helper_terminal,
            primary_terminal=primary_terminal,
            helper_reserved_by=helper_reserved_by,
            plan_path=plan_path,
            expected_plan_file_sha256=expected_plan_file_sha256,
        )
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
        "terminal": primary_terminal,
        "terminal_root": str(_claimed_factory_terminal_root(primary_terminal)),
        "ea_id": int(ea_id),
        "expert": str(expert),
        "symbol": str(symbol),
        "period": execution_period,
        "repo_root": str(repo_root.resolve()),
        "run_smoke_path": str((repo_root / "framework" / "scripts" / "run_smoke.ps1").resolve()),
        "cell_timeout_sec": int(payload["q09_cell_timeout_sec"]),
        "q07_work_item_id": payload["q09_q07_work_item_id"],
        "q07_evidence_sha256": payload["q09_q07_evidence_sha256"],
        "calendar_provision": provision,
        "news_selfreport": build_news_selfreport(calendar_manifest),
        "skip_expert_deploy": payload.get("diagnostic_non_admission") is True,
        "diagnostic_expert_stage": diagnostic_expert_stage,
        "expected_expert_sha256": (
            diagnostic_expert_stage["sha256"]
            if diagnostic_expert_stage is not None
            else input_manifest["identities"]["ex5_sha256"]
        ),
    }
    dispatcher = dispatch_cell or _production_dispatch_cell
    budget = int(cell_retry_budget)
    if budget < 0:
        raise RunnerError("Q09 cell retry budget must be non-negative")

    def _reverify_before_attempt(cell_context: Mapping[str, Any]) -> None:
        # A child can exit before its terminal process fully releases the
        # claimed profile.  Each retry waits for that exact terminal root to
        # clear and re-verifies the claim is still ours (and, for the diagnostic
        # lane, that the staged expert binary is unchanged) before re-dispatch.
        execution_terminal = str(cell_context["terminal"])
        _wait_for_claimed_terminal_exit(Path(str(cell_context["terminal_root"])))
        assert_factory_capacity(
            farm_root,
            work_item_id=work_item_id,
            terminal=execution_terminal,
            primary_terminal=primary_terminal,
            helper_reserved_by=(
                helper_reserved_by
                if execution_terminal != primary_terminal
                else None
            ),
            plan_path=plan_path,
            expected_plan_file_sha256=expected_plan_file_sha256,
        )
        if diagnostic_expert_stage is not None:
            _verify_hash(
                Path(diagnostic_expert_stage["destination_path"]),
                diagnostic_expert_stage["sha256"],
                "effective Q09 diagnostic expert EX5",
            )

    def _run_one_cell(
        spec: Mapping[str, Any],
        cell_context: Mapping[str, Any],
        *,
        helper: bool,
    ) -> None:
        """Dispatch a single cell with a bounded transient retry budget.

        A ``CapacityError`` is re-raised so the ordinary worker can requeue the
        whole work item (genuine claim/host loss).  Every other failure is
        cell-scoped: a transient class is retried up to ``budget`` extra times,
        and any residual transient exhaustion or non-transient tester error is
        written as an immutable ``cell_failure`` sidecar and swallowed, so the
        outer loop records the cell as failed and continues with the remaining
        planned cells.  One flaky cell can no longer abort the experiment.
        """

        transient_retries_used = 0
        while True:
            try:
                dispatcher(spec, cell_context)
                _receipt_to_cell(spec)
                return
            except CapacityError:
                raise
            except TransientCellError as exc:
                if helper:
                    raise HelperAbortError(str(exc)) from exc
                _write_cell_failure(
                    spec, work_item_id=str(work_item_id), exc=exc
                )
                if transient_retries_used >= budget:
                    return
                transient_retries_used += 1
                _reverify_before_attempt(cell_context)
            except Exception as exc:  # noqa: BLE001 - cell-scoped, non-transient
                if helper:
                    raise HelperAbortError(str(exc)) from exc
                _write_cell_failure(
                    spec, work_item_id=str(work_item_id), exc=exc
                )
                return

    selected_cells = select_plan_cells(
        plan, cell_shard=cell_shard, cell_keys=cell_keys
    )

    def _context_for(execution_terminal: str) -> dict[str, Any]:
        cell_context = dict(context)
        cell_context["terminal"] = execution_terminal
        cell_context["terminal_root"] = str(
            _claimed_factory_terminal_root(execution_terminal)
        )
        return cell_context

    def _run_cells(
        specs: Sequence[Mapping[str, Any]], execution_terminal: str, *, helper: bool
    ) -> None:
        cell_context = _context_for(execution_terminal)
        for spec in specs:
            receipt_path = Path(str(spec["receipt_path"]))
            if receipt_path.is_file():
                # Receipts are immutable and idempotent. Authentication remains
                # the collector's job, so a contradictory pre-existing receipt
                # is never silently replaced by a helper.
                continue
            assert_factory_capacity(
                farm_root,
                work_item_id=work_item_id,
                terminal=execution_terminal,
                primary_terminal=primary_terminal,
                helper_reserved_by=(helper_reserved_by if helper else None),
                plan_path=plan_path,
                expected_plan_file_sha256=expected_plan_file_sha256,
            )
            if diagnostic_expert_stage is not None:
                _verify_hash(
                    Path(diagnostic_expert_stage["destination_path"]),
                    diagnostic_expert_stage["sha256"],
                    "effective Q09 diagnostic expert EX5",
                )
            _run_one_cell(spec, cell_context, helper=helper)

    helper_abortions: list[dict[str, str]] = []
    if helpers:
        terminals = [primary_terminal, *helpers]
        assignments = build_cell_shard_assignments(plan, len(terminals))
        by_key = {cell_key(spec): spec for spec in plan["cells"]}
        with ThreadPoolExecutor(max_workers=len(terminals)) as executor:
            futures = {
                executor.submit(
                    _run_cells,
                    [by_key[key] for key in assignments[index]],
                    execution_terminal,
                    helper=index > 0,
                ): (execution_terminal, index > 0)
                for index, execution_terminal in enumerate(terminals)
            }
            for future in as_completed(futures):
                execution_terminal, is_helper = futures[future]
                try:
                    future.result()
                except Exception as exc:  # helper loss is caught up below
                    if not is_helper:
                        raise
                    helper_abortions.append(
                        {"terminal": execution_terminal, "error": repr(exc)}
                    )
        # A helper exit without an immutable receipt leaves its cell eligible
        # for the main terminal. Main-shard failures are terminal outcomes.
        catchup = [
            spec
            for spec in plan["cells"]
            if not Path(str(spec["receipt_path"])).is_file()
            and not _cell_failure_path(spec).is_file()
        ]
        _run_cells(catchup, primary_terminal, helper=False)
    else:
        _run_cells(selected_cells, primary_terminal, helper=False)

    complete_count = sum(
        1
        for spec in plan["cells"]
        if Path(str(spec["receipt_path"])).is_file()
        or _cell_failure_path(spec).is_file()
    )
    if complete_count != int(plan["cell_count"]):
        # A shard worker never publishes a partial aggregate. A later
        # idempotent shard/main pass can fill the remaining cells and collect.
        return {
            "status": "SHARD_COMPLETE",
            "verdict": "SHARD_COMPLETE",
            "aggregate_published": False,
            "planned_cell_count": int(plan["cell_count"]),
            "selected_cell_count": len(selected_cells),
            "completed_cell_count": complete_count,
            "helper_abortions": helper_abortions,
        }

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
    result["aggregate_published"] = True
    result["helper_abortions"] = helper_abortions
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
    shard_plan = sub.add_parser("shard-plan")
    shard_plan.add_argument("--plan", required=True, type=Path)
    shard_plan.add_argument("--expected-plan-file-sha256", required=True)
    shard_plan.add_argument("--shards", required=True, type=int)
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
    execute.add_argument(
        "--period",
        help="Optional explicit period; when present it must match the sealed Q08 baseline",
    )
    execute.add_argument("--repo-root", required=True, type=Path)
    execute.add_argument("--common-root", required=True, type=Path)
    execute.add_argument("--cell-shard")
    execute.add_argument("--cell-key", action="append", dest="cell_keys")
    execute.add_argument("--helper-terminal", action="append", dest="helper_terminals")
    execute.add_argument("--helper-reserved-by")
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
            cell_shard=args.cell_shard,
            cell_keys=args.cell_keys,
            helper_terminals=args.helper_terminals,
            helper_reserved_by=args.helper_reserved_by,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["verdict"] in {"CONFIG_LOCKED", "SHARD_COMPLETE"} else 2
    if args.command == "shard-plan":
        plan, _manifest = load_authenticated_plan(
            args.plan.resolve(),
            expected_file_sha256=args.expected_plan_file_sha256,
        )
        assignments = build_cell_shard_assignments(plan, args.shards)
        result = {
            "schema_version": "q09-news-cell-shard-plan/v1",
            "plan_path": str(args.plan.resolve()),
            "plan_sha256": plan["plan_sha256"],
            "cell_count": int(plan["cell_count"]),
            "shard_count": int(args.shards),
            "shards": [
                {"index": index + 1, "cell_count": len(keys), "cell_keys": keys}
                for index, keys in enumerate(assignments)
            ],
            "mt5_started": False,
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    result = collect_run_plan_status(
        args.plan,
        output_root=args.output_root,
        expected_plan_file_sha256=args.expected_plan_file_sha256,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["verdict"] == "CONFIG_LOCKED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
