# QM5_13115_energy-samecal - Strategy Spec

**EA ID:** QM5_13115  
**Slug:** `energy-samecal`  
**Strategy ID:** `KELOHARJU-RETSEAS-2016_XTI_XNG_S01`  
**Source:** `KELOHARJU-RETSEAS-2016`  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a monthly market-neutral XTI/XNG same-calendar-month
seasonality rank. On the first tradable D1 bar of each month, it reconstructs
that calendar month's completed XTI and XNG returns in prior years, averages
the synchronized XTI-minus-XNG relative returns, buys the higher seasonal leg,
and shorts the lower seasonal leg.

This is not XTI/XNG recent momentum, z-score reversion, volatility breakout,
carry, residual-volatility screening, a fixed month-direction map, or commodity
RSI. The recurring historical same-calendar-month rank is required for every
package.

## 2. Parameters

| Parameter | Default | Card range | Meaning |
|---|---:|---|---|
| `strategy_history_years` | 10 | 5, 10 | Maximum prior same-month years sampled |
| `strategy_min_history_years` | 5 | locked at 5 | Minimum synchronized samples |
| `strategy_history_bars` | 3000 | 1800-3000 | Bounded D1 reconstruction buffer |
| `strategy_atr_period_d1` | 20 | 14-30 | Per-leg ATR stop period |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | Per-leg frozen ATR stop multiple |
| `strategy_max_hold_days` | 35 | locked at 35 | Stale package close |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | WTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | Natural-gas entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Basket order deviation |

## 3. Symbol Universe

- Logical basket: `QM5_13115_ENERGY_SAMECAL_D1`.
- Host/traded slot 0: `XTIUSD.DWX`.
- Traded slot 1: `XNGUSD.DWX`.

## 4. Timeframe

- Host and both signal inputs: D1.
- Entry/reset: first D1 bar of each broker-calendar month.
- Raw history work is bounded behind `QM_IsNewBar()` and the monthly
  transition gate.

## 5. Expected Behaviour

- Expected completed packages: 10-12/year after five-year warm-up.
- Direction: market-neutral long one energy leg, short the other.
- Hold: one month, capped by 35 days, orphan cleanup, or per-leg ATR stop.
- Friday close: disabled to preserve the source's monthly holding horizon.
- Q02 risk: `RISK_FIXED=1000`, split equally across both legs.

## 6. Source Citation

Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016), "Return
Seasonalities", *The Journal of Finance* 71(4), 1557-1590,
DOI `10.1111/jofi.12398`.

Complete open working-paper version:
https://www.nber.org/system/files/working_papers/w20815/w20815.pdf

The source's 24-future commodity portfolio explicitly includes crude oil and
natural gas. This two-leg continuous-DWX carrier reduces source breadth and
history, so Q02 is a translation test rather than a replication.

## 7. Risk Model

| Environment | Mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 package budget |
| Live | not configured | n/a |

No live setfile, deploy manifest, portfolio gate, `T_Live` path, or
AutoTrading setting is part of this build.

## 8. Framework Alignment

- No-Trade: exact host/slot, parameters, synchronized history, spreads, ATR,
  lot, and arithmetic guards.
- Entry: monthly same-calendar-month relative rank and equal-risk two-leg
  package.
- Management: monthly reset, 35-day stale exit, and orphan cleanup.
- Close: per-leg ATR stops and deterministic basket flattening.

## 9. Pipeline History

| version | date | reason | next phase |
|---|---|---|---|
| v1 | 2026-07-10 | initial energy same-calendar-month basket | Q02 |

