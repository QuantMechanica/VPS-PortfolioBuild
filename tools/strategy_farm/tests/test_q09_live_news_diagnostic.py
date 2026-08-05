import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import q09_live_news_backfill as backfill  # noqa: E402
import q09_news_calendar as calendar  # noqa: E402
import q09_news_contract as contract  # noqa: E402
import q09_news_runner as runner  # noqa: E402
import terminal_worker  # noqa: E402


class Q09LiveNewsDiagnosticTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.root = Path(self.temporary.name)
        self.farm = self.root / "farm"
        farmctl.init_db(self.farm)
        self.setfile = self.root / "baseline.set"
        self.setfile.write_text(
            "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_filter_news_enabled=0\n"
            "qm_filter_news_mode=0\nqm_news_temporal=0\nqm_news_compliance=0\n"
            "qm_news_stale_max_hours=336\n",
            encoding="utf-8",
        )
        self.ex5 = self.root / "live.ex5"
        self.ex5.write_bytes(b"exact-live-binary")
        self.includes = self.root / "include_assessment.json"
        self.includes.write_text('{"diagnostic":true}\n', encoding="utf-8")
        self.q07 = self.root / "q07.json"
        self.q07.write_text(
            json.dumps({
                "phase": "Q07", "ea_id": 9999, "symbol": "EURUSD.DWX", "verdict": "PASS"
            }) + "\n",
            encoding="utf-8",
        )
        source = self.root / "calendar.csv"
        source.write_text(
            "datetime,currency,event_name,impact\n2024-01-10 13:30:00,USD,CPI,high\n",
            encoding="utf-8",
        )
        receipt = self.root / "calendar_receipt.json"
        receipt.write_text(
            json.dumps({
                "approved_by": "OWNER",
                "approved_at": "2026-08-05T00:00:00Z",
                "reason": "diagnostic test",
            }),
            encoding="utf-8",
        )
        calendar_plan = calendar.build_bundle_plan(
            source_csv=source,
            receipt_path=receipt,
            coverage_from_utc="2019-01-01T00:00:00Z",
            coverage_to_utc="2026-08-09T00:00:00Z",
            publication_reason="INITIAL",
        )
        published = calendar.publish_bundle(calendar_plan, self.root / "calendar")
        self.calendar_manifest = Path(published["manifest_path"])
        self.work_item_id = "diagnostic-q09-1"
        self.anchor = self.root / "anchor.json"
        anchor = {
            "schema_version": runner.DIAGNOSTIC_ANCHOR_SCHEMA,
            "diagnostic_contract": runner.DIAGNOSTIC_CONTRACT,
            "diagnostic_non_admission": True,
            "anchor_id": "diagnostic-anchor-1",
            "work_item_id": self.work_item_id,
            "ea_id": "QM5_9999",
            "symbol": "EURUSD.DWX",
            "baseline_run": {
                "period": "H1",
                "baseline_setfile_path": str(self.setfile.resolve()),
                "baseline_setfile_sha256": contract.sha256_file(self.setfile),
                "baseline_ex5_sha256": contract.sha256_file(self.ex5),
            },
            "deployed_ex5": {
                "path": str(self.ex5.resolve()),
                "sha256": contract.sha256_file(self.ex5),
            },
            "q07_seed_stability": {
                "work_item_id": "q07-1",
                "evidence_path": str(self.q07.resolve()),
                "evidence_sha256": contract.sha256_file(self.q07),
            },
        }
        self.anchor.write_bytes(contract.canonical_json_bytes(anchor))
        self.plan = runner.build_run_plan(
            work_item_id=self.work_item_id,
            candidate_lineage_key=contract.sha256_file(self.anchor),
            deployment_target="DXZ",
            q08_work_item_id="diagnostic-anchor-1",
            q08_evidence_path=self.anchor,
            baseline_setfile_path=self.setfile,
            ex5_path=self.ex5,
            include_closure_path=self.includes,
            calendar_manifest_path=self.calendar_manifest,
            calendar_common_relative_path="QM/q09_news/test/events.csv",
            full_from_utc="2019-01-01T00:00:00Z",
            full_to_utc="2025-12-31T23:59:59Z",
            selection_from_utc="2019-01-01T00:00:00Z",
            selection_to_utc="2023-12-31T23:59:59Z",
            holdout_from_utc="2024-01-01T00:00:00Z",
            holdout_to_utc="2025-12-31T23:59:59Z",
            complete_months=60,
            holdout_complete_months=24,
            tester_model="REAL_TICKS",
            cost_profile="DXZ_CANONICAL_REAL_TICKS_V1",
            output_root=self.root / "plan",
        )
        payload = {
            "diagnostic_non_admission": True,
            "diagnostic_contract": runner.DIAGNOSTIC_CONTRACT,
            "diagnostic_campaign_id": "test",
            "diagnostic_queue_rank": 1,
            "diagnostic_anchor_path": str(self.anchor.resolve()),
            "diagnostic_anchor_sha256": contract.sha256_file(self.anchor),
            "avoid_terminals": ["T6", "T7", "T8", "T9", "T10"],
            "staged_ex5_path": str(self.ex5.resolve()),
            "staged_ex5_sha256": contract.sha256_file(self.ex5),
        }
        now = "2026-08-05T00:00:00+00:00"
        with farmctl.connect(self.farm) as connection:
            connection.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
                ) VALUES('q07-1','backtest','Q07','QM5_9999','EURUSD.DWX',?,'done','PASS',
                         0,NULL,?,NULL,'{}',?,?)
                """,
                (str(self.setfile), str(self.q07), now, now),
            )
            connection.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
                ) VALUES(?, 'backtest','Q09_NEWS','QM5_9999','EURUSD.DWX',?,'pending',NULL,
                         0,NULL,NULL,NULL,?,?,?)
                """,
                (self.work_item_id, str(self.setfile), json.dumps(payload), now, now),
            )
            connection.commit()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def bind_and_activate(self) -> str:
        plan_path = Path(self.plan["plan_path"])
        plan_hash = contract.sha256_file(plan_path)
        bound = runner.bind_diagnostic_plan_to_work_item(
            self.farm,
            work_item_id=self.work_item_id,
            plan_path=plan_path,
            expected_plan_file_sha256=plan_hash,
            cell_timeout_sec=60,
        )
        self.assertTrue(bound["diagnostic_non_admission"])
        staged = self.root / "terminal" / "ea.ex5"
        staged.parent.mkdir(parents=True)
        staged.write_bytes(self.ex5.read_bytes())
        with farmctl.connect(self.farm) as connection:
            row = connection.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()
            payload = json.loads(row["payload_json"])
            binding_before = payload["q09_dispatch_binding_sha256"]
            payload["staged_ex5"] = {
                "destination_path": str(staged.resolve()),
                "required_sha256": contract.sha256_file(staged),
                "pre_run_sha256": contract.sha256_file(staged),
            }
            self.assertEqual(binding_before, runner._dispatch_binding_sha256(payload))
            connection.execute(
                "UPDATE work_items SET status='active',claimed_by='T1',payload_json=? WHERE id=?",
                (json.dumps(payload, sort_keys=True), self.work_item_id),
            )
            connection.commit()
        return plan_hash

    def test_diagnostic_binding_is_claimable_and_capacity_is_t1_to_t5_only(self) -> None:
        plan_hash = self.bind_and_activate()
        capacity = runner.assert_factory_capacity(
            self.farm,
            work_item_id=self.work_item_id,
            terminal="T1",
            plan_path=Path(self.plan["plan_path"]),
            expected_plan_file_sha256=plan_hash,
        )
        self.assertTrue(capacity["payload"]["diagnostic_non_admission"])
        with self.assertRaisesRegex(runner.CapacityError, "active terminal claim|cap violated"):
            runner.assert_factory_capacity(
                self.farm,
                work_item_id=self.work_item_id,
                terminal="T6",
                plan_path=Path(self.plan["plan_path"]),
                expected_plan_file_sha256=plan_hash,
            )

    def test_diagnostic_binding_allows_only_dynamic_t1_to_t5_retry_avoidance(self) -> None:
        plan_hash = self.bind_and_activate()
        with farmctl.connect(self.farm) as connection:
            row = connection.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()
            payload = json.loads(row["payload_json"])
            payload["avoid_terminals"].append("T2")
            connection.execute(
                "UPDATE work_items SET payload_json=? WHERE id=?",
                (json.dumps(payload, sort_keys=True), self.work_item_id),
            )
            connection.commit()
        capacity = runner.assert_factory_capacity(
            self.farm,
            work_item_id=self.work_item_id,
            terminal="T1",
            plan_path=Path(self.plan["plan_path"]),
            expected_plan_file_sha256=plan_hash,
        )
        self.assertIn("T2", capacity["payload"]["avoid_terminals"])
        self.assertTrue(
            {"T6", "T7", "T8", "T9", "T10"}.issubset(
                terminal_worker._payload_avoid_terminals({
                    "diagnostic_non_admission": True,
                    "diagnostic_allowed_terminals": ["T1", "T2", "T3", "T4", "T5"],
                    "avoid_terminals": [],
                })
            )
        )

    def test_diagnostic_runner_stages_exact_binary_for_legacy_worker_label(self) -> None:
        payload = {
            "staged_ex5_path": str(self.ex5.resolve()),
            "staged_ex5_sha256": contract.sha256_file(self.ex5),
        }
        terminal_root = self.root / "T1"
        with mock.patch.object(
            runner, "_claimed_factory_terminal_root", return_value=terminal_root
        ):
            staged = runner._stage_diagnostic_expert_binary(
                payload, terminal="T1", expert=r"QM\QM5_9999"
            )
        destination = terminal_root / "MQL5" / "Experts" / "QM" / "QM5_9999.ex5"
        self.assertEqual(Path(staged["destination_path"]), destination.resolve())
        self.assertEqual(destination.read_bytes(), self.ex5.read_bytes())
        self.assertEqual(staged["sha256"], contract.sha256_file(self.ex5))

    def test_diagnostic_persistence_writes_review_summary_not_canonical_q09(self) -> None:
        plan_hash = self.bind_and_activate()
        output = self.root / "result"
        output.mkdir()
        evidence = output / "evidence.json"
        aggregate = output / "aggregate.json"
        evidence.write_text('{"cells":[]}\n', encoding="utf-8")
        aggregate.write_text('{"verdict":"CONFIG_LOCKED"}\n', encoding="utf-8")
        result = {
            "evidence_path": str(evidence),
            "aggregate_path": str(aggregate),
            "aggregate_sha256": contract.sha256_file(aggregate),
        }
        sidecar = runner._persist_q09_result(
            self.farm,
            work_item_id=self.work_item_id,
            terminal="T1",
            plan_path=Path(self.plan["plan_path"]),
            expected_plan_file_sha256=plan_hash,
            result=result,
        )
        self.assertEqual(sidecar["status"], "DIAGNOSTIC_RECORDED")
        summary = json.loads((output / "summary.json").read_text(encoding="utf-8"))
        self.assertEqual(summary["verdict"], "REVIEW_REQUIRED")
        self.assertTrue(summary["diagnostic_non_admission"])
        with farmctl.connect(self.farm) as connection:
            self.assertEqual(
                connection.execute(
                    "SELECT count(*) FROM q09_news_tests WHERE work_item_id=?",
                    (self.work_item_id,),
                ).fetchone()[0],
                0,
            )

    def test_diagnostic_uses_deployed_ex5_name_and_worker_accepts_only_review_sidecar(self) -> None:
        self.bind_and_activate()
        output = self.root / "reports" / "QM5_9999" / "Q09_NEWS" / "EURUSD_DWX"
        output.mkdir(parents=True)
        evidence = output / "q09_news_evidence.json"
        aggregate = output / "aggregate.json"
        evidence.write_text('{"cells":[]}\n', encoding="utf-8")
        aggregate.write_text('{"verdict":"CONFIG_LOCKED"}\n', encoding="utf-8")
        summary = {
            "schema_version": runner.DIAGNOSTIC_SUMMARY_SCHEMA,
            "phase": "Q09_NEWS",
            "verdict": "REVIEW_REQUIRED",
            "reason": "diagnostic_non_admission",
            "reason_codes": ["diagnostic_non_admission", "owner_review_required"],
            "diagnostic_non_admission": True,
            "diagnostic_contract": runner.DIAGNOSTIC_CONTRACT,
            "work_item_id": self.work_item_id,
            "underlying_q09_verdict": "CONFIG_LOCKED",
            "aggregate_path": str(aggregate.resolve()),
            "aggregate_sha256": contract.sha256_file(aggregate),
            "evidence_path": str(evidence.resolve()),
            "evidence_sha256": contract.sha256_file(evidence),
            "diagnostic_anchor_path": str(self.anchor.resolve()),
            "diagnostic_anchor_sha256": contract.sha256_file(self.anchor),
        }
        (output / "summary.json").write_bytes(contract.canonical_json_bytes(summary))
        with farmctl.connect(self.farm) as connection:
            row = connection.execute(
                "SELECT * FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()
            payload = json.loads(row["payload_json"])
            payload.update({
                "phase_evidence_path": str(aggregate.resolve()),
                "report_root": str((self.root / "reports").resolve()),
            })
            connection.execute(
                "UPDATE work_items SET payload_json=? WHERE id=?",
                (json.dumps(payload, sort_keys=True), self.work_item_id),
            )
            connection.commit()
            row = connection.execute(
                "SELECT * FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()

        command = farmctl._phase_runner_cmd_for_work_item(
            self.farm, row, self.root / "reports", "T1", REPO
        )
        self.assertIsNotNone(command)
        self.assertEqual(command[command.index("--expert") + 1], r"QM\live")
        aggregate_data = json.loads(aggregate.read_text(encoding="utf-8"))
        self.assertTrue(
            terminal_worker._q09_sidecar_matches(
                self.farm, row, aggregate, aggregate_data
            )
        )
        result = terminal_worker._finish_work_item(self.farm, self.work_item_id, 0)
        self.assertEqual(result["status"], "done")
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        with farmctl.connect(self.farm) as connection:
            finished = connection.execute(
                "SELECT verdict,evidence_path,payload_json FROM work_items WHERE id=?",
                (self.work_item_id,),
            ).fetchone()
        self.assertEqual(finished["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(Path(finished["evidence_path"]), output / "summary.json")
        finished_payload = json.loads(finished["payload_json"])
        self.assertEqual(
            finished_payload["q09_sidecar_verification"],
            "diagnostic_summary_matched",
        )
        self.assertEqual(
            finished_payload["diagnostic_underlying_q09_verdict"],
            "CONFIG_LOCKED",
        )

    def test_live_baseline_derivation_neutralizes_control_and_preserves_source(self) -> None:
        source = self.root / "live.set"
        source.write_text(
            "RISK_FIXED=0\nRISK_PERCENT=0.75\nqm_filter_news_enabled=1\n"
            "qm_filter_news_mode=3\nqm_news_stale_max_hours=336\n",
            encoding="utf-8",
        )
        before = source.read_bytes()
        derived = self.root / "derived.set"
        receipt = backfill.derived_baseline(source, derived)
        self.assertEqual(source.read_bytes(), before)
        values = runner._setfile_values(derived)
        self.assertEqual(values["risk_fixed"], "1000")
        self.assertEqual(values["risk_percent"], "0")
        self.assertEqual(values["qm_filter_news_enabled"], "0")
        self.assertEqual(values["qm_filter_news_mode"], "0")
        self.assertLessEqual(int(values["qm_news_stale_max_hours"]), 336)
        self.assertTrue(receipt["legacy_control_neutralized"])

    def test_campaign_order_and_terminal_cap_are_exact(self) -> None:
        self.assertEqual(len(backfill.SLEEVES), 17)
        self.assertEqual([s.rank for s in backfill.SLEEVES], list(range(1, 18)))
        self.assertEqual(
            [(s.ea_id, s.symbol, s.weight) for s in backfill.SLEEVES[:4]],
            [(12567, "XNGUSD", 0.98), (10919, "XTIUSD", 0.92),
             (12567, "XAUUSD", 0.75), (1556, "XAUUSD", 0.60)],
        )
        self.assertEqual(backfill.ALLOWED_TERMINALS, ("T1", "T2", "T3", "T4", "T5"))
        self.assertEqual(backfill.AVOID_TERMINALS, ("T6", "T7", "T8", "T9", "T10"))

    def test_append_only_rerun_preserves_predecessor_and_steers_launch_fault(self) -> None:
        artifact_root = self.root / "campaign"
        source_anchor = json.loads(self.anchor.read_text(encoding="utf-8"))
        source_anchor["diagnostic_include_assessment"] = {
            "path": str(self.includes.resolve()),
            "sha256": contract.sha256_file(self.includes),
        }
        self.anchor.write_bytes(contract.canonical_json_bytes(source_anchor))
        campaign = {
            "schema_version": "q09-live-news-backfill-plan/v1",
            "campaign_id": backfill.CAMPAIGN_ID,
            "diagnostic_non_admission": True,
            "sleeves": [{
                "rank": 2,
                "ea_id": "QM5_9999",
                "symbol": "EURUSD.DWX",
                "period": "H1",
                "weight": 0.92,
                "work_item_id": self.work_item_id,
                "anchor_path": str(self.anchor.resolve()),
                "anchor_sha256": contract.sha256_file(self.anchor),
                "baseline_setfile_path": str(self.setfile.resolve()),
                "baseline_setfile_sha256": contract.sha256_file(self.setfile),
                "deployed_ex5_path": str(self.ex5.resolve()),
                "deployed_ex5_sha256": contract.sha256_file(self.ex5),
            }],
        }
        artifact_root.mkdir(parents=True)
        (artifact_root / "campaign_plan.json").write_bytes(
            contract.canonical_json_bytes(campaign)
        )
        with farmctl.connect(self.farm) as connection:
            row = connection.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()
            payload = json.loads(row["payload_json"])
            payload.update({
                "diagnostic_campaign_id": backfill.CAMPAIGN_ID,
                "last_launch_fault_terminal": "T3",
            })
            connection.execute(
                "UPDATE work_items SET status='failed',verdict='INFRA_FAIL',payload_json=? "
                "WHERE id=?",
                (json.dumps(payload, sort_keys=True), self.work_item_id),
            )
            connection.commit()

        task_id = "router-follow-up-1"
        with (
            mock.patch.object(backfill, "ARTIFACT_ROOT", artifact_root),
            mock.patch.object(backfill, "FARM_ROOT", self.farm),
            mock.patch.object(backfill, "CALENDAR_MANIFEST", self.calendar_manifest),
            mock.patch.object(
                backfill, "CALENDAR_COMMON_PATH", "QM/q09_news/test/events.csv"
            ),
        ):
            receipt = backfill.enqueue_append_only_rerun(
                task_id=task_id,
                predecessor_id=self.work_item_id,
                avoid_terminal="T3",
            )

        expected_id = backfill.append_only_rerun_id(self.work_item_id, task_id)
        self.assertEqual(receipt["work_item_id"], expected_id)
        self.assertEqual(receipt["rerun_of"], self.work_item_id)
        self.assertEqual(receipt["cell_count"], 40)
        with farmctl.connect(self.farm) as connection:
            predecessor = connection.execute(
                "SELECT status,verdict FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()
            rerun = connection.execute(
                "SELECT status,verdict,parent_task_id,payload_json FROM work_items WHERE id=?",
                (expected_id,),
            ).fetchone()
            canonical_count = connection.execute(
                "SELECT count(*) FROM q09_news_tests WHERE work_item_id IN (?,?)",
                (self.work_item_id, expected_id),
            ).fetchone()[0]
        self.assertEqual((predecessor["status"], predecessor["verdict"]), ("failed", "INFRA_FAIL"))
        self.assertEqual((rerun["status"], rerun["verdict"]), ("pending", None))
        self.assertEqual(rerun["parent_task_id"], self.work_item_id)
        rerun_payload = json.loads(rerun["payload_json"])
        self.assertEqual(rerun_payload["rerun_of"], self.work_item_id)
        self.assertEqual(
            set(rerun_payload["avoid_terminals"]),
            {"T3", "T6", "T7", "T8", "T9", "T10"},
        )
        self.assertNotIn("launch_not_before_utc", rerun_payload)
        self.assertEqual(canonical_count, 0)

    def test_generation_rerun_reuses_sealed_anchor_and_preserves_cell_identities(self) -> None:
        artifact_root = self.root / "campaign"
        plan_path = Path(self.plan["plan_path"])
        plan_hash = contract.sha256_file(plan_path)
        with (
            mock.patch.object(backfill, "ARTIFACT_ROOT", artifact_root),
            mock.patch.object(backfill, "FARM_ROOT", self.farm),
        ):
            runner.bind_diagnostic_plan_to_work_item(
                self.farm,
                work_item_id=self.work_item_id,
                plan_path=plan_path,
                expected_plan_file_sha256=plan_hash,
                cell_timeout_sec=60,
            )

            failed_cell_root = Path(self.plan["cells"][0]["receipt_path"]).parent
            failed_cell_root.mkdir(parents=True, exist_ok=True)
            (failed_cell_root / "cell_failure.json").write_text(
                json.dumps({
                    "error_type": "RunnerError",
                    "error": "Q09 selection run_smoke exited with code 1",
                }),
                encoding="utf-8",
            )
            summary_path = self.root / "summary.json"
            summary_path.write_text(
                json.dumps({
                    "schema_version": "q09-live-news-diagnostic-summary/v1",
                    "diagnostic_non_admission": True,
                    "diagnostic_contract": runner.DIAGNOSTIC_CONTRACT,
                    "work_item_id": self.work_item_id,
                }),
                encoding="utf-8",
            )
            with farmctl.connect(self.farm) as connection:
                row = connection.execute(
                    "SELECT payload_json FROM work_items WHERE id=?",
                    (self.work_item_id,),
                ).fetchone()
                payload = json.loads(row["payload_json"])
                payload.update({
                    "diagnostic_campaign_id": backfill.CAMPAIGN_ID,
                    "diagnostic_generation": 2,
                    "diagnostic_queue_rank": -98,
                    "diagnostic_source_rank": 2,
                    "diagnostic_live_weight": 0.92,
                    "diagnostic_control": "test-neutralized",
                    "host_symbol": "EURUSD.DWX",
                    "host_timeframe": "H1",
                    "terminal": "T4",
                    "protected_chain_exclusion": ["round7", "Q09_PORTFOLIO", "Q10"],
                })
                connection.execute(
                    "UPDATE work_items SET status='done',verdict='REVIEW_REQUIRED',"
                    "evidence_path=?,payload_json=? WHERE id=?",
                    (str(summary_path), json.dumps(payload, sort_keys=True), self.work_item_id),
                )
                connection.commit()

            task_id = "router-transient-generation-1"
            receipt = backfill.enqueue_append_only_rerun(
                task_id=task_id,
                predecessor_id=self.work_item_id,
                avoid_terminal="T4",
            )
            repeated = backfill.enqueue_append_only_rerun(
                task_id=task_id,
                predecessor_id=self.work_item_id,
                avoid_terminal="T4",
            )

        expected_id = backfill.transient_generation_rerun_id(
            self.work_item_id, task_id
        )
        self.assertEqual(receipt["work_item_id"], expected_id)
        self.assertTrue(receipt["ordered_cell_identities_equal"])
        self.assertTrue(repeated["idempotent"])
        rerun_plan = json.loads(
            Path(receipt["plan_path"]).read_text(encoding="utf-8")
        )
        identity_keys = (
            "run_identity_sha256", "setfile_sha256", "arm", "compliance_mode",
            "temporal_mode", "seed", "paired_base_identity_sha256",
        )
        self.assertEqual(
            [tuple(cell.get(key) for key in identity_keys) for cell in self.plan["cells"]],
            [tuple(cell.get(key) for key in identity_keys) for cell in rerun_plan["cells"]],
        )
        with farmctl.connect(self.farm) as connection:
            rerun = connection.execute(
                "SELECT status,parent_task_id,payload_json FROM work_items WHERE id=?",
                (expected_id,),
            ).fetchone()
            canonical_count = connection.execute(
                "SELECT count(*) FROM q09_news_tests WHERE work_item_id IN (?,?)",
                (self.work_item_id, expected_id),
            ).fetchone()[0]
        rerun_payload = json.loads(rerun["payload_json"])
        self.assertEqual(rerun["status"], "pending")
        self.assertEqual(rerun["parent_task_id"], self.work_item_id)
        self.assertEqual(rerun_payload["diagnostic_generation"], 3)
        self.assertTrue(rerun_payload["sealed_identity_rerun"])
        self.assertEqual(
            Path(rerun_payload["diagnostic_anchor_path"]), self.anchor.resolve()
        )
        self.assertEqual(
            set(rerun_payload["avoid_terminals"]),
            {"T4", "T6", "T7", "T8", "T9", "T10"},
        )
        self.assertNotIn("launch_not_before_utc", rerun_payload)
        self.assertEqual(canonical_count, 0)

    def test_generation_rerun_proof_accepts_one_ok_after_invalid_startup(self) -> None:
        cell_root = self.root / "retry-then-ok-cell"
        run_summary_path = cell_root / "runs" / "holdout" / "fixture" / "summary.json"
        run_summary_path.parent.mkdir(parents=True)
        run_summary_path.write_text(
            json.dumps({
                "result": "PASS",
                "runs": [
                    {"run": "run_01", "status": "INVALID", "failure": "BARS_ZERO"},
                    {"run": "run_02", "status": "OK", "total_trades": 34},
                ],
            }),
            encoding="utf-8",
        )
        failure_path = cell_root / "cell_failure.json"
        failure_path.write_text(
            json.dumps({
                "error_type": "RunnerError",
                "error": "run_smoke did not publish exactly one authenticated OK run",
                "artifacts": [{
                    "path": str(run_summary_path.resolve()),
                    "relative_path": "runs/holdout/fixture/summary.json",
                    "sha256": contract.sha256_file(run_summary_path),
                }],
            }),
            encoding="utf-8",
        )
        diagnostic_summary = self.root / "retry-then-ok-diagnostic-summary.json"
        diagnostic_summary.write_text(
            json.dumps({
                "schema_version": "q09-live-news-diagnostic-summary/v1",
                "diagnostic_non_admission": True,
                "diagnostic_contract": runner.DIAGNOSTIC_CONTRACT,
                "work_item_id": self.work_item_id,
            }),
            encoding="utf-8",
        )
        predecessor = {
            "id": self.work_item_id,
            "status": "done",
            "verdict": "REVIEW_REQUIRED",
            "evidence_path": str(diagnostic_summary),
        }
        payload = {
            "diagnostic_non_admission": True,
            "diagnostic_campaign_id": backfill.CAMPAIGN_ID,
            "diagnostic_generation": 2,
        }
        plan = {"cells": [{
            "receipt_path": str(cell_root / "cell_receipt.json"),
            "run_identity_sha256": "a" * 64,
        }]}

        proof = backfill._transient_generation_failure_proof(
            predecessor, payload, plan
        )

        self.assertEqual(len(proof), 1)
        self.assertEqual(
            proof[0]["proof_kind"],
            "one_ok_after_invalid_startup_attempt",
        )
        self.assertEqual(
            proof[0]["supporting_summary_sha256"],
            contract.sha256_file(run_summary_path),
        )

    def test_generation_rerun_proof_accepts_misapplied_diagnostic_trade_floor(self) -> None:
        cell_root = self.root / "diagnostic-min-trades-cell"
        run_summary_path = cell_root / "runs" / "selection" / "fixture" / "summary.json"
        run_summary_path.parent.mkdir(parents=True)
        run_summary_path.write_text(
            json.dumps({
                "result": "FAIL",
                "reason_classes": ["MIN_TRADES_NOT_MET"],
                "requested_runs": 1,
                "deterministic": True,
                "oninit_failure_detected": False,
                "min_trades_required": 25,
                "execution_identity": {"stable_during_run": True},
                "runs": [{
                    "run": "run_01",
                    "status": "OK",
                    "total_trades": 24,
                }],
            }),
            encoding="utf-8",
        )
        failure_path = cell_root / "cell_failure.json"
        failure_path.write_text(
            json.dumps({
                "error_type": "RunnerError",
                "error": "Q09 selection run_smoke exited with code 1",
                "artifacts": [{
                    "path": str(run_summary_path.resolve()),
                    "relative_path": "runs/selection/fixture/summary.json",
                    "sha256": contract.sha256_file(run_summary_path),
                }],
            }),
            encoding="utf-8",
        )
        diagnostic_summary = self.root / "diagnostic-min-trades-summary.json"
        diagnostic_summary.write_text(
            json.dumps({
                "schema_version": "q09-live-news-diagnostic-summary/v1",
                "diagnostic_non_admission": True,
                "diagnostic_contract": runner.DIAGNOSTIC_CONTRACT,
                "work_item_id": self.work_item_id,
            }),
            encoding="utf-8",
        )
        predecessor = {
            "id": self.work_item_id,
            "status": "done",
            "verdict": "REVIEW_REQUIRED",
            "evidence_path": str(diagnostic_summary),
        }
        payload = {
            "diagnostic_non_admission": True,
            "diagnostic_campaign_id": backfill.CAMPAIGN_ID,
            "diagnostic_generation": 3,
        }
        plan = {"cells": [{
            "receipt_path": str(cell_root / "cell_receipt.json"),
            "run_identity_sha256": "b" * 64,
        }]}

        proof = backfill._transient_generation_failure_proof(
            predecessor, payload, plan
        )

        self.assertEqual(len(proof), 1)
        self.assertEqual(
            proof[0]["proof_kind"],
            "diagnostic_min_trades_floor_misapplied",
        )
        self.assertEqual(proof[0]["min_trades_required"], "25")
        self.assertEqual(proof[0]["actual_trades"], "24")

    def test_generation_rerun_proof_refuses_other_fresh_code_one_summary(self) -> None:
        cell_root = self.root / "diagnostic-other-code-one-cell"
        run_summary_path = cell_root / "runs" / "selection" / "fixture" / "summary.json"
        run_summary_path.parent.mkdir(parents=True)
        run_summary_path.write_text(
            json.dumps({
                "result": "FAIL",
                "reason_classes": ["TIMEOUT"],
                "requested_runs": 1,
                "deterministic": False,
                "oninit_failure_detected": False,
                "min_trades_required": 25,
                "execution_identity": {"stable_during_run": True},
                "runs": [],
            }),
            encoding="utf-8",
        )
        failure_path = cell_root / "cell_failure.json"
        failure_path.write_text(
            json.dumps({
                "error_type": "RunnerError",
                "error": "Q09 selection run_smoke exited with code 1",
                "artifacts": [{
                    "path": str(run_summary_path.resolve()),
                    "relative_path": "runs/selection/fixture/summary.json",
                    "sha256": contract.sha256_file(run_summary_path),
                }],
            }),
            encoding="utf-8",
        )
        diagnostic_summary = self.root / "diagnostic-other-code-one-summary.json"
        diagnostic_summary.write_text(
            json.dumps({
                "schema_version": "q09-live-news-diagnostic-summary/v1",
                "diagnostic_non_admission": True,
                "diagnostic_contract": runner.DIAGNOSTIC_CONTRACT,
                "work_item_id": self.work_item_id,
            }),
            encoding="utf-8",
        )

        with self.assertRaisesRegex(
            backfill.BackfillError,
            "no authenticated transient/no-receipt failure",
        ):
            backfill._transient_generation_failure_proof(
                {
                    "id": self.work_item_id,
                    "status": "done",
                    "verdict": "REVIEW_REQUIRED",
                    "evidence_path": str(diagnostic_summary),
                },
                {
                    "diagnostic_non_admission": True,
                    "diagnostic_campaign_id": backfill.CAMPAIGN_ID,
                    "diagnostic_generation": 3,
                },
                {"cells": [{
                    "receipt_path": str(cell_root / "cell_receipt.json"),
                    "run_identity_sha256": "c" * 64,
                }]},
            )

    def test_fresh_build_rerun_is_append_only_hash_bound_and_idempotent(self) -> None:
        artifact_root = self.root / "campaign"
        source_anchor = json.loads(self.anchor.read_text(encoding="utf-8"))
        source_anchor.update({
            "diagnostic_include_assessment": {
                "path": str(self.includes.resolve()),
                "sha256": contract.sha256_file(self.includes),
            },
            "live_source_preset": {
                "path": str(self.setfile.resolve()),
                "sha256": contract.sha256_file(self.setfile),
                "read_only": True,
            },
            "derived_baseline": {
                "source_path": str(self.setfile.resolve()),
                "source_sha256": contract.sha256_file(self.setfile),
                "derived_path": str(self.setfile.resolve()),
                "derived_sha256": contract.sha256_file(self.setfile),
            },
        })
        self.anchor.write_bytes(contract.canonical_json_bytes(source_anchor))
        campaign = {
            "schema_version": "q09-live-news-backfill-plan/v1",
            "campaign_id": backfill.CAMPAIGN_ID,
            "diagnostic_non_admission": True,
            "sleeves": [{
                "rank": 1,
                "ea_id": "QM5_9999",
                "symbol": "EURUSD.DWX",
                "period": "H1",
                "weight": 0.75,
                "work_item_id": self.work_item_id,
                "anchor_path": str(self.anchor.resolve()),
                "anchor_sha256": contract.sha256_file(self.anchor),
                "baseline_setfile_path": str(self.setfile.resolve()),
                "baseline_setfile_sha256": contract.sha256_file(self.setfile),
                "deployed_ex5_path": str(self.ex5.resolve()),
                "deployed_ex5_sha256": contract.sha256_file(self.ex5),
            }],
        }
        artifact_root.mkdir(parents=True)
        (artifact_root / "campaign_plan.json").write_bytes(
            contract.canonical_json_bytes(campaign)
        )
        with farmctl.connect(self.farm) as connection:
            row = connection.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()
            payload = json.loads(row["payload_json"])
            payload.update({
                "diagnostic_campaign_id": backfill.CAMPAIGN_ID,
                "diagnostic_non_admission": True,
            })
            connection.execute(
                "UPDATE work_items SET status='done',verdict='REVIEW_REQUIRED',payload_json=? "
                "WHERE id=?",
                (json.dumps(payload, sort_keys=True), self.work_item_id),
            )
            connection.commit()

        repo = self.root / "repo"
        ea_dir = repo / "framework" / "EAs" / "QM5_9999_live"
        include_dir = repo / "framework" / "include" / "QM"
        ea_dir.mkdir(parents=True)
        include_dir.mkdir(parents=True)
        fresh_ex5 = ea_dir / "QM5_9999_live.ex5"
        fresh_ex5.write_bytes(b"fresh-current-build")
        fresh_mq5 = ea_dir / "QM5_9999_live.mq5"
        fresh_mq5.write_text(
            "input QM_NewsTemporalMode qm_news_temporal = QM_NEWS_TEMPORAL_PRE30_POST30;\n"
            "input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;\n"
            "input int qm_news_stale_max_hours = 336;\n"
            "input string qm_news_min_impact = \"high\";\n"
            "void OnTick()\n{\n"
            "  // current V5 evidence hook\n"
            "  QM_FrameworkTrackOpenPositionMae();\n"
            "  if(!QM_KillSwitchCheck()) return;\n"
            "}\n",
            encoding="utf-8",
        )
        (include_dir / "QM_Common.mqh").write_text("// common\n", encoding="utf-8")
        (include_dir / "QM_NewsFilter.mqh").write_text("// news\n", encoding="utf-8")

        task_id = "router-fresh-build-1"
        fresh_hash = contract.sha256_file(fresh_ex5)
        patches = (
            mock.patch.object(backfill, "ARTIFACT_ROOT", artifact_root),
            mock.patch.object(backfill, "FARM_ROOT", self.farm),
            mock.patch.object(backfill, "CALENDAR_MANIFEST", self.calendar_manifest),
            mock.patch.object(
                backfill, "CALENDAR_COMMON_PATH", "QM/q09_news/test/events.csv"
            ),
            mock.patch.object(backfill, "REPO_ROOT", repo),
        )
        with patches[0], patches[1], patches[2], patches[3], patches[4]:
            receipt = backfill.enqueue_fresh_build_reruns(
                task_id=task_id,
                ea_id="QM5_9999",
                fresh_ex5_path=fresh_ex5,
                expected_fresh_ex5_sha256=fresh_hash,
            )
            repeated = backfill.enqueue_fresh_build_reruns(
                task_id=task_id,
                ea_id="QM5_9999",
                fresh_ex5_path=fresh_ex5,
                expected_fresh_ex5_sha256=fresh_hash,
            )

        self.assertEqual(receipt["sleeve_count"], 1)
        self.assertEqual(receipt["fresh_ex5_sha256"], fresh_hash)
        self.assertTrue(repeated["idempotent"])
        expected_id = backfill.fresh_build_rerun_id(
            self.work_item_id, task_id, fresh_hash
        )
        self.assertEqual(receipt["work_item_ids"], [expected_id])
        with farmctl.connect(self.farm) as connection:
            predecessor = connection.execute(
                "SELECT status,verdict FROM work_items WHERE id=?", (self.work_item_id,)
            ).fetchone()
            reruns = connection.execute(
                "SELECT id,status,parent_task_id,payload_json FROM work_items WHERE id=?",
                (expected_id,),
            ).fetchall()
            canonical_count = connection.execute(
                "SELECT count(*) FROM q09_news_tests WHERE work_item_id IN (?,?)",
                (self.work_item_id, expected_id),
            ).fetchone()[0]
        self.assertEqual((predecessor["status"], predecessor["verdict"]),
                         ("done", "REVIEW_REQUIRED"))
        self.assertEqual(len(reruns), 1)
        self.assertEqual(reruns[0]["status"], "pending")
        self.assertEqual(reruns[0]["parent_task_id"], self.work_item_id)
        rerun_payload = json.loads(reruns[0]["payload_json"])
        self.assertEqual(rerun_payload["diagnostic_generation"], 2)
        self.assertEqual(rerun_payload["diagnostic_queue_rank"], -99)
        self.assertEqual(rerun_payload["staged_ex5_sha256"], fresh_hash)
        self.assertEqual(rerun_payload["rerun_of"], self.work_item_id)
        self.assertEqual(
            set(rerun_payload["avoid_terminals"]),
            {"T6", "T7", "T8", "T9", "T10"},
        )
        anchor_path = Path(rerun_payload["diagnostic_anchor_path"])
        fresh_anchor = json.loads(anchor_path.read_text(encoding="utf-8"))
        self.assertEqual(fresh_anchor["fresh_build_ex5"]["sha256"], fresh_hash)
        self.assertEqual(
            fresh_anchor["deployed_ex5"]["sha256"], contract.sha256_file(self.ex5)
        )
        self.assertEqual(fresh_anchor["baseline_run"]["baseline_ex5_sha256"], fresh_hash)
        self.assertEqual(canonical_count, 0)


if __name__ == "__main__":
    unittest.main()
