---
ea_id: QM5_12856
slug: brent-mon-fade
type: strategy
strategy_id: QUAY-WTI-DOW-2019_BRENT_S02
source_id: QUAY-WTI-DOW-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
source_citations:
  - type: academic_paper
    citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. (2020). Seasonality in crude oil returns. Soft Computing 24, 7857-7873."
    location: "DOI https://doi.org/10.1007/s00500-019-04329-0; local source packet strategy-seeds/sources/QUAY-WTI-DOW-2019/"
    quality_tier: A
    role: primary
sources:
  - "[[sources/QUAY-WTI-DOW-2019]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/brent-calendar-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly D1 Brent Monday-calendar weakness sleeve; estimate 40-52 trades/year after broker holidays, XBR history availability, and framework filters."
expected_trades_per_year_per_symbol: 46
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS peer-reviewed crude-oil day-of-week source with explicit Brent/WTI lineage; R2 PASS deterministic Monday D1 short/next-bar flat rule with ATR stop; R3 PASS wide-net DWX route via XBRUSD.DWX farm symbol map/prior XBR setfiles with Q02 validating history sufficiency; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
---

# Brent Monday Calendar Fade

## Source

- Source: [[sources/QUAY-WTI-DOW-2019]]
- Primary citation: Quayyum, H. A., Khan, M. A. M. and Ali, S. M.,
  "Seasonality in crude oil returns", Soft Computing 24, 7857-7873 (2020),
  DOI https://doi.org/10.1007/s00500-019-04329-0.
- Public metadata pointer: https://pure.cardiffmet.ac.uk/en/publications/seasonality-in-crude-oil-returns/.

## Concept

The peer-reviewed source studies crude-oil day-of-week seasonality across Brent
and WTI return samples and documents weak early-week crude-oil returns. This
card isolates the Monday weakness on the Brent benchmark instead of adding
another WTI or XNG leg: sell `XBRUSD.DWX` only on the broker-calendar Monday D1
bar and flatten on the first subsequent D1 bar.

This is deliberately different from:

- `QM5_12596_wti-mon-fade`: same weekday thesis but WTI benchmark
  (`XTIUSD.DWX`), not Brent.
- `QM5_12841_brent-thu-prem`: Brent benchmark, but Thursday long premium
  instead of Monday short weakness.
- `QM5_12597_wti-fri-prem`, `QM5_12610_wti-tue-fade`, `QM5_12775_wti-wed-prem`,
  and `QM5_12771_wti-thu-prem`: different benchmark, weekday, or direction.
- WTI month, WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, CAD/FX,
  oil/gold, oil/silver, XTI/XNG, XNG, XAU/XAG, Donchian, time-series momentum,
  and commodity RSI sleeves already in the registry.

## Markets And Timeframe

- Target symbol: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 40-52 trades/year before Q02 proves or kills
  the route.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

`XBRUSD.DWX` is intentionally queued only for Q02 validation. The farm has an
XBR symbol map and prior XBR setfiles, but current history sufficiency must be
confirmed by the paced backtest fleet.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be Monday, where Sunday=0 and Monday=1
  in MQL5 broker time.
- Entry direction is short only: SELL `XBRUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after Monday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XBRUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when ATR or the broker-calendar D1 bar is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_entry_dow
  default: 1
  sweep_range: [1]
- name: strategy_max_spread_points
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

The source is used only for structural lineage around day-of-week seasonality
in Brent and WTI returns, including weak early-week returns. No source
performance number is imported into QM; Q02 and later phases must validate the
rule on Darwinex `XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 18
- expected_trade_frequency: approximately 40-52 trades/year.
- risk_class: medium-high due Brent CFD history and crude gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed Soft Computing crude-oil seasonality
  paper with DOI.
- [x] R2 mechanical: fixed broker-calendar Monday, single D1 short entry, ATR
  stop, next-bar exit.
- [x] R3 testable: `XBRUSD.DWX` has farm symbol mapping and prior XBR setfile
  usage; Q02 is responsible for current history sufficiency.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: Brent benchmark Monday weakness is not another XTIUSD WTI
  build, not the existing Brent Thursday long, not XNG, not XAU/XAG, not
  XTI/XNG, and not commodity RSI logic.

## Framework Alignment

- no_trade: D1 and `XBRUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: Monday broker-calendar short entry.
- trade_management: first non-Monday D1 bar and max-hold stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial structural Brent Monday calendar-fade card | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `D:\QM\reports\framework\21\build_check_20260701_140718.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `3dac9cf1-8a42-4309-af7b-09d74df05002` |
