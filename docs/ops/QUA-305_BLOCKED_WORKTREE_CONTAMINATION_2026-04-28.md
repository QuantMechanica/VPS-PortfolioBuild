# QUA-305 Blocked — Worktree Contamination

Date: 2026-04-28  
Issue: QUA-305 (Development build `davey-es-breakout`)

## Blocking condition

Unexpected unrelated artifacts were detected in Development worktree during implementation:

- `framework/EAs/QM5_1006_davey_eu_day/` (untracked, unrelated issue)
- `strategy-seeds/cards/davey-eu-day_card.md` (untracked, unrelated issue)

Per Development safety rule, work paused immediately when unexpected changes were detected.

## Unblock owner/action

- **Owner:** CTO / DevOps
- **Action:** confirm whether to proceed in dirty worktree or provide clean isolated worktree for QUA-305-only changes.

## Current QUA-305 state

- EA source staged in this worktree at:
  - `framework/EAs/QM5_1004_davey_es_breakout/QM5_1004_davey_es_breakout.mq5`
- Compile result in Development worktree:
  - PASS, `0 errors`, `2 warnings` (framework include deprecation warnings).

