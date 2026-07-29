"""Cross-process lock for every Strategy Farm state mutation.

The lock file is intentionally shared with ``Factory_OFF.ps1`` and
``Factory_ON.ps1``.  Acquisition is an atomic create-new operation; an existing
file is fail-closed and is never stolen here.  Factory OFF owns stale-owner
inspection because it can also drain the associated scheduled tasks/processes.
"""

from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path


DEFAULT_PATH = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")


class FactoryMutationLock:
    """Hold the global mutation boundary until the guarded operation finishes."""

    def __init__(self, path: Path = DEFAULT_PATH, *, owner: str) -> None:
        self.path = Path(path)
        self.owner = owner
        self._fd: int | None = None

    def __enter__(self) -> "FactoryMutationLock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        flags = os.O_CREAT | os.O_EXCL | os.O_WRONLY
        if hasattr(os, "O_BINARY"):
            flags |= os.O_BINARY
        try:
            self._fd = os.open(self.path, flags, 0o600)
        except FileExistsError as exc:
            raise RuntimeError(f"factory mutation lock is busy: {self.path}") from exc
        record = {
            "pid": os.getpid(),
            "owner": self.owner,
            "created_at": dt.datetime.now(dt.UTC).isoformat(),
        }
        try:
            raw = (json.dumps(record, sort_keys=True) + "\n").encode("utf-8")
            os.write(self._fd, raw)
            os.fsync(self._fd)
        except BaseException:
            os.close(self._fd)
            self._fd = None
            self.path.unlink(missing_ok=True)
            raise
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        if self._fd is not None:
            os.close(self._fd)
            self._fd = None
        self.path.unlink(missing_ok=True)


def path_for_factory_flag(factory_off_flag: Path) -> Path:
    return Path(factory_off_flag).with_name("FACTORY_MUTATION.lock")
