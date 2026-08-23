from __future__ import annotations

import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

from tools.strategy_farm import account_portfolio_governor as governor
from tools.strategy_farm import governor_dry_run_watch as watch


NOW = dt.datetime(2026, 8, 23, 8, 0, tzinfo=dt.UTC)
LOGIN = 4000090541


def _configure_paths(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(watch, "STATE_JSON", tmp_path / "state.json")
    monkeypatch.setattr(watch, "GUARD_LOG", tmp_path / "guard.log")
    monkeypatch.setattr(watch, "ALARM_LOG", tmp_path / "alarms.log")
    monkeypatch.setattr(watch, "HISTORY_JSONL", tmp_path / "history.jsonl")


def _position(ticket: int, magic: int, symbol: str, side: str) -> dict:
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
        "base_currency": symbol[:3],
        "profit_currency": "USD",
        "notional_account_ok": True,
        "signed_notional_account": 10_000.0 if side == "BUY" else -10_000.0,
        "stop_loss_account_ok": True,
        "remaining_loss_to_sl_account": 250.0,
    }


def _snapshot(*, positions: list[dict], orders: list[dict], observed_at: str) -> dict:
    return {
        "schema": governor.SNAPSHOT_SCHEMA,
        "account_login": LOGIN,
        "time_utc": observed_at,
        "equity": 100_000.0,
        "balance": 99_500.0,
        "margin": 5_000.0,
        "free_margin": 95_000.0,
        "open_positions": len(positions),
        "pending_orders": len(orders),
        "reconciled_positions": len(positions),
        "reconciled_orders": len(orders),
        "reconciliation_complete": True,
        "gross_notional_account": sum(abs(p["signed_notional_account"]) for p in positions),
        "net_directional_notional_account": sum(
            p["signed_notional_account"] for p in positions
        ),
        "planned_stop_loss_account": sum(
            p["remaining_loss_to_sl_account"] for p in positions
        ),
        "unpriced_positions": 0,
        "positions_without_stop": 0,
        "write_ok": True,
        "positions": positions,
        "orders": orders,
    }


def _write_policy(path: Path, *, gross_ceiling: float) -> None:
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
            "max_abs_currency_net_leverage": 5.0,
            "max_planned_stop_loss_account": 10_000.0,
        },
    }
    path.write_text(json.dumps(payload), encoding="utf-8")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_every_active_position_is_recognized_and_persisted(
    monkeypatch, tmp_path: Path
) -> None:
    _configure_paths(monkeypatch, tmp_path)
    snapshot_path = tmp_path / "snapshot.json"
    positions = [
        _position(101, 111320000, "EURUSD", "BUY"),
        _position(102, 0, "XAUUSD", "SELL"),
        _position(103, 999, "NDX", "BUY"),
    ]
    orders = [{"ticket": 201, "magic": 0, "symbol": "EURUSD", "type": "BUY_LIMIT"}]
    snapshot_path.write_text(
        json.dumps(_snapshot(positions=positions, orders=orders, observed_at="2026-08-23T07:59:30Z")),
        encoding="utf-8",
    )
    monkeypatch.setattr(sys, "argv", ["governor_dry_run_watch.py", "--dry-run",
                                       "--snapshot", str(snapshot_path),
                                       "--now-utc", "2026-08-23T08:00:00Z"])

    rc = watch.main()

    assert rc == 0
    state = json.loads(watch.STATE_JSON.read_text(encoding="utf-8"))
    assert sorted(state["last_position_tickets"]) == [101, 102, 103]
    assert state["last_order_tickets"] == [201]
    assert state["run_count"] == 1
    history_lines = watch.HISTORY_JSONL.read_text(encoding="utf-8").strip().splitlines()
    assert len(history_lines) == 1
    recorded = json.loads(history_lines[0])
    assert sorted(recorded["analysis"]["recognized_position_tickets"]) == [101, 102, 103]
    assert recorded["action_plan"]["actions_executed"] == []
    assert recorded["dry_run"] is True


def test_level_increase_writes_alarm_and_level_decrease_writes_recovery(
    monkeypatch, tmp_path: Path
) -> None:
    _configure_paths(monkeypatch, tmp_path)
    snapshot_path = tmp_path / "snapshot.json"
    policy_path = tmp_path / "policy.json"
    _write_policy(policy_path, gross_ceiling=0.05)  # trivially breached by any position
    policy_sha = _sha256(policy_path)

    positions = [_position(101, 111320000, "EURUSD", "BUY")]
    snapshot_path.write_text(
        json.dumps(_snapshot(positions=positions, orders=[], observed_at="2026-08-23T07:59:30Z")),
        encoding="utf-8",
    )

    common_argv = [
        "governor_dry_run_watch.py", "--dry-run",
        "--snapshot", str(snapshot_path),
        "--policy", str(policy_path),
        "--trusted-policy-sha256", policy_sha,
        "--now-utc", "2026-08-23T08:00:00Z",
    ]

    # Run 1: no prior state -> first observation, no transition recorded yet.
    monkeypatch.setattr(sys, "argv", common_argv)
    assert watch.main() == 0
    state1 = json.loads(watch.STATE_JSON.read_text(encoding="utf-8"))
    assert state1["last_level"] == 2  # PENDING_CANCEL_AND_ENTRY_FREEZE (breach, no emergency policy)
    assert state1["alarm_count"] == 0
    assert not watch.ALARM_LOG.exists()

    # Run 2: snapshot now resolves (no positions, no breach) while the same
    # policy stays bound -> level drops back to 0 (CLEAR) -> RECOVERY.
    snapshot_path.write_text(
        json.dumps(_snapshot(positions=[], orders=[], observed_at="2026-08-23T08:04:30Z")),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        sys,
        "argv",
        common_argv[:-1] + ["2026-08-23T08:05:00Z"],
    )
    assert watch.main() == 0
    state2 = json.loads(watch.STATE_JSON.read_text(encoding="utf-8"))
    assert state2["last_level"] == 0
    assert state2["last_transition"] == "RECOVERY"
    assert state2["recovery_count"] == 1
    alarm_lines = watch.ALARM_LOG.read_text(encoding="utf-8").strip().splitlines()
    assert len(alarm_lines) == 1
    recovery_entry = json.loads(alarm_lines[0])
    assert recovery_entry["source"] == "governor_dry_run_watch"
    assert recovery_entry["severity"] == "INFO"
    assert "level_decrease" in recovery_entry["detail"]

    # Run 3: breach returns -> level climbs back to 2 -> ALARM this time
    # (prior state now exists, so the increase is a real transition).
    snapshot_path.write_text(
        json.dumps(_snapshot(positions=positions, orders=[], observed_at="2026-08-23T08:09:30Z")),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        sys,
        "argv",
        common_argv[:-1] + ["2026-08-23T08:10:00Z"],
    )
    assert watch.main() == 0
    state3 = json.loads(watch.STATE_JSON.read_text(encoding="utf-8"))
    assert state3["last_level"] == 2
    assert state3["last_transition"] == "ALARM"
    assert state3["alarm_count"] == 1
    alarm_lines = watch.ALARM_LOG.read_text(encoding="utf-8").strip().splitlines()
    assert len(alarm_lines) == 2
    alarm_entry = json.loads(alarm_lines[1])
    assert alarm_entry["severity"] == "WARN"
    assert "level_increase" in alarm_entry["detail"]


def test_stage3_flatten_requires_owner_signed_emergency_policy_bound_to_trigger(
    monkeypatch, tmp_path: Path
) -> None:
    _configure_paths(monkeypatch, tmp_path)
    snapshot_path = tmp_path / "snapshot.json"
    policy_path = tmp_path / "policy.json"
    _write_policy(policy_path, gross_ceiling=0.05)
    policy_sha = _sha256(policy_path)

    positions = [_position(101, 111320000, "EURUSD", "BUY")]
    snapshot_path.write_text(
        json.dumps(_snapshot(positions=positions, orders=[], observed_at="2026-08-23T07:59:30Z")),
        encoding="utf-8",
    )

    # No emergency policy supplied: stage 3 must not be reachable, whatever
    # the breach severity, and no action may ever be listed as executed.
    monkeypatch.setattr(sys, "argv", [
        "governor_dry_run_watch.py", "--dry-run",
        "--snapshot", str(snapshot_path),
        "--policy", str(policy_path),
        "--trusted-policy-sha256", policy_sha,
        "--now-utc", "2026-08-23T08:00:00Z",
    ])
    assert watch.main() == 0
    history = json.loads(watch.HISTORY_JSONL.read_text(encoding="utf-8").strip())
    assert history["decision"]["level"] == 2
    assert history["action_plan"]["would_flatten_position_tickets"] == []
    assert history["action_plan"]["actions_executed"] == []
    assert history["emergency_policy_binding"]["bound"] is False


def test_unreadable_snapshot_fails_closed_without_crashing(monkeypatch, tmp_path: Path) -> None:
    _configure_paths(monkeypatch, tmp_path)
    missing_snapshot = tmp_path / "does_not_exist.json"
    monkeypatch.setattr(sys, "argv", [
        "governor_dry_run_watch.py", "--dry-run",
        "--snapshot", str(missing_snapshot),
        "--expected-login", str(LOGIN),
        "--now-utc", "2026-08-23T08:00:00Z",
    ])

    rc = watch.main()

    assert rc == 0
    state = json.loads(watch.STATE_JSON.read_text(encoding="utf-8"))
    assert state["last_level"] == 1
    history = json.loads(watch.HISTORY_JSONL.read_text(encoding="utf-8").strip())
    assert history["decision"]["name"] == "ENTRY_FREEZE_WATCHER_ERROR"
    assert history["action_plan"]["actions_executed"] == []


def test_dry_run_flag_is_a_required_acknowledgement(monkeypatch, tmp_path: Path) -> None:
    _configure_paths(monkeypatch, tmp_path)
    monkeypatch.setattr(sys, "argv", ["governor_dry_run_watch.py"])

    rc = watch.main()

    assert rc == 2
    assert not watch.STATE_JSON.exists()
