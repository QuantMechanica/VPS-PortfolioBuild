# QM5_12578_eia-oilgas-ratio - Strategy Spec

**EA ID:** QM5_12578
**Slug:** `eia-oilgas-ratio`
**Source:** `EIA-OILGAS-RATIO-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural energy relative-value sleeve as a
two-leg basket on `XTIUSD.DWX` and `XNGUSD.DWX`. It computes the D1 log spread
`ln(XTIUSD) - beta * ln(XNGUSD)`, converts it to a rolling z-score, opens a
short-ratio package above +2.0, opens a long-ratio package below -2.0, and exits
both legs when the spread reverts inside +/-0.5. Each leg carries an ATR(20) *
3.0 hard stop.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`:
it does not use RSI or short-horizon pullback logic. It also differs from
`QM5_12575_eia-xng-season` and `QM5_12576_eia-wti-season` because this is a
paired oil/gas relative-value package, not a standalone calendar-seasonal trade.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 120 | 90-252 | D1 bars used for spread mean and standard deviation |
| `strategy_beta` | 1.0 | 0.5-1.5 | Hedge coefficient in the log spread |
| `strategy_entry_z` | 2.0 | 1.5-2.5 | Absolute z-score threshold for entry |
| `strategy_exit_z` | 0.5 | 0.25-0.75 | Absolute z-score threshold for exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.5 | Per-leg stop multiplier |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-4000 | XNG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and oil numerator, magic slot 0.
- `XNGUSD.DWX` - hedge leg and gas denominator, magic slot 1.
- Logical basket symbol: `QM5_12578_XTI_XNG_RATIO_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected spread packages/year: about 4-12.
- Typical hold: days to weeks.
- Regime preference: extreme oil/gas relative-price deviations.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration energy-explained pages for crude oil and
natural gas provide official structural lineage for separate but economically
linked energy markets. Supplemental Baker Institute research documents the
oil-natural-gas price relationship and substitution linkage. The card uses
these sources only for mechanism; no performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
