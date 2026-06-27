# QM5_12608_eia-oilgas-breakout - Strategy Spec

**EA ID:** QM5_12608
**Slug:** `eia-oilgas-breakout`
**Source:** `EIA-OILGAS-BREAKOUT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural energy relative-value sleeve as a
two-leg basket on `XTIUSD.DWX` and `XNGUSD.DWX`. It computes the D1 log spread
`ln(XTIUSD) - beta * ln(XNGUSD)` and trades channel breakouts in that spread.
Upside breakout buys the oil/gas ratio (buy XTI, sell XNG); downside breakout
sells it (sell XTI, buy XNG). The package exits on spread midline failure,
max-hold expiry, a broken package repair, Friday close, or per-leg ATR stops.

This is not a duplicate of `QM5_12578_eia-oilgas-ratio`, which fades oil/gas
z-score extremes and exits on reversion. It is also not a duplicate of
`QM5_12567_cum-rsi2-commodity`, because it uses no RSI/pullback logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_channel_lookback_d1` | 63 | 42-126 | Prior spread channel used for breakout detection |
| `strategy_exit_lookback_d1` | 20 | 14-30 | Spread average used as failure exit |
| `strategy_beta` | 1.0 | 0.7-1.3 | Hedge coefficient in the log spread |
| `strategy_breakout_buffer_sd` | 0.10 | 0.0-0.25 | Prior-channel standard-deviation buffer |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 45 | 30-60 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-4000 | XNG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and oil numerator, magic slot 0.
- `XNGUSD.DWX` - hedge leg and gas denominator, magic slot 1.
- Logical basket symbol: `QM5_12608_XTI_XNG_BREAKOUT_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected spread packages/year: about 5-12.
- Typical hold: days to several weeks.
- Regime preference: persistent oil/gas relative-price dislocations.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration research documents the crude oil and
natural gas price relationship and regime-dependent changes in that linkage.
The card uses this source only for mechanism; no performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
