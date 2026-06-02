# QM5_10481_mql5-exec-ao - Strategy Spec v2

**EA ID:** QM5_10481
**Slug:** `mql5-exec-ao`
**v2 Date:** 2026-06-02

## Fix Applied
v1 failed Q02 with `EA_MAGIC_NOT_REGISTERED: ea_id=10481 slot=20` because:
- The .ex5 was compiled against the 14-symbol magic resolver (GBPUSD=slot 1)
- But set files were generated with the 37-symbol expanded mapping (GBPUSD=slot 20)

This _v2 uses the 37-symbol mapping. Requires the updated magic_numbers.csv (worktree branch) to be merged and the .ex5 recompiled.

## Strategy: AO Momentum Bend
Trades Awesome Oscillator (fast SMA - slow SMA on PRICE_MEDIAN) bend patterns. Long on concave-up bend (AO > prev > prev2), short on concave-down. ATR-based SL/TP. Max hold bars exit and opposite-bend exit.

## Symbol Universe (37 symbols, M15)
AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY, EURAUD, EURCAD, EURCHF, EURGBP, EURJPY, EURNZD, EURUSD, GBPAUD, GBPCAD, GBPCHF, GBPJPY, GBPNZD, GBPUSD, GDAXI, NDX, NZDCAD, NZDCHF, NZDJPY, NZDUSD, SP500, UK100, USDCAD, USDCHF, USDJPY, WS30, XAGUSD, XAUUSD, XNGUSD, XTIUSD

## Risk
Backtest: RISK_FIXED=1000
