# WTI Monthly Information-Flow Agreement - Source Approval

Date: 2026-08-17

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

- proposed slug: `wti-mflow-agree`
- proposed strategy ID: `WILLIAMS-MOP-WTI-MFLOWAGREE-2026_S01`
- proposed source ID: `WILLIAMS-MOP-WTI-MFLOWAGREE-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable D1 tick of a new normalized broker month
- price state: all completed prior-month close-to-open log returns and all
  completed prior-month open-to-close log returns, summed separately
- lifecycle: require strict component-sign agreement, follow their reconciled
  completed-month direction, and renew at the next broker-month boundary

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/WILLIAMS-MOP-WTI-MFLOWAGREE-2026/source.md` was read
completely before card drafting. Its governed parents were also read in full:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   page-15-to-30 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define public flow as
   prior close to current open and professional flow as current open to
   current close. Williams discusses separately accumulated lines,
   divergences, and crossings. He does not test WTI or a monthly sign-agreement
   rule.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` establish WTI as an
   explicit commodity-futures carrier and report the one-month formation,
   one-month hold family at the commodity-portfolio level. They do not split
   the completed return by information time or test this agreement gate.

No source tests the exact conjunction, Darwinex continuous CFDs, normalized
energy D1 labels, fixed cash risk, an ATR stop, or the QM portfolio. No source
performance, significance, density, WTI-only efficacy, transaction cost,
drawdown, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable D1 tick of each new `XTIUSD.DWX` broker month:

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
8. BUY only when both component sums are strictly positive. SELL only when
   both are strictly negative. Disagreement, exact zero, invalid arithmetic,
   or failed reconciliation consumes the month flat. Signal magnitude never
   changes size.
9. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, a 1,500-point entry-spread ceiling, and no
   target.
10. Keep both news axes OFF and framework Friday close disabled. Close at the
    first observed next-month boundary, after 40 calendar days, or when owned
    position state is malformed. Never scale in, pyramid, grid, martingale, or
    use an external runtime feed.

The immediately completed month, every component endpoint, uniform label
normalization, strict agreement, reconciliation, monthly attempt, fixed risk,
and month-to-month lifecycle are load-bearing. No magnitude threshold,
volatility gate, season, weekday selector, moving line, or crossover is
authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one complete OWNER-supplied
  Tier-A practitioner extraction and one complete-read peer-reviewed JFE
  carrier/one-month-momentum lineage, with the untested conjunction and
  adverse scope explicit.
- R2 `PASS`: normalized month identity, completed endpoints, component sums,
  agreement, reconciliation, direction, attempt state, timing, risk, stop,
  spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native MT5 execution state
  supply every runtime input; the energy label offset is governed in
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: calendar, OHLC, logarithms, ATR risk plumbing, quotes, positions,
  deal history, and terminal state only; no trained output, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,521 EA-registry rows and 617 root
cards. It found no exact identity and raised the expected fuzzy match
`QM5_41029_wti-flow-agree`. Manual semantic review fixes these boundaries:

- `QM5_41029_wti-flow-agree` uses one exact Monday-Friday week, decides on the
  next Monday, and flattens Friday. This candidate consumes every session in
  one completed broker month, decides only at a new-month boundary, and holds
  until the next month.
- `QM5_20187_wti-tsmom1m` follows the completed month total unconditionally.
  This candidate requires both information-time components to agree; any
  opposed-component month is flat even when its total return is nonzero.
- `QM5_41032_wti-flow-div` and `QM5_41033_wti-flow-dom` trade only weekly
  component opposition. This candidate trades only monthly component
  agreement, a disjoint state at a different formation and hold cadence.
- `QM5_41023_wti-mends-mom` compares two non-overlapping close-to-close
  segments inside the completed month and holds five sessions. This candidate
  decomposes every daily interval into close-to-open versus open-to-close
  information time and holds one broker month.
- `QM5_12784_progo-xti` trades crossings of two fourteen-day signed-value
  averages on any D1 bar. This candidate uses raw log sums, no moving line or
  crossover, and a fixed monthly clock.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a symmetric structural WTI flow state.

Verdict:
`CLEAN_WTI_MONTHLY_INFORMATION_FLOW_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to eight completed positions per full
post-warm-up year. Q02 must retire on zero trades, fewer than five/year, wrong
month identity or endpoints, current-bar leakage, component disagreement,
wrong direction, failed reconciliation, late or repeated entry, wrong
lifecycle, nondeterminism, invalid risk mode, or nonpositive governed
economics. Source-to-rule distance, WTI futures/CFD basis, month-boundary gaps,
session labeling, financing, and later book correlation are first-order
risks. Q09 alone may establish realized correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once if CPU capacity permits. If the
factory resource ceiling is binding, do not dispatch, reserve, stop, reap,
reprioritize, or otherwise control a tester.

