"""Verify or apply the OWNER-reviewed MNT-043 KS vintage bill.

The farm database is always opened read-only.  Dry-run is the default and
performs every bill, database-row, adopted-binary, and overlay-chain check
without creating a lock, receipt, or overlay record.  Apply mode is narrowly
bound to the reviewed bill and the caller-supplied overlay head, then appends
one fsync'd, hash-chained event per bill row under the standard create-only
sidecar lock.
"""

from __future__ import annotations

import argparse
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
        work_item_snapshot,
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
        work_item_snapshot,
    )


APPLY_SCHEMA = "qm/mnt043-ks-vintage-bill-apply-receipt/v1"
BINDING_SCHEMA = "qm/mnt043-ks-vintage-adjudication-binding/v1"
BILL_SCHEMA = "qm.mnt043_044.recompile_vintage_bill.proposed.v1"
APPLY_TOOL = "apply_ks_vintage_bill/v1"
APPROVED_BILL_SHA256 = (
    "1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1"
)
APPROVED_BILL_STATUS = (
    "PREPARED_NOT_APPENDED_PENDING_CLAUDE_REVIEW_AND_STAGED_BINARY_ADOPTION"
)
EXPECTED_SOURCE_COMMIT = "386151841013afbaf01fe10b23e6cf7538480b71"
EXPECTED_EFFECTIVE_STATUS = "EVIDENCE_VINTAGE_STALE"
EXPECTED_REASON_CLASS = "BINARY_VINTAGE_MISMATCH"
EXPECTED_EVENT_COUNT = 26
EXPECTED_BINARY_COUNT = 7
EXPECTED_OVERLAY_EVENT_COUNT = 13
TRAILER_FLAGS = (
    "append_only_overlay_write_performed",
    "work_item_rows_modified",
    "pipeline_verdict_created",
    "live_action_performed",
)
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_OVERLAY = Path(r"D:\QM\reports\maintenance\mnt_adjudication_overlay.jsonl")
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[2]
OS_BINARY = getattr(os, "O_BINARY", 0)


class ApplyError(ScanError):
    """The reviewed bill, a bound row/binary, or the overlay head drifted."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _parse_utc(value: str) -> str:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"invalid ISO-8601 timestamp: {value}"
        ) from exc
    if parsed.tzinfo is None:
        raise argparse.ArgumentTypeError("timestamp must carry a UTC offset")
    return parsed.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def _parse_sha256(value: str) -> str:
    normalized = value.strip().lower()
    if not valid_sha256(normalized):
        raise argparse.ArgumentTypeError("expected a full SHA-256 hex digest")
    return normalized


def _require_sha256(value: Any, *, field: str) -> str:
    if not valid_sha256(value):
        raise ApplyError(f"{field} is not a full SHA-256 digest")
    return str(value).lower()


def _load_json_with_hash(path: Path) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ApplyError(f"bill is unreadable: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ApplyError("bill root must be an object")
    return value, hashlib.sha256(raw).hexdigest()


def _validate_static_bill(
    bill: Mapping[str, Any],
    *,
    bill_sha256: str,
    expected_bill_sha256: str,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    expected = _require_sha256(
        expected_bill_sha256,
        field="expected bill sha256",
    )
    approved = _require_sha256(
        APPROVED_BILL_SHA256,
        field="approved bill sha256",
    )
    if expected != approved:
        raise ApplyError(
            "expected bill hash is not the approved MNT-043 bill: "
            f"approved={approved} supplied={expected}"
        )
    if bill_sha256 != expected:
        raise ApplyError(
            "bill file hash drift: "
            f"expected={expected} actual={bill_sha256}"
        )
    if bill.get("schema_version") != BILL_SCHEMA:
        raise ApplyError("bill schema_version is not supported")
    if bill.get("status") != APPROVED_BILL_STATUS:
        raise ApplyError(
            "bill status is not applyable: "
            f"expected={APPROVED_BILL_STATUS!r} actual={bill.get('status')!r}"
        )
    if bill.get("source_commit") != EXPECTED_SOURCE_COMMIT:
        raise ApplyError("bill source_commit is not the reviewed 386151841 pin")
    if bill.get("proposed_effective_status") != EXPECTED_EFFECTIVE_STATUS:
        raise ApplyError("bill proposed_effective_status drifted")
    if bill.get("proposed_reason_class") != EXPECTED_REASON_CLASS:
        raise ApplyError("bill proposed_reason_class drifted")
    for flag in TRAILER_FLAGS:
        if bill.get(flag) is not False:
            raise ApplyError(f"bill trailer flag is not false: {flag}")

    raw_replacements = bill.get("binary_replacements")
    if not isinstance(raw_replacements, list) or len(raw_replacements) != EXPECTED_BINARY_COUNT:
        raise ApplyError(
            f"bill must contain exactly {EXPECTED_BINARY_COUNT} binary replacements"
        )
    replacements: list[dict[str, Any]] = []
    replacement_by_ea: dict[str, dict[str, Any]] = {}
    for index, value in enumerate(raw_replacements):
        if not isinstance(value, dict):
            raise ApplyError(f"binary replacement {index} is not an object")
        replacement = dict(value)
        ea_id = str(replacement.get("ea_id") or "")
        if not ea_id.startswith("QM5_") or not ea_id[4:].isdigit():
            raise ApplyError(f"binary replacement {index} has invalid ea_id")
        if ea_id in replacement_by_ea:
            raise ApplyError(f"duplicate binary replacement: {ea_id}")
        replacement["new_ex5_sha256"] = _require_sha256(
            replacement.get("new_ex5_sha256"),
            field=f"binary replacement {ea_id} new_ex5_sha256",
        )
        replacement["historical_repo_ex5_reference_sha256"] = _require_sha256(
            replacement.get("historical_repo_ex5_reference_sha256"),
            field=f"binary replacement {ea_id} historical hash",
        )
        replacements.append(replacement)
        replacement_by_ea[ea_id] = replacement

    raw_events = bill.get("events")
    if not isinstance(raw_events, list) or len(raw_events) != EXPECTED_EVENT_COUNT:
        raise ApplyError(f"bill must contain exactly {EXPECTED_EVENT_COUNT} events")
    scan = bill.get("read_only_scan")
    if not isinstance(scan, dict) or scan.get("target_historical_pass_rows") != EXPECTED_EVENT_COUNT:
        raise ApplyError("bill read_only_scan event count drifted")

    events: list[dict[str, Any]] = []
    work_item_ids: set[str] = set()
    for index, value in enumerate(raw_events):
        if not isinstance(value, dict):
            raise ApplyError(f"bill event {index} is not an object")
        event = dict(value)
        work_item_id = str(event.get("work_item_id") or "")
        if not work_item_id:
            raise ApplyError(f"bill event {index} has no work_item_id")
        if work_item_id in work_item_ids:
            raise ApplyError(f"duplicate bill work_item_id: {work_item_id}")
        work_item_ids.add(work_item_id)
        if event.get("phase") not in {"Q06", "Q07"}:
            raise ApplyError(f"bill event {work_item_id} has invalid phase")
        if event.get("original_verdict") != "PASS":
            raise ApplyError(f"bill event {work_item_id} was not originally PASS")
        if event.get("priority") not in {"P0_ADMISSION", "P1_HISTORY"}:
            raise ApplyError(f"bill event {work_item_id} has invalid priority")
        event["raw_row_sha256"] = _require_sha256(
            event.get("raw_row_sha256"),
            field=f"bill event {work_item_id} raw_row_sha256",
        )
        ea_id = str(event.get("ea_id") or "")
        replacement = replacement_by_ea.get(ea_id)
        if replacement is None:
            raise ApplyError(
                f"bill event {work_item_id} has no binary replacement: {ea_id}"
            )
        event["new_ex5_sha256"] = _require_sha256(
            event.get("new_ex5_sha256"),
            field=f"bill event {work_item_id} new_ex5_sha256",
        )
        if event["new_ex5_sha256"] != replacement["new_ex5_sha256"]:
            raise ApplyError(f"bill event {work_item_id} new EX5 hash drifted")
        if not isinstance(event.get("current_reason_classes"), list):
            raise ApplyError(
                f"bill event {work_item_id} current_reason_classes is not a list"
            )
        events.append(event)
    return events, replacements


def _verify_database_rows(
    *,
    db_path: Path,
    events: Sequence[Mapping[str, Any]],
) -> list[dict[str, Any]]:
    connection = open_db_read_only(db_path)
    try:
        checks: list[dict[str, Any]] = []
        for bill_event in events:
            work_item_id = str(bill_event["work_item_id"])
            row = connection.execute(
                "SELECT * FROM work_items WHERE id=?",
                (work_item_id,),
            ).fetchone()
            if row is None:
                raise ApplyError(f"bill work_item is missing: {work_item_id}")
            snapshot = work_item_snapshot(row)
            raw_sha256 = canonical_sha256(snapshot)
            if raw_sha256 != bill_event["raw_row_sha256"]:
                raise ApplyError(
                    f"work_item raw row hash drift: {work_item_id}: "
                    f"expected={bill_event['raw_row_sha256']} actual={raw_sha256}"
                )
            if row["status"] != "done":
                raise ApplyError(
                    f"bill work_item is no longer done: {work_item_id}: {row['status']!r}"
                )
            if row["verdict"] != "PASS" or bill_event["original_verdict"] != "PASS":
                raise ApplyError(
                    f"bill work_item is no longer PASS: {work_item_id}: {row['verdict']!r}"
                )
            for field in ("phase", "ea_id", "symbol"):
                if row[field] != bill_event[field]:
                    raise ApplyError(
                        f"bill work_item identity drift: {work_item_id}: {field}: "
                        f"expected={bill_event[field]!r} actual={row[field]!r}"
                    )
            checks.append(
                {
                    "work_item_id": work_item_id,
                    "raw_row_sha256": raw_sha256,
                    "status": row["status"],
                    "verdict": row["verdict"],
                    "phase": row["phase"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                }
            )
        connection.rollback()
        return checks
    finally:
        connection.close()


def _verify_adopted_binaries(
    *,
    repo_root: Path,
    replacements: Sequence[Mapping[str, Any]],
) -> list[dict[str, Any]]:
    ea_root = repo_root / "framework" / "EAs"
    if not ea_root.is_dir():
        raise ApplyError(f"repo-tree EA root is missing: {ea_root}")
    checks: list[dict[str, Any]] = []
    for replacement in replacements:
        ea_id = str(replacement["ea_id"])
        directories = sorted(path for path in ea_root.glob(f"{ea_id}_*") if path.is_dir())
        if len(directories) != 1:
            raise ApplyError(
                f"adopted binary directory is not unique for {ea_id}: "
                f"found={len(directories)}"
            )
        ex5_files = sorted(path for path in directories[0].glob("*.ex5") if path.is_file())
        if len(ex5_files) != 1:
            raise ApplyError(
                f"adopted repo-tree EX5 is not unique for {ea_id}: "
                f"found={len(ex5_files)}"
            )
        ex5_path = ex5_files[0]
        actual = sha256_file(ex5_path)
        expected = str(replacement["new_ex5_sha256"])
        if actual != expected:
            raise ApplyError(
                f"adopted repo-tree EX5 hash mismatch for {ea_id}: "
                f"expected={expected} actual={actual} path={ex5_path}"
            )
        checks.append(
            {
                "ea_id": ea_id,
                "repo_ex5_path": str(ex5_path),
                "new_ex5_sha256": actual,
            }
        )
    return checks


def _read_bound_overlay_state(
    path: Path,
    *,
    expected_overlay_sha256: str,
    expected_tail_event_sha256: str,
) -> tuple[bytes, list[dict[str, Any]], str, str]:
    if not path.is_file():
        raise ApplyError(f"bound overlay is missing: {path}")
    if not path.parent.is_dir():
        raise ApplyError(f"overlay parent directory is missing: {path.parent}")
    expected_file = _require_sha256(
        expected_overlay_sha256,
        field="expected overlay sha256",
    )
    expected_tail = _require_sha256(
        expected_tail_event_sha256,
        field="expected tail event sha256",
    )
    events, tail = validate_overlay_chain(path)
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ApplyError(f"overlay is unreadable: {path}: {exc}") from exc
    actual_file = hashlib.sha256(raw).hexdigest()
    if tail != expected_tail:
        raise ApplyError(
            "overlay tail drift: "
            f"expected={expected_tail} actual={tail}"
        )
    if len(events) != EXPECTED_OVERLAY_EVENT_COUNT:
        raise ApplyError(
            "overlay event count drift: "
            f"expected={EXPECTED_OVERLAY_EVENT_COUNT} actual={len(events)}"
        )
    if actual_file != expected_file:
        raise ApplyError(
            "overlay file hash drift: "
            f"expected={expected_file} actual={actual_file}"
        )
    if raw and not raw.endswith(b"\n"):
        raise ApplyError("overlay does not end at a complete JSONL record")
    if len(raw.splitlines()) != len(events):
        raise ApplyError("overlay byte and validated event counts disagree")
    event_ids = [str(event.get("event_id") or "") for event in events]
    if any(not valid_sha256(event_id) for event_id in event_ids):
        raise ApplyError("overlay contains an invalid event_id")
    if len(event_ids) != len(set(event_ids)):
        raise ApplyError("overlay contains duplicate event_id values")
    return raw, events, expected_tail, actual_file


def _live_action(priority: str) -> str:
    if priority == "P0_ADMISSION":
        return "NO_AUTOMATIC_LIVE_ACTION"
    if priority == "P1_HISTORY":
        return "NO_RUNTIME_ACTION"
    raise ApplyError(f"unsupported bill priority: {priority}")


def _build_overlay_candidates(
    *,
    bill: Mapping[str, Any],
    bill_sha256: str,
    events: Sequence[Mapping[str, Any]],
    reviewer: str,
    observed_at_utc: str,
    apply_tool_sha256: str,
) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for bill_event in events:
        work_item_id = str(bill_event["work_item_id"])
        priority = str(bill_event["priority"])
        binding = {
            "schema": BINDING_SCHEMA,
            "bill_schema": bill["schema_version"],
            "bill_sha256": bill_sha256,
            "bill_status": bill["status"],
            "source_commit": bill["source_commit"],
            "work_item_id": work_item_id,
            "raw_row_sha256": bill_event["raw_row_sha256"],
            "phase": bill_event["phase"],
            "ea_id": bill_event["ea_id"],
            "symbol": bill_event["symbol"],
            "original_verdict": bill_event["original_verdict"],
            "new_ex5_sha256": bill_event["new_ex5_sha256"],
            "proposed_effective_status": EXPECTED_EFFECTIVE_STATUS,
            "reason_class": EXPECTED_REASON_CLASS,
        }
        event = {
            "schema": OVERLAY_SCHEMA,
            "tool": TOOL_ID,
            "apply_tool": APPLY_TOOL,
            "apply_tool_sha256": apply_tool_sha256,
            "reviewer": reviewer,
            "observed_at_utc": observed_at_utc,
            "work_item_id": work_item_id,
            "raw_row_sha256": bill_event["raw_row_sha256"],
            "phase": bill_event["phase"],
            "ea_id": bill_event["ea_id"],
            "symbol": bill_event["symbol"],
            "original_status": "done",
            "original_verdict": bill_event["original_verdict"],
            "effective_admission_status": EXPECTED_EFFECTIVE_STATUS,
            "proposed_effective_status": EXPECTED_EFFECTIVE_STATUS,
            "reason_classes": [EXPECTED_REASON_CLASS],
            "reason_class": EXPECTED_REASON_CLASS,
            "priority": priority,
            "live_action": _live_action(priority),
            "adjudication_fingerprint_sha256": canonical_sha256(binding),
            "bill_schema": bill["schema_version"],
            "bill_sha256": bill_sha256,
            "bill_status": bill["status"],
            "bill_source_commit": bill["source_commit"],
            "bill_previous_effective_status": bill_event.get(
                "current_effective_status"
            ),
            "bill_previous_reason_classes": list(
                bill_event.get("current_reason_classes") or []
            ),
            "new_ex5_sha256": bill_event["new_ex5_sha256"],
            "required_rerun": bill_event.get("required_rerun"),
        }
        identity = dict(event)
        identity.pop("reviewer")
        identity.pop("observed_at_utc")
        event["event_id"] = canonical_sha256(identity)
        candidates.append(event)
    return candidates


def _sign_batch(
    *,
    candidates: Sequence[Mapping[str, Any]],
    previous_tail: str,
    existing_event_ids: set[str],
    first_line_number: int,
) -> tuple[list[dict[str, Any]], bytes, str, list[dict[str, Any]]]:
    previous = previous_tail
    signed: list[dict[str, Any]] = []
    chunks: list[bytes] = []
    receipt_rows: list[dict[str, Any]] = []
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
        signed.append(event)
        chunks.append(encoded)
        receipt_rows.append(
            {
                "line_number": first_line_number + offset,
                "work_item_id": event["work_item_id"],
                "ea_id": event["ea_id"],
                "symbol": event["symbol"],
                "phase": event["phase"],
                "raw_row_sha256": event["raw_row_sha256"],
                "new_ex5_sha256": event["new_ex5_sha256"],
                "event_id": event_id,
                "previous_event_sha256": previous,
                "event_sha256": event["event_sha256"],
            }
        )
        previous = str(event["event_sha256"])
        existing_event_ids.add(event_id)
    return signed, b"".join(chunks), previous, receipt_rows


def _write_all(descriptor: int, payload: bytes) -> None:
    view = memoryview(payload)
    while view:
        written = os.write(descriptor, view)
        if written <= 0:
            raise OSError("write made no progress")
        view = view[written:]


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


def _append_fsync_per_line(
    path: Path,
    *,
    before: bytes,
    signed_events: Sequence[Mapping[str, Any]],
) -> None:
    actual = path.read_bytes()
    if actual != before:
        raise ApplyError("overlay content changed before append")
    descriptor = os.open(path, os.O_APPEND | os.O_WRONLY | OS_BINARY)
    try:
        for event in signed_events:
            _write_all(descriptor, canonical_json_bytes(event) + b"\n")
            os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _write_receipt_create_only(path: Path, receipt: Mapping[str, Any]) -> None:
    if not path.parent.is_dir():
        raise ApplyError(f"receipt parent directory does not exist: {path.parent}")
    payload = json.dumps(
        receipt,
        ensure_ascii=False,
        sort_keys=True,
        indent=2,
    ).encode("utf-8") + b"\n"
    try:
        descriptor = os.open(
            path,
            os.O_CREAT | os.O_EXCL | os.O_WRONLY | OS_BINARY,
            0o600,
        )
    except FileExistsError as exc:
        raise ApplyError(f"receipt path already exists: {path}") from exc
    try:
        _write_all(descriptor, payload)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _verify_all(
    *,
    bill_path: Path,
    expected_bill_sha256: str,
    db_path: Path,
    repo_root: Path,
    overlay_path: Path,
    expected_overlay_sha256: str,
    expected_tail_event_sha256: str,
    reviewer: str,
    observed_at_utc: str,
) -> dict[str, Any]:
    if not reviewer.strip():
        raise ApplyError("--reviewer must not be empty")
    bill, bill_sha256 = _load_json_with_hash(bill_path)
    bill_events, replacements = _validate_static_bill(
        bill,
        bill_sha256=bill_sha256,
        expected_bill_sha256=expected_bill_sha256,
    )
    row_checks = _verify_database_rows(db_path=db_path, events=bill_events)
    binary_checks = _verify_adopted_binaries(
        repo_root=repo_root,
        replacements=replacements,
    )
    before, existing, before_tail, before_sha256 = _read_bound_overlay_state(
        overlay_path,
        expected_overlay_sha256=expected_overlay_sha256,
        expected_tail_event_sha256=expected_tail_event_sha256,
    )
    tool_path = Path(__file__).resolve()
    tool_sha256 = sha256_file(tool_path)
    candidates = _build_overlay_candidates(
        bill=bill,
        bill_sha256=bill_sha256,
        events=bill_events,
        reviewer=reviewer.strip(),
        observed_at_utc=observed_at_utc,
        apply_tool_sha256=tool_sha256,
    )
    signed, append_payload, after_tail, receipt_rows = _sign_batch(
        candidates=candidates,
        previous_tail=before_tail,
        existing_event_ids={str(event.get("event_id")) for event in existing},
        first_line_number=len(existing) + 1,
    )
    return {
        "bill": bill,
        "bill_events": bill_events,
        "bill_sha256": bill_sha256,
        "row_checks": row_checks,
        "binary_checks": binary_checks,
        "before": before,
        "existing": existing,
        "before_tail": before_tail,
        "before_sha256": before_sha256,
        "tool_path": tool_path,
        "tool_sha256": tool_sha256,
        "candidates": candidates,
        "signed": signed,
        "append_payload": append_payload,
        "after_tail": after_tail,
        "receipt_rows": receipt_rows,
    }


def apply_bill(
    *,
    bill_path: Path,
    expected_bill_sha256: str,
    db_path: Path,
    repo_root: Path,
    overlay_path: Path,
    expected_overlay_sha256: str,
    expected_tail_event_sha256: str,
    reviewer: str,
    observed_at_utc: str,
    apply: bool,
    receipt_path: Path | None,
) -> dict[str, Any]:
    if not apply:
        verified = _verify_all(
            bill_path=bill_path,
            expected_bill_sha256=expected_bill_sha256,
            db_path=db_path,
            repo_root=repo_root,
            overlay_path=overlay_path,
            expected_overlay_sha256=expected_overlay_sha256,
            expected_tail_event_sha256=expected_tail_event_sha256,
            reviewer=reviewer,
            observed_at_utc=observed_at_utc,
        )
        before = verified["before"]
        append_payload = verified["append_payload"]
        rows = verified["receipt_rows"]
        return {
            "schema": APPLY_SCHEMA,
            "status": "DRY_RUN_VERIFIED_NO_MUTATION",
            "observed_at_utc": observed_at_utc,
            "reviewer": reviewer.strip(),
            "bill_path": str(bill_path),
            "bill_sha256": verified["bill_sha256"],
            "bill_status": verified["bill"]["status"],
            "database": str(db_path),
            "database_open_mode": "ro/query_only",
            "database_rows_verified": len(verified["row_checks"]),
            "repo_root": str(repo_root),
            "adopted_binaries_verified": verified["binary_checks"],
            "apply_tool_path": str(verified["tool_path"]),
            "apply_tool_sha256": verified["tool_sha256"],
            "overlay": {
                "path": str(overlay_path),
                "before_event_count": len(verified["existing"]),
                "before_tail_event_sha256": verified["before_tail"],
                "before_bytes": len(before),
                "before_bytes_sha256": verified["before_sha256"],
                "planned_append_count": len(rows),
                "planned_after_event_count": len(verified["existing"]) + len(rows),
                "planned_after_tail_event_sha256": verified["after_tail"],
                "planned_after_bytes": len(before) + len(append_payload),
                "planned_after_bytes_sha256": hashlib.sha256(
                    before + append_payload
                ).hexdigest(),
                "chain_validation": "PASS",
            },
            "candidate_event_ids": [row["event_id"] for row in rows],
            "rows": rows,
            "raw_work_item_mutations": 0,
            "overlay_writes": 0,
            "receipt_writes": 0,
        }

    if receipt_path is None:
        raise ApplyError("--receipt-out is required with --apply")
    if receipt_path.exists():
        raise ApplyError(f"receipt path already exists: {receipt_path}")
    if not receipt_path.parent.is_dir():
        raise ApplyError(f"receipt parent directory does not exist: {receipt_path.parent}")

    lock_descriptor, lock_record = _acquire_sidecar_lock(overlay_path)
    try:
        verified = _verify_all(
            bill_path=bill_path,
            expected_bill_sha256=expected_bill_sha256,
            db_path=db_path,
            repo_root=repo_root,
            overlay_path=overlay_path,
            expected_overlay_sha256=expected_overlay_sha256,
            expected_tail_event_sha256=expected_tail_event_sha256,
            reviewer=reviewer,
            observed_at_utc=observed_at_utc,
        )
        _append_fsync_per_line(
            overlay_path,
            before=verified["before"],
            signed_events=verified["signed"],
        )

        after_events, validated_tail = validate_overlay_chain(overlay_path)
        after_bytes = overlay_path.read_bytes()
        expected_after = verified["before"] + verified["append_payload"]
        if after_bytes != expected_after:
            raise ApplyError("post-append overlay bytes mismatch")
        if len(after_events) != len(verified["existing"]) + len(verified["signed"]):
            raise ApplyError("post-append overlay event count mismatch")
        if validated_tail != verified["after_tail"]:
            raise ApplyError("post-append overlay tail mismatch")

        post_bill, post_bill_sha256 = _load_json_with_hash(bill_path)
        if post_bill_sha256 != verified["bill_sha256"] or post_bill != verified["bill"]:
            raise ApplyError("bill changed across overlay append")
        post_rows = _verify_database_rows(
            db_path=db_path,
            events=verified["bill_events"],
        )
        before_rows = {
            str(row["work_item_id"]): str(row["raw_row_sha256"])
            for row in verified["row_checks"]
        }
        after_rows = {
            str(row["work_item_id"]): str(row["raw_row_sha256"])
            for row in post_rows
        }
        if before_rows != after_rows:
            raise ApplyError("database rows changed across overlay append")
        post_binaries = _verify_adopted_binaries(
            repo_root=repo_root,
            replacements=verified["bill"]["binary_replacements"],
        )
        if post_binaries != verified["binary_checks"]:
            raise ApplyError("adopted binary bindings changed across overlay append")

        receipt = {
            "schema": APPLY_SCHEMA,
            "status": "APPLIED",
            "applied_at_utc": observed_at_utc,
            "reviewer": reviewer.strip(),
            "bill_path": str(bill_path),
            "bill_sha256": verified["bill_sha256"],
            "bill_status": verified["bill"]["status"],
            "database": str(db_path),
            "database_open_mode": "ro/query_only",
            "database_rows_reverified_unchanged": len(after_rows),
            "raw_row_hash_algorithm": (
                "sha256(canonical-json(mnt_closure_drift.work_item_snapshot(row)))"
            ),
            "raw_work_item_mutations": 0,
            "repo_root": str(repo_root),
            "adopted_binaries_verified": verified["binary_checks"],
            "apply_tool_path": str(verified["tool_path"]),
            "apply_tool_sha256": verified["tool_sha256"],
            "overlay": {
                "path": str(overlay_path),
                "before_event_count": len(verified["existing"]),
                "before_tail_event_sha256": verified["before_tail"],
                "before_bytes": len(verified["before"]),
                "before_bytes_sha256": verified["before_sha256"],
                "appended_event_count": len(verified["signed"]),
                "after_event_count": len(after_events),
                "after_tail_event_sha256": validated_tail,
                "after_bytes": len(after_bytes),
                "after_bytes_sha256": hashlib.sha256(after_bytes).hexdigest(),
                "chain_validation": "PASS",
                "publication": "append_fsync_per_line_under_create_only_sidecar_lock",
            },
            "candidate_event_ids": [
                row["event_id"] for row in verified["receipt_rows"]
            ],
            "rows": verified["receipt_rows"],
        }
        receipt["receipt_fingerprint_sha256"] = canonical_sha256(receipt)
        _write_receipt_create_only(receipt_path, receipt)
        return receipt
    finally:
        _release_sidecar_lock(
            overlay_path,
            lock_descriptor,
            lock_record,
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bill", type=Path, required=True)
    parser.add_argument(
        "--expected-bill-sha256",
        type=_parse_sha256,
        required=True,
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    parser.add_argument("--overlay", type=Path, default=DEFAULT_OVERLAY)
    parser.add_argument(
        "--expected-overlay-sha256",
        type=_parse_sha256,
        required=True,
    )
    parser.add_argument(
        "--expected-tail-event-sha256",
        type=_parse_sha256,
        required=True,
    )
    parser.add_argument("--reviewer", required=True)
    parser.add_argument("--receipt-out", type=Path)
    parser.add_argument("--observed-at-utc", type=_parse_utc, default=None)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_false",
        dest="apply",
        help="verify and print the candidate batch without writes (default)",
    )
    mode.add_argument(
        "--apply",
        action="store_true",
        help="append the reviewed bill and create the receipt",
    )
    parser.set_defaults(apply=False)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = apply_bill(
            bill_path=args.bill,
            expected_bill_sha256=args.expected_bill_sha256,
            db_path=args.db,
            repo_root=args.repo_root,
            overlay_path=args.overlay,
            expected_overlay_sha256=args.expected_overlay_sha256,
            expected_tail_event_sha256=args.expected_tail_event_sha256,
            reviewer=args.reviewer,
            observed_at_utc=args.observed_at_utc or _utc_now(),
            apply=bool(args.apply),
            receipt_path=args.receipt_out,
        )
    except (OSError, sqlite3.Error, ApplyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
