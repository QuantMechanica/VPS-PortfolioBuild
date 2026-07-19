from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

import pytest

from tools.strategy_farm.dxz_cost_evidence import (
    CostEvidenceError,
    RoundTrip,
    build_report,
    evaluate_input,
    evaluate_trades,
    validate_formula,
    write_immutable_report,
)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _report(*, second_trade: bool = True, native_commission: float = 0.0) -> str:
    total_trades = 2 if second_trade else 1
    net = 100.0 + native_commission
    deals = f"""
    <tr><th>Deals</th></tr>
    <tr><td>Time</td><td>Deal</td><td>Symbol</td><td>Type</td><td>Direction</td><td>Volume</td><td>Price</td><td>Order</td><td>Commission</td><td>Swap</td><td>Profit</td><td>Balance</td><td>Comment</td></tr>
    <tr><td>2024.01.01 00:00:00</td><td>1</td><td>EURUSD.DWX</td><td>buy</td><td>in</td><td>1.00</td><td>1.10000</td><td>1</td><td>0.00</td><td>0.00</td><td>0.00</td><td>100000.00</td><td>entry</td></tr>
    <tr><td>2024.01.02 00:00:00</td><td>2</td><td>EURUSD.DWX</td><td>sell</td><td>out</td><td>1.00</td><td>1.10100</td><td>2</td><td>{native_commission:.2f}</td><td>0.00</td><td>100.00</td><td>{100000.0 + net:.2f}</td><td>exit</td></tr>
    """
    if second_trade:
        deals += """
        <tr><td>2024.01.03 00:00:00</td><td>3</td><td>EURUSD.DWX</td><td>buy</td><td>in</td><td>0.50</td><td>1.20000</td><td>3</td><td>0.00</td><td>0.00</td><td>0.00</td><td>100100.00</td><td>entry</td></tr>
        <tr><td>2024.01.04 00:00:00</td><td>4</td><td>EURUSD.DWX</td><td>sell</td><td>out</td><td>0.50</td><td>1.20000</td><td>4</td><td>0.00</td><td>0.00</td><td>0.00</td><td>100100.00</td><td>exit</td></tr>
        """
    return f"""<!DOCTYPE html><html><body><table>
    <tr><td>Expert:</td><td>QM5_99999_fixture</td></tr>
    <tr><td>Symbol:</td><td>EURUSD.DWX</td></tr>
    <tr><td>Period:</td><td>Hourly (2024.01.01 - 2024.12.31)</td></tr>
    <tr><td>Currency:</td><td>EUR</td></tr>
    <tr><td>History Quality:</td><td>100% real ticks</td></tr>
    <tr><td>Total Net Profit:</td><td>{net:.2f}</td></tr>
    <tr><td>Gross Profit:</td><td>100.00</td></tr>
    <tr><td>Gross Loss:</td><td>0.00</td></tr>
    <tr><td>Profit Factor:</td><td>0.00</td></tr>
    <tr><td>Total Trades:</td><td>{total_trades}</td></tr>
    <tr><td>Equity Drawdown Maximal:</td><td>0.00 (0.00%)</td></tr>
    {deals}</table></body></html>"""


def _fixture_inputs(tmp_path: Path) -> tuple[Path, Path, Path]:
    report = tmp_path / "report.htm"
    report.write_text(_report(), encoding="utf-16")
    q08 = tmp_path / "q08_stream.jsonl"
    q08.write_text(
        "\n".join(
            [
                json.dumps({"symbol": "EURUSD.DWX", "notional": 110100.0}),
                json.dumps({"symbol": "EURUSD.DWX", "notional": 60000.0}),
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    receipt = tmp_path / "receipt.json"
    receipt.write_text(
        json.dumps(
            {
                "job": {"ea_id": 99999, "symbol": "EURUSD.DWX", "timeframe": "H1"},
                "identity": {
                    "native_report_sha256": _sha(report),
                    "q08_stream_sha256": _sha(q08),
                },
                "native_report_copy_hash_match": True,
                "native_report_window_match": True,
                "native_report_trade_count_match": True,
                "native_report_stability": {"stable": True},
                "native_metrics": {"closed_trades": 2},
                "status": "FAIL",
            },
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    return receipt, report, q08


def test_zero_move_is_explicitly_bounded_from_same_symbol() -> None:
    trades = [
        RoundTrip(
            entry_time="2024.01.01 00:00:00",
            exit_time="2024.01.02 00:00:00",
            entry_deal="1",
            exit_deal="2",
            symbol="EURUSD.DWX",
            side="buy",
            volume=1.0,
            entry_price=1.1,
            exit_price=1.101,
            gross_pnl=100.0,
            gross_pnl_rounding_half_width=0.005,
            recorded_swap=0.0,
            native_commission=0.0,
        ),
        RoundTrip(
            entry_time="2024.01.03 00:00:00",
            exit_time="2024.01.04 00:00:00",
            entry_deal="3",
            exit_deal="4",
            symbol="EURUSD.DWX",
            side="buy",
            volume=0.5,
            entry_price=1.2,
            exit_price=1.2,
            gross_pnl=0.0,
            gross_pnl_rounding_half_width=0.005,
            recorded_swap=0.0,
            native_commission=0.0,
        ),
    ]

    result = evaluate_trades(trades)

    assert result["commission_evidence_status"] == "BOUNDED_AMBIGUOUS_FAIL_CLOSED"
    assert result["ambiguous_trade_count"] == 1
    ambiguous = result["round_trips"][1]
    assert ambiguous["ambiguity_reason"] == "ZERO_SIGNED_MOVE"
    assert ambiguous["k_source"] == "SAME_SYMBOL_OBSERVED_MIN_MEDIAN_MAX_BOUND"
    assert ambiguous["commission_at_official_0p005pct_rate"]["central_unrounded"] > 0.0
    assert result["conservative_cost_adjusted"] is not None


def test_ambiguous_trade_without_symbol_bound_is_unavailable() -> None:
    trade = RoundTrip(
        entry_time="2024.01.01 00:00:00",
        exit_time="2024.01.02 00:00:00",
        entry_deal="1",
        exit_deal="2",
        symbol="ONLY.DWX",
        side="buy",
        volume=1.0,
        entry_price=10.0,
        exit_price=10.0,
        gross_pnl=0.0,
        gross_pnl_rounding_half_width=0.005,
        recorded_swap=0.0,
        native_commission=0.0,
    )

    result = evaluate_trades([trade])

    assert result["commission_evidence_status"] == "UNBOUNDED_AMBIGUOUS_FAIL_CLOSED"
    assert result["central_cost_adjusted"] is None
    assert result["conservative_cost_adjusted"] is None
    assert result["round_trips"][0]["commission_at_official_0p005pct_rate"] is None


def test_evaluate_input_binds_receipt_report_and_q08(tmp_path: Path) -> None:
    receipt, report, q08 = _fixture_inputs(tmp_path)

    result = evaluate_input(receipt, report, q08)

    assert result["sleeve"]["key"] == "99999:EURUSD.DWX"
    assert result["scope"]["spread"]["status"] == (
        "HISTORICAL_TESTER_SPREAD_EMBEDDED_NOT_BROKER_PARITY_CERTIFIED"
    )
    assert result["scope"]["spread"]["current_broker_spread_parity"] == "NOT_CERTIFIED"
    assert result["q08_notional_cross_check"]["status"] == "DIAGNOSTIC_ONLY"
    assert result["q08_notional_cross_check"]["valid_rows"] == 2
    assert result["report_reconciliation"]["status"] == "PASS"
    assert result["scope"]["deployment_eligible"] is False


def test_evaluate_input_rejects_report_hash_mismatch(tmp_path: Path) -> None:
    receipt, report, q08 = _fixture_inputs(tmp_path)
    report.write_text(_report() + "<!-- changed -->", encoding="utf-16")

    with pytest.raises(CostEvidenceError, match="report hash"):
        evaluate_input(receipt, report, q08)


def test_formula_validation_uses_exit_notional_and_cent_bounds(tmp_path: Path) -> None:
    report = tmp_path / "q07_report.htm"
    report.write_text(_report(second_trade=False, native_commission=-5.51), encoding="utf-16")
    summary = tmp_path / "summary.json"
    summary.write_text("{}", encoding="utf-8")

    result = validate_formula(
        summary,
        report,
        expected_native_commission=5.51,
        expected_derived_commission=5.505,
        native_tolerance=0.001,
        derived_tolerance=0.001,
    )

    assert result["status"] == "PASS"
    assert result["observed_native_commission"] == 5.51
    assert result["observed_derived_unrounded_commission"] == pytest.approx(5.505)
    assert result["derived_lower_bound"] <= 5.51 <= result["derived_conservative_upper"]


def test_build_report_requires_exact_explicit_count() -> None:
    with pytest.raises(CostEvidenceError, match="explicit input count"):
        build_report(
            [],
            expected_input_count=1,
            as_of_utc="2026-07-16T12:00:00Z",
            selection_note="fixture",
            exclusions=[],
            validation_input=None,
        )


def test_build_report_never_equates_real_ticks_with_broker_spread_certification(
    tmp_path: Path,
) -> None:
    receipt, report, q08 = _fixture_inputs(tmp_path)

    result = build_report(
        [(receipt, report, q08)],
        expected_input_count=1,
        as_of_utc="2026-07-16T12:00:00Z",
        selection_note="fixture",
        exclusions=[],
        validation_input=None,
    )

    assert result["schema_version"] == 3
    assert result["policy"]["round_trip_notional_rate"] == 0.00005
    assert result["policy"]["round_trip_notional_percent"] == 0.005
    assert result["policy"]["round_trip_notional_basis_points"] == 0.5
    assert "official_dxz_5bp_cost" not in result["sleeves"][0]
    assert "commission_5bp" not in result["sleeves"][0]["round_trips"][0]
    assert result["summary"][
        "reports_with_100_percent_real_ticks_spread_embedded"
    ] == 1
    assert result["summary"]["current_broker_spread_parity_certified"] == 0
    assert "spread_certified_100_percent_real_ticks" not in result["summary"]


def test_immutable_writer_creates_hash_sidecar_and_refuses_overwrite(tmp_path: Path) -> None:
    output = tmp_path / "report.json"
    expected_payload = b'{\n  "deployment_eligible": false\n}\n'

    actual_hash = write_immutable_report({"deployment_eligible": False}, output)

    assert output.read_bytes() == expected_payload
    assert actual_hash == hashlib.sha256(expected_payload).hexdigest()
    assert output.with_name("report.json.sha256").read_text(encoding="ascii").startswith(
        actual_hash
    )
    with pytest.raises(CostEvidenceError, match="refusing overwrite"):
        write_immutable_report({"deployment_eligible": False}, output)
    # Leave retained pytest temp data cleanly mutable on Windows.
    os.chmod(output, 0o666)
    os.chmod(output.with_name("report.json.sha256"), 0o666)
