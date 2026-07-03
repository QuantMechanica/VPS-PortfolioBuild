---
ea_id: QM5_13004
slug: xti-cot-fade
type: strategy
strategy_id: CFTC-COT-XTI-FRI-FADE-2026
source_id: CFTC-COT-RELEASE-2026
source_citation: "U.S. Commodity Futures Trading Commission, Commitments of Traders main page and release schedule. URLs https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm and https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm"
source_citations:
  - type: government_market_data
    citation: "U.S. Commodity Futures Trading Commission. Commitments of Traders."
    location: "https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm"
    quality_tier: A
    role: primary
  - type: government_release_schedule
    citation: "U.S. Commodity Futures Trading Commission. Commitments of Traders Release Schedule."
    location: "https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm"
    quality_tier: A
    role: primary
  - type: exchange_context
    citation: "CME Group. Commitment of Traders tool and CFTC report context."
    location: "https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html"
    quality_tier: B
    role: supplement
sources:
  - "https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm"
  - "https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm"
  - "https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html"
concepts:
  - "cftc-cot-release-cadence"
  - "managed-money-positioning-proxy"
  - "friday-positioning-exhaustion"
indicators:
  - "ATR"
  - "SMA"
strategy_type_flags: [official-release-window, positioning-proxy, mean-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13004_XTI_COT_FRI_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI first-new-week fade after an unusually large Friday COT-release-window displacement with close-location and SMA stretch confirmation; roughly 4-12 entries/year before Q02 validation."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [low_frequency_sample, friday_close, crude_oil_volatility, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official CFTC COT source and release-schedule packet; R2 PASS deterministic D1 first-new-week fade after a large Friday XTI displacement, close-location confirmation, SMA stretch, ATR stop, favorable/adverse closed-bar exits, SMA mean exit, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this is a CFTC COT release-cadence positioning-exhaustion proxy on WTI, not WPSR/EIA inventory, OPEC/IEA/STEO/DPR, refinery/product-seasonality, Cushing, SPR, hurricane, roll/expiry, month/weekday premium, XTI/XNG, WTI/Brent, oil-metal ratio, broad commodity TSMOM/reversal/carry, or XNG rig-count logic."
---

# XTI COT Friday Positioning Fade

## Source

- Primary official source: U.S. Commodity Futures Trading Commission,
  "Commitments of Traders", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm.
- Primary release-cadence source: U.S. Commodity Futures Trading Commission,
  "Release Schedule", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm.
- Supplemental market-context source: CME Group, "Commitment of Traders", URL
  https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html.

## Concept

CFTC Commitments of Traders reports provide a weekly public view of futures
market positioning and are normally released Friday afternoon with data from
the prior Tuesday. This card does not download or parse CFTC data at runtime.
It uses the official release cadence as structural lineage and asks whether a
large completed Friday `XTIUSD.DWX` D1 displacement, closing near an extreme
and stretched away from a slow mean, tends to exhaust into the next trading
week.

The mechanical expression is symmetric. On the first D1 bar of a new broker
week, inspect the prior completed Friday D1 bar. If that bar posted a large
upward displacement, closed near its high, and finished stretched above SMA,
sell WTI. If it posted a large downward displacement, closed near its low, and
finished stretched below SMA, buy WTI. Positions exit on SMA mean reversion,
favorable or adverse ATR-based closed-bar movement, hard ATR stop, or time
stop.

## Non-Duplicate Rationale

- Not WPSR/inventory, export-flow, STEO, DPR, SPR, Cushing, refinery,
  distillate/RBOB/jet fuel, hurricane, OPEC, IEA OMR, roll, expiry, or
  WTI/Brent logic: no such source family or event window is used.
- Not `QM5_12596_wti-mon-fade`, `QM5_12597_wti-fri-prem`,
  `QM5_12610_wti-tue-fade`, `QM5_12771_wti-thu-prem`, or other weekday/month
  seasonality cards: this requires a COT-release-window Friday displacement,
  close-location extreme, SMA stretch, ATR scaling, and first-new-week entry.
- Not `QM5_12997_xng-rig-fri-mom` or `QM5_13000_xng-rig-fri-fade`: those use
  Baker Hughes rig-count cadence on natural gas; this is CFTC COT cadence on
  WTI.
- Not broad commodity TSMOM/reversal/carry, XTI/XNG, XAU/XAG, oil/gold,
  oil/silver, RSI commodity pullback, or Turtle/Donchian trend logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-12 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only. No CFTC download, COT CSV, futures curve, inventory
  feed, API, analyst forecast, discretionary override, or ML model is used at
  runtime.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- Require the current D1 bar to be the first trading bar of a new broker week.
- Use the prior completed D1 bar as the COT-release-window proxy.
- Require that prior bar's day-of-week to be Friday by default.
- Compute `signal_return_pct = 100 * ln(Close[1] / Close[2])`.
- Compute ATR(`strategy_atr_period`)[1] and SMA(`strategy_mean_period`)[1].
- Require `abs(signal_return_pct) >= strategy_min_signal_return_pct`.
- Require `abs(signal_return_pct) >= strategy_min_atr_return_mult * atr_pct`,
  where `atr_pct = 100 * ATR / Close[1]`.
- Skip if `abs(signal_return_pct) > strategy_max_signal_return_pct`.
- For a short fade after an up displacement:
  - `Close[1]` must be in the top `strategy_close_location_min` fraction of
    the signal-bar range.
  - `Close[1]` must be at least `strategy_min_stretch_atr * ATR` above
    SMA(`strategy_mean_period`).
  - Enter SELL.
- For a long fade after a down displacement:
  - `Close[1]` must be in the bottom `strategy_close_location_min` fraction of
    the signal-bar range.
  - `Close[1]` must be at least `strategy_min_stretch_atr * ATR` below
    SMA(`strategy_mean_period`).
  - Enter BUY.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close a long if a completed D1 close reaches or exceeds
  SMA(`strategy_mean_period`).
- Close a short if a completed D1 close reaches or falls below
  SMA(`strategy_mean_period`).
- Close a long if a completed D1 close has moved at least
  `strategy_reversion_close_atr_mult * ATR` above entry price.
- Close a short if a completed D1 close has moved at least
  `strategy_reversion_close_atr_mult * ATR` below entry price.
- Close early if a completed D1 close continues against the fade beyond
  `strategy_adverse_close_atr_mult * ATR`.
- Friday Close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_min_signal_return_pct
  default: 1.25
  sweep_range: [0.90, 1.25, 1.75]
- name: strategy_min_atr_return_mult
  default: 0.60
  sweep_range: [0.45, 0.60, 0.80]
- name: strategy_max_signal_return_pct
  default: 9.0
  sweep_range: [7.0, 9.0, 12.0]
- name: strategy_close_location_min
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_signal_dow
  default: 5
  sweep_range: [5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_mean_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_min_stretch_atr
  default: 0.50
  sweep_range: [0.35, 0.50, 0.80]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.50]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_reversion_close_atr_mult
  default: 0.80
  sweep_range: [0.60, 0.80, 1.10]
- name: strategy_adverse_close_atr_mult
  default: 1.00
  sweep_range: [0.75, 1.00, 1.30]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Risk

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 4-12 entries/year on D1.
- risk_class: medium-high because crude-oil gaps, event timing, and sparse
  positioning-window samples require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CFTC COT pages and official release
  schedule; CME COT page used only as exchange-context supplement.
- [x] R2 mechanical: fixed new-week gate, prior Friday displacement,
  close-location extreme, SMA stretch, ATR stop, SMA/ATR/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime data, and one position per magic.
- [x] Non-duplicate: CFTC COT release-cadence WTI positioning fade, not the
  existing WTI/XNG source families listed above.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: first-new-week COT-release-window fade after large prior Friday
  D1 displacement, close-location confirmation, and SMA stretch.
- trade_management: SMA mean exit, favorable/adverse ATR closed-bar exits, and
  max-hold exit.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-03.
- Q01: implemented as `framework/EAs/QM5_13004_xti-cot-fade`.
- Q02: queued after compile.
