# XAU/XAG Completed-Month Daily Relative-Sign Breadth Reversion - Source Approval

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

- proposed slug: `xauxag-mdaybreadth-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  two-leg basket
- state: a strict majority of all synchronized daily relative returns in the
  immediately completed broker-calendar month shares the completed-month
  relative-return sign
- action: fade that broadly participated completed-month gold/silver-ratio
  displacement for the next broker-calendar month
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
   evidence from Yaya, Vo, and Olayinka (2021), *Resources Policy* 72, 102045,
   DOI `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   which records CME Group's definition of the gold/silver ratio, its
   intermarket-spread carrier, and the metals' differing monetary and
   industrial sensitivities.

No new online page, inaccessible content, inferred source table, or
unrecorded performance claim is used.

Schweikert supports testing a potentially state-dependent long-run
gold/silver relation rather than assuming one universal equilibrium. CME
supports treating gold and silver as an intermarket relative-value carrier.
Neither source tests synchronized daily relative-sign breadth inside a
completed month, a strict-majority rule, endpoint agreement, a one-month fade,
Darwinex continuous CFDs, fixed cash risk, or equal-notional execution. Those
are declared QM falsification choices. No source return, density, hedge ratio,
cost, neutrality, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, slots
   zero and one, fixed-risk backtest inputs, both news axes OFF, and Friday
   close OFF.
2. On the first tradable synchronized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw host-bar open, reconstruct two
   immediately preceding consecutive completed calendar months. Require 17
   through 23 unique synchronized close pairs in each month and no current-
   month observation.
3. Use the parent month's chronological final synchronized log ratio as the
   first return anchor. For every synchronized close pair in the immediately
   completed month, compute the chronological gold-minus-silver relative log
   return from that anchor or the preceding close pair. Flat relative returns
   remain in the session denominator and count toward neither sign.
4. When a strict majority of those relative returns is positive and the final
   completed-month ratio is above the parent anchor, sell gold and buy silver.
   When a strict majority is negative and the final ratio is below the parent
   anchor, buy gold and sell silver. Equality, disagreement, asynchronous
   history, mixed month labels, or invalid endpoints consumes the month flat.
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

## Non-Duplicate Decision

The fail-closed pre-allocation checker scanned 4,608 registry identities,
1,280 repository cards, and 45 Strategy-Wiki nodes and returned `CLEAN`, with
no exact or fuzzy match. Evidence:
`artifacts/qm5_xauxag_mdaybreadth_rv_preallocation_dedup_20260822.json`.

Manual family review separates this identity from the nearest cards:

- `QM5_41085_xauxag-wdaybreadth-rv` requires one exact five-session broker
  week, four-of-five relative signs, and a one-week hold. This candidate uses
  two complete 17-to-23-session calendar months, every newest-month relative
  return, strict majority, and a next-month hold.
- `QM5_20275_gsr-runfade` classifies a fixed six-return run over a short rolling
  window rather than all relative returns in one calendar month.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268` estimate
  a rolling center, regression, scale, robust score, or empirical tail. This
  candidate estimates none.
- `QM5_41103_xauxag-mrange-migrate-rv`,
  `QM5_41104_xauxag-mmedian-shift-rv`,
  `QM5_41109_xauxag-mmean-median-rv`, and
  `QM5_41110_xauxag-moutside-res-rv` classify monthly range, location, or
  distribution geometry rather than adjacent relative-return signs.
- `QM5_41030`, `QM5_41040`, and `QM5_41057` decompose overnight and session
  relative flows rather than synchronized close-to-close monthly paths.
- `QM5_41111_wti-mdaybreadth-mom` uses a single outright WTI carrier and
  follows its own daily-sign majority. This candidate trades two synchronized
  metals, fades their relative move, and targets equal notionals.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades a EURJPY/GBPJPY cointegration package.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only,
  two-day XNG oscillator pullback with no paired intermetal state.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, every newest-
month relative-return sign, flat-return denominator, strict majority,
same-sign endpoint displacement, contrarian package direction, consumed
monthly attempt, equal-notional aggregate-risk package, and next-month exit
are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_RELATIVE_SIGN_MAJORITY_NET_AGREEMENT_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK`: one bounded child
  source ID will preserve peer-reviewed DOI and official-exchange lineage;
  the untested breadth condition is disclosed and no performance result
  transfers.
- R2 `PASS`: synchronized month labels, endpoints, return orientation, flat
  handling, strict majority, endpoint agreement, sides, attempt, risk, stops,
  spread, atomicity, and lifecycle are locked before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state supply all
  runtime inputs; Q02 owns history, holiday attrition, density, cost, fill,
  financing, and CFD-basis sufficiency.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms, counting,
  comparisons, ATR, quotes, positions, deals, and terminal state only; no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Portfolio Claim Boundary

The candidate is one symmetric long/short intermetal package designed to
reduce common outright-metal direction in the signal. Equal-notional opposite
legs are not proof of beta, factor, volatility, market, or portfolio
neutrality. Q09 alone may establish realized correlation with the certified
XAU/SP500/NDX/XNG book. This approval makes no decorrelation, admission, or
replacement claim.

## Kill And Safety Boundary

Expected cadence is approximately seven to ten completed paired packages per
full post-warm-up year. Q02 must retire below five completed packages per full
year, at zero trades or nonpositive governed economics, or on any
synchronization, month-boundary, endpoint, return-orientation, flat handling,
majority/net, side, attempt, risk, atomicity, lifecycle, or determinism defect.
No weak result may be rescued by changing session bounds, deleting flat
returns, accepting majority equality, removing endpoint agreement, changing
direction or hold, or adding a fitted center, volatility, volume, calendar,
event, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and whole-host CPU checks are below their
ceilings. At the ceiling, stop before queue mutation and record a non-live
handoff.
