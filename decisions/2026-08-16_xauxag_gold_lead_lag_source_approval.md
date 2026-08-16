# XAU/XAG Asymmetric Gold-Lead Catch-Up - Source Approval

Date: 2026-08-16

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue if CPU capacity permits. This decision does
not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, a market-neutral or
structural carrier, `RISK_FIXED` backtests, and no live or portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `xauxag-goldlead`
- proposed strategy ID:
  `KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026_S01`
- proposed source ID: `KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026`
- host/traded slot 0: `XAUUSD.DWX`, D1
- companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first executable tick of each synchronized broker D1
  session, within 180 minutes of the host D1 open
- price state: one completed gold close-to-close log return and the
  synchronized silver return
- lifecycle: after a material gold move whose silver response remains
  bounded below one-half, trade silver toward gold and hedge with the opposite
  XAU leg; flatten at the first subsequent synchronized D1 bar

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded source packet at
`strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026/source.md`
was read completely before this decision. It preserves:

1. Krawiec and Gorska (2015), "Granger Causality Tests for Precious Metals
   Returns," *Quantitative Methods in Economics* 16(2), 13-22. The complete
   ten-page paper studies London daily USD prices from 2008-2013, reports
   positive gold/silver return correlation, rejects no-causality from gold to
   silver at 1, 5, and 10 daily lags, and does not reject the reverse
   direction. The paper does not publish coefficient signs or a trading rule.
2. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, whose complete governed extraction warns
   that the gold/silver relationship is state-dependent and cannot be treated
   as one automatically profitable constant equilibrium.
3. CME Group's governed gold/silver spread packet, which supports one
   intermarket carrier with shared precious-metals drivers and distinct
   monetary/industrial sensitivities.

No source tests the proposed conjunction. The inference that a bounded
silver under-response may catch up in gold's direction is a falsifiable QM
translation, not a reported coefficient. The exact Darwinex carriers,
75-basis-point gold threshold, one-half response boundary, absolute-response
cap, 180-minute attachment boundary, equal-notional hedge, fixed cash risk,
ATR stops, spread caps, persistent attempt, and one-session lifecycle are
transparent QM choices. No source return, coefficient, significance beyond
its historical sample, density, cost, drawdown, CFD equivalence, neutrality,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On every new `XAUUSD.DWX` D1 bar:

1. Repair or flatten malformed, orphaned, duplicated, same-side, wrong-side,
   or stale owned exposure before applying entry-only gates.
2. Require current and two immediately completed XAU/XAG D1 timestamps to
   match exactly. Require the current host date to equal the broker date and
   the first observed tick to arrive within 180 minutes of that D1 open.
3. Persist the broker-date attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill that date.
4. Compute only completed returns:
   `g = ln(XAU_close[1]/XAU_close[2])` and
   `s = ln(XAG_close[1]/XAG_close[2])`.
5. If `g >= 0.0075`, `s < 0.5*g`, and `abs(s) <= abs(g)`, SELL XAU and BUY
   XAG. If `g <= -0.0075`, `s > 0.5*g`, and `abs(s) <= abs(g)`, BUY XAU and
   SELL XAG. Exact equality, smaller gold moves, already-complete or excessive
   silver response, and invalid arithmetic consume the date flat.
6. Open at most one equal-USD-notional opposite-leg package. Round volumes
   down only, reject post-rounding notional mismatch above 20%, and ensure the
   combined frozen-stop loss does not exceed one `RISK_FIXED=1000` package
   budget. Each leg uses a frozen `3.0 * ATR(20,D1)` hard stop and a
   1,500-point entry spread ceiling. There is no target.
7. If either leg fails to open, immediately close the survivor and consume
   the date. Never retry, scale in, pyramid, grid, or martingale.
8. Close both legs at the first subsequent synchronized XAU D1 bar. Framework
   Friday close remains enabled as a fail-safe. Close malformed or surviving
   exposure after three calendar days. Both news axes remain OFF.

Gold-only causal direction, completed endpoints, shock floor, response
fraction, response cap, opposite package sides, no-retry rule, aggregate
fixed risk, first-next-D1 exit, and equal-notional basket are load-bearing.
No ratio level, center, scale, regression, VAR fit, oscillator, seasonal
clock, target, or longer hold is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: complete-read academic daily
  causality evidence plus peer-reviewed and exchange carrier lineages; the
  absent coefficient sign and untested trade translation are explicit.
- R2 `PASS`: synchronized completed endpoints, asymmetric signal, thresholds,
  direction, attempt state, entry timing, aggregate risk, stops, spreads, and
  paired exit are deterministic and locked.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 execution state supply every runtime
  input; Q02 owns synchronized-history, density, fill, and economics proof.
- R4 `PASS`: native timestamps, closes, logarithms, arithmetic, ATR risk
  plumbing, quotes, positions, deal history, and terminal state only; no
  trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,518 EA-registry rows and 614 root
cards. It found no exact identity and no fuzzy match. Manual semantic review
fixes the family boundaries:

- ratio, OLS, MAD, empirical-tail, failed-break, and CADF systems estimate a
  relative level, center, scale, regression, tail, or stationarity state;
  this candidate uses one completed return per metal and estimates none;
- `QM5_20275_gsr-runfade` requires five same-sign relative returns plus a
  counter-return; this candidate requires one gold-led under-response;
- variance-ratio systems estimate multiweek memory; this candidate has no
  memory or regime estimator;
- monthly cross-sectional momentum and calendar systems have different state
  and lifecycle;
- `QM5_41030_xauxag-flowdiv` compares weekly close/open information-time
  components, while this candidate uses only one close-to-close causal-order
  event and closes on the next D1 bar; and
- `QM5_12567_cum-rsi2-commodity` is a long-only oscillator pullback rather
  than a two-leg asymmetric lead-lag package.

Verdict:
`CLEAN_XAUXAG_ASYMMETRIC_GOLD_LEAD_SILVER_CATCHUP_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately ten to thirty completed packages per full
post-warm-up year. Q02 must retire on zero trades, below five completed
packages/year, silver-to-gold reversal of the source direction, current-bar
leakage, unsynchronized endpoints, a missing/late/repeated attempt, wrong
sides, excess notional mismatch, orphan survival, wrong lifecycle,
nondeterminism, invalid risk mode, or nonpositive governed economics.
Source-to-rule distance, spot/CFD basis, daily session mapping, spreads,
financing, hedge residual, and later book correlation are first-order risks.
Q09 alone may establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; neutrality claims; and
correlation waivers. Q02 may be enqueued once if CPU capacity permits. If the
factory resource ceiling is binding, do not dispatch, reserve, stop, reap,
reprioritize, or otherwise control a tester.
