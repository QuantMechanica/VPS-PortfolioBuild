# XAU/XAG Completed-Month Close-Quartile Reversion - Source Approval

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

- proposed slug: `xauxag-mclose-quartile-rv`
- proposed strategy ID:
  `SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  two-leg basket
- state: the final synchronized gold-minus-silver log-ratio close of the
  immediately completed broker-calendar month lies in its strict lower or
  upper inclusive-count quartile
- action: fade that lower/upper relative close rank with opposite
  equal-notional metal legs for the next broker-calendar month
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
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026/source.md`.

Schweikert supports testing a potentially state-dependent long-run
gold/silver relation rather than assuming one universal equilibrium. CME
supports treating gold and silver as an intermarket relative-value carrier.
Neither source tests an immediately completed calendar month's within-month
closing rank, a one-month contrarian hold, Darwinex continuous CFDs, fixed
cash risk, or equal-notional execution. Those are declared QM falsification
choices. No source return, density, hedge ratio, cost, neutrality, or
portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, slots
   zero and one, fixed-risk backtest inputs, both news axes OFF, and Friday
   close OFF.
2. On the first tradable synchronized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw host-bar open, reconstruct every
   synchronized close pair in the immediately completed calendar month.
   Require 17 through 23 unique timestamp-identical positive close pairs and
   no current-month observation.
3. Order the completed-month log ratios oldest to newest. Let `n` be the
   count, let `z` be the newest ratio, let `rank` be the zero-based count of
   ratios strictly below `z`, and let `tail=ceil(n/4)=(n+3)//4`. Any earlier
   ratio equal to `z` consumes the month flat.
4. A `rank < tail` lower-quartile close opens BUY XAU / SELL XAG. A
   `rank >= n-tail` upper-quartile close opens SELL XAU / BUY XAG. Every
   interior rank consumes the month flat. Rank distance does not affect
   direction, sizing, stops, or lifecycle.
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

## Quartile Arithmetic Contract

The newest close participates once in a rank over all `n` synchronized
completed-month ratios. With `tail=ceil(n/4)`, the eligible lower and upper
sets each contain exactly `tail` possible unique ranks. Across the locked
17-to-23-session range, `tail` is five or six and total eligible ranks are ten
or twelve. There is no rolling center, fitted scale, return threshold, future
price, current-month price, or optimization surface.

Strict uniqueness is load-bearing: equality between the newest ratio and any
earlier ratio is flat rather than assigned by timestamp. The quartile cutoff
is an inclusive count rule fixed before testing, not a sample quantile
interpolation convention.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named source authors, complete mechanic, and actual Company Reference Wiki
root. It scanned 4,618 registry identities, 1,287 repository cards, and 45
Strategy-Wiki nodes, found no exact or fuzzy match, and returned `CLEAN`.
Evidence:
`artifacts/qm5_xauxag_mclose_quartile_rv_preallocation_dedup_20260822.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_41079_xauxag-wclose-extreme-rv` requires the newest ratio to be the
  unique minimum or maximum of a three-to-five-session completed week and
  holds one week. This candidate uses the immediately completed 17-to-23-
  session calendar month, fixed outer quartile rank sets, and a one-month
  lifecycle.
- `QM5_20268_xauxag-qtail-rv` ranks the current ratio against a frozen
  126-value rolling empirical distribution, requires a separate central-plus-
  two-tail event, and exits at a rolling median. This candidate ranks only
  the final close inside one completed month and has a fixed next-month exit.
- `QM5_41118_xauxag-mlatehalf-dom-rv` partitions adjacent relative returns
  into two cumulative halves and compares their magnitudes. This candidate
  uses close levels, no return-block partition, and no magnitude comparison.
- `QM5_41110_xauxag-moutside-res-rv` measures the share of completed-month
  ratios outside a prior-month range. This candidate has no parent-month
  range, residence count, or breakout boundary.
- `QM5_41103_xauxag-mrange-migrate-rv` compares two completed monthly ranges.
  This candidate reconstructs only the immediately completed month and ranks
  its final close.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a rolling center, regression, scale, robust score, or empirical
  tail. This candidate estimates none.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades an EURJPY/GBPJPY cointegration package.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only,
  two-day XNG oscillator pullback with no paired intermetal state.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, chronological close ratios, strict newest-
close uniqueness, fixed `ceil(n/4)` outer rank sets, contrarian rank direction,
consumed monthly attempt, equal-notional aggregate-risk package, and
next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_CLOSE_QUARTILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_CLOSE_QUARTILE_TRANSLATION_RISK`: peer-reviewed DOI and
  official-exchange lineage, named authors, complete governed records, and
  durable hashes; the untested rank state is disclosed and no result
  transfers.
- R2 `PASS`: synchronized month membership, ordering, exact rank and quartile
  arithmetic, tie rule, sides, attempt, risk, stops, atomicity, and lifecycle
  are locked before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state supply
  every runtime input; Q02 owns history, holiday attrition, density, costs,
  fills, financing, and CFD-basis sufficiency.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms, integer
  ranks, comparisons, ATR, quotes, positions, deals, and terminal state only;
  no trained logic, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Frequency, Portfolio Claim, And Falsification

The fixed outer-rank sets are expected to select approximately five to seven
completed paired packages per full post-warm-up year. This is a combinatorial
prior, not test evidence. Q02 retires below the unchanged five-trades/year/
symbol floor, at zero trades or nonpositive governed economics, or on any
synchronization, month, ordering, uniqueness, rank, quartile, side, attempt,
risk, atomicity, lifecycle, or determinism defect.

The opposite equal-notional legs are intended to suppress common outright-
metal direction. They do not prove beta, factor, volatility, market, or
portfolio neutrality. Q09 alone may establish realized correlation with the
certified XAU/SP500/NDX/XNG book. No decorrelation, admission, replacement, or
waiver claim is made here.

No weak result may be rescued by changing the quartile definition, accepting
ties, reversing the side, changing the hold, loosening session bounds, or
adding a fitted center, scale, return, volatility, volume, calendar, event,
external, or prior-result state.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
