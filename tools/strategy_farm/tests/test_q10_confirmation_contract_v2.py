import hashlib
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_schema as schema  # noqa: E402
import q09_news_calendar as calendar_bundle  # noqa: E402
import q10_confirmation_contract as q10_contract  # noqa: E402
from q09_news_contract import ADJUDICATION_SCHEMA_VERSION, canonical_json_bytes, sha256_file  # noqa: E402


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


class Q10ConfirmationContractV2Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.database = self.root / "farm.sqlite"
        self.conn = sqlite3.connect(self.database)
        self.conn.executescript(
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
        schema.ensure_schema(self.conn)
        self.q09_evidence = self.root / "q09_aggregate.json"
        self.q09_evidence.write_bytes(b'{"verdict":"CONFIG_LOCKED"}\n')
        self.portfolio_evidence = self.root / "q09_portfolio.json"
        self.portfolio_evidence.write_bytes(b'{"verdict":"PASS_PORTFOLIO"}\n')
        self.source_set = self.root / "source.set"
        self.source_set.write_bytes(
            b"; immutable source\r\nqm_news_temporal=3||3||1||6||N\r\nqm_news_compliance=1\r\nRisk=0.5\r\n"
        )
        self.ex5 = self.root / "ea.ex5"
        self.ex5.write_bytes(b"compiled-ea-v2")
        self.include_closure = self.root / "include_closure.json"
        self.include_closure.write_bytes(b'{"QM_NewsFilter.mqh":"abc"}\n')
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
        published_calendar = calendar_bundle.publish_bundle(calendar_plan, self.root / "calendar_bundles")
        self.calendar_manifest = Path(published_calendar["manifest_path"])
        self.bundle_id = published_calendar["bundle_id"]
        calendar_content = published_calendar["content_sha256"]
        q09_aggregate = {
            "schema_version": ADJUDICATION_SCHEMA_VERSION,
            "verdict": "CONFIG_LOCKED",
            "work_item_id": "q09n",
            "chosen_config": {
                "temporal_mode": "PRE30",
                "temporal_mode_id": 1,
                "compliance_mode": "DXZ",
                "setfile_sha256s": [],
            },
            "identities": {
                "baseline_setfile_sha256": sha256_file(self.source_set),
                "ex5_sha256": sha256_file(self.ex5),
                "include_closure_sha256": sha256_file(self.include_closure),
            },
            "calendar_bundle": {
                "bundle_id": self.bundle_id,
                "manifest_sha256": published_calendar["manifest_sha256"],
                "content_sha256": calendar_content,
            },
        }
        q09_aggregate["adjudication_sha256"] = hashlib.sha256(
            canonical_json_bytes(q09_aggregate)
        ).hexdigest()
        self.q09_evidence.write_bytes(canonical_json_bytes(q09_aggregate))
        self._add_work_item("q08", "Q08", "PASS", self.root / "q08.json")
        self._add_work_item("q09n", "Q09_NEWS", "CONFIG_LOCKED", self.q09_evidence)
        self._add_work_item("q09p", "Q09_PORTFOLIO", "PASS_PORTFOLIO", self.portfolio_evidence)
        self._add_work_item("q10", "Q10", None, self.root / "q10.json")
        schema.record_calendar_bundle(self.conn, published_calendar, str(self.calendar_manifest))
        schema.add_dependency(
            self.conn, child_work_item_id="q09n", dependency_role="Q08_INPUT", parent_work_item_id="q08",
            parent_evidence_sha256=_hash("q08"), required_verdicts=["PASS"],
        )
        schema.add_dependency(
            self.conn, child_work_item_id="q09p", dependency_role="Q08_INPUT", parent_work_item_id="q08",
            parent_evidence_sha256=_hash("q08"), required_verdicts=["PASS"],
        )
        self.conn.execute(
            """
            INSERT INTO q09_news_tests(
                work_item_id,contract_version,deployment_target,target_compliance,q08_work_item_id,
                calendar_bundle_id,paired_base_identity_sha256,baseline_setfile_sha256,ex5_sha256,
                include_closure_sha256,selection_from_utc,selection_to_utc,holdout_from_utc,
                holdout_to_utc,complete_months,holdout_complete_months,matrix_scope,verdict,
                chosen_temporal,chosen_compliance,aggregate_path,aggregate_sha256,created_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                "q09n", schema.CONTRACT_VERSION, "DXZ", "DXZ", "q08", self.bundle_id, _hash("base"),
                sha256_file(self.source_set), sha256_file(self.ex5), sha256_file(self.include_closure),
                "2020-01-01T00:00:00Z", "2022-12-31T23:59:59Z", "2023-01-01T00:00:00Z",
                "2025-01-01T00:00:00Z", 60, 24, "7x1_target_compliance", "CONFIG_LOCKED",
                "PRE30", "DXZ", str(self.q09_evidence), sha256_file(self.q09_evidence),
                "2026-01-01T00:00:01Z",
            ),
        )
        for arm, mode, compliance in (("CONTROL_OFF", "OFF", "NONE"), ("POLICY_ON", "PRE30", "DXZ")):
            for seed in (42, 17, 99, 7, 2026):
                identity = f"{arm}/{mode}/{compliance}/{seed}"
                self.conn.execute(
                    """
                    INSERT INTO q09_news_cells(
                        q09_news_work_item_id,arm,temporal_mode,compliance_mode,seed,requested_seed,
                        effective_seed,paired_base_identity_sha256,run_identity_sha256,setfile_sha256,
                        evidence_sha256,report_sha256,selection_metrics_json,holdout_metrics_json,
                        full_metrics_json,q07_seed_stability_pass,flat_at_event_receipt_sha256,created_at
                    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        "q09n", arm, mode, compliance, seed, seed, seed, _hash("base"), _hash("run/" + identity),
                        _hash("set/" + identity), _hash("evidence/" + identity), _hash("report/" + identity),
                        "{}", "{}", "{}", 1, None, "2026-01-01T00:00:02Z",
                    ),
                )
            self.conn.execute(
                """
                INSERT INTO q09_news_arms(
                    q09_news_work_item_id,arm,temporal_mode,compliance_mode,seed_set_json,
                    setfile_hashes_json,evidence_hashes_json,created_at
                ) VALUES(?,?,?,?,?,?,?,?)
                """,
                ("q09n", arm, mode, compliance, "[42,17,99,7,2026]", "{}", "{}", "2026-01-01T00:00:03Z"),
            )
        schema.add_dependency(
            self.conn, child_work_item_id="q10", dependency_role="Q09_NEWS", parent_work_item_id="q09n",
            parent_evidence_sha256=sha256_file(self.q09_evidence), required_verdicts=["CONFIG_LOCKED"],
        )
        self.conn.commit()

    def tearDown(self) -> None:
        self.conn.close()
        self.temporary.cleanup()

    def _add_work_item(self, item_id: str, phase: str, verdict: str | None, evidence: Path) -> None:
        self.conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
            (item_id, phase, "QM5_12345", "EURUSD.DWX", "done" if verdict else "pending", verdict,
             str(evidence), "2026-01-01T00:00:00Z"),
        )

    def _add_portfolio_dependency(self) -> None:
        schema.add_dependency(
            self.conn, child_work_item_id="q10", dependency_role="Q09_PORTFOLIO", parent_work_item_id="q09p",
            parent_evidence_sha256=sha256_file(self.portfolio_evidence), required_verdicts=["PASS_PORTFOLIO"],
        )
        self.conn.commit()

    def test_q10_is_blocked_until_both_dependencies_are_bound(self) -> None:
        with self.assertRaises(q10_contract.Q10BindingError):
            q10_contract.verify_q10_binding(self.conn, "q10")
        self._add_portfolio_dependency()
        binding = q10_contract.verify_q10_binding(self.conn, "q10")
        self.assertEqual(binding.q09_news_work_item_id, "q09n")
        self.assertEqual(binding.q09_portfolio_work_item_id, "q09p")

    def test_upstream_evidence_hash_mismatch_blocks_q10(self) -> None:
        self._add_portfolio_dependency()
        self.q09_evidence.write_bytes(b"tampered")
        with self.assertRaisesRegex(q10_contract.Q10BindingError, "SHA-256 mismatch"):
            q10_contract.verify_q10_binding(self.conn, "q10")

    def test_materialization_is_isolated_and_source_set_remains_immutable(self) -> None:
        self._add_portfolio_dependency()
        binding = q10_contract.verify_q10_binding(self.conn, "q10")
        source_before = self.source_set.read_bytes()
        result = q10_contract.materialize_q10_inputs(
            binding,
            source_setfile=self.source_set,
            ex5_path=self.ex5,
            include_closure_path=self.include_closure,
            report_root=self.root / "reports" / "q10",
            calendar_relative_common_path=f"q09_news/{self.bundle_id}/events.csv",
        )
        self.assertEqual(self.source_set.read_bytes(), source_before)
        generated = Path(result["generated_setfile"])
        self.assertTrue(generated.is_relative_to((self.root / "reports" / "q10").resolve()))
        text = generated.read_text(encoding="utf-8")
        self.assertIn("qm_news_temporal=1||3||1||6||N", text)
        self.assertIn("qm_news_compliance=1", text)
        self.assertIn("qm_news_calendar_bundle_id=" + self.bundle_id, text)
        self.assertIn(
            "qm_news_calendar_expected_sha256=" + binding.calendar_content_sha256,
            text,
        )
        manifest = json.loads(Path(result["manifest_path"]).read_text(encoding="utf-8"))
        self.assertEqual(set(manifest["dependencies"]), {"Q09_NEWS", "Q09_PORTFOLIO"})
        self.assertEqual(manifest["inputs"]["baseline_source_setfile_sha256"], sha256_file(self.source_set))

    def test_binary_identity_mismatch_blocks_materialization(self) -> None:
        self._add_portfolio_dependency()
        binding = q10_contract.verify_q10_binding(self.conn, "q10")
        self.ex5.write_bytes(b"different-binary")
        with self.assertRaisesRegex(q10_contract.Q10BindingError, "compiled EX5 SHA-256 mismatch"):
            q10_contract.materialize_q10_inputs(
                binding,
                source_setfile=self.source_set,
                ex5_path=self.ex5,
                include_closure_path=self.include_closure,
                report_root=self.root / "reports",
                calendar_relative_common_path=f"q09_news/{self.bundle_id}/events.csv",
            )


if __name__ == "__main__":
    unittest.main()
