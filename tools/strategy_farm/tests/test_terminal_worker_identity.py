"""Regression tests for the DL-065 terminal-worker identity boundary."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest


SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

import agent_scopes  # noqa: E402
import start_terminal_workers  # noqa: E402
import terminal_worker  # noqa: E402


def _exit_before_worker_loop(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(terminal_worker, "_acquire_instance_mutex", lambda _terminal: False)


def test_direct_worker_entrypoint_bootstraps_repo_imports(tmp_path: Path) -> None:
    worker = SF / "terminal_worker.py"
    env = os.environ.copy()
    env.pop("PYTHONPATH", None)

    result = subprocess.run(
        [sys.executable, str(worker), "--help"],
        cwd=tmp_path,
        env=env,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=30,
    )

    assert result.returncode == 0, result.stderr
    assert "--terminal" in result.stdout


def test_unset_worker_defaults_to_controller_and_passes_dispatch_guard(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.delenv("QM_AGENT_ID", raising=False)
    monkeypatch.setattr(agent_scopes, "_audit", lambda *args, **kwargs: None)
    _exit_before_worker_loop(monkeypatch)

    assert terminal_worker.main(["--terminal", "T1", "--root", str(tmp_path)]) == 0
    assert agent_scopes.current_agent_id() == "controller"
    agent_scopes.guard(
        "mt5.backtest.dispatch",
        tool="dl065_regression_test",
        args_summary="unset worker identity",
    )


def test_explicit_narrower_worker_identity_is_preserved_and_enforced(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setenv("QM_AGENT_ID", "gemini")
    monkeypatch.setattr(agent_scopes, "_audit", lambda *args, **kwargs: None)
    _exit_before_worker_loop(monkeypatch)

    assert terminal_worker.main(["--terminal", "T1", "--root", str(tmp_path)]) == 0
    assert agent_scopes.current_agent_id() == "gemini"
    with pytest.raises(agent_scopes.ScopeDenied):
        agent_scopes.guard(
            "mt5.backtest.dispatch",
            tool="dl065_regression_test",
            args_summary="explicit narrower identity",
        )


def test_worker_spawner_exports_controller_to_unset_children(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    repo_root = tmp_path / "repo"
    farm_root = tmp_path / "farm"
    mt5_root = tmp_path / "mt5"
    captured: dict[str, object] = {}

    def fake_popen(*args, **kwargs):
        captured["command"] = args[0]
        captured["identity"] = os.environ.get("QM_AGENT_ID")
        return SimpleNamespace(pid=4321)

    monkeypatch.delenv("QM_AGENT_ID", raising=False)
    monkeypatch.setattr(start_terminal_workers, "_installed_terminals", lambda _root: ("T1",))
    monkeypatch.setattr(start_terminal_workers, "_scan_running_workers", lambda: {})
    monkeypatch.setattr(start_terminal_workers.subprocess, "Popen", fake_popen)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "start_terminal_workers.py",
            "--repo-root",
            str(repo_root),
            "--farm-root",
            str(farm_root),
            "--mt5-root",
            str(mt5_root),
        ],
    )

    assert start_terminal_workers.main() == 0
    assert captured["identity"] == "controller"
    assert "--terminal" in captured["command"]
    assert "T1" in captured["command"]
