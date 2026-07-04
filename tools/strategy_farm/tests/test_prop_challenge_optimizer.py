import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.prop_challenge_optimizer import (  # noqa: E402
    _filter_daily_pnl,
    build_artifact,
    build_round24_candidate_screen_artifact,
    combine_daily_pnl,
    main,
    parse_mt5_report_daily_pnl,
    write_artifact,
)


class PropChallengeOptimizerTests(unittest.TestCase):
    def test_single_ranking_prefers_fast_ftmo_stream(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp) / "common"
            self._write_stream(common_dir, 100, "EURUSD.DWX", [6000.0] * 8)
            self._write_stream(common_dir, 200, "GBPUSD.DWX", [100.0] * 8)

            artifact = build_artifact(
                common_dir=common_dir,
                all_streams=True,
                risk_scales=[1.0],
                runs=50,
                block_days=1,
                seed=3,
                phase_horizon_days=4,
                max_combo_size=1,
                top_single_pool=2,
                top_results=5,
            )

        self.assertEqual(artifact["n_single_results"], 2)
        self.assertEqual(artifact["n_combo_results"], 0)
        self.assertEqual(artifact["top_overall"][0]["keys"], ["100:EURUSD.DWX"])
        self.assertEqual(artifact["top_overall"][0]["sample_status"], "LOW_SAMPLE")
        self.assertEqual(artifact["top_overall"][0]["best"]["status"], "SPRINT_CANDIDATE")
        self.assertGreater(artifact["top_overall"][0]["best"]["robust_pass_probability_pct"], 0.0)

    def test_combo_generation_uses_top_single_pool(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp) / "common"
            self._write_stream(common_dir, 100, "EURUSD.DWX", [6000.0] * 8)
            self._write_stream(common_dir, 200, "GBPUSD.DWX", [5000.0] * 8)
            self._write_stream(common_dir, 300, "USDJPY.DWX", [10.0] * 8)

            artifact = build_artifact(
                common_dir=common_dir,
                all_streams=True,
                risk_scales=[1.0],
                runs=20,
                block_days=1,
                seed=5,
                phase_horizon_days=4,
                max_combo_size=2,
                top_single_pool=2,
                top_results=10,
            )

        self.assertEqual(artifact["single_pool"], ["100:EURUSD.DWX", "200:GBPUSD.DWX"])
        self.assertEqual(artifact["n_combo_results"], 1)
        self.assertEqual(
            artifact["top_combinations"][0]["keys"],
            ["100:EURUSD.DWX", "200:GBPUSD.DWX"],
        )

    def test_risk_too_high_status_when_daily_loss_breaches(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp) / "common"
            self._write_stream(common_dir, 100, "EURUSD.DWX", [-6000.0] * 8)

            artifact = build_artifact(
                common_dir=common_dir,
                all_streams=True,
                risk_scales=[1.0],
                runs=20,
                block_days=1,
                seed=7,
                phase_horizon_days=4,
                max_combo_size=1,
                top_results=1,
            )

        best = artifact["top_overall"][0]["best"]
        self.assertEqual(best["status"], "RISK_TOO_HIGH")
        self.assertGreater(best["daily_loss_breach_probability_pct"], 0.0)

    def test_combine_daily_pnl_equal_weights_on_union_dates(self) -> None:
        day1 = dt.date(2024, 1, 1)
        day3 = dt.date(2024, 1, 3)
        day4 = dt.date(2024, 1, 4)
        combined = combine_daily_pnl(
            [(1, "A"), (2, "B")],
            {
                (1, "A"): {day1: 10.0, day3: 20.0},
                (2, "B"): {day3: 40.0, day4: 60.0},
            },
        )

        self.assertEqual(combined, [5.0, 0.0, 30.0, 30.0])

    def test_write_artifact_round_trips_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "artifact.json"
            artifact = {"phase": "Q_PROP_SPRINT_OPTIMIZER", "top_overall": []}
            write_artifact(artifact, path)

            loaded = json.loads(path.read_text(encoding="utf-8"))

        self.assertEqual(loaded, artifact)

    def test_parse_mt5_report_daily_pnl_uses_closing_deal_commission_basis(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "report.htm"
            total = self._write_report(
                report,
                "EURUSD.DWX",
                [
                    (dt.date(2024, 1, 1), 110.0, 1.0),
                    (dt.date(2024, 1, 2), -50.0, 1.0),
                ],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 3),
            )

            parsed = parse_mt5_report_daily_pnl(report, expected_symbol="EURUSD.DWX")

        self.assertEqual(parsed["closed_trades"], 2)
        self.assertEqual(parsed["calendar_days"], 3)
        self.assertAlmostEqual(parsed["net"], total)
        self.assertAlmostEqual(parsed["report_net_delta"], 0.0)
        self.assertAlmostEqual(parsed["daily_pnl"][dt.date(2024, 1, 1)], 105.0)
        self.assertAlmostEqual(parsed["daily_pnl"][dt.date(2024, 1, 2)], -55.0)
        self.assertAlmostEqual(parsed["daily_pnl"][dt.date(2024, 1, 3)], 0.0)

    def test_round24_candidate_screen_builds_verdict_artifact_from_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            lead_a = root / "lead_a.htm"
            lead_b = root / "lead_b.htm"
            candidate = root / "candidate.htm"
            self._write_report(
                lead_a,
                "EURUSD.DWX",
                [
                    (dt.date(2024, 1, 1), 3000.0, 1.0),
                    (dt.date(2024, 1, 2), -500.0, 1.0),
                    (dt.date(2024, 1, 3), 3000.0, 1.0),
                    (dt.date(2024, 1, 4), -500.0, 1.0),
                ],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 4),
            )
            self._write_report(
                lead_b,
                "GBPUSD.DWX",
                [
                    (dt.date(2024, 1, 1), -250.0, 1.0),
                    (dt.date(2024, 1, 2), 2000.0, 1.0),
                    (dt.date(2024, 1, 3), -250.0, 1.0),
                    (dt.date(2024, 1, 4), 2000.0, 1.0),
                ],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 4),
            )
            self._write_report(
                candidate,
                "USDJPY.DWX",
                [
                    (dt.date(2024, 1, 1), 4000.0, 1.0),
                    (dt.date(2024, 1, 2), 4000.0, 1.0),
                    (dt.date(2024, 1, 3), 4000.0, 1.0),
                    (dt.date(2024, 1, 4), 4000.0, 1.0),
                ],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 4),
            )
            round24 = root / "round24.json"
            round24.write_text(
                json.dumps(
                    {
                        "keys": ["QM5_1:EURUSD.DWX", "QM5_2:GBPUSD.DWX"],
                        "weights": [0.6, 0.4],
                        "source_reports": {
                            "QM5_1:EURUSD.DWX": str(lead_a),
                            "QM5_2:GBPUSD.DWX": str(lead_b),
                        },
                        "runs_per_seed": 5,
                        "seeds": [0, 1],
                        "block_days": 1,
                        "phase_horizon_days": 4,
                        "starting_capital": 100000.0,
                        "preset": "FTMO_2STEP",
                        "results": [
                            {
                                "risk_scale": 1.0,
                                "summary": {
                                    "min_robust_pass_probability_pct": 0.0,
                                    "mean_robust_pass_probability_pct": 0.0,
                                    "max_daily_loss_breach_probability_pct": 0.0,
                                    "max_max_loss_breach_probability_pct": 5.0,
                                    "mean_target_not_reached_probability_pct": 100.0,
                                },
                            },
                            {
                                "risk_scale": 2.0,
                                "summary": {
                                    "min_robust_pass_probability_pct": 90.0,
                                    "mean_robust_pass_probability_pct": 90.0,
                                    "max_daily_loss_breach_probability_pct": 0.0,
                                    "max_max_loss_breach_probability_pct": 9.0,
                                    "mean_target_not_reached_probability_pct": 10.0,
                                },
                            },
                        ],
                    }
                ),
                encoding="utf-8",
            )

            artifact = build_round24_candidate_screen_artifact(
                candidate_ea_id="QM5_3",
                candidate_symbol="USDJPY.DWX",
                candidate_report=candidate,
                round24_artifact_path=round24,
                candidate_weights=[0.1],
                risk_scales=[1.0],
                runs=5,
                block_days=1,
                seed=0,
                seeds=[0, 1],
                phase_horizon_days=4,
                force_confirm=True,
            )

        self.assertEqual(artifact["phase"], "Q_PROP_ROUND24_ADMISSION_SCREEN")
        self.assertEqual(artifact["candidate"]["key"], "QM5_3:USDJPY.DWX")
        self.assertEqual(artifact["benchmark"]["risk_scale"], 1.0)
        self.assertIn(artifact["verdict"], {"ADMIT", "BACKUP", "REJECT"})
        self.assertIsNotNone(artifact["confirmation"])
        self.assertEqual(len(artifact["screen"]["results"]), 1)
        self.assertAlmostEqual(sum(artifact["screen"]["selected_seed0"]["weights"]), 1.0)

    def test_screen_candidate_cli_writes_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            lead = root / "lead.htm"
            candidate = root / "candidate.htm"
            out_path = root / "screen.json"
            round24 = root / "round24.json"
            self._write_report(
                lead,
                "EURUSD.DWX",
                [(dt.date(2024, 1, day), 2500.0, 1.0) for day in range(1, 5)],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 4),
            )
            self._write_report(
                candidate,
                "GBPUSD.DWX",
                [(dt.date(2024, 1, day), 400.0, 1.0) for day in range(1, 5)],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 4),
            )
            write_artifact(
                {
                    "keys": ["QM5_10:EURUSD.DWX"],
                    "weights": [1.0],
                    "source_reports": {"QM5_10:EURUSD.DWX": str(lead)},
                    "runs_per_seed": 5,
                    "seeds": [0, 1],
                    "block_days": 1,
                    "phase_horizon_days": 4,
                    "starting_capital": 100000.0,
                    "preset": "FTMO_2STEP",
                    "results": [
                        {
                            "risk_scale": 1.0,
                            "summary": {
                                "min_robust_pass_probability_pct": 0.0,
                                "mean_robust_pass_probability_pct": 0.0,
                                "max_daily_loss_breach_probability_pct": 0.0,
                                "max_max_loss_breach_probability_pct": 4.0,
                                "mean_target_not_reached_probability_pct": 100.0,
                            },
                        }
                    ],
                },
                round24,
            )

            rc = main(
                [
                    "--screen-candidate",
                    "QM5_11",
                    "GBPUSD.DWX",
                    "--candidate-report",
                    str(candidate),
                    "--round24-artifact",
                    str(round24),
                    "--screen-risk-scales",
                    "1",
                    "--candidate-weights",
                    "0.1",
                    "--screen-runs",
                    "5",
                    "--screen-seeds",
                    "0,1",
                    "--block-days",
                    "1",
                    "--phase-horizon-days",
                    "4",
                    "--force-confirm",
                    "--out",
                    str(out_path),
                ]
            )
            artifact = json.loads(out_path.read_text(encoding="utf-8"))

        self.assertEqual(rc, 0)
        self.assertEqual(artifact["phase"], "Q_PROP_ROUND24_ADMISSION_SCREEN")
        self.assertEqual(artifact["candidate"]["key"], "QM5_11:GBPUSD.DWX")
        self.assertIn("deltas_vs_round24", artifact)

    def test_filter_daily_pnl_inclusive_bounds(self) -> None:
        mapping = {
            dt.date(2024, 1, 1): 1.0,
            dt.date(2024, 1, 2): 2.0,
            dt.date(2024, 1, 3): 3.0,
            dt.date(2024, 1, 4): 4.0,
            dt.date(2024, 1, 5): 5.0,
        }
        result = _filter_daily_pnl(mapping, dt.date(2024, 1, 2), dt.date(2024, 1, 4))
        self.assertEqual(
            result,
            {
                dt.date(2024, 1, 2): 2.0,
                dt.date(2024, 1, 3): 3.0,
                dt.date(2024, 1, 4): 4.0,
            },
        )

    def test_filter_daily_pnl_none_bounds_passthrough(self) -> None:
        mapping = {dt.date(2024, 1, day): float(day) for day in range(1, 6)}
        self.assertEqual(_filter_daily_pnl(mapping, None, None), dict(mapping))
        result_from = _filter_daily_pnl(mapping, dt.date(2024, 1, 3), None)
        self.assertEqual(
            set(result_from.keys()),
            {dt.date(2024, 1, 3), dt.date(2024, 1, 4), dt.date(2024, 1, 5)},
        )
        result_to = _filter_daily_pnl(mapping, None, dt.date(2024, 1, 2))
        self.assertEqual(
            set(result_to.keys()),
            {dt.date(2024, 1, 1), dt.date(2024, 1, 2)},
        )

    def test_filter_daily_pnl_thin_window_raises(self) -> None:
        """Restricting any leg to < 30 calendar days must raise ValueError."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            lead = root / "lead.htm"
            candidate = root / "candidate.htm"
            round24 = root / "round24.json"
            # Reports span Jan 2024 (31 calendar days); filter to 14 days triggers the guard.
            self._write_report(
                lead,
                "EURUSD.DWX",
                [(dt.date(2024, 1, d), 100.0, 1.0) for d in range(1, 5)],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 31),
            )
            self._write_report(
                candidate,
                "GBPUSD.DWX",
                [(dt.date(2024, 1, d), 100.0, 1.0) for d in range(1, 5)],
                start=dt.date(2024, 1, 1),
                end=dt.date(2024, 1, 31),
            )
            write_artifact(
                {
                    "keys": ["QM5_1:EURUSD.DWX"],
                    "weights": [1.0],
                    "source_reports": {"QM5_1:EURUSD.DWX": str(lead)},
                    "runs_per_seed": 5,
                    "seeds": [0],
                    "block_days": 1,
                    "phase_horizon_days": 4,
                    "starting_capital": 100000.0,
                    "preset": "FTMO_2STEP",
                    "results": [
                        {
                            "risk_scale": 1.0,
                            "summary": {
                                "min_robust_pass_probability_pct": 0.0,
                                "mean_robust_pass_probability_pct": 0.0,
                                "max_daily_loss_breach_probability_pct": 0.0,
                                "max_max_loss_breach_probability_pct": 4.0,
                                "mean_target_not_reached_probability_pct": 100.0,
                            },
                        }
                    ],
                },
                round24,
            )
            with self.assertRaises(ValueError) as ctx:
                build_round24_candidate_screen_artifact(
                    candidate_ea_id="QM5_2",
                    candidate_symbol="GBPUSD.DWX",
                    candidate_report=candidate,
                    round24_artifact_path=round24,
                    candidate_weights=[0.1],
                    risk_scales=[1.0],
                    runs=5,
                    block_days=1,
                    seed=0,
                    seeds=[0],
                    phase_horizon_days=4,
                    pnl_from_date=dt.date(2024, 1, 1),
                    pnl_to_date=dt.date(2024, 1, 14),  # only 14 days — must raise
                )
            self.assertIn("30", str(ctx.exception))

    def _write_stream(self, common_dir: Path, ea_id: int, symbol: str, net_of_cost: list[float]) -> None:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True, exist_ok=True)
        model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
        cost = model.cost_round_trip(symbol, 1.0, 10000.0)
        start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
        filename = f"{ea_id}_{symbol.replace('.', '_')}.jsonl"
        with (stream_dir / filename).open("w", encoding="utf-8") as fh:
            for offset, value in enumerate(net_of_cost):
                row = {
                    "event": "TRADE_CLOSED",
                    "symbol": symbol,
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": value + cost,
                    "profit": value + cost,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")

    def _write_report(
        self,
        path: Path,
        symbol: str,
        closes: list[tuple[dt.date, float, float]],
        *,
        start: dt.date,
        end: dt.date,
    ) -> float:
        rows: list[str] = []
        balance = 100000.0
        rows.append(
            "<tr bgcolor=\"#FFFFFF\" align=right>"
            "<td>2024.01.01 00:00:00</td><td>1</td><td></td><td>balance</td>"
            "<td></td><td></td><td></td><td></td><td>0.00</td><td>0.00</td>"
            "<td>100 000.00</td><td>100 000.00</td><td></td></tr>"
        )
        deal_id = 2
        total = 0.0
        gross_profit = 0.0
        gross_loss = 0.0
        for day, profit, volume in closes:
            commission = -2.5 * volume
            total += profit + 2.0 * commission
            balance += commission
            rows.append(
                "<tr bgcolor=\"#F7F7F7\" align=right>"
                f"<td>{day:%Y.%m.%d} 01:00:00</td><td>{deal_id}</td><td>{symbol}</td>"
                f"<td>buy</td><td>in</td><td>{volume:.2f}</td><td>1.00000</td><td>{deal_id}</td>"
                f"<td>{commission:.2f}</td><td>0.00</td><td>0.00</td><td>{balance:.2f}</td><td></td></tr>"
            )
            deal_id += 1
            balance += profit + commission
            rows.append(
                "<tr bgcolor=\"#FFFFFF\" align=right>"
                f"<td>{day:%Y.%m.%d} 12:00:00</td><td>{deal_id}</td><td>{symbol}</td>"
                f"<td>sell</td><td>out</td><td>{volume:.2f}</td><td>1.00000</td><td>{deal_id}</td>"
                f"<td>{commission:.2f}</td><td>0.00</td><td>{profit:.2f}</td><td>{balance:.2f}</td><td></td></tr>"
            )
            deal_id += 1
            if profit > 0.0:
                gross_profit += profit
            else:
                gross_loss += profit

        pf = gross_profit / abs(gross_loss) if gross_loss else 99.0
        html = f"""<!DOCTYPE html>
<html><body><table>
<tr><td colspan="13"><b>Settings</b></td></tr>
<tr><td colspan="3">Expert:</td><td colspan="10"><b>QM5_test</b></td></tr>
<tr><td colspan="3">Symbol:</td><td colspan="10"><b>{symbol}</b></td></tr>
<tr><td colspan="3">Period:</td><td colspan="10"><b>H1 ({start:%Y.%m.%d} - {end:%Y.%m.%d})</b></td></tr>
<tr><td colspan="13"><b>Results</b></td></tr>
<tr><td colspan="3">Total Net Profit:</td><td><b>{total:.2f}</b></td>
<td colspan="3">Equity Drawdown Maximal:</td><td><b>1 000.00 (1.00%)</b></td></tr>
<tr><td colspan="3">Gross Profit:</td><td><b>{gross_profit:.2f}</b></td>
<td colspan="3">Gross Loss:</td><td><b>{gross_loss:.2f}</b></td>
<td colspan="3">Profit Factor:</td><td><b>{pf:.2f}</b></td></tr>
<tr><td colspan="3">Total Trades:</td><td><b>{len(closes)}</b></td></tr>
<tr><th colspan="13"><div><b>Deals</b></div></th></tr>
<tr><td><b>Time</b></td><td><b>Deal</b></td><td><b>Symbol</b></td><td><b>Type</b></td>
<td><b>Direction</b></td><td><b>Volume</b></td><td><b>Price</b></td><td><b>Order</b></td>
<td><b>Commission</b></td><td><b>Swap</b></td><td><b>Profit</b></td><td><b>Balance</b></td><td><b>Comment</b></td></tr>
{''.join(rows)}
</table></body></html>"""
        path.write_text(html, encoding="utf-16")
        return round(total, 10)


if __name__ == "__main__":
    unittest.main()
