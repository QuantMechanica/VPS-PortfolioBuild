"""DL-089 Amendment 1 dispatch pruning (default OFF, append-only evidence).

The module is intentionally narrow: it may disposition only still-pending
annual ``OPT_CENSUS`` cells after an authenticated, measured earlier-year floor
break for the same declared arm.  It never edits the ledger, selection rules,
active rows, or pipeline verdicts.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import sqlite3
from pathlib import Path
from typing import Any, Callable, Mapping, Optional

try:
    import opt_census as census
except ModuleNotFoundError:
    from tools.strategy_farm import opt_census as census


ENABLE_ENV = "QM_ENABLE_DL089_PRUNING"
AMENDMENT_ID = "DL-089-AMENDMENT-1-20260827"
AMENDMENT_PATH = (
    census.REPO_ROOT
    / "decisions"
    / "DL-089_amendment_1_deterministic_floor_break_pruning_2026-08-27.md"
)
AMENDMENT_SHA256 = (
    "4635d90aa74151cdf0a081cf7cbb632dbf49023b2bc694b776405d1ee45310d6"
)
RECEIPT_SCHEMA = "qm.dl089-skipped-as-excluded/v1"
DISPOSITION = "skipped_as_excluded"
SKIPPED_VERDICT = "SKIPPED_EXCLUDED"
_TRUE = frozenset({"1", "true", "yes", "on"})


class PruningError(RuntimeError):
    """The enabled pruning contract cannot be authenticated or applied safely."""


def census_measured_verdict() -> str:
    """Keep the dispatch hook explicit without importing the selection driver."""
    return "MEASURED"


def pruning_enabled(env: Optional[Mapping[str, str]] = None) -> bool:
    env = os.environ if env is None else env
    return str(env.get(ENABLE_ENV, "")).strip().lower() in _TRUE


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def receipt_sha256(path: Path) -> str:
    """Public hash helper for consumers authenticating a bound receipt."""
    return _sha256(path)


def authenticate_amendment(path: Path = AMENDMENT_PATH) -> str:
    if not path.is_file():
        raise PruningError(f"DL-089 Amendment 1 missing: {path}")
    actual = _sha256(path)
    if actual != AMENDMENT_SHA256:
        raise PruningError(
            "DL-089 Amendment 1 sha256 mismatch: "
            f"expected={AMENDMENT_SHA256} actual={actual}"
        )
    return actual


def _payload(raw: Any, *, work_item_id: str) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except json.JSONDecodeError as exc:
        raise PruningError(f"{work_item_id}: invalid payload_json") from exc
    if not isinstance(value, dict):
        raise PruningError(f"{work_item_id}: payload_json must be an object")
    return value


def _load_ledger(payload: Mapping[str, Any]) -> tuple[Path, dict[str, Any]]:
    raw_path = str(payload.get("ledger_path") or "").strip()
    if not raw_path:
        raise PruningError("OPT_CENSUS payload has no ledger_path")
    ledger_path = Path(raw_path).resolve()
    if not ledger_path.is_file():
        raise PruningError(f"OPT_CENSUS ledger missing: {ledger_path}")
    try:
        ledger = json.loads(ledger_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PruningError(f"OPT_CENSUS ledger unreadable: {ledger_path}") from exc
    if not isinstance(ledger, dict) or ledger.get("schema") != census.SCHEMA:
        raise PruningError(f"not an authenticated OPT_CENSUS ledger: {ledger_path}")
    if ledger.get("program_id") != payload.get("program_id"):
        raise PruningError("payload/ledger program_id mismatch")
    if ledger.get("activity_floor") != census.ACTIVITY_FLOOR:
        raise PruningError("ledger activity_floor drift; pruning refused")
    if ledger.get("years") != list(census.YEARS):
        raise PruningError("ledger years are not the sealed ascending annual range")
    if ledger.get("wf_windows") != [dict(window) for window in census.WF_WINDOWS]:
        raise PruningError("ledger anchored WF windows drifted; pruning refused")
    if ledger.get("declared_trial_count") != census.DECLARED_TRIAL_COUNT:
        raise PruningError("ledger declared_trial_count drifted; pruning refused")
    return ledger_path, ledger


def _is_initial_annual_candidate(payload: Mapping[str, Any]) -> bool:
    try:
        year = int(payload.get("year"))
    except (TypeError, ValueError):
        return False
    return (
        payload.get("schema") == census.SCHEMA
        and _nonempty(payload.get("program_id"))
        and _nonempty(payload.get("cell_key"))
        and payload.get("opt_census_stage") in (None, "CENSUS")
        and str(payload.get("arm") or "") != "baseline"
        and str(payload.get("direction") or "") in {"BUY", "SELL"}
        and year in census.YEARS
        and payload.get("from_date") == f"{year}.01.01"
        and payload.get("to_date") == f"{year}.12.31"
    )


def _nonempty(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _default_metric_reader(path: Path) -> dict[str, Any]:
    return census.cell_report(path)


def _metric(
    evidence_path: Any,
    reader: Callable[[Path], Mapping[str, Any]],
) -> dict[str, Any]:
    path = Path(str(evidence_path or ""))
    if not path.is_file():
        raise PruningError(f"measured trigger evidence missing: {path}")
    value = dict(reader(path))
    if value.get("report_reconciled") is not True:
        raise PruningError(f"trigger report is not reconciled: {path}")
    try:
        entry_days = int(value["entry_trading_days"])
    except (KeyError, TypeError, ValueError) as exc:
        raise PruningError(f"trigger entry_trading_days invalid: {path}") from exc
    if entry_days < 0:
        raise PruningError(f"trigger entry_trading_days negative: {path}")
    value["entry_trading_days"] = entry_days
    return value


def _declared_cell(
    ledger: Mapping[str, Any],
    work_item_id: str,
) -> Mapping[str, Any]:
    matches = [
        cell
        for cell in ledger.get("cells", [])
        if isinstance(cell, Mapping) and cell.get("work_item_id") == work_item_id
    ]
    if len(matches) != 1:
        raise PruningError(
            f"{work_item_id}: expected one declared ledger cell, found {len(matches)}"
        )
    return matches[0]


def _validate_declared_identity(
    declared: Mapping[str, Any],
    payload: Mapping[str, Any],
) -> None:
    for field_name in ("cell_key", "year", "arm", "direction", "predicate_id"):
        if declared.get(field_name) != payload.get(field_name):
            raise PruningError(
                f"declared cell identity mismatch for {field_name}: "
                f"{declared.get(field_name)!r} != {payload.get(field_name)!r}"
            )


def _receipt_path(ledger_path: Path, work_item_id: str) -> Path:
    return ledger_path.parent / "pruning_receipts" / f"{work_item_id}.json"


def _canonical_receipt_bytes(receipt: Mapping[str, Any]) -> bytes:
    return (
        json.dumps(
            receipt,
            indent=2,
            sort_keys=True,
            ensure_ascii=True,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def validate_receipt(
    path: Path,
    *,
    expected_cell_key: Optional[str] = None,
    expected_trigger_cell_key: Optional[str] = None,
) -> dict[str, Any]:
    try:
        receipt = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PruningError(f"skip receipt unreadable: {path}") from exc
    if not isinstance(receipt, dict):
        raise PruningError(f"skip receipt root is not an object: {path}")
    required = {
        "schema",
        "amendment_id",
        "amendment_sha256",
        "disposition",
        "program_id",
        "arm",
        "cell_key",
        "trigger_cell_key",
        "trigger_work_item_id",
        "trigger_year",
        "skipped_year",
        "trigger_entry_trading_days",
        "activity_floor",
        "declared_trial_count",
        "timestamp",
    }
    missing = sorted(required - receipt.keys())
    if missing:
        raise PruningError(f"skip receipt missing {missing}: {path}")
    if receipt["schema"] != RECEIPT_SCHEMA:
        raise PruningError(f"skip receipt schema mismatch: {path}")
    if receipt["amendment_id"] != AMENDMENT_ID:
        raise PruningError(f"skip receipt amendment mismatch: {path}")
    if receipt["amendment_sha256"] != AMENDMENT_SHA256:
        raise PruningError(f"skip receipt amendment hash mismatch: {path}")
    if receipt["disposition"] != DISPOSITION:
        raise PruningError(f"skip receipt disposition mismatch: {path}")
    if not all(
        _nonempty(receipt.get(key))
        for key in (
            "program_id",
            "arm",
            "cell_key",
            "trigger_cell_key",
            "trigger_work_item_id",
            "timestamp",
        )
    ):
        raise PruningError(f"skip receipt string identity invalid: {path}")
    try:
        trigger_year = int(receipt["trigger_year"])
        skipped_year = int(receipt["skipped_year"])
        trigger_days = int(receipt["trigger_entry_trading_days"])
        activity_floor = int(receipt["activity_floor"])
        declared_count = int(receipt["declared_trial_count"])
    except (TypeError, ValueError) as exc:
        raise PruningError(f"skip receipt numeric contract invalid: {path}") from exc
    if trigger_year not in census.YEARS or skipped_year not in census.YEARS:
        raise PruningError(f"skip receipt year outside sealed census: {path}")
    if skipped_year <= trigger_year:
        raise PruningError(f"skip receipt is not a later-year disposition: {path}")
    if activity_floor != census.ACTIVITY_FLOOR or not 0 <= trigger_days < activity_floor:
        raise PruningError(f"skip receipt floor trigger invalid: {path}")
    if declared_count != census.DECLARED_TRIAL_COUNT:
        raise PruningError(f"skip receipt declared count invalid: {path}")
    if expected_cell_key is not None and receipt["cell_key"] != expected_cell_key:
        raise PruningError(f"skip receipt cell_key collision: {path}")
    if (
        expected_trigger_cell_key is not None
        and receipt["trigger_cell_key"] != expected_trigger_cell_key
    ):
        raise PruningError(f"skip receipt trigger collision: {path}")
    return receipt


def _create_receipt_once(path: Path, receipt: Mapping[str, Any]) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = _canonical_receipt_bytes(receipt)
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except FileExistsError:
        durable = validate_receipt(
            path,
            expected_cell_key=str(receipt["cell_key"]),
            expected_trigger_cell_key=str(receipt["trigger_cell_key"]),
        )
        for key, expected in receipt.items():
            if key != "timestamp" and durable.get(key) != expected:
                raise PruningError(f"skip receipt invariant collision for {key}: {path}")
        return durable
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
    except Exception:
        try:
            path.unlink()
        except OSError:
            pass
        raise
    return dict(receipt)


def _apply_trigger(
    conn: sqlite3.Connection,
    *,
    trigger_row: Mapping[str, Any],
    trigger_payload: Mapping[str, Any],
    metric: Mapping[str, Any],
    now: str,
    target_work_item_id: Optional[str] = None,
) -> dict[str, Any]:
    ledger_path, ledger = _load_ledger(trigger_payload)
    trigger_id = str(trigger_row["id"])
    trigger_declared = _declared_cell(ledger, trigger_id)
    _validate_declared_identity(trigger_declared, trigger_payload)
    entry_days = int(metric["entry_trading_days"])
    floor = int(ledger["activity_floor"])
    if entry_days >= floor:
        return {
            "enabled": True,
            "triggered": False,
            "trigger_cell_key": trigger_payload["cell_key"],
            "entry_trading_days": entry_days,
            "activity_floor": floor,
            "skipped": 0,
            "skipped_ids": [],
        }

    trigger_year = int(trigger_payload["year"])
    targets: list[tuple[int, str, dict[str, Any]]] = []
    active_downstream: list[str] = []
    for row in conn.execute(
        "SELECT id,status,claimed_by,payload_json FROM work_items WHERE phase=?",
        (census.PHASE,),
    ):
        payload = _payload(row["payload_json"], work_item_id=str(row["id"]))
        if (
            payload.get("program_id") != trigger_payload.get("program_id")
            or payload.get("arm") != trigger_payload.get("arm")
        ):
            continue
        try:
            year = int(payload.get("year"))
        except (TypeError, ValueError):
            continue
        if year <= trigger_year:
            continue
        if row["status"] == "active":
            active_downstream.append(str(row["id"]))
            continue
        if row["status"] != "pending" or row["claimed_by"] is not None:
            continue
        if target_work_item_id is not None and str(row["id"]) != target_work_item_id:
            continue
        if not _is_initial_annual_candidate(payload):
            raise PruningError(f"{row['id']}: downstream target is not an annual cell")
        targets.append((year, str(row["id"]), payload))
    targets.sort(key=lambda value: (value[0], value[1]))

    skipped_ids: list[str] = []
    receipt_paths: list[str] = []
    for year, work_item_id, payload in targets:
        declared = _declared_cell(ledger, work_item_id)
        _validate_declared_identity(declared, payload)
        receipt = {
            "schema": RECEIPT_SCHEMA,
            "amendment_id": AMENDMENT_ID,
            "amendment_sha256": AMENDMENT_SHA256,
            "disposition": DISPOSITION,
            "program_id": trigger_payload["program_id"],
            "arm": trigger_payload["arm"],
            "cell_key": payload["cell_key"],
            "trigger_cell_key": trigger_payload["cell_key"],
            "trigger_work_item_id": trigger_id,
            "trigger_year": trigger_year,
            "skipped_year": year,
            "trigger_entry_trading_days": entry_days,
            "activity_floor": floor,
            "declared_trial_count": ledger["declared_trial_count"],
            "timestamp": now,
        }
        receipt_path = _receipt_path(ledger_path, work_item_id)
        durable = _create_receipt_once(receipt_path, receipt)
        receipt_sha = _sha256(receipt_path)
        payload[DISPOSITION] = {
            "amendment_id": AMENDMENT_ID,
            "cell_key": durable["cell_key"],
            "trigger_cell_key": durable["trigger_cell_key"],
            "timestamp": durable["timestamp"],
            "receipt_path": str(receipt_path.resolve()),
            "receipt_sha256": receipt_sha,
        }
        cursor = conn.execute(
            """
            UPDATE work_items
            SET status='done',verdict=?,evidence_path=?,claimed_by=NULL,
                payload_json=?,updated_at=?
            WHERE id=? AND status='pending' AND claimed_by IS NULL
            """,
            (
                SKIPPED_VERDICT,
                str(receipt_path.resolve()),
                json.dumps(payload, sort_keys=True),
                now,
                work_item_id,
            ),
        )
        if cursor.rowcount != 1:
            raise PruningError(f"skip compare-and-set lost: {work_item_id}")
        skipped_ids.append(work_item_id)
        receipt_paths.append(str(receipt_path.resolve()))
    return {
        "enabled": True,
        "triggered": True,
        "trigger_cell_key": trigger_payload["cell_key"],
        "entry_trading_days": entry_days,
        "activity_floor": floor,
        "skipped": len(skipped_ids),
        "skipped_ids": skipped_ids,
        "receipt_paths": receipt_paths,
        "active_downstream_untouched": sorted(active_downstream),
        "declared_trial_count": ledger["declared_trial_count"],
    }


def prune_after_completed_measurement(
    conn: sqlite3.Connection,
    *,
    work_item_id: str,
    now: Optional[str] = None,
    env: Optional[Mapping[str, str]] = None,
    metric_reader: Callable[[Path], Mapping[str, Any]] = _default_metric_reader,
) -> dict[str, Any]:
    """Disposition all pending later years immediately after a measured break."""
    if not pruning_enabled(env):
        return {"enabled": False, "triggered": False, "skipped": 0}
    authenticate_amendment()
    row = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (work_item_id,)
    ).fetchone()
    if row is None:
        raise PruningError(f"completed trigger row missing: {work_item_id}")
    if row["phase"] != census.PHASE:
        return {"enabled": True, "triggered": False, "skipped": 0}
    if row["status"] != "done" or row["verdict"] != "MEASURED":
        raise PruningError(f"{work_item_id}: trigger is not done/MEASURED")
    payload = _payload(row["payload_json"], work_item_id=work_item_id)
    if not _is_initial_annual_candidate(payload):
        return {"enabled": True, "triggered": False, "skipped": 0}
    metric = _metric(row["evidence_path"], metric_reader)
    stamp = now or dt.datetime.now(dt.timezone.utc).isoformat()
    return _apply_trigger(
        conn,
        trigger_row=row,
        trigger_payload=payload,
        metric=metric,
        now=stamp,
    )


def inspect_candidate_exclusion(
    conn: sqlite3.Connection,
    candidate_row: Mapping[str, Any],
    *,
    env: Optional[Mapping[str, str]] = None,
    metric_reader: Callable[[Path], Mapping[str, Any]] = _default_metric_reader,
) -> dict[str, Any]:
    """Read-only claim-boundary pruning analysis for speculative preparation.

    This deliberately stops before ``_apply_trigger``: it authenticates the same
    amendment, ledger, candidate identity, earlier measurements, and activity
    floor as the real claim-boundary backstop, but it creates no receipt and
    performs no database write.  The ordinary post-finish claimant must still
    call :func:`prune_candidate_if_excluded` under its existing locks.
    """

    candidate_id = str(candidate_row["id"])
    if not pruning_enabled(env):
        return {"enabled": False, "would_skip_current": False}
    if candidate_row["phase"] != census.PHASE:
        return {"enabled": True, "would_skip_current": False}
    amendment_sha256 = authenticate_amendment()
    candidate = _payload(candidate_row["payload_json"], work_item_id=candidate_id)
    if not _is_initial_annual_candidate(candidate):
        return {"enabled": True, "would_skip_current": False}
    candidate_year = int(candidate["year"])
    ledger_path, ledger = _load_ledger(candidate)
    trigger_rows: list[tuple[int, sqlite3.Row, dict[str, Any]]] = []
    for row in conn.execute(
        """
        SELECT * FROM work_items
        WHERE phase=? AND status='done' AND verdict='MEASURED'
        """,
        (census.PHASE,),
    ):
        payload = _payload(row["payload_json"], work_item_id=str(row["id"]))
        if (
            payload.get("program_id") == candidate.get("program_id")
            and payload.get("arm") == candidate.get("arm")
            and _is_initial_annual_candidate(payload)
            and int(payload["year"]) < candidate_year
        ):
            trigger_rows.append((int(payload["year"]), row, payload))
    trigger_rows.sort(key=lambda value: (value[0], str(value[1]["id"])))
    inspected: list[dict[str, Any]] = []
    trigger: dict[str, Any] | None = None
    for year, row, _payload_value in trigger_rows:
        metric = _metric(row["evidence_path"], metric_reader)
        detail = {
            "work_item_id": str(row["id"]),
            "year": year,
            "evidence_path": str(row["evidence_path"] or ""),
            "entry_trading_days": int(metric["entry_trading_days"]),
        }
        inspected.append(detail)
        if int(metric["entry_trading_days"]) < census.ACTIVITY_FLOOR:
            trigger = detail
            break
    return {
        "enabled": True,
        "would_skip_current": trigger is not None,
        "candidate_id": candidate_id,
        "candidate_year": candidate_year,
        "program_id": str(candidate.get("program_id") or ""),
        "arm": str(candidate.get("arm") or ""),
        "amendment_id": AMENDMENT_ID,
        "amendment_sha256": amendment_sha256,
        "ledger_path": str(ledger_path),
        "ledger_sha256": _sha256(ledger_path),
        "q12_work_item_id": str(ledger.get("q12_work_item_id") or ""),
        "q12_declaration_sha256": str(ledger.get("q12_declaration_sha256") or ""),
        "inspected_predecessors": inspected,
        "trigger": trigger,
    }


def prune_candidate_if_excluded(
    conn: sqlite3.Connection,
    candidate_row: Mapping[str, Any],
    *,
    now: Optional[str] = None,
    env: Optional[Mapping[str, str]] = None,
    metric_reader: Callable[[Path], Mapping[str, Any]] = _default_metric_reader,
) -> dict[str, Any]:
    """Claim-boundary backstop: skip a candidate if an earlier break exists."""
    candidate_id = str(candidate_row["id"])
    if not pruning_enabled(env):
        return {"enabled": False, "skipped_current": False, "skipped": 0}
    if candidate_row["phase"] != census.PHASE:
        return {"enabled": True, "skipped_current": False, "skipped": 0}
    authenticate_amendment()
    candidate = _payload(candidate_row["payload_json"], work_item_id=candidate_id)
    if not _is_initial_annual_candidate(candidate):
        return {"enabled": True, "skipped_current": False, "skipped": 0}
    candidate_year = int(candidate["year"])
    _load_ledger(candidate)  # authenticate invariants before any trigger scan

    trigger_rows: list[tuple[int, sqlite3.Row, dict[str, Any]]] = []
    for row in conn.execute(
        """
        SELECT * FROM work_items
        WHERE phase=? AND status='done' AND verdict='MEASURED'
        """,
        (census.PHASE,),
    ):
        payload = _payload(row["payload_json"], work_item_id=str(row["id"]))
        if (
            payload.get("program_id") == candidate.get("program_id")
            and payload.get("arm") == candidate.get("arm")
            and _is_initial_annual_candidate(payload)
        ):
            year = int(payload["year"])
            if year < candidate_year:
                trigger_rows.append((year, row, payload))
    trigger_rows.sort(key=lambda value: (value[0], str(value[1]["id"])))
    for _year, trigger_row, trigger_payload in trigger_rows:
        metric = _metric(trigger_row["evidence_path"], metric_reader)
        if int(metric["entry_trading_days"]) >= census.ACTIVITY_FLOOR:
            continue
        result = _apply_trigger(
            conn,
            trigger_row=trigger_row,
            trigger_payload=trigger_payload,
            metric=metric,
            now=now or dt.datetime.now(dt.timezone.utc).isoformat(),
        )
        result["skipped_current"] = candidate_id in result["skipped_ids"]
        return result
    return {"enabled": True, "skipped_current": False, "skipped": 0}
