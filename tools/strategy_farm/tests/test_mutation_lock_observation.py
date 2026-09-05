from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path
import sys
import threading
import time

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import factory_mutation_lock as locks
import mutation_lock_observation as observer


def marker(owner="fixture", nonce="a"):
    return {"owner": owner, "pid": os.getpid(), "nonce": nonce,
            "created_at": dt.datetime.now(dt.UTC).isoformat()}


def test_live_exclusive_lock_has_readable_diagnostic_fallback(tmp_path):
    path = tmp_path / "FACTORY_MUTATION.lock"
    with locks.pump_stage("dispatch_tick"):
        with locks.FactoryMutationLock(path, owner="fixture:claim") as lock:
            record = json.loads(lock._record_bytes)
            assert record["stage"] == "dispatch_tick"
            assert record["reason"] == "fixture:claim"
            assert record["exe"] == Path(sys.executable).name
            assert record["argv0"] == Path(sys.argv[0]).name
            assert record["acquired_at"] == record["created_at"]
            result = observer.observe_lock_owner(path)
            assert result["status"] == "observed", result
            assert result["owner"] == "fixture:claim"
            assert result["nonce"] == lock.nonce
            if os.name == "nt":
                assert result["source"] == "unreleased_hold_journal_receipt"
            with pytest.raises((RuntimeError, OSError)):
                with locks.FactoryMutationLock(path, owner="competitor"):
                    pytest.fail("diagnostics must not permit a competing owner")
    assert observer.observe_lock_owner(path)["status"] == "lock_absent"


def test_late_release_of_previous_owner_does_not_hide_successor(tmp_path):
    path = tmp_path / "FACTORY_MUTATION.lock"
    path.write_text("invalid", encoding="utf-8")
    journal = path.with_name(path.name + ".holds.jsonl")
    old, new = marker("old", "a"), marker("new", "b")
    records = [{**old, "event": "ACQUIRED"}, {**new, "event": "ACQUIRED"},
               {**old, "event": "RELEASED"}]
    journal.write_text("\n".join(json.dumps({**r, "lock_path": str(path)}) for r in records))
    result = observer.observe_lock_owner(path)
    assert result["owner"] == "new"
    assert result["diagnostic_only"] is True


def test_released_or_other_lock_is_not_attributed(tmp_path):
    path = tmp_path / "FACTORY_MUTATION.lock"
    path.write_text("invalid")
    journal = path.with_name(path.name + ".holds.jsonl")
    m = {**marker(), "lock_path": str(path)}
    rows = [{**m, "event": "ACQUIRED"}, {**m, "event": "RELEASED"},
            {**marker("other", "b"), "event": "ACQUIRED", "lock_path": str(tmp_path / "other")}]
    journal.write_text("\n".join(map(json.dumps, rows)))
    assert observer.observe_lock_owner(path)["status"] == "no_owner_in_bounded_tail"


def test_oversized_and_corrupt_tail_is_bounded_and_nonfatal(tmp_path):
    path = tmp_path / "FACTORY_MUTATION.lock"
    path.write_text("x" * 5000)
    journal = path.with_name(path.name + ".holds.jsonl")
    row = {**marker(), "event": "ACQUIRED", "lock_path": str(path)}
    journal.write_text("x" * (observer.MAX_TAIL_BYTES * 2) + "\n" + json.dumps(row) + "\n{")
    assert observer.observe_lock_owner(path)["owner"] == "fixture"


def test_slow_filesystem_does_not_queue_readers_or_block_claim_path(monkeypatch):
    release = threading.Event()
    finished = threading.Event()
    calls = []

    def slow(path):
        calls.append(path)
        release.wait(2)
        finished.set()
        return {"status": "late"}

    monkeypatch.setattr(observer, "_read_owner", slow)
    started = time.perf_counter()
    try:
        result = observer.observe_lock_owner("fixture")
        elapsed = time.perf_counter() - started
        assert result["status"] == "read_timeout"
        assert elapsed < 0.05
        assert observer.observe_lock_owner("fixture")["status"] == "reader_busy"
        assert len(calls) == 1
    finally:
        release.set()
        assert finished.wait(2)
        # The daemon releases its single-flight slot immediately after read.
        assert observer._IN_FLIGHT.acquire(timeout=2)
        observer._IN_FLIGHT.release()


def test_reader_failure_is_diagnostic_only(monkeypatch):
    def fail(path):
        raise PermissionError("fixture")
    monkeypatch.setattr(observer, "_read_owner", fail)
    result = observer.observe_lock_owner("fixture")
    assert result["status"] == "unavailable"
    assert result["error"] == "PermissionError"


def test_every_busy_attempt_emits_event_without_changing_backoff(monkeypatch, capsys):
    import terminal_worker as worker
    sleeps = []
    monkeypatch.setattr(worker.time, "sleep", sleeps.append)
    monkeypatch.setattr(worker.random, "uniform", lambda a, b: 0)
    monkeypatch.setattr(worker, "_UNCLAIMED_DECLINE_LOG_LAST", {})
    owner = {"status": "observed", "owner": "fixture", "pid": 7}
    claim = {"reason": "factory_mutation_lock_busy", "lock": "fixture", "lock_owner": owner}
    worker._pause_after_unclaimed(claim, "T3")
    worker._pause_after_unclaimed(claim, "T3")
    records = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    assert sum(r["event"] == "claim_lock_busy" for r in records) == 2
    assert sum(r["event"] == "claim_declined" for r in records) == 1
    assert all(r["lock_owner"] == owner for r in records)
    assert sleeps == [worker.COMMIT_GUARD_SLEEP_SECONDS] * 2
