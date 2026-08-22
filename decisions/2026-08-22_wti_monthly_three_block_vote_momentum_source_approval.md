# WTI Completed-Month Three-Block Vote Momentum - Source Approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on the `agents/board-advisor` branch on 2026-08-22. The
mission explicitly permits a structural low-frequency `XTIUSD` trend edge,
requires one new non-duplicate reputable-source card with `RISK_FIXED`
backtests, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-mthirdvote-mom`
- proposed strategy ID: `MOP-WTI-MTHIRDVOTE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MTHIRDVOTE-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: a strict two-of-three sign majority across three exhaustive,
  chronological cumulative-return blocks inside the immediately completed
  broker-calendar month
- action: follow the majority direction for the next broker-calendar month
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The governed record below was read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which records a complete read and durable retrieval identity for Tobias J.
   Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series
   Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`.

The bounded child extraction will be
`strategy-seeds/sources/MOP-WTI-MTHIRDVOTE-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only chronological three-block sign vote. That vote is a predeclared QM
price-path hypothesis. No source return, trade density, cost, continuous-CFD
equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable normalized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw open, reconstruct the immediately
   completed month and its consecutive parent from completed D1 history. Each
   month must contain 17 through 23 unique, strictly ordered sessions.
3. Apply one uniform energy-label convention to the current bar and every
   historical bar: raw labels when the current D1 date equals broker date, or
   a `+1`-calendar-day normalization only when the raw label is exactly one
   day behind. Reject every other or mixed convention.
4. Let `P` be the parent month's chronological final close and let
   `C[0]...C[n-1]` be all chronological closes in the newest completed month.
   Set `a=floor(n/3)` and `b=floor(2n/3)`. Define
   `block_1=log(C[a-1]/P)`, `block_2=log(C[b-1]/C[a-1])`, and
   `block_3=log(C[n-1]/C[b-1])`. The shared endpoints are anchors, not
   duplicated returns, so the three blocks exhaust all `n` adjacent returns.
5. BUY only when at least two block returns are strictly positive. SELL only
   when at least two are strictly negative. A zero block contributes no vote;
   no strict majority consumes the month flat. Return magnitude cannot change
   direction or risk.
6. Persist the normalized decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry a consumed month.
7. Require no owned position and no same-magic entry deal in the decision
   month. Attach one frozen `3.5 * ATR(20,D1)` hard stop, risk exactly
   `RISK_FIXED=1000`, use no target, and reject a genuinely positive spread
   above 1,500 points.
8. Hold until the first tick of the next normalized broker month. Forty
   calendar days is a stale-exposure repair only. No trail, break-even move,
   partial exit, retry, scale-in, grid, martingale, or pyramid exists.

## Three-Block Arithmetic Contract

The newest completed month contributes exactly `n` adjacent returns: from
`P` to `C[0]`, then from each `C[i-1]` to `C[i]`. With
`a=floor(n/3)` and `b=floor(2n/3)`, block sizes are `a`, `b-a`, and `n-b`.
For the locked 17-to-23-session range, each block contains five through eight
returns and no return is skipped or counted twice.

The sign vote is deliberately magnitude-blind. Two positive blocks can
authorize BUY even when one negative block is larger in magnitude and makes
the full-month endpoint return negative; the symmetric case can authorize
SELL. That behavior is load-bearing and distinguishes the candidate from
unconditional completed-month endpoint momentum. It is also an explicit QM
translation risk, not a finding attributed to the paper.

## Non-Duplicate Gate

The canonical fail-closed pre-allocation checker included the proposed slug,
strategy ID, named authors, complete mechanic, and actual Company Reference
Wiki root. It scanned 4,611 EA-registry identities, 1,283 repository cards,
and 45 Strategy-Wiki nodes, found no exact or fuzzy match, and returned
`CLEAN`. Receipt:
`artifacts/qm5_wti_mthirdvote_mom_preallocation_dedup_20260822.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_41114_wti-mhalfagree-mom` requires both of two cumulative halves to
  share a sign. This candidate uses three exhaustive blocks, accepts a strict
  two-of-three majority, and can trade when one block opposes the other two.
- `QM5_41111_wti-mdaybreadth-mom` counts every individual adjacent daily
  return sign and also requires endpoint agreement. This candidate casts only
  three cumulative block votes and does not require the full-month endpoint
  sign to agree.
- `QM5_20272_wti-qtrvote-tr` votes four disjoint three-month returns across a
  full year. This candidate votes three within-month blocks and holds only the
  next month.
- `QM5_20187_wti-tsmom1m` follows every nonzero completed-month endpoint
  return. This candidate can reject that direction or take the opposite side
  when the within-month block majority differs.
- `QM5_41021_wti-mdual-mom` combines a full-month return with a nested final-
  five-session return and holds five sessions; the proposed blocks are
  exhaustive, non-overlapping, and held for a full month.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly WTI path vote.

Pre-allocation verdict:
`CLEAN_WTI_COMPLETED_MONTH_THREE_EXHAUSTIVE_BLOCK_STRICT_MAJORITY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_THREE_BLOCK_TRANSLATION_RISK`: peer-reviewed JFE article,
  DOI, named authors, complete-paper review, durable retrieval hash, and
  explicit WTI membership; the three-block vote is disclosed as an untested
  QM state.
- R2 `PASS`: exact clock, normalization, month membership, session bounds,
  endpoints, floor partitions, return orientation, zero handling, vote,
  attempt, risk, spread, stop, and lifecycle are fixed before results.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 plus MT5-native state supply every runtime input; Q02 owns
  label, density, cost, and continuous-CFD sufficiency.
- R4 `PASS`: closed-form timestamp/close arithmetic and framework state only;
  no ML, banned indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Frequency And Falsification

Because three nonzero block signs always have a strict majority, the design
expects approximately ten to twelve completed positions per full post-warm-up
year after history and execution gates. This is a hypothesis, not imported
evidence. Q02 retires below the unchanged five-trades/year/symbol floor, at
zero trades or nonpositive governed economics, or on any clock, label, month,
partition, return-orientation, vote, attempt, risk, stop, lifecycle, or
determinism defect.

No result may be rescued by changing the block count or endpoints, requiring
or removing endpoint agreement, weighting votes by magnitude, moving the
hold, loosening session bounds, or adding volatility, volume, season,
weekday, inventory, event, moving-average, external-data, or prior-result
filters.

## Implementation And Safety Boundary

The approved card may map exact identity and locked inputs to the No-Trade
module, completed-month reconstruction and three-block vote to Trade Entry,
malformed and stale exposure repair to Trade Management, and later-month
flattening to Trade Close. The framework owns kill switch, fixed-risk sizing,
registered magic, order handling, and telemetry.

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
