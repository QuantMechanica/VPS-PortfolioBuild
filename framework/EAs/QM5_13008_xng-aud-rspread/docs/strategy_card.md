---
ea_id: QM5_13008
slug: xng-aud-rspread
type: strategy
strategy_id: RBA-AUD-COMMODITY-2026_XNG_AUD_RSPREAD
source_id: RBA-AUD-COMMODITY-2026
source_citation: "Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate. https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
source_citations:
  - type: central_bank_explainer
    citation: "Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate."
    location: "https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
    quality_tier: A
    role: primary
sources:
  - "[[sources/RBA-AUD-COMMODITY-2026]]"
concepts:
  - "[[concepts/commodity-fx-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/return-spread-reversion]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX, AUDUSD.DWX]
basket_symbols: [XNGUSD.DWX, AUDUSD.DWX]
markets: [XNGUSD.DWX, AUDUSD.DWX]
primary_target_symbols: [XNGUSD.DWX, AUDUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13008_XNG_AUD_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XNG/AUD return-spread z-score reversion; estimate 6-14 paired packages/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, basket_leg_atomicity, symbol_history_sufficiency]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS single official RBA source; R2 PASS deterministic D1 two-leg XNG/AUD return-spread z-score reversion with spread caps, mean exit, max-hold exit, and ATR hard stops; R3 PASS XNGUSD.DWX and AUDUSD.DWX exist in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate versus existing commodity sleeves because this is XNG/AUD commodity-FX return-spread mean reversion, not XNG RSI, XNG seasonal/storage/weather/event logic, XNG/CAD residual spread, XBR/XNG or XTI/XNG energy spread, metals ratio, index, or outright WTI trend/seasonality."
---

# XNG/AUD D1 Return-Spread Reversion

## Source

- Source: [[sources/RBA-AUD-COMMODITY-2026]]
- Citation: Reserve Bank of Australia, "Drivers of the Australian Dollar
  Exchange Rate".
- URL: https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html

## Concept

The RBA identifies commodity prices, including natural gas, as a driver of the
terms of trade and the Australian dollar exchange rate. This card expresses
that structural channel as a Darwinex-native two-leg basket:

`return_spread = ln(XNG[t] / XNG[t-L]) - beta_aud * ln(AUDUSD[t] / AUDUSD[t-L])`

When natural gas has unusually outperformed AUDUSD over the fixed D1 return
window, the basket shorts gas and buys AUDUSD. When gas has unusually
underperformed AUDUSD, it buys gas and sells AUDUSD.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, no oscillator pullback, and no
  single-symbol commodity mean reversion.
- XNG seasonal/storage/weather/event cards: no EIA feed, weather proxy, rig
  count calendar, storage-calendar timing, freeze/hurricane logic, or month/day
  seasonal ownership.
- `QM5_13002_xng-cad-rspread`: different FX hedge leg and different commodity
  currency channel.
- `QM5_12999_xbr-xng-rspr`, `QM5_12840_xti-xng-rspread`, and
  `QM5_12850_xti-xng-vcb`: not an oil/gas spread and not a volatility breakout.
- XAU/XAG, gas/gold, gas/silver, oil/gold, oil/silver, WTI calendar, and index
  sleeves: this is an XNG/AUD commodity-FX residual spread.

## Market Universe

- Logical symbol: `QM5_13008_XNG_AUD_RSPREAD_D1`.
- Host symbol: `XNGUSD.DWX`.
- Basket legs: `XNGUSD.DWX` and `AUDUSD.DWX`.
- Period: `D1`.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No futures curve, RBA feed, EIA feed, CSV, API, analyst
  forecast, alternative data, or ML model.

## Timeframe

- Evaluate on completed D1 bars only.
- Entry cadence: one host-chart D1 evaluation per bar.
- Typical hold: several D1 bars to several weeks.

## Entry

- Evaluate only on a new D1 bar of the `XNGUSD.DWX` host chart.
- Copy completed D1 closes for `XNGUSD.DWX` and `AUDUSD.DWX`.
- Compute the fixed-window return spread above.
- Standardize the latest return spread against the prior
  `strategy_z_lookback_d1` return-spread observations.
- If z-score is greater than `strategy_entry_z`, short the spread: sell
  `XNGUSD.DWX` and buy `AUDUSD.DWX`.
- If z-score is less than negative `strategy_entry_z`, long the spread: buy
  `XNGUSD.DWX` and sell `AUDUSD.DWX`.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit

- Exit both legs when absolute z-score falls below `strategy_exit_z`.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Filters

- Only run from the `XNGUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Require positive prices, valid return-spread standard deviation, valid ATR,
  valid lot sizing, and allowed spreads for both legs.
- Require both symbols to be selected and tradable through the framework.
- Framework kill-switch, symbol guard, magic resolver, news, and Friday-close
  controls remain active.

## Trade Management Rules

- Market-neutral two-leg package.
- Symmetric long/short spread.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_return_lookback_d1
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta_aud
  default: 0.75
  sweep_range: [0.5, 0.75, 1.0]
- name: strategy_entry_z
  default: 1.9
  sweep_range: [1.6, 1.9, 2.3]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.2, 0.4, 0.7]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 30
  sweep_range: [20, 30, 45]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 3500]
- name: strategy_audusd_max_spread_pts
  default: 90
  sweep_range: [60, 90, 140]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The source establishes the commodity-price/AUD mechanism only. This card
imports no source performance number. Q02 and later phases must validate or
reject the `XNGUSD.DWX` / `AUDUSD.DWX` basket on Darwinex bars.

## Q08_Q11_Risks

- XNG custom-symbol history may be thinner or less synchronized than major FX;
  Q02 must validate synchronized D1 history sufficiency.
- AUDUSD can behave as a global risk proxy, so the basket may still have equity
  beta in crisis windows.
- Natural gas has gap and spread risk around futures/CFD session transitions.
- A commodity-currency relationship can trend for longer than the max-hold
  window; Q04-Q08 must judge robustness before portfolio admission.

## Strategy Allowability Check

- [x] R1 reputable source: single official RBA source with `source_id`.
- [x] R2 mechanical: fixed D1 return-spread z-score, spread caps, max-hold
  exit, mean-reversion exit, and ATR hard stops.
- [x] R3 testable: `XNGUSD.DWX` and `AUDUSD.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  pyramiding, and no external runtime feed.
- [x] Non-duplicate: XNG/AUD return-spread mean reversion, not existing XNG RSI,
  XNG/CAD, XBR/XNG, XTI/XNG, metal-ratio, WTI event/calendar, or index logic.

## Implementation Notes

- Slot 0: `XNGUSD.DWX`.
- Slot 1: `AUDUSD.DWX`.
- Use `QM_BasketOrder.mqh` for both legs.
- Use the logical basket setfile `QM5_13008_XNG_AUD_RSPREAD_D1` for Q02.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Do not add live setfiles or touch live manifests.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread caps,
  data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XNG/AUD return-spread reversion.
- trade_management: broken-package repair and max-hold guard.
- trade_close: z-score reversion exit, hard ATR stops, Friday close, and time
  stop.

## Falsification

Kill or recycle the card if Q02 cannot produce at least one valid logical-basket
trade, if Q02 PF is below 1.0 after costs, if synchronized XNG/AUD history is
insufficient, or if Q08 shows drawdown concentration above the portfolio stress
limits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-03 | initial XNG/AUD return-spread basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PENDING | local build |
| Q02 Baseline Screening | 2026-07-03 | PENDING | enqueue after compile |

