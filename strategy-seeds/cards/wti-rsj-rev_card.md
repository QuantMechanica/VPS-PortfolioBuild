---
copy_of: strategy-seeds/cards/approved/QM5_20289_wti-rsj-rev_card.md
card_schema_version: 2
type: strategy
strategy_id: KISS-RSJ-2025_XTI_TS_S03
variant_id: KISS-RSJ-2025_XTI_TS_S03
source_id: KISS-WTI-RSJ-REV-2026
ea_id: QM5_20289
slug: wti-rsj-rev
status: APPROVED
g0_status: APPROVED
execution_contract_status: DRAFT
source_author: "Tamas Kiss; Igor Ferreira Batista Martins"
strategy_mechanic: monthly-wti-prior-complete-month-absolute-rsj-zero-pivot-reversal
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Kiss, T., and Ferreira Batista Martins, I. (2025). Good Volatility, Bad Volatility and the Cross Section of Commodity Returns. Finance Research Letters 86 Part D, 108656."
markets: [commodities, energy, crude_oil]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year; Q02 must prove at least five/year or retire."
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [complete_broker_month_reconstruction, within_month_return_inclusion, rsj_normalization, absolute_zero_pivot, reversal_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
---

# QM5_20289 WTI Signed-Semivariance Reversal

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20289_wti-rsj-rev_card.md`.

## Hypothesis

Trade a single-WTI monthly carrier of the source's negative RSJ relation: buy
when downside realized semivariance dominated the immediately preceding
complete month and sell when upside semivariance dominated. The zero-pivot
time-series translation is a disclosed QM hypothesis, not a source result.

## Rules

On the first D1 bar of a new broker month, use 15-25 log returns whose two
timestamps both lie in the prior complete month. Compute normalized
`RSJ=(RV_plus-RV_minus)/(RV_plus+RV_minus)`. Buy below zero, sell above zero,
and consume exact zero or invalid state flat. Renew monthly with one frozen
ATR hard stop, one consumed attempt, and no intramonth signal flip.

## 4. Entry Rules

- Exact `XTIUSD.DWX` D1, EA `20289`, slot 0, one monthly attempt.
- Prior complete month only; no boundary-crossing or current-month return.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen `3.5*ATR(20,D1)` stop.

## 5. Exit Rules

- Close before the next monthly decision or after forty calendar days.
- Broker stop and framework safety exits remain authoritative.

## 6. Filters (No-Trade Module)

- Fail closed on invalid month bounds, count, arithmetic, RSJ, spread, quote,
  ATR, risk mode, attempt state, or owned exposure.
- Friday close and both news axes are locked OFF for the monthly hold.

## 7. Trade Management Rules

- At most one position and one consumed attempt per broker month.
- No target, trail, partial, scale-in, grid, martingale, or pyramiding.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire below five packages/year, on nonpositive governed
economics, or on later correlation rejection. The existing two-leg energy RSJ
carrier's negative Q02 economics and Q04 failure are disclosed and not
inherited or repaired.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20289_wti_rsj_rev_g0.md` |
| Q01 Build Validation | - | NOT RUN | - |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
