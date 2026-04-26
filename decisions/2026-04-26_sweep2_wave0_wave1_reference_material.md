# Decision: Sweep 2 — Wave-0/1 reference material migration

- Date: 2026-04-26
- Status: accepted
- Owner: OWNER + Claude Board Advisor
- Affected docs: `docs/ops/PAPERCLIP_OPERATING_SYSTEM_NOTION.md`, `docs/ops/EPISODE_GUIDE.md`, `docs/ops/GITHUB_REPO_PLAN.md`, `docs/ops/PROMPTS_AND_SCRIPTS_LIBRARY_INDEX.md`, `docs/ops/QUANTMECHANICA_DASHBOARD_SPEC.md`, `docs/ops/WEBSITE_RELAUNCH_PLAN.md`, `expenses/PUBLIC_EXPENSE_LOG.md`, `expenses/expenses.csv`, `branding/assets/`, `docs/ops/PHASE0_EXECUTION_BOARD.md`

## Context

Sweep 1 (commit `3898d1a`) migrated the 13 agent prompts + 4 critical V5 docs + Strategy Card Template that Wave 0 needs to hire against. Sweep 2 covers the next layer: the operational reference material that Wave 0 (CEO, CTO, Documentation-KM) and Wave 1 (DevOps) need for their first issues.

Per OWNER 2026-04-26 ("starte Sweep 2,los gehts!"), proceed with the planned 7 Notion docs + brand assets.

## Decision

Migrate as-is, with V5-aware additions where they prevent silent re-introduction of V4 problems or stale states. Specifically:

1. **6 Notion docs → `docs/ops/`** sourced byte-equivalent with V5-aware additions:
   - `PAPERCLIP_OPERATING_SYSTEM_NOTION.md` — complementary to existing laptop-version `PAPERCLIP_OPERATING_SYSTEM.md`; both kept, Documentation-KM (Wave 0) reconciles divergences
   - `QUANTMECHANICA_DASHBOARD_SPEC.md` — JSON schema corrected to 15-phase pipeline (`G0, P1, P2, P3, P3.5, P4, P5, P5b, P5c, P6, P7, P8, P9, P9b, P10`) per `PIPELINE_PHASE_SPEC.md`; complementary to laptop-version `WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md`
   - `GITHUB_REPO_PLAN.md` — current-repo-structure section appended showing what actually exists vs notional plan
   - `PROMPTS_AND_SCRIPTS_LIBRARY_INDEX.md` — current repo locations table + Sweep 3 candidates list
   - `EPISODE_GUIDE.md` and `WEBSITE_RELAUNCH_PLAN.md` migrated as-is with date/status touch-ups

2. **Public Expense Log** in two forms: human-readable Markdown at `expenses/PUBLIC_EXPENSE_LOG.md`, machine-readable CSV at `expenses/expenses.csv`. Dashboard consumes the CSV; humans read the Markdown. Closes P0-15.

3. **Brand assets** in `branding/assets/`: favicon.svg + og-image.svg (the small SVGs that runtime scripts need), plus 2000px logo PNGs (the references for image generation tasks). Mascot poses + YouTube banners + Brand Book HTML stay on Drive (read-only reference, not runtime). Closes Brand Guide § 10 question 2.

4. **Wave 0 hire is still gated** on PC1-00 (Drive `.git/` exclusion + git mutex per V4 mass-delete-incident lesson) and Paperclip install — Sweep 2 does not change those blockers. But the *material* Wave 0 needs to read on Day 1 is now in repo.

## Alternatives Considered

- **Skip the Notion-mirror duplicates** (PAPERCLIP_OPERATING_SYSTEM and QUANTMECHANICA_DASHBOARD_SPEC) since laptop-versions exist. Rejected. The laptop-versions and Notion-versions diverge in detail; both are useful inputs to Documentation-KM's reconciliation pass. Repo carries both with explicit complementary-relationship notes.
- **Inline Public Expense Log into PROJECT_CHARTER.md.** Rejected. Expense Log changes on every purchase; Charter changes on strategy pivots. Different rhythms, different audiences, separate files.
- **Migrate Sweep-3 reference scripts now.** Rejected. V4 Python + PowerShell scripts are reference for CTO + DevOps Wave-0+ work. They don't unblock Wave 0 hire; deferring keeps this commit focused.
- **Copy Brand Book HTML + Brand Guidelines DOCX into repo.** Rejected. They are read-only reference, not runtime. Drive remains canonical; repo only carries what scripts/dashboards consume at runtime.

## Consequences

- Wave 0 has all reference material in repo for Day-1 reading. Documentation-KM specifically inherits Notion-vs-repo reconciliation as a first-issue.
- The dashboard JSON-schema-15-phase correction means any consumer of the public snapshot must use the V5 phase keys, not the legacy 10-phase shorthand.
- `expenses/` folder is no longer a stub — both forms now in repo.
- `branding/assets/` populates the Brand Guide § 10 default. Dashboard render scripts can include logo without Drive mount.
- Sweep 3 (V4 reference scripts + voice samples + sub-page dispatch templates) is now the only remaining migration; not Wave-0-blocking, scheduled for after first concrete physical-VPS work (P0-21 Tick Data Manager DST verification).

## Sources

- OWNER conversation 2026-04-26 ("starte Sweep 2, los gehts!")
- `decisions/2026-04-26_sweep1_wave0_bootstrap_material.md` (Sweep 1 ADR — defines pattern this Sweep continues)
- `decisions/2026-04-26_paperclip_reality_and_phase_map.md` (Specification Density Principle)
- 7 Notion source pages enumerated in MIGRATION_LOG section
- Drive sources for brand assets enumerated in `branding/assets/README.md`
