"""Safety tests for requeue_stranded_infra.py (Claude, 2026-07-25).

Covers the things that make this mutation tool safe to hand to --apply:
  * SELECTION — only genuinely stranded rows are picked; poison sentinels (log-bomb
    attempt_count=99, LOG_BOMB marker), already-graded siblings, missing setfiles, and the
    below-sweep-cap Q02 set are all REFUSED; Q02 is only reached above the cap.
  * REVERT   — --apply flips + archives the report root, and --revert restores the EXACT
    prior row (status/verdict/attempt_count/evidence/payload/updated_at) and un-archives.
  * transaction-local revalidation aborts (no writes) when a sibling becomes pending between
    plan and apply.
  * CRASH SAFETY (apply/revert ordering, 2026-07-26 rework):
      - the durable journal (== --snapshot-out) is written with the full src->dst archive map +
        pre/post-apply row states BEFORE any filesystem move and BEFORE the DB commit;
      - an exception mid-move rolls the DB back and compensates every completed move;
      - a failed rename aborts the whole apply non-zero (nothing committed);
      - --revert refuses a row that drifted (e.g. a worker claimed it), reverting nothing for it;
      - an un-archive failure aborts --revert BEFORE the DB is touched.
"""

import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import requeue_stranded_infra as rsi  # noqa: E402
import farmctl  # noqa: E402

ORIGINAL_UPDATED_AT = "2024-01-01T00:00:00+00:00"
NO_SKIP = lambda _s: None  # noqa: E731  bypass the real .DWX matrix in hermetic tests
FLAT_PRIO = lambda _e: 0.0  # noqa: E731


class _Base(unittest.TestCase):
    def _make_ea(self, root: Path, ea_num: int, slug: str) -> tuple[Path, Path]:
        d = root / "EAs" / f"QM5_{ea_num}_{slug}"
        (d / "sets").mkdir(parents=True, exist_ok=True)
        (d / f"QM5_{ea_num}.ex5").write_bytes(b"MZ")  # compiled artifact present
        setfile = d / "sets" / f"QM5_{ea_num}_{slug}_EURUSD.DWX_H1_backtest.set"
        setfile.write_text("param=1\n", encoding="utf-8")
        return d, setfile

    def _registry(self, root: Path, rows: list[tuple[int, str, str]]) -> Path:
        p = root / "registry.csv"
        lines = ["ea_id,status,slug"]
        lines += [f"QM5_{n},{status},{slug}" for n, status, slug in rows]
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return p

    def _db(self, root: Path) -> Path:
        db = root / "farm_state.sqlite"
        conn = sqlite3.connect(db)
        conn.execute(
            """CREATE TABLE work_items (
                 id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
                 setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
                 parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
                 payload_json TEXT, created_at TEXT, updated_at TEXT)"""
        )
        conn.commit()
        conn.close()
        return db

    def _insert(self, db: Path, **kw):
        cols = dict(
            id=kw["id"], kind="backtest", phase=kw["phase"], ea_id=kw["ea_id"],
            symbol=kw["symbol"], setfile_path=kw.get("setfile_path"),
            status=kw["status"], verdict=kw.get("verdict"),
            attempt_count=kw.get("attempt_count", 0), parent_task_id=None,
            evidence_path=kw.get("evidence_path"), claimed_by=kw.get("claimed_by"),
            payload_json=json.dumps(kw.get("payload", {})),
            created_at=kw.get("updated_at", ORIGINAL_UPDATED_AT),
            updated_at=kw.get("updated_at", ORIGINAL_UPDATED_AT),
        )
        conn = sqlite3.connect(db)
        conn.execute(
            "INSERT INTO work_items (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,"
            "attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,created_at,"
            "updated_at) VALUES (:id,:kind,:phase,:ea_id,:symbol,:setfile_path,:status,:verdict,"
            ":attempt_count,:parent_task_id,:evidence_path,:claimed_by,:payload_json,:created_at,"
            ":updated_at)", cols)
        conn.commit()
        conn.close()

    def _row(self, db: Path, wid: str):
        conn = sqlite3.connect(db)
        conn.row_factory = sqlite3.Row
        r = conn.execute("SELECT * FROM work_items WHERE id=?", (wid,)).fetchone()
        conn.close()
        return r

    def _cfg(self, root: Path, registry_rows, wi_reports=None):
        return rsi.Config.build(
            db=root / "farm_state.sqlite",
            eas_root=root / "EAs",
            registry_path=self._registry(root, registry_rows),
            wi_reports_root=(wi_reports or (root / "work_items")),
        )


class SelectionTests(_Base):
    def test_stranded_deep_phase_row_is_requeue(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="wi1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="INFRA_FAIL",
                         attempt_count=2, payload={"final_failure": "summary_missing_retries_exhausted"})
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 1)
        self.assertEqual(plan["canary"][0]["work_item_id"], "wi1")
        self.assertEqual(plan["canary"][0]["reason"], "stranded_infra_eligible")

    def test_active_poison_quarantine_excludes_recovery_wave(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="wi1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="INFRA_FAIL")
            conn = sqlite3.connect(db)
            conn.execute(
                "CREATE TABLE poison_pill_quarantine "
                "(ea_id TEXT,symbol TEXT,phase TEXT,active INTEGER)"
            )
            conn.execute(
                "INSERT INTO poison_pill_quarantine VALUES(?,?,?,1)",
                ("QM5_500", "EURUSD.DWX", "Q04"),
            )
            conn.commit()
            conn.close()
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 0)

    def test_poison_attempt_count_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="wi1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="failed", verdict="INFRA_FAIL",
                         attempt_count=99, payload={"final_failure": "log_bomb"})
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 0)
        self.assertEqual(plan["per_phase"]["Q04"]["refuse_reasons"],
                         {"poison_attempt_count_sentinel": 1})

    def test_log_bomb_marker_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="wi1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="INFRA_FAIL",
                         attempt_count=0, payload={"reason_classes": ["LOG_BOMB"]})
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 0)
        self.assertEqual(plan["per_phase"]["Q04"]["refuse_reasons"], {"log_bomb_marker": 1})

    def test_done_non_infra_sibling_excludes_group(self):
        # setfile already produced a real (non-INFRA) verdict -> not stranded, leave it.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="pass1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="PASS",
                         updated_at="2024-01-01T00:00:00+00:00")
            self._insert(db, id="infra1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="INFRA_FAIL",
                         updated_at="2024-02-01T00:00:00+00:00")
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 0)
        self.assertEqual(plan["per_phase"]["Q04"]["stranded_groups"], 0)

    def test_pending_sibling_excludes_group(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="infra1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="INFRA_FAIL")
            self._insert(db, id="pend1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="pending", verdict=None)
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 0)

    def test_setfile_missing_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="wi1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(root / "gone.set"), status="done", verdict="INFRA_FAIL")
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 0)
        self.assertEqual(plan["per_phase"]["Q04"]["refuse_reasons"], {"setfile_missing": 1})

    def test_registry_inactive_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="wi1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="INFRA_FAIL")
            cfg = self._cfg(root, [(500, "retired", "slug")])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        self.assertEqual(plan["eligible_total"], 0)
        self.assertIn("registry_status=retired", plan["per_phase"]["Q04"]["refuse_reasons"])

    def test_q02_below_cap_refused_above_cap_requeued(self):
        orig = farmctl.is_q02_requeue_excluded
        farmctl.is_q02_requeue_excluded = lambda ea, excluded=None: False
        try:
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                _d, sf = self._make_ea(root, 500, "slug")
                _d2, sf2 = self._make_ea(root, 600, "slug6")
                db = self._db(root)
                # below-cap Q02: 3 INFRA rows -> reachable by hourly sweep -> REFUSE
                for i in range(3):
                    self._insert(db, id=f"lo{i}", phase="Q02", ea_id="QM5_500",
                                 symbol="EURUSD.DWX", setfile_path=str(sf),
                                 status="failed", verdict="INFRA_FAIL",
                                 updated_at=f"2024-01-0{i+1}T00:00:00+00:00")
                # above-cap Q02: 12 INFRA rows -> sweep-unreachable -> REQUEUE
                for i in range(12):
                    self._insert(db, id=f"hi{i:02d}", phase="Q02", ea_id="QM5_600",
                                 symbol="EURUSD.DWX", setfile_path=str(sf2),
                                 status="failed", verdict="INFRA_FAIL",
                                 attempt_count=2,
                                 updated_at=f"2024-02-{i+1:02d}T00:00:00+00:00")
                cfg = self._cfg(root, [(500, "active", "slug"), (600, "active", "slug6")])
                plan = rsi._plan(cfg, phases=(), include_q02_exhausted=True, limit=50,
                                 symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
        finally:
            farmctl.is_q02_requeue_excluded = orig
        self.assertEqual(plan["eligible_total"], 1)
        self.assertEqual(plan["canary"][0]["ea_id"], "QM5_600")
        self.assertEqual(plan["canary"][0]["infra_count"], 12)
        self.assertIn("below_sweep_cap_left_to_hourly_sweep",
                      plan["per_phase"]["Q02"]["refuse_reasons"])

    def test_q08_invalid_report_is_never_requeued(self):
        self.assertTrue(rsi._is_q08_invalid_report(
            {"verdict_reason": "phase_runner_invalid_report"}
        ))
        self.assertTrue(rsi._is_q08_invalid_report(
            {"verdict_reason": "q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid"}
        ))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(
                db, id="q08-invalid", phase="Q08", ea_id="QM5_500",
                symbol="EURUSD.DWX", setfile_path=str(sf), status="failed",
                verdict="INFRA_FAIL",
                payload={"verdict_reason": "phase_runner_invalid_report"},
            )
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(
                cfg, phases=("Q08",), include_q02_exhausted=False, limit=5,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
        self.assertEqual(plan["eligible_total"], 0)
        self.assertEqual(
            plan["per_phase"]["Q08"]["refuse_reasons"],
            {"q08_invalid_report_non_retryable": 1},
        )

    def test_pair_that_advanced_to_deeper_phase_is_historical(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _d, sf = self._make_ea(root, 500, "slug")
            db = self._db(root)
            self._insert(db, id="old-q04", phase="Q04", ea_id="QM5_500",
                         symbol="EURUSD.DWX", setfile_path=str(sf), status="failed",
                         verdict="INFRA_FAIL")
            self._insert(db, id="new-q05", phase="Q05", ea_id="QM5_500",
                         symbol="EURUSD.DWX", setfile_path=str(sf), status="failed",
                         verdict="INFRA_FAIL", updated_at="2024-02-01T00:00:00+00:00")
            cfg = self._cfg(root, [(500, "active", "slug")])
            plan = rsi._plan(
                cfg, phases=("Q04",), include_q02_exhausted=False, limit=5,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
        self.assertEqual(plan["eligible_total"], 0)
        self.assertEqual(
            plan["per_phase"]["Q04"]["refuse_reasons"],
            {"historical_phase_advanced": 1},
        )


class HealthCensusTests(_Base):
    def test_cross_phase_census_exposes_dispositions_and_historical_exclusions(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            made = {}
            registry = []
            for num in range(500, 506):
                _d, made[num] = self._make_ea(root, num, f"slug{num}")
                registry.append((num, "retired" if num == 503 else "active", f"slug{num}"))
            db = self._db(root)

            # Q03 has an explicit successor in flight -> RETRY, not stranded.
            self._insert(db, id="q03-infra", phase="Q03", ea_id="QM5_500",
                         symbol="EURUSD.DWX", setfile_path=str(made[500]), status="failed",
                         verdict="INFRA_FAIL")
            self._insert(db, id="q03-next", phase="Q03", ea_id="QM5_500",
                         symbol="EURUSD.DWX", setfile_path=str(made[500]), status="pending",
                         verdict=None, updated_at="2024-02-01T00:00:00+00:00")
            # Q04 is a real retry candidate.
            self._insert(db, id="q04-retry", phase="Q04", ea_id="QM5_501",
                         symbol="EURUSD.DWX", setfile_path=str(made[501]), status="failed",
                         verdict="INFRA_FAIL")
            # Q05 was superseded by a real verdict and remains visible as history.
            self._insert(db, id="q05-infra", phase="Q05", ea_id="QM5_502",
                         symbol="EURUSD.DWX", setfile_path=str(made[502]), status="failed",
                         verdict="INFRA_FAIL")
            self._insert(db, id="q05-pass", phase="Q05", ea_id="QM5_502",
                         symbol="EURUSD.DWX", setfile_path=str(made[502]), status="done",
                         verdict="PASS", updated_at="2024-02-01T00:00:00+00:00")
            # Q06 retired; Q07 poison; Q08 invalid-report boundary.
            self._insert(db, id="q06-retired", phase="Q06", ea_id="QM5_503",
                         symbol="EURUSD.DWX", setfile_path=str(made[503]), status="failed",
                         verdict="INFRA_FAIL")
            self._insert(db, id="q07-poison", phase="Q07", ea_id="QM5_504",
                         symbol="EURUSD.DWX", setfile_path=str(made[504]), status="failed",
                         verdict="INFRA_FAIL", attempt_count=99)
            self._insert(db, id="q08-invalid", phase="Q08", ea_id="QM5_505",
                         symbol="EURUSD.DWX", setfile_path=str(made[505]), status="failed",
                         verdict="INFRA_FAIL",
                         payload={"reason_classes": ["INVALID_REPORT"]})
            cfg = self._cfg(root, registry)

            census = rsi._health_census(cfg, symbol_skip_fn=NO_SKIP)

        self.assertTrue(census["read_only"])
        self.assertEqual(census["phases"], list(rsi.HEALTH_PHASES))
        self.assertEqual(census["invariant"]["status"], "PASS")
        self.assertEqual(census["invariant"]["q08_invalid_report_retryable"], 0)
        self.assertEqual(census["per_phase"]["Q04"]["dispositions"]["RETRY"], 1)
        self.assertEqual(census["per_phase"]["Q05"]["dispositions"]["REAL_VERDICT"], 1)
        self.assertEqual(census["per_phase"]["Q06"]["dispositions"]["RETIRED"], 1)
        self.assertEqual(census["per_phase"]["Q07"]["dispositions"]["BLOCKED"], 1)
        self.assertEqual(census["per_phase"]["Q08"]["q08_invalid_report_blocked"], 1)
        self.assertEqual(
            census["per_phase"]["Q05"]["historical_exclusions"],
            {"superseded_by_real_verdict": 1},
        )


class WaveContractTests(_Base):
    def _cohort(self, root: Path, count: int = 30):
        db = self._db(root)
        registry = []
        for offset in range(count):
            num = 500 + offset
            slug = f"slug{num}"
            _d, sf = self._make_ea(root, num, slug)
            registry.append((num, "active", slug))
            self._insert(
                db, id=f"wi{num}", phase="Q04", ea_id=f"QM5_{num}",
                symbol="EURUSD.DWX", setfile_path=str(sf), status="failed",
                verdict="INFRA_FAIL", attempt_count=1,
                updated_at=f"2024-01-{(offset % 28) + 1:02d}T00:00:00+00:00",
            )
        return db, self._cfg(root, registry)

    @staticmethod
    def _settle(db: Path, ids: list[str], *, fail_id: str | None = None):
        conn = sqlite3.connect(db)
        for wid in ids:
            verdict = "INFRA_FAIL" if wid == fail_id else "PASS"
            conn.execute(
                "UPDATE work_items SET status='done', verdict=?, updated_at=? WHERE id=?",
                (verdict, "2024-03-01T00:00:00+00:00", wid),
            )
        conn.commit()
        conn.close()

    def test_wave1_is_exactly_5_and_pass_receipt_binds_exactly_25(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg = self._cohort(root, 30)
            wave1 = rsi._plan_wave(
                cfg, wave=1, phases=("Q04",), include_q02_exhausted=False,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
            self.assertEqual(wave1["recovery_wave"]["status"], "READY")
            self.assertEqual(wave1["canary_count"], 5)
            journal = root / "wave1.json"
            rsi._apply(cfg, wave1, journal)
            wave1_ids = wave1["recovery_wave"]["selection"]["work_item_ids"]
            self._settle(db, wave1_ids)

            receipt_path = root / "wave1-receipt.json"
            receipt = rsi._write_wave1_receipt(
                cfg, journal, receipt_path, phases=("Q04",),
                include_q02_exhausted=False,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
            self.assertEqual(receipt["assessment"]["gate"], "PASS")
            self.assertEqual(receipt["assessment"]["wave1"]["yield_pct"], 100.0)
            self.assertEqual(receipt["assessment"]["wave1"]["infra_rate_pct"], 0.0)
            self.assertEqual(receipt["assessment"]["wave2"]["selection"]["size"], 25)

            wave2 = rsi._plan_wave(
                cfg, wave=2, phases=("Q04",), include_q02_exhausted=False,
                wave1_receipt=receipt_path,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
            self.assertEqual(wave2["recovery_wave"]["status"], "READY")
            self.assertEqual(wave2["canary_count"], 25)
            self.assertEqual(
                wave2["recovery_wave"]["selection"]["sha256"],
                receipt["assessment"]["wave2"]["selection"]["sha256"],
            )

    def test_wave1_infra_recurrence_blocks_receipt_and_wave2(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg = self._cohort(root, 30)
            wave1 = rsi._plan_wave(
                cfg, wave=1, phases=("Q04",), include_q02_exhausted=False,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
            journal = root / "wave1.json"
            rsi._apply(cfg, wave1, journal)
            ids = wave1["recovery_wave"]["selection"]["work_item_ids"]
            self._settle(db, ids, fail_id=ids[0])
            receipt_path = root / "blocked-receipt.json"
            receipt = rsi._write_wave1_receipt(
                cfg, journal, receipt_path, phases=("Q04",),
                include_q02_exhausted=False,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
            self.assertEqual(receipt["assessment"]["gate"], "BLOCKED")
            self.assertTrue(any(
                reason.startswith("wave1_infra_recurrence:")
                for reason in receipt["assessment"]["blockers"]
            ))
            with self.assertRaises(RuntimeError):
                rsi._plan_wave(
                    cfg, wave=2, phases=("Q04",), include_q02_exhausted=False,
                    wave1_receipt=receipt_path,
                    symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
                )

    def test_wave2_requires_receipt_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg = self._cohort(root, 30)
            with self.assertRaises(RuntimeError):
                rsi._plan_wave(
                    cfg, wave=2, phases=("Q04",), include_q02_exhausted=False,
                    symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
                )

            wave1 = rsi._plan_wave(
                cfg, wave=1, phases=("Q04",), include_q02_exhausted=False,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
            journal = root / "wave1.json"
            rsi._apply(cfg, wave1, journal)
            self._settle(db, wave1["recovery_wave"]["selection"]["work_item_ids"])
            receipt_path = root / "receipt.json"
            receipt = rsi._write_wave1_receipt(
                cfg, journal, receipt_path, phases=("Q04",),
                include_q02_exhausted=False,
                symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
            )
            receipt["assessment"]["decision_digest"] = "0" * 64
            rsi._write_journal(receipt_path, receipt)
            with self.assertRaises(RuntimeError):
                rsi._plan_wave(
                    cfg, wave=2, phases=("Q04",), include_q02_exhausted=False,
                    wave1_receipt=receipt_path,
                    symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO,
                )


class ApplyRevertTests(_Base):
    def _stranded(self, root):
        _d, sf = self._make_ea(root, 500, "slug")
        db = self._db(root)
        wi_reports = root / "work_items"
        (wi_reports / "wi1").mkdir(parents=True)
        (wi_reports / "wi1" / "report.csv").write_text("evidence", encoding="utf-8")
        self._insert(db, id="wi1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                     setfile_path=str(sf), status="done", verdict="INFRA_FAIL",
                     attempt_count=2, evidence_path=str(wi_reports / "wi1" / "report.csv"),
                     payload={"final_failure": "summary_missing_retries_exhausted",
                              "pid": 1234, "host_symbol": "EURUSD.DWX"})
        cfg = self._cfg(root, [(500, "active", "slug")], wi_reports=wi_reports)
        return db, cfg, wi_reports

    def test_apply_flips_and_archives_then_revert_restores_exact(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports = self._stranded(root)
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
            self.assertEqual(plan["canary_count"], 1)
            before = self._row(db, "wi1")
            prior_payload = before["payload_json"]

            snap = root / "snap.json"
            result = rsi._apply(cfg, plan, snap)
            self.assertEqual(result["requeued"], 1)
            after = self._row(db, "wi1")
            self.assertEqual(after["status"], "pending")
            self.assertIsNone(after["verdict"])
            self.assertEqual(after["attempt_count"], 0)
            self.assertIsNone(after["evidence_path"])
            # stale runtime key stripped, provenance stamped
            ap = json.loads(after["payload_json"])
            self.assertNotIn("pid", ap)
            self.assertEqual(ap["requeue_reason"], "stranded_infra_deep_phase")
            # report root archived aside
            self.assertFalse((wi_reports / "wi1").exists())
            archive = Path(result["archived_report_roots"]["wi1"])
            self.assertTrue(archive.exists())
            # journal (== snapshot) written by _apply, marked committed, full state recorded
            self.assertTrue(snap.exists())
            journal = json.loads(snap.read_text(encoding="utf-8"))["journal"]
            self.assertEqual(journal["state"], "committed")
            self.assertEqual(journal["entries"]["wi1"]["archive_dst"], str(archive))
            self.assertEqual(journal["entries"]["wi1"]["post_apply"]["status"], "pending")

            # revert from the journal
            rev = rsi._revert(cfg, snap)
            self.assertEqual(rev["restored"], 1)
            self.assertEqual(rev["exit_code"], 0)
            self.assertEqual(rev["skipped_drifted"], [])
            back = self._row(db, "wi1")
            self.assertEqual(back["status"], "done")
            self.assertEqual(back["verdict"], "INFRA_FAIL")
            self.assertEqual(back["attempt_count"], 2)
            self.assertEqual(back["evidence_path"], before["evidence_path"])
            self.assertEqual(back["payload_json"], prior_payload)  # byte-faithful payload
            self.assertEqual(back["updated_at"], ORIGINAL_UPDATED_AT)  # exact original stamp
            # report root un-archived
            self.assertTrue((wi_reports / "wi1").exists())
            self.assertFalse(archive.exists())

    def test_apply_aborts_when_sibling_pending_after_plan(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports = self._stranded(root)
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
            # a sibling becomes pending between plan and apply
            self._insert(db, id="pend1", phase="Q04", ea_id="QM5_500", symbol="EURUSD.DWX",
                         setfile_path=self._row(db, "wi1")["setfile_path"],
                         status="pending", verdict=None)
            snap = root / "snap.json"
            with self.assertRaises(RuntimeError):
                rsi._apply(cfg, plan, snap)
            # unchanged + report root NOT archived (fail closed in revalidation, before any write)
            self.assertEqual(self._row(db, "wi1")["status"], "done")
            self.assertTrue((wi_reports / "wi1").exists())

    def test_apply_without_snapshot_out_refuses(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, _wi = self._stranded(root)
            rc = rsi.main(["--apply", "--db", str(db), "--eas-root", str(root / "EAs"),
                           "--registry", str(root / "registry.csv"),
                           "--wi-reports-root", str(root / "work_items"), "--phases", "Q04"])
            self.assertEqual(rc, 2)
            self.assertEqual(self._row(db, "wi1")["status"], "done")  # untouched


class CrashSafetyTests(_Base):
    """Apply/revert ordering: journal-before-move, mid-move compensation, drift + un-archive guards."""

    def _stranded_n(self, root, ea_nums):
        """Build one stranded Q04 INFRA row (with a live report root) per ea number."""
        db = self._db(root)
        wi_reports = root / "work_items"
        reg_rows = []
        wids = []
        for num in ea_nums:
            slug = f"slug{num}"
            _d, sf = self._make_ea(root, num, slug)
            reg_rows.append((num, "active", slug))
            wid = f"wi{num}"
            (wi_reports / wid).mkdir(parents=True)
            (wi_reports / wid / "report.csv").write_text("evidence", encoding="utf-8")
            self._insert(db, id=wid, phase="Q04", ea_id=f"QM5_{num}", symbol="EURUSD.DWX",
                         setfile_path=str(sf), status="done", verdict="INFRA_FAIL",
                         attempt_count=2,
                         evidence_path=str(wi_reports / wid / "report.csv"),
                         payload={"final_failure": "summary_missing_retries_exhausted", "pid": 42})
            wids.append(wid)
        cfg = self._cfg(root, reg_rows, wi_reports=wi_reports)
        return db, cfg, wi_reports, wids

    def test_apply_midmove_failure_rolls_back_and_compensates(self):
        # Two rows; the SECOND archive move throws. DB must roll back and the FIRST (already
        # completed) move must be compensated (moved back).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports, wids = self._stranded_n(root, [500, 600])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
            self.assertEqual(plan["canary_count"], 2)
            snap = root / "snap.json"

            real = rsi._do_rename
            state = {"n": 0}

            def failing(src, dst):
                state["n"] += 1
                if state["n"] == 2:
                    raise OSError("injected move failure on 2nd root")
                real(src, dst)

            rsi._do_rename = failing
            try:
                with self.assertRaises(RuntimeError):
                    rsi._apply(cfg, plan, snap)
            finally:
                rsi._do_rename = real

            # DB unchanged: both rows still terminal INFRA_FAIL.
            for wid in wids:
                r = self._row(db, wid)
                self.assertEqual(r["status"], "done")
                self.assertEqual(r["verdict"], "INFRA_FAIL")
                self.assertEqual(r["attempt_count"], 2)
            # Completed move compensated + untouched root intact; no archives left behind.
            self.assertTrue((wi_reports / "wi500").exists())
            self.assertTrue((wi_reports / "wi600").exists())
            self.assertEqual(list(wi_reports.glob("*.requeued_*")), [])
            # Journal remains 'planned' (recoverable) with the full archive map.
            journal = json.loads(snap.read_text(encoding="utf-8"))["journal"]
            self.assertEqual(journal["state"], "planned")
            self.assertEqual(set(journal["entries"]), {"wi500", "wi600"})

    def test_journal_has_full_archive_map_before_any_move(self):
        # Fail on the FIRST move: the journal must already exist on disk with both rows' complete
        # src->dst archive map and pre/post-apply states (written BEFORE any filesystem mutation).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports, wids = self._stranded_n(root, [500, 600])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
            snap = root / "snap.json"

            real = rsi._do_rename

            def always_fail(src, dst):
                raise OSError("injected move failure on 1st root")

            rsi._do_rename = always_fail
            try:
                with self.assertRaises(RuntimeError):
                    rsi._apply(cfg, plan, snap)
            finally:
                rsi._do_rename = real

            self.assertTrue(snap.exists())
            journal = json.loads(snap.read_text(encoding="utf-8"))["journal"]
            self.assertEqual(journal["state"], "planned")
            self.assertEqual(set(journal["entries"]), {"wi500", "wi600"})
            for wid in wids:
                e = journal["entries"][wid]
                self.assertEqual(e["archive_src"], str(wi_reports / wid))
                self.assertTrue(e["archive_dst"].startswith(str(wi_reports / wid) + ".requeued_"))
                self.assertEqual(e["pre_apply"]["status"], "done")
                self.assertEqual(e["pre_apply"]["verdict"], "INFRA_FAIL")
                self.assertEqual(e["post_apply"]["status"], "pending")
                self.assertIsNone(e["post_apply"]["verdict"])
            # No move happened, DB untouched, no archives on disk.
            self.assertTrue((wi_reports / "wi500").exists())
            self.assertTrue((wi_reports / "wi600").exists())
            self.assertEqual(list(wi_reports.glob("*.requeued_*")), [])
            self.assertEqual(self._row(db, "wi500")["status"], "done")

    def test_failed_rename_aborts_whole_apply_nonzero(self):
        # Via main(): a rename failure must yield a non-zero exit code and commit nothing.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports, _wids = self._stranded_n(root, [500])
            snap = root / "snap.json"

            real_rename = rsi._do_rename
            real_skip = farmctl._q02_symbol_skip_reason
            real_prio = rsi._default_priority_fn

            def always_fail(src, dst):
                raise OSError("injected")

            rsi._do_rename = always_fail
            farmctl._q02_symbol_skip_reason = lambda s, allow_logical_basket=False: None
            rsi._default_priority_fn = lambda: (lambda _ea: 0.0)
            try:
                rc = rsi.main([
                    "--apply", "--snapshot-out", str(snap),
                    "--db", str(db), "--eas-root", str(root / "EAs"),
                    "--registry", str(root / "registry.csv"),
                    "--wi-reports-root", str(wi_reports), "--phases", "Q04",
                ])
            finally:
                rsi._do_rename = real_rename
                farmctl._q02_symbol_skip_reason = real_skip
                rsi._default_priority_fn = real_prio

            self.assertNotEqual(rc, 0)
            # nothing committed, report root intact, no archive
            self.assertEqual(self._row(db, "wi500")["status"], "done")
            self.assertTrue((wi_reports / "wi500").exists())
            self.assertEqual(list(wi_reports.glob("*.requeued_*")), [])

    def test_revert_refuses_drifted_row(self):
        # A worker claims the row after apply -> revert must refuse it, revert nothing for it,
        # leave its DB row + archived root untouched, and return non-zero.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports, _wids = self._stranded_n(root, [500])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
            snap = root / "snap.json"
            result = rsi._apply(cfg, plan, snap)
            archive = Path(result["archived_report_roots"]["wi500"])
            self.assertTrue(archive.exists())

            # a worker claims the requeued row
            conn = sqlite3.connect(db)
            conn.execute("UPDATE work_items SET status='active', claimed_by='worker-1' WHERE id=?",
                         ("wi500",))
            conn.commit()
            conn.close()

            rev = rsi._revert(cfg, snap)
            self.assertEqual(rev["exit_code"], 1)
            self.assertEqual(rev["restored"], 0)
            self.assertEqual(len(rev["skipped_drifted"]), 1)
            self.assertEqual(rev["skipped_drifted"][0]["work_item_id"], "wi500")
            # drifted row + its archived root are left exactly as the worker found them
            r = self._row(db, "wi500")
            self.assertEqual(r["status"], "active")
            self.assertEqual(r["claimed_by"], "worker-1")
            self.assertTrue(archive.exists())
            self.assertFalse((wi_reports / "wi500").exists())

    def test_revert_unarchive_failure_aborts_before_db_restore(self):
        # If un-archiving the report root fails, revert must abort BEFORE touching the DB: the row
        # stays in its post-apply (pending) state and the archive stays put.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports, _wids = self._stranded_n(root, [500])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
            snap = root / "snap.json"
            result = rsi._apply(cfg, plan, snap)
            archive = Path(result["archived_report_roots"]["wi500"])

            real = rsi._do_rename

            def always_fail(src, dst):
                raise OSError("injected un-archive failure")

            rsi._do_rename = always_fail
            try:
                rev = rsi._revert(cfg, snap)
            finally:
                rsi._do_rename = real

            self.assertEqual(rev["exit_code"], 1)
            self.assertTrue(rev["unarchive_errors"])
            self.assertEqual(rev["restored"], 0)
            # DB NOT touched: row still in post-apply pending state; archive still archived.
            r = self._row(db, "wi500")
            self.assertEqual(r["status"], "pending")
            self.assertIsNone(r["verdict"])
            self.assertTrue(archive.exists())
            self.assertFalse((wi_reports / "wi500").exists())

    def test_partial_revert_then_second_revert_completes(self):
        # Batch-3 counterexample: revert #1 restores wi500 but refuses drifted wi600 -> the
        # journal must stay actionable ('partially_reverted', NOT 'reverted'), and once wi600
        # is back in its exact journalled post-apply state a second --revert must complete it
        # and only then mark the journal 'reverted'. The old unconditional marking made the
        # rerun a silent exit-0 no-op with wi600 left unreverted and its root archived.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, cfg, wi_reports, _wids = self._stranded_n(root, [500, 600])
            plan = rsi._plan(cfg, phases=("Q04",), include_q02_exhausted=False, limit=50,
                             symbol_skip_fn=NO_SKIP, priority_fn=FLAT_PRIO)
            snap = root / "snap.json"
            result = rsi._apply(cfg, plan, snap)
            archive600 = Path(result["archived_report_roots"]["wi600"])

            # a worker claims wi600 -> revert #1 restores wi500, refuses wi600
            conn = sqlite3.connect(db)
            conn.execute("UPDATE work_items SET status='active', claimed_by='worker-1' WHERE id=?",
                         ("wi600",))
            conn.commit()
            conn.close()
            rev1 = rsi._revert(cfg, snap)
            self.assertEqual(rev1["exit_code"], 1)
            self.assertEqual(rev1["restored"], 1)
            self.assertEqual([s["work_item_id"] for s in rev1["skipped_drifted"]], ["wi600"])
            journal = json.loads(snap.read_text(encoding="utf-8"))["journal"]
            self.assertEqual(journal["state"], "partially_reverted")

            # the worker releases wi600 back into its exact journalled post-apply state
            pa = journal["entries"]["wi600"]["post_apply"]
            conn = sqlite3.connect(db)
            conn.execute(
                "UPDATE work_items SET status=?, verdict=?, attempt_count=?, evidence_path=?, "
                "claimed_by=?, payload_json=?, updated_at=? WHERE id=?",
                (pa["status"], pa["verdict"], pa["attempt_count"], pa["evidence_path"],
                 pa["claimed_by"], pa["payload_json"], pa["updated_at"], "wi600"))
            conn.commit()
            conn.close()

            # revert #2 completes: wi600 restored, archive gone, journal finally 'reverted'
            rev2 = rsi._revert(cfg, snap)
            self.assertEqual(rev2["exit_code"], 0)
            self.assertEqual(rev2["restored"], 1)
            self.assertEqual(rev2["skipped_drifted"], [])
            self.assertFalse(archive600.exists())
            self.assertTrue((wi_reports / "wi600").exists())
            pre = journal["entries"]["wi600"]["pre_apply"]
            r = self._row(db, "wi600")
            self.assertEqual(r["status"], pre["status"])
            self.assertEqual(r["verdict"], pre["verdict"])
            journal2 = json.loads(snap.read_text(encoding="utf-8"))["journal"]
            self.assertEqual(journal2["state"], "reverted")


if __name__ == "__main__":
    unittest.main()
