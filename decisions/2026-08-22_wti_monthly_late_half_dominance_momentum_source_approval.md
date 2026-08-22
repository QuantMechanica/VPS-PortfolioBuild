# WTI Completed-Month Late-Half Dominance Momentum - Source Approval

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

- proposed slug: `wti-mlatehalf-dom-mom`
- proposed strategy ID: `MOP-WTI-MLATEHALF-DOM-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MLATEHALF-DOM-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the immediately completed broker-calendar month's second exhaustive
  cumulative half has strictly greater absolute return than its first half
- action: follow the second-half sign for the next broker-calendar month
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
`strategy-seeds/sources/MOP-WTI-MLATEHALF-DOM-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only within-month late-half dominance gate. That gate is a predeclared QM
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
   `C[0]...C[n-1]` be all chronological closes in the immediately completed
   month. Set `h=floor(n/2)`. Define
   `early=log(C[h-1]/P)` and `late=log(C[n-1]/C[h-1])`. The shared split close
   is an anchor, not a duplicated return, so the two blocks exhaust all `n`
   adjacent returns from `P` through `C[n-1]`.
5. Trade only when `abs(late) > abs(early)`. BUY when `late > 0`; SELL when
   `late < 0`. Equality, zero late return, invalid arithmetic, malformed
   history, or non-dominance consumes the month flat. Neither return magnitude
   changes risk.
6. Persist the normalized decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry a consumed month.
7. Require no owned position and no same-magic entry deal in the decision
   month. Attach one frozen `3.5 * ATR(20,D1)` hard stop, risk exactly
   `RISK_FIXED=1000`, use no target, and reject a genuinely positive spread
   above 1,500 points.
8. Hold until the first tick of the next normalized broker month. Forty
   calendar days is a stale-exposure repair only. No trail, break-even move,
   partial exit, retry, scale-in, grid, martingale, or pyramid exists.

## Two-Half Arithmetic Contract

The newest completed month contributes exactly `n` adjacent returns: from
`P` to `C[0]`, then from each `C[i-1]` to `C[i]`. With `h=floor(n/2)`, the
early block contains `h` returns and the late block contains `n-h` returns.
For the locked 17-to-23-session range, the early block contains eight through
eleven returns and the late block nine through twelve; none is skipped or
counted twice.

The gate is deliberately asymmetric in recency. It asks whether the newer
half's cumulative displacement strictly dominates the older half, then uses
only the newer half's sign. Opposed half signs are eligible when the newer
half dominates; same-sign halves are ineligible when it does not. This is a
load-bearing translation risk, not a result attributed to the paper.

## Non-Duplicate Gate

The canonical fail-closed pre-allocation checker included the proposed slug,
strategy ID, named authors, complete mechanic, and actual Company Reference
Wiki root. It scanned 4,613 EA-registry identities, 1,285 repository cards,
and 45 Strategy-Wiki nodes, found no exact or fuzzy match, and returned
`CLEAN`. Receipt:
`artifacts/qm5_wti_mlatehalf_dom_mom_preallocation_dedup_20260822.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_41114_wti-mhalfagree-mom` requires both exhaustive halves to share one
  strict sign and ignores their relative magnitudes. This candidate requires
  strict late-half magnitude dominance, accepts an opposed early half, and
  rejects same-sign paths whose early half is at least as large.
- `QM5_41115_wti-mthirdvote-mom` casts a magnitude-blind strict majority over
  three exhaustive blocks. This candidate uses exactly two halves, has no
  vote, and makes the magnitude ordering load-bearing.
- `QM5_20187_wti-tsmom1m` follows every nonzero completed-month endpoint
  return. This candidate consumes a non-dominant late half flat and therefore
  trades a strict subset selected by the completed intramonth path.
- `QM5_41016_wti-mclose-mom` follows the prior month's final-five-session
  return and exits after five sessions. This candidate uses the entire
  completed month in two exhaustive blocks, compares them, and holds through
  the next month.
- `QM5_41068_wti-waccel-mom` requires two consecutive completed weeks to have
  the same sign and a larger newest magnitude, then holds one week. This
  candidate partitions one completed month, permits opposed half signs, and
  uses a monthly decision and hold.
- `QM5_20274_wti-path-eff` measures a twelve-month net-to-absolute path
  efficiency threshold. This candidate estimates no threshold, volatility,
  or twelve-month path statistic.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not symmetric monthly WTI continuation.

Pre-allocation verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_LATE_HALF_ABSOLUTE_DOMINANCE_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_LATE_HALF_DOMINANCE_TRANSLATION_RISK`: peer-reviewed JFE
  article, DOI, named authors, complete-paper review, durable retrieval hash,
  and explicit WTI membership; the within-month dominance gate is disclosed
  as an untested QM state.
- R2 `PASS`: exact clock, normalization, month membership, session bounds,
  endpoints, floor-half split, return orientation, strict magnitude and sign
  rules, attempt, risk, spread, stop, and lifecycle are fixed before results.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 plus MT5-native state supply every runtime input; Q02 owns
  label, density, cost, and continuous-CFD sufficiency.
- R4 `PASS`: closed-form timestamp/close arithmetic and framework state only;
  no ML, banned indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Frequency And Falsification

The strict late-half dominance gate is expected to select approximately five
to eight completed positions per full post-warm-up year. This is a hypothesis,
not imported evidence. Q02 retires below the unchanged five-trades/year/symbol
floor, at zero trades or nonpositive governed economics, or on any clock,
label, month, split, return-orientation, dominance, attempt, risk, stop,
lifecycle, or determinism defect.

No result may be rescued by moving the split, accepting equality, reversing
the side, adding an agreement condition, changing the hold, loosening session
bounds, or adding volatility, volume, season, weekday, inventory, event,
moving-average, external-data, or prior-result filters.

## Implementation And Safety Boundary

The approved card may map exact identity and locked inputs to the No-Trade
module, completed-month reconstruction and half-dominance state to Trade
Entry, malformed and stale exposure repair to Trade Management, and later-
month flattening to Trade Close. The framework owns kill switch, fixed-risk
sizing, registered magic, order handling, and telemetry.

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
