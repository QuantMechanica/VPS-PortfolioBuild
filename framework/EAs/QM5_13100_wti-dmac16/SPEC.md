# QM5_13100_wti-dmac16 - Strategy Spec

**EA ID:** QM5_13100
**Slug:** `wti-dmac16`
**Source:** `SZAKMARY-WTI-DMAC16-2010`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements the peer-reviewed source's monthly 1/6 dual-moving-average
commodity trend rule on `XTIUSD.DWX`. At the first D1 bar of a new broker month,
it reconstructs the six latest completed month-end closes from D1 history. The
latest close is the short value; the arithmetic mean of all six is the long
mean.

- Long when the latest month-end close is above the mean by more than 2.5%.
- Short when it is below the mean by more than 2.5%.
- Flat inside or on the neutral band.
- Hold while state is unchanged; flatten/reverse only at a new monthly state.
- A frozen D1 ATR hard stop is the only V5 risk-contract addition.

This is not the existing M15 30/140 crude crossover, 12-month return-sign
TSMOM, 3/9 or 6/12 return alignment, annual-extreme anchor, Donchian/ADX trend,
weekly volatility-gated momentum, commodity RSI, or WTI event/calendar logic.

## 2. Parameters

| Parameter | Default | Source/test range | Meaning |
|---|---:|---|---|
| `strategy_long_months` | 6 | 3, 6, 9, 12 | Completed month-end closes in the long mean |
| `strategy_band_pct` | 2.5 | 1.25, 2.5, 3.75, 5.0 | Symmetric neutral band around the long mean |
| `strategy_atr_period` | 20 | 14-30 | D1 ATR period for the hard stop |
| `strategy_atr_sl_mult` | 4.0 | 3.0-5.0 | Frozen ATR stop distance |
| `strategy_max_spread_points` | 1500 | 1000-2500 | Entry spread cap |

The source horizon/band variants are paired: 3/1.25%, 6/2.5%, 9/3.75%, and
12/5.0%. Q02 uses 6/2.5% only; later sweeps must not optimize an unconstrained
Cartesian product.

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- D1 host and new-bar gate.
- Completed D1 closes are sampled at month boundaries to supply the source's
  monthly values without depending on `.DWX` MN1 history materialization.
- One decision per broker-calendar month transition.

## 5. Expected Behaviour

- Expected entries: approximately 1-5/year before Q02 validation.
- Direction: symmetric long/short with a flat neutral state.
- Hold: month-to-month until neutral/opposite state or ATR hard stop.
- Friday close: disabled by approved card because weekly flattening would
  replace the source's monthly holding rule.
- Q02 risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## 6. Source Citation

Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010), "Trend-following
trading strategies in commodity futures: A re-examination", *Journal of
Banking & Finance*, 34(2), 409-426,
https://doi.org/10.1016/j.jbankfin.2009.08.004.

CME WTI benchmark supplement:
https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved | RISK_PERCENT | allocated by portfolio process |

There is no live setfile. No T_Live file, AutoTrading state, deploy manifest,
T_Live manifest, portfolio admission, or portfolio gate is touched.

## 8. Framework Alignment

- No-Trade: XTI/D1, slot, parameter, history, spread, duplicate-month, and
  one-position guards.
- Entry: monthly 1/6 mean and 2.5% band state, market request, ATR hard stop.
- Management: retain matching state; close neutral or opposed exposure at a
  month transition.
- Close: `QM_TM_ClosePosition` with strategy/opposite-signal reason; broker ATR
  stop remains active intramonth.

## 9. Pipeline History

| version | date | reason | next phase |
|---|---|---|---|
| v1 | 2026-07-09 | initial source-exact WTI monthly DMAC build | Q02 |
