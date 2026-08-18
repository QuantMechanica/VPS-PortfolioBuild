---
source_id: WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026
title: XAU/XAG weekly relative-flow agreement reversion basket
publisher: Wiley Trading / Journal of Banking and Finance / CME Group
source_type: book_peer_reviewed_exchange_composite_lineage
status: approved
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
approved_by: "OWNER commodity/energy portfolio mission 2026-08-18"
approved_at: 2026-08-18
source_approval: decisions/2026-08-18_xauxag_weekly_flow_agreement_fade_source_approval.md
approval_commit: d50ca2929
strategy_ids:
  - WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026_S01
cards_extracted:
  - xauxag-wflow-agree-fade
parent_sources:
  - SRC03
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
  - WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026
  - WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026
---

# XAU/XAG Weekly Relative-Flow Agreement Fade Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins governed source lineages whose repository evidence
was read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record at
   `strategy-seeds/sources/SRC03/source.md` and complete bounded page-15-to-30
   text at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define daily
   prior-close-to-open and open-to-close flows, their separate accumulation,
   divergences, and crossings.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. The governed complete-read
   records at `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`
   and `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md` document a
   state-dependent gold/silver relation and adverse evidence against one
   constant automatically tradable equilibrium.
3. CME Group, "Gold & Silver Ratio Spread" and related governed exchange
   material at `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME
   defines the ratio/spread carrier and distinguishes gold's monetary and
   safe-haven sensitivity from silver's larger industrial sensitivity.
4. The complete governed weekly endpoint packets at
   `strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026/source.md`
   and
   `strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026/source.md`
   fix the exact synchronized prior-week endpoint map and record the
   source-to-Darwinex limitations. Their opposition states are not inherited.

Williams does not test gold/silver or a weekly relative basket. Schweikert
and CME do not decompose relative returns by information time. None tests
strict relative-flow agreement followed by a completed-week fade, Darwinex
continuous CFDs, synchronized broker labels, equal-notional sizing, fixed
cash risk, or ATR stops. No source return, alpha, coefficient, significance,
density, drawdown, cost, neutrality, CFD equivalence, decorrelation, or
portfolio result transfers.

## Bounded Mechanization

`WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026_S01` is one predeclared
logical XAU/XAG package:

- exact host/traded slot 0 `XAUUSD.DWX`, D1, and companion/traded slot 1
  `XAGUSD.DWX`, D1;
- decide only on the first genuine broker Monday after one exact synchronized
  completed Monday-through-Friday week, within 180 minutes of the shared D1
  open;
- require current and six immediately completed D1 timestamps to match across
  metals, with prior completed dates exactly Friday through Monday plus the
  preceding Friday anchor; never shift or substitute a holiday;
- persist the broker-Monday attempt before every fallible entry gate;
- for each metal, sum five completed close-to-open log returns and five
  completed open-to-close log returns, then reconcile them to frozen weekly
  endpoints;
- subtract silver from gold for each component;
- trade only when the relative components have the same strict sign;
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
gold-minus-silver subtraction, strict agreement, completed-week fade,
reconciliation, Monday attempt, aggregate fixed risk, equal-notional sizing,
and paired lifecycle are disclosed QM choices. The sources do not test their
interaction or one-week hold.

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

require overnight_relative * session_relative > 0

week_relative > 0 => SELL XAU / BUY XAG
week_relative < 0 => BUY XAU / SELL XAG
otherwise         => consume week flat
```

All endpoints are completed before the current Monday. Exact zero or
component opposition is flat. Under strict agreement the total has the shared
component sign. Signal magnitude never changes size. Entry is one
all-or-repair package, not two standalone systems.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one bounded lineage ID joins a
  complete OWNER-supplied Tier-A practitioner extraction, a peer-reviewed DOI
  source, a governed CME carrier packet, and complete governed exact-week
  translation records. The untested conjunction is explicit.
- R2 `PASS`: exact synchronized prior-week identity, completed endpoints,
  relative subtraction, agreement, fade sides, reconciliation, attempt
  timing, aggregate risk, stops, spreads, and paired exit are fixed.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 state supply all runtime inputs. Q02
  must prove synchronized history and paired fills.
- R4 `PASS`: timestamps, calendar, OHLC, logarithms, arithmetic, comparisons,
  ATR risk plumbing, quotes, positions, deals, and terminal state only; no
  trained output, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,544 EA-registry rows and 625 root
cards. It found no exact identity and the expected fuzzy flow-family
neighbors. Manual review returned
`CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_AGREEMENT_COMPLETED_WEEK_FADE_AFTER_FAMILY_REVIEW`:

- `QM5_41030_xauxag-flowdiv` requires strict relative-component opposition
  and follows session flow. This packet requires same-sign components and
  fades their total; the entry sets are mutually exclusive.
- `QM5_41040_xauxag-wflow-fade` requires session-dominant opposition before
  fading. This packet admits only agreement and cannot share a signal state.
- `QM5_41039_xauxag-mflow-div` uses a complete broker month, opposition,
  session-following sides, and a next-month lifecycle, not one exact week,
  agreement, Monday fade, and Friday exit.
- ratio z-score, OLS, MAD, empirical-tail, failed-break, run-fade,
  quantile-cointegration, CADF, and seasonal systems estimate a relative
  level, fitted residual, center, scale, tail, or long-horizon state. This
  packet estimates none of them.
- monthly momentum/reversal, fixed weekend, daily shock-catchup, and
  oscillator systems use different endpoints, cadence, direction map, and
  exposure lifecycle.

Changing agreement to opposition collapses into the existing weekly flow
family. Following rather than fading, adding a level or magnitude threshold,
changing the week, or extending the hold requires a new source and card.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-18_xauxag_weekly_flow_agreement_fade_source_approval.md`
authorizes exactly one card, deterministic ID allocation, one branch-only
non-live build, strict Q01, one logical `RISK_FIXED` backtest setfile, and one
paced target-only Q02 enqueue if capacity permits.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; neutrality claims; decorrelation claims; and
correlation waivers. Q09 alone may establish realized correlation with the
certified book.

Expected cadence is approximately fifteen to thirty completed packages per
full post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
week identity or endpoints, current-bar leakage, component opposition, wrong
fade sides, failed reconciliation, late or repeated entry, excess hedge
mismatch, orphan survival, wrong lifecycle, nondeterminism, invalid risk
mode, or nonpositive governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-18 | bounded composite source approval | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-18 | one approved agreement-fade card extracted | G0 | APPROVED |
| v1-build | 2026-08-18 | deterministic basket build and static validation | Q01 | PASS |
| v1-q02-capacity | 2026-08-18 | target-only enqueue withheld at tester-capacity and host-CPU ceilings | Q02 | NOT_ENQUEUED_CPU_CEILING |
