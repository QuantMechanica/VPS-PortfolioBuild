# Phase Chain Build Result - 2026-05-19

## Built

- P3.5 work-item wiring now supplies existing P2/P3 CSV evidence to the CSR runner instead of producing `PENDING_IMPLEMENTATION`.
- P5 has a real pipeline wrapper: generate clean/stress metrics, then evaluate `p5_stress_runner.py`.
- P5 calibration input is generated per EA from measured VPS calibration evidence.
- P5b now generates Monte Carlo trial evidence, then evaluates `p5b_calibrated_noise.py`.
- P5c now generates crisis-slice rows from P5 clean/stress metrics, then runs the report-first crisis runner.
- P6 now generates `p6_seeds.csv`, then evaluates `p6_multiseed.py`.
- P7 now generates `sweep_pass_rows.csv` from P3/P2 evidence, then evaluates `p7_statval.py`.
- P8 now generates `news_matrix.csv` and validates against the available news calendar aliases (`news_calendar_2015_2025.csv` / ForexFactory export).

## Remaining Reality

The chain is now runnable without structural `PENDING_IMPLEMENTATION` for P3.5-P8. Verdicts can still be FAIL, WAITING_INPUT, or REPORT_ONLY when the underlying evidence is weak or absent.

Known engineering debt:
- P5c crisis rows are proxy rows derived from P5 stress metrics, not separate MT5 crisis-window reruns yet.
- P7 statistical inputs are conservative derived rows from P3/P2 evidence; richer PBO/DSR should be computed directly from full parameter distributions later.
- P8 mode matrix is derived from prior metrics and calendar validation; it does not yet rerun MT5 under each news mode.

These are no longer stub blockers, but they are the next quality upgrades before treating P8 PASS as deploy-grade without manual review.
