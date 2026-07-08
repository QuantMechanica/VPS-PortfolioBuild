---
ea_id: QM5_13067
slug: iea-omr-brk
type: strategy
strategy_id: IEA-OMR-XTI-BRK-2026_S01
source_id: IEA-OMR-XTI-BRK-2026
source_citation: "International Energy Agency. Oil Market Report (OMR). https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr"
source_citations:
  - type: official_report
    citation: "International Energy Agency. Oil Market Report (OMR)."
    location: "https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr"
    quality_tier: A
    role: primary
strategy_type_flags: [official-release-window, donchian-breakout, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13067_XTI_IEA_OMR_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly IEA OMR D1 breakout proxy; estimate 4-9 entries/year after range/body/window/spread filters and one-entry-per-month guard."
expected_trades_per_year_per_symbol: 6
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
modules_used: [calendar-window, donchian-breakout, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-08: R1 PASS official IEA Oil Market Report source; R2 PASS deterministic mid-month calendar proxy, D1 Donchian breakout, ATR stop/target, spread cap, time exit, and one-entry-per-month guard; R3 PASS XTIUSD.DWX is in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus QM5_12994 because this follows OMR-window closing breakouts instead of fading shock bars."
---

# IEA OMR WTI Breakout

## Hypothesis

The IEA Oil Market Report is a recurring official oil-market information window
covering demand, supply, inventories, refinery activity, and prices. This card
tests whether a large `XTIUSD.DWX` D1 range breakout during the OMR proxy
window can continue for several sessions.

The EA reads no IEA report content at runtime. The IEA source supplies only the
official report lineage and deterministic monthly timing proxy; execution uses
Darwinex `XTIUSD.DWX` D1 OHLC, spread, ATR, broker calendar, and V5 framework
state.

## Non-Duplicate Boundary

This is not `QM5_12994_iea-omr-fade`, which fades unusually large OMR-window
shock bars. This card follows a completed Donchian closing breakout during the
same official-source window and uses a wider continuation target. It is also
not OPEC MOMR, EIA STEO, WPSR, DPR, PSM, Cushing, SPR, import/export,
production, refinery, hurricane, roll, month, weekday, XTI/XNG, oil/metal,
XAU/XAG, XNG, VRP, COT, or commodity RSI logic.

## Source

- Primary reference: International Energy Agency, Oil Market Report (OMR),
  https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr.

## Rules

The strategy is a deterministic symmetric D1 breakout. The signal bar must be a
completed D1 bar inside broker-calendar day 10 through day 18, matching the
mid-month OMR proxy window used by the existing IEA OMR fade card. A long
signal requires the signal bar to close above the prior Donchian high with a
large enough range and body. A short signal requires a close below the prior
Donchian low with the same range/body checks. The EA enters on the next D1 bar
with ATR stop, ATR target, max-hold exit, standard news handling, Friday close,
and a one-entry-per-month guard.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: symmetric long/short.
- Runtime data: native MT5 OHLC, spread, ATR helper, broker calendar.

## 4. Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar.

1. Signal bar must be inside the IEA OMR proxy window:
   `strategy_event_start_day` through `strategy_event_end_day`.
2. Signal range must be at least `strategy_min_range_atr * ATR`.
3. Signal body must be at least `strategy_min_body_atr * ATR`.
4. Build context high/low from the prior `strategy_breakout_lookback` completed
   D1 bars excluding the OMR proxy bar.
5. Long: signal closes above the context high and above its open.
6. Short: signal closes below the context low and below its open.
7. Skip if an open position exists, this signal month was already consumed,
   spread is too wide, or guardrail inputs are invalid.

## 5. Exit Rules

- ATR hard stop and ATR profit target are set at entry.
- Close any still-open position after `strategy_max_hold_days` calendar days.
- Framework Friday close and kill switch remain active.
- One position per magic/symbol. No pyramiding, grid, martingale, external data
  calls, report parsing, or discretionary override.

## 6. Filters (No-Trade Module)

- Do not trade any symbol other than `XTIUSD.DWX` or timeframe other than D1.
- Do not trade outside magic slot 0.
- Do not trade outside the deterministic OMR proxy window.
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
| `strategy_event_start_day` | 10 | 9-11 | First broker-calendar day in OMR proxy window |
| `strategy_event_end_day` | 18 | 16-20 | Last broker-calendar day in OMR proxy window |
| `strategy_breakout_lookback` | 20 | 10-30 | D1 Donchian context excluding OMR bar |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 1.00 | 0.75-1.50 | Minimum signal range in ATR units |
| `strategy_min_body_atr` | 0.35 | 0.20-0.60 | Minimum signal body in ATR units |
| `strategy_atr_sl_mult` | 2.50 | 1.75-3.50 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.00 | 2.00-4.00 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 4-9 trades/year.
- risk_class: medium-high for crude-oil report-window volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official IEA Oil Market Report source.
- [x] R2 mechanical: fixed calendar proxy, Donchian breakout, ATR stop/target,
  spread cap, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no adaptive fitting, grid, martingale, external runtime
  feed, or discretionary override.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, release-window proxy, and valid data checks.
- trade_entry: monthly IEA OMR proxy-window Donchian breakout on completed D1
  OHLC.
- trade_management: max-hold stale-position exit.
- trade_close: hard ATR stop, ATR target, and deterministic time exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-08 | mission-directed IEA OMR breakout energy sleeve build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
