# QUA-212 Kanban Dispatch Gap (2026-05-08)

## Context
Issue wake continues to target `QUA-212` (`in_progress`, high), but Kanban dispatcher command returns no actionable CTO task:

- `python C:/QM/paperclip/tools/ops/next_task.py --agent cto --json`
- Result: `{"agent":"cto","tasks":[],"message":"no actionable tasks"}`

## Blocker classification
- Block class: `cap-blocked` (dispatch/source-of-truth mismatch)
- Unblock owner: `local-board/OWNER` (Kanban source-of-truth maintainer)

## Required unblock action
1. Add or re-queue a CTO row in `C:/QM/paperclip/kanban/company_kanban.csv` mapped to `paperclip_issue_id=QUA-212`.
2. Set status to actionable (`queued` or `in_progress`) for assignee `cto`.
3. Re-run `next_task.py --agent cto --json` and verify it returns that task id.

## Why this matters
CTO is currently performing direct issue-scoped implementation from wake payloads, but the OWNER binding requires Kanban dispatch as authoritative entrypoint each heartbeat.

## Current workaround in effect
- Continue running mandatory Kanban check each heartbeat.
- Continue leaving durable progress artifacts on QUA-212 while dispatch gap is unresolved.

## Automated readiness check
- Script: `scripts/ops/check_kanban_dispatch_gap.py`
- Command: `python scripts/ops/check_kanban_dispatch_gap.py --issue QUA-212 --assignee cto`
- Latest result: `{"issue":"QUA-212","assignee":"cto","match_count":0,"actionable_count":0,"status":"FAIL"}`
- Latest machine snapshot: `docs/ops/QUA-212_KANBAN_DISPATCH_STATUS_20260508T071316Z.json`
- Status snapshot wrapper: `scripts/ops/write_qua212_dispatch_status.ps1`
- Latest machine snapshot: `docs/ops/QUA-212_KANBAN_DISPATCH_STATUS_20260508T071356Z.json`
- Stable latest snapshot pointer: `docs/ops/QUA-212_KANBAN_DISPATCH_STATUS_latest.json`
