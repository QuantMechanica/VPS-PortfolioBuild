"""Tests for the Q02 summary-missing failure classification (census rank 1, 2026-07-27).

Covers: the forward log-signature classifier (farmctl.classify_summary_missing_run),
the historical DB-join reclassifier cascade + reversible payload-only apply/revert
(classify_summary_missing.py), and the two detectors (health.py). All read/write against
temp SQLite DBs — nothing touches the live factory.
"""
from __future__ import annotations

import json
import sqlite3
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_SF = _HERE.parent
for p in (str(_SF),):
    if p not in sys.path:
        sys.path.insert(0, p)

import farmctl  # noqa: E402
import classify_summary_missing as csm  # noqa: E402
import health  # noqa: E402


def _log(timed_out=False, latched=False, log_bomb=False, start=True):
    lines = []
    if start:
        lines.append("run_smoke.stage=terminal_start terminal=T1")
        lines.append("run_smoke.stage=terminal_spawn_confirmed terminal_pid=1")
    lines.append(
        f"run_smoke.stage=terminal_exit terminal_pid=1 exit_code= "
        f"timed_out={timed_out} valid_report_latched={latched} log_bomb={log_bomb}"
    )
    return "\n".join(lines)


class ForwardClassifier(unittest.TestCase):
    def test_clean_exit_no_report_is_deterministic(self):
        r = farmctl.classify_summary_missing_run({}, _log(latched=False))
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_DETERMINISTIC)
        self.assertEqual(r["failure_subclass"], "no_report")
        self.assertFalse(r["retryable"])

    def test_report_latched_but_no_summary_is_deterministic(self):
        r = farmctl.classify_summary_missing_run({}, _log(latched=True))
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_DETERMINISTIC)
        self.assertEqual(r["failure_subclass"], "report_unparsed")
        self.assertFalse(r["retryable"])

    def test_timeout_is_transient(self):
        r = farmctl.classify_summary_missing_run({}, _log(timed_out=True))
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_TRANSIENT)
        self.assertTrue(r["retryable"])

    def test_log_bomb_is_deterministic(self):
        r = farmctl.classify_summary_missing_run({}, _log(log_bomb=True))
        self.assertEqual(r["failure_subclass"], "log_bomb")
        self.assertFalse(r["retryable"])

    def test_launch_fault_is_transient(self):
        r = farmctl.classify_summary_missing_run({}, "run_smoke.stage=resolved_terminal T1")
        self.assertEqual(r["failure_subclass"], "launch_fault")
        self.assertTrue(r["retryable"])

    def test_deterministic_token_without_log(self):
        r = farmctl.classify_summary_missing_run(
            {"verdict_reason": "run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS"}, None
        )
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_DETERMINISTIC)
        self.assertFalse(r["retryable"])

    def test_transient_token_without_log(self):
        r = farmctl.classify_summary_missing_run(
            {"verdict_reason": "run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS"}, None
        )
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_TRANSIENT)
        self.assertTrue(r["retryable"])

    def test_incomplete_runs_suffix_alone_is_not_transient(self):
        # INCOMPLETE_RUNS is a generic co-occurring suffix; with no other signal and no
        # log it must fail OPEN to UNCLASSIFIED/retryable, never assert a class.
        r = farmctl.classify_summary_missing_run(
            {"verdict_reason": "run_smoke_fail:INCOMPLETE_RUNS"}, None
        )
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_UNCLASSIFIED)
        self.assertTrue(r["retryable"])

    def test_no_evidence_fails_open(self):
        r = farmctl.classify_summary_missing_run({}, None)
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_UNCLASSIFIED)
        self.assertTrue(r["retryable"])

    def test_clean_exit_transient_token_wins_over_no_report(self):
        r = farmctl.classify_summary_missing_run(
            {"verdict_reason": "run_smoke_fail:METATESTER_HUNG"}, _log(latched=False)
        )
        self.assertEqual(r["failure_class"], farmctl.SM_CLASS_TRANSIENT)
        self.assertTrue(r["retryable"])

    def test_last_terminal_exit_wins_on_relaunch(self):
        # first run timed out, relaunch cleanly exited with no report -> deterministic.
        two = _log(timed_out=True) + "\n" + _log(latched=False)
        r = farmctl.classify_summary_missing_run({}, two)
        self.assertEqual(r["failure_subclass"], "no_report")


def _seed_db(path: Path):
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute(
        """CREATE TABLE work_items (id TEXT PRIMARY KEY, ea_id TEXT, symbol TEXT,
           phase TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
           setfile_path TEXT, evidence_path TEXT, claimed_by TEXT,
           payload_json TEXT, created_at TEXT, updated_at TEXT)"""
    )
    return conn


def _gy_payload(**extra):
    p = {"final_failure": csm.GRAVEYARD_TAG}
    p.update(extra)
    return json.dumps(p, sort_keys=True)


class HistoricalCascade(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(self._make_tmp())
        self.conn = _seed_db(self.tmp)
        self.setfile = self.tmp.with_suffix(".set")
        self.setfile.write_text("x", encoding="utf-8")

    def _make_tmp(self):
        import tempfile
        fd, name = tempfile.mkstemp(suffix=".sqlite")
        import os
        os.close(fd)
        return name

    def tearDown(self):
        self.conn.close()
        for p in (self.tmp, self.setfile):
            try:
                Path(p).unlink()
            except OSError:
                pass

    def _ins(self, wid, ea, sym, status, verdict, att=2, payload=None, setfile=None):
        self.conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (wid, ea, sym, "Q02", status, verdict, att,
             setfile if setfile is not None else str(self.setfile),
             None, None, payload if payload is not None else _gy_payload(),
             "2026-06-01T00:00:00Z", "2026-06-01T00:00:00Z"),
        )
        self.conn.commit()

    def _classify(self, wid):
        registry = {1: "active"}  # QM5_1 -> active
        resolved, openp = csm._build_pair_maps(self.conn, "Q02")
        row = self.conn.execute("SELECT * FROM work_items WHERE id=?", (wid,)).fetchone()
        p = json.loads(row["payload_json"])
        return csm._classify_row(
            p, int(row["attempt_count"] or 0), row["ea_id"], row["symbol"],
            row["setfile_path"], resolved_pairs=resolved, open_pairs=openp,
            registry_status=registry, setfile_cache={},
        )

    def test_log_bomb_requires_genuine_marker(self):
        # verdict_reason=LOG_BOMB is the genuine journal-flood kill marker.
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL",
                  payload=_gy_payload(verdict_reason="LOG_BOMB"))
        self.assertEqual(self._classify("a"), (csm.CLASS_DETERMINISTIC, "log_bomb"))

    def test_log_bomb_marker_in_reason_classes(self):
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL",
                  payload=_gy_payload(reason_classes=["LOG_BOMB"]))
        self.assertEqual(self._classify("a"), (csm.CLASS_DETERMINISTIC, "log_bomb"))

    def test_attempt_count_99_alone_is_not_log_bomb(self):
        # Regression guard: a bare attempt_count>=99 with NO genuine marker must NOT be
        # stamped log_bomb (the 4,236-row mislabel of 2026-07-27). It falls through to the
        # honest cascade -> a pair that only ever INFRA_FAILed is never_worked.
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL", att=99)
        self.assertEqual(self._classify("a"), (csm.CLASS_DETERMINISTIC, "never_worked"))

    def test_superseded(self):
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL")
        self._ins("b", "QM5_1", "EURUSD", "done", "FAIL")  # a real verdict on the pair
        self.assertEqual(self._classify("a"), (csm.CLASS_SUPERSEDED, "pair_has_verdict"))

    def test_input_missing_when_setfile_absent(self):
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL", setfile="C:/nope/missing.set")
        self.assertEqual(self._classify("a"), (csm.CLASS_DETERMINISTIC, "input_missing"))

    def test_in_flight(self):
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL")
        self._ins("b", "QM5_1", "EURUSD", "pending", None)  # open successor
        self.assertEqual(self._classify("a"), (csm.CLASS_IN_FLIGHT, "pair_open"))

    def test_transient_token(self):
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL",
                  payload=_gy_payload(verdict_reason="run_smoke_fail:ACTIVE_TIMEOUT"))
        self.assertEqual(self._classify("a"), (csm.CLASS_TRANSIENT, "transient_token"))

    def test_never_worked(self):
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL")
        self._ins("b", "QM5_1", "EURUSD", "failed", "INFRA_FAIL")  # pair only ever INFRA
        self.assertEqual(self._classify("a"), (csm.CLASS_DETERMINISTIC, "never_worked"))

    def test_superseded_beats_input_missing(self):
        # a resolved pair is closeable even if its current setfile is gone
        self._ins("a", "QM5_1", "EURUSD", "failed", "INFRA_FAIL", setfile="C:/nope.set")
        self._ins("b", "QM5_1", "EURUSD", "done", "ZERO_TRADES")
        self.assertEqual(self._classify("a"), (csm.CLASS_SUPERSEDED, "pair_has_verdict"))


class ApplyRevertRoundTrip(unittest.TestCase):
    def setUp(self):
        import tempfile, os
        fd, name = tempfile.mkstemp(suffix=".sqlite")
        os.close(fd)
        self.db = Path(name)
        conn = _seed_db(self.db)
        self.prior = _gy_payload(verdict_reason="run_smoke_fail:NO_HISTORY")
        conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            ("a", "QM5_1", "EURUSD", "Q02", "failed", "INFRA_FAIL", 2, None, None, None,
             self.prior, "2026-06-01T00:00:00Z", "2026-06-01T00:00:00Z"),
        )
        conn.commit()
        conn.close()

    def tearDown(self):
        try:
            self.db.unlink()
        except OSError:
            pass

    def test_apply_stamps_class_and_leaves_verdict_status_untouched(self):
        rows = [{"id": "a", "prior_text": self.prior, "payload": json.loads(self.prior),
                 "failure_class": csm.CLASS_TRANSIENT, "failure_subclass": "transient_token"}]
        changed, skipped = csm._apply(self.db, rows, batch=10)
        self.assertEqual((changed, skipped), (1, 0))
        conn = sqlite3.connect(str(self.db))
        conn.row_factory = sqlite3.Row
        row = conn.execute("SELECT * FROM work_items WHERE id='a'").fetchone()
        p = json.loads(row["payload_json"])
        self.assertEqual(p["failure_class"], csm.CLASS_TRANSIENT)
        self.assertEqual(p["failure_subclass"], "transient_token")
        # verdict/status/attempt/updated_at unchanged -> no requeue, no routing impact
        self.assertEqual(row["verdict"], "INFRA_FAIL")
        self.assertEqual(row["status"], "failed")
        self.assertEqual(row["updated_at"], "2026-06-01T00:00:00Z")
        # prior payload keys preserved
        self.assertEqual(p["final_failure"], csm.GRAVEYARD_TAG)
        conn.close()

    def test_guard_skips_a_row_changed_since_inspection(self):
        rows = [{"id": "a", "prior_text": "STALE-DOES-NOT-MATCH", "payload": {},
                 "failure_class": csm.CLASS_TRANSIENT, "failure_subclass": "x"}]
        changed, skipped = csm._apply(self.db, rows, batch=10)
        self.assertEqual((changed, skipped), (0, 1))  # never clobbers

    def test_full_revert_restores_exact_prior_payload(self):
        import datetime as dt
        rows = [{"id": "a", "prior_text": self.prior, "payload": json.loads(self.prior),
                 "failure_class": csm.CLASS_TRANSIENT, "failure_subclass": "transient_token"}]
        stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
        snap = csm._write_snapshot(rows, self.db, "Q02", stamp)
        try:
            csm._apply(self.db, rows, batch=10)
            restored, skipped = csm._revert(self.db, snap, batch=10)
            self.assertEqual((restored, skipped), (1, 0))
            conn = sqlite3.connect(str(self.db))
            row = conn.execute("SELECT payload_json FROM work_items WHERE id='a'").fetchone()
            self.assertEqual(row[0], self.prior)  # byte-identical restore
            conn.close()
        finally:
            try:
                snap.unlink()
            except OSError:
                pass


class Detectors(unittest.TestCase):
    def _db(self):
        import tempfile, os
        fd, name = tempfile.mkstemp(suffix=".sqlite")
        os.close(fd)
        conn = _seed_db(Path(name))
        return Path(name), conn

    def test_pending_tail_age_warns_on_old_pending(self):
        db, conn = self._db()
        conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            ("a", "QM5_1", "EURUSD", "Q02", "pending", None, 0, None, None, None,
             json.dumps({"recovery_class": True}), "2026-01-01T00:00:00Z", "2026-07-20T00:00:00Z"),
        )
        conn.commit()
        r = health.chk_pending_tail_age(conn)
        self.assertEqual(r["status"], "WARN")
        self.assertEqual(r["value"], 1)
        self.assertIn("recovery_class=1", r["detail"])
        conn.close()
        db.unlink()

    def test_pending_tail_age_ok_when_no_old_rows(self):
        db, conn = self._db()
        r = health.chk_pending_tail_age(conn)
        self.assertEqual(r["status"], "OK")
        conn.close()
        db.unlink()

    def test_unclassified_fails_when_new_rows_lack_class(self):
        db, conn = self._db()
        # 25 recent summary-missing terminals with NO failure_class -> classifier regressed
        for i in range(25):
            conn.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (f"r{i}", "QM5_1", "EURUSD", "Q02", "failed", "INFRA_FAIL", 2, None, None, None,
                 _gy_payload(), "2026-07-27T00:00:00Z", health._utc_now().strftime("%Y-%m-%dT%H:%M:%SZ")),
            )
        conn.commit()
        r = health.chk_q02_summary_missing_unclassified(conn)
        self.assertEqual(r["status"], "FAIL")
        conn.close()
        db.unlink()

    def test_unclassified_ok_when_rows_are_classified(self):
        db, conn = self._db()
        for i in range(25):
            conn.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (f"r{i}", "QM5_1", "EURUSD", "Q02", "failed", "INVALID", 2, None, None, None,
                 _gy_payload(failure_class=farmctl.SM_CLASS_DETERMINISTIC, failure_subclass="no_report"),
                 "2026-07-27T00:00:00Z", health._utc_now().strftime("%Y-%m-%dT%H:%M:%SZ")),
            )
        conn.commit()
        r = health.chk_q02_summary_missing_unclassified(conn)
        self.assertEqual(r["status"], "OK")
        conn.close()
        db.unlink()


if __name__ == "__main__":
    unittest.main(verbosity=2)
