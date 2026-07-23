# Company Audit Live Sources

Date: 2026-05-30

Use this file when restarting an agent or doing a company audit. The retired
orchestration stack is not a source of truth; do not use its old directory or dashboards as health
signals.

## Current Runtime Model

- Factory MT5 terminals: `D:\QM\mt5\T1` through `D:\QM\mt5\T10`.
- Live trading terminal: `C:\QM\mt5\T_Live`.
- `T_Live` is the former live T6 and is not part of the factory backtest pool.
- Factory phase names are `Q00` through `Q14`. Old `P*` keys may remain in generated
  compatibility files and should not be reported as canonical phase names.

## Audit Source Order

1. Live processes:
   - `terminal64.exe` / `metatester64.exe`
   - `python.exe` / `pythonw.exe` terminal workers and Qxx scripts
   - `pwsh.exe` `run_smoke.ps1`
   - `claude.exe`, `codex.exe`, and their child processes
2. Strategy farm database and state:
   - `D:\QM\strategy_farm\state\farm_state.sqlite`
   - `D:\QM\strategy_farm\state\health.json`
   - `D:\QM\strategy_farm\state\quota_snapshot.json`
3. Work-item evidence:
   - `D:\QM\reports\work_items\...\Qxx\...\aggregate.json`
   - `D:\QM\reports\work_items\...\summary.json`
   - raw MT5 reports/logs under the same work item
4. Farm controller commands from `C:\QM\repo`:
   - `python tools\strategy_farm\farmctl.py health`
   - `python tools\strategy_farm\farmctl.py mt5-slots`
   - `python tools\strategy_farm\agent_router.py status`
   - `python tools\strategy_farm\agent_router.py list-tasks --agent claude`
   - `python tools\strategy_farm\agent_router.py list-tasks --agent codex`
5. Repo/worktree state:
   - `C:\QM\repo`
   - `C:\QM\worktrees\*`

## Stale Or Compatibility Sources

These files can be useful as exported snapshots, but they are not sufficient for a live
audit:

- `public-data\public-snapshot.json`
- `D:\QM\reports\state\pipeline_state.json`

The former static `company-runtime` export was removed because it represented a
retired agent hierarchy rather than current runtime state. Do not recreate it as a
health source.

If these mention `P2`, `P3`, `P3.5`, or old T6/T_Live assumptions, report them as stale
or compatibility data and verify against live Qxx work-item evidence.

## Claude Token Hygiene Checks

Before starting or trusting Claude orchestration, check for stale spawned sessions:

```powershell
Get-CimInstance Win32_Process -Filter "Name='claude.exe' OR Name='git.exe' OR Name='git-remote-https.exe' OR Name='git-credential-manager.exe'" |
  Select-Object ProcessId,ParentProcessId,Name,CreationDate,CommandLine
```

Red flags:

- many `claude.exe -p --model sonnet ...` sessions with no matching active router tasks;
- old `git push origin agents/claude-orchestration-*` process trees;
- `git-credential-manager get` processes older than a few minutes;
- `QM_StrategyFarm_ClaudeOrchestration_15min` running while `agent_router.py list-tasks
  --agent claude` returns `[]`.

Throttle Claude before spending more tokens: stop stale Claude processes, stop stale Git
children, and keep Claude orchestration disabled until there is a concrete premium-review
queue. Codex should handle default code/ops/build work.
