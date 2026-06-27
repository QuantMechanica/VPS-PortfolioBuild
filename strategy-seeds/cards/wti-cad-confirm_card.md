---
ea_id: QM5_12607
slug: wti-cad-confirm
type: strategy
source_id: BOC-CAD-OIL-2017
source_citation: "Bank of Canada. The Link Between the Canadian Dollar and Commodity Prices: Has It Broken? Staff Analytical Note 2017-1. URL https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/; U.S. Energy Information Administration. Canada Country Analysis Brief. URL https://www.eia.gov/international/analysis/country/CAN"
sources:
  - "[[sources/BOC-CAD-OIL-2017]]"
concepts:
  - "[[concepts/commodity-currency-confirmation]]"
  - "[[concepts/wti-energy-sleeve]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [intermarket-confirmation, trend-filter-ma, atr-hard-stop, signal-failure-exit, time-stop, symmetric-long-short]
target_symbols: [XTIUSD.DWX]
confirmation_symbols: [USDCAD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly WTI D1 momentum package gated by opposite-direction USDCAD confirmation; estimate 6-16 entries/year after thresholds and trend filter."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS Bank of Canada/EIA source packet; R2 PASS deterministic weekly D1 WTI return plus USDCAD confirmation rules; R3 PASS XTIUSD.DWX and USDCAD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# WTI CAD Confirmation Trend

## Source

- Source: [[sources/BOC-CAD-OIL-2017]]
- Primary citation: Bank of Canada, "The Link Between the Canadian Dollar and
  Commodity Prices: Has It Broken?", Staff Analytical Note 2017-1, URL
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/.
- Supplement: U.S. Energy Information Administration, "Canada", Country
  Analysis Brief, URL https://www.eia.gov/international/analysis/country/CAN.

## Concept

Canada's currency has a documented commodity and oil-price sensitivity, but the
relationship is regime-dependent. This card therefore uses `USDCAD.DWX` only as
an intermarket confirmation filter for WTI, not as an external forecast feed.
When WTI has positive quarterly momentum and USDCAD has moved lower over the
same horizon, the confirmation says oil strength and CAD strength agree, so the
EA can buy `XTIUSD.DWX`. When WTI has negative quarterly momentum and USDCAD has
moved higher, oil weakness and CAD weakness agree, so the EA can short
`XTIUSD.DWX`.

This is deliberately different from:

- `QM5_12603_wti-tsmom12m`: this card uses a 63-day WTI signal plus USDCAD
  confirmation at a weekly gate, not monthly 12-month WTI-only momentum.
- `QM5_12563_donchian-turtle-trend-commodity`: not a Donchian breakout basket.
- `QM5_12576`, `QM5_12581`, `QM5_12583`, `QM5_12589`, and `QM5_12593`: not EIA
  refined-product, distillate, RBOB, shoulder, or refinery seasonal logic.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: not WPSR aftershock, fade, or
  pre-release positioning.
- `QM5_12591`, `QM5_12598`, and `QM5_12600`: not hurricane, OPEC, or CME
  expiry/roll-window logic.
- `QM5_12596`, `QM5_12597`, and `QM5_12599`: not weekday or February
  calendar-average seasonality.
- `QM5_12604`, `QM5_12605`, and `QM5_12606`: not an oil/gold or oil/silver
  ratio basket.
- `singh-cmd-corr`: that card trades CADJPY from oil support/resistance; this
  card trades WTI itself and uses USDCAD only as a confirmation symbol.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Host/traded symbol: XTIUSD.DWX.
- Confirmation symbol: USDCAD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only; no EIA feed, Bank
  of Canada feed, futures curve, COT report, inventory data, analyst forecast,
  CSV, API, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first available D1 bar of a new broker-calendar
  week.
- Compute completed-bar log returns for `XTIUSD.DWX` over
  `strategy_oil_lookback_d1` bars and `USDCAD.DWX` over
  `strategy_cad_lookback_d1` bars.
- Compute the prior completed `XTIUSD.DWX` close and SMA(`strategy_trend_period`).
- Long entry: WTI return is greater than `strategy_min_oil_return_pct / 100`,
  USDCAD return is less than `-strategy_min_cad_return_pct / 100`, and WTI close
  is above its SMA.
- Short entry: WTI return is less than `-strategy_min_oil_return_pct / 100`,
  USDCAD return is greater than `strategy_min_cad_return_pct / 100`, and WTI
  close is below its SMA.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit Long when the weekly confirmation is no longer long.
- Exit Short when the weekly confirmation is no longer short.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade on `XTIUSD.DWX` D1.
- Skip entries when either XTIUSD.DWX or USDCAD.DWX D1 history is too short.
- Skip entries when ATR, SMA, or return values are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open XTI position per magic.

## Parameters To Test

- name: strategy_cad_symbol
  default: USDCAD.DWX
  sweep_range: [USDCAD.DWX]
- name: strategy_oil_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_cad_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_min_oil_return_pct
  default: 3.0
  sweep_range: [2.0, 3.0, 5.0]
- name: strategy_min_cad_return_pct
  default: 1.0
  sweep_range: [0.5, 1.0, 1.5]
- name: strategy_trend_period
  default: 84
  sweep_range: [63, 84, 126]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 21
  sweep_range: [14, 21, 31]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The sources support structural lineage, not a performance claim. The Q02+
pipeline tests whether the deterministic WTI-plus-CAD confirmation port has an
edge on Darwinex `XTIUSD.DWX` bars with `USDCAD.DWX` as a closed-bar
confirmation series.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-16 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: central-bank analytical note and U.S. government
  energy country analysis.
- [x] R2 mechanical: fixed weekly gate, return thresholds, SMA trend filter, ATR
  hard stop, confirmation-failure exit, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` and `USDCAD.DWX` exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  external runtime feed, and one position per magic.
- [x] Non-duplicate: WTI host traded from CAD confirmation is not any existing
  WTI calendar, EIA, OPEC, hurricane, refinery, expiry, ratio, RSI, Donchian,
  or WTI-only trend sleeve.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX host guard, parameter guard, CAD symbol guard,
  spread cap, and weekly entry gate.
- trade_entry: weekly WTI return signal confirmed by opposite-direction USDCAD
  return and WTI SMA trend.
- trade_management: weekly confirmation-failure exit and max-hold stale-position
  exit.
- trade_close: hard ATR stop plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI CAD-confirmation build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
