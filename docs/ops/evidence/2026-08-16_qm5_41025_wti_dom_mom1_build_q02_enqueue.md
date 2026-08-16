# QM5_41025 WTI Exact-Day Momentum Build And Q02 Enqueue

Date: 2026-08-16

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41025_wti-dom-mom1` is a new exact-`XTIUSD.DWX`, D1,
low-frequency structural calendar/momentum interaction. It buys only on exact
normalized broker-calendar day 8 after a positive immediately completed
calendar-month WTI return, or sells only on exact day 26 after a negative
return. A date is persisted before fallible gates, missing dates never shift,
and an opened package closes at the first following normalized D1 boundary.

Borowski (2016) supplies the source-significant positive WTI day-8 and
negative day-26 cells. Moskowitz, Ooi, and Pedersen (2012), *Journal of
Financial Economics* 104(2), supply instrument-own completed-return-sign
momentum and explicit WTI membership. Both lineages were completely reviewed
before extraction. Their conjunction, Darwinex label mapping, one-D1 hold,
fixed risk, ATR stop, and spread ceiling are disclosed QM falsification
choices; no source performance transfers.

This direct crude-oil carrier is outside the certified XAU/SP500/NDX/XNG
book. That establishes exposure novelty, not realized decorrelation,
certification, or portfolio admission. Q09 alone may establish correlation if
the candidate survives the earlier gates.

## Approval, Allocation, And Non-Duplicate Boundary

- Source approval: `600106d4ee80673024d52d5496228b042dea10e4`.
- Deterministic allocation of `QM5_41025`:
  `5e1571bf13c4bfb6a0e582ad87f8a6dce12dcde4`.
- Strategy Card and OWNER G0 approval:
  `3676e0792bb5be521cecd988e0a2b6d7fe148a27`.
- V5 implementation and Q01 seal:
  `ba9ee25135f7d5b0b8c27ee690b49190a77bd7dd`.
- The canonical dedup checker scanned 4,512 registry rows and 608 root cards,
  found no exact identity, and raised only `wti-dom-ctrreg` for manual review.
- Manual family review separated the opposing 252-D1 state in
  `QM5_41017`, the day-1/day-26 252-D1 build `QM5_20215`, the unconditional
  source parents `QM5_20036`/`QM5_20027`, the month-boundary/full-month hold
  `QM5_20187`, and RSI2 commodity build `QM5_12567`.
- Verdict:
  `CLEAN_WTI_DAY8_DAY26_PRIOR_MONTH_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Magic tuple:
  `41025,wti-dom-mom1,0,XTIUSD.DWX,410250000`.
- Backtest preset:
  `framework/EAs/QM5_41025_wti-dom-mom1/sets/QM5_41025_wti-dom-mom1_XTIUSD.DWX_D1_backtest.set`.
- Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; both news axes OFF; Friday close enabled at broker
  hour 21.
- Reference suite: eight tests PASS for exact date/no-shift behavior,
  zero-or-one-day label normalization, the 180-minute boundary, consecutive
  completed-month endpoints, date-specific direction agreement, and the
  next-D1 exit.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260816_151015/QM5_41025_wti-dom-mom1.compile.log`.
- Targeted strict build check: PASS, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_151014.json`.
- Static P1: PASS:
  `D:/QM/reports/pipeline/QM5_41025/P1/P1_QM5_41025_result.json`.
- All three Strategy Card copies are byte-identical and pass schema/ML lint.
- The repo-wide historical registry audit still reports unrelated legacy
  missing/mismatched rows. The target-specific strict build gate has no
  registry, compile, setfile, forbidden-code, performance, or schema finding;
  no legacy row was altered.

## Capacity And Target-Only Queue Mutation

The first path-anchored read-only factory sample at
`2026-08-16T15:12:25Z` found T4, T7, and T10 running: 3 of the 7 allowed
T1-T10 tester terminals. The immediate pre-apply sample at
`2026-08-16T15:14:58Z` found T4, T6, T7, and T9: 4 of 7. The CPU ceiling did
not bind. Non-factory terminals, including `T_Live`, were excluded from the
capacity count.

Dry run:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41025 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Applied once:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41025 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=True
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The canonical factory DB contained exactly one matching row at the read-only
observation:

- work item: `e96b97cd-e777-401d-aed8-af621853fff7`;
- phase/kind: `Q02` / `backtest`;
- symbol: `XTIUSD.DWX`;
- created: `2026-08-16T15:15:04+00:00`;
- observed status: `pending`, unclaimed;
- attempt count: `0`; verdict: unset.

The post-enqueue sample at `2026-08-16T15:15:57Z` remained below the ceiling
at 4 of 7. The queue report is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`0f748fb5dc106ae8b83af2e29fd1d33ea2e36d96b08b1ab2619a588626e29740`.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `1aaace3e4ab7ab97ec4be43a1e146d0ed07244b97c732d4546b6ef2e7242671f` |
| G0 decision | `a090c6d590c2c7a58b702177de2328c3d5d5c57644e65b5bc1dfccb5f88161d0` |
| governed source packet | `2f0af8a05779842616ccf26404ec56a9456e80ce880a2590253f6afcc2c35cc2` |
| each of three synchronized cards | `01ade49a1e5502a328f7983366e892633faf1c385b2e206541fade30fd0de524` |
| MQ5 source | `8edfbeb1061bec19fd9ce4e86bc08ac8b23d80a2c40b2510e53b841c4f06d3d7` |
| compiled EX5 | `f85f16be9d5298f263300081c33520f324bd1a215f306f5ea8871521f3edc358` |
| fixed-risk setfile | `0ca6a2dc5981b5e14a69d86192c096d59a81d5e82526018471b4d4ece97b777f` |
| reference test | `1a4c89d4d9e83d8eb9d35c03aa3234b0267d84e6efff8799834dbbf2b7c8a555` |
| strict build-check report | `a10f37b60031911b46d2862691db81a267fccc7dbfae1748bbd78a8ca8878fde` |
| static P1 result | `b2e65eebea557561318fbb9f43a6eaa3b1909682f82abad82ea0598dff23a214` |

## Safety And Handoff

No manual tester run, pipeline phase runner, dispatcher tick, terminal start
or stop, reservation mutation, AutoTrading action, `T_Live` state change,
live/demo/shadow/stress preset, portfolio-gate edit, portfolio admission,
deploy manifest, or `T_Live` manifest action occurred. Q02 must retire below
five completed positions per full post-warm-up year, on zero trades, wrong or
shifted dates, wrong endpoints/signs, nondeterminism, risk-mode mismatch, or
nonpositive governed economics. This receipt records an enqueue, not a Q02
verdict, certification, decorrelation finding, or portfolio admission.
