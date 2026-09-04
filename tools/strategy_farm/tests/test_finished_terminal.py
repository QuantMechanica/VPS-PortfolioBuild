import json
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import finished_terminal as ft
import health
import process_identity as pi
import terminal_worker as worker

START = "2026-09-04T12:00:00.1234567+02:00"
NOW = datetime.fromisoformat("2026-09-04T12:10:00+02:00")


@pytest.fixture
def fixture(tmp_path):
    item = "wi-finished"
    mt5 = tmp_path / "mt5"
    terminal_dir = mt5 / "T2"
    (terminal_dir / "Tester/logs").mkdir(parents=True)
    (terminal_dir / "logs").mkdir()
    reports = tmp_path / "reports" / item
    raw = reports / "EA/20260904_100000/raw/run_01"; raw.mkdir(parents=True)
    ini = raw / "tester.ini"
    ini.write_text("[Tester]\nOptimization=0\nShutdownTerminal=1\nReport=bound_report.htm\n")
    image = terminal_dir / "terminal64.exe"
    runner = tmp_path / "work_item.log"
    runner.write_text(f"run_smoke.stage=terminal_start exe='{image}' args='/portable /config:{ini}' timeout_seconds=7200\n"
                      f"run_smoke.stage=terminal_spawn_confirmed terminal_pid=4242 start_time='{START}'\n")
    native = terminal_dir / "logs/20260904.log"
    native.write_text(f'AA\t0\t12:00:01.000\tStartup\tsuccessfully initialized from start config "{ini}"\n', encoding="utf-16")
    tester = terminal_dir / "Tester/logs/20260904.log"
    tester.write_text("AA\t0\t12:00:10.000\tTester\tEURUSD: testing of Experts\\EA.ex5\n"
                      "BB\t0\t12:02:00.000\tTester\tautomatic testing finished\n", encoding="utf-16")
    identity = {"is_running": True, "creation_key": ft.windows_creation_key(START), "image_path": str(image)}
    return SimpleNamespace(item=item, mt5=mt5, terminal_dir=terminal_dir, raw=raw, ini=ini, runner=runner,
                           native=native, tester=tester, identity=identity,
                           payload={"log_path": str(runner), "report_root": str(reports)})


def inspect(f, terminal="T2", identity=None):
    return ft.inspect_candidate(f.item, terminal, f.payload, f.mt5,
                                lambda _: f.identity if identity is None else identity, now_utc=NOW)


def test_exact_seven_digit_creation_key():
    # Independently checked with DateTimeOffset.UtcDateTime.ToFileTimeUtc().
    assert ft.windows_creation_key(START) == "windows-filetime:134329896001234567"
    assert ft.windows_creation_key(START.replace("1234567", "1234568")) == "windows-filetime:134329896001234568"
    assert ft.windows_creation_key("2026-09-04T10:00:00.1234567+00:00") == ft.windows_creation_key(START)


@pytest.mark.parametrize("elapsed,expected", [(299, False), (300, False), (301, True)])
def test_strict_five_minute_observation_and_single_exact_pid(fixture, elapsed, expected):
    f, state, stop = fixture, {}, Mock(return_value=True)
    args = (f.item, "T2", f.payload, f.mt5, state)
    assert ft.poll(*args, 0, lambda _: f.identity, stop, now_utc=NOW) is None
    result = ft.poll(*args, elapsed, lambda _: f.identity, stop, now_utc=NOW)
    assert (result is not None) is expected
    if expected:
        assert result["terminal_pid"] == 4242 and result["terminal_stopped"] is True
        assert result["observed_finished_seconds"] == 301
        assert ft.poll(*args, 400, lambda _: f.identity, stop, now_utc=NOW) is None
    assert stop.call_count == int(expected)


@pytest.mark.parametrize("where", ["raw", "source", "source_html", "other_raw"])
def test_even_empty_report_prevents_recovery(fixture, where):
    f = fixture
    path = {"raw": f.raw / "report.htm", "source": f.terminal_dir / "bound_report.htm",
            "source_html": f.terminal_dir / "bound_report.html", "other_raw": f.raw / "other.html"}[where]
    path.touch()
    assert inspect(f) is None


def test_report_appears_during_grace(fixture):
    f, state, stop = fixture, {}, Mock()
    ft.poll(f.item, "T2", f.payload, f.mt5, state, 0, lambda _: f.identity, stop, now_utc=NOW)
    (f.raw / "report.htm").write_text("arrived")
    assert ft.poll(f.item, "T2", f.payload, f.mt5, state, 301, lambda _: f.identity, stop, now_utc=NOW) is None
    stop.assert_not_called()


@pytest.mark.parametrize("change", ["reused_pid", "different_image", "exited", "no_identity"])
def test_identity_refusals(fixture, change):
    identity = dict(fixture.identity)
    if change == "reused_pid": identity["creation_key"] = "windows-filetime:999"
    if change == "different_image": identity["image_path"] = "D:/QM/mt5/T_Live/terminal64.exe"
    if change == "exited": identity["is_running"] = False
    if change == "no_identity": identity = {}
    assert inspect(fixture, identity=identity) is None


@pytest.mark.parametrize("terminal", ["T_Live", "T11", "T0", "T2/../T_Live"])
def test_only_factory_t1_through_t10(fixture, terminal):
    assert inspect(fixture, terminal=terminal) is None


@pytest.mark.parametrize("suffix", ["run_smoke.stage=terminal_exit", "run_smoke.stage=valid_report_latched",
                                  "run_smoke.stage=terminal_start exe='new' args='/config:new'",
                                  "run_smoke.stage=start_terminal terminal=T2 run=run_02"])
def test_runner_progress_invalidates_old_spawn(fixture, suffix):
    with fixture.runner.open("a") as stream: stream.write(suffix + "\n")
    assert inspect(fixture) is None


def test_new_test_after_finish_does_not_kill_active_backtest(fixture):
    with fixture.tester.open("a", encoding="utf-16-le") as stream:
        stream.write("CC\t0\t12:03:00.000\tTester\tEURUSD: testing of Experts\\EA.ex5\n")
    assert inspect(fixture) is None


def test_finish_before_current_process_is_stale(fixture):
    fixture.tester.write_text("AA\t0\t11:59:59.000\tTester\tautomatic testing finished\n", encoding="utf-16")
    assert inspect(fixture) is None


def test_different_terminal_config_is_not_current_run(fixture):
    with fixture.native.open("a", encoding="utf-16-le") as stream:
        stream.write('AA\t0\t12:03:00.000\tStartup\tsuccessfully initialized from start config "D:/other/tester.ini"\n')
    assert inspect(fixture) is None


@pytest.mark.parametrize("match", [True, False])
def test_terminate_checks_same_open_handle_and_never_process_tree(fixture, match):
    candidate = inspect(fixture)
    kernel = SimpleNamespace(OpenProcess=Mock(return_value=77), TerminateProcess=Mock(return_value=True), CloseHandle=Mock())
    observed = dict(fixture.identity)
    if not match: observed["creation_key"] = "reused"
    with patch.object(pi, "_windows_kernel32", return_value=kernel), patch.object(pi, "_configure_windows_process_api"), \
         patch.object(pi, "_windows_identity_from_handle", return_value=observed) as get_identity:
        assert ft.terminate_verified_terminal(candidate) is match
    get_identity.assert_called_once_with(kernel, 77, 4242)
    assert kernel.TerminateProcess.call_count == int(match)
    if match: kernel.TerminateProcess.assert_called_once_with(77, 1)
    kernel.CloseHandle.assert_called_once_with(77)


def test_worker_records_event_and_health_count_without_killing_runner(fixture, tmp_path):
    f = fixture
    conn = sqlite3.connect(":memory:"); conn.row_factory = sqlite3.Row
    conn.execute("CREATE TABLE events(ts,entity_type,entity_id,event,detail_json)")
    evidence = {"event": "terminal_finished_but_alive", "terminal_stopped": True, "terminal_pid": 4242,
                "item_id": f.item, "terminal": "T2", "tester_finished_at_local": "2026-09-04T12:02:00"}
    with patch.object(worker.farmctl, "DEFAULT_ROOT", tmp_path), patch.object(worker.farmctl, "connect", return_value=conn), \
         patch.object(ft, "poll", return_value=evidence), patch.object(worker.farmctl, "_stop_pid_tree") as stop_runner:
        result = worker._recover_finished_terminal(tmp_path, {"id": f.item}, "T2", {"pid": 123}, f.payload, {}, 301)
    assert result["runner_pid"] == 123
    stop_runner.assert_not_called()
    check = health.chk_terminal_finished_but_alive(conn)
    assert check["value"] == 1 and check["terminated"] == 1
    assert conn.execute("SELECT event FROM events").fetchone()[0] == "terminal_finished_but_alive"
    conn.close()


def test_identity_changes_on_final_recheck_refuses_termination(fixture):
    f, state, stop = fixture, {}, Mock()
    identities = iter([f.identity, f.identity, {**f.identity, "creation_key": "reused"}])
    provider = lambda _: next(identities)
    assert ft.poll(f.item, "T2", f.payload, f.mt5, state, 0, provider, stop, now_utc=NOW) is None
    assert ft.poll(f.item, "T2", f.payload, f.mt5, state, 301, provider, stop, now_utc=NOW) is None
    stop.assert_not_called()


def test_recovered_terminal_leaves_runner_and_uses_normal_finish(tmp_path):
    recovery = {"terminal_stopped": True, "terminal_pid": 4242}
    moments = iter([0, 301, 301, 301, 302, 302])
    with (patch.object(worker.time, "monotonic", side_effect=lambda: next(moments)),
          patch.object(worker.time, "sleep"),
          patch.object(worker, "_monitor_deadline_monotonic", return_value=1000),
          patch.object(worker, "_monitor_timeout_seconds", return_value=1000),
          patch.object(worker, "_bound_runner_identity", side_effect=[{"alive": True}, {"alive": False}, {"alive": False}]),
          patch.object(worker, "_terminal_slot_running", return_value=False),
          patch.object(worker, "_work_item_ownership", return_value={"owned": True}),
          patch.object(worker, "_recover_finished_terminal", return_value=recovery),
          patch.object(worker, "_smoke_terminal_exit_stall_grace_seconds", return_value=None),
          patch.object(worker, "_work_item_has_summary_data", return_value=False),
          patch.object(worker, "_sample_tester_memory"),
          patch.object(worker, "_verify_and_record_staged_ex5"),
          patch.object(worker, "_defer_runner_death_or_hold") as defer,
          patch.object(worker.farmctl, "_stop_pid_tree") as kill_runner,
          patch.object(worker, "_finish_work_item", return_value={"finished": True}) as finish):
        result = worker._monitor_spawned_work_item(tmp_path, {"id": "x", "phase": "Q04"}, "T2", {"pid": 123}, {}, 1000)
    defer.assert_not_called(); kill_runner.assert_not_called()
    assert finish.call_args.kwargs["runtime_payload_updates"]["terminal_finished_recoveries"] == [recovery]
    assert result["finished"] is True
