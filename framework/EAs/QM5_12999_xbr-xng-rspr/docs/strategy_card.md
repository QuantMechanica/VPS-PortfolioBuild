---
ea_id: QM5_12840
slug: xti-xng-rspread
type: strategy
strategy_id: SRC05_S01_XTI_XNG_RSPREAD_2026
source_id: SRC05
source_citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley. Chapter 3, Example 3.2 pair-spread Bollinger-style mean reversion; local source packet strategy-seeds/sources/SRC05/."
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley."
    location: "Chapter 3, Example 3.2 pair-spread Bollinger-style mean reversion; strategy-seeds/sources/SRC05/"
    quality_tier: A
    role: primary
sources:
  - "[[sources/SRC05]]"
concepts:
  - "[[concepts/pair-spread-mean-reversion]]"
  - "[[concepts/energy-return-spread]]"
indicators:
  - "[[indicators/return-spread-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, zscore-band-reversion, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [XTIUSD.DWX, XNGUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12840_XTI_XNG_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 XTI/XNG return-spread z-score reversion; estimate 8-16 paired packages/year after z-score, spread, max-hold, and ATR filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS reputable published strategy source packet; R2 PASS deterministic D1 two-leg return-spread z-score reversion with mean exit, max-hold exit, spread caps, and ATR hard stops; R3 PASS XTIUSD.DWX and XNGUSD.DWX available in V5/DWX OHLC; R4 PASS no ML/grid/martingale/external runtime data."
---

# XTI/XNG D1 Return-Spread Reversion

## Source

- Source: [[sources/SRC05]]
- Primary citation: Chan, Ernest P. (2013). *Algorithmic Trading: Winning
  Strategies and Their Rationale*. Wiley.
- Lineage: Chapter 3, Example 3.2 pair-spread Bollinger-style mean reversion.

## Concept

The approved source packet supplies the structural pattern: trade a two-leg
spread when the standardized spread moves far from its recent mean, then exit
after reversion. This card ports the idea to a D1 energy return spread between
WTI CFD proxy `XTIUSD.DWX` and natural-gas CFD proxy `XNGUSD.DWX`.

Instead of using an absolute log price ratio, the signal measures fixed-window
relative return divergence:

`return_spread = log(XTI[t] / XTI[t-L]) - beta * log(XNG[t] / XNG[t-L])`

The return-spread choice is deliberate. It avoids duplicating the existing
XTI/XNG log-price-level ratio reversion and tests whether temporary energy
return shocks mean-revert at a lower frequency.

This is deliberately different from:

- `QM5_12578_eia-oilgas-ratio`: price-level log-ratio z-score reversion.
- `QM5_12608_eia-oilgas-breakout`: price-level log-ratio channel breakout.
- `QM5_12733_xti-xng-xmom`: monthly cross-sectional momentum that owns the
  stronger leg and shorts the weaker leg.
- `QM5_12813_eia-energy-switch`: fixed seasonal switch between WTI and natural
  gas ownership windows.
- `QM5_12567_cum-rsi2-commodity`: generic RSI2 commodity pullback logic.
- Existing WTI/XNG expiry, post-roll, event, inventory, calendar, trend, and
  reversal sleeves: timing and signal construction differ.
- XAU/XAG baskets: this is an energy return-spread basket and does not add more
  metal exposure.

## Markets And Timeframe

- Logical symbol: `QM5_12840_XTI_XNG_RSPREAD_D1`.
- Host symbol: `XTIUSD.DWX`.
- Basket legs: `XTIUSD.DWX` and `XNGUSD.DWX`.
- Period: `D1`.
- Expected package frequency: about 8-16 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no futures curve, inventory feed, API,
  volume, analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar of the `XTIUSD.DWX` host chart.
- Copy recent closed D1 closes for both basket legs.
- Compute fixed-window returns for WTI and natural gas using
  `strategy_return_lookback_d1`.
- Compute the return spread for the latest closed bar and the recent
  `strategy_z_lookback_d1` history.
- Standardize the current return spread into a z-score using that history.
- If z-score is greater than `strategy_entry_z`, short the spread: sell WTI and
  buy natural gas.
- If z-score is less than negative `strategy_entry_z`, long the spread: buy WTI
  and sell natural gas.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit Rules

- Exit both legs when `abs(z-score) < strategy_exit_z`.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Filters

- Only run from the `XTIUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Require positive prices, valid return-spread standard deviation, valid ATR,
  valid lot sizing, and allowed spreads for both legs.
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
  sweep_range: [10, 20, 30, 40]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 160, 180]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.75, 1.0, 1.25]
- name: strategy_entry_z
  default: 1.8
  sweep_range: [1.5, 1.8, 2.1, 2.4]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.2, 0.4, 0.6, 0.8]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 25
  sweep_range: [15, 25, 35]

## Author Claims

The source is used for structural lineage only: a mechanical pair-spread
mean-reversion template. This card imports no performance claim for XTI/XNG.
The actual edge must be proven or rejected by the V5 Q02 pipeline.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 8-16 paired packages/year.
- risk_class: medium-high for energy spread volatility and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: published strategy source packet from `SRC05`.
- [x] R2 mechanical: fixed D1 return-spread z-score entry, mean exit,
  max-hold exit, spread caps, and ATR hard stops.
- [x] R3 testable: `XTIUSD.DWX` and `XNGUSD.DWX` exist in the DWX symbol
  universe and require OHLC only.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and no pyramiding.
- [x] Non-duplicate: this is return-spread reversion, not XTI/XNG price-ratio
  level reversion, price-ratio breakout, monthly cross-sectional momentum,
  fixed seasonal switch, WTI/XNG expiry/event/calendar logic, RSI pullback, or
  XAU/XAG metal exposure.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, return-spread data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XTI/XNG return-spread reversion.
- trade_management: z-score mean exit, max-hold stale-package exit, orphan leg
  cleanup, and Friday close.
- trade_close: hard ATR stop plus deterministic package close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial XTI/XNG return-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12840_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `bc623b84-ba53-4e54-964d-96932497bbd0` |
