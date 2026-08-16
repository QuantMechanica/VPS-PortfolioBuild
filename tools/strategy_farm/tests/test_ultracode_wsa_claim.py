"""ULTRACODE WS-A: shared claim-ordering contract + durable recovery idle-cap.

Covers Codex's round-2 acceptance for A:
  * shared ordering selector (both claimants delegate to pending_claim_order_sql);
  * durable rolling recovery idle-cap (successful-claim ratio, restart continuity,
    ratified idle-only escape);
  * BOTH claim entry points exercised through their REAL production code:
      - terminal_worker.claim_atomic (frontier precedence, idle-only cap);
      - farmctl.dispatch_work_items (claim-then-spawn, full compare-and-swap).

Codex round-1 rejected the `_dispatch_style_claim` REPLICA. This suite therefore drives
the REAL `farmctl.dispatch_work_items` for every dispatch assertion; only MT5 process
spawn / terminal enumeration is stubbed (there is no MetaTrader in the test host).
"""
from __future__ import annotations

import gc
import json
import sqlite3
import sys
import tempfile
import threading
import unittest
from datetime import datetime as dt_datetime, timedelta as dt_timedelta, timezone as dt_timezone
from contextlib import closing
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO))  # terminal_worker imports the `framework` package

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


def _sliding_windows(seq: list[str], size: int):
    for i in range(0, max(0, len(seq) - size + 1)):
        yield seq[i : i + size]


def _seed_active_fleet(db: "_FarmDB", n: "int | None" = None) -> None:
    """Seed enough ACTIVE rows that the occupancy floor keeps the cap regime armed.

    OWNER-ratified amendment 2026-08-11 ("Go, alles freigegeben", evidence
    docs/ops/evidence/2026-08-11_ramp10_soak_evaluation.md): the rolling
    recovery cap binds only while at least CLAIM_RECOVERY_OCCUPANCY_MIN_ACTIVE
    work items are active fleet-wide; below that floor the frontier demonstrably
    cannot fill capacity and recovery takes the idle slot.
    """
    count = farmctl.CLAIM_RECOVERY_OCCUPANCY_MIN_ACTIVE if n is None else n
    for i in range(count):
        db.insert(f"busy{i}", "Q02", f"BUSY{i}", status="active", claimed_by=f"TB{i}")


class _FarmDB:
    """A throwaway file-backed farm DB rooted at a temp dir (root/state/...sqlite)."""

    def __init__(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.root = Path(self._tmp.name)
        farmctl.init_db(self.root)
        self.db = self.root / farmctl.DB_REL

    def close(self) -> None:
        gc.collect()  # finalize any lingering sqlite connections before rmtree
        self._tmp.cleanup()

    def conn(self) -> sqlite3.Connection:
        c = sqlite3.connect(self.db, timeout=30)
        c.row_factory = sqlite3.Row
        c.execute("PRAGMA busy_timeout=30000")
        return c

    def insert(self, wid: str, phase: str, symbol: str, *, status: str = "pending",
               recovery: str | None = None, priority_track: bool = False,
               claimed_by: str | None = None, ea_id: str | None = None,
               raw_payload_json: str | None = None) -> None:
        payload: dict = {}
        if recovery:
            payload["recovery_class"] = recovery
        if priority_track:
            payload["priority_track"] = True
        payload_json = raw_payload_json if raw_payload_json is not None else json.dumps(
            payload, sort_keys=True)
        with closing(self.conn()) as c:
            c.execute(
                "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, "
                "status, verdict, attempt_count, payload_json, created_at, updated_at) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                (wid, "backtest", phase, ea_id or f"QM5_{wid}", symbol, f"{wid}.set",
                 status, None, 0, payload_json,
                 "2026-07-26T00:00:00+00:00", "2026-07-26T00:00:00+00:00"),
            )
            c.commit()

    def order_ids(self) -> list[str]:
        with closing(self.conn()) as c:
            return [r["id"] for r in c.execute(farmctl.pending_claim_order_sql()).fetchall()]

    def ledger_classes(self) -> list[str]:
        with closing(self.conn()) as c:
            return [r["claim_class"] for r in c.execute(
                "SELECT claim_class FROM claim_class_ledger ORDER BY seq ASC").fetchall()]

    def status_of(self, wid: str) -> tuple[str, str | None]:
        with closing(self.conn()) as c:
            r = c.execute("SELECT status, claimed_by FROM work_items WHERE id=?", (wid,)).fetchone()
            return (r["status"], r["claimed_by"])

    def pending_count(self) -> int:
        with closing(self.conn()) as c:
            return c.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]

    def mark_done(self, wid: str) -> None:
        with closing(self.conn()) as c:
            # A completed work item must carry an explicit terminal verdict.
            # These queue-contention tests do not exercise gate economics, so
            # PASS is the neutral successful completion used to free the slot.
            c.execute(
                "UPDATE work_items SET status='done', verdict='PASS' WHERE id=?",
                (wid,),
            )
            c.commit()


def _fake_spawn_factory(spawn_calls: list, observer=None):
    """Return a stub for farmctl._spawn_work_item_runner (no MetaTrader in the host).

    `observer(item, terminal)` (optional) runs at spawn time so a test can assert the
    DB claim was already secured BEFORE the spawn is attempted.
    """
    def _fake_spawn(root, item, terminal):  # noqa: ANN001
        spawn_calls.append((item["id"], terminal))
        if observer is not None:
            observer(item, terminal)
        return {
            "spawned": True,
            "pid": 424242,
            "process_creation_key": "ck",
            "process_image_path": "img",
            "process_started_at_epoch": 1.0,
            "log_path": "log",
            "report_root": "rr",
            "ea_dir_name": "ea",
            "setfile_path": item["setfile_path"],
            "phase_runner": None,
            "effective_min_trades": 5,
        }
    return _fake_spawn


class _DispatchStubMixin:
    """Installs the minimal stubs so REAL farmctl.dispatch_work_items runs in-process:
    fake terminal enumeration, no running-MT5 probe, no MT5 spawn, cheap pid checks."""

    def install_dispatch_stubs(self, terminals: tuple[str, ...], spawn_calls: list,
                               observer=None) -> None:
        saved = {
            "active_mt5_terminals": farmctl.active_mt5_terminals,
            "_running_mt5_terminals": farmctl._running_mt5_terminals,
            "_spawn_work_item_runner": farmctl._spawn_work_item_runner,
            "_pid_tree_exists": farmctl._pid_tree_exists,
            "_pid_exists": farmctl._pid_exists,
        }

        def _restore():
            for name, fn in saved.items():
                setattr(farmctl, name, fn)
        self.addCleanup(_restore)

        farmctl.active_mt5_terminals = lambda *a, **k: tuple(terminals)
        farmctl._running_mt5_terminals = lambda *a, **k: set()
        farmctl._spawn_work_item_runner = _fake_spawn_factory(spawn_calls, observer)
        farmctl._pid_tree_exists = lambda *a, **k: True
        farmctl._pid_exists = lambda *a, **k: True


# ---------------------------------------------------------------------------
# Shared ordering + durable cap primitives (Codex-verified sound; kept as-is).
# ---------------------------------------------------------------------------
class SharedOrderingTests(unittest.TestCase):
    def test_priority_query_delegates_to_shared_selector(self) -> None:
        self.assertEqual(
            terminal_worker._priority_pending_query(), farmctl.pending_claim_order_sql())

    def test_recovery_rows_sort_last_and_frontier_order_preserved(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("q02plain", "Q02", "AAA")
        db.insert("q10", "Q10", "BBB")
        db.insert("q02prio", "Q02", "CCC", priority_track=True)
        db.insert("rec", "Q02", "DDD", recovery="stranded_infra_fail")
        order = db.order_ids()
        self.assertEqual(order[-1], "rec")            # recovery ALWAYS last
        self.assertEqual(order[0], "q02prio")         # priority_track beats phase
        self.assertLess(order.index("q10"), order.index("q02plain"))  # Q10 before Q02

    def test_ordering_inert_without_any_recovery_tag(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("a", "Q02", "AAA")
        db.insert("b", "Q04", "BBB")
        db.insert("c", "Q02", "CCC", priority_track=True)
        # Zero recovery tags -> every _recovery_rank is 0 -> prior contract exactly.
        self.assertEqual(db.order_ids(), ["c", "b", "a"])

    def _assert_payload_priority(self, payload_json: str, *, expected: bool) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("q10plain", "Q10", "AAA")
        db.insert("q02candidate", "Q02", "BBB", raw_payload_json=payload_json)
        order = db.order_ids()
        self.assertEqual(order[0] == "q02candidate", expected)

    def test_priority_track_compact_json_is_prioritized(self) -> None:
        self._assert_payload_priority('{"priority_track":true}', expected=True)

    def test_priority_track_pretty_spaced_json_is_prioritized(self) -> None:
        self._assert_payload_priority('{\n  "priority_track" : true\n}', expected=True)

    def test_priority_track_false_is_not_prioritized(self) -> None:
        self._assert_payload_priority('{"priority_track": false}', expected=False)

    def test_priority_track_numeric_one_is_not_prioritized(self) -> None:
        self._assert_payload_priority('{"priority_track": 1}', expected=False)

    def test_priority_track_float_one_is_not_prioritized(self) -> None:
        self._assert_payload_priority('{"priority_track": 1.0}', expected=False)

    def test_priority_track_missing_is_not_prioritized(self) -> None:
        self._assert_payload_priority('{"other": true}', expected=False)

    def test_priority_track_invalid_json_fails_closed_without_error(self) -> None:
        self._assert_payload_priority('{"priority_track": true', expected=False)

    def test_compact_json_basket_q02_gets_basket_rank(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert(
            "compact-basket",
            "Q02",
            "QM5_TEST_AAA_BBB_COINTEGRATION_H1",
            raw_payload_json='{"portfolio_scope":"basket","priority_track":true}',
        )
        with closing(db.conn()) as conn:
            rows = {
                row["id"]: row
                for row in conn.execute(farmctl.pending_claim_order_sql()).fetchall()
            }
        self.assertEqual(rows["compact-basket"]["_basket_q02_rank"], 0)


class RecoveryCapPrimitiveTests(unittest.TestCase):
    def test_cap_holds_one_in_five_while_frontier_has_work(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")  # persistent non-recovery pending -> cap active
        _seed_active_fleet(db)  # occupancy at the floor -> cap regime binds (OWNER 2026-08-11)
        with closing(db.conn()) as c:
            # Seed ONE fresh priority claim: the amended cap regime requires
            # ledger evidence that the priority lane is alive (else the stall
            # escape correctly lets recovery flood — covered separately).
            c.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c, "T0", "seed", "priority", farmctl.utc_now())
            c.commit()
            for _ in range(30):
                c.execute("BEGIN IMMEDIATE")
                cls = "recovery" if farmctl.recovery_claim_allowed(c) else "priority"
                # Current timestamps: priority claims are flowing, so the stall
                # escape must stay dormant and the 1-in-5 share bound must hold.
                farmctl.record_claim_ledger(c, "T1", "x", cls, farmctl.utc_now())
                c.commit()
        classes = db.ledger_classes()
        for w in _sliding_windows(classes, farmctl.CLAIM_RECOVERY_WINDOW):
            self.assertLessEqual(
                w.count("recovery"), farmctl.CLAIM_RECOVERY_MAX_IN_WINDOW, msg=str(classes))
        self.assertGreaterEqual(classes.count("recovery"), 5)  # genuinely drains ~1/5

    def test_recovery_drains_freely_when_frontier_globally_empty(self) -> None:
        # RATIFIED idle-only escape: no non-recovery pending row anywhere -> every
        # recovery row eligible; the cap must NOT stall the drain.
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("rec1", "Q02", "AAA", recovery="stranded_infra_fail")  # only recovery pending
        with closing(db.conn()) as c:
            for _ in range(5):
                c.execute("BEGIN IMMEDIATE")
                self.assertTrue(farmctl.recovery_claim_allowed(c))
                farmctl.record_claim_ledger(c, "T1", "rec1", "recovery", "t")
                c.commit()

    def test_restart_continuity_reads_persisted_ledger(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")
        _seed_active_fleet(db)  # occupancy at the floor -> cap regime binds (OWNER 2026-08-11)
        with closing(db.conn()) as c:
            c.execute("BEGIN IMMEDIATE")
            # Fresh priority claim -> lane provably alive -> cap regime applies.
            farmctl.record_claim_ledger(c, "T0", "seed", "priority", farmctl.utc_now())
            self.assertTrue(farmctl.recovery_claim_allowed(c))
            farmctl.record_claim_ledger(c, "T1", "x", "recovery", "t")
            c.commit()
        with closing(db.conn()) as c2:   # "restart": brand-new connection
            c2.execute("BEGIN IMMEDIATE")
            self.assertFalse(farmctl.recovery_claim_allowed(c2))  # durable ledger persists
            c2.commit()

    def test_ratio_invariant_holds_under_two_thread_contention(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")  # persistent frontier -> cap stays active
        _seed_active_fleet(db)  # occupancy at the floor -> cap regime binds (OWNER 2026-08-11)
        iters_each = 25
        with closing(db.conn()) as c0:
            c0.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c0, "T0", "seed", "priority", farmctl.utc_now())
            c0.commit()

        def driver() -> None:
            with closing(db.conn()) as c:
                for _ in range(iters_each):
                    for _attempt in range(200):
                        try:
                            c.execute("BEGIN IMMEDIATE")
                        except sqlite3.OperationalError:
                            continue
                        break
                    cls = "recovery" if farmctl.recovery_claim_allowed(c) else "priority"
                    farmctl.record_claim_ledger(c, "T1", "x", cls, "t")
                    c.commit()

        threads = [threading.Thread(target=driver) for _ in range(2)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=60)
        classes = db.ledger_classes()
        self.assertEqual(len(classes), 2 * iters_each + 1)  # no lost writes (+seed)
        for w in _sliding_windows(classes, farmctl.CLAIM_RECOVERY_WINDOW):
            self.assertLessEqual(w.count("recovery"), farmctl.CLAIM_RECOVERY_MAX_IN_WINDOW,
                                 msg=str(classes))


# ---------------------------------------------------------------------------
# Entry point 1: the REAL primary claimant, terminal_worker.claim_atomic.
# ---------------------------------------------------------------------------
class ClaimAtomicIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        # Isolate the claim-ordering/cap logic from the history + RAM resource gates.
        self._orig_hist = terminal_worker._p2_history_claimable
        self._orig_ram = terminal_worker._free_ram_gb
        terminal_worker._p2_history_claimable = lambda *a, **k: (True, None)
        terminal_worker._free_ram_gb = lambda: 999.0

    def tearDown(self) -> None:
        terminal_worker._p2_history_claimable = self._orig_hist
        terminal_worker._free_ram_gb = self._orig_ram

    def test_frontier_precedence_recovery_only_when_priority_idle(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("p1", "Q02", "S1")
        db.insert("p2", "Q03", "S2")  # frontier phase
        db.insert("r1", "Q02", "S3", recovery="stranded_infra_fail")
        db.insert("r2", "Q02", "S4", recovery="deferred_promotion")
        claims: list[tuple[str, str]] = []
        for _ in range(4):
            res = terminal_worker.claim_atomic(db.root, "T1")
            if not res.get("claimed"):
                break
            claims.append((res["item"]["id"], res["claim_class"]))
            db.mark_done(res["item"]["id"])
        classes_by_order = [c for _, c in claims]
        first_recovery = next((i for i, c in enumerate(classes_by_order) if c == "recovery"), None)
        self.assertIsNotNone(first_recovery)
        self.assertTrue(all(c == "priority" for c in classes_by_order[:first_recovery]))
        self.assertEqual({wid for wid, c in claims if c == "priority"}, {"p1", "p2"})

    def test_recovery_drains_through_stalled_ineligible_frontier(self) -> None:
        # AMENDED CONTRACT (OWNER 2026-08-04): frontier rows that are pending but
        # unclaimable must not freeze the fleet. With no priority claim recorded
        # within the stall horizon, recovery drains freely even though frontier
        # rows exist.
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("locked_active", "Q02", "LOCK", status="active", claimed_by="T9")
        # Same (ea_id, symbol) as the active row: the duplicate guard keeps the
        # frontier ineligible under the 2026-08-12 same-symbol cap contract.
        db.insert("locked_pending", "Q02", "LOCK", ea_id="QM5_locked_active")
        db.insert("r1", "Q02", "S1", recovery="stranded_infra_fail")
        db.insert("r2", "Q02", "S2", recovery="stranded_infra_fail")
        res1 = terminal_worker.claim_atomic(db.root, "T1")
        self.assertTrue(res1.get("claimed"))
        self.assertEqual(res1["claim_class"], "recovery")     # priority lane idle -> recovery ok
        db.mark_done(res1["item"]["id"])
        res2 = terminal_worker.claim_atomic(db.root, "T2")    # lane still stalled -> escape
        self.assertTrue(res2.get("claimed"))
        self.assertEqual(res2["claim_class"], "recovery")

    def test_cap_rearms_after_fresh_priority_claim(self) -> None:
        # A recovery entry sits in the window AND a priority claim landed within
        # the stall horizon -> the 1-in-5 share bound applies again.
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")  # keeps the cap regime active
        _seed_active_fleet(db)  # occupancy at the floor -> cap regime binds (OWNER 2026-08-11)
        with closing(db.conn()) as c:
            c.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c, "T1", "r", "recovery", farmctl.utc_now())
            farmctl.record_claim_ledger(c, "T2", "p", "priority", farmctl.utc_now())
            self.assertFalse(farmctl.recovery_claim_allowed(c))
            c.commit()

    def test_stall_escape_opens_when_last_priority_claim_is_stale(self) -> None:
        # Recovery entry in the window, newest priority claim OLDER than the
        # stall horizon -> the lane is provably stalled and recovery may drain.
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")
        stale = (
            dt_datetime.now(dt_timezone.utc)
            - dt_timedelta(minutes=farmctl.CLAIM_RECOVERY_STALL_ESCAPE_MINUTES + 1)
        ).isoformat()
        with closing(db.conn()) as c:
            c.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c, "T2", "p", "priority", stale)
            farmctl.record_claim_ledger(c, "T1", "r", "recovery", farmctl.utc_now())
            self.assertTrue(farmctl.recovery_claim_allowed(c))
            c.commit()

    def test_unparseable_priority_timestamp_keeps_conservative_cap(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")
        _seed_active_fleet(db)  # occupancy at the floor -> cap regime binds (OWNER 2026-08-11)
        with closing(db.conn()) as c:
            c.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c, "T2", "p", "priority", "not-a-timestamp")
            farmctl.record_claim_ledger(c, "T1", "r", "recovery", farmctl.utc_now())
            self.assertFalse(farmctl.recovery_claim_allowed(c))
            c.commit()

    def test_occupancy_escape_opens_below_half_fleet(self) -> None:
        # OWNER-ratified amendment 2026-08-11 ("Go, alles freigegeben"): recovery
        # in the window + priority lane provably alive would deny under the
        # rolling cap — but with fewer than CLAIM_RECOVERY_OCCUPANCY_MIN_ACTIVE
        # active claims the frontier cannot fill the fleet, so recovery may take
        # the idle slot (2026-08-11 trickle regime: 906 recovery rows pending,
        # 2-3/10 terminals busy, stall escape never triggered).
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")
        _seed_active_fleet(db, farmctl.CLAIM_RECOVERY_OCCUPANCY_MIN_ACTIVE - 1)
        with closing(db.conn()) as c:
            c.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c, "T1", "r", "recovery", farmctl.utc_now())
            farmctl.record_claim_ledger(c, "T2", "p", "priority", farmctl.utc_now())
            self.assertTrue(farmctl.recovery_claim_allowed(c))
            c.commit()

    def test_occupancy_escape_stays_closed_at_floor(self) -> None:
        # At exactly the occupancy floor the fleet is meaningfully busy and the
        # ratified 1-in-5 share bound must keep protecting frontier throughput.
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("frontier", "Q02", "FRONT")
        _seed_active_fleet(db)
        with closing(db.conn()) as c:
            c.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c, "T1", "r", "recovery", farmctl.utc_now())
            farmctl.record_claim_ledger(c, "T2", "p", "priority", farmctl.utc_now())
            self.assertFalse(farmctl.recovery_claim_allowed(c))
            c.commit()


# ---------------------------------------------------------------------------
# Entry point 2: the REAL secondary claimant, farmctl.dispatch_work_items.
# Every assertion below drives the production function (NOT a replica).
# ---------------------------------------------------------------------------
class DispatchRealPathTests(_DispatchStubMixin, unittest.TestCase):
    def test_dispatch_secures_claim_before_spawn_and_advances_ledger(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("p0", "Q02", "S0")
        spawn_calls: list = []
        observed: dict = {}

        def observer(item, terminal):
            # At spawn time the DB claim MUST already be secured (claim-then-spawn).
            observed["at_spawn"] = db.status_of(item["id"])

        self.install_dispatch_stubs(("D1",), spawn_calls, observer=observer)
        result = farmctl.dispatch_work_items(db.root)

        self.assertEqual(spawn_calls, [("p0", "D1")])            # spawned exactly once
        self.assertEqual(observed["at_spawn"], ("active", "D1"))  # claim precedes spawn
        self.assertEqual(db.status_of("p0"), ("active", "D1"))    # still owned after enrich
        self.assertEqual(db.ledger_classes(), ["priority"])       # ledger advanced on the claim
        claimed = [a for a in result["actions"] if a.get("action") == "claimed"]
        self.assertEqual(len(claimed), 1)
        self.assertEqual(claimed[0]["claim_class"], "priority")

    def test_dispatch_lost_cas_does_not_spawn_or_overwrite_rival(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("p0", "Q02", "S0")
        spawn_calls: list = []
        self.install_dispatch_stubs(("D1",), spawn_calls)

        # Simulate a concurrent claimant (e.g. claim_atomic) landing the row BETWEEN
        # dispatch's pending snapshot and its compare-and-swap: hook the per-item
        # is_recovery_payload call (which runs after the snapshot, before BEGIN
        # IMMEDIATE) to CAS-claim the row for a rival first.
        orig_is_rec = farmctl.is_recovery_payload
        state = {"raced": False}

        def racing_is_rec(payload):
            if not state["raced"]:
                state["raced"] = True
                with closing(db.conn()) as rc:
                    rc.execute("BEGIN IMMEDIATE")
                    rc.execute("UPDATE work_items SET status='active', claimed_by='RIVAL', "
                               "updated_at='t' WHERE id='p0' AND status='pending'")
                    rc.commit()
            return orig_is_rec(payload)

        farmctl.is_recovery_payload = racing_is_rec
        self.addCleanup(lambda: setattr(farmctl, "is_recovery_payload", orig_is_rec))

        result = farmctl.dispatch_work_items(db.root)

        self.assertEqual(spawn_calls, [])                        # NEVER spawn a row we lost
        self.assertEqual(db.status_of("p0"), ("active", "RIVAL"))  # rival claim NOT overwritten
        self.assertEqual(db.ledger_classes(), [])                # no ledger advance on a lost CAS
        actions = result["actions"]
        self.assertTrue(any(a.get("action") == "claim_lost" for a in actions))
        self.assertFalse(any(a.get("action") == "claimed" for a in actions))

    def test_dispatch_recovery_cap_read_inside_claim_txn_blocks_spawn(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        # An ACTIVE row locks symbol LOCK; a pending frontier row on LOCK stays pending
        # (ineligible) so the frontier is non-empty and the cap regime (not the idle
        # escape) applies. A pending recovery row on a free symbol is then cap-tested.
        db.insert("lock_active", "Q02", "LOCK", status="active", claimed_by="T9")
        # Duplicate (ea_id, symbol) of the active row keeps the frontier
        # ineligible under the 2026-08-12 same-symbol cap contract.
        db.insert("front_locked", "Q02", "LOCK", ea_id="QM5_lock_active")
        db.insert("rec1", "Q02", "S1", recovery="stranded_infra_fail")
        # lock_active plus four more actives reach the occupancy floor, so the
        # cap regime (not the 2026-08-11 occupancy escape) governs this test.
        _seed_active_fleet(db, farmctl.CLAIM_RECOVERY_OCCUPANCY_MIN_ACTIVE - 1)
        with closing(db.conn()) as c:                            # pre-seed cap: last claim = recovery
            c.execute("BEGIN IMMEDIATE")
            # Fresh priority row keeps the cap regime armed under the amended
            # contract (without it the stall escape would rightly admit rec1).
            farmctl.record_claim_ledger(c, "T0", "seed_p", "priority", farmctl.utc_now())
            farmctl.record_claim_ledger(c, "T0", "seed", "recovery", "t")
            c.commit()
        spawn_calls: list = []
        self.install_dispatch_stubs(("D1",), spawn_calls)

        result = farmctl.dispatch_work_items(db.root)

        self.assertEqual(spawn_calls, [])                        # recovery capped -> no spawn
        self.assertEqual(db.status_of("rec1"), ("pending", None))  # recovery row untouched
        self.assertEqual(db.ledger_classes(), ["priority", "recovery"])  # cap NOT advanced by dispatch
        actions = result["actions"]
        self.assertTrue(any(a.get("action") == "recovery_capped" for a in actions))

    def test_dispatch_still_defers_duplicate_symbol(self) -> None:
        # Behaviour-preservation: two pending rows of ONE (ea_id, symbol) ->
        # exactly one claimed+spawned, the other deferred (duplicate guard).
        # Cross-EA same-symbol parallelism is covered by the 2026-08-12 cap
        # tests in test_index_symbol_dispatch_serialization.py.
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("a", "Q02", "SAME", ea_id="QM5_pair")
        db.insert("b", "Q02", "SAME", ea_id="QM5_pair")
        spawn_calls: list = []
        self.install_dispatch_stubs(("D1", "D2"), spawn_calls)
        result = farmctl.dispatch_work_items(db.root)
        self.assertEqual(len(spawn_calls), 1)                       # only one of the pair spawned
        actions = result["actions"]
        self.assertEqual(sum(1 for x in actions if x.get("action") == "claimed"), 1)
        self.assertTrue(any(x.get("action") == "deferred_symbol_lock" for x in actions))

    def test_dispatch_persists_spawn_setfile_and_pid(self) -> None:
        # The enrich UPDATE after a won claim persists the runner's setfile + pid.
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("p0", "Q02", "S0")
        spawn_calls: list = []
        self.install_dispatch_stubs(("D1",), spawn_calls)
        farmctl.dispatch_work_items(db.root)
        with closing(db.conn()) as c:
            row = c.execute("SELECT status, claimed_by, setfile_path, payload_json "
                            "FROM work_items WHERE id='p0'").fetchone()
        self.assertEqual((row["status"], row["claimed_by"]), ("active", "D1"))
        self.assertEqual(row["setfile_path"], "p0.set")            # from the fake spawn dict
        self.assertEqual(json.loads(row["payload_json"])["pid"], 424242)

    def test_dispatch_recovery_drains_when_frontier_globally_empty(self) -> None:
        # RATIFIED idle-only escape on the real dispatch path: with no non-recovery
        # pending row anywhere, a recovery row is claimed even if the last claim was
        # recovery (the cap protects the frontier, and there is none to protect).
        db = _FarmDB()
        self.addCleanup(db.close)
        db.insert("rec1", "Q02", "S1", recovery="stranded_infra_fail")
        with closing(db.conn()) as c:
            c.execute("BEGIN IMMEDIATE")
            farmctl.record_claim_ledger(c, "T0", "seed", "recovery", "t")
            c.commit()
        spawn_calls: list = []
        self.install_dispatch_stubs(("D1",), spawn_calls)

        farmctl.dispatch_work_items(db.root)

        self.assertEqual(spawn_calls, [("rec1", "D1")])          # drained despite prior recovery
        self.assertEqual(db.status_of("rec1"), ("active", "D1"))
        self.assertEqual(db.ledger_classes(), ["recovery", "recovery"])


# ---------------------------------------------------------------------------
# BOTH real entry points under genuine multi-connection contention.
# ---------------------------------------------------------------------------
class BothEntryPointsContentionTests(_DispatchStubMixin, unittest.TestCase):
    def setUp(self) -> None:
        self._orig_hist = terminal_worker._p2_history_claimable
        self._orig_ram = terminal_worker._free_ram_gb
        terminal_worker._p2_history_claimable = lambda *a, **k: (True, None)
        terminal_worker._free_ram_gb = lambda: 999.0

    def tearDown(self) -> None:
        terminal_worker._p2_history_claimable = self._orig_hist
        terminal_worker._free_ram_gb = self._orig_ram

    def test_real_dispatch_and_real_claim_atomic_never_double_claim(self) -> None:
        db = _FarmDB()
        self.addCleanup(db.close)
        n = 30
        for i in range(n):
            db.insert(f"p{i}", "Q02", f"SYM{i}")  # distinct symbols -> all eligible
        spawn_calls: list = []
        self.install_dispatch_stubs(("D1", "D2", "D3", "D4"), spawn_calls)

        claimed: list[str] = []
        lock = threading.Lock()
        stop = threading.Event()

        def record(wid: str) -> None:
            with lock:
                claimed.append(wid)
            db.mark_done(wid)  # free the terminal + symbol so both claimants keep draining

        def dispatch_driver() -> None:
            while not stop.is_set():
                try:
                    result = farmctl.dispatch_work_items(db.root)
                except sqlite3.OperationalError:
                    continue
                got = [a["item_id"] for a in result["actions"] if a.get("action") == "claimed"]
                for wid in got:
                    record(wid)
                if not got and db.pending_count() == 0:
                    return

        def worker_primary(term: str) -> None:
            while not stop.is_set():
                res = terminal_worker.claim_atomic(db.root, term)
                if res.get("claimed"):
                    record(res["item"]["id"])
                    continue
                if res.get("reason") == "sqlite_locked":
                    continue
                if db.pending_count() == 0:
                    return

        threads = [
            threading.Thread(target=dispatch_driver),
            threading.Thread(target=worker_primary, args=("A1",)),
            threading.Thread(target=worker_primary, args=("A2",)),
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=90)
        stop.set()

        # The one invariant that matters: every row claimed AT MOST once across BOTH
        # real entry points (no double-claim under contention), and the queue drained.
        self.assertEqual(len(claimed), len(set(claimed)), msg=f"double-claim: {claimed}")
        self.assertEqual(sorted(claimed), sorted(f"p{i}" for i in range(n)))
        self.assertEqual(db.pending_count(), 0)


if __name__ == "__main__":
    unittest.main()
