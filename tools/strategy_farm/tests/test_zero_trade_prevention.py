from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from tools.strategy_farm import farmctl


class ZeroTradePreventionTests(unittest.TestCase):
    def test_review_invalidation_excludes_same_generation_evidence(self) -> None:
        build_payload = {"build_generation": 0}
        active = {"build_generation": 0}
        invalidated = {
            "build_generation": 0,
            "review_invalidated_at": "2026-08-31T16:30:00+00:00",
            "review_invalidated_reason": "artifact_path_resolution_failure",
        }
        legacy_generation_zero_superseded = {
            "build_generation": 0,
            "superseded_by_build_generation": 0,
        }

        self.assertTrue(
            farmctl._review_matches_build_generation(active, build_payload)
        )
        self.assertFalse(
            farmctl._review_matches_build_generation(invalidated, build_payload)
        )
        self.assertFalse(
            farmctl._review_matches_build_generation(
                legacy_generation_zero_superseded,
                build_payload,
            )
        )

    def test_codex_pre_review_binds_attempt_archived_build_result(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            archived = (
                root
                / "artifacts"
                / "builds"
                / "build-task.attempt_0.attempt_1.json"
            )
            archived.parent.mkdir(parents=True, exist_ok=True)
            archived.write_text('{"task_id":"build-task"}\n', encoding="utf-8")
            now = farmctl.utc_now()
            payload = {
                "ea_id": "QM5_999000",
                "card_path": str(root / "card.md"),
                "build_result_path": str(archived),
                "codex_result": {
                    "mq5_path": str(root / "ea.mq5"),
                    "ex5_path": str(root / "ea.ex5"),
                },
            }
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('build-task', 'build_ea', 'done', NULL, 'QM5_999000', ?, ?, ?)
                    """,
                    (json.dumps(payload), now, now),
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM tasks WHERE id='build-task'"
                ).fetchone()

            fake_lease = {"lease_id": "lease-1"}
            with mock.patch.object(
                farmctl,
                "_spawn_owned_codex",
                return_value=(SimpleNamespace(pid=1234), fake_lease),
            ):
                spawned = farmctl._spawn_codex_for_pre_review(root, row)

            self.assertTrue(spawned["spawned"])
            with farmctl.connect(root) as conn:
                review = conn.execute(
                    "SELECT payload_json FROM tasks WHERE id=?",
                    (spawned["codex_review_task_id"],),
                ).fetchone()
            review_payload = json.loads(review["payload_json"])
            self.assertEqual(
                Path(review_payload["build_result_path"]),
                archived,
            )
            prompt = (
                root
                / "queue"
                / f"codex_review_{spawned['codex_review_task_id']}.md"
            ).read_text(encoding="utf-8")
            self.assertIn(str(archived), prompt)

    def test_pre_review_allows_only_durable_saturation_block_reason(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            ea_dir = root / "ea"
            ea_dir.mkdir()
            mq5 = ea_dir / "QM5_999000_demo.mq5"
            ex5 = ea_dir / "QM5_999000_demo.ex5"
            mq5.write_text("// source\n", encoding="utf-8")
            ex5.write_bytes(b"compiled")
            farmctl.init_db(root)
            now = farmctl.utc_now()

            result_path = root / "artifacts" / "builds" / "build-task.json"
            result_path.parent.mkdir(parents=True, exist_ok=True)
            base_result = {
                "task_id": "build-task",
                "ea_id": "QM5_999000",
                "mq5_path": str(mq5),
                "ex5_path": str(ex5),
                "compile_succeeded": True,
                "build_check_passed": True,
                "smoke_result": "deferred_p2_smoke",
            }
            payload = {
                "ea_id": "QM5_999000",
                "build_result_path": str(result_path),
            }
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('build-task', 'build_ea', 'done', NULL, 'QM5_999000', ?, ?, ?)
                    """,
                    (json.dumps(payload), now, now),
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM tasks WHERE id='build-task'"
                ).fetchone()

            saturated = dict(base_result)
            saturated["blocked_reason"] = (
                "resolve_backtest_target.py status=no_capacity; 10/10 slots occupied"
            )
            result_path.write_text(json.dumps(saturated), encoding="utf-8")
            self.assertEqual(farmctl._pre_review_ready(root, row), (True, ""))

            generic = dict(base_result)
            generic["blocked_reason"] = "headless smoke unavailable"
            result_path.write_text(json.dumps(generic), encoding="utf-8")
            self.assertEqual(
                farmctl._pre_review_ready(root, row),
                (False, "build_result_blocked"),
            )

    def test_reviewable_pre_review_block_is_restored_without_build_retry(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            ea_dir = root / "ea"
            ea_dir.mkdir()
            mq5 = ea_dir / "QM5_999000_demo.mq5"
            ex5 = ea_dir / "QM5_999000_demo.ex5"
            mq5.write_text("// source\n", encoding="utf-8")
            ex5.write_bytes(b"compiled")
            farmctl.init_db(root)
            result_path = root / "artifacts" / "builds" / "build-task.json"
            result_path.parent.mkdir(parents=True, exist_ok=True)
            result_path.write_text(
                json.dumps({
                    "task_id": "build-task",
                    "ea_id": "QM5_999000",
                    "mq5_path": str(mq5),
                    "ex5_path": str(ex5),
                    "compile_succeeded": True,
                    "build_check_passed": True,
                    "smoke_result": "deferred_p2_smoke",
                    "blocked_reason": "status=no_capacity; 10/10 slots occupied",
                }),
                encoding="utf-8",
            )
            now = farmctl.utc_now()
            payload = {
                "ea_id": "QM5_999000",
                "build_result_path": str(result_path),
                "blocked_reason": "pre_review_not_reviewable:build_result_blocked",
                "pre_review_not_reviewable_reason": "build_result_blocked",
                "attempt_count": 3,
            }
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    INSERT INTO tasks
                      (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                    VALUES
                      ('build-task', 'build_ea', 'blocked', NULL, 'QM5_999000', ?, ?, ?)
                    """,
                    (json.dumps(payload), now, now),
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM tasks WHERE id='build-task'"
                ).fetchone()

            restored = farmctl._restore_reviewable_pre_review_block(root, row)
            self.assertTrue(restored["restored"])
            with farmctl.connect(root) as conn:
                stored = conn.execute(
                    "SELECT status,payload_json FROM tasks WHERE id='build-task'"
                ).fetchone()
            stored_payload = json.loads(stored["payload_json"])
            self.assertEqual(stored["status"], "done")
            self.assertNotIn("blocked_reason", stored_payload)
            self.assertNotIn("pre_review_not_reviewable_reason", stored_payload)
            self.assertEqual(stored_payload["attempt_count"], 3)
            self.assertEqual(
                stored_payload["pre_review_block_reconciled_from"],
                "pre_review_not_reviewable:build_result_blocked",
            )

    def test_q01_smoke_saturation_waiver_requires_durable_capacity_evidence(self) -> None:
        missing = farmctl._q01_smoke_admission(None)
        self.assertFalse(missing["admitted"])
        self.assertEqual(missing["reason"], "q01_smoke_missing_without_saturation_waiver")

        unsupported = farmctl._q01_smoke_admission({
            "build_task_id": "build-1",
            "smoke_result": "deferred_p2_smoke",
            "smoke_skipped_reason": "headless scheduled execution",
        })
        self.assertFalse(unsupported["admitted"])
        self.assertEqual(unsupported["reason"], "q01_smoke_waiver_missing_capacity_evidence")

        vague_process_text = farmctl._q01_smoke_admission({
            "build_task_id": "build-vague",
            "smoke_result": "deferred_p2_smoke",
            "blocked_reason": "metatester64 state was not checked",
        })
        self.assertFalse(vague_process_text["admitted"])

        saturated = farmctl._q01_smoke_admission({
            "build_task_id": "build-2",
            "smoke_result": "deferred_p2_smoke",
            "blocked_reason": "resolve_backtest_target.py status=no_capacity; 10/10 slots occupied",
        })
        self.assertTrue(saturated["admitted"])
        self.assertTrue(saturated["waiver"])
        self.assertEqual(saturated["reason"], "q01_smoke_saturation_waiver")

        measured_processes = farmctl._q01_smoke_admission({
            "build_task_id": "build-quantified",
            "smoke_result": "deferred_p2_smoke",
            "blocked_reason": "10 metatester64 processes running",
        })
        self.assertTrue(measured_processes["admitted"])

        passed = farmctl._q01_smoke_admission({
            "build_task_id": "build-3", "smoke_result": "passed",
        })
        self.assertTrue(passed["admitted"])
        self.assertFalse(passed["waiver"])

    def test_q03_fanout_uses_logical_basket_setfile(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            ea_dir = repo_root / "framework" / "EAs" / "QM5_999003_demo-basket"
            sets_dir = ea_dir / "sets"
            sets_dir.mkdir(parents=True)
            logical_symbol = "QM5_999003_EURUSD_GBPUSD_COINTEGRATION_D1"
            manifest = {
                "logical_symbol": logical_symbol,
                "host_symbol": "EURUSD.DWX",
                "host_timeframe": "D1",
                "tester_currency": "USD",
                "tester_deposit": 100000,
                "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
            }
            (ea_dir / "basket_manifest.json").write_text(
                json.dumps(manifest), encoding="utf-8"
            )
            setfile = sets_dir / f"QM5_999003_demo-basket_{logical_symbol}_D1_backtest.set"
            setfile.write_text("; basket setfile\n", encoding="utf-8")
            farmctl.init_db(root)

            with farmctl.connect(root) as conn:
                with mock.patch.object(farmctl, "REPO_ROOT", repo_root):
                    created, skipped = farmctl._create_backtest_work_items(
                        conn,
                        parent_task_id="q03-parent",
                        root=root,
                        ea_id="QM5_999003",
                        phase="Q03",
                        surviving_symbols=[logical_symbol],
                    )

            self.assertEqual(skipped, [])
            self.assertEqual(len(created), 1)
            self.assertEqual(created[0]["symbol"], logical_symbol)
            self.assertEqual(created[0]["setfile_path"], str(setfile.resolve()))
            self.assertEqual(created[0]["payload"]["portfolio_scope"], "basket")

    def test_p2_fanout_respects_card_declared_universe(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            approved = root / "artifacts" / "cards_approved"
            approved.mkdir(parents=True)
            (approved / "QM5_999001_universe-test.md").write_text(
                """---
ea_id: QM5_999001
slug: universe-test
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
Universe: EURUSD.DWX, XAUUSD.DWX
Filters: news blackout only.
""",
                encoding="utf-8",
            )
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                with mock.patch.object(
                    farmctl,
                    "_ensure_p2_target_setfiles",
                    return_value=[
                        ("EURUSD.DWX", "eur.set"),
                        ("XAUUSD.DWX", "xau.set"),
                    ],
                ):
                    created, skipped = farmctl._create_backtest_work_items(
                        conn,
                        parent_task_id="parent",
                        root=root,
                        ea_id="QM5_999001",
                        phase="P2",
                        surviving_symbols=None,
                    )

            self.assertEqual([row["symbol"] for row in created], ["EURUSD.DWX", "XAUUSD.DWX"])
            self.assertEqual(skipped, [])

    def test_p2_enqueue_blocks_latest_zero_trade_build_smoke(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                now = farmctl.utc_now()
                conn.execute(
                    """
                    INSERT INTO tasks(id, kind, status, card_id, payload_json, created_at, updated_at)
                    VALUES ('build-zero', 'build_ea', 'done', 'QM5_999002', ?, ?, ?)
                    """,
                    (
                        json.dumps({"codex_result": {"smoke_result": "zero_trades"}}),
                        now,
                        now,
                    ),
                )
                conn.execute(
                    """
                    INSERT INTO tasks(id, kind, status, card_id, payload_json, created_at, updated_at)
                    VALUES ('review-pass', 'ea_review', 'done', 'QM5_999002', ?, ?, ?)
                    """,
                    (
                        json.dumps({"ea_id": "QM5_999002", "verdict": {"verdict": "APPROVE_FOR_BACKTEST"}}),
                        now,
                        now,
                    ),
                )
                conn.commit()

            with mock.patch.dict(os.environ, {"QM_AGENT_ID": "controller"}):
                result = farmctl.enqueue_backtest(root, "review-pass", "P2")

            self.assertFalse(result["enqueued"])
            self.assertEqual(result["reason"], "q01_trade_generation_zero_trades")
            self.assertEqual(result["build_task_id"], "build-zero")


if __name__ == "__main__":
    unittest.main()
