# XAU/XAG Completed-Week Leg-Divergence Reversion - Source Approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-21. The mission asks
for one new, non-duplicate, structural low-frequency commodity edge and
explicitly names a market-neutral `XAUUSD`/`XAGUSD` gold/silver reversion basket
as an allowed candidate. It requires reputable-source criteria and
`RISK_FIXED` backtests and excludes live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-wlegdiv-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  two-leg basket
- state: the two metals have strictly opposite signed returns across the same
  immediately completed broker week
- action: sell the weekly winner and buy the weekly loser for one broker week
- lifecycle: one persisted attempt per broker week and first-later-week flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
   which preserves named peer-reviewed DOI lineage for Karsten Schweikert
   (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-cointegration
   evidence from Yaya, Vo, and Olayinka (2021), *Resources Policy* 72, 102045,
   DOI `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   which records CME Group's definition of the gold/silver ratio, the
   intermarket-spread carrier, and the metals' differing macro drivers.

The bounded child extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026/source.md`.
No new online page, inaccessible content, inferred source table, or unrecorded
performance claim is used.

Schweikert supports testing a potentially state-dependent long-run
gold/silver relation rather than assuming a universal constant equilibrium.
CME supports treating gold and silver as one intermarket relative-value
carrier while noting their differing monetary and industrial sensitivities.
Neither source tests opposite individual weekly return signs, a one-week fade,
Darwinex continuous CFDs, equal-notional sizing, fixed cash risk, or ATR stops.
Those are declared QM falsification choices. No source return, density, hedge
ratio, cost, neutrality, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, slots
   zero and one, fixed-risk backtest inputs, both news axes OFF, and Friday
   close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its raw host-bar open, reconstruct the synchronized
   week-end close pair for each of the two immediately preceding consecutive
   broker weeks.
3. Compute the gold and silver log returns across the exact same completed
   weekly interval. Require both returns to be finite and strictly nonzero and
   their signs to be opposite. Gold positive with silver negative sells gold
   and buys silver. Gold negative with silver positive buys gold and sells
   silver. Equality, zero, same-sign returns, missing endpoints, or an
   asynchronous pair consumes the week flat.
4. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
5. Size an equal-absolute-notional two-leg package so combined normalized hard-
   stop risk cannot exceed one `RISK_FIXED=1000` budget. Freeze a
   `3.5 * ATR(20,D1)` stop on each leg, reject notional mismatch above 20
   percent, and use no target.
6. Close both legs on the first tick of a later broker week or after ten
   calendar days. Malformed or orphaned ownership flattens immediately. Never
   retry, trail, partially close, scale in, grid, martingale, pyramid, or read
   an external runtime feed.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,570 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual family review
separates this identity from the nearest cards:

- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268` use a
  rolling ratio center, fitted residual, robust score, or empirical tail. This
  candidate estimates no center, dispersion, hedge ratio, or threshold.
- `QM5_41030_xauxag-flowdiv` compares cross-metal close/open and open/close
  relative-flow components within a week. This candidate ignores session
  decomposition and tests the two metals' complete-week return signs.
- `QM5_41031_xauxag-goldlead` requires a one-day gold shock and bounded silver
  underresponse. This candidate is symmetric, weekly, threshold-free, and
  requires strictly opposite leg directions.
- `QM5_41040` and `QM5_41057` classify relative session/overnight flow. This
  candidate uses only synchronized completed week-end closes.
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify sequences of one
  gold-minus-silver relative return across two or more weeks. They do not
  require the individual gold and silver returns over one common week to have
  opposite signs.
- `QM5_41079_xauxag-wclose-extreme-rv` ranks daily ratio closes within one
  completed week. This candidate uses only the two synchronized week-end
  endpoint pairs and has no within-week rank.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades a four-leg EURJPY/GBPJPY cointegration package.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day
  oscillator pullback with no paired intermetal state.

The exact two-leg carrier, same synchronized completed weekly interval,
strictly opposite individual metal-return signs, contrarian relative-winner
side, consumed weekly attempt, equal-notional aggregate-risk package, and
next-week exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_WEEK_LEG_SIGN_DIVERGENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_LEG_STATE_TRANSLATION_RISK`: one bounded child source ID
  preserves peer-reviewed DOI and official-exchange lineage; the untested
  weekly leg-sign condition is disclosed and no performance claim transfers.
- R2 `PASS`: exact synchronized endpoints, individual-return orientation,
  strict opposite signs, sides, attempt, risk, stops, spread, atomicity, and
  lifecycle are locked before testing.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state supply every
  runtime input; Q02 owns label, history, density, and CFD-basis sufficiency.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms,
  comparisons, ATR, quotes, positions, deals, and terminal state only; no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Portfolio Claim Boundary

The candidate is one symmetric long/short intermetal package designed to
remove the common outright direction present in the completed signal week. An
equal-notional opposite-leg basket is not proof of beta, factor, volatility,
market, or portfolio neutrality. Q09 alone may establish realized correlation
with the certified XAU/SP500/NDX/XNG book. This approval makes no decorrelation,
admission, or replacement claim.

## Kill And Safety Boundary

Expected cadence is approximately eight to eighteen completed paired packages
per full post-warm-up year. Q02 must retire below five completed packages per
full year, at zero trades or nonpositive governed economics, or on any
synchronization, endpoint, sign, side, attempt, risk, atomicity, lifecycle, or
determinism defect. No weak result may be rescued by accepting a zero or
same-sign return, adding a magnitude threshold, changing direction or hold,
or adding a fitted center, volatility, volume, calendar, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and whole-host CPU checks are below their
ceilings. At the ceiling, stop before queue mutation and record a non-live
handoff.
