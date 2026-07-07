---
ea_id: QM5_13032
slug: xng-cot-fade
type: strategy
strategy_id: CFTC-COT-XNG-FRI-FADE-2026
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
  - "[[sources/CFTC-COT-RELEASE-2026]]"
concepts:
  - "[[concepts/cftc-cot-release-cadence]]"
  - "[[concepts/natural-gas-positioning-proxy]]"
  - "[[concepts/friday-positioning-exhaustion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [official-release-window, positioning-proxy, mean-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13032_XNG_COT_FRI_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 natural-gas first-new-week fade after an unusually large Friday COT-release-window displacement with close-location and SMA stretch confirmation; roughly 4-10 entries/year before Q02 validation."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.07
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, xng_volatility, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed structural commodity sleeve: CFTC COT Friday positioning-window natural-gas exhaustion fade; official CFTC release lineage, deterministic D1 rules, XNGUSD.DWX data available, no ML/grid/martingale, non-duplicate versus RSI2/rig-count/storage/seasonal/XTI/metal/index sleeves."
---

# XNG COT Friday Positioning Fade

## Hypothesis

CFTC Commitments of Traders reports provide a weekly public view of futures
market positioning and are normally released Friday afternoon using data from
the prior Tuesday. This card does not download or parse CFTC data at runtime.
It uses the official release cadence as structural lineage and asks whether a
large completed Friday `XNGUSD.DWX` D1 displacement, stretched away from a slow
mean, tends to exhaust into the next broker week.

## Source

- Primary official source, 2026 reference URL: U.S. Commodity Futures Trading
  Commission, "Commitments of Traders", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm.
- Primary release-cadence source, 2026 schedule URL: U.S. Commodity Futures
  Trading Commission, "Commitments of Traders Release Schedule", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm.
- Supplemental market-context source, 2026 context URL: CME Group,
  "Commitment of Traders", URL
  https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html.

## Concept

This is a single-symbol natural-gas positioning-window exhaustion sleeve. On
the first D1 bar of a new broker week, the EA inspects the prior completed
Friday D1 bar. If that COT-window proxy bar posts a large directional move,
closes near the directional extreme, and finishes stretched away from a slow
SMA, the EA fades the move for a short mean-reversion window.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, generic
  commodity mean-reversion rule, or multi-commodity port is used.
- `QM5_13030_xng-cot-mom`: that card follows Friday COT-window displacement
  only after trend and Donchian confirmation. This card fades stretched Friday
  displacements and does not use a channel breakout.
- `QM5_12997_xng-rig-fri-mom` and `QM5_13000_xng-rig-fri-fade`: those use
  Baker Hughes rig-count cadence. This card uses CFTC COT cadence.
- XNG storage, winter/summer/fall/shoulder, hurricane/freeze, LNG, Thursday
  storage-report, weekend, month, volshock, and multiday-drift sleeves:
  different source family, event clock, and signal definition.
- XTI COT, XTI/XNG baskets, gas/gold, gas/silver, XAU/XAG, oil/gold,
  oil/silver, index, and metals sleeves: no basket, hedge ratio, or
  metals/index exposure.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-10 entries/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  V5 framework state only.

## Entry Rules

- Evaluate only on a new `XNGUSD.DWX` D1 bar.
- Host chart must be `XNGUSD.DWX` on D1 and magic slot 0.
- Require the current D1 bar to be the first trading bar of a new broker week.
- Use the prior completed D1 bar as the COT-release-window proxy.
- Require that prior bar's day-of-week to be Friday by default.
- Compute `signal_return_pct = 100 * ln(Close[1] / Close[2])`.
- Compute ATR(`strategy_atr_period`)[1] and SMA(`strategy_mean_period`)[1].
- Require `abs(signal_return_pct) >= strategy_min_signal_return_pct`.
- Require `abs(signal_return_pct) >= strategy_min_atr_return_mult * atr_pct`,
  where `atr_pct = 100 * ATR / Close[1]`.
- Skip if `abs(signal_return_pct) > strategy_max_signal_return_pct`.
- Short fade after an up displacement:
  - `Close[1]` is in the top `strategy_close_location_min` fraction of the
    signal bar range.
  - `Close[1]` is at least `strategy_min_stretch_atr * ATR` above
    SMA(`strategy_mean_period`).
  - Enter SELL.
- Long fade after a down displacement:
  - `Close[1]` is in the bottom `strategy_close_location_min` fraction of the
    signal bar range.
  - `Close[1]` is at least `strategy_min_stretch_atr * ATR` below
    SMA(`strategy_mean_period`).
  - Enter BUY.
- Skip if an open `XNGUSD.DWX` position already exists for this EA magic.
- Skip if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close a long if the latest completed D1 close reaches or exceeds
  SMA(`strategy_mean_period`).
- Close a short if the latest completed D1 close reaches or falls below
  SMA(`strategy_mean_period`).
- Close a long if a completed D1 close has moved at least
  `strategy_reversion_close_atr_mult * ATR(strategy_atr_period)` above entry.
- Close a short if a completed D1 close has moved at least
  `strategy_reversion_close_atr_mult * ATR(strategy_atr_period)` below entry.
- Close early if a completed D1 close continues against the fade beyond
  `strategy_adverse_close_atr_mult * ATR(strategy_atr_period)`.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, SMA, spread, entry price, or stop price is
  unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_min_signal_return_pct
  default: 1.60
  sweep_range: [1.20, 1.60, 2.20]
- name: strategy_min_atr_return_mult
  default: 0.55
  sweep_range: [0.40, 0.55, 0.75]
- name: strategy_max_signal_return_pct
  default: 16.0
  sweep_range: [12.0, 16.0, 22.0]
- name: strategy_close_location_min
  default: 0.62
  sweep_range: [0.58, 0.62, 0.72]
- name: strategy_signal_dow
  default: 5
  sweep_range: [5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_mean_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_min_stretch_atr
  default: 0.65
  sweep_range: [0.45, 0.65, 0.90]
- name: strategy_atr_sl_mult
  default: 3.00
  sweep_range: [2.50, 3.00, 3.75]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_reversion_close_atr_mult
  default: 1.10
  sweep_range: [0.80, 1.10, 1.60]
- name: strategy_adverse_close_atr_mult
  default: 1.10
  sweep_range: [0.80, 1.10, 1.50]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 4000]

## Author Claims

The CFTC sources establish the COT publication and release cadence only. This
card imports no source performance claim. Q02 and later phases must validate
or reject the mechanical `XNGUSD.DWX` realization on Darwinex bars.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Initial Risk Profile

- expected_pf: 1.07.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 4-10 entries/year on D1.
- risk_class: medium-high because natural-gas gaps, sparse positioning-window
  samples, and weather-sensitive volatility require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CFTC COT pages and official release
  schedule; CME COT page used only as exchange-context supplement.
- [x] R2 mechanical: fixed new-week gate, prior Friday displacement,
  close-location, SMA stretch, ATR stop, and deterministic mean/profit/adverse
  /time exits.
- [x] R3 testable: `XNGUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: CFTC COT release-cadence XNG positioning fade, not XNG
  RSI, COT momentum, rig-count, storage, seasonal/weather, WTI COT, metals,
  index, or basket logic.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, first-new-week gate, and signal-quality checks.
- trade_entry: first-new-week COT-release-window fade after a large prior
  Friday D1 displacement with close-location and SMA-stretch confirmation.
- trade_management: SMA mean reversion, favorable ATR, adverse ATR, and
  max-hold exits.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-07.
- Q01: implemented as `framework/EAs/QM5_13032_xng-cot-fade`.
- Q02: queued after compile.
