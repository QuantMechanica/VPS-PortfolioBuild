"""Bounded FIFO admission among worker claimants; the factory lock still owns safety."""
from __future__ import annotations

import re
import time
import uuid
from pathlib import Path

_TICKET = re.compile(r"^(\d{20})-(\d{20})-([0-9a-f]{32})\.ticket$")


class ClaimWaitTurn:
    """One acquisition turn. Expired/crashed waiters cannot obstruct later turns.

    Monotonic clocks share a time base on this host. Tickets convey only queue
    order; they never release or replace FACTORY_MUTATION.lock. Other mutators
    retain that existing interlock and can cause a bounded acquisition refusal.
    """

    def __init__(self, lock_path: Path, deadline: float):
        self.directory = lock_path.with_name(lock_path.name + ".claim_waiters")
        self.deadline = deadline
        self.path: Path | None = None
        self.nonce = uuid.uuid4().hex
        self.acquired_at: float | None = None

    def __enter__(self):
        self.directory.mkdir(parents=True, exist_ok=True)
        # perf_counter has sub-millisecond resolution on Python 3.11/Windows;
        # monotonic can share a 15 ms tick across several arriving processes.
        self.path = self.directory / f"{time.perf_counter_ns():020d}-{int(self.deadline * 1e9):020d}-{self.nonce}.ticket"
        with self.path.open("xb") as handle:
            handle.write(self.nonce.encode("ascii"))
        return self

    def is_head(self) -> bool:
        now = time.monotonic_ns()
        if now >= int(self.deadline * 1e9) or self.path is None:
            return False
        live = []
        for path in self.directory.glob("*.ticket"):
            match = _TICKET.fullmatch(path.name)
            if match is None:
                continue
            expiry = int(match[2])
            if expiry > now:
                live.append(path.name)
            elif expiry < now - 60_000_000_000:
                # Only an expired, nonce-matching coordination ticket is pruned.
                try:
                    if path.read_bytes() == match[3].encode("ascii"):
                        path.unlink()
                except OSError:
                    pass
        return bool(live) and self.path.name == min(live)

    def __exit__(self, *args):
        if self.path is not None:
            try:
                if self.path.read_bytes() == self.nonce.encode("ascii"):
                    self.path.unlink()
            except OSError:
                pass
