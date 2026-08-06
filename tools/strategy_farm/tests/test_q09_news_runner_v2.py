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
    ) -> tuple[Path, str]:
        farm_root = self.root / "farm"
        farmctl.init_db(farm_root)
        q07_evidence = self.root / "q07.json"
        q07_evidence.write_text('{"verdict":"MULTI_SEED_PASS"}\n', encoding="utf-8")
        now = "2026-08-02T00:00:00+00:00"
        with closing(farmctl.connect(farm_root)) as connection:
            for values in (
                (
                    "q07-1", "Q07", "done", "MULTI_SEED_PASS",
                    str(q07_evidence), "{}",
                ),
                (
                    "q08-1", "Q08", "done", "PASS", str(self.q08),
                    json.dumps({"promoted_from_work_item": "q07-1"}),
                ),
                (
                    "q09-news-1", "Q09_NEWS", "pending", None, None, "{}",
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
            schema.add_dependency(
                connection,
                child_work_item_id="q09-news-1",
                dependency_role="Q08_INPUT",
                parent_work_item_id="q08-1",
                parent_evidence_sha256=contract.sha256_file(self.q08),
                required_verdicts=["PASS"],
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

    def test_terminal_failure_pointer_authenticates_distinct_attempt_snapshots(self) -> None:
        plan = self.build(output="terminal-attempt-snapshots")
        farm_root, plan_hash = self.setup_bound_farm(
            plan,
            activate=True,
            attempt_count=runner.WORK_ITEM_ATTEMPT_CEILING - 1,
        )
        spec = plan["cells"][0]
        cell_dir = Path(spec["receipt_path"]).parent
        live_log = cell_dir / "runs" / "selection" / "run_smoke.log"
        dispatch_count = 0

        def differing_transient_attempts(_spec: dict, _context: dict) -> None:
            nonlocal dispatch_count
            dispatch_count += 1
            live_log.parent.mkdir(parents=True, exist_ok=True)
            live_log.write_text(
                f"attempt {dispatch_count} log\n", encoding="utf-8"
            )
            raise runner.TransientCellError(
                f"fixture transient attempt {dispatch_count}"
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

        self.assertEqual(dispatch_count, 2)
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
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

        execution_failure = json.loads(
            Path(result["execution_failure_path"]).read_text(encoding="utf-8")
        )
        self.assertEqual(
            execution_failure["schema_version"], runner.EXECUTION_FAILURE_SCHEMA
        )
        self.assertEqual(execution_failure["cell_failure_occurrence"], 2)
        self.assertEqual(execution_failure["cell_failure_path"], str(second_path))
        self.assertEqual(
            result["adjudication"]["details"]["failed_cells"][0]["failure_path"],
            str(second_path),
        )

        for sidecar_path in (first_path, second_path):
            authenticated = runner._authenticated_cell_failure(
                spec,
                work_item_id="q09-news-1",
                failure_path=sidecar_path,
                expected_failure_sha256=contract.sha256_file(sidecar_path),
            )
            self.assertIsNotNone(authenticated)

        # The live log can change again without invalidating either occurrence.
        live_log.write_text("attempt 3 live mutation\n", encoding="utf-8")
        recollected = runner.collect_run_plan_status(
            Path(plan["plan_path"]), output_root=output_root
        )
        self.assertEqual(recollected["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(
            recollected["adjudication"]["details"]["failed_cells"][0][
                "failure_path"
            ],
            str(second_path),
        )

        # A terminal snapshot mutation still fails closed, under the accurate
        # failure-manifest reason rather than the receipt reason.
        second_log.write_text("tampered snapshot\n", encoding="utf-8")
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
        self.assertEqual(result["failed_cell_count"], 1)
        failure = json.loads(
            Path(result["adjudication"]["details"]["failed_cells"][0]["failure_path"])
            .read_text(encoding="utf-8")
        )
        self.assertEqual(failure["schema_version"], runner.CELL_FAILURE_SCHEMA)
        self.assertIn("claimed-terminal exit wait timed out", failure["error"])

    def test_executor_surfaces_a_failed_cell_instead_of_reporting_every_cell_missing(self) -> None:
        plan = self.build(output="failed-cell")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)

        def fail_first_cell(spec: dict, _context: dict) -> None:
            raise runner.RunnerError(
                f"fixture tester failure for {spec['run_identity_sha256']}"
            )

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
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["adjudication"]["reason_codes"], ["cell_execution_failed"])
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 39)
        failed = result["adjudication"]["details"]["failed_cells"]
        self.assertEqual(len(failed), 1)
        self.assertIn("fixture tester failure", failed[0]["error"])
        failure_path = Path(failed[0]["failure_path"])
        self.assertTrue(failure_path.is_file())
        self.assertEqual(contract.sha256_file(failure_path), failed[0]["failure_sha256"])
        top_level_failure = json.loads(
            Path(result["execution_failure_path"]).read_text(encoding="utf-8")
        )
        self.assertEqual(top_level_failure["cell_failure_path"], str(failure_path))

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

    def test_transient_cell_twice_requeues_without_adjudication(self) -> None:
        plan = self.build(output="transient-twice-requeue")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        self.assertEqual(
            runner.WORK_ITEM_ATTEMPT_CEILING,
            terminal_worker.MAX_WORK_ITEM_RETRIES,
        )

        with (
            patch.object(
                runner.subprocess,
                "run",
                return_value=SimpleNamespace(returncode=1, stdout="", stderr=""),
            ) as smoke_run,
            patch.object(runner, "_wait_for_claimed_terminal_exit"),
            self.assertRaisesRegex(
                runner.CapacityError,
                "transient cell exhausted.*requeue work item",
            ),
        ):
            runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "transient-twice-requeue-output",
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
                common_root=self.root / "common-transient-twice-requeue",
            )

        self.assertEqual(smoke_run.call_count, 2)
        self.assertFalse(
            list((self.root / "transient-twice-requeue-output").rglob("aggregate.json"))
        )
        first_cell = Path(plan["cells"][0]["receipt_path"]).parent
        self.assertTrue((first_cell / "cell_failure.json").is_file())
        self.assertTrue((first_cell / "cell_failure_2.json").is_file())
        self.assertFalse((first_cell / "cell_receipt.json").exists())

        finished = terminal_worker._finish_work_item(farm_root, "q09-news-1", 1)
        self.assertEqual(finished["status"], "pending")
        self.assertEqual(finished["attempt"], 1)
        with closing(farmctl.connect(farm_root)) as connection:
            row = connection.execute(
                "SELECT status,verdict,attempt_count,evidence_path "
                "FROM work_items WHERE id='q09-news-1'"
            ).fetchone()
        self.assertEqual(tuple(row), ("pending", None, 1, None))

    def test_transient_cell_attempt_ceiling_adjudicates(self) -> None:
        plan = self.build(output="transient-attempt-ceiling")
        farm_root, plan_hash = self.setup_bound_farm(
            plan,
            activate=True,
            attempt_count=runner.WORK_ITEM_ATTEMPT_CEILING - 1,
        )

        def always_transient(_spec: dict, _context: dict) -> None:
            raise runner.TransientCellError("fixture child exit 1 without receipt")

        with patch.object(runner, "_wait_for_claimed_terminal_exit"):
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "transient-attempt-ceiling-output",
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
                common_root=self.root / "common-transient-attempt-ceiling",
                dispatch_cell=always_transient,
            )

        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 39)
        first_cell = Path(plan["cells"][0]["receipt_path"]).parent
        self.assertTrue((first_cell / "cell_failure.json").is_file())
        self.assertTrue((first_cell / "cell_failure_2.json").is_file())
        self.assertTrue(Path(result["aggregate_path"]).is_file())

    def test_history_lock_requeues_count_toward_transient_ceiling(self) -> None:
        plan = self.build(output="transient-history-lock-ceiling")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        with closing(farmctl.connect(farm_root)) as connection:
            row = connection.execute(
                "SELECT payload_json FROM work_items WHERE id='q09-news-1'"
            ).fetchone()
            payload = json.loads(row["payload_json"])
            payload["transient_infra_attempts"] = 2
            connection.execute(
                "UPDATE work_items SET payload_json=? WHERE id='q09-news-1'",
                (json.dumps(payload, sort_keys=True),),
            )
            connection.commit()

        def always_transient(_spec: dict, _context: dict) -> None:
            raise runner.TransientCellError("fixture child exit 1 without receipt")

        with patch.object(runner, "_wait_for_claimed_terminal_exit"):
            result = runner.execute_run_plan(
                Path(plan["plan_path"]),
                output_root=self.root / "transient-history-lock-ceiling-output",
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
                common_root=self.root / "common-transient-history-lock-ceiling",
                dispatch_cell=always_transient,
            )

        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(result["failed_cell_count"], 1)
        self.assertEqual(result["missing_cell_count"], 39)
        first_cell = Path(plan["cells"][0]["receipt_path"]).parent
        self.assertTrue((first_cell / "cell_failure.json").is_file())
        self.assertTrue((first_cell / "cell_failure_2.json").is_file())
        self.assertTrue(Path(result["aggregate_path"]).is_file())

    def test_production_multi_cell_execute_writes_receipts_and_collects(self) -> None:
        plan = self.build(output="production-multi-cell")
        farm_root, plan_hash = self.setup_bound_farm(plan, activate=True)
        commands: list[list[str]] = []

        def fake_run(command: list[str], **_kwargs: object) -> SimpleNamespace:
            commands.append(command)
            self.assertIn("-RequireFreshLoggerSample", command)
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
