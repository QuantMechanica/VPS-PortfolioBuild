"""Shared health and operating-intent contract for QM watchdog surfaces.

The contract deliberately separates two questions:

* ``status`` says whether the observed facts satisfy the declared intent.
* ``intent`` says whether a subject is expected RUNNING, PARKED, or in
  MAINTENANCE.  Consumers must never infer intent from a process being absent.

Every producer emits the same check keys consumed by ``farmctl health`` and
the aggregate always uses the worst severity.  Unknown statuses and unknown
runtime probes fail closed.
"""

from __future__ import annotations

import datetime as dt
from pathlib import Path
from typing import Any, Iterable, Mapping


SCHEMA = "qm.health.contract.v1"
OK = "OK"
WARN = "WARN"
FAIL = "FAIL"
VALID_STATUSES = {OK, WARN, FAIL}
VALID_INTENTS = {"RUNNING", "PARKED", "MAINTENANCE"}
SEVERITY = {OK: 0, WARN: 1, FAIL: 2}

_STATUS_ALIASES = {
    "OK": OK,
    "PASS": OK,
    "GREEN": OK,
    "HEALTHY": OK,
    "PARKED": OK,
    "WARN": WARN,
    "WARNING": WARN,
    "AMBER": WARN,
    "MAINTENANCE": WARN,
    "FAIL": FAIL,
    "FAILED": FAIL,
    "ALARM": FAIL,
    "ERROR": FAIL,
    "CRITICAL": FAIL,
    "RED": FAIL,
}


def utc_iso(when: dt.datetime | None = None) -> str:
    value = when or dt.datetime.now(dt.timezone.utc)
    if value.tzinfo is None:
        value = value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_status(value: Any) -> str:
    """Return one canonical severity; an unknown producer value fails closed."""
    return _STATUS_ALIASES.get(str(value or "").strip().upper(), FAIL)


def intent(
    expected_state: Any,
    *,
    effective_state: Any | None = None,
    reason: str = "",
    review_expires_utc: str | None = None,
    review_expired: bool = False,
    source: str = "",
) -> dict[str, Any]:
    expected = str(expected_state or "").strip().upper()
    effective = str(effective_state or expected).strip().upper()
    return {
        "expected_state": expected,
        "effective_state": effective,
        "valid": expected in VALID_INTENTS and effective in VALID_INTENTS,
        "reason": str(reason or ""),
        "review_expires_utc": review_expires_utc,
        "review_expired": bool(review_expired),
        "source": str(source or ""),
    }


def check(
    name: str,
    status: Any,
    value: Any = None,
    threshold: Any = None,
    detail: str = "",
    action_hint: str = "",
    *,
    source: str = "",
    layer: str = "observation",
    operating_intent: Mapping[str, Any] | None = None,
    evidence: str | Path | None = None,
) -> dict[str, Any]:
    out: dict[str, Any] = {
        "name": str(name),
        "status": normalize_status(status),
        "value": value,
        "threshold": threshold,
        "detail": str(detail or ""),
        "action_hint": str(action_hint or ""),
        "source": str(source or ""),
        "layer": str(layer or "observation"),
    }
    if operating_intent is not None:
        out["intent"] = dict(operating_intent)
    if evidence is not None:
        out["evidence"] = str(evidence)
    return out


def _canonical_check(raw: Mapping[str, Any], default_source: str) -> dict[str, Any]:
    return check(
        str(raw.get("name") or raw.get("metric") or "unnamed_check"),
        raw.get("status") or raw.get("severity") or raw.get("verdict"),
        raw.get("value"),
        raw.get("threshold"),
        str(raw.get("detail") or ""),
        str(raw.get("action_hint") or raw.get("hint") or ""),
        source=str(raw.get("source") or default_source),
        layer=str(raw.get("layer") or "observation"),
        operating_intent=raw.get("intent") if isinstance(raw.get("intent"), Mapping) else None,
        evidence=raw.get("evidence"),
    )


def build(
    source: str,
    checks: Iterable[Mapping[str, Any]],
    *,
    checked_at: str | None = None,
    operating_intent: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    canonical = [_canonical_check(item, source) for item in checks]
    summary = {
        "ok": sum(item["status"] == OK for item in canonical),
        "warn": sum(item["status"] == WARN for item in canonical),
        "fail": sum(item["status"] == FAIL for item in canonical),
    }
    overall = FAIL if summary["fail"] else WARN if summary["warn"] else OK
    out: dict[str, Any] = {
        "schema": SCHEMA,
        "source": str(source),
        "checked_at": checked_at or utc_iso(),
        "overall": overall,
        "summary": summary,
        "checks": canonical,
    }
    if operating_intent is not None:
        out["intent"] = dict(operating_intent)
    return out


def merge(base: Mapping[str, Any], *surfaces: Mapping[str, Any]) -> dict[str, Any]:
    """Merge health surfaces under worst-severity-wins semantics."""
    source = str(base.get("source") or "farm_health")
    all_checks: list[Mapping[str, Any]] = []
    base_checks = base.get("checks")
    if isinstance(base_checks, list):
        all_checks.extend(item for item in base_checks if isinstance(item, Mapping))
    for surface in surfaces:
        surface_source = str(surface.get("source") or "external_health_surface")
        nested = surface.get("health_contract")
        if isinstance(nested, Mapping):
            surface = nested
            surface_source = str(surface.get("source") or surface_source)
        rows = surface.get("checks")
        if isinstance(rows, list):
            for row in rows:
                if not isinstance(row, Mapping):
                    continue
                normalized = dict(row)
                normalized.setdefault("source", surface_source)
                all_checks.append(normalized)
            continue
        alarms = surface.get("alarms")
        if isinstance(alarms, list):
            for row in alarms:
                if isinstance(row, Mapping):
                    normalized = dict(row)
                    normalized.setdefault("source", surface_source)
                    normalized.setdefault("status", row.get("severity") or FAIL)
                    all_checks.append(normalized)
                elif row:
                    all_checks.append(check(
                        f"{surface_source}_alarm", FAIL, detail=str(row), source=surface_source
                    ))
    result = build(source, all_checks, checked_at=str(base.get("checked_at") or utc_iso()))
    for key, value in base.items():
        if key not in {"checks", "summary", "overall", "schema", "source", "checked_at"}:
            result[key] = value
    return result


def assess_runtime_intent(
    subject: str,
    *,
    expected_state: Any,
    running: bool | None,
    maintenance: bool = False,
    probe_ok: bool = True,
    review_expired: bool = False,
    review_expires_utc: str | None = None,
    source: str = "",
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Assess process facts against explicit RUNNING/PARKED/MAINTENANCE intent."""
    expected = str(expected_state or "").strip().upper()
    effective = "MAINTENANCE" if maintenance or expected == "MAINTENANCE" else expected
    op_intent = intent(
        expected,
        effective_state=effective,
        reason="maintenance_override" if maintenance else "declared",
        review_expires_utc=review_expires_utc,
        review_expired=review_expired,
        source=source,
    )
    if not op_intent["valid"]:
        status, condition = FAIL, "intent_invalid"
        detail = f"{subject}: invalid expected/effective state {expected!r}/{effective!r}"
    elif review_expired:
        status, condition = FAIL, "intent_review_expired"
        detail = f"{subject}: operating-intent review expired at {review_expires_utc}"
    elif effective == "MAINTENANCE":
        status, condition = WARN, "maintenance"
        detail = f"{subject}: planned MAINTENANCE; running={running}"
    elif not probe_ok or running is None:
        status, condition = FAIL, "probe_unknown"
        detail = f"{subject}: runtime state is unknown; refusing to infer health"
    elif expected == "RUNNING" and running:
        status, condition = OK, "running"
        detail = f"{subject}: RUNNING intent satisfied"
    elif expected == "RUNNING":
        status, condition = FAIL, "missing"
        detail = f"{subject}: expected RUNNING but process is absent"
    elif expected == "PARKED" and not running:
        status, condition = OK, "parked"
        detail = f"{subject}: PARKED intent satisfied"
    else:
        status, condition = FAIL, "unexpected_running"
        detail = f"{subject}: expected PARKED but process is running"
    op_intent["condition"] = condition
    return op_intent, check(
        f"{subject}_operating_intent",
        status,
        value=running,
        threshold=expected,
        detail=detail,
        action_hint=(
            "Correct the declared intent or runtime under OWNER authority; monitors must not infer or change it."
            if status == FAIL else ""
        ),
        source=source,
        layer="intent",
        operating_intent=op_intent,
    )
