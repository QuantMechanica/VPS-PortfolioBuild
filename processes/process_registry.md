# Process Registry

## Factory Setup Standards

- MT5 factory terminals `T1`-`T5` must include an install-root `portable.txt` marker file (empty file) to prevent AppData split-brain when launched without explicit `/portable`.

## Concurrent-Write Discipline / Worktree Isolation

Canonical decision: [DL-028](../decisions/DL-028_per_agent_worktree_isolation.md). Narrative source of record: [`lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md`](../lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md).

- Agents writing to `framework/`, `infra/`, or any other path under concurrent multi-agent write contention run from `C:\QM\worktrees\<agent-key>\` on branch `agents/<agent-key>`, **not** from the shared `C:\QM\repo\` root.
- All `git add` / `git commit` / `git push` on `C:\QM\repo\` go through `infra/scripts/Invoke-GitWithMutex.ps1` (Windows named mutex serializes across worktrees).
- Stale `index.lock` files older than 20 min are surfaced by scheduled task `QM_GitIndexLockMonitor_10min` (every 10 min); see `infra/monitoring/Invoke-GitIndexLockMonitor.ps1`.
- Worktree creation/repair is idempotent via `infra/scripts/Ensure-AgentWorktree.ps1`.
- Race detection: if an agent observes mid-edit on-disk drift, it **safety-stops** and posts an issue comment offering merge / use-existing / overwrite options (Stop-digging Hard Rule).

Out of scope for this rule: `T6_Live` (governed by DL-025 + `CLAUDE.md` § Hard Boundaries) and `paperclip-prompts/*.md` (OWNER-managed; agent prompts are Git-canonical). Exceptions to the worktree rule require a successor DL-NNN.
