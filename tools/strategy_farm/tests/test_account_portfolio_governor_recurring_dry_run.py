from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

from tools.strategy_farm import account_portfolio_governor as governor
from tools.strategy_farm import account_portfolio_governor_recurring_dry_run as recurring


LOGIN = 4000090541
T0 = dt.datetime(2026, 8, 23, 8, 0, tzinfo=dt.UTC)


def _position(
    ticket: int,
    magic: int,
    symbol: str,
    side: str,
    notional: float,
    stop_loss: float,
    base: str,
    profit: str = "USD",
) -> dict:
    return {
        "ticket": ticket,
        "identifier": ticket + 1000,
        "magic": magic,
        "symbol": symbol,
        "type": side,
        "volume": 1.0,
        "price_open": 100.0,
        "price_current": 101.0,
        "sl": 95.0,
        "tp": 110.0,
        "profit": 100.0,
        "swap": 0.0,
        "base_currency": base,
        "profit_currency": profit,
        "notional_account_ok": True,
        "signed_notional_account": notional,
        "stop_loss_account_ok": True,
        "remaining_loss_to_sl_account": stop_loss,
    }


def _snapshot(at: dt.datetime, *, gross_notional: float) -> dict:
    positions = [
        _position(301, 111320000, "EURUSD", "BUY", gross_notional, 1_000.0, "EUR"),
        _position(302, 0, "XAUUSD", "SELL", -1_000.0, 500.0, "XAU"),
    ]
    orders = [{"ticket": 401, "magic": 111320000, "symbol": "EURUSD", "type": "BUY_LIMIT"}]
    net = gross_notional - 1_000.0
    return {
        "schema": governor.SNAPSHOT_SCHEMA,
        "monitor_version": "1.10",
        "account_login": LOGIN,
        "currency": "USD",
        "time_utc": at.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "equity": 100_000.0,
        "balance": 100_000.0,
        "margin": 5_000.0,
        "free_margin": 95_000.0,
        "open_positions": len(positions),
        "pending_orders": len(orders),
        "reconciled_positions": len(positions),
        "reconciled_orders": len(orders),
        "reconciliation_complete": True,
        "gross_notional_account": gross_notional + 1_000.0,
        "net_directional_notional_account": net,
        "planned_stop_loss_account": 1_500.0,
        "unpriced_positions": 0,
        "positions_without_stop": 0,
        "write_ok": True,
        "positions": positions,
        "orders": orders,
    }


def _write_policy(path: Path, *, gross_ceiling: float, now: dt.datetime) -> governor.BoundPolicy:
    payload = {
        "schema": governor.POLICY_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-08-23T00:00:00Z",
        "valid_until_utc": "2026-08-24T00:00:00Z",
        "stage2_cancel_pending_authorized": True,
        "thresholds": {
            "min_free_margin_account": 1_000.0,
            "max_gross_leverage": gross_ceiling,
            "max_abs_currency_net_leverage": 2.0,
            "max_planned_stop_loss_account": 5_000.0,
        },
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return governor._load_bound_policy(
        path, digest, schema=governor.POLICY_SCHEMA, now_utc=now, expected_login=LOGIN,
        label="policy",
    )


def _write_emergency(path: Path, trigger_sha256: str, now: dt.datetime) -> governor.BoundPolicy:
    payload = {
        "schema": governor.EMERGENCY_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-08-23T00:00:00Z",
        "valid_until_utc": "2026-08-23T23:59:59Z",
        "incident_id": "TEST-RECURRING-1",
        "flatten_authorized": True,
        "trigger_policy_sha256": trigger_sha256,
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return governor._load_bound_policy(
        path, digest, schema=governor.EMERGENCY_SCHEMA, now_utc=now, expected_login=LOGIN,
        label="emergency_policy",
    )


def test_full_lifecycle_clear_freeze_flatten_recovery_is_append_only(tmp_path: Path) -> None:
    """One continuous run history proves detection + alarm + freeze +
    controlled recovery without any persisted breach latch to reset."""
    journal_path = tmp_path / "journal.jsonl"
    alarm_log = tmp_path / "alarms.log"
    policy = _write_policy(tmp_path / "policy.json", gross_ceiling=1.0, now=T0)
    emergency = _write_emergency(tmp_path / "emergency.json", policy.sha256, now=T0)

    timeline = [
        # 1. CLEAR: policy bound, gross leverage within ceiling.
        (T0, _snapshot(T0, gross_notional=50_000.0), policy, None),
        # 2. BREACH: gross leverage above ceiling -> level 2 freeze+cancel plan.
        (
            T0 + dt.timedelta(minutes=5),
            _snapshot(T0 + dt.timedelta(minutes=5), gross_notional=200_000.0),
            policy,
            None,
        ),
        # 3. EMERGENCY: same breach, now with a bound OWNER emergency policy -> level 3.
        (
            T0 + dt.timedelta(minutes=10),
            _snapshot(T0 + dt.timedelta(minutes=10), gross_notional=200_000.0),
            policy,
            emergency,
        ),
        # 4. RECOVERY: condition clears on its own -> back to level 0, no reset call made.
        (
            T0 + dt.timedelta(minutes=15),
            _snapshot(T0 + dt.timedelta(minutes=15), gross_notional=50_000.0),
            policy,
            None,
        ),
    ]

    records = []
    for now, snapshot, run_policy, run_emergency in timeline:
        record = recurring.build_record(
            snapshot,
            now_utc=now,
            expected_login=LOGIN,
            max_age_seconds=90,
            policy=run_policy,
            emergency_policy=run_emergency,
        )
        recurring.append_journal(record, journal_path)
        recurring.append_alarm(record, alarm_log)
        records.append(record)

        # Append-only: every prior line in the journal is untouched after this write.
        lines = journal_path.read_text(encoding="utf-8").splitlines()
        assert len(lines) == len(records)
        for prior_record, prior_line in zip(records, lines):
            assert json.loads(prior_line) == prior_record

        # Every active position is recognized on every single run, regardless of level.
        assert record["recognized_position_tickets"] == [301, 302]
        assert record["positions_reconciled"] is True
        assert record["orders_reconciled"] is True
        assert record["actions_executed"] == []
        assert record["dry_run"] is True

    levels = [record["decision_level"] for record in records]
    assert levels == [0, 2, 3, 0]

    # Freeze/cancel plan is concrete and only appears from level 2 onward.
    assert records[0]["would_cancel_pending_order_tickets"] == []
    assert records[1]["would_cancel_pending_order_tickets"] == [401]
    assert records[2]["would_cancel_pending_order_tickets"] == [401]
    assert records[3]["would_cancel_pending_order_tickets"] == []

    # Flatten plan requires the independently bound emergency policy, not just the breach.
    assert records[1]["would_flatten_position_tickets"] == []
    assert records[2]["would_flatten_position_tickets"] == [301, 302]
    assert records[3]["would_flatten_position_tickets"] == []

    # Alarm fires exactly when level > 0, at the severity matching the level.
    alarm_lines = alarm_log.read_text(encoding="utf-8").splitlines()
    assert len(alarm_lines) == 2  # CLEAR and RECOVERY runs raise no alarm
    assert " WARN " in alarm_lines[0] and "level=2" in alarm_lines[0]
    assert " CRITICAL " in alarm_lines[1] and "level=3" in alarm_lines[1]

    # Recovery is provable from the record itself: the last run needed no emergency
    # policy, no cancel/flatten plan, and no different code path than the first CLEAR run.
    assert records[3]["decision_name"] == records[0]["decision_name"] == "CLEAR"
    assert records[3]["policy_bound"] is True
    assert records[3]["emergency_policy_bound"] is False


def test_alarm_line_omitted_for_clear_but_present_for_policy_unbound(tmp_path: Path) -> None:
    policy = _write_policy(tmp_path / "policy.json", gross_ceiling=100.0, now=T0)
    clear_record = recurring.build_record(
        _snapshot(T0, gross_notional=1_000.0),
        now_utc=T0,
        expected_login=LOGIN,
        max_age_seconds=90,
        policy=policy,
    )
    assert clear_record["decision_level"] == 0
    assert recurring.alarm_line(clear_record) is None

    # Without a bound policy the evaluator fails closed to level 1 (ENTRY_FREEZE_POLICY_UNBOUND),
    # and that must alarm too -- an unbound policy is itself an operating condition to flag.
    unbound_record = recurring.build_record(
        _snapshot(T0, gross_notional=1_000.0),
        now_utc=T0,
        expected_login=LOGIN,
        max_age_seconds=90,
        policy=None,
    )
    assert unbound_record["decision_level"] == 1
    line = recurring.alarm_line(unbound_record)
    assert line is not None
    assert "level=1" in line


def test_stage3_never_reachable_without_emergency_policy_even_across_many_runs(
    tmp_path: Path,
) -> None:
    policy = _write_policy(tmp_path / "policy.json", gross_ceiling=1.0, now=T0)
    for minute in range(5):
        now = T0 + dt.timedelta(minutes=minute)
        record = recurring.build_record(
            _snapshot(now, gross_notional=200_000.0),
            now_utc=now,
            expected_login=LOGIN,
            max_age_seconds=90,
            policy=policy,
            emergency_policy=None,
        )
        assert record["decision_level"] == 2
        assert record["would_flatten_position_tickets"] == []
        assert record["actions_executed"] == []
