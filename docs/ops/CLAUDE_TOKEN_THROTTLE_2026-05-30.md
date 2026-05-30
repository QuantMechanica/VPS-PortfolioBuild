# Claude Token Throttle

Date: 2026-05-30
Operator: Codex

## Reason

Company audit found no active Claude router tasks:

```powershell
python tools\strategy_farm\agent_router.py list-tasks --agent claude
# []
```

Despite that, many `claude.exe -p --model sonnet --dangerously-skip-permissions
--add-dir C:\QM\worktrees\claude-orchestration-*` sessions and stale `git push origin
agents/claude-orchestration-*` child process trees were still alive. Several were older
than 12 hours; some were older than one day. This wastes Claude quota and leaves Git
credential-manager / remote-https children hanging.

## Action Taken

- Stopped `QM_StrategyFarm_ClaudeOrchestration_15min`.
- Disabled `QM_StrategyFarm_ClaudeOrchestration_15min`.
- Stopped stale `claude.exe`, `git.exe`, `git-remote-https.exe`, and
  `git-credential-manager.exe` processes tied to the old Claude orchestration runs.
- Initially set `D:\QM\strategy_farm\CLAUDE_DISABLED.flag` as an emergency brake.
  This was later split into controlled mode: `CLAUDE_PUMP_DISABLED.flag` blocks
  automatic pump Claude lanes, while the router may still use Claude under
  `CLAUDE_BUDGET_POLICY.json`.
- Archived stale empty `D:\QM\strategy_farm\CODEX_LOW_TOKENS.flag` to
  `CODEX_LOW_TOKENS.flag.cleared_20260530T211719Z`; it was blocking Codex spawns
  and causing the pump to fall back to Claude.
- Did not stop MT5 factory workers, Qxx pipeline scripts, Codex, or `T_Live`.

## Current Policy

Keep Claude pump lanes disabled. Claude orchestration may remain enabled only under
`CLAUDE_BUDGET_POLICY.json` and only for a concrete premium-reasoning queue:

- strategy critique that Codex should not do,
- high-signal OWNER synthesis,
- manual live-trading authority workflow,
- final review of complex architecture/process changes.

Default code, ops, EA builds, tests, dashboard plumbing, and routine pipeline repairs
should route to Codex.

See `docs/ops/CLAUDE_CONTROLLED_RUN_POLICY_2026-05-30.md` for the controlled-run
policy through Friday 2026-06-05 00:00 Europe/Berlin.

## Re-enable Command

```powershell
Enable-ScheduledTask -TaskName QM_StrategyFarm_ClaudeOrchestration_15min
Start-ScheduledTask -TaskName QM_StrategyFarm_ClaudeOrchestration_15min
```

Before increasing cadence or removing budget limits, check:

```powershell
python tools\strategy_farm\agent_router.py list-tasks --agent claude
Get-Process -Name claude,git,git-remote-https,git-credential-manager -ErrorAction SilentlyContinue
```
