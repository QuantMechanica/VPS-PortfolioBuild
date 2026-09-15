#!/usr/bin/env python3
"""QuantMechanica - Kimi (Kimi Code CLI) subscription / quota governor.

Kimi is a USD-99 one-month subscription (OWNER 2026-09-15). There is NO
programmatic usage endpoint on the CLI (audit kimi_cli.md sec6), so - unlike the
agy governor which pulls a live remaining-fraction - this governor derives state
purely from the LOCAL usage ledger the adapter writes on every call
(D:/QM/reports/state/kimi_usage_ledger.jsonl, schema qm.kimi-usage/v1). That
uncertainty is surfaced honestly: the state JSON carries
``usage_source: "local_ledger_only"`` unless a real usage snapshot was captured
(none exists today - the CLI never prints one).

States (NORMAL / CONSERVE / EXHAUSTED):
  NORMAL     - within caps; Kimi routable for all its capabilities.
  CONSERVE   - >= conserve_pct of the daily OR weekly call cap, or the
               subscription period is within N days of its end. Only the
               high-value research capabilities stay allowed
               (edge_discovery / hypothesis_authoring /
               cross_experiment_analysis / research_critic); generic
               research_strategy/summary work falls back to cheaper lanes so a
               fixed one-month budget is not drained on low-value volume.
  EXHAUSTED  - a call cap is hit (100%), OR two consecutive rate_limited /
               auth_expired statuses, OR a cli_missing status, OR the
               subscription period has ended. No capabilities allowed.

Flag (honored by both router and chain planes once they are wired):
  D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag  (written on EXHAUSTED)
Ownership-tracked exactly like quota_governor.py: the flag body's first line is
``MANAGED_BY=kimi_governor``; the governor only clears a flag carrying THAT
marker, never one another owner set.

  python kimi_governor.py status      # print state JSON (no writes)
  python kimi_governor.py evaluate    # recompute + reconcile the flag

The adapter calls ``record()`` after appending each ledger line; a future
15-min scheduled task calls ``evaluate()``.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

# --------------------------------------------------------------------------- config

_CONFIG_PATH = Path(__file__).with_name("config") / "kimi_adapter.v1.json"


def load_config(path: Path | str = _CONFIG_PATH) -> dict[str, Any]:
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    if cfg.get("schema") != "qm.kimi-adapter.v1":
        raise ValueError(f"unexpected kimi adapter config schema: {cfg.get('schema')!r}")
    return cfg


def governor_config(cfg: dict[str, Any] | None = None) -> dict[str, Any]:
    cfg = cfg or load_config()
    gov = dict(cfg.get("governor") or {})
    # Sensible fallbacks so the governor never crashes on a partial config.
    gov.setdefault("ledger_path", cfg.get("ledger_path", "D:/QM/reports/state/kimi_usage_ledger.jsonl"))
    gov.setdefault("flag_path", "D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag")
    gov.setdefault("state_path", "D:/QM/reports/state/kimi_governor_state.json")
    gov.setdefault("log_path", "D:/QM/reports/state/kimi_governor.log")
    gov.setdefault("managed_by", "kimi_governor")
    gov.setdefault("caps", {"day": 40, "week": 200})
    gov.setdefault("conserve_pct", 70)
    gov.setdefault("consecutive_fail_threshold", 2)
    gov.setdefault("consecutive_fail_statuses", ["rate_limited", "auth_expired"])
    gov.setdefault(
        "conserve_allowed_capabilities",
        ["edge_discovery", "hypothesis_authoring", "cross_experiment_analysis", "research_critic"],
    )
    gov.setdefault("subscription_period", cfg.get("subscription_period") or {})
    gov.setdefault("period_conserve_days_before_end", 3)
    return gov


# --------------------------------------------------------------------------- helpers

def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _parse_ts(value: Any) -> dt.datetime | None:
    if not value:
        return None
    try:
        x = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return x if x.tzinfo else x.replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None


def _parse_date(value: Any) -> dt.date | None:
    if not value:
        return None
    try:
        return dt.date.fromisoformat(str(value)[:10])
    except Exception:
        return None


def read_ledger(ledger_path: Path | str) -> list[dict[str, Any]]:
    """Return every well-formed JSON line; tolerate a truncated/garbage line."""
    path = Path(ledger_path)
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if isinstance(obj, dict):
            rows.append(obj)
    return rows


def _log(gov: dict[str, Any], msg: str) -> None:
    line = f"{_now().strftime('%Y-%m-%dT%H:%M:%SZ')} {msg}"
    print(line)
    try:
        log_path = Path(gov["log_path"])
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception:
        pass


# --------------------------------------------------------------------------- state derivation

def compute_state(
    rows: list[dict[str, Any]],
    gov: dict[str, Any],
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Derive NORMAL / CONSERVE / EXHAUSTED from the ledger rows. Pure function."""
    now = now or _now()
    caps = gov.get("caps") or {"day": 40, "week": 200}
    cap_day = int(caps.get("day", 40))
    cap_week = int(caps.get("week", 200))
    conserve_pct = float(gov.get("conserve_pct", 70))
    fail_statuses = set(gov.get("consecutive_fail_statuses") or ["rate_limited", "auth_expired"])
    fail_threshold = int(gov.get("consecutive_fail_threshold", 2))

    day_start = now - dt.timedelta(days=1)
    week_start = now - dt.timedelta(days=7)

    calls_day = 0
    calls_week = 0
    dated: list[tuple[dt.datetime, str]] = []
    any_usage_snapshot = False
    for r in rows:
        ts = _parse_ts(r.get("ts_utc") or r.get("ts"))
        status = str(r.get("status") or "")
        if r.get("usage") not in (None, {}, ""):
            any_usage_snapshot = True
        if ts is None:
            continue
        dated.append((ts, status))
        if ts >= week_start:
            calls_week += 1
        if ts >= day_start:
            calls_day += 1

    dated.sort(key=lambda t: t[0])
    # consecutive failures at the tail of the ledger
    tail_fail_streak = 0
    for _ts, status in reversed(dated):
        if status in fail_statuses:
            tail_fail_streak += 1
        else:
            break
    last_statuses = [s for _ts, s in dated[-5:]]
    saw_cli_missing = bool(dated) and dated[-1][1] == "cli_missing"

    day_pct = (calls_day / cap_day * 100.0) if cap_day else 0.0
    week_pct = (calls_week / cap_week * 100.0) if cap_week else 0.0

    # subscription-period awareness (the boundary is a known, measurable date).
    period = gov.get("subscription_period") or {}
    period_start = _parse_date(period.get("start"))
    period_end = _parse_date(period.get("end"))
    days_before = int(gov.get("period_conserve_days_before_end", 3))
    period_ended = bool(period_end and now.date() > period_end)
    period_near_end = bool(period_end and not period_ended
                           and (period_end - now.date()).days <= days_before)

    reasons: list[str] = []
    state = "NORMAL"

    # EXHAUSTED conditions (any one).
    if calls_day >= cap_day:
        state = "EXHAUSTED"
        reasons.append(f"daily cap hit ({calls_day}/{cap_day})")
    if calls_week >= cap_week:
        state = "EXHAUSTED"
        reasons.append(f"weekly cap hit ({calls_week}/{cap_week})")
    if tail_fail_streak >= fail_threshold:
        state = "EXHAUSTED"
        reasons.append(f"{tail_fail_streak} consecutive {'/'.join(sorted(fail_statuses))} statuses")
    if saw_cli_missing:
        state = "EXHAUSTED"
        reasons.append("last status cli_missing")
    if period_ended:
        state = "EXHAUSTED"
        reasons.append(f"subscription period ended {period_end.isoformat()}")

    # CONSERVE conditions (only if not already EXHAUSTED).
    if state != "EXHAUSTED":
        if day_pct >= conserve_pct or week_pct >= conserve_pct:
            state = "CONSERVE"
            reasons.append(
                f"approaching cap (day {day_pct:.0f}%, week {week_pct:.0f}% >= {conserve_pct:.0f}%)"
            )
        if period_near_end:
            state = "CONSERVE"
            reasons.append(f"subscription period ends {period_end.isoformat()} (<= {days_before}d)")

    if not reasons:
        reasons.append("within caps")

    return {
        "state": state,
        "counts": {"day": calls_day, "week": calls_week},
        "caps": {"day": cap_day, "week": cap_week},
        "pct": {"day": round(day_pct, 1), "week": round(week_pct, 1)},
        "last_statuses": last_statuses,
        "consecutive_fail_streak": tail_fail_streak,
        "subscription_period": {
            "start": period_start.isoformat() if period_start else None,
            "end": period_end.isoformat() if period_end else None,
            "ended": period_ended,
            "near_end": period_near_end,
        },
        "usage_source": "local_ledger_only" if not any_usage_snapshot else "usage_snapshot",
        "reasons": reasons,
        "computed_at": now.isoformat(),
    }


# --------------------------------------------------------------------------- capability policy

def allowed_capabilities(state: str, gov: dict[str, Any] | None = None) -> list[str] | None:
    """Capabilities Kimi may serve in the given state.

    NORMAL   -> None  (unrestricted; all declared capabilities allowed)
    CONSERVE -> only the high-value research capabilities
    EXHAUSTED-> []    (none)
    """
    gov = gov or governor_config()
    if state == "NORMAL":
        return None
    if state == "CONSERVE":
        return list(gov.get("conserve_allowed_capabilities") or [])
    return []


# --------------------------------------------------------------------------- flag reconciliation

def _flag_owned(flag: Path, managed_by: str) -> bool:
    try:
        first = flag.read_text(encoding="utf-8").splitlines()[0].strip()
    except Exception:
        return False
    return first == f"MANAGED_BY={managed_by}"


def _write_flag(flag: Path, managed_by: str, reason: str, state_info: dict[str, Any]) -> None:
    flag.parent.mkdir(parents=True, exist_ok=True)
    body = (
        f"MANAGED_BY={managed_by}\n"
        f"set_at={_now().strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
        f"reason={reason}\n"
        f"counts=day {state_info['counts']['day']}/{state_info['caps']['day']}, "
        f"week {state_info['counts']['week']}/{state_info['caps']['week']}\n"
    )
    flag.write_text(body, encoding="utf-8")


def reconcile_flag(state_info: dict[str, Any], gov: dict[str, Any], *, dry_run: bool = False) -> dict[str, Any]:
    """Write the flag on EXHAUSTED, clear it otherwise - but only ever touch a
    flag this governor owns (MANAGED_BY marker). Returns the flag action taken."""
    flag = Path(gov["flag_path"])
    managed_by = gov.get("managed_by", "kimi_governor")
    state = state_info["state"]
    exists = flag.exists()
    owned = _flag_owned(flag, managed_by) if exists else False
    reason = "; ".join(state_info.get("reasons") or [])

    action = "noop"
    if state == "EXHAUSTED":
        if not exists:
            action = "SET"
            if not dry_run:
                _write_flag(flag, managed_by, reason, state_info)
        elif owned:
            action = "hold"
        else:
            action = "leave-external"  # someone else owns this flag; never overwrite
    else:  # NORMAL / CONSERVE -> the flag (a hard lane-disable) should not be present
        if exists and owned:
            action = "CLEAR"
            if not dry_run:
                try:
                    flag.unlink()
                except Exception:
                    action = "clear-failed"
        elif exists:
            action = "leave-external"
        else:
            action = "noop"

    return {"action": action, "flag_path": str(flag), "owned": owned, "existed": exists}


# --------------------------------------------------------------------------- public API

def evaluate(cfg: dict[str, Any] | None = None, *, dry_run: bool = False,
             now: dt.datetime | None = None) -> dict[str, Any]:
    """Recompute state from the ledger and reconcile the flag."""
    cfg = cfg or load_config()
    gov = governor_config(cfg)
    rows = read_ledger(gov["ledger_path"])
    state_info = compute_state(rows, gov, now=now)
    state_info["allowed_capabilities"] = allowed_capabilities(state_info["state"], gov)
    flag_action = reconcile_flag(state_info, gov, dry_run=dry_run)
    state_info["flag"] = flag_action
    if not dry_run:
        try:
            state_path = Path(gov["state_path"])
            state_path.parent.mkdir(parents=True, exist_ok=True)
            state_path.write_text(json.dumps(state_info, indent=2), encoding="utf-8")
        except Exception:
            pass
        _log(gov, f"state={state_info['state']} day={state_info['counts']['day']}/"
                  f"{state_info['caps']['day']} week={state_info['counts']['week']}/"
                  f"{state_info['caps']['week']} flag={flag_action['action']} "
                  f"({'; '.join(state_info['reasons'])})")
    return state_info


def record(entry: dict[str, Any] | None = None, cfg: dict[str, Any] | None = None) -> dict[str, Any]:
    """Called by the adapter AFTER it appended a ledger line. Recomputes state
    and reconciles the flag. ``entry`` is accepted for interface symmetry and
    forward compatibility (a future usage snapshot) but state is always derived
    from the durable ledger, never from this single in-memory line."""
    return evaluate(cfg=cfg, dry_run=False)


# --------------------------------------------------------------------------- CLI

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("command", choices=["status", "evaluate"], nargs="?", default="status")
    ap.add_argument("--config", default=str(_CONFIG_PATH))
    args = ap.parse_args(argv)
    cfg = load_config(args.config)
    if args.command == "status":
        info = evaluate(cfg, dry_run=True)
        print(json.dumps(info, indent=2))
        return 0
    info = evaluate(cfg, dry_run=False)
    print(json.dumps(info, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
