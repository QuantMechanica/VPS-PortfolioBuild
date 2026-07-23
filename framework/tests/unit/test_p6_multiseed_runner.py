import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts.p6_multiseed import run_p6_multiseed


class P6MultiSeedRunnerTests(unittest.TestCase):
    def _write_seed(self, seed_dir: Path, seed: int, pf: float, seed_pass: bool, trades: int) -> None:
        payload = {
            "profit_factor": pf,
            "seed_pass": seed_pass,
            "trade_count": trades,
        }
        (seed_dir / f"seed_{seed}.json").write_text(json.dumps(payload), encoding="utf-8")

    def test_multiseed_mixed_when_majority_passes_but_one_pf_below_one(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            seed_dir = root / "seed_metrics"
            out_dir = root / "reports"
            seed_dir.mkdir(parents=True, exist_ok=True)

            self._write_seed(seed_dir, 42, 1.30, True, 240)
            self._write_seed(seed_dir, 17, 1.18, True, 198)
            self._write_seed(seed_dir, 99, 0.95, True, 175)
            self._write_seed(seed_dir, 7, 1.07, False, 112)
            self._write_seed(seed_dir, 2026, 1.02, False, 104)

            result = run_p6_multiseed(
                ea_id="QM5_1001",
                seeds=[42, 17, 99, 7, 2026],
                symbol="EURUSD.DWX",
                seed_metrics_dir=seed_dir,
                output_root=out_dir,
            )

            self.assertEqual(result["verdict"], "MULTI_SEED_MIXED")
            self.assertEqual(result["details"]["pass_count"], 3)
            self.assertTrue(result["details"]["has_pf_below_one"])
            self.assertTrue(Path(result["evidence_path"]).exists())

    def test_multiseed_waiver_when_seed_evidence_missing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            seed_dir = root / "seed_metrics"
            out_dir = root / "reports"
            seed_dir.mkdir(parents=True, exist_ok=True)

            self._write_seed(seed_dir, 42, 1.20, True, 220)
            self._write_seed(seed_dir, 17, 1.10, True, 210)
            # Seed 99 intentionally missing.
            self._write_seed(seed_dir, 7, 1.05, True, 200)
            self._write_seed(seed_dir, 2026, 1.01, True, 180)

            result = run_p6_multiseed(
                ea_id="QM5_1001",
                seeds=[42, 17, 99, 7, 2026],
                symbol="EURUSD.DWX",
                seed_metrics_dir=seed_dir,
                output_root=out_dir,
            )

            self.assertEqual(result["verdict"], "MULTI_SEED_WAIVER")
            self.assertEqual(result["details"]["missing_evidence_count"], 1)


if __name__ == "__main__":
    unittest.main()
