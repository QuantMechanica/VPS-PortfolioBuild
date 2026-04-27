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
- Research live agent instructions updated to route work to isolated CWD:
  - `C:\QM\paperclip\data\instances\default\companies\03d4dcc8-4cea-4133-9f68-90c0d99628fb\agents\7aef7a17-d010-4f6e-a198-4a8dc5deb40d\instructions\AGENTS.md`
  - added `Workspace` section with:
    - `Primary CWD: C:\QM\worktrees\research`
    - explicit warning not to run git writes from `C:\QM\repo`
- DL-027 side-artifact refreshed:
  - `paperclip-prompts/diffs/research_basis_to_active.diff`
  - now records the live-only Workspace/CWD adaptation alongside the operating-contract appendix.
