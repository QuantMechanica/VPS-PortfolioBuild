"""Tests for `farmctl readjudicate-news-8cell`.

OWNER-DEC-NEWSGATE-AE-20260904 (a)+(e): the 43 open Q10_NEWS expansion rows get
append-only successors adjudicated from their SEALED 8-cell aggregates under the
current single-target rule - no tester run, full provenance, the original row
untouched.  These tests exercise that append-only CLI on a tmp DB with fixture
aggregates: `--list` enumeration, a read-only dry run, a single append-only
apply, and every machine-readable refusal.
"""

import hashlib
import json
import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import q09_news_contract as contract  # noqa: E402
import q09_news_schema as schema  # noqa: E402


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _metrics(net=100.0, pf=1.2, dd=10.0, sharpe=0.5, affected=0):
    return {
        "trades": 30,
        "profit_factor": pf,
        "drawdown_pct": dd,
        "sharpe": sharpe,
        "net_r": net,
        "original_entries": 100,
        "blocked_entries": 0,
        "affected_entries": affected,
    }


def _cell(arm, mode, comp, seed, tag, ssharpe, hsharpe, net=100.0, pf=1.2, dd=10.0):
    ident = f"{tag}/{arm}/{mode}/{comp}/{seed}"
    return {
        "arm": arm,
        "temporal_mode": mode,
        "compliance_mode": comp,
        "seed": seed,
        "requested_seed": seed,
        "effective_seed": seed,
        "paired_base_identity_sha256": _hash("base/" + tag),
        "run_identity_sha256": _hash("run/" + ident),
        "setfile_sha256": _hash("set/" + ident),
        "evidence_sha256": _hash("ev/" + ident),
        "report_sha256": _hash("rep/" + ident),
        "selection": _metrics(net, pf, dd, ssharpe),
        "holdout": _metrics(net, pf, dd, hsharpe),
        "full": _metrics(net, pf, dd, (ssharpe + hsharpe) / 2),
        "q07_seed_stability_pass": True,
        "flat_at_event_receipt_sha256": None,
    }


def _v3_evidence(work_item_id, *, tag, material=False, news_or_event=False):
    """A v3 8-cell (seed-17-only) evidence payload for a DXZ single-target run."""
    seed = 17
    target = "DXZ"
    cells = [_cell("CONTROL_OFF", "OFF", "NONE", seed, tag, 0.50, 0.40)]
    for mode in contract.TEMPORAL_MODES:
        if material and mode == "SKIP_DAY":
            cells.append(
                _cell("POLICY_ON", mode, target, seed, tag, 0.50, 0.40, net=-200.0, pf=0.7, dd=20.0)
            )
        else:
            cells.append(_cell("POLICY_ON", mode, target, seed, tag, 0.50, 0.40))
    return {
        "schema_version": contract.SCHEMA_VERSION_V3,
        "work_item_id": work_item_id,
        "deployment_target": target,
        "identities": {
            "q08_work_item_id": "q08-" + tag,
            "q08_evidence_sha256": _hash("q08/" + tag),
            "baseline_setfile_sha256": _hash("bl/" + tag),
            "ex5_sha256": _hash("ex5/" + tag),
            "include_closure_sha256": _hash("inc/" + tag),
            "paired_base_identity_sha256": _hash("base/" + tag),
        },
        "calendar_bundle": {
            "bundle_id": "cal-" + tag,
            "manifest_sha256": _hash("man/" + tag),
            "content_sha256": _hash("cont/" + tag),
            "coverage_from_utc": "2019-12-01T00:00:00Z",
            "coverage_to_utc": "2025-02-01T00:00:00Z",
        },
        "windows": {
            "full_from_utc": "2020-01-01T00:00:00Z",
            "full_to_utc": "2025-01-01T00:00:00Z",
            "selection_from_utc": "2020-01-01T00:00:00Z",
            "selection_to_utc": "2022-12-31T23:59:59Z",
            "holdout_from_utc": "2023-01-01T00:00:00Z",
            "holdout_to_utc": "2025-01-01T00:00:00Z",
            "complete_months": 60,
            "holdout_complete_months": 24,
            "holdout_sealed": True,
        },
        "news_or_event_strategy": news_or_event,
        "cells": cells,
    }


def _expanded_review_aggregate(tag):
    """A genuine REVIEW / expanded_7x4_matrix_required aggregate (from a material 8-cell)."""
    # Historical rows were adjudicated BEFORE OWNER-DEC-NEWSGATE-AE-20260904 (e):
    # a single-target material 8-cell then yielded REVIEW / expanded_7x4 with the
    # sole expansion reason "material_effect".  The current rule locks such a
    # run, so the replica is built through the still-expanding news/event path
    # and normalized back to the pre-(e) shape (reason list, no expansion_policy,
    # sha recomputed the way adjudicate() seals it).
    material = _v3_evidence("adj-" + tag, tag=tag, material=True, news_or_event=True)
    review = contract.adjudicate(material)
    assert review["verdict"] == "REVIEW_REQUIRED"
    assert review["reason_codes"] == ["expanded_7x4_matrix_required"]
    review["details"]["expansion_reasons"] = ["material_effect"]
    review.pop("expansion_policy", None)
    # pre-(a) REVIEW dicts carried neither label; the 8-cell row keeps the
    # persisted default scope (7x1_target_compliance) the CLI keys on.
    review.pop("matrix_scope", None)
    review.pop("target_compliance", None)
    review.pop("adjudication_sha256", None)
    review["adjudication_sha256"] = contract.sha256_bytes(contract.canonical_json_bytes(review))
    return review


def _nonlock_review(reason):
    result = {
        "schema_version": contract.ADJUDICATION_SCHEMA_VERSION_V3,
        "verdict": "REVIEW_REQUIRED",
        "reason_codes": [reason],
        "target_compliance": "DXZ",
        "matrix_scope": "7x1_target_compliance",
        "chosen_config": None,
        "locked_arms": [],
        "details": {"note": "fixture non-expansion review"},
    }
    result["adjudication_sha256"] = contract.sha256_bytes(
        contract.canonical_json_bytes(result)
    )
    return result


class ReadjudicateNews8CellTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.tmp = Path(self.temporary.name)
        self.root = self.tmp / "farm"
        self.work_items_root = self.tmp / "work_items"
        farmctl.init_db(self.root)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _seed_source(
        self,
        *,
        tag,
        source_id=None,
        ea_id=None,
        symbol=None,
        evidence_locks=True,
        write_evidence=True,
        aggregate=None,
        news_or_event=False,
        phase=None,
    ):
        """Seed one done Q10_NEWS 8-cell REVIEW row plus its sealed aggregates."""
        source_id = source_id or ("src-" + tag)
        ea_id = ea_id or ("QM5_99" + tag[-2:] if tag[-2:].isdigit() else "QM5_9999")
        symbol = symbol or "EURUSD.DWX"
        setfile = f"/sets/{tag}.set"
        q08_id = "q08-" + tag
        bundle_id = "cal-" + tag

        # sealed evidence written under the source work-item directory
        evidence = _v3_evidence(
            source_id, tag=tag, material=not evidence_locks, news_or_event=news_or_event
        )
        review = aggregate if aggregate is not None else _expanded_review_aggregate(tag)

        source_dir = self.work_items_root / source_id
        source_dir.mkdir(parents=True, exist_ok=True)
        agg_path = source_dir / "aggregate.json"
        agg_path.write_bytes(contract.canonical_json_bytes(review))
        agg_sha = contract.sha256_file(agg_path)
        if write_evidence:
            (source_dir / "q09_news_evidence.json").write_bytes(
                contract.canonical_json_bytes(evidence)
            )

        now = "2026-09-04T00:00:00+00:00"
        with closing(farmctl.connect(self.root)) as conn:
            conn.execute(
                """
                INSERT INTO news_calendar_bundles(
                    bundle_id,schema_version,manifest_path,manifest_sha256,content_sha256,
                    coverage_from_utc,coverage_to_utc,event_from_utc,event_to_utc,row_count,
                    publisher_evidence_path,publisher_evidence_sha256,correction_reason,
                    approved_by,approved_at,created_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    bundle_id, "q09-news-calendar/v2", "manifest.json",
                    _hash("man/" + tag), _hash("cont/" + tag),
                    "2019-12-01T00:00:00Z", "2025-02-01T00:00:00Z", None, None, 1,
                    "publisher.json", _hash("pub/" + tag), None, "OWNER",
                    "2026-07-29T08:00:00Z", now,
                ),
            )
            for wid, phase, status, verdict in (
                (q08_id, "Q08", "done", "PASS"),
                (source_id, phase or farmctl._NEWS_PHASE, "done", "REVIEW_REQUIRED"),
            ):
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                        attempt_count,parent_task_id,evidence_path,claimed_by,
                        payload_json,created_at,updated_at
                    ) VALUES(?, 'backtest', ?, ?, ?, ?, ?, ?, 0, NULL, NULL, NULL, ?, ?, ?)
                    """,
                    (wid, phase, ea_id, symbol, setfile, status, verdict, "{}", now, now),
                )
            schema.add_dependency(
                conn,
                child_work_item_id=source_id,
                dependency_role="Q08_INPUT",
                parent_work_item_id=q08_id,
                parent_evidence_sha256=_hash("q08/" + tag),
                required_verdicts=["PASS"],
            )
            conn.commit()
            evidence_for_source = dict(evidence)
            evidence_for_source["work_item_id"] = source_id
            schema.record_q09_adjudication(
                conn,
                evidence_payload=evidence_for_source,
                adjudication=review,
                aggregate_path=str(agg_path),
                aggregate_sha256=agg_sha,
            )
        return {
            "source_id": source_id,
            "ea_id": ea_id,
            "symbol": symbol,
            "source_dir": source_dir,
            "aggregate_sha256": agg_sha,
        }

    # -- list ---------------------------------------------------------------

    def test_list_enumerates_eligible_and_drops_readjudicated(self) -> None:
        self._seed_source(tag="aa11", source_id="src-aa11", ea_id="QM5_9911")
        self._seed_source(tag="bb22", source_id="src-bb22", ea_id="QM5_9922")

        listing = farmctl.readjudicate_news_8cell(self.root, None, list_mode=True)
        self.assertTrue(listing["list"])
        self.assertEqual(listing["eligible_count"], 2)
        ids = {row["source_work_item_id"] for row in listing["eligible"]}
        self.assertEqual(ids, {"src-aa11", "src-bb22"})
        for row in listing["eligible"]:
            self.assertTrue(row["sealed_evidence_present"])
            self.assertEqual(row["expansion_reasons"], ["material_effect"])

        farmctl.readjudicate_news_8cell(self.root, "src-aa11", apply=True)
        after = farmctl.readjudicate_news_8cell(self.root, None, list_mode=True)
        self.assertEqual(after["eligible_count"], 1)
        self.assertEqual(after["already_readjudicated_count"], 1)
        self.assertEqual(after["eligible"][0]["source_work_item_id"], "src-bb22")

    def test_list_excludes_historical_phase_rows_the_action_refuses(self) -> None:
        """2026-09-04 verifier finding: a row stored under the historical lane is
        returned by the UNION read but refused by the action path; --list must
        report it as excluded, never as eligible."""
        phases = farmctl._news_read_phases(include_historical=True)
        if len(phases) < 2:
            self.skipTest("no historical news lane under the active gate contract")
        self._seed_source(tag="aa11", source_id="src-aa11", ea_id="QM5_9911")
        self._seed_source(
            tag="cc33", source_id="src-cc33", ea_id="QM5_9933", phase=phases[1]
        )

        listing = farmctl.readjudicate_news_8cell(self.root, None, list_mode=True)
        self.assertEqual(listing["eligible_count"], 1)
        self.assertEqual(listing["eligible"][0]["source_work_item_id"], "src-aa11")
        self.assertEqual(listing["excluded_historical_phase_count"], 1)
        excluded = listing["excluded_historical_phase"][0]
        self.assertEqual(excluded["source_work_item_id"], "src-cc33")
        self.assertEqual(excluded["phase"], phases[1])
        self.assertEqual(excluded["reason"], "readjudicate_source_phase_not_current")
        self.assertEqual(excluded["required_phase"], farmctl._NEWS_PHASE)

        refused = farmctl.readjudicate_news_8cell(self.root, "src-cc33", apply=True)
        self.assertFalse(refused["readjudicated"])

    # -- dry run ------------------------------------------------------------

    def test_dry_run_writes_nothing(self) -> None:
        seeded = self._seed_source(tag="cc33", source_id="src-cc33")
        result = farmctl.readjudicate_news_8cell(self.root, "src-cc33")
        self.assertFalse(result["readjudicated"])
        self.assertTrue(result["dry_run"])
        self.assertTrue(result["would_readjudicate"])
        self.assertEqual(result["readjudicated_verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["readjudicated_from_work_item"], "src-cc33")

        with closing(farmctl.connect(self.root)) as conn:
            successors = conn.execute(
                "SELECT count(*) FROM work_items WHERE phase=? AND verdict='CONFIG_LOCKED'",
                (farmctl._NEWS_PHASE,),
            ).fetchone()[0]
            tests_rows = conn.execute(
                "SELECT count(*) FROM q09_news_tests WHERE verdict='CONFIG_LOCKED'"
            ).fetchone()[0]
        self.assertEqual(successors, 0)
        self.assertEqual(tests_rows, 0)
        # Only the source directory exists under the work-items root.
        self.assertEqual(
            sorted(p.name for p in self.work_items_root.iterdir()), ["src-cc33"]
        )

    # -- apply --------------------------------------------------------------

    def test_apply_inserts_exactly_one_successor_with_provenance(self) -> None:
        seeded = self._seed_source(tag="dd44", source_id="src-dd44", ea_id="QM5_9944")
        result = farmctl.readjudicate_news_8cell(self.root, "src-dd44", apply=True)
        self.assertTrue(result["readjudicated"])
        self.assertFalse(result["dry_run"])
        self.assertEqual(result["successor_verdict"], "CONFIG_LOCKED")
        successor_id = result["successor_work_item_id"]

        with closing(farmctl.connect(self.root)) as conn:
            successors = conn.execute(
                """
                SELECT id, phase, status, verdict, payload_json FROM work_items
                WHERE phase=? AND json_valid(payload_json)=1
                  AND json_extract(payload_json,'$.readjudicated_from_work_item')='src-dd44'
                """,
                (farmctl._NEWS_PHASE,),
            ).fetchall()
            self.assertEqual(len(successors), 1)
            row = successors[0]
            self.assertEqual(row["id"], successor_id)
            self.assertEqual(row["phase"], farmctl._NEWS_PHASE)
            self.assertEqual(row["status"], "done")
            self.assertEqual(row["verdict"], "CONFIG_LOCKED")

            payload = json.loads(row["payload_json"])
            self.assertEqual(payload["readjudicated_from_work_item"], "src-dd44")
            self.assertEqual(
                payload["readjudication_source_aggregate_sha256"],
                seeded["aggregate_sha256"],
            )
            self.assertEqual(
                payload["readjudication_rule_adjudication_schema"],
                contract.ADJUDICATION_SCHEMA_VERSION_V3,
            )
            self.assertEqual(
                payload["readjudication_original_review_reason_codes"],
                ["expanded_7x4_matrix_required"],
            )
            self.assertEqual(
                payload["readjudication_original_expansion_reasons"], ["material_effect"]
            )
            self.assertTrue(payload["no_tester_run"])

            # The q09_news_tests successor row is a CONFIG_LOCKED 8-cell lock.
            test_row = conn.execute(
                """
                SELECT verdict, matrix_scope, target_compliance, chosen_temporal,
                       chosen_compliance FROM q09_news_tests WHERE work_item_id=?
                """,
                (successor_id,),
            ).fetchone()
            self.assertEqual(test_row["verdict"], "CONFIG_LOCKED")
            self.assertEqual(test_row["matrix_scope"], "7x1_target_compliance")
            self.assertEqual(test_row["target_compliance"], "DXZ")
            self.assertIsNotNone(test_row["chosen_compliance"])

            # The ORIGINAL row is untouched.
            source_row = conn.execute(
                "SELECT status, verdict FROM work_items WHERE id='src-dd44'"
            ).fetchone()
            self.assertEqual((source_row["status"], source_row["verdict"]), ("done", "REVIEW_REQUIRED"))
            source_test = conn.execute(
                "SELECT verdict FROM q09_news_tests WHERE work_item_id='src-dd44'"
            ).fetchone()
            self.assertEqual(source_test["verdict"], "REVIEW_REQUIRED")

        # Successor aggregate + provenance sidecar written under the successor dir.
        successor_dir = self.work_items_root / successor_id
        self.assertTrue((successor_dir / "aggregate.json").is_file())
        self.assertTrue((successor_dir / "q09_news_evidence.json").is_file())
        provenance = json.loads(
            (successor_dir / "readjudication_provenance.json").read_text(encoding="utf-8")
        )
        self.assertEqual(provenance["readjudicated_from_work_item"], "src-dd44")
        self.assertEqual(
            provenance["readjudication_source_aggregate_sha256"],
            seeded["aggregate_sha256"],
        )
        self.assertEqual(
            provenance["schema_version"], "qm-q10-news-readjudication-provenance/v1"
        )

        # Re-applying refuses: the successor already exists.
        repeat = farmctl.readjudicate_news_8cell(self.root, "src-dd44", apply=True)
        self.assertFalse(repeat["readjudicated"])
        self.assertEqual(repeat["reason"], "readjudicate_successor_already_exists")
        self.assertEqual(repeat["successor_work_item_id"], successor_id)

    # -- refusals -----------------------------------------------------------

    def test_refuses_when_work_item_id_missing(self) -> None:
        result = farmctl.readjudicate_news_8cell(self.root, "")
        self.assertFalse(result["readjudicated"])
        self.assertEqual(result["reason"], "readjudicate_requires_work_item_id")

    def test_refuses_when_source_missing(self) -> None:
        result = farmctl.readjudicate_news_8cell(self.root, "does-not-exist")
        self.assertFalse(result["readjudicated"])
        self.assertEqual(result["reason"], "readjudicate_source_missing")

    def test_refuses_when_source_not_done_review_row(self) -> None:
        # A done Q08 PASS row is not a Q10_NEWS 8-cell REVIEW row.
        now = "2026-09-04T00:00:00+00:00"
        with closing(farmctl.connect(self.root)) as conn:
            conn.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,
                    payload_json,created_at,updated_at
                ) VALUES('q08-only','backtest','Q08','QM5_9999','EURUSD.DWX',
                         '/x.set','done','PASS',0,NULL,NULL,NULL,'{}',?,?)
                """,
                (now, now),
            )
            conn.commit()
        result = farmctl.readjudicate_news_8cell(self.root, "q08-only")
        self.assertFalse(result["readjudicated"])
        self.assertEqual(result["reason"], "readjudicate_source_not_done_review_row")

    def test_refuses_when_source_not_expanded_8cell(self) -> None:
        # A done Q10_NEWS REVIEW whose aggregate is cell_execution_failed, not
        # the expanded_7x4_matrix_required expansion request.
        self._seed_source(
            tag="ee55",
            source_id="src-ee55",
            aggregate=_nonlock_review("cell_execution_failed"),
        )
        result = farmctl.readjudicate_news_8cell(self.root, "src-ee55")
        self.assertFalse(result["readjudicated"])
        self.assertEqual(result["reason"], "readjudicate_source_not_expanded_8cell")

    def test_refuses_when_cell_aggregates_missing(self) -> None:
        self._seed_source(tag="ff66", source_id="src-ff66", write_evidence=False)
        result = farmctl.readjudicate_news_8cell(self.root, "src-ff66")
        self.assertFalse(result["readjudicated"])
        self.assertEqual(result["reason"], "readjudicate_cell_aggregates_missing")

    def test_refuses_when_new_rule_still_review(self) -> None:
        # A news/event strategy keeps the 7x4 requirement under (e): the sealed
        # evidence still fires material_effect -> the current rule returns
        # REVIEW_REQUIRED, so no successor is minted.
        self._seed_source(
            tag="gg77", source_id="src-gg77", evidence_locks=False, news_or_event=True
        )
        result = farmctl.readjudicate_news_8cell(self.root, "src-gg77", apply=True)
        self.assertFalse(result["readjudicated"])
        self.assertEqual(result["reason"], "readjudicate_new_rule_still_review")
        self.assertEqual(result["readjudicated_verdict"], "REVIEW_REQUIRED")
        with closing(farmctl.connect(self.root)) as conn:
            successors = conn.execute(
                "SELECT count(*) FROM work_items WHERE phase=? AND verdict='CONFIG_LOCKED'",
                (farmctl._NEWS_PHASE,),
            ).fetchone()[0]
        self.assertEqual(successors, 0)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
