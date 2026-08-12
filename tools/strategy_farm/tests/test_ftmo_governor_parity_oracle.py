"""Standing golden-parity tests for the FTMO account-governor (WS-G').

Binds the reusable Python policy oracle
``tools/strategy_farm/portfolio/ftmo_governor_policy_v2.py`` to:

  * the sealed golden artifact + the exact-double fingerprints in the .mqh
    (MQL/Python golden parity, SPEC blocker #2);
  * the independent read-only observer ``ftmo_trial_pulse.assess_loss_limits``
    (governor >= observer on the official FTMO limits — the observer never
    becomes a competing halt authority);
  * the Prague-midnight DST day boundary (tz-DB-free hardcoded transitions plus
    an optional zoneinfo cross-check);
  * the target-before-day-4 fail-safe reason remap.

All fixtures here are deterministic and terminal-free (portable/CI-safe). The
FTMO-terminal replay corpus lives in the WS-G harness, not in this test.
"""

from __future__ import annotations

import datetime as dt
import json
import math
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
GOLDEN = ROOT / "artifacts" / "ftmo_governor_policy_golden_2026-07-17.json"

import sys

sys.path.insert(0, str(ROOT))
from tools.strategy_farm.portfolio import ftmo_governor_policy_v2 as gov  # noqa: E402
from tools.strategy_farm import ftmo_trial_pulse as pulse  # noqa: E402


UTC = dt.timezone.utc


# --- Fingerprint / golden-artifact parity -----------------------------------

def test_self_check_and_fingerprints_match_sealed_include():
    gov.self_check()  # raises on any policy drift
    assert gov.select_policy("FTMO_2S_P1_100K_V2").fingerprint()[1] == gov.P1_FINGERPRINT_NUMBER
    assert gov.select_policy("FTMO_2S_P2_100K_V2").fingerprint()[1] == gov.P2_FINGERPRINT_NUMBER
    assert gov.select_policy("FTMO_2S_FUNDED_100K_V2").fingerprint()[1] == gov.FUNDED_FINGERPRINT_NUMBER


def test_oracle_matches_sealed_golden_artifact():
    data = json.loads(GOLDEN.read_text(encoding="utf-8"))
    assert data["contract_revision"] == gov.CONTRACT_REVISION
    assert data["policy_version"] == gov.POLICY_VERSION
    # Fingerprints and sha256 in the artifact reproduce from the oracle policies.
    for item in data["policies"]:
        pol = gov.select_policy(item["policy_id"])
        digest, number = pol.fingerprint()
        assert digest == item["canonical_sha256"], item["policy_id"]
        assert number == item["fingerprint_number"], item["policy_id"]
    # Every golden decision case reproduces exactly.
    for case in data["golden_cases"]:
        pol = gov.select_policy(case["policy_id"])
        dec = gov.evaluate_snapshot(
            timestamp_utc=dt.datetime(2026, 1, 15, 12, tzinfo=UTC),
            balance=case["balance"], equity=case["equity"],
            midnight_balance=case["midnight_balance"], trading_days=case["trading_days"],
            positions_open=case["positions_open"], orders_pending=case["orders_pending"],
            policy=pol,
        )
        for key, expected in case["expected"].items():
            actual = dec[key]
            if isinstance(expected, float):
                assert abs(actual - expected) < 1e-9, (case["name"], key)
            else:
                assert actual == expected, (case["name"], key)


# --- Prague-midnight DST parity ---------------------------------------------

@pytest.mark.parametrize(
    "ts_iso,expected_key",
    [
        ("2026-03-28T23:30:00Z", 20260329),
        ("2026-03-29T00:30:00Z", 20260329),
        ("2026-03-29T01:30:00Z", 20260329),
        ("2026-10-24T22:30:00Z", 20261025),
        ("2026-10-25T00:30:00Z", 20261025),
        ("2026-10-25T23:30:00Z", 20261026),
        ("2026-07-01T22:05:00Z", 20260702),
        ("2026-01-15T12:00:00Z", 20260115),
    ],
)
def test_prague_day_key_across_dst(ts_iso, expected_key):
    ts = dt.datetime.fromisoformat(ts_iso.replace("Z", "+00:00"))
    assert gov.prague_day_key(ts) == expected_key


def test_prague_day_key_matches_zoneinfo_when_available():
    try:
        from zoneinfo import ZoneInfo

        prague = ZoneInfo("Europe/Prague")
    except Exception:  # pragma: no cover - tz DB not installed
        pytest.skip("tzdata/zoneinfo unavailable")
    base = dt.datetime(2026, 1, 1, tzinfo=UTC)
    for hours in range(0, 366 * 24, 7):  # sample across the whole year
        ts = base + dt.timedelta(hours=hours)
        local = ts.astimezone(prague).date()
        assert gov.prague_day_key(ts) == local.year * 10000 + local.month * 100 + local.day


# --- Parity vs the independent observer (official limits) --------------------

def _pulse_official_alarm(equity: float, day_pnl: float) -> tuple[bool, bool]:
    _t, _d, alarms, _w = pulse.assess_loss_limits(equity, day_pnl)
    total = any(a.startswith("total_dd_limit_breached") for a in alarms)
    daily = any(a.startswith("daily_loss_limit_breached") for a in alarms)
    return total, daily


@pytest.mark.parametrize(
    "equity,day_pnl,expect_total,expect_daily",
    [
        (89_999.0, -10_001.0, True, True),    # both official limits breached
        (90_000.0, -10_000.0, True, True),    # exactly at both floors -> breach (<=)
        (90_001.0, -9_999.0, False, True),    # total just safe, daily breached
        (95_001.0, -4_999.0, False, False),   # daily just safe
        (95_000.0, -5_000.0, False, True),    # daily exactly at floor -> breach
        (99_500.0, -500.0, False, False),     # healthy
    ],
)
def test_official_limit_equivalence_vs_observer(equity, day_pnl, expect_total, expect_daily):
    policy = gov.select_policy("FTMO_2S_P1_100K_V2")
    midnight = equity - day_pnl
    gov_total = gov.official_total_breach(equity, policy)
    gov_daily = gov.official_daily_breach(equity, midnight, policy)
    pulse_total, pulse_daily = _pulse_official_alarm(equity, day_pnl)
    # Governor official-limit math and observer percentage math agree.
    assert gov_total == pulse_total == expect_total
    assert gov_daily == pulse_daily == expect_daily


@pytest.mark.parametrize("equity", [88_000.0, 90_000.0, 92_000.0, 94_000.0,
                                    95_000.0, 97_000.0, 99_000.0, 99_500.0, 100_000.0])
def test_safety_direction_governor_never_more_permissive(equity):
    """If the governor allows entry, the observer must NOT be raising an official
    breach; equivalently, an official observer alarm forces the governor closed.
    Proven across the full risk-room band under the Phase-1 policy."""
    policy = gov.select_policy("FTMO_2S_P1_100K_V2")
    # Flat account: day_pnl == equity - midnight; use a fresh 100k Prague midnight.
    midnight = 100_000.0
    day_pnl = equity - midnight
    dec = gov.evaluate_snapshot(
        timestamp_utc=dt.datetime(2026, 5, 4, 12, tzinfo=UTC),
        balance=equity, equity=equity, midnight_balance=midnight,
        trading_days=1, policy=policy,
    )
    pulse_total, pulse_daily = _pulse_official_alarm(equity, day_pnl)
    if pulse_total or pulse_daily:
        assert not dec["entry_allowed"], equity
    if dec["entry_allowed"]:
        assert not (pulse_total or pulse_daily), equity


# --- Target-before-day-4 fail-safe reason remap -----------------------------

def test_target_before_day4_yields_min_days_pending():
    r = gov.ea_publish_reason(
        policy_reason=gov.REASON_TARGET_CAPTURE,
        target_complete=False, target_lock=True, day_lock=False, total_lock=False,
        unknown_exposure=False, trading_days=2, minimum_trading_days=4,
    )
    assert r == gov.REASON_TARGET_MIN_DAYS_PENDING
    assert gov.is_halt(r)  # still a halt state (entry locked, gains protected)


def test_target_with_min_days_met_is_capture_then_complete():
    capture = gov.ea_publish_reason(
        policy_reason=gov.REASON_TARGET_CAPTURE,
        target_complete=False, target_lock=True, day_lock=False, total_lock=False,
        unknown_exposure=False, trading_days=4, minimum_trading_days=4,
    )
    assert capture == gov.REASON_TARGET_CAPTURE
    complete = gov.ea_publish_reason(
        policy_reason=gov.REASON_TARGET_COMPLETE,
        target_complete=True, target_lock=True, day_lock=False, total_lock=False,
        unknown_exposure=False, trading_days=4, minimum_trading_days=4,
    )
    assert complete == gov.REASON_TARGET_COMPLETE


def test_day_or_total_lock_dominates_min_days_pending():
    # A day/total breach must not be masked by the target-pending remap.
    for lock in ("day", "total"):
        r = gov.ea_publish_reason(
            policy_reason=gov.REASON_EFFECTIVE_DAILY_FLOOR,
            target_complete=False, target_lock=True,
            day_lock=(lock == "day"), total_lock=(lock == "total"),
            unknown_exposure=False, trading_days=1, minimum_trading_days=4,
        )
        assert r == gov.REASON_EFFECTIVE_DAILY_FLOOR


def test_funded_policy_never_target_locks():
    funded = gov.select_policy("FTMO_2S_FUNDED_100K_V2")
    dec = gov.evaluate_snapshot(
        timestamp_utc=dt.datetime(2026, 5, 4, 12, tzinfo=UTC),
        balance=200_000.0, equity=200_000.0, midnight_balance=100_000.0,
        trading_days=0, policy=funded,
    )
    assert dec["target_reached"] is False
    assert dec["target_complete"] is False
    assert dec["reason"] == gov.REASON_ALLOW


# --- Fail-closed input handling ---------------------------------------------

def test_unknown_policy_id_fails_closed():
    with pytest.raises(KeyError):
        gov.select_policy("FTMO_2S_P1_100K_V3")
    with pytest.raises(KeyError):
        gov.select_policy("")


def test_nonfinite_and_nonpositive_inputs_fail_closed():
    policy = gov.select_policy("FTMO_2S_P1_100K_V2")
    ts = dt.datetime(2026, 5, 4, 12, tzinfo=UTC)
    for bad in (float("nan"), float("inf")):
        with pytest.raises(ValueError):
            gov.evaluate_snapshot(timestamp_utc=ts, balance=bad, equity=100_000.0,
                                  midnight_balance=100_000.0, trading_days=1, policy=policy)
    with pytest.raises(ValueError):
        gov.evaluate_snapshot(timestamp_utc=ts, balance=100_000.0, equity=-1.0,
                              midnight_balance=100_000.0, trading_days=1, policy=policy)
    with pytest.raises(ValueError):
        gov.floors(0.0, policy)


def test_naive_timestamp_fails_closed():
    policy = gov.select_policy("FTMO_2S_P1_100K_V2")
    with pytest.raises(ValueError):
        gov.evaluate_snapshot(timestamp_utc=dt.datetime(2026, 5, 4, 12),
                              balance=100_000.0, equity=100_000.0,
                              midnight_balance=100_000.0, trading_days=1, policy=policy)


def test_internal_floors_are_a_conservative_superset_of_official():
    # Governor internal total floor is strictly tighter than the official 90k,
    # so it halts before the official max-loss line every phase.
    for pid in gov.all_policy_ids():
        pol = gov.select_policy(pid)
        assert pol.internal_total_floor >= pol.official_total_floor
        assert math.isclose(pol.official_total_floor, gov.OFFICIAL_TOTAL_FLOOR)
        assert math.isclose(pol.official_daily_loss, gov.OFFICIAL_DAILY_LOSS)
