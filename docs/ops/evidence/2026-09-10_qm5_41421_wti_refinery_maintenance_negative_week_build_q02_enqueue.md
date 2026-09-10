# QM5_41421 WTI Refinery-Maintenance Negative-Week Continuation - Build And Q02 Handoff

Date: 2026-09-10

## Outcome

The new structural WTI maintenance sleeve was source-approved, dedup-clean,
allocated, built, compiled, and enqueued once for fixed-risk Q02.

- Identity: QM5_41421 / `wti-refmaint-negweek-cont`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414210000`
- Signal: short only after one strictly negative completed week when the new
  Monday anchor is in February, March, September, or October
- Lifecycle: first new-week attempt, frozen 3.5 ATR stop, next-week close
- Q02 work item: `290e9de5-3b60-4166-983b-fab2bd11ab23`

## Deterministic Evidence

- Reputable-source approval bounds official EIA maintenance-season context
  and complete-read peer-reviewed commodity-momentum evidence, while clearly
  disclosing the untested weekly/CFD translation.
- Canonical dedup: `CLEAN` across 4,901 registry rows, 1,511 cards, and 45
  Strategy Wiki nodes; manual family review separates six nearby WTI rules.
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Card schema, G0-heading, and Card-v2 execution-contract lints: PASS.
- Reference suite: 12/12 PASS.
- Governed compile `1d13cb7f-fcf7-4c04-8079-06fe036e0775`: `COMPILE_OK`,
  zero compiler errors/warnings, strict build-check PASS.
- Q02 dry run: `ELIGIBLE` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- CPU samples: 88, 90, 86, 55, and 65 percent; maximum 90 is below the
  exclusive 97 percent ceiling.

## Safety Boundary

No manual tester, optimization, live/demo/shadow/stress preset, AutoTrading,
`T_Live`, deploy/live manifest, portfolio gate, admission, correlation waiver,
or decorrelation claim was touched. Q09 alone may establish realized portfolio
correlation.
