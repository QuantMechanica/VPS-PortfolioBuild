# QM5_12817_xng-volshock-fade - Strategy Spec

**EA ID:** QM5_12817
**Slug:** `xng-volshock-fade`
**Source:** `EIA-XNG-VOLSHOCK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a D1 natural-gas volatility-shock mean-reversion rule on
`XNGUSD.DWX`. On each closed D1 bar, it measures the recent multi-day log
return and the current stretch from a D1 SMA in ATR units. A large downside
shock stretched below the SMA opens a long fade; a large upside shock stretched
above the SMA opens a short fade.

The logic is intentionally different from the existing XNG sleeves: no RSI,
storage-report timing, month-opening breakout, weekend gap, seasonal window,
52-week anchor, trend-following, or XTI/XNG basket logic is used.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_shock_lookback_d1` | 3 | 2-5 | D1 bars used for the return shock |
| `strategy_min_abs_return_pct` | 12.0 | 9.0-15.0 | Minimum absolute multi-day log-return shock |
| `strategy_sma_period` | 20 | 15-30 | D1 SMA used as reversion anchor |
| `strategy_atr_period` | 20 | 14-30 | D1 ATR period for stretch, stop, and target |
| `strategy_min_stretch_atr` | 1.40 | 1.10-1.80 | Minimum SMA stretch in ATR units |
| `strategy_max_stretch_atr` | 5.00 | 4.00-6.50 | Maximum stretch allowed before skip |
| `strategy_atr_sl_mult` | 3.25 | 2.50-4.00 | ATR stop distance multiplier |
| `strategy_atr_tp_mult` | 2.00 | 0.00-3.00 | ATR target distance multiplier; 0 disables TP |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1500 | 1000-2200 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.
- Not designed for `XTIUSD.DWX`, metals, indices, FX baskets, or XTI/XNG
  relative-value baskets.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe reads: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Typical hold: several D1 bars; capped at 8 calendar days by default.
- Regime preference: sharp natural-gas overshoots that are stretched from a
  short D1 mean.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Factors affecting natural gas prices",
Natural Gas Explained,
https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.
Supplemental official context: EIA Natural Gas Weekly Update and Weekly Natural
Gas Storage Report.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-30 | Initial XNG volatility-shock fade build |
