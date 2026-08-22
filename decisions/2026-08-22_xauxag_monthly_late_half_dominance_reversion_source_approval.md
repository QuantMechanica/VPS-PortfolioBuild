# XAU/XAG Completed-Month Late-Half Dominance Reversion - Source Approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-22. The mission
asks for one new, non-duplicate, structural low-frequency commodity edge and
explicitly permits a market-neutral `XAUUSD`/`XAGUSD` gold/silver-ratio
reversion basket. It requires reputable-source criteria and `RISK_FIXED`
backtests and excludes live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-mlatehalf-dom-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  two-leg basket
- state: the immediately completed broker-calendar month's late cumulative
  relative-return half has strictly greater absolute magnitude than its early
  half
- action: fade the late-half sign with opposite equal-notional metal legs for
  the next broker-calendar month
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
   which preserves named peer-reviewed DOI lineage for Karsten Schweikert
   (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-cointegration
   evidence from Yaya, Vo, and Olayinka (2021), *Resources Policy* 72,
   102045, DOI `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   which records CME Group's definition of the gold/silver ratio, its
   intermarket-spread carrier, and the metals' differing monetary and
   industrial sensitivities.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026/source.md`.

Schweikert supports testing a potentially state-dependent long-run
gold/silver relation rather than assuming one universal equilibrium. CME
supports treating gold and silver as an intermarket relative-value carrier.
Neither source tests a completed-month late-half dominance state, a one-month
contrarian hold, Darwinex continuous CFDs, fixed cash risk, or equal-notional
execution. Those are declared QM falsification choices. No source return,
density, hedge ratio, cost, neutrality, or portfolio-correlation result
transfers.

## Locked Mechanic

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, slots
   zero and one, fixed-risk backtest inputs, both news axes OFF, and Friday
   close OFF.
2. On the first tradable synchronized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw host-bar open, reconstruct the two
   immediately preceding consecutive completed calendar months. Require 17
   through 23 unique timestamp-identical close pairs in each month and no
   current-month observation.
3. Let `P` be the parent month's chronological final synchronized log ratio
   and let `Q[0]...Q[n-1]` be every chronological ratio in the immediately
   completed month. Set `h=floor(n/2)`. Define
   `early=Q[h-1]-P` and `late=Q[n-1]-Q[h-1]`. The shared midpoint ratio is an
   anchor, not a duplicated return, so the halves exhaust every adjacent
   relative return from `P` through `Q[n-1]` exactly once.
4. Trade only when `abs(late) > abs(early)`. A positive late half opens SELL
   XAU / BUY XAG; a negative late half opens BUY XAU / SELL XAG. Equality,
   zero late return, asynchronous history, mixed month labels, invalid split,
   or invalid endpoints consumes the month flat. The early-half sign and the
   full-month endpoint sign do not affect eligibility or sizing.
5. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker month.
6. Size an equal-absolute-notional opposite-leg package so combined normalized
   hard-stop risk cannot exceed one `RISK_FIXED=1000` budget. Freeze a
   `3.5 * ATR(20,D1)` stop on each leg, reject notional mismatch above 20
   percent, and use no target.
7. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partially close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

## Two-Half Arithmetic Contract

The newest completed month contributes exactly `n` adjacent relative returns:
from `P` to `Q[0]`, then from each `Q[i-1]` to `Q[i]`. With
`h=floor(n/2)`, the early block contains `h` returns and the late block
contains `n-h` returns. Across the locked 17-to-23-session range, the early
block contains eight through eleven returns and the late block nine through
twelve; none is skipped or counted twice.

The gate is deliberately asymmetric in recency. It asks whether the newer
half's cumulative relative displacement strictly dominates the older half,
then fades only that newer-half sign. Opposed half signs remain eligible when
the late half dominates; same-sign halves remain ineligible when it does not.
This translation is load-bearing and is not a source result.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named source authors, complete mechanic, and actual Company Reference Wiki
root. It scanned 4,615 registry identities, 1,286 repository cards, and 45
Strategy-Wiki nodes, found no exact or fuzzy match, and returned `CLEAN`.
Evidence:
`artifacts/qm5_xauxag_mlatehalf_dom_rv_preallocation_dedup_20260822.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_41113_xauxag-mhalfagree-rv` requires both exhaustive ratio halves to
  share one strict sign and ignores their relative magnitudes. This candidate
  requires strict late-half magnitude dominance, accepts an opposed early
  half, and rejects same-sign paths whose early half is at least as large.
- `QM5_41116_xauxag-mthirdvote-rv` casts a magnitude-blind strict majority
  across three exhaustive relative-return blocks. This candidate uses two
  halves, has no vote, and makes the magnitude ordering load-bearing.
- `QM5_41112_xauxag-mdaybreadth-rv` counts every adjacent daily relative-
  return sign and requires full-month endpoint agreement. This candidate
  uses two cumulative blocks and imposes no endpoint-agreement filter.
- `QM5_41117_wti-mlatehalf-dom-mom` shares the half-dominance state shape but
  is a single-symbol direct-WTI continuation position. This candidate computes
  synchronized XAU-minus-XAG relative returns, reverses the late sign, and
  opens an opposite equal-notional two-leg package.
- `QM5_20260_xauxag-mom-vote` votes cross-sectional one-, three-, and
  twelve-month return ranks and follows the winner. This candidate partitions
  one completed month and fades a within-month relative displacement.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a rolling center, regression, scale, robust score, or empirical
  tail. This candidate estimates none.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades an EURJPY/GBPJPY cointegration package.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only,
  two-day XNG oscillator pullback with no paired intermetal state.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, deterministic
floor-half split, exhaustive non-overlapping relative-return blocks, strict
late-half absolute dominance, contrarian late-sign package direction,
consumed monthly attempt, equal-notional aggregate-risk package, and
next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_LATE_HALF_ABSOLUTE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_LATE_HALF_DOMINANCE_TRANSLATION_RISK`: peer-reviewed DOI and
  official-exchange lineage, named authors, complete governed records, and
  durable hashes; the untested path gate is disclosed and no result transfers.
- R2 `PASS`: synchronized month labels, endpoints, split, return orientation,
  strict magnitude/zero rules, sides, attempt, risk, stops, atomicity, and
  lifecycle are locked before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state supply every
  runtime input; Q02 owns history, holiday attrition, density, costs, fills,
  financing, and CFD-basis sufficiency.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms,
  indexing, arithmetic, comparisons, ATR, quotes, positions, deals, and
  terminal state only; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid.

## Frequency, Portfolio Claim, And Falsification

Strict late-half dominance is expected to select approximately five to eight
completed paired packages per full post-warm-up year. This is a prior, not
test evidence. Q02 retires below the unchanged five-trades/year/symbol floor,
at zero trades or nonpositive governed economics, or on any synchronization,
month, split, endpoint, return-orientation, dominance, zero, side, attempt,
risk, atomicity, lifecycle, or determinism defect.

The opposite equal-notional legs are intended to suppress common outright-
metal direction. They do not prove beta, factor, volatility, market, or
portfolio neutrality. Q09 alone may establish realized correlation with the
certified XAU/SP500/NDX/XNG book. No decorrelation, admission, replacement, or
waiver claim is made here.

No weak result may be rescued by moving the split, accepting equality,
reversing the side, adding half-sign or endpoint agreement, changing the hold,
loosening session bounds, or adding a fitted center, volatility, volume,
calendar, event, external, or prior-result state.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
