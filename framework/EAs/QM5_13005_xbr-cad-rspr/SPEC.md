# QM5_13005_xbr-cad-rspr - Strategy Spec

**EA ID:** QM5_13005
**Slug:** `xbr-cad-rspr`
**Source:** `BOC-EIA-BRENT-CAD-RSPREAD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency two-leg Brent/CAD relative-value basket on
`XBRUSD.DWX` and `USDCAD.DWX`. On each new D1 host bar it computes:

`spread = ln(XBRUSD.DWX) + beta * ln(USDCAD.DWX)`

The current spread is standardized against its recent D1 history. A high
positive z-score means Brent is rich versus the CAD channel, so the basket sells
`XBRUSD.DWX` and sells `USDCAD.DWX`. A high negative z-score buys both legs.
The package exits when the z-score reverts toward zero, when max hold expires,
on Friday close, or through per-leg ATR stops.

This is not a duplicate of XAU/XAG, XNG, WTI/CAD, XNG/CAD, WTI event/calendar,
Brent calendar, oil/gas, oil-metal, or index sleeves. It trades a Brent/CAD
commodity-FX linkage with a two-leg basket and no external runtime data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 90 | 60-140 | History length for spread z-score |
| `strategy_beta` | 4.0 | 2.0-8.0 | USDCAD multiplier in the CAD-denominated Brent spread |
| `strategy_entry_z` | 2.0 | 1.6-2.4 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.5 | 0.2-0.8 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 45 | 25-60 | Calendar-day stale package exit |
| `strategy_xbr_max_spread_pts` | 1000 | 700-1500 | XBR entry spread cap |
| `strategy_usdcad_max_spread_pts` | 80 | 50-120 | USDCAD entry spread cap |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13005_XBR_CAD_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`, magic slot 0.
- Second leg: `USDCAD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XBRUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: temporary dislocations between global crude pricing and
  the Canada/oil FX channel.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

- Bank of Canada Staff Analytical Note 2017-1, "The Share of Systematic
  Variations in the Canadian Dollar - Part II",
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/
- U.S. EIA Today in Energy, "Canada's crude oil has an increasingly significant
  role in U.S. refineries", 2024-08-01,
  https://www.eia.gov/todayinenergy/detail.php?id=62664
- Canada Energy Regulator, "Market Snapshot: Overview of Canada-U.S. Energy
  Trade", 2025,
  https://www.cer-rec.gc.ca/en/data-analysis/energy-markets/market-snapshots/2025/market-snapshot-overview-of-canada-us-energy-trade.html

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
