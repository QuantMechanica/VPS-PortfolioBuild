# XAU/XAG Weekly Common-Shock Dispersion Reversion - Source Approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-21. The mission asks
for one new, non-duplicate, structural low-frequency commodity edge and
explicitly allows a market-neutral `XAUUSD`/`XAGUSD` gold/silver reversion
basket. It requires reputable-source criteria and `RISK_FIXED` backtests and
excludes live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-commonshock-rv`
- proposed strategy ID:
  `SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  two-leg basket
- state: both metals have strict same-sign individual log returns over the
  immediately completed broker week
- action: sell the relative outperformer and buy the relative underperformer
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
   evidence from Yaya, Vo, and Olayinka (2021), *Resources Policy* 72,
   102045, DOI `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   which records CME Group's definition of the gold/silver ratio, the
   intermarket-spread carrier, and the metals' differing monetary and
   industrial drivers.

The bounded child extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026/source.md`.
No new online page, inaccessible content, inferred source table, or
unrecorded performance claim is used.

Schweikert supports testing a potentially state-dependent long-run
gold/silver relation rather than assuming one constant equilibrium. CME
supports treating gold and silver as one intermarket relative-value carrier
while noting their differing macro sensitivities. Neither source tests a
same-direction completed-week filter, symmetric relative-outperformer fade,
one-week hold, continuous CFDs, or equal-notional fixed-dollar risk. Those are
declared QM falsification choices. No source alpha, density, hedge ratio,
neutrality, cost, CFD equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, slots
   zero and one, fixed-risk backtest inputs, both news axes OFF, and Friday
   close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its raw host-bar open, reconstruct synchronized final
   close pairs for the immediately completed week and its consecutive parent
   week. Each completed week must contain three to five synchronized sessions.
3. Compute one completed weekly log return independently for gold and silver.
   Require both returns to be strictly positive or both strictly negative.
   A zero, mixed-sign state, equality of the individual returns, missing
   endpoint, asynchronous bar, or invalid week consumes the week flat.
4. When gold's completed return is strictly greater than silver's, sell gold
   and buy silver. When gold's return is strictly smaller, buy gold and sell
   silver. The side always fades the completed relative outperformance.
5. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
6. Size an equal-absolute-notional two-leg package so combined normalized
   hard-stop risk cannot exceed one `RISK_FIXED=1000` budget. Freeze a
   `3.5 * ATR(20,D1)` stop on each leg, reject notional mismatch above 20
   percent, and use no target.
7. Close both legs on the first tick of a later broker week or after ten
   calendar days. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately. Never retry, trail,
   partially close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,573 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual family review
separates this identity from the nearest cards:

- `QM5_41031_xauxag-goldlead` is an asymmetric one-D1 gold-lead event: gold
  alone must exceed 75 basis points and silver must respond by less than half;
  silver can never lead. This candidate is symmetric across the legs, uses a
  complete broker week, has no magnitude or response-fraction threshold, and
  requires the individual returns to share a strict sign.
- `QM5_41083_xauxag-wlegdiv-rv` admits only opposite-sign individual weekly
  metal returns. This candidate admits only same-sign individual weekly
  returns; the state spaces are disjoint.
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify two or more
  completed gold-minus-silver weekly returns by acceleration, retracement,
  overshoot, or streak. This candidate uses one weekly return per individual
  leg and no multiweek relative path.
- `QM5_41057_xauxag-wflow-agree-fade` decomposes weekly close-to-open and
  open-to-close relative flows and requires their agreement. This candidate
  reads only synchronized completed-week final endpoints and individual-leg
  directions.
- `QM5_41085_xauxag-wdaybreadth-rv` counts five within-week relative-return
  signs and requires an exact five-session week. This candidate counts no
  daily signs and allows a synchronized three-to-five-session completed week.
- rolling ratio/residual cards (`QM5_12577`, `QM5_20157`, `QM5_20161`,
  `QM5_20263`, and `QM5_20268`) estimate a center, regression, scale, score,
  or tail. This candidate estimates none.
- `QM5_12533` supplies only the validated logical-basket manifest/order
  recipe, while `QM5_12567` is a single-symbol long-only two-day oscillator
  pullback.

The exact paired carrier, consecutive synchronized completed-week endpoints,
strict same-sign individual returns, symmetric relative-outperformer fade,
durable weekly attempt, equal-notional aggregate-risk package, and next-week
exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_SAME_DIRECTION_WEEKLY_COMMON_SHOCK_RELATIVE_OUTPERFORMER_FADE_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMMON_SHOCK_TRANSLATION_RISK`: one bounded child source ID
  preserves peer-reviewed DOI and official-exchange lineage; the same-sign
  weekly fade is disclosed as an untested QM translation.
- R2 `PASS`: week anchors, synchronized endpoints, return orientation, strict
  sign/equality handling, symmetric sides, attempt, risk, stops, spread caps,
  atomicity, and lifecycle are locked before testing.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state supply every
  runtime input; Q02 owns history, holiday-week, density, and CFD-basis
  sufficiency.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms,
  comparisons, ATR, quotes, positions, deals, and terminal state only; no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Portfolio Claim Boundary

The candidate is one symmetric long/short intermetal package designed to
remove the shared outright metals direction from the entry state. A same-sign
formation filter and equal-notional opposite legs are not proof of beta,
factor, volatility, market, or portfolio neutrality. Q09 alone may establish
realized correlation with the certified XAU/SP500/NDX/XNG book. This approval
makes no decorrelation, admission, or replacement claim.

## Kill And Safety Boundary

Expected cadence is approximately fifteen to thirty-five completed paired
packages per full post-warm-up year. Q02 must retire below five completed
packages per full year, at zero trades or nonpositive governed economics, or
on any synchronization, endpoint, session-count, return-orientation,
same-sign, side, attempt, risk, atomicity, lifecycle, or determinism defect.
No weak result may be rescued by accepting mixed signs, adding a return-size
threshold, changing the side or hold, or fitting a center, volatility, volume,
calendar, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and whole-host CPU checks are below their
ceilings. At the ceiling, stop before queue mutation and record a non-live
handoff.
