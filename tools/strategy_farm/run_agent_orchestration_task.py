"""Headless single-pass orchestration wrapper for Codex/Gemini/Claude.

The Windows scheduler owns cadence. This wrapper owns only one fire:
take an overlap lock, launch the requested agent in non-interactive mode with
a single-pass orchestration prompt, wait for it to exit, and write evidence.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import socket
import subprocess
import sys
import threading
import time
import traceback
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any


def _pythonw_excepthook(exc_type: type[BaseException], exc: BaseException, tb: Any) -> None:
    """Persist otherwise invisible top-level pythonw failures."""
    try:
        crash_log = globals().get(
            "PYTHONW_CRASH_LOG",
            Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
            / "logs"
            / "agent_orchestration_pythonw_crash.log",
        )
        crash_log.parent.mkdir(parents=True, exist_ok=True)
        stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
        with crash_log.open("a", encoding="utf-8") as handle:
            handle.write(f"\n[{stamp}] uncaught top-level exception\n")
            traceback.print_exception(exc_type, exc, tb, file=handle)
    except Exception:
        # An exception hook must never mask the original failure.
        pass


if __name__ == "__main__":
    # Install before project-local imports so pythonw import/startup failures are
    # durable even when the normal per-run log has not been created.
    sys.excepthook = _pythonw_excepthook


try:
    from managed_codex import (
        release_managed_codex_process,
        spawn_managed_codex,
        terminate_managed_codex_pid,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.managed_codex import (
        release_managed_codex_process,
        spawn_managed_codex,
        terminate_managed_codex_pid,
    )

try:
    from process_identity import get_process_identity
except ModuleNotFoundError:
    try:
        from tools.strategy_farm.process_identity import get_process_identity
    except ModuleNotFoundError:
        from process_identity import get_process_identity  # script-style import (sys.path = tools/strategy_farm)

try:
    import quota_spawn_gate
except ModuleNotFoundError:
    from tools.strategy_farm import quota_spawn_gate

try:
    import agent_router
except ModuleNotFoundError:
    from tools.strategy_farm import agent_router


REPO_ROOT = Path(r"C:\QM\repo")
WORKTREE_ROOT = Path(os.environ.get("QM_AGENT_WORKTREE_ROOT", r"C:\QM\worktrees"))
FARM_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
LOG_DIR = FARM_ROOT / "logs"
PYTHONW_CRASH_LOG = LOG_DIR / "agent_orchestration_pythonw_crash.log"
LOCK_DIR = FARM_ROOT / "locks"
INTERACTIVE_ORCHESTRATOR_FLAG = FARM_ROOT / "state" / "INTERACTIVE_ORCHESTRATOR.flag"
NO_CHANGE_STATE_DIR = FARM_ROOT / "state" / "orchestration_no_change"
HEADLESS_SESSION_LEASE_TTL_MINUTES = 30
INTERACTIVE_FLAG_STALE_MINUTES = 30
PYTHON_EXE = Path(r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe")
CODEX_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd")
# Antigravity CLI (agy) — replaces the deprecated gemini-cli for the "gemini" lane
# (2026-06-29). Headless via `agy -p`; auth = Windows Credential Manager (gemini:antigravity),
# OWNER-authenticated, no API key. agy does NOT read stdin -> prompt passed as a -p file-pointer.
# Candidate list, not a single env-derived path: the scheduled task runs as SYSTEM,
# whose LOCALAPPDATA points into systemprofile — resolving agy ONLY via the env var
# silently fell back to the dead npm gemini-cli on every scheduled slot (2026-07-06/07).
_AGY_BIN_CANDIDATES = [
    Path(os.environ.get("LOCALAPPDATA", r"C:\Users\Administrator\AppData\Local")) / "agy" / "bin" / "agy.exe",
    Path(r"C:\Users\Administrator\AppData\Local\agy\bin\agy.exe"),
]
AGY_BIN = next((p for p in _AGY_BIN_CANDIDATES if p.exists()), _AGY_BIN_CANDIDATES[-1])
# agy hangs on non-TTY stdout (redirected file/pipe). The ConPTY runner gives agy a real
# pseudo-console via pywinpty so it runs headless; the runner forwards output to our stdout.
CONPTY_RUNNER = REPO_ROOT / "tools" / "strategy_farm" / "agy_conpty_run.py"
CLAUDE_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\claude.cmd")
CODEX_HOME = Path(os.environ.get("CODEX_HOME", r"C:\Users\Administrator\.codex"))
AGENT_USER_HOME = Path(r"C:\Users\Administrator")
CLAUDE_DISABLED_FLAG = FARM_ROOT / "CLAUDE_DISABLED.flag"
CLAUDE_BUDGET_POLICY = FARM_ROOT / "CLAUDE_BUDGET_POLICY.json"
# Claude-lane drain fix (review c1 M2, OWNER-DEC-CBE-20260915 §35): after a
# session finishes its pinned task it leases the NEXT eligible task and works it,
# up to this many tasks per session, so --max-sessions 1 does not degrade the
# lane to one task per 15-min cycle. Override via CLAUDE_BUDGET_POLICY.json
# ("max_tasks_per_session") or the QM_CLAUDE_MAX_TASKS_PER_SESSION env var.
CLAUDE_MAX_TASKS_PER_SESSION_DEFAULT = 4
# Codex pinned fan-out uses the same bounded sequential drain shape as Claude,
# but its budget is independent of CLAUDE_BUDGET_POLICY.json.  The legacy Codex
# --max-sessions 1 path does not consult this value and remains task-agnostic.
CODEX_MAX_TASKS_PER_SESSION_DEFAULT = 4
# A dirty/diverged legacy slot is never reset or overwritten.  Search a bounded
# number of slot names for enough clean/current worktrees and fail closed if the
# requested concurrency cannot be prepared safely.
PINNED_WORKTREE_SLOT_SCAN_LIMIT = 32
# Kimi Code CLI (OWNER-DEC-KIMI-INTEGRATION-20260915,
# KIMI_INTEGRATION_ARCHITECTURE.md §1, §5.4). Pinned path: kimi.exe is NOT on
# PATH and its auto-updater is on, so the pinned constant plus the adapter's
# per-run version stamp is the version-pinning defence.
KIMI_BIN = Path(r"C:\Users\Administrator\.kimi-code\bin\kimi.exe")
# Adapter config that carries the per-capability model map (§3.3). Read at
# dispatch if present; otherwise the documented default model is used.
KIMI_ADAPTER_CONFIG = REPO_ROOT / "tools" / "strategy_farm" / "config" / "kimi_adapter.v1.json"
# MaxSessions is hard-capped at 1 for kimi: the OAuth credential has a 15-min
# rolling token and a refresh WRITE race across concurrent processes corrupts
# the login (Codex-class failure). The cross-plane guarantee is the adapter's
# machine-wide single-flight lock (§3.6); this cap is the lane-level belt.
KIMI_MAX_SESSIONS = 1
_KIMI_MODEL_ENV_OVERRIDE = os.environ.get("QM_KIMI_HEADLESS_MODEL", "").strip()
# Documented default model (§3.3): the K2.8 default with the 1M-token context.
KIMI_HEADLESS_MODEL = _KIMI_MODEL_ENV_OVERRIDE or "kimi-code/kimi-for-coding"

# --- Headless model selection (weekly-quota cost control) -------------------
# Each headless cycle is mostly routine orchestration (claim work, run gates,
# write the cycle log, monitor health) — work that does not need the top model.
# Default Claude headless to Sonnet and let OWNER raise to opus per-run via env;
# Codex/Antigravity default to their account model unless an env override is set.
# Interactive sessions (e.g. the senior agent) are unaffected — they ignore
# these vars. Empty string => omit the flag (use the CLI/account default).
#   $env:QM_CLAUDE_HEADLESS_MODEL = 'opus'   # bump a cycle back to Opus
#   $env:QM_CODEX_HEADLESS_MODEL  = 'gpt-5-codex'  # explicit model override
# OWNER-approved 2026-08-03 5x-plan matrix: task class sets Codex effort
# (max/high/medium), Claude remains Sonnet unless a task deliberately selects
# Opus, and quota pressure may defer volume but never lower the selected tier.
# `with_tiers=False`: these are IMPORT-TIME fallbacks. A tier profile is only
# valid for the instant its rolling 5h window was measured (model routing
# doctrine 2026-09-04 section 3.1), so freezing one for the lifetime of the
# process would dispatch at/above budget forever and would also read the
# ledger on every import. The tier is resolved freshly in
# `headless_model_contract` instead; the constants below stay the
# pre-doctrine single-model contract (`model_matrix.codex.model`).
_DEFAULT_CODEX_INVOCATION = (
    quota_spawn_gate.invocation_profile("codex", "build_ea", with_tiers=False) or {}
)
_DEFAULT_CLAUDE_INVOCATION = quota_spawn_gate.invocation_profile("claude", "build_ea") or {}
_CODEX_MODEL_ENV_OVERRIDE = os.environ.get("QM_CODEX_HEADLESS_MODEL", "").strip()
_CLAUDE_MODEL_ENV_OVERRIDE = os.environ.get("QM_CLAUDE_HEADLESS_MODEL", "").strip()
CLAUDE_HEADLESS_MODEL = _CLAUDE_MODEL_ENV_OVERRIDE or str(
    _DEFAULT_CLAUDE_INVOCATION.get("model") or "sonnet"
)
CODEX_HEADLESS_MODEL = _CODEX_MODEL_ENV_OVERRIDE or str(
    _DEFAULT_CODEX_INVOCATION.get("model") or ""
)
CODEX_HEADLESS_EFFORT = str(_DEFAULT_CODEX_INVOCATION.get("reasoning_effort") or "high")
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
        # Antigravity CLI (agy) is the live backend; gemini-cli is DEAD (OWNER
        # 2026-07-02) and must never be silently revived. No deprecated npm
        # fallback exists: if agy is missing we return its expected path and let the
        # spawn fail LOUDLY (visible in the result JSON) instead of running the
        # deprecated CLI with incompatible args, which burned every scheduled
        # slot 2026-07-06/07 while reporting only a generic rc=1.
        if AGY_BIN.exists():
            return str(AGY_BIN)
        found = shutil.which("agy")
        if found:
            return found
        return str(AGY_BIN)
    if agent == "claude":
        found = shutil.which("claude.cmd") or shutil.which("claude")
        if found:
            return found
        return str(CLAUDE_FALLBACK if CLAUDE_FALLBACK.exists() else "claude")
    if agent == "kimi":
        # kimi.exe is not on PATH (audit §1). Return the pinned path and let a
        # missing binary fail LOUDLY in the adapter (status cli_missing) instead
        # of resolving a wrong CLI. No npm/other fallback exists for kimi.
        return str(KIMI_BIN)
    raise ValueError(f"unsupported agent: {agent}")


def agent_env(agent: str, assigned_task_id: str | None = None) -> dict[str, str]:
    env = os.environ.copy()
    env["QM_AGENT_ID"] = agent
    # Fan-out fix (OWNER-DEC-CBE-20260915 §35): when the launcher has leased a
    # single concrete task to this session it pins the id here, so the child
    # process can refuse any work other than the one it owns. Absent for the
    # task-agnostic single-session lanes (codex/gemini).
    if assigned_task_id:
        env["QM_ASSIGNED_TASK_ID"] = str(assigned_task_id)
    if agent == "codex":
        env["CODEX_HOME"] = str(CODEX_HOME)
    if agent == "gemini":
        # Scheduled tasks run as SYSTEM; point agy at the operator profile where
        # its Windows Credential Manager token and workspace trust are configured.
        env["USERPROFILE"] = str(AGENT_USER_HOME)
        env["HOME"] = str(AGENT_USER_HOME)
        env["HOMEDRIVE"] = "C:"
        env["HOMEPATH"] = r"\Users\Administrator"
        env.setdefault("TERM", "dumb")
        env.setdefault("NO_COLOR", "1")
        env.setdefault("FORCE_COLOR", "0")
        env.setdefault("CI", "1")
    if agent == "claude":
        env["USERPROFILE"] = str(AGENT_USER_HOME)
        env["HOME"] = str(AGENT_USER_HOME)
        env["HOMEDRIVE"] = "C:"
        env["HOMEPATH"] = r"\Users\Administrator"
    if agent == "kimi":
        # Point kimi at the operator profile so its OAuth credential file
        # (C:\Users\Administrator\.kimi-code\credentials\kimi-code.json) resolves
        # under the SYSTEM scheduled task, mirroring the claude lane (§3.6).
        env["USERPROFILE"] = str(AGENT_USER_HOME)
        env["HOME"] = str(AGENT_USER_HOME)
        env["HOMEDRIVE"] = "C:"
        env["HOMEPATH"] = r"\Users\Administrator"
    return env


def build_prompt(agent: str, cwd: Path, assigned_task_id: str | None = None) -> str:
    edge_charter = cwd / "docs" / "ops" / "EDGE_LAB_CHARTER_2026-05-22.md"
    profitability = cwd / "docs" / "ops" / "PROFITABILITY_TRACK_2026-05-21.md"
    canonical_farmctl = (REPO_ROOT / "tools" / "strategy_farm" / "farmctl.py").as_posix()
    canonical_router = (REPO_ROOT / "tools" / "strategy_farm" / "agent_router.py").as_posix()
    if agent == "kimi":
        # Research-only lane prompt (KIMI_INTEGRATION_ARCHITECTURE.md §4, §5.4).
        # Kimi is a capability provider, never an orchestrator. The restrictions
        # below are prompt-level REINFORCEMENT of the code-level guards (no
        # code/ops caps, no verdict-write path, no farmctl mutation reachable);
        # they are stated so a headless kimi run has no ambiguity about scope.
        return f"""You are kimi for QuantMechanica, launched by a headless scheduled task.

Execute exactly one single-pass RESEARCH cycle, then exit. Do not start a
15-minute sleep loop; the Windows scheduler provides cadence.

Working directory: {cwd.as_posix()}

Scope — you are a research-only capability provider:
1. Run only for tasks the deterministic router assigned to the kimi lane:
   python {canonical_router} list-tasks --agent kimi --state IN_PROGRESS
   You never choose your own work and never route. Do NOT run `agent_router.py run`,
   `route-many`, `route-once`, or `replenish`.
2. For each IN_PROGRESS task assigned to kimi, produce a durable research artifact
   (edge discovery, hypothesis authoring, cross-experiment synthesis, or an
   independent research critique) and leave it in REVIEW:
   python {canonical_router} update-task <task_id> --state REVIEW --artifact-path "<artifact>" --verdict "<short_verdict>"
3. Repeat until the kimi IN_PROGRESS list is empty, then exit.

Hard rules for the kimi lane (research-only):
- You may ONLY work tasks assigned to the kimi lane. Ignore every other lane's work.
- NEVER run any farmctl mutation subcommand (no approve-card, close-review,
  enqueue-backtest, pipeline advance, or any state-changing command). Read-only
  `python {canonical_farmctl} health` is the only farmctl call permitted.
- NEVER write a pipeline verdict or move a task to APPROVED/PIPELINE/PASSED. The
  pipeline is the sole judge; an LLM "PASS" is never a pipeline PASS. Leave every
  artifact in REVIEW for orchestrator review.
- NEVER touch T_Live paths (C:/QM/mt5/T_Live), the gate manifest, live book, or
  AutoTrading in any way.
- Machine learning may inform OFFLINE research only. Any strategy you propose must
  reduce to explicit mechanical rules (finite parameters, deterministic logic, no
  inference API, no model file, no online learning) before it could enter Q00.
  ML is FORBIDDEN inside any EA or its live/backtest decision engine.
- Write REVIEW artifacts under docs/ops/evidence/ (absolute canonical path
  C:/QM/repo/docs/ops/evidence/) like the other lanes; strategy-card drafts go to
  D:/QM/strategy_farm/artifacts/cards_review/. Every quantitative claim must cite a
  computed output file, never an LLM-computed number.
- Never start terminal64.exe; never interrupt T1-T10 backtests.
"""
    # G: drive (Google Drive for Desktop) is mounted per-user. Antigravity/agy runs as SYSTEM
    # in a scheduled task with no G: mount -> any G: access raises PermissionError and
    # strands the task IN_PROGRESS (Rule 13, OPERATING_RULES_2026-07-03). Skip G: paths
    # for gemini; Claude/Codex run interactively or have G: via the user session.
    if agent == "gemini":
        vault_lines = ""
    else:
        vault_lines = (
            "- G:/My Drive/QuantMechanica - Company Reference/08 Current State/Current Operating State.md\n"
            "- G:/My Drive/QuantMechanica - Company Reference/02 Org/AI Agent Routing and Role Contracts.md\n"
            "- G:/My Drive/QuantMechanica - Company Reference/12 ToDo/_INDEX.md\n"
        )
    if assigned_task_id:
        # Fan-out fix (OWNER-DEC-CBE-20260915 §35): this session was launched with
        # a distinct pid-owned exec-lease on exactly ONE task. The prompt pins that
        # id so the session never touches a sibling session's ticket even if the
        # lease layer ever regresses (defence in depth, ticket 3e0c8b83).
        task_cycle = f"""2. Work ONLY task `{assigned_task_id}` (also in env QM_ASSIGNED_TASK_ID). The
   launcher already holds a distinct exec-lease (`agent_task_exec:{assigned_task_id}`)
   for this session, so you own it exclusively. Do NOT list all IN_PROGRESS tasks
   and work them - that is the fan-out defect this pin closes. If task
   `{assigned_task_id}` is no longer IN_PROGRESS for {agent}, or is not visible to
   you, do nothing and exit idle; never pick a different task.
   Read its payload and skills, produce a durable artifact, run focused
   verification, then update the router with:
   python {canonical_router} update-task {assigned_task_id} --state REVIEW --artifact-path "<artifact>" --verdict "<short_verdict>"
   Write your artifact under a task-scoped subdir keyed by this id
   (e.g. `<evidence_dir>/task_{assigned_task_id}/` or `slot<N>_*/`), never onto a
   path a sibling session may also write - this keeps parallel sessions idempotent.
3. Do NOT loop over other tasks. After task `{assigned_task_id}` is in REVIEW (or
   found not-actionable), stop taking work.
4. Run `python {canonical_farmctl} health` for a final sanity check. Do not invent untracked work.
5. Exit."""
    else:
        task_cycle = f"""2. For every IN_PROGRESS task assigned to {agent}, in ascending numeric priority:
   The router claims a 30-minute spawn lease (`agent_task:<task_id>`) when it
   moves work to IN_PROGRESS. If you were launched directly for a specific task
   outside the router path, acquire that same lease before doing any work; if the
   lease is live, skip/defer instead of duplicating the task.
   read payload and skills, produce a durable artifact, run focused verification,
   then update the router with:
   python {canonical_router} update-task <task_id> --state REVIEW --artifact-path "<artifact>" --verdict "<short_verdict>"
3. Repeat task handling until `python {canonical_router} list-tasks --agent {agent} --state IN_PROGRESS`
   returns an empty list. Ignore REVIEW/BLOCKED/PASSED tasks; they are not yours.
4. If no task remains, run `python {canonical_farmctl} health` and check QM5_10260 queue state. Do not invent untracked work.
5. Exit."""
    # 2026-09-21 (Fable): the agy headless runner terminates the session ~5 s after the
    # root agent goes idle. Two consecutive gemini cycles (19:00Z, 19:15Z) launched
    # `farmctl health` as a BACKGROUND task, idled, and were killed at step 1 without
    # ever reading their task list. The prompt therefore pins foreground execution for
    # gemini; it is a prompt-level rule, no launcher behaviour changes.
    execution_model = ""
    if agent == "gemini":
        execution_model = """
EXECUTION MODEL (binding for this headless runner): run every shell command in the
FOREGROUND and wait for its complete output before continuing. NEVER launch a command
as a background task and NEVER end your turn while a background task is pending - this
runner terminates the session about 5 seconds after the root agent goes idle, and on
2026-09-21 two consecutive cycles died at step 1 exactly that way. If a command is
slow (`farmctl health` can take a minute), still wait for it in the foreground.
"""
    return f"""You are {agent} for QuantMechanica, launched by a headless scheduled task.

Execute exactly one single-pass orchestration cycle, then exit. Do not start a
15-minute sleep loop; the Windows scheduler provides cadence.
{execution_model}
Working directory: {cwd.as_posix()}

Read first if needed:
{vault_lines}- {edge_charter}
- {profitability}

Cycle:
1. Run:
   python {canonical_farmctl} health
   python {canonical_router} status
   python {canonical_router} list-tasks --agent {agent} --state IN_PROGRESS

   DO NOT run `agent_router.py run`, `route-many`, `route-once`, or `replenish`.
   You consume work the router assigned to you; you never route. The router is its own scheduled task
   (QM_StrategyFarm_AgentRouter_5min) which always executes the canonical
   checkout C:/QM/repo. Your task workspace may be a worktree that is months
   behind, but every control-plane command above uses the absolute canonical
   script path. On 2026-08-22 an agent ran `run`/`route-many` from a checkout 12,210
   commits stale, whose router had neither the human-lane hold nor the registry
   writer gate, and it assigned an OWNER-only video ticket to a lane that cannot
   watch videos. A guard only exists in the code that runs it - so routing runs
   in exactly one place.
{task_cycle}

No-change dedupe:
- A recheck whose blocker facts have not changed must not create another timestamped
  evidence file, OPEN_ITEMS entry, or commit. Put only stable blocker facts and bound
  hashes/row IDs (no observation timestamp) in a canonical JSON file, then run:
  `python {REPO_ROOT.as_posix()}/tools/strategy_farm/run_agent_orchestration_task.py --agent {agent} --dedupe-no-change-task <task_id> --state-json <json> --artifact-path <existing_or_planned_evidence>`.
  Write/commit the planned evidence only when `write_allowed=true`; otherwise reuse
  `artifact_path` from the response and make no no-change commit.

Hard rules:
- Do not choose work outside the deterministic router.
- Gemini may draft code, but Codex review is mandatory before acceptance; leave
  Gemini code tasks in REVIEW and do not self-approve or move them to PIPELINE.
- Build guardrail (enforced by validate_build_guardrails.py + compile_ea +
  close-review): NEVER set qm_news_stale_max_hours above 336. A stale-news INIT
  failure is fixed by refreshing the news calendar seed (D:/QM/data/news_calendar
  + the FILE_COMMON copy), NOT by weakening the fail-closed check. Backtest set
  files must use RISK_FIXED > 0 and RISK_PERCENT = 0.
- Keep operator-facing phase names Q-only.
- Never enable T_Live or AutoTrading.
- Never start terminal64.exe manually.
- Do not interrupt active T1-T10 backtests unless OWNER explicitly says so.
- Pipeline verdicts come only from pipeline evidence.
- Edge Lab work must fit the active charter: FTMO + DXZ target, <=5% daily DD,
  <=10% total DD, mandatory news blackout, swing/scalping horizon only, no HFT,
  no martingale/grid, mechanical only, no ML in EA.
- Strategy card drafts go to D:/QM/strategy_farm/artifacts/cards_review/.
- Evidence docs and ops artifacts MUST be written in the canonical checkout at
  C:/QM/repo/docs/ops/evidence/ (absolute path) and committed on
  agents/board-advisor only, using explicit pathspecs.
- Do NOT cherry-pick, merge, commit, reset, or otherwise advance main or the
  C:/QM/worktrees/cto_main worktree. Main integration is performed exclusively
  by Claude+OWNER close-outs. Leave the board-advisor artifact in REVIEW.
"""


def process_alive(pid: int, expected_creation_key: str | None) -> bool:
    """Read-only, PID-reuse-safe lock-owner check.

    Never use ``os.kill(pid, 0)`` on Windows: CPython implements unsupported
    signals with ``TerminateProcess`` and signal 0 can therefore kill the very
    process being "probed" with exit code 0.
    """

    if pid <= 0 or not str(expected_creation_key or ""):
        return False
    try:
        identity = get_process_identity(int(pid))
    except Exception:
        return False
    return bool(
        identity
        and identity.get("is_running", True)
        and str(identity.get("creation_key") or "") == str(expected_creation_key)
    )


def acquire_lock(agent: str, stale_minutes: int, slot: int = 1) -> tuple[bool, dict[str, Any]]:
    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    lock_name = f"{agent}_orchestration.lock" if slot == 1 else f"{agent}_orchestration_{slot}.lock"
    lock_path = LOCK_DIR / lock_name
    owner_token = uuid.uuid4().hex
    for _attempt in range(3):
        try:
            fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            now = time.time()
            try:
                data = json.loads(lock_path.read_text(encoding="utf-8"))
            except Exception:
                data = {}
            try:
                age_sec = now - lock_path.stat().st_mtime
            except OSError:
                continue
            pid = int(data.get("pid") or 0)
            process_creation_key = str(data.get("process_creation_key") or "")
            if pid and process_alive(pid, process_creation_key):
                return False, {
                    "lock_path": str(lock_path),
                    "reason": "previous_run_active",
                    "pid": pid,
                    "age_sec": round(age_sec, 1),
                }
            if age_sec < stale_minutes * 60:
                return False, {
                    "lock_path": str(lock_path),
                    "reason": "recent_lock_owner_not_live",
                    "pid": pid,
                    "age_sec": round(age_sec, 1),
                }
            stale_path = lock_path.with_name(
                f"{lock_path.name}.{uuid.uuid4().hex}.stale"
            )
            try:
                os.replace(lock_path, stale_path)
                stale_path.unlink(missing_ok=True)
            except OSError:
                continue
            continue

        try:
            identity = get_process_identity(os.getpid())
            if identity is None or not identity.get("is_running", True):
                raise RuntimeError("cannot capture orchestration lock owner identity")
            process_creation_key = str(identity.get("creation_key") or "")
            if not process_creation_key:
                raise RuntimeError("orchestration lock owner creation key is empty")
            payload = {
                "agent": agent,
                "slot": slot,
                "pid": os.getpid(),
                "process_creation_key": process_creation_key,
                "owner_token": owner_token,
                "started_at": dt.datetime.now(dt.UTC).isoformat(),
            }
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
                json.dump(payload, handle, indent=2, sort_keys=True)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
        except Exception:
            try:
                os.close(fd)
            except OSError:
                pass
            lock_path.unlink(missing_ok=True)
            raise
        return True, {"lock_path": str(lock_path), "owner_token": owner_token}
    return False, {"lock_path": str(lock_path), "reason": "lock_contention"}


def release_lock(lock_info: dict[str, Any]) -> None:
    path = Path(str(lock_info.get("lock_path") or ""))
    owner_token = str(lock_info.get("owner_token") or "")
    try:
        if not path.exists() or not owner_token:
            return
        data = json.loads(path.read_text(encoding="utf-8"))
        if str(data.get("owner_token") or "") != owner_token:
            return
        path.unlink()
    except (OSError, ValueError, TypeError):
        pass


def command_for(
    agent: str,
    cwd: Path,
    prompt_path: Path | None = None,
    model_contract: dict[str, Any] | None = None,
) -> list[str] | None:
    """Argv for one headless agent launch; ``None`` for a REFUSED Codex contract.

    CEO decision D3 (round 3, 2026-09-04): a refused contract (spent 5h window,
    unknown tier, invalid scalpel marker) must not render a model flag at all -
    the caller skips instead. `run_agent_slot` returns `skipped` before reaching
    here, so the `None` is the belt to that braces.
    """
    cli = resolve_cli(agent)
    if agent == "codex":
        contract = headless_model_contract(agent, model_contract)
        if contract.get("model_tier_refused"):
            return None
        model = str(contract.get("model") or "")
        effort = str(contract.get("reasoning_effort") or CODEX_HEADLESS_EFFORT)
        model_args = ["-m", model] if model else []
        return [
            cli,
            "exec",
            *model_args,
            "-c",
            f'model_reasoning_effort="{effort}"',
            "--dangerously-bypass-approvals-and-sandbox",
            "--cd",
            str(cwd),
        ]
    if agent == "gemini":
        # Antigravity CLI (agy): headless via `-p`. agy does NOT read stdin, and a full
        # orchestration prompt can exceed the Windows cmdline limit, so pass a short
        # POINTER telling the agentic CLI to read+execute the prompt FILE; agy reads it
        # via its file tools (workspace = the --add-dir paths). yolo/auto-approve =
        # --dangerously-skip-permissions. Auth = Windows Credential Manager (no key).
        # These flags are the agy Go shim's own surface (proven rc=0 runs 06-29/07-02);
        # do NOT swap in Node gemini-cli flags — a "yargs Unknown arguments" dump in
        # the live log means the DEAD gemini-cli got resolved, not that agy changed
        # (see resolve_cli 2026-07-07).
        extra_dirs = [str(cwd)]
        if prompt_path is not None:
            extra_dirs.append(str(Path(prompt_path).parent))
        for extra in (
            Path(r"C:\Users\Administrator\Downloads"),  # OWNER source folders (EA/video mining)
            FARM_ROOT / "artifacts" / "cards_review",   # artifact write target
            Path(r"G:\My Drive"),                        # shared Drive (spec outputs)
        ):
            try:
                available = extra.exists()
            except OSError:
                # Google Drive is per-user and can return Access Denied under
                # the SYSTEM scheduled-task token even for a read-only probe.
                available = False
            if available:
                extra_dirs.append(str(extra))
        add_dir_flags: list[str] = []
        for d in extra_dirs:
            add_dir_flags += ["--add-dir", d]
        model_args = ["--model", GEMINI_HEADLESS_MODEL] if GEMINI_HEADLESS_MODEL else []
        pointer = (
            f"Read the file '{prompt_path}' and execute its instructions exactly, then exit."
            if prompt_path is not None
            else "Execute one single-pass QuantMechanica orchestration cycle, then exit."
        )
        return [
            str(PYTHON_EXE),
            str(CONPTY_RUNNER),
            cli,
            *model_args,
            "--dangerously-skip-permissions",
            "--print-timeout",
            "60m",
            *add_dir_flags,
            "-p",
            pointer,
        ]
    if agent == "claude":
        contract = headless_model_contract(agent, model_contract)
        model = str(contract.get("model") or "")
        model_args = ["--model", model] if model else []
        return [
            cli,
            "-p",
            *model_args,
            "--dangerously-skip-permissions",
            "--add-dir",
            str(cwd),
        ]
    if agent == "kimi":
        # Kimi Code CLI headless invocation (KIMI_INTEGRATION_ARCHITECTURE.md
        # §3.1). Prompt delivery = a prompt FILE plus a short argv POINTER
        # (mirroring agy), because the Windows argv path risks the ~32 KB
        # cmdline cap for a full orchestration prompt and kimi has no dedicated
        # --prompt-file flag. Output is stream-json (text mode is dirty). --auto
        # guarantees no interactive prompt hangs a headless run; --add-dir scopes
        # the workspace. The adapter (kimi_adapter.run_kimi) actually spawns this
        # under a watchdog + single-flight lock; this argv is the documented
        # shape recorded in the result JSON and handed to the adapter.
        contract = headless_model_contract(agent, model_contract)
        model = str(contract.get("model") or KIMI_HEADLESS_MODEL)
        model_args = ["-m", model] if model else []
        add_dirs = [str(cwd)]
        if prompt_path is not None:
            add_dirs.append(str(Path(prompt_path).parent))
        add_dir_flags: list[str] = []
        for d in add_dirs:
            add_dir_flags += ["--add-dir", d]
        pointer = (
            f"Read the file '{prompt_path}' and execute its instructions exactly, then exit."
            if prompt_path is not None
            else "Execute one single-pass QuantMechanica research cycle, then exit."
        )
        return [
            cli,
            "-p",
            pointer,
            "--output-format",
            "stream-json",
            *model_args,
            *add_dir_flags,
        ]
    raise ValueError(f"unsupported agent: {agent}")


def headless_model_contract(
    agent: str,
    selected: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Observable enforcement point: quota pacing changes volume, not depth.

    For Codex the invocation carries the model id resolved from the tier
    contract (model routing doctrine 2026-09-04 §5); `command_for` emits it as
    `-m <model>`. When the caller supplies no invocation (e.g. the
    `lane_db_unavailable_ops_continuity` branch of `_quota_lane_check`, which
    returns no `allowed_invocations`) the tier is resolved FRESHLY here rather
    than taken from a frozen import-time snapshot, and an exhausted 5h window
    is carried through as `model_tier_refused` so the spawn can fail closed
    instead of silently spending a message over budget. The env override stays
    the manual OWNER escape hatch.
    """
    if agent == "codex":
        if selected:
            contract = dict(selected)
        else:
            contract = dict(
                quota_spawn_gate.invocation_profile("codex", "build_ea") or _DEFAULT_CODEX_INVOCATION
            )
            contract["model_contract_source"] = "resolved_at_dispatch"
        # `select_dispatch` reports an exhausted window / unknown tier as a
        # side-band field; neither is a model id, so make it a first-class flag.
        if contract.get("model_tier_refusal") or contract.get("model_tier_error"):
            contract["model_tier_refused"] = True
        if contract.get("model_tier_hold"):
            contract["model_tier_refused"] = True
        if _CODEX_MODEL_ENV_OVERRIDE:
            contract["model"] = _CODEX_MODEL_ENV_OVERRIDE
            contract["model_override_source"] = "QM_CODEX_HEADLESS_MODEL"
            # An explicit OWNER model override outranks our own conservative
            # planning budget (same authority order as the burn flag).
            contract["model_tier_refused"] = False
        return contract
    if agent == "claude":
        contract = dict(selected or _DEFAULT_CLAUDE_INVOCATION)
        if _CLAUDE_MODEL_ENV_OVERRIDE:
            contract["model"] = _CLAUDE_MODEL_ENV_OVERRIDE
            contract["model_override_source"] = "QM_CLAUDE_HEADLESS_MODEL"
        return contract
    if agent == "kimi":
        # Model per capability (KIMI_INTEGRATION_ARCHITECTURE.md §3.3): resolved
        # from config/kimi_adapter.v1.json when present, else the documented
        # default. The caller may pass a capability via `selected` to pick a
        # cheaper critic/summary model; env override always wins.
        contract: dict[str, Any] = dict(selected or {})
        capability = str(contract.get("capability") or "").strip()
        model = str(contract.get("model") or "")
        if not model:
            model = _kimi_model_for_capability(capability)
        if _KIMI_MODEL_ENV_OVERRIDE:
            model = _KIMI_MODEL_ENV_OVERRIDE
            contract["model_override_source"] = "QM_KIMI_HEADLESS_MODEL"
        contract["model"] = model
        contract.setdefault("reasoning_effort", None)
        return contract
    return {"model": GEMINI_HEADLESS_MODEL or None, "reasoning_effort": None}


def _kimi_model_for_capability(capability: str) -> str:
    """Resolve the kimi model id for a capability (§3.3).

    Config-first: config/kimi_adapter.v1.json may carry
    ``{"models": {"<capability>": "<model>", "default": "<model>"}}``. If the
    file is absent or unreadable (it is authored by kimi_adapter.py in parallel),
    fall back to the documented defaults so this lane never hard-fails on a
    missing config.
    """
    documented_default = KIMI_HEADLESS_MODEL
    try:
        raw = KIMI_ADAPTER_CONFIG.read_text(encoding="utf-8")
        models = (json.loads(raw) or {}).get("models") or {}
    except (OSError, ValueError, TypeError):
        models = {}
    if capability and isinstance(models, dict) and models.get(capability):
        return str(models[capability])
    if isinstance(models, dict) and models.get("default"):
        return str(models["default"])
    return documented_default


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


def _git_at(path: Path, args: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(path), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )


def _current_canonical_head() -> tuple[str | None, str | None]:
    proc = run_git(["rev-parse", "HEAD"])
    head = proc.stdout.strip() if proc.returncode == 0 else ""
    if not head:
        return None, (proc.stderr.strip() or "canonical_head_unavailable")
    return head, None


def _repo_is_ancestor(ancestor: str, descendant: str) -> bool:
    return run_git(["merge-base", "--is-ancestor", ancestor, descendant]).returncode == 0


def ensure_current_pinned_worktree(
    agent: str,
    slot: int,
    required_head: str,
    *,
    create: bool,
) -> dict[str, Any]:
    """Prepare one pinned-session worktree without discarding prior work.

    Existing dirty, ahead, or diverged slots are rejected.  A clean slot may
    only move by a fast-forward to the exact canonical launch commit. Missing
    slots are created without ``-B`` so an existing branch is never reset.
    ``create=False`` performs the same checks as a read-only dry-run.
    """
    path = worktree_path(agent, slot)
    branch = branch_name(agent, slot)
    base: dict[str, Any] = {
        "slot": slot,
        "path": str(path),
        "branch": branch,
        "required_head": required_head,
        "create": create,
    }

    if path.exists():
        check = _git_at(path, ["rev-parse", "--show-toplevel"], timeout=20)
        if check.returncode != 0:
            return {
                **base,
                "ok": False,
                "reason": "path_exists_but_not_git_worktree",
                "stderr": check.stderr.strip(),
            }
        status = _git_at(path, ["status", "--porcelain"], timeout=60)
        if status.returncode != 0:
            return {
                **base,
                "ok": False,
                "reason": "worktree_status_failed",
                "stderr": status.stderr.strip(),
            }
        dirty_rows = [row for row in status.stdout.splitlines() if row.strip()]
        if dirty_rows:
            return {
                **base,
                "ok": False,
                "reason": "worktree_dirty_refuse_update",
                "dirty_path_count": len(dirty_rows),
            }
        head_proc = _git_at(path, ["rev-parse", "HEAD"], timeout=20)
        head = head_proc.stdout.strip() if head_proc.returncode == 0 else ""
        if not head:
            return {
                **base,
                "ok": False,
                "reason": "worktree_head_unavailable",
                "stderr": head_proc.stderr.strip(),
            }
        branch_proc = _git_at(path, ["branch", "--show-current"], timeout=20)
        current_branch = branch_proc.stdout.strip() if branch_proc.returncode == 0 else ""
        if current_branch != branch:
            return {
                **base,
                "ok": False,
                "reason": "worktree_branch_mismatch_refuse_update",
                "head": head,
                "current_branch": current_branch or None,
            }
        if head == required_head:
            return {**base, "ok": True, "created": False, "head": head, "current": True}
        if _repo_is_ancestor(required_head, head):
            return {
                **base,
                "ok": False,
                "reason": "worktree_ahead_refuse_reset",
                "head": head,
            }
        if not _repo_is_ancestor(head, required_head):
            return {
                **base,
                "ok": False,
                "reason": "worktree_diverged_refuse_update",
                "head": head,
            }
        if not create:
            return {
                **base,
                "ok": True,
                "created": False,
                "head": head,
                "current": False,
                "would_fast_forward": True,
            }
        ff = _git_at(path, ["merge", "--ff-only", required_head], timeout=120)
        if ff.returncode != 0:
            return {
                **base,
                "ok": False,
                "reason": "worktree_fast_forward_failed",
                "head": head,
                "stderr": ff.stderr.strip(),
            }
        advanced = _git_at(path, ["rev-parse", "HEAD"], timeout=20).stdout.strip()
        return {
            **base,
            "ok": advanced == required_head,
            "created": False,
            "head": advanced,
            "current": advanced == required_head,
            "fast_forwarded": True,
            "reason": None if advanced == required_head else "worktree_head_mismatch_after_ff",
        }

    branch_ref = f"refs/heads/{branch}"
    branch_exists = run_git(["show-ref", "--verify", "--quiet", branch_ref]).returncode == 0
    branch_head = ""
    would_fast_forward = False
    if branch_exists:
        resolved = run_git(["rev-parse", branch_ref])
        branch_head = resolved.stdout.strip() if resolved.returncode == 0 else ""
        if not branch_head:
            return {**base, "ok": False, "reason": "slot_branch_head_unavailable"}
        if branch_head == required_head:
            pass
        elif _repo_is_ancestor(required_head, branch_head):
            return {
                **base,
                "ok": False,
                "reason": "slot_branch_ahead_refuse_reset",
                "branch_head": branch_head,
            }
        elif _repo_is_ancestor(branch_head, required_head):
            would_fast_forward = True
        else:
            return {
                **base,
                "ok": False,
                "reason": "slot_branch_diverged_refuse_reset",
                "branch_head": branch_head,
            }

    if not create:
        return {
            **base,
            "ok": True,
            "created": False,
            "current": not would_fast_forward,
            "would_create": True,
            "would_fast_forward": would_fast_forward,
            "branch_exists": branch_exists,
            "branch_head": branch_head or None,
        }

    WORKTREE_ROOT.mkdir(parents=True, exist_ok=True)
    if branch_exists:
        added = run_git(["worktree", "add", str(path), branch], timeout=120)
    else:
        added = run_git(
            ["worktree", "add", "-b", branch, str(path), required_head], timeout=120
        )
    if added.returncode != 0:
        return {
            **base,
            "ok": False,
            "reason": "worktree_create_failed",
            "stderr": added.stderr.strip(),
        }
    if would_fast_forward:
        ff = _git_at(path, ["merge", "--ff-only", required_head], timeout=120)
        if ff.returncode != 0:
            return {
                **base,
                "ok": False,
                "reason": "new_worktree_fast_forward_failed",
                "stderr": ff.stderr.strip(),
            }
    head = _git_at(path, ["rev-parse", "HEAD"], timeout=20).stdout.strip()
    current = head == required_head
    return {
        **base,
        "ok": current,
        "created": True,
        "head": head,
        "current": current,
        "fast_forwarded": would_fast_forward,
        "reason": None if current else "new_worktree_missing_required_head",
    }


def prepare_pinned_worktree_slots(
    agent: str,
    requested: int,
    *,
    create: bool,
) -> dict[str, Any]:
    """Return up to ``requested`` safe/current slot ids, skipping legacy dirt."""
    if requested <= 0:
        return {
            "ok": True,
            "reason": "no_slots_requested",
            "requested": requested,
            "slot_ids": [],
            "accepted": [],
            "rejected": [],
        }
    required_head, error = _current_canonical_head()
    if not required_head:
        return {
            "ok": False,
            "reason": "canonical_head_unavailable",
            "error": error,
            "slot_ids": [],
            "rejected": [],
        }
    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for slot in range(1, PINNED_WORKTREE_SLOT_SCAN_LIMIT + 1):
        result = ensure_current_pinned_worktree(
            agent, slot, required_head, create=create
        )
        if result.get("ok"):
            accepted.append(result)
            if len(accepted) >= requested:
                break
        else:
            rejected.append(result)
    return {
        "ok": len(accepted) >= requested,
        "reason": (
            "safe_slots_ready"
            if len(accepted) >= requested
            else "insufficient_safe_worktree_slots"
        ),
        "required_head": required_head,
        "requested": requested,
        "slot_ids": [int(row["slot"]) for row in accepted],
        "accepted": accepted,
        "rejected": rejected,
    }


# A single orchestration invocation is allowed to run up to `timeout_minutes`
# (225 by default, near the Task Scheduler's 4h ExecutionTimeLimit ceiling) —
# far longer than LANE_HEARTBEAT_STALE_HOURS (2h, agent_router.py). Before this
# constant existed, the heartbeat was written once at spawn and never again
# until the process exited, so any run past 2h made the router treat a
# genuinely busy lane as dead: chk_agent_lane_heartbeat WARNs, and
# release_stale_in_progress can release/recycle that lane's own IN_PROGRESS
# task out from under it while it is still legitimately working (MNT-003).
# Refreshing well inside the 2h window keeps the heartbeat meaning what its
# own docstring says it should: infrastructure alive, not "just started".
HEARTBEAT_REFRESH_INTERVAL_SECONDS = 600


def _wait_with_heartbeat_refresh(
    proc: Any,
    timeout_seconds: float,
    refresh_interval_seconds: float,
    refresh_fn: Any,
) -> int:
    """poll proc.wait() in bounded slices, calling refresh_fn() between polls so a
    single long-running process keeps proving liveness instead of going silent
    for its entire runtime. Re-raises subprocess.TimeoutExpired once the total
    elapsed time exceeds timeout_seconds, exactly like a plain proc.wait(timeout=...)."""
    deadline = time.monotonic() + timeout_seconds
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired(cmd=getattr(proc, "args", None), timeout=timeout_seconds)
        slice_timeout = min(refresh_interval_seconds, remaining)
        try:
            return proc.wait(timeout=slice_timeout)
        except subprocess.TimeoutExpired:
            refresh_fn()
            continue


def _sha256_file(path: Path) -> str | None:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def _run_kimi_slot(
    slot: int,
    cwd: Path,
    prompt_path: Path,
    live_log: Path,
    result_path: Path,
    worktree: dict[str, Any],
    dry_run: bool,
    invocation_profile: dict[str, Any] | None,
    timeout_minutes: int,
) -> dict[str, Any]:
    """Execute one kimi research slot via kimi_adapter.run_kimi (§5.4, §9).

    Fail-closed contract: the adapter module is authored in parallel, so it is
    imported LAZILY here; if it is missing the branch returns a result JSON with
    status ``cli_missing`` and never raises into the lane loop. Any exception the
    adapter itself raises is caught and classified, never propagated.
    """
    agent = "kimi"
    started_at = dt.datetime.now(dt.UTC).isoformat()
    task_id = str((invocation_profile or {}).get("task_id") or f"orchestration:kimi:slot{slot}")
    model_contract = headless_model_contract(agent, invocation_profile)
    model = str(model_contract.get("model") or KIMI_HEADLESS_MODEL)
    cmd = command_for(agent, cwd, prompt_path, model_contract)
    add_dirs = [str(cwd), str(prompt_path.parent)]
    try:
        quota_state = agent_router.kimi_quota_state()
    except Exception:
        quota_state = "unknown"
    prompt_sha256 = _sha256_file(prompt_path)
    payload: dict[str, Any] = {
        "agent": agent,
        "provider": "kimi",
        "execution_backend": "kimi_adapter",
        "task_id": task_id,
        "model": model,
        "model_contract": model_contract,
        "slot": slot,
        "dry_run": dry_run,
        "prompt_path": str(prompt_path),
        "live_log": str(live_log),
        "command": cmd,
        "cwd": str(cwd),
        "worktree": worktree,
        "quota_state": quota_state,
        "prompt_sha256": prompt_sha256,
        "output_sha256": None,
        "latency_s": None,
        "retries": 0,
        "started_at": started_at,
    }
    try:
        if dry_run:
            payload.update(
                {
                    "ok": True,
                    "returncode": 0,
                    "status": "dry_run_verified",
                    "dry_run_verified": True,
                }
            )
            return payload

        try:
            try:
                import kimi_adapter  # type: ignore
            except ModuleNotFoundError:
                from tools.strategy_farm import kimi_adapter  # type: ignore
        except ModuleNotFoundError:
            # Adapter not present yet: fail closed, do not raise (§5.4).
            payload.update(
                {
                    "ok": False,
                    "returncode": 127,
                    "status": "cli_missing",
                    "error": "kimi_adapter module not found",
                }
            )
            return payload

        start = time.monotonic()
        try:
            # Real adapter contract (kimi_adapter.run_kimi, slice C1): the prompt TEXT goes in,
            # the adapter writes its own pointer file under out_dir; role 'research' = the
            # orchestration lane; the capability names the model tier from the adapter config.
            result = kimi_adapter.run_kimi(
                Path(prompt_path).read_text(encoding="utf-8"),
                role="research",
                capability=str((invocation_profile or {}).get("capability") or "deep_research"),
                task_id=task_id,
                model=model,
                cwd=Path(cwd),
                add_dirs=[Path(d) for d in add_dirs],
                timeout_s=timeout_minutes * 60,
                out_dir=Path(live_log).parent / f"kimi_slot{slot}_{Path(live_log).stem}",
                environ=agent_env(agent),
            )
        except Exception as exc:  # adapter must never crash the lane loop
            payload.update(
                {
                    "ok": False,
                    "returncode": 1,
                    "status": "unknown",
                    "error": repr(exc),
                    "latency_s": round(time.monotonic() - start, 3),
                }
            )
            return payload
        result = dict(result or {})
        status = str(result.get("status") or "unknown")
        payload.update(
            {
                "status": status,
                "ok": status == "ok",
                "returncode": int(result.get("returncode") if result.get("returncode") is not None else (0 if status == "ok" else 1)),
                "latency_s": result.get("latency_s", round(time.monotonic() - start, 3)),
                "retries": int(result.get("retries") or 0),
                "output_sha256": result.get("output_sha256"),
                "cli_version": result.get("cli_version"),
                "quota_state": result.get("quota_state", quota_state),
            }
        )
        if result.get("model"):
            payload["model"] = str(result["model"])
        if result.get("error"):
            payload["error"] = str(result["error"])
        return payload
    finally:
        payload["finished_at"] = dt.datetime.now(dt.UTC).isoformat()
        try:
            result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        except OSError:
            pass


def run_agent_slot(
    agent: str,
    slot: int,
    dry_run: bool,
    stale_minutes: int,
    timeout_minutes: int,
    invocation_profile: dict[str, Any] | None = None,
    session_lease: dict[str, Any] | None = None,
    assigned_task_id: str | None = None,
    exec_lease: dict[str, Any] | None = None,
) -> dict[str, Any]:
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
    prompt = build_prompt(agent, cwd, assigned_task_id)
    prompt_path = LOG_DIR / f"{agent}_orchestration_slot{slot}_prompt_{stamp}.md"
    live_log = LOG_DIR / f"{agent}_orchestration_slot{slot}_{stamp}.live.log"
    result_path = LOG_DIR / f"{agent}_orchestration_slot{slot}_{stamp}.json"
    prompt_path.write_text(prompt, encoding="utf-8", newline="\n")

    if worktree.get("ok") is False:
        # Free the pinned task so a healthy launcher can retake it immediately.
        release_task_exec_lease(exec_lease)
        payload = {
            "agent": agent,
            "slot": slot,
            "ok": False,
            "returncode": 1,
            "worktree": worktree,
            "assigned_task_id": assigned_task_id,
            "result_path": str(result_path),
        }
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        return payload

    locked, lock_info = acquire_lock(agent, stale_minutes, slot=slot)
    if not locked:
        release_task_exec_lease(exec_lease)
        payload = {
            "agent": agent,
            "slot": slot,
            "ok": True,
            "skipped": True,
            "reason": lock_info.get("reason"),
            "lock": lock_info,
            "assigned_task_id": assigned_task_id,
            "result_path": str(result_path),
        }
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        return payload

    # Refresh lane heartbeat at spawn time (initial write happens in run_agent
    # BEFORE the empty-spawn guards — see _write_lane_heartbeat).
    _write_lane_heartbeat(agent, slot=slot)

    if agent == "kimi":
        # Kimi executes through kimi_adapter.run_kimi, NOT the generic Popen path
        # (§5.4): the adapter owns the stream-json parse, the watchdog, bounded
        # retries, the usage ledger and the machine-wide single-flight lock. This
        # branch returns before the codex/claude/gemini spawn machinery.
        payload = _run_kimi_slot(
            slot,
            cwd,
            prompt_path,
            live_log,
            result_path,
            worktree,
            dry_run,
            invocation_profile,
            timeout_minutes,
        )
        release_lock(lock_info)
        return payload

    model_contract = headless_model_contract(agent, invocation_profile)
    # CEO decision D3 (round 3, 2026-09-04): BOOK FIRST, RENDER SECOND. The argv
    # used to be frozen here from the PREVIEW tier and never reconciled with
    # what `commit_dispatch` actually booked, so a commit that landed one tier
    # lower still launched the preview model (over its budget) while the lower
    # tier was charged a message it never spent. For codex the command line is
    # therefore built from the COMMITTED contract below.
    cmd = None if agent == "codex" else command_for(agent, cwd, prompt_path, model_contract)
    payload: dict[str, Any] = {
        "agent": agent,
        "execution_backend": "agy" if agent == "gemini" else agent,
        "model_contract": model_contract,
        "assigned_task_id": assigned_task_id,
        "slot": slot,
        "dry_run": dry_run,
        "prompt_path": str(prompt_path),
        "live_log": str(live_log),
        "command": cmd,
        "cwd": str(cwd),
        "worktree": worktree,
        "started_at": dt.datetime.now(dt.UTC).isoformat(),
    }
    managed_lease_id: str | None = None
    managed_pid: int | None = None
    managed_process_finished = False
    # Booked message of the 5h model window, refunded if the launch never
    # happens (model routing doctrine 2026-09-04 §3.1).
    codex_ledger: dict[str, Any] | None = None
    try:
        if dry_run:
            if agent == "codex" and cmd is None and not model_contract.get("model_tier_refused"):
                # A dry run books nothing, so this argv is the PREVIEW tier and
                # is marked as such - never the authority for a real spawn.
                cmd = command_for(agent, cwd, prompt_path, model_contract)
                payload["command"] = cmd
                payload["command_preview_only"] = True
            payload.update({"ok": True, "returncode": 0, "dry_run_verified": True})
            return payload
        if agent == "codex" and model_contract.get("model_tier_refused"):
            # Model routing doctrine 2026-09-04 §3.1: the rolling 5h allowance
            # of the selected model is spent (or the requested tier is
            # unknown). Refuse the spawn rather than dispatch over budget - the
            # quota gate normally catches this upstream, but the ops-continuity
            # fail-open branch reaches here with no gate invocation at all.
            payload.update(
                {
                    "ok": True,
                    "skipped": True,
                    "returncode": 0,
                    "reason": "codex_tier_window_exhausted",
                    "model_tier_refusal": model_contract.get("model_tier_refusal")
                    or model_contract.get("model_tier_error")
                    or model_contract.get("model_tier_hold"),
                }
            )
            return payload
        if agent == "codex":
            # One real dispatch = one message of the selected model's rolling
            # 5h allowance (model routing doctrine 2026-09-04 §3.1). Booked
            # BEFORE the launch and under the ledger lock, so two slots cannot
            # both pass the same remaining slot; refunded below if the launch
            # itself fails. Never for a dry run (returned above).
            codex_ledger = quota_spawn_gate.record_codex_dispatch(
                task_id=str(
                    (invocation_profile or {}).get("task_id")
                    or f"orchestration:{agent}:slot{slot}"
                ),
                contract=model_contract,
            )
            payload["model_window_ledger"] = codex_ledger
            booking_reason = str(codex_ledger.get("reason") or "")
            if codex_ledger.get("recorded"):
                # CEO decision D3: reconcile the contract with what was really
                # booked. The commit may have landed one tier LOWER than the
                # preview (another spawner filled the preferred model in
                # between); the argv must then carry that lower tier's model id,
                # which is also the tier the ledger just charged.
                booked_model = str(codex_ledger.get("model") or "")
                if booked_model and not model_contract.get("model_override_source"):
                    model_contract = dict(model_contract)
                    model_contract["model"] = booked_model
                    model_contract["model_tier"] = str(
                        codex_ledger.get("tier") or model_contract.get("model_tier") or ""
                    )
                    if codex_ledger.get("downgraded_from"):
                        model_contract["model_tier_downgraded_from"] = str(
                            codex_ledger["downgraded_from"]
                        )
                    model_contract["model_contract_source"] = "committed_ledger_booking"
                    payload["model_contract"] = model_contract
            elif booking_reason != "codex_model_tiers_disabled":
                # CEO decision D4: a message that could not be BOOKED is not
                # spent - an exhausted window, an unusable tier, an unreadable
                # or unwritable ledger and an unresolvable policy all refuse.
                payload.update(
                    {
                        "ok": True,
                        "skipped": True,
                        "returncode": 0,
                        "reason": booking_reason or "codex_dispatch_unbooked",
                        "model_tier_refusal": codex_ledger.get("refusal") or codex_ledger,
                    }
                )
                return payload
        if agent == "codex":
            cmd = command_for(agent, cwd, prompt_path, model_contract)
            payload["command"] = cmd
            if cmd is None:
                # Booked but never launched: refund so the window does not
                # drift shut on a phantom message.
                if codex_ledger and codex_ledger.get("recorded"):
                    payload["model_window_ledger_release"] = (
                        quota_spawn_gate.release_codex_dispatch(codex_ledger)
                    )
                payload.update(
                    {
                        "ok": True,
                        "skipped": True,
                        "returncode": 0,
                        "reason": "codex_model_contract_refused",
                    }
                )
                return payload
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        with open(prompt_path, "rb") as stdin_f, open(live_log, "wb") as stdout_f:
            popen_kwargs = {
                "stdin": stdin_f,
                "stdout": stdout_f,
                "stderr": subprocess.STDOUT,
                "env": agent_env(agent, assigned_task_id),
                "shell": agent != "gemini",
                "creationflags": creationflags,
                "close_fds": True,
            }
            if agent == "codex":
                proc, lease = spawn_managed_codex(
                    FARM_ROOT,
                    cmd,
                    purpose="orchestration",
                    cwd=cwd,
                    dedupe_key="orchestration:codex",
                    # The wrapper owns the primary timeout.  Five minutes of
                    # lease headroom covers its result write/push cleanup while
                    # remaining below the Task Scheduler's four-hour limit for
                    # the default 225-minute run.
                    max_age_minutes=timeout_minutes + 5,
                    metadata={
                        "slot": slot,
                        "live_log": str(live_log),
                        "result_path": str(result_path),
                    },
                    **popen_kwargs,
                )
                managed_lease_id = str(lease["lease_id"])
                managed_pid = int(proc.pid)
                payload["lease_id"] = managed_lease_id
            else:
                proc = subprocess.Popen(cmd, cwd=str(cwd), **popen_kwargs)
            payload["pid"] = proc.pid
            try:
                payload["returncode"] = _wait_with_heartbeat_refresh(
                    proc,
                    timeout_minutes * 60,
                    HEARTBEAT_REFRESH_INTERVAL_SECONDS,
                    lambda: _refresh_headless_ownership(agent, slot, session_lease, exec_lease),
                )
                payload["ok"] = payload["returncode"] == 0
                managed_process_finished = managed_pid is not None
            except subprocess.TimeoutExpired:
                if managed_pid is not None:
                    stopped = terminate_managed_codex_pid(FARM_ROOT, managed_pid)
                    payload["timeout_stop"] = stopped
                    managed_process_finished = bool(stopped.get("stopped"))
                    if not managed_process_finished:
                        try:
                            proc.wait(timeout=30)
                            managed_process_finished = True
                            payload["timeout_stop_completed_concurrently"] = True
                        except subprocess.TimeoutExpired:
                            pass
                else:
                    proc.kill()
                payload.update({"ok": False, "returncode": 124, "error": "timeout"})
        if managed_lease_id is not None and not managed_process_finished:
            payload["push"] = {
                "attempted": False,
                "ok": False,
                "reason": "managed_process_exit_unconfirmed",
            }
            return payload
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
        running_proc = locals().get("proc")
        if running_proc is not None and payload.get("pid") and not managed_process_finished:
            try:
                if managed_pid is not None:
                    stopped = terminate_managed_codex_pid(FARM_ROOT, managed_pid)
                    payload["exception_stop"] = stopped
                    managed_process_finished = bool(stopped.get("stopped"))
                else:
                    running_proc.kill()
                    running_proc.wait(timeout=30)
                    payload["exception_stop"] = {"stopped": True}
            except Exception as stop_exc:
                payload["exception_stop"] = {"stopped": False, "error": repr(stop_exc)}
        payload.update({"ok": False, "returncode": 1, "error": repr(exc)})
        if codex_ledger and codex_ledger.get("recorded") and not payload.get("pid"):
            # The message was booked but no process was ever launched: refund
            # it so the window does not drift shut on a phantom dispatch.
            payload["model_window_ledger_release"] = quota_spawn_gate.release_codex_dispatch(
                codex_ledger
            )
        return payload
    finally:
        # Release the per-task exec-lease (fan-out fix): a clean or crashed exit
        # frees the task immediately; if release storage is unavailable, the TTL
        # is the fail-safe. Never before this point - the pin must outlive the
        # child process for the whole run.
        release_task_exec_lease(exec_lease)
        # A lease may be removed only after the exact registered process is
        # known to have exited.  If waiting or termination fails, retain it so
        # the ownership-safe reaper can retry instead of orphaning the tree.
        if managed_lease_id is not None and managed_process_finished:
            removed = release_managed_codex_process(FARM_ROOT, lease_id=managed_lease_id)
            if not removed:
                payload["lease_retained_for_reaper"] = True
        elif managed_lease_id is not None:
            payload["lease_retained_for_reaper"] = True
        payload["finished_at"] = dt.datetime.now(dt.UTC).isoformat()
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        if managed_lease_id is None or managed_process_finished:
            release_lock(lock_info)
        else:
            payload["lock_retained_until_stale_recovery"] = True
            result_path.write_text(
                json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8"
            )


def claude_work_available() -> dict[str, Any]:
    """Pre-spawn check to avoid empty or low-value Claude invocations.

    Claude is quota-constrained. It should only wake for explicit router work
    already assigned to Claude, or for unrouted premium work that asks for
    Claude-only capabilities such as `summary`. Candidate eligibility is
    delegated to `_quota_lane_candidates`, so skills and human-lane holds are
    enforced identically by the wake gate and the quota gate. G0/card mass
    review is handled by Codex while the pump Claude lane is disabled.
    """
    candidates, candidate_status = _quota_lane_candidates("claude")
    if candidate_status != "ok":
        # Fail OPEN — if the check fails, spawn anyway rather than starve Claude.
        return {
            "any_work": True,
            "reason": f"work_check_{candidate_status}",
            "candidate_status": candidate_status,
        }

    assigned = [candidate for candidate in candidates if candidate["assigned"]]
    premium = [
        candidate
        for candidate in candidates
        if not candidate["assigned"]
        and (
            "summary" in candidate["required_capabilities"]
            or candidate["budget_class"] in {"premium", "claude"}
        )
    ]
    return {
        "any_work": bool(assigned or premium),
        "claude_assigned": len(assigned),
        "premium_backlog": len(premium),
        "candidate_status": candidate_status,
    }


def _parse_dt(value: str) -> dt.datetime | None:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def interactive_orchestrator_status(
    *,
    flag_path: Path | None = None,
    now: dt.datetime | None = None,
    stale_minutes: int = INTERACTIVE_FLAG_STALE_MINUTES,
) -> dict[str, Any]:
    """Return an explicit headless-admission decision for the interactive flag.

    A fresh malformed marker also blocks: ambiguity must not create a duplicate
    interactive/headless session.  A stale marker is reported but ignored.
    """
    path = flag_path or INTERACTIVE_ORCHESTRATOR_FLAG
    observed = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC)
    if not path.exists():
        return {"active": False, "reason": "interactive_flag_absent", "path": str(path)}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("interactive flag must be a JSON object")
    except Exception as exc:
        try:
            age_seconds = max(0.0, observed.timestamp() - path.stat().st_mtime)
        except OSError:
            age_seconds = 0.0
        active = age_seconds <= stale_minutes * 60
        return {
            "active": active,
            "reason": "interactive_flag_malformed_fresh" if active else "interactive_flag_malformed_stale",
            "path": str(path),
            "age_seconds": round(age_seconds, 3),
            "error": repr(exc),
        }
    heartbeat_text = str(payload.get("heartbeat_at") or payload.get("heartbeat") or "")
    heartbeat = _parse_dt(heartbeat_text)
    if heartbeat is None:
        try:
            age_seconds = max(0.0, observed.timestamp() - path.stat().st_mtime)
        except OSError:
            age_seconds = 0.0
        active = age_seconds <= stale_minutes * 60
        return {
            "active": active,
            "reason": (
                "interactive_flag_missing_heartbeat_fresh"
                if active
                else "interactive_flag_missing_heartbeat_stale"
            ),
            "path": str(path),
            "payload": payload,
            "age_seconds": round(age_seconds, 3),
        }
    age_seconds = max(0.0, (observed - heartbeat).total_seconds())
    active = age_seconds <= stale_minutes * 60
    return {
        "active": active,
        "reason": "interactive_flag_fresh" if active else "interactive_flag_stale",
        "path": str(path),
        "pid": payload.get("pid"),
        "host": payload.get("host"),
        "heartbeat_at": heartbeat.isoformat(),
        "age_seconds": round(age_seconds, 3),
    }


def touch_interactive_orchestrator_flag(
    *,
    flag_path: Path | None = None,
    pid: int | None = None,
    host: str | None = None,
    now: dt.datetime | None = None,
    owner_token: str | None = None,
    mode: str = "touch",
) -> dict[str, Any]:
    """Atomically publish one heartbeat understood by the headless guard."""
    path = flag_path or INTERACTIVE_ORCHESTRATOR_FLAG
    observed = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC)
    token = owner_token or uuid.uuid4().hex
    payload = {
        "schema": "qm.interactive-orchestrator-heartbeat/v1",
        "pid": int(pid if pid is not None else os.getpid()),
        "host": str(host or socket.gethostname()),
        "heartbeat_at": observed.isoformat(),
        "owner_token": token,
        "mode": mode,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_name(f"{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with tmp_path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, path)
    finally:
        tmp_path.unlink(missing_ok=True)
    return {"written": True, "path": str(path), **payload}


def _remove_owned_interactive_flag(path: Path, owner_token: str) -> bool:
    """Remove only this helper's marker, preserving a newer interactive owner."""
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        if str(payload.get("owner_token") or "") != owner_token:
            return False
        path.unlink()
        return True
    except (OSError, ValueError, TypeError, AttributeError):
        return False


def _parent_identity_alive(parent_pid: int, creation_key: str) -> bool:
    return process_alive(parent_pid, creation_key)


def run_interactive_heartbeat_loop(
    minutes: float,
    *,
    flag_path: Path | None = None,
    parent_pid: int | None = None,
    heartbeat_interval_seconds: float = 600.0,
    parent_poll_seconds: float = 5.0,
    monotonic_fn: Any = time.monotonic,
    sleep_fn: Any = time.sleep,
    now_fn: Any = lambda: dt.datetime.now(dt.UTC),
    parent_alive_fn: Any = _parent_identity_alive,
) -> dict[str, Any]:
    """Refresh the interactive marker every ten minutes while its parent lives."""
    if minutes <= 0:
        raise ValueError("minutes must be greater than zero")
    if heartbeat_interval_seconds <= 0 or parent_poll_seconds <= 0:
        raise ValueError("heartbeat and parent-poll intervals must be greater than zero")

    path = flag_path or INTERACTIVE_ORCHESTRATOR_FLAG
    observed_parent_pid = int(parent_pid if parent_pid is not None else os.getppid())
    identity = get_process_identity(observed_parent_pid)
    creation_key = str((identity or {}).get("creation_key") or "")
    if not creation_key or not parent_alive_fn(observed_parent_pid, creation_key):
        return {
            "ok": True,
            "reason": "parent_process_missing",
            "parent_pid": observed_parent_pid,
            "refresh_count": 0,
            "path": str(path),
        }

    owner_token = uuid.uuid4().hex
    started = monotonic_fn()
    deadline = started + float(minutes) * 60.0
    next_heartbeat = started + heartbeat_interval_seconds
    refresh_count = 0
    reason = "duration_elapsed"
    touch_interactive_orchestrator_flag(
        flag_path=path,
        pid=observed_parent_pid,
        now=now_fn(),
        owner_token=owner_token,
        mode="loop",
    )
    refresh_count += 1
    try:
        while monotonic_fn() < deadline:
            if not parent_alive_fn(observed_parent_pid, creation_key):
                reason = "parent_process_missing"
                break
            current = monotonic_fn()
            if current >= next_heartbeat:
                touch_interactive_orchestrator_flag(
                    flag_path=path,
                    pid=observed_parent_pid,
                    now=now_fn(),
                    owner_token=owner_token,
                    mode="loop",
                )
                refresh_count += 1
                next_heartbeat = current + heartbeat_interval_seconds
                continue
            sleep_fn(min(parent_poll_seconds, deadline - current, next_heartbeat - current))
    finally:
        removed = _remove_owned_interactive_flag(path, owner_token)
    return {
        "ok": True,
        "reason": reason,
        "parent_pid": observed_parent_pid,
        "refresh_count": refresh_count,
        "flag_removed": removed,
        "path": str(path),
    }


def _journal_headless_skip(agent: str, reason: str, detail: dict[str, Any]) -> None:
    """Append a durable admission refusal without creating a Git commit."""
    path = LOG_DIR / "headless_orchestration_skip_journal.jsonl"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        row = {
            "schema": "qm.headless-orchestration-skip/v1",
            "at": dt.datetime.now(dt.UTC).isoformat(),
            "agent": agent,
            "reason": reason,
            "detail": detail,
        }
        encoded = json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n"
        with path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
    except OSError:
        pass


def acquire_headless_session_lease(
    agent: str,
    *,
    now: dt.datetime | None = None,
    session_token: str | None = None,
    owner_pid: int | None = None,
    owner_host: str | None = None,
) -> tuple[bool, dict[str, Any]]:
    """Atomically admit one concrete headless controller for an agent lane."""
    observed = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    token = session_token or uuid.uuid4().hex
    pid = int(owner_pid or os.getpid())
    host = owner_host or socket.gethostname()
    task_key = f"headless_orchestration:{agent}"
    expires = observed + dt.timedelta(minutes=HEADLESS_SESSION_LEASE_TTL_MINUTES)
    try:
        conn = agent_router.connect(FARM_ROOT)
        try:
            conn.execute("BEGIN IMMEDIATE")
            acquired = agent_router.agent_scopes.acquire_spawn_lease(
                conn,
                task_key,
                agent,
                observed.isoformat(timespec="seconds"),
                expires.isoformat(timespec="seconds"),
                owner_token=token,
                owner_pid=pid,
                owner_host=host,
                fail_open_on_error=False,
            )
            existing = None
            if not acquired:
                row = conn.execute(
                    """SELECT agent_id, acquired_at, expires_at, owner_token,
                              owner_pid, owner_host, renewed_at
                       FROM spawn_leases WHERE task_key=?""",
                    (task_key,),
                ).fetchone()
                if row is not None:
                    existing = dict(row)
            conn.commit()
        finally:
            conn.close()
    except Exception as exc:
        return False, {
            "task_key": task_key,
            "reason": "headless_session_lease_error_fail_closed",
            "error": repr(exc),
        }
    info = {
        "task_key": task_key,
        "agent": agent,
        "session_token": token,
        "owner_pid": pid,
        "owner_host": host,
        "acquired_at": observed.isoformat(timespec="seconds"),
        "expires_at": expires.isoformat(timespec="seconds"),
    }
    if not acquired:
        info.update({"reason": "foreign_live_headless_session", "existing": existing})
    return bool(acquired), info


def renew_headless_session_lease(
    lease: dict[str, Any], *, now: dt.datetime | None = None
) -> bool:
    observed = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    expires = observed + dt.timedelta(minutes=HEADLESS_SESSION_LEASE_TTL_MINUTES)
    try:
        conn = agent_router.connect(FARM_ROOT)
        try:
            conn.execute("BEGIN IMMEDIATE")
            renewed = agent_router.agent_scopes.renew_spawn_lease(
                conn,
                str(lease["task_key"]),
                owner_token=str(lease["session_token"]),
                owner_pid=int(lease["owner_pid"]),
                owner_host=str(lease["owner_host"]),
                now_iso=observed.isoformat(timespec="seconds"),
                expires_iso=expires.isoformat(timespec="seconds"),
            )
            conn.commit()
        finally:
            conn.close()
    except Exception:
        return False
    if renewed:
        lease["expires_at"] = expires.isoformat(timespec="seconds")
    return bool(renewed)


def release_headless_session_lease(lease: dict[str, Any]) -> None:
    try:
        conn = agent_router.connect(FARM_ROOT)
        try:
            conn.execute("BEGIN IMMEDIATE")
            agent_router.agent_scopes.release_spawn_lease(
                conn,
                str(lease["task_key"]),
                owner_token=str(lease["session_token"]),
                owner_pid=int(lease["owner_pid"]),
                owner_host=str(lease["owner_host"]),
            )
            conn.commit()
        finally:
            conn.close()
    except Exception:
        # Expiry remains the fail-safe if release storage is unavailable.
        pass


# --- Per-task exec-lease (Claude fan-out fix, OWNER-DEC-CBE-20260915 §35) -----
# The router's `agent_task:<id>` lease is written with NO owner tuple, so it
# cannot tell two sibling worker sessions of ONE launcher apart. This ADDITIVE
# key binds a concrete pid-owned session to exactly one task BEFORE it does any
# work. The router path (`agent_task:*`) is deliberately left untouched.


def _task_exec_lease_key(task_id: str) -> str:
    return f"agent_task_exec:{task_id}"


def _exec_lease_owner_alive(owner_host: str, owner_pid: int) -> bool | None:
    """Return local liveness; ``None`` means the owner cannot be proved dead."""
    if not owner_host or owner_host.casefold() != socket.gethostname().casefold():
        return None
    if owner_pid <= 0:
        return None
    try:
        identity = get_process_identity(owner_pid)
    except Exception:
        return None
    if identity is None:
        return False
    return bool(identity.get("is_running", True))


def acquire_task_exec_lease(
    agent: str,
    task_id: str,
    *,
    now: dt.datetime | None = None,
    session_token: str | None = None,
    owner_pid: int | None = None,
    owner_host: str | None = None,
) -> tuple[bool, dict[str, Any]]:
    """Atomically claim one task for one concrete worker session.

    Fail-closed: any storage error refuses the claim so a visibility incident
    spawns FEWER sessions, never a duplicate. An expired owner-scoped lease is
    reclaimed only when its local owner PID is proven dead. A live PID, remote
    host, or unreadable owner identity remains held even after TTL expiry.
    """
    observed = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    token = session_token or uuid.uuid4().hex
    pid = int(owner_pid or os.getpid())
    host = owner_host or socket.gethostname()
    task_key = _task_exec_lease_key(task_id)
    expires = observed + dt.timedelta(minutes=HEADLESS_SESSION_LEASE_TTL_MINUTES)
    existing: dict[str, Any] | None = None
    refusal_reason: str | None = None
    try:
        conn = agent_router.connect(FARM_ROOT)
        try:
            conn.execute("BEGIN IMMEDIATE")
            agent_router.agent_scopes._ensure_spawn_lease_schema(conn)
            row = conn.execute(
                """SELECT task_key, agent_id, acquired_at, expires_at,
                          owner_token, owner_pid, owner_host, renewed_at
                   FROM spawn_leases WHERE task_key=?""",
                (task_key,),
            ).fetchone()
            if row is not None:
                existing = dict(row)
                existing_expiry = _parse_dt(str(existing.get("expires_at") or ""))
                if existing_expiry is not None and existing_expiry <= observed:
                    old_pid = int(existing.get("owner_pid") or 0)
                    old_host = str(existing.get("owner_host") or "")
                    old_token = str(existing.get("owner_token") or "")
                    alive = _exec_lease_owner_alive(old_host, old_pid)
                    if alive is False and old_token:
                        removed = conn.execute(
                            """DELETE FROM spawn_leases
                               WHERE task_key=? AND owner_token=?
                                 AND owner_pid=? AND owner_host=? AND expires_at=?""",
                            (
                                task_key,
                                old_token,
                                old_pid,
                                old_host,
                                str(existing.get("expires_at") or ""),
                            ),
                        )
                        if not removed.rowcount:
                            refusal_reason = "task_exec_lease_stale_release_raced"
                    elif alive is True:
                        refusal_reason = "task_exec_lease_expired_owner_pid_alive"
                    else:
                        refusal_reason = "task_exec_lease_stale_owner_unverifiable"
            if refusal_reason is None:
                acquired = agent_router.agent_scopes.acquire_spawn_lease(
                    conn,
                    task_key,
                    agent,
                    observed.isoformat(timespec="seconds"),
                    expires.isoformat(timespec="seconds"),
                    owner_token=token,
                    owner_pid=pid,
                    owner_host=host,
                    fail_open_on_error=False,
                )
            else:
                acquired = False
            conn.commit()
        finally:
            conn.close()
    except Exception as exc:
        return False, {
            "task_key": task_key,
            "task_id": task_id,
            "reason": "task_exec_lease_error_fail_closed",
            "error": repr(exc),
        }
    info = {
        "task_key": task_key,
        "task_id": task_id,
        "agent": agent,
        "session_token": token,
        "owner_pid": pid,
        "owner_host": host,
        "acquired_at": observed.isoformat(timespec="seconds"),
        "expires_at": expires.isoformat(timespec="seconds"),
    }
    if not acquired:
        info["reason"] = refusal_reason or "task_exec_lease_held_by_live_session"
        if existing is not None:
            info["existing"] = existing
    return bool(acquired), info


def renew_task_exec_lease(lease: dict[str, Any], *, now: dt.datetime | None = None) -> bool:
    observed = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    expires = observed + dt.timedelta(minutes=HEADLESS_SESSION_LEASE_TTL_MINUTES)
    try:
        conn = agent_router.connect(FARM_ROOT)
        try:
            conn.execute("BEGIN IMMEDIATE")
            renewed = agent_router.agent_scopes.renew_spawn_lease(
                conn,
                str(lease["task_key"]),
                owner_token=str(lease["session_token"]),
                owner_pid=int(lease["owner_pid"]),
                owner_host=str(lease["owner_host"]),
                now_iso=observed.isoformat(timespec="seconds"),
                expires_iso=expires.isoformat(timespec="seconds"),
            )
            conn.commit()
        finally:
            conn.close()
    except Exception:
        return False
    if renewed:
        lease["expires_at"] = expires.isoformat(timespec="seconds")
    return bool(renewed)


def release_task_exec_lease(lease: dict[str, Any] | None) -> None:
    if not lease or not lease.get("session_token"):
        return
    try:
        conn = agent_router.connect(FARM_ROOT)
        try:
            conn.execute("BEGIN IMMEDIATE")
            agent_router.agent_scopes.release_spawn_lease(
                conn,
                str(lease["task_key"]),
                owner_token=str(lease["session_token"]),
                owner_pid=int(lease["owner_pid"]),
                owner_host=str(lease["owner_host"]),
            )
            conn.commit()
        finally:
            conn.close()
    except Exception:
        # Expiry (TTL) remains the fail-safe if release storage is unavailable.
        pass


def claim_task_exec_leases(
    agent: str,
    task_ids: list[str],
    limit: int,
    *,
    now: dt.datetime | None = None,
    owner_pid: int | None = None,
    owner_host: str | None = None,
) -> list[dict[str, Any]]:
    """Claim up to ``limit`` distinct tasks, in the given priority order.

    Each won task carries a distinct pid-owned exec-lease. Tasks already pinned
    by another live session are skipped (never duplicated). Returns the leases
    for the tasks this launcher won; ``len(result) <= min(limit, len(task_ids))``.
    """
    leases: list[dict[str, Any]] = []
    if limit <= 0:
        return leases
    seen: set[str] = set()
    for task_id in task_ids:
        if len(leases) >= limit:
            break
        tid = str(task_id)
        if not tid or tid in seen:
            continue
        seen.add(tid)
        acquired, lease = acquire_task_exec_lease(
            agent, tid, now=now, owner_pid=owner_pid, owner_host=owner_host
        )
        if acquired:
            leases.append(lease)
    return leases


def reserve_no_change_evidence(
    agent: str,
    task_id: str,
    state: Any,
    artifact_path: Path,
    *,
    marker_root: Path | None = None,
    evidence_root: Path | None = None,
) -> dict[str, Any]:
    """Atomically reserve one evidence write per stable blocker-state hash."""
    allowed_root = (evidence_root or (REPO_ROOT / "docs" / "ops" / "evidence")).resolve()
    artifact = artifact_path.resolve()
    if not artifact.is_relative_to(allowed_root):
        raise ValueError(f"artifact path must stay below {allowed_root}")
    canonical = json.dumps(state, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    state_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    root = marker_root or NO_CHANGE_STATE_DIR
    marker = root / agent / task_id / f"{state_hash}.json"
    marker.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "qm.orchestration-no-change-state/v1",
        "agent": agent,
        "task_id": task_id,
        "state_sha256": state_hash,
        "artifact_path": str(artifact),
        "reserved_at": dt.datetime.now(dt.UTC).isoformat(),
    }
    try:
        fd = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        existing = json.loads(marker.read_text(encoding="utf-8"))
        return {
            "write_allowed": False,
            "reason": "state_hash_already_recorded",
            "state_sha256": state_hash,
            "marker_path": str(marker),
            "artifact_path": existing.get("artifact_path"),
        }
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    return {
        "write_allowed": True,
        "reason": "new_state_hash_reserved",
        "state_sha256": state_hash,
        "marker_path": str(marker),
        "artifact_path": str(artifact),
    }


def _claude_budget_policy() -> dict[str, Any]:
    defaults: dict[str, Any] = {
        "enabled": True,
        "max_runs_per_day": 0,
        "min_minutes_between_runs": 0,
        "max_sessions_per_run": 5,  # OWNER 2026-06-01: Claude = full worker at 5
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


def _claude_max_tasks_per_session() -> int:
    """Per-session drain cap (review c1 M2).

    Resolution order: QM_CLAUDE_MAX_TASKS_PER_SESSION env var >
    CLAUDE_BUDGET_POLICY.json ``max_tasks_per_session`` > the documented default
    of 4. Always at least 1 so a session works at least the task it is pinned to.
    """
    env_raw = os.environ.get("QM_CLAUDE_MAX_TASKS_PER_SESSION", "").strip()
    if env_raw:
        try:
            return max(1, int(env_raw))
        except ValueError:
            pass
    try:
        policy_value = _claude_budget_policy().get("max_tasks_per_session")
    except Exception:
        policy_value = None
    if policy_value is not None:
        try:
            return max(1, int(policy_value))
        except (TypeError, ValueError):
            pass
    return CLAUDE_MAX_TASKS_PER_SESSION_DEFAULT


def _pinned_max_tasks_per_session(agent: str) -> int:
    if agent == "claude":
        return _claude_max_tasks_per_session()
    if agent == "codex":
        env_raw = os.environ.get("QM_CODEX_MAX_TASKS_PER_SESSION", "").strip()
        if env_raw:
            try:
                return max(1, int(env_raw))
            except ValueError:
                pass
        return CODEX_MAX_TASKS_PER_SESSION_DEFAULT
    return 1


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

    Candidate eligibility is delegated to `_quota_lane_candidates`, so this
    wake gate cannot revive work that the capability/skill contract rejects.
    Fails OPEN so a DB error never starves the agent.
    """
    candidates, candidate_status = _quota_lane_candidates(agent)
    if candidate_status != "ok":
        return {
            "any_work": True,
            "reason": f"work_check_{candidate_status}",
            "candidate_status": candidate_status,
        }

    n_assigned = sum(1 for candidate in candidates if candidate["assigned"])
    n_backlog = len(candidates) - n_assigned
    return {
        "any_work": bool(candidates),
        f"{agent}_assigned": n_assigned,
        "backlog_unrouted": n_backlog,
        "candidate_status": candidate_status,
    }


def _quota_lane_candidates(agent: str) -> tuple[list[dict[str, Any]], str]:
    """Return work that satisfies one lane's full capability/skill contract."""
    import sqlite3 as _sqlite3

    db = FARM_ROOT / "state" / "farm_state.sqlite"
    if not db.exists():
        return [], "db_missing"
    con: _sqlite3.Connection | None = None
    try:
        con = _sqlite3.connect(db)
        con.row_factory = _sqlite3.Row
        registry = con.execute(
            "SELECT capabilities_json FROM agent_registry WHERE agent_id=?",
            (agent,),
        ).fetchone()
        capabilities = None
        if registry is not None:
            capabilities = set(json.loads(registry["capabilities_json"] or "[]"))
        declared_caps = agent_router._declared_registry_capabilities(con)
        governed_caps = agent_router._governed_routing_capabilities()
        rows = con.execute(
            """
            SELECT id, state, task_type, priority, assigned_agent, budget_class,
                   required_capabilities_json, required_skills_json, payload_json
            FROM agent_tasks
            WHERE (assigned_agent=? AND state IN ('TODO','IN_PROGRESS'))
               OR (state IN ('BACKLOG','TODO') AND (assigned_agent IS NULL OR assigned_agent=''))
            ORDER BY priority DESC, updated_at ASC
            """,
            (agent,),
        ).fetchall()
        candidates: list[dict[str, Any]] = []
        for row in rows:
            required = set(json.loads(row["required_capabilities_json"] or "[]"))
            skills = set(json.loads(row["required_skills_json"] or "[]"))
            row_payload = json.loads(row["payload_json"] or "{}")
            # Match agent_router.route_once exactly: declared/governed skills
            # are binding capabilities, while undeclared skill labels remain
            # descriptive metadata and do not strand otherwise-routable work.
            required |= skills & (declared_caps | governed_caps)
            # Same for payload-declared capabilities (routing-flapping defect,
            # ticket 2026-08-21). Without this union the two selectors disagreed
            # for every row written before the doctrine patch or outside
            # `enqueue_task`, i.e. exactly the rows the defect produced.
            required |= set(agent_router.payload_required_capabilities(row_payload)) & (
                declared_caps | governed_caps
            )
            # CEO decision D10 (round 4, 2026-09-04): scalpel-class work is
            # gated at the lane too, so this selector and `route_once` agree
            # about which lanes may see a `strategy_mechanize_source` row or a
            # payload carrying `scalpel: true`.
            required |= agent_router.scalpel_routing_capabilities(
                row["task_type"], row_payload
            )
            # Round-4 residual finding (2026-09-05): an INVALID scalpel marker is
            # a HELD config defect (route_once records it as a model-window
            # hold), so it must never be offered to ANY executing lane here -
            # not codex, not claude. Skip it so this selector agrees with
            # route_once that nothing runs the malformed row.
            if agent_router.invalid_scalpel_marker_hold(row_payload) is not None:
                continue
            assigned = str(row["assigned_agent"] or "")
            # A human-owned task is never offered to an automated lane, even
            # if a stale assignment or registry drift says otherwise.
            human_holder = agent_router._human_lane_holder(con, required, root=FARM_ROOT)
            if human_holder is not None and human_holder != agent:
                continue
            # Decision-bound rows belong to one lane only (doctrine
            # 2026-09-04 §5); they must not make another lane spawn either.
            pinned_agent = agent_router.decision_bound_agent(row_payload)
            if pinned_agent is not None and pinned_agent != agent:
                continue
            if capabilities is not None and not required.issubset(capabilities):
                continue
            candidates.append(
                {
                    "task_id": row["id"],
                    "state": str(row["state"]),
                    "task_type": row["task_type"],
                    "priority": int(row["priority"]),
                    "assigned": bool(assigned),
                    "budget_class": str(row["budget_class"] or "standard"),
                    "required_capabilities": sorted(required),
                    "payload": row_payload,
                }
            )
        return candidates, "ok"
    except Exception as exc:
        return [], f"db_error:{exc!r}"
    finally:
        if con is not None:
            con.close()


def _quota_lane_check(
    agent: str,
    *,
    config_path: Path | None = None,
    state_path: Path | None = None,
    summary_path: Path | None = None,
) -> dict[str, Any]:
    """Gate a 15-minute lane before any Codex/Claude CLI process is spawned."""
    if agent not in quota_spawn_gate.GATED_AGENTS:
        return {"allowed": True, "reason": "agent_not_quota_gated", "allowed_task_count": 1}

    candidates, candidate_status = _quota_lane_candidates(agent)
    if candidate_status != "ok":
        # DB visibility is an operations incident. Preserve the explicit
        # ops/review fail-open contract while still recording a gate decision.
        decision = quota_spawn_gate.evaluate_spawn(
            agent,
            "ops_issue",
            70,
            config_path=config_path,
            state_path=state_path,
            summary_path=summary_path,
        )
        return {
            "allowed": bool(decision.get("allowed")),
            "reason": "lane_db_unavailable_ops_continuity",
            "candidate_status": candidate_status,
            "allowed_task_count": 1 if decision.get("allowed") else 0,
            "selected_decision": decision,
        }
    if not candidates:
        return {
            "allowed": False,
            "reason": "no_quota_eligible_agent_tasks",
            "candidate_status": candidate_status,
            "allowed_task_count": 0,
        }

    allowed: list[tuple[dict[str, Any], dict[str, Any]]] = []
    denied: list[tuple[dict[str, Any], dict[str, Any]]] = []
    for candidate in candidates:
        decision = quota_spawn_gate.evaluate_spawn(
            agent,
            str(candidate["task_type"]),
            int(candidate["priority"]),
            config_path=config_path,
            state_path=state_path,
            summary_path=summary_path,
            payload=dict(candidate.get("payload") or {}),
            write_summary=False,
        )
        (allowed if decision.get("allowed") else denied).append((candidate, decision))

    selected_pair = allowed[0] if allowed else denied[0]
    quota_spawn_gate.record_gate_decision(
        selected_pair[1],
        state_path=state_path,
        summary_path=summary_path,
    )
    return {
        "allowed": bool(allowed),
        "reason": "quota_eligible_work_available" if allowed else "all_candidate_tasks_quota_blocked",
        "candidate_status": candidate_status,
        "candidate_count": len(candidates),
        "allowed_task_count": len(allowed),
        "blocked_task_count": len(denied),
        "allowed_task_ids": [str(candidate.get("task_id") or "") for candidate, _ in allowed],
        "selected_task": {
            key: value
            for key, value in selected_pair[0].items()
            if key not in {"payload", "state"}
        },
        "selected_decision": selected_pair[1],
        "allowed_invocations": [
            # Carry the row id with the invocation so the 5h model ledger can
            # name WHICH task spent the message (doctrine 2026-09-04 §3.1).
            {"task_id": str(candidate.get("task_id") or ""), **(decision.get("invocation") or {})}
            for candidate, decision in allowed
            if decision.get("invocation")
        ],
    }


def _write_lane_heartbeat(agent: str, slot: int = 0) -> None:
    """Lane heartbeat = 'this lane's scheduled infrastructure is alive', NOT
    'this lane is busy'. The router skips lanes whose heartbeat is older than
    LANE_HEARTBEAT_STALE_HOURS, so the heartbeat MUST be written before any
    empty-spawn guard: a drained lane that skips before heartbeating goes
    router-invisible and can never be assigned new work (codex deadlock
    2026-07-04..07). Stuck-broken lanes are handled by the router's 6h
    stale-IN_PROGRESS release, not by heartbeat staleness."""
    heartbeat_path = FARM_ROOT / "state" / f"lane_{agent}_heartbeat.json"
    try:
        heartbeat_path.parent.mkdir(parents=True, exist_ok=True)
        heartbeat_path.write_text(
            json.dumps({"agent": agent, "slot": slot, "pid": os.getpid(), "at": utc_stamp()},
                       sort_keys=True),
            encoding="utf-8",
        )
    except OSError:
        pass


def _refresh_headless_ownership(
    agent: str,
    slot: int,
    session_lease: dict[str, Any] | None,
    exec_lease: dict[str, Any] | None = None,
) -> None:
    _write_lane_heartbeat(agent, slot=slot)
    if session_lease is not None and not renew_headless_session_lease(session_lease):
        _journal_headless_skip(agent, "headless_session_lease_lost", session_lease)
        raise RuntimeError("headless session lease renewal refused")
    # Keep the per-task exec-lease alive for the duration of a legitimately long
    # task so it is never stolen by TTL expiry while the session is still working.
    if exec_lease is not None and not renew_task_exec_lease(exec_lease):
        _journal_headless_skip(agent, "task_exec_lease_lost", exec_lease)
        raise RuntimeError("task exec-lease renewal refused")


def _run_agent_with_session_lease(
    agent: str,
    dry_run: bool,
    stale_minutes: int,
    timeout_minutes: int,
    max_sessions: int,
    session_lease: dict[str, Any] | None,
) -> dict[str, Any]:
    codex_pinned_requested = agent == "codex" and max_sessions > 1
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
    quota_check: dict[str, Any] | None = None
    if agent in quota_spawn_gate.GATED_AGENTS and not dry_run:
        quota_check = _quota_lane_check(agent)
        if not quota_check.get("allowed"):
            return {
                "agent": agent,
                "ok": True,
                "skipped": True,
                "reason": "quota_gate_blocked",
                "quota_gate_check": quota_check,
            }
        max_sessions = min(
            max_sessions,
            max(1, int(quota_check.get("allowed_task_count") or 1)),
        )
        if agent == "codex" and not codex_pinned_requested:
            # The established --max-sessions 1 result contract predates pinned
            # task ids. Keep that path byte-identical; only the new fan-out path
            # consumes this internal eligibility detail.
            quota_check = {
                key: value
                for key, value in quota_check.items()
                if key != "allowed_task_ids"
            }
    session_count = max(1, max_sessions)
    if agent not in ("claude", "codex"):
        session_count = 1
    if agent == "codex" and not codex_pinned_requested:
        session_count = 1
    if agent == "kimi":
        # Hard cap, explicit (belt to the non-claude rule above): the OAuth
        # credential refresh race forbids concurrent kimi sessions (§3.6, §8).
        session_count = min(session_count, KIMI_MAX_SESSIONS)
    slot_invocations = list((quota_check or {}).get("allowed_invocations") or [])

    def slot_invocation(slot_index: int) -> dict[str, Any] | None:
        if not slot_invocations:
            return None
        return dict(slot_invocations[min(slot_index, len(slot_invocations) - 1)] or {})

    def task_invocation(task_id: str, slot_index: int) -> dict[str, Any] | None:
        for invocation in slot_invocations:
            if str(invocation.get("task_id") or "") == str(task_id):
                return dict(invocation)
        if codex_pinned_requested:
            # Preserve task attribution even if an allowed gate decision did
            # not need an explicit model override. Never reuse another task's
            # invocation merely because it occupied the same worktree slot.
            return {"task_id": str(task_id)}
        return slot_invocation(slot_index)

    # A Codex >1 dry-run is a read-only pinned plan: no exec lease, worktree
    # creation, model booking or child process.  The legacy --max-sessions 1
    # path below remains byte-for-byte prompt compatible and task-agnostic.
    if codex_pinned_requested and dry_run:
        candidates, candidate_status = _quota_lane_candidates("codex")
        if candidate_status != "ok":
            return {
                "agent": "codex",
                "ok": True,
                "skipped": True,
                "dry_run": True,
                "reason": "codex_candidate_query_unavailable",
                "candidate_status": candidate_status,
                "planned_task_ids": [],
            }
        assigned_task_ids = [
            str(candidate["task_id"])
            for candidate in candidates
            if candidate.get("assigned") and candidate.get("state") == "IN_PROGRESS"
        ]
        planned_count = min(session_count, len(assigned_task_ids))
        worktree_plan = prepare_pinned_worktree_slots(
            "codex", planned_count, create=False
        )
        planned_slots = list(worktree_plan.get("slot_ids") or [])[:planned_count]
        planned_count = min(planned_count, len(planned_slots))
        return {
            "agent": "codex",
            "ok": bool(worktree_plan.get("ok")) or planned_count == 0,
            "returncode": 0 if (worktree_plan.get("ok") or planned_count == 0) else 1,
            "dry_run": True,
            "dry_run_verified": bool(worktree_plan.get("ok")) or planned_count == 0,
            "reason": "codex_pinned_fanout_plan",
            "requested_max_sessions": max_sessions,
            "max_sessions": planned_count,
            "planned_task_ids": assigned_task_ids[:planned_count],
            "planned_slots": planned_slots,
            "worktree_plan": worktree_plan,
        }

    # --- Pinned fan-out + bounded drain (Claude and Codex >1) ----------------
    # Each concurrent session owns exactly one task exec-lease before spawn.
    # After it exits, the same slot may lease the next quota-eligible assigned
    # task, bounded by max_tasks_per_session and the controller deadline.
    if agent == "claude" and not dry_run:
        return _run_claude_session_chains(
            dry_run=dry_run,
            stale_minutes=stale_minutes,
            timeout_minutes=timeout_minutes,
            session_count=session_count,
            session_lease=session_lease,
            slot_invocation=slot_invocation,
            task_invocation=task_invocation,
            quota_check=quota_check,
        )
    if codex_pinned_requested and not dry_run:
        return _run_pinned_session_chains(
            agent="codex",
            dry_run=dry_run,
            stale_minutes=stale_minutes,
            timeout_minutes=timeout_minutes,
            session_count=session_count,
            session_lease=session_lease,
            slot_invocation=slot_invocation,
            task_invocation=task_invocation,
            quota_check=quota_check,
            require_current_worktrees=True,
        )

    # Codex --max-sessions 1, Gemini/Kimi, and the Claude dry-run preview retain
    # the historical task-agnostic single-session behavior.
    if session_count == 1:
        results = [
            run_agent_slot(
                agent,
                1,
                dry_run,
                stale_minutes,
                timeout_minutes,
                slot_invocation(0),
                session_lease,
                None,
                None,
            )
        ]
    else:
        with ThreadPoolExecutor(max_workers=session_count) as executor:
            futures = [
                executor.submit(
                    run_agent_slot,
                    agent,
                    slot,
                    dry_run,
                    stale_minutes,
                    timeout_minutes,
                    slot_invocation(slot - 1),
                    session_lease,
                    None,
                    None,
                )
                for slot in range(1, session_count + 1)
            ]
            results = [future.result() for future in futures]
    ok = all(bool(r.get("ok")) for r in results)
    return {
        "agent": agent,
        "ok": ok,
        "returncode": 0 if ok else 1,
        "max_sessions": session_count,
        "leased_task_ids": [],
        "quota_gate_check": quota_check,
        "results": results,
    }


def _run_claude_session_chains(
    *,
    dry_run: bool,
    stale_minutes: int,
    timeout_minutes: int,
    session_count: int,
    session_lease: dict[str, Any] | None,
    slot_invocation: Any,
    task_invocation: Any | None = None,
    quota_check: dict[str, Any] | None,
) -> dict[str, Any]:
    """Backward-compatible wrapper for the original Claude pinned path."""
    return _run_pinned_session_chains(
        agent="claude",
        dry_run=dry_run,
        stale_minutes=stale_minutes,
        timeout_minutes=timeout_minutes,
        session_count=session_count,
        session_lease=session_lease,
        slot_invocation=slot_invocation,
        task_invocation=task_invocation,
        quota_check=quota_check,
        require_current_worktrees=False,
    )


def _run_pinned_session_chains(
    *,
    agent: str,
    dry_run: bool,
    stale_minutes: int,
    timeout_minutes: int,
    session_count: int,
    session_lease: dict[str, Any] | None,
    slot_invocation: Any,
    task_invocation: Any | None,
    quota_check: dict[str, Any] | None,
    require_current_worktrees: bool,
) -> dict[str, Any]:
    """Drive disjoint pid-owned task chains for one supported premium lane.

    Candidate visibility failures fail closed.  Initial tasks are disjoint and
    leased before any child spawn.  Claiming the next task is serialized, and
    every task id is worked at most once per controller run.  Codex additionally
    requires a clean worktree containing the canonical launch commit; dirty or
    diverged legacy slots are skipped without reset or deletion.
    """
    prior_candidate_status = str((quota_check or {}).get("candidate_status") or "ok")
    if prior_candidate_status != "ok":
        return {
            "agent": agent,
            "ok": True,
            "skipped": True,
            "reason": f"{agent}_candidate_query_unavailable",
            "candidate_status": prior_candidate_status,
            "quota_gate_check": quota_check,
        }
    candidates, candidate_status = _quota_lane_candidates(agent)
    if candidate_status != "ok":
        return {
            "agent": agent,
            "ok": True,
            "skipped": True,
            "reason": f"{agent}_candidate_query_unavailable",
            "candidate_status": candidate_status,
            "quota_gate_check": quota_check,
        }

    owner_pid = os.getpid()
    max_tasks_per_session = _pinned_max_tasks_per_session(agent)
    deadline = time.monotonic() + max(1, timeout_minutes) * 60
    claimed_lock = threading.Lock()
    claimed_ids: set[str] = set()
    leased_task_ids: list[str] = []
    quota_allowed_ids = {
        str(task_id)
        for task_id in ((quota_check or {}).get("allowed_task_ids") or [])
        if str(task_id)
    }

    def _eligible_ids(rows: list[dict[str, Any]]) -> list[str]:
        ids: list[str] = []
        for candidate in rows:
            if not candidate.get("assigned"):
                continue
            if agent == "codex" and candidate.get("state") != "IN_PROGRESS":
                continue
            task_id = str(candidate.get("task_id") or "")
            if not task_id:
                continue
            if quota_allowed_ids and task_id not in quota_allowed_ids:
                continue
            ids.append(task_id)
        return ids

    assigned_task_ids = _eligible_ids(candidates)
    if not assigned_task_ids:
        return {
            "agent": agent,
            "ok": True,
            "skipped": True,
            "reason": f"no_quota_eligible_assigned_{agent}_task",
            "candidate_status": candidate_status,
            "quota_gate_check": quota_check,
        }

    worktree_plan: dict[str, Any] | None = None
    if require_current_worktrees:
        requested_slots = min(session_count, len(assigned_task_ids))
        worktree_plan = prepare_pinned_worktree_slots(
            agent, requested_slots, create=True
        )
        slot_ids = [int(slot) for slot in (worktree_plan.get("slot_ids") or [])]
        if not slot_ids:
            return {
                "agent": agent,
                "ok": True,
                "skipped": True,
                "reason": "no_safe_codex_worktree_slots",
                "candidate_status": candidate_status,
                "quota_gate_check": quota_check,
                "worktree_plan": worktree_plan,
            }
    else:
        slot_ids = list(range(1, session_count + 1))

    def _claim_next() -> dict[str, Any] | None:
        with claimed_lock:
            fresh, status = _quota_lane_candidates(agent)
            if status != "ok":
                return None
            for tid in _eligible_ids(fresh):
                if tid in claimed_ids:
                    continue
                acquired, lease = acquire_task_exec_lease(
                    agent, tid, owner_pid=owner_pid
                )
                if acquired:
                    claimed_ids.add(tid)
                    leased_task_ids.append(tid)
                    return lease
            return None

    def _run_chain(slot: int, initial_lease: dict[str, Any]) -> list[dict[str, Any]]:
        chain_results: list[dict[str, Any]] = []
        lease: dict[str, Any] | None = initial_lease
        while lease is not None:
            try:
                invocation = (
                    task_invocation(str(lease["task_id"]), max(0, slot - 1))
                    if task_invocation is not None
                    else slot_invocation(max(0, slot - 1))
                )
                res = run_agent_slot(
                    agent,
                    slot,
                    dry_run,
                    stale_minutes,
                    timeout_minutes,
                    invocation,
                    session_lease,
                    lease["task_id"],
                    lease,
                )
            finally:
                # run_agent_slot releases its own exec-lease on exit; this
                # backstop covers a raise before that release. Owner-scoped and
                # idempotent, so the double call is safe.
                release_task_exec_lease(lease)
            chain_results.append(res)
            if len(chain_results) >= max_tasks_per_session:
                break
            if time.monotonic() >= deadline:
                break
            lease = _claim_next()
        return chain_results

    initial_leases = claim_task_exec_leases(
        agent, assigned_task_ids, min(session_count, len(slot_ids)), owner_pid=owner_pid
    )
    for lease in initial_leases:
        claimed_ids.add(str(lease["task_id"]))
        leased_task_ids.append(str(lease["task_id"]))

    if not initial_leases:
        return {
            "agent": agent,
            "ok": True,
            "skipped": True,
            "reason": f"no_unpinned_{agent}_task",
            "candidate_status": candidate_status,
            "assigned_candidates": len(assigned_task_ids),
            "quota_gate_check": quota_check,
            "worktree_plan": worktree_plan,
        }

    concurrent = len(initial_leases)
    active_slots = slot_ids[:concurrent]
    results: list[dict[str, Any]] = []
    if concurrent == 1:
        results = _run_chain(active_slots[0], initial_leases[0])
    else:
        with ThreadPoolExecutor(max_workers=concurrent) as executor:
            futures = [
                executor.submit(_run_chain, slot, lease)
                for slot, lease in zip(active_slots, initial_leases)
            ]
            for future in futures:
                results.extend(future.result())

    ok = all(bool(r.get("ok")) for r in results)
    return {
        "agent": agent,
        "ok": ok,
        "returncode": 0 if ok else 1,
        "max_sessions": concurrent,
        "slots": active_slots,
        "tasks_worked": len(leased_task_ids),
        "max_tasks_per_session": max_tasks_per_session,
        "leased_task_ids": leased_task_ids,
        "quota_gate_check": quota_check,
        "worktree_plan": worktree_plan,
        "results": results,
    }


def run_agent(
    agent: str,
    dry_run: bool,
    stale_minutes: int,
    timeout_minutes: int,
    max_sessions: int,
) -> dict[str, Any]:
    if dry_run:
        return _run_agent_with_session_lease(
            agent, dry_run, stale_minutes, timeout_minutes, max_sessions, None
        )

    _write_lane_heartbeat(agent)
    # The interactive marker exists to stop a headless CLAUDE cycle from racing the interactive
    # Claude session (duplicate-session race 2026-08-23/24). It must never pause the Codex or
    # gemini lanes: 2026-09-12 15:30Z -> 2026-09-13 11:15Z the Codex ticket lane skipped 80 cycles
    # with interactive_orchestrator_active while five priority tickets cycled through stale-release
    # every six hours (Orchestrator 2026-09-13 11:3xZ).
    interactive = interactive_orchestrator_status() if agent == "claude" else {"active": False, "reason": "not_claude_lane"}
    if interactive.get("active"):
        _journal_headless_skip(agent, "interactive_orchestrator_active", interactive)
        return {
            "agent": agent,
            "ok": True,
            "returncode": 0,
            "skipped": True,
            "reason": "interactive_orchestrator_active",
            "interactive_guard": interactive,
        }

    acquired, session_lease = acquire_headless_session_lease(agent)
    if not acquired:
        _journal_headless_skip(agent, str(session_lease.get("reason")), session_lease)
        return {
            "agent": agent,
            "ok": True,
            "returncode": 0,
            "skipped": True,
            "reason": session_lease.get("reason", "foreign_live_headless_session"),
            "session_lease": session_lease,
        }
    try:
        result = _run_agent_with_session_lease(
            agent,
            dry_run,
            stale_minutes,
            timeout_minutes,
            max_sessions,
            session_lease,
        )
        result["session_lease"] = session_lease
        return result
    finally:
        release_headless_session_lease(session_lease)


def main() -> int:
    os.environ.setdefault("QM_AGENT_ID", "controller")
    parser = argparse.ArgumentParser(description="Run one headless agent orchestration pass.")
    parser.add_argument("--agent", choices=("codex", "gemini", "claude", "kimi"))
    parser.add_argument("--dry-run", action="store_true", help="Verify prompt/lock/command without launching the model.")
    # Must remain above the 225-minute agent timeout and the PT4H task limit.
    parser.add_argument("--stale-minutes", type=int, default=250)
    # Leave cleanup headroom below the scheduled task's PT4H execution limit.
    parser.add_argument("--timeout-minutes", type=int, default=225)
    parser.add_argument("--max-sessions", type=int, default=1, help="Claude-only parallel slot count.")
    parser.add_argument("--dedupe-no-change-task", help="Reserve/reuse one evidence artifact for a stable task-state hash.")
    parser.add_argument("--state-json", type=Path, help="Canonical JSON containing stable blocker facts only.")
    parser.add_argument("--artifact-path", type=Path, help="Existing or planned canonical evidence path for the state hash.")
    parser.add_argument(
        "--touch-interactive-flag",
        action="store_true",
        help="Write one fresh interactive-orchestrator heartbeat and exit.",
    )
    parser.add_argument(
        "--interactive-heartbeat-loop",
        action="store_true",
        help="Refresh the interactive heartbeat every ten minutes while the parent lives.",
    )
    parser.add_argument("--minutes", type=float, help="Maximum heartbeat-loop duration in minutes.")
    args = parser.parse_args()
    if args.touch_interactive_flag and args.interactive_heartbeat_loop:
        parser.error("interactive heartbeat modes are mutually exclusive")
    if args.touch_interactive_flag:
        result = touch_interactive_orchestrator_flag()
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if args.interactive_heartbeat_loop:
        if args.minutes is None:
            parser.error("--interactive-heartbeat-loop requires --minutes N")
        result = run_interactive_heartbeat_loop(args.minutes)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if args.minutes is not None:
        parser.error("--minutes is only valid with --interactive-heartbeat-loop")
    if not args.agent:
        parser.error("--agent is required for headless orchestration and no-change dedupe")
    if args.dedupe_no_change_task:
        if args.state_json is None or args.artifact_path is None:
            parser.error("--dedupe-no-change-task requires --state-json and --artifact-path")
        state = json.loads(args.state_json.read_text(encoding="utf-8"))
        result = reserve_no_change_evidence(
            args.agent,
            args.dedupe_no_change_task,
            state,
            args.artifact_path,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    result = run_agent(args.agent, args.dry_run, args.stale_minutes, args.timeout_minutes, args.max_sessions)
    print(json.dumps(result, indent=2, sort_keys=True))
    return int(result.get("returncode", 0) or 0)


if __name__ == "__main__":
    raise SystemExit(main())
