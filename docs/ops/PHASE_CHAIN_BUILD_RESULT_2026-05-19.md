# Phase Chain Build Result - 2026-05-19

Status: superseded by Q-Series hardening on 2026-05-20. See `PIPELINE_PHASE_SPEC.md` and `PIPELINE_PHASE_ID_MAP.md`.

## Built

- P3.5 work-item wiring now supplies existing P2/P3 CSV evidence to the CSR runner instead of producing `PENDING_IMPLEMENTATION`.
- P5 has a real pipeline wrapper: generate clean/stress metrics, then evaluate `p5_stress_runner.py`.
- P5 calibration input is generated per EA from measured VPS calibration evidence.
- Q07 now requires real MT5 calibrated-noise reruns. Synthetic Monte Carlo rows are diagnostics only.
- Q08 now requires real MT5 crisis-slice reruns. Report-only/proxy rows do not promote.
- P6 now generates `p6_seeds.csv`, then evaluates `p6_multiseed.py`.
- Q10 rejects proxy-only pass rows and waits for real statistical evidence.
- Q11 requires MT5 news-mode reruns plus deal replay against `news_calendar_2015_2025.csv`.

## Remaining Reality

The chain is runnable without structural `PENDING_IMPLEMENTATION` for Q04-Q11. Verdicts can still be FAIL or WAITING_INPUT when required real evidence is absent.

Known engineering debt:
- Existing database rows from the pre-hardening window can contain `P5c REPORT_ONLY`, `P6 MULTI_SEED_MIXED`, proxy P7 PASS, or P8 PASS without MT5-mode reruns. Those rows must be invalidated or rerun before claiming an honest Q11.
- Q10 still needs richer direct PBO/DSR computation from full parameter distributions.

No Q11 PASS is deploy-grade unless its artifact shows `parameters.run_mt5=true` and non-empty MT5-mode evidence.
