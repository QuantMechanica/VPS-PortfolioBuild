---
ea_id: QM5_13083
slug: xbr-cadjpy-rspr
type: strategy
strategy_id: EIA-BOC-BOJ-XBR-CADJPY-2026_S01
source_id: EIA-BOC-BOJ-XBR-CADJPY-2026
source_citation: "EIA oil/exchange-rate working paper plus official Bank of Canada commodity-CAD note and EIA/BOJ Japan oil-importer context."
source_citations:
  - type: government_research
    citation: "Beckmann, Czudaj, and Arora. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, 2017."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_research
    citation: "Bank of Canada Staff Analytical Note 2017-1. The Link Between the Canadian Dollar and Commodity Prices: Has It Broken?"
    location: "https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/"
    quality_tier: A
    role: cad_channel
  - type: government_energy_context
    citation: "U.S. Energy Information Administration. Japan Country Analysis Brief."
    location: "https://www.eia.gov/international/analysis/country/JPN"
    quality_tier: A
    role: jpy_importer_channel
  - type: central_bank_speech
    citation: "Bank of Japan, Uchida, S. Recent Developments in Economic Activity, Prices, and Monetary Policy. 2026-06-03."
    location: "https://www.boj.or.jp/en/about/press/koen_2026/ko260603a.htm"
    quality_tier: A
    role: jpy_import_cost_context
sources:
  - "[[sources/EIA-BOC-BOJ-XBR-CADJPY-2026]]"
concepts:
  - "[[concepts/oil-fx-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/energy-sleeve]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [oil-fx-return-spread, market-neutral-basket, zscore-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XBRUSD.DWX, CADJPY.DWX]
basket_symbols: [XBRUSD.DWX, CADJPY.DWX]
markets: [XBRUSD.DWX, CADJPY.DWX]
primary_target_symbols: [XBRUSD.DWX, CADJPY.DWX]
single_symbol_only: false
logical_symbol: QM5_13083_XBR_CADJPY_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XBR/CADJPY return-spread z-score reversion; estimate 8-14 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-04
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-04: R1 PASS official EIA/central-bank source packet; R2 PASS deterministic D1 two-leg XBR/CADJPY return-spread z-score reversion with spread caps, mean exit, max-hold exit, and ATR hard stops; R3 PASS XBRUSD.DWX and CADJPY.DWX exist in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is a paired Brent/CADJPY return-spread basket, not the Singh CADJPY leading-indicator build, Brent/USDCAD, Brent/USDJPY, XBR/NZD, XBR/XNG, Brent/Brent, metal-ratio, XNG, or index logic."
---

# XBR/CADJPY D1 Return-Spread Reversion

## Source

- Source: [[sources/EIA-BOC-BOJ-XBR-CADJPY-2026]]
- Primary citation: Beckmann, Czudaj, and Arora, "The Relationship between Oil
  Prices and Exchange Rates", U.S. Energy Information Administration Working
  Paper, 2017.
- Support: Bank of Canada Staff Analytical Note 2017-1 for the commodity/CAD
  channel; EIA Japan and BOJ material for the Japan oil-importer terms-of-trade
  channel.

## Concept

Oil, CAD, and JPY have a structural macro relationship, but the relationship
can break by regime. This card therefore avoids using CADJPY as a one-way
predictor and trades a two-leg relative-value package:

`return_spread = ln(XBR[t] / XBR[t-L]) - beta_cadjpy * ln(CADJPY[t] / CADJPY[t-L])`

When Brent has unusually outperformed CADJPY over the fixed D1 return window, the
basket shorts Brent and buys CADJPY. When Brent has unusually underperformed
CADJPY, it buys Brent and sells CADJPY. The bet is a temporary return-spread
dislocation between the crude leg and the oil-exporter/oil-importer FX leg.

This is deliberately different from:

- `QM5_1040_singh-cmd-corr`: that EA trades CADJPY from oil support/resistance
  breakouts and does not trade Brent as a paired basket leg.
- `QM5_12609_wti-cad-spread-mr` and `QM5_12722_wti-cad-brk`: those use USDCAD,
  not CADJPY, and different spread definitions.
- `QM5_12834_wti-jpy-spread`: that uses USDJPY as the Japan proxy, not CADJPY.
- `QM5_13006_xbr-nzd-rspread`, `QM5_12840_xbr-xng-rspread`, Brent/Brent,
  oil/gold, oil/silver, XAU/XAG, XNG, index, and outright Brent calendar/event
  sleeves: this is a two-leg Brent/CADJPY return-spread basket.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon pullback,
  or single-symbol commodity reversal logic is used.

## Markets And Timeframe

- Logical symbol: `QM5_13083_XBR_CADJPY_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`.
- Basket legs: `XBRUSD.DWX` and `CADJPY.DWX`.
- Period: D1.
- Expected trade frequency: about 8-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread metadata, ATR, broker time, and
  V5 framework state only. No EIA, Bank of Canada, BOJ, futures-curve, CFTC,
  macro CSV, API, analyst forecast, or ML model is consumed at runtime.

## Entry Rules

- Evaluate only on a new D1 bar of the `XBRUSD.DWX` host chart.
- Copy completed D1 closes for `XBRUSD.DWX` and `CADJPY.DWX`.
- Compute `xbr_ret = ln(XBR close[1] / XBR close[1 + strategy_return_lookback_d1])`.
- Compute `cadjpy_ret = ln(CADJPY close[1] / CADJPY close[1 + strategy_return_lookback_d1])`.
- Compute `return_spread = xbr_ret - strategy_beta_cadjpy * cadjpy_ret`.
- Standardize the latest completed return spread against the prior
  `strategy_z_lookback_d1` completed return spreads.
- Short spread: if z-score is above `strategy_entry_z`, sell `XBRUSD.DWX` and
  buy `CADJPY.DWX`.
- Long spread: if z-score is below `-strategy_entry_z`, buy `XBRUSD.DWX` and
  sell `CADJPY.DWX`.
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

- Only run from the `XBRUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Skip entries when `XBRUSD.DWX` spread exceeds `strategy_xbr_max_spread_pts`.
- Skip entries when `CADJPY.DWX` spread exceeds `strategy_cadjpy_max_spread_pts`.
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
- name: strategy_beta_cadjpy
  default: 0.65
  sweep_range: [0.4, 0.65, 0.9]
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
- name: strategy_xbr_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_cadjpy_max_spread_pts
  default: 120
  sweep_range: [80, 120, 180]

## Author Claims

The source packet establishes structural lineage for oil/exchange-rate and
oil-exporter/oil-importer FX channels only. This card imports no source
performance number. Q02 and later phases must validate or reject the
`XBRUSD.DWX` / `CADJPY.DWX` basket on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 8-14 paired packages/year.
- risk_class: medium-high because crude volatility, CADJPY carry/risk
  sensitivity, and synchronized basket fills need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single official-source packet anchored on EIA
  research with central-bank and government support.
- [x] R2 mechanical: fixed D1 return spread, rolling z-score entry/exit, ATR
  hard stops, spread caps, max-hold exit, and broken-package repair.
- [x] R3 testable: `XBRUSD.DWX` and `CADJPY.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Non-duplicate: paired Brent/CADJPY return-spread mean reversion, not Singh
  oil-to-CADJPY breakout, Brent/USDCAD, Brent/USDJPY, XBR/NZD, XBR/XNG,
  Brent/Brent, metal-ratio, XNG, index, or outright Brent logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Registry And Queue Notes

- Slot 0: `XBRUSD.DWX`.
- Slot 1: `CADJPY.DWX`.
- Use the logical basket setfile `QM5_13083_XBR_CADJPY_RSPREAD_D1` for Q02.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps, news,
  Friday close, and valid data checks.
- trade_entry: D1 standardized XBR/CADJPY return-spread reversion.
- trade_management: broken-package repair and max-hold tracking.
- trade_close: z-score mean exit, max-hold exit, Friday close, and ATR hard
  stops.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce at least one valid logical-basket
trade, if Q02 PF is below 1.0 after costs, if synchronized XBR/CADJPY history
is insufficient, or if the basket preflight cannot execute both legs under the
V5 one-position-per-magic model.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-04 | initial XBR/CADJPY return-spread basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-04 | APPROVED | this card |
| Q01 Build Validation | 2026-07-04 | PENDING | `artifacts/qm5_13083_build_result.json` |
| Q02 Baseline Screening | 2026-07-04 | PENDING | enqueue after compile |
