"""Shared test configuration for the strategy-farm suite.

The fleet-wide claim stagger (terminal_worker.CLAIM_SPACING_SECONDS, OWNER
2026-08-15) shapes the production ramp; queue-semantics tests claim several
items back-to-back and must not race a wall-clock window. Disable it suite-wide
here — test_claim_spacing.py covers the stagger behavior explicitly.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture(autouse=True)
def _zero_claim_spacing(monkeypatch):
    # Import lazily at fixture time, never at conftest collection time: a
    # collection-time import establishes a second flat import graph before
    # each test module's own sys.path setup runs, and exception classes from
    # the duplicated modules no longer compare equal
    # (test_privatize_fails_closed_without_master_state, 2026-08-15).
    import terminal_worker

    monkeypatch.setattr(terminal_worker, "CLAIM_SPACING_SECONDS", 0.0)
