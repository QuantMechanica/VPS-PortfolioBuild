---
ea_id: QM5_13066
slug: xti-padd4-fade
type: strategy
strategy_id: EIA-XTI-PADD4-FADE-2026
source_id: EIA-XTI-PADD4-FADE-2026
source_citation: "U.S. Energy Information Administration Rocky Mountain (PADD 4) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly Rocky Mountain (PADD 4) Ending Stocks excluding SPR of Crude Oil."
    location: "https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP41"
    quality_tier: A
    role: primary
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, failed-breakout-fade, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13066_XTI_PADD4_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "January-April and September-December Rocky Mountain PADD 4 crude-stock pressure window, Thursday/Friday post-WPSR proxy, D1 failed-upside probe, and one signal per month; estimate 3-6 entries/year before Q02."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
g0_approval_reasoning: "Mission-directed commodity/energy sleeve; R1 official EIA Rocky Mountain PADD 4 crude-stock data and WPSR source family; R2 deterministic D1 calendar, failed-upside range probe, SMA downtrend filter, ATR stop/target, spread, and time-exit rules; R3 XTIUSD.DWX D1 data available; R4 no ML, grid, martingale, external runtime feed, or multi-position magic. Non-duplicate versus PADD2/PADD3/PADD5 long stockdraw/squeeze sleeves because this is short-only PADD4 failed-upside fade logic."
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
modules_used: [calendar-window, failed-range-probe, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI Rocky Mountain PADD 4 Failed-Upside Fade

## Hypothesis

The U.S. Energy Information Administration publishes weekly Rocky Mountain
PADD 4 crude-oil stocks excluding SPR as part of the official petroleum data
lineage, with the Weekly Petroleum Status Report providing the recurring
oil-inventory information window. PADD 4 is an inland regional crude-stock
series, so inventory pressure can be different from Gulf Coast, West Coast,
Cushing, and broad WTI report-window behavior.

This card tests a conservative structural proxy: in January-April and
September-December, if WTI makes a post-WPSR D1 upside probe above the recent
range but closes back below that range high while the D1 trend filter is down,
the failed reaction may continue lower over the next several sessions. The EA
does not read EIA values at runtime; it uses official EIA source lineage for the
edge definition and native Darwinex `XTIUSD.DWX` D1 OHLC, spread, ATR, SMA,
and broker calendar for deterministic execution.

## Non-Duplicate Boundary

This is not `QM5_13063_xti-padd2-draw`, which trades WTI long after PADD 2
stockdraw momentum. This is not `QM5_13064_xti-padd5-sqz`, which trades long
after a PADD 5 compression and drawdown squeeze. It is not an OPEC MOMR, IEA
OMR, EIA STEO, PSM, DPR, production, import/export, refinery utilization, SPR,
Cushing, rig-count, COT, roll, XTI/XNG ratio, oil/metal ratio, XAU/XAG ratio,
XNG, commodity RSI, or index/metal logic.

The implementation is short-only, PADD 4 scoped, post-WPSR calendar proxied,
and requires a failed upside range probe plus a bearish D1 trend filter.

## Source

- Primary reference: U.S. Energy Information Administration, Weekly Rocky
  Mountain (PADD 4) Ending Stocks excluding SPR of Crude Oil,
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP41.
- Supporting release family: U.S. Energy Information Administration, Weekly
  Petroleum Status Report, https://www.eia.gov/petroleum/supply/weekly/.

## Rules

The strategy is a deterministic short-only D1 failed-upside fade. Evaluate once
per new D1 bar using the prior completed D1 bar as the signal bar. The signal
bar must be Thursday or Friday in broker time, inside the January-April or
September-December PADD 4 pressure windows, and only one signal may be consumed
per calendar month.

A valid short signal requires the prior D1 bar to probe above the previous
context high by a minimum ATR fraction, close back below the context high, close
in the lower part of its daily range, and print a bearish body. The signal is
filtered by D1 trend: close below fast SMA, fast SMA below slow SMA, and fast
SMA falling versus a prior fast SMA sample.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: short only.
- Runtime data: native MT5 OHLC, spread, ATR helper, SMA helper, broker
  calendar, and V5 framework state.

## 4. Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar.

1. Signal month must be inside either `strategy_season_start_month_a` through
   `strategy_season_end_month_a` or `strategy_season_start_month_b` through
   `strategy_season_end_month_b`.
2. Signal day of week must be inside `strategy_report_start_dow` through
   `strategy_report_end_dow`.
3. Signal range must be at least `strategy_min_range_atr * ATR`.
4. Signal body must be at least `strategy_min_body_atr * ATR` and bearish.
5. Build context high/low from the prior `strategy_context_lookback` completed
   D1 bars excluding the signal bar.
6. Short: signal high probes above context high by `strategy_min_probe_atr *
   ATR`, closes back at or below context high, and close location is no more
   than `strategy_max_close_location`.
7. Trend filter: signal close below `strategy_sma_period` SMA, that SMA below
   `strategy_slow_sma_period` SMA, and the fast SMA below its
   `strategy_sma_slope_shift` sample.
8. Skip if an open position exists, this signal month was already consumed,
   spread is too wide, or guardrail inputs are invalid.

## 5. Exit Rules

- ATR hard stop and ATR profit target are set at entry.
- Close any still-open position after `strategy_max_hold_days` calendar days.
- Close if price closes back above the fast SMA.
- Close if broker month exits both PADD 4 pressure windows.
- Framework Friday close and kill switch remain active.
- One position per magic/symbol. No pyramiding, grid, martingale, external data
  calls, or discretionary override.

## 6. Filters (No-Trade Module)

- Do not trade any symbol other than `XTIUSD.DWX` or timeframe other than D1.
- Do not trade outside magic slot 0.
- Do not enter outside the deterministic PADD 4 seasonal and post-WPSR proxy
  windows.
- Do not enter when spread exceeds `strategy_max_spread_points`.
- Do not enter when V5 news, Friday-close, kill-switch, or input guardrails
  block trading.

## 7. Trade Management Rules

Position sizing is delegated to the V5 framework fixed-risk module using
`RISK_FIXED=1000`. Stops and targets are normalized through framework stop
rules. Management is limited to ATR stop, ATR target, time stop, fast-SMA
invalidation, seasonal invalidation, and framework risk controls.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_season_start_month_a` | 1 | 1-12 | First month in first PADD 4 pressure window |
| `strategy_season_end_month_a` | 4 | 1-12 | Last month in first PADD 4 pressure window |
| `strategy_season_start_month_b` | 9 | 1-12 | First month in second PADD 4 pressure window |
| `strategy_season_end_month_b` | 12 | 1-12 | Last month in second PADD 4 pressure window |
| `strategy_report_start_dow` | 4 | 3-5 | First broker day-of-week allowed for post-WPSR signal |
| `strategy_report_end_dow` | 5 | 4-5 | Last broker day-of-week allowed for post-WPSR signal |
| `strategy_context_lookback` | 14 | 10-20 | D1 context range excluding signal bar |
| `strategy_sma_period` | 55 | 34-80 | Fast trend SMA |
| `strategy_slow_sma_period` | 120 | 90-160 | Slow trend SMA |
| `strategy_sma_slope_shift` | 6 | 3-10 | Prior fast-SMA sample for falling-trend check |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.50 | 0.40-0.80 | Minimum signal range in ATR units |
| `strategy_min_body_atr` | 0.12 | 0.05-0.25 | Minimum signal body in ATR units |
| `strategy_min_probe_atr` | 0.06 | 0.00-0.15 | Minimum outside-range probe in ATR units |
| `strategy_max_close_location` | 0.45 | 0.35-0.55 | Maximum close location for failed-upside short |
| `strategy_atr_sl_mult` | 2.40 | 1.75-3.25 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.60 | 1.75-3.50 | ATR target distance |
| `strategy_max_hold_days` | 6 | 3-9 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

- expected_pf: 1.04.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-6 trades/year.
- risk_class: medium-high for crude-oil inventory-window volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA PADD 4 crude-stock data and WPSR source
  family.
- [x] R2 mechanical: fixed seasonal calendar proxy, post-WPSR day proxy,
  failed Donchian-style upside probe/reclaim, SMA trend filter, ATR stop/target,
  spread cap, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no adaptive fitting, grid, martingale, external runtime
  feed, or discretionary override.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, entry calendar proxy, and valid data checks.
- trade_entry: PADD 4 seasonal post-WPSR failed-upside D1 range probe with SMA
  downtrend filter.
- trade_management: max-hold stale-position exit, fast-SMA invalidation, and
  seasonal invalidation.
- trade_close: hard ATR stop, ATR target, and deterministic management exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | mission-directed EIA PADD 4 WTI failed-upside fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PASS | `artifacts/qm5_13066_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | QUEUED | `artifacts/qm5_13066_q02_enqueue_20260708.json` / work item `fefd5fd3-0885-4930-ae49-486532615df8` |
