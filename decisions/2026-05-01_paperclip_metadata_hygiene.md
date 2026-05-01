# DL-049 — Paperclip Company Metadata Hygiene

> Renumbered 2026-05-01 from DL-036 to DL-049. Original commit `31ffb43d` collided with the prior DL-036 (`2026-04-28_ea_review_gate.md`, recorded under QUA-301). Per registry rule, this entry materialises at DL-049 alongside its DL-047 (heartbeat rebalance) and DL-048 (roster cleanup) siblings under QUA-639.

- **Date:** 2026-05-01
- **Author:** CEO (`7795b4b0-...`)
- **Approver:** OWNER directive (QUA-639 wake comment) + DL-031 (Projects formalization + routing convention).
- **Authority basis:** DL-031 (CEO unilateral on project routing) + DL-023 (operational class).
- **Status:** EXECUTED 2026-05-01.
- **Related:** QUA-639 D5.

## Decision

Two minimal Paperclip metadata patches, executed in this heartbeat:

1. **Goal `4662e91e-8e9b-458e-9383-b1f67751965b`** — `description` field was `null`. Filled from `paperclip/company/company_card.md` § Mission (12-month horizon): "Build-in-public quant research factory; portfolio of mechanical trading strategies. 12-month mission: ship a portfolio of low-volume, high-quality mechanical EAs trading independent edges across FX, indices, energy, and crypto, hosted on the QuantMechanica VPS factory (T1-T5) with T6 reserved for live deploy. Public artefacts (Strategy Cards, decision log, episode pack) ship under the QuantMechanica brand."
2. **Project `26cdd201-24a8-446d-93c3-34a7012a8b76` (Portfolio Factory V5 umbrella)** — `goalIds` field was `[]`. Set to `["4662e91e-8e9b-458e-9383-b1f67751965b"]`.

The archived "Onboarding" project's stale goal reference is left untouched per the directive (cosmetic, no functional impact).

## Acceptance

- `GET /api/goals/4662e91e-...` returns `description` length 409 (verified post-PATCH).
- `GET /api/projects/26cdd201-...` returns `goalIds: ["4662e91e-..."]` (verified post-PATCH).

## Why this is one-line metadata, not a structural decision

DL-031 already formalised goals/projects/issues hierarchy and routing. This DL is the cleanup tail: bringing the underlying Paperclip records into line with what DL-031 says they should look like. No routing rule changes; no project shape changes; no goal-tier outcome changes.

## Cross-references

- Parent directive: QUA-639, `docs/ops/CEO_DIRECTIVE_PHASE2_CLOSE_2026-05-01.md` D5
- Routing convention: DL-031 (`DL-031_projects_formalization_and_routing_convention.md`)
- Mission text source: `paperclip/company/company_card.md` § Mission (12-month horizon)
