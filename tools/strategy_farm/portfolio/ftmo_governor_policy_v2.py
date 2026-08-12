"""Immutable FTMO 2-Step 100k V2 account-governor policy — Python oracle.

This is the reusable Python mirror of the MQL policy include
``framework/include/QM/QM_FTMOGovernorPolicy.mqh`` (V2, three signed policies:
Phase 1, Verification, Funded). It exists so that:

* the MQL/Python golden-parity blocker (SPEC blocker #2) has a single reusable
  oracle instead of a policy reimplementation embedded inside a test;
* the golden-parity harness that cross-checks the governor against the
  independent read-only observer ``ftmo_trial_pulse.py`` can call the exact same
  decision math the governor EA runs on the FTMO terminal.

The values are RELEASE CONSTANTS, not optimizer inputs. Every field and the
reason ladder are a line-for-line mirror of the ``.mqh``; the fingerprints are
verified against ``artifacts/ftmo_governor_policy_golden_2026-07-17.json`` and
against the exact-double fingerprints embedded in the include. Nothing here
arms, deploys, or writes anything on any terminal — it is pure decision math.

Prague-midnight day boundaries are computed with the SAME last-Sunday DST
algorithm as the include (spring: last Sunday of March 01:00 UTC; autumn: last
Sunday of October 01:00 UTC), and additionally cross-checked against
``zoneinfo`` Europe/Prague in the test suite.
"""

from __future__ import annotations

import dataclasses
import datetime as dt
import hashlib
import json
import math
from typing import Mapping


# --- Contract identity (mirror of QM_FTMOGovernorPolicy.mqh) ----------------

POLICY_VERSION = 2.0
CONTRACT_REVISION = 2

P1_FINGERPRINT_NUMBER = 1215771617389199
P2_FINGERPRINT_NUMBER = 2586499533483248
FUNDED_FINGERPRINT_NUMBER = 1248702263814813

# Official FTMO 2-Step 100k outer limits (encoded identically in every policy).
OFFICIAL_START_BALANCE = 100_000.0
OFFICIAL_TOTAL_FLOOR = 90_000.0          # 10% static Maximum Loss
OFFICIAL_DAILY_LOSS = 5_000.0            # 5% Maximum Daily Loss from Prague-midnight balance

# Canonical field order used for the sealed fingerprint. MUST match the
# POLICY_FIELDS tuple in framework/tests/test_ftmo_governor_policy_v2.py.
POLICY_FIELDS = (
    "policy_id",
    "start_balance",
    "target_enabled",
    "target_balance",
    "official_total_floor",
    "official_daily_loss",
    "internal_total_floor",
    "entry_daily_stop",
    "liquidation_daily_stop",
    "profit_room_retention",
    "full_risk_room",
    "minimum_trading_days",
    "taper_level_1",
    "taper_scale_1",
    "taper_level_2",
    "taper_scale_2",
)


@dataclasses.dataclass(frozen=True)
class GovernorPolicy:
    policy_id: str
    start_balance: float
    target_enabled: bool
    target_balance: float
    official_total_floor: float
    official_daily_loss: float
    internal_total_floor: float
    entry_daily_stop: float
    liquidation_daily_stop: float
    profit_room_retention: float
    full_risk_room: float
    minimum_trading_days: int
    taper_level_1: float
    taper_scale_1: float
    taper_level_2: float
    taper_scale_2: float

    def canonical_payload(self) -> dict:
        return {field: getattr(self, field) for field in POLICY_FIELDS}

    def fingerprint(self) -> tuple[str, int]:
        """Return (sha256_hex, exact-double fingerprint number).

        Identical construction to the golden artifact / v2 test so the number
        equals the exact-double fingerprint embedded in the .mqh.
        """
        canonical = json.dumps(
            self.canonical_payload(), sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
        digest = hashlib.sha256(canonical).hexdigest()
        number = int(digest[:13], 16) & ((1 << 52) - 1)
        return digest, number


# --- The three signed immutable policies (mirror QM_FTMO_SelectPolicy) -------

_POLICIES: dict[str, GovernorPolicy] = {
    "FTMO_2S_P1_100K_V2": GovernorPolicy(
        policy_id="FTMO_2S_P1_100K_V2",
        start_balance=100_000.0,
        target_enabled=True,
        target_balance=110_000.0,
        official_total_floor=90_000.0,
        official_daily_loss=5_000.0,
        internal_total_floor=94_000.0,
        entry_daily_stop=900.0,
        liquidation_daily_stop=1_250.0,
        profit_room_retention=0.2,
        full_risk_room=900.0,
        minimum_trading_days=4,
        taper_level_1=107_500.0,
        taper_scale_1=0.75,
        taper_level_2=109_000.0,
        taper_scale_2=0.5,
    ),
    "FTMO_2S_P2_100K_V2": GovernorPolicy(
        policy_id="FTMO_2S_P2_100K_V2",
        start_balance=100_000.0,
        target_enabled=True,
        target_balance=105_000.0,
        official_total_floor=90_000.0,
        official_daily_loss=5_000.0,
        internal_total_floor=96_000.0,
        entry_daily_stop=650.0,
        liquidation_daily_stop=900.0,
        profit_room_retention=0.2,
        full_risk_room=650.0,
        minimum_trading_days=4,
        taper_level_1=103_500.0,
        taper_scale_1=0.7,
        taper_level_2=104_500.0,
        taper_scale_2=0.4,
    ),
    "FTMO_2S_FUNDED_100K_V2": GovernorPolicy(
        policy_id="FTMO_2S_FUNDED_100K_V2",
        start_balance=100_000.0,
        target_enabled=False,
        target_balance=0.0,
        official_total_floor=90_000.0,
        official_daily_loss=5_000.0,
        internal_total_floor=97_500.0,
        entry_daily_stop=350.0,
        liquidation_daily_stop=500.0,
        profit_room_retention=0.2,
        full_risk_room=350.0,
        minimum_trading_days=0,
        taper_level_1=0.0,
        taper_scale_1=1.0,
        taper_level_2=0.0,
        taper_scale_2=1.0,
    ),
}

_EXPECTED_FINGERPRINTS = {
    "FTMO_2S_P1_100K_V2": P1_FINGERPRINT_NUMBER,
    "FTMO_2S_P2_100K_V2": P2_FINGERPRINT_NUMBER,
    "FTMO_2S_FUNDED_100K_V2": FUNDED_FINGERPRINT_NUMBER,
}


def select_policy(policy_id: str) -> GovernorPolicy:
    """Mirror of QM_FTMO_SelectPolicy: only exact allowlisted IDs resolve."""
    if policy_id not in _POLICIES:
        raise KeyError(f"unknown/unsigned policy id: {policy_id!r}")
    return _POLICIES[policy_id]


def all_policy_ids() -> tuple[str, ...]:
    return tuple(_POLICIES.keys())


# --- Prague-midnight day key (mirror of the .mqh last-Sunday DST math) -------

def _last_sunday_at_one_utc(year: int, month: int) -> dt.datetime:
    """Last Sunday of `month` at 01:00 UTC — the CE(S)T transition instant.

    Europe/Prague switches at 01:00 UTC on the last Sunday of March (to +02:00)
    and the last Sunday of October (back to +01:00). This is the exact instant
    used by QM_FTMO_LastSundayAtOneUTC in the include.
    """
    if month == 12:
        first_next = dt.datetime(year + 1, 1, 1, tzinfo=dt.timezone.utc)
    else:
        first_next = dt.datetime(year, month + 1, 1, tzinfo=dt.timezone.utc)
    last_day = (first_next - dt.timedelta(days=1)).replace(hour=1)
    # weekday(): Mon=0..Sun=6 -> Python; MQL day_of_week Sun=0..Sat=6.
    dow_mql = (last_day.weekday() + 1) % 7  # Sun->0
    return last_day - dt.timedelta(days=dow_mql)


def prague_utc_offset_seconds(ts_utc: dt.datetime) -> int:
    ts_utc = _as_utc(ts_utc)
    spring = _last_sunday_at_one_utc(ts_utc.year, 3)
    autumn = _last_sunday_at_one_utc(ts_utc.year, 10)
    return 7200 if (spring <= ts_utc < autumn) else 3600


def prague_day_key(ts_utc: dt.datetime) -> int:
    """Integer day key year*10000+mon*100+day for the Prague local date."""
    ts_utc = _as_utc(ts_utc)
    offset = prague_utc_offset_seconds(ts_utc)
    local = ts_utc + dt.timedelta(seconds=offset)
    return local.year * 10000 + local.month * 100 + local.day


def _as_utc(ts: dt.datetime) -> dt.datetime:
    if ts.tzinfo is None:
        raise ValueError("timestamp must be timezone-aware (UTC)")
    return ts.astimezone(dt.timezone.utc)


# --- Floors, risk scale, decision (mirror QM_FTMO_* evaluate functions) ------

def floors(midnight_balance: float, policy: GovernorPolicy) -> dict:
    if not math.isfinite(midnight_balance) or midnight_balance <= 0.0:
        raise ValueError("midnight_balance must be finite and positive")
    official_daily_floor = midnight_balance - policy.official_daily_loss
    protected_profit_floor = policy.internal_total_floor + policy.profit_room_retention * max(
        0.0, midnight_balance - policy.internal_total_floor
    )
    internal_daily_floor = midnight_balance - policy.liquidation_daily_stop
    liquidation_floor = max(
        policy.official_total_floor,
        policy.internal_total_floor,
        official_daily_floor,
        internal_daily_floor,
        protected_profit_floor,
    )
    entry_floor = max(liquidation_floor, midnight_balance - policy.entry_daily_stop)
    return {
        "official_daily_floor": official_daily_floor,
        "protected_profit_floor": protected_profit_floor,
        "liquidation_floor": liquidation_floor,
        "entry_floor": entry_floor,
    }


def entry_risk_scale(equity: float, entry_floor: float, policy: GovernorPolicy) -> float:
    if not (math.isfinite(equity) and math.isfinite(entry_floor)):
        raise ValueError("equity and entry_floor must be finite")
    room = min(1.0, max(0.0, (equity - entry_floor) / policy.full_risk_room))
    target_cap = 1.0
    if policy.target_enabled:
        if equity >= policy.target_balance:
            target_cap = 0.0
        elif equity >= policy.taper_level_2:
            target_cap = policy.taper_scale_2
        elif equity >= policy.taper_level_1:
            target_cap = policy.taper_scale_1
    return min(room, target_cap)


# Policy-level decision reasons (mirror QM_FTMO_GovernorReason string names).
REASON_PERSISTED_TOTAL_LOCK = "PERSISTED_TOTAL_LOCK"
REASON_TOTAL_FLOOR = "TOTAL_FLOOR"
REASON_PERSISTED_DAY_LOCK = "PERSISTED_DAY_LOCK"
REASON_EFFECTIVE_DAILY_FLOOR = "EFFECTIVE_DAILY_FLOOR"
REASON_TARGET_COMPLETE = "TARGET_COMPLETE"
REASON_TARGET_CAPTURE = "TARGET_CAPTURE"
REASON_ENTRY_HALT = "ENTRY_HALT"
REASON_ALLOW = "ALLOW"

# EA publish-level reason added in WS-G′ for the target-before-day-4 fail-safe.
REASON_TARGET_MIN_DAYS_PENDING = "TARGET_MIN_DAYS_PENDING"
REASON_UNKNOWN_EXPOSURE = "UNKNOWN_EXPOSURE"

_HALT_REASONS = frozenset(
    {
        REASON_PERSISTED_TOTAL_LOCK,
        REASON_TOTAL_FLOOR,
        REASON_PERSISTED_DAY_LOCK,
        REASON_EFFECTIVE_DAILY_FLOOR,
        REASON_TARGET_COMPLETE,
        REASON_TARGET_CAPTURE,
        REASON_ENTRY_HALT,
    }
)


def evaluate_snapshot(
    *,
    timestamp_utc: dt.datetime,
    balance: float,
    equity: float,
    midnight_balance: float,
    trading_days: int,
    positions_open: int = 0,
    orders_pending: int = 0,
    persisted_day_lock: bool = False,
    persisted_total_lock: bool = False,
    policy: GovernorPolicy,
) -> dict:
    """Line-for-line mirror of QM_FTMO_EvaluateSnapshot. Returns the decision
    dict with the same fields the golden artifact records."""
    for name, value in (("balance", balance), ("equity", equity), ("midnight_balance", midnight_balance)):
        if not math.isfinite(value):
            raise ValueError(f"{name} must be finite")
    if balance <= 0.0 or equity <= 0.0:
        raise ValueError("balance and equity must be positive")
    if trading_days < 0 or positions_open < 0 or orders_pending < 0:
        raise ValueError("counts must be non-negative")

    f = floors(midnight_balance, policy)
    scale = entry_risk_scale(equity, f["entry_floor"], policy)
    minimum_days_complete = trading_days >= policy.minimum_trading_days
    target_reached = policy.target_enabled and equity >= policy.target_balance
    target_complete = (
        policy.target_enabled
        and balance >= policy.target_balance
        and positions_open == 0
        and orders_pending == 0
        and minimum_days_complete
    )

    if persisted_total_lock:
        reason = REASON_PERSISTED_TOTAL_LOCK
    elif equity <= policy.internal_total_floor or equity <= policy.official_total_floor:
        reason = REASON_TOTAL_FLOOR
    elif persisted_day_lock:
        reason = REASON_PERSISTED_DAY_LOCK
    elif equity <= f["liquidation_floor"]:
        reason = REASON_EFFECTIVE_DAILY_FLOOR
    elif target_complete:
        reason = REASON_TARGET_COMPLETE
    elif target_reached:
        reason = REASON_TARGET_CAPTURE
    elif equity <= f["entry_floor"] or scale <= 0.0:
        reason = REASON_ENTRY_HALT
    else:
        reason = REASON_ALLOW

    persist_lock = reason in {
        REASON_TOTAL_FLOOR,
        REASON_EFFECTIVE_DAILY_FLOOR,
        REASON_TARGET_CAPTURE,
        REASON_TARGET_COMPLETE,
    }
    flatten_required = reason in {
        REASON_TOTAL_FLOOR,
        REASON_EFFECTIVE_DAILY_FLOOR,
        REASON_TARGET_CAPTURE,
    } and (positions_open > 0 or orders_pending > 0)

    return {
        "prague_day_key": prague_day_key(timestamp_utc),
        "official_daily_floor": f["official_daily_floor"],
        "protected_profit_floor": f["protected_profit_floor"],
        "liquidation_floor": f["liquidation_floor"],
        "entry_floor": f["entry_floor"],
        "risk_scale": scale,
        "minimum_days_complete": minimum_days_complete,
        "target_reached": target_reached,
        "target_complete": target_complete,
        "reason": reason,
        "entry_allowed": reason == REASON_ALLOW,
        "persist_lock": persist_lock,
        "flatten_required": flatten_required,
    }


def is_halt(reason: str) -> bool:
    return reason in _HALT_REASONS or reason in {
        REASON_TARGET_MIN_DAYS_PENDING,
        REASON_UNKNOWN_EXPOSURE,
    }


# --- EA publish-reason remap (mirror of EvaluateAndPublish tail) -------------

def ea_publish_reason(
    *,
    policy_reason: str,
    target_complete: bool,
    target_lock: bool,
    day_lock: bool,
    total_lock: bool,
    unknown_exposure: bool,
    trading_days: int,
    minimum_trading_days: int,
) -> str:
    """Mirror of the governor EA's publish_reason remap, including the WS-G′
    target-before-day-4 fail-safe branch (TARGET_MIN_DAYS_PENDING).

    The remap keeps the raw breach reason unless a monotone latch dominates:
      * completed target             -> TARGET_COMPLETE
      * target latched, days < min   -> TARGET_MIN_DAYS_PENDING  (NEW, fail-safe)
      * target latched (days met)    -> TARGET_CAPTURE
      * foreign exposure only        -> UNKNOWN_EXPOSURE
    Day/total locks always dominate and are surfaced by the raw reason.
    """
    reason = policy_reason
    if target_complete and not day_lock and not total_lock:
        reason = REASON_TARGET_COMPLETE
    elif (
        target_lock
        and not target_complete
        and not day_lock
        and not total_lock
        and trading_days < minimum_trading_days
    ):
        reason = REASON_TARGET_MIN_DAYS_PENDING
    elif target_lock and not day_lock and not total_lock:
        reason = REASON_TARGET_CAPTURE
    elif unknown_exposure and not day_lock and not total_lock and not target_lock:
        reason = REASON_UNKNOWN_EXPOSURE
    return reason


# --- Official-limit view (the domain shared with ftmo_trial_pulse.py) --------

def official_total_breach(equity: float, policy: GovernorPolicy) -> bool:
    """FTMO 10% static Maximum Loss breach (equity at/below the 90k floor)."""
    return equity <= policy.official_total_floor


def official_daily_breach(equity: float, midnight_balance: float, policy: GovernorPolicy) -> bool:
    """FTMO 5% Maximum Daily Loss breach measured from the Prague-midnight
    balance (equity at/below midnight - 5% of start)."""
    return equity <= (midnight_balance - policy.official_daily_loss)


def self_check() -> None:
    """Validate the mirrored policies against the sealed fingerprints."""
    for pid, policy in _POLICIES.items():
        _digest, number = policy.fingerprint()
        expected = _EXPECTED_FINGERPRINTS[pid]
        if number != expected:
            raise RuntimeError(
                f"policy {pid} fingerprint {number} != sealed {expected}"
            )
        if policy.official_total_floor != OFFICIAL_TOTAL_FLOOR:
            raise RuntimeError(f"policy {pid} official total floor drift")
        if policy.official_daily_loss != OFFICIAL_DAILY_LOSS:
            raise RuntimeError(f"policy {pid} official daily loss drift")


# Fail fast at import time: a mutated policy must never load silently.
self_check()
