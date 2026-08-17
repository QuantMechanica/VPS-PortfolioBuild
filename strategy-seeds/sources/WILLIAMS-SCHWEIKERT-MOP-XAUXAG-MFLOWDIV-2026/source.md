---
source_id: WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026
title: XAU/XAG monthly relative information-flow divergence basket
publisher: Wiley Trading / Journal of Banking and Finance / Journal of Financial Economics / CME Group
source_type: book_peer_reviewed_exchange_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_xauxag_monthly_relative_flow_divergence_source_approval.md
approval_commit: cf8667151
strategy_ids:
  - WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026_S01
cards_extracted:
  - strategy-seeds/cards/approved/QM5_41039_xauxag-mflow-div_card.md
parent_sources:
  - SRC03
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
  - MOP-TSMOM-2012
---

# XAU/XAG Monthly Relative-Flow Divergence Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins governed source lineages whose repository evidence
was read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record is
   `strategy-seeds/sources/SRC03/source.md`. The complete bounded page-15-to-30
   text at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` defines daily
   prior-close-to-open public flow and open-to-close professional flow, then
   discusses separately accumulated lines and divergences.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. The governed packets at
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` and
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md` document a
   state-dependent gold/silver relationship and adverse evidence against one
   constant, automatically tradable equilibrium.
3. CME Group, "Gold & Silver Ratio Spread" and related governed exchange
   material at `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME
   defines the intermarket carrier and documents shared precious-metals
   drivers alongside differing monetary, safe-haven, and industrial
   sensitivities.
4. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` delimit a pooled
   commodity one-month formation and one-month hold family.

Williams does not test gold/silver, monthly relative components, a new-month
entry, or a one-month hold. Schweikert and CME do not decompose relative
returns by close/open information time or direct a trade toward session flow.
Moskowitz, Ooi, and Pedersen do not test this two-metal component-opposition
basket. None tests Darwinex continuous CFDs, synchronized broker timestamps,
equal-notional sizing, fixed cash risk, or ATR stops. No source performance,
significance, cost, density, drawdown, CFD equivalence, neutrality,
correlation, or portfolio result transfers.

## Bounded Mechanization

`WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026_S01` is one predeclared logical
XAU/XAG package:

- exact host/traded slot 0 `XAUUSD.DWX`, D1, and companion/traded slot 1
  `XAGUSD.DWX`, D1;
- decide only on the first genuine synchronized D1 boundary of a new broker
  month, within 180 minutes of executable D1 open;
- require both symbols' current and completed D1 timestamps to match exactly;
  never shift, substitute, or independently repair a session;
- persist the broker-month attempt before every fallible gate;
- reconstruct every synchronized session in the immediately completed broker
  month plus its preceding month-end anchor, with 15-25 completed sessions;
- for each metal, sum completed close-to-open log returns separately from
  completed open-to-close log returns;
- subtract silver from gold for each component and reconcile both metal totals
  and their relative total to completed month-end returns;
- trade only when the two relative components have opposite strict signs and
  follow the open-to-close relative component: positive session-relative flow
  means BUY XAU/SELL XAG; negative session-relative flow means SELL XAU/BUY
  XAG;
- use one equal-USD-notional opposite-leg package, no more than 20% notional
  mismatch after rounding, one shared `RISK_FIXED=1000` budget, per-leg frozen
  `3.5 * ATR(20,D1)` hard stops, 1,500-point spread ceilings, and no target;
- close both legs at the first next-month D1 boundary, with framework Friday
  close disabled and a 40-calendar-day stale guard; and
- use no external runtime data, ratio-level threshold, regression, quantile,
  oscillator, volatility gate, retry, scale-in, grid, martingale, or pyramid.

The completed-month selector, synchronized endpoints, information-time
decomposition, gold-minus-silver subtraction, strict disagreement,
session-following sides, reconciliation, 180-minute attachment boundary,
aggregate risk, equal-notional sizing, stops, spreads, and paired lifecycle
are disclosed QM choices. The sources do not test this interaction or this
continuous-CFD implementation.

## Exact Signal Contract

For every synchronized completed session `d` in the immediately prior broker
month, with positive finite prices and the preceding month-end as anchor:

```text
xau_overnight[d] = ln(XAU_open[d] / XAU_close[prior_session])
xag_overnight[d] = ln(XAG_open[d] / XAG_close[prior_session])
xau_session[d]   = ln(XAU_close[d] / XAU_open[d])
xag_session[d]   = ln(XAG_close[d] / XAG_open[d])

overnight_relative = sum(xau_overnight[d] - xag_overnight[d])
session_relative   = sum(xau_session[d]   - xag_session[d])

session_relative > 0 and overnight_relative < 0 => BUY XAU / SELL XAG
session_relative < 0 and overnight_relative > 0 => SELL XAU / BUY XAG
otherwise                                          => consume month flat
```

For each metal, `overnight + session` must reconcile to its completed
month-end log return within `1e-10`; the relative total must reconcile to gold
month return minus silver month return. All endpoints are completed before the
decision month. Exact zero is flat. Signal magnitude does not change size.
Entry is one all-or-repair package, not two standalone strategies.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named sources include an
  OWNER-supplied Tier-A practitioner extraction, peer-reviewed DOI lineages,
  and a governed CME exchange packet. The untested conjunction and
  source-to-implementation distance are explicit.
- R2 `PASS`: exact synchronized prior-month identity, completed close/open
  endpoints, relative subtraction, strict disagreement, reconciliation,
  sides, attempt state, entry timing, aggregate risk, stops, spreads, and
  paired exit are fixed.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 state supply all runtime inputs. The
  logical Q02 window must be synchronized for both carriers.
- R4 `PASS`: timestamps, OHLC, logarithms, arithmetic, comparisons, ATR risk
  plumbing, quotes, positions, deals, and terminal state only; no trained
  output, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,526 EA-registry rows and 623 card
files. It found no exact identity and raised only the expected weekly
`QM5_41030_xauxag-flowdiv` family neighbor. Manual review returned
`CLEAN_XAUXAG_MONTHLY_RELATIVE_FLOW_DIVERGENCE_AFTER_CADENCE_CARRIER_AND_FAMILY_REVIEW`:

- `QM5_41030_xauxag-flowdiv` forms on one exact Monday-Friday week, decides
  next Monday, and exits Friday; this packet consumes every synchronized
  session in a completed broker month and holds until the next month;
- `QM5_41037_xng-mflow-div` is a single-leg XNG state and cannot express a
  gold-minus-silver logical basket;
- one-, three-, and twelve-month XAU/XAG cross-sectional momentum systems rank
  close-to-close relative returns and trade every non-tie; this packet admits
  only strict information-time opposition and follows session-relative flow,
  which may oppose the total relative-return sign;
- ratio, OLS, MAD, empirical-tail, failed-break, seasonal-surprise, and CADF
  systems trade relative levels or fitted residuals, which this packet never
  estimates;
- the gold-lead catch-up basket uses one completed daily shock and a
  one-session hold rather than every prior-month close/open interval; and
- the incumbent commodity oscillator is neither a two-leg flow decomposition
  nor a monthly logical basket.

The exact synchronized completed month, two information-time components,
cross-metal subtraction, strict disagreement, session-following direction,
equal-notional opposite legs, and month-to-month lifecycle are the auditable
identity. A failed result may not be rescued by adding a threshold, admitting
agreement, reversing the session component, changing the clock, or shortening
or extending the hold.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_xauxag_monthly_relative_flow_divergence_source_approval.md`
authorize exactly one card, deterministic ID allocation, one branch-only
non-live build, strict Q01, one logical `RISK_FIXED` backtest setfile, and one
paced Q02 enqueue if CPU capacity permits.

They exclude manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; neutrality claims; and correlation waivers.
Q09 alone may establish realized correlation with the certified book.

Expected cadence is approximately five to eight completed packages per full
post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
month identity or flow endpoints, current-bar leakage, entry on component
agreement, wrong sides, failed reconciliation, late or repeated entry, excess
hedge mismatch, orphan survival, wrong lifecycle, nondeterminism, invalid risk
mode, or nonpositive governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-17 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
