---
ea_id: QM5_10496
slug: mql5-mom-cross
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Scriptor idea, Vladimir Karputov (barabashkakvn) code, Crossing Moving Average, MQL5 CodeBase, published 2018-08-23, https://www.mql5.com/en/code/21515"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/ma-cross]]"
  - "[[concepts/momentum-filter]]"
indicators: [Moving Average, Momentum]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M15
expected_trade_frequency: "Two-MA cross with minimum-distance and Momentum override filter on M15; conservative estimate 60-150 trades/year/symbol."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 MQL5 CodeBase URL/title present; R2 explicit MA-cross plus Momentum filter with SL/TP/opposite-signal/time exits, ~100 trades/year/symbol; R3 MA/Momentum OHLC logic testable on DWX FX/metals; R4 fixed rules, no ML/grid/martingale, one-position gating."
---

# MQL5 Crossing Moving Average Momentum Filter

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Scriptor idea, Vladimir Karputov (barabashkakvn) code, "Crossing Moving Average", MQL5 CodeBase, published 2018-08-23, URL https://www.mql5.com/en/code/21515.
- Source location: page gives explicit buy/sell MA-cross pseudocode using MA values on bars #1 and #2 plus `ExtMA_MinimumDistance`, then checks each signal with a Momentum indicator filter. Source test shown on EURUSD M15.

## Mechanik

### Entry
- Evaluate only when a new bar appears.
- Compute First MA, Second MA, and Momentum.
- Long:
  - First MA[1] > Second MA[1] + minimum distance.
  - First MA[2] < Second MA[2] - minimum distance.
  - Momentum filter passes the long override threshold.
  - No active position for this symbol/magic.
- Short:
  - First MA[1] < Second MA[1] - minimum distance.
  - First MA[2] > Second MA[2] + minimum distance.
  - Momentum filter passes the short override threshold.
  - No active position for this symbol/magic.
- Baseline MA periods = 20/50 and Momentum period = 14; P3 sweeps source input ranges.

### Exit
- Protective SL baseline = 1.5 * ATR(14).
- TP baseline = 2.0R.
- Close on opposite confirmed MA/Momentum signal.
- Source trailing input is disabled for P2 and can be swept later as a fixed rule.
- Time stop after 64 M15 bars.

### Stop Loss
- ATR stop, normalized by symbol tick size and broker stop level.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip high-impact news windows when QM news filter is active.
- Spread filter required for M15 execution.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | Source publishes explicit MA-cross pseudocode and a deterministic Momentum filter. |
| R3 DWX-testbar | PASS | MA and Momentum are standard OHLC-derived indicators portable to DWX instruments. |
| R4 No ML | PASS | Fixed indicator rules, no ML, no grid/martingale, and one-position V5 gating. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10435_mql5-ma-cross]] - baseline MA crossover.
- [[strategies/QM5_10495_mql5-sep-trade]] - MA crossover with volatility filters.

## Lessons Learned
- TBD during pipeline run.
