#!/usr/bin/env python3
"""Read-only account/portfolio governor evaluator.

The evaluator consumes the detailed, atomic snapshot emitted by
``framework/monitor/QM_AccountMonitor.mq5`` v1.10.  It never connects to MT5,
never sends/deletes/closes an order, and has no apply mode.  Its output is a
dry-run escalation plan only.

Production thresholds require a raw-file SHA-256-bound OWNER policy.  A
controlled-flatten plan additionally requires a second, independently bound
OWNER emergency policy.  Supplying neither (the normal diagnostic mode) fails
closed at entry-freeze level.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SNAPSHOT_SCHEMA = "qm.account-monitor.snapshot/v2"
POLICY_SCHEMA = "qm.account-governor.policy/v1"
EMERGENCY_SCHEMA = "qm.account-governor.emergency-policy/v1"
OUTPUT_SCHEMA = "qm.account-governor.dry-run/v1"
DEFAULT_SNAPSHOT = Path(
    r"C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/account_snapshot.json"
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class GovernorError(RuntimeError):
    """Invalid input that prevents a trustworthy dry-run decision."""


@dataclass(frozen=True)
class BoundPolicy:
    raw: dict[str, Any]
    path: Path
    sha256: str


def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _read_json(path: Path, label: str) -> dict[str, Any]:
    if not path.is_file():
        raise GovernorError(f"{label}_missing:{path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise GovernorError(f"{label}_unreadable:{path}:{exc}") from exc
    if not isinstance(value, dict):
        raise GovernorError(f"{label}_not_object:{path}")
    return value


def _parse_ts(value: Any, label: str) -> dt.datetime:
    try:
        parsed = dt.datetime.fromisoformat(str(value or "").replace("Z", "+00:00"))
    except ValueError as exc:
        raise GovernorError(f"{label}_invalid:{value!r}") from exc
    if parsed.tzinfo is None:
        raise GovernorError(f"{label}_timezone_missing:{value!r}")
    return parsed.astimezone(dt.UTC)


def _finite(value: Any, label: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise GovernorError(f"{label}_invalid:{value!r}") from exc
    if not math.isfinite(number):
        raise GovernorError(f"{label}_not_finite:{value!r}")
    return number


def _positive_int(value: Any, label: str, *, allow_zero: bool = False) -> int:
    if isinstance(value, bool):
        raise GovernorError(f"{label}_invalid:{value!r}")
    try:
        number = int(value)
    except (TypeError, ValueError) as exc:
        raise GovernorError(f"{label}_invalid:{value!r}") from exc
    if str(number) != str(value).strip() and not isinstance(value, int):
        raise GovernorError(f"{label}_not_integer:{value!r}")
    if number < 0 or (number == 0 and not allow_zero):
        raise GovernorError(f"{label}_out_of_range:{number}")
    return number


def _load_bound_policy(
    path: Path,
    trusted_sha256: str,
    *,
    schema: str,
    now_utc: dt.datetime,
    expected_login: int,
    label: str,
) -> BoundPolicy:
    trusted = str(trusted_sha256 or "").lower()
    if not SHA256_RE.fullmatch(trusted):
        raise GovernorError(f"{label}_trusted_sha256_missing_or_invalid")
    resolved = path.resolve()
    actual = _sha256(resolved) if resolved.is_file() else ""
    if actual != trusted:
        raise GovernorError(
            f"{label}_sha256_mismatch:expected={trusted}:actual={actual or 'MISSING'}"
        )
    policy = _read_json(resolved, label)
    if policy.get("schema") != schema:
        raise GovernorError(f"{label}_schema_invalid:{policy.get('schema')}")
    if policy.get("status") != "OWNER_SIGNED":
        raise GovernorError(f"{label}_not_owner_signed:{policy.get('status')}")
    if not str(policy.get("authorized_by") or "").upper().startswith("OWNER"):
        raise GovernorError(f"{label}_owner_attribution_missing")
    login = _positive_int(policy.get("account_login"), f"{label}.account_login")
    if login != expected_login:
        raise GovernorError(
            f"{label}_account_mismatch:expected={expected_login}:actual={login}"
        )
    valid_from = _parse_ts(policy.get("valid_from_utc"), f"{label}.valid_from_utc")
    valid_until = _parse_ts(policy.get("valid_until_utc"), f"{label}.valid_until_utc")
    if valid_until <= valid_from or now_utc < valid_from or now_utc > valid_until:
        raise GovernorError(f"{label}_outside_validity_window")
    return BoundPolicy(policy, resolved, actual)


def _ticket_inventory(
    rows: Any,
    declared_count: Any,
    label: str,
) -> tuple[list[dict[str, Any]], list[int], list[str]]:
    errors: list[str] = []
    if not isinstance(rows, list):
        return [], [], [f"{label}_inventory_missing"]
    try:
        expected = _positive_int(declared_count, f"{label}_count", allow_zero=True)
    except GovernorError as exc:
        return [], [], [str(exc)]
    if len(rows) != expected:
        errors.append(f"{label}_count_mismatch:declared={expected}:rows={len(rows)}")
    tickets: list[int] = []
    clean: list[dict[str, Any]] = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(f"{label}_row_not_object:{index}")
            continue
        try:
            ticket = _positive_int(row.get("ticket"), f"{label}[{index}].ticket")
        except GovernorError as exc:
            errors.append(str(exc))
            continue
        tickets.append(ticket)
        clean.append(row)
    duplicates = sorted({ticket for ticket in tickets if tickets.count(ticket) > 1})
    if duplicates:
        errors.append(f"{label}_duplicate_tickets:{duplicates}")
    return clean, tickets, errors


def analyze_snapshot(
    snapshot: dict[str, Any],
    *,
    now_utc: dt.datetime,
    max_age_seconds: float,
    expected_login: int | None = None,
) -> dict[str, Any]:
    uncertainties: list[str] = []
    if snapshot.get("schema") != SNAPSHOT_SCHEMA:
        uncertainties.append(
            f"snapshot_schema_not_v2:{snapshot.get('schema') or 'LEGACY_UNVERSIONED'}"
        )
    try:
        login = _positive_int(snapshot.get("account_login"), "account_login")
    except GovernorError as exc:
        login = 0
        uncertainties.append(str(exc))
    if expected_login is not None and login != expected_login:
        uncertainties.append(
            f"account_login_mismatch:expected={expected_login}:actual={login}"
        )

    try:
        observed_at = _parse_ts(snapshot.get("time_utc"), "snapshot.time_utc")
        age_seconds = (now_utc - observed_at).total_seconds()
        if age_seconds < -5:
            uncertainties.append(f"snapshot_from_future:age_seconds={age_seconds:.3f}")
        elif age_seconds > max_age_seconds:
            uncertainties.append(
                f"snapshot_stale:age_seconds={age_seconds:.3f}:max={max_age_seconds:.3f}"
            )
    except GovernorError as exc:
        observed_at = None
        age_seconds = None
        uncertainties.append(str(exc))

    metrics: dict[str, float | int | bool | dict[str, float]] = {}
    for key in ("equity", "balance", "free_margin", "margin"):
        try:
            metrics[key] = _finite(snapshot.get(key), key)
        except GovernorError as exc:
            metrics[key] = 0.0
            uncertainties.append(str(exc))
    if metrics["equity"] <= 0:
        uncertainties.append(f"equity_not_positive:{metrics['equity']}")
    if metrics["free_margin"] < 0:
        uncertainties.append(f"free_margin_negative:{metrics['free_margin']}")
    if snapshot.get("write_ok") is not True:
        uncertainties.append("snapshot_writer_not_ok")

    positions, position_tickets, position_errors = _ticket_inventory(
        snapshot.get("positions"), snapshot.get("open_positions"), "positions"
    )
    orders, order_tickets, order_errors = _ticket_inventory(
        snapshot.get("orders"), snapshot.get("pending_orders"), "orders"
    )
    uncertainties.extend(position_errors)
    uncertainties.extend(order_errors)
    if snapshot.get("reconciliation_complete") is not True:
        uncertainties.append("producer_reconciliation_incomplete")
    if snapshot.get("reconciled_positions") != len(positions):
        uncertainties.append("producer_reconciled_position_count_mismatch")
    if snapshot.get("reconciled_orders") != len(orders):
        uncertainties.append("producer_reconciled_order_count_mismatch")

    gross_notional = 0.0
    net_directional = 0.0
    planned_stop_loss = 0.0
    unpriced = 0
    uncovered = 0
    currency_net: dict[str, float] = {}
    recognized_positions: list[dict[str, Any]] = []
    for index, row in enumerate(positions):
        symbol = str(row.get("symbol") or "").strip().upper()
        side = str(row.get("type") or "").strip().upper()
        magic = row.get("magic")
        if not symbol or side not in {"BUY", "SELL"}:
            uncertainties.append(f"position_identity_invalid:{index}")
        try:
            _finite(row.get("volume"), f"positions[{index}].volume")
        except GovernorError as exc:
            uncertainties.append(str(exc))
        notional_ok = row.get("notional_account_ok") is True
        stop_ok = row.get("stop_loss_account_ok") is True
        try:
            signed_notional = _finite(
                row.get("signed_notional_account"),
                f"positions[{index}].signed_notional_account",
            )
        except GovernorError as exc:
            signed_notional = 0.0
            notional_ok = False
            uncertainties.append(str(exc))
        if notional_ok:
            gross_notional += abs(signed_notional)
            net_directional += signed_notional
            base = str(row.get("base_currency") or f"@SYMBOL:{symbol}").strip().upper()
            profit = str(row.get("profit_currency") or "@ACCOUNT").strip().upper()
            currency_net[base] = currency_net.get(base, 0.0) + signed_notional
            currency_net[profit] = currency_net.get(profit, 0.0) - signed_notional
        else:
            unpriced += 1
            uncertainties.append(f"position_notional_unpriced:{row.get('ticket')}")
        try:
            remaining_loss = _finite(
                row.get("remaining_loss_to_sl_account"),
                f"positions[{index}].remaining_loss_to_sl_account",
            )
        except GovernorError as exc:
            remaining_loss = 0.0
            stop_ok = False
            uncertainties.append(str(exc))
        if stop_ok and remaining_loss >= 0:
            planned_stop_loss += remaining_loss
        else:
            uncovered += 1
            uncertainties.append(f"position_stop_loss_uncovered:{row.get('ticket')}")
        recognized_positions.append(
            {
                "ticket": row.get("ticket"),
                "magic": magic,
                "symbol": symbol,
                "type": side,
                "included_independent_of_magic": True,
            }
        )

    equity = float(metrics.get("equity") or 0.0)
    metrics.update(
        {
            "gross_notional_account": round(gross_notional, 2),
            "net_directional_notional_account": round(net_directional, 2),
            "planned_stop_loss_account": round(planned_stop_loss, 2),
            "gross_leverage": round(gross_notional / equity, 8) if equity > 0 else 0.0,
            "net_directional_leverage": round(abs(net_directional) / equity, 8)
            if equity > 0
            else 0.0,
            "currency_net_account": {
                key: round(value, 2) for key, value in sorted(currency_net.items())
            },
            "max_abs_currency_net_leverage": round(
                max((abs(value) for value in currency_net.values()), default=0.0)
                / equity,
                8,
            )
            if equity > 0
            else 0.0,
            "unpriced_positions": unpriced,
            "positions_without_stop": uncovered,
            "recognized_position_count": len(recognized_positions),
            "recognized_order_count": len(orders),
        }
    )

    # Independently recompute and compare producer aggregates. Drift is an
    # uncertainty, never silently accepted.
    for key, derived in (
        ("gross_notional_account", gross_notional),
        ("net_directional_notional_account", net_directional),
        ("planned_stop_loss_account", planned_stop_loss),
    ):
        try:
            declared = _finite(snapshot.get(key), f"producer.{key}")
            tolerance = max(0.02, abs(derived) * 1e-6)
            if abs(declared - derived) > tolerance:
                uncertainties.append(
                    f"producer_metric_drift:{key}:declared={declared}:derived={derived}"
                )
        except GovernorError as exc:
            uncertainties.append(str(exc))

    return {
        "account_login": login,
        "snapshot_observed_at_utc": observed_at.isoformat() if observed_at else None,
        "snapshot_age_seconds": round(age_seconds, 3) if age_seconds is not None else None,
        "snapshot_fresh": not any(
            item.startswith(("snapshot_stale", "snapshot_from_future", "snapshot.time_utc"))
            for item in uncertainties
        ),
        "positions_reconciled": not position_errors
        and snapshot.get("reconciliation_complete") is True
        and snapshot.get("reconciled_positions") == len(positions),
        "orders_reconciled": not order_errors
        and snapshot.get("reconciliation_complete") is True
        and snapshot.get("reconciled_orders") == len(orders),
        "recognized_positions": recognized_positions,
        "recognized_position_tickets": position_tickets,
        "recognized_order_tickets": order_tickets,
        "metrics": metrics,
        "uncertainties": sorted(set(uncertainties)),
    }


def _policy_thresholds(policy: BoundPolicy) -> dict[str, float]:
    raw = policy.raw.get("thresholds")
    if not isinstance(raw, dict):
        raise GovernorError("policy_thresholds_missing")
    names = (
        "min_free_margin_account",
        "max_gross_leverage",
        "max_abs_currency_net_leverage",
        "max_planned_stop_loss_account",
    )
    values = {name: _finite(raw.get(name), f"policy.{name}") for name in names}
    if any(value < 0 for value in values.values()):
        raise GovernorError("policy_threshold_negative")
    if policy.raw.get("stage2_cancel_pending_authorized") is not True:
        raise GovernorError("policy_stage2_authorization_missing")
    return values


def evaluate(
    snapshot: dict[str, Any],
    *,
    now_utc: dt.datetime,
    expected_login: int | None,
    max_age_seconds: float,
    policy: BoundPolicy | None = None,
    emergency_policy: BoundPolicy | None = None,
) -> dict[str, Any]:
    analysis = analyze_snapshot(
        snapshot,
        now_utc=now_utc,
        max_age_seconds=max_age_seconds,
        expected_login=expected_login,
    )
    reasons: list[str] = []
    level = 0
    name = "CLEAR"
    thresholds: dict[str, float] | None = None
    policy_error: str | None = None
    if analysis["uncertainties"]:
        level = 1
        name = "ENTRY_FREEZE_UNCERTAINTY"
        reasons.extend(analysis["uncertainties"])
    elif policy is None:
        level = 1
        name = "ENTRY_FREEZE_POLICY_UNBOUND"
        reasons.append("owner_policy_not_bound")
    else:
        try:
            thresholds = _policy_thresholds(policy)
        except GovernorError as exc:
            level = 1
            name = "ENTRY_FREEZE_POLICY_INVALID"
            policy_error = str(exc)
            reasons.append(policy_error)

    breaches: list[str] = []
    if level == 0 and thresholds is not None:
        metrics = analysis["metrics"]
        checks = (
            (
                float(metrics["free_margin"]) < thresholds["min_free_margin_account"],
                "free_margin_below_floor",
            ),
            (
                float(metrics["gross_leverage"]) > thresholds["max_gross_leverage"],
                "gross_leverage_above_ceiling",
            ),
            (
                float(metrics["max_abs_currency_net_leverage"])
                > thresholds["max_abs_currency_net_leverage"],
                "currency_net_leverage_above_ceiling",
            ),
            (
                float(metrics["planned_stop_loss_account"])
                > thresholds["max_planned_stop_loss_account"],
                "planned_stop_loss_above_ceiling",
            ),
        )
        breaches = [reason for breached, reason in checks if breached]
        if breaches:
            level = 2
            name = "PENDING_CANCEL_AND_ENTRY_FREEZE"
            reasons.extend(breaches)

    emergency_error: str | None = None
    if level == 2 and emergency_policy is not None:
        emergency = emergency_policy.raw
        if emergency.get("flatten_authorized") is not True:
            emergency_error = "emergency_policy_flatten_not_authorized"
        elif policy is None or emergency.get("trigger_policy_sha256") != policy.sha256:
            emergency_error = "emergency_policy_trigger_binding_mismatch"
        elif not str(emergency.get("incident_id") or "").strip():
            emergency_error = "emergency_policy_incident_id_missing"
        else:
            level = 3
            name = "CONTROLLED_FLATTEN_AUTHORIZED_DRY_RUN"
            reasons.append("owner_emergency_policy_bound")
        if emergency_error:
            reasons.append(emergency_error)

    action_plan = {
        "entry_freeze": level >= 1,
        "would_cancel_pending_order_tickets": analysis["recognized_order_tickets"]
        if level >= 2
        else [],
        "would_flatten_position_tickets": analysis["recognized_position_tickets"]
        if level >= 3
        else [],
        "actions_executed": [],
    }
    return {
        "schema": OUTPUT_SCHEMA,
        "generated_at_utc": now_utc.isoformat(),
        "dry_run": True,
        "execution_adapter_present": False,
        "decision": {"level": level, "name": name, "reasons": sorted(set(reasons))},
        "analysis": analysis,
        "policy_binding": {
            "bound": policy is not None,
            "path": str(policy.path) if policy else None,
            "sha256": policy.sha256 if policy else None,
            "error": policy_error,
        },
        "emergency_policy_binding": {
            "bound": emergency_policy is not None,
            "path": str(emergency_policy.path) if emergency_policy else None,
            "sha256": emergency_policy.sha256 if emergency_policy else None,
            "error": emergency_error,
        },
        "thresholds": thresholds,
        "breaches": breaches,
        "action_plan": action_plan,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT)
    parser.add_argument("--expected-login", type=int)
    parser.add_argument("--max-age-seconds", type=float, default=90.0)
    parser.add_argument("--policy", type=Path)
    parser.add_argument("--trusted-policy-sha256")
    parser.add_argument("--emergency-policy", type=Path)
    parser.add_argument("--trusted-emergency-sha256")
    parser.add_argument("--now-utc")
    parser.add_argument(
        "--dry-run", action="store_true", help="Required acknowledgement; no apply mode exists."
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if not args.dry_run:
        print(
            json.dumps(
                {
                    "schema": OUTPUT_SCHEMA,
                    "status": "ERROR",
                    "reason": "dry_run_acknowledgement_required_no_apply_mode_exists",
                },
                indent=2,
            )
        )
        return 2
    try:
        now_utc = _parse_ts(args.now_utc, "now_utc") if args.now_utc else _now_utc()
        snapshot = _read_json(args.snapshot.resolve(), "snapshot")
        login = args.expected_login
        if login is None:
            login = _positive_int(snapshot.get("account_login"), "account_login")
        policy = None
        if args.policy is not None:
            policy = _load_bound_policy(
                args.policy,
                args.trusted_policy_sha256,
                schema=POLICY_SCHEMA,
                now_utc=now_utc,
                expected_login=login,
                label="policy",
            )
        emergency = None
        if args.emergency_policy is not None:
            emergency = _load_bound_policy(
                args.emergency_policy,
                args.trusted_emergency_sha256,
                schema=EMERGENCY_SCHEMA,
                now_utc=now_utc,
                expected_login=login,
                label="emergency_policy",
            )
        result = evaluate(
            snapshot,
            now_utc=now_utc,
            expected_login=login,
            max_age_seconds=args.max_age_seconds,
            policy=policy,
            emergency_policy=emergency,
        )
    except Exception as exc:
        print(
            json.dumps(
                {
                    "schema": OUTPUT_SCHEMA,
                    "status": "ERROR",
                    "error_type": type(exc).__name__,
                    "reason": str(exc),
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
