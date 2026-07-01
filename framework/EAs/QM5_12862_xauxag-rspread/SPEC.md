# QM5_12862_xauxag-rspread - Strategy Spec

**EA ID:** QM5_12862
**Slug:** `xauxag-rspread`
**Source:** `CME-XAUXAG-RSPREAD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency market-neutral precious-metals basket on
`XAUUSD.DWX` and `XAGUSD.DWX`. On each new D1 host bar it computes a rolling
return spread:

`log(XAU[t] / XAU[t-L]) - beta * log(XAG[t] / XAG[t-L])`

The current return spread is standardized against its recent D1 history. A high
positive z-score means gold has outperformed silver over the fixed return
window, so the basket sells gold and buys silver. A high negative z-score buys
gold and sells silver. The package exits when the z-score reverts near zero,
when max hold expires, on Friday close, or through per-leg ATR stops.

This is not a duplicate of `QM5_12577_cme-xauxag-ratio`, which fades the
absolute XAU/XAG log price ratio, or `QM5_12724_cme-xauxag-brk`, which follows a
ratio breakout. This EA trades temporary D1 relative-return dislocation between
the two metals.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 10 | 5-20 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | History length for return-spread z-score |
| `strategy_beta` | 1.0 | 0.8-1.2 | Silver return multiplier and risk weight proxy |
| `strategy_entry_z` | 2.0 | 1.7-2.3 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 20 | 10-30 | Calendar-day stale package exit |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | Gold spread cap |
| `strategy_xag_max_spread_pts` | 200 | 100-400 | Silver spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- Logical basket symbol: `QM5_12862_XAU_XAG_RSPREAD_D1`.
- Host symbol: `XAUUSD.DWX`, magic slot 0.
- Second leg: `XAGUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XAUUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: short-lived relative precious-metals return dislocations
  where one leg has overrun the other.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

CME Group, "Gold & Silver Ratio Spread", URL
https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.
CME Group, "Spread Trading Opportunities with Precious Metals", URL
https://www.cmegroup.com/education/articles-and-reports/spread-trading-opportunities-with-precious-metals.

The implementation uses the pair-spread mean-reversion template lineage from
Chan, Ernest P. (2013), *Algorithmic Trading: Winning Strategies and Their
Rationale*, Wiley, adapted to a fixed-window XAU/XAG return spread. No source
performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
