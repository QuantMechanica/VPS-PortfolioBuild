import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_contract as contract  # noqa: E402
import q09_news_calendar as calendar_bundle  # noqa: E402
import q09_news_runner as runner  # noqa: E402


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
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.q08 = self.root / "q08.json"
        self.q08.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
        self.setfile = self.root / "baseline.set"
        self.setfile.write_bytes(
            b"qm_rng_seed=42\r\nqm_news_temporal=3\r\nqm_news_compliance=1\r\nRisk=0.5\r\n"
        )
        self.ex5 = self.root / "ea.ex5"
        self.ex5.write_bytes(b"compiled")
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

    def write_receipts(self, plan: dict) -> None:
        for spec in plan["cells"]:
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
        with self.assertRaisesRegex(runner.RunnerError, "setfile SHA-256 mismatch"):
            runner.collect_run_plan(Path(plan["plan_path"]))


if __name__ == "__main__":
    unittest.main()
