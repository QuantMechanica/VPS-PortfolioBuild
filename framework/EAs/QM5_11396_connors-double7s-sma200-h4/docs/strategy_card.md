---
ea_id: QM5_11396
slug: connors-double7s-sma200-h4
type: strategy
source_id: ea4596d1-24e0-5e43-9106-66fd575a5370
sources:
  - "[[sources/dropbox-forex-pdf-archive]]"
concepts:
  - "[[concepts/n-day-extreme]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/ma-trend-filter]]"
indicators:
  - "[[indicators/sma]]"
period: H4
source_citation: "Larry Connors and Cesar Alvarez, Short Term Trading Strategies That Work (2009) — Double 7's Strategy, Forex adaptation on H4. Local PDF: C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\100324184-Short-Term-Trading-Strategies-That-Work-by-Larry-Connors-and-Cesar-Alvarez.pdf"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 50
g0_approval_reasoning: "R1 single source_id/local Connors book attribution; R2 deterministic SMA200+7-bar close-extreme entry/exit with H4 cadence plausibly >2 trades/year/symbol; R3 DWX FX H4 testable; R4 deterministic no ML/HR14 issue"
---

# QM5_11396 Connors Double 7's — N-Day High/Low + SMA(200) (H4, Forex Adaptation)

## Quelle

- Source: "Short Term Trading Strategies That Work" by Larry Connors and Cesar Alvarez (2009)
  — "Double 7's Strategy" chapter
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\100324184-Short-Term-Trading-Strategies-That-Work-by-Larry-Connors-and-Cesar-Alvarez.pdf`
- Author: Larry Connors (named professional, 2009). R1 PASS.
- Note: Original strategy uses SPY/US indices. This card is a Forex adaptation on H4.

## Mechanik

When price is in an uptrend (above SMA(200)), a 7-period closing low signals a pullback entry.
Exit on a 7-period closing high (momentum returning to strength). Pure price-level extreme, no
oscillators. The "7" in "Double 7's" refers to the 7-period lookback used for both entry and exit.

### Entry

**LONG**:
1. Close[0] > SMA(200) (price is in an uptrend).
2. Close[0] == min(Close[0..6]) — today's close is the lowest close over the past 7 bars.
   Equivalently: `Close[0] < Close[1] && Close[0] == Lowest(Close, 7)`.
3. Enter BUY at next bar open.

**SHORT**:
1. Close[0] < SMA(200).
2. Close[0] == max(Close[0..6]) — highest close over 7 bars.
3. Enter SELL.

### Exit

**Exit LONG**: Close[0] == highest close over past 7 bars → close at next bar open.
**Exit SHORT**: Close[0] == lowest close over past 7 bars → close.

Alternative exit: RSI(2) above 70 for LONG exit (combined with QM5_11395 pattern).

### Stop Loss

- ATR(14) × 2.0 from entry (protective stop).
- P2 cap: 50 pips max.

### Position Sizing

- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter

- Timeframe: H4 (original uses daily; H4 provides more trades)
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX
- Spread cap: 20 pips

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Larry Connors, named professional, Wiley/TradingMarkets 2009. |
| R2 Mechanical | PASS | SMA(200) position check binary. Lowest/highest Close over N bars is pure OHLC math. Exit on N-bar high/close is deterministic. |
| R3 Data Available | PASS | H4 DWX data. |
| R4 No ML | PASS | SMA + N-bar extreme. No ML. |

G0 APPROVE eligible.

## Pipeline-Verlauf

- G0: 2026-05-23 — adapted from Connors/Alvarez (2009) Double 7's to Forex H4

## Implementation Notes for Codex (P1)

- Timeframe: H4
- DWX symbols: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX**
- SMA(200): `iMA(NULL,0,200,0,MODE_SMA,PRICE_CLOSE,0)`
- 7-bar low: compute `min_close7 = iLowest(NULL,0,MODE_CLOSE,7,0)` — if `Close[0] == Close[min_close7]` → entry LONG
- Actually use: `lowest = min(Close[0], Close[1], ..., Close[6])` and check `Close[0] <= lowest`
- 7-bar high exit: `Close[0] == max(Close[0..6])`
- Entry: next bar open after signal
- SL: `entry - iATR(NULL,0,14,0) * 2.0`; cap 50 pips
- P3 sweeps: lookback N (5 vs 7 vs 10 bars), SMA period (100 vs 200), exit method (N-bar high vs RSI2>70),
  TF H4 vs D1.

## Verwandte Strategien

- Related: QM5_11395 (connors-rsi2-sma200-pullback-h4) — same author, same trend filter, different signal
- Differentiator: Double 7's uses N-bar close extreme as entry/exit signal (no oscillators);
  RSI(2) strategy uses RSI extreme. Can be combined for higher-probability entries.

## Lessons Learned

- *(populated as pipeline progresses)*
