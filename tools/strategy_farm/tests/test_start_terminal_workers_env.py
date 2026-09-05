"""Incident 2026-09-02: workers restarted from an interactive session lost the
machine-level QM_* environment (top-down claim order, DL-089 pruning, SQLite
busy timeout). The launcher must merge the machine QM_* values into the spawn
environment while an explicit process value still wins."""
from __future__ import annotations

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
    assert all(str(k).upper().startswith("QM_") for k in values)


def test_merge_carries_machine_dl089_scheduling_caps():
    """Reload chunks restart workers from an interactive env without DL089_* (2026-09-05)."""
    from tools.strategy_farm.start_terminal_workers import merge_machine_qm_env

    process = {"PATH": "x"}
    machine = {"DL089_PROGRAM_SLOTS": "8", "DL089_CELL_SLOTS": "6", "QM_ENABLE_DL089_PRUNING": "1", "PATHEXT": ".EXE"}
    merged = merge_machine_qm_env(process, machine)
    assert merged["DL089_PROGRAM_SLOTS"] == "8"
    assert merged["DL089_CELL_SLOTS"] == "6"
    assert merged["QM_ENABLE_DL089_PRUNING"] == "1"
    assert "PATHEXT" not in merged  # unrelated machine vars are still not merged

