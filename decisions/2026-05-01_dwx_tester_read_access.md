# ADR: DWX Tester Read-Access Failure (DL-054 Gate 1)

Date: 2026-05-01  
Status: Accepted (for D2 closeout evidence)  
Issue: QUA-686 (parent QUA-684 D2)

## Context

`hourly_2026-04-27.log` shows verifier rows where ~21 symbols report `bars_one_shot=0`, `bars_one_shot_err=(-2, 'Terminal: Invalid params')`, and `bars_drift=-100,000`, while the readiness report from the same run stamped `OVERALL=READY`.

## Decision

1. Gate 1 evidence is produced per symbol at `D:/QM/reports/setup/dwx_gate1_verify_2026-05-01.csv`.
2. `T1_READINESS_REPORT.md` must be derived from Gate 1 outcomes and cannot report READY when any symbol is FAIL/UNAVAILABLE.
3. For 2026-04-27 evidence set, overall readiness is `NOT_READY`.

## Root-Cause Findings

1. Readiness logic gap: historical readiness report did not incorporate verifier FAIL signatures (`FAIL_tail_*`, `bars_one_shot=0`, `bars_drift=-100,000`).
2. Verifier one-shot bars read path: `copy_rates_range(...)` on full span returned `Invalid params` for affected symbols; this is a read-path/runtime behavior, not proven write-path corruption by itself.
3. Evidence coverage gap: 15 symbols had no verifier row in the canonical log segment used for Gate 1 matrix, so they must be marked UNAVAILABLE rather than inferred PASS.

## Alternatives Considered

- Mark missing verifier rows as PASS from symbol existence/spec checks: rejected (violates DL-054 Gate 1 evidence standard).
- Ignore `bars_one_shot=0` when chunked/from-pos reads exist: rejected for D2 because DL-054 explicitly flags this signature.

## Remediation

1. Keep Gate 1 CSV emission in `infra/scripts/dwx_hourly_check.py` and enforce pre-P2 checks from CSV outcomes.
2. Run a fresh verify cycle after WS30 staging files are restored; regenerate Gate 1 CSV and readiness report from that run.
3. Pipeline-Operator + CTO co-sign closeout only after all 36 symbols are PASS or explicitly UNAVAILABLE with reason.

## Evidence

- `D:/QM/reports/setup/dwx_gate1_verify_2026-05-01.csv`
- `D:/QM/reports/setup/T1_READINESS_REPORT.md`
- `D:/QM/mt5/T1/dwx_import/logs/hourly_2026-04-27.log`
- `C:/QM/repo/docs/ops/QUA-686_GATE1_READ_ACCESS_SUMMARY_2026-05-01.json`

## Addendum (2026-05-01, post-merge)

Authoritative root-cause and remediation runbook were finalized in:

- `C:/QM/repo/docs/ops/QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md`
- `C:/QM/repo/docs/ops/QUA-684_D2_BAR_COMPILE_RUNBOOK_2026-05-01.md`
- `C:/QM/repo/framework/scripts/mt5/Compile_Custom_Bars_QM.mq5`

This ADR remains valid as D2 evidence framing; execution-critical next step is the GUI-triggered bar compilation run on T1, followed by fresh `verify_import.py` Gate 1 CSV regeneration and T1→T2..T5 propagation.
