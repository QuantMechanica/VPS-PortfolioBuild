# QM5_13113_energy-mom-ivol — Strategy Spec

**EA ID:** QM5_13113  
**Slug:** `energy-mom-ivol`  
**Strategy ID:** `FUERTES-MOMIVOL-2015_XTI_XNG_S01`  
**Source:** `FUERTES-MOMIVOL-2015`  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a monthly market-neutral XTI/XNG double screen. It computes
63-D1 momentum for both energy legs and estimates each leg's residual standard
deviation against an equal-weight D1 factor made from XTI, XNG, XAU, and XAG.
It buys the energy momentum winner and shorts the loser only when the winner is
also the lower-IVol leg. Conflicting rankings target flat.

This is not `QM5_12733` relative momentum alone, `QM5_12578` ratio reversion,
`QM5_12840` return-spread reversion, `QM5_12850` volatility-compression
breakout, `QM5_13089` carry ranking, or `QM5_12567` cumulative RSI. The second
independent residual-volatility rank is required for every package.

## 2. Parameters

| Parameter | Default | Source/card range | Meaning |
|---|---:|---|---|
| `strategy_signal_lookback_d1` | 63 | 21, 63, 126, 252 | Common momentum/IVol window |
| `strategy_atr_period_d1` | 20 | 14-30 | Per-leg ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg ATR hard-stop multiple |
| `strategy_max_hold_days` | 35 | 28-42 | Stale package close |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2000 | WTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4000 | Natural-gas entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Basket order deviation |

## 3. Symbol Universe

- Traded: `XTIUSD.DWX` slot 0 and `XNGUSD.DWX` slot 1.
- Read only: `XAUUSD.DWX` and `XAGUSD.DWX` as common factor members.
- Logical symbol: `QM5_13113_ENERGY_MOM_IVOL_D1`.

## 4. Timeframe

- Host and all signal inputs: D1.
- Entry/reset: first D1 bar of each broker-calendar month.
- Raw history work is bounded and gated behind `QM_IsNewBar()` plus the monthly
  key transition.

## 5. Expected Behaviour

- Expected completed packages: 6-10/year before Q02 validation.
- Direction: market-neutral long one energy leg, short the other.
- Hold: one month, capped by 35 days, orphan cleanup, or per-leg ATR stop.
- Friday close: disabled by the approved card to preserve the source's monthly
  holding horizon.
- Q02 risk: `RISK_FIXED=1000`, split equally across both legs.

## 6. Source Citation

Fuertes, A.-M., Miffre, J., and Fernandez-Perez, A. (2015), "Commodity
Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility,"
*Journal of Futures Markets* 35(3), 274-297, DOI `10.1002/fut.21656`.

Open accepted manuscript:
https://openaccess.city.ac.uk/id/eprint/6418/1/JFM_SSRN_13Jan2014.pdf

The card implements the paper's momentum-IVol double screen with its tested
equal-weight commodity benchmark alternative and 3-month window. The source's
27-future universe is reduced to four DWX factor proxies and two traded energy
legs, so Q02 is a carrier test rather than a replication.

## 7. Risk Model

| Environment | Mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 package budget |
| Live | not configured | n/a |

No live setfile, deploy manifest, portfolio gate, `T_Live` path, or AutoTrading
setting is part of this build.

## 8. Framework Alignment

- No-Trade: exact host/slot, parameter, history, OLS, spread, ATR, and lot guards.
- Entry: monthly momentum/IVol rank agreement and two-leg equal-risk package.
- Management: monthly reset, 35-day stale exit, and orphan cleanup.
- Close: per-leg ATR stops and deterministic basket flattening.

## 9. Pipeline History

| version | date | reason | next phase |
|---|---|---|---|
| v1 | 2026-07-10 | initial energy momentum-IVol double screen | Q02 |

