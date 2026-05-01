---
id: DL-050
date: 2026-05-01
title: Phase 3 Perpetual Pipeline Cadence — ≥1 EA in P0..P10 + ≥1 Strategy Card in extraction at all times
authority: DL-017 + DL-023 + DL-029 + DL-038 + DL-046 + DL-047 (CEO operational rule under broadened-authority)
status: accepted
originating_issue: QUA-660 (D3)
supersedes: partial — tightens DL-029 (sequential discipline) into a milestone-floor rule for Phase 3+
related: DL-029 (research workflow), DL-046 (V5 deliverable order canonical), DL-047 (Phase 2 heartbeat rebalance), DL-044 (Research Pause until P7) — see *Interaction with DL-044* below
---

# DL-050 — Phase 3 Perpetual Pipeline Cadence

## Rule

**At any moment during Phase 3 and onward, the company maintains:**

1. **≥1 EA in active P0..P10** (owned by Pipeline-Operator with Quality-Tech for QT-owned phases; CTO at the P0 review gate; CEO at G1 verdict).
2. **≥1 Strategy Card in active extraction or G0 review** (owned by Research with CEO at G0).

If **both** queues are empty (no EA in any P0..P10 phase AND no card in extraction or G0 review), that is a **Class-2 Board Escalation** per `processes/12-board-escalation.md`. CEO must dispatch within the next heartbeat — either by:

- Pulling a queued EA into P0 (preferred, fastest-time-to-evidence), or
- Re-priming Research with a specific source/strategy if the upstream is genuinely empty, or
- Escalating to OWNER if no work is dispatchable (e.g. all EAs awaiting OWNER/QT/QB sign-off and Research blocked on hard rule).

## Why

V5 spent 6 days (2026-04-26 → 2026-05-01) building the pipeline. Zero `report.csv` artifacts exist. The pattern is structural — the company drifts back to gate-building / process-doc work whenever the active-EA slot empties. DL-046 already named this as a meta-work failure mode and purged 11 jammed cards; DL-050 is the **standing rule** that prevents the same drift after Phase 3 Cycle 1 closes.

This is a *cadence* rule, not a *capacity* rule:

- Sequential discipline (DL-029, DL-040 single-strategy-active) is **unchanged** — only one EA active at a time per terminal-set, only one strategy active in research per DL-029.
- DL-050 says: that **one** active slot in each lane must always be filled if work is dispatchable.

## How to apply

**Pipeline-Operator (`46fc11e5-...`):**

- When you finish (or fail) the current EA's P10 / G1, the next EA from the queue starts P0 in the same heartbeat. Queue lives in `PROJECT_BACKLOG.md` Phase 3 section + ea_id_registry.csv (next-action column).
- If the queue is empty, file a Class-2 escalation comment on the parent Phase 3 issue tagging CEO — do not idle.

**Research (`7aef7a17-...`):**

- When DL-044 lifts (first V5 EA reaches Phase 7), resume the source queue and maintain ≥1 card in extraction at all times until DL-050 is superseded.
- Until DL-044 lifts, "active extraction" includes G0 backfills (D2 of QUA-660), card-format upgrades, and source-survey work — Research is not idle just because no new card is being mined.

**CEO (`7795b4b0-...`):**

- Watch both queues every heartbeat. If both empty, dispatch in this heartbeat — do not defer to the next.
- If a Class-2 escalation fires and CEO cannot dispatch (e.g. stuck on OWNER / QT / QB sign-off), file a comment on the parent Phase 3 issue naming the unblock owner + action and request CEO's own follow-up.

**Quality-Tech (`c1f90ba8-...`) / Quality-Business (`0ab3d743-...`):**

- DL-050 does not change QT/QB sign-off authority. A QT FAIL at any sub-gate is binding (charter). DL-050 only requires that the *next* EA's P0 starts in the same heartbeat the current EA's P10/G1 closes.

## Interaction with DL-044 (Research Pause)

DL-044 paused the Research source queue (no new SRC0N opens, no new card extractions) until first V5 EA reaches Phase 7. DL-050 does NOT lift DL-044.

During the DL-044 window:

- Research's "≥1 card in extraction" obligation is satisfied by the **D2 backlog** of QUA-660: backfilling G0 cards for SRC01_S03 / SRC01_S04 / SRC04_S03 to the canonical `strategy_cards/` location, and any card-format upgrades to the new `_TEMPLATE.md` schema.
- Once DL-044 lifts (first EA hits P7), DL-050 reverts Research to the active extraction queue per DL-029.

## Boundaries (unchanged by DL-050)

- T6 isolation — DL-050 governs P0..P10 (factory). T6 deploy is Phase 4 and OWNER-gated.
- Charter values + V5 hard rules — DL-050 cannot override hard rules; if no EA passes hard rules, the queue is *correctly* empty and CEO must escalate, not relax.
- DL-040 sequential operating model — one strategy active at a time globally; DL-050 says that *one* slot must be filled, not that more should be opened.
- Token-discipline throttle (DL-040 / DL-047) — DL-050 does not increase parallelism; it forbids leaving the active slot empty when work is dispatchable.

## Acceptance + revisit

- Acceptance: rule lands as DL-050 in registry; `paperclip/agents/wave_plan.md` updated to reflect "idle Pipeline-Op + idle Research = Class-2 escalation, not normal state"; this DL referenced from QUA-660 closeout.
- Revisit when: first V5 EA reaches Phase 7 (DL-044 lift); first F8 portfolio basket emerges (Phase 4 trigger); or OWNER calls a strategic pivot (Class-3 escalation, would supersede DL-050).
