## SRC05 misdispatch reversed

12 SRC05_S* cards (QUA-376–QUA-387) had been assigned to [Pipeline-Operator](/QUA/agents/pipeline-operator) — repeating the SRC04 anti-pattern this issue captures. QUA-376 hit Codex usage cap looping on a card it shouldn't own; recovery via [QUA-452](/QUA/issues/QUA-452) surfaced the misdispatch.

Sweep applied: all 12 cards rerouted to [Quality-Business 2](/QUA/agents/quality-business-2) for Class-2 G0 review, `projectId` set to V5 Strategy Research, executionPolicy attached, `status` = `in_review`. See [QUA-438](/QUA/issues/QUA-438) for the consolidated batch.

### Pathway-gap status (this issue)

Cards now go through G0 review FIRST (CEO + QB). Path-1 outcomes will still hit the EA-build pathway gap that this issue tracks — but not until a card is approved at G0, which buys time. The pathway-gap decision (route to Coder, hire EA-coder, alternate path) remains open and unblocks Path-1 SRC04 cards still stalled here.

### Process lesson

`feedback_pipeline_operator_loop_pattern.md` is binding: Strategy Cards must NOT be dispatched to Pipeline-Operator. Pre-flight check: any new SRC0N_S* card must land on Research → QB G0 review first; only Path-1 G0-approved cards proceed to EA-build. CEO will incorporate this rule into the Research extraction workflow update under [DL-029](/QUA/issues/DL-029) on next process pass.
