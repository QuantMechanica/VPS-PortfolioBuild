---
ea_id: QM5_20060
slug: xcu-xag-rspread
type: strategy
strategy_id: PARNES-CME-COPPERSILVER-2026
source_id: PARNES-CME-COPPERSILVER-2026
source_citation: "Parnes (2024) peer-reviewed metal-ratio evidence and CME exchange research covering gold, silver, and copper; XCU/XAG mean reversion is an explicitly falsifiable transfer hypothesis."
source_citations:
  - type: peer_reviewed_paper
    citation: "Parnes, Dror. Copper-to-gold ratio as a leading indicator for the 10-Year Treasury yield. The North American Journal of Economics and Finance, 69A, Article 102016, 2024."
    location: "https://doi.org/10.1016/j.najef.2023.102016"
    quality_tier: A
    role: peer_reviewed_ratio_lineage
  - type: asset_manager_research
    citation: "State Street Global Advisors. The gold/copper ratio is rising, but this time the signal is different. 2026-05-04."
    location: "https://www.ssga.com/us/en/intermediary/etfs/insights/the-gold-copper-ratio-is-rising-but-this-time-the-signal-is-different"
    quality_tier: A-
    role: cyclical_defensive_metal_context
  - type: exchange_reference
    citation: "CME Group OpenMarkets. Gold, Silver, Copper: An Optimistic Outlook?"
    location: "https://www.cmegroup.com/openmarkets/metals/2024/Gold-Silver-Copper-An-Optimistic-Outlook.html"
    quality_tier: A-
    role: metals_market_reference
sources:
  - "[[sources/PARNES-CME-COPPERSILVER-2026]]"
concepts:
  - "[[concepts/copper-silver-ratio]]"
  - "[[concepts/commodity-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-relative-value, market-neutral-basket, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XCUUSD.DWX, XAGUSD.DWX]
basket_symbols: [XCUUSD.DWX, XAGUSD.DWX]
markets: [XCUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XCUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20060_XCU_XAG_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XCU/XAG copper-silver return-spread z-score reversion; estimate 5-10 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-23
expected_pf: 1.05
expected_dd_pct: 24.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "APPROVED under the 2026-07-23 OWNER commodity-sleeve mission. R1 PASS: peer-reviewed metal-ratio evidence plus CME exchange coverage of copper and silver; the exact XCU/XAG reversion claim is labelled a transfer hypothesis, not a source claim. R2 PASS deterministic D1 XCU/XAG return-spread basket. R3 PASS because XAGUSD.DWX is widely registered and existing XCU builds use XCUUSD.DWX, with synchronized multi-symbol history and fills left to Q02. R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate: no XCU/XAG card, registry row, or EA existed at intake."
---

# XCU/XAG D1 Return-Spread Reversion

## Source

- Source: [[sources/PARNES-CME-COPPERSILVER-2026]]
- Primary citation: Dror Parnes, "Copper-to-gold ratio as a leading indicator
  for the 10-Year Treasury yield", The North American Journal of Economics and
  Finance, Volume 69 Part A, Article 102016, January 2024,
  https://doi.org/10.1016/j.najef.2023.102016.
- Market context: State Street Global Advisors gold/copper ratio explainer
  dated 2026-05-04 and CME OpenMarkets metals context.

## Concept

The source packet establishes that metal ratios carry macro information and
that copper and silver have distinct industrial/monetary demand mixes. It does
not establish this exact trading rule. This card therefore treats temporary
copper-minus-silver return-spread normalization as a transfer hypothesis to be
falsified by Q02 onward. It consumes no external source at runtime.

The Darwinex-native package is:

`return_spread = ln(XCU[t] / XCU[t-L]) - beta_xag * ln(XAG[t] / XAG[t-L])`

When copper has unusually outperformed silver, the package sells `XCUUSD.DWX`
and buys `XAGUSD.DWX`. When copper has unusually underperformed silver, it buys
`XCUUSD.DWX` and sells `XAGUSD.DWX`. The thesis is temporary return-spread
normalization between a growth-sensitive industrial metal and a defensive
precious metal, not an outright copper or silver forecast.

This is deliberately different from:

- `QM5_13080_xcu-donchian55`: solo copper trend breakout.
- `QM5_13081_xcu-4w-reversal`: solo copper four-week reversal.
- `QM5_13085_xcu-audusd-rspr`: copper/AUD commodity-FX return spread.
- `QM5_13090_xti-xcu-rspread` and `QM5_13094_xti-xcu-brk`: oil/copper baskets.
- XTI/XAU oil/gold, XNG/XAU gas/gold, XAU/XAG gold/silver, WTI event/calendar,
  index, and `QM5_12567_cum-rsi2-commodity` logic.

## Hypothesis

Extreme completed-D1 copper-minus-silver return spreads should partially
normalize because copper and silver both sit in the metals complex while
representing different macro regimes. The EA expresses that hypothesis as a
two-leg basket and only needs a mean-reverting spread tail, not an outright
forecast for either metal.

## Markets And Timeframe

- Logical symbol: `QM5_20060_XCU_XAG_RSPREAD_D1`.
- Host symbol: `XCUUSD.DWX`.
- Basket legs: `XCUUSD.DWX` and `XAGUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 5-10 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread metadata, ATR, broker time, and
  V5 framework state only. No paper data, asset-manager data, CME feed,
  macro CSV, futures curve, API, analyst forecast, alternative data, or ML
  model is consumed at runtime.

## Rules

The mechanical rule set is fully specified below: D1 host-chart gating,
completed-close return-spread construction, rolling z-score entry, paired
basket orders, ATR hard stops, spread caps, normalization exit, max-hold exit,
and broken-package repair.

## Entry Rules

- Evaluate only on a new D1 bar of the `XCUUSD.DWX` host chart.
- Copy completed D1 closes for `XCUUSD.DWX` and `XAGUSD.DWX`.
- Compute `xcu_ret = ln(XCU close[1] / XCU close[1 + strategy_return_lookback_d1])`.
- Compute `xag_ret = ln(XAG close[1] / XAG close[1 + strategy_return_lookback_d1])`.
- Compute `return_spread = xcu_ret - strategy_beta_xag * xag_ret`.
- Standardize the latest completed return spread against the prior
  `strategy_z_lookback_d1` completed return spreads.
- Short spread: if z-score is above `strategy_entry_z`, sell `XCUUSD.DWX` and
  buy `XAGUSD.DWX`.
- Long spread: if z-score is below `-strategy_entry_z`, buy `XCUUSD.DWX` and
  sell `XAGUSD.DWX`.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(`strategy_atr_period_d1`)
  times `strategy_atr_sl_mult` from entry.
- Exit both legs when absolute spread z-score falls below `strategy_exit_z`.
- Exit both legs after `strategy_max_hold_days`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Only run from the `XCUUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Skip entries when `XCUUSD.DWX` spread exceeds `strategy_xcu_max_spread_pts`.
- Skip entries when `XAGUSD.DWX` spread exceeds `strategy_xag_max_spread_pts`.
- Skip entries when either close series or either ATR series is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open two-leg package at a time.
- Package integrity repair is deterministic: if one leg is missing, close the
  remaining leg.

## Parameters To Test

- name: strategy_return_lookback_d1
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta_xag
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00]
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
- name: strategy_xcu_max_spread_pts
  default: 1200
  sweep_range: [800, 1200, 1800]
- name: strategy_xag_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The source packet establishes structural lineage for copper/silver as an
industrial-growth versus defensive-metal relative signal only. This card
imports no source performance number. Q02 and later phases must validate or
reject the `XCUUSD.DWX` / `XAGUSD.DWX` basket on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.05.
- expected_dd_pct: 24.
- expected_trade_frequency: approximately 5-10 paired packages/year.
- risk_class: medium-high because copper history/fills, silver hedge behavior,
  and synchronized basket execution need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed metal-ratio paper plus SSGA and CME
  market references; exact XCU/XAG rule is explicitly a transfer hypothesis.
- [x] R2 mechanical: fixed D1 return spread, rolling z-score entry/exit, ATR
  hard stops, spread caps, max-hold exit, and broken-package repair.
- [x] R3 testable: `XAGUSD.DWX` is widely registered in V5 and existing XCU
  EAs build against `XCUUSD.DWX`; Q02 must validate synchronized XCU/XAG
  history and fills.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Non-duplicate: paired copper/silver return-spread mean reversion, not solo
  copper trend/reversal, copper/AUDUSD, oil/copper, oil/gold, gas/gold,
  gold/silver, XNG, index, or commodity-RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Registry And Queue Notes

- Slot 0: `XCUUSD.DWX`.
- Slot 1: `XAGUSD.DWX`.
- Use the logical basket setfile `QM5_20060_XCU_XAG_RSPREAD_D1` for Q02.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps, news,
  Friday close, and valid data checks.
- trade_entry: D1 standardized XCU/XAG return-spread reversion.
- trade_management: broken-package repair and max-hold tracking.
- trade_close: z-score mean exit, max-hold exit, Friday close, and ATR hard
  stops.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce at least one valid logical-basket
trade, if Q02 PF is below 1.0 after costs, if synchronized XCU/XAG history is
insufficient, or if the basket preflight cannot execute both legs under the V5
one-position-per-magic model.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-23 | initial XCU/XAG return-spread basket card | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-23 | APPROVED | this card |
| Q01 Build Validation | 2026-07-23 | PENDING | `artifacts/qm5_20060_build_result.json` |
| Q02 Baseline Screening | 2026-07-23 | PENDING | `artifacts/qm5_20060_q02_enqueue_20260723.json` |
