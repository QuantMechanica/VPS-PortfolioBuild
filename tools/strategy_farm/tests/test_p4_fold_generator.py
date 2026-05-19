from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "framework" / "scripts" / "p4_fold_generator.py"
CSV_COLUMNS = ["ea_id", "fold_id", "regime", "dev_start", "dev_end", "oos_start", "oos_end"]


def _creationflags() -> int:
    if sys.platform == "win32":
        return subprocess.CREATE_NO_WINDOW
    return 0


class P4FoldGeneratorTests(unittest.TestCase):
    def _run_generator(self, out_prefix: Path) -> list[dict[str, str]]:
        cmd = [
            sys.executable,
            str(SCRIPT),
            "--ea",
            "QM5_1056",
            "--out-prefix",
            str(out_prefix),
            "--train-from-year",
            "2017",
            "--oos-from-year",
            "2023",
            "--oos-to-year",
            "2025",
            "--fold-months",
            "6",
            "--embargo-days",
            "7",
            "--min-folds",
            "6",
        ]
        proc = subprocess.run(
            cmd,
            cwd=str(REPO),
            capture_output=True,
            text=True,
            creationflags=_creationflags(),
        )
        self.assertEqual(proc.returncode, 0, msg=f"stdout={proc.stdout}\nstderr={proc.stderr}")

        csv_path = Path(proc.stdout.strip().splitlines()[-1])
        self.assertTrue(csv_path.is_absolute())
        self.assertEqual(csv_path, out_prefix.resolve() / "QM5_1056" / "P4" / "walk_forward_folds.csv")
        self.assertTrue(csv_path.exists(), msg=f"missing folds csv: {csv_path}")
        with csv_path.open("r", encoding="utf-8", newline="") as handle:
            return [dict(row) for row in csv.DictReader(handle)]

    def test_six_anchored_folds_produced(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rows = self._run_generator(Path(tmp))

        self.assertEqual(len(rows), 6)
        self.assertEqual(rows[0]["fold_id"], "F1")
        self.assertEqual(rows[-1]["fold_id"], "F6")
        self.assertEqual(rows[0]["oos_start"], "2023-01-01")
        self.assertEqual(rows[0]["oos_end"], "2023-06-30")
        self.assertEqual(rows[-1]["oos_start"], "2025-07-01")
        self.assertEqual(rows[-1]["oos_end"], "2025-12-31")
        self.assertTrue(all(row["regime"] == "UNCLASSIFIED" for row in rows))

    def test_embargo_respected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rows = self._run_generator(Path(tmp))

        for row in rows:
            dev_end = date.fromisoformat(row["dev_end"])
            oos_start = date.fromisoformat(row["oos_start"])
            self.assertLess(dev_end, oos_start)
            self.assertLess(dev_end + timedelta(days=7), oos_start)
            self.assertGreaterEqual((oos_start - dev_end).days, 7)

        self.assertEqual(rows[0]["dev_end"], "2022-12-24")
        self.assertEqual(rows[1]["dev_end"], "2023-06-23")
        self.assertEqual(rows[2]["dev_end"], "2023-12-24")
        self.assertEqual(rows[3]["dev_end"], "2024-06-23")
        self.assertEqual(rows[4]["dev_end"], "2024-12-24")
        self.assertEqual(rows[5]["dev_end"], "2025-06-23")

    def test_anchored_train_start(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rows = self._run_generator(Path(tmp))

        self.assertEqual({row["dev_start"] for row in rows}, {"2017-01-01"})

    def test_csv_columns_exact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_prefix = Path(tmp)
            self._run_generator(out_prefix)
            csv_path = out_prefix.resolve() / "QM5_1056" / "P4" / "walk_forward_folds.csv"

            with csv_path.open("r", encoding="utf-8", newline="") as handle:
                reader = csv.DictReader(handle)
                self.assertEqual(reader.fieldnames, CSV_COLUMNS)


if __name__ == "__main__":
    unittest.main()
