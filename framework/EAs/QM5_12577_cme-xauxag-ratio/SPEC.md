# QM5_12577_cme-xauxag-ratio - Strategy Spec

**EA ID:** QM5_12577
**Slug:** `cme-xauxag-ratio`
**Source:** `CME-GSR-SPREAD-2025`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural gold-silver ratio sleeve as a
two-leg basket on `XAUUSD.DWX` and `XAGUSD.DWX`. It computes the D1 log spread
`ln(XAUUSD) - beta * ln(XAGUSD)`, converts it to a rolling z-score, opens a
short-ratio package above +2.0, opens a long-ratio package below -2.0, and exits
both legs when the spread reverts inside +/-0.5. Each leg carries an ATR(20) *
2.5 hard stop.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`:
it does not use RSI or short-horizon pullback logic. It is also not an outright
XAU trend/reversal sleeve; every entry is a paired XAU/XAG package.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 90 | 60-180 | D1 bars used for spread mean and standard deviation |
| `strategy_beta` | 1.0 | 0.8-1.2 | Hedge coefficient in the log spread |
| `strategy_entry_z` | 2.0 | 1.5-2.5 | Absolute z-score threshold for entry |
| `strategy_exit_z` | 0.5 | 0.25-0.75 | Absolute z-score threshold for exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | Per-leg stop multiplier |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 200 | 100-400 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XAUUSD.DWX` - host chart and ratio numerator, magic slot 0.
- `XAGUSD.DWX` - hedge leg and ratio denominator, magic slot 1.
- Logical basket symbol: `QM5_12577_XAU_XAG_RATIO_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected spread packages/year: about 8-16.
- Typical hold: days to weeks.
- Regime preference: precious-metals relative-value reversion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

CME Group, "Gold & Silver Ratio Spread", URL
https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.

Supplemental CME sources document precious-metals spread trading and 2025
gold-silver ratio drivers. No source performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
