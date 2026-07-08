---
ea_id: QM5_13047
slug: eia-steo-fade
type: strategy
strategy_id: EIA-STEO-XTI-FADE-2026
source_id: EIA-STEO-XTI-BRK-2026
source_citation: "U.S. Energy Information Administration, Short-Term Energy Outlook, https://www.eia.gov/outlooks/steo/; STEO release schedule, https://www.eia.gov/outlooks/steo/release_schedule.php; STEO global oil markets, https://www.eia.gov/outlooks/steo/report/global_oil.php"
source_citations:
  - type: official_report
    citation: "U.S. Energy Information Administration. Short-Term Energy Outlook."
    location: "https://www.eia.gov/outlooks/steo/"
    quality_tier: A
    role: primary
  - type: official_release_schedule
    citation: "U.S. Energy Information Administration. Short-Term Energy Outlook release schedule."
    location: "https://www.eia.gov/outlooks/steo/release_schedule.php"
    quality_tier: A
    role: timing_rule
  - type: official_report
    citation: "U.S. Energy Information Administration. STEO global oil markets."
    location: "https://www.eia.gov/outlooks/steo/report/global_oil.php"
    quality_tier: A
    role: crude_oil_context
strategy_type_flags: [official-release-window, failed-breakout-fade, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13047_XTI_STEO_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA STEO D1 failed-breakout fade; estimate 5-10 entries/year after range, probe, reclaim, spread, and one-entry-per-release filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, failed-range-probe, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# EIA STEO WTI Failed-Breakout Fade

## Hypothesis

The EIA Short-Term Energy Outlook is a recurring official monthly oil-market
information window. `QM5_12992_eia-steo-brk` already tests whether a STEO proxy
day closing breakout continues. This card tests the opposite structural
reaction: if the STEO proxy day probes outside the recent D1 crude range but
closes back inside it, the next session may mean-revert as the first reaction
fails.

The EA reads no EIA release content at runtime. The EIA source supplies only the
official report lineage and deterministic monthly timing proxy; execution uses
Darwinex `XTIUSD.DWX` D1 OHLC, spread, ATR, broker calendar, and V5 framework
state.

## Non-Duplicate Boundary

This is not `QM5_12992_eia-steo-brk`, which follows closing breakouts. This EA
requires failed outside probes and fades them. It is also not IEA OMR, OPEC
MOMR, WPSR, DPR, PSM, Cushing, SPR, import/export, production, refinery,
hurricane, roll, month, weekday, XTI/XNG, oil/metal, XAU/XAG, XNG, or commodity
RSI logic.

## Rules

The strategy is a deterministic symmetric D1 fade. On the first Tuesday after
the first Thursday of the broker-calendar month, with optional Wednesday delay,
the prior completed STEO proxy bar must have an ATR-sized range and a body. A
short signal requires an upside probe beyond the previous D1 context high and a
close back at or below that high in the lower half of the range. A long signal
requires a downside probe beyond the previous D1 context low and a close back at
or above that low in the upper half of the range. The EA enters the next D1 bar
with ATR stop, ATR target, max-hold exit, standard news handling, and Friday
close.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: symmetric long/short.
- Runtime data: native MT5 OHLC, spread, ATR helper, broker calendar.

## 4. Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar.

1. Signal bar must be the STEO proxy day.
2. Signal range must be at least `strategy_min_range_atr * ATR`.
3. Signal body must be at least `strategy_min_body_atr * ATR`.
4. Build context high/low from the prior `strategy_context_lookback` completed
   D1 bars excluding the STEO proxy bar.
5. Long: signal low probes below context low by `strategy_min_probe_atr * ATR`,
   closes back at or above context low, and close location is at least
   `strategy_long_min_close_location`.
6. Short: signal high probes above context high by `strategy_min_probe_atr * ATR`,
   closes back at or below context high, and close location is no more than
   `strategy_short_max_close_location`.
7. Skip if an open position exists, this signal day was already consumed,
   spread is too wide, or guardrail inputs are invalid.

## 5. Exit Rules

- ATR hard stop and ATR profit target are set at entry.
- Close any still-open position after `strategy_max_hold_days` calendar days.
- Framework Friday close and kill switch remain active.
- One position per magic/symbol. No pyramiding, grid, martingale, external data
  calls, or discretionary override.

## 6. Filters (No-Trade Module)

- Do not trade any symbol other than `XTIUSD.DWX` or timeframe other than D1.
- Do not trade outside magic slot 0.
- Do not trade when spread exceeds `strategy_max_spread_points`.
- Do not trade when V5 news, Friday-close, kill-switch, or input guardrails
  block trading.

## 7. Trade Management Rules

Position sizing is delegated to the V5 framework fixed-risk module using
`RISK_FIXED=1000`. Stops and targets are normalized through framework stop
rules. Management is limited to ATR stop, ATR target, time stop, and framework
risk controls.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_context_lookback` | 14 | 10-20 | D1 context range excluding STEO bar |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.50 | 0.40-0.80 | Minimum signal range in ATR units |
| `strategy_min_body_atr` | 0.10 | 0.05-0.20 | Minimum signal body in ATR units |
| `strategy_min_probe_atr` | 0.05 | 0.00-0.15 | Minimum outside-range probe in ATR units |
| `strategy_long_min_close_location` | 0.50 | 0.45-0.60 | Minimum long close location |
| `strategy_short_max_close_location` | 0.50 | 0.40-0.55 | Maximum short close location |
| `strategy_atr_sl_mult` | 2.25 | 1.75-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.75 | 2.0-3.5 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |
| `strategy_allow_wed_delay` | true | true/false | Allow Wednesday delayed STEO proxy |

## Risk

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 5-10 trades/year.
- risk_class: medium-high for crude-oil report-window volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA STEO report and release schedule.
- [x] R2 mechanical: fixed calendar proxy, failed Donchian probe/reclaim, ATR
  stop/target, spread cap, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no adaptive fitting, grid, martingale, external runtime
  feed, or discretionary override.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, release-window proxy, and valid data checks.
- trade_entry: monthly STEO failed-breakout fade on completed D1 OHLC.
- trade_management: max-hold stale-position exit.
- trade_close: hard ATR stop, ATR target, and deterministic time exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | mission-directed STEO failed-breakout fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PASS | `artifacts/qm5_13047_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | QUEUED | `artifacts/qm5_13047_q02_enqueue_20260708.json` / work item `0b20c287-1481-4783-94c1-b3ff23c37bbf` |
