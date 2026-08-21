---
ea_id: 11927
slug: rb-atr-candle-break
g0_status: APPROVED
r1_track_record: live_balke
source_id: live_balke
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 50
target_symbols: ["XAUUSD.DWX"]
last_updated: 2026-08-21
g0_approval_reasoning: "R1 traceable (live_balke); R2 now closed-form (closed-bar signal, direction rule, entry timing, sizing pinned via respecification); R3 XAUUSD.DWX governed; R4 mechanical, 1-pos-per-magic, no ML."
expected_pf: 1.25
expected_dd_pct: 15.0
---

# RB — ATR Candle Breakout (Gold Momentum)

Source: René Balke ATR outlier-candle momentum system (lineage `live_balke`).
Target symbols: XAUUSD.DWX

## Thesis
Captures institutional momentum in Gold identified by an outlier candle that is large relative to recent volatility (ATR).

## Entry Rules
- **Timeframe:** H1. The signal candle is the last CLOSED H1 bar [1]; entry is a market order at the OPEN of the next bar.
- **Volatility Trigger:** `(High[1] - Low[1]) >= 1.5 * ATR(100)[1]`.
- **Candle-Form Filter:** `Body[1] = |Close[1] - Open[1]| >= 0.60 * (High[1] - Low[1])` AND the close sits in the extreme quartile in the breakout direction: for a Long, `Close[1] >= High[1] - 0.25*(High[1]-Low[1])`; for a Short, `Close[1] <= Low[1] + 0.25*(High[1]-Low[1])`.
- **Direction Rule:** the outlier candle's own direction sets the side — Long if `Close[1] > Open[1]` (bullish), Short if `Close[1] < Open[1]` (bearish).
- **Trend Filter:** Long only if `Close[1] > EMA(Close,200)[1](D1)`; Short only if `Close[1] < EMA(Close,200)[1](D1)`.
- **Time Filter:** signal bar close-time between 08:00 and 20:00 server time inclusive.

## Exit
- **Stop Loss:** Fixed 1.5% adverse move from entry price.
- **Take Profit:** Fixed 2.0% favourable move from entry price.
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the 1.5% stop. One position per magic; no averaging.

## Respecification Provenance (2026-08-21)
Wave-1 rejected this card R2-only: "candle direction, entry trigger/timing, and whether current means a closed bar are absent, so the rule cannot be implemented literally."
- **Defective passage:** `- **Trigger:** Current candle size >= 1.5x ATR(100).` (plus a Candle-Form filter that never named a side).
- **Correction:** "current candle" is pinned to the **last closed H1 bar [1]**; entry timing is pinned to a **market order at the next bar open**; and the missing **direction rule** is supplied from the outlier candle's own sign (bullish body -> Long, bearish body -> Short), which is the natural, source-consistent breakout side — no external mechanic invented. The top/bottom-25% "proximity" filter is expressed as an explicit quartile inequality per side.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Swing (H1).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
