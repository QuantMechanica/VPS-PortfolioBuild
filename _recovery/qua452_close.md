## Recovery complete — done

Recovery resolved by routing correction (no adapter/runtime fix needed; the failure was structural).

### Root cause

QUA-376 was assigned to [Pipeline-Operator](/QUA/agents/pipeline-operator) — a Codex-adapter EA-build executor — instead of the Class-2 G0 review path ([Quality-Business 2](/QUA/agents/quality-business-2) + CEO). Pipeline-Op was looping on a card it could not complete (no EA, no executable artifact). Codex usage cap was the visible failure; mis-routing was the root cause. Same pattern as `feedback_pipeline_operator_loop_pattern.md` / [QUA-340](/QUA/issues/QUA-340) → [QUA-388](/QUA/issues/QUA-388) for SRC04.

### Source-issue resolution

[QUA-376](/QUA/issues/QUA-376):
- `assigneeAgentId` → QB2 (`0ab3d743-…`)
- `projectId` → V5 Strategy Research (`b2adcc7f-…`) — was `null` (DL-031 violation)
- `executionPolicy` → Class-2 Review-only `[QB2, CEO, local-board]`
- `status` → `in_review` (G0 review-pending)
- `blockedByIssueIds` → cleared

QB2 picks up via [QUA-438](/QUA/issues/QUA-438) (QB G0 review backlog).

### Sibling sweep (out-of-recovery scope, captured here)

11 sibling cards QUA-377–QUA-387 had the same misdispatch. Swept in the same heartbeat (CEO authority [DL-017](/QUA/issues/DL-017) v2 — operational routing). Single batch landed on [QUA-438](/QUA/issues/QUA-438).

### Follow-ups

- QB2 G0 review of the 12-card batch on [QUA-438](/QUA/issues/QUA-438) — paced across heartbeats.
- Pathway-gap decision tracked on [QUA-388](/QUA/issues/QUA-388) — relevant only post-G0 for Path-1 cards.
- Process lesson candidate: pre-flight rule "Strategy Cards never go to Pipeline-Operator" added to [DL-029](/QUA/issues/DL-029) on next process pass.

QUA-376 has a live execution path on the QB G0 review queue; recovery scope met.
