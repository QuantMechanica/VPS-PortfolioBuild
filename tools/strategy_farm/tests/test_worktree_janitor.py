from __future__ import annotations

import os
import time
from pathlib import Path

from tools.strategy_farm import worktree_janitor as janitor


def _old(path: Path) -> None:
    stamp = time.time() - 72 * 3600
    os.utime(path, (stamp, stamp))
    os.utime(path / ".git", (stamp, stamp))


def test_old_clean_unreferenced_linked_worktree_is_eligible(tmp_path, monkeypatch) -> None:
    parent = tmp_path / "worktrees"
    path = parent / "old-clean"
    path.mkdir(parents=True)
    (path / ".git").write_text("gitdir: elsewhere", encoding="utf-8")
    _old(path)
    monkeypatch.setattr(janitor, "worktree_clean", lambda _path: True)
    monkeypatch.setattr(janitor, "worktree_age_hours", lambda _path: 72.0)

    result = janitor.assess(
        {"path": str(path), "head": "a" * 40}, command_lines=[],
        canonical_repo=tmp_path / "repo", worktree_parent=parent,
    )

    assert result["eligible"] is True


def test_process_reference_or_dirty_state_retains_worktree(tmp_path, monkeypatch) -> None:
    parent = tmp_path / "worktrees"
    path = parent / "in-use"
    path.mkdir(parents=True)
    (path / ".git").write_text("gitdir: elsewhere", encoding="utf-8")
    _old(path)
    monkeypatch.setattr(janitor, "worktree_clean", lambda _path: False)
    monkeypatch.setattr(janitor, "worktree_age_hours", lambda _path: 72.0)

    result = janitor.assess(
        {"path": str(path)}, command_lines=[f"codex exec --cd {path}"],
        canonical_repo=tmp_path / "repo", worktree_parent=parent,
    )

    assert result["eligible"] is False
    assert "process_referenced" in result["reasons"]
    assert "dirty_or_unreadable" in result["reasons"]


def test_outside_parent_is_never_eligible_even_if_clean(tmp_path, monkeypatch) -> None:
    path = tmp_path / "outside"
    path.mkdir()
    (path / ".git").write_text("gitdir: elsewhere", encoding="utf-8")
    monkeypatch.setattr(janitor, "worktree_clean", lambda _path: True)
    monkeypatch.setattr(janitor, "worktree_age_hours", lambda _path: 72.0)

    result = janitor.assess(
        {"path": str(path), "registered": False}, command_lines=[],
        canonical_repo=tmp_path / "repo", worktree_parent=tmp_path / "worktrees",
    )

    assert result["eligible"] is False
    assert "outside_worktree_parent" in result["reasons"]
