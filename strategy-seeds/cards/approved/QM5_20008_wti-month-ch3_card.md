---
copy_of: strategy-seeds/cards/wti-month-ch3_card.md
strategy_id: SZAKMARY-WTI-MCH3-2010
source_id: SZAKMARY-WTI-MCH3-2010
ea_id: QM5_20008
slug: wti-month-ch3
status: APPROVED
g0_status: APPROVED
created: 2026-07-19
created_by: Research
last_updated: 2026-07-19
source_citation: "Szakmary, Shen and Sharma (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking & Finance 34(2), 409-426, DOI 10.1016/j.jbankfin.2009.08.004."
source_citations:
  - type: academic_paper
    citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination."
    location: "Section 3 monthly channel rule; DOI https://doi.org/10.1016/j.jbankfin.2009.08.004"
    quality_tier: A
    role: primary
markets: [commodities, energy, crude_oil]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
period: D1
expected_trade_frequency: "Approximately 8 completed monthly packages/year; local 2018-2025 cadence precheck measured 8.21 signals/year."
expected_trades_per_year_per_symbol: 8
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

# Approved Card Copy - QM5_20008_wti-month-ch3

The canonical approved card is
`strategy-seeds/cards/wti-month-ch3_card.md`. Approval covers exactly the
source-tested monthly `L=3` close channel: compare the just-completed WTI
month end with the prior three month-end closes, hold the long/short breakout
package for one month, remain flat inside the channel, and renew at the next
month boundary. The only strategy additions are a frozen ATR hard stop, a
35-day stale guard and restart-safe one-package-per-month enforcement.

Approval is limited to one `XTIUSD.DWX` D1 RISK_FIXED backtest carrier. The
rolled-futures/CFD basis, costs, WTI-specific efficacy and realized correlation
to the certified book remain binding pipeline risks. No live artifact,
AutoTrading action, portfolio admission or portfolio-gate change is approved.

## Hypothesis

A completed WTI month that closes beyond all three prior month-end closes can
identify a persistent commodity trend. The source tests this exact monthly
channel with a one-month holding period.

## Rules

On the first D1 bar of a new broker month, reconstruct four completed month-end
closes. BUY when the latest is strictly above the maximum of the prior three,
SELL when it is strictly below their minimum, and remain flat otherwise. Close
the prior-month package before renewal. Use one frozen ATR hard stop and no
take-profit or trailing rule.

## 4. Entry Rules

- `XTIUSD.DWX` D1 only, once at the first D1 bar of a new broker month.
- `C0 > max(C1,C2,C3)` buys; `C0 < min(C1,C2,C3)` sells; equality is flat.
- Require valid bounded D1 history, ATR, spread and no current-month entry.
- Initial stop is `4.0 * ATR(20)`; risk is sized by the V5 fixed-risk layer.

## 5. Exit Rules

- Close every prior-month package at the next month boundary before renewal.
- Close at 35 calendar days as a stale guard or at the broker hard stop.
- No intramonth signal, target, trailing stop or break-even exit.

## 6. Filters (No-Trade Module)

- Exact XTI/D1/slot-0 guard and fail-closed parameter/history validation.
- Zero modeled spread is allowed; only a spread above the cap blocks entry.
- Framework kill switch and entry-news policy remain active.

## 7. Trade Management Rules

- One position per magic and one entry package per broker month.
- Current-month deal history prevents stop/restart re-entry.
- No scale-in, partial close, grid, martingale, pyramiding, adaptive fit,
  external runtime feed, banned indicator or ML.
- Friday close is disabled for the source's one-month hold.

## Risk

Q02 uses only `RISK_FIXED=1000`, `RISK_PERCENT=0` and one XTI D1 backtest
setfile. The rolled-futures/CFD basis, WTI gaps, false breakouts and unmeasured
book correlation make the card high risk. No live or portfolio mutation is
authorized.

## Pipeline Status

- Q01 PASS on 2026-07-19: strict compile 0 errors/0 warnings; build check 0
  failures/0 warnings.
- Q02 pending and unclaimed: work item
  `5659ee85-5c28-492e-965e-ca95b28e3828` for `XTIUSD.DWX` D1.
- Evidence:
  `docs/ops/evidence/2026-07-19_qm5_20008_wti_month_ch3_q02_enqueue.md`.
