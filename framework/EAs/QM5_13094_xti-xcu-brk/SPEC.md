# QM5_13094_xti-xcu-brk - Strategy Spec

**EA ID:** QM5_13094
**Slug:** `xti-xcu-brk`
**Source:** `EIA-CME-USGS-XTI-XCU-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA trades a low-frequency D1 two-leg channel-breakout basket on
`XTIUSD.DWX` and `XCUUSD.DWX`. On each completed host D1 bar it computes:

`log(XTIUSD.DWX close) - strategy_beta_xcu * log(XCUUSD.DWX close)`

If the latest completed spread breaks above its entry channel, the EA buys WTI
and sells copper. If it breaks below the entry channel, the EA sells WTI and
buys copper. The package exits on a shorter channel reversal, max hold, Friday
close, or broken-package repair. Each leg receives a fixed ATR hard stop.

This is deliberately different from `QM5_13090_xti-xcu-rspread`, which fades
fixed-window return-spread z-score extremes. This EA follows price-level
log-spread continuation instead of mean reversion.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_lookback_d1` | 120 | 90-252 | D1 spread channel used for entry |
| `strategy_exit_lookback_d1` | 40 | 20-60 | D1 spread channel used for reversal exit |
| `strategy_beta_xcu` | 1.0 | 0.8-1.2 | Copper log-price multiplier and risk-weight proxy |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period for per-leg stops |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg hard stop distance in ATR |
| `strategy_max_hold_days` | 45 | 30-65 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xcu_max_spread_pts` | 1200 | 800-1800 | XCU entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | MT5 order deviation for basket sends |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13094_XTI_XCU_BRK_D1`.
- Host symbol: `XTIUSD.DWX`, magic slot 0.
- Second leg: `XCUUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 4-10 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: persistent divergence between energy and base-metal
  commodity risk.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "What drives crude oil prices: Spot
Prices", URL https://www.eia.gov/finance/markets/crudeoil/spot_prices.php.

CME Group, "Copper Futures", URL
https://www.cmegroup.com/markets/metals/base/copper.html.

U.S. Geological Survey, "Copper Statistics and Information", URL
https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information.

No source performance claim is imported. The sources define the WTI and copper
risk legs and the spread-breakout mechanization lineage; Q02 validates the
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
