# XAU/XAG Weekly Flow-Agreement Fade - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission explicitly requests one new
market-neutral or structural low-frequency commodity sleeve, names an
`XAUUSD~XAGUSD` gold/silver relative-value basket as an allowed carrier,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-wflow-agree-fade`
- proposed strategy ID:
  `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026_S01`
- proposed source ID:
  `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  equal-notional opposite-leg package
- decision clock: first executable synchronized broker Monday after one exact
  completed Monday-through-Friday week
- price state: gold-minus-silver completed close-to-open flow and
  gold-minus-silver completed open-to-close flow have the same strict sign
- lifecycle: fade the completed relative week and flatten both legs together
  on broker Friday

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through the OWNER-supplied Tier-A record at
   `strategy-seeds/sources/SRC03/source.md` and its complete bounded
   page-15-to-30 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`. Williams separates
   prior-close-to-open and open-to-close price flows, accumulates them
   independently, and discusses divergence and crossing states. He does not
   test gold/silver, weekly relative aggregation, agreement, or a contrarian
   package.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, through the governed
   complete-read records at
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` and
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`. The paper supplies a
   state-dependent gold/silver relation and adverse evidence against assuming
   a constant automatically tradable equilibrium.
3. CME Group, "Gold & Silver Ratio Spread" and related governed exchange
   material at `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME
   defines the intermarket carrier and distinguishes gold's monetary and
   safe-haven sensitivity from silver's larger industrial sensitivity.
4. The governed exact-week endpoint packets at
   `strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026/source.md`
   and
   `strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026/source.md`.
   They fix the synchronized Monday-through-Friday endpoint map and document
   the source-to-CFD translation boundary. Their strict-opposition entry
   states are not inherited.

No source tests the exact same-sign conjunction, next-week fade, Darwinex
continuous CFDs, exact synchronized broker labels, equal-notional sizing,
fixed cash risk, ATR stops, or this portfolio. No source performance,
significance, density, transaction-cost, drawdown, CFD-equivalence,
neutrality, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable synchronized D1 tick of a genuine broker Monday:

1. Repair malformed, duplicate, orphaned, wrong-side, or stale owned exposure
   before all entry-only gates.
2. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, matching
   current-bar timestamps, and shared current D1 date equal to broker Monday.
   No label shifting or per-bar repair is allowed.
3. Persist the exact broker-Monday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. A late attachment
   consumes the week flat; it may not retry or backfill.
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
8. Require strict component agreement:
   `overnight_relative * session_relative > 0`. Exact zero, opposition,
   invalid arithmetic, or failed reconciliation consumes the week flat.
9. Fade the completed relative week. Positive `week_relative` sells XAU and
   buys XAG; negative `week_relative` buys XAU and sells XAG. Magnitude never
   changes size.
10. Target equal absolute USD notionals, round volumes down, reject mismatch
    above 20%, and keep combined frozen-stop loss within one
    `RISK_FIXED=1000` package budget. Use per-leg `3.0 * ATR(20,D1)` hard
    stops, 1,500-point spread ceilings, and no target.
11. Keep both news axes OFF. Close both legs together at broker Friday hour
    21, on later-week observation, after eight calendar days, or when package
    state is malformed. Never retry, scale in, pyramid, grid, martingale, or
    use an external runtime feed.

The exact prior week, synchronized completed endpoints, gold-minus-silver
subtraction, strict component agreement, completed-week fade, reconciliation,
Monday attempt, equal-notional opposite legs, aggregate fixed risk, and paired
Friday lifecycle are load-bearing. No ratio level, fitted center, scale,
regression, quantile, stationarity test, absolute magnitude threshold,
volatility signal gate, moving line, or crossover is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: the canonical bounded lineage
  joins a complete OWNER-supplied Tier-A practitioner extraction, a
  peer-reviewed gold/silver relationship source, a governed exchange carrier
  packet, and complete exact-week translation records. The untested
  conjunction is explicit.
- R2 `PASS`: exact week identity, synchronization, completed endpoints,
  relative subtraction, agreement, fade sides, reconciliation, attempt
  timing, joint sizing, risk, stops, spreads, and paired exit are deterministic
  and locked.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 state supply every runtime input. Q02
  must prove synchronized history and both-leg execution.
- R4 `PASS`: timestamps, calendar, OHLC, logarithms, arithmetic, ATR risk
  plumbing, quotes, positions, deal history, and terminal state only; no
  trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,544 EA-registry rows and 625 root
cards. It found no exact identity and the three expected fuzzy family
neighbors. Manual semantic review fixes the boundaries:

- `QM5_41030_xauxag-flowdiv` requires strict component opposition and follows
  the session-relative sign. This candidate requires strict component
  agreement and fades the total relative week. Their entry states are
  mutually exclusive.
- `QM5_41040_xauxag-wflow-fade` also requires strict component opposition,
  then restricts it to session dominance before fading. This candidate
  requires same-sign components and never admits a 41040 state.
- `QM5_41039_xauxag-mflow-div` consumes a complete broker month, requires
  opposition, follows session flow, and holds to the next month. This
  candidate uses one exact week, agreement, a Monday decision, a fade, and
  Friday flat.
- Ratio z-score, OLS, median/MAD, empirical-tail, failed-break,
  quantile-cointegration, CADF, and seasonal systems estimate a relative
  level, center, scale, fitted residual, tail, or long-horizon state. This
  candidate estimates none of them and admits only an information-time
  component conjunction.
- Monthly XAU/XAG momentum and reversal systems use completed monthly return
  horizons. The weekend basket is a fixed Friday-to-Monday side. Neither uses
  the exact prior-week flow state or Monday-to-Friday lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a synchronized symmetric logical basket.

Verdict:
`CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_AGREEMENT_COMPLETED_WEEK_FADE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately fifteen to thirty completed packages per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong week identity or endpoints,
current-bar leakage, entry on component opposition, wrong fade sides, failed
reconciliation, late or repeated entry, excess hedge mismatch, orphan
survival, wrong lifecycle, nondeterminism, invalid risk mode, or unusable
synchronized history. A weak result may not be rescued by changing the
agreement rule, direction, clock, hold, carrier, or adding a ratio threshold,
trend, volatility, seasonal, inventory, or event filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; neutrality claims; and correlation waivers. Q02 may be
enqueued once only if the exact-path tester count and host CPU are below the
governed ceilings. At the ceiling, stop before queue mutation and record a
non-live handoff.

