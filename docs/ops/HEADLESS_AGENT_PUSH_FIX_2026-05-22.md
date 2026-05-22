# Headless Agent Push Fix

Date: 2026-05-22
Task: `d49e6e9b-74f4-4fad-8bf6-0be09c58016f`
Status: REVIEW

## Diagnosis

The Strategy Farm orchestration scheduled tasks run as `SYSTEM`:

- `QM_StrategyFarm_CodexOrchestration_15min`
- `QM_StrategyFarm_ClaudeOrchestration_15min`

Both invoke `tools/strategy_farm/run_agent_orchestration_task.py` from
`C:\QM\repo`. Git is configured with `credential.helper=manager`, and the repo
remote is HTTPS:

`https://github.com/QuantMechanica/VPS-PortfolioBuild.git`

In this headless worktree context, `git push --dry-run origin HEAD` timed out
after 120 seconds. That matches the observed `PUSH_TIMEOUT` /
`PUSH_BLOCKED_AUTH` reports: Git Credential Manager is not a reliable
non-interactive credential provider for the scheduled-task context.

## Fix

`tools/strategy_farm/run_agent_orchestration_task.py` now has a
headless-safe push path:

- After each agent slot exits, the wrapper calls `push_worktree_branch()`.
- It refuses to invoke interactive GCM.
- It sets `GIT_TERMINAL_PROMPT=0`.
- It uses `GH_TOKEN` or `GITHUB_TOKEN` from the scheduled-task environment when
  present.
- The token is not written to the repository or to the result JSON. Error text
  redacts the token if Git echoes it.
- If no token is present, the result records:
  `missing_GH_TOKEN_or_GITHUB_TOKEN`.

Required OWNER/credential-custodian action:

Provide a GitHub token with repository contents write permission to the
scheduled-task runtime environment as `GH_TOKEN` or `GITHUB_TOKEN`.

## Verification

- `python -m py_compile tools/strategy_farm/run_agent_orchestration_task.py`: PASS
- `push_worktree_branch(... )` with no token returns
  `missing_GH_TOKEN_or_GITHUB_TOKEN` immediately instead of hanging.
- `git ls-remote --heads origin agents/codex-orchestration-1`: PASS transport read.
- `git push --dry-run origin HEAD`: timed out after 120 seconds in this
  headless worktree context, confirming the failure mode.

No secret was created, stored, printed, or committed.
