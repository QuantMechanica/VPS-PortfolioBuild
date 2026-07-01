---
ea_id: QM5_12843
slug: wti-brent-spread
type: strategy
strategy_id: CME-WTI-BRENT-SPREAD-2026_S01
source_id: CME-WTI-BRENT-SPREAD-2026
source_citation: "CME Group WTI-Brent Financial Futures; ICE Brent/WTI Futures Spread; U.S. EIA Today in Energy Brent-WTI spread analysis."
source_citations:
  - type: exchange_reference
    citation: "CME Group. WTI-Brent Financial Futures."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/wti-brent-ice-calendar-swap-futures.html"
    quality_tier: A
    role: primary
  - type: exchange_reference
    citation: "ICE. Brent/WTI Futures Spread."
    location: "https://www.ice.com/products/1242/Brent-WTI-Futures-Spread/data"
    quality_tier: A
    role: corroborating
  - type: government_agency_analysis
    citation: "U.S. Energy Information Administration. Today in Energy Brent-WTI spread analysis."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67424"
    quality_tier: A
    role: structural_context
sources:
  - "[[sources/CME-WTI-BRENT-SPREAD-2026]]"
concepts:
  - "[[concepts/crude-benchmark-spread]]"
  - "[[concepts/brent-wti-relative-value]]"
indicators:
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-zscore, market-neutral-basket, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
markets: [XTIUSD.DWX, XBRUSD.DWX]
logical_symbol: QM5_12843_WTI_BRENT_SPREAD_D1
single_symbol_only: false
period: D1
timeframes: [D1]
expected_trade_frequency: "Low-frequency D1 Brent/WTI spread package; estimate 5-12 paired packages/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS exchange-traded CME/ICE Brent-WTI spread references plus EIA structural spread analysis; R2 PASS deterministic D1 log-spread z-score rule with ATR stops; R3 PASS XTI history exists and XBR route is already represented by QM5_12841, with Q02 required to validate XBR history sufficiency; R4 PASS no ML, grid, martingale, external runtime feed, or banned indicators."
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
---

# WTI-Brent Spread Reversion

## Source

- Source: [[sources/CME-WTI-BRENT-SPREAD-2026]]
- Primary references: CME WTI-Brent Financial Futures, ICE Brent/WTI Futures
  Spread, and EIA Brent-WTI spread market-structure analysis.

## Concept

Brent and WTI are separate crude benchmarks with a traded spread and a persistent
structural basis. The EA treats the broker CFD pair as a D1 relative-value
basket. It computes:

`log(XBRUSD.DWX) - beta * log(XTIUSD.DWX)`

on completed D1 closes, standardizes the spread against its rolling history, and
fades statistically extreme dislocations.

This is deliberately different from:

- `QM5_12840_xti-xng-rspread`: XTI/XNG return-spread reversion, not crude
  benchmark basis.
- `QM5_12578_eia-oilgas-ratio`, `QM5_12608_eia-oilgas-breakout`,
  `QM5_12733_xti-xng-xmom`, `QM5_12813_eia-energy-switch`, and
  `QM5_12840_xti-xng-rspread`: natural-gas cross-energy logic.
- `QM5_12841_brent-thu-prem`: single-symbol Brent weekday seasonality.
- WTI expiry, inventory, weekday, FX-confirmation, XNG expiry, XAU/XAG, and
  commodity RSI sleeves.

## Markets And Timeframe

- Logical basket symbol: `QM5_12843_WTI_BRENT_SPREAD_D1`.
- Host symbol: `XTIUSD.DWX`.
- Second leg: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 5-12 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

`XBRUSD.DWX` is intentionally queued only for Q02 validation. The local registry
already has an XBR route through `QM5_12841_brent-thu-prem`, but current history
sufficiency must be confirmed by the paced backtest fleet.

## Entry Rules

- Evaluate only on a new D1 host bar after both completed D1 close series are
  available.
- Compute the rolling z-score of `log(XBR) - beta * log(XTI)`.
- If z-score is above `strategy_entry_z`, Brent is rich versus WTI:
  sell `XBRUSD.DWX` and buy `XTIUSD.DWX`.
- If z-score is below negative `strategy_entry_z`, Brent is cheap versus WTI:
  buy `XBRUSD.DWX` and sell `XTIUSD.DWX`.
- No entry if either leg has an open position for this EA magic.
- No entry if either leg exceeds its spread cap.

## Exit Rules

- Close both legs when absolute z-score falls below `strategy_exit_z`.
- Close both legs after `strategy_max_hold_days` calendar days.
- Per-leg hard stop: ATR(`strategy_atr_period_d1`) *
  `strategy_atr_sl_mult`.
- Close both legs through the V5 Friday-close hook.
- If only one leg remains open, immediately flatten the orphaned leg.

## Filters

- Only trade from an `XTIUSD.DWX` D1 host chart.
- Magic slot offset must be 0 on the host.
- Skip entries when either D1 history series, ATR, spread, or symbol metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Two-leg basket only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.8, 2.0, 2.3]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.3, 0.5, 0.8]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 60]

## Author Claims

The source packet establishes that Brent-WTI is an exchange-recognized crude
benchmark spread with independent agency analysis. No source performance number
is imported into QM. Q02 and later phases must validate the mechanical rule on
Darwinex `XTIUSD.DWX` and `XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 22
- expected_trade_frequency: approximately 5-12 paired packages/year.
- risk_class: high because the Brent CFD history route and basket execution
  quality both need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: CME/ICE exchange listings and EIA structural spread
  analysis.
- [x] R2 mechanical: fixed D1 log-spread z-score entry, mean-reversion exit,
  time stop, ATR hard stops.
- [x] R3 testable: `XTIUSD.DWX` history is in registry and `XBRUSD.DWX` has a
  farm route through prior XBR setfiles; Q02 validates current basket history.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one package per magic.
- [x] Non-duplicate: Brent/WTI crude benchmark spread basket is not another
  XTI/XNG, XNG, XAU/XAG, WTI calendar, Brent weekday, or commodity RSI sleeve.

## Framework Alignment

- no_trade: D1 host guard, magic slot guard, parameter guard, spread caps.
- trade_entry: D1 completed-bar Brent/WTI z-score package entry.
- trade_management: orphan-leg cleanup, mean-reversion exit, max-hold stale
  exit, Friday close.
- trade_close: hard ATR stop plus deterministic package exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial structural Brent/WTI spread reversion card | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12843_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `5d112944-daec-4524-94cb-d11c1179b29c` |
