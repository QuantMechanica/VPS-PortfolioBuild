# XNG Monthly Opposed-Flow Dominance - Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue if CPU capacity permits. This decision does not
authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission permits a second `XNGUSD.DWX` edge
only when its logic is materially different from `QM5_12567`, requires
reputable-source criteria and `RISK_FIXED` backtests, and forbids live or
portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xng-mflow-dom`
- proposed strategy ID: `WILLIAMS-MOP-XNG-MFLOWDOM-2026_S01`
- proposed source ID: `WILLIAMS-MOP-XNG-MFLOWDOM-2026`
- carrier: exact `XNGUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable D1 tick of a new normalized broker month
- price state: all completed prior-month close-to-open log returns and all
  completed prior-month open-to-close log returns, summed separately
- lifecycle: require strict component-sign opposition, follow the sign of the
  component with larger absolute magnitude, and renew at the next broker-month
  boundary

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/WILLIAMS-MOP-XNG-MFLOWDOM-2026/source.md` was read
completely before card drafting. Its governed parents were also read in full:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   page-15-to-30 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define public flow as
   prior close to current open and professional flow as current open to
   current close. Williams says the separate lines can reveal what is really
   happening and specifically identifies divergences as potentially useful.
   He does not test XNG, monthly aggregation, or this direction rule.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` establish XNG as an
   explicit commodity-futures carrier and report a one-month formation,
   one-month hold family at the pooled commodity level. They do not split
   returns by information time or validate a dominant-component direction
   rule during component opposition.

No source tests the exact conjunction, Darwinex continuous CFDs, normalized
energy D1 labels, fixed cash risk, an ATR stop, or the QM portfolio. No source
performance, significance, density, XNG-only efficacy, transaction cost,
drawdown, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable D1 tick of each new `XNGUSD.DWX` broker month:

1. Repair malformed, duplicate, or stale owned exposure before entry-only
   gates.
2. Normalize D1 labels only by the governed same-day or uniform
   `+1`-calendar-day energy convention. Require the current normalized label
   to equal the broker date and its month to follow the completed month
   immediately. Never repair an individual bar or shift a missing session.
3. Persist the exact broker `yyyymm` attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. A late attachment consumes the
   month flat; it may not retry or backfill.
4. Require first observation within 180 minutes of the executable D1 open.
5. Reconstruct the immediately completed broker month plus its preceding
   month-end anchor. Require 15-25 completed prior-month sessions, positive
   finite OHLC endpoints, strict timestamp order, and consecutive month keys.
6. Across every prior-month session compute
   `overnight_flow += log(Open[d] / Close[prior_session])` and
   `session_flow += log(Close[d] / Open[d])`.
7. Reconcile `total_flow = overnight_flow + session_flow` to
   `log(PriorMonthEndClose / PriorPriorMonthEndClose)` within `1e-10`.
8. Require strict component-sign opposition. When
   `abs(session_flow) > abs(overnight_flow)`, follow the session-flow sign;
   when `abs(overnight_flow) > abs(session_flow)`, follow the overnight-flow
   sign. Equal absolute magnitude, agreement, exact zero, invalid arithmetic,
   or failed reconciliation consumes the month flat. Magnitude selects
   direction only and never changes size.
9. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, a 3,000-point entry-spread ceiling, and no
   target.
10. Keep both news axes OFF and framework Friday close disabled. Close at the
    first observed next-month boundary, after 40 calendar days, or when owned
    position state is malformed. Never scale in, pyramid, grid, martingale, or
    use an external runtime feed.

The immediately completed month, every component endpoint, uniform label
normalization, strict opposition, absolute-dominance direction,
reconciliation, monthly attempt, fixed risk, and month-to-month lifecycle are
load-bearing. No magnitude threshold, volatility gate, season, weekday
selector, moving line, or crossover is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one complete OWNER-supplied
  Tier-A practitioner extraction and one complete-read peer-reviewed JFE
  carrier/monthly-hold lineage, with the untested conjunction and adverse
  scope explicit.
- R2 `PASS`: normalized month identity, completed endpoints, component sums,
  opposition, reconciliation, direction, attempt state, timing, risk, stop,
  spread, and exit are deterministic and locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC and
  native MT5 execution state supply every runtime input. The route is already
  exercised, while the session-offset registry marks XNG's label convention
  as inferred from its measured XTI energy sibling.
- R4 `PASS`: calendar, OHLC, logarithms, ATR risk plumbing, quotes, positions,
  deal history, and terminal state only; no trained output, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,525 EA-registry rows and 621 root
cards. It found no exact identity and raised three expected fuzzy family
neighbors. Manual semantic review fixes these boundaries:

- `QM5_41036_wti-mflow-dom` has the same dominance mechanic on WTI. This
  candidate is the exact XNG carrier authorized by the mission, with its own
  magic, route, fills, risk, and result stream; no WTI result transfers.
- `QM5_41035_wti-mflow-div` has the same monthly information clock on WTI but
  always follows session flow. This candidate follows the larger component
  and may take the opposite direction when overnight flow dominates.
- `QM5_41037_xng-mflow-div` uses the same XNG endpoints and opposition gate
  but always follows session flow. This candidate's absolute-dominance rule
  is load-bearing: session-dominant months agree, overnight-dominant months
  trade the opposite side, and equal magnitudes are flat.
- `QM5_20204_xng-tsmom1m` follows every nonzero completed-month total. This
  candidate rejects every agreement month and admits only strict component
  opposition; the total sign is only the algebraic result of the locked
  larger-component rule.
- `QM5_20054_xng-1m-contr` fades every nonzero completed-month total. This
  candidate rejects agreement months and follows rather than fades the
  dominant opposed component.
- `QM5_21504_xng-flowrev` and `QM5_21520_xng-flow-mom` use five-close weekly
  returns gated by native tick-volume ranks. This candidate uses every
  completed prior-month open/close interval and no volume.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a symmetric structural XNG flow state.

Verdict:
`CLEAN_XNG_MONTHLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to eight completed positions per full
post-warm-up year. Q02 must retire on zero trades, fewer than five/year, wrong
month identity or endpoints, current-bar leakage, component agreement, wrong
direction, failed reconciliation, late or repeated entry, wrong lifecycle,
nondeterminism, invalid risk mode, or nonpositive governed economics.
Source-to-rule distance, XNG futures/CFD basis, month-boundary gaps, session
labeling, financing, and later book correlation are first-order risks. Q09
alone may establish realized correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once if CPU capacity permits. If the
factory resource ceiling is binding, do not dispatch, reserve, stop, reap,
  reprioritize, or otherwise control a tester.
