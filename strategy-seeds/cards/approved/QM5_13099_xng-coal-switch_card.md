---
ea_id: QM5_13099
slug: xng-coal-switch
type: strategy
strategy_id: EIA-XNG-COAL-SWITCH-2026
source_id: EIA-XNG-COAL-SWITCH-2026
source_citation: "U.S. Energy Information Administration. Factors affecting natural gas prices; Electricity generation from coal and natural gas both increased with summer heat; Natural gas for power generation flat this summer, record high expected in 2027. URLs https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php, https://www.eia.gov/todayinenergy/detail.php?id=8450, https://www.eia.gov/todayinenergy/detail.php?id=67725"
source_citations:
  - type: official_agency_explainer
    citation: "U.S. Energy Information Administration. Factors affecting natural gas prices."
    location: "sections Natural gas prices are affected by market supply and demand; Competition with other fuels can influence natural gas prices"
    quality_tier: A
    role: primary
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. Electricity generation from coal and natural gas both increased with summer heat."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=8450"
    quality_tier: A
    role: supplement
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. Natural gas for power generation flat this summer, record high expected in 2027."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67725"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-XNG-COAL-SWITCH-2026]]"
concepts:
  - "[[concepts/natural-gas-fuel-switching]]"
  - "[[concepts/shoulder-season-demand-floor]]"
indicators:
  - "[[indicators/closing-price-percentile]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-min-reversion, calendar-seasonality, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13099_XNG_COAL_SWITCH_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 natural-gas shoulder-season demand-floor reclaim; at most two accepted entries/year and approximately 0-2 trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 2
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS official EIA price-driver, dispatch, and current power-burn source packet; R2 PASS deterministic XNGUSD.DWX D1 spring/early-autumn bottom-quartile annual-price-rank plus SMA-reclaim rule with close-location/range confirmation, ATR stop/target, rank/SMA/time exits, and one-entry-per-season guard; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XNG Coal-Switching Demand-Floor Reclaim

## Hypothesis

EIA identifies competing-fuel prices as a natural-gas demand driver and
documents that low gas prices can make gas-fired generation more competitive
with coal. The EA tests whether unusually cheap `XNGUSD.DWX` prices find a
structural demand floor during price-sensitive spring and early-autumn shoulder
windows, entering only after a completed D1 bar reclaims its short mean.

The setup is intended as a sparse second XNG sleeve for the current
XAU/SP500/NDX/XNG book. It is not a claim that a low gas price must rebound;
Q02 and the later portfolio-correlation gate must falsify that proposition if
the proxy does not survive costs or merely reproduces the existing XNG stream.

## Source

- Primary: U.S. Energy Information Administration, "Factors affecting natural
  gas prices", Energy Explained, updated October 25, 2023, URL
  https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.
- Supplement: U.S. Energy Information Administration, "Electricity generation
  from coal and natural gas both increased with summer heat", October 19, 2012,
  URL https://www.eia.gov/todayinenergy/detail.php?id=8450.
- Current context: U.S. Energy Information Administration, "Natural gas for
  power generation flat this summer, record high expected in 2027", May 28,
  2026, URL https://www.eia.gov/todayinenergy/detail.php?id=67725.

No source performance claim is imported. The sources establish the physical
demand channel only; the deterministic CFD port is a hypothesis for the V5
pipeline to test.

## Concept

The EA runs only on `XNGUSD.DWX` D1. It defines a favorable-price regime as a
completed close in the bottom quartile of the preceding 252 D1 closes, inside
April-May or September through mid-October. It waits for a bullish range bar to
cross back above SMA(10), so the annual discount alone never triggers a trade.

Runtime uses only MT5 OHLC, ATR, SMA, broker calendar, spread, and framework
state. It does not read coal prices, EIA data, generation, power load, weather,
storage, LNG flows, futures curves, volume, open interest, CSV, API, forecasts,
or analyst input.

## Non-Duplicate Boundary

- `QM5_12567_cum-rsi2-commodity`: no RSI, two-day cumulative oscillator, or
  generic short-horizon commodity pullback is used.
- `QM5_12895_xng-6m-reversal`: no 120-D1 return threshold, symmetric long/short
  fade, monthly rebalance, or six-month zero-cross exit is used.
- `QM5_12704_xngusd-summer-power-long`: this card excludes June-August and
  requires annual-discount plus completed-bar reclaim; it does not buy each
  eligible summer month above a slow SMA.
- `QM5_12588_eia-xng-sum-sqz`: no summer compression breakout is used.
- `QM5_12703_xngusd-spring-shoulder-short`: this is a conditional long demand-
  floor reclaim at an annual discount, not an unconditional spring-demand
  decay short.
- `QM5_12896_xng-oct-turn-long`: no 10-D1 positive-turn plus fast/slow trend
  stack is used; the autumn window ends in mid-October and requires a bottom-
  quartile annual price rank.
- No storage-report, freeze, hurricane, LNG, rig-count, COT, expiry, weekend,
  weekday, carry, XTI/XNG, gas/metal, XAU/XAG, index, or external-feed logic is
  used.

## Target Symbol And Period

- Target: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Expected frequency: 0-2 entries/year because only one accepted entry is
  allowed in each of the two annual shoulder windows.

## Rules

The EA evaluates the most recent completed D1 bar after the framework new-bar
gate. The completed bar must be within April 1-May 31 or September 1-October 15.
Its close must rank at or below the configured percentile among the prior 252
completed closes. The prior close must be at or below its SMA(10), and the
signal close must reclaim above the current SMA(10). The signal bar must be
bullish, have a minimum ATR-normalized range, and close in its upper portion.

Only one accepted entry is allowed per spring or autumn season key. The EA
enters long with an ATR hard stop and ATR profit target. There is no short,
pyramid, grid, martingale, scale-in, partial close, or adaptive sizing path.

## Entry

- `XNGUSD.DWX`, D1, completed bars only.
- Signal date inside April 1-May 31 or September 1-October 15.
- `price_percentile_252 <= strategy_entry_price_percentile`.
- Prior close at or below prior SMA(`strategy_reclaim_sma_period`).
- Signal close above current SMA(`strategy_reclaim_sma_period`).
- Signal close above open.
- Signal range at least `strategy_min_range_atr * ATR`.
- Signal close location at least `strategy_min_close_location`.
- No position for this EA magic, no prior accepted entry in the same annual
  shoulder window, and spread at or below the configured cap.

## Exit

- Hard stop at `strategy_atr_sl_mult * ATR` from entry.
- Profit target at `strategy_atr_tp_mult * ATR` from entry.
- Close when the 252-D1 price percentile normalizes to or above
  `strategy_exit_price_percentile`.
- Close when a completed D1 close falls below SMA(10) minus
  `strategy_exit_sma_buffer_atr * ATR`.
- Close after `strategy_max_hold_days` calendar days.
- Framework Friday close remains enabled.

## Filters

- Wrong symbol/timeframe, invalid parameters, missing lookback, open-position,
  duplicate-season, and excessive-spread states reject entry.
- Standard V5 kill-switch, news, risk, Friday-close, and one-position-per-magic
  protections remain active.

## Trade Management

- No break-even move, trailing stop, partial close, or pyramiding in v1.
- Strategy management evaluates normalization, SMA failure, and stale hold on
  completed D1 bars.

## Parameters To Test

- name: strategy_price_rank_lookback
  default: 252
  sweep_range: [189, 252, 315]
- name: strategy_entry_price_percentile
  default: 0.25
  sweep_range: [0.15, 0.20, 0.25, 0.30]
- name: strategy_exit_price_percentile
  default: 0.55
  sweep_range: [0.45, 0.55, 0.65]
- name: strategy_reclaim_sma_period
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.55
  sweep_range: [0.40, 0.55, 0.75]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.58, 0.65, 0.72]
- name: strategy_exit_sma_buffer_atr
  default: 0.30
  sweep_range: [0.10, 0.30, 0.50]
- name: strategy_atr_sl_mult
  default: 2.80
  sweep_range: [2.20, 2.80, 3.40]
- name: strategy_atr_tp_mult
  default: 3.80
  sweep_range: [2.80, 3.80, 5.00]
- name: strategy_max_hold_days
  default: 25
  sweep_range: [15, 25, 35]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

"Favorable natural gas prices in recent years have contributed to increased
natural gas use by the electric power sector." (EIA, Factors affecting natural
gas prices, section Competition with other fuels)

"lower natural gas prices allowed natural gas-fired generators to compete with
coal-fired generators." (EIA, Today in Energy, October 19, 2012)

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: 0-2 entries/year.
- risk_class: high because XNG gaps and regime persistence can defeat a
  demand-floor hypothesis.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official U.S. Energy Information Administration
  pages with stable public URLs.
- [x] R2 mechanical: fixed calendar windows, annual price rank, SMA reclaim,
  ATR/range/close-location checks, ATR bracket, and deterministic exits.
- [x] R3 testable: `XNGUSD.DWX` exists in the local DWX symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fit, grid, martingale, external runtime
  feed, or multiple positions per magic.
- [x] Non-duplicate: annual-discount shoulder-season reclaim, not RSI2,
  six-month reversal, summer power, summer squeeze, seasonal short, winter
  turn, storage/event, or basket logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XNGUSD.DWX` D1 setfile. This build does not define live sizing and does not
touch `T_Live`, AutoTrading, deploy manifests, the T_Live manifest, portfolio
admission, or the portfolio gate.

## Framework Alignment

- no_trade: enforce XNG D1, magic slot, parameter validity, spread cap,
  completed lookback, one-position, and one-entry-per-season constraints.
- trade_entry: spring/autumn bottom-quartile 252-D1 price-rank regime plus
  bullish SMA reclaim, ATR range, and close-location confirmation.
- trade_management: normalized-rank exit, SMA failure exit, and max-hold exit.
- trade_close: hard ATR stop/target plus deterministic management exits.

## Falsification

Reject or recycle if Q02 produces zero trades, fails the PF/DD gate, or shows
that the annual-price-rank/reclaim proxy is too sparse to evaluate. Do not
promote if later portfolio evidence shows material correlation with
`QM5_12567:XNGUSD` or the current index/metal book instead of a distinct sparse
shoulder-season stream.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial EIA coal-switching demand-floor build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |

