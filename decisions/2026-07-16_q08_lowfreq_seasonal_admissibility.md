# Q08 low-freq + seasonal admissibility for the requalified DXZ book — OWNER 2026-07-16

Status: **OWNER_RATIFIED**

## Decision

For the requalified DarwinexZero book, a sleeve is **admissible** when its only residual
Q08 non-PASS classifications are:

- `8.4_seasonal: EDGE_SOFT` and/or `8.10_regime_crisis: EDGE_SOFT` (marginal, regimes still
  profitable), and/or
- `LOW_SAMPLE` sub-gates (`8.2_dsr`, `8.8_edge_decay`, `8.9_runs`) arising from **low trade
  frequency on swing / D1 strategies** — explicitly acceptable **down to ~6 trades/year**.

OWNER statement (active session 2026-07-16): *"Low freq mit 6 Trades pro Jahr ist ok."*

These are **not merit failures** and do not block book admission.

## Consistency with existing floors

- The ratified Q02 frequency floor is **≥5 trades/year/symbol** (OWNER 2026-07-03, economics).
  6/year is **above** that floor → this decision is consistent, not a loosening.
- DL-070 precedent already accepted ~10 trades/year for swing (Q08 low-freq); this extends the
  explicit acceptable floor down to ~6/year for the requal book.

## What is NOT waived

- **Hard `FAIL`** sub-gates (genuine merit failures) still reject.
- **`INVALID`** sub-gates (e.g. `8.5_neighborhood` degenerate baseline, `8.7_pbo` INVALID) are a
  **tooling defect**, not a pass — they must be resolved by pointing the neighborhood/PBO baseline
  at the correct param-filled approved-Card set and re-running Q08. See
  `docs/research/Q08_REQUAL_COHORT_FAILSOFT_ROOTCAUSE_2026-07-16.md`.
- The 1% per-sleeve risk cap, correlation ≤0.30 (locked window), synchronized mark-to-market
  DD ≤9.5%, and the OWNER-signed freeze gate remain binding (Q6 design).

## Effect

Once the INVALID baselines are fixed and Q08 re-runs, cohort sleeves whose residual is only
EDGE_SOFT-seasonal / LOW_SAMPLE qualify. This determines the qualifying-sleeve count for the
requalified book. No runtime, preset, binary or AutoTrading state changes from recording this.
