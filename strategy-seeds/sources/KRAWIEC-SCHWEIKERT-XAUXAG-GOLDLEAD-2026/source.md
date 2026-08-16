---
source_id: KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026
title: XAU/XAG asymmetric gold-lead silver-catch-up basket
publisher: Quantitative Methods in Economics / Journal of Banking and Finance / CME Group
source_type: peer_reviewed_exchange_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_xauxag_gold_lead_lag_source_approval.md
approval_commit: f4aa2f4c7
strategy_ids:
  - KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026_S01
cards_extracted:
  - xauxag-goldlead
parent_sources:
  - KRAWIEC-GORSKA-PRECIOUS-CAUSALITY-2015
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
---

# XAU/XAG Asymmetric Gold-Lead Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet has one canonical lineage ID and three attributable
components. All components were read completely before card drafting.

1. Monika Krawiec and Anna Gorska (2015), "Granger Causality Tests for
   Precious Metals Returns," *Quantitative Methods in Economics* 16(2),
   13-22. Journal landing page:
   `https://qme.sggw.edu.pl/article/view/3763`; complete ten-page PDF:
   `https://qme.sggw.edu.pl/article/download/3763/3390/4072`. The full paper,
   including data, equations, Tables 1-4, conclusion, footnotes, and
   references, was read on 2026-08-16. It studies London daily USD closing
   prices from January 2008 through December 2013. Gold and silver daily log
   returns have positive contemporaneous correlation of 0.6061. The paper
   rejects no-Granger-causality from gold returns to silver returns at 1, 5,
   and 10 lags, while it does not reject the reverse direction at any of those
   lags. The authors do not publish coefficient signs and do not test a
   trading rule.
2. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. The complete governed
   extraction at `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md` records
   the state-dependent gold/silver relation and adverse evidence against
   assuming one stable, automatically profitable equilibrium.
3. CME Group's governed exchange packet at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` identifies gold and
   silver as a tradable intermarket carrier with shared precious-metals
   drivers but materially different monetary and industrial sensitivities.

Krawiec and Gorska establish predictive ordering, not the sign or magnitude
of a trade. Schweikert and CME establish the relative-value carrier, not a
one-day lead-lag rule. None tests Darwinex continuous CFDs, a 75-basis-point
gold shock, a one-half silver-response boundary, equal-notional hedging,
fixed cash risk, ATR stops, attachment timing, or a one-session exit. No
source return, significance beyond the cited historical tests, coefficient,
trade count, drawdown, cost, CFD equivalence, neutrality, correlation, or
portfolio result transfers.

## Bounded Mechanization

`KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026_S01` is one predeclared logical
XAU/XAG package:

- host/traded slot 0 is exact `XAUUSD.DWX`, D1; companion/traded slot 1 is
  exact `XAGUSD.DWX`, D1;
- decide at most once on the first executable tick of each synchronized D1
  session, within 180 minutes of the current host D1 open;
- persist the broker-date attempt before history, signal, news, spread,
  quote, ATR, sizing, or order gates, with no same-date retry or backfill;
- require current and two immediately completed XAU/XAG D1 timestamps to
  match exactly and use only the two completed closes for each metal;
- compute `gold_return = ln(XAU_close[1] / XAU_close[2])` and
  `silver_return = ln(XAG_close[1] / XAG_close[2])`;
- treat gold as a positive leader only when `gold_return >= 0.0075`,
  `silver_return < 0.5 * gold_return`, and
  `abs(silver_return) <= abs(gold_return)`; BUY XAG and SELL XAU;
- treat gold as a negative leader only when `gold_return <= -0.0075`,
  `silver_return > 0.5 * gold_return`, and
  `abs(silver_return) <= abs(gold_return)`; SELL XAG and BUY XAU;
- exact equality, a smaller gold move, excessive or already-complete silver
  response, invalid arithmetic, or unsynchronized history consumes the day
  flat;
- solve one opposite-leg equal-USD-notional package, round volumes down,
  reject notional mismatch above 20%, and keep combined frozen-stop loss at
  or below one `RISK_FIXED=1000` package budget;
- use a frozen `3.0 * ATR(20,D1)` hard stop per leg, 1,500-point entry spread
  ceilings, no target, and no signal-magnitude sizing; and
- close both legs together at the first subsequent synchronized XAU D1 bar,
  with framework Friday 21 close and a three-calendar-day stale repair guard.

The source-directed asymmetry is gold-to-silver only. A silver move never
predicts gold. The same-direction catch-up interpretation, shock threshold,
under-response fraction, absolute-response cap, paired hedge, one-session
hold, attempt state, execution guards, and all risk parameters are disclosed
QM falsification choices.

## Exact Signal Contract

For positive finite synchronized completed closes:

```text
g = ln(XAU_close[1] / XAU_close[2])
s = ln(XAG_close[1] / XAG_close[2])

g >= +0.0075 and s < 0.5*g and abs(s) <= abs(g)
    => SELL XAU / BUY XAG

g <= -0.0075 and s > 0.5*g and abs(s) <= abs(g)
    => BUY XAU / SELL XAG

otherwise
    => consume the broker date flat
```

The current D1 bar enters neither return. Direction uses only gold's completed
return; silver is a bounded under-response gate. Signal magnitude never
changes size. The package is all-or-repair and neither leg is a standalone
strategy.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: the canonical source packet joins
  a complete-read academic daily-causality study, a peer-reviewed
  *Journal of Banking & Finance* carrier study, and governed CME exchange
  material. The missing coefficient direction and untested trade translation
  are explicit.
- R2 `PASS`: synchronized completed endpoints, one-way signal, thresholds,
  sides, attempt state, entry window, combined risk, notional constraint,
  stops, spreads, paired exit, and repair behavior are deterministic.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC plus native MT5 execution state provide every runtime
  input. Q02 must use one logical basket over synchronized history.
- R4 `PASS`: timestamps, closes, logarithms, arithmetic, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, pyramid,
  or random path.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,518 EA-registry rows and 614 root
cards and returned `CLEAN` with no fuzzy match. Manual family review returned
`CLEAN_XAUXAG_ASYMMETRIC_GOLD_LEAD_SILVER_CATCHUP_AFTER_FAMILY_REVIEW`:

- `QM5_12577_cme-xauxag-ratio`, `QM5_20157_xau-xag-ratio`,
  `QM5_20161_xauxag-ols-rv`, `QM5_20263_xauxag-mad-rv`,
  `QM5_20268_xauxag-qtail-rv`, and `QM5_21526_xau-xag-cadf` estimate a
  relative level, center, scale, regression, tail, or stationarity state; this
  mechanic estimates none and uses only one completed return per metal;
- `QM5_20275_gsr-runfade` requires a fresh five-return same-sign ratio run and
  a counter-return event; this mechanic is one-way gold-led under-response
  and never counts a run;
- `QM5_20249_xauxag-vr-spread` and `QM5_20254_xauxag-vr-fade` estimate
  multiweek return memory before selecting continuation or reversion; this
  mechanic has no memory estimator or rolling regime;
- XAU/XAG cross-sectional momentum and seasonal systems rebalance on monthly
  horizons; this package closes after one synchronized D1 session;
- `QM5_41030_xauxag-flowdiv` compares completed weekly close-to-open and
  open-to-close relative-flow sums and trades only on component disagreement;
  this package has no open-price flow decomposition, weekly clock, or Friday
  lifecycle; and
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not an asymmetric two-leg causal-ordering test.

The auditable identity is the conjunction of gold-only completed-return
leadership, a fixed shock floor, bounded silver under-response, opposite
equal-notional legs, and first-next-D1 flattening. A failed result may not be
rescued by reversing causality, fitting a VAR, adding a ratio z-score, moving
the thresholds, dropping the hedge, or extending the hold.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-16_xauxag_gold_lead_lag_source_approval.md` authorize
exactly one card, deterministic ID allocation, one branch-only non-live
build, strict Q01, one logical `RISK_FIXED` backtest setfile, and one paced
Q02 enqueue if CPU capacity permits.

They exclude manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; neutrality claims; and correlation waivers.
Q09 alone may establish realized correlation with the certified book.

Expected cadence is approximately ten to thirty completed packages per full
post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
causal direction, current-bar leakage, unsynchronized endpoints, a missing or
late attempt, incorrect sides, excess notional mismatch, orphan survival,
wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive governed
economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-16 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic two-leg implementation and static validation | Q01 | PASS |
| v1-q02 | 2026-08-16 | one target-only logical-basket baseline row created below the tester ceiling | Q02 | ENQUEUED |
