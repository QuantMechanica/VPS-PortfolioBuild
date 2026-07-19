from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_darwinia_book_proxy as subject


def _cost_report(tmp_path: Path) -> tuple[Path, str]:
    sleeves = []
    rows = {
        "1:AAA.DWX": [
            ("2024.01.05 12:00:00", 100.0),
            ("2024.02.05 12:00:00", -50.0),
            ("2024.06.05 12:00:00", 25.0),
            ("2024.07.05 12:00:00", 10.0),
        ],
        "2:BBB.DWX": [
            ("2024.01.06 12:00:00", -20.0),
            ("2024.03.06 12:00:00", 40.0),
            ("2024.07.06 12:00:00", -5.0),
        ],
    }
    for key, trades in rows.items():
        ea_id, symbol = key.split(":", 1)
        sleeves.append(
            {
                "sleeve": {"key": key, "ea_id": int(ea_id), "symbol": symbol},
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
    path = tmp_path / "cost.json"
    path.write_text(
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
    return path, hashlib.sha256(path.read_bytes()).hexdigest()


def _build(tmp_path: Path) -> dict:
    cost, digest = _cost_report(tmp_path)
    implementation = tmp_path / "implementation.py"
    implementation.write_text("# frozen\n", encoding="utf-8")
    return subject.build_report(
        cost,
        expected_cost_report_sha256=digest,
        expected_sleeve_count=2,
        cohorts=[("all", ("1:AAA.DWX", "2:BBB.DWX"))],
        cohort_notes={"all": "predeclared synthetic cohort"},
        from_date="2024-01-01",
        to_date="2024-07-31",
        starting_equity=100000.0,
        as_of_utc="2026-07-16T10:00:00Z",
        implementation_path=implementation,
    )


def test_book_math_and_rolling_six_months(tmp_path: Path) -> None:
    report = _build(tmp_path)
    cohort = report["cohorts"]["all"]
    assert cohort["summary"]["closed_trades"] == 7
    assert cohort["summary"]["net"] == 100.0
    assert cohort["summary"]["exit_event_max_drawdown"] == 70.0
    assert cohort["summary"]["daily_netted_close_pnl_max_drawdown"] == 70.0
    assert cohort["summary"]["rolling_six_month_windows"] == 2
    assert cohort["rolling_six_month"][0]["net"] == 95.0
    assert cohort["rolling_six_month"][1]["net"] == 20.0
    assert report["deployment_eligible"] is False
    assert report["darwinia_policy_snapshot"]["risk_engine"]["simulated_here"] is False


def test_exit_event_drawdown_and_entry_activity_are_not_daily_close_proxies() -> None:
    indexed = {
        "1:AAA.DWX": {
            "round_trips": [
                {
                    "entry_time_mt5_server": "2024.01.31 10:00:00",
                    "exit_time_mt5_server": "2024.02.01 10:00:00",
                    "conservative_cost_adjusted_pnl": 100.0,
                },
                {
                    "entry_time_mt5_server": "2024.01.31 11:00:00",
                    "exit_time_mt5_server": "2024.02.01 11:00:00",
                    "conservative_cost_adjusted_pnl": -80.0,
                },
            ]
        }
    }
    cohort = subject.evaluate_cohort(
        indexed,
        ("1:AAA.DWX",),
        start=subject.dt.date(2024, 1, 1),
        end=subject.dt.date(2024, 3, 31),
        starting_equity=100000.0,
        note="synthetic",
    )
    assert cohort["summary"]["exit_event_max_drawdown"] == 80.0
    assert cohort["summary"]["daily_netted_close_pnl_max_drawdown"] == 0.0
    assert cohort["monthly"][0]["opened_completed_round_trips"] == 2
    assert cohort["monthly"][0]["closed_trades"] == 0
    assert cohort["monthly"][0]["silver_entry_activity_proxy"] is True
    assert cohort["monthly"][1]["opened_completed_round_trips"] == 0
    assert cohort["monthly"][1]["closed_trades"] == 2
    assert cohort["monthly"][1]["silver_entry_activity_proxy"] is True
    assert cohort["monthly"][2]["silver_entry_activity_proxy"] is False


def test_sha_binding_fails_closed(tmp_path: Path) -> None:
    cost, _digest = _cost_report(tmp_path)
    implementation = tmp_path / "implementation.py"
    implementation.write_text("# frozen\n", encoding="utf-8")
    with pytest.raises(subject.DarwiniaProxyError, match="SHA mismatch"):
        subject.build_report(
            cost,
            expected_cost_report_sha256="0" * 64,
            expected_sleeve_count=2,
            cohorts=[("all", ("1:AAA.DWX",))],
            cohort_notes={"all": "explicit"},
            from_date="2024-01-01",
            to_date="2024-07-31",
            starting_equity=100000.0,
            as_of_utc="2026-07-16T10:00:00Z",
            implementation_path=implementation,
        )


def test_superseded_cost_schema_is_rejected_even_when_hash_bound(tmp_path: Path) -> None:
    cost, _digest = _cost_report(tmp_path)
    payload = json.loads(cost.read_text(encoding="utf-8"))
    payload["schema_version"] = 1
    cost.write_text(json.dumps(payload), encoding="utf-8")
    digest = hashlib.sha256(cost.read_bytes()).hexdigest()
    implementation = tmp_path / "implementation.py"
    implementation.write_text("# frozen\n", encoding="utf-8")

    with pytest.raises(subject.DarwiniaProxyError, match="schema_version=3"):
        subject.build_report(
            cost,
            expected_cost_report_sha256=digest,
            expected_sleeve_count=2,
            cohorts=[("all", ("1:AAA.DWX",))],
            cohort_notes={"all": "explicit"},
            from_date="2024-01-01",
            to_date="2024-07-31",
            starting_equity=100000.0,
            as_of_utc="2026-07-16T10:00:00Z",
            implementation_path=implementation,
        )


def test_mislabelled_rate_unit_contract_is_rejected_even_when_hash_bound(
    tmp_path: Path,
) -> None:
    cost, _digest = _cost_report(tmp_path)
    payload = json.loads(cost.read_text(encoding="utf-8"))
    payload["policy"]["round_trip_notional_basis_points"] = 5.0
    cost.write_text(json.dumps(payload), encoding="utf-8")
    digest = hashlib.sha256(cost.read_bytes()).hexdigest()
    implementation = tmp_path / "implementation.py"
    implementation.write_text("# frozen\n", encoding="utf-8")

    with pytest.raises(subject.DarwiniaProxyError, match="rate-unit contract"):
        subject.build_report(
            cost,
            expected_cost_report_sha256=digest,
            expected_sleeve_count=2,
            cohorts=[("all", ("1:AAA.DWX",))],
            cohort_notes={"all": "explicit"},
            from_date="2024-01-01",
            to_date="2024-07-31",
            starting_equity=100000.0,
            as_of_utc="2026-07-16T10:00:00Z",
            implementation_path=implementation,
        )


def test_unknown_key_and_missing_note_fail_closed(tmp_path: Path) -> None:
    cost, digest = _cost_report(tmp_path)
    implementation = tmp_path / "implementation.py"
    implementation.write_text("# frozen\n", encoding="utf-8")
    with pytest.raises(subject.DarwiniaProxyError, match="exactly one explicit note"):
        subject.build_report(
            cost,
            expected_cost_report_sha256=digest,
            expected_sleeve_count=2,
            cohorts=[("all", ("9:NOPE.DWX",))],
            cohort_notes={},
            from_date="2024-01-01",
            to_date="2024-07-31",
            starting_equity=100000.0,
            as_of_utc="2026-07-16T10:00:00Z",
            implementation_path=implementation,
        )
    with pytest.raises(subject.DarwiniaProxyError, match="unknown keys"):
        subject.build_report(
            cost,
            expected_cost_report_sha256=digest,
            expected_sleeve_count=2,
            cohorts=[("all", ("9:NOPE.DWX",))],
            cohort_notes={"all": "explicit"},
            from_date="2024-01-01",
            to_date="2024-07-31",
            starting_equity=100000.0,
            as_of_utc="2026-07-16T10:00:00Z",
            implementation_path=implementation,
        )


def test_period_and_enum_like_cohort_parser_contract() -> None:
    assert subject.parse_cohort("edge=1:AAA.DWX,2:BBB.DWX") == (
        "edge",
        ("1:AAA.DWX", "2:BBB.DWX"),
    )
    with pytest.raises(subject.DarwiniaProxyError, match="duplicate"):
        subject.parse_cohort("edge=1:AAA.DWX,1:AAA.DWX")


def test_immutable_writer_refuses_overwrite(tmp_path: Path) -> None:
    output = tmp_path / "report.json"
    digest = subject.write_immutable_report({"deployment_eligible": False}, output)
    assert digest == hashlib.sha256(output.read_bytes()).hexdigest()
    assert output.with_name("report.json.sha256").is_file()
    with pytest.raises(subject.DarwiniaProxyError, match="refusing overwrite"):
        subject.write_immutable_report({"deployment_eligible": False}, output)
