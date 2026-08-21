---
ea_id: 11926
slug: rb-rsi-ma-filter
g0_status: APPROVED
r1_track_record: live_balke
source_id: live_balke
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 100
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-08-21
g0_approval_reasoning: "R1 traceable (live_balke); R2 now closed-form (single Standard exit regime, sizing added via respecification); R3 EURUSD.DWX governed; R4 mechanical, 1-pos-per-magic, no ML."
expected_pf: 1.15
expected_dd_pct: 12.0
---

# RB — RSI Trading Bot with MA Filter (René Balke)

Source: René Balke live-traded RSI system (lineage `live_balke`).
Target symbols: EURUSD.DWX

## Thesis
Standard RSI oscillator used in a trend-following context (MA filter) with a strict reset rule to prevent over-trading in parabolic regimes.

## Entry Rules
- **Timeframe:** H1. Signals evaluated on the last CLOSED H1 bar [1].
- **Trigger (Long):** `RSI(Close,14)[1] < 30`.
- **Trigger (Short):** `RSI(Close,14)[1] > 70`.
- **Trend Filter:** Long only if `Close[1] > SMA(Close,50)[1](D1)`; Short only if `Close[1] < SMA(Close,50)[1](D1)`.
- **Anti-Spam Reset:** After a Long entry, no further Long is permitted until `RSI(14)` has printed a value `>= 50` on a closed bar; symmetric (`<= 50`) for Shorts. Deterministic latch stored in EA state.

## Exit
- **Stop Loss:** Fixed 5.0% adverse move from entry price.
- **Take Profit:** Fixed 1.0% favourable move from entry price.
- **Position Sizing:** RISK_FIXED for backtest / RISK_PERCENT for live, sized so the 5.0% stop equals the configured per-trade risk. One position per magic; no averaging.

## Respecification Provenance (2026-08-21)
Wave-1 rejected this card R2-only: "mutually alternative standard and trailing exits are not resolved, and no position-risk/sizing rule is defined."
- **Defective passage:**
  `- **Standard:** 5% Stop Loss, 1% Take Profit.`
  `- **Alternative:** Trailing Stop (Trigger 0.5%, Trail 0.1%, Step 0.05%).`
- **Correction:** the two mutually-exclusive exit regimes are resolved to the single **Standard** regime (fixed 5.0% SL / 1.0% TP, the primary regime stated first in the source card). The trailing-stop alternative is removed so the exit is one immutable rule.
- **Sizing added:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the 5.0% stop, closing the missing position-risk rule. No new entry mechanics were introduced.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Swing (H1).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
