# XAU/XAG Monthly Outside-Range Residence Reversion - Source Approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and basket-magic allocation, one branch-only non-live build, strict Q01
validation, and one paced logical-basket Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on the `agents/board-advisor` branch on 2026-08-22. The
mission explicitly names a market-neutral `XAUUSD` / `XAGUSD` gold/silver
ratio-reversion basket as an allowed carrier, requires one new non-duplicate
structural low-frequency edge under the reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-moutside-res-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: persistent one-sided residence of the newest completed month's
  synchronized daily-close log ratio beyond the parent completed month's
  observed ratio range
- direction: fade the persistent outside-range displacement as one
  equal-notional package
- lifecycle: one consumed attempt at each broker-month boundary and
  first-later-month paired flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
   covering Karsten Schweikert (2018), *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and the supplemental robust
   fractional-cointegration lineage recorded there.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   covering CME Group's gold/silver ratio-spread research.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026/source.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relationship rather than assuming one immutable equilibrium. CME defines the
ratio and supports treating gold and silver as one intermarket relative-value
carrier. Neither source tests completed-month outside-range residence, a
five-session persistence floor, the contrarian direction, Darwinex continuous
CFDs, equal-notional sizing, ATR stops, or this lifecycle. Those are disclosed
QM choices. No efficacy, density, neutrality, CFD-equivalence, or
decorrelation result transfers.

## Locked Mechanic

1. Repair orphan, duplicate, same-side, wrong-symbol, wrong-magic, stopless,
   notional-invalid, later-month, or stale owned exposure before entry gates.
2. Require exact `XAUUSD.DWX` D1 host, exact `XAGUSD.DWX` D1 companion,
   synchronized timestamps, and locked backtest/news/Friday inputs.
3. On the first tradable D1 bar of a broker-calendar month, within 180 elapsed
   minutes of the raw host-bar open, reconstruct the immediately completed
   month and its consecutive parent month. Require 17 through 23 unique,
   strictly ordered, timestamp-identical D1 sessions in each month and exclude
   every current-month bar.
4. For every synchronized session compute only
   `r=log(XAUUSD.DWX close)-log(XAGUSD.DWX close)`. Require finite positive
   closes. From the parent month aggregate the strict observed range
   `[parent_min,parent_max]`.
5. In the newest completed month count closes strictly above `parent_max` and
   strictly below `parent_min`. SELL XAU / BUY XAG only when at least five
   closes are above, none is below, and the chronological final close remains
   above `parent_max`. BUY XAU / SELL XAG only for the exact lower-side mirror.
   Equality, fewer than five outside closes, any opposite-side breach, a final
   close back inside, invalid arithmetic, incomplete history, non-adjacent
   months, or timestamp disagreement is flat.
6. Persist the current `yyyymm` attempt before history, spread, quote, ATR,
   sizing, news, or order gates. A rejected or failed attempt may not retry
   that month.
7. Target one-to-one absolute entry notional with at most 20 percent lot-step
   mismatch. Constrain combined broker-normalized stop risk to one
   `RISK_FIXED=1000` package.
8. Attach one frozen `3.5*ATR(20,D1)` stop per leg, no target, and require
   XAU/XAG spreads at or below 1,500/500 points respectively.
9. Keep both news axes and Friday close OFF. Close the complete package at the
   first tick of a later broker-calendar month or after forty elapsed calendar
   days. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_OUTSIDE_RANGE_TRANSLATION_RISK`: one bounded source
  lineage carries a named peer-reviewed DOI and official exchange research;
  outside-range residence and its fade are explicitly untested QM hypotheses.
- R2 `PASS`: month adjacency, synchronized session membership, log-ratio
  construction, parent range, outside counts, one-sided persistence, final
  close, side, attempt, aggregate risk, spreads, and lifecycle are locked and
  mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 histories supply every runtime input; Q02 owns alignment, session
  sufficiency, fill, cost, density, and continuous-CFD basis falsification.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical `research_dedup_check.py` scan covered 4,599 registry rows and
1,278 repository cards and found no exact or fuzzy match. Its configured
optional Strategy-Wiki root was unavailable, so the receipt honestly remains
`INPUT_ERROR_FAIL_CLOSED` rather than claiming a false clean result:
`artifacts/qm5_xauxag_moutside_res_rv_preallocation_dedup_20260822.json`.
The same unavailable-wiki limitation is recorded in the immediately preceding
OWNER-approved commodity builds; it does not substitute for the manual family
review below.

Repository-wide exact and semantic review distinguishes:

- `QM5_20157_xau-xag-ratio`, which fades a rolling 60-day ratio z-score and
  exits at a rolling center rather than using complete calendar-month ranges;
- `QM5_20161_xauxag-ols-rv`, which fits a rolling OLS hedge residual rather
  than using a fixed unit log ratio or calendar packages;
- `QM5_20254_xauxag-vr-fade`, which gates a daily ratio z-score with a robust
  monthly variance-ratio statistic;
- `QM5_41079_xauxag-wclose-extreme-rv`, which ranks one final weekly ratio
  close inside the same week's range and counts no residence sessions;
- `QM5_41085_xauxag-wdaybreadth-rv`, which counts within-week adjacent
  relative-return signs rather than observations outside a parent range;
- `QM5_41103_xauxag-mrange-migrate-rv`, which compares both range endpoints
  across months and does not count newest-month closes beyond the parent;
- `QM5_41104_xauxag-mmedian-shift-rv`, which compares two monthly medians and
  has no parent-range boundary, outside count, or final-close persistence;
- `QM5_41109_xauxag-mmean-median-rv`, which compares the mean and median
  inside one completed month and uses no parent month; and
- `QM5_41093_wti-wclose-breakout-mom`, which follows one final direct-WTI
  weekly close outside a parent range rather than fading persistent residence
  of a two-leg monthly ratio.

The exact paired carrier, two synchronized completed calendar months, fixed
unit daily-close log ratio, parent-month observed range, at least five
newest-month closes beyond exactly one boundary, no opposite boundary breach,
final close still outside, contrarian package, durable monthly attempt,
equal-notional aggregate-risk sizing, and next-month exit are jointly
load-bearing. Verdict:
`NO_EXACT_XAUXAG_MONTHLY_OUTSIDE_RANGE_RESIDENCE_REVERSION_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to nine completed packages per full
post-warm-up year. Q02 must retire below five per year, at zero trades or
nonpositive governed economics, or on any synchronization, month membership,
ratio, parent-range, outside-count, one-sidedness, final-close, direction,
attempt, basket, risk, lifecycle, or determinism defect. No weak result may be
rescued by lowering the five-session floor, accepting an opposite-side breach
or inside final close, changing the direction or hold, using current-month
data, fitting a hedge ratio, or adding a ratio center, trend, season, calendar,
or volatility filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
