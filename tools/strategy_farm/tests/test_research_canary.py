from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import research_canary as canary


def _farm(tmp_path: Path, *, t11_active: bool = False) -> Path:
    state = tmp_path / "farm" / "state"; state.mkdir(parents=True)
    (state / "worker_pids.json").write_text('{"T1": 1}\n', encoding="utf-8")
    (state / "custom_history_isolation_activation.json").write_text(json.dumps({"runner_terminals": ["T11"] if t11_active else ["T1"]}), encoding="utf-8")
    import sqlite3
    with sqlite3.connect(state / "farm_state.sqlite") as db:
        db.execute("CREATE TABLE work_items(id TEXT)"); db.execute("INSERT INTO work_items VALUES ('a')")
    return tmp_path / "farm"


def test_snapshot_and_unchanged_isolation(tmp_path):
    farm = _farm(tmp_path)
    before = canary.isolation_snapshot(farm_root=farm, terminal="T11")
    after = canary.isolation_snapshot(farm_root=farm, terminal="T11")
    canary.assert_isolation_admitted(before)
    canary.assert_isolation_unchanged(before, after)


def test_isolation_refuses_factory_activation_or_mutation_lock(tmp_path):
    active = canary.isolation_snapshot(farm_root=_farm(tmp_path, t11_active=True), terminal="T11")
    with pytest.raises(canary.CanaryRefused, match="active factory"):
        canary.assert_isolation_admitted(active)
    farm = _farm(tmp_path / "two")
    (farm / "state" / "FACTORY_MUTATION.lock").write_text("locked", encoding="utf-8")
    locked = canary.isolation_snapshot(farm_root=farm, terminal="T11")
    with pytest.raises(canary.CanaryRefused, match="FACTORY_MUTATION"):
        canary.assert_isolation_admitted(locked)


def test_rendered_ini_is_real_tick_and_shutdown_contract():
    ini = canary.render_tester_ini(expert="QM\\EA", symbol="USDJPY.DWX", period="H1",
        setfile_name="cell.set", from_date="2021.01.01", to_date="2021.12.31", report_rel="x/report.htm")
    assert "Model=4" in ini and "ShutdownTerminal=1" in ini and "ExpertParameters=cell.set" in ini


def test_resource_guard_refuses_ram_and_agent_limits(monkeypatch):
    class Memory: available = 1
    monkeypatch.setattr(canary.psutil, "virtual_memory", lambda: Memory())
    with pytest.raises(canary.CanaryRefused, match="RAM guard"):
        canary.check_resources(max_agents=1, cpu_samples=1, sample_seconds=0)


def test_request_rejects_t12_and_outside_t11_paths(tmp_path):
    root = tmp_path / "mt5"; (root / "T11" / "MQL5" / "Experts").mkdir(parents=True)
    (root / "T11" / "MQL5" / "Profiles" / "Tester").mkdir(parents=True)
    expert = root / "T11" / "MQL5" / "Experts" / "x.ex5"; expert.write_bytes(b"x")
    setfile = root / "T11" / "MQL5" / "Profiles" / "Tester" / "x.set"; setfile.write_text("x")
    request = canary.CanaryRequest("test", "T12", "x", expert, setfile, "USDJPY.DWX", "H1", "2021.01.01", "2021.12.31", 1, 1, True)
    with pytest.raises(canary.CanaryRefused, match="only inert T11"):
        canary._validate_request(request, mt5_root=root)


def test_stage_is_hash_bound_t11_only_and_writes_receipt(tmp_path, monkeypatch):
    repo = tmp_path / "repo"; repo.mkdir()
    expert = repo / "x.ex5"; expert.write_bytes(b"expert")
    setfile = tmp_path / "x.set"; setfile.write_text("RISK_FIXED=1\nRISK_PERCENT=0\n", encoding="utf-8")
    mt5 = tmp_path / "mt5"; (mt5 / "T11").mkdir(parents=True)
    monkeypatch.setattr(canary, "REPO_ROOT", repo)
    request = canary.StagingRequest("test", "T11", expert, setfile,
        canary.sha256_file(expert), canary.sha256_file(setfile))
    result = canary.stage_inputs(request, mt5_root=mt5, reports_root=tmp_path / "reports")
    assert result["status"] == "STAGED_HASH_VERIFIED"
    assert result["ex5"]["action"] == "copied"
    assert Path(result["receipt_path"]).is_file()
    assert (mt5 / "T11" / "MQL5" / "Experts" / "x.ex5").read_bytes() == b"expert"
    with pytest.raises(canary.CanaryRefused, match="source SHA-256 mismatch"):
        canary.stage_inputs(canary.StagingRequest("test", "T11", expert, setfile,
            "0" * 64, canary.sha256_file(setfile)), mt5_root=mt5, reports_root=tmp_path / "reports")
