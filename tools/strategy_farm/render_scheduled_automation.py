#!/usr/bin/env python3
"""Generate the Company Reference "Scheduled Automation" vault page from the live
Windows Task Scheduler.

The page is a DETERMINISTIC projection of the current ``QM_*`` scheduled tasks: the same
task set (name/state/cadence/runner/purpose) always renders byte-identical markdown except
for the single ``generated_at_utc`` frontmatter field (a live-system snapshot is not a pure
file transform, so a wall-clock stamp is documented and isolated to one field).

Purpose column: the task's own Scheduler Description when present, else a curated fallback
for the handful of QM tasks registered without a description, else ``—`` (never invented).

The page is CLEARLY GENERATED (frontmatter ``generated: true`` + a DO-NOT-EDIT banner) so a
human never hand-edits it and the generator never clobbers a hand-written page. The canonical
hand-written narrative lives at ``06 Infrastructure/Background Automation and Scheduled
Tasks.md``; this page is the machine-refreshed inventory it points to.

Usage (orchestrator; read-only against the scheduler, writes one vault file):
    python -X utf8 tools/strategy_farm/render_scheduled_automation.py
    python -X utf8 tools/strategy_farm/render_scheduled_automation.py --out some/where.md
    python -X utf8 tools/strategy_farm/render_scheduled_automation.py --json-in tasks.json --out page.md

Slice: i3_old_rules_sweep_docs (follow-up directive §10 OPERATIONS: current scheduled
automation).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import subprocess
import sys
from pathlib import Path

SCHEMA = "qm.scheduled-automation-page/v1"
GENERATOR = "tools/strategy_farm/render_scheduled_automation.py"
DEFAULT_OUT = Path(
    "G:/My Drive/QuantMechanica - Company Reference/06 Infrastructure/Scheduled Automation.md"
)

# Curated fallback purposes for QM tasks registered WITHOUT a Scheduler Description.
# Kept minimal and factual; only used when the live Description is empty. Extend here when a
# new description-less task appears rather than inventing a value in the table.
PURPOSE_FALLBACK: dict[str, str] = {
    "QM_BalkeMinute_WF": "On-demand Balke minute walk-forward research launcher.",
    "QM_BookEvolution_FridayEvidenceCut": "Weekly recomposition: Friday evidence cut (freeze hash-pinned CLOSED cut).",
    "QM_BookEvolution_RuntimeVerify": "Weekly recomposition: Monday read-only verify of live vs accepted package.",
    "QM_BookEvolution_SaturdayAnalysis": "Weekly recomposition: Saturday deterministic evaluation + cross-vendor critique.",
    "QM_BookEvolution_SundayRecommendation": "Weekly recomposition: Sunday OWNER decision package + decision cards.",
    "QM_ClaudeParallel_RestoreOnReset": "Relaunch the parallel Claude CLI lane after a session reset.",
    "QM_CodexParallel_RestoreOnReset": "Relaunch the parallel Codex CLI lane after a session reset.",
    "QM_CommitSampler_1min": "Sample git commit activity for the pacing/quota surfaces.",
    "QM_FTMO_TrialPulse": "FTMO demo terminal pulse / trial health probe.",
    "QM_LiveSupervisor_Watchdog_SYSTEM": "SYSTEM watchdog for the live-session supervisor.",
    "QM_NewsCalendar_Refresh": "Refresh the backtest news calendar seed (scheduled daily).",
    "QM_NightlyBackup_Vault": "Nightly backup of the Company Reference vault (scripts/backup_nightly.ps1).",
    "QM_Repo_Push": "Scheduled git push of the canonical repo (orchestrator commits).",
    "QM_StrategyFarm_AgentChain_Critique_15min": "Creator->Critic->Formatter cross-vendor critique chain (agent_chain.py).",
    "QM_StrategyFarm_BookEvolutionReadModels_15min": "Refresh book-evolution read-models under D:/QM/reports/state/.",
    "QM_StrategyFarm_KimiGovernor_15min": "Kimi research-lane quota governor (NORMAL/CONSERVE/EXHAUSTED + KIMI_LOW_QUOTA.flag).",
    "QM_StrategyFarm_Pump_5min": "Backtest pump: advance queued work into free MT5 slots.",
    "QM_StrategyFarm_PumpMaintenance_Hourly": "Hourly pump maintenance / stuck-claim hygiene.",
    "QM_StrategyFarm_Q10Breaker_DryRun_15min": "Read-only dry run of the Q10 news-breaker logic.",
    "QM_StrategyFarm_TerminalWorkers_AT_STARTUP": "RETIRED/Disabled worker autostart (superseded by FactoryON_AtLogon).",
    "QM_StrategyFarm_WorktreeClean_4h": "Clean stale agent git worktrees (4-hourly).",
    "QM_StrategyFarm_WorktreeJanitor_6h": "Deeper worktree janitor sweep (6-hourly).",
    "QM_TMP_StaggeredWorkerReload_1700": "Temporary staggered worker reload helper.",
    "QM_TMP_WebsitePreview_8090": "Temporary local website preview server (port 8090).",
    "QM_TMP_WebsiteRefresh_8091": "Temporary local website refresh server (port 8091).",
    "QM_TSCon_Console_OnDisconnect": "Reconnect the console session on RDP disconnect (disabled).",
    "QM_WorkItemLogPruner_Daily_0310": "Daily prune of work-item logs (03:10).",
}

# Tasks that automatically spend AI tokens (flagged in a callout so the reader can see the
# unattended-AI-spend surface at a glance). Membership is by exact name.
AI_SPEND_TASKS = frozenset({
    "QM_StrategyFarm_CodexOrchestration_15min",
    "QM_StrategyFarm_ClaudeOrchestration_15min",
    "QM_StrategyFarm_GeminiOrchestration_15min",
    "QM_StrategyFarm_KimiOrchestration_15min",
    "QM_StrategyFarm_AgentRouter_5min",
    "QM_StrategyFarm_CodexFleetPacer",
    "QM_StrategyFarm_AgentChain_Critique_15min",
    "QM_StrategyFarm_MailboxSourceIntake_Daily",
    "QM_StrategyFarm_REvalDrain_15min",
})


def _exe_short(exe: str) -> str:
    if not exe:
        return "—"
    return Path(exe.split(";")[0].strip().strip('"')).name or exe


def _purpose(task: dict) -> str:
    desc = (task.get("description") or "").strip()
    if desc:
        return " ".join(desc.split())
    return PURPOSE_FALLBACK.get(task.get("name", ""), "—")


def _md_cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ").strip()


def render_markdown(tasks: list[dict], generated_at_utc: str) -> str:
    """Pure, deterministic render of the scheduled-automation page.

    ``tasks`` is a list of dicts with keys: name, state, cadence, exe, description.
    Output is identical for identical inputs except for ``generated_at_utc``.
    """
    tasks_sorted = sorted(tasks, key=lambda t: t.get("name", ""))
    enabled = [t for t in tasks_sorted if str(t.get("state", "")).lower() != "disabled"]
    disabled = [t for t in tasks_sorted if str(t.get("state", "")).lower() == "disabled"]
    ai_spend = [t for t in enabled if t.get("name") in AI_SPEND_TASKS]

    lines: list[str] = []
    lines.append("---")
    lines.append("type: infrastructure")
    lines.append("generated: true")
    lines.append(f"generator: {GENERATOR}")
    lines.append(f"schema: {SCHEMA}")
    lines.append('source: "Get-ScheduledTask -TaskName QM_* (live Windows Task Scheduler)"')
    lines.append(f"generated_at_utc: {generated_at_utc}")
    lines.append(f"task_count: {len(tasks_sorted)}")
    lines.append(f"enabled_count: {len(enabled)}")
    lines.append(f"disabled_count: {len(disabled)}")
    lines.append(f"ai_spend_count: {len(ai_spend)}")
    lines.append("---")
    lines.append("")
    lines.append("# Scheduled Automation (generated)")
    lines.append("")
    lines.append(
        "> **DO NOT EDIT BY HAND — generated.** Refresh with "
        f"`python -X utf8 {GENERATOR}`. Hand-written narrative and the script-vs-AI "
        "distinction live in [[Background Automation and Scheduled Tasks]]; this page is the "
        "machine-refreshed inventory of the live `QM_*` scheduled tasks. Authority for the "
        "AI-spend / quota model: repo `CLAUDE.md` + [[AI Spend and Quota Governance]]."
    )
    lines.append("")
    lines.append(
        f"Inventory: **{len(tasks_sorted)}** `QM_*` tasks "
        f"(**{len(enabled)}** enabled, **{len(disabled)}** disabled). "
        f"**{len(ai_spend)}** enabled tasks automatically spend AI tokens (all quota-governed; "
        "backtests are never throttled)."
    )
    lines.append("")
    lines.append("## Unattended AI-spend tasks")
    lines.append("")
    if ai_spend:
        for t in ai_spend:
            lines.append(f"- `{t.get('name')}` — {_md_cell(_purpose(t))}")
    else:
        lines.append("- (none detected in the current inventory)")
    lines.append("")
    lines.append("## All enabled tasks")
    lines.append("")
    lines.append("| Task | State | Cadence | Runner | Purpose |")
    lines.append("| --- | --- | --- | --- | --- |")
    for t in enabled:
        lines.append(
            f"| `{_md_cell(t.get('name',''))}` | {_md_cell(str(t.get('state','')))} "
            f"| {_md_cell(str(t.get('cadence','') or '—'))} | {_md_cell(_exe_short(t.get('exe','')))} "
            f"| {_md_cell(_purpose(t))} |"
        )
    lines.append("")
    lines.append("## Disabled tasks (retired / kill-switched — kept for history)")
    lines.append("")
    lines.append("| Task | Cadence | Runner | Purpose |")
    lines.append("| --- | --- | --- | --- |")
    for t in disabled:
        lines.append(
            f"| `{_md_cell(t.get('name',''))}` | {_md_cell(str(t.get('cadence','') or '—'))} "
            f"| {_md_cell(_exe_short(t.get('exe','')))} | {_md_cell(_purpose(t))} |"
        )
    lines.append("")
    lines.append(
        "See also: [[Background Automation and Scheduled Tasks]] · "
        "[[AI Spend and Quota Governance]] · [[Backups]] · [[Live Controls]] · "
        "repo `docs/ops/QUOTA_GOVERNOR_AND_FACTORY_RECOVERY_2026-06-21.md`."
    )
    lines.append("")
    return "\n".join(lines)


# --------------------------------------------------------------------------- live query (IO)
_PS_SNIPPET = r"""
$out = @()
foreach ($t in (Get-ScheduledTask -TaskName 'QM_*')) {
  $exe = ($t.Actions | ForEach-Object { $_.Execute }) -join ' ; '
  $cad = @()
  foreach ($tr in $t.Triggers) {
    $type = $tr.CimClass.CimClassName
    if ($tr.Repetition -and $tr.Repetition.Interval) { $cad += ('rep ' + $tr.Repetition.Interval) }
    elseif ($type -eq 'MSFT_TaskLogonTrigger') { $cad += 'at-logon' }
    elseif ($type -eq 'MSFT_TaskBootTrigger') { $cad += 'at-boot' }
    elseif ($type -eq 'MSFT_TaskDailyTrigger') { $cad += ('daily ' + ([string]$tr.StartBoundary).Substring(11,5)) }
    elseif ($type -eq 'MSFT_TaskWeeklyTrigger') { $cad += 'weekly' }
    elseif ($tr.StartBoundary) { $cad += ('at ' + [string]$tr.StartBoundary) }
    else { $cad += $type }
  }
  if ($cad.Count -eq 0) { $cad = @('on-demand') }
  $out += [pscustomobject]@{
    name = $t.TaskName
    state = [string]$t.State
    exe = $exe
    cadence = ($cad -join ' / ')
    description = ($t.Description -replace '\s+',' ')
  }
}
$out | ConvertTo-Json -Depth 4
"""


def fetch_tasks() -> list[dict]:
    """Query the live scheduler (read-only). IO boundary; not unit-tested."""
    proc = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", _PS_SNIPPET],
        capture_output=True,
        text=True,
        timeout=120,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"Get-ScheduledTask failed: {proc.stderr.strip()}")
    data = json.loads(proc.stdout or "[]")
    if isinstance(data, dict):
        data = [data]
    return data


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output markdown path")
    ap.add_argument("--json-in", type=Path, default=None,
                    help="read tasks from a JSON file instead of the live scheduler (testing)")
    ap.add_argument("--stdout", action="store_true", help="print instead of writing --out")
    args = ap.parse_args(argv)

    if args.json_in:
        tasks = json.loads(Path(args.json_in).read_text(encoding="utf-8"))
        if isinstance(tasks, dict):
            tasks = [tasks]
    else:
        tasks = fetch_tasks()

    now = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    md = render_markdown(tasks, now)

    if args.stdout:
        sys.stdout.write(md)
        return 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(md, encoding="utf-8")
    print(f"wrote {args.out} ({len(tasks)} tasks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
