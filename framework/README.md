# V5 EA Framework

V5 EA framework: shared MQL5 includes, EA template, magic-number registry, set-file conventions, compile + smoke harness.

Design spec: `V5_FRAMEWORK_DESIGN.md` (canonical — read this before touching anything).
Decision: `decisions/2026-04-26_v5_framework_design.md`.
Phase 0 workstream: `P0-26` in `docs/ops/PHASE0_EXECUTION_BOARD.md`.

## Status

**Design phase.** Code does not yet exist. Codex (laptop or VPS-CTO agent) implements `framework/include/`, `framework/templates/`, `framework/scripts/` against the design spec once OWNER + CTO confirm the open questions in `V5_FRAMEWORK_DESIGN.md` § Open Questions.

## Layout

```
framework/
  V5_FRAMEWORK_DESIGN.md   # the spec
  README.md                # this file
  include/                 # shared .mqh modules
  templates/               # EA + chart + setfile templates
  EAs/                     # one folder per V5 EA (QM5_NNNN_<slug>/)
  registry/                # magic + ea_id allocation
  scripts/                 # PowerShell compile + smoke + validation
  conventions/             # markdown specs for set files, naming, logs, errors
  build/                   # compile output (gitignored)
  tests/                   # smoke + unit test EAs
```

## Usage (once implemented)

To build a new V5 EA:

1. Research writes a Strategy Card → `strategy-seeds/cards/QM5_NNNN_<slug>_card.md`
2. CEO + CTO allocate `ea_id` → row in `framework/registry/ea_id_registry.csv`
3. Copy `framework/templates/EA_Skeleton.mq5` to `framework/EAs/QM5_NNNN_<slug>/QM5_NNNN_<slug>.mq5`
4. Fill in strategy logic
5. `framework/scripts/compile_one.ps1 -EAPath ...` must pass strict
6. `framework/scripts/run_smoke.ps1 -EAId NNNN ...` runs P1 Build Validation
7. Continue through pipeline per `docs/ops/PIPELINE_PHASE_SPEC.md`

## Inheritance From V4

`V5_FRAMEWORK_DESIGN.md` § "What V5 Explicitly Does NOT Inherit From V4" enumerates the boundary. Briefly:

- **Kept:** `magic = ea_id * 10000 + symbol_slot`; dual `RISK_PERCENT` / `RISK_FIXED` contract; evidence-first markdown receipts
- **Rebuilt:** every shared library (V4 had none — `Company/Include` was absent), set file format, logger, news-impact tooling, EA structure, naming
- **Discarded:** SM_XXX namespace, V4 deploy folder layout, V4 set files, V4 magic-number assignments
