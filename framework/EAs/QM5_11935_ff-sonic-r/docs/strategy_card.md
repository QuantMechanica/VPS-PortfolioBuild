---
ea_id: 11935
slug: ff-sonic-r
g0_status: APPROVED
r1_track_record: forex_factory_sonic
source_id: forex_factory_sonic
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 150
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-09-12
g0_approval_reasoning: "Edge Lab adversarial screen 2026-09-12 (OWNER go): closed-form card; the stated expected DD 14.0 pct is a sizing estimate -- approved at the 10 pct box expectation, RISK_FIXED backtests and the Q05/Q08 gates measure the realised DD; live sizing via RISK_PERCENT."
expected_pf: 1.2
expected_dd_pct: 10.0
g0_rejection_reason: "R2 FAIL: entry on 'the first retest of the Dragon that fails to close below it' is discretionary, the target is an undefined 'next major S/R', and the stop is an unresolved alternative (89-EMA side or 50-pip)."
---

# FF — Sonic R System

Source: ForexFactory "Sonic R" thread (lineage `forex_factory_sonic`).
Target symbols: EURUSD.DWX

## Thesis
Trend continuation off the "Dragon" EMA tunnel, filtered by the 89 EMA, entering on the first retest of the Dragon after a breakout.

## Indicator Definitions (closed bar [1], M15)
- **Dragon tunnel:** `DrH = EMA(High,34)`, `DrL = EMA(Low,34)`, `DrC = EMA(Close,34)`.
- **Trend filter:** `T = EMA(Close,89)`.

## Entry Rules (state machine, one position per magic)
- **Long path (requires `Close[1] > T[1]`):**
  1. Breakout: a closed bar prints `Close > DrH` (price breaks above the tunnel).
  2. Retest & hold: on a later closed bar, `Low[1] <= DrH[1]` (price returns into/at the tunnel) AND `Close[1] > DrL[1]` (it fails to close below the tunnel). Enter Long at that bar's close.
- **Short path (requires `Close[1] < T[1]`):**
  1. Breakout: a closed bar prints `Close < DrL`.
  2. Retest & hold: `High[1] >= DrL[1]` AND `Close[1] < DrH[1]`. Enter Short at that bar's close.

## Exit & Management
- **Stop Loss:** the far side of the 89 EMA — `T[1]` at entry (Long: stop below T; Short: above T).
- **Take Profit:** fixed 1.5 * initial risk (resolved from the "S/R or 1.5x risk" alternative to the closed-form 1.5R).
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the stop distance.

## Respecification Provenance (2026-08-21)
- **Defective passage:** "Wait for price to break above the Dragon, then enter on the first retest of the Dragon that fails to close below it"; "Take Profit: Next major Support/Resistance or fixed 1.5x risk"; "Stop Loss: Opposite side of the 89 EMA or a 50-pip safety stop."
- **Correction:** the "break then first retest that holds" language is made a two-step closed-bar state machine using the explicit Dragon tunnel bands (EMA34 of High/Low/Close); the TP alternative resolved to **1.5R** (the mechanical branch, dropping the discretionary S/R branch); the SL alternative resolved to the **89 EMA** side (the structural branch). No new mechanics invented.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Intraday Swing (M15).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
