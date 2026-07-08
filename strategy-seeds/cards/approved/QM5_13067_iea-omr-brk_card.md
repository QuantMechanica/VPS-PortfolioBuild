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
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-08: R1 PASS official IEA Oil Market Report source; R2 PASS deterministic mid-month calendar proxy, D1 Donchian breakout, ATR stop/target, spread cap, time exit, and one-entry-per-month guard; R3 PASS XTIUSD.DWX is in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus QM5_12994 because this follows OMR-window closing breakouts instead of fading shock bars."
---

# QM5_13067 IEA OMR WTI Breakout

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/iea-omr-brk_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses the official IEA Oil Market
Report as structural lineage for a monthly mid-month information window, but
reads no IEA report contents, calendars, news, CSV/API feeds, forecasts,
futures curves, inventory data, or ML output at runtime.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.

## hypothesis

Large WTI D1 closing breakouts inside the IEA OMR proxy window can persist for
several sessions as crude-oil market-balance information is digested. This
tests a breakout continuation branch that is intentionally separate from
`QM5_12994_iea-omr-fade`.

## rules

Trade `XTIUSD.DWX` D1 only. On each new broker D1 bar, use the previous
completed D1 bar. If that bar falls inside broker-calendar day 10 through day
18, has enough ATR-normalized range and body, and closes outside the prior
Donchian context range, enter in the breakout direction. Allow at most one
entry per month.

## 4. entry rules

PARAMETERS

- strategy_event_start_day = 10
- strategy_event_end_day = 18
- strategy_breakout_lookback = 20
- strategy_atr_period = 20
- strategy_min_range_atr = 1.00
- strategy_min_body_atr = 0.35
- strategy_atr_sl_mult = 2.50
- strategy_atr_tp_mult = 3.00
- strategy_max_hold_days = 5
- strategy_max_spread_points = 1000

## 5. exit rules

Use an ATR hard stop, ATR profit target, five-calendar-day time exit, standard
news handling, and Friday close.

## risk

Q02 backtests use one `XTIUSD.DWX` D1 setfile with fixed risk. One position per
magic/symbol; no pyramiding, grid, martingale, partial close, external runtime
feed, adaptive PnL fitting, or ML.
