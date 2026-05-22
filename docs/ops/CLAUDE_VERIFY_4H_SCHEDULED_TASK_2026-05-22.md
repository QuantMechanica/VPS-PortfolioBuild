# Claude Verify 4h Scheduled Task

Date: 2026-05-22
Status: REVIEW_READY
Router task: `de85c13f-03d8-4460-bd89-7c0831e8e1c6`

Implemented a VPS-local, headless Claude verification scheduled task for the Strategy Farm.

## Files

- `tools/strategy_farm/prompts/claude_farm_verify_4h.md`
- `tools/strategy_farm/run_claude_verify_4h.ps1`
- `tools/strategy_farm/install_claude_verify_4h_task.ps1`
- `docs/ops/FARM_VERIFY_20260522T111118Z.md`

## Task Definition

- Name: `QM_StrategyFarm_ClaudeVerify_4h`
- Principal: `SYSTEM`
- Run level: highest
- Action: `powershell.exe`
- Arguments: `-NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\tools\strategy_farm\run_claude_verify_4h.ps1"`
- Working directory: `C:\QM\repo`
- Recurrence: every 4 hours (`PT4H`)
- Multiple instances: `IgnoreNew`
- Execution limit: 4 hours

## Verification

- Runner and installer parse checks passed.
- Runner dry run passed and resolved `claude.cmd`.
- Scheduled task registered and is `Ready`.
- Manual `Start-ScheduledTask` run completed with `LastTaskResult=0`.
- Claude produced a farm verification pass and report:
  - `docs/ops/farm_verification_2026-05-22T1100Z.md`
  - `D:\QM\strategy_farm\logs\claude_verify_4h_20260522T110120Z.json`

## Guardrails

- `CLAUDE_DISABLED.flag` is respected.
- Runner uses an overlap lock at `D:\QM\strategy_farm\locks\claude_verify_4h.lock`.
- No T_Live or AutoTrading changes.
- No manual `terminal64.exe` start.
- No pipeline verdict semantic changes.
- No email notifier work.
