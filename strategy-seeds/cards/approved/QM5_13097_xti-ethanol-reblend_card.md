---
ea_id: QM5_13097
slug: xti-ethanol-reblend
type: strategy
strategy_id: EIA-ETHANOL-REBLEND-XTI-2026
source_id: EIA-ETHANOL-REBLEND-XTI-2026
source_citation: "U.S. Energy Information Administration. Ethanol blending provides another proxy for gasoline demand; U.S. fuel ethanol production continues to grow in 2017; What's in your gasoline? Understanding U.S. motor gasoline formulations; Weekly Petroleum Status Report. URLs https://www.eia.gov/todayinenergy/detail.php?id=13271, https://www.eia.gov/todayinenergy/detail.php?id=32152, https://www.eia.gov/todayinenergy/detail.php?id=67464, https://www.eia.gov/petroleum/supply/weekly/"
source_citations:
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. Ethanol blending provides another proxy for gasoline demand."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=13271"
    quality_tier: A
    role: primary
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. U.S. fuel ethanol production continues to grow in 2017."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=32152"
    quality_tier: A
    role: supporting
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. What's in your gasoline? Understanding U.S. motor gasoline formulations."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67464"
    quality_tier: A
    role: supporting
  - type: official_agency_data_page
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: cadence_reference
sources:
  - "[[sources/EIA-ETHANOL-REBLEND-XTI-2026]]"
concepts:
  - "[[concepts/ethanol-blending-gasoline-demand-proxy]]"
  - "[[concepts/spring-gasoline-reblend]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [official-source-lineage, structural-demand, ethanol-blending, spring-reblend, pullback-reclaim, trend-filter-ma, atr-hard-stop, atr-profit-target, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13097_XTI_ETHANOL_REBLEND_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XTI spring ethanol/gasoline reblend pullback-reclaim; estimate 2-7 trades/year after date-window, pullback, SMA reclaim, close-location, spread, and one-position filters."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS official EIA ethanol/gasoline source packet; R2 PASS deterministic XTIUSD.DWX D1 spring reblend pullback-reclaim rule with SMA reclaim, ATR body/range, close-location, ATR stop/target, time/window/SMA exits, and one-position guard; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI Ethanol Reblend Pullback-Reclaim

## Hypothesis

EIA describes ethanol blending as a proxy for gasoline demand when most gasoline
is E10, notes April ethanol-plant maintenance in the weekly ethanol production
series, and documents the spring/summer gasoline formulation switch. This card
ports that structure to a low-frequency WTI sleeve: buy `XTIUSD.DWX` only after
a late-April to mid-June pullback below the D1 mean is reclaimed with a strong
closed D1 bar.

This is intended to add solo crude-oil exposure to the current XAU/SP500/NDX/XNG
book without adding another gold, index, XNG RSI, or XAU/XAG-style basket.

## Source

- Source: [[sources/EIA-ETHANOL-REBLEND-XTI-2026]]
- Primary citation: U.S. Energy Information Administration, "Ethanol blending
  provides another proxy for gasoline demand", Today in Energy, October 7, 2013,
  URL https://www.eia.gov/todayinenergy/detail.php?id=13271.
- Supporting citation: U.S. Energy Information Administration, "U.S. fuel
  ethanol production continues to grow in 2017", Today in Energy, July 21,
  2017, URL https://www.eia.gov/todayinenergy/detail.php?id=32152.
- Supporting citation: U.S. Energy Information Administration, "What's in your
  gasoline? Understanding U.S. motor gasoline formulations", Today in Energy,
  April 15, 2026, URL https://www.eia.gov/todayinenergy/detail.php?id=67464.

No source performance claim is imported. The source packet provides structural
energy-market lineage only; Q02 validates the deterministic Darwinex CFD
implementation.

## Concept

The strategy uses only Darwinex `XTIUSD.DWX` OHLC, spread, ATR, SMA, broker
calendar, and V5 framework state. It does not read EIA/WPSR values, fuel ethanol
production, gasoline stocks, product-supplied data, RBOB prices, refinery
statistics, futures curves, volume, open interest, CSV, API, analyst forecasts,
or discretionary runtime data.

This is deliberately different from:

- `QM5_12579_eia-wti-aftershock`: not a generic Wednesday/Thursday WPSR
  post-event range-expansion rule.
- `QM5_13039_xti-gasdraw-mom`: not May-August gasoline-stock pressure after a
  WPSR proxy reaction.
- `QM5_12737_eia-wti-drive`: not broad April-August channel breakout.
- `QM5_13078_xti-holiday-gas-fade`: not post-driving-holiday mean reversion.
- RBOB crack, distillate, jet-fuel, propane, Cushing, refinery, hurricane,
  OPEC, IEA, STEO, SPR, roll/expiry, COT, rig-count, import/export, PADD,
  XTI/XNG, oil/metal, XAU/XAG, XNG, and `QM5_12567_cum-rsi2-commodity`: no
  event feed, cross-asset basket, RSI, storage, or futures-curve logic is used.

## Target Symbols And Period

- Target symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: 2-7 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

The EA evaluates only on a new `XTIUSD.DWX` D1 bar. The completed signal bar
must fall inside the spring reblend window, default April 20 through June 15.
The prior completed close must be below its D1 SMA and the signal close must
reclaim that SMA. The prior lookback window must include a low at least
`strategy_min_pullback_atr * ATR` below the signal-bar SMA, representing a
maintenance/reblend pullback before recovery. The signal bar must be bullish,
large enough versus ATR, close in the upper part of its range, and avoid a
materially falling SMA.

## Entry

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Signal bar: most recent completed D1 bar.
- Signal date must be inside April 20 to June 15 by default.
- Prior completed close must be below or equal to its SMA.
- Signal close must reclaim above the current SMA.
- Lowest low over the prior pullback window must sit at least
  `strategy_min_pullback_atr * ATR` below the current SMA.
- Signal range, body, and close location must pass ATR/close-location gates.
- SMA must be flat-to-rising; it cannot be falling by more than the configured
  ATR buffer versus its lagged value.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit

- Exit if the spring reblend window is over.
- Exit if a completed D1 close falls below SMA minus
  `strategy_exit_sma_buffer_atr * ATR`.
- Exit after `strategy_max_hold_days` calendar days.
- Framework Friday close remains enabled.

## Stop

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- No pyramiding, gridding, martingale, partial close, or trailing stop in v1.

## Parameters To Test

- name: strategy_window_start_month
  default: 4
  sweep_range: [4]
- name: strategy_window_start_day
  default: 20
  sweep_range: [15, 20, 25]
- name: strategy_window_end_month
  default: 6
  sweep_range: [6]
- name: strategy_window_end_day
  default: 15
  sweep_range: [10, 15, 30]
- name: strategy_pullback_lookback
  default: 12
  sweep_range: [8, 12, 16]
- name: strategy_min_pullback_atr
  default: 0.60
  sweep_range: [0.40, 0.60, 0.90]
- name: strategy_sma_period
  default: 40
  sweep_range: [30, 40, 60]
- name: strategy_sma_slope_lag_days
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_max_sma_fall_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.55
  sweep_range: [0.40, 0.55, 0.80]
- name: strategy_min_body_atr
  default: 0.22
  sweep_range: [0.15, 0.22, 0.35]
- name: strategy_min_close_location
  default: 0.62
  sweep_range: [0.58, 0.62, 0.70]
- name: strategy_exit_sma_buffer_atr
  default: 0.10
  sweep_range: [0.00, 0.10, 0.25]
- name: strategy_atr_sl_mult
  default: 2.40
  sweep_range: [1.80, 2.40, 3.00]
- name: strategy_atr_tp_mult
  default: 3.00
  sweep_range: [2.20, 3.00, 4.00]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [7, 12, 18]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 2-7 trades/year.
- risk_class: medium-high for crude-oil overnight and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA ethanol/gasoline source packet.
- [x] R2 mechanical: fixed D1 date window, SMA reclaim, prior pullback depth,
  ATR body/range, close-location confirmation, ATR stop/target, SMA/window/time
  exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, and
  one position per magic.
- [x] Non-duplicate: not WPSR aftershock/fade/pre-event, not May-August
  gasoline-stock momentum, not broad driving-season channel breakout, not
  holiday gasoline fade, not RBOB/distillate/jet/propane/refinery, not XTI/XNG,
  not metals, not XNG RSI.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, and reblend-window guard.
- trade_entry: spring pullback-reclaim with SMA context, ATR body/range,
  close-location confirmation, and one-position guard.
- trade_management: SMA trend-failure exit, ATR target/stop, date-window exit,
  and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic close rules.

## Falsification

Reject if Q02 produces zero trades, PF below the Q02 floor, drawdown above the
Q02 ceiling, or evidence that the rule is materially correlated with the
current index/metal/XNG live book rather than adding crude-oil sleeve diversity.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial EIA ethanol/gasoline spring reblend build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
