# Claude Code Worker Setup - 2026-05-22

Task: `8e51327b-6609-48d2-be92-9b482f15d8da`

## Changes

- `tools/strategy_farm/agent_router.py`
  - Claude registry now includes `code`.
  - Claude remains enabled at `max_parallel=3`.
  - Codex remains enabled at `max_parallel=5`.
- `tools/strategy_farm/run_agent_orchestration_task.py`
  - Added `claude` as a supported headless orchestration agent.
  - Added Claude disabled-flag respect via `D:\QM\strategy_farm\CLAUDE_DISABLED.flag`.
  - Added per-slot locks: slot 1 uses the historical lock name, slots 2-3 use slot-specific lock files.
  - Added per-slot git worktrees under `C:\QM\worktrees\<agent>-orchestration-<slot>` on branches `agents/<agent>-orchestration-<slot>`.
  - Added `--max-sessions`; Claude uses up to 3 concurrent slots, Codex/Gemini stay at one.
- `tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1`
  - Default cadence corrected to 15 minutes.
  - Registers `QM_StrategyFarm_ClaudeOrchestration_15min` with `--agent claude --max-sessions 3`.
  - Existing Codex/Gemini task arguments now pass `--max-sessions 1`.
- `tools/strategy_farm/tests/test_agent_router.py`
  - Added assertion that enabled Claude has the `code` capability.

## Installed Task

`QM_StrategyFarm_ClaudeOrchestration_15min` was registered without `-RunNow`.

Observed scheduled-task state:

```text
TaskName  : QM_StrategyFarm_ClaudeOrchestration_15min
State     : Ready
Execute   : C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe
Arguments : "C:\QM\repo\tools\strategy_farm\run_agent_orchestration_task.py" --agent claude --max-sessions 3
```

## Verification

```text
python -m py_compile tools/strategy_farm/agent_router.py tools/strategy_farm/run_agent_orchestration_task.py
PASS
```

```text
python -m unittest tools.strategy_farm.tests.test_agent_router
Ran 19 tests
OK
```

```text
python tools/strategy_farm/run_agent_orchestration_task.py --agent claude --max-sessions 3 --dry-run
ok=true, returncode=0
created/verified:
- C:\QM\worktrees\claude-orchestration-1 -> agents/claude-orchestration-1
- C:\QM\worktrees\claude-orchestration-2 -> agents/claude-orchestration-2
- C:\QM\worktrees\claude-orchestration-3 -> agents/claude-orchestration-3
```

```text
python tools/strategy_farm/agent_router.py status
claude capabilities include code,research,review,strategy,summary; max_parallel=3
codex max_parallel=5
```

## Handoff

Code-task handoff remains through the existing deterministic router contract:
Claude executes assigned `IN_PROGRESS` tasks and marks outputs `REVIEW`; Codex
then receives/reviews Codex-routable REVIEW work according to router state and
task payload. No pipeline verdict semantics were changed.

## Commit / Push

Committed locally on `agents/board-advisor`:

```text
feat(farm): add headless Claude code orchestration
```

Push was attempted with `GIT_TERMINAL_PROMPT=0` and blocked by missing GitHub
credentials in the headless environment:

```text
fatal: Cannot prompt because terminal prompts have been disabled.
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```
