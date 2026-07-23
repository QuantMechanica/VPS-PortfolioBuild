#!/usr/bin/env python3
"""QuantMechanica - Silent-Failure Meta-Monitor (task #11).

WHY THIS EXISTS
  Six failure classes were LOG-ONLY until an audit found them the hard way:
    1. 660 consecutive quota-governor "metrics unavailable" skip cycles
       (Codex spend unsteered for days -- see quota_governor._codex_weekly_window).
    2. A 9-day REVIEW-lane stall (agent_tasks stuck in state=REVIEW).
    3. Scheduled tasks dying with LastTaskResult 267014 (0x4130A, killed at the
       ExecutionTimeLimit) with nobody watching.
    4. Worker respawn crashes visible only in terminal_worker_*.log.err files.
    5. Pump blocked:true streaks (build lane wedged for hours).
    6. State files mutated / going stale without an alarm trail.
  Each was individually observable in a log or a state file, but no watcher tied
  those signals into one durable health surface. This meta-monitor reads (never
  mutates) the farm's own logs/state/DB, decides OK / WARN / FAIL per invariant,
  and writes a compact sidecar for inspection and health aggregation.

INTEGRATION WITH HEALTH STATE (pipeline mail is OWNER-disabled)
  The former hourly Gmail dispatcher consumed health.json fingerprints. OWNER
  policy since 2026-07-23 disables that separate PIPELINE FAIL/OK mail channel;
  this monitor therefore produces health evidence only and never sends mail.
  For compatibility with existing readers, it:
    * writes a health.json-SHAPED sidecar: ALARM_SIDECAR (checks[] with the exact
      name/status/detail/action_hint keys health consumers understand), and
    * exposes merge_into_health(health) -- a drop-in that folds this monitor's
      non-OK checks into a health dict, escalates `overall`, and (crucially)
      injects its OWN staleness as a FAIL if the monitor itself died.
  gmail_alarm.py still imports the merge helper for backwards compatibility,
  but its executable PIPELINE FAIL/OK path is policy-disabled. The single daily
  MorningBriefing and per-boot diagnostic use the shared SMTP helper directly.

DESIGN CONTRACT
  * Single run-and-exit; scheduled every 15 min (pythonw direct, like the intake
    task). Target runtime < 30s. Pure stdlib.
  * STRICTLY read-only on farm_state.sqlite (opened file:...?mode=ro). Reads logs
    and state files; writes ONLY its own three artifacts under D:/QM/reports/state.
  * Every threshold lives in CONFIG at the top.
  * Every check handles "source file/dir missing" as its own WARN.
  * Incident dedupe: per-check state (first_seen, streak, last_status) so an
    alarm opens once, stays quiet while ongoing, and logs RECOVERED on clear.
  * Every emitted alarm line carries an evidence path + a first-seen timestamp.
  * A crash inside any one check becomes its own WARN (`check_error:<name>`);
    it never blinds the other checks.

Run manually (read-only; only writes this monitor's own state/alarm files):
    python tools/strategy_farm/silent_failure_monitor.py
    python tools/strategy_farm/silent_failure_monitor.py --print   # human table, no state write
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import traceback
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIG — every threshold, in one place
# ─────────────────────────────────────────────────────────────────────────────
CONFIG = {
    # ── check 1: scheduled-task health ──────────────────────────────────────
    # LastTaskResult codes that are NOT failures:
    #   0          = success
    #   267009     = 0x41301 task currently running
    #   267011     = 0x41303 task has not yet run (freshly registered, e.g. the
    #                intake sweep before its first fire) -> benign, never alarm.
    "schtask_benign_results": {0, 267009, 267011},
    # Codes that are ALWAYS a hard failure on a live/recurring task:
    #   267014     = 0x4130A killed at the ExecutionTimeLimit  (the motivating bug)
    #   2147943648 = 0x800710E0 the task launch was refused / an instance is already running past window
    "schtask_hardfail_results": {267014, 2147943648},
    # Transient/ad-hoc tasks the run_smoke + compile harness register and tear down
    # (QM_DEV<n>_SMOKE_<hex>, QM_*_SMOKE_*). They are not persistent farm infra and
    # their result codes are harness churn, not a silent-failure class — ignore them.
    "schtask_ignore_patterns": (r"_SMOKE_", r"^QM_DEV\d"),
    # These logon-only GUI tasks are intentionally not demand-startable. Their
    # availability is adjudicated from live_uptime_watchdog.json instead of a
    # historical LastTaskResult (0x800710E0 is expected for a Disc-session
    # demand-start attempt on this host).
    "schtask_live_logon_owned_elsewhere": {
        "QM_T_Live_AtLogon",
        "QM_FTMO_AtLogon",
        "QM_Live_MT5_SessionSupervisor",
    },
    "schtask_recurring_horizon_h": 26,   # NextRun within this window ⇒ "actively recurring"
    "schtask_oneoff_recent_h": 48,       # a one-off's failure is only actionable if it ran this recently
    "schtask_parked_horizon_days": 200,  # NextRun farther out than this ⇒ parked/manual, ignore generic results
    "schtask_overdue_grace_mult": 2.0,   # overdue if now-NextRun > mult*cadence + pad
    "schtask_overdue_pad_min": 5,
    # Explicit cadence (minutes) for recurring tasks whose NAME lacks a _<n>min suffix.
    "schtask_explicit_cadence_min": {
        "QM_StrategyFarm_QuotaPull": 5,
        "QM_StrategyFarm_QuotaGovernor": 15,
        "QM_StrategyFarm_TesterCachePurge": 20,
        "QM_StrategyFarm_LiveBookPulse": 30,
        "QM_StrategyFarm_CodexFleetPacer": 15,
        "QM_StrategyFarm_AgyGovernor": 15,
        "QM_T_Live_Watchdog": 1,
        "QM_FTMO_TrialPulse": 30,
    },

    # ── check 2: quota governor ─────────────────────────────────────────────
    "quota_skip_warn": 8,     # governor itself logs a WARNING at 8 (~2h @ 15min)
    "quota_skip_fail": 32,    # ~8h unsteered ⇒ escalate to FAIL (the 660-cycle class)
    "quota_gov_silent_warn_min": 30,   # governor log mtime older than this ⇒ WARN
    "quota_gov_silent_fail_min": 90,   # ⇒ FAIL (governor task itself dead)

    # ── check 3: REVIEW lane ────────────────────────────────────────────────
    "review_median_age_warn_h": 72,
    "review_median_age_fail_h": 168,   # 7d (the 9-day stall class ⇒ FAIL)
    "review_count_warn": 100,
    "review_count_fail": 200,

    # ── check 4: purge futility ─────────────────────────────────────────────
    "purge_disk_floor_gb": 40.0,       # only "futile" when disk is genuinely low
    "purge_reclaimed_epsilon_gb": 0.1, # reclaimed ≈ 0
    "purge_consecutive_runs": 3,       # consecutive acting runs that reclaimed nothing
    "purge_recent_window_min": 90,     # the streak must be recent (purge acts every 20min)

    # ── check 5: worker crash burst ─────────────────────────────────────────
    "worker_err_burst_window_min": 15,
    "worker_err_burst_count": 3,       # ≥3 .err files freshly touched...
    "worker_err_crash_signatures": ("Traceback", "Error", "Exception", "Fatal", "OSError"),
    "worker_daemon_min": 5,            # < this many terminal_worker.py while factory should be up ⇒ FAIL

    # ── check 6: pump blockade ──────────────────────────────────────────────
    "pump_block_window_min": 130,      # look back ~2h10m
    "pump_block_marker": "PUMP_BLOCKED",
    "pump_block_min_runs": 3,          # need at least this many logs in window to call it a streak

    # ── check 7: heartbeats ─────────────────────────────────────────────────
    "hb_backup_warn_h": 26,
    "hb_backup_fail_h": 50,
    "hb_health_warn_min": 30,
    "hb_health_fail_min": 60,
    "hb_cockpit_warn_min": 15,
    "hb_cockpit_fail_min": 45,

    # ── check 8: both live MT5 processes + recovery readiness ──────────────
    "live_watchdog_warn_stale_min": 3,
    "live_watchdog_fail_stale_min": 7,

    # ── check 9: GoogleDriveFS liveness (G: is a per-user mount; SYSTEM can
    #    NEVER Test-Path G:\, so this check is strictly process-based) ─────────
    # 2026-07-20 incident: GoogleDriveFS died after a console disconnect; G:
    # vanished for every consumer (nightly backup FATAL, vault sync dead,
    # morning-brief vault copy into the void) with zero alarms. The one
    # sanctioned self-heal: Start-ScheduledTask QM_GoogleDrive_AtLogon
    # (InteractiveToken; starts DriveFS in the logged-on qm-admin session) —
    # exactly the manual recovery that fixed the incident. This is the
    # monitor's ONLY mutating action; it is idempotent and touches no farm
    # state. Heal only attempted when a user session is active.
    "gdrive_heal_task": "QM_GoogleDrive_AtLogon",
    "gdrive_heal_enabled": True,

    # ── check 10 / merge: monitor self-staleness (evaluated by the consumer) ─
    "monitor_self_stale_warn_min": 25,   # merge_into_health injects WARN past this
    "monitor_self_stale_fail_min": 45,   # ...and FAIL past this (monitor task dead)

    # ── infra ───────────────────────────────────────────────────────────────
    # 50s (was 25): the probe enumerates ~75 QM_* tasks + a full Win32_Process
    # scan; under factory load the 05:00Z run blew 25s and degraded every
    # probe-based check to WARN (2026-07-20). Target runtime stays <30s normal.
    "powershell_timeout_sec": 50,
}

# ─────────────────────────────────────────────────────────────────────────────
#  Paths (all inputs read-only; outputs live under D:/QM/reports/state)
# ─────────────────────────────────────────────────────────────────────────────
FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_STATE = Path(r"D:\QM\reports\state")

DB_PATH = FARM_ROOT / "state" / "farm_state.sqlite"
HEALTH_JSON = FARM_ROOT / "state" / "health.json"
COCKPIT_HTML = FARM_ROOT / "dashboards" / "cockpit.html"
FACTORY_OFF_FLAG = FARM_ROOT / "state" / "FACTORY_OFF.flag"
LOGS_DIR = FARM_ROOT / "logs"
WORKER_ERR_GLOB = "terminal_worker_*.log.err"
PUMP_LOG_GLOB = "pump_task_*.log"

QUOTA_GOV_LOG = REPORTS_STATE / "quota_governor.log"
QUOTA_GOV_STATE = REPORTS_STATE / "quota_governor_state.json"
PURGE_LOG = REPORTS_STATE / "tester_cache_purge.log"
BACKUP_LOG = REPORTS_STATE / "backup_nightly.log"
LIVE_UPTIME_STATE = REPORTS_STATE / "live_uptime_watchdog.json"

# Outputs (this monitor's ONLY writes)
MONITOR_STATE = REPORTS_STATE / "silent_failure_monitor_state.json"
MONITOR_LOG = REPORTS_STATE / "silent_failure_monitor.log"
ALARM_SIDECAR = REPORTS_STATE / "silent_failure_alarms.json"

OK, WARN, FAIL = "OK", "WARN", "FAIL"
_SEVERITY = {OK: 0, WARN: 1, FAIL: 2}


# ─────────────────────────────────────────────────────────────────────────────
#  Small helpers
# ─────────────────────────────────────────────────────────────────────────────
def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _utc_iso(when: dt.datetime | None = None) -> str:
    return (when or _now()).strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    text = str(value).strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _file_age_min(path: Path) -> float | None:
    """Minutes since the file was last modified, or None if it does not exist."""
    try:
        return (time.time() - path.stat().st_mtime) / 60.0
    except OSError:
        return None


def _tail_text(path: Path, max_bytes: int = 65536) -> str:
    try:
        size = path.stat().st_size
        with open(path, "rb") as fh:
            if size > max_bytes:
                fh.seek(size - max_bytes)
            raw = fh.read()
        return raw.decode("utf-8", errors="replace")
    except OSError:
        return ""


def _creationflags_no_window() -> int:
    if sys.platform == "win32" and hasattr(subprocess, "CREATE_NO_WINDOW"):
        return subprocess.CREATE_NO_WINDOW
    return 0


def finding(name: str, status: str, detail: str, *, value=None, threshold=None,
            hint: str = "", evidence: str = "") -> dict:
    """One health-compatible check result (+ evidence)."""
    return {
        "name": name,
        "status": status,
        "value": value,
        "threshold": threshold,
        "detail": detail,
        "action_hint": hint,
        "evidence": evidence,
    }


def _connect_ro() -> sqlite3.Connection:
    """Open farm_state.sqlite strictly read-only (URI mode=ro)."""
    uri = "file:" + str(DB_PATH).replace("\\", "/") + "?mode=ro"
    con = sqlite3.connect(uri, uri=True, timeout=5)
    con.row_factory = sqlite3.Row
    return con


# ─────────────────────────────────────────────────────────────────────────────
#  Windows probe: ONE powershell call returns scheduled tasks + worker count.
#  Dates are pre-formatted to UTC ISO strings in-shell so we never have to parse
#  PS5.1's /Date(ms)/ JSON serialization.
# ─────────────────────────────────────────────────────────────────────────────
_PS_PROBE = r"""
$ErrorActionPreference = 'SilentlyContinue'
$tasks = @()
foreach ($t in Get-ScheduledTask -TaskName 'QM_*') {
    $i = Get-ScheduledTaskInfo -TaskName $t.TaskName
    $tasks += [pscustomobject]@{
        Name       = $t.TaskName
        State      = $t.State.ToString()
        LastResult = [int64]$i.LastTaskResult
        LastRun    = if ($i.LastRunTime) { $i.LastRunTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $null }
        NextRun    = if ($i.NextRunTime) { $i.NextRunTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $null }
    }
}
$workers = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
[pscustomobject]@{ tasks = $tasks; worker_count = $workers } | ConvertTo-Json -Depth 4 -Compress
"""


def _tasklist_count(image: str) -> int | None:
    """Count processes named `image` via native tasklist — enumerates ALL
    sessions reliably. Chosen after 2026-07-20 debugging: from THIS monitor's
    exact spawn chain (SYSTEM task -> pythonw -> powershell) both Get-Process
    and Get-CimInstance returned 0 for another user's GoogleDriveFS.exe, while
    a directly-scheduled SYSTEM powershell saw it fine. tasklist is immune to
    whatever scopes that chain. None = probe failure (caller emits WARN)."""
    try:
        out = subprocess.run(
            ["tasklist", "/FI", f"IMAGENAME eq {image}", "/NH"],
            capture_output=True, text=True, timeout=20,
            creationflags=_creationflags_no_window(),
        )
        return (out.stdout or "").lower().count(image.lower())
    except Exception:  # noqa: BLE001
        return None


def _windows_probe() -> dict:
    """Return {'tasks': [...], 'worker_count': int} or {'error': str}."""
    try:
        out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", _PS_PROBE],
            capture_output=True, text=True,
            timeout=CONFIG["powershell_timeout_sec"],
            creationflags=_creationflags_no_window(),
        )
    except Exception as exc:  # noqa: BLE001
        return {"error": f"powershell probe failed: {type(exc).__name__}: {exc}"}
    raw = (out.stdout or "").strip()
    if not raw:
        return {"error": f"powershell probe empty (stderr: {(out.stderr or '').strip()[:200]})"}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return {"error": f"probe JSON parse failed: {exc}"}
    tasks = data.get("tasks") or []
    if isinstance(tasks, dict):   # single task ⇒ ConvertTo-Json emits an object
        tasks = [tasks]
    return {"tasks": tasks, "worker_count": int(data.get("worker_count") or 0)}


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 1 — scheduled-task health
# ─────────────────────────────────────────────────────────────────────────────
_CADENCE_RE = re.compile(r"_(\d+)\s*min", re.IGNORECASE)


def _task_cadence_min(name: str) -> int | None:
    m = _CADENCE_RE.search(name)
    if m:
        return int(m.group(1))
    if name in CONFIG["schtask_explicit_cadence_min"]:
        return CONFIG["schtask_explicit_cadence_min"][name]
    if name.lower().endswith("hourly"):
        return 60
    return None


def check_scheduled_tasks(probe: dict) -> list[dict]:
    if probe.get("error"):
        return [finding("schtask_enum", WARN,
                        f"could not enumerate QM_* scheduled tasks: {probe['error']}",
                        hint="Run Get-ScheduledTask QM_* | Get-ScheduledTaskInfo manually",
                        evidence="powershell Get-ScheduledTaskInfo")]
    tasks = probe.get("tasks") or []
    if not tasks:
        return [finding("schtask_enum", WARN, "0 QM_* scheduled tasks returned by probe",
                        hint="Task Scheduler may be unreachable; verify QM_* tasks exist",
                        evidence="powershell Get-ScheduledTask QM_*")]

    now = _now()
    benign = CONFIG["schtask_benign_results"]
    hardfail = CONFIG["schtask_hardfail_results"]
    horizon = dt.timedelta(hours=CONFIG["schtask_recurring_horizon_h"])
    parked_h = dt.timedelta(days=CONFIG["schtask_parked_horizon_days"])
    recent = dt.timedelta(hours=CONFIG["schtask_oneoff_recent_h"])

    ignore_res = [re.compile(p, re.IGNORECASE) for p in CONFIG["schtask_ignore_patterns"]]
    findings: list[dict] = []
    for t in tasks:
        name = str(t.get("Name") or "?")
        if any(r.search(name) for r in ignore_res):
            continue  # transient smoke/dev harness task — not persistent farm infra
        if name in CONFIG["schtask_live_logon_owned_elsewhere"]:
            continue  # exact live state + resident heartbeat are checked below
        state = str(t.get("State") or "")
        if state == "Disabled":
            continue  # intentionally off — never overdue, never result-alarmed
        result = int(t.get("LastResult") or 0)
        next_run = _parse_iso(t.get("NextRun"))
        last_run = _parse_iso(t.get("LastRun"))
        cadence = _task_cadence_min(name)

        recurring = (cadence is not None) or (next_run is not None and now <= next_run <= now + horizon)
        parked = next_run is not None and next_run > now + parked_h
        ran_recently = last_run is not None and (now - last_run) <= recent
        ev = f"Get-ScheduledTaskInfo {name}"

        # ── result-code adjudication ─────────────────────────────────────────
        if result in benign:
            pass
        elif result in hardfail:
            label = "267014 killed@time-limit" if result == 267014 else f"0x{result:08X} launch-refused"
            if recurring:
                findings.append(finding(
                    f"schtask:{name}", FAIL,
                    f"{name} LastTaskResult {label} (recurring, next {t.get('NextRun')})",
                    value=result, threshold=0,
                    hint="Task is dying at its ExecutionTimeLimit / refusing launch; raise the "
                         "limit or fix the workload. This is the 267014 class that went unwatched.",
                    evidence=ev))
            elif ran_recently and not parked:
                findings.append(finding(
                    f"schtask:{name}", WARN,
                    f"{name} LastTaskResult {label} (one-off, last ran {t.get('LastRun')})",
                    value=result, threshold=0,
                    hint="One-off task hit its time limit recently; inspect if still relevant.",
                    evidence=ev))
            # else: stale/parked historical hard-fail ⇒ not actionable, skip.
        else:  # generic non-zero
            if parked:
                pass  # manual/parked task (e.g. NextRun years out) — ignore generic results
            elif recurring:
                findings.append(finding(
                    f"schtask:{name}", WARN,
                    f"{name} LastTaskResult {result} (non-zero, recurring)",
                    value=result, threshold=0,
                    hint="Recurring task last exited non-zero; check its wrapper log.",
                    evidence=ev))
            elif ran_recently:
                findings.append(finding(
                    f"schtask:{name}", WARN,
                    f"{name} LastTaskResult {result} (non-zero, last ran {t.get('LastRun')})",
                    value=result, threshold=0,
                    hint="Recently-run task exited non-zero; inspect if still relevant.",
                    evidence=ev))

        # ── overdue adjudication (recurring, cadence-known only) ─────────────
        if cadence is not None and not parked:
            grace_min = CONFIG["schtask_overdue_grace_mult"] * cadence + CONFIG["schtask_overdue_pad_min"]
            overdue_by = None
            if next_run is None:
                overdue_by = float("inf")
            elif next_run < now:
                overdue_by = (now - next_run).total_seconds() / 60.0
            if overdue_by is not None and overdue_by > grace_min:
                by_txt = "no NextRun set" if overdue_by == float("inf") else f"{overdue_by:.0f}m past due"
                findings.append(finding(
                    f"schtask_overdue:{name}", WARN,
                    f"{name} overdue ({by_txt}; cadence ~{cadence}min, next {t.get('NextRun')})",
                    value=None if overdue_by == float("inf") else round(overdue_by, 0),
                    threshold=round(grace_min, 0),
                    hint="Repetition trigger appears stalled/lost; re-check the task's trigger.",
                    evidence=ev))
    return findings


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 2 — quota governor (skip-streak + log silence)
# ─────────────────────────────────────────────────────────────────────────────
def check_quota_governor() -> list[dict]:
    findings: list[dict] = []
    ev_state = str(QUOTA_GOV_STATE)
    ev_log = str(QUOTA_GOV_LOG)

    # (a) per-agent skip streak (metrics unavailable)
    if not QUOTA_GOV_STATE.exists():
        findings.append(finding("quota_governor_state_missing", WARN,
                                "quota_governor_state.json missing — cannot read skip streaks",
                                hint="Confirm QM_StrategyFarm_QuotaGovernor is installed and running",
                                evidence=ev_state))
    else:
        try:
            state = json.loads(QUOTA_GOV_STATE.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            findings.append(finding("quota_governor_state_missing", WARN,
                                    f"quota_governor_state.json unreadable: {exc}",
                                    evidence=ev_state))
            state = {}
        for agent, node in (state.get("agents") or {}).items():
            if not isinstance(node, dict):
                continue
            streak = int(node.get("skip_streak") or 0)
            since = node.get("first_unavailable_at") or "?"
            if streak >= CONFIG["quota_skip_fail"]:
                findings.append(finding(
                    f"quota_governor_skip:{agent}", FAIL,
                    f"{agent}: metrics unavailable {streak} consecutive cycles (since {since}) — "
                    f"spend UNSTEERED (660-cycle class)",
                    value=streak, threshold=CONFIG["quota_skip_fail"],
                    hint="quota_pull.py snapshot shape changed; fix _codex_weekly_window / snapshot keys.",
                    evidence=ev_state))
            elif streak >= CONFIG["quota_skip_warn"]:
                findings.append(finding(
                    f"quota_governor_skip:{agent}", WARN,
                    f"{agent}: metrics unavailable {streak} consecutive cycles (since {since})",
                    value=streak, threshold=CONFIG["quota_skip_warn"],
                    hint="Governor is not steering this agent; check quota_snapshot.json shape.",
                    evidence=ev_state))

    # (b) governor log silence
    age = _file_age_min(QUOTA_GOV_LOG)
    if age is None:
        findings.append(finding("quota_governor_silent", WARN,
                                "quota_governor.log missing — cannot confirm the governor ran",
                                hint="Verify QM_StrategyFarm_QuotaGovernor task is enabled",
                                evidence=ev_log))
    elif age > CONFIG["quota_gov_silent_fail_min"]:
        findings.append(finding("quota_governor_silent", FAIL,
                                f"quota_governor.log silent {age:.0f}min (>{CONFIG['quota_gov_silent_fail_min']}m) "
                                f"— governor task likely dead",
                                value=round(age, 0), threshold=CONFIG["quota_gov_silent_fail_min"],
                                hint="Start-ScheduledTask QM_StrategyFarm_QuotaGovernor; check its wrapper",
                                evidence=ev_log))
    elif age > CONFIG["quota_gov_silent_warn_min"]:
        findings.append(finding("quota_governor_silent", WARN,
                                f"quota_governor.log silent {age:.0f}min (>{CONFIG['quota_gov_silent_warn_min']}m)",
                                value=round(age, 0), threshold=CONFIG["quota_gov_silent_warn_min"],
                                hint="Governor may have missed cycles; watch for escalation.",
                                evidence=ev_log))
    return findings


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 3 — REVIEW lane (agent_tasks)
# ─────────────────────────────────────────────────────────────────────────────
def check_review_lane(con: sqlite3.Connection | None) -> list[dict]:
    ev = f"{DB_PATH} (agent_tasks WHERE state='REVIEW')"
    if con is None:
        return [finding("review_lane", WARN, "farm_state.sqlite unavailable — REVIEW lane not checked",
                        evidence=ev)]
    try:
        rows = list(con.execute(
            "SELECT id, updated_at FROM agent_tasks WHERE state='REVIEW'"))
    except sqlite3.Error as exc:
        return [finding("review_lane", WARN, f"agent_tasks query failed: {exc}", evidence=ev)]

    count = len(rows)
    now = _now()
    ages_h = sorted(
        (now - d).total_seconds() / 3600.0
        for r in rows
        for d in [_parse_iso(r["updated_at"])]
        if d is not None
    )
    findings: list[dict] = []

    # (a) median age
    if ages_h:
        n = len(ages_h)
        median = ages_h[n // 2] if n % 2 else (ages_h[n // 2 - 1] + ages_h[n // 2]) / 2.0
        worst = ages_h[-1]
        if median > CONFIG["review_median_age_fail_h"]:
            findings.append(finding("review_lane_age", FAIL,
                                    f"REVIEW median age {median:.0f}h (>{CONFIG['review_median_age_fail_h']}h); "
                                    f"oldest {worst:.0f}h, {count} in REVIEW (9-day-stall class)",
                                    value=round(median, 0), threshold=CONFIG["review_median_age_fail_h"],
                                    hint="Drain the REVIEW lane: agent_router close-review / re-route stuck tasks.",
                                    evidence=ev))
        elif median > CONFIG["review_median_age_warn_h"]:
            findings.append(finding("review_lane_age", WARN,
                                    f"REVIEW median age {median:.0f}h (>{CONFIG['review_median_age_warn_h']}h); "
                                    f"oldest {worst:.0f}h, {count} in REVIEW",
                                    value=round(median, 0), threshold=CONFIG["review_median_age_warn_h"],
                                    hint="REVIEW lane aging; route reviews before the stall deepens.",
                                    evidence=ev))

    # (b) backlog count
    if count > CONFIG["review_count_fail"]:
        findings.append(finding("review_lane_count", FAIL,
                                f"{count} tasks in REVIEW (>{CONFIG['review_count_fail']})",
                                value=count, threshold=CONFIG["review_count_fail"],
                                hint="REVIEW backlog exploded; the router is not draining reviews.",
                                evidence=ev))
    elif count > CONFIG["review_count_warn"]:
        findings.append(finding("review_lane_count", WARN,
                                f"{count} tasks in REVIEW (>{CONFIG['review_count_warn']})",
                                value=count, threshold=CONFIG["review_count_warn"],
                                hint="REVIEW backlog building; keep an eye on router throughput.",
                                evidence=ev))
    return findings


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 4 — tester-cache purge futility
# ─────────────────────────────────────────────────────────────────────────────
_PURGE_RECLAIM_RE = re.compile(
    r"^(?P<ts>\S+)\s+idle caches cleared.*->\s*(?P<after>[\d.]+)GB\s*\(reclaimed\s*(?P<recl>-?[\d.]+)GB\)")


def check_purge_futility() -> list[dict]:
    ev = str(PURGE_LOG)
    if not PURGE_LOG.exists():
        return [finding("purge_futility", WARN, "tester_cache_purge.log missing",
                        hint="Verify QM_StrategyFarm_TesterCachePurge is installed",
                        evidence=ev)]
    text = _tail_text(PURGE_LOG, max_bytes=32768)
    acting = []  # (ts_dt, after_gb, reclaimed_gb)
    for line in text.splitlines():
        m = _PURGE_RECLAIM_RE.match(line.strip())
        if not m:
            continue
        ts = _parse_iso(m.group("ts"))
        try:
            acting.append((ts, float(m.group("after")), float(m.group("recl"))))
        except ValueError:
            continue
    need = CONFIG["purge_consecutive_runs"]
    if len(acting) < need:
        return [finding("purge_futility", OK,
                        f"{len(acting)} acting purge run(s) logged; no {need}-run futility streak",
                        value=len(acting), threshold=need, evidence=ev)]
    tail = acting[-need:]
    newest_ts = tail[-1][0]
    recent = newest_ts is not None and (_now() - newest_ts).total_seconds() / 60.0 <= CONFIG["purge_recent_window_min"]
    floor = CONFIG["purge_disk_floor_gb"]
    eps = CONFIG["purge_reclaimed_epsilon_gb"]
    all_futile = all(after < floor and reclaimed <= eps for _ts, after, reclaimed in tail)
    if recent and all_futile:
        worst_after = min(after for _ts, after, _r in tail)
        return [finding("purge_futility", FAIL,
                        f"{need} consecutive purge runs reclaimed ~0GB with D: still <{floor}GB "
                        f"(worst free {worst_after:.1f}GB) — caches empty but disk critically low",
                        value=round(worst_after, 1), threshold=floor,
                        hint="Purge cannot help: something non-regenerable is filling D:. Investigate D: usage.",
                        evidence=ev)]
    return [finding("purge_futility", OK,
                    f"last {need} acting purge runs not futile (recent={recent})",
                    value=len(acting), threshold=need, evidence=ev)]


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 5 — worker crash burst / daemon shortfall
# ─────────────────────────────────────────────────────────────────────────────
def check_worker_health(probe: dict) -> list[dict]:
    findings: list[dict] = []

    # (a) .err burst — fresh writes WITH crash signatures (avoids false positives
    #     on clean restarts, which also touch every .err at once).
    if not LOGS_DIR.is_dir():
        findings.append(finding("worker_crash_burst", WARN, f"logs dir missing: {LOGS_DIR}",
                                evidence=str(LOGS_DIR)))
    else:
        window = CONFIG["worker_err_burst_window_min"]
        sigs = CONFIG["worker_err_crash_signatures"]
        fresh_crashers = []
        for err in LOGS_DIR.glob(WORKER_ERR_GLOB):
            age = _file_age_min(err)
            if age is None or age > window:
                continue
            tail = _tail_text(err, max_bytes=4096)
            if any(s in tail for s in sigs):
                fresh_crashers.append(err.name)
        if len(fresh_crashers) >= CONFIG["worker_err_burst_count"]:
            findings.append(finding("worker_crash_burst", WARN,
                                    f"{len(fresh_crashers)} worker .err files with crash signatures modified "
                                    f"in {window}min: {', '.join(sorted(fresh_crashers))}",
                                    value=len(fresh_crashers), threshold=CONFIG["worker_err_burst_count"],
                                    hint="Worker respawn crash loop; read the .err tails and fix the worker fault.",
                                    evidence=str(LOGS_DIR / WORKER_ERR_GLOB)))

    # (b) daemon shortfall while factory should be up
    if FACTORY_OFF_FLAG.exists():
        findings.append(finding("worker_daemon_shortfall", OK,
                                "FACTORY_OFF.flag present — worker shortfall expected",
                                evidence=str(FACTORY_OFF_FLAG)))
    elif probe.get("error"):
        findings.append(finding("worker_daemon_shortfall", WARN,
                                f"could not scan terminal_worker.py processes: {probe['error']}",
                                evidence="powershell Win32_Process terminal_worker.py"))
    else:
        n = int(probe.get("worker_count") or 0)
        if n < CONFIG["worker_daemon_min"]:
            findings.append(finding("worker_daemon_shortfall", FAIL,
                                    f"only {n} terminal_worker.py daemons alive (<{CONFIG['worker_daemon_min']}) "
                                    f"and FACTORY_OFF.flag absent",
                                    value=n, threshold=CONFIG["worker_daemon_min"],
                                    hint="Run start_terminal_workers.py --dedupe; factory is under-provisioned.",
                                    evidence="powershell Win32_Process terminal_worker.py"))
    return findings


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 6 — pump blockade
# ─────────────────────────────────────────────────────────────────────────────
def check_pump_blockade() -> list[dict]:
    ev = str(LOGS_DIR / PUMP_LOG_GLOB)
    if FACTORY_OFF_FLAG.exists():
        return [finding("pump_blockade", OK, "FACTORY_OFF.flag present — pump intentionally suspended",
                        evidence=str(FACTORY_OFF_FLAG))]
    if not LOGS_DIR.is_dir():
        return [finding("pump_blockade", WARN, f"logs dir missing: {LOGS_DIR}", evidence=ev)]
    window = CONFIG["pump_block_window_min"]
    marker = CONFIG["pump_block_marker"]
    recent_logs = []
    for lg in LOGS_DIR.glob(PUMP_LOG_GLOB):
        age = _file_age_min(lg)
        if age is not None and age <= window:
            recent_logs.append((age, lg))
    if not recent_logs:
        return [finding("pump_blockade", WARN,
                        f"no pump_task_*.log in the last {window}min — pump may not be running",
                        hint="Check QM_StrategyFarm_Pump_5min; confirm it is enabled and firing.",
                        evidence=ev)]
    blocked = [lg for _age, lg in recent_logs if marker in _tail_text(lg, max_bytes=8192)]
    _newest_age, newest_lg = min(recent_logs, key=lambda x: x[0])  # smallest age = newest
    newest_blocked = marker in _tail_text(newest_lg, max_bytes=8192)
    if (len(recent_logs) >= CONFIG["pump_block_min_runs"]
            and len(blocked) == len(recent_logs) and newest_blocked):
        return [finding("pump_blockade", FAIL,
                        f"all {len(recent_logs)} pump runs in the last {window}min show {marker} "
                        f"(blocked >2h); newest {newest_lg.name}",
                        value=len(blocked), threshold=CONFIG["pump_block_min_runs"],
                        hint="Build lane wedged: usually the repo dirty-guard (uncommitted source) or the "
                             "codex_kill_safety_audit. Commit/clean the worktree or fix the audit.",
                        evidence=str(newest_lg))]
    return [finding("pump_blockade", OK,
                    f"{len(blocked)}/{len(recent_logs)} recent pump runs blocked; newest ok={not newest_blocked}",
                    value=len(blocked), threshold=CONFIG["pump_block_min_runs"], evidence=ev)]


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 8 — GoogleDriveFS liveness (+ sanctioned auto-heal)
# ─────────────────────────────────────────────────────────────────────────────
def check_gdrive(probe: dict) -> list[dict]:
    """Process-based G:-mount proxy. SYSTEM cannot see the per-user G: drive,
    so we watch the GoogleDriveFS process count instead (via tasklist — see
    _tasklist_count for why not Get-Process/CIM). On zero, attempt the ONE
    sanctioned heal (Start-ScheduledTask QM_GoogleDrive_AtLogon) when an
    interactive session exists, then report WARN(healed)/FAIL(down)."""
    ev = "tasklist /FI \"IMAGENAME eq GoogleDriveFS.exe\""
    count = _tasklist_count("GoogleDriveFS.exe")
    if count is None:
        return [finding("gdrive_fs", WARN,
                        "could not probe GoogleDriveFS processes (tasklist failed)",
                        evidence=ev)]
    if count > 0:
        return [finding("gdrive_fs", OK, f"GoogleDriveFS alive ({count} proc)",
                        value=count, threshold=1, evidence=ev)]

    sessions = _tasklist_count("explorer.exe") or 0
    detail = ("GoogleDriveFS NOT running — G: absent for every consumer "
              "(vault sync, nightly backup, morning-brief vault copy)")
    hint = f"Start-ScheduledTask {CONFIG['gdrive_heal_task']} (needs an active user session)"
    if not (CONFIG["gdrive_heal_enabled"] and sessions > 0):
        return [finding("gdrive_fs", FAIL,
                        detail + (f"; no active user session — heal impossible" if sessions == 0 else ""),
                        value=0, threshold=1, hint=hint, evidence=ev)]
    try:
        subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
             f"Start-ScheduledTask -TaskName '{CONFIG['gdrive_heal_task']}'"],
            capture_output=True, text=True, timeout=CONFIG["powershell_timeout_sec"],
            creationflags=_creationflags_no_window(),
        )
        return [finding("gdrive_fs", WARN,
                        detail + f" — auto-heal triggered ({CONFIG['gdrive_heal_task']}); "
                                 f"verify recovery next cycle",
                        value=0, threshold=1, hint=hint, evidence=ev)]
    except Exception as exc:  # noqa: BLE001
        return [finding("gdrive_fs", FAIL, detail + f"; auto-heal failed: {exc}",
                        value=0, threshold=1, hint=hint, evidence=ev)]


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 7 — heartbeats
# ─────────────────────────────────────────────────────────────────────────────
def _heartbeat(name: str, path: Path, warn_min: float, fail_min: float,
               missing_status: str = WARN, missing_detail: str | None = None) -> dict:
    ev = str(path)
    age = _file_age_min(path)
    if age is None:
        return finding(name, missing_status,
                       missing_detail or f"{path.name} missing",
                       hint="Confirm the producing task is installed and running.", evidence=ev)
    if age > fail_min:
        return finding(name, FAIL,
                       f"{path.name} stale {age:.0f}min (>{fail_min:.0f}m)",
                       value=round(age, 0), threshold=fail_min,
                       hint="Producer task appears dead — restart it.", evidence=ev)
    if age > warn_min:
        return finding(name, WARN,
                       f"{path.name} stale {age:.0f}min (>{warn_min:.0f}m)",
                       value=round(age, 0), threshold=warn_min,
                       hint="Producer task may have missed cycles.", evidence=ev)
    return finding(name, OK, f"{path.name} fresh ({age:.0f}min)", value=round(age, 0),
                   threshold=warn_min, evidence=ev)


def check_heartbeats() -> list[dict]:
    findings: list[dict] = []
    # backup: nightly. Absence pre-first-run is normal ⇒ OK-with-note (only armed once the file exists).
    if not BACKUP_LOG.exists():
        findings.append(finding("heartbeat:backup_nightly", OK,
                                "backup_nightly.log absent — nightly backup not yet run (check not armed)",
                                evidence=str(BACKUP_LOG)))
    else:
        findings.append(_heartbeat("heartbeat:backup_nightly", BACKUP_LOG,
                                   CONFIG["hb_backup_warn_h"] * 60, CONFIG["hb_backup_fail_h"] * 60))
    findings.append(_heartbeat("heartbeat:health_json", HEALTH_JSON,
                               CONFIG["hb_health_warn_min"], CONFIG["hb_health_fail_min"]))
    findings.append(_heartbeat("heartbeat:cockpit_html", COCKPIT_HTML,
                               CONFIG["hb_cockpit_warn_min"], CONFIG["hb_cockpit_fail_min"]))
    return findings


# ─────────────────────────────────────────────────────────────────────────────
#  CHECK 8 — live MT5 uptime + recoverability
# ─────────────────────────────────────────────────────────────────────────────
def check_live_uptime() -> list[dict]:
    ev = str(LIVE_UPTIME_STATE)
    if not LIVE_UPTIME_STATE.exists():
        return [finding(
            "live_mt5_uptime", FAIL,
            "live_uptime_watchdog.json missing — neither live-process state nor recovery readiness is observable",
            hint="Run/install QM_T_Live_Watchdog and verify its SYSTEM principal.",
            evidence=ev,
        )]
    try:
        state = json.loads(LIVE_UPTIME_STATE.read_text(encoding="utf-8-sig"))
    except Exception as exc:  # noqa: BLE001
        return [finding(
            "live_mt5_uptime", FAIL,
            f"live watchdog state unreadable: {type(exc).__name__}: {exc}",
            hint="Inspect T_Live_Watchdog.ps1 and the state-file ACL/disk.", evidence=ev,
        )]

    checked = _parse_iso(state.get("last_checked_utc") or state.get("ts"))
    age = ((_now() - checked).total_seconds() / 60.0) if checked else _file_age_min(LIVE_UPTIME_STATE)
    if age is None or age > CONFIG["live_watchdog_fail_stale_min"]:
        age_text = "unknown" if age is None else f"{age:.0f}min"
        return [finding(
            "live_mt5_uptime", FAIL,
            f"live watchdog state stale ({age_text}); minute-level recovery may be dead",
            value=None if age is None else round(age, 0),
            threshold=CONFIG["live_watchdog_fail_stale_min"],
            hint="Check QM_T_Live_Watchdog task state and LastTaskResult immediately.", evidence=ev,
        )]
    if age > CONFIG["live_watchdog_warn_stale_min"]:
        return [finding(
            "live_mt5_uptime", WARN,
            f"live watchdog state is {age:.0f}min old",
            value=round(age, 0), threshold=CONFIG["live_watchdog_warn_stale_min"],
            hint="Check whether the one-minute watchdog trigger is slipping.", evidence=ev,
        )]

    dxz_running = state.get("dxz_running") is True
    ftmo_running = state.get("ftmo_running") is True
    if state.get("process_probe_ok") is not True:
        return [finding(
            "live_mt5_uptime", FAIL,
            "live process inventory failed; watchdog correctly refused destructive recovery, but uptime is unknown",
            hint="Repair CIM/WMI process enumeration; verify both exact terminal paths manually.", evidence=ev,
        )]
    if not dxz_running or not ftmo_running:
        missing = [name for name, running in (("DXZ", dxz_running), ("FTMO", ftmo_running)) if not running]
        return [finding(
            "live_mt5_uptime", FAIL,
            f"live MT5 down: {', '.join(missing)}; watchdog status={state.get('status') or state.get('last_status')}",
            value=len(missing), threshold=0,
            hint="Inspect live_uptime_watchdog.jsonl; recovery should relaunch or reboot after confirmation.",
            evidence=ev,
        )]

    if state.get("session_placement_ok") is not True:
        return [finding(
            "live_mt5_session", FAIL,
            f"live MT5 process is outside the qm-admin session; DXZ sessions={state.get('dxz_session_ids')}, "
            f"FTMO sessions={state.get('ftmo_session_ids')}, target={state.get('target_session_id')}",
            hint="Do not accept a session-0 GUI process as recovered; inspect the InteractiveToken tasks.",
            evidence=ev,
        )]

    if state.get("maintenance") is True:
        return [finding(
            "live_mt5_uptime", WARN,
            "both live MT5 processes run, but automatic recovery is suppressed by the maintenance flag",
            hint="Remove LIVE_UPTIME_MAINTENANCE.flag after the maintenance window.", evidence=ev,
        )]

    if state.get("session_supervisor_ready") is not True:
        return [finding(
            "live_mt5_session_supervisor", FAIL,
            f"resident live recovery is not ready: {state.get('session_supervisor_reason')}; "
            f"age={state.get('session_supervisor_age_seconds')}s",
            hint="Repair/start QM_Live_MT5_SessionSupervisor in the qm-admin desktop session.", evidence=ev,
        )]

    dxz_profile = state.get("dxz_profile")
    ftmo_profile = state.get("ftmo_profile")
    expected_dxz = state.get("expected_dxz_profile")
    expected_ftmo = state.get("expected_ftmo_profile")
    if dxz_profile != expected_dxz or ftmo_profile != expected_ftmo:
        return [finding(
            "live_mt5_profile", FAIL,
            f"live profile drift: DXZ={dxz_profile!r} expected={expected_dxz!r}; "
            f"FTMO={ftmo_profile!r} expected={expected_ftmo!r}",
            hint="Perform a controlled OWNER-approved profile switch; do not restart a live terminal blindly.",
            evidence=ev,
        )]

    if state.get("dxz_experts_enabled") != 1 or state.get("ftmo_experts_enabled") != 1:
        return [finding(
            "live_mt5_autotrading_config", FAIL,
            f"[Experts] Enabled is not 1 for both terminals: DXZ={state.get('dxz_experts_enabled')}, "
            f"FTMO={state.get('ftmo_experts_enabled')}",
            hint="Inspect the approved live state and common.ini; do not toggle AutoTrading without OWNER authority.",
            evidence=ev,
        )]

    if any(str(error).startswith("tscon_disable_failed:") for error in (state.get("errors") or [])):
        return [finding(
            "live_mt5_session_guard", FAIL,
            "the watchdog could not enforce the unsafe tscon task as disabled",
            hint="Disable QM_TSCon_Console_OnDisconnect and repair its task ACL/state.", evidence=ev,
        )]

    if state.get("autologon_ready") is not True:
        return [finding(
            "live_mt5_recovery_ready", FAIL,
            f"both terminals run, but reboot recovery is blocked (LSA probe={state.get('autologon_secret_probe')})",
            hint="Repair qm-admin Sysinternals Autologon before relying on unattended recovery.", evidence=ev,
        )]

    return [finding(
        "live_mt5_uptime", OK,
        f"DXZ + FTMO running; session={state.get('target_session_id')} "
        f"({state.get('target_session_state')}); recovery ready; state age={age:.1f}min",
        value=0, threshold=CONFIG["live_watchdog_warn_stale_min"], evidence=ev,
    )]


# ─────────────────────────────────────────────────────────────────────────────
#  Incident dedupe — carry first_seen / streak across runs
# ─────────────────────────────────────────────────────────────────────────────
def _load_state() -> dict:
    if not MONITOR_STATE.exists():
        return {}
    try:
        return json.loads(MONITOR_STATE.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        return {}


def apply_incidents(prev_state: dict, findings: list[dict], now_iso: str) -> tuple[dict, list[str]]:
    """Fold current findings into per-check incident state.

    Returns (new_checks_state, transition_log_lines). A finding is a live incident
    while its status != OK. first_seen is stable for the life of an incident;
    streak counts consecutive non-OK runs; transitions (open / escalate / recover)
    are logged ONCE."""
    prev = prev_state.get("checks", {}) if isinstance(prev_state.get("checks"), dict) else {}
    current = {f["name"]: f for f in findings}
    new_checks: dict = {}
    transitions: list[str] = []

    # 1) walk current findings
    for name, f in current.items():
        status = f["status"]
        p = prev.get(name, {})
        p_status = p.get("status", OK)
        was_incident = p_status in (WARN, FAIL)
        is_incident = status in (WARN, FAIL)

        if is_incident and not was_incident:
            first_seen = now_iso
            streak = 1
            transitions.append(f"ALARM-OPEN [{status}] {name} :: {f['detail']} "
                               f"(first_seen={first_seen}, evidence={f.get('evidence','')})")
        elif is_incident and was_incident:
            first_seen = p.get("first_seen", now_iso)
            streak = int(p.get("streak", 0)) + 1
            if status != p_status:
                transitions.append(f"ALARM-{('ESCALATE' if _SEVERITY[status] > _SEVERITY[p_status] else 'EASE')} "
                                   f"[{p_status}->{status}] {name} :: {f['detail']} (since {first_seen})")
        elif (not is_incident) and was_incident:
            transitions.append(f"RECOVERED [{p_status}->OK] {name} (incident since {p.get('first_seen','?')})")
            first_seen = None
            streak = 0
        else:  # steady OK
            first_seen = None
            streak = 0

        entry = {"status": status, "streak": streak, "last_status": status, "last_seen": now_iso}
        if first_seen:
            entry["first_seen"] = first_seen
        new_checks[name] = entry
        # decorate the finding for the sidecar
        if first_seen:
            f["first_seen"] = first_seen
        f["streak"] = streak

    # 2) prior incidents whose finding vanished this run ⇒ recovered
    for name, p in prev.items():
        if name in current:
            continue
        if p.get("status") in (WARN, FAIL):
            transitions.append(f"RECOVERED [{p['status']}->OK] {name} "
                               f"(incident since {p.get('first_seen','?')}; finding cleared)")
        # dropped from state (steady OK, no need to persist)

    return new_checks, transitions


# ─────────────────────────────────────────────────────────────────────────────
#  Sidecar (health-shaped) + state + log writers
# ─────────────────────────────────────────────────────────────────────────────
def _summarize(findings: list[dict]) -> tuple[str, dict]:
    n_fail = sum(1 for f in findings if f["status"] == FAIL)
    n_warn = sum(1 for f in findings if f["status"] == WARN)
    n_ok = sum(1 for f in findings if f["status"] == OK)
    overall = FAIL if n_fail else WARN if n_warn else OK
    return overall, {"fail": n_fail, "warn": n_warn, "ok": n_ok}


def _write_sidecar(findings: list[dict], now_iso: str, runtime_sec: float) -> None:
    # Only non-OK checks go into the durable health sidecar.
    non_ok = [f for f in findings if f["status"] in (WARN, FAIL)]
    overall, _summary_all = _summarize(findings)
    n_fail = sum(1 for f in non_ok if f["status"] == FAIL)
    n_warn = sum(1 for f in non_ok if f["status"] == WARN)
    payload = {
        "source": "silent_failure_monitor",
        "checked_at": now_iso,
        "overall": overall,
        "summary": {"fail": n_fail, "warn": n_warn, "ok": sum(1 for f in findings if f["status"] == OK)},
        "runtime_sec": round(runtime_sec, 2),
        "checks": non_ok,
    }
    ALARM_SIDECAR.parent.mkdir(parents=True, exist_ok=True)
    ALARM_SIDECAR.write_text(json.dumps(payload, indent=2, sort_keys=False), encoding="utf-8")


def _write_state(new_checks: dict, now_iso: str, runtime_sec: float, overall: str, summary: dict) -> None:
    payload = {
        "schema": 1,
        "last_run_utc": now_iso,
        "runtime_sec": round(runtime_sec, 2),
        "overall": overall,
        "summary": summary,
        "checks": new_checks,
    }
    MONITOR_STATE.parent.mkdir(parents=True, exist_ok=True)
    MONITOR_STATE.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _log(lines: list[str]) -> None:
    MONITOR_LOG.parent.mkdir(parents=True, exist_ok=True)
    with MONITOR_LOG.open("a", encoding="utf-8", newline="\n") as fh:
        for ln in lines:
            fh.write(ln + "\n")


# ─────────────────────────────────────────────────────────────────────────────
#  Consumer-side merge — folds this monitor's findings into health state
# ─────────────────────────────────────────────────────────────────────────────
def merge_into_health(health: dict) -> dict:
    """Fold silent-failure alarms into a health.json-style dict IN PLACE and return it.

    Existing health readers may call this after building their checks. It also
    injects the monitor's OWN staleness as WARN/FAIL so a dead monitor remains
    visible in the resulting health state. It does not send mail."""
    if not isinstance(health, dict):
        health = {}
    checks = health.get("checks")
    if not isinstance(checks, list):
        checks = []
        health["checks"] = checks

    injected: list[dict] = []
    age = _file_age_min(ALARM_SIDECAR)
    if age is None:
        injected.append({
            "name": "silent_failure_monitor_stale", "status": FAIL,
            "detail": "silent_failure_alarms.json missing — the silent-failure meta-monitor is not producing output",
            "action_hint": "Check QM_StrategyFarm_SilentFailureMonitor (task #11) is installed and running",
            "value": None, "threshold": CONFIG["monitor_self_stale_fail_min"],
            "evidence": str(ALARM_SIDECAR),
        })
    elif age > CONFIG["monitor_self_stale_fail_min"]:
        injected.append({
            "name": "silent_failure_monitor_stale", "status": FAIL,
            "detail": f"silent_failure_alarms.json stale {age:.0f}min (>{CONFIG['monitor_self_stale_fail_min']}m) "
                      f"— meta-monitor task appears dead",
            "action_hint": "Restart QM_StrategyFarm_SilentFailureMonitor (task #11)",
            "value": round(age, 0), "threshold": CONFIG["monitor_self_stale_fail_min"],
            "evidence": str(ALARM_SIDECAR),
        })
    else:
        if age > CONFIG["monitor_self_stale_warn_min"]:
            injected.append({
                "name": "silent_failure_monitor_stale", "status": WARN,
                "detail": f"silent_failure_alarms.json stale {age:.0f}min "
                          f"(>{CONFIG['monitor_self_stale_warn_min']}m)",
                "action_hint": "Meta-monitor may have missed a cycle.",
                "value": round(age, 0), "threshold": CONFIG["monitor_self_stale_warn_min"],
                "evidence": str(ALARM_SIDECAR),
            })
        try:
            sidecar = json.loads(ALARM_SIDECAR.read_text(encoding="utf-8"))
            for c in sidecar.get("checks", []):
                if isinstance(c, dict) and c.get("status") in (WARN, FAIL):
                    injected.append(c)
        except Exception as exc:  # noqa: BLE001
            injected.append({
                "name": "silent_failure_monitor_stale", "status": WARN,
                "detail": f"silent_failure_alarms.json unreadable: {exc}",
                "action_hint": "Inspect the meta-monitor output file.",
                "value": None, "threshold": None, "evidence": str(ALARM_SIDECAR),
            })

    checks.extend(injected)

    # Recompute summary + overall so every health consumer sees the new FAILs.
    n_fail = sum(1 for c in checks if c.get("status") == FAIL)
    n_warn = sum(1 for c in checks if c.get("status") == WARN)
    n_ok = sum(1 for c in checks if c.get("status") == OK)
    health["summary"] = {"fail": n_fail, "warn": n_warn, "ok": n_ok}
    health["overall"] = FAIL if n_fail else WARN if n_warn else health.get("overall", OK)
    return health


# ─────────────────────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────────────────────
def _run_check(label: str, fn, *args) -> list[dict]:
    """Run one check; a crash becomes its own WARN rather than blinding the rest."""
    try:
        return fn(*args)
    except Exception:  # noqa: BLE001
        tb = traceback.format_exc().strip().splitlines()[-1]
        return [finding(f"check_error:{label}", WARN,
                        f"check '{label}' raised: {tb}",
                        hint="Meta-monitor check crashed; inspect silent_failure_monitor.py",
                        evidence="silent_failure_monitor.py")]


def _make_streams_safe() -> None:
    """pythonw.exe gives a scheduled process sys.stdout/stderr == None, so a bare
    print() would raise and silently kill the run — the exact failure this monitor
    exists to catch. Redirect None streams to devnull, and force utf-8 on real
    consoles so the box-drawing/em-dash detail text never trips a cp1252 encode."""
    try:
        if sys.stdout is None:
            sys.stdout = open(os.devnull, "w", encoding="utf-8")
        elif hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if sys.stderr is None:
            sys.stderr = open(os.devnull, "w", encoding="utf-8")
        elif hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # noqa: BLE001 — never let stream setup abort the run
        pass


def main() -> int:
    _make_streams_safe()
    ap = argparse.ArgumentParser(description="QM silent-failure meta-monitor (task #11)")
    ap.add_argument("--print", dest="print_only", action="store_true",
                    help="Print a human table and DO NOT write state/log/sidecar (dry run).")
    args = ap.parse_args()

    t0 = time.monotonic()
    now_iso = _utc_iso()

    probe = _windows_probe()

    con = None
    try:
        con = _connect_ro()
    except sqlite3.Error:
        con = None

    findings: list[dict] = []
    findings += _run_check("scheduled_tasks", check_scheduled_tasks, probe)
    findings += _run_check("quota_governor", check_quota_governor)
    findings += _run_check("review_lane", check_review_lane, con)
    findings += _run_check("purge_futility", check_purge_futility)
    findings += _run_check("worker_health", check_worker_health, probe)
    findings += _run_check("pump_blockade", check_pump_blockade)
    findings += _run_check("heartbeats", check_heartbeats)
    findings += _run_check("live_mt5_uptime", check_live_uptime)
    findings += _run_check("gdrive_fs", check_gdrive, probe)

    if con is not None:
        try:
            con.close()
        except sqlite3.Error:
            pass

    overall, summary = _summarize(findings)
    prev_state = _load_state()
    new_checks, transitions = apply_incidents(prev_state, findings, now_iso)
    runtime = time.monotonic() - t0

    # heartbeat + transition log
    log_lines = [f"{now_iso} RUN overall={overall} fail={summary['fail']} warn={summary['warn']} "
                 f"ok={summary['ok']} runtime={runtime:.1f}s probe={'ERR' if probe.get('error') else 'ok'}"]
    log_lines += [f"{now_iso}   {t}" for t in transitions]

    if args.print_only:
        print(f"[DRY RUN - no state/sidecar written]  overall={overall}  "
              f"fail={summary['fail']} warn={summary['warn']} ok={summary['ok']} runtime={runtime:.1f}s")
        for f in sorted(findings, key=lambda x: (-_SEVERITY[x["status"]], x["name"])):
            if f["status"] == OK:
                continue
            print(f"  [{f['status']:4}] {f['name']}: {f['detail']}")
            if f.get("evidence"):
                print(f"          evidence: {f['evidence']}")
        print(f"  ({summary['ok']} checks OK, not shown)")
        for t in transitions:
            print(f"  TRANSITION: {t}")
        return 0

    _write_sidecar(findings, now_iso, runtime)
    _write_state(new_checks, now_iso, runtime, overall, summary)
    _log(log_lines)

    print(f"silent_failure_monitor: overall={overall} fail={summary['fail']} warn={summary['warn']} "
          f"ok={summary['ok']} runtime={runtime:.1f}s")
    print(f"  sidecar: {ALARM_SIDECAR}")
    print(f"  state:   {MONITOR_STATE}")
    print(f"  log:     {MONITOR_LOG}")
    for t in transitions:
        print(f"  {t}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
