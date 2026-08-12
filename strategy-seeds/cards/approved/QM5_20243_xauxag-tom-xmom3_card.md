---
card_schema_version: 2
type: strategy
strategy_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026_S01
variant_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026_S01
source_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026
ea_id: QM5_20243
slug: xauxag-tom-xmom3
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20243_xauxag-tom-xmom3_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
source_citation: "van Hemert (2014), SSRN 2515900; Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), 2530-2548."
source_citations:
  - type: working_paper
    citation: "van Hemert, O. (2014). The MOM-TOM Effect: Detecting the Market Impact of CTA Trading."
    location: "SSRN 2515900; governed packet strategy-seeds/sources/VANHEMERT-MOMTOM-2014/source.md"
    quality_tier: A-
    role: turn_of_month_flow_window
  - type: peer_reviewed_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI 10.1016/j.jbankfin.2010.04.009; complete governed packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: three_month_cross_sectional_momentum
strategy_mechanic: three-date-turn-of-month-cycle-frozen-three-completed-month-average-return-rank-xau-xag-two-leg-basket
strategy_type_flags: [commodity, precious-metals, turn-of-month, cta-flow, cross-sectional-momentum, market-neutral-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20243_XAU_XAG_TOM_XMOM3_D1
symbol: QM5_20243_XAU_XAG_TOM_XMOM3_D1
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-12 two-leg TOM packages/year after warm-up; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a cycle-frozen XAU/XAG three-month rank held only during the three-date CTA-flow TOM window; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [tom_calendar_translation, cycle_frozen_signal, synchronized_month_ends, basket_atomicity, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission plus decisions/2026-08-06_qm5_20243_xauxag_tom_xmom3_g0.md; R1-R4 PASS; exact identity clean and expected momentum siblings manually separated by TOM-only exposure and a pre-cycle frozen signal."
---

# QM5_20243 XAU/XAG MOM-TOM Cross-Sectional Momentum

The complete canonical execution card is
`strategy-seeds/cards/xauxag-tom-xmom3_card.md`; all rules below are locked to
that approved contract.

## Hypothesis And Source Boundary

Combine Van Hemert's last-two/first-one CTA turn-of-month flow timing with the
source-declared three-month commodity cross-sectional return rank of Fuertes,
Miffre, and Rallis. Buy the higher-return metal, short the lower, and remain
flat outside the TOM cycle. The exact intersection and two-CFD translation are
QM hypotheses; no source efficacy, neutrality, or correlation result transfers.

## Non-Duplicate Boundary

The pre-allocation checker found no exact identity and only expected XAU/XAG
momentum siblings. `QM5_20184` holds a three-month rank for an entire month;
this EA freezes formation before the cycle, trades only the final two calendar
dates plus the next month's first date, and exits immediately after. One- and
twelve-month ranks, ratio/residual systems, risk-distribution ranks, and
outright energy TOM systems have different information objects, horizons,
holds, or carriers. The TOM-only lifecycle is load-bearing.

## Rules

The following rules and fixed inputs are the complete Q02 baseline.

## 4. Entry Rules

- Exact ID `20243`, XAU D1 host, slot 0, fixed inputs, and one attempt per TOM
  cycle persisted before every fallible gate.
- Map the last two calendar dates of month `t` and first date of `t+1` to one
  cycle key.
- For each leg reconstruct four synchronized month ends ending at `t-1`, then
  average exactly three consecutive simple monthly returns.
- Buy XAU/sell XAG when XAU ranks higher; sell XAU/buy XAG when XAG ranks
  higher; consume equality or invalid state flat.
- Require both registered magics, spreads at or below 1,500/3,000 points,
  valid quotes, ATR, stops, lots, and no owned or same-cycle exposure.
- Split one `RISK_FIXED` budget equally by stop risk. Give both legs frozen
  `3.5 * ATR(20,D1)` hard stops and no target. Repair any partial open.

## 5. Exit Rules

- Close both legs on the first D1 bar outside the same TOM cycle or after six
  elapsed calendar days.
- Flatten any orphan, duplicate, wrong-symbol, same-direction, wrong-magic, or
  missing-stop package immediately.
- Friday close is disabled. Broker stops and kill switch remain authoritative.
- No target, trail, break-even, partial, scale, grid, martingale, pyramid, or
  intracycle signal flip is allowed.

## 6. Filters (No-Trade Module)

Fail closed on wrong host, timeframe, ID, slot, input, cycle, attempt state,
history, month key, endpoint synchronization, arithmetic, spread, quote, ATR,
stop, volume, magic, deal, or package state. News temporal, compliance, and
legacy modes are OFF. Runtime uses only native MT5 D1 OHLC, broker calendar,
ATR, positions, deals, quotes, and contract metadata.

## 7. Trade Management Rules

Maintain exactly one opposite-direction XAU/XAG pair and one consumed attempt
per cycle. Validate composition every tick, preserve original hard stops, and
close invalid or out-of-window state before any entry logic. Both legs share a
single fixed-risk package budget.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_tom_pre_days` | 2 | [2] |
| `strategy_tom_post_days` | 1 | [1] |
| `strategy_return_window_months` | 3 | [3] |
| `strategy_history_bars` | 500 | [500] |
| `strategy_atr_period_d1` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 6 | [6] |
| `strategy_xau_max_spread_pts` | 1500 | [1500] |
| `strategy_xag_max_spread_pts` | 3000 | [3000] |
| `strategy_deviation_points` | 20 | [20] |

## Risk And Safety

Q02 uses one logical-basket setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. Retire below five complete packages/year, on
nonpositive economics, any lifecycle or aggregate-risk breach, nondeterminism,
or later correlation rejection. No frozen-input rescue is authorized.

No manual backtest, live/demo/shadow/optimization/stress setfile, AutoTrading,
`T_Live`, deploy manifest, portfolio admission, portfolio-gate edit, or
correlation waiver is authorized.
