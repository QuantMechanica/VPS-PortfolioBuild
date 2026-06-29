---
ea_id: QM5_12763
slug: wti-ref-sqz-brk
type: strategy
source_id: EIA-WTI-REFINERY-MAINT-2026
source_citation: "U.S. Energy Information Administration. Refinery outages: planned and unplanned outages, 2007-2011; U.S. refinery utilization rates slightly higher than last year heading into summer. URLs https://www.eia.gov/petroleum/articles/refoutagesindex.php and https://www.eia.gov/todayinenergy/detail.php?id=61543"
sources:
  - "[[sources/EIA-WTI-REFINERY-MAINT-2026]]"
concepts:
  - "[[concepts/refinery-utilization-ramp]]"
  - "[[concepts/volatility-compression-breakout]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
  - "[[indicators/donchian-channel]]"
strategy_type_flags: [calendar-seasonality, volatility-compression, channel-breakout, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12763_XTI_REF_SQZ_BRK_D1
period: D1
expected_trade_frequency: "D1 WTI pre-summer refinery-utilization squeeze-breakout sleeve; estimate 4-8 trades/year after compression, trend, breakout, spread, and framework filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
expected_pf: 1.1
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA refinery outage/utilization source; R2 PASS deterministic May-Jul D1 compression breakout with ATR/SMA/channel/time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# WTI Refinery Utilization Squeeze Breakout

## Source

- Source: [[sources/EIA-WTI-REFINERY-MAINT-2026]]
- Primary citation: U.S. Energy Information Administration, "Refinery outages:
  planned and unplanned outages, 2007-2011", URL
  https://www.eia.gov/petroleum/articles/refoutagesindex.php.
- Structural supplement: U.S. Energy Information Administration, "U.S.
  refinery utilization rates slightly higher than last year heading into
  summer", URL https://www.eia.gov/todayinenergy/detail.php?id=61543.

## Concept

EIA documents refinery outage behavior and the transition from maintenance
season into higher refinery utilization heading into summer. This card does
not forecast outages or ingest EIA utilization data. It uses the official
lineage only to define a low-frequency pre-summer energy regime, then requires
Darwinex `XTIUSD.DWX` D1 compression, rising trend, and upside range breakout
before taking long exposure.

This is deliberately different from:

- `QM5_12593_eia-wti-ref-fade`: refinery shoulder mean reversion from stretch
  rejection bars. This card is long-only continuation after compression.
- `QM5_12737_eia-wti-drive`: gasoline driving-season channel breakout. This
  card requires ATR compression and a rising refinery-ramp trend gate in a
  narrower May-July window.
- `QM5_12581_eia-rbob-crack`: gasoline crack-spread seasonal long/short
  breakout. This card is not an RBOB crack-spread proxy and never shorts.
- WTI WPSR, hurricane, OPEC, expiry, ETF-roll, and month-of-year sleeves:
  this card has no weekly event, storm, policy, futures-roll, or standalone
  month-effect trigger.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon pullback,
  ML, grid, or martingale logic.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: 6 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed,
  refinery-utilization data, outage data, product-spread feed, futures curve,
  inventory feed, CSV, API, or external input.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior closed D1 bar must fall inside the pre-summer refinery-utilization
  ramp window: May 1 through July 31, inclusive.
- Long only.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Trend gate: prior closed D1 close must be above SMA(`strategy_trend_period`),
  and the current SMA must be above the SMA from
  `strategy_sma_slope_shift` bars earlier.
- Compression gate: ATR(`strategy_atr_fast_period`) divided by
  ATR(`strategy_atr_slow_period`) must be less than or equal to
  `strategy_compression_ratio`.
- Breakout gate: prior closed D1 close must break above the highest high of the
  previous `strategy_entry_channel` completed D1 bars, excluding the signal bar.
- Entry: BUY `XTIUSD.DWX` at market after all gates pass.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_slow_period`) *
  `strategy_atr_sl_mult`.
- Close if the active date leaves the May 1 through July 31 refinery-ramp
  window.
- Close if prior closed D1 close falls below SMA(`strategy_trend_period`).
- Close if prior closed D1 close breaks below the lowest low of the previous
  `strategy_exit_channel` completed bars, excluding the signal bar.
- Close if `strategy_max_hold_days` calendar days is exceeded.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- No short entries.
- Skip entries when SMA, ATR, or channel OHLC series are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_start_month
  default: 5
  sweep_range: [5]
- name: strategy_start_day
  default: 1
  sweep_range: [1, 15]
- name: strategy_end_month
  default: 7
  sweep_range: [7]
- name: strategy_end_day
  default: 31
  sweep_range: [15, 31]
- name: strategy_trend_period
  default: 84
  sweep_range: [63, 84, 100, 150]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_entry_channel
  default: 25
  sweep_range: [15, 25, 35]
- name: strategy_exit_channel
  default: 12
  sweep_range: [8, 12, 18]
- name: strategy_atr_fast_period
  default: 10
  sweep_range: [7, 10, 14]
- name: strategy_atr_slow_period
  default: 30
  sweep_range: [20, 30, 40]
- name: strategy_compression_ratio
  default: 0.80
  sweep_range: [0.70, 0.80, 0.90]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 18
  sweep_range: [10, 18, 28]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. EIA is used only as official
structural lineage for refinery maintenance, planned/unplanned outage behavior,
and utilization conditions heading into summer. The edge claim is tested by
the QM Q02+ pipeline on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: 6 trades/year on D1.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA refinery outage and utilization URLs.
- [x] R2 mechanical: fixed date window, D1 trend gate, ATR-compression gate,
  channel breakout entry, ATR stop, channel/trend/window/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: continuation after compression, not existing refinery
  fade, gasoline driving-season breakout, RBOB crack spread, WPSR, hurricane,
  OPEC, expiry, ETF-roll, medium-term momentum, XNG, XAU/XAG, or RSI commodity
  logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap,
  and May-July window.
- trade_entry: pre-summer refinery-ramp D1 compression breakout.
- trade_management: window end, SMA trend failure, channel failure, and
  max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window/trend/range exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI refinery-utilization squeeze-breakout card | G0 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | PENDING | this card |

