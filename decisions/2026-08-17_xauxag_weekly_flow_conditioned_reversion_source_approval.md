# XAU/XAG Weekly Flow-Conditioned Relative Reversion - Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue if factory capacity permits. This decision does
not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission explicitly requests one new
market-neutral or structural low-frequency commodity sleeve, names an
XAUUSD/XAGUSD logical basket as an allowed carrier, requires reputable-source
criteria and `RISK_FIXED` backtests, and forbids live and portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `xauxag-wflow-fade`
- proposed strategy ID:
  `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026_S01`
- proposed source ID: `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  opposite-leg package
- decision clock: first executable synchronized broker Monday following one
  exact completed Monday-through-Friday week
- price state: gold-minus-silver completed close-to-open flow versus
  gold-minus-silver completed open-to-close flow
- lifecycle: require strict component opposition and session dominance, fade
  the completed relative week, and flatten both legs on broker Friday

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through the OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and its bounded page-15-to-30 text.
   Williams separates prior-close-to-open and open-to-close price flows,
   accumulates them independently, and treats disagreement as potentially
   informative. He does not test gold/silver, weekly relative aggregation,
   session dominance, or relative-value reversion.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, through the complete-read
   governed packets at
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` and
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`. The paper supports a
   state-dependent gold/silver relation and supplies adverse evidence against
   treating one constant equilibrium as automatically tradable.
3. CME Group, "Gold & Silver Ratio Spread" and related precious-metals
   material, governed at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME defines the
   intermarket carrier and documents shared precious-metals drivers alongside
   gold's greater monetary/safe-haven sensitivity and silver's greater
   industrial sensitivity.
4. The already governed weekly relative-flow source packet at
   `strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026/source.md`.
   It fixes the exact synchronized Monday-through-Friday endpoints and records
   the full source-to-CFD translation boundary. Its session-following trade is
   not inherited; this approval isolates a different, contrarian conditional
   mechanic.

No source tests the exact conjunction, the session-dominance selector, the
fade direction, Darwinex continuous CFDs, exact synchronized broker labels,
equal-notional sizing, fixed cash risk, ATR stops, or this portfolio. No
source performance, significance, density, transaction cost, drawdown, CFD
equivalence, neutrality, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable synchronized D1 tick of a genuine broker Monday:

1. Repair malformed, duplicate, orphaned, wrong-side, or stale owned exposure
   before all entry-only gates.
2. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, matching
   current-bar timestamps, and shared current D1 date equal to the broker
   Monday. No label shifting or per-bar repair is allowed.
3. Persist the exact broker Monday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. A late attachment consumes
   the week flat; it may not retry or backfill.
4. Require the first observation within 180 minutes of the synchronized D1
   open.
5. Require shifts 1 through 6 on both symbols to be exactly the immediately
   prior Friday, Thursday, Wednesday, Tuesday, Monday, and preceding Friday,
   with exact cross-symbol timestamp equality and strict order. Holidays or
   missing sessions consume the week flat.
6. For the five completed formation sessions compute separately for each
   metal `overnight += log(Open[d] / Close[prior_session])` and
   `session += log(Close[d] / Open[d])`.
7. Define `overnight_relative = xau_overnight - xag_overnight`,
   `session_relative = xau_session - xag_session`, and
   `week_relative = overnight_relative + session_relative`. Reconcile each
   metal and the relative total to the completed weekly endpoints within
   `1e-10`.
8. Require strict relative-component opposition and strict session dominance:
   `abs(session_relative) > abs(overnight_relative)`. Exact zero, agreement,
   equality, invalid arithmetic, or failed reconciliation consumes the week.
9. Fade the completed relative week. Positive `week_relative` sells XAU and
   buys XAG; negative `week_relative` buys XAU and sells XAG. Under the locked
   dominance gate this is deliberately opposite the session-relative sign.
   Magnitude never changes size.
10. Target equal absolute USD notionals, round volumes down, reject mismatch
    above 20%, and keep combined frozen-stop loss within one
    `RISK_FIXED=1000` package budget. Use per-leg `3.0 * ATR(20,D1)` hard
    stops, 1,500-point spread ceilings, and no target.
11. Keep both news axes OFF. Close both legs together at broker Friday hour
    21, on later-week observation, after eight calendar days, or when package
    state is malformed. Never retry, scale in, pyramid, grid, martingale, or
    use an external runtime feed.

The exact prior week, every completed endpoint, gold-minus-silver
subtraction, strict component opposition, strict session dominance,
completed-week fade, reconciliation, Monday attempt, equal-notional opposite
legs, aggregate fixed risk, and paired Friday lifecycle are load-bearing. No
ratio level, fitted center, scale, regression, quantile, stationarity test,
absolute magnitude threshold, volatility signal gate, moving line, or
crossover is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one complete OWNER-supplied
  Tier-A practitioner extraction, one peer-reviewed gold/silver relationship
  lineage, one governed exchange carrier packet, and one complete governed
  weekly endpoint packet, with the untested conjunction explicit.
- R2 `PASS`: exact week identity, synchronization, completed endpoints,
  relative subtraction, opposition, dominance, fade sides, reconciliation,
  attempt timing, joint sizing, risk, stops, spreads, and paired exit are
  deterministic and locked.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 state supply every runtime input. Q02
  must prove synchronized history and both-leg execution.
- R4 `PASS`: timestamps, calendar, OHLC, logarithms, arithmetic, ATR risk
  plumbing, quotes, positions, deal history, and terminal state only; no
  trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,527 EA-registry rows and 624 root
cards. It found no exact identity and two expected fuzzy family neighbors.
Manual semantic review fixes the boundaries:

- `QM5_41030_xauxag-flowdiv` trades every strict-disagreement week and follows
  the session-relative sign. This candidate trades only the strict subset in
  which session flow dominates and takes the opposite side by fading the
  completed relative week. On every admitted state its sides oppose 41030.
- `QM5_41039_xauxag-mflow-div` consumes a complete broker month, decides at a
  new-month boundary, follows session-relative flow, and holds to the next
  month. This candidate uses one exact week, a Monday decision, a contrarian
  dominance gate, and Friday flat.
- Ratio z-score, OLS, median/MAD, empirical-tail, failed-break, run-exhaustion,
  quantile-cointegration, and seasonal-surprise systems estimate a relative
  level, center, scale, fitted residual, tail, or long-horizon state. This
  candidate estimates none of them and admits only a five-session
  information-time decomposition.
- Monthly XAU/XAG momentum and reversal systems use completed monthly return
  horizons. The weekend basket is a fixed Friday-to-Monday side. Neither uses
  the candidate's exact prior-week flow state or Monday-to-Friday lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a synchronized symmetric logical basket.

Verdict:
`CLEAN_XAUXAG_WEEKLY_SESSION_DOMINANT_FLOW_CONDITIONED_RELATIVE_FADE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately seven to fifteen completed packages per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong weekday identity or endpoints,
current-bar leakage, component agreement, absent session dominance, wrong
sides, failed reconciliation, late/repeated entry, excess notional mismatch,
orphan survival, wrong lifecycle, nondeterminism, or invalid risk mode. Source
distance, futures/CFD basis, holiday gaps, financing, legging, hedge drift,
and later book correlation are first-order risks. Q09 alone may establish
realized correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
neutrality claims; and correlation waivers. Q02 may be enqueued once if CPU
capacity permits. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.

