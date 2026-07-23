# QUA-344 Unblock Packet Index (2026-04-28)

Issue: `QUA-344`  
State: `blocked pending executable binding`

## Canonical blocker

- Owner: `Dev + CTO`
- Required action: provide `ea_id`, compiled `.ex5` path, target terminal routing, and approved baseline window.

## Ready-to-use controller artifacts

1. Status update payload (blocked + resume)
- `docs/ops/QUA-344_ISSUE_STATUS_UPDATE_2026-04-28.json`

2. Issue comment payload + markdown
- `docs/ops/QUA-344_ISSUE_COMMENT_PAYLOAD_2026-04-28.json`
- `docs/ops/QUA-344_ISSUE_COMMENT_DRAFT_2026-04-28.md`

3. Interaction payload to create child tasks
- `docs/ops/QUA-344_INTERACTION_SUGGEST_TASKS_2026-04-28.json`
- `docs/ops/QUA-344_INTERACTION_SUGGEST_TASKS_2026-04-28.md`

4. Child-issue proposal details
- `docs/ops/QUA-344_CHILD_ISSUE_PROPOSAL_BUILD_HANDOFF_2026-04-28.json`
- `docs/ops/QUA-344_CHILD_ISSUE_PROPOSAL_BUILD_HANDOFF_2026-04-28.md`

5. Pipeline execution template (post-unblock)
- `docs/ops/QUA-344_P1_BASELINE_TEMPLATE_2026-04-28.json`
- `docs/ops/QUA-344_PIPELINE_READINESS_UPDATE_2026-04-28.md`

6. Machine readiness gate
- script: `infra/scripts/Test-QUA344Readiness.ps1`
- output: `docs/ops/QUA-344_READINESS_CHECK_2026-04-28.json`
- run note: `docs/ops/QUA-344_READINESS_CHECK_RUN_2026-04-28.md`

## Current gate snapshot

From `docs/ops/QUA-344_READINESS_CHECK_2026-04-28.json`:
- `status: blocked`
- `card_status: DRAFT`
- `ea_id: TBD`
- `ea_binary_path: TBD`

## Immediate next action when unblocked

Run one-symbol P1 baseline (`EURGBP.DWX`, `D1`) and publish:
- terminal PID
- filesystem report count (truth)
- report byte sizes (NO_REPORT rule)
- completion timestamp
