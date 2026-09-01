# QM5_41264 WTI Monthly Yuen20 Trimmed-Shift Trend - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41264_wti-myuen20-shift-tr`
- Strategy ID: `AI-CODEX-WTI-MYUEN20-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41264_wti-myuen20-shift-tr_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-WTI-MYUEN20-20260901/source.md`
- Source approval commit: `6b929669e7`
- Identity reservation commit: `77331a3951`

## Decision

Approve one branch-only non-live build of the locked WTI monthly fixed-block
20%-trimmed Yuen robust-location shift continuation rule, followed by strict
Q01 and one paced Q02 enqueue if CPU admission permits.

G0 approves mechanization and the execution contract. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Source and R1

`APPROVED_WITH_EXPLICIT_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY`. The evidence
contains complete governed peer-reviewed WTI continuation evidence, named
peer-reviewed Yuen method metadata and abstract, and complete official SciPy
documentation plus pinned implementation evidence.

The sources support the WTI carrier, general continuation direction, and
trimmed unequal-variance arithmetic only. Fixed blocks, trim fraction,
activity boundary, side, CFD translation, risk, and lifecycle are pre-result
QM synthesis.

## R2 mechanical contract

`APPROVED`. The card locks:

1. exact `XTIUSD.DWX` host/trade symbol on D1;
2. one consumed attempt within 180 minutes of a broker-month transition;
3. 21 consecutive completed month-end closes and 20 adjacent log returns;
4. fixed old/recent blocks of ten with independent sorted copies;
5. exact `g=2`, `h=6`, middle-six trimmed means, and two-per-tail
   Winsorization;
6. Winsorized variance around each Winsorized mean with exact divisor five;
7. unequal-variance `se2=wvar_old/6+wvar_recent/6` and score orientation
   `recent-old`;
8. inclusive `+/-0.75` shift-direction entry boundary;
9. fixed `RISK_FIXED=1000`, frozen `3.5*ATR(20,D1)` stop, spread ceiling,
   next-month exit, and forty-day stale repair.

There is no optimization surface, fitted split, p-value, theoretical critical
table, statistic-strength sizing, current-month input, intramonth retry,
external runtime input, grid, martingale, or scale-in.

## R3 data

`APPROVED_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 history
and MT5-native state provide every signal and execution input. Q02 must expose
warm-up, roll/basis, financing, spread, gap, month-label, and history-window
failures.

## R4 prohibited logic

`APPROVED`. The rule uses deterministic timestamps, completed prices,
logarithms, sorting, fixed finite loops, arithmetic, comparisons, ATR risk,
quotes, orders, positions, deals, and terminal state. It has no trained
signal, prohibited signal indicator, random runtime sampling, or external
runtime feed.

## Pre-result activity prior

The `0.75` score is a density-aware activity boundary, not a significance
critical value. A centered continuous reference implies roughly five to six
absolute boundary events per twelve attempts before market/execution gates.
This is not an empirical frequency or alpha claim. Retire below five completed
positions in any full post-warm-up year.

## Dedup adjudication

The corrected-root receipt scanned 4,763 identities, 1,400 cards, and 45 Wiki
nodes, finding no exact identity. The expected fuzzy match `QM5_41249` uses
raw six/six means and variances with a recent-mean sign gate. This card uses
ten/ten blocks, middle-six trimmed locations, two-per-tail Winsorized scales,
effective size six, and the robust shift direction. Two fixed source fixtures
prove qualification disagreement in both directions.

Verdict:
`FUZZY_WELCH_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_YUEN20_TRIMMED_LOCATION_UNEQUAL_WINSORIZED_SCALE_SHIFT_CONTINUATION`.

## Build order

1. Create `framework/EAs/QM5_41264_wti-myuen20-shift-tr/` and copy the
   approved card into `docs/strategy_card.md`.
2. Allocate one active magic row for slot 0 `XTIUSD.DWX`, regenerate the
   resolver, and verify no row is dropped.
3. Implement only the approved four-module behavior and exact reference
   fixtures.
4. Create exactly one canonical D1 `RISK_FIXED` backtest preset.
5. Compile through governed Q01, require zero errors/warnings and all static/
   reference checks, then enqueue exactly one Q02 row if CPU admission permits.

## Safety boundary

Forbidden: manual tester launch, optimization, portfolio-gate mutation,
correlation waiver, portfolio admission, live/demo/shadow/stress presets,
`T_Live`, AutoTrading, deploy/live manifest, or terminal control.
