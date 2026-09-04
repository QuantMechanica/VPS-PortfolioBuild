"""RAM emergency reaper + idle-loop MemoryError hardening (2026-09-05).

Reconstructs the 2026-09-04 08:09Z failure: a Q05 tester ballooned to a 27 GB
working set against an 8 GB reservation, drove the host to 0.6 GB free, and the
OS killed three idle workers. The reaper, run from an idle worker, terminates
the newest FACTORY tester whose subtree working set exceeds 2x its reservation
(never the live terminal, never a COMPILE_EA run), records the item re-runnable
with reason ram_emergency_reap, and captures the observed peak into the
tester-memory ledger. The idle loop catches MemoryError and keeps running.
"""
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import terminal_worker  # noqa: E402

farmctl = terminal_worker.farmctl
GIB = float(1024 ** 3)


def _make_db(root: Path, rows):
    dbp = root / farmctl.DB_REL
    dbp.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(dbp) as conn:
        conn.execute(
            "CREATE TABLE work_items(id TEXT PRIMARY KEY,status TEXT,verdict TEXT,"
            "claimed_by TEXT,ea_id TEXT,symbol TEXT,phase TEXT,payload_json TEXT,"
            "updated_at TEXT)"
        )
        for r in rows:
            conn.execute(
                "INSERT INTO work_items(id,status,verdict,claimed_by,ea_id,symbol,"
                "phase,payload_json,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    r["id"], r.get("status", "active"), r.get("verdict"),
                    r.get("claimed_by"), r.get("ea_id"), r.get("symbol"),
                    r.get("phase"), json.dumps(r.get("payload", {})),
                    farmctl.utc_now(),
                ),
            )
        conn.commit()


def _isolate(monkeypatch, tmp_path):
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")
    monkeypatch.setenv("QM_TESTER_MEMORY_LEDGER", str(tmp_path / "state" / "ledger.jsonl"))
    monkeypatch.setenv("QM_RAM_EMERGENCY_STATE_DIR", str(tmp_path / "reap_state"))
    monkeypatch.delenv("QM_DISABLE_RAM_EMERGENCY_REAP", raising=False)
    monkeypatch.setattr(terminal_worker, "_multisymbol_ea_ids", lambda: frozenset())
    terminal_worker._RAM_EMERGENCY_STATE.update({"consec": 0, "samples": []})


def _tester(term, pid, subtree_gb, create_time, image_path=None):
    return {
        "terminal": term,
        "pid": pid,
        "image_path": image_path or rf"D:\QM\mt5\{term}\terminal64.exe",
        "subtree_ws_bytes": int(subtree_gb * GIB),
        "terminal_ws_bytes": int(2 * GIB),
        "create_time": create_time,
    }


# ---- path anchor --------------------------------------------------------

def test_path_anchor_accepts_factory_rejects_live():
    f = terminal_worker._factory_terminal_from_image_path
    assert f(r"D:\QM\mt5\T9\terminal64.exe") == "T9"
    assert f("D:/QM/mt5/T12/terminal64.exe") == "T12"
    assert f("d:/qm/mt5/t1/terminal64.exe") == "T1"
    # the live terminal is structurally excluded
    assert f(r"C:\QM\mt5\T_Live\terminal64.exe") is None
    assert f("C:/QM/mt5/T_Live/terminal64.exe") is None
    # out-of-range / wrong exe / malformed
    assert f("D:/QM/mt5/T13/terminal64.exe") is None
    assert f("D:/QM/mt5/T9/metatester64.exe") is None
    # anchored to the IMMEDIATE parent: a nested dir is not the factory exe
    assert f("D:/QM/mt5/T9/sub/terminal64.exe") is None
    assert f("") is None
    assert f(None) is None


# ---- selection + requeue + ledger --------------------------------------

def test_reaps_newest_over_reserved_and_requeues(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    _make_db(tmp_path, [
        {"id": "wi-t3", "claimed_by": "T3", "ea_id": "QM5_10395",
         "symbol": "EURJPY.DWX", "phase": "Q05",
         "payload": {"host_timeframe": "H4"}},
        {"id": "wi-t9", "claimed_by": "T9", "ea_id": "QM5_20085",
         "symbol": "GBPJPY.DWX", "phase": "Q05",
         "payload": {"host_timeframe": "H4"}},
    ])
    # T3 has the LARGER working set (27 GB) but is OLDER; T9 is newer -> victim.
    testers = [_tester("T3", 300, 27.0, 100), _tester("T9", 900, 22.0, 200)]
    monkeypatch.setattr(terminal_worker, "_enumerate_factory_testers", lambda: testers)
    killed = []
    monkeypatch.setattr(farmctl, "_stop_pid_tree", lambda pid: killed.append(pid) or True)

    facts = terminal_worker._run_ram_emergency_reap(tmp_path, "T1", [0.6, 0.9])

    assert facts is not None
    assert facts["victim_terminal"] == "T9"
    assert facts["victim_pid"] == 900
    assert facts["reservation_gb"] == 8.0
    assert facts["kill_threshold_gb"] == 16.0
    assert facts["working_set_gb"] == 22.0
    assert facts["candidate_count"] == 2
    assert killed == [900]

    dbp = tmp_path / farmctl.DB_REL
    with sqlite3.connect(dbp) as conn:
        conn.row_factory = sqlite3.Row
        t9 = conn.execute("SELECT * FROM work_items WHERE id='wi-t9'").fetchone()
        t3 = conn.execute("SELECT * FROM work_items WHERE id='wi-t3'").fetchone()
    # victim re-runnable, verdict never written
    assert (t9["status"], t9["verdict"], t9["claimed_by"]) == ("pending", None, None)
    p9 = json.loads(t9["payload_json"])
    assert p9["prior_failure"] == "ram_emergency_reap"
    assert p9["ram_emergency_reap"]["victim_pid"] == 900
    assert p9["ram_emergency_reap_count"] == 1
    # the non-victim stays exactly active
    assert (t3["status"], t3["claimed_by"]) == ("active", "T3")

    # the observed peak is captured so the per-EA key can learn it
    ledger = tmp_path / "state" / "ledger.jsonl"
    lines = ledger.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 1
    rec = json.loads(lines[0])
    assert rec["ea_id"] == "QM5_20085"
    assert rec["outcome"] == "ram_emergency_reap"
    assert rec["peak_subtree_working_set_gb"] == 22.0
    assert rec["run_kind"] == "backtest"
    assert rec["timeframe"] == "H4"


def test_never_reaps_compile_ea(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    _make_db(tmp_path, [
        {"id": "wi-c", "claimed_by": "T5", "ea_id": "QM5_10395",
         "symbol": "EURUSD.DWX", "phase": farmctl.COMPILE_EA_PHASE,
         "payload": {"host_timeframe": "H1"}},
    ])
    testers = [_tester("T5", 500, 50.0, 100)]  # huge WS, but COMPILE_EA
    monkeypatch.setattr(terminal_worker, "_enumerate_factory_testers", lambda: testers)
    killed = []
    monkeypatch.setattr(farmctl, "_stop_pid_tree", lambda pid: killed.append(pid) or True)
    assert terminal_worker._run_ram_emergency_reap(tmp_path, "T1", [0.6, 0.6]) is None
    assert killed == []


def test_never_reaps_live_terminal_path(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    _make_db(tmp_path, [
        {"id": "wi-x", "claimed_by": "T3", "ea_id": "QM5_10395",
         "symbol": "EURJPY.DWX", "phase": "Q05", "payload": {"host_timeframe": "H4"}},
    ])
    # A tester mislabelled T3 but pointing at the LIVE image path must be refused.
    testers = [_tester("T3", 300, 40.0, 100,
                       image_path=r"C:\QM\mt5\T_Live\terminal64.exe")]
    monkeypatch.setattr(terminal_worker, "_enumerate_factory_testers", lambda: testers)
    killed = []
    monkeypatch.setattr(farmctl, "_stop_pid_tree", lambda pid: killed.append(pid) or True)
    assert terminal_worker._run_ram_emergency_reap(tmp_path, "T1", [0.6, 0.6]) is None
    assert killed == []


def test_skips_under_threshold(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    _make_db(tmp_path, [
        {"id": "wi", "claimed_by": "T4", "ea_id": "QM5_10395",
         "symbol": "EURJPY.DWX", "phase": "Q05", "payload": {"host_timeframe": "H4"}},
    ])
    testers = [_tester("T4", 400, 12.0, 100)]  # 12 < 2x8=16
    monkeypatch.setattr(terminal_worker, "_enumerate_factory_testers", lambda: testers)
    killed = []
    monkeypatch.setattr(farmctl, "_stop_pid_tree", lambda pid: killed.append(pid) or True)
    assert terminal_worker._run_ram_emergency_reap(tmp_path, "T1", [0.6, 0.6]) is None
    assert killed == []


def test_skips_tester_without_work_item(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    _make_db(tmp_path, [])  # no active rows
    testers = [_tester("T7", 700, 30.0, 100)]
    monkeypatch.setattr(terminal_worker, "_enumerate_factory_testers", lambda: testers)
    killed = []
    monkeypatch.setattr(farmctl, "_stop_pid_tree", lambda pid: killed.append(pid) or True)
    assert terminal_worker._run_ram_emergency_reap(tmp_path, "T1", [0.6, 0.6]) is None
    assert killed == []


def test_cooldown_blocks_second_reap(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    _make_db(tmp_path, [
        {"id": "wi-a", "claimed_by": "T3", "ea_id": "QM5_10395",
         "symbol": "EURJPY.DWX", "phase": "Q05", "payload": {"host_timeframe": "H4"}},
        {"id": "wi-b", "claimed_by": "T6", "ea_id": "QM5_20085",
         "symbol": "GBPJPY.DWX", "phase": "Q05", "payload": {"host_timeframe": "H4"}},
    ])
    monkeypatch.setattr(
        terminal_worker, "_enumerate_factory_testers",
        lambda: [_tester("T3", 300, 30.0, 100), _tester("T6", 600, 28.0, 90)],
    )
    killed = []
    monkeypatch.setattr(farmctl, "_stop_pid_tree", lambda pid: killed.append(pid) or True)
    first = terminal_worker._run_ram_emergency_reap(tmp_path, "T1", [0.6, 0.6])
    assert first is not None
    # immediate second attempt is inside the wall-clock cool-down
    second = terminal_worker._run_ram_emergency_reap(tmp_path, "T1", [0.6, 0.6])
    assert second is None
    assert killed == [300]  # only the first window reaped


def test_lock_serializes_concurrent_workers(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    # Hold the lease, then a second worker must not act.
    with terminal_worker._ram_emergency_reap_lock() as held:
        assert held is True
        _make_db(tmp_path, [
            {"id": "wi", "claimed_by": "T3", "ea_id": "QM5_10395",
             "symbol": "EURJPY.DWX", "phase": "Q05", "payload": {"host_timeframe": "H4"}},
        ])
        monkeypatch.setattr(
            terminal_worker, "_enumerate_factory_testers",
            lambda: [_tester("T3", 300, 30.0, 100)],
        )
        killed = []
        monkeypatch.setattr(farmctl, "_stop_pid_tree", lambda pid: killed.append(pid) or True)
        assert terminal_worker._run_ram_emergency_reap(tmp_path, "T2", [0.6, 0.6]) is None
        assert killed == []


# ---- consecutive-sample gate + kill switch -----------------------------

def test_requires_consecutive_samples(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    calls = []
    monkeypatch.setattr(
        terminal_worker, "_run_ram_emergency_reap",
        lambda root, term, samples: calls.append(list(samples)) or {"ok": 1},
    )
    # first sub-threshold sample: armed but not fired
    assert terminal_worker._maybe_ram_emergency_reap(tmp_path, "T1", 0.6) is None
    assert calls == []
    # second consecutive sub-threshold sample: fires once
    assert terminal_worker._maybe_ram_emergency_reap(tmp_path, "T1", 0.9) == {"ok": 1}
    assert len(calls) == 1
    assert calls[0][-2:] == [0.6, 0.9]
    # counter reset after firing
    assert terminal_worker._RAM_EMERGENCY_STATE["consec"] == 0


def test_recovered_ram_resets_counter(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    calls = []
    monkeypatch.setattr(
        terminal_worker, "_run_ram_emergency_reap",
        lambda *a: calls.append(a) or {"ok": 1},
    )
    terminal_worker._maybe_ram_emergency_reap(tmp_path, "T1", 0.6)   # consec 1
    terminal_worker._maybe_ram_emergency_reap(tmp_path, "T1", 5.0)   # >= 2.0 resets
    assert terminal_worker._RAM_EMERGENCY_STATE["consec"] == 0
    terminal_worker._maybe_ram_emergency_reap(tmp_path, "T1", 0.6)   # consec 1 again
    assert calls == []


def test_kill_switch_disables_reaper(tmp_path, monkeypatch):
    _isolate(monkeypatch, tmp_path)
    monkeypatch.setenv("QM_DISABLE_RAM_EMERGENCY_REAP", "1")

    def _boom(*a):
        raise AssertionError("reaper must not run when disabled")

    monkeypatch.setattr(terminal_worker, "_run_ram_emergency_reap", _boom)
    assert terminal_worker._maybe_ram_emergency_reap(tmp_path, "T1", 0.5) is None
    assert terminal_worker._maybe_ram_emergency_reap(tmp_path, "T1", 0.5) is None
    assert terminal_worker._RAM_EMERGENCY_STATE["consec"] == 0


# ---- deliverable (3): idle-loop MemoryError hardening -------------------

def test_idle_memoryerror_logger_throttled(capsys, monkeypatch):
    monkeypatch.setattr(terminal_worker, "_IDLE_MEMORYERROR_LOG_AT", -1e9)
    terminal_worker._log_idle_memoryerror("T1")
    terminal_worker._log_idle_memoryerror("T1")  # within window -> suppressed
    out = capsys.readouterr().out
    assert out.count('"idle_loop_memoryerror"') == 1


def test_run_loop_survives_idle_memoryerror(tmp_path, monkeypatch):
    tw = terminal_worker
    monkeypatch.setattr(tw, "release_stale_claims_for_terminal", lambda *a, **k: [])
    monkeypatch.setattr(tw, "reconcile_orphan_claims", lambda *a, **k: [])
    monkeypatch.setattr(tw, "_custom_history_gate", lambda *a, **k: {})

    class _PS:
        def claim_attempt(self):
            pass

        def claim_result(self, claim):
            return None

        def shutdown(self):
            pass

    monkeypatch.setattr(tw, "_make_next_cell_prestage_controller", lambda *a, **k: _PS())

    calls = {"n": 0}

    def _boom():
        calls["n"] += 1
        raise MemoryError("idle oom")

    monkeypatch.setattr(tw, "rebuild_tester_memory_expectations", _boom)
    monkeypatch.setattr(tw, "_IDLE_MEMORYERROR_LOG_AT", -1e9)
    monkeypatch.setattr(tw.random, "uniform", lambda a, b: 0.0)

    def _stop_sleep(_seconds):
        tw._STOP = True

    monkeypatch.setattr(tw.time, "sleep", _stop_sleep)
    monkeypatch.setattr(tw, "_STOP", False)

    rc = tw.run_loop(tmp_path, "T1", 60)
    assert rc == 0                # returned cleanly, did NOT propagate MemoryError
    assert calls["n"] == 1        # entered the body, caught, then stopped
