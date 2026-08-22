"""Read-only census for Q09 rows held while automatic plan sealing is blocked.

The hold is deliberately fail-closed.  This observer makes that safe stop visible
without releasing a hold or mutating a work item.  Both farm health and Mission
Control consume this module so their grouping and thresholds cannot drift.
"""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
from collections import Counter
from typing import Any


SCHEMA_VERSION = "qm.q09_autoseal_hold_census.v1"
HOLD_CODE = "Q09_AWAITING_SEALED_PLAN"
WARN_AGE_HOURS = 1.0
FAIL_AGE_HOURS = 6.0
FAIL_AGED_COUNT = 3
FAIL_REASON_COUNT = 3
EXAMPLE_LIMIT = 5

MISSING_ACTIVATION_STATE = "MISSING_Q09_ACTIVATION_STATE"
NO_FAILURE_REASON = "NO_Q09_AUTOSEAL_FAILURE"
INVALID_PAYLOAD_REASON = "PAYLOAD_JSON_INVALID"
INVALID_OBSERVED_AT_REASON = "OBSERVED_AT_INVALID"


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _parse_utc(value: Any) -> dt.datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _iso(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def collect(con: sqlite3.Connection, *, now: dt.datetime | None = None) -> dict[str, Any]:
    """Return the canonical grouped census from an already read-only connection."""

    now = (now or _utc_now()).astimezone(dt.timezone.utc)
    rows = con.execute(
        """
        SELECT w.id,w.ea_id,w.symbol,w.created_at,
               h.created_at AS held_at,w.payload_json
        FROM work_items w
        JOIN work_item_holds h ON h.work_item_id=w.id
        WHERE w.phase='Q09_NEWS' AND w.status='pending'
          AND h.hold_code=? AND h.active=1
        ORDER BY h.created_at ASC,w.id ASC
        """,
        (HOLD_CODE,),
    ).fetchall()

    parsed_rows: list[dict[str, Any]] = []
    malformed_count = 0
    for row in rows:
        payload_invalid = False
        try:
            payload = json.loads(str(row["payload_json"] or "{}"))
            if not isinstance(payload, dict):
                raise ValueError("payload must be an object")
        except (json.JSONDecodeError, TypeError, ValueError):
            payload = {}
            payload_invalid = True

        activation_state = str(
            payload.get("q09_activation_state") or MISSING_ACTIVATION_STATE
        ).strip()
        failure = payload.get("q09_autoseal_failure")
        if not isinstance(failure, dict):
            failure = {}

        reason_code = str(failure.get("reason_code") or NO_FAILURE_REASON).strip()
        raw_observed_at = failure.get("observed_at")
        observed_at = _parse_utc(raw_observed_at)
        observation_source = "q09_autoseal_failure.observed_at"

        if payload_invalid:
            activation_state = MISSING_ACTIVATION_STATE
            reason_code = INVALID_PAYLOAD_REASON
            observed_at = None
        elif raw_observed_at and observed_at is None:
            reason_code = INVALID_OBSERVED_AT_REASON

        if observed_at is None:
            observation_source = "hold_created_at_fallback"
            observed_at = _parse_utc(row["held_at"] or row["created_at"])

        invalid_timestamp = observed_at is None
        if payload_invalid or invalid_timestamp or reason_code == INVALID_OBSERVED_AT_REASON:
            malformed_count += 1

        age_hours = (
            max(0.0, (now - observed_at).total_seconds() / 3600.0)
            if observed_at is not None
            else None
        )
        parsed_rows.append(
            {
                "id": str(row["id"]),
                "ea_id": str(row["ea_id"] or ""),
                "symbol": str(row["symbol"] or ""),
                "q09_activation_state": activation_state,
                "reason_code": reason_code,
                "observed_at": _iso(observed_at) if observed_at is not None else None,
                "observation_source": observation_source,
                "age_hours": round(age_hours, 3) if age_hours is not None else None,
            }
        )

    groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for row in parsed_rows:
        key = (row["q09_activation_state"], row["reason_code"])
        groups.setdefault(key, []).append(row)

    grouped = []
    for (activation_state, reason_code), members in groups.items():
        timestamps = [r["observed_at"] for r in members if r["observed_at"]]
        ages = [r["age_hours"] for r in members if r["age_hours"] is not None]
        grouped.append(
            {
                "q09_activation_state": activation_state,
                "reason_code": reason_code,
                "count": len(members),
                "oldest_observed_at": min(timestamps) if timestamps else None,
                "oldest_age_hours": max(ages) if ages else None,
                "example_ids": [r["id"] for r in members[:EXAMPLE_LIMIT]],
            }
        )
    grouped.sort(
        key=lambda item: (
            -int(item["count"]),
            str(item["q09_activation_state"]),
            str(item["reason_code"]),
        )
    )

    reason_counts = Counter(r["reason_code"] for r in parsed_rows)
    reason_groups = []
    for reason_code, count in sorted(reason_counts.items(), key=lambda item: (-item[1], item[0])):
        members = [r for r in parsed_rows if r["reason_code"] == reason_code]
        timestamps = [r["observed_at"] for r in members if r["observed_at"]]
        reason_groups.append(
            {
                "reason_code": reason_code,
                "count": count,
                "oldest_observed_at": min(timestamps) if timestamps else None,
                "example_ids": [r["id"] for r in members[:EXAMPLE_LIMIT]],
            }
        )

    aged_over_warn = [
        r for r in parsed_rows
        if r["age_hours"] is not None and r["age_hours"] > WARN_AGE_HOURS
    ]
    aged_over_fail = [
        r for r in parsed_rows
        if r["age_hours"] is not None and r["age_hours"] > FAIL_AGE_HOURS
    ]
    repeated_reasons = {
        reason: count
        for reason, count in reason_counts.items()
        if reason != NO_FAILURE_REASON and count >= FAIL_REASON_COUNT
    }

    status_reasons: list[str] = []
    if malformed_count:
        status_reasons.append(f"malformed_rows={malformed_count}")
    if len(aged_over_fail) >= FAIL_AGED_COUNT:
        status_reasons.append(
            f"aged_over_{FAIL_AGE_HOURS:g}h={len(aged_over_fail)}"
        )
    if repeated_reasons:
        rendered = ",".join(f"{key}:{value}" for key, value in sorted(repeated_reasons.items()))
        status_reasons.append(f"reason_count_gte_{FAIL_REASON_COUNT}={rendered}")

    if status_reasons:
        status = "FAIL"
    elif aged_over_warn:
        status = "WARN"
        status_reasons.append(f"aged_over_{WARN_AGE_HOURS:g}h={len(aged_over_warn)}")
    else:
        status = "OK"
        status_reasons.append("below_warn_and_fail_thresholds")

    observed_timestamps = [r["observed_at"] for r in parsed_rows if r["observed_at"]]
    observed_ages = [r["age_hours"] for r in parsed_rows if r["age_hours"] is not None]
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": _iso(now),
        "hold_code": HOLD_CODE,
        "status": status,
        "status_reasons": status_reasons,
        "total": len(parsed_rows),
        "oldest_observed_at": min(observed_timestamps) if observed_timestamps else None,
        "oldest_age_hours": max(observed_ages) if observed_ages else None,
        "aged_over_warn_count": len(aged_over_warn),
        "aged_over_fail_count": len(aged_over_fail),
        "malformed_count": malformed_count,
        "thresholds": {
            "warn_age_hours_exclusive": WARN_AGE_HOURS,
            "fail_age_hours_exclusive": FAIL_AGE_HOURS,
            "fail_aged_count": FAIL_AGED_COUNT,
            "fail_reason_count": FAIL_REASON_COUNT,
        },
        "groups": grouped,
        "reason_groups": reason_groups,
    }
