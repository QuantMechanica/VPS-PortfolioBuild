from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest


REPO = Path(__file__).resolve().parents[3]
STRATEGY_FARM = REPO / "tools" / "strategy_farm"
sys.path.insert(0, str(STRATEGY_FARM))

from factory_mutation_lock import FactoryMutationLock  # noqa: E402


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
