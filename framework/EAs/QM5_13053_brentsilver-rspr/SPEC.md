# QM5_13053_brentsilver-rspr - Strategy Spec

**EA ID:** QM5_13053
**Slug:** `brentsilver-rspr`
**Source:** `MACROTRENDS-SILVER-OIL-RATIO-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency market-neutral Brent/Silver basket on
`XBRUSD.DWX` and `XAGUSD.DWX`. On each new D1 host bar it computes a rolling
return spread:

`log(xbr[t] / xbr[t-L]) - beta * log(XAG[t] / XAG[t-L])`

The current return spread is standardized against recent D1 history. A high
positive z-score means Brent has outperformed silver over the fixed return
window, so the basket sells Brent and buys silver. A high negative z-score buys
Brent and sells silver. The package exits when the z-score reverts near zero,
max hold expires, Friday close fires, an orphan leg appears, or a per-leg ATR
stop is hit.

This is not a duplicate of `QM5_12864_oilsilver-rspr`, which uses WTI as the
oil leg, or `QM5_12606_oil-silver-ratio`, which fades the absolute WTI/silver
log price-ratio level. It is also distinct from Brent/gold, Brent/WTI,
XTI/XNG, XBR/XNG, XAU/XAG, directional Brent/WTI/XNG/XAU, seasonal/event, and
commodity RSI sleeves. This EA trades temporary D1 relative-return dislocation
between Brent and silver.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 10 | 5-20 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | History length for return-spread z-score |
| `strategy_beta` | 1.0 | 0.8-1.2 | Silver return multiplier and risk weight proxy |
| `strategy_entry_z` | 2.0 | 1.7-2.3 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 20 | 10-30 | Calendar-day stale package exit |
| `strategy_xbr_max_spread_pts` | 1200 | 800-1800 | Brent spread cap |
| `strategy_xag_max_spread_pts` | 200 | 100-350 | Silver spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13053_XBR_XAG_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`, magic slot 0.
- Second leg: `XAGUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XBRUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: short-lived relative return dislocations between Brent and
  silver where one leg has overrun the other.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Macrotrends, "Silver to Oil Ratio - Historical Chart", URL
https://www.macrotrends.net/2612/silver-to-oil-ratio-historical-chart.

Chan, Ernest P., *Algorithmic Trading: Winning Strategies and Their Rationale*,
Wiley, 2013, pair-spread mean-reversion implementation lineage.

The source frames crude oil through silver as a relative-value lens. The EA uses
that lineage to define an oil/silver pair, with Brent as the crude benchmark leg,
and tests a fixed-window return-spread mechanization using Darwinex OHLC only.
No source performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial build from card | Q02 queued by paced fleet handoff |
