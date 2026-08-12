from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pandas as pd
import pytest

from tools.strategy_farm.portfolio import ftmo_bar_joint_book_sim as joint
from tools.strategy_farm.portfolio import ftmo_trend20d_mt5_parity as parity
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip


SYMBOL = "WS30.DWX"
TIMESTAMP_BASIS = "darwinex_broker_wall"


def _trade(
    entry: dt.datetime,
    *,
    profit: float = 1.0,
    side: str = "buy",
) -> RoundTrip:
    return RoundTrip(
        entry_time=entry,
        exit_time=entry + dt.timedelta(hours=2, minutes=30),
        symbol=SYMBOL,
        side=side,
        volume=1.0,
        entry_price=100.0,
        exit_price=101.0,
        profit=profit,
        native_swap=0.0,
        native_commission=0.0,
    )


def _parity_case() -> tuple[list[RoundTrip], list[RoundTrip], pd.DataFrame]:
    first_source = dt.datetime(2024, 1, 5, 20, 30, 2)
    second_source = first_source + dt.timedelta(days=7)
    first_bucket = joint.normalize_timestamp(first_source, TIMESTAMP_BASIS).floor("15min")
    second_bucket = joint.normalize_timestamp(second_source, TIMESTAMP_BASIS).floor("15min")
    index = pd.date_range(
        end=second_bucket,
        periods=1922 + 7 * 24 * 4,
        freq="15min",
        tz="UTC",
    )
    closes = [100.0] * len(index)
    first_position = int(index.searchsorted(first_bucket, side="left"))
    second_position = int(index.searchsorted(second_bucket, side="left"))
    assert first_position == 1921
    closes[first_position - 1] = 110.0
    closes[second_position - 1] = 90.0
    bars = pd.DataFrame(
        {
            "open": closes,
            "high": [value + 1.0 for value in closes],
            "low": [value - 1.0 for value in closes],
            "close": closes,
        },
        index=index,
    )
    baseline = [_trade(first_source), _trade(second_source)]
    target = [_trade(first_source + dt.timedelta(seconds=51))]
    return baseline, target, bars


def test_native_entry_parity_ignores_first_tick_seconds_within_m15_bucket() -> None:
    baseline, target, bars = _parity_case()

    result = parity.compare_entry_parity(
        baseline,
        target,
        bars,
        timestamp_basis=TIMESTAMP_BASIS,
        expected_symbol=SYMBOL,
    )

    assert result["status"] == "PASS"
    assert result["counts"] == {
        "baseline": 2,
        "expected_accepted": 1,
        "expected_rejected": 1,
        "expected_unavailable": 0,
        "target": 1,
    }
    assert result["checks"]["target_is_exact_baseline_subset"] is True
    assert result["checks"]["expected_entries_equal_target_entries"] is True
    assert result["baseline_oracle"][0]["entry_match"]["key"] == result[
        "target_entries"
    ][0]["entry_match"]["key"]


def test_selection_result_is_invariant_to_report_pnl() -> None:
    baseline, target, bars = _parity_case()
    changed_baseline = [
        _trade(trade.entry_time, profit=999999.0 if number == 0 else -999999.0)
        for number, trade in enumerate(baseline)
    ]
    changed_target = [_trade(target[0].entry_time, profit=-123456.0)]

    original = parity.compare_entry_parity(
        baseline,
        target,
        bars,
        timestamp_basis=TIMESTAMP_BASIS,
        expected_symbol=SYMBOL,
    )
    changed = parity.compare_entry_parity(
        changed_baseline,
        changed_target,
        bars,
        timestamp_basis=TIMESTAMP_BASIS,
        expected_symbol=SYMBOL,
    )

    assert changed == original
    assert changed["checks"]["pnl_used_for_selection"] is False


def test_rejected_baseline_entry_in_target_fails_exact_expected_set() -> None:
    baseline, _target, bars = _parity_case()
    wrong_target = [_trade(baseline[1].entry_time + dt.timedelta(seconds=30))]

    result = parity.compare_entry_parity(
        baseline,
        wrong_target,
        bars,
        timestamp_basis=TIMESTAMP_BASIS,
        expected_symbol=SYMBOL,
    )

    assert result["status"] == "FAIL"
    assert "expected_entry_missing_from_target" in result["reasons"]
    assert "unexpected_entry_present_in_target" in result["reasons"]
    assert result["checks"]["target_is_exact_baseline_subset"] is True


def test_tester_log_scan_is_scoped_to_last_exact_test_block(tmp_path: Path) -> None:
    log = tmp_path / "tester.log"
    stale = (
        "Core WS30.DWX,M15: testing of Experts\\QM\\QM5_13202_other.ex5 started\n"
        "not enough money\n"
        "Test passed\nconnection closed\n"
    )
    current = (
        "Core WS30.DWX,M15: testing of "
        "Experts\\QM\\QM5_13202_ws30-fri-pm-long.ex5 started with inputs:\n"
        "ordinary current-run line\nTest passed\nconnection closed\n"
    )
    log.write_text(stale + current, encoding="utf-8")

    clean = parity.scan_tester_log(
        log,
        expected_expert=r"QM\QM5_13202_ws30-fri-pm-long",
        expected_symbol=SYMBOL,
        expected_period="M15",
    )
    assert clean["no_money_detected"] is False
    assert clean["scope_contract"].startswith("last_exact")

    log.write_text(
        stale + current.replace("ordinary current-run line", "retcode=10019 NO_MONEY"),
        encoding="utf-8",
    )
    contaminated = parity.scan_tester_log(
        log,
        expected_expert=r"QM\QM5_13202_ws30-fri-pm-long",
        expected_symbol=SYMBOL,
        expected_period="M15",
    )
    assert contaminated["no_money_detected"] is True


def test_summary_report_count_mismatch_fails_closed(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    report = tmp_path / "report.htm"
    report.write_text("fixture", encoding="ascii")
    log = tmp_path / "tester.log"
    log.write_text(
        "Core WS30.DWX,M15: testing of "
        "Experts\\QM\\QM5_13202_ws30-fri-pm-long.ex5 started with inputs:\n"
        "Test passed\nconnection closed\n",
        encoding="utf-8",
    )
    summary = tmp_path / "summary.json"
    summary.write_text(
        json.dumps(
            {
                "result": "PASS",
                "ea_id": 13202,
                "expert": r"QM\QM5_13202_ws30-fri-pm-long",
                "symbol": SYMBOL,
                "period": "M15",
                "deterministic": True,
                "runs": [
                    {
                        "status": "OK",
                        "exit_code": 0,
                        "total_trades": 2,
                        "report_canonical_path": str(report),
                        "tester_log_path": str(log),
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    friday = dt.datetime(2024, 1, 5, 13, 30)
    monkeypatch.setattr(
        parity,
        "extract_round_trips",
        lambda _path, _symbol: ([_trade(friday)], {"total_trades": 1}),
    )

    with pytest.raises(ValueError, match="baseline count mismatch"):
        parity.load_report_evidence(
            summary,
            report,
            expected_symbol=SYMBOL,
            timestamp_basis="unix_utc",
            role="baseline",
        )


def test_risk10_set_and_binary_are_bound_to_summary_ea(tmp_path: Path) -> None:
    setfile = tmp_path / "risk10.set"
    setfile.write_text("qm_ea_id=13207\nRISK_FIXED=10\n", encoding="ascii")
    binary = tmp_path / "QM5_13207_ws30-fri-t20a.ex5"
    binary.write_bytes(b"native-binary-fixture")

    assert parity.validate_set_binding(
        setfile,
        expected_ea_id=13207,
        expected_risk_fixed=10.0,
    ) == {"ea_id": 13207, "risk_fixed": 10.0}
    parity.validate_binary_binding(binary, expected_ea_id=13207)

    with pytest.raises(ValueError, match="RISK_FIXED"):
        parity.validate_set_binding(
            setfile,
            expected_ea_id=13207,
            expected_risk_fixed=100.0,
        )
