# V5 Restart — Scope Boundary

Created: 2026-04-26
Authority: OWNER + Claude Board Advisor
Binds: every V5 agent, every Phase 0 workstream, every migration decision
Decision source: `decisions/2026-04-26_v5_restart_clean_slate.md`

## Purpose

Codex's laptop reconstruction (`CANONICAL_LAPTOP_STATE_2026-04-25.md`) usefully captured what existed on the laptop, but blurred a critical line: it listed both *process* and *bestand* as items the VPS build "must inherit from the laptop". V5 inherits one of those, not both. This document draws the line cleanly.

## What V5 INHERITS From V4 / Laptop

### Process and rules

- The 15-phase pipeline shape (G0..P10) → `docs/ops/PIPELINE_PHASE_SPEC.md`
- Pipeline governance and change process → `docs/ops/PIPELINE_AUTONOMY_MODEL.md`
- The 12 process docs → `processes/01..12-*.md`
- Hard rules from CLAUDE.md (filesystem-is-truth, T6 isolation, no-AutoTrading, setup-vs-strategy classification, no QUAA runtime state, etc.)
- V2.1 additive gates (P3.5, P5b)
- The MT5 / Tick Data / Darwinex time conventions → `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md`
- The news-calendar seed asset (already installed at `D:\QM\data\news_calendar\`)

### Learnings (these shape V5's stricter process)

- Lane drift is a real failure mode → V5 requires evidence on the deploy lane
- Waiver creep undermines portfolio claims → V5 counts waivers explicitly
- Setup data failures must not look like strategy failures → V5 keeps `SETUP_DATA_MISSING` and `SETUP_DATA_MISMATCH` separate from PASS/FAIL
- Smoke ≠ baseline-equivalent → V5 audits use the actual trigger symbol + full BL window
- NO_REPORT must be disambiguated from EA weakness → V5 file-size-checks before any "dead EA" verdict

### Provisional defaults (V5 may revisit)

- V2.1 numerical thresholds (P2 `PF > 1.30`, `T > 200`, `DD < 12%`; P5b `>= 70%` proxy compliance; P6 5-seed set `42, 17, 99, 7, 2026`; P7 `PBO < 5%`). These are V4 inheritance, not V5 commitments. Once V5 EAs produce real distributions, the thresholds may need recalibration.

## What V5 DOES NOT INHERIT

### Strategy bestand

- The V4 locked basket (`SM_124, SM_221, SM_345, SM_157, SM_640`) — none of these enter V5 unless re-derived from new research
- The V4 outlier exclusions (`SM_890 AUDUSD, SM_890 EURUSD, SM_882 WS30`) — V5 may or may not encounter similar ideas; the V4 verdict is not portable
- Per-sleeve weights, magic numbers, set files, deploy lanes, deploy folders (`Company/VPS/V6/` etc.)
- Open V4 waivers (P5b waiver for SM_124, P6 waivers for the four sleeves, SM_221 YELLOW)
- Lane-reassignment history between V4 P5b and V4 lock

### EA framework / code

- The V4 EA framework code (Include libraries, magic-number schema implementation, set-file format conventions, risk-input definitions, EA template) — V5 builds its own. Tracked as `P0-26 Establish V5 EA framework` (CTO + Development).
- The V4 V2.1 runner stack (`Company/scripts/`, V2.1 runners, `run_news_impact_tests.py` if it exists) — V5 may port, rewrite, or replace; no automatic adoption
- The V4 deploy automation, dashboard refresh scripts, and aggregator loops

### Bestand-derived artifacts

- The V4 strategy archive (~402 historical SM_XXX HTML pages and 5 markdown specs) is reference material only, never an approved V5 Strategy Card
- The V4 set-file library
- The V4 magic-number registry

## V5 Operating Loop (the new shape)

```
V5 Research (G0)
  → V5 Strategy Card (CTO review)
    → V5 EA (built on V5 framework, P0-26)
      → V5 Backtest (P1 Build Validation)
        → V5 Pipeline (P2..P10)
          → V5 Live (post-P10 promotion via V5 deploy process)
```

Every step uses V5-native tooling. No V4 artifact participates without explicit re-derivation through G0.

## How To Read Legacy Files In This Repo

Files marked legacy (V4 / pre-restart) carry a header banner:

> **STATUS: LEGACY / ARCHIVE ONLY.** Not a V5 input. See `V5_RESTART_SCOPE_BOUNDARY.md`.

These files exist for:

- audit trail (why V5's pipeline is what it is)
- learnings reference (what failure modes V5 must guard against)
- research inspiration (themes, theses, MT5-native feasibility notes — never the parameters or the SM_ID)

They never feed V5 decisions directly.

## Enforcement

- Documentation-KM keeps this boundary current; new files that touch V4 bestand must add the legacy banner.
- CEO rejects any task framed as "import V4 SM_X into V5".
- Quality-Tech and Quality-Business reject any V5 PASS that cites a V4 receipt as evidence.
- The Codex laptop reconstruction's "must inherit" phrasing is overruled by `decisions/2026-04-26_v5_restart_clean_slate.md`.

## Open Questions That Survive The Boundary Decision

1. Are the V2.1 numerical thresholds correct for V5 EAs, or do they need recalibration once the V5 framework produces real distributions? (Quality-Tech to re-evaluate after first V5 EAs reach P2.)
2. What does the V5 EA framework look like? (P0-26 — CTO + Development.)
3. Does the V5 news-impact tooling reuse, port, or replace `run_news_impact_tests.py`? (Pending Codex Task A reply.)
4. News-rule-set compliance variants (FTMO / 5ers / no-news / news-only) — Hybrid A+C recommended. (`decisions/2026-04-25_news_compliance_variants_TBD.md`.)
