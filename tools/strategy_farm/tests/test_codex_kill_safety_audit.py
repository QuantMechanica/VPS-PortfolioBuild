from __future__ import annotations

import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from codex_kill_safety_audit import audit_repo_roots  # noqa: E402


def _farm_file(repo: Path, source: str) -> Path:
    path = repo / "tools" / "strategy_farm" / "farmctl.py"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")
    return path


def _pacer_file(repo: Path, source: str) -> Path:
    path = repo / "tools" / "strategy_farm" / "codex_fleet_pacer.py"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")
    return path


def _worker_launcher_file(repo: Path, source: str) -> Path:
    path = repo / "tools" / "strategy_farm" / "start_terminal_workers.py"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")
    return path


def test_audit_rejects_global_codex_discovery_and_force_kill(tmp_path) -> None:
    _farm_file(
        tmp_path,
        """
def reap():
    script = \"Get-CimInstance Win32_Process | ? Name -eq 'codex.exe' | taskkill\"
    return script
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is False
    assert report["unsafe"][0]["reason"].endswith("function:reap")


def test_audit_allows_identity_bound_lifecycle_and_separate_diagnostics(tmp_path) -> None:
    _farm_file(
        tmp_path,
        """
def count_only():
    return \"Get-Process -Name codex\"

def stop_owned_terminal():
    return \"Stop-Process -Id $ownedTerminalPid\"

def reap_owned_lease():
    return terminate_managed_codex_pid(lease_id)
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is True
    assert report["unsafe"] == []


def test_audit_rejects_windows_destructive_signal_zero_probe(tmp_path) -> None:
    _farm_file(
        tmp_path,
        """
import os

def process_alive(pid):
    os.kill(pid, 0)
    return True
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is False
    assert report["unsafe"][0]["reason"].startswith(
        "windows_destructive_os_kill_zero:function:process_alive"
    )


def test_audit_allows_signal_zero_only_after_exiting_windows_guard(tmp_path) -> None:
    _farm_file(
        tmp_path,
        """
import os
import sys

def process_alive(pid):
    if sys.platform == "win32":
        return read_only_windows_probe(pid)
    os.kill(pid, 0)
    return True
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is True


def test_audit_rejects_unguarded_call_even_with_later_windows_probe(tmp_path) -> None:
    _farm_file(
        tmp_path,
        """
import os

def process_alive(pid):
    os.kill(pid, 0)
    if os.name == "nt":
        return OpenProcess(pid) and GetExitCodeProcess(pid)
    return True
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is False


def test_audit_rejects_farmctl_bare_pid_force_kill(tmp_path) -> None:
    _farm_file(
        tmp_path,
        """
def _stop_pid(pid):
    command = f"Stop-Process -Id {pid} -Force"
    return run(command)
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is False
    assert "identity_less_persisted_pid_force_kill" in report["unsafe"][0]["reason"]


def test_audit_allows_farmctl_parent_owned_child_tree_stop(tmp_path) -> None:
    _farm_file(
        tmp_path,
        """
def _stop_pid(pid):
    return False

def _stop_pid_tree(pid):
    command = f"Stop-Process -Id {pid} -Force"
    return run(command)
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is True


def test_audit_rejects_fleet_pacer_bare_pid_taskkill(tmp_path) -> None:
    _pacer_file(
        tmp_path,
        """
def stop_agent(pid):
    return run(["taskkill", "/PID", str(pid), "/T", "/F"])
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is False
    assert "identity_less_persisted_pid_force_kill" in report["unsafe"][0]["reason"]


def test_audit_rejects_worker_dedupe_bare_pid_taskkill(tmp_path) -> None:
    _worker_launcher_file(
        tmp_path,
        """
def _stop_pid(pid):
    return run(["taskkill", "/PID", str(pid), "/T", "/F"])
""",
    )

    report = audit_repo_roots([tmp_path])

    assert report["safe"] is False


def test_clean_root_head_result_is_reused_from_cache(tmp_path, monkeypatch) -> None:
    _farm_file(tmp_path, "def safe():\n    return True\n")
    cache = tmp_path / "cache.json"
    monkeypatch.setattr(
        "codex_kill_safety_audit._git_identity",
        lambda _root: ("a" * 40, True),
    )

    first = audit_repo_roots([tmp_path], cache_path=cache)
    second = audit_repo_roots([tmp_path], cache_path=cache)

    assert first["cache_hits"] == 0
    assert second["cache_hits"] == 1
    assert second["safe"] is True


def test_runtime_file_change_invalidates_same_head_cache(tmp_path, monkeypatch) -> None:
    _farm_file(tmp_path, "def safe():\n    return True\n")
    cache = tmp_path / "cache.json"
    monkeypatch.setattr(
        "codex_kill_safety_audit._git_identity",
        lambda _root: ("b" * 40, True),
    )
    audit_repo_roots([tmp_path], cache_path=cache)
    _farm_file(
        tmp_path,
        "def unsafe():\n    return \"Get-Process -Name codex.exe | taskkill\"\n",
    )

    result = audit_repo_roots([tmp_path], cache_path=cache)

    assert result["cache_hits"] == 0
    assert result["safe"] is False
