# QM5_41422 WTI Refinery-Restart Positive-Week Continuation - Build And Q02 CPU Stop

Date: 2026-09-10

## Outcome

A new structural WTI post-maintenance sleeve was source-approved, dedup-
reviewed, allocated, built, and compiled. Its first Q02 intake dry run is
eligible, but the paced enqueue was refused before mutation because a fresh
whole-host CPU sample exceeded the binding ceiling.

- Identity: QM5_41422 / `wti-refrestart-posweek-cont`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414220000`
- Signal: buy only after one strictly positive completed week when the new
  Monday anchor is in April or May
- Lifecycle: first new-week attempt, frozen 3.5 ATR stop, next-week close
- Compile work item: `12e67cc1-25b0-4007-a132-6b6febebdefd`
- Q02: not enqueued; no Q02 work-item row exists

## Deterministic Evidence

- Reputable-source approval bounds official EIA refinery-maintenance/restart
  context and complete-read peer-reviewed commodity-momentum evidence while
  disclosing the untested weekly/CFD translation.
- Canonical dedup found no exact identity across 4,902 registry rows, 1,512
  cards, and 45 Strategy Wiki nodes. Three fuzzy family neighbors were
  manually separated by carrier, opposite seasonal regime/direction, or
  two-week formation.
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Card schema and Strategy Card v2 execution-contract lints: PASS.
- Reference suite: 12/12 PASS; SPEC validator: PASS.
- Governed compile `12e67cc1-25b0-4007-a132-6b6febebdefd`: `COMPILE_OK`, zero
  compiler errors/warnings, strict build-check PASS.
- Q02 dry run: `ELIGIBLE`, hash-bound to EX5
  `15a14136ff3cd083d7eda8bd6c73f56bcfbb900c40b700750990f1f3ff1971c9`
  and setfile
  `60113f7cb51a06757eca423b88d8325bb142120d79e850939888fbf39caa3e5b`,
  with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Capacity Refusal

Five consecutive one-second `Processor(_Total)` samples were `91.90`,
`96.88`, `88.78`, `88.97`, and `98.34` percent (average `92.97`). The
maximum `98.34` exceeded the exclusive `97` percent ceiling. Six active work
items were present, all `OPT_CENSUS`. Per the PACER order, no Q02 apply command
was issued and no backtest was started.

## Exact Resume Action

After a new five-sample CPU window remains strictly below 97 percent, re-run
the dry intake to revalidate current hashes and then apply exactly once:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm intake-first-q02 --compile-work-item-id 12e67cc1-25b0-4007-a132-6b6febebdefd
python C:/QM/repo/tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm intake-first-q02 --compile-work-item-id 12e67cc1-25b0-4007-a132-6b6febebdefd --apply
```

## Safety Boundary

No manual tester, optimization, live/demo/shadow/stress preset, AutoTrading,
`T_Live`, deploy/live manifest, portfolio gate, admission, correlation waiver,
or decorrelation claim was touched.
