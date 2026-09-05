import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import farmctl
import terminal_worker as worker
from claim_wait_turn import ClaimWaitTurn
from factory_mutation_lock import FactoryMutationLock


def test_census_indexes_preserve_every_ordered_row_and_remove_correlated_scan(tmp_path):
    farmctl.init_db(tmp_path)
    with farmctl.connect(tmp_path) as conn:
        for index, (program, arm, year) in enumerate((p, a, y) for p in ("one", "two") for a in ("BUY", "SELL") for y in range(2010, 2027)):
            payload = {"program_id": program, "arm": arm, "year": year, "opt_census_stage": "WF_COMBO",
                       "priority_track": True, "opt_census_frontier_priority": True}
            conn.execute("INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,payload_json,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                         (str(index), "backtest", "OPT_CENSUS", "QM5_9999", "EURUSD.DWX", "fixture.set", "pending", json.dumps(payload), "2026-01-01", "2026-01-01"))
        conn.execute("INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,payload_json,created_at,updated_at) VALUES ('malformed','backtest','Q02','QM5_9998','USDJPY.DWX','fixture.set','pending','not-json','2026-01-01','2026-01-01')")
        sql = farmctl.pending_claim_order_sql()
        indexed = [dict(r) for r in conn.execute(sql)]
        plans = [r[3] for r in conn.execute("EXPLAIN QUERY PLAN " + sql)]
        assert any("idx_work_items_census_earlier" in p for p in plans)
        assert any("idx_work_items_census_active_program" in p for p in plans)
        conn.execute("DROP INDEX idx_work_items_census_earlier")
        conn.execute("DROP INDEX idx_work_items_census_active_program")
        assert indexed == [dict(r) for r in conn.execute(sql)]


def test_ten_contenders_follow_fifo_and_do_not_overlap(tmp_path):
    path = tmp_path / "FACTORY_MUTATION.lock"
    turns = [ClaimWaitTurn(path, time.monotonic() + 5).__enter__() for _ in range(10)]
    completed = []

    def serve(i):
        turn = turns[i]
        try:
            while not turn.is_head():
                assert time.monotonic() < turn.deadline
                time.sleep(.002)
            with FactoryMutationLock(path, owner=f"test:{i}"):
                completed.append(i)
                time.sleep(.002)
        finally:
            turn.__exit__(None, None, None)

    with ThreadPoolExecutor(max_workers=10) as pool:
        list(pool.map(serve, reversed(range(10))))
    assert completed == list(range(10))
    assert not list(turns[0].directory.glob("*.ticket"))
    assert not path.exists()


def test_expired_or_replaced_ticket_cannot_block_or_be_deleted_by_old_owner(tmp_path):
    path = tmp_path / "FACTORY_MUTATION.lock"
    expired = ClaimWaitTurn(path, time.monotonic() - 1).__enter__()
    current = ClaimWaitTurn(path, time.monotonic() + 5).__enter__()
    assert not expired.is_head()
    assert current.is_head()
    current.path.write_bytes(b"replacement")
    current.__exit__(None, None, None)
    assert current.path.read_bytes() == b"replacement"
    expired.__exit__(None, None, None)


def test_preflight_reentries_share_one_wait_budget(tmp_path, monkeypatch):
    from test_terminal_worker_atomic_claim import TerminalWorkerAtomicClaimTests
    fixture = TerminalWorkerAtomicClaimTests()
    fixture.setUp()
    try:
        fixture._insert_work_item(tmp_path, "first", "EURUSD.DWX", phase="Q02")
        fixture._insert_work_item(tmp_path, "second", "GBPUSD.DWX", phase="Q02")
        with farmctl.connect(tmp_path) as conn:
            conn.execute("UPDATE work_items SET created_at='2025-01-01',updated_at='2025-01-01' WHERE id='first'")
            conn.commit()
        entered = []

        class DelayedTurn(ClaimWaitTurn):
            def __enter__(self):
                result = super().__enter__()
                entered.append(self.deadline - time.monotonic())
                time.sleep(.06)
                return result

        monkeypatch.setattr(worker, "ClaimWaitTurn", DelayedTurn)
        monkeypatch.setattr(worker, "FACTORY_ADMISSION_LOCK_TIMEOUT_SECONDS", .10)
        monkeypatch.setattr(worker, "FACTORY_ADMISSION_LOCK_POLL_SECONDS", .005)
        monkeypatch.setattr(worker, "_p2_history_claimable", lambda item, *a: (item["id"] == "second", {}))
        monkeypatch.setattr(farmctl, "_news_calendar_preflight", lambda **kw: {"ok": True})
        result = worker.claim_atomic(tmp_path, "T1")
        assert len(entered) == 2
        assert entered[1] < entered[0] - .05
        assert result["reason"] == "factory_mutation_lock_busy"
        assert not result["claimed"]
        assert result["factory_admission_wait_seconds"] == .1
        with farmctl.connect(tmp_path) as conn:
            assert conn.execute("SELECT status FROM work_items WHERE id='second'").fetchone()[0] == "pending"
    finally:
        fixture.tearDown()


def test_prepared_order_refuses_a_commit_expiry_or_reopened_version_poller(tmp_path):
    farmctl.init_db(tmp_path)
    with farmctl.connect(tmp_path) as conn:
        snapshot = farmctl.prepare_pending_claim_snapshot(conn)
        assert farmctl.pending_claim_snapshot_valid(conn, snapshot)
        with farmctl.connect(tmp_path) as other:
            other.execute("CREATE TABLE snapshot_version_probe(value TEXT)")
            other.commit()
        assert not farmctl.pending_claim_snapshot_valid(conn, snapshot)
        snapshot = farmctl.prepare_pending_claim_snapshot(conn)
        assert farmctl.pending_claim_snapshot_valid(conn, snapshot)
        expired = dict(snapshot, expires_monotonic=time.monotonic() - 1)
        assert not farmctl.pending_claim_snapshot_valid(conn, expired)
        changed_sql = dict(snapshot, sql="SELECT stale_order")
        assert not farmctl.pending_claim_snapshot_valid(conn, changed_sql)
        farmctl._reset_claim_order_pollers()
        assert not farmctl.pending_claim_snapshot_valid(conn, snapshot)


def test_queue_rebuild_never_runs_under_factory_lock(tmp_path, monkeypatch):
    from test_terminal_worker_atomic_claim import TerminalWorkerAtomicClaimTests
    fixture = TerminalWorkerAtomicClaimTests()
    fixture.setUp()
    try:
        fixture._insert_work_item(tmp_path, "only", "EURUSD.DWX", phase="Q02")
        state, tracking = fixture._tracking_factory_lock()
        real = farmctl.execute_pending_claim_order
        calls = []

        def checked(conn, **kwargs):
            assert not state["global_active"]
            calls.append(True)
            return real(conn, **kwargs)

        monkeypatch.setattr(worker, "FactoryMutationLock", tracking)
        monkeypatch.setattr(farmctl, "execute_pending_claim_order", checked)
        monkeypatch.setenv("QM_CLAIM_ORDER_CACHE_TTL_MS", "0")
        result = worker.claim_atomic(tmp_path, "T1")
        assert result["claimed"], result
        assert calls
    finally:
        fixture.tearDown()
