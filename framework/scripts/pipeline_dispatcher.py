#!/usr/bin/env python3
"""Factory-only queue dispatcher for T1-T5 backtests."""

from __future__ import annotations

import time
import json
from pathlib import Path
from typing import Any

TERMINALS = ("T1", "T2", "T3", "T4", "T5")
AFFINITY_TTL_SECONDS = 24 * 60 * 60
RECENT_WINDOW_SECONDS = 24 * 60 * 60
DEFAULT_STATE_PATH = Path(r"D:\QM\Reports\pipeline\dispatch_state.json")
DEFAULT_COMPLETED_RETENTION_SECONDS = 48 * 60 * 60


def dedup_key(job: dict[str, Any]) -> str:
    return "|".join(
        [
            str(job.get("ea_id", "")),
            str(job.get("version", "")),
            str(job.get("symbol", "")),
            str(job.get("phase", "")),
            str(job.get("sub_gate_config_hash", "")),
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


def release_job(job: dict[str, Any], state: dict[str, Any], now_epoch: int | None = None) -> dict[str, Any]:
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
