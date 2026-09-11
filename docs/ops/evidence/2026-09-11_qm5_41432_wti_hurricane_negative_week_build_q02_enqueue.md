# QM5_41432 WTI Hurricane Negative-Week Build And Q02 Enqueue

Date: 2026-09-11

## Outcome

`QM5_41432_wti-hurr-negweek-cont` is a new branch-only WTI D1 structural
hurricane-season sleeve. It sells only after a strictly negative immediately
completed normalized WTI week whose new-week Monday anchor falls in August,
September, or October, then exits at the next normalized week. It is not
admitted to the portfolio and makes no decorrelation claim.

## G0 And Build Evidence

- source and G0 approval: commit `a610107d95`
- deterministic identity/magic allocation: commit `0ee596d0cb`
- source-only implementation: commit `ca338e646b`
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings
- deterministic reference oracle: 12/12 PASS
- compile work item: `693125c7-2ccc-46e5-8041-3b440c429576`
- compile: `COMPILE_OK`, 0 errors, 0 compiler warnings
- strict build check: PASS at
  `D:/QM/reports/framework/21/build_check_20260911_033147.json`
- EX5 SHA-256:
  `7c7729cc4f512924629cf5cc2542836072fd046f45cc522df08ad4c1729da7ab`

The canonical Q02 set is `XTIUSD.DWX` D1 with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and SHA-256
`b5aa07d54f3fe8ae408ede9a15b025a35e8568c0bff7db194d48831ab4a218bf`.
The first-Q02 intake dry-run returned `ELIGIBLE` and `would_enqueue=true`.

## Paced Q02 Handoff

The first five one-second CPU samples were `87, 77, 96, 85, 90` percent. A
transient factory-mutation-lock refusal applied nothing. After the lock
cleared, five fresh samples were `45, 44, 61, 64, 80` percent. Both sample
maxima remained below the exclusive `97%` backtest CPU ceiling. Exactly one
canonical Q02 canary was enqueued as pending work item
`4c7d7b31-c837-4fdc-9070-505b72b82f97` for `XTIUSD.DWX` D1. No dispatch tick
or manual backtest was run.

No `T_Live`, AutoTrading, deploy manifest, live manifest, portfolio gate, or
portfolio admission was touched.
