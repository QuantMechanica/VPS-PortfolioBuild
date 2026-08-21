"""MNT-038 regression contract for sequential Q02 cohort fanout."""

import json

from tools.strategy_farm import farmctl


def _row(
    symbol: str,
    *,
    status: str = "done",
    verdict: str | None,
    reason: str | None = None,
    updated_at: str = "2026-08-21T10:00:00+00:00",
) -> dict:
    payload = {"verdict_reason": reason} if reason else {}
    return {
        "symbol": symbol,
        "status": status,
        "verdict": verdict,
        "payload_json": json.dumps(payload),
        "updated_at": updated_at,
    }


def test_staging_selects_one_liquid_canary_before_fanout() -> None:
    parsed = [
        ("aud.set", "AUDUSD.DWX", "D1"),
        ("xau.set", "XAUUSD.DWX", "D1"),
        ("eur.set", "EURUSD.DWX", "D1"),
        ("ndx.set", "NDX.DWX", "D1"),
    ]

    canary, deferred = farmctl._stage_q02_setfiles(parsed)

    assert canary == [("eur.set", "EURUSD.DWX", "D1")]
    assert deferred == [parsed[0], parsed[1], parsed[3]]


def test_deterministic_infra_canary_stops_the_cohort() -> None:
    rows = [
        _row(
            "EURUSD.DWX",
            verdict="INFRA_FAIL",
            reason="run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS",
        )
    ]

    decision = farmctl._q02_canary_fanout_decision(rows, ["EURUSD.DWX"])

    assert decision["action"] == "STOP"
    assert decision["reason"] == "deterministic_canary_failure"


def test_failed_build_or_runner_without_verdict_stops_fanout() -> None:
    rows = [_row("EURUSD.DWX", status="failed", verdict=None)]

    decision = farmctl._q02_canary_fanout_decision(rows, ["EURUSD.DWX"])

    assert decision["action"] == "STOP"


def test_first_null_signal_requests_exactly_one_confirmation() -> None:
    rows = [
        _row("EURUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES")
    ]

    decision = farmctl._q02_canary_fanout_decision(rows, ["EURUSD.DWX"])

    assert decision["action"] == "CONFIRM"
    assert decision["reason"] == "first_null_signal_requires_second_host"


def test_two_identical_null_signals_stop_fanout() -> None:
    rows = [
        _row("EURUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
        _row("GBPUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
    ]

    decision = farmctl._q02_canary_fanout_decision(
        rows, ["EURUSD.DWX", "GBPUSD.DWX"]
    )

    assert decision["action"] == "STOP"
    assert decision["reason"] == "identical_null_signal_confirmed"


def test_heterogeneous_strategy_is_not_stopped_early() -> None:
    rows = [
        _row("EURUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
        _row("GBPUSD.DWX", verdict="PASS", reason="OK"),
    ]

    decision = farmctl._q02_canary_fanout_decision(
        rows, ["EURUSD.DWX", "GBPUSD.DWX"]
    )

    assert decision["action"] == "RELEASE"
    assert decision["reason"] == "economic_or_heterogeneous_canary"
