# QM5_12959_elder-triple-screen-swing - Strategy Spec

**EA ID:** QM5_12959  
**Slug:** `elder-triple-screen-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved Elder Triple Screen H4 card. D1 close versus
SMA(200) sets direction. H4 RSI(14) gates the pullback wave: RSI below 30 for
longs and above 70 for shorts. The H1 ripple is a stop entry at the prior H1
high plus buffer for longs, or prior H1 low minus buffer for shorts. Pending
orders expire after 24 hours. The stop is beyond the recent H4 swing plus a
5-point buffer, and the take-profit is fixed at 2R.

Friday close remains enabled by default for this H4 build per WS3 instruction.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_sma_regime_period` | 200 | D1 direction SMA |
| `strategy_rsi_period` | 14 | H4 wave RSI period |
| `strategy_rsi_long_max` | 30.0 | Long wave threshold |
| `strategy_rsi_short_min` | 70.0 | Short wave threshold |
| `strategy_pending_expiry_hours` | 24 | Pending stop expiry |
| `strategy_rr_target` | 2.0 | Fixed R multiple target |
| `strategy_swing_lookback_h4` | 10 | H4 structure-stop lookback |
| `strategy_entry_buffer_points` | 5 | H1 stop-entry buffer floor |
| `strategy_sl_buffer_points` | 5 | H4 swing stop buffer |

## 3. Symbol Universe

- `NDX.DWX`, magic slot 0.
- `XAUUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: H4.
- Multi-timeframe reads: D1 direction and H1 stop trigger.
- Entry gating: `QM_IsNewBar()`.
- Signal reads use closed bars on each referenced timeframe.

## 5. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
