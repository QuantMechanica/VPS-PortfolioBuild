# QM5_12993_xnggold-rspread - Strategy Spec

**EA ID:** QM5_12993
**Slug:** `xnggold-rspread`
**Source:** `CME-GAS-GOLD-RELVAL-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency market-neutral natural gas/gold basket on
`XNGUSD.DWX` and `XAUUSD.DWX`. On each new D1 host bar it computes a rolling
return spread:

`log(XNG[t] / XNG[t-L]) - beta * log(XAU[t] / XAU[t-L])`

The current return spread is standardized against recent D1 history. A high
positive z-score means natural gas has outperformed gold over the fixed return
window, so the basket sells natural gas and buys gold. A high negative z-score
buys natural gas and sells gold. The package exits when the z-score reverts
near zero, max hold expires, Friday close fires, an orphan leg appears, or a
per-leg ATR stop is hit.

This is not a duplicate of `QM5_12824_cme-gasgold-ratio`, which fades the
absolute XNG/XAU log price ratio level. This EA trades temporary D1
relative-return dislocation between natural gas and gold. It is also distinct
from `QM5_12868_cme-gassilver-rspr` because the hedge leg is gold rather than
silver, and from `QM5_12567_cum-rsi2-commodity` because it is a paired
return-spread z-score package with no RSI pullback logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 10 | 5-20 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | History length for return-spread z-score |
| `strategy_beta` | 1.0 | 0.8-1.2 | Gold return multiplier and risk weight proxy |
| `strategy_entry_z` | 2.0 | 1.7-2.3 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 20 | 10-30 | Calendar-day stale package exit |
| `strategy_xng_max_spread_pts` | 2500 | 1500-3500 | Natural gas spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | Gold spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- Logical basket symbol: `QM5_12993_XNG_XAU_RSPREAD_D1`.
- Host symbol: `XNGUSD.DWX`, magic slot 0.
- Second leg: `XAUUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XNGUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: short-lived relative return dislocations between natural
  gas and gold where one leg has overrun the other.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

CME Group Henry Hub Natural Gas futures overview:
https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html.

CME Group Gold futures overview:
https://www.cmegroup.com/markets/metals/precious/gold.html.

The source packet frames the two exchange-traded commodity references. The EA
uses that lineage to define the XNG/XAU pair and tests a fixed-window
return-spread mechanization using Darwinex OHLC only. No source performance
claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
