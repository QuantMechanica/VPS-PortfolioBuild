# QM5_41191 WTI Same-Calendar Signed-Rank Seasonality — G0 Decision

Date: 2026-08-28

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41191_wti-samecal-srank_card.md` and only
the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41191`
- slug: `wti-samecal-srank`
- strategy ID: `KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026_S01`
- source ID: `KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026`
- host / traded slot 0: exact `XTIUSD.DWX`, D1
- logical symbol: `XTIUSD.DWX`

`41191` is the deterministic next free numeric identity after the current
registry frontier `41190`. The governed allocator must persist the exact
active registry and magic rows and regenerate the resolver before any build
step. This decision is not a substitute for that verified allocation.

## Source And Claim Boundary

The bounded source packet is
`strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md`,
SHA-256
`57FF7096210C5E48A7236DAD6799A3E6CE706E726BD704416064D5A803D10B98`.
Its durable source approval is
`decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md`,
committed before extraction as `62ee0c240`.

R1 is `PASS_WITH_STATISTIC_AND_SINGLE_CFD_TRANSLATION_RISK`. The complete
peer-reviewed Keloharju source lineage supplies a same-calendar-month
commodity information object, a five-year floor, and explicit crude-oil
membership. Complete pinned R Core implementation and manual files supply
the one-sample signed absolute-rank sum. Neither source tests this direct-WTI
conjunction, strict tie reduction, Darwinex CFD, or QM book. No performance,
p-value, significance, cost, density, CFD-equivalence, neutrality, or
correlation result transfers.

## Mechanical Decision

R2 is `PASS`. On the first eligible tick of each new broker month, the card:

1. consumes the month before every fallible entry gate;
2. applies one uniform native or `+1` energy D1 label convention;
3. reconstructs exact completed returns for this calendar month in years
   `Y-1..Y-10`, skipping invalid years and requiring five observations;
4. rejects epsilon-zero returns and epsilon-level absolute-return ties;
5. assigns strict absolute ranks 1 through `n`, sums positive ranks, and
   computes `S=2*V_plus-n(n+1)/2` with invariants;
6. buys on positive `S`, sells on negative `S`, and consumes exact zero flat;
7. sizes one WTI position under `RISK_FIXED=1000` against a frozen
   `3.5*ATR(20,D1)` hard stop; and
8. closes at the next month, after 35 days, or immediately on malformed owned
   state.

Both news axes, legacy news mode, and Friday close are OFF. There is no mean,
median, hit-rate, p-value, threshold sweep, fixed month list, recent trend,
inventory, event, curve, volume, oscillator, external runtime feed, or
result-dependent rescue.

## Data And Determinism

R3 is `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
`XTIUSD.DWX` D1 history, quotes, contract metadata, ATR, positions, deals,
broker time, and terminal-persistent attempt state provide every field. Q02
must prove warm-up, normalized sessions, density, fills, and economics.

R4 is `PASS`. The signal uses only timestamps, completed prices, logarithms,
sorting, comparisons, integer arithmetic, and native execution state. There
is no trained output, prohibited signal indicator, external runtime feed,
grid, martingale, scale-in, pyramid, or adaptive PnL fit.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_srank_preallocation_dedup_20260828.json`, SHA-256
`26CC216D1ED87B6C16F5FFAA51DD53D4D25BFA76798F6792798E447C28EF7DD1`,
found no exact identity across 4,690 registry rows, 1,341 cards, and all 45
Strategy Wiki nodes. It surfaced only expected fuzzy same-calendar relatives.

Manual review establishes functional non-equivalence:

- `QM5_20099_wti-samecal` follows the arithmetic mean. On
  `[.01,.02,.03,.04,-.20]`, this card buys with `S=5` while the mean is
  negative.
- `QM5_41055_wti-medcal` follows the ordinary median. On six small negatives
  plus four larger positives, this card buys with `S=13` while the median is
  negative.
- `QM5_41059_wti-samecal-hit` uses positive-observation frequency. On six
  small positives plus four larger negatives, this card sells with `S=-13`
  despite a positive count majority.
- Fixed-month and recent-path WTI systems use different calendar samples and
  state functions; certified `QM5_12567` is a short-horizon long-only XNG
  oscillator pullback.

The carrier, disjoint same-calendar sample, strict absolute ranks, centered
score, zero/tie rule, and monthly lifecycle are load bearing. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_RENEWAL`.

## Portfolio Intent And Falsification

WTI adds a crude-oil return driver absent from the stated directional
XAU/SP500/NDX/XNG book. This does not prove factor or portfolio decorrelation;
only unchanged Q09 evidence may decide realized overlap.

Q02 retires on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any defect in calendar,
endpoint, normalization, sample, zero/tie, rank, invariant, score, side,
attempt, fixed risk, stop, lifecycle, or determinism. No parameter, direction,
carrier, risk, stop, hold, or gate may change after results to rescue it.

## Capacity Preflight

A fresh five-sample whole-host window ending
`2026-08-28T18:11:40.0503171Z` measured `70.9145%`, `76.5028%`, `69.0730%`,
`67.0933%`, and `78.0296%`: average `72.3226%`, maximum `78.0296%`. Both are
strictly below the governed `97%` ceiling, so the earlier explicit CPU stop
does not bind this allocation decision. A new fresh check remains mandatory
before Q02 enqueue.

## Authorized Scope

This approval permits only:

- deterministic EA and slot-0 magic allocation through the governed
  allocator and resolver regeneration;
- one branch-only V5 EA build;
- one exact D1 `RISK_FIXED` backtest setfile;
- strict compile and Q01 validation; and
- one paced Q02 enqueue if the active factory remains below its CPU ceiling.

It does not permit a manual backtest, terminal control, live/demo/shadow/
stress/optimization setfile, `T_Live`, AutoTrading, deploy or live manifest,
portfolio-gate mutation, portfolio admission, correlation waiver, or queue
deletion.
