"""Shared test configuration for the strategy-farm suite.

The fleet-wide claim stagger (terminal_worker.CLAIM_SPACING_SECONDS, OWNER
2026-08-15) shapes the production ramp; queue-semantics tests claim several
items back-to-back and must not race a wall-clock window. Disable it suite-wide
here — test_claim_spacing.py covers the stagger behavior explicitly.
"""
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def pytest_configure(config):
    """Keep isolated farm fixtures outside production-forbidden AppData roots."""
    if config.option.basetemp is None:
        repo_root = Path(__file__).resolve().parents[3]
        scratch_root = repo_root / "scratch"
        scratch_root.mkdir(parents=True, exist_ok=True)
        config.option.basetemp = str(scratch_root / f"pytest-{os.getpid()}")


@pytest.fixture(autouse=True)
def _zero_claim_spacing(monkeypatch):
    # Import lazily at fixture time, never at conftest collection time: a
    # collection-time import establishes a second flat import graph before
    # each test module's own sys.path setup runs, and exception classes from
    # the duplicated modules no longer compare equal
    # (test_privatize_fails_closed_without_master_state, 2026-08-15).
    import terminal_worker

    monkeypatch.setattr(terminal_worker, "CLAIM_SPACING_SECONDS", 0.0)

    # The suite is routinely executed from a linked ticket worktree, while
    # router unit tests exercise isolated temporary databases as the current
    # canonical writer. Model that canonical checkout by default. Tests of the
    # linked-worktree refusal contract explicitly replace this value with a
    # `.git` file and therefore continue to exercise the production guard.
    from tools.strategy_farm import agent_router

    router_modules = [agent_router]
    flat_router = sys.modules.get("agent_router")
    if flat_router is not None and flat_router is not agent_router:
        router_modules.append(flat_router)
    for router_module in router_modules:
        monkeypatch.setattr(
            router_module,
            "ROUTER_CHECKOUT_ROOT",
            router_module.CANONICAL_ROUTER_ROOT,
        )
