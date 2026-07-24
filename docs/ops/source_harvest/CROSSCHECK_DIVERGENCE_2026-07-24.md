# Cross-check FAILED — ledger NOT validated (2026-07-24)

Per the run's stop condition, the independent Codex control sample (26 PDFs = 20%,
seed 20260724, gpt-5.6-sol @ effort max, task `2a0ae38a`) diverged from the Claude
sweep on **10/26 PDFs = 38% > 30% threshold → run aborted at the validation gate.**
The ledger files in this directory are complete raw material but are **NOT approved
for build sequencing** until OWNER recalibrates the eligibility rubric.

## Divergence pattern (systematic, not noise)

8 of 10 divergences are one-directional: Claude ELIGIBLE vs Codex REJECTED/PARKED.
Root cause visible in the ledger itself: **51 of 97 ELIGIBLE rows have
rules_completeness=PARTIAL** (one even VAGUE). The schema as written does not bind
`eligibility` to `rules_completeness` — Claude's sweep graded "mechanizable in
principle, gaps fillable at card time" as ELIGIBLE; Codex's control graded "rules
not fully stated = not implementable as-is" as REJECTED. Both readings are
defensible → the rubric, not either model, is the defect. Exactly what the >30%
gate exists to catch.

Divergent PDFs (mine vs codex): ff_127271 THV (ELIGIBLE vs PARKED),
ff_1348734 fractals, ff_206723 deadly-accuracy, ff_416962 ema-fib,
ff_460041 dance-continues (2×ELIGIBLE vs REJECTED), ff_989445 magic-100,
ff_993524 roadmap, forexfactory_423512 momentum (each ELIGIBLE vs REJECTED),
plus 2 candidate-granularity splits (ichimoku_18242, my-ultimate-system_1259295).

## Decision needed (OWNER)

Pick the rubric, then the eligibility column gets re-graded (cheap re-pass over
existing rows; PDFs need not be re-read):
- **Option A (strict, = Codex reading):** ELIGIBLE requires rules_completeness=FULL;
  PARTIAL → new tier `ELIGIBLE_NEEDS_SPEC` (card-time parameter completion, counts
  as parked-adjacent, not build-ready). Expected result: ~45 ELIGIBLE, ~52 NEEDS_SPEC.
- **Option B (permissive, = Claude reading):** PARTIAL may be ELIGIBLE when the
  gaps are parameter-level (not structural); mark `spec_gaps` in notes. Keeps 97
  but tightens what PARTIAL means.

Recommendation: **Option A** — it matches the Q00-R2 spirit (deterministic rules
must be STATED, not inferred) and the card validator's expectations.

Codex sample artifacts: `D:\QM\reports\source_harvest_codex_sample\CODEX_SAMPLE_LEDGER.csv`
(34 rows: 16/6/12). Claude ledger: `SOURCE_LEDGER.csv` (143 rows: 97/1/45).
