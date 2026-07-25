"""Safety tests for the staged Q09 stranded-sleeve requeue tool.

Gate-repair WP-6 defect-2 (round 2, 2026-07-25 Codex re-review): the mutation tool must
never apply without a durable snapshot, must revalidate provenance transaction-locally
(not just status/verdict), and revert must restore the EXACT prior state including the
original updated_at.
"""

import datetime as dt
import hashlib
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio import requeue_q09_stranded_sleeves as requeue  # noqa: E402


ORIGINAL_UPDATED_AT = "2024-01-01T00:00:00+00:00"


class RequeueQ09StrandedSleevesTests(unittest.TestCase):
    def _sleeve_stream_dir(self, common_dir: Path) -> Path:
        d = common_dir / "QM" / "q08_trades"
        d.mkdir(parents=True, exist_ok=True)
        return d

    def _write_volume_stream(self, path: Path, n: int) -> None:
        start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
        with path.open("w", encoding="utf-8") as fh:
            for i in range(n):
                fh.write(json.dumps({
                    "event": "TRADE_CLOSED",
                    "symbol": "EURUSD.DWX",
                    "time": int((start + dt.timedelta(days=i)).timestamp()),
                    "net": 10.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                }) + "\n")

    def _build(self, root: Path, *, authoritative: int = 25, floor: int = 20,
               recorded_n: int = 25, dur_rows: int = 25):
        """Create a farm DB with one Q09 stranded sleeve + its Q08 evidence and stream."""
        common_dir = root / "sleeve_streams"
        stream_dir = self._sleeve_stream_dir(common_dir)
        self._write_volume_stream(stream_dir / f"500_EURUSD_DWX.jsonl", dur_rows)

        aggregate_path = root / "q08_aggregate.json"
        aggregate_path.write_text(
            json.dumps({"n_trades": authoritative, "portfolio_stream": {"n": recorded_n}}),
            encoding="utf-8",
        )

        db = root / "farm_state.sqlite"
        conn = sqlite3.connect(db)
        try:
            conn.execute(
                """
                CREATE TABLE work_items (
                    id TEXT PRIMARY KEY, ea_id TEXT, symbol TEXT, phase TEXT,
                    status TEXT, verdict TEXT, evidence_path TEXT, setfile_path TEXT,
                    payload_json TEXT, created_at TEXT, updated_at TEXT
                )
                """
            )
            conn.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (
                    "wi-500", "QM5_500", "EURUSD.DWX", "Q09_PORTFOLIO",
                    "done", "NEED_MORE_DATA", None, None,
                    json.dumps({
                        "q08_evidence_path": str(aggregate_path),
                        "q08_trade_count": authoritative,
                        "min_portfolio_trades": floor,
                    }),
                    ORIGINAL_UPDATED_AT, ORIGINAL_UPDATED_AT,
                ),
            )
            conn.commit()
        finally:
            conn.close()
        return db, common_dir, aggregate_path

    def _row_state(self, db: Path, wid: str = "wi-500"):
        conn = sqlite3.connect(db)
        try:
            cur = conn.execute(
                "SELECT status, verdict, updated_at FROM work_items WHERE id=?", (wid,)
            ).fetchone()
        finally:
            conn.close()
        return cur

    def test_plan_classifies_provenance_validated_row_as_requeue(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, common_dir, _ = self._build(root)
            plan = requeue._plan(db, common_dir, requeue.DEFAULT_MIN_PORTFOLIO_TRADES)
        self.assertEqual(plan["requeue_count"], 1)
        self.assertEqual(plan["requeue"][0]["reason"], "provenance_validated")
        self.assertEqual(plan["prior_state"]["wi-500"]["updated_at"], ORIGINAL_UPDATED_AT)

    def test_apply_without_snapshot_out_refuses_and_writes_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, _, _ = self._build(root)
            rc = requeue.main(["--apply", "--db", str(db),
                               "--common-dir", str(root / "sleeve_streams")])
            self.assertEqual(rc, 2)
            status, verdict, updated_at = self._row_state(db)
            self.assertEqual((status, verdict), ("done", "NEED_MORE_DATA"))
            self.assertEqual(updated_at, ORIGINAL_UPDATED_AT)  # untouched

    def test_apply_aborts_when_evidence_purged_after_plan(self) -> None:
        # Transaction-local revalidation: an aggregate deleted between plan and apply must
        # abort the mutation (a status/verdict-only check would still have requeued it).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, common_dir, aggregate_path = self._build(root)
            plan = requeue._plan(db, common_dir, requeue.DEFAULT_MIN_PORTFOLIO_TRADES)
            self.assertEqual(plan["requeue_count"], 1)
            aggregate_path.unlink()  # purge the qualifying Q08 evidence after planning
            with self.assertRaises(RuntimeError):
                requeue._apply(db, plan)
            status, verdict, updated_at = self._row_state(db)
            self.assertEqual((status, verdict), ("done", "NEED_MORE_DATA"))
            self.assertEqual(updated_at, ORIGINAL_UPDATED_AT)  # rolled back, unchanged

    def test_apply_aborts_when_durable_stream_diverges_after_plan(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, common_dir, _ = self._build(root)
            plan = requeue._plan(db, common_dir, requeue.DEFAULT_MIN_PORTFOLIO_TRADES)
            self.assertEqual(plan["requeue_count"], 1)
            # Truncate the durable stream so its volume-bearing count no longer matches.
            self._write_volume_stream(
                common_dir / "QM" / "q08_trades" / "500_EURUSD_DWX.jsonl", 3)
            with self.assertRaises(RuntimeError):
                requeue._apply(db, plan)
            self.assertEqual(self._row_state(db)[:2], ("done", "NEED_MORE_DATA"))

    def test_apply_then_revert_restores_exact_prior_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, common_dir, _ = self._build(root)
            plan = requeue._plan(db, common_dir, requeue.DEFAULT_MIN_PORTFOLIO_TRADES)
            snapshot = root / "snapshot.json"
            snapshot.write_text(json.dumps(plan, sort_keys=True), encoding="utf-8")

            changed = requeue._apply(db, plan)
            self.assertEqual(changed, 1)
            status, verdict, updated_at = self._row_state(db)
            self.assertEqual((status, verdict), ("pending", None))
            self.assertNotEqual(updated_at, ORIGINAL_UPDATED_AT)  # fresh stamp on apply

            restored = requeue._revert(db, snapshot)
            self.assertEqual(restored, 1)
            status, verdict, updated_at = self._row_state(db)
            self.assertEqual((status, verdict), ("done", "NEED_MORE_DATA"))
            self.assertEqual(updated_at, ORIGINAL_UPDATED_AT)  # EXACT original restored

    def test_v2_durable_stream_sha_mismatch_is_refused(self) -> None:
        # WP-6 defect-2 (round 3, 2026-07-25 Codex re-check): when the aggregate is v2 (it
        # carries content_sha256), count parity is not enough — the durable stream's bytes
        # must hash to the bound identity. A same-count FOREIGN stream is REFUSED, never
        # requeued into a real verdict.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, common_dir, aggregate_path = self._build(root)
            # Rewrite the aggregate as v2 with a content_sha256 that the (correct-count)
            # durable stream cannot possibly hash to.
            aggregate_path.write_text(
                json.dumps({
                    "n_trades": 25,
                    "portfolio_stream": {
                        "n": 25,
                        "content_sha256": hashlib.sha256(b"foreign authoritative bytes").hexdigest(),
                    },
                }),
                encoding="utf-8",
            )
            plan = requeue._plan(db, common_dir, requeue.DEFAULT_MIN_PORTFOLIO_TRADES)
        self.assertEqual(plan["requeue_count"], 0)
        self.assertEqual(plan["refuse"][0]["reason"], "durable_stream_sha256_mismatch")
        self.assertEqual(plan["refuse"][0]["lineage_basis"], "sha256")

    def test_v2_matching_durable_stream_sha_is_requeued(self) -> None:
        # v2 happy path: when the durable stream's bytes DO hash to the aggregate's bound
        # content_sha256, the row is provenance-validated and requeued, on lineage_basis=sha256.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, common_dir, aggregate_path = self._build(root)
            stream_path = common_dir / "QM" / "q08_trades" / "500_EURUSD_DWX.jsonl"
            good_sha = hashlib.sha256(stream_path.read_bytes()).hexdigest()
            aggregate_path.write_text(
                json.dumps({
                    "n_trades": 25,
                    "portfolio_stream": {"n": 25, "content_sha256": good_sha},
                }),
                encoding="utf-8",
            )
            plan = requeue._plan(db, common_dir, requeue.DEFAULT_MIN_PORTFOLIO_TRADES)
        self.assertEqual(plan["requeue_count"], 1)
        self.assertEqual(plan["requeue"][0]["reason"], "provenance_validated")
        self.assertEqual(plan["requeue"][0]["lineage_basis"], "sha256")

    def test_below_floor_row_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db, common_dir, _ = self._build(root, authoritative=3, floor=20,
                                            recorded_n=3, dur_rows=3)
            plan = requeue._plan(db, common_dir, requeue.DEFAULT_MIN_PORTFOLIO_TRADES)
        self.assertEqual(plan["requeue_count"], 0)
        self.assertEqual(plan["refuse"][0]["reason"], "authoritative_below_floor")


if __name__ == "__main__":
    unittest.main()
