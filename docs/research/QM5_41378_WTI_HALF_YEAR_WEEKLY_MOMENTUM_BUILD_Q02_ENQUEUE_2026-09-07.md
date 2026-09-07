# QM5_41378 WTI Half-Year Weekly Momentum — Build And Q02 Enqueue

`QM5_41378_wti-wmom265` is a new low-frequency structural WTI sleeve. On the
first tradable D1 bar of week `t`, it follows the strict sign of WTI's
cumulative return over completed weeks `t-26..t-5`, excludes all of
`t-4..t-1`, uses a frozen `3.5*ATR(20,D1)` stop, and exits at the next broker
week.

The mechanic is distinct from the same-source `t-1`, `t-4..t-2`, and
short-horizon agreement siblings. The peer-reviewed evidence is deliberately
carried with its adverse boundary: `CMOM26,5` is weak after factor adjustment
and loads strongly on carry and equity momentum. WTI CFD efficacy and realized
decorrelation from the certified book remain unproven; Q02 and Q09 must measure
them.

## Build Result

- Mandatory PACER audit: PASS, zero `EA_FRAMEWORK_INPUT_PINNED` findings on
  final source SHA-256
  `8d621c6f64affedd75dd61305e2828c88370513a192d96d35f5dac8e0241fed0`,
  before compile enqueue.
- Deterministic reference tests: 14/14 PASS; card schema/ML lint: PASS.
- Governed compile work item:
  `0d883e95-9a9d-440d-a7e7-55c03b2ded47`.
- Compile: `COMPILE_OK`, zero compiler errors and warnings; framework build
  check PASS.
- Binary SHA-256:
  `cc4fce1985c6ba799af47f60e30c8ea9be8b9f6b2108c8250d61d7571f3cb108`.
- The generated preset initially left `strategy_symbol` blank. The packaging
  defect was caught by the first-Q02 dry run and corrected in the setfile only;
  the audited source and compiled binary were not changed. The final preset
  binds `XTIUSD.DWX`, `RISK_FIXED=1000`, and `RISK_PERCENT=0`, with SHA-256
  `615b95008bf78117d89164a8011c4ced7cfeed5a3eb5760c2ef95db1e143b483`.

## Q02 Admission

The repeated first-Q02 dry run was eligible for the exact XTIUSD.DWX D1
fixed-risk preset. Five whole-host CPU samples were 84.297%, 88.677%, 75.034%,
87.623%, and 95.185%. The maximum was 95.185%, strictly below the binding 97%
ceiling, so the governed intake appended Q02 work item
`d4ac61bc-4b49-4eed-98ef-93b488d5e749` without a priority boost.

This handoff records enqueue only. No manual backtest or terminal action was
performed, and no Q02 verdict is claimed.

## Safety Boundary

No portfolio gate, `T_Live`, deploy/live manifest, AutoTrading, manual
backtest, optimization, terminal restart, priority boost, or live surface was
touched.
