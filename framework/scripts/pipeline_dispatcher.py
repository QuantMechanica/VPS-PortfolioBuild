#!/usr/bin/env python3
"""Factory-only queue dispatcher for T1-T5 backtests."""

from __future__ import annotations

import time
import json
from pathlib import Path
from typing import Any

TERMINALS = ("T1", "T2", "T3", "T4", "T5")
REQUIRED_JOB_FIELDS = ("ea_id", "version", "symbol", "phase", "sub_gate_config_hash")
MATRIX_REQUIRED_FIELDS = ("ea_id", "version", "phase", "sub_gate_config_hash", "symbols")
MATRIX_SYMBOL_COUNT = 36
AFFINITY_TTL_SECONDS = 24 * 60 * 60
RECENT_WINDOW_SECONDS = 24 * 60 * 60
DEFAULT_STATE_PATH = Path(r"D:\QM\Reports\pipeline\dispatch_state.json")
DEFAULT_DEDUP_INDEX_PATH = Path(r"D:\QM\Reports\pipeline\dedup_index.json")
DEFAULT_COMPLETED_RETENTION_SECONDS = 48 * 60 * 60


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
    for field in ("ea_id", "version", "phase", "sub_gate_config_hash"):
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
    row = {"symbol": symbol, "terminal": terminal, "verdict": None, "evidence": None}
    rows.append(row)
    return row


def _ensure_matrix_bucket(state: dict[str, Any], job: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    key = matrix_bucket_key(job)
    index = _phase_matrix_index(state)
    bucket = index.setdefault(key, {"matrix": [], "phase_verdict": None, "next_strategy_unblocked": None})
    return key, bucket


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
) -> dict[str, Any]:
    now = int(now_epoch if now_epoch is not None else time.time())
    key = dedup_key(job)
    dedup = state.setdefault("dedup", {})
    if key in dedup:
        existing = dedup.get(key, {})
        return {"dedup_key": key, "status": "duplicate", "terminal": existing.get("terminal")}

    running = state.setdefault("running", {name: 0 for name in TERMINALS})
    eligible = [name for name in TERMINALS if int(running.get(name, 0)) < max_per_terminal]
    if not eligible:
        return {"dedup_key": key, "status": "no_capacity", "terminal": None}

    min_load = min(int(running.get(name, 0)) for name in eligible)
    least_loaded = [name for name in eligible if int(running.get(name, 0)) == min_load]

    symbol = str(job.get("symbol", ""))
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
    state["last_rr_index"] = TERMINALS.index(selected)
    affinity[symbol] = {"terminal": selected, "ts": now}
    state.setdefault("recent_runs", {}).setdefault(selected, []).append(now)
    dedup[key] = {"symbol": symbol, "terminal": selected, "ts": now}
    _, bucket = _ensure_matrix_bucket(state, job)
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
        return {"status": "pinned", "terminal": target, "dedup_key": dedup_key(job)}
    return dispatch_job(job, state, max_per_terminal=max_per_terminal, now_epoch=now_epoch)


def release_job(
    job: dict[str, Any],
    state: dict[str, Any],
    now_epoch: int | None = None,
    verdict: str | None = None,
    evidence: str | None = None,
    pass_threshold: int = 1,
    fail_phase_label: str | None = None,
    next_strategy_unblocked: str | None = None,
) -> dict[str, Any]:
    now = int(now_epoch if now_epoch is not None else time.time())
    key = dedup_key(job)
    dedup = state.setdefault("dedup", {})
    if key not in dedup:
        return {"dedup_key": key, "status": "not_found", "terminal": None}

    record = dedup[key]
    terminal = str(record.get("terminal", ""))
    if terminal in TERMINALS:
        running = state.setdefault("running", {name: 0 for name in TERMINALS})
        current = int(running.get(terminal, 0))
        running[terminal] = max(current - 1, 0)
    record["status"] = "complete"
    record["completed_ts"] = now
    _, bucket = _ensure_matrix_bucket(state, job)
    row = _upsert_matrix_row(bucket, symbol=str(record.get("symbol", job.get("symbol", ""))), terminal=terminal or None)
    if verdict is not None:
        row["verdict"] = verdict
    if evidence is not None:
        row["evidence"] = evidence
    if next_strategy_unblocked is not None:
        bucket["next_strategy_unblocked"] = next_strategy_unblocked
    _refresh_phase_verdict(bucket, pass_threshold=pass_threshold, fail_phase_label=fail_phase_label)
    return {"dedup_key": key, "status": "released", "terminal": terminal or None}


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


def load_dispatch_state(path: Path = DEFAULT_STATE_PATH) -> dict[str, Any]:
    if not path.exists():
        return {"dedup": {}, "last_rr_index": -1, "recent_runs": {}, "running": {}, "symbol_affinity": {}}
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_dispatch_state(state: dict[str, Any], path: Path = DEFAULT_STATE_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(state, handle, indent=2, sort_keys=True)
        handle.write("\n")


def export_phase_matrix_index(state: dict[str, Any]) -> dict[str, Any]:
    index = state.get("phase_matrix_index", {})
    if not isinstance(index, dict):
        return {}
    return index


def load_dedup_index(path: Path = DEFAULT_DEDUP_INDEX_PATH) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        return {}
    return data


def save_dedup_index(index: dict[str, Any], path: Path = DEFAULT_DEDUP_INDEX_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(index, handle, indent=2, sort_keys=True)
        handle.write("\n")
