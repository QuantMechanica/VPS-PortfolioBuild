# QM5_12722_wti-cad-brk - Strategy Spec

**EA ID:** QM5_12722
**Slug:** `wti-cad-brk`
**Source:** `BOC-CAD-OIL-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural energy/FX relative-value sleeve
as a two-leg basket on `XTIUSD.DWX` and `USDCAD.DWX`. It computes the D1 log
spread `ln(XTIUSD) - beta * ln(USDCAD)`. If the spread breaks above its long
channel, it buys WTI and sells USDCAD; if it breaks below, it sells WTI and
buys USDCAD. The package exits on the opposite short channel, max-hold expiry,
broken-package repair, Friday close, or per-leg ATR stops.

This is not a duplicate of `QM5_12609_wti-cad-spread-mr`, which fades z-score
extremes, or `QM5_12607_wti-cad-confirm`, which trades only WTI.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_lookback_d1` | 120 | 90-252 | Entry channel lookback |
| `strategy_exit_lookback_d1` | 40 | 20-60 | Exit channel lookback |
| `strategy_beta` | 4.0 | 3.0-6.0 | USDCAD coefficient in the signal spread |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 60 | 30-90 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_usdcad_max_spread_pts` | 80 | 50-120 | USDCAD entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and WTI leg, magic slot 0.
- `USDCAD.DWX` - petro-currency leg, magic slot 1.
- Logical basket symbol: `QM5_12722_XTI_USDCAD_BRK_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected spread packages/year: about 4-10.
- Typical hold: days to several weeks.
- Regime preference: synchronized WTI/CAD petro-currency trend regimes.
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
