"""Immutable FTMO Phase-1 account-governor policy and parity vectors.

The V1 values are release constants, not optimizer inputs. Runtime callers must
persist a lock before cancellation/liquidation and must capture target equity by
flattening before declaring the balance target complete.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Mapping
from zoneinfo import ZoneInfo


PRAGUE = ZoneInfo("Europe/Prague")
UTC = dt.timezone.utc
V1_CONTRACT_REVISION = 1
V1_POLICY_SHA256 = "03390b7a65ee33153f4fe63064bb163c4bcc692436b694cdd2ed1be7f1117e3d"
V1_FINGERPRINT_NUMBER = int(V1_POLICY_SHA256[:12], 16)


@dataclasses.dataclass(frozen=True)
class GovernorPolicy:
    policy_id: str = "FTMO_P1_GOVERNOR_V1"
    start_balance: float = 100_000.0
    target_balance: float = 110_000.0
    total_loss_floor: float = 90_000.0
    execution_daily_stop: float = 4_500.0
    profit_room_retention: float = 0.20
    full_risk_room: float = 4_000.0
    minimum_trading_days: int = 4

    def validate(self) -> None:
        expected = {
            "policy_id": "FTMO_P1_GOVERNOR_V1",
            "start_balance": 100_000.0,
            "target_balance": 110_000.0,
            "total_loss_floor": 90_000.0,
            "execution_daily_stop": 4_500.0,
            "profit_room_retention": 0.20,
            "full_risk_room": 4_000.0,
            "minimum_trading_days": 4,
        }
        actual = dataclasses.asdict(self)
        numeric = [
            actual[name]
            for name in (
                "start_balance",
                "target_balance",
                "total_loss_floor",
                "execution_daily_stop",
                "profit_room_retention",
                "full_risk_room",
            )
        ]
        if not all(math.isfinite(float(value)) for value in numeric):
            raise ValueError("policy values must be finite")
        if actual != expected:
            raise ValueError("FTMO_P1_GOVERNOR_V1 values are immutable")

    def canonical_payload(self) -> dict[str, Any]:
        self.validate()
        return dataclasses.asdict(self)

    def sha256(self) -> str:
        payload = json.dumps(
            {
                "contract_revision": V1_CONTRACT_REVISION,
                "policy": self.canonical_payload(),
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        digest = hashlib.sha256(payload).hexdigest()
        if digest != V1_POLICY_SHA256:
            raise RuntimeError("V1 policy payload no longer matches its sealed fingerprint")
        return digest


@dataclasses.dataclass(frozen=True)
class GovernorSnapshot:
    timestamp_utc: dt.datetime
    balance: float
    equity: float
    midnight_balance: float
    trading_days: int
    positions_open: int = 0
    orders_pending: int = 0
    persisted_day_lock: bool = False
    persisted_total_lock: bool = False

    def validate(self) -> None:
        if self.timestamp_utc.tzinfo is None:
            raise ValueError("timestamp_utc must be timezone-aware")
        for name in ("balance", "equity", "midnight_balance"):
            if not math.isfinite(float(getattr(self, name))):
                raise ValueError(f"{name} must be finite")
        if self.trading_days < 0 or self.positions_open < 0 or self.orders_pending < 0:
            raise ValueError("counts must be non-negative")


@dataclasses.dataclass(frozen=True)
class GovernorDecision:
    prague_day: str
    effective_floor: float
    daily_floor: float
    protected_profit_floor: float
    risk_scale: float
    entry_allowed: bool
    persist_lock: bool
    flatten_required: bool
    minimum_days_complete: bool
    target_reached: bool
    target_complete: bool
    reason: str

    def to_dict(self) -> dict[str, Any]:
        return dataclasses.asdict(self)


def parse_utc(value: str | dt.datetime) -> dt.datetime:
    if isinstance(value, dt.datetime):
        parsed = value
    else:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("UTC timestamp must include an offset")
    return parsed.astimezone(UTC)


def prague_day(value: str | dt.datetime) -> dt.date:
    return parse_utc(value).astimezone(PRAGUE).date()


def daily_floors(
    midnight_balance: float, policy: GovernorPolicy
) -> tuple[float, float, float]:
    policy.validate()
    if not math.isfinite(midnight_balance):
        raise ValueError("midnight_balance must be finite")
    daily_floor = midnight_balance - policy.execution_daily_stop
    protected_profit_floor = policy.total_loss_floor + (
        policy.profit_room_retention
        * max(0.0, midnight_balance - policy.total_loss_floor)
    )
    effective = max(daily_floor, protected_profit_floor, policy.total_loss_floor)
    return daily_floor, protected_profit_floor, effective


def entry_risk_scale(
    equity: float, effective_floor: float, policy: GovernorPolicy
) -> float:
    policy.validate()
    if not math.isfinite(equity) or not math.isfinite(effective_floor):
        raise ValueError("equity and effective_floor must be finite")
    raw = (equity - effective_floor) / policy.full_risk_room
    return min(1.0, max(0.0, raw))


def evaluate_snapshot(
    snapshot: GovernorSnapshot, policy: GovernorPolicy | None = None
) -> GovernorDecision:
    policy = policy or GovernorPolicy()
    policy.validate()
    snapshot.validate()
    daily_floor, protected_floor, effective_floor = daily_floors(
        snapshot.midnight_balance, policy
    )
    scale = entry_risk_scale(snapshot.equity, effective_floor, policy)
    minimum_days_complete = snapshot.trading_days >= policy.minimum_trading_days
    target_reached = snapshot.equity >= policy.target_balance
    target_complete = (
        snapshot.balance >= policy.target_balance
        and snapshot.positions_open == 0
        and snapshot.orders_pending == 0
        and minimum_days_complete
    )

    if snapshot.persisted_total_lock:
        reason = "PERSISTED_TOTAL_LOCK"
    elif snapshot.equity <= policy.total_loss_floor:
        reason = "TOTAL_FLOOR"
    elif snapshot.persisted_day_lock:
        reason = "PERSISTED_DAY_LOCK"
    elif snapshot.equity <= effective_floor:
        reason = "EFFECTIVE_DAILY_FLOOR"
    elif target_complete:
        reason = "TARGET_COMPLETE"
    elif target_reached:
        reason = "TARGET_CAPTURE"
    elif scale <= 0.0:
        reason = "NO_RISK_ROOM"
    else:
        reason = "ALLOW"

    breach_lock = reason in {
        "TOTAL_FLOOR",
        "EFFECTIVE_DAILY_FLOOR",
        "TARGET_CAPTURE",
        "TARGET_COMPLETE",
    }
    flatten_required = reason in {
        "TOTAL_FLOOR",
        "EFFECTIVE_DAILY_FLOOR",
        "TARGET_CAPTURE",
    } and (snapshot.positions_open > 0 or snapshot.orders_pending > 0)
    return GovernorDecision(
        prague_day=prague_day(snapshot.timestamp_utc).isoformat(),
        effective_floor=round(effective_floor, 10),
        daily_floor=round(daily_floor, 10),
        protected_profit_floor=round(protected_floor, 10),
        risk_scale=round(scale, 10),
        entry_allowed=reason == "ALLOW",
        persist_lock=breach_lock,
        flatten_required=flatten_required,
        minimum_days_complete=minimum_days_complete,
        target_reached=target_reached,
        target_complete=target_complete,
        reason=reason,
    )


def golden_vectors(policy: GovernorPolicy | None = None) -> dict[str, Any]:
    policy = policy or GovernorPolicy()
    cases: Mapping[str, GovernorSnapshot] = {
        "full_risk": GovernorSnapshot(
            parse_utc("2026-01-15T12:00:00Z"), 100_000, 100_000, 100_000, 1
        ),
        "daily_headroom_scale": GovernorSnapshot(
            parse_utc("2026-01-15T13:00:00Z"), 95_900, 95_900, 100_000, 1
        ),
        "daily_floor_flatten": GovernorSnapshot(
            parse_utc("2026-01-15T14:00:00Z"),
            96_000,
            95_500,
            100_000,
            1,
            positions_open=2,
        ),
        "spring_dst_before": GovernorSnapshot(
            parse_utc("2026-03-29T00:30:00Z"), 100_000, 100_000, 100_000, 1
        ),
        "spring_dst_after": GovernorSnapshot(
            parse_utc("2026-03-29T01:30:00Z"), 100_000, 100_000, 100_000, 1
        ),
        "target_capture_open": GovernorSnapshot(
            parse_utc("2026-07-01T12:00:00Z"),
            109_500,
            110_100,
            109_000,
            4,
            positions_open=1,
        ),
        "target_too_few_days": GovernorSnapshot(
            parse_utc("2026-07-01T12:00:00Z"), 110_100, 110_100, 109_000, 3
        ),
        "target_pending": GovernorSnapshot(
            parse_utc("2026-07-02T12:00:00Z"),
            110_100,
            110_100,
            109_000,
            4,
            orders_pending=1,
        ),
        "target_complete": GovernorSnapshot(
            parse_utc("2026-07-02T12:00:00Z"), 110_100, 110_100, 109_000, 4
        ),
    }
    return {
        "schema_version": 2,
        "contract_revision": V1_CONTRACT_REVISION,
        "policy": policy.canonical_payload(),
        "policy_sha256": policy.sha256(),
        "policy_fingerprint_number": V1_FINGERPRINT_NUMBER,
        "cases": {
            name: {
                "input": {
                    **dataclasses.asdict(snapshot),
                    "timestamp_utc": snapshot.timestamp_utc.isoformat(),
                },
                "expected": evaluate_snapshot(snapshot, policy).to_dict(),
            }
            for name, snapshot in cases.items()
        },
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--golden-out", type=Path)
    args = parser.parse_args(argv)
    rendered = json.dumps(golden_vectors(), indent=2, sort_keys=True) + "\n"
    if args.golden_out:
        args.golden_out.parent.mkdir(parents=True, exist_ok=True)
        args.golden_out.write_text(rendered, encoding="utf-8")
        print(f"wrote {args.golden_out}")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
