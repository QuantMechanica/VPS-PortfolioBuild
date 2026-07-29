import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_migration as migration  # noqa: E402
import q09_news_schema as schema  # noqa: E402


def create_legacy_database(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY,
            phase TEXT NOT NULL,
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            status TEXT NOT NULL,
            verdict TEXT,
            evidence_path TEXT,
            created_at TEXT NOT NULL
        );
        CREATE TABLE portfolio_candidates (
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            q11_work_item_id TEXT NOT NULL,
            state TEXT NOT NULL,
            evidence_path TEXT,
            first_seen_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY(ea_id,symbol,q11_work_item_id)
        );
        """
    )
    rows = [
        ("q08", "Q08", "QM5_A", "EURUSD.DWX", "done", "PASS", "q08.json", "2026-01-01Z"),
        ("q09p", "Q09_PORTFOLIO", "QM5_A", "EURUSD.DWX", "done", "PASS_PORTFOLIO", "q09p.json", "2026-01-02Z"),
        ("q10", "Q10", "QM5_A", "EURUSD.DWX", "done", "PASS", "q10.json", "2026-01-03Z"),
        ("stale-source", "Q10", "QM5_B", "GBPUSD.DWX", "done", "PASS", "stale.json", "2026-01-03Z"),
        ("duplicate-source", "Q10", "QM5_C", "USDJPY.DWX", "done", "PASS", "duplicate.json", "2026-01-03Z"),
        ("ignored-source", "Q10", "QM5_D", "XAUUSD.DWX", "done", "FAIL", "ignored.json", "2026-01-03Z"),
    ]
    conn.executemany("INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)", rows)
    candidates = [
        ("QM5_A", "EURUSD.DWX", "q10", "Q12_REVIEW_READY", "q10.json", "x", "x"),
        ("QM5_B", "GBPUSD.DWX", "stale-source", "EVIDENCE_STALE", "stale.json", "x", "x"),
        ("QM5_C", "USDJPY.DWX", "duplicate-source", "DUPLICATE_SUPERSEDED", "duplicate.json", "x", "x"),
        ("QM5_D", "XAUUSD.DWX", "ignored-source", "OWNER_REJECTED", "ignored.json", "x", "x"),
    ]
    conn.executemany("INSERT INTO portfolio_candidates VALUES(?,?,?,?,?,?,?)", candidates)
    conn.commit()
    conn.close()


def legacy_rows(path: Path) -> tuple[list[tuple], list[tuple]]:
    conn = sqlite3.connect(path)
    try:
        return (
            conn.execute("SELECT id,status,verdict,evidence_path FROM work_items ORDER BY id").fetchall(),
            conn.execute(
                "SELECT ea_id,symbol,q11_work_item_id,state,evidence_path FROM portfolio_candidates ORDER BY 1,2,3"
            ).fetchall(),
        )
    finally:
        conn.close()


class Q09NewsMigrationV2Tests(unittest.TestCase):
    def test_plan_whatif_apply_idempotency_and_guarded_revert(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            database = root / "farm.sqlite"
            plan_path = root / "plan.json"
            snapshot = root / "farm.pre-q09.sqlite"
            factory_off = root / "FACTORY_OFF.flag"
            factory_off.write_text('{"factory":"OFF"}\n', encoding="utf-8")
            create_legacy_database(database)
            original_rows = legacy_rows(database)

            def operational_guards() -> dict:
                return {
                    "factory_off_flag": factory_off,
                    "expected_database_sha256": migration.sha256_file(database),
                    "expected_database_state_sha256": migration.sqlite_state_sha256(database),
                    "expected_factory_off_sha256": migration.sha256_file(factory_off),
                }

            readonly = migration._connect(database, readonly=True)
            try:
                plan = migration.build_plan(readonly, source_database=str(database))
                what_if = migration.what_if(readonly, plan)
            finally:
                readonly.close()
            self.assertEqual(what_if["mode"], "WhatIf")
            self.assertTrue(what_if["protected_state_matches"])
            self.assertEqual(what_if["would_update_legacy_rows"], 0)
            self.assertEqual(plan["entry_count"], 3)
            self.assertEqual(plan["overlay_counts"], {
                "EXCLUDED_DUPLICATE": 1,
                "LEGACY_NEWS_REQUAL_REQUIRED": 1,
                "LEGACY_STALE_BLOCKED": 1,
            })
            check = sqlite3.connect(database)
            try:
                self.assertFalse(
                    check.execute(
                        "SELECT 1 FROM sqlite_master WHERE name='candidate_qualifications'"
                    ).fetchone()
                )
            finally:
                check.close()
            migration.write_plan(plan, plan_path)

            with self.assertRaises(migration.MigrationError):
                migration.apply_plan(
                    database,
                    plan,
                    plan_path=plan_path,
                    snapshot_path=snapshot,
                    confirm_plan_sha256="0" * 64,
                    exclusive_ack=migration.EXCLUSIVE_ACK,
                    **operational_guards(),
                )
            with self.assertRaises(migration.MigrationError):
                migration.apply_plan(
                    database,
                    plan,
                    plan_path=plan_path,
                    snapshot_path=snapshot,
                    confirm_plan_sha256=plan["plan_sha256"],
                    exclusive_ack="",
                    **operational_guards(),
                )
            bad_state_guards = operational_guards()
            bad_state_guards["expected_database_state_sha256"] = "0" * 64
            with self.assertRaisesRegex(migration.MigrationError, "logical database-state"):
                migration.apply_plan(
                    database,
                    plan,
                    plan_path=plan_path,
                    snapshot_path=snapshot,
                    confirm_plan_sha256=plan["plan_sha256"],
                    exclusive_ack=migration.EXCLUSIVE_ACK,
                    **bad_state_guards,
                )
            missing_flag_guards = operational_guards()
            flag_bytes = factory_off.read_bytes()
            factory_off.unlink()
            try:
                with self.assertRaisesRegex(migration.MigrationError, "FACTORY_OFF flag missing"):
                    migration.apply_plan(
                        database,
                        plan,
                        plan_path=plan_path,
                        snapshot_path=snapshot,
                        confirm_plan_sha256=plan["plan_sha256"],
                        exclusive_ack=migration.EXCLUSIVE_ACK,
                        **missing_flag_guards,
                    )
            finally:
                factory_off.write_bytes(flag_bytes)
            lock_path = root / "FACTORY_MUTATION.lock"
            with migration.FactoryMutationLock(lock_path, owner="test-busy-lock"):
                with self.assertRaisesRegex(migration.MigrationError, "mutation lock is busy"):
                    migration.apply_plan(
                        database,
                        plan,
                        plan_path=plan_path,
                        snapshot_path=snapshot,
                        confirm_plan_sha256=plan["plan_sha256"],
                        exclusive_ack=migration.EXCLUSIVE_ACK,
                        **operational_guards(),
                    )
            applied = migration.apply_plan(
                database,
                plan,
                plan_path=plan_path,
                snapshot_path=snapshot,
                confirm_plan_sha256=plan["plan_sha256"],
                exclusive_ack=migration.EXCLUSIVE_ACK,
                **operational_guards(),
            )
            self.assertEqual(applied["status"], "APPLIED")
            self.assertEqual(applied["inserted_count"], 3)
            self.assertTrue(snapshot.is_file())
            self.assertFalse((root / "FACTORY_MUTATION.lock").exists())
            self.assertEqual(applied["wal_checkpoint"]["busy"], 0)
            self.assertEqual(legacy_rows(database), original_rows)
            conn = sqlite3.connect(database)
            try:
                states = {
                    row[0] for row in conn.execute("SELECT state FROM candidate_qualifications").fetchall()
                }
                self.assertEqual(states, {
                    "LEGACY_NEWS_REQUAL_REQUIRED", "LEGACY_STALE_BLOCKED", "EXCLUDED_DUPLICATE"
                })
                self.assertEqual(conn.execute("SELECT count(*) FROM portfolio_candidates_eligible").fetchone()[0], 0)
            finally:
                conn.close()

            repeated = migration.apply_plan(
                database,
                plan,
                plan_path=plan_path,
                snapshot_path=snapshot,
                confirm_plan_sha256=plan["plan_sha256"],
                exclusive_ack=migration.EXCLUSIVE_ACK,
                **operational_guards(),
            )
            self.assertEqual(repeated["status"], "ALREADY_APPLIED")
            self.assertEqual(repeated["inserted_count"], 0)

            with self.assertRaises(migration.MigrationError):
                migration.revert(
                    database,
                    snapshot_path=snapshot,
                    plan_hash=plan["plan_sha256"],
                    confirm_revert_guard_sha256="0" * 64,
                    exclusive_ack=migration.EXCLUSIVE_ACK,
                    **operational_guards(),
                )
            reverted = migration.revert(
                database,
                snapshot_path=snapshot,
                plan_hash=plan["plan_sha256"],
                confirm_revert_guard_sha256=applied["revert_guard_sha256"],
                exclusive_ack=migration.EXCLUSIVE_ACK,
                **operational_guards(),
            )
            self.assertEqual(reverted["status"], "REVERTED_TO_SNAPSHOT")
            self.assertEqual(legacy_rows(database), original_rows)
            restored = sqlite3.connect(database)
            try:
                self.assertIsNone(
                    restored.execute(
                        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='candidate_qualifications'"
                    ).fetchone()
                )
            finally:
                restored.close()


if __name__ == "__main__":
    unittest.main()
