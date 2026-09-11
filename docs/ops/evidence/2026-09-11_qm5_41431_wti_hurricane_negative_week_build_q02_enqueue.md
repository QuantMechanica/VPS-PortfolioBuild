# QM5_41431 WTI Hurricane Negative-Week Build And Q02 Enqueue

Date: 2026-09-11

## Outcome

`QM5_41431_wti-hurr-negweek-fade` is a new branch-only WTI D1 structural
hurricane-season sleeve. It buys only after a strictly negative immediately
completed normalized WTI week whose new-week Monday anchor falls in August,
September, or October, then exits at the next normalized week. It is not
admitted to the portfolio and makes no decorrelation claim.

## G0 And Build Evidence

- source and G0 approval: commit `0df98bb86a`
- deterministic identity/magic allocation: commit `06b18b8be8`
- source-only implementation: commit `79c80a86fe`
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings
- deterministic reference oracle: 12/12 PASS
- compile work item: `9b5e9fb8-29ed-4ce2-8a5c-dc69f28f3d14`
- compile: `COMPILE_OK`, 0 errors, 0 compiler warnings
- strict build check: PASS at
  `D:/QM/reports/framework/21/build_check_20260911_013813.json`
- EX5 SHA-256:
  `72e972ce02d727918f870be5d51f95ba64ed6c2a6236bfe53b7aec8d112b4939`

The canonical Q02 set is `XTIUSD.DWX` D1 with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and SHA-256
`71f0c70f54ddf5871b17479624aab6bb78c40b54bf092a84ad7f42ec6e70e2d6`.
The first-Q02 intake dry-run returned `ELIGIBLE` and `would_enqueue=true`.

## Paced Q02 Handoff

Five one-second CPU samples were `43.2, 45.0, 42.3, 52.4, 53.4` percent.
Their maximum, `53.4%`, remained below the exclusive `97%` backtest CPU
ceiling. Exactly one canonical Q02 canary was enqueued as pending work item
`1873db73-4c12-466a-bcd0-2ec03fbb2043` for `XTIUSD.DWX` D1. No dispatch tick
or manual backtest was run.

No `T_Live`, AutoTrading, deploy manifest, live manifest, portfolio gate, or
portfolio admission was touched.
