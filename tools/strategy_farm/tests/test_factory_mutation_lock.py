from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading

import pytest


REPO = Path(__file__).resolve().parents[3]
STRATEGY_FARM = REPO / "tools" / "strategy_farm"
sys.path.insert(0, str(STRATEGY_FARM))

import factory_mutation_lock as mutation_lock  # noqa: E402
from factory_mutation_lock import FactoryMutationLock  # noqa: E402


def _write_old_lock(path: Path, *, pid: int = 999_999) -> bytes:
    record = {
        "pid": pid,
        "owner": "orphaned-pytest-owner",
        "nonce": "a" * 32,
        "created_at": (dt.datetime.now(dt.UTC) - dt.timedelta(minutes=5)).isoformat(),
    }
    payload = (json.dumps(record, sort_keys=True) + "\n").encode("utf-8")
    path.write_bytes(payload)
    return payload


def test_python_lock_record_has_nonce_bound_identity(tmp_path: Path) -> None:
    path = tmp_path / "FACTORY_MUTATION.lock"

    with FactoryMutationLock(path, owner="pytest-owner") as lock:
        # The Windows lock handle deliberately denies all sharing while held;
        # inspect the exact bytes the instance durably wrote.
        assert lock._record_bytes is not None
        record = json.loads(lock._record_bytes.decode("utf-8"))
        assert path.exists()
        created_at = dt.datetime.fromisoformat(record["created_at"])
        assert record["pid"] == os.getpid()
        assert record["owner"] == "pytest-owner"
        assert record["nonce"] == lock.nonce
        assert len(record["nonce"]) == 32
        assert created_at.tzinfo is not None
        assert created_at.utcoffset() == dt.timedelta(0)

    assert not path.exists()
    assert lock.release_succeeded is True
    assert lock.release_status == "released"


def test_python_lock_old_owner_cannot_release_replacement(tmp_path: Path) -> None:
    path = tmp_path / "FACTORY_MUTATION.lock"
    lock = FactoryMutationLock(path, owner="old-owner")
    lock.__enter__()

    # Model a lost/closed owner followed by a new, nonce-distinct lock record.
    assert lock._fd is not None
    os.close(lock._fd)
    lock._fd = None
    replacement = {
        "pid": os.getpid(),
        "owner": "replacement-owner",
        "nonce": "f" * 32,
        "created_at": dt.datetime.now(dt.UTC).isoformat(),
    }
    path.write_text(json.dumps(replacement, sort_keys=True) + "\n", encoding="utf-8")

    lock.__exit__(None, None, None)

    assert json.loads(path.read_text(encoding="utf-8")) == replacement
    assert lock.release_succeeded is False
    assert lock.release_status == "ownership_changed"


def test_python_lock_rejects_blank_owner(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="owner must be non-empty"):
        FactoryMutationLock(tmp_path / "FACTORY_MUTATION.lock", owner="  ")


def test_pid_probe_distinguishes_live_process_from_terminated_process() -> None:
    created_at = dt.datetime.now(dt.UTC)
    assert mutation_lock._pid_identity_state(os.getpid(), created_at) == "live"

    child = subprocess.Popen([sys.executable, "-c", "pass"])
    child_pid = child.pid
    assert child.wait(timeout=10) == 0
    assert mutation_lock._pid_identity_state(child_pid, created_at) in {
        "dead",
        "reused",
    }


@pytest.mark.skipif(os.name != "nt", reason="production content-CAS uses Windows handles")
def test_orphan_lock_self_heals_and_appends_evidence(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    path = tmp_path / "FACTORY_MUTATION.lock"
    evidence_path = tmp_path / "mutation_lock_reaps.jsonl"
    original = _write_old_lock(path)
    monkeypatch.setattr(mutation_lock, "_pid_identity_state", lambda *_: "dead")

    with FactoryMutationLock(
        path,
        owner="pytest-successor",
        stale_reap_seconds=120,
        reap_evidence_path=evidence_path,
    ) as lock:
        assert lock.reap_status == "reaped"
        assert lock._record_bytes != original

    lines = evidence_path.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 1
    audit = json.loads(lines[0])
    assert audit["schema"] == "qm.factory-mutation-lock-reap/v1"
    assert audit["pid_state"] == "dead"
    assert audit["lock_record"]["nonce"] == "a" * 32
    assert audit["reaper_owner"] == "pytest-successor"
    assert not path.exists()


@pytest.mark.skipif(os.name != "nt", reason="production content-CAS uses Windows handles")
def test_live_holder_is_not_reaped_and_busy_result_is_preserved(
    tmp_path: Path,
) -> None:
    path = tmp_path / "FACTORY_MUTATION.lock"
    evidence_path = tmp_path / "mutation_lock_reaps.jsonl"
    with FactoryMutationLock(path, owner="pytest-live-holder"):
        with pytest.raises(RuntimeError, match="stale_reap=unreadable"):
            FactoryMutationLock(
                path,
                owner="pytest-waiter",
                stale_reap_seconds=0,
                reap_evidence_path=evidence_path,
            ).__enter__()

    assert not evidence_path.exists()


@pytest.mark.skipif(os.name != "nt", reason="production content-CAS uses Windows handles")
def test_two_reapers_content_cas_has_exactly_one_winner(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    path = tmp_path / "FACTORY_MUTATION.lock"
    evidence_path = tmp_path / "mutation_lock_reaps.jsonl"
    _write_old_lock(path)
    monkeypatch.setattr(mutation_lock, "_pid_identity_state", lambda *_: "dead")

    barrier = threading.Barrier(2)
    real_delete = mutation_lock._delete_windows_file_if_content_matches

    def racing_delete(candidate_path: Path, expected: bytes) -> str:
        barrier.wait(timeout=5)
        return real_delete(candidate_path, expected)

    monkeypatch.setattr(
        mutation_lock,
        "_delete_windows_file_if_content_matches",
        racing_delete,
    )
    locks = [
        FactoryMutationLock(
            path,
            owner=f"pytest-reaper-{index}",
            stale_reap_seconds=120,
            reap_evidence_path=evidence_path,
        )
        for index in range(2)
    ]
    outcomes: list[str] = []
    failures: list[BaseException] = []

    def reap(lock: FactoryMutationLock) -> None:
        try:
            outcomes.append(lock._try_reap_stale_lock())
        except BaseException as exc:  # surfaced below with both thread outcomes
            failures.append(exc)

    threads = [threading.Thread(target=reap, args=(lock,)) for lock in locks]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=10)

    assert all(not thread.is_alive() for thread in threads)
    assert failures == []
    assert outcomes.count("reaped") == 1
    assert len(evidence_path.read_text(encoding="utf-8").splitlines()) == 1
    assert not path.exists()


def test_powershell_stale_owner_and_content_identity_contract() -> None:
    powershell = shutil.which("powershell.exe") or shutil.which("pwsh")
    if powershell is None:
        pytest.skip("PowerShell is not installed")
    script = STRATEGY_FARM / "tests" / "Test-FactoryMutationLock.ps1"
    result = subprocess.run(
        [
            powershell,
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
        ],
        text=True,
        capture_output=True,
        timeout=60,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Factory mutation-lock tests passed (15 assertions)" in result.stdout


def test_all_autonomous_global_lock_writers_use_nonce_bound_protocol() -> None:
    for name in (
        "codex_fleet_pacer.py",
        "run_worktree_clean_task.py",
        "sweep_enqueue_built_eas.py",
    ):
        source = (STRATEGY_FARM / name).read_text(encoding="utf-8")
        assert "FactoryMutationLock(" in source, name
        assert "FACTORY_MUTATION_LOCK.unlink" not in source, name
        assert "_FACTORY_MUTATION_LOCK.unlink" not in source, name

    snapshot = (REPO / "scripts" / "run_public_snapshot_task.ps1").read_text(
        encoding="utf-8-sig"
    )
    assert "nonce = [guid]::NewGuid().ToString('N')" in snapshot
    assert "Remove-QmFactoryMutationLockIfUnchanged" in snapshot
    assert "Remove-Item -LiteralPath $FactoryMutationLockPath" not in snapshot


def test_factory_powershell_scripts_share_exact_identity_protocol() -> None:
    off = (STRATEGY_FARM / "Factory_OFF.ps1").read_text(encoding="utf-8-sig")
    on = (STRATEGY_FARM / "Factory_ON.ps1").read_text(encoding="utf-8-sig")

    assert "Wait-QmFactoryMutationLockDrain" in off
    assert "owner_pid_reused" in (
        STRATEGY_FARM / "factory_mutation_lock.ps1"
    ).read_text(encoding="utf-8")
    assert "factoryMutationLockRecordBytesBase64" in on
    assert "Remove-QmFactoryMutationLockIfUnchanged" in on
    exit_body = on[
        on.index("function Exit-FactoryMutationLock"):on.index(
            "function Invoke-RepairWithMutationLock"
        )
    ]
    assert "Remove-Item" not in exit_body
    finalizer = on[on.rindex("} finally {"):]
    assert "if (-not $script:factoryRestartMutationLockReleased)" in finalizer
    rollback = finalizer.index("Invoke-FailClosedRollback")
    failure = finalizer.index("FACTORY ON FAILED CLOSED", rollback)
    assert rollback < failure
