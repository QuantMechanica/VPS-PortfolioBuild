#!/usr/bin/env python3
"""Factory-only queue dispatcher for T1-T10 backtests."""

from __future__ import annotations

import os
import random
import tempfile
import time
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from framework.scripts.dl054_gates import apply_post_launch_gates, apply_pre_launch_gates

MT5_ROOT = Path(os.environ.get("QM_MT5_ROOT", r"D:\QM\mt5"))
TERMINALS = tuple(f"T{i}" for i in range(1, 11))
REQUIRED_JOB_FIELDS = ("ea_id", "version", "symbol", "phase", "sub_gate_config_hash", "setfile_path")
MATRIX_REQUIRED_FIELDS = ("ea_id", "version", "phase", "sub_gate_config_hash", "setfile_path", "symbols")
MATRIX_SYMBOL_COUNT = 36
AFFINITY_TTL_SECONDS = 24 * 60 * 60
RECENT_WINDOW_SECONDS = 24 * 60 * 60
DEFAULT_STATE_PATH = Path(r"D:\QM\Reports\pipeline\dispatch_state.json")
DEFAULT_DEDUP_INDEX_PATH = Path(r"D:\QM\Reports\pipeline\dedup_index.json")
DEFAULT_COMPLETED_RETENTION_SECONDS = 48 * 60 * 60


def active_terminals() -> tuple[str, ...]:
    installed = tuple(terminal for terminal in TERMINALS if (MT5_ROOT / terminal / "terminal64.exe").exists())
    return installed if installed else TERMINALS


def _require_non_empty_string(value: Any, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"job.{field_name} must be a non-empty string")
    return value.strip()


def validate_job(job: dict[str, Any]) -> dict[str, str]:
    if not isinstance(job, dict):
        raise ValueError("job must be an object")
    normalized: dict[str, str] = {}
    for field in REQUIRED_JOB_FIELDS:
        normalized[field] = _require_non_empty_string(job.get(field), field)
    if not normalized["symbol"].endswith(".DWX"):
        raise ValueError("job.symbol must end with .DWX")
    return normalized


def validate_matrix_payload(payload: dict[str, Any]) -> tuple[dict[str, str], list[str]]:
    if not isinstance(payload, dict):
        raise ValueError("matrix payload must be an object")
    for field in MATRIX_REQUIRED_FIELDS:
        if field not in payload:
            raise ValueError(f"matrix.{field} is required")
    base_job: dict[str, str] = {}
    for field in ("ea_id", "version", "phase", "sub_gate_config_hash", "setfile_path"):
        base_job[field] = _require_non_empty_string(payload.get(field), field)
    raw_symbols = payload.get("symbols")
    if not isinstance(raw_symbols, list):
        raise ValueError("matrix.symbols must be an array")
    symbols = [_require_non_empty_string(item, "symbol") for item in raw_symbols]
    if len(symbols) != MATRIX_SYMBOL_COUNT:
        raise ValueError(f"matrix.symbols must contain exactly {MATRIX_SYMBOL_COUNT} entries")
    if len(set(symbols)) != len(symbols):
        raise ValueError("matrix.symbols contains duplicates")
    for symbol in symbols:
        if not symbol.endswith(".DWX"):
            raise ValueError(f"matrix symbol must end with .DWX: {symbol}")
    return base_job, symbols


def build_matrix_jobs(payload: dict[str, Any]) -> list[dict[str, str]]:
    base_job, symbols = validate_matrix_payload(payload)
    jobs: list[dict[str, str]] = []
    for symbol in symbols:
        job = dict(base_job)
        job["symbol"] = symbol
        jobs.append(job)
    return jobs


def matrix_bucket_key(job: dict[str, Any]) -> str:
    normalized = validate_job(job)
    return f"{normalized['ea_id']}_{normalized['version']}_{normalized['phase']}"


def _phase_matrix_index(state: dict[str, Any]) -> dict[str, Any]:
    return state.setdefault("phase_matrix_index", {})


def _upsert_matrix_row(bucket: dict[str, Any], symbol: str, terminal: str | None = None) -> dict[str, Any]:
    rows = bucket.setdefault("matrix", [])
    for row in rows:
        if str(row.get("symbol", "")) == symbol:
            if terminal:
                row["terminal"] = terminal
            return row
    row = {
        "symbol": symbol,
        "terminal": terminal,
        "verdict": None,
        "invalidation_reason": None,
        "evidence": None,
    }
    rows.append(row)
    return row


def _coerce_utc_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)
    if isinstance(value, str) and value.strip():
        text = value.strip().replace("Z", "+00:00")
        dt = datetime.fromisoformat(text)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    raise ValueError("window_start/window_end must be datetime or ISO-8601 string")


def _append_report_csv_row(
    report_csv_path: str | None,
    *,
    ea_id: str,
    phase: str,
    symbol: str,
    terminal: str,
    verdict: str,
    invalidation_reason: str = "",
    evidence: str = "",
) -> None:
    if not report_csv_path:
        return
    path = Path(report_csv_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    needs_header = (not path.exists()) or path.stat().st_size == 0
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        if needs_header:
            handle.write("ea_id,phase,symbol,terminal,verdict,invalidation_reason,evidence\n")
        fields = [
            ea_id,
            phase,
            symbol,
            terminal,
            verdict,
            (invalidation_reason or "").replace(",", ";").replace("\n", " "),
            evidence or "",
        ]
        handle.write(",".join(fields) + "\n")


def dispatch_or_invalidate(
    job: dict[str, Any],
    state: dict[str, Any],
    *,
    terminal: str,
    window_start: Any,
    window_end: Any,
    launch_config: dict[str, Any],
    report_csv_path: str | None = None,
    max_per_terminal: int = 3,
    now_epoch: int | None = None,
) -> Any | None:
    normalized_job = validate_job(job)
    pre = apply_pre_launch_gates(
        ea_id=normalized_job["ea_id"],
        phase=normalized_job["phase"],
        symbol=normalized_job["symbol"],
        terminal=terminal,
        window_start=_coerce_utc_datetime(window_start),
        window_end=_coerce_utc_datetime(window_end),
        launch_config=launch_config,
    )
    if pre.verdict == "INVALID":
        _, bucket = _ensure_matrix_bucket(state, normalized_job)
        row = _upsert_matrix_row(bucket, symbol=normalized_job["symbol"], terminal=terminal)
        row["verdict"] = "INVALID"
        row["invalidation_reason"] = pre.invalidation_reason
        row["evidence"] = "pipeline_dispatcher.py:prelaunch"
        _append_report_csv_row(
            report_csv_path,
            ea_id=normalized_job["ea_id"],
            phase=normalized_job["phase"],
            symbol=normalized_job["symbol"],
            terminal=terminal,
            verdict="INVALID",
            invalidation_reason=pre.invalidation_reason,
            evidence="pipeline_dispatcher.py:prelaunch",
        )
        _refresh_phase_verdict(bucket, pass_threshold=1, fail_phase_label=None)
        return None
    return pre


def _ensure_matrix_bucket(state: dict[str, Any], job: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    key = matrix_bucket_key(job)
    index = _phase_matrix_index(state)
    bucket = index.setdefault(key, {"matrix": [], "phase_verdict": None, "next_strategy_unblocked": None})
    return key, bucket


def initialize_matrix_bucket_for_symbols(state: dict[str, Any], jobs: list[dict[str, Any]]) -> None:
    """Reset matrix rows to current symbol cohort and clear matching stale dedup keys."""
    if not jobs:
        return
    normalized_jobs = [validate_job(job) for job in jobs]
    _, bucket = _ensure_matrix_bucket(state, normalized_jobs[0])
    cohort = normalized_jobs[0]
    cohort_ea = cohort["ea_id"].strip().lower()
    cohort_version = cohort["version"].strip().lower()
    cohort_phase = cohort["phase"].strip().upper()
    cohort_symbols = {job["symbol"].strip().upper() for job in normalized_jobs}
    dedup = state.setdefault("dedup", {})
    remove_keys: list[str] = []
    for key in dedup:
        parts = key.split("|")
        if len(parts) != 5:
            continue
        ea_id, version, symbol, phase, _hash = parts
        key_ea = ea_id.strip().lower()
        key_version = version.strip().lower()
        key_symbol = symbol.strip().upper()
        key_phase = phase.strip().upper()
        if (
            key_ea == cohort_ea
            and key_version == cohort_version
            and key_phase == cohort_phase
            and key_symbol in cohort_symbols
        ):
            remove_keys.append(key)
    for key in remove_keys:
        dedup.pop(key, None)
    existing_rows = {
        str(row.get("symbol", "")): row
        for row in bucket.get("matrix", [])
        if isinstance(row, dict) and isinstance(row.get("symbol"), str)
    }
    refreshed_rows: list[dict[str, Any]] = []
    for normalized in normalized_jobs:
        symbol = normalized["symbol"]
        prior = existing_rows.get(symbol, {})
        refreshed_rows.append(
            {
                "symbol": symbol,
                "terminal": prior.get("terminal"),
                "verdict": None,
                "invalidation_reason": None,
                "evidence": None,
            }
        )
    bucket["matrix"] = refreshed_rows
    bucket["phase_verdict"] = None
    bucket["next_strategy_unblocked"] = None


def _refresh_phase_verdict(bucket: dict[str, Any], pass_threshold: int = 1, fail_phase_label: str | None = None) -> None:
    rows = list(bucket.get("matrix", []))
    verdicts = [str(row.get("verdict")) for row in rows if row.get("verdict") is not None]
    if not rows or len(verdicts) < len(rows):
        bucket["phase_verdict"] = None
        return
    pass_count = sum(1 for value in verdicts if value == "PASS")
    if pass_count >= pass_threshold:
        bucket["phase_verdict"] = "PASS"
        return
    if fail_phase_label:
        bucket["phase_verdict"] = f"FAIL_PHASE_{fail_phase_label}"
        return
    bucket["phase_verdict"] = "FAIL_NO_SYMBOLS_PASSED"


def dedup_key(job: dict[str, Any]) -> str:
    normalized = validate_job(job)
    return "|".join(
        [
            normalized["ea_id"],
            normalized["version"],
            normalized["symbol"],
            normalized["phase"],
            normalized["sub_gate_config_hash"],
        ]
    )


def _round_robin_candidates(candidates: list[str], last_rr_index: int) -> list[str]:
    if not candidates:
        return []
    offset = (last_rr_index + 1) % len(candidates)
    return candidates[offset:] + candidates[:offset]


def _affinity_terminal(symbol: str, affinity: dict[str, Any], now_epoch: int) -> str | None:
    raw = affinity.get(symbol)
    if isinstance(raw, str):
        return raw
    if not isinstance(raw, dict):
        return None
    terminal = str(raw.get("terminal", ""))
    ts = int(raw.get("ts", 0))
    if terminal and (now_epoch - ts) <= AFFINITY_TTL_SECONDS:
        return terminal
    return None


def _recent_count_for_terminal(state: dict[str, Any], terminal: str, now_epoch: int) -> int:
    recent_runs = state.setdefault("recent_runs", {})
    times = [int(ts) for ts in list(recent_runs.get(terminal, []))]
    cutoff = now_epoch - RECENT_WINDOW_SECONDS
    kept = [ts for ts in times if ts >= cutoff]
    recent_runs[terminal] = kept
    return len(kept)


def dispatch_job(
    job: dict[str, Any],
    state: dict[str, Any],
    max_per_terminal: int = 3,
    now_epoch: int | None = None,
    enforce_dl054_prelaunch: bool = True,
    terminal_for_gate: str = "T1",
    window_start: Any = None,
    window_end: Any = None,
    launch_config: dict[str, Any] | None = None,
    report_csv_path: str | None = None,
) -> dict[str, Any]:
    now = int(now_epoch if now_epoch is not None else time.time())
    normalized_job = validate_job(job)
    key = dedup_key(job)
    dedup = state.setdefault("dedup", {})
    if key in dedup:
        existing = dedup.get(key, {})
        return {"dedup_key": key, "status": "duplicate", "terminal": existing.get("terminal")}

    if enforce_dl054_prelaunch:
        if launch_config is None:
            raise ValueError("launch_config is required when enforce_dl054_prelaunch=True")
        if window_start is None or window_end is None:
            raise ValueError("window_start/window_end are required when enforce_dl054_prelaunch=True")
        pre = apply_pre_launch_gates(
            ea_id=normalized_job["ea_id"],
            phase=normalized_job["phase"],
            symbol=normalized_job["symbol"],
            terminal=terminal_for_gate,
            window_start=_coerce_utc_datetime(window_start),
            window_end=_coerce_utc_datetime(window_end),
            launch_config=launch_config,
        )
        if pre.verdict == "INVALID":
            _, bucket = _ensure_matrix_bucket(state, normalized_job)
            row = _upsert_matrix_row(bucket, symbol=normalized_job["symbol"], terminal=terminal_for_gate)
            row["verdict"] = "INVALID"
            row["invalidation_reason"] = pre.invalidation_reason
            row["evidence"] = "pipeline_dispatcher.py:prelaunch"
            _append_report_csv_row(
                report_csv_path,
                ea_id=normalized_job["ea_id"],
                phase=normalized_job["phase"],
                symbol=normalized_job["symbol"],
                terminal=terminal_for_gate,
                verdict="INVALID",
                invalidation_reason=pre.invalidation_reason,
                evidence="pipeline_dispatcher.py:prelaunch",
            )
            _refresh_phase_verdict(bucket, pass_threshold=1, fail_phase_label=None)
            return {
                "dedup_key": key,
                "status": "invalid_prelaunch",
                "terminal": terminal_for_gate,
                "invalidation_reason": pre.invalidation_reason,
            }

    terminals = active_terminals()
    running = state.setdefault("running", {name: 0 for name in terminals})
    for name in terminals:
        running.setdefault(name, 0)
    eligible = [name for name in terminals if int(running.get(name, 0)) < max_per_terminal]
    if not eligible:
        return {"dedup_key": key, "status": "no_capacity", "terminal": None}

    min_load = min(int(running.get(name, 0)) for name in eligible)
    least_loaded = [name for name in eligible if int(running.get(name, 0)) == min_load]

    symbol = normalized_job["symbol"]
    affinity = state.setdefault("symbol_affinity", {})
    preferred = _affinity_terminal(symbol, affinity, now)
    if preferred in least_loaded:
        selected = preferred
    else:
        recent_counts = {name: _recent_count_for_terminal(state, name, now) for name in least_loaded}
        min_recent = min(recent_counts.values())
        lowest_recent = [name for name in least_loaded if recent_counts[name] == min_recent]
        rr = _round_robin_candidates(lowest_recent, int(state.get("last_rr_index", -1)))
        selected = rr[0]

    running[selected] = int(running.get(selected, 0)) + 1
    state["last_rr_index"] = terminals.index(selected)
    affinity[symbol] = {"terminal": selected, "ts": now}
    state.setdefault("recent_runs", {}).setdefault(selected, []).append(now)
    dedup[key] = {"symbol": symbol, "terminal": selected, "ts": now, "job": dict(normalized_job)}
    _, bucket = _ensure_matrix_bucket(state, normalized_job)
    _upsert_matrix_row(bucket, symbol=symbol, terminal=selected)
    return {"dedup_key": key, "status": "scheduled", "terminal": selected}


def resolve_target_terminal(
    job: dict[str, Any],
    state: dict[str, Any],
    max_per_terminal: int = 3,
    now_epoch: int | None = None,
) -> dict[str, Any]:
    target = str(job.get("target_terminal", "any")).upper()
    if target in TERMINALS:
        if target in active_terminals():
            return {"status": "pinned", "terminal": target, "dedup_key": dedup_key(job)}
        return {"status": "terminal_not_installed", "terminal": target, "dedup_key": dedup_key(job)}
    return dispatch_job(
        job,
        state,
        max_per_terminal=max_per_terminal,
        now_epoch=now_epoch,
        enforce_dl054_prelaunch=False,
    )


def release_job(
    job: dict[str, Any],
    state: dict[str, Any],
    now_epoch: int | None = None,
    verdict: str | None = None,
    evidence: str | None = None,
    pass_threshold: int = 1,
    fail_phase_label: str | None = None,
    next_strategy_unblocked: str | None = None,
    pre_verdict: Any = None,
    journal_path: str | None = None,
    report_path: str | None = None,
    report_csv_path: str | None = None,
) -> dict[str, Any]:
    now = int(now_epoch if now_epoch is not None else time.time())
    key = dedup_key(job)
    dedup = state.setdefault("dedup", {})
    if key not in dedup:
        return {"dedup_key": key, "status": "not_found", "terminal": None}

    record = dedup[key]
    terminal = str(record.get("terminal", ""))
    if terminal in TERMINALS:
        terminals = active_terminals()
        running = state.setdefault("running", {name: 0 for name in terminals})
        for name in terminals:
            running.setdefault(name, 0)
        current = int(running.get(terminal, 0))
        running[terminal] = max(current - 1, 0)
    record["status"] = "complete"
    record["completed_ts"] = now
    normalized_job = validate_job(job)
    _, bucket = _ensure_matrix_bucket(state, normalized_job)
    row = _upsert_matrix_row(bucket, symbol=str(record.get("symbol", job.get("symbol", ""))), terminal=terminal or None)
    post_invalidation_reason: str | None = None
    final_verdict = verdict
    if pre_verdict is not None:
        if not journal_path or not report_path:
            final_verdict = "INVALID"
            post_invalidation_reason = "G3:post_launch_artifacts_missing"
        else:
            post = apply_post_launch_gates(pre_verdict, journal_path=Path(journal_path), report_path=Path(report_path))
            final_verdict = post.verdict
            post_invalidation_reason = post.invalidation_reason or None
    if final_verdict is not None:
        row["verdict"] = final_verdict
    row["invalidation_reason"] = post_invalidation_reason
    if evidence is not None:
        row["evidence"] = evidence
    if final_verdict is not None:
        _append_report_csv_row(
            report_csv_path,
            ea_id=normalized_job["ea_id"],
            phase=normalized_job["phase"],
            symbol=normalized_job["symbol"],
            terminal=terminal or "",
            verdict=final_verdict,
            invalidation_reason=post_invalidation_reason or "",
            evidence=evidence or "",
        )
    if next_strategy_unblocked is not None:
        bucket["next_strategy_unblocked"] = next_strategy_unblocked
    _refresh_phase_verdict(bucket, pass_threshold=pass_threshold, fail_phase_label=fail_phase_label)
    response: dict[str, Any] = {"dedup_key": key, "status": "released", "terminal": terminal or None}
    if post_invalidation_reason:
        response["invalidation_reason"] = post_invalidation_reason
    return response


def prune_state(
    state: dict[str, Any],
    now_epoch: int | None = None,
    retention_seconds: int = DEFAULT_COMPLETED_RETENTION_SECONDS,
) -> int:
    now = int(now_epoch if now_epoch is not None else time.time())
    dedup = state.setdefault("dedup", {})
    remove_keys: list[str] = []
    for key, record in dedup.items():
        status = str(record.get("status", ""))
        completed_ts = int(record.get("completed_ts", 0))
        if status == "complete" and completed_ts > 0 and (now - completed_ts) > retention_seconds:
            remove_keys.append(key)
    for key in remove_keys:
        dedup.pop(key, None)
    return len(remove_keys)


def _load_json_with_retry(path: Path, default_factory):
    """Read a JSON file, tolerating concurrent writers.

    On Windows, os.replace() during a save can briefly race with readers
    (PermissionError) or — if the writer is killed mid-write — leave
    garbage in the file. Retry with jitter for both cases. Return
    default_factory() if all retries exhausted.
    """
    last_err = None
    for attempt in range(8):
        try:
            with path.open("r", encoding="utf-8") as handle:
                return json.load(handle)
        except (PermissionError, json.JSONDecodeError, OSError) as e:
            last_err = e
            time.sleep(0.05 + random.uniform(0, 0.1) * (attempt + 1))
    # Final fallback: return default rather than crashing the resolver.
    return default_factory()


def _save_json_atomic(payload: dict[str, Any], path: Path) -> None:
    """Atomic write: write to tempfile in same dir, then os.replace().

    Avoids partial-write corruption that crashes concurrent readers.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_path = tempfile.mkstemp(
        prefix=path.name + ".",
        suffix=".tmp",
        dir=str(path.parent),
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        # os.replace is atomic on Windows + POSIX
        for attempt in range(5):
            try:
                os.replace(tmp_path, str(path))
                tmp_path = None
                return
            except PermissionError:
                # Another process has the file open momentarily; retry briefly.
                time.sleep(0.05 + random.uniform(0, 0.1) * (attempt + 1))
        # Last-resort: try once more, let exception propagate this time.
        os.replace(tmp_path, str(path))
        tmp_path = None
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


def load_dispatch_state(path: Path = DEFAULT_STATE_PATH) -> dict[str, Any]:
    if not path.exists():
        return {"dedup": {}, "last_rr_index": -1, "recent_runs": {}, "running": {}, "symbol_affinity": {}}
    return _load_json_with_retry(
        path,
        lambda: {"dedup": {}, "last_rr_index": -1, "recent_runs": {}, "running": {}, "symbol_affinity": {}},
    )


def save_dispatch_state(state: dict[str, Any], path: Path = DEFAULT_STATE_PATH) -> None:
    _save_json_atomic(state, path)


def export_phase_matrix_index(state: dict[str, Any]) -> dict[str, Any]:
    index = state.get("phase_matrix_index", {})
    if not isinstance(index, dict):
        return {}
    return index


def load_dedup_index(path: Path = DEFAULT_DEDUP_INDEX_PATH) -> dict[str, Any]:
    if not path.exists():
        return {}
    data = _load_json_with_retry(path, lambda: {})
    if not isinstance(data, dict):
        return {}
    return data


def save_dedup_index(index: dict[str, Any], path: Path = DEFAULT_DEDUP_INDEX_PATH) -> None:
    _save_json_atomic(index, path)
