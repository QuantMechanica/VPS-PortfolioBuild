# XAU/XAG Monthly Ratio-Range Migration Reversion - Source Approval

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

- proposed slug: `xauxag-mrange-migrate-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-MRANGE-MIGRATE-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-MRANGE-MIGRATE-RV-2026`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: strict same-direction migration of both endpoints of the synchronized
  daily-close log-ratio range from the parent completed calendar month to the
  immediately completed calendar month
- direction: fade the migrated ratio range as one equal-notional package
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
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MRANGE-MIGRATE-RV-2026/source.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relationship rather than assuming one immutable equilibrium. CME defines the
ratio and supports treating gold and silver as one intermarket relative-value
carrier. Neither source tests completed-month daily-close ratio ranges,
two-endpoint range migration, the contrarian direction, Darwinex continuous
CFDs, equal-notional sizing, ATR stops, or this lifecycle. Those are disclosed
QM choices. No efficacy, density, neutrality, CFD-equivalence, or decorrelation
result transfers.

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
   closes. For each month aggregate `r_min` and `r_max` and require a strict
   positive range.
5. If both newest endpoints are strictly higher than the parent endpoints,
   sell gold and buy silver. If both are strictly lower, buy gold and sell
   silver. A mixed state, equality at either endpoint, invalid arithmetic,
   incomplete history, non-adjacent months, or timestamp disagreement is flat.
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

- R1 `PASS_WITH_MONTHLY_RATIO_RANGE_TRANSLATION_RISK`: one bounded source ID
  carries named peer-reviewed DOI and official exchange lineages; the monthly
  two-endpoint range-migration fade is explicitly an untested QM hypothesis.
- R2 `PASS`: month adjacency, synchronized session membership, log-ratio
  construction, range endpoints, strict migration, side, attempt, aggregate
  risk, spreads, and lifecycle are locked and mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 histories supply every runtime input; Q02 owns alignment, session
  sufficiency, fill, cost, and continuous-CFD basis falsification.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical `research_dedup_check.py` scan covered 4,592 registry rows,
1,271 repository cards, and 45 Strategy-Wiki nodes. It returned `CLEAN`, with
no exact or fuzzy match. The receipt is
`artifacts/qm5_xauxag_mrange_migrate_rv_preallocation_dedup_20260822.json`.
Manual family review distinguishes:

- `QM5_20157_xau-xag-ratio`, which fades a rolling 60-day ratio z-score and
  exits at a rolling center rather than using completed calendar-month ranges;
- `QM5_20161_xauxag-ols-rv`, which fits a rolling OLS hedge residual rather
  than using a fixed unit log ratio or calendar packages;
- `QM5_20202_xauxag-rev18`, which ranks eighteen-month per-leg returns rather
  than ratio-range endpoints;
- `QM5_20254_xauxag-vr-fade`, which gates a daily ratio z-score with a robust
  monthly variance-ratio statistic;
- `QM5_41079_xauxag-wclose-extreme-rv`, which ranks one final weekly ratio
  close inside the same week rather than comparing two monthly ranges;
- `QM5_41066`, `QM5_41075`, `QM5_41076`, and `QM5_41077`, which classify two
  adjacent completed-week relative-return signs and magnitudes; and
- `QM5_41102_wti-mrange-migrate-mom`, which follows direct WTI aggregate
  monthly high/low migration and never constructs or trades a two-leg ratio.

The exact paired carrier, two consecutive synchronized completed calendar
months, daily-close log-ratio ranges, strict migration of both ratio-range
endpoints, contrarian package, monthly attempt, equal-notional aggregate-risk
sizing, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_RATIO_RANGE_MIGRATION_REVERSION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to nine completed packages per full
post-warm-up year. Q02 must retire below five per year, at zero trades or
nonpositive governed economics, or on any synchronization, month membership,
ratio-range, threshold, direction, attempt, basket, risk, lifecycle, or
determinism defect. No weak result may be rescued by accepting equality or
mixed migration, changing the direction or hold, relaxing month membership,
using current-month data, fitting a hedge ratio, or adding a ratio center,
trend, season, calendar, or volatility filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
