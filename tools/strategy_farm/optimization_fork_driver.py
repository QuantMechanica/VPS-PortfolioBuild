"""Append-only automation for the mandatory optimization/requalification fork.

The driver owns *routing*, not gate adjudication.  It creates one immutable,
hash-bound work item for the next manifest role and waits for the governed
runner for that role to publish a terminal row/evidence.  Re-running the driver
is idempotent.  It never launches MT5 and never updates an existing verdict.

Runtime role mapping is resolved from the supplied gate manifest:

* v3: Q10 -> Q14 -> Q15 -> Q16
* v4: Q11 -> Q12 -> Q13 -> Q14

The DL-089 pattern gate is fail-closed on the fixture harness.  The historical
83b89730 row is the commissioning root; a later HARNESS_OK rerun of the same
harness identity may satisfy the prerequisite, while the failed root remains
preserved as evidence.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sqlite3
import uuid
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from gate_manifest import GateManifest
    from phase_ids import ACTIVE_GATE_MANIFEST
    from throughput_telemetry import EXECUTION_VERDICT_EXCLUSION_SQL
except ModuleNotFoundError:
    from tools.strategy_farm.gate_manifest import GateManifest
    from tools.strategy_farm.phase_ids import ACTIVE_GATE_MANIFEST
    from tools.strategy_farm.throughput_telemetry import EXECUTION_VERDICT_EXCLUSION_SQL


SCHEMA = "qm.opt-fork-routing/v1"
HARNESS_ROOT_WORK_ITEM_ID = "83b89730-bb86-4c18-955a-efefe3039cc5"
HARNESS_EA_ID = "QM_PP_FIXTURE_HARNESS"
HARNESS_PHASE = "HARNESS_PP_FIXTURE"
HARNESS_GREEN_VERDICTS = frozenset({"HARNESS_OK", "PASS"})
PATTERN_SUCCESS_VERDICTS = frozenset(
    {"PASS", "PASS_SOFT", "KEEP_INCUMBENT", "OPT_ELIGIBLE", "NO_FILTER_CHANGE"}
)
PARAM_SUCCESS_VERDICTS = frozenset(
    {"PASS", "PASS_SOFT", "KEEP_INCUMBENT", "CHALLENGER_SPAWNED", "NO_PARAMETER_CHANGE"}
)
TERMINAL_REQUALIFICATION_VERDICTS = frozenset(
    {"PROMOTE_CHALLENGER", "CHALLENGER_PROMOTED", "KEEP_INCUMBENT", "ADMIT_BOTH"}
)
ROW_NAMESPACE = uuid.UUID("ee66f777-f906-4d5e-a302-a46e44af5b7a")


class OptimizationForkError(RuntimeError):
    """A fail-closed routing or binding error."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _binding(path_value: Any, label: str) -> dict[str, Any]:
    path = Path(str(path_value or "")).resolve()
    if not path.is_file():
        raise OptimizationForkError(f"{label} missing: {path}")
    return {"path": str(path), "sha256": _sha256(path), "size_bytes": path.stat().st_size}


def _contract_version(manifest: GateManifest) -> str:
    match = re.search(r"/v(\d+)$", manifest.schema_version)
    if not match:
        raise OptimizationForkError(
            f"unsupported gate manifest schema version: {manifest.schema_version}"
        )
    return f"v{match.group(1)}"


def _decode_payload(row: sqlite3.Row | Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (json.JSONDecodeError, TypeError) as exc:
        raise OptimizationForkError(f"work item {row['id']} has invalid payload JSON") from exc
    return value if isinstance(value, dict) else {}


def _artifact_bindings(row: sqlite3.Row | Mapping[str, Any]) -> dict[str, Any]:
    """Bind the row evidence plus current source/binary/setfile bytes."""

    evidence = _binding(row["evidence_path"], "parent evidence")
    setfile = _binding(row["setfile_path"], "parent setfile")
    payload = _decode_payload(row)
    set_path = Path(setfile["path"])
    ea_dir = set_path.parent.parent
    ea_dir_name = str(payload.get("ea_dir_name") or ea_dir.name).strip()
    ex5_path = Path(str(payload.get("expected_ex5_path") or ea_dir / f"{ea_dir_name}.ex5"))
    mq5_path = Path(str(payload.get("expected_mq5_path") or ea_dir / f"{ea_dir_name}.mq5"))
    binary = _binding(ex5_path, "parent binary")
    source = _binding(mq5_path, "parent source")
    for key, observed in (
        ("expected_ex5_sha256", binary["sha256"]),
        ("expected_mq5_sha256", source["sha256"]),
        ("expected_setfile_sha256", setfile["sha256"]),
    ):
        expected = str(payload.get(key) or "").strip().lower()
        if expected and expected != observed:
            raise OptimizationForkError(
                f"parent {key} mismatch for {row['id']}: expected {expected}, observed {observed}"
            )
    return {"evidence": evidence, "binary": binary, "source": source, "setfile": setfile}


def _harness_state(conn: sqlite3.Connection) -> dict[str, Any]:
    root = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (HARNESS_ROOT_WORK_ITEM_ID,)
    ).fetchone()
    green = conn.execute(
        """
        SELECT * FROM work_items
        WHERE ea_id=? AND phase=? AND lower(status)='done'
          AND upper(coalesce(verdict,'')) IN ('HARNESS_OK','PASS')
        ORDER BY updated_at DESC,created_at DESC,id DESC LIMIT 1
        """,
        (HARNESS_EA_ID, HARNESS_PHASE),
    ).fetchone()
    state: dict[str, Any] = {
        "root_work_item_id": HARNESS_ROOT_WORK_ITEM_ID,
        "root_present": root is not None,
        "root_status": None if root is None else root["status"],
        "root_verdict": None if root is None else root["verdict"],
        "green": green is not None,
        "selected_work_item_id": None if green is None else green["id"],
        "machine_reason": "FIXTURE_HARNESS_GREEN" if green is not None else (
            "FIXTURE_HARNESS_ROOT_MISSING" if root is None else "FIXTURE_HARNESS_NOT_GREEN"
        ),
    }
    if green is not None:
        state["evidence"] = _binding(green["evidence_path"], "fixture harness evidence")
        state["selected_status"] = green["status"]
        state["selected_verdict"] = green["verdict"]
    return state


def _row_id(*, manifest: GateManifest, role: str, parent_id: str, prerequisite_id: str) -> str:
    seed = f"{SCHEMA}:{manifest.sha256}:{role}:{parent_id}:{prerequisite_id}"
    return str(uuid.uuid5(ROW_NAMESPACE, seed))


def _target_set(target_pairs: Iterable[tuple[str, str]] | None) -> set[tuple[str, str]] | None:
    if target_pairs is None:
        return None
    return {(str(ea).strip().upper(), str(symbol).strip().upper()) for ea, symbol in target_pairs}


def _latest_incumbents(
    conn: sqlite3.Connection,
    *,
    manifest: GateManifest,
    target_pairs: Iterable[tuple[str, str]] | None,
) -> list[sqlite3.Row]:
    phase = manifest.gate_for_role("INCUMBENT")
    targets = _target_set(target_pairs)
    rows = conn.execute(
        """
        SELECT * FROM work_items
        WHERE upper(phase)=? AND lower(status)='done' AND upper(coalesce(verdict,''))='PASS'
        ORDER BY updated_at DESC,created_at DESC,id DESC
        """,
        (phase,),
    ).fetchall()
    latest: dict[tuple[str, str], sqlite3.Row] = {}
    for row in rows:
        key = (str(row["ea_id"]).upper(), str(row["symbol"]).upper())
        if targets is not None and key not in targets:
            continue
        latest.setdefault(key, row)
    return list(latest.values())


def _managed_terminal_rows(
    conn: sqlite3.Connection, *, phase: str, manifest: GateManifest
) -> list[sqlite3.Row]:
    rows = conn.execute(
        """
        SELECT * FROM work_items
        WHERE upper(phase)=? AND lower(status) IN ('done','failed')
          AND json_valid(payload_json)=1
          AND json_extract(payload_json,'$.schema')=?
          AND json_extract(payload_json,'$.gate_manifest_sha256')=?
        ORDER BY updated_at,created_at,id
        """,
        (phase, SCHEMA, manifest.sha256),
    ).fetchall()
    return list(rows)


def _stage_payload(
    *,
    manifest: GateManifest,
    role: str,
    phase: str,
    parent: sqlite3.Row,
    parent_bindings: Mapping[str, Any],
    harness: Mapping[str, Any],
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema": SCHEMA,
        "role": role,
        "phase": phase,
        "gate_contract_version": _contract_version(manifest),
        "gate_manifest_sha256": manifest.sha256,
        "parent_work_item_id": str(parent["id"]),
        "parent_phase": str(parent["phase"]),
        "parent_verdict": str(parent["verdict"]),
        "parent_bindings": dict(parent_bindings),
        "expected_ex5_sha256": parent_bindings["binary"]["sha256"],
        "expected_mq5_sha256": parent_bindings["source"]["sha256"],
        "expected_setfile_sha256": parent_bindings["setfile"]["sha256"],
        "expected_symbol": str(parent["symbol"]),
        "dl089_contract": {
            "decision": "decisions/DL-089_pattern_filter_wf_census_v3.md",
            "plan": "docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md",
            "zero_pattern_filter_valid": True,
            "frequency_check": "DL-089_ACTIVITY_FLOOR_FAIL_CLOSED",
        },
        "numeric_parameter_sweep": {
            "mode": "NO_NEW_PARAMETER_SWEEP",
            "declared_parameter_count": 0,
            "declared_trial_count_increment": 0,
            "no_parameter_change_valid": True,
        },
        "execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
        "activation_state": "READY",
        "machine_reason": "PREREQUISITES_GREEN",
    }
    if role == "PATTERN":
        payload["fixture_harness"] = dict(harness)
        if not harness["green"]:
            payload["activation_state"] = "FAIL_CLOSED"
            payload["machine_reason"] = harness["machine_reason"]
    return payload


def _append_stage(
    conn: sqlite3.Connection,
    *,
    manifest: GateManifest,
    role: str,
    phase: str,
    parent: sqlite3.Row,
    harness: Mapping[str, Any],
    apply: bool,
) -> dict[str, Any]:
    try:
        bindings = _artifact_bindings(parent)
    except OptimizationForkError as exc:
        return {
            "created": False,
            "role": role,
            "phase": phase,
            "parent_work_item_id": str(parent["id"]),
            "ea_id": str(parent["ea_id"]),
            "symbol": str(parent["symbol"]),
            "machine_reason": f"PARENT_BINDING_INVALID:{exc}",
        }
    prerequisite_id = (
        str(harness.get("selected_work_item_id") or harness["machine_reason"])
        if role == "PATTERN"
        else str(parent["id"])
    )
    work_item_id = _row_id(
        manifest=manifest, role=role, parent_id=str(parent["id"]), prerequisite_id=prerequisite_id
    )
    payload = _stage_payload(
        manifest=manifest, role=role, phase=phase, parent=parent,
        parent_bindings=bindings, harness=harness,
    )
    payload["routing_identity_sha256"] = hashlib.sha256(_canonical_bytes(payload)).hexdigest()
    terminal_fail = role == "PATTERN" and not bool(harness["green"])
    status = "failed" if terminal_fail else "pending"
    verdict = "INFRA_FAIL" if terminal_fail else None
    existing = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
    if existing is not None:
        if (
            str(existing["payload_json"]) != json.dumps(payload, sort_keys=True)
            or str(existing["phase"]).upper() != phase
        ):
            raise OptimizationForkError(
                f"deterministic optimization work-item collision: {work_item_id}"
            )
        return {
            "created": False, "idempotent": True, "work_item_id": work_item_id,
            "role": role, "phase": phase, "ea_id": parent["ea_id"],
            "symbol": parent["symbol"], "status": existing["status"],
            "verdict": existing["verdict"],
            "machine_reason": payload["machine_reason"],
        }
    result = {
        "created": bool(apply), "idempotent": False, "work_item_id": work_item_id,
        "role": role, "phase": phase, "ea_id": parent["ea_id"],
        "symbol": parent["symbol"], "status": status, "verdict": verdict,
        "machine_reason": payload["machine_reason"],
    }
    if not apply:
        result["would_create"] = True
        return result
    now = _utc_now()
    conn.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
            parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
            gate_contract_version
        ) VALUES(?,?,?,?,?,?,?,?,0,NULL,NULL,NULL,?,?,?,?)
        """,
        (
            work_item_id, "analytic", phase, parent["ea_id"], parent["symbol"],
            parent["setfile_path"], status, verdict, json.dumps(payload, sort_keys=True),
            now, now, _contract_version(manifest),
        ),
    )
    return result


def advance_optimization_fork(
    conn: sqlite3.Connection,
    *,
    manifest: GateManifest = ACTIVE_GATE_MANIFEST,
    target_pairs: Iterable[tuple[str, str]] | None = None,
    apply: bool = False,
) -> dict[str, Any]:
    """Plan or append every currently licensed optimization-fork successor."""

    conn.row_factory = sqlite3.Row
    pattern_phase = manifest.gate_for_role("PATTERN")
    param_phase = manifest.gate_for_role("PARAM_OPT")
    head_phase = manifest.gate_for_role("HEAD_TO_HEAD")
    harness = _harness_state(conn)
    actions: list[dict[str, Any]] = []

    if apply:
        conn.execute("BEGIN IMMEDIATE")
    try:
        for parent in _latest_incumbents(conn, manifest=manifest, target_pairs=target_pairs):
            actions.append(_append_stage(
                conn, manifest=manifest, role="PATTERN", phase=pattern_phase,
                parent=parent, harness=harness, apply=apply,
            ))

        targets = _target_set(target_pairs)
        for parent in _managed_terminal_rows(conn, phase=pattern_phase, manifest=manifest):
            key = (str(parent["ea_id"]).upper(), str(parent["symbol"]).upper())
            if targets is not None and key not in targets:
                continue
            if str(parent["verdict"] or "").upper() not in PATTERN_SUCCESS_VERDICTS:
                continue
            actions.append(_append_stage(
                conn, manifest=manifest, role="PARAM_OPT", phase=param_phase,
                parent=parent, harness=harness, apply=apply,
            ))

        for parent in _managed_terminal_rows(conn, phase=param_phase, manifest=manifest):
            key = (str(parent["ea_id"]).upper(), str(parent["symbol"]).upper())
            if targets is not None and key not in targets:
                continue
            if str(parent["verdict"] or "").upper() not in PARAM_SUCCESS_VERDICTS:
                continue
            actions.append(_append_stage(
                conn, manifest=manifest, role="HEAD_TO_HEAD", phase=head_phase,
                parent=parent, harness=harness, apply=apply,
            ))
        if apply:
            conn.commit()
    except Exception:
        if apply:
            conn.rollback()
        raise
    return {
        "schema": SCHEMA,
        "dry_run": not apply,
        "applied": apply,
        "gate_contract_version": _contract_version(manifest),
        "gate_manifest_sha256": manifest.sha256,
        "phases": {
            "incumbent": manifest.gate_for_role("INCUMBENT"),
            "pattern": pattern_phase,
            "param_opt": param_phase,
            "head_to_head": head_phase,
        },
        "fixture_harness": harness,
        "actions": actions,
        "created_work_item_ids": [row["work_item_id"] for row in actions if row.get("created")],
    }


def service_metrics(
    conn: sqlite3.Connection,
    *,
    manifests: Iterable[GateManifest],
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Return 24h completed rates and lifetime terminal requalification count."""

    observed = now or dt.datetime.now(dt.timezone.utc)
    cutoff = (observed - dt.timedelta(days=1)).isoformat()
    per_gate: dict[str, int] = {}
    terminal_clauses: list[tuple[str, str]] = []
    for manifest in manifests:
        version = _contract_version(manifest)
        for role in ("PATTERN", "PARAM_OPT", "HEAD_TO_HEAD"):
            phase = manifest.gate_for_role(role)
            key = f"{version}:{phase}:{role}"
            accepted_versions = (version, "legacy") if version == "v3" else (version,)
            version_placeholders = ",".join("?" for _ in accepted_versions)
            per_gate[key] = int(conn.execute(
                f"""
                SELECT count(*) FROM work_items
                WHERE upper(phase)=? AND lower(status) IN ('done','failed')
                  AND coalesce(gate_contract_version,?) IN ({version_placeholders})
                  AND updated_at>=?
                  AND {EXECUTION_VERDICT_EXCLUSION_SQL}
                """,
                (
                    phase, "legacy" if version == "v3" else version,
                    *accepted_versions, cutoff,
                ),
            ).fetchone()[0])
        terminal_clauses.append((manifest.terminal_requalification_gate, version))
    terminal_ids: set[str] = set()
    for phase, version in terminal_clauses:
        accepted_versions = (version, "legacy") if version == "v3" else (version,)
        version_placeholders = ",".join("?" for _ in accepted_versions)
        rows = conn.execute(
            f"""
            SELECT id FROM work_items
            WHERE upper(phase)=? AND lower(status)='done'
              AND upper(coalesce(verdict,'')) IN (?,?,?,?)
              AND coalesce(gate_contract_version,?) IN ({version_placeholders})
            """,
            (
                phase, *sorted(TERMINAL_REQUALIFICATION_VERDICTS),
                "legacy" if version == "v3" else version, *accepted_versions,
            ),
        ).fetchall()
        terminal_ids.update(str(row[0]) for row in rows)
    return {
        "window_hours": 24,
        "completed_per_day_by_gate": per_gate,
        "terminal_requalification_verdicts_count": len(terminal_ids),
    }
