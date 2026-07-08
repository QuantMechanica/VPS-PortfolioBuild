---
ea_id: QM5_13068
slug: xti-padd1-reclaim
type: strategy
strategy_id: EIA-XTI-PADD1-RECLAIM-2026
source_id: EIA-XTI-PADD1-RECLAIM-2026
source_citation: "U.S. Energy Information Administration East Coast (PADD 1) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly East Coast (PADD 1) Ending Stocks excluding SPR of Crude Oil."
    location: "https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP11"
    quality_tier: A
    role: primary
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, failed-breakout-fade, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13068_XTI_PADD1_RECLAIM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "January-March and October-December East Coast PADD 1 crude-stock sensitivity window, Thursday/Friday post-WPSR proxy, D1 failed-breakdown reclaim, one signal per month; estimate 3-6 entries/year before Q02."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
g0_approval_reasoning: "Mission-directed commodity/energy sleeve; R1 official EIA East Coast PADD 1 crude-stock data and WPSR source family; R2 deterministic D1 calendar, failed-breakdown range reclaim, SMA uptrend filter, ATR stop/target, spread, and time-exit rules; R3 XTIUSD.DWX D1 data available; R4 no ML, grid, martingale, external runtime feed, or multi-position magic. Non-duplicate versus PADD2/PADD3/PADD5 long stockdraw/squeeze sleeves and PADD4 short failed-upside fade because this is East Coast scoped, long-only, and requires a downside false break with bullish trend confirmation."
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

# XTI East Coast PADD 1 Failed-Breakdown Reclaim

## Hypothesis

The U.S. Energy Information Administration publishes weekly East Coast (PADD 1)
crude-oil stocks excluding SPR as part of the official petroleum data lineage,
with the Weekly Petroleum Status Report providing the recurring oil-inventory
information window. PADD 1 is a geographically distinct East Coast stock series
and can express a different regional balance than PADD 2 Midwest stockdraws,
PADD 3 Gulf Coast balances, PADD 4 Rocky Mountain pressure, or PADD 5 West
Coast compression.

This card tests a conservative structural proxy: in January-March and
October-December, if WTI probes below a recent D1 range after the WPSR window
but closes back above that range low while the D1 trend filter remains bullish,
the failed downside reaction may continue higher over the next several
sessions. The EA does not read EIA values at runtime; it uses official EIA
source lineage for the edge definition and native Darwinex `XTIUSD.DWX` D1
OHLC, spread, ATR, SMA, and broker calendar for deterministic execution.

## Non-Duplicate Boundary

This is not `QM5_13063_xti-padd2-draw`, which trades WTI long after PADD 2
stockdraw momentum. This is not `QM5_13044_xti-padd3-draw`, which is Gulf Coast
stockdraw scoped. This is not `QM5_13064_xti-padd5-sqz`, which trades long after
PADD 5 compression and drawdown squeeze. This is not `QM5_13066_xti-padd4-fade`,
which is short-only and fades failed upside probes in a Rocky Mountain PADD 4
pressure window.

The implementation is East Coast PADD 1 scoped, long-only, post-WPSR calendar
proxied, and requires a failed downside range probe plus a bullish D1 trend
filter. It is not OPEC MOMR, IEA OMR, EIA STEO, PSM, DPR, field production,
import/export, refinery utilization, SPR, Cushing, rig-count, COT, roll,
XTI/XNG ratio, oil/metal ratio, XAU/XAG ratio, XNG, commodity RSI, or
index/metal logic.

## Source

- Primary reference: U.S. Energy Information Administration, Weekly East Coast
  (PADD 1) Ending Stocks excluding SPR of Crude Oil,
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP11.
- Supporting release family: U.S. Energy Information Administration, Weekly
  Petroleum Status Report, https://www.eia.gov/petroleum/supply/weekly/.

## Rules

The strategy is a deterministic long-only D1 failed-breakdown reclaim. Evaluate
once per new D1 bar using the prior completed D1 bar as the signal bar. The
signal bar must be Thursday or Friday in broker time, inside the January-March
or October-December PADD 1 sensitivity windows, and only one signal may be
consumed per calendar month.

A valid long signal requires the prior D1 bar to probe below the previous
context low by a minimum ATR fraction, close back above the context low, close
in the upper part of its daily range, and print a bullish body. The signal is
filtered by D1 trend: close above fast SMA, fast SMA above slow SMA, and fast
SMA rising versus a prior fast-SMA sample.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: long only.
- Runtime data: native MT5 OHLC, spread, ATR helper, SMA helper, broker
  calendar, and V5 framework state.

## Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar.

1. Signal month must be inside either `strategy_season_start_month_a` through
   `strategy_season_end_month_a` or `strategy_season_start_month_b` through
   `strategy_season_end_month_b`.
2. Signal day of week must be inside `strategy_report_start_dow` through
   `strategy_report_end_dow`.
3. Signal range must be at least `strategy_min_range_atr * ATR`.
4. Signal body must be at least `strategy_min_body_atr * ATR` and bullish.
5. Build context high/low from the prior `strategy_context_lookback` completed
   D1 bars excluding the signal bar.
6. Long: signal low probes below context low by `strategy_min_probe_atr * ATR`,
   closes back at or above context low, and close location is at least
   `strategy_min_close_location`.
7. Trend filter: signal close above `strategy_sma_period` SMA, that SMA above
   `strategy_slow_sma_period` SMA, and the fast SMA above its
   `strategy_sma_slope_shift` sample.
8. Skip if an open position exists, this signal month was already consumed,
   spread is too wide, or guardrail inputs are invalid.

## Exit Rules

- ATR hard stop and ATR profit target are set at entry.
- Close any still-open position after `strategy_max_hold_days` calendar days.
- Close if price closes back below the fast SMA.
- Close if broker month exits both PADD 1 sensitivity windows.
- Framework Friday close and kill switch remain active.
- One position per magic/symbol. No pyramiding, grid, martingale, external data
  calls, or discretionary override.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_season_start_month_a` | 1 | 1-12 | First month in first PADD 1 sensitivity window |
| `strategy_season_end_month_a` | 3 | 1-12 | Last month in first PADD 1 sensitivity window |
| `strategy_season_start_month_b` | 10 | 1-12 | First month in second PADD 1 sensitivity window |
| `strategy_season_end_month_b` | 12 | 1-12 | Last month in second PADD 1 sensitivity window |
| `strategy_report_start_dow` | 4 | 3-5 | First broker day-of-week allowed for post-WPSR signal |
| `strategy_report_end_dow` | 5 | 4-5 | Last broker day-of-week allowed for post-WPSR signal |
| `strategy_context_lookback` | 16 | 10-24 | D1 context range excluding signal bar |
| `strategy_sma_period` | 34 | 21-55 | Fast trend SMA |
| `strategy_slow_sma_period` | 100 | 80-160 | Slow trend SMA |
| `strategy_sma_slope_shift` | 5 | 3-10 | Prior fast-SMA sample for rising-trend check |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.45 | 0.35-0.75 | Minimum signal range in ATR units |
| `strategy_min_body_atr` | 0.10 | 0.05-0.25 | Minimum signal body in ATR units |
| `strategy_min_probe_atr` | 0.05 | 0.00-0.15 | Minimum outside-range probe in ATR units |
| `strategy_min_close_location` | 0.55 | 0.50-0.70 | Minimum close location for failed-breakdown long |
| `strategy_atr_sl_mult` | 2.20 | 1.75-3.25 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.80 | 2.00-3.75 | ATR target distance |
| `strategy_max_hold_days` | 7 | 4-10 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

- expected_pf: 1.04.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-6 trades/year.
- risk_class: medium-high for crude-oil inventory-window volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

Q02 and later backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The build
is single-symbol, low-frequency, non-ML, non-grid, non-martingale, and uses no
runtime web/API/CSV/EIA feed. It does not touch live setfiles, `T_Live`,
AutoTrading, or the portfolio gate.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA East Coast PADD 1 crude-stock data and
  WPSR source family.
- [x] R2 mechanical: fixed seasonal calendar proxy, post-WPSR day proxy, failed
  Donchian-style downside probe/reclaim, SMA trend filter, ATR stop/target,
  spread cap, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no adaptive fitting, grid, martingale, external runtime
  feed, or discretionary override.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, entry calendar proxy, and valid data checks.
- trade_entry: PADD 1 seasonal post-WPSR failed-downside D1 range reclaim with
  SMA uptrend filter.
- trade_management: max-hold stale-position exit, fast-SMA invalidation, and
  seasonal invalidation.
- trade_close: hard ATR stop, ATR target, and deterministic management exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-08 | mission-directed EIA PADD 1 WTI failed-breakdown reclaim build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PASS | `artifacts/qm5_13068_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | QUEUED | `artifacts/qm5_13068_q02_enqueue_20260708.json` / work item `22f18111-1e5d-4bfe-9c7d-6a8223f45f28` |
