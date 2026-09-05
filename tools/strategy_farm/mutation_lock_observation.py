"""Bounded diagnostic reads; never an input to lock or claim decisions.

The Windows lock denies sharing. Its existing ACQUIRED/RELEASED journal is a
best-effort fallback, explicitly labeled as an observation, not current-owner
proof. One daemon reader per process prevents a slow filesystem from queuing
threads or making the claim path wait for I/O without a deadline.
"""
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path
import threading
import time

from factory_mutation_lock import DEFAULT_PATH, DEFAULT_HOLD_TELEMETRY_PATH

MAX_TAIL_BYTES = 64 * 1024
READ_BUDGET_SECONDS = 0.035
_IN_FLIGHT = threading.Lock()


def _identity(path: str | Path) -> str:
    return os.path.normcase(os.path.abspath(path))


def _owner(record: dict, source: str) -> dict:
    stamp = record.get("acquired_at") or record.get("created_at") or record.get("acquired_at_utc")
    at = dt.datetime.fromisoformat(str(stamp).replace("Z", "+00:00"))
    if at.tzinfo is None or not isinstance(record.get("owner"), str):
        raise ValueError("unusable owner marker")
    if type(record.get("pid")) is not int or record["pid"] <= 0:
        raise ValueError("unusable pid")
    return {
        "status": "observed", "source": source, "diagnostic_only": True,
        "pid": record["pid"], "owner": record["owner"][:512],
        "nonce": str(record.get("nonce") or "")[:64],
        "exe": record.get("exe"), "argv0": record.get("argv0"),
        "stage": record.get("stage"), "reason": record.get("reason"),
        "acquired_at": at.isoformat(),
        "age_seconds": round(max(0.0, (dt.datetime.now(dt.UTC) - at).total_seconds()), 6),
    }


def _read_owner(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            raw = handle.read(4097)
        if len(raw) <= 4096:
            return _owner(json.loads(raw), "lock_record")
    except FileNotFoundError:
        return {"status": "lock_absent", "diagnostic_only": True}
    except (OSError, ValueError, TypeError, AttributeError):
        pass
    journal = (DEFAULT_HOLD_TELEMETRY_PATH if path.parent == DEFAULT_PATH.parent
               else path.with_name(path.name + ".holds.jsonl"))
    with journal.open("rb") as handle:
        handle.seek(0, os.SEEK_END)
        offset = max(0, handle.tell() - MAX_TAIL_BYTES)
        handle.seek(offset)
        lines = handle.read(MAX_TAIL_BYTES).splitlines()
    if offset:
        lines = lines[1:]
    released: set[str] = set()
    for line in reversed(lines):
        try:
            record = json.loads(line)
            if _identity(record.get("lock_path", "")) != _identity(path):
                continue
            nonce = record.get("nonce")
            if not isinstance(nonce, str) or not nonce:
                continue
            if record.get("event") == "RELEASED":
                released.add(nonce)
            elif record.get("event") == "ACQUIRED" and nonce not in released:
                return _owner(record, "unreleased_hold_journal_receipt")
        except (ValueError, TypeError, AttributeError):
            continue
    return {"status": "no_owner_in_bounded_tail", "diagnostic_only": True}


def observe_lock_owner(path: str | Path = DEFAULT_PATH) -> dict:
    """Wait at most 35 ms for one capped read; no queue and no process probes."""
    started = time.monotonic()
    if not _IN_FLIGHT.acquire(blocking=False):
        return {"status": "reader_busy", "diagnostic_only": True}
    done = threading.Event()
    result: dict = {}

    def read() -> None:
        try:
            result.update(_read_owner(Path(path)))
        except Exception as exc:
            result.update(status="unavailable", error=type(exc).__name__, diagnostic_only=True)
        finally:
            _IN_FLIGHT.release()
            done.set()

    try:
        threading.Thread(target=read, name="qm-lock-observer", daemon=True).start()
    except Exception as exc:
        _IN_FLIGHT.release()
        return {"status": "reader_start_failed", "error": type(exc).__name__, "diagnostic_only": True}
    if not done.wait(max(0.0, READ_BUDGET_SECONDS - (time.monotonic() - started))):
        return {"status": "read_timeout", "diagnostic_only": True, "budget_ms": 35}
    return {**result, "read_elapsed_ms": round((time.monotonic() - started) * 1000, 3)}
