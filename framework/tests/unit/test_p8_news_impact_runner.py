from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "framework" / "scripts" / "p8_news_impact.py"
MATRIX_FIXTURE = REPO_ROOT / "framework" / "scripts" / "tests" / "fixtures" / "p8_matrix.csv"


def _run_runner(tmp_path: Path, *, matrix_csv: Path) -> dict:
    args = [
        sys.executable,
        str(RUNNER),
        "--ea",
        "QM5_1001",
        "--out-prefix",
        str(tmp_path),
        "--news-matrix",
        str(matrix_csv),
    ]
    completed = subprocess.run(
        args,
        cwd=str(REPO_ROOT),
        check=True,
        capture_output=True,
        text=True,
    )
    result_path = Path(completed.stdout.strip())
    return json.loads(result_path.read_text(encoding="utf-8"))


class TestP8NewsImpactRunner(unittest.TestCase):
    def test_p8_news_impact_happy_path_selects_off(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _run_runner(Path(tmp), matrix_csv=MATRIX_FIXTURE)

        self.assertEqual(result["phase"], "P8")
        self.assertEqual(result["verdict"], "MODE_SELECTED")
        self.assertEqual(result["details"]["recommended_mode"], "OFF")
        self.assertEqual(result["details"]["recommended_mode_by_symbol"], {"ALL_SYMBOLS": "OFF"})
        self.assertEqual(result["details"]["symbol_results"][0]["eligible_mode_count"], 5)
        self.assertEqual(result["details"]["compliance"]["ftmo_pass"], True)
        self.assertEqual(result["details"]["compliance"]["fiveers_pass"], True)
        self.assertEqual(result["details"]["compliance"]["no_news_pass"], True)
        self.assertEqual(result["details"]["compliance"]["news_only_pass"], True)

    def test_p8_news_impact_alias_no_news_only_normalized(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            matrix_csv = tmp_path / "p8_alias.csv"
            matrix_csv.write_text(
                "\n".join(
                    [
                        "mode,pf,sharpe,drawdown_pct,trades,compliance_ftmo,compliance_5ers,compliance_no_news,compliance_news_only",
                        "off,1.05,0.52,8.9,120,true,true,true,false",
                        "NO_NEWS_ONLY,1.12,0.48,7.3,80,false,false,true,false",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            result = _run_runner(tmp_path, matrix_csv=matrix_csv)

        modes = [row["mode"] for row in result["details"]["matrix"]]
        self.assertEqual(result["verdict"], "MODE_SELECTED")
        self.assertEqual(result["details"]["recommended_mode"], "no_news")
        self.assertEqual(result["details"]["recommended_mode_by_symbol"], {"ALL_SYMBOLS": "no_news"})
        self.assertEqual(modes, ["OFF", "no_news"])

    def test_p8_news_impact_no_eligible_mode_falls_back_to_off(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            matrix_csv = tmp_path / "p8_no_eligible.csv"
            matrix_csv.write_text(
                "\n".join(
                    [
                        "mode,pf,sharpe,drawdown_pct,trades,compliance_ftmo,compliance_5ers,compliance_no_news,compliance_news_only",
                        "OFF,0.95,0.40,9.2,90,true,true,true,false",
                        "PAUSE,0.90,0.30,8.0,0,true,true,true,false",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            result = _run_runner(tmp_path, matrix_csv=matrix_csv)

        self.assertEqual(result["phase"], "P8")
        self.assertEqual(result["verdict"], "NO_ELIGIBLE_MODE")
        self.assertEqual(result["details"]["recommended_mode"], "OFF")
        self.assertEqual(result["details"]["symbol_results"][0]["eligible_mode_count"], 0)

    def test_p8_news_impact_per_symbol_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            matrix_csv = tmp_path / "p8_per_symbol.csv"
            matrix_csv.write_text(
                "\n".join(
                    [
                        "symbol,mode,pf,sharpe,drawdown_pct,trades,compliance_ftmo,compliance_5ers,compliance_no_news,compliance_news_only",
                        "EURUSD.DWX,OFF,1.04,0.61,9.5,160,true,true,true,false",
                        "EURUSD.DWX,PAUSE,1.09,0.58,8.8,150,true,true,true,false",
                        "XAUUSD.DWX,OFF,0.98,0.49,11.2,120,true,true,true,false",
                        "XAUUSD.DWX,FTMO_PAUSE,1.05,0.57,10.1,130,true,true,true,false",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            result = _run_runner(tmp_path, matrix_csv=matrix_csv)

        self.assertEqual(result["verdict"], "MODE_SELECTED")
        self.assertEqual(result["details"]["recommended_mode"], None)
        self.assertEqual(
            result["details"]["recommended_mode_by_symbol"],
            {"EURUSD.DWX": "PAUSE", "XAUUSD.DWX": "FTMO_PAUSE"},
        )
        self.assertEqual(len(result["details"]["symbol_results"]), 2)


if __name__ == "__main__":
    unittest.main()
