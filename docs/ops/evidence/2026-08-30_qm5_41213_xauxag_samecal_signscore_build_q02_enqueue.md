# QM5_41213 XAU/XAG same-calendar sign-score build and Q02 enqueue

Date: 2026-08-30

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CLEAR`

## Delivered edge

`QM5_41213_xauxag-samecal-signscore` is a low-frequency,
market-neutral-style precious-metals relative-value candidate. At the first
normalized `XAUUSD.DWX` D1 broker-month transition it scans the same calendar
month in exact years `Y-1..Y-10`, retains at least five synchronized
XAU-minus-XAG log-return pairs, maps nonnegative observations to one and
negative observations to zero, and computes:

```text
score = (x - n*0.5) / sqrt(n*0.5*0.5) = (2*x - n) / sqrt(n)
```

There is no continuity correction. The EA buys XAU and sells XAG only above
`+1.0+1e-10`, reverses the legs only below `-1.0-1e-10`, and otherwise
consumes the month flat. An opened package closes on the next normalized
broker-month boundary, with a 40-day stale repair and frozen per-leg
`3.5*ATR(20,D1)` stops.

The information object is binary relative gold-versus-silver calendar
pressure and the position has opposite XAU/XAG legs. That differs from the
book's outright XAU, SP500, NDX, and XNG exposures. It does not prove dollar,
beta, volatility, factor, market, or portfolio neutrality; Q09 remains the
only realized-correlation authority.

Canonical preallocation dedup scanned 4,712 registry identities, 1,358 cards,
and 45 wiki nodes. It found no exact identity and surfaced the expected
raw-mean XAU/XAG and single-WTI sign-score neighbors. On
`[0.09,-0.01,-0.01,-0.01,-0.01]`, raw mean buys XAU while the sign score sells
XAU. On `[0.001,0.001,0.001,0.001,-0.100]`, the sign score buys XAU while the
magnitude t-score sibling remains flat. The carrier, position composition,
participation rule, and binary information object are all load bearing.

## Governance and implementation

The reputable lineages are Keloharju, Linnainmaa, and Nyberg (2016), *Journal
of Finance*; Fuertes, Miffre, and Rallis (2010), *Journal of Banking &
Finance*; Papailias, Liu, and Thomakos (2021), *Journal of Banking & Finance*;
and commit-pinned R Core primary-software arithmetic. The exact two-metal CFD
conjunction and fixed threshold are QM translations with no transferred
performance claim.

- Source approval commit: `3d992f08934f929ddc7883d68beb22b68acc8708`.
- Bounded source packet commit: `b2839d5a8af0f06ebb60a242a095f4953acc1f95`.
- Approved G0 card and deterministic identity commit:
  `e78203c2cb8877ce221adf9096384b4772e3aa62`.
- Governed magic allocation commit:
  `0bd08c947da3642abf93ed6545065cb7d9fb20fa`.
- EA, basket manifest, spec, fixtures, and fixed-risk presets commit:
  `936127a996d265121408e5dcf9f101827b5b002e`.
- Active slots: XAU slot 0 / magic `412130000`; XAG slot 1 / magic
  `412130001`.
- Sole Q02 package risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split into two equal fixed stop-risk halves.

The executable normalizes native or uniform prior-day metal D1 labels,
requires the current normalized host date to equal the broker date, applies
the same offset to historical endpoints, and matches prior/target/following
timestamps across both legs. Missing exact years are skipped without
substitution. Fewer than five pairs, invalid prices, a nonpositive
denominator, or an inclusive threshold-band score consumes the month.

The independent suite passed nine deterministic label, synchronization,
exact-year, score-arithmetic, disagreement, attempt-state, card, setfile,
registry, resolver, and basket-manifest fixtures. Card schema, G0 structure,
spec, strategy-entry, and source-quarantine checks passed.

## Governed compile

Build task `1fff4fb6-e5dc-46b6-9a0f-ffd479698b00` is bound to compile item
`3926b8df-f21d-4cdf-8992-7d5d557a94fe`. A source-hash-exact bounded release
allowed one resident T7 worker to compile without launching a trading
terminal or changing AutoTrading.

The worker returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 1 nonfatal static warning;
- EX5 SHA-256:
  `cedd93aca2559e631435281eea4e5623f846a9e8a05108160181b4d0a17e5903`;
- evidence:
  `D:/QM/reports/work_items/3926b8df-f21d-4cdf-8992-7d5d557a94fe/QM5_41213/COMPILE_EA/compile_evidence.json`.

The nonfatal `EA_PERF_UNGATED_BAR_DATA` warning is call-graph-insensitive:
the flagged two-bar `CopyRates` is inside
`Strategy_NormalizedHostSessions`, which is called only by
`Strategy_AdvanceSignal_OnNewBar` after `QM_IsNewBar()` passes. The larger
history copies carry explicit bounded monthly-decision annotations.

The worker refreshed build hashes on the logical and two standard component
presets. All three remain fixed-risk build artifacts. Only the logical basket
preset appears in the recorded build result; neither component was enqueued
or treated as a standalone strategy.

## Q02 enqueue and CPU boundary

Immediately before `record-build`, five one-second whole-host CPU samples
averaged `70.14%` and peaked at `72.48%`, below the hard `97%` ceiling.
Recording the successful build atomically created exactly one logical-basket
Q02 item:

- work item: `d7bd7a15-0503-4840-b739-e15d40a63189`;
- symbol/timeframe: `QM5_41213_XAU_XAG_SAMECAL_SIGNSCORE_D1` / D1;
- logical setfile:
  `framework/EAs/QM5_41213_xauxag-samecal-signscore/sets/QM5_41213_xauxag-samecal-signscore_QM5_41213_XAU_XAG_SAMECAL_SIGNSCORE_D1_D1_backtest.set`;
- test window: 2018-07-02 through 2024-12-31;
- readback: `pending`, attempt 0, unclaimed;
- component Q02 items: zero.

The immediate post-enqueue CPU window averaged `81.58%` and peaked at
`90.64%`, also below the ceiling. This mission performed no manual dispatch,
tester launch, retry, terminal reservation, or later pipeline action.

## Remaining falsification risks

- Synchronized history gaps can still cause zero or sub-floor activity.
- Binary signs discard magnitude, and one observation can change a small-n
  participation or direction decision.
- Opposite legs do not establish realized neutrality; Q09 must reject
  excessive overlap.
- Continuous-CFD labels, financing, rolls, asymmetric stops, legging, and
  futures-to-CFD basis remain empirical translation risks.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress/optimization preset, `T_Live`
control or manifest, deploy manifest, portfolio gate, portfolio admission,
or correlation waiver was touched. Neither certification nor diversification
is claimed before downstream evidence.

Machine-readable receipt:
`artifacts/qm5_41213_build_q02_enqueue_20260830.json`.
