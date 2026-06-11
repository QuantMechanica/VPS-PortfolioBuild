---
ea_id: QM5_9920
slug: ff-mtf-candle-color-m5
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "Brb-Fraudin, Simple scalping system, all red or all green, ForexFactory, 2010, https://www.forexfactory.com/thread/215160-simple-scalping-system-all-red-or-all-green"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/multi-timeframe-momentum]]"
  - "[[concepts/scalping]]"
  - "[[concepts/candle-color-trend]]"
indicators:
  - "[[indicators/candle-color]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX]
period: M5
expected_trade_frequency: "High; all-green/all-red MTF candle alignment on M5 should produce roughly 120-240 trades/year/symbol after session and spacing filters."
expected_trades_per_year_per_symbol: 160
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/handle present; R2 deterministic MTF candle-color entry/SL/TP/flip/time exits with ~160 trades/year/symbol; R3 DWX FX OHLC/ATR testable; R4 fixed no-ML single-position rules."
---

# ForexFactory MTF Candle Color Scalper M5

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: Brb-Fraudin, "Simple scalping system, all red or all green", ForexFactory, 2010, URL https://www.forexfactory.com/thread/215160-simple-scalping-system-all-red-or-all-green.
- Thread: "Simple scalping system, all red or all green".
- Author / handle: `Brb-Fraudin`.
- URL: https://www.forexfactory.com/thread/215160-simple-scalping-system-all-red-or-all-green
- Source location: first post gives M5/M15/M30/H1 color alignment; post #3 gives approximate TP/SL (+15/+20 pips, -15 pip SL); post #6 clarifies active candle usage.

## Mechanik

### Entry
- Use M5 execution, but evaluate only on completed M5 bars to avoid active-candle repaint in backtests.
- Define candle color as close > open for green and close < open for red.
- Long setup:
  - Last completed M5 candle is green.
  - Current in-progress M15, M30, and H1 candles are green when evaluated at the M5 close using their current open and current close.
  - Previous completed M5 candle was not already part of an open long signal, preventing repeated entries on every aligned bar.
- Enter long at next M5 open. Short setup mirrors with all four timeframes red.

### Exit
- Primary TP: 15 pips on FX majors or 1.2R, whichever is closer.
- Optional extended TP cap: 20 pips if trade reaches 12 pips before any color disagreement.
- Exit immediately when the completed M5 candle flips against the position.
- Time stop: 12 M5 bars.

### Stop Loss
- FX initial SL: 15 pips, capped to the range `[0.8 * ATR(14,M5), 2.0 * ATR(14,M5)]`.
- XAUUSD not in primary basket; if tested later, use ATR-only stop.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- Trade only London and early New York sessions.
- Skip if M15 ATR(14) is below its 60-bar 25th percentile.
- Enforce at least 3 completed M5 bars between same-direction entries.
- One active position per magic-symbol.

## Concepts
- [[concepts/multi-timeframe-momentum]] - primary
- [[concepts/scalping]] - secondary
- [[concepts/candle-color-trend]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory first-post URL plus named handle `Brb-Fraudin`. |
| R2 Mechanical | PASS | Candle-color alignment, fixed SL/TP, color-flip exit, spacing, and time stop are deterministic. |
| R3 DWX-testbar | PASS | Uses only OHLC candle colors and ATR on DWX FX pairs. |
| R4 No ML | PASS | Fixed thresholds and no ML, online adaptation, grid, martingale, or multi-position scaling. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9702_ff-mtf-rsi-stack-m5]] - MTF oscillator stack; this card uses raw candle-color alignment only.
- [[strategies/QM5_9698_ff-symphonie-4lights-m15]] - multi-indicator light alignment; this card is indicator-free OHLC color alignment.

## Lessons Learned
- TBD during pipeline run.
