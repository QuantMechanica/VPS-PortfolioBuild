---
ea_id: QM5_11289
slug: tc20-ha-sma14-osma-mom-rsi-h1
type: strategy
source_id: e78a9f1f-4e6a-563c-a080-915133d6ed28
sources:
  - "[[sources/dropbox-forex-pdf-archive]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum-oscillator]]"
  - "[[concepts/multi-indicator-confluence]]"
indicators:
  - "[[indicators/heiken-ashi]]"
  - "[[indicators/sma]]"
  - "[[indicators/osma]]"
  - "[[indicators/momentum]]"
  - "[[indicators/rsi]]"
period: H1
source_citation: "Thomas Carter, 20 Forex Trading Strategies (1 Hour Time Frame), Forex Trading Strategy #4, local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\376863900-20-Forex-Trading-Strategies-Collection.pdf"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 70
g0_approval_reasoning: "R1 local PDF/title attribution; R2 deterministic HA/SMA/OsMA/Momentum/RSI H1 entry+exit with plausible >2 trades/year/symbol despite selective filters; R3 DWX FX H1 testable; R4 fixed indicators no ML/grid/martingale."
---

# QM5_11289 TC20 Strategy #4 — Heiken Ashi + SMA(14) + OsMA + Momentum + RSI(5) (H1)

## Quelle
- Source: "20 Forex Trading Strategies (1 Hour Time Frame)" by Thomas Carter, 2014
- 2014 source URL/path: local PDF archive path listed below.
- Section: Forex Trading Strategy #4
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`
- Author: Thomas Carter. R1 PASS.

## Mechanik

Five-condition simultaneous entry: Heiken Ashi bullish + SMA(14) cross + OsMA crosses zero + Momentum crosses 100 + RSI(5) crosses 50. All five must align on the same bar. Most selective strategy in the TC20 H1 collection.

### Entry

**LONG** (all simultaneously on closed bar):
1. Bullish Heiken Ashi candle crosses **above** SMA(14).
2. OsMA(12,26,9) crosses **above** zero.
3. Momentum(10) crosses **above** 100.
4. RSI(5) crosses **above** 50.
5. Enter BUY at next bar open.

SL: a few pips below last swing low.
TP: double the SL distance.
Early exit: OsMA crosses back below zero.

**SHORT** (mirror):
1. Bearish Heiken Ashi candle crosses below SMA(14).
2. OsMA crosses below zero.
3. Momentum(10) crosses below 100.
4. RSI(5) crosses below 50.
5. Enter SELL.

Early exit: OsMA crosses above zero.

### Stop Loss
- Swing low/high at entry bar.
- P2 default: ATR(14) × 1.5.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H1
- Instruments: EURUSD.DWX, GBPUSD.DWX; P2: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX
- Spread cap: 20 pips

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Thomas Carter named, 2014. |
| R2 Mechanical | PASS | All 5 conditions are numeric comparisons (HA pattern from OHLC math, crosses on indicators). |
| R3 Data Available | PASS | H1 DWX data available. HA = computed from OHLC. |
| R4 No ML | PASS | Fixed-period indicators. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from TC20 H1 PDF, Strategy #4

## Implementation Notes for Codex (P1)
- Heiken Ashi: HAClose=(O+H+L+C)/4; HAOpen=(prev_HAOpen+prev_HAClose)/2; HA bullish = HAClose>HAOpen
- SMA(14): price_close
- OsMA = MACD_main - MACD_signal = iOsMA(NULL,0,12,26,9,PRICE_CLOSE,0)
- Momentum(10): iMomentum(NULL,0,10,PRICE_CLOSE,0) — cross above 100 = prev<100 && curr>=100
- RSI(5): iRSI(NULL,0,5,PRICE_CLOSE,0)
- TP: 2 × SL distance (compute SL = entry - swing_low, TP = entry + 2*SL)
- P3 sweeps: RSI period (5 vs 14), Momentum period (10 vs 14), require 3-of-5 vs all-5

## Verwandte Strategien
- Related: QM5_11290 (TC20 #5, SMMA55) — also H1 multi-condition; this adds HA visual + Momentum
- Differentiator: HA candle type as directional filter is unusual; requires HeikenAshi implementation

## Lessons Learned
- *(populated as pipeline progresses)*
