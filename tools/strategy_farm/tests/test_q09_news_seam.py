import json
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_seam as seam  # noqa: E402


def _write_snapshots(path: Path, values: list[tuple[int, float]]) -> None:
    rows = [
        {
            "event": "EQUITY_SNAPSHOT",
            "payload": {"day_key": day, "equity": equity},
        }
        for day, equity in values
    ]
    path.write_text(
        "".join(json.dumps(row) + "\n" for row in rows),
        encoding="utf-8",
    )


def test_reconstruct_full_metrics_preserves_cross_seam_drawdown(tmp_path: Path) -> None:
    selection_log = tmp_path / "selection.jsonl"
    holdout_log = tmp_path / "holdout.jsonl"
    _write_snapshots(selection_log, [(20230101, 100.0), (20231231, 120.0)])
    _write_snapshots(holdout_log, [(20240101, 100.0), (20240102, 80.0), (20241231, 110.0)])
    selection = {
        "trades": 10,
        "profit_factor": 2.0,
        "drawdown_pct": 1.0,
        "sharpe": 1.0,
        "net_r": 2.0,
        "original_entries": 12,
        "blocked_entries": 1,
        "affected_entries": 2,
    }
    holdout = {
        "trades": 4,
        "profit_factor": 1.5,
        "drawdown_pct": 2.0,
        "sharpe": 0.5,
        "net_r": 1.0,
        "original_entries": 5,
        "blocked_entries": 2,
        "affected_entries": 3,
    }

    result = seam.reconstruct_full_metrics(
        selection,
        holdout,
        selection_logger_path=selection_log,
        holdout_logger_path=holdout_log,
        selection_gross_profit=200.0,
        selection_gross_loss=-100.0,
        holdout_gross_profit=75.0,
        holdout_gross_loss=-50.0,
    )

    assert result["metrics"]["trades"] == 14
    assert result["metrics"]["profit_factor"] == 275.0 / 150.0
    assert result["metrics"]["drawdown_pct"] == 20.0 / 120.0 * 100.0
    assert result["metrics"]["net_r"] == 3.0
    assert result["metrics"]["original_entries"] == 17
    assert result["seam_reconstructed"] is True
    assert result["selection_snapshot_count"] == 2
    assert result["holdout_snapshot_count"] == 3
