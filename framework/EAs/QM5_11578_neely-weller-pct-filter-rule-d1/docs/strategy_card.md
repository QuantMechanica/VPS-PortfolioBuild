---
ea_id: QM5_11578
slug: neely-weller-pct-filter-rule-d1
source_id: 577eb0aa-7880-5c0a-a8f9-56cd126c19f9
source_title: "Lessons from the Evolution of Foreign Exchange Trading Strategies"
source_author: Christopher J. Neely & Paul A. Weller
r1: PASS
r2: PASS
phase: G0
status: draft
period: D1
target_symbols:
  - EURUSD.DWX
  - GBPUSD.DWX
  - USDJPY.DWX
  - USDCHF.DWX
created_at: 2026-05-23
r1_track_record: PASS
r1_reasoning: "Single source_id present linking to Neely & Weller (2013), a peer-reviewed Federal Reserve / University of Iowa FX strategy study."
r2_mechanical: PASS
r2_reasoning: "Deterministic percentage filter: long/short when close moves x% from tracked local trough/peak; pure price arithmetic with no discretion."
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX all available as DWX D1 symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Pure threshold comparison on price history; always-in-market stop-and-reverse with fixed ATR safety SL; no ML or martingale."
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols,period,expected_trade_frequency"
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id Neely-Weller paper; R2 PASS deterministic pct filter stop-and-reverse with safety SL and plausible >=2 trades/year/symbol on D1 FX; R3 PASS DWX FX symbols; R4 PASS deterministic no ML/martingale."
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 6
---

## Concept

Neely & Weller (2013) filter rule: go long (short) when price rises (falls) by x% from
a recent local trough (peak). This differs from a channel breakout: the signal is a
percentage move from a local extreme, not from a rolling N-day high/low.

The paper tested filter sizes of 0.5%, 1%, 2% (small) and 3% (large) across 40 currency
pairs 1973-2012. Filter rules have the second-longest average trade duration (after carry)
and featured prominently in top-ranked portfolios in the late 1990s.

## Entry Logic

```mql5
// Inputs
double InpFilterPct = 0.01;  // filter size (1% = 0.01)

// Track running trough and peak
// On each bar: if new low since last long signal → update trough; if new high → update peak

// Implementation approach: use price level tracking
// Track lowest close since last SHORT signal → trough
// Track highest close since last LONG signal → peak

double trough = lowest_close_since_last_short;  // maintained in EA state
double peak   = highest_close_since_last_long;   // maintained in EA state

double close0 = iClose(NULL, PERIOD_D1, 1);  // last closed bar

// Long signal: price has risen InpFilterPct% above trough
bool LONG  = (trough > 0) && (close0 >= trough * (1.0 + InpFilterPct));

// Short signal: price has fallen InpFilterPct% below peak
bool SHORT = (peak > 0) && (close0 <= peak * (1.0 - InpFilterPct));

// After LONG signal: reset peak tracking to close0, clear trough tracker
// After SHORT signal: reset trough tracking to close0, clear peak tracker
```

## Exit Logic

Exit LONG when SHORT signal triggers (system is always in the market, like a stop-and-
reverse). Safety SL applied as a hard backstop.

## Risk / SL

Safety SL (P2 addition):
- `SL = 2 x iATR(NULL, PERIOD_D1, 14)` at entry bar, capped at 150 pips.
- `RISK_FIXED = 1000 USD` for P2 backtests.

## P2 Parameter Sweep

| Parameter      | Default | Sweep                    |
|----------------|---------|--------------------------|
| InpFilterPct   | 0.01    | 0.005, 0.01, 0.02, 0.03  |

## Notes

- Source citation: Neely & Weller (2013), "Lessons from the Evolution of Foreign Exchange Trading Strategies", journal/policy research article.
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX.
- Period: D1.
- Expected trade frequency: >= 6 trades/year/symbol at 0.5%-1% filters; >= 2 trades/year/symbol remains plausible across the sweep.
- Filter rule distinguishes from channel breakout: signal is pct-move from local extreme,
  not N-day lookback. These can diverge when local extremes are old but ATR is high.
- Paper's best individual rule composition: EUR ch(10) > EUR vma(5,20) > filter rules.
  Filter rules were top-ranked during specific sub-periods (late 1990s).
- Post-2000 on advanced pairs, all simple technical rules showed near-zero Sharpe without
  adaptive selection. P2 will confirm whether V5 out-of-sample period 2017-2024 reverts.
- R1 PASS: Federal Reserve / peer-reviewed.
- R2 PASS: pure close arithmetic, percentage threshold comparison.
