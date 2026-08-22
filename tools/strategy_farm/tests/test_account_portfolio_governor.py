from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import account_portfolio_governor as governor


REPO = Path(__file__).resolve().parents[3]
MONITOR = REPO / "framework" / "monitor" / "QM_AccountMonitor.mq5"
NOW = dt.datetime(2026, 8, 22, 10, 45, tzinfo=dt.UTC)
LOGIN = 4000090541


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


def _snapshot() -> dict:
    positions = [
        _position(101, 111320000, "EURUSD", "BUY", 100_000.0, 1_000.0, "EUR"),
        # Magic 0 and an unregistered magic are intentionally included. Reconciliation
        # is account-scoped; magic is attribution only.
        _position(102, 0, "XAUUSD", "SELL", -50_000.0, 500.0, "XAU"),
        _position(103, 999, "NDX", "BUY", 25_000.0, 250.0, "NDX"),
    ]
    orders = [
        {"ticket": 201, "magic": 0, "symbol": "EURUSD", "type": "BUY_LIMIT"},
        {"ticket": 202, "magic": 999, "symbol": "XAUUSD", "type": "SELL_STOP"},
    ]
    return {
        "schema": governor.SNAPSHOT_SCHEMA,
        "monitor_version": "1.10",
        "account_login": LOGIN,
        "currency": "USD",
        "time_utc": "2026-08-22T10:44:30Z",
        "equity": 100_000.0,
        "balance": 99_500.0,
        "margin": 10_000.0,
        "free_margin": 90_000.0,
        "open_positions": len(positions),
        "pending_orders": len(orders),
        "reconciled_positions": len(positions),
        "reconciled_orders": len(orders),
        "reconciliation_complete": True,
        "gross_notional_account": 175_000.0,
        "net_directional_notional_account": 75_000.0,
        "planned_stop_loss_account": 1_750.0,
        "unpriced_positions": 0,
        "positions_without_stop": 0,
        "write_ok": True,
        "positions": positions,
        "orders": orders,
    }


def _write_policy(path: Path, *, gross_ceiling: float) -> governor.BoundPolicy:
    payload = {
        "schema": governor.POLICY_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-08-22T00:00:00Z",
        "valid_until_utc": "2026-08-23T00:00:00Z",
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
        path,
        digest,
        schema=governor.POLICY_SCHEMA,
        now_utc=NOW,
        expected_login=LOGIN,
        label="policy",
    )


def _write_emergency(
    path: Path, trigger_sha256: str
) -> governor.BoundPolicy:
    payload = {
        "schema": governor.EMERGENCY_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-08-22T10:40:00Z",
        "valid_until_utc": "2026-08-22T11:00:00Z",
        "incident_id": "TEST-INCIDENT-1",
        "flatten_authorized": True,
        "trigger_policy_sha256": trigger_sha256,
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return governor._load_bound_policy(
        path,
        digest,
        schema=governor.EMERGENCY_SCHEMA,
        now_utc=NOW,
        expected_login=LOGIN,
        label="emergency_policy",
    )


def test_reconciles_every_position_independent_of_magic_and_computes_risk() -> None:
    analysis = governor.analyze_snapshot(
        _snapshot(), now_utc=NOW, max_age_seconds=90, expected_login=LOGIN
    )

    assert analysis["uncertainties"] == []
    assert analysis["positions_reconciled"] is True
    assert analysis["orders_reconciled"] is True
    assert analysis["recognized_position_tickets"] == [101, 102, 103]
    assert [row["magic"] for row in analysis["recognized_positions"]] == [111320000, 0, 999]
    assert all(row["included_independent_of_magic"] for row in analysis["recognized_positions"])
    assert analysis["metrics"]["gross_leverage"] == 1.75
    assert analysis["metrics"]["net_directional_leverage"] == 0.75
    assert analysis["metrics"]["planned_stop_loss_account"] == 1750.0
    assert analysis["metrics"]["currency_net_account"] == {
        "EUR": 100000.0,
        "NDX": 25000.0,
        "USD": -75000.0,
        "XAU": -50000.0,
    }


def test_uncertainty_is_entry_freeze_only() -> None:
    snapshot = _snapshot()
    snapshot["reconciliation_complete"] = False
    snapshot["positions"] = snapshot["positions"][:-1]

    result = governor.evaluate(
        snapshot,
        now_utc=NOW,
        expected_login=LOGIN,
        max_age_seconds=90,
    )

    assert result["decision"]["level"] == 1
    assert result["action_plan"]["entry_freeze"] is True
    assert result["action_plan"]["would_cancel_pending_order_tickets"] == []
    assert result["action_plan"]["would_flatten_position_tickets"] == []
    assert result["action_plan"]["actions_executed"] == []


def test_threshold_breach_reaches_cancel_plan_but_never_flatten_without_emergency(
    tmp_path: Path,
) -> None:
    policy = _write_policy(tmp_path / "policy.json", gross_ceiling=1.0)

    result = governor.evaluate(
        _snapshot(),
        now_utc=NOW,
        expected_login=LOGIN,
        max_age_seconds=90,
        policy=policy,
    )

    assert result["decision"]["level"] == 2
    assert result["breaches"] == ["gross_leverage_above_ceiling"]
    assert result["action_plan"]["would_cancel_pending_order_tickets"] == [201, 202]
    assert result["action_plan"]["would_flatten_position_tickets"] == []
    assert result["execution_adapter_present"] is False


def test_flatten_plan_requires_independently_hash_bound_owner_emergency_policy(
    tmp_path: Path,
) -> None:
    policy = _write_policy(tmp_path / "policy.json", gross_ceiling=1.0)
    emergency = _write_emergency(tmp_path / "emergency.json", policy.sha256)

    result = governor.evaluate(
        _snapshot(),
        now_utc=NOW,
        expected_login=LOGIN,
        max_age_seconds=90,
        policy=policy,
        emergency_policy=emergency,
    )

    assert result["decision"]["level"] == 3
    assert result["action_plan"]["would_flatten_position_tickets"] == [101, 102, 103]
    assert result["action_plan"]["actions_executed"] == []
    assert result["dry_run"] is True


def test_policy_hash_mismatch_fails_closed(tmp_path: Path) -> None:
    path = tmp_path / "policy.json"
    path.write_text("{}", encoding="utf-8")

    with pytest.raises(governor.GovernorError, match="policy_sha256_mismatch"):
        governor._load_bound_policy(
            path,
            "0" * 64,
            schema=governor.POLICY_SCHEMA,
            now_utc=NOW,
            expected_login=LOGIN,
            label="policy",
        )


def test_monitor_source_enumerates_all_account_exposure_without_magic_filter() -> None:
    source = MONITOR.read_text(encoding="utf-8")
    positions = source[
        source.index("string BuildPositionInventory") : source.index(
            "string BuildOrderInventory"
        )
    ]
    orders = source[
        source.index("string BuildOrderInventory") : source.index(
            "//+------------------------------------------------------------------+\n//| Atomic-ish write"
        )
    ]

    assert "PositionsTotal()" in positions
    assert "PositionGetTicket(index)" in positions
    assert "OrdersTotal()" in orders
    assert "OrderGetTicket(index)" in orders
    assert "MagicAllowed" not in positions
    assert "MagicAllowed" not in orders
    assert "OrderCalcProfit" in source
    assert governor.SNAPSHOT_SCHEMA in source
