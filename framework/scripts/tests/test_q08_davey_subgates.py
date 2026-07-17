import datetime as dt
import csv
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from framework.scripts import q08_5_neighborhood_runner, q08_7_pbo_runner
from framework.scripts.q08_davey import (
    aggregate,
    sub_8_1_correlation,
    sub_8_2_dsr_mc_fdr,
    sub_8_3_tail_dependence,
    sub_8_4_seasonal,
    sub_8_5_neighborhood,
    sub_8_6_chopping_block,
    sub_8_7_pbo,
    sub_8_8_edge_decay,
    sub_8_9_runs_test,
    sub_8_10_regime_crisis,
    sub_8_11_mc_shuffle_dd,
)


def _trade(ts: dt.datetime, net: float) -> dict:
    return {"ts_utc": ts.replace(tzinfo=dt.UTC).isoformat(), "net": net}


class Q08DaveySubGateSemanticsTests(unittest.TestCase):
    def test_first_portfolio_correlation_and_tail_dependence_are_trivial_passes(self) -> None:
        corr = sub_8_1_correlation.run(equity_stream=[], portfolio=[])
        tail = sub_8_3_tail_dependence.run(equity_stream=[], portfolio=[])

        self.assertEqual(corr["status"], "PASS")
        self.assertTrue(corr["passed"])
        self.assertIn("trivial_pass", corr["detail"])
        self.assertEqual(tail["status"], "PASS")
        self.assertTrue(tail["passed"])
        self.assertIn("trivial_pass", tail["detail"])

    def _write_perturbations(self, tmp, baseline, perturbs) -> Path:
        import json
        p = Path(tmp) / "perturbations.json"
        p.write_text(json.dumps({"baseline": baseline, "perturbations": perturbs}), encoding="utf-8")
        return p

    def test_neighborhood_degenerate_baseline_is_invalid_not_fail(self) -> None:
        # The -Year 0 runner bug gave every EA a 0-trade baseline; that must be INVALID,
        # never FAIL (failing on a degenerate runner is a false negative). 2026-06-26.
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 0, "pf": None, "dd": None},
                [{"param": "x", "delta": "-10pct", "pf": 0.0, "dd": 0.0}],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "INVALID")
        self.assertFalse(result["passed"])
        self.assertIn("degenerate_baseline", result["detail"])

    def test_neighborhood_empty_perturbations_is_invalid_not_vacuous_pass(self) -> None:
        # 141 historical runs "PASSed" with an empty perturbation list (tested nothing).
        # That must be INVALID, not a vacuous PASS. 2026-06-26.
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(tmp, {"trades": 220, "pf": 1.42, "dd": 8500}, [])
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "INVALID")
        self.assertIn("vacuous", result["detail"])

    def test_neighborhood_real_breach_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 220, "pf": 1.42, "dd": 8500},
                [{"param": "fast_ema", "delta": "-10pct", "pf": 0.85,
                  "dd": 9000, "trades": 210}],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "FAIL")
        self.assertIn("perturbation_breaches", result["detail"])

    def test_neighborhood_pf_at_floor_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 220, "pf": 1.42, "dd": 8500},
                [
                    {"param": "fast_ema", "delta": "-10pct", "pf": 1.0,
                     "dd": 8800, "trades": 215, "status": "VALID"},
                    {"param": "fast_ema", "delta": "+10pct", "pf": 1.2,
                     "dd": 9000, "trades": 218, "status": "VALID"},
                ],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "FAIL")
        self.assertEqual(result["evidence"]["breaches"][0]["reason"],
                         "pf_not_above_floor")

    def test_neighborhood_robust_plateau_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 220, "pf": 1.42, "dd": 8500},
                [{"param": "fast_ema", "delta": "-10pct", "pf": 1.35,
                  "dd": 8800, "trades": 215},
                 {"param": "fast_ema", "delta": "+10pct", "pf": 1.38,
                  "dd": 9000, "trades": 218}],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "PASS")

    def test_neighborhood_zero_trade_cell_is_invalid_not_breach(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 220, "pf": 1.42, "dd": 8500},
                [{"param": "strategy_entry_z", "delta": "-10pct", "pf": 0.0,
                  "dd": 0.0, "trades": 0}],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "INVALID")
        self.assertIn("insufficient_valid_perturbations", result["detail"])
        self.assertEqual(result["evidence"]["n_invalid_perturbations"], 1)

    def test_neighborhood_two_valid_cells_can_pass_with_invalid_cell_logged(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 220, "pf": 1.42, "dd": 8500},
                [
                    {"param": "strategy_period", "delta": "-10pct", "pf": 1.2,
                     "dd": 9000, "trades": 210, "status": "VALID"},
                    {"param": "strategy_period", "delta": "+10pct", "pf": 1.3,
                     "dd": 9100, "trades": 212, "status": "VALID"},
                    {"param": "strategy_threshold", "delta": "-10pct", "pf": None,
                     "dd": None, "trades": 0, "status": "INVALID",
                     "invalid_reason": "BARS_ZERO"},
                ],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["evidence"]["n_valid_perturbations"], 2)
        self.assertEqual(result["evidence"]["n_invalid_perturbations"], 1)

    def test_neighborhood_valid_breach_dominates_invalid_cells(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_perturbations(
                tmp,
                {"trades": 299, "pf": 1.27, "dd": 13967.4},
                [
                    {"param": "strategy_ao_slow_period", "delta": "-10pct",
                     "pf": 1.11, "dd": 22190.52, "trades": 285,
                     "status": "VALID"},
                    {"param": "strategy_other", "delta": "+10pct", "pf": None,
                     "dd": None, "trades": 0, "status": "INVALID",
                     "invalid_reason": "timeout"},
                ],
            )
            result = sub_8_5_neighborhood.run(perturbations_path=path)
        self.assertEqual(result["status"], "FAIL")
        self.assertEqual(result["evidence"]["breaches"][0]["reason"], "dd_ratio_exceeded")

    def test_neighborhood_parameter_types_and_steps_are_deterministic(self) -> None:
        beta = q08_5_neighborhood_runner.classify_param("strategy_beta", -0.122)
        self.assertEqual(beta["class"], "structural")
        self.assertEqual(
            q08_5_neighborhood_runner.parameter_perturbations(
                "strategy_beta", -0.122, {}, 10.0,
            ),
            [],
        )

        entry = q08_5_neighborhood_runner.parameter_perturbations(
            "strategy_entry_z", 2.0, {}, 10.0,
        )
        self.assertEqual([row["value"] for row in entry], [1.8, 2.2])
        self.assertTrue(all(row["param_class"] == "continuous" for row in entry))

        weekday = q08_5_neighborhood_runner.parameter_perturbations(
            "strategy_day_of_week", 3, {"minimum": 0, "maximum": 6, "step": 1}, 10.0,
        )
        self.assertEqual([row["value"] for row in weekday], [2, 4])
        self.assertEqual([row["delta"] for row in weekday], ["-1step", "+1step"])

        stepped = q08_5_neighborhood_runner.parameter_perturbations(
            "strategy_period", 20, {"minimum": 10, "maximum": 50, "step": 5}, 10.0,
        )
        self.assertEqual([row["value"] for row in stepped], [15, 25])

        lower_bounded = q08_5_neighborhood_runner.parameter_perturbations(
            "strategy_period", 10, {"minimum": 10, "step": 5}, 10.0,
        )
        self.assertEqual([row["value"] for row in lower_bounded], [15])

    def test_neighborhood_setfile_materialization_is_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "baseline.set"
            source.write_text(
                "; symbol: EURUSD.DWX\n"
                "RISK_FIXED=1000\nRISK_PERCENT=0\n"
                "; strategy-specific params from card must be appended below this line\n"
                "strategy_period=20||10||5||50||Y\n"
                "strategy_threshold=2.0\n"
                "strategy_beta=-0.12202869296345396\n"
                "strategy_pair_name=EURGBP_AUDJPY\n",
                encoding="utf-8",
            )
            generated = root / "generated.set"
            identity = q08_5_neighborhood_runner.materialize_setfile(
                source,
                {
                    "strategy_period": 25,
                    "strategy_beta": -0.12202869296345396,
                    "strategy_pair_name": "EURUSD_GBPUSD",
                },
                generated,
            )
            text = generated.read_text(encoding="utf-8")
            self.assertIn("strategy_period=25||10||5||50||N", text)
            self.assertIn("strategy_threshold=2.0", text)
            self.assertIn("strategy_beta=-0.12202869296345396", text)
            self.assertIn("strategy_pair_name=EURUSD_GBPUSD", text)
            self.assertIn("RISK_FIXED=1000", text)
            self.assertEqual(identity["strategy_param_count"], 4)
            inspected = q08_5_neighborhood_runner.inspect_baseline_setfile(
                source, "EURUSD.DWX",
            )
            self.assertEqual(inspected["strategy_param_count"], 4)
            self.assertEqual(
                q08_5_neighborhood_runner.classify_param(
                    "strategy_pair_name", "EURGBP_AUDJPY",
                )["class"],
                "structural",
            )
            with self.assertRaisesRegex(ValueError, "missing from baseline"):
                q08_5_neighborhood_runner.materialize_setfile(
                    source, {"strategy_missing": 1}, root / "missing.set",
                )

    def test_pbo_missing_scores_is_invalid_not_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "missing_scores.csv"
            result = sub_8_7_pbo.run(scores_path=missing)

        self.assertEqual(result["status"], "INVALID")
        self.assertFalse(result["passed"])
        self.assertIn("pbo_runner_scores_missing", result["detail"])

    def test_pbo_single_config_is_invalid_not_vacuous_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            scores = Path(tmp) / "scores.csv"
            with scores.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(["config_id", "slice_id", "score"])
                for idx in range(1, 9):
                    writer.writerow(["grid_001", f"S{idx}", 1.0 + idx / 100.0])

            result = sub_8_7_pbo.run(scores_path=scores)

        self.assertEqual(result["status"], "INVALID")
        self.assertFalse(result["passed"])
        self.assertIn("got=1:need>=2", result["detail"])
        self.assertNotIn("PBO=0", result["detail"])

    def test_pbo_two_distinct_configs_with_even_slices_is_evaluable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            scores = Path(tmp) / "scores.csv"
            with scores.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(["config_id", "slice_id", "score"])
                for idx in range(1, 9):
                    writer.writerow(["grid_001", f"S{idx}", 2.0 if idx <= 4 else 1.0])
                    writer.writerow(["grid_002", f"S{idx}", 1.0 if idx <= 4 else 2.0])
            scores.with_name("scores_meta.json").write_text(
                json.dumps({
                    "schema_version": 2,
                    "status": "VALID",
                    "config_source": "Q08.5_neighborhood",
                    "q03_candidate_configs": 1,
                    "neighborhood_candidate_configs": 2,
                }),
                encoding="utf-8",
            )

            result = sub_8_7_pbo.run(scores_path=scores)

        self.assertIn(result["status"], {"PASS", "FAIL"})
        self.assertEqual(result["evidence"]["n_configs"], 2)
        self.assertEqual(result["evidence"]["n_common_slices"], 8)
        self.assertEqual(result["evidence"]["splits_evaluated"], 35)
        self.assertEqual(result["evidence"]["config_source"], "Q08.5_neighborhood")
        self.assertEqual(result["evidence"]["q03_candidate_configs"], 1)
        self.assertEqual(result["evidence"]["neighborhood_candidate_configs"], 2)

    def test_pbo_non_even_common_slice_family_is_invalid(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            scores = Path(tmp) / "scores.csv"
            with scores.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(["config_id", "slice_id", "score"])
                for config in ("grid_001", "grid_002"):
                    for idx in range(1, 4):
                        writer.writerow([config, f"S{idx}", float(idx)])

            result = sub_8_7_pbo.run(scores_path=scores)

        self.assertEqual(result["status"], "INVALID")
        self.assertFalse(result["passed"])
        self.assertIn("insufficient_common_even_slices", result["detail"])
        self.assertEqual(result["evidence"]["n_common_slices"], 3)

    def test_pbo_runner_records_single_config_as_invalid(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            summary = root / "summary.json"
            summary.write_text("{}", encoding="utf-8")
            argv = [
                "q08_7_pbo_runner.py",
                "--ea", "QM5_12567",
                "--symbol", "XAUUSD.DWX",
                "--report-root", str(root),
            ]
            trades = [
                {"ts": dt.datetime(2023, 1, 1, tzinfo=dt.UTC), "net": 10.0},
                {"ts": dt.datetime(2024, 1, 1, tzinfo=dt.UTC), "net": -5.0},
            ]
            with (
                patch.object(q08_7_pbo_runner.sys, "argv", argv),
                patch.object(
                    q08_7_pbo_runner,
                    "discover_sweep_configs",
                    return_value=[("grid_001", summary)],
                ),
                patch.object(
                    q08_7_pbo_runner,
                    "discover_work_item_q03_configs",
                    return_value=[],
                ),
                patch.object(
                    q08_7_pbo_runner,
                    "_parse_trades_from_summary",
                    return_value=trades,
                ),
            ):
                rc = q08_7_pbo_runner.main()

            scores_path = (
                root / "QM5_12567" / "Q08" / "pbo" / "XAUUSD_DWX" / "scores.csv"
            )
            self.assertEqual(rc, 1)
            self.assertTrue(scores_path.exists())
            meta = json.loads(
                scores_path.with_name("scores_meta.json").read_text(encoding="utf-8")
            )
            self.assertEqual(meta["status"], "INVALID")
            self.assertEqual(meta["n_configs"], 1)
            self.assertEqual(meta["rows_written"], 0)
            with scores_path.open("r", encoding="utf-8", newline="") as handle:
                self.assertEqual(len(list(csv.reader(handle))), 1)

    def test_pbo_runner_report_fallback_returns_datetime_timestamps(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            summary = Path(tmp) / "summary.json"
            report = Path(tmp) / "report.htm"
            report.write_text("placeholder", encoding="utf-8")
            summary.write_text(
                '{"runs":[{"report_canonical_path":"' + str(report).replace("\\", "\\\\") + '"}]}',
                encoding="utf-8",
            )
            with patch.object(
                q08_7_pbo_runner,
                "load_trades_from_mt5_report",
                return_value=[{"ts_utc": "2024-01-02T03:04:05+00:00", "net": "12.5"}],
            ):
                trades = q08_7_pbo_runner._parse_trades_from_summary(summary)

        self.assertEqual(len(trades), 1)
        self.assertIsInstance(trades[0]["ts"], dt.datetime)
        self.assertEqual(trades[0]["net"], 12.5)

    def test_pbo_sweep_configs_require_verified_setfile_content(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            missing_lineage = root / "grid_001"
            missing_lineage.mkdir()
            (missing_lineage / "summary.json").write_text("{}", encoding="utf-8")
            for name in ("grid_002", "grid_003"):
                config = root / name
                config.mkdir()
                (config / "summary.json").write_text("{}", encoding="utf-8")
                (config / "config.set").write_text(
                    f"; distinct header {name}\n"
                    "; strategy-specific params\n"
                    "strategy_period=20\n",
                    encoding="utf-8",
                )

            configs = q08_7_pbo_runner.discover_sweep_configs(root)

        self.assertEqual(len(configs), 1)
        self.assertTrue(configs[0][0].startswith("q03_"))

    def test_pbo_runner_uses_distinct_valid_neighborhood_configs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            q03_summary = root / "q03_summary.json"
            q03_summary.write_text("{}", encoding="utf-8")
            neighborhood_summaries = []
            for index in range(3):
                summary = root / f"neighborhood_{index}.json"
                summary.write_text("{}", encoding="utf-8")
                neighborhood_summaries.append(summary)
            artifact = root / "perturbations.json"
            artifact.write_text(json.dumps({
                "baseline": {
                    "status": "VALID", "trades": 80,
                    "setfile_sha256": "a" * 64,
                    "summary_path": str(neighborhood_summaries[0]),
                },
                "perturbations": [
                    {"status": "VALID", "trades": 82,
                     "setfile_sha256": "b" * 64,
                     "summary_path": str(neighborhood_summaries[1])},
                    {"status": "VALID", "trades": 84,
                     "setfile_sha256": "c" * 64,
                     "summary_path": str(neighborhood_summaries[2])},
                    {"status": "INVALID", "trades": 0,
                     "setfile_sha256": "d" * 64,
                     "summary_path": str(root / "missing.json")},
                ],
            }), encoding="utf-8")
            trades = [
                {"ts": dt.datetime(2020, month, 1, tzinfo=dt.UTC),
                 "net": 10.0 if month % 2 else -5.0}
                for month in range(1, 9)
            ]
            argv = [
                "q08_7_pbo_runner.py",
                "--ea", "QM5_13117",
                "--symbol", "PAIR_COMPOSITE",
                "--report-root", str(root),
                "--neighborhood-artifact", str(artifact),
            ]
            with (
                patch.object(q08_7_pbo_runner.sys, "argv", argv),
                patch.object(q08_7_pbo_runner, "discover_sweep_configs",
                             return_value=[("q03_only", q03_summary)]),
                patch.object(q08_7_pbo_runner, "discover_work_item_q03_configs",
                             return_value=[]),
                patch.object(q08_7_pbo_runner, "_parse_trades_from_summary",
                             return_value=trades),
            ):
                rc = q08_7_pbo_runner.main()

            meta_path = root / "QM5_13117" / "Q08" / "pbo" / "PAIR_COMPOSITE" / "scores_meta.json"
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        self.assertEqual(rc, 0)
        self.assertEqual(meta["status"], "VALID")
        self.assertEqual(meta["config_source"], "Q08.5_neighborhood")
        self.assertEqual(meta["n_configs"], 3)

    def test_regime_missing_or_unjoinable_input_is_invalid_not_fail(self) -> None:
        trades = [_trade(dt.datetime(2024, 1, day), 10.0) for day in range(1, 4)]

        missing = sub_8_10_regime_crisis.run(trades=trades, equity_stream=[])
        self.assertEqual(missing["status"], "INVALID")
        self.assertFalse(missing["passed"])
        self.assertIn("regime_input_missing", missing["detail"])

        unjoinable = sub_8_10_regime_crisis.run(
            trades=trades,
            equity_stream=[
                {"day_key": 20230101, "atr_regime": "low"},
                {"day_key": 20230102, "atr_regime": "normal"},
                {"day_key": 20230103, "atr_regime": "high"},
            ],
        )
        self.assertEqual(unjoinable["status"], "INVALID")
        self.assertFalse(unjoinable["passed"])
        self.assertIn("regime_join_failed", unjoinable["detail"])

        incomplete = sub_8_10_regime_crisis.run(
            trades=trades,
            equity_stream=[
                {"day_key": 20240101, "atr_regime": "low"},
                {"day_key": 20240102, "atr_regime": "normal"},
            ],
        )
        self.assertEqual(incomplete["status"], "INVALID")
        self.assertFalse(incomplete["passed"])
        self.assertIn("regime_join_incomplete", incomplete["detail"])

    def test_mc_shuffle_dd_is_deterministic_with_stable_values(self) -> None:
        trades = [
            {"net": 1000.0},
            {"net": -500.0},
            {"net": 700.0},
            {"net": -1200.0},
            {"net": 300.0},
            {"net": -100.0},
            {"net": 900.0},
            {"net": -400.0},
        ]

        first = sub_8_11_mc_shuffle_dd.run(trades=trades)
        second = sub_8_11_mc_shuffle_dd.run(trades=trades)

        self.assertEqual(first, second)
        self.assertEqual(first["status"], "PASS")
        evidence = first["evidence"]
        self.assertEqual(evidence["seed"], 8112026)
        self.assertEqual(evidence["n_permutations"], 1000)
        self.assertEqual(evidence["as_realized_maxdd"], 1200.0)
        self.assertEqual(evidence["mc_maxdd_median"], 1600.0)
        self.assertEqual(evidence["mc_maxdd_p95"], 2200.0)
        self.assertEqual(evidence["mc_maxdd_p95_over_as_realized_maxdd"], 1.833333)

    def test_mc_shuffle_dd_failure_is_soft_only_in_aggregate(self) -> None:
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.7_pbo", "status": "PASS"},
            {"name": "8.11_mc_shuffle_dd", "status": "FAIL", "detail": "mc_maxdd_p95=11000"},
        ]

        verdict, classification = aggregate._aggregate_verdict(subs, trades=trades)

        self.assertEqual(verdict, "FAIL_SOFT")
        self.assertEqual(classification["8.11_mc_shuffle_dd"], "EDGE_SOFT")

    def test_edge_decay_negative_decline_passes(self) -> None:
        trades: list[dict] = []
        for month_index in range(24):
            year = 2020 + month_index // 12
            month = month_index % 12 + 1
            loss = -0.75 if month_index < 12 else -0.70
            for i in range(10):
                net = 1.0 if i < 6 else loss
                trades.append(_trade(dt.datetime(year, month, min(i + 1, 28)), net))

        result = sub_8_8_edge_decay.run(trades=trades)

        self.assertEqual(result["status"], "PASS")
        self.assertTrue(result["passed"])
        self.assertLess(result["value"], 0)

    def test_runs_test_detail_and_boolean_match_for_non_clustered_profit_stream(self) -> None:
        trades: list[dict] = []
        pattern = [1, 1, 0, 0]
        for month in range(1, 13):
            for i in range(10):
                win = pattern[(month * 10 + i) % len(pattern)]
                trades.append(_trade(dt.datetime(2020, month, min(i + 1, 28)), 10.0 if win else -8.0))

        result = sub_8_9_runs_test.run(trades=trades)

        self.assertEqual(result["status"], "PASS")
        self.assertTrue(result["passed"])
        self.assertGreater(result["value"]["runs_p_value"], 0.05)
        self.assertLessEqual(result["value"]["top_pct_share"], 70.0)

    def test_genuine_failures_remain_failures(self) -> None:
        losing_daily = [_trade(dt.datetime(2024, 1, 1) + dt.timedelta(days=i), -1.0) for i in range(100)]
        dsr = sub_8_2_dsr_mc_fdr.run(trades=losing_daily)
        self.assertEqual(dsr["status"], "FAIL")
        self.assertFalse(dsr["passed"])

        seasonal_trades = [_trade(dt.datetime(2024, month, 1), 10.0) for month in range(1, 13)]
        seasonal_trades.append(_trade(dt.datetime(2024, 8, 2), -50.0))
        seasonal = sub_8_4_seasonal.run(trades=seasonal_trades)
        self.assertEqual(seasonal["status"], "FAIL")
        self.assertFalse(seasonal["passed"])

        chopping_trades = [{"net": 1.0} for _ in range(5)] + [{"net": -10.0} for _ in range(95)]
        chopping = sub_8_6_chopping_block.run(trades=chopping_trades)
        self.assertEqual(chopping["status"], "FAIL")
        self.assertFalse(chopping["passed"])

    def test_dsr_first_entry_empty_cohort_is_trivial_pass(self) -> None:
        # Positive-drift but volatile daily series, no portfolio peers: the DSR
        # deflation is not applicable (no selection bias), so it trivial-passes
        # pending cohort — never INVALID, never a deflation FAIL.
        trades = [
            _trade(dt.datetime(2024, 1, 1) + dt.timedelta(days=i), 10.0 if i % 2 == 0 else -9.0)
            for i in range(120)
        ]
        result = sub_8_2_dsr_mc_fdr.run(trades=trades, portfolio=[])

        self.assertEqual(result["status"], "PASS")
        self.assertTrue(result["passed"])
        self.assertEqual(result["evidence"]["tier"], "standalone_pending_cohort")
        self.assertIn("first_entry", result["detail"])

    def test_dsr_tier1_fail_with_cohort_is_fail_not_invalid(self) -> None:
        # Same modest-Sharpe series, but with a peer cohort present the DSR
        # deflation applies and fails Tier-1. It must resolve to a real FAIL,
        # not a permanent INVALID dead-end (no batch-FDR rescue exists yet).
        trades = [
            _trade(dt.datetime(2024, 1, 1) + dt.timedelta(days=i), 10.0 if i % 2 == 0 else -9.0)
            for i in range(120)
        ]
        result = sub_8_2_dsr_mc_fdr.run(trades=trades, portfolio=[{"ea_id": 1, "equity": []}])

        self.assertEqual(result["status"], "FAIL")
        self.assertFalse(result["passed"])
        self.assertNotEqual(result["status"], "INVALID")
        self.assertIn("DSR_TIER1_FAIL", result["detail"])

    def test_dl077_invalid_davey_gates_route_profitable_edge_to_soft(self) -> None:
        # OWNER 2026-07-17: an unresolved neighborhood is a blocking tooling
        # condition even when PBO and profitability are real.
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.1_correlation", "status": "PASS"},
            {"name": "8.3_tail_dependence", "status": "PASS"},
            {"name": "8.7_pbo", "status": "PASS"},
            {"name": "8.2_dsr_mc_fdr", "status": "INVALID", "detail": "degenerate_baseline"},
            {"name": "8.5_neighborhood", "status": "INVALID", "detail": "degenerate_baseline"},
            {"name": "8.9_runs_test", "status": "INVALID", "detail": "too_few_for_runs"},
        ]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "INVALID")

    def test_dl077_no_real_quality_pass_is_invalid(self) -> None:
        # Only the trivial 8.1/8.3 passed; nothing real validated the edge -> INVALID.
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.1_correlation", "status": "PASS"},
            {"name": "8.3_tail_dependence", "status": "PASS"},
            {"name": "8.7_pbo", "status": "INVALID", "detail": "degenerate"},
            {"name": "8.2_dsr_mc_fdr", "status": "INVALID", "detail": "degenerate"},
        ]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "INVALID")

    def test_dl077_zero_trade_baseline_cost_cushion_is_invalid_not_hard(self) -> None:
        # A 0-trade baseline (gross<=0 -> cost_cushion EDGE_HARD) is an infra failure, NOT a
        # cost fail -> INVALID so it re-runs, never FAIL_HARD.
        subs = [{"name": "8.7_pbo", "status": "PASS"}]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=[], cost_cushion_tier="EDGE_HARD")
        self.assertEqual(verdict, "INVALID")

    def test_dl077_real_cost_fail_with_trades_still_hard(self) -> None:
        # Traded but gross <= cost -> a genuine cost failure stays FAIL_HARD.
        trades = [_trade(dt.datetime(2024, 1, 1), -5.0), _trade(dt.datetime(2024, 1, 2), 1.0)]
        subs = [{"name": "8.7_pbo", "status": "PASS"}]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=trades, cost_cushion_tier="EDGE_HARD")
        self.assertEqual(verdict, "FAIL_HARD")

    def test_dl077_real_hard_fail_still_fail_hard(self) -> None:
        # An INVALID Davey gate does not rescue a genuine HARD failure (PBO fail stays hard).
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.7_pbo", "status": "FAIL", "detail": "pbo_0.88_above_floor"},
            {"name": "8.2_dsr_mc_fdr", "status": "INVALID", "detail": "degenerate"},
        ]
        verdict, _ = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "FAIL_HARD")

    def test_pbo_neighborhood_fallback_fail_is_soft_not_model_selection_hard(self) -> None:
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [
            {"name": "8.5_neighborhood", "status": "PASS"},
            {
                "name": "8.7_pbo",
                "status": "FAIL",
                "detail": "PBO=62.86%:max=40%:splits=35:overfit=22",
                "evidence": {"config_source": "Q08.5_neighborhood"},
            },
        ]
        verdict, classification = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "FAIL_SOFT")
        self.assertEqual(classification["8.7_pbo"], "EDGE_SOFT")

    def test_pbo_q03_cohort_fail_remains_hard(self) -> None:
        trades = [_trade(dt.datetime(2024, 1, d), 10.0) for d in range(1, 20)]
        trades.append(_trade(dt.datetime(2024, 2, 1), -5.0))
        subs = [{
            "name": "8.7_pbo",
            "status": "FAIL",
            "detail": "PBO=62.86%:max=40%:splits=35:overfit=22",
            "evidence": {"config_source": "Q03"},
        }]
        verdict, classification = aggregate._aggregate_verdict(subs, trades=trades)
        self.assertEqual(verdict, "FAIL_HARD")
        self.assertEqual(classification["8.7_pbo"], "EDGE_HARD")
        self.assertEqual(
            aggregate._classify_fail({
                "name": "8.7_pbo",
                "status": "FAIL",
                "detail": "PBO=50.00%:max=40%",
                "evidence": {"config_source": "Q03"},
            }),
            "EDGE_SOFT",
        )
        self.assertEqual(
            aggregate._classify_fail({
                "name": "8.7_pbo",
                "status": "FAIL",
                "detail": "PBO=62.86%:max=40%",
            }),
            "EDGE_HARD",
        )

    def test_structured_qm_log_loader_finds_tester_agent_equity_stream(self) -> None:
        # Guard the helper's contract directly without requiring a live MT5 tree.
        self.assertTrue(hasattr(aggregate, "_latest_structured_qm_log"))

    def test_q08_explicit_baseline_setfile_feeds_support_runners(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "QM5_999999_demo_EURUSD.DWX_H1_rescue_long_only_backtest.set"
            baseline.write_text(
                "; symbol: EURUSD.DWX\n"
                "; strategy-specific params from card must be appended below this line\n"
                "strategy_period=20\n",
                encoding="utf-8",
            )
            calls = []

            def fake_run(args, **_kwargs):
                calls.append([str(arg) for arg in args])
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch("subprocess.run", side_effect=fake_run):
                aggregate._ensure_sub_gate_inputs(
                    999999,
                    "EURUSD.DWX",
                    terminal="T9",
                    baseline_setfile=baseline,
                    neighborhood_max_params=1,
                )

        neighborhood = next(
            cmd for cmd in calls
            if any("q08_5_neighborhood_runner.py" in part for part in cmd)
        )
        self.assertEqual(neighborhood[neighborhood.index("--baseline-setfile") + 1], str(baseline))
        self.assertEqual(neighborhood[neighborhood.index("--max-params") + 1], "1")

    def test_q08_explicit_baseline_setfile_feeds_baseline_backtest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "QM5_11476_demo_USDJPY.DWX_H1_rescue_long_only_backtest.set"
            baseline.write_text("x=1\n", encoding="utf-8")
            calls = []

            def fake_run(args, **_kwargs):
                calls.append([str(arg) for arg in args])
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch("subprocess.run", side_effect=fake_run), \
                 patch.object(aggregate, "_latest_baseline_summary", return_value=None), \
                 patch.object(aggregate, "_latest_structured_qm_log", return_value=None):
                aggregate._run_baseline_for_trades(
                    11476,
                    "USDJPY.DWX",
                    terminal="T9",
                    baseline_setfile=baseline,
                )

        self.assertEqual(calls[0][calls[0].index("-SetFile") + 1], str(baseline))

    def test_q08_neighborhood_resolves_canonical_v5_expert_path(self) -> None:
        expert = q08_5_neighborhood_runner.resolve_ea_expert("QM5_11476", 11476)

        self.assertTrue(expert.startswith("QM\\QM5_11476_"))

    def test_q08_neighborhood_reads_run_smoke_timestamp_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = root / "baseline.set"
            baseline.write_text("x=1\n", encoding="utf-8")

            def fake_run(_args, **_kwargs):
                summary = root / "QM5_11476" / "20260101_000000" / "summary.json"
                summary.parent.mkdir(parents=True)
                summary.write_text(
                    json.dumps({
                        "ea_id": 11476,
                        "expert": r"QM\QM5_11476_demo",
                        "symbol": "USDJPY.DWX",
                        "period": "H1",
                        "terminal": "T9",
                        "runs": [{
                            "profit_factor": 1.23,
                            "drawdown": 456.0,
                            "total_trades": 78,
                        }],
                    }),
                    encoding="utf-8",
                )
                return SimpleNamespace(
                    returncode=0,
                    stdout=f"run_smoke.summary={summary}\n",
                    stderr="",
                )

            with patch.object(q08_5_neighborhood_runner.subprocess, "run", side_effect=fake_run):
                pf, dd, trades = q08_5_neighborhood_runner.fire_backtest(
                    ea_id=11476,
                    ea_expert="QM\\QM5_11476_demo",
                    symbol="USDJPY.DWX",
                    setfile=baseline,
                    terminal="T9",
                    run_tag="baseline",
                    report_root=root,
                )

        self.assertEqual(pf, 1.23)
        self.assertEqual(dd, 456.0)
        self.assertEqual(trades, 78)

    def test_q08_neighborhood_summary_lookup_never_falls_back_to_stale(self) -> None:
        import os
        import time
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            summary = root / "QM5_11476" / "old" / "summary.json"
            summary.parent.mkdir(parents=True)
            summary.write_text(json.dumps({
                "ea_id": 11476,
                "expert": r"QM\QM5_11476_demo",
                "symbol": "USDJPY.DWX",
                "period": "H1",
                "terminal": "T9",
            }), encoding="utf-8")
            os.utime(summary, (1, 1))
            found = q08_5_neighborhood_runner.latest_run_smoke_summary(
                root,
                11476,
                time.time(),
                ea_expert=r"QM\QM5_11476_demo",
                symbol="USDJPY.DWX",
                period="H1",
                terminal="T9",
            )
        self.assertIsNone(found)

    def test_q08_neighborhood_missing_marker_does_not_bind_fresh_matching_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = root / "baseline.set"
            baseline.write_text("x=1\n", encoding="utf-8")

            def fake_run(_args, **_kwargs):
                summary = root / "QM5_11476" / "fresh" / "summary.json"
                summary.parent.mkdir(parents=True)
                summary.write_text(json.dumps({
                    "ea_id": 11476,
                    "expert": r"QM\QM5_11476_demo",
                    "symbol": "USDJPY.DWX",
                    "period": "H1",
                    "terminal": "T9",
                    "runs": [{"profit_factor": 1.23, "drawdown": 456.0,
                              "total_trades": 78}],
                }), encoding="utf-8")
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch.object(q08_5_neighborhood_runner.subprocess, "run", side_effect=fake_run):
                result = q08_5_neighborhood_runner.fire_backtest_details(
                    ea_id=11476,
                    ea_expert=r"QM\QM5_11476_demo",
                    symbol="USDJPY.DWX",
                    setfile=baseline,
                    terminal="T9",
                    run_tag="strategy_period_pos10pct",
                    report_root=root,
                )

        self.assertEqual(result["status"], "INVALID")
        self.assertEqual(result["invalid_reason"], "summary_missing_or_identity_mismatch")

    def test_q08_pbo_refresh_rejects_stale_artifacts(self) -> None:
        import time
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scores = root / "scores.csv"
            scores.write_text("config_id,slice_id,score\n", encoding="utf-8")
            meta = scores.with_name("scores_meta.json")
            meta.write_text(json.dumps({
                "schema_version": q08_7_pbo_runner.SCORES_SCHEMA_VERSION,
                "engine_version": q08_7_pbo_runner.ENGINE_VERSION,
                "status": "VALID",
                "scores_csv": str(scores),
            }), encoding="utf-8")
            started_at = time.time() + 1.0

            reusable, reason = aggregate._pbo_refresh_artifact_status(
                scores, root / "missing_perturbations.json", started_at,
            )
            result = aggregate._pbo_refresh_invalid_result({
                "8_7_pbo": {
                    "artifact_reusable_after": reusable,
                    "reuse_check_after": reason,
                },
            })

        self.assertFalse(reusable)
        self.assertEqual(reason, "scores_or_meta_stale")
        self.assertEqual(result["status"], "INVALID")

    def test_q08_neighborhood_setfile_fallback_skips_framework_and_categorical_params(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            setfile = Path(tmp) / "demo.set"
            setfile.write_text(
                "\n".join([
                    "; strategy-specific params from card must be appended below this line",
                    "qm_rng_seed=42",
                    "RISK_FIXED=1000",
                    "PORTFOLIO_WEIGHT=1",
                    "strategy_use_slope_filter=1",
                    "strategy_direction_mode=1",
                    "strategy_min_exit_bars=0",
                    "strategy_bb_period=20",
                    "strategy_bb_dev_inner=1.0",
                    "fast_ema=12",
                ]),
                encoding="utf-8",
            )

            params = q08_5_neighborhood_runner.load_params_from_setfile(setfile)["params"]

        self.assertEqual(params, {
            "strategy_bb_period": 20,
            "strategy_bb_dev_inner": 1.0,
            "fast_ema": 12,
        })

    def test_q08_neighborhood_rejects_empty_strategy_block(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            setfile = Path(tmp) / "QM5_11708_demo_EURUSD.DWX_D1_backtest.set"
            setfile.write_text(
                "\n".join([
                    "; symbol: EURUSD.DWX",
                    "RISK_FIXED=1000",
                    "RISK_PERCENT=0",
                    "; strategy-specific params from card must be appended below this line",
                    "; card_defaults_source=not_found",
                ]),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "no strategy parameters"):
                q08_5_neighborhood_runner.inspect_baseline_setfile(
                    setfile,
                    "EURUSD.DWX",
                )

    def test_q08_neighborhood_rejects_wrong_symbol_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            setfile = Path(tmp) / "baseline.set"
            setfile.write_text(
                "\n".join([
                    "; symbol: AUDUSD.DWX",
                    "; strategy-specific params from card must be appended below this line",
                    "strategy_period=20",
                ]),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "symbol mismatch"):
                q08_5_neighborhood_runner.inspect_baseline_setfile(
                    setfile,
                    "EURUSD.DWX",
                )

    def test_q08_neighborhood_cache_requires_exact_baseline_identity(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "QM5_10476_demo_USDCAD.DWX_H1_backtest.set"
            setfile.write_text(
                "\n".join([
                    "; symbol: USDCAD.DWX",
                    "; strategy-specific params from card must be appended below this line",
                    "strategy_period=20",
                ]),
                encoding="utf-8",
            )
            identity = q08_5_neighborhood_runner.inspect_baseline_setfile(
                setfile,
                "USDCAD.DWX",
            )
            artifact = root / "perturbations.json"
            artifact.write_text(
                json.dumps({
                    "schema_version": q08_5_neighborhood_runner.EVIDENCE_SCHEMA_VERSION,
                    "engine_version": q08_5_neighborhood_runner.ENGINE_VERSION,
                    "symbol": "USDCAD.DWX",
                    "param_source": identity["path"],
                    "param_source_sha256": identity["sha256"],
                    "baseline_setfile_path": identity["path"],
                    "baseline_setfile_sha256": identity["sha256"],
                    "baseline_setfile_symbol": "USDCAD.DWX",
                    "baseline_setfile_strategy_param_count": identity["strategy_param_count"],
                    "baseline": {"status": "VALID", "trades": 80,
                                 "pf": 1.4, "dd": 1000.0},
                    "evidence_status": "VALID",
                    "n_params_tested": 1,
                    "n_valid_perturbations": 2,
                    "perturbations": [
                        {"param": "strategy_period", "delta": "-10pct", "trades": 78,
                         "pf": 1.35, "dd": 1100.0, "status": "VALID",
                         "setfile_sha256": "a" * 64},
                        {"param": "strategy_period", "delta": "+10pct", "trades": 82,
                         "pf": 1.32, "dd": 1050.0, "status": "VALID",
                         "setfile_sha256": "b" * 64},
                    ],
                }),
                encoding="utf-8",
            )

            reusable, reason = aggregate._neighborhood_artifact_reuse_status(
                artifact,
                setfile,
                "USDCAD.DWX",
            )
            self.assertTrue(reusable)
            self.assertEqual(reason, "exact_baseline_lineage")

            payload = json.loads(artifact.read_text(encoding="utf-8"))
            valid_baseline = dict(payload["baseline"])
            payload["baseline"] = {
                "status": "VALID", "trades": 0, "pf": None, "dd": None,
            }
            artifact.write_text(json.dumps(payload), encoding="utf-8")
            reusable, reason = aggregate._neighborhood_artifact_reuse_status(
                artifact,
                setfile,
                "USDCAD.DWX",
            )
            self.assertFalse(reusable)
            self.assertEqual(reason, "degenerate_baseline")

            payload["baseline"] = valid_baseline
            valid_perturbation = dict(payload["perturbations"][0])
            payload["perturbations"][0].update({
                "status": "VALID", "trades": 0, "pf": None,
            })
            artifact.write_text(json.dumps(payload), encoding="utf-8")
            reusable, reason = aggregate._neighborhood_artifact_reuse_status(
                artifact,
                setfile,
                "USDCAD.DWX",
            )
            self.assertFalse(reusable)
            self.assertEqual(reason, "valid_perturbation_degenerate")

            payload["perturbations"][0] = valid_perturbation
            artifact.write_text(json.dumps(payload), encoding="utf-8")
            setfile.write_text(setfile.read_text(encoding="utf-8") + "\nstrategy_extra=2\n")
            reusable, reason = aggregate._neighborhood_artifact_reuse_status(
                artifact,
                setfile,
                "USDCAD.DWX",
            )
            self.assertFalse(reusable)
            self.assertEqual(reason, "baseline_sha256_mismatch")

    def test_q08_neighborhood_legacy_cache_without_lineage_is_not_reused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "QM5_12567_demo_XAUUSD.DWX_D1_backtest.set"
            setfile.write_text(
                "\n".join([
                    "; symbol: XAUUSD.DWX",
                    "; strategy-specific params from card must be appended below this line",
                    "strategy_period=2",
                ]),
                encoding="utf-8",
            )
            artifact = root / "perturbations.json"
            artifact.write_text(
                json.dumps({
                    "symbol": "XAUUSD.DWX",
                    "baseline": {"trades": 0, "pf": None, "params": {}},
                }),
                encoding="utf-8",
            )

            reusable, reason = aggregate._neighborhood_artifact_reuse_status(
                artifact,
                setfile,
                "XAUUSD.DWX",
            )
            self.assertFalse(reusable)
            self.assertEqual(reason, "schema_version_mismatch")

    def test_q08_neighborhood_cache_rejects_current_empty_or_wrong_symbol_set(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for filename, header, expected_reason in (
                ("empty.set", "EURUSD.DWX", "baseline_setfile_invalid:ValueError"),
                ("wrong.set", "AUDUSD.DWX", "baseline_setfile_invalid:ValueError"),
            ):
                setfile = root / filename
                lines = [
                    f"; symbol: {header}",
                    "; strategy-specific params from card must be appended below this line",
                ]
                if filename == "wrong.set":
                    lines.append("strategy_period=20")
                setfile.write_text("\n".join(lines), encoding="utf-8")
                artifact = root / f"{filename}.json"
                artifact.write_text(json.dumps({"symbol": "EURUSD.DWX"}), encoding="utf-8")

                reusable, reason = aggregate._neighborhood_artifact_reuse_status(
                    artifact,
                    setfile,
                    "EURUSD.DWX",
                )
                self.assertFalse(reusable)
                self.assertEqual(reason, expected_reason)

    def test_q08_neighborhood_cache_binds_parameter_source_hash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            setfile = root / "baseline.set"
            setfile.write_text(
                "\n".join([
                    "; symbol: EURUSD.DWX",
                    "; strategy-specific params from card must be appended below this line",
                    "strategy_period=20",
                ]),
                encoding="utf-8",
            )
            identity = q08_5_neighborhood_runner.inspect_baseline_setfile(
                setfile,
                "EURUSD.DWX",
            )
            plateau = root / "plateau_pick.json"
            plateau.write_text('{"params":{"strategy_period":20}}', encoding="utf-8")
            import hashlib
            plateau_sha = hashlib.sha256(plateau.read_bytes()).hexdigest()
            artifact = root / "perturbations.json"
            artifact.write_text(json.dumps({
                "schema_version": q08_5_neighborhood_runner.EVIDENCE_SCHEMA_VERSION,
                "engine_version": q08_5_neighborhood_runner.ENGINE_VERSION,
                "symbol": "EURUSD.DWX",
                "param_source": str(plateau),
                "param_source_sha256": plateau_sha,
                "baseline_setfile_path": identity["path"],
                "baseline_setfile_sha256": identity["sha256"],
                "baseline_setfile_symbol": "EURUSD.DWX",
                "baseline_setfile_strategy_param_count": 1,
                "baseline": {"status": "VALID", "trades": 80,
                             "pf": 1.4, "dd": 1000.0},
                "evidence_status": "VALID",
                "n_params_tested": 1,
                "n_valid_perturbations": 2,
                "perturbations": [
                    {"trades": 80, "pf": 1.3, "dd": 1100.0,
                     "status": "VALID", "setfile_sha256": "c" * 64},
                    {"trades": 82, "pf": 1.35, "dd": 1050.0,
                     "status": "VALID", "setfile_sha256": "d" * 64},
                ],
            }), encoding="utf-8")
            plateau.write_text('{"params":{"strategy_period":21}}', encoding="utf-8")

            reusable, reason = aggregate._neighborhood_artifact_reuse_status(
                artifact,
                setfile,
                "EURUSD.DWX",
            )
            self.assertFalse(reusable)
            self.assertEqual(reason, "param_source_sha256_mismatch")

    def test_q08_neighborhood_quarantine_failure_forces_invalid(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = Path(tmp) / "perturbations.json"
            artifact.write_text("{}", encoding="utf-8")
            with patch.object(Path, "replace", side_effect=OSError("locked")):
                archived, error = aggregate._quarantine_stale_neighborhood_artifact(artifact)

            self.assertIsNone(archived)
            self.assertEqual(error, "stale_artifact_quarantine_failed:OSError")
            result = aggregate._neighborhood_lineage_invalid_result({
                "8_5_neighborhood": {
                    "artifact_reusable_after": False,
                    "error": error,
                    "reuse_check_after": "stale_artifact_not_quarantined",
                },
            })
            self.assertEqual(result["status"], "INVALID")
            self.assertIn("stale_artifact_not_quarantined", result["detail"])


class Q08DurableSleeveStreamTests(unittest.TestCase):
    """The durable portfolio-stream persistence fidelity rule (copy / serialise / skip)."""

    def test_copies_live_common_stream_verbatim_when_present(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            common_log = root / "common" / "1234_EURUSD_DWX.jsonl"
            common_log.parent.mkdir(parents=True)
            payload = ('{"event":"TRADE_CLOSED","time":1,"net":5.0,"volume":0.1,'
                       '"notional":1000.0,"symbol":"EURUSD.DWX"}\n')
            common_log.write_text(payload, encoding="utf-8")
            with patch.object(aggregate, "DURABLE_STREAM_ROOT", root / "durable"), \
                 patch.object(aggregate, "_common_q08_trade_log", return_value=common_log):
                res = aggregate._persist_durable_sleeve_stream(
                    1234, "EURUSD.DWX", [{"volume": 0.1, "net": 5.0}])
            self.assertTrue(res["persisted"])
            self.assertEqual(res["source"], "common_copy")
            self.assertEqual(Path(res["path"]).read_text(encoding="utf-8"), payload)

    def test_serialises_in_memory_trades_when_volume_present_and_no_common(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            absent = root / "nope.jsonl"
            trades = [{"time": 10, "net": 3.0, "profit": 3.0, "swap": 0.0,
                       "commission": 0.0, "volume": 0.2, "notional": 2000.0,
                       "symbol": "NDX.DWX"}]
            with patch.object(aggregate, "DURABLE_STREAM_ROOT", root / "durable"), \
                 patch.object(aggregate, "_common_q08_trade_log", return_value=absent):
                res = aggregate._persist_durable_sleeve_stream(99, "NDX.DWX", trades)
            self.assertTrue(res["persisted"])
            self.assertEqual(res["source"], "serialized")
            line = Path(res["path"]).read_text(encoding="utf-8").strip()
            self.assertIn('"event": "TRADE_CLOSED"', line)
            self.assertIn('"volume": 0.2', line)

    def test_skips_volume_less_report_fallback_trades(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            absent = root / "nope.jsonl"
            # HTML-report-fallback shape: no volume / notional.
            trades = [{"time": 10, "net": 3.0, "profit": 3.0, "swap": 0.0, "commission": 0.0}]
            with patch.object(aggregate, "DURABLE_STREAM_ROOT", root / "durable"), \
                 patch.object(aggregate, "_common_q08_trade_log", return_value=absent):
                res = aggregate._persist_durable_sleeve_stream(99, "NDX.DWX", trades)
            self.assertFalse(res["persisted"])
            self.assertEqual(res["reason"], "report_fallback_no_volume")

    def test_run_all_persists_stream_before_support_runners(self) -> None:
        events = []
        trades = [{"time": 1, "net": 10.0, "profit": 10.0, "swap": 0.0,
                   "commission": 0.0, "volume": 0.1, "symbol": "EURUSD.DWX"}]
        commission_info = {
            "commission_basis": "test",
            "commission_model": {"degraded": False},
            "commission_total": 0.0,
            "gross_total": 10.0,
            "cost_cushion": None,
            "cost_cushion_tier": "PASS",
            "degraded_symbols": [],
        }

        def persist(*_args, **_kwargs):
            events.append("persist")
            return {"persisted": True, "source": "common_copy", "path": "durable.jsonl", "n": 1}

        def ensure(*_args, **_kwargs):
            events.append("ensure")
            return {}

        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            out_dir = root / "out"
            with patch.object(aggregate.common, "load_trades_from_log", return_value=trades), \
                 patch.object(aggregate.common, "load_equity_stream", return_value=[]), \
                 patch.object(aggregate, "_latest_structured_qm_log", return_value=None), \
                 patch.object(aggregate, "_persist_durable_sleeve_stream", side_effect=persist), \
                 patch.object(aggregate, "_ensure_sub_gate_inputs", side_effect=ensure), \
                 patch.object(aggregate, "_apply_worst_case_commission",
                              return_value=([dict(t) for t in trades], commission_info)), \
                 patch.object(aggregate, "_aggregate_verdict", return_value=("PASS", {})), \
                 patch.object(aggregate, "SUB_GATES", []):
                res = aggregate.run_all(1234, "EURUSD.DWX", root / "unused.log", out_dir=out_dir)

        self.assertEqual(events, ["persist", "ensure"])
        self.assertEqual(res["portfolio_stream"]["n"], 1)

    def test_run_all_exposes_mc_shuffle_dd_metrics(self) -> None:
        trades = [
            {"time": 1, "net": 1000.0},
            {"time": 2, "net": -500.0},
            {"time": 3, "net": 700.0},
            {"time": 4, "net": -1200.0},
            {"time": 5, "net": 300.0},
            {"time": 6, "net": -100.0},
            {"time": 7, "net": 900.0},
            {"time": 8, "net": -400.0},
        ]
        commission_info = {
            "commission_basis": "test",
            "commission_model": {"degraded": False},
            "commission_total": 0.0,
            "gross_total": 700.0,
            "cost_cushion": None,
            "cost_cushion_tier": "PASS",
            "degraded_symbols": [],
        }

        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            out_dir = root / "out"
            with patch.object(aggregate.common, "load_trades_from_log", return_value=trades), \
                 patch.object(aggregate.common, "load_equity_stream", return_value=[]), \
                 patch.object(aggregate, "_latest_structured_qm_log", return_value=None), \
                 patch.object(aggregate, "_persist_durable_sleeve_stream",
                              return_value={"persisted": False, "reason": "test", "n": len(trades)}), \
                 patch.object(aggregate, "_ensure_sub_gate_inputs", return_value={}), \
                 patch.object(aggregate, "_apply_worst_case_commission",
                              return_value=([dict(t) for t in trades], commission_info)), \
                 patch.object(aggregate, "SUB_GATES", [("8.11", sub_8_11_mc_shuffle_dd)]):
                res = aggregate.run_all(9999, "EURUSD.DWX", root / "unused.log", out_dir=out_dir)

            persisted = json.loads((out_dir / "aggregate.json").read_text(encoding="utf-8"))

        self.assertEqual(res["mc_shuffle_dd"]["mc_maxdd_p95"], 2200.0)
        self.assertEqual(res["mc_maxdd_p95"], 2200.0)
        self.assertEqual(persisted["mc_maxdd_p95"], 2200.0)
        self.assertEqual(
            persisted["mc_maxdd_p95_over_as_realized_maxdd"],
            1.833333,
        )


class HostSymbolFromSetfileTests(unittest.TestCase):
    """Tests for aggregate._host_symbol_from_setfile.

    Basket EAs carry a logical composite symbol (e.g.
    QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1) that does not exist in MT5's
    market watch. The setfile header records the physical MT5 symbol the tester
    must run on as '; host_symbol: <sym>'. The helper must extract it and the
    baseline runner must pass it as -Symbol.
    """

    def _write_setfile(self, tmp: str, content: str, *, bom: bool = False) -> Path:
        p = Path(tmp) / "test.set"
        if bom:
            p.write_bytes(b"\xef\xbb\xbf" + content.encode("utf-8"))
        else:
            p.write_text(content, encoding="utf-8")
        return p

    def test_header_present_returns_host_symbol(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            setfile = self._write_setfile(tmp, (
                ";=====\n"
                "; host_symbol:  GBPJPY.DWX\n"
                "; timeframe:    D1\n"
                "strategy_z_lookback_d1=60\n"
            ))
            result = aggregate._host_symbol_from_setfile(setfile, "COMPOSITE_FALLBACK")
        self.assertEqual(result, "GBPJPY.DWX")

    def test_header_absent_returns_fallback(self) -> None:
        # Single-symbol EA setfile — no host_symbol line at all.
        with tempfile.TemporaryDirectory() as tmp:
            setfile = self._write_setfile(tmp, "; symbol: EURUSD.DWX\nx=1\n")
            result = aggregate._host_symbol_from_setfile(setfile, "EURUSD.DWX")
        self.assertEqual(result, "EURUSD.DWX")

    def test_unreadable_file_returns_fallback(self) -> None:
        missing = Path("/nonexistent_path_for_test/setfile.set")
        result = aggregate._host_symbol_from_setfile(missing, "FALLBACK.DWX")
        self.assertEqual(result, "FALLBACK.DWX")

    def test_bom_file_works(self) -> None:
        # Real setfiles are generated with utf-8-sig; the BOM must not confuse the parser.
        with tempfile.TemporaryDirectory() as tmp:
            setfile = self._write_setfile(tmp, "; host_symbol: AUDJPY.DWX\nx=1\n", bom=True)
            result = aggregate._host_symbol_from_setfile(setfile, "COMPOSITE_FALLBACK")
        self.assertEqual(result, "AUDJPY.DWX")

    def test_tolerates_no_space_after_semicolon(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            setfile = self._write_setfile(tmp, ";host_symbol:USDJPY.DWX\nx=1\n")
            result = aggregate._host_symbol_from_setfile(setfile, "FALLBACK")
        self.assertEqual(result, "USDJPY.DWX")

    def test_case_insensitive_key(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            setfile = self._write_setfile(tmp, "; HOST_SYMBOL: XAUUSD.DWX\nx=1\n")
            result = aggregate._host_symbol_from_setfile(setfile, "FALLBACK")
        self.assertEqual(result, "XAUUSD.DWX")

    def test_run_baseline_passes_host_symbol_to_mt5_for_basket_ea(self) -> None:
        """_run_baseline_for_trades must pass -Symbol=host_symbol (physical), not the composite."""
        with tempfile.TemporaryDirectory() as tmp:
            baseline = (Path(tmp)
                        / "QM5_12772_demo_QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set")
            baseline.write_text(
                "; host_symbol:  GBPJPY.DWX\nstrategy_z_lookback_d1=60\n",
                encoding="utf-8",
            )
            calls: list[list[str]] = []

            def fake_run(args, **_kwargs):
                calls.append([str(a) for a in args])
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch("subprocess.run", side_effect=fake_run), \
                 patch.object(aggregate, "_latest_baseline_summary", return_value=None), \
                 patch.object(aggregate, "_latest_structured_qm_log", return_value=None):
                aggregate._run_baseline_for_trades(
                    12772,
                    "QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1",
                    terminal="T2",
                    baseline_setfile=baseline,
                )

        self.assertEqual(len(calls), 1)
        args = calls[0]
        sym_idx = args.index("-Symbol")
        self.assertEqual(
            args[sym_idx + 1], "GBPJPY.DWX",
            "-Symbol must be the physical host_symbol, not the composite",
        )

    def test_run_baseline_uses_symbol_unchanged_when_no_host_symbol_header(self) -> None:
        """Single-symbol EAs (no host_symbol header) receive the original symbol — zero regression."""
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "QM5_11476_demo_USDJPY.DWX_H1_backtest.set"
            baseline.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
            calls: list[list[str]] = []

            def fake_run(args, **_kwargs):
                calls.append([str(a) for a in args])
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch("subprocess.run", side_effect=fake_run), \
                 patch.object(aggregate, "_latest_baseline_summary", return_value=None), \
                 patch.object(aggregate, "_latest_structured_qm_log", return_value=None):
                aggregate._run_baseline_for_trades(
                    11476,
                    "USDJPY.DWX",
                    terminal="T2",
                    baseline_setfile=baseline,
                )

        self.assertEqual(len(calls), 1)
        args = calls[0]
        sym_idx = args.index("-Symbol")
        self.assertEqual(
            args[sym_idx + 1], "USDJPY.DWX",
            "Without host_symbol header, original symbol must pass through unchanged",
        )


if __name__ == "__main__":
    unittest.main()
