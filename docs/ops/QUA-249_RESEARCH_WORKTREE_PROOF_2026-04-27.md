# QUA-249 Research Worktree Materialization Proof (2026-04-27)

Status: completed

- Target path: `C:\QM\worktrees\research`
- Script: `C:\QM\repo\infra\scripts\Ensure-AgentWorktree.ps1`
- Invocation:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Ensure-AgentWorktree.ps1 -AgentKey research -CreateBranchIfMissing`

Run evidence:

1. First run result: `action=created`, `branch=agents/research`, `status=ok`
2. Second run result: `action=already_present`, `branch=agents/research`, `status=ok`

Validation:

- `git -C C:\QM\repo worktree list --porcelain` includes `worktree C:/QM/worktrees/research` with `branch refs/heads/agents/research`.
