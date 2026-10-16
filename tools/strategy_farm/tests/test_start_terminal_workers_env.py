"""Incident 2026-09-02: workers restarted from an interactive session lost the
machine-level QM_* environment (top-down claim order, DL-089 pruning, SQLite
busy timeout). The launcher must merge the machine QM_* values into the spawn
environment while an explicit process value still wins."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from tools.strategy_farm import start_terminal_workers as launcher


def test_merge_fills_missing_machine_qm_vars_and_keeps_process_values():
    process = {"PATH": "x", "QM_CODEX_PARALLEL": "5"}
    machine = {
        "QM_TOPDOWN_GATE_PRIORITY_ENABLED": "1",
        "QM_ENABLE_DL089_PRUNING": "1",
        "QM_CODEX_PARALLEL": "3",
        "OTHER_VAR": "ignored",
    }
    merged = launcher.merge_machine_qm_env(process, machine)
    assert merged["QM_TOPDOWN_GATE_PRIORITY_ENABLED"] == "1"
    assert merged["QM_ENABLE_DL089_PRUNING"] == "1"
    assert merged["QM_CODEX_PARALLEL"] == "5"  # explicit process value wins
    assert "OTHER_VAR" not in merged
    assert merged["PATH"] == "x"
    assert process == {"PATH": "x", "QM_CODEX_PARALLEL": "5"}  # input untouched


def test_machine_environment_reader_returns_mapping():
    values = launcher.machine_qm_environment()
    assert isinstance(values, dict)
    from tools.strategy_farm.start_terminal_workers import _is_machine_factory_var

    assert all(_is_machine_factory_var(k) for k in values)


def test_merge_carries_machine_dl089_scheduling_caps():
    """Reload chunks restart workers from an interactive env without DL089_* (2026-09-05)."""
    from tools.strategy_farm.start_terminal_workers import merge_machine_qm_env

    process = {"PATH": "x"}
    machine = {
        "DL089_PROGRAM_SLOTS": "8",
        "DL089_LANES_PER_PROGRAM": "2",  # OWNER 2026-09-10 "Winsweep ja": carried since 2026-09-11
        "DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST": "DL089_X",
        "DL089_CELL_SLOTS": "3",  # temporary 48 h cap: never carried across a reboot
        "QM_ENABLE_DL089_PRUNING": "1",
        "PATHEXT": ".EXE",
    }
    merged = merge_machine_qm_env(process, machine)
    assert merged["DL089_PROGRAM_SLOTS"] == "8"
    assert merged["QM_ENABLE_DL089_PRUNING"] == "1"
    assert merged["DL089_LANES_PER_PROGRAM"] == "2"
    assert merged["DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST"] == "DL089_X"
    assert "DL089_CELL_SLOTS" not in merged
    assert "PATHEXT" not in merged  # unrelated machine vars are still not merged


def test_only_terminal_starts_one_worker_and_preserves_other_pid_receipts(
    tmp_path: Path, monkeypatch
):
    spawned: list[tuple[list[str], dict[str, str]]] = []

    class FakePopen:
        pid = 111

        def __init__(self, command, **kwargs):
            spawned.append((list(command), dict(kwargs["env"])))

    monkeypatch.setattr(
        launcher, "_installed_terminals", lambda _root: ("T1", "T2")
    )
    monkeypatch.setattr(
        launcher, "_scan_running_workers", lambda: {"T2": [222]}
    )
    monkeypatch.setattr(launcher, "_pid_alive", lambda pid: pid in {111, 222})
    monkeypatch.setattr(
        launcher,
        "machine_qm_environment",
        lambda: {
            "QM_TESTER_MEMORY_LIMIT_V1": "1",
            "QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID": "stale-row",
            "QM_TESTER_MEMORY_LIMIT_CANARY_BYTES": "1073741824",
        },
    )
    monkeypatch.setattr(
        launcher.resource_headroom, "probe", lambda _root: {"available": True}
    )
    monkeypatch.setattr(
        launcher.resource_headroom,
        "concurrency_decision",
        lambda *_args, **_kwargs: {"max_workers": 2},
    )
    monkeypatch.setattr(launcher.subprocess, "Popen", FakePopen)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "start_terminal_workers.py",
            "--repo-root",
            str(tmp_path / "repo"),
            "--farm-root",
            str(tmp_path / "farm"),
            "--mt5-root",
            str(tmp_path / "mt5"),
            "--only-terminal",
            "T1",
            "--expected-count",
            "1",
        ],
    )
    monkeypatch.delenv("QM_AGENT_ID", raising=False)
    monkeypatch.setenv("QM_TESTER_MEMORY_LIMIT_V1", "0")

    assert launcher.main() == 0
    assert len(spawned) == 1
    command, spawned_env = spawned[0]
    assert command[command.index("--terminal") + 1] == "T1"
    assert spawned_env["QM_TESTER_MEMORY_LIMIT_V1"] == "0"
    assert "QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID" not in spawned_env
    assert "QM_TESTER_MEMORY_LIMIT_CANARY_BYTES" not in spawned_env
    receipt = json.loads(
        (tmp_path / "farm" / "state" / "worker_pids.json").read_text(
            encoding="utf-8"
        )
    )
    assert receipt == {"T1": 111, "T2": 222}


def test_memory_limit_activation_refuses_non_targeted_fleet_start(
    tmp_path: Path, monkeypatch
):
    monkeypatch.setattr(launcher, "_scan_running_workers", lambda: {})
    monkeypatch.setattr(
        launcher,
        "machine_qm_environment",
        lambda: {"QM_TESTER_MEMORY_LIMIT_V1": "1"},
    )
    monkeypatch.setattr(
        launcher.subprocess,
        "Popen",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("fleet start must be refused before Popen")
        ),
    )
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "start_terminal_workers.py",
            "--repo-root",
            str(tmp_path / "repo"),
            "--farm-root",
            str(tmp_path / "farm"),
            "--mt5-root",
            str(tmp_path / "mt5"),
        ],
    )
    monkeypatch.delenv("QM_TESTER_MEMORY_LIMIT_V1", raising=False)

    assert launcher.main() == 6


def test_memory_limit_activation_refuses_target_without_exact_row_binding(
    tmp_path: Path, monkeypatch
):
    monkeypatch.setattr(launcher, "_scan_running_workers", lambda: {})
    monkeypatch.setattr(
        launcher,
        "machine_qm_environment",
        lambda: {"QM_TESTER_MEMORY_LIMIT_V1": "1"},
    )
    monkeypatch.setattr(
        launcher.subprocess,
        "Popen",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("unbound activation must be refused before Popen")
        ),
    )
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "start_terminal_workers.py",
            "--repo-root",
            str(tmp_path / "repo"),
            "--farm-root",
            str(tmp_path / "farm"),
            "--mt5-root",
            str(tmp_path / "mt5"),
            "--only-terminal",
            "T1",
            "--expected-count",
            "1",
        ],
    )
    monkeypatch.delenv("QM_TESTER_MEMORY_LIMIT_V1", raising=False)

    assert launcher.main() == 6


def test_memory_limit_production_refuses_canary_binding(
    tmp_path: Path, monkeypatch
):
    monkeypatch.setattr(launcher, "_scan_running_workers", lambda: {})
    monkeypatch.setattr(
        launcher,
        "machine_qm_environment",
        lambda: {
            "QM_TESTER_MEMORY_LIMIT_V1": "1",
            "QM_TESTER_MEMORY_LIMIT_A2_PRODUCTION_V1": "1",
            "QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID": "row-1",
            "QM_TESTER_MEMORY_LIMIT_CANARY_BYTES": "1073741824",
            "QM_RESEARCH_BACKTEST_MAX_ACTIVE": "1",
        },
    )
    monkeypatch.setattr(
        launcher.subprocess,
        "Popen",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("mixed production/canary mode must be refused")
        ),
    )
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "start_terminal_workers.py",
            "--repo-root",
            str(tmp_path / "repo"),
            "--farm-root",
            str(tmp_path / "farm"),
            "--mt5-root",
            str(tmp_path / "mt5"),
            "--only-terminal",
            "T1",
        ],
    )
    for name in (
        "QM_TESTER_MEMORY_LIMIT_V1",
        "QM_TESTER_MEMORY_LIMIT_A2_PRODUCTION_V1",
        "QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID",
        "QM_TESTER_MEMORY_LIMIT_CANARY_BYTES",
        "QM_RESEARCH_BACKTEST_MAX_ACTIVE",
    ):
        monkeypatch.delenv(name, raising=False)

    assert launcher.main() == 6


def test_memory_limit_production_refuses_cap_other_than_one(
    tmp_path: Path, monkeypatch
):
    monkeypatch.setattr(launcher, "_scan_running_workers", lambda: {})
    monkeypatch.setattr(
        launcher,
        "machine_qm_environment",
        lambda: {
            "QM_TESTER_MEMORY_LIMIT_V1": "1",
            "QM_TESTER_MEMORY_LIMIT_A2_PRODUCTION_V1": "1",
            "QM_RESEARCH_BACKTEST_MAX_ACTIVE": "2",
        },
    )
    monkeypatch.setattr(
        launcher.subprocess,
        "Popen",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("production cap other than one must be refused")
        ),
    )
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "start_terminal_workers.py",
            "--repo-root",
            str(tmp_path / "repo"),
            "--farm-root",
            str(tmp_path / "farm"),
            "--mt5-root",
            str(tmp_path / "mt5"),
            "--only-terminal",
            "T1",
        ],
    )
    for name in (
        "QM_TESTER_MEMORY_LIMIT_V1",
        "QM_TESTER_MEMORY_LIMIT_A2_PRODUCTION_V1",
        "QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID",
        "QM_TESTER_MEMORY_LIMIT_CANARY_BYTES",
        "QM_RESEARCH_BACKTEST_MAX_ACTIVE",
    ):
        monkeypatch.delenv(name, raising=False)

    assert launcher.main() == 6

