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
    build_artifact,
    combine_daily_pnl,
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


if __name__ == "__main__":
    unittest.main()
