from __future__ import annotations

import datetime as dt
import json
from decimal import Decimal
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from tools.strategy_farm import target_rulepacks
from tools.strategy_farm.portfolio import ftmo_rules_engine as mtm
from tools.strategy_farm.portfolio import ftmo_timebox_eval as timebox
from tools.strategy_farm.portfolio.ftmo_rule_contract import (
    DEFAULT_RULEPACK_PATH,
    load_two_step_contract,
)


ROOT = Path(__file__).resolve().parents[3]
PRAGUE = ZoneInfo("Europe/Prague")


def _timebox_day(number: int, *, net: float, opens: int) -> timebox.DailyPoint:
    return timebox.DailyPoint(
        day=dt.date(2026, 1, 5) + dt.timedelta(days=number),
        net_return=net,
        intraday_low_return=min(0.0, net),
        trade_count=opens,
        eligible_start=True,
        flat_at_end=True,
    )


def _mtm_trace(opening_days: int) -> mtm.NormalizedTrace:
    start = dt.datetime(2026, 1, 4, 23, tzinfo=dt.UTC)
    points: list[mtm.TracePoint] = []
    balance = Decimal("100000.00")
    previous_balance = balance
    for index in range(121):
        stamp = start + dt.timedelta(hours=index)
        local = stamp.astimezone(PRAGUE)
        day_number = (local.date() - dt.date(2026, 1, 5)).days
        is_noon = local.hour == 12
        opens = 1 if is_noon and 0 <= day_number < opening_days else 0
        if day_number == 0 and is_noon:
            balance = Decimal("110100.00")
        points.append(
            mtm.TracePoint(
                ts_utc=stamp,
                balance=balance,
                equity=balance,
                interval_min_equity=min(previous_balance, balance),
                open_positions=0,
                opened_positions=opens,
                day_anchor=local.hour == 0,
            )
        )
        previous_balance = balance
    return mtm.NormalizedTrace(
        trace_id=f"astra-probe-{opening_days}",
        currency="USD",
        source_fingerprint_sha256=(str(opening_days) * 64)[:64],
        money_decimals=2,
        grid_seconds=3_600,
        balance_basis=mtm.BALANCE_BASIS_NET_TRADING,
        equity_basis=mtm.EQUITY_BASIS_MTM,
        opened_positions_basis=mtm.OPENED_POSITIONS_BASIS,
        interval_min_equity_basis=mtm.INTERVAL_MIN_EQUITY_BASIS,
        points=tuple(points),
    )


def test_validated_rulepack_is_the_shared_two_step_source() -> None:
    contract = load_two_step_contract()
    assert contract.canonical_sha256 == target_rulepacks.load_rulepack_path(
        DEFAULT_RULEPACK_PATH
    ).canonical_sha256
    assert timebox.DEFAULT_RULES["minimum_trading_days"] == 4
    assert timebox.DEFAULT_RULES["timezone"] == "Europe/Prague"
    assert timebox.DEFAULT_RULES["target_operator"] == "STRICTLY_GREATER_THAN_TARGET"
    assert timebox.DEFAULT_RULES["live_equity_compounding_allowed"] is False
    assert mtm.TWO_STEP_PHASE1.profit_target_fraction == contract.phase1_target_fraction
    assert mtm.TWO_STEP_VERIFICATION.profit_target_fraction == contract.phase2_target_fraction
    assert mtm.TWO_STEP_PHASE1.minimum_trading_days == contract.minimum_trading_days


def test_astra_one_day_probe_is_rejected_by_both_engines() -> None:
    fixture = json.loads(
        (ROOT / "docs/ops/evidence/2026-09-04_astra_ftmo_contracts.json").read_text(
            encoding="utf-8"
        )
    )
    assert fixture["four_day_reproducer"]["actual"]["outcome"] == "PASS"

    legacy_shape = [_timebox_day(0, net=0.101, opens=1)]
    assert timebox.evaluate_phase(legacy_shape, 0, 0.10, 60)["outcome"] == "TIMEOUT"
    result = mtm.evaluate_trace(
        _mtm_trace(1),
        rules=mtm.TWO_STEP_PHASE1,
        initial_balance="100000.00",
        assumptions=mtm.EvaluationAssumptions(maximum_grid_seconds=3_600),
    )
    assert result["status"] == "NOT_PASSED"
    assert "MINIMUM_TRADING_DAYS" in result["missing_objectives"]


def test_four_opening_days_and_strict_target_agree_cross_engine() -> None:
    days = [_timebox_day(0, net=0.101, opens=1)] + [
        _timebox_day(index, net=0.0, opens=1) for index in range(1, 4)
    ]
    assert timebox.evaluate_phase(days, 0, 0.10, 60)["outcome"] == "PASS"
    result = mtm.evaluate_trace(
        _mtm_trace(4),
        rules=mtm.TWO_STEP_PHASE1,
        initial_balance="100000.00",
        assumptions=mtm.EvaluationAssumptions(maximum_grid_seconds=3_600),
    )
    assert result["status"] == "SCREEN_PASS"
    assert result["trading_days"] == 4

    exact = [_timebox_day(index, net=0.025, opens=1) for index in range(4)]
    assert timebox.evaluate_phase(exact, 0, 0.10, 60)["outcome"] == "TIMEOUT"


def test_prague_calendar_boundary_counts_distinct_opening_days() -> None:
    # 22:00Z and 00:00Z are opposite sides of Prague midnight in January;
    # the intervening 23:00Z point is the mandatory local-day anchor.
    start = dt.datetime(2026, 1, 4, 23, 0, tzinfo=dt.UTC)
    stamps = tuple(start + dt.timedelta(hours=index) for index in range(49))
    points = tuple(
        mtm.TracePoint(
            ts_utc=stamp,
            balance=Decimal("100000.00"),
            equity=Decimal("100000.00"),
            interval_min_equity=Decimal("100000.00"),
            open_positions=0,
            opened_positions=1 if stamp in {
                dt.datetime(2026, 1, 5, 22, 0, tzinfo=dt.UTC),
                dt.datetime(2026, 1, 6, 0, 0, tzinfo=dt.UTC),
            } else 0,
            day_anchor=stamp.astimezone(PRAGUE).hour == 0,
        )
        for stamp in stamps
    )
    trace = mtm.NormalizedTrace(
        trace_id="prague-boundary",
        currency="USD",
        source_fingerprint_sha256="a" * 64,
        money_decimals=2,
        grid_seconds=3_600,
        balance_basis=mtm.BALANCE_BASIS_NET_TRADING,
        equity_basis=mtm.EQUITY_BASIS_MTM,
        opened_positions_basis=mtm.OPENED_POSITIONS_BASIS,
        interval_min_equity_basis=mtm.INTERVAL_MIN_EQUITY_BASIS,
        points=points,
    )
    result = mtm.evaluate_trace(
        trace,
        rules=mtm.TWO_STEP_PHASE1,
        initial_balance="100000.00",
        assumptions=mtm.EvaluationAssumptions(maximum_grid_seconds=3_600),
    )
    assert result["trading_days"] == 2


def test_stage_two_resets_and_fixed_initial_returns_do_not_compound() -> None:
    days = [_timebox_day(0, net=0.101, opens=1)] + [
        _timebox_day(index, net=0.0, opens=1) for index in range(1, 4)
    ]
    days += [_timebox_day(4, net=0.051, opens=1)] + [
        _timebox_day(index, net=0.0, opens=1) for index in range(5, 8)
    ]
    outcome = timebox.rolling_outcomes(days)[0]
    assert outcome["p1"]["end_index"] == 3
    assert outcome["p2"]["end_index"] == 7
    assert outcome["joint_pass"] is True

    exact_additive = [_timebox_day(index, net=0.025, opens=1) for index in range(4)]
    assert timebox.evaluate_phase(exact_additive, 0, 0.10, 60)["outcome"] == "TIMEOUT"


def test_rulepack_schema_and_target_invariants_fail_closed(tmp_path: Path) -> None:
    payload = target_rulepacks.load_rulepack_path(DEFAULT_RULEPACK_PATH).as_dict()
    rule = next(
        row for row in payload["official_rules"]
        if row["rule_id"] == "ftmo_2s_minimum_trading_days"
    )
    rule["parameters"]["days"] = 1
    tampered = tmp_path / "tampered.json"
    tampered.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(target_rulepacks.RulepackValidationError, match="must equal 4"):
        load_two_step_contract(tampered)
