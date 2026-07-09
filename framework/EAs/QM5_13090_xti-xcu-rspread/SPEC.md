# QM5_13090_xti-xcu-rspread - Strategy Spec

**EA ID:** QM5_13090
**Slug:** `xti-xcu-rspread`
**Source:** `EIA-CME-USGS-XTI-XCU-RSPREAD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA trades a low-frequency D1 two-leg return-spread reversion basket on
`XTIUSD.DWX` and `XCUUSD.DWX`. On each completed host D1 bar it computes a
fixed-window WTI log return, subtracts `strategy_beta_xcu` times the matching
copper log return, standardizes the return spread over a rolling window, and
fades z-score extremes.

Long spread means buy WTI and sell copper. Short spread means sell WTI and buy
copper. The EA exits both legs when the z-score normalizes, the package exceeds
max hold, Friday close fires, or one leg is orphaned. Each leg receives a fixed
ATR hard stop at entry.

This is deliberately different from WTI commodity-FX baskets, XTI/XNG baskets,
oil/gold and oil/silver baskets, solo copper EAs, WTI calendar/event/inventory
sleeves, and commodity-RSI logic. It isolates WTI versus copper relative-return
dislocation as a market-neutral commodity package.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 bars in each leg's fixed return |
| `strategy_z_lookback_d1` | 120 | 80-180 | Return-spread observations used for z-score |
| `strategy_beta_xcu` | 1.0 | 0.8-1.2 | Copper return multiplier and risk weight proxy |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score entry threshold |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Absolute z-score normalization exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period for per-leg stops |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg hard stop distance in ATR |
| `strategy_max_hold_days` | 30 | 20-45 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xcu_max_spread_pts` | 1200 | 800-1800 | XCU entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | MT5 order deviation for basket sends |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13090_XTI_XCU_RSPREAD_D1`.
- Host symbol: `XTIUSD.DWX`, magic slot 0.
- Second leg: `XCUUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: short-lived relative return dislocations between energy
  and base-metal commodity risk.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "What drives crude oil prices: Spot
Prices", URL https://www.eia.gov/finance/markets/crudeoil/spot_prices.php.

CME Group, "Copper Futures", URL
https://www.cmegroup.com/markets/metals/base/copper.html.

U.S. Geological Survey, "Copper Statistics and Information", URL
https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information.

Chan, Ernest P., *Algorithmic Trading: Winning Strategies and Their Rationale*,
Wiley, 2013, pair-spread mean-reversion implementation lineage.

No source performance claim is imported. The sources define the WTI and copper
risk legs and the pair-spread mechanization lineage; Q02 validates the
Darwinex implementation.

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
| v1 | 2026-07-09 | Initial build from approved card | Q02 enqueue target |
