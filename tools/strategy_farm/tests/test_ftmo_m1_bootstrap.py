from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path
from types import SimpleNamespace

import pytest

from tools.strategy_farm import ftmo_lane_runner
from tools.strategy_farm import ftmo_m1_bootstrap as bootstrap


CREATED = "2026-08-08T06:00:00+00:00"


def _process(path: Path, pid: int, created: str = CREATED) -> dict[str, object]:
    return {
        "ProcessId": pid,
        "CreationDate": created,
        "ExecutablePath": str(path),
        "CommandLine": f'"{path}" /portable',
    }


def _write_raw_pair(root: Path, *, tag: str = "TAG", symbol: str = "XAUUSD") -> tuple[Path, Path]:
    raw = root / "raw.jsonl"
    raw.parent.mkdir(parents=True, exist_ok=True)
    rows = [
        {
            "ts": "2026-01-02T10:00:00Z",
            "open": 100.0,
            "high": 101.0,
            "low": 99.0,
            "close": 100.5,
            "tick_volume": 12,
            "spread": 15,
        },
        {
            "ts": "2026-01-02T10:01:00Z",
            "open": 100.5,
            "high": 102.0,
            "low": 100.0,
            "close": 101.5,
            "tick_volume": 13,
            "spread": 16,
        },
    ]
    raw.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
    coverage = root / "coverage.json"
    coverage.write_text(
        json.dumps(
            {
                "schema": bootstrap.HARVEST_COVERAGE_SCHEMA,
                "status": "COMPLETE",
                "extraction_method": bootstrap.EXTRACTION_METHOD,
                "output_tag": tag,
                "symbol": symbol,
                "first_bar": "2026-01-02T10:00:00Z",
                "last_bar": "2026-01-02T10:01:00Z",
                "bar_count": 2,
                "depth_days": 0.000694,
                "tick_first": "2026-08-01T10:00:00Z",
                "tick_last": "2026-08-08T10:00:00Z",
            }
        ),
        encoding="utf-8",
    )
    return raw, coverage


def _published_ftmo_coverage(
    report_root: Path,
    *,
    symbol: str,
    lane: str,
    with_ticks: bool = True,
) -> Path:
    token = "XAUUSD" if symbol == "XAUUSD" else "GER40_cash"
    raw = report_root / f"{token}.raw.jsonl"
    terminal_coverage = report_root / f"{token}.terminal_coverage.json"
    projection = report_root / f"{token}.projection.jsonl"
    hcc = report_root / f"{token}.2026.hcc"
    raw.write_text("raw\n", encoding="utf-8")
    terminal_coverage.write_text("{}\n", encoding="utf-8")
    projection.write_text("projection\n", encoding="utf-8")
    hcc.write_bytes(b"hcc")
    value = {
        "schema": bootstrap.HARVEST_EVIDENCE_SCHEMA,
        "status": "PASS",
        "created_at": "2026-08-08T06:30:00Z",
        "venue": "FTMO",
        "symbol": symbol,
        "evaluator_symbol": "XAUUSD" if symbol == "XAUUSD" else "GDAXI",
        "terminal": lane,
        "terminal_root": str(bootstrap.LANE_ROOTS[lane].resolve()),
        "output_tag": "TAG",
        "extraction_method": bootstrap.EXTRACTION_METHOD,
        "coverage": {
            "first_bar": "2026-01-01T00:00:00Z",
            "last_bar": "2026-08-07T23:59:00Z",
            "bar_count": 100,
            "depth_days": 218.999306,
            "tick_first": "2026-08-01T00:00:00Z" if with_ticks else None,
            "tick_last": "2026-08-07T23:59:00Z" if with_ticks else None,
        },
        "bindings": {
            "raw": bootstrap.file_binding(raw),
            "terminal_coverage": bootstrap.file_binding(terminal_coverage),
            "projection": bootstrap.file_binding(projection),
            "source_hcc": [bootstrap.file_binding(hcc)],
            "run": {"status": "mocked"},
        },
        "claims": {
            "q_pipeline_verdict": "NONE",
            "live_authority": "NONE",
            "autotrading_touched": False,
        },
    }
    path = report_root / f"{token}_FTMO_coverage.json"
    path.write_text(bootstrap.canonical_json(value), encoding="utf-8")
    return path


def test_mql_script_is_static_read_only_and_has_required_harvest_contract() -> None:
    result = bootstrap.validate_mql_source()

    assert result["read_only_static_check"] == "PASS"
    assert result["forbidden_trading_tokens"] == []
    source = bootstrap.SCRIPT_SOURCE.read_text(encoding="utf-8")
    assert "D'2026.01.01 00:00'" in source
    assert "CopyRates(symbol, PERIOD_M1" in source
    assert "CopyTicksRange(symbol" in source
    assert '"ts"' not in source  # emitted through escaped JSON, not a schema include
    assert "\\\"ts\\\"" in source


def test_execution_gate_refuses_before_runtime_work() -> None:
    with pytest.raises(bootstrap.BootstrapError, match="requires --execute"):
        bootstrap.run_ftmo_bootstrap(
            lane="FTMO_STREAM1",
            execute=False,
            timeout_seconds=60,
            replace_projections=False,
        )
    with pytest.raises(bootstrap.BootstrapError, match="requires --execute"):
        bootstrap.run_dxz_bootstrap(
            execute=False,
            timeout_seconds=60,
            replace_projections=False,
            reservation_minutes=10,
        )


def test_dxz_reservation_must_outlive_timeout() -> None:
    with pytest.raises(bootstrap.BootstrapError, match="outlive"):
        bootstrap.run_dxz_bootstrap(
            execute=True,
            timeout_seconds=7200,
            replace_projections=False,
            reservation_minutes=120,
        )


def test_raw_harvest_projects_to_existing_strict_calibration_schema(tmp_path: Path) -> None:
    raw, coverage = _write_raw_pair(tmp_path)
    projection = tmp_path / "XAUUSD_FTMO_M1.jsonl"

    result = bootstrap.project_raw_harvest(
        raw,
        coverage,
        projection,
        symbol="XAUUSD",
        venue="FTMO",
        output_tag="TAG",
    )

    rows = [json.loads(line) for line in projection.read_text(encoding="utf-8").splitlines()]
    assert rows == [
        {
            "schema": "qm.m1-spread-row/v1",
            "symbol": "XAUUSD",
            "venue": "FTMO",
            "time": "2026-01-02T10:00:00Z",
            "spread_points": 15,
        },
        {
            "schema": "qm.m1-spread-row/v1",
            "symbol": "XAUUSD",
            "venue": "FTMO",
            "time": "2026-01-02T10:01:00Z",
            "spread_points": 16,
        },
    ]
    assert result["coverage"]["bar_count"] == 2
    assert result["projection"]["sha256"] == bootstrap.sha256_file(projection)


def test_projection_refuses_duplicate_or_non_increasing_minutes(tmp_path: Path) -> None:
    raw, coverage = _write_raw_pair(tmp_path)
    rows = raw.read_text(encoding="utf-8").splitlines()
    second = json.loads(rows[1])
    second["ts"] = "2026-01-02T10:00:00Z"
    raw.write_text(rows[0] + "\n" + json.dumps(second) + "\n", encoding="utf-8")

    with pytest.raises(bootstrap.BootstrapError, match="not increasing"):
        bootstrap.project_raw_harvest(
            raw,
            coverage,
            tmp_path / "projection.jsonl",
            symbol="XAUUSD",
            venue="FTMO",
            output_tag="TAG",
        )


def test_projection_refuses_coverage_count_mismatch_without_publishing(tmp_path: Path) -> None:
    raw, coverage = _write_raw_pair(tmp_path)
    value = json.loads(coverage.read_text(encoding="utf-8"))
    value["bar_count"] = 3
    coverage.write_text(json.dumps(value), encoding="utf-8")
    projection = tmp_path / "projection.jsonl"

    with pytest.raises(bootstrap.BootstrapError, match="bar_count"):
        bootstrap.project_raw_harvest(
            raw,
            coverage,
            projection,
            symbol="XAUUSD",
            venue="FTMO",
            output_tag="TAG",
        )
    assert not projection.exists()


def test_history_handoff_is_hold_partial_until_both_lane_artifacts_exist(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    lane_root = tmp_path / "FTMO_STREAM1"
    lane_root.mkdir()
    monkeypatch.setitem(bootstrap.LANE_ROOTS, "FTMO_STREAM1", lane_root)
    _published_ftmo_coverage(
        tmp_path,
        symbol="XAUUSD",
        lane="FTMO_STREAM1",
    )

    result = bootstrap.build_history_handoff(
        lane="FTMO_STREAM1",
        observation_path=tmp_path / "observation.json",
        report_root=tmp_path,
    )

    assert result["status"] == "HOLD_PARTIAL"
    assert result["history_observation"] is None
    assert "MISSING_GER40_cash_FTMO_COVERAGE" in result["hold_reasons"]
    assert not (tmp_path / "observation.json").exists()


def test_full_history_handoff_matches_lane_runner_schema(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    lane_root = tmp_path / "FTMO_STREAM1"
    lane_two_root = tmp_path / "FTMO_STREAM2"
    lane_root.mkdir()
    lane_two_root.mkdir()
    monkeypatch.setitem(bootstrap.LANE_ROOTS, "FTMO_STREAM1", lane_root)
    monkeypatch.setitem(bootstrap.LANE_ROOTS, "FTMO_STREAM2", lane_two_root)
    _published_ftmo_coverage(tmp_path, symbol="XAUUSD", lane="FTMO_STREAM1")
    _published_ftmo_coverage(tmp_path, symbol="GER40.cash", lane="FTMO_STREAM2")
    observation_path = tmp_path / "observation.json"

    result = bootstrap.build_history_handoff(
        lane="FTMO_STREAM1",
        observation_path=observation_path,
        report_root=tmp_path,
    )

    assert result["status"] == "READY"
    observation = json.loads(observation_path.read_text(encoding="utf-8"))
    assert observation["schema"] == ftmo_lane_runner.HISTORY_OBSERVATION_SCHEMA
    assert set(observation["symbols"]) == {"XAUUSD", "GER40.cash"}
    history = {
        symbol: {"real_ticks": {}, "m1_bars": {}}
        for symbol in ("XAUUSD", "GER40.cash")
    }
    binding = ftmo_lane_runner._apply_history_observation(
        history,
        observation_path,
        "FTMO_STREAM1",
        lane_root.resolve(),
    )
    assert binding["sha256"] == bootstrap.sha256_file(observation_path)
    assert history["GER40.cash"]["m1_bars"]["coverage_proven"] is True

    lane_two_observation = tmp_path / "observation_stream2.json"
    lane_two = bootstrap.build_history_handoff(
        lane="FTMO_STREAM2",
        observation_path=lane_two_observation,
        report_root=tmp_path,
    )
    assert lane_two["status"] == "READY"
    assert json.loads(lane_two_observation.read_text(encoding="utf-8"))["lane_root"] == str(
        lane_two_root.resolve()
    )


def test_missing_real_tick_window_remains_hold_partial(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    lane_root = tmp_path / "FTMO_STREAM1"
    lane_root.mkdir()
    monkeypatch.setitem(bootstrap.LANE_ROOTS, "FTMO_STREAM1", lane_root)
    _published_ftmo_coverage(
        tmp_path, symbol="XAUUSD", lane="FTMO_STREAM1", with_ticks=False
    )
    _published_ftmo_coverage(tmp_path, symbol="GER40.cash", lane="FTMO_STREAM2")

    result = bootstrap.build_history_handoff(
        lane="FTMO_STREAM1",
        observation_path=tmp_path / "observation.json",
        report_root=tmp_path,
    )

    assert result["status"] == "HOLD_PARTIAL"
    assert "MISSING_XAUUSD_REAL_TICK_WINDOW" in result["hold_reasons"]


def test_ftmo_preflight_requires_stable_challenge_and_zero_lane_processes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    challenge = tmp_path / "Program Files/FTMO/terminal64.exe"
    stream1 = tmp_path / "mt5/FTMO_STREAM1"
    stream2 = tmp_path / "mt5/FTMO_STREAM2"
    monkeypatch.setattr(bootstrap, "CHALLENGE_TERMINAL", challenge)
    monkeypatch.setitem(bootstrap.LANE_ROOTS, "FTMO_STREAM1", stream1)
    monkeypatch.setitem(bootstrap.LANE_ROOTS, "FTMO_STREAM2", stream2)

    result = bootstrap.assert_ftmo_preconditions(
        "FTMO_STREAM1", [_process(challenge, 10)]
    )
    assert result["challenge"]["pid"] == 10
    assert result["autotrading_touched"] is False

    with pytest.raises(bootstrap.BootstrapError, match="serial"):
        bootstrap.assert_ftmo_preconditions(
            "FTMO_STREAM1", [_process(challenge, 10), _process(stream2 / "terminal64.exe", 11)]
        )
    with pytest.raises(bootstrap.BootstrapError, match="exactly one"):
        bootstrap.assert_ftmo_preconditions("FTMO_STREAM1", [])


def test_unknown_terminal_process_makes_factory_preconditions_unclear(tmp_path: Path) -> None:
    with pytest.raises(bootstrap.BootstrapError, match="unclear"):
        bootstrap.classified_terminal_snapshot(
            [_process(tmp_path / "unregistered/terminal64.exe", 90)]
        )


def test_t_live_is_observed_but_never_an_owned_termination_target(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    mt5_root = tmp_path / "mt5"
    live = mt5_root / "T_Live/MT5_Base/terminal64.exe"
    monkeypatch.setattr(bootstrap, "MT5_ROOT", mt5_root)
    snapshot = bootstrap.classified_terminal_snapshot([_process(live, 77)])
    assert snapshot["t_live"][0]["pid"] == 77

    with pytest.raises(bootstrap.BootstrapError, match="outside an owned"):
        bootstrap.terminate_exact_owned_terminal(
            bootstrap.process_identity(_process(live, 77), "T_Live")
        )


def test_exact_factory_termination_is_pid_path_and_creation_bound(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    mt5_root = tmp_path / "mt5"
    terminal = mt5_root / "T3/terminal64.exe"
    monkeypatch.setattr(bootstrap, "MT5_ROOT", mt5_root)
    captured: dict[str, str] = {}

    def fake_powershell(script: str, *, timeout: int = 20) -> dict[str, object]:
        captured["script"] = script
        return {
            "status": "TERMINATED",
            "pid": 123,
            "executable_path": str(terminal),
            "creation_date_utc": "2026-08-08T06:00:00.0000000Z",
        }

    monkeypatch.setattr(bootstrap, "_powershell_json", fake_powershell)
    result = bootstrap.terminate_exact_owned_terminal(
        bootstrap.process_identity(_process(terminal, 123), "T3")
    )

    assert result["status"] == "TERMINATED"
    assert "ProcessId=123" in captured["script"]
    assert "CreationDate drift" in captured["script"]
    assert "Invoke-CimMethod" in captured["script"]


def test_startup_files_keep_experts_disabled_and_bind_script_parameters(tmp_path: Path) -> None:
    terminal_root = tmp_path / "FTMO_STREAM1"
    run_root = tmp_path / "run"
    run_root.mkdir()

    result = bootstrap.prepare_startup_files(
        terminal_root=terminal_root,
        run_root=run_root,
        symbols=["XAUUSD"],
        output_tag="SAFE_TAG",
        include_login=True,
    )

    ini = Path(result["startup_ini"]["path"]).read_text(encoding="utf-8")
    preset = Path(result["preset"]["path"]).read_text(encoding="utf-8")
    assert "Enabled=0" in ini
    assert "AllowLiveTrading=0" in ini
    assert "ScriptParameters=QM_M1_SpreadHarvest_SAFE_TAG.set" in ini
    assert "ShutdownTerminal=0" in ini
    assert "InpSymbols=XAUUSD" in preset
    assert "Enabled=1" not in ini


def test_compile_boundary_uses_lane_metaeditor_and_requires_zero_errors_warnings(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    terminal_root = tmp_path / "FTMO_STREAM1"
    terminal_root.mkdir()
    (terminal_root / "MetaEditor64.exe").write_bytes(b"metaeditor")
    run_root = tmp_path / "run"
    run_root.mkdir()
    monkeypatch.setattr(bootstrap, "scan_metaeditor_processes", lambda: [])
    captured: dict[str, object] = {}

    def fake_run(command: list[str], **kwargs: object) -> SimpleNamespace:
        captured["command"] = command
        staged_source = Path(command[1].removeprefix("/compile:"))
        staged_source.with_suffix(".ex5").write_bytes(b"compiled")
        Path(command[2].removeprefix("/log:")).write_text(
            "Result: 0 errors, 0 warnings\n", encoding="utf-8"
        )
        return SimpleNamespace(returncode=1, stdout="", stderr="")

    monkeypatch.setattr(bootstrap.subprocess, "run", fake_run)
    result = bootstrap.compile_harvest_script(terminal_root, run_root)

    assert captured["command"][0] == str((terminal_root / "MetaEditor64.exe").resolve())
    assert result["errors"] == 0
    assert result["warnings"] == 0
    assert result["ex5"]["sha256"] == bootstrap.sha256_file(
        terminal_root / "MQL5/Scripts/QM/m1_harvest/QM_M1_SpreadHarvest.ex5"
    )


def test_launch_boundary_terminates_only_the_spawned_exact_terminal(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    mt5_root = tmp_path / "mt5"
    terminal_root = mt5_root / "T2"
    terminal_root.mkdir(parents=True)
    terminal = terminal_root / "terminal64.exe"
    terminal.write_bytes(b"terminal")
    challenge = tmp_path / "Program Files/FTMO/terminal64.exe"
    startup = tmp_path / "startup.ini"
    startup.write_text("[StartUp]\n", encoding="utf-8")
    completed = tmp_path / "coverage.json"
    completed.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(bootstrap, "MT5_ROOT", mt5_root)
    monkeypatch.setattr(bootstrap, "CHALLENGE_TERMINAL", challenge)
    calls = {"scan": 0}

    class FakePopen:
        pid = 501

        def __init__(self, command: list[str], **kwargs: object) -> None:
            assert command[0] == str(terminal.resolve())
            assert command[1] == "/portable"
            assert command[2].startswith("/config:")

        def poll(self) -> None:
            return None

    def fake_scan() -> list[dict[str, object]]:
        calls["scan"] += 1
        if calls["scan"] == 1:
            return [_process(challenge, 400)]
        return [_process(challenge, 400), _process(terminal, 501)]

    terminated: list[dict[str, object]] = []

    def fake_terminate(identity: dict[str, object]) -> dict[str, object]:
        terminated.append(identity)
        return {"status": "TERMINATED", "pid": identity["pid"]}

    monkeypatch.setattr(bootstrap.subprocess, "Popen", FakePopen)
    monkeypatch.setattr(bootstrap, "scan_terminal_processes", fake_scan)
    monkeypatch.setattr(bootstrap, "terminate_exact_owned_terminal", fake_terminate)
    challenge_identity = bootstrap.process_identity(_process(challenge, 400), "challenge")

    result = bootstrap.launch_and_wait(
        terminal_root=terminal_root,
        startup_ini=startup,
        expected_artifacts=[completed],
        timeout_seconds=60,
        challenge_identity=challenge_identity,
    )

    assert result["process_identity"]["pid"] == 501
    assert terminated == [result["process_identity"]]
    assert terminated[0]["executable_path"] == str(terminal.resolve())


def test_factory_selection_requires_no_process_claim_or_reservation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    mt5_root = tmp_path / "mt5"
    monkeypatch.setattr(bootstrap, "MT5_ROOT", mt5_root)
    monkeypatch.setattr(bootstrap, "FACTORY_TERMINALS", ("T1", "T2"))
    for terminal in ("T1", "T2"):
        root = mt5_root / terminal
        root.mkdir(parents=True)
        (root / "terminal64.exe").write_bytes(b"terminal")
        (root / "MetaEditor64.exe").write_bytes(b"metaeditor")
    rows = [_process(mt5_root / "T1/terminal64.exe", 11)]

    assert bootstrap.select_free_factory_terminal(rows, set(), {}) == "T2"
    with pytest.raises(bootstrap.BootstrapError, match="no free"):
        bootstrap.select_free_factory_terminal(rows, {"T2"}, {})
    with pytest.raises(bootstrap.BootstrapError, match="no free"):
        bootstrap.select_free_factory_terminal(rows, set(), {"T2": {"reserved_by": "x"}})


def test_active_factory_claims_are_read_only_and_fail_closed_on_invalid_terminal(
    tmp_path: Path,
) -> None:
    database = tmp_path / "farm_state.sqlite"
    with sqlite3.connect(database) as connection:
        connection.execute("CREATE TABLE work_items(status TEXT, claimed_by TEXT)")
        connection.execute("INSERT INTO work_items VALUES('active', 'T4')")
        connection.execute("INSERT INTO work_items VALUES('pending', 'T5')")

    assert bootstrap.read_active_factory_claims(database) == {"T4"}
    with sqlite3.connect(database) as connection:
        connection.execute("INSERT INTO work_items VALUES('active', 'UNKNOWN')")
    with pytest.raises(bootstrap.BootstrapError, match="unclear"):
        bootstrap.read_active_factory_claims(database)


def test_exclusive_lock_refuses_concurrent_bootstrap(tmp_path: Path) -> None:
    path = tmp_path / "bootstrap.lock"
    with bootstrap.exclusive_bootstrap_lock(path) as first:
        assert path.is_file()
        with pytest.raises(bootstrap.BootstrapError, match="another"):
            with bootstrap.exclusive_bootstrap_lock(path):
                pass
        assert first["path"] == str(path.resolve())
    assert not path.exists()


def test_parse_creation_date_accepts_wmi_json_epoch_format():
    """PowerShell 5.1 ConvertTo-Json emits /Date(<epoch_ms>)/ for CIM DateTime."""
    parsed = bootstrap._parse_creation_date("/Date(1785990314288)/", "test row")
    assert parsed.endswith("Z")
    assert parsed.startswith("2026-08-06T")
    with pytest.raises(bootstrap.BootstrapError):
        bootstrap._parse_creation_date("/Date(notanumber)/", "test row")
