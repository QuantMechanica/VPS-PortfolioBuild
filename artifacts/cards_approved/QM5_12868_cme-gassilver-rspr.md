---
ea_id: QM5_12868
slug: cme-gassilver-rspr
type: strategy
strategy_id: CME-GAS-SILVER-RELVAL-2026_S03
source_id: CME-GAS-SILVER-RELVAL-2026
source_citation: "CME Group. Henry Hub Natural Gas Futures Overview. URL https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html; CME Group. Silver Futures Overview. URL https://www.cmegroup.com/markets/metals/precious/silver.html"
source_citations:
  - type: exchange_product_source
    citation: "CME Group Henry Hub Natural Gas and Silver futures product overview source packet."
    location: "strategy-seeds/sources/CME-GAS-SILVER-RELVAL-2026/source.md"
    quality_tier: A
    role: primary
sources:
  - "[[sources/CME-GAS-SILVER-RELVAL-2026]]"
concepts:
  - "[[concepts/natural-gas-silver-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/return-spread-zscore]]"
indicators:
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, natural-gas-silver-relative-value, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX, XAGUSD.DWX]
markets: [XNGUSD.DWX, XAGUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12868_XNG_XAG_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "Low-frequency D1 XNG/XAG return-spread z-score reversion; estimate 6-14 paired packages/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 24.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, xng_volatility, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS single CME gas/silver exchange-product source packet; R2 PASS deterministic D1 natural-gas-minus-silver return-spread z-score entry, mean exit, max-hold exit, spread caps, and ATR hard stops; R3 PASS XNGUSD.DWX and XAGUSD.DWX are in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# Natural Gas/Silver Return-Spread Reversion

## Source

- Source: [[sources/CME-GAS-SILVER-RELVAL-2026]]
- Primary citations: CME Group Henry Hub Natural Gas futures overview and CME
  Group Silver futures overview.

## Concept

CME lists Henry Hub Natural Gas and Silver as separate exchange-traded
commodity markets. This card uses that single CME source packet only for
structural lineage, then tests a Darwinex-native relative-value basket on
`XNGUSD.DWX` and `XAGUSD.DWX`.

The signal deliberately avoids another absolute natural gas/silver ratio level
or breakout. It measures short fixed-window relative return divergence:

`return_spread = ln(XNG_t / XNG_t-N) - beta * ln(XAG_t / XAG_t-N)`

The current return spread is standardized against recent completed-D1 history.
If natural gas has overrun silver over the return window, the basket sells
natural gas and buys silver. If silver has overrun natural gas, the basket buys
natural gas and sells silver. The thesis is short-horizon relative-return
snapback inside an energy/industrial-metal pair, not outright XNG direction and
not an outright silver sleeve.

This is deliberately different from:

- `QM5_12826_cme-gassilver-ratio`: that EA fades the absolute XNG/XAG log price
  ratio level. This card fades a short-window return-spread shock.
- `QM5_12827_cme-gassilver-brk`: that EA follows natural gas/silver ratio
  breakouts. This card is contrarian after return-spread dislocation.
- `QM5_12824_cme-gasgold-ratio`: that card trades natural gas versus gold. This
  card trades natural gas versus silver, adding a more industrial metal hedge.
- `QM5_12850_xti-xng-vcb`, `QM5_12840_xti-xng-rspread`, and XNG single-leg
  seasonal/weather/event sleeves: this card has no WTI leg and no single-leg
  XNG entry.
- `QM5_12567_cum-rsi2-commodity`: every entry is a paired package and uses no
  RSI, oscillator pullback, ML, grid, martingale, or adaptive online parameter
  logic.
- Index, XAU, directional XAG, WTI/Brent, and XAU/XAG sleeves: this is an
  energy/silver relative-return package.

## Markets And Timeframe

- Logical symbol: `QM5_12868_XNG_XAG_RSPREAD_D1`.
- Host symbol: `XNGUSD.DWX`.
- Second leg: `XAGUSD.DWX`.
- Period: D1.
- Expected package frequency: about 6-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No CME feed, futures curve, storage feed, weather feed,
  CFTC data, CSV, API, analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new D1 host bar after both completed D1 close series are
  available.
- Compute the latest `strategy_return_lookback_d1` D1 log return for
  `XNGUSD.DWX` and `XAGUSD.DWX`.
- Compute `return_spread = return_XNG - beta * return_XAG`.
- Standardize the return spread using the last `strategy_z_lookback_d1`
  completed return-spread observations.
- If z-score is above `strategy_entry_z`, natural gas has outperformed silver
  sharply: sell `XNGUSD.DWX` and buy `XAGUSD.DWX`.
- If z-score is below negative `strategy_entry_z`, silver has outperformed
  natural gas sharply: buy `XNGUSD.DWX` and sell `XAGUSD.DWX`.
- No entry if either leg has an open position for this EA magic.
- No entry if either leg exceeds its spread cap.

## Exit Rules

- Close both legs when absolute return-spread z-score falls below
  `strategy_exit_z`.
- Close both legs after `strategy_max_hold_days` calendar days.
- Close both legs through the V5 Friday-close hook.
- If only one leg remains open, immediately flatten the orphaned leg.
- Per-leg hard stop: ATR(`strategy_atr_period_d1`) *
  `strategy_atr_sl_mult`.

## Filters

- Only trade from an `XNGUSD.DWX` D1 host chart.
- Magic slot offset must be 0 on the host.
- Skip entries when either D1 history series, ATR, spread, or symbol metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Two-leg basket only.
- Symmetric long/short natural gas/silver relative-value package.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_return_lookback_d1
  default: 10
  sweep_range: [5, 10, 20]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.7, 2.0, 2.3]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.25, 0.4, 0.6]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 3500]
- name: strategy_xag_max_spread_pts
  default: 200
  sweep_range: [100, 200, 350]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The CME source packet establishes exchange-traded natural gas and silver market
lineage. This card imports no source performance claim. Q02 and later phases
must validate or reject the mechanical rule on Darwinex `XNGUSD.DWX` and
`XAGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 24.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: high because natural-gas gaps, silver volatility, and basket
  execution quality all need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single CME exchange product source packet for Henry
  Hub Natural Gas and Silver futures.
- [x] R2 mechanical: fixed D1 return-spread z-score entry, normalization exit,
  time stop, spread caps, and ATR hard stops.
- [x] R3 testable: `XNGUSD.DWX` and `XAGUSD.DWX` exist in the DWX symbol
  universe and require OHLC only.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one package per magic.
- [x] Non-duplicate: this is XNG/XAG return-spread reversion, not XNG/XAG
  price-ratio level reversion, XNG/XAG ratio breakout, XNG/XAU ratio
  reversion, XTI/XNG relative value, XNG single-leg event/calendar logic,
  XAU/XAG return-spread, commodity RSI, or directional metal/index exposure.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, return-spread data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XNG/XAG return-spread reversion.
- trade_management: z-score mean exit, max-hold stale-package exit, orphan leg
  cleanup, and Friday close.
- trade_close: hard ATR stop plus deterministic package close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial XNG/XAG return-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PASS | `artifacts/qm5_12868_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | QUEUED | work item `377ea635-89ee-4398-abfc-b3e2df0d5d90` |
