---
copy_of: strategy-seeds/cards/xng-2m-contr_card.md
strategy_id: MISHRA-SMYTH-XNG-2M-2016_S01
source_id: MISHRA-SMYTH-XNG-PRED-2016
ea_id: QM5_20013
slug: xng-2m-contr
status: APPROVED
g0_status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
source_citation: "Mishra, V. and Smyth, R. (2016), Are Natural Gas Spot and Futures Prices Predictable?, Economic Modelling 54, 178-186, DOI 10.1016/j.econmod.2015.12.034."
source_citations:
  - type: academic_paper
    citation: "Mishra, V. and Smyth, R. (2016). Are Natural Gas Spot and Futures Prices Predictable? Economic Modelling, 54, 178-186."
    location: "Trading simulation on printed p. 18 and Table 10 on printed p. 34; DOI https://doi.org/10.1016/j.econmod.2015.12.034"
    quality_tier: A
    role: primary
markets: [commodities, energy, natural_gas]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Six fixed bimonthly decisions per complete year; normally six renewed packages, subject to exact equality, missing history, spread, or a prior stop in the same period."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, low_frequency]
---

# Embedded Approved Card - QM5_20013_xng-2m-contr

The canonical card is `strategy-seeds/cards/xng-2m-contr_card.md` and the
approval copy is
`strategy-seeds/cards/approved/QM5_20013_xng-2m-contr_card.md`.

## Hypothesis

Fade the sign of the completed two-month XNG move at fixed odd-month broker
boundaries. The rule is unconditional and uses no oscillator, magnitude
threshold, moving average, volatility regime or fitted mean.

## 4. Entry Rules

- D1 `XNGUSD.DWX`, slot 0, first bar of Jan/Mar/May/Jul/Sep/Nov.
- Reconstruct `C0,C1,C2`; buy for `C0<C2`, sell for `C0>C2`.
- Exact equality creates no new order and retains an existing prior state.
- Non-equality renews the prior two-month package.
- Require valid bounded history, ATR and spread; one entry per period.
- Use a frozen `4.0 * ATR(20)` stop and V5 fixed-risk sizing.

## 5. Exit Rules

- Close before non-equality renewal; retain on exact equality.
- Close at 70 calendar days as a safety override or at the broker stop.
- No intraperiod signal, target, trail or break-even move.

## 6. Filters (No-Trade Module)

- Exact XNG/D1/slot and locked-parameter guards.
- Spread cap 3000 points; zero modeled spread is allowed.
- Framework kill switch and entry-news policy remain authoritative.

## 7. Trade Management Rules

- One position and one entry package per magic/period.
- Deal history blocks restart and post-stop re-entry.
- No stacking, grid, martingale, adaptive fit, external feed, banned indicator
  or ML; Friday close is disabled for the two-month horizon.

## Risk

Only one RISK_FIXED backtest setfile is authorized. Spot/futures-to-CFD basis,
costs, realized performance and book correlation are unproven. No live or
portfolio mutation is authorized.

## Pipeline Status

- Q01 build validation pending.
- Q02 not yet enqueued.

