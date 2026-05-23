from __future__ import annotations

import csv
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "framework" / "scripts"


def _write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def _write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload), encoding="utf-8")


def _run_python(script: Path, args: list[str], cwd: Path) -> dict:
    cmd = ["python", str(script)] + args
    proc = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
    if proc.returncode != 0:
        raise AssertionError(f"cmd={' '.join(cmd)}\nstdout={proc.stdout}\nstderr={proc.stderr}")
    result_path = Path(proc.stdout.strip().splitlines()[-1])
    if not result_path.exists():
        raise AssertionError(f"missing result file: {result_path}\nstdout={proc.stdout}\nstderr={proc.stderr}")
    return json.loads(result_path.read_text(encoding="utf-8"))


class P35VerdictSemanticsTests(unittest.TestCase):
    def test_p35_verdict_matrix(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            baseline = root / "baseline.csv"
            csr = root / "csr.csv"

            _write_csv(
                baseline,
                rows=[{"symbol": "EURUSD", "verdict": "FAIL"}],
                fieldnames=["symbol", "verdict"],
            )
            no_pass = _run_python(
                SCRIPTS / "p35_csr_runner.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--baseline-csv", str(baseline)],
                REPO,
            )
            self.assertEqual(no_pass["verdict"], "NO_PASS_BASELINE")

            _write_csv(
                baseline,
                rows=[{"symbol": "EURUSD", "verdict": "PASS"}],
                fieldnames=["symbol", "verdict"],
            )
            needs_rerun = _run_python(
                SCRIPTS / "p35_csr_runner.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--baseline-csv", str(baseline)],
                REPO,
            )
            self.assertEqual(needs_rerun["verdict"], "NEEDS_RERUN")

            _write_csv(
                csr,
                rows=[{"symbol": "US30", "verdict": "PASS"}],
                fieldnames=["symbol", "verdict"],
            )
            post_rerun_pass = _run_python(
                SCRIPTS / "p35_csr_runner.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--baseline-csv", str(baseline), "--csr-results-csv", str(csr)],
                REPO,
            )
            self.assertEqual(post_rerun_pass["verdict"], "PASS")

            _write_csv(
                csr,
                rows=[{"symbol": "GBPUSD", "verdict": "PASS"}],
                fieldnames=["symbol", "verdict"],
            )
            post_rerun_fail = _run_python(
                SCRIPTS / "p35_csr_runner.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--baseline-csv", str(baseline), "--csr-results-csv", str(csr)],
                REPO,
            )
            self.assertEqual(post_rerun_fail["verdict"], "FAIL")

            _write_csv(
                baseline,
                rows=[{"symbol": "EURUSD", "verdict": "PASS"}, {"symbol": "US30", "verdict": "PASS"}],
                fieldnames=["symbol", "verdict"],
            )
            auto_pass = _run_python(
                SCRIPTS / "p35_csr_runner.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--baseline-csv", str(baseline)],
                REPO,
            )
            self.assertEqual(auto_pass["verdict"], "AUTO_PASS")


class P5bVerdictSemanticsTests(unittest.TestCase):
    def test_p5b_strict_proxy_and_fail_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            trials = root / "trials.csv"
            calibration = root / "calibration.json"
            _write_json(
                calibration,
                {
                    "measurement_status": "ready",
                    "symbols": {
                        "EURUSD.DWX": {
                            "min_remaining_cushion_pct": 0.1,
                            "recovery_fraction_limit": 0.9,
                        }
                    },
                },
            )

            _write_csv(
                trials,
                rows=[{"symbol": "EURUSD.DWX", "breach_count": "0"} for _ in range(10)],
                fieldnames=["symbol", "breach_count"],
            )
            strict_pass = _run_python(
                SCRIPTS / "p5b_calibrated_noise.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--trials-csv", str(trials), "--calibration-json", str(calibration), "--symbol", "EURUSD.DWX"],
                REPO,
            )
            self.assertEqual(strict_pass["verdict"], "PASS")

            _write_csv(
                trials,
                rows=[{"symbol": "EURUSD.DWX", "breach_count": "0"} for _ in range(6)]
                + [{"symbol": "EURUSD.DWX", "breach_count": "1"} for _ in range(2)]
                + [{"symbol": "EURUSD.DWX", "breach_count": "2"} for _ in range(2)],
                fieldnames=["symbol", "breach_count"],
            )
            yellow = _run_python(
                SCRIPTS / "p5b_calibrated_noise.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--trials-csv", str(trials), "--calibration-json", str(calibration), "--symbol", "EURUSD.DWX"],
                REPO,
            )
            self.assertEqual(yellow["verdict"], "YELLOW")

            _write_csv(
                trials,
                rows=[{"symbol": "EURUSD.DWX", "breach_count": "2"} for _ in range(10)],
                fieldnames=["symbol", "breach_count"],
            )
            fail = _run_python(
                SCRIPTS / "p5b_calibrated_noise.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--trials-csv", str(trials), "--calibration-json", str(calibration), "--symbol", "EURUSD.DWX"],
                REPO,
            )
            self.assertEqual(fail["verdict"], "FAIL")


class P5VerdictSemanticsTests(unittest.TestCase):
    def test_p5_thresholds_and_calibration_readiness(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            calibration = root / "calibration.json"
            clean = root / "clean.json"
            stress = root / "stress.json"

            def run_case(calibration_payload: dict, clean_payload: dict, stress_payload: dict) -> dict:
                _write_json(calibration, calibration_payload)
                _write_json(clean, clean_payload)
                _write_json(stress, stress_payload)
                return _run_python(
                    SCRIPTS / "p5_stress_runner.py",
                    [
                        "--ea",
                        "QM5_1001",
                        "--out-prefix",
                        str(out),
                        "--symbol",
                        "EURUSD.DWX",
                        "--calibration-json",
                        str(calibration),
                        "--clean-metrics-json",
                        str(clean),
                        "--stress-metrics-json",
                        str(stress),
                    ],
                    REPO,
                )

            ready_cal = {
                "measurement_status": "MEASURED",
                "symbols": {
                    "EURUSD.DWX": {
                        "commission_cents_per_lot": 7,
                        "latency_ms": {"avg": 50, "p95": 120},
                        "slippage_points": {"avg": 2, "p95": 5},
                        "spread_points": {"median": 10, "p95": 25},
                    }
                },
            }

            not_ready = run_case(
                {"measurement_status": "PENDING", "symbols": {}},
                {"symbol": "EURUSD.DWX", "pf": 1.4, "trade_count": 100},
                {"symbol": "EURUSD.DWX", "pf": 1.2, "trade_count": 90},
            )
            self.assertEqual(not_ready["verdict"], "FAIL")
            self.assertIn("pending", not_ready["criterion"].lower())

            pf_fail = run_case(
                ready_cal,
                {"symbol": "EURUSD.DWX", "pf": 1.4, "trade_count": 100},
                {"symbol": "EURUSD.DWX", "pf": 1.0, "trade_count": 90},
            )
            self.assertEqual(pf_fail["verdict"], "FAIL")
            self.assertIn("PF", pf_fail["criterion"])

            retention_fail = run_case(
                ready_cal,
                {"symbol": "EURUSD.DWX", "pf": 1.4, "trade_count": 100},
                {"symbol": "EURUSD.DWX", "pf": 1.1, "trade_count": 49},
            )
            self.assertEqual(retention_fail["verdict"], "FAIL")
            self.assertIn("50%", retention_fail["criterion"])

            p5_pass = run_case(
                ready_cal,
                {"symbol": "EURUSD.DWX", "pf": 1.4, "trade_count": 100},
                {"symbol": "EURUSD.DWX", "pf": 1.1, "trade_count": 50},
            )
            self.assertEqual(p5_pass["verdict"], "PASS")

            bad_type_cal = {
                "measurement_status": "MEASURED",
                "symbols": {
                    "EURUSD.DWX": {
                        "commission_cents_per_lot": 7,
                        "latency_ms": {"avg": "bad", "p95": 120},
                        "slippage_points": {"avg": 2, "p95": 5},
                        "spread_points": {"median": 10, "p95": 25},
                    }
                },
            }
            type_fail = run_case(
                bad_type_cal,
                {"symbol": "EURUSD.DWX", "pf": 1.4, "trade_count": 100},
                {"symbol": "EURUSD.DWX", "pf": 1.1, "trade_count": 90},
            )
            self.assertEqual(type_fail["verdict"], "FAIL")
            self.assertIn("must be numeric", type_fail["criterion"])


class P6VerdictSemanticsTests(unittest.TestCase):
    def test_p6_verdict_matrix(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            seeds_csv = root / "seeds.csv"
            seeds = "42,17,99,7,2026"
            fieldnames = ["seed", "seed_pass", "profit_factor", "trade_count"]

            _write_csv(seeds_csv, rows=[], fieldnames=fieldnames)
            waiver = _run_python(
                SCRIPTS / "p6_multiseed.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--seeds-csv", str(seeds_csv), "--seeds", seeds],
                REPO,
            )
            self.assertEqual(waiver["verdict"], "MULTI_SEED_WAIVER")

            _write_csv(
                seeds_csv,
                rows=[
                    {"seed": "42", "seed_pass": "PASS", "profit_factor": "1.2", "trade_count": "100"},
                    {"seed": "17", "seed_pass": "PASS", "profit_factor": "1.1", "trade_count": "90"},
                    {"seed": "99", "seed_pass": "PASS", "profit_factor": "1.3", "trade_count": "95"},
                ],
                fieldnames=fieldnames,
            )
            p6_pass = _run_python(
                SCRIPTS / "p6_multiseed.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--seeds-csv", str(seeds_csv), "--seeds", seeds],
                REPO,
            )
            self.assertEqual(p6_pass["verdict"], "MULTI_SEED_PASS")

            _write_csv(
                seeds_csv,
                rows=[
                    {"seed": "42", "seed_pass": "PASS", "profit_factor": "1.2", "trade_count": "100"},
                    {"seed": "17", "seed_pass": "PASS", "profit_factor": "0.9", "trade_count": "90"},
                    {"seed": "99", "seed_pass": "PASS", "profit_factor": "1.3", "trade_count": "95"},
                ],
                fieldnames=fieldnames,
            )
            mixed = _run_python(
                SCRIPTS / "p6_multiseed.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--seeds-csv", str(seeds_csv), "--seeds", seeds],
                REPO,
            )
            self.assertEqual(mixed["verdict"], "MULTI_SEED_FAIL")

            _write_csv(
                seeds_csv,
                rows=[
                    {"seed": "42", "seed_pass": "PASS", "profit_factor": "1.2", "trade_count": "100"},
                    {"seed": "17", "seed_pass": "FAIL", "profit_factor": "1.1", "trade_count": "90"},
                    {"seed": "99", "seed_pass": "FAIL", "profit_factor": "1.3", "trade_count": "95"},
                ],
                fieldnames=fieldnames,
            )
            fail = _run_python(
                SCRIPTS / "p6_multiseed.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--seeds-csv", str(seeds_csv), "--seeds", seeds],
                REPO,
            )
            self.assertEqual(fail["verdict"], "MULTI_SEED_FAIL")


class P7VerdictSemanticsTests(unittest.TestCase):
    def test_p7_hard_gate_order(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            sweep_csv = root / "sweep.csv"
            ms_csv = root / "multiseed.csv"

            def run_case(
                *,
                trades: str,
                pbo: str,
                dsr: str,
                mc_p: str,
                fdr_q: str,
            ) -> dict:
                _write_csv(
                    sweep_csv,
                    rows=[{"trade_count": trades, "pbo_pct": pbo, "dsr": dsr}],
                    fieldnames=["trade_count", "pbo_pct", "dsr"],
                )
                _write_csv(
                    ms_csv,
                    rows=[{"mc_pvalue": mc_p, "fdr_q": fdr_q}],
                    fieldnames=["mc_pvalue", "fdr_q"],
                )
                return _run_python(
                    SCRIPTS / "p7_statval.py",
                    ["--ea", "QM5_1001", "--out-prefix", str(out), "--sweep-pass-rows", str(sweep_csv), "--multiseed-rows", str(ms_csv)],
                    REPO,
                )

            ok = run_case(trades="250", pbo="2.0", dsr="0.3", mc_p="0.01", fdr_q="0.05")
            self.assertEqual(ok["verdict"], "PASS")

            t_fail = run_case(trades="199", pbo="2.0", dsr="0.3", mc_p="0.01", fdr_q="0.05")
            self.assertEqual(t_fail["verdict"], "FAIL")
            self.assertIn("T < 200", t_fail["criterion"])

            pbo_fail = run_case(trades="250", pbo="5.0", dsr="0.3", mc_p="0.01", fdr_q="0.05")
            self.assertEqual(pbo_fail["verdict"], "FAIL")
            self.assertIn("PBO", pbo_fail["criterion"])

            dsr_fail = run_case(trades="250", pbo="2.0", dsr="0.0", mc_p="0.01", fdr_q="0.05")
            self.assertEqual(dsr_fail["verdict"], "FAIL")
            self.assertIn("DSR", dsr_fail["criterion"])

            mc_fail = run_case(trades="250", pbo="2.0", dsr="0.3", mc_p="0.05", fdr_q="0.05")
            self.assertEqual(mc_fail["verdict"], "FAIL")
            self.assertIn("MC permutation", mc_fail["criterion"])

            fdr_fail = run_case(trades="250", pbo="2.0", dsr="0.3", mc_p="0.01", fdr_q="0.10")
            self.assertEqual(fdr_fail["verdict"], "FAIL")
            self.assertIn("FDR", fdr_fail["criterion"])


class P8VerdictSemanticsTests(unittest.TestCase):
    def test_p8_mode_selection_and_no_eligible(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            matrix = root / "matrix.csv"
            fieldnames = [
                "symbol",
                "mode",
                "pf",
                "sharpe",
                "drawdown_pct",
                "trades",
                "compliance_ftmo",
                "compliance_5ers",
                "compliance_no_news",
                "compliance_news_only",
            ]

            _write_csv(
                matrix,
                rows=[
                    {
                        "symbol": "EURUSD.DWX",
                        "mode": "OFF",
                        "pf": "1.10",
                        "sharpe": "0.9",
                        "drawdown_pct": "10",
                        "trades": "50",
                        "compliance_ftmo": "1",
                        "compliance_5ers": "1",
                        "compliance_no_news": "1",
                        "compliance_news_only": "0",
                    },
                    {
                        "symbol": "EURUSD.DWX",
                        "mode": "PAUSE",
                        "pf": "1.20",
                        "sharpe": "0.8",
                        "drawdown_pct": "11",
                        "trades": "40",
                        "compliance_ftmo": "1",
                        "compliance_5ers": "1",
                        "compliance_no_news": "0",
                        "compliance_news_only": "1",
                    },
                ],
                fieldnames=fieldnames,
            )
            selected = _run_python(
                SCRIPTS / "p8_news_impact.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--news-matrix", str(matrix), "--modes", "OFF,PAUSE"],
                REPO,
            )
            self.assertEqual(selected["verdict"], "MODE_SELECTED")
            self.assertEqual(selected["details"]["recommended_mode_by_symbol"]["EURUSD.DWX"], "PAUSE")

            _write_csv(
                matrix,
                rows=[
                    {
                        "symbol": "EURUSD.DWX",
                        "mode": "OFF",
                        "pf": "0.95",
                        "sharpe": "0.1",
                        "drawdown_pct": "20",
                        "trades": "5",
                        "compliance_ftmo": "0",
                        "compliance_5ers": "0",
                        "compliance_no_news": "0",
                        "compliance_news_only": "0",
                    }
                ],
                fieldnames=fieldnames,
            )
            no_eligible = _run_python(
                SCRIPTS / "p8_news_impact.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--news-matrix", str(matrix), "--modes", "OFF"],
                REPO,
            )
            self.assertEqual(no_eligible["verdict"], "NO_ELIGIBLE_MODE")
            self.assertEqual(no_eligible["details"]["recommended_mode_by_symbol"]["EURUSD.DWX"], "OFF")

            _write_csv(
                matrix,
                rows=[
                    {
                        "symbol": "EURUSD.DWX",
                        "mode": "PAUSE",
                        "pf": "1.20",
                        "sharpe": "0.8",
                        "drawdown_pct": "11",
                        "trades": "40",
                        "compliance_ftmo": "1",
                        "compliance_5ers": "0",
                        "compliance_no_news": "0",
                        "compliance_news_only": "1",
                    },
                    {
                        "symbol": "US30.DWX",
                        "mode": "OFF",
                        "pf": "0.80",
                        "sharpe": "0.1",
                        "drawdown_pct": "30",
                        "trades": "10",
                        "compliance_ftmo": "0",
                        "compliance_5ers": "1",
                        "compliance_no_news": "1",
                        "compliance_news_only": "0",
                    },
                ],
                fieldnames=fieldnames,
            )
            mixed_symbols = _run_python(
                SCRIPTS / "p8_news_impact.py",
                ["--ea", "QM5_1001", "--out-prefix", str(out), "--news-matrix", str(matrix), "--modes", "OFF,PAUSE"],
                REPO,
            )
            self.assertEqual(mixed_symbols["verdict"], "NO_ELIGIBLE_MODE")
            rec = mixed_symbols["details"]["recommended_mode_by_symbol"]
            self.assertEqual(rec["EURUSD.DWX"], "PAUSE")
            self.assertEqual(rec["US30.DWX"], "OFF")


if __name__ == "__main__":
    unittest.main()
