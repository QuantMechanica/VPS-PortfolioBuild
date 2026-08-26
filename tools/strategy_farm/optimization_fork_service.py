"""Governed no-change executor for manifest-routed optimization work items.

The optimization fork router deliberately creates ``kind=analytic`` rows,
which terminal workers must not claim.  This service consumes only the narrow
legacy no-change contract emitted before the mandatory DL-089 declaration was
wired into :mod:`optimization_fork_driver`:

* Q12/PATTERN may finish as ``NO_FILTER_CHANGE`` only when the payload declares
  that zero selected filters is valid and contains no filter-search result or
  candidate plan for a human/analytic selector to adjudicate.  Current Q12
  rows always carry the sealed 154-candidate declaration and therefore remain
  pending for the governed measurement/evaluation path.
* Q13/PARAM_OPT may finish as ``NO_PARAMETER_CHANGE`` only for the explicit
  ``NO_NEW_PARAMETER_SWEEP`` / zero-trial contract.
* Q14/HEAD_TO_HEAD may finish as ``KEEP_INCUMBENT`` only when both upstream
  stages are authenticated no-change outcomes, so no challenger exists.

Any changed-strategy, measured-selection, malformed, held, or hash-drifted row
is left pending and reported fail-closed for its governed evaluator.  Existing
terminal verdicts are never touched.  Every applied transition binds a durable
JSON receipt before the pending row is completed with a compare-and-set update.
"""
from __future__ import annotations

import datetime as dt
import gzip
import hashlib
import json
import os
import sqlite3
import subprocess
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from gate_manifest import GateManifest
    from optimization_fork_driver import (
        HARNESS_GREEN_VERDICTS,
        PARAM_SUCCESS_VERDICTS,
        PATTERN_SUCCESS_VERDICTS,
        SCHEMA as ROUTING_SCHEMA,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.gate_manifest import GateManifest
    from tools.strategy_farm.optimization_fork_driver import (
        HARNESS_GREEN_VERDICTS,
        PARAM_SUCCESS_VERDICTS,
        PATTERN_SUCCESS_VERDICTS,
        SCHEMA as ROUTING_SCHEMA,
    )


SERVICE_SCHEMA = "qm.optimization-fork-no-change-service/v1"
RECEIPT_SCHEMA = "qm.optimization-fork-no-change-receipt/v1"
SERVICE_ID = "optimization_fork_no_change_service"
DEFAULT_EVIDENCE_ROOT = Path(r"D:\QM\reports\optimization_fork")

_PATTERN_SEARCH_KEYS = frozenset(
    {
        "filter_candidates",
        "opt_census",
        "pattern_filter_candidates",
        "pattern_filter_selection",
        "pattern_filter_sweep",
        "selected_pattern_filters",
    }
)


class OptimizationForkServiceError(RuntimeError):
    """A row cannot be safely completed by the no-change executor."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _contract_version(manifest: GateManifest) -> str:
    tail = str(manifest.schema_version).rsplit("/", 1)[-1]
    if not tail.startswith("v") or not tail[1:].isdigit():
        raise OptimizationForkServiceError(
            f"unsupported gate manifest schema version: {manifest.schema_version}"
        )
    return tail


def _payload(row: sqlite3.Row | Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (TypeError, json.JSONDecodeError) as exc:
        raise OptimizationForkServiceError(
            f"work item {row['id']} has invalid payload JSON"
        ) from exc
    if not isinstance(value, dict):
        raise OptimizationForkServiceError(
            f"work item {row['id']} payload is not an object"
        )
    return value


def _path_binding(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise OptimizationForkServiceError(f"bound file missing: {resolved}")
    return {
        "path": str(resolved),
        "sha256": _sha256_file(resolved),
        "size_bytes": resolved.stat().st_size,
    }


def _gzip_sibling_binding(
    path: Path, *, expected_hash: str, expected_size: int
) -> dict[str, Any] | None:
    archive = Path(str(path) + ".gz")
    if not archive.is_file():
        return None
    digest = hashlib.sha256()
    content_size = 0
    try:
        with gzip.open(archive, "rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
                content_size += len(chunk)
    except OSError as exc:
        raise OptimizationForkServiceError(f"gzip evidence archive is invalid: {archive}") from exc
    if digest.hexdigest() != expected_hash or content_size != expected_size:
        return None
    return {
        "path": str(path),
        "sha256": expected_hash,
        "size_bytes": expected_size,
        "archive_type": "gzip_sibling",
        "archive_path": str(archive.resolve()),
        "archive_sha256": _sha256_file(archive),
        "archive_size_bytes": archive.stat().st_size,
    }


def _git_history_binding(
    path: Path,
    *,
    expected_hash: str,
    expected_size: int,
    repo_root: Path | None,
) -> dict[str, Any] | None:
    if repo_root is None:
        return None
    try:
        relative = path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return None
    try:
        commits = subprocess.check_output(
            ["git", "-C", str(repo_root), "log", "--all", "--format=%H", "--", relative],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=30,
        ).split()
    except (OSError, subprocess.SubprocessError):
        return None
    for commit in commits:
        try:
            raw = subprocess.check_output(
                ["git", "-C", str(repo_root), "show", f"{commit}:{relative}"],
                stderr=subprocess.DEVNULL,
                timeout=30,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        variants = [("git_blob", raw)]
        lf = raw.replace(b"\r\n", b"\n")
        variants.append(("lf_checkout", lf))
        variants.append(("crlf_checkout", lf.replace(b"\n", b"\r\n")))
        for variant, content in variants:
            if len(content) != expected_size or _sha256_bytes(content) != expected_hash:
                continue
            try:
                blob = subprocess.check_output(
                    ["git", "-C", str(repo_root), "rev-parse", f"{commit}:{relative}"],
                    text=True,
                    stderr=subprocess.DEVNULL,
                    timeout=30,
                ).strip()
            except (OSError, subprocess.SubprocessError):
                blob = None
            return {
                "path": str(path),
                "sha256": expected_hash,
                "size_bytes": expected_size,
                "archive_type": "git_history",
                "archive_commit": commit,
                "archive_blob": blob,
                "archive_path": relative,
                "archive_bytes_variant": variant,
            }
    return None


def _verify_binding(
    raw: Any, label: str, *, repo_root: Path | None = None
) -> dict[str, Any]:
    if not isinstance(raw, Mapping):
        raise OptimizationForkServiceError(f"{label} binding missing")
    path = Path(str(raw.get("path") or "")).resolve()
    expected_hash = str(raw.get("sha256") or "").lower()
    expected_size = int(raw.get("size_bytes"))
    if path.is_file():
        observed = _path_binding(path)
        if (
            observed["sha256"] == expected_hash
            and int(observed["size_bytes"]) == expected_size
        ):
            return observed
        current_detail = (
            f"current_sha256={observed['sha256']},current_size={observed['size_bytes']}"
        )
    else:
        current_detail = "current_path_missing"
    archived = _gzip_sibling_binding(
        path, expected_hash=expected_hash, expected_size=expected_size
    ) or _git_history_binding(
        path,
        expected_hash=expected_hash,
        expected_size=expected_size,
        repo_root=repo_root,
    )
    if archived is not None:
        return archived
    raise OptimizationForkServiceError(
        f"{label} binding unavailable: expected_sha256={expected_hash},"
        f"expected_size={expected_size},{current_detail}"
    )


def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone() is not None


def _active_holds(conn: sqlite3.Connection, work_item_id: str) -> list[dict[str, Any]]:
    if not _table_exists(conn, "work_item_holds"):
        return []
    return [
        dict(row)
        for row in conn.execute(
            "SELECT hold_code,reason,created_at,updated_at FROM work_item_holds "
            "WHERE work_item_id=? AND active=1 ORDER BY hold_code",
            (work_item_id,),
        ).fetchall()
    ]


def _verify_routing_identity(payload: Mapping[str, Any]) -> str:
    expected = str(payload.get("routing_identity_sha256") or "").lower()
    identity_payload = dict(payload)
    identity_payload.pop("routing_identity_sha256", None)
    observed = _sha256_bytes(_canonical_bytes(identity_payload))
    if expected != observed:
        raise OptimizationForkServiceError(
            f"routing identity mismatch: expected {expected}, observed {observed}"
        )
    return observed


def _verify_parent(
    conn: sqlite3.Connection,
    *,
    row: sqlite3.Row,
    payload: Mapping[str, Any],
    repo_root: Path,
) -> tuple[sqlite3.Row, dict[str, dict[str, Any]]]:
    parent_id = str(payload.get("parent_work_item_id") or "")
    parent = conn.execute("SELECT * FROM work_items WHERE id=?", (parent_id,)).fetchone()
    if parent is None:
        raise OptimizationForkServiceError(f"parent work item missing: {parent_id}")
    if str(parent["status"]).lower() != "done":
        raise OptimizationForkServiceError(f"parent is not done: {parent_id}")
    if str(parent["phase"]).upper() != str(payload.get("parent_phase") or "").upper():
        raise OptimizationForkServiceError(f"parent phase drift: {parent_id}")
    if str(parent["verdict"] or "").upper() != str(payload.get("parent_verdict") or "").upper():
        raise OptimizationForkServiceError(f"parent verdict drift: {parent_id}")
    if str(parent["ea_id"]).upper() != str(row["ea_id"]).upper():
        raise OptimizationForkServiceError(f"parent EA mismatch: {parent_id}")
    if str(parent["symbol"]).upper() != str(row["symbol"]).upper():
        raise OptimizationForkServiceError(f"parent symbol mismatch: {parent_id}")

    raw_bindings = payload.get("parent_bindings")
    if not isinstance(raw_bindings, Mapping):
        raise OptimizationForkServiceError("parent_bindings missing")
    bindings = {
        label: _verify_binding(
            raw_bindings.get(label), f"parent {label}", repo_root=repo_root
        )
        for label in ("evidence", "setfile", "source", "binary")
    }
    if Path(str(parent["evidence_path"] or "")).resolve() != Path(
        bindings["evidence"]["path"]
    ).resolve():
        raise OptimizationForkServiceError("parent evidence path drift")
    if Path(str(parent["setfile_path"] or "")).resolve() != Path(
        bindings["setfile"]["path"]
    ).resolve():
        raise OptimizationForkServiceError("parent setfile path drift")
    expected_hashes = {
        "binary": "expected_ex5_sha256",
        "source": "expected_mq5_sha256",
        "setfile": "expected_setfile_sha256",
    }
    for label, field in expected_hashes.items():
        if str(payload.get(field) or "").lower() != bindings[label]["sha256"]:
            raise OptimizationForkServiceError(f"{field} does not match parent binding")
    return parent, bindings


def _verify_harness(
    conn: sqlite3.Connection, payload: Mapping[str, Any], *, repo_root: Path
) -> dict[str, Any]:
    harness = payload.get("fixture_harness")
    if not isinstance(harness, Mapping) or harness.get("green") is not True:
        raise OptimizationForkServiceError("fixture harness is not green")
    selected_id = str(harness.get("selected_work_item_id") or "")
    selected = conn.execute("SELECT * FROM work_items WHERE id=?", (selected_id,)).fetchone()
    if selected is None:
        raise OptimizationForkServiceError(f"fixture harness row missing: {selected_id}")
    if (
        str(selected["status"]).lower() != "done"
        or str(selected["verdict"] or "").upper() not in HARNESS_GREEN_VERDICTS
    ):
        raise OptimizationForkServiceError(f"fixture harness row is not green: {selected_id}")
    binding = _verify_binding(
        harness.get("evidence"), "fixture harness evidence", repo_root=repo_root
    )
    if Path(str(selected["evidence_path"] or "")).resolve() != Path(binding["path"]).resolve():
        raise OptimizationForkServiceError("fixture harness evidence path drift")
    return {
        "work_item_id": selected_id,
        "status": selected["status"],
        "verdict": selected["verdict"],
        "evidence": binding,
    }


def _nonempty_search_keys(payload: Mapping[str, Any]) -> list[str]:
    return sorted(key for key in _PATTERN_SEARCH_KEYS if payload.get(key) not in (None, {}, []))


def _pattern_ancestor(
    conn: sqlite3.Connection, param_parent: sqlite3.Row
) -> sqlite3.Row:
    param_payload = _payload(param_parent)
    pattern_id = str(param_payload.get("parent_work_item_id") or "")
    pattern = conn.execute("SELECT * FROM work_items WHERE id=?", (pattern_id,)).fetchone()
    if pattern is None:
        raise OptimizationForkServiceError(f"pattern ancestor missing: {pattern_id}")
    return pattern


def _decision(
    conn: sqlite3.Connection,
    *,
    row: sqlite3.Row,
    payload: Mapping[str, Any],
    manifest: GateManifest,
    repo_root: Path,
) -> tuple[str, str, dict[str, Any]]:
    role = str(payload.get("role") or "").upper()
    phase_by_role = {
        "PATTERN": manifest.gate_for_role("PATTERN"),
        "PARAM_OPT": manifest.gate_for_role("PARAM_OPT"),
        "HEAD_TO_HEAD": manifest.gate_for_role("HEAD_TO_HEAD"),
    }
    if role not in phase_by_role:
        raise OptimizationForkServiceError(f"unsupported optimization role: {role}")
    if str(row["phase"]).upper() != phase_by_role[role]:
        raise OptimizationForkServiceError(f"role/phase mismatch: {role}/{row['phase']}")
    parent, bindings = _verify_parent(
        conn, row=row, payload=payload, repo_root=repo_root
    )
    extras: dict[str, Any] = {"parent_bindings": bindings}

    if role == "PATTERN":
        if str(parent["verdict"] or "").upper() != "PASS":
            raise OptimizationForkServiceError("PATTERN parent is not incumbent PASS")
        dl089 = payload.get("dl089_contract")
        if not isinstance(dl089, Mapping) or dl089.get("zero_pattern_filter_valid") is not True:
            raise OptimizationForkServiceError("zero-filter pass-through is not authorized")
        declared = _nonempty_search_keys(payload)
        if declared:
            raise OptimizationForkServiceError(
                "declared pattern work requires governed selection: " + ",".join(declared)
            )
        extras["fixture_harness"] = _verify_harness(
            conn, payload, repo_root=repo_root
        )
        return "NO_FILTER_CHANGE", "NO_DECLARED_PATTERN_SEARCH_ZERO_FILTER_VALID", extras

    if role == "PARAM_OPT":
        if str(parent["verdict"] or "").upper() not in PATTERN_SUCCESS_VERDICTS:
            raise OptimizationForkServiceError("PARAM_OPT parent verdict is not routable")
        sweep = payload.get("numeric_parameter_sweep")
        if not isinstance(sweep, Mapping):
            raise OptimizationForkServiceError("numeric_parameter_sweep missing")
        if (
            str(sweep.get("mode") or "") != "NO_NEW_PARAMETER_SWEEP"
            or int(sweep.get("declared_parameter_count", -1)) != 0
            or int(sweep.get("declared_trial_count_increment", -1)) != 0
            or sweep.get("no_parameter_change_valid") is not True
        ):
            raise OptimizationForkServiceError(
                "declared parameter work requires governed development runner"
            )
        return "NO_PARAMETER_CHANGE", "EXPLICIT_ZERO_TRIAL_PARAMETER_CONTRACT", extras

    if str(parent["verdict"] or "").upper() not in PARAM_SUCCESS_VERDICTS:
        raise OptimizationForkServiceError("HEAD_TO_HEAD parent verdict is not routable")
    if str(parent["verdict"] or "").upper() != "NO_PARAMETER_CHANGE":
        raise OptimizationForkServiceError("changed parameter chain requires sealed evaluator")
    pattern = _pattern_ancestor(conn, parent)
    if str(pattern["status"]).lower() != "done" or str(pattern["verdict"] or "").upper() not in {
        "NO_FILTER_CHANGE",
        "KEEP_INCUMBENT",
    }:
        raise OptimizationForkServiceError("changed pattern chain requires sealed evaluator")
    extras["pattern_ancestor"] = {
        "work_item_id": pattern["id"],
        "verdict": pattern["verdict"],
        "evidence_path": pattern["evidence_path"],
    }
    return "KEEP_INCUMBENT", "NO_CHALLENGER_BOTH_UPSTREAM_STAGES_NO_CHANGE", extras


def _contract_bindings(repo_root: Path, payload: Mapping[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    dl089 = payload.get("dl089_contract")
    if isinstance(dl089, Mapping):
        for label in ("decision", "plan"):
            rel = str(dl089.get(label) or "")
            if rel:
                result[label] = _path_binding(repo_root / rel)
    return result


def _plan_row(
    conn: sqlite3.Connection,
    *,
    row: sqlite3.Row,
    manifest: GateManifest,
    repo_root: Path,
    evidence_root: Path,
) -> dict[str, Any]:
    holds = _active_holds(conn, str(row["id"]))
    if holds:
        raise OptimizationForkServiceError(
            "active work-item hold(s): " + ",".join(str(h["hold_code"]) for h in holds)
        )
    payload = _payload(row)
    if payload.get("schema") != ROUTING_SCHEMA:
        raise OptimizationForkServiceError("not an optimization-fork routing row")
    if payload.get("execution_lane") != "GOVERNED_ANALYTIC_DISPATCH":
        raise OptimizationForkServiceError("row is not assigned to governed analytic dispatch")
    if payload.get("activation_state") != "READY":
        raise OptimizationForkServiceError(
            f"activation_state is {payload.get('activation_state')!r}, not READY"
        )
    version = _contract_version(manifest)
    if str(row["gate_contract_version"] or "") != version:
        raise OptimizationForkServiceError("row gate contract version is not active")
    if str(payload.get("gate_contract_version") or "") != version:
        raise OptimizationForkServiceError("payload gate contract version is not active")
    if str(payload.get("gate_manifest_sha256") or "").lower() != manifest.sha256:
        raise OptimizationForkServiceError("payload is not bound to active gate manifest")
    if str(payload.get("phase") or "").upper() != str(row["phase"]).upper():
        raise OptimizationForkServiceError("payload phase does not match row phase")
    if str(payload.get("expected_symbol") or "").upper() != str(row["symbol"]).upper():
        raise OptimizationForkServiceError("payload symbol does not match row symbol")
    routing_identity = _verify_routing_identity(payload)
    verdict, reason_code, extras = _decision(
        conn,
        row=row,
        payload=payload,
        manifest=manifest,
        repo_root=repo_root,
    )
    evidence_path = (evidence_root / str(row["id"]) / "receipt.json").resolve()
    return {
        "work_item_id": row["id"],
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "phase": row["phase"],
        "role": payload["role"],
        "verdict": verdict,
        "reason_code": reason_code,
        "evidence_path": str(evidence_path),
        "routing_identity_sha256": routing_identity,
        "input_payload_sha256": _sha256_bytes(str(row["payload_json"]).encode("utf-8")),
        "gate_manifest_sha256": manifest.sha256,
        "gate_contract_version": version,
        "contract_bindings": _contract_bindings(repo_root, payload),
        **extras,
    }


def _write_receipt(path: Path, receipt: Mapping[str, Any]) -> str:
    encoded = json.dumps(receipt, indent=2, sort_keys=True).encode("utf-8") + b"\n"
    if path.exists():
        try:
            existing = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            raise OptimizationForkServiceError(f"existing receipt is invalid: {path}") from exc
        immutable = ("schema", "work_item_id", "verdict", "input_payload_sha256")
        if any(existing.get(key) != receipt.get(key) for key in immutable):
            raise OptimizationForkServiceError(f"existing receipt conflicts: {path}")
        return _sha256_file(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_bytes(encoded)
    temp.replace(path)
    return _sha256_bytes(encoded)


def service_pending(
    conn: sqlite3.Connection,
    *,
    manifest: GateManifest,
    repo_root: Path,
    evidence_root: Path = DEFAULT_EVIDENCE_ROOT,
    apply: bool = False,
    limit: int = 3,
    work_item_ids: Iterable[str] | None = None,
) -> dict[str, Any]:
    """Plan or apply bounded no-change analytic transitions."""

    if limit < 1:
        raise ValueError("limit must be at least 1")
    conn.row_factory = sqlite3.Row
    phases = tuple(
        manifest.gate_for_role(role) for role in ("PATTERN", "PARAM_OPT", "HEAD_TO_HEAD")
    )
    targets = None if work_item_ids is None else {str(value) for value in work_item_ids}
    rows = conn.execute(
        "SELECT * FROM work_items WHERE kind='analytic' AND lower(status)='pending' "
        "AND verdict IS NULL AND claimed_by IS NULL AND upper(phase) IN (?,?,?) "
        "ORDER BY created_at,id",
        phases,
    ).fetchall()
    planned: list[dict[str, Any]] = []
    deferred: list[dict[str, Any]] = []
    for row in rows:
        if targets is not None and str(row["id"]) not in targets:
            continue
        try:
            plan = _plan_row(
                conn,
                row=row,
                manifest=manifest,
                repo_root=repo_root.resolve(),
                evidence_root=evidence_root.resolve(),
            )
        except (OptimizationForkServiceError, OSError, ValueError) as exc:
            deferred.append(
                {
                    "work_item_id": row["id"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "phase": row["phase"],
                    "machine_reason": f"GOVERNED_EVALUATOR_REQUIRED:{exc}",
                }
            )
            continue
        planned.append(plan)
        if len(planned) >= limit:
            break

    completed: list[dict[str, Any]] = []
    if apply:
        for plan in planned:
            completed_at = _utc_now()
            receipt = {
                "schema": RECEIPT_SCHEMA,
                "service": SERVICE_ID,
                "completed_at_utc": completed_at,
                "selection_contract_changed": False,
                "measured_candidate_adjudicated": False,
                **plan,
            }
            evidence_path = Path(plan["evidence_path"])
            receipt_sha256 = _write_receipt(evidence_path, receipt)
            try:
                conn.execute("BEGIN IMMEDIATE")
                cursor = conn.execute(
                    "UPDATE work_items SET status='done',verdict=?,evidence_path=?,"
                    "claimed_by=NULL,updated_at=? WHERE id=? AND status='pending' "
                    "AND verdict IS NULL AND claimed_by IS NULL",
                    (
                        plan["verdict"],
                        str(evidence_path),
                        completed_at,
                        plan["work_item_id"],
                    ),
                )
                if cursor.rowcount != 1:
                    conn.rollback()
                    deferred.append(
                        {
                            "work_item_id": plan["work_item_id"],
                            "machine_reason": "COMPARE_AND_SET_LOST",
                        }
                    )
                    continue
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            completed.append({**plan, "receipt_sha256": receipt_sha256})

    return {
        "schema": SERVICE_SCHEMA,
        "dry_run": not apply,
        "applied": apply,
        "gate_contract_version": _contract_version(manifest),
        "gate_manifest_sha256": manifest.sha256,
        "limit": limit,
        "planned": planned,
        "completed": completed,
        "deferred": deferred,
    }
