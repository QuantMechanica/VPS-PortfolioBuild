---
ea_id: QM5_13002
slug: xng-cad-rspread
type: strategy
strategy_id: EIA-CANADA-GAS-TRADE-2025_S01
source_id: EIA-CANADA-GAS-TRADE-2025
source_citation: "U.S. Energy Information Administration, Last year's U.S.-Canada energy trade was valued around $150 billion, Today in Energy, 2025-07-30, updated 2025-08-04, https://www.eia.gov/todayinenergy/detail.php?id=65825"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Last year's U.S.-Canada energy trade was valued around $150 billion. Today in Energy, 2025-07-30; updated 2025-08-04."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=65825"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-CANADA-GAS-TRADE-2025]]"
concepts:
  - "[[concepts/natural-gas-trade-linkage]]"
  - "[[concepts/cad-commodity-fx-channel]]"
  - "[[concepts/pair-spread-mean-reversion]]"
indicators:
  - "[[indicators/log-spread-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, zscore-band-reversion, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX, USDCAD.DWX]
primary_target_symbols: [XNGUSD.DWX, USDCAD.DWX]
markets: [XNGUSD.DWX, USDCAD.DWX]
timeframes: [D1]
logical_symbol: QM5_13002_XNG_CAD_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 XNG/CAD log-spread z-score reversion; estimate 6-14 paired packages/year after z-score, spread, max-hold, and ATR filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official EIA Canada/U.S. energy-trade source; R2 PASS deterministic D1 XNG/USDCAD log-spread z-score entries, mean exit, max-hold exit, spread caps, and ATR stops; R3 PASS XNGUSD.DWX and USDCAD.DWX available; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate versus existing book because this is a gas/CAD two-leg relative-value basket, not XNG RSI/storage/seasonality/weather/expiry/rig-count, gas-metal, oil-gas, XTI-CAD, XAU/XAG, or index logic."
---

# XNG/CAD Natural-Gas Trade Relative Spread

## Source

- Source: [[sources/EIA-CANADA-GAS-TRADE-2025]]
- Primary citation: U.S. Energy Information Administration, "Last year's
  U.S.-Canada energy trade was valued around $150 billion", Today in Energy,
  2025-07-30, updated 2025-08-04.

## Concept

EIA describes the U.S.-Canada energy trade channel and the material cross-border
natural-gas pipeline flow between the two countries. This card turns that
structural channel into a Darwinex-native relative-value basket: a D1
CAD-denominated natural-gas spread between `XNGUSD.DWX` and `USDCAD.DWX`.

The signal is:

`spread = ln(XNGUSD.DWX close) + beta * ln(USDCAD.DWX close)`

A rich spread sells both legs; a cheap spread buys both legs. The source is used
only for structural lineage, not for any performance claim.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon commodity pullback.
- XNG storage, seasonality, weather, expiry, weekend, month-ORB, rig-count,
  52-week, 6-month, and carry sleeves: this is a two-leg gas/CAD spread.
- Gas/gold, gas/silver, oil/gas, XBR/XNG, and XTI/XNG baskets: the hedge leg is
  `USDCAD.DWX`, not another commodity.
- WTI/CAD sleeves: this trades natural gas, not WTI crude.
- XAU/XAG and index book sleeves: no metal or index leg is traded.

## Markets And Timeframe

- Logical symbol: `QM5_13002_XNG_CAD_RSPREAD_D1`.
- Host symbol: `XNGUSD.DWX`.
- Basket legs: `XNGUSD.DWX` and `USDCAD.DWX`.
- Period: `D1`.
- Expected package frequency: about 6-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, trade-volume feed, tariff
  feed, futures curve, API, CSV, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar of the `XNGUSD.DWX` host chart.
- Copy recent closed D1 closes for both basket legs.
- Compute `spread = ln(XNGUSD.DWX) + beta * ln(USDCAD.DWX)`.
- Standardize the current spread into a z-score using
  `strategy_z_lookback_d1`.
- If z-score is greater than `strategy_entry_z`, short the spread: sell
  `XNGUSD.DWX` and sell `USDCAD.DWX`.
- If z-score is less than negative `strategy_entry_z`, long the spread: buy
  `XNGUSD.DWX` and buy `USDCAD.DWX`.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit Rules

- Exit both legs when the open spread direction reverts into the
  `strategy_exit_z` band.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Filters

- Only run from the `XNGUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Require positive prices, valid spread standard deviation, valid ATR, valid lot
  sizing, and allowed spreads for both legs.
- Framework kill-switch, symbol guard, magic resolver, news, and Friday-close
  controls remain active.

## Trade Management Rules

- Two-leg relative-value basket.
- Symmetric long/short spread.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 90
  sweep_range: [60, 90, 120, 140]
- name: strategy_beta
  default: 4.0
  sweep_range: [2.0, 4.0, 6.0, 8.0]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.6, 2.0, 2.4]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.2, 0.5, 0.8]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [25, 45, 60]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 3500]
- name: strategy_usdcad_max_spread_pts
  default: 80
  sweep_range: [50, 80, 120]

## Author Claims

EIA is used for structural lineage only: U.S.-Canada natural-gas trade is a
material pipeline-linked energy channel. This card imports no performance claim
for `XNGUSD.DWX`/`USDCAD.DWX`; the actual edge must be proven or rejected by
the V5 Q02 pipeline.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: medium-high because natural gas can gap and the CAD hedge is
  imperfect.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA source packet
  `EIA-CANADA-GAS-TRADE-2025`.
- [x] R2 mechanical: fixed D1 log-spread z-score entry, mean exit, max-hold
  exit, spread caps, and ATR hard stops.
- [x] R3 testable: `XNGUSD.DWX` and `USDCAD.DWX` exist in the DWX symbol
  universe and require OHLC only.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and no pyramiding.
- [x] Non-duplicate: not XNG RSI, storage, seasonality, weather, expiry,
  rig-count, commodity-metal, oil/gas, XTI/CAD, XAU/XAG, or index logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, spread data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XNG/CAD log-spread mean reversion.
- trade_management: no trailing or partial management in v1.
- trade_close: z-score mean exit, max-hold stale-package exit, orphan leg
  cleanup, Friday close, and hard ATR stops.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-03 | initial XNG/CAD relative-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_13002_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED `57c71a00` | `D:\QM\strategy_farm\state\farm_state.sqlite` |
