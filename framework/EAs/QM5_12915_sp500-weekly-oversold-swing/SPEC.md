# QM5_12915_sp500-weekly-oversold-swing - Strategy Spec

**EA ID:** QM5_12915  
**Slug:** `sp500-weekly-oversold-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved SP500 D1 trend-filtered oversold swing card.
It opens long when the last closed D1 close is above SMA(200) and is the
lowest close in the last 10 D1 bars. It exits when the last closed D1 close
recovers above SMA(10) or after 15 D1 bars. A 2.5 x ATR(14) hard stop is used
as the framework risk-sizing stop.

The OnTick path follows the WS3 canonical order with the news gate applied to
entries only.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_sma_regime_period` | 200 | Long-only trend regime filter |
| `strategy_entry_lookback_low` | 10 | Lowest-close entry lookback |
| `strategy_sma_exit_period` | 10 | Mean-recovery exit |
| `strategy_time_stop_days` | 15 | D1 bar time stop |
| `strategy_atr_period` | 14 | Risk stop ATR period |
| `strategy_atr_sl_mult` | 2.5 | Risk stop ATR multiple |

## 3. Symbol Universe

- `SP500.DWX`, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Entry gating: `QM_IsNewBar()`.
- Signal and exit reads use closed D1 bars.

## 5. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. Friday close defaults to
disabled for the approved multi-day swing hold.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
