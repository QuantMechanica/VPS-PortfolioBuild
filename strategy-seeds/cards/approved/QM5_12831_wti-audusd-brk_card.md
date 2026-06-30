---
ea_id: QM5_12831
slug: wti-audusd-brk
type: strategy
strategy_id: EIA-RBA-WTI-AUD-2026_S01
source_id: EIA-RBA-WTI-AUD-2026
source_citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017. URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf; Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate. URL https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
source_citations:
  - type: working_paper
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. (2017). The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration."
    location: "EIA working paper PDF"
    quality_tier: A
    role: primary
  - type: central_bank_education
    citation: "Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate."
    location: "https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-RBA-WTI-AUD-2026]]"
concepts:
  - "[[concepts/oil-exchange-rate-linkage]]"
  - "[[concepts/commodity-fx-relative-value]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/log-spread-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, donchian-breakout, atr-hard-stop, channel-exit, low-frequency]
target_symbols: [XTIUSD.DWX, AUDUSD.DWX]
basket_symbols: [XTIUSD.DWX, AUDUSD.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 channel breakout on a 120-day XTIUSD/AUDUSD log spread; estimate 4-9 basket packages/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS official EIA working paper plus RBA official AUD exchange-rate source; R2 PASS deterministic D1 XTIUSD/AUDUSD log-spread channel breakout, channel/time exits, and ATR stops; R3 PASS DWX XTIUSD/AUDUSD symbols; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
---

# WTI AUDUSD Commodity-FX Breakout

## Source

- Source: [[sources/EIA-RBA-WTI-AUD-2026]]
- Primary citation: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Supplement: Reserve Bank of Australia, "Drivers of the Australian Dollar
  Exchange Rate".

## Concept

Oil prices and exchange rates share a documented structural channel, and AUDUSD
is a commodity-sensitive FX proxy tied to global demand and terms-of-trade
conditions. This card converts that relationship into a Darwinex-native
relative-value basket: trade D1 channel breakouts in the log spread between
`XTIUSD.DWX` and `AUDUSD.DWX`.

This is deliberately different from:

- `QM5_12825_wti-eurusd-spread`: that card fades XTI/EURUSD z-score extremes;
  this card follows XTI/AUDUSD channel breakouts.
- `QM5_12609_wti-cad-spread-mr`, `QM5_12607_wti-cad-confirm`, and
  `QM5_12722_wti-cad-brk`: no CAD or petro-currency leg is used.
- WTI calendar, WPSR, OPEC, refinery, hurricane, SPR, expiry, ETF-roll,
  Cushing, XTI/XNG, oil/gold, oil/silver, gas/metal, XAU/XAG, and XNG RSI
  sleeves: this is a commodity-FX basket with AUDUSD as the second leg.

## Hypothesis

When the WTI/AUDUSD log spread breaks a multi-month D1 channel, the move may
reflect an energy-specific shock, global commodity-demand repricing, or a
temporary divergence between oil and the commodity-currency proxy. A two-leg
breakout package should add a structural energy/FX sleeve that is materially
different from the current index, metal, and natural-gas book.

## Markets And Timeframe

- Host symbol: `XTIUSD.DWX`.
- Basket leg symbols: `XTIUSD.DWX` and `AUDUSD.DWX`.
- Logical symbol: `QM5_12831_XTI_AUDUSD_BRK_D1`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no EIA, RBA, commodity-index,
  futures-curve, macro CSV, API, or analyst feed.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) - beta * ln(AUDUSD.DWX close)` on
  prior closed D1 bars.
- Compute the highest and lowest spread over `strategy_entry_lookback_d1`,
  excluding the most recent closed spread.
- Entry Long Spread: if the most recent closed spread is above the entry
  channel high, BUY `XTIUSD.DWX` and SELL `AUDUSD.DWX`.
- Entry Short Spread: if the most recent closed spread is below the entry
  channel low, SELL `XTIUSD.DWX` and BUY `AUDUSD.DWX`.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at
  ATR(`strategy_atr_period_d1`) * `strategy_atr_sl_mult`.
- For a long-spread package, exit both legs when the most recent closed spread
  falls below the `strategy_exit_lookback_d1` channel low.
- For a short-spread package, exit both legs when the most recent closed spread
  rises above the `strategy_exit_lookback_d1` channel high.
- If only one basket leg is open, close it immediately as a broken package.
- Close any package after `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Skip entries when XTI spread exceeds `strategy_xti_max_spread_pts`.
- Skip entries when AUDUSD spread exceeds `strategy_audusd_max_spread_pts`.
- Skip entries when either close series or either ATR series is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open basket package at a time.

## Parameters To Test

- name: strategy_entry_lookback_d1
  default: 120
  sweep_range: [90, 120, 180]
- name: strategy_exit_lookback_d1
  default: 40
  sweep_range: [20, 40, 60]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.75, 1.0, 1.25]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 35
  sweep_range: [20, 35, 55]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_audusd_max_spread_pts
  default: 80
  sweep_range: [50, 80, 120]

## Author Claims

No performance claim is imported from either official source. The sources are
used only for structural lineage around oil/exchange-rate linkage and AUD
commodity sensitivity. The Q02+ pipeline tests the deterministic Darwinex
`XTIUSD.DWX` / `AUDUSD.DWX` basket.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 22
- expected_trade_frequency: approximately 4-9 basket packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA working paper plus official RBA source.
- [x] R2 mechanical: fixed D1 log-spread channel entries, channel/time exits,
  ATR stops, spread caps, and one package at a time.
- [x] R3 testable: `XTIUSD.DWX` and `AUDUSD.DWX` exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime data.
- [x] Non-duplicate: not XTI/EURUSD z-score mean reversion, WTI/CAD,
  WTI calendar/event, energy/metal ratio, XTI/XNG, XAU/XAG, or XNG RSI logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` host guard, magic-slot guard, parameter guard,
  spread caps, both-symbol trade-session readiness, framework news, kill-switch,
  and Friday close.
- trade_entry: two-leg basket entry on XTI/AUDUSD log-spread channel breakout.
- trade_management: broken-package repair and package max-hold control.
- trade_close: channel reversal exits, max-hold exit, Friday close, ATR hard
  stops, and framework kill-switch close handling.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial structural WTI/AUDUSD commodity-FX breakout build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q01 Build Validation | 2026-06-30 | PASS | `artifacts/qm5_12831_build_result.json` |
| Q02 Backtest | 2026-06-30 | ENQUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` |

## Lessons Captured

- 2026-06-30: Added WTI/AUDUSD as a different energy/FX basket from existing
  XTI/EURUSD mean reversion and WTI/CAD sleeves.
