---
ea_id: QM5_12896
slug: xng-oct-turn-long
type: strategy
strategy_id: EIA-XNG-OCT-TURN-2026
source_id: 706222b7-2d60-5fdb-8dab-d722d3c96f92
source_citation: "U.S. Energy Information Administration. Natural gas use features two seasonal peaks per year. Today in Energy, 2015-09-11. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Natural gas use features two seasonal peaks per year. Today in Energy, 2015-09-11."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=22892"
    quality_tier: A
    role: primary
sources:
  - "[[sources/706222b7-2d60-5fdb-8dab-d722d3c96f92]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/autumn-shoulder-to-winter-transition]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, seasonal-window, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Autumn-to-winter XNG transition long sleeve on D1 weekly checks; estimate 4-8 entries/year after SMA, return-turn, spread, and one-position filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 24.0
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-02: R1 PASS official EIA natural-gas seasonality source; R2 PASS deterministic October-November D1 weekly long rule with SMA trend confirmation, 10-D1 return-turn confirmation, ATR stop, SMA/season/time exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate versus QM5_12567 because this is a seasonal transition trend-following sleeve, not a two-day RSI pullback."
---

# XNG October Winter-Turn Long

## Source

- Source: [[sources/706222b7-2d60-5fdb-8dab-d722d3c96f92]]
- Primary citation: U.S. Energy Information Administration, "Natural gas use
  features two seasonal peaks per year", Today in Energy, 2015-09-11, URL
  https://www.eia.gov/todayinenergy/detail.php?id=22892.

## Concept

The EIA source describes natural-gas demand as seasonal, with winter heating
and summer electric-sector demand as the two primary consumption peaks and
lower demand in shoulder periods. This card isolates the autumn transition
from fall shoulder/storage-fill conditions into the winter heating-demand
regime. It does not ingest weather, storage, load, or EIA data at runtime; it
uses fixed October-November calendar eligibility and Darwinex `XNGUSD.DWX`
D1 price confirmation.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback
  logic.
- `QM5_12575_eia-xng-season`: this is not a broad monthly two-sided season map;
  it is an October-November transition-long rule with weekly confirmation.
- `QM5_12702_xngusd-winter-withdrawal-long`: this does not hold the whole
  November-March winter window; it only trades the early winter-turn phase and
  requires a recent 10-D1 upside turn.
- `QM5_12703_xngusd-spring-shoulder-short` and `QM5_12704_xngusd-summer-power-long`:
  different season, direction, and confirmation logic.
- XNG storage, hurricane, freeze, prestorage, weekend-gap, expiry, XTI/XNG
  basket, and medium-horizon reversal/carry sleeves: no event feed, no shock
  fade, no relative-value basket, no broker-swap carry, and no 6M return fade.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, framework news state, and broker
  calendar only. No EIA feed, storage report, weather feed, futures curve,
  CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar week.
- Eligible months are October and November.
- Compute:
  - prior completed D1 close;
  - 10-D1 return into the prior close;
  - SMA(`strategy_fast_sma_period`);
  - SMA(`strategy_slow_sma_period`);
  - ATR(`strategy_atr_period`).
- BUY `XNGUSD.DWX` when all are true:
  - eligible month is active;
  - prior close is above both moving averages;
  - fast SMA is at or above the slow SMA;
  - 10-D1 return is at least `strategy_min_turn_return_pct`;
  - spread is no greater than `strategy_max_spread_points`.
- No short entries.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult` from entry.
- Exit when the broker-calendar month is outside October-November.
- Exit when the prior D1 close falls below SMA(`strategy_fast_sma_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when SMA, ATR, return lookback, entry price, stop price, or
  spread data is unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_turn_lookback_days
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_min_turn_return_pct
  default: 3.0
  sweep_range: [2.0, 3.0, 5.0]
- name: strategy_fast_sma_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_slow_sma_period
  default: 60
  sweep_range: [42, 60, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 3.5]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [5, 6, 10]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The official source is used only as
structural lineage for seasonal natural-gas demand. Q02 and later phases must
validate or reject the mechanical `XNGUSD.DWX` autumn transition port.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 24.
- expected_trade_frequency: approximately 4-8 entries/year.
- risk_class: high for natural-gas gap and volatility risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official U.S. Energy Information Administration
  natural-gas seasonality source.
- [x] R2 mechanical: fixed October-November window, weekly gate, 10-D1
  return-turn confirmation, SMA trend filter, ATR hard stop, SMA/season/time
  exits.
- [x] R3 testable: `XNGUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: not RSI commodity logic, not broad XNG seasonality, not
  winter-allocation long, not storage/weather/event timing, not XNG carry,
  not XNG 6M reversal, and not an energy relative-value basket.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and position-duplication guard.
- trade_entry: weekly October-November transition-long entry after 10-D1
  return-turn and SMA trend confirmation.
- trade_management: season end, SMA failure, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/season/trend exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-02 | initial structural XNG October turn build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PENDING | `artifacts/qm5_12896_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | TO_ENQUEUE | `D:\QM\strategy_farm\state\farm_state.sqlite` |
