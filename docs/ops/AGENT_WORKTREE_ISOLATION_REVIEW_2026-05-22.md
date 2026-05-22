# Agent Worktree Isolation Review - 2026-05-22

Task: `9d3adde4-cc38-494c-b27f-6dd14b22c01a`

## Verdict

`WORKTREE_ISOLATION_VERIFIED`

The active orchestration checkout is clean and the headless agent wrapper routes scheduled agent sessions into per-agent git worktrees under `C:\QM\worktrees`.

## Evidence

- `git status --short` in `C:\QM\worktrees\codex-orchestration-1` returned no dirty files.
- Current branch: `agents/codex-orchestration-1`.
- `tools/strategy_farm/run_agent_orchestration_task.py` defines:
  - `WORKTREE_ROOT = C:\QM\worktrees`
  - `worktree_path(agent, slot) -> C:\QM\worktrees\<agent>-orchestration-<slot>`
  - `branch_name(agent, slot) -> agents/<agent>-orchestration-<slot>`
  - `ensure_worktree()` using `git worktree add -B ...`
- Existing git worktrees include:
  - `C:/QM/worktrees/codex-orchestration-1` on `agents/codex-orchestration-1`
  - `C:/QM/worktrees/claude-orchestration-1` on `agents/claude-orchestration-1`
  - `C:/QM/worktrees/claude-orchestration-2` on `agents/claude-orchestration-2`
  - `C:/QM/worktrees/claude-orchestration-3` on `agents/claude-orchestration-3`
  - `C:/QM/worktrees/gemini-orchestration-1` on `agents/gemini-orchestration-1`
- Scheduled task actions point to `tools\strategy_farm\run_agent_orchestration_task.py`:
  - `QM_StrategyFarm_CodexOrchestration_15min`: `--agent codex --max-sessions 1`
  - `QM_StrategyFarm_ClaudeOrchestration_15min`: `--agent claude --max-sessions 3`
- Scheduled task settings use parallel task instances, but each wrapper slot uses its own lock and worktree path.
- Router status showed `codex max_parallel=5` and `claude max_parallel=3`.

## Scope Notes

No `T_Live` or AutoTrading setting was touched. No MT5 terminal was started or interrupted.
