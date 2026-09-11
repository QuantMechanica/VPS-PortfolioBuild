# QM5_41433 WTI Hurricane Positive-Week Reversion Build And Q02 Enqueue

Date: 2026-09-11

## Outcome

`QM5_41433_wti-hurr-posweek-fade` is a new branch-only WTI D1 structural
hurricane-season sleeve. It sells only after a strictly positive immediately
completed normalized WTI week whose new-week Monday anchor falls in August,
September, or October, then exits at the next normalized week. It is not
admitted to the portfolio and makes no decorrelation claim.

## G0 And Build Evidence

- source and G0 approval: commit `691dbab289`
- deterministic identity/magic allocation: commit `117105b0aa`
- source-only implementation: commit `8bc54b5c9a`
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings
- deterministic reference oracle: 12/12 PASS
- compile work item: `65fa5ff5-a729-467d-842e-1d654fb5dc43`
- compile: `COMPILE_OK`, 0 errors, 0 compiler warnings
- strict build check: PASS at
  `D:/QM/reports/framework/21/build_check_20260911_040948.json`
- EX5 SHA-256:
  `4773ccca368b7e481bc7f9c85db4a5626da3acaa82401845e5f88f3ce614a558`

The compile worker reported three nonfatal card-discovery warnings and
regenerated `strategy_symbol` empty. The first Q02 intake dry-run refused
`empty_strategy_values` and applied nothing. The canonical set was repaired to
the card-bound `XTIUSD.DWX`; the second dry-run returned `ELIGIBLE` with
`would_enqueue=true`. The accepted set is D1 with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and SHA-256
`ff272e3fbf81831ac25ebe1b85a7eff5fd03998401edad405c27836ff2b88b60`.

## Paced Q02 Handoff

Five one-second whole-host CPU samples were `93.7, 87.9, 95.2, 92.3, 88.5`
percent. The 95.2% maximum remained below the exclusive 97% backtest CPU
ceiling. Exactly one canonical Q02 canary was enqueued as work item
`06341514-697d-44c5-b675-734ef0c355dc` for `XTIUSD.DWX` D1. No dispatch tick
or manual backtest was run, and no second enqueue was attempted.

No `T_Live`, AutoTrading, deploy manifest, live manifest, portfolio gate, or
portfolio admission was touched.
