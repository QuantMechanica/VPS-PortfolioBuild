---
ea_id: QM5_12835
slug: wti-usdchf-brk
type: strategy
strategy_id: EIA-SNB-WTI-CHF-2026_S01
source_id: EIA-SNB-WTI-CHF-2026
source_citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017. URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf; Swiss National Bank. The Swiss franc as a safe-haven currency. SNB Quarterly Bulletin 2020 Q2. URL https://www.snb.ch/en/publications/communication/quarterly-bulletin/2020/q2"
source_citations:
  - type: working_paper
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. (2017). The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_research
    citation: "Swiss National Bank. The Swiss franc as a safe-haven currency. SNB Quarterly Bulletin 2020 Q2."
    location: "https://www.snb.ch/en/publications/communication/quarterly-bulletin/2020/q2"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-SNB-WTI-CHF-2026]]"
concepts:
  - "[[concepts/oil-exchange-rate-linkage]]"
  - "[[concepts/chf-safe-haven]]"
  - "[[concepts/commodity-fx-relative-value]]"
indicators:
  - "[[indicators/log-spread-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, donchian-breakout, atr-hard-stop, channel-exit, low-frequency]
target_symbols: [XTIUSD.DWX, USDCHF.DWX]
basket_symbols: [XTIUSD.DWX, USDCHF.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 channel breakout on XTIUSD priced in CHF terms; estimate 4-9 basket packages/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS official EIA oil/exchange-rate working paper plus SNB CHF safe-haven source; R2 PASS deterministic D1 XTIUSD-in-CHF channel breakout, channel/time exits, and ATR stops; R3 PASS DWX XTIUSD/USDCHF symbols; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
---

# WTI USDCHF CHF-Terms Breakout

## Source

- Source: [[sources/EIA-SNB-WTI-CHF-2026]]
- Primary citation: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.
- Supplement: Swiss National Bank, "The Swiss franc as a safe-haven currency",
  SNB Quarterly Bulletin 2020 Q2.

## Concept

Oil prices and exchange rates share a documented structural channel, while CHF
is a recurring safe-haven currency. This card expresses WTI in CHF terms with
the Darwinex-native proxy `ln(XTIUSD.DWX) + beta * ln(USDCHF.DWX)`, then trades
D1 channel breakouts in that composite series.

This is deliberately different from:

- `QM5_12825_wti-eurusd-spread`: that card fades XTI/EURUSD z-score extremes.
- `QM5_12831_wti-audusd-brk`: that card trades an AUD commodity-FX proxy and
  uses a minus-log spread; this card trades CHF safe-haven terms and uses a
  plus-log spread.
- `QM5_12834_wti-jpy-spread`: that card uses WTI/USDJPY z-score mean
  reversion; this card uses USDCHF breakout continuation.
- WTI/CAD, WTI event/calendar, XTI/XNG, energy/metal, XAU/XAG, and XNG RSI
  sleeves: this card is a CHF-terms oil breakout basket.

## Hypothesis

When WTI priced in CHF terms breaks a multi-month D1 channel, the move may
reflect a persistent energy/risk repricing rather than a standalone oil move.
A two-leg breakout package should add a WTI/CHF sleeve that is materially
different from the current index, metal, and natural-gas book.

## Markets And Timeframe

- Host symbol: `XTIUSD.DWX`.
- Basket leg symbols: `XTIUSD.DWX` and `USDCHF.DWX`.
- Logical symbol: `QM5_12835_XTI_USDCHF_BRK_D1`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no EIA, SNB, futures-curve, macro CSV,
  API, or analyst feed.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) + beta * ln(USDCHF.DWX close)` on
  prior closed D1 bars.
- Compute the highest and lowest spread over `strategy_entry_lookback_d1`,
  excluding the most recent closed spread.
- Entry Long Spread: if the most recent closed spread is above the entry
  channel high, BUY `XTIUSD.DWX` and BUY `USDCHF.DWX`.
- Entry Short Spread: if the most recent closed spread is below the entry
  channel low, SELL `XTIUSD.DWX` and SELL `USDCHF.DWX`.
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
- Skip entries when USDCHF spread exceeds `strategy_usdchf_max_spread_pts`.
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
- name: strategy_usdchf_max_spread_pts
  default: 80
  sweep_range: [50, 80, 120]
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
structural lineage around oil/exchange-rate linkage and CHF safe-haven context.
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

- [x] R1 reputable source: one source ID with official EIA and SNB citations.
- [x] R2 mechanical: fixed D1 CHF-terms spread definition, channel breakout
  entries, channel/time exits, and ATR stops.
- [x] R3 testable: `XTIUSD.DWX` and `USDCHF.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Portfolio intent: WTI/CHF energy-FX sleeve distinct from the current
  XAU/SP500/NDX/XNG book and from existing WTI/EURUSD, WTI/AUDUSD, and
  WTI/USDJPY builds.

## Framework Alignment

- no_trade: host chart guard, D1 guard, magic-slot guard, parameter guard,
  spread caps, and both-leg trade-session checks.
- trade_entry: D1 channel breakout in WTI priced in CHF terms.
- trade_management: broken-package repair and max-hold guard.
- trade_close: exit-channel failure, hard ATR stops, Friday close, and time
  stop.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial WTI/USDCHF CHF-terms breakout build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-30 | QUEUED | work_item `bcaf90f8-5b6f-4262-b2a5-53f874a42462` |
