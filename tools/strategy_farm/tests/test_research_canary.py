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
    assert "Deposit=100000" in ini and "Currency=USD" in ini and "Leverage=100" in ini


def test_tester_defaults_refuse_invalid_currency(tmp_path, monkeypatch):
    registry = tmp_path / "framework/registry"; registry.mkdir(parents=True)
    (registry / "tester_defaults.json").write_text(json.dumps({
        "initial_deposit": 100000, "leverage": 100, "deposit_currency": "USD\nModel=0"}))
    monkeypatch.setattr(canary, "REPO_ROOT", tmp_path)
    with pytest.raises(canary.CanaryRefused, match="invalid canonical"):
        canary.render_tester_ini(expert="x", symbol="USDJPY.DWX", period="H1",
            setfile_name="x.set", from_date="2021.01.01", to_date="2021.12.31", report_rel="x.htm")


def test_resource_guard_refuses_ram_and_agent_limits(monkeypatch):
    class Memory: available = 1
    monkeypatch.setattr(canary.psutil, "virtual_memory", lambda: Memory())
    with pytest.raises(canary.CanaryRefused, match="RAM guard"):
        canary.check_resources(terminal="T11", max_agents=1, cpu_samples=1, sample_seconds=0)


def test_resource_guard_counts_only_t11_owned_metatesters(tmp_path, monkeypatch):
    class Memory: available = 100 * 1024**3
    class Process:
        def __init__(self, pid, executable):
            self.pid = pid
            self.info = {"pid": pid, "name": "metatester64.exe", "exe": str(executable)}
    mt5 = tmp_path / "mt5"
    t11_exe = mt5 / "T11" / "metatester64.exe"; t11_exe.parent.mkdir(parents=True); t11_exe.write_bytes(b"")
    t1_exe = mt5 / "T1" / "metatester64.exe"; t1_exe.parent.mkdir(parents=True); t1_exe.write_bytes(b"")
    monkeypatch.setattr(canary.psutil, "virtual_memory", lambda: Memory())
    monkeypatch.setattr(canary.psutil, "process_iter", lambda _attrs: [Process(1, t11_exe), Process(2, t1_exe)])
    monkeypatch.setattr(canary.psutil, "cpu_percent", lambda interval: 1.0)
    result = canary.check_resources(terminal="T11", max_agents=1, cpu_samples=1, sample_seconds=0, mt5_root=mt5)
    assert result["metatester_agents"] == 1
    assert result["metatester_agent_processes"] == [{"pid": 1, "exe": str(t11_exe.resolve())}]


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


def test_run_captures_relative_report_and_binds_tester_contract(tmp_path, monkeypatch):
    farm = _farm(tmp_path)
    repo = tmp_path / "repo"
    registry = repo / "framework/registry"; registry.mkdir(parents=True)
    (registry / "tester_defaults.json").write_text(json.dumps({
        "initial_deposit": 100000, "deposit_currency": "USD", "leverage": 100}))
    (registry / "tester_groups").mkdir()
    (registry / "tester_groups/Darwinex-Live_real.canonical.txt").write_bytes(b"canonical")
    terminal = tmp_path / "mt5/T11"
    experts = terminal / "MQL5/Experts"; experts.mkdir(parents=True)
    profiles = terminal / "MQL5/Profiles/Tester"; profiles.mkdir(parents=True)
    (profiles / "Groups").mkdir()
    (profiles / "Groups/Darwinex-Live_real.txt").write_bytes(b"canonical")
    expert = experts / "x.ex5"; expert.write_bytes(b"expert")
    setfile = profiles / "x.set"; setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n")
    (terminal / "terminal64.exe").write_bytes(b"test double")
    monkeypatch.setattr(canary, "REPO_ROOT", repo)
    monkeypatch.setattr(canary, "verify_private_history", lambda **kw: {"status": "test double"})
    monkeypatch.setattr(canary, "suspended_runner_creation_flags", lambda: 0)
    monkeypatch.setattr(canary, "bind_spawned_process_to_kill_job", lambda *a, **kw: {"process_creation_key": "test"})
    class Process:
        pid = 123
        def wait(self, timeout): return 0
    def launch(argv, **kw):
        ini = Path(argv[-1].split(":", 1)[1]).read_text(encoding="utf-16")
        name = next(line.split("=", 1)[1] for line in ini.splitlines() if line.startswith("Report="))
        assert Path(name).name == name
        (terminal / name).write_bytes(b"<html>fresh tester report</html>")
        return Process()
    monkeypatch.setattr(canary.subprocess, "Popen", launch)
    request = canary.CanaryRequest("test", "T11", "x.ex5", expert, setfile,
        "USDJPY.DWX", "H1", "2021.01.01", "2021.12.31", 4, 60, False)
    receipt = canary.run(request, farm_root=farm, mt5_root=tmp_path / "mt5",
        reports_root=tmp_path / "reports", resource_check=lambda **kw: {})
    assert receipt["status"] == "COMPLETED_REVIEW_REQUIRED"
    assert receipt["isolation_unchanged"] is True
    assert Path(receipt["report"]["path"]).read_bytes() == b"<html>fresh tester report</html>"
    assert receipt["report"]["sha256"] == canary.sha256_file(Path(receipt["tester_contract"]["report_export_path"]))
    (profiles / "Groups/Darwinex-Live_real.txt").write_bytes(b"different")
    with pytest.raises(canary.CanaryRefused, match="commission group"):
        canary.run(request, farm_root=farm, mt5_root=tmp_path / "mt5",
            reports_root=tmp_path / "reports", resource_check=lambda **kw: {})
