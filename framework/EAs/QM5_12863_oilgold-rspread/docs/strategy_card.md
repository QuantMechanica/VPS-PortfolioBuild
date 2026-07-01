---
ea_id: QM5_12862
slug: xauxag-rspread
type: strategy
strategy_id: CME-XAUXAG-RSPREAD-2026
source_id: CME-XAUXAG-RSPREAD-2026
source_citation: "CME Group Gold & Silver Ratio Spread lesson; CME Group Spread Trading Opportunities with Precious Metals; Chan, Ernest P. Algorithmic Trading, Wiley, 2013, pair-spread mean-reversion template."
source_citations:
  - type: exchange_education
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade"
    quality_tier: A
    role: primary
  - type: exchange_education
    citation: "CME Group. Spread Trading Opportunities with Precious Metals."
    location: "https://www.cmegroup.com/education/articles-and-reports/spread-trading-opportunities-with-precious-metals"
    quality_tier: A
    role: structural_context
  - type: book
    citation: "Chan, Ernest P. Algorithmic Trading: Winning Strategies and Their Rationale. Wiley, 2013."
    location: "Pair-spread mean-reversion template lineage."
    quality_tier: A
    role: implementation_template
sources:
  - "[[sources/CME-XAUXAG-RSPREAD-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/pair-spread-mean-reversion]]"
  - "[[concepts/return-spread-zscore]]"
indicators:
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, precious-metals-relative-value, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [XAUUSD.DWX, XAGUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12862_XAU_XAG_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "Low-frequency D1 XAU/XAG return-spread z-score reversion; estimate 6-14 paired packages/year before Q02 validates history and fills."
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
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS official CME gold/silver ratio and precious-metals spread references plus Chan/Wiley pair-spread implementation lineage; R2 PASS deterministic D1 return-spread z-score entry, mean exit, max-hold exit, spread caps, and ATR hard stops; R3 PASS XAUUSD.DWX and XAGUSD.DWX are in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XAU/XAG Return-Spread Reversion

## Source

- Primary reference: CME Group, "Gold & Silver Ratio Spread".
- Structural context: CME Group, "Spread Trading Opportunities with Precious
  Metals".
- Implementation lineage: Chan, Ernest P. (2013), *Algorithmic Trading:
  Winning Strategies and Their Rationale*, Wiley, pair-spread mean reversion.

## Concept

CME documents gold/silver as a traded relative-value spread. This card keeps
that exposure market-neutral, but deliberately avoids another absolute
gold/silver price-ratio sleeve. Instead it measures short fixed-window relative
return divergence:

`return_spread = ln(XAU_t / XAU_t-N) - beta * ln(XAG_t / XAG_t-N)`

The current return spread is standardized against recent completed-D1 history.
If gold has overrun silver over the return window, the basket sells gold and
buys silver. If silver has overrun gold, the basket buys gold and sells silver.
The hypothesis is short-horizon relative-return snapback inside a structural
metals pair, not outright gold direction.

This is deliberately different from:

- `QM5_12577_cme-xauxag-ratio`: that EA fades the absolute XAU/XAG log price
  ratio level. This card fades a short-window return-spread shock.
- `QM5_12724_cme-xauxag-brk`: that EA follows ratio breakouts. This card is
  contrarian after return-spread dislocation.
- Directional XAU/XAG trend, seasonal, ORB, or pullback sleeves: every entry is
  a paired package with both metal legs.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, ML, grid,
  martingale, or adaptive online parameter logic is used.
- Index, WTI, XNG, and XTI/XNG sleeves: this is a precious-metals relative-value
  package and should be evaluated as a logical basket, not two standalone legs.

## Markets And Timeframe

- Logical symbol: `QM5_12862_XAU_XAG_RSPREAD_D1`.
- Host symbol: `XAUUSD.DWX`.
- Second leg: `XAGUSD.DWX`.
- Period: D1.
- Expected package frequency: about 6-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No CME feed, futures curve, CFTC data, CSV, API,
  analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new D1 host bar after both completed D1 close series are
  available.
- Compute the latest `strategy_return_lookback_d1` D1 log return for
  `XAUUSD.DWX` and `XAGUSD.DWX`.
- Compute `return_spread = return_XAU - beta * return_XAG`.
- Standardize the return spread using the last `strategy_z_lookback_d1`
  completed return-spread observations.
- If z-score is above `strategy_entry_z`, gold has outperformed silver sharply:
  sell `XAUUSD.DWX` and buy `XAGUSD.DWX`.
- If z-score is below negative `strategy_entry_z`, silver has outperformed gold
  sharply: buy `XAUUSD.DWX` and sell `XAGUSD.DWX`.
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

- Only trade from an `XAUUSD.DWX` D1 host chart.
- Magic slot offset must be 0 on the host.
- Skip entries when either D1 history series, ATR, spread, or symbol metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Two-leg basket only.
- Symmetric long/short precious-metals relative-value package.
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
  default: 2.5
  sweep_range: [2.0, 2.5, 3.5]
- name: strategy_max_hold_days
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_xau_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_xag_max_spread_pts
  default: 200
  sweep_range: [100, 200, 400]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The CME sources establish gold/silver as a standard relative-value spread and
precious-metals spread context. The Chan source supplies the generic mechanical
pair-spread mean-reversion template. This card imports no performance claim.
Q02 and later phases must validate or reject the mechanical rule on Darwinex
`XAUUSD.DWX` and `XAGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: medium-high because metal leg volatility and basket execution
  quality both need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CME gold/silver ratio and precious-metals
  spread references plus Chan/Wiley pair-spread implementation lineage.
- [x] R2 mechanical: fixed D1 return-spread z-score entry, normalization exit,
  time stop, spread caps, and ATR hard stops.
- [x] R3 testable: `XAUUSD.DWX` and `XAGUSD.DWX` exist in the DWX symbol
  universe and require OHLC only.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one package per magic.
- [x] Non-duplicate: this is XAU/XAG return-spread reversion, not XAU/XAG
  price-ratio level reversion, XAU/XAG ratio breakout, commodity RSI, or
  directional metal exposure.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, return-spread data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XAU/XAG return-spread reversion.
- trade_management: z-score mean exit, max-hold stale-package exit, orphan leg
  cleanup, and Friday close.
- trade_close: hard ATR stop plus deterministic package close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial XAU/XAG return-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12862_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `350833a1-7065-48c7-8acb-df836d718667` |
