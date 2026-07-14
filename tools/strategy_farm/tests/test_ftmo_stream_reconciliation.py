import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_stream_reconciliation as reconciliation  # noqa: E402


def _write_summary(path: Path, *, trades: int, net: float) -> None:
    path.write_text(
        json.dumps({
            "result": "PASS",
            "runs": [{
                "run": "run_01",
                "status": "OK",
                "total_trades": trades,
                "profit_factor": 1.3,
                "net_profit": net,
                "drawdown": 1000.0,
            }],
        }),
        encoding="utf-8",
    )


def _write_stream(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")


def test_exact_round_trip_reconciliation_passes(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    rows = [
        {"event": "TRADE_CLOSED", "net": 102.0, "commission": -2.0, "entry_time": 1, "mae_acct": -5.0},
        {"event": "TRADE_CLOSED", "net": -48.0, "commission": -2.0, "entry_time": 2, "mae_acct": -50.0},
    ]
    _write_stream(stream, rows)
    _write_summary(summary, trades=2, net=50.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "PASS"
    assert result["corrected_net_delta"] == 0.0


def test_trade_count_and_net_mismatch_fail(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    _write_stream(
        stream,
        [{"event": "TRADE_CLOSED", "net": 10.0, "commission": -1.0, "entry_time": 1, "mae_acct": -2.0}],
    )
    _write_summary(summary, trades=2, net=25.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "FAIL"
    assert any(reason.startswith("trade_count_mismatch:") for reason in result["reasons"])
    assert any(reason.startswith("corrected_net_mismatch:") for reason in result["reasons"])


def test_missing_mae_fails_even_when_net_matches(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    _write_stream(stream, [{"event": "TRADE_CLOSED", "net": 10.0, "commission": -1.0}])
    _write_summary(summary, trades=1, net=9.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "FAIL"
    assert result["reasons"] == ["stream_missing_mae_rows:1"]
