"""Read-only historical work-item taxonomy view.

MNT-016 deliberately does not rewrite ``work_items``.  Instead, dashboard
connections install a TEMP view whose public status/taxonomy/reason fields are
derived from the settled verdict.  The original fields remain alongside them
as ``raw_*`` audit columns.  TEMP schema creation happens before ``query_only``
is asserted and never changes the on-disk database.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
from collections import Counter
from functools import lru_cache
from pathlib import Path
from typing import Any, Mapping


CLEAN_VIEW_NAME = "work_items_clean"
CLEAN_VIEW_SCHEMA = "qm.work_items.clean_view.v1"

OPEN_STATUSES = frozenset({"pending", "active", "claimed"})
TERMINAL_STATUS_BY_TAXONOMY = {
    "infra": "failed",
    "invalid": "failed",
    "governance": "failed",
    "strategy": "done",
    "draft_defect": "done",
    "review": "done",
}

# These are execution/transport residue, not a merit explanation.  If one of
# them survives in a later PASS/FAIL/ZERO_* payload, the derived reason is
# suppressed while the raw value remains auditable.
INFRA_REASON_TOKENS = (
    "ACTIVE_TIMEOUT",
    "BARS_ZERO",
    "COLD_CACHE",
    "EMPTY_EXPERT",
    "EMPTY_SYMBOL",
    "EX5_MISSING",
    "HISTORY_CONTEXT_INVALID",
    "LAUNCH_FAULT",
    "LOG_BOMB",
    "METATESTER",
    "NO_HISTORY",
    "NO_REAL_TICKS",
    "ONINIT_FAILED",
    "REPORT_FORMAT_DRIFT",
    "REPORT_MISSING",
    "SETFILE_MISSING",
    "SHARED_BASES_HISTORY_LOCK",
    "STALE_CLAIM",
    "SUMMARY_MISSING",
    "TERMINAL_DEAD",
    "TIMEOUT",
    "WORKER_LOOP_RELEASED",
    "WORKER_PROCESS_MISSING",
    "WORKER_RESTART_RELEASED",
)

_REASON_KEYS = (
    "verdict_reason",
    "final_failure",
    "prior_failure",
    "transient_infra_signature",
    "blocked_reason",
    "reason",
)


@lru_cache(maxsize=8192)
def _payload_fields(payload_json: str) -> tuple[str, str, bool]:
    """Return raw taxonomy, first durable reason, and JSON-validity."""

    try:
        payload = json.loads(payload_json or "{}")
    except (TypeError, ValueError, json.JSONDecodeError):
        return "", "", False
    if not isinstance(payload, dict):
        return "", "", False
    taxonomy = str(payload.get("verdict_taxonomy") or "").strip().lower()
    reason = ""
    for key in _REASON_KEYS:
        candidate = payload.get(key)
        if isinstance(candidate, str) and candidate.strip():
            reason = candidate.strip()
            break
    return taxonomy, reason, True


def verdict_taxonomy(status: Any, verdict: Any) -> str:
    """Derive the display taxonomy from the verdict, never stale payload data."""

    state = str(status or "").strip().lower()
    token = str(verdict or "").strip().upper()
    if not token:
        return "open" if state in OPEN_STATUSES else "unknown"
    if token == "INFRA_FAIL":
        return "infra"
    if token.startswith("INVALID"):
        return "invalid"
    if token == "DRAFT_DEFECT":
        return "draft_defect"
    if token.startswith(("PASS", "FAIL", "ZERO", "RETIR")) or token in {
        "AUTO_PASS",
        "CONFIG_LOCKED",
        "MODE_SELECTED",
        "MULTI_SEED_MIXED",
        "MULTI_SEED_PASS",
    }:
        return "strategy"
    if token.startswith(("REVIEW", "NEED_", "OPT_", "PENDING_", "CHALLENGER_")):
        return "review"
    if token.startswith(("SUPERSEDED", "CANCELLED", "BLOCKED", "OBSOLETE")):
        return "governance"
    return "unknown"


def clean_status(status: Any, verdict: Any) -> str:
    """Normalize the historical INFRA/done and strategy/failed split."""

    raw = str(status or "").strip().lower()
    taxonomy = verdict_taxonomy(raw, verdict)
    if taxonomy == "open":
        return raw
    return TERMINAL_STATUS_BY_TAXONOMY.get(taxonomy, raw or "unknown")


def clean_reason(status: Any, verdict: Any, payload_json: Any) -> str | None:
    """Return a verdict-compatible reason without destroying raw provenance."""

    raw_payload = str(payload_json or "")
    _raw_taxonomy, reason, _payload_valid = _payload_fields(raw_payload)
    if not reason:
        return None
    taxonomy = verdict_taxonomy(status, verdict)
    if taxonomy == "strategy":
        upper_reason = reason.upper()
        if any(token in upper_reason for token in INFRA_REASON_TOKENS):
            return None
    return reason


def allowed_combination(status: Any, verdict: Any, taxonomy: Any) -> bool:
    """Validate the public status x verdict x taxonomy invariant."""

    state = str(status or "").strip().lower()
    token = str(verdict or "").strip().upper()
    family = str(taxonomy or "").strip().lower()
    if family == "open":
        return state in OPEN_STATUSES and not token
    expected_status = TERMINAL_STATUS_BY_TAXONOMY.get(family)
    if expected_status is None or state != expected_status or not token:
        return False
    return verdict_taxonomy(state, token) == family


def derive_work_item(row: Mapping[str, Any]) -> dict[str, Any]:
    """Return one immutable-source row projected through the clean contract."""

    result = dict(row)
    raw_status = str(row.get("status") or "").strip().lower()
    raw_verdict = str(row.get("verdict") or "").strip()
    verdict = raw_verdict.upper() or None
    payload_json = str(row.get("payload_json") or "")
    raw_taxonomy, raw_reason, payload_valid = _payload_fields(payload_json)
    taxonomy = verdict_taxonomy(raw_status, verdict)
    status = clean_status(raw_status, verdict)
    reason = clean_reason(raw_status, verdict, payload_json)

    flags: list[str] = []
    if not payload_valid:
        flags.append("payload_unreadable")
    if not raw_taxonomy:
        flags.append("taxonomy_derived")
    elif raw_taxonomy != taxonomy:
        flags.append("taxonomy_restamped")
    if raw_status != status:
        flags.append("status_restamped")
    if raw_reason and reason is None:
        flags.append("reason_suppressed")
    if taxonomy == "unknown":
        flags.append("unknown_combination")

    result.update(
        {
            "status": status,
            "verdict": verdict,
            "verdict_taxonomy": taxonomy,
            "verdict_reason": reason,
            "raw_status": raw_status,
            "raw_verdict": raw_verdict or None,
            "raw_verdict_taxonomy": raw_taxonomy or None,
            "raw_verdict_reason": raw_reason or None,
            "clean_view_schema": CLEAN_VIEW_SCHEMA,
            "clean_view_flags": flags,
            "clean_view_valid": allowed_combination(status, verdict, taxonomy),
        }
    )
    return result


def _sqlite_derive(field: str, status: Any, verdict: Any, payload_json: Any) -> Any:
    raw_status = str(status or "").strip().lower()
    raw_verdict = str(verdict or "").strip()
    normalized_verdict = raw_verdict.upper() or None
    if field == "status":
        return clean_status(raw_status, normalized_verdict)
    if field == "verdict":
        return normalized_verdict
    if field == "verdict_taxonomy":
        return verdict_taxonomy(raw_status, normalized_verdict)
    if field == "raw_status":
        return raw_status
    if field == "raw_verdict":
        return raw_verdict or None
    if field == "clean_view_valid":
        taxonomy = verdict_taxonomy(raw_status, normalized_verdict)
        return int(
            allowed_combination(
                clean_status(raw_status, normalized_verdict),
                normalized_verdict,
                taxonomy,
            )
        )

    # Payload JSON is intentionally parsed only for consumers that request a
    # reason, raw payload taxonomy, or audit flags. Ordinary dashboard status
    # and verdict scans therefore stay close to native-view performance.
    row = derive_work_item(
        {"status": status, "verdict": verdict, "payload_json": payload_json}
    )
    value = row[field]
    if field == "clean_view_flags":
        return json.dumps(value, separators=(",", ":"))
    return value


def install_clean_view(connection: sqlite3.Connection) -> None:
    """Install the MNT-016 TEMP view on an existing SQLite connection."""

    for field in (
        "status",
        "verdict",
        "verdict_taxonomy",
        "verdict_reason",
        "raw_status",
        "raw_verdict",
        "raw_verdict_taxonomy",
        "raw_verdict_reason",
        "clean_view_flags",
        "clean_view_valid",
    ):
        connection.create_function(
            f"qm_clean_{field}",
            3,
            lambda status, verdict, payload, selected=field: _sqlite_derive(
                selected, status, verdict, payload
            ),
            deterministic=True,
        )
    connection.execute(f"DROP VIEW IF EXISTS temp.{CLEAN_VIEW_NAME}")
    available = {
        str(row[1]) for row in connection.execute("PRAGMA main.table_info(work_items)")
    }
    if not available:
        raise sqlite3.OperationalError("required main.work_items table is missing")

    # Small fixture databases often declare only the columns a consumer needs.
    # Project absent optional columns as NULL while keeping production's full
    # schema stable. Column names below are a closed, hard-coded allow-list.
    def source(column: str) -> str:
        return column if column in available else "NULL"

    raw_status = source("status")
    raw_verdict = source("verdict")
    raw_payload = source("payload_json")
    state = f"LOWER(TRIM(COALESCE({raw_status}, '')))"
    token = f"UPPER(TRIM(COALESCE({raw_verdict}, '')))"
    taxonomy_sql = f"""
        CASE
          WHEN {token} = '' AND {state} IN ('pending','active','claimed') THEN 'open'
          WHEN {token} = 'INFRA_FAIL' THEN 'infra'
          WHEN {token} LIKE 'INVALID%' THEN 'invalid'
          WHEN {token} = 'DRAFT_DEFECT' THEN 'draft_defect'
          WHEN {token} LIKE 'PASS%' OR {token} LIKE 'FAIL%'
            OR {token} LIKE 'ZERO%' OR {token} LIKE 'RETIR%'
            OR {token} IN ('AUTO_PASS','CONFIG_LOCKED','MODE_SELECTED',
                           'MULTI_SEED_MIXED','MULTI_SEED_PASS') THEN 'strategy'
          WHEN {token} LIKE 'REVIEW%' OR {token} LIKE 'NEED_%'
            OR {token} LIKE 'OPT_%' OR {token} LIKE 'PENDING_%'
            OR {token} LIKE 'CHALLENGER_%' THEN 'review'
          WHEN {token} LIKE 'SUPERSEDED%' OR {token} LIKE 'CANCELLED%'
            OR {token} LIKE 'BLOCKED%' OR {token} LIKE 'OBSOLETE%' THEN 'governance'
          ELSE 'unknown'
        END
    """.strip()
    status_sql = f"""
        CASE
          WHEN {token} = '' AND {state} IN ('pending','active','claimed') THEN {state}
          WHEN {token} = 'INFRA_FAIL' OR {token} LIKE 'INVALID%'
            OR {token} LIKE 'SUPERSEDED%' OR {token} LIKE 'CANCELLED%'
            OR {token} LIKE 'BLOCKED%' OR {token} LIKE 'OBSOLETE%' THEN 'failed'
          WHEN {token} = 'DRAFT_DEFECT'
            OR {token} LIKE 'PASS%' OR {token} LIKE 'FAIL%'
            OR {token} LIKE 'ZERO%' OR {token} LIKE 'RETIR%'
            OR {token} LIKE 'REVIEW%' OR {token} LIKE 'NEED_%'
            OR {token} LIKE 'OPT_%' OR {token} LIKE 'PENDING_%'
            OR {token} LIKE 'CHALLENGER_%'
            OR {token} IN ('AUTO_PASS','CONFIG_LOCKED','MODE_SELECTED',
                           'MULTI_SEED_MIXED','MULTI_SEED_PASS') THEN 'done'
          ELSE COALESCE(NULLIF({state}, ''), 'unknown')
        END
    """.strip()
    connection.execute(
        f"""
        CREATE TEMP VIEW {CLEAN_VIEW_NAME} AS
        SELECT
            {source('id')} AS id,
            {source('kind')} AS kind,
            {source('phase')} AS phase,
            {source('ea_id')} AS ea_id,
            {source('symbol')} AS symbol,
            {source('setfile_path')} AS setfile_path,
            ({status_sql}) AS status,
            NULLIF({token}, '') AS verdict,
            {source('attempt_count')} AS attempt_count,
            {source('parent_task_id')} AS parent_task_id,
            {source('evidence_path')} AS evidence_path,
            {source('claimed_by')} AS claimed_by,
            {raw_payload} AS payload_json,
            {source('created_at')} AS created_at,
            {source('updated_at')} AS updated_at,
            ({taxonomy_sql}) AS verdict_taxonomy,
            qm_clean_verdict_reason({raw_status}, {raw_verdict}, {raw_payload}) AS verdict_reason,
            {state} AS raw_status,
            NULLIF(TRIM(COALESCE({raw_verdict}, '')), '') AS raw_verdict,
            qm_clean_raw_verdict_taxonomy({raw_status}, {raw_verdict}, {raw_payload}) AS raw_verdict_taxonomy,
            qm_clean_raw_verdict_reason({raw_status}, {raw_verdict}, {raw_payload}) AS raw_verdict_reason,
            '{CLEAN_VIEW_SCHEMA}' AS clean_view_schema,
            qm_clean_clean_view_flags({raw_status}, {raw_verdict}, {raw_payload}) AS clean_view_flags,
            qm_clean_clean_view_valid({raw_status}, {raw_verdict}, {raw_payload}) AS clean_view_valid
        FROM main.work_items
        """
    )


def open_clean_view_connection(database: Path | str) -> sqlite3.Connection:
    """Open the source read-only, install the TEMP view, then fail closed."""

    resolved = Path(database).resolve()
    connection = sqlite3.connect(resolved.as_uri() + "?mode=ro", uri=True)
    try:
        install_clean_view(connection)
        connection.execute("PRAGMA query_only=ON")
        enabled = connection.execute("PRAGMA query_only").fetchone()
        if enabled is None or int(enabled[0]) != 1:
            raise sqlite3.OperationalError("SQLite query_only could not be asserted")
    except BaseException:
        connection.close()
        raise
    return connection


def audit_clean_view(connection: sqlite3.Connection) -> dict[str, Any]:
    """Summarize restamps and prove the derived invariant over a whole DB."""

    connection.row_factory = sqlite3.Row
    counts: Counter[str] = Counter()
    combinations: Counter[tuple[str, str, str]] = Counter()
    raw_combinations: Counter[tuple[str, str, str]] = Counter()
    invalid_ids: list[str] = []
    rows = connection.execute(
        f"SELECT id, status, verdict, verdict_taxonomy, raw_status, "
        f"raw_verdict, raw_verdict_taxonomy, clean_view_flags, clean_view_valid "
        f"FROM {CLEAN_VIEW_NAME}"
    )
    total = 0
    for row in rows:
        total += 1
        flags = json.loads(row["clean_view_flags"] or "[]")
        counts.update(flags)
        combinations[
            (row["status"] or "<null>", row["verdict"] or "<null>", row["verdict_taxonomy"])
        ] += 1
        raw_combinations[
            (
                row["raw_status"] or "<null>",
                row["raw_verdict"] or "<null>",
                row["raw_verdict_taxonomy"] or "<missing>",
            )
        ] += 1
        if not int(row["clean_view_valid"]):
            invalid_ids.append(str(row["id"]))
    return {
        "schema": CLEAN_VIEW_SCHEMA,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "total_rows": total,
        "invariant": {
            "valid": not invalid_ids,
            "violation_count": len(invalid_ids),
            "sample_ids": invalid_ids[:20],
        },
        "restamp_counts": dict(sorted(counts.items())),
        "derived_combinations": [
            {"status": key[0], "verdict": key[1], "taxonomy": key[2], "count": count}
            for key, count in sorted(combinations.items())
        ],
        "raw_combinations": [
            {"status": key[0], "verdict": key[1], "taxonomy": key[2], "count": count}
            for key, count in sorted(raw_combinations.items())
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db",
        type=Path,
        default=Path(r"D:\QM\strategy_farm\state\farm_state.sqlite"),
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    with open_clean_view_connection(args.db) as connection:
        report = audit_clean_view(connection)
    report["source_db"] = str(args.db.resolve())
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    else:
        print(rendered, end="")
    return 0 if report["invariant"]["valid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
