# WTI completed-month extreme-sequence momentum - Source Approval

Date: 2026-08-23

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-23. The mission
requires one new, non-duplicate, structural low-frequency commodity edge and
expressly permits a structural `XTIUSD` trend or seasonality carrier. It also
requires reputable-source criteria and `RISK_FIXED` backtests and excludes
live and portfolio-gate mutation.

## Candidate identity

- proposed slug: `wti-mextreme-sequence-mom`
- proposed strategy ID: `MOP-WTI-MEXTREME-SEQUENCE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MEXTREME-SEQUENCE-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, one outright WTI position
- state: in the immediately completed broker-calendar month, the unique low
  occurs before the unique high and the month closes above its first open, or
  the unique high occurs before the unique low and the month closes below its
  first open
- action: follow the completed auction direction for the next broker month
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved source basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It records a complete read of Tobias J. Moskowitz, Yao Hua Ooi, and Lasse
   Heje Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, with a
   published-PDF retrieval hash. WTI crude oil is an explicit constituent of
   the paper's commodity-futures universe. The paper directly tests monthly
   own-return sign as the next monthly holding direction, including the
   one-month formation/one-month holding specification.
2. `strategy-seeds/sources/MOP-WTI-WEXTREME-SEQUENCE-MOM-2026/source.md`,
   read in full as the governed closest-family extraction. It preserves the
   same parent lineage and makes the unique-extreme chronological-order proxy,
   ambiguity rules, and their separation from source results explicit for a
   weekly WTI carrier.

The bounded child extraction will be
`strategy-seeds/sources/MOP-WTI-MEXTREME-SEQUENCE-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen support testing a symmetric own-price WTI trend
carrier on a monthly formation and holding clock. They do not define the
chronological session order of a calendar month's high and low, require unique
extreme occurrences, or condition the return sign on that order. They also do
not test a Darwinex continuous CFD, broker-calendar month labels, fixed cash
risk, ATR stops, spread caps, or the QM portfolio. Those are transparent QM
falsification choices. No source return, alpha, probability, density, risk,
cost, CFD equivalence, or portfolio-correlation result transfers.

## Locked mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw host-bar open, reconstruct every completed D1
   session in the immediately preceding calendar month. Require 17 through 23
   unique sessions in strict chronological order and one adjacent older bar
   proving the month was not truncated. Exclude all current-month OHLC.
3. For chronological sessions `i=0..n-1`, set `O=open[0]`,
   `H=max(high[i])`, `L=min(low[i])`, and `C=close[n-1]`. Require positive
   finite prices, valid per-session and aggregate OHLC geometry, `H>L`, and
   `L<=O,C<=H`.
4. Require exactly one session whose high equals `H` and exactly one session
   whose low equals `L`. Let their chronological indices be `iH` and `iL`.
   A repeated extreme or `iH==iL` is ambiguous and consumes the month flat.
5. Map only extreme order that agrees with the completed month's body sign:
   `iL<iH && C>O` buys WTI; `iH<iL && C<O` sells WTI. Close/open equality,
   order/body disagreement, invalid or incomplete history, and ambiguous
   extremes consume the month flat. Magnitude and the distance between
   extreme sessions never alter direction, eligibility, or size.
6. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker month.
7. Open at most one position with aggregate `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry-spread
   ceiling. There is no signal-strength sizing.
8. Close on the first tick of a later broker-calendar month or after forty
   calendar days. Malformed, duplicated, stopless, or otherwise invalid
   ownership flattens immediately. Never retry, trail, partially close, scale
   in, grid, martingale, pyramid, or read an external runtime feed.

## Non-duplicate decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,621 registry identities, 1,290 repository cards, and 45 Strategy
Wiki nodes, found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_wti_mextreme_sequence_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_41098_wti-wextreme-sequence-mom` is a three-to-five-session normalized
  Monday-anchored weekly auction with a one-week hold. This candidate consumes
  the exact 17-to-23-session prior calendar month and holds to the next month;
  no week anchor or energy-label normalization enters its signal.
- `QM5_41105_wti-mclose-location-mom` compares the completed close with fixed
  range quartiles. This candidate has no close-location threshold and instead
  uses the chronological identities of the unique monthly high and low.
- `QM5_41106_wti-mbody-dominance-mom` compares absolute body with the monthly
  range. This candidate has no magnitude or body-share threshold.
- `QM5_41107_wti-minside-body-mom` requires range contraction versus a parent
  month. This candidate is invariant to every parent-month price.
- `QM5_41108_wti-mrange-expansion-mom` requires range expansion versus a
  parent month. This candidate uses no parent month and no range comparison.
- `QM5_41111_wti-mdaybreadth-mom`, `QM5_41114_wti-mhalfagree-mom`,
  `QM5_41115_wti-mthirdvote-mom`, and `QM5_41117_wti-mlatehalf-dom-mom`
  classify daily-body signs or block-return sums. This candidate counts no
  signs or blocks and ignores intermediate opens/closes except for OHLC
  geometry.
- pure one-month WTI time-series momentum maps only the month-end return sign;
  this candidate additionally requires a unique chronological low-to-high or
  high-to-low auction path, so identical endpoints can yield different
  eligibility.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback under a slow mean, not a symmetric outright WTI monthly
  structural auction.

The exact WTI carrier, immediately completed broker-calendar month,
17-to-23-session contract, unique aggregate-extreme sessions, chronological
extreme order, agreeing close/open sign, consumed monthly attempt, fixed-risk
package, and next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_EXTREME_SEQUENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1 `PASS_WITH_EXTREME_SEQUENCE_TRANSLATION_RISK`: named authors, a
  peer-reviewed *Journal of Financial Economics* DOI record, complete
  published-paper read, durable retrieval hash, explicit WTI membership, and
  a source-tested monthly direction/holding clock. The unique-extreme path
  state is explicit untested translation and no result transfers.
- R2 `PASS`: exact month membership, session count, chronology, OHLC geometry,
  unique-extreme rule, order/body conjunction, side, attempt, risk, stop,
  spread, and lifecycle are fixed before testing.
- R3 `PASS_WITH_CALENDAR_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. Q02 owns
  history, holiday attrition, density, costs, financing, fills, and CFD-basis
  sufficiency.
- R4 `PASS`: runtime uses completed timestamps and OHLC, integer index
  comparisons, ATR, quotes, positions, deals, and persistent terminal state;
  no trained logic, banned signal, external feed, grid, martingale, scale-in,
  or pyramid exists.

## Frequency, portfolio claim, and falsification

The fixed conjunction is expected to select approximately six to ten
completed positions per full post-warm-up year. This is a pre-result cadence
prior, not test evidence. Q02 retires below five completed positions in any
full scored year, at zero trades, with nonpositive governed economics, or on
any month-label, session, ordering, geometry, uniqueness, side, attempt, risk,
lifecycle, or determinism defect.

WTI supplies a commodity/energy carrier absent from the certified
XAU/SP500/NDX/XNG book. That structural distinction does not prove low
correlation, profitability, or portfolio admission. Q09 alone owns the
realized portfolio finding.

No weak result may be rescued by accepting repeated or same-session extremes,
dropping body agreement, reversing the side, changing month membership or the
hold, loosening session bounds, or adding a magnitude, wick, close-location,
range-rank, volatility, volume, seasonal, event, inventory, moving-average,
oscillator, external, or prior-result state.

## Implementation and safety boundary

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
