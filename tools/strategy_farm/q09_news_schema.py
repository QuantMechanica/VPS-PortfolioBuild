#!/usr/bin/env python3
"""Additive SQLite sidecars for the Q09_NEWS v2 evidence contract.

The production farm database contains historical foreign-key violations and
runs with ``PRAGMA foreign_keys=OFF``.  This module therefore does not toggle
global FK enforcement.  New relationships are protected with insert triggers
and transactional validation instead.

All tables created here are append-only.  Historical ``work_items`` verdicts
and ``portfolio_candidates`` states remain untouched.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence

try:
    from q09_news_contract import (
        ADJUDICATION_SCHEMA_VERSION,
        CANONICAL_VERDICTS,
        SEEDS,
        canonical_json_bytes,
        sha256_file,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.q09_news_contract import (
        ADJUDICATION_SCHEMA_VERSION,
        CANONICAL_VERDICTS,
        SEEDS,
        canonical_json_bytes,
        sha256_file,
    )


SCHEMA_VERSION = 3
CONTRACT_VERSION = "Q09_NEWS_V2"
ACTIVATION_HOLD_CODE = "Q09_AWAITING_SEALED_PLAN"
ACTIVATION_HOLD_REASON = (
    "Q09_NEWS is not claimable until a sealed run plan is hash-bound"
)
ACTIVATION_STATE_AWAITING = "AWAITING_SEALED_PLAN"
ACTIVATION_STATE_RUNNABLE = "RUNNABLE_BOUND"


class SchemaError(RuntimeError):
    """Raised when the additive Q09 schema or its lineage is invalid."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def hold_until_plan_bound(
    conn: sqlite3.Connection,
    work_item_id: str,
    *,
    now: str | None = None,
) -> None:
    """Keep a pending Q09 row out of every ordinary claimant until binding.

    ``work_item_holds`` is already consumed by both fresh pump processes and
    resident terminal workers. Using that existing database contract closes
    the enqueue-to-bind race without requiring a worker restart. A different
    active hold is never overwritten.
    """

    item = conn.execute(
        "SELECT phase,status,claimed_by FROM work_items WHERE id=?",
        (str(work_item_id),),
    ).fetchone()
    if item is None or item[0] != "Q09_NEWS":
        raise SchemaError("Q09 activation hold requires a canonical Q09_NEWS row")
    if item[1] != "pending" or str(item[2] or "").strip():
        raise SchemaError("Q09 activation hold requires an unclaimed pending row")
    existing = conn.execute(
        "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?",
        (str(work_item_id),),
    ).fetchone()
    if existing is not None and int(existing[1]) == 1 and existing[0] != ACTIVATION_HOLD_CODE:
        raise SchemaError("Q09 activation cannot replace a different active work-item hold")
    stamp = now or utc_now()
    conn.execute(
        """
        INSERT INTO work_item_holds(
            work_item_id,hold_code,reason,active,release_on_restart,
            created_at,updated_at,released_at,release_note
        ) VALUES(?,?,?,1,0,?,?,NULL,NULL)
        ON CONFLICT(work_item_id) DO UPDATE SET
            hold_code=excluded.hold_code,
            reason=excluded.reason,
            active=1,
            release_on_restart=0,
            updated_at=excluded.updated_at,
            released_at=NULL,
            release_note=NULL
        """,
        (
            str(work_item_id),
            ACTIVATION_HOLD_CODE,
            ACTIVATION_HOLD_REASON,
            stamp,
            stamp,
        ),
    )


def release_plan_bound_hold(
    conn: sqlite3.Connection,
    work_item_id: str,
    *,
    now: str | None = None,
) -> bool:
    """Release only this contract's hold after binding succeeds atomically."""

    existing = conn.execute(
        "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?",
        (str(work_item_id),),
    ).fetchone()
    if existing is None:
        return False  # Backward-compatible for pre-hold pending rows.
    if existing[0] != ACTIVATION_HOLD_CODE:
        if int(existing[1]) == 1:
            raise SchemaError("Q09 binding cannot release a different active work-item hold")
        return False
    if int(existing[1]) != 1:
        return False
    stamp = now or utc_now()
    cursor = conn.execute(
        """
        UPDATE work_item_holds
        SET active=0,updated_at=?,released_at=?,
            release_note='sealed Q09 run plan bound; ordinary worker claim enabled'
        WHERE work_item_id=? AND hold_code=? AND active=1
        """,
        (stamp, stamp, str(work_item_id), ACTIVATION_HOLD_CODE),
    )
    if cursor.rowcount != 1:
        raise SchemaError("Q09 activation hold changed during plan binding")
    return True


def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone() is not None


def _view_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='view' AND name=?", (name,)
    ).fetchone() is not None


def _require_base_schema(conn: sqlite3.Connection) -> None:
    missing = [name for name in ("work_items", "portfolio_candidates") if not _table_exists(conn, name)]
    if missing:
        raise SchemaError(f"base farm schema missing: {', '.join(missing)}")


DDL = r"""
CREATE TABLE IF NOT EXISTS q09_news_schema_meta (
    schema_name TEXT PRIMARY KEY,
    schema_version INTEGER NOT NULL,
    installed_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS work_item_contracts (
    contract_id TEXT PRIMARY KEY,
    work_item_id TEXT NOT NULL UNIQUE,
    phase_id TEXT NOT NULL,
    contract_version TEXT NOT NULL,
    candidate_lineage_key TEXT NOT NULL,
    input_manifest_path TEXT NOT NULL,
    input_manifest_sha256 TEXT NOT NULL CHECK (
        length(input_manifest_sha256)=64 AND input_manifest_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    supersedes_contract_id TEXT,
    created_at TEXT NOT NULL,
    UNIQUE (phase_id, contract_version, input_manifest_sha256)
);

CREATE TABLE IF NOT EXISTS work_item_dependencies (
    child_work_item_id TEXT NOT NULL,
    dependency_role TEXT NOT NULL CHECK (
        dependency_role IN ('Q08_INPUT', 'Q09_NEWS', 'Q09_PORTFOLIO')
    ),
    parent_work_item_id TEXT NOT NULL,
    parent_evidence_sha256 TEXT NOT NULL CHECK (
        length(parent_evidence_sha256)=64 AND parent_evidence_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    required_verdicts_json TEXT NOT NULL CHECK (json_valid(required_verdicts_json)),
    created_at TEXT NOT NULL,
    PRIMARY KEY (child_work_item_id, dependency_role)
);

CREATE TABLE IF NOT EXISTS news_calendar_bundles (
    bundle_id TEXT PRIMARY KEY,
    schema_version TEXT NOT NULL,
    manifest_path TEXT NOT NULL,
    manifest_sha256 TEXT NOT NULL UNIQUE CHECK (
        length(manifest_sha256)=64 AND manifest_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    content_sha256 TEXT NOT NULL CHECK (
        length(content_sha256)=64 AND content_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    coverage_from_utc TEXT NOT NULL,
    coverage_to_utc TEXT NOT NULL,
    event_from_utc TEXT,
    event_to_utc TEXT,
    row_count INTEGER NOT NULL CHECK (row_count >= 0),
    publisher_evidence_path TEXT NOT NULL,
    publisher_evidence_sha256 TEXT NOT NULL CHECK (
        length(publisher_evidence_sha256)=64 AND publisher_evidence_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    correction_reason TEXT,
    approved_by TEXT,
    approved_at TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS news_calendar_bundle_files (
    bundle_id TEXT NOT NULL,
    file_role TEXT NOT NULL,
    relative_path TEXT NOT NULL,
    sha256 TEXT NOT NULL CHECK (length(sha256)=64 AND sha256 NOT GLOB '*[^0-9a-f]*'),
    size_bytes INTEGER NOT NULL CHECK (size_bytes >= 0),
    row_count INTEGER NOT NULL CHECK (row_count >= 0),
    event_from_utc TEXT,
    event_to_utc TEXT,
    created_at TEXT NOT NULL,
    PRIMARY KEY (bundle_id, file_role, relative_path)
);

CREATE TABLE IF NOT EXISTS q09_news_tests (
    work_item_id TEXT PRIMARY KEY,
    contract_version TEXT NOT NULL,
    deployment_target TEXT NOT NULL,
    target_compliance TEXT NOT NULL CHECK (target_compliance IN ('NONE','DXZ','FTMO','5ERS')),
    q08_work_item_id TEXT NOT NULL,
    calendar_bundle_id TEXT NOT NULL,
    paired_base_identity_sha256 TEXT NOT NULL CHECK (
        length(paired_base_identity_sha256)=64 AND paired_base_identity_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    baseline_setfile_sha256 TEXT NOT NULL CHECK (
        length(baseline_setfile_sha256)=64 AND baseline_setfile_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    ex5_sha256 TEXT NOT NULL CHECK (length(ex5_sha256)=64 AND ex5_sha256 NOT GLOB '*[^0-9a-f]*'),
    include_closure_sha256 TEXT NOT NULL CHECK (
        length(include_closure_sha256)=64 AND include_closure_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    selection_from_utc TEXT NOT NULL,
    selection_to_utc TEXT NOT NULL,
    holdout_from_utc TEXT NOT NULL,
    holdout_to_utc TEXT NOT NULL,
    complete_months INTEGER NOT NULL CHECK (complete_months >= 60),
    holdout_complete_months INTEGER NOT NULL CHECK (holdout_complete_months >= 24),
    matrix_scope TEXT NOT NULL CHECK (matrix_scope IN ('7x1_target_compliance','7x4')),
    verdict TEXT NOT NULL CHECK (verdict IN ('CONFIG_LOCKED','REVIEW_REQUIRED','INVALID_EVIDENCE')),
    chosen_temporal TEXT,
    chosen_compliance TEXT,
    aggregate_path TEXT NOT NULL,
    aggregate_sha256 TEXT NOT NULL CHECK (
        length(aggregate_sha256)=64 AND aggregate_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    created_at TEXT NOT NULL,
    CHECK (
        (verdict='CONFIG_LOCKED' AND chosen_temporal IS NOT NULL AND chosen_compliance IS NOT NULL)
        OR (verdict<>'CONFIG_LOCKED' AND chosen_temporal IS NULL AND chosen_compliance IS NULL)
    )
);

CREATE TABLE IF NOT EXISTS q09_news_cells (
    q09_news_work_item_id TEXT NOT NULL,
    arm TEXT NOT NULL CHECK (arm IN ('CONTROL_OFF','POLICY_ON')),
    temporal_mode TEXT NOT NULL,
    compliance_mode TEXT NOT NULL CHECK (compliance_mode IN ('NONE','DXZ','FTMO','5ERS')),
    seed INTEGER NOT NULL,
    requested_seed INTEGER NOT NULL,
    effective_seed INTEGER NOT NULL,
    paired_base_identity_sha256 TEXT NOT NULL CHECK (
        length(paired_base_identity_sha256)=64 AND paired_base_identity_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    run_identity_sha256 TEXT NOT NULL UNIQUE CHECK (
        length(run_identity_sha256)=64 AND run_identity_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    setfile_sha256 TEXT NOT NULL CHECK (length(setfile_sha256)=64 AND setfile_sha256 NOT GLOB '*[^0-9a-f]*'),
    evidence_sha256 TEXT NOT NULL UNIQUE CHECK (
        length(evidence_sha256)=64 AND evidence_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    report_sha256 TEXT NOT NULL CHECK (length(report_sha256)=64 AND report_sha256 NOT GLOB '*[^0-9a-f]*'),
    selection_metrics_json TEXT NOT NULL CHECK (json_valid(selection_metrics_json)),
    holdout_metrics_json TEXT NOT NULL CHECK (json_valid(holdout_metrics_json)),
    full_metrics_json TEXT NOT NULL CHECK (json_valid(full_metrics_json)),
    q07_seed_stability_pass INTEGER NOT NULL CHECK (q07_seed_stability_pass IN (0,1)),
    flat_at_event_receipt_sha256 TEXT,
    created_at TEXT NOT NULL,
    PRIMARY KEY (q09_news_work_item_id, arm, temporal_mode, compliance_mode, seed),
    CHECK (seed=requested_seed AND seed=effective_seed),
    CHECK (
        flat_at_event_receipt_sha256 IS NULL OR
        (length(flat_at_event_receipt_sha256)=64 AND flat_at_event_receipt_sha256 NOT GLOB '*[^0-9a-f]*')
    )
);

CREATE TABLE IF NOT EXISTS q09_news_cell_occurrences (
    occurrence_identity_sha256 TEXT PRIMARY KEY CHECK (
        length(occurrence_identity_sha256)=64 AND
        occurrence_identity_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    q09_news_work_item_id TEXT NOT NULL,
    run_identity_sha256 TEXT NOT NULL CHECK (
        length(run_identity_sha256)=64 AND run_identity_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    evidence_sha256 TEXT NOT NULL CHECK (
        length(evidence_sha256)=64 AND evidence_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    report_sha256 TEXT NOT NULL CHECK (
        length(report_sha256)=64 AND report_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    evidence_path TEXT NOT NULL,
    report_path TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE (
        q09_news_work_item_id,run_identity_sha256,evidence_sha256,report_sha256,
        evidence_path,report_path
    )
);

CREATE VIEW IF NOT EXISTS q09_news_cells_by_work_item AS
SELECT
    o.q09_news_work_item_id,
    c.arm,c.temporal_mode,c.compliance_mode,c.seed,c.requested_seed,c.effective_seed,
    c.paired_base_identity_sha256,c.run_identity_sha256,c.setfile_sha256,
    o.evidence_sha256,o.report_sha256,
    c.selection_metrics_json,c.holdout_metrics_json,c.full_metrics_json,
    c.q07_seed_stability_pass,c.flat_at_event_receipt_sha256,o.created_at
FROM q09_news_cell_occurrences o
JOIN q09_news_cells c ON c.run_identity_sha256=o.run_identity_sha256
WHERE NOT EXISTS (
    SELECT 1 FROM q09_news_cell_occurrences newer
    WHERE newer.q09_news_work_item_id=o.q09_news_work_item_id
      AND newer.run_identity_sha256=o.run_identity_sha256
      AND (
          newer.created_at>o.created_at OR
          (newer.created_at=o.created_at AND
           newer.occurrence_identity_sha256>o.occurrence_identity_sha256)
      )
)
UNION ALL
SELECT
    c.q09_news_work_item_id,
    c.arm,c.temporal_mode,c.compliance_mode,c.seed,c.requested_seed,c.effective_seed,
    c.paired_base_identity_sha256,c.run_identity_sha256,c.setfile_sha256,
    c.evidence_sha256,c.report_sha256,
    c.selection_metrics_json,c.holdout_metrics_json,c.full_metrics_json,
    c.q07_seed_stability_pass,c.flat_at_event_receipt_sha256,c.created_at
FROM q09_news_cells c
WHERE NOT EXISTS (
    SELECT 1 FROM q09_news_cell_occurrences o
    WHERE o.q09_news_work_item_id=c.q09_news_work_item_id
      AND o.run_identity_sha256=c.run_identity_sha256
);

CREATE TABLE IF NOT EXISTS q09_news_arms (
    q09_news_work_item_id TEXT NOT NULL,
    arm TEXT NOT NULL CHECK (arm IN ('CONTROL_OFF','POLICY_ON')),
    temporal_mode TEXT NOT NULL,
    compliance_mode TEXT NOT NULL CHECK (compliance_mode IN ('NONE','DXZ','FTMO','5ERS')),
    seed_set_json TEXT NOT NULL CHECK (json_valid(seed_set_json)),
    setfile_hashes_json TEXT NOT NULL CHECK (json_valid(setfile_hashes_json)),
    evidence_hashes_json TEXT NOT NULL CHECK (json_valid(evidence_hashes_json)),
    created_at TEXT NOT NULL,
    PRIMARY KEY (q09_news_work_item_id, arm)
);

CREATE TABLE IF NOT EXISTS candidate_qualifications (
    qualification_id TEXT PRIMARY KEY,
    candidate_lineage_key TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    contract_version TEXT NOT NULL,
    q08_work_item_id TEXT,
    q09_news_work_item_id TEXT,
    q09_portfolio_work_item_id TEXT,
    q10_work_item_id TEXT,
    q09_news_evidence_sha256 TEXT,
    q09_portfolio_evidence_sha256 TEXT,
    q10_evidence_sha256 TEXT,
    baseline_setfile_sha256 TEXT,
    q10_setfile_sha256 TEXT,
    ex5_sha256 TEXT,
    include_closure_sha256 TEXT,
    calendar_bundle_id TEXT,
    legacy_source_work_item_id TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN (
        'QUALIFIED',
        'LEGACY_NEWS_REQUAL_REQUIRED',
        'LEGACY_STALE_BLOCKED',
        'EXCLUDED_DUPLICATE',
        'VINTAGE_STALE',
        'LIVE_LEGACY_REQUAL_REQUIRED',
        'STAGED_REQUAL_REQUIRED'
    )),
    reason_code TEXT NOT NULL,
    evidence_manifest_path TEXT NOT NULL,
    evidence_manifest_sha256 TEXT NOT NULL CHECK (
        length(evidence_manifest_sha256)=64 AND evidence_manifest_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    supersedes_qualification_id TEXT,
    created_at TEXT NOT NULL,
    CHECK (q09_news_evidence_sha256 IS NULL OR
           (length(q09_news_evidence_sha256)=64 AND q09_news_evidence_sha256 NOT GLOB '*[^0-9a-f]*')),
    CHECK (q09_portfolio_evidence_sha256 IS NULL OR
           (length(q09_portfolio_evidence_sha256)=64 AND q09_portfolio_evidence_sha256 NOT GLOB '*[^0-9a-f]*')),
    CHECK (q10_evidence_sha256 IS NULL OR
           (length(q10_evidence_sha256)=64 AND q10_evidence_sha256 NOT GLOB '*[^0-9a-f]*')),
    CHECK (baseline_setfile_sha256 IS NULL OR
           (length(baseline_setfile_sha256)=64 AND baseline_setfile_sha256 NOT GLOB '*[^0-9a-f]*')),
    CHECK (q10_setfile_sha256 IS NULL OR
           (length(q10_setfile_sha256)=64 AND q10_setfile_sha256 NOT GLOB '*[^0-9a-f]*')),
    CHECK (ex5_sha256 IS NULL OR (length(ex5_sha256)=64 AND ex5_sha256 NOT GLOB '*[^0-9a-f]*')),
    CHECK (include_closure_sha256 IS NULL OR
           (length(include_closure_sha256)=64 AND include_closure_sha256 NOT GLOB '*[^0-9a-f]*'))
);
CREATE INDEX IF NOT EXISTS idx_candidate_qualifications_lineage
    ON candidate_qualifications(candidate_lineage_key, created_at, qualification_id);

CREATE TABLE IF NOT EXISTS q09_news_migration_runs (
    migration_id TEXT PRIMARY KEY,
    plan_sha256 TEXT NOT NULL UNIQUE CHECK (length(plan_sha256)=64 AND plan_sha256 NOT GLOB '*[^0-9a-f]*'),
    protected_before_sha256 TEXT NOT NULL CHECK (
        length(protected_before_sha256)=64 AND protected_before_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    protected_after_sha256 TEXT NOT NULL CHECK (
        length(protected_after_sha256)=64 AND protected_after_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    snapshot_path TEXT NOT NULL,
    snapshot_sha256 TEXT NOT NULL CHECK (
        length(snapshot_sha256)=64 AND snapshot_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    snapshot_logical_sha256 TEXT NOT NULL CHECK (
        length(snapshot_logical_sha256)=64 AND snapshot_logical_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    revert_guard_sha256 TEXT NOT NULL CHECK (
        length(revert_guard_sha256)=64 AND revert_guard_sha256 NOT GLOB '*[^0-9a-f]*'
    ),
    inserted_count INTEGER NOT NULL CHECK (inserted_count >= 0),
    applied_at TEXT NOT NULL
);
"""


TRIGGERS = r"""
CREATE TRIGGER IF NOT EXISTS trg_wic_validate_insert
BEFORE INSERT ON work_item_contracts
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM work_items w WHERE w.id=NEW.work_item_id AND w.phase=NEW.phase_id
    ) THEN RAISE(ABORT, 'work_item_contract phase/work_item mismatch') END;
    SELECT CASE WHEN NEW.phase_id='Q09' THEN RAISE(ABORT, 'historical Q09 alias is read-only') END;
    SELECT CASE WHEN NEW.supersedes_contract_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM work_item_contracts c WHERE c.contract_id=NEW.supersedes_contract_id
    ) THEN RAISE(ABORT, 'superseded contract does not exist') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_wid_validate_insert
BEFORE INSERT ON work_item_dependencies
BEGIN
    SELECT CASE WHEN NEW.child_work_item_id=NEW.parent_work_item_id
        THEN RAISE(ABORT, 'work item cannot depend on itself') END;
    SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM work_items WHERE id=NEW.child_work_item_id)
        THEN RAISE(ABORT, 'dependency child work item missing') END;
    SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM work_items WHERE id=NEW.parent_work_item_id)
        THEN RAISE(ABORT, 'dependency parent work item missing') END;
    SELECT CASE WHEN json_array_length(NEW.required_verdicts_json)=0
        THEN RAISE(ABORT, 'required verdict set is empty') END;
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM work_items p, json_each(NEW.required_verdicts_json) v
        WHERE p.id=NEW.parent_work_item_id AND p.verdict=v.value
    ) THEN RAISE(ABORT, 'dependency parent verdict is not allowed') END;
    SELECT CASE WHEN NEW.dependency_role='Q08_INPUT' AND NOT EXISTS (
        SELECT 1 FROM work_items c, work_items p
        WHERE c.id=NEW.child_work_item_id AND p.id=NEW.parent_work_item_id
          AND c.phase IN ('Q09_NEWS','Q09_PORTFOLIO') AND p.phase='Q08'
    ) THEN RAISE(ABORT, 'Q08_INPUT phase mismatch') END;
    SELECT CASE WHEN NEW.dependency_role='Q09_NEWS' AND NOT EXISTS (
        SELECT 1 FROM work_items c, work_items p
        WHERE c.id=NEW.child_work_item_id AND p.id=NEW.parent_work_item_id
          AND c.phase='Q10' AND p.phase='Q09_NEWS'
    ) THEN RAISE(ABORT, 'Q09_NEWS dependency phase mismatch') END;
    SELECT CASE WHEN NEW.dependency_role='Q09_PORTFOLIO' AND NOT EXISTS (
        SELECT 1 FROM work_items c, work_items p
        WHERE c.id=NEW.child_work_item_id AND p.id=NEW.parent_work_item_id
          AND c.phase='Q10' AND p.phase='Q09_PORTFOLIO'
    ) THEN RAISE(ABORT, 'Q09_PORTFOLIO dependency phase mismatch') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_ncbf_validate_insert
BEFORE INSERT ON news_calendar_bundle_files
BEGIN
    SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM news_calendar_bundles WHERE bundle_id=NEW.bundle_id)
        THEN RAISE(ABORT, 'calendar bundle missing') END;
    SELECT CASE WHEN NEW.relative_path LIKE '/%' OR NEW.relative_path LIKE '\\%' OR
        NEW.relative_path LIKE '%..%' OR instr(NEW.relative_path, ':')>0
        THEN RAISE(ABORT, 'calendar relative_path is unsafe') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_q09_test_validate_insert
BEFORE INSERT ON q09_news_tests
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM work_items w WHERE w.id=NEW.work_item_id AND w.phase='Q09_NEWS'
    ) THEN RAISE(ABORT, 'q09 test work item missing or non-canonical phase') END;
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM news_calendar_bundles b WHERE b.bundle_id=NEW.calendar_bundle_id
    ) THEN RAISE(ABORT, 'q09 calendar bundle missing') END;
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM work_item_dependencies d
        WHERE d.child_work_item_id=NEW.work_item_id AND d.dependency_role='Q08_INPUT'
          AND d.parent_work_item_id=NEW.q08_work_item_id
    ) THEN RAISE(ABORT, 'q09 Q08_INPUT dependency missing') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_q09_cell_validate_insert
BEFORE INSERT ON q09_news_cells
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM q09_news_tests t WHERE t.work_item_id=NEW.q09_news_work_item_id
    ) THEN RAISE(ABORT, 'q09 test header missing') END;
    SELECT CASE WHEN NEW.seed NOT IN (42,17,99,7,2026)
        THEN RAISE(ABORT, 'q09 seed is not canonical') END;
    SELECT CASE WHEN NEW.arm='CONTROL_OFF' AND (NEW.temporal_mode<>'OFF' OR NEW.compliance_mode<>'NONE')
        THEN RAISE(ABORT, 'CONTROL_OFF must use OFF/NONE') END;
    SELECT CASE WHEN NEW.paired_base_identity_sha256<>(
        SELECT paired_base_identity_sha256 FROM q09_news_tests WHERE work_item_id=NEW.q09_news_work_item_id
    ) THEN RAISE(ABORT, 'q09 cell base identity mismatch') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_q09_cell_occurrence_validate_insert
BEFORE INSERT ON q09_news_cell_occurrences
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM q09_news_tests t
        WHERE t.work_item_id=NEW.q09_news_work_item_id
    ) THEN RAISE(ABORT, 'q09 occurrence test header missing') END;
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM q09_news_cells c
        WHERE c.run_identity_sha256=NEW.run_identity_sha256
    ) THEN RAISE(ABORT, 'q09 occurrence canonical cell missing') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_q09_arm_validate_insert
BEFORE INSERT ON q09_news_arms
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM q09_news_tests t
        WHERE t.work_item_id=NEW.q09_news_work_item_id AND t.verdict='CONFIG_LOCKED'
    ) THEN RAISE(ABORT, 'locked arm requires CONFIG_LOCKED q09 test') END;
    SELECT CASE WHEN NEW.arm='CONTROL_OFF' AND (NEW.temporal_mode<>'OFF' OR NEW.compliance_mode<>'NONE')
        THEN RAISE(ABORT, 'locked CONTROL_OFF must use OFF/NONE') END;
    SELECT CASE WHEN NEW.arm='POLICY_ON' AND NOT EXISTS (
        SELECT 1 FROM q09_news_tests t WHERE t.work_item_id=NEW.q09_news_work_item_id
          AND t.chosen_temporal=NEW.temporal_mode AND t.chosen_compliance=NEW.compliance_mode
    ) THEN RAISE(ABORT, 'locked POLICY_ON does not match adjudication') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_cq_validate_insert
BEFORE INSERT ON candidate_qualifications
BEGIN
    SELECT CASE WHEN NEW.supersedes_qualification_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM candidate_qualifications q WHERE q.qualification_id=NEW.supersedes_qualification_id
    ) THEN RAISE(ABORT, 'superseded qualification missing') END;
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM portfolio_candidates p
        WHERE p.ea_id=NEW.ea_id AND p.symbol=NEW.symbol
          AND p.q11_work_item_id=NEW.legacy_source_work_item_id
    ) THEN RAISE(ABORT, 'qualification source candidate missing') END;
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM candidate_qualifications q
        WHERE q.ea_id=NEW.ea_id AND q.symbol=NEW.symbol
          AND q.legacy_source_work_item_id=NEW.legacy_source_work_item_id
          AND q.candidate_lineage_key<>NEW.candidate_lineage_key
    ) THEN RAISE(ABORT, 'candidate source cannot change lineage key') END;
    SELECT CASE WHEN NEW.state='QUALIFIED' AND (
        NEW.q08_work_item_id IS NULL OR NEW.q09_news_work_item_id IS NULL OR
        NEW.q09_portfolio_work_item_id IS NULL OR NEW.q10_work_item_id IS NULL OR
        NEW.q09_news_evidence_sha256 IS NULL OR NEW.q09_portfolio_evidence_sha256 IS NULL OR
        NEW.q10_evidence_sha256 IS NULL OR NEW.baseline_setfile_sha256 IS NULL OR
        NEW.q10_setfile_sha256 IS NULL OR NEW.ex5_sha256 IS NULL OR
        NEW.include_closure_sha256 IS NULL OR NEW.calendar_bundle_id IS NULL
    ) THEN RAISE(ABORT, 'QUALIFIED lineage is incomplete') END;
    SELECT CASE WHEN NEW.state='QUALIFIED' AND NOT EXISTS (
        SELECT 1 FROM work_items q08, work_items q09n, work_items q09p, work_items q10
        WHERE q08.id=NEW.q08_work_item_id AND q08.phase='Q08'
          AND q09n.id=NEW.q09_news_work_item_id AND q09n.phase='Q09_NEWS' AND q09n.verdict='CONFIG_LOCKED'
          AND q09p.id=NEW.q09_portfolio_work_item_id AND q09p.phase='Q09_PORTFOLIO'
              AND q09p.verdict='PASS_PORTFOLIO'
          AND q10.id=NEW.q10_work_item_id AND q10.phase='Q10' AND q10.verdict='PASS'
    ) THEN RAISE(ABORT, 'QUALIFIED work-item verdict chain invalid') END;
    SELECT CASE WHEN NEW.state='QUALIFIED' AND NOT EXISTS (
        SELECT 1 FROM q09_news_tests t
        WHERE t.work_item_id=NEW.q09_news_work_item_id AND t.verdict='CONFIG_LOCKED'
          AND (SELECT count(*) FROM q09_news_arms a
               WHERE a.q09_news_work_item_id=t.work_item_id)=2
          AND EXISTS (SELECT 1 FROM q09_news_arms a
                      WHERE a.q09_news_work_item_id=t.work_item_id AND a.arm='CONTROL_OFF')
          AND EXISTS (SELECT 1 FROM q09_news_arms a
                      WHERE a.q09_news_work_item_id=t.work_item_id AND a.arm='POLICY_ON')
    ) THEN RAISE(ABORT, 'QUALIFIED q09 two-arm lock missing') END;
    SELECT CASE WHEN NEW.state='QUALIFIED' AND NOT EXISTS (
        SELECT 1 FROM q09_news_tests t
        WHERE t.work_item_id=NEW.q09_news_work_item_id
          AND (SELECT count(DISTINCT seed) FROM q09_news_cells_by_work_item c
               WHERE c.q09_news_work_item_id=t.work_item_id
                  AND c.arm='CONTROL_OFF' AND c.temporal_mode='OFF' AND c.compliance_mode='NONE')=5
          AND (SELECT count(DISTINCT seed) FROM q09_news_cells_by_work_item c
               WHERE c.q09_news_work_item_id=t.work_item_id
                  AND c.arm='POLICY_ON' AND c.temporal_mode=t.chosen_temporal
                  AND c.compliance_mode=t.chosen_compliance)=5
    ) THEN RAISE(ABORT, 'QUALIFIED q09 paired five-seed cells missing') END;
    SELECT CASE WHEN NEW.state='QUALIFIED' AND NOT EXISTS (
        SELECT 1 FROM q09_news_tests t
        WHERE t.work_item_id=NEW.q09_news_work_item_id
          AND t.aggregate_sha256=NEW.q09_news_evidence_sha256
          AND t.baseline_setfile_sha256=NEW.baseline_setfile_sha256
          AND t.ex5_sha256=NEW.ex5_sha256
          AND t.include_closure_sha256=NEW.include_closure_sha256
          AND t.calendar_bundle_id=NEW.calendar_bundle_id
    ) THEN RAISE(ABORT, 'QUALIFIED q09 identity tuple mismatch') END;
    SELECT CASE WHEN NEW.state='QUALIFIED' AND NOT EXISTS (
        SELECT 1 FROM work_item_dependencies dn, work_item_dependencies dp
        WHERE dn.child_work_item_id=NEW.q10_work_item_id AND dn.dependency_role='Q09_NEWS'
          AND dn.parent_work_item_id=NEW.q09_news_work_item_id
          AND dn.parent_evidence_sha256=NEW.q09_news_evidence_sha256
          AND dp.child_work_item_id=NEW.q10_work_item_id AND dp.dependency_role='Q09_PORTFOLIO'
          AND dp.parent_work_item_id=NEW.q09_portfolio_work_item_id
          AND dp.parent_evidence_sha256=NEW.q09_portfolio_evidence_sha256
    ) THEN RAISE(ABORT, 'QUALIFIED Q10 dependencies missing') END;
    SELECT CASE WHEN NEW.state='QUALIFIED' AND NOT EXISTS (
        SELECT 1 FROM work_item_dependencies dn, work_item_dependencies dp
        WHERE dn.child_work_item_id=NEW.q09_news_work_item_id AND dn.dependency_role='Q08_INPUT'
          AND dn.parent_work_item_id=NEW.q08_work_item_id
          AND dp.child_work_item_id=NEW.q09_portfolio_work_item_id AND dp.dependency_role='Q08_INPUT'
          AND dp.parent_work_item_id=NEW.q08_work_item_id
    ) THEN RAISE(ABORT, 'QUALIFIED Q08 convergence missing') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_wic_no_update BEFORE UPDATE ON work_item_contracts
BEGIN SELECT RAISE(ABORT, 'work_item_contracts is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_wic_no_delete BEFORE DELETE ON work_item_contracts
BEGIN SELECT RAISE(ABORT, 'work_item_contracts is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_wid_no_update BEFORE UPDATE ON work_item_dependencies
BEGIN SELECT RAISE(ABORT, 'work_item_dependencies is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_wid_no_delete BEFORE DELETE ON work_item_dependencies
BEGIN SELECT RAISE(ABORT, 'work_item_dependencies is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_ncb_no_update BEFORE UPDATE ON news_calendar_bundles
BEGIN SELECT RAISE(ABORT, 'news_calendar_bundles is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_ncb_no_delete BEFORE DELETE ON news_calendar_bundles
BEGIN SELECT RAISE(ABORT, 'news_calendar_bundles is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_ncbf_no_update BEFORE UPDATE ON news_calendar_bundle_files
BEGIN SELECT RAISE(ABORT, 'news_calendar_bundle_files is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_ncbf_no_delete BEFORE DELETE ON news_calendar_bundle_files
BEGIN SELECT RAISE(ABORT, 'news_calendar_bundle_files is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09t_no_update BEFORE UPDATE ON q09_news_tests
BEGIN SELECT RAISE(ABORT, 'q09_news_tests is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09t_no_delete BEFORE DELETE ON q09_news_tests
BEGIN SELECT RAISE(ABORT, 'q09_news_tests is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09c_no_update BEFORE UPDATE ON q09_news_cells
BEGIN SELECT RAISE(ABORT, 'q09_news_cells is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09c_no_delete BEFORE DELETE ON q09_news_cells
BEGIN SELECT RAISE(ABORT, 'q09_news_cells is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09co_no_update BEFORE UPDATE ON q09_news_cell_occurrences
BEGIN SELECT RAISE(ABORT, 'q09_news_cell_occurrences is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09co_no_delete BEFORE DELETE ON q09_news_cell_occurrences
BEGIN SELECT RAISE(ABORT, 'q09_news_cell_occurrences is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09a_no_update BEFORE UPDATE ON q09_news_arms
BEGIN SELECT RAISE(ABORT, 'q09_news_arms is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09a_no_delete BEFORE DELETE ON q09_news_arms
BEGIN SELECT RAISE(ABORT, 'q09_news_arms is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_cq_no_update BEFORE UPDATE ON candidate_qualifications
BEGIN SELECT RAISE(ABORT, 'candidate_qualifications is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_cq_no_delete BEFORE DELETE ON candidate_qualifications
BEGIN SELECT RAISE(ABORT, 'candidate_qualifications is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09mr_no_update BEFORE UPDATE ON q09_news_migration_runs
BEGIN SELECT RAISE(ABORT, 'q09_news_migration_runs is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_q09mr_no_delete BEFORE DELETE ON q09_news_migration_runs
BEGIN SELECT RAISE(ABORT, 'q09_news_migration_runs is append-only'); END;
"""


ELIGIBILITY_VIEW = r"""
CREATE VIEW portfolio_candidates_eligible AS
WITH latest AS (
    SELECT q.*
    FROM candidate_qualifications q
    WHERE NOT EXISTS (
        SELECT 1 FROM candidate_qualifications newer
        WHERE newer.candidate_lineage_key=q.candidate_lineage_key
          AND (newer.created_at>q.created_at OR
               (newer.created_at=q.created_at AND newer.qualification_id>q.qualification_id))
    )
)
SELECT
    p.ea_id,
    p.symbol,
    p.q11_work_item_id,
    p.state AS historical_candidate_state,
    p.evidence_path AS historical_evidence_path,
    p.first_seen_at,
    p.updated_at,
    q.qualification_id,
    q.candidate_lineage_key,
    q.contract_version,
    q.q08_work_item_id,
    q.q09_news_work_item_id,
    q.q09_portfolio_work_item_id,
    q.q10_work_item_id,
    q.q09_news_evidence_sha256,
    q.q09_portfolio_evidence_sha256,
    q.q10_evidence_sha256,
    q.baseline_setfile_sha256,
    q.q10_setfile_sha256,
    q.ex5_sha256,
    q.include_closure_sha256,
    q.calendar_bundle_id,
    q.evidence_manifest_path,
    q.evidence_manifest_sha256,
    q.created_at AS qualified_at
FROM portfolio_candidates p
JOIN latest q
  ON q.ea_id=p.ea_id
 AND q.symbol=p.symbol
 AND q.legacy_source_work_item_id=p.q11_work_item_id
JOIN work_items q10 ON q10.id=q.q10_work_item_id AND q10.phase='Q10' AND q10.verdict='PASS'
JOIN q09_news_tests nt ON nt.work_item_id=q.q09_news_work_item_id AND nt.verdict='CONFIG_LOCKED'
WHERE q.state='QUALIFIED';
"""


def ensure_schema(conn: sqlite3.Connection, *, commit: bool = True) -> None:
    """Install or validate the additive schema without changing legacy rows.

    ``commit=False`` leaves the ``BEGIN IMMEDIATE`` transaction open so a
    guarded migration can install the schema and append its overlay rows in one
    atomic commit.
    """

    _require_base_schema(conn)
    if conn.in_transaction:
        raise SchemaError("schema installation requires no active transaction")
    existing = conn.execute(
        "SELECT schema_version FROM q09_news_schema_meta WHERE schema_name='q09_news'"
    ).fetchone() if _table_exists(conn, "q09_news_schema_meta") else None
    if existing is not None and int(existing[0]) > SCHEMA_VERSION:
        raise SchemaError(f"database Q09 schema {existing[0]} is newer than supported {SCHEMA_VERSION}")
    installed_at = utc_now().replace("'", "''")
    install_script = (
        "BEGIN IMMEDIATE;\n"
        + DDL
        + "\n"
        + "\nDROP TRIGGER IF EXISTS trg_cq_validate_insert;\n"
        + TRIGGERS
        + "\nDROP VIEW IF EXISTS portfolio_candidates_eligible;\n"
        + ELIGIBILITY_VIEW
        + f"""
        INSERT INTO q09_news_schema_meta(schema_name,schema_version,installed_at)
        VALUES('q09_news',{SCHEMA_VERSION},'{installed_at}')
        ON CONFLICT(schema_name) DO UPDATE SET schema_version=excluded.schema_version
        WHERE q09_news_schema_meta.schema_version < excluded.schema_version;
        """
        + ("\nCOMMIT;\n" if commit else "")
    )
    try:
        conn.executescript(install_script)
    except BaseException:
        conn.rollback()
        raise


@contextmanager
def immediate_transaction(conn: sqlite3.Connection) -> Iterator[None]:
    if conn.in_transaction:
        raise SchemaError("caller must not enter Q09 transaction with an active transaction")
    conn.execute("BEGIN IMMEDIATE")
    try:
        yield
    except BaseException:
        conn.rollback()
        raise
    else:
        conn.commit()


def add_contract(
    conn: sqlite3.Connection,
    *,
    contract_id: str,
    work_item_id: str,
    phase_id: str,
    candidate_lineage_key: str,
    input_manifest_path: str,
    input_manifest_sha256: str,
    supersedes_contract_id: str | None = None,
    contract_version: str = CONTRACT_VERSION,
) -> None:
    conn.execute(
        """
        INSERT INTO work_item_contracts(
            contract_id,work_item_id,phase_id,contract_version,candidate_lineage_key,
            input_manifest_path,input_manifest_sha256,supersedes_contract_id,created_at
        ) VALUES(?,?,?,?,?,?,?,?,?)
        """,
        (
            contract_id,
            work_item_id,
            phase_id,
            contract_version,
            candidate_lineage_key,
            input_manifest_path,
            input_manifest_sha256,
            supersedes_contract_id,
            utc_now(),
        ),
    )


def add_dependency(
    conn: sqlite3.Connection,
    *,
    child_work_item_id: str,
    dependency_role: str,
    parent_work_item_id: str,
    parent_evidence_sha256: str,
    required_verdicts: Sequence[str],
) -> None:
    if not required_verdicts:
        raise SchemaError("required_verdicts must not be empty")
    conn.execute(
        """
        INSERT INTO work_item_dependencies(
            child_work_item_id,dependency_role,parent_work_item_id,
            parent_evidence_sha256,required_verdicts_json,created_at
        ) VALUES(?,?,?,?,?,?)
        """,
        (
            child_work_item_id,
            dependency_role,
            parent_work_item_id,
            parent_evidence_sha256,
            json.dumps(list(required_verdicts), separators=(",", ":")),
            utc_now(),
        ),
    )


def record_calendar_bundle(conn: sqlite3.Connection, manifest: Mapping[str, Any], manifest_path: str) -> None:
    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        raise SchemaError("calendar manifest files are missing")
    created = str(manifest.get("created_at") or utc_now())
    conn.execute(
        """
        INSERT INTO news_calendar_bundles(
            bundle_id,schema_version,manifest_path,manifest_sha256,content_sha256,
            coverage_from_utc,coverage_to_utc,event_from_utc,event_to_utc,row_count,
            publisher_evidence_path,publisher_evidence_sha256,correction_reason,
            approved_by,approved_at,created_at
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            manifest["bundle_id"],
            manifest["schema_version"],
            manifest_path,
            manifest["manifest_sha256"],
            manifest["content_sha256"],
            manifest["coverage_from_utc"],
            manifest["coverage_to_utc"],
            manifest.get("event_from_utc"),
            manifest.get("event_to_utc"),
            int(manifest["row_count"]),
            manifest["publisher_evidence_path"],
            manifest["publisher_evidence_sha256"],
            manifest.get("correction_reason"),
            manifest.get("approved_by"),
            manifest.get("approved_at"),
            created,
        ),
    )
    for item in files:
        conn.execute(
            """
            INSERT INTO news_calendar_bundle_files(
                bundle_id,file_role,relative_path,sha256,size_bytes,row_count,
                event_from_utc,event_to_utc,created_at
            ) VALUES(?,?,?,?,?,?,?,?,?)
            """,
            (
                manifest["bundle_id"],
                item["role"],
                item["relative_path"],
                item["sha256"],
                int(item["size_bytes"]),
                int(item.get("row_count", 0)),
                item.get("event_from_utc"),
                item.get("event_to_utc"),
                created,
            ),
        )


def _verify_adjudication_hash(adjudication: Mapping[str, Any]) -> str:
    embedded = adjudication.get("adjudication_sha256")
    if not isinstance(embedded, str):
        raise SchemaError("adjudication_sha256 missing")
    unsigned = dict(adjudication)
    unsigned.pop("adjudication_sha256", None)
    actual = hashlib.sha256(canonical_json_bytes(unsigned)).hexdigest()
    if actual != embedded:
        raise SchemaError("adjudication_sha256 mismatch")
    return actual


def _assert_persistence_match(
    existing: sqlite3.Row,
    expected: Mapping[str, Any],
    *,
    row_kind: str,
    identity: str,
) -> None:
    """Fail closed when an append-only resume contradicts stored content."""

    divergent_fields = sorted(
        field for field, value in expected.items() if existing[field] != value
    )
    if not divergent_fields:
        return
    report = {
        "row_kind": row_kind,
        "identity": identity,
        "divergent_fields": divergent_fields,
    }
    raise SchemaError(
        "Q09 persistence divergence: "
        + json.dumps(report, sort_keys=True, separators=(",", ":"))
    )


_CELL_DETERMINISTIC_FIELDS = (
    "arm",
    "temporal_mode",
    "compliance_mode",
    "seed",
    "requested_seed",
    "effective_seed",
    "paired_base_identity_sha256",
    "run_identity_sha256",
    "setfile_sha256",
    "selection_metrics_json",
    "holdout_metrics_json",
    "full_metrics_json",
    "q07_seed_stability_pass",
    "flat_at_event_receipt_sha256",
)


def _record_cell_occurrence(
    conn: sqlite3.Connection,
    *,
    work_item_id: str,
    raw: Mapping[str, Any],
    created_at: str,
) -> None:
    """Append one execution's provenance without rewriting canonical cell bytes."""

    provenance = {
        "q09_news_work_item_id": work_item_id,
        "run_identity_sha256": str(raw["run_identity_sha256"]),
        "evidence_sha256": str(raw["evidence_sha256"]),
        "report_sha256": str(raw["report_sha256"]),
        "evidence_path": str(raw.get("evidence_path") or ""),
        "report_path": str(raw.get("report_path") or ""),
    }
    occurrence_identity = hashlib.sha256(canonical_json_bytes(provenance)).hexdigest()
    existing = conn.execute(
        """
        SELECT * FROM q09_news_cell_occurrences
        WHERE occurrence_identity_sha256=?
        """,
        (occurrence_identity,),
    ).fetchone()
    if existing is not None:
        _assert_persistence_match(
            existing,
            provenance,
            row_kind="q09_news_cell_occurrences",
            identity=occurrence_identity,
        )
        return
    conn.execute(
        """
        INSERT INTO q09_news_cell_occurrences(
            occurrence_identity_sha256,q09_news_work_item_id,run_identity_sha256,
            evidence_sha256,report_sha256,evidence_path,report_path,created_at
        ) VALUES(?,?,?,?,?,?,?,?)
        """,
        (occurrence_identity,) + tuple(provenance.values()) + (created_at,),
    )


def record_q09_adjudication(
    conn: sqlite3.Connection,
    *,
    evidence_payload: Mapping[str, Any],
    adjudication: Mapping[str, Any],
    aggregate_path: str,
    aggregate_sha256: str,
) -> bool:
    """Persist or authenticate-resume a Q09 result in one transaction.

    Returns ``True`` when the summary row was new and ``False`` when an
    identical summary already existed. Cell run identities are global sealed
    experiment identities, so an append-only work-item rerun may legitimately
    encounter a cell stored by an earlier work item. Such a cell is reused
    only after every deterministic, verdict-relevant field matches exactly.
    Execution-local artifact hashes and paths are recorded in an append-only
    occurrence ledger and never rewrite the canonical cell row.
    """

    if adjudication.get("schema_version") != ADJUDICATION_SCHEMA_VERSION:
        raise SchemaError("unsupported adjudication schema")
    _verify_adjudication_hash(adjudication)
    aggregate_file = Path(aggregate_path)
    if not aggregate_file.is_file() or sha256_file(aggregate_file) != aggregate_sha256:
        raise SchemaError("Q09 aggregate path/SHA-256 is not authentic")
    try:
        aggregate_document = json.loads(aggregate_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SchemaError(f"Q09 aggregate is unreadable: {exc}") from exc
    if aggregate_document != dict(adjudication):
        raise SchemaError("Q09 aggregate bytes contradict supplied adjudication")
    work_item_id = str(evidence_payload["work_item_id"])
    identities = evidence_payload["identities"]
    windows = evidence_payload["windows"]
    calendar = evidence_payload["calendar_bundle"]
    chosen = adjudication.get("chosen_config") or {}
    verdict = str(adjudication["verdict"])
    if verdict not in CANONICAL_VERDICTS:
        raise SchemaError("non-canonical Q09 verdict")
    created_at = utc_now()
    summary_content = {
        "work_item_id": work_item_id,
        "contract_version": CONTRACT_VERSION,
        "deployment_target": evidence_payload["deployment_target"],
        "target_compliance": (
            adjudication.get("target_compliance")
            or chosen.get("compliance_mode")
            or "NONE"
        ),
        "q08_work_item_id": identities["q08_work_item_id"],
        "calendar_bundle_id": calendar["bundle_id"],
        "paired_base_identity_sha256": identities["paired_base_identity_sha256"],
        "baseline_setfile_sha256": identities["baseline_setfile_sha256"],
        "ex5_sha256": identities["ex5_sha256"],
        "include_closure_sha256": identities["include_closure_sha256"],
        "selection_from_utc": windows["selection_from_utc"],
        "selection_to_utc": windows["selection_to_utc"],
        "holdout_from_utc": windows["holdout_from_utc"],
        "holdout_to_utc": windows["holdout_to_utc"],
        "complete_months": int(windows["complete_months"]),
        "holdout_complete_months": int(windows["holdout_complete_months"]),
        "matrix_scope": adjudication.get("matrix_scope", "7x1_target_compliance"),
        "verdict": verdict,
        "chosen_temporal": (
            chosen.get("temporal_mode") if verdict == "CONFIG_LOCKED" else None
        ),
        "chosen_compliance": (
            chosen.get("compliance_mode") if verdict == "CONFIG_LOCKED" else None
        ),
        "aggregate_path": str(aggregate_path),
        "aggregate_sha256": aggregate_sha256,
    }
    with immediate_transaction(conn):
        existing_summary = conn.execute(
            "SELECT * FROM q09_news_tests WHERE work_item_id=?",
            (work_item_id,),
        ).fetchone()
        summary_inserted = existing_summary is None
        if existing_summary is not None:
            _assert_persistence_match(
                existing_summary,
                summary_content,
                row_kind="q09_news_tests",
                identity=work_item_id,
            )
        else:
            conn.execute(
                """
                INSERT INTO q09_news_tests(
                    work_item_id,contract_version,deployment_target,target_compliance,q08_work_item_id,
                    calendar_bundle_id,paired_base_identity_sha256,baseline_setfile_sha256,ex5_sha256,
                    include_closure_sha256,selection_from_utc,selection_to_utc,holdout_from_utc,
                    holdout_to_utc,complete_months,holdout_complete_months,matrix_scope,verdict,
                    chosen_temporal,chosen_compliance,aggregate_path,aggregate_sha256,created_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                tuple(summary_content.values()) + (created_at,),
            )
        for raw in evidence_payload["cells"]:
            cell_content = {
                "arm": raw["arm"],
                "temporal_mode": raw["temporal_mode"],
                "compliance_mode": raw["compliance_mode"],
                "seed": int(raw["seed"]),
                "requested_seed": int(raw["requested_seed"]),
                "effective_seed": int(raw["effective_seed"]),
                "paired_base_identity_sha256": raw["paired_base_identity_sha256"],
                "run_identity_sha256": raw["run_identity_sha256"],
                "setfile_sha256": raw["setfile_sha256"],
                "evidence_sha256": raw["evidence_sha256"],
                "report_sha256": raw["report_sha256"],
                "selection_metrics_json": json.dumps(
                    raw["selection"], sort_keys=True, separators=(",", ":")
                ),
                "holdout_metrics_json": json.dumps(
                    raw["holdout"], sort_keys=True, separators=(",", ":")
                ),
                "full_metrics_json": json.dumps(
                    raw["full"], sort_keys=True, separators=(",", ":")
                ),
                "q07_seed_stability_pass": int(bool(raw["q07_seed_stability_pass"])),
                "flat_at_event_receipt_sha256": raw.get("flat_at_event_receipt_sha256"),
            }
            run_identity = str(cell_content["run_identity_sha256"])
            deterministic_cell_content = {
                field: cell_content[field] for field in _CELL_DETERMINISTIC_FIELDS
            }
            existing_cell = conn.execute(
                "SELECT * FROM q09_news_cells WHERE run_identity_sha256=?",
                (run_identity,),
            ).fetchone()
            if existing_cell is not None:
                _assert_persistence_match(
                    existing_cell,
                    deterministic_cell_content,
                    row_kind="q09_news_cells",
                    identity=run_identity,
                )
            else:
                conn.execute(
                    """
                    INSERT INTO q09_news_cells(
                        q09_news_work_item_id,arm,temporal_mode,compliance_mode,seed,requested_seed,
                        effective_seed,paired_base_identity_sha256,run_identity_sha256,setfile_sha256,
                        evidence_sha256,report_sha256,selection_metrics_json,holdout_metrics_json,
                        full_metrics_json,q07_seed_stability_pass,flat_at_event_receipt_sha256,created_at
                    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (work_item_id,) + tuple(cell_content.values()) + (created_at,),
                )
            _record_cell_occurrence(
                conn,
                work_item_id=work_item_id,
                raw=raw,
                created_at=created_at,
            )
        for arm in adjudication.get("locked_arms", []):
            arm_content = {
                "arm": arm["arm"],
                "temporal_mode": arm["temporal_mode"],
                "compliance_mode": arm["compliance_mode"],
                "seed_set_json": json.dumps(arm["seed_set"], separators=(",", ":")),
                "setfile_hashes_json": json.dumps(
                    arm["setfile_sha256_by_seed"], sort_keys=True, separators=(",", ":")
                ),
                "evidence_hashes_json": json.dumps(
                    arm["evidence_sha256_by_seed"], sort_keys=True, separators=(",", ":")
                ),
            }
            existing_arm = conn.execute(
                """
                SELECT * FROM q09_news_arms
                WHERE q09_news_work_item_id=? AND arm=?
                """,
                (work_item_id, arm_content["arm"]),
            ).fetchone()
            if existing_arm is not None:
                _assert_persistence_match(
                    existing_arm,
                    arm_content,
                    row_kind="q09_news_arms",
                    identity=f"{work_item_id}:{arm_content['arm']}",
                )
                continue
            conn.execute(
                """
                INSERT INTO q09_news_arms(
                    q09_news_work_item_id,arm,temporal_mode,compliance_mode,seed_set_json,
                    setfile_hashes_json,evidence_hashes_json,created_at
                ) VALUES(?,?,?,?,?,?,?,?)
                """,
                (work_item_id,) + tuple(arm_content.values()) + (created_at,),
            )
        if verdict == "CONFIG_LOCKED":
            arms = conn.execute(
                "SELECT arm,temporal_mode,compliance_mode,seed_set_json FROM q09_news_arms WHERE q09_news_work_item_id=?",
                (work_item_id,),
            ).fetchall()
            if {row[0] for row in arms} != {"CONTROL_OFF", "POLICY_ON"} or len(arms) != 2:
                raise SchemaError("CONFIG_LOCKED requires exactly two bound arms")
            if any(set(json.loads(row[3])) != set(SEEDS) for row in arms):
                raise SchemaError("locked arms do not bind all five canonical seeds")
    return summary_inserted


@dataclass(frozen=True)
class Q10DependencyGate:
    q10_work_item_id: str
    q09_news_work_item_id: str
    q09_portfolio_work_item_id: str
    q09_news_evidence_sha256: str
    q09_portfolio_evidence_sha256: str
    calendar_bundle_id: str
    chosen_temporal: str
    chosen_compliance: str
    baseline_setfile_sha256: str
    ex5_sha256: str
    include_closure_sha256: str


def assert_q10_dependency_gate(conn: sqlite3.Connection, q10_work_item_id: str) -> Q10DependencyGate:
    q10 = conn.execute("SELECT phase FROM work_items WHERE id=?", (q10_work_item_id,)).fetchone()
    if q10 is None or q10[0] != "Q10":
        raise SchemaError("Q10 work item missing or wrong phase")
    rows = conn.execute(
        """
        SELECT dependency_role,parent_work_item_id,parent_evidence_sha256
        FROM work_item_dependencies
        WHERE child_work_item_id=? AND dependency_role IN ('Q09_NEWS','Q09_PORTFOLIO')
        """,
        (q10_work_item_id,),
    ).fetchall()
    dependencies = {row[0]: row for row in rows}
    if set(dependencies) != {"Q09_NEWS", "Q09_PORTFOLIO"}:
        raise SchemaError("Q10 requires bound Q09_NEWS and Q09_PORTFOLIO dependencies")
    news_id = dependencies["Q09_NEWS"][1]
    portfolio_id = dependencies["Q09_PORTFOLIO"][1]
    news = conn.execute(
        """
        SELECT verdict,calendar_bundle_id,chosen_temporal,chosen_compliance,aggregate_sha256,
               baseline_setfile_sha256,ex5_sha256,include_closure_sha256
        FROM q09_news_tests WHERE work_item_id=?
        """,
        (news_id,),
    ).fetchone()
    if news is None or news[0] != "CONFIG_LOCKED":
        raise SchemaError("Q09_NEWS dependency is not CONFIG_LOCKED")
    if news[4] != dependencies["Q09_NEWS"][2]:
        raise SchemaError("Q09_NEWS dependency evidence hash mismatch")
    portfolio = conn.execute(
        "SELECT verdict FROM work_items WHERE id=? AND phase='Q09_PORTFOLIO'", (portfolio_id,)
    ).fetchone()
    if portfolio is None or portfolio[0] != "PASS_PORTFOLIO":
        raise SchemaError("Q09_PORTFOLIO dependency is not PASS_PORTFOLIO")
    if conn.execute(
        "SELECT count(*) FROM q09_news_arms WHERE q09_news_work_item_id=?", (news_id,)
    ).fetchone()[0] != 2:
        raise SchemaError("Q09_NEWS two-arm lock is incomplete")
    control_seed_count = conn.execute(
        """
        SELECT count(DISTINCT seed) FROM q09_news_cells_by_work_item
        WHERE q09_news_work_item_id=? AND arm='CONTROL_OFF'
          AND temporal_mode='OFF' AND compliance_mode='NONE'
        """,
        (news_id,),
    ).fetchone()[0]
    policy_seed_count = conn.execute(
        """
        SELECT count(DISTINCT seed) FROM q09_news_cells_by_work_item
        WHERE q09_news_work_item_id=? AND arm='POLICY_ON'
          AND temporal_mode=? AND compliance_mode=?
        """,
        (news_id, news[2], news[3]),
    ).fetchone()[0]
    if control_seed_count != 5 or policy_seed_count != 5:
        raise SchemaError("Q09_NEWS paired five-seed evidence is incomplete")
    return Q10DependencyGate(
        q10_work_item_id=q10_work_item_id,
        q09_news_work_item_id=news_id,
        q09_portfolio_work_item_id=portfolio_id,
        q09_news_evidence_sha256=dependencies["Q09_NEWS"][2],
        q09_portfolio_evidence_sha256=dependencies["Q09_PORTFOLIO"][2],
        calendar_bundle_id=news[1],
        chosen_temporal=news[2],
        chosen_compliance=news[3],
        baseline_setfile_sha256=news[5],
        ex5_sha256=news[6],
        include_closure_sha256=news[7],
    )


def append_qualification(conn: sqlite3.Connection, values: Mapping[str, Any]) -> None:
    columns = (
        "qualification_id",
        "candidate_lineage_key",
        "ea_id",
        "symbol",
        "contract_version",
        "q08_work_item_id",
        "q09_news_work_item_id",
        "q09_portfolio_work_item_id",
        "q10_work_item_id",
        "q09_news_evidence_sha256",
        "q09_portfolio_evidence_sha256",
        "q10_evidence_sha256",
        "baseline_setfile_sha256",
        "q10_setfile_sha256",
        "ex5_sha256",
        "include_closure_sha256",
        "calendar_bundle_id",
        "legacy_source_work_item_id",
        "state",
        "reason_code",
        "evidence_manifest_path",
        "evidence_manifest_sha256",
        "supersedes_qualification_id",
        "created_at",
    )
    row = [values.get(column) for column in columns]
    if row[-1] is None:
        row[-1] = utc_now()
    conn.execute(
        f"INSERT INTO candidate_qualifications({','.join(columns)}) VALUES({','.join('?' for _ in columns)})",
        row,
    )


def protected_legacy_sha256(conn: sqlite3.Connection) -> str:
    """Fingerprint fields that Q09 migrations are forbidden to rewrite."""

    work_items = [
        dict(zip(("id", "status", "verdict", "evidence_path"), row))
        for row in conn.execute(
            "SELECT id,status,verdict,evidence_path FROM work_items ORDER BY id"
        ).fetchall()
    ]
    candidates = [
        dict(zip(("ea_id", "symbol", "q11_work_item_id", "state", "evidence_path"), row))
        for row in conn.execute(
            """
            SELECT ea_id,symbol,q11_work_item_id,state,evidence_path
            FROM portfolio_candidates ORDER BY ea_id,symbol,q11_work_item_id
            """
        ).fetchall()
    ]
    return hashlib.sha256(canonical_json_bytes({"work_items": work_items, "portfolio_candidates": candidates})).hexdigest()


__all__ = [
    "CONTRACT_VERSION",
    "Q10DependencyGate",
    "SCHEMA_VERSION",
    "SchemaError",
    "add_contract",
    "add_dependency",
    "append_qualification",
    "assert_q10_dependency_gate",
    "ensure_schema",
    "immediate_transaction",
    "protected_legacy_sha256",
    "record_calendar_bundle",
    "record_q09_adjudication",
    "utc_now",
]
