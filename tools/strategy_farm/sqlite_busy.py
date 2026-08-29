"""Shared SQLite contention policy for strategy-farm writers.

SQLite serializes writers.  A long per-connection busy timeout makes every
contender sleep in the C call at the same time and produces long, synchronized
stalls.  The farm instead uses a short busy timeout and reopens/retries the
whole transaction after bounded exponential jitter.
"""

from __future__ import annotations

import os
import random
import sqlite3
import time
from collections.abc import Callable
from typing import TypeVar


T = TypeVar("T")

# Default stays the deliberate short-timeout doctrine (claim-path contention:
# short beats long, see XCU 2026-08-16).  The singleton control plane (pump /
# pump-maintenance wrappers) overrides via env because ONE lost write there
# kills a whole 5-minute dispatch cycle (2026-08-29 pump starvation: cycles
# died at ever-deeper raw write sites during news-runner write bursts).
BUSY_TIMEOUT_MS = int(os.environ.get("QM_SQLITE_BUSY_TIMEOUT_MS", "750"))
WRITE_ATTEMPTS = 8
BASE_DELAY_SECONDS = 0.05
MAX_DELAY_SECONDS = 1.0
JITTER_SECONDS = 0.10


def configure_connection(
    connection: sqlite3.Connection, *, busy_timeout_ms: int = BUSY_TIMEOUT_MS
) -> sqlite3.Connection:
    """Apply the one farm-wide busy policy to an existing connection."""

    connection.execute(f"PRAGMA busy_timeout={max(0, int(busy_timeout_ms))}")
    return connection


def is_sqlite_busy(exc: BaseException) -> bool:
    """Recognize both SQLITE_BUSY and SQLITE_LOCKED across Python versions."""

    code = getattr(exc, "sqlite_errorcode", None)
    busy_codes = {
        getattr(sqlite3, "SQLITE_BUSY", 5),
        getattr(sqlite3, "SQLITE_LOCKED", 6),
    }
    if code in busy_codes:
        return True
    message = str(exc).lower()
    return "database is locked" in message or "database table is locked" in message


def retry_sqlite_busy(
    operation: Callable[[], T],
    *,
    attempts: int = WRITE_ATTEMPTS,
    base_delay_seconds: float = BASE_DELAY_SECONDS,
    max_delay_seconds: float = MAX_DELAY_SECONDS,
    jitter_seconds: float = JITTER_SECONDS,
    sleep: Callable[[float], None] = time.sleep,
    random_uniform: Callable[[float, float], float] = random.uniform,
) -> T:
    """Retry a transaction factory after SQLITE_BUSY/LOCKED.

    ``operation`` must open its own connection/transaction on each call so a
    failed transaction is discarded before the jittered retry.
    """

    if attempts < 1:
        raise ValueError("attempts must be at least one")
    for attempt in range(attempts):
        try:
            return operation()
        except sqlite3.OperationalError as exc:
            if not is_sqlite_busy(exc) or attempt + 1 >= attempts:
                raise
            exponential = min(
                max_delay_seconds,
                max(0.0, base_delay_seconds) * (2**attempt),
            )
            jitter = random_uniform(0.0, max(0.0, jitter_seconds))
            sleep(exponential + jitter)
    raise RuntimeError("unreachable sqlite retry state")
