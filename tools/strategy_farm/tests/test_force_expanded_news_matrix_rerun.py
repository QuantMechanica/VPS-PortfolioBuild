"""Tests for `enqueue-backtest --force-expanded-news-matrix`.

The pump authors a full 7x4 news-expansion continuation only for the ORIGINAL
8-cell REVIEW_REQUIRED source; a manual `--append-only-rerun-of <expansion
child>` otherwise produces an 8-cell row (the ordinary target-compliance
scope). This opt-in flag lets an operator recover a done full-matrix child that
lost one cell to infra by minting a fresh row that copies the parent's
expansion identity, so the autoseal re-authors the same 7x4 matrix and the
pump's continuation-dedup treats the row as an existing continuation.
"""

import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import news_gate_service  # noqa: E402


# The exact selection the pump's expansion stage runs to decide whether a
# continuation already exists (farmctl.author_news_expansion_continuations).
_PUMP_EXISTING_CONTINUATION_QUERY = """
    SELECT * FROM work_items
    WHERE json_valid(payload_json)=1
      AND json_extract(payload_json,'$.news_expansion_of_work_item')=?
    ORDER BY created_at DESC,id DESC
"""


class ForceExpandedNewsMatrixRerunTests(unittest.TestCase):
    ORIGINAL_SOURCE_ID = "q10-news-original-8cell-source"
    AGGREGATE_SHA = "a" * 64

    def _build_repo(self, tmp: Path, ea_id: str):
        """Create a canonical EA directory the binding guard authenticates."""
        repo_root = tmp / "repo"
        ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
        sets_dir = ea_dir / "sets"
        sets_dir.mkdir(parents=True)
        (ea_dir / f"{ea_dir.name}.mq5").write_text("// source\n", encoding="utf-8")
        ex5 = ea_dir / f"{ea_dir.name}.ex5"
        ex5.write_bytes(b"compiled-binary")
        setfile = sets_dir / f"{ea_dir.name}_EURUSD.DWX_H4_backtest.set"
        setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
        return repo_root, ea_dir, ex5, setfile

    def _seed_accepted_case(self, root: Path, setfile: Path, ea_id: str):
        """Q08->Q09 lineage plus a done full-matrix Q10_NEWS rerun target."""
        farmctl.init_db(root)
        now = farmctl.utc_now()
        q08_evidence = root / "q08-evidence.json"
        q08_evidence.write_text(json.dumps({"gate": "Q08"}), encoding="utf-8")
        with sqlite3.connect(root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   verdict, attempt_count, evidence_path, payload_json,
                   created_at, updated_at)
                VALUES (?, 'backtest', 'Q08', ?, 'EURUSD.DWX', ?, 'done',
                        'PASS', 0, ?, ?, ?, ?)
                """,
                (
                    "q08-source",
                    ea_id,
                    str(setfile),
                    str(q08_evidence),
                    json.dumps({"verdict_reason": "q08-pass"}, sort_keys=True),
                    now,
                    now,
                ),
            )
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   verdict, attempt_count, evidence_path, payload_json,
                   created_at, updated_at)
                VALUES (?, 'backtest', 'Q09', ?, 'EURUSD.DWX', ?, 'done',
                        'PASS', 0, 'q09-evidence.json', ?, ?, ?)
                """,
                (
                    "q09-baseline",
                    ea_id,
                    str(setfile),
                    json.dumps(
                        {"promoted_from_work_item": "q08-source"}, sort_keys=True
                    ),
                    now,
                    now,
                ),
            )
            # The done full-matrix child that lost one cell to infra
            # (cell_execution_failed => REVIEW_REQUIRED). It carries the four
            # expansion identity fields the pump stamped, plus the plan-derived
            # q09_cell_count from its sealed 7x4 plan.
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   verdict, attempt_count, evidence_path, payload_json,
                   created_at, updated_at)
                VALUES (?, 'backtest', 'Q10_NEWS', ?, 'EURUSD.DWX', ?, 'done',
                        'REVIEW_REQUIRED', 0, 'q10-news-evidence.json', ?, ?, ?)
                """,
                (
                    "q10-news-child",
                    ea_id,
                    str(setfile),
                    json.dumps(
                        {
                            "force_expanded_news_matrix": True,
                            "news_expansion_of_work_item": self.ORIGINAL_SOURCE_ID,
                            "news_expansion_source_aggregate_sha256": self.AGGREGATE_SHA,
                            "news_expansion_reason_code": news_gate_service.EXPANSION_REASON,
                            "q09_cell_count": 29,
                            "verdict_reason": "cell_execution_failed",
                        },
                        sort_keys=True,
                    ),
                    now,
                    now,
                ),
            )
            conn.commit()

    def test_refused_on_non_news_phase(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            result = farmctl.enqueue_cascade_backtest_for_ea(
                root,
                "QM5_9994",
                "Q06",
                predecessor_work_item_id="q05-source",
                append_only_rerun_of="q06-historical",
                rerun_reason="does not matter, refused first",
                force_expanded_news_matrix=True,
            )
        self.assertFalse(result["enqueued"])
        self.assertEqual(
            result["reason"], "force_expanded_news_matrix_requires_news_phase"
        )

    def test_refused_when_rerun_of_lacks_expansion_identity(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                # A done Q10_NEWS row that is NOT a full-matrix child: it lacks
                # force_expanded_news_matrix (an ordinary 8-cell rerun target).
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status,
                       verdict, attempt_count, evidence_path, payload_json,
                       created_at, updated_at)
                    VALUES (?, 'backtest', 'Q10_NEWS', 'QM5_9994', 'EURUSD.DWX',
                            '/x.set', 'done', 'REVIEW_REQUIRED', 0, 'e.json', ?, ?, ?)
                    """,
                    (
                        "q10-news-plain",
                        json.dumps({"verdict_reason": "cell_execution_failed"}),
                        now,
                        now,
                    ),
                )
                conn.commit()
            result = farmctl.enqueue_cascade_backtest_for_ea(
                root,
                "QM5_9994",
                "Q10_NEWS",
                predecessor_work_item_id="q09-baseline",
                append_only_rerun_of="q10-news-plain",
                rerun_reason="attempted full-matrix recovery",
                force_expanded_news_matrix=True,
            )
        self.assertFalse(result["enqueued"])
        self.assertEqual(
            result["reason"],
            "force_expanded_news_matrix_rerun_of_missing_expansion_identity",
        )

    def test_refused_when_rerun_of_not_found(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            farmctl.init_db(root)
            result = farmctl.enqueue_cascade_backtest_for_ea(
                root,
                "QM5_9994",
                "Q10_NEWS",
                predecessor_work_item_id="q09-baseline",
                append_only_rerun_of="does-not-exist",
                rerun_reason="attempted full-matrix recovery",
                force_expanded_news_matrix=True,
            )
        self.assertFalse(result["enqueued"])
        self.assertEqual(
            result["reason"], "force_expanded_news_matrix_rerun_of_not_found"
        )

    def test_accepted_copies_identity_and_pump_sees_existing_continuation(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            tmp_path = Path(tmp)
            root = tmp_path / "farm"
            ea_id = "QM5_9994"
            repo_root, _ea_dir, ex5, setfile = self._build_repo(tmp_path, ea_id)
            current_ex5_sha256 = farmctl._sha256_file(ex5)
            self._seed_accepted_case(root, setfile, ea_id)

            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo_root
                result = farmctl.enqueue_cascade_backtest_for_ea(
                    root,
                    ea_id,
                    "Q10_NEWS",
                    predecessor_work_item_id="q09-baseline",
                    append_only_rerun_of="q10-news-child",
                    rerun_reason="recover full 7x4 matrix after single-cell infra loss",
                    expected_current_ex5_sha256=current_ex5_sha256,
                    force_expanded_news_matrix=True,
                )
                # Re-running is idempotent: the append-only dedup still fires.
                repeat = farmctl.enqueue_cascade_backtest_for_ea(
                    root,
                    ea_id,
                    "Q10_NEWS",
                    predecessor_work_item_id="q09-baseline",
                    append_only_rerun_of="q10-news-child",
                    rerun_reason="recover full 7x4 matrix after single-cell infra loss",
                    expected_current_ex5_sha256=current_ex5_sha256,
                    force_expanded_news_matrix=True,
                )
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["enqueued"], result)
            self.assertEqual(len(result["created"]), 1, result)
            new_id = result["created"][0]["id"]
            self.assertEqual(
                result["created"][0]["rerun_of_work_item_id"], "q10-news-child"
            )
            self.assertEqual(repeat["created"], [])
            self.assertEqual(
                repeat["skipped"][0]["reason"], "append_only_rerun_already_exists"
            )

            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.row_factory = sqlite3.Row
                new_row = conn.execute(
                    "SELECT phase, status, verdict, payload_json FROM work_items WHERE id=?",
                    (new_id,),
                ).fetchone()
                # The rerun target row must be preserved untouched.
                target = conn.execute(
                    "SELECT status, verdict FROM work_items WHERE id='q10-news-child'"
                ).fetchone()
                # Reconstruct the pump's expansion-stage decision keyed on the
                # ORIGINAL 8-cell source id.
                existing_rows = conn.execute(
                    _PUMP_EXISTING_CONTINUATION_QUERY, (self.ORIGINAL_SOURCE_ID,)
                ).fetchall()

            self.assertEqual(new_row["phase"], "Q10_NEWS")
            self.assertEqual(new_row["status"], "pending")
            self.assertIsNone(new_row["verdict"])
            self.assertEqual((target["status"], target["verdict"]), ("done", "REVIEW_REQUIRED"))

            payload = json.loads(new_row["payload_json"])
            # The four expansion identity fields are copied from the rerun-of row;
            # news_expansion_of_work_item stays the ORIGINAL 8-cell source id.
            self.assertIs(payload["force_expanded_news_matrix"], True)
            self.assertEqual(
                payload["news_expansion_of_work_item"], self.ORIGINAL_SOURCE_ID
            )
            self.assertEqual(
                payload["news_expansion_source_aggregate_sha256"], self.AGGREGATE_SHA
            )
            self.assertEqual(
                payload["news_expansion_reason_code"], news_gate_service.EXPANSION_REASON
            )
            # q09_cell_count comes from the parent's sealed plan, not a hardcoded 29.
            self.assertEqual(payload["q09_cell_count"], 29)
            self.assertEqual(
                payload["rerun_reason"],
                "recover full 7x4 matrix after single-cell infra loss",
            )
            self.assertEqual(payload["append_only_rerun_of_work_item"], "q10-news-child")

            # The pump's expansion stage: existing = existing_rows[0] if any.
            # With the minted row present it is non-None, so the pump SKIPS
            # rather than minting a second continuation (no double mint).
            existing_ids = {row["id"] for row in existing_rows}
            self.assertIn(new_id, existing_ids)
            self.assertIn("q10-news-child", existing_ids)
            pump_existing = existing_rows[0] if existing_rows else None
            self.assertIsNotNone(pump_existing)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
