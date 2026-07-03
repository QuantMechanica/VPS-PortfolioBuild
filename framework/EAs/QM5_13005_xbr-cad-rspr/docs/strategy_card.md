---
ea_id: QM5_13005
slug: xbr-cad-rspr
type: strategy
strategy_id: BOC-EIA-BRENT-CAD-RSPREAD-2026_S01
source_id: BOC-EIA-BRENT-CAD-RSPREAD-2026
source_citation: "Bank of Canada Staff Analytical Note 2017-1, The Share of Systematic Variations in the Canadian Dollar - Part II, 2017; U.S. EIA Today in Energy, Canada's crude oil has an increasingly significant role in U.S. refineries, 2024-08-01; Canada Energy Regulator Market Snapshot, Overview of Canada-U.S. Energy Trade, 2025."
source_citations:
  - type: central_bank_research
    citation: "Bank of Canada. The Share of Systematic Variations in the Canadian Dollar - Part II. Staff Analytical Note 2017-1, 2017."
    location: "https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/"
    quality_tier: A
    role: primary
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Canada's crude oil has an increasingly significant role in U.S. refineries. Today in Energy, 2024-08-01."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=62664"
    quality_tier: A
    role: supplement
  - type: government_energy_research
    citation: "Canada Energy Regulator. Market Snapshot: Overview of Canada-U.S. Energy Trade, 2025."
    location: "https://www.cer-rec.gc.ca/en/data-analysis/energy-markets/market-snapshots/2025/market-snapshot-overview-of-canada-us-energy-trade.html"
    quality_tier: A
    role: supplement
concepts:
  - "[[concepts/oil-cad-commodity-fx-channel]]"
  - "[[concepts/brent-relative-value]]"
  - "[[concepts/pair-spread-mean-reversion]]"
indicators:
  - "[[indicators/log-spread-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, zscore-band-reversion, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XBRUSD.DWX, USDCAD.DWX]
primary_target_symbols: [XBRUSD.DWX, USDCAD.DWX]
markets: [XBRUSD.DWX, USDCAD.DWX]
timeframes: [D1]
logical_symbol: QM5_13005_XBR_CAD_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 Brent/CAD log-spread z-score reversion; estimate 6-14 paired packages/year after z-score, spread, max-hold, and ATR filters."
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
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS Bank of Canada oil/CAD factor research plus official EIA/CER Canada crude trade sources; R2 PASS deterministic D1 XBR/USDCAD log-spread z-score entries, mean exit, max-hold exit, spread caps, and ATR stops; R3 PASS XBRUSD.DWX and USDCAD.DWX available in local V5 builds; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is Brent/CAD two-leg relative-value, not WTI/CAD, XNG/CAD, WTI event/calendar, oil-gas, oil-metal, XAU/XAG, XNG, or index logic."
---

# XBR/CAD Brent Oil Relative Spread

## Source

- Bank of Canada Staff Analytical Note 2017-1 documents an oil-linked currency
  factor and reports that the oil portfolio is correlated with Brent and WTI
  while the Canadian dollar has positive oil-portfolio sensitivity in the
  2011-2016 rolling window.
- EIA documents the scale of Canada crude oil in U.S. refinery supply, including
  Canada as 60% of U.S. crude imports in 2023.
- Canada Energy Regulator documents Canada-U.S. hydrocarbon trade, including
  crude oil as the largest hydrocarbon export category to the United States.

## Concept

The card converts the oil/CAD structural channel into a Darwinex-native,
low-frequency relative-value basket between Brent crude and `USDCAD.DWX`.
It does not import any external source data at runtime; the EA uses only MT5
closed-bar OHLC to compute a rolling log-spread z-score.

The signal is:

`spread = ln(XBRUSD.DWX close) + beta * ln(USDCAD.DWX close)`

A rich spread sells both legs; a cheap spread buys both legs. This sign choice
uses the usual oil-exporter FX intuition: stronger oil and stronger CAD both
push the spread in the same broad direction when expressed through USD/CAD.

This is deliberately different from:

- `QM5_13002_xng-cad-rspread`: trades Brent crude, not natural gas.
- `QM5_12609_wti-cad-spread-mr`, `QM5_12607_wti-cad-confirm`, and
  `QM5_12722_wti-cad-brk`: Brent/CAD relative spread, not WTI/CAD.
- WTI and Brent seasonality/event sleeves: no weekday, month, WPSR, OPEC, IEA,
  STEO, COT, rig-count, refinery, expiry, or roll-window trigger.
- XAU/XAG, XNG, gas-metal, oil-metal, oil-gas, and index book sleeves.

## Markets And Timeframe

- Logical symbol: `QM5_13005_XBR_CAD_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`.
- Basket legs: `XBRUSD.DWX` and `USDCAD.DWX`.
- Period: `D1`.
- Expected package frequency: about 6-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC only; no Bank of Canada, EIA, CER, futures
  curve, API, CSV, analyst forecast, or ML model at runtime.

## Entry Rules

- Evaluate only on a new D1 bar of the `XBRUSD.DWX` host chart.
- Copy recent closed D1 closes for both basket legs.
- Compute `spread = ln(XBRUSD.DWX) + beta * ln(USDCAD.DWX)`.
- Standardize the current spread into a z-score using
  `strategy_z_lookback_d1`.
- If z-score is greater than `strategy_entry_z`, short the spread: sell
  `XBRUSD.DWX` and sell `USDCAD.DWX`.
- If z-score is less than negative `strategy_entry_z`, long the spread: buy
  `XBRUSD.DWX` and buy `USDCAD.DWX`.
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

- Only run from the `XBRUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
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
- name: strategy_xbr_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_usdcad_max_spread_pts
  default: 80
  sweep_range: [50, 80, 120]

## Author Claims

The sources establish only structural lineage for an oil/CAD channel. This card
imports no performance claim for `XBRUSD.DWX`/`USDCAD.DWX`; the actual edge must
be proven or rejected by the V5 Q02 pipeline.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: medium-high because crude oil can gap and the CAD hedge is
  imperfect.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Bank of Canada staff research plus official EIA/CER
  energy-trade sources.
- [x] R2 mechanical: fixed D1 log-spread z-score entry, mean exit, max-hold
  exit, spread caps, and ATR hard stops.
- [x] R3 testable: `XBRUSD.DWX` and `USDCAD.DWX` exist in the DWX symbol
  universe and require OHLC only.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and no pyramiding.
- [x] Non-duplicate: not WTI/CAD, XNG/CAD, WTI event/calendar, Brent calendar,
  oil/gas, oil-metal, XAU/XAG, XNG, or index logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, spread data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized Brent/CAD log-spread mean reversion.
- trade_management: no trailing or partial management in v1.
- trade_close: z-score mean exit, max-hold stale-package exit, orphan leg
  cleanup, Friday close, and hard ATR stops.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-03 | initial Brent/CAD relative-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
