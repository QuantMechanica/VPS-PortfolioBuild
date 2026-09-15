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

Flag (honored by both router and chain planes):
  D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag  (written on CONSERVE **and** EXHAUSTED)
The flag body is a JSON object (schema ``qm.kimi-low-quota-flag/v1``) carrying the
computed ``state`` so both consumers (agent_router.kimi_quota_state, JSON-only, and
agent_chain._read_kimi_flag_state) learn CONSERVE as well as EXHAUSTED - the earlier
key=value body only ever reached EXHAUSTED by the routers' fail-closed accident and
silently discarded CONSERVE (review finding F1, 2026-09-15).
Ownership-tracked exactly like quota_governor.py: the JSON body carries
``managed_by: kimi_governor``; the governor only clears/rewrites a flag carrying THAT
marker, never one another owner set. ``_flag_owned`` still tolerates the legacy
first-line ``MANAGED_BY=kimi_governor`` key=value body so an in-flight upgrade is safe.

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

# One canonical flag-body schema written by the governor and parsed by both planes.
FLAG_SCHEMA = "qm.kimi-low-quota-flag/v1"


def load_config(path: Path | str = _CONFIG_PATH) -> dict[str, Any]:
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    if cfg.get("schema") != "qm.kimi-adapter.v1":
        raise ValueError(f"unexpected kimi adapter config schema: {cfg.get('schema')!r}")
    return cfg


# Default real-telemetry thresholds (directive OWNER-DEC-CBE-20260915 sec33; the
# authoritative, OWNER/Fable-adjustable values live in kimi_quota_fetcher.v1.json).
DEFAULT_REAL_THRESHOLDS = {
    "conserve_window_ratio": 0.80,
    "conserve_monthly_ratio": 0.85,
    "exhausted_window_ratio": 0.98,
}
# Runaway/anomaly guard defaults (directive sec33): raised well above the old 40/200
# rollout caps so they cannot bind before the real subscription telemetry does, while
# still stopping a runaway loop. These are NOT contractual limits.
DEFAULT_RUNAWAY_GUARD = {"day": 120, "week": 600}
DEFAULT_MAX_STATE_AGE_S = 1800  # 2x the 15-min governor cadence (directive freshness rule)


def governor_config(cfg: dict[str, Any] | None = None) -> dict[str, Any]:
    cfg = cfg or load_config()
    raw = dict(cfg.get("governor") or {})
    gov = dict(raw)
    # Sensible fallbacks so the governor never crashes on a partial config.
    gov.setdefault("ledger_path", cfg.get("ledger_path", "D:/QM/reports/state/kimi_usage_ledger.jsonl"))
    gov.setdefault("flag_path", "D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag")
    gov.setdefault("state_path", "D:/QM/reports/state/kimi_governor_state.json")
    gov.setdefault("log_path", "D:/QM/reports/state/kimi_governor.log")
    gov.setdefault("managed_by", "kimi_governor")
    # Runaway guard (formerly "caps"): directive sec33 renamed the local 40/200 call
    # caps into anomaly/runaway-loop protection only. We honour an explicit
    # ``runaway_guard`` first, then the legacy ``caps`` key (back-compat / existing
    # tests), then the raised default. ``caps`` stays as an alias so any older reader
    # keeps working.
    guard_user_specified = ("runaway_guard" in raw) or ("caps" in raw)
    guard = raw.get("runaway_guard") or raw.get("caps") or dict(DEFAULT_RUNAWAY_GUARD)
    gov["runaway_guard"] = dict(guard)
    gov["caps"] = dict(guard)
    gov["_guard_user_specified"] = guard_user_specified
    gov.setdefault("conserve_pct", 70)
    gov.setdefault("consecutive_fail_threshold", 2)
    gov.setdefault("consecutive_fail_statuses", ["rate_limited", "auth_expired"])
    gov.setdefault(
        "conserve_allowed_capabilities",
        ["edge_discovery", "hypothesis_authoring", "cross_experiment_analysis", "research_critic"],
    )
    gov.setdefault("subscription_period", cfg.get("subscription_period") or {})
    gov.setdefault("period_conserve_days_before_end", 3)
    # Real-quota consumption params (populated at runtime from the fetcher config by
    # evaluate(); defaults here keep compute_state usable when called directly).
    gov.setdefault("real_thresholds", dict(DEFAULT_REAL_THRESHOLDS))
    gov.setdefault("max_state_age_s", DEFAULT_MAX_STATE_AGE_S)
    gov.setdefault("quota_state_path", "D:/QM/reports/state/kimi_quota_state.json")
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

_STATE_ORDER = {"NORMAL": 0, "CONSERVE": 1, "EXHAUSTED": 2}


def _escalate(current: str, candidate: str) -> str:
    """Return the more severe of two states (NORMAL < CONSERVE < EXHAUSTED)."""
    return candidate if _STATE_ORDER.get(candidate, 0) > _STATE_ORDER.get(current, 0) else current


def _real_ratio(entry: Any) -> float | None:
    if not isinstance(entry, dict):
        return None
    v = entry.get("used_ratio")
    try:
        return None if v is None else float(v)
    except (TypeError, ValueError):
        return None


def _quota_state_fresh(quota_state: dict[str, Any] | None, max_age_s: int,
                       now: dt.datetime) -> bool:
    """True iff the fetched quota state is an ``ok`` fetch within ``max_age_s``
    (directive: prefer real telemetry only when fetch_status==ok AND source_timestamp
    is fresh, at most 2x the governor cadence)."""
    if not isinstance(quota_state, dict) or quota_state.get("fetch_status") != "ok":
        return False
    ts = _parse_ts(quota_state.get("source_timestamp"))
    if ts is None:
        return False
    age = (now - ts).total_seconds()
    return 0 <= age <= int(max_age_s)


def _real_state_from_ratios(quota_state: dict[str, Any],
                            thresholds: dict[str, Any]) -> tuple[str, list[str]]:
    """Derive NORMAL/CONSERVE/EXHAUSTED from the real subscription used-ratios.

    CONSERVE when any rolling window >= conserve_window_ratio (0.80) or monthly >=
    conserve_monthly_ratio (0.85); EXHAUSTED when any window (incl. monthly) >=
    exhausted_window_ratio (0.98). Thresholds are Fable-adjustable (directive sec33).
    """
    cw = float(thresholds.get("conserve_window_ratio", 0.80))
    cm = float(thresholds.get("conserve_monthly_ratio", 0.85))
    ex = float(thresholds.get("exhausted_window_ratio", 0.98))

    rolling: list[tuple[str, float]] = []
    for key in ("rolling_5h", "rolling_7d"):
        r = _real_ratio(quota_state.get(key))
        if r is not None:
            rolling.append((key, r))
    monthly_ratio = _real_ratio(quota_state.get("monthly"))

    state = "NORMAL"
    reasons: list[str] = []
    all_windows = rolling + ([("monthly", monthly_ratio)] if monthly_ratio is not None else [])
    for name, r in all_windows:
        if r >= ex:
            state = _escalate(state, "EXHAUSTED")
            reasons.append(f"real {name} {r:.2%} >= exhausted {ex:.0%}")
    if state != "EXHAUSTED":
        for name, r in rolling:
            if r >= cw:
                state = _escalate(state, "CONSERVE")
                reasons.append(f"real {name} {r:.2%} >= conserve {cw:.0%}")
        if monthly_ratio is not None and monthly_ratio >= cm:
            state = _escalate(state, "CONSERVE")
            reasons.append(f"real monthly {monthly_ratio:.2%} >= conserve {cm:.0%}")
    if not reasons:
        reasons.append("real usage within limits")
    return state, reasons


def compute_state(
    rows: list[dict[str, Any]],
    gov: dict[str, Any],
    now: dt.datetime | None = None,
    quota_state: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Derive NORMAL / CONSERVE / EXHAUSTED. Pure function.

    When ``quota_state`` is supplied and it is a fresh ``ok`` fetch from the managed
    usage endpoint, the primary state is driven by the REAL subscription used-ratios
    and ``usage_source='managed_usage_endpoint'``. The local call counts then act only
    as a runaway/anomaly guard (they can still escalate to EXHAUSTED). When a fetch was
    attempted but is unusable (auth_error/network_error/schema_error/disabled or stale),
    the governor falls back to the local ledger path exactly as before and marks
    ``usage_source='local_ledger_fallback'`` with the failure class. When ``quota_state``
    is None (no fetch attempted), the legacy ledger-only path is used.
    """
    now = now or _now()
    caps = gov.get("runaway_guard") or gov.get("caps") or {"day": 120, "week": 600}
    cap_day = int(caps.get("day", 120))
    cap_week = int(caps.get("week", 600))
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

    # Decide which telemetry drives the primary state (directive sec33):
    #   * real     - a fresh, ``ok`` managed-usage fetch was supplied.
    #   * fallback - a fetch was attempted but is unusable (auth/network/schema/
    #                disabled or stale) -> ledger path, marked local_ledger_fallback.
    #   * legacy   - no fetch attempted (quota_state is None) -> ledger-only as before.
    max_age_s = int(gov.get("max_state_age_s", DEFAULT_MAX_STATE_AGE_S))
    if quota_state is None:
        mode = "legacy"
        usage_source = "local_ledger_only" if not any_usage_snapshot else "usage_snapshot"
        fallback_class = None
    elif _quota_state_fresh(quota_state, max_age_s, now):
        mode = "real"
        usage_source = "managed_usage_endpoint"
        fallback_class = None
    else:
        mode = "fallback"
        usage_source = "local_ledger_fallback"
        fallback_class = str(quota_state.get("fetch_status") or "unusable")

    reasons: list[str] = []
    state = "NORMAL"

    # --- Runaway / anomaly guard + calendar conditions: ALWAYS active (all modes) ---
    # The renamed local call caps are now runaway-loop protection only (directive sec33).
    if calls_day >= cap_day:
        state = _escalate(state, "EXHAUSTED")
        reasons.append(f"runaway guard: daily calls {calls_day}/{cap_day}")
    if calls_week >= cap_week:
        state = _escalate(state, "EXHAUSTED")
        reasons.append(f"runaway guard: weekly calls {calls_week}/{cap_week}")
    if tail_fail_streak >= fail_threshold:
        state = _escalate(state, "EXHAUSTED")
        reasons.append(f"{tail_fail_streak} consecutive {'/'.join(sorted(fail_statuses))} statuses")
    if saw_cli_missing:
        state = _escalate(state, "EXHAUSTED")
        reasons.append("last status cli_missing")
    if period_ended:
        state = _escalate(state, "EXHAUSTED")
        reasons.append(f"subscription period ended {period_end.isoformat()}")
    if period_near_end and state != "EXHAUSTED":
        state = _escalate(state, "CONSERVE")
        reasons.append(f"subscription period ends {period_end.isoformat()} (<= {days_before}d)")

    real_quota: dict[str, Any] | None = None
    if mode == "real":
        # Primary state from the REAL subscription used-ratios.
        real_state, real_reasons = _real_state_from_ratios(
            quota_state, gov.get("real_thresholds") or DEFAULT_REAL_THRESHOLDS)
        state = _escalate(state, real_state)
        reasons = real_reasons + reasons
        real_quota = {
            "plan": quota_state.get("plan"),
            "source_timestamp": quota_state.get("source_timestamp"),
            "monthly": quota_state.get("monthly"),
            "rolling_5h": quota_state.get("rolling_5h"),
            "rolling_7d": quota_state.get("rolling_7d"),
            "breakdown": quota_state.get("breakdown"),
            "extra_quota_active": quota_state.get("extra_quota_active"),
        }
    else:
        # Ledger fallback / legacy: CONSERVE on approaching the (raised) guard.
        if state != "EXHAUSTED" and (day_pct >= conserve_pct or week_pct >= conserve_pct):
            state = _escalate(state, "CONSERVE")
            reasons.append(
                f"approaching runaway guard (day {day_pct:.0f}%, week {week_pct:.0f}% >= {conserve_pct:.0f}%)"
            )
        if mode == "fallback":
            reasons.insert(0, f"real quota fetch {fallback_class} -> local ledger fallback")

    if not reasons:
        reasons.append("within limits")

    return {
        "state": state,
        "counts": {"day": calls_day, "week": calls_week},
        "caps": {"day": cap_day, "week": cap_week},
        "runaway_guard": {"day": cap_day, "week": cap_week},
        "pct": {"day": round(day_pct, 1), "week": round(week_pct, 1)},
        "last_statuses": last_statuses,
        "consecutive_fail_streak": tail_fail_streak,
        "subscription_period": {
            "start": period_start.isoformat() if period_start else None,
            "end": period_end.isoformat() if period_end else None,
            "ended": period_ended,
            "near_end": period_near_end,
        },
        "usage_source": usage_source,
        "quota_fetch_status": (quota_state or {}).get("fetch_status") if quota_state else None,
        "fallback_class": fallback_class,
        "real_quota": real_quota,
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
    """True iff this governor owns the flag. Reads ``managed_by`` from the JSON body
    and tolerates the legacy first-line ``MANAGED_BY=<owner>`` key=value body."""
    try:
        raw = flag.read_text(encoding="utf-8").strip()
    except Exception:
        return False
    if not raw:
        return False
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            return str(obj.get("managed_by") or "") == managed_by
    except ValueError:
        pass
    # legacy key=value body: first line MANAGED_BY=<owner>
    first = raw.splitlines()[0].strip()
    return first == f"MANAGED_BY={managed_by}"


def _flag_state_on_disk(flag: Path) -> str | None:
    """The ``state`` currently recorded in the (owned) flag, or None if unreadable.
    Tolerant of the legacy body, which never carried a state (-> None)."""
    try:
        raw = flag.read_text(encoding="utf-8").strip()
    except Exception:
        return None
    if not raw:
        return None
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict) and obj.get("state"):
            return str(obj["state"]).upper()
    except ValueError:
        pass
    return None


def _write_flag(flag: Path, managed_by: str, state: str, reason: str,
                state_info: dict[str, Any]) -> None:
    """Write the canonical JSON flag body carrying the computed ``state`` so both
    planes (router JSON-only, chain JSON-or-key=value) transmit CONSERVE and
    EXHAUSTED faithfully."""
    flag.parent.mkdir(parents=True, exist_ok=True)
    body = {
        "schema": FLAG_SCHEMA,
        "state": state,
        "managed_by": managed_by,
        "reason": reason,
        "set_at_utc": _now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "counts": dict(state_info.get("counts") or {}),
        "caps": dict(state_info.get("caps") or {}),
    }
    flag.write_text(json.dumps(body, indent=2), encoding="utf-8")


def reconcile_flag(state_info: dict[str, Any], gov: dict[str, Any], *, dry_run: bool = False) -> dict[str, Any]:
    """Write the flag on CONSERVE **and** EXHAUSTED (carrying the state), clear it
    only when NORMAL - but only ever touch a flag this governor owns (managed_by
    marker). Returns the flag action taken."""
    flag = Path(gov["flag_path"])
    managed_by = gov.get("managed_by", "kimi_governor")
    state = state_info["state"]
    exists = flag.exists()
    owned = _flag_owned(flag, managed_by) if exists else False
    reason = "; ".join(state_info.get("reasons") or [])

    action = "noop"
    if state in ("EXHAUSTED", "CONSERVE"):
        if not exists:
            action = "SET"
            if not dry_run:
                _write_flag(flag, managed_by, state, reason, state_info)
        elif owned:
            # keep the flag current: rewrite when the recorded state changed
            # (e.g. CONSERVE -> EXHAUSTED, or a legacy body with no state).
            if _flag_state_on_disk(flag) != state:
                action = "UPDATE"
                if not dry_run:
                    _write_flag(flag, managed_by, state, reason, state_info)
            else:
                action = "hold"
        else:
            action = "leave-external"  # someone else owns this flag; never overwrite
    else:  # NORMAL -> the flag (a lane brake) should not be present
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


# --------------------------------------------------------------------------- real-quota wiring

_QUOTA_FETCHER_CONFIG = Path(__file__).with_name("config") / "kimi_quota_fetcher.v1.json"
_FETCH_TIMEOUT_S = 15  # directive: guard the in-process fetch with a 15 s timeout


def _load_quota_fetcher_config(cfg: dict[str, Any]) -> dict[str, Any] | None:
    """Load the quota-fetcher config (guarded); None if absent/broken so the governor
    keeps running on the local ledger."""
    gov_cfg = cfg.get("governor") or {}
    raw = gov_cfg.get("quota_fetcher_config")
    path = Path(raw) if raw else _QUOTA_FETCHER_CONFIG
    if raw and not path.is_absolute():
        # A bare / relative file name is resolved against the governor's config
        # directory, not the process cwd (the 15-min task runs from the repo root,
        # operators run from anywhere). Live defect 2026-09-15: the bare name in
        # kimi_adapter.v1.json silently disabled the real-quota fetch.
        path = _QUOTA_FETCHER_CONFIG.parent / path
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def _apply_fetcher_params(gov: dict[str, Any], fetcher_cfg: dict[str, Any]) -> None:
    """Merge the fetcher config's real-quota params into ``gov`` (thresholds, freshness
    window, quota-state path, and the raised runaway guard unless the caller pinned it)."""
    fgov = fetcher_cfg.get("governor") or {}
    if fgov.get("thresholds"):
        gov["real_thresholds"] = dict(fgov["thresholds"])
    if fgov.get("max_state_age_s") is not None:
        gov["max_state_age_s"] = int(fgov["max_state_age_s"])
    if fetcher_cfg.get("state_path"):
        gov["quota_state_path"] = fetcher_cfg["state_path"]
    # Only adopt the fetcher's raised runaway guard when the governor config did not
    # pin its own caps/runaway_guard (keeps existing configs and tests authoritative).
    if not gov.get("_guard_user_specified") and fgov.get("runaway_guard"):
        gov["runaway_guard"] = dict(fgov["runaway_guard"])
        gov["caps"] = dict(fgov["runaway_guard"])



def _prefer_fresh_last_ok(fetched: dict[str, Any], gov: dict[str, Any], *,
                          now: dt.datetime | None = None) -> dict[str, Any]:
    """When the current fetch failed but the fetcher carried a ``last_ok`` snapshot that
    is still within ``max_state_age_s``, treat that snapshot as the authoritative state
    (fetch_status ok, annotated ``last_ok_reused`` + the failure class of the current
    cycle). Beyond the window the failed state is returned unchanged -> ledger fallback."""
    if not isinstance(fetched, dict) or fetched.get("fetch_status") == "ok":
        return fetched
    last_ok = fetched.get("last_ok")
    if not isinstance(last_ok, dict):
        return fetched
    candidate = dict(last_ok)
    candidate["fetch_status"] = "ok"
    if _quota_state_fresh(candidate, int(gov.get("max_state_age_s") or 0), now or _now()):
        candidate["last_ok_reused"] = True
        candidate["current_cycle_fetch_status"] = fetched.get("fetch_status")
        candidate["refresh_calls"] = fetched.get("refresh_calls")
        candidate["refresh_last_utc"] = fetched.get("refresh_last_utc")
        return candidate
    return fetched

def _fetch_quota_state(fetcher_cfg: dict[str, Any], *, timeout_s: int = _FETCH_TIMEOUT_S,
                       now: dt.datetime | None = None) -> dict[str, Any] | None:
    """Call the quota fetcher in-process, bounded by ``timeout_s`` and fully guarded.
    Returns the normalized state dict, or None if the fetcher is unavailable/hangs -
    the caller then marks a fallback. Never raises (MT5 factory unaffected)."""
    import threading

    box: dict[str, Any] = {}

    def _run() -> None:
        try:
            import kimi_quota_fetcher as kqf  # same dir; guarded
            box["state"] = kqf.fetch(fetcher_cfg, now=now)
        except Exception as exc:  # pragma: no cover - defensive
            box["error"] = type(exc).__name__

    th = threading.Thread(target=_run, daemon=True)
    th.start()
    th.join(timeout_s)
    if th.is_alive():
        return None
    return box.get("state")


# --------------------------------------------------------------------------- public API

def evaluate(cfg: dict[str, Any] | None = None, *, dry_run: bool = False,
             now: dt.datetime | None = None, fetch: bool = False,
             quota_state: dict[str, Any] | None = None) -> dict[str, Any]:
    """Recompute state and reconcile the flag.

    ``fetch=True`` (the ``evaluate`` CLI subcommand and the 15-min governor task)
    performs the in-process real-quota fetch first (guarded, 15 s timeout) and prefers
    the real subscription ratios. ``fetch=False`` (adapter ``record()``) consumes the
    last fetched ``kimi_quota_state.json`` if present, so ordinary calls do not spend a
    fetch. An explicit ``quota_state`` overrides both (tests / injection). Any fetch
    failure falls back to the local ledger path (directive sec33/sec70)."""
    cfg = cfg or load_config()
    gov = governor_config(cfg)
    fetcher_cfg = _load_quota_fetcher_config(cfg)
    if fetcher_cfg:
        _apply_fetcher_params(gov, fetcher_cfg)

    # Resolve the quota telemetry to feed compute_state.
    if quota_state is None:
        if fetch and fetcher_cfg is not None:
            fetched = _fetch_quota_state(fetcher_cfg, now=now)
            if fetched is None:
                # Fetch was attempted but the fetcher was unavailable/hung -> fallback.
                quota_state = {"fetch_status": "network_error", "error": "fetcher_unavailable",
                               "source_timestamp": (now or _now()).replace(microsecond=0)
                               .isoformat().replace("+00:00", "Z")}
            else:
                quota_state = _prefer_fresh_last_ok(fetched, gov, now=now)
        elif not fetch:
            # Consume the freshest state the governor task last wrote, if any.
            try:
                sp = Path(gov.get("quota_state_path") or "")
                if sp and sp.exists():
                    obj = json.loads(sp.read_text(encoding="utf-8"))
                    if isinstance(obj, dict):
                        quota_state = obj
            except Exception:
                quota_state = None

    rows = read_ledger(gov["ledger_path"])
    state_info = compute_state(rows, gov, now=now, quota_state=quota_state)
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
        # Read-only: no fetch (would write the quota-state file), consume last state.
        info = evaluate(cfg, dry_run=True, fetch=False)
        print(json.dumps(info, indent=2))
        return 0
    # evaluate: perform the real-quota fetch first (in-process, guarded), then derive.
    info = evaluate(cfg, dry_run=False, fetch=True)
    print(json.dumps(info, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
