---
source_id: WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026
title: XAU/XAG weekly relative-flow divergence session-follow basket
publisher: Wiley Trading / Journal of Banking and Finance / CME Group
source_type: book_peer_reviewed_exchange_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_xauxag_relative_flow_divergence_source_approval.md
approval_commit: ee6468d58337120ca856dd365a1295e2138000c3
strategy_ids:
  - WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026_S01
cards_extracted:
  - xauxag-flowdiv
parent_sources:
  - SRC03
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
---

# XAU/XAG Weekly Relative-Flow Divergence Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins already governed source lineages whose repository
extractions were read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record is
   `strategy-seeds/sources/SRC03/source.md`. The complete bounded page-18 text
   at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` defines a daily
   prior-close-to-open flow and an open-to-close flow. Williams labels them
   public and professional flows, constructs fourteen-day averages, and
   discusses divergences and crossings.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. The governed packets at
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` and
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md` document the
   state-dependent gold/silver relation and adverse evidence against assuming
   one constant, automatically tradable equilibrium.
3. CME Group, "Gold & Silver Ratio Spread" and related governed exchange
   material at `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME
   defines the ratio, identifies shared precious-metals drivers and different
   monetary/industrial sensitivities, and treats the instruments as an
   intermarket spread carrier.

Williams does not test gold/silver, weekly relative components, a Monday
entry, or a Friday exit. Schweikert and CME do not decompose relative returns
by close/open information time or direct a trade toward session flow. None
tests a Darwinex continuous-CFD basket, synchronized broker timestamps,
equal-notional sizing, fixed cash risk, or ATR stops. No source performance,
significance, cost, density, drawdown, CFD equivalence, neutrality,
correlation, or portfolio result transfers.

## Bounded Mechanization

`WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026_S01` is one predeclared logical
XAU/XAG package:

- exact host/traded slot 0 `XAUUSD.DWX`, D1, and companion/traded slot 1
  `XAGUSD.DWX`, D1;
- decide only on the first genuine broker Monday after one exact synchronized
  completed Monday-through-Friday week, within 180 minutes of the executable
  D1 open;
- require both symbols' current and six immediately completed D1 timestamps to
  match, with prior completed dates exactly Friday through Monday plus the
  preceding Friday; never shift or substitute a holiday;
- persist the broker-Monday attempt before every fallible gate;
- for each metal, sum five fixed completed close-to-open log returns and five
  fixed completed open-to-close log returns;
- subtract silver from gold for each component;
- trade only when the two relative components have opposite strict signs and
  follow the open-to-close component: positive session-relative flow means BUY
  XAU/SELL XAG; negative session-relative flow means SELL XAU/BUY XAG;
- use one equal-USD-notional opposite-leg package, no more than 20% notional
  mismatch after rounding, one shared `RISK_FIXED=1000` budget, per-leg frozen
  `3.0 * ATR(20,D1)` hard stops, 1,500-point spread ceilings, and no target;
- close both legs together Friday at broker hour 21, with framework Friday
  close enabled as a fail-safe and a later-week/eight-day stale guard; and
- use no external runtime data, ratio-level threshold, regression, quantile,
  oscillator, volatility gate, retry, scale-in, grid, martingale, or pyramid.

The exact-week selector, synchronized endpoints, return decomposition,
gold-minus-silver subtraction, strict disagreement, session-following sides,
180-minute attachment boundary, aggregate risk, equal-notional sizing, stops,
spreads, and paired lifecycle are disclosed QM choices. The sources do not
test this interaction or one-week hold.

## Exact Signal Contract

For each synchronized completed prior-week session `d`, with positive finite
prices:

```text
xau_overnight[d] = ln(XAU_open[d] / XAU_close[prior_session])
xag_overnight[d] = ln(XAG_open[d] / XAG_close[prior_session])
xau_session[d]   = ln(XAU_close[d] / XAU_open[d])
xag_session[d]   = ln(XAG_close[d] / XAG_open[d])

overnight_relative = sum(xau_overnight[d] - xag_overnight[d])
session_relative   = sum(xau_session[d]   - xag_session[d])

session_relative > 0 and overnight_relative < 0 => BUY XAU / SELL XAG
session_relative < 0 and overnight_relative > 0 => SELL XAU / BUY XAG
otherwise                                          => consume week flat
```

All endpoints are completed before the current Monday. Exact zero is flat.
Signal magnitude does not change size. Entry is one all-or-repair package, not
two standalone strategies.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named sources include an
  OWNER-supplied Tier-A practitioner extraction, a peer-reviewed DOI lineage,
  and a governed CME exchange packet. The untested conjunction and
  source-to-implementation distance are explicit.
- R2 `PASS`: exact synchronized prior-week identity, completed close/open
  endpoints, relative subtraction, strict disagreement, sides, attempt state,
  entry timing, aggregate risk, stops, spreads, and paired exit are fixed.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 state supply all runtime inputs. The
  logical Q02 window must be synchronized for both carriers.
- R4 `PASS`: timestamps, OHLC, logarithms, arithmetic, comparisons, ATR risk
  plumbing, quotes, positions, deals, and terminal state only; no trained
  output, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,517 EA-registry rows and 613 root
cards and returned `CLEAN` with no fuzzy match. Manual family review returned
`CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_DISAGREEMENT_SESSION_FOLLOW_AFTER_FAMILY_REVIEW`:

- the weekend basket is a fixed XAU-long/XAG-short Friday-to-Monday exposure,
  not a conditional prior-week decomposition;
- ratio, OLS, MAD, empirical-tail, failed-break, seasonal-surprise, and CADF
  systems trade relative levels or fitted residuals, which this packet never
  estimates;
- XAU/XAG cross-sectional momentum systems use close-to-close monthly return
  horizons and do not condition on opposing weekly information-time flows;
- the fresh-run fade uses five same-sign daily ratio returns and a
  counter-return exit, not close/open components or a fixed weekly clock;
- WTI flow agreement is single-leg, trades component agreement, and cannot
  express a gold-minus-silver logical basket; and
- the existing commodity oscillator is neither a two-leg flow decomposition
  nor an exact weekly calendar rule.

The exact synchronized week, two information-time components, cross-metal
subtraction, strict disagreement, session-following direction, equal-notional
opposite legs, and Monday-to-Friday lifecycle are the auditable identity. A
failed result may not be rescued by adding a threshold, using flow agreement,
reversing the session component, changing the clock, or extending the hold.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-16_xauxag_relative_flow_divergence_source_approval.md`
authorizes exactly one card, deterministic ID allocation, one branch-only
non-live build, strict Q01, one logical `RISK_FIXED` backtest setfile, and one
paced Q02 enqueue.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; neutrality claims; and correlation waivers.
Q09 alone may establish realized correlation with the certified book.

Expected cadence is approximately fifteen to thirty completed packages per
full post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
week identity or flow endpoints, current-bar leakage, entry on component
agreement, wrong sides, late or repeated entry, excess hedge mismatch, orphan
survival, wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive
governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-16 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic two-leg implementation and static validation | Q01 | PASS |
