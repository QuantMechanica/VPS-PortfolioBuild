# Friday Restart Prompt - Claude Re-enable Checkpoint 2026-05-22

Stand: 2026-05-19 after OWNER directive to stop all Claude token burn.

Use this prompt on Friday, 2026-05-22, when Claude quota is expected to be available again. Read this whole file first. Do not re-enable Claude automatically before confirming current quota and OWNER intent.

## 0. Prompt To Start Friday Session

```text
Restart Prompt - Friday 2026-05-22 Claude Quota Reset

Read C:/QM/repo/CLAUDE.md and this file first:
C:/QM/repo/docs/ops/FRIDAY_RESTART_PROMPT_2026-05-22_CLAUDE_REENABLE.md

Context: On Tuesday 2026-05-19, OWNER ordered all Claude background token burn stopped. Claude jobs were killed, Claude scheduled wakes were disabled, `MAX_PARALLEL_CLAUDE` was set to 0, Claude spawn lanes in farmctl were routed to Codex, and `D:\QM\strategy_farm\CLAUDE_DISABLED.flag` was installed as a wrapper kill-switch.

Friday objective: Check whether Claude quota/OAuth is healthy again and ask OWNER before any Claude re-enable. If approved, restart from the current honest pipeline state with Codex still primary and Claude only as an explicitly capped fallback or selected lane. Do not assume "quota reset" means "turn everything back on".

Research policy: do not restart continuous research. New `research_strategy` work is only allowed when the combined strategy reservoir drops below 5; otherwise the factory should spend tokens on review, build, pipeline, and failure triage.

Before changing anything:
1. Verify no Claude process is already running.
2. Verify `QM_StrategyFarm_BoardAdvisor_Hourly` and `QM_StrategyFarm_AutonomousWake_Hourly` are still disabled.
3. Verify `D:\QM\strategy_farm\CLAUDE_DISABLED.flag` still exists.
4. Snapshot pipeline state and lead candidate.
5. Confirm OWNER wants Claude re-enabled and at what cap.

Hard rules: no T_Live AutoTrading enable, no manual `terminal64.exe` start, no `git push --force`, no `codex login`, no `claude login` unless OWNER explicitly requests the interactive OAuth flow.
```

## 1. Current Guardrail

As of 2026-05-19, all autonomous Claude spend is hard-disabled:

- Running Claude CLI processes were killed.
- `tools/strategy_farm/farmctl.py` routes review, G0, and research work to Codex.
- `MAX_PARALLEL_CLAUDE = 0`.
- `QM_PREFER_CLAUDE_REVIEW` is ignored by the pump while this patch is active.
- `claude_review_spawn`, `claude_g0_spawn`, and `claude_research_spawn` return disabled/routed-to-Codex reasons.
- `QM_StrategyFarm_BoardAdvisor_Hourly` and `QM_StrategyFarm_AutonomousWake_Hourly` were disabled because they directly invoke Claude.
- `D:\QM\strategy_farm\CLAUDE_DISABLED.flag` blocks the Claude PS1 wrappers even if those tasks are accidentally re-enabled.
- Research is replenishment-only: `research_strategy` tasks are created only when the combined strategy reservoir is below 5.

This was intentional. Do not treat missing Claude activity as a bug before Friday.

## 2. Friday Re-enable Decision

On Friday, 2026-05-22:

1. Confirm OWNER wants Claude restarted.
2. Confirm Claude quota/OAuth is healthy.
3. Inspect current pipeline and Codex load before changing caps.
4. If approved, revert the Codex-only hard disable deliberately.

Do not run `claude login` unless OWNER explicitly asks; OAuth is interactive.

## 3. Required Checks

```powershell
cd C:/QM/repo

# Confirm no unexpected Claude is already burning tokens.
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -ieq 'claude.exe' -or $_.CommandLine -match 'claude\.cmd|claude-code|claude_research|claude_review|claude_g0|chrome-native-host' } |
  Select-Object ProcessId,ParentProcessId,Name,CommandLine

# Pipeline snapshot.
python C:/Windows/Temp/pipeline_now.py
python tools/strategy_farm/farmctl.py mt5-slots

# Check exact current code gates.
rg -n "MAX_PARALLEL_CLAUDE|claude disabled|prefer_claude_review|claude_research_spawn|claude_g0_spawn|claude_review_spawn" tools/strategy_farm/farmctl.py

# Confirm task-level Claude wakes are still off.
Get-ScheduledTask -TaskName QM_StrategyFarm_BoardAdvisor_Hourly,QM_StrategyFarm_AutonomousWake_Hourly |
  Select-Object TaskName,State

# Confirm the wrapper kill-switch is present.
Test-Path D:\QM\strategy_farm\CLAUDE_DISABLED.flag
```

## 4. Re-enable Patch Target

If OWNER confirms re-enable, update `tools/strategy_farm/farmctl.py` around `pump()`:

- Set `MAX_PARALLEL_CLAUDE` to the OWNER-approved cap, probably `3`.
- Restore `prefer_claude_review = os.environ.get("QM_PREFER_CLAUDE_REVIEW") == "1"` if Claude should only be fallback.
- Restore Claude G0/research spawn branches only if OWNER wants dual Claude+Codex operation again.
- Preserve the research replenish gate: do not spawn Claude, Codex, or Gemini research while strategy reservoir is 5 or higher.
- Keep Codex as default unless OWNER explicitly says Claude should be primary.
- Remove `D:\QM\strategy_farm\CLAUDE_DISABLED.flag`.
- Re-enable `QM_StrategyFarm_BoardAdvisor_Hourly` and/or `QM_StrategyFarm_AutonomousWake_Hourly` only if OWNER wants those Claude wakes back.

Recommended Friday default:

- Codex remains primary for build/review/research.
- Claude re-enabled only as capped fallback or selected G0/research lane.
- No marathon session; restart every 4-6 hours.

## 5. Verification Before Commit

```powershell
python -m py_compile tools/strategy_farm/farmctl.py
python -m pytest framework/scripts/tests/test_phase_backtest_drivers.py framework/scripts/tests/test_phase_runners_idempotence.py framework/scripts/tests/test_p4_walk_forward.py -q
git diff -- tools/strategy_farm/farmctl.py
```

Then commit with a message like:

```text
chore(pump): re-enable capped claude lanes after quota reset
```

## 6. Still Active Hard Rules

- Never enable T_Live AutoTrading without OWNER + signed manifest.
- Never manually start `terminal64.exe`.
- Never `git push --force`.
- Never `codex login`.
- Never let Claude restart before Friday confirmation.
