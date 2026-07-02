# QM5_12960_keltner-pullback-swing - Strategy Spec

**EA ID:** QM5_12960  
**Slug:** `keltner-pullback-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved H4 Keltner band-reentry pullback card. The
channel is EMA(20) +/- 1.5 x ATR(10), with EMA(50) as the trend gate. Long
entry requires the previous H4 candle to touch the lower band and the last
closed H4 candle to close back above the lower band while above EMA(50).
Shorts mirror at the upper band below EMA(50). The hard stop is 1.5 x ATR(14).
The strategy exits on the first closed-bar touch of the opposite band.

Friday close remains enabled by default for this H4 build per WS3 instruction.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_keltner_ema_period` | 20 | Keltner midline EMA |
| `strategy_keltner_atr_period` | 10 | Keltner ATR period |
| `strategy_keltner_mult` | 1.5 | Keltner ATR multiplier |
| `strategy_trend_ema_period` | 50 | Trend gate EMA |
| `strategy_sl_atr_period` | 14 | Risk stop ATR period |
| `strategy_sl_mult` | 1.5 | Risk stop ATR multiple |

## 3. Symbol Universe

- `SP500.DWX`, magic slot 0.
- `XAGUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: H4.
- Entry gating: `QM_IsNewBar()`.
- Signal and exit reads use closed H4 bars.

## 5. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
