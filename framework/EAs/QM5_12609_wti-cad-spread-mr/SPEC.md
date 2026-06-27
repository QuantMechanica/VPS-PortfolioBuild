# QM5_12609_wti-cad-spread-mr - Strategy Spec

**EA ID:** QM5_12609
**Slug:** `wti-cad-spread-mr`
**Source:** `BOC-CAD-OIL-SPREAD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural energy/FX relative-value sleeve
as a two-leg basket on `XTIUSD.DWX` and `USDCAD.DWX`. It computes the D1 log
spread `ln(XTIUSD) + beta * ln(USDCAD)`. If the spread is rich by z-score it
sells both legs; if it is cheap it buys both legs. The package exits on spread
z-score reversion, max-hold expiry, broken package repair, Friday close, or
per-leg ATR stops.

This is not a duplicate of `QM5_12607_wti-cad-confirm`, which uses USDCAD as a
confirmation filter and trades only WTI. This build opens and manages both legs
as a basket.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 90 | 60-180 | Prior spread sample for z-score |
| `strategy_beta` | 4.0 | 3.0-6.0 | USDCAD coefficient in the log spread |
| `strategy_entry_z` | 2.0 | 1.6-2.4 | Absolute z-score needed for entry |
| `strategy_exit_z` | 0.5 | 0.25-0.75 | Absolute z-score package exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 45 | 30-60 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_usdcad_max_spread_pts` | 80 | 50-120 | USDCAD entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and WTI leg, magic slot 0.
- `USDCAD.DWX` - petro-currency leg, magic slot 1.
- Logical basket symbol: `QM5_12609_XTI_USDCAD_SPREAD_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected spread packages/year: about 4-10.
- Typical hold: days to several weeks.
- Regime preference: temporary WTI/CAD relationship dislocations.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Bank of Canada Staff Analytical Note 2017-1 and Chen/Rogoff/Rossi (QJE 2010)
support the structural commodity-currency channel. EIA provides the energy
market context for Canada. These sources are used only for mechanism; no
performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
