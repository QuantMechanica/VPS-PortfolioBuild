from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_darwinia_walkforward_proxy as subject


def _fixture(tmp_path: Path) -> tuple[Path, str, Path, Path]:
    sleeves = []
    data = {
        "1:A.DWX": [
            ("2020.01.01 00:00:00", 20.0),
            ("2020.02.01 00:00:00", -10.0),
            ("2021.01.01 00:00:00", 30.0),
            ("2021.02.01 00:00:00", -10.0),
        ],
        "2:B.DWX": [
            ("2020.01.02 00:00:00", -20.0),
            ("2020.02.02 00:00:00", 5.0),
            ("2021.01.02 00:00:00", 1000.0),
        ],
    }
    for key, trades in data.items():
        ea, symbol = key.split(":")
        sleeves.append(
            {
                "sleeve": {"key": key, "ea_id": int(ea), "symbol": symbol},
                "unbounded_trade_count": 0,
                "round_trips": [
                    {
                        "entry_time_mt5_server": timestamp,
                        "exit_time_mt5_server": timestamp,
                        "conservative_cost_adjusted_pnl": pnl,
                    }
                    for timestamp, pnl in trades
                ],
            }
        )
    cost = tmp_path / "cost.json"
    cost.write_text(
        json.dumps(
            {
                "schema_version": 3,
                "artifact_type": "DXZ_STANDALONE_COST_EVIDENCE",
                "deployment_eligible": False,
                "policy": {
                    "round_trip_notional_rate": 0.00005,
                    "round_trip_notional_percent": 0.005,
                    "round_trip_notional_basis_points": 0.5,
                },
                "summary": {
                    "reports_with_100_percent_real_ticks_spread_embedded": 2,
                    "current_broker_spread_parity_certified": 0,
                },
                "sleeves": sleeves,
            }
        ),
        encoding="utf-8",
    )
    implementation = tmp_path / "walk.py"
    dependency = tmp_path / "book.py"
    implementation.write_text("# walk\n", encoding="utf-8")
    dependency.write_text("# book\n", encoding="utf-8")
    return cost, hashlib.sha256(cost.read_bytes()).hexdigest(), implementation, dependency


def test_training_selection_cannot_see_later_winner(tmp_path: Path) -> None:
    cost, digest, implementation, dependency = _fixture(tmp_path)
    report = subject.build_report(
        cost,
        expected_cost_report_sha256=digest,
        expected_sleeve_count=2,
        universe=("1:A.DWX", "2:B.DWX"),
        train_from="2020-01-01",
        train_to="2020-12-31",
        evaluate_from="2021-01-01",
        evaluate_to="2021-12-31",
        minimum_training_trades=2,
        minimum_training_pf=1.1,
        starting_equity=100000.0,
        as_of_utc="2026-07-16T10:00:00Z",
        implementation_path=implementation,
        dependency_path=dependency,
    )
    assert report["selection_contract"]["selected_keys"] == ["1:A.DWX"]
    assert report["selected_cohort_evaluation"]["summary"]["net"] == 20.0
    assert report["full_universe_evaluation"]["summary"]["net"] == 1020.0
    assert report["deployment_eligible"] is False


def test_overlapping_windows_fail_closed(tmp_path: Path) -> None:
    cost, digest, implementation, dependency = _fixture(tmp_path)
    with pytest.raises(subject.WalkForwardError, match="strictly after"):
        subject.build_report(
            cost,
            expected_cost_report_sha256=digest,
            expected_sleeve_count=2,
            universe=("1:A.DWX",),
            train_from="2020-01-01",
            train_to="2020-12-31",
            evaluate_from="2020-12-31",
            evaluate_to="2021-12-31",
            minimum_training_trades=2,
            minimum_training_pf=1.1,
            starting_equity=100000.0,
            as_of_utc="2026-07-16T10:00:00Z",
            implementation_path=implementation,
            dependency_path=dependency,
        )


def test_unknown_universe_and_empty_selection_fail_closed(tmp_path: Path) -> None:
    cost, digest, implementation, dependency = _fixture(tmp_path)
    common = dict(
        cost_report_path=cost,
        expected_cost_report_sha256=digest,
        expected_sleeve_count=2,
        train_from="2020-01-01",
        train_to="2020-12-31",
        evaluate_from="2021-01-01",
        evaluate_to="2021-12-31",
        minimum_training_trades=2,
        minimum_training_pf=1.1,
        starting_equity=100000.0,
        as_of_utc="2026-07-16T10:00:00Z",
        implementation_path=implementation,
        dependency_path=dependency,
    )
    with pytest.raises(subject.WalkForwardError, match="unknown keys"):
        subject.build_report(universe=("9:NO.DWX",), **common)
    with pytest.raises(subject.WalkForwardError, match="selected no sleeves"):
        subject.build_report(
            universe=("2:B.DWX",), minimum_training_pf=9.0,
            **{key: value for key, value in common.items() if key != "minimum_training_pf"},
        )


def test_universe_parser_rejects_duplicates() -> None:
    assert subject.parse_universe("1:A.DWX,2:B.DWX") == (
        "1:A.DWX",
        "2:B.DWX",
    )
    with pytest.raises(subject.WalkForwardError, match="unique"):
        subject.parse_universe("1:A.DWX,1:A.DWX")


def test_non_finite_starting_equity_fails_closed(tmp_path: Path) -> None:
    cost, digest, implementation, dependency = _fixture(tmp_path)
    with pytest.raises(subject.WalkForwardError, match="finite and > 0"):
        subject.build_report(
            cost,
            expected_cost_report_sha256=digest,
            expected_sleeve_count=2,
            universe=("1:A.DWX",),
            train_from="2020-01-01",
            train_to="2020-12-31",
            evaluate_from="2021-01-01",
            evaluate_to="2021-12-31",
            minimum_training_trades=2,
            minimum_training_pf=1.1,
            starting_equity=float("nan"),
            as_of_utc="2026-07-16T10:00:00Z",
            implementation_path=implementation,
            dependency_path=dependency,
        )
