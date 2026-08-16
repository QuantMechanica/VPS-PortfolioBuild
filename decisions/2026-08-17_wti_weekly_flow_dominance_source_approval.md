# WTI Weekly Flow-Dominance Continuation - Source Approval

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

- proposed slug: `wti-flow-dom`
- proposed strategy ID: `WILLIAMS-MOP-WTI-WFLOWDOM-2026_S01`
- proposed source ID: `WILLIAMS-MOP-WTI-WFLOWDOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable tick of a genuine broker Monday after one
  exact completed Monday-through-Friday week
- price state: five completed prior-close-to-open log returns and five
  completed open-to-close log returns, summed separately
- lifecycle: require strict sign opposition, follow the component with larger
  absolute magnitude (the reconciled completed-week total), and flatten Friday

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded source packet at
`strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDOM-2026/source.md` was read
completely before this decision. Its governed parents were also read in full:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and complete bounded page-15-to-30
   text at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define public
   flow as prior close to current open and professional flow as current open
   to current close. Williams discusses separate lines, divergences, and
   crossings. He does not test this weekly WTI dominance rule.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` establishes WTI as an
   explicit commodity-futures carrier and own-return continuation as a
   separate family. It does not validate the proposed information-time gate.

No source tests exact completed Monday-Friday aggregation, strict component
opposition, absolute-flow dominance, a next-Monday entry, a Friday exit,
Darwinex continuous CFDs, normalized broker labels, fixed cash risk, or an ATR
stop. These are disclosed QM falsification choices. No source performance,
significance, density, transaction cost, drawdown, WTI-only efficacy, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible `XTIUSD.DWX` broker Monday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or uniform `+1`-calendar-day energy D1
   label convention. Require the current normalized date to equal the broker
   date and the six completed bars to be prior Friday through Monday plus the
   preceding Friday. Never shift a holiday.
3. Persist the exact broker-Monday attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill it.
4. Require first observation within 180 minutes of executable session open.
5. Across the five completed prior-week sessions compute
   `overnight_flow = sum(log(Open[d]/Close[prior_session]))` and
   `session_flow = sum(log(Close[d]/Open[d]))`.
6. Require the two sums to have opposite strict signs. Reconcile
   `total_flow = overnight_flow + session_flow` to the exact completed-week
   return `log(PriorFridayClose/PrecedingFridayClose)`.
7. BUY when `total_flow > 0`; SELL when `total_flow < 0`. Equal component
   magnitudes, agreement, exact zero, invalid arithmetic, or failed
   reconciliation consumes the week flat. Signal magnitude never scales size.
8. Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point entry-spread ceiling, and no
   target.
9. Framework Friday close at broker hour 21 is the ordinary exit. A later-week
   boundary and eight-calendar-day guard repair stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

The exact completed-week identity, close/open decomposition, strict component
opposition, dominant-component direction, reconciliation, Monday attempt,
fixed risk, and Friday lifecycle are load-bearing. No threshold, volatility
gate, seasonal selector, line crossover, or return filter is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one complete OWNER-supplied
  Tier-A practitioner extraction and one complete-read peer-reviewed JFE
  carrier paper, with the untested conjunction and adverse scope explicit.
- R2 `PASS`: exact week, normalized labels, completed endpoints, opposition,
  reconciliation, dominant direction, attempt state, timing, risk, stop,
  spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native MT5 execution state
  supply every runtime input; the energy label offset is governed.
- R4 `PASS`: timestamps, OHLC, logarithms, arithmetic, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,520 EA-registry rows and 616 card
files. It found no exact identity and raised three fuzzy neighbors. Manual
semantic review fixes the boundaries:

- `QM5_41032_wti-flow-div` owns the same strict-opposition state but always
  follows session flow. This candidate follows the reconciled total: it agrees
  with QM5_41032 only when session magnitude dominates, takes the opposite
  side when overnight magnitude dominates, and stays flat on an exact tie.
- `QM5_41029_wti-flow-agree` uses the same endpoints but trades only when both
  components share a sign. This candidate is flat on every agreement state.
- `QM5_41022_wti-wdual-mom` splits the week into early and late close-to-close
  segments. This candidate decomposes all five sessions by close-to-open
  versus open-to-close information time.
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 magnitude threshold and
  realized-volatility rank. This candidate is exact-calendar, sign-only, and
  requires internal component opposition.
- `QM5_12784_progo-xti` trades crossings of fourteen-day signed-value averages
  on any D1 bar. This candidate uses fixed five-session log sums, no line or
  crossover, and one Monday-Friday lifecycle.
- `QM5_10316_overnight-intraday-reversal` is a daily cross-sectional basket
  rank closed within the same session, not a one-symbol completed-week rule.
- `QM5_21520_xng-flow-mom` is a tick-volume-ranked XNG continuation rule, and
  `QM5_12567_cum-rsi2-commodity` is a long-only oscillator pullback.

Verdict:
`CLEAN_WTI_WEEKLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, wrong week identity or endpoints, current-bar leakage, entry on
component agreement, direction different from the reconciled total, failed
reconciliation, late or repeated entry, wrong lifecycle, nondeterminism,
invalid risk mode, or nonpositive governed economics. Source-to-rule distance,
spot/CFD basis, session labeling, financing, gaps, and later book correlation
are first-order risks. Q09 alone may establish realized correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once if CPU capacity permits. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.

