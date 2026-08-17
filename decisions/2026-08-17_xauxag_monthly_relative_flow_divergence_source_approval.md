# XAU/XAG Monthly Relative-Flow Divergence - Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue if CPU capacity permits. This decision does not
authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission explicitly requests a new
market-neutral or structural low-frequency commodity sleeve, identifies an
XAU/XAG logical basket as an allowed carrier, requires reputable-source
criteria and `RISK_FIXED` backtests, and forbids live and portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `xauxag-mflow-div`
- proposed strategy ID:
  `WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026_S01`
- proposed source ID: `WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  opposite-leg package
- decision clock: first executable synchronized D1 tick of a new broker month
- price state: gold-minus-silver completed prior-month close-to-open flow and
  gold-minus-silver completed prior-month open-to-close flow
- lifecycle: require strict relative-component opposition, follow the
  session-relative sign, and renew the pair at the next broker-month boundary

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded source lineages below were read completely before approval and
card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   page-15-to-30 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define public flow as
   prior close to current open and professional flow as current open to
   current close. Williams says separately accumulated lines can reveal what
   is happening and identifies divergence as potentially useful. He does not
   test gold/silver, monthly relative aggregation, or this direction rule.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. The complete governed
   packets at
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` and
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md` support a
   state-dependent gold/silver relationship and warn against assuming one
   constant, automatically tradable equilibrium.
3. CME Group, "Gold & Silver Ratio Spread" and related precious-metals
   material, governed at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME defines the
   intermarket carrier and documents common precious-metals drivers alongside
   gold's greater monetary/safe-haven sensitivity and silver's greater
   industrial sensitivity.
4. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` establish a pooled
   commodity one-month formation and one-month hold family. They do not split
   gold-minus-silver returns by information time or validate this basket.

No source tests the exact conjunction, Darwinex continuous CFDs, synchronized
broker timestamps, equal-notional sizing, fixed cash risk, ATR stops, or the
QM portfolio. No source performance, significance, density, pair-only
efficacy, transaction cost, drawdown, CFD equivalence, neutrality,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable synchronized D1 tick of each new broker month:

1. Repair malformed, duplicate, orphaned, or stale owned exposure before
   entry-only gates.
2. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, matching
   current D1 timestamps, and a shared current D1 date equal to the broker
   date. No label shifting or per-bar repair is allowed.
3. Persist the exact broker `yyyymm` attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. A late attachment consumes the
   month flat; it may not retry or backfill.
4. Require the first observation within 180 minutes of the synchronized D1
   open.
5. Reconstruct the immediately completed broker month on both metals plus its
   preceding month-end anchor. Require 15-25 synchronized completed sessions,
   positive finite OHLC endpoints, exact cross-symbol timestamp equality,
   strict timestamp order, and consecutive month keys.
6. For every prior-month session compute separately for each metal:
   `overnight += log(Open[d] / Close[prior_session])` and
   `session += log(Close[d] / Open[d])`.
7. Define `overnight_relative = xau_overnight - xag_overnight` and
   `session_relative = xau_session - xag_session`. Reconcile each metal's
   total and the relative total to their completed month-end returns within
   `1e-10`.
8. Require strict relative-component opposition. Positive session-relative
   flow with negative overnight-relative flow buys XAU and sells XAG;
   negative session-relative flow with positive overnight-relative flow sells
   XAU and buys XAG. Agreement, exact zero, invalid arithmetic, or failed
   reconciliation consumes the month flat. Magnitude never changes size.
9. Target equal absolute USD notionals, round volumes down, reject mismatch
   above 20%, and keep the combined frozen-stop loss within one
   `RISK_FIXED=1000` package budget. Use per-leg `3.5 * ATR(20,D1)` hard
   stops, 1,500-point spread ceilings, and no target.
10. Keep both news axes OFF and framework Friday close disabled. Close both
    legs together at the first observed next-month boundary, after 40
    calendar days, or when package state is malformed. Never retry, scale in,
    pyramid, grid, martingale, or use an external runtime feed.

The synchronized immediately completed month, every component endpoint,
gold-minus-silver subtraction, strict opposition, session-relative direction,
reconciliation, monthly attempt, equal-notional opposite legs, aggregate
fixed risk, and month-to-month lifecycle are load-bearing. No ratio level,
center, scale, regression, quantile, stationarity test, magnitude threshold,
volatility gate, season, weekday selector, moving line, or crossover is
authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one complete OWNER-supplied
  Tier-A practitioner extraction, one peer-reviewed gold/silver relationship
  lineage, one complete-read peer-reviewed commodity monthly-hold lineage,
  and one governed exchange carrier packet, with the untested conjunction and
  adverse scope explicit.
- R2 `PASS`: synchronized month identity, all completed endpoints, relative
  component sums, opposition, reconciliation, sides, attempt state, timing,
  joint sizing, risk, stops, spreads, and exit are deterministic and locked.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 state supply every runtime input. The
  logical Q02 window must be synchronized for both carriers.
- R4 `PASS`: timestamps, calendar, OHLC, logarithms, arithmetic, ATR risk
  plumbing, quotes, positions, deal history, and terminal state only; no
  trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,526 EA-registry rows and 623 root
cards. It found no exact identity and one expected fuzzy family neighbor.
Manual semantic review fixes these boundaries:

- `QM5_41030_xauxag-flowdiv` uses one exact synchronized completed
  Monday-Friday week, decides on the next Monday, and closes Friday. This
  candidate consumes every session in one completed broker month, decides
  only at a new-month boundary, and holds to the next month. Weekly and
  monthly endpoint sets, attempt keys, exposure paths, and lifecycle are
  non-interchangeable.
- `QM5_41037_xng-mflow-div` uses a monthly close/open decomposition on one
  directional XNG leg. This candidate subtracts synchronized silver flow from
  gold flow and must execute one equal-notional opposite-leg package.
- `QM5_20057_xauxag-xmom1`, `QM5_20050_xauxag-xmom12`, and
  `QM5_20184_xauxag-xmom3` rank completed close-to-close returns and follow
  the stronger metal. This candidate admits only opposed information-time
  components and follows session-relative flow, which can differ from the
  completed relative-total sign.
- Ratio, OLS, MAD, empirical-tail, failed-break, seasonal-surprise, and CADF
  systems trade relative levels or fitted residuals. This candidate estimates
  no ratio level, center, scale, regression, quantile, or stationarity state.
- `QM5_41031_xauxag-goldlead` uses one completed gold-led daily shock and a
  one-session silver catch-up hold, not a monthly two-component relative-flow
  state.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a synchronized symmetric logical basket.

Verdict:
`CLEAN_XAUXAG_MONTHLY_RELATIVE_FLOW_DIVERGENCE_AFTER_CADENCE_CARRIER_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to eight completed packages per full
post-warm-up year. Q02 must retire on zero trades, fewer than five/year, wrong
month identity or endpoints, current-bar leakage, component agreement, wrong
sides, failed reconciliation, late or repeated entry, excess notional
mismatch, orphan survival, wrong lifecycle, nondeterminism, invalid risk mode,
or nonpositive governed economics. Source-to-rule distance, futures/CFD
basis, month-boundary gaps, financing, legging, hedge drift, and later book
correlation are first-order risks. Q09 alone may establish realized
correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
neutrality claims; and correlation waivers. Q02 may be enqueued once if CPU
capacity permits. If the factory resource ceiling is binding, do not
dispatch, reserve, stop, reap, reprioritize, or otherwise control a tester.
