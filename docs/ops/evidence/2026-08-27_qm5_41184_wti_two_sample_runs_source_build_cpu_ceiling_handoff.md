# QM5_41184 WTI Two-Sample Runs — Source Build / CPU-Ceiling Handoff

Date: 2026-08-27  
Branch: `agents/board-advisor`  
Outcome: `SOURCE_BUILD_COMMITTED_Q02_NOT_ENQUEUED_CPU_CEILING`

## Delivered

- New non-duplicate direct-WTI structural sleeve: ten completed month ends,
  fixed older/newer blocks of five, strict pooled O/N membership runs, and
  newer-block median continuation at the single locked `R<=6` boundary.
- G0-approved card, source packet, exact EA/strategy identity, slot-zero magic
  `411840000`, generated resolver row, V5 `.mq5`, SPEC, one D1 backtest-only
  `RISK_FIXED=1000` setfile, and pure reference suite.
- Source/build commits: `fb7ef4580`, `ec0b7413f`, `34484b115`, and
  `1dcf96924`.

An exhaustive pre-build enumeration caught and transparently corrected the
initial density-table transcription before compile or any market result. The
correct distribution for runs 2–10 is
`2,8,32,48,72,48,32,8,2`; `R<=6` admits 162/252 states, split 81 BUY / 81
SELL, for a 7.714 decisions/year random-rank prior. Receipt:
`artifacts/qm5_41184_prebuild_runs_density_enumeration_20260827.json`.

## Validation

- Card schema/banned-ML lint: PASS.
- Pure reference tests: 11/11 PASS.
- SPEC validator: PASS.
- Build guardrails: PASS, no findings.
- Resolver/guardrail pytest group: 36/36 PASS.
- Resolver regeneration dry-run: 17,933 kept, zero dropped; no active magic
  collision.
- Canonical pre-allocation dedup: CLEAN across the recorded registry/card/wiki
  inventory.
- Strict compile/Q01: not run. The live-factory guard refused the ad-hoc
  build-check path before invoking a compiler; no retry was attempted.

Machine-readable evidence:
`artifacts/qm5_41184_wti_two_sample_runs_source_build_cpu_ceiling_20260827.json`.

## Capacity Stop And Pipeline State

Fresh one-second CPU samples were `100.00, 99.81, 100.00, 99.90, 100.00%`:
average 99.94%, maximum 100.00%, versus the configured 97% ceiling. Six
`metatester64` and eight `terminal64` processes were active.

Per the mission stop rule, no governed compile item and no Q02 row were
created. There is no `.ex5`; Q01 remains pending and Q02 remains
`NOT_ENQUEUED_Q01_PENDING_AND_CPU_CEILING`. No backtest, terminal control,
AutoTrading change, `T_Live` change, live-manifest change, portfolio-gate
change, or portfolio-admission change occurred.

## Resume Condition

After capacity falls below the governed ceiling, enqueue exactly one governed
compile for `QM5_41184_wti-mww-runs-shift-tr`. Require hash-bound strict
0-error/0-warning compile and Q01 PASS, then enqueue exactly one
`XTIUSD.DWX` D1 `RISK_FIXED` Q02 baseline.
