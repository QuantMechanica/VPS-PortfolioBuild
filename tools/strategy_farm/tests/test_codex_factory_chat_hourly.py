from datetime import datetime, timedelta, timezone
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import subprocess
import unittest
from tempfile import TemporaryDirectory
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import codex_factory_chat_hourly as hourly


class HourlyChatTests(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[3] / "scratch"
        scratch.mkdir(exist_ok=True)
        self.temporary = TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        queue_db = root / "queue.sqlite"
        with closing(sqlite3.connect(queue_db, isolation_level=None)) as db:
            db.execute("CREATE TABLE queued_items (thread_id TEXT, payload_json TEXT)")
        prompt = root / "prompt.md"
        prompt.write_text("Prüfe aktuelle Evidenz und berichte hier.", encoding="utf-8")
        self.config = dict(thread_id="01a0c58a-454a-76d3-998d-a26f15f34610",
                           state_dir=str(root / "state"), queue_db=str(queue_db),
                           prompt_file=str(prompt), codex_exe="codex.exe", repo_root=str(root))
        self.now = datetime(2026, 9, 22, 10, 0, tzinfo=timezone.utc)
        self.calls = []

    def runner(self, command, **kwargs):
        self.calls.append((command, kwargs))
        return subprocess.CompletedProcess(command, 0, "Queued message receipt", "")

    def test_explicit_thread_unicode_prompt_and_once_per_hour(self):
        self.assertEqual(hourly.dispatch(self.config, self.now, self.runner)["status"], "queued")
        self.assertEqual(hourly.dispatch(self.config, self.now + timedelta(minutes=30), self.runner)["status"], "skipped_same_hour")
        self.assertEqual(hourly.dispatch(self.config, self.now + timedelta(hours=1), self.runner)["status"], "queued")
        self.assertEqual(len(self.calls), 2)
        command, kwargs = self.calls[0]
        self.assertEqual(command[:4], ["codex.exe", "queue", "--thread", self.config["thread_id"]])
        self.assertIn("Prüfe aktuelle", command[-1])
        self.assertNotIn("shell", kwargs)
        self.assertEqual(kwargs["timeout"], 45)

    def test_pending_reminder_prevents_offline_backlog_without_touching_queue(self):
        with closing(sqlite3.connect(self.config["queue_db"], isolation_level=None)) as db:
            db.execute("INSERT INTO queued_items VALUES (?,?)", (self.config["thread_id"], hourly.MARKER))
        for hours in (0, 1, 24):
            result = hourly.dispatch(self.config, self.now + timedelta(hours=hours), self.runner)
            self.assertEqual(result["status"], "skipped_pending_reminder")
        self.assertEqual(self.calls, [])
        with closing(sqlite3.connect(self.config["queue_db"], isolation_level=None)) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM queued_items").fetchone()[0], 1)

    def test_other_thread_does_not_suppress_this_thread(self):
        with closing(sqlite3.connect(self.config["queue_db"], isolation_level=None)) as db:
            db.execute("INSERT INTO queued_items VALUES (?,?)", ("another-thread", hourly.MARKER))
        self.assertEqual(hourly.dispatch(self.config, self.now, self.runner)["status"], "queued")

    def test_ambiguous_timeout_is_reserved_without_duplicate_retry(self):
        def timeout(command, **kwargs):
            raise subprocess.TimeoutExpired(command, 45)
        self.assertEqual(hourly.dispatch(self.config, self.now, timeout)["status"], "delivery_unknown")
        self.assertEqual(hourly.dispatch(self.config, self.now, self.runner)["status"], "skipped_same_hour")
        self.assertEqual(self.calls, [])

    def test_cli_error_is_not_delivery_success(self):
        def failed(command, **kwargs):
            return subprocess.CompletedProcess(command, 1, "", "thread unavailable")
        result = hourly.dispatch(self.config, self.now, failed)
        self.assertEqual(result["status"], "queue_error")
        state = json.loads((Path(self.config["state_dir"]) / "dispatch_state.json").read_text())
        self.assertEqual(state["exit_code"], 1)

    def test_unknown_queue_schema_fails_closed(self):
        with closing(sqlite3.connect(self.config["queue_db"], isolation_level=None)) as db:
            db.execute("DROP TABLE queued_items")
        with self.assertRaises(sqlite3.OperationalError):
            hourly.dispatch(self.config, self.now, self.runner)
        self.assertEqual(self.calls, [])

    def test_dst_repeated_wall_hour_gets_distinct_utc_buckets(self):
        summer = datetime(2026, 10, 25, 2, 0, tzinfo=timezone(timedelta(hours=2)))
        winter = datetime(2026, 10, 25, 2, 0, tzinfo=timezone(timedelta(hours=1)))
        self.assertNotEqual(hourly.utc_bucket(summer), hourly.utc_bucket(winter))
        self.assertEqual(hourly.utc_bucket(summer), hourly.utc_bucket(summer.astimezone(timezone.utc)))

    def test_process_lock_cannot_overlap_and_releases(self):
        path = Path(self.config["state_dir"]) / "test.lock"
        with hourly.process_lock(path):
            with self.assertRaises(OSError):
                with hourly.process_lock(path):
                    self.fail("second dispatch acquired the lock")
        with hourly.process_lock(path):
            pass


if __name__ == "__main__":
    unittest.main()
