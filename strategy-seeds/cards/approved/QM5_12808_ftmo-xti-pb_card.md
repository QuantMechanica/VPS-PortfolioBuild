---
ea_id: QM5_12808
slug: ftmo-xti-pb
type: strategy
strategy_id: FTMO-MAR2026-XTI-PORTFOLIO_S01
source_id: FTMO-MAR2026-XTI-PORTFOLIO
source_citation: "Local QM inventory of OWNER FTMO March 2026 portfolio package: docs/research/dropbox/existing_ea_inventory.md, row FTMO_XTIUSD_Portfolio_v1."
source_citations:
  - type: local_inventory
    citation: "Existing EA Code Inventory - OWNER's Dropbox, FTMO March 2026/EAs row 11: FTMO_XTIUSD_Portfolio_v1."
    location: "docs/research/dropbox/existing_ea_inventory.md"
    quality_tier: B
    role: primary
sources:
  - "[[sources/FTMO-MAR2026-XTI-PORTFOLIO]]"
concepts:
  - "[[concepts/wti-trend-pullback]]"
  - "[[concepts/energy-trend-continuation]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trend-pullback, multi-timeframe-filter, atr-hard-stop, signal-reversal-exit, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [H4]
single_symbol_only: true
period: H4
expected_trade_frequency: "D1/H4 WTI trend-pullback package; estimate 8-24 entries/year after D1 regime, H4 reclaim, spread, and framework filters."
expected_trades_per_year_per_symbol: 16
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single local code-first FTMO March 2026 XTIUSD package lineage; R2 PASS deterministic D1 EMA regime plus H4 EMA pullback/reclaim, ATR stop, trend invalidation, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
---

# FTMO XTI Trend Pullback

## hypothesis

WTI crude oil trends can persist when the higher-timeframe regime is aligned,
but cleaner entries may come after a pullback into the H4 moving-average zone
and a reclaim in the D1 trend direction. This creates energy exposure that is
not another XAU, SP500, NDX, or XNG sleeve.

## rules

- Trade only `XTIUSD.DWX` on H4.
- Long regime: prior completed D1 close is above EMA(50), EMA(50) is above
  EMA(200), and EMA(50) is rising over the configured slope lookback.
- Short regime: prior completed D1 close is below EMA(50), EMA(50) is below
  EMA(200), and EMA(50) is falling over the configured slope lookback.
- Long entry: under the long regime, the prior completed H4 bar trades down to
  or through EMA(50), then closes back above EMA(21) with a bullish candle.
- Short entry: under the short regime, the prior completed H4 bar trades up to
  or through EMA(50), then closes back below EMA(21) with a bearish candle.
- Stop loss is ATR(H4) times the configured multiplier, frozen at entry.
- Exit when the H4 close crosses back through EMA(50) against the position, the
  D1 regime invalidates, or the max-hold bar count expires.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and a single
`XTIUSD.DWX` H4 setfile. Live risk is intentionally unset; any future live
allocation must come from the portfolio process. This build does not touch
`T_Live`, AutoTrading, deploy manifests, or portfolio admission gates.

## Source

- Source: [[sources/FTMO-MAR2026-XTI-PORTFOLIO]]
- Primary citation: local inventory row for `FTMO_XTIUSD_Portfolio_v1` in
  `docs/research/dropbox/existing_ea_inventory.md`.

## Concept

The FTMO March 2026 inventory identifies a non-ML XTIUSD portfolio package whose
active components include TrendPullback and ParSAR on D1/H4/H1. This card
mechanizes only the trend-pullback component because it is structural, OHLC-only,
and low-frequency enough for the QM portfolio funnel.

This is deliberately different from existing WTI month, weekday, weekend-gap,
EIA/WPSR, OPEC, hurricane, refinery, roll, 52-week-anchor, TSMOM, Pro-Go,
Abraham breakout-pullback, range-expansion, CAD/oil, XTI/XNG, oil/gold,
oil/silver, and commodity-RSI sleeves.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: H4.
- Expected trade frequency: about 8-24 trades/year.
- Runtime data: Darwinex MT5 OHLC and ATR/EMA readers only. No futures curve,
  inventory feed, news feed, external CSV, API, or adaptive model.

## Entry Rules

- Evaluate only on a fresh H4 bar.
- Long if D1 trend is bullish and the prior H4 bar touched EMA(50), closed above
  EMA(21), closed bullish, and spread is below the cap.
- Short if D1 trend is bearish and the prior H4 bar touched EMA(50), closed
  below EMA(21), closed bearish, and spread is below the cap.
- No entry if this EA already has an open `XTIUSD.DWX` position.

## Exit Rules

- ATR hard stop at entry.
- Long trend invalidation: close if H4 closes below EMA(50) or D1 regime is no
  longer bullish.
- Short trend invalidation: close if H4 closes above EMA(50) or D1 regime is no
  longer bearish.
- Time exit after `strategy_max_hold_bars` H4 bars.
- Friday close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_d1_fast_ema
  default: 50
  sweep_range: [34, 50, 89]
- name: strategy_d1_slow_ema
  default: 200
  sweep_range: [150, 200, 252]
- name: strategy_h4_trigger_ema
  default: 21
  sweep_range: [13, 21, 34]
- name: strategy_h4_pullback_ema
  default: 50
  sweep_range: [34, 50, 89]
- name: strategy_slope_lookback_d1
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.8
  sweep_range: [2.0, 2.8, 3.5]
- name: strategy_max_hold_bars
  default: 36
  sweep_range: [24, 36, 48]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Strategy Allowability Check

- [x] R1 reputable source: one local code-first source ID from the prior QM
  Dropbox inventory.
- [x] R2 mechanical: fixed D1 EMA regime, fixed H4 EMA pullback/reclaim trigger,
  ATR stop, trend invalidation, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: source-specific FTMO XTI trend-pullback, not existing WTI
  calendar/event/ratio/TSMOM/RSI/pro-go/range-expansion mechanics.

## Framework Alignment

- no_trade: H4 `XTIUSD.DWX` guard, slot guard, parameter guard, warmup, spread cap.
- trade_entry: D1 trend filter and H4 pullback/reclaim trigger.
- trade_management: trend invalidation and max-hold close.
- trade_close: ATR hard stop plus deterministic trend/time exits.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-29 | QUEUED | pending work item |
