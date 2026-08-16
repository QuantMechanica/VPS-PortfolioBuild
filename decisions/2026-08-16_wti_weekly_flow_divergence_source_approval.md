# WTI Weekly Public/Professional Flow Divergence - Source Approval

Date: 2026-08-16

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue if CPU capacity permits. This decision does not
authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-flow-div`
- proposed strategy ID: `WILLIAMS-MOP-WTI-WFLOWDIV-2026_S01`
- proposed source ID: `WILLIAMS-MOP-WTI-WFLOWDIV-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable tick of a genuine broker Monday after one
  exact completed Monday-through-Friday week
- price state: five completed prior-close-to-open log returns and five
  completed open-to-close log returns, summed separately
- lifecycle: trade only when the two weekly components have opposite strict
  signs, follow the open-to-close session component, and flatten Friday

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded source packet at
`strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDIV-2026/source.md` was read
completely before this decision. Its governed parents were also read in full:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and complete bounded page-18 text
   at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define public flow
   as prior close to current open and professional flow as current open to
   current close. Williams discusses their separate lines, divergences, and
   crossings. He does not test the proposed weekly WTI sign-opposition rule.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` establishes WTI as an
   explicit commodity-futures carrier and provides adverse discipline: its
   own-return continuation result does not establish that one information-
   time component should dominate another.

No source tests exact completed Monday-Friday aggregation, strict component
opposition, a next-Monday entry, session-following direction, a Friday exit,
Darwinex continuous CFDs, normalized broker labels, fixed cash risk, or an ATR
stop. These are disclosed QM falsification choices. No source performance,
significance, density, transaction cost, drawdown, WTI-only efficacy, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible `XTIUSD.DWX` broker Monday:

1. Repair malformed or stale owned exposure before applying entry-only gates.
2. Support only the governed same-day or uniform `+1`-calendar-day energy D1
   label convention. Require the current normalized session date to equal the
   broker date and the six completed bars to be, newest first, prior Friday
   through Monday plus the preceding Friday. Never shift a holiday.
3. Persist the exact broker-Monday attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill it.
4. Require first observation within 180 minutes of executable session open.
5. Across the five completed prior-week sessions compute
   `overnight_flow = sum(log(Open[d]/Close[prior_session]))` and
   `session_flow = sum(log(Close[d]/Open[d]))`.
6. If `session_flow > 0` and `overnight_flow < 0`, BUY WTI. If
   `session_flow < 0` and `overnight_flow > 0`, SELL WTI. Agreement, exact
   zero, invalid arithmetic, or any other state consumes the week flat.
7. Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point entry-spread ceiling, and no
   target or signal-magnitude sizing.
8. Framework Friday close at broker hour 21 is the ordinary exit. A later-week
   boundary and eight-calendar-day guard repair stale exposure.
9. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
   runtime data.

The exact completed-week identity, close/open decomposition, strict component
opposition, session-following side, Monday attempt, fixed risk, and Friday
lifecycle are load-bearing. No price-flow average, line crossover, magnitude
threshold, volatility regime, seasonal selector, or return-sign overlay is
authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one complete OWNER-supplied
  Tier-A practitioner extraction and one complete-read peer-reviewed JFE
  carrier paper, with the untested conjunction and adverse scope explicit.
- R2 `PASS`: exact completed-week identity, normalized labels, close/open
  endpoints, strict opposition, direction, attempt state, entry timing, risk,
  stop, spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native MT5 execution state
  supply every runtime input; the energy label offset is governed in the
  framework registry.
- R4 `PASS`: timestamps, OHLC, logarithms, arithmetic, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,519 EA-registry rows and 615 root
cards. It found no exact identity and raised two fuzzy neighbors. Manual
semantic review fixes the boundaries:

- `QM5_41029_wti-flow-agree` uses the same completed-week decomposition but
  enters only when both component signs agree and follows their common sign.
  This candidate is flat on every agreement week, enters only the disjoint
  opposition state, and follows the session component.
- `QM5_12784_progo-xti` compares fourteen-day signed-value averages and trades
  line crossings on any D1 bar. This candidate uses five fixed log-flow sums,
  no moving line or crossing, and an exact Monday-Friday lifecycle.
- `QM5_41030_xauxag-flowdiv` is a two-leg gold-minus-silver relative basket.
  This candidate performs no cross-metal subtraction and trades one direct WTI
  position.
- `QM5_21520_xng-flow-mom`, the other fuzzy result, is an XNG close-return
  continuation rule gated by a 40-window tick-volume rank. It has no close/open
  decomposition, opposition state, WTI carrier, or Monday-Friday clock.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a symmetric structural WTI price-flow rule.

Verdict:
`CLEAN_WTI_WEEKLY_PUBLIC_PROFESSIONAL_FLOW_DIVERGENCE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, wrong week identity or flow endpoints, current-bar leakage, entry on
component agreement, direction opposite the session component, late or
repeated entry, wrong lifecycle, nondeterminism, invalid risk mode, or
nonpositive governed economics. Source-to-rule distance, spot/CFD basis,
session labeling, financing, gaps, and later book correlation are first-order
risks. Q09 alone may establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once if CPU capacity permits. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.

