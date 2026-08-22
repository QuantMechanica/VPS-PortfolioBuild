import json
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_contract as contract  # noqa: E402
import q09_news_calendar as calendar_bundle  # noqa: E402
import q09_news_runner as runner  # noqa: E402
import q09_news_schema as schema  # noqa: E402
import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


def metrics(sharpe: float) -> dict:
    return {
        "trades": 30,
        "profit_factor": 1.2,
        "drawdown_pct": 10.0,
        "sharpe": sharpe,
        "net_r": 100.0,
        "original_entries": 100,
        "blocked_entries": 0,
        "affected_entries": 0,
    }


class Q09NewsRunnerV2Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.root = Path(self.temporary.name)
        self.q08 = self.root / "q08.json"
        self.setfile = self.root / "baseline.set"
        self.setfile.write_bytes(
            b"qm_rng_seed=42\r\nqm_news_temporal=3\r\nqm_news_compliance=1\r\n"
            b"qm_news_stale_max_hours=336\r\nRISK_FIXED=1000\r\nRISK_PERCENT=0\r\n"
        )
        self.ex5 = self.root / "ea.ex5"
        self.ex5.write_bytes(b"compiled")
        self.q08.write_text(
            json.dumps(
                {
                    "verdict": "PASS",
                    "baseline_run": {
                        "period": "H1",
                        "baseline_setfile_path": str(self.setfile.resolve()),
                        "baseline_setfile_sha256": contract.sha256_file(self.setfile),
                        "baseline_ex5_sha256": contract.sha256_file(self.ex5),
                    },
                }
            )
            + "\n",
            encoding="utf-8",
        )
        self.includes = self.root / "includes.json"
        self.includes.write_text('{"closure":"sealed"}\n', encoding="utf-8")
        calendar_source = self.root / "calendar.csv"
        calendar_source.write_text(
            "datetime,currency,event_name,impact\n2024-01-10 13:30:00,USD,CPI,high\n",
            encoding="utf-8",
        )
        calendar_receipt = self.root / "calendar_receipt.json"
        calendar_receipt.write_text(
            json.dumps(
                {
                    "approved_by": "OWNER",
                    "approved_at": "2026-07-29T08:00:00Z",
                    "reason": "sealed test calendar",
                }
            ),
            encoding="utf-8",
        )
        calendar_plan = calendar_bundle.build_bundle_plan(
            source_csv=calendar_source,
            receipt_path=calendar_receipt,
            coverage_from_utc="2019-01-01T00:00:00Z",
            coverage_to_utc="2026-01-01T00:00:00Z",
            publication_reason="INITIAL",
        )
        published = calendar_bundle.publish_bundle(calendar_plan, self.root / "calendar_bundles")
        self.calendar = Path(published["manifest_path"])

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_news_selfreport_has_six_filled_provenance_fields(self) -> None:
        report = runner.build_news_selfreport(self.calendar)
        for field in (
            "source_path",
            "content_sha256",
            "row_count",
            "max_event_date_utc",
            "schema_version",
            "mapping_version",
        ):
            self.assertNotIn(report[field], (None, "", 0))
        self.assertEqual(report["mapping_version"], runner.PRE_V2_MAPPING_VERSION)
        self.assertEqual(report["evidence_authority"], "NON_AUTHORITATIVE_PRE_V2")

    def test_single_ok_run_accepts_invalid_startup_attempt_then_success(self) -> None:
        invalid = {"run": "run_01", "status": "INVALID", "failure": "BARS_ZERO"}
        successful = {"run": "run_02", "status": "OK", "total_trades": 34}

        self.assertIs(
            runner._single_ok_run({"runs": [invalid, successful]}),
            successful,
        )
        for runs in (
            [invalid],
            [successful, {"run": "run_03", "status": "OK"}],
        ):
            with self.assertRaisesRegex(
                runner.RunnerError,
                "exactly one authenticated OK run",
            ):
                runner._single_ok_run({"runs": runs})

    def build(self, *, target: str = "DXZ", output: str = "experiment", news: bool = False) -> dict:
        return runner.build_run_plan(
            work_item_id="q09-news-1",
            candidate_lineage_key=contract.sha256_bytes(b"candidate"),
            deployment_target=target,
            q08_work_item_id="q08-1",
            q08_evidence_path=self.q08,
            baseline_setfile_path=self.setfile,
            ex5_path=self.ex5,
            include_closure_path=self.includes,
            calendar_manifest_path=self.calendar,
            calendar_common_relative_path="q09_news/sealed/events.csv",
            full_from_utc="2020-01-01T00:00:00Z",
            full_to_utc="2025-01-01T00:00:00Z",
            selection_from_utc="2020-01-01T00:00:00Z",
            selection_to_utc="2022-12-31T23:59:59Z",
            holdout_from_utc="2023-01-01T00:00:00Z",
            holdout_to_utc="2025-01-01T00:00:00Z",
            complete_months=60,
            holdout_complete_months=24,
            tester_model="REAL_TICKS",
            cost_profile="DXZ_MED",
            output_root=self.root / output,
            news_or_event_strategy=news,
        )

    def write_receipt(self, spec: dict) -> None:
        seed_index = contract.SEEDS.index(spec["seed"])
        control_selection = 0.50 + seed_index * 0.01
        control_holdout = 0.40 + seed_index * 0.01
        delta = 0.10 if spec["arm"] == "POLICY_ON" and spec["temporal_mode"] == "PRE30" else 0.0
        report = Path(spec["receipt_path"]).with_name("report.json")
        evidence = Path(spec["receipt_path"]).with_name("summary.json")
        report.write_text(spec["run_identity_sha256"] + "\n", encoding="utf-8")
        cell_metrics = {
            "selection": metrics(control_selection + delta),
            "holdout": metrics(control_holdout + delta),
            "full": metrics((control_selection + control_holdout) / 2 + delta),
        }
        evidence.write_bytes(
            contract.canonical_json_bytes(
                {
                    "schema_version": runner.CELL_EVIDENCE_SCHEMA,
                    "run_identity_sha256": spec["run_identity_sha256"],
                    "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
                    "requested_seed": spec["seed"],
                    "effective_seed": spec["seed"],
                    "setfile_sha256": spec["setfile_sha256"],
                    "report_sha256": contract.sha256_file(report),
                    "metrics": cell_metrics,
                    "q07_seed_stability_pass": True,
                    "flat_at_event_receipt_sha256": None,
                }
            )
        )
        receipt = {
            "schema_version": runner.CELL_RECEIPT_SCHEMA,
            "run_identity_sha256": spec["run_identity_sha256"],
            "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
            "arm": spec["arm"],
            "temporal_mode": spec["temporal_mode"],
            "compliance_mode": spec["compliance_mode"],
            "seed": spec["seed"],
            "requested_seed": spec["seed"],
            "effective_seed": spec["seed"],
            "setfile_sha256": spec["setfile_sha256"],
            "report_path": str(report),
            "report_sha256": contract.sha256_file(report),
            "evidence_path": str(evidence),
            "evidence_sha256": contract.sha256_file(evidence),
            "metrics": cell_metrics,
            "q07_seed_stability_pass": True,
        }
        Path(spec["receipt_path"]).write_bytes(contract.canonical_json_bytes(receipt))

    def write_receipts(self, plan: dict) -> None:
        for spec in plan["cells"]:
            self.write_receipt(spec)

    def setup_bound_farm(
        self,
        plan: dict,
        *,
        activate: bool,
        attempt_count: int = 0,
        q08_verdict: str = "PASS",
        portfolio_rescue: bool = False,
    ) -> tuple[Path, str]:
        farm_root = self.root / "farm"
        farmctl.init_db(farm_root)
        q07_evidence = self.root / "q07.json"
        q07_evidence.write_text('{"verdict":"MULTI_SEED_PASS"}\n', encoding="utf-8")
        q09_payload: dict[str, str] = {}
        portfolio_evidence = self.root / "q09_portfolio.json"
        if portfolio_rescue:
            portfolio_evidence.write_text(
                '{"verdict":"PASS_PORTFOLIO"}\n', encoding="utf-8"
            )
            q09_payload = {
                "q09_portfolio_work_item_id": "q09-portfolio-1",
                "q09_portfolio_evidence_sha256": contract.sha256_file(
                    portfolio_evidence
                ),
            }
        now = "2026-08-02T00:00:00+00:00"
        with closing(farmctl.connect(farm_root)) as connection:
            for values in (
                (
                    "q07-1", "Q07", "done", "MULTI_SEED_PASS",
                    str(q07_evidence), "{}",
                ),
                (
                    "q08-1", "Q08", "done", q08_verdict, str(self.q08),
                    json.dumps({"promoted_from_work_item": "q07-1"}),
                ),
                (
                    "q09-news-1", "Q09_NEWS", "pending", None, None,
                    json.dumps(q09_payload, sort_keys=True),
                ),
            ):
                connection.execute(
                    """
                    INSERT INTO work_items(
                        id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                        attempt_count,parent_task_id,evidence_path,claimed_by,
                        payload_json,created_at,updated_at
                    ) VALUES(?, 'backtest', ?, 'QM5_9999', 'EURUSD.DWX', ?, ?, ?,
                             0, NULL, ?, NULL, ?, ?, ?)
                    """,
                    (
                        values[0], values[1], str(self.setfile), values[2],
                        values[3], values[4], values[5], now, now,
                    ),
                )
            if portfolio_rescue:
                connection.execute(
                    """
                    INSERT INTO work_items(
                        id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                        attempt_count,parent_task_id,evidence_path,claimed_by,
                        payload_json,created_at,updated_at
                    ) VALUES('q09-portfolio-1','backtest','Q09_PORTFOLIO',
                             'QM5_9999','EURUSD.DWX',?,'done','PASS_PORTFOLIO',
                             0,NULL,?,NULL,'{}',?,?)
                    """,
                    (str(self.setfile), str(portfolio_evidence), now, now),
                )
                schema.add_dependency(
                    connection,
                    child_work_item_id="q09-portfolio-1",
                    dependency_role="Q08_INPUT",
                    parent_work_item_id="q08-1",
                    parent_evidence_sha256=contract.sha256_file(self.q08),
                    required_verdicts=[q08_verdict],
                )
            schema.add_dependency(
                connection,
                child_work_item_id="q09-news-1",
                dependency_role="Q08_INPUT",
                parent_work_item_id="q08-1",
                parent_evidence_sha256=contract.sha256_file(self.q08),
                required_verdicts=[q08_verdict],
            )
            schema.hold_until_plan_bound(connection, "q09-news-1", now=now)
            connection.commit()
        plan_hash = contract.sha256_file(Path(plan["plan_path"]))
        binding = runner.bind_plan_to_work_item(
            farm_root,
            work_item_id="q09-news-1",
            plan_path=Path(plan["plan_path"]),
            expected_plan_file_sha256=plan_hash,
            cell_timeout_sec=60,
        )
        self.assertTrue(binding["activation_hold_released"])
        self.assertEqual(binding["activation_state"], "RUNNABLE_BOUND")
        with closing(farmctl.connect(farm_root)) as connection:
            hold = connection.execute(
                "SELECT active,release_note FROM work_item_holds WHERE work_item_id='q09-news-1'"
            ).fetchone()
            payload = json.loads(
                connection.execute(
                    "SELECT payload_json FROM work_items WHERE id='q09-news-1'"
                ).fetchone()[0]
            )
        self.assertEqual(hold[0], 0)
        self.assertIn("sealed Q09 run plan bound", hold[1])
        self.assertEqual(payload["q09_activation_state"], "RUNNABLE_BOUND")
        with closing(farmctl.connect(farm_root)) as connection:
            connection.execute(
                "UPDATE work_items SET attempt_count=? WHERE id='q09-news-1'",
                (int(attempt_count),),
            )
            connection.commit()
        if activate:
            with closing(farmctl.connect(farm_root)) as connection:
                connection.execute(
                    "UPDATE work_items SET status='active',claimed_by='T1' WHERE id='q09-news-1'"
                )
                connection.commit()
        return farm_root, plan_hash

    def test_plan_binding_accepts_exact_fail_soft_portfolio_rescue(self) -> None:
        plan = self.build(output="binding-fail-soft-portfolio")
        farm_root, _ = self.setup_bound_farm(
            plan,
            activate=False,
            q08_verdict="FAIL_SOFT",
            portfolio_rescue=True,
        )
        with closing(farmctl.connect(farm_root)) as connection:
            hold = connection.execute(
                "SELECT active FROM work_item_holds WHERE work_item_id='q09-news-1'"
            ).fetchone()
        self.assertEqual(hold[0], 0)

    def test_plan_binding_rejects_unpaired_fail_soft(self) -> None:
        plan = self.build(output="binding-unpaired-fail-soft")
        with self.assertRaisesRegex(
            runner.RunnerError, "lacks an authenticated portfolio sibling"
        ):
            self.setup_bound_farm(
                plan,
                activate=False,
                q08_verdict="FAIL_SOFT",
                portfolio_rescue=False,
            )

    def test_plan_materializes_40_paired_cells_without_touching_source(self) -> None:
        source_before = self.setfile.read_bytes()
        plan = self.build()
        self.assertEqual(plan["cell_count"], 40)
        self.assertEqual(plan["matrix_scope"], "7x1_target_compliance")
        self.assertEqual(self.setfile.read_bytes(), source_before)
        control = next(cell for cell in plan["cells"] if cell["arm"] == "CONTROL_OFF" and cell["seed"] == 42)
        text = Path(control["setfile_path"]).read_text(encoding="utf-8")
        self.assertIn("qm_news_temporal=0", text)
        self.assertIn("qm_news_compliance=0", text)
        manifest = json.loads(self.calendar.read_text(encoding="utf-8"))
        self.assertIn("qm_news_calendar_bundle_id=" + manifest["bundle_id"], text)
        repeated = self.build()
        self.assertEqual(repeated["plan_sha256"], plan["plan_sha256"])

    def test_prop_or_event_strategy_plans_full_7x4_matrix(self) -> None:
        ftmo = self.build(target="FTMO", output="ftmo")
        self.assertEqual(ftmo["cell_count"], 145)
        self.assertEqual(ftmo["matrix_scope"], "7x4")
        event_strategy = self.build(news=True, output="event")
        self.assertEqual(event_strategy["cell_count"], 145)

    def test_execution_guard_refuses_weakened_stale_news_or_percent_risk(self) -> None:
        self.setfile.write_bytes(
            self.setfile.read_bytes().replace(
                b"qm_news_stale_max_hours=336", b"qm_news_stale_max_hours=337"
            )
        )
        stale_plan = self.build(output="stale-guard")
        _, stale_manifest = runner.load_authenticated_plan(Path(stale_plan["plan_path"]))
        with self.assertRaisesRegex(runner.RunnerError, "336-hour maximum"):
            runner._validate_cell_setfile(stale_plan["cells"][0], stale_manifest)

        self.setfile.write_bytes(
            self.setfile.read_bytes()
            .replace(b"qm_news_stale_max_hours=337", b"qm_news_stale_max_hours=336")
            .replace(b"RISK_PERCENT=0", b"RISK_PERCENT=1")
        )
        percent_plan = self.build(output="percent-risk-guard")
        _, percent_manifest = runner.load_authenticated_plan(Path(percent_plan["plan_path"]))
        with self.assertRaisesRegex(runner.RunnerError, "RISK_FIXED > 0 and RISK_PERCENT = 0"):
            runner._validate_cell_setfile(percent_plan["cells"][0], percent_manifest)

    def test_executor_fixture_report_consumes_sealed_calendar_bundle_inputs(self) -> None:
        plan = self.build(output="effective-calendar-inputs")
        _, manifest = runner.load_authenticated_plan(Path(plan["plan_path"]))
        spec = plan["cells"][0]
        report = self.root / "effective-inputs.htm"
        effective = {
            "qm_rng_seed": str(spec["seed"]),
            "qm_news_temporal": str(contract.TEMPORAL_MODE_IDS[spec["temporal_mode"]]),
            "qm_news_compliance": str(runner.COMPLIANCE_MODE_IDS[spec["compliance_mode"]]),
            "qm_news_calendar_bundle_id": manifest["calendar_bundle"]["bundle_id"],
            "qm_news_calendar_expected_sha256": manifest["calendar_bundle"][
                "content_sha256"
            ],
            "qm_news_calendar_common_relative_path": manifest["calendar_bundle"][
                "common_relative_path"
            ],
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "qm_news_stale_max_hours": "336",
        }

        def write_report(values: dict[str, str]) -> None:
            rendered = "".join(f"<b>{key}={value}</b>" for key, value in values.items())
            report.write_text(
                "<html><table><tr><td colspan=\"3\">Inputs:</td>"
                f"<td>{rendered}</td></tr></table></html>",
                encoding="utf-8",
            )

        write_report(effective)
        parsed = runner._validate_report_effective_inputs(
            report,
            spec=spec,
            input_manifest=manifest,
            risk_fixed=1000.0,
        )
        for field in (
            "qm_news_calendar_bundle_id",
            "qm_news_calendar_expected_sha256",
            "qm_news_calendar_common_relative_path",
        ):
            self.assertEqual(parsed[field], effective[field])

        del effective["qm_news_calendar_expected_sha256"]
        write_report(effective)
        with self.assertRaisesRegex(
            runner.RunnerError,
            "effective input qm_news_calendar_expected_sha256 mismatch",
        ):
            runner._validate_report_effective_inputs(
                report,
                spec=spec,
                input_manifest=manifest,
                risk_fixed=1000.0,
            )

    def test_collector_authenticates_artifacts_and_locks_robust_policy(self) -> None:
        plan = self.build()
        self.write_receipts(plan)
        result = runner.collect_run_plan(Path(plan["plan_path"]))
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["adjudication"]["chosen_config"]["temporal_mode"], "PRE30")
        self.assertTrue(Path(result["aggregate_path"]).is_file())
        first_receipt = Path(plan["cells"][0]["receipt_path"])
        original_receipt = first_receipt.read_bytes()
        contradictory = json.loads(original_receipt)
        contradictory["metrics"]["selection"]["sharpe"] += 1.0
        first_receipt.write_bytes(contract.canonical_json_bytes(contradictory))
        with self.assertRaisesRegex(runner.RunnerError, "contradict hashed cell evidence"):
            runner.collect_run_plan(Path(plan["plan_path"]))
        first_receipt.write_bytes(original_receipt)
        first_set = Path(plan["cells"][0]["setfile_path"])
        first_set.write_bytes(first_set.read_bytes() + b"tamper")
        with self.assertRaisesRegex(runner.RunnerError, "setfile.*SHA-256 mismatch"):
            runner.collect_run_plan(Path(plan["plan_path"]))

    def test_status_collector_never_locks_partial_or_tampered_cells(self) -> None:
        partial = self.build(output="partial")
        self.write_receipt(partial["cells"][0])
        partial_result = runner.collect_run_plan_status(Path(partial["plan_path"]))
        self.assertEqual(partial_result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(partial_result["authenticated_cell_count"], 1)
        self.assertEqual(partial_result["missing_cell_count"], 39)
        self.assertEqual(partial_result["adjudication"]["locked_arms"], [])

        tampered = self.build(output="tampered")
        self.write_receipts(tampered)
        first = Path(tampered["cells"][0]["receipt_path"])
        payload = json.loads(first.read_text(encoding="utf-8"))
        payload["effective_seed"] = 999
        first.write_bytes(contract.canonical_json_bytes(payload))
        tampered_result = runner.collect_run_plan_status(Path(tampered["plan_path"]))
        self.assertEqual(tampered_result["verdict"], "INVALID_EVIDENCE")
        self.assertEqual(tampered_result["invalid_cell_count"], 1)
        self.assertEqual(tampered_result["adjudication"]["locked_arms"], [])

    def test_failure_retries_append_and_receipt_precedes_stale_sidecars(self) -> None:
        plan = self.build(output="retry-stable-failure")
        spec = plan["cells"][0]
        cell_dir = Path(spec["receipt_path"]).parent
        first_artifact = cell_dir / "attempt-1.log"
        first_artifact.write_text("first attempt\n", encoding="utf-8")

        first_path = runner._write_cell_failure(
            spec,
            work_item_id="q09-news-1",
            exc=runner.RunnerError("first transient failure"),
        )
        original_bytes = first_path.read_bytes()
        first_payload = json.loads(original_bytes)

        second_artifact = cell_dir / "attempt-2.log"
        second_artifact.write_text("second attempt\n", encoding="utf-8")
        second_path = runner._write_cell_failure(
            spec,
            work_item_id="q09-news-1",
            exc=runner.RunnerError("second transient failure"),
        )
        second_payload = json.loads(second_path.read_text(encoding="utf-8"))

        self.assertEqual(first_path.name, "cell_failure.json")
        self.assertEqual(second_path.name, "cell_failure_2.json")
        self.assertEqual(first_path.read_bytes(), original_bytes)
        self.assertNotEqual(first_payload["error"], second_payload["error"])
        self.assertNotEqual(first_payload["artifacts"], second_payload["artifacts"])
        self.assertFalse(
            any(
                artifact["relative_path"].startswith("cell_failure")
                for artifact in second_payload["artifacts"]
            )
        )
        for field in runner.CELL_FAILURE_STABLE_FIELDS:
            self.assertEqual(first_payload[field], second_payload[field])

        self.write_receipts(plan)
        result = runner.collect_run_plan_status(Path(plan["plan_path"]))
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["authenticated_cell_count"], 40)
        self.assertEqual(result["failed_cell_count"], 0)
        self.assertEqual(first_path.read_bytes(), original_bytes)
        self.assertTrue(second_path.is_file())

    def test_failure_retry_keeps_stable_identity_mismatch_fail_closed(self) -> None:
        plan = self.build(output="failure-identity-mismatch")
        spec = plan["cells"][0]
        first_path = runner._write_cell_failure(
            spec,
            work_item_id="q09-news-1",
            exc=runner.RunnerError("first transient failure"),
        )
        contradictory = json.loads(first_path.read_text(encoding="utf-8"))
        contradictory["seed"] = int(contradictory["seed"]) + 1
        first_path.write_bytes(contract.canonical_json_bytes(contradictory))

        with self.assertRaisesRegex(runner.RunnerError, "cell failure seed mismatch"):
            runner._write_cell_failure(
                spec,
                work_item_id="q09-news-1",
                exc=runner.RunnerError("second transient failure"),
            )
        self.assertFalse(first_path.with_name("cell_failure_2.json").exists())

    def test_failure_snapshot_flattens_deep_source_paths(self) -> None:
        plan = self.build(output="failure-flat-long-path")
        spec = plan["cells"][0]
        cell_dir = Path(spec["receipt_path"]).parent
        relative = Path("runs") / "selection"
        attempt_root = runner._failure_attempt_root(cell_dir, 1)
        while len(str(attempt_root / relative / "artifact.log")) <= 260:
            relative /= "pre_run_logger_archive"
        source = cell_dir / relative / "artifact.log"
        source.parent.mkdir(parents=True)
        source.write_text("long-path failure evidence\n", encoding="utf-8")
        mirrored = runner._failure_attempt_root(cell_dir, 1) / relative / source.name
        self.assertGreater(len(str(mirrored)), 260)

        failure_path = runner._write_cell_failure(
            spec,
            work_item_id="q09-news-1",
            exc=runner.RunnerError("long-path fixture"),
        )
        payload = json.loads(failure_path.read_text(encoding="utf-8"))
        artifact = next(
            row
            for row in payload["artifacts"]
            if row["source_relative_path"] == (relative / source.name).as_posix()
        )
        snapshot_root = runner._failure_attempt_root(cell_dir, 1)
        snapshot_path = Path(artifact["path"])
        self.assertEqual(
            payload["artifact_snapshot_layout"],
            runner.CELL_FAILURE_SNAPSHOT_LAYOUT,
        )
        self.assertEqual(snapshot_path.parent, snapshot_root)
        self.assertLess(len(str(snapshot_path)), len(str(mirrored)))
        self.assertLess(len(str(snapshot_path)), 260)
        self.assertEqual(
            snapshot_path.read_text(encoding="utf-8"),
            "long-path failure evidence\n",
        )
        self.assertIsNotNone(
            runner._authenticated_cell_failure(
                spec,
                work_item_id="q09-news-1",
                failure_path=failure_path,
                expected_failure_sha256=contract.sha256_file(failure_path),
            )
        )

    def test_failure_retry_skips_orphaned_temporary_attempt(self) -> None:
        plan = self.build(output="failure-orphaned-temporary-attempt")
        spec = plan["cells"][0]
        cell_dir = Path(spec["receipt_path"]).parent
        orphan = runner._failure_attempt_root(cell_dir, 1).with_name(
            "attempt_0001.tmp"
        )
        orphan.mkdir(parents=True)
        (orphan / "partial.bin").write_bytes(b"partial")

        failure_path = runner._write_cell_failure(
            spec,
            work_item_id="q09-news-1",
            exc=runner.RunnerError("retry after orphaned snapshot"),
        )
        payload = json.loads(failure_path.read_text(encoding="utf-8"))
        self.assertEqual(failure_path.name, "cell_failure_2.json")
        self.assertEqual(payload["failure_occurrence"], 2)
        self.assertEqual(
            payload["artifact_snapshot_relative_path"],
            "failure_attempts/attempt_0002",
        )
        self.assertTrue(orphan.is_dir())
        self.assertTrue(runner._failure_attempt_root(cell_dir, 2).is_dir())
        self.assertIsNotNone(
            runner._authenticated_cell_failure(
                spec,
                work_item_id="q09-news-1",
                failure_path=failure_path,
                expected_failure_sha256=contract.sha256_file(failure_path),
            )
        )

    def test_failed_cell_authenticates_distinct_attempt_snapshots(self) -> None:
        plan = self.build(output="terminal-attempt-snapshots")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        spec = plan["cells"][0]
        target_id = spec["run_identity_sha256"]
        cell_dir = Path(spec["receipt_path"]).parent
        live_log = cell_dir / "runs" / "selection" / "run_smoke.log"
        attempt_no = 0

        def differing_transient_attempts(inner: dict, _context: dict) -> None:
            # Only the first cell fails; every other cell succeeds so the run
            # ends with the maximal 39-cell authenticated set plus one failed.
            if inner["run_identity_sha256"] != target_id:
                self.write_receipt(inner)
                return
            nonlocal attempt_no
            attempt_no += 1
            live_log.parent.mkdir(parents=True, exist_ok=True)
            live_log.write_text(
                f"attempt {attempt_no} log\n", encoding="utf-8"
            )
            raise runner.TransientCellError(
                f"fixture transient attempt {attempt_no}"
            )

        output_root = self.root / "terminal-attempt-snapshots-output"
        with patch.object(runner, "_wait_for_claimed_terminal_exit"):
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=output_root,
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period=None,
                repo_root=REPO,
                common_root=self.root / "common-terminal-attempt-snapshots",
                dispatch_cell=differing_transient_attempts,
            )

        # First attempt + DEFAULT_CELL_RETRY_BUDGET retries = 3 dispatches.
        self.assertEqual(attempt_no, runner.DEFAULT_CELL_RETRY_BUDGET + 1)
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["adjudication"]["reason_codes"], ["cell_execution_failed"])
        self.assertEqual(result["authenticated_cell_count"], 39)
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 0)
        self.assertTrue(result["accounting_reconciled"])
        first_path = cell_dir / "cell_failure.json"
        second_path = cell_dir / "cell_failure_2.json"
        first = json.loads(first_path.read_text(encoding="utf-8"))
        second = json.loads(second_path.read_text(encoding="utf-8"))

        def snapshotted_log(payload: dict) -> Path:
            artifact = next(
                row
                for row in payload["artifacts"]
                if row["source_relative_path"]
                == "runs/selection/run_smoke.log"
            )
            return Path(artifact["path"])

        first_log = snapshotted_log(first)
        second_log = snapshotted_log(second)
        self.assertNotEqual(first_log, second_log)
        self.assertEqual(first_log.read_text(encoding="utf-8"), "attempt 1 log\n")
        self.assertEqual(second_log.read_text(encoding="utf-8"), "attempt 2 log\n")
        self.assertIn("failure_attempts/attempt_0001", first_log.as_posix())
        self.assertIn("failure_attempts/attempt_0002", second_log.as_posix())

        # No single-cell execution_failure pointer is written any more; the
        # aggregate authenticates the base cell_failure sidecar directly.
        self.assertNotIn("execution_failure_path", result)
        self.assertFalse((output_root / "execution_failure.json").exists())
        self.assertEqual(
            result["adjudication"]["details"]["failed_cells"][0]["failure_path"],
            str(first_path),
        )

        for sidecar_path in (first_path, second_path):
            authenticated = runner._authenticated_cell_failure(
                spec,
                work_item_id="q09-news-1",
                failure_path=sidecar_path,
                expected_failure_sha256=contract.sha256_file(sidecar_path),
            )
            self.assertIsNotNone(authenticated)

        # The live log can change again without invalidating the recorded
        # occurrences (their evidence lives in the immutable attempt snapshots).
        live_log.write_text("attempt 3 live mutation\n", encoding="utf-8")
        recollected = runner.collect_run_plan_status(
            Path(plan["plan_path"]), output_root=output_root
        )
        self.assertEqual(recollected["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(
            recollected["adjudication"]["details"]["failed_cells"][0][
                "failure_path"
            ],
            str(first_path),
        )

        # Tampering the authenticated occurrence-1 snapshot fails closed under
        # the accurate failure-manifest reason rather than the receipt reason.
        first_log.write_text("tampered snapshot\n", encoding="utf-8")
        invalid = runner.collect_run_plan_status(
            Path(plan["plan_path"]), output_root=output_root
        )
        self.assertEqual(invalid["verdict"], "INVALID_EVIDENCE")
        self.assertEqual(
            invalid["adjudication"]["reason_codes"],
            ["cell_failure_manifest_invalid"],
        )
        self.assertEqual(invalid["invalid_cell_count"], 1)

    def test_claimed_terminal_wait_blocks_until_only_that_terminal_exits(self) -> None:
        terminal_root = self.root / "mt5" / "T1"
        terminal_root.mkdir(parents=True)
        snapshots = [
            [
                {
                    "ProcessId": 101,
                    "ExecutablePath": str(terminal_root / "terminal64.exe"),
                },
                {
                    "ProcessId": 202,
                    "ExecutablePath": str(
                        terminal_root.parent / "T2" / "terminal64.exe"
                    ),
                },
                {
                    "ProcessId": 303,
                    "ExecutablePath": str(
                        terminal_root.parent / "T_Live" / "terminal64.exe"
                    ),
                },
                {
                    "ProcessId": 404,
                    "ExecutablePath": str(
                        self.root / "FTMO Global Markets MT5 Terminal" / "terminal64.exe"
                    ),
                },
            ],
            [
                {
                    "ProcessId": 202,
                    "ExecutablePath": str(
                        terminal_root.parent / "T2" / "terminal64.exe"
                    ),
                },
                {
                    "ProcessId": 303,
                    "ExecutablePath": str(
                        terminal_root.parent / "T_Live" / "terminal64.exe"
                    ),
                },
            ],
        ]
        now = [0.0]
        sleeps: list[float] = []

        def scan() -> list[dict]:
            return snapshots.pop(0)

        def sleep(seconds: float) -> None:
            sleeps.append(seconds)
            now[0] += seconds

        runner._wait_for_claimed_terminal_exit(
            terminal_root,
            process_scan=scan,
            monotonic=lambda: now[0],
            sleeper=sleep,
        )

        self.assertEqual(sleeps, [runner.TERMINAL_EXIT_POLL_SEC])
        self.assertEqual(snapshots, [])

    def test_claimed_terminal_wait_is_bounded_when_process_never_exits(self) -> None:
        terminal_root = self.root / "mt5" / "T1"
        process = {
            "ProcessId": 101,
            "ExecutablePath": str(terminal_root / "terminal64.exe"),
        }
        now = [0.0]
        sleeps: list[float] = []

        def sleep(seconds: float) -> None:
            sleeps.append(seconds)
            now[0] += seconds

        with self.assertRaisesRegex(
            runner.RunnerError,
            "claimed-terminal exit wait timed out after 5s.*101",
        ):
            runner._wait_for_claimed_terminal_exit(
                terminal_root,
                timeout_sec=5,
                poll_sec=2,
                process_scan=lambda: [process],
                monotonic=lambda: now[0],
                sleeper=sleep,
            )

        self.assertEqual(sleeps, [2.0, 2.0, 1.0])
        self.assertEqual(sum(sleeps), 5.0)

    def test_terminal_wait_timeout_fails_cell_closed_without_spawning_smoke(self) -> None:
        plan = self.build(output="terminal-wait-timeout")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)

        with (
            patch.object(
                runner,
                "_wait_for_claimed_terminal_exit",
                side_effect=runner.RunnerError(
                    "Q09 claimed-terminal exit wait timed out after 180s for T1"
                ),
            ),
            patch.object(runner.subprocess, "run") as smoke_run,
        ):
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "terminal-wait-timeout-output",
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period=None,
                repo_root=REPO,
                common_root=self.root / "common-terminal-wait-timeout",
            )

        smoke_run.assert_not_called()
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        # A claimed-terminal exit-wait timeout is a non-transient tester error
        # that recurs for every cell.  Under continue-on-failure it records each
        # cell as failed rather than aborting the run, and never spawns smoke.
        self.assertEqual(result["failed_cell_count"], 40)
        self.assertEqual(result["missing_cell_count"], 0)
        self.assertTrue(result["accounting_reconciled"])
        failure = json.loads(
            Path(result["adjudication"]["details"]["failed_cells"][0]["failure_path"])
            .read_text(encoding="utf-8")
        )
        self.assertEqual(failure["schema_version"], runner.CELL_FAILURE_SCHEMA)
        self.assertIn("claimed-terminal exit wait timed out", failure["error"])

    def test_one_nontransient_cell_fails_while_the_rest_authenticate(self) -> None:
        plan = self.build(output="failed-cell")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        target_id = plan["cells"][0]["run_identity_sha256"]
        dispatched: list[str] = []

        def fail_first_cell(spec: dict, _context: dict) -> None:
            dispatched.append(spec["run_identity_sha256"])
            if spec["run_identity_sha256"] == target_id:
                raise runner.RunnerError(
                    f"fixture tester failure for {spec['run_identity_sha256']}"
                )
            self.write_receipt(spec)

        result = runner.execute_run_plan(
            Path(plan["plan_path"]),
            output_root=self.root / "failed-cell-output",
            farm_root=farm_root,
            work_item_id="q09-news-1",
            terminal="T1",
            expected_plan_file_sha256=plan_hash,
            ea_id=9999,
            expert="QM5_9999_demo",
            symbol="EURUSD.DWX",
            work_item_symbol="EURUSD.DWX",
            period=None,
            repo_root=REPO,
            common_root=self.root / "common-failed-cell",
            dispatch_cell=fail_first_cell,
        )
        # A non-transient failure is not retried, and the run continues through
        # all remaining planned cells instead of aborting at the first failure.
        self.assertEqual(dispatched.count(target_id), 1)
        self.assertEqual(len(dispatched), 40)
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["adjudication"]["reason_codes"], ["cell_execution_failed"])
        self.assertEqual(result["authenticated_cell_count"], 39)
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 0)
        self.assertTrue(result["accounting_reconciled"])
        failed = result["adjudication"]["details"]["failed_cells"]
        self.assertEqual(len(failed), 1)
        self.assertIn("fixture tester failure", failed[0]["error"])
        failure_path = Path(failed[0]["failure_path"])
        self.assertTrue(failure_path.is_file())
        self.assertEqual(contract.sha256_file(failure_path), failed[0]["failure_sha256"])
        # No aborting single-cell execution_failure pointer is written.
        self.assertNotIn("execution_failure_path", result)
        self.assertFalse((self.root / "failed-cell-output" / "execution_failure.json").exists())

    def test_transient_cell_retry_succeeds_inside_same_attempt(self) -> None:
        plan = self.build(output="transient-retry-succeeds")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        dispatch_count = 0

        def transient_then_success(spec: dict, _context: dict) -> None:
            nonlocal dispatch_count
            dispatch_count += 1
            if dispatch_count == 1:
                raise runner.TransientCellError("fixture child exit 1 without receipt")
            self.write_receipt(spec)

        with patch.object(runner, "_wait_for_claimed_terminal_exit") as wait_for_exit:
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "transient-retry-succeeds-output",
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period=None,
                repo_root=REPO,
                common_root=self.root / "common-transient-retry-succeeds",
                dispatch_cell=transient_then_success,
            )

        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["authenticated_cell_count"], 40)
        self.assertEqual(dispatch_count, 41)
        wait_for_exit.assert_called_once()
        first_cell = Path(plan["cells"][0]["receipt_path"]).parent
        self.assertTrue((first_cell / "cell_failure.json").is_file())
        self.assertTrue((first_cell / "cell_receipt.json").is_file())

    def test_all_transient_cells_recorded_failed_without_requeue(self) -> None:
        # The retained ceiling still mirrors the worker's retry budget even
        # though the executor no longer requeues the whole item for one cell.
        self.assertEqual(
            runner.WORK_ITEM_ATTEMPT_CEILING,
            terminal_worker.MAX_WORK_ITEM_RETRIES,
        )
        plan = self.build(output="transient-all-failed")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        dispatch_count = 0

        def always_transient(_spec: dict, _context: dict) -> None:
            nonlocal dispatch_count
            dispatch_count += 1
            raise runner.TransientCellError("fixture child exit 1 without receipt")

        with patch.object(runner, "_wait_for_claimed_terminal_exit"):
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "transient-all-failed-output",
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period=None,
                repo_root=REPO,
                common_root=self.root / "common-transient-all-failed",
                dispatch_cell=always_transient,
            )

        # A wholesale transient wedge no longer raises/requeues: every cell is
        # retried within its bounded budget, recorded as failed, and the run
        # produces a fail-closed aggregate with exact accounting.
        self.assertEqual(dispatch_count, 40 * (runner.DEFAULT_CELL_RETRY_BUDGET + 1))
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["adjudication"]["reason_codes"], ["cell_execution_failed"])
        self.assertEqual(result["authenticated_cell_count"], 0)
        self.assertEqual(result["failed_cell_count"], 40)
        self.assertEqual(result["missing_cell_count"], 0)
        self.assertTrue(result["accounting_reconciled"])
        self.assertTrue(Path(result["aggregate_path"]).is_file())
        first_cell = Path(plan["cells"][0]["receipt_path"]).parent
        self.assertTrue((first_cell / "cell_failure.json").is_file())
        self.assertTrue((first_cell / "cell_failure_2.json").is_file())
        self.assertFalse((first_cell / "cell_receipt.json").exists())

    def test_single_transient_cell_exhausts_budget_then_run_continues(self) -> None:
        # Requirement test (i): one cell fails K+1 times -> the run continues,
        # the aggregate counts 39 authenticated + 1 failed, and the verdict path
        # is unchanged (fail-closed REVIEW_REQUIRED / cell_execution_failed).
        plan = self.build(output="transient-single-budget")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        target_id = plan["cells"][0]["run_identity_sha256"]
        target_dispatches = 0

        def fail_first_transiently(spec: dict, _context: dict) -> None:
            nonlocal target_dispatches
            if spec["run_identity_sha256"] == target_id:
                target_dispatches += 1
                raise runner.TransientCellError(
                    "fixture child exit 1 without receipt"
                )
            self.write_receipt(spec)

        with patch.object(runner, "_wait_for_claimed_terminal_exit") as wait_for_exit:
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "transient-single-budget-output",
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period=None,
                repo_root=REPO,
                common_root=self.root / "common-transient-single-budget",
                dispatch_cell=fail_first_transiently,
            )

        # First attempt + K retries, and one terminal-exit wait per retry.
        self.assertEqual(target_dispatches, runner.DEFAULT_CELL_RETRY_BUDGET + 1)
        self.assertEqual(wait_for_exit.call_count, runner.DEFAULT_CELL_RETRY_BUDGET)
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["adjudication"]["reason_codes"], ["cell_execution_failed"])
        self.assertEqual(result["authenticated_cell_count"], 39)
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 0)
        self.assertTrue(result["accounting_reconciled"])
        first_cell = Path(plan["cells"][0]["receipt_path"]).parent
        self.assertTrue((first_cell / "cell_failure.json").is_file())
        self.assertTrue((first_cell / "cell_failure_2.json").is_file())
        self.assertTrue((first_cell / "cell_failure_3.json").is_file())
        self.assertFalse((first_cell / "cell_receipt.json").exists())
        self.assertTrue(Path(result["aggregate_path"]).is_file())

    def test_collect_status_reconciles_mixed_partial_buckets(self) -> None:
        # Requirement test (iii): partial collection reconciles every planned
        # cell into exactly one bucket (authenticated | failed | missing |
        # invalid), covering the matrix-scope accounting and the fail-closed
        # cell_receipt_invalid path.
        plan = self.build(output="mixed-buckets")
        cells = plan["cells"]
        self.assertEqual(len(cells), 40)
        for spec in cells[:37]:
            self.write_receipt(spec)
        # One authentic failed cell recorded as an immutable failure sidecar.
        runner._write_cell_failure(
            cells[37],
            work_item_id="q09-news-1",
            exc=runner.TransientCellError("fixture failed cell"),
        )
        # One present-but-contradictory receipt (fails closed as invalid).
        Path(cells[38]["receipt_path"]).write_bytes(
            contract.canonical_json_bytes({"schema_version": "bogus"})
        )
        # cells[39] is left untouched -> missing.
        result = runner.collect_run_plan_status(Path(plan["plan_path"]))

        self.assertEqual(result["planned_cell_count"], 40)
        self.assertEqual(result["authenticated_cell_count"], 37)
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 1)
        self.assertEqual(result["invalid_cell_count"], 1)
        self.assertEqual(result["accounted_cell_count"], 40)
        self.assertTrue(result["accounting_reconciled"])
        self.assertEqual(result["verdict"], "INVALID_EVIDENCE")
        self.assertEqual(
            result["adjudication"]["reason_codes"], ["cell_receipt_invalid"]
        )

        # Removing only the invalid receipt leaves a clean partial run: the
        # remaining failed + missing cells still reconcile and fail closed to
        # REVIEW_REQUIRED rather than locking a config on incomplete evidence.
        Path(cells[38]["receipt_path"]).unlink()
        self.write_receipt(cells[38])
        cleaned = runner.collect_run_plan_status(Path(plan["plan_path"]))
        self.assertEqual(cleaned["authenticated_cell_count"], 38)
        self.assertEqual(cleaned["failed_cell_count"], 1)
        self.assertEqual(cleaned["missing_cell_count"], 1)
        self.assertEqual(cleaned["invalid_cell_count"], 0)
        self.assertEqual(cleaned["accounted_cell_count"], 40)
        self.assertTrue(cleaned["accounting_reconciled"])
        self.assertEqual(cleaned["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(
            cleaned["adjudication"]["reason_codes"], ["cell_execution_failed"]
        )

    def test_production_multi_cell_execute_writes_receipts_and_collects(self) -> None:
        plan = self.build(output="production-multi-cell")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        commands: list[list[str]] = []

        def fake_run(command: list[str], **_kwargs: object) -> SimpleNamespace:
            commands.append(command)
            self.assertIn("-RequireFreshLoggerSample", command)
            self.assertEqual(
                command[command.index("-ExpectedExpertSha256") + 1],
                contract.sha256_file(self.ex5),
            )
            self.assertIn("-SmokeMode", command)
            self.assertEqual(command[command.index("-MinTrades") + 1], "0")
            report_root = Path(command[command.index("-ReportRoot") + 1])
            summary = report_root / "QM5_9999" / "fixture" / "summary.json"
            summary.parent.mkdir(parents=True, exist_ok=True)
            summary.write_text("{}\n", encoding="utf-8")
            return SimpleNamespace(returncode=0, stdout="fixture PASS\n", stderr="")

        def fake_validate(summary_path: Path, **kwargs: object) -> tuple[dict, dict]:
            spec = kwargs["spec"]
            self.assertIsInstance(spec, dict)
            window = next(name for name in runner.WINDOW_NAMES if name in summary_path.parts)
            seed_index = contract.SEEDS.index(spec["seed"])
            selection = 0.50 + seed_index * 0.01
            holdout = 0.40 + seed_index * 0.01
            values = {
                "selection": selection,
                "holdout": holdout,
                "full": (selection + holdout) / 2,
            }
            delta = (
                0.10
                if spec["arm"] == "POLICY_ON" and spec["temporal_mode"] == "PRE30"
                else 0.0
            )
            return metrics(values[window] + delta), {
                "cost_execution_identity_sha256": "c" * 64,
            }

        with (
            patch.object(runner.subprocess, "run", side_effect=fake_run),
            patch.object(runner, "_wait_for_claimed_terminal_exit") as wait_for_exit,
            patch.object(runner, "_validate_window_summary", side_effect=fake_validate),
        ):
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "production-multi-cell-output",
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period=None,
                repo_root=REPO,
                common_root=self.root / "common-production-multi-cell",
            )
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["authenticated_cell_count"], 40)
        self.assertEqual(len(commands), 40 * len(runner.WINDOW_NAMES))
        self.assertEqual(wait_for_exit.call_count, 40 * len(runner.WINDOW_NAMES))
        self.assertTrue(all("-AllowRunningTerminal" not in command for command in commands))
        self.assertEqual(
            len(list((self.root / "production-multi-cell").rglob("cell_receipt.json"))),
            40,
        )

    def _drive_one_failing_cell_through_fork(
        self,
        *,
        output: str,
        reason_classes: list[str],
    ) -> tuple[dict, dict, Path]:
        """Run execute_run_plan through the REAL _production_dispatch_cell fork.

        The first plan cell's ``selection`` window exits 1 with a fresh FAIL
        summary carrying ``reason_classes``; every other window/cell exits 0
        with a valid summary.  Returns (result, call_counts, target_cell_dir).
        """

        plan = self.build(output=output)
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        target_cell_dir = Path(plan["cells"][0]["receipt_path"]).parent.resolve()
        counts = {"target_selection": 0, "total": 0}

        def fake_run(command: list[str], **_kwargs: object) -> SimpleNamespace:
            counts["total"] += 1
            report_root = Path(command[command.index("-ReportRoot") + 1])
            window = report_root.name
            cell_dir = report_root.parent.parent.resolve()
            summary = report_root / "QM5_9999" / "fixture" / "summary.json"
            summary.parent.mkdir(parents=True, exist_ok=True)
            if cell_dir == target_cell_dir and window == "selection":
                counts["target_selection"] += 1
                summary.write_text(
                    json.dumps(
                        {
                            "evidence_schema": "run_smoke/v2",
                            "result": "FAIL",
                            "reason_classes": list(reason_classes),
                        }
                    )
                    + "\n",
                    encoding="utf-8",
                )
                return SimpleNamespace(returncode=1, stdout="fixture FAIL\n", stderr="")
            summary.write_text("{}\n", encoding="utf-8")
            return SimpleNamespace(returncode=0, stdout="fixture PASS\n", stderr="")

        def fake_validate(summary_path: Path, **kwargs: object) -> tuple[dict, dict]:
            spec = kwargs["spec"]
            window = next(
                name for name in runner.WINDOW_NAMES if name in summary_path.parts
            )
            seed_index = contract.SEEDS.index(spec["seed"])
            selection = 0.50 + seed_index * 0.01
            holdout = 0.40 + seed_index * 0.01
            values = {
                "selection": selection,
                "holdout": holdout,
                "full": (selection + holdout) / 2,
            }
            delta = (
                0.10
                if spec["arm"] == "POLICY_ON" and spec["temporal_mode"] == "PRE30"
                else 0.0
            )
            return metrics(values[window] + delta), {
                "cost_execution_identity_sha256": "c" * 64,
            }

        with (
            patch.object(runner.subprocess, "run", side_effect=fake_run),
            patch.object(runner, "_wait_for_claimed_terminal_exit"),
            patch.object(runner, "_validate_window_summary", side_effect=fake_validate),
        ):
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / f"{output}-output",
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period=None,
                repo_root=REPO,
                common_root=self.root / f"common-{output}",
            )
        return result, counts, target_cell_dir

    def test_transient_reason_class_fail_summary_routes_to_retry_lane(self) -> None:
        # Requirement (i): a child exit-1 WITH a fresh FAIL summary whose reason
        # classes are all transient (TIMEOUT) is reclassified into the bounded
        # per-cell retry lane -- the selection window is re-dispatched
        # budget+1 times before the cell is recorded as failed.
        result, counts, target_cell_dir = self._drive_one_failing_cell_through_fork(
            output="fork-transient-timeout",
            reason_classes=["TIMEOUT"],
        )
        self.assertEqual(
            counts["target_selection"], runner.DEFAULT_CELL_RETRY_BUDGET + 1
        )
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(
            result["adjudication"]["reason_codes"], ["cell_execution_failed"]
        )
        self.assertEqual(result["authenticated_cell_count"], 39)
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 0)
        self.assertTrue(result["accounting_reconciled"])
        failure = result["adjudication"]["details"]["failed_cells"][0]
        self.assertEqual(failure["error_type"], "TransientCellError")
        self.assertIn("run_smoke FAIL is transient", failure["error"])
        self.assertIn("TIMEOUT", failure["error"])
        # The retry lane records a distinct immutable sidecar per occurrence.
        self.assertTrue((target_cell_dir / "cell_failure.json").is_file())
        self.assertTrue((target_cell_dir / "cell_failure_2.json").is_file())

    def test_unknown_reason_class_fail_summary_is_not_retried(self) -> None:
        # Requirement (ii): a child exit-1 WITH a fresh FAIL summary whose reason
        # class is genuine (MIN_TRADES_NOT_MET, i.e. real zero/low-signal) is NOT
        # transient: it is recorded-and-continued with NO retry, and the run
        # still completes every remaining planned cell.
        result, counts, target_cell_dir = self._drive_one_failing_cell_through_fork(
            output="fork-nontransient-mintrades",
            reason_classes=["MIN_TRADES_NOT_MET"],
        )
        self.assertEqual(counts["target_selection"], 1)
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(
            result["adjudication"]["reason_codes"], ["cell_execution_failed"]
        )
        self.assertEqual(result["authenticated_cell_count"], 39)
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 0)
        self.assertTrue(result["accounting_reconciled"])
        failure = result["adjudication"]["details"]["failed_cells"][0]
        self.assertEqual(failure["error_type"], "RunnerError")
        self.assertIn("exited with code 1", failure["error"])
        self.assertIn("MIN_TRADES_NOT_MET", failure["error"])
        # No retry: exactly one immutable failure sidecar, no occurrence 2.
        self.assertTrue((target_cell_dir / "cell_failure.json").is_file())
        self.assertFalse((target_cell_dir / "cell_failure_2.json").exists())

    def test_mixed_reason_classes_with_one_unknown_is_not_retried(self) -> None:
        # A FAIL summary that mixes a transient class with a genuine one is NOT
        # all-transient, so it must stay in the non-retried RunnerError lane.
        result, counts, _ = self._drive_one_failing_cell_through_fork(
            output="fork-mixed-reason",
            reason_classes=["TIMEOUT", "NON_DETERMINISTIC"],
        )
        self.assertEqual(counts["target_selection"], 1)
        failure = result["adjudication"]["details"]["failed_cells"][0]
        self.assertEqual(failure["error_type"], "RunnerError")

    def test_failure_snapshot_copies_log_artifact_byte_true_and_purge_safe(
        self,
    ) -> None:
        # Requirement (iii): a .log run-log listed in the failure manifest is
        # copied into the immutable attempt snapshot byte-for-byte, and the copy
        # is renamed to a non-.log suffix so the ops `*.log` retention sweep
        # (reports_log_purge.ps1) cannot delete the evidence (root cause of the
        # cba63d44 pilot's gutted attempt_0001).
        plan = self.build(output="failure-log-snapshot")
        spec = plan["cells"][0]
        cell_dir = Path(spec["receipt_path"]).parent
        run_root = cell_dir / "runs" / "selection"
        run_root.mkdir(parents=True, exist_ok=True)
        # A large-ish binary-ish payload so the assertion is meaningfully byte-true.
        log_bytes = b"line-0\n" + bytes(range(256)) * 4096 + b"\ntail\n"
        (run_root / "run_smoke.log").write_bytes(log_bytes)

        failure_path = runner._write_cell_failure(
            spec,
            work_item_id="q09-news-1",
            exc=runner.RunnerError("fixture .log snapshot"),
        )
        payload = json.loads(failure_path.read_text(encoding="utf-8"))
        self.assertEqual(
            payload["artifact_snapshot_layout"],
            runner.CELL_FAILURE_SNAPSHOT_LAYOUT_V2,
        )
        artifact = next(
            row
            for row in payload["artifacts"]
            if row["source_relative_path"] == "runs/selection/run_smoke.log"
        )
        snapshot_path = Path(artifact["path"])
        # Byte-true copy of the source log.
        self.assertTrue(snapshot_path.is_file())
        self.assertEqual(snapshot_path.read_bytes(), log_bytes)
        self.assertEqual(artifact["size_bytes"], len(log_bytes))
        self.assertEqual(artifact["sha256"], contract.sha256_file(snapshot_path))
        # Purge-safe: the immutable copy must NOT carry a `*.log`-swept name.
        self.assertFalse(snapshot_path.name.endswith(".log"))
        self.assertTrue(snapshot_path.name.endswith(".evidence"))
        # And it still authenticates end-to-end.
        self.assertIsNotNone(
            runner._authenticated_cell_failure(
                spec,
                work_item_id="q09-news-1",
                failure_path=failure_path,
                expected_failure_sha256=contract.sha256_file(failure_path),
            )
        )

    def test_plan_binding_refuses_file_hash_drift(self) -> None:
        plan = self.build(output="binding-drift")
        farm_root, _ = self.setup_bound_farm(plan, activate=False)
        # A second bind with a false exact-file identity must fail before any
        # payload mutation, even though the plan's internal logical hash is valid.
        with self.assertRaisesRegex(runner.RunnerError, "run-plan artifact SHA-256 mismatch"):
            runner.bind_plan_to_work_item(
                farm_root,
                work_item_id="q09-news-1",
                plan_path=Path(plan["plan_path"]),
                expected_plan_file_sha256="0" * 64,
                cell_timeout_sec=60,
            )

    def test_executor_refuses_without_active_factory_capacity(self) -> None:
        plan = self.build(output="capacity")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=False)
        with self.assertRaisesRegex(runner.CapacityError, "active terminal claim"):
            runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "capacity-output",
                farm_root=farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                expected_plan_file_sha256=plan_hash,
                ea_id=9999,
                expert="QM5_9999_demo",
                symbol="EURUSD.DWX",
                work_item_symbol="EURUSD.DWX",
                period="H1",
                repo_root=REPO,
                common_root=self.root / "common-capacity",
                dispatch_cell=lambda *_: self.fail("capacity refusal dispatched a cell"),
            )

    def test_end_to_end_bound_dispatch_collect_and_sidecar_config_lock(self) -> None:
        plan = self.build(output="end-to-end")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)

        def fixture_dispatch(spec: dict, context: dict) -> None:
            self.assertEqual(context["period"], "H1")
            self.write_receipt(spec)

        result = runner.execute_run_plan(
            Path(plan["plan_path"]),
            output_root=self.root / "end-to-end-output",
            farm_root=farm_root,
            work_item_id="q09-news-1",
            terminal="T1",
            expected_plan_file_sha256=plan_hash,
            ea_id=9999,
            expert="QM5_9999_demo",
            symbol="EURUSD.DWX",
            work_item_symbol="EURUSD.DWX",
            period=None,
            repo_root=REPO,
            common_root=self.root / "common-end-to-end",
            dispatch_cell=fixture_dispatch,
        )
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["authenticated_cell_count"], 40)
        self.assertEqual(result["sidecar"]["status"], "RECORDED")
        resumed = runner._persist_q09_result(
            farm_root,
            work_item_id="q09-news-1",
            terminal="T1",
            plan_path=Path(plan["plan_path"]),
            expected_plan_file_sha256=plan_hash,
            result=result,
        )
        self.assertEqual(resumed["status"], "ALREADY_RECORDED")
        with closing(farmctl.connect(farm_root)) as connection:
            test = connection.execute(
                "SELECT verdict,aggregate_sha256 FROM q09_news_tests WHERE work_item_id='q09-news-1'"
            ).fetchone()
            self.assertEqual(test["verdict"], "CONFIG_LOCKED")
            self.assertEqual(test["aggregate_sha256"], result["aggregate_sha256"])
            self.assertEqual(
                connection.execute(
                    "SELECT count(*) FROM q09_news_cells WHERE q09_news_work_item_id='q09-news-1'"
                ).fetchone()[0],
                40,
            )
            self.assertEqual(
                connection.execute(
                    "SELECT count(*) FROM q09_news_arms WHERE q09_news_work_item_id='q09-news-1'"
                ).fetchone()[0],
                2,
            )
            self.assertEqual(
                connection.execute(
                    "SELECT count(*) FROM q09_news_cell_occurrences"
                ).fetchone()[0],
                40,
            )

    def test_cross_round_resume_records_new_provenance_without_rewriting_cells(self) -> None:
        plan = self.build(output="resume-prior-cells")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        self.write_receipts(plan)
        result = runner.collect_run_plan_status(
            Path(plan["plan_path"]),
            output_root=self.root / "resume-prior-output",
            expected_plan_file_sha256=plan_hash,
        )
        evidence = json.loads(Path(result["evidence_path"]).read_text(encoding="utf-8"))
        adjudication = json.loads(
            Path(result["aggregate_path"]).read_text(encoding="utf-8")
        )
        prior_evidence = dict(evidence)
        prior_evidence["work_item_id"] = "q09-news-prior"
        prior_cells = []
        for cell in evidence["cells"][:5]:
            prior = dict(cell)
            run_identity = prior["run_identity_sha256"]
            prior["evidence_sha256"] = contract.sha256_bytes(
                f"prior-evidence:{run_identity}".encode("utf-8")
            )
            prior["report_sha256"] = contract.sha256_bytes(
                f"prior-report:{run_identity}".encode("utf-8")
            )
            prior["evidence_path"] = f"D:/prior/{run_identity}/summary.json"
            prior["report_path"] = f"D:/prior/{run_identity}/report.htm"
            prior_cells.append(prior)
        prior_evidence["cells"] = prior_cells
        shared_identity = prior_cells[0]["run_identity_sha256"]

        with closing(farmctl.connect(farm_root)) as connection:
            connection.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,
                    payload_json,created_at,updated_at
                )
                SELECT 'q09-news-prior',kind,phase,ea_id,symbol,setfile_path,
                       'done','REVIEW_REQUIRED',0,NULL,NULL,NULL,'{}',created_at,updated_at
                FROM work_items WHERE id='q09-news-1'
                """
            )
            schema.add_dependency(
                connection,
                child_work_item_id="q09-news-prior",
                dependency_role="Q08_INPUT",
                parent_work_item_id="q08-1",
                parent_evidence_sha256=contract.sha256_file(self.q08),
                required_verdicts=["PASS"],
            )
            connection.commit()
            schema.record_q09_adjudication(
                connection,
                evidence_payload=prior_evidence,
                adjudication=adjudication,
                aggregate_path=result["aggregate_path"],
                aggregate_sha256=result["aggregate_sha256"],
            )

        resumed = runner._persist_q09_result(
            farm_root,
            work_item_id="q09-news-1",
            terminal="T1",
            plan_path=Path(plan["plan_path"]),
            expected_plan_file_sha256=plan_hash,
            result=result,
        )
        self.assertEqual(resumed["status"], "RECORDED")
        with closing(farmctl.connect(farm_root)) as connection:
            self.assertEqual(
                connection.execute("SELECT count(*) FROM q09_news_cells").fetchone()[0],
                40,
            )
            self.assertEqual(
                connection.execute(
                    """
                    SELECT count(*) FROM q09_news_cells
                    WHERE q09_news_work_item_id='q09-news-prior'
                    """
                ).fetchone()[0],
                5,
            )
            self.assertEqual(
                connection.execute(
                    """
                    SELECT count(*) FROM q09_news_cells
                    WHERE q09_news_work_item_id='q09-news-1'
                    """
                ).fetchone()[0],
                35,
            )
            self.assertEqual(
                connection.execute(
                    """
                    SELECT count(*) FROM q09_news_cells_by_work_item
                    WHERE q09_news_work_item_id='q09-news-1'
                    """
                ).fetchone()[0],
                40,
            )
            self.assertEqual(
                connection.execute(
                    "SELECT count(*) FROM q09_news_cell_occurrences"
                ).fetchone()[0],
                45,
            )
            canonical = connection.execute(
                """
                SELECT evidence_sha256,report_sha256 FROM q09_news_cells
                WHERE run_identity_sha256=?
                """,
                (shared_identity,),
            ).fetchone()
            self.assertEqual(canonical["evidence_sha256"], prior_cells[0]["evidence_sha256"])
            occurrences = connection.execute(
                """
                SELECT q09_news_work_item_id,evidence_sha256,report_sha256,
                       evidence_path,report_path
                FROM q09_news_cell_occurrences
                WHERE run_identity_sha256=?
                ORDER BY q09_news_work_item_id
                """,
                (shared_identity,),
            ).fetchall()
            self.assertEqual(len(occurrences), 2)
            current = next(
                row for row in occurrences if row["q09_news_work_item_id"] == "q09-news-1"
            )
            current_cell = next(
                cell for cell in evidence["cells"]
                if cell["run_identity_sha256"] == shared_identity
            )
            self.assertEqual(current["evidence_sha256"], current_cell["evidence_sha256"])
            self.assertEqual(current["report_sha256"], current_cell["report_sha256"])
            self.assertEqual(current["evidence_path"], current_cell["evidence_path"])
            self.assertEqual(current["report_path"], current_cell["report_path"])

    def test_persistence_resume_fails_closed_on_divergent_cell_content(self) -> None:
        plan = self.build(output="resume-divergence")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        self.write_receipts(plan)
        result = runner.collect_run_plan_status(
            Path(plan["plan_path"]),
            output_root=self.root / "resume-divergence-output",
            expected_plan_file_sha256=plan_hash,
        )
        evidence = json.loads(Path(result["evidence_path"]).read_text(encoding="utf-8"))
        adjudication = json.loads(
            Path(result["aggregate_path"]).read_text(encoding="utf-8")
        )
        partial_evidence = dict(evidence)
        divergent_cell = dict(evidence["cells"][0])
        divergent_selection = dict(divergent_cell["selection"])
        divergent_selection["trades"] += 1
        divergent_cell["selection"] = divergent_selection
        partial_evidence["cells"] = [divergent_cell]
        run_identity = divergent_cell["run_identity_sha256"]

        with closing(farmctl.connect(farm_root)) as connection:
            schema.record_q09_adjudication(
                connection,
                evidence_payload=partial_evidence,
                adjudication=adjudication,
                aggregate_path=result["aggregate_path"],
                aggregate_sha256=result["aggregate_sha256"],
            )

        with self.assertRaises(schema.SchemaError) as raised:
            runner._persist_q09_result(
                farm_root,
                work_item_id="q09-news-1",
                terminal="T1",
                plan_path=Path(plan["plan_path"]),
                expected_plan_file_sha256=plan_hash,
                result=result,
            )
        report = str(raised.exception)
        self.assertIn("Q09 persistence divergence", report)
        self.assertIn(run_identity, report)
        self.assertIn("selection_metrics_json", report)
        with closing(farmctl.connect(farm_root)) as connection:
            self.assertEqual(
                connection.execute("SELECT count(*) FROM q09_news_cells").fetchone()[0],
                1,
            )

    def test_executor_refuses_period_that_contradicts_sealed_q08(self) -> None:
        plan = self.build(output="period-contradiction")
        _, manifest = runner.load_authenticated_plan(Path(plan["plan_path"]))
        self.assertEqual(runner.resolve_execution_period(manifest, None), "H1")
        self.assertEqual(runner.resolve_execution_period(manifest, "h1"), "H1")
        with self.assertRaisesRegex(
            runner.RunnerError,
            "--period M15 contradicts sealed Q09 period H1",
        ):
            runner.resolve_execution_period(manifest, "M15")


if __name__ == "__main__":
    unittest.main()
