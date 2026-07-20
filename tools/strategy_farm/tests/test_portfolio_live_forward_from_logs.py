import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.portfolio_live_forward_from_logs import (  # noqa: E402
    collect_forward_equity_from_logs,
)


class PortfolioLiveForwardEquityTests(unittest.TestCase):
    @staticmethod
    def _write_log(path: Path, equities: list[tuple[int, float]], *, scoped: bool) -> None:
        rows = []
        for day_key, equity in equities:
            payload = {"day_key": day_key, "equity": equity}
            if scoped:
                payload["scope"] = "account"
            rows.append({"event": "EQUITY_SNAPSHOT", "payload": payload})
        path.write_text(
            "\n".join(json.dumps(row, separators=(",", ":")) for row in rows) + "\n",
            encoding="utf-8",
        )

    def test_account_snapshots_across_sleeves_are_medianed_never_summed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            log_dir = Path(tmp)
            self._write_log(
                log_dir / "QM5_1001_ea-1001.log",
                [(20260718, 100_001.0), (20260719, 100_011.0)],
                scoped=False,
            )
            self._write_log(
                log_dir / "QM5_1002_ea-1002.log",
                [(20260718, 100_003.0), (20260719, 100_013.0)],
                scoped=True,
            )

            result = collect_forward_equity_from_logs(
                log_dir,
                {"starting_capital": 100_000.0},
            )

        self.assertEqual(result["equity_curve"], [100_002.0, 100_012.0])
        self.assertEqual(result["daily_pnl"], [10.0])
        self.assertNotEqual(result["equity_curve"][0], 100_001.0 + 100_003.0)
        self.assertEqual(result["sleeves"], {})


if __name__ == "__main__":
    unittest.main()
