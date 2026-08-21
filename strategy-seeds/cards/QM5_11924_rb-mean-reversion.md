---
ea_id: 11924
slug: rb-mean-reversion
g0_status: APPROVED
r1_track_record: live_balke
source_id: live_balke
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 150
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-08-21
g0_approval_reasoning: "R1 traceable (live_balke); R2 now closed-form (RSI resolved to 14, all thresholds/sizing pinned via respecification); R3 EURUSD.DWX governed; R4 mechanical, 1-pos-per-magic, no ML."
expected_pf: 1.2
expected_dd_pct: 12.0
---

# RB — Mean Reversion EUR/USD (René Balke)

Source: René Balke live-traded mean-reversion system (lineage `live_balke`).
Target symbols: EURUSD.DWX

## Thesis
Harvests liquidity-provider premium by fading extreme price deviations from the 360-period moving average in sideways regimes.

## Entry Rules
- **Timeframe:** M15. Signals are evaluated only on the last CLOSED M15 bar (index [1]).
- **Basis Signal (Long):** `Close[1] <= SMA(Close,360)[1] * (1 - 0.006)` (price at least 0.6% below the 360-SMA).
- **Basis Signal (Short):** `Close[1] >= SMA(Close,360)[1] * (1 + 0.006)` (price at least 0.6% above the 360-SMA).
- **Daily Trend Filter:** Long only if `Close[1](D1) > SMA(Close,20)[1](D1)`; Short only if `Close[1](D1) < SMA(Close,20)[1](D1)`.
- **RSI Filter:** `RSI(Close,14)[1] > RSI(Close,14)[2]` (rising) for Longs; `RSI(Close,14)[1] < RSI(Close,14)[2]` (falling) for Shorts.
- **Volatility Compression:** `ATR(10)[1] < ATR(20)[1]` (mandatory).

## Exit
- **Primary Target:** Close the position when `Close[1] >= SMA(Close,360)[1]` (Longs) or `Close[1] <= SMA(Close,360)[1]` (Shorts) — i.e. price re-touches the 360-SMA.
- **Stop Loss:** Fixed 2.0% adverse move from entry price (charter hard stop).
- **Position Sizing:** RISK_FIXED for backtest / RISK_PERCENT for live, sized so the 2.0% stop equals the configured per-trade risk. One position per magic; no averaging.

## Respecification Provenance (2026-08-21)
Wave-1 rejected this card R2-only: "RSI period is left as 14 or 20, so the card does not select one immutable signal definition for a build."
- **Defective passage:** `- **RSI Filter (14 or 20):** RSI must be rising (current > prev) for Buys, falling for Sells.`
- **Correction:** the alternative is resolved to the single canonical value **RSI(14)** (the more common Balke/Wilder default and the lower-lag of the two). The rule is otherwise unchanged (rising for Buys, falling for Sells).
- Also pinned for closure: signal bar = last closed M15 bar `[1]`; the 0.6% deviation and 2.0% stop expressed as explicit closed-form inequalities; sizing rule (RISK_FIXED/RISK_PERCENT tied to the 2% stop) added since the original card left sizing implicit. No new mechanics introduced — all rules trace to the original card.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Scalping (M15).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
