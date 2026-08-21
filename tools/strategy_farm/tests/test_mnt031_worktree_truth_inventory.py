from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import worktree_truth_inventory as inventory  # noqa: E402


def test_porcelain_parser_preserves_detached_and_locked_state() -> None:
    rows = inventory._parse_worktrees(
        "worktree C:/QM/repo\nHEAD abc\nbranch refs/heads/agents/board-advisor\n\n"
        "worktree C:/QM/worktrees/legacy\nHEAD def\ndetached\nlocked initializing\n\n"
    )
    assert rows[0]["branch"] == "refs/heads/agents/board-advisor"
    assert rows[1]["detached"] is True
    assert rows[1]["locked"] == "initializing"


def test_explicit_worktree_roles_outrank_name_guessing() -> None:
    assert inventory._owner_and_role(Path("C:/QM/repo"), "agents/board-advisor", False)[1] == "canonical_operative"
    assert inventory._owner_and_role(Path("C:/QM/worktrees/cto_main"), "main", False)[:2] == (
        "Claude+OWNER",
        "main_integration_staging",
    )
    assert inventory._owner_and_role(Path("C:/QM/runtime_worktrees/job"), None, True)[:2] == (
        "Pipeline-Operator",
        "runtime_detached_execution",
    )


def test_unknown_detached_worktree_is_owner_disposition_not_production() -> None:
    owner, role, basis = inventory._owner_and_role(Path("C:/QM/worktrees/legacy"), None, True)
    assert owner == "Claude+OWNER disposition"
    assert role == "legacy_detached_worktree"
    assert basis == "safe_default"
