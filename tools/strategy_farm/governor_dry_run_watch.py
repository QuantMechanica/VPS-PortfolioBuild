"""Recurring dry-run watcher for the account/portfolio governor (SP-C6).

SP-C1 (`account_portfolio_governor.py`) is a pure, stateless evaluator: given
one snapshot (+ optional OWNER-bound policies) it returns one escalation
decision and never persists anything. That proved the staged decision logic
in isolation but left two gaps a *single* dry run cannot show:

1. Alarm: nothing observes level transitions over time, so a freeze or a
   stage-2/3 escalation would produce a JSON blob on stdout and nothing else.
2. Recovery: nothing records that the evaluator naturally returns to a lower
   level once the underlying condition clears (it is a pure function of the
   current snapshot, so "recovery" here means the next run's level drops --
   there is no sticky latch to unlock, unlike ``live_book_dd_guard.py``).

This script re-evaluates the governor on every invocation (intended cadence:
a scheduled task, mirroring ``QM_StrategyFarm_LiveBookDDGuard``), diffs the
new decision level against the previous run's persisted level, and:

- appends every full decision to an append-only JSONL history (durable
  evidence that every recognized position/order ticket was detected on every
  run, per the Hard Rule that evidence needs a log path, not a claim);
- writes one line to a plain-text run log on every invocation (steady-state
  visibility, matching the guard-log convention); and
- appends one entry to the shared ``health_alarms.log`` only on a level
  *increase* (ALARM) or *decrease* (RECOVERY) -- unchanged steady state
  (typically level 1, ``ENTRY_FREEZE_POLICY_UNBOUND``, until OWNER binds a
  policy) never spams the alarm log.

Safety boundary (unchanged from SP-C1): this script never connects to MT5,
never sends/deletes/closes an order, never toggles AutoTrading, and has no
apply mode -- ``action_plan.actions_executed`` from the governor is always
``[]``. Stage 3 (controlled flatten) still requires the governor's own
independently hash-bound, time-limited OWNER emergency policy; this watcher
adds no new authority and does not change ``evaluate()``.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

try:
    from tools.strategy_farm import account_portfolio_governor as governor
except ImportError:  # running as a standalone script (sys.path[0] == this dir)
    import account_portfolio_governor as governor  # type: ignore[no-redef]

STATE_JSON = Path(r"D:\QM\reports\state\governor_dry_run_watch_state.json")
GUARD_LOG = Path(r"D:\QM\reports\state\governor_dry_run_watch.log")
ALARM_LOG = Path(r"D:\QM\strategy_farm\state\health_alarms.log")
HISTORY_JSONL = Path(r"D:\QM\reports\state\governor_dry_run_watch_history.jsonl")

SOURCE = "governor_dry_run_watch"


def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def _log(msg: str) -> None:
    GUARD_LOG.parent.mkdir(parents=True, exist_ok=True)
    with GUARD_LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"{_now_utc().replace(microsecond=0).isoformat()} {msg}\n")


def _alarm(severity: str, detail: str) -> None:
    try:
        ALARM_LOG.parent.mkdir(parents=True, exist_ok=True)
        with ALARM_LOG.open("a", encoding="utf-8") as fh:
            fh.write(
                json.dumps(
                    {
                        "ts_utc": _now_utc().replace(microsecond=0).isoformat(),
                        "source": SOURCE,
                        "severity": severity,
                        "detail": detail,
                    }
                )
                + "\n"
            )
    except OSError:
        pass


def _append_history(result: dict[str, Any]) -> None:
    HISTORY_JSONL.parent.mkdir(parents=True, exist_ok=True)
    with HISTORY_JSONL.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(result, sort_keys=True) + "\n")


def _load_state() -> dict[str, Any]:
    try:
        return json.loads(STATE_JSON.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _save_state(state: dict[str, Any]) -> None:
    STATE_JSON.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_JSON.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=1, sort_keys=True), encoding="utf-8")
    tmp.replace(STATE_JSON)


def _severity_for_level(level: int) -> str:
    if level >= 3:
        return "CRITICAL"
    if level >= 2:
        return "WARN"
    return "INFO"


def run_once(
    *,
    snapshot_path: Path,
    expected_login: int | None,
    max_age_seconds: float,
    policy_path: Path | None,
    trusted_policy_sha256: str | None,
    emergency_policy_path: Path | None,
    trusted_emergency_sha256: str | None,
    now_utc: dt.datetime,
    prior_state: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Evaluate one governor decision and produce the updated watch state.

    Never raises: any load/parse failure downgrades to a level-1 uncertainty
    decision instead of crashing the recurring caller (fail closed, always
    emit a decision -- mirrors ``live_book_dd_guard``'s BLIND handling).
    """
    try:
        snapshot = governor._read_json(snapshot_path.resolve(), "snapshot")
        login = expected_login
        if login is None:
            login = governor._positive_int(snapshot.get("account_login"), "account_login")
        policy = None
        if policy_path is not None:
            policy = governor._load_bound_policy(
                policy_path,
                trusted_policy_sha256,
                schema=governor.POLICY_SCHEMA,
                now_utc=now_utc,
                expected_login=login,
                label="policy",
            )
        emergency = None
        if emergency_policy_path is not None:
            emergency = governor._load_bound_policy(
                emergency_policy_path,
                trusted_emergency_sha256,
                schema=governor.EMERGENCY_SCHEMA,
                now_utc=now_utc,
                expected_login=login,
                label="emergency_policy",
            )
        result = governor.evaluate(
            snapshot,
            now_utc=now_utc,
            expected_login=login,
            max_age_seconds=max_age_seconds,
            policy=policy,
            emergency_policy=emergency,
        )
    except Exception as exc:  # noqa: BLE001 - fail closed, never crash the watcher
        result = {
            "schema": governor.OUTPUT_SCHEMA,
            "generated_at_utc": now_utc.isoformat(),
            "dry_run": True,
            "execution_adapter_present": False,
            "decision": {
                "level": 1,
                "name": "ENTRY_FREEZE_WATCHER_ERROR",
                "reasons": [f"{type(exc).__name__}:{exc}"],
            },
            "analysis": {
                "recognized_positions": [],
                "recognized_position_tickets": [],
                "recognized_order_tickets": [],
                "uncertainties": [f"watcher_error:{type(exc).__name__}:{exc}"],
            },
            "policy_binding": {"bound": False, "path": None, "sha256": None, "error": None},
            "emergency_policy_binding": {
                "bound": False,
                "path": None,
                "sha256": None,
                "error": None,
            },
            "thresholds": None,
            "breaches": [],
            "action_plan": {
                "entry_freeze": True,
                "would_cancel_pending_order_tickets": [],
                "would_flatten_position_tickets": [],
                "actions_executed": [],
            },
        }

    level = int(result["decision"]["level"])
    name = str(result["decision"]["name"])
    prior_level = prior_state.get("last_level")
    position_tickets = list(result["analysis"].get("recognized_position_tickets") or [])
    order_tickets = list(result["analysis"].get("recognized_order_tickets") or [])

    transition = None
    if prior_level is not None and level != int(prior_level):
        transition = "ALARM" if level > int(prior_level) else "RECOVERY"

    detail = (
        f"level={level}:{name} prior_level={prior_level} "
        f"positions={len(position_tickets)} orders={len(order_tickets)} "
        f"uncertainties={len(result['analysis'].get('uncertainties') or [])}"
    )
    if transition == "ALARM":
        _alarm(_severity_for_level(level), f"level_increase:{detail}")
    elif transition == "RECOVERY":
        _alarm("INFO", f"level_decrease:{detail}")

    _log(
        f"{transition or 'STEADY'} {detail} "
        f"entry_freeze={result['action_plan']['entry_freeze']} "
        f"actions_executed={result['action_plan']['actions_executed']}"
    )
    _append_history(result)

    run_count = int(prior_state.get("run_count") or 0) + 1
    alarm_count = int(prior_state.get("alarm_count") or 0) + (1 if transition == "ALARM" else 0)
    recovery_count = int(prior_state.get("recovery_count") or 0) + (
        1 if transition == "RECOVERY" else 0
    )
    new_state = {
        "last_level": level,
        "last_level_name": name,
        "last_transition": transition,
        "last_position_tickets": position_tickets,
        "last_order_tickets": order_tickets,
        "last_run_utc": now_utc.replace(microsecond=0).isoformat(),
        "run_count": run_count,
        "alarm_count": alarm_count,
        "recovery_count": recovery_count,
    }
    return result, new_state


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
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Required acknowledgement; this watcher has no apply mode.",
    )
    parser.add_argument("--status", action="store_true", help="Print persisted state and exit.")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.status:
        print(json.dumps(_load_state(), indent=2, sort_keys=True))
        return 0
    if not args.dry_run:
        print(
            json.dumps(
                {
                    "schema": governor.OUTPUT_SCHEMA,
                    "status": "ERROR",
                    "reason": "dry_run_acknowledgement_required_no_apply_mode_exists",
                },
                indent=2,
            )
        )
        return 2

    now_utc = governor._parse_ts(args.now_utc, "now_utc") if args.now_utc else _now_utc()
    prior_state = _load_state()
    result, new_state = run_once(
        snapshot_path=args.snapshot,
        expected_login=args.expected_login,
        max_age_seconds=args.max_age_seconds,
        policy_path=args.policy,
        trusted_policy_sha256=args.trusted_policy_sha256,
        emergency_policy_path=args.emergency_policy,
        trusted_emergency_sha256=args.trusted_emergency_sha256,
        now_utc=now_utc,
        prior_state=prior_state,
    )
    _save_state(new_state)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
