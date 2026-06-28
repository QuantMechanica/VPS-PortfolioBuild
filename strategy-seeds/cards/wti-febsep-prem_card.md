---
ea_id: QM5_12734
slug: wti-febsep-prem
type: strategy
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Tkacova, A. and Bukoven, M. Seasonal patterns in oil prices and their implications for investors. Journal of International Studies. URL https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
sources:
  - "[[sources/ARENDAS-OIL-SEASON-2018]]"
concepts:
  - "[[concepts/crude-oil-seasonality]]"
  - "[[concepts/seasonal-window-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, seasonal-window, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12734_XTI_FEBSEP_D1
period: D1
expected_trade_frequency: "February-September WTI seasonal window on D1; V5 Friday-close segmentation implies approximately 25-35 entries/year."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS academic oil-seasonality paper; R2 PASS deterministic February-September D1 long-season rule with ATR stop and time/season exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 20.0
---

# WTI February-September Seasonal Premium

## Source

- Source: [[sources/ARENDAS-OIL-SEASON-2018]]
- Primary citation: Arendas, P., Tkacova, A. and Bukoven, M., "Seasonal
  patterns in oil prices and their implications for investors", Journal of
  International Studies, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## Concept

Academic crude-oil seasonality research tests a structural allocation window
that holds oil exposure from February through September and avoids the weaker
late-year period. This card mechanizes that source-defined seasonal window as a
single `XTIUSD.DWX` sleeve, using only broker calendar state plus ATR for risk.

This is not another one-month WTI card. `QM5_12730_wti-mar-prem`,
`QM5_12727_wti-apr-prem`, and `QM5_12729_wti-aug-prem` isolate individual
months from the same source; this card tests the broader February-September
seasonal allocation as one low-frequency exposure. It is also not
`QM5_12576_eia-wti-season`, which uses EIA refined-product demand months plus
SMA/ROC confirmation, and it is not any WPSR, OPEC, refinery, hurricane,
expiry, ratio, RSI, Donchian, or time-series-momentum WTI sleeve.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory data, analyst forecasts, external API, CSV, or paper data feed.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar month must be February through September, inclusive.
- BUY `XTIUSD.DWX` at market if no open position exists for this EA magic.
- No short entries.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- No entry if ATR(`strategy_atr_period`) is unavailable.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit when the broker-calendar month is outside February-September.
- Exit after `strategy_max_hold_days` calendar days as a stale-position guard.
- Friday close remains enabled by the V5 framework. If Friday close flattens a
  position during the eligible season, the EA may re-enter on the next D1 bar.

## Risk

- Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Live risk, if ever approved later, is allocated only by the portfolio
  process.
- No `T_Live`, deploy manifest, AutoTrading, or portfolio-gate file is part of
  this card.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when parameters are invalid or spread exceeds the cap.
- Standard framework news, kill-switch, magic, and Friday-close guards remain
  active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_start_month
  default: 2
  sweep_range: [2]
- name: strategy_end_month
  default: 9
  sweep_range: [9]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0, 5.0]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported into the portfolio. The source is used only
for structural lineage around crude-oil month-of-year seasonality and the
February-September seasonal allocation window; Q02+ must validate the
mechanical Darwinex `XTIUSD.DWX` port.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 25-35 entries/year after V5
  Friday-close segmentation.
- risk_class: high for commodity volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic crude-oil seasonality paper with URL.
- [x] R2 mechanical: fixed broker-calendar seasonal window, single D1 long
  entry, ATR hard stop, time/season exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: this is the source-defined February-September seasonal
  window, not a one-month WTI sleeve, EIA demand map, WPSR/news/event timing,
  oil/gas ratio, RSI pullback, Donchian trend, or long-horizon TSMOM.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, February-September season gate,
  parameter guard, spread cap.
- trade_entry: long-only D1 entry inside the source-defined seasonal window.
- trade_management: max-hold stale-position exit.
- trade_close: ATR hard stop, season-end exit, max-hold exit, and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI February-September seasonal build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
