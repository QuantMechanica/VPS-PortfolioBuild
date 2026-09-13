#!/usr/bin/env python3
"""Append-only closure of the ACTIVE Q10_NEWS REVIEW_REQUIRED lane.

`farmctl readjudicate-news-8cell` is the canonical governed instrument for this
lane and is used first, per row.  It accepts only a sealed 8-cell expansion
request whose *current* adjudication is `CONFIG_LOCKED`; everything else it
refuses with a machine-readable `reason`.  This tool closes exactly what that
instrument refuses, and it invents no verdict of its own:

* ``SUCCESSOR_SUPERSESSION`` - a governed readjudication successor already
  exists (``payload_json.$.readjudicated_from_work_item`` points back at the
  source).  The measurement is concluded; only the supersession edge is
  missing.  **No new work item is inserted** - the edge points at the existing
  successor and cites its ``readjudication_provenance.json``.
* ``SEALED_READJUDICATION`` - a sibling ``q09_news_evidence.json`` exists next
  to the row's ``q09_news_tests.aggregate_path``.  The **current**
  ``q09_news_contract.adjudicate`` rule is re-run over those sealed bytes (no
  tester run) and its terminal verdict (``CONFIG_LOCKED`` /
  ``INVALID_EVIDENCE``) becomes the disposition verdict.
* ``EVIDENCE_AGED_OUT`` - the aggregate no longer exists on disk (DL-090 report
  retention).  Unadjudicable: ``INVALID_EVIDENCE`` / ``EVIDENCE_AGED_OUT_DL090``.

One class is deliberately **not** closed.  Rows whose current adjudication is
still ``REVIEW_REQUIRED`` / ``control_or_policy_off_not_qualifiable`` are a
declared open residual: closing them would need either a new measurement or a
change to the gate rule, and gate criteria are ROT.  They are enumerated by
exact id in the plan and re-checked at apply time.

Hard invariants, verified by the tool itself and asserted in the receipt:

* historical ``work_items`` rows are never UPDATEd (``historical_work_item_updates: 0``);
* no verdict, trade stream or evidence file is deleted or overwritten;
* no ``q09_news_tests`` / ``q09_news_cells`` / ``q09_news_arms`` row is written -
  a disposition is an adjudication **receipt**, not a new seal;
* no hold is created or released, nothing is enqueued, no tester runs;
* gate thresholds and ``q09_news_contract`` are untouched.

Dry-run (``plan``) writes a content-addressed plan.  ``apply`` requires that
plan hash, takes an online SQLite backup, re-validates every source row under
``FactoryMutationLock`` inside one ``BEGIN IMMEDIATE`` transaction, appends the
dispositions plus one ``work_item_supersedes`` edge per source, and writes a
receipt.

Evidence: docs/ops/evidence/2026-09-13_q10_news_review_lane_dispositions.md
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
import uuid
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import q09_news_contract as contract  # noqa: E402

try:
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:  # pragma: no cover
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DEFAULT_ARTIFACT_ROOT = Path(
    r"D:\QM\strategy_farm\artifacts\q10_news_review_dispositions_20260913"
)
EVIDENCE_PATH = (
    HERE.parents[1]
    / "docs"
    / "ops"
    / "evidence"
    / "2026-09-13_q10_news_review_lane_dispositions.md"
)

NEWS_PHASE = "Q10_NEWS"
DISPOSITION_ID = "ORCH-Q10NEWS-REVIEW-LANE-CLOSURE-20260913"
PLAN_SCHEMA = "qm.q10-news-review-disposition-plan/v1"
RECEIPT_SCHEMA = "qm.q10-news-review-disposition-receipt/v1"
ROW_SCHEMA = "qm.q10-news-review-disposition-row/v1"
SOURCE_ENCODING = "orchestrator:q10-news-review-lane-closure/v1"
RECORDED_BY = "claude"
DISPOSITION_NAMESPACE = uuid.UUID("7d41c0a6-3b18-4f7e-9c2d-6a0f5b8e21d4")

CLASS_SUCCESSOR = "SUCCESSOR_SUPERSESSION"
CLASS_SEALED = "SEALED_READJUDICATION"
CLASS_AGED_OUT = "EVIDENCE_AGED_OUT"
RESIDUAL_CLASS = "CONTROL_OR_POLICY_OFF_NOT_QUALIFIABLE"

EXPECTED_CLASS_COUNTS = {CLASS_SUCCESSOR: 36, CLASS_SEALED: 46, CLASS_AGED_OUT: 2}
EXPECTED_RESIDUAL_COUNT = 11
EXPECTED_TOTAL = sum(EXPECTED_CLASS_COUNTS.values()) + EXPECTED_RESIDUAL_COUNT

#: The one non-terminal adjudication that stays open, by design.
RESIDUAL_REASON_CODE = "control_or_policy_off_not_qualifiable"
EXPANSION_REASON = "expanded_7x4_matrix_required"

ADJUDICABLE_VERDICTS = ("CONFIG_LOCKED", "INVALID_EVIDENCE")
TAXONOMY_BY_VERDICT = {"CONFIG_LOCKED": "measurement", "INVALID_EVIDENCE": "invalid"}


class DispositionError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_new_json(path: Path, value: dict[str, Any]) -> str:
    if path.exists():
        raise DispositionError(f"output_exists:{path}")
    data = canonical_bytes(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(data)
    temporary.replace(path)
    return sha256_bytes(data)


def connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        connection = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=30)
    else:
        connection = sqlite3.connect(str(db), timeout=30)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout=30000")
    return connection


def disposition_id(source_id: str) -> str:
    return str(uuid.uuid5(DISPOSITION_NAMESPACE, f"{DISPOSITION_ID}|{source_id}"))


def source_identity_sha256(row: sqlite3.Row | dict[str, Any]) -> str:
    return sha256_bytes(canonical_bytes({
        "id": row["id"],
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "phase": row["phase"],
        "status": row["status"],
        "verdict": row["verdict"],
        "created_at": row["created_at"],
        "setfile_path": row["setfile_path"],
        "evidence_path": row["evidence_path"],
    }))


def _select_sources(connection: sqlite3.Connection) -> list[sqlite3.Row]:
    """Every unsuperseded done/REVIEW_REQUIRED row of the ACTIVE news lane."""

    return connection.execute(
        """
        SELECT w.id, w.ea_id, w.symbol, w.phase, w.status, w.verdict,
               w.setfile_path, w.evidence_path, w.created_at,
               w.gate_contract_version,
               t.aggregate_path AS aggregate_path,
               t.aggregate_sha256 AS aggregate_sha256,
               t.matrix_scope AS matrix_scope
        FROM work_items w
        LEFT JOIN q09_news_tests t ON t.work_item_id = w.id
        WHERE w.phase=? AND w.status='done' AND w.verdict='REVIEW_REQUIRED'
          AND NOT EXISTS (
            SELECT 1 FROM work_item_supersedes s WHERE s.work_item_id = w.id
          )
        ORDER BY w.created_at ASC, w.id ASC
        """,
        (NEWS_PHASE,),
    ).fetchall()


def _existing_successor(
    connection: sqlite3.Connection, source_id: str
) -> sqlite3.Row | None:
    """The governed farmctl readjudication successor, if one was already made."""

    return connection.execute(
        """
        SELECT id, status, verdict, evidence_path FROM work_items
        WHERE phase=? AND json_valid(payload_json)=1
          AND json_extract(payload_json, '$.readjudicated_from_work_item')=?
        ORDER BY created_at ASC, id ASC LIMIT 1
        """,
        (NEWS_PHASE, source_id),
    ).fetchone()


def _sealed_evidence_path(aggregate_raw: str) -> Path | None:
    if not aggregate_raw:
        return None
    candidate = Path(aggregate_raw).resolve().parent / "q09_news_evidence.json"
    return candidate if candidate.is_file() else None


def _aggregate_reason_codes(aggregate_raw: str) -> list[str]:
    if not aggregate_raw:
        return []
    path = Path(aggregate_raw)
    if not path.is_file():
        return []
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return []
    if not isinstance(payload, dict):
        return []
    return [str(code) for code in (payload.get("reason_codes") or [])]


def _classify(
    connection: sqlite3.Connection, row: sqlite3.Row
) -> dict[str, Any]:
    """Decide one source row's class from the DB and the evidence on disk only."""

    source_id = str(row["id"])
    aggregate_raw = str(row["aggregate_path"] or "").strip()

    successor = _existing_successor(connection, source_id)
    if successor is not None:
        successor_evidence = str(successor["evidence_path"] or "")
        provenance = (
            Path(successor_evidence).resolve().parent / "readjudication_provenance.json"
            if successor_evidence else None
        )
        return {
            "disposition_class": CLASS_SUCCESSOR,
            "verdict": str(successor["verdict"] or ""),
            "verdict_reason": "Q10_NEWS_GOVERNED_READJUDICATION_SUCCESSOR",
            "successor_work_item_id": str(successor["id"]),
            "successor_status": str(successor["status"] or ""),
            "successor_evidence_path": successor_evidence,
            "successor_provenance_path": (
                str(provenance) if provenance is not None and provenance.is_file() else ""
            ),
            "successor_provenance_sha256": (
                sha256_file(provenance)
                if provenance is not None and provenance.is_file() else ""
            ),
            "aggregate_path": aggregate_raw,
            "aggregate_sha256": str(row["aggregate_sha256"] or ""),
            "matrix_scope": str(row["matrix_scope"] or ""),
        }

    reason_codes = _aggregate_reason_codes(aggregate_raw)
    if RESIDUAL_REASON_CODE in reason_codes:
        return {
            "disposition_class": RESIDUAL_CLASS,
            "verdict": None,
            "verdict_reason": "Q10_NEWS_CURRENT_RULE_STILL_REVIEW_REQUIRED",
            "aggregate_path": aggregate_raw,
            "aggregate_sha256": str(row["aggregate_sha256"] or ""),
            "aggregate_reason_codes": reason_codes,
            "matrix_scope": str(row["matrix_scope"] or ""),
        }

    sealed_path = _sealed_evidence_path(aggregate_raw)
    if sealed_path is not None:
        payload = json.loads(sealed_path.read_text(encoding="utf-8-sig"))
        if not isinstance(payload, dict) or not isinstance(payload.get("cells"), list):
            raise DispositionError(f"sealed_evidence_malformed:{source_id}")
        result = contract.adjudicate(payload)
        verdict = str(result.get("verdict") or "")
        if verdict not in ADJUDICABLE_VERDICTS:
            # The current rule itself is still non-terminal here.  Never invent
            # a closure for it: it stays a declared residual.
            raise DispositionError(
                f"sealed_readjudication_not_terminal:{source_id}:{verdict}"
            )
        return {
            "disposition_class": CLASS_SEALED,
            "verdict": verdict,
            "verdict_reason": f"Q10_NEWS_SEALED_READJUDICATION_{verdict}",
            "sealed_evidence_path": str(sealed_path),
            "sealed_evidence_sha256": sha256_file(sealed_path),
            "sealed_cell_count": len(payload["cells"]),
            "aggregate_path": aggregate_raw,
            "aggregate_sha256": str(row["aggregate_sha256"] or ""),
            "aggregate_reason_codes": reason_codes,
            "matrix_scope": str(row["matrix_scope"] or ""),
            "readjudicated_verdict": verdict,
            "readjudicated_reason_codes": list(result.get("reason_codes") or []),
            "readjudicated_detail": str((result.get("details") or {}).get("error") or ""),
            "readjudicated_chosen_temporal": (result.get("chosen_config") or {}).get(
                "temporal_mode"
            ),
            "readjudicated_chosen_compliance": (result.get("chosen_config") or {}).get(
                "compliance_mode"
            ),
            "adjudication_schema_version": str(result.get("schema_version") or ""),
            "adjudication_sha256": sha256_bytes(contract.canonical_json_bytes(result)),
        }

    return {
        "disposition_class": CLASS_AGED_OUT,
        "verdict": "INVALID_EVIDENCE",
        "verdict_reason": "EVIDENCE_AGED_OUT_DL090",
        "missing_aggregate_path": aggregate_raw,
        "missing_evidence_path": str(row["evidence_path"] or ""),
        "has_q09_news_test_row": bool(aggregate_raw),
    }


def build_plan(db: Path) -> dict[str, Any]:
    if not EVIDENCE_PATH.is_file():
        raise DispositionError(f"evidence_missing:{EVIDENCE_PATH}")
    connection = connect(db, read_only=True)
    try:
        sources = _select_sources(connection)
        if len(sources) != EXPECTED_TOTAL:
            raise DispositionError(f"scope_drift:{len(sources)}!={EXPECTED_TOTAL}")
        targets: list[dict[str, Any]] = []
        residuals: list[dict[str, Any]] = []
        for row in sources:
            source_id = str(row["id"])
            if connection.execute(
                "SELECT 1 FROM work_item_holds WHERE work_item_id=? AND active=1",
                (source_id,),
            ).fetchone():
                raise DispositionError(f"source_has_active_hold:{source_id}")
            classification = _classify(connection, row)
            common = {
                "schema": ROW_SCHEMA,
                "source_work_item_id": source_id,
                "source_identity_sha256": source_identity_sha256(row),
                "ea_id": str(row["ea_id"]),
                "symbol": str(row["symbol"]),
                "setfile_path": str(row["setfile_path"]),
                "created_at": str(row["created_at"]),
                "gate_contract_version": row["gate_contract_version"] or "legacy",
            }
            if classification["disposition_class"] == RESIDUAL_CLASS:
                residuals.append({**common, **classification})
                continue
            if classification["disposition_class"] == CLASS_SUCCESSOR:
                targets.append({**common, **classification,
                                "disposition_work_item_id": None})
                continue
            new_id = disposition_id(source_id)
            if connection.execute(
                "SELECT 1 FROM work_items WHERE id=?", (new_id,)
            ).fetchone():
                raise DispositionError(f"disposition_exists:{new_id}")
            targets.append({**common, **classification,
                            "disposition_work_item_id": new_id})

        counts: dict[str, int] = {}
        verdicts: dict[str, int] = {}
        for target in targets:
            counts[target["disposition_class"]] = counts.get(
                target["disposition_class"], 0
            ) + 1
            verdicts[target["verdict"]] = verdicts.get(target["verdict"], 0) + 1
        if counts != EXPECTED_CLASS_COUNTS:
            raise DispositionError(f"class_distribution_drift:{counts}")
        if len(residuals) != EXPECTED_RESIDUAL_COUNT:
            raise DispositionError(f"residual_count_drift:{len(residuals)}")
    finally:
        connection.close()
    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "database": str(db.resolve()),
        "disposition_id": DISPOSITION_ID,
        "news_phase": NEWS_PHASE,
        "governed_tool_note": (
            "farmctl readjudicate-news-8cell was run per row first; this plan "
            "covers only rows that instrument refuses (farmctl.py:19896-20234)"
        ),
        "evidence_path": str(EVIDENCE_PATH.resolve()),
        "evidence_sha256": sha256_file(EVIDENCE_PATH),
        "contract_module_sha256": sha256_file(Path(contract.__file__).resolve()),
        "class_counts": counts,
        "verdict_counts": verdicts,
        "residual_class": RESIDUAL_CLASS,
        "residual_count": len(residuals),
        "residual_work_item_ids": sorted(
            str(entry["source_work_item_id"]) for entry in residuals
        ),
        "historical_work_item_updates": 0,
        "q09_news_tests_writes": 0,
        "q09_news_cells_writes": 0,
        "holds_touched": 0,
        "enqueued_rows": 0,
        "targets": targets,
        "residuals": residuals,
    }
    plan["targets_sha256"] = sha256_bytes(canonical_bytes(targets))
    plan["residuals_sha256"] = sha256_bytes(canonical_bytes(residuals))
    return plan


def validate_plan(plan: dict[str, Any]) -> None:
    if plan.get("schema") != PLAN_SCHEMA:
        raise DispositionError("wrong_plan_schema")
    if plan.get("disposition_id") != DISPOSITION_ID:
        raise DispositionError("wrong_disposition_id")
    if plan.get("news_phase") != NEWS_PHASE:
        raise DispositionError("wrong_news_phase")
    targets = plan.get("targets") or []
    residuals = plan.get("residuals") or []
    if len(targets) != sum(EXPECTED_CLASS_COUNTS.values()):
        raise DispositionError(f"plan_target_count:{len(targets)}")
    if len(residuals) != EXPECTED_RESIDUAL_COUNT:
        raise DispositionError(f"plan_residual_count:{len(residuals)}")
    if sha256_bytes(canonical_bytes(targets)) != plan.get("targets_sha256"):
        raise DispositionError("plan_target_manifest_invalid")
    if sha256_bytes(canonical_bytes(residuals)) != plan.get("residuals_sha256"):
        raise DispositionError("plan_residual_manifest_invalid")
    if plan.get("class_counts") != EXPECTED_CLASS_COUNTS:
        raise DispositionError("plan_class_distribution_invalid")
    if sha256_file(EVIDENCE_PATH) != plan.get("evidence_sha256"):
        raise DispositionError("evidence_drift")
    if sha256_file(Path(contract.__file__).resolve()) != plan.get(
        "contract_module_sha256"
    ):
        raise DispositionError("adjudication_contract_drift")
    seen_sources: set[str] = set()
    seen_dispositions: set[str] = set()
    for target in targets:
        if target.get("verdict") not in ADJUDICABLE_VERDICTS:
            raise DispositionError(f"plan_verdict_invalid:{target.get('verdict')}")
        if target["source_work_item_id"] in seen_sources:
            raise DispositionError("plan_duplicate_source")
        seen_sources.add(target["source_work_item_id"])
        if target["disposition_class"] == CLASS_SUCCESSOR:
            if target.get("disposition_work_item_id") is not None:
                raise DispositionError("successor_class_must_not_insert_a_row")
            if not str(target.get("successor_work_item_id") or ""):
                raise DispositionError("successor_class_without_successor")
            continue
        new_id = target.get("disposition_work_item_id")
        if new_id in seen_dispositions:
            raise DispositionError("plan_duplicate_disposition")
        if new_id != disposition_id(target["source_work_item_id"]):
            raise DispositionError("plan_disposition_id_not_derived")
        seen_dispositions.add(new_id)
    for residual in residuals:
        if residual.get("disposition_class") != RESIDUAL_CLASS:
            raise DispositionError("plan_residual_class_invalid")
        if residual.get("verdict") is not None:
            raise DispositionError("plan_residual_must_not_carry_a_verdict")
        if residual["source_work_item_id"] in seen_sources:
            raise DispositionError("plan_residual_also_a_target")


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = (
        backup_dir
        / f"farm_state_before_q10_news_review_dispositions_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    source = sqlite3.connect(str(db), timeout=30)
    target = sqlite3.connect(str(destination))
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def _write_row_receipt(
    artifact_root: Path, target: dict[str, Any], *, plan_sha256: str, applied_at: str
) -> tuple[Path, str]:
    """One immutable per-row receipt; becomes the disposition evidence_path."""

    leaf = target.get("disposition_work_item_id") or (
        "supersession_" + str(target["source_work_item_id"])
    )
    directory = artifact_root / str(leaf)
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "disposition.json"
    document = {
        "schema": ROW_SCHEMA,
        "disposition_id": DISPOSITION_ID,
        "applied_at_utc": applied_at,
        "plan_sha256": plan_sha256,
        "evidence_path": str(EVIDENCE_PATH.resolve()),
        "evidence_sha256": sha256_file(EVIDENCE_PATH),
        "historical_work_item_preserved": True,
        "append_only_disposition": True,
        "no_tester_run": True,
        "q09_news_tests_written": False,
        "q09_news_cells_written": False,
        **{k: v for k, v in target.items() if k != "schema"},
    }
    if path.exists():
        existing = sha256_file(path)
        candidate = sha256_bytes(canonical_bytes(document))
        if existing != candidate:
            raise DispositionError(f"row_receipt_conflict:{path}")
        return path, existing
    return path, write_new_json(path, document)


def apply_plan(
    *,
    db: Path,
    plan_path: Path,
    expected_plan_sha256: str,
    receipt_out: Path,
    backup_dir: Path,
    mutation_lock: Path,
    artifact_root: Path,
) -> dict[str, Any]:
    if sha256_file(plan_path) != expected_plan_sha256.lower():
        raise DispositionError("plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan(plan)
    backup_path, backup_sha = backup_database(db, backup_dir)
    applied_at = utc_now()
    plan_sha = expected_plan_sha256.lower()
    residual_ids = sorted(
        str(entry["source_work_item_id"]) for entry in plan["residuals"]
    )

    row_receipts: dict[str, dict[str, str]] = {}
    for target in plan["targets"]:
        path, digest = _write_row_receipt(
            artifact_root, target, plan_sha256=plan_sha, applied_at=applied_at
        )
        row_receipts[target["source_work_item_id"]] = {
            "path": str(path),
            "sha256": digest,
        }

    inserted: list[dict[str, Any]] = []
    with FactoryMutationLock(mutation_lock, owner=f"q10-news-review-closure:{DISPOSITION_ID}"):
        connection = connect(db, read_only=False)
        try:
            connection.execute("BEGIN IMMEDIATE")
            open_before = int(connection.execute(
                "SELECT COUNT(*) FROM work_items "
                "WHERE phase=? AND status='done' AND verdict='REVIEW_REQUIRED'",
                (NEWS_PHASE,),
            ).fetchone()[0])

            for target in plan["targets"]:
                source_id = target["source_work_item_id"]
                source = connection.execute(
                    "SELECT * FROM work_items WHERE id=?", (source_id,)
                ).fetchone()
                if source is None:
                    raise DispositionError(f"source_vanished:{source_id}")
                if source_identity_sha256(source) != target["source_identity_sha256"]:
                    raise DispositionError(f"source_identity_drift:{source_id}")
                new_id = target.get("disposition_work_item_id")
                if new_id and connection.execute(
                    "SELECT 1 FROM work_items WHERE id=?", (new_id,)
                ).fetchone():
                    raise DispositionError(f"disposition_raced:{new_id}")
                if connection.execute(
                    "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?",
                    (source_id,),
                ).fetchone():
                    raise DispositionError(f"supersession_raced:{source_id}")
                if connection.execute(
                    "SELECT 1 FROM work_item_holds WHERE work_item_id=? AND active=1",
                    (source_id,),
                ).fetchone():
                    raise DispositionError(f"hold_raced:{source_id}")

            for target in plan["targets"]:
                source_id = target["source_work_item_id"]
                verdict = target["verdict"]
                receipt = row_receipts[source_id]
                is_successor_class = target["disposition_class"] == CLASS_SUCCESSOR
                superseded_by = (
                    target["successor_work_item_id"]
                    if is_successor_class
                    else target["disposition_work_item_id"]
                )
                if not is_successor_class:
                    payload = {
                        "append_only_disposition": True,
                        "disposition": "ADJUDICATION_RECEIPT",
                        "disposition_class": target["disposition_class"],
                        "disposition_id": DISPOSITION_ID,
                        "historical_evidence_preserved": True,
                        "historical_verdicts_preserved": True,
                        "historical_work_item_updates": 0,
                        "no_tester_run": True,
                        "plan_sha256": plan_sha,
                        "q09_news_seal_written": False,
                        "source_work_item_id": source_id,
                        "source_identity_sha256": target["source_identity_sha256"],
                        "source_phase": NEWS_PHASE,
                        "disposition_receipt_path": receipt["path"],
                        "disposition_receipt_sha256": receipt["sha256"],
                        "verdict_reason": target["verdict_reason"],
                        "verdict_taxonomy": TAXONOMY_BY_VERDICT[verdict],
                    }
                    for key in (
                        "sealed_evidence_path", "sealed_evidence_sha256",
                        "sealed_cell_count", "aggregate_path", "aggregate_sha256",
                        "aggregate_reason_codes", "matrix_scope",
                        "readjudicated_reason_codes", "readjudicated_detail",
                        "readjudicated_chosen_temporal",
                        "readjudicated_chosen_compliance",
                        "adjudication_schema_version", "adjudication_sha256",
                        "missing_evidence_path", "missing_aggregate_path",
                    ):
                        if key in target and target[key] not in (None, "", []):
                            payload[key] = target[key]
                    connection.execute(
                        """
                        INSERT INTO work_items(
                            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                            attempt_count,parent_task_id,evidence_path,claimed_by,
                            payload_json,created_at,updated_at,verdict_taxonomy_stored,
                            clean_status_stored,gate_contract_version,verdict_taxonomy,
                            sh3_enforced
                        ) VALUES(?,'disposition',?,?,?,?,'done',?,0,NULL,?,NULL,?,?,?,?,'done',?,?,0)
                        """,
                        (
                            target["disposition_work_item_id"],
                            NEWS_PHASE,
                            target["ea_id"],
                            target["symbol"],
                            target["setfile_path"],
                            verdict,
                            receipt["path"],
                            json.dumps(payload, sort_keys=True),
                            applied_at,
                            applied_at,
                            TAXONOMY_BY_VERDICT[verdict],
                            target["gate_contract_version"],
                            TAXONOMY_BY_VERDICT[verdict],
                        ),
                    )
                reason = (
                    f"{target['disposition_class']} -> {verdict} "
                    f"({target['verdict_reason']}); {DISPOSITION_ID}; "
                    "append-only adjudication receipt, historical row unchanged"
                )
                connection.execute(
                    """
                    INSERT INTO work_item_supersedes(
                        work_item_id,superseded_by_work_item_id,reason,source_encoding,
                        evidence_path,recorded_by,recorded_at
                    ) VALUES(?,?,?,?,?,?,?)
                    """,
                    (
                        source_id, superseded_by, reason, SOURCE_ENCODING,
                        receipt["path"], RECORDED_BY, applied_at,
                    ),
                )
                connection.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES(?,?,?,?,?)",
                    (
                        applied_at, "work_item", source_id,
                        "q10_news_review_lane_disposition_appended",
                        json.dumps({
                            "disposition_id": DISPOSITION_ID,
                            "disposition_class": target["disposition_class"],
                            "superseded_by_work_item_id": superseded_by,
                            "verdict": verdict,
                            "verdict_reason": target["verdict_reason"],
                            "receipt_sha256": receipt["sha256"],
                        }, sort_keys=True),
                    ),
                )
                inserted.append({
                    "source_work_item_id": source_id,
                    "disposition_work_item_id": target.get("disposition_work_item_id"),
                    "superseded_by_work_item_id": superseded_by,
                    "disposition_class": target["disposition_class"],
                    "verdict": verdict,
                    "verdict_reason": target["verdict_reason"],
                    "receipt_path": receipt["path"],
                })

            open_after = int(connection.execute(
                "SELECT COUNT(*) FROM work_items "
                "WHERE phase=? AND status='done' AND verdict='REVIEW_REQUIRED'",
                (NEWS_PHASE,),
            ).fetchone()[0])
            if open_after != open_before:
                raise DispositionError("historical_rows_were_modified")
            remaining = [
                str(row[0]) for row in connection.execute(
                    """
                    SELECT w.id FROM work_items w
                    WHERE w.phase=? AND w.status='done' AND w.verdict='REVIEW_REQUIRED'
                      AND NOT EXISTS (
                        SELECT 1 FROM work_item_supersedes s WHERE s.work_item_id=w.id
                      )
                    ORDER BY w.id
                    """,
                    (NEWS_PHASE,),
                ).fetchall()
            ]
            if sorted(remaining) != residual_ids:
                raise DispositionError(
                    f"unexpected_open_reviews:{sorted(set(remaining) ^ set(residual_ids))}"
                )
            seal_rows = int(connection.execute(
                "SELECT COUNT(*) FROM q09_news_tests WHERE work_item_id IN "
                "(SELECT id FROM work_items WHERE kind='disposition' AND phase=?)",
                (NEWS_PHASE,),
            ).fetchone()[0])
            if seal_rows != 0:
                raise DispositionError("disposition_wrote_a_q09_news_seal")
            connection.commit()
            quick_check = connection.execute("PRAGMA quick_check").fetchone()[0]
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    class_counts: dict[str, int] = {}
    verdict_counts: dict[str, int] = {}
    for entry in inserted:
        class_counts[entry["disposition_class"]] = class_counts.get(
            entry["disposition_class"], 0
        ) + 1
        verdict_counts[entry["verdict"]] = verdict_counts.get(entry["verdict"], 0) + 1

    receipt_document = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": applied_at,
        "disposition_id": DISPOSITION_ID,
        "news_phase": NEWS_PHASE,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": plan_sha,
        "evidence_path": str(EVIDENCE_PATH.resolve()),
        "evidence_sha256": sha256_file(EVIDENCE_PATH),
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "artifact_root": str(artifact_root.resolve()),
        "closed_count": len(inserted),
        "class_counts": class_counts,
        "verdict_counts": verdict_counts,
        "residual_class": RESIDUAL_CLASS,
        "residual_count": len(residual_ids),
        "residual_work_item_ids": residual_ids,
        "open_reviews_total": open_before,
        "open_reviews_after_unsuperseded": len(residual_ids),
        "historical_work_item_updates": 0,
        "q09_news_tests_writes": 0,
        "q09_news_cells_writes": 0,
        "holds_touched": 0,
        "enqueued_rows": 0,
        "quick_check": quick_check,
        "closed": inserted,
    }
    receipt_document["receipt_sha256"] = write_new_json(receipt_out, receipt_document)
    return receipt_document


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "apply"))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    args = parser.parse_args()
    try:
        if args.mode == "plan":
            if args.plan_out is None:
                raise DispositionError("plan_out_required")
            plan = build_plan(args.db)
            plan_sha = write_new_json(args.plan_out, plan)
            result = {
                "status": "ok",
                "mode": "plan",
                "plan_path": str(args.plan_out.resolve()),
                "plan_sha256": plan_sha,
                "target_count": len(plan["targets"]),
                "class_counts": plan["class_counts"],
                "verdict_counts": plan["verdict_counts"],
                "residual_count": plan["residual_count"],
                "residual_work_item_ids": plan["residual_work_item_ids"],
            }
        else:
            if args.plan is None or not args.expected_plan_sha256 or args.receipt_out is None:
                raise DispositionError("plan_hash_and_receipt_required")
            result = apply_plan(
                db=args.db,
                plan_path=args.plan,
                expected_plan_sha256=args.expected_plan_sha256,
                receipt_out=args.receipt_out,
                backup_dir=args.backup_dir,
                mutation_lock=args.mutation_lock,
                artifact_root=args.artifact_root,
            )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (DispositionError, OSError, sqlite3.Error, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps(
            {"status": "aborted", "reason": f"{type(exc).__name__}: {exc}"}, indent=2
        ))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
