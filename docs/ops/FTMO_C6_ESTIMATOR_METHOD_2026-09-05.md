# FTMO C-6 estimator — adopted method (OWNER-DEC-C6-ESTIMATOR-20260905 = YES)

Receipt `871cf325-3961-41b3-9543-e9b1477448e2` (Mission Control, 2026-09-05 12:42Z). Decision-bound task `adbeff65-8be8-59d4-83b0-0f81bd2ebf13`. Written 12:50Z 2026-09-05.

## What the OWNER adopted

- **C6-1 Method C6-A**: worst-of over a moving-block bootstrap plus an exact guard on the book-wide M5/Prague-day path trace captured by the exact-profile trial telemetry (`QM_FTMO_TrialTelemetry.mq5` → `ftmo_trial_telemetry.py`).
- **C6-2 Floors** as sample-size preconditions: 36 breach gauntlets, 23 P2 passes, 9 joint observations; below a floor the estimator reports LOW_SAMPLE, never a pass.
- **C6-3** Closed-P&L streams are inadmissible as input for breach and joint estimates (they cannot see intraday troughs).
- **C6-4** Disjoint-block origin = the first sealed Prague trading day of the for-record trace.

## Boundaries (unchanged by this decision)

- Contract V1 (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md`, `tools/strategy_farm/config/ftmo_probability_contract.v1.json`) keeps the C-6 gates **INERT**; its text is sealed by the ratifiable acceptance test r5 and is not edited by this decision. Activation of the gates is a separate OWNER card after the fixtures pass.
- NO-BUY stays; no purchase, no trial account, no live effect follows from this decision.

## Execution

- Exactly one implementation task: Codex Astra `ae041465` (INERT behind the contract flags; known-answer and null fixtures; evidence doc `docs/ops/evidence/2026-09-05_c6_estimator_implementation.md`).
- Claude reviews and integrates; the activation card follows with the fixture results.
