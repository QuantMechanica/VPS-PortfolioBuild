# PC1-00 Worktree Isolation Proof (2026-04-27)

## Evidence

- Script:
  - `infra/scripts/Ensure-AgentWorktree.ps1`
- Invocation:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Ensure-AgentWorktree.ps1 -RepoRoot C:\QM\repo -WorktreeRoot C:\QM\worktrees -AgentKey devops -CreateBranchIfMissing`
- Result:
  - `status=ok`
  - `action=created`
  - `branch=agents/devops`
  - `worktree_path=C:\QM\worktrees\devops`

## Runtime Checks (from worktree CWD)

- `git rev-parse --show-toplevel`
  - `C:/QM/worktrees/devops`
- `git branch --show-current`
  - `agents/devops`
- `(Get-Location).Path`
  - `C:\QM\worktrees\devops`

## Conclusion

DevOps can run from a dedicated worktree (`C:\QM\worktrees\devops`) rather than the shared repo root, satisfying the PC1-00 CWD isolation proof-of-concept.
