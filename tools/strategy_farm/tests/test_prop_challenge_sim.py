import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.prop_challenge_sim import (  # noqa: E402
    FTMO_2STEP,
    build_artifact,
    combine_calendar_daily_pnl,
    evaluate_challenge,
    evaluate_phase,
    write_artifact,
)


class PropChallengeSimTests(unittest.TestCase):
    def test_phase_target_waits_for_minimum_trading_days(self) -> None:
        phase = FTMO_2STEP.phases[0]

        result = evaluate_phase([5000.0, 5000.0, 0.0, 0.0], phase, starting_capital=100_000.0)

        self.assertTrue(result["passed"])
        self.assertEqual(result["target_day"], 2)
        self.assertEqual(result["days"], 4)

    def test_daily_loss_breach_is_conservative_at_threshold(self) -> None:
        phase = FTMO_2STEP.phases[0]

        result = evaluate_phase([-5000.0], phase, starting_capital=100_000.0)

        self.assertFalse(result["passed"])
        self.assertEqual(result["reason"], "daily_loss_breach")
        self.assertEqual(result["max_closed_daily_loss_pct"], 5.0)

    def test_max_loss_breach_catches_cumulative_loss(self) -> None:
        phase = FTMO_2STEP.phases[0]

        result = evaluate_phase([-4000.0, -4000.0, -3000.0], phase, starting_capital=100_000.0)

        self.assertFalse(result["passed"])
        self.assertEqual(result["reason"], "max_loss_breach")
        self.assertEqual(result["max_total_loss_pct"], 11.0)

    def test_two_step_challenge_resets_equity_per_phase_and_consumes_days(self) -> None:
        daily = [5000.0, 5000.0, 0.0, 0.0, 2500.0, 2500.0, 0.0, 0.0]

        result = evaluate_challenge(
            daily,
            FTMO_2STEP,
            starting_capital=100_000.0,
            phase_horizon_days=4,
        )

        self.assertTrue(result["passed"])
        self.assertEqual(result["total_days"], 8)
        self.assertEqual([phase["target_day"] for phase in result["phases"]], [2, 2])

    def test_build_artifact_from_q08_stream_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            out1 = root / "one.json"
            out2 = root / "two.json"
            self._write_stream(common_dir, [6000.0, 6000.0, 0.0, 0.0, 3000.0, 3000.0, 0.0, 0.0])

            kwargs = {
                "common_dir": common_dir,
                "all_streams": True,
                "runs": 100,
                "block_days": 2,
                "seed": 17,
                "starting_capital": 100_000.0,
                "phase_horizon_days": 4,
            }
            artifact1 = build_artifact(**kwargs)
            artifact2 = build_artifact(**kwargs)
            artifact1["generated_at_utc"] = "fixed"
            artifact2["generated_at_utc"] = "fixed"
            write_artifact(artifact1, out1)
            write_artifact(artifact2, out2)
            written1 = json.loads(out1.read_text(encoding="utf-8"))
            written2 = json.loads(out2.read_text(encoding="utf-8"))

        self.assertEqual(artifact1, artifact2)
        self.assertEqual(written1, artifact1)
        self.assertEqual(written2, artifact2)
        self.assertEqual(artifact1["preset"], "FTMO_2STEP")
        self.assertEqual(artifact1["n_series"], 1)
        self.assertEqual(artifact1["observed"]["reason"], "passed")
        self.assertIn("block_bootstrap", artifact1["simulation"])

    def test_missing_selected_key_raises_clear_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "selected stream"):
                build_artifact(
                    common_dir=Path(tmp),
                    selected_keys=[(999, "EURUSD.DWX")],
                    runs=1,
                )

    def test_calendar_combiner_preserves_zero_pnl_gap_days(self) -> None:
        day1 = dt.date(2024, 1, 1)
        day3 = dt.date(2024, 1, 3)

        combined = combine_calendar_daily_pnl(
            [(1, "EURUSD.DWX")],
            {(1, "EURUSD.DWX"): {day1: 10.0, day3: 30.0}},
            [1.0],
        )

        self.assertEqual(combined, [10.0, 0.0, 30.0])

    def _write_stream(self, common_dir: Path, net_of_cost: list[float]) -> None:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True)
        model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
        cost = model.cost_round_trip("EURUSD.DWX", 1.0, 10000.0)
        start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
        with (stream_dir / "100_EURUSD_DWX.jsonl").open("w", encoding="utf-8") as fh:
            for offset, value in enumerate(net_of_cost):
                row = {
                    "event": "TRADE_CLOSED",
                    "symbol": "EURUSD.DWX",
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": value + cost,
                    "profit": value + cost,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")


if __name__ == "__main__":
    unittest.main()
