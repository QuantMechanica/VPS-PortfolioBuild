from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from framework.scripts.resolve_backtest_target import BACKTEST_SETFILE_ERROR, _reject_missing_setfile


class ResolveBacktestTargetTests(unittest.TestCase):
    def test_rejects_missing_setfile_field(self) -> None:
        rejected = _reject_missing_setfile({"ea_id": "QM5_1001"})
        self.assertIsNotNone(rejected)
        self.assertEqual(rejected["error_code"], BACKTEST_SETFILE_ERROR)

    def test_rejects_nonexistent_relative_setfile(self) -> None:
        rejected = _reject_missing_setfile({"setfile_path": "does/not/exist.set"})
        self.assertIsNotNone(rejected)
        self.assertEqual(rejected["error_code"], BACKTEST_SETFILE_ERROR)

    def test_accepts_existing_absolute_setfile(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            setfile = Path(tmp_dir) / "ok.set"
            setfile.write_text("ENV=backtest\n", encoding="utf-8")
            rejected = _reject_missing_setfile({"setfile_path": str(setfile)})
        self.assertIsNone(rejected)


if __name__ == "__main__":
    unittest.main()
