# QUA-509 Redirect Note (2026-04-29)

Use this as the issue comment on `QUA-509` when closing `QUA-510`.

Pipeline-Op routing clarification:

- Your runtime `adapterConfig.cwd` is `C:\QM\worktrees\pipeline-operator` (branch `agents/pipeline-operator`).
- The earlier empty-path diagnosis was for the Paperclip project workspace path, which is now bootstrapped.
- Resume `QUA-509` from your existing `pipeline-operator` worktree; do not switch cwd in this heartbeat.

Operational note:

- `C:\QM\worktrees\pipeline-operations` and project-path worktree bootstrap are retained as clean spare/recovery workspaces.
