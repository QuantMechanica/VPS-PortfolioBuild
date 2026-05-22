"""Headless single-pass orchestration wrapper for Codex/Gemini.

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
from pathlib import Path
from typing import Any


REPO_ROOT = Path(r"C:\QM\repo")
FARM_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
LOG_DIR = FARM_ROOT / "logs"
LOCK_DIR = FARM_ROOT / "locks"
PYTHON_EXE = Path(r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe")
CODEX_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\codex.cmd")
GEMINI_FALLBACK = Path(r"C:\Users\Administrator\AppData\Roaming\npm\gemini.cmd")
CODEX_HOME = Path(os.environ.get("CODEX_HOME", r"C:\Users\Administrator\.codex"))
AGENT_USER_HOME = Path(r"C:\Users\Administrator")


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
    raise ValueError(f"unsupported agent: {agent}")


def agent_env(agent: str) -> dict[str, str]:
    env = os.environ.copy()
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
    return env


def build_prompt(agent: str) -> str:
    edge_charter = REPO_ROOT / "docs" / "ops" / "EDGE_LAB_CHARTER_2026-05-22.md"
    profitability = REPO_ROOT / "docs" / "ops" / "PROFITABILITY_TRACK_2026-05-21.md"
    return f"""You are {agent} for QuantMechanica, launched by a headless scheduled task.

Execute exactly one single-pass orchestration cycle, then exit. Do not start a
15-minute sleep loop; the Windows scheduler provides cadence.

Working directory: C:/QM/repo

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
   python tools/strategy_farm/agent_router.py list-tasks --agent {agent}
2. For every IN_PROGRESS task assigned to {agent}, in ascending numeric priority:
   read payload and skills, produce a durable artifact, run focused verification,
   then update the router with:
   python tools/strategy_farm/agent_router.py update-task <task_id> --state REVIEW --artifact-path "<artifact>" --verdict "<short_verdict>"
3. Repeat task handling until no IN_PROGRESS {agent} task remains.
4. If no task remains, run farmctl health and check QM5_10260 queue state. Do not invent untracked work.
5. Exit.

Hard rules:
- Do not choose work outside the deterministic router.
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
    except OSError:
        return False
    return True


def acquire_lock(agent: str, stale_minutes: int) -> tuple[bool, dict[str, Any]]:
    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    lock_path = LOCK_DIR / f"{agent}_orchestration.lock"
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


def command_for(agent: str, prompt: str) -> list[str]:
    cli = resolve_cli(agent)
    if agent == "codex":
        return [
            cli,
            "exec",
            "--dangerously-bypass-approvals-and-sandbox",
            "--cd",
            str(REPO_ROOT),
        ]
    if agent == "gemini":
        return [
            cli,
            "--prompt",
            "Execute the single-pass QuantMechanica orchestration instructions from stdin.",
            "--approval-mode",
            "yolo",
            "--skip-trust",
            "--include-directories",
            str(REPO_ROOT),
        ]
    raise ValueError(f"unsupported agent: {agent}")


def run_agent(agent: str, dry_run: bool, stale_minutes: int, timeout_minutes: int) -> dict[str, Any]:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = utc_stamp()
    prompt = build_prompt(agent)
    prompt_path = LOG_DIR / f"{agent}_orchestration_prompt_{stamp}.md"
    live_log = LOG_DIR / f"{agent}_orchestration_{stamp}.live.log"
    result_path = LOG_DIR / f"{agent}_orchestration_{stamp}.json"
    prompt_path.write_text(prompt, encoding="utf-8", newline="\n")

    locked, lock_info = acquire_lock(agent, stale_minutes)
    if not locked:
        payload = {
            "agent": agent,
            "ok": True,
            "skipped": True,
            "reason": lock_info.get("reason"),
            "lock": lock_info,
            "result_path": str(result_path),
        }
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        return payload

    cmd = command_for(agent, prompt)
    payload: dict[str, Any] = {
        "agent": agent,
        "dry_run": dry_run,
        "prompt_path": str(prompt_path),
        "live_log": str(live_log),
        "command": cmd,
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
                cwd=str(REPO_ROOT),
                stdin=stdin_f,
                stdout=stdout_f,
                stderr=subprocess.STDOUT,
                env=agent_env(agent),
                shell=True,
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
        return payload
    except Exception as exc:
        payload.update({"ok": False, "returncode": 1, "error": repr(exc)})
        return payload
    finally:
        payload["finished_at"] = dt.datetime.now(dt.UTC).isoformat()
        result_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        release_lock(lock_info)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run one headless agent orchestration pass.")
    parser.add_argument("--agent", choices=("codex", "gemini"), required=True)
    parser.add_argument("--dry-run", action="store_true", help="Verify prompt/lock/command without launching the model.")
    parser.add_argument("--stale-minutes", type=int, default=180)
    parser.add_argument("--timeout-minutes", type=int, default=240)
    args = parser.parse_args()
    result = run_agent(args.agent, args.dry_run, args.stale_minutes, args.timeout_minutes)
    print(json.dumps(result, indent=2, sort_keys=True))
    return int(result.get("returncode", 0) or 0)


if __name__ == "__main__":
    raise SystemExit(main())
