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


# --- DEFECT 1: cohort-aware identical-null confirmation -------------------------


def test_mixed_cohort_null_promotes_unprobed_asset_class_before_stop() -> None:
    """Two identical FX nulls must not kill a cohort that still holds gold."""
    rows = [
        _row("EURUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
        _row("USDJPY.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
    ]

    decision = farmctl._q02_canary_fanout_decision(
        rows,
        ["EURUSD.DWX", "USDJPY.DWX"],
        ["EURUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX"],
    )

    assert decision["action"] == "CONFIRM"
    assert decision["reason"] == "identical_null_requires_cross_asset_confirmation"
    assert "commodities" in decision["promote_asset_classes"]


def test_homogeneous_fx_cohort_null_may_stop() -> None:
    """An all-FX cohort with identical bare nulls is still stopped."""
    rows = [
        _row("EURUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
        _row("USDJPY.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
    ]

    decision = farmctl._q02_canary_fanout_decision(
        rows,
        ["EURUSD.DWX", "USDJPY.DWX"],
        ["EURUSD.DWX", "USDJPY.DWX", "GBPUSD.DWX"],
    )

    assert decision["action"] == "STOP"
    assert decision["reason"] == "identical_null_signal_confirmed"


def test_cross_asset_confirmed_null_finally_stops() -> None:
    """Once every asset class produced the identical bare null, the cohort stops."""
    rows = [
        _row("EURUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
        _row("USDJPY.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
        _row("XAUUSD.DWX", verdict="ZERO_TRADES", reason="Q02_ZERO_TRADES"),
    ]

    decision = farmctl._q02_canary_fanout_decision(
        rows,
        ["EURUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX"],
        ["EURUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX"],
    )

    assert decision["action"] == "STOP"
    assert decision["reason"] == "identical_null_signal_confirmed"


# --- DEFECT 2: transient-infra confirmation + STOPPED revival -------------------


def test_transient_infra_canary_waits_before_confirmation() -> None:
    rows = [
        _row(
            "EURUSD.DWX",
            verdict="INFRA_FAIL",
            reason="run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS",
        )
    ]

    decision = farmctl._q02_canary_fanout_decision(rows, ["EURUSD.DWX"])

    assert decision["action"] == "WAIT"
    assert decision["reason"] == "transient_infra_awaiting_confirmation"
    assert decision["infra_attempts"] == 1


def test_transient_infra_canary_stops_after_three_attempts() -> None:
    rows = [
        _row(
            "EURUSD.DWX",
            verdict="INFRA_FAIL",
            reason="NO_HISTORY;INCOMPLETE_RUNS",
            updated_at=f"2026-08-21T0{n}:00:00+00:00",
        )
        for n in (1, 2, 3)
    ]

    decision = farmctl._q02_canary_fanout_decision(rows, ["EURUSD.DWX"])

    assert decision["action"] == "STOP"
    assert decision["reason"] == "confirmed_infra_canary_failure"
    assert decision["infra_attempts"] == 3


def test_hard_defect_canary_stops_on_first_sight() -> None:
    rows = [_row("EURUSD.DWX", verdict="INVALID", reason="INVALID_EVIDENCE")]

    decision = farmctl._q02_canary_fanout_decision(rows, ["EURUSD.DWX"])

    assert decision["action"] == "STOP"
    assert decision["reason"] == "deterministic_canary_failure"


def test_stopped_cohort_revives_on_later_economic_verdict() -> None:
    stopped_at = "2026-08-21T05:00:00+00:00"
    rows = [
        _row(
            "EURUSD.DWX",
            verdict="INFRA_FAIL",
            reason="NO_HISTORY",
            updated_at="2026-08-21T04:00:00+00:00",
        ),
        _row(
            "EURUSD.DWX",
            verdict="PASS",
            reason="OK",
            updated_at="2026-08-21T06:00:00+00:00",
        ),
    ]

    revival = farmctl._q02_canary_revival(rows, stopped_at)

    assert revival is not None
    assert revival["symbol"] == "EURUSD.DWX"
    assert revival["verdict"] == "PASS"


def test_stopped_cohort_not_revived_without_newer_economic_row() -> None:
    stopped_at = "2026-08-21T05:00:00+00:00"
    rows = [
        _row(
            "EURUSD.DWX",
            verdict="PASS",
            reason="OK",
            updated_at="2026-08-21T04:00:00+00:00",
        ),
        _row(
            "EURUSD.DWX",
            verdict="INFRA_FAIL",
            reason="NO_HISTORY",
            updated_at="2026-08-21T06:00:00+00:00",
        ),
    ]

    assert farmctl._q02_canary_revival(rows, stopped_at) is None
