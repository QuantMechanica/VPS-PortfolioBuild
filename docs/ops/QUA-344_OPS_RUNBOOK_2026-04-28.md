# QUA-344 Ops Runbook (2026-04-28)

Scope: operational handling for `QUA-344` while waiting for executable binding.

## 1) Run heartbeat tick (with no-change detection)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/Invoke-QUA344Heartbeat.ps1 -RepoRoot C:\QM\worktrees\research
```

Output:
- `docs/ops/QUA-344_HEARTBEAT_<timestamp>.json`
- `docs/ops/QUA-344_READINESS_CHECK_<timestamp>.json`
- `docs/ops/QUA-344_HEARTBEAT_STATE.json`

## 2) Post blocked status + resume comment

Use payloads:
- `docs/ops/QUA-344_ISSUE_STATUS_UPDATE_2026-04-28.json`
- `docs/ops/QUA-344_ISSUE_COMMENT_PAYLOAD_2026-04-28.json`

## 3) Trigger child-task suggestion interaction

Use payload:
- `docs/ops/QUA-344_INTERACTION_SUGGEST_TASKS_2026-04-28.json`

## 4) Execute immediately after unblock fields arrive

Fill + run from template:
- `docs/ops/QUA-344_P1_BASELINE_TEMPLATE_2026-04-28.json`

Required fields before dispatch:
- `ea_id`
- `ea_binary_path` (.ex5)
- `target_terminal` (or `any`)
- approved baseline window

## 5) Completion evidence policy (pipeline)

After first P1 run, publish:
- terminal PID
- report file count from filesystem (truth)
- report byte sizes (NO_REPORT disambiguation)
- completion timestamp

## Canonical index

- `docs/ops/QUA-344_UNBLOCK_PACKET_INDEX_2026-04-28.md`
- `docs/ops/QUA-344_UNBLOCK_PACKET_INDEX_2026-04-28.json`
