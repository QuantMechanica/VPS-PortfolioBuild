# QM5_41430 WTI Hurricane Positive-Week Build And Q02 CPU Hold

Date: 2026-09-11

## Outcome

`QM5_41430_wti-hurr-posweek-cont` is a new branch-only WTI D1 structural
hurricane-season sleeve. It buys only after a strictly positive immediately
completed normalized WTI week whose new-week Monday anchor falls in August,
September, or October, then exits at the next normalized week. It is not
admitted to the portfolio and makes no decorrelation claim.

## G0 And Build Evidence

- source and G0 approval: commits `24eb09239f` and `25e7f91498`
- source-only implementation: commit `6a4653d56e`
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings
- deterministic reference oracle: 12/12 PASS
- compile work item: `3978c46b-db15-4c26-82c3-c3a380444080`
- compile: `COMPILE_OK`, 0 errors, 0 warnings
- strict build check: PASS at
  `D:/QM/reports/framework/21/build_check_20260911_002545.json`
- EX5 SHA-256:
  `047af04c83e60dda72350efbc75954ce41bdac1522c4abab32fd855bacc507b8`

The canonical Q02 set is `XTIUSD.DWX` D1 with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and SHA-256
`039068ecde4bb9a6c558874710d550fb0824bb142901e746f6527c8482c076f5`.
The first-Q02 intake dry-run returned `ELIGIBLE` and `would_enqueue=true`.

## Binding CPU Refusal

The fresh one-second samples were `98.64, 92.21, 89.26, 91.90, 82.13` percent.
Their maximum, `98.64%`, breached the exclusive `97%` backtest CPU ceiling.
Q02 was therefore not enqueued. No backtest, `T_Live`, AutoTrading, deploy
manifest, live manifest, portfolio gate, or portfolio admission was touched.
