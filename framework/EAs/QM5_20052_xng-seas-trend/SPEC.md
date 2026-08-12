# QM5_20052_xng-seas-trend - Strategy Spec

**EA ID:** QM5_20052  
**Slug:** `xng-seas-trend`  
**Source:** `SUENAGA-MOP-XNG-2008-2012_S01`  
**Last revised:** 2026-07-23

## 1. Strategy Logic

On the first D1 bar of each broker month, the EA trades the sign of the prior 126-D1-bar XNG log return only in May-September and November-January. A +2% return buys and a -2% return sells. Season end, monthly rebalance, or the stale guard closes the position.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 126 | 84-252 | Closed D1 trend horizon |
| `strategy_min_abs_return_pct` | 2.0 | 1.0-5.0 | Neutral-band threshold |
| `strategy_atr_period` | 20 | 14-30 | D1 ATR period |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | Hard-stop distance |
| `strategy_max_hold_days` | 31 | 28-35 | Stale-position guard |
| `strategy_max_spread_points` | 1000 | 500-2500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- D1 execution and signal data; first bar of each broker month.

## 5. Expected Behaviour

- No more than eight eligible monthly packages per year; approximately 4-8 before Q02 validation.
- Symmetric directional trend exposure only inside the physical volatility seasons.
- Distinct from cumulative-RSI2 reversion and H4 prior-range breakout.

## 6. Source Citation

Suenaga, Smith and Williams (2008), *Journal of Futures Markets* 28(5), DOI 10.1002/fut.20317. Trend mechanic: Moskowitz, Ooi and Pedersen (2012), *Journal of Financial Economics* 104(2), DOI 10.1016/j.jfineco.2011.11.003.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02 backtest | RISK_FIXED | 1000 |
| Live | Not authorized | n/a |

No live setfile, deploy manifest, T_Live artifact, AutoTrading change, or portfolio-gate edit is part of this build.
