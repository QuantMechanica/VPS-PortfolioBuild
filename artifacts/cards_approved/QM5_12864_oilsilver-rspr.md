---
ea_id: QM5_12864
slug: oilsilver-rspr
type: strategy
strategy_id: MACROTRENDS-SILVER-OIL-RATIO-2026_S03
source_id: MACROTRENDS-SILVER-OIL-RATIO-2026
source_citation: "Macrotrends. Silver to Oil Ratio - Historical Chart. URL https://www.macrotrends.net/2612/silver-to-oil-ratio-historical-chart; Chan, Ernest P. Algorithmic Trading, Wiley, 2013, pair-spread mean-reversion template."
source_citations:
  - type: market_data_reference
    citation: "Macrotrends. Silver to Oil Ratio - Historical Chart."
    location: "https://www.macrotrends.net/2612/silver-to-oil-ratio-historical-chart"
    quality_tier: B
    role: primary
  - type: book
    citation: "Chan, Ernest P. Algorithmic Trading: Winning Strategies and Their Rationale. Wiley, 2013."
    location: "Pair-spread mean-reversion template lineage."
    quality_tier: A
    role: implementation_template
sources:
  - "[[sources/MACROTRENDS-SILVER-OIL-RATIO-2026]]"
concepts:
  - "[[concepts/oil-silver-ratio]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/return-spread-zscore]]"
indicators:
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, oil-silver-relative-value, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XAGUSD.DWX]
markets: [XTIUSD.DWX, XAGUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12864_XTI_XAG_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "Low-frequency D1 XTI/XAG return-spread z-score reversion; estimate 6-14 paired packages/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS existing approved oil/silver ratio source packet plus Chan/Wiley pair-spread implementation lineage; R2 PASS deterministic D1 oil-minus-silver return-spread z-score entry, mean exit, max-hold exit, spread caps, and ATR hard stops; R3 PASS XTIUSD.DWX and XAGUSD.DWX are in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# Oil/Silver Return-Spread Reversion

## Source

- Source: [[sources/MACROTRENDS-SILVER-OIL-RATIO-2026]]
- Primary citation: Macrotrends, "Silver to Oil Ratio - Historical Chart", URL
  https://www.macrotrends.net/2612/silver-to-oil-ratio-historical-chart.
- Implementation lineage: Chan, Ernest P. (2013), *Algorithmic Trading:
  Winning Strategies and Their Rationale*, Wiley, pair-spread mean reversion.

## Concept

The silver/oil ratio links crude oil to an industrial and monetary metal rather
than expressing either market as a standalone direction call. This card keeps
that exposure market-neutral, but deliberately avoids another absolute
oil/silver price-ratio sleeve. It measures short fixed-window relative return
divergence:

`return_spread = ln(XTI_t / XTI_t-N) - beta * ln(XAG_t / XAG_t-N)`

The current return spread is standardized against recent completed-D1 history.
If WTI has overrun silver over the return window, the basket sells WTI and buys
silver. If silver has overrun WTI, the basket buys WTI and sells silver. The
thesis is short-horizon relative-return snapback inside a structural
oil/silver pair, not outright WTI trend and not outright metal exposure.

This is deliberately different from:

- `QM5_12606_oil-silver-ratio`: that EA fades the absolute XTI/XAG log price
  ratio level. This card fades a short-window return-spread shock.
- `QM5_12797_oil-silver-brk`: that EA follows oil/silver ratio breakouts. This
  card is contrarian after return-spread dislocation.
- `QM5_12863_oilgold-rspread`: that card trades oil versus gold. This card
  trades oil versus silver, adding a different hedge leg with industrial-metal
  behavior.
- `QM5_12862_xauxag-rspread`: that card is intra-metals. This card introduces
  energy versus silver relative value.
- Directional WTI, XNG, XAU, index, calendar, inventory, roll, and
  `QM5_12567_cum-rsi2-commodity` sleeves: every entry is a paired package and
  uses no RSI, oscillator pullback, ML, grid, martingale, or external feed.

## Markets And Timeframe

- Logical symbol: `QM5_12864_XTI_XAG_RSPREAD_D1`.
- Host symbol: `XTIUSD.DWX`.
- Second leg: `XAGUSD.DWX`.
- Period: D1.
- Expected package frequency: about 6-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No Macrotrends feed, futures curve, CFTC data,
  inventory data, CSV, API, analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new D1 host bar after both completed D1 close series are
  available.
- Compute the latest `strategy_return_lookback_d1` D1 log return for
  `XTIUSD.DWX` and `XAGUSD.DWX`.
- Compute `return_spread = return_XTI - beta * return_XAG`.
- Standardize the return spread using the last `strategy_z_lookback_d1`
  completed return-spread observations.
- If z-score is above `strategy_entry_z`, WTI has outperformed silver sharply:
  sell `XTIUSD.DWX` and buy `XAGUSD.DWX`.
- If z-score is below negative `strategy_entry_z`, silver has outperformed WTI
  sharply: buy `XTIUSD.DWX` and sell `XAGUSD.DWX`.
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

- Only trade from an `XTIUSD.DWX` D1 host chart.
- Magic slot offset must be 0 on the host.
- Skip entries when either D1 history series, ATR, spread, or symbol metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Two-leg basket only.
- Symmetric long/short oil/silver relative-value package.
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
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xag_max_spread_pts
  default: 200
  sweep_range: [100, 200, 350]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The Macrotrends source establishes the oil/silver relative-value lens. The Chan
source supplies the generic mechanical pair-spread mean-reversion template.
This card imports no performance claim. Q02 and later phases must validate or
reject the mechanical rule on Darwinex `XTIUSD.DWX` and `XAGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: high because WTI gaps, silver volatility, and basket execution
  quality all need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: existing approved oil/silver ratio source packet plus
  Chan/Wiley pair-spread implementation lineage.
- [x] R2 mechanical: fixed D1 return-spread z-score entry, normalization exit,
  time stop, spread caps, and ATR hard stops.
- [x] R3 testable: `XTIUSD.DWX` and `XAGUSD.DWX` exist in the DWX symbol
  universe and require OHLC only.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one package per magic.
- [x] Non-duplicate: this is XTI/XAG return-spread reversion, not XTI/XAG
  price-ratio level reversion, oil/silver ratio breakout, oil/gold
  return-spread, XAU/XAG return-spread, commodity RSI, or directional
  oil/silver exposure.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, return-spread data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XTI/XAG return-spread reversion.
- trade_management: z-score mean exit, max-hold stale-package exit, orphan leg
  cleanup, and Friday close.
- trade_close: hard ATR stop plus deterministic package close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial XTI/XAG return-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12864_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `87d3c700-5eda-401f-b8dd-ff023e6e710f` |
