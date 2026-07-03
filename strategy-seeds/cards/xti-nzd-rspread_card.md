---
ea_id: QM5_13006
slug: xti-nzd-rspread
type: strategy
strategy_id: EIA-RBA-RBNZ-WTI-FX-2026_S02
source_id: EIA-RBA-RBNZ-WTI-FX-2026
source_citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017. URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf; Reserve Bank of New Zealand, Commodity prices and implications for monetary policy. URL https://www.rbnz.govt.nz/research-and-publications/research/our-research-and-analysis/additional-research/commodity-prices-and-implications-for-monetary-policy"
source_citations:
  - type: working_paper
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. (2017). The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
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
target_symbols: [XTIUSD.DWX, NZDUSD.DWX]
basket_symbols: [XTIUSD.DWX, NZDUSD.DWX]
markets: [XTIUSD.DWX, NZDUSD.DWX]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX, NZDUSD.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 z-score basket on WTI priced against NZDUSD; estimate 5-10 packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
g0_approval_reasoning: "R1 PASS official EIA oil/exchange-rate working paper plus RBNZ commodity-FX supplement; R2 PASS deterministic D1 XTI/NZD log-spread z-score entries/exits with ATR and time stops; R3 PASS DWX XTIUSD/NZDUSD data; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.07
expected_dd_pct: 18.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
---

# XTI/NZD Commodity-FX Residual Spread Reversion

## Source

- Source: [[sources/EIA-RBA-RBNZ-WTI-FX-2026]]
- Primary citation: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Primary URL: https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf
- Supplement: Reserve Bank of New Zealand, "Commodity prices and implications
  for monetary policy".
- Supplement URL: https://www.rbnz.govt.nz/research-and-publications/research/our-research-and-analysis/additional-research/commodity-prices-and-implications-for-monetary-policy

## Concept

Oil prices and exchange rates share a documented structural channel. This card
expresses WTI against a single NZD commodity-FX hedge leg using the Darwinex
native spread:

`spread = ln(XTIUSD.DWX) - beta_nzd * ln(NZDUSD.DWX)`

A high spread means WTI is rich versus NZDUSD; the EA sells WTI and buys
NZDUSD. A low spread buys WTI and sells NZDUSD. The thesis is temporary
relative-value dislocation, not standalone WTI trend, calendar seasonality,
inventory timing, or oscillator pullback.

This is deliberately different from:

- `QM5_12837_wti-audnzd-mr`: that card is a three-leg XTI/AUD/NZD basket; this
  card removes AUD entirely and tests a pure XTI/NZD residual spread.
- `QM5_12831_wti-audusd-brk`: that card is an XTI/AUDUSD channel breakout; this
  card is an XTI/NZD z-score mean-reversion basket.
- `QM5_12609_wti-cad-spread-mr`, `QM5_12825_wti-eurusd-spread`,
  `QM5_12833`, `QM5_12834`, and `QM5_12835_wti-usdchf-brk`: not CAD, EUR,
  JPY, or CHF petro/risk-proxy logic.
- WTI calendar, WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, XTI/XNG,
  oil/gold, oil/silver, XAU/XAG, XNG, and `QM5_12567` RSI sleeves: no calendar,
  event feed, ratio to metals/gas, or RSI component.

## Hypothesis

WTI relative to NZDUSD can mean-revert after D1 dislocations because oil, USD
risk appetite, global growth, and commodity-linked exchange-rate channels are
related but not perfectly synchronized. A two-leg WTI/NZD residual basket gives
the portfolio an energy/commodity-FX sleeve that is structurally different from
the current XAU/SP500/NDX/XNG book and from the existing AUD/NZD three-leg
realization.

## Rules

The strategy is deterministic: compute the prior-bar D1 log spread, convert it
to a rolling z-score, enter a two-leg XTI/NZD package only at configured
z-score extremes, and exit the full package on z-score reversion, time stop,
Friday close, broken-package repair, or hard ATR stop.

## Markets And Timeframe

- Host symbol: `XTIUSD.DWX`.
- Basket leg symbols: `XTIUSD.DWX` and `NZDUSD.DWX`.
- Logical symbol: `QM5_13006_XTI_NZD_RSPREAD_D1`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no EIA, RBNZ, futures-curve, macro CSV,
  API, analyst feed, or ML model.

## 4. Entry Rules

- Evaluate only on a new D1 bar.
- Compute the spread above on prior completed D1 bars.
- Compute a rolling z-score of the latest completed spread against the prior
  `strategy_z_lookback_d1` completed spreads.
- Short spread: if z-score is above `strategy_entry_z`, SELL `XTIUSD.DWX` and
  BUY `NZDUSD.DWX`.
- Long spread: if z-score is below `-strategy_entry_z`, BUY `XTIUSD.DWX` and
  SELL `NZDUSD.DWX`.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## 5. Exit Rules

- Stop loss: each leg receives a fixed hard SL at
  ATR(`strategy_atr_period_d1`) * `strategy_atr_sl_mult`.
- Exit all legs when absolute spread z-score falls below `strategy_exit_z`.
- Exit all legs after `strategy_max_hold_days`.
- If a package has fewer or more than two open legs, close the remaining legs
  immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes all basket legs.

## 6. Filters (No-Trade Module)

- Host chart must be `XTIUSD.DWX` on D1.
- Skip entries when XTI or NZDUSD spread exceeds its configured cap.
- Skip entries when either close series or ATR series is unavailable.
- Both the XTI host and NZDUSD hedge leg must be trade-session ready at entry
  time.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## 7. Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open two-leg package at a time.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [90, 120, 180]
- name: strategy_beta_nzd
  default: 0.5
  sweep_range: [0.3, 0.5, 0.7]
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
structural lineage around oil/exchange-rate linkage and NZD commodity-FX
context. Q02+ must validate this deterministic Darwinex-native realization.

## Risk

Q02 and later backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live risk,
if ever authorized after portfolio admission, is outside this build.

## Initial Risk Profile

- expected_pf: 1.07
- expected_dd_pct: 18
- expected_trade_frequency: approximately 5-10 basket packages/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA working paper plus central-bank RBNZ
  supplement.
- [x] R2 mechanical: fixed D1 spread definition, z-score entries, z-score/time
  exits, per-leg ATR hard stops, and broken-package repair.
- [x] R3 testable: `XTIUSD.DWX` and `NZDUSD.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Portfolio intent: WTI/NZD energy-FX sleeve distinct from the current
  XAU/SP500/NDX/XNG book and from existing WTI/AUD/NZD, WTI/AUDUSD, WTI/CAD,
  WTI/EURUSD, WTI/JPY, WTI/CHF, XTI/XNG, energy/metal, and XNG RSI builds.

## Framework Alignment

- no_trade: host chart guard, D1 guard, magic-slot guard, parameter guard,
  spread caps, and all-leg trade-session checks.
- trade_entry: two-leg basket entry on WTI versus NZDUSD z-score extremes.
- trade_management: broken-package repair and max-hold guard.
- trade_close: z-score reversion exit, hard ATR stops, Friday close, and time
  stop.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-03 | initial XTI/NZD residual-spread mean-reversion basket build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | work_item:ecb3d51d |
