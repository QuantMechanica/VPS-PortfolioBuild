#!/usr/bin/env python3
"""Shared fail-closed live observability contract for operator surfaces.

``live_book_pulse`` is the producer of this contract.  Morning Brief and
Mission Control consume the producer block and only *re-observe* its original
per-source timestamps.  Consequently a newly-written consumer envelope cannot
make an old DD-guard, account snapshot, pulse, pointer, or manifest look fresh.

This module is observation-only.  It does not change a trading, pipeline, or
deployment verdict and never reads from or writes to T_Live.
"""

from __future__ import annotations

import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "qm.live_observability.v1"

DEFAULT_POINTER_PATH = Path(r"D:\QM\reports\state\live_deployment_pointer.json")
DEFAULT_DD_GUARD_PATH = Path(r"D:\QM\reports\state\live_book_dd_guard_state.json")
DEFAULT_PULSE_PATH = Path(r"D:\QM\reports\state\live_book_pulse.json")

# These bounds describe the source cadence/validity, not the cadence of a
# consumer that happens to wrap the data.  In particular, the DD guard runs at
# five-minute cadence and its timer-driven account input is allowed to be at
# most 180 seconds old when the guard evaluates it.
SOURCE_MAX_AGE_SEC: dict[str, int] = {
    "deploy_pointer": 90 * 24 * 60 * 60,
    "manifest": 90 * 24 * 60 * 60,
    "live_pulse": 45 * 60,
    "dd_guard": 10 * 60,
    "account_snapshot": 180,
}
SOURCE_NAMES = tuple(SOURCE_MAX_AGE_SEC)
FINGERPRINT_NAMES = (
    "manifest_sha256",
    "sleeve_sha256",
    "account_sha256",
    "state_sha256",
)


def _utc(value: dt.datetime | None = None) -> dt.datetime:
    value = value or dt.datetime.now(dt.timezone.utc)
    if value.tzinfo is None:
        value = value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc)


def _iso(value: dt.datetime | None) -> str | None:
    if value is None:
        return None
    return _utc(value).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _parse_utc(value: object) -> dt.datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    return _utc(parsed)


def _canonical_sha256(value: Any) -> str:
    rendered = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        default=str,
    )
    return hashlib.sha256(rendered.encode("utf-8")).hexdigest()


def _sha256_file(path: Path | None) -> str | None:
    if path is None:
        return None
    try:
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                digest.update(chunk)
        return digest.hexdigest()
    except OSError:
        return None


def _read_dict(path: Path | None) -> tuple[dict[str, Any] | None, str | None]:
    if path is None:
        return None, "path_missing"
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except OSError as exc:
        return None, f"unreadable:{type(exc).__name__}"
    except (UnicodeError, json.JSONDecodeError) as exc:
        return None, f"malformed:{type(exc).__name__}"
    if not isinstance(payload, dict):
        return None, "malformed:root_not_object"
    return payload, None


def _is_sha256(value: object) -> bool:
    text = str(value or "").lower()
    return len(text) == 64 and all(ch in "0123456789abcdef" for ch in text)


def _freshness(
    source_generated_at_utc: object,
    observed_at: dt.datetime,
    max_age_sec: int,
) -> tuple[str, int | None, str | None]:
    generated = _parse_utc(source_generated_at_utc)
    if generated is None:
        return "UNKNOWN", None, "source_timestamp_missing_or_invalid"
    age = int((observed_at - generated).total_seconds())
    if age < -300:
        return "UNKNOWN", age, "source_timestamp_more_than_300s_in_future"
    age = max(0, age)
    if age > max_age_sec:
        return "STALE", age, f"source_age_{age}s_exceeds_{max_age_sec}s"
    return "FRESH", age, None


def _source_record(
    name: str,
    *,
    generated_at: object,
    observed_at: dt.datetime,
    fingerprint: str | None,
    source_path: Path | None,
    source_error: str | None = None,
    timestamp_basis: str,
) -> dict[str, Any]:
    max_age = SOURCE_MAX_AGE_SEC[name]
    freshness, age, freshness_error = _freshness(generated_at, observed_at, max_age)
    error = source_error or freshness_error
    if source_error:
        freshness = "UNKNOWN"
    generated = _parse_utc(generated_at)
    return {
        "source_generated_at_utc": _iso(generated),
        "observed_at_utc": _iso(observed_at),
        "max_age_sec": max_age,
        "age_sec": age,
        "freshness": freshness,
        "source_fingerprint_sha256": fingerprint if _is_sha256(fingerprint) else None,
        "source_path": str(source_path) if source_path is not None else None,
        "timestamp_basis": timestamp_basis,
        "source_error": source_error,
        "error": error,
    }


def _pulse_state_projection(pulse: dict[str, Any]) -> dict[str, Any]:
    """Stable pulse facts; deliberately excludes this contract and wrappers."""
    terminal = pulse.get("terminal_journals") or {}
    heartbeat = pulse.get("heartbeat") or {}
    manifest = pulse.get("book_manifest") or {}
    return {
        "schema_version": pulse.get("schema_version"),
        "generated_at_utc": pulse.get("generated_at_utc"),
        "verdict": pulse.get("verdict"),
        "alarms": pulse.get("alarms"),
        "book_manifest": {
            "sha256": manifest.get("sha256"),
            "book": manifest.get("book"),
            "status": manifest.get("status"),
            "expected_sleeve_count": manifest.get("expected_sleeve_count"),
        },
        "deploy_pointer_reconciliation": pulse.get("deploy_pointer_reconciliation"),
        "manifest_reconcile": pulse.get("manifest_reconcile"),
        "preset_consistency": pulse.get("preset_consistency"),
        "terminal": {
            "account_id": terminal.get("account_id"),
            "loaded_sleeve_count": terminal.get("loaded_sleeve_count"),
            "last_terminal_sync": terminal.get("last_terminal_sync"),
        },
        "heartbeat": {
            "last_journal_write_utc": heartbeat.get("last_journal_write_utc"),
            "latest_scan_finished": heartbeat.get("latest_scan_finished"),
            "position_exposed": heartbeat.get("position_exposed"),
            "alarm": heartbeat.get("alarm"),
        },
    }


def _overall_status(sources: dict[str, dict[str, Any]]) -> str:
    states = [str((sources.get(name) or {}).get("freshness") or "UNKNOWN") for name in SOURCE_NAMES]
    if any(state == "UNKNOWN" for state in states):
        return "UNKNOWN"
    if any(state == "STALE" for state in states):
        return "STALE"
    return "GREEN" if all(state == "FRESH" for state in states) else "UNKNOWN"


def _latency_block(sources: dict[str, dict[str, Any]]) -> dict[str, Any]:
    dd_ts = _parse_utc((sources.get("dd_guard") or {}).get("source_generated_at_utc"))
    account_ts = _parse_utc((sources.get("account_snapshot") or {}).get("source_generated_at_utc"))
    observed = _parse_utc((sources.get("dd_guard") or {}).get("observed_at_utc"))
    input_gap = int((dd_ts - account_ts).total_seconds()) if dd_ts and account_ts else None
    surface_gap = int((observed - dd_ts).total_seconds()) if observed and dd_ts else None
    return {
        "dd_guard_to_account_snapshot_sec": input_gap,
        "surface_to_dd_guard_sec": max(0, surface_gap) if surface_gap is not None else None,
        "dd_guard_gap_visible": input_gap is not None and surface_gap is not None,
    }


def build_contract(
    pulse: dict[str, Any],
    *,
    observed_at: dt.datetime | None = None,
    pointer_path: Path = DEFAULT_POINTER_PATH,
    dd_guard_path: Path = DEFAULT_DD_GUARD_PATH,
    manifest_path: Path | None = None,
) -> dict[str, Any]:
    """Build the producer contract from the exact sources Pulse observed."""
    observed = _utc(observed_at)
    pointer, pointer_error = _read_dict(Path(pointer_path))
    dd_guard, dd_error = _read_dict(Path(dd_guard_path))
    pointer = pointer or {}
    dd_guard = dd_guard or {}

    if manifest_path is None:
        candidate = pointer.get("manifest_path") or (pulse.get("book_manifest") or {}).get("path")
        manifest_path = Path(candidate) if candidate else None
    else:
        manifest_path = Path(manifest_path)
    manifest, manifest_error = _read_dict(manifest_path)
    manifest = manifest or {}

    pointer_fp = _canonical_sha256(pointer) if not pointer_error else None
    manifest_fp = _sha256_file(manifest_path) if not manifest_error else None
    pulse_fp = _canonical_sha256(_pulse_state_projection(pulse))
    dd_guard_fp = _canonical_sha256(dd_guard) if not dd_error else None

    account_projection = {
        "expected_account": pointer.get("expected_account"),
        "expected_server": pointer.get("expected_server"),
        "expected_phase": pointer.get("expected_phase"),
        "observed_account": (pulse.get("terminal_journals") or {}).get("account_id"),
        "dd_guard_account": dd_guard.get("account_login"),
    }
    account_fp = _canonical_sha256(account_projection)
    account_snapshot_projection = {
        "account_login": dd_guard.get("account_login"),
        "equity_observed_at_utc": dd_guard.get("equity_observed_at_utc"),
        "last_equity": dd_guard.get("last_equity"),
        "last_balance": dd_guard.get("last_balance"),
        "last_free_margin": dd_guard.get("last_free_margin"),
        "equity_source": dd_guard.get("equity_source"),
    }
    account_snapshot_fp = _canonical_sha256(account_snapshot_projection) if not dd_error else None

    sleeves = pointer.get("expected_sleeves") or {}
    sleeve_fp = sleeves.get("identity_sha256") if isinstance(sleeves, dict) else None
    if not _is_sha256(sleeve_fp) and isinstance(sleeves, dict) and isinstance(sleeves.get("roster"), list):
        sleeve_fp = _canonical_sha256(sleeves["roster"])

    sources = {
        "deploy_pointer": _source_record(
            "deploy_pointer",
            generated_at=pointer.get("written_at_utc"),
            observed_at=observed,
            fingerprint=pointer_fp,
            source_path=Path(pointer_path),
            source_error=pointer_error,
            timestamp_basis="deploy_pointer.written_at_utc",
        ),
        "manifest": _source_record(
            "manifest",
            generated_at=(manifest.get("generated_at_utc") or manifest.get("generated_at")),
            observed_at=observed,
            fingerprint=manifest_fp,
            source_path=manifest_path,
            source_error=manifest_error,
            timestamp_basis="manifest.generated_at_utc|generated_at",
        ),
        "live_pulse": _source_record(
            "live_pulse",
            generated_at=pulse.get("generated_at_utc"),
            observed_at=observed,
            fingerprint=pulse_fp,
            source_path=DEFAULT_PULSE_PATH,
            timestamp_basis="live_book_pulse.generated_at_utc",
        ),
        "dd_guard": _source_record(
            "dd_guard",
            generated_at=dd_guard.get("last_run_utc"),
            observed_at=observed,
            fingerprint=dd_guard_fp,
            source_path=Path(dd_guard_path),
            source_error=dd_error,
            timestamp_basis="live_book_dd_guard_state.last_run_utc",
        ),
        "account_snapshot": _source_record(
            "account_snapshot",
            generated_at=dd_guard.get("equity_observed_at_utc"),
            observed_at=observed,
            fingerprint=account_snapshot_fp,
            source_path=Path(dd_guard_path),
            source_error=dd_error,
            timestamp_basis="live_book_dd_guard_state.equity_observed_at_utc",
        ),
    }

    state_projection = {
        "deploy_pointer": pointer_fp,
        "manifest": manifest_fp,
        "live_pulse": pulse_fp,
        "dd_guard": dd_guard_fp,
        "account_snapshot": account_snapshot_fp,
        "source_generated_at_utc": {
            name: sources[name]["source_generated_at_utc"] for name in SOURCE_NAMES
        },
    }
    fingerprints = {
        "manifest_sha256": manifest_fp,
        "sleeve_sha256": sleeve_fp if _is_sha256(sleeve_fp) else None,
        "account_sha256": account_fp,
        "state_sha256": _canonical_sha256(state_projection),
    }
    return {
        "schema_version": SCHEMA_VERSION,
        "observed_at_utc": _iso(observed),
        "status": _overall_status(sources),
        "sources": sources,
        "fingerprints": fingerprints,
        "latency": _latency_block(sources),
        "semantics": "observation_only_no_trading_or_pipeline_verdict_change",
    }


def unknown_contract(observed_at: dt.datetime | None, reason: str) -> dict[str, Any]:
    observed = _utc(observed_at)
    sources = {
        name: _source_record(
            name,
            generated_at=None,
            observed_at=observed,
            fingerprint=None,
            source_path=None,
            source_error=reason,
            timestamp_basis="unavailable",
        )
        for name in SOURCE_NAMES
    }
    return {
        "schema_version": SCHEMA_VERSION,
        "observed_at_utc": _iso(observed),
        "status": "UNKNOWN",
        "sources": sources,
        "fingerprints": {name: None for name in FINGERPRINT_NAMES},
        "latency": _latency_block(sources),
        "semantics": "observation_only_no_trading_or_pipeline_verdict_change",
        "error": reason,
    }


def refresh_contract(contract: object, observed_at: dt.datetime | None = None) -> dict[str, Any]:
    """Re-evaluate source TTLs without changing producer fingerprints.

    Consumer write timestamps are never used as a source freshness anchor.
    Malformed/incomplete producer contracts fail closed to UNKNOWN.
    """
    observed = _utc(observed_at)
    if not isinstance(contract, dict) or contract.get("schema_version") != SCHEMA_VERSION:
        return unknown_contract(observed, "observability_contract_missing_or_wrong_schema")
    raw_sources = contract.get("sources")
    raw_fingerprints = contract.get("fingerprints")
    if not isinstance(raw_sources, dict) or not isinstance(raw_fingerprints, dict):
        return unknown_contract(observed, "observability_contract_missing_sources_or_fingerprints")

    refreshed = copy.deepcopy(contract)
    sources: dict[str, dict[str, Any]] = {}
    for name in SOURCE_NAMES:
        raw = raw_sources.get(name)
        if not isinstance(raw, dict):
            return unknown_contract(observed, f"observability_source_missing:{name}")
        source_error = raw.get("source_error")
        record = _source_record(
            name,
            generated_at=raw.get("source_generated_at_utc"),
            observed_at=observed,
            fingerprint=raw.get("source_fingerprint_sha256"),
            source_path=Path(raw["source_path"]) if raw.get("source_path") else None,
            source_error=str(source_error) if source_error else None,
            timestamp_basis=str(raw.get("timestamp_basis") or "producer_contract"),
        )
        sources[name] = record

    fingerprints = {
        name: (str(raw_fingerprints.get(name)).lower() if _is_sha256(raw_fingerprints.get(name)) else None)
        for name in FINGERPRINT_NAMES
    }
    if any(value is None for value in fingerprints.values()):
        # Identity cannot be claimed cross-surface if any required axis is absent.
        status = "UNKNOWN"
    else:
        status = _overall_status(sources)
    refreshed.update({
        "observed_at_utc": _iso(observed),
        "status": status,
        "sources": sources,
        "fingerprints": fingerprints,
        "latency": _latency_block(sources),
    })
    return refreshed


def load_from_pulse(
    pulse_path: Path = DEFAULT_PULSE_PATH,
    *,
    observed_at: dt.datetime | None = None,
) -> dict[str, Any]:
    pulse, error = _read_dict(Path(pulse_path))
    if error or pulse is None:
        return unknown_contract(observed_at, f"live_pulse_{error or 'missing'}")
    return refresh_contract(pulse.get("observability_contract"), observed_at)
