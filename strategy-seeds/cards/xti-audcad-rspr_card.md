---
ea_id: QM5_13034
slug: xti-audcad-rspr
type: strategy
strategy_id: EIA-RBA-BOC-XTI-AUDCAD-2026_S01
source_id: EIA-RBA-BOC-XTI-AUDCAD-2026
source_citation: "EIA oil/exchange-rate working paper plus official RBA commodity-AUD and Bank of Canada oil-CAD context."
source_citations:
  - type: government_research
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_explainer
    citation: "Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate."
    location: "https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
    quality_tier: A
    role: aud_channel
  - type: central_bank_report
    citation: "Bank of Canada. Monetary Policy Report April 2026, Canadian outlook."
    location: "https://www.bankofcanada.ca/publications/mpr/mpr-2026-04-29/canadian-outlook/"
    quality_tier: A
    role: cad_oil_channel
sources:
  - "[[sources/EIA-RBA-BOC-XTI-AUDCAD-2026]]"
concepts:
  - "[[concepts/oil-exchange-rate-linkage]]"
  - "[[concepts/commodity-fx-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, AUDCAD.DWX]
basket_symbols: [XTIUSD.DWX, AUDCAD.DWX]
markets: [XTIUSD.DWX, AUDCAD.DWX]
primary_target_symbols: [XTIUSD.DWX, AUDCAD.DWX]
single_symbol_only: false
logical_symbol: QM5_13034_XTI_AUDCAD_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XTI/AUDCAD return-spread z-score reversion; estimate 6-12 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-07: R1 PASS official EIA/RBA/BoC source packet; R2 PASS deterministic D1 two-leg XTI/AUDCAD return-spread z-score reversion with spread caps, mean exit, max-hold exit, and ATR hard stops; R3 PASS XTIUSD.DWX and AUDCAD.DWX exist in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is WTI versus CAD-through-AUDCAD relative value, not XTI/AUDUSD breakout, XTI/NZD, XTI/CADJPY, XTI/CADCHF, WTI/USDCAD, XTI/XNG, Brent/WTI, oil-metal, XNG, XAU/XAG, calendar, WPSR, COT, or RSI commodity logic."
---

# XTI/AUDCAD D1 Return-Spread Reversion

## Thesis

Oil prices and exchange rates have a documented structural relationship, but
the relationship is unstable across regimes. This card uses the instability as
a relative-value setup instead of forecasting WTI or CAD directly.

The basket compares WTI to a CAD-through-AUDCAD proxy. Since `AUDCAD` rises
when AUD strengthens versus CAD and falls when CAD strengthens versus AUD, the
card computes the CAD proxy as the negative AUDCAD return:

`return_spread = XTI_return - beta_audcad * (-AUDCAD_return)`

Equivalently, the executable spread is `XTI_return + beta_audcad * AUDCAD_return`.
High positive spread means WTI is rich versus the CAD proxy; low negative spread
means WTI is cheap versus the CAD proxy.

## Source

- Source: [[sources/EIA-RBA-BOC-XTI-AUDCAD-2026]]
- Primary citation: Beckmann, Czudaj, and Arora, "The Relationship between Oil
  Prices and Exchange Rates", U.S. Energy Information Administration Working
  Paper, 2017.
- Support: Reserve Bank of Australia material for AUD commodity-currency
  behavior and Bank of Canada material for the historical CAD/oil channel.

## Market Universe

- Logical symbol: `QM5_13034_XTI_AUDCAD_RSPREAD_D1`.
- Host symbol: `XTIUSD.DWX`.
- Basket legs: `XTIUSD.DWX` and `AUDCAD.DWX`.
- Period: `D1`.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No EIA, RBA, BoC, futures curve, macro CSV, API,
  analyst forecast, alternative data, or ML model.

## Timeframe

- Evaluate only on completed D1 bars.
- Entry cadence: one host-chart D1 evaluation per bar.
- Typical hold: several D1 bars to several weeks, capped by max-hold.

## Entry

- Evaluate only on a new D1 bar of the `XTIUSD.DWX` host chart.
- Copy completed D1 closes for `XTIUSD.DWX` and `AUDCAD.DWX`.
- Compute `xti_ret = ln(XTI close[1] / XTI close[1 + strategy_return_lookback_d1])`.
- Compute `audcad_ret = ln(AUDCAD close[1] / AUDCAD close[1 + strategy_return_lookback_d1])`.
- Compute `return_spread = xti_ret + strategy_beta_audcad * audcad_ret`.
- Standardize the latest return spread against the prior
  `strategy_z_lookback_d1` return-spread observations.
- If z-score is greater than `strategy_entry_z`, short the spread: sell
  `XTIUSD.DWX` and sell `AUDCAD.DWX`.
- If z-score is less than negative `strategy_entry_z`, long the spread: buy
  `XTIUSD.DWX` and buy `AUDCAD.DWX`.
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

- Only run from the `XTIUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Require positive prices, valid return-spread standard deviation, valid ATR,
  valid lot sizing, and allowed spreads for both legs.
- Require both symbols to be selected and tradable through the framework.
- Framework kill-switch, symbol guard, magic resolver, news, and Friday-close
  controls remain active.

## Trade Management Rules

- Two-leg relative-value package.
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
- name: strategy_beta_audcad
  default: 0.65
  sweep_range: [0.4, 0.65, 0.9]
- name: strategy_entry_z
  default: 1.9
  sweep_range: [1.6, 1.9, 2.2]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.25, 0.4, 0.6]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 30
  sweep_range: [20, 30, 45]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_audcad_max_spread_pts
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The source packet establishes structural lineage for oil/exchange-rate,
commodity-AUD, and oil-CAD channels only. This card imports no source
performance number. Q02 and later phases must validate or reject the
`XTIUSD.DWX` / `AUDCAD.DWX` basket on Darwinex bars.

## Q08_Q11_Risks

- AUDCAD can behave as a commodity/risk cross rather than a clean CAD oil proxy.
- The post-2015 CAD/oil relationship may weaken or trend longer than the
  max-hold window.
- Two-leg CFD fills can leave a broken package; the EA must repair immediately.
- Crude gaps and AUDCAD session liquidity can concentrate losses in stress
  windows.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA working paper plus RBA and BoC official
  source packet with a single `source_id`.
- [x] R2 mechanical: fixed D1 return-spread z-score, spread caps, max-hold
  exit, mean-reversion exit, and ATR hard stops.
- [x] R3 testable: `XTIUSD.DWX` and `AUDCAD.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  pyramiding, and no external runtime feed.
- [x] Non-duplicate: XTI/AUDCAD return-spread mean reversion, not XTI/AUDUSD
  channel breakout, XTI/NZD, XTI/CADJPY, XTI/CADCHF, WTI/USDCAD, XTI/XNG,
  Brent/WTI, oil-metal, XNG, XAU/XAG, calendar, WPSR, COT, or RSI logic.

## Implementation Notes

- Slot 0: `XTIUSD.DWX`.
- Slot 1: `AUDCAD.DWX`.
- Use `QM_BasketOrder.mqh` for both legs.
- Use the logical basket setfile `QM5_13034_XTI_AUDCAD_RSPREAD_D1` for Q02.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Do not add live setfiles or touch live manifests.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XTI/AUDCAD return-spread reversion.
- trade_management: broken-package repair and max-hold guard.
- trade_close: z-score reversion exit, hard ATR stops, Friday close, and time
  stop.

## Falsification

Kill or recycle the card if Q02 cannot produce at least one valid logical-basket
trade, if Q02 PF is below 1.0 after costs, if synchronized XTI/AUDCAD history
is insufficient, or if Q08 shows drawdown concentration above the portfolio
stress limits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-07 | initial XTI/AUDCAD return-spread mean-reversion basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-07 | APPROVED | this card |
| Q01 Build Validation | 2026-07-07 | PENDING | local build |
| Q02 Baseline Screening | 2026-07-07 | PENDING | enqueue after compile |
