from __future__ import annotations

import os
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
from process_identity import get_process_identity  # noqa: E402


def test_current_process_has_stable_creation_identity() -> None:
    first = get_process_identity(os.getpid())
    second = get_process_identity(os.getpid())

    assert first is not None
    assert first["is_running"] is True
    assert first["creation_key"] == second["creation_key"]


def test_legacy_bare_pid_stop_fails_closed() -> None:
    assert farmctl._stop_pid(1234, expected_creation_key=None) is False
