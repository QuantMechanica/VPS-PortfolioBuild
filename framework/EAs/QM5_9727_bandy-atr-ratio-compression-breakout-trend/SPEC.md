# QM5_9727_bandy-atr-ratio-compression-breakout-trend

**EA ID:** QM5_9727
**Slug:** bandy-atr-ratio-compression-breakout-trend
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

## 1. Strategy Logic
On the close of each D1 bar, compute ATR(5, D1) and ATR(20, D1) and derive ratio ATR(5)/ATR(20). The compression flag is active if ratio <= 0.65 on prior or current closed bar. Enter LONG at next session open when close[1] breaks out above the 20-bar Donchian channel high (highest high of 20 closed bars prior to bar 1). Enter SHORT when close[1] breaks below 20-bar Donchian channel low. Exit using 2.5xATR(14) ratcheting trail, 45-day hard time stop, or opposite breakout.

## 2. Parameters
- strategy_atr_short_period = 5
- strategy_atr_long_period = 20
- strategy_compression_threshold = 0.65
- strategy_donchian_period = 20
- strategy_trail_atr_period = 14
- strategy_trail_atr_mult = 2.5
- strategy_max_hold_days = 45
