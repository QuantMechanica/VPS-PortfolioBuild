"""Contract tests for the FTMO trial pulse.

The four PARKED-branch tests below pass ``expected_state="PARKED"`` explicitly.
They used to rely on the module default, which OWNER changed from PARKED to
RUNNING on 2026-08-13 when the demo was ratified as running -- so all four went
red and stayed red. A branch test must pin the branch it tests, not inherit
whatever the current operational default happens to be; a permanently red test
in the live-monitoring suite trains everyone to ignore red.
"""
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

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=False, now=now, expected_state="PARKED"
    )

    assert state["expected_state"] == "PARKED"
    assert state["condition"] == "parked_terminal_stopped"
    assert state["alarm"] is None


def test_expected_state_parked_running_without_qm_magics_is_ok() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=True,
        now=now,
        magics_seen=0,
        expected_state="PARKED",
    )

    assert state["condition"] == "parked_terminal_running_no_qm_trading"
    assert state["alarm"] is None


def test_expected_state_parked_running_with_qm_magic_is_alarm() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=True,
        now=now,
        magics_seen=1,
        expected_state="PARKED",
    )

    assert state["condition"] == "parked_qm_trading_active"
    assert state["alarm"] == "ftmo_qm_magics_active_while_parked:1"


def test_expected_state_parked_running_fails_closed_on_unknown_magic_probe() -> None:
    now = datetime(2026, 7, 28, tzinfo=timezone.utc)

    state = ftmo_trial_pulse.assess_expected_state(
        terminal_up=True, now=now, expected_state="PARKED"
    )

    assert state["condition"] == "parked_magic_probe_unknown"
    assert state["alarm"] == "ftmo_parked_magic_probe_unknown"


def test_open_qm_positions_come_from_broker_deal_lifecycle(tmp_path: Path) -> None:
    path = tmp_path / "live_deals_normalized.csv"
    path.write_text(
        "deal_id,position_id,time_utc,entry,deal_magic,logical_magic,symbol,profit,swap,commission,fee,net_actual,risk_percent_in_force,net_per_1pct_risk,magic,type,volume,price,order,time_broker,comment\n"
        "1,100,2026-08-12T10:00:00Z,IN,107060001,,GBPUSD,0,0,0,0,0,,,107060001,SELL,0.2,1.2,10,2026-08-12 13:00:00,open\n"
        "2,100,2026-08-12T11:00:00Z,OUT,0,,GBPUSD,2,0,0,0,2,,,0,BUY,0.2,1.1,11,2026-08-12 14:00:00,close\n"
        "3,200,2026-08-12T12:00:00Z,IN,133010010,,GER40.cash,0,0,0,0,0,,,133010010,BUY,0.1,26000,12,2026-08-12 15:00:00,open\n",
        encoding="utf-8",
    )

    state = ftmo_trial_pulse.read_open_qm_positions(path)

    assert state["ok"] is True
    assert state["magics"] == [133010010]
    assert [row["position_id"] for row in state["positions"]] == [200]


def test_open_qm_positions_fail_closed_on_missing_contract_column(tmp_path: Path) -> None:
    path = tmp_path / "live_deals_normalized.csv"
    path.write_text("position_id,entry,magic\n1,IN,107060001\n", encoding="utf-8")

    state = ftmo_trial_pulse.read_open_qm_positions(path)

    assert state["ok"] is False
    assert state["reason"].startswith("deal_export_header_missing:")


def test_parked_activity_requires_fresh_matching_account_position_count() -> None:
    activity = {
        "ok": True,
        "reason": "ok",
        "positions": [{"position_id": 200, "magic": 133010010, "closed": False}],
        "magics": [133010010],
    }

    matching = ftmo_trial_pulse.reconcile_parked_activity(
        activity,
        {"fresh": True, "open_positions": 1},
    )
    mismatch = ftmo_trial_pulse.reconcile_parked_activity(
        activity,
        {"fresh": True, "open_positions": 0},
    )
    missing_count = ftmo_trial_pulse.reconcile_parked_activity(
        activity,
        {"fresh": True},
    )

    assert matching == {"ok": True, "reason": "ok", "magics_seen": 1}
    assert mismatch["ok"] is False
    assert mismatch["reason"] == "account_position_count_mismatch:0!=1"
    assert mismatch["magics_seen"] is None
    assert missing_count["reason"] == "account_open_positions_invalid"
    assert missing_count["magics_seen"] is None


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
