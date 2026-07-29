from __future__ import annotations

import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
sys.path.insert(0, str(TOOLS))

import farmctl  # noqa: E402
import run_agent_orchestration_task as orchestration  # noqa: E402


def test_legacy_gemini_lane_resolves_only_agy(monkeypatch, tmp_path: Path) -> None:
    expected = tmp_path / "agy.exe"
    monkeypatch.setattr(farmctl, "_AGY_BIN", expected)
    monkeypatch.setattr(farmctl._shutil if hasattr(farmctl, "_shutil") else __import__("shutil"), "which", lambda _name: None)
    command, shell = farmctl._resolve_gemini_command()
    assert command == [str(expected)]
    assert shell is False


def test_orchestration_legacy_key_builds_agy_command(monkeypatch, tmp_path: Path) -> None:
    agy = tmp_path / "agy.exe"
    monkeypatch.setattr(orchestration, "AGY_BIN", agy)
    monkeypatch.setattr(orchestration.shutil, "which", lambda _name: None)
    monkeypatch.setattr(orchestration, "PYTHON_EXE", tmp_path / "python.exe")
    monkeypatch.setattr(orchestration, "CONPTY_RUNNER", tmp_path / "agy_conpty_run.py")
    prompt = tmp_path / "prompt.md"
    command = orchestration.command_for("gemini", tmp_path, prompt)
    assert command[:3] == [str(tmp_path / "python.exe"), str(tmp_path / "agy_conpty_run.py"), str(agy)]
    joined = " ".join(command).lower()
    assert "gemini.cmd" not in joined
    assert "gemini.js" not in joined


def test_dead_gemini_executable_references_are_absent() -> None:
    for source in (Path(farmctl.__file__), Path(orchestration.__file__)):
        text = source.read_text(encoding="utf-8").lower()
        assert "gemini.cmd" not in text
        assert "@google\\gemini-cli" not in text
