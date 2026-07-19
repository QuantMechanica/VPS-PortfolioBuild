from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import managed_codex  # noqa: E402


def _identity(pid: int, key: str = "creation-A", started: float = 100.0) -> dict[str, object]:
    return {
        "pid": pid,
        "creation_key": key,
        "started_at_epoch": started,
        "image_path": r"C:\Windows\System32\cmd.exe",
    }


def _register(
    monkeypatch,
    root: Path,
    *,
    pid: int = 1234,
    key: str = "creation-A",
    started: float = 100.0,
    max_age_minutes: int = 60,
    dedupe_key: str | None = None,
) -> dict[str, object]:
    monkeypatch.setattr(
        managed_codex,
        "_get_process_identity",
        lambda actual_pid: _identity(actual_pid, key=key, started=started),
    )
    return managed_codex.register_managed_codex_process(
        root,
        pid,
        purpose="build",
        argv=["codex.cmd", "exec", "--cd", r"C:\QM\repo"],
        cwd=r"C:\QM\repo",
        max_age_minutes=max_age_minutes,
        windows_job_name=f"Global\\QMTestJob_{pid}",
        dedupe_key=dedupe_key,
        metadata={"task_id": "build-1"},
        now=started + 1,
    )


def test_reaper_ignores_unleased_old_interactive_codex(tmp_path, monkeypatch) -> None:
    def unexpected_identity(_pid: int):
        raise AssertionError("unleased processes must never be inspected")

    def unexpected_stop(_pid: int, _key: str, **_kwargs):
        raise AssertionError("unleased processes must never be stopped")

    monkeypatch.setattr(managed_codex, "_get_process_identity", unexpected_identity)
    monkeypatch.setattr(managed_codex, "_stop_pid_tree", unexpected_stop)

    result = managed_codex.reap_managed_codex_processes(tmp_path, now=10_000.0)

    assert result["reaped"] == 0
    assert result["pids"] == []


def test_registration_persists_exact_creation_identity_and_metadata(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=4321, key="creation-exact", started=500.0)
    payload = json.loads(Path(str(lease["lease_path"])).read_text(encoding="utf-8"))

    assert payload["owner"] == managed_codex.LEASE_OWNER
    assert payload["pid"] == 4321
    assert payload["process_creation_key"] == "creation-exact"
    assert payload["purpose"] == "build"
    assert payload["metadata"]["task_id"] == "build-1"
    assert payload["windows_job_name"] == r"Global\QMTestJob_4321"
    assert payload["expires_at_epoch"] == 500.0 + 3600.0
    assert "argv_sha256" in payload
    assert "codex.cmd" not in json.dumps(payload)


def test_reaper_kills_expired_matching_managed_process(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=2222, started=100.0)
    stopped: list[tuple[int, str, str | None]] = []

    def stop(pid: int, key: str, **kwargs) -> dict[str, object]:
        stopped.append((pid, key, kwargs.get("windows_job_name")))
        return {"stopped": True, "reason": "stopped", "pid": pid}

    monkeypatch.setattr(managed_codex, "_stop_pid_tree", stop)

    result = managed_codex.reap_managed_codex_processes(tmp_path, now=3_701.0)

    assert stopped == [(2222, "creation-A", r"Global\QMTestJob_2222")]
    assert result["reaped"] == 1
    assert result["pids"] == [2222]
    assert not Path(str(lease["lease_path"])).exists()


def test_reaper_keeps_fresh_matching_managed_process(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=3333, started=100.0)
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(AssertionError("fresh process was stopped")),
    )

    result = managed_codex.reap_managed_codex_processes(tmp_path, now=3_699.0)

    assert result["reaped"] == 0
    assert result["active"] == 1
    assert Path(str(lease["lease_path"])).exists()


def test_reaper_rejects_reused_pid_without_killing(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=4444, key="original", started=100.0)
    monkeypatch.setattr(
        managed_codex,
        "_get_process_identity",
        lambda pid: _identity(pid, key="reused", started=4_000.0),
    )
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(AssertionError("reused PID was stopped")),
    )

    result = managed_codex.reap_managed_codex_processes(tmp_path, now=5_000.0)

    assert result["reaped"] == 0
    assert result["pid_reused"] == 1
    assert not Path(str(lease["lease_path"])).exists()


def test_reaper_cleans_terminated_but_still_queryable_wrapper(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=4545, started=100.0)
    exited = _identity(4545, started=100.0)
    exited["is_running"] = False
    monkeypatch.setattr(managed_codex, "_get_process_identity", lambda _pid: exited)
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(AssertionError("exited wrapper was stopped")),
    )

    result = managed_codex.reap_managed_codex_processes(tmp_path, now=5_000.0)

    assert result["reaped"] == 0
    assert result["cleaned_exited"] == 1
    assert not Path(str(lease["lease_path"])).exists()


def test_malformed_lease_is_quarantined_without_blocking_valid_sibling(
    tmp_path, monkeypatch
) -> None:
    lease = _register(monkeypatch, tmp_path, pid=5555, started=100.0)
    lease_dir = tmp_path / managed_codex.LEASE_DIR_REL
    malformed = lease_dir / "malformed.json"
    malformed.write_text("{definitely not json", encoding="utf-8")
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(AssertionError("fresh process was stopped")),
    )

    result = managed_codex.reap_managed_codex_processes(tmp_path, now=200.0)

    assert result["invalid_leases"] == 1
    assert result["active"] == 1
    assert Path(str(lease["lease_path"])).exists()
    assert not malformed.exists()
    assert list((lease_dir / "quarantine").glob("malformed.json.*.invalid"))


def test_reaper_never_steals_fresh_termination_claim(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=5656, started=100.0)
    claim = managed_codex._claim_lease(Path(str(lease["lease_path"])), now=1_000.0)
    assert claim is not None
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(
            AssertionError("fresh claim was stolen")
        ),
    )

    result = managed_codex.reap_managed_codex_processes(tmp_path, now=1_050.0)

    assert result["claims_in_progress"] == 1
    assert result["reaped"] == 0
    assert claim.exists()


def test_reaper_atomically_recovers_stale_claim(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=5757, started=100.0)
    claim = managed_codex._claim_lease(Path(str(lease["lease_path"])), now=1_000.0)
    assert claim is not None
    stopped: list[int] = []

    def stop(pid: int, _key: str, **_kwargs) -> dict[str, object]:
        stopped.append(pid)
        return {"stopped": True, "reason": "job_terminated", "pid": pid}

    monkeypatch.setattr(managed_codex, "_stop_pid_tree", stop)

    result = managed_codex.reap_managed_codex_processes(
        tmp_path,
        now=1_000.0 + managed_codex.CLAIM_RECOVERY_SECONDS + 1,
    )

    assert stopped == [5757], result
    assert result["reaped"] == 1
    assert not claim.exists()


def test_explicit_terminate_does_not_steal_existing_claim(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=5858, started=100.0)
    claim = managed_codex._claim_lease(Path(str(lease["lease_path"])), now=1_000.0)
    assert claim is not None
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(
            AssertionError("existing claim was stolen")
        ),
    )

    result = managed_codex.terminate_managed_codex_pid(tmp_path, 5858)

    assert result == {"stopped": False, "reason": "stop_in_progress", "pid": 5858}
    assert claim.exists()


def test_live_count_uses_only_identity_matching_leases(tmp_path, monkeypatch) -> None:
    _register(monkeypatch, tmp_path, pid=6666, key="owned", started=100.0)

    def identity(pid: int):
        if pid == 6666:
            return _identity(pid, key="owned", started=100.0)
        return _identity(pid, key="interactive", started=1.0)

    monkeypatch.setattr(managed_codex, "_get_process_identity", identity)

    # PID 7777 represents an old interactive Codex process.  It has no lease,
    # so it cannot affect the farm count even though the OS says it is alive.
    assert identity(7777) is not None
    assert managed_codex.count_live_managed_codex_processes(tmp_path) == 1


def test_dedupe_rejects_second_live_process_for_same_work(tmp_path, monkeypatch) -> None:
    _register(
        monkeypatch,
        tmp_path,
        pid=6767,
        key="owned",
        started=100.0,
        dedupe_key="build:task-1",
    )

    with pytest.raises(managed_codex.ManagedCodexAlreadyRunning):
        managed_codex._assert_no_live_dedupe(tmp_path, "build:task-1")

    managed_codex._assert_no_live_dedupe(tmp_path, "build:task-2")


def test_spawn_fails_closed_when_lease_registration_fails(tmp_path, monkeypatch) -> None:
    class DummyProcess:
        pid = 8888

        def kill(self) -> None:
            raise AssertionError("Job Object cleanup should be attempted first")

    stopped_jobs: list[str] = []
    monkeypatch.setattr(
        managed_codex,
        "_spawn_windows_job_supervisor",
        lambda *args, **kwargs: (DummyProcess(), r"Global\QMTestJob_spawn"),
    )
    monkeypatch.setattr(
        managed_codex,
        "register_managed_codex_process",
        lambda *args, **kwargs: (_ for _ in ()).throw(OSError("disk unavailable")),
    )
    def stop_job(job_name: str, **_kwargs) -> dict[str, object]:
        stopped_jobs.append(job_name)
        return {"stopped": True, "reason": "job_terminated", "job_name": job_name}

    monkeypatch.setattr(managed_codex, "_terminate_windows_job", stop_job)

    with pytest.raises(managed_codex.ManagedCodexError, match="managed Codex spawn failed"):
        managed_codex.spawn_managed_codex(
            tmp_path,
            ["codex.cmd", "exec"],
            purpose="build",
            cwd=tmp_path,
            max_age_minutes=60,
        )

    assert stopped_jobs == [r"Global\QMTestJob_spawn"]


def test_terminate_unmanaged_pid_never_inspects_or_stops_it(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(
        managed_codex,
        "_get_process_identity",
        lambda _pid: (_ for _ in ()).throw(AssertionError("unmanaged PID was inspected")),
    )
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(AssertionError("unmanaged PID was stopped")),
    )

    result = managed_codex.terminate_managed_codex_pid(tmp_path, 9999)

    assert result == {"stopped": False, "reason": "not_managed", "pid": 9999}


def test_terminate_revalidates_creation_identity_before_stop(tmp_path, monkeypatch) -> None:
    lease = _register(monkeypatch, tmp_path, pid=9998, key="original", started=100.0)
    monkeypatch.setattr(
        managed_codex,
        "_get_process_identity",
        lambda pid: _identity(pid, key="reused", started=4_000.0),
    )
    monkeypatch.setattr(
        managed_codex,
        "_stop_pid_tree",
        lambda _pid, _key, **_kwargs: (_ for _ in ()).throw(AssertionError("reused PID was stopped")),
    )

    result = managed_codex.terminate_managed_codex_pid(tmp_path, 9998)

    assert result == {"stopped": False, "reason": "identity_mismatch", "pid": 9998}
    assert not Path(str(lease["lease_path"])).exists()


@pytest.mark.skipif(os.name != "nt", reason="Windows Job Object integration")
def test_windows_job_supervisor_preserves_redirected_stdio(tmp_path) -> None:
    prompt = tmp_path / "prompt.txt"
    output = tmp_path / "output.txt"
    prompt.write_text("managed-stdio-ok\n", encoding="ascii")
    proc = None
    lease = None
    try:
        with prompt.open("rb") as stdin_f, output.open("wb") as stdout_f:
            proc, lease = managed_codex.spawn_managed_codex(
                tmp_path,
                ["cmd.exe", "/d", "/s", "/c", "sort"],
                purpose="windows_stdio_test",
                dedupe_key="test:windows-stdio",
                cwd=REPO,
                max_age_minutes=5,
                stdin=stdin_f,
                stdout=stdout_f,
                stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW,
                close_fds=True,
            )
        assert proc.wait(timeout=10) == 0
        assert lease.get("windows_job_name", "").startswith(
            r"Global\QMStrategyFarmCodex_"
        )
        assert output.read_text(encoding="ascii").strip() == "managed-stdio-ok"
        assert (
            managed_codex.release_managed_codex_process(
                tmp_path, lease_id=str(lease["lease_id"])
            )
            == 1
        )
    finally:
        if proc is not None and proc.poll() is None:
            managed_codex.terminate_managed_codex_pid(tmp_path, proc.pid)
            proc.wait(timeout=10)


@pytest.mark.skipif(os.name != "nt", reason="Windows Job Object integration")
def test_windows_named_job_termination_stops_entire_tree(tmp_path) -> None:
    proc = None
    try:
        proc, _lease = managed_codex.spawn_managed_codex(
            tmp_path,
            [
                "cmd.exe",
                "/d",
                "/s",
                "/c",
                'powershell.exe -NoProfile -Command "Start-Sleep -Seconds 120"',
            ],
            purpose="windows_job_stop_test",
            cwd=REPO,
            max_age_minutes=5,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        stopped = managed_codex.terminate_managed_codex_pid(tmp_path, proc.pid)
        assert stopped["stopped"] is True
        assert stopped["reason"] == "job_terminated"
        proc.wait(timeout=10)
    finally:
        if proc is not None and proc.poll() is None:
            managed_codex.terminate_managed_codex_pid(tmp_path, proc.pid)
            proc.wait(timeout=10)
