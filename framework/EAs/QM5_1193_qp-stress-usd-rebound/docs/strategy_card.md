---
ea_id: QM5_1193
slug: qp-stress-usd-rebound
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia Cross-Asset Stress USD Rebound

## Source

- Quantpedia "Short-Term Correlated Stress Reversal Trading", Cyril Dujava, 2024.
- USD safe-haven lineage: Lustig, Roussanov & Verdelhan, "Countercyclical Currency Risk Premia", Journal of Financial Economics 111(3), 2014.

## Mechanics

On each completed D1 bar:

1. Compute close-to-close returns for `SP500.DWX` and the approved oil proxy (`XTIUSD.DWX` preferred; `XBRUSD.DWX` fallback).
2. If both returns are below `0.0%`, mark a correlated risky-asset stress day.
3. At that D1 close, open a LONG-USD basket for one day:
   - SHORT `EURUSD.DWX`
   - SHORT `GBPUSD.DWX`
   - SHORT `AUDUSD.DWX`
   - LONG `USDJPY.DWX`
   - LONG `USDCAD.DWX`
4. Equal-risk each basket slot; if fewer than three legs have valid bars/spreads, skip the signal.

## Exit

- Close all basket legs at the next D1 close.
- Safety exit after 2 trading days if the scheduled close is unavailable.

## Stop Loss

- Per-leg initial stop: 1.5x ATR(20) D1.
- Basket kill: close all active legs if combined floating loss reaches 1.2x the intended basket risk.

## Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD total basket risk, split equally across active legs.
- Live: `RISK_PERCENT = 0.25` total basket risk.

## Additional Filters

- One position per magic slot.
- Skip legs with spread greater than 3x the 20-day median spread.
- P3 may test basket membership, but P1 default keeps the fixed five-leg USD basket.

## T6 Live-Promotion Caveat

`SP500.DWX` is not broker-routable. If the EA passes P0-P9 using `SP500.DWX` as a required signal leg, T6 deploy requires parallel validation using `NDX.DWX` or `WS30.DWX` as the equity-stress proxy before AutoTrading enable.
