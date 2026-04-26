# Decision: V4 = V5 basis (framing correction) + framework patterns encoded + open-items audit

- Date: 2026-04-26
- Status: accepted
- Owner: OWNER + Claude Board Advisor
- Affected docs: `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`, `lessons-learned/2026-04-20_*.md`, `framework/V5_FRAMEWORK_DESIGN.md`, `docs/ops/PHASE0_EXECUTION_BOARD.md`, `docs/ops/V5_SELF_REVIEW_2026-04-26.md`, `PROJECT_BACKLOG.md`

## Context

OWNER clarified on 2026-04-26 (night) that earlier framing of V4 as "legacy" was too hard. The accurate model:

- **V4 strategy bestand** (specific SM_XXX sleeves, magic numbers, set files, deploy folders) does NOT carry into V5. (This part of the earlier ADR `2026-04-26_v5_restart_clean_slate.md` stands.)
- **V4 framework patterns** (Friday Close, BT=Fixed/Live=Percent risk convention, .DWX discipline, Model 4, magic schema, Enhancement Doctrine, Darwinex-native data only, 4-module Modularity, gridding 1%-cap, ML ban) ARE the V5 basis. Paperclip professionalizes them, not redesigns from scratch.
- **V4 learnings** (22 entries KEPT/CHANGED/DISCARDED in Notion `Learnings Archive`) ARE the V5 basis. They explain *why V5 is the way it is*.
- **V4 incident learnings** (mass-delete 2026-04-20, file-deletion policy) are the basis for V5's safety architecture.

OWNER also asked for a critical self-review with weak items explicitly marked open.

## Decision

1. **Migrate V4 learnings as V5 basis**, not legacy archive:
   - `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` — 22 entries with explicit framing as V5 basis
   - `lessons-learned/2026-04-20_mass_delete_incident.md` — byte-identical from Drive
   - `lessons-learned/2026-04-20_file_deletion_policy_v1.md` — byte-identical from Drive (V5 needs the same policy)
   - Carry the mass-delete root cause forward as a Phase-1 first task (PC1-00: Drive `.git/` exclusion + git mutex pattern) so the same incident does not recur on VPS

2. **Encode V4 framework patterns in `V5_FRAMEWORK_DESIGN.md`** as binding code-level rules (not just prompt-rules):
   - Friday Close as a default exit reason with broker-time cut-off
   - Risk-Mode Convention enforced via set-file ENV (mismatch = `EA_INPUT_RISK_MODE_MISMATCH` hard-fail)
   - 4-module Modularity (No-Trade / Entry / Management / Close) as the framework boundary every EA implements against
   - Strategy allowability: gridding allowed with 1%-cap, scalping allowed with mandatory P5b stress, ML forbidden with build-check enforcement
   - Input parameter groups mandatory: `QuantMechanica V5 Framework`, `Risk`, `News`, `Friday Close`, `Strategy`

3. **Fix PHASE0 numbering drift** with Notion-canonical Phase 0 Board:
   - P0-21 restored to Notion-canonical "Verify Tick Data Manager DarwinexZero GMT/DST settings" (the OWNER's current active task)
   - My earlier reconstruction tasks renumbered to P0-22..P0-31
   - Repo PHASE0 board now matches Notion P0-21 numbering, while extending to P0-31 with V5-Reconstruction work that Notion does not have

4. **Add "Open / Weak Items" section to `PROJECT_BACKLOG.md`** enumerating 20 known weaknesses grouped CRITICAL / HIGH / MEDIUM / LOW. Critical ones flagged: Drive-sync vs `.git/` (mass-delete class), Custom Tick Data not verified, calibration JSON not measured, no `.git/` exclusion documented for VPS Drive setup.

5. **Write `V5_SELF_REVIEW_2026-04-26.md`** as a one-shot honest critical pass with explicit acknowledgment of self-bias and a list of unknowns that need empirical validation.

## Alternatives Considered

- **Re-write the V5 clean-slate ADR (`2026-04-26_v5_restart_clean_slate.md`) wholesale.** Rejected. That ADR's strategy-bestand stance is correct. The lesson-side framing was where the drift happened; correcting it via the V4 learnings archive header + framework basis section is cleaner than rewriting an ADR after the fact.
- **Leave `V4_LEARNINGS_ARCHIVE` Notion-only.** Rejected. CLAUDE.md source order says repo wins; if an artifact is referenced as V5 basis it must live in repo.
- **Fold V4 patterns into Specification Density Principle as "less constraint = more Paperclip freedom".** Rejected. Friday Close, BT/Live convention, ML ban etc. are HARD constraints — Paperclip professionalizes inside them, not redefines them. They belong as code-level rules with build-check enforcement, not as Wave-0-discretion items.
- **Skip the self-review.** Rejected. OWNER asked for it explicitly. Self-bias is real but documenting unknowns + recommending empirical next-actions is still better than not reviewing.

## Consequences

- V5 docs now consistently frame V4 as basis (not legacy) where pattern-inheritance applies; strategy bestand framing unchanged
- Framework spec is no longer "V5 invents from scratch" — it's "V5 codifies V4 best practice with build-check enforcement"
- PC1-00 (Drive `.git/` exclusion) is now Phase 1's first task — closes a real V4 risk before Wave 0 starts writing
- `PROJECT_BACKLOG.md` Open Items section is the new place to track risk/gap items, refreshed every commit
- `V5_SELF_REVIEW_2026-04-26.md` is one-shot; future reviews are by Codex at phase boundaries (per `ORG_SELF_DESIGN_MODEL.md` cadence)
- Notion drift acknowledged: PHASE0 board in repo extends Notion's; Pipeline Design page in Notion superseded but not rewritten. Documentation-KM (Wave 0) reconciles.

## Sources

- OWNER conversation 2026-04-26 (night session)
- Notion `Learnings Archive — What We Keep vs. Change`
- Notion `Phase 0 Execution Board`
- Notion `QuantMechanica — VPS Portfolio Build V5` (V5 Hub) — "Input Fabian" section with Friday Close + 4-module Modularity + Gridding rule + ML stance
- Notion `CTO Agent — System Prompt` — V5-aligned hard rules
- Drive `Company/Learnings/2026-04-20_mass_delete_incident.md`
- Drive `Company/Policy/file_deletion_policy.md`
- Drive `Company/scripts/README_V2.1_RUNNERS.md`
- `decisions/2026-04-26_v5_restart_clean_slate.md` (related ADR — strategy-bestand boundary stands)
- `decisions/2026-04-26_v5_framework_design.md` (extended by today's framework additions)
- `decisions/2026-04-26_v5_sub_gate_reconstruction.md`
