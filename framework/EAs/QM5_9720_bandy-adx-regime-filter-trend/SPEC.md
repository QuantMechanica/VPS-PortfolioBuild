# QM5_9720_bandy-adx-regime-filter-trend

**EA ID:** QM5_9720
**Slug:** bandy-adx-regime-filter-trend
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

## 1. Strategy Logic
On the close of each D1 bar, compute fast SMA(20), slow SMA(50), and Wilder ADX(14). Enter LONG at next session open when SMA(20) crosses above SMA(50) on closed bar 1 and ADX(14) >= 25.0. Enter SHORT when SMA(20) crosses below SMA(50) on closed bar 1 and ADX(14) >= 25.0. Exit using 2.5xATR(14) ratcheting trailing stop, 60-day hard time stop, or opposite crossover + ADX signal.

## 2. Parameters
- strategy_sma_fast_period = 20
- strategy_sma_slow_period = 50
- strategy_adx_period = 14
- strategy_adx_threshold = 25.0
- strategy_trail_atr_period = 14
- strategy_trail_atr_mult = 2.5
- strategy_max_hold_days = 60
