#!/usr/bin/env python3
"""Read-only typed lifecycle projection for legacy strategy-farm work items.

The current database sometimes stores nonterminal conditions as terminal
``status='done'`` verdicts. This module inventories that mismatch and produces
a content-addressed append-only overlay plan. It intentionally has no apply
function and never opens SQLite writable.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any, Iterable, Mapping


SCHEMA_VERSION = "work-item-lifecycle-v2-plan/v1"
TYPED_STATES = {
    "PENDING",
    "ACTIVE",
    "WAITING_INPUT",
    "BLOCKED",
    "QUARANTINED",
    "SUCCEEDED",
    "FAILED",
}
NONTERMINAL_STATES = {"PENDING", "ACTIVE", "WAITING_INPUT", "BLOCKED", "QUARANTINED"}
TERMINAL_STATES = {"SUCCEEDED", "FAILED"}

# These sets mirror the real work-item verdict vocabulary. They are deliberately
# explicit: a new verdict must be classified here before an inventory can pass.
SUCCEEDED_VERDICTS = frozenset(
    {
        "PASS",
        "PASS_SOFT",
        "PASS_LOWFREQ",
        "PASS_PORTFOLIO",
        "CONFIG_LOCKED",
        "OPT_ELIGIBLE",
        "CHALLENGER_SPAWNED",
        "PROMOTE_CHALLENGER",
        "KEEP_INCUMBENT",
        "ADMIT_BOTH",
        # DL-089 §3 measurement family (OPT_CENSUS): a completed single-year
        # measurement is a terminal 'done' success in lifecycle terms. It is NOT
        # a gate pass — the MNT-016 clean view scores it under its own
        # 'measurement' taxonomy so it never enters gate_pass counts; here it
        # only needs a terminal-success lifecycle bucket so the read-only
        # inventory does not fail closed on the new verdict token.
        "MEASURED",
    }
)
WAITING_INPUT_VERDICTS = frozenset(
    {
        "WAITING_INPUT",
        "NEED_MORE_DATA",
        "REVIEW_REQUIRED",
    }
)
BLOCKED_VERDICTS = frozenset(
    {
        "BLOCKED",
        "BLOCKED_FACTORY_OFF",
        "BLOCKED_STALE_BUILD_RESULT",
        "PENDING_IMPLEMENTATION",
        "PENDING_RUNNER",
        "REPORT_ONLY",
    }
)
FAILED_VERDICTS = frozenset(
    {
        "CANCELLED_DUPLICATE_REQUEUE",
        "DRAFT_DEFECT",
        "FAIL",
        "FAIL_DD_PORTFOLIO_REVIEW",
        "FAIL_HARD",
        "FAIL_PORTFOLIO",
        "FAIL_SOFT",
        "INFRA_FAIL",
        "INVALID",
        "INVALID_BUILD_STATIC_FIDELITY",
        "INVALID_EVIDENCE",
        "MIN_TRADES_NOT_MET",
        "OBSOLETE_NON_DWX_SYMBOL",
        "OPT_REJECTED",
        "RETIRE",
        "RETIRED_ARCHIVED",
        "RETIRED_LOW_FREQ",
        "RETIRED_WITHOUT_BUILD",
        "SUPERSEDED",
        "SUPERSEDED_BY_LOGICAL_BASKET",
        "SUPERSEDED_DUPLICATE",
        "ZERO_TRADES",
    }
)
KNOWN_VERDICTS = frozenset().union(
    SUCCEEDED_VERDICTS,
    WAITING_INPUT_VERDICTS,
    BLOCKED_VERDICTS,
    FAILED_VERDICTS,
)

if sum(
    len(values)
    for values in (
        SUCCEEDED_VERDICTS,
        WAITING_INPUT_VERDICTS,
        BLOCKED_VERDICTS,
        FAILED_VERDICTS,
    )
) != len(KNOWN_VERDICTS):
    raise RuntimeError("work-item lifecycle verdict classes overlap")


class LifecycleProjectionError(ValueError):
    pass


def _canonical_bytes(payload: Mapping[str, Any]) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def _payload(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except json.JSONDecodeError:
        return {"_invalid_payload_json": True}
    return value if isinstance(value, dict) else {"_invalid_payload_json": True}


def project_row(row: Mapping[str, Any]) -> dict[str, Any]:
    work_item_id = str(row.get("id") or "").strip()
    legacy_status = str(row.get("status") or "").strip().lower()
    legacy_verdict = str(row.get("verdict") or "").strip().upper()
    payload = _payload(row.get("payload_json"))
    if not work_item_id:
        raise LifecycleProjectionError("work item id is required")
    if legacy_status not in {"pending", "active", "done", "failed"}:
        raise LifecycleProjectionError(
            f"{work_item_id}: unsupported legacy status {legacy_status!r}"
        )
    if legacy_verdict and legacy_verdict not in KNOWN_VERDICTS:
        raise LifecycleProjectionError(
            f"{work_item_id}: unsupported verdict {legacy_verdict!r} for "
            f"legacy status {legacy_status!r}"
        )
    if legacy_status in {"pending", "active"} and legacy_verdict:
        raise LifecycleProjectionError(
            f"{work_item_id}: {legacy_status} row must not carry verdict "
            f"{legacy_verdict!r}"
        )

    quarantine_code = str(
        payload.get("quarantine_code")
        or payload.get("quarantine_reason")
        or payload.get("maintenance_hold_code")
        or ""
    ).strip()
    maintenance_transitions = payload.get("maintenance_transitions")
    transition_quarantine = isinstance(maintenance_transitions, list) and any(
        isinstance(transition, Mapping)
        and str(transition.get("action") or "").strip().lower() == "quarantine"
        for transition in maintenance_transitions
    )
    if payload.get("quarantined") is True or quarantine_code or transition_quarantine:
        state, reason = "QUARANTINED", quarantine_code or "EXPLICIT_QUARANTINE"
    elif legacy_status == "pending":
        state, reason = "PENDING", "LEGACY_PENDING"
    elif legacy_status == "active":
        state, reason = "ACTIVE", "LEGACY_ACTIVE"
    elif not legacy_verdict:
        raise LifecycleProjectionError(
            f"{work_item_id}: terminal legacy row requires a verdict"
        )
    elif legacy_verdict in WAITING_INPUT_VERDICTS:
        state = "WAITING_INPUT"
        reason = str(payload.get("verdict_reason") or "").strip() or legacy_verdict
    elif legacy_verdict in BLOCKED_VERDICTS:
        state = "BLOCKED"
        reason = str(payload.get("verdict_reason") or "").strip() or legacy_verdict
    elif legacy_verdict in SUCCEEDED_VERDICTS:
        if legacy_status != "done":
            raise LifecycleProjectionError(
                f"{work_item_id}: success verdict {legacy_verdict!r} requires "
                "legacy status 'done'"
            )
        state, reason = "SUCCEEDED", legacy_verdict
    elif legacy_verdict in FAILED_VERDICTS:
        state, reason = "FAILED", legacy_verdict
    else:  # pragma: no cover - guarded by the exhaustive KNOWN_VERDICTS check
        raise LifecycleProjectionError(f"{work_item_id}: unclassified known verdict")

    projection = {
        "work_item_id": work_item_id,
        "legacy_status": legacy_status,
        "legacy_verdict": legacy_verdict or None,
        "typed_state": state,
        "terminal": state in TERMINAL_STATES,
        "reason": reason,
        "source_updated_at": str(row.get("updated_at") or "").strip() or None,
    }
    projection["idempotency_key"] = hashlib.sha256(
        _canonical_bytes(projection)
    ).hexdigest()
    return projection


def build_plan(rows: Iterable[Mapping[str, Any]], *, database_sha256: str) -> dict[str, Any]:
    if len(database_sha256) != 64 or any(c not in "0123456789abcdef" for c in database_sha256):
        raise LifecycleProjectionError("database_sha256 must be lowercase SHA-256")
    projected = sorted((project_row(row) for row in rows), key=lambda row: row["work_item_id"])
    if len({row["work_item_id"] for row in projected}) != len(projected):
        raise LifecycleProjectionError("duplicate work_item_id")
    counts = {state: 0 for state in sorted(TYPED_STATES)}
    for row in projected:
        counts[row["typed_state"]] += 1
    plan: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "mode": "READ_ONLY_DRY_RUN",
        "database_sha256": database_sha256,
        "runtime_action": "NONE",
        "owner_approval_required_before_apply": True,
        "apply_implemented": False,
        "overlay_contract": {
            "append_only": True,
            "historical_rows_rewritten": False,
            "second_apply_expected_changes": 0,
        },
        "typed_state_counts": counts,
        "rows": projected,
    }
    plan["plan_sha256"] = hashlib.sha256(_canonical_bytes(plan)).hexdigest()
    return plan


def inventory_database(path: Path | str) -> dict[str, Any]:
    database = Path(path).resolve()
    if not database.is_file():
        raise FileNotFoundError(database)
    database_sha256 = hashlib.sha256(database.read_bytes()).hexdigest()
    uri = database.as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA query_only=ON")
        if connection.execute("PRAGMA query_only").fetchone()[0] != 1:
            raise LifecycleProjectionError("SQLite query_only could not be asserted")
        rows = connection.execute(
            "SELECT id,status,verdict,payload_json,updated_at FROM work_items ORDER BY id"
        ).fetchall()
        return build_plan((dict(row) for row in rows), database_sha256=database_sha256)
    finally:
        connection.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", type=Path)
    args = parser.parse_args()
    print(json.dumps(inventory_database(args.database), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
