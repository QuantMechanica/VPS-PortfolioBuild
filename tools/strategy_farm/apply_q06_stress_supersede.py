"""Apply one Claude-approved Q06 supersede proposal to the MNT overlay.

The runtime database is opened read-only. Historical work-item rows are never
updated: the only operational mutation is one atomic replacement of the
append-only, hash-chained adjudication overlay after every proposal binding is
reverified under the overlay sidecar lock.
"""

from __future__ import annotations

import argparse
from collections import Counter
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys
from typing import Any, Mapping, Sequence
import uuid

try:
    from mnt_closure_drift import (
        OVERLAY_SCHEMA,
        TOOL_ID,
        ScanError,
        canonical_json_bytes,
        canonical_sha256,
        open_db_read_only,
        sha256_file,
        validate_overlay_chain,
        valid_sha256,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.mnt_closure_drift import (
        OVERLAY_SCHEMA,
        TOOL_ID,
        ScanError,
        canonical_json_bytes,
        canonical_sha256,
        open_db_read_only,
        sha256_file,
        validate_overlay_chain,
        valid_sha256,
    )


APPLY_SCHEMA = "qm/q06-stress-supersede-apply-receipt/v1"
PROPOSAL_SCHEMA = "qm/q06-stress-supersede-proposal/v1"
APPLY_TOOL = "apply_q06_stress_supersede/v1"
APPROVED_PROPOSAL_COMMIT = "e12753b4dcc1a367f01335b00e1d8f14dc4d8924"
APPROVED_PROPOSAL_SHA256 = (
    "cdb3472e9a24738c09eb928ebde1b2ea6042f0035e50be2ab5d8a263408a0b27"
)
AUTHORITY_TASK_ID = "13c3a60d-e9fc-4c97-962b-eb735b16960b"
APPLY_TASK_ID = "4b64823f-cd32-42f6-908f-9ea1841b4858"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_OVERLAY = Path(
    r"D:\QM\reports\maintenance\mnt_adjudication_overlay.jsonl"
)
EXPECTED_REASON_COUNTS = Counter(
    {
        "STRESS_INPUT_NOT_EFFECTIVE": 8,
        "BASKET_REJECTION_HOOK_MISSING": 5,
    }
)
OS_BINARY = getattr(os, "O_BINARY", 0)


class ApplyError(ScanError):
    """A proposal, authority, row, evidence, or append precondition drifted."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _parse_utc(value: str) -> str:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid ISO-8601 timestamp: {value}") from exc
    if parsed.tzinfo is None:
        raise argparse.ArgumentTypeError("timestamp must carry a UTC offset")
    return parsed.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def _load_json_with_hash(path: Path) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ApplyError(f"proposal is unreadable: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ApplyError("proposal root must be an object")
    return value, hashlib.sha256(raw).hexdigest()


def _parse_payload(raw: Any, *, context: str) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except json.JSONDecodeError as exc:
        raise ApplyError(f"{context} payload_json is invalid: {exc}") from exc
    if not isinstance(value, dict):
        raise ApplyError(f"{context} payload_json must be an object")
    return value


def database_row_snapshot(row: Mapping[str, Any]) -> dict[str, Any]:
    """Return every SQLite column, matching the approved proposal generator."""

    return {key: row[key] for key in row.keys()}


def _validate_static_proposal(
    proposal: Mapping[str, Any],
    *,
    proposal_sha256: str,
    expected_proposal_sha256: str,
) -> list[dict[str, Any]]:
    if proposal_sha256 != expected_proposal_sha256:
        raise ApplyError(
            "approved proposal hash drift: "
            f"expected={expected_proposal_sha256} actual={proposal_sha256}"
        )
    if proposal.get("schema") != PROPOSAL_SCHEMA:
        raise ApplyError("proposal schema is not supported")
    if proposal.get("status") != "PROPOSAL_ONLY_NOT_APPLIED":
        raise ApplyError("proposal status is not applyable")
    if proposal.get("router_task_id") != AUTHORITY_TASK_ID:
        raise ApplyError("proposal router_task_id does not bind the authority task")
    if proposal.get("proposed_effective_admission_status") != "PROVENANCE_UNVERIFIED":
        raise ApplyError("proposal effective admission status drifted")
    if proposal.get("proposed_priority") != "P0_ADMISSION":
        raise ApplyError("proposal priority drifted")
    if proposal.get("proposed_live_action") != "HOLD_OWNER_REVIEW":
        raise ApplyError("proposal live action drifted")
    if proposal.get("raw_work_item_mutations") != 0:
        raise ApplyError("proposal permits raw work-item mutation")

    raw_events = proposal.get("events")
    if not isinstance(raw_events, list) or len(raw_events) != 13:
        raise ApplyError("approved proposal must contain exactly 13 events")
    if proposal.get("event_count") != len(raw_events):
        raise ApplyError("proposal event_count does not match events")

    events: list[dict[str, Any]] = []
    historical_ids: set[str] = set()
    replacement_ids: set[str] = set()
    proposal_ids: set[str] = set()
    reasons: Counter[str] = Counter()
    for index, value in enumerate(raw_events):
        if not isinstance(value, dict):
            raise ApplyError(f"proposal event {index} is not an object")
        event = dict(value)
        proposal_event_id = str(event.get("proposal_event_id") or "")
        identity = dict(event)
        identity.pop("proposal_event_id", None)
        identity.pop("replacement_state_observed", None)
        if proposal_event_id != canonical_sha256(identity):
            raise ApplyError(f"proposal_event_id drift at index {index}")
        if not valid_sha256(proposal_event_id):
            raise ApplyError(f"proposal_event_id invalid at index {index}")
        work_item_id = str(event.get("work_item_id") or "")
        replacement_id = str(event.get("replacement_work_item_id") or "")
        if not work_item_id or not replacement_id:
            raise ApplyError(f"row identity missing at proposal index {index}")
        if work_item_id in historical_ids or replacement_id in replacement_ids:
            raise ApplyError(f"duplicate row identity at proposal index {index}")
        if proposal_event_id in proposal_ids:
            raise ApplyError(f"duplicate proposal_event_id at index {index}")
        historical_ids.add(work_item_id)
        replacement_ids.add(replacement_id)
        proposal_ids.add(proposal_event_id)

        reason_classes = event.get("reason_classes")
        if not isinstance(reason_classes, list) or len(reason_classes) != 1:
            raise ApplyError(f"event {work_item_id} must have one defect class")
        reason = str(reason_classes[0])
        reasons[reason] += 1
        if event.get("phase") != "Q06":
            raise ApplyError(f"event {work_item_id} is not Q06")
        if event.get("original_status") != "done" or event.get("original_verdict") != "PASS":
            raise ApplyError(f"event {work_item_id} original disposition drifted")
        for field in ("raw_row_sha256", "evidence_sha256"):
            if not valid_sha256(event.get(field)):
                raise ApplyError(f"event {work_item_id} has invalid {field}")
        events.append(event)
    if reasons != EXPECTED_REASON_COUNTS:
        raise ApplyError(
            f"proposal defect-class counts drifted: {dict(sorted(reasons.items()))}"
        )
    return events


def _authority_binding(connection: sqlite3.Connection) -> dict[str, Any]:
    row = connection.execute(
        "SELECT * FROM agent_tasks WHERE id=?",
        (AUTHORITY_TASK_ID,),
    ).fetchone()
    if row is None:
        raise ApplyError(f"Claude authority task missing: {AUTHORITY_TASK_ID}")
    payload = _parse_payload(row["payload_json"], context="authority task")
    close_verdict = str(payload.get("review_close_verdict") or "")
    if payload.get("review_close_state") != "APPROVED":
        raise ApplyError("authority review_close_state is not APPROVED")
    if row["state"] not in {"APPROVED", "PASSED"}:
        raise ApplyError(f"authority task state is not terminal-approved: {row['state']}")
    required_fragments = (
        "Supersede proposal semantics APPROVED",
        "full re-verify/append-atomic/no-UPDATE contract",
    )
    if any(fragment not in close_verdict for fragment in required_fragments):
        raise ApplyError("authority close-review verdict does not approve this apply contract")
    snapshot = {key: row[key] for key in row.keys()}
    return {
        "task_id": AUTHORITY_TASK_ID,
        "task_state": row["state"],
        "review_close_state": payload["review_close_state"],
        "review_closed_at": payload.get("review_closed_at"),
        "review_close_verdict": close_verdict,
        "agent_task_row_sha256": canonical_sha256(snapshot),
    }


def _same_path(left: Any, right: Any) -> bool:
    try:
        return Path(str(left)).resolve() == Path(str(right)).resolve()
    except OSError:
        return False


def _verify_database_and_evidence(
    *,
    db_path: Path,
    events: Sequence[Mapping[str, Any]],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    connection = open_db_read_only(db_path)
    try:
        authority = _authority_binding(connection)
        checks: list[dict[str, Any]] = []
        for proposal_event in events:
            work_item_id = str(proposal_event["work_item_id"])
            historical = connection.execute(
                "SELECT * FROM work_items WHERE id=?",
                (work_item_id,),
            ).fetchone()
            if historical is None:
                raise ApplyError(f"historical row missing: {work_item_id}")
            raw_snapshot = database_row_snapshot(historical)
            raw_sha256 = canonical_sha256(raw_snapshot)
            if raw_sha256 != proposal_event["raw_row_sha256"]:
                raise ApplyError(
                    f"historical row hash drift: {work_item_id}: "
                    f"expected={proposal_event['raw_row_sha256']} actual={raw_sha256}"
                )
            for field in ("phase", "ea_id", "symbol", "status", "verdict"):
                proposal_field = {
                    "status": "original_status",
                    "verdict": "original_verdict",
                }.get(field, field)
                if historical[field] != proposal_event[proposal_field]:
                    raise ApplyError(f"historical row {work_item_id} field drift: {field}")
            if not _same_path(historical["evidence_path"], proposal_event["evidence_path"]):
                raise ApplyError(f"historical evidence path drift: {work_item_id}")

            evidence_path = Path(str(proposal_event["evidence_path"]))
            if not evidence_path.is_file():
                raise ApplyError(f"historical evidence missing: {evidence_path}")
            evidence_sha256 = sha256_file(evidence_path)
            if evidence_sha256 != proposal_event["evidence_sha256"]:
                raise ApplyError(
                    f"historical evidence hash drift: {work_item_id}: "
                    f"expected={proposal_event['evidence_sha256']} actual={evidence_sha256}"
                )

            replacement_id = str(proposal_event["replacement_work_item_id"])
            replacement = connection.execute(
                "SELECT * FROM work_items WHERE id=?",
                (replacement_id,),
            ).fetchone()
            if replacement is None:
                raise ApplyError(f"replacement row missing: {replacement_id}")
            for field in ("phase", "ea_id", "symbol"):
                if replacement[field] != historical[field]:
                    raise ApplyError(
                        f"replacement row {replacement_id} does not match {field}"
                    )
            replacement_payload = _parse_payload(
                replacement["payload_json"],
                context=f"replacement {replacement_id}",
            )
            if replacement_payload.get("append_only_rerun_of_work_item") != work_item_id:
                raise ApplyError(f"replacement lineage drift: {replacement_id}")
            if replacement_payload.get("append_only_rerun") is not True:
                raise ApplyError(f"replacement append-only marker missing: {replacement_id}")
            if replacement_payload.get("historical_work_item_preserved") is not True:
                raise ApplyError(
                    f"replacement preservation marker missing: {replacement_id}"
                )
            replacement_snapshot = database_row_snapshot(replacement)
            checks.append(
                {
                    "proposal_event_id": proposal_event["proposal_event_id"],
                    "work_item_id": work_item_id,
                    "raw_row_sha256": raw_sha256,
                    "evidence_path": str(evidence_path),
                    "evidence_sha256": evidence_sha256,
                    "reason_classes": list(proposal_event["reason_classes"]),
                    "replacement_work_item_id": replacement_id,
                    "replacement_status": replacement["status"],
                    "replacement_verdict": replacement["verdict"],
                    "replacement_raw_row_sha256": canonical_sha256(
                        replacement_snapshot
                    ),
                    "replacement_lineage_verified": True,
                }
            )
        connection.rollback()
        return authority, checks
    finally:
        connection.close()


def _build_overlay_events(
    *,
    proposal: Mapping[str, Any],
    proposal_sha256: str,
    proposal_events: Sequence[Mapping[str, Any]],
    row_checks: Sequence[Mapping[str, Any]],
    authority: Mapping[str, Any],
    observed_at_utc: str,
    apply_tool_sha256: str,
) -> list[dict[str, Any]]:
    checks_by_id = {str(row["work_item_id"]): row for row in row_checks}
    reviewer = f"claude:{AUTHORITY_TASK_ID};codex:{APPLY_TASK_ID}"
    result: list[dict[str, Any]] = []
    for proposed in proposal_events:
        work_item_id = str(proposed["work_item_id"])
        check = checks_by_id[work_item_id]
        binding = {
            "schema": "qm/q06-stress-supersede-adjudication-binding/v1",
            "proposal_schema": proposal["schema"],
            "proposal_sha256": proposal_sha256,
            "proposal_event_id": proposed["proposal_event_id"],
            "authority_task_id": AUTHORITY_TASK_ID,
            "authority_agent_task_row_sha256": authority["agent_task_row_sha256"],
            "apply_task_id": APPLY_TASK_ID,
            "apply_tool_sha256": apply_tool_sha256,
            "work_item_id": work_item_id,
            "raw_row_sha256": check["raw_row_sha256"],
            "evidence_sha256": check["evidence_sha256"],
            "replacement_work_item_id": check["replacement_work_item_id"],
            "replacement_raw_row_sha256": check["replacement_raw_row_sha256"],
            "replacement_lineage_verified": True,
            "effective_admission_status": "PROVENANCE_UNVERIFIED",
            "reason_classes": list(proposed["reason_classes"]),
        }
        event = {
            "schema": OVERLAY_SCHEMA,
            "tool": TOOL_ID,
            "apply_tool": APPLY_TOOL,
            "apply_tool_sha256": apply_tool_sha256,
            "reviewer": reviewer,
            "observed_at_utc": observed_at_utc,
            "work_item_id": work_item_id,
            "raw_row_sha256": check["raw_row_sha256"],
            "phase": proposed["phase"],
            "ea_id": proposed["ea_id"],
            "symbol": proposed["symbol"],
            "original_status": proposed["original_status"],
            "original_verdict": proposed["original_verdict"],
            "effective_admission_status": "PROVENANCE_UNVERIFIED",
            "reason_classes": list(proposed["reason_classes"]),
            "priority": "P0_ADMISSION",
            "live_action": "HOLD_OWNER_REVIEW",
            "evidence_path": proposed["evidence_path"],
            "evidence_sha256": check["evidence_sha256"],
            "adjudication_fingerprint_sha256": canonical_sha256(binding),
            "proposal_sha256": proposal_sha256,
            "proposal_event_id": proposed["proposal_event_id"],
            "proposal_commit": APPROVED_PROPOSAL_COMMIT,
            "authority_task_id": AUTHORITY_TASK_ID,
            "authority_agent_task_row_sha256": authority[
                "agent_task_row_sha256"
            ],
            "apply_task_id": APPLY_TASK_ID,
            "replacement_work_item_id": check["replacement_work_item_id"],
            "replacement_status_observed": check["replacement_status"],
            "replacement_verdict_observed": check["replacement_verdict"],
            "replacement_raw_row_sha256": check["replacement_raw_row_sha256"],
            "replacement_lineage_verified": True,
        }
        event_identity = dict(event)
        event_identity.pop("observed_at_utc")
        event_identity.pop("reviewer")
        event["event_id"] = canonical_sha256(event_identity)
        result.append(event)
    return result


def _read_overlay_state(
    path: Path,
) -> tuple[bytes, list[dict[str, Any]], str | None, bool]:
    if not path.parent.is_dir():
        raise ApplyError(f"overlay parent directory does not exist: {path.parent}")
    existed = path.exists()
    events, tail = validate_overlay_chain(path)
    try:
        raw = path.read_bytes() if existed else b""
    except OSError as exc:
        raise ApplyError(f"overlay is unreadable: {path}: {exc}") from exc
    if raw and not raw.endswith(b"\n"):
        raise ApplyError("overlay does not end at a complete JSONL record")
    if len(raw.splitlines()) != len(events):
        raise ApplyError("overlay byte/chain event counts disagree")
    event_ids = [str(event.get("event_id") or "") for event in events]
    if any(not valid_sha256(event_id) for event_id in event_ids):
        raise ApplyError("overlay contains an invalid event_id")
    if len(event_ids) != len(set(event_ids)):
        raise ApplyError("overlay contains duplicate event_id values")
    return raw, events, tail, existed


def _sign_batch(
    *,
    candidates: Sequence[Mapping[str, Any]],
    previous_tail: str | None,
    existing_event_ids: set[str],
    first_line_number: int,
) -> tuple[list[dict[str, Any]], bytes, str | None, list[dict[str, Any]]]:
    previous = previous_tail
    signed: list[dict[str, Any]] = []
    receipt_rows: list[dict[str, Any]] = []
    chunks: list[bytes] = []
    for offset, candidate in enumerate(
        sorted(candidates, key=lambda item: str(item.get("event_id")))
    ):
        event_id = str(candidate.get("event_id") or "")
        if not valid_sha256(event_id):
            raise ApplyError("candidate event_id is invalid")
        if event_id in existing_event_ids:
            raise ApplyError(f"candidate event already exists: {event_id}")
        event = dict(candidate)
        event["previous_event_sha256"] = previous
        event["event_sha256"] = canonical_sha256(event)
        encoded = canonical_json_bytes(event) + b"\n"
        chunks.append(encoded)
        signed.append(event)
        receipt_rows.append(
            {
                "line_number": first_line_number + offset,
                "proposal_event_id": event["proposal_event_id"],
                "work_item_id": event["work_item_id"],
                "reason_classes": event["reason_classes"],
                "raw_row_sha256": event["raw_row_sha256"],
                "evidence_sha256": event["evidence_sha256"],
                "replacement_work_item_id": event["replacement_work_item_id"],
                "replacement_raw_row_sha256": event[
                    "replacement_raw_row_sha256"
                ],
                "event_id": event_id,
                "previous_event_sha256": previous,
                "event_sha256": event["event_sha256"],
            }
        )
        previous = event["event_sha256"]
        existing_event_ids.add(event_id)
    return signed, b"".join(chunks), previous, receipt_rows


def _write_all(descriptor: int, payload: bytes) -> None:
    view = memoryview(payload)
    while view:
        written = os.write(descriptor, view)
        if written <= 0:
            raise OSError("write made no progress")
        view = view[written:]


def _atomic_overlay_append(path: Path, *, before: bytes, append_payload: bytes) -> None:
    before_exists = path.exists()
    temp = path.with_name(f".{path.name}.tmp.{os.getpid()}.{uuid.uuid4().hex}")
    descriptor: int | None = None
    try:
        descriptor = os.open(
            temp,
            os.O_CREAT | os.O_EXCL | os.O_WRONLY | OS_BINARY,
            0o600,
        )
        _write_all(descriptor, before + append_payload)
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None

        actual_exists = path.exists()
        actual = path.read_bytes() if actual_exists else b""
        if actual_exists != before_exists or actual != before:
            raise ApplyError("overlay content changed before atomic replace")
        if before_exists:
            os.replace(temp, path)
        elif os.name == "nt":
            os.rename(temp, path)  # Windows refuses an unexpected existing target
        else:
            os.link(temp, path)  # create-only publication on POSIX
            temp.unlink()
    finally:
        if descriptor is not None:
            try:
                os.close(descriptor)
            except OSError:
                pass
        try:
            temp.unlink()
        except FileNotFoundError:
            pass


def _write_receipt_create_only(path: Path, receipt: Mapping[str, Any]) -> None:
    if not path.parent.is_dir():
        raise ApplyError(f"receipt parent directory does not exist: {path.parent}")
    payload = json.dumps(
        receipt,
        ensure_ascii=False,
        sort_keys=True,
        indent=2,
    ).encode("utf-8") + b"\n"
    descriptor = os.open(
        path,
        os.O_CREAT | os.O_EXCL | os.O_WRONLY | OS_BINARY,
        0o600,
    )
    try:
        _write_all(descriptor, payload)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _acquire_sidecar_lock(path: Path) -> tuple[int, bytes]:
    lock_path = path.with_name(path.name + ".lock")
    record = canonical_json_bytes(
        {
            "pid": os.getpid(),
            "owner": APPLY_TOOL,
            "nonce": uuid.uuid4().hex,
            "created_at_utc": _utc_now(),
        }
    ) + b"\n"
    try:
        descriptor = os.open(
            lock_path,
            os.O_CREAT | os.O_EXCL | os.O_WRONLY | OS_BINARY,
            0o600,
        )
    except FileExistsError as exc:
        raise ApplyError(f"overlay append lock already exists: {lock_path}") from exc
    try:
        _write_all(descriptor, record)
        os.fsync(descriptor)
    except BaseException:
        os.close(descriptor)
        try:
            lock_path.unlink()
        except OSError:
            pass
        raise
    return descriptor, record


def _release_sidecar_lock(path: Path, descriptor: int, expected: bytes) -> None:
    lock_path = path.with_name(path.name + ".lock")
    try:
        os.close(descriptor)
    finally:
        try:
            actual = lock_path.read_bytes()
        except FileNotFoundError:
            return
        if actual != expected:
            raise ApplyError(f"overlay lock ownership changed: {lock_path}")
        lock_path.unlink()


def apply_proposal(
    *,
    proposal_path: Path,
    db_path: Path,
    overlay_path: Path,
    receipt_path: Path | None,
    apply: bool,
    observed_at_utc: str,
    expected_proposal_sha256: str = APPROVED_PROPOSAL_SHA256,
) -> dict[str, Any]:
    proposal, proposal_sha256 = _load_json_with_hash(proposal_path)
    proposal_events = _validate_static_proposal(
        proposal,
        proposal_sha256=proposal_sha256,
        expected_proposal_sha256=expected_proposal_sha256,
    )
    tool_path = Path(__file__).resolve()
    apply_tool_sha256 = sha256_file(tool_path)

    if not apply:
        authority, row_checks = _verify_database_and_evidence(
            db_path=db_path,
            events=proposal_events,
        )
        before, existing, before_tail, before_existed = _read_overlay_state(
            overlay_path
        )
        candidates = _build_overlay_events(
            proposal=proposal,
            proposal_sha256=proposal_sha256,
            proposal_events=proposal_events,
            row_checks=row_checks,
            authority=authority,
            observed_at_utc=observed_at_utc,
            apply_tool_sha256=apply_tool_sha256,
        )
        _signed, append_payload, after_tail, receipt_rows = _sign_batch(
            candidates=candidates,
            previous_tail=before_tail,
            existing_event_ids={str(event.get("event_id")) for event in existing},
            first_line_number=len(existing) + 1,
        )
        return {
            "schema": APPLY_SCHEMA,
            "status": "DRY_RUN_VERIFIED_NO_MUTATION",
            "observed_at_utc": observed_at_utc,
            "proposal_path": str(proposal_path),
            "proposal_sha256": proposal_sha256,
            "authority": authority,
            "database": str(db_path),
            "overlay": {
                "path": str(overlay_path),
                "before_existed": before_existed,
                "before_event_count": len(existing),
                "before_tail_event_sha256": before_tail,
                "before_bytes_sha256": hashlib.sha256(before).hexdigest(),
                "planned_append_count": len(receipt_rows),
                "planned_after_tail_event_sha256": after_tail,
                "planned_after_bytes_sha256": hashlib.sha256(
                    before + append_payload
                ).hexdigest(),
            },
            "reason_counts": dict(EXPECTED_REASON_COUNTS),
            "raw_work_item_mutations": 0,
            "rows": receipt_rows,
        }

    if receipt_path is None:
        raise ApplyError("--receipt is required with --apply")
    if receipt_path.exists():
        raise ApplyError(f"receipt path already exists: {receipt_path}")

    lock_descriptor, lock_record = _acquire_sidecar_lock(overlay_path)
    try:
        # Re-read every authority/row/file binding after acquiring the same
        # sidecar lock used by the canonical MNT appender.
        locked_proposal, locked_sha256 = _load_json_with_hash(proposal_path)
        if locked_sha256 != proposal_sha256 or locked_proposal != proposal:
            raise ApplyError("proposal changed before locked apply")
        authority, row_checks = _verify_database_and_evidence(
            db_path=db_path,
            events=proposal_events,
        )
        before, existing, before_tail, before_existed = _read_overlay_state(
            overlay_path
        )
        candidates = _build_overlay_events(
            proposal=proposal,
            proposal_sha256=proposal_sha256,
            proposal_events=proposal_events,
            row_checks=row_checks,
            authority=authority,
            observed_at_utc=observed_at_utc,
            apply_tool_sha256=apply_tool_sha256,
        )
        signed, append_payload, after_tail, receipt_rows = _sign_batch(
            candidates=candidates,
            previous_tail=before_tail,
            existing_event_ids={str(event.get("event_id")) for event in existing},
            first_line_number=len(existing) + 1,
        )
        _atomic_overlay_append(
            overlay_path,
            before=before,
            append_payload=append_payload,
        )

        after_events, validated_tail = validate_overlay_chain(overlay_path)
        after_bytes = overlay_path.read_bytes()
        if len(after_events) != len(existing) + len(signed):
            raise ApplyError("post-append overlay event count mismatch")
        if validated_tail != after_tail:
            raise ApplyError("post-append overlay tail mismatch")
        expected_after = before + append_payload
        if after_bytes != expected_after:
            raise ApplyError("post-append overlay bytes mismatch")

        # A second fresh read-only transaction proves the append did not alter
        # any historical DB row and the evidence bindings are still present.
        post_authority, post_checks = _verify_database_and_evidence(
            db_path=db_path,
            events=proposal_events,
        )
        before_historical = {
            str(row["work_item_id"]): str(row["raw_row_sha256"])
            for row in row_checks
        }
        after_historical = {
            str(row["work_item_id"]): str(row["raw_row_sha256"])
            for row in post_checks
        }
        if before_historical != after_historical:
            raise ApplyError("historical rows changed across overlay append")
        if post_authority["review_close_state"] != "APPROVED":
            raise ApplyError("authority drifted across overlay append")

        receipt = {
            "schema": APPLY_SCHEMA,
            "status": "APPLIED",
            "applied_at_utc": observed_at_utc,
            "proposal_path": str(proposal_path),
            "proposal_sha256": proposal_sha256,
            "proposal_commit": APPROVED_PROPOSAL_COMMIT,
            "authority": authority,
            "apply_task_id": APPLY_TASK_ID,
            "apply_tool_path": str(tool_path),
            "apply_tool_sha256": apply_tool_sha256,
            "database": str(db_path),
            "database_open_mode": "ro/query_only",
            "raw_row_hash_algorithm": (
                "sha256(canonical-json(all SQLite work_items columns))"
            ),
            "raw_work_item_mutations": 0,
            "historical_rows_reverified_unchanged": len(before_historical),
            "reason_counts": dict(EXPECTED_REASON_COUNTS),
            "overlay": {
                "path": str(overlay_path),
                "before_existed": before_existed,
                "before_event_count": len(existing),
                "before_tail_event_sha256": before_tail,
                "before_bytes": len(before),
                "before_bytes_sha256": hashlib.sha256(before).hexdigest(),
                "appended_event_count": len(signed),
                "after_event_count": len(after_events),
                "after_tail_event_sha256": after_tail,
                "after_bytes": len(after_bytes),
                "after_bytes_sha256": hashlib.sha256(after_bytes).hexdigest(),
                "chain_validation": "PASS",
                "publication": "single_same-directory_atomic_replace",
            },
            "rows": receipt_rows,
        }
        receipt["receipt_fingerprint_sha256"] = canonical_sha256(receipt)
        _write_receipt_create_only(receipt_path, receipt)
        return receipt
    finally:
        _release_sidecar_lock(overlay_path, lock_descriptor, lock_record)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--overlay", type=Path, default=DEFAULT_OVERLAY)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--observed-at-utc", type=_parse_utc, default=None)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="perform the atomic overlay append; otherwise verify read-only",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = apply_proposal(
            proposal_path=args.proposal,
            db_path=args.db,
            overlay_path=args.overlay,
            receipt_path=args.receipt,
            apply=bool(args.apply),
            observed_at_utc=args.observed_at_utc or _utc_now(),
        )
    except (OSError, sqlite3.Error, ApplyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    summary = {
        "status": result["status"],
        "proposal_sha256": result["proposal_sha256"],
        "raw_work_item_mutations": result["raw_work_item_mutations"],
        "reason_counts": result["reason_counts"],
        "overlay": result["overlay"],
        "receipt_fingerprint_sha256": result.get("receipt_fingerprint_sha256"),
    }
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
