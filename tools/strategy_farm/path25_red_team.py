#!/usr/bin/env python3
"""Read-only adversarial audit of the active v4 path to 25 qualified pairs.

This module is deliberately outside every dispatcher and runner.  It opens the
farm database with SQLite ``mode=ro`` plus ``query_only=ON``, emits observations
only, and never changes a verdict, queue row, hold, gate threshold, or book.

The audit distinguishes a broken safety invariant (``FAIL``) from production
evidence that simply does not exist yet (``WARN``).  In particular, fewer than
25 terminally requalified pairs is an unproven/unfinished path, not proof that
the implementation is defective.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import (  # noqa: E402
    book_build_guard,
    gate_manifest,
    path_to_25,
    phase_ids,
    v4_readiness_check,
)


SCHEMA = "qm.path25-red-team/v1"
DEFAULT_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_MANIFEST_PATH = gate_manifest.V4_MANIFEST
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_OPEN_STATUSES = frozenset({"pending", "active"})
_LATE_LINEAR_PHASES = ("Q09", "Q10_NEWS", "Q11", "Q12", "Q13", "Q14")
_MANAGED_OPT_PHASES = ("Q12", "Q13", "Q14")


@dataclasses.dataclass(frozen=True)
class Check:
    id: str
    status: str
    summary: str
    evidence: dict[str, Any]


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _check(
    check_id: str,
    status: str,
    summary: str,
    **evidence: Any,
) -> Check:
    normalized = str(status).upper()
    if normalized not in {"PASS", "WARN", "FAIL", "INFO"}:
        raise ValueError(f"unknown check status: {status!r}")
    return Check(check_id, normalized, summary, evidence)


def _open_ro(db_path: str | Path) -> sqlite3.Connection:
    path = Path(db_path).resolve().as_posix()
    connection = sqlite3.connect(
        f"file:{path}?mode=ro", uri=True, timeout=5, isolation_level=None
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout=3000")
    connection.execute("PRAGMA query_only=ON")
    return connection


def _table_exists(connection: sqlite3.Connection, table: str) -> bool:
    return connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name=?",
        (table,),
    ).fetchone() is not None


def _columns(connection: sqlite3.Connection, table: str) -> set[str]:
    if not _table_exists(connection, table):
        return set()
    return {
        str(row[1]).lower()
        for row in connection.execute(f"PRAGMA table_info({table})")
    }


def _decode_payload(value: Any) -> dict[str, Any]:
    try:
        decoded = json.loads(str(value or "{}"))
    except (TypeError, json.JSONDecodeError):
        return {}
    return decoded if isinstance(decoded, dict) else {}


def _overall(checks: Iterable[Check]) -> str:
    statuses = {row.status for row in checks}
    if "FAIL" in statuses:
        return "FAIL"
    if "WARN" in statuses:
        return "WARN"
    return "PASS"


def _as_dicts(checks: Iterable[Check]) -> list[dict[str, Any]]:
    return [dataclasses.asdict(row) for row in checks]


def _runtime_path(manifest: gate_manifest.GateManifest) -> tuple[list[str], list[str]]:
    table = phase_ids.build_advancement_table(manifest)
    storage_path = ["Q08"]
    canonical_path = ["Q08"]
    seen = {"Q08"}
    while table[storage_path[-1]].next is not None:
        successor = str(table[storage_path[-1]].next)
        if successor in seen:
            storage_path.append(successor)
            break
        seen.add(successor)
        storage_path.append(successor)
        canonical = table[successor].canonical_phase
        if canonical != canonical_path[-1]:
            canonical_path.append(canonical)
    return storage_path, canonical_path


def audit_manifest(
    manifest_path: str | Path = DEFAULT_MANIFEST_PATH,
) -> tuple[gate_manifest.GateManifest, dict[str, Any], list[Check]]:
    """Audit the active contract and runtime topology without touching SQLite."""
    path = Path(manifest_path).resolve()
    raw = json.loads(path.read_text(encoding="utf-8-sig"))
    manifest = gate_manifest.load_gate_manifest(path)
    checks: list[Check] = []

    expected_ids = tuple(f"Q{i:02d}" for i in range(18))
    active = (
        manifest.schema_version == gate_manifest.SCHEMA_VERSION_V4
        and manifest.activation_state == "ACTIVE"
        and raw.get("status") == "ACTIVE"
    )
    checks.append(_check(
        "contract.active_v4",
        "PASS" if active else "FAIL",
        "The default contract is activated v4." if active else "The audited contract is not activated v4.",
        schema_version=manifest.schema_version,
        activation_state=manifest.activation_state,
        declared_status=raw.get("status"),
        manifest_sha256=manifest.sha256,
    ))

    default_matches = path == Path(gate_manifest.DEFAULT_MANIFEST).resolve()
    checks.append(_check(
        "contract.default_pointer",
        "PASS" if default_matches else "WARN",
        (
            "The audited manifest is the runtime default."
            if default_matches
            else "A non-default manifest was audited explicitly."
        ),
        audited_path=str(path),
        default_path=str(Path(gate_manifest.DEFAULT_MANIFEST).resolve()),
    ))

    ids_ok = manifest.phase_ids == expected_ids and tuple(
        gate.ordinal for gate in manifest.gates
    ) == tuple(range(18))
    checks.append(_check(
        "contract.ordered_gate_ids",
        "PASS" if ids_ok else "FAIL",
        (
            "Gate IDs and ordinals are exactly Q00..Q17."
            if ids_ok
            else "Gate IDs or ordinals are not the strict Q00..Q17 sequence."
        ),
        observed_ids=list(manifest.phase_ids),
        observed_ordinals=[gate.ordinal for gate in manifest.gates],
    ))

    bad_edges = []
    ordinals = {gate.id: gate.ordinal for gate in manifest.gates}
    for gate in manifest.gates:
        if gate.next is None:
            continue
        if ordinals.get(gate.next) != gate.ordinal + 1:
            bad_edges.append({"from": gate.id, "to": gate.next})
    checks.append(_check(
        "contract.no_skip_or_back_edges",
        "PASS" if not bad_edges else "FAIL",
        (
            "Every declared edge points to the immediate ordinal successor."
            if not bad_edges
            else "At least one declared edge skips or points backwards."
        ),
        invalid_edges=bad_edges,
    ))

    q14 = next((gate for gate in manifest.gates if gate.id == "Q14"), None)
    q15 = next((gate for gate in manifest.gates if gate.id == "Q15"), None)
    terminal_ok = bool(
        q14
        and q14.next is None
        and manifest.terminal_requalification_gate == "Q14"
        and not any(gate.next == "Q15" for gate in manifest.gates[:15])
    )
    checks.append(_check(
        "contract.q14_is_per_ea_terminal",
        "PASS" if terminal_ok else "FAIL",
        (
            "Q14 is the sole terminal per-EA gate and has no automatic Q15 edge."
            if terminal_ok
            else "Q14/Q15 separation is not fail-closed."
        ),
        q14_next=None if q14 is None else q14.next,
        terminal_requalification_gate=manifest.terminal_requalification_gate,
    ))

    trigger = raw.get("book_trigger") or {}
    trigger_conditions = {
        str(row.get("condition"))
        for row in trigger.get("requires_all", [])
        if isinstance(row, dict)
    }
    book_ok = bool(
        q15
        and q15.authority == "OWNER"
        and trigger.get("policy") == "FAIL_CLOSED"
        and trigger.get("entry_gate") == "Q15"
        and {
            "qualified_candidates_ge_25",
            "owner_order_artifact_present",
        }.issubset(trigger_conditions)
        and book_build_guard.MIN_QUALIFIED_PAIRS == 25
    )
    checks.append(_check(
        "contract.book_trigger_authority",
        "PASS" if book_ok else "FAIL",
        (
            "Q15 requires both >=25 qualified pairs and an OWNER order."
            if book_ok
            else "The Q15 book trigger or its authority is incomplete."
        ),
        q15_authority=None if q15 is None else q15.authority,
        policy=trigger.get("policy"),
        conditions=sorted(trigger_conditions),
        code_minimum=book_build_guard.MIN_QUALIFIED_PAIRS,
    ))

    storage = raw.get("storage_strategy") or {}
    stamp_ok = (
        storage.get("policy") == "STAMP_DONT_RENAME"
        and "gate_contract_version" in str(storage.get("discriminator_column") or "")
    )
    checks.append(_check(
        "contract.versioned_storage",
        "PASS" if stamp_ok else "FAIL",
        (
            "Historical rows are contract-stamped and never silently renumbered."
            if stamp_ok
            else "The versioned-storage promise is absent or ambiguous."
        ),
        policy=storage.get("policy"),
    ))

    storage_path, canonical_path = _runtime_path(manifest)
    expected_runtime = [f"Q{i:02d}" for i in range(8, 15)]
    runtime_ok = canonical_path == expected_runtime
    checks.append(_check(
        "runtime.linear_phase2_path",
        "PASS" if runtime_ok else "FAIL",
        (
            "Runtime advances Q08 through Q14 and stops."
            if runtime_ok
            else "Runtime Phase-2 advancement diverges from Q08..Q14."
        ),
        storage_path=storage_path,
        canonical_path=canonical_path,
        expected=expected_runtime,
    ))

    source_findings = [
        finding
        for relative in v4_readiness_check.DISPATCH_MODULES
        for finding in v4_readiness_check.scan_source(
            v4_readiness_check.REPO_ROOT / relative
        )
    ]
    violations = [row for row in source_findings if not row.allowlisted]
    runtime_violations = v4_readiness_check.runtime_findings()
    source_ok = not violations and not runtime_violations
    checks.append(_check(
        "runtime.no_v3_only_dispatch",
        "PASS" if source_ok else "FAIL",
        (
            "Dispatch sources and runtime tables contain no v3-only routing decision."
            if source_ok
            else "A v3-only dispatch or runtime violation remains."
        ),
        violations=[dataclasses.asdict(row) for row in violations],
        runtime_violations=runtime_violations,
        allowlisted_compatibility_literals=sum(row.allowlisted for row in source_findings),
    ))

    draft_note = str(raw.get("draft_note") or "")
    stale_tokens = [
        token
        for token in ("PROPOSAL ONLY", "READ_INERT")
        if token in draft_note
    ]
    draft_pipeline_version = "DRAFT" in manifest.pipeline_version.upper()
    checks.append(_check(
        "documentation.activation_note",
        "WARN" if active and (stale_tokens or draft_pipeline_version) else "PASS",
        (
            "Activation metadata is internally consistent."
            if not (active and (stale_tokens or draft_pipeline_version))
            else "The active manifest still carries pre-activation draft labels."
        ),
        stale_tokens=stale_tokens,
        draft_note=draft_note,
        pipeline_version=manifest.pipeline_version,
        pipeline_version_contains_draft=draft_pipeline_version,
    ))
    return manifest, raw, checks


def _phase_counts(connection: sqlite3.Connection) -> dict[str, dict[str, int]]:
    result: dict[str, dict[str, int]] = {}
    rows = connection.execute(
        """
        SELECT upper(phase) AS phase,lower(status) AS status,count(*) AS n
        FROM work_items
        WHERE gate_contract_version='v4'
          AND upper(phase) IN ('Q09','Q10_NEWS','Q11','Q12','Q13','Q14')
        GROUP BY upper(phase),lower(status)
        ORDER BY upper(phase),lower(status)
        """
    )
    for row in rows:
        result.setdefault(str(row["phase"]), {})[str(row["status"])] = int(row["n"])
    return {phase: result.get(phase, {}) for phase in _LATE_LINEAR_PHASES}


def _binding_coverage(
    connection: sqlite3.Connection,
    manifest: gate_manifest.GateManifest,
) -> dict[str, dict[str, Any]]:
    coverage: dict[str, dict[str, Any]] = {
        phase: {"rows": 0, "complete": 0, "invalid_rows": []}
        for phase in _MANAGED_OPT_PHASES
    }
    rows = connection.execute(
        """
        SELECT id,upper(phase) AS phase,payload_json
        FROM work_items
        WHERE gate_contract_version='v4'
          AND upper(phase) IN ('Q12','Q13','Q14')
        ORDER BY id
        """
    )
    for row in rows:
        phase = str(row["phase"])
        record = coverage[phase]
        record["rows"] += 1
        payload = _decode_payload(row["payload_json"])
        reasons: list[str] = []
        if payload.get("schema") != "qm.opt-fork-routing/v1":
            reasons.append("routing_schema_mismatch")
        if payload.get("gate_contract_version") != "v4":
            reasons.append("payload_contract_version_mismatch")
        if str(payload.get("phase") or "").upper() != phase:
            reasons.append("payload_phase_mismatch")
        observed_manifest_hash = str(payload.get("gate_manifest_sha256") or "").lower()
        if observed_manifest_hash != manifest.sha256:
            reasons.append("active_manifest_hash_mismatch")
        artifact_hashes = {
            "binary": str(payload.get("expected_ex5_sha256") or "").lower(),
            "source": str(payload.get("expected_mq5_sha256") or "").lower(),
            "setfile": str(payload.get("expected_setfile_sha256") or "").lower(),
        }
        for label, value in artifact_hashes.items():
            if SHA256_RE.fullmatch(value) is None:
                reasons.append(f"invalid_{label}_sha256")
        if not payload.get("parent_work_item_id"):
            reasons.append("parent_work_item_id_missing")
        parent_bindings = payload.get("parent_bindings")
        if not isinstance(parent_bindings, dict):
            reasons.append("parent_bindings_missing")
        else:
            for label, expected in artifact_hashes.items():
                nested = parent_bindings.get(label)
                observed = (
                    str(nested.get("sha256") or "").lower()
                    if isinstance(nested, dict) else ""
                )
                if observed != expected:
                    reasons.append(f"parent_{label}_binding_mismatch")
            evidence = parent_bindings.get("evidence")
            if not isinstance(evidence, dict) or SHA256_RE.fullmatch(
                str(evidence.get("sha256") or "").lower()
            ) is None:
                reasons.append("parent_evidence_binding_missing")
        routing_hash = str(payload.get("routing_identity_sha256") or "").lower()
        unsigned = dict(payload)
        unsigned.pop("routing_identity_sha256", None)
        calculated_routing_hash = hashlib.sha256(
            (
                json.dumps(
                    unsigned,
                    sort_keys=True,
                    separators=(",", ":"),
                    ensure_ascii=True,
                )
                + "\n"
            ).encode("utf-8")
        ).hexdigest()
        if routing_hash != calculated_routing_hash:
            reasons.append("routing_identity_sha256_mismatch")
        if not reasons:
            record["complete"] += 1
        else:
            record["invalid_rows"].append({
                "id": str(row["id"]),
                "reasons": reasons,
                "payload_phase": payload.get("phase"),
                "payload_contract_version": payload.get("gate_contract_version"),
                "payload_manifest_sha256": observed_manifest_hash or None,
                "active_manifest_sha256": manifest.sha256,
            })
    return coverage


def audit_database(
    db_path: str | Path,
    manifest: gate_manifest.GateManifest,
    raw_manifest: dict[str, Any],
) -> tuple[dict[str, Any], list[Check]]:
    """Audit live evidence through a physically read-only SQLite connection."""
    checks: list[Check] = []
    path = Path(db_path).resolve()
    connection = _open_ro(path)
    try:
        query_only = int(connection.execute("PRAGMA query_only").fetchone()[0])
        checks.append(_check(
            "observer.sqlite_read_only",
            "PASS" if query_only == 1 and connection.total_changes == 0 else "FAIL",
            "Audit connection is mode=ro, query_only, with zero local changes.",
            sqlite_uri_mode="ro",
            query_only=query_only,
            connection_total_changes=connection.total_changes,
        ))

        columns = _columns(connection, "work_items")
        required = {
            "id", "phase", "ea_id", "symbol", "status", "verdict",
            "payload_json", "created_at", "updated_at", "gate_contract_version",
        }
        missing = sorted(required - columns)
        checks.append(_check(
            "database.work_items_contract_columns",
            "PASS" if not missing else "FAIL",
            (
                "work_items exposes the fields required for a versioned evidence audit."
                if not missing
                else "work_items is missing required audit fields."
            ),
            missing_columns=missing,
        ))
        if missing:
            return {"path": str(path)}, checks

        activation = str(
            ((raw_manifest.get("extension_topology") or {}).get("activation_guard") or {}).get("activated_at")
            or ""
        )
        unstamped = int(connection.execute(
            """
            SELECT count(*) FROM work_items
            WHERE created_at>=? AND (gate_contract_version IS NULL OR trim(gate_contract_version)='')
            """,
            (activation,),
        ).fetchone()[0])
        version_counts = {
            str(row[0] if row[0] not in (None, "") else "<UNSTAMPED>"): int(row[1])
            for row in connection.execute(
                "SELECT gate_contract_version,count(*) FROM work_items "
                "WHERE created_at>=? GROUP BY gate_contract_version",
                (activation,),
            )
        }
        checks.append(_check(
            "database.post_activation_contract_stamps",
            "PASS" if unstamped == 0 else "FAIL",
            (
                "Every post-activation row carries an explicit contract version."
                if unstamped == 0
                else "Post-activation rows without a contract stamp exist."
            ),
            activation_date=activation,
            unstamped_rows=unstamped,
            version_counts=version_counts,
        ))

        phase_counts = _phase_counts(connection)
        observed = {
            phase: sum(statuses.values()) for phase, statuses in phase_counts.items()
        }
        missing_proof = [phase for phase, count in observed.items() if count == 0]
        checks.append(_check(
            "evidence.phase2_production_reach",
            "PASS" if not missing_proof else "WARN",
            (
                "Production has exercised every late Phase-2 stage."
                if not missing_proof
                else "Some late Phase-2 stages have no v4 production row yet; "
                "the path is operationally unproven there."
            ),
            missing_stages=missing_proof,
            counts=phase_counts,
        ))

        binding = _binding_coverage(connection, manifest)
        invalid_bindings = sum(
            int(row["rows"]) - int(row["complete"]) for row in binding.values()
        )
        checks.append(_check(
            "evidence.optimization_binding_coverage",
            "PASS" if invalid_bindings == 0 else "FAIL",
            (
                "Every observed managed Q12-Q14 row is manifest-, lineage-, "
                "and artifact-bound."
                if invalid_bindings == 0
                else "At least one managed Q12-Q14 row lacks a complete binding."
            ),
            invalid_rows=invalid_bindings,
            by_phase=binding,
        ))

        metrics = path_to_25.path_to_25_metrics(path)
        qualified = int(metrics.get("qualified_pairs") or 0)
        checks.append(_check(
            "evidence.qualified_pool",
            "PASS" if qualified >= book_build_guard.MIN_QUALIFIED_PAIRS else "WARN",
            (
                "The terminally qualified pool has reached the book trigger."
                if qualified >= book_build_guard.MIN_QUALIFIED_PAIRS
                else "The path is still accumulating terminally qualified pairs; "
                "no book trigger is licensed."
            ),
            qualified_pairs=qualified,
            target=book_build_guard.MIN_QUALIFIED_PAIRS,
            distinct_eas=int(metrics.get("distinct_eas") or 0),
            strategy_families=int(metrics.get("families") or 0),
            eta_days=metrics.get("eta_days"),
        ))

        phase3_rows = int(connection.execute(
            """
            SELECT count(*) FROM work_items
            WHERE gate_contract_version='v4' AND upper(phase) IN ('Q15','Q15_DXZ','Q15_FTMO','Q16','Q17')
            """
        ).fetchone()[0])
        phase3_status = "PASS"
        phase3_summary = "No v4 Phase-3 row bypasses the closed book trigger."
        phase3_evidence: dict[str, Any] = {
            "phase3_rows": phase3_rows,
            "qualified_pairs": qualified,
        }
        if phase3_rows and qualified < book_build_guard.MIN_QUALIFIED_PAIRS:
            phase3_status = "FAIL"
            phase3_summary = "A v4 Phase-3 row exists below the 25-pair minimum."
        elif phase3_rows:
            guard = book_build_guard.check_book_build_allowed("dxz", path)
            phase3_evidence["book_guard_allowed"] = guard.allowed
            phase3_evidence["book_guard_reasons"] = guard.reasons
            if not guard.allowed:
                phase3_status = "FAIL"
                phase3_summary = "A v4 Phase-3 row exists without a complete DXZ book authority."
        checks.append(_check(
            "evidence.no_phase3_bypass",
            phase3_status,
            phase3_summary,
            **phase3_evidence,
        ))

        open_late = sum(
            count
            for statuses in phase_counts.values()
            for status, count in statuses.items()
            if status in _OPEN_STATUSES
        )
        database = {
            "path": str(path),
            "sqlite_query_only": bool(query_only),
            "observer_total_changes": connection.total_changes,
            "phase2_counts": phase_counts,
            "open_late_phase2_rows": open_late,
            "path_to_25": metrics,
        }
        return database, checks
    finally:
        connection.close()


def build_audit(
    db_path: str | Path = DEFAULT_DB_PATH,
    manifest_path: str | Path = DEFAULT_MANIFEST_PATH,
) -> dict[str, Any]:
    manifest, raw, manifest_checks = audit_manifest(manifest_path)
    database, database_checks = audit_database(db_path, manifest, raw)
    checks = [*manifest_checks, *database_checks]
    counts = Counter(row.status for row in checks)
    return {
        "schema": SCHEMA,
        "generated_at_utc": _utc_now(),
        "mode": "READ_ONLY_SHADOW_AUDIT",
        "status": _overall(checks),
        "summary": {
            "pass": counts["PASS"],
            "warn": counts["WARN"],
            "fail": counts["FAIL"],
            "info": counts["INFO"],
        },
        "manifest": {
            "path": str(Path(manifest_path).resolve()),
            "schema_version": manifest.schema_version,
            "pipeline_version": manifest.pipeline_version,
            "sha256": manifest.sha256,
        },
        "database": database,
        "checks": _as_dicts(checks),
        "interpretation": {
            "FAIL": "A fail-closed invariant or evidence binding is broken.",
            "WARN": "The implementation is safe but not yet proven/reached in production, or documentation is stale.",
            "PASS": "The named property was observed by this read-only audit.",
        },
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--db", type=Path, default=DEFAULT_DB_PATH)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--strict-warnings",
        action="store_true",
        help="return 2 when the audit contains WARN but no FAIL",
    )
    args = parser.parse_args(argv)
    report = build_audit(args.db, args.manifest)
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    if report["status"] == "FAIL":
        return 1
    if args.strict_warnings and report["status"] == "WARN":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = ["audit_database", "audit_manifest", "build_audit"]
