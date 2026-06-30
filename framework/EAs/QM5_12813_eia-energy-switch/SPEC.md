# QM5_12813_eia-energy-switch - Strategy Spec

**EA ID:** QM5_12813
**Slug:** `eia-energy-switch`
**Source:** `EIA-ENERGY-SEASON-SWITCH-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural energy relative-value basket on
`XTIUSD.DWX` and `XNGUSD.DWX`. It uses fixed EIA-supported seasonal windows:
long XTI/short XNG during the summer oil and gasoline demand window, and short
XTI/long XNG during the winter natural-gas heating demand window. The package
requires both legs to confirm the intended seasonal direction versus a D1 SMA,
then exits on window end, monthly rebalance, max hold, Friday close, broken
package repair, or per-leg ATR hard stop.

This is not a duplicate of `QM5_12578` XTI/XNG ratio reversion, `QM5_12608`
XTI/XNG breakout, `QM5_12733` XTI/XNG cross-sectional momentum, `QM5_12810`
WTI month ORB, `QM5_12812` XNG month ORB, or `QM5_12567` XNG RSI.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_period_d1` | 84 | 63-126 | D1 SMA confirmation period |
| `strategy_require_relative_trend` | true | true | Require both legs to confirm seasonal direction |
| `strategy_xti_start_month` | 5 | fixed | Start month for long-XTI summer window |
| `strategy_xti_start_day` | 15 | 1-15 | Start day for long-XTI summer window |
| `strategy_xti_end_month` | 8 | 8-9 | End month for long-XTI summer window |
| `strategy_xti_end_day` | 31 | fixed | End day for long-XTI summer window |
| `strategy_xng_start_month` | 11 | fixed | Start month for long-XNG winter window |
| `strategy_xng_start_day` | 1 | fixed | Start day for long-XNG winter window |
| `strategy_xng_end_month` | 3 | fixed | End month for long-XNG winter window |
| `strategy_xng_end_day` | 31 | fixed | End day for long-XNG winter window |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg ATR stop multiplier |
| `strategy_max_hold_days` | 35 | 25-45 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-4000 | XNG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and magic slot 0.
- `XNGUSD.DWX` - hedge leg and magic slot 1.
- Logical basket symbol: `QM5_12813_XTI_XNG_SEASON_SWITCH_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` plus one entry cap per broker-calendar month.

## 5. Expected Behaviour

- Expected spread packages/year: about 6-9 when the trend confirmation agrees.
- Typical hold: one calendar month or less.
- Regime preference: seasonal divergence between oil-linked summer demand and natural-gas winter heating demand.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

The source lineage is the U.S. Energy Information Administration. EIA Energy
Explained documents gasoline price seasonality around the spring and late-summer
driving cycle, and EIA Today in Energy documents seasonal natural gas demand and
storage withdrawal behavior. This build uses those public structural observations
only to define fixed calendar windows; no external data is read at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, or portfolio gate file is touched by this build.
