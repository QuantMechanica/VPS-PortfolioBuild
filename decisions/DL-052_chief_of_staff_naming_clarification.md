# DL-052 — Chief-of-Staff Naming Clarification

- **Date:** 2026-05-01
- **Author:** CEO (`7795b4b0-…`)
- **Authority basis:** [QUA-665](/QUA/issues/QUA-665) D2 + DL-017 broadened CEO authority (internal process choices).
- **Scope:** terminology only. No org-chart change, no hiring authority change.
- **Related:** [DL-048](./2026-05-01_roster_cleanup_and_cos_retire.md) (retired the unauthorized mid-phase CoS), `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` (frozen Wave-6 founder-comms plan).

## Decision

The label "Chief of Staff" has been used in this repo for two different roles. They are not the same; do not collapse them. From now on, use the bracketed disambiguator on every reference:

1. **Chief of Staff [Wave-6 / founder-comms]** — OWNER-frozen plan in `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`. Status: **deferred**. Trigger: OWNER explicitly says "now build founder-comms". Scope: founder-comms drafting, narrative continuity, OWNER-facing voice. Not yet hired; no agent ID.

2. **Chief of Staff [OS-Controller / mid-phase]** — coordination-internal variant retired by DL-048 (agent `bf24c2ae-…`, terminated 2026-05-01). Original scope: org-chart maintenance, weekly bottleneck review, token controller, hire recommendations. Status: **retired** (was unauthorized hire). Re-hire requires a fresh DL-NNN, OWNER directive, and 7+ day evidence per DL-048 § "Future re-hire conditions".

## Binding rule

When writing a comment, DL, prompt, or any other artifact that references a Chief-of-Staff role:

- If the context is OWNER-facing narrative / podcast / public communication — say **"Chief of Staff [Wave-6 / founder-comms]"** or just **"founder-comms CoS"**.
- If the context is internal routing / org-chart / token-budget / weekly bottleneck — say **"OS-Controller"** (no "CoS" abbreviation), or explicitly **"Chief of Staff [OS-Controller, retired]"** when referencing the retired hire.
- Bare "Chief of Staff" without a disambiguator is forbidden in new artifacts effective 2026-05-01.

Existing artifacts (DL-048, PHASE_FINAL_FOUNDER_COMMS.md, org_chart.md) are not retroactively rewritten — they are unambiguous in context. The rule applies to new authoring.

## Out-of-scope

- Does not authorize a re-hire of either variant.
- Does not change Wave-6 deferral.
- Does not change DL-048's retirement of the OS-Controller agent.

## Memory

This DL adds one durable lesson to CEO memory:

- **Same label, different role = compounding ambiguity.** When two distinct roles share a name, force the disambiguator at the language level, not at "everyone should remember which one."

## References

- [QUA-665](/QUA/issues/QUA-665) D2
- [DL-048](./2026-05-01_roster_cleanup_and_cos_retire.md) — retirement record
- `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` — frozen Wave-6 plan
- `paperclip/governance/org_chart.md` § Wave 2-6 trigger table
