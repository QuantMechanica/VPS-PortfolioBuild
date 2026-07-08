---
ea_id: QM5_13070
slug: xti-jodi-fade
type: strategy
strategy_id: JODI-OIL-UPDATE-FADE-2026
source_id: JODI-OIL-UPDATE-BRK-2026
source_citation: "JODI-Oil World Database and IEF Monthly Oil & Gas Data Review. URLs https://www.jodidata.org/oil/, https://www.jodidata.org/oil/support/update-calendar.aspx, https://www.ief.org/data/oil-gas-data-review, and https://www.iea.org/about/international-collaborations/joint-organisations-data-initiative"
source_citations:
  - type: official_global_energy_data
    citation: "Joint Organisations Data Initiative. JODI-Oil World Database."
    location: "https://www.jodidata.org/oil/"
    quality_tier: A
    role: primary
  - type: official_release_calendar
    citation: "Joint Organisations Data Initiative. JODI-Oil World Database Update Calendar."
    location: "https://www.jodidata.org/oil/support/update-calendar.aspx"
    quality_tier: A
    role: primary
  - type: official_energy_review
    citation: "International Energy Forum. Oil and Gas Data Review."
    location: "https://www.ief.org/data/oil-gas-data-review"
    quality_tier: A
    role: supporting
  - type: official_institutional_overview
    citation: "International Energy Agency. Joint Organisations Data Initiative overview."
    location: "https://www.iea.org/about/international-collaborations/joint-organisations-data-initiative"
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, global-oil-data, n-period-min-reversion, n-period-max-continuation, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13070_XTI_JODI_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly JODI oil update-window D1 failed-probe fade; estimate 2-6 entries/year after window, Donchian probe/reclaim, SMA mean, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
g0_approval_reasoning: "Mission-directed commodity/energy sleeve; R1 PASS official JODI/IEF/IEA global oil data source packet; R2 PASS deterministic monthly date-window proxy, D1 failed Donchian probe/reclaim fade, SMA mean exit, ATR stop/target, spread cap, max-hold exit, and one-entry-per-month guard; R3 PASS XTIUSD.DWX exists in the DWX symbol matrix; R4 PASS no ML, grid, martingale, external runtime feed, or multi-position magic. Non-duplicate versus QM5_13069 because this fades failed JODI-window probes instead of following closing breakouts."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.07
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, failed-probe-fade, sma-mean-exit, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI JODI Monthly Oil Data Failed-Probe Fade

## Hypothesis

JODI is an official global oil and gas data-transparency initiative with a
public monthly oil database and an IEF monthly Oil and Gas Data Review. The
source family defines a broad global oil information window, not a U.S.
inventory report, OPEC decision event, IEA forecast window, or futures-roll
calendar.

This card tests whether `XTIUSD.DWX` often rejects failed D1 range probes during
that monthly update/review window. The EA reads no JODI data at runtime. The
official source only defines the structural information clock; execution uses
native MT5 D1 OHLC, broker calendar, spread, ATR, SMA, and V5 framework state.

## Non-Duplicate Boundary

This is not `QM5_13069_xti-jodi-brk`, which follows a completed-bar Donchian
closing breakout in the JODI proxy window. This sibling fades failed probes:
long after a downside probe reclaims the prior range, short after an upside
probe rejects back inside the prior range, then exits at the SMA mean or time
guard.

It is also not IEA OMR, OPEC MOMR, EIA STEO/DPR/PSM/WPSR/Cushing/PADD/refinery
or product-demand logic, Baker Hughes rig count, COT, roll, expiry,
ratio-spread, XNG, metal, index, or commodity RSI logic.

## Source

- Primary database: JODI-Oil World Database, https://www.jodidata.org/oil/.
- Release calendar: JODI-Oil World Database Update Calendar,
  https://www.jodidata.org/oil/support/update-calendar.aspx.
- Review publication: IEF Oil and Gas Data Review,
  https://www.ief.org/data/oil-gas-data-review.
- Institutional support: IEA Joint Organisations Data Initiative overview,
  https://www.iea.org/about/international-collaborations/joint-organisations-data-initiative.

## Rules

The strategy is a deterministic D1 monthly information-window failed-probe fade.
Evaluate once per new D1 bar using the prior completed D1 bar as the signal bar.
The signal bar must fall inside a fixed day-of-month proxy for the JODI monthly
update/review window, and only one signal may be consumed per calendar month.

A valid long signal requires the completed signal bar to probe below the prior
Donchian low by an ATR-scaled amount, reclaim back inside the range, close above
its open, and remain below the SMA mean. A valid short signal mirrors this after
an upside probe above the prior Donchian high, rejection back inside the range,
close below its open, and close above the SMA mean.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: symmetric long/short.
- Runtime data: native MT5 OHLC, spread, ATR helper, SMA helper, broker
  calendar, and V5 framework state.

## Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar.

1. Signal day of month must be between `strategy_event_start_day` and
   `strategy_event_end_day`.
2. Signal range must be at least `strategy_min_range_atr * ATR`.
3. Signal body must be at least `strategy_min_body_atr * ATR`.
4. Build context high/low from the prior `strategy_probe_lookback` completed
   D1 bars excluding the signal bar.
5. Long fade: signal low probes below context low by at least
   `strategy_min_probe_atr * ATR`, closes back above
   `context_low + strategy_reclaim_buffer_atr * ATR`, closes above its open,
   and closes below SMA(`strategy_mean_sma_period`).
6. Short fade: signal high probes above context high by at least
   `strategy_min_probe_atr * ATR`, closes back below
   `context_high - strategy_reclaim_buffer_atr * ATR`, closes below its open,
   and closes above SMA(`strategy_mean_sma_period`).
7. Skip if an open position exists, this signal month was already consumed,
   spread is too wide, or guardrail inputs are invalid.

## Exit Rules

- ATR hard stop and ATR profit target are set at entry.
- Close any still-open position after `strategy_max_hold_days` calendar days.
- Close long if the prior completed D1 close reaches or exceeds the SMA mean.
- Close short if the prior completed D1 close reaches or falls below the SMA
  mean.
- Framework Friday close and kill switch remain active.
- One position per magic/symbol. No pyramiding, grid, martingale, external data
  calls, report parsing, or discretionary override.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_event_start_day` | 18 | 16-20 | First broker-calendar day in the JODI monthly proxy window |
| `strategy_event_end_day` | 23 | 21-25 | Last broker-calendar day in the JODI monthly proxy window |
| `strategy_probe_lookback` | 34 | 20-55 | D1 Donchian context excluding the signal bar |
| `strategy_mean_sma_period` | 100 | 63-150 | SMA mean used for entry side and mean exit |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.70 | 0.50-1.20 | Minimum signal range in ATR units |
| `strategy_min_body_atr` | 0.20 | 0.10-0.45 | Minimum signal body in ATR units |
| `strategy_min_probe_atr` | 0.10 | 0.05-0.25 | Minimum failed probe beyond prior range |
| `strategy_reclaim_buffer_atr` | 0.03 | 0.00-0.10 | Reclaim distance back inside prior range |
| `strategy_atr_sl_mult` | 2.20 | 1.75-3.25 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.60 | 2.00-3.50 | ATR target distance |
| `strategy_max_hold_days` | 6 | 4-10 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

- expected_pf: 1.07.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 2-6 trades/year.
- risk_class: medium-high for crude-oil monthly information-window volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

Q02 and later backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The build
is single-symbol, low-frequency, non-ML, non-grid, non-martingale, and uses no
runtime web/API/CSV/JODI feed. It does not touch live setfiles, `T_Live`,
AutoTrading, or the portfolio gate.

## Strategy Allowability Check

- [x] R1 reputable source: official JODI/IEF/IEA global oil data and update
  calendar source packet.
- [x] R2 mechanical: fixed monthly calendar proxy, completed-bar failed range
  probe/reclaim, SMA mean exit, ATR stop/target, spread cap, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no adaptive fitting, grid, martingale, external runtime
  feed, or discretionary override.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, monthly JODI proxy-window gate, and valid data checks.
- trade_entry: monthly JODI update-window failed Donchian probe fade with SMA
  mean-side confirmation.
- trade_management: max-hold stale-position exit and SMA mean-touch exit.
- trade_close: hard ATR stop, ATR target, and deterministic management exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-08 | mission-directed JODI monthly global-oil WTI failed-probe fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PASS | `artifacts/qm5_13070_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | QUEUED | `artifacts/qm5_13070_q02_enqueue_20260708.json` |
