---
ea_id: QM5_13064
slug: xti-padd5-sqz
type: strategy
strategy_id: EIA-XTI-PADD5-SQZ-2026
source_id: EIA-XTI-PADD5-SQZ-2026
source_citation: "U.S. Energy Information Administration West Coast (PADD 5) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly West Coast (PADD 5) Ending Stocks excluding SPR of Crude Oil."
    location: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP51
    quality_tier: A
    role: primary
  - type: official_energy_data_table
    citation: "U.S. Energy Information Administration. West Coast (PADD 5) Stocks of Crude Oil and Petroleum Products."
    location: https://www.eia.gov/dnav/pet/pet_stoc_wstk_dcu_r50_w.htm
    quality_tier: A
    role: supporting
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, compression-breakout, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13064_XTI_PADD5_SQZ_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "May-October West Coast PADD 5 crude-stock squeeze window, Thursday/Friday post-WPSR proxy, D1 compression breakout, and one signal per month; estimate 3-6 entries/year before Q02."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
g0_approval_reasoning: "Mission-directed commodity/energy sleeve; R1 official EIA West Coast PADD 5 crude-stock data and WPSR source family; R2 deterministic D1 calendar, compression, breakout, SMA trend, ATR stop/target, spread, and time-exit rules; R3 XTIUSD.DWX D1 data available; R4 no ML, grid, martingale, external runtime feed, or multi-position magic."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.04
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, compression-breakout, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI West Coast PADD 5 Stockdraw Squeeze

## Hypothesis

EIA publishes weekly West Coast PADD 5 crude-oil stock levels excluding the SPR
inside the official petroleum data family and WPSR tables. PADD 5 is a
geographically isolated coastal refining and import region; a post-WPSR D1
price breakout after a compressed range can express regional crude tightness
without requiring the EA to read EIA data at runtime.

The EA imports no EIA data, CSV, web page, forecast, or external calendar at
runtime. It trades deterministic price-only confirmation on Darwinex
`XTIUSD.DWX` D1 bars inside a May-October West Coast stockdraw pressure window.

## Non-Duplicate Boundary

This is not `QM5_13044_xti-padd3-draw` or `QM5_13063_xti-padd2-draw`: those are
Gulf Coast and Midwest pullback-reclaim momentum sleeves. This card uses West
Coast PADD 5 source lineage and a compression-then-breakout rule after the WPSR
proxy window. It is also not Cushing delivery-hub tightness, broad WPSR
inventory momentum, gasoline/distillate/jet fuel/product-supplied logic, PSM,
DPR, field production, import/export, refinery utilization, SPR, COT,
rig-count, OPEC, IEA/STEO, expiry/roll, XTI/XNG, oil-metal, XAU/XAG, XNG RSI,
or index logic.

## Rules

The strategy is a deterministic long-only D1 reaction model. On each new D1 bar
it inspects the previous completed bar. The signal bar must be Thursday or
Friday in broker time, inside the May-October PADD 5 squeeze window, and the EA
may consume at most one signal per broker-calendar month.

Entry requires:

- a compressed prior D1 context range;
- a bullish signal bar with ATR-normalized range/body;
- a close in the upper portion of the signal bar;
- a close above the prior context high;
- a close above a rising `SMA(80)`;
- `SMA(80) > SMA(160)`;
- spread below the configured cap and no open position for this EA magic.

The EA enters `XTIUSD.DWX` long at market with ATR-defined hard stop and target.
It exits on ATR stop, ATR target, max-hold timeout, close below the fast SMA,
leaving the May-October window, framework Friday close, or kill switch.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: long only.
- Runtime data: native MT5 OHLC, spread, ATR/SMA helpers, broker calendar.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 5 | 4-6 | First West Coast stockdraw squeeze month |
| `strategy_season_end_month` | 10 | 9-11 | Last West Coast stockdraw squeeze month |
| `strategy_report_start_dow` | 4 | 3-4 | Thursday WPSR proxy start |
| `strategy_report_end_dow` | 5 | 4-5 | Friday WPSR holiday-drift proxy |
| `strategy_context_lookback` | 12 | 8-18 | Prior D1 range used for breakout context |
| `strategy_compression_lookback` | 7 | 5-10 | Prior D1 range used for compression check |
| `strategy_max_compression_atr` | 1.65 | 1.2-2.2 | Maximum compressed prior range in ATR units |
| `strategy_max_open_extension_atr` | 0.30 | 0.10-0.50 | Reject opens already far above context high |
| `strategy_sma_period` | 80 | 55-100 | Fast D1 trend filter period |
| `strategy_slow_sma_period` | 160 | 120-220 | Slow D1 trend filter period |
| `strategy_sma_slope_shift` | 8 | 4-12 | Bars used for fast SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.55 | 0.40-0.85 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.16 | 0.08-0.28 | Minimum bullish body in ATR units |
| `strategy_min_close_location` | 0.66 | 0.56-0.80 | Minimum close location inside signal bar |
| `strategy_breakout_buffer_atr` | 0.03 | 0.00-0.12 | Required close distance above context high |
| `strategy_atr_sl_mult` | 2.70 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.45 | 1.8-3.4 | ATR target distance |
| `strategy_max_hold_days` | 7 | 4-11 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, portfolio gates, or live setfiles.

## R1-R4 Verdict

- R1 PASS: official EIA PADD 5 crude-stock data and WPSR tables.
- R2 PASS: deterministic D1 calendar, compression, breakout, SMA, ATR, spread,
  stop, target, and time-exit rules.
- R3 PASS: `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no grid, no martingale, one position per magic/symbol, and
  no external runtime feed.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap,
  May-October season, and one-signal-per-month gate.
- trade_entry: WPSR proxy bar compression breakout with SMA trend filter.
- trade_management: SMA invalidation, season invalidation, max-hold exit.
- trade_close: ATR stop/target plus deterministic strategy exits and framework
  Friday close.

## Pipeline

G0 approved for Q02 on 2026-07-08 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.
Build evidence is expected at `artifacts/qm5_13064_build_result.json` after
compilation and Q02 enqueue.
