---
source_id: WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026
title: XAU/XAG weekly session-dominant relative-flow reversion basket
publisher: Wiley Trading / Journal of Banking and Finance / CME Group
source_type: book_peer_reviewed_exchange_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_xauxag_weekly_flow_conditioned_reversion_source_approval.md
approval_commit: cf6d369d7
strategy_ids:
  - WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026_S01
cards_extracted:
  - xauxag-wflow-fade
parent_sources:
  - SRC03
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
  - WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026
---

# XAU/XAG Weekly Flow-Conditioned Relative Reversion Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins governed source lineages whose repository evidence
was read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record at
   `strategy-seeds/sources/SRC03/source.md` and bounded page-15-to-30 text
   define daily prior-close-to-open and open-to-close flows, their separate
   accumulation, and disagreement as a potentially informative state.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. The governed complete-read
   packets at `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`
   and `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md` document a
   state-dependent gold/silver relationship and adverse evidence against a
   constant automatically tradable equilibrium.
3. CME Group, "Gold & Silver Ratio Spread" and related governed exchange
   material at `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME
   defines the ratio/spread carrier and distinguishes gold's monetary and
   safe-haven sensitivity from silver's greater industrial sensitivity.
4. `strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026/source.md`
   fixes an auditable exact synchronized prior-week endpoint map and records
   its source-to-Darwinex limitations. Its session-following direction is not
   inherited by this packet.

Williams does not test gold/silver or a weekly relative basket. Schweikert and
CME do not decompose relative returns by information time. None tests session
dominance followed by a completed-week fade, Darwinex continuous CFDs,
synchronized broker labels, equal-notional sizing, fixed cash risk, or ATR
stops. No source return, alpha, coefficient, significance, density, drawdown,
cost, neutrality, CFD equivalence, decorrelation, or portfolio result
transfers.

## Bounded Mechanization

`WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026_S01` is one predeclared logical
XAU/XAG package:

- exact host/traded slot 0 `XAUUSD.DWX`, D1, and companion/traded slot 1
  `XAGUSD.DWX`, D1;
- decide only on the first genuine broker Monday after one exact synchronized
  completed Monday-through-Friday week, within 180 minutes of the shared D1
  open;
- require the current bar and six immediately completed D1 timestamps to
  match across metals, with prior completed dates exactly Friday through
  Monday plus the preceding Friday anchor; never shift or substitute a
  holiday;
- persist the broker-Monday attempt before every fallible entry gate;
- for each metal, sum five completed close-to-open log returns and five
  completed open-to-close log returns, then reconcile them to the frozen
  weekly endpoints;
- subtract silver from gold for each component;
- trade only when the relative components have opposite strict signs and the
  absolute session-relative component is strictly larger than the absolute
  overnight-relative component;
- fade the completed relative week: positive total means SELL XAU/BUY XAG and
  negative total means BUY XAU/SELL XAG;
- target equal absolute USD notionals, reject more than 20% post-rounding
  mismatch, cap combined frozen-stop loss at one `RISK_FIXED=1000` budget,
  use per-leg `3.0 * ATR(20,D1)` hard stops and 1,500-point spread ceilings,
  and use no target;
- close both legs together Friday at broker hour 21, with later-week and
  eight-day stale repair; and
- use no external runtime data, ratio-level estimate, regression, quantile,
  oscillator, volatility signal gate, retry, scale-in, grid, martingale, or
  pyramid.

The exact-week selector, synchronized endpoints, flow decomposition,
gold-minus-silver subtraction, strict opposition, strict session dominance,
completed-week fade, reconciliation, Monday attempt, aggregate fixed risk,
equal-notional sizing, and paired lifecycle are disclosed QM choices. The
sources do not test their interaction or one-week hold.

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
week_relative      = overnight_relative + session_relative

require overnight_relative * session_relative < 0
require abs(session_relative) > abs(overnight_relative)

week_relative > 0 => SELL XAU / BUY XAG
week_relative < 0 => BUY XAU / SELL XAG
otherwise         => consume week flat
```

All endpoints are completed before the current Monday. Exact zero, component
agreement, or equal magnitude is flat. Under the dominance gate the fade side
is necessarily opposite the session-relative sign. Signal magnitude never
changes size. Entry is one all-or-repair package, not two standalone systems.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named source lineage includes an
  OWNER-supplied Tier-A practitioner extraction, a peer-reviewed DOI source,
  a governed CME packet, and a complete governed weekly endpoint packet. The
  untested conjunction is explicit.
- R2 `PASS`: exact synchronized prior-week identity, completed endpoints,
  relative subtraction, opposition, dominance, fade sides, reconciliation,
  attempt timing, aggregate risk, stops, spreads, and paired exit are fixed.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 state supply all runtime inputs. Q02
  must prove synchronized history and paired fills.
- R4 `PASS`: timestamps, calendar, OHLC, logarithms, arithmetic, comparisons,
  ATR risk plumbing, quotes, positions, deals, and terminal state only; no
  trained output, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,527 EA-registry rows and 624 root
cards. It found no exact identity and the two expected flow-divergence family
neighbors. Manual review returned
`CLEAN_XAUXAG_WEEKLY_SESSION_DOMINANT_FLOW_CONDITIONED_RELATIVE_FADE_AFTER_FAMILY_REVIEW`:

- `QM5_41030_xauxag-flowdiv` follows session-relative flow on every strict
  opposition week. This packet admits only session-dominant opposition and
  takes the opposite sides on every admitted state.
- `QM5_41039_xauxag-mflow-div` uses a complete broker month and next-month
  lifecycle, not one exact week, Monday decision, and Friday exit.
- ratio z-score, OLS, MAD, empirical-tail, failed-break, run-fade,
  quantile-cointegration, and seasonal systems estimate different state and
  do not condition on the fixed information-time decomposition.
- monthly momentum/reversal, fixed weekend, daily shock-catchup, and
  oscillator systems use different endpoints, cadence, direction map, and
  exposure lifecycle.

Replacing the fade with session following collapses into 41030. Dropping the
dominance gate creates a broader flow-opposition reversal family that this
approval does not authorize. Changing the week, adding a relative-level
threshold, or extending the hold requires a new source and card.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-17_xauxag_weekly_flow_conditioned_reversion_source_approval.md`
authorizes exactly one card, deterministic ID allocation, one branch-only
non-live build, strict Q01, one logical `RISK_FIXED` backtest setfile, and one
paced Q02 enqueue if capacity permits.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; neutrality claims; and correlation waivers.
Q09 alone may establish realized correlation with the certified book.

Expected cadence is approximately seven to fifteen completed packages per
full post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
week identity or endpoints, current-bar leakage, component agreement, absent
session dominance, wrong fade sides, failed reconciliation, late/repeated
entry, excess hedge mismatch, orphan survival, wrong lifecycle,
nondeterminism, invalid risk mode, or nonpositive governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source approval | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-17 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
