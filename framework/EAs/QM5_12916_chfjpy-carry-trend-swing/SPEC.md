# QM5_12916_chfjpy-carry-trend-swing - Strategy Spec

**EA ID:** QM5_12916  
**Slug:** `chfjpy-carry-trend-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved CHFJPY D1 carry-trend swing card. It is long
only. Regime requires the last closed D1 close above SMA(200) and above the
close 63 D1 bars earlier. Entry occurs when the last closed D1 close crosses
back above SMA(10) from below while the regime is active. Exit occurs when the
last closed D1 close is below SMA(50). A 3.0 x ATR(20) hard stop is used as
the framework risk-sizing stop.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_sma_regime_period` | 200 | Trend regime SMA |
| `strategy_momentum_lookback` | 63 | D1 momentum lookback |
| `strategy_sma_entry_period` | 10 | Pullback recovery SMA |
| `strategy_sma_exit_period` | 50 | Trend failure exit SMA |
| `strategy_atr_period` | 20 | Risk stop ATR period |
| `strategy_atr_sl_mult` | 3.0 | Risk stop ATR multiple |

## 3. Symbol Universe

- `CHFJPY.DWX`, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Entry gating: `QM_IsNewBar()`.
- Signal and exit reads use closed D1 bars.

## 5. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. Friday close defaults to
disabled for the approved multi-week swing hold.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
