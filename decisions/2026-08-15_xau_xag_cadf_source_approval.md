# XAU/XAG Annual CADF Residual Reversion — Source Approval

Date: 2026-08-15

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Q02 enqueue is not authority to dispatch a
manual tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch. The mission explicitly permits an
`XAUUSD~XAGUSD` market-neutral ratio-reversion basket, requires a genuinely
new structural low-frequency edge, reputable-source criteria, and
`RISK_FIXED` backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `xau-xag-cadf`
- proposed strategy ID: `CHAN-SCHWEIKERT-XAUXAG-CADF-2026_S01`
- proposed source ID: `CHAN-SCHWEIKERT-XAUXAG-CADF-2026`
- host/traded slot 0: `XAUUSD.DWX`, D1
- companion/traded slot 1: `XAGUSD.DWX`, D1
- logical topology: one opposite-leg gold/silver residual-reversion package
- signal: a fresh standardized residual crossing from an annual walk-forward
  252-observation log-gold-on-log-silver OLS model, admitted only when its
  residual passes the locked one-lag CADF and fitted half-life gates

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following complete governed repository evidence was read before this
decision:

1. Ernest P. Chan (2009), *Quantitative Trading: How to Build Your Own
   Algorithmic Trading Business*, Wiley, ISBN 978-0-470-28488-9. The complete
   bounded extraction of Examples 3.6, 7.2, 7.3, and 7.5 and the surrounding
   stationarity discussion is preserved at
   `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`, SHA-256
   `183A1624AE3EB4432DDE9BA8883E3F5B16E0107A191E468864CA9600D8D45D64`.
   The source family was CEO-ratified on 2026-04-28. It supplies OLS hedge
   fitting, CADF qualification, frozen training statistics, standardized
   spread reversion, mean-band exit, and fitted half-life discipline.
2. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, the
   OWNER-approved bounded packet for Schweikert (2018), *Journal of Banking &
   Finance* 88, DOI `10.1016/j.jbankfin.2017.11.010`, and Yaya, Vo, and
   Olayinka (2021), *Resources Policy* 72, DOI
   `10.1016/j.resourpol.2021.102045`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
   It supplies peer-reviewed gold/silver long-run-relation and
   state-dependence context.
3. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, the governed CME
   carrier packet, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   It establishes the gold/silver ratio as a traded intermarket spread and
   records the metals' shared and distinct drivers.

No fresh public-page text, proxy, cache, authentication, or unavailable
content is used. These governed packets are the source evidence of record.

Chan's worked carrier is GLD/GDX, not spot gold/silver. The peer-reviewed
gold/silver papers do not prescribe this walk-forward trading rule. CME does
not establish current cointegration or efficacy. The two-CFD carrier,
timestamp synchronization, annual refit convention, log-price orientation,
hard stops, spread limits, aggregate risk split, atomic repair, and restart
behavior are transparent QM translations. No source return, Sharpe ratio,
coefficient, significance, trade density, drawdown, cost, CFD equivalence,
neutrality, decorrelation, or portfolio result transfers.

## Locked Mechanic

For each broker calendar year, fit one model from the 252 synchronized
completed D1 observations immediately preceding that year's first host D1
bar. The model is reconstructed from the same historical anchor after a
restart and remains frozen for the rest of the year:

1. Fit `log(XAU) = alpha + beta * log(XAG) + residual` by closed-form OLS with
   an intercept. Require finite nonsingular arithmetic and beta in
   `[0.10, 3.00]`.
2. Regress residual changes on lagged residual level, one lagged residual
   change, and an intercept. Require the lagged-level t-statistic to be no
   greater than `-3.343`, matching the governed 5% two-variable CADF boundary.
3. Fit the source-aligned OU adjustment from residual changes on demeaned
   lagged residuals. Require a strictly negative coefficient and a half-life
   in `[2, 30]` D1 observations.
4. Freeze alpha, beta, residual mean, residual sample standard deviation,
   CADF statistic, and half-life for the broker year. The annual signal stream
   may not slide or refit intrayear.
5. Standardize the latest two synchronized completed residuals with the
   frozen mean and scale. A fresh cross above `+1.0` sells gold and buys
   silver; a fresh cross below `-1.0` buys gold and sells silver. An
   already-extreme, tied, missing, stale, desynchronized, or invalid state
   remains flat and cannot retry the same excursion.
6. Open at most one opposite-leg package with aggregate `RISK_FIXED=1000`,
   `RISK_PERCENT=0`. Split stop risk in relative weights `1.0` for gold and
   `abs(beta)` for silver, normalize the shares, and attach one frozen
   `3.5 * ATR(20,D1)` hard stop to each leg. Signal magnitude never scales
   risk.
7. Close both legs when `abs(z) <= 0.5`, the frozen model or synchronized
   package becomes invalid, or `ceil(half_life)` calendar days elapse. Open
   gold first and silver second, and immediately flatten all owned exposure
   after any partial-open or final-package validation failure.

Friday close and all news modes are OFF for the source-aligned multi-session
hold. The carrier, annual anchor, log orientation, observation count, OLS
intercept, one-lag CADF form and boundary, half-life gate, fresh crossing,
paired direction, aggregate risk, and atomic lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS`: a CEO-ratified complete Wiley extraction, two identified
  peer-reviewed gold/silver sources in an OWNER-approved bounded packet, and
  a governed CME carrier reference.
- R2 `PASS`: anchor, history, estimators, statistical gates, direction,
  lifecycle, aggregate risk, stops, spreads, and repair are deterministic and
  locked before Q02.
- R3 `PASS`: registered XAUUSD.DWX and XAGUSD.DWX D1 routes supply every
  runtime input; Q02 owns synchronized-history, stationarity, density, fill,
  and economics proof.
- R4 `PASS`: native arithmetic and framework state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker found no exact registry or card identity
and one expected fuzzy family match, `QM5_21525_wti-xcu-cadf`. Manual review
fixes the boundaries:

- `QM5_20161_xauxag-ols-rv` refits a 120-D1 OLS model every bar, has no CADF
  admission test or fitted half-life, enters any extreme rather than only a
  fresh crossing, and uses a fixed sixty-day exit. This candidate freezes one
  252-observation model at the calendar-year anchor and trades only when both
  stationarity gates pass.
- `QM5_12577_cme-xauxag-ratio` standardizes a fixed-beta raw log ratio and has
  no fitted hedge, CADF, or half-life state.
- `QM5_13205_xau-xag-qc` fits conditional quantile envelopes monthly and does
  not use a CADF-qualified frozen OLS residual.
- `QM5_1017_chan_pairs_stat_arb` is the approved method lineage but its
  concrete built carrier is AUDUSD/NZDUSD with different slots, quotes,
  contract sizes, and return driver. This card is the separately declared
  gold/silver carrier and is not a fan-out of the existing work item.
- `QM5_21525_wti-xcu-cadf` uses a rolling WTI/copper model and a different
  energy/industrial-metal carrier. It does not freeze an annual precious-
  metals equilibrium or use the Chan 5% one-lag CADF specification here.

Verdict:
`CLEAN_XAU_XAG_ANNUAL_CADF_HALFLIFE_RESIDUAL_REVERSION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eight to twenty completed packages per
full post-warm-up year. Q02 must retire below five/year, on zero trades,
persistent failure of the CADF/half-life gate, or nonpositive governed
economics. Q09 alone may establish realized correlation with the certified
book. Opposite sides and beta-weighted stop risk do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02
may be enqueued once. If the factory resource ceiling is binding, do not
dispatch, reserve, stop, reap, reprioritize, or otherwise control a tester.
