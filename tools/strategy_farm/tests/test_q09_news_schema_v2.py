import hashlib
import json
import sqlite3
import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_schema as schema  # noqa: E402


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def base_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
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
    return conn


def add_work_item(conn: sqlite3.Connection, item_id: str, phase: str, verdict: str,
                  *, evidence: str = "evidence.json") -> None:
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
        (item_id, phase, "QM5_12345", "EURUSD.DWX", "done", verdict, evidence, "2026-01-01T00:00:00Z"),
    )


def add_bundle(conn: sqlite3.Connection) -> None:
    manifest = {
        "schema_version": "q09-news-calendar-bundle/v2",
        "bundle_id": "bundle-v2",
        "manifest_sha256": _hash("calendar-manifest"),
        "content_sha256": _hash("calendar-content"),
        "coverage_from_utc": "2019-01-01T00:00:00Z",
        "coverage_to_utc": "2026-01-01T00:00:00Z",
        "event_from_utc": "2019-01-02T00:00:00Z",
        "event_to_utc": "2025-12-30T00:00:00Z",
        "row_count": 100,
        "publisher_evidence_path": "publisher.json",
        "publisher_evidence_sha256": _hash("publisher"),
        "files": [
            {
                "role": "EVENTS",
                "relative_path": "events.csv",
                "sha256": _hash("calendar-content"),
                "size_bytes": 1000,
                "row_count": 100,
                "event_from_utc": "2019-01-02T00:00:00Z",
                "event_to_utc": "2025-12-30T00:00:00Z",
            }
        ],
    }
    schema.record_calendar_bundle(conn, manifest, "manifest.json")


def add_q09_final(conn: sqlite3.Connection) -> None:
    conn.execute(
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
            "q09n", schema.CONTRACT_VERSION, "DXZ", "DXZ", "q08", "bundle-v2", _hash("base"),
            _hash("baseline"), _hash("ex5"), _hash("include"), "2020-01-01T00:00:00Z",
            "2022-12-31T23:59:59Z", "2023-01-01T00:00:00Z", "2025-01-01T00:00:00Z",
            60, 24, "7x1_target_compliance", "CONFIG_LOCKED", "PRE30", "DXZ",
            "q09.json", _hash("q09-evidence"), "2026-01-01T00:00:01Z",
        ),
    )
    for arm, mode, compliance in (("CONTROL_OFF", "OFF", "NONE"), ("POLICY_ON", "PRE30", "DXZ")):
        for seed in (42, 17, 99, 7, 2026):
            identity = f"{arm}/{mode}/{compliance}/{seed}"
            conn.execute(
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
        conn.execute(
            """
            INSERT INTO q09_news_arms(
                q09_news_work_item_id,arm,temporal_mode,compliance_mode,seed_set_json,
                setfile_hashes_json,evidence_hashes_json,created_at
            ) VALUES(?,?,?,?,?,?,?,?)
            """,
            (
                "q09n", arm, mode, compliance, json.dumps([42, 17, 99, 7, 2026]), "{}", "{}",
                "2026-01-01T00:00:03Z",
            ),
        )


class Q09NewsSchemaV2Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.conn = base_connection()

    def tearDown(self) -> None:
        self.conn.close()

    def test_schema_is_idempotent_and_does_not_enable_global_foreign_keys(self) -> None:
        add_work_item(self.conn, "legacy", "Q10", "PASS")
        self.conn.execute(
            "INSERT INTO portfolio_candidates VALUES(?,?,?,?,?,?,?)",
            ("QM5_12345", "EURUSD.DWX", "legacy", "Q12_REVIEW_READY", "old.json", "x", "x"),
        )
        before = schema.protected_legacy_sha256(self.conn)
        self.conn.commit()
        schema.ensure_schema(self.conn)
        schema.ensure_schema(self.conn)
        self.assertEqual(self.conn.execute("PRAGMA foreign_keys").fetchone()[0], 0)
        self.assertEqual(schema.protected_legacy_sha256(self.conn), before)
        self.assertIsNotNone(
            self.conn.execute("SELECT 1 FROM sqlite_master WHERE type='view' AND name='portfolio_candidates_eligible'").fetchone()
        )

    def test_v3_dependency_rows_migrate_byte_for_byte_and_new_roles_open(self) -> None:
        add_work_item(self.conn, "q08", "Q08", "PASS")
        add_work_item(self.conn, "q09n", "Q09_NEWS", "CONFIG_LOCKED")
        self.conn.executescript(
            """
            CREATE TABLE q09_news_schema_meta (
                schema_name TEXT PRIMARY KEY,
                schema_version INTEGER NOT NULL,
                installed_at TEXT NOT NULL
            );
            INSERT INTO q09_news_schema_meta VALUES('q09_news',3,'2026-01-01T00:00:00Z');
            CREATE TABLE work_item_dependencies (
                child_work_item_id TEXT NOT NULL,
                dependency_role TEXT NOT NULL CHECK (
                    dependency_role IN ('Q08_INPUT','Q09_NEWS','Q09_PORTFOLIO')
                ),
                parent_work_item_id TEXT NOT NULL,
                parent_evidence_sha256 TEXT NOT NULL,
                required_verdicts_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY(child_work_item_id,dependency_role)
            );
            """
        )
        prior = (
            "q09n", "Q08_INPUT", "q08", _hash("q08"), '["PASS"]',
            "2026-01-01T00:00:00Z",
        )
        self.conn.execute(
            "INSERT INTO work_item_dependencies VALUES(?,?,?,?,?,?)", prior
        )
        self.conn.commit()

        schema.ensure_schema(self.conn)

        self.assertEqual(
            tuple(self.conn.execute("SELECT * FROM work_item_dependencies").fetchone()),
            prior,
        )
        table_sql = self.conn.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='work_item_dependencies'"
        ).fetchone()[0]
        self.assertIn("PARENT_LINEAGE", table_sql)
        self.assertIn("CHALLENGER_Q10", table_sql)
        self.assertIn("Q14_ADMISSION", table_sql)
        self.assertEqual(
            self.conn.execute(
                "SELECT schema_version FROM q09_news_schema_meta WHERE schema_name='q09_news'"
            ).fetchone()[0],
            5,
        )

        add_work_item(self.conn, "q10", "Q10", "PASS")
        add_work_item(self.conn, "q16", "Q16", None)
        for role in ("PARENT_LINEAGE", "CHALLENGER_Q10"):
            schema.add_dependency(
                self.conn,
                child_work_item_id="q16",
                dependency_role=role,
                parent_work_item_id="q10",
                parent_evidence_sha256=_hash(role),
                required_verdicts=["PASS"],
            )

        add_work_item(self.conn, "q14", "Q14", "OPT_ELIGIBLE")
        add_work_item(self.conn, "q15", "Q15", "CHALLENGER_SPAWNED")
        schema.add_dependency(
            self.conn,
            child_work_item_id="q15",
            dependency_role="Q14_ADMISSION",
            parent_work_item_id="q14",
            parent_evidence_sha256=_hash("q14"),
            required_verdicts=["OPT_ELIGIBLE"],
        )

    def test_dependency_trigger_rejects_missing_parent_with_foreign_keys_off(self) -> None:
        add_work_item(self.conn, "q09n", "Q09_NEWS", None)
        self.conn.commit()
        schema.ensure_schema(self.conn)
        with self.assertRaises(sqlite3.IntegrityError):
            schema.add_dependency(
                self.conn,
                child_work_item_id="q09n",
                dependency_role="Q08_INPUT",
                parent_work_item_id="missing",
                parent_evidence_sha256=_hash("missing"),
                required_verdicts=["PASS"],
            )

    def test_historical_q09_alias_cannot_receive_a_new_contract(self) -> None:
        add_work_item(self.conn, "legacy-q09", "Q09", "PASS")
        self.conn.commit()
        schema.ensure_schema(self.conn)
        with self.assertRaises(sqlite3.IntegrityError):
            schema.add_contract(
                self.conn,
                contract_id="contract-1",
                work_item_id="legacy-q09",
                phase_id="Q09",
                candidate_lineage_key=_hash("lineage"),
                input_manifest_path="input.json",
                input_manifest_sha256=_hash("input"),
            )

    def test_calendar_rows_are_append_only(self) -> None:
        schema.ensure_schema(self.conn)
        add_bundle(self.conn)
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("UPDATE news_calendar_bundles SET row_count=101 WHERE bundle_id='bundle-v2'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("DELETE FROM news_calendar_bundle_files WHERE bundle_id='bundle-v2'")

    def test_q10_gate_and_eligibility_require_both_dependencies_and_two_arms(self) -> None:
        add_work_item(self.conn, "q08", "Q08", "PASS", evidence="q08.json")
        add_work_item(self.conn, "q09n", "Q09_NEWS", "CONFIG_LOCKED", evidence="q09.json")
        add_work_item(self.conn, "q09p", "Q09_PORTFOLIO", "PASS_PORTFOLIO", evidence="q09p.json")
        add_work_item(self.conn, "q10", "Q10", "PASS", evidence="q10.json")
        self.conn.execute(
            "INSERT INTO portfolio_candidates VALUES(?,?,?,?,?,?,?)",
            ("QM5_12345", "EURUSD.DWX", "q10", "Q12_REVIEW_READY", "q10.json", "x", "x"),
        )
        self.conn.commit()
        schema.ensure_schema(self.conn)
        add_bundle(self.conn)
        schema.add_dependency(
            self.conn, child_work_item_id="q09n", dependency_role="Q08_INPUT", parent_work_item_id="q08",
            parent_evidence_sha256=_hash("q08"), required_verdicts=["PASS"],
        )
        schema.add_dependency(
            self.conn, child_work_item_id="q09p", dependency_role="Q08_INPUT", parent_work_item_id="q08",
            parent_evidence_sha256=_hash("q08"), required_verdicts=["PASS"],
        )
        add_q09_final(self.conn)
        schema.add_dependency(
            self.conn, child_work_item_id="q10", dependency_role="Q09_NEWS", parent_work_item_id="q09n",
            parent_evidence_sha256=_hash("q09-evidence"), required_verdicts=["CONFIG_LOCKED"],
        )
        with self.assertRaises(schema.SchemaError):
            schema.assert_q10_dependency_gate(self.conn, "q10")
        schema.add_dependency(
            self.conn, child_work_item_id="q10", dependency_role="Q09_PORTFOLIO", parent_work_item_id="q09p",
            parent_evidence_sha256=_hash("q09p-evidence"), required_verdicts=["PASS_PORTFOLIO"],
        )
        gate = schema.assert_q10_dependency_gate(self.conn, "q10")
        self.assertEqual(gate.q09_news_work_item_id, "q09n")
        schema.append_qualification(
            self.conn,
            {
                "qualification_id": "qualification-1",
                "candidate_lineage_key": _hash("candidate-lineage"),
                "ea_id": "QM5_12345",
                "symbol": "EURUSD.DWX",
                "contract_version": schema.CONTRACT_VERSION,
                "q08_work_item_id": "q08",
                "q09_news_work_item_id": "q09n",
                "q09_portfolio_work_item_id": "q09p",
                "q10_work_item_id": "q10",
                "q09_news_evidence_sha256": _hash("q09-evidence"),
                "q09_portfolio_evidence_sha256": _hash("q09p-evidence"),
                "q10_evidence_sha256": _hash("q10-evidence"),
                "baseline_setfile_sha256": _hash("baseline"),
                "q10_setfile_sha256": _hash("q10-setfile"),
                "ex5_sha256": _hash("ex5"),
                "include_closure_sha256": _hash("include"),
                "calendar_bundle_id": "bundle-v2",
                "legacy_source_work_item_id": "q10",
                "state": "QUALIFIED",
                "reason_code": "bound_chain_passed",
                "evidence_manifest_path": "qualification.json",
                "evidence_manifest_sha256": _hash("qualification"),
                "supersedes_qualification_id": None,
                "created_at": "2026-01-02T00:00:00Z",
            },
        )
        eligible = self.conn.execute("SELECT * FROM portfolio_candidates_eligible").fetchall()
        self.assertEqual(len(eligible), 1)
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("UPDATE candidate_qualifications SET reason_code='rewrite'")
        schema.append_qualification(
            self.conn,
            {
                "qualification_id": "qualification-2",
                "candidate_lineage_key": _hash("candidate-lineage"),
                "ea_id": "QM5_12345",
                "symbol": "EURUSD.DWX",
                "contract_version": schema.CONTRACT_VERSION,
                "legacy_source_work_item_id": "q10",
                "state": "VINTAGE_STALE",
                "reason_code": "binary_identity_changed",
                "evidence_manifest_path": "stale.json",
                "evidence_manifest_sha256": _hash("stale"),
                "supersedes_qualification_id": "qualification-1",
                "created_at": "2026-01-03T00:00:00Z",
            },
        )
        self.assertEqual(self.conn.execute("SELECT count(*) FROM portfolio_candidates_eligible").fetchone()[0], 0)


if __name__ == "__main__":
    unittest.main()
