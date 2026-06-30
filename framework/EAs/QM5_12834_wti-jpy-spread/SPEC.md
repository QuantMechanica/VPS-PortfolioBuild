# QM5_12834_wti-jpy-spread - Strategy Spec

**EA ID:** QM5_12834
**Slug:** `wti-jpy-spread`
**Source:** `EIA-BOJ-WTI-JPY-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural energy/FX relative-value sleeve
as a two-leg basket on `XTIUSD.DWX` and `USDJPY.DWX`. It computes the D1 log
spread `ln(XTIUSD) - beta * ln(USDJPY)`. If the spread is rich by z-score it
sells WTI and buys USDJPY; if it is cheap it buys WTI and sells USDJPY. The
package exits on spread z-score reversion, max-hold expiry, broken package
repair, Friday close, or per-leg ATR stops.

This is not a duplicate of `QM5_12833_wti-jpy-confirm`, which uses USDJPY as a
read-only confirmation filter and trades only WTI. This build opens and manages
both XTI and USDJPY as a basket. It is also distinct from `QM5_12825`
XTI/EURUSD z-score logic and the CAD/AUD commodity-FX baskets.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 120 | 90-180 | Prior spread sample for z-score |
| `strategy_beta` | 1.0 | 0.75-1.25 | USDJPY coefficient in the log spread |
| `strategy_entry_z` | 2.0 | 1.75-2.25 | Absolute z-score needed for entry |
| `strategy_exit_z` | 0.5 | 0.25-0.75 | Absolute z-score package exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 45 | 30-60 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_usdjpy_max_spread_pts` | 60 | 30-100 | USDJPY entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |
| `strategy_entry_hour_broker` | 0 | 0 | Framework D1 new-bar entry cadence |
| `strategy_entry_minute_broker` | 0 | 0 | Earliest broker minute for daily entry attempt |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and WTI leg, magic slot 0.
- `USDJPY.DWX` - Japan oil-importer FX leg, magic slot 1.
- Logical basket symbol: `QM5_12834_XTI_USDJPY_SPREAD_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: one entry attempt per D1 bar through the framework new-bar gate.

## 5. Expected Behaviour

- Expected spread packages/year: about 4-10, default card estimate 7.
- Typical hold: days to several weeks.
- Regime preference: temporary WTI/yen oil-importer linkage dislocations.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration Japan Country Analysis Brief and Bank of
Japan June 2026 policy speech support the Japan energy-import and terms-of-trade
channel. Beckmann, Czudaj, and Arora, "The Relationship between Oil Prices and
Exchange Rates", EIA working paper, June 2017, is used as supplement. These
sources are used only for mechanism; no performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
