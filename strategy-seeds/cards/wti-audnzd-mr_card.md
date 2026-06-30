---
ea_id: QM5_12837
slug: wti-audnzd-mr
type: strategy
strategy_id: EIA-RBA-RBNZ-WTI-FX-2026_S01
source_id: EIA-RBA-RBNZ-WTI-FX-2026
source_citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017. URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf; Reserve Bank of Australia, Drivers of the Australian Dollar Exchange Rate. URL https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html; Reserve Bank of New Zealand, Commodity prices and implications for monetary policy. URL https://www.rbnz.govt.nz/research-and-publications/research/our-research-and-analysis/additional-research/commodity-prices-and-implications-for-monetary-policy"
source_citations:
  - type: working_paper
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. (2017). The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_research
    citation: "Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate."
    location: "https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
    quality_tier: A
    role: supplement
  - type: central_bank_research
    citation: "Reserve Bank of New Zealand. Commodity prices and implications for monetary policy."
    location: "https://www.rbnz.govt.nz/research-and-publications/research/our-research-and-analysis/additional-research/commodity-prices-and-implications-for-monetary-policy"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-RBA-RBNZ-WTI-FX-2026]]"
concepts:
  - "[[concepts/oil-exchange-rate-linkage]]"
  - "[[concepts/commodity-fx-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, zscore-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, AUDUSD.DWX, NZDUSD.DWX]
basket_symbols: [XTIUSD.DWX, AUDUSD.DWX, NZDUSD.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 z-score basket on WTI priced against an AUD/NZD commodity-FX basket; estimate 4-9 packages/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS official EIA source plus RBA/RBNZ central-bank supplements; R2 PASS deterministic D1 log-spread z-score entry/exit, max-hold exit, and ATR stops; R3 PASS DWX XTIUSD/AUDUSD/NZDUSD symbols; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
---

# WTI AUD/NZD Commodity-FX Mean Reversion

## Source

- Source: [[sources/EIA-RBA-RBNZ-WTI-FX-2026]]
- Primary citation: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Supplement: Reserve Bank of Australia, "Drivers of the Australian Dollar
  Exchange Rate".
- Supplement: Reserve Bank of New Zealand, "Commodity prices and implications
  for monetary policy".

## Concept

Oil prices and exchange rates share a documented structural channel. This card
expresses WTI against an antipodean commodity-FX basket by using the Darwinex
native spread:

`spread = ln(XTIUSD.DWX) - beta_aud * ln(AUDUSD.DWX) - beta_nzd * ln(NZDUSD.DWX)`

A high spread means WTI is rich versus the AUD/NZD commodity-FX basket; the EA
sells WTI and buys both FX legs. A low spread buys WTI and sells both FX legs.
The thesis is temporary relative-value dislocation, not standalone WTI trend,
calendar seasonality, inventory timing, or oscillator pullback.

This is deliberately different from:

- `QM5_12831_wti-audusd-brk`: that card is a two-leg XTI/AUDUSD channel
  breakout; this card is a three-leg AUD+NZD z-score mean-reversion basket.
- `QM5_12825_wti-eurusd-spread`: that card uses EURUSD as a broad USD leg; this
  card uses an AUD/NZD commodity-FX basket.
- `QM5_12609_wti-cad-spread-mr`: not a CAD petro-currency pair.
- `QM5_12833` and `QM5_12834`: not JPY confirmation or JPY spread logic.
- `QM5_12835_wti-usdchf-brk`: not CHF safe-haven breakout logic.
- WTI calendar, WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, XTI/XNG,
  oil/gold, oil/silver, XAU/XAG, XNG, and `QM5_12567` RSI sleeves: no calendar,
  event feed, ratio to metals/gas, or RSI component.

## Hypothesis

WTI relative to AUD and NZD can mean-revert after D1 dislocations because oil,
global growth, commodity terms of trade, and USD risk appetite are related but
not perfectly synchronized. A three-leg basket reduces dependence on a single
FX hedge leg and provides a different energy sleeve from the current
XAU/SP500/NDX/XNG book.

## Markets And Timeframe

- Host symbol: `XTIUSD.DWX`.
- Basket leg symbols: `XTIUSD.DWX`, `AUDUSD.DWX`, and `NZDUSD.DWX`.
- Logical symbol: `QM5_12837_XTI_AUDNZD_MR_D1`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no EIA, RBA, RBNZ, futures-curve,
  macro CSV, API, analyst feed, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute the spread above on prior completed D1 bars.
- Compute a rolling z-score of the latest completed spread against the prior
  `strategy_z_lookback_d1` completed spreads.
- Short spread: if z-score is above `strategy_entry_z`, SELL `XTIUSD.DWX`, BUY
  `AUDUSD.DWX`, and BUY `NZDUSD.DWX`.
- Long spread: if z-score is below `-strategy_entry_z`, BUY `XTIUSD.DWX`, SELL
  `AUDUSD.DWX`, and SELL `NZDUSD.DWX`.
- No entry if any basket leg already has an open position for this EA magic.
- No entry if any symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at
  ATR(`strategy_atr_period_d1`) * `strategy_atr_sl_mult`.
- Exit all legs when absolute spread z-score falls below `strategy_exit_z`.
- Exit all legs after `strategy_max_hold_days`.
- If a package has fewer or more than three open legs, close the remaining legs
  immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes all basket legs.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Skip entries when XTI, AUDUSD, or NZDUSD spread exceeds its configured cap.
- Skip entries when any close series or ATR series is unavailable.
- Both FX legs and the XTI host must be trade-session ready at entry time.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open three-leg package at a time.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [90, 120, 180]
- name: strategy_beta_aud
  default: 0.6
  sweep_range: [0.4, 0.6, 0.8]
- name: strategy_beta_nzd
  default: 0.4
  sweep_range: [0.2, 0.4, 0.6]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.75, 2.0, 2.25]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 60]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_audusd_max_spread_pts
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_nzdusd_max_spread_pts
  default: 90
  sweep_range: [60, 90, 140]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]
- name: strategy_entry_hour_broker
  default: 0
  sweep_range: [0]
- name: strategy_entry_minute_broker
  default: 0
  sweep_range: [0]

## Author Claims

No source performance claim is imported into QM. The sources are used only for
structural lineage around oil/exchange-rate linkage and commodity-FX context.
Q02+ must validate this deterministic Darwinex-native realization.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 22
- expected_trade_frequency: approximately 4-9 basket packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA working paper plus central-bank RBA/RBNZ
  supplements.
- [x] R2 mechanical: fixed D1 spread definition, z-score entries, z-score/time
  exits, per-leg ATR hard stops, and broken-package repair.
- [x] R3 testable: `XTIUSD.DWX`, `AUDUSD.DWX`, and `NZDUSD.DWX` exist in the
  Darwinex symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Portfolio intent: WTI/AUD/NZD energy-FX sleeve distinct from the current
  XAU/SP500/NDX/XNG book and from existing WTI/CAD, WTI/EURUSD, WTI/AUDUSD,
  WTI/JPY, WTI/CHF, XTI/XNG, energy/metal, and XNG RSI builds.

## Framework Alignment

- no_trade: host chart guard, D1 guard, magic-slot guard, parameter guard,
  spread caps, and all-leg trade-session checks.
- trade_entry: three-leg basket entry on WTI versus AUD/NZD z-score extremes.
- trade_management: broken-package repair and max-hold guard.
- trade_close: z-score reversion exit, hard ATR stops, Friday close, and time
  stop.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial WTI/AUD/NZD mean-reversion basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-30 | QUEUED | TBD |
