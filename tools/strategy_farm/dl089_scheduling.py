"""Shared bounded scheduling policy for independent DL-089 programs."""

from __future__ import annotations

import hashlib
import os
from typing import Any, Mapping


PROGRAM_SLOTS_ENV = "DL089_PROGRAM_SLOTS"
DEFAULT_PROGRAM_SLOTS = 4
MAX_PROGRAM_SLOTS = 10


def program_slots() -> int:
    """Return the bounded program cap; setting the environment to 1 rolls back."""

    raw = str(os.environ.get(PROGRAM_SLOTS_ENV, DEFAULT_PROGRAM_SLOTS)).strip()
    try:
        value = int(raw)
    except ValueError:
        return DEFAULT_PROGRAM_SLOTS
    return max(1, min(value, MAX_PROGRAM_SLOTS))


def program_id(
    payload: Mapping[str, Any], *, ea_id: object = "", symbol: object = ""
) -> str:
    """Resolve a governed program identity with a deterministic legacy fallback."""

    declared = str(payload.get("program_id") or "").strip()
    if declared:
        return declared
    q12 = str(payload.get("q12_work_item_id") or "").strip()
    if q12:
        return f"q12:{q12}"
    return f"legacy:{ea_id}:{str(symbol or '').upper()}"


def pruning_lock_filename(program: str) -> str:
    """Return a path-safe lock name keyed by authenticated program identity."""

    digest = hashlib.sha256(program.encode("utf-8")).hexdigest()[:20]
    return f"DL089_CLAIM_PRUNING.{digest}.lock"

