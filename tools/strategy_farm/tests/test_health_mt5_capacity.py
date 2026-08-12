from __future__ import annotations

import json
import sys
from pathlib import Path
from types import SimpleNamespace


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import health  # noqa: E402


def _scan(monkeypatch, terminals: list[str], disabled: set[str]):
    rows = [
        {
            "ProcessId": index,
            "CommandLine": f"python terminal_worker.py --terminal {terminal}",
        }
        for index, terminal in enumerate(terminals, start=1)
    ]
    monkeypatch.setattr(
        health.subprocess,
        "run",
        lambda *args, **kwargs: SimpleNamespace(stdout=json.dumps(rows)),
    )
    monkeypatch.setattr(health, "_disabled_terminals", lambda: disabled)
    return health.chk_mt5_worker_saturation(None)


def test_all_design_slots_alive_is_ok(monkeypatch):
    result = _scan(monkeypatch, list(health.FACTORY_TERMINALS), set())
    assert result["status"] == "OK"
    assert result["value"] == 10
    assert result["threshold"] == 10


def test_healthy_enabled_subset_still_warns_about_missing_design_capacity(monkeypatch):
    enabled = [terminal for terminal in health.FACTORY_TERMINALS if terminal != "T5"]
    result = _scan(monkeypatch, enabled, {"T5"})
    assert result["status"] == "WARN"
    assert result["value"] == 9
    assert result["threshold"] == 10
    assert "9/10 design" in result["detail"]
    assert "9/9 enabled" in result["detail"]
    assert "safety/quarantine" in result["detail"]
    assert "cap:" not in result["detail"]


def test_enabled_worker_loss_warns_against_design_capacity(monkeypatch):
    enabled = [terminal for terminal in health.FACTORY_TERMINALS if terminal != "T5"]
    result = _scan(monkeypatch, enabled[:-1], {"T5"})
    assert result["status"] == "WARN"
    assert result["value"] == 8
    assert result["threshold"] == 10


def test_below_enabled_safety_floor_is_fail(monkeypatch):
    result = _scan(monkeypatch, ["T1", "T2", "T3", "T4", "T6"], {"T5"})
    assert result["status"] == "FAIL"
    assert result["threshold"] == 6


def test_t_live_and_disabled_worker_do_not_count(monkeypatch):
    enabled = [terminal for terminal in health.FACTORY_TERMINALS if terminal != "T5"]
    rows = enabled + ["T5"]
    result = _scan(monkeypatch, rows, {"T5"})
    assert result["value"] == 9
    assert "T5" not in result["detail"].split("enabled daemons alive", 1)[1].split("//", 1)[0]
