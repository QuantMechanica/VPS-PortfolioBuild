#!/usr/bin/env python3
"""Classify Q02 summary-missing failures and append approved INVALID dispositions.

Census rank 1 (docs/ops/evidence/2026-07-27_factory_loose_ends_census.md): a single
`summary_missing_retries_exhausted` label carried under `verdict=INFRA_FAIL` dominates
every factory failure statistic (43,736 Q02 rows on 2026-07-27, 68% of all Q02 rows).
It conflates a terminal-side fault, a deterministic EA/build defect, and a genuine
transient into one bucket, so historical evidence production overwhelms strategy
measurement in every count.

This tool splits that population into disjoint, ACTIONABLE classes using ONLY row-bound
evidence — each row's own payload, its `(ea_id, symbol)` key resolved against the same
work_items table, and its current on-disk set file / registry status. For ~99% of these
historical rows the run log and report root have been purged by the log/cache pruners
(measured 1.1% logs, 1.2% report roots survive), so the DB join is the only surviving
evidence; the forward classifier in farmctl.classify_summary_missing_run reads the fresh
log instead, and both emit the SAME action vocabulary (farmctl.SM_CLASS_*).

Disjoint cascade (first match wins), measured 2026-07-27:

    LOG_BOMB          ~0  DETERMINISTIC  genuine journal-flood marker ONLY (verdict_reason=
                          LOG_BOMB / reason_classes / log_bomb_journal_*). The former bare
                          attempt_count>=99 trigger was removed 2026-07-27: it mislabelled
                          4,236 summary-missing transport rows carrying NO genuine marker,
                          which now re-bucket to SUPERSEDED / NEVER_WORKED / IN_FLIGHT below
                          (docs/ops/evidence/2026-07-27_logbomb_family_diagnosis.md).
    SUPERSEDED     26651  SUPERSEDED     the (ea,symbol) pair already has a real Q02 verdict
    INPUT_MISSING    181  DETERMINISTIC  set file absent or EA registry status != active
    IN_FLIGHT       4517  IN_FLIGHT      the pair still has a pending/active successor
    TRANSIENT_TOKEN   33  TRANSIENT      verdict_reason carries an explicit transient token
    NEVER_WORKED    8118  DETERMINISTIC  pair has ONLY ever INFRA_FAILed (the "119/119" cohort)

WHAT THIS TOOL WRITES: only three payload keys — `failure_class` (action axis),
`failure_subclass` (specific cause) and `failure_class_evidence`. It does NOT touch
`verdict`, `status`, `attempt_count`, `evidence_path`, `claimed_by` or `updated_at`, and
it NEVER requeues a row. Reclassification is therefore invisible to the claim path and
has zero throughput/capacity impact — it only makes the honest cause visible to reason
histograms, dashboards and the new health detectors. Promoting the DETERMINISTIC class
from INFRA_FAIL to the non-retryable INVALID remains OWNER-gated.  The bounded
``OWNER-DEC-STRANDED-182`` mode appends one INVALID disposition per reviewed pair and
never updates a historical verdict row.

Safety (mirrors backfill_verdict_reason.py, ratified WP-3 pattern):
  * --dry-run is the DEFAULT. Nothing is written without --apply.
  * --apply writes a timestamped reversible snapshot (id + exact prior payload_json)
    under D:/QM/reports/state/ BEFORE the first row is touched.
  * Each UPDATE is guarded on the EXACT expected prior payload_json, so a row a worker
    changed out from under the snapshot is skipped, never clobbered.
  * --revert <snapshot> restores every row to its exact prior payload_json.
  * Inspection is read-only (mode=ro). Apply commits in bounded batches so it never
    holds one long write lock against the live fleet.

The apply path should still run in a quiescent window; the guard makes a concurrent
write safe (skip, never clobber) but a long contended write wastes claim-lock time.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import sqlite3
import sys
import uuid
import hashlib
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from factory_mutation_lock import FactoryMutationLock

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REGISTRY = Path(r"C:\QM\repo\framework\registry\ea_id_registry.csv")
SNAPSHOT_DIR = Path(r"D:\QM\reports\state")
OWNER_DECISION_ID = "OWNER-DEC-STRANDED-182"
OWNER_DECISION_PATH = Path("decisions/2026-08-23_owner_decisions_evening_batch_2.md")
OWNER_EXPECTED_PAIR_COUNT = 182
MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DISPOSITION_NAMESPACE = uuid.UUID("5c0d8085-9ef1-4dca-95f6-49d18c9920e7")

STRANDED_COHORT_SQL = """
SELECT ea_id, symbol
FROM work_items
WHERE phase IN ('Q02','P2')
GROUP BY ea_id, symbol
HAVING SUM(CASE WHEN status IN ('done','failed') AND verdict IS NOT NULL
                 AND TRIM(verdict)<>'' AND UPPER(verdict)<>'INFRA_FAIL'
                THEN 1 ELSE 0 END)=0
   AND SUM(CASE WHEN status IN ('pending','active') THEN 1 ELSE 0 END)=0
   AND SUM(CASE WHEN UPPER(verdict)='INFRA_FAIL' THEN 1 ELSE 0 END)>=12
""".strip()

# The graveyard tag the terminal worker stamps at summary-missing exhaustion.
GRAVEYARD_TAG = "summary_missing_retries_exhausted"

# Action classes — kept identical to farmctl.SM_CLASS_* so the historical reclassifier
# and the forward classifier can never disagree on vocabulary.
CLASS_DETERMINISTIC = "DETERMINISTIC_NO_SUMMARY"
CLASS_TRANSIENT = "TRANSIENT"
CLASS_SUPERSEDED = "SUPERSEDED"
CLASS_IN_FLIGHT = "IN_FLIGHT"

# NOTE: a bare attempt_count>=99 was formerly treated as log_bomb here. It is NOT
# log-bomb-specific (the older exhaustion/poison paths stamped 99 for ~8 different causes),
# and it mislabelled 4,236 summary-missing transport rows that carried no genuine journal
# marker. _has_log_bomb now requires a genuine kill marker; the sentinel is gone.
# See docs/ops/evidence/2026-07-27_logbomb_family_diagnosis.md.

# Explicit transient run_smoke tokens (kept in sync with farmctl.SM_TRANSIENT_TOKENS;
# INCOMPLETE_RUNS is intentionally excluded — it discriminates nothing).
TRANSIENT_TOKENS = (
    "ACTIVE_TIMEOUT", "NO_HISTORY", "METATESTER_HUNG", "NO_REAL_TICKS", "TIMEOUT",
    "LAUNCH_FAULT",
)


def _connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
            + "\n").encode("utf-8")


def _write_new_json(path: Path, value: Any) -> str:
    path = path.resolve(strict=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise RuntimeError(f"refusing to overwrite receipt/plan: {path}")
    raw = _canonical_bytes(value)
    path.write_bytes(raw)
    return _sha256_bytes(raw)


def _ea_int(ea_id: Any) -> int | None:
    m = re.fullmatch(r"(?:QM5_)?(\d+)", str(ea_id).strip())
    return int(m.group(1)) if m else None


def _load_registry_status(path: Path) -> dict[int, str]:
    reg: dict[int, str] = {}
    try:
        fh = path.open(encoding="utf-8-sig")
    except OSError:
        return reg
    with fh:
        for row in csv.DictReader(fh):
            num = _ea_int(row.get("ea_id") or "")
            if num is not None:
                reg[num] = (row.get("status") or "").strip().lower()
    return reg


def _has_log_bomb(payload: dict[str, Any], attempt_count: int) -> bool:
    # A genuine journal-flood kill stamps a distinctive record (terminal_worker.py:2595-2633):
    # verdict_reason='LOG_BOMB', reason_classes+=['LOG_BOMB'], log_bomb_journal_gb=<size>.
    # attempt_count>=99 ALONE is NOT one of those markers, so it is deliberately no longer a
    # trigger (see the census note above): require a genuine marker and let every other
    # summary-missing row fall through to the honest SUPERSEDED / never_worked / IN_FLIGHT
    # rules. `attempt_count` is retained in the signature for call-site parity only.
    if str(payload.get("verdict_reason") or "").upper() == "LOG_BOMB":
        return True
    if any(str(x).upper() == "LOG_BOMB" for x in (payload.get("reason_classes") or [])):
        return True
    return any(str(k).startswith("log_bomb_journal") for k in payload)


def _classify_row(
    payload: dict[str, Any],
    attempt_count: int,
    ea_id: str,
    symbol: str,
    setfile_path: str | None,
    *,
    resolved_pairs: set[tuple[str, str]],
    open_pairs: set[tuple[str, str]],
    registry_status: dict[int, str],
    setfile_cache: dict[str, bool],
) -> tuple[str, str]:
    """Return (failure_class, failure_subclass) for one graveyard row. Disjoint cascade."""
    if _has_log_bomb(payload, attempt_count):
        return CLASS_DETERMINISTIC, "log_bomb"
    key = (ea_id, symbol)
    if key in resolved_pairs:
        return CLASS_SUPERSEDED, "pair_has_verdict"
    status = registry_status.get(_ea_int(ea_id))
    sf_ok = False
    if setfile_path:
        if setfile_path not in setfile_cache:
            setfile_cache[setfile_path] = os.path.isfile(setfile_path)
        sf_ok = setfile_cache[setfile_path]
    if status != "active" or not sf_ok:
        return CLASS_DETERMINISTIC, "input_missing"
    if key in open_pairs:
        return CLASS_IN_FLIGHT, "pair_open"
    vr = str(payload.get("verdict_reason") or "").upper()
    if any(tok in vr for tok in TRANSIENT_TOKENS):
        return CLASS_TRANSIENT, "transient_token"
    return CLASS_DETERMINISTIC, "never_worked"


def _build_pair_maps(conn: sqlite3.Connection, phase: str) -> tuple[set, set]:
    """resolved_pairs = pair has any phase verdict that is not NULL and not INFRA_FAIL;
    open_pairs = pair has a pending/active row in the phase."""
    resolved: set[tuple[str, str]] = set()
    open_pairs: set[tuple[str, str]] = set()
    for r in conn.execute(
        "SELECT ea_id, symbol, status, verdict FROM work_items WHERE phase=?", (phase,)
    ):
        key = (r["ea_id"], r["symbol"])
        if r["verdict"] and r["verdict"] != "INFRA_FAIL":
            resolved.add(key)
        if r["status"] in ("pending", "active"):
            open_pairs.add(key)
    return resolved, open_pairs


def _iter_graveyard(conn: sqlite3.Connection, phase: str):
    sql = (
        "SELECT id, ea_id, symbol, attempt_count, setfile_path, payload_json "
        "FROM work_items WHERE phase=? AND verdict='INFRA_FAIL' "
        "AND json_extract(payload_json, '$.final_failure')=?"
    )
    for row in conn.execute(sql, (phase, GRAVEYARD_TAG)):
        text = row["payload_json"]
        if not text:
            continue
        try:
            payload = json.loads(text)
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(payload, dict):
            continue
        yield row, payload, text


def _plan(db: Path, phase: str, registry: Path, limit: int | None) -> dict[str, Any]:
    registry_status = _load_registry_status(registry)
    conn = _connect_ro(db)
    try:
        resolved, open_pairs = _build_pair_maps(conn, phase)
        setfile_cache: dict[str, bool] = {}
        by_class: Counter = Counter()
        by_subclass: Counter = Counter()
        already: Counter = Counter()
        rows: list[dict[str, Any]] = []
        for row, payload, text in _iter_graveyard(conn, phase):
            cls, sub = _classify_row(
                payload, int(row["attempt_count"] or 0), row["ea_id"], row["symbol"],
                row["setfile_path"], resolved_pairs=resolved, open_pairs=open_pairs,
                registry_status=registry_status, setfile_cache=setfile_cache,
            )
            by_class[cls] += 1
            by_subclass[sub] += 1
            existing = payload.get("failure_class")
            needs_write = existing != cls or payload.get("failure_subclass") != sub
            if isinstance(existing, str) and existing:
                already[existing] += 1
            if needs_write:
                rows.append({
                    "id": row["id"], "prior_text": text, "payload": payload,
                    "failure_class": cls, "failure_subclass": sub,
                })
                if limit is not None and len(rows) >= limit:
                    break
    finally:
        conn.close()
    return {
        "tool": "classify_summary_missing.py",
        "db": str(db),
        "phase": phase,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "population": sum(by_class.values()),
        "by_class": dict(by_class),
        "by_subclass": dict(by_subclass),
        "already_classified": dict(already),
        "rows_needing_write": len(rows),
        "rows": rows,
    }


def _owner_disposition_plan(db: Path, expected_count: int) -> dict[str, Any]:
    """Freeze the exact 2026-08-22 census semantics and reviewed pair list."""
    conn = _connect_ro(db)
    try:
        rows = conn.execute(
            f"""
            WITH cohort AS ({STRANDED_COHORT_SQL}), ranked AS (
              SELECT w.*,
                     ROW_NUMBER() OVER (
                       PARTITION BY w.ea_id,w.symbol
                       ORDER BY w.updated_at DESC,w.created_at ASC,w.id ASC
                     ) AS rn
              FROM work_items w JOIN cohort c USING(ea_id,symbol)
              WHERE w.phase IN ('Q02','P2')
            )
            SELECT * FROM ranked
            WHERE rn=1
              AND json_extract(payload_json,'$.failure_class')=?
            ORDER BY ea_id,symbol,id
            """,
            (CLASS_DETERMINISTIC,),
        ).fetchall()
        targets: list[dict[str, Any]] = []
        for row in rows:
            prior_text = str(row["payload_json"] or "")
            payload = json.loads(prior_text)
            disposition_id = str(uuid.uuid5(
                DISPOSITION_NAMESPACE,
                f"{OWNER_DECISION_ID}:{row['ea_id']}:{row['symbol']}:{row['id']}",
            ))
            targets.append({
                "source_work_item_id": str(row["id"]),
                "disposition_work_item_id": disposition_id,
                "ea_id": str(row["ea_id"]),
                "symbol": str(row["symbol"]),
                "phase": str(row["phase"]),
                "kind": str(row["kind"]),
                "setfile_path": str(row["setfile_path"]),
                "source_updated_at": str(row["updated_at"]),
                "source_payload_sha256": _sha256_bytes(prior_text.encode("utf-8")),
                "failure_class": str(payload.get("failure_class")),
                "failure_subclass": str(payload.get("failure_subclass") or ""),
                "source_evidence_path": row["evidence_path"],
                "gate_contract_version": row["gate_contract_version"],
            })
        if len(targets) != expected_count:
            raise RuntimeError(
                f"OWNER scope mismatch: expected {expected_count} deterministic stranded "
                f"pairs, found {len(targets)}"
            )
        if targets:
            duplicate_ids = conn.execute(
                "SELECT COUNT(*) FROM work_items WHERE id IN (%s)" %
                ",".join("?" for _ in targets),
                [row["disposition_work_item_id"] for row in targets],
            ).fetchone()[0]
            if duplicate_ids:
                raise RuntimeError(
                    f"{duplicate_ids} deterministic disposition ids already exist"
                )
        decision_raw = OWNER_DECISION_PATH.read_bytes()
        if (OWNER_DECISION_ID.encode() not in decision_raw
                or "alle drei genehmigt".encode() not in decision_raw):
            raise RuntimeError("OWNER decision artifact does not contain the approval")
        plan = {
            "schema": "qm.summary-missing-stranded-invalid-plan/v1",
            "mode": "dry_run",
            "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
            "database": str(db.resolve()),
            "owner_decision": {
                "id": OWNER_DECISION_ID,
                "path": str(OWNER_DECISION_PATH.resolve()),
                "sha256": _sha256_bytes(decision_raw),
            },
            "selection": {
                "expected_pair_count": expected_count,
                "actual_pair_count": len(targets),
                "cohort_sql": STRANDED_COHORT_SQL,
                "tie_break": "updated_at DESC, created_at ASC, id ASC",
            },
            "mutation": "APPEND_INVALID_WORK_ITEM_ONLY",
            "historical_verdict_rows_updated": 0,
            "targets": targets,
        }
        plan["targets_sha256"] = _sha256_bytes(_canonical_bytes(targets))
        return plan
    finally:
        conn.close()


def _apply_owner_dispositions(
    db: Path, plan: dict[str, Any], expected_plan_sha256: str, receipt_out: Path
) -> dict[str, Any]:
    if plan.get("schema") != "qm.summary-missing-stranded-invalid-plan/v1":
        raise RuntimeError("unsupported OWNER disposition plan schema")
    if plan.get("owner_decision", {}).get("id") != OWNER_DECISION_ID:
        raise RuntimeError("wrong OWNER decision in disposition plan")
    if len(plan.get("targets") or []) != OWNER_EXPECTED_PAIR_COUNT:
        raise RuntimeError("disposition plan is not the exact approved 182-pair scope")
    if _sha256_bytes(_canonical_bytes(plan["targets"])) != plan.get("targets_sha256"):
        raise RuntimeError("disposition target list hash mismatch")

    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    inserted: list[str] = []
    with FactoryMutationLock(
        MUTATION_LOCK, owner="classify_summary_missing.owner_dec_stranded_182"
    ):
        conn = sqlite3.connect(str(db), timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            for target in plan["targets"]:
                source = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (target["source_work_item_id"],)
                ).fetchone()
                if source is None:
                    raise RuntimeError(f"source row vanished: {target['source_work_item_id']}")
                source_payload = str(source["payload_json"] or "")
                if _sha256_bytes(source_payload.encode("utf-8")) != target["source_payload_sha256"]:
                    raise RuntimeError(f"source payload drifted: {source['id']}")
                if source["verdict"] != "INFRA_FAIL" or source["status"] not in ("done", "failed"):
                    raise RuntimeError(f"source terminal identity drifted: {source['id']}")
                pair = conn.execute(
                    f"SELECT 1 FROM ({STRANDED_COHORT_SQL}) WHERE ea_id=? AND symbol=?",
                    (target["ea_id"], target["symbol"]),
                ).fetchone()
                if pair is None:
                    raise RuntimeError(
                        f"pair left stranded cohort: {target['ea_id']}/{target['symbol']}"
                    )
                payload = {
                    "disposition_only": True,
                    "owner_decision_id": OWNER_DECISION_ID,
                    "owner_decision_sha256": plan["owner_decision"]["sha256"],
                    "source_work_item_id": source["id"],
                    "source_payload_sha256": target["source_payload_sha256"],
                    "failure_class": CLASS_DETERMINISTIC,
                    "failure_subclass": target["failure_subclass"],
                    "verdict_reason": "OWNER_APPROVED_DETERMINISTIC_NO_SUMMARY_INVALID",
                    "historical_infra_rows_preserved": True,
                    "backtest_enqueued": False,
                    "plan_sha256": expected_plan_sha256,
                }
                evidence = target.get("source_evidence_path") or (
                    f"EVIDENCE_UNAVAILABLE:{OWNER_DECISION_ID}:{source['id']}"
                )
                conn.execute(
                    """
                    INSERT INTO work_items(
                      id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                      parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
                      verdict_taxonomy_stored,clean_status_stored,gate_contract_version
                    ) VALUES(?,?,?,?,?,?,'failed','INVALID',0,NULL,?,NULL,?,?,?,
                             'invalid','failed',?)
                    """,
                    (
                        target["disposition_work_item_id"], target["kind"], target["phase"],
                        target["ea_id"], target["symbol"], target["setfile_path"], evidence,
                        json.dumps(payload, sort_keys=True, separators=(",", ":")), now, now,
                        target.get("gate_contract_version") or "legacy",
                    ),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES(?,?,?,?,?)",
                    (now, "work_item", target["disposition_work_item_id"],
                     "owner_stranded_summary_missing_invalid_appended",
                     json.dumps(payload, sort_keys=True, separators=(",", ":"))),
                )
                inserted.append(target["disposition_work_item_id"])
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()
    receipt = {
        "schema": "qm.summary-missing-stranded-invalid-receipt/v1",
        "applied_at_utc": now,
        "database": str(db.resolve()),
        "owner_decision_id": OWNER_DECISION_ID,
        "plan_sha256": expected_plan_sha256,
        "inserted_count": len(inserted),
        "inserted_work_item_ids": inserted,
        "historical_verdict_rows_updated": 0,
        "rollback": "append an OWNER-authorized superseding disposition; never delete history",
    }
    receipt_sha = _write_new_json(receipt_out, receipt)
    return {
        **receipt,
        "receipt_path": str(receipt_out.resolve()),
        "receipt_sha256": receipt_sha,
    }


def _print_plan(plan: dict[str, Any]) -> None:
    print(f"summary-missing reclassification  (phase={plan['phase']})")
    print(f"population (verdict=INFRA_FAIL, final_failure={GRAVEYARD_TAG!r}): {plan['population']}")
    print("\naction class:")
    for k, n in sorted(plan["by_class"].items(), key=lambda kv: -kv[1]):
        pct = 100 * n / plan["population"] if plan["population"] else 0
        print(f"  {k:24} {n:7} ({pct:.1f}%)")
    print("\nsubclass:")
    for k, n in sorted(plan["by_subclass"].items(), key=lambda kv: -kv[1]):
        print(f"  {k:20} {n:7}")
    det = plan["by_class"].get(CLASS_DETERMINISTIC, 0)
    print(f"\nDETERMINISTIC (non-retryable) = {det}   "
          f"SUPERSEDED = {plan['by_class'].get(CLASS_SUPERSEDED, 0)}   "
          f"IN_FLIGHT = {plan['by_class'].get(CLASS_IN_FLIGHT, 0)}   "
          f"TRANSIENT = {plan['by_class'].get(CLASS_TRANSIENT, 0)}")
    print(f"rows needing a failure_class write: {plan['rows_needing_write']} "
          f"(already classified: {sum(plan['already_classified'].values())})")


def _write_snapshot(rows: list[dict[str, Any]], db: Path, phase: str, stamp: str) -> Path:
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    snap_path = SNAPSHOT_DIR / f"classify_summary_missing_{phase}_{stamp}.json"
    entries = [
        {
            "id": r["id"],
            "failure_class": r["failure_class"],
            "failure_subclass": r["failure_subclass"],
            "payload_json": r["prior_text"],  # exact prior text -> exact revert
        }
        for r in rows
    ]
    snap = {
        "tool": "classify_summary_missing.py",
        "db": str(db),
        "phase": phase,
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "row_count": len(entries),
        "entries": entries,
    }
    snap_path.write_text(json.dumps(snap, indent=2), encoding="utf-8")
    return snap_path


def _apply(db: Path, rows: list[dict[str, Any]], batch: int) -> tuple[int, int]:
    """Payload-only stamp of failure_class/subclass/evidence. Guarded on prior payload.

    Commits in bounded batches so the live claim path never waits on one long write lock.
    """
    conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    changed = 0
    skipped = 0
    try:
        pending = 0
        for r in rows:
            updated = dict(r["payload"])
            updated["failure_class"] = r["failure_class"]
            updated["failure_subclass"] = r["failure_subclass"]
            updated["failure_class_evidence"] = "historical_reclassify:db_join"
            new_text = json.dumps(updated, sort_keys=True)
            cur = conn.execute(
                "UPDATE work_items SET payload_json=? WHERE id=? AND payload_json=?",
                (new_text, r["id"], r["prior_text"]),
            )
            if cur.rowcount == 1:
                changed += 1
            else:
                skipped += 1  # row changed since inspection — never clobber
            pending += 1
            if pending >= batch:
                conn.commit()
                pending = 0
        conn.commit()
    finally:
        conn.close()
    return changed, skipped


def _revert(db: Path, snap_path: Path, batch: int) -> tuple[int, int]:
    snap = json.loads(snap_path.read_text(encoding="utf-8"))
    conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    restored = 0
    skipped = 0
    try:
        pending = 0
        for entry in snap.get("entries", []):
            prior = entry["payload_json"]
            payload = json.loads(prior)
            payload["failure_class"] = entry["failure_class"]
            payload["failure_subclass"] = entry["failure_subclass"]
            payload["failure_class_evidence"] = "historical_reclassify:db_join"
            expected_after = json.dumps(payload, sort_keys=True)
            cur = conn.execute(
                "UPDATE work_items SET payload_json=? WHERE id=? AND payload_json=?",
                (prior, entry["id"], expected_after),
            )
            if cur.rowcount == 1:
                restored += 1
            else:
                skipped += 1
            pending += 1
            if pending >= batch:
                conn.commit()
                pending = 0
        conn.commit()
    finally:
        conn.close()
    return restored, skipped


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    ap.add_argument("--phase", default="Q02")
    ap.add_argument("--apply", action="store_true", help="write failure_class (default: dry-run)")
    ap.add_argument("--dry-run", action="store_true", help="explicit dry-run (default)")
    ap.add_argument("--revert", type=Path, metavar="SNAPSHOT", help="restore rows from a snapshot")
    ap.add_argument("--limit", type=int, default=None, help="cap rows written (canary)")
    ap.add_argument("--batch", type=int, default=500, help="rows per commit (lock friendliness)")
    ap.add_argument("--owner-decision", choices=[OWNER_DECISION_ID])
    ap.add_argument("--expected-pairs", type=int, default=OWNER_EXPECTED_PAIR_COUNT)
    ap.add_argument("--plan-out", type=Path)
    ap.add_argument("--plan", type=Path)
    ap.add_argument("--expected-plan-sha256")
    ap.add_argument("--receipt-out", type=Path)
    args = ap.parse_args(argv)

    if args.apply and args.revert:
        ap.error("--apply and --revert are mutually exclusive")
    if not args.db.exists():
        print(f"ERROR: DB not found: {args.db}", file=sys.stderr)
        return 2

    if args.revert:
        if not args.revert.exists():
            print(f"ERROR: snapshot not found: {args.revert}", file=sys.stderr)
            return 2
        restored, skipped = _revert(args.db, args.revert, args.batch)
        print(f"revert: restored={restored} skipped(changed_or_already_reverted)={skipped}")
        return 0

    if args.owner_decision:
        if args.apply:
            if not args.plan or not args.expected_plan_sha256 or not args.receipt_out:
                ap.error(
                    "OWNER apply requires --plan, --expected-plan-sha256 and --receipt-out"
                )
            raw = args.plan.read_bytes()
            actual_sha = _sha256_bytes(raw)
            if actual_sha != args.expected_plan_sha256.lower():
                raise RuntimeError(
                    f"plan SHA-256 mismatch: expected={args.expected_plan_sha256} "
                    f"actual={actual_sha}"
                )
            result = _apply_owner_dispositions(
                args.db, json.loads(raw), actual_sha, args.receipt_out
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        if args.plan_out is None:
            ap.error("OWNER dry-run requires --plan-out")
        plan = _owner_disposition_plan(args.db, args.expected_pairs)
        plan_sha = _write_new_json(args.plan_out, plan)
        print(json.dumps({
            "mode": "dry_run",
            "pair_count": len(plan["targets"]),
            "plan_path": str(args.plan_out.resolve()),
            "plan_sha256": plan_sha,
            "targets": plan["targets"],
        }, indent=2, sort_keys=True))
        return 0

    plan = _plan(args.db, args.phase, args.registry, args.limit if args.apply else None)
    _print_plan(plan)

    if not args.apply:
        print("\nDRY-RUN (default). No rows written. Re-run with --apply to stamp failure_class.")
        return 0

    rows = plan["rows"]
    if not rows:
        print("\nnothing to write: every graveyard row already carries its failure_class.")
        return 0
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    snap_path = _write_snapshot(rows, args.db, args.phase, stamp)
    print(f"\nsnapshot written (revert with --revert): {snap_path}")
    changed, skipped = _apply(args.db, rows, args.batch)
    print(f"apply: changed={changed} skipped(row_changed_since_inspection)={skipped}")
    print(f"revert command: python classify_summary_missing.py --revert \"{snap_path}\"")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
