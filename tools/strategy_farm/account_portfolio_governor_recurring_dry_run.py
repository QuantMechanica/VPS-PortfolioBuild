#!/usr/bin/env python3
"""Recurring kill-switch/recovery dry-run wrapper around the account governor.

SP-C1 (`account_portfolio_governor.py`) proved the *design*: a single dry-run
invocation reconciles every open position independent of magic, and staged
escalation (entry-freeze -> pending-cancel -> controlled-flatten) requires
increasingly strong OWNER authorization. SP-C6 proves the *operating
property*: run that evaluator on a recurring cadence and show, from an
append-only history rather than a single sample, that (a) every active
position keeps being detected across runs, (b) an alarm is raised the moment
the decision level rises above CLEAR, (c) a level-2+ decision always lists a
concrete freeze/cancel plan, and (d) the system recovers to CLEAR on its own
once the underlying condition clears -- with no persisted breach latch to
reset, because each run is independently derived from that run's own
snapshot.

This module is dry-run-only, like its dependency: no order is sent, deleted,
or closed; no AutoTrading state is touched; no signal file is written. The
only side effects are two append-only local files: the JSONL run journal and
the shared `health_alarms.log` (reused from `live_book_dd_guard.py`'s
convention) when the decision level is above CLEAR.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import account_portfolio_governor as governor

RECORD_SCHEMA = "qm.account-governor.recurring-dry-run-record/v1"
DEFAULT_JOURNAL = Path(
    r"D:\QM\reports\state\account_portfolio_governor_recurring_dry_run.jsonl"
)
ALARM_LOG = Path(r"D:\QM\strategy_farm\state\health_alarms.log")

_LEVEL_SEVERITY = {
    0: None,  # CLEAR: no alarm
    1: "WARN",
    2: "WARN",
    3: "CRITICAL",
}


def build_record(
    snapshot: dict[str, Any],
    *,
    now_utc: dt.datetime,
    expected_login: int | None,
    max_age_seconds: float,
    policy: governor.BoundPolicy | None = None,
    emergency_policy: governor.BoundPolicy | None = None,
) -> dict[str, Any]:
    """Pure function: one governor evaluation -> one compact journal record.

    Contains no file I/O so it is directly testable and so the recurring
    property (append-only history, no residual state) is provable from
    records alone rather than from side effects.
    """
    result = governor.evaluate(
        snapshot,
        now_utc=now_utc,
        expected_login=expected_login,
        max_age_seconds=max_age_seconds,
        policy=policy,
        emergency_policy=emergency_policy,
    )
    decision = result["decision"]
    analysis = result["analysis"]
    return {
        "schema": RECORD_SCHEMA,
        "run_at_utc": now_utc.isoformat(),
        "decision_level": decision["level"],
        "decision_name": decision["name"],
        "reasons": decision["reasons"],
        "recognized_position_tickets": analysis["recognized_position_tickets"],
        "recognized_order_tickets": analysis["recognized_order_tickets"],
        "positions_reconciled": analysis["positions_reconciled"],
        "orders_reconciled": analysis["orders_reconciled"],
        "would_cancel_pending_order_tickets": result["action_plan"][
            "would_cancel_pending_order_tickets"
        ],
        "would_flatten_position_tickets": result["action_plan"][
            "would_flatten_position_tickets"
        ],
        "actions_executed": result["action_plan"]["actions_executed"],
        "dry_run": result["dry_run"],
        "execution_adapter_present": result["execution_adapter_present"],
        "policy_bound": result["policy_binding"]["bound"],
        "emergency_policy_bound": result["emergency_policy_binding"]["bound"],
    }


def alarm_line(record: dict[str, Any]) -> str | None:
    """Return the alarm-log line for this record, or None if level is CLEAR."""
    severity = _LEVEL_SEVERITY.get(record["decision_level"])
    if severity is None:
        return None
    return (
        f"{record['run_at_utc']} {severity} account_portfolio_governor_recurring_dry_run "
        f"level={record['decision_level']} name={record['decision_name']} "
        f"positions={len(record['recognized_position_tickets'])} "
        f"would_cancel={len(record['would_cancel_pending_order_tickets'])} "
        f"would_flatten={len(record['would_flatten_position_tickets'])}"
    )


def append_journal(record: dict[str, Any], journal_path: Path) -> None:
    journal_path.parent.mkdir(parents=True, exist_ok=True)
    with journal_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def append_alarm(record: dict[str, Any], alarm_log: Path) -> None:
    line = alarm_line(record)
    if line is None:
        return
    alarm_log.parent.mkdir(parents=True, exist_ok=True)
    with alarm_log.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--snapshot", type=Path, default=governor.DEFAULT_SNAPSHOT)
    parser.add_argument("--expected-login", type=int)
    parser.add_argument("--max-age-seconds", type=float, default=90.0)
    parser.add_argument("--policy", type=Path)
    parser.add_argument("--trusted-policy-sha256")
    parser.add_argument("--emergency-policy", type=Path)
    parser.add_argument("--trusted-emergency-sha256")
    parser.add_argument("--now-utc")
    parser.add_argument("--journal-path", type=Path, default=DEFAULT_JOURNAL)
    parser.add_argument("--alarm-log", type=Path, default=ALARM_LOG)
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
                    "schema": RECORD_SCHEMA,
                    "status": "ERROR",
                    "reason": "dry_run_acknowledgement_required_no_apply_mode_exists",
                },
                indent=2,
            )
        )
        return 2
    try:
        now_utc = (
            governor._parse_ts(args.now_utc, "now_utc") if args.now_utc else governor._now_utc()
        )
        snapshot = governor._read_json(args.snapshot.resolve(), "snapshot")
        login = args.expected_login
        if login is None:
            login = governor._positive_int(snapshot.get("account_login"), "account_login")
        policy = None
        if args.policy is not None:
            policy = governor._load_bound_policy(
                args.policy,
                args.trusted_policy_sha256,
                schema=governor.POLICY_SCHEMA,
                now_utc=now_utc,
                expected_login=login,
                label="policy",
            )
        emergency = None
        if args.emergency_policy is not None:
            emergency = governor._load_bound_policy(
                args.emergency_policy,
                args.trusted_emergency_sha256,
                schema=governor.EMERGENCY_SCHEMA,
                now_utc=now_utc,
                expected_login=login,
                label="emergency_policy",
            )
        record = build_record(
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
                    "schema": RECORD_SCHEMA,
                    "status": "ERROR",
                    "error_type": type(exc).__name__,
                    "reason": str(exc),
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2
    append_journal(record, args.journal_path)
    append_alarm(record, args.alarm_log)
    print(json.dumps(record, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
