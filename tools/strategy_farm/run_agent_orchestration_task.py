"""Headless single-pass orchestration wrapper for Codex/Gemini/Claude.

The Windows scheduler owns cadence. This wrapper owns only one fire:
take an overlap lock, launch the requested agent in non-interactive mode with
a single-pass orchestration prompt, wait for it to exit, and write evidence.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any


REPO_ROOT = Path(r"C:\QM\repo")
WORKTREE_ROOT = Path(os.environ.get("QM_AGENT_WORKTREE_ROOT", r"C:\QM\worktrees"))
FARM_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
LOG_DIR = FARM_ROOT / "logs"
LOCK_DIR = FARM_ROOT / "locks"
PYTHON_EXE = Path(r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe")
CODEX_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd")
GEMINI_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\gemini.cmd")
GEMINI_NODE_BUNDLE = Path(r"C:\Users\Administrator\AppData\Roaming\npm\node_modules\@google\gemini-cli\bundle\gemini.js")
CLAUDE_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\claude.cmd")
CODEX_HOME = Path(os.environ.get("CODEX_HOME", r"C:\Users\Administrator\.codex"))
AGENT_USER_HOME = Path(r"C:\Users\Administrator")
CLAUDE_DISABLED_FLAG = FARM_ROOT / "CLAUDE_DISABLED.flag"
CLAUDE_BUDGET_POLICY = FARM_ROOT / "CLAUDE_BUDGET_POLICY.json"

# --- Headless model selection (weekly-quota cost control) -------------------
# Each headless cycle is mostly routine orchestration (claim work, run gates,
# write the cycle log, monitor health) — work that does not need the top model.
# Default Claude headless to Sonnet and let OWNER raise to opus per-run via env;
# Codex/Gemini default to their config.toml model unless an env override is set.
# Interactive sessions (e.g. the senior agent) are unaffected — they ignore
# these vars. Empty string => omit the flag (use the CLI/account default).
#   $env:QM_CLAUDE_HEADLESS_MODEL = 'opus'   # bump a cycle back to Opus
#   $env:QM_CODEX_HEADLESS_MODEL  = 'gpt-5-codex'  # cheaper Codex tier
CLAUDE_HEADLESS_MODEL = os.environ.get("QM_CLAUDE_HEADLESS_MODEL", "sonnet").strip()
CODEX_HEADLESS_MODEL = os.environ.get("QM_CODEX_HEADLESS_MODEL", "").strip()
GEMINI_HEADLESS_MODEL = os.environ.get("QM_GEMINI_HEADLESS_MODEL", "").strip()


def utc_stamp() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")


def resolve_cli(agent: str) -> str:
    if agent == "codex":
        found = shutil.which("codex.cmd") or shutil.which("codex")
        if found:
            return found
        return str(CODEX_FALLBACK if CODEX_FALLBACK.exists() else "codex")
    if agent == "gemini":
        found = shutil.which("gemini.cmd") or shutil.which("gemini")
        if found:
            return found
        return str(GEMINI_FALLBACK if GEMINI_FALLBACK.exists() else "gemini")
    if agent == "claude":
        found = shutil.which("claude.cmd") or shutil.which("claude")
        if found:
            return found
        return str(CLAUDE_FALLBACK if CLAUDE_FALLBACK.exists() else "claude")
    raise ValueError(f"unsupported agent: {agent}")


def agent_env(agent: str) -> dict[str, str]:
    env = os.environ.copy()
    env["QM_AGENT_ID"] = agent
    if agent == "codex":
        env["CODEX_HOME"] = str(CODEX_HOME)
    if agent == "gemini":
        # Scheduled tasks run as SYSTEM; point Gemini at the operator profile
        # where OAuth and workspace trust are configured.
        env["USERPROFILE"] = str(AGENT_USER_HOME)
        env["HOME"] = str(AGENT_USER_HOME)
        env["HOMEDRIVE"] = "C:"
        env["HOMEPATH"] = r"\Users\Administrator"
        env.setdefault("GEMINI_DEFAULT_AUTH_TYPE", "oauth-personal")
        env.setdefault("TERM", "dumb")
        env.setdefault("NO_COLOR", "1")
        env.setdefault("FORCE_COLOR", "0")
        env.setdefault("CI", "1")
    if agent == "claude":
        env["USERPROFILE"] = str(AGENT_USER_HOME)
        env["HOME"] = str(AGENT_USER_HOME)
        env["HOMEDRIVE"] = "C:"
        env["HOMEPATH"] = r"\Users\Administrator"
    return env


def build_prompt(agent: str, cwd: Path) -> str:
    edge_charter = cwd / "docs" / "ops" / "EDGE_LAB_CHARTER_2026-05-22.md"
    profitability = cwd / "docs" / "ops" / "PROFITABILITY_TRACK_2026-05-21.md"
    return f"""You are {agent} for QuantMechanica, launched by a headless scheduled task.

Execute exactly one single-pass orchestration cycle, then exit. Do not start a
15-minute sleep loop; the Windows scheduler provides cadence.

Working directory: {cwd.as_posix()}

Read first if needed:
- G:/My Drive/QuantMechanica - Company Reference/08 Current State/Current Operating State.md
- G:/My Drive/QuantMechanica - Company Reference/02 Org/AI Agent Routing and Role Contracts.md
- G:/My Drive/QuantMechanica - Company Reference/_OPEN ITEMS.md
- {edge_charter}
- {profitability}

Cycle:
1. Run:
   python tools/strategy_farm/farmctl.py health
   python tools/strategy_farm/agent_router.py status
   python tools/strategy_farm/agent_router.py run --min-ready-strategy-cards 5 --max-routes 5
   python tools/strategy_farm/agent_router.py route-many --max-routes 5
   python tools/strategy_farm/agent_router.py list-tasks --agent {agent} --state IN_PROGRESS
2. For every IN_PROGRESS task assigned to {agent}, in ascending numeric priority:
   The router claims a 30-minute spawn lease (`agent_task:<task_id>`) when it
   moves work to IN_PROGRESS. If you were launched directly for a specific task
   outside the router path, acquire that same lease before doing any work; if the
   lease is live, skip/defer instead of duplicating the task.
   read payload and skills, produce a durable artifact, run focused verification,
   then update the router with:
   python tools/strategy_farm/agent_router.py update-task <task_id> --state REVIEW --artifact-path "<artifact>" --verdict "<short_verdict>"
3. Repeat task handling until `list-tasks --agent {agent} --state IN_PROGRESS`
   returns an empty list. Ignore REVIEW/BLOCKED/PASSED tasks; they are not yours.
4. If no task remains, run farmctl health and check QM5_10260 queue state. Do not invent untracked work.
5. Exit.

Hard rules:
- Do not choose work outside the deterministic router.
- Gemini may draft code, but Codex review is mandatory before acceptance; leave
  Gemini code tasks in REVIEW and do not self-approve or move them to PIPELINE.
- Keep operator-facing phase names Q-only.
- Never enable T_Live or AutoTrading.
- Never start terminal64.exe manually.
- Do not interrupt active T1-T10 backtests unless OWNER explicitly says so.
- Pipeline verdicts come only from pipeline evidence.
- Edge Lab work must fit the active charter: FTMO + DXZ target, <=5% daily DD,
  <=10% total DD, mandatory news blackout, swing/scalping horizon only, no HFT,
  no martingale/grid, mechanical only, no ML in EA.
- Strategy card drafts go to D:/QM/strategy_farm/artifacts/cards_review/.
"""


def process_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except Exception:
        return False
    return True


def acquire_lock(agent: str, stale_minutes: int, slot: int = 1) -> tuple[bool, dict[str, Any]]:
    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    lock_name = f"{agent}_orchestration.lock" if slot == 1 else f"{agent}_orchestration_{slot}.lock"
    lock_path = LOCK_DIR / lock_name
    now = time.time()
    if lock_path.exists():
        try:
            data = json.loads(lock_path.read_text(encoding="utf-8"))
        except Exception:
            data = {}
        pid = int(data.get("pid") or 0)
        age_sec = now - lock_path.stat().st_mtime
        if age_sec < stale_minutes * 60 and process_alive(pid):
            return False, {
                "lock_path": str(lock_path),
                "reason": "previous_run_active",
                "pid": pid,
                "age_sec": round(age_sec, 1),
            }
        if age_sec < stale_minutes * 60 and not pid:
            return False, {
                "lock_path": str(lock_path),
                "reason": "recent_lock_without_pid",
                "age_sec": round(age_sec, 1),
            }
    payload = {
        "agent": agent,
        "slot": slot,
        "pid": os.getpid(),
        "started_at": dt.datetime.now(dt.UTC).isoformat(),
    }
    lock_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    return True, {"lock_path": str(lock_path)}


def release_lock(lock_info: dict[str, Any]) -> None:
    path = Path(str(lock_info.get("lock_path") or ""))
    try:
        if path.exists():
            path.unlink()
    except OSError:
        pass


def command_for(agent: str, cwd: Path) -> list[str]:
    cli = resolve_cli(agent)
    if agent == "codex":
        model_args = ["-m", CODEX_HEADLESS_MODEL] if CODEX_HEADLESS_MODEL else []
        return [
            cli,
            "exec",
            *model_args,
            "--dangerously-bypass-approvals-and-sandbox",
            "--cd",
            str(cwd),
        ]
    if agent == "gemini":
        # Sandbox whitelist. By default gemini-cli only sees the worktree.
        # Extra paths are needed for:
        #  - Dropbox-mining initiative (Wave-A* video source folders, project memo
        #    `project_dropbox_strategy_research_2026-05-23`)
        #  - cards_review write target (so gemini can write artifacts directly
        #    instead of staging inside the worktree and requiring a copy step)
        # `--include-directories` accepts comma-separated or repeated flag (per
        # `gemini --help`); using comma-separated for compactness.
        extra_dirs = [str(cwd)]
        dropbox_forex = Path(r"C:\Users\Administrator\Dropbox\Finanzen\Forex")
        if dropbox_forex.exists():
            extra_dirs.append(str(dropbox_forex))
        cards_review = FARM_ROOT / "artifacts" / "cards_review"
        if cards_review.exists():
            extra_dirs.append(str(cards_review))
        node = shutil.which("node.exe") or shutil.which("node")
        if node and GEMINI_NODE_BUNDLE.exists():
            launcher = [node, str(GEMINI_NODE_BUNDLE)]
        else:
            launcher = [cli]
        model_args = ["--model", GEMINI_HEADLESS_MODEL] if GEMINI_HEADLESS_MODEL else []
        return [
            *launcher,
            *model_args,
            "--prompt",
            "Execute the single-pass QuantMechanica orchestration instructions from stdin.",
            "--approval-mode",
            "yolo",
            "--skip-trust",
            "--output-format",
            "text",
            "--include-directories",
            ",".join(extra_dirs),
        ]
    if agent == "claude":
        model_args = ["--model", CLAUDE_HEADLESS_MODEL] if CLAUDE_HEADLESS_MODEL else []
        return [
            cli,
            "-p",
            *model_args,
            "--dangerously-skip-permissions",
            "--add-dir",
            str(cwd),
        ]
    raise ValueError(f"unsupported agent: {agent}")


def worktree_path(agent: str, slot: int) -> Path:
    return WORKTREE_ROOT / f"{agent}-orchestration-{slot}"


def branch_name(agent: str, slot: int) -> str:
    return f"agents/{agent}-orchestration-{slot}"


def run_git(args: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )


def push_worktree_branch(cwd: Path, branch: str, timeout: int = 120) -> dict[str, Any]:
    """Push an agent worktree branch without invoking interactive GCM.

    Scheduled tasks run as SYSTEM/session-0, where Git Credential Manager can
    hang waiting for a desktop prompt. A token supplied through the task
    environment lets git authenticate non-interactively without writing a
    credential file or committing a secret.
    """
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        return {
            "attempted": False,
            "ok": False,
            "reason": "missing_GH_TOKEN_or_GITHUB_TOKEN",
            "owner_action": "Provide a repo contents:write token in the scheduled-task environment.",
        }
    if not cwd.exists():
        return {"attempted": False, "ok": False, "reason": "worktree_missing", "cwd": str(cwd)}

    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GCM_INTERACTIVE"] = "never"
    # Classic PATs use Basic auth; rewrite the github.com URL to embed credentials
    # so GCM is bypassed entirely in headless/session-0 contexts.
    cmd = [
        "git",
        "-C",
        str(cwd),
        "-c",
        f"url.https://x-access-token:{token}@github.com/.insteadOf=https://github.com/",
        "push",
        "origin",
        f"HEAD:{branch}",
    ]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        return {
            "attempted": True,
            "ok": proc.returncode == 0,
            "returncode": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.replace(token, "<redacted>").strip(),
            "branch": branch,
        }
    except subprocess.TimeoutExpired:
        return {
            "attempted": True,
            "ok": False,
            "returncode": 124,
            "error": "push_timeout",
            "branch": branch,
        }


def ensure_worktree(agent: str, slot: int) -> dict[str, Any]:
    path = worktree_path(agent, slot)
    branch = branch_name(agent, slot)
    if path.exists():
        check = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=20,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        if check.returncode == 0:
            return {"path": str(path), "branch": branch, "created": False}
        return {
            "path": str(path),
            "branch": branch,
            "created": False,
            "ok": False,
            "error": "path_exists_but_not_git_worktree",
        }

    WORKTREE_ROOT.mkdir(parents=True, exist_ok=True)
    add = run_git(["worktree", "add", "-B", branch, str(path), "HEAD"], timeout=120)
    return {
        "path": str(path),
        "branch": branch,
        "created": add.returncode == 0,
        "ok": add.returncode == 0,
        "returncode": add.returncode,
        "stdout": add.stdout.strip(),
        "stderr": add.stderr.strip(),
    }


def run_agent_slot(agent: str, slot: int, dry_run: bool, stale_minutes: int, timeout_minutes: int) -> dict[str, Any]:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = utc_stamp()
    if agent == "gemini":
        cwd = REPO_ROOT
        worktree = {
            "path": str(REPO_ROOT),
            "branch": "shared-repo",
            "created": False,
            "shared_repo": True,
            "reason": "gemini_uses_current_farm_code_and_router_state",
        }
    else:
        cwd = REPO_ROOT if agent == "codex" and slot == 0 else worktree_path(agent, slot)
        worktree = ensure_worktree(agent, slot)
    prompt = build_prompt(agent, cwd)
    prompt_path = LOG_DIR / f"{agent}_orchestration_slot{slot}_prompt_{stamp}.md"
    live_log = LOG_DIR / f"{agent}_orchestration_slot{slot}_{stamp}.live.log"
    result_path = LOG_DIR / f"{agent}_orchestration_slot{slot}_{stamp}.json"
    prompt_path.write_text(prompt, encoding="utf-8", newline="\n")

    if worktree.get("ok") is False:
        payload = {
            "agent": agent,
            "slot": slot,
            "ok": False,
            "returncode": 1,
            "worktree": worktree,
            "result_path": str(result_path),
        }
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        return payload

    locked, lock_info = acquire_lock(agent, stale_minutes, slot=slot)
    if not locked:
        payload = {
            "agent": agent,
            "slot": slot,
            "ok": True,
            "skipped": True,
            "reason": lock_info.get("reason"),
            "lock": lock_info,
            "result_path": str(result_path),
        }
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        return payload

    cmd = command_for(agent, cwd)
    payload: dict[str, Any] = {
        "agent": agent,
        "slot": slot,
        "dry_run": dry_run,
        "prompt_path": str(prompt_path),
        "live_log": str(live_log),
        "command": cmd,
        "cwd": str(cwd),
        "worktree": worktree,
        "started_at": dt.datetime.now(dt.UTC).isoformat(),
    }
    try:
        if dry_run:
            payload.update({"ok": True, "returncode": 0, "dry_run_verified": True})
            return payload
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        with open(prompt_path, "rb") as stdin_f, open(live_log, "wb") as stdout_f:
            proc = subprocess.Popen(
                cmd,
                cwd=str(cwd),
                stdin=stdin_f,
                stdout=stdout_f,
                stderr=subprocess.STDOUT,
                env=agent_env(agent),
                shell=(agent != "gemini"),
                creationflags=creationflags,
                close_fds=True,
            )
            payload["pid"] = proc.pid
            try:
                payload["returncode"] = proc.wait(timeout=timeout_minutes * 60)
                payload["ok"] = payload["returncode"] == 0
            except subprocess.TimeoutExpired:
                proc.kill()
                payload.update({"ok": False, "returncode": 124, "error": "timeout"})
        if worktree.get("shared_repo"):
            payload["push"] = {
                "attempted": False,
                "ok": True,
                "reason": "shared_repo_not_pushed_by_headless_agent",
            }
        else:
            payload["push"] = push_worktree_branch(cwd, branch_name(agent, slot))
        return payload
    except Exception as exc:
        payload.update({"ok": False, "returncode": 1, "error": repr(exc)})
        return payload
    finally:
        payload["finished_at"] = dt.datetime.now(dt.UTC).isoformat()
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        release_lock(lock_info)


def claude_work_available() -> dict[str, Any]:
    """Pre-spawn check to avoid empty or low-value Claude invocations.

    Claude is quota-constrained. It should only wake for explicit router work
    already assigned to Claude, or for unrouted premium work that asks for
    Claude-only capabilities such as `summary`. G0/card mass review is handled
    by Codex while the pump Claude lane is disabled.
    """
    import sqlite3 as _sqlite3
    db = FARM_ROOT / "state" / "farm_state.sqlite"
    if not db.exists():
        return {"any_work": True, "reason": "db_missing_assume_work"}
    try:
        con = _sqlite3.connect(db)
        con.row_factory = _sqlite3.Row
        n_assigned = con.execute(
            """
            SELECT COUNT(*) FROM agent_tasks
            WHERE assigned_agent='claude' AND state IN ('TODO','IN_PROGRESS')
            """
        ).fetchone()[0]
        n_premium_backlog = con.execute(
            """
            SELECT COUNT(*) FROM agent_tasks
            WHERE state IN ('BACKLOG','TODO')
              AND assigned_agent IS NULL
              AND (
                required_capabilities_json LIKE '%"summary"%'
                OR budget_class IN ('premium','claude','owner')
              )
            """
        ).fetchone()[0]
        con.close()
        any_work = (n_assigned + n_premium_backlog) > 0
        return {
            "any_work": any_work,
            "claude_assigned": n_assigned,
            "premium_backlog": n_premium_backlog,
        }
    except Exception as exc:
        # Fail OPEN — if the check fails, spawn anyway rather than starve Claude.
        return {"any_work": True, "reason": f"work_check_error:{exc!r}"}


def _parse_dt(value: str) -> dt.datetime | None:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def _claude_budget_policy() -> dict[str, Any]:
    defaults: dict[str, Any] = {
        "enabled": True,
        "max_runs_per_day": 0,
        "min_minutes_between_runs": 0,
        "max_sessions_per_run": 3,
    }
    if not CLAUDE_BUDGET_POLICY.exists():
        return defaults
    try:
        loaded = json.loads(CLAUDE_BUDGET_POLICY.read_text(encoding="utf-8"))
    except Exception as exc:
        policy = dict(defaults)
        policy["policy_error"] = repr(exc)
        return policy
    if not isinstance(loaded, dict):
        policy = dict(defaults)
        policy["policy_error"] = "policy_not_object"
        return policy
    policy = dict(defaults)
    policy.update(loaded)
    return policy


def _claude_non_skipped_runs_today(now: dt.datetime, count_from: dt.datetime | None = None) -> list[dt.datetime]:
    local_now = now.astimezone()
    local_midnight = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
    cutoff = count_from or local_midnight.astimezone(dt.UTC)
    started: list[dt.datetime] = []
    for path in LOG_DIR.glob("claude_orchestration_slot*_*.json"):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if payload.get("agent") != "claude" or payload.get("skipped"):
            continue
        ts = _parse_dt(str(payload.get("started_at") or payload.get("finished_at") or ""))
        if ts and ts >= cutoff:
            started.append(ts)
    return sorted(started)


def claude_budget_check(max_sessions: int) -> dict[str, Any]:
    policy = _claude_budget_policy()
    now = dt.datetime.now(dt.UTC)
    if not bool(policy.get("enabled", True)):
        return {"allowed": False, "reason": "budget_policy_disabled", "policy": policy}

    not_after = str(policy.get("not_after_local") or policy.get("not_after_utc") or "").strip()
    if not_after:
        deadline = _parse_dt(not_after)
        if deadline and now >= deadline:
            return {"allowed": False, "reason": "budget_deadline_reached", "deadline": not_after, "policy": policy}

    count_from_value = str(policy.get("count_from_local") or policy.get("count_from_utc") or "").strip()
    count_from = _parse_dt(count_from_value) if count_from_value else None
    runs_today = _claude_non_skipped_runs_today(now, count_from=count_from)
    max_runs = int(policy.get("max_runs_per_day") or 0)
    if max_runs > 0 and len(runs_today) >= max_runs:
        return {
            "allowed": False,
            "reason": "daily_run_budget_exhausted",
            "runs_today": len(runs_today),
            "max_runs_per_day": max_runs,
            "policy": policy,
        }

    min_gap = int(policy.get("min_minutes_between_runs") or 0)
    if min_gap > 0 and runs_today:
        elapsed = (now - runs_today[-1]).total_seconds() / 60
        if elapsed < min_gap:
            return {
                "allowed": False,
                "reason": "min_interval_not_elapsed",
                "minutes_since_last_run": round(elapsed, 1),
                "min_minutes_between_runs": min_gap,
                "policy": policy,
            }

    cap = max(1, int(policy.get("max_sessions_per_run") or 1))
    return {
        "allowed": True,
        "policy": policy,
        "runs_today": len(runs_today),
        "requested_max_sessions": max_sessions,
        "effective_max_sessions": min(max_sessions, cap),
    }


def _agent_tasks_work_available(agent: str) -> dict[str, Any]:
    """Pre-spawn guard for Codex/Gemini: skip if no actionable work in agent_tasks.

    Checks two signals:
    - Tasks already assigned to this agent with state TODO or IN_PROGRESS
    - Unrouted BACKLOG tasks (route-many might assign them to this agent)
    Fails OPEN so a DB error never starves the agent.
    """
    import sqlite3 as _sqlite3
    db = FARM_ROOT / "state" / "farm_state.sqlite"
    if not db.exists():
        return {"any_work": True, "reason": "db_missing_assume_work"}
    try:
        con = _sqlite3.connect(db)
        con.row_factory = _sqlite3.Row
        n_assigned = con.execute(
            "SELECT COUNT(*) FROM agent_tasks WHERE assigned_agent=? AND state IN ('TODO','IN_PROGRESS')",
            (agent,),
        ).fetchone()[0]
        n_backlog = con.execute(
            "SELECT COUNT(*) FROM agent_tasks WHERE state='BACKLOG'",
        ).fetchone()[0]
        con.close()
        any_work = (n_assigned + n_backlog) > 0
        return {
            "any_work": any_work,
            f"{agent}_assigned": n_assigned,
            "backlog_unrouted": n_backlog,
        }
    except Exception as exc:
        # Fail OPEN — if the check fails, spawn anyway rather than starve the agent.
        return {"any_work": True, "reason": f"work_check_error:{exc!r}"}


def run_agent(agent: str, dry_run: bool, stale_minutes: int, timeout_minutes: int, max_sessions: int) -> dict[str, Any]:
    if agent == "claude" and CLAUDE_DISABLED_FLAG.exists():
        return {
            "agent": agent,
            "ok": True,
            "skipped": True,
            "reason": "claude_disabled_flag",
            "flag": str(CLAUDE_DISABLED_FLAG),
        }
    if agent == "claude" and not dry_run:
        budget = claude_budget_check(max_sessions)
        if not budget.get("allowed"):
            return {
                "agent": agent,
                "ok": True,
                "skipped": True,
                "reason": budget.get("reason", "claude_budget_blocked"),
                "budget_check": budget,
            }
        max_sessions = int(budget.get("effective_max_sessions") or 1)
    # PT12 2026-05-24 — Claude empty-spawn guard.
    if agent == "claude" and not dry_run:
        wa = claude_work_available()
        if not wa.get("any_work"):
            return {
                "agent": agent,
                "ok": True,
                "skipped": True,
                "reason": "no_actionable_work",
                "work_available_check": wa,
            }
    # 2026-05-30 — Codex/Gemini empty-spawn guard (mirrors PT12 logic for agent_tasks).
    if agent in ("codex", "gemini") and not dry_run:
        wa = _agent_tasks_work_available(agent)
        if not wa.get("any_work"):
            return {
                "agent": agent,
                "ok": True,
                "skipped": True,
                "reason": "no_actionable_work",
                "work_available_check": wa,
            }
    session_count = max(1, max_sessions)
    if agent != "claude":
        session_count = 1
    if session_count == 1:
        results = [run_agent_slot(agent, 1, dry_run, stale_minutes, timeout_minutes)]
    else:
        with ThreadPoolExecutor(max_workers=session_count) as executor:
            futures = [
                executor.submit(run_agent_slot, agent, slot, dry_run, stale_minutes, timeout_minutes)
                for slot in range(1, session_count + 1)
            ]
            results = [future.result() for future in futures]
    ok = all(bool(r.get("ok")) for r in results)
    return {
        "agent": agent,
        "ok": ok,
        "returncode": 0 if ok else 1,
        "max_sessions": session_count,
        "results": results,
    }


def main() -> int:
    os.environ.setdefault("QM_AGENT_ID", "controller")
    parser = argparse.ArgumentParser(description="Run one headless agent orchestration pass.")
    parser.add_argument("--agent", choices=("codex", "gemini", "claude"), required=True)
    parser.add_argument("--dry-run", action="store_true", help="Verify prompt/lock/command without launching the model.")
    parser.add_argument("--stale-minutes", type=int, default=180)
    parser.add_argument("--timeout-minutes", type=int, default=240)
    parser.add_argument("--max-sessions", type=int, default=1, help="Claude-only parallel slot count.")
    args = parser.parse_args()
    result = run_agent(args.agent, args.dry_run, args.stale_minutes, args.timeout_minutes, args.max_sessions)
    print(json.dumps(result, indent=2, sort_keys=True))
    return int(result.get("returncode", 0) or 0)


if __name__ == "__main__":
    raise SystemExit(main())
