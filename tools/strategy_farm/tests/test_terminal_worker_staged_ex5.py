import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402


class StagedEx5Tests(unittest.TestCase):
    def test_post_run_hashes_are_persisted_in_summary(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            binary = root / "probe.ex5"
            binary.write_bytes(b"historical binary")
            digest = hashlib.sha256(binary.read_bytes()).hexdigest()
            summary = root / "reports" / "QM5_9936" / "run" / "summary.json"
            summary.parent.mkdir(parents=True)
            summary.write_text('{"verdict":"PASS"}', encoding="utf-8")
            payload = {
                "report_root": str(root / "reports"),
                "staged_ex5": {
                    "source_path": str(binary),
                    "destination_path": str(binary),
                    "required_sha256": digest,
                    "pre_run_sha256": digest,
                },
            }

            result = terminal_worker._verify_and_record_staged_ex5(payload)

            self.assertTrue(result["verified"])
            recorded = json.loads(summary.read_text(encoding="utf-8"))
            self.assertEqual(recorded["staged_ex5"]["pre_run_sha256"], digest)
            self.assertEqual(recorded["staged_ex5"]["post_run_sha256"], digest)

    def test_post_run_hash_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            binary = Path(tmp) / "probe.ex5"
            binary.write_bytes(b"changed binary")
            payload = {
                "staged_ex5": {
                    "destination_path": str(binary),
                    "required_sha256": "0" * 64,
                    "pre_run_sha256": "0" * 64,
                },
            }
            with self.assertRaisesRegex(ValueError, "post_run_sha256_mismatch"):
                terminal_worker._verify_and_record_staged_ex5(payload)


if __name__ == "__main__":
    unittest.main()
