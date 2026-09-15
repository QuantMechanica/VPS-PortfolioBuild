"""AI orchestration health read-model (``qm.orchestration-health/v1``).

Deterministically composes ``D:/QM/reports/state/orchestration_health.json``
from **read-only** inputs so Mission Control, the vault Heartbeat and the
15-minute read-model task can all read one authoritative orchestration-health
surface instead of re-deriving it from raw logs.

Directive basis: OWNER follow-up 2026-09-15 §18 (AI orchestration health),
§16 (Kimi must actually run), §15 (Kimi telemetry final state), §17 (research
resource capacity); master §35 (Claude-lane fan-out fix).

Read-only inputs (never opened writable, no process started):
  * ``farm_state.sqlite`` (``mode=ro``) — ``agent_tasks`` state census per lane,
    ``spawn_leases`` (router ``agent_task:*`` and the fan-out fix's owner-scoped
    ``agent_task_exec:*`` leases), ``agent_task_transition_ledger``.
  * ``D:/QM/reports/state/`` governor/quota state files
    (``quota_governor_state.json``, ``codex_budget_line.json``, ``agy_quota.json``,
    ``agy_governor_state.json``, ``kimi_governor_state.json``,
    ``kimi_quota_state.json``).
  * ``D:/QM/strategy_farm/*.flag`` — quota flags (presence + mtime + expiry).
  * ``D:/QM/strategy_farm/state/agent_chain/tasks/*.json`` — critic-chain
    receipts, for review-independence (``cross_vendor`` / ``critic_fallback_used``).
  * ``agent_router`` registry + task-type capability map — routing correctness.
  * ``research.research_env.research_guard`` — the §17 research resource guard.

Determinism: all *content* is a pure function of the inputs. The only
wall-clock value is ``generated_at_utc`` (the run stamp) and the age/window
classifications, which take a single injectable ``now`` (tests pass a fixed
``now`` for byte-identical output). Missing inputs are explicit
(``EVIDENCE_MISSING`` / ``UNKNOWN`` / ``NOT_EVALUATED``), never zero-forged.

CLI::

    python tools/strategy_farm/orchestration_health_readmodel.py build
    python tools/strategy_farm/orchestration_health_readmodel.py build --stdout
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "qm.orchestration-health/v1"

# --- canonical paths (module-level so tests can monkeypatch) ---
FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_STATE = Path(r"D:\QM\reports\state")
DB = FARM_ROOT / "state" / "farm_state.sqlite"
FLAG_DIR = FARM_ROOT
AGENT_CHAIN_RECEIPT_DIR = FARM_ROOT / "state" / "agent_chain" / "tasks"
OUTPUT_PATH = REPORTS_STATE / "orchestration_health.json"

QUOTA_GOVERNOR_STATE = REPORTS_STATE / "quota_governor_state.json"
CODEX_BUDGET_LINE = REPORTS_STATE / "codex_budget_line.json"
AGY_QUOTA = REPORTS_STATE / "agy_quota.json"
AGY_GOVERNOR_STATE = REPORTS_STATE / "agy_governor_state.json"
KIMI_GOVERNOR_STATE = REPORTS_STATE / "kimi_governor_state.json"
KIMI_QUOTA_STATE = REPORTS_STATE / "kimi_quota_state.json"

# The five orchestration lanes. ``gemini`` is the router lane name that executes
# via the agy CLI (CLAUDE.md); ``owner`` is the declared-but-disabled human lane.
LANES = ["claude", "codex", "gemini", "kimi", "owner"]

# Quota flag file -> the lane it governs.
QUOTA_FLAGS = {
    "CLAUDE_DISABLED.flag": "claude",
    "CODEX_LOW_TOKENS.flag": "codex",
    "AGY_LOW_QUOTA.flag": "gemini",
    "KIMI_LOW_QUOTA.flag": "kimi",
}
# Burn-authorization flags are informational (they expire); reported not lane-gating.
INFO_FLAGS = ["CLAUDE_BURN_AUTHORIZED.flag", "CODEX_BURN_AUTHORIZED.flag"]

# Lease TTL used by both the router lease and the fan-out fix's exec-lease
# (run_agent_orchestration_task.HEADLESS_SESSION_LEASE_TTL_MINUTES == 30,
# agent_router.LEASE_TTL_MINUTES == 30). Kept as the module constant so the
# stale-lease classification has a single documented source.
LEASE_TTL_MINUTES = 30
STALE_TODO_DAYS = 14
THROUGHPUT_WINDOW_DAYS = 7


# --------------------------------------------------------------------------- utils
def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(when: dt.datetime) -> str:
    return when.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_ts(value: Any) -> dt.datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def _lane_of(assigned_agent: str | None) -> str | None:
    """Strip a ``codex:agents/board-advisor`` worktree suffix down to the lane."""
    if not assigned_agent:
        return None
    return assigned_agent.split(":", 1)[0]


# --------------------------------------------------------------------------- DB census
def _task_states_by_lane(conn: sqlite3.Connection) -> dict[str, dict[str, int]]:
    out: dict[str, dict[str, int]] = {lane: {} for lane in LANES}
    out["(unassigned)"] = {}
    for row in conn.execute(
        "SELECT assigned_agent AS a, state, COUNT(*) AS n FROM agent_tasks GROUP BY a, state"
    ):
        lane = _lane_of(row["a"]) or "(unassigned)"
        bucket = out.setdefault(lane, {})
        bucket[row["state"]] = bucket.get(row["state"], 0) + int(row["n"])
    return out


def _throughput(conn: sqlite3.Connection, *, now: dt.datetime) -> dict[str, Any]:
    """Tasks reaching APPROVED, per lane per day, over the window.

    Source of truth is ``agent_tasks.updated_at`` = the LAST transition
    timestamp. This is a proxy: a task later advanced past APPROVED
    (PIPELINE/PASSED) no longer carries state=APPROVED, so this UNDER-counts.
    There is no per-transition history for every move (the
    ``agent_task_transition_ledger`` records only a subset of actions), so the
    proxy is the deterministic best available signal. The method + caveats are
    stamped into the block so no reader mistakes it for a full transition log.
    """
    since = (now - dt.timedelta(days=THROUGHPUT_WINDOW_DAYS)).strftime("%Y-%m-%d")
    approved_by_lane_day: dict[str, dict[str, int]] = {}
    for row in conn.execute(
        "SELECT assigned_agent AS a, substr(updated_at,1,10) AS d, COUNT(*) AS n "
        "FROM agent_tasks WHERE state='APPROVED' AND updated_at >= ? GROUP BY a, d",
        (since,),
    ):
        lane = _lane_of(row["a"]) or "(unassigned)"
        approved_by_lane_day.setdefault(lane, {})[row["d"]] = int(row["n"])
    ledger_rows = 0
    ledger_max_ts = None
    try:
        r = conn.execute(
            "SELECT COUNT(*) n, MAX(ts) m FROM agent_task_transition_ledger").fetchone()
        ledger_rows, ledger_max_ts = int(r["n"]), r["m"]
    except sqlite3.Error:
        pass
    return {
        "method": "updated_at_last_transition_proxy(state=APPROVED)",
        "window_days": THROUGHPUT_WINDOW_DAYS,
        "since": since,
        "approved_by_lane_day": approved_by_lane_day,
        "caveats": [
            "updated_at is the LAST transition; tasks advanced past APPROVED are not counted here.",
            "A bulk updated_at re-touch on 2026-09-12 contaminates that day's counts.",
            "agent_task_transition_ledger is a partial action log, not a full move history.",
        ],
        "transition_ledger_rows": ledger_rows,
        "transition_ledger_max_ts": ledger_max_ts,
    }


def _stale_tasks(conn: sqlite3.Connection, *, now: dt.datetime,
                 leases: dict[str, dict[str, Any]]) -> dict[str, Any]:
    """IN_PROGRESS rows whose newest matching lease is expired (or missing), and
    TODO rows older than STALE_TODO_DAYS (by created_at)."""
    in_progress_stale: list[dict[str, Any]] = []
    for row in conn.execute(
        "SELECT id, assigned_agent, task_type, priority, created_at, updated_at "
        "FROM agent_tasks WHERE state='IN_PROGRESS'"
    ):
        tid = row["id"]
        lease = leases.get(f"agent_task_exec:{tid}") or leases.get(f"agent_task:{tid}")
        exp = _parse_ts(lease.get("expires_at")) if lease else None
        lease_expired = (exp is not None and exp < now)
        updated = _parse_ts(row["updated_at"])
        age_min = (now - updated).total_seconds() / 60.0 if updated else None
        stale = lease_expired or (lease is None and age_min is not None
                                  and age_min > LEASE_TTL_MINUTES)
        if stale:
            in_progress_stale.append({
                "id": tid,
                "lane": _lane_of(row["assigned_agent"]),
                "task_type": row["task_type"],
                "priority": row["priority"],
                "updated_at": row["updated_at"],
                "age_minutes": round(age_min, 1) if age_min is not None else None,
                "lease_present": lease is not None,
                "lease_expired": bool(lease_expired),
                "lease_owner_pid": (lease or {}).get("owner_pid"),
            })
    todo_cut = (now - dt.timedelta(days=STALE_TODO_DAYS))
    todo_stale_by_lane: dict[str, int] = {}
    todo_total = 0
    for row in conn.execute(
        "SELECT assigned_agent AS a, created_at FROM agent_tasks WHERE state='TODO'"
    ):
        todo_total += 1
        created = _parse_ts(row["created_at"])
        if created is not None and created < todo_cut:
            lane = _lane_of(row["a"]) or "(unassigned)"
            todo_stale_by_lane[lane] = todo_stale_by_lane.get(lane, 0) + 1
    return {
        "in_progress_beyond_ttl": in_progress_stale,
        "in_progress_beyond_ttl_count": len(in_progress_stale),
        "lease_ttl_minutes": LEASE_TTL_MINUTES,
        "todo_older_than_days": STALE_TODO_DAYS,
        "todo_stale_by_lane": todo_stale_by_lane,
        "todo_stale_total": sum(todo_stale_by_lane.values()),
        "todo_total": todo_total,
    }


def _leases(conn: sqlite3.Connection) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    try:
        for row in conn.execute(
            "SELECT task_key, agent_id, owner_pid, owner_host, acquired_at, expires_at "
            "FROM spawn_leases"
        ):
            out[row["task_key"]] = dict(row)
    except sqlite3.Error:
        pass
    return out


def _double_claim_guard(conn: sqlite3.Connection, leases: dict[str, dict[str, Any]],
                        *, now: dt.datetime) -> dict[str, Any]:
    """State of the fan-out fix (master §35): the owner-scoped
    ``agent_task_exec:*`` lease scheme vs the router's NULL-owner
    ``agent_task:*`` leases, and any IN_PROGRESS task not covered by an
    owner-scoped exec-lease (the pre-fix collision shape)."""
    exec_leases = {k: v for k, v in leases.items() if k.startswith("agent_task_exec:")}
    router_leases = {k: v for k, v in leases.items()
                     if k.startswith("agent_task:") and not k.startswith("agent_task_exec:")}
    exec_owned = [k for k, v in exec_leases.items() if v.get("owner_pid") is not None]
    router_null_owner = [k for k, v in router_leases.items() if v.get("owner_pid") is None]
    in_progress_ids = [r["id"] for r in conn.execute(
        "SELECT id FROM agent_tasks WHERE state='IN_PROGRESS'")]
    uncovered = [tid for tid in in_progress_ids
                 if f"agent_task_exec:{tid}" not in exec_leases]
    return {
        "exec_lease_scheme_present": bool(exec_leases),
        "exec_leases_total": len(exec_leases),
        "exec_leases_owner_scoped": len(exec_owned),
        "router_leases_total": len(router_leases),
        "router_leases_null_owner": len(router_null_owner),
        "in_progress_total": len(in_progress_ids),
        "in_progress_without_exec_lease": uncovered,
        "note": (
            "The fan-out fix (agent_task_exec:* owner-scoped leases) is landed in "
            "run_agent_orchestration_task.py. Router agent_task:* leases carry NULL "
            "owner by design (route-time only) and never gated sibling sessions. "
            "in_progress_without_exec_lease>0 with the exec scheme unused indicates "
            "the claude lane has not spawned under the new scheme yet (it is quota-"
            "disabled / --max-sessions 1)."
        ),
    }


# --------------------------------------------------------------------------- quota / flags
def _flag_state(name: str, *, now: dt.datetime) -> dict[str, Any]:
    path = FLAG_DIR / name
    if not path.exists():
        return {"present": False}
    try:
        mtime = dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc)
    except OSError:
        mtime = None
    body = None
    try:
        body = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        pass
    expired = None
    if body and "expire" in body.lower():
        for tok in body.replace(",", " ").replace('"', " ").split():
            ts = _parse_ts(tok)
            if ts is not None:
                expired = ts < now
                break
    return {
        "present": True,
        "mtime_utc": _iso(mtime) if mtime else None,
        "age_hours": round((now - mtime).total_seconds() / 3600.0, 1) if mtime else None,
        "expired": expired,
    }


def _quota_flags(*, now: dt.datetime) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for name in list(QUOTA_FLAGS) + INFO_FLAGS:
        st = _flag_state(name, now=now)
        st["lane"] = QUOTA_FLAGS.get(name)
        st["kind"] = "lane_gate" if name in QUOTA_FLAGS else "informational"
        out[name] = st
    return out


def _lane_quota(now: dt.datetime, flags: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Per-lane quota posture from the governor/quota state files + flags."""
    gov = _read_json(QUOTA_GOVERNOR_STATE) or {}
    gov_agents = gov.get("agents") or {}
    agy_q = _read_json(AGY_QUOTA) or {}
    agy_gov = _read_json(AGY_GOVERNOR_STATE) or {}
    kimi_gov = _read_json(KIMI_GOVERNOR_STATE) or {}
    budget = _read_json(CODEX_BUDGET_LINE) or {}

    def flag_on(fname: str) -> bool:
        return bool((flags.get(fname) or {}).get("present"))

    out: dict[str, dict[str, Any]] = {}
    c = gov_agents.get("claude") or {}
    out["claude"] = {
        "flag": "CLAUDE_DISABLED.flag" if flag_on("CLAUDE_DISABLED.flag") else None,
        "flag_on": flag_on("CLAUDE_DISABLED.flag"),
        "weekly_used_pct": c.get("used_pct"),
        "weekly_elapsed_pct": c.get("elapsed_pct"),
        "projected_eow_pct": c.get("projected_eow_pct"),
        "five_hour_used_pct": c.get("five_hour_used_pct"),
        "action": c.get("action"),
        "why": c.get("why"),
        "week_reset": c.get("week_reset"),
    }
    cx = gov_agents.get("codex") or {}
    out["codex"] = {
        "flag": "CODEX_LOW_TOKENS.flag" if flag_on("CODEX_LOW_TOKENS.flag") else None,
        "flag_on": flag_on("CODEX_LOW_TOKENS.flag"),
        "weekly_used_pct": cx.get("used_pct"),
        "weekly_elapsed_pct": cx.get("elapsed_pct"),
        "projected_eow_pct": cx.get("projected_eow_pct"),
        "action": cx.get("action"),
        "why": cx.get("why"),
        "week_reset": cx.get("week_reset"),
        "budget_line": {
            "anchor_used": budget.get("anchor_used"),
            "target_at_reset": budget.get("target_at_reset"),
            "reset_ts": budget.get("reset_ts"),
        } if budget else None,
    }
    out["gemini"] = {
        "flag": "AGY_LOW_QUOTA.flag" if flag_on("AGY_LOW_QUOTA.flag") else None,
        "flag_on": flag_on("AGY_LOW_QUOTA.flag"),
        "quota_ok": agy_q.get("ok"),
        "token_expired": agy_q.get("token_expired"),
        "failure_class": agy_gov.get("failure_class"),
        "reason": agy_gov.get("reason"),
        "note": "agy token expiry needs OWNER Antigravity relogin (OWNER lane action).",
    }
    out["kimi"] = {
        "flag": "KIMI_LOW_QUOTA.flag" if flag_on("KIMI_LOW_QUOTA.flag") else None,
        "flag_on": flag_on("KIMI_LOW_QUOTA.flag"),
        "state": kimi_gov.get("state"),
        "usage_source": kimi_gov.get("usage_source"),
        "quota_fetch_status": kimi_gov.get("quota_fetch_status"),
        "counts": kimi_gov.get("counts"),
        "runaway_guard": kimi_gov.get("runaway_guard") or kimi_gov.get("caps"),
    }
    out["owner"] = {
        "flag": None,
        "flag_on": False,
        "note": "human lane, declared-but-disabled (enabled:false, max_parallel:0); "
                "video_analysis held as awaiting_human_lane:owner.",
    }
    return out


# --------------------------------------------------------------------------- critic chain
def _critic_chain(*, receipt_dir: Path | None = None,
                  recent_limit: int = 12) -> dict[str, Any]:
    """Review independence from the agent_chain critic receipts.

    A same-vendor critic (``cross_vendor=false``) is the quota-gated last-resort
    seat and REDUCES review independence; ``critic_fallback_used=true`` means the
    first critic seat was replaced by the next open seat within the chain (still
    cross-vendor by construction). Both are surfaced honestly.
    """
    rdir = receipt_dir or AGENT_CHAIN_RECEIPT_DIR
    files = sorted(glob.glob(str(Path(rdir) / "*.json")))
    if not files:
        return {"present": False, "degraded_reason": "EVIDENCE_MISSING",
                "receipt_dir": str(rdir)}
    recent: list[dict[str, Any]] = []
    completed = cross_false = fallback = 0
    for f in files:
        r = _read_json(Path(f))
        if not r:
            continue
        status = r.get("status")
        plan_critic = (r.get("plan") or {}).get("critic") or {}
        critic_stages = [s for s in (r.get("stages") or []) if s.get("role") == "critic"]
        cross_vendor = None
        for s in critic_stages:
            if s.get("cross_vendor") is not None:
                cross_vendor = s.get("cross_vendor")
        if cross_vendor is None:
            cross_vendor = plan_critic.get("cross_vendor")
        fb = bool(r.get("critic_fallback_used"))
        creator_vendor = ((r.get("plan") or {}).get("creator") or {}).get("vendor")
        critic_vendor = (r.get("critic_seat_final") or plan_critic or {}).get("vendor")
        is_completed = status in {"ok", "partial"} and bool(critic_stages)
        if is_completed:
            completed += 1
            if cross_vendor is False:
                cross_false += 1
            if fb:
                fallback += 1
        recent.append({
            "chain_id": r.get("chain_id"),
            "task_id": r.get("task_id"),
            "status": status,
            "critic_verdict": r.get("critic_verdict"),
            "creator_vendor": creator_vendor,
            "critic_vendor": critic_vendor,
            "cross_vendor": cross_vendor,
            "critic_fallback_used": fb,
            "generated_at_utc": r.get("generated_at_utc"),
        })
    recent.sort(key=lambda x: (x.get("generated_at_utc") or ""), reverse=True)
    degraded = completed > 0 and (cross_false > 0)
    return {
        "present": True,
        "receipt_dir": str(rdir),
        "receipts_considered": len(files),
        "completed": completed,
        "cross_vendor_false": cross_false,
        "critic_fallback_used": fallback,
        "same_vendor_share": round(cross_false / completed, 3) if completed else None,
        "fallback_share": round(fallback / completed, 3) if completed else None,
        "independence_degraded": degraded,
        "recent": recent[:recent_limit],
        "note": (
            "cross_vendor=false = same-vendor last-resort critic (independence "
            "reduced) — happens when the other vendor lanes are quota-gated. "
            "critic_fallback_used=true replaces the first critic seat with the next "
            "OPEN seat, still cross-vendor by construction. Kimi never critiques Kimi "
            "(hard invariant in agent_chain.open_critic_seats)."
        ),
    }


# --------------------------------------------------------------------------- routing
def _routing_correctness(conn: sqlite3.Connection, *, sample: int = 40) -> dict[str, Any]:
    """Sample recent routed tasks and check the assigned lane's registry
    capabilities cover the task-type + payload required capabilities."""
    router = None
    try:
        import agent_router as router  # type: ignore
    except Exception:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        try:
            import agent_router as router  # type: ignore
        except Exception as exc:  # pragma: no cover
            return {"available": False, "reason": f"router_import_failed:{exc}"}
    caps = {a: set(r.get("capabilities", []))
            for a, r in router.DEFAULT_AGENT_REGISTRY.items()}
    ttc = router.TASK_TYPE_CAPABILITIES
    ok = 0
    mismatches: list[dict[str, Any]] = []
    rows = list(conn.execute(
        "SELECT id, task_type, assigned_agent, required_capabilities_json "
        "FROM agent_tasks WHERE assigned_agent IS NOT NULL "
        "ORDER BY updated_at DESC LIMIT ?", (sample,)))
    for row in rows:
        lane = _lane_of(row["assigned_agent"])
        req = set(ttc.get(row["task_type"], []))
        try:
            req |= set(json.loads(row["required_capabilities_json"] or "[]"))
        except (ValueError, TypeError):
            pass
        have = caps.get(lane, set())
        if req.issubset(have):
            ok += 1
        else:
            mismatches.append({
                "id": row["id"], "lane": lane, "task_type": row["task_type"],
                "required": sorted(req), "missing": sorted(req - have),
            })
    return {
        "available": True,
        "method": "task_type+required_capabilities vs assigned lane registry caps",
        "sampled": len(rows),
        "ok": ok,
        "mismatch": len(mismatches),
        "mismatches": mismatches,
    }


# --------------------------------------------------------------------------- kimi / research
def _kimi_telemetry() -> dict[str, Any]:
    q = _read_json(KIMI_QUOTA_STATE)
    g = _read_json(KIMI_GOVERNOR_STATE) or {}
    if q is None:
        return {"present": False, "degraded_reason": "EVIDENCE_MISSING"}
    return {
        "present": True,
        "usage_source": g.get("usage_source"),
        "quota_fetch_status": q.get("fetch_status"),
        "source": q.get("source"),
        "source_timestamp": q.get("source_timestamp"),
        "refresh_calls": q.get("refresh_calls"),
        "refresh_last_utc": q.get("refresh_last_utc"),
        "last_ok_present": bool(q.get("last_ok")),
        "plan": q.get("plan"),
        "rolling_5h_used_ratio": (q.get("rolling_5h") or {}).get("used_ratio"),
        "rolling_7d_used_ratio": (q.get("rolling_7d") or {}).get("used_ratio"),
        "monthly_used_ratio": (q.get("monthly") or {}).get("used_ratio")
            if isinstance(q.get("monthly"), dict) else None,
        "subscription_period": q.get("subscription_period"),
    }


def _research_guard_state() -> dict[str, Any]:
    research_guard = None
    try:
        from research.research_env import research_guard  # type: ignore
    except Exception:
        try:
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            from research.research_env import research_guard  # type: ignore
        except Exception as exc:  # pragma: no cover
            return {"available": False, "reason": f"research_env_import_failed:{exc}"}
    try:
        res = research_guard()
    except Exception as exc:  # pragma: no cover
        return {"available": False, "reason": f"research_guard_error:{exc}"}
    d = res.as_dict() if hasattr(res, "as_dict") else dict(res)
    m = d.get("measurements") or {}
    return {
        "available": True,
        "allowed": d.get("allowed"),
        "reasons": d.get("reasons"),
        "scratch_root": m.get("scratch_root"),
        "scratch_free_gb": m.get("scratch_free_gb"),
        "scratch_min_free_gb": m.get("scratch_min_free_gb"),
        "scratch_on_factory_drive": m.get("scratch_on_factory_drive"),
        "factory_free_gb": m.get("factory_free_gb"),
        "factory_min_free_gb": m.get("factory_min_free_gb"),
        "free_ram_gb": m.get("free_ram_gb"),
        "max_worker_processes": d.get("max_worker_processes"),
    }


# --------------------------------------------------------------------------- health roll-up
def _health(lane_quota: dict[str, Any], critic: dict[str, Any], routing: dict[str, Any],
            double_claim: dict[str, Any], stale: dict[str, Any],
            kimi: dict[str, Any]) -> dict[str, Any]:
    flags: list[str] = []
    status = "GREEN"
    if routing.get("available") and routing.get("mismatch", 0) > 0:
        flags.append(f"routing_mismatch:{routing['mismatch']}")
        status = "RED"
    if critic.get("present") and critic.get("independence_degraded"):
        flags.append(
            f"critic_same_vendor:{critic.get('cross_vendor_false')}/{critic.get('completed')}")
        status = "AMBER" if status != "RED" else status
    for lane, q in lane_quota.items():
        if q.get("flag_on"):
            flags.append(f"quota_flag_on:{lane}")
            status = "AMBER" if status == "GREEN" else status
    ip = (stale or {}).get("in_progress_beyond_ttl_count", 0)
    if ip:
        flags.append(f"stale_in_progress:{ip}")
        status = "AMBER" if status == "GREEN" else status
    if (stale or {}).get("todo_stale_total", 0):
        flags.append(f"stale_todo:{stale['todo_stale_total']}")
        status = "AMBER" if status == "GREEN" else status
    if double_claim.get("in_progress_without_exec_lease"):
        flags.append(
            f"in_progress_without_exec_lease:{len(double_claim['in_progress_without_exec_lease'])}")
    return {"status": status, "flags": flags}


# --------------------------------------------------------------------------- compose
def build_orchestration_health(db: Path | None = None, *,
                               now: dt.datetime | None = None) -> dict[str, Any]:
    now = now or _now_utc()
    db = Path(db) if db is not None else DB

    task_states: dict[str, dict[str, int]] = {}
    throughput: dict[str, Any] = {}
    stale: dict[str, Any] = {}
    double_claim: dict[str, Any] = {}
    routing: dict[str, Any] = {"available": False, "reason": "db_unavailable"}
    db_error: str | None = None
    leases: dict[str, dict[str, Any]] = {}
    try:
        conn = _connect_ro(db)
    except sqlite3.Error as exc:
        conn = None
        db_error = f"db_open_error:{exc}"
    if conn is not None:
        try:
            leases = _leases(conn)
            task_states = _task_states_by_lane(conn)
            throughput = _throughput(conn, now=now)
            stale = _stale_tasks(conn, now=now, leases=leases)
            double_claim = _double_claim_guard(conn, leases, now=now)
            routing = _routing_correctness(conn)
        finally:
            conn.close()

    flags = _quota_flags(now=now)
    lane_quota = _lane_quota(now, flags)
    critic = _critic_chain()
    kimi = _kimi_telemetry()
    research = _research_guard_state()

    lanes: dict[str, Any] = {}
    for lane in LANES:
        lanes[lane] = {
            "task_states": task_states.get(lane, {}),
            "quota": lane_quota.get(lane, {}),
            "todo_stale": (stale.get("todo_stale_by_lane", {}) or {}).get(lane, 0) if stale else 0,
        }

    health = _health(lane_quota, critic, routing, double_claim, stale, kimi)

    return {
        "schema": SCHEMA_VERSION,
        "generated_at_utc": _iso(now),
        "source_db": str(db),
        "db_error": db_error,
        "lease_ttl_minutes": LEASE_TTL_MINUTES,
        "lanes": lanes,
        "task_states_by_lane": task_states,
        "throughput": throughput,
        "stale_tasks": stale,
        "double_claim_guard": double_claim,
        "critic_chain": critic,
        "routing": routing,
        "quota_flags": flags,
        "kimi_telemetry": kimi,
        "research_guard": research,
        "health": health,
    }


def write_text_atomic(path: Path, rendered: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(rendered, encoding="utf-8", newline="\n")
    os.replace(temp, path)


# --------------------------------------------------------------------------- CLI
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build"], help="build the read-model")
    parser.add_argument("--db", type=Path, default=None, help="override farm_state.sqlite")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH,
                        help="orchestration_health.json output path")
    parser.add_argument("--stdout", action="store_true", help="also print to stdout")
    args = parser.parse_args(argv)

    now = _now_utc()
    doc = build_orchestration_health(args.db, now=now)
    rendered = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    write_text_atomic(args.output, rendered)
    if args.stdout:
        sys.stdout.write(rendered)

    _err = sys.stderr if sys.stderr is not None else open(os.devnull, "w", encoding="utf-8")
    crit = doc["critic_chain"]
    _err.write(
        f"[orchestration_health] status={doc['health']['status']} "
        f"routing_mismatch={doc['routing'].get('mismatch')} "
        f"critic_same_vendor={crit.get('cross_vendor_false')}/{crit.get('completed')} "
        f"stale_in_progress={doc['stale_tasks'].get('in_progress_beyond_ttl_count')} "
        f"kimi_usage_source={doc['kimi_telemetry'].get('usage_source')} -> {args.output}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
