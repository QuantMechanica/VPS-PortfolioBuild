import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import ftmo_trial_pulse  # noqa: E402


def test_loss_monitor_warns_at_half_total_budget() -> None:
    total_dd, day_loss, alarms, warns = ftmo_trial_pulse.assess_loss_limits(94_015.80, -111.79)

    assert round(total_dd, 4) == 5.9842
    assert round(day_loss, 5) == 0.11179
    assert alarms == []
    assert warns == ["total_dd_warning:5.98pct_vs_limit_10.0"]


def test_loss_monitor_alarms_at_actual_limit() -> None:
    total_dd, day_loss, alarms, warns = ftmo_trial_pulse.assess_loss_limits(89_999.0, -5_000.0)

    assert total_dd > 10.0
    assert day_loss == 5.0
    assert "total_dd_limit_breached:10.00pct" in alarms
    assert "daily_loss_limit_breached:5.00pct" in alarms
    assert warns == []


def test_snapshot_age_is_utc_aware() -> None:
    now = datetime(2026, 7, 9, 20, 0, tzinfo=timezone.utc)

    age = ftmo_trial_pulse.snapshot_age_minutes("2026-07-09T17:30:00Z", now)

    assert age == 150.0


def test_snapshot_age_rejects_invalid_timestamp() -> None:
    assert ftmo_trial_pulse.snapshot_age_minutes("not-a-time") is None


def test_expected_state_parked_off_is_ok() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(terminal_up=False, now=now)

    assert state["expected_state"] == "PARKED"
    assert state["condition"] == "parked"
    assert state["alarm"] is None


def test_expected_state_parked_running_is_alarm() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(terminal_up=True, now=now)

    assert state["condition"] == "unexpected_running"
    assert state["alarm"] == "ftmo_terminal_running_while_parked"


def test_expected_state_expiry_fails_closed() -> None:
    now = datetime(2026, 8, 25, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(terminal_up=False, now=now)

    assert state["review_expired"] is True
    assert state["condition"] == "contract_expired"
    assert state["alarm"] == "expected_state_review_expired"


def test_invalid_expected_state_fails_closed_even_during_maintenance() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=False,
        now=now,
        maintenance=True,
        expected_state="UNKNOWN",
    )

    assert state["condition"] == "contract_invalid"
    assert state["alarm"] == "expected_state_contract_invalid"


def test_parked_state_fails_closed_when_process_probe_is_unknown() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(terminal_up=None, now=now)

    assert state["condition"] == "probe_unknown"
    assert state["alarm"] == "ftmo_terminal_process_probe_unknown"


def test_contract_expiry_wins_over_maintenance() -> None:
    now = datetime(2026, 9, 1, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=True,
        now=now,
        maintenance=True,
    )

    assert state["effective_state"] == "MAINTENANCE"
    assert state["condition"] == "contract_expired"
    assert state["alarm"] == "expected_state_review_expired"


def test_unexpired_maintenance_suppresses_runtime_alarm() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=True,
        now=now,
        maintenance=True,
    )

    assert state["effective_state"] == "MAINTENANCE"
    assert state["condition"] == "maintenance"
    assert state["alarm"] is None


def test_contract_expiry_wins_over_unknown_process_probe() -> None:
    now = datetime(2026, 9, 1, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=None,
        now=now,
    )

    assert state["condition"] == "contract_expired"
    assert state["alarm"] == "expected_state_review_expired"


def test_pulse_is_observer_only_no_halt_signal_emission() -> None:
    """One-authority tombstone (WS-G' round 2): the FTMO pulse must never emit a
    halt/liquidation signal. The single armed halt authority is the
    account-governor EA QM5_13206. This source guard prevents any future edit or
    bad merge from silently reintroducing the removed `portfolio_dd.signal`
    second-authority write path."""
    src = (ROOT / "tools" / "strategy_farm" / "ftmo_trial_pulse.py").read_text(encoding="utf-8")
    # The removed halt-emission identifiers must not come back.
    assert "BOOK_DD_SIGNAL" not in src
    assert "DD_FLOOR_PCT" not in src
    assert "dd_floor_signal" not in src
    # Exactly one write in the whole module — the read-only state JSON. A second
    # write (a halt-signal file) reintroduces a competing authority and trips
    # this tripwire.
    assert src.count(".write_text(") == 1
    # Tombstone + refusal are present; the retired arm flag is ignored, not honored.
    assert "ONE-AUTHORITY TOMBSTONE" in src
    assert "LEGACY_ARM_FLAG" in src
    assert "ftmo_dd_floor_arm_flag_present_but_ignored" in src


def test_pulse_declares_observer_role_and_governor_authority() -> None:
    src = (ROOT / "tools" / "strategy_farm" / "ftmo_trial_pulse.py").read_text(encoding="utf-8")
    assert '"role": "observer_only"' in src
    assert "governor_QM5_13206" in src
