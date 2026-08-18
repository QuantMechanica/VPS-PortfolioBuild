# XNG Weekly Flow-Agreement Continuation - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission explicitly permits a second
`XNGUSD` edge when its logic differs from `QM5_12567`, requires a structural
low-frequency rule, reputable sources, `RISK_FIXED` backtests, and one Q02
handoff, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xng-wflow-agree`
- proposed strategy ID: `WILLIAMS-MOP-XNG-WFLOW-2026_S01`
- proposed source ID: `WILLIAMS-MOP-XNG-WFLOW-2026`
- carrier: exact `XNGUSD.DWX`, D1, one direct symmetric long/short position
- decision clock: first executable normalized broker Monday after one exact
  completed Monday-through-Friday week
- state: the five completed close-to-open log returns and five completed
  open-to-close log returns have the same strict sign
- lifecycle: continue the agreed completed-week direction and flatten by
  broker Friday hour 21

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed records below were read completely before this approval:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through the OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and the already governed exact-week
   packet at
   `strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOW-2026/source.md`. Williams
   separates prior-close-to-open and open-to-close flows, accumulates them
   independently, and discusses their interaction. The governed packet fixes
   the exact completed-week endpoint map; its WTI carrier is not inherited.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, through the complete-paper record at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It supplies own-return
   continuation lineage, a diversified commodity-futures universe that
   includes natural gas, and explicit warnings against transferring pooled
   results to one CFD carrier.

Williams does not test natural gas, an exact prior-week agreement conjunction,
or a Monday-to-Friday hold. Moskowitz, Ooi, and Pedersen do not decompose a
weekly return by close/open information time. Neither source tests Darwinex
continuous CFDs, uniform energy-label normalization, fixed cash risk, an ATR
stop, or this portfolio. No source return, alpha, significance, density,
drawdown, cost, XNG-only efficacy, CFD equivalence, decorrelation, or
portfolio result transfers.

## Locked Mechanic

On the first executable `XNGUSD.DWX` D1 tick of a genuine broker Monday:

1. Repair malformed, duplicate, wrong-side, or stale owned exposure before
   all entry-only gates.
2. Accept only native same-day D1 labels or one uniform `+1` calendar-day
   energy offset. Require the normalized current D1 date to equal the broker
   Monday and apply the same offset to every completed endpoint.
3. Persist the exact broker-Monday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. A late attachment,
   rejection, restart, or stopped position cannot retry the week.
4. Require observation within 180 minutes of the normalized D1 open.
5. Require shifts 1 through 6, newest first, to be exactly prior Friday,
   Thursday, Wednesday, Tuesday, Monday, and the preceding Friday. Holidays,
   missing bars, or per-bar label repair consume the week flat.
6. Across the five completed sessions compute
   `overnight_flow += log(Open[d] / Close[prior_session])` and
   `session_flow += log(Close[d] / Open[d])`. Reconcile their sum to the
   completed weekly endpoint return within `1e-10`.
7. BUY only when both component sums are strictly positive. SELL only when
   both are strictly negative. Opposition, exact zero, invalid arithmetic,
   or failed reconciliation consumes the week flat. Signal magnitude never
   changes size.
8. Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
   `3.0 * ATR(20,D1)` broker hard stop, a 3,000-point XNG spread ceiling, and
   no take-profit.
9. Keep both news axes OFF. Close by framework Friday close at broker hour 21,
   with later-week and eight-calendar-day stale repair.
10. Never retry, scale in, pyramid, grid, martingale, partially close, read an
    external signal, or form a second leg.

The exact week, uniform energy-label convention, completed endpoints,
separate component sums, strict agreement, continuation direction, durable
attempt, fixed risk, hard stop, and Friday lifecycle are load-bearing. No
absolute return threshold, volatility signal gate, line crossover, ratio,
regression, event calendar, inventory series, seasonal window, or oscillator
is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named authors, one complete
  OWNER-supplied Tier-A practitioner lineage, one complete-read peer-reviewed
  JFE paper with DOI and natural-gas membership, and an explicit carrier-port
  boundary.
- R2 `PASS`: exact week identity, label normalization, completed endpoints,
  component arithmetic, agreement, direction, attempt, timing, risk, stop,
  spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XNGUSD.DWX` D1 OHLC and native MT5 execution state
  supply every runtime input; Q02 must prove current history and fills.
- R4 `PASS`: calendar, OHLC, logarithms, comparisons, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,545 EA-registry rows and 625 root cards. It
found no exact identity and four expected fuzzy source-family neighbors.
Manual semantic review fixes the boundaries:

- `QM5_41029_wti-flow-agree` owns the same frozen information-time mechanic
  on WTI. This candidate is the explicitly mission-authorized natural-gas
  carrier, with its own XNG history, contract, gap, seasonality, liquidity,
  and spread risks. It cannot trade WTI and is not an in-place parameter
  change to that EA.
- `QM5_41032_wti-flow-div` and `QM5_41033_wti-flow-dom` require component
  opposition and trade WTI. This candidate requires strict agreement and
  trades only XNG.
- `QM5_41037_xng-mflow-div` and `QM5_41038_xng-mflow-dom` use a complete
  broker month, require opposed flows, and hold to the next month. This
  candidate uses one exact week, agreement, Monday entry, and Friday flat.
- `QM5_41043_xng-thu-flow-agree` observes one completed standard-Thursday
  event proxy and enters Friday into a weekend hold. This candidate aggregates
  all ten endpoints of an exact prior week and enters Monday.
- `QM5_13101_xng-1w-mom-vol` uses a close-to-close magnitude threshold and
  realized-volatility gate. This candidate has neither and remains flat
  unless both information-time components agree.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI
  pullback. This candidate is symmetric, weekly, continuation-based, and has
  no oscillator or short-horizon pullback state.

Verdict:
`CLEAN_XNG_WEEKLY_OVERNIGHT_SESSION_FLOW_AGREEMENT_CARRIER_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong week identity or endpoints, current-bar
leakage, entry on opposition, wrong direction, late or repeated entry, wrong
Friday lifecycle, nondeterminism, invalid risk mode, or unusable XNG history.
A weak result may not be rescued by changing the agreement rule, direction,
clock, hold, spread cap, carrier, or adding a trend, volatility, seasonal,
inventory, event, or oscillator filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the exact-path tester count and host CPU are below the governed ceilings.
At the ceiling, stop before queue mutation and record a non-live handoff.

