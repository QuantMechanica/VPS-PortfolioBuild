import datetime as dt
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.portfolio_burnin import (  # noqa: E402
    ConfigError,
    burnin_verdict,
    collect_forward_equity,
    load_burnin_config,
    main,
)


class PortfolioBurninTests(unittest.TestCase):
    def test_forward_equity_below_mc_p95_and_sharpe_in_band_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            self._write_stream(common_dir, "100_EURUSD_DWX.jsonl", [40.0, 20.0, -30.0, 35.0])
            manifest = self._manifest(sharpe=9.3132846448)

            forward = collect_forward_equity(common_dir, manifest)
            verdict = burnin_verdict(
                manifest,
                forward,
                self._mc_artifact(p95=1.0),
                dd_tolerance=0.0,
                sharpe_band=0.01,
            )

        self.assertEqual(verdict["status"], "EVIDENCE_FOR_OWNER")
        self.assertEqual(verdict["verdict"], "PASS")
        self.assertEqual(verdict["reasons"], [])

    def test_forward_drawdown_above_mc_p95_fails_with_reason(self) -> None:
        manifest = self._manifest(sharpe=1.0)
        forward = {"daily_pnl": [100.0, -500.0, 50.0]}

        verdict = burnin_verdict(
            manifest,
            forward,
            self._mc_artifact(p95=2.0),
            dd_tolerance=0.0,
            sharpe_band=100.0,
        )

        self.assertEqual(verdict["verdict"], "FAIL")
        self.assertTrue(any("exceeds Monte-Carlo p95" in reason for reason in verdict["reasons"]))

    def test_missing_config_placeholders_refuse_with_clear_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "portfolio_burnin.json"
            config_path.write_text(
                json.dumps(
                    {
                        "_owner_must_set": [
                            "demo_account.account_label",
                            "pass_tolerances.dd_tolerance",
                        ],
                        "demo_account": {
                            "account_label": "OWNER_SET_DEMO_ACCOUNT_LABEL",
                        },
                        "pass_tolerances": {
                            "dd_tolerance": "OWNER_SET_DD_TOLERANCE",
                        },
                    }
                ),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ConfigError, "OWNER must set"):
                load_burnin_config(config_path)

    def test_cli_refuses_unset_config_before_real_burnin(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "portfolio_burnin.json"
            config_path.write_text(
                json.dumps(
                    {
                        "_owner_must_set": ["demo_account.account_label"],
                        "demo_account": {
                            "account_label": "OWNER_SET_DEMO_ACCOUNT_LABEL",
                        },
                    }
                ),
                encoding="utf-8",
            )

            stdout = io.StringIO()
            with redirect_stdout(stdout):
                rc = main(
                    [
                        "--manifest",
                        str(Path(tmp) / "missing_manifest.json"),
                        "--demo-results-dir",
                        str(Path(tmp) / "missing_demo"),
                        "--out",
                        str(Path(tmp) / "out"),
                        "--config",
                        str(config_path),
                    ]
                )

        self.assertEqual(rc, 2)
        self.assertIn("portfolio burn-in refused: OWNER must set", stdout.getvalue())

    def _manifest(self, *, sharpe: float) -> dict[str, object]:
        return {
            "starting_capital": 10_000.0,
            "n_sleeves": 1,
            "kpis": {"sharpe": sharpe, "max_drawdown_pct": 0.5},
            "sleeves": [
                {
                    "ea_id": 100,
                    "symbol": "EURUSD.DWX",
                    "weight": 1.0,
                }
            ],
        }

    def _mc_artifact(self, *, p95: float) -> dict[str, object]:
        return {
            "block_bootstrap": {
                "max_drawdown_pct": {
                    "p95": p95,
                }
            }
        }

    def _write_stream(self, common_dir: Path, filename: str, pnl: list[float]) -> None:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True)
        start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
        with (stream_dir / filename).open("w", encoding="utf-8") as fh:
            for offset, net in enumerate(pnl):
                row = {
                    "event": "TRADE_CLOSED",
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": net,
                    "profit": net,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 0.0,
                    "notional": 0.0,
                    "symbol": "EURUSD.DWX",
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")


if __name__ == "__main__":
    unittest.main()
