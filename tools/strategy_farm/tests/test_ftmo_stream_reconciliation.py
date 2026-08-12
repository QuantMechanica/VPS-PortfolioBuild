import json
import sys
import datetime as dt
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_stream_reconciliation as reconciliation  # noqa: E402
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip  # noqa: E402


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
    assert result["contract"] == "one_entry_one_exit_duplicate_closing_commission"


def _full_lifecycle_row(*, net: float, profit: float, entry_time: int) -> dict:
    return {
        "event": "TRADE_CLOSED",
        "money_basis": "FULL_POSITION_LIFECYCLE_ACTUAL_V1",
        "profit": profit,
        "swap": 0.0,
        "fee": 0.0,
        "entry_commission": -1.0,
        "exit_commission": -1.0,
        "commission": -2.0,
        "net": net,
        "entry_time": entry_time,
        "mae_acct": min(-5.0, net),
    }


def test_marked_full_lifecycle_reconciliation_does_not_add_commission_again(
    tmp_path: Path,
) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    rows = [
        _full_lifecycle_row(net=100.0, profit=102.0, entry_time=1),
        _full_lifecycle_row(net=-50.0, profit=-48.0, entry_time=2),
    ]
    _write_stream(stream, rows)
    _write_summary(summary, trades=2, net=50.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "PASS"
    assert result["contract"] == "full_position_lifecycle_actual_v1"
    assert result["stream"]["round_trip_corrected_net"] == 50.0
    assert result["stream"]["closing_commission"] == -2.0
    assert result["stream"]["total_commission"] == -4.0


def test_mixed_legacy_and_marked_money_basis_fails_closed(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    rows = [
        {"event": "TRADE_CLOSED", "net": 10.0, "commission": -1.0, "entry_time": 1, "mae_acct": -2.0},
        _full_lifecycle_row(net=10.0, profit=12.0, entry_time=2),
    ]
    _write_stream(stream, rows)
    _write_summary(summary, trades=2, net=19.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "FAIL"
    assert "stream_mixed_money_basis" in result["reasons"]
    assert result["stream"]["round_trip_corrected_net"] is None


def test_unknown_explicit_money_basis_fails_closed(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    _write_stream(
        stream,
        [{
            "event": "TRADE_CLOSED",
            "money_basis": None,
            "net": 10.0,
            "commission": -1.0,
            "entry_time": 1,
            "mae_acct": -2.0,
        }],
    )
    _write_summary(summary, trades=1, net=9.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "FAIL"
    assert "stream_unknown_money_basis_rows:1" in result["reasons"]


def test_malformed_marked_money_fails_closed(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    row = _full_lifecycle_row(net=100.0, profit=102.0, entry_time=1)
    row["commission"] = -3.0
    _write_stream(stream, [row])
    _write_summary(summary, trades=1, net=100.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "FAIL"
    assert "stream_malformed_money_rows:1" in result["reasons"]


def test_marked_stream_without_fee_fails_closed(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    summary = tmp_path / "summary.json"
    row = _full_lifecycle_row(net=100.0, profit=102.0, entry_time=1)
    row.pop("fee")
    _write_stream(stream, [row])
    _write_summary(summary, trades=1, net=100.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "FAIL"
    assert "stream_malformed_money_rows:1" in result["reasons"]


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


def test_jsonl_duplicate_key_and_numeric_overflow_fail_closed(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    stream.write_text(
        '{"event":"TRADE_CLOSED","net":1,"net":2,"entry_time":1,"mae_acct":1e999}\n',
        encoding="utf-8",
    )
    summary = tmp_path / "summary.json"
    _write_summary(summary, trades=1, net=1.0)

    result = reconciliation.reconcile_case(9001, "NDX.DWX", summary, stream_path=stream)

    assert result["status"] == "FAIL"
    assert "stream_invalid_rows:1" in result["reasons"]


def test_lifecycle_reconciliation_checks_identity_money_and_ambiguity() -> None:
    entry = dt.datetime(2024, 1, 1, 10, 0, tzinfo=dt.UTC)
    exit_ = dt.datetime(2024, 1, 1, 11, 0, tzinfo=dt.UTC)
    trade = RoundTrip(
        entry_time=entry,
        exit_time=exit_,
        symbol="NDX.DWX",
        side="buy",
        volume=1.0,
        entry_price=100.0,
        exit_price=101.0,
        profit=10.0,
        native_swap=-1.0,
        native_commission=-2.0,
        native_entry_commission=-0.75,
        native_exit_commission=-1.25,
    )
    row = {
        "entry_time": int(entry.timestamp()),
        "time": int(exit_.timestamp()),
        "symbol": "NDX.DWX",
        "side": "BUY",
        "volume": 1.0,
        "entry_price": 100.0,
        "exit_price": 101.0,
        "profit": 10.0,
        "swap": -1.0,
        "commission": -2.0,
        "entry_commission": -0.75,
        "exit_commission": -1.25,
        "fee": 0.0,
        "net": 7.0,
    }

    passed, reasons = reconciliation._lifecycle_reconciliation([trade], [row])
    assert passed["status"] == "PASS"
    assert reasons == []

    bad = dict(row, side="SELL", profit=9.0, net=6.0)
    failed, reasons = reconciliation._lifecycle_reconciliation(
        [trade, trade], [row, bad]
    )
    assert failed["status"] == "FAIL"
    assert any("ambiguous_duplicate_lifecycle_identity" in value for value in reasons)
    assert any("identity_mismatch" in value for value in reasons)
    assert any("profit_mismatch" in value for value in reasons)

    swapped_sides = dict(
        row,
        entry_commission=-1.25,
        exit_commission=-0.75,
    )
    side_failed, side_reasons = reconciliation._lifecycle_reconciliation(
        [trade], [swapped_sides]
    )
    assert side_failed["status"] == "FAIL"
    assert any("entry_commission_mismatch" in value for value in side_reasons)
    assert any("exit_commission_mismatch" in value for value in side_reasons)
