# XAU/XAG Weekly Relative-Flow Divergence - Source Approval

Date: 2026-08-16

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. This decision does not authorize a manual
tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, a market-neutral or
structural carrier, `RISK_FIXED` backtests, and no live or portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `xauxag-flowdiv`
- proposed strategy ID:
  `WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026_S01`
- proposed source ID: `WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026`
- host/traded slot 0: `XAUUSD.DWX`, D1
- companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: the first genuine synchronized Monday D1 session after one
  exact completed Monday-through-Friday week
- price state: gold-minus-silver close-to-open flow and gold-minus-silver
  open-to-close flow, summed separately across the completed week
- lifecycle: when those relative flows have opposite strict signs, follow the
  open-to-close relative flow with one equal-notional opposite-leg package;
  flatten both legs together Friday at broker hour 21

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following bounded repository sources were read completely before this
decision:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A packet at
   `strategy-seeds/sources/SRC03/source.md` and its complete bounded page-18
   extraction at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define
   separate prior-close-to-open and open-to-close price-flow objects. Williams
   characterizes the former as public flow and the latter as professional
   flow, then discusses divergences and crossings between their fourteen-day
   averages.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, together with the governed
   CME Group gold/silver-ratio packet. The complete repository extractions at
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`,
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, and
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` support a
   state-dependent gold/silver relationship and treating the two instruments
   as one intermarket relative-value carrier. They also warn against assuming
   an immutable or automatically profitable equilibrium.

No source tests the proposed conjunction. Williams does not prescribe a
five-session relative-flow comparison, gold/silver basket, Monday clock, or
Friday exit. Schweikert and CME do not split gold/silver relative returns by
close/open information time or direct a trade toward the session component.
The exact Darwinex carriers, calendar sequence, synchronization contract,
180-minute attachment boundary, equal-notional sizing, fixed cash risk, ATR
stops, spread caps, attempt ledger, and weekly lifecycle are transparent QM
falsification choices. No source return, coefficient, significance, density,
cost, drawdown, CFD equivalence, neutrality, decorrelation, or portfolio
result transfers.

## Locked Mechanic

On the first observed tick of an exact broker Monday `XAUUSD.DWX` D1 bar:

1. Repair or flatten malformed, orphaned, duplicated, same-side, wrong-side,
   stale, or out-of-lifecycle owned exposure before applying entry-only gates.
2. Require synchronized current and completed XAU/XAG D1 timestamps. Require
   the current D1 date to equal the broker date and the six immediately
   completed dates, newest first, to be prior Friday, Thursday, Wednesday,
   Tuesday, Monday, and the preceding Friday at exact offsets 3, 4, 5, 6, 7,
   and 10 calendar days. Holidays are not shifted, substituted, or backfilled.
3. Require the first observed tick within 180 minutes of the executable Monday
   D1 open. Persist the current broker-Monday attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry or backfill
   that Monday.
4. Across the five completed prior-week sessions, compute each metal's
   close-to-open and open-to-close log returns from fixed completed endpoints.
   Define `overnight_relative` as the gold sum minus the silver sum and
   `session_relative` as the gold sum minus the silver sum. The current Monday
   price enters neither state.
5. Trade only when the two relative flows have opposite strict signs. If
   `session_relative > 0` and `overnight_relative < 0`, BUY XAU and SELL XAG.
   If `session_relative < 0` and `overnight_relative > 0`, SELL XAU and BUY
   XAG. Agreement, exact zero, or invalid arithmetic consumes the week flat.
   Signal magnitude never scales risk.
6. Open at most one equal-USD-notional opposite-leg package. Round volumes
   down only, reject post-rounding notional mismatch above 20%, and ensure the
   combined frozen-stop loss does not exceed one `RISK_FIXED=1000` package
   budget. Each leg uses a frozen `3.0 * ATR(20,D1)` hard stop and a
   1,500-point entry spread ceiling. There is no target.
7. Close both legs together on or after broker Friday 21:00. Framework Friday
   close remains enabled as a fail-safe. Close stale exposure on the first
   later broker-week boundary or after eight calendar days. Both news axes
   remain OFF.

The two return decompositions, gold-minus-silver subtraction, exact prior-week
sequence, strict disagreement, session-following direction, Monday clock,
no-shift/no-late-entry/no-retry rules, aggregate fixed risk, paired Friday
exit, and equal-notional basket are load-bearing. No threshold, volatility
gate, ratio level, regression, oscillator, event feed, target, or longer hold
is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one OWNER-supplied Tier-A
  practitioner extraction defines the two price-flow components; one
  peer-reviewed *Journal of Banking & Finance* lineage and one governed CME
  exchange packet support the gold/silver relative-value carrier. The untested
  conjunction and source-to-implementation distance are explicit.
- R2 `PASS`: synchronized exact-week identity, fixed completed endpoints,
  relative-flow subtraction, strict disagreement, direction, attempt state,
  entry timing, aggregate risk, stops, spreads, and paired exit are
  deterministic and locked.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 execution state supply every runtime
  input. Q02 is one logical basket over the synchronized history window.
- R4 `PASS`: native calendar, OHLC, logarithm, arithmetic, ATR risk plumbing,
  quotes, positions, deal history, and framework state only; no trained
  output, banned signal indicator, external feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,517 EA-registry rows and 613 root
cards. It found no exact identity and no fuzzy match for the complete mechanic.
Manual semantic review fixes the family boundaries:

- `QM5_20019_xauxag-wkend` always buys XAU and sells XAG across the
  Friday-close/Monday-open weekend interval; this candidate forms two
  completed prior-week relative-flow components, conditions on disagreement,
  and holds the selected package Monday-to-Friday.
- `QM5_20157_xau-xag-ratio`, `QM5_20161_xauxag-ols-rv`,
  `QM5_20263_xauxag-mad-rv`, `QM5_20268_xauxag-qtail-rv`, and
  `QM5_21526_xau-xag-cadf` fade ratio/residual levels or tails. This candidate
  uses no ratio level, center, scale, regression, quantile, or stationarity
  estimate.
- `QM5_20050_xauxag-xmom12`, `QM5_20057_xauxag-xmom1`,
  `QM5_20184_xauxag-xmom3`, and `QM5_20260_xauxag-mom-vote` follow relative
  close-to-close momentum over monthly horizons. This candidate requires
  opposition between weekly overnight and session components and follows only
  the session component.
- `QM5_20265_xauxag-fail-rv` waits for a failed ratio-channel break and
  `QM5_20275_gsr-runfade` fades a fresh five-return same-sign ratio run. This
  candidate has neither a channel/failure event nor a same-sign run.
- `QM5_41029_wti-flow-agree` trades one WTI leg only when its overnight and
  session components agree. This candidate trades a two-leg XAU/XAG relative
  carrier only when the gold-minus-silver components disagree, and takes the
  session-relative side.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  multiple commodity carriers, not an exact-clock two-leg flow decomposition.

Verdict:
`CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_DISAGREEMENT_SESSION_FOLLOW_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately fifteen to thirty completed packages per
full post-warm-up year after exact-week, synchronization, and disagreement
gates. Q02 must retire on zero trades, below five completed packages per year,
wrong weekday sequence, current-bar leakage, incorrect flow endpoints or
subtraction, entry on flow agreement, wrong sides, late or repeated entry,
excess hedge mismatch, orphan survival, wrong lifecycle, nondeterminism,
invalid risk mode, or nonpositive governed economics. Holiday exclusions,
source-to-carrier distance, spot/CFD basis, synchronized-history limits,
spreads, financing, hedge residual, and later book correlation are first-order
risks. Q09 alone may establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; neutrality claims; and
correlation waivers. Q02 may be enqueued once. If the factory resource ceiling
is binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
