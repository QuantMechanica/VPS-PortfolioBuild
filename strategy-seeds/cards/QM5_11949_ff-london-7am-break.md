---
ea_id: 11949
slug: ff-london-7am-break
g0_status: APPROVED
r1_track_record: forex_factory_classic
source_id: forex_factory_classic
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 250
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-08-21
g0_approval_reasoning: "R1 traceable (FF classic); R2 now closed-form (07:00 GMT reference candle OCO stops, 12:00 expiry, RC-opposite SL, 2:1-or-13:30 first-touch exit) via respecification; R3 EURUSD.DWX governed; R4 mechanical, 1-pos-per-magic, no ML."
expected_pf: 1.15
expected_dd_pct: 12.0
---

# FF — London 7:00 AM GMT Breakout

Source: ForexFactory classic London-open volatility-breakout thread (lineage `forex_factory_classic`).
Target symbols: EURUSD.DWX

## Thesis
The 07:00 GMT hourly candle (immediately before the London "big" open) sets the session's initial liquidity boundaries; a breakout of it often begins a sustained directional move.

## Entry Rules
- **Timeframe:** H1. **Reference candle:** the H1 bar whose open-time is 07:00 GMT (call it `RC`).
- **Pending Orders (placed at 08:00 GMT, i.e. at RC close):**
  - `BUY_STOP` at `High(RC)`.
  - `SELL_STOP` at `Low(RC)`.
- **OCO:** if one leg fills, cancel the opposite; one position per magic.
- **Expiry:** cancel any unfilled pending order at 12:00 GMT.

## Exit & Management
- **Stop Loss:** the opposite end of the reference candle (`Low(RC)` for Buys, `High(RC)` for Sells).
- **Take Profit:** whichever comes first — fixed **2:1 reward-to-risk** OR a **time exit at 13:30 GMT** (US session start).
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the stop distance.

## Respecification Provenance (2026-08-21)
- **Defective passage:** "Take Profit: Fixed 2:1 Reward-to-Risk ratio or at the start of the US session (13:30 GMT)."
- **Correction:** the TP "or" resolved to a deterministic first-touch-of-either rule (2:1 target OR 13:30 GMT time exit, whichever comes first). Reference candle, OCO stops, and 12:00 expiry were already mechanical and are restated. No new mechanics invented.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Intraday.
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
