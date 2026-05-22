# Codex/Gemini Headless Orchestration Scheduled Tasks

Date: 2026-05-22
Status: REVIEW_READY
Router task: `6c03acec-f89c-46bf-9e37-50fa110a3e73`

## Implemented

- Added `tools/strategy_farm/run_agent_orchestration_task.py`.
  - Runs one single-pass orchestration prompt for `codex` or `gemini`.
  - Writes prompt, live log, and JSON result files under `D:/QM/strategy_farm/logs/`.
  - Uses per-agent overlap locks under `D:/QM/strategy_farm/locks/`.
  - Exits after one pass; no sleep loop.
- Added `tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1`.
  - Registers `QM_StrategyFarm_CodexOrchestration_15min`.
  - Registers `QM_StrategyFarm_GeminiOrchestration_15min`.
  - Runs as `SYSTEM`, highest privilege, repeat interval `PT15M`, `MultipleInstances=IgnoreNew`, execution limit `PT4H`.

## Fixes Applied During Verification

- Updated the Codex command for current CLI syntax:
  - `codex exec --dangerously-bypass-approvals-and-sandbox --cd C:/QM/repo`
  - Removed the obsolete `-a never` option that caused exit code `2`.
- Updated the Gemini command for headless SYSTEM execution:
  - Adds `--skip-trust`.
  - Sets `USERPROFILE`, `HOME`, `HOMEDRIVE`, `HOMEPATH`, and `GEMINI_DEFAULT_AUTH_TYPE=oauth-personal` so Gemini uses the Administrator `.gemini` OAuth/trust profile instead of `C:/Windows/System32/config/systemprofile`.

## Verification

- `python -m py_compile tools/strategy_farm/run_agent_orchestration_task.py` -> PASS.
- `python tools/strategy_farm/run_agent_orchestration_task.py --agent codex --dry-run` -> PASS.
  - Evidence: `D:/QM/strategy_farm/logs/codex_orchestration_20260522T062815Z.json`
- `python tools/strategy_farm/run_agent_orchestration_task.py --agent gemini --dry-run` -> PASS.
  - Evidence: `D:/QM/strategy_farm/logs/gemini_orchestration_20260522T062815Z.json`
- Codex CLI headless auth smoke:
  - Command returned `OK`.
  - Observed `approval: never`, `sandbox: danger-full-access`.
- Gemini CLI headless auth smoke:
  - Command returned `OK`.
  - `gemini --help` confirms `--prompt` is non-interactive/headless mode.
- Scheduled-task launch/overlap-guard smoke:
  - Fresh lock files were placed to avoid nested real agent sessions during this active Codex pass.
  - `Start-ScheduledTask` executed both tasks.
  - Both tasks exited with `LastTaskResult=0`.
  - Skip evidence:
    - `D:/QM/strategy_farm/logs/codex_orchestration_20260522T062857Z.json`
    - `D:/QM/strategy_farm/logs/gemini_orchestration_20260522T062857Z.json`

## Current Scheduled Task State

- `QM_StrategyFarm_CodexOrchestration_15min`
  - State: Ready
  - Principal: SYSTEM
  - Action: `C:/Users/Administrator/AppData/Local/Programs/Python/Python311/pythonw.exe`
  - Arguments: `"C:/QM/repo/tools/strategy_farm/run_agent_orchestration_task.py" --agent codex`
  - Repetition interval: 15 minutes
- `QM_StrategyFarm_GeminiOrchestration_15min`
  - State: Ready
  - Principal: SYSTEM
  - Action: `C:/Users/Administrator/AppData/Local/Programs/Python/Python311/pythonw.exe`
  - Arguments: `"C:/QM/repo/tools/strategy_farm/run_agent_orchestration_task.py" --agent gemini`
  - Repetition interval: 15 minutes

## Guardrails

- Did not enable T_Live or AutoTrading.
- Did not start `terminal64.exe`.
- Did not interrupt active T1-T10 backtests.
- Did not launch a nested full Codex/Gemini orchestration pass during this active worker session; the scheduler path was verified through the overlap guard.
