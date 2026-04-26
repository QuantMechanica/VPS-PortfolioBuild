# Decision: Sweep 1 — Wave-0 bootstrap material migration

- Date: 2026-04-26
- Status: accepted
- Owner: OWNER + Claude Board Advisor
- Affected docs: `paperclip-prompts/` (new folder, 14 files), `docs/ops/PROJECT_CHARTER.md`, `docs/ops/RESEARCH_METHODOLOGY_V2.md`, `docs/ops/CODEX_AUDIT_V5_UPGRADE_PLAN.md`, `docs/ops/PAPERCLIP_V2_COMPANY_DESIGN.md`, `strategy-seeds/cards/_TEMPLATE.md`, `docs/ops/PHASE0_EXECUTION_BOARD.md`

## Context

Per OWNER 2026-04-26 direction ("Paperclip soll das ja auch als Basis verwenden, wir werden ihm das dann selbst zum Durcharbeiten, Rollenbilden, etc. füttern"), Wave 0 needs the Paperclip prompts and supporting V5 hub material in repo before hire. Phase 0 acceptance gate (per Notion `Phase 0 Execution Board`) requires `paperclip-prompts/*.md` present. Codex Audit (2026-04-21) named "single canonical export path into Git" for prompts as an open contradiction.

Sweep 1 closes that gap: 13 agent prompts + 4 critical Notion docs + Strategy Card Template. Sweep 2 + 3 follow with reference material (V4 scripts, brand assets, archive HTML).

## Decision

Migrate as-is, with V5-aware additions where they prevent silent re-introduction of V4 problems. Specifically:

1. **13 paperclip-prompts/*.md** sourced byte-equivalent from Notion sub-pages of `Paperclip V2 Company Design`. CTO, DevOps, Pipeline-Operator, Quality-Tech, Development, Observability-SRE, LiveOps prompts received targeted V5-aware augmentations (V5 framework references, Friday Close, ENV-mode enforcement, 4-module Modularity, ML ban, sub-gate calibration ownership, stale-`index.lock` watch, P10 Shadow Deploy detail). Each prompt's V1→V5 changes table records the deviation explicitly. Documentation-KM (Wave 0) can reconcile back to Notion.

2. **4 critical docs** mirror Notion canonical pages. PROJECT_CHARTER, RESEARCH_METHODOLOGY_V2, CODEX_AUDIT_V5_UPGRADE_PLAN, PAPERCLIP_V2_COMPANY_DESIGN. CODEX_AUDIT and PAPERCLIP_V2_COMPANY_DESIGN have appended 2026-04-26 status updates (resolved-Notion-contradictions, repo prompt-file index).

3. **Strategy Card Template** authored from RESEARCH_METHODOLOGY_V2 § Step 2 + V5 Hub Fragenkatalog (4-module Modularity, ML ban, Friday Close compatibility, Allowability checklist). 14 sections cover source through pipeline history.

4. **Repo path is now canonical for prompt source-of-truth** per Codex Audit § Immediate Next Action 3. Notion remains synced for browsing; deployed Paperclip prompt is authoritative for the running agent; this repo file is the version-controlled history.

5. **Wave 0 reads this as basis and works it out itself.** Per OWNER position, Paperclip is not a passive consumer; it reviews, adapts, and role-forms before activation. The Specification Density Principle (`CLAUDE.md`) holds: prompts pin the constraints (hard rules, V1-V5 changes), interior shape stays editable.

## Alternatives Considered

- **Migrate prompts byte-identical with no V5-aware additions.** Rejected. Some V4 prompts reference scripts that don't exist (`full_baseline_scan.py`), Notion typos for "OWNER" vs "Fabian" inconsistency, and lack the V5 framework hard rules. Augmenting at migration is cleaner than waiting for Wave 0 to discover and fix.
- **Wait until Paperclip is installed and let Wave 0 author from scratch.** Rejected. Wave-0 needs *something* to be hired into. Authoring from scratch loses the V1→V5 changes audit trail in the existing prompts.
- **Migrate only the 4 Wave-0 prompts.** Rejected. Wave 1+ hires need their prompts ready when triggered (DevOps + Pipeline-Operator on T1-T5 install, etc.). Stage all 13 now; Wave 0 can refine.
- **Embed Strategy Card Template inside RESEARCH_METHODOLOGY_V2.md.** Rejected. Template is operationally distinct — Research uses it as a fill-in form, not a reference doc. Separate file lets Research copy + fill cleanly.

## Consequences

- `paperclip-prompts/` folder is now the canonical source for Paperclip agent prompts. Future edits go there with ADR justification.
- Wave 0 hire is now unblocked on Paperclip-side material. Remaining blockers: PC1-00 (Drive `.git/` exclusion + git mutex) and Paperclip installation itself.
- Documentation-KM (Wave 0 hire) inherits the responsibility to keep Notion synced with repo. Repo wins on conflict per CLAUDE.md.
- The Strategy Card Template makes Research's first-real-deliverable shape concrete. CEO can approve the first source knowing what the deliverable looks like.
- Codex Audit's "Immediate Next Action 3" (export 13 prompts to `paperclip-prompts/`) is closed.

## Sources

- OWNER conversation 2026-04-26
- Notion `Paperclip V2 Company Design` and 13 sub-pages
- Notion `Project Charter`, `Research Methodology V2`, `Codex Audit - V5 Upgrade Plan`
- `decisions/2026-04-26_paperclip_reality_and_phase_map.md` (Specification Density Principle)
- `decisions/2026-04-26_v4_basis_framework_patterns_and_open_items.md` (V4 = V5 basis framing)
- `framework/V5_FRAMEWORK_DESIGN.md` (target of CTO + Development prompts)
- `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` (V1→V5 changes basis)
