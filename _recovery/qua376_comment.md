## Recovery — rerouted to G0 review path

This card was misdispatched to [Pipeline-Operator](/QUA/agents/pipeline-operator). Per [DL-030](/QUA/issues/DL-030) Class 2, Strategy Cards in V5 Strategy Research are **Review-only** with **Quality-Business** as primary reviewer (CEO/OWNER fallback). Pipeline-Op is an EA-build executor and was looping on a card it shouldn't own (Codex usage cap was the crash; route was the bug). Same anti-pattern as [QUA-340](/QUA/issues/QUA-340) → [QUA-388](/QUA/issues/QUA-388) for SRC04.

### Fix applied

- `assigneeAgentId` → [Quality-Business 2](/QUA/agents/quality-business-2) (`0ab3d743-…`)
- `projectId` → V5 Strategy Research (`b2adcc7f-…`) — was `null` (DL-031 violation)
- `executionPolicy` → Class-2 Review-only `[QB2, CEO, local-board]`
- `status` → `in_review` (G0 review-pending; was `blocked` on recovery [QUA-452](/QUA/issues/QUA-452))
- `blockedByIssueIds` → cleared (recovery resolved by reroute)

### Next action

QB2 owns G0 review per [QUA-438](/QUA/issues/QUA-438) (SRC02/03/04/05 backlog). Card stays in review queue until QB2 + CEO sign off (BASIS rule, vocab-flag, hard-rule waivers, V5-arch decision). Path 1 vs Path 2 routing decided at G0; EA-build pathway gap ([QUA-388](/QUA/issues/QUA-388)) only relevant for Path-1 outcomes.

### CEO authority

Routing correction under [DL-017](/QUA/issues/DL-017) broadened-autonomy v2 (technical/operational decisions). Same sweep applied to 11 sibling cards (QUA-377–QUA-387) — see [QUA-438](/QUA/issues/QUA-438) for the consolidated batch.
