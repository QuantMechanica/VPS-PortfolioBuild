from __future__ import annotations

import os
import subprocess
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SUPERVISOR = REPO / "tools" / "strategy_farm" / "codex_session_supervisor.ps1"
FAKE_CODEX = (
    REPO / "tools" / "strategy_farm" / "tests" / "fixtures" / "fake_codex_supervisor.cmd"
)


def test_supervisor_resumes_after_unexpected_child_exit(tmp_path) -> None:
    state_path = tmp_path / "state.txt"
    args_path = tmp_path / "args.txt"
    codex_home = tmp_path / "codex-home"
    supervisor_log = tmp_path / "supervisor.jsonl"
    env = os.environ.copy()
    env.update(
        {
            "CODEX_HOME": str(codex_home),
            "QM_CODEX_REAL_LAUNCHER": str(FAKE_CODEX),
            "QM_CODEX_FAKE_STATE": str(state_path),
            "QM_CODEX_FAKE_ARGS": str(args_path),
            "QM_CODEX_SUPERVISOR_LOG": str(supervisor_log),
            "QM_CODEX_SESSION_SUPERVISOR_FORCE": "1",
        }
    )

    result = subprocess.run(
        [
            "pwsh.exe",
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SUPERVISOR),
        ],
        cwd=str(REPO),
        capture_output=True,
        text=True,
        timeout=30,
        env=env,
    )

    assert result.returncode == 130, result.stderr
    resumed_args = args_path.read_text(encoding="utf-8").strip()
    assert resumed_args.startswith("resume --last ")
    assert "automatisch" in resumed_args


def test_supervisor_passes_noninteractive_subcommands_through(tmp_path) -> None:
    state_path = tmp_path / "state.txt"
    args_path = tmp_path / "args.txt"
    codex_home = tmp_path / "codex-home"
    supervisor_log = tmp_path / "supervisor.jsonl"
    state_path.write_text("already_started", encoding="utf-8")
    env = os.environ.copy()
    env.update(
        {
            "CODEX_HOME": str(codex_home),
            "QM_CODEX_REAL_LAUNCHER": str(FAKE_CODEX),
            "QM_CODEX_FAKE_STATE": str(state_path),
            "QM_CODEX_FAKE_ARGS": str(args_path),
            "QM_CODEX_SUPERVISOR_LOG": str(supervisor_log),
            "QM_CODEX_SESSION_SUPERVISOR_FORCE": "1",
        }
    )

    result = subprocess.run(
        [
            "pwsh.exe",
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SUPERVISOR),
            "exec",
            "do-not-resume",
        ],
        cwd=str(REPO),
        capture_output=True,
        text=True,
        timeout=30,
        env=env,
    )

    assert result.returncode == 0, result.stderr
    assert args_path.read_text(encoding="utf-8").strip() == "exec do-not-resume"
