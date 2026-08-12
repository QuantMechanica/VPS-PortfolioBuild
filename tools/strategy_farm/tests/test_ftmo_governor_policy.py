import datetime as dt
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_governor_policy as policy  # noqa: E402


def snapshot(**overrides):
    values = {
        "timestamp_utc": dt.datetime(2026, 1, 15, 12, tzinfo=dt.timezone.utc),
        "balance": 100_000.0,
        "equity": 100_000.0,
        "midnight_balance": 100_000.0,
        "trading_days": 1,
    }
    values.update(overrides)
    return policy.GovernorSnapshot(**values)


def test_default_floor_and_full_risk() -> None:
    decision = policy.evaluate_snapshot(snapshot())

    assert decision.daily_floor == 95_500.0
    assert decision.protected_profit_floor == 92_000.0
    assert decision.effective_floor == 95_500.0
    assert decision.risk_scale == 1.0
    assert decision.entry_allowed is True


def test_risk_scale_is_clamped_and_linear_inside_room() -> None:
    cfg = policy.GovernorPolicy()

    assert policy.entry_risk_scale(95_500.0, 95_500.0, cfg) == 0.0
    assert policy.entry_risk_scale(97_500.0, 95_500.0, cfg) == 0.5
    assert policy.entry_risk_scale(99_500.0, 95_500.0, cfg) == 1.0
    assert policy.entry_risk_scale(120_000.0, 95_500.0, cfg) == 1.0


def test_v1_policy_values_and_fingerprint_are_immutable() -> None:
    with pytest.raises(ValueError, match="immutable"):
        policy.GovernorPolicy(total_loss_floor=80_000.0).validate()
    with pytest.raises(ValueError, match="immutable"):
        policy.GovernorPolicy(execution_daily_stop=9_000.0).validate()
    assert policy.GovernorPolicy().sha256() == policy.V1_POLICY_SHA256
    assert policy.V1_CONTRACT_REVISION == 1
    assert policy.V1_FINGERPRINT_NUMBER == 3_543_540_590_062


def test_breach_persists_lock_before_flatten() -> None:
    decision = policy.evaluate_snapshot(
        snapshot(equity=95_500.0, positions_open=2)
    )

    assert decision.reason == "EFFECTIVE_DAILY_FLOOR"
    assert decision.entry_allowed is False
    assert decision.persist_lock is True
    assert decision.flatten_required is True


def test_profit_retention_can_dominate_total_floor() -> None:
    cfg = policy.GovernorPolicy()
    daily, protected, effective = policy.daily_floors(106_000.0, cfg)

    assert daily == 101_500.0
    assert protected == 93_200.0
    assert effective == 101_500.0


def test_target_requires_flat_account_and_minimum_days() -> None:
    too_early = policy.evaluate_snapshot(
        snapshot(balance=110_100, equity=110_100, trading_days=3)
    )
    still_open = policy.evaluate_snapshot(
        snapshot(balance=110_100, equity=110_100, trading_days=4, positions_open=1)
    )
    pending = policy.evaluate_snapshot(
        snapshot(balance=110_100, equity=110_100, trading_days=4, orders_pending=1)
    )
    complete = policy.evaluate_snapshot(
        snapshot(balance=110_100, equity=110_100, trading_days=4)
    )

    assert too_early.target_complete is False
    assert too_early.reason == "TARGET_CAPTURE"
    assert too_early.entry_allowed is False
    assert still_open.target_complete is False
    assert still_open.flatten_required is True
    assert pending.target_complete is False
    assert pending.flatten_required is True
    assert complete.target_complete is True
    assert complete.reason == "TARGET_COMPLETE"
    assert complete.entry_allowed is False


def test_current_total_floor_escalates_through_persisted_day_lock() -> None:
    decision = policy.evaluate_snapshot(
        snapshot(equity=89_999.0, persisted_day_lock=True)
    )

    assert decision.reason == "TOTAL_FLOOR"
    assert decision.persist_lock is True


def test_prague_day_handles_spring_and_fall_dst() -> None:
    assert policy.prague_day("2026-03-28T23:30:00Z").isoformat() == "2026-03-29"
    assert policy.prague_day("2026-10-24T22:30:00Z").isoformat() == "2026-10-25"
    assert policy.prague_day("2026-10-25T23:30:00Z").isoformat() == "2026-10-26"


def test_naive_or_nonfinite_inputs_fail_closed() -> None:
    with pytest.raises(ValueError, match="timezone-aware"):
        policy.evaluate_snapshot(
            snapshot(timestamp_utc=dt.datetime(2026, 1, 1), equity=100_000)
        )
    with pytest.raises(ValueError, match="equity must be finite"):
        policy.evaluate_snapshot(snapshot(equity=float("nan")))


def test_golden_vectors_are_hash_bound_and_deterministic() -> None:
    first = policy.golden_vectors()
    second = policy.golden_vectors()

    assert first == second
    assert first["policy_sha256"] == policy.V1_POLICY_SHA256
    assert first["policy_fingerprint_number"] == policy.V1_FINGERPRINT_NUMBER
    assert first["cases"]["daily_floor_flatten"]["expected"]["persist_lock"] is True
    assert first["cases"]["target_capture_open"]["expected"]["flatten_required"] is True
