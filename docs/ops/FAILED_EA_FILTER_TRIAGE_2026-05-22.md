# Failed-EA Filter Triage

Date: 2026-05-22
Task: `300b5521` (failed-EA filter-review)
Author: Claude
Plan: `docs/ops/FILTER_LIBRARY_PLAN_2026-05-22.md`

## Method

A failed EA qualifies for a thesis-driven filter rerun ONLY if BOTH hold:

- (a) it has a **real thesis** — a structural edge; AND
- (b) its failure is a **named structural weakness** that a specific declared
  filter directly addresses.

An EA with no demonstrated robust edge does not qualify — a filter cannot
manufacture an edge. No filter search: one declared filter per qualifying EA.

## Data reviewed

`work_items` pipeline history. Only EAs that reached the late gates carry a
demonstrated edge worth filtering:

- **QM5_1056** (moskowitz-tsmom-multiasset) — reached P8/Q11; PASS at P4/Q05
  (walk-forward), P5/Q06 (stress), P5b/Q07 (noise); **FAIL at P5c/Q08 Crisis
  Slices — 33 FAIL.**
- **QM5_1047** — reached P4/Q05 (walk-forward); **every P4 run FAILED**
  (286 FAIL, 0 PASS).
- All other failed EAs died at P2/P3/P3.5 — no demonstrated robust edge.

## Verdict

### QUALIFIES (1): QM5_1056 — moskowitz-tsmom-multiasset

- **Thesis:** time-series momentum (Moskowitz) — academically grounded, a real edge.
- **Demonstrated robustness:** PASSED Q05 walk-forward, Q06 stress, Q07 noise —
  genuine out-of-sample robustness, not an in-sample fluke.
- **Named structural failure:** Q08 Crisis Slices, 33 FAIL — momentum crashes
  in crisis regimes. A named, structural weakness.
- **Declared filter (one, not searched):** a regime / realized-volatility
  **crisis filter** — de-risk or flatten momentum exposure when the filter
  signals a crisis / risk-off regime. Directly targets the Q08 failure mode.
- **Acceptance for the rerun:** the filtered variant must beat the unfiltered
  QM5_1056 on Q08 *without* degrading Q05/Q07 — per the Filter Library
  robust-gate test.

### DOES NOT QUALIFY

- **QM5_1047** — reached Q05 walk-forward but failed it outright (0 PASS).
  Failing walk-forward = no demonstrated OOS robustness. A filter addresses a
  regime-specific weakness, not a strategy that does not generalise. Excluded.
- **All EAs that died at P2/P3/P3.5** — never demonstrated a robust edge; a
  filter cannot create one. This is the large majority of the ~3,350 failed
  work_items. Excluded.

## Result

Exactly **one** filter-addressable failed EA: **QM5_1056**, with one declared
filter (crisis regime/vol filter). This is the input to rerun task `af7c5668` —
which builds QM5_1056 + the crisis filter as a filter-variant and runs it
through the pipeline once the Filter Library (`573731f4`) is built.
