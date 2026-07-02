# QM5_12917_xti-driving-season-swing - Strategy Spec

**EA ID:** QM5_12917  
**Slug:** `xti-driving-season-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved WTI driving-season D1 swing card. Entries are
allowed from April 15 through June 30 by broker D1 calendar key. The EA opens
long when the last closed D1 close crosses above SMA(21), uses a 2.5 x ATR(14)
hard stop, and exits on the first of July 15 or later, close below SMA(21), or
the hard stop.

Calendar decisions use `QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1)` rather
than raw `iTime` calendar logic.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_window_start_mmdd` | 415 | Entry window start |
| `strategy_window_end_mmdd` | 630 | Entry window end |
| `strategy_hard_exit_mmdd` | 715 | Calendar exit date |
| `strategy_sma_period` | 21 | Trend confirmation SMA |
| `strategy_atr_period` | 14 | Risk stop ATR period |
| `strategy_atr_stop_mult` | 2.5 | Risk stop ATR multiple |
| `strategy_max_entries_per_year` | 2 | Seasonal re-entry cap |

## 3. Symbol Universe

- `XTIUSD.DWX`, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Entry gating: `QM_IsNewBar()`.
- Calendar and signal reads are based on closed D1 bars.

## 5. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. Friday close defaults to
disabled for this approved multi-week seasonal swing.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
