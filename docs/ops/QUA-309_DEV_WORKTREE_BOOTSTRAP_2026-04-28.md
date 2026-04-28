# QUA-309 Dev Worktree Bootstrap (2026-04-28)

Status: complete (worktree created and idempotency validated)

- Script: `infra/scripts/Ensure-AgentWorktree.ps1`
- Repo root: `C:\QM\repo`
- Worktree root: `C:\QM\worktrees`
- Agent key: `development`
- Branch: `agents/development`
- Worktree path: `C:\QM\worktrees\development`

## Execution

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\Ensure-AgentWorktree.ps1 -RepoRoot C:\QM\repo -WorktreeRoot C:\QM\worktrees -AgentKey development -CreateBranchIfMissing
```

Observed result:
- `status=ok`
- `action=created`

## Idempotency Re-Run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\Ensure-AgentWorktree.ps1 -RepoRoot C:\QM\repo -WorktreeRoot C:\QM\worktrees -AgentKey development
```

Observed result:
- `status=ok`
- `action=already_present`

## Safety Notes

- Check-then-act behavior rejects non-empty unmanaged target directories.
- Script only mutates via `git branch` (optional create) and `git worktree add` when absent.
- No T6 scope and no EA strategy code touched.
