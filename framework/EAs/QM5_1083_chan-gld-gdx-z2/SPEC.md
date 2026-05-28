# QM5_1083_chan-gld-gdx-z2 - Strategy Spec

**EA ID:** QM5_1083
**Slug:** `chan-gld-gdx-z2`
**Source:** `fce67611-4e0f-5dce-8cff-c8b9dd84dd49`
**Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1083_chan-gld-gdx-z2.md`
**Last revised:** 2026-05-26

## Strategy Logic

Daily close evaluation of a two-leg metals proxy spread. The EA estimates an OLS hedge ratio over the configured D1 lookback, computes `spread = leg_a_close - beta * leg_b_close`, and converts the spread to a rolling z-score.

- `z <= -2`: buy spread, long leg A and short hedge-adjusted leg B.
- `z >= +2`: short spread, short leg A and long hedge-adjusted leg B.
- Exit when the z-score crosses zero.
- Exit after `3 * estimated_half_life` D1 bars.
- Strategy stop closes the pair when `abs(z) >= 4`.

The primary pair is `XAUUSD.DWX` versus `XAGUSD.DWX`. The Card's alternative proxy is exposed as `XAUUSD.DWX` versus `XTIUSD.DWX` via `strategy_pair_index=1`.

## Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_pair_index` | 0 | `0` primary XAU/XAG, `1` alternative XAU/XTI. |
| `strategy_lookback_d1` | 100 | OLS hedge-ratio and z-score window. |
| `strategy_entry_z` | 2.0 | Absolute z-score entry threshold. |
| `strategy_exit_z` | 0.0 | Zero-line exit; values >0 exit inside that band. |
| `strategy_stop_z` | 4.0 | Strategy z-score stop. |
| `strategy_min_half_life_bars` | 2 | Minimum acceptable estimated half-life. |
| `strategy_max_half_life_bars` | 60 | Maximum acceptable estimated half-life. |
| `strategy_adf_t_max` | -1.30 | ADF-style stationarity proxy threshold. |
| `strategy_atr_period_d1` | 20 | D1 ATR period for protective SL and risk sizing. |
| `strategy_atr_sl_mult` | 4.0 | Protective SL multiplier. |
| `strategy_max_spread_points` | 0 | Optional max spread per leg; 0 disables. |

## Symbol Slots

| Slot | Symbol | Role |
|---:|---|---|
| 0 | `XAUUSD.DWX` | Leg A, gold proxy |
| 1 | `XAGUSD.DWX` | Primary leg B, silver proxy |
| 2 | `XTIUSD.DWX` | Alternative leg B, oil proxy |

## Framework Alignment

| V5 module | Implementation |
|---|---|
| No-Trade | D1 timeframe, registered symbol/slot, DWX suffix, optional spread cap. |
| Entry | `Strategy_EntrySignal` opens both pair legs through `QM_BasketOpenPosition`. |
| Management | No trailing, break-even, partial close, add-on, or rebalance. |
| Close | Zero-cross, `abs(z) >= 4`, and `3 * half_life` timeout. |

## Risk Model

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live setfile uses `RISK_PERCENT=0.25` and `RISK_FIXED=0`. `QM_FrameworkInit` enforces ENV-to-risk-mode consistency.
