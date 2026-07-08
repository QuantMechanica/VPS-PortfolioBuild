import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class BuildBacklogDedupTests(unittest.TestCase):
    def _seed_pending_build_with_q02_work(
        self,
        root: Path,
        repo_root: Path,
        *,
        payload_extra: dict[str, object] | None = None,
    ) -> tuple[dict[str, object], str]:
        ea_id = "QM5_9999"
        slug = "demo"
        label = f"{ea_id}_{slug}"
        ea_dir = repo_root / "framework" / "EAs" / label
        ea_dir.mkdir(parents=True)
        (ea_dir / f"{label}.ex5").write_text("compiled", encoding="utf-8")

        farmctl.init_db(root)
        now = farmctl.utc_now()
        payload: dict[str, object] = {
            "ea_id": ea_id,
            "slug": slug,
            "ea_dir": str(ea_dir),
        }
        if payload_extra:
            payload.update(payload_extra)

        with farmctl.connect(root) as conn:
            conn.execute(
                """
                INSERT INTO tasks
                  (id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
                VALUES
                  ('build-duplicate', 'build_ea', 'pending', NULL, ?, ?, ?, ?)
                """,
                (ea_id, json.dumps(payload, sort_keys=True), now, now),
            )
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES
                  ('wi-q02', 'backtest', 'Q02', ?, 'EURUSD.DWX', 'sets/demo.set',
                   'pending', NULL, 0, NULL, NULL, NULL, '{}', ?, ?)
                """,
                (ea_id, now, now),
            )
        return payload, "build-duplicate"

    def test_blocks_plain_pending_build_when_ea_already_has_pipeline_work(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            old_framework_eas_dir = farmctl.FRAMEWORK_EAS_DIR
            try:
                farmctl.FRAMEWORK_EAS_DIR = repo_root / "framework" / "EAs"
                payload, task_id = self._seed_pending_build_with_q02_work(root, repo_root)

                with farmctl.connect(root) as conn:
                    row = conn.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
                    blocked = farmctl._block_duplicate_pending_build_if_pipelined(conn, row, payload)

                    self.assertIsNotNone(blocked)
                    self.assertEqual(blocked["reason"], "duplicate_build_task_existing_pipeline_work")
                    task = conn.execute(
                        "SELECT status, payload_json FROM tasks WHERE id=?", (task_id,)
                    ).fetchone()
                    updated_payload = json.loads(task["payload_json"])
                    self.assertEqual(task["status"], "blocked")
                    self.assertEqual(
                        updated_payload["blocked_reason"],
                        "duplicate_build_task_existing_pipeline_work",
                    )
                    self.assertEqual(updated_payload["duplicate_pipeline_work_item_count"], 1)
            finally:
                farmctl.FRAMEWORK_EAS_DIR = old_framework_eas_dir

    def test_explicit_rework_build_is_not_blocked_by_existing_pipeline_work(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            old_framework_eas_dir = farmctl.FRAMEWORK_EAS_DIR
            try:
                farmctl.FRAMEWORK_EAS_DIR = repo_root / "framework" / "EAs"
                payload, task_id = self._seed_pending_build_with_q02_work(
                    root,
                    repo_root,
                    payload_extra={"codex_review_rework": True},
                )

                with farmctl.connect(root) as conn:
                    row = conn.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
                    blocked = farmctl._block_duplicate_pending_build_if_pipelined(conn, row, payload)

                    self.assertIsNone(blocked)
                    status = conn.execute("SELECT status FROM tasks WHERE id=?", (task_id,)).fetchone()[0]
                    self.assertEqual(status, "pending")
            finally:
                farmctl.FRAMEWORK_EAS_DIR = old_framework_eas_dir


if __name__ == "__main__":
    unittest.main()
