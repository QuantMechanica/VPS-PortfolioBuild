---
strategy_id: MEEK-HOELSCHER-XNG-DOW-2023_S03
source_id: MEEK-HOELSCHER-XNG-DOW-2023
ea_id: QM5_20011
slug: xng-thu-tue
status: APPROVED
created: 2026-07-19
created_by: Research
last_updated: 2026-07-19
g0_status: APPROVED
source_citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics & Finance 11(1), 2213876. DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: paper
    citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics & Finance 11(1), 2213876."
    location: "Section 4 and Table 6, printed pages 15-16; DOI https://doi.org/10.1080/23322039.2023.2213876; open full text https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [session-close-seasonality, atr-hard-stop, time-stop, long-only, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "One package per broker week; approximately 45-52 completed packages/year after holidays and framework filters."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, darwinex_native_data_only]
g0_approval_reasoning: "R1 PASS peer-reviewed open source with exact Section 4 rule; R2 PASS fixed weekly Thursday-close to Tuesday-close lifecycle and ATR hard stop; R3 PASS XNGUSD.DWX D1 registered; R4 PASS deterministic native-data logic with no ML, banned indicators, grid or martingale; sibling return-window overlap disclosed."
---

# XNG Thursday-Close to Tuesday-Close Calendar Carry

## Source

Meek and Hoelscher (2023), *Cogent Economics & Finance* 11(1), article
2213876, DOI https://doi.org/10.1080/23322039.2023.2213876, explicitly state
the Natural Gas weekly implementation in Section 4: long at Thursday close
and close at Tuesday close. The paper studies futures; Darwinex CFD transfer
is a falsification question for Q02.

## 4. Entry Rules

On `XNGUSD.DWX` D1, BUY once per broker week at Friday D1 open, the executable
proxy for Thursday close. Require the first tradable tick within a locked
five-minute grace and prime later Friday attaches so they cannot enter.
Persist the weekly attempt before news gating and submission. Require no
same-magic position or entry deal, valid closed ATR(20), and spread not above
2500 points. Deal-history uncertainty consumes the decision before failing
closed, so a restart cannot create a recovery entry.

## 5. Exit Rules

Exit at the first tradable D1 opening after Tuesday close, normally Wednesday
D1 open, or the next tradable bar if Wednesday is missing. A seven-calendar-
day stale guard also exits.

## Stop

Place a frozen server hard stop `3.5 * ATR(20)` below entry. This deterministic
V5 risk overlay is source-silent. No TP, trail, break-even or partial close.

## 6. Filters (No-Trade Module)

Exact host `XNGUSD.DWX`, D1, slot 0. Entry/exit weekdays are locked. Invalid
parameters, price, ATR, spread, history or persisted state fail closed. News
may block only new risk; lifecycle exits remain active.

## 7. Trade Management Rules

One long package and attempt per broker week. Friday close is disabled because
weekend exposure is source-required. No ML, banned indicator, external runtime
data, adaptive fit, grid, martingale, pyramid or scale-in. Backtest setfiles
must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Expected Frequency

Approximately 48 completed packages per year on one symbol.

## Non-Duplicate Boundary

`NO_EXACT_MECHANIC_DUPLICATE` is clean. The strategy is distinct from
certified `QM5_12567` (fixed weekly calendar lifecycle versus conditional
SMA200/cumulative-RSI2 pullback). `KNOWN_RETURN_WINDOW_OVERLAP` is disclosed:
pending `QM5_12806` samples Monday-long and pending `QM5_12818` samples
Tuesday-long. Friday/weekend exposure and the persistent combined lifecycle
are incremental; decorrelation remains unproven.

## Risk And Safety Boundary

One RISK_FIXED backtest setfile only. No live setfile, `T_Live`, AutoTrading,
deploy/T_Live manifest, portfolio gate or portfolio-admission modification.

## Pipeline Status

Q01 passed on 2026-07-19 with zero compile errors/warnings and zero build-check
failures/warnings. Q02 work item
`aa33ca98-bc8a-4015-abc7-24f3f6e5b2ab` is pending, attempt 0 and unclaimed.
Smoke was deferred at the paced-fleet CPU ceiling; no tester was launched.
