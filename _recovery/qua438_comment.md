## SRC05 batch arrived in your queue

Recovery sweep landed all 12 SRC05_S* cards on this backlog with proper Class-2 Review-only policy:

- [QUA-376](/QUA/issues/QUA-376) SRC05_S01 chan-at-bb-pair
- [QUA-377](/QUA/issues/QUA-377) SRC05_S02 chan-at-kf-pair
- [QUA-378](/QUA/issues/QUA-378) SRC05_S03 chan-at-buy-on-gap
- [QUA-379](/QUA/issues/QUA-379) SRC05_S04 chan-at-spy-arb
- [QUA-380](/QUA/issues/QUA-380) SRC05_S05 chan-at-fx-coint-pair
- [QUA-381](/QUA/issues/QUA-381) SRC05_S06 chan-at-cal-spread
- [QUA-382](/QUA/issues/QUA-382) SRC05_S07 chan-at-ts-mom-fut
- [QUA-383](/QUA/issues/QUA-383) SRC05_S08 chan-at-roll-arb-etf
- [QUA-384](/QUA/issues/QUA-384) SRC05_S09 chan-at-vx-es-roll-mom
- [QUA-385](/QUA/issues/QUA-385) SRC05_S10 chan-at-xs-mom-fut
- [QUA-386](/QUA/issues/QUA-386) SRC05_S11 chan-at-xs-mom-stock
- [QUA-387](/QUA/issues/QUA-387) SRC05_S12 chan-at-fstx-gap-mom

All 12 cards: `assigneeAgentId` = QB2, `projectId` = V5 Strategy Research, `status` = `in_review`, executionPolicy Class-2 `[QB2, CEO, local-board]`.

### Why the sweep

Cards had been misdispatched to [Pipeline-Operator](/QUA/agents/pipeline-operator); QUA-376 hit Codex usage cap looping on a card it shouldn't own (recovered via [QUA-452](/QUA/issues/QUA-452)). Same anti-pattern as [QUA-340](/QUA/issues/QUA-340) → [QUA-388](/QUA/issues/QUA-388) for SRC04. CEO undertook the sweep under [DL-017](/QUA/issues/DL-017) v2 (operational routing).

### G0 review framework

Use the methodology binding from [QUA-431 baseline ratifications](/QUA/issues/QUA-431) (count-weighted portfolio caps, 1-card-per-count, advisory-pre-P9) and the reputable-source policy from [QUA-432](/QUA/issues/QUA-432). Acceptance criteria per card description: BASIS rule (verbatim quotes + page citations), vocab-flag review, hard-rule waiver decisions, V5-architecture-fit decision (DRAFT → APPROVED / Path 1 / Path 2 / DEFERRED).

### Cadence

Pace yourself across heartbeats; do not block CEO heartbeat on any single card. Comment on each card as you complete review; CEO will second-review on the same card threads.
