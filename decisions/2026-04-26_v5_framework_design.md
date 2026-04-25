# Decision: V5 EA framework design

- Date: 2026-04-26
- Status: design accepted, implementation pending sign-off on open questions
- Owner: CTO + Development (implementation), OWNER (acceptance)
- Spec: `framework/V5_FRAMEWORK_DESIGN.md`
- Affected docs: `framework/README.md`, `docs/ops/PHASE0_EXECUTION_BOARD.md` (P0-26), `docs/ops/PIPELINE_PHASE_SPEC.md`

## Context

V5 starts with no EA framework (`decisions/2026-04-26_v5_restart_clean_slate.md`, `docs/ops/V5_RESTART_SCOPE_BOUNDARY.md`). Codex's V4 inventory (2026-04-26) confirmed the V4 codebase **had no shared library** — `Company/Include` was absent, every V4 EA was self-contained, and the V2.1 runner guide referenced scripts that did not exist on disk. That is the root cause of three V4 failure modes V5 must eliminate:

1. Magic-number arithmetic duplicated per EA → real collisions visible in V4 `Company/Results`
2. Risk sizing duplicated per EA → unreviewable risk posture
3. Doc/code drift → runner guide describing tools that were never written (`run_news_impact_tests.py` itself does not exist)

The framework decision is therefore not optional — V5 ships a single shared framework or the V4 failure modes return.

## Decision

Adopt `framework/V5_FRAMEWORK_DESIGN.md` as the V5 EA framework spec. Codex implements per § Implementation Order once OWNER + CTO confirm the open questions in that document.

### What V5 keeps from V4 (verbatim)

- Magic-number formula: `magic = ea_id * 10000 + symbol_slot`
- Dual risk mode: `RISK_PERCENT` and `RISK_FIXED`, exactly one non-zero
- Evidence-first markdown receipts under `D:\QM\reports\`

These are kept because Codex's inventory marked all three as "design choices V5 might want to keep" *and* because they were the V4 elements that worked — magic collisions in V4 came from missing registry validation, not from the formula.

### What V5 redesigns

- Shared include library (V4 had none) — 8 modules under `framework/include/`
- Magic registry as a CSV with hash baked into the EA binary at compile time
- Set file format with mandatory header comment block + schema validator
- JSON-line structured logger (V4 used freeform `Print`)
- News filter as a first-class include with mode enum that already accommodates the FTMO/5ers compliance variants from `decisions/2026-04-25_news_compliance_variants_TBD.md`
- Kill-switch as a first-class include with three independent kill paths
- DST-aware time helper that does not rely on broker server clock
- TradeContext wrapper that classifies broker errors against a named taxonomy
- EA template that compiles cleanly with the framework before any strategy logic
- Compile + build-check + smoke harness as committed PowerShell scripts

### What V5 discards from V4

- `SM_XXX` namespace → V5 uses `QM5_NNNN_<slug>` (ea_id range 1000-9999, leaving 1-999 forever as V4)
- V4 set file format (lacked schema validation)
- V4 logger format (was freeform)
- V4 deploy folder layout (`Company/VPS/V6/`)
- V4 hand-orchestrated P8 workflow

## Alternatives Considered

- **Port V4 EAs into V5 with a thin shim layer.** Rejected. Codex confirmed there is no `Company/Include` to start from — every "port" would be a rewrite anyway, and the V4 EAs would arrive without their lessons-learned context.
- **Skip the framework entirely; let each V5 EA self-contain.** Rejected. That is V4's failure mode literally repeated.
- **Use a third-party MQL5 framework (e.g. CTrade extensions, MQL5 community libs).** Rejected for V5 day-1 — adds an external dependency and supply-chain risk to a project whose first hard rule is filesystem-is-truth. May reconsider per-module later (e.g. for backtest-statistics computation) once the V5 framework's own surface is stable.
- **Folder-flat layout (all EAs in one directory) vs. one folder per EA.** Folder-per-EA chosen for grep-ability and to keep set files + docs adjacent to their EA.
- **Single rotating logger file vs. per-EA log file.** Per-EA chosen for grep-ability and to avoid lock contention when multiple EAs run on the same terminal.

## Consequences

- Repo gets `framework/` folder with design + README; code arrives in subsequent Codex commits.
- `P0-26` is the active Phase 0 workstream once `P0-25` closes (which it now has).
- No V5 strategy EA can be built until `framework/V5_FRAMEWORK_DESIGN.md` § Implementation step 14 (smoke regression gate) passes.
- Quality-Tech reviews the full framework before first V5 strategy build.
- The 6 open questions in the design doc need OWNER + CTO confirmation before Codex starts coding.
- News-compliance Hybrid A+C architecture (`decisions/2026-04-25_news_compliance_variants_TBD.md`) is implemented natively in `QM_NewsFilter.mqh` rather than retrofitted later.
- Sub-gate parameters (P5/P5b/P6/P7/P10) are still TBD — Quality-Tech owns first author pass once the framework produces the first V5 EA distributions. The framework explicitly does not bake in V4 numerical thresholds.

## Sources

- `framework/V5_FRAMEWORK_DESIGN.md`
- `decisions/2026-04-26_v5_restart_clean_slate.md`
- `docs/ops/V5_RESTART_SCOPE_BOUNDARY.md`
- Codex pack: `Phase0_Migration_Pack_2026-04-25/v4_framework_inventory.md` (laptop)
- Codex pack: `Phase0_Migration_Pack_2026-04-25/news_impact_tooling_location_report.md` (laptop)
- Codex pack: `Phase0_Migration_Pack_2026-04-25/pipeline_spec/MANIFEST.md` (laptop)
